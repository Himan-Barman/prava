#include "modules/media/media_service.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include <openssl/hmac.h>
#include <openssl/sha.h>

#include <drogon/utils/Utilities.h>

#include "app_state.h"
#include "modules/conversations/conversations_service.h"

namespace {

constexpr long long kMaxMediaBytes = 100LL * 1024LL * 1024LL;
constexpr int kUploadUrlTtlSeconds = 15 * 60;
constexpr int kDownloadUrlTtlSeconds = 15 * 60;
constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

struct ParsedEndpoint {
  std::string scheme;
  std::string host;
  std::string base_path;
};

Json::Value ParseJsonText(const std::string& text,
                          const Json::Value& fallback) {
  if (text.empty()) {
    return fallback;
  }

  Json::CharReaderBuilder builder;
  builder["collectComments"] = false;
  Json::Value root;
  std::string errors;
  std::istringstream stream(text);
  if (!Json::parseFromStream(builder, stream, &root, &errors)) {
    return fallback;
  }
  return root;
}

std::string ToJsonString(const Json::Value& value) {
  Json::StreamWriterBuilder builder;
  builder["indentation"] = "";
  return Json::writeString(builder, value);
}

std::string SanitizeFileName(const std::string& input) {
  std::string sanitized;
  sanitized.reserve(input.size());
  for (char ch : input) {
    if (std::isalnum(static_cast<unsigned char>(ch)) || ch == '.' || ch == '_' ||
        ch == '-') {
      sanitized.push_back(ch);
    } else {
      sanitized.push_back('_');
    }
    if (sanitized.size() >= 128) {
      break;
    }
  }
  return sanitized;
}

ParsedEndpoint ParseEndpoint(const std::string& endpoint) {
  ParsedEndpoint parsed;
  std::string url = endpoint;
  if (url.empty()) {
    return parsed;
  }

  const std::string https_prefix = "https://";
  const std::string http_prefix = "http://";
  if (url.rfind(https_prefix, 0) == 0) {
    parsed.scheme = "https";
    url = url.substr(https_prefix.size());
  } else if (url.rfind(http_prefix, 0) == 0) {
    parsed.scheme = "http";
    url = url.substr(http_prefix.size());
  } else {
    parsed.scheme = "https";
  }

  const auto slash_pos = url.find('/');
  if (slash_pos == std::string::npos) {
    parsed.host = url;
    parsed.base_path = "";
  } else {
    parsed.host = url.substr(0, slash_pos);
    parsed.base_path = url.substr(slash_pos);
  }

  if (parsed.base_path == "/") {
    parsed.base_path.clear();
  }

  return parsed;
}

std::string UrlEncode(const std::string& value, bool keep_slash) {
  std::ostringstream escaped;
  escaped.fill('0');
  escaped << std::hex << std::uppercase;

  for (const unsigned char ch : value) {
    if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
        (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' || ch == '.' ||
        ch == '~' || (keep_slash && ch == '/')) {
      escaped << ch;
    } else {
      escaped << '%' << std::setw(2) << static_cast<int>(ch);
    }
  }
  return escaped.str();
}

std::string Sha256Hex(const std::string& data) {
  unsigned char hash[SHA256_DIGEST_LENGTH];
  SHA256(reinterpret_cast<const unsigned char*>(data.data()),
         data.size(),
         hash);

  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (unsigned char byte : hash) {
    stream << std::setw(2) << static_cast<int>(byte);
  }
  return stream.str();
}

std::string HmacSha256(const std::string& key, const std::string& data) {
  unsigned char digest[EVP_MAX_MD_SIZE];
  unsigned int len = 0;
  HMAC(EVP_sha256(),
       key.data(),
       static_cast<int>(key.size()),
       reinterpret_cast<const unsigned char*>(data.data()),
       data.size(),
       digest,
       &len);
  return std::string(reinterpret_cast<char*>(digest), len);
}

std::string HmacSha256Hex(const std::string& key, const std::string& data) {
  const std::string raw = HmacSha256(key, data);
  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (unsigned char byte : raw) {
    stream << std::setw(2) << static_cast<int>(byte);
  }
  return stream.str();
}

std::string AwsSign(const std::string& secret,
                    const std::string& date,
                    const std::string& region,
                    const std::string& service,
                    const std::string& string_to_sign) {
  const std::string k_date = HmacSha256("AWS4" + secret, date);
  const std::string k_region = HmacSha256(k_date, region);
  const std::string k_service = HmacSha256(k_region, service);
  const std::string k_signing = HmacSha256(k_service, "aws4_request");
  return HmacSha256Hex(k_signing, string_to_sign);
}

std::string BuildPresignedUrl(const std::string& method,
                              const std::string& endpoint,
                              const std::string& region,
                              const std::string& access_key,
                              const std::string& secret_key,
                              const std::string& bucket,
                              const std::string& object_key,
                              int expires_seconds,
                              const std::optional<std::string>& content_type,
                              bool force_path_style) {
  if (access_key.empty() || secret_key.empty() || region.empty() ||
      bucket.empty()) {
    return "";
  }

  ParsedEndpoint parsed = ParseEndpoint(endpoint);
  if (parsed.host.empty()) {
    return "";
  }

  std::string host = parsed.host;
  std::string path = parsed.base_path;
  if (force_path_style) {
    path += "/" + bucket + "/" + object_key;
  } else {
    host = bucket + "." + host;
    path += "/" + object_key;
  }

  const auto now = std::chrono::system_clock::now();
  const std::time_t now_time = std::chrono::system_clock::to_time_t(now);
  std::tm tm{};
#if defined(_WIN32)
  gmtime_s(&tm, &now_time);
#else
  gmtime_r(&now_time, &tm);
#endif
  char date_buf[9];
  char datetime_buf[17];
  std::strftime(date_buf, sizeof(date_buf), "%Y%m%d", &tm);
  std::strftime(datetime_buf, sizeof(datetime_buf), "%Y%m%dT%H%M%SZ", &tm);

  const std::string date = date_buf;
  const std::string amz_date = datetime_buf;
  const std::string credential_scope =
      date + "/" + region + "/s3/aws4_request";

  std::vector<std::pair<std::string, std::string>> query_params = {
      {"X-Amz-Algorithm", "AWS4-HMAC-SHA256"},
      {"X-Amz-Credential", access_key + "/" + credential_scope},
      {"X-Amz-Date", amz_date},
      {"X-Amz-Expires", std::to_string(expires_seconds)},
  };

  std::vector<std::pair<std::string, std::string>> headers = {
      {"host", host},
  };
  if (content_type && !content_type->empty() && method == "PUT") {
    headers.push_back({"content-type", *content_type});
  }

  std::sort(headers.begin(), headers.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });
  std::string canonical_headers;
  std::string signed_headers;
  for (size_t i = 0; i < headers.size(); ++i) {
    canonical_headers += headers[i].first + ":" + headers[i].second + "\n";
    if (i > 0) {
      signed_headers += ";";
    }
    signed_headers += headers[i].first;
  }

  query_params.push_back({"X-Amz-SignedHeaders", signed_headers});
  std::sort(query_params.begin(), query_params.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });

  std::string canonical_query;
  for (size_t i = 0; i < query_params.size(); ++i) {
    if (i > 0) {
      canonical_query += "&";
    }
    canonical_query += UrlEncode(query_params[i].first, false);
    canonical_query += "=";
    canonical_query += UrlEncode(query_params[i].second, false);
  }

  const std::string canonical_uri = UrlEncode(path, true);
  const std::string canonical_request =
      method + "\n" + canonical_uri + "\n" + canonical_query + "\n" +
      canonical_headers + "\n" + signed_headers + "\nUNSIGNED-PAYLOAD";

  const std::string string_to_sign =
      "AWS4-HMAC-SHA256\n" + amz_date + "\n" + credential_scope + "\n" +
      Sha256Hex(canonical_request);

  const std::string signature = AwsSign(secret_key, date, region, "s3",
                                        string_to_sign);

  const std::string scheme =
      parsed.scheme.empty() ? "https" : parsed.scheme;
  std::string url = scheme + "://" + host + canonical_uri + "?" +
                    canonical_query + "&X-Amz-Signature=" + signature;
  return url;
}

std::string BuildPublicUrl(const std::string& base,
                           const std::string& key) {
  if (base.empty()) {
    return "";
  }
  std::string trimmed = base;
  while (!trimmed.empty() && trimmed.back() == '/') {
    trimmed.pop_back();
  }
  return trimmed + "/" + key;
}

std::string BuildStorageKey(const std::string& user_id,
                            const std::string& conversation_id,
                            const std::string& asset_id,
                            const std::optional<std::string>& file_name) {
  const std::string scope = !conversation_id.empty() ? conversation_id : user_id;
  const std::string safe_name =
      file_name ? SanitizeFileName(*file_name) : "";

  if (!safe_name.empty()) {
    return "media/" + scope + "/" + asset_id + "/" + safe_name;
  }

  return "media/" + scope + "/" + asset_id;
}

Json::Value MapAssetRow(const drogon::orm::Row& row) {
  Json::Value asset;
  asset["id"] = row["id"].as<std::string>();
  asset["userId"] = row["user_id"].as<std::string>();
  asset["conversationId"] = row["conversation_id"].isNull()
                                ? Json::nullValue
                                : Json::Value(row["conversation_id"].as<std::string>());
  asset["status"] = row["status"].as<std::string>();
  asset["contentType"] = row["content_type"].as<std::string>();
  asset["fileName"] = row["file_name"].isNull()
                          ? Json::nullValue
                          : Json::Value(row["file_name"].as<std::string>());
  asset["sizeBytes"] = row["size_bytes"].isNull()
                           ? Json::nullValue
                           : Json::Value(static_cast<Json::Int64>(
                                 row["size_bytes"].as<long long>()));
  asset["sha256"] = row["sha256"].isNull()
                        ? Json::nullValue
                        : Json::Value(row["sha256"].as<std::string>());
  asset["metadata"] = row["metadata"].isNull()
                          ? Json::Value(Json::objectValue)
                          : ParseJsonText(row["metadata"].as<std::string>(),
                                          Json::Value(Json::objectValue));
  asset["encryptionAlgorithm"] =
      row["encryption_algorithm"].isNull()
          ? Json::nullValue
          : Json::Value(row["encryption_algorithm"].as<std::string>());
  asset["encryptionKeyId"] =
      row["encryption_key_id"].isNull()
          ? Json::nullValue
          : Json::Value(row["encryption_key_id"].as<std::string>());
  asset["encryptionIv"] =
      row["encryption_iv"].isNull()
          ? Json::nullValue
          : Json::Value(row["encryption_iv"].as<std::string>());
  asset["encryptionKeyHash"] =
      row["encryption_key_hash"].isNull()
          ? Json::nullValue
          : Json::Value(row["encryption_key_hash"].as<std::string>());
  asset["thumbnailKey"] =
      row["thumbnail_key"].isNull()
          ? Json::nullValue
          : Json::Value(row["thumbnail_key"].as<std::string>());
  asset["thumbnailContentType"] =
      row["thumbnail_content_type"].isNull()
          ? Json::nullValue
          : Json::Value(row["thumbnail_content_type"].as<std::string>());
  asset["retentionPolicy"] = row["retention_policy"].as<std::string>();
  asset["expiresAt"] = row["expires_at"].isNull()
                           ? Json::nullValue
                           : Json::Value(row["expires_at"].as<std::string>());
  asset["createdAt"] = row["created_at"].as<std::string>();
  asset["updatedAt"] = row["updated_at"].as<std::string>();
  asset["uploadedAt"] = row["uploaded_at"].isNull()
                            ? Json::nullValue
                            : Json::Value(row["uploaded_at"].as<std::string>());
  asset["processedAt"] = row["processed_at"].isNull()
                             ? Json::nullValue
                             : Json::Value(row["processed_at"].as<std::string>());
  return asset;
}

}  // namespace

MediaService::MediaService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

Json::Value MediaService::InitUpload(const MediaInitInput& input) {
  if (input.size_bytes && *input.size_bytes > kMaxMediaBytes) {
    throw MediaError(drogon::k400BadRequest, "Media file exceeds size limit");
  }

  const auto& cfg = AppState::Instance().GetConfig();
  if (cfg.s3_region.empty() || cfg.s3_access_key_id.empty() ||
      cfg.s3_secret_access_key.empty() || cfg.s3_bucket.empty()) {
    throw MediaError(drogon::k503ServiceUnavailable,
                     "Media storage not configured");
  }

  std::string endpoint = cfg.s3_endpoint;
  if (endpoint.empty()) {
    endpoint = "https://s3." + cfg.s3_region + ".amazonaws.com";
  }

  const std::string asset_id = drogon::utils::getUuid();
  const std::string storage_key =
      BuildStorageKey(input.user_id, input.conversation_id, asset_id,
                      input.file_name);

  const std::string metadata_json = ToJsonString(input.metadata);
  const std::string file_name_value = input.file_name.value_or("");
  const std::string sha256_value = input.sha256.value_or("");
  const std::string retention =
      input.retention_policy.value_or("standard");
  const std::string encryption_algorithm =
      input.encryption_algorithm.value_or("");
  const std::string encryption_key_id =
      input.encryption_key_id.value_or("");
  const std::string encryption_iv = input.encryption_iv.value_or("");
  const std::string encryption_key_hash =
      input.encryption_key_hash.value_or("");
  const long long size_bytes_value =
      input.size_bytes.value_or(-1);

  const auto rows = db::ExecSqlSync(db_, 
      "INSERT INTO media_assets (id, user_id, conversation_id, status, content_type, "
      "file_name, size_bytes, sha256, storage_bucket, storage_key, storage_region, "
      "metadata, encryption_algorithm, encryption_key_id, encryption_iv, "
      "encryption_key_hash, retention_policy, updated_at) "
      "VALUES (?, ?, ?, 'pending', ?, NULLIF(?, ''), NULLIF(?, -1), NULLIF(?, ''), "
      "?, ?, ?, NULLIF(?, '')::jsonb, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), "
      "NULLIF(?, ''), ?, NOW()) "
      "RETURNING id, storage_key",
      asset_id,
      input.user_id,
      input.conversation_id,
      input.content_type,
      file_name_value,
      size_bytes_value,
      sha256_value,
      cfg.s3_bucket,
      storage_key,
      cfg.s3_region,
      metadata_json,
      encryption_algorithm,
      encryption_key_id,
      encryption_iv,
      encryption_key_hash,
      retention);

  if (rows.empty()) {
    throw MediaError(drogon::k500InternalServerError,
                     "Failed to initialize media");
  }

  const std::string upload_url = BuildPresignedUrl(
      "PUT", endpoint, cfg.s3_region, cfg.s3_access_key_id,
      cfg.s3_secret_access_key, cfg.s3_bucket, storage_key,
      kUploadUrlTtlSeconds, input.content_type, cfg.s3_force_path_style);

  if (upload_url.empty()) {
    throw MediaError(drogon::k503ServiceUnavailable,
                     "Media storage not configured");
  }

  Json::Value response;
  response["assetId"] = asset_id;
  response["uploadUrl"] = upload_url;
  response["uploadMethod"] = "PUT";
  Json::Value headers(Json::objectValue);
  headers["Content-Type"] = input.content_type;
  response["uploadHeaders"] = headers;
  response["expiresIn"] = kUploadUrlTtlSeconds;
  response["storageKey"] = storage_key;
  return response;
}

Json::Value MediaService::CompleteUpload(const MediaCompleteInput& input) {
  if (input.size_bytes && *input.size_bytes > kMaxMediaBytes) {
    throw MediaError(drogon::k400BadRequest, "Media file exceeds size limit");
  }

  const auto rows = db::ExecSqlSync(db_, 
      "SELECT id, user_id, status, size_bytes, sha256, metadata, file_name "
      "FROM media_assets WHERE id = ? LIMIT 1",
      input.asset_id);

  if (rows.empty()) {
    throw MediaError(drogon::k404NotFound, "Media not found");
  }

  const auto& row = rows.front();
  if (row["user_id"].as<std::string>() != input.user_id) {
    throw MediaError(drogon::k403Forbidden, "Media asset not owned");
  }

  const std::string status = row["status"].as<std::string>();
  if (status == "failed") {
    throw MediaError(drogon::k400BadRequest, "Media asset upload failed");
  }
  if (status == "ready" || status == "processing") {
    Json::Value response;
    response["assetId"] = input.asset_id;
    response["status"] = status;
    return response;
  }

  const long long size_value = input.size_bytes.value_or(-1);
  const std::string sha_value = input.sha256.value_or("");
  const std::string file_name_value = input.file_name.value_or("");
  const std::string metadata_json =
      input.metadata.isNull() || input.metadata.empty()
          ? ""
          : ToJsonString(input.metadata);

  const auto updated = db::ExecSqlSync(db_, 
      "UPDATE media_assets SET status = 'uploaded', "
      "size_bytes = COALESCE(NULLIF(?, -1), size_bytes), "
      "sha256 = COALESCE(NULLIF(?, ''), sha256), "
      "metadata = CASE WHEN ? = '' THEN metadata ELSE ?::jsonb END, "
      "file_name = COALESCE(NULLIF(?, ''), file_name), "
      "uploaded_at = NOW(), updated_at = NOW() "
      "WHERE id = ? "
      "RETURNING id, status",
      size_value,
      sha_value,
      metadata_json,
      metadata_json,
      file_name_value,
      input.asset_id);

  if (updated.empty()) {
    throw MediaError(drogon::k500InternalServerError,
                     "Failed to complete upload");
  }

  Json::Value response;
  response["assetId"] = updated.front()["id"].as<std::string>();
  response["status"] = updated.front()["status"].as<std::string>();
  return response;
}

std::optional<Json::Value> MediaService::GetAssetForUser(
    const std::string& asset_id,
    const std::string& user_id) {
  const auto rows = db::ExecSqlSync(db_, 
      "SELECT id, user_id, conversation_id, status, content_type, file_name, "
      "size_bytes, sha256, storage_bucket, storage_key, storage_region, metadata, "
      "encryption_algorithm, encryption_key_id, encryption_iv, encryption_key_hash, "
      "thumbnail_key, thumbnail_content_type, retention_policy, "
      "to_char(expires_at at time zone 'utc', ?) AS expires_at, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at, "
      "to_char(uploaded_at at time zone 'utc', ?) AS uploaded_at, "
      "to_char(processed_at at time zone 'utc', ?) AS processed_at "
      "FROM media_assets WHERE id = ? LIMIT 1",
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      asset_id);

  if (rows.empty()) {
    return std::nullopt;
  }

  const auto& row = rows.front();
  bool can_access = row["user_id"].as<std::string>() == user_id;
  if (!can_access && !row["conversation_id"].isNull()) {
    const std::string conversation_id =
        row["conversation_id"].as<std::string>();
    ConversationsService conversations(db_);
    can_access = conversations.HasMembership(conversation_id, user_id);
  }

  if (!can_access) {
    throw MediaError(drogon::k403Forbidden, "Media asset is restricted");
  }

  const auto& cfg = AppState::Instance().GetConfig();
  std::string endpoint = cfg.s3_endpoint;
  if (endpoint.empty() && !cfg.s3_region.empty()) {
    endpoint = "https://s3." + cfg.s3_region + ".amazonaws.com";
  }

  const std::string storage_key = row["storage_key"].as<std::string>();
  std::string download_url;
  if (row["status"].as<std::string>() == "ready") {
    if (!cfg.s3_public_base_url.empty()) {
      download_url = BuildPublicUrl(cfg.s3_public_base_url, storage_key);
    } else {
      download_url = BuildPresignedUrl(
          "GET", endpoint, cfg.s3_region, cfg.s3_access_key_id,
          cfg.s3_secret_access_key, cfg.s3_bucket, storage_key,
          kDownloadUrlTtlSeconds, std::nullopt, cfg.s3_force_path_style);
    }
  }

  std::string thumbnail_url;
  if (!row["thumbnail_key"].isNull()) {
    const std::string thumb_key = row["thumbnail_key"].as<std::string>();
    if (!cfg.s3_public_base_url.empty()) {
      thumbnail_url = BuildPublicUrl(cfg.s3_public_base_url, thumb_key);
    } else {
      thumbnail_url = BuildPresignedUrl(
          "GET", endpoint, cfg.s3_region, cfg.s3_access_key_id,
          cfg.s3_secret_access_key, cfg.s3_bucket, thumb_key,
          kDownloadUrlTtlSeconds, std::nullopt, cfg.s3_force_path_style);
    }
  }

  Json::Value response;
  response["asset"] = MapAssetRow(row);
  response["downloadUrl"] =
      download_url.empty() ? Json::nullValue : Json::Value(download_url);
  response["thumbnailUrl"] =
      thumbnail_url.empty() ? Json::nullValue : Json::Value(thumbnail_url);
  return response;
}

Json::Value MediaService::AssertAssetReadyForMessage(
    const std::string& asset_id,
    const std::string& user_id,
    const std::string& conversation_id) {
  const auto rows = db::ExecSqlSync(db_, 
      "SELECT id, user_id, conversation_id, status "
      "FROM media_assets WHERE id = ? LIMIT 1",
      asset_id);

  if (rows.empty()) {
    throw MediaError(drogon::k400BadRequest, "Media asset not found");
  }

  const auto& row = rows.front();
  if (row["user_id"].as<std::string>() != user_id) {
    throw MediaError(drogon::k403Forbidden, "Media asset not owned");
  }

  if (!row["conversation_id"].isNull()) {
    const std::string asset_conversation =
        row["conversation_id"].as<std::string>();
    if (asset_conversation != conversation_id) {
      throw MediaError(drogon::k400BadRequest,
                       "Media asset is not in this conversation");
    }
  } else {
    db::ExecSqlSync(db_, 
        "UPDATE media_assets SET conversation_id = ?, updated_at = NOW() "
        "WHERE id = ?",
        conversation_id,
        asset_id);
  }

  const std::string status = row["status"].as<std::string>();
  if (status != "ready") {
    throw MediaError(drogon::k400BadRequest, "Media is not ready");
  }

  Json::Value response;
  response["id"] = row["id"].as<std::string>();
  return response;
}

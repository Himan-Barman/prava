#include "modules/media/media_controller.h"

#include <optional>
#include <string>
#include <unordered_set>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/conversations/conversations_service.h"
#include "modules/media/media_service.h"

namespace {

constexpr long long kMaxMediaBytes = 100LL * 1024LL * 1024LL;

bool GetUserId(const drogon::HttpRequestPtr& req, std::string& user_id) {
  const auto attrs = req->getAttributes();
  if (!attrs || !attrs->find("user_id")) {
    return false;
  }
  user_id = attrs->get<std::string>("user_id");
  return true;
}

bool ParseJsonPayload(const drogon::HttpRequestPtr& req,
                      const std::unordered_set<std::string>& allowed,
                      Json::Value& out,
                      drogon::HttpResponsePtr& error_resp) {
  std::string error;
  if (!http::ParseJsonObject(req, out, error)) {
    error_resp = http::ErrorResponse(drogon::k400BadRequest, error);
    return false;
  }
  if (!http::HasOnlyFields(out, allowed)) {
    error_resp = http::ErrorResponse(drogon::k400BadRequest, "Invalid payload");
    return false;
  }
  return true;
}

bool GetRequiredString(const Json::Value& body,
                       const std::string& key,
                       std::string& out) {
  return http::GetStringField(body, key, out);
}

bool GetOptionalString(const Json::Value& body,
                       const std::string& key,
                       std::optional<std::string>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isString()) {
    return false;
  }
  out = body[key].asString();
  return true;
}

bool GetOptionalInt64(const Json::Value& body,
                      const std::string& key,
                      std::optional<long long>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isInt64() && !body[key].isUInt64() && !body[key].isInt()) {
    return false;
  }
  out = body[key].asInt64();
  return true;
}

bool GetOptionalObject(const Json::Value& body,
                       const std::string& key,
                       Json::Value& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isObject()) {
    return false;
  }
  out = body[key];
  return true;
}

MediaService BuildMediaService() {
  return MediaService(AppState::Instance().GetDb());
}

ConversationsService BuildConversationsService() {
  return ConversationsService(AppState::Instance().GetDb());
}

void RespondWithMedia(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const MediaError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void MediaController::InitUpload(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {
      "conversationId",
      "contentType",
      "fileName",
      "sizeBytes",
      "sha256",
      "retentionPolicy",
      "encryptionAlgorithm",
      "encryptionKeyId",
      "encryptionIv",
      "encryptionKeyHash",
      "metadata"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string conversation_id;
  std::string content_type;
  if (!GetRequiredString(body, "conversationId", conversation_id) ||
      !GetRequiredString(body, "contentType", content_type)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (content_type.size() < 3 || content_type.size() > 128) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> file_name;
  if (!GetOptionalString(body, "fileName", file_name)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (file_name && file_name->size() > 256) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<long long> size_bytes;
  if (!GetOptionalInt64(body, "sizeBytes", size_bytes)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (size_bytes && (*size_bytes < 1 || *size_bytes > kMaxMediaBytes)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> sha256;
  if (!GetOptionalString(body, "sha256", sha256)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (sha256 && sha256->size() != 64) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> retention;
  if (!GetOptionalString(body, "retentionPolicy", retention)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (retention && *retention != "standard" && *retention != "ephemeral") {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> encryption_algorithm;
  if (!GetOptionalString(body, "encryptionAlgorithm", encryption_algorithm)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (encryption_algorithm && encryption_algorithm->size() > 32) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> encryption_key_id;
  if (!GetOptionalString(body, "encryptionKeyId", encryption_key_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (encryption_key_id && encryption_key_id->size() > 128) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> encryption_iv;
  if (!GetOptionalString(body, "encryptionIv", encryption_iv)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (encryption_iv && encryption_iv->size() > 128) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> encryption_key_hash;
  if (!GetOptionalString(body, "encryptionKeyHash", encryption_key_hash)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (encryption_key_hash && encryption_key_hash->size() > 128) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  Json::Value metadata(Json::nullValue);
  if (body.isMember("metadata")) {
    if (!body["metadata"].isObject()) {
      callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
      return;
    }
    metadata = body["metadata"];
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  auto conversations = BuildConversationsService();
  if (!conversations.HasMembership(conversation_id, user_id)) {
    callback(http::ErrorResponse(drogon::k403Forbidden,
                                 "Not a member of conversation"));
    return;
  }

  MediaInitInput input;
  input.user_id = user_id;
  input.conversation_id = conversation_id;
  input.content_type = content_type;
  input.file_name = file_name;
  input.size_bytes = size_bytes;
  input.sha256 = sha256;
  input.retention_policy = retention;
  input.encryption_algorithm = encryption_algorithm;
  input.encryption_key_id = encryption_key_id;
  input.encryption_iv = encryption_iv;
  input.encryption_key_hash = encryption_key_hash;
  input.metadata = metadata;

  RespondWithMedia(
      [&input]() {
        auto media = BuildMediaService();
        return media.InitUpload(input);
      },
      std::move(callback));
}

void MediaController::CompleteUpload(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& asset_id) const {
  if (asset_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {"sizeBytes",
                                                          "sha256",
                                                          "metadata",
                                                          "fileName"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::optional<long long> size_bytes;
  if (!GetOptionalInt64(body, "sizeBytes", size_bytes)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (size_bytes && (*size_bytes < 1 || *size_bytes > kMaxMediaBytes)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> sha256;
  if (!GetOptionalString(body, "sha256", sha256)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (sha256 && sha256->size() != 64) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> file_name;
  if (!GetOptionalString(body, "fileName", file_name)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (file_name && file_name->size() > 256) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  Json::Value metadata(Json::objectValue);
  if (!GetOptionalObject(body, "metadata", metadata)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  MediaCompleteInput input;
  input.asset_id = asset_id;
  input.user_id = user_id;
  input.size_bytes = size_bytes;
  input.sha256 = sha256;
  input.metadata = metadata;
  input.file_name = file_name;

  RespondWithMedia(
      [&input]() {
        auto media = BuildMediaService();
        return media.CompleteUpload(input);
      },
      std::move(callback));
}

void MediaController::GetMedia(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& asset_id) const {
  if (asset_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  try {
    auto media = BuildMediaService();
    const auto result = media.GetAssetForUser(asset_id, user_id);
    if (!result.has_value()) {
      callback(http::ErrorResponse(drogon::k404NotFound, "Media not found"));
      return;
    }
    callback(http::JsonResponse(*result, drogon::k200OK));
  } catch (const MediaError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

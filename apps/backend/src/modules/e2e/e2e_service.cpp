#include "modules/e2e/e2e_service.h"

#include <algorithm>
#include <iomanip>
#include <sstream>
#include <string>
#include <utility>

#include <openssl/sha.h>

namespace {

constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

Json::Value NullableString(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return Json::nullValue;
  }
  return Json::Value(field.as<std::string>());
}

bool LooksLikeIsoTimestamp(const std::string& value) {
  if (value.size() < 10) {
    return false;
  }
  if (value.size() >= 19) {
    return value[4] == '-' && value[7] == '-' && value[10] == 'T' &&
           value[13] == ':' && value[16] == ':';
  }
  return true;
}

std::string NormalizeExpiresAt(const std::optional<std::string>& value) {
  if (!value || value->empty()) {
    return "";
  }
  if (!LooksLikeIsoTimestamp(*value)) {
    return "";
  }
  return *value;
}

}  // namespace

E2eService::E2eService(drogon::orm::DbClientPtr db) : db_(std::move(db)) {}

void E2eService::EnsureKeyAccess(const std::string& requester_id,
                                 const std::string& target_user_id) {
  if (requester_id == target_user_id) {
    return;
  }

  const auto rows = db::ExecSqlSync(db_, 
      "SELECT 1 "
      "FROM conversation_members cm1 "
      "JOIN conversation_members cm2 ON cm1.conversation_id = cm2.conversation_id "
      "WHERE cm1.user_id = ? AND cm2.user_id = ? "
      "AND cm1.left_at IS NULL AND cm2.left_at IS NULL "
      "LIMIT 1",
      requester_id,
      target_user_id);

  if (rows.empty()) {
    throw E2eError(drogon::k403Forbidden,
                   "No shared conversation with user");
  }
}

std::string E2eService::Fingerprint(const std::string& key) {
  unsigned char hash[SHA256_DIGEST_LENGTH];
  SHA256(reinterpret_cast<const unsigned char*>(key.data()),
         key.size(),
         hash);

  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (unsigned char byte : hash) {
    stream << std::setw(2) << static_cast<int>(byte);
  }
  return stream.str();
}

void E2eService::UpsertSignedPreKey(
    const std::string& user_id,
    const std::string& device_id,
    const SignedPreKeyInput& signed_pre_key) {
  db::ExecSqlSync(db_, 
      "UPDATE device_signed_prekeys SET revoked_at = NOW() "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL",
      user_id,
      device_id);

  const std::string expires_at = NormalizeExpiresAt(signed_pre_key.expires_at);

  db::ExecSqlSync(db_, 
      "INSERT INTO device_signed_prekeys (user_id, device_id, key_id, public_key, "
      "signature, expires_at) "
      "VALUES (?, ?, ?, ?, ?, NULLIF(?, '')::timestamptz) "
      "ON CONFLICT (user_id, device_id, key_id) DO UPDATE SET "
      "public_key = EXCLUDED.public_key, signature = EXCLUDED.signature, "
      "expires_at = EXCLUDED.expires_at, revoked_at = NULL",
      user_id,
      device_id,
      signed_pre_key.key_id,
      signed_pre_key.public_key,
      signed_pre_key.signature,
      expires_at);
}

Json::Value E2eService::RegisterDeviceKeys(
    const std::string& user_id,
    const std::string& device_id,
    const std::string& platform,
    const std::optional<std::string>& device_name,
    const std::string& identity_key,
    const std::optional<int>& registration_id,
    const SignedPreKeyInput& signed_pre_key,
    const std::vector<PreKeyInput>& one_time_pre_keys) {
  const auto existing = db::ExecSqlSync(db_, 
      "SELECT identity_key FROM device_identity_keys "
      "WHERE user_id = ? AND device_id = ? LIMIT 1",
      user_id,
      device_id);

  const bool identity_changed =
      !existing.empty() &&
      existing.front()["identity_key"].as<std::string>() != identity_key;

  const std::string device_name_value = device_name.value_or("");
  const int registration_value = registration_id.value_or(-1);

  db::ExecSqlSync(db_, 
      "INSERT INTO device_identity_keys (user_id, device_id, platform, device_name, "
      "identity_key, registration_id, updated_at, last_seen_at, revoked_at) "
      "VALUES (?, ?, ?, NULLIF(?, ''), ?, NULLIF(?, -1), NOW(), NOW(), NULL) "
      "ON CONFLICT (user_id, device_id) DO UPDATE SET "
      "platform = EXCLUDED.platform, device_name = EXCLUDED.device_name, "
      "identity_key = EXCLUDED.identity_key, registration_id = EXCLUDED.registration_id, "
      "updated_at = NOW(), last_seen_at = NOW(), revoked_at = NULL",
      user_id,
      device_id,
      platform,
      device_name_value,
      identity_key,
      registration_value);

  if (identity_changed) {
    db::ExecSqlSync(db_, 
        "UPDATE device_signed_prekeys SET revoked_at = NOW() "
        "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL",
        user_id,
        device_id);

    db::ExecSqlSync(db_, 
        "UPDATE device_prekeys SET consumed_at = NOW() "
        "WHERE user_id = ? AND device_id = ? AND consumed_at IS NULL",
        user_id,
        device_id);

    db::ExecSqlSync(db_, 
        "UPDATE device_trust SET status = 'unverified', verified_at = NULL, "
        "updated_at = NOW() "
        "WHERE trusted_user_id = ? AND trusted_device_id = ?",
        user_id,
        device_id);
  }

  UpsertSignedPreKey(user_id, device_id, signed_pre_key);

  for (const auto& key : one_time_pre_keys) {
    db::ExecSqlSync(db_, 
        "INSERT INTO device_prekeys (user_id, device_id, key_id, public_key) "
        "VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING",
        user_id,
        device_id,
        key.key_id,
        key.public_key);
  }

  Json::Value response;
  response["registered"] = true;
  response["preKeysAdded"] = static_cast<int>(one_time_pre_keys.size());
  return response;
}

Json::Value E2eService::UploadPreKeys(
    const std::string& user_id,
    const std::string& device_id,
    const std::vector<PreKeyInput>& pre_keys) {
  const auto device = db::ExecSqlSync(db_, 
      "SELECT user_id FROM device_identity_keys "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL LIMIT 1",
      user_id,
      device_id);
  if (device.empty()) {
    throw E2eError(drogon::k404NotFound, "Device not registered");
  }

  if (pre_keys.empty()) {
    throw E2eError(drogon::k400BadRequest, "No prekeys supplied");
  }

  for (const auto& key : pre_keys) {
    db::ExecSqlSync(db_, 
        "INSERT INTO device_prekeys (user_id, device_id, key_id, public_key) "
        "VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING",
        user_id,
        device_id,
        key.key_id,
        key.public_key);
  }

  Json::Value response;
  response["added"] = static_cast<int>(pre_keys.size());
  return response;
}

Json::Value E2eService::RotateSignedPreKey(
    const std::string& user_id,
    const std::string& device_id,
    const SignedPreKeyInput& signed_pre_key) {
  const auto device = db::ExecSqlSync(db_, 
      "SELECT user_id FROM device_identity_keys "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL LIMIT 1",
      user_id,
      device_id);
  if (device.empty()) {
    throw E2eError(drogon::k404NotFound, "Device not registered");
  }

  UpsertSignedPreKey(user_id, device_id, signed_pre_key);

  Json::Value response;
  response["rotated"] = true;
  return response;
}

Json::Value E2eService::ListDevicesForUser(
    const std::string& requester_id,
    const std::string& target_user_id) {
  EnsureKeyAccess(requester_id, target_user_id);

  const auto rows = db::ExecSqlSync(db_, 
      "SELECT "
      "dik.device_id AS device_id, "
      "dik.platform AS platform, "
      "dik.device_name AS device_name, "
      "dik.identity_key AS identity_key, "
      "dik.registration_id AS registration_id, "
      "to_char(dik.last_seen_at at time zone 'utc', ?) AS last_seen_at, "
      "to_char(dik.revoked_at at time zone 'utc', ?) AS revoked_at, "
      "dt.status AS trust_status, "
      "to_char(dt.verified_at at time zone 'utc', ?) AS verified_at "
      "FROM device_identity_keys dik "
      "LEFT JOIN device_trust dt "
      "  ON dt.trusting_user_id = ? "
      " AND dt.trusted_user_id = dik.user_id "
      " AND dt.trusted_device_id = dik.device_id "
      "WHERE dik.user_id = ? AND dik.revoked_at IS NULL "
      "ORDER BY dik.created_at ASC",
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      requester_id,
      target_user_id);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["deviceId"] = row["device_id"].as<std::string>();
    item["platform"] = row["platform"].as<std::string>();
    item["deviceName"] = NullableString(row["device_name"]);
    item["identityKey"] = row["identity_key"].as<std::string>();
    item["registrationId"] = row["registration_id"].isNull()
                                 ? Json::nullValue
                                 : Json::Value(row["registration_id"].as<int>());
    item["lastSeenAt"] = NullableString(row["last_seen_at"]);
    item["revokedAt"] = NullableString(row["revoked_at"]);
    item["trustStatus"] = NullableString(row["trust_status"]);
    item["verifiedAt"] = NullableString(row["verified_at"]);
    item["identityFingerprint"] =
        row["identity_key"].isNull()
            ? Json::nullValue
            : Json::Value(Fingerprint(row["identity_key"].as<std::string>()));
    items.append(item);
  }

  return items;
}

Json::Value E2eService::GetPreKeyBundle(
    const std::string& requester_id,
    const std::string& target_user_id,
    const std::string& target_device_id) {
  EnsureKeyAccess(requester_id, target_user_id);

  const auto device = db::ExecSqlSync(db_, 
      "SELECT device_id, identity_key, registration_id "
      "FROM device_identity_keys "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL LIMIT 1",
      target_user_id,
      target_device_id);

  if (device.empty()) {
    throw E2eError(drogon::k404NotFound, "Device not found");
  }

  const auto signed_pre_keys = db::ExecSqlSync(db_, 
      "SELECT key_id, public_key, signature "
      "FROM device_signed_prekeys "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL "
      "AND (expires_at IS NULL OR expires_at > NOW()) "
      "ORDER BY created_at DESC LIMIT 1",
      target_user_id,
      target_device_id);

  if (signed_pre_keys.empty()) {
    throw E2eError(drogon::k404NotFound, "Signed prekey missing");
  }

  const auto pre_key_rows = db::ExecSqlSync(db_, 
      "SELECT key_id, public_key "
      "FROM device_prekeys "
      "WHERE user_id = ? AND device_id = ? AND consumed_at IS NULL "
      "ORDER BY created_at ASC "
      "FOR UPDATE SKIP LOCKED "
      "LIMIT 1",
      target_user_id,
      target_device_id);

  Json::Value one_time_pre_key(Json::nullValue);
  if (!pre_key_rows.empty()) {
    const auto& row = pre_key_rows.front();
    one_time_pre_key = Json::Value(Json::objectValue);
    one_time_pre_key["keyId"] = row["key_id"].as<int>();
    one_time_pre_key["publicKey"] = row["public_key"].as<std::string>();

    db::ExecSqlSync(db_, 
        "UPDATE device_prekeys SET consumed_at = NOW() "
        "WHERE user_id = ? AND device_id = ? AND key_id = ?",
        target_user_id,
        target_device_id,
        row["key_id"].as<int>());
  }

  Json::Value response;
  response["deviceId"] = device.front()["device_id"].as<std::string>();
  response["identityKey"] = device.front()["identity_key"].as<std::string>();
  response["identityFingerprint"] =
      Fingerprint(device.front()["identity_key"].as<std::string>());
  response["registrationId"] = device.front()["registration_id"].isNull()
                                   ? Json::nullValue
                                   : Json::Value(
                                         device.front()["registration_id"].as<int>());

  Json::Value signed_pre_key(Json::objectValue);
  signed_pre_key["keyId"] = signed_pre_keys.front()["key_id"].as<int>();
  signed_pre_key["publicKey"] =
      signed_pre_keys.front()["public_key"].as<std::string>();
  signed_pre_key["signature"] =
      signed_pre_keys.front()["signature"].as<std::string>();
  response["signedPreKey"] = signed_pre_key;
  response["oneTimePreKey"] = one_time_pre_key;
  return response;
}

Json::Value E2eService::SetTrust(const std::string& requester_id,
                                 const std::string& target_user_id,
                                 const std::string& target_device_id,
                                 const std::string& status) {
  EnsureKeyAccess(requester_id, target_user_id);

  const auto device = db::ExecSqlSync(db_, 
      "SELECT user_id FROM device_identity_keys "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL LIMIT 1",
      target_user_id,
      target_device_id);
  if (device.empty()) {
    throw E2eError(drogon::k404NotFound, "Device not found");
  }

  db::ExecSqlSync(db_, 
      "INSERT INTO device_trust (trusting_user_id, trusted_user_id, "
      "trusted_device_id, status, verified_at, updated_at) "
      "VALUES (?, ?, ?, ?, CASE WHEN ? = 'trusted' THEN NOW() ELSE NULL END, NOW()) "
      "ON CONFLICT (trusting_user_id, trusted_user_id, trusted_device_id) "
      "DO UPDATE SET status = EXCLUDED.status, "
      "verified_at = CASE WHEN EXCLUDED.status = 'trusted' THEN NOW() ELSE NULL END, "
      "updated_at = NOW()",
      requester_id,
      target_user_id,
      target_device_id,
      status,
      status);

  Json::Value response;
  response["trusted"] = status;
  return response;
}

Json::Value E2eService::ListTrustForUser(const std::string& requester_id,
                                         const std::string& target_user_id) {
  EnsureKeyAccess(requester_id, target_user_id);

  const auto rows = db::ExecSqlSync(db_, 
      "SELECT "
      "dik.device_id AS device_id, "
      "dt.status AS status, "
      "to_char(dt.verified_at at time zone 'utc', ?) AS verified_at "
      "FROM device_identity_keys dik "
      "LEFT JOIN device_trust dt "
      "  ON dt.trusting_user_id = ? "
      " AND dt.trusted_user_id = dik.user_id "
      " AND dt.trusted_device_id = dik.device_id "
      "WHERE dik.user_id = ? AND dik.revoked_at IS NULL "
      "ORDER BY dik.created_at ASC",
      kTimestampFormat,
      requester_id,
      target_user_id);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["deviceId"] = row["device_id"].as<std::string>();
    item["status"] = NullableString(row["status"]);
    item["verifiedAt"] = NullableString(row["verified_at"]);
    items.append(item);
  }

  return items;
}

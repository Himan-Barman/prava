#include "modules/devices/devices_service.h"

#include <string>
#include <utility>

namespace {

constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

Json::Value NullableString(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return Json::nullValue;
  }
  return Json::Value(field.as<std::string>());
}

Json::Value MapPushTokenRow(const drogon::orm::Row& row) {
  Json::Value item;
  item["id"] = row["id"].as<std::string>();
  item["userId"] = row["user_id"].as<std::string>();
  item["deviceId"] = row["device_id"].as<std::string>();
  item["platform"] = row["platform"].as<std::string>();
  item["token"] = row["token"].as<std::string>();
  item["createdAt"] = NullableString(row["created_at"]);
  item["updatedAt"] = NullableString(row["updated_at"]);
  item["revokedAt"] = NullableString(row["revoked_at"]);
  return item;
}

}  // namespace

DevicesService::DevicesService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

Json::Value DevicesService::RegisterPushToken(const std::string& user_id,
                                              const std::string& device_id,
                                              const std::string& platform,
                                              const std::string& token) {
  const auto existing = db::ExecSqlSync(db_, 
      "SELECT id FROM push_tokens WHERE token = ? LIMIT 1",
      token);

  if (!existing.empty()) {
    const std::string token_id = existing.front()["id"].as<std::string>();

    db::ExecSqlSync(db_, 
        "DELETE FROM push_tokens "
        "WHERE user_id = ? AND device_id = ? AND id <> ?",
        user_id,
        device_id,
        token_id);

    const auto updated = db::ExecSqlSync(db_, 
        "UPDATE push_tokens SET user_id = ?, device_id = ?, platform = ?, "
        "updated_at = NOW(), revoked_at = NULL "
        "WHERE id = ? "
        "RETURNING id, user_id, device_id, platform, token, "
        "to_char(created_at at time zone 'utc', ?) AS created_at, "
        "to_char(updated_at at time zone 'utc', ?) AS updated_at, "
        "to_char(revoked_at at time zone 'utc', ?) AS revoked_at",
        user_id,
        device_id,
        platform,
        token_id,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat);

    if (!updated.empty()) {
      return MapPushTokenRow(updated.front());
    }
  }

  const auto rows = db::ExecSqlSync(db_, 
      "INSERT INTO push_tokens (user_id, device_id, platform, token, "
      "updated_at, revoked_at) "
      "VALUES (?, ?, ?, ?, NOW(), NULL) "
      "ON CONFLICT (user_id, device_id) DO UPDATE SET "
      "token = EXCLUDED.token, platform = EXCLUDED.platform, "
      "updated_at = NOW(), revoked_at = NULL "
      "RETURNING id, user_id, device_id, platform, token, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at, "
      "to_char(revoked_at at time zone 'utc', ?) AS revoked_at",
      user_id,
      device_id,
      platform,
      token,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat);

  if (rows.empty()) {
    throw DevicesError(drogon::k500InternalServerError,
                       "Failed to register token");
  }

  return MapPushTokenRow(rows.front());
}

Json::Value DevicesService::RevokePushToken(const std::string& user_id,
                                            const std::string& device_id) {
  db::ExecSqlSync(db_, 
      "UPDATE push_tokens SET revoked_at = NOW(), updated_at = NOW() "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL",
      user_id,
      device_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

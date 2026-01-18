#include "modules/notifications/notifications_service.h"

#include <chrono>
#include <regex>
#include <sstream>
#include <string>
#include <utility>

#include "app_state.h"
#include "realtime/ws_hub.h"

namespace {

constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

int ClampLimit(const std::optional<int>& input,
               int default_value,
               int min_value,
               int max_value) {
  int value = input.value_or(default_value);
  if (value < min_value) {
    value = min_value;
  }
  if (value > max_value) {
    value = max_value;
  }
  return value;
}

bool IsValidCursor(const std::string& cursor) {
  if (cursor.empty()) {
    return false;
  }
  static const std::regex pattern(
      R"(^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$)");
  return std::regex_match(cursor, pattern);
}

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

Json::Value ParseDataField(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return Json::Value(Json::objectValue);
  }
  return ParseJsonText(field.as<std::string>(),
                       Json::Value(Json::objectValue));
}

int64_t NowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

void PublishNotification(const std::string& user_id,
                         const Json::Value& payload) {
  const auto& redis = AppState::Instance().GetRedis();
  if (redis) {
    Json::StreamWriterBuilder builder;
    builder["indentation"] = "";
    const std::string message = Json::writeString(builder, payload);
    const std::string channel = "ws:" + UserTopic(user_id);
    try {
      redis->execCommandSync<int>(
          [](const drogon::nosql::RedisResult&) { return 0; },
          "PUBLISH %s %s",
          channel.c_str(),
          message.c_str());
      return;
    } catch (const std::exception&) {
    }
  }

  WsHub::Instance().PublishToUser(user_id, payload);
}

}  // namespace

NotificationsService::NotificationsService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

Json::Value NotificationsService::ListForUser(
    const std::string& user_id,
    const std::optional<int>& limit,
    const std::optional<std::string>& cursor) {
  const int limit_value = ClampLimit(limit, 30, 1, 50);
  const int fetch_limit = limit_value + 1;
  const bool use_cursor = cursor.has_value() && IsValidCursor(*cursor);

  auto rows = use_cursor
    ? db::ExecSqlSync(db_, 
        "SELECT "
        "n.id, "
        "n.type, "
        "n.title, "
        "n.body, "
        "n.data::text AS data, "
        "to_char(n.read_at at time zone 'utc', ?) AS read_at, "
        "to_char(n.created_at at time zone 'utc', ?) AS created_at, "
        "u.id AS actor_id, "
        "u.username AS actor_username, "
        "u.display_name AS actor_display_name, "
        "u.is_verified AS actor_verified "
        "FROM notifications n "
        "LEFT JOIN users u ON u.id = n.actor_id "
        "WHERE n.user_id = ? AND n.created_at < ?::timestamptz "
        "ORDER BY n.created_at DESC "
        "LIMIT ?",
        kTimestampFormat,
        kTimestampFormat,
        user_id,
        *cursor,
        fetch_limit)
    : db::ExecSqlSync(db_, 
        "SELECT "
        "n.id, "
        "n.type, "
        "n.title, "
        "n.body, "
        "n.data::text AS data, "
        "to_char(n.read_at at time zone 'utc', ?) AS read_at, "
        "to_char(n.created_at at time zone 'utc', ?) AS created_at, "
        "u.id AS actor_id, "
        "u.username AS actor_username, "
        "u.display_name AS actor_display_name, "
        "u.is_verified AS actor_verified "
        "FROM notifications n "
        "LEFT JOIN users u ON u.id = n.actor_id "
        "WHERE n.user_id = ? "
        "ORDER BY n.created_at DESC "
        "LIMIT ?",
        kTimestampFormat,
        kTimestampFormat,
        user_id,
        fetch_limit);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["type"] = row["type"].as<std::string>();
    item["title"] = row["title"].as<std::string>();
    item["body"] = row["body"].as<std::string>();
    item["data"] = ParseDataField(row["data"]);
    item["readAt"] = row["read_at"].isNull()
                         ? Json::nullValue
                         : Json::Value(row["read_at"].as<std::string>());
    item["createdAt"] = row["created_at"].as<std::string>();

    if (row["actor_id"].isNull()) {
      item["actor"] = Json::nullValue;
    } else {
      Json::Value actor;
      actor["id"] = row["actor_id"].as<std::string>();
      actor["username"] = row["actor_username"].as<std::string>();
      if (row["actor_display_name"].isNull()) {
        actor["displayName"] = actor["username"].asString();
      } else {
        actor["displayName"] =
            row["actor_display_name"].as<std::string>();
      }
      actor["isVerified"] = row["actor_verified"].as<bool>();
      item["actor"] = actor;
    }
    items.append(item);
  }

  Json::Value next_cursor = Json::nullValue;
  if (static_cast<int>(items.size()) > limit_value) {
    const Json::Value& last = items[limit_value - 1];
    if (last.isMember("createdAt") && last["createdAt"].isString()) {
      next_cursor = last["createdAt"].asString();
    }

    Json::Value trimmed(Json::arrayValue);
    for (int i = 0; i < limit_value; ++i) {
      trimmed.append(items[i]);
    }
    items = trimmed;
  }

  Json::Value response;
  response["items"] = items;
  response["nextCursor"] = next_cursor;
  response["unreadCount"] = CountUnread(user_id);
  return response;
}

int NotificationsService::CountUnread(const std::string& user_id) {
  const auto rows = db::ExecSqlSync(db_, 
      "SELECT COUNT(*)::int AS count FROM notifications "
      "WHERE user_id = ? AND read_at IS NULL",
      user_id);

  if (rows.empty() || rows.front()["count"].isNull()) {
    return 0;
  }
  return rows.front()["count"].as<int>();
}

Json::Value NotificationsService::MarkRead(
    const std::string& user_id,
    const std::string& notification_id) {
  const auto rows = db::ExecSqlSync(db_, 
      "UPDATE notifications SET read_at = NOW() "
      "WHERE id = ? AND user_id = ? AND read_at IS NULL "
      "RETURNING id",
      notification_id,
      user_id);

  Json::Value response;
  response["success"] = !rows.empty();
  return response;
}

Json::Value NotificationsService::MarkAllRead(const std::string& user_id) {
  db::ExecSqlSync(db_, 
      "UPDATE notifications SET read_at = NOW() "
      "WHERE user_id = ? AND read_at IS NULL",
      user_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

std::optional<Json::Value> NotificationsService::CreateNotification(
    const NotificationInput& input) {
  if (input.actor_id && *input.actor_id == input.user_id) {
    return std::nullopt;
  }

  const std::string actor = input.actor_id.value_or("");
  const std::string data_json =
      ToJsonString(input.data.isNull() ? Json::Value(Json::objectValue)
                                       : input.data);

  const auto rows = db::ExecSqlSync(db_, 
      "INSERT INTO notifications "
      "(user_id, actor_id, type, title, body, data) "
      "VALUES (?, NULLIF(?, ''), ?, ?, ?, ?::jsonb) "
      "RETURNING id, data::text AS data, "
      "to_char(read_at at time zone 'utc', ?) AS read_at, "
      "to_char(created_at at time zone 'utc', ?) AS created_at",
      input.user_id,
      actor,
      input.type,
      input.title,
      input.body,
      data_json,
      kTimestampFormat,
      kTimestampFormat);

  if (rows.empty()) {
    return std::nullopt;
  }

  Json::Value actor_json = Json::nullValue;
  if (input.actor_id) {
    const auto actor_rows = db::ExecSqlSync(db_, 
        "SELECT id, username, display_name, is_verified FROM users "
        "WHERE id = ? LIMIT 1",
        *input.actor_id);

    if (!actor_rows.empty()) {
      const auto& row = actor_rows.front();
      Json::Value actor_value;
      actor_value["id"] = row["id"].as<std::string>();
      actor_value["username"] = row["username"].as<std::string>();
      if (row["display_name"].isNull()) {
        actor_value["displayName"] = actor_value["username"].asString();
      } else {
        actor_value["displayName"] =
            row["display_name"].as<std::string>();
      }
      actor_value["isVerified"] = row["is_verified"].as<bool>();
      actor_json = actor_value;
    }
  }

  const auto& row = rows.front();
  Json::Value payload;
  payload["id"] = row["id"].as<std::string>();
  payload["type"] = input.type;
  payload["title"] = input.title;
  payload["body"] = input.body;
  payload["data"] = ParseDataField(row["data"]);
  payload["readAt"] = row["read_at"].isNull()
                          ? Json::nullValue
                          : Json::Value(row["read_at"].as<std::string>());
  payload["createdAt"] = row["created_at"].as<std::string>();
  payload["actor"] = actor_json;

  Json::Value event;
  event["type"] = "NOTIFICATION_PUSH";
  event["payload"] = payload;
  event["ts"] = static_cast<Json::Int64>(NowMs());
  PublishNotification(input.user_id, event);

  return payload;
}

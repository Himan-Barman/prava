#include "modules/messages/messages_service.h"

#include <algorithm>
#include <chrono>
#include <cctype>
#include <optional>
#include <sstream>
#include <string>
#include <utility>

#include <json/json.h>

namespace {

constexpr int kMaxMessageBodyLength = 65535;
constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

Json::Value NullableString(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return Json::nullValue;
  }
  return Json::Value(field.as<std::string>());
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

Json::Value MapMessageRow(const drogon::orm::Row& row) {
  Json::Value item;
  item["id"] = row["id"].as<std::string>();
  item["conversationId"] = row["conversation_id"].as<std::string>();
  item["senderUserId"] = row["sender_user_id"].as<std::string>();
  item["senderDeviceId"] = row["sender_device_id"].as<std::string>();
  item["seq"] = row["seq"].as<int>();
  item["contentType"] = row["content_type"].as<std::string>();
  item["body"] = row["body"].as<std::string>();
  item["clientTempId"] = NullableString(row["client_temp_id"]);
  item["mediaAssetId"] = NullableString(row["media_asset_id"]);
  item["editVersion"] = row["edit_version"].as<int>();
  item["clientTimestamp"] = NullableString(row["client_timestamp"]);
  item["createdAt"] = NullableString(row["created_at"]);
  item["deliveredAt"] = NullableString(row["delivered_at"]);
  item["readAt"] = NullableString(row["read_at"]);
  item["deletedForAllAt"] = NullableString(row["deleted_for_all_at"]);
  return item;
}

void AssertMediaAssetReady(drogon::orm::DbClientPtr db,
                           const std::string& asset_id,
                           const std::string& user_id,
                           const std::string& conversation_id) {
  const auto rows = db->execSqlSync(
      "SELECT id, user_id, conversation_id, status "
      "FROM media_assets WHERE id = ? LIMIT 1",
      asset_id);

  if (rows.empty()) {
    throw MessagesError(drogon::k400BadRequest, "Media asset not found");
  }

  const auto& row = rows.front();
  const std::string owner_id = row["user_id"].as<std::string>();
  if (owner_id != user_id) {
    throw MessagesError(drogon::k403Forbidden, "Media asset not owned");
  }

  if (!row["conversation_id"].isNull()) {
    const std::string asset_conversation =
        row["conversation_id"].as<std::string>();
    if (asset_conversation != conversation_id) {
      throw MessagesError(drogon::k400BadRequest,
                          "Media asset is not in this conversation");
    }
  } else {
    db->execSqlSync(
        "UPDATE media_assets SET conversation_id = ?, updated_at = NOW() "
        "WHERE id = ?",
        conversation_id,
        asset_id);
  }

  const std::string status = row["status"].as<std::string>();
  if (status != "ready") {
    throw MessagesError(drogon::k400BadRequest, "Media is not ready");
  }
}

}  // namespace

MessagesService::MessagesService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

Json::Value MessagesService::SendMessage(const SendMessageInput& input) {
  std::string content_type = input.content_type.empty() ? "text"
                                                        : input.content_type;
  std::string body = input.body;

  if (content_type != "text" && content_type != "system" &&
      content_type != "media") {
    throw MessagesError(drogon::k400BadRequest, "Invalid content type");
  }

  if (content_type == "media") {
    if (!input.media_asset_id || input.media_asset_id->empty()) {
      throw MessagesError(drogon::k400BadRequest,
                          "Media asset is required for media messages");
    }

    if (body.size() > static_cast<size_t>(kMaxMessageBodyLength)) {
      throw MessagesError(drogon::k400BadRequest, "Invalid body length");
    }

    AssertMediaAssetReady(db_, *input.media_asset_id, input.sender_user_id,
                          input.conversation_id);
  } else {
    if (body.empty() || body.size() > static_cast<size_t>(kMaxMessageBodyLength)) {
      throw MessagesError(drogon::k400BadRequest, "Invalid body length");
    }

    if (input.media_asset_id && !input.media_asset_id->empty()) {
      throw MessagesError(drogon::k400BadRequest,
                          "Media asset only allowed for media messages");
    }
  }

  if (input.client_temp_id && !input.client_temp_id->empty()) {
    const auto existing = db_->execSqlSync(
        "SELECT id, conversation_id, sender_user_id, sender_device_id, seq, "
        "content_type, body, client_temp_id, media_asset_id, edit_version, "
        "to_char(client_timestamp at time zone 'utc', ?) AS client_timestamp, "
        "to_char(created_at at time zone 'utc', ?) AS created_at, "
        "to_char(delivered_at at time zone 'utc', ?) AS delivered_at, "
        "to_char(read_at at time zone 'utc', ?) AS read_at, "
        "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at "
        "FROM messages "
        "WHERE conversation_id = ? AND sender_user_id = ? AND sender_device_id = ? "
        "AND client_temp_id = ? "
        "LIMIT 1",
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        input.conversation_id,
        input.sender_user_id,
        input.sender_device_id,
        *input.client_temp_id);

    if (!existing.empty()) {
      Json::Value response;
      response["message"] = MapMessageRow(existing.front());
      response["message"]["reactions"] = Json::Value(Json::arrayValue);
      response["created"] = false;
      return response;
    }
  }

  const auto convo_rows = db_->execSqlSync(
      "SELECT id FROM conversations WHERE id = ? FOR UPDATE",
      input.conversation_id);
  if (convo_rows.empty()) {
    throw MessagesError(drogon::k400BadRequest, "Conversation not found");
  }

  const auto seq_rows = db_->execSqlSync(
      "SELECT COALESCE(MAX(seq), 0) + 1 AS next "
      "FROM messages WHERE conversation_id = ?",
      input.conversation_id);
  const int next_seq = seq_rows.empty() || seq_rows.front()["next"].isNull()
                           ? 1
                           : seq_rows.front()["next"].as<int>();

  std::string client_temp = input.client_temp_id.value_or("");
  std::string media_asset = input.media_asset_id.value_or("");
  std::string client_timestamp = input.client_timestamp.value_or("");

  std::optional<drogon::orm::Result> inserted;
  try {
    inserted = db_->execSqlSync(
        "INSERT INTO messages (conversation_id, sender_user_id, sender_device_id, "
        "body, content_type, client_timestamp, client_temp_id, media_asset_id, seq) "
        "VALUES (?, ?, ?, ?, ?, NULLIF(?, '')::timestamptz, "
        "NULLIF(?, ''), NULLIF(?, '')::uuid, ?) "
        "RETURNING id, conversation_id, sender_user_id, sender_device_id, seq, "
        "content_type, body, client_temp_id, media_asset_id, edit_version, "
        "to_char(client_timestamp at time zone 'utc', ?) AS client_timestamp, "
        "to_char(created_at at time zone 'utc', ?) AS created_at, "
        "to_char(delivered_at at time zone 'utc', ?) AS delivered_at, "
        "to_char(read_at at time zone 'utc', ?) AS read_at, "
        "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at",
        input.conversation_id,
        input.sender_user_id,
        input.sender_device_id,
        body,
        content_type,
        client_timestamp,
        client_temp,
        media_asset,
        next_seq,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat);
  } catch (const std::exception&) {
    if (input.client_temp_id && !input.client_temp_id->empty()) {
      const auto existing = db_->execSqlSync(
          "SELECT id, conversation_id, sender_user_id, sender_device_id, seq, "
          "content_type, body, client_temp_id, media_asset_id, edit_version, "
          "to_char(client_timestamp at time zone 'utc', ?) AS client_timestamp, "
          "to_char(created_at at time zone 'utc', ?) AS created_at, "
          "to_char(delivered_at at time zone 'utc', ?) AS delivered_at, "
          "to_char(read_at at time zone 'utc', ?) AS read_at, "
          "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at "
          "FROM messages "
          "WHERE conversation_id = ? AND sender_user_id = ? AND sender_device_id = ? "
          "AND client_temp_id = ? "
          "LIMIT 1",
          kTimestampFormat,
          kTimestampFormat,
          kTimestampFormat,
          kTimestampFormat,
          kTimestampFormat,
          input.conversation_id,
          input.sender_user_id,
          input.sender_device_id,
          *input.client_temp_id);

      if (!existing.empty()) {
        Json::Value response;
        response["message"] = MapMessageRow(existing.front());
        response["message"]["reactions"] = Json::Value(Json::arrayValue);
        response["created"] = false;
        return response;
      }
    }
    throw;
  }

  if (!inserted.has_value() || inserted->empty()) {
    throw MessagesError(drogon::k500InternalServerError,
                        "Failed to create message");
  }

  db_->execSqlSync(
      "UPDATE conversations SET updated_at = NOW() WHERE id = ?",
      input.conversation_id);

  Json::Value response;
  response["message"] = MapMessageRow(inserted->front());
  response["message"]["reactions"] = Json::Value(Json::arrayValue);
  response["created"] = true;
  return response;
}

Json::Value MessagesService::ListMessages(
    const std::string& conversation_id,
    const std::optional<int>& before_seq,
    const std::optional<int>& limit) {
  const int limit_value = ClampLimit(limit, 50, 1, 100);
  const bool use_before = before_seq.has_value();

  auto rows = use_before
    ? db_->execSqlSync(
        "SELECT "
        "m.id AS id, "
        "m.conversation_id AS conversation_id, "
        "m.sender_user_id AS sender_user_id, "
        "m.sender_device_id AS sender_device_id, "
        "m.seq AS seq, "
        "m.content_type AS content_type, "
        "m.body AS body, "
        "m.client_temp_id AS client_temp_id, "
        "m.media_asset_id AS media_asset_id, "
        "m.edit_version AS edit_version, "
        "to_char(m.client_timestamp at time zone 'utc', ?) AS client_timestamp, "
        "to_char(m.created_at at time zone 'utc', ?) AS created_at, "
        "to_char(m.delivered_at at time zone 'utc', ?) AS delivered_at, "
        "to_char(m.read_at at time zone 'utc', ?) AS read_at, "
        "to_char(m.deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at, "
        "COALESCE(json_agg(json_build_object("
        "'userId', mr.user_id, "
        "'emoji', mr.emoji, "
        "'reactedAt', to_char(mr.reacted_at at time zone 'utc', ?), "
        "'updatedAt', to_char(mr.updated_at at time zone 'utc', ?)"
        ")) FILTER (WHERE mr.message_id IS NOT NULL), '[]'::json) AS reactions "
        "FROM messages m "
        "LEFT JOIN message_reactions mr ON mr.message_id = m.id "
        "WHERE m.conversation_id = ? AND m.seq < ? "
        "GROUP BY m.id "
        "ORDER BY m.seq DESC "
        "LIMIT ?",
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        conversation_id,
        before_seq.value(),
        limit_value)
    : db_->execSqlSync(
        "SELECT "
        "m.id AS id, "
        "m.conversation_id AS conversation_id, "
        "m.sender_user_id AS sender_user_id, "
        "m.sender_device_id AS sender_device_id, "
        "m.seq AS seq, "
        "m.content_type AS content_type, "
        "m.body AS body, "
        "m.client_temp_id AS client_temp_id, "
        "m.media_asset_id AS media_asset_id, "
        "m.edit_version AS edit_version, "
        "to_char(m.client_timestamp at time zone 'utc', ?) AS client_timestamp, "
        "to_char(m.created_at at time zone 'utc', ?) AS created_at, "
        "to_char(m.delivered_at at time zone 'utc', ?) AS delivered_at, "
        "to_char(m.read_at at time zone 'utc', ?) AS read_at, "
        "to_char(m.deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at, "
        "COALESCE(json_agg(json_build_object("
        "'userId', mr.user_id, "
        "'emoji', mr.emoji, "
        "'reactedAt', to_char(mr.reacted_at at time zone 'utc', ?), "
        "'updatedAt', to_char(mr.updated_at at time zone 'utc', ?)"
        ")) FILTER (WHERE mr.message_id IS NOT NULL), '[]'::json) AS reactions "
        "FROM messages m "
        "LEFT JOIN message_reactions mr ON mr.message_id = m.id "
        "WHERE m.conversation_id = ? "
        "GROUP BY m.id "
        "ORDER BY m.seq DESC "
        "LIMIT ?",
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        kTimestampFormat,
        conversation_id,
        limit_value);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item = MapMessageRow(row);
    const std::string reactions_text =
        row["reactions"].isNull() ? "[]" : row["reactions"].as<std::string>();
    item["reactions"] = ParseJsonText(reactions_text,
                                      Json::Value(Json::arrayValue));
    items.append(item);
  }

  Json::Value ordered(Json::arrayValue);
  for (Json::ArrayIndex i = items.size(); i > 0; --i) {
    ordered.append(items[i - 1]);
  }

  return ordered;
}

void MessagesService::MarkRead(const ReceiptInput& input) {
  const auto existing = db_->execSqlSync(
      "SELECT last_read_seq, last_delivered_seq "
      "FROM sync_state WHERE user_id = ? AND device_id = ? AND conversation_id = ? "
      "LIMIT 1",
      input.user_id,
      input.device_id,
      input.conversation_id);

  const int prev_read =
      existing.empty() || existing.front()["last_read_seq"].isNull()
          ? 0
          : existing.front()["last_read_seq"].as<int>();

  db_->execSqlSync(
      "UPDATE conversation_members "
      "SET last_read_seq = GREATEST(COALESCE(last_read_seq, 0), ?) "
      "WHERE conversation_id = ? AND user_id = ? AND left_at IS NULL",
      input.seq,
      input.conversation_id,
      input.user_id);

  db_->execSqlSync(
      "INSERT INTO sync_state (user_id, device_id, conversation_id, "
      "last_delivered_seq, last_read_seq, last_sync_at, updated_at) "
      "VALUES (?, ?, ?, ?, ?, NOW(), NOW()) "
      "ON CONFLICT (user_id, device_id, conversation_id) DO UPDATE SET "
      "last_read_seq = GREATEST(COALESCE(sync_state.last_read_seq, 0), EXCLUDED.last_read_seq), "
      "last_delivered_seq = GREATEST(COALESCE(sync_state.last_delivered_seq, 0), EXCLUDED.last_read_seq), "
      "last_sync_at = NOW(), updated_at = NOW()",
      input.user_id,
      input.device_id,
      input.conversation_id,
      input.seq,
      input.seq);

  if (input.seq > prev_read) {
    db_->execSqlSync(
        "INSERT INTO message_device_states (message_id, device_id, delivered_at, read_at) "
        "SELECT m.id, ?, NOW(), NOW() "
        "FROM messages m "
        "WHERE m.conversation_id = ? AND m.seq > ? AND m.seq <= ? "
        "ON CONFLICT (message_id, device_id) DO UPDATE SET "
        "delivered_at = COALESCE(message_device_states.delivered_at, EXCLUDED.delivered_at), "
        "read_at = COALESCE(message_device_states.read_at, EXCLUDED.read_at)",
        input.device_id,
        input.conversation_id,
        prev_read,
        input.seq);

    db_->execSqlSync(
        "DELETE FROM message_retries mr "
        "USING messages m "
        "WHERE mr.message_id = m.id AND mr.device_id = ? "
        "AND m.conversation_id = ? AND m.seq <= ?",
        input.device_id,
        input.conversation_id,
        input.seq);
  }
}

void MessagesService::MarkDelivered(const ReceiptInput& input) {
  const auto existing = db_->execSqlSync(
      "SELECT last_delivered_seq "
      "FROM sync_state WHERE user_id = ? AND device_id = ? AND conversation_id = ? "
      "LIMIT 1",
      input.user_id,
      input.device_id,
      input.conversation_id);

  const int prev_delivered =
      existing.empty() || existing.front()["last_delivered_seq"].isNull()
          ? 0
          : existing.front()["last_delivered_seq"].as<int>();

  db_->execSqlSync(
      "INSERT INTO sync_state (user_id, device_id, conversation_id, "
      "last_delivered_seq, last_sync_at, updated_at) "
      "VALUES (?, ?, ?, ?, NOW(), NOW()) "
      "ON CONFLICT (user_id, device_id, conversation_id) DO UPDATE SET "
      "last_delivered_seq = GREATEST(COALESCE(sync_state.last_delivered_seq, 0), EXCLUDED.last_delivered_seq), "
      "last_sync_at = NOW(), updated_at = NOW()",
      input.user_id,
      input.device_id,
      input.conversation_id,
      input.seq);

  if (input.seq > prev_delivered) {
    db_->execSqlSync(
        "INSERT INTO message_device_states (message_id, device_id, delivered_at) "
        "SELECT m.id, ?, NOW() "
        "FROM messages m "
        "WHERE m.conversation_id = ? AND m.seq > ? AND m.seq <= ? "
        "ON CONFLICT (message_id, device_id) DO UPDATE SET "
        "delivered_at = COALESCE(message_device_states.delivered_at, EXCLUDED.delivered_at)",
        input.device_id,
        input.conversation_id,
        prev_delivered,
        input.seq);

    db_->execSqlSync(
        "DELETE FROM message_retries mr "
        "USING messages m "
        "WHERE mr.message_id = m.id AND mr.device_id = ? "
        "AND m.conversation_id = ? AND m.seq <= ?",
        input.device_id,
        input.conversation_id,
        input.seq);
  }
}

std::optional<Json::Value> MessagesService::GetMessage(
    const std::string& conversation_id,
    const std::string& message_id) {
  const auto rows = db_->execSqlSync(
      "SELECT id, conversation_id, sender_user_id, sender_device_id, seq, "
      "content_type, body, client_temp_id, media_asset_id, edit_version, "
      "to_char(client_timestamp at time zone 'utc', ?) AS client_timestamp, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(delivered_at at time zone 'utc', ?) AS delivered_at, "
      "to_char(read_at at time zone 'utc', ?) AS read_at, "
      "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at "
      "FROM messages "
      "WHERE id = ? AND conversation_id = ? "
      "LIMIT 1",
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      message_id,
      conversation_id);

  if (rows.empty()) {
    return std::nullopt;
  }

  return MapMessageRow(rows.front());
}

Json::Value MessagesService::ListMessageReceipts(
    const std::string& conversation_id,
    const std::string& message_id) {
  const auto rows = db_->execSqlSync(
      "SELECT DISTINCT ON (mds.device_id) "
      "mds.device_id AS device_id, "
      "to_char(mds.delivered_at at time zone 'utc', ?) AS delivered_at, "
      "to_char(mds.read_at at time zone 'utc', ?) AS read_at, "
      "ss.user_id AS user_id "
      "FROM message_device_states mds "
      "LEFT JOIN sync_state ss ON ss.device_id = mds.device_id "
      "AND ss.conversation_id = ? "
      "WHERE mds.message_id = ? "
      "ORDER BY mds.device_id, ss.updated_at DESC NULLS LAST",
      kTimestampFormat,
      kTimestampFormat,
      conversation_id,
      message_id);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["deviceId"] = row["device_id"].as<std::string>();
    item["deliveredAt"] = NullableString(row["delivered_at"]);
    item["readAt"] = NullableString(row["read_at"]);
    item["userId"] = NullableString(row["user_id"]);
    items.append(item);
  }

  return items;
}

std::optional<Json::Value> MessagesService::EditMessage(
    const std::string& conversation_id,
    const std::string& message_id,
    const std::string& user_id,
    const std::string& body) {
  const auto rows = db_->execSqlSync(
      "UPDATE messages SET body = ?, edit_version = edit_version + 1 "
      "WHERE id = ? AND conversation_id = ? AND sender_user_id = ? "
      "AND content_type = 'text' AND deleted_for_all_at IS NULL "
      "RETURNING id, conversation_id, sender_user_id, sender_device_id, seq, "
      "content_type, body, client_temp_id, media_asset_id, edit_version, "
      "to_char(client_timestamp at time zone 'utc', ?) AS client_timestamp, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(delivered_at at time zone 'utc', ?) AS delivered_at, "
      "to_char(read_at at time zone 'utc', ?) AS read_at, "
      "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at",
      body,
      message_id,
      conversation_id,
      user_id,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat);

  if (rows.empty()) {
    return std::nullopt;
  }

  return MapMessageRow(rows.front());
}

std::optional<Json::Value> MessagesService::DeleteMessageForAll(
    const std::string& conversation_id,
    const std::string& message_id,
    const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "UPDATE messages SET deleted_for_all_at = NOW(), body = '', "
      "content_type = 'system' "
      "WHERE id = ? AND conversation_id = ? AND sender_user_id = ? "
      "AND deleted_for_all_at IS NULL "
      "RETURNING id, conversation_id, sender_user_id, sender_device_id, seq, "
      "content_type, body, client_temp_id, media_asset_id, edit_version, "
      "to_char(client_timestamp at time zone 'utc', ?) AS client_timestamp, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(delivered_at at time zone 'utc', ?) AS delivered_at, "
      "to_char(read_at at time zone 'utc', ?) AS read_at, "
      "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at",
      message_id,
      conversation_id,
      user_id,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat);

  if (rows.empty()) {
    return std::nullopt;
  }

  return MapMessageRow(rows.front());
}

std::optional<Json::Value> MessagesService::SetReaction(
    const ReactionInput& input) {
  const auto exists = db_->execSqlSync(
      "SELECT id FROM messages WHERE id = ? AND conversation_id = ? "
      "AND deleted_for_all_at IS NULL LIMIT 1",
      input.message_id,
      input.conversation_id);

  if (exists.empty()) {
    return std::nullopt;
  }

  const auto rows = db_->execSqlSync(
      "INSERT INTO message_reactions (message_id, user_id, emoji, reacted_at, updated_at) "
      "VALUES (?, ?, ?, NOW(), NOW()) "
      "ON CONFLICT (message_id, user_id) DO UPDATE SET "
      "emoji = EXCLUDED.emoji, updated_at = NOW() "
      "RETURNING message_id, user_id, emoji, "
      "to_char(reacted_at at time zone 'utc', ?) AS reacted_at, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at",
      input.message_id,
      input.user_id,
      input.emoji,
      kTimestampFormat,
      kTimestampFormat);

  if (rows.empty()) {
    return std::nullopt;
  }

  const auto& row = rows.front();
  Json::Value reaction;
  reaction["messageId"] = row["message_id"].as<std::string>();
  reaction["userId"] = row["user_id"].as<std::string>();
  reaction["emoji"] = row["emoji"].as<std::string>();
  reaction["reactedAt"] = NullableString(row["reacted_at"]);
  reaction["updatedAt"] = NullableString(row["updated_at"]);
  return reaction;
}

bool MessagesService::RemoveReaction(const std::string& conversation_id,
                                     const std::string& message_id,
                                     const std::string& user_id) {
  const auto exists = db_->execSqlSync(
      "SELECT id FROM messages WHERE id = ? AND conversation_id = ? LIMIT 1",
      message_id,
      conversation_id);
  if (exists.empty()) {
    return false;
  }

  const auto rows = db_->execSqlSync(
      "DELETE FROM message_reactions WHERE message_id = ? AND user_id = ? "
      "RETURNING message_id",
      message_id,
      user_id);
  return !rows.empty();
}

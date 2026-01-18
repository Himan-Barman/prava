#include "realtime/sync_service.h"

#include <string>

namespace {

constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

std::optional<std::string> NullableString(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return std::nullopt;
  }
  return field.as<std::string>();
}

}  // namespace

SyncService::SyncService(drogon::orm::DbClientPtr db) : db_(std::move(db)) {}

std::vector<SyncMessage> SyncService::SyncConversation(
    const SyncInput& input) {
  if (!db_) {
    return {};
  }

  db_->execSqlSync(
      "INSERT INTO sync_state (user_id, device_id, conversation_id, "
      "last_delivered_seq, last_sync_at, updated_at) "
      "VALUES (?, ?, ?, ?, NOW(), NOW()) "
      "ON CONFLICT (user_id, device_id, conversation_id) DO UPDATE SET "
      "last_delivered_seq = GREATEST(COALESCE(sync_state.last_delivered_seq, 0), "
      "EXCLUDED.last_delivered_seq), "
      "last_sync_at = NOW(), updated_at = NOW()",
      input.user_id,
      input.device_id,
      input.conversation_id,
      input.last_delivered_seq);

  const auto rows = db_->execSqlSync(
      "SELECT id, conversation_id, sender_user_id, sender_device_id, seq, "
      "content_type, body, media_asset_id, edit_version, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(deleted_for_all_at at time zone 'utc', ?) AS deleted_for_all_at "
      "FROM messages "
      "WHERE conversation_id = ? AND seq > ? "
      "ORDER BY seq ASC "
      "LIMIT 500",
      kTimestampFormat,
      kTimestampFormat,
      input.conversation_id,
      input.last_delivered_seq);

  std::vector<SyncMessage> messages;
  messages.reserve(rows.size());
  for (const auto& row : rows) {
    SyncMessage msg;
    msg.id = row["id"].as<std::string>();
    msg.conversation_id = row["conversation_id"].as<std::string>();
    msg.seq = row["seq"].as<int>();
    msg.sender_user_id = row["sender_user_id"].as<std::string>();
    msg.sender_device_id = row["sender_device_id"].as<std::string>();
    msg.content_type = row["content_type"].as<std::string>();
    msg.body = row["body"].as<std::string>();
    msg.media_asset_id = NullableString(row["media_asset_id"]);
    msg.edit_version = row["edit_version"].as<int>();
    msg.created_at = row["created_at"].as<std::string>();
    msg.deleted_for_all_at = NullableString(row["deleted_for_all_at"]);
    messages.push_back(std::move(msg));
  }

  return messages;
}

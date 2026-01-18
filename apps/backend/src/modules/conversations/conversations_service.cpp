#include "modules/conversations/conversations_service.h"

#include <unordered_set>
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

}  // namespace

ConversationsService::ConversationsService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

bool ConversationsService::HasMembership(const std::string& conversation_id,
                                         const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT user_id FROM conversation_members "
      "WHERE conversation_id = ? AND user_id = ? AND left_at IS NULL "
      "LIMIT 1",
      conversation_id,
      user_id);
  return !rows.empty();
}

std::string ConversationsService::MembershipRole(
    const std::string& conversation_id,
    const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT role FROM conversation_members "
      "WHERE conversation_id = ? AND user_id = ? AND left_at IS NULL "
      "LIMIT 1",
      conversation_id,
      user_id);
  if (rows.empty() || rows.front()["role"].isNull()) {
    return "";
  }
  return rows.front()["role"].as<std::string>();
}

std::vector<std::string> ConversationsService::ListConversationIdsForUser(
    const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT conversation_id FROM conversation_members "
      "WHERE user_id = ? AND left_at IS NULL",
      user_id);

  std::vector<std::string> ids;
  ids.reserve(rows.size());
  for (const auto& row : rows) {
    ids.push_back(row["conversation_id"].as<std::string>());
  }
  return ids;
}

Json::Value ConversationsService::ListForUser(const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT "
      "c.id, "
      "c.type, "
      "c.title, "
      "to_char(c.created_at at time zone 'utc', ?) AS created_at, "
      "to_char(c.updated_at at time zone 'utc', ?) AS updated_at, "
      "cm.role, "
      "cm.last_read_seq, "
      "GREATEST(COALESCE(lm.seq, 0) - COALESCE(cm.last_read_seq, 0), 0) AS unread_count, "
      "lm.id AS last_message_id, "
      "lm.seq AS last_message_seq, "
      "lm.sender_user_id AS last_message_sender_user_id, "
      "lm.body AS last_message_body, "
      "lm.content_type AS last_message_content_type, "
      "lm.edit_version AS last_message_edit_version, "
      "to_char(lm.deleted_for_all_at at time zone 'utc', ?) AS last_message_deleted_for_all_at, "
      "to_char(lm.created_at at time zone 'utc', ?) AS last_message_created_at "
      "FROM conversation_members cm "
      "JOIN conversations c ON c.id = cm.conversation_id "
      "LEFT JOIN LATERAL ("
      "  SELECT m.id, m.seq, m.sender_user_id, m.body, m.content_type, "
      "         m.edit_version, m.deleted_for_all_at, m.created_at "
      "  FROM messages m "
      "  WHERE m.conversation_id = c.id "
      "  ORDER BY m.seq DESC "
      "  LIMIT 1"
      ") lm ON TRUE "
      "WHERE cm.user_id = ? AND cm.left_at IS NULL "
      "ORDER BY c.updated_at DESC",
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      user_id);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["type"] = row["type"].as<std::string>();
    item["title"] = NullableString(row["title"]);
    item["createdAt"] = row["created_at"].as<std::string>();
    item["updatedAt"] = row["updated_at"].as<std::string>();
    item["role"] = row["role"].as<std::string>();
    item["lastReadSeq"] = row["last_read_seq"].isNull()
                              ? Json::nullValue
                              : Json::Value(row["last_read_seq"].as<int>());
    item["unreadCount"] = row["unread_count"].isNull()
                              ? 0
                              : row["unread_count"].as<int>();
    item["lastMessageId"] = NullableString(row["last_message_id"]);
    item["lastMessageSeq"] = row["last_message_seq"].isNull()
                                 ? Json::nullValue
                                 : Json::Value(row["last_message_seq"].as<int>());
    item["lastMessageSenderUserId"] =
        NullableString(row["last_message_sender_user_id"]);
    item["lastMessageBody"] = NullableString(row["last_message_body"]);
    item["lastMessageContentType"] =
        NullableString(row["last_message_content_type"]);
    item["lastMessageEditVersion"] =
        row["last_message_edit_version"].isNull()
            ? Json::nullValue
            : Json::Value(row["last_message_edit_version"].as<int>());
    item["lastMessageDeletedForAllAt"] =
        row["last_message_deleted_for_all_at"].isNull()
            ? Json::nullValue
            : Json::Value(
                  row["last_message_deleted_for_all_at"].as<std::string>());
    item["lastMessageCreatedAt"] =
        row["last_message_created_at"].isNull()
            ? Json::nullValue
            : Json::Value(row["last_message_created_at"].as<std::string>());
    items.append(item);
  }

  return items;
}

Json::Value ConversationsService::CreateDm(const std::string& user_id,
                                           const std::string& other_user_id) {
  if (user_id == other_user_id) {
    throw ConversationsError(drogon::k400BadRequest,
                             "Cannot create DM with self");
  }

  const auto existing = db_->execSqlSync(
      "SELECT c.id "
      "FROM conversations c "
      "JOIN conversation_members cm1 ON cm1.conversation_id = c.id "
      "JOIN conversation_members cm2 ON cm2.conversation_id = c.id "
      "WHERE c.type = 'dm' "
      "  AND cm1.user_id = ? "
      "  AND cm2.user_id = ? "
      "  AND cm1.left_at IS NULL "
      "  AND cm2.left_at IS NULL "
      "LIMIT 1",
      user_id,
      other_user_id);

  if (!existing.empty()) {
    Json::Value response;
    response["conversationId"] = existing.front()["id"].as<std::string>();
    response["created"] = false;
    return response;
  }

  const auto convo_rows = db_->execSqlSync(
      "INSERT INTO conversations (type, created_by_user_id) "
      "VALUES ('dm', ?) "
      "RETURNING id",
      user_id);

  if (convo_rows.empty()) {
    throw ConversationsError(drogon::k500InternalServerError,
                             "Failed to create DM");
  }

  const std::string conversation_id =
      convo_rows.front()["id"].as<std::string>();

  db_->execSqlSync(
      "INSERT INTO conversation_members (conversation_id, user_id, role) "
      "VALUES (?, ?, 'member'), (?, ?, 'member')",
      conversation_id,
      user_id,
      conversation_id,
      other_user_id);

  Json::Value response;
  response["conversationId"] = conversation_id;
  response["created"] = true;
  return response;
}

Json::Value ConversationsService::CreateGroup(const CreateGroupInput& input) {
  const std::string title = input.title;
  if (title.empty()) {
    throw ConversationsError(drogon::k400BadRequest,
                             "Invalid group title");
  }

  std::unordered_set<std::string> unique;
  unique.insert(input.user_id);
  for (const auto& member : input.member_ids) {
    if (!member.empty()) {
      unique.insert(member);
    }
  }

  const auto convo_rows = db_->execSqlSync(
      "INSERT INTO conversations (type, title, created_by_user_id) "
      "VALUES ('group', ?, ?) "
      "RETURNING id",
      title,
      input.user_id);

  if (convo_rows.empty()) {
    throw ConversationsError(drogon::k500InternalServerError,
                             "Failed to create group");
  }

  const std::string conversation_id =
      convo_rows.front()["id"].as<std::string>();

  for (const auto& member_id : unique) {
    const std::string role =
        member_id == input.user_id ? "admin" : "member";
    db_->execSqlSync(
        "INSERT INTO conversation_members (conversation_id, user_id, role) "
        "VALUES (?, ?, ?) ON CONFLICT DO NOTHING",
        conversation_id,
        member_id,
        role);
  }

  Json::Value response;
  response["conversationId"] = conversation_id;
  return response;
}

Json::Value ConversationsService::AddMembers(const AddMembersInput& input) {
  if (!HasMembership(input.conversation_id, input.requester_id)) {
    throw ConversationsError(drogon::k400BadRequest,
                             "Not a member of conversation");
  }

  const auto convo_rows = db_->execSqlSync(
      "SELECT type FROM conversations WHERE id = ? LIMIT 1",
      input.conversation_id);
  if (!convo_rows.empty()) {
    const std::string type = convo_rows.front()["type"].as<std::string>();
    if (type == "dm") {
      throw ConversationsError(drogon::k400BadRequest,
                               "Cannot add members to a DM");
    }
  }

  const std::string role =
      MembershipRole(input.conversation_id, input.requester_id);
  if (role != "admin") {
    throw ConversationsError(drogon::k400BadRequest,
                             "Only admins can add members");
  }

  std::unordered_set<std::string> unique;
  for (const auto& member : input.member_ids) {
    if (!member.empty()) {
      unique.insert(member);
    }
  }

  if (unique.empty()) {
    Json::Value response;
    response["added"] = 0;
    return response;
  }

  for (const auto& member_id : unique) {
    db_->execSqlSync(
        "INSERT INTO conversation_members (conversation_id, user_id, role) "
        "VALUES (?, ?, 'member') ON CONFLICT DO NOTHING",
        input.conversation_id,
        member_id);
  }

  Json::Value response;
  response["added"] = static_cast<int>(unique.size());
  return response;
}

Json::Value ConversationsService::ListMembers(
    const std::string& conversation_id) {
  const auto rows = db_->execSqlSync(
      "SELECT user_id, role, "
      "to_char(joined_at at time zone 'utc', ?) AS joined_at, "
      "to_char(left_at at time zone 'utc', ?) AS left_at "
      "FROM conversation_members "
      "WHERE conversation_id = ?",
      kTimestampFormat,
      kTimestampFormat,
      conversation_id);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["userId"] = row["user_id"].as<std::string>();
    item["role"] = row["role"].as<std::string>();
    item["joinedAt"] = row["joined_at"].as<std::string>();
    item["leftAt"] = row["left_at"].isNull()
                         ? Json::nullValue
                         : Json::Value(row["left_at"].as<std::string>());
    items.append(item);
  }
  return items;
}

void ConversationsService::LeaveConversation(
    const std::string& conversation_id,
    const std::string& user_id) {
  db_->execSqlSync(
      "UPDATE conversation_members SET left_at = NOW() "
      "WHERE conversation_id = ? AND user_id = ? AND left_at IS NULL",
      conversation_id,
      user_id);
}

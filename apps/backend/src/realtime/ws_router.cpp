#include "realtime/ws_router.h"

#include <chrono>
#include <ctime>
#include <iomanip>
#include <optional>
#include <sstream>
#include <string>

#include <drogon/WebSocketConnection.h>

namespace {

constexpr int kMaxMessageBodyLength = 65535;

int64_t NowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

std::string ToJsonString(const Json::Value& value) {
  Json::StreamWriterBuilder builder;
  builder["indentation"] = "";
  return Json::writeString(builder, value);
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

std::optional<std::string> ToIsoTimestamp(int64_t millis) {
  using namespace std::chrono;
  if (millis <= 0) {
    return std::nullopt;
  }
  const auto tp = system_clock::time_point(milliseconds(millis));
  std::time_t t = system_clock::to_time_t(tp);
  std::tm utc{};
#if defined(_WIN32)
  gmtime_s(&utc, &t);
#else
  gmtime_r(&t, &utc);
#endif
  const auto ms_part = static_cast<int>(millis % 1000);
  std::ostringstream stream;
  stream << std::put_time(&utc, "%Y-%m-%dT%H:%M:%S");
  stream << '.' << std::setw(3) << std::setfill('0') << ms_part << 'Z';
  return stream.str();
}

std::optional<std::string> ParseClientTimestamp(const Json::Value& value) {
  if (value.isInt64()) {
    return ToIsoTimestamp(value.asInt64());
  }
  if (value.isUInt64()) {
    return ToIsoTimestamp(static_cast<int64_t>(value.asUInt64()));
  }
  if (value.isString()) {
    const std::string raw = value.asString();
    if (LooksLikeIsoTimestamp(raw)) {
      return raw;
    }
  }
  return std::nullopt;
}

void SendEvent(const drogon::WebSocketConnectionPtr& conn,
               const Json::Value& payload) {
  if (!conn || conn->disconnected()) {
    return;
  }
  conn->send(ToJsonString(payload));
}

void SendError(const drogon::WebSocketConnectionPtr& conn,
               const std::string& code,
               const std::string& message) {
  Json::Value error;
  error["type"] = "ERROR";
  Json::Value payload;
  payload["code"] = code;
  payload["message"] = message;
  error["payload"] = payload;
  error["ts"] = static_cast<Json::Int64>(NowMs());
  SendEvent(conn, error);
}

}  // namespace

void WsRouter::HandleMessage(const WsContext& ctx,
                             const Json::Value& message) {
  if (!ctx.conn || !ctx.sync_service || !ctx.conversations_service ||
      !ctx.messages_service || !ctx.hub) {
    return;
  }

  const std::string type =
      message.isMember("type") && message["type"].isString()
          ? message["type"].asString()
          : "";
  const Json::Value payload =
      message.isMember("payload") ? message["payload"] : Json::Value();

  if (type == "SYNC_INIT") {
    if (!payload.isObject() || !payload["conversations"].isArray()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    for (const auto& convo : payload["conversations"]) {
      if (!convo.isObject()) {
        continue;
      }
      if (!convo.isMember("conversationId") || !convo["conversationId"].isString() ||
          !convo.isMember("lastDeliveredSeq") || !convo["lastDeliveredSeq"].isInt()) {
        continue;
      }

      const std::string conversation_id = convo["conversationId"].asString();
      const int last_delivered_seq = convo["lastDeliveredSeq"].asInt();
      if (!ctx.conversations_service->HasMembership(conversation_id,
                                                    ctx.user_id)) {
        continue;
      }

      SyncInput sync_input;
      sync_input.user_id = ctx.user_id;
      sync_input.device_id = ctx.device_id;
      sync_input.conversation_id = conversation_id;
      sync_input.last_delivered_seq = last_delivered_seq;

      const auto rows = ctx.sync_service->SyncConversation(sync_input);
      for (const auto& m : rows) {
        Json::Value event;
        event["type"] = "MESSAGE_PUSH";
        Json::Value event_payload;
        event_payload["messageId"] = m.id;
        event_payload["conversationId"] = m.conversation_id;
        event_payload["seq"] = m.seq;
        event_payload["senderUserId"] = m.sender_user_id;
        event_payload["senderDeviceId"] = m.sender_device_id;
        event_payload["body"] = m.body;
        event_payload["contentType"] = m.content_type;
        event_payload["mediaAssetId"] =
            m.media_asset_id ? Json::Value(*m.media_asset_id) : Json::nullValue;
        event_payload["editVersion"] = m.edit_version;
        event_payload["deletedForAllAt"] =
            m.deleted_for_all_at ? Json::Value(*m.deleted_for_all_at)
                                 : Json::nullValue;
        event_payload["createdAt"] = m.created_at;
        event["payload"] = event_payload;
        event["ts"] = static_cast<Json::Int64>(NowMs());
        SendEvent(ctx.conn, event);
      }
    }

    return;
  }

  if (type == "MESSAGE_SEND") {
    if (!payload.isObject() || !payload["conversationId"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    std::string content_type = "text";
    if (payload.isMember("contentType") && payload["contentType"].isString()) {
      content_type = payload["contentType"].asString();
    }

    if (content_type != "text" && content_type != "system" &&
        content_type != "media") {
      SendError(ctx.conn, "INVALID_TYPE", "Invalid content type");
      return;
    }

    std::string body;
    if (payload.isMember("body") && payload["body"].isString()) {
      body = payload["body"].asString();
    }

    std::optional<std::string> media_asset_id;
    if (payload.isMember("mediaAssetId") &&
        payload["mediaAssetId"].isString()) {
      media_asset_id = payload["mediaAssetId"].asString();
    }

    if (content_type == "media") {
      if (!media_asset_id || media_asset_id->empty()) {
        SendError(ctx.conn, "INVALID_MEDIA", "Media asset required");
        return;
      }
      if (body.size() > static_cast<size_t>(kMaxMessageBodyLength)) {
        SendError(ctx.conn, "INVALID_BODY", "Invalid body length");
        return;
      }
    } else {
      if (body.empty() ||
          body.size() > static_cast<size_t>(kMaxMessageBodyLength)) {
        SendError(ctx.conn, "INVALID_BODY", "Invalid body length");
        return;
      }
      if (media_asset_id && !media_asset_id->empty()) {
        SendError(ctx.conn, "INVALID_MEDIA", "Media asset not allowed");
        return;
      }
    }

    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    std::optional<std::string> temp_id;
    if (payload.isMember("tempId") && payload["tempId"].isString()) {
      temp_id = payload["tempId"].asString();
    }

    std::optional<std::string> client_timestamp;
    if (payload.isMember("clientTimestamp")) {
      client_timestamp = ParseClientTimestamp(payload["clientTimestamp"]);
    }

    SendMessageInput input;
    input.conversation_id = conversation_id;
    input.sender_user_id = ctx.user_id;
    input.sender_device_id = ctx.device_id;
    input.body = body;
    input.content_type = content_type;
    input.client_timestamp = client_timestamp;
    input.client_temp_id = temp_id;
    input.media_asset_id = media_asset_id;

    Json::Value result;
    try {
      result = ctx.messages_service->SendMessage(input);
    } catch (const std::exception&) {
      SendError(ctx.conn, "SEND_FAILED", "Failed to send message");
      return;
    }

    const Json::Value& inserted = result["message"];
    const bool created = result["created"].asBool();

    if (created) {
      Json::Value event;
      event["type"] = "MESSAGE_PUSH";
      Json::Value event_payload;
      event_payload["messageId"] = inserted["id"];
      event_payload["conversationId"] = conversation_id;
      event_payload["seq"] = inserted["seq"];
      event_payload["senderUserId"] = inserted["senderUserId"];
      event_payload["senderDeviceId"] = inserted["senderDeviceId"];
      event_payload["body"] = inserted["body"];
      event_payload["contentType"] = inserted["contentType"];
      event_payload["mediaAssetId"] = inserted["mediaAssetId"];
      event_payload["editVersion"] = inserted["editVersion"];
      event_payload["deletedForAllAt"] = inserted["deletedForAllAt"];
      event_payload["createdAt"] = inserted["createdAt"];
      event["payload"] = event_payload;
      event["ts"] = static_cast<Json::Int64>(NowMs());
      ctx.hub->PublishToConversation(conversation_id, event);
    }

    Json::Value ack;
    ack["type"] = "MESSAGE_ACK";
    Json::Value ack_payload;
    ack_payload["tempId"] =
        temp_id ? Json::Value(*temp_id) : Json::nullValue;
    ack_payload["conversationId"] = conversation_id;
    ack_payload["messageId"] = inserted["id"];
    ack_payload["seq"] = inserted["seq"];
    ack_payload["createdAt"] = inserted["createdAt"];
    ack_payload["created"] = created;
    ack["payload"] = ack_payload;
    ack["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToUser(ctx.user_id, ack);

    return;
  }

  if (type == "READ_RECEIPT") {
    if (!payload.isObject() || !payload["conversationId"].isString() ||
        !payload["lastReadSeq"].isInt()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const int last_read_seq = payload["lastReadSeq"].asInt();
    if (last_read_seq < 0) {
      SendError(ctx.conn, "INVALID_READ", "Invalid read cursor");
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    ReceiptInput input;
    input.conversation_id = conversation_id;
    input.user_id = ctx.user_id;
    input.device_id = ctx.device_id;
    input.seq = last_read_seq;
    ctx.messages_service->MarkRead(input);

    Json::Value event;
    event["type"] = "READ_UPDATE";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["userId"] = ctx.user_id;
    event_payload["lastReadSeq"] = last_read_seq;
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "DELIVERY_RECEIPT") {
    if (!payload.isObject() || !payload["conversationId"].isString() ||
        !payload["lastDeliveredSeq"].isInt()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const int last_delivered = payload["lastDeliveredSeq"].asInt();
    if (last_delivered < 0) {
      SendError(ctx.conn, "INVALID_DELIVERED", "Invalid delivery cursor");
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    ReceiptInput input;
    input.conversation_id = conversation_id;
    input.user_id = ctx.user_id;
    input.device_id = ctx.device_id;
    input.seq = last_delivered;
    ctx.messages_service->MarkDelivered(input);

    Json::Value event;
    event["type"] = "DELIVERY_UPDATE";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["userId"] = ctx.user_id;
    event_payload["lastDeliveredSeq"] = last_delivered;
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "MESSAGE_EDIT") {
    if (!payload.isObject() || !payload["conversationId"].isString() ||
        !payload["messageId"].isString() || !payload["body"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string body = payload["body"].asString();
    if (body.empty() || body.size() > static_cast<size_t>(kMaxMessageBodyLength)) {
      SendError(ctx.conn, "INVALID_BODY", "Invalid body length");
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    const std::string message_id = payload["messageId"].asString();
    const auto updated =
        ctx.messages_service->EditMessage(conversation_id, message_id,
                                          ctx.user_id, body);
    if (!updated) {
      SendError(ctx.conn, "EDIT_DENIED", "Cannot edit message");
      return;
    }

    Json::Value event;
    event["type"] = "MESSAGE_EDIT";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["messageId"] = message_id;
    event_payload["body"] = (*updated)["body"];
    event_payload["editVersion"] = (*updated)["editVersion"];
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "MESSAGE_DELETE") {
    if (!payload.isObject() || !payload["conversationId"].isString() ||
        !payload["messageId"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    const std::string message_id = payload["messageId"].asString();
    const auto updated =
        ctx.messages_service->DeleteMessageForAll(conversation_id, message_id,
                                                  ctx.user_id);
    if (!updated) {
      SendError(ctx.conn, "DELETE_DENIED", "Cannot delete message");
      return;
    }

    Json::Value event;
    event["type"] = "MESSAGE_DELETE";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["messageId"] = message_id;
    event_payload["deletedForAllAt"] = (*updated)["deletedForAllAt"];
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "REACTION_SET") {
    if (!payload.isObject() || !payload["conversationId"].isString() ||
        !payload["messageId"].isString() || !payload["emoji"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string emoji = payload["emoji"].asString();
    if (emoji.empty() || emoji.size() > 16) {
      SendError(ctx.conn, "INVALID_REACTION", "Invalid emoji");
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    ReactionInput input;
    input.conversation_id = conversation_id;
    input.message_id = payload["messageId"].asString();
    input.user_id = ctx.user_id;
    input.emoji = emoji;

    const auto reaction = ctx.messages_service->SetReaction(input);
    if (!reaction) {
      SendError(ctx.conn, "REACTION_FAILED", "Failed to react");
      return;
    }

    Json::Value event;
    event["type"] = "REACTION_UPDATE";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["messageId"] = (*reaction)["messageId"];
    event_payload["userId"] = (*reaction)["userId"];
    event_payload["emoji"] = (*reaction)["emoji"];
    event_payload["updatedAt"] = (*reaction)["updatedAt"];
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "REACTION_REMOVE") {
    if (!payload.isObject() || !payload["conversationId"].isString() ||
        !payload["messageId"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    const std::string message_id = payload["messageId"].asString();
    const bool removed =
        ctx.messages_service->RemoveReaction(conversation_id, message_id,
                                             ctx.user_id);
    if (!removed) {
      SendError(ctx.conn, "REACTION_MISSING", "Reaction not found");
      return;
    }

    Json::Value event;
    event["type"] = "REACTION_UPDATE";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["messageId"] = message_id;
    event_payload["userId"] = ctx.user_id;
    event_payload["emoji"] = Json::nullValue;
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "TYPING_START" || type == "TYPING_STOP") {
    if (!payload.isObject() || !payload["conversationId"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      return;
    }

    Json::Value event;
    event["type"] = "TYPING";
    Json::Value event_payload;
    event_payload["conversationId"] = conversation_id;
    event_payload["userId"] = ctx.user_id;
    event_payload["isTyping"] = (type == "TYPING_START");
    event["payload"] = event_payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    ctx.hub->PublishToConversation(conversation_id, event);
    return;
  }

  if (type == "CONVERSATION_SUBSCRIBE") {
    if (!payload.isObject() || !payload["conversationId"].isString()) {
      ctx.conn->shutdown(drogon::CloseCode::kProtocolError);
      return;
    }

    const std::string conversation_id = payload["conversationId"].asString();
    if (!ctx.conversations_service->HasMembership(conversation_id,
                                                  ctx.user_id)) {
      SendError(ctx.conn, "NOT_MEMBER", "Not in conversation");
      return;
    }

    ctx.hub->SubscribeConversation(ctx.conn, conversation_id);
    return;
  }

  if (type == "FEED_SUBSCRIBE") {
    ctx.hub->SubscribeFeed(ctx.conn);
    return;
  }

  if (type == "PING") {
    Json::Value pong;
    pong["type"] = "PONG";
    pong["ts"] = static_cast<Json::Int64>(NowMs());
    SendEvent(ctx.conn, pong);
    return;
  }

  // Unknown message type: ignore.
}

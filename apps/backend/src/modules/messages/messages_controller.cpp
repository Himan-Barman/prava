#include "modules/messages/messages_controller.h"

#include <cstdlib>
#include <optional>
#include <string>
#include <unordered_set>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/auth/auth_validation.h"
#include "modules/conversations/conversations_service.h"
#include "modules/messages/messages_service.h"

namespace {

constexpr int kMaxMessageBodyLength = 65535;

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

bool GetRequiredInt(const Json::Value& body,
                    const std::string& key,
                    int& out) {
  if (!body.isMember(key) || !body[key].isInt()) {
    return false;
  }
  out = body[key].asInt();
  return true;
}

std::optional<int> ParseOptionalInt(const drogon::HttpRequestPtr& req,
                                    const std::string& key) {
  const std::string value = req->getParameter(key);
  if (value.empty()) {
    return std::nullopt;
  }

  char* end = nullptr;
  const long parsed = std::strtol(value.c_str(), &end, 10);
  if (end == value.c_str() || *end != '\0') {
    return std::nullopt;
  }

  return static_cast<int>(parsed);
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

MessagesService BuildMessagesService() {
  return MessagesService(AppState::Instance().GetDb());
}

ConversationsService BuildConversationsService() {
  return ConversationsService(AppState::Instance().GetDb());
}

void RespondWithMessages(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const MessagesError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void MessagesController::ListMessages(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id) const {
  if (conversation_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
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

  const auto before_seq = ParseOptionalInt(req, "beforeSeq");
  const auto limit = ParseOptionalInt(req, "limit");

  RespondWithMessages(
      [&conversation_id, &before_seq, &limit]() {
        auto messages = BuildMessagesService();
        return messages.ListMessages(conversation_id, before_seq, limit);
      },
      std::move(callback));
}

void MessagesController::SendMessage(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id) const {
  if (conversation_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {
      "body", "contentType", "clientTimestamp", "tempId", "mediaAssetId",
      "deviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string device_id;
  if (!GetRequiredString(body, "deviceId", device_id) ||
      !IsValidDeviceId(device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> content_type;
  if (!GetOptionalString(body, "contentType", content_type)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> body_text;
  if (!GetOptionalString(body, "body", body_text)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> client_timestamp;
  if (!GetOptionalString(body, "clientTimestamp", client_timestamp)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (client_timestamp && !LooksLikeIsoTimestamp(*client_timestamp)) {
    client_timestamp.reset();
  }

  std::optional<std::string> temp_id;
  if (!GetOptionalString(body, "tempId", temp_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (temp_id && (temp_id->size() < 6 || temp_id->size() > 64)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> media_asset_id;
  if (!GetOptionalString(body, "mediaAssetId", media_asset_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (body_text && body_text->size() > static_cast<size_t>(kMaxMessageBodyLength)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
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

  SendMessageInput input;
  input.conversation_id = conversation_id;
  input.sender_user_id = user_id;
  input.sender_device_id = device_id;
  input.body = body_text.value_or("");
  input.content_type = content_type.value_or("text");
  input.client_timestamp = client_timestamp;
  input.client_temp_id = temp_id;
  input.media_asset_id = media_asset_id;

  RespondWithMessages(
      [&input]() {
        auto messages = BuildMessagesService();
        return messages.SendMessage(input);
      },
      std::move(callback));
}

void MessagesController::MarkRead(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id) const {
  if (conversation_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {"lastReadSeq",
                                                          "deviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  int last_read_seq = -1;
  if (!GetRequiredInt(body, "lastReadSeq", last_read_seq) || last_read_seq < 0) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string device_id;
  if (!GetRequiredString(body, "deviceId", device_id) ||
      !IsValidDeviceId(device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
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

  ReceiptInput input;
  input.conversation_id = conversation_id;
  input.user_id = user_id;
  input.device_id = device_id;
  input.seq = last_read_seq;

  RespondWithMessages(
      [&input]() {
        auto messages = BuildMessagesService();
        messages.MarkRead(input);
        Json::Value payload;
        payload["success"] = true;
        return payload;
      },
      std::move(callback));
}

void MessagesController::ListReceipts(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id,
    const std::string& message_id) const {
  if (conversation_id.empty() || message_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
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

  auto messages = BuildMessagesService();
  const auto message = messages.GetMessage(conversation_id, message_id);
  if (!message.has_value()) {
    callback(http::ErrorResponse(drogon::k404NotFound, "Message not found"));
    return;
  }

  if ((*message)["senderUserId"].asString() != user_id) {
    callback(http::ErrorResponse(drogon::k403Forbidden,
                                 "Receipts restricted to sender"));
    return;
  }

  RespondWithMessages(
      [&conversation_id, &message_id]() {
        auto service = BuildMessagesService();
        return service.ListMessageReceipts(conversation_id, message_id);
      },
      std::move(callback));
}

void MessagesController::MarkDelivered(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id) const {
  if (conversation_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {"lastDeliveredSeq",
                                                          "deviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  int last_delivered_seq = -1;
  if (!GetRequiredInt(body, "lastDeliveredSeq", last_delivered_seq) ||
      last_delivered_seq < 0) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string device_id;
  if (!GetRequiredString(body, "deviceId", device_id) ||
      !IsValidDeviceId(device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
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

  ReceiptInput input;
  input.conversation_id = conversation_id;
  input.user_id = user_id;
  input.device_id = device_id;
  input.seq = last_delivered_seq;

  RespondWithMessages(
      [&input]() {
        auto messages = BuildMessagesService();
        messages.MarkDelivered(input);
        Json::Value payload;
        payload["success"] = true;
        return payload;
      },
      std::move(callback));
}

void MessagesController::EditMessage(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id,
    const std::string& message_id) const {
  if (conversation_id.empty() || message_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {"body"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string body_text;
  if (!GetRequiredString(body, "body", body_text) || body_text.empty() ||
      body_text.size() > static_cast<size_t>(kMaxMessageBodyLength)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
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

  RespondWithMessages(
      [&conversation_id, &message_id, &user_id, &body_text]() {
        auto messages = BuildMessagesService();
        auto updated =
            messages.EditMessage(conversation_id, message_id, user_id, body_text);
        if (!updated) {
          throw MessagesError(drogon::k403Forbidden, "Cannot edit message");
        }
        return *updated;
      },
      std::move(callback));
}

void MessagesController::DeleteMessage(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id,
    const std::string& message_id) const {
  if (conversation_id.empty() || message_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
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

  RespondWithMessages(
      [&conversation_id, &message_id, &user_id]() {
        auto messages = BuildMessagesService();
        auto updated =
            messages.DeleteMessageForAll(conversation_id, message_id, user_id);
        if (!updated) {
          throw MessagesError(drogon::k403Forbidden, "Cannot delete message");
        }
        return *updated;
      },
      std::move(callback));
}

void MessagesController::SetReaction(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id,
    const std::string& message_id) const {
  if (conversation_id.empty() || message_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {"emoji"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string emoji;
  if (!GetRequiredString(body, "emoji", emoji) || emoji.empty() ||
      emoji.size() > 16) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
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

  ReactionInput input;
  input.conversation_id = conversation_id;
  input.message_id = message_id;
  input.user_id = user_id;
  input.emoji = emoji;

  RespondWithMessages(
      [&input]() {
        auto messages = BuildMessagesService();
        auto reaction = messages.SetReaction(input);
        if (!reaction) {
          throw MessagesError(drogon::k403Forbidden,
                              "Cannot react to message");
        }
        return *reaction;
      },
      std::move(callback));
}

void MessagesController::RemoveReaction(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id,
    const std::string& message_id) const {
  if (conversation_id.empty() || message_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
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

  RespondWithMessages(
      [&conversation_id, &message_id, &user_id]() {
        auto messages = BuildMessagesService();
        Json::Value payload;
        payload["removed"] =
            messages.RemoveReaction(conversation_id, message_id, user_id);
        return payload;
      },
      std::move(callback));
}

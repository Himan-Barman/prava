#include "modules/conversations/conversations_controller.h"

#include <string>
#include <unordered_set>
#include <vector>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/conversations/conversations_service.h"

namespace {

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

bool GetStringArray(const Json::Value& body,
                    const std::string& key,
                    std::vector<std::string>& out) {
  if (!body.isMember(key) || !body[key].isArray()) {
    return false;
  }
  out.clear();
  for (const auto& entry : body[key]) {
    if (!entry.isString()) {
      return false;
    }
    const std::string value = entry.asString();
    if (!value.empty()) {
      out.push_back(value);
    }
  }
  return true;
}

ConversationsService BuildConversationsService() {
  return ConversationsService(AppState::Instance().GetDb());
}

void RespondWithConversations(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const ConversationsError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void ConversationsController::List(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithConversations(
      [&user_id]() {
        auto conversations = BuildConversationsService();
        return conversations.ListForUser(user_id);
      },
      std::move(callback));
}

void ConversationsController::CreateDm(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"otherUserId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string other_user_id;
  if (!GetRequiredString(body, "otherUserId", other_user_id) ||
      other_user_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithConversations(
      [&user_id, &other_user_id]() {
        auto conversations = BuildConversationsService();
        return conversations.CreateDm(user_id, other_user_id);
      },
      std::move(callback));
}

void ConversationsController::CreateGroup(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"title",
                                                          "memberIds"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string title;
  if (!GetRequiredString(body, "title", title) || title.empty() ||
      title.size() > 140) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::vector<std::string> member_ids;
  if (!GetStringArray(body, "memberIds", member_ids) || member_ids.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  CreateGroupInput input;
  input.user_id = user_id;
  input.title = title;
  input.member_ids = std::move(member_ids);

  RespondWithConversations(
      [&input]() {
        auto conversations = BuildConversationsService();
        return conversations.CreateGroup(input);
      },
      std::move(callback));
}

void ConversationsController::ListMembers(
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
    callback(http::ErrorResponse(drogon::k400BadRequest,
                                 "Not a member of conversation"));
    return;
  }

  RespondWithConversations(
      [&conversations, &conversation_id]() {
        return conversations.ListMembers(conversation_id);
      },
      std::move(callback));
}

void ConversationsController::AddMembers(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& conversation_id) const {
  if (conversation_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  static const std::unordered_set<std::string> allowed = {"memberIds"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::vector<std::string> member_ids;
  if (!GetStringArray(body, "memberIds", member_ids) || member_ids.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  AddMembersInput input;
  input.conversation_id = conversation_id;
  input.requester_id = user_id;
  input.member_ids = std::move(member_ids);

  RespondWithConversations(
      [&input]() {
        auto conversations = BuildConversationsService();
        return conversations.AddMembers(input);
      },
      std::move(callback));
}

void ConversationsController::Leave(
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

  RespondWithConversations(
      [&conversation_id, &user_id]() {
        auto conversations = BuildConversationsService();
        conversations.LeaveConversation(conversation_id, user_id);
        Json::Value payload;
        payload["success"] = true;
        return payload;
      },
      std::move(callback));
}

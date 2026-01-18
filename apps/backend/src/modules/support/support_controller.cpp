#include "modules/support/support_controller.h"

#include <string>
#include <unordered_set>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/support/support_service.h"

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

bool GetOptionalBool(const Json::Value& body,
                     const std::string& key,
                     std::optional<bool>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isBool()) {
    return false;
  }
  out = body[key].asBool();
  return true;
}

bool GetOptionalInt(const Json::Value& body,
                    const std::string& key,
                    std::optional<int>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isInt()) {
    return false;
  }
  out = body[key].asInt();
  return true;
}

SupportService BuildSupportService() {
  return SupportService(AppState::Instance().GetDb());
}

void RespondWithSupport(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const SupportError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void SupportController::CreateTicket(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"type",
                                                          "category",
                                                          "message",
                                                          "includeLogs",
                                                          "allowContact",
                                                          "score"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string type;
  std::string message;
  if (!GetRequiredString(body, "type", type) ||
      !GetRequiredString(body, "message", message)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (type != "help" && type != "report" && type != "feedback") {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (message.size() < 3 || message.size() > 2000) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> category;
  if (!GetOptionalString(body, "category", category)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (category && category->size() > 32) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<bool> include_logs;
  if (!GetOptionalBool(body, "includeLogs", include_logs)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<bool> allow_contact;
  if (!GetOptionalBool(body, "allowContact", allow_contact)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<int> score;
  if (!GetOptionalInt(body, "score", score)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (score && (*score < 1 || *score > 5)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  SupportTicketInput input;
  input.user_id = user_id;
  input.type = type;
  input.category = category;
  input.message = message;
  input.include_logs = include_logs;
  input.allow_contact = allow_contact;
  input.score = score;

  RespondWithSupport(
      [&input]() {
        auto support = BuildSupportService();
        return support.CreateTicket(input);
      },
      std::move(callback));
}

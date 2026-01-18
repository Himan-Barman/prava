#include "modules/feed/feed_controller.h"

#include <cstdlib>
#include <optional>
#include <string>
#include <unordered_set>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/feed/feed_service.h"

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

FeedService BuildFeedService() {
  return FeedService(AppState::Instance().GetDb());
}

void RespondWithFeed(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const FeedError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void FeedController::List(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  const auto limit = ParseOptionalInt(req, "limit");
  std::optional<std::string> before;
  const std::string before_param = req->getParameter("before");
  if (!before_param.empty() && LooksLikeIsoTimestamp(before_param)) {
    before = before_param;
  }

  std::string mode = req->getParameter("mode");
  for (auto& ch : mode) {
    ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }
  if (mode != "following") {
    mode = "for-you";
  }

  RespondWithFeed(
      [&]() {
        auto feed = BuildFeedService();
        return feed.ListFeed(user_id, limit, before, mode);
      },
      std::move(callback));
}

void FeedController::Create(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"body"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string text;
  if (!GetRequiredString(body, "body", text) || text.empty() ||
      text.size() > 5000) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithFeed(
      [&]() {
        auto feed = BuildFeedService();
        return feed.CreatePost(user_id, text);
      },
      std::move(callback));
}

void FeedController::ToggleLike(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& post_id) const {
  if (post_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithFeed(
      [&]() {
        auto feed = BuildFeedService();
        return feed.ToggleLike(user_id, post_id);
      },
      std::move(callback));
}

void FeedController::ListComments(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& post_id) const {
  if (post_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  const auto limit = ParseOptionalInt(req, "limit");

  RespondWithFeed(
      [&]() {
        auto feed = BuildFeedService();
        return feed.ListComments(user_id, post_id, limit);
      },
      std::move(callback));
}

void FeedController::AddComment(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& post_id) const {
  if (post_id.empty()) {
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

  std::string text;
  if (!GetRequiredString(body, "body", text) || text.empty() ||
      text.size() > 2000) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithFeed(
      [&]() {
        auto feed = BuildFeedService();
        return feed.AddComment(user_id, post_id, text);
      },
      std::move(callback));
}

void FeedController::Share(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& post_id) const {
  if (post_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithFeed(
      [&]() {
        auto feed = BuildFeedService();
        return feed.SharePost(user_id, post_id);
      },
      std::move(callback));
}

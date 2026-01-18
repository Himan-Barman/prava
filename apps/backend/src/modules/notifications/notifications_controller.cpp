#include "modules/notifications/notifications_controller.h"

#include <cstdlib>
#include <optional>
#include <string>

#include "app_state.h"
#include "http/response.h"
#include "modules/notifications/notifications_service.h"

namespace {

bool GetUserId(const drogon::HttpRequestPtr& req, std::string& user_id) {
  const auto attrs = req->getAttributes();
  if (!attrs || !attrs->find("user_id")) {
    return false;
  }
  user_id = attrs->get<std::string>("user_id");
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

NotificationsService BuildNotificationsService() {
  return NotificationsService(AppState::Instance().GetDb());
}

void RespondWithNotifications(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void NotificationsController::List(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  const auto limit = ParseOptionalInt(req, "limit");
  std::optional<std::string> cursor;
  const std::string cursor_param = req->getParameter("cursor");
  if (!cursor_param.empty()) {
    cursor = cursor_param;
  }

  RespondWithNotifications(
      [&user_id, &limit, &cursor]() {
        auto notifications = BuildNotificationsService();
        return notifications.ListForUser(user_id, limit, cursor);
      },
      std::move(callback));
}

void NotificationsController::UnreadCount(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithNotifications(
      [&user_id]() {
        auto notifications = BuildNotificationsService();
        Json::Value payload;
        payload["count"] = notifications.CountUnread(user_id);
        return payload;
      },
      std::move(callback));
}

void NotificationsController::MarkAllRead(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithNotifications(
      [&user_id]() {
        auto notifications = BuildNotificationsService();
        return notifications.MarkAllRead(user_id);
      },
      std::move(callback));
}

void NotificationsController::MarkRead(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& notification_id) const {
  if (notification_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithNotifications(
      [&user_id, &notification_id]() {
        auto notifications = BuildNotificationsService();
        return notifications.MarkRead(user_id, notification_id);
      },
      std::move(callback));
}

#pragma once

#include <functional>

#include <drogon/HttpController.h>

class NotificationsController
    : public drogon::HttpController<NotificationsController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(NotificationsController::List, "/api/notifications",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(NotificationsController::UnreadCount,
                "/api/notifications/unread-count", drogon::Get, "JwtFilter");
  ADD_METHOD_TO(NotificationsController::MarkAllRead,
                "/api/notifications/read-all", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(NotificationsController::MarkRead,
                "/api/notifications/{1}/read", drogon::Post, "JwtFilter");
  METHOD_LIST_END

  void List(const drogon::HttpRequestPtr& req,
            std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void UnreadCount(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void MarkAllRead(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void MarkRead(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& notification_id) const;
};

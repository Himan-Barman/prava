#pragma once

#include <functional>

#include <drogon/HttpController.h>

class DevicesController : public drogon::HttpController<DevicesController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(DevicesController::RegisterPushToken,
                "/api/devices/push-token", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(DevicesController::RevokePushToken,
                "/api/devices/push-token", drogon::Delete, "JwtFilter");
  METHOD_LIST_END

  void RegisterPushToken(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RevokePushToken(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
};

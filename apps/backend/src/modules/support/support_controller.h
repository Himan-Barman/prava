#pragma once

#include <functional>

#include <drogon/HttpController.h>

class SupportController : public drogon::HttpController<SupportController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(SupportController::CreateTicket, "/api/support", drogon::Post,
                "JwtFilter");
  METHOD_LIST_END

  void CreateTicket(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
};

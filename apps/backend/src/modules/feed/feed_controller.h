#pragma once

#include <functional>

#include <drogon/HttpController.h>

class FeedController : public drogon::HttpController<FeedController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(FeedController::List, "/api/feed", drogon::Get, "JwtFilter");
  ADD_METHOD_TO(FeedController::Create, "/api/feed", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(FeedController::ToggleLike, "/api/feed/{1}/like", drogon::Post,
                "JwtFilter");
  ADD_METHOD_TO(FeedController::ListComments,
                "/api/feed/{1}/comments", drogon::Get, "JwtFilter");
  ADD_METHOD_TO(FeedController::AddComment,
                "/api/feed/{1}/comments", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(FeedController::Share, "/api/feed/{1}/share", drogon::Post,
                "JwtFilter");
  METHOD_LIST_END

  void List(const drogon::HttpRequestPtr& req,
            std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void Create(const drogon::HttpRequestPtr& req,
              std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void ToggleLike(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& post_id) const;
  void ListComments(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& post_id) const;
  void AddComment(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& post_id) const;
  void Share(const drogon::HttpRequestPtr& req,
             std::function<void(const drogon::HttpResponsePtr&)>&& callback,
             const std::string& post_id) const;
};

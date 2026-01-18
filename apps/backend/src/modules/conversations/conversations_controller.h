#pragma once

#include <functional>

#include <drogon/HttpController.h>

class ConversationsController
    : public drogon::HttpController<ConversationsController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(ConversationsController::List, "/api/conversations",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(ConversationsController::CreateDm, "/api/conversations/dm",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(ConversationsController::CreateGroup,
                "/api/conversations/group", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(ConversationsController::ListMembers,
                "/api/conversations/{1}/members", drogon::Get, "JwtFilter");
  ADD_METHOD_TO(ConversationsController::AddMembers,
                "/api/conversations/{1}/members", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(ConversationsController::Leave,
                "/api/conversations/{1}/leave", drogon::Post, "JwtFilter");
  METHOD_LIST_END

  void List(const drogon::HttpRequestPtr& req,
            std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void CreateDm(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void CreateGroup(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ListMembers(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id) const;
  void AddMembers(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id) const;
  void Leave(const drogon::HttpRequestPtr& req,
             std::function<void(const drogon::HttpResponsePtr&)>&& callback,
             const std::string& conversation_id) const;
};

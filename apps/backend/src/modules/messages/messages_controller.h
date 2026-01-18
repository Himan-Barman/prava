#pragma once

#include <functional>

#include <drogon/HttpController.h>

class MessagesController : public drogon::HttpController<MessagesController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(MessagesController::ListMessages,
                "/api/conversations/{1}/messages", drogon::Get, "JwtFilter");
  ADD_METHOD_TO(MessagesController::SendMessage,
                "/api/conversations/{1}/messages", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(MessagesController::MarkRead,
                "/api/conversations/{1}/read", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(MessagesController::ListReceipts,
                "/api/conversations/{1}/messages/{2}/receipts", drogon::Get,
                "JwtFilter");
  ADD_METHOD_TO(MessagesController::MarkDelivered,
                "/api/conversations/{1}/delivered", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(MessagesController::EditMessage,
                "/api/conversations/{1}/messages/{2}", drogon::Patch,
                "JwtFilter");
  ADD_METHOD_TO(MessagesController::DeleteMessage,
                "/api/conversations/{1}/messages/{2}", drogon::Delete,
                "JwtFilter");
  ADD_METHOD_TO(MessagesController::SetReaction,
                "/api/conversations/{1}/messages/{2}/reactions", drogon::Post,
                "JwtFilter");
  ADD_METHOD_TO(MessagesController::RemoveReaction,
                "/api/conversations/{1}/messages/{2}/reactions",
                drogon::Delete, "JwtFilter");
  METHOD_LIST_END

  void ListMessages(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id) const;
  void SendMessage(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id) const;
  void MarkRead(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id) const;
  void ListReceipts(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id,
      const std::string& message_id) const;
  void MarkDelivered(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id) const;
  void EditMessage(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id,
      const std::string& message_id) const;
  void DeleteMessage(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id,
      const std::string& message_id) const;
  void SetReaction(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id,
      const std::string& message_id) const;
  void RemoveReaction(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& conversation_id,
      const std::string& message_id) const;
};

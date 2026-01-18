#pragma once

#include <optional>
#include <string>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>

#include "db/sql.h"
#include <json/json.h>

struct MessagesError : public std::runtime_error {
  MessagesError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct SendMessageInput {
  std::string conversation_id;
  std::string sender_user_id;
  std::string sender_device_id;
  std::string body;
  std::string content_type;
  std::optional<std::string> client_timestamp;
  std::optional<std::string> client_temp_id;
  std::optional<std::string> media_asset_id;
};

struct ReceiptInput {
  std::string conversation_id;
  std::string user_id;
  std::string device_id;
  int seq = 0;
};

struct ReactionInput {
  std::string conversation_id;
  std::string message_id;
  std::string user_id;
  std::string emoji;
};

class MessagesService {
 public:
  explicit MessagesService(drogon::orm::DbClientPtr db);

  Json::Value SendMessage(const SendMessageInput& input);
  Json::Value ListMessages(const std::string& conversation_id,
                           const std::optional<int>& before_seq,
                           const std::optional<int>& limit);
  void MarkRead(const ReceiptInput& input);
  void MarkDelivered(const ReceiptInput& input);
  std::optional<Json::Value> GetMessage(const std::string& conversation_id,
                                        const std::string& message_id);
  Json::Value ListMessageReceipts(const std::string& conversation_id,
                                  const std::string& message_id);
  std::optional<Json::Value> EditMessage(const std::string& conversation_id,
                                         const std::string& message_id,
                                         const std::string& user_id,
                                         const std::string& body);
  std::optional<Json::Value> DeleteMessageForAll(
      const std::string& conversation_id,
      const std::string& message_id,
      const std::string& user_id);
  std::optional<Json::Value> SetReaction(const ReactionInput& input);
  bool RemoveReaction(const std::string& conversation_id,
                      const std::string& message_id,
                      const std::string& user_id);

 private:
  drogon::orm::DbClientPtr db_;
};

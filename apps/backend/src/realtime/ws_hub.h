#pragma once

#include <memory>
#include <string>

#include <drogon/WebSocketConnection.h>
#include <json/json.h>

#include "realtime/ws_fanout.h"
#include "realtime/ws_registry.h"

std::string UserTopic(const std::string& user_id);
std::string ConversationTopic(const std::string& conversation_id);
std::string FeedTopic();

class WsHub {
 public:
  static WsHub& Instance();

  void Init(const drogon::nosql::RedisClientPtr& redis);

  void SubscribeUser(const drogon::WebSocketConnectionPtr& conn,
                     const std::string& user_id);
  void SubscribeConversation(const drogon::WebSocketConnectionPtr& conn,
                             const std::string& conversation_id);
  void SubscribeFeed(const drogon::WebSocketConnectionPtr& conn);
  void Remove(const drogon::WebSocketConnectionPtr& conn);

  void PublishToUser(const std::string& user_id, const Json::Value& payload);
  void PublishToConversation(const std::string& conversation_id,
                             const Json::Value& payload);
  void PublishToFeed(const Json::Value& payload);

 private:
  WsHub() = default;

  void Publish(const std::string& scope,
               const std::string& topic,
               const Json::Value& payload);

  LocalTopicRegistry registry_;
  std::unique_ptr<WsFanout> fanout_;
};

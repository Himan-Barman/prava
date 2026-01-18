#include "realtime/ws_hub.h"

#include <string>

namespace {
std::string ToJsonString(const Json::Value& value) {
  Json::StreamWriterBuilder builder;
  builder["indentation"] = "";
  return Json::writeString(builder, value);
}
}  // namespace

std::string UserTopic(const std::string& user_id) {
  return "user:" + user_id;
}

std::string ConversationTopic(const std::string& conversation_id) {
  return "conversation:" + conversation_id;
}

std::string FeedTopic() {
  return "feed:global";
}

WsHub& WsHub::Instance() {
  static WsHub instance;
  return instance;
}

void WsHub::Init(const drogon::nosql::RedisClientPtr& redis) {
  if (fanout_) {
    return;
  }

  if (!redis) {
    return;
  }

  fanout_ = std::make_unique<WsFanout>(
      redis, [this](const std::string& topic, const std::string& payload) {
        registry_.Publish(topic, payload);
      });
  fanout_->Init();
}

void WsHub::SubscribeUser(const drogon::WebSocketConnectionPtr& conn,
                          const std::string& user_id) {
  registry_.Subscribe(conn, UserTopic(user_id));
}

void WsHub::SubscribeConversation(const drogon::WebSocketConnectionPtr& conn,
                                  const std::string& conversation_id) {
  registry_.Subscribe(conn, ConversationTopic(conversation_id));
}

void WsHub::SubscribeFeed(const drogon::WebSocketConnectionPtr& conn) {
  registry_.Subscribe(conn, FeedTopic());
}

void WsHub::Remove(const drogon::WebSocketConnectionPtr& conn) {
  registry_.Remove(conn);
}

void WsHub::PublishToUser(const std::string& user_id,
                          const Json::Value& payload) {
  Publish("user", UserTopic(user_id), payload);
}

void WsHub::PublishToConversation(const std::string& conversation_id,
                                  const Json::Value& payload) {
  Publish("conversation", ConversationTopic(conversation_id), payload);
}

void WsHub::PublishToFeed(const Json::Value& payload) {
  Publish("feed", FeedTopic(), payload);
}

void WsHub::Publish(const std::string& scope,
                    const std::string& topic,
                    const Json::Value& payload) {
  const std::string message = ToJsonString(payload);

  if (fanout_) {
    fanout_->Publish(scope, topic, message);
    return;
  }

  registry_.Publish(topic, message);
}

#pragma once

#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <drogon/WebSocketConnection.h>

class LocalTopicRegistry {
 public:
  void Subscribe(const drogon::WebSocketConnectionPtr& conn,
                 const std::string& topic);
  void Publish(const std::string& topic, const std::string& payload);
  void Remove(const drogon::WebSocketConnectionPtr& conn);

 private:
  struct ConnectionEntry {
    std::weak_ptr<drogon::WebSocketConnection> conn;
    std::unordered_set<std::string> topics;
  };

  std::mutex mutex_;
  std::unordered_map<std::string, std::unordered_set<std::uintptr_t>> topics_;
  std::unordered_map<std::uintptr_t, ConnectionEntry> connections_;
};

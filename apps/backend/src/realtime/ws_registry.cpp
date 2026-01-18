#include "realtime/ws_registry.h"

#include <algorithm>
#include <utility>

void LocalTopicRegistry::Subscribe(const drogon::WebSocketConnectionPtr& conn,
                                   const std::string& topic) {
  if (!conn || topic.empty()) {
    return;
  }

  const auto id = reinterpret_cast<std::uintptr_t>(conn.get());

  std::lock_guard<std::mutex> lock(mutex_);
  auto& topic_set = topics_[topic];
  topic_set.insert(id);

  auto& entry = connections_[id];
  entry.conn = conn;
  entry.topics.insert(topic);
}

void LocalTopicRegistry::Publish(const std::string& topic,
                                 const std::string& payload) {
  if (topic.empty()) {
    return;
  }

  std::vector<drogon::WebSocketConnectionPtr> targets;
  std::vector<std::uintptr_t> stale;

  {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = topics_.find(topic);
    if (it == topics_.end()) {
      return;
    }

    auto& ids = it->second;
    for (const auto id : ids) {
      auto conn_it = connections_.find(id);
      if (conn_it == connections_.end()) {
        stale.push_back(id);
        continue;
      }

      auto conn = conn_it->second.conn.lock();
      if (!conn || conn->disconnected()) {
        stale.push_back(id);
        continue;
      }
      targets.push_back(std::move(conn));
    }

    if (!stale.empty()) {
      for (const auto id : stale) {
        ids.erase(id);
        connections_.erase(id);
      }
      if (ids.empty()) {
        topics_.erase(it);
      }
    }
  }

  for (const auto& conn : targets) {
    if (conn && conn->connected()) {
      conn->send(payload);
    }
  }
}

void LocalTopicRegistry::Remove(const drogon::WebSocketConnectionPtr& conn) {
  if (!conn) {
    return;
  }

  const auto id = reinterpret_cast<std::uintptr_t>(conn.get());

  std::lock_guard<std::mutex> lock(mutex_);
  auto conn_it = connections_.find(id);
  if (conn_it == connections_.end()) {
    return;
  }

  for (const auto& topic : conn_it->second.topics) {
    auto topic_it = topics_.find(topic);
    if (topic_it == topics_.end()) {
      continue;
    }
    topic_it->second.erase(id);
    if (topic_it->second.empty()) {
      topics_.erase(topic_it);
    }
  }

  connections_.erase(conn_it);
}

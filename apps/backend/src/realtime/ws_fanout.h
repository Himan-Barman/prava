#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <string>

#include <drogon/nosql/RedisClient.h>
#include <drogon/nosql/RedisSubscriber.h>

class WsFanout {
 public:
  using PublishLocal =
      std::function<void(const std::string&, const std::string&)>;

  WsFanout(drogon::nosql::RedisClientPtr redis,
           PublishLocal publish_local);

  void Init();
  void Publish(const std::string& scope,
               const std::string& topic,
               const std::string& payload);
  bool IsSubscribed() const;

 private:
  drogon::nosql::RedisClientPtr redis_;
  std::shared_ptr<drogon::nosql::RedisSubscriber> subscriber_;
  PublishLocal publish_local_;
  std::atomic<bool> subscribed_{false};
};

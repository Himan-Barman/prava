#include "realtime/ws_fanout.h"

#include <cstring>
#include <string>

namespace {
constexpr const char* kChannelPrefix = "ws:";
}  // namespace

WsFanout::WsFanout(drogon::nosql::RedisClientPtr redis,
                   PublishLocal publish_local)
    : redis_(std::move(redis)), publish_local_(std::move(publish_local)) {}

void WsFanout::Init() {
  if (subscribed_.load() || !redis_) {
    return;
  }

  try {
    subscriber_ = redis_->newSubscriber();
    if (!subscriber_) {
      return;
    }

    subscriber_->psubscribe(
        std::string(kChannelPrefix) + "*",
        [this](const std::string& channel, const std::string& message) {
          if (channel.rfind(kChannelPrefix, 0) != 0) {
            return;
          }
          const std::string topic = channel.substr(std::strlen(kChannelPrefix));
          if (topic.empty()) {
            return;
          }
          publish_local_(topic, message);
        });

    subscribed_.store(true);
  } catch (const std::exception&) {
    subscribed_.store(false);
  }
}

void WsFanout::Publish(const std::string& /*scope*/,
                       const std::string& topic,
                       const std::string& payload) {
  if (!topic.empty() && redis_ && subscribed_.load()) {
    try {
      const std::string channel = std::string(kChannelPrefix) + topic;
      redis_->execCommandSync<void>(
          [](const drogon::nosql::RedisResult&) {},
          "PUBLISH %s %s",
          channel.c_str(),
          payload.c_str());
      return;
    } catch (const std::exception&) {
      // Fall back to local delivery.
    }
  }

  publish_local_(topic, payload);
}

bool WsFanout::IsSubscribed() const {
  return subscribed_.load();
}

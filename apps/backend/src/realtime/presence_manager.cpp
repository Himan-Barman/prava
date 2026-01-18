#include "realtime/presence_manager.h"

#include <chrono>
#include <string>

#include "app_state.h"

namespace {

constexpr int kPresenceTtlSec = 90;

std::string PresenceKey(const std::string& user_id) {
  return "presence:devices:" + user_id;
}

}  // namespace

void PresenceManager::Connect(const std::string& user_id,
                              const std::string& device_id) const {
  const auto& redis = AppState::Instance().GetRedis();
  if (!redis) {
    return;
  }

  if (user_id.empty()) {
    return;
  }

  const std::string key = PresenceKey(user_id);
  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::system_clock::now().time_since_epoch())
                       .count();

  try {
    if (!device_id.empty()) {
      redis->execCommandSync<int>(
          [](const drogon::nosql::RedisResult&) { return 0; },
          "ZADD %s %lld %s",
          key.c_str(),
          static_cast<long long>(now),
          device_id.c_str());
    }

    redis->execCommandSync<int>(
        [](const drogon::nosql::RedisResult&) { return 0; },
        "EXPIRE %s %d",
        key.c_str(),
        kPresenceTtlSec);
  } catch (const std::exception&) {
  }
}

void PresenceManager::Disconnect(const std::string& user_id,
                                 const std::string& device_id) const {
  const auto& redis = AppState::Instance().GetRedis();
  if (!redis) {
    return;
  }

  if (user_id.empty()) {
    return;
  }

  const std::string key = PresenceKey(user_id);
  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::system_clock::now().time_since_epoch())
                       .count();
  const auto cutoff = now - static_cast<long long>(kPresenceTtlSec) * 1000;

  try {
    if (!device_id.empty()) {
      redis->execCommandSync<int>(
          [](const drogon::nosql::RedisResult&) { return 0; },
          "ZREM %s %s",
          key.c_str(),
          device_id.c_str());
    }

    redis->execCommandSync<int>(
        [](const drogon::nosql::RedisResult&) { return 0; },
        "ZREMRANGEBYSCORE %s 0 %lld",
        key.c_str(),
        static_cast<long long>(cutoff));

    const auto count = redis->execCommandSync<long long>(
        [](const drogon::nosql::RedisResult& result) {
          return static_cast<long long>(result.asInteger());
        },
        "ZCARD %s",
        key.c_str());

    if (count == 0) {
      redis->execCommandSync<int>(
          [](const drogon::nosql::RedisResult&) { return 0; },
          "DEL %s",
          key.c_str());
    }
  } catch (const std::exception&) {
  }
}

bool PresenceManager::IsOnline(const std::string& user_id) const {
  const auto& redis = AppState::Instance().GetRedis();
  if (!redis) {
    return false;
  }

  if (user_id.empty()) {
    return false;
  }

  const std::string key = PresenceKey(user_id);
  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::system_clock::now().time_since_epoch())
                       .count();
  const auto cutoff = now - static_cast<long long>(kPresenceTtlSec) * 1000;

  try {
    redis->execCommandSync<int>(
        [](const drogon::nosql::RedisResult&) { return 0; },
        "ZREMRANGEBYSCORE %s 0 %lld",
        key.c_str(),
        static_cast<long long>(cutoff));

    const auto count = redis->execCommandSync<long long>(
        [](const drogon::nosql::RedisResult& result) {
          return static_cast<long long>(result.asInteger());
        },
        "ZCARD %s",
        key.c_str());

    return count > 0;
  } catch (const std::exception&) {
    return false;
  }
}

bool PresenceManager::IsDeviceOnline(const std::string& user_id,
                                     const std::string& device_id) const {
  const auto& redis = AppState::Instance().GetRedis();
  if (!redis) {
    return false;
  }

  if (user_id.empty() || device_id.empty()) {
    return false;
  }

  const std::string key = PresenceKey(user_id);
  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::system_clock::now().time_since_epoch())
                       .count();
  const auto cutoff = now - static_cast<long long>(kPresenceTtlSec) * 1000;

  try {
    const auto score = redis->execCommandSync<long long>(
        [](const drogon::nosql::RedisResult& result) -> long long {
          if (result.isNil()) {
            return 0;
          }
          const auto value = result.asString();
          if (value.empty()) {
            return 0;
          }
          try {
            return std::stoll(value);
          } catch (const std::exception&) {
            return 0;
          }
        },
        "ZSCORE %s %s",
        key.c_str(),
        device_id.c_str());

    if (score <= 0) {
      return false;
    }

    if (score < cutoff) {
      redis->execCommandSync<int>(
          [](const drogon::nosql::RedisResult&) { return 0; },
          "ZREM %s %s",
          key.c_str(),
          device_id.c_str());
      return false;
    }

    return true;
  } catch (const std::exception&) {
    return false;
  }
}

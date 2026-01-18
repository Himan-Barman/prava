#include "app_state.h"

#include <stdexcept>

AppState& AppState::Instance() {
  static AppState instance;
  return instance;
}

void AppState::Init(Config config,
                    drogon::orm::DbClientPtr db,
                    drogon::nosql::RedisClientPtr redis) {
  config_ = std::move(config);
  db_ = std::move(db);
  redis_ = std::move(redis);
}

const Config& AppState::GetConfig() const {
  return config_;
}

const drogon::orm::DbClientPtr& AppState::GetDb() const {
  if (!db_) {
    throw std::runtime_error("database client is not initialized");
  }
  return db_;
}

const drogon::nosql::RedisClientPtr& AppState::GetRedis() const {
  return redis_;
}

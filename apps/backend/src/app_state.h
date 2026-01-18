#pragma once

#include <memory>

#include <drogon/nosql/RedisClient.h>
#include <drogon/orm/DbClient.h>

#include "db/sql.h"

#include "config/config.h"

class AppState {
 public:
  static AppState& Instance();

  void Init(Config config,
            drogon::orm::DbClientPtr db,
            drogon::nosql::RedisClientPtr redis);

  const Config& GetConfig() const;
  const drogon::orm::DbClientPtr& GetDb() const;
  const drogon::nosql::RedisClientPtr& GetRedis() const;

 private:
  AppState() = default;

  Config config_{};
  drogon::orm::DbClientPtr db_{};
  drogon::nosql::RedisClientPtr redis_{};
};

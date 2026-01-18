#pragma once

#include <optional>
#include <string>

#include <drogon/orm/DbClient.h>

#include "db/sql.h"
#include <json/json.h>

struct NotificationInput {
  std::string user_id;
  std::optional<std::string> actor_id;
  std::string type;
  std::string title;
  std::string body;
  Json::Value data{Json::objectValue};
  bool push = false;
};

class NotificationsService {
 public:
  explicit NotificationsService(drogon::orm::DbClientPtr db);

  Json::Value ListForUser(const std::string& user_id,
                          const std::optional<int>& limit,
                          const std::optional<std::string>& cursor);
  int CountUnread(const std::string& user_id);
  Json::Value MarkRead(const std::string& user_id,
                       const std::string& notification_id);
  Json::Value MarkAllRead(const std::string& user_id);
  std::optional<Json::Value> CreateNotification(const NotificationInput& input);

 private:
  drogon::orm::DbClientPtr db_;
};

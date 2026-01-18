#pragma once

#include <string>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>
#include <json/json.h>

struct DevicesError : public std::runtime_error {
  DevicesError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

class DevicesService {
 public:
  explicit DevicesService(drogon::orm::DbClientPtr db);

  Json::Value RegisterPushToken(const std::string& user_id,
                                const std::string& device_id,
                                const std::string& platform,
                                const std::string& token);
  Json::Value RevokePushToken(const std::string& user_id,
                              const std::string& device_id);

 private:
  drogon::orm::DbClientPtr db_;
};

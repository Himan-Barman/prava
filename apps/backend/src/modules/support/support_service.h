#pragma once

#include <optional>
#include <string>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>
#include <json/json.h>

struct SupportError : public std::runtime_error {
  SupportError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct SupportTicketInput {
  std::string user_id;
  std::string type;
  std::optional<std::string> category;
  std::string message;
  std::optional<bool> include_logs;
  std::optional<bool> allow_contact;
  std::optional<int> score;
};

class SupportService {
 public:
  explicit SupportService(drogon::orm::DbClientPtr db);

  Json::Value CreateTicket(const SupportTicketInput& input);

 private:
  drogon::orm::DbClientPtr db_;
};

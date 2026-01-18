#pragma once

#include <optional>
#include <string>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>
#include <json/json.h>

struct FeedError : public std::runtime_error {
  FeedError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

class FeedService {
 public:
  explicit FeedService(drogon::orm::DbClientPtr db);

  Json::Value CreatePost(const std::string& user_id, const std::string& body);
  Json::Value ListFeed(const std::string& user_id,
                       const std::optional<int>& limit,
                       const std::optional<std::string>& before,
                       const std::string& mode);
  Json::Value ToggleLike(const std::string& user_id,
                         const std::string& post_id);
  Json::Value ListComments(const std::string& user_id,
                           const std::string& post_id,
                           const std::optional<int>& limit);
  Json::Value AddComment(const std::string& user_id,
                         const std::string& post_id,
                         const std::string& body);
  Json::Value SharePost(const std::string& user_id,
                        const std::string& post_id);

 private:
  drogon::orm::DbClientPtr db_;
};

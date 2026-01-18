#pragma once

#include <optional>
#include <string>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>

#include "db/sql.h"
#include <json/json.h>

struct UsersError : public std::runtime_error {
  UsersError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct UserLimitInput {
  std::string user_id;
  std::optional<int> limit;
};

struct SearchUsersInput {
  std::string user_id;
  std::string query;
  std::optional<int> limit;
};

struct FollowInput {
  std::string follower_id;
  std::string following_id;
};

struct SetFollowInput {
  std::string follower_id;
  std::string following_id;
  bool follow = false;
};

struct RemoveFollowerInput {
  std::string user_id;
  std::string follower_id;
};

struct RemoveConnectionInput {
  std::string user_id;
  std::string target_user_id;
};

struct PublicProfileInput {
  std::string target_user_id;
  std::string viewer_id;
  std::optional<int> limit;
};

struct UpdateHandleInput {
  std::optional<std::string> username;
  std::optional<std::string> display_name;
  std::optional<std::string> bio;
  std::optional<std::string> location;
  std::optional<std::string> website;
};

struct UpdateDetailsInput {
  std::string first_name;
  std::string last_name;
  std::string phone_country_code;
  std::string phone_number;
};

struct BlockInput {
  std::string user_id;
  std::string target_user_id;
};

struct AddMutedWordInput {
  std::string user_id;
  std::string phrase;
};

struct RemoveMutedWordInput {
  std::string user_id;
  std::string word_id;
};

class UsersService {
 public:
  explicit UsersService(drogon::orm::DbClientPtr db);

  Json::Value SearchUsers(const SearchUsersInput& input);
  bool IsUsernameAvailable(const std::string& username);
  Json::Value ToggleFollow(const FollowInput& input);
  Json::Value SetFollow(const SetFollowInput& input);
  Json::Value RemoveFollower(const RemoveFollowerInput& input);
  Json::Value RemoveConnection(const RemoveConnectionInput& input);
  Json::Value GetConnections(const UserLimitInput& input);
  Json::Value GetProfileSummary(const UserLimitInput& input);
  Json::Value GetPublicProfileSummary(const PublicProfileInput& input);
  Json::Value UpdateDetails(const std::string& user_id,
                            const UpdateDetailsInput& input);
  Json::Value GetSettings(const std::string& user_id);
  Json::Value UpdateSettings(const std::string& user_id,
                             const Json::Value& updates);
  Json::Value GetAccountInfo(const std::string& user_id);
  Json::Value UpdateEmail(const std::string& user_id,
                          const std::string& email);
  Json::Value UpdateHandle(const std::string& user_id,
                           const UpdateHandleInput& input);
  Json::Value ListBlockedUsers(const UserLimitInput& input);
  Json::Value BlockUser(const BlockInput& input);
  Json::Value UnblockUser(const BlockInput& input);
  Json::Value ListMutedWords(const UserLimitInput& input);
  Json::Value AddMutedWord(const AddMutedWordInput& input);
  Json::Value RemoveMutedWord(const RemoveMutedWordInput& input);
  Json::Value CreateDataExport(const std::string& user_id);
  Json::Value GetLatestDataExport(const std::string& user_id);
  Json::Value DeleteAccount(const std::string& user_id);

 private:
  void EnsureNotBlocked(const std::string& user_id,
                        const std::string& target_user_id);
  void NotifyFollow(const std::string& follower_id,
                    const std::string& following_id);

  drogon::orm::DbClientPtr db_;
};

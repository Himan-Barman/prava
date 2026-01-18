#pragma once

#include <string>
#include <vector>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>

#include "db/sql.h"
#include <json/json.h>

struct ConversationsError : public std::runtime_error {
  ConversationsError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct CreateGroupInput {
  std::string user_id;
  std::string title;
  std::vector<std::string> member_ids;
};

struct AddMembersInput {
  std::string conversation_id;
  std::string requester_id;
  std::vector<std::string> member_ids;
};

class ConversationsService {
 public:
  explicit ConversationsService(drogon::orm::DbClientPtr db);

  bool HasMembership(const std::string& conversation_id,
                     const std::string& user_id);
  std::string MembershipRole(const std::string& conversation_id,
                             const std::string& user_id);
  std::vector<std::string> ListConversationIdsForUser(
      const std::string& user_id);
  Json::Value ListForUser(const std::string& user_id);
  Json::Value CreateDm(const std::string& user_id,
                       const std::string& other_user_id);
  Json::Value CreateGroup(const CreateGroupInput& input);
  Json::Value AddMembers(const AddMembersInput& input);
  Json::Value ListMembers(const std::string& conversation_id);
  void LeaveConversation(const std::string& conversation_id,
                         const std::string& user_id);

 private:
  drogon::orm::DbClientPtr db_;
};

#pragma once

#include <optional>
#include <string>
#include <vector>

#include <drogon/orm/DbClient.h>

struct SyncInput {
  std::string user_id;
  std::string device_id;
  std::string conversation_id;
  int last_delivered_seq = 0;
};

struct SyncMessage {
  std::string id;
  std::string conversation_id;
  int seq = 0;
  std::string sender_user_id;
  std::string sender_device_id;
  std::string body;
  std::string content_type;
  std::optional<std::string> media_asset_id;
  int edit_version = 0;
  std::optional<std::string> deleted_for_all_at;
  std::string created_at;
};

class SyncService {
 public:
  explicit SyncService(drogon::orm::DbClientPtr db);

  std::vector<SyncMessage> SyncConversation(const SyncInput& input);

 private:
  drogon::orm::DbClientPtr db_;
};

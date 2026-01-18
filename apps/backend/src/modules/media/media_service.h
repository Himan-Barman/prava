#pragma once

#include <optional>
#include <string>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>
#include <json/json.h>

struct MediaError : public std::runtime_error {
  MediaError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct MediaInitInput {
  std::string user_id;
  std::string conversation_id;
  std::string content_type;
  std::optional<std::string> file_name;
  std::optional<long long> size_bytes;
  std::optional<std::string> sha256;
  std::optional<std::string> retention_policy;
  std::optional<std::string> encryption_algorithm;
  std::optional<std::string> encryption_key_id;
  std::optional<std::string> encryption_iv;
  std::optional<std::string> encryption_key_hash;
  Json::Value metadata{Json::objectValue};
};

struct MediaCompleteInput {
  std::string asset_id;
  std::string user_id;
  std::optional<long long> size_bytes;
  std::optional<std::string> sha256;
  Json::Value metadata{Json::objectValue};
  std::optional<std::string> file_name;
};

class MediaService {
 public:
  explicit MediaService(drogon::orm::DbClientPtr db);

  Json::Value InitUpload(const MediaInitInput& input);
  Json::Value CompleteUpload(const MediaCompleteInput& input);
  std::optional<Json::Value> GetAssetForUser(const std::string& asset_id,
                                             const std::string& user_id);
  Json::Value AssertAssetReadyForMessage(const std::string& asset_id,
                                         const std::string& user_id,
                                         const std::string& conversation_id);

 private:
  drogon::orm::DbClientPtr db_;
};

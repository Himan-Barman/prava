#pragma once

#include <optional>
#include <string>
#include <vector>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>
#include <json/json.h>

struct E2eError : public std::runtime_error {
  E2eError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct SignedPreKeyInput {
  int key_id = 0;
  std::string public_key;
  std::string signature;
  std::optional<std::string> expires_at;
};

struct PreKeyInput {
  int key_id = 0;
  std::string public_key;
};

class E2eService {
 public:
  explicit E2eService(drogon::orm::DbClientPtr db);

  Json::Value RegisterDeviceKeys(
      const std::string& user_id,
      const std::string& device_id,
      const std::string& platform,
      const std::optional<std::string>& device_name,
      const std::string& identity_key,
      const std::optional<int>& registration_id,
      const SignedPreKeyInput& signed_pre_key,
      const std::vector<PreKeyInput>& one_time_pre_keys);

  Json::Value UploadPreKeys(const std::string& user_id,
                            const std::string& device_id,
                            const std::vector<PreKeyInput>& pre_keys);

  Json::Value RotateSignedPreKey(const std::string& user_id,
                                 const std::string& device_id,
                                 const SignedPreKeyInput& signed_pre_key);

  Json::Value ListDevicesForUser(const std::string& requester_id,
                                 const std::string& target_user_id);

  Json::Value GetPreKeyBundle(const std::string& requester_id,
                              const std::string& target_user_id,
                              const std::string& target_device_id);

  Json::Value SetTrust(const std::string& requester_id,
                       const std::string& target_user_id,
                       const std::string& target_device_id,
                       const std::string& status);

  Json::Value ListTrustForUser(const std::string& requester_id,
                               const std::string& target_user_id);

 private:
  void EnsureKeyAccess(const std::string& requester_id,
                       const std::string& target_user_id);

  std::string Fingerprint(const std::string& key);

  void UpsertSignedPreKey(const std::string& user_id,
                          const std::string& device_id,
                          const SignedPreKeyInput& signed_pre_key);

  drogon::orm::DbClientPtr db_;
};

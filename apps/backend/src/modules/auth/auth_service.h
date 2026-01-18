#pragma once

#include <string>
#include <vector>

#include <drogon/HttpTypes.h>
#include <drogon/orm/DbClient.h>
#include <json/json.h>

#include "modules/auth/token_service.h"

struct AuthError : public std::runtime_error {
  AuthError(drogon::HttpStatusCode status, const std::string& message)
      : std::runtime_error(message), status(status) {}
  drogon::HttpStatusCode status;
};

struct RegisterInput {
  std::string email;
  std::string password;
  std::string username;
  std::string device_id;
  std::string device_name;
  std::string platform;
};

struct LoginInput {
  std::string email;
  std::string password;
  std::string device_id;
  std::string device_name;
  std::string platform;
};

struct RefreshInput {
  std::string refresh_token;
  std::string device_id;
};

struct DeviceInput {
  std::string device_id;
};

struct CurrentDeviceInput {
  std::string current_device_id;
};

struct EmailInput {
  std::string email;
};

struct PasswordResetInput {
  std::string token;
  std::string new_password;
};

struct EmailOtpInput {
  std::string email;
};

struct EmailOtpVerifyInput {
  std::string email;
  std::string code;
};

class AuthService {
 public:
  AuthService(drogon::orm::DbClientPtr db, TokenService tokens);

  Json::Value Register(const RegisterInput& input);
  Json::Value Login(const LoginInput& input);
  Json::Value Refresh(const RefreshInput& input);
  Json::Value Logout(const std::string& user_id, const DeviceInput& input);
  Json::Value LogoutAll(const std::string& user_id);
  Json::Value RequestEmailVerification(const EmailInput& input);
  Json::Value VerifyEmail(const std::string& token);
  Json::Value RequestPasswordReset(const EmailInput& input);
  Json::Value ResetPassword(const PasswordResetInput& input);
  Json::Value RequestEmailOtp(const EmailOtpInput& input);
  Json::Value VerifyEmailOtp(const EmailOtpVerifyInput& input);
  Json::Value ListSessions(const std::string& user_id);
  Json::Value RevokeSession(const std::string& user_id, const DeviceInput& input);
  Json::Value RevokeOtherSessions(const std::string& user_id,
                                  const CurrentDeviceInput& input);

 private:
  std::string IssueRefreshToken(const std::string& user_id,
                                const std::string& device_id,
                                const std::string& device_name,
                                const std::string& platform);
  Json::Value BuildSessionRow(const drogon::orm::Row& row) const;

  void EnsureEmailOtpVerified(const std::string& email);
  void CreateEmailVerification(const std::string& user_id,
                               const std::string& email);
  void CreatePasswordReset(const std::string& user_id,
                           const std::string& email);

  drogon::orm::DbClientPtr db_;
  TokenService tokens_;
};

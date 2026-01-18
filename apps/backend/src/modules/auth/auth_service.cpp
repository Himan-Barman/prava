#include "modules/auth/auth_service.h"

#include <chrono>
#include <iomanip>
#include <sstream>
#include <string>

#include <drogon/utils/Utilities.h>

#include "app_state.h"
#include "email/email_service.h"
#include "modules/auth/auth_validation.h"
#include "modules/auth/password_hasher.h"

namespace {

std::string NormalizeEmail(const std::string& value) {
  return ToLower(Trim(value));
}

std::string NormalizeUsername(const std::string& value) {
  return ToLower(Trim(value));
}

std::string GenerateOtpCode() {
  uint32_t value = 0;
  if (!drogon::utils::secureRandomBytes(&value, sizeof(value))) {
    throw std::runtime_error("secure random failed");
  }
  value = value % 1000000;
  std::ostringstream stream;
  stream << std::setw(6) << std::setfill('0') << value;
  return stream.str();
}

}  // namespace

AuthService::AuthService(drogon::orm::DbClientPtr db, TokenService tokens)
    : db_(std::move(db)), tokens_(std::move(tokens)) {}

Json::Value AuthService::Register(const RegisterInput& input) {
  const std::string email = NormalizeEmail(input.email);
  if (!IsValidEmail(email)) {
    throw AuthError(drogon::k400BadRequest, "Invalid email");
  }

  std::string username = input.username.empty() ? email.substr(0, email.find('@'))
                                                : input.username;
  username = NormalizeUsername(username);
  if (!IsValidUsername(username)) {
    throw AuthError(drogon::k400BadRequest, "Invalid username");
  }

  if (!IsValidPassword(input.password)) {
    throw AuthError(drogon::k400BadRequest, "Invalid password");
  }
  if (!IsValidDeviceId(input.device_id)) {
    throw AuthError(drogon::k400BadRequest, "Invalid device");
  }
  const std::string platform = ToLower(Trim(input.platform));
  if (!IsValidPlatform(platform)) {
    throw AuthError(drogon::k400BadRequest, "Invalid platform");
  }

  EnsureEmailOtpVerified(email);

  auto existing = db_->execSqlSync(
      "SELECT id FROM users WHERE email = ? LIMIT 1", email);
  if (!existing.empty()) {
    throw AuthError(drogon::k409Conflict, "Email already exists");
  }
  existing = db_->execSqlSync(
      "SELECT id FROM users WHERE username = ? LIMIT 1", username);
  if (!existing.empty()) {
    throw AuthError(drogon::k409Conflict, "Username already exists");
  }

  const std::string password_hash = HashPassword(input.password);

  const auto rows = db_->execSqlSync(
      "INSERT INTO users (email, username, display_name, password_hash, "
      "is_verified, email_verified_at) "
      "VALUES (?, ?, ?, ?, true, NOW()) "
      "RETURNING id, email, username, display_name, is_verified",
      email,
      username,
      username,
      password_hash);

  if (rows.empty()) {
    throw std::runtime_error("register failed");
  }

  const auto& row = rows.front();
  const std::string user_id = row["id"].as<std::string>();

  Json::Value user;
  user["id"] = user_id;
  user["email"] = row["email"].as<std::string>();
  user["username"] = row["username"].as<std::string>();
  const std::string display_name =
      row["display_name"].isNull() ? user["username"].asString()
                                   : row["display_name"].as<std::string>();
  user["displayName"] = display_name;
  user["isVerified"] = row["is_verified"].as<bool>();

  const std::string refresh_token = IssueRefreshToken(
      user_id, input.device_id, input.device_name, platform);

  Json::Value response;
  response["user"] = user;
  response["accessToken"] = tokens_.SignAccessToken(user_id);
  response["refreshToken"] = refresh_token;
  return response;
}

Json::Value AuthService::Login(const LoginInput& input) {
  const std::string identifier = NormalizeEmail(input.email);
  if (identifier.size() < 3 || identifier.size() > 255) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }
  if (!IsValidPassword(input.password)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }
  if (!IsValidDeviceId(input.device_id)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  const bool is_email = identifier.find('@') != std::string::npos;
  const auto rows = db_->execSqlSync(
      std::string("SELECT id, email, username, display_name, is_verified, "
                  "password_hash FROM users WHERE ") +
          (is_email ? "email = ?" : "username = ?") + " LIMIT 1",
      identifier);

  if (rows.empty()) {
    throw AuthError(drogon::k401Unauthorized, "Invalid credentials");
  }

  const auto& row = rows.front();
  const std::string password_hash = row["password_hash"].as<std::string>();
  if (!VerifyPassword(password_hash, input.password)) {
    throw AuthError(drogon::k401Unauthorized, "Invalid credentials");
  }

  const std::string user_id = row["id"].as<std::string>();
  const std::string platform = ToLower(Trim(input.platform));
  if (!IsValidPlatform(platform)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  Json::Value user;
  user["id"] = user_id;
  user["email"] = row["email"].as<std::string>();
  user["username"] = row["username"].as<std::string>();
  const std::string display_name =
      row["display_name"].isNull() ? user["username"].asString()
                                   : row["display_name"].as<std::string>();
  user["displayName"] = display_name;
  user["isVerified"] = row["is_verified"].as<bool>();

  const std::string refresh_token = IssueRefreshToken(
      user_id, input.device_id, input.device_name, platform);

  Json::Value response;
  response["user"] = user;
  response["accessToken"] = tokens_.SignAccessToken(user_id);
  response["refreshToken"] = refresh_token;
  return response;
}

Json::Value AuthService::Refresh(const RefreshInput& input) {
  if (!IsValidRefreshToken(input.refresh_token)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }
  if (!IsValidDeviceId(input.device_id)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  const std::string token_hash = drogon::utils::getSha256(input.refresh_token);
  const auto rows = db_->execSqlSync(
      "SELECT id, user_id, COALESCE(device_name, ''), COALESCE(platform, '') "
      "FROM refresh_tokens "
      "WHERE token_hash = ? AND device_id = ? AND revoked_at IS NULL "
      "AND expires_at > NOW() LIMIT 1",
      token_hash,
      input.device_id);

  if (rows.empty()) {
    throw AuthError(drogon::k401Unauthorized, "Invalid refresh token");
  }

  const auto& row = rows.front();
  const std::string refresh_id = row["id"].as<std::string>();
  const std::string user_id = row["user_id"].as<std::string>();
  const std::string device_name = row[2].as<std::string>();
  const std::string platform = row[3].as<std::string>();

  db_->execSqlSync(
      "UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = ?",
      refresh_id);

  const std::string refresh_token = IssueRefreshToken(
      user_id, input.device_id, device_name, platform);

  Json::Value response;
  response["accessToken"] = tokens_.SignAccessToken(user_id);
  response["refreshToken"] = refresh_token;
  return response;
}

Json::Value AuthService::Logout(const std::string& user_id,
                                const DeviceInput& input) {
  if (!IsValidDeviceId(input.device_id)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  db_->execSqlSync(
      "UPDATE refresh_tokens SET revoked_at = NOW() "
      "WHERE user_id = ? AND device_id = ?",
      user_id,
      input.device_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

Json::Value AuthService::LogoutAll(const std::string& user_id) {
  db_->execSqlSync(
      "UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = ?",
      user_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

Json::Value AuthService::RequestEmailVerification(const EmailInput& input) {
  const std::string email = NormalizeEmail(input.email);
  if (!IsValidEmail(email)) {
    throw AuthError(drogon::k400BadRequest, "Invalid email");
  }

  const auto users = db_->execSqlSync(
      "SELECT id, is_verified FROM users WHERE email = ? LIMIT 1",
      email);
  if (users.empty() || users.front()["is_verified"].as<bool>()) {
    Json::Value response;
    response["success"] = true;
    return response;
  }

  const std::string user_id = users.front()["id"].as<std::string>();

  db_->execSqlSync(
      "UPDATE email_verification_tokens SET used_at = NOW() "
      "WHERE user_id = ? AND used_at IS NULL AND expires_at > NOW()",
      user_id);

  CreateEmailVerification(user_id, email);

  Json::Value response;
  response["success"] = true;
  return response;
}

Json::Value AuthService::VerifyEmail(const std::string& token) {
  const std::string trimmed = Trim(token);
  if (trimmed.empty()) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  const std::string hash = drogon::utils::getSha256(trimmed);
  const auto rows = db_->execSqlSync(
      "SELECT id, user_id FROM email_verification_tokens "
      "WHERE token_hash = ? AND used_at IS NULL AND expires_at > NOW() "
      "LIMIT 1",
      hash);

  if (rows.empty()) {
    throw AuthError(drogon::k401Unauthorized, "Invalid or expired code");
  }

  const std::string token_id = rows.front()["id"].as<std::string>();
  const std::string user_id = rows.front()["user_id"].as<std::string>();

  db_->execSqlSync(
      "UPDATE users SET is_verified = true, email_verified_at = NOW() "
      "WHERE id = ?",
      user_id);
  db_->execSqlSync(
      "UPDATE email_verification_tokens SET used_at = NOW() WHERE id = ?",
      token_id);

  Json::Value response;
  response["verified"] = true;
  return response;
}

Json::Value AuthService::RequestPasswordReset(const EmailInput& input) {
  const std::string email = NormalizeEmail(input.email);
  if (!IsValidEmail(email)) {
    throw AuthError(drogon::k400BadRequest, "Invalid email");
  }

  const auto users = db_->execSqlSync(
      "SELECT id FROM users WHERE email = ? LIMIT 1", email);
  if (users.empty()) {
    Json::Value response;
    response["success"] = true;
    return response;
  }

  const std::string user_id = users.front()["id"].as<std::string>();
  CreatePasswordReset(user_id, email);

  Json::Value response;
  response["success"] = true;
  return response;
}

Json::Value AuthService::ResetPassword(const PasswordResetInput& input) {
  const std::string token = Trim(input.token);
  if (!IsValidOtpCode(token) || !IsValidPassword(input.new_password)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  const std::string hash = drogon::utils::getSha256(token);
  const auto rows = db_->execSqlSync(
      "SELECT id, user_id FROM password_reset_tokens "
      "WHERE token_hash = ? AND used_at IS NULL AND expires_at > NOW() "
      "LIMIT 1",
      hash);

  if (rows.empty()) {
    throw AuthError(drogon::k401Unauthorized, "Invalid or expired code");
  }

  const std::string token_id = rows.front()["id"].as<std::string>();
  const std::string user_id = rows.front()["user_id"].as<std::string>();

  const std::string new_hash = HashPassword(input.new_password);
  db_->execSqlSync(
      "UPDATE users SET password_hash = ? WHERE id = ?",
      new_hash,
      user_id);
  db_->execSqlSync(
      "UPDATE password_reset_tokens SET used_at = NOW() WHERE id = ?",
      token_id);
  db_->execSqlSync(
      "UPDATE refresh_tokens SET revoked_at = NOW() WHERE user_id = ?",
      user_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

Json::Value AuthService::RequestEmailOtp(const EmailOtpInput& input) {
  const std::string email = NormalizeEmail(input.email);
  if (!IsValidEmail(email)) {
    throw AuthError(drogon::k400BadRequest, "Invalid email");
  }

  const auto users = db_->execSqlSync(
      "SELECT id, is_verified FROM users WHERE email = ? LIMIT 1",
      email);
  if (!users.empty() && users.front()["is_verified"].as<bool>()) {
    Json::Value response;
    response["success"] = true;
    return response;
  }

  db_->execSqlSync(
      "UPDATE email_otp_tokens SET used_at = NOW() "
      "WHERE email = ? AND used_at IS NULL AND expires_at > NOW()",
      email);

  const int expires_in_minutes = 10;
  const std::string code = GenerateOtpCode();
  const std::string hash = drogon::utils::getSha256(code);

  db_->execSqlSync(
      "INSERT INTO email_otp_tokens (email, token_hash, expires_at) "
      "VALUES (?, ?, NOW() + interval '10 minutes')",
      email,
      hash);

  EmailService emailer(AppState::Instance().GetConfig());
  emailer.SendEmailOtp(email, code, expires_in_minutes);

  Json::Value response;
  response["success"] = true;
  response["expiresIn"] = expires_in_minutes * 60;
  return response;
}

Json::Value AuthService::VerifyEmailOtp(const EmailOtpVerifyInput& input) {
  const std::string email = NormalizeEmail(input.email);
  const std::string code = Trim(input.code);
  if (!IsValidEmail(email) || !IsValidOtpCode(code)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  const auto rows = db_->execSqlSync(
      "SELECT id, token_hash, attempts FROM email_otp_tokens "
      "WHERE email = ? AND used_at IS NULL AND expires_at > NOW() "
      "ORDER BY created_at DESC LIMIT 1",
      email);

  if (rows.empty()) {
    throw AuthError(drogon::k401Unauthorized, "Invalid or expired code");
  }

  const auto& row = rows.front();
  const std::string token_id = row["id"].as<std::string>();
  const std::string token_hash = row["token_hash"].as<std::string>();
  const int attempts = row["attempts"].as<int>();

  if (attempts >= 5) {
    db_->execSqlSync(
        "UPDATE email_otp_tokens SET used_at = NOW() WHERE id = ?",
        token_id);
    throw AuthError(drogon::k401Unauthorized, "Invalid or expired code");
  }

  const std::string hash = drogon::utils::getSha256(code);
  if (hash != token_hash) {
    const int next_attempts = attempts + 1;
    db_->execSqlSync(
        "UPDATE email_otp_tokens SET attempts = ?, used_at = "
        "CASE WHEN ? >= 5 THEN NOW() ELSE NULL END "
        "WHERE id = ?",
        next_attempts,
        next_attempts,
        token_id);
    throw AuthError(drogon::k401Unauthorized, "Invalid or expired code");
  }

  db_->execSqlSync(
      "UPDATE email_otp_tokens SET used_at = NOW() WHERE id = ?",
      token_id);
  db_->execSqlSync(
      "UPDATE users SET is_verified = true, email_verified_at = NOW() "
      "WHERE email = ? AND is_verified = false",
      email);

  Json::Value response;
  response["verified"] = true;
  return response;
}

Json::Value AuthService::ListSessions(const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT id, device_id, device_name, platform, "
      "to_char(created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS created_at, "
      "to_char(last_seen_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS last_seen_at, "
      "to_char(expires_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"') AS expires_at "
      "FROM refresh_tokens "
      "WHERE user_id = ? AND revoked_at IS NULL AND expires_at > NOW() "
      "ORDER BY created_at",
      user_id);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    items.append(BuildSessionRow(row));
  }
  return items;
}

Json::Value AuthService::RevokeSession(const std::string& user_id,
                                       const DeviceInput& input) {
  if (!IsValidDeviceId(input.device_id)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  db_->execSqlSync(
      "UPDATE refresh_tokens SET revoked_at = NOW() "
      "WHERE user_id = ? AND device_id = ? AND revoked_at IS NULL",
      user_id,
      input.device_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

Json::Value AuthService::RevokeOtherSessions(
    const std::string& user_id,
    const CurrentDeviceInput& input) {
  if (!IsValidDeviceId(input.current_device_id)) {
    throw AuthError(drogon::k400BadRequest, "Invalid request");
  }

  db_->execSqlSync(
      "UPDATE refresh_tokens SET revoked_at = NOW() "
      "WHERE user_id = ? AND revoked_at IS NULL AND device_id <> ?",
      user_id,
      input.current_device_id);

  Json::Value response;
  response["success"] = true;
  return response;
}

std::string AuthService::IssueRefreshToken(const std::string& user_id,
                                           const std::string& device_id,
                                           const std::string& device_name,
                                           const std::string& platform) {
  const auto token = tokens_.GenerateRefreshToken();
  db_->execSqlSync(
      "INSERT INTO refresh_tokens (user_id, device_id, device_name, platform, "
      "token_hash, expires_at, last_seen_at) "
      "VALUES (?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, NOW() + interval '30 days', NOW())",
      user_id,
      device_id,
      device_name,
      platform,
      token.hash);
  return token.raw;
}

Json::Value AuthService::BuildSessionRow(const drogon::orm::Row& row) const {
  Json::Value item;
  item["id"] = row["id"].as<std::string>();
  item["deviceId"] = row["device_id"].as<std::string>();
  if (row["device_name"].isNull()) {
    item["deviceName"] = Json::nullValue;
  } else {
    item["deviceName"] = row["device_name"].as<std::string>();
  }
  if (row["platform"].isNull()) {
    item["platform"] = Json::nullValue;
  } else {
    item["platform"] = row["platform"].as<std::string>();
  }
  if (row["created_at"].isNull()) {
    item["createdAt"] = Json::nullValue;
  } else {
    item["createdAt"] = row["created_at"].as<std::string>();
  }
  if (row["last_seen_at"].isNull()) {
    item["lastSeenAt"] = Json::nullValue;
  } else {
    item["lastSeenAt"] = row["last_seen_at"].as<std::string>();
  }
  if (row["expires_at"].isNull()) {
    item["expiresAt"] = Json::nullValue;
  } else {
    item["expiresAt"] = row["expires_at"].as<std::string>();
  }
  return item;
}

void AuthService::EnsureEmailOtpVerified(const std::string& email) {
  const auto rows = db_->execSqlSync(
      "SELECT id FROM email_otp_tokens "
      "WHERE email = ? AND used_at IS NOT NULL "
      "AND used_at > NOW() - interval '15 minutes' "
      "ORDER BY used_at DESC LIMIT 1",
      email);

  if (rows.empty()) {
    throw AuthError(drogon::k401Unauthorized, "Email verification required");
  }
}

void AuthService::CreateEmailVerification(const std::string& user_id,
                                          const std::string& email) {
  const std::string raw = drogon::utils::secureRandomString(64);
  const std::string hash = drogon::utils::getSha256(raw);

  db_->execSqlSync(
      "INSERT INTO email_verification_tokens (user_id, token_hash, expires_at) "
      "VALUES (?, ?, NOW() + interval '1 hour')",
      user_id,
      hash);

  EmailService emailer(AppState::Instance().GetConfig());
  emailer.SendVerifyEmail(email, raw);
}

void AuthService::CreatePasswordReset(const std::string& user_id,
                                      const std::string& email) {
  db_->execSqlSync(
      "UPDATE password_reset_tokens SET used_at = NOW() "
      "WHERE user_id = ? AND used_at IS NULL AND expires_at > NOW()",
      user_id);

  const int expires_in_minutes = 10;
  const std::string code = GenerateOtpCode();
  const std::string hash = drogon::utils::getSha256(code);

  db_->execSqlSync(
      "INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) "
      "VALUES (?, ?, NOW() + interval '10 minutes')",
      user_id,
      hash);

  EmailService emailer(AppState::Instance().GetConfig());
  emailer.SendPasswordResetCode(email, code, expires_in_minutes);
}

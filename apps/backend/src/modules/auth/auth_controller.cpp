#include "modules/auth/auth_controller.h"

#include <functional>
#include <string>
#include <unordered_set>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/auth/auth_service.h"
#include "modules/auth/token_service.h"

namespace {

bool ParseJsonPayload(const drogon::HttpRequestPtr& req,
                      const std::unordered_set<std::string>& allowed,
                      Json::Value& out,
                      drogon::HttpResponsePtr& error_resp) {
  std::string error;
  if (!http::ParseJsonObject(req, out, error)) {
    error_resp = http::ErrorResponse(drogon::k400BadRequest, error);
    return false;
  }
  if (!http::HasOnlyFields(out, allowed)) {
    error_resp = http::ErrorResponse(drogon::k400BadRequest, "Invalid payload");
    return false;
  }
  return true;
}

bool GetRequiredString(const Json::Value& body,
                       const std::string& key,
                       std::string& out) {
  return http::GetStringField(body, key, out);
}

bool GetOptionalString(const Json::Value& body,
                       const std::string& key,
                       std::string& out) {
  if (!body.isMember(key)) {
    out.clear();
    return true;
  }
  return http::GetStringField(body, key, out);
}

bool GetUserId(const drogon::HttpRequestPtr& req, std::string& user_id) {
  const auto attrs = req->getAttributes();
  if (!attrs || !attrs->find("user_id")) {
    return false;
  }
  user_id = attrs->get<std::string>("user_id");
  return true;
}

AuthService BuildAuthService() {
  const auto& state = AppState::Instance();
  const auto& cfg = state.GetConfig();
  return AuthService(state.GetDb(),
                     TokenService(cfg.jwt_private, cfg.jwt_public));
}

void RespondWithAuth(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const AuthError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void AuthController::Register(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {
      "email", "password", "username", "deviceId", "deviceName", "platform"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  RegisterInput input;
  if (!GetRequiredString(body, "email", input.email) ||
      !GetRequiredString(body, "password", input.password) ||
      !GetRequiredString(body, "deviceId", input.device_id) ||
      !GetOptionalString(body, "username", input.username) ||
      !GetOptionalString(body, "deviceName", input.device_name) ||
      !GetOptionalString(body, "platform", input.platform)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.Register(input);
      },
      std::move(callback));
}

void AuthController::Login(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {
      "email", "password", "deviceId", "deviceName", "platform"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  LoginInput input;
  if (!GetRequiredString(body, "email", input.email) ||
      !GetRequiredString(body, "password", input.password) ||
      !GetRequiredString(body, "deviceId", input.device_id) ||
      !GetOptionalString(body, "deviceName", input.device_name) ||
      !GetOptionalString(body, "platform", input.platform)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.Login(input);
      },
      std::move(callback));
}

void AuthController::Refresh(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"refreshToken",
                                                          "deviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  RefreshInput input;
  if (!GetRequiredString(body, "refreshToken", input.refresh_token) ||
      !GetRequiredString(body, "deviceId", input.device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.Refresh(input);
      },
      std::move(callback));
}

void AuthController::Logout(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"deviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  DeviceInput input;
  if (!GetRequiredString(body, "deviceId", input.device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&user_id, &input]() {
        auto auth = BuildAuthService();
        return auth.Logout(user_id, input);
      },
      std::move(callback));
}

void AuthController::LogoutAll(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithAuth(
      [&user_id]() {
        auto auth = BuildAuthService();
        return auth.LogoutAll(user_id);
      },
      std::move(callback));
}

void AuthController::VerifyEmail(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"token"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string token;
  if (!GetRequiredString(body, "token", token)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&token]() {
        auto auth = BuildAuthService();
        return auth.VerifyEmail(token);
      },
      std::move(callback));
}

void AuthController::RequestEmailVerification(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"email"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  EmailInput input;
  if (!GetRequiredString(body, "email", input.email)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.RequestEmailVerification(input);
      },
      std::move(callback));
}

void AuthController::ResendEmailVerification(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  RequestEmailVerification(req, std::move(callback));
}

void AuthController::RequestPasswordReset(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"email"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  EmailInput input;
  if (!GetRequiredString(body, "email", input.email)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.RequestPasswordReset(input);
      },
      std::move(callback));
}

void AuthController::ResetPassword(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"token",
                                                          "newPassword"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  PasswordResetInput input;
  if (!GetRequiredString(body, "token", input.token) ||
      !GetRequiredString(body, "newPassword", input.new_password)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.ResetPassword(input);
      },
      std::move(callback));
}

void AuthController::RequestEmailOtp(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"email"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  EmailOtpInput input;
  if (!GetRequiredString(body, "email", input.email)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.RequestEmailOtp(input);
      },
      std::move(callback));
}

void AuthController::VerifyEmailOtp(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"email", "code"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  EmailOtpVerifyInput input;
  if (!GetRequiredString(body, "email", input.email) ||
      !GetRequiredString(body, "code", input.code)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&input]() {
        auto auth = BuildAuthService();
        return auth.VerifyEmailOtp(input);
      },
      std::move(callback));
}

void AuthController::ListSessions(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithAuth(
      [&user_id]() {
        auto auth = BuildAuthService();
        return auth.ListSessions(user_id);
      },
      std::move(callback));
}

void AuthController::RevokeSession(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"deviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  DeviceInput input;
  if (!GetRequiredString(body, "deviceId", input.device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&user_id, &input]() {
        auto auth = BuildAuthService();
        return auth.RevokeSession(user_id, input);
      },
      std::move(callback));
}

void AuthController::RevokeOtherSessions(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"currentDeviceId"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  CurrentDeviceInput input;
  if (!GetRequiredString(body, "currentDeviceId",
                         input.current_device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  RespondWithAuth(
      [&user_id, &input]() {
        auto auth = BuildAuthService();
        return auth.RevokeOtherSessions(user_id, input);
      },
      std::move(callback));
}

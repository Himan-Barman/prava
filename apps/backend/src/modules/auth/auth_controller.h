#pragma once

#include <functional>

#include <drogon/HttpController.h>

class AuthController : public drogon::HttpController<AuthController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(AuthController::Register, "/api/auth/register", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::Login, "/api/auth/login", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::Refresh, "/api/auth/refresh", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::Logout, "/api/auth/logout", drogon::Post,
                "JwtFilter");
  ADD_METHOD_TO(AuthController::LogoutAll, "/api/auth/logout-all",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(AuthController::VerifyEmail, "/api/auth/verify-email",
                drogon::Post, "RateLimitFilter");
  ADD_METHOD_TO(AuthController::RequestEmailVerification,
                "/api/auth/verify-email/request", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::ResendEmailVerification,
                "/api/auth/verify-email/resend", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::RequestPasswordReset,
                "/api/auth/password-reset/request", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::ResetPassword,
                "/api/auth/password-reset/confirm", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::RequestEmailOtp,
                "/api/auth/email-otp/request", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::VerifyEmailOtp,
                "/api/auth/email-otp/verify", drogon::Post,
                "RateLimitFilter");
  ADD_METHOD_TO(AuthController::ListSessions, "/api/auth/sessions",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(AuthController::RevokeSession, "/api/auth/sessions/revoke",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(AuthController::RevokeOtherSessions,
                "/api/auth/sessions/revoke-others", drogon::Post, "JwtFilter");
  METHOD_LIST_END

  void Register(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void Login(const drogon::HttpRequestPtr& req,
             std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void Refresh(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void Logout(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void LogoutAll(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void VerifyEmail(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RequestEmailVerification(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ResendEmailVerification(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RequestPasswordReset(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ResetPassword(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RequestEmailOtp(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void VerifyEmailOtp(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ListSessions(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RevokeSession(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RevokeOtherSessions(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
};

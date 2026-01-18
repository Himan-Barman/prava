#pragma once

#include <functional>

#include <drogon/HttpController.h>

class E2eController : public drogon::HttpController<E2eController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(E2eController::RegisterDevice,
                "/api/crypto/devices/register", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(E2eController::UploadPreKeys, "/api/crypto/prekeys",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(E2eController::RotateSignedPreKey,
                "/api/crypto/signed-prekey", drogon::Post, "JwtFilter");
  ADD_METHOD_TO(E2eController::ListDevices, "/api/crypto/devices/{1}",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(E2eController::GetBundle, "/api/crypto/bundle/{1}/{2}",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(E2eController::TrustDevice, "/api/crypto/trust",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(E2eController::ListTrust, "/api/crypto/trust/{1}",
                drogon::Get, "JwtFilter");
  METHOD_LIST_END

  void RegisterDevice(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void UploadPreKeys(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RotateSignedPreKey(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ListDevices(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& user_id) const;
  void GetBundle(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& user_id,
      const std::string& device_id) const;
  void TrustDevice(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ListTrust(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& user_id) const;
};

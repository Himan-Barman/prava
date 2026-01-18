#include "modules/e2e/e2e_controller.h"

#include <string>
#include <unordered_set>
#include <vector>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/auth/auth_validation.h"
#include "modules/e2e/e2e_service.h"

namespace {

bool GetUserId(const drogon::HttpRequestPtr& req, std::string& user_id) {
  const auto attrs = req->getAttributes();
  if (!attrs || !attrs->find("user_id")) {
    return false;
  }
  user_id = attrs->get<std::string>("user_id");
  return true;
}

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
                       std::optional<std::string>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isString()) {
    return false;
  }
  out = body[key].asString();
  return true;
}

bool GetOptionalInt(const Json::Value& body,
                    const std::string& key,
                    std::optional<int>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  if (!body[key].isInt()) {
    return false;
  }
  out = body[key].asInt();
  return true;
}

bool ParsePreKey(const Json::Value& value, PreKeyInput& out) {
  if (!value.isObject()) {
    return false;
  }
  if (!value.isMember("keyId") || !value["keyId"].isInt()) {
    return false;
  }
  if (!value.isMember("publicKey") || !value["publicKey"].isString()) {
    return false;
  }
  const int key_id = value["keyId"].asInt();
  const std::string public_key = value["publicKey"].asString();
  if (key_id < 0 || public_key.empty() || public_key.size() > 2048) {
    return false;
  }
  out.key_id = key_id;
  out.public_key = public_key;
  return true;
}

bool ParseSignedPreKey(const Json::Value& value, SignedPreKeyInput& out) {
  if (!value.isObject()) {
    return false;
  }
  if (!value.isMember("keyId") || !value["keyId"].isInt()) {
    return false;
  }
  if (!value.isMember("publicKey") || !value["publicKey"].isString()) {
    return false;
  }
  if (!value.isMember("signature") || !value["signature"].isString()) {
    return false;
  }
  const int key_id = value["keyId"].asInt();
  const std::string public_key = value["publicKey"].asString();
  const std::string signature = value["signature"].asString();
  if (key_id < 0 || public_key.empty() || public_key.size() > 2048 ||
      signature.empty() || signature.size() > 4096) {
    return false;
  }
  out.key_id = key_id;
  out.public_key = public_key;
  out.signature = signature;
  if (value.isMember("expiresAt")) {
    if (!value["expiresAt"].isString()) {
      return false;
    }
    out.expires_at = value["expiresAt"].asString();
  }
  return true;
}

E2eService BuildE2eService() {
  return E2eService(AppState::Instance().GetDb());
}

void RespondWithE2e(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const E2eError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void E2eController::RegisterDevice(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {
      "deviceId",
      "platform",
      "deviceName",
      "identityKey",
      "registrationId",
      "signedPreKey",
      "oneTimePreKeys"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string device_id;
  std::string platform;
  std::string identity_key;
  if (!GetRequiredString(body, "deviceId", device_id) ||
      !GetRequiredString(body, "platform", platform) ||
      !GetRequiredString(body, "identityKey", identity_key)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  platform = ToLower(Trim(platform));
  if (!IsValidDeviceId(device_id) || !IsValidPlatform(platform) ||
      identity_key.size() < 16 || identity_key.size() > 4096) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<std::string> device_name;
  if (!GetOptionalString(body, "deviceName", device_name)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (device_name && device_name->size() > 64) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::optional<int> registration_id;
  if (!GetOptionalInt(body, "registrationId", registration_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (registration_id && *registration_id < 0) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (!body.isMember("signedPreKey") || !body["signedPreKey"].isObject()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  SignedPreKeyInput signed_pre_key;
  if (!ParseSignedPreKey(body["signedPreKey"], signed_pre_key)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::vector<PreKeyInput> one_time_pre_keys;
  if (body.isMember("oneTimePreKeys")) {
    if (!body["oneTimePreKeys"].isArray()) {
      callback(
          http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
      return;
    }
    if (body["oneTimePreKeys"].size() > 200) {
      callback(
          http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
      return;
    }
    for (const auto& entry : body["oneTimePreKeys"]) {
      PreKeyInput key;
      if (!ParsePreKey(entry, key)) {
        callback(
            http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
        return;
      }
      one_time_pre_keys.push_back(std::move(key));
    }
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.RegisterDeviceKeys(user_id, device_id, platform, device_name,
                                      identity_key, registration_id,
                                      signed_pre_key, one_time_pre_keys);
      },
      std::move(callback));
}

void E2eController::UploadPreKeys(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"deviceId",
                                                          "preKeys"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string device_id;
  if (!GetRequiredString(body, "deviceId", device_id) ||
      !IsValidDeviceId(device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (!body.isMember("preKeys") || !body["preKeys"].isArray()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (body["preKeys"].size() > 500) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::vector<PreKeyInput> pre_keys;
  for (const auto& entry : body["preKeys"]) {
    PreKeyInput key;
    if (!ParsePreKey(entry, key)) {
      callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
      return;
    }
    pre_keys.push_back(std::move(key));
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.UploadPreKeys(user_id, device_id, pre_keys);
      },
      std::move(callback));
}

void E2eController::RotateSignedPreKey(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"deviceId",
                                                          "signedPreKey"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string device_id;
  if (!GetRequiredString(body, "deviceId", device_id) ||
      !IsValidDeviceId(device_id)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (!body.isMember("signedPreKey") || !body["signedPreKey"].isObject()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  SignedPreKeyInput signed_pre_key;
  if (!ParseSignedPreKey(body["signedPreKey"], signed_pre_key)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.RotateSignedPreKey(user_id, device_id, signed_pre_key);
      },
      std::move(callback));
}

void E2eController::ListDevices(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& user_id) const {
  if (user_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string requester_id;
  if (!GetUserId(req, requester_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.ListDevicesForUser(requester_id, user_id);
      },
      std::move(callback));
}

void E2eController::GetBundle(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& user_id,
    const std::string& device_id) const {
  if (user_id.empty() || device_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string requester_id;
  if (!GetUserId(req, requester_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.GetPreKeyBundle(requester_id, user_id, device_id);
      },
      std::move(callback));
}

void E2eController::TrustDevice(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"targetUserId",
                                                          "targetDeviceId",
                                                          "status"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string target_user_id;
  std::string target_device_id;
  std::string status;
  if (!GetRequiredString(body, "targetUserId", target_user_id) ||
      !GetRequiredString(body, "targetDeviceId", target_device_id) ||
      !GetRequiredString(body, "status", status)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  status = ToLower(Trim(status));
  if (target_user_id.empty() || !IsValidDeviceId(target_device_id) ||
      (status != "trusted" && status != "unverified" && status != "blocked")) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string requester_id;
  if (!GetUserId(req, requester_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.SetTrust(requester_id, target_user_id, target_device_id,
                            status);
      },
      std::move(callback));
}

void E2eController::ListTrust(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& user_id) const {
  if (user_id.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid request"));
    return;
  }

  std::string requester_id;
  if (!GetUserId(req, requester_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithE2e(
      [&]() {
        auto e2e = BuildE2eService();
        return e2e.ListTrustForUser(requester_id, user_id);
      },
      std::move(callback));
}

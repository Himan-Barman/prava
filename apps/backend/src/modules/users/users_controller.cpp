#include "modules/users/users_controller.h"

#include <cstdlib>
#include <optional>
#include <string>
#include <unordered_set>

#include "app_state.h"
#include "http/json.h"
#include "http/response.h"
#include "modules/users/users_service.h"

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
                       std::optional<std::string>& out) {
  if (!body.isMember(key)) {
    return true;
  }
  std::string value;
  if (!http::GetStringField(body, key, value)) {
    return false;
  }
  out = value;
  return true;
}

bool GetRequiredBool(const Json::Value& body,
                     const std::string& key,
                     bool& out) {
  if (!body.isMember(key)) {
    return false;
  }
  const auto& value = body[key];
  if (!value.isBool()) {
    return false;
  }
  out = value.asBool();
  return true;
}

bool SetOptionalBool(const Json::Value& body,
                     const std::string& key,
                     Json::Value& updates) {
  if (!body.isMember(key)) {
    return true;
  }
  const auto& value = body[key];
  if (!value.isBool()) {
    return false;
  }
  updates[key] = value.asBool();
  return true;
}

bool SetOptionalInt(const Json::Value& body,
                    const std::string& key,
                    Json::Value& updates) {
  if (!body.isMember(key)) {
    return true;
  }
  const auto& value = body[key];
  if (!value.isInt()) {
    return false;
  }
  updates[key] = value.asInt();
  return true;
}

bool SetOptionalNumber(const Json::Value& body,
                       const std::string& key,
                       Json::Value& updates) {
  if (!body.isMember(key)) {
    return true;
  }
  const auto& value = body[key];
  if (!value.isNumeric()) {
    return false;
  }
  updates[key] = value.asDouble();
  return true;
}

bool SetOptionalString(const Json::Value& body,
                       const std::string& key,
                       Json::Value& updates) {
  if (!body.isMember(key)) {
    return true;
  }
  const auto& value = body[key];
  if (!value.isString()) {
    return false;
  }
  updates[key] = value.asString();
  return true;
}

bool GetUserId(const drogon::HttpRequestPtr& req, std::string& user_id) {
  const auto attrs = req->getAttributes();
  if (!attrs || !attrs->find("user_id")) {
    return false;
  }
  user_id = attrs->get<std::string>("user_id");
  return true;
}

std::optional<int> ParseOptionalInt(const drogon::HttpRequestPtr& req,
                                    const std::string& key) {
  const std::string value = req->getParameter(key);
  if (value.empty()) {
    return std::nullopt;
  }

  char* end = nullptr;
  const long parsed = std::strtol(value.c_str(), &end, 10);
  if (end == value.c_str() || *end != '\0') {
    return std::nullopt;
  }

  return static_cast<int>(parsed);
}

UsersService BuildUsersService() {
  return UsersService(AppState::Instance().GetDb());
}

void RespondWithUsers(
    std::function<Json::Value()> handler,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) {
  try {
    const Json::Value payload = handler();
    callback(http::JsonResponse(payload, drogon::k200OK));
  } catch (const UsersError& err) {
    callback(http::ErrorResponse(err.status, err.what()));
  } catch (const std::exception&) {
    callback(http::ErrorResponse(drogon::k500InternalServerError,
                                 "Internal server error"));
  }
}

}  // namespace

void UsersController::Me(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  Json::Value payload;
  payload["userId"] = user_id;
  callback(http::JsonResponse(payload, drogon::k200OK));
}

void UsersController::Account(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id]() {
        auto users = BuildUsersService();
        return users.GetAccountInfo(user_id);
      },
      std::move(callback));
}

void UsersController::UpdateEmail(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"email"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string email;
  if (!GetRequiredString(body, "email", email) || email.size() > 255) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id, &email]() {
        auto users = BuildUsersService();
        return users.UpdateEmail(user_id, email);
      },
      std::move(callback));
}

void UsersController::UpdateHandle(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"username",
                                                          "displayName",
                                                          "bio",
                                                          "location",
                                                          "website"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  UpdateHandleInput input;
  if (!GetOptionalString(body, "username", input.username) ||
      !GetOptionalString(body, "displayName", input.display_name) ||
      !GetOptionalString(body, "bio", input.bio) ||
      !GetOptionalString(body, "location", input.location) ||
      !GetOptionalString(body, "website", input.website)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  if (input.username &&
      (input.username->size() < 3 || input.username->size() > 32)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (input.display_name && input.display_name->size() > 64) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (input.bio && input.bio->size() > 160) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (input.location && input.location->size() > 120) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }
  if (input.website && input.website->size() > 255) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id, &input]() {
        auto users = BuildUsersService();
        return users.UpdateHandle(user_id, input);
      },
      std::move(callback));
}

void UsersController::GetSettings(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id]() {
        auto users = BuildUsersService();
        return users.GetSettings(user_id);
      },
      std::move(callback));
}

void UsersController::UpdateSettings(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {
      "privateAccount",
      "activityStatus",
      "readReceipts",
      "messagePreview",
      "sensitiveContent",
      "locationSharing",
      "twoFactor",
      "loginAlerts",
      "appLock",
      "biometrics",
      "pushNotifications",
      "emailNotifications",
      "inAppSounds",
      "inAppHaptics",
      "dataSaver",
      "autoDownload",
      "autoPlayVideos",
      "reduceMotion",
      "themeIndex",
      "textScale",
      "languageLabel"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  Json::Value updates(Json::objectValue);
  if (!SetOptionalBool(body, "privateAccount", updates) ||
      !SetOptionalBool(body, "activityStatus", updates) ||
      !SetOptionalBool(body, "readReceipts", updates) ||
      !SetOptionalBool(body, "messagePreview", updates) ||
      !SetOptionalBool(body, "sensitiveContent", updates) ||
      !SetOptionalBool(body, "locationSharing", updates) ||
      !SetOptionalBool(body, "twoFactor", updates) ||
      !SetOptionalBool(body, "loginAlerts", updates) ||
      !SetOptionalBool(body, "appLock", updates) ||
      !SetOptionalBool(body, "biometrics", updates) ||
      !SetOptionalBool(body, "pushNotifications", updates) ||
      !SetOptionalBool(body, "emailNotifications", updates) ||
      !SetOptionalBool(body, "inAppSounds", updates) ||
      !SetOptionalBool(body, "inAppHaptics", updates) ||
      !SetOptionalBool(body, "dataSaver", updates) ||
      !SetOptionalBool(body, "autoDownload", updates) ||
      !SetOptionalBool(body, "autoPlayVideos", updates) ||
      !SetOptionalBool(body, "reduceMotion", updates) ||
      !SetOptionalInt(body, "themeIndex", updates) ||
      !SetOptionalNumber(body, "textScale", updates) ||
      !SetOptionalString(body, "languageLabel", updates)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id, &updates]() {
        auto users = BuildUsersService();
        return users.UpdateSettings(user_id, updates);
      },
      std::move(callback));
}

void UsersController::UpdateDetails(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"firstName",
                                                          "lastName",
                                                          "phoneCountryCode",
                                                          "phoneNumber"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  UpdateDetailsInput input;
  if (!GetRequiredString(body, "firstName", input.first_name) ||
      !GetRequiredString(body, "lastName", input.last_name) ||
      !GetRequiredString(body, "phoneCountryCode",
                         input.phone_country_code) ||
      !GetRequiredString(body, "phoneNumber", input.phone_number)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id, &input]() {
        auto users = BuildUsersService();
        return users.UpdateDetails(user_id, input);
      },
      std::move(callback));
}

void UsersController::Profile(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  UserLimitInput input{user_id, ParseOptionalInt(req, "limit")};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.GetProfileSummary(input);
      },
      std::move(callback));
}

void UsersController::Blocked(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  UserLimitInput input{user_id, ParseOptionalInt(req, "limit")};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.ListBlockedUsers(input);
      },
      std::move(callback));
}

void UsersController::BlockUser(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  BlockInput input{user_id, target_user_id};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.BlockUser(input);
      },
      std::move(callback));
}

void UsersController::UnblockUser(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  BlockInput input{user_id, target_user_id};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.UnblockUser(input);
      },
      std::move(callback));
}

void UsersController::MutedWords(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  UserLimitInput input{user_id, ParseOptionalInt(req, "limit")};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.ListMutedWords(input);
      },
      std::move(callback));
}

void UsersController::AddMutedWord(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  static const std::unordered_set<std::string> allowed = {"phrase"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  std::string phrase;
  if (!GetRequiredString(body, "phrase", phrase) || phrase.empty() ||
      phrase.size() > 120) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  AddMutedWordInput input{user_id, phrase};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.AddMutedWord(input);
      },
      std::move(callback));
}

void UsersController::RemoveMutedWord(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& word_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RemoveMutedWordInput input{user_id, word_id};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.RemoveMutedWord(input);
      },
      std::move(callback));
}

void UsersController::ExportData(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id]() {
        auto users = BuildUsersService();
        return users.CreateDataExport(user_id);
      },
      std::move(callback));
}

void UsersController::LatestExport(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id]() {
        auto users = BuildUsersService();
        return users.GetLatestDataExport(user_id);
      },
      std::move(callback));
}

void UsersController::Connections(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  UserLimitInput input{user_id, ParseOptionalInt(req, "limit")};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.GetConnections(input);
      },
      std::move(callback));
}

void UsersController::DeleteAccount(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RespondWithUsers(
      [&user_id]() {
        auto users = BuildUsersService();
        return users.DeleteAccount(user_id);
      },
      std::move(callback));
}

void UsersController::PublicProfile(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  PublicProfileInput input{target_user_id, user_id,
                           ParseOptionalInt(req, "limit")};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.GetPublicProfileSummary(input);
      },
      std::move(callback));
}

void UsersController::Search(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  const std::string query = req->getParameter("query");
  if (query.empty()) {
    callback(
        http::ErrorResponse(drogon::k400BadRequest, "query is required"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  SearchUsersInput input{user_id, query, ParseOptionalInt(req, "limit")};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.SearchUsers(input);
      },
      std::move(callback));
}

void UsersController::UsernameAvailable(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  const std::string username = req->getParameter("username");
  if (username.empty()) {
    callback(http::ErrorResponse(drogon::k400BadRequest,
                                 "username is required"));
    return;
  }

  RespondWithUsers(
      [&username]() {
        auto users = BuildUsersService();
        Json::Value payload;
        payload["available"] = users.IsUsernameAvailable(username);
        return payload;
      },
      std::move(callback));
}

void UsersController::ToggleFollow(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  FollowInput input{user_id, target_user_id};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.ToggleFollow(input);
      },
      std::move(callback));
}

void UsersController::SetFollow(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  static const std::unordered_set<std::string> allowed = {"follow"};

  Json::Value body;
  drogon::HttpResponsePtr error_resp;
  if (!ParseJsonPayload(req, allowed, body, error_resp)) {
    callback(error_resp);
    return;
  }

  bool follow = false;
  if (!GetRequiredBool(body, "follow", follow)) {
    callback(http::ErrorResponse(drogon::k400BadRequest, "Invalid payload"));
    return;
  }

  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  SetFollowInput input{user_id, target_user_id, follow};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.SetFollow(input);
      },
      std::move(callback));
}

void UsersController::RemoveFollower(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RemoveFollowerInput input{user_id, target_user_id};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.RemoveFollower(input);
      },
      std::move(callback));
}

void UsersController::RemoveConnection(
    const drogon::HttpRequestPtr& req,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback,
    const std::string& target_user_id) const {
  std::string user_id;
  if (!GetUserId(req, user_id)) {
    callback(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  RemoveConnectionInput input{user_id, target_user_id};

  RespondWithUsers(
      [&input]() {
        auto users = BuildUsersService();
        return users.RemoveConnection(input);
      },
      std::move(callback));
}

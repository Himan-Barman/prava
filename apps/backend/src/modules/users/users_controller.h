#pragma once

#include <functional>

#include <drogon/HttpController.h>

class UsersController : public drogon::HttpController<UsersController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(UsersController::Me, "/api/users/me", drogon::Get,
                "JwtFilter");
  ADD_METHOD_TO(UsersController::Account, "/api/users/me/account",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::UpdateEmail, "/api/users/me/email",
                drogon::Put, "JwtFilter");
  ADD_METHOD_TO(UsersController::UpdateHandle, "/api/users/me/handle",
                drogon::Put, "JwtFilter");
  ADD_METHOD_TO(UsersController::GetSettings, "/api/users/me/settings",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::UpdateSettings, "/api/users/me/settings",
                drogon::Put, "JwtFilter");
  ADD_METHOD_TO(UsersController::UpdateDetails, "/api/users/me/details",
                drogon::Put, "JwtFilter");
  ADD_METHOD_TO(UsersController::Profile, "/api/users/me/profile",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::Blocked, "/api/users/me/blocks",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::BlockUser, "/api/users/{1}/block",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(UsersController::UnblockUser, "/api/users/{1}/block",
                drogon::Delete, "JwtFilter");
  ADD_METHOD_TO(UsersController::MutedWords, "/api/users/me/muted-words",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::AddMutedWord, "/api/users/me/muted-words",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(UsersController::RemoveMutedWord,
                "/api/users/me/muted-words/{1}", drogon::Delete,
                "JwtFilter");
  ADD_METHOD_TO(UsersController::ExportData, "/api/users/me/data-export",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(UsersController::LatestExport, "/api/users/me/data-export",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::Connections, "/api/users/me/connections",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::DeleteAccount, "/api/users/me",
                drogon::Delete, "JwtFilter");
  ADD_METHOD_TO(UsersController::PublicProfile, "/api/users/{1}/profile",
                drogon::Get, "JwtFilter");
  ADD_METHOD_TO(UsersController::Search, "/api/users/search", drogon::Get,
                "JwtFilter");
  ADD_METHOD_TO(UsersController::UsernameAvailable,
                "/api/users/username-available", drogon::Get,
                "RateLimitFilter");
  ADD_METHOD_TO(UsersController::ToggleFollow, "/api/users/{1}/follow",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(UsersController::SetFollow, "/api/users/{1}/follow",
                drogon::Put, "JwtFilter");
  ADD_METHOD_TO(UsersController::RemoveFollower, "/api/users/{1}/follower",
                drogon::Delete, "JwtFilter");
  ADD_METHOD_TO(UsersController::RemoveConnection,
                "/api/users/{1}/connection", drogon::Delete, "JwtFilter");
  METHOD_LIST_END

  void Me(const drogon::HttpRequestPtr& req,
          std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void Account(const drogon::HttpRequestPtr& req,
               std::function<void(const drogon::HttpResponsePtr&)>&& callback)
      const;
  void UpdateEmail(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void UpdateHandle(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void GetSettings(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void UpdateSettings(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void UpdateDetails(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void Profile(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void Blocked(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void BlockUser(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
  void UnblockUser(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
  void MutedWords(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void AddMutedWord(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void RemoveMutedWord(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& word_id) const;
  void ExportData(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void LatestExport(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void Connections(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void DeleteAccount(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void PublicProfile(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
  void Search(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void UsernameAvailable(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void ToggleFollow(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
  void SetFollow(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
  void RemoveFollower(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
  void RemoveConnection(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& target_user_id) const;
};

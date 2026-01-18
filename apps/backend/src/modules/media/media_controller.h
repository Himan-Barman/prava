#pragma once

#include <functional>

#include <drogon/HttpController.h>

class MediaController : public drogon::HttpController<MediaController> {
 public:
  METHOD_LIST_BEGIN
  ADD_METHOD_TO(MediaController::InitUpload, "/api/media/init", drogon::Post,
                "JwtFilter");
  ADD_METHOD_TO(MediaController::CompleteUpload, "/api/media/{1}/complete",
                drogon::Post, "JwtFilter");
  ADD_METHOD_TO(MediaController::GetMedia, "/api/media/{1}", drogon::Get,
                "JwtFilter");
  METHOD_LIST_END

  void InitUpload(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback) const;
  void CompleteUpload(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& asset_id) const;
  void GetMedia(
      const drogon::HttpRequestPtr& req,
      std::function<void(const drogon::HttpResponsePtr&)>&& callback,
      const std::string& asset_id) const;
};

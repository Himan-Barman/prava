#include "modules/health/health_controller.h"

#include <chrono>

#include "http/response.h"

void HealthController::GetHealth(
    const drogon::HttpRequestPtr&,
    std::function<void(const drogon::HttpResponsePtr&)>&& callback) const {
  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::system_clock::now().time_since_epoch())
                       .count();

  Json::Value payload;
  payload["status"] = "ok";
  payload["ts"] = static_cast<Json::Int64>(now);

  callback(http::JsonResponse(payload, drogon::k200OK));
}

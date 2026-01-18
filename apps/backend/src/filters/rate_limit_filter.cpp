#include "filters/rate_limit_filter.h"

#include <chrono>
#include <string>

#include "app_state.h"
#include "http/response.h"

namespace {

std::string ExtractIp(const drogon::HttpRequestPtr& req) {
  const std::string forwarded = req->getHeader("x-forwarded-for");
  if (!forwarded.empty()) {
    auto pos = forwarded.find(',');
    if (pos == std::string::npos) {
      return forwarded;
    }
    return forwarded.substr(0, pos);
  }

  const std::string realIp = req->getHeader("x-real-ip");
  if (!realIp.empty()) {
    return realIp;
  }

  return req->peerAddr().toIp();
}

}  // namespace

void RateLimitFilter::doFilter(const drogon::HttpRequestPtr& req,
                               drogon::FilterCallback&& fcb,
                               drogon::FilterChainCallback&& fccb) {
  constexpr int kWindowSec = 60;
  constexpr int kMaxRequests = 30;

  const auto& redis = AppState::Instance().GetRedis();
  if (!redis) {
    fccb();
    return;
  }

  const std::string ip = ExtractIp(req);
  const std::string route =
      req->getMatchedPathPattern().empty() ? req->getPath()
                                           : std::string(req->getMatchedPathPattern());
  const std::string key = "ratelimit:" + route + ":" + (ip.empty() ? "unknown" : ip);

  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                       std::chrono::system_clock::now().time_since_epoch())
                       .count();
  const auto cutoff = now - static_cast<long long>(kWindowSec) * 1000;

  try {
    redis->execCommandSync(
        "ZADD %s %lld %lld",
        key.c_str(),
        static_cast<long long>(now),
        static_cast<long long>(now));

    redis->execCommandSync(
        "ZREMRANGEBYSCORE %s 0 %lld",
        key.c_str(),
        static_cast<long long>(cutoff));

    const auto count_result = redis->execCommandSync(
        "ZCARD %s",
        key.c_str());
    const auto count = static_cast<long long>(count_result.asInteger());

    redis->execCommandSync(
        "EXPIRE %s %d",
        key.c_str(),
        kWindowSec);

    if (count > kMaxRequests) {
      fcb(http::ErrorResponse(drogon::k429TooManyRequests, "Too many requests, slow down"));
      return;
    }
  } catch (const std::exception&) {
    // Fail open on Redis errors.
  }

  fccb();
}

#include "filters/jwt_filter.h"

#include <algorithm>
#include <cctype>
#include <string>

#include <jwt-cpp/jwt.h>

#include "app_state.h"
#include "http/response.h"

namespace {

std::string Trim(const std::string& value) {
  auto start = value.begin();
  while (start != value.end() && std::isspace(static_cast<unsigned char>(*start))) {
    ++start;
  }
  auto end = value.end();
  while (end != start && std::isspace(static_cast<unsigned char>(*(end - 1)))) {
    --end;
  }
  return std::string(start, end);
}

}  // namespace

void JwtFilter::doFilter(const drogon::HttpRequestPtr& req,
                         drogon::FilterCallback&& fcb,
                         drogon::FilterChainCallback&& fccb) {
  const std::string header = req->getHeader("authorization");
  if (header.empty()) {
    fcb(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  std::string lowered = header;
  std::transform(lowered.begin(), lowered.end(), lowered.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

  if (lowered.rfind("bearer ", 0) != 0) {
    fcb(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  const std::string token = Trim(header.substr(7));
  if (token.empty()) {
    fcb(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
    return;
  }

  try {
    const auto decoded = jwt::decode(token);
    const auto& cfg = AppState::Instance().GetConfig();
    auto verifier = jwt::verify()
                        .allow_algorithm(jwt::algorithm::rs256(cfg.jwt_public, "", "", ""))
                        .leeway(0);
    verifier.verify(decoded);

    if (!decoded.has_subject()) {
      fcb(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
      return;
    }

    req->getAttributes()->insert("user_id", decoded.get_subject());
    fccb();
  } catch (const std::exception&) {
    fcb(http::ErrorResponse(drogon::k401Unauthorized, "unauthorized"));
  }
}

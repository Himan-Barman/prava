#include <drogon/drogon.h>
#include <trantor/utils/Logger.h>

#include <iostream>
#include <stdexcept>
#include <string>

#include "app_state.h"
#include "config/config.h"
#include "http/response.h"
#include "realtime/ws_hub.h"

namespace {

bool IsOriginAllowed(const Config& cfg, const std::string& origin) {
  if (cfg.cors_allow_all) {
    return true;
  }
  if (origin.empty()) {
    return false;
  }
  for (const auto& allowed : cfg.cors_origins) {
    if (allowed == origin) {
      return true;
    }
  }
  return false;
}

void ApplyCorsHeaders(const Config& cfg,
                      const drogon::HttpRequestPtr& req,
                      const drogon::HttpResponsePtr& resp) {
  if (!cfg.cors_allow_all && cfg.cors_origins.empty()) {
    return;
  }

  const std::string origin = req->getHeader("origin");
  if (cfg.cors_allow_all) {
    if (!origin.empty()) {
      resp->addHeader("Access-Control-Allow-Origin", origin);
      resp->addHeader("Vary", "Origin");
    } else {
      resp->addHeader("Access-Control-Allow-Origin", "*");
    }
  } else {
    if (!IsOriginAllowed(cfg, origin)) {
      return;
    }
    resp->addHeader("Access-Control-Allow-Origin", origin);
    resp->addHeader("Vary", "Origin");
  }

  resp->addHeader("Access-Control-Allow-Credentials", "true");
  resp->addHeader(
      "Access-Control-Allow-Methods",
      "GET,POST,PUT,PATCH,DELETE,OPTIONS");
  resp->addHeader(
      "Access-Control-Allow-Headers",
      "Accept,Authorization,Content-Type,X-Request-ID,X-Device-Id");
}

void ApplySecurityHeaders(const drogon::HttpResponsePtr& resp) {
  resp->addHeader("X-Content-Type-Options", "nosniff");
  resp->addHeader("X-Frame-Options", "DENY");
  resp->addHeader("Referrer-Policy", "no-referrer");
  resp->addHeader("X-XSS-Protection", "0");
}

drogon::nosql::RedisClientPtr BuildRedisClient(const std::string& redis_url) {
  if (redis_url.empty()) {
    return nullptr;
  }

  std::string url = redis_url;
  bool tls = false;
  const std::string redis_prefix = "redis://";
  const std::string rediss_prefix = "rediss://";
  if (url.rfind(redis_prefix, 0) == 0) {
    url = url.substr(redis_prefix.size());
  } else if (url.rfind(rediss_prefix, 0) == 0) {
    url = url.substr(rediss_prefix.size());
    tls = true;
  } else {
    throw std::runtime_error("unsupported redis url scheme");
  }

  std::string hostinfo = url;
  std::string path;
  const auto slash_pos = url.find('/');
  if (slash_pos != std::string::npos) {
    hostinfo = url.substr(0, slash_pos);
    path = url.substr(slash_pos + 1);
  }

  std::string username;
  std::string password;
  std::string hostport = hostinfo;
  const auto at_pos = hostinfo.find('@');
  if (at_pos != std::string::npos) {
    const std::string auth = hostinfo.substr(0, at_pos);
    hostport = hostinfo.substr(at_pos + 1);
    const auto colon_pos = auth.find(':');
    if (colon_pos != std::string::npos) {
      username = auth.substr(0, colon_pos);
      password = auth.substr(colon_pos + 1);
    } else {
      password = auth;
    }
  }

  std::string host = hostport;
  uint16_t port = 6379;
  if (!hostport.empty() && hostport.front() == '[') {
    const auto close_pos = hostport.find(']');
    if (close_pos == std::string::npos) {
      throw std::runtime_error("invalid redis host");
    }
    host = hostport.substr(1, close_pos - 1);
    if (close_pos + 1 < hostport.size() && hostport[close_pos + 1] == ':') {
      port = static_cast<uint16_t>(
          std::stoi(hostport.substr(close_pos + 2)));
    }
  } else {
    const auto colon_pos = hostport.rfind(':');
    if (colon_pos != std::string::npos) {
      host = hostport.substr(0, colon_pos);
      port = static_cast<uint16_t>(
          std::stoi(hostport.substr(colon_pos + 1)));
    }
  }

  unsigned int db = 0;
  if (!path.empty()) {
    db = static_cast<unsigned int>(std::stoi(path));
  }

  if (host.empty()) {
    throw std::runtime_error("redis host is required");
  }

  if (tls) {
    std::cerr << "rediss:// detected but TLS for redis is not wired yet\n";
  }

  trantor::InetAddress address(host, port);
  return drogon::nosql::RedisClient::newRedisClient(address, 10, password, db,
                                                    username);
}

}  // namespace

int main() {
  Config cfg;
  try {
    cfg = Config::Load();
  } catch (const std::exception& ex) {
    std::cerr << "Config error: " << ex.what() << "\n";
    return 1;
  }

  trantor::Logger::setLogLevel(cfg.env == "production"
                                   ? trantor::Logger::kWarn
                                   : trantor::Logger::kDebug);

  auto db = drogon::orm::DbClient::newPgClient(cfg.db_url, 20);
  auto redis = BuildRedisClient(cfg.redis_url);
  AppState::Instance().Init(cfg, db, redis);
  WsHub::Instance().Init(redis);

  std::string ws_mode = cfg.ws_mode;
  if (ws_mode.empty()) {
    const bool is_render =
        std::getenv("RENDER") != nullptr ||
        std::getenv("RENDER_EXTERNAL_URL") != nullptr;
    ws_mode = is_render ? "shared" : "standalone";
  }

  auto& app = drogon::app();
  app.addListener("0.0.0.0", cfg.port);
  if (ws_mode == "standalone" && cfg.ws_port != cfg.port) {
    app.addListener("0.0.0.0", cfg.ws_port);
  }

  app.setCustomErrorHandler([](drogon::HttpStatusCode code,
                               const drogon::HttpRequestPtr&) {
        return http::ErrorResponse(
            code, std::string(drogon::statusCodeToString(code)));
      })
      .registerPreRoutingAdvice([cfg](const drogon::HttpRequestPtr& req,
                                      drogon::AdviceCallback&& acb,
                                      drogon::AdviceChainCallback&& accb) {
        const std::string request_id =
            !req->getHeader("x-request-id").empty()
                ? req->getHeader("x-request-id")
                : drogon::utils::getUuid();
        req->getAttributes()->insert("request_id", request_id);

        if (req->method() == drogon::Options) {
          if (!cfg.cors_allow_all && cfg.cors_origins.empty()) {
            accb();
            return;
          }
          if (!IsOriginAllowed(cfg, req->getHeader("origin")) &&
              !cfg.cors_allow_all) {
            acb(http::ErrorResponse(drogon::k403Forbidden,
                                    "CORS origin not allowed"));
            return;
          }
          auto resp = drogon::HttpResponse::newHttpResponse();
          ApplyCorsHeaders(cfg, req, resp);
          resp->setStatusCode(drogon::k200OK);
          acb(resp);
          return;
        }

        accb();
      })
      .registerPostHandlingAdvice([cfg](const drogon::HttpRequestPtr& req,
                                        const drogon::HttpResponsePtr& resp) {
        ApplyCorsHeaders(cfg, req, resp);
        ApplySecurityHeaders(resp);

        const auto attrs = req->getAttributes();
        if (attrs && attrs->find("request_id")) {
          resp->addHeader("X-Request-ID",
                          attrs->get<std::string>("request_id"));
        }
      });

  drogon::app().run();
  return 0;
}

#include "realtime/ws_controller.h"

#include <chrono>
#include <memory>
#include <sstream>
#include <string>

#include <drogon/drogon.h>
#include <json/json.h>
#include <jwt-cpp/jwt.h>

#include "app_state.h"
#include "modules/auth/auth_validation.h"
#include "modules/conversations/conversations_service.h"
#include "modules/messages/messages_service.h"
#include "realtime/presence_manager.h"
#include "realtime/sync_service.h"
#include "realtime/ws_hub.h"
#include "realtime/ws_router.h"

namespace {

constexpr int kRateLimitWindowMs = 10000;
constexpr int kRateLimitMax = 120;
constexpr size_t kMaxWsPayloadBytes = 256 * 1024;
constexpr double kPresenceRefreshSeconds = 30.0;

int64_t NowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

struct WsSession {
  std::string user_id;
  std::string device_id;
  std::chrono::steady_clock::time_point window_start;
  int window_count = 0;
  bool has_window = false;
  trantor::TimerId presence_timer = trantor::InvalidTimerId;
};

std::string ExtractToken(const drogon::HttpRequestPtr& req) {
  const std::string header = req->getHeader("authorization");
  if (!header.empty()) {
    const std::string lowered = ToLower(header);
    if (lowered.rfind("bearer ", 0) == 0) {
      const std::string token = Trim(header.substr(7));
      if (!token.empty()) {
        return token;
      }
    }
  }

  const std::string query = req->getParameter("token");
  return Trim(query);
}

std::string ExtractDeviceId(const drogon::HttpRequestPtr& req) {
  std::string device_id = req->getParameter("deviceId");
  if (!device_id.empty()) {
    return Trim(device_id);
  }
  device_id = req->getHeader("x-device-id");
  return Trim(device_id);
}

std::optional<std::string> VerifyToken(const std::string& token) {
  if (token.empty()) {
    return std::nullopt;
  }

  try {
    const auto decoded = jwt::decode(token);
    const auto& cfg = AppState::Instance().GetConfig();
    auto verifier = jwt::verify()
                        .allow_algorithm(
                            jwt::algorithm::rs256(cfg.jwt_public, "", "", ""))
                        .leeway(0);
    verifier.verify(decoded);

    if (!decoded.has_subject()) {
      return std::nullopt;
    }
    return decoded.get_subject();
  } catch (const std::exception&) {
    return std::nullopt;
  }
}

bool IsRateLimited(WsSession& session) {
  const auto now = std::chrono::steady_clock::now();
  if (!session.has_window ||
      std::chrono::duration_cast<std::chrono::milliseconds>(
          now - session.window_start)
              .count() >= kRateLimitWindowMs) {
    session.window_start = now;
    session.window_count = 1;
    session.has_window = true;
    return false;
  }

  session.window_count += 1;
  return session.window_count > kRateLimitMax;
}

void PublishPresence(const std::string& user_id, bool is_online) {
  ConversationsService conversations(AppState::Instance().GetDb());
  const auto conversation_ids =
      conversations.ListConversationIdsForUser(user_id);
  for (const auto& conversation_id : conversation_ids) {
    Json::Value event;
    event["type"] = "PRESENCE_UPDATE";
    Json::Value payload;
    payload["conversationId"] = conversation_id;
    payload["userId"] = user_id;
    payload["isOnline"] = is_online;
    event["payload"] = payload;
    event["ts"] = static_cast<Json::Int64>(NowMs());
    WsHub::Instance().PublishToConversation(conversation_id, event);
  }
}

}  // namespace

void WsController::handleNewConnection(
    const drogon::HttpRequestPtr& req,
    const drogon::WebSocketConnectionPtr& conn) {
  if (!conn) {
    return;
  }

  const std::string token = ExtractToken(req);
  const std::string device_id = ExtractDeviceId(req);
  if (token.empty() || device_id.empty() || !IsValidDeviceId(device_id)) {
    conn->shutdown(drogon::CloseCode::kViolation, "Unauthorized");
    return;
  }

  const auto user_id = VerifyToken(token);
  if (!user_id) {
    conn->shutdown(drogon::CloseCode::kViolation, "Unauthorized");
    return;
  }

  auto session = std::make_shared<WsSession>();
  session->user_id = *user_id;
  session->device_id = device_id;
  conn->setContext(session);

  PresenceManager presence;
  const bool was_online = presence.IsOnline(session->user_id);
  presence.Connect(session->user_id, session->device_id);
  if (!was_online) {
    PublishPresence(session->user_id, true);
  }

  WsHub::Instance().SubscribeUser(conn, session->user_id);

  ConversationsService conversations(AppState::Instance().GetDb());
  const auto conversation_ids =
      conversations.ListConversationIdsForUser(session->user_id);
  for (const auto& conversation_id : conversation_ids) {
    WsHub::Instance().SubscribeConversation(conn, conversation_id);
  }

  auto loop = drogon::app().getLoop();
  if (loop) {
    session->presence_timer = loop->runEvery(
        kPresenceRefreshSeconds, [user_id = session->user_id,
                                  device_id = session->device_id]() {
          PresenceManager pm;
          pm.Connect(user_id, device_id);
        });
  }
}

void WsController::handleNewMessage(
    const drogon::WebSocketConnectionPtr& conn,
    std::string&& message,
    const drogon::WebSocketMessageType& type) {
  if (!conn || type != drogon::WebSocketMessageType::Text) {
    return;
  }

  auto session = conn->getContext<WsSession>();
  if (!session) {
    conn->shutdown(drogon::CloseCode::kProtocolError);
    return;
  }

  if (message.size() > kMaxWsPayloadBytes) {
    conn->shutdown(drogon::CloseCode::kMessageTooBig);
    return;
  }

  if (IsRateLimited(*session)) {
    conn->shutdown(drogon::CloseCode::kViolation, "Rate limit exceeded");
    return;
  }

  Json::CharReaderBuilder builder;
  builder["collectComments"] = false;
  Json::Value root;
  std::string errors;
  std::istringstream stream(message);
  if (!Json::parseFromStream(builder, stream, &root, &errors) ||
      !root.isObject()) {
    conn->shutdown(drogon::CloseCode::kProtocolError);
    return;
  }

  PresenceManager presence;
  presence.Connect(session->user_id, session->device_id);

  SyncService sync(AppState::Instance().GetDb());
  ConversationsService conversations(AppState::Instance().GetDb());
  MessagesService messages(AppState::Instance().GetDb());

  WsContext ctx;
  ctx.conn = conn;
  ctx.user_id = session->user_id;
  ctx.device_id = session->device_id;
  ctx.sync_service = &sync;
  ctx.conversations_service = &conversations;
  ctx.messages_service = &messages;
  ctx.hub = &WsHub::Instance();

  WsRouter::HandleMessage(ctx, root);
}

void WsController::handleConnectionClosed(
    const drogon::WebSocketConnectionPtr& conn) {
  if (!conn) {
    return;
  }

  auto session = conn->getContext<WsSession>();
  if (session && session->presence_timer != trantor::InvalidTimerId) {
    auto loop = drogon::app().getLoop();
    if (loop) {
      loop->invalidateTimer(session->presence_timer);
    }
    session->presence_timer = trantor::InvalidTimerId;
  }

  WsHub::Instance().Remove(conn);

  if (session) {
    PresenceManager presence;
    presence.Disconnect(session->user_id, session->device_id);
    const bool still_online = presence.IsOnline(session->user_id);
    if (!still_online) {
      PublishPresence(session->user_id, false);
    }
  }
}

#pragma once

#include <string>

#include <drogon/WebSocketConnection.h>
#include <json/json.h>

#include "modules/conversations/conversations_service.h"
#include "modules/messages/messages_service.h"
#include "realtime/sync_service.h"
#include "realtime/ws_hub.h"

struct WsContext {
  drogon::WebSocketConnectionPtr conn;
  std::string user_id;
  std::string device_id;
  SyncService* sync_service = nullptr;
  ConversationsService* conversations_service = nullptr;
  MessagesService* messages_service = nullptr;
  WsHub* hub = nullptr;
};

class WsRouter {
 public:
  static void HandleMessage(const WsContext& ctx, const Json::Value& message);
};

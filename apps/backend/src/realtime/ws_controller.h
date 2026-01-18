#pragma once

#include <drogon/WebSocketController.h>

class WsController : public drogon::WebSocketController<WsController> {
 public:
  void handleNewMessage(
      const drogon::WebSocketConnectionPtr& conn,
      std::string&& message,
      const drogon::WebSocketMessageType& type) override;
  void handleNewConnection(
      const drogon::HttpRequestPtr& req,
      const drogon::WebSocketConnectionPtr& conn) override;
  void handleConnectionClosed(
      const drogon::WebSocketConnectionPtr& conn) override;

  WS_PATH_LIST_BEGIN
  WS_PATH_ADD("/", drogon::Get);
  WS_PATH_ADD("/ws", drogon::Get);
  WS_PATH_LIST_END
};

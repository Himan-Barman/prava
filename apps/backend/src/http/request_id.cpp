#include "http/request_id.h"

namespace http {

std::string GetRequestId(const drogon::HttpRequestPtr& req) {
  const auto attrs = req ? req->getAttributes() : nullptr;
  if (attrs && attrs->find("request_id")) {
    return attrs->get<std::string>("request_id");
  }
  return "";
}

}  // namespace http

#include "http/response.h"

#include <drogon/HttpResponse.h>
#include <drogon/utils/Utilities.h>

namespace http {

drogon::HttpResponsePtr JsonResponse(const Json::Value& payload,
                                     drogon::HttpStatusCode status) {
  auto resp = drogon::HttpResponse::newHttpJsonResponse(payload);
  resp->setStatusCode(status);
  return resp;
}

drogon::HttpResponsePtr ErrorResponse(drogon::HttpStatusCode status,
                                      const std::string& message) {
  Json::Value payload;
  payload["statusCode"] = static_cast<int>(status);
  payload["message"] = message;
  payload["error"] = std::string(drogon::statusCodeToString(status));
  return JsonResponse(payload, status);
}

}  // namespace http

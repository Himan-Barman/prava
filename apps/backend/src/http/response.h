#pragma once

#include <string>

#include <drogon/HttpResponse.h>
#include <drogon/HttpTypes.h>
#include <json/json.h>

namespace http {

drogon::HttpResponsePtr JsonResponse(const Json::Value& payload,
                                     drogon::HttpStatusCode status);

drogon::HttpResponsePtr ErrorResponse(drogon::HttpStatusCode status,
                                      const std::string& message);

}  // namespace http

#pragma once

#include <string>

#include <drogon/HttpRequest.h>

namespace http {

std::string GetRequestId(const drogon::HttpRequestPtr& req);

}  // namespace http

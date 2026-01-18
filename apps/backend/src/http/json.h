#pragma once

#include <string>
#include <unordered_set>

#include <drogon/HttpRequest.h>
#include <json/json.h>

namespace http {

bool ParseJsonObject(const drogon::HttpRequestPtr& req,
                     Json::Value& out,
                     std::string& error);

bool HasOnlyFields(const Json::Value& obj,
                   const std::unordered_set<std::string>& allowed);

bool GetStringField(const Json::Value& obj,
                    const std::string& key,
                    std::string& out);

}  // namespace http

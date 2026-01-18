#include "http/json.h"

namespace http {

bool ParseJsonObject(const drogon::HttpRequestPtr& req,
                     Json::Value& out,
                     std::string& error) {
  const auto& json = req->getJsonObject();
  if (!json) {
    error = "Invalid payload";
    return false;
  }
  if (!json->isObject()) {
    error = "Invalid payload";
    return false;
  }
  out = *json;
  return true;
}

bool HasOnlyFields(const Json::Value& obj,
                   const std::unordered_set<std::string>& allowed) {
  for (const auto& key : obj.getMemberNames()) {
    if (allowed.find(key) == allowed.end()) {
      return false;
    }
  }
  return true;
}

bool GetStringField(const Json::Value& obj,
                    const std::string& key,
                    std::string& out) {
  if (!obj.isMember(key)) {
    return false;
  }
  const auto& value = obj[key];
  if (!value.isString()) {
    return false;
  }
  out = value.asString();
  return true;
}

}  // namespace http

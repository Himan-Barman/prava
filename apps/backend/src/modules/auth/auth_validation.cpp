#include "modules/auth/auth_validation.h"

#include <algorithm>
#include <cctype>
#include <regex>

std::string Trim(const std::string& value) {
  auto start = value.begin();
  while (start != value.end() &&
         std::isspace(static_cast<unsigned char>(*start))) {
    ++start;
  }
  auto end = value.end();
  while (end != start &&
         std::isspace(static_cast<unsigned char>(*(end - 1)))) {
    --end;
  }
  return std::string(start, end);
}

std::string ToLower(const std::string& value) {
  std::string out = value;
  std::transform(out.begin(), out.end(), out.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return out;
}

bool IsValidEmail(const std::string& value) {
  static const std::regex pattern(R"(^[^@\s]+@[^@\s]+\.[^@\s]+$)",
                                  std::regex::icase);
  return std::regex_match(value, pattern);
}

bool IsValidPassword(const std::string& value) {
  return value.size() >= 8 && value.size() <= 128;
}

bool IsValidUsername(const std::string& value) {
  if (value.size() < 3 || value.size() > 32) {
    return false;
  }
  static const std::regex pattern(R"(^[a-z0-9_]+$)");
  return std::regex_match(value, pattern);
}

bool IsValidDeviceId(const std::string& value) {
  return value.size() >= 10 && value.size() <= 128;
}

bool IsValidPlatform(const std::string& value) {
  if (value.empty()) {
    return true;
  }
  return value == "android" || value == "ios" || value == "web" ||
         value == "desktop";
}

bool IsValidRefreshToken(const std::string& value) {
  return value.size() >= 20;
}

bool IsValidOtpCode(const std::string& value) {
  if (value.size() != 6) {
    return false;
  }
  return std::all_of(value.begin(), value.end(),
                     [](unsigned char c) { return std::isdigit(c) != 0; });
}

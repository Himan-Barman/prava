#pragma once

#include <string>

std::string Trim(const std::string& value);
std::string ToLower(const std::string& value);

bool IsValidEmail(const std::string& value);
bool IsValidPassword(const std::string& value);
bool IsValidUsername(const std::string& value);
bool IsValidDeviceId(const std::string& value);
bool IsValidPlatform(const std::string& value);
bool IsValidRefreshToken(const std::string& value);
bool IsValidOtpCode(const std::string& value);

#pragma once

#include <string>

std::string HashPassword(const std::string& password);
bool VerifyPassword(const std::string& hash, const std::string& password);

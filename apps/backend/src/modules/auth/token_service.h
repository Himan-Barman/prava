#pragma once

#include <chrono>
#include <string>

class TokenService {
 public:
  struct RefreshToken {
    std::string raw;
    std::string hash;
  };

  TokenService(std::string private_key, std::string public_key);

  std::string SignAccessToken(const std::string& subject) const;
  RefreshToken GenerateRefreshToken() const;
  std::chrono::system_clock::time_point RefreshExpiryDate() const;

 private:
  std::string private_key_;
  std::string public_key_;
};

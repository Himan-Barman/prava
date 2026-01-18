#include "modules/auth/token_service.h"

#include <chrono>
#include <stdexcept>
#include <string>
#include <vector>

#include <drogon/utils/Utilities.h>
#include <jwt-cpp/jwt.h>

namespace {

std::string RandomHex(size_t bytes) {
  std::vector<unsigned char> buffer(bytes);
  if (!drogon::utils::secureRandomBytes(buffer.data(), buffer.size())) {
    throw std::runtime_error("secure random failed");
  }
  return drogon::utils::binaryStringToHex(
      reinterpret_cast<const unsigned char*>(buffer.data()), buffer.size(), true);
}

}  // namespace

TokenService::TokenService(std::string private_key, std::string public_key)
    : private_key_(std::move(private_key)),
      public_key_(std::move(public_key)) {}

std::string TokenService::SignAccessToken(const std::string& subject) const {
  const auto now = std::chrono::system_clock::now();
  const auto expires = now + std::chrono::minutes(15);

  return jwt::create()
      .set_type("JWT")
      .set_subject(subject)
      .set_issued_at(now)
      .set_expires_at(expires)
      .sign(jwt::algorithm::rs256(public_key_, private_key_, "", ""));
}

TokenService::RefreshToken TokenService::GenerateRefreshToken() const {
  RefreshToken token;
  token.raw = RandomHex(64);
  token.hash = drogon::utils::getSha256(token.raw);
  return token;
}

std::chrono::system_clock::time_point TokenService::RefreshExpiryDate() const {
  return std::chrono::system_clock::now() + std::chrono::hours(24 * 30);
}

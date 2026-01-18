#include "modules/auth/password_hasher.h"

#include <argon2.h>
#include <cstring>
#include <stdexcept>
#include <vector>

#include <drogon/utils/Utilities.h>

namespace {

constexpr uint32_t kTimeCost = 3;
constexpr uint32_t kMemoryCost = 1 << 16;
constexpr uint32_t kParallelism = 4;
constexpr uint32_t kSaltLength = 16;
constexpr uint32_t kHashLength = 32;

}  // namespace

std::string HashPassword(const std::string& password) {
  std::vector<unsigned char> salt(kSaltLength);
  if (!drogon::utils::secureRandomBytes(salt.data(), salt.size())) {
    throw std::runtime_error("secure random failed");
  }

  const size_t encoded_length =
      argon2_encodedlen(kTimeCost, kMemoryCost, kParallelism, kSaltLength,
                        kHashLength, Argon2_id);
  std::string encoded(encoded_length, '\0');

  const int result = argon2id_hash_encoded(
      kTimeCost, kMemoryCost, kParallelism, password.data(), password.size(),
      salt.data(), salt.size(), kHashLength, encoded.data(), encoded.size());
  if (result != ARGON2_OK) {
    throw std::runtime_error("argon2 hash failed");
  }

  encoded.resize(std::strlen(encoded.c_str()));
  return encoded;
}

bool VerifyPassword(const std::string& hash, const std::string& password) {
  const int result =
      argon2id_verify(hash.c_str(), password.data(), password.size());
  return result == ARGON2_OK;
}

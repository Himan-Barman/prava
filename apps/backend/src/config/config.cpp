#include "config/config.h"

#include <algorithm>
#include <cstdlib>
#include <sstream>
#include <stdexcept>

namespace {
std::string GetEnv(const char* key) {
  const char* value = std::getenv(key);
  if (!value) {
    return "";
  }
  return std::string(value);
}

std::string GetEnvDefault(const char* key, const char* fallback) {
  const std::string value = GetEnv(key);
  return value.empty() ? std::string(fallback) : value;
}

int GetEnvInt(const char* key, int fallback) {
  const std::string value = GetEnv(key);
  if (value.empty()) {
    return fallback;
  }
  try {
    return std::stoi(value);
  } catch (const std::exception&) {
    throw std::runtime_error(std::string("invalid int for ") + key);
  }
}

bool GetEnvBool(const char* key, bool fallback) {
  const std::string value = GetEnv(key);
  if (value.empty()) {
    return fallback;
  }
  std::string lowered = value;
  std::transform(lowered.begin(), lowered.end(), lowered.begin(), ::tolower);
  if (lowered == "true" || lowered == "1") {
    return true;
  }
  if (lowered == "false" || lowered == "0") {
    return false;
  }
  throw std::runtime_error(std::string("invalid bool for ") + key);
}

std::string NormalizePem(std::string value) {
  std::string::size_type pos = 0;
  while ((pos = value.find("\\n", pos)) != std::string::npos) {
    value.replace(pos, 2, "\n");
    pos += 1;
  }
  return value;
}

std::vector<std::string> SplitCsv(const std::string& value) {
  std::vector<std::string> out;
  std::stringstream stream(value);
  std::string item;
  while (std::getline(stream, item, ',')) {
    item.erase(item.begin(),
               std::find_if(item.begin(), item.end(),
                            [](unsigned char c) { return !std::isspace(c); }));
    item.erase(
        std::find_if(item.rbegin(), item.rend(),
                     [](unsigned char c) { return !std::isspace(c); })
            .base(),
        item.end());
    if (!item.empty()) {
      out.push_back(item);
    }
  }
  return out;
}

void RequireNonEmpty(const std::string& value, const char* key) {
  if (value.empty()) {
    throw std::runtime_error(std::string(key) + " is required");
  }
}

void ValidateEnv(const std::string& env) {
  if (env != "development" && env != "test" && env != "production") {
    throw std::runtime_error("NODE_ENV must be development, test, or production");
  }
}
}  // namespace

Config Config::Load() {
  Config cfg;

  cfg.env = GetEnvDefault("NODE_ENV", "development");
  ValidateEnv(cfg.env);

  cfg.port = GetEnvInt("PORT", 3000);
  cfg.ws_port = GetEnvInt("WS_PORT", 3001);
  cfg.ws_mode = GetEnv("WS_MODE");

  const std::string cors_origin = GetEnv("CORS_ORIGIN");
  if (!cors_origin.empty()) {
    if (cors_origin == "*") {
      cfg.cors_allow_all = true;
    } else {
      cfg.cors_origins = SplitCsv(cors_origin);
    }
  }

  cfg.app_name = GetEnvDefault("APP_NAME", "PRAVA");
  cfg.redis_url = GetEnv("REDIS_URL");
  cfg.db_url = GetEnv("DATABASE_URL");

  cfg.jwt_private = NormalizePem(GetEnv("JWT_PRIVATE_KEY"));
  cfg.jwt_public = NormalizePem(GetEnv("JWT_PUBLIC_KEY"));

  RequireNonEmpty(cfg.redis_url, "REDIS_URL");
  RequireNonEmpty(cfg.db_url, "DATABASE_URL");
  RequireNonEmpty(cfg.jwt_private, "JWT_PRIVATE_KEY");
  RequireNonEmpty(cfg.jwt_public, "JWT_PUBLIC_KEY");

  cfg.email_from = GetEnv("EMAIL_FROM");
  cfg.email_from_name = GetEnv("EMAIL_FROM_NAME");
  cfg.email_support = GetEnv("EMAIL_SUPPORT");
  cfg.email_verify_url = GetEnv("EMAIL_VERIFY_URL");
  cfg.password_reset_url = GetEnv("PASSWORD_RESET_URL");
  cfg.resend_api_key = GetEnv("RESEND_API_KEY");

  const std::string email_to = GetEnv("EMAIL_TO");
  if (cfg.email_support.empty()) {
    cfg.email_support = email_to;
  }

  cfg.decision_engine_url = GetEnv("DECISION_ENGINE_URL");
  cfg.engagement_engine_url = GetEnv("ENGAGEMENT_ENGINE_URL");
  cfg.experimentation_engine_url = GetEnv("EXPERIMENTATION_ENGINE_URL");
  cfg.moderation_engine_url = GetEnv("MODERATION_ENGINE_URL");
  cfg.trust_safety_engine_url = GetEnv("TRUST_SAFETY_ENGINE_URL");

  cfg.fcm_service_account_json = GetEnv("FCM_SERVICE_ACCOUNT_JSON");
  cfg.apns_key_id = GetEnv("APNS_KEY_ID");
  cfg.apns_team_id = GetEnv("APNS_TEAM_ID");
  cfg.apns_bundle_id = GetEnv("APNS_BUNDLE_ID");
  cfg.apns_private_key = NormalizePem(GetEnv("APNS_PRIVATE_KEY"));
  cfg.apns_env = GetEnv("APNS_ENV");

  cfg.s3_endpoint = GetEnv("S3_ENDPOINT");
  cfg.s3_region = GetEnv("S3_REGION");
  cfg.s3_access_key_id = GetEnv("S3_ACCESS_KEY_ID");
  cfg.s3_secret_access_key = GetEnv("S3_SECRET_ACCESS_KEY");
  cfg.s3_bucket = GetEnv("S3_BUCKET");
  cfg.s3_public_base_url = GetEnv("S3_PUBLIC_BASE_URL");
  cfg.s3_force_path_style = GetEnvBool("S3_FORCE_PATH_STYLE", false);

  const std::string brokers_raw = GetEnv("KAFKA_BROKERS");
  if (!brokers_raw.empty()) {
    cfg.kafka_brokers = SplitCsv(brokers_raw);
  } else {
    cfg.kafka_brokers = {"localhost:9092"};
  }
  cfg.kafka_client_id = GetEnvDefault("KAFKA_CLIENT_ID", "prava-api");
  cfg.kafka_group_id = GetEnvDefault("KAFKA_GROUP_ID", "prava-workers");
  cfg.kafka_email_topic =
      GetEnvDefault("KAFKA_TOPIC_EMAIL", "prava.email");
  cfg.kafka_notification_topic =
      GetEnvDefault("KAFKA_TOPIC_NOTIFICATION", "prava.notification");
  cfg.kafka_message_topic =
      GetEnvDefault("KAFKA_TOPIC_MESSAGE", "prava.message");
  cfg.kafka_message_retry_topic =
      GetEnvDefault("KAFKA_TOPIC_MESSAGE_RETRY", "prava.message.retry");
  cfg.kafka_media_topic =
      GetEnvDefault("KAFKA_TOPIC_MEDIA", "prava.media");
  cfg.kafka_feed_topic =
      GetEnvDefault("KAFKA_TOPIC_FEED", "prava.feed");
  cfg.kafka_presence_topic =
      GetEnvDefault("KAFKA_TOPIC_PRESENCE", "prava.presence");
  cfg.kafka_support_topic =
      GetEnvDefault("KAFKA_TOPIC_SUPPORT", "prava.support");
  cfg.kafka_audit_topic =
      GetEnvDefault("KAFKA_TOPIC_AUDIT", "prava.audit");

  return cfg;
}

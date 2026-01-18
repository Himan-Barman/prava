#pragma once

#include <string>
#include <vector>

struct Config {
  std::string env;
  int port = 3000;
  int ws_port = 3001;
  std::string ws_mode;

  bool cors_allow_all = false;
  std::vector<std::string> cors_origins;

  std::string app_name;
  std::string redis_url;
  std::string db_url;
  std::string jwt_public;
  std::string jwt_private;

  std::string email_from;
  std::string email_from_name;
  std::string email_support;
  std::string email_verify_url;
  std::string password_reset_url;
  std::string resend_api_key;

  std::string decision_engine_url;
  std::string engagement_engine_url;
  std::string experimentation_engine_url;
  std::string moderation_engine_url;
  std::string trust_safety_engine_url;

  std::string fcm_service_account_json;
  std::string apns_key_id;
  std::string apns_team_id;
  std::string apns_bundle_id;
  std::string apns_private_key;
  std::string apns_env;

  std::string s3_endpoint;
  std::string s3_region;
  std::string s3_access_key_id;
  std::string s3_secret_access_key;
  std::string s3_bucket;
  std::string s3_public_base_url;
  bool s3_force_path_style = false;

  std::vector<std::string> kafka_brokers;
  std::string kafka_client_id;
  std::string kafka_group_id;
  std::string kafka_email_topic;
  std::string kafka_notification_topic;
  std::string kafka_message_topic;
  std::string kafka_message_retry_topic;
  std::string kafka_media_topic;
  std::string kafka_feed_topic;
  std::string kafka_presence_topic;
  std::string kafka_support_topic;
  std::string kafka_audit_topic;

  static Config Load();
};

#include "modules/users/users_service.h"

#include <algorithm>
#include <chrono>
#include <cctype>
#include <ctime>
#include <iomanip>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include "app_state.h"
#include "modules/auth/auth_service.h"
#include "modules/auth/auth_validation.h"
#include "modules/auth/token_service.h"
#include "modules/notifications/notifications_service.h"
#include "realtime/presence_manager.h"

namespace {

constexpr int kMaxProfileLimit = 30;
constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

std::string NowIsoString() {
  const auto now = std::chrono::system_clock::now();
  const auto millis =
      std::chrono::duration_cast<std::chrono::milliseconds>(
          now.time_since_epoch()) %
      1000;
  const std::time_t now_time = std::chrono::system_clock::to_time_t(now);
  std::tm tm{};
#if defined(_WIN32)
  gmtime_s(&tm, &now_time);
#else
  gmtime_r(&now_time, &tm);
#endif

  std::ostringstream stream;
  stream << std::put_time(&tm, "%Y-%m-%dT%H:%M:%S") << '.'
         << std::setw(3) << std::setfill('0') << millis.count() << 'Z';
  return stream.str();
}

int ClampLimit(const std::optional<int>& input,
               int default_value,
               int min_value,
               int max_value) {
  int value = input.value_or(default_value);
  if (value < min_value) {
    value = min_value;
  }
  if (value > max_value) {
    value = max_value;
  }
  return value;
}

Json::Value DefaultSettings() {
  Json::Value settings(Json::objectValue);
  settings["privateAccount"] = false;
  settings["activityStatus"] = true;
  settings["readReceipts"] = true;
  settings["messagePreview"] = true;
  settings["sensitiveContent"] = false;
  settings["locationSharing"] = false;
  settings["twoFactor"] = false;
  settings["loginAlerts"] = true;
  settings["appLock"] = false;
  settings["biometrics"] = true;
  settings["pushNotifications"] = true;
  settings["emailNotifications"] = false;
  settings["inAppSounds"] = true;
  settings["inAppHaptics"] = true;
  settings["dataSaver"] = false;
  settings["autoDownload"] = true;
  settings["autoPlayVideos"] = true;
  settings["reduceMotion"] = false;
  settings["themeIndex"] = 0;
  settings["textScale"] = 1.0;
  settings["languageLabel"] = "English";
  return settings;
}

Json::Value MergeSettings(const Json::Value& defaults,
                          const Json::Value& current,
                          const Json::Value& update) {
  Json::Value merged = defaults;
  if (current.isObject()) {
    for (const auto& key : current.getMemberNames()) {
      merged[key] = current[key];
    }
  }
  if (update.isObject()) {
    for (const auto& key : update.getMemberNames()) {
      merged[key] = update[key];
    }
  }
  return merged;
}

Json::Value ParseJsonText(const std::string& text,
                          const Json::Value& fallback) {
  if (text.empty()) {
    return fallback;
  }

  Json::CharReaderBuilder builder;
  builder["collectComments"] = false;
  Json::Value root;
  std::string errors;
  std::istringstream stream(text);
  if (!Json::parseFromStream(builder, stream, &root, &errors)) {
    return fallback;
  }
  return root;
}

std::string ToJsonString(const Json::Value& value) {
  Json::StreamWriterBuilder builder;
  builder["indentation"] = "";
  return Json::writeString(builder, value);
}

struct NormalizedPhone {
  std::string country_code;
  std::string phone_number;
};

std::optional<std::string> NormalizeName(const std::string& value) {
  std::string trimmed = Trim(value);
  std::string collapsed;
  bool in_space = false;
  for (const char ch : trimmed) {
    if (std::isspace(static_cast<unsigned char>(ch))) {
      if (!collapsed.empty() && !in_space) {
        collapsed.push_back(' ');
        in_space = true;
      }
    } else {
      collapsed.push_back(ch);
      in_space = false;
    }
  }

  if (collapsed.size() < 1 || collapsed.size() > 64) {
    return std::nullopt;
  }

  static const std::regex pattern(R"(^[A-Za-z][A-Za-z '\-]*$)");
  if (!std::regex_match(collapsed, pattern)) {
    return std::nullopt;
  }

  return collapsed;
}

std::optional<NormalizedPhone> NormalizePhone(const std::string& country_code,
                                              const std::string& phone_number) {
  auto normalized_country = Trim(country_code);
  normalized_country.erase(
      std::remove_if(normalized_country.begin(),
                     normalized_country.end(),
                     [](unsigned char c) { return std::isspace(c) != 0; }),
      normalized_country.end());

  auto normalized_number = Trim(phone_number);
  normalized_number.erase(
      std::remove_if(normalized_number.begin(),
                     normalized_number.end(),
                     [](unsigned char c) { return std::isspace(c) != 0; }),
      normalized_number.end());

  std::string digits = normalized_country;
  if (!digits.empty() && digits.front() == '+') {
    digits.erase(digits.begin());
  }

  static const std::regex country_pattern(R"(^\d{1,4}$)");
  static const std::regex number_pattern(R"(^\d{4,14}$)");

  if (!std::regex_match(digits, country_pattern)) {
    return std::nullopt;
  }
  if (!std::regex_match(normalized_number, number_pattern)) {
    return std::nullopt;
  }
  if (digits.size() + normalized_number.size() > 15) {
    return std::nullopt;
  }

  NormalizedPhone phone;
  phone.country_code = "+" + digits;
  phone.phone_number = normalized_number;
  return phone;
}

Json::Value NullableString(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return Json::nullValue;
  }
  return Json::Value(field.as<std::string>());
}

Json::Value MapPostRow(const drogon::orm::Row& row) {
  Json::Value item;
  item["id"] = row["id"].as<std::string>();
  item["body"] = row["body"].as<std::string>();
  item["createdAt"] = row["created_at"].as<std::string>();
  item["likeCount"] =
      row["like_count"].isNull() ? 0 : row["like_count"].as<int>();
  item["commentCount"] =
      row["comment_count"].isNull() ? 0 : row["comment_count"].as<int>();
  item["shareCount"] =
      row["share_count"].isNull() ? 0 : row["share_count"].as<int>();
  item["liked"] = row["liked"].as<bool>();
  item["followed"] = row["followed"].as<bool>();

  Json::Value mentions = ParseJsonText(
      row["mentions"].isNull() ? "" : row["mentions"].as<std::string>(),
      Json::Value(Json::arrayValue));
  if (!mentions.isArray()) {
    mentions = Json::Value(Json::arrayValue);
  }
  item["mentions"] = mentions;

  Json::Value hashtags = ParseJsonText(
      row["hashtags"].isNull() ? "" : row["hashtags"].as<std::string>(),
      Json::Value(Json::arrayValue));
  if (!hashtags.isArray()) {
    hashtags = Json::Value(Json::arrayValue);
  }
  item["hashtags"] = hashtags;

  Json::Value author;
  author["id"] = row["author_id"].as<std::string>();
  author["username"] = row["author_username"].as<std::string>();
  if (row["author_display_name"].isNull()) {
    author["displayName"] = author["username"].asString();
  } else {
    author["displayName"] = row["author_display_name"].as<std::string>();
  }
  item["author"] = author;
  return item;
}

AuthService BuildAuthService() {
  const auto& state = AppState::Instance();
  const auto& cfg = state.GetConfig();
  return AuthService(state.GetDb(),
                     TokenService(cfg.jwt_private, cfg.jwt_public));
}

}  // namespace

UsersService::UsersService(drogon::orm::DbClientPtr db) : db_(std::move(db)) {}

Json::Value UsersService::SearchUsers(const SearchUsersInput& input) {
  std::string normalized = ToLower(Trim(input.query));
  while (!normalized.empty() && normalized.front() == '@') {
    normalized.erase(normalized.begin());
  }

  Json::Value response;
  response["results"] = Json::Value(Json::arrayValue);

  if (normalized.size() < 2) {
    return response;
  }

  static const std::regex query_pattern(R"(^[a-z0-9_.]+$)");
  if (!std::regex_match(normalized, query_pattern)) {
    return response;
  }

  const int limit = ClampLimit(input.limit, 20, 1, 25);

  const auto rows = db_->execSqlSync(
      "SELECT "
      "u.id, "
      "u.username, "
      "u.display_name AS display_name, "
      "u.is_verified AS is_verified, "
      "(f1.follower_id IS NOT NULL) AS is_following, "
      "(f2.follower_id IS NOT NULL) AS is_followed_by "
      "FROM users u "
      "LEFT JOIN follows f1 "
      "  ON f1.follower_id = ? "
      " AND f1.following_id = u.id "
      "LEFT JOIN follows f2 "
      "  ON f2.follower_id = u.id "
      " AND f2.following_id = ? "
      "LEFT JOIN user_blocks b1 "
      "  ON b1.blocker_id = ? "
      " AND b1.blocked_id = u.id "
      "LEFT JOIN user_blocks b2 "
      "  ON b2.blocker_id = u.id "
      " AND b2.blocked_id = ? "
      "WHERE u.id <> ? "
      "  AND b1.blocker_id IS NULL "
      "  AND b2.blocker_id IS NULL "
      "  AND (u.username ILIKE ? OR u.display_name ILIKE ?) "
      "ORDER BY u.username ASC "
      "LIMIT ?",
      input.user_id,
      input.user_id,
      input.user_id,
      input.user_id,
      input.user_id,
      normalized + "%",
      normalized + "%",
      limit);

  Json::Value results(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["username"] = row["username"].as<std::string>();
    if (row["display_name"].isNull()) {
      item["displayName"] = item["username"].asString();
    } else {
      item["displayName"] = row["display_name"].as<std::string>();
    }
    item["isVerified"] = row["is_verified"].as<bool>();
    item["isFollowing"] = row["is_following"].as<bool>();
    item["isFollowedBy"] = row["is_followed_by"].as<bool>();
    results.append(item);
  }
  response["results"] = results;
  return response;
}

bool UsersService::IsUsernameAvailable(const std::string& username) {
  const std::string normalized = ToLower(Trim(username));
  if (!IsValidUsername(normalized)) {
    throw UsersError(drogon::k400BadRequest, "Invalid username");
  }

  const auto rows = db_->execSqlSync(
      "SELECT id FROM users WHERE username = ? LIMIT 1", normalized);
  return rows.empty();
}

Json::Value UsersService::ToggleFollow(const FollowInput& input) {
  if (input.follower_id == input.following_id) {
    throw UsersError(drogon::k400BadRequest, "Cannot follow self");
  }

  EnsureNotBlocked(input.follower_id, input.following_id);

  auto target = db_->execSqlSync(
      "SELECT id FROM users WHERE id = ? LIMIT 1", input.following_id);
  if (target.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto existing = db_->execSqlSync(
      "SELECT follower_id FROM follows WHERE follower_id = ? AND "
      "following_id = ? LIMIT 1",
      input.follower_id,
      input.following_id);

  Json::Value response;
  if (!existing.empty()) {
    db_->execSqlSync(
        "DELETE FROM follows WHERE follower_id = ? AND following_id = ?",
        input.follower_id,
        input.following_id);
    response["following"] = false;
    return response;
  }

  db_->execSqlSync(
      "INSERT INTO follows (follower_id, following_id) VALUES (?, ?)",
      input.follower_id,
      input.following_id);

  NotifyFollow(input.follower_id, input.following_id);

  response["following"] = true;
  return response;
}

Json::Value UsersService::SetFollow(const SetFollowInput& input) {
  if (input.follower_id == input.following_id) {
    throw UsersError(drogon::k400BadRequest, "Cannot follow self");
  }

  EnsureNotBlocked(input.follower_id, input.following_id);

  const auto target = db_->execSqlSync(
      "SELECT id FROM users WHERE id = ? LIMIT 1", input.following_id);
  if (target.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto existing = db_->execSqlSync(
      "SELECT follower_id FROM follows WHERE follower_id = ? AND "
      "following_id = ? LIMIT 1",
      input.follower_id,
      input.following_id);

  Json::Value response;
  if (input.follow) {
    if (!existing.empty()) {
      response["following"] = true;
      response["changed"] = false;
      return response;
    }

    db_->execSqlSync(
        "INSERT INTO follows (follower_id, following_id) VALUES (?, ?)",
        input.follower_id,
        input.following_id);

    NotifyFollow(input.follower_id, input.following_id);

    response["following"] = true;
    response["changed"] = true;
    return response;
  }

  if (existing.empty()) {
    response["following"] = false;
    response["changed"] = false;
    return response;
  }

  db_->execSqlSync(
      "DELETE FROM follows WHERE follower_id = ? AND following_id = ?",
      input.follower_id,
      input.following_id);

  response["following"] = false;
  response["changed"] = true;
  return response;
}

Json::Value UsersService::RemoveFollower(const RemoveFollowerInput& input) {
  if (input.user_id == input.follower_id) {
    throw UsersError(drogon::k400BadRequest, "Cannot remove self");
  }

  const auto rows = db_->execSqlSync(
      "DELETE FROM follows WHERE follower_id = ? AND following_id = ? "
      "RETURNING follower_id",
      input.follower_id,
      input.user_id);

  Json::Value response;
  response["removed"] = !rows.empty();
  return response;
}

Json::Value UsersService::RemoveConnection(
    const RemoveConnectionInput& input) {
  if (input.user_id == input.target_user_id) {
    throw UsersError(drogon::k400BadRequest, "Cannot remove self");
  }

  const auto rows = db_->execSqlSync(
      "DELETE FROM follows WHERE "
      "(follower_id = ? AND following_id = ?) "
      "OR (follower_id = ? AND following_id = ?) "
      "RETURNING follower_id",
      input.user_id,
      input.target_user_id,
      input.target_user_id,
      input.user_id);

  Json::Value response;
  response["removed"] = !rows.empty();
  return response;
}

Json::Value UsersService::GetConnections(const UserLimitInput& input) {
  const int limit = ClampLimit(input.limit, 20, 1, 50);

  const auto requests_rows = db_->execSqlSync(
      "SELECT "
      "u.id, "
      "u.username, "
      "u.display_name AS display_name, "
      "u.bio, "
      "u.location, "
      "u.is_verified AS is_verified, "
      "to_char(u.created_at at time zone 'utc', ?) AS created_at, "
      "to_char(f.created_at at time zone 'utc', ?) AS since "
      "FROM follows f "
      "JOIN users u ON u.id = f.follower_id "
      "LEFT JOIN follows f2 "
      "  ON f2.follower_id = ? "
      " AND f2.following_id = f.follower_id "
      "WHERE f.following_id = ? "
      "  AND f2.follower_id IS NULL "
      "ORDER BY f.created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      kTimestampFormat,
      input.user_id,
      input.user_id,
      limit);

  const auto sent_rows = db_->execSqlSync(
      "SELECT "
      "u.id, "
      "u.username, "
      "u.display_name AS display_name, "
      "u.bio, "
      "u.location, "
      "u.is_verified AS is_verified, "
      "to_char(u.created_at at time zone 'utc', ?) AS created_at, "
      "to_char(f.created_at at time zone 'utc', ?) AS since "
      "FROM follows f "
      "JOIN users u ON u.id = f.following_id "
      "LEFT JOIN follows f2 "
      "  ON f2.follower_id = u.id "
      " AND f2.following_id = ? "
      "WHERE f.follower_id = ? "
      "  AND f2.follower_id IS NULL "
      "ORDER BY f.created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      kTimestampFormat,
      input.user_id,
      input.user_id,
      limit);

  const auto friends_rows = db_->execSqlSync(
      "SELECT "
      "u.id, "
      "u.username, "
      "u.display_name AS display_name, "
      "u.bio, "
      "u.location, "
      "u.is_verified AS is_verified, "
      "to_char(u.created_at at time zone 'utc', ?) AS created_at, "
      "to_char(GREATEST(f.created_at, f2.created_at) at time zone 'utc', ?) AS since "
      "FROM follows f "
      "JOIN users u ON u.id = f.following_id "
      "JOIN follows f2 "
      "  ON f2.follower_id = u.id "
      " AND f2.following_id = ? "
      "WHERE f.follower_id = ? "
      "ORDER BY GREATEST(f.created_at, f2.created_at) DESC "
      "LIMIT ?",
      kTimestampFormat,
      kTimestampFormat,
      input.user_id,
      input.user_id,
      limit);

  PresenceManager presence;

  auto map_rows = [&presence](const drogon::orm::Result& rows,
                              bool is_following,
                              bool is_followed_by) {
    Json::Value items(Json::arrayValue);
    for (const auto& row : rows) {
      Json::Value item;
      const std::string user_id = row["id"].as<std::string>();
      item["id"] = user_id;
      item["username"] = row["username"].as<std::string>();
      if (row["display_name"].isNull()) {
        item["displayName"] = item["username"].asString();
      } else {
        item["displayName"] = row["display_name"].as<std::string>();
      }
      item["bio"] = row["bio"].isNull() ? "" : row["bio"].as<std::string>();
      item["location"] =
          row["location"].isNull() ? "" : row["location"].as<std::string>();
      item["isVerified"] = row["is_verified"].as<bool>();
      item["createdAt"] = row["created_at"].as<std::string>();
      item["since"] = row["since"].as<std::string>();
      item["isFollowing"] = is_following;
      item["isFollowedBy"] = is_followed_by;
      item["isOnline"] = presence.IsOnline(user_id);
      items.append(item);
    }
    return items;
  };

  Json::Value response;
  response["requests"] = map_rows(requests_rows, false, true);
  response["sent"] = map_rows(sent_rows, true, false);
  response["friends"] = map_rows(friends_rows, true, true);
  return response;
}

Json::Value UsersService::GetProfileSummary(const UserLimitInput& input) {
  const int limit = ClampLimit(input.limit, 12, 1, kMaxProfileLimit);

  const auto users_rows = db_->execSqlSync(
      "SELECT "
      "id, "
      "username, "
      "display_name, "
      "bio, "
      "location, "
      "website, "
      "is_verified, "
      "to_char(created_at at time zone 'utc', ?) AS created_at "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      input.user_id);

  if (users_rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto& user_row = users_rows.front();

  const auto stats_rows = db_->execSqlSync(
      "SELECT "
      "(SELECT COUNT(*)::int FROM feed_posts WHERE author_id = ?) AS posts, "
      "(SELECT COUNT(*)::int FROM follows WHERE following_id = ?) AS followers, "
      "(SELECT COUNT(*)::int FROM follows WHERE follower_id = ?) AS following, "
      "(SELECT COALESCE(SUM(like_count), 0)::int FROM feed_posts WHERE author_id = ?) AS likes",
      input.user_id,
      input.user_id,
      input.user_id,
      input.user_id);

  const auto posts_rows = db_->execSqlSync(
      "SELECT "
      "p.id AS id, "
      "p.body AS body, "
      "to_char(p.created_at at time zone 'utc', ?) AS created_at, "
      "p.like_count AS like_count, "
      "p.comment_count AS comment_count, "
      "p.share_count AS share_count, "
      "COALESCE(p.metadata->'mentions', '[]'::jsonb)::text AS mentions, "
      "COALESCE(p.metadata->'hashtags', '[]'::jsonb)::text AS hashtags, "
      "u.id AS author_id, "
      "u.username AS author_username, "
      "u.display_name AS author_display_name, "
      "(fl.user_id IS NOT NULL) AS liked, "
      "(f.follower_id IS NOT NULL) AS followed "
      "FROM feed_posts p "
      "JOIN users u ON u.id = p.author_id "
      "LEFT JOIN feed_likes fl "
      "  ON fl.post_id = p.id AND fl.user_id = ? "
      "LEFT JOIN follows f "
      "  ON f.follower_id = ? AND f.following_id = p.author_id "
      "WHERE p.author_id = ? "
      "ORDER BY p.created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      input.user_id,
      input.user_id,
      input.user_id,
      limit);

  const auto liked_rows = db_->execSqlSync(
      "SELECT "
      "p.id AS id, "
      "p.body AS body, "
      "to_char(p.created_at at time zone 'utc', ?) AS created_at, "
      "p.like_count AS like_count, "
      "p.comment_count AS comment_count, "
      "p.share_count AS share_count, "
      "COALESCE(p.metadata->'mentions', '[]'::jsonb)::text AS mentions, "
      "COALESCE(p.metadata->'hashtags', '[]'::jsonb)::text AS hashtags, "
      "u.id AS author_id, "
      "u.username AS author_username, "
      "u.display_name AS author_display_name, "
      "true AS liked, "
      "(f.follower_id IS NOT NULL) AS followed "
      "FROM feed_posts p "
      "JOIN users u ON u.id = p.author_id "
      "JOIN feed_likes fl "
      "  ON fl.post_id = p.id AND fl.user_id = ? "
      "LEFT JOIN follows f "
      "  ON f.follower_id = ? AND f.following_id = p.author_id "
      "ORDER BY fl.created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      input.user_id,
      input.user_id,
      limit);

  Json::Value user;
  user["id"] = user_row["id"].as<std::string>();
  user["username"] = user_row["username"].as<std::string>();
  if (user_row["display_name"].isNull()) {
    user["displayName"] = user["username"].asString();
  } else {
    user["displayName"] = user_row["display_name"].as<std::string>();
  }
  user["bio"] = NullableString(user_row["bio"]);
  user["location"] = NullableString(user_row["location"]);
  user["website"] = NullableString(user_row["website"]);
  user["isVerified"] = user_row["is_verified"].as<bool>();
  user["createdAt"] = user_row["created_at"].as<std::string>();

  Json::Value stats;
  if (!stats_rows.empty()) {
    const auto& row = stats_rows.front();
    stats["posts"] = row["posts"].isNull() ? 0 : row["posts"].as<int>();
    stats["followers"] =
        row["followers"].isNull() ? 0 : row["followers"].as<int>();
    stats["following"] =
        row["following"].isNull() ? 0 : row["following"].as<int>();
    stats["likes"] = row["likes"].isNull() ? 0 : row["likes"].as<int>();
  } else {
    stats["posts"] = 0;
    stats["followers"] = 0;
    stats["following"] = 0;
    stats["likes"] = 0;
  }

  Json::Value posts(Json::arrayValue);
  for (const auto& row : posts_rows) {
    posts.append(MapPostRow(row));
  }

  Json::Value liked(Json::arrayValue);
  for (const auto& row : liked_rows) {
    liked.append(MapPostRow(row));
  }

  Json::Value response;
  response["user"] = user;
  response["stats"] = stats;
  response["posts"] = posts;
  response["liked"] = liked;
  return response;
}

Json::Value UsersService::GetPublicProfileSummary(
    const PublicProfileInput& input) {
  EnsureNotBlocked(input.viewer_id, input.target_user_id);

  const int limit = ClampLimit(input.limit, 12, 1, kMaxProfileLimit);

  const auto users_rows = db_->execSqlSync(
      "SELECT "
      "id, "
      "username, "
      "display_name, "
      "bio, "
      "location, "
      "website, "
      "is_verified, "
      "to_char(created_at at time zone 'utc', ?) AS created_at "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      input.target_user_id);

  if (users_rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto relationship_rows = db_->execSqlSync(
      "SELECT "
      "EXISTS(SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?) "
      "AS is_following, "
      "EXISTS(SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?) "
      "AS is_followed_by",
      input.viewer_id,
      input.target_user_id,
      input.target_user_id,
      input.viewer_id);

  const auto stats_rows = db_->execSqlSync(
      "SELECT "
      "(SELECT COUNT(*)::int FROM feed_posts WHERE author_id = ?) AS posts, "
      "(SELECT COUNT(*)::int FROM follows WHERE following_id = ?) AS followers, "
      "(SELECT COUNT(*)::int FROM follows WHERE follower_id = ?) AS following, "
      "(SELECT COALESCE(SUM(like_count), 0)::int FROM feed_posts WHERE author_id = ?) AS likes",
      input.target_user_id,
      input.target_user_id,
      input.target_user_id,
      input.target_user_id);

  const auto posts_rows = db_->execSqlSync(
      "SELECT "
      "p.id AS id, "
      "p.body AS body, "
      "to_char(p.created_at at time zone 'utc', ?) AS created_at, "
      "p.like_count AS like_count, "
      "p.comment_count AS comment_count, "
      "p.share_count AS share_count, "
      "COALESCE(p.metadata->'mentions', '[]'::jsonb)::text AS mentions, "
      "COALESCE(p.metadata->'hashtags', '[]'::jsonb)::text AS hashtags, "
      "u.id AS author_id, "
      "u.username AS author_username, "
      "u.display_name AS author_display_name, "
      "(fl.user_id IS NOT NULL) AS liked, "
      "(f.follower_id IS NOT NULL) AS followed "
      "FROM feed_posts p "
      "JOIN users u ON u.id = p.author_id "
      "LEFT JOIN feed_likes fl "
      "  ON fl.post_id = p.id AND fl.user_id = ? "
      "LEFT JOIN follows f "
      "  ON f.follower_id = ? AND f.following_id = p.author_id "
      "WHERE p.author_id = ? "
      "ORDER BY p.created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      input.viewer_id,
      input.viewer_id,
      input.target_user_id,
      limit);

  const auto& user_row = users_rows.front();

  Json::Value user;
  user["id"] = user_row["id"].as<std::string>();
  user["username"] = user_row["username"].as<std::string>();
  if (user_row["display_name"].isNull()) {
    user["displayName"] = user["username"].asString();
  } else {
    user["displayName"] = user_row["display_name"].as<std::string>();
  }
  user["bio"] = NullableString(user_row["bio"]);
  user["location"] = NullableString(user_row["location"]);
  user["website"] = NullableString(user_row["website"]);
  user["isVerified"] = user_row["is_verified"].as<bool>();
  user["createdAt"] = user_row["created_at"].as<std::string>();

  Json::Value relationship;
  if (!relationship_rows.empty()) {
    const auto& row = relationship_rows.front();
    relationship["isFollowing"] = row["is_following"].as<bool>();
    relationship["isFollowedBy"] = row["is_followed_by"].as<bool>();
  } else {
    relationship["isFollowing"] = false;
    relationship["isFollowedBy"] = false;
  }

  Json::Value stats;
  if (!stats_rows.empty()) {
    const auto& row = stats_rows.front();
    stats["posts"] = row["posts"].isNull() ? 0 : row["posts"].as<int>();
    stats["followers"] =
        row["followers"].isNull() ? 0 : row["followers"].as<int>();
    stats["following"] =
        row["following"].isNull() ? 0 : row["following"].as<int>();
    stats["likes"] = row["likes"].isNull() ? 0 : row["likes"].as<int>();
  } else {
    stats["posts"] = 0;
    stats["followers"] = 0;
    stats["following"] = 0;
    stats["likes"] = 0;
  }

  Json::Value posts(Json::arrayValue);
  for (const auto& row : posts_rows) {
    posts.append(MapPostRow(row));
  }

  Json::Value response;
  response["user"] = user;
  response["stats"] = stats;
  response["relationship"] = relationship;
  response["posts"] = posts;
  return response;
}

Json::Value UsersService::UpdateDetails(const std::string& user_id,
                                        const UpdateDetailsInput& input) {
  const auto first_name = NormalizeName(input.first_name);
  const auto last_name = NormalizeName(input.last_name);

  if (!first_name || !last_name) {
    throw UsersError(drogon::k400BadRequest, "Invalid name");
  }

  const auto phone =
      NormalizePhone(input.phone_country_code, input.phone_number);
  if (!phone) {
    throw UsersError(drogon::k400BadRequest, "Invalid phone number");
  }

  const std::string display_name = *first_name + " " + *last_name;

  const auto rows = db_->execSqlSync(
      "UPDATE users SET "
      "first_name = ?, "
      "last_name = ?, "
      "phone_country = ?, "
      "phone_number = ?, "
      "display_name = ?, "
      "updated_at = NOW() "
      "WHERE id = ? "
      "RETURNING id",
      *first_name,
      *last_name,
      phone->country_code,
      phone->phone_number,
      display_name,
      user_id);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  Json::Value response;
  response["success"] = true;

  Json::Value profile;
  profile["firstName"] = *first_name;
  profile["lastName"] = *last_name;
  profile["displayName"] = display_name;
  profile["phoneCountryCode"] = phone->country_code;
  profile["phoneNumber"] = phone->phone_number;
  response["profile"] = profile;

  return response;
}

Json::Value UsersService::GetSettings(const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT settings::text AS settings, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at "
      "FROM user_settings WHERE user_id = ? LIMIT 1",
      kTimestampFormat,
      user_id);

  Json::Value settings = DefaultSettings();
  std::string updated_at = NowIsoString();

  if (!rows.empty()) {
    const auto& row = rows.front();
    if (!row["settings"].isNull()) {
      settings = MergeSettings(settings,
                               ParseJsonText(row["settings"].as<std::string>(),
                                             Json::Value(Json::objectValue)),
                               Json::Value(Json::objectValue));
    }
    if (!row["updated_at"].isNull()) {
      updated_at = row["updated_at"].as<std::string>();
    }
  }

  Json::Value response;
  response["settings"] = settings;
  response["updatedAt"] = updated_at;
  return response;
}

Json::Value UsersService::UpdateSettings(const std::string& user_id,
                                         const Json::Value& updates) {
  const auto existing = db_->execSqlSync(
      "SELECT settings::text AS settings FROM user_settings WHERE user_id = ? "
      "LIMIT 1",
      user_id);

  Json::Value current(Json::objectValue);
  if (!existing.empty() && !existing.front()["settings"].isNull()) {
    current = ParseJsonText(existing.front()["settings"].as<std::string>(),
                            Json::Value(Json::objectValue));
  }

  Json::Value next = MergeSettings(DefaultSettings(), current, updates);
  const std::string payload = ToJsonString(next);

  const auto rows = db_->execSqlSync(
      "INSERT INTO user_settings (user_id, settings, updated_at) "
      "VALUES (?, ?::jsonb, NOW()) "
      "ON CONFLICT (user_id) DO UPDATE SET "
      "settings = EXCLUDED.settings, "
      "updated_at = EXCLUDED.updated_at "
      "RETURNING settings::text AS settings, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at",
      user_id,
      payload,
      kTimestampFormat);

  Json::Value settings = next;
  std::string updated_at = NowIsoString();
  if (!rows.empty()) {
    const auto& row = rows.front();
    if (!row["settings"].isNull()) {
      settings = ParseJsonText(row["settings"].as<std::string>(), next);
    }
    if (!row["updated_at"].isNull()) {
      updated_at = row["updated_at"].as<std::string>();
    }
  }

  Json::Value response;
  response["settings"] = settings;
  response["updatedAt"] = updated_at;
  return response;
}

Json::Value UsersService::GetAccountInfo(const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT "
      "id, "
      "email, "
      "username, "
      "display_name, "
      "first_name, "
      "last_name, "
      "phone_country, "
      "phone_number, "
      "bio, "
      "location, "
      "website, "
      "is_verified, "
      "to_char(email_verified_at at time zone 'utc', ?) AS email_verified_at, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      kTimestampFormat,
      kTimestampFormat,
      user_id);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto& row = rows.front();
  Json::Value account;
  account["id"] = row["id"].as<std::string>();
  account["email"] = row["email"].as<std::string>();
  account["username"] = row["username"].as<std::string>();
  if (row["display_name"].isNull()) {
    account["displayName"] = account["username"].asString();
  } else {
    account["displayName"] = row["display_name"].as<std::string>();
  }
  account["firstName"] =
      row["first_name"].isNull() ? "" : row["first_name"].as<std::string>();
  account["lastName"] =
      row["last_name"].isNull() ? "" : row["last_name"].as<std::string>();
  account["phoneCountryCode"] = row["phone_country"].isNull()
                                    ? ""
                                    : row["phone_country"].as<std::string>();
  account["phoneNumber"] = row["phone_number"].isNull()
                               ? ""
                               : row["phone_number"].as<std::string>();
  account["bio"] = row["bio"].isNull() ? "" : row["bio"].as<std::string>();
  account["location"] =
      row["location"].isNull() ? "" : row["location"].as<std::string>();
  account["website"] =
      row["website"].isNull() ? "" : row["website"].as<std::string>();
  account["isVerified"] = row["is_verified"].as<bool>();
  account["emailVerifiedAt"] =
      row["email_verified_at"].isNull()
          ? Json::nullValue
          : Json::Value(row["email_verified_at"].as<std::string>());
  account["createdAt"] = row["created_at"].as<std::string>();
  account["updatedAt"] = row["updated_at"].as<std::string>();

  Json::Value response;
  response["account"] = account;
  return response;
}

Json::Value UsersService::UpdateEmail(const std::string& user_id,
                                      const std::string& email) {
  const std::string normalized = ToLower(Trim(email));
  if (normalized.empty() || normalized.size() > 255 ||
      !IsValidEmail(normalized)) {
    throw UsersError(drogon::k400BadRequest, "Invalid email");
  }

  const auto current_rows = db_->execSqlSync(
      "SELECT id, email, is_verified, "
      "to_char(email_verified_at at time zone 'utc', ?) AS email_verified_at "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      user_id);

  if (current_rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto& current = current_rows.front();
  const std::string current_email = current["email"].as<std::string>();

  if (current_email == normalized) {
    Json::Value response;
    response["email"] = current_email;
    response["isVerified"] = current["is_verified"].as<bool>();
    response["emailVerifiedAt"] =
        current["email_verified_at"].isNull()
            ? Json::nullValue
            : Json::Value(current["email_verified_at"].as<std::string>());
    return response;
  }

  const auto existing = db_->execSqlSync(
      "SELECT id FROM users WHERE email = ? LIMIT 1", normalized);
  if (!existing.empty() &&
      existing.front()["id"].as<std::string>() != user_id) {
    throw UsersError(drogon::k409Conflict, "Email already exists");
  }

  const auto rows = db_->execSqlSync(
      "UPDATE users SET "
      "email = ?, "
      "is_verified = false, "
      "email_verified_at = NULL, "
      "updated_at = NOW() "
      "WHERE id = ? "
      "RETURNING email, is_verified, "
      "to_char(email_verified_at at time zone 'utc', ?) AS email_verified_at",
      normalized,
      user_id,
      kTimestampFormat);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  try {
    auto auth = BuildAuthService();
    EmailInput input{normalized};
    auth.RequestEmailVerification(input);
  } catch (const std::exception&) {
  }

  const auto& row = rows.front();
  Json::Value response;
  response["email"] = row["email"].as<std::string>();
  response["isVerified"] = row["is_verified"].as<bool>();
  response["emailVerifiedAt"] =
      row["email_verified_at"].isNull()
          ? Json::nullValue
          : Json::Value(row["email_verified_at"].as<std::string>());
  return response;
}

Json::Value UsersService::UpdateHandle(const std::string& user_id,
                                       const UpdateHandleInput& input) {
  const auto current_rows = db_->execSqlSync(
      "SELECT username, display_name, bio, location, website, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      user_id);

  if (current_rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto& current = current_rows.front();
  std::string next_username = current["username"].as<std::string>();
  std::string next_display =
      current["display_name"].isNull()
          ? ""
          : current["display_name"].as<std::string>();
  std::string next_bio =
      current["bio"].isNull() ? "" : current["bio"].as<std::string>();
  std::string next_location =
      current["location"].isNull() ? "" : current["location"].as<std::string>();
  std::string next_website =
      current["website"].isNull() ? "" : current["website"].as<std::string>();

  bool has_updates = false;

  if (input.username) {
    std::string username = ToLower(Trim(*input.username));
    while (!username.empty() && username.front() == '@') {
      username.erase(username.begin());
    }
    if (!IsValidUsername(username)) {
      throw UsersError(drogon::k400BadRequest, "Invalid username");
    }

    if (username != next_username) {
      const auto existing = db_->execSqlSync(
          "SELECT id FROM users WHERE username = ? LIMIT 1", username);
      if (!existing.empty() &&
          existing.front()["id"].as<std::string>() != user_id) {
        throw UsersError(drogon::k409Conflict, "Username already exists");
      }
    }
    next_username = username;
    has_updates = true;
  }

  if (input.display_name) {
    const std::string trimmed = Trim(*input.display_name);
    next_display = trimmed;
    has_updates = true;
  }

  if (input.bio) {
    const std::string trimmed = Trim(*input.bio);
    next_bio = trimmed;
    has_updates = true;
  }

  if (input.location) {
    const std::string trimmed = Trim(*input.location);
    next_location = trimmed;
    has_updates = true;
  }

  if (input.website) {
    const std::string trimmed = Trim(*input.website);
    next_website = trimmed;
    has_updates = true;
  }

  if (!has_updates) {
    Json::Value response;
    Json::Value profile;
    profile["id"] = user_id;
    profile["username"] = next_username;
    profile["displayName"] =
        next_display.empty() ? next_username : next_display;
    profile["bio"] = next_bio.empty() ? "" : next_bio;
    profile["location"] = next_location.empty() ? "" : next_location;
    profile["website"] = next_website.empty() ? "" : next_website;
    profile["updatedAt"] = current["updated_at"].as<std::string>();
    response["profile"] = profile;
    return response;
  }

  const auto rows = db_->execSqlSync(
      "UPDATE users SET "
      "username = ?, "
      "display_name = NULLIF(?, ''), "
      "bio = NULLIF(?, ''), "
      "location = NULLIF(?, ''), "
      "website = NULLIF(?, ''), "
      "updated_at = NOW() "
      "WHERE id = ? "
      "RETURNING id, username, display_name, bio, location, website, "
      "to_char(updated_at at time zone 'utc', ?) AS updated_at",
      next_username,
      next_display,
      next_bio,
      next_location,
      next_website,
      user_id,
      kTimestampFormat);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto& row = rows.front();
  Json::Value profile;
  profile["id"] = row["id"].as<std::string>();
  profile["username"] = row["username"].as<std::string>();
  if (row["display_name"].isNull()) {
    profile["displayName"] = profile["username"].asString();
  } else {
    profile["displayName"] = row["display_name"].as<std::string>();
  }
  profile["bio"] = row["bio"].isNull() ? "" : row["bio"].as<std::string>();
  profile["location"] =
      row["location"].isNull() ? "" : row["location"].as<std::string>();
  profile["website"] =
      row["website"].isNull() ? "" : row["website"].as<std::string>();
  profile["updatedAt"] = row["updated_at"].as<std::string>();

  Json::Value response;
  response["profile"] = profile;
  return response;
}

Json::Value UsersService::ListBlockedUsers(const UserLimitInput& input) {
  const int limit = ClampLimit(input.limit, 30, 1, 50);

  const auto rows = db_->execSqlSync(
      "SELECT "
      "u.id, "
      "u.username, "
      "u.display_name AS display_name, "
      "u.is_verified AS is_verified, "
      "to_char(b.created_at at time zone 'utc', ?) AS blocked_at "
      "FROM user_blocks b "
      "JOIN users u ON u.id = b.blocked_id "
      "WHERE b.blocker_id = ? "
      "ORDER BY b.created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      input.user_id,
      limit);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["username"] = row["username"].as<std::string>();
    if (row["display_name"].isNull()) {
      item["displayName"] = item["username"].asString();
    } else {
      item["displayName"] = row["display_name"].as<std::string>();
    }
    item["isVerified"] = row["is_verified"].as<bool>();
    item["blockedAt"] = row["blocked_at"].as<std::string>();
    items.append(item);
  }

  Json::Value response;
  response["items"] = items;
  return response;
}

Json::Value UsersService::BlockUser(const BlockInput& input) {
  if (input.user_id == input.target_user_id) {
    throw UsersError(drogon::k400BadRequest, "Cannot block self");
  }

  const auto target = db_->execSqlSync(
      "SELECT id FROM users WHERE id = ? LIMIT 1", input.target_user_id);
  if (target.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  db_->execSqlSync(
      "INSERT INTO user_blocks (blocker_id, blocked_id) "
      "VALUES (?, ?) "
      "ON CONFLICT (blocker_id, blocked_id) DO NOTHING",
      input.user_id,
      input.target_user_id);

  db_->execSqlSync(
      "DELETE FROM follows WHERE "
      "(follower_id = ? AND following_id = ?) "
      "OR (follower_id = ? AND following_id = ?)",
      input.user_id,
      input.target_user_id,
      input.target_user_id,
      input.user_id);

  Json::Value response;
  response["blocked"] = true;
  return response;
}

Json::Value UsersService::UnblockUser(const BlockInput& input) {
  const auto rows = db_->execSqlSync(
      "DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ? "
      "RETURNING id",
      input.user_id,
      input.target_user_id);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "Block not found");
  }

  Json::Value response;
  response["blocked"] = false;
  return response;
}

Json::Value UsersService::ListMutedWords(const UserLimitInput& input) {
  const int limit = ClampLimit(input.limit, 50, 1, 200);

  const auto rows = db_->execSqlSync(
      "SELECT "
      "id, "
      "phrase, "
      "to_char(created_at at time zone 'utc', ?) AS created_at "
      "FROM user_muted_words "
      "WHERE user_id = ? "
      "ORDER BY created_at DESC "
      "LIMIT ?",
      kTimestampFormat,
      input.user_id,
      limit);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["phrase"] = row["phrase"].as<std::string>();
    item["createdAt"] = row["created_at"].as<std::string>();
    items.append(item);
  }

  Json::Value response;
  response["items"] = items;
  return response;
}

Json::Value UsersService::AddMutedWord(const AddMutedWordInput& input) {
  std::string phrase = ToLower(Trim(input.phrase));
  if (phrase.empty()) {
    throw UsersError(drogon::k400BadRequest, "Phrase required");
  }
  if (phrase.size() > 120) {
    throw UsersError(drogon::k400BadRequest, "Phrase required");
  }

  const auto rows = db_->execSqlSync(
      "INSERT INTO user_muted_words (user_id, phrase) "
      "VALUES (?, ?) "
      "ON CONFLICT (user_id, phrase) DO NOTHING "
      "RETURNING id, phrase, "
      "to_char(created_at at time zone 'utc', ?) AS created_at",
      input.user_id,
      phrase,
      kTimestampFormat);

  Json::Value response;
  if (rows.empty()) {
    response["phrase"] = phrase;
    response["existed"] = true;
    return response;
  }

  const auto& row = rows.front();
  Json::Value item;
  item["id"] = row["id"].as<std::string>();
  item["phrase"] = row["phrase"].as<std::string>();
  item["createdAt"] = row["created_at"].as<std::string>();
  response["item"] = item;
  return response;
}

Json::Value UsersService::RemoveMutedWord(const RemoveMutedWordInput& input) {
  const auto rows = db_->execSqlSync(
      "DELETE FROM user_muted_words WHERE user_id = ? AND id = ? "
      "RETURNING id",
      input.user_id,
      input.word_id);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "Muted word not found");
  }

  Json::Value response;
  response["removed"] = true;
  return response;
}

Json::Value UsersService::CreateDataExport(const std::string& user_id) {
  const auto user_rows = db_->execSqlSync(
      "SELECT "
      "id, "
      "email, "
      "username, "
      "display_name, "
      "first_name, "
      "last_name, "
      "bio, "
      "location, "
      "website, "
      "phone_country, "
      "phone_number, "
      "is_verified, "
      "to_char(created_at at time zone 'utc', ?) AS created_at "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      user_id);

  if (user_rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  const auto settings_snapshot = GetSettings(user_id);

  const auto stats_rows = db_->execSqlSync(
      "SELECT "
      "(SELECT COUNT(*)::int FROM feed_posts WHERE author_id = ?) AS posts, "
      "(SELECT COUNT(*)::int FROM follows WHERE following_id = ?) AS followers, "
      "(SELECT COUNT(*)::int FROM follows WHERE follower_id = ?) AS following, "
      "(SELECT COALESCE(SUM(like_count), 0)::int FROM feed_posts WHERE author_id = ?) AS likes",
      user_id,
      user_id,
      user_id,
      user_id);

  const auto recent_posts = db_->execSqlSync(
      "SELECT "
      "id, "
      "body, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "like_count, "
      "comment_count, "
      "share_count "
      "FROM feed_posts "
      "WHERE author_id = ? "
      "ORDER BY created_at DESC "
      "LIMIT 50",
      kTimestampFormat,
      user_id);

  const auto blocked_rows = db_->execSqlSync(
      "SELECT blocked_id FROM user_blocks WHERE blocker_id = ?", user_id);
  const auto muted_rows = db_->execSqlSync(
      "SELECT phrase FROM user_muted_words WHERE user_id = ?", user_id);

  const auto& user_row = user_rows.front();
  Json::Value user;
  user["id"] = user_row["id"].as<std::string>();
  user["email"] = user_row["email"].as<std::string>();
  user["username"] = user_row["username"].as<std::string>();
  if (user_row["display_name"].isNull()) {
    user["displayName"] = user["username"].asString();
  } else {
    user["displayName"] = user_row["display_name"].as<std::string>();
  }
  user["firstName"] = user_row["first_name"].isNull()
                          ? ""
                          : user_row["first_name"].as<std::string>();
  user["lastName"] = user_row["last_name"].isNull()
                         ? ""
                         : user_row["last_name"].as<std::string>();
  user["bio"] =
      user_row["bio"].isNull() ? "" : user_row["bio"].as<std::string>();
  user["location"] = user_row["location"].isNull()
                         ? ""
                         : user_row["location"].as<std::string>();
  user["website"] = user_row["website"].isNull()
                        ? ""
                        : user_row["website"].as<std::string>();
  user["phoneCountryCode"] = user_row["phone_country"].isNull()
                                 ? ""
                                 : user_row["phone_country"].as<std::string>();
  user["phoneNumber"] = user_row["phone_number"].isNull()
                            ? ""
                            : user_row["phone_number"].as<std::string>();
  user["isVerified"] = user_row["is_verified"].as<bool>();
  user["createdAt"] = user_row["created_at"].as<std::string>();

  Json::Value stats;
  if (!stats_rows.empty()) {
    const auto& row = stats_rows.front();
    stats["posts"] = row["posts"].isNull() ? 0 : row["posts"].as<int>();
    stats["followers"] =
        row["followers"].isNull() ? 0 : row["followers"].as<int>();
    stats["following"] =
        row["following"].isNull() ? 0 : row["following"].as<int>();
    stats["likes"] = row["likes"].isNull() ? 0 : row["likes"].as<int>();
  } else {
    stats["posts"] = 0;
    stats["followers"] = 0;
    stats["following"] = 0;
    stats["likes"] = 0;
  }

  Json::Value recent(Json::arrayValue);
  for (const auto& row : recent_posts) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["body"] = row["body"].as<std::string>();
    item["createdAt"] = row["created_at"].as<std::string>();
    item["likeCount"] =
        row["like_count"].isNull() ? 0 : row["like_count"].as<int>();
    item["commentCount"] =
        row["comment_count"].isNull() ? 0 : row["comment_count"].as<int>();
    item["shareCount"] =
        row["share_count"].isNull() ? 0 : row["share_count"].as<int>();
    recent.append(item);
  }

  Json::Value blocked(Json::arrayValue);
  for (const auto& row : blocked_rows) {
    blocked.append(row["blocked_id"].as<std::string>());
  }

  Json::Value muted(Json::arrayValue);
  for (const auto& row : muted_rows) {
    muted.append(row["phrase"].as<std::string>());
  }

  Json::Value payload;
  payload["generatedAt"] = NowIsoString();
  payload["user"] = user;
  payload["settings"] = settings_snapshot["settings"];
  payload["stats"] = stats;
  payload["recentPosts"] = recent;
  payload["blockedAccounts"] = blocked;
  payload["mutedWords"] = muted;

  const std::string payload_json = ToJsonString(payload);
  const auto rows = db_->execSqlSync(
      "INSERT INTO user_data_exports "
      "(user_id, status, format, payload, created_at, completed_at) "
      "VALUES (?, 'ready', 'json', ?::jsonb, NOW(), NOW()) "
      "RETURNING id, status, format, payload::text AS payload, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(completed_at at time zone 'utc', ?) AS completed_at",
      user_id,
      payload_json,
      kTimestampFormat,
      kTimestampFormat);

  Json::Value export_item;
  if (!rows.empty()) {
    const auto& row = rows.front();
    export_item["id"] = row["id"].as<std::string>();
    export_item["status"] = row["status"].as<std::string>();
    export_item["format"] = row["format"].as<std::string>();
    export_item["payload"] =
        ParseJsonText(row["payload"].as<std::string>(), payload);
    export_item["createdAt"] = row["created_at"].as<std::string>();
    export_item["completedAt"] = row["completed_at"].as<std::string>();
  } else {
    export_item["id"] = "";
    export_item["status"] = "ready";
    export_item["format"] = "json";
    export_item["payload"] = payload;
    export_item["createdAt"] = NowIsoString();
    export_item["completedAt"] = NowIsoString();
  }

  Json::Value response;
  response["export"] = export_item;
  return response;
}

Json::Value UsersService::GetLatestDataExport(const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT id, status, format, payload::text AS payload, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "to_char(completed_at at time zone 'utc', ?) AS completed_at "
      "FROM user_data_exports "
      "WHERE user_id = ? "
      "ORDER BY created_at DESC "
      "LIMIT 1",
      kTimestampFormat,
      kTimestampFormat,
      user_id);

  Json::Value response;
  if (rows.empty()) {
    response["export"] = Json::nullValue;
    return response;
  }

  const auto& row = rows.front();
  Json::Value export_item;
  export_item["id"] = row["id"].as<std::string>();
  export_item["status"] = row["status"].as<std::string>();
  export_item["format"] = row["format"].as<std::string>();
  export_item["payload"] =
      row["payload"].isNull()
          ? Json::Value(Json::objectValue)
          : ParseJsonText(row["payload"].as<std::string>(),
                          Json::Value(Json::objectValue));
  export_item["createdAt"] = row["created_at"].as<std::string>();
  export_item["completedAt"] =
      row["completed_at"].isNull()
          ? Json::nullValue
          : Json::Value(row["completed_at"].as<std::string>());

  response["export"] = export_item;
  return response;
}

Json::Value UsersService::DeleteAccount(const std::string& user_id) {
  const auto rows = db_->execSqlSync(
      "DELETE FROM users WHERE id = ? RETURNING id", user_id);

  if (rows.empty()) {
    throw UsersError(drogon::k404NotFound, "User not found");
  }

  Json::Value response;
  response["deleted"] = true;
  return response;
}

void UsersService::EnsureNotBlocked(const std::string& user_id,
                                    const std::string& target_user_id) {
  const auto rows = db_->execSqlSync(
      "SELECT id FROM user_blocks WHERE "
      "(blocker_id = ? AND blocked_id = ?) "
      "OR (blocker_id = ? AND blocked_id = ?) "
      "LIMIT 1",
      user_id,
      target_user_id,
      target_user_id,
      user_id);

  if (!rows.empty()) {
    throw UsersError(drogon::k400BadRequest, "User is blocked");
  }
}

void UsersService::NotifyFollow(const std::string& follower_id,
                                const std::string& following_id) {
  try {
    const auto rows = db_->execSqlSync(
        "SELECT id, username, display_name FROM users WHERE id = ? LIMIT 1",
        follower_id);
    if (rows.empty()) {
      return;
    }

    const auto& row = rows.front();
    std::string name = row["username"].as<std::string>();
    if (!row["display_name"].isNull()) {
      name = row["display_name"].as<std::string>();
    }

    NotificationsService notifications(db_);
    NotificationInput input;
    input.user_id = following_id;
    input.actor_id = follower_id;
    input.type = "follow";
    input.title = "New follower";
    input.body = name + " started following you";
    input.data = Json::Value(Json::objectValue);
    input.push = true;
    notifications.CreateNotification(input);
  } catch (const std::exception&) {
  }
}

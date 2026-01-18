#include "modules/feed/feed_service.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cmath>
#include <ctime>
#include <iomanip>
#include <mutex>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include <drogon/HttpClient.h>
#include <trantor/net/EventLoopThread.h>

#include "app_state.h"
#include "modules/notifications/notifications_service.h"
#include "realtime/ws_hub.h"

namespace {

constexpr int kMaxFeedLimit = 50;
constexpr int kMaxFeedCandidates = 200;
constexpr int kInterestDecayHours = 720;
constexpr double kMaxInterestScore = 6.0;
constexpr double kInterestCategoryMultiplier = 1.5;
constexpr int kMaxCategoriesPerPost = 3;
constexpr int kCategoryScoreThreshold = 2;
constexpr int kMaxTagsPerPost = 12;
constexpr double kInterestWeightLike = 1.0;
constexpr double kInterestWeightComment = 2.0;
constexpr double kInterestWeightShare = 3.0;
constexpr const char* kFeedExperimentKey = "feed_algo_v1";
constexpr double kEngagementEngineTimeoutSec = 1.4;
constexpr double kExperimentEngineTimeoutSec = 0.8;
constexpr double kDecisionEngineTimeoutSec = 1.6;
constexpr double kModerationTimeoutSec = 1.2;
constexpr double kTrustSafetyTimeoutSec = 1.2;
constexpr double kShadowTimeoutSec = 0.9;
constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

struct SafetySignals {
  double author_reputation = 0.5;
  double safety_score = 1.0;
  double negative_feedback = 0.0;
  bool is_sensitive = false;
  double quality_score = 0.7;
};

struct TrustSafetyResult {
  double trust_score = 0.5;
  double spam_score = 0.0;
  bool shadow_ban = false;
};

struct ParsedUrl {
  std::string base;
  std::string path;
};

const std::vector<std::pair<std::string, std::vector<std::string>>>
    kCategoryKeywords = {
        {"news",
         {"news", "headline", "breaking", "report", "update", "press"}},
        {"sports",
         {"sports", "football", "soccer", "cricket", "nba", "nfl", "f1",
          "tennis", "match", "goal"}},
        {"tech",
         {"tech", "technology", "ai", "android", "ios", "software",
          "coding", "developer", "startup", "gadget"}},
        {"music",
         {"music", "song", "album", "spotify", "concert", "guitar",
          "singer", "rapper"}},
        {"movies",
         {"movie", "film", "cinema", "trailer", "netflix", "actor",
          "actress"}},
        {"gaming",
         {"game", "gaming", "ps5", "xbox", "steam", "esports", "fortnite",
          "valorant", "pubg", "minecraft"}},
        {"fashion",
         {"fashion", "style", "outfit", "streetwear", "design", "luxury",
          "model"}},
        {"travel",
         {"travel", "trip", "flight", "hotel", "tour", "vacation", "beach",
          "mountain"}},
        {"education",
         {"education", "study", "learning", "school", "college",
          "university", "course", "exam", "tutorial"}},
        {"business",
         {"business", "startup", "market", "finance", "stock", "crypto",
          "economy", "sales", "product"}},
        {"fitness",
         {"fitness", "workout", "gym", "training", "yoga", "run", "running",
          "health"}},
        {"food",
         {"food", "recipe", "cook", "cooking", "meal", "restaurant",
          "coffee", "tea", "dessert"}},
        {"politics",
         {"politics", "election", "government", "policy", "parliament",
          "vote", "president", "minister"}},
        {"art",
         {"art", "design", "painting", "illustration", "sketch", "creative",
          "gallery"}},
        {"science",
         {"science", "research", "space", "nasa", "physics", "chemistry",
          "biology", "lab"}},
};

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

int64_t NowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

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

std::string ToLowerCopy(const std::string& value) {
  std::string out = value;
  std::transform(out.begin(), out.end(), out.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return out;
}

std::vector<std::string> ExtractMentions(const std::string& body) {
  static const std::regex pattern(R"((?:^|\s)@([a-zA-Z0-9_]{3,32}))");
  std::unordered_set<std::string> matches;
  auto begin = std::sregex_iterator(body.begin(), body.end(), pattern);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) {
    std::string name = (*it)[1].str();
    std::transform(name.begin(), name.end(), name.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    matches.insert(name);
  }
  return std::vector<std::string>(matches.begin(), matches.end());
}

std::vector<std::string> ExtractHashtags(const std::string& body) {
  static const std::regex pattern(R"((?:^|\s)#([a-zA-Z0-9_]{2,32}))");
  std::unordered_set<std::string> matches;
  auto begin = std::sregex_iterator(body.begin(), body.end(), pattern);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) {
    std::string tag = (*it)[1].str();
    std::transform(tag.begin(), tag.end(), tag.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    matches.insert(tag);
  }
  return std::vector<std::string>(matches.begin(), matches.end());
}

Json::Value VectorToJsonArray(const std::vector<std::string>& values) {
  Json::Value arr(Json::arrayValue);
  for (const auto& value : values) {
    arr.append(value);
  }
  return arr;
}

std::vector<std::string> ParseStringArrayField(const drogon::orm::Field& field) {
  if (field.isNull()) {
    return {};
  }
  Json::Value arr = ParseJsonText(field.as<std::string>(),
                                  Json::Value(Json::arrayValue));
  std::vector<std::string> values;
  if (!arr.isArray()) {
    return values;
  }
  values.reserve(arr.size());
  for (const auto& item : arr) {
    if (item.isString()) {
      values.push_back(item.asString());
    } else if (item.isNumeric()) {
      values.push_back(std::to_string(item.asDouble()));
    }
  }
  return values;
}

std::vector<std::string> LoadMutedPhrases(drogon::orm::DbClientPtr db,
                                          const std::string& user_id) {
  const auto rows = db::ExecSqlSync(db, 
      "SELECT phrase FROM user_muted_words WHERE user_id = ?",
      user_id);
  std::vector<std::string> phrases;
  phrases.reserve(rows.size());
  for (const auto& row : rows) {
    std::string phrase = row["phrase"].as<std::string>();
    std::transform(phrase.begin(), phrase.end(), phrase.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    if (!phrase.empty()) {
      phrases.push_back(std::move(phrase));
    }
  }
  return phrases;
}

Json::Value MapFeedRow(const drogon::orm::Row& row) {
  Json::Value item;
  item["id"] = row["id"].as<std::string>();
  item["body"] = row["body"].as<std::string>();
  item["createdAt"] = row["created_at"].as<std::string>();
  item["likeCount"] = row["like_count"].as<int>();
  item["commentCount"] = row["comment_count"].as<int>();
  item["shareCount"] = row["share_count"].as<int>();
  item["liked"] = row["liked"].isNull() ? false : row["liked"].as<bool>();
  item["followed"] =
      row["followed"].isNull() ? false : row["followed"].as<bool>();

  const std::string mentions_text =
      row["mentions"].isNull() ? "[]" : row["mentions"].as<std::string>();
  const std::string hashtags_text =
      row["hashtags"].isNull() ? "[]" : row["hashtags"].as<std::string>();
  item["mentions"] =
      ParseJsonText(mentions_text, Json::Value(Json::arrayValue));
  item["hashtags"] =
      ParseJsonText(hashtags_text, Json::Value(Json::arrayValue));

  if (!row["relationship"].isNull()) {
    item["relationship"] = row["relationship"].as<std::string>();
  } else if (item["followed"].asBool()) {
    item["relationship"] = "following";
  } else {
    item["relationship"] = "other";
  }

  Json::Value author;
  author["id"] = row["author_id"].as<std::string>();
  author["username"] = row["author_username"].as<std::string>();
  if (row["author_display_name"].isNull()) {
    author["displayName"] = author["username"];
  } else {
    author["displayName"] = row["author_display_name"].as<std::string>();
  }
  item["author"] = author;
  return item;
}

Json::Value FilterMuted(const Json::Value& items,
                        const std::vector<std::string>& muted_phrases) {
  if (muted_phrases.empty()) {
    return items;
  }

  Json::Value filtered(Json::arrayValue);
  for (const auto& item : items) {
    const std::string body =
        item.isMember("body") ? item["body"].asString() : "";
    std::string lower = body;
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    bool muted = false;
    for (const auto& phrase : muted_phrases) {
      if (!phrase.empty() && lower.find(phrase) != std::string::npos) {
        muted = true;
        break;
      }
    }
    if (!muted) {
      filtered.append(item);
    }
  }
  return filtered;
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

double Clamp(double value, double min_value = 0.0, double max_value = 1.0) {
  if (value < min_value) {
    return min_value;
  }
  if (value > max_value) {
    return max_value;
  }
  return value;
}

int CountLinks(const std::string& body) {
  static const std::regex pattern(R"(https?:\/\/|www\.)",
                                  std::regex_constants::icase);
  return static_cast<int>(
      std::distance(std::sregex_iterator(body.begin(), body.end(), pattern),
                    std::sregex_iterator()));
}

double EstimateQualityScore(const std::string& body,
                            const std::vector<std::string>& hashtags,
                            const std::vector<std::string>& mentions,
                            int link_count) {
  const size_t length = body.size();
  double score = 0.7;
  if (length >= 30 && length <= 220) {
    score = 1.0;
  } else if (length < 30) {
    score = 0.82;
  } else if (length <= 420) {
    score = 0.9;
  } else {
    score = 0.78;
  }

  score -= std::min(static_cast<double>(hashtags.size()) * 0.05, 0.35);
  score -= std::min(static_cast<double>(mentions.size()) * 0.07, 0.35);
  score -= std::min(static_cast<double>(link_count) * 0.1, 0.3);

  return Clamp(score, 0.2, 1.0);
}

Json::Value NormalizeMetadata(const Json::Value& metadata) {
  if (metadata.isNull()) {
    return Json::Value(Json::objectValue);
  }
  if (metadata.isObject()) {
    return metadata;
  }
  if (metadata.isString()) {
    return ParseJsonText(metadata.asString(), Json::Value(Json::objectValue));
  }
  return Json::Value(Json::objectValue);
}

std::vector<std::string> NormalizeTagsFromMetadata(const Json::Value& metadata) {
  const Json::Value meta = NormalizeMetadata(metadata);
  std::unordered_set<std::string> unique;
  if (meta.isMember("hashtags") && meta["hashtags"].isArray()) {
    for (const auto& tag : meta["hashtags"]) {
      std::string value = Trim(ToLowerCopy(tag.asString()));
      if (!value.empty()) {
        unique.insert(value);
      }
    }
  }

  std::vector<std::string> tags;
  tags.reserve(unique.size());
  for (const auto& tag : unique) {
    tags.push_back(tag);
  }
  if (tags.size() > static_cast<size_t>(kMaxTagsPerPost)) {
    tags.resize(kMaxTagsPerPost);
  }
  return tags;
}

std::vector<std::string> NormalizeCategoriesFromMetadata(
    const Json::Value& metadata) {
  const Json::Value meta = NormalizeMetadata(metadata);
  std::unordered_set<std::string> unique;
  if (meta.isMember("categories") && meta["categories"].isArray()) {
    for (const auto& cat : meta["categories"]) {
      std::string value = Trim(ToLowerCopy(cat.asString()));
      if (!value.empty()) {
        unique.insert(value);
      }
    }
  }

  std::vector<std::string> categories;
  categories.reserve(unique.size());
  for (const auto& cat : unique) {
    categories.push_back(cat);
  }
  if (categories.size() > static_cast<size_t>(kMaxCategoriesPerPost)) {
    categories.resize(kMaxCategoriesPerPost);
  }
  return categories;
}

std::vector<std::string> ClassifyPostCategories(
    const std::string& body,
    const std::vector<std::string>& hashtags) {
  if (body.empty() && hashtags.empty()) {
    return {};
  }

  std::unordered_set<std::string> words;
  static const std::regex word_pattern(R"([a-z0-9]+)");
  auto begin = std::sregex_iterator(body.begin(), body.end(), word_pattern);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) {
    words.insert(ToLowerCopy(it->str()));
  }

  std::unordered_set<std::string> tags;
  for (const auto& tag : hashtags) {
    tags.insert(ToLowerCopy(tag));
  }

  std::vector<std::pair<std::string, int>> scored;
  for (const auto& entry : kCategoryKeywords) {
    int score = 0;
    if (tags.count(entry.first)) {
      score += 3;
    }
    if (words.count(entry.first)) {
      score += 2;
    }

    for (const auto& keyword : entry.second) {
      if (tags.count(keyword)) {
        score += 3;
      }
      if (words.count(keyword)) {
        score += 1;
      }
    }

    if (score >= kCategoryScoreThreshold) {
      scored.emplace_back(entry.first, score);
    }
  }

  std::sort(scored.begin(), scored.end(),
            [](const auto& a, const auto& b) { return a.second > b.second; });

  std::vector<std::string> categories;
  for (const auto& entry : scored) {
    if (categories.size() >= static_cast<size_t>(kMaxCategoriesPerPost)) {
      break;
    }
    categories.push_back(entry.first);
  }

  return categories;
}

SafetySignals ExtractSafetySignals(const Json::Value& metadata,
                                   double fallback_quality) {
  const Json::Value meta = NormalizeMetadata(metadata);
  const Json::Value trust =
      meta.isMember("trust") && meta["trust"].isObject()
          ? meta["trust"]
          : Json::Value(Json::objectValue);
  const Json::Value moderation =
      meta.isMember("moderation") && meta["moderation"].isObject()
          ? meta["moderation"]
          : Json::Value(Json::objectValue);

  const double trust_score =
      trust.isMember("trustScore") && trust["trustScore"].isNumeric()
          ? trust["trustScore"].asDouble()
          : 0.5;
  const double spam_score =
      trust.isMember("spamScore") && trust["spamScore"].isNumeric()
          ? trust["spamScore"].asDouble()
          : 0.0;

  const std::string action = moderation.isMember("action")
                                 ? moderation["action"].asString()
                                 : "allow";
  double moderation_penalty = 0.0;
  if (action == "review") {
    moderation_penalty = 0.15;
  } else if (action == "block") {
    moderation_penalty = 0.5;
  }

  SafetySignals signals;
  signals.author_reputation = Clamp(trust_score);
  signals.safety_score = Clamp(1.0 - Clamp(spam_score));
  signals.negative_feedback = Clamp(spam_score + moderation_penalty);
  signals.is_sensitive = (action == "review");
  signals.quality_score =
      meta.isMember("qualityScore") && meta["qualityScore"].isNumeric()
          ? Clamp(meta["qualityScore"].asDouble())
          : fallback_quality;
  return signals;
}

std::optional<std::chrono::system_clock::time_point> ParseIsoTimestamp(
    const std::string& value) {
  if (value.size() < 19) {
    return std::nullopt;
  }

  try {
    const int year = std::stoi(value.substr(0, 4));
    const int month = std::stoi(value.substr(5, 2));
    const int day = std::stoi(value.substr(8, 2));
    const int hour = std::stoi(value.substr(11, 2));
    const int minute = std::stoi(value.substr(14, 2));
    const int second = std::stoi(value.substr(17, 2));
    int millis = 0;

    if (value.size() > 19 && value[19] == '.') {
      size_t ms_len = 0;
      size_t pos = 20;
      while (pos + ms_len < value.size() &&
             std::isdigit(static_cast<unsigned char>(value[pos + ms_len]))) {
        ++ms_len;
      }
      if (ms_len > 0) {
        std::string ms_text = value.substr(pos, std::min(ms_len, size_t(3)));
        millis = std::stoi(ms_text);
        if (ms_len == 1) {
          millis *= 100;
        } else if (ms_len == 2) {
          millis *= 10;
        }
      }
    }

    std::tm utc = {};
    utc.tm_year = year - 1900;
    utc.tm_mon = month - 1;
    utc.tm_mday = day;
    utc.tm_hour = hour;
    utc.tm_min = minute;
    utc.tm_sec = second;

#ifdef _WIN32
    std::time_t time = _mkgmtime(&utc);
#else
    std::time_t time = timegm(&utc);
#endif
    if (time < 0) {
      return std::nullopt;
    }

    auto tp = std::chrono::system_clock::from_time_t(time);
    tp += std::chrono::milliseconds(millis);
    return tp;
  } catch (const std::exception&) {
    return std::nullopt;
  }
}

double AgeHours(const std::string& created_at,
                std::chrono::system_clock::time_point now) {
  const auto parsed = ParseIsoTimestamp(created_at);
  if (!parsed.has_value()) {
    return 0.0;
  }
  auto diff = now - *parsed;
  if (diff.count() < 0) {
    return 0.0;
  }
  return std::chrono::duration_cast<std::chrono::duration<double, std::ratio<3600>>>(
             diff)
      .count();
}

trantor::EventLoop* GetHttpLoop() {
  static trantor::EventLoopThread loop_thread("feed-http-loop");
  static std::once_flag once;
  std::call_once(once, [&]() { loop_thread.run(); });
  return loop_thread.getLoop();
}

bool ParseUrl(const std::string& url, ParsedUrl& out) {
  const auto scheme_pos = url.find("://");
  if (scheme_pos == std::string::npos) {
    return false;
  }
  const auto path_pos = url.find('/', scheme_pos + 3);
  if (path_pos == std::string::npos) {
    out.base = url;
    out.path = "/";
    return true;
  }
  out.base = url.substr(0, path_pos);
  out.path = url.substr(path_pos);
  if (out.path.empty()) {
    out.path = "/";
  }
  return true;
}

std::string TrimTrailingSlash(const std::string& url) {
  if (!url.empty() && url.back() == '/') {
    return url.substr(0, url.size() - 1);
  }
  return url;
}

std::optional<Json::Value> PostJson(const std::string& url,
                                    const Json::Value& payload,
                                    double timeout_sec) {
  ParsedUrl parsed;
  if (!ParseUrl(url, parsed)) {
    return std::nullopt;
  }

  auto loop = GetHttpLoop();
  if (!loop) {
    return std::nullopt;
  }

  auto client = drogon::HttpClient::newHttpClient(parsed.base, loop);
  auto req = drogon::HttpRequest::newHttpJsonRequest(payload);
  req->setMethod(drogon::Post);
  req->setPath(parsed.path);

  const auto result = client->sendRequest(req, timeout_sec);
  if (result.first != drogon::ReqResult::Ok || !result.second) {
    return std::nullopt;
  }

  const auto status = result.second->getStatusCode();
  if (status < drogon::k200OK || status >= drogon::k300MultipleChoices) {
    return std::nullopt;
  }

  const auto json = result.second->getJsonObject();
  if (!json) {
    return std::nullopt;
  }

  return *json;
}

void PublishFeedEvent(const Json::Value& payload) {
  const auto& redis = AppState::Instance().GetRedis();
  if (redis) {
    Json::StreamWriterBuilder builder;
    builder["indentation"] = "";
    const std::string message = Json::writeString(builder, payload);
    const std::string channel = "ws:" + FeedTopic();
    try {
      redis->execCommandSync<int>(
          [](const drogon::nosql::RedisResult&) { return 0; },
          "PUBLISH %s %s",
          channel.c_str(),
          message.c_str());
      return;
    } catch (const std::exception&) {
    }
  }

  WsHub::Instance().PublishToFeed(payload);
}

Json::Value CheckModeration(const Config& cfg,
                            const std::string& content,
                            const std::string& user_id,
                            const std::optional<std::string>& content_id) {
  Json::Value fallback(Json::objectValue);
  fallback["action"] = "allow";
  fallback["reasons"] = Json::Value(Json::arrayValue);
  fallback["confidence"] = 0.0;

  if (cfg.moderation_engine_url.empty()) {
    return fallback;
  }

  Json::Value payload(Json::objectValue);
  payload["content"] = content;
  if (!user_id.empty()) {
    payload["userId"] = user_id;
  }
  if (content_id && !content_id->empty()) {
    payload["contentId"] = *content_id;
  }

  const std::string url = TrimTrailingSlash(cfg.moderation_engine_url) +
                          "/moderation/check";
  const auto response = PostJson(url, payload, kModerationTimeoutSec);
  if (!response.has_value()) {
    return fallback;
  }

  Json::Value result = fallback;
  if (response->isMember("action") && (*response)["action"].isString()) {
    result["action"] = (*response)["action"].asString();
  }
  if (response->isMember("reasons") && (*response)["reasons"].isArray()) {
    result["reasons"] = (*response)["reasons"];
  }
  if (response->isMember("confidence") && (*response)["confidence"].isNumeric()) {
    result["confidence"] = (*response)["confidence"].asDouble();
  }
  return result;
}

TrustSafetyResult EvaluateTrustSafety(const Config& cfg,
                                      double account_age_days,
                                      bool email_verified,
                                      bool phone_verified,
                                      double quality_score,
                                      int link_count,
                                      int mention_count) {
  TrustSafetyResult result;
  if (cfg.trust_safety_engine_url.empty()) {
    return result;
  }

  const std::string base = TrimTrailingSlash(cfg.trust_safety_engine_url);

  Json::Value trust_payload(Json::objectValue);
  trust_payload["accountAgeDays"] = account_age_days;
  trust_payload["reportCount"] = 0;
  trust_payload["blockCount"] = 0;
  trust_payload["emailVerified"] = email_verified;
  trust_payload["phoneVerified"] = phone_verified;
  trust_payload["qualityScore"] = quality_score;

  const auto trust_resp =
      PostJson(base + "/trust/score", trust_payload, kTrustSafetyTimeoutSec);
  if (trust_resp.has_value() && trust_resp->isMember("trust_score")) {
    result.trust_score = Clamp((*trust_resp)["trust_score"].asDouble());
  }

  Json::Value spam_payload(Json::objectValue);
  spam_payload["linkCount"] = link_count;
  spam_payload["mentionCount"] = mention_count;
  spam_payload["duplicateRatio"] = 0;
  spam_payload["postRatePerHour"] = 0;

  const auto spam_resp =
      PostJson(base + "/spam/score", spam_payload, kTrustSafetyTimeoutSec);
  if (spam_resp.has_value() && spam_resp->isMember("spam_score")) {
    result.spam_score = Clamp((*spam_resp)["spam_score"].asDouble());
  }

  Json::Value shadow_payload(Json::objectValue);
  shadow_payload["trustScore"] = result.trust_score;
  shadow_payload["spamScore"] = result.spam_score;

  const auto shadow_resp =
      PostJson(base + "/shadow/evaluate", shadow_payload, kShadowTimeoutSec);
  if (shadow_resp.has_value() && shadow_resp->isMember("shadow_ban")) {
    result.shadow_ban = (*shadow_resp)["shadow_ban"].asBool();
  }

  return result;
}

std::optional<std::string> FetchExperimentVariant(const Config& cfg,
                                                  const std::string& user_id) {
  if (cfg.experimentation_engine_url.empty()) {
    return std::nullopt;
  }

  Json::Value variants(Json::objectValue);
  variants["control"] = 0.45;
  variants["social"] = 0.25;
  variants["relevance"] = 0.2;
  variants["explore"] = 0.1;

  Json::Value payload(Json::objectValue);
  payload["user_id"] = user_id;
  payload["experiment_key"] = kFeedExperimentKey;
  payload["variants"] = variants;
  payload["salt"] = "feed";

  const std::string url = TrimTrailingSlash(cfg.experimentation_engine_url) +
                          "/experiments/assign";
  const auto response = PostJson(url, payload, kExperimentEngineTimeoutSec);
  if (!response.has_value()) {
    return std::nullopt;
  }
  if (response->isMember("variant") && (*response)["variant"].isString()) {
    return (*response)["variant"].asString();
  }
  return std::nullopt;
}

std::optional<Json::Value> FetchEngagementScores(
    const Config& cfg,
    const std::string& user_id,
    const Json::Value& candidates) {
  if (cfg.engagement_engine_url.empty()) {
    return std::nullopt;
  }
  if (!candidates.isArray() || candidates.empty()) {
    return std::nullopt;
  }

  Json::Value payload(Json::objectValue);
  payload["user_id"] = user_id;
  payload["candidates"] = candidates;

  const std::string url = TrimTrailingSlash(cfg.engagement_engine_url) +
                          "/engagement/score";
  const auto response = PostJson(url, payload, kEngagementEngineTimeoutSec);
  if (!response.has_value()) {
    return std::nullopt;
  }
  if (!response->isMember("predictions") ||
      !(*response)["predictions"].isArray()) {
    return std::nullopt;
  }
  return (*response)["predictions"];
}

std::optional<std::vector<std::string>> RankWithDecisionEngine(
    const Config& cfg,
    const std::string& user_id,
    int limit,
    const std::string& mode,
    const Json::Value& candidates,
    const std::optional<std::string>& variant) {
  if (cfg.decision_engine_url.empty()) {
    return std::nullopt;
  }
  if (!candidates.isArray() || candidates.empty()) {
    return std::vector<std::string>{};
  }

  Json::Value payload(Json::objectValue);
  payload["user_id"] = user_id;
  payload["limit"] = limit;
  payload["mode"] = mode;
  payload["candidates"] = candidates;
  if (variant && !variant->empty()) {
    payload["variant"] = *variant;
  }

  const std::string url = TrimTrailingSlash(cfg.decision_engine_url) +
                          "/rank/feed";
  const auto response = PostJson(url, payload, kDecisionEngineTimeoutSec);
  if (!response.has_value()) {
    return std::nullopt;
  }
  if (!response->isMember("ordered_ids") ||
      !(*response)["ordered_ids"].isArray()) {
    return std::nullopt;
  }

  std::vector<std::string> ordered_ids;
  for (const auto& id : (*response)["ordered_ids"]) {
    if (id.isString()) {
      ordered_ids.push_back(id.asString());
    } else if (id.isNumeric()) {
      ordered_ids.push_back(std::to_string(id.asInt64()));
    }
  }
  return ordered_ids;
}

void UpdateInterestFromPost(drogon::orm::DbClientPtr db,
                            const std::string& user_id,
                            const std::string& post_id,
                            double delta) {
  if (!db || delta == 0.0) {
    return;
  }

  const auto rows = db::ExecSqlSync(db, 
      "SELECT metadata::text AS metadata, body FROM feed_posts WHERE id = ? "
      "LIMIT 1",
      post_id);
  if (rows.empty()) {
    return;
  }

  const auto& row = rows.front();
  const std::string metadata_text =
      row["metadata"].isNull() ? "{}" : row["metadata"].as<std::string>();
  const Json::Value metadata =
      ParseJsonText(metadata_text, Json::Value(Json::objectValue));
  const std::string body = row["body"].isNull() ? "" : row["body"].as<std::string>();

  const auto tags = NormalizeTagsFromMetadata(metadata);
  auto categories = NormalizeCategoriesFromMetadata(metadata);
  if (categories.empty()) {
    categories = ClassifyPostCategories(body, tags);
  }

  if (tags.empty() && categories.empty()) {
    return;
  }

  for (const auto& tag : tags) {
    db::ExecSqlSync(db, 
        "INSERT INTO user_interest_profiles (user_id, tag, score, updated_at) "
        "VALUES (?, ?, ?, NOW()) "
        "ON CONFLICT (user_id, tag) DO UPDATE SET "
        "score = GREATEST(user_interest_profiles.score + ?, 0), "
        "updated_at = NOW()",
        user_id,
        tag,
        delta,
        delta);
  }

  for (const auto& category : categories) {
    const double adjusted = delta * kInterestCategoryMultiplier;
    const std::string tag = "cat:" + category;
    db::ExecSqlSync(db, 
        "INSERT INTO user_interest_profiles (user_id, tag, score, updated_at) "
        "VALUES (?, ?, ?, NOW()) "
        "ON CONFLICT (user_id, tag) DO UPDATE SET "
        "score = GREATEST(user_interest_profiles.score + ?, 0), "
        "updated_at = NOW()",
        user_id,
        tag,
        adjusted,
        adjusted);
  }
}

std::unordered_map<std::string, double> FetchInterestScores(
    drogon::orm::DbClientPtr db,
    const std::string& user_id,
    const std::vector<std::string>& tags) {
  std::unordered_map<std::string, double> scores;
  if (!db || tags.empty()) {
    return scores;
  }

  std::unordered_set<std::string> tag_set;
  for (const auto& tag : tags) {
    if (!tag.empty()) {
      tag_set.insert(tag);
    }
  }
  if (tag_set.empty()) {
    return scores;
  }

  const std::string query =
      "SELECT tag, (score * EXP(-GREATEST(EXTRACT(EPOCH FROM (now() - "
      "updated_at)) / 3600.0, 0) / " +
      std::to_string(kInterestDecayHours) +
      ")) AS score FROM user_interest_profiles WHERE user_id = ?";
  const auto rows = db::ExecSqlSync(db, query, user_id);

  for (const auto& row : rows) {
    if (row["tag"].isNull() || row["score"].isNull()) {
      continue;
    }
    const std::string tag = row["tag"].as<std::string>();
    if (!tag_set.count(tag)) {
      continue;
    }
    const double score = row["score"].as<double>();
    if (!std::isnan(score)) {
      scores[tag] = score;
    }
  }

  return scores;
}

void NotifyMentions(drogon::orm::DbClientPtr db,
                    const std::string& author_id,
                    const std::vector<std::string>& mentions,
                    const std::string& post_id) {
  if (!db || mentions.empty()) {
    return;
  }

  std::unordered_set<std::string> unique;
  for (const auto& mention : mentions) {
    std::string value = Trim(ToLowerCopy(mention));
    if (!value.empty()) {
      unique.insert(value);
    }
  }

  std::vector<std::string> names;
  names.reserve(unique.size());
  for (const auto& name : unique) {
    if (names.size() >= 20) {
      break;
    }
    names.push_back(name);
  }

  if (names.empty()) {
    return;
  }

  std::string in_clause;
  for (size_t i = 0; i < names.size(); ++i) {
    if (i > 0) {
      in_clause += ",";
    }
    in_clause += "'" + names[i] + "'";
  }

  const std::string query =
      "SELECT id, username, display_name FROM users WHERE username IN (" +
      in_clause + ")";
  const auto rows = db::ExecSqlSync(db, query);
  if (rows.empty()) {
    return;
  }

  std::string author_name = "Someone";
  const auto author_rows = db::ExecSqlSync(db, 
      "SELECT id, username, display_name FROM users WHERE id = ? LIMIT 1",
      author_id);
  if (!author_rows.empty()) {
    const auto& row = author_rows.front();
    if (!row["display_name"].isNull()) {
      author_name = row["display_name"].as<std::string>();
    } else if (!row["username"].isNull()) {
      author_name = row["username"].as<std::string>();
    }
  }

  NotificationsService notifications(db);
  for (const auto& row : rows) {
    if (row["id"].isNull()) {
      continue;
    }
    const std::string user_id = row["id"].as<std::string>();
    if (user_id == author_id) {
      continue;
    }

    NotificationInput notif;
    notif.user_id = user_id;
    notif.actor_id = author_id;
    notif.type = "mention";
    notif.title = "Mentioned you";
    notif.body = author_name + " mentioned you in a post";
    notif.data = Json::Value(Json::objectValue);
    notif.data["postId"] = post_id;
    notif.push = true;
    try {
      notifications.CreateNotification(notif);
    } catch (const std::exception&) {
    }
  }
}

Json::Value ListFollowingFeed(drogon::orm::DbClientPtr db,
                              const std::string& user_id,
                              const std::optional<int>& limit,
                              const std::optional<std::string>& before) {
  const int limit_value = ClampLimit(limit, 20, 1, kMaxFeedLimit);
  const bool use_before = before.has_value();

  std::string query =
      "SELECT "
      "p.id AS id, "
      "p.body AS body, "
      "to_char(p.created_at at time zone 'utc', ?) AS created_at, "
      "p.like_count AS like_count, "
      "p.comment_count AS comment_count, "
      "p.share_count AS share_count, "
      "COALESCE(p.metadata->'mentions', '[]'::jsonb) AS mentions, "
      "COALESCE(p.metadata->'hashtags', '[]'::jsonb) AS hashtags, "
      "u.id AS author_id, "
      "u.username AS author_username, "
      "u.display_name AS author_display_name, "
      "(fl.user_id IS NOT NULL) AS liked, "
      "(f.follower_id IS NOT NULL) AS followed, "
      "CASE "
      "WHEN f.follower_id IS NOT NULL AND f2.follower_id IS NOT NULL THEN 'friend' "
      "WHEN f.follower_id IS NOT NULL THEN 'following' "
      "ELSE 'other' "
      "END AS relationship "
      "FROM feed_posts p "
      "JOIN users u ON u.id = p.author_id "
      "LEFT JOIN feed_likes fl ON fl.post_id = p.id AND fl.user_id = ? "
      "LEFT JOIN follows f ON f.follower_id = ? AND f.following_id = p.author_id "
      "LEFT JOIN follows f2 ON f2.follower_id = p.author_id AND f2.following_id = ? "
      "WHERE 1=1 ";

  if (use_before) {
    query += "AND p.created_at < ?::timestamptz ";
  }

  query +=
      "AND (COALESCE(p.metadata->>'shadowBan', 'false') != 'true' "
      "OR p.author_id = ?) "
      "AND (p.author_id = ? OR f.follower_id IS NOT NULL) "
      "AND NOT EXISTS ("
      "SELECT 1 FROM user_blocks b "
      "WHERE (b.blocker_id = ? AND b.blocked_id = p.author_id) "
      "OR (b.blocker_id = p.author_id AND b.blocked_id = ?)"
      ") "
      "ORDER BY p.created_at DESC LIMIT ?";

  auto rows = use_before
    ? db::ExecSqlSync(db, 
        query,
        kTimestampFormat,
        user_id,
        user_id,
        user_id,
        before.value(),
        user_id,
        user_id,
        user_id,
        user_id,
        limit_value)
    : db::ExecSqlSync(db, 
        query,
        kTimestampFormat,
        user_id,
        user_id,
        user_id,
        user_id,
        user_id,
        user_id,
        user_id,
        limit_value);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    items.append(MapFeedRow(row));
  }

  return items;
}

Json::Value ListForYouFeed(drogon::orm::DbClientPtr db,
                           const std::string& user_id,
                           const std::optional<int>& limit,
                           const std::optional<std::string>& before) {
  const auto& cfg = AppState::Instance().GetConfig();
  const int limit_value = ClampLimit(limit, 20, 1, kMaxFeedLimit);
  const int candidate_limit =
      std::min(limit_value * 5, kMaxFeedCandidates);
  const bool use_before = before.has_value();

  std::string query =
      "WITH affinity AS ("
      "SELECT t.author_id, SUM(t.likes)::int AS likes, "
      "SUM(t.comments)::int AS comments, SUM(t.shares)::int AS shares "
      "FROM ("
      "SELECT p.author_id, COUNT(*)::int AS likes, 0::int AS comments, 0::int AS shares "
      "FROM feed_likes l JOIN feed_posts p ON p.id = l.post_id "
      "WHERE l.user_id = ? GROUP BY p.author_id "
      "UNION ALL "
      "SELECT p.author_id, 0::int AS likes, COUNT(*)::int AS comments, 0::int AS shares "
      "FROM feed_comments c JOIN feed_posts p ON p.id = c.post_id "
      "WHERE c.author_id = ? GROUP BY p.author_id "
      "UNION ALL "
      "SELECT p.author_id, 0::int AS likes, 0::int AS comments, COUNT(*)::int AS shares "
      "FROM feed_shares s JOIN feed_posts p ON p.id = s.post_id "
      "WHERE s.user_id = ? GROUP BY p.author_id"
      ") t GROUP BY t.author_id"
      "), base AS ("
      "SELECT p.id AS id, p.body AS body, "
      "to_char(p.created_at at time zone 'utc', ?) AS created_at, "
      "p.like_count AS like_count, p.comment_count AS comment_count, "
      "p.share_count AS share_count, "
      "COALESCE(p.metadata->'mentions', '[]'::jsonb) AS mentions, "
      "COALESCE(p.metadata->'hashtags', '[]'::jsonb) AS hashtags, "
      "p.metadata AS metadata, "
      "u.id AS author_id, u.username AS author_username, "
      "u.display_name AS author_display_name, "
      "(fl.user_id IS NOT NULL) AS liked, "
      "(f.follower_id IS NOT NULL) AS followed, "
      "(f2.follower_id IS NOT NULL) AS followed_by, "
      "COALESCE(a.likes, 0) AS affinity_likes, "
      "COALESCE(a.comments, 0) AS affinity_comments, "
      "COALESCE(a.shares, 0) AS affinity_shares, "
      "CASE "
      "WHEN f.follower_id IS NOT NULL AND f2.follower_id IS NOT NULL THEN 'friend' "
      "WHEN f.follower_id IS NOT NULL THEN 'following' "
      "WHEN f2.follower_id IS NOT NULL THEN 'followed_by' "
      "ELSE 'other' "
      "END AS relationship "
      "FROM feed_posts p "
      "JOIN users u ON u.id = p.author_id "
      "LEFT JOIN feed_likes fl ON fl.post_id = p.id AND fl.user_id = ? "
      "LEFT JOIN follows f ON f.follower_id = ? AND f.following_id = p.author_id "
      "LEFT JOIN follows f2 ON f2.follower_id = p.author_id AND f2.following_id = ? "
      "LEFT JOIN affinity a ON a.author_id = p.author_id "
      "WHERE 1=1 ";

  if (use_before) {
    query += "AND p.created_at < ?::timestamptz ";
  }

  query +=
      "AND (COALESCE(p.metadata->>'shadowBan', 'false') != 'true' "
      "OR p.author_id = ?) "
      "AND NOT EXISTS ("
      "SELECT 1 FROM user_blocks b "
      "WHERE (b.blocker_id = ? AND b.blocked_id = p.author_id) "
      "OR (b.blocker_id = p.author_id AND b.blocked_id = ?)"
      ")"
      ") SELECT * FROM base ORDER BY created_at DESC LIMIT ?";

  auto rows = use_before
    ? db::ExecSqlSync(db, 
        query,
        user_id,
        user_id,
        user_id,
        kTimestampFormat,
        user_id,
        user_id,
        user_id,
        before.value(),
        user_id,
        user_id,
        user_id,
        candidate_limit)
    : db::ExecSqlSync(db, 
        query,
        user_id,
        user_id,
        user_id,
        kTimestampFormat,
        user_id,
        user_id,
        user_id,
        user_id,
        user_id,
        user_id,
        candidate_limit);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    items.append(MapFeedRow(row));
  }

  if (rows.empty()) {
    return items;
  }

  const auto now = std::chrono::system_clock::now();
  Json::Value engagement_candidates(Json::arrayValue);
  std::unordered_set<std::string> tag_set;

  for (const auto& row : rows) {
    const std::string body = row["body"].as<std::string>();
    const auto hashtags = ParseStringArrayField(row["hashtags"]);
    const auto mentions = ParseStringArrayField(row["mentions"]);
    const std::string created_at = row["created_at"].as<std::string>();

    Json::Value metadata = row["metadata"].isNull()
                               ? Json::Value(Json::objectValue)
                               : ParseJsonText(row["metadata"].as<std::string>(),
                                               Json::Value(Json::objectValue));

    SafetySignals signals = ExtractSafetySignals(
        metadata, EstimateQualityScore(body, hashtags, mentions, CountLinks(body)));

    Json::Value candidate(Json::objectValue);
    candidate["postId"] = row["id"].as<std::string>();
    candidate["createdAt"] = created_at;
    candidate["relationship"] = row["relationship"].as<std::string>();
    candidate["textLength"] = static_cast<int>(body.size());
    candidate["mediaCount"] = 0;
    candidate["hashtagCount"] = static_cast<int>(hashtags.size());
    candidate["mentionCount"] = static_cast<int>(mentions.size());
    candidate["ageHours"] = AgeHours(created_at, now);
    candidate["authorReputation"] = signals.author_reputation;
    Json::Value affinity(Json::objectValue);
    affinity["likes"] = row["affinity_likes"].as<int>();
    affinity["comments"] = row["affinity_comments"].as<int>();
    affinity["shares"] = row["affinity_shares"].as<int>();
    candidate["affinity"] = affinity;
    engagement_candidates.append(candidate);

    for (const auto& tag : hashtags) {
      const std::string trimmed = Trim(ToLowerCopy(tag));
      if (!trimmed.empty()) {
        tag_set.insert(trimmed);
      }
    }

    auto categories = NormalizeCategoriesFromMetadata(metadata);
    if (categories.empty()) {
      categories = ClassifyPostCategories(body, hashtags);
    }
    for (const auto& category : categories) {
      if (!category.empty()) {
        tag_set.insert("cat:" + category);
      }
    }
  }

  std::vector<std::string> tags(tag_set.begin(), tag_set.end());
  const auto variant = FetchExperimentVariant(cfg, user_id);
  const auto engagement_predictions =
      FetchEngagementScores(cfg, user_id, engagement_candidates);
  const auto interest_map = FetchInterestScores(db, user_id, tags);

  std::unordered_map<std::string, double> engagement_map;
  if (engagement_predictions.has_value()) {
    for (const auto& prediction : *engagement_predictions) {
      if (!prediction.isObject()) {
        continue;
      }
      std::string post_id;
      if (prediction.isMember("postId")) {
        post_id = prediction["postId"].asString();
      } else if (prediction.isMember("post_id")) {
        post_id = prediction["post_id"].asString();
      }
      if (post_id.empty()) {
        continue;
      }

      double score = 0.0;
      if (prediction.isMember("engagementScore")) {
        score = prediction["engagementScore"].asDouble();
      } else if (prediction.isMember("engagement_score")) {
        score = prediction["engagement_score"].asDouble();
      }
      engagement_map[post_id] = score;
    }
  }

  Json::Value candidates(Json::arrayValue);
  for (const auto& row : rows) {
    const std::string body = row["body"].as<std::string>();
    const auto hashtags = ParseStringArrayField(row["hashtags"]);
    const auto mentions = ParseStringArrayField(row["mentions"]);
    const std::string created_at = row["created_at"].as<std::string>();
    const std::string post_id = row["id"].as<std::string>();

    Json::Value metadata = row["metadata"].isNull()
                               ? Json::Value(Json::objectValue)
                               : ParseJsonText(row["metadata"].as<std::string>(),
                                               Json::Value(Json::objectValue));

    auto categories = NormalizeCategoriesFromMetadata(metadata);
    if (categories.empty()) {
      categories = ClassifyPostCategories(body, hashtags);
    }

    const int link_count = CountLinks(body);
    const double quality =
        EstimateQualityScore(body, hashtags, mentions, link_count);
    SafetySignals signals = ExtractSafetySignals(metadata, quality);

    double interest_score = 0.0;
    for (const auto& tag : hashtags) {
      const std::string key = ToLowerCopy(tag);
      const auto it = interest_map.find(key);
      if (it != interest_map.end()) {
        interest_score += it->second;
      }
    }
    for (const auto& category : categories) {
      const std::string key = "cat:" + category;
      const auto it = interest_map.find(key);
      if (it != interest_map.end()) {
        interest_score += it->second;
      }
    }
    if (interest_score > kMaxInterestScore) {
      interest_score = kMaxInterestScore;
    }

    Json::Value candidate(Json::objectValue);
    candidate["postId"] = post_id;
    candidate["authorId"] = row["author_id"].as<std::string>();
    candidate["createdAt"] = created_at;
    candidate["likeCount"] = row["like_count"].as<int>();
    candidate["commentCount"] = row["comment_count"].as<int>();
    candidate["shareCount"] = row["share_count"].as<int>();
    candidate["textLength"] = static_cast<int>(body.size());
    candidate["mediaCount"] = 0;
    candidate["relationship"] = row["relationship"].as<std::string>();
    Json::Value affinity(Json::objectValue);
    affinity["likes"] = row["affinity_likes"].as<int>();
    affinity["comments"] = row["affinity_comments"].as<int>();
    affinity["shares"] = row["affinity_shares"].as<int>();
    candidate["affinity"] = affinity;
    candidate["hashtags"] = VectorToJsonArray(hashtags);
    candidate["mentions"] = VectorToJsonArray(mentions);
    candidate["qualityScore"] = signals.quality_score;
    candidate["authorReputation"] = signals.author_reputation;
    candidate["safetyScore"] = signals.safety_score;
    candidate["negativeFeedback"] = signals.negative_feedback;
    candidate["isSensitive"] = signals.is_sensitive;
    auto engagement_it = engagement_map.find(post_id);
    candidate["engagementScore"] =
        engagement_it != engagement_map.end() ? engagement_it->second : 0.0;
    candidate["interestScore"] = interest_score;
    candidates.append(candidate);
  }

  const auto ordered_ids = RankWithDecisionEngine(
      cfg, user_id, limit_value, "for-you", candidates, variant);

  if (!ordered_ids.has_value()) {
    Json::Value trimmed(Json::arrayValue);
    for (Json::ArrayIndex i = 0;
         i < items.size() && i < static_cast<Json::ArrayIndex>(limit_value);
         ++i) {
      trimmed.append(items[i]);
    }
    return trimmed;
  }

  std::unordered_map<std::string, Json::Value> by_id;
  for (const auto& item : items) {
    if (item.isMember("id") && item["id"].isString()) {
      by_id[item["id"].asString()] = item;
    }
  }

  Json::Value ordered(Json::arrayValue);
  std::unordered_set<std::string> seen;
  for (const auto& id : *ordered_ids) {
    auto it = by_id.find(id);
    if (it != by_id.end()) {
      ordered.append(it->second);
      seen.insert(id);
    }
    if (ordered.size() >= static_cast<Json::ArrayIndex>(limit_value)) {
      break;
    }
  }

  if (ordered.size() < static_cast<Json::ArrayIndex>(limit_value)) {
    for (const auto& item : items) {
      if (!item.isMember("id") || !item["id"].isString()) {
        continue;
      }
      const std::string id = item["id"].asString();
      if (seen.count(id)) {
        continue;
      }
      ordered.append(item);
      seen.insert(id);
      if (ordered.size() >= static_cast<Json::ArrayIndex>(limit_value)) {
        break;
      }
    }
  }

  return ordered;
}

}  // namespace

FeedService::FeedService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

Json::Value FeedService::CreatePost(const std::string& user_id,
                                    const std::string& body) {
  const std::string trimmed = Trim(body);
  if (trimmed.empty()) {
    throw FeedError(drogon::k400BadRequest, "Post body required");
  }

  const auto mentions = ExtractMentions(trimmed);
  const auto hashtags = ExtractHashtags(trimmed);
  const auto categories = ClassifyPostCategories(trimmed, hashtags);
  const int link_count = CountLinks(trimmed);
  const double quality_score =
      EstimateQualityScore(trimmed, hashtags, mentions, link_count);

  const auto author_rows = db::ExecSqlSync(db_, 
      "SELECT id, username, display_name, "
      "to_char(created_at at time zone 'utc', ?) AS created_at, "
      "(email_verified_at IS NOT NULL) AS email_verified, "
      "(NULLIF(phone_number, '') IS NOT NULL) AS phone_verified "
      "FROM users WHERE id = ? LIMIT 1",
      kTimestampFormat,
      user_id);
  if (author_rows.empty()) {
    throw FeedError(drogon::k404NotFound, "Author not found");
  }
  const auto& author_row = author_rows.front();

  const std::string created_at = author_row["created_at"].as<std::string>();
  const double account_age_days =
      AgeHours(created_at, std::chrono::system_clock::now()) / 24.0;
  const bool email_verified = author_row["email_verified"].isNull()
                                  ? false
                                  : author_row["email_verified"].as<bool>();
  const bool phone_verified = author_row["phone_verified"].isNull()
                                  ? false
                                  : author_row["phone_verified"].as<bool>();

  const auto& cfg = AppState::Instance().GetConfig();
  const Json::Value moderation =
      CheckModeration(cfg, trimmed, user_id, std::nullopt);
  const std::string moderation_action =
      moderation.isMember("action") && moderation["action"].isString()
          ? moderation["action"].asString()
          : "allow";
  if (moderation_action == "block") {
    throw FeedError(drogon::k400BadRequest, "Post blocked by moderation");
  }

  const TrustSafetyResult trust =
      EvaluateTrustSafety(cfg,
                          account_age_days,
                          email_verified,
                          phone_verified,
                          quality_score,
                          link_count,
                          static_cast<int>(mentions.size()));

  Json::Value metadata(Json::objectValue);
  metadata["mentions"] = VectorToJsonArray(mentions);
  metadata["hashtags"] = VectorToJsonArray(hashtags);
  metadata["categories"] = VectorToJsonArray(categories);
  metadata["moderation"] = moderation;
  Json::Value trust_meta(Json::objectValue);
  trust_meta["trustScore"] = trust.trust_score;
  trust_meta["spamScore"] = trust.spam_score;
  metadata["trust"] = trust_meta;
  metadata["shadowBan"] = trust.shadow_ban;
  metadata["qualityScore"] = quality_score;

  Json::StreamWriterBuilder builder;
  builder["indentation"] = "";
  const std::string metadata_text = Json::writeString(builder, metadata);

  const auto rows = db::ExecSqlSync(db_, 
      "INSERT INTO feed_posts (author_id, body, metadata, updated_at) "
      "VALUES (?, ?, ?::jsonb, NOW()) "
      "RETURNING id, body, like_count, comment_count, share_count, "
      "to_char(created_at at time zone 'utc', ?) AS created_at",
      user_id,
      trimmed,
      metadata_text,
      kTimestampFormat);

  if (rows.empty()) {
    throw FeedError(drogon::k500InternalServerError, "Post not created");
  }

  const auto& row = rows.front();
  Json::Value author;
  author["id"] = author_row["id"].as<std::string>();
  author["username"] = author_row["username"].as<std::string>();
  if (author_row["display_name"].isNull()) {
    author["displayName"] = author["username"];
  } else {
    author["displayName"] = author_row["display_name"].as<std::string>();
  }

  Json::Value post;
  post["id"] = row["id"].as<std::string>();
  post["body"] = row["body"].as<std::string>();
  post["createdAt"] = row["created_at"].as<std::string>();
  post["likeCount"] = row["like_count"].as<int>();
  post["commentCount"] = row["comment_count"].as<int>();
  post["shareCount"] = row["share_count"].as<int>();
  post["liked"] = false;
  post["followed"] = false;
  post["mentions"] = VectorToJsonArray(mentions);
  post["hashtags"] = VectorToJsonArray(hashtags);
  post["author"] = author;

  Json::Value event;
  event["type"] = "FEED_POST";
  event["payload"] = post;
  event["ts"] = static_cast<Json::Int64>(NowMs());
  if (!trust.shadow_ban) {
    PublishFeedEvent(event);
  }

  try {
    NotifyMentions(db_, user_id, mentions, row["id"].as<std::string>());
  } catch (const std::exception&) {
  }

  return post;
}

Json::Value FeedService::ListFeed(const std::string& user_id,
                                  const std::optional<int>& limit,
                                  const std::optional<std::string>& before,
                                  const std::string& mode) {
  const auto muted_phrases = LoadMutedPhrases(db_, user_id);
  const std::string normalized = ToLowerCopy(mode);

  Json::Value items = (normalized == "following")
                          ? ListFollowingFeed(db_, user_id, limit, before)
                          : ListForYouFeed(db_, user_id, limit, before);

  return FilterMuted(items, muted_phrases);
}

Json::Value FeedService::ToggleLike(const std::string& user_id,
                                    const std::string& post_id) {
  const auto post_rows = db::ExecSqlSync(db_, 
      "SELECT author_id FROM feed_posts WHERE id = ? LIMIT 1",
      post_id);
  if (post_rows.empty()) {
    throw FeedError(drogon::k404NotFound, "Post not found");
  }
  const std::string author_id = post_rows.front()["author_id"].as<std::string>();

  const auto existing = db::ExecSqlSync(db_, 
      "SELECT post_id FROM feed_likes WHERE post_id = ? AND user_id = ? "
      "LIMIT 1",
      post_id,
      user_id);

  bool liked = false;
  int like_count = 0;

  if (!existing.empty()) {
    db::ExecSqlSync(db_, 
        "DELETE FROM feed_likes WHERE post_id = ? AND user_id = ?",
        post_id,
        user_id);
    const auto rows = db::ExecSqlSync(db_, 
        "UPDATE feed_posts SET "
        "like_count = GREATEST(like_count - 1, 0), "
        "updated_at = NOW() "
        "WHERE id = ? "
        "RETURNING like_count",
        post_id);
    liked = false;
    if (!rows.empty() && !rows.front()["like_count"].isNull()) {
      like_count = rows.front()["like_count"].as<int>();
    }
  } else {
    db::ExecSqlSync(db_, 
        "INSERT INTO feed_likes (post_id, user_id) VALUES (?, ?) "
        "ON CONFLICT DO NOTHING",
        post_id,
        user_id);
    const auto rows = db::ExecSqlSync(db_, 
        "UPDATE feed_posts SET "
        "like_count = (like_count + 1), "
        "updated_at = NOW() "
        "WHERE id = ? "
        "RETURNING like_count",
        post_id);
    liked = true;
    if (!rows.empty() && !rows.front()["like_count"].isNull()) {
      like_count = rows.front()["like_count"].as<int>();
    }
  }

  Json::Value response;
  response["liked"] = liked;
  response["likeCount"] = like_count;

  Json::Value event;
  event["type"] = "FEED_LIKE";
  Json::Value payload;
  payload["postId"] = post_id;
  payload["userId"] = user_id;
  payload["liked"] = liked;
  payload["likeCount"] = like_count;
  event["payload"] = payload;
  event["ts"] = static_cast<Json::Int64>(NowMs());
  PublishFeedEvent(event);

  try {
    UpdateInterestFromPost(
        db_,
        user_id,
        post_id,
        liked ? kInterestWeightLike : -kInterestWeightLike);
  } catch (const std::exception&) {
  }

  if (liked && author_id != user_id) {
    try {
      NotificationsService notifications(db_);
      NotificationInput notif;
      notif.user_id = author_id;
      notif.actor_id = user_id;
      notif.type = "like";
      notif.title = "New like";
      notif.body = "Someone liked your post";
      notif.data = Json::Value(Json::objectValue);
      notif.data["postId"] = post_id;
      notif.push = true;
      notifications.CreateNotification(notif);
    } catch (const std::exception&) {
    }
  }

  return response;
}

Json::Value FeedService::ListComments(const std::string& user_id,
                                      const std::string& post_id,
                                      const std::optional<int>& limit) {
  const int limit_value = ClampLimit(limit, 30, 1, kMaxFeedLimit);

  const auto rows = db::ExecSqlSync(db_, 
      "SELECT "
      "c.id AS id, "
      "c.body AS body, "
      "to_char(c.created_at at time zone 'utc', ?) AS created_at, "
      "u.id AS author_id, "
      "u.username AS author_username, "
      "u.display_name AS author_display_name "
      "FROM feed_comments c "
      "JOIN users u ON u.id = c.author_id "
      "WHERE c.post_id = ? "
      "AND NOT EXISTS ("
      "SELECT 1 FROM user_blocks b "
      "WHERE (b.blocker_id = ? AND b.blocked_id = u.id) "
      "OR (b.blocker_id = u.id AND b.blocked_id = ?)"
      ") "
      "ORDER BY c.created_at ASC "
      "LIMIT ?",
      kTimestampFormat,
      post_id,
      user_id,
      user_id,
      limit_value);

  Json::Value items(Json::arrayValue);
  for (const auto& row : rows) {
    Json::Value item;
    item["id"] = row["id"].as<std::string>();
    item["body"] = row["body"].as<std::string>();
    item["createdAt"] = row["created_at"].as<std::string>();
    Json::Value author;
    author["id"] = row["author_id"].as<std::string>();
    author["username"] = row["author_username"].as<std::string>();
    if (row["author_display_name"].isNull()) {
      author["displayName"] = author["username"];
    } else {
      author["displayName"] = row["author_display_name"].as<std::string>();
    }
    item["author"] = author;
    items.append(item);
  }

  return items;
}

Json::Value FeedService::AddComment(const std::string& user_id,
                                    const std::string& post_id,
                                    const std::string& body) {
  const std::string trimmed = Trim(body);
  if (trimmed.empty()) {
    throw FeedError(drogon::k400BadRequest, "Comment body required");
  }

  const auto& cfg = AppState::Instance().GetConfig();
  const Json::Value moderation =
      CheckModeration(cfg, trimmed, user_id, std::nullopt);
  const std::string moderation_action =
      moderation.isMember("action") && moderation["action"].isString()
          ? moderation["action"].asString()
          : "allow";
  if (moderation_action == "block") {
    throw FeedError(drogon::k400BadRequest, "Comment blocked by moderation");
  }

  const auto post_rows = db::ExecSqlSync(db_, 
      "SELECT author_id FROM feed_posts WHERE id = ? LIMIT 1",
      post_id);
  if (post_rows.empty()) {
    throw FeedError(drogon::k404NotFound, "Post not found");
  }
  const std::string post_author_id =
      post_rows.front()["author_id"].as<std::string>();

  const auto comment_rows = db::ExecSqlSync(db_, 
      "INSERT INTO feed_comments (post_id, author_id, body) "
      "VALUES (?, ?, ?) "
      "RETURNING id, body, "
      "to_char(created_at at time zone 'utc', ?) AS created_at",
      post_id,
      user_id,
      trimmed,
      kTimestampFormat);
  if (comment_rows.empty()) {
    throw FeedError(drogon::k500InternalServerError, "Comment not created");
  }

  const auto count_rows = db::ExecSqlSync(db_, 
      "UPDATE feed_posts SET "
      "comment_count = (comment_count + 1), "
      "updated_at = NOW() "
      "WHERE id = ? "
      "RETURNING comment_count",
      post_id);
  int comment_count = 0;
  if (!count_rows.empty() && !count_rows.front()["comment_count"].isNull()) {
    comment_count = count_rows.front()["comment_count"].as<int>();
  }

  const auto author_rows = db::ExecSqlSync(db_, 
      "SELECT id, username, display_name FROM users WHERE id = ? LIMIT 1",
      user_id);

  const auto& comment_row = comment_rows.front();
  Json::Value comment;
  comment["id"] = comment_row["id"].as<std::string>();
  comment["body"] = comment_row["body"].as<std::string>();
  comment["createdAt"] = comment_row["created_at"].as<std::string>();
  Json::Value author;
  author["id"] = user_id;
  if (!author_rows.empty()) {
    const auto& row = author_rows.front();
    author["id"] = row["id"].as<std::string>();
    author["username"] = row["username"].as<std::string>();
    if (row["display_name"].isNull()) {
      author["displayName"] = author["username"];
    } else {
      author["displayName"] = row["display_name"].as<std::string>();
    }
  } else {
    author["username"] = "";
    author["displayName"] = "";
  }
  comment["author"] = author;

  Json::Value event;
  event["type"] = "FEED_COMMENT";
  Json::Value payload;
  payload["postId"] = post_id;
  payload["comment"] = comment;
  payload["commentCount"] = comment_count;
  event["payload"] = payload;
  event["ts"] = static_cast<Json::Int64>(NowMs());
  PublishFeedEvent(event);

  if (post_author_id != user_id) {
    try {
      NotificationsService notifications(db_);
      NotificationInput notif;
      notif.user_id = post_author_id;
      notif.actor_id = user_id;
      notif.type = "comment";
      notif.title = "New comment";
      notif.body = "Someone commented on your post";
      notif.data = Json::Value(Json::objectValue);
      notif.data["postId"] = post_id;
      notif.data["commentId"] = comment["id"];
      notif.push = true;
      notifications.CreateNotification(notif);
    } catch (const std::exception&) {
    }
  }

  try {
    UpdateInterestFromPost(db_, user_id, post_id, kInterestWeightComment);
  } catch (const std::exception&) {
  }

  Json::Value response;
  response["comment"] = comment;
  response["commentCount"] = comment_count;
  return response;
}

Json::Value FeedService::SharePost(const std::string& user_id,
                                   const std::string& post_id) {
  const auto post_rows = db::ExecSqlSync(db_, 
      "SELECT author_id, share_count FROM feed_posts WHERE id = ? LIMIT 1",
      post_id);
  if (post_rows.empty()) {
    throw FeedError(drogon::k404NotFound, "Post not found");
  }

  const auto& post_row = post_rows.front();
  const std::string post_author_id =
      post_row["author_id"].as<std::string>();
  int share_count =
      post_row["share_count"].isNull() ? 0 : post_row["share_count"].as<int>();
  bool created = false;

  const auto existing = db::ExecSqlSync(db_, 
      "SELECT post_id FROM feed_shares WHERE post_id = ? AND user_id = ? "
      "LIMIT 1",
      post_id,
      user_id);

  if (existing.empty()) {
    db::ExecSqlSync(db_, 
        "INSERT INTO feed_shares (post_id, user_id) VALUES (?, ?) "
        "ON CONFLICT DO NOTHING",
        post_id,
        user_id);
    const auto rows = db::ExecSqlSync(db_, 
        "UPDATE feed_posts SET "
        "share_count = (share_count + 1), "
        "updated_at = NOW() "
        "WHERE id = ? "
        "RETURNING share_count",
        post_id);
    if (!rows.empty() && !rows.front()["share_count"].isNull()) {
      share_count = rows.front()["share_count"].as<int>();
    }
    created = true;
  }

  Json::Value event;
  event["type"] = "FEED_SHARE";
  Json::Value payload;
  payload["postId"] = post_id;
  payload["userId"] = user_id;
  payload["shareCount"] = share_count;
  event["payload"] = payload;
  event["ts"] = static_cast<Json::Int64>(NowMs());
  PublishFeedEvent(event);

  if (post_author_id != user_id) {
    try {
      NotificationsService notifications(db_);
      NotificationInput notif;
      notif.user_id = post_author_id;
      notif.actor_id = user_id;
      notif.type = "share";
      notif.title = "Post shared";
      notif.body = "Someone shared your post";
      notif.data = Json::Value(Json::objectValue);
      notif.data["postId"] = post_id;
      notif.push = true;
      notifications.CreateNotification(notif);
    } catch (const std::exception&) {
    }
  }

  if (created) {
    try {
      UpdateInterestFromPost(db_, user_id, post_id, kInterestWeightShare);
    } catch (const std::exception&) {
    }
  }

  Json::Value response;
  response["shared"] = true;
  response["shareCount"] = share_count;
  response["created"] = created;
  return response;
}

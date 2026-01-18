#include "modules/support/support_service.h"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <string>
#include <utility>

#include "app_state.h"
#include "email/email_service.h"
#include "modules/auth/auth_validation.h"

namespace {

constexpr const char* kTimestampFormat =
    "YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"";

std::string ToJsonString(const Json::Value& value) {
  Json::StreamWriterBuilder builder;
  builder["indentation"] = "";
  return Json::writeString(builder, value);
}

std::string ReplaceNewlinesWithBr(const std::string& value) {
  std::ostringstream out;
  for (char ch : value) {
    if (ch == '\n') {
      out << "<br />";
    } else {
      out << ch;
    }
  }
  return out.str();
}

std::string ToUpper(const std::string& value) {
  std::string out = value;
  std::transform(out.begin(), out.end(), out.begin(),
                 [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
  return out;
}

}  // namespace

SupportService::SupportService(drogon::orm::DbClientPtr db)
    : db_(std::move(db)) {}

Json::Value SupportService::CreateTicket(const SupportTicketInput& input) {
  const std::string message = Trim(input.message);
  if (message.empty()) {
    throw SupportError(drogon::k400BadRequest, "Message is required");
  }

  const auto user_rows = db_->execSqlSync(
      "SELECT id, email, username, display_name FROM users WHERE id = ? LIMIT 1",
      input.user_id);

  Json::Value metadata(Json::objectValue);
  metadata["includeLogs"] = input.include_logs.value_or(false);
  metadata["allowContact"] = input.allow_contact.value_or(false);
  if (input.score.has_value()) {
    metadata["score"] = input.score.value();
  } else {
    metadata["score"] = Json::nullValue;
  }

  const std::string category_value = input.category.value_or("");
  const auto rows = db_->execSqlSync(
      "INSERT INTO support_tickets (user_id, type, category, message, metadata) "
      "VALUES (?, ?, NULLIF(?, ''), ?, ?::jsonb) "
      "RETURNING id, to_char(created_at at time zone 'utc', ?) AS created_at",
      input.user_id,
      input.type,
      category_value,
      message,
      ToJsonString(metadata),
      kTimestampFormat);

  if (rows.empty()) {
    throw SupportError(drogon::k500InternalServerError,
                       "Failed to create ticket");
  }

  const std::string ticket_id = rows.front()["id"].as<std::string>();
  const std::string created_at = rows.front()["created_at"].as<std::string>();

  const auto& cfg = AppState::Instance().GetConfig();
  const std::string support_email =
      !cfg.email_support.empty() ? cfg.email_support : cfg.email_from;

  if (!support_email.empty()) {
    EmailService email(cfg);

    std::string identity = "Unknown user";
    if (!user_rows.empty()) {
      const auto& row = user_rows.front();
      const std::string username = row["username"].as<std::string>();
      const std::string display_name = row["display_name"].isNull()
                                           ? username
                                           : row["display_name"].as<std::string>();
      const std::string email_addr = row["email"].as<std::string>();
      identity = display_name + " <" + email_addr + ">";
    }

    const std::string title =
        input.category && !input.category->empty() ? *input.category
                                                    : "Support request";
    const std::string subject =
        "[" + ToUpper(input.type) + "] " + title + " (" + ticket_id + ")";

    std::ostringstream text;
    text << "Ticket: " << ticket_id << "\n";
    text << "Type: " << input.type << "\n";
    text << "Category: " << title << "\n";
    text << "User: " << identity << "\n";
    text << "Allow contact: "
         << (metadata["allowContact"].asBool() ? "yes" : "no") << "\n";
    text << "Include logs: "
         << (metadata["includeLogs"].asBool() ? "yes" : "no") << "\n";
    if (input.score.has_value()) {
      text << "Score: " << input.score.value() << "\n";
    }
    text << "\n" << message;

    std::ostringstream html;
    html << "<h2>" << title << "</h2>";
    html << "<p><strong>Ticket:</strong> " << ticket_id << "</p>";
    html << "<p><strong>Type:</strong> " << input.type << "</p>";
    html << "<p><strong>User:</strong> " << identity << "</p>";
    html << "<p><strong>Allow contact:</strong> "
         << (metadata["allowContact"].asBool() ? "yes" : "no") << "</p>";
    html << "<p><strong>Include logs:</strong> "
         << (metadata["includeLogs"].asBool() ? "yes" : "no") << "</p>";
    if (input.score.has_value()) {
      html << "<p><strong>Score:</strong> " << input.score.value() << "</p>";
    }
    html << "<hr />";
    html << "<p>" << ReplaceNewlinesWithBr(message) << "</p>";

    try {
      email.SendSupportEmail(support_email, subject, html.str(), text.str());
    } catch (const std::exception&) {
      // Best-effort delivery.
    }
  }

  Json::Value response;
  response["ticketId"] = ticket_id;
  response["createdAt"] = created_at.empty() ? Json::nullValue
                                             : Json::Value(created_at);
  return response;
}

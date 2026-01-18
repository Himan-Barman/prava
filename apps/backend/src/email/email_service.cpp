#include "email/email_service.h"

#include <drogon/HttpClient.h>
#include <drogon/HttpRequest.h>
#include <json/json.h>
#include <trantor/utils/Logger.h>

namespace {

const char kResendEndpoint[] = "https://api.resend.com";

}  // namespace

EmailService::EmailService(const Config& cfg) : cfg_(cfg) {}

void EmailService::SendVerifyEmail(const std::string& email,
                                   const std::string& token) const {
  const std::string app_name = cfg_.app_name.empty() ? "PRAVA" : cfg_.app_name;
  const std::string verify_url = WithToken(cfg_.email_verify_url, token);
  const std::string subject = "Verify your " + app_name + " account";

  std::string text = "Your " + app_name +
                     " verification code is:\n" + token;
  if (!verify_url.empty()) {
    text += "\n\nVerify here: " + verify_url;
  }

  const std::string html =
      "<p>Use this code to verify your account:</p>"
      "<p><strong>" + token + "</strong></p>";

  SendEmail(email, subject, html, text);
}

void EmailService::SendPasswordResetCode(const std::string& email,
                                         const std::string& code,
                                         int expires_in_minutes) const {
  const std::string app_name = cfg_.app_name.empty() ? "PRAVA" : cfg_.app_name;
  const std::string subject = "Your " + app_name + " password reset code";

  std::string text = "Use this code to reset your " + app_name +
                     " password: " + code +
                     "\nThis code expires in " +
                     std::to_string(expires_in_minutes) + " minutes.";

  const std::string html =
      "<p>Use this code to reset your password:</p>"
      "<p><strong>" + code + "</strong></p>";

  SendEmail(email, subject, html, text);
}

void EmailService::SendEmailOtp(const std::string& email,
                                const std::string& code,
                                int expires_in_minutes) const {
  const std::string app_name = cfg_.app_name.empty() ? "PRAVA" : cfg_.app_name;
  const std::string subject = "Your " + app_name + " verification code";

  std::string text = "Your " + app_name + " verification code is " + code +
                     "\nThis code expires in " +
                     std::to_string(expires_in_minutes) + " minutes.";

  const std::string html =
      "<p>Your verification code:</p>"
      "<p><strong>" + code + "</strong></p>";

  SendEmail(email, subject, html, text);
}

void EmailService::SendSupportEmail(const std::string& to,
                                    const std::string& subject,
                                    const std::string& html,
                                    const std::string& text) const {
  SendEmail(to, subject, html, text);
}

void EmailService::SendEmail(const std::string& to,
                             const std::string& subject,
                             const std::string& html,
                             const std::string& text) const {
  if (!IsConfigured()) {
    if (cfg_.env == "production") {
      LOG_ERROR << "Email service not configured. Set RESEND_API_KEY and EMAIL_FROM.";
    } else {
      LOG_WARN << "Email service not configured. Skipping email delivery.";
    }
    return;
  }

  Json::Value payload;
  payload["from"] = BuildFromAddress();
  payload["to"] = Json::arrayValue;
  payload["to"].append(to);
  payload["subject"] = subject;
  payload["html"] = html;
  payload["text"] = text;

  auto client = drogon::HttpClient::newHttpClient(kResendEndpoint);
  auto req = drogon::HttpRequest::newHttpJsonRequest(payload);
  req->setMethod(drogon::Post);
  req->setPath("/emails");
  req->addHeader("Authorization", "Bearer " + cfg_.resend_api_key);

  client->sendRequest(req, [](drogon::ReqResult result,
                              const drogon::HttpResponsePtr& resp) {
    if (result != drogon::ReqResult::Ok || !resp || resp->getStatusCode() >= 300) {
      LOG_WARN << "Resend API request failed";
    }
  });
}

bool EmailService::IsConfigured() const {
  return !cfg_.resend_api_key.empty() && !cfg_.email_from.empty();
}

std::string EmailService::BuildFromAddress() const {
  if (cfg_.email_from.empty()) {
    return "";
  }
  if (cfg_.email_from_name.empty()) {
    return cfg_.email_from;
  }
  return cfg_.email_from_name + " <" + cfg_.email_from + ">";
}

std::string EmailService::WithToken(const std::string& base_url,
                                    const std::string& token) const {
  if (base_url.empty()) {
    return "";
  }
  const std::string delimiter =
      base_url.find('?') == std::string::npos ? "?" : "&";
  return base_url + delimiter + "token=" + token;
}

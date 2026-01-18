#pragma once

#include <string>

#include "config/config.h"

class EmailService {
 public:
  explicit EmailService(const Config& cfg);

  void SendVerifyEmail(const std::string& email, const std::string& token) const;
  void SendPasswordResetCode(const std::string& email,
                             const std::string& code,
                             int expires_in_minutes) const;
  void SendEmailOtp(const std::string& email,
                    const std::string& code,
                    int expires_in_minutes) const;
  void SendSupportEmail(const std::string& to,
                        const std::string& subject,
                        const std::string& html,
                        const std::string& text) const;

 private:
  void SendEmail(const std::string& to,
                 const std::string& subject,
                 const std::string& html,
                 const std::string& text) const;
  bool IsConfigured() const;
  std::string BuildFromAddress() const;
  std::string WithToken(const std::string& base_url,
                        const std::string& token) const;

  const Config& cfg_;
};

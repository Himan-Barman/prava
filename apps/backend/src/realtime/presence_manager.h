#pragma once

#include <string>

class PresenceManager {
 public:
  void Connect(const std::string& user_id,
               const std::string& device_id) const;
  void Disconnect(const std::string& user_id,
                  const std::string& device_id) const;
  bool IsOnline(const std::string& user_id) const;
  bool IsDeviceOnline(const std::string& user_id,
                      const std::string& device_id) const;
};

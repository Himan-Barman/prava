#pragma once

#include <drogon/HttpFilter.h>

class RateLimitFilter : public drogon::HttpFilter<RateLimitFilter> {
 public:
  void doFilter(const drogon::HttpRequestPtr& req,
                drogon::FilterCallback&& fcb,
                drogon::FilterChainCallback&& fccb) override;
};

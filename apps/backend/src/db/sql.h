#pragma once

#include <string>
#include <utility>

#include <drogon/orm/DbClient.h>

namespace db {

inline std::string NormalizePgPlaceholders(std::string sql) {
  if (sql.find('?') == std::string::npos) {
    return sql;
  }

  std::string out;
  out.reserve(sql.size() + 8);

  bool in_single_quote = false;
  int index = 1;
  for (size_t i = 0; i < sql.size(); ++i) {
    const char ch = sql[i];
    if (ch == '\'') {
      out.push_back(ch);
      if (in_single_quote) {
        if (i + 1 < sql.size() && sql[i + 1] == '\'') {
          out.push_back('\'');
          ++i;
        } else {
          in_single_quote = false;
        }
      } else {
        in_single_quote = true;
      }
      continue;
    }

    if (!in_single_quote && ch == '?') {
      out.push_back('$');
      out += std::to_string(index++);
      continue;
    }

    out.push_back(ch);
  }

  return out;
}

template <typename... Args>
inline drogon::orm::Result ExecSqlSync(const drogon::orm::DbClientPtr& db,
                                       std::string sql,
                                       Args&&... args) {
  if (db && db->type() == drogon::orm::ClientType::PostgreSQL) {
    sql = NormalizePgPlaceholders(std::move(sql));
  }
  return db->execSqlSync(sql, std::forward<Args>(args)...);
}

}  // namespace db

cmake_minimum_required(VERSION 3.20)

project(prava_backend_cpp LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(FetchContent)

FetchContent_Declare(
  drogon
  GIT_REPOSITORY https://github.com/drogonframework/drogon.git
  GIT_TAG v1.9.7
)

FetchContent_Declare(
  jwtcpp
  GIT_REPOSITORY https://github.com/Thalhammer/jwt-cpp.git
  GIT_TAG v0.7.0
)

FetchContent_Declare(
  argon2
  GIT_REPOSITORY https://github.com/P-H-C/phc-winner-argon2.git
  GIT_TAG master
)

FetchContent_MakeAvailable(drogon jwtcpp)

FetchContent_GetProperties(argon2)
if(NOT argon2_POPULATED)
  FetchContent_Populate(argon2)
endif()

add_library(argon2 STATIC
  ${argon2_SOURCE_DIR}/src/argon2.c
  ${argon2_SOURCE_DIR}/src/core.c
  ${argon2_SOURCE_DIR}/src/encoding.c
  ${argon2_SOURCE_DIR}/src/ref.c
  ${argon2_SOURCE_DIR}/src/thread.c
  ${argon2_SOURCE_DIR}/src/blake2/blake2b.c
)
target_include_directories(argon2 PUBLIC
  ${argon2_SOURCE_DIR}/include
  ${argon2_SOURCE_DIR}/src
)

find_package(OpenSSL REQUIRED)

add_executable(prava_backend_cpp
  src/main.cpp
  src/app_state.cpp
  src/config/config.cpp
  src/email/email_service.cpp
  src/http/json.cpp
  src/http/response.cpp
  src/http/request_id.cpp
  src/filters/jwt_filter.cpp
  src/filters/rate_limit_filter.cpp
  src/modules/notifications/notifications_controller.cpp
  src/modules/notifications/notifications_service.cpp
  src/modules/conversations/conversations_controller.cpp
  src/modules/conversations/conversations_service.cpp
  src/modules/messages/messages_controller.cpp
  src/modules/messages/messages_service.cpp
  src/modules/devices/devices_controller.cpp
  src/modules/devices/devices_service.cpp
  src/modules/e2e/e2e_controller.cpp
  src/modules/e2e/e2e_service.cpp
  src/modules/media/media_controller.cpp
  src/modules/media/media_service.cpp
  src/modules/support/support_controller.cpp
  src/modules/support/support_service.cpp
  src/modules/feed/feed_controller.cpp
  src/modules/feed/feed_service.cpp
  src/realtime/presence_manager.cpp
  src/realtime/sync_service.cpp
  src/realtime/ws_controller.cpp
  src/realtime/ws_fanout.cpp
  src/realtime/ws_hub.cpp
  src/realtime/ws_registry.cpp
  src/realtime/ws_router.cpp
  src/modules/health/health_controller.cpp
  src/modules/auth/auth_controller.cpp
  src/modules/auth/auth_validation.cpp
  src/modules/auth/auth_service.cpp
  src/modules/auth/password_hasher.cpp
  src/modules/auth/token_service.cpp
  src/modules/users/users_controller.cpp
  src/modules/users/users_service.cpp
)

target_include_directories(prava_backend_cpp PRIVATE src)
target_link_libraries(prava_backend_cpp PRIVATE drogon jwt-cpp::jwt-cpp argon2 OpenSSL::Crypto)

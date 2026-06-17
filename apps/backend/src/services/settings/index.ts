import { requireAuth } from "../../lib/auth.js";
import { query, queryMany, queryOne, withTransaction } from "../../lib/pg.js";
import {
  HttpError,
  ensure,
  generateId,
  isValidEmail,
  isValidUsername,
  normalizeEmail,
  normalizeUsername,
  now,
  verifyPassword,
} from "../../lib/security.js";
import { getFeedPreferences, updateFeedPreferences } from "../feed/recommendation.js";

const visibilityValues = ["everyone", "public", "followers", "friends", "closeFriends", "onlyMe", "hidden"] as const;
const audienceValues = ["everyone", "followers", "friends", "closeFriends", "nobody"] as const;
const themeValues = ["system", "light", "dark", "premiumDark", "amoled"] as const;
const densityValues = ["compact", "comfortable", "spacious"] as const;
const fontSizeValues = ["small", "default", "large", "extraLarge"] as const;
const feedModeValues = ["forYou", "following", "friends", "latest", "trending"] as const;
const personalizationValues = ["low", "balanced", "high"] as const;
const safetyValues = ["strict", "balanced", "open"] as const;
const mediaQualityValues = ["auto", "low", "standard", "high"] as const;
const accountTypeValues = ["personal", "creator", "professional", "organization"] as const;

const legacyDefaults = {
  privateAccount: false,
  activityStatus: true,
  readReceipts: true,
  messagePreview: true,
  sensitiveContent: false,
  locationSharing: false,
  twoFactor: false,
  loginAlerts: true,
  appLock: false,
  biometrics: true,
  pushNotifications: true,
  emailNotifications: false,
  inAppSounds: true,
  inAppHaptics: true,
  notifyPosts: true,
  notifyChats: true,
  notifyMentions: true,
  notifyFollows: true,
  dataSaver: false,
  autoDownload: true,
  autoPlayVideos: true,
  reduceMotion: false,
  themeIndex: 0,
  textScale: 1,
  languageLabel: "English",
};

type Schema = Record<string, { column: string; type: "bool" | "text" | "number" | "list"; allowed?: readonly string[]; min?: number; max?: number }>;

const tableSchemas: Record<string, { table: string; schema: Schema; sensitive?: string[] }> = {
  profile_visibility: {
    table: "profile_visibility_settings",
    sensitive: ["account_privacy"],
    schema: {
      accountPrivacy: { column: "account_privacy", type: "text", allowed: ["public", "private"] },
      postsVisibility: { column: "posts_visibility", type: "text", allowed: visibilityValues },
      repliesVisibility: { column: "replies_visibility", type: "text", allowed: visibilityValues },
      mediaVisibility: { column: "media_visibility", type: "text", allowed: visibilityValues },
      highlightsVisibility: { column: "highlights_visibility", type: "text", allowed: visibilityValues },
      aboutVisibility: { column: "about_visibility", type: "text", allowed: visibilityValues },
      bioVisibility: { column: "bio_visibility", type: "text", allowed: visibilityValues },
      locationVisibility: { column: "location_visibility", type: "text", allowed: visibilityValues },
      websiteVisibility: { column: "website_visibility", type: "text", allowed: visibilityValues },
      birthdayVisibility: { column: "birthday_visibility", type: "text", allowed: visibilityValues },
      followersListVisibility: { column: "followers_list_visibility", type: "text", allowed: visibilityValues },
      followingListVisibility: { column: "following_list_visibility", type: "text", allowed: visibilityValues },
      friendsListVisibility: { column: "friends_list_visibility", type: "text", allowed: visibilityValues },
      mutualFriendsVisibility: { column: "mutual_friends_visibility", type: "text", allowed: visibilityValues },
      profileSharingEnabled: { column: "profile_sharing_enabled", type: "bool" },
      searchEngineVisibility: { column: "search_engine_visibility", type: "bool" },
      accentColor: { column: "accent_color", type: "text" },
      profileTheme: { column: "profile_theme", type: "text" },
      coverStyle: { column: "cover_style", type: "text" },
      badgeVisibility: { column: "badge_visibility", type: "text", allowed: visibilityValues },
    },
  },
  privacy: {
    table: "privacy_settings",
    schema: {
      showOnlineStatus: { column: "show_online_status", type: "bool" },
      showLastActive: { column: "show_last_active", type: "bool" },
      readReceiptsEnabled: { column: "read_receipts_enabled", type: "bool" },
      typingIndicatorEnabled: { column: "typing_indicator_enabled", type: "bool" },
      activityStatusVisibility: { column: "activity_status_visibility", type: "text", allowed: visibilityValues },
      allowFindByUsername: { column: "allow_find_by_username", type: "bool" },
      allowFindByEmail: { column: "allow_find_by_email", type: "bool" },
      allowFindByPhone: { column: "allow_find_by_phone", type: "bool" },
      suggestProfileToOthers: { column: "suggest_profile_to_others", type: "bool" },
      contactSyncEnabled: { column: "contact_sync_enabled", type: "bool" },
      allowMentionsFrom: { column: "allow_mentions_from", type: "text", allowed: audienceValues },
      allowTagsFrom: { column: "allow_tags_from", type: "text", allowed: audienceValues },
      reviewTagsBeforeShowing: { column: "review_tags_before_showing", type: "bool" },
      allowReposts: { column: "allow_reposts", type: "bool" },
      allowQuotePosts: { column: "allow_quote_posts", type: "bool" },
      whoCanMessage: { column: "who_can_message", type: "text", allowed: audienceValues },
      messageRequestsEnabled: { column: "message_requests_enabled", type: "bool" },
      filterUnknownSenders: { column: "filter_unknown_senders", type: "bool" },
      hideMessagePreview: { column: "hide_message_preview", type: "bool" },
      sensitiveContentFilter: { column: "sensitive_content_filter", type: "bool" },
      blurSensitiveMedia: { column: "blur_sensitive_media", type: "bool" },
      offensiveWordsFilter: { column: "offensive_words_filter", type: "bool" },
      contentSafetyLevel: { column: "content_safety_level", type: "text", allowed: safetyValues },
    },
  },
  notifications: {
    table: "notification_settings",
    schema: {
      pushEnabled: { column: "push_enabled", type: "bool" },
      inAppEnabled: { column: "in_app_enabled", type: "bool" },
      emailEnabled: { column: "email_enabled", type: "bool" },
      smsEnabled: { column: "sms_enabled", type: "bool" },
      likesEnabled: { column: "likes_enabled", type: "bool" },
      commentsEnabled: { column: "comments_enabled", type: "bool" },
      repliesEnabled: { column: "replies_enabled", type: "bool" },
      repostsEnabled: { column: "reposts_enabled", type: "bool" },
      quotePostsEnabled: { column: "quote_posts_enabled", type: "bool" },
      mentionsEnabled: { column: "mentions_enabled", type: "bool" },
      tagsEnabled: { column: "tags_enabled", type: "bool" },
      followsEnabled: { column: "follows_enabled", type: "bool" },
      followRequestsEnabled: { column: "follow_requests_enabled", type: "bool" },
      friendRequestsEnabled: { column: "friend_requests_enabled", type: "bool" },
      friendAcceptsEnabled: { column: "friend_accepts_enabled", type: "bool" },
      directMessagesEnabled: { column: "direct_messages_enabled", type: "bool" },
      messageRequestsEnabled: { column: "message_requests_enabled", type: "bool" },
      groupMessagesEnabled: { column: "group_messages_enabled", type: "bool" },
      recommendationsEnabled: { column: "recommendations_enabled", type: "bool" },
      trendingEnabled: { column: "trending_enabled", type: "bool" },
      securityAlertsEnabled: { column: "security_alerts_enabled", type: "bool" },
      quietHoursEnabled: { column: "quiet_hours_enabled", type: "bool" },
      quietHoursStart: { column: "quiet_hours_start", type: "text" },
      quietHoursEnd: { column: "quiet_hours_end", type: "text" },
      allowImportantAlerts: { column: "allow_important_alerts", type: "bool" },
      allowMessageExceptions: { column: "allow_message_exceptions", type: "bool" },
      notificationPreviewEnabled: { column: "notification_preview_enabled", type: "bool" },
      soundEnabled: { column: "sound_enabled", type: "bool" },
      vibrationEnabled: { column: "vibration_enabled", type: "bool" },
      badgeCountEnabled: { column: "badge_count_enabled", type: "bool" },
      lockScreenPreviewEnabled: { column: "lock_screen_preview_enabled", type: "bool" },
    },
  },
  chats: {
    table: "chat_settings",
    schema: {
      whoCanMessage: { column: "who_can_message", type: "text", allowed: ["everyone", "followers", "friends", "nobody"] },
      messageRequestsEnabled: { column: "message_requests_enabled", type: "bool" },
      filterUnknownSenders: { column: "filter_unknown_senders", type: "bool" },
      readReceiptsEnabled: { column: "read_receipts_enabled", type: "bool" },
      typingIndicatorsEnabled: { column: "typing_indicators_enabled", type: "bool" },
      onlineStatusEnabled: { column: "online_status_enabled", type: "bool" },
      showLastSeen: { column: "show_last_seen", type: "bool" },
      whoCanAddToGroups: { column: "who_can_add_to_groups", type: "text", allowed: ["everyone", "friends", "nobody"] },
      groupInviteApprovalRequired: { column: "group_invite_approval_required", type: "bool" },
      allowGroupMentions: { column: "allow_group_mentions", type: "bool" },
      groupNotificationDefaults: { column: "group_notification_defaults", type: "text", allowed: ["all", "mentions", "muted"] },
      chatTheme: { column: "chat_theme", type: "text", allowed: themeValues },
      bubbleDensity: { column: "bubble_density", type: "text", allowed: densityValues },
      fontSize: { column: "font_size", type: "text", allowed: fontSizeValues },
      timestampDisplay: { column: "timestamp_display", type: "text", allowed: ["compact", "full", "hidden"] },
      autoDownloadImages: { column: "auto_download_images", type: "bool" },
      autoDownloadVideos: { column: "auto_download_videos", type: "bool" },
      autoDownloadVoiceNotes: { column: "auto_download_voice_notes", type: "bool" },
      dataSaverMedia: { column: "data_saver_media", type: "bool" },
      enterKeySends: { column: "enter_key_sends", type: "bool" },
      sendButtonAlwaysVisible: { column: "send_button_always_visible", type: "bool" },
      linkPreviewsEnabled: { column: "link_previews_enabled", type: "bool" },
      defaultReaction: { column: "default_reaction", type: "text" },
    },
  },
  friends: {
    table: "friend_settings",
    schema: {
      allowFriendRequestsFrom: { column: "allow_friend_requests_from", type: "text", allowed: audienceValues },
      showMutualFriendActivity: { column: "show_mutual_friend_activity", type: "bool" },
      peopleYouMayKnow: { column: "people_you_may_know", type: "bool" },
      closeFriendsNotifications: { column: "close_friends_notifications", type: "bool" },
    },
  },
  appearance: {
    table: "appearance_settings",
    schema: {
      themeMode: { column: "theme_mode", type: "text", allowed: themeValues },
      accentColor: { column: "accent_color", type: "text" },
      displayDensity: { column: "display_density", type: "text", allowed: densityValues },
      fontSize: { column: "font_size", type: "text", allowed: fontSizeValues },
      boldText: { column: "bold_text", type: "bool" },
      reduceAnimations: { column: "reduce_animations", type: "bool" },
      blurEffectsEnabled: { column: "blur_effects_enabled", type: "bool" },
      hapticFeedbackEnabled: { column: "haptic_feedback_enabled", type: "bool" },
      premiumMotionEnabled: { column: "premium_motion_enabled", type: "bool" },
    },
  },
  accessibility: {
    table: "accessibility_settings",
    schema: {
      textSize: { column: "text_size", type: "text", allowed: fontSizeValues },
      highContrast: { column: "high_contrast", type: "bool" },
      boldText: { column: "bold_text", type: "bool" },
      reduceMotion: { column: "reduce_motion", type: "bool" },
      reduceTransparency: { column: "reduce_transparency", type: "bool" },
      largerTouchTargets: { column: "larger_touch_targets", type: "bool" },
      screenReaderEnhancedLabels: { column: "screen_reader_enhanced_labels", type: "bool" },
      disableAutoplay: { column: "disable_autoplay", type: "bool" },
    },
  },
  data_storage: {
    table: "data_storage_settings",
    schema: {
      dataSaverEnabled: { column: "data_saver_enabled", type: "bool" },
      autoDownloadEnabled: { column: "auto_download_enabled", type: "bool" },
      autoPlayVideos: { column: "auto_play_videos", type: "bool" },
      mediaQuality: { column: "media_quality", type: "text", allowed: mediaQualityValues },
    },
  },
  ai_personalization: {
    table: "ai_personalization_settings",
    schema: {
      personalizedFeedEnabled: { column: "personalized_feed_enabled", type: "bool" },
      aiFriendSuggestionsEnabled: { column: "ai_friend_suggestions_enabled", type: "bool" },
      aiPostRecommendationsEnabled: { column: "ai_post_recommendations_enabled", type: "bool" },
      aiSmartRepliesEnabled: { column: "ai_smart_replies_enabled", type: "bool" },
      aiProfileSummaryEnabled: { column: "ai_profile_summary_enabled", type: "bool" },
      aiSafetyFilteringEnabled: { column: "ai_safety_filtering_enabled", type: "bool" },
      useActivityForAi: { column: "use_activity_for_ai", type: "bool" },
      usePostsForRecommendations: { column: "use_posts_for_recommendations", type: "bool" },
      useLikesForRecommendations: { column: "use_likes_for_recommendations", type: "bool" },
      useChatsForAi: { column: "use_chats_for_ai", type: "bool" },
    },
  },
  creator: {
    table: "creator_settings",
    schema: {
      creatorModeEnabled: { column: "creator_mode_enabled", type: "bool" },
      creatorCategory: { column: "creator_category", type: "text" },
      professionalAccountEnabled: { column: "professional_account_enabled", type: "bool" },
      publicContactButtonEnabled: { column: "public_contact_button_enabled", type: "bool" },
      publicEmail: { column: "public_email", type: "text" },
      showCreatorBadge: { column: "show_creator_badge", type: "bool" },
      analyticsEnabled: { column: "analytics_enabled", type: "bool" },
      monetizationEnabled: { column: "monetization_enabled", type: "bool" },
    },
  },
  security: {
    table: "security_settings",
    sensitive: ["two_factor_enabled", "trusted_devices_enabled"],
    schema: {
      twoFactorEnabled: { column: "two_factor_enabled", type: "bool" },
      loginAlertsEnabled: { column: "login_alerts_enabled", type: "bool" },
      suspiciousLoginProtectionEnabled: { column: "suspicious_login_protection_enabled", type: "bool" },
      trustedDevicesEnabled: { column: "trusted_devices_enabled", type: "bool" },
      recoveryEmailSet: { column: "recovery_email_set", type: "bool" },
      recoveryPhoneSet: { column: "recovery_phone_set", type: "bool" },
      appLockEnabled: { column: "app_lock_enabled", type: "bool" },
      biometricsEnabled: { column: "biometrics_enabled", type: "bool" },
    },
  },
};

function boolValue(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function stringList(value: unknown, max = 20): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map((item) => String(item || "").trim()).filter(Boolean))].slice(0, max);
}

function themeFromIndex(index: unknown): string {
  if (index === 1 || String(index) === "1") return "light";
  if (index === 2 || String(index) === "2") return "dark";
  return "system";
}

function indexFromTheme(theme: unknown): number {
  if (theme === "light") return 1;
  if (theme === "dark" || theme === "premiumDark" || theme === "amoled") return 2;
  return 0;
}

function fontFromScale(value: unknown): string {
  const scale = Number(value || 1);
  if (scale >= 1.18) return "extraLarge";
  if (scale >= 1.08) return "large";
  if (scale <= 0.94) return "small";
  return "default";
}

function scaleFromFont(value: unknown): number {
  if (value === "extraLarge") return 1.2;
  if (value === "large") return 1.1;
  if (value === "small") return 0.9;
  return 1;
}

function sanitizeTime(value: unknown, fallback: string): string {
  const text = String(value || "").trim();
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(text) ? text : fallback;
}

function sanitizeValue(key: string, value: unknown, rule: Schema[string]) {
  if (rule.type === "bool") return value === true;
  if (rule.type === "number") {
    const num = Number(value);
    const fallback = rule.min ?? 0;
    const min = rule.min ?? Number.NEGATIVE_INFINITY;
    const max = rule.max ?? Number.POSITIVE_INFINITY;
    return Number.isFinite(num) ? Math.max(min, Math.min(max, num)) : fallback;
  }
  if (rule.type === "list") return stringList(value, rule.max || 20);
  const text = String(value || "").trim();
  if (key.toLowerCase().includes("email") && text) {
    ensure(isValidEmail(text), 400, "Invalid email");
    return normalizeEmail(text);
  }
  if (key.toLowerCase().includes("time")) return sanitizeTime(text, "00:00");
  if (rule.allowed && !rule.allowed.includes(text)) {
    throw new HttpError(400, `Invalid ${key}`);
  }
  return text.slice(0, 240);
}

function rowToCamel(row: any, schema: Schema) {
  const result: Record<string, unknown> = {};
  for (const [key, rule] of Object.entries(schema)) {
    result[key] = row?.[rule.column];
  }
  return result;
}

function tableColumns(schema: Schema) {
  return Object.values(schema).map((entry) => entry.column);
}

async function ensureSettingsRows(userId: string, legacy: Record<string, any>) {
  const inserts = [
    query(
      `INSERT INTO profile_visibility_settings
       (user_id, account_privacy, posts_visibility, replies_visibility, media_visibility, highlights_visibility, bio_visibility,
        location_visibility, website_visibility, followers_list_visibility, following_list_visibility, friends_list_visibility, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       ON CONFLICT (user_id) DO NOTHING`,
      [
        userId,
        legacy.privateAccount === true ? "private" : "public",
        legacy.profileVisibility?.posts || "everyone",
        legacy.profileVisibility?.replies || "everyone",
        legacy.profileVisibility?.media || "everyone",
        legacy.profileVisibility?.highlights || "everyone",
        legacy.profileVisibility?.bio || "everyone",
        legacy.profileVisibility?.location || "friends",
        legacy.profileVisibility?.website || "everyone",
        legacy.profileVisibility?.followers || "everyone",
        legacy.profileVisibility?.following || "everyone",
        legacy.profileVisibility?.friends || "friends",
        now(),
      ]
    ),
    query(
      `INSERT INTO privacy_settings
       (user_id, show_online_status, show_last_active, read_receipts_enabled, typing_indicator_enabled,
        who_can_message, hide_message_preview, sensitive_content_filter, updated_at)
       VALUES ($1, $2, $2, $3, TRUE, 'everyone', $4, $5, $6)
       ON CONFLICT (user_id) DO NOTHING`,
      [
        userId,
        legacy.activityStatus !== false,
        legacy.readReceipts !== false,
        legacy.messagePreview === false,
        legacy.sensitiveContent === true,
        now(),
      ]
    ),
    query(
      `INSERT INTO notification_settings
       (user_id, push_enabled, email_enabled, sound_enabled, vibration_enabled, recommendations_enabled,
        direct_messages_enabled, mentions_enabled, follows_enabled, notification_preview_enabled, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       ON CONFLICT (user_id) DO NOTHING`,
      [
        userId,
        legacy.pushNotifications !== false,
        legacy.emailNotifications === true,
        legacy.inAppSounds !== false,
        legacy.inAppHaptics !== false,
        legacy.notifyPosts !== false,
        legacy.notifyChats !== false,
        legacy.notifyMentions !== false,
        legacy.notifyFollows !== false,
        legacy.messagePreview !== false,
        now(),
      ]
    ),
    query(
      `INSERT INTO chat_settings
       (user_id, read_receipts_enabled, typing_indicators_enabled, online_status_enabled, show_last_seen,
        auto_download_images, auto_download_videos, data_saver_media, link_previews_enabled, updated_at)
       VALUES ($1, $2, TRUE, $3, $3, $4, $4, $5, TRUE, $6)
       ON CONFLICT (user_id) DO NOTHING`,
      [
        userId,
        legacy.readReceipts !== false,
        legacy.activityStatus !== false,
        legacy.autoDownload !== false,
        legacy.dataSaver === true,
        now(),
      ]
    ),
    query(
      `INSERT INTO appearance_settings
       (user_id, theme_mode, font_size, reduce_animations, haptic_feedback_enabled, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id) DO NOTHING`,
      [
        userId,
        themeFromIndex(legacy.themeIndex),
        fontFromScale(legacy.textScale),
        legacy.reduceMotion === true,
        legacy.inAppHaptics !== false,
        now(),
      ]
    ),
    query(
      `INSERT INTO accessibility_settings
       (user_id, text_size, reduce_motion, disable_autoplay, updated_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id) DO NOTHING`,
      [userId, fontFromScale(legacy.textScale), legacy.reduceMotion === true, legacy.autoPlayVideos === false, now()]
    ),
    query(
      `INSERT INTO data_storage_settings
       (user_id, data_saver_enabled, auto_download_enabled, auto_play_videos, updated_at)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id) DO NOTHING`,
      [userId, legacy.dataSaver === true, legacy.autoDownload !== false, legacy.autoPlayVideos !== false, now()]
    ),
    query(
      `INSERT INTO friend_settings (user_id, updated_at) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING`,
      [userId, now()]
    ),
    query(
      `INSERT INTO ai_personalization_settings (user_id, updated_at) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING`,
      [userId, now()]
    ),
    query(
      `INSERT INTO creator_settings (user_id, creator_mode_enabled, updated_at)
       VALUES ($1, $2, $3) ON CONFLICT (user_id) DO NOTHING`,
      [userId, legacy.isCreatorModeEnabled === true, now()]
    ),
    query(
      `INSERT INTO security_settings
       (user_id, two_factor_enabled, login_alerts_enabled, app_lock_enabled, biometrics_enabled, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id) DO NOTHING`,
      [
        userId,
        legacy.twoFactor === true,
        legacy.loginAlerts !== false,
        legacy.appLock === true,
        legacy.biometrics !== false,
        now(),
      ]
    ),
  ];
  await Promise.all(inserts);
}

async function legacySettings(userId: string) {
  const row = await queryOne(`SELECT settings FROM user_settings WHERE user_id = $1`, [userId]);
  return { ...legacyDefaults, ...(row?.settings || {}) };
}

async function updateLegacy(userId: string, patch: Record<string, unknown>, client?: any) {
  const executor = client || { query };
  const ts = now();
  await executor.query(
    `INSERT INTO user_settings (user_id, settings, updated_at)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id)
     DO UPDATE SET settings = COALESCE(user_settings.settings, '{}'::jsonb) || EXCLUDED.settings,
                   updated_at = EXCLUDED.updated_at`,
    [userId, patch, ts]
  );
}

async function auditSetting(userId: string, category: string, key: string, oldValue: unknown, newValue: unknown, request: any, sensitivity = "normal", client?: any) {
  const executor = client || { query };
  await executor.query(
    `INSERT INTO setting_audit_logs
     (id, user_id, setting_category, setting_key, old_value, new_value, changed_by, ip_address, user_agent, sensitivity_level, changed_at)
     VALUES ($1, $2, $3, $4, $5::jsonb, $6::jsonb, $2, $7, $8, $9, $10)`,
    [
      generateId(),
      userId,
      category,
      key,
      JSON.stringify(oldValue ?? null),
      JSON.stringify(newValue ?? null),
      String(request.ip || ""),
      String(request.headers?.["user-agent"] || ""),
      sensitivity,
      now(),
    ]
  );
}

async function rowFor(category: keyof typeof tableSchemas, userId: string) {
  const config = tableSchemas[category];
  const columns = tableColumns(config.schema).join(", ");
  const row = await queryOne(`SELECT ${columns}, updated_at FROM ${config.table} WHERE user_id = $1`, [userId]);
  return rowToCamel(row || {}, config.schema);
}

function legacyFromGroups(groups: any, existing: Record<string, any>) {
  const profile = groups.profile_visibility || {};
  const privacy = groups.privacy || {};
  const notifications = groups.notifications || {};
  const chats = groups.chats || {};
  const appearance = groups.appearance || {};
  const accessibility = groups.accessibility || {};
  const data = groups.data_storage || {};
  const security = groups.security || {};
  const ai_personalization = groups.ai_personalization || {};
  const creator = groups.creator || {};
  return {
    ...existing,
    privateAccount: profile.accountPrivacy === "private",
    activityStatus: privacy.showOnlineStatus !== false && chats.onlineStatusEnabled !== false,
    readReceipts: privacy.readReceiptsEnabled !== false && chats.readReceiptsEnabled !== false,
    messagePreview: notifications.notificationPreviewEnabled !== false && privacy.hideMessagePreview !== true,
    sensitiveContent: privacy.sensitiveContentFilter === true,
    twoFactor: security.twoFactorEnabled === true,
    loginAlerts: security.loginAlertsEnabled !== false,
    appLock: security.appLockEnabled === true,
    biometrics: security.biometricsEnabled !== false,
    pushNotifications: notifications.pushEnabled !== false,
    emailNotifications: notifications.emailEnabled === true,
    inAppSounds: notifications.soundEnabled !== false,
    inAppHaptics: notifications.vibrationEnabled !== false,
    notifyPosts: notifications.recommendationsEnabled !== false,
    notifyChats: notifications.directMessagesEnabled !== false,
    notifyMentions: notifications.mentionsEnabled !== false,
    notifyFollows: notifications.followsEnabled !== false,
    dataSaver: data.dataSaverEnabled === true,
    autoDownload: data.autoDownloadEnabled !== false,
    autoPlayVideos: data.autoPlayVideos !== false && accessibility.disableAutoplay !== true,
    reduceMotion: accessibility.reduceMotion === true || appearance.reduceAnimations === true,
    themeIndex: indexFromTheme(appearance.themeMode),
    textScale: scaleFromFont(accessibility.textSize || appearance.fontSize),
    whoCanMessage: chats.whoCanMessage || privacy.whoCanMessage || "everyone",
    whoCanAddToGroups: chats.whoCanAddToGroups || "friends",
    defaultFeedMode: groups.feed?.defaultFeedMode || existing.defaultFeedMode || "forYou",
    personalizationLevel: groups.feed?.personalizationLevel || existing.personalizationLevel || "balanced",
    contentSafetyLevel: privacy.contentSafetyLevel || "balanced",
    displayDensity: appearance.displayDensity || "comfortable",
    fontSize: appearance.fontSize || accessibility.textSize || "default",
    mediaQuality: data.mediaQuality || "auto",
    quietHours: notifications.quietHoursEnabled === true,
    showRecommendedPosts: groups.feed?.showRecommendedPosts !== false,
    showTrendingPosts: groups.feed?.showTrendingPosts !== false,
    showFriendsFirst: groups.feed?.showFriendsFirst === true,
    highContrast: accessibility.highContrast === true,
    boldText: accessibility.boldText === true || appearance.boldText === true,
    reduceTransparency: accessibility.reduceTransparency === true,
    largerTouchTargets: accessibility.largerTouchTargets === true,
    screenReaderEnhancedLabels: accessibility.screenReaderEnhancedLabels !== false,
    disableAutoplay: accessibility.disableAutoplay === true,
    aiPersonalizedFeed: ai_personalization.personalizedFeedEnabled !== false,
    aiFriendSuggestions: ai_personalization.aiFriendSuggestionsEnabled !== false,
    aiPostRecommendations: ai_personalization.aiPostRecommendationsEnabled !== false,
    aiSmartReplies: ai_personalization.aiSmartRepliesEnabled === true,
    creatorMode: creator.creatorModeEnabled === true,
    professionalMode: creator.professionalAccountEnabled === true,
    publicContactButton: creator.publicContactButtonEnabled === true,
    showCreatorBadge: creator.showCreatorBadge === true,
    isCreatorModeEnabled: creator.creatorModeEnabled === true,
    profileVisibility: {
      ...(existing.profileVisibility || {}),
      posts: profile.postsVisibility || "everyone",
      replies: profile.repliesVisibility || "everyone",
      media: profile.mediaVisibility || "everyone",
      highlights: profile.highlightsVisibility || "everyone",
      about: profile.aboutVisibility || "everyone",
      bio: profile.bioVisibility || "everyone",
      location: profile.locationVisibility || "friends",
      website: profile.websiteVisibility || "everyone",
      followers: profile.followersListVisibility || "everyone",
      following: profile.followingListVisibility || "everyone",
      friends: profile.friendsListVisibility || "friends",
    },
  };
}

async function buildSettingsBundle(userId: string) {
  const [user, existing, feed] = await Promise.all([
    queryOne(
      `SELECT user_id, email, username, display_name, avatar_url, is_verified, created_at, last_seen_at, details
       FROM users WHERE user_id = $1 AND deleted_at IS NULL`,
      [userId]
    ),
    legacySettings(userId),
    getFeedPreferences(userId),
  ]);
  ensure(user, 404, "User not found");
  await ensureSettingsRows(userId, existing);
  const categories = await Promise.all(
    (Object.keys(tableSchemas) as Array<keyof typeof tableSchemas>).map(async (key) => [key, await rowFor(key, userId)])
  );
  const groups = Object.fromEntries(categories);
  groups.feed = {
    defaultFeedMode: existing.defaultFeedMode || "forYou",
    personalizationLevel: existing.personalizationLevel || feed.lens || "balanced",
    useActivityForRecommendations: existing.useActivityForRecommendations !== false,
    useFollowsForRecommendations: existing.useFollowsForRecommendations !== false,
    useLikesForRecommendations: existing.useLikesForRecommendations !== false,
    useRepliesForRecommendations: existing.useRepliesForRecommendations !== false,
    showRecommendedPosts: feed.discoveryIntensity > 0,
    showTrendingPosts: existing.showTrendingPosts !== false,
    showFriendsFirst: feed.friendPriority >= 0.35,
    showFollowingFirst: existing.showFollowingFirst === true,
    reduceSensitiveContent: feed.reduceSensitiveContent,
    reducePoliticalContent: feed.reducePoliticalContent,
    autoplayMedia: existing.autoPlayVideos !== false,
    mediaQuality: groups.data_storage.mediaQuality || "auto",
    dataSaverEnabled: groups.data_storage.dataSaverEnabled === true,
    preferredLanguages: feed.preferredLanguages,
    mutedKeywords: feed.mutedKeywords,
  };

  const legacy = legacyFromGroups(groups, existing);

  const completionSignals = [
    Boolean(user.avatar_url),
    Boolean(user.display_name),
    Boolean(user.username),
    Boolean(user.email),
    Boolean(user.details?.bio),
  ];
  const completion = Math.round((completionSignals.filter(Boolean).length / completionSignals.length) * 100);
  const securityScore = [
    groups.security.loginAlertsEnabled !== false,
    groups.security.suspiciousLoginProtectionEnabled !== false,
    groups.security.twoFactorEnabled === true,
    groups.security.trustedDevicesEnabled !== false,
  ].filter(Boolean).length * 25;

  return {
    account: {
      id: user.user_id,
      displayName: user.display_name || user.username,
      username: user.username,
      email: user.email,
      avatarUrl: user.avatar_url || "",
      isVerified: user.is_verified === true,
      accountType: groups.creator.creatorModeEnabled ? "creator" : (existing.accountType || "personal"),
      language: existing.languageLabel || "English",
      countryRegion: existing.countryRegion || "India",
      profileCompletion: completion,
      createdAt: user.created_at?.toISOString?.() || null,
    },
    profile_visibility: groups.profile_visibility,
    privacy: groups.privacy,
    security: groups.security,
    notifications: groups.notifications,
    chats: groups.chats,
    feed: groups.feed,
    friends: groups.friends,
    appearance: groups.appearance,
    accessibility: groups.accessibility,
    data_storage: groups.data_storage,
    ai_personalization: groups.ai_personalization,
    creator: groups.creator,
    capabilities: {
      passkeys: false,
      smsOtp: false,
      profileQr: true,
      creatorAnalytics: true,
      accountDeletionRecoveryDays: 30,
    },
    warnings: {
      privacy: groups.profile_visibility.accountPrivacy === "private" ? [] : ["public_account"],
      security: securityScore < 75 ? ["enable_two_factor"] : [],
      data: [],
    },
    allowed_values: {
      visibility: visibilityValues,
      audience: audienceValues,
      themeMode: themeValues,
      displayDensity: densityValues,
      fontSize: fontSizeValues,
      feedMode: feedModeValues,
      personalizationLevel: personalizationValues,
      mediaQuality: mediaQualityValues,
      accountType: accountTypeValues,
    },
    locked_settings: {
      notifications: ["securityAlertsEnabled"],
    },
    requires_reauth: {
      account: ["email", "phone", "password"],
      security: ["twoFactorEnabled", "trustedDevicesEnabled"],
      danger: ["deactivate", "delete"],
    },
    feature_availability: {
      creator: true,
      aiPersonalization: true,
      monetization: false,
    },
    legacy,
    last_updated: new Date().toISOString(),
  };
}

function categoryPatchFromLegacy(body: Record<string, unknown>) {
  return {
    profile_visibility: {
      accountPrivacy: body.privateAccount === true ? "private" : body.privateAccount === false ? "public" : undefined,
    },
    privacy: {
      showOnlineStatus: body.activityStatus,
      showLastActive: body.activityStatus,
      readReceiptsEnabled: body.readReceipts,
      hideMessagePreview: body.messagePreview === undefined ? undefined : body.messagePreview !== true,
      sensitiveContentFilter: body.sensitiveContent,
      whoCanMessage: body.whoCanMessage,
      contentSafetyLevel: body.contentSafetyLevel,
    },
    security: {
      twoFactorEnabled: body.twoFactor,
      loginAlertsEnabled: body.loginAlerts,
      appLockEnabled: body.appLock,
      biometricsEnabled: body.biometrics,
    },
    notifications: {
      pushEnabled: body.pushNotifications,
      emailEnabled: body.emailNotifications,
      soundEnabled: body.inAppSounds,
      vibrationEnabled: body.inAppHaptics,
      recommendationsEnabled: body.notifyPosts,
      directMessagesEnabled: body.notifyChats,
      mentionsEnabled: body.notifyMentions,
      followsEnabled: body.notifyFollows,
      notificationPreviewEnabled: body.messagePreview,
      quietHoursEnabled: body.quietHours,
    },
    chats: {
      whoCanMessage: body.whoCanMessage,
      whoCanAddToGroups: body.whoCanAddToGroups,
      readReceiptsEnabled: body.readReceipts,
      onlineStatusEnabled: body.activityStatus,
      showLastSeen: body.activityStatus,
      autoDownloadImages: body.autoDownload,
      autoDownloadVideos: body.autoDownload,
      dataSaverMedia: body.dataSaver,
    },
    appearance: {
      themeMode: body.themeIndex === undefined ? undefined : themeFromIndex(body.themeIndex),
      fontSize: body.textScale === undefined ? undefined : fontFromScale(body.textScale),
      displayDensity: body.displayDensity,
      reduceAnimations: body.reduceMotion,
      hapticFeedbackEnabled: body.inAppHaptics,
      boldText: body.boldText,
    },
    accessibility: {
      textSize: body.textScale === undefined ? undefined : fontFromScale(body.textScale),
      highContrast: body.highContrast,
      boldText: body.boldText,
      reduceMotion: body.reduceMotion,
      reduceTransparency: body.reduceTransparency,
      largerTouchTargets: body.largerTouchTargets,
      screenReaderEnhancedLabels: body.screenReaderEnhancedLabels,
      disableAutoplay: body.autoPlayVideos === undefined ? undefined : body.autoPlayVideos !== true,
    },
    data_storage: {
      dataSaverEnabled: body.dataSaver,
      autoDownloadEnabled: body.autoDownload,
      autoPlayVideos: body.autoPlayVideos,
      mediaQuality: body.mediaQuality,
    },
    friends: {
      peopleYouMayKnow: body.aiFriendSuggestions,
      showMutualFriendActivity: body.showFriendsFirst,
    },
    ai_personalization: {
      personalizedFeedEnabled: body.aiPersonalizedFeed,
      aiFriendSuggestionsEnabled: body.aiFriendSuggestions,
      aiPostRecommendationsEnabled: body.aiPostRecommendations,
      aiSmartRepliesEnabled: body.aiSmartReplies,
    },
    creator: {
      creatorModeEnabled: body.creatorMode ?? body.isCreatorModeEnabled,
      professionalAccountEnabled: body.professionalMode,
      publicContactButtonEnabled: body.publicContactButton,
      showCreatorBadge: body.showCreatorBadge,
    },
  };
}

function cleanPatch(input: Record<string, unknown>, schema: Schema) {
  const out: Record<string, unknown> = {};
  for (const [key, rule] of Object.entries(schema)) {
    if (input[key] !== undefined) {
      out[key] = sanitizeValue(key, input[key], rule);
    }
  }
  return out;
}

async function patchTable(userId: string, category: keyof typeof tableSchemas, input: Record<string, unknown>, request: any, client?: any) {
  const config = tableSchemas[category];
  const patch = cleanPatch(input, config.schema);
  if (Object.keys(patch).length === 0) return;
  const previous = await rowFor(category, userId);
  const setClauses: string[] = [];
  const values: unknown[] = [userId];
  for (const [key, value] of Object.entries(patch)) {
    const column = config.schema[key].column;
    values.push(value);
    setClauses.push(`${column} = $${values.length}`);
  }
  values.push(now());
  const executor = client || { query };
  await executor.query(
    `UPDATE ${config.table}
     SET ${setClauses.join(", ")}, updated_at = $${values.length}
     WHERE user_id = $1`,
    values
  );
  for (const key of Object.keys(patch)) {
    const column = config.schema[key].column;
    const sensitive = config.sensitive?.includes(column) ? "sensitive" : "normal";
    await auditSetting(userId, category, key, previous[key], patch[key], request, sensitive, client);
  }
}

async function applyLegacyPatch(userId: string, body: Record<string, unknown>, request: any) {
  const patches = categoryPatchFromLegacy(body);
  await ensureSettingsRows(userId, await legacySettings(userId));
  await withTransaction(async (client) => {
    for (const [category, patch] of Object.entries(patches)) {
      await patchTable(userId, category as keyof typeof tableSchemas, patch as Record<string, unknown>, request, client);
    }
    await updateLegacy(userId, body, client);
  });
}

async function patchCategory(userId: string, category: keyof typeof tableSchemas, body: Record<string, unknown>, request: any) {
  await ensureSettingsRows(userId, await legacySettings(userId));
  await withTransaction(async (client) => {
    await patchTable(userId, category, body, request, client);
  });
}

async function requirePassword(userId: string, body: any) {
  const password = String(body?.password || "");
  if (!password) {
    throw new HttpError(401, "Re-authentication required");
  }
  const user = await queryOne(`SELECT password_hash FROM users WHERE user_id = $1`, [userId]);
  ensure(verifyPassword(password, user?.password_hash), 401, "Invalid password");
}

async function createAccountLifecycleRequest({
  userId,
  requestType,
  reason,
  recoveryUntil,
}: {
  userId: string;
  requestType: "deactivate" | "delete";
  reason: string;
  recoveryUntil?: Date;
}) {
  const requestId = generateId();
  const ts = now();
  try {
    await query(
      `INSERT INTO account_deletion_requests (request_id, user_id, request_type, status, reason, recovery_until, created_at, updated_at)
       VALUES ($1, $2, $3, 'pending', $4, $5, $6, $6)`,
      [requestId, userId, requestType, reason.slice(0, 500), recoveryUntil || null, ts]
    );
    return { requestId, createdAt: ts };
  } catch (error: any) {
    if (!["42703", "42804", "23502"].includes(String(error?.code || ""))) {
      throw error;
    }
  }

  const user = await queryOne(`SELECT id FROM users WHERE user_id = $1`, [userId]);
  ensure(user?.id, 500, "Account lifecycle table is not compatible with this database");
  const scheduledAt = recoveryUntil || new Date(ts.getTime() + 30 * 24 * 60 * 60 * 1000);
  await query(
    `INSERT INTO account_deletion_requests (id, user_id, reason, scheduled_delete_at, requested_at)
     VALUES ($1, $2, $3, $4, $5)`,
    [requestId, user.id, reason.slice(0, 500), scheduledAt, ts]
  );
  return { requestId, createdAt: ts };
}

function summaryFromBundle(bundle: any) {
  return {
    accountCard: {
      displayName: bundle.account.displayName,
      username: bundle.account.username,
      avatarUrl: bundle.account.avatarUrl,
      isVerified: bundle.account.isVerified,
      profileCompletion: bundle.account.profileCompletion,
      accountType: bundle.account.accountType,
    },
    privacyStatus: bundle.profile_visibility.accountPrivacy === "private" ? "private" : "public",
    securityScore: bundle.warnings.security.length ? 50 : 100,
    notificationStatus: bundle.notifications.pushEnabled ? "on" : "off",
    appearanceMode: bundle.appearance.themeMode,
    legacy: bundle.legacy,
    warnings: bundle.warnings,
    last_updated: bundle.last_updated,
  };
}

const searchableSettings = [
  ["Account", "Personal information, username, email, phone, password, verification", "account"],
  ["Profile & Visibility", "Private account, posts, replies, media, highlights, profile preview", "profile_visibility"],
  ["Privacy", "Activity status, mentions, tags, messages, blocked users, muted words", "privacy"],
  ["Security", "Password, two factor, devices, login alerts, sessions", "security"],
  ["Notifications", "Push, email, likes, comments, follows, quiet hours", "notifications"],
  ["Chats & Messages", "Message privacy, read receipts, group invites, media storage", "chats"],
  ["Feed & Content", "For You, personalization, muted topics, sensitive content", "feed"],
  ["Friends & Social Graph", "Friend requests, close friends, people you may know", "friends"],
  ["Appearance", "Theme, accent color, density, font size", "appearance"],
  ["Accessibility", "High contrast, reduce motion, text size, touch targets", "accessibility"],
  ["Data & Storage", "Data saver, cache, export, download data", "data_storage"],
  ["AI & Personalization", "AI recommendations, smart replies, personalization controls", "ai_personalization"],
  ["Creator / Professional", "Creator mode, badge, analytics, public contact", "creator"],
  ["Help & Support", "Help center, report problem, bug report, support tickets", "support"],
  ["Legal & About", "Terms, privacy policy, app version, licenses", "legal"],
  ["Danger Zone", "Logout, deactivate account, delete account", "danger"],
];

export default async function settingsService(app: any) {
  app.get("/api/settings", { preHandler: requireAuth }, async (request: any) => {
    return buildSettingsBundle(request.user.userId);
  });

  app.get("/api/settings/summary", { preHandler: requireAuth }, async (request: any) => {
    return summaryFromBundle(await buildSettingsBundle(request.user.userId));
  });

  app.get("/api/settings/search", { preHandler: requireAuth }, async (request: any) => {
    const q = String(request.query?.q || "").trim().toLowerCase();
    const items = searchableSettings
      .filter(([title, subtitle, key]) => !q || `${title} ${subtitle} ${key}`.toLowerCase().includes(q))
      .map(([title, subtitle, category]) => ({ title, subtitle, category }));
    return {
      query: q,
      groups: items.reduce<Record<string, any[]>>((acc, item) => {
        const group = item.category === "danger" ? "Danger Zone" : "Settings";
        acc[group] = [...(acc[group] || []), item];
        return acc;
      }, {}),
      items,
    };
  });

  app.patch("/api/settings", { preHandler: requireAuth }, async (request: any) => {
    await applyLegacyPatch(request.user.userId, request.body || {}, request);
    return buildSettingsBundle(request.user.userId);
  });

  app.patch("/api/settings/account", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    const userPatch: string[] = [];
    const values: unknown[] = [request.user.userId];
    if (body.displayName !== undefined) {
      values.push(String(body.displayName || "").trim().slice(0, 80));
      userPatch.push(`display_name = $${values.length}, display_name_lower = LOWER($${values.length})`);
    }
    if (body.username !== undefined) {
      const username = normalizeUsername(body.username);
      ensure(isValidUsername(username), 400, "Invalid username");
      values.push(username);
      userPatch.push(`username = $${values.length}, username_lower = $${values.length}`);
    }
    if (userPatch.length) {
      values.push(now());
      await query(`UPDATE users SET ${userPatch.join(", ")}, updated_at = $${values.length} WHERE user_id = $1`, values);
    }
    await updateLegacy(request.user.userId, {
      languageLabel: body.language || body.languageLabel,
      countryRegion: body.countryRegion,
      accountType: body.accountType,
    });
    await auditSetting(request.user.userId, "account", "profile", null, body, request, "sensitive");
    return buildSettingsBundle(request.user.userId);
  });

  for (const [path, category] of [
    ["/api/settings/profile-visibility", "profile_visibility"],
    ["/api/settings/privacy", "privacy"],
    ["/api/settings/security", "security"],
    ["/api/settings/notifications", "notifications"],
    ["/api/settings/chats", "chats"],
    ["/api/settings/friends", "friends"],
    ["/api/settings/appearance", "appearance"],
    ["/api/settings/accessibility", "accessibility"],
    ["/api/settings/data-storage", "data_storage"],
    ["/api/settings/ai", "ai_personalization"],
    ["/api/settings/creator", "creator"],
  ] as const) {
    app.patch(path, { preHandler: requireAuth }, async (request: any) => {
      await patchCategory(request.user.userId, category, request.body || {}, request);
      const bundle = await buildSettingsBundle(request.user.userId);
      return bundle;
    });
  }

  app.patch("/api/settings/feed", { preHandler: requireAuth }, async (request: any) => {
    const body = request.body || {};
    await updateFeedPreferences(request.user.userId, {
      lens: body.personalizationLevel,
      reduceSensitiveContent: body.reduceSensitiveContent,
      reducePoliticalContent: body.reducePoliticalContent,
      preferredLanguages: body.preferredLanguages,
      mutedKeywords: body.mutedKeywords,
      discoveryIntensity: body.showRecommendedPosts === false ? 0 : undefined,
      friendPriority: body.showFriendsFirst === true ? 0.6 : undefined,
    });
    await updateLegacy(request.user.userId, {
      defaultFeedMode: body.defaultFeedMode,
      personalizationLevel: body.personalizationLevel,
      useActivityForRecommendations: body.useActivityForRecommendations,
      useFollowsForRecommendations: body.useFollowsForRecommendations,
      useLikesForRecommendations: body.useLikesForRecommendations,
      useRepliesForRecommendations: body.useRepliesForRecommendations,
      showTrendingPosts: body.showTrendingPosts,
      showFollowingFirst: body.showFollowingFirst,
      autoPlayVideos: body.autoplayMedia,
    });
    await auditSetting(request.user.userId, "feed", "preferences", null, body, request);
    return buildSettingsBundle(request.user.userId);
  });

  app.post("/api/settings/privacy-checkup", { preHandler: requireAuth }, async (request: any) => {
    const bundle = await buildSettingsBundle(request.user.userId);
    return {
      score: bundle.profile_visibility.accountPrivacy === "private" ? 92 : 70,
      recommendations: [
        bundle.profile_visibility.accountPrivacy === "private" ? null : "Turn on Private account if you want approved followers only.",
        bundle.privacy.allowFindByEmail ? "Disable find-by-email for stronger privacy." : null,
        bundle.privacy.reviewTagsBeforeShowing ? null : "Review tags before they appear on your profile.",
      ].filter(Boolean),
    };
  });

  app.post("/api/settings/security-checkup", { preHandler: requireAuth }, async (request: any) => {
    const bundle = await buildSettingsBundle(request.user.userId);
    return {
      score: bundle.warnings.security.length ? 50 : 100,
      recommendations: [
        bundle.security.twoFactorEnabled ? null : "Enable two-factor authentication.",
        bundle.security.loginAlertsEnabled ? null : "Keep login alerts enabled.",
        bundle.security.trustedDevicesEnabled ? null : "Use trusted device protection.",
      ].filter(Boolean),
    };
  });

  app.post("/api/settings/reset-feed-personalization", { preHandler: requireAuth }, async (request: any) => {
    await withTransaction(async (client) => {
      await client.query(`DELETE FROM feed_feedback WHERE user_id = $1`, [request.user.userId]);
      await client.query(`DELETE FROM feed_served_history WHERE user_id = $1`, [request.user.userId]);
      await client.query(`DELETE FROM feed_preferences WHERE user_id = $1`, [request.user.userId]);
    });
    await auditSetting(request.user.userId, "feed", "reset_personalization", null, { reset: true }, request, "sensitive");
    return { reset: true, settings: await buildSettingsBundle(request.user.userId) };
  });

  app.post("/api/settings/clear-search-history", { preHandler: requireAuth }, async (request: any) => {
    await auditSetting(request.user.userId, "data_storage", "clear_search_history", null, { cleared: true }, request);
    return { cleared: true };
  });

  app.post("/api/settings/clear-cache-metadata", { preHandler: requireAuth }, async (request: any) => {
    await ensureSettingsRows(request.user.userId, await legacySettings(request.user.userId));
    await query(`UPDATE data_storage_settings SET clear_cache_metadata_at = $2, updated_at = $2 WHERE user_id = $1`, [request.user.userId, now()]);
    await auditSetting(request.user.userId, "data_storage", "clear_cache_metadata", null, { cleared: true }, request);
    return { cleared: true };
  });

  app.post("/api/data-export", { preHandler: requireAuth }, async (request: any) => {
    const exportId = generateId();
    const ts = now();
    await query(
      `INSERT INTO data_exports (export_id, user_id, status, format, payload, created_at, completed_at)
       VALUES ($1, $2, 'queued', 'json', $3, $4, NULL)`,
      [exportId, request.user.userId, JSON.stringify({ source: "settings" }), ts]
    );
    return { id: exportId, status: "queued", createdAt: ts.toISOString() };
  });

  app.get("/api/data-export/:id", { preHandler: requireAuth }, async (request: any) => {
    const id = String(request.params.id || "");
    const row = await queryOne(
      `SELECT export_id, status, format, payload, created_at, completed_at
       FROM data_exports WHERE export_id = $1 AND user_id = $2`,
      [id, request.user.userId]
    );
    ensure(row, 404, "Export not found");
    return {
      id: row.export_id,
      status: row.status,
      format: row.format,
      payload: row.payload || {},
      createdAt: row.created_at?.toISOString?.() || null,
      completedAt: row.completed_at?.toISOString?.() || null,
    };
  });

  app.post("/api/account/deactivate", { preHandler: requireAuth }, async (request: any) => {
    await requirePassword(request.user.userId, request.body || {});
    const { requestId } = await createAccountLifecycleRequest({
      userId: request.user.userId,
      requestType: "deactivate",
      reason: String(request.body?.reason || ""),
    });
    await auditSetting(request.user.userId, "danger", "deactivate", null, { requestId }, request, "critical");
    return { deactivated: false, pending: true, requestId };
  });

  app.post("/api/account/delete-request", { preHandler: requireAuth }, async (request: any) => {
    await requirePassword(request.user.userId, request.body || {});
    const confirmation = String(request.body?.confirmation || "").trim();
    const user = await queryOne(`SELECT username FROM users WHERE user_id = $1`, [request.user.userId]);
    ensure(confirmation === "DELETE" || confirmation === user?.username, 400, "Confirmation required");
    const ts = now();
    const recoveryUntil = new Date(ts.getTime() + 30 * 24 * 60 * 60 * 1000);
    const created = await createAccountLifecycleRequest({
      userId: request.user.userId,
      requestType: "delete",
      reason: String(request.body?.reason || ""),
      recoveryUntil,
    });
    await auditSetting(request.user.userId, "danger", "delete_request", null, { requestId: created.requestId }, request, "critical");
    return { deletionRequested: true, requestId: created.requestId, recoveryUntil: recoveryUntil.toISOString() };
  });

  app.post("/api/account/delete-cancel", { preHandler: requireAuth }, async (request: any) => {
    const ts = now();
    let canceled = false;
    try {
      const result = await query(
        `UPDATE account_deletion_requests
         SET status = 'canceled', canceled_at = $2, updated_at = $2
         WHERE user_id = $1 AND status = 'pending' AND request_type = 'delete'`,
        [request.user.userId, ts]
      );
      canceled = (result.rowCount || 0) > 0;
    } catch (error: any) {
      if (!["42703", "42804"].includes(String(error?.code || ""))) {
        throw error;
      }
      const user = await queryOne(`SELECT id FROM users WHERE user_id = $1`, [request.user.userId]);
      ensure(user?.id, 500, "Account lifecycle table is not compatible with this database");
      const result = await query(
        `UPDATE account_deletion_requests
         SET cancelled_at = $2
         WHERE user_id = $1 AND cancelled_at IS NULL AND completed_at IS NULL`,
        [user.id, ts]
      );
      canceled = (result.rowCount || 0) > 0;
    }
    await auditSetting(request.user.userId, "danger", "delete_cancel", null, { canceled }, request, "critical");
    return { canceled };
  });

  app.post("/api/sessions/logout-all", { preHandler: requireAuth }, async (request: any) => {
    await query(`UPDATE refresh_tokens SET revoked_at = $1 WHERE user_id = $2 AND revoked_at IS NULL`, [now(), request.user.userId]);
    await auditSetting(request.user.userId, "security", "logout_all", null, { revoked: true }, request, "sensitive");
    return { success: true };
  });

  app.delete("/api/sessions/:sessionId", { preHandler: requireAuth }, async (request: any) => {
    const sessionId = String(request.params.sessionId || "");
    const result = await query(
      `UPDATE refresh_tokens SET revoked_at = $3
       WHERE user_id = $1 AND refresh_token_id = $2 AND revoked_at IS NULL`,
      [request.user.userId, sessionId, now()]
    );
    await auditSetting(request.user.userId, "security", "revoke_session", null, { sessionId }, request, "sensitive");
    return { revoked: (result.rowCount || 0) > 0 };
  });

  app.get("/api/settings/audit", { preHandler: requireAuth }, async (request: any) => {
    const rows = await queryMany(
      `SELECT setting_category, setting_key, sensitivity_level, changed_at
       FROM setting_audit_logs
       WHERE user_id = $1
       ORDER BY changed_at DESC
       LIMIT 50`,
      [request.user.userId]
    );
    return { items: rows.map((row) => ({
      category: row.setting_category,
      key: row.setting_key,
      sensitivity: row.sensitivity_level,
      changedAt: row.changed_at?.toISOString?.() || null,
    })) };
  });
}

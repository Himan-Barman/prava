import 'dart:convert';

import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';

class SettingsState {
  SettingsState({
    required this.privateAccount,
    required this.activityStatus,
    required this.readReceipts,
    required this.messagePreview,
    required this.sensitiveContent,
    required this.locationSharing,
    required this.twoFactor,
    required this.loginAlerts,
    required this.appLock,
    required this.biometrics,
    required this.pushNotifications,
    required this.emailNotifications,
    required this.inAppSounds,
    required this.inAppHaptics,
    required this.notifyPosts,
    required this.notifyChats,
    required this.notifyMentions,
    required this.notifyFollows,
    required this.dataSaver,
    required this.autoDownload,
    required this.autoPlayVideos,
    required this.reduceMotion,
    required this.themeIndex,
    required this.textScale,
    required this.languageLabel,
    required this.whoCanMessage,
    required this.whoCanAddToGroups,
    required this.defaultFeedMode,
    required this.personalizationLevel,
    required this.contentSafetyLevel,
    required this.displayDensity,
    required this.fontSize,
    required this.mediaQuality,
    required this.quietHours,
    required this.showRecommendedPosts,
    required this.showTrendingPosts,
    required this.showFriendsFirst,
    required this.highContrast,
    required this.boldText,
    required this.reduceTransparency,
    required this.largerTouchTargets,
    required this.screenReaderEnhancedLabels,
    required this.disableAutoplay,
    required this.aiPersonalizedFeed,
    required this.aiFriendSuggestions,
    required this.aiPostRecommendations,
    required this.aiSmartReplies,
    required this.creatorMode,
    required this.professionalMode,
    required this.publicContactButton,
    required this.showCreatorBadge,
  });

  final bool privateAccount;
  final bool activityStatus;
  final bool readReceipts;
  final bool messagePreview;
  final bool sensitiveContent;
  final bool locationSharing;
  final bool twoFactor;
  final bool loginAlerts;
  final bool appLock;
  final bool biometrics;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool inAppSounds;
  final bool inAppHaptics;
  final bool notifyPosts;
  final bool notifyChats;
  final bool notifyMentions;
  final bool notifyFollows;
  final bool dataSaver;
  final bool autoDownload;
  final bool autoPlayVideos;
  final bool reduceMotion;
  final int themeIndex;
  final double textScale;
  final String languageLabel;
  final String whoCanMessage;
  final String whoCanAddToGroups;
  final String defaultFeedMode;
  final String personalizationLevel;
  final String contentSafetyLevel;
  final String displayDensity;
  final String fontSize;
  final String mediaQuality;
  final bool quietHours;
  final bool showRecommendedPosts;
  final bool showTrendingPosts;
  final bool showFriendsFirst;
  final bool highContrast;
  final bool boldText;
  final bool reduceTransparency;
  final bool largerTouchTargets;
  final bool screenReaderEnhancedLabels;
  final bool disableAutoplay;
  final bool aiPersonalizedFeed;
  final bool aiFriendSuggestions;
  final bool aiPostRecommendations;
  final bool aiSmartReplies;
  final bool creatorMode;
  final bool professionalMode;
  final bool publicContactButton;
  final bool showCreatorBadge;

  factory SettingsState.defaults() {
    return SettingsState(
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
      textScale: 1.0,
      languageLabel: 'English',
      whoCanMessage: 'everyone',
      whoCanAddToGroups: 'friends',
      defaultFeedMode: 'forYou',
      personalizationLevel: 'balanced',
      contentSafetyLevel: 'balanced',
      displayDensity: 'comfortable',
      fontSize: 'default',
      mediaQuality: 'auto',
      quietHours: false,
      showRecommendedPosts: true,
      showTrendingPosts: true,
      showFriendsFirst: false,
      highContrast: false,
      boldText: false,
      reduceTransparency: false,
      largerTouchTargets: false,
      screenReaderEnhancedLabels: true,
      disableAutoplay: false,
      aiPersonalizedFeed: true,
      aiFriendSuggestions: true,
      aiPostRecommendations: true,
      aiSmartReplies: false,
      creatorMode: false,
      professionalMode: false,
      publicContactButton: false,
      showCreatorBadge: false,
    );
  }

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    final defaults = SettingsState.defaults();
    return SettingsState(
      privateAccount: json['privateAccount'] is bool
          ? json['privateAccount']
          : defaults.privateAccount,
      activityStatus: json['activityStatus'] is bool
          ? json['activityStatus']
          : defaults.activityStatus,
      readReceipts: json['readReceipts'] is bool
          ? json['readReceipts']
          : defaults.readReceipts,
      messagePreview: json['messagePreview'] is bool
          ? json['messagePreview']
          : defaults.messagePreview,
      sensitiveContent: json['sensitiveContent'] is bool
          ? json['sensitiveContent']
          : defaults.sensitiveContent,
      locationSharing: json['locationSharing'] is bool
          ? json['locationSharing']
          : defaults.locationSharing,
      twoFactor: json['twoFactor'] is bool
          ? json['twoFactor']
          : defaults.twoFactor,
      loginAlerts: json['loginAlerts'] is bool
          ? json['loginAlerts']
          : defaults.loginAlerts,
      appLock: json['appLock'] is bool ? json['appLock'] : defaults.appLock,
      biometrics: json['biometrics'] is bool
          ? json['biometrics']
          : defaults.biometrics,
      pushNotifications: json['pushNotifications'] is bool
          ? json['pushNotifications']
          : defaults.pushNotifications,
      emailNotifications: json['emailNotifications'] is bool
          ? json['emailNotifications']
          : defaults.emailNotifications,
      inAppSounds: json['inAppSounds'] is bool
          ? json['inAppSounds']
          : defaults.inAppSounds,
      inAppHaptics: json['inAppHaptics'] is bool
          ? json['inAppHaptics']
          : defaults.inAppHaptics,
      notifyPosts: json['notifyPosts'] is bool
          ? json['notifyPosts']
          : defaults.notifyPosts,
      notifyChats: json['notifyChats'] is bool
          ? json['notifyChats']
          : defaults.notifyChats,
      notifyMentions: json['notifyMentions'] is bool
          ? json['notifyMentions']
          : defaults.notifyMentions,
      notifyFollows: json['notifyFollows'] is bool
          ? json['notifyFollows']
          : defaults.notifyFollows,
      dataSaver: json['dataSaver'] is bool
          ? json['dataSaver']
          : defaults.dataSaver,
      autoDownload: json['autoDownload'] is bool
          ? json['autoDownload']
          : defaults.autoDownload,
      autoPlayVideos: json['autoPlayVideos'] is bool
          ? json['autoPlayVideos']
          : defaults.autoPlayVideos,
      reduceMotion: json['reduceMotion'] is bool
          ? json['reduceMotion']
          : defaults.reduceMotion,
      themeIndex: json['themeIndex'] is int
          ? json['themeIndex'] as int
          : int.tryParse(json['themeIndex']?.toString() ?? '') ??
                defaults.themeIndex,
      textScale: json['textScale'] is num
          ? (json['textScale'] as num).toDouble()
          : double.tryParse(json['textScale']?.toString() ?? '') ??
                defaults.textScale,
      languageLabel:
          json['languageLabel']?.toString() ?? defaults.languageLabel,
      whoCanMessage:
          json['whoCanMessage']?.toString() ?? defaults.whoCanMessage,
      whoCanAddToGroups:
          json['whoCanAddToGroups']?.toString() ?? defaults.whoCanAddToGroups,
      defaultFeedMode:
          json['defaultFeedMode']?.toString() ?? defaults.defaultFeedMode,
      personalizationLevel:
          json['personalizationLevel']?.toString() ??
          defaults.personalizationLevel,
      contentSafetyLevel:
          json['contentSafetyLevel']?.toString() ?? defaults.contentSafetyLevel,
      displayDensity:
          json['displayDensity']?.toString() ?? defaults.displayDensity,
      fontSize: json['fontSize']?.toString() ?? defaults.fontSize,
      mediaQuality: json['mediaQuality']?.toString() ?? defaults.mediaQuality,
      quietHours: json['quietHours'] is bool
          ? json['quietHours']
          : defaults.quietHours,
      showRecommendedPosts: json['showRecommendedPosts'] is bool
          ? json['showRecommendedPosts']
          : defaults.showRecommendedPosts,
      showTrendingPosts: json['showTrendingPosts'] is bool
          ? json['showTrendingPosts']
          : defaults.showTrendingPosts,
      showFriendsFirst: json['showFriendsFirst'] is bool
          ? json['showFriendsFirst']
          : defaults.showFriendsFirst,
      highContrast: json['highContrast'] is bool
          ? json['highContrast']
          : defaults.highContrast,
      boldText: json['boldText'] is bool ? json['boldText'] : defaults.boldText,
      reduceTransparency: json['reduceTransparency'] is bool
          ? json['reduceTransparency']
          : defaults.reduceTransparency,
      largerTouchTargets: json['largerTouchTargets'] is bool
          ? json['largerTouchTargets']
          : defaults.largerTouchTargets,
      screenReaderEnhancedLabels: json['screenReaderEnhancedLabels'] is bool
          ? json['screenReaderEnhancedLabels']
          : defaults.screenReaderEnhancedLabels,
      disableAutoplay: json['disableAutoplay'] is bool
          ? json['disableAutoplay']
          : defaults.disableAutoplay,
      aiPersonalizedFeed: json['aiPersonalizedFeed'] is bool
          ? json['aiPersonalizedFeed']
          : defaults.aiPersonalizedFeed,
      aiFriendSuggestions: json['aiFriendSuggestions'] is bool
          ? json['aiFriendSuggestions']
          : defaults.aiFriendSuggestions,
      aiPostRecommendations: json['aiPostRecommendations'] is bool
          ? json['aiPostRecommendations']
          : defaults.aiPostRecommendations,
      aiSmartReplies: json['aiSmartReplies'] is bool
          ? json['aiSmartReplies']
          : defaults.aiSmartReplies,
      creatorMode: json['creatorMode'] is bool
          ? json['creatorMode']
          : defaults.creatorMode,
      professionalMode: json['professionalMode'] is bool
          ? json['professionalMode']
          : defaults.professionalMode,
      publicContactButton: json['publicContactButton'] is bool
          ? json['publicContactButton']
          : defaults.publicContactButton,
      showCreatorBadge: json['showCreatorBadge'] is bool
          ? json['showCreatorBadge']
          : defaults.showCreatorBadge,
    );
  }

  SettingsState copyWith({
    bool? privateAccount,
    bool? activityStatus,
    bool? readReceipts,
    bool? messagePreview,
    bool? sensitiveContent,
    bool? locationSharing,
    bool? twoFactor,
    bool? loginAlerts,
    bool? appLock,
    bool? biometrics,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? inAppSounds,
    bool? inAppHaptics,
    bool? notifyPosts,
    bool? notifyChats,
    bool? notifyMentions,
    bool? notifyFollows,
    bool? dataSaver,
    bool? autoDownload,
    bool? autoPlayVideos,
    bool? reduceMotion,
    int? themeIndex,
    double? textScale,
    String? languageLabel,
    String? whoCanMessage,
    String? whoCanAddToGroups,
    String? defaultFeedMode,
    String? personalizationLevel,
    String? contentSafetyLevel,
    String? displayDensity,
    String? fontSize,
    String? mediaQuality,
    bool? quietHours,
    bool? showRecommendedPosts,
    bool? showTrendingPosts,
    bool? showFriendsFirst,
    bool? highContrast,
    bool? boldText,
    bool? reduceTransparency,
    bool? largerTouchTargets,
    bool? screenReaderEnhancedLabels,
    bool? disableAutoplay,
    bool? aiPersonalizedFeed,
    bool? aiFriendSuggestions,
    bool? aiPostRecommendations,
    bool? aiSmartReplies,
    bool? creatorMode,
    bool? professionalMode,
    bool? publicContactButton,
    bool? showCreatorBadge,
  }) {
    return SettingsState(
      privateAccount: privateAccount ?? this.privateAccount,
      activityStatus: activityStatus ?? this.activityStatus,
      readReceipts: readReceipts ?? this.readReceipts,
      messagePreview: messagePreview ?? this.messagePreview,
      sensitiveContent: sensitiveContent ?? this.sensitiveContent,
      locationSharing: locationSharing ?? this.locationSharing,
      twoFactor: twoFactor ?? this.twoFactor,
      loginAlerts: loginAlerts ?? this.loginAlerts,
      appLock: appLock ?? this.appLock,
      biometrics: biometrics ?? this.biometrics,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      inAppSounds: inAppSounds ?? this.inAppSounds,
      inAppHaptics: inAppHaptics ?? this.inAppHaptics,
      notifyPosts: notifyPosts ?? this.notifyPosts,
      notifyChats: notifyChats ?? this.notifyChats,
      notifyMentions: notifyMentions ?? this.notifyMentions,
      notifyFollows: notifyFollows ?? this.notifyFollows,
      dataSaver: dataSaver ?? this.dataSaver,
      autoDownload: autoDownload ?? this.autoDownload,
      autoPlayVideos: autoPlayVideos ?? this.autoPlayVideos,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      themeIndex: themeIndex ?? this.themeIndex,
      textScale: textScale ?? this.textScale,
      languageLabel: languageLabel ?? this.languageLabel,
      whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      whoCanAddToGroups: whoCanAddToGroups ?? this.whoCanAddToGroups,
      defaultFeedMode: defaultFeedMode ?? this.defaultFeedMode,
      personalizationLevel: personalizationLevel ?? this.personalizationLevel,
      contentSafetyLevel: contentSafetyLevel ?? this.contentSafetyLevel,
      displayDensity: displayDensity ?? this.displayDensity,
      fontSize: fontSize ?? this.fontSize,
      mediaQuality: mediaQuality ?? this.mediaQuality,
      quietHours: quietHours ?? this.quietHours,
      showRecommendedPosts: showRecommendedPosts ?? this.showRecommendedPosts,
      showTrendingPosts: showTrendingPosts ?? this.showTrendingPosts,
      showFriendsFirst: showFriendsFirst ?? this.showFriendsFirst,
      highContrast: highContrast ?? this.highContrast,
      boldText: boldText ?? this.boldText,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      largerTouchTargets: largerTouchTargets ?? this.largerTouchTargets,
      screenReaderEnhancedLabels:
          screenReaderEnhancedLabels ?? this.screenReaderEnhancedLabels,
      disableAutoplay: disableAutoplay ?? this.disableAutoplay,
      aiPersonalizedFeed: aiPersonalizedFeed ?? this.aiPersonalizedFeed,
      aiFriendSuggestions: aiFriendSuggestions ?? this.aiFriendSuggestions,
      aiPostRecommendations:
          aiPostRecommendations ?? this.aiPostRecommendations,
      aiSmartReplies: aiSmartReplies ?? this.aiSmartReplies,
      creatorMode: creatorMode ?? this.creatorMode,
      professionalMode: professionalMode ?? this.professionalMode,
      publicContactButton: publicContactButton ?? this.publicContactButton,
      showCreatorBadge: showCreatorBadge ?? this.showCreatorBadge,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privateAccount': privateAccount,
      'activityStatus': activityStatus,
      'readReceipts': readReceipts,
      'messagePreview': messagePreview,
      'sensitiveContent': sensitiveContent,
      'locationSharing': locationSharing,
      'twoFactor': twoFactor,
      'loginAlerts': loginAlerts,
      'appLock': appLock,
      'biometrics': biometrics,
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'inAppSounds': inAppSounds,
      'inAppHaptics': inAppHaptics,
      'notifyPosts': notifyPosts,
      'notifyChats': notifyChats,
      'notifyMentions': notifyMentions,
      'notifyFollows': notifyFollows,
      'dataSaver': dataSaver,
      'autoDownload': autoDownload,
      'autoPlayVideos': autoPlayVideos,
      'reduceMotion': reduceMotion,
      'themeIndex': themeIndex,
      'textScale': textScale,
      'languageLabel': languageLabel,
      'whoCanMessage': whoCanMessage,
      'whoCanAddToGroups': whoCanAddToGroups,
      'defaultFeedMode': defaultFeedMode,
      'personalizationLevel': personalizationLevel,
      'contentSafetyLevel': contentSafetyLevel,
      'displayDensity': displayDensity,
      'fontSize': fontSize,
      'mediaQuality': mediaQuality,
      'quietHours': quietHours,
      'showRecommendedPosts': showRecommendedPosts,
      'showTrendingPosts': showTrendingPosts,
      'showFriendsFirst': showFriendsFirst,
      'highContrast': highContrast,
      'boldText': boldText,
      'reduceTransparency': reduceTransparency,
      'largerTouchTargets': largerTouchTargets,
      'screenReaderEnhancedLabels': screenReaderEnhancedLabels,
      'disableAutoplay': disableAutoplay,
      'aiPersonalizedFeed': aiPersonalizedFeed,
      'aiFriendSuggestions': aiFriendSuggestions,
      'aiPostRecommendations': aiPostRecommendations,
      'aiSmartReplies': aiSmartReplies,
      'creatorMode': creatorMode,
      'professionalMode': professionalMode,
      'publicContactButton': publicContactButton,
      'showCreatorBadge': showCreatorBadge,
    };
  }
}

class SettingsService {
  SettingsService({SecureStore? store})
    : _store = store ?? SecureStore(),
      _client = ApiClient(store ?? SecureStore());

  final SecureStore _store;
  final ApiClient _client;

  Future<SettingsState> loadLocal() async {
    final raw = await _store.getSettingsJson();
    if (raw == null || raw.isEmpty) {
      return SettingsState.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SettingsState.fromJson(decoded);
      }
    } catch (_) {}

    return SettingsState.defaults();
  }

  Future<void> saveLocal(SettingsState state) async {
    final raw = jsonEncode(state.toJson());
    await _store.setSettingsJson(raw);
  }

  Future<SettingsState> fetchRemote() async {
    final data = await _client.get('/settings', auth: true);
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final legacy = payload['legacy'];
    if (legacy is Map<String, dynamic>) {
      return SettingsState.fromJson(legacy);
    }
    final settings = payload['settings'];
    if (settings is Map<String, dynamic>) {
      return SettingsState.fromJson(settings);
    }
    return SettingsState.fromJson(payload);
  }

  Future<SettingsState> saveRemote(SettingsState state) async {
    final data = await _client.patch(
      '/settings',
      auth: true,
      body: state.toJson(),
    );
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final legacy = payload['legacy'];
    if (legacy is Map<String, dynamic>) {
      return SettingsState.fromJson(legacy);
    }
    final settings = payload['settings'];
    if (settings is Map<String, dynamic>) {
      return SettingsState.fromJson(settings);
    }
    return SettingsState.fromJson(payload);
  }
}

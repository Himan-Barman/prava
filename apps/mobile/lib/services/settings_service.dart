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
    required this.dataSaver,
    required this.autoDownload,
    required this.autoPlayVideos,
    required this.reduceMotion,
    required this.themeIndex,
    required this.textScale,
    required this.languageLabel,
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
  final bool dataSaver;
  final bool autoDownload;
  final bool autoPlayVideos;
  final bool reduceMotion;
  final int themeIndex;
  final double textScale;
  final String languageLabel;

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
      dataSaver: false,
      autoDownload: true,
      autoPlayVideos: true,
      reduceMotion: false,
      themeIndex: 0,
      textScale: 1.0,
      languageLabel: 'English',
    );
  }

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    final defaults = SettingsState.defaults();
    return SettingsState(
      privateAccount:
          json['privateAccount'] is bool ? json['privateAccount'] : defaults.privateAccount,
      activityStatus:
          json['activityStatus'] is bool ? json['activityStatus'] : defaults.activityStatus,
      readReceipts:
          json['readReceipts'] is bool ? json['readReceipts'] : defaults.readReceipts,
      messagePreview:
          json['messagePreview'] is bool ? json['messagePreview'] : defaults.messagePreview,
      sensitiveContent:
          json['sensitiveContent'] is bool ? json['sensitiveContent'] : defaults.sensitiveContent,
      locationSharing:
          json['locationSharing'] is bool ? json['locationSharing'] : defaults.locationSharing,
      twoFactor: json['twoFactor'] is bool ? json['twoFactor'] : defaults.twoFactor,
      loginAlerts: json['loginAlerts'] is bool ? json['loginAlerts'] : defaults.loginAlerts,
      appLock: json['appLock'] is bool ? json['appLock'] : defaults.appLock,
      biometrics: json['biometrics'] is bool ? json['biometrics'] : defaults.biometrics,
      pushNotifications: json['pushNotifications'] is bool
          ? json['pushNotifications']
          : defaults.pushNotifications,
      emailNotifications: json['emailNotifications'] is bool
          ? json['emailNotifications']
          : defaults.emailNotifications,
      inAppSounds:
          json['inAppSounds'] is bool ? json['inAppSounds'] : defaults.inAppSounds,
      inAppHaptics:
          json['inAppHaptics'] is bool ? json['inAppHaptics'] : defaults.inAppHaptics,
      dataSaver: json['dataSaver'] is bool ? json['dataSaver'] : defaults.dataSaver,
      autoDownload:
          json['autoDownload'] is bool ? json['autoDownload'] : defaults.autoDownload,
      autoPlayVideos:
          json['autoPlayVideos'] is bool ? json['autoPlayVideos'] : defaults.autoPlayVideos,
      reduceMotion:
          json['reduceMotion'] is bool ? json['reduceMotion'] : defaults.reduceMotion,
      themeIndex: json['themeIndex'] is int
          ? json['themeIndex'] as int
          : int.tryParse(json['themeIndex']?.toString() ?? '') ?? defaults.themeIndex,
      textScale: json['textScale'] is num
          ? (json['textScale'] as num).toDouble()
          : double.tryParse(json['textScale']?.toString() ?? '') ?? defaults.textScale,
      languageLabel: json['languageLabel']?.toString() ?? defaults.languageLabel,
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
    bool? dataSaver,
    bool? autoDownload,
    bool? autoPlayVideos,
    bool? reduceMotion,
    int? themeIndex,
    double? textScale,
    String? languageLabel,
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
      dataSaver: dataSaver ?? this.dataSaver,
      autoDownload: autoDownload ?? this.autoDownload,
      autoPlayVideos: autoPlayVideos ?? this.autoPlayVideos,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      themeIndex: themeIndex ?? this.themeIndex,
      textScale: textScale ?? this.textScale,
      languageLabel: languageLabel ?? this.languageLabel,
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
      'dataSaver': dataSaver,
      'autoDownload': autoDownload,
      'autoPlayVideos': autoPlayVideos,
      'reduceMotion': reduceMotion,
      'themeIndex': themeIndex,
      'textScale': textScale,
      'languageLabel': languageLabel,
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
    final data = await _client.get('/users/me/settings', auth: true);
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final settings = payload['settings'];
    if (settings is Map<String, dynamic>) {
      return SettingsState.fromJson(settings);
    }
    return SettingsState.fromJson(payload);
  }

  Future<SettingsState> saveRemote(SettingsState state) async {
    final data = await _client.put(
      '/users/me/settings',
      auth: true,
      body: state.toJson(),
    );
    final payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final settings = payload['settings'];
    if (settings is Map<String, dynamic>) {
      return SettingsState.fromJson(settings);
    }
    return SettingsState.fromJson(payload);
  }
}

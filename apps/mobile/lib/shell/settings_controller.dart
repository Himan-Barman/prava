import 'dart:async';

import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({SettingsService? service})
    : _service = service ?? SettingsService(),
      _state = SettingsState.defaults();

  final SettingsService _service;
  SettingsState _state;
  bool _isReady = false;
  bool _loading = false;
  int _revision = 0;
  Timer? _saveTimer;

  SettingsState get state => _state;
  bool get isReady => _isReady;

  ThemeMode get themeMode {
    switch (_state.themeIndex) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  double get textScale => _state.textScale;
  bool get reduceMotion => _state.reduceMotion;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    final local = await _service.loadLocal();
    _state = local;
    notifyListeners();
    final revisionSnapshot = _revision;
    unawaited(_refreshRemote(revisionSnapshot));
  }

  Future<void> _refreshRemote(int revisionSnapshot) async {
    try {
      final remote = await _service.fetchRemote();
      if (revisionSnapshot == _revision) {
        _state = remote;
        unawaited(_service.saveLocal(remote));
      }
    } catch (_) {}
    _isReady = true;
    _loading = false;
    notifyListeners();
  }

  void update(SettingsState next) {
    _revision += 1;
    _state = next;
    notifyListeners();
    unawaited(_service.saveLocal(next));
    _saveTimer?.cancel();
    final revisionSnapshot = _revision;
    _saveTimer = Timer(const Duration(milliseconds: 650), () async {
      try {
        final saved = await _service.saveRemote(next);
        if (revisionSnapshot == _revision) {
          _state = saved;
          unawaited(_service.saveLocal(saved));
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  Future<void> updateNow(SettingsState next) async {
    _saveTimer?.cancel();
    _revision += 1;
    final revisionSnapshot = _revision;
    final previous = _state;
    _state = next;
    notifyListeners();
    await _service.saveLocal(next);

    try {
      final saved = await _service.saveRemote(next);
      if (revisionSnapshot == _revision) {
        _state = saved;
        await _service.saveLocal(saved);
        notifyListeners();
      }
    } catch (_) {
      if (revisionSnapshot == _revision) {
        _state = previous;
        await _service.saveLocal(previous);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<SettingsCheckupResult> runPrivacyCheckup() {
    return _service.runPrivacyCheckup();
  }

  Future<SettingsCheckupResult> runSecurityCheckup() {
    return _service.runSecurityCheckup();
  }

  Future<void> resetFeedPersonalization() async {
    final next = await _service.resetFeedPersonalization();
    _saveTimer?.cancel();
    _revision += 1;
    _state = next;
    await _service.saveLocal(next);
    notifyListeners();
  }

  Future<void> clearSearchHistory() {
    return _service.clearSearchHistory();
  }

  Future<void> clearCacheMetadata() {
    return _service.clearCacheMetadata();
  }

  Future<void> logoutAllSessions() {
    return _service.logoutAllSessions();
  }

  Future<SettingsAccountActionResult> deactivateAccount({
    required String password,
    String? reason,
  }) {
    return _service.deactivateAccount(password: password, reason: reason);
  }

  Future<SettingsAccountActionResult> requestAccountDeletion({
    required String password,
    required String confirmation,
    String? reason,
  }) {
    return _service.requestAccountDeletion(
      password: password,
      confirmation: confirmation,
      reason: reason,
    );
  }

  Future<void> cancelAccountDeletion() {
    return _service.cancelAccountDeletion();
  }

  Future<List<SettingsAuditEntry>> fetchAudit() {
    return _service.fetchAudit();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope not found in widget tree.');
    return scope!.notifier!;
  }
}

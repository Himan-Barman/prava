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
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope not found in widget tree.');
    return scope!.notifier!;
  }
}

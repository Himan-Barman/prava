import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum NativeNotificationPermission {
  authorized,
  provisional,
  denied,
  notDetermined,
  unavailable,
}

class NotificationPermissionSnapshot {
  const NotificationPermissionSnapshot({
    required this.permission,
    required this.alert,
    required this.badge,
    required this.sound,
  });

  final NativeNotificationPermission permission;
  final bool alert;
  final bool badge;
  final bool sound;

  bool get canDeliver =>
      permission == NativeNotificationPermission.authorized ||
      permission == NativeNotificationPermission.provisional;

  bool get canRequest =>
      permission == NativeNotificationPermission.notDetermined ||
      permission == NativeNotificationPermission.denied ||
      permission == NativeNotificationPermission.unavailable;

  String get label {
    switch (permission) {
      case NativeNotificationPermission.authorized:
        return 'Allowed';
      case NativeNotificationPermission.provisional:
        return 'Quiet';
      case NativeNotificationPermission.denied:
        return 'Blocked';
      case NativeNotificationPermission.notDetermined:
        return 'Not set';
      case NativeNotificationPermission.unavailable:
        return 'Unavailable';
    }
  }

  String get detail {
    switch (permission) {
      case NativeNotificationPermission.authorized:
        return 'Native alerts, badges, and sounds can be delivered.';
      case NativeNotificationPermission.provisional:
        return 'Notifications can arrive quietly until the user promotes them.';
      case NativeNotificationPermission.denied:
        return 'System permission is blocked for this app.';
      case NativeNotificationPermission.notDetermined:
        return 'Ask for permission before sending push alerts.';
      case NativeNotificationPermission.unavailable:
        return 'Firebase notification permission is not available on this device.';
    }
  }

  static const unavailable = NotificationPermissionSnapshot(
    permission: NativeNotificationPermission.unavailable,
    alert: false,
    badge: false,
    sound: false,
  );
}

class NotificationPermissionService {
  Future<NotificationPermissionSnapshot> getStatus() async {
    try {
      await _ensureFirebase();
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return _fromSettings(settings);
    } catch (_) {
      return NotificationPermissionSnapshot.unavailable;
    }
  }

  Future<NotificationPermissionSnapshot> requestPermission() async {
    try {
      await _ensureFirebase();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
      return _fromSettings(settings);
    } catch (_) {
      return NotificationPermissionSnapshot.unavailable;
    }
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  NotificationPermissionSnapshot _fromSettings(NotificationSettings settings) {
    return NotificationPermissionSnapshot(
      permission: _mapStatus(settings.authorizationStatus),
      alert: settings.alert == AppleNotificationSetting.enabled,
      badge: settings.badge == AppleNotificationSetting.enabled,
      sound: settings.sound == AppleNotificationSetting.enabled,
    );
  }

  NativeNotificationPermission _mapStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return NativeNotificationPermission.authorized;
      case AuthorizationStatus.provisional:
        return NativeNotificationPermission.provisional;
      case AuthorizationStatus.denied:
        return NativeNotificationPermission.denied;
      case AuthorizationStatus.notDetermined:
        return NativeNotificationPermission.notDetermined;
    }
  }
}

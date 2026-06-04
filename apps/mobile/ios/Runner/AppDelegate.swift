import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  private var pendingLocationResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "prava/platform",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "shareText":
          let args = call.arguments as? [String: Any]
          let text = args?["text"] as? String ?? ""
          self?.shareText(text, result: result)
        case "requestLocationTimeAccess":
          self?.requestLocationTimeAccess(result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func shareText(_ text: String, result: @escaping FlutterResult) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let controller = window?.rootViewController else {
      result(false)
      return
    }

    let activity = UIActivityViewController(
      activityItems: [text],
      applicationActivities: nil
    )
    controller.present(activity, animated: true) {
      result(true)
    }
  }

  private func requestLocationTimeAccess(_ result: @escaping FlutterResult) {
    let status = CLLocationManager.authorizationStatus()
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      result(timeZonePayload(permissionGranted: true))
      return
    }
    if status == .denied || status == .restricted {
      result(timeZonePayload(permissionGranted: false))
      return
    }

    pendingLocationResult = result
    let manager = CLLocationManager()
    manager.delegate = self
    locationManager = manager
    manager.requestWhenInUseAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    finishLocationPermission(status: manager.authorizationStatus)
  }

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    finishLocationPermission(status: status)
  }

  private func finishLocationPermission(status: CLAuthorizationStatus) {
    guard let result = pendingLocationResult else { return }
    if status == .notDetermined { return }
    let granted = status == .authorizedAlways || status == .authorizedWhenInUse
    result(timeZonePayload(permissionGranted: granted))
    pendingLocationResult = nil
    locationManager = nil
  }

  private func timeZonePayload(permissionGranted: Bool) -> [String: Any] {
    let zone = TimeZone.current
    return [
      "timeZoneName": zone.identifier,
      "timeZoneOffsetMinutes": zone.secondsFromGMT() / 60,
      "permissionGranted": permissionGranted
    ]
  }
}

import Flutter
import UIKit

/// 离开前台后给休息结束留一小段后台时间，让训练 Live Activity 自己把岛展开。
///
/// 不用 AlarmKit。它会再占一条系统 Live Activity，休息到点时把顶部灵动岛顶掉，
/// 锁屏上原来的训练活动还在。
enum RestIslandAlert {
  private static var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hold":
      hold()
      result(nil)
    case "endHold":
      endHold()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func hold() {
    endHold()
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "rest-island") {
      endHold()
    }
  }

  static func endHold() {
    guard backgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
  }
}

//
//  MyAppWidgetLiveActivity.swift
//  MyAppWidget
//
//  训练 Live Activity / 灵动岛。
//  Attributes 类型名必须是 LiveActivitiesAppAttributes（live_activities 插件约定）。
//
//  三个呈现：
//  - 锁屏：动作图 + Next 行在上，大倒计时在下
//  - 展开岛：倒计时在左，动作图在右，名称在下
//  - 紧凑岛：倒计时在左，动作图在右
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable {}

  var id = UUID()
}

/// 与 Flutter `WorkoutLiveActivityService` / Runner entitlements 保持一致。
let sharedDefault = UserDefaults(suiteName: "group.com.ervin.PowerTrack")!

struct MyAppWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      LockScreenWorkoutView(data: WorkoutIslandData(attributes: context.attributes))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let data = WorkoutIslandData(attributes: context.attributes)

      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Group {
            if data.phase == "ready" {
              Text("开始")
            } else {
              WorkoutTimerText(data: data, showsHours: false)
            }
          }
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .frame(maxWidth: 120, alignment: .leading)
          .padding(.leading, 6)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ExerciseThumb(path: data.imagePath, size: 40, radius: 10)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 6)
        }
        DynamicIslandExpandedRegion(.bottom) {
          ExerciseTitle(data: data)
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
        }
      } compactLeading: {
        if data.phase == "ready" {
          Text("下一组")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(width: 52, height: 20, alignment: .leading)
        } else {
          // timerInterval 的理想宽度按整段区间计算，计到很远的时间会把岛拉满。
          Color.clear
            .frame(width: 48, height: 20)
            .overlay(alignment: .leading) {
              WorkoutTimerText(data: data, showsHours: false)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
            }
            .clipped()
        }
      } compactTrailing: {
        ExerciseThumb(path: data.imagePath, size: 22, radius: 6)
      } minimal: {
        ExerciseThumb(path: data.imagePath, size: 18, radius: 5)
      }
      .keylineTint(.white.opacity(0.25))
    }
  }
}

// MARK: - Views

private struct WorkoutTimerText: View {
  let data: WorkoutIslandData
  var showsHours = true

  var body: some View {
    if data.isResting, let start = data.restStartedAt, let end = data.restEndsAt, end > start {
      Text(timerInterval: start...end, countsDown: true, showsHours: showsHours)
        .multilineTextAlignment(.leading)
    } else {
      // 上限一小时内，等宽数字只按「59:59」占位。用 distantFuture 会把紧凑岛拉满整条状态栏。
      let cap = max(data.startedAt.addingTimeInterval(59 * 60), Date().addingTimeInterval(60))
      Text(timerInterval: data.startedAt...cap, countsDown: false, showsHours: false)
        .multilineTextAlignment(.leading)
    }
  }
}

private struct ExerciseThumb: View {
  let path: String?
  let size: CGFloat
  let radius: CGFloat

  var body: some View {
    Group {
      if let path, let uiImage = UIImage(contentsOfFile: path) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: "figure.strengthtraining.traditional")
          .font(.system(size: size * 0.42, weight: .semibold))
          .foregroundStyle(Color.black.opacity(0.55))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color(white: 0.93))
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}

private struct ExerciseTitle: View {
  let data: WorkoutIslandData

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(data.nextLine)
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(.white.opacity(0.72))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      Text(data.exerciseName)
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ExerciseCaption: View {
  let data: WorkoutIslandData
  let thumb: CGFloat
  let radius: CGFloat

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      ExerciseThumb(path: data.imagePath, size: thumb, radius: radius)
      ExerciseTitle(data: data)
    }
  }
}

private struct LockScreenWorkoutView: View {
  let data: WorkoutIslandData

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ExerciseCaption(data: data, thumb: 54, radius: 14)
      Group {
        if data.phase == "ready" {
          Text("开始")
            .font(.system(size: 40, weight: .bold, design: .rounded))
        } else {
          WorkoutTimerText(data: data, showsHours: false)
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.6)
        }
      }
      .foregroundStyle(.white)
      .lineLimit(1)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Data

private struct WorkoutIslandData {
  let exerciseName: String
  let nextLine: String
  let imagePath: String?
  let phase: String
  let startedAt: Date
  let restStartedAt: Date?
  let restEndsAt: Date?

  var isResting: Bool {
    phase == "rest" && restEndsAt.map { $0 > Date() } == true
  }

  init(attributes: LiveActivitiesAppAttributes) {
    func key(_ k: String) -> String { attributes.prefixedKey(k) }

    exerciseName = sharedDefault.string(forKey: key("exerciseName")) ?? "训练进行中"
    let line = sharedDefault.string(forKey: key("nextLine")) ?? ""
    nextLine = line.isEmpty ? "训练中" : line
    let image = sharedDefault.string(forKey: key("exerciseImage"))
    imagePath = (image?.isEmpty == false) ? image : nil
    phase = sharedDefault.string(forKey: key("phase")) ?? "work"

    let startedMs = sharedDefault.double(forKey: key("startedAtMs"))
    startedAt = Date(timeIntervalSince1970: startedMs / 1000)

    let restEndMs = sharedDefault.double(forKey: key("restEndsAtMs"))
    let restStartMs = sharedDefault.double(forKey: key("restStartedAtMs"))
    if restEndMs > 0 {
      restEndsAt = Date(timeIntervalSince1970: restEndMs / 1000)
      restStartedAt = restStartMs > 0
        ? Date(timeIntervalSince1970: restStartMs / 1000)
        : Date()
    } else {
      restEndsAt = nil
      restStartedAt = nil
    }
  }
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    "\(id)_\(key)"
  }
}

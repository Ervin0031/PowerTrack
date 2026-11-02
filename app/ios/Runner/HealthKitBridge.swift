import Foundation
import Flutter
import HealthKit

/// Flutter MethodChannel：`powertrack/health`
final class HealthKitBridge: NSObject {
  static let shared = HealthKitBridge()
  private let store = HKHealthStore()

  private var shareTypes: Set<HKSampleType> {
    [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
  }

  private var readTypes: Set<HKObjectType> {
    [
      HKQuantityType(.stepCount),
      HKQuantityType(.activeEnergyBurned),
      HKQuantityType(.bodyMass),
      HKQuantityType(.restingHeartRate),
      HKObjectType.workoutType(),
    ]
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(HKHealthStore.isHealthDataAvailable())
    case "requestAuthorization":
      guard HKHealthStore.isHealthDataAvailable() else {
        result(false)
        return
      }
      store.requestAuthorization(toShare: shareTypes, read: readTypes) { success, _ in
        DispatchQueue.main.async { result(success) }
      }
    case "fetchDailySummary":
      Task { await fetchDailySummary(result: result) }
    case "saveStrengthWorkout":
      guard let args = call.arguments as? [String: Any],
            let startMs = args["startMs"] as? Double,
            let endMs = args["endMs"] as? Double else {
        result(FlutterError(code: "bad_args", message: "startMs/endMs required", details: nil))
        return
      }
      let start = Date(timeIntervalSince1970: startMs / 1000)
      let end = Date(timeIntervalSince1970: endMs / 1000)
      Task { await saveWorkout(start: start, end: end, result: result) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func fetchDailySummary(result: @escaping FlutterResult) async {
    guard HKHealthStore.isHealthDataAvailable() else {
      result([:] as [String: Any])
      return
    }
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let now = Date()

    async let steps = sum(.stepCount, unit: .count(), start: start, end: now)
    async let energy = sum(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: now)
    async let mass = latest(.bodyMass, unit: .gramUnit(with: .kilo))
    async let rhr = latest(
      .restingHeartRate,
      unit: HKUnit.count().unitDivided(by: .minute())
    )

    let payload: [String: Any?] = [
      "steps": await steps,
      "activeEnergyKcal": await energy,
      "bodyMassKg": await mass,
      "restingHeartRate": await rhr,
    ]
    result(payload.compactMapValues { $0 })
  }

  private func saveWorkout(start: Date, end: Date, result: @escaping FlutterResult) async {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(false)
      return
    }
    do {
      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .traditionalStrengthTraining
      configuration.locationType = .indoor
      let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
      try await builder.beginCollection(at: start)

      let minutes = max(0, end.timeIntervalSince(start) / 60)
      let energy = minutes * 5
      if energy > 0 {
        let sample = HKQuantitySample(
          type: HKQuantityType(.activeEnergyBurned),
          quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy),
          start: start,
          end: end
        )
        try await builder.addSamples([sample])
      }
      try await builder.endCollection(at: end)
      _ = try await builder.finishWorkout()
      result(true)
    } catch {
      result(false)
    }
  }

  private func sum(
    _ id: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date
  ) async -> Double? {
    let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
    let samplePredicate = HKSamplePredicate.quantitySample(
      type: HKQuantityType(id),
      predicate: predicate
    )
    let query = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)
    guard let stats = try? await query.result(for: store) else { return nil }
    return stats.sumQuantity()?.doubleValue(for: unit)
  }

  private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: HKQuantityType(id))],
      sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
      limit: 1
    )
    guard let sample = try? await descriptor.result(for: store).first else { return nil }
    return sample.quantity.doubleValue(for: unit)
  }
}

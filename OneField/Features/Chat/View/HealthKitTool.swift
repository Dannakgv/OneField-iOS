//
//  HealthKitTool.swift
//  OneField
//
//  Created by Danna Valencia on 06/10/25.
//

import Foundation
import FoundationModels
import HealthKit

// MARK: - HealthKitTool
final class HealthKitTool: Tool {

    // MARK: Tool metadata
    let name = "healthKit"
    let description = """
    Query HealthKit for time-series and summary statistics over a date range.
    Metrics: steps, distanceWalkingRunning, activeEnergy, heartRateAvg, heartRateMin, heartRateMax, vo2Max, hrvSDNN, sleepAsleep, sleepInBed.
    Granularity: day, week, month. Units: metric or us.
    """

    // MARK: Arguments / Output

    @Generable
    struct Arguments: Codable {
        @Guide(description: "ISO-8601 start date, e.g. 2025-10-06T00:00:00Z")
        let startISO8601: String?

        @Guide(description: "ISO-8601 end date, e.g. 2025-10-13T00:00:00Z")
        let endISO8601: String?

        let metrics: [String]
        let granularity: String?   // "day" | "week" | "month"
        let unitSystem: String?    // "metric" | "us"
    }

    @Generable
    struct TimeSeriesPoint: Codable {
        let periodStartISO8601: String
        let value: Double
    }

    @Generable
    struct MetricSeries: Codable {
        let metric: String
        let unit: String
        let series: [TimeSeriesPoint]
        let total: Double?
        let average: Double?
        let min: Double?
        let max: Double?
    }

    
    @Generable
    struct Output: Codable {
        let startISO8601: String
        let endISO8601: String
        let timezone: String
        let granularity: String
        let metrics: [MetricSeries]
        let warnings: [String]
    }

    // MARK: Internal types

    private enum Granularity {
        case day, week, month

        init(_ raw: String?) {
            switch raw?.lowercased() {
            case "week": self = .week
            case "month": self = .month
            default: self = .day
            }
        }

        var dateComponents: DateComponents {
            switch self {
            case .day:   return DateComponents(day: 1)
            case .week:  return DateComponents(weekOfYear: 1)
            case .month: return DateComponents(month: 1)
            }
        }
    }

    private enum UnitSystem { case metric, us
        init(_ raw: String?) { self = (raw?.lowercased() == "us") ? .us : .metric }
    }

    private struct MetricSpec {
        enum Kind {
            case cumulative(HKQuantityTypeIdentifier, unit: HKUnit)
            case discrete(HKQuantityTypeIdentifier, option: HKStatisticsOptions, unit: HKUnit)
            case sleep(asAsleep: Bool) // true = asleep duration, false = in-bed duration
        }
        let kind: Kind
        let hkType: HKObjectType
        let displayUnitString: String
    }

    // MARK: HealthKit

    private let healthStore = HKHealthStore()

    // MARK: Tool entry point

    func call(arguments: Arguments) async throws -> Output {
//        guard HKHealthStore.isHealthDataAvailable() else {
//            return nil
//        }

        // Resolve time window & settings
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let start = arguments.startISO8601.flatMap(iso.date(from:)) ?? Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let end   = arguments.endISO8601.flatMap(iso.date(from:))   ?? now
        let gran = Granularity(arguments.granularity)
        let unitSystem = UnitSystem(arguments.unitSystem)
        let tz = TimeZone.current

        // Resolve metric specs & authorization set
        let requested = arguments.metrics.isEmpty
            ? ["steps"] : arguments.metrics

        var specs: [String: MetricSpec] = [:]
        for m in requested {
            if let spec = try spec(for: m, unitSystem: unitSystem) {
                specs[m] = spec
            }
        }
//        if specs.isEmpty {
//            return nil
//        }

        // Request read authorization
        let readTypes = Set(specs.values.map(\.hkType))
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)

        // Fetch data
        var seriesList: [MetricSeries] = []
        var warnings: [String] = []

        let cal = Calendar.current
        let anchor = anchorDate(for: gran, start: start, calendar: cal)
        let interval = gran.dateComponents

        for (metricKey, spec) in specs {
            do {
                switch spec.kind {
                case let .cumulative(id, unit):
                    let qType = HKQuantityType.quantityType(forIdentifier: id)!
                    let points = try await fetchCumulativeSeries(
                        quantityType: qType,
                        unit: unit,
                        start: start,
                        end: end,
                        anchor: anchor,
                        interval: interval
                    )
                    let stats = summarize(points.map { $0.value })
                    seriesList.append(
                        MetricSeries(
                            metric: metricKey,
                            unit: spec.displayUnitString,
                            series: points,
                            total: stats.total,
                            average: stats.average,
                            min: stats.min,
                            max: stats.max
                        )
                    )

                case let .discrete(id, option, unit):
                    let qType = HKQuantityType.quantityType(forIdentifier: id)!
                    let points = try await fetchDiscreteSeries(
                        quantityType: qType,
                        option: option,
                        unit: unit,
                        start: start,
                        end: end,
                        anchor: anchor,
                        interval: interval
                    )
                    let stats = summarize(points.map { $0.value })
                    seriesList.append(
                        MetricSeries(
                            metric: metricKey,
                            unit: spec.displayUnitString,
                            series: points,
                            total: stats.total,
                            average: stats.average,
                            min: stats.min,
                            max: stats.max
                        )
                    )

                case let .sleep(asAsleep):
                    let points = try await fetchSleepSeries(
                        start: start,
                        end: end,
                        asAsleep: asAsleep,
                        anchor: anchor,
                        interval: interval
                    )
                    let stats = summarize(points.map { $0.value })
                    seriesList.append(
                        MetricSeries(
                            metric: metricKey,
                            unit: "hr",
                            series: points,
                            total: stats.total,
                            average: stats.average,
                            min: stats.min,
                            max: stats.max
                        )
                    )
                }

            } catch {
                warnings.append("Failed metric \(metricKey): \(error.localizedDescription)")
            }
        }

        let out = Output(
            startISO8601: isoString(start),
            endISO8601: isoString(end),
            timezone: TimeZone.current.identifier,
            granularity: arguments.granularity?.lowercased() ?? "day",
            metrics: seriesList,
            warnings: warnings
        )
        return out
    }

    // MARK: Mapping

    private func spec(for key: String, unitSystem: UnitSystem) throws -> MetricSpec? {
        switch key.lowercased() {
        case "steps":
            return MetricSpec(
                kind: .cumulative(.stepCount, unit: .count()),
                hkType: HKObjectType.quantityType(forIdentifier: .stepCount)!,
                displayUnitString: "count"
            )

        case "distancewalkingrunning":
            let unit: HKUnit = (unitSystem == .us) ? .mile() : .meterUnit(with: .kilo)
            return MetricSpec(
                kind: .cumulative(.distanceWalkingRunning, unit: unit),
                hkType: HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                displayUnitString: (unitSystem == .us) ? "mi" : "km"
            )

        case "activeenergy":
            return MetricSpec(
                kind: .cumulative(.activeEnergyBurned, unit: .kilocalorie()),
                hkType: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                displayUnitString: "kcal"
            )

        case "heartrateavg":
            return MetricSpec(
                kind: .discrete(.heartRate, option: .discreteAverage, unit: HKUnit.count().unitDivided(by: .minute())),
                hkType: HKObjectType.quantityType(forIdentifier: .heartRate)!,
                displayUnitString: "bpm"
            )

        case "heartratemin":
            return MetricSpec(
                kind: .discrete(.heartRate, option: .discreteMin, unit: HKUnit.count().unitDivided(by: .minute())),
                hkType: HKObjectType.quantityType(forIdentifier: .heartRate)!,
                displayUnitString: "bpm"
            )

        case "heartratemax":
            return MetricSpec(
                kind: .discrete(.heartRate, option: .discreteMax, unit: HKUnit.count().unitDivided(by: .minute())),
                hkType: HKObjectType.quantityType(forIdentifier: .heartRate)!,
                displayUnitString: "bpm"
            )

        case "vo2max":
            // mL/(kg*min)
            return MetricSpec(
                kind: .discrete(.vo2Max, option: .discreteAverage, unit: HKUnit(from: "mL/min·kg")),
                hkType: HKObjectType.quantityType(forIdentifier: .vo2Max)!,
                displayUnitString: "mL·kg⁻¹·min⁻¹"
            )

        case "hrvsdnn":
            return MetricSpec(
                kind: .discrete(.heartRateVariabilitySDNN, option: .discreteAverage, unit: .secondUnit(with: .milli)),
                hkType: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
                displayUnitString: "ms"
            )

        case "sleepasleep":
            return MetricSpec(
                kind: .sleep(asAsleep: true),
                hkType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                displayUnitString: "hr"
            )

        case "sleepinbed":
            return MetricSpec(
                kind: .sleep(asAsleep: false),
                hkType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                displayUnitString: "hr"
            )

        default:
            return nil
        }
    }

    // MARK: Queries

    private func fetchCumulativeSeries(
        quantityType: HKQuantityType,
        unit: HKUnit,
        start: Date,
        end: Date,
        anchor: Date,
        interval: DateComponents
    ) async throws -> [TimeSeriesPoint] {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, collection, error in
                if let error = error { cont.resume(throwing: error); return }
                var points: [TimeSeriesPoint] = []
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    let v = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                    points.append(TimeSeriesPoint(periodStartISO8601: self.isoString(stats.startDate), value: v))
                }
                cont.resume(returning: points)
            }
            healthStore.execute(q)
        }
    }

    private func fetchDiscreteSeries(
        quantityType: HKQuantityType,
        option: HKStatisticsOptions,
        unit: HKUnit,
        start: Date,
        end: Date,
        anchor: Date,
        interval: DateComponents
    ) async throws -> [TimeSeriesPoint] {
        try await withCheckedThrowingContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: option,
                anchorDate: anchor,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, collection, error in
                if let error = error { cont.resume(throwing: error); return }
                var points: [TimeSeriesPoint] = []
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    let quantity: HKQuantity?
                    switch option {
                    case .discreteAverage: quantity = stats.averageQuantity()
                    case .discreteMin:     quantity = stats.minimumQuantity()
                    case .discreteMax:     quantity = stats.maximumQuantity()
                    default:                quantity = nil
                    }
                    let v = quantity?.doubleValue(for: unit) ?? 0
                    points.append(TimeSeriesPoint(periodStartISO8601: self.isoString(stats.startDate), value: v))
                }
                cont.resume(returning: points)
            }
            healthStore.execute(q)
        }
    }

    private func fetchSleepSeries(
        start: Date,
        end: Date,
        asAsleep: Bool,
        anchor: Date,
        interval: DateComponents
    ) async throws -> [TimeSeriesPoint] {
        // We’ll fetch category samples and bucket durations
        try await withCheckedThrowingContinuation { cont in
            let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error { cont.resume(throwing: error); return }
                let cal = Calendar.current
                // Build bucket edges (inclusive start)
                var buckets: [Date: TimeInterval] = [:]

                // Create the bucket boundaries from anchor to end using 'interval'
                var cursor = anchor
                while cursor < end {
                    buckets[cursor] = 0
                    cursor = cal.date(byAdding: interval, to: cursor)!
                }

                // Helper to find bucket start for a given date
                func bucketStart(for date: Date) -> Date {
                    switch interval {
                    case DateComponents(day: 1):
                        return cal.startOfDay(for: date)
                    case DateComponents(weekOfYear: 1):
                        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
                    case DateComponents(month: 1):
                        let comps = cal.dateComponents([.year, .month], from: date)
                        return cal.date(from: comps)!
                    default:
                        return cal.startOfDay(for: date)
                    }
                }

                // Sum durations into appropriate buckets
                if let samples = samples as? [HKCategorySample] {
                    for s in samples {
                        let value = s.value
                        let isAsleepCategory: Bool = {
                            if #available(iOS 16.0, *) {
                                switch value {
                                case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                     HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                     HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                                     HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: return true
                                case HKCategoryValueSleepAnalysis.inBed.rawValue: return false
                                default: return false
                                }
                            } else {
                                // Pre-iOS 16: only 'asleep' and 'inBed'
                                return value == HKCategoryValueSleepAnalysis.asleep.rawValue
                            }
                        }()

                        let include = asAsleep ? isAsleepCategory : !isAsleepCategory
                        guard include else { continue }

                        // Clip to requested window and add duration to bucket
                        let clippedStart = max(s.startDate, start)
                        let clippedEnd = min(s.endDate, end)
                        var t = clippedStart
                        while t < clippedEnd {
                            let bStart = bucketStart(for: t)
                            // Next bucket edge
                            let bEnd: Date = {
                                if interval.day == 1 { return cal.date(byAdding: .day, value: 1, to: bStart)! }
                                if interval.weekOfYear == 1 { return cal.date(byAdding: .weekOfYear, value: 1, to: bStart)! }
                                if interval.month == 1 { return cal.date(byAdding: .month, value: 1, to: bStart)! }
                                return cal.date(byAdding: .day, value: 1, to: bStart)!
                            }()
                            let segEnd = min(clippedEnd, bEnd)
                            let dt = segEnd.timeIntervalSince(t)
                            buckets[bStart, default: 0] += dt
                            t = segEnd
                        }
                    }
                }

                let points = buckets
                    .filter { $0.key >= start && $0.key < end }
                    .keys.sorted()
                    .map { TimeSeriesPoint(periodStartISO8601: self.isoString($0), value: buckets[$0, default: 0] / 3600.0) }

                cont.resume(returning: points)
            }
            self.healthStore.execute(q)
        }
    }

    // MARK: Helpers

    private func anchorDate(for gran: Granularity, start: Date, calendar: Calendar) -> Date {
        switch gran {
        case .day:
            return calendar.startOfDay(for: start)
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start))!
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: start)
            return calendar.date(from: comps)!
        }
    }
    
    func isoString(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    private func summarize(_ values: [Double]) -> (total: Double?, average: Double?, min: Double?, max: Double?) {
        guard !values.isEmpty else { return (nil, nil, nil, nil) }
        let total = values.reduce(0, +)
        return (total, total / Double(values.count), values.min(), values.max())
    }
}

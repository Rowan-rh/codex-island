import Foundation

// Mirrors UsageHistory.swift's sample shape so the forecast compiles without
// the persisted store and its app-wide dependencies.
struct UsageSample: Codable {
    let at: Date
    let used: Double
}

@main
struct UsageForecastTests {
    static func main() {
        var failures = 0
        func expect(_ condition: Bool, _ label: String) {
            if condition { print("PASS \(label)") } else { failures += 1; print("FAIL \(label)") }
        }

        let now = Date(timeIntervalSince1970: 1_790_000_000)
        func minutesAgo(_ m: Double, _ used: Double) -> UsageSample {
            UsageSample(at: now.addingTimeInterval(-m * 60), used: used)
        }
        func window(_ used: Double, resetIn hours: Double?, error: String? = nil) -> WindowUsage {
            WindowUsage(usedPercent: used, resetAt: hours.map { now.addingTimeInterval($0 * 3600) }, error: error)
        }

        // 40% → 70% over the last hour: 30 points/hour, 30 points left → 1h.
        let steady = [minutesAgo(60, 0.40), minutesAgo(30, 0.55), minutesAgo(0, 0.70)]
        expect(UsageForecast.project(samples: steady, current: window(0.70, resetIn: 3), now: now)
            == .runsOut(at: now.addingTimeInterval(3600)),
               "a steady climb projects exhaustion before the reset")
        expect(UsageForecast.project(samples: steady, current: window(0.70, resetIn: 0.5), now: now) == .lastsUntilReset,
               "the same pace lasts when the reset comes first")

        let slow = [minutesAgo(60, 0.40), minutesAgo(0, 0.42)]
        expect(UsageForecast.project(samples: slow, current: window(0.42, resetIn: 3), now: now) == .lastsUntilReset,
               "a slow pace lasts until the reset")
        let idle = [minutesAgo(60, 0.40), minutesAgo(0, 0.40)]
        expect(UsageForecast.project(samples: idle, current: window(0.40, resetIn: 3), now: now) == .lastsUntilReset,
               "no new usage lasts until the reset")

        let thin = [minutesAgo(10, 0.40), minutesAgo(0, 0.60)]
        expect(UsageForecast.project(samples: thin, current: window(0.60, resetIn: 3), now: now) == .unknown,
               "less than fifteen minutes of readings gives no forecast")
        expect(UsageForecast.project(samples: [], current: window(0.60, resetIn: 3), now: now) == .unknown,
               "no history gives no forecast")

        let acrossReset = [minutesAgo(50, 0.95), minutesAgo(40, 0.98), minutesAgo(20, 0.05), minutesAgo(0, 0.10)]
        expect(UsageForecast.project(samples: acrossReset, current: window(0.10, resetIn: 4.5), now: now)
            == .lastsUntilReset,
               "readings from the previous cycle are ignored after a reset")
        let justReset = [minutesAgo(30, 0.97), minutesAgo(5, 0.02), minutesAgo(0, 0.04)]
        expect(UsageForecast.project(samples: justReset, current: window(0.04, resetIn: 4.9), now: now) == .unknown,
               "a window that just reset waits for a fresh span")

        let staleBurst = [minutesAgo(180, 0.10), minutesAgo(90, 0.60), minutesAgo(60, 0.60), minutesAgo(0, 0.61)]
        expect(UsageForecast.project(samples: staleBurst, current: window(0.61, resetIn: 2), now: now) == .lastsUntilReset,
               "a five-hour window ignores bursts older than an hour")
        let weekly = [minutesAgo(24 * 60, 0.30), minutesAgo(60, 0.34), minutesAgo(0, 0.40)]
        expect(UsageForecast.project(samples: weekly, current: window(0.40, resetIn: 72), now: now) == .lastsUntilReset,
               "a long window paces over the last day, not the last hour")

        expect(UsageForecast.project(samples: steady, current: window(1.0, resetIn: 3), now: now) == .unknown,
               "a full window has nothing left to forecast")
        expect(UsageForecast.project(samples: steady, current: window(0.70, resetIn: nil), now: now) == .unknown,
               "a window without a reset time has no deadline to compare")
        expect(UsageForecast.project(samples: steady, current: window(0.70, resetIn: 3, error: "HTTP 500"), now: now)
            == .unknown,
               "an errored reading gives no forecast")

        let overshoot = [minutesAgo(60, 0.50), minutesAgo(0, 0.99)]
        if case .runsOut(let at) = UsageForecast.project(samples: overshoot, current: window(0.99, resetIn: 3), now: now) {
            expect(at >= now, "a projection never lands in the past")
        } else {
            expect(false, "a projection never lands in the past")
        }

        exit(failures == 0 ? 0 : 1)
    }
}

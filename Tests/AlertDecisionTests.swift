import Foundation

@main
@MainActor
struct AlertDecisionTests {
    static func main() {
        var failures = 0
        func expect(_ condition: Bool, _ label: String) {
            if condition { print("PASS \(label)") } else { failures += 1; print("FAIL \(label)") }
        }

        let cycle = Date(timeIntervalSince1970: 1_790_000_000)
        let next = cycle.addingTimeInterval(5 * 3600)
        func input(_ used: Double, resetAt: Date, provider: IslandProvider = .codex) -> AlertDecision.WindowInput {
            AlertDecision.WindowInput(provider: provider, visible: true,
                                      window: WindowUsage(usedPercent: used, resetAt: resetAt, error: nil))
        }
        func evaluate(_ previous: Set<AlertEngine.CrossingKey>, _ inputs: [AlertDecision.WindowInput],
                      warmedUp: Bool = true) -> AlertDecision.CrossingsEvalResult {
            AlertDecision.evaluateCrossings(previous: previous, inputs: inputs, warning: 80, critical: 95,
                                            warmedUp: warmedUp)
        }

        let crossed = evaluate([], [input(0.82, resetAt: cycle)])
        expect(crossed.pulse?.lines.map(\.percent) == [82] && crossed.resets.isEmpty,
               "a first warning crossing pulses without a reset")
        expect(evaluate(crossed.next, [input(0.86, resetAt: cycle)]).pulse == nil,
               "the same threshold does not pulse twice in one cycle")

        let reset = evaluate(crossed.next, [input(0.03, resetAt: next)])
        expect(reset.resets.map(\.provider) == [.codex] && reset.resets.first?.percent == 3,
               "a window that reached warning reports its reset")
        expect(evaluate(reset.next, [input(0.05, resetAt: next)]).resets.isEmpty,
               "a reset is reported once")

        let quiet = evaluate([], [input(0.40, resetAt: cycle)])
        expect(evaluate(quiet.next, [input(0.02, resetAt: next)]).resets.isEmpty,
               "a window that stayed below warning resets silently")

        let jitter = cycle.addingTimeInterval(90)
        expect(evaluate(crossed.next, [input(0.10, resetAt: jitter)]).resets.isEmpty,
               "a small shift of the reset time is not a new cycle")
        expect(evaluate(crossed.next, [input(0.90, resetAt: next)]).resets.isEmpty,
               "a new cycle that is already above warning is not announced as a reset")
        expect(evaluate(crossed.next, [input(0.03, resetAt: next)], warmedUp: false).resets.isEmpty,
               "nothing is reported during warmup")

        let hidden = AlertDecision.WindowInput(provider: .codex, visible: false,
                                               window: WindowUsage(usedPercent: 0.03, resetAt: next, error: nil))
        expect(evaluate(crossed.next, [hidden]).resets.isEmpty, "hidden providers are not announced")

        exit(failures == 0 ? 0 : 1)
    }
}

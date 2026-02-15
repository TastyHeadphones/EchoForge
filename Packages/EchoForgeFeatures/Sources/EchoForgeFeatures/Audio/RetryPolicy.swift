import Foundation
import OSLog

struct RetryPolicy: Sendable {
    var maxAttempts: Int
    var baseDelay: Duration
    var maxDelay: Duration
    var jitterFraction: Double

    init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .milliseconds(300),
        maxDelay: Duration = .seconds(4),
        jitterFraction: Double = 0.2
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFraction = max(0, jitterFraction)
    }

    func run<T: Sendable>(
        operationName: String,
        logger: Logger,
        shouldRetry: @Sendable (Error) -> Bool,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < maxAttempts, shouldRetry(error) else {
                    throw error
                }

                let delay = computeDelay(attempt: attempt)
                let attemptText = "\(attempt)/\(maxAttempts)"
                logger.warning(
                    "\(operationName, privacy: .public) failed (attempt \(attemptText, privacy: .public)). Retrying…"
                )
                try await Task.sleep(for: delay)
                attempt += 1
            }
        }
    }

    private func computeDelay(attempt: Int) -> Duration {
        let baseSeconds = baseDelay.timeInterval
        let capSeconds = maxDelay.timeInterval

        let multiplier = pow(2.0, Double(max(0, attempt - 1)))
        let withoutJitter = min(capSeconds, baseSeconds * multiplier)
        let jitter = withoutJitter * jitterFraction * Double.random(in: 0...1)

        return .seconds(withoutJitter + jitter)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let seconds = components.seconds
        let attoseconds = components.attoseconds
        let fractional = Double(attoseconds) / 1_000_000_000_000_000_000.0
        return TimeInterval(seconds) + fractional
    }
}

import Foundation

/// Adapts how early the next episode is prepared to recent resolver and resource-preparation latency.
public struct UpcomingPreloadPolicy: Equatable, Sendable {
    public private(set) var estimatedPreparation: Double?
    public let minimumLead: Double
    public let maximumLead: Double
    public let safetyMargin: Double

    public init(minimumLead: Double = 30, maximumLead: Double = 90, safetyMargin: Double = 10) {
        self.minimumLead = max(1, minimumLead.isFinite ? minimumLead : 30)
        self.maximumLead = max(self.minimumLead, maximumLead.isFinite ? maximumLead : 90)
        self.safetyMargin = max(0, safetyMargin.isFinite ? safetyMargin : 10)
        estimatedPreparation = nil
    }

    public var lead: Double {
        guard let estimatedPreparation else { return min(max(30, minimumLead), maximumLead) }
        return min(maximumLead, max(minimumLead, estimatedPreparation * 2 + safetyMargin))
    }

    /// Records a completed preparation using an EWMA so one slow request cannot dominate indefinitely.
    public mutating func recordPreparation(seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        if let current = estimatedPreparation {
            estimatedPreparation = current * 0.7 + seconds * 0.3
        } else {
            estimatedPreparation = seconds
        }
    }
}

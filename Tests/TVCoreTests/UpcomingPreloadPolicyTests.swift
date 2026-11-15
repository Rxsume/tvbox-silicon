import Testing
@testable import TVCore

@Test func upcomingPreloadUsesConservativeDefaultAndClampsBounds() {
    var policy = UpcomingPreloadPolicy(minimumLead: 20, maximumLead: 60, safetyMargin: 10)
    #expect(policy.lead == 30)
    policy.recordPreparation(seconds: 2)
    #expect(policy.lead == 20)
    policy.recordPreparation(seconds: 40)
    #expect(abs(policy.lead - 36.8) < 0.001)
    policy.recordPreparation(seconds: 100)
    #expect(policy.lead == 60)
}

@Test func upcomingPreloadIgnoresInvalidSamplesAndSmoothsLatency() {
    var policy = UpcomingPreloadPolicy()
    policy.recordPreparation(seconds: 10)
    policy.recordPreparation(seconds: .infinity)
    policy.recordPreparation(seconds: -1)
    #expect(policy.estimatedPreparation == 10)
    policy.recordPreparation(seconds: 20)
    #expect(policy.estimatedPreparation == 13)
}

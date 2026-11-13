import Testing
import Foundation
import HealthKit
@testable import OneField

struct OneFieldTests {
    @Test @MainActor func emptyHealthStoreIsNotAReadFailure() {
        let error = NSError(domain: HKErrorDomain, code: HKError.Code.errorNoData.rawValue)
        let result = HealthKitManager.stepQueryError(error)
        guard let mapped = result as? HealthKitError else {
            Issue.record("Expected an empty-data result")
            return
        }
        if case .noData = mapped {} else {
            Issue.record("Expected noData")
        }
    }

    @Test @MainActor func otherHealthErrorsKeepTheirDetails() {
        let error = NSError(domain: HKErrorDomain, code: HKError.Code.errorHealthDataUnavailable.rawValue)
        let result = HealthKitManager.stepQueryError(error) as NSError
        #expect(result.domain == error.domain)
        #expect(result.code == error.code)
    }

    @Test @MainActor func heatHydrationQuestionHasAnOfflineAnswer() {
        let response = ChatViewModel.heatHydrationInformation(for: "How many times should I drink water in a 39 degree heat")
        #expect(response?.contains("drink water regularly") == true)
        #expect(response?.contains("cdc.gov") == true)
        #expect(ChatViewModel.heatHydrationInformation(for: "¿Cuánta agua debo beber con este calor?")?.contains("bebe agua") == true)
    }

    @Test @MainActor func unrelatedQuestionsDoNotReceiveHydrationAdvice() {
        #expect(ChatViewModel.heatHydrationInformation(for: "How many steps have I done today?") == nil)
        #expect(ChatViewModel.heatHydrationInformation(for: "What is the boiling point of water?") == nil)
    }
}

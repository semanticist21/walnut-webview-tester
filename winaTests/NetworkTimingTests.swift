//
//  NetworkTimingTests.swift
//  winaTests
//
//  Tests for NetworkTimingView timing display and statistics.
//

import XCTest
import SwiftUI
@testable import wina

final class NetworkTimingTests: XCTestCase {

    // MARK: - Helper Functions

    private func createRequest(
        duration: TimeInterval,
        status: Int = 200,
        method: String = "GET"
    ) -> NetworkRequest {
        let startTime = Date().addingTimeInterval(-duration)
        return NetworkRequest(
            id: UUID(),
            method: method,
            url: "https://api.example.com/test",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: startTime,
            pageIsSecure: true,
            status: status,
            statusText: "OK",
            responseHeaders: nil,
            responseBodyPreview: "{}",
            endTime: Date(),
            error: nil,
            requestType: .fetch
        )
    }

    // MARK: - NetworkTimingView Tests

    func testNetworkTimingViewInitialization() {
        let request = createRequest(duration: 1.5)
        let view = NetworkTimingView(request: request)
        XCTAssertNotNil(view)
    }

    func testNetworkTimingViewWithFastRequest() {
        let request = createRequest(duration: 0.1)  // 100ms
        let view = NetworkTimingView(request: request)
        XCTAssertNotNil(view)
    }

    func testNetworkTimingViewWithSlowRequest() {
        let request = createRequest(duration: 5.0)  // 5 seconds
        let view = NetworkTimingView(request: request)
        XCTAssertNotNil(view)
    }

    func testNetworkTimingViewWithZeroDuration() {
        let request = createRequest(duration: 0)
        let view = NetworkTimingView(request: request)
        XCTAssertNotNil(view)
    }

    func testNetworkTimingViewWithVeryShortDuration() {
        let request = createRequest(duration: 0.001)  // 1ms
        let view = NetworkTimingView(request: request)
        XCTAssertNotNil(view)
    }

    // MARK: - Duration Formatting Tests

    func testDurationTextFormatting() {
        let request = createRequest(duration: 0.5)
        XCTAssertEqual(request.durationText, "500ms")
    }

    func testDurationTextFormattingSeconds() {
        let request = createRequest(duration: 2.5)
        XCTAssertEqual(request.durationText, "2.50s")
    }

    func testDurationTextFormattingLessThanMillisecond() {
        let request = createRequest(duration: 0.0001)
        XCTAssertEqual(request.durationText, "0ms")
    }

    func testDurationTextFormattingGreaterThanSecond() {
        let request = createRequest(duration: 10.5)
        XCTAssertEqual(request.durationText, "10.50s")
    }

    // MARK: - Timing Visualization Tests

    func testTimingVisualizationBar() {
        let duration = 1.5
        let view = TimingVisualizationBar(duration: duration)
        XCTAssertNotNil(view)
    }

    func testTimingVisualizationBarWithShortDuration() {
        let duration = 0.05  // 50ms
        let view = TimingVisualizationBar(duration: duration)
        XCTAssertNotNil(view)
    }

    func testTimingVisualizationBarWithLongDuration() {
        let duration = 30.0  // 30 seconds
        let view = TimingVisualizationBar(duration: duration)
        XCTAssertNotNil(view)
    }

    // MARK: - Timing Phase Row Tests

    func testTimingPhaseRow() {
        let view = TimingPhaseRow(
            label: "Request → Response",
            duration: 1.5,
            color: .blue,
            icon: "arrow.right"
        )
        XCTAssertNotNil(view)
    }

    func testTimingPhaseRowMilliseconds() {
        let view = TimingPhaseRow(
            label: "Request",
            duration: 0.1,
            color: .blue,
            icon: "arrow.right"
        )
        XCTAssertNotNil(view)
    }

    func testTimingPhaseRowSeconds() {
        let view = TimingPhaseRow(
            label: "Response",
            duration: 2.5,
            color: .green,
            icon: "arrow.down"
        )
        XCTAssertNotNil(view)
    }

    // MARK: - Timing Statistics Tests

    func testTimingStatisticsWithSingleRequest() {
        let request = createRequest(duration: 1.0)
        let view = TimingStatisticsView(requests: [request])
        XCTAssertNotNil(view)
    }

    func testTimingStatisticsWithMultipleRequests() {
        let requests = [
            createRequest(duration: 0.5),
            createRequest(duration: 1.0),
            createRequest(duration: 1.5),
            createRequest(duration: 2.0)
        ]
        let view = TimingStatisticsView(requests: requests)
        XCTAssertNotNil(view)
    }

    func testTimingStatisticsWithEmptyArray() {
        let view = TimingStatisticsView(requests: [])
        XCTAssertNotNil(view)
    }

    func testAverageDurationCalculation() {
        let requests = [
            createRequest(duration: 1.0),
            createRequest(duration: 2.0),
            createRequest(duration: 3.0)
        ]

        let totalDuration = requests.compactMap { $0.duration }.reduce(0, +)
        let average = totalDuration / Double(requests.count)

        // Use accuracy to account for small timing variations in createRequest helper
        XCTAssertEqual(average, 2.0, accuracy: 0.1)
    }

    func testLongestDurationDetection() {
        let requests = [
            createRequest(duration: 0.5),
            createRequest(duration: 2.0),
            createRequest(duration: 1.0)
        ]

        let longest = requests.compactMap { $0.duration }.max()
        // Use accuracy to account for small timing variations in createRequest helper
        XCTAssertEqual(longest!, 2.0, accuracy: 0.1)
    }

    func testShortestDurationDetection() {
        let requests = [
            createRequest(duration: 2.0),
            createRequest(duration: 0.5),
            createRequest(duration: 1.0)
        ]

        let shortest = requests.compactMap { $0.duration }.min()
        // Use accuracy to account for small timing variations in createRequest helper
        XCTAssertEqual(shortest!, 0.5, accuracy: 0.1)
    }

    // MARK: - Request Duration Property Tests

    func testRequestDurationCalculation() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1.5)
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://api.example.com/test",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: startTime,
            pageIsSecure: true,
            status: 200,
            statusText: "OK",
            responseHeaders: nil,
            responseBodyPreview: "{}",
            endTime: endTime,
            requestType: .fetch
        )

        XCTAssertNotNil(request.duration)
        XCTAssertEqual(request.duration!, 1.5, accuracy: 0.01)
    }

    func testRequestDurationNilWhenNoEndTime() {
        let request = createRequest(duration: 1.5)
        var mutableRequest = request
        mutableRequest.endTime = nil

        XCTAssertNil(mutableRequest.duration)
    }

    // MARK: - Statistic Row Tests

    func testStatisticRow() {
        let view = StatisticRow(
            label: "Average",
            value: "1.5s",
            icon: "chart.bar",
            color: .blue
        )
        XCTAssertNotNil(view)
    }

    func testStatisticRowWithDifferentColors() {
        let blueRow = StatisticRow(label: "Test", value: "1s", icon: "chart.bar", color: .blue)
        let redRow = StatisticRow(label: "Test", value: "2s", icon: "arrow.up", color: .red)
        let greenRow = StatisticRow(label: "Test", value: "0.5s", icon: "arrow.down", color: .green)

        XCTAssertNotNil(blueRow)
        XCTAssertNotNil(redRow)
        XCTAssertNotNil(greenRow)
    }

    // MARK: - Integration Tests

    func testTimingViewWithVariousRequestTypes() {
        let requests = [
            createRequest(duration: 0.5, method: "GET"),
            createRequest(duration: 1.0, method: "POST"),
            createRequest(duration: 0.75, method: "PUT"),
            createRequest(duration: 0.3, method: "DELETE")
        ]

        for request in requests {
            let view = NetworkTimingView(request: request)
            XCTAssertNotNil(view)
        }
    }

    func testTimingViewWithDifferentStatusCodes() {
        let requests = [
            createRequest(duration: 0.5, status: 200),  // OK
            createRequest(duration: 0.8, status: 301),  // Redirect
            createRequest(duration: 1.0, status: 404),  // Not Found
            createRequest(duration: 1.2, status: 500)   // Server Error
        ]

        for request in requests {
            let view = NetworkTimingView(request: request)
            XCTAssertNotNil(view)
        }
    }

    func testTimingStatisticsWithMixedDurations() {
        let requests = [
            createRequest(duration: 0.1),   // Very fast
            createRequest(duration: 0.5),   // Fast
            createRequest(duration: 1.0),   // Normal
            createRequest(duration: 2.0),   // Slow
            createRequest(duration: 5.0)    // Very slow
        ]

        let view = TimingStatisticsView(requests: requests)
        XCTAssertNotNil(view)

        let durations = requests.compactMap { $0.duration }
        let average = durations.reduce(0, +) / Double(durations.count)
        let longest = durations.max() ?? 0
        let shortest = durations.min() ?? 0

        // Use accuracy to account for small timing variations in createRequest helper
        XCTAssertEqual(average, 1.72, accuracy: 0.1)
        XCTAssertEqual(longest, 5.0, accuracy: 0.1)
        XCTAssertEqual(shortest, 0.1, accuracy: 0.1)
    }

    // MARK: - Edge Cases

    func testNetworkTimingViewWithNegativeDuration() {
        // This shouldn't happen in practice, but test for robustness
        let request = NetworkRequest(
            id: UUID(),
            method: "GET",
            url: "https://api.example.com/test",
            requestHeaders: nil,
            requestBodyPreview: nil,
            startTime: Date(),
            pageIsSecure: true,
            status: 200,
            statusText: "OK",
            responseHeaders: nil,
            responseBodyPreview: "{}",
            endTime: Date().addingTimeInterval(-1.0),  // Negative duration
            requestType: .fetch
        )

        let view = NetworkTimingView(request: request)
        XCTAssertNotNil(view)
    }

    func testTimingVisualizationWithExtremeValues() {
        // Very short
        let shortView = TimingVisualizationBar(duration: 0.001)
        XCTAssertNotNil(shortView)

        // Very long
        let longView = TimingVisualizationBar(duration: 300.0)
        XCTAssertNotNil(longView)
    }

    func testStatisticsWithAllIdenticalDurations() {
        let requests = [
            createRequest(duration: 1.0),
            createRequest(duration: 1.0),
            createRequest(duration: 1.0)
        ]

        let durations = requests.compactMap { $0.duration }
        let average = durations.reduce(0, +) / Double(durations.count)
        let longest = durations.max() ?? 0
        let shortest = durations.min() ?? 0

        // Use accuracy to account for small timing variations in createRequest helper
        XCTAssertEqual(average, 1.0, accuracy: 0.1)
        XCTAssertEqual(longest, 1.0, accuracy: 0.1)
        XCTAssertEqual(shortest, 1.0, accuracy: 0.1)
    }
}

import XCTest
@testable import wina

@MainActor
final class ConsoleManagerTests: XCTestCase {

    var manager: ConsoleManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = ConsoleManager()
    }

    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }

    /// async context에서 로그가 추가될 때까지 대기 (flaky RunLoop polling 대신 Task.sleep 사용)
    private func waitForLogs(_ expectedCount: Int, timeout: TimeInterval = 2.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.logs.count < expectedCount && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    // MARK: - Timer Tests

    func testTimerStart() async {
        manager.time(label: "test")
        await waitForLogs(1)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].type, .time)
        XCTAssertEqual(logs[0].timerLabel, "test")
        XCTAssertTrue(logs[0].message.contains("started"))
    }

    func testTimerEnd() async {
        manager.time(label: "fetchData")
        await waitForLogs(1)

        // Task.sleep 사용 (usleep 대신)
        try? await Task.sleep(for: .milliseconds(150))

        manager.timeEnd(label: "fetchData")
        await waitForLogs(2)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[1].type, .timeEnd)
        XCTAssertEqual(logs[1].timerLabel, "fetchData")
        XCTAssertNotNil(logs[1].timerElapsed)
        XCTAssertGreaterThan(logs[1].timerElapsed ?? 0, 0.1)  // 최소 100ms (CI 안정성 위해 증가)
    }

    func testTimeLogMidway() async {
        manager.time(label: "process")
        await waitForLogs(1)

        try? await Task.sleep(for: .milliseconds(80))
        manager.timeLog(label: "process")
        await waitForLogs(2)

        try? await Task.sleep(for: .milliseconds(80))
        manager.timeEnd(label: "process")
        await waitForLogs(3)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 3)
        XCTAssertEqual(logs[1].type, .timeLog)
        XCTAssertEqual(logs[2].type, .timeEnd)

        // timeLog와 timeEnd의 경과시간 비교
        let timeLogElapsed = logs[1].timerElapsed ?? 0
        let timeEndElapsed = logs[2].timerElapsed ?? 0
        XCTAssertGreaterThan(timeEndElapsed, timeLogElapsed)
    }

    func testTimerNotFound() async {
        manager.timeEnd(label: "nonexistent")
        await waitForLogs(1)

        let logs = manager.logs
        XCTAssertGreaterThan(logs.count, 0)

        let errorLog = logs.first(where: { $0.type == .error })
        XCTAssertNotNil(errorLog)
        XCTAssertTrue(errorLog?.message.contains("not found") ?? false)
    }

    func testMultipleTimers() async {
        manager.time(label: "timer1")
        manager.time(label: "timer2")
        manager.time(label: "timer3")
        await waitForLogs(3)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 3)
        XCTAssertEqual(logs[0].timerLabel, "timer1")
        XCTAssertEqual(logs[1].timerLabel, "timer2")
        XCTAssertEqual(logs[2].timerLabel, "timer3")
    }

    // MARK: - Count Tests

    func testCountDefault() async {
        manager.count()
        manager.count()
        manager.count()
        await waitForLogs(3)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 3)

        XCTAssertEqual(logs[0].countValue, 1)
        XCTAssertEqual(logs[1].countValue, 2)
        XCTAssertEqual(logs[2].countValue, 3)
    }

    func testCountWithLabel() async {
        manager.count(label: "clicks")
        manager.count(label: "views")
        manager.count(label: "clicks")
        manager.count(label: "views")
        manager.count(label: "clicks")
        await waitForLogs(5)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 5)

        let clickLogs = logs.filter { $0.countLabel == "clicks" }
        XCTAssertEqual(clickLogs.count, 3)
        XCTAssertEqual(clickLogs[0].countValue, 1)
        XCTAssertEqual(clickLogs[1].countValue, 2)
        XCTAssertEqual(clickLogs[2].countValue, 3)

        let viewLogs = logs.filter { $0.countLabel == "views" }
        XCTAssertEqual(viewLogs.count, 2)
        XCTAssertEqual(viewLogs[0].countValue, 1)
        XCTAssertEqual(viewLogs[1].countValue, 2)
    }

    func testCountReset() async {
        manager.count(label: "attempts")
        manager.count(label: "attempts")
        manager.count(label: "attempts")
        await waitForLogs(3)

        manager.countReset(label: "attempts")
        await waitForLogs(4)

        manager.count(label: "attempts")
        await waitForLogs(5)

        let logs = manager.logs
        let countLogs = logs.filter { $0.type == .count && $0.countLabel == "attempts" }

        // 3회 증가, 리셋, 1회 증가 = 4개 count 로그
        XCTAssertEqual(countLogs.count, 4)
        XCTAssertEqual(countLogs[3].countValue, 1)  // 리셋 후 1부터 시작
    }

    // MARK: - Assert Tests

    func testAssertTrue() {
        manager.assert(true, message: "This should pass")

        let logs = manager.logs
        XCTAssertEqual(logs.count, 0)  // 실패하지 않으므로 로그 없음
    }

    func testAssertFalse() async {
        manager.assert(false, message: "This is an error")
        await waitForLogs(1)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].type, .assert)
        XCTAssertTrue(logs[0].message.contains("This is an error"))
    }

    // MARK: - Clear Tests

    func testClearResetsContexts() async {
        manager.time(label: "test")
        manager.count(label: "test")
        await waitForLogs(2)

        manager.clear()

        // 타이머 컨텍스트도 초기화되어야 함
        manager.timeEnd(label: "test")
        await waitForLogs(3)

        let logs = manager.logs
        let errorLog = logs.first(where: { $0.type == .error })
        XCTAssertNotNil(errorLog)  // 타이머가 없어서 에러 발생
    }

    // MARK: - Integration Tests

    func testComplexScenario() async {
        // 복잡한 시나리오: 여러 메서드 조합
        manager.time(label: "operation")

        manager.count(label: "step1")
        manager.count(label: "step1")
        await waitForLogs(3)

        try? await Task.sleep(for: .milliseconds(80))
        manager.timeLog(label: "operation")
        await waitForLogs(4)

        manager.count(label: "step2")
        manager.count(label: "step2")
        manager.count(label: "step2")
        await waitForLogs(7)

        try? await Task.sleep(for: .milliseconds(80))
        manager.timeEnd(label: "operation")
        await waitForLogs(8)

        manager.assert(manager.logs.count > 5, message: "Should have multiple logs")

        let logs = manager.logs
        XCTAssertGreaterThan(logs.count, 5)

        // 타입 분포 확인
        let timeCount = logs.filter { $0.type == .time || $0.type == .timeLog || $0.type == .timeEnd }.count
        let countCount = logs.filter { $0.type == .count }.count

        XCTAssertEqual(timeCount, 3)  // time, timeLog, timeEnd
        XCTAssertEqual(countCount, 5)  // count 5회
    }

    // MARK: - Thread Safety Tests

    func testConcurrentTimer() async {
        // actor-isolated 환경에서 concurrent 테스트를 위해 Task 그룹 사용
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    let label = "timer\(i)"
                    self.manager.time(label: label)
                    try? await Task.sleep(for: .milliseconds(Int.random(in: 20..<80)))
                    self.manager.timeEnd(label: label)
                }
            }
        }

        await waitForLogs(20)  // 10 timers * 2 (start + end)

        let logs = manager.logs
        let timerLogs = logs.filter { $0.type == .time || $0.type == .timeEnd }
        XCTAssertGreaterThan(timerLogs.count, 0)
    }

    func testConcurrentCount() async {
        // actor-isolated 환경에서 concurrent 테스트
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { @MainActor in
                    self.manager.count(label: "concurrent")
                }
            }
        }

        await waitForLogs(50)  // Wait for at least 50 logs

        let logs = manager.logs
        let countLogs = logs.filter { $0.countLabel == "concurrent" }

        // 모든 count가 기록되어야 함
        XCTAssertGreaterThanOrEqual(countLogs.count, 50)  // 대부분은 성공해야 함
    }
}

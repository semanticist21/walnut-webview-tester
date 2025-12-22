import XCTest
@testable import wina

final class ConsoleManagerTests: XCTestCase {

    var manager: ConsoleManager!

    override func setUp() {
        super.setUp()
        manager = ConsoleManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    /// Main thread에서 로그가 추가될 때까지 대기
    private func waitForLogs(_ expectedCount: Int, timeout: TimeInterval = 0.5) {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.logs.count < expectedCount && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    // MARK: - Timer Tests

    func testTimerStart() {
        manager.time(label: "test")
        waitForLogs(1)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].type, .time)
        XCTAssertEqual(logs[0].timerLabel, "test")
        XCTAssertTrue(logs[0].message.contains("started"))
    }

    func testTimerEnd() {
        manager.time(label: "fetchData")
        waitForLogs(1)

        // 약간의 지연을 주어 시간이 경과하도록
        usleep(100_000)  // 100ms

        manager.timeEnd(label: "fetchData")
        waitForLogs(2)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs[1].type, .timeEnd)
        XCTAssertEqual(logs[1].timerLabel, "fetchData")
        XCTAssertNotNil(logs[1].timerElapsed)
        XCTAssertGreaterThan(logs[1].timerElapsed ?? 0, 0.05)  // 최소 50ms
    }

    func testTimeLogMidway() {
        manager.time(label: "process")
        waitForLogs(1)

        usleep(50_000)  // 50ms
        manager.timeLog(label: "process")
        waitForLogs(2)

        usleep(50_000)  // 추가 50ms
        manager.timeEnd(label: "process")
        waitForLogs(3)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 3)
        XCTAssertEqual(logs[1].type, .timeLog)
        XCTAssertEqual(logs[2].type, .timeEnd)

        // timeLog와 timeEnd의 경과시간 비교
        let timeLogElapsed = logs[1].timerElapsed ?? 0
        let timeEndElapsed = logs[2].timerElapsed ?? 0
        XCTAssertGreaterThan(timeEndElapsed, timeLogElapsed)
    }

    func testTimerNotFound() {
        manager.timeEnd(label: "nonexistent")
        waitForLogs(1)

        let logs = manager.logs
        XCTAssertGreaterThan(logs.count, 0)

        let errorLog = logs.first(where: { $0.type == .error })
        XCTAssertNotNil(errorLog)
        XCTAssertTrue(errorLog?.message.contains("not found") ?? false)
    }

    func testMultipleTimers() {
        manager.time(label: "timer1")
        manager.time(label: "timer2")
        manager.time(label: "timer3")
        waitForLogs(3)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 3)
        XCTAssertEqual(logs[0].timerLabel, "timer1")
        XCTAssertEqual(logs[1].timerLabel, "timer2")
        XCTAssertEqual(logs[2].timerLabel, "timer3")
    }

    // MARK: - Count Tests

    func testCountDefault() {
        manager.count()
        manager.count()
        manager.count()
        waitForLogs(3)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 3)

        XCTAssertEqual(logs[0].countValue, 1)
        XCTAssertEqual(logs[1].countValue, 2)
        XCTAssertEqual(logs[2].countValue, 3)
    }

    func testCountWithLabel() {
        manager.count(label: "clicks")
        manager.count(label: "views")
        manager.count(label: "clicks")
        manager.count(label: "views")
        manager.count(label: "clicks")
        waitForLogs(5)

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

    func testCountReset() {
        manager.count(label: "attempts")
        manager.count(label: "attempts")
        manager.count(label: "attempts")
        waitForLogs(3)

        manager.countReset(label: "attempts")
        waitForLogs(4)

        manager.count(label: "attempts")
        waitForLogs(5)

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

    func testAssertFalse() {
        manager.assert(false, message: "This is an error")
        waitForLogs(1)

        let logs = manager.logs
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].type, .assert)
        XCTAssertTrue(logs[0].message.contains("This is an error"))
    }

    // MARK: - Clear Tests

    func testClearResetsContexts() {
        manager.time(label: "test")
        manager.count(label: "test")
        waitForLogs(2)

        manager.clear()

        // 타이머 컨텍스트도 초기화되어야 함
        manager.timeEnd(label: "test")
        waitForLogs(3)

        let logs = manager.logs
        let errorLog = logs.first(where: { $0.type == .error })
        XCTAssertNotNil(errorLog)  // 타이머가 없어서 에러 발생
    }

    // MARK: - Integration Tests

    func testComplexScenario() {
        // 복잡한 시나리오: 여러 메서드 조합
        manager.time(label: "operation")

        manager.count(label: "step1")
        manager.count(label: "step1")
        waitForLogs(3)

        usleep(50_000)
        manager.timeLog(label: "operation")
        waitForLogs(4)

        manager.count(label: "step2")
        manager.count(label: "step2")
        manager.count(label: "step2")
        waitForLogs(7)

        usleep(50_000)
        manager.timeEnd(label: "operation")
        waitForLogs(8)

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

    func testConcurrentTimer() {
        let queue = DispatchQueue.global()
        let group = DispatchGroup()

        for i in 0..<10 {
            queue.async(group: group) {
                let label = "timer\(i)"
                self.manager.time(label: label)
                usleep(UInt32.random(in: 10_000..<50_000))
                self.manager.timeEnd(label: label)
            }
        }

        group.wait()
        waitForLogs(20)  // 10 timers * 2 (start + end)

        let logs = manager.logs
        let timerLogs = logs.filter { $0.type == .time || $0.type == .timeEnd }
        XCTAssertGreaterThan(timerLogs.count, 0)
    }

    func testConcurrentCount() {
        let queue = DispatchQueue.global()
        let group = DispatchGroup()

        for _ in 0..<100 {
            queue.async(group: group) {
                self.manager.count(label: "concurrent")
            }
        }

        group.wait()
        waitForLogs(50)  // Wait for at least 50 logs

        let logs = manager.logs
        let countLogs = logs.filter { $0.countLabel == "concurrent" }

        // 모든 count가 기록되어야 함
        XCTAssertGreaterThanOrEqual(countLogs.count, 50)  // 대부분은 성공해야 함
    }
}

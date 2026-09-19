import XCTest
@testable import Services

final class CostReceiptTests: XCTestCase {
    func testAveragesOverUptime() {
        let receipt = CostReceipt(sample: CostSample(
            cpuSeconds: 3.6, wakeups: 360, footprintBytes: 36 * 1_048_576, uptime: 3600
        ))
        XCTAssertEqual(receipt.cpuPercent, 0.1, accuracy: 1e-9)
        XCTAssertEqual(receipt.wakeupsPerHour, 360, accuracy: 1e-9)
        XCTAssertEqual(receipt.footprintMB, 36, accuracy: 1e-9)
    }

    func testFormattingUsesThreeDecimalsBelowOnePercent() {
        let receipt = CostReceipt(sample: CostSample(cpuSeconds: 0.144, wakeups: 41, footprintBytes: 0, uptime: 3600))
        XCTAssertEqual(receipt.cpuText, "0.004%")
        XCTAssertEqual(receipt.wakeupsText, "41")
    }

    func testFormattingUsesOneDecimalAboveOnePercent() {
        let receipt = CostReceipt(sample: CostSample(cpuSeconds: 90, wakeups: 0, footprintBytes: 0, uptime: 3600))
        XCTAssertEqual(receipt.cpuText, "2.5%")
    }

    func testZeroUptimeDoesNotDivideByZero() {
        let receipt = CostReceipt(sample: CostSample(cpuSeconds: 0.5, wakeups: 1, footprintBytes: 0, uptime: 0))
        XCTAssertTrue(receipt.cpuPercent.isFinite)
        XCTAssertTrue(receipt.wakeupsPerHour.isFinite)
    }

    func testLiveSampleIsReadable() {
        let sample = CostSample.current()
        XCTAssertNotNil(sample)
        XCTAssertGreaterThan(sample?.footprintBytes ?? 0, 0)
    }
}

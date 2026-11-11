import XCTest
import ServiceManagement
@testable import BeanCore

final class DurationInputTests: XCTestCase {
    func testAcceptsWholeMinutesInRange() {
        XCTAssertEqual(DurationInput.minutes(from: "1"), 1)
        XCTAssertEqual(DurationInput.minutes(from: "30"), 30)
        XCTAssertEqual(DurationInput.minutes(from: " 45 "), 45)
        XCTAssertEqual(DurationInput.minutes(from: "1440"), 1440)
    }

    /// Each of these crashed or misbehaved in the 1.0 build.
    func testRejectsInputThatBrokeVersionOne() {
        for bad in ["inf", "1e20", "nan", "0.001", "0", "-5", "1441", "99999", "", "  ", "abc", "3.5", "١٢"] {
            XCTAssertNil(DurationInput.minutes(from: bad), "\"\(bad)\" should be rejected")
        }
    }
}

@MainActor
final class LoginItemControllerTests: XCTestCase {
    func testStatusMapping() {
        XCTAssertEqual(LoginItemController.state(for: .enabled), .on)
        XCTAssertEqual(LoginItemController.state(for: .notRegistered), .off)
        XCTAssertEqual(LoginItemController.state(for: .requiresApproval), .needsApproval)
        XCTAssertEqual(LoginItemController.state(for: .notFound), .off)
    }

    func testNeverRegisteredCopyShowsOffAndCanStillRegister() {
        let service = FakeLoginItemService()
        service.status = .notFound
        let controller = LoginItemController(service: service)
        XCTAssertEqual(controller.state, .off)
        XCTAssertNil(controller.errorMessage)
        controller.setEnabled(true)
        XCTAssertEqual(controller.state, .on)
    }

    func testRefreshReadsLiveStatusInsteadOfCaching() {
        let service = FakeLoginItemService()
        let controller = LoginItemController(service: service)
        XCTAssertEqual(controller.state, .off)
        service.status = .enabled // changed in System Settings behind the app's back
        controller.refresh()
        XCTAssertEqual(controller.state, .on)
    }

    func testEnableCanLandInNeedsApproval() {
        let service = FakeLoginItemService()
        service.statusAfterRegister = .requiresApproval
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        XCTAssertEqual(controller.state, .needsApproval)
        controller.openSystemSettings()
        XCTAssertTrue(service.openedSettings)
    }

    func testRegisterErrorIsSurfacedAndStateReflectsSystem() {
        let service = FakeLoginItemService()
        service.registerError = FakeError()
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        XCTAssertEqual(controller.state, .off)
        XCTAssertEqual(controller.errorMessage, "Couldn't turn on Launch at Login: Operation not permitted")
    }

    func testSuccessfulToggleClearsPreviousError() {
        let service = FakeLoginItemService()
        service.registerError = FakeError()
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        service.registerError = nil
        controller.setEnabled(true)
        XCTAssertNil(controller.errorMessage)
        XCTAssertEqual(controller.state, .on)
        controller.setEnabled(false)
        XCTAssertEqual(controller.state, .off)
    }
}

final class RemainingTimeFormatterTests: XCTestCase {
    func testFormats() {
        XCTAssertEqual(RemainingTimeFormatter.string(seconds: 0), "0:00")
        XCTAssertEqual(RemainingTimeFormatter.string(seconds: 59), "0:59")
        XCTAssertEqual(RemainingTimeFormatter.string(seconds: 245), "4:05")
        XCTAssertEqual(RemainingTimeFormatter.string(seconds: 3723), "1:02:03")
        XCTAssertEqual(RemainingTimeFormatter.string(seconds: 86_400), "24:00:00")
        XCTAssertEqual(RemainingTimeFormatter.string(seconds: -3), "0:00")
    }
}

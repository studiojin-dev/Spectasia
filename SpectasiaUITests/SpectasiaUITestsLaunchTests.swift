//
//  SpectasiaUITestsLaunchTests.swift
//  SpectasiaUITests
//
//  Created by kimjeongjin on 1/27/26.
//

import XCTest

final class SpectasiaUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    private static var isRunningInCI: Bool {
        let env = ProcessInfo.processInfo.environment
        let ci = env["CI"] ?? env["GITHUB_ACTIONS"] ?? env["BUILDKITE"] ?? env["TF_BUILD"]
        return ci == "1" || ci?.lowercased() == "true"
    }

    private static var shouldCaptureScreenshots: Bool {
        let env = ProcessInfo.processInfo.environment
        if let value = env["SPECTASIA_UI_SCREENSHOTS"] {
            return value == "1" || value.lowercased() == "true"
        }
        return false
    }

    override func setUpWithError() throws {
        if Self.isRunningInCI {
            throw XCTSkip("Skipping launch screenshot tests in CI to avoid flaky UI timing.")
        }
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        guard Self.shouldCaptureScreenshots else {
            let attachment = XCTAttachment(string: "Screenshot capture disabled. Set SPECTASIA_UI_SCREENSHOTS=1 to enable.")
            attachment.name = "Launch Screen (Skipped)"
            attachment.lifetime = .keepAlways
            add(attachment)
            return
        }

        if waitForAppReady(app, timeout: 30),
           let attachment = tryTakeScreenshotAttachment(app: app, name: "Launch Screen", retries: 3, delay: 0.75) {
            add(attachment)
        } else {
            let attachment = XCTAttachment(string: "Skipped screenshot: app not ready or snapshot failed after retries.")
            attachment.name = "Launch Screen (Skipped)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    private func waitForAppReady(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if app.state == .runningForeground, app.windows.count > 0 {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    @MainActor
    private func tryTakeScreenshotAttachment(app: XCUIApplication, name: String, retries: Int, delay: TimeInterval) -> XCTAttachment? {
        for attempt in 0..<max(1, retries) {
            if app.windows.count > 0 {
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = name
                attachment.lifetime = .keepAlways
                return attachment
            }
            if attempt < retries - 1 {
                RunLoop.current.run(until: Date().addingTimeInterval(delay))
            }
        }
        return nil
    }
}

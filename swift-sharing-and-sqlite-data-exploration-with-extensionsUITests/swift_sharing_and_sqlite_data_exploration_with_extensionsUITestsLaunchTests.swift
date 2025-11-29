//
//  swift_sharing_and_sqlite_data_exploration_with_extensionsUITestsLaunchTests.swift
//  swift-sharing-and-sqlite-data-exploration-with-extensionsUITests
//
//  Created by Michael Lustig on 11/29/25.
//

import XCTest

final class swift_sharing_and_sqlite_data_exploration_with_extensionsUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

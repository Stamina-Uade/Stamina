//
//  TrainerUITestsLaunchTests.swift
//  TrainerUITests
//
//  Created by Iván Karkoszka on 09/09/2026.
//

import XCTest

final class TrainerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // Sin servidor ni llavero, como el resto de los tests de UI
        // (`FlujoDeEntradaUITests.sinServidor`).
        app.launchArguments = ["-serviciosDePrueba", "-apiBase", "http://127.0.0.1:9/v1"]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

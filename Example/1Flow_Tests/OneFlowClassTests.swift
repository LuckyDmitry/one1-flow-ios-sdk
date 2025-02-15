//
//  OneFlowClassTests.swift
//  1Flow_Tests
//
//  Created by Rohan Moradiya on 30/04/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import XCTest
@testable import _1Flow
@testable import _Flow_Example

class OneFlowTests: XCTestCase {
    var apiController = MockAPIController()
    var projectDetailsControler = MockProjectDetailsController()

    override func setUp() {
        super.setUp()
        OneFlow.shared.apiController = apiController
        OneFlow.shared.projectDetailsController = projectDetailsControler
//        apiController = MockAPIController()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testConfigureOneFlow_CallingMultipleTimeOnlyCallAddUserOnce() {
        OneFlow.configure("MyKey")
        OneFlow.shared.reachabilityChanged(note: Notification(name: Notification.Name.init(rawValue: ""), object: OneFlow.shared.reachability, userInfo: nil))
        XCTAssertTrue(apiController.isAddUserCalled, "Add user not called when calling configure")
        apiController.isAddUserCalled = false
        OneFlow.configure("MyKey2")
        XCTAssertFalse(apiController.isAddUserCalled, "Calling configure multiple times should not call add user again")
    }

    func testRecordEvent_shouldCall_EventManagerRecordEvent() {
        let expectation = XCTestExpectation()
        let eventManager = MockEventManager(expectation)
        OneFlow.shared.eventManager = eventManager
        OneFlow.recordEventName("Event", parameters: nil)
        self.wait(for: [expectation], timeout: 1.0)
    }

    func testRecordEvent_IfDatePassedInParams_itShouldConvertToTimeInterval() {
        let expectation = XCTestExpectation()
        let date = Date()
        let expectedInterval = Int(date.timeIntervalSince1970)
        let params = ["date": date]
        let eventManager = MockEventManager(expectation)
        OneFlow.shared.eventManager = eventManager
        OneFlow.recordEventName("Event", parameters: params)
        self.wait(for: [expectation], timeout: 1.0)
        guard let receivedParams = eventManager.finalParameter else {
            XCTFail("Event manager should receive parameter")
            return
        }
        guard let receivedDate = receivedParams["date"] as? Int else {
            XCTFail("Date should be interger value in final params")
            return
        }
        XCTAssertEqual(expectedInterval, receivedDate, "Interval should match")
    }

    func testRecordEvent_IfNotParsableParams_itShouldRemoveParameter() {
        struct MockClass {
            let name: String
        }
        
        let obj = MockClass(name: "FirstName")
        let expectation = XCTestExpectation()
        let params = ["Number": "1234567890", "SomeObject": obj] as [String : Any]
        let eventManager = MockEventManager(expectation)
        OneFlow.shared.eventManager = eventManager
        OneFlow.recordEventName("Event", parameters: params)
        self.wait(for: [expectation], timeout: 1.0)
        guard let receivedParams = eventManager.finalParameter else {
            XCTFail("Event manager should receive parameter")
            return
        }
        if let _ = receivedParams["SomeObject"] {
            XCTFail("Parameter should remove SomeObject in final params")
        }
    }

    func testLogUser_shouldUploadPendingEvent() {
        let expectation = XCTestExpectation(description: "Should upload pending event")
        let eventManager = MockEventManager(expectation)
        OneFlow.shared.eventManager = eventManager
        let mockProjectDetails = MockProjectDetailsController()
        mockProjectDetails.analytic_user_id = "abc"
        OneFlow.shared.projectDetailsController = mockProjectDetails
        OneFlow.logUser("user_id", userDetails: nil)
        self.wait(for: [expectation], timeout: 1.0)
    }

    func testLogUser_shouldUploadPendingSurvey() {
        let expectation = XCTestExpectation(description: "Should upload pending survey")
        let surveyManager = MockSurveyManager(expectation)
        let mockProjectDetails = MockProjectDetailsController()
        mockProjectDetails.analytic_user_id = "abc"
        OneFlow.shared.eventManager = OFEventManager()
        OneFlow.shared.projectDetailsController = mockProjectDetails
        OneFlow.shared.eventManager.projectDetailsController = mockProjectDetails
        OneFlow.shared.eventManager.surveyManager = surveyManager
        OneFlow.logUser("user_id", userDetails: nil)
        self.wait(for: [expectation], timeout: 4.0)
    }

    func testLogUser_IfDatePassedInParams_itShouldConvertToTimeInterval() {
        let date = Date()
        let expectedInterval = Int(date.timeIntervalSince1970)
        let params = ["date": date]
        let projectDetailsController = MockProjectDetailsController()
        OneFlow.shared.projectDetailsController = projectDetailsController
        OneFlow.logUser("abc", userDetails: params)
        guard let receivedParams = projectDetailsController.newUserData else {
            XCTFail("Project details controller should have new data")
            return
        }
        guard let receivedDate = receivedParams["date"] as? Int else {
            XCTFail("Date should be interger value in final params")
            return
        }
        XCTAssertEqual(expectedInterval, receivedDate, "Interval should match")
    }

    func testLogUser_IfNotParsableParams_itShouldRemoveParameter() {
        struct MockClass {
            let name: String
        }
        
        let obj = MockClass(name: "FirstName")
        let params = ["Number": "1234567890", "SomeObject": obj] as [String : Any]
        let projectDetailsController = MockProjectDetailsController()
        OneFlow.shared.projectDetailsController = projectDetailsController
        OneFlow.logUser("abc", userDetails: params)
        guard let receivedParams = projectDetailsController.newUserData else {
            XCTFail("Event manager should receive parameter")
            return
        }
        if let _ = receivedParams["SomeObject"] {
            XCTFail("Parameter should remove SomeObject in final params")
        }
    }

    func testOneFlowConfigure_shouldCall_eventManagerConfigure() {
        let expectation = XCTestExpectation()
        projectDetailsControler.appKey = nil
        let eventManager = MockEventManager(expectation)
        OneFlow.shared.eventManager = eventManager
        apiController.dataToRespond = MockResponseProvider.getDataForAddUserResponse()
        OneFlow.configure("abc")
        OneFlow.shared.reachabilityChanged(note: Notification(name: Notification.Name.init(rawValue: ""), object: OneFlow.shared.reachability, userInfo: nil))
        self.wait(for: [expectation], timeout: 2.0)
    }

    func testOneFlowConfigure_shouldNotCall_eventManagerConfigure_ifAddUserFail() {
        let expectation = XCTestExpectation()
        expectation.isInverted = true
        projectDetailsControler.appKey = nil
        let eventManager = MockEventManager(expectation)
        OneFlow.shared.eventManager = eventManager
        OneFlow.shared.reachabilityChanged(note: Notification(name: Notification.Name.init(rawValue: ""), object: OneFlow.shared.reachability, userInfo: nil))
        self.wait(for: [expectation], timeout: 2.0)
    }
}

//
//  BackgroundLaunchGateTests.swift
//  diskindexTests
//
//  Aufgabe 154 — zweite Instanz mit --background beendet sich.
//

import Testing
@testable import diskindex

struct BackgroundLaunchGateTests {
    @Test func exitsOnlyWhenBackgroundAndAnotherProcess() {
        #expect(BackgroundLaunchGate.shouldExitImmediately(arguments: ["--background"], runningPIDs: [10, 20], ownPID: 10))
        #expect(!BackgroundLaunchGate.shouldExitImmediately(arguments: ["--background"], runningPIDs: [10], ownPID: 10))
        #expect(!BackgroundLaunchGate.shouldExitImmediately(arguments: [], runningPIDs: [10, 20], ownPID: 10))
    }
}

//
//  RuntimeEnvironment.swift
//  DiskArchive
//

import Foundation

/// Eine Stelle für „läuft die App als Testhost?“ (AppDelegate, DiskArchiveLog, MediumCoordinator).
nonisolated enum RuntimeEnvironment {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestSessionIdentifier"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["XCTestInjectionFrameworkPath"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }
}

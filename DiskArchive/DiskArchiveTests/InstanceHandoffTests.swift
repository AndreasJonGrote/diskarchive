//
//  InstanceHandoffTests.swift
//  DiskArchiveTests
//

import Foundation
import Testing
@testable import DiskArchive

@MainActor
struct InstanceHandoffTests {
    private let own = InstanceHandoff.ProcessStamp(bundleID: "app.diskarchive", launchDate: Date(timeIntervalSince1970: 100))

    @Test func youngerSiblingQuits() {
        let quit = InstanceHandoff.shouldQuit(object: "42", ownPID: 7, own: own) { pid in
            #expect(pid == 42)
            return InstanceHandoff.ProcessStamp(bundleID: "app.diskarchive", launchDate: Date(timeIntervalSince1970: 200))
        }
        #expect(quit)
    }

    @Test func foreignOrOlderOrMissingIsIgnored() {
        #expect(!InstanceHandoff.shouldQuit(object: nil, ownPID: 7, own: own) { _ in nil })
        #expect(!InstanceHandoff.shouldQuit(object: "7", ownPID: 7, own: own) { _ in own })
        #expect(!InstanceHandoff.shouldQuit(object: "nope", ownPID: 7, own: own) { _ in own })
        #expect(!InstanceHandoff.shouldQuit(object: "42", ownPID: 7, own: own) { _ in nil })
        #expect(!InstanceHandoff.shouldQuit(object: "42", ownPID: 7, own: own) { _ in
            InstanceHandoff.ProcessStamp(bundleID: "other.app", launchDate: Date(timeIntervalSince1970: 200))
        })
        #expect(!InstanceHandoff.shouldQuit(object: "42", ownPID: 7, own: own) { _ in
            InstanceHandoff.ProcessStamp(bundleID: "app.diskarchive", launchDate: Date(timeIntervalSince1970: 50))
        })
    }

    @Test func loginNeverQuitsOlderEvenInDebug() {
        #expect(InstanceHandoff.conflictAction(launchKind: .login, isDebugBuild: true) == .handOffAndQuitSelf)
        #expect(InstanceHandoff.conflictAction(launchKind: .login, isDebugBuild: false) == .handOffAndQuitSelf)
    }

    @Test func debugClickQuitsOlder() {
        #expect(InstanceHandoff.conflictAction(launchKind: .click, isDebugBuild: true) == .quitOlderInstances)
        #expect(InstanceHandoff.conflictAction(launchKind: .click, isDebugBuild: false) == .handOffAndQuitSelf)
    }
}

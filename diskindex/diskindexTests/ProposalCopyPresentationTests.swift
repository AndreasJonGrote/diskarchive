//
//  ProposalCopyPresentationTests.swift
//  diskindexTests
//

import Testing
@testable import diskindex

struct ProposalCopyPresentationTests {
    @Test func highlightUsesProposalRed() {
        let saved = ProposalCopySettings.highlightProposalCopy
        defer { ProposalCopySettings.highlightProposalCopy = saved }
        ProposalCopySettings.highlightProposalCopy = true
        #expect(ProposalCopyPresentation.foregroundColor(base: nil) == ProposalCopyPresentation.proposalRed)
        ProposalCopySettings.highlightProposalCopy = false
        #expect(ProposalCopyPresentation.foregroundColor(base: nil) == nil)
        #expect(ProposalCopyPresentation.foregroundColor(base: DesignColor.favorite) == DesignColor.favorite)
    }
}

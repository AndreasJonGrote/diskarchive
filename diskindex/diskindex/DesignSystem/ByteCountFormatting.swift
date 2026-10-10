//
//  ByteCountFormatting.swift
//  diskindex
//

import Foundation

extension ByteCountFormatter {
    static let storage: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

//
//  FileTypeIcon.swift
//  DiskArchive
//
//  Phosphor Dateityp-Icons (README Screen 08).
//

import SwiftUI

enum FileKind: String, CaseIterable {
    case folder
    case document
    case pdf
    case image
    case video
    case audio
    case archive
    case code
    case spreadsheet
    case presentation
    case other

    var assetName: String {
        switch self {
        case .folder: "FileTypeFolder"
        case .document: "FileTypeText"
        case .pdf: "FileTypePDF"
        case .image: "FileTypeImage"
        case .video: "FileTypeVideo"
        case .audio: "FileTypeAudio"
        case .archive: "FileTypeZip"
        case .code: "FileTypeCode"
        case .spreadsheet: "FileTypeXls"
        case .presentation: "FileTypePpt"
        case .other: "FileTypeGeneric"
        }
    }

    init(fileName: String, isFolder: Bool, isPackage: Bool = false) {
        if isFolder, isPackage || fileName.lowercased().hasSuffix(".app") {
            self = .archive
            return
        }
        if isFolder {
            self = .folder
            return
        }
        let ext = (fileName as NSString).pathExtension.lowercased()
        // bug.0.4.2.001: Bild, Video und Audio aus derselben Liste wie der Filter.
        if SearchFileTypeFilter.imageExtensions.contains(ext) {
            self = .image
            return
        }
        if SearchFileTypeFilter.videoExtensions.contains(ext) {
            self = .video
            return
        }
        if SearchFileTypeFilter.audioExtensions.contains(ext) {
            self = .audio
            return
        }
        switch ext {
        case "pdf": self = .pdf
        case "txt", "md", "rtf", "doc", "docx", "pages", "odt": self = .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "dmg", "pkg": self = .archive
        case "py", "js", "ts", "jsx", "tsx", "html", "htm", "css", "json", "sh", "rb", "php", "swift", "sql", "command": self = .code
        case "xls", "xlsx", "csv", "numbers", "ods": self = .spreadsheet
        case "ppt", "pptx", "key", "odp": self = .presentation
        case "exe", "app": self = .archive
        default: self = .other
        }
    }
}

struct FileTypeIcon: View {
    var kind: FileKind
    var size: CGFloat = 15
    var color: Color = DesignColor.text

    var body: some View {
        Image(kind.assetName)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}

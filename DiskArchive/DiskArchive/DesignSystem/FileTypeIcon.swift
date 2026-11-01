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
        switch (fileName as NSString).pathExtension.lowercased() {
        case "pdf": self = .pdf
        case "txt", "md", "rtf", "doc", "docx", "pages", "odt": self = .document
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "tif", "tiff", "svg", "nef", "cr2", "arw", "dng": self = .image
        case "mov", "mp4", "m4v", "avi", "mkv": self = .video
        case "mp3", "wav", "aac", "m4a", "flac": self = .audio
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

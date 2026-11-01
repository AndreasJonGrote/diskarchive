//
//  PreviewData.swift
//  DiskArchive
//
//  Nur Xcode-Vorschauen. Die laufende App lädt Medien aus dem Speicher.
//

#if DEBUG
import Foundation

enum PreviewData {
    static let media: [Medium] = [
        Medium(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!,
            name: "Backup SSD",
            type: .ssd,
            connectionStatus: .connected,
            indexStatus: .indexing,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 4_100_000_000_000,
            capacityUsedBytes: 3_770_000_000_000,
            fileCount: 238_421,
            folderCount: 12_400,
            lastSeenAt: Date(),
            firstIndexedAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()),
            lastIndexedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            isForgotten: false,
            indexingProgress: 0.67
        ),
        Medium(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000002")!,
            name: "Archiv 2019–2021",
            type: .hdd,
            connectionStatus: .connected,
            indexStatus: .indexed,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 2_000_000_000_000,
            capacityUsedBytes: 700_000_000_000,
            fileCount: 89_102,
            folderCount: 4_200,
            lastSeenAt: Date(),
            firstIndexedAt: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
            lastIndexedAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()),
            isForgotten: false,
            indexingProgress: 1,
            isFavorite: true
        ),
        Medium(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000006")!,
            name: "Neues Medium",
            type: .usb,
            connectionStatus: .connected,
            indexStatus: .pending,
            allowIndexing: true,
            autoIndexPaused: false,
            capacityTotalBytes: 64_000_000_000,
            capacityUsedBytes: 0,
            fileCount: 0,
            folderCount: 0,
            lastSeenAt: Date(),
            firstIndexedAt: nil,
            lastIndexedAt: nil,
            isForgotten: false,
            indexingProgress: 0
        ),
    ]
}
#endif

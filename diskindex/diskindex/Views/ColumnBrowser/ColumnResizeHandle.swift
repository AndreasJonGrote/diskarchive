//
//  ColumnResizeHandle.swift
//  diskindex
//

import SwiftUI

struct ColumnResizeHandle: View {
    @Binding var committedWidth: CGFloat
    var onPreviewWidthChange: (CGFloat?) -> Void

    var minWidth: CGFloat = 160
    var maxWidth: CGFloat = 420

    @State private var widthAtDragStart: CGFloat?
    @GestureState private var dragTranslation: CGFloat = 0

    private var previewWidth: CGFloat? {
        guard widthAtDragStart != nil || dragTranslation != 0 else { return nil }
        let start = widthAtDragStart ?? committedWidth
        return min(max(minWidth, start + dragTranslation), maxWidth)
    }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .columnResizePointerStyle()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onChanged { _ in
                        if widthAtDragStart == nil {
                            widthAtDragStart = committedWidth
                        }
                    }
                    .onEnded { value in
                        let start = widthAtDragStart ?? committedWidth
                        let next = min(max(minWidth, start + value.translation.width), maxWidth)
                        committedWidth = next
                        widthAtDragStart = nil
                        onPreviewWidthChange(nil)
                    }
            )
            .onChange(of: dragTranslation) { _, _ in
                reportPreview(previewWidth)
            }
    }

    @State private var lastReportedPreview: CGFloat?

    private func reportPreview(_ width: CGFloat?) {
        guard width != lastReportedPreview else { return }
        lastReportedPreview = width
        onPreviewWidthChange(width)
    }
}

#if DEBUG
//
//  IndexDiagnosticsView.swift
//  diskindex
//
//  Aufgabe 35: Systemcontrols, kein Design-System.
//

import SwiftUI

struct IndexDiagnosticsView: View {
    @State private var model = IndexDiagnosticsModel()

    var body: some View {
        IndexDiagnosticsViewContent(model: model)
    }
}

private struct IndexDiagnosticsViewContent: View {
    @Bindable var model: IndexDiagnosticsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.string("diagnostics.title"))
                    .font(.title2)
                Text("Sandbox aus: Xcode → Target diskindex → Signing & Capabilities → „App Sandbox“ entfernen → neu starten → Abschnitt B erneut. Danach die Sandbox wieder einschalten. Dialog zurücksetzen: tccutil reset SystemPolicyRemovableVolumes xjonx.diskindex")
                    .font(.callout)
                    .textSelection(.enabled)

                GroupBox(L10n.string("diagnostics.section.volumes")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auswerfen erscheint erst, wenn ein Medium ausgeworfen wird: willUnmount, didUnmount und DiskArbitration „verschwunden“ mit Zeitstempel und Pfad.")
                            .font(.callout)
                            .textSelection(.enabled)
                        HStack {
                            Button(L10n.string("diagnostics.volumes.reread")) { model.refreshMounted(logNotes: true) }
                            Button(L10n.string("diagnostics.report.copy")) { model.copyReport() }
                        }
                        List(model.volumes, selection: $model.selectedID) { row in
                            Text(row.line)
                                .font(.system(size: 11, design: .monospaced))
                                .tag(Optional(row.id))
                        }
                        .frame(minHeight: 140, maxHeight: 180)
                        logEditor(text: model.logA)
                    }
                    .padding(8)
                }

                GroupBox(L10n.string("diagnostics.section.access")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(L10n.string("diagnostics.root.read")) { model.probeAccess() }
                            .disabled(model.probing || model.selectedPath == nil)
                        TextField("Systemdialog erschienen: ja/nein/wann", text: $model.systemDialogNote)
                            .onChange(of: model.systemDialogNote) { _, _ in
                                model.storeDialogNote()
                            }
                        logEditor(text: model.logB)
                    }
                    .padding(8)
                }

                GroupBox(L10n.string("diagnostics.section.scan")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Stepper("Ebene \(model.scanDepth)", value: $model.scanDepth, in: 1...5)
                            if model.scanning {
                                Button(L10n.string("diagnostics.cancel")) { model.cancelScan() }
                            } else {
                                Button(L10n.string("diagnostics.scan.start")) { model.startScan() }
                                    .disabled(model.selectedPath == nil)
                            }
                        }
                        logEditor(text: model.logC)
                    }
                    .padding(8)
                }

                GroupBox(L10n.string("diagnostics.section.fsevents")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Strom starten. Im Finder eine Datei anlegen, umbenennen, löschen. Strom stoppen, Medium auswerfen, wieder anstecken, Strom mit gespeicherter ID starten. Optional: Medium an einem anderen Rechner ändern (Datei anlegen), dann prüfen, ob das Nachspielen sie zeigt (erwartet: nein).")
                            .font(.callout)
                            .textSelection(.enabled)
                        Button(model.watching ? L10n.string("diagnostics.fsevents.stop") : L10n.string("diagnostics.fsevents.start")) {
                            model.toggleFSEvents()
                        }
                        .disabled(!model.watching && model.selectedPath == nil)
                        logEditor(text: model.logD)
                    }
                    .padding(8)
                }

                GroupBox(L10n.string("diagnostics.section.sqlite")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(L10n.string("diagnostics.rows"), selection: $model.sqliteRowCount) {
                            Text("100 000").tag(100_000)
                            Text("1 000 000").tag(1_000_000)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                        Button(L10n.string("diagnostics.sqlite.measure")) { model.measureSQLite() }
                            .disabled(model.measuring)
                        logEditor(text: model.logE)
                    }
                    .padding(8)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func logEditor(text: String) -> some View {
        TextEditor(text: Binding(get: { text.isEmpty ? "" : text }, set: { _ in }))
            .font(.system(size: 11, design: .monospaced))
            .frame(minHeight: 120, maxHeight: 180)
    }
}
#endif

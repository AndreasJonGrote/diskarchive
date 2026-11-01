//
//  MeasurementTestGroup.swift
//  DiskArchiveTests
//
//  bug.0.3.9.004 c — Mess- und Datenmengen-Suites (50.000 Zeilen, 600 Treffer, Laufzeitgrenzen) laufen nacheinander
//  unter einer Elternsuite, damit sie sich im Parallellauf nicht gegenseitig ausbremsen. Fenster-Messtests liegen in
//  `WindowTestGroup`.
//

import Testing

@Suite(.serialized) @MainActor
enum MeasurementTestGroup {}

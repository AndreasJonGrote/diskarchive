//
//  LiveRenamePairs.swift
//  diskindex
//
//  FSEvents Item-Paare alt→neu im Quiet-Fenster (235b).
//

import Foundation

nonisolated struct ItemPathEvent: Sendable, Equatable {
  var path: String
  var itemCreated: Bool
  var itemRemoved: Bool
  var itemRenamed: Bool

  var hasItemFlag: Bool { itemCreated || itemRemoved || itemRenamed }
}

nonisolated struct LiveRenamePair: Sendable, Equatable {
  var fromPath: String
  var toPath: String
}

nonisolated enum LiveRenamePairs {
  /// Bildet 1:1-Paare (Pfad existiert nicht → alt, existiert → neu). Mehrdeutig → leer für diese Pfade.
  static func pair(
    events: [ItemPathEvent],
    fileExists: (String) -> Bool
  ) -> [LiveRenamePair] {
    var byPath: [String: ItemPathEvent] = [:]
    for event in events where event.hasItemFlag {
      let std = URL(fileURLWithPath: event.path).standardizedFileURL.path
      byPath[std] = event
    }
    guard byPath.count == 2 else { return [] }

    var gone: [String] = []
    var present: [String] = []
    for path in byPath.keys.sorted() {
      if fileExists(path) {
        present.append(path)
      } else {
        gone.append(path)
      }
    }
    guard gone.count == 1, present.count == 1 else { return [] }
    let from = gone[0]
    let to = present[0]
    let fromEvent = byPath[from]
    let toEvent = byPath[to]
    let fromSignals = fromEvent?.itemRemoved == true || fromEvent?.itemRenamed == true
    let toSignals = toEvent?.itemCreated == true || toEvent?.itemRenamed == true
    guard fromSignals, toSignals else { return [] }
    return [LiveRenamePair(fromPath: from, toPath: to)]
  }
}

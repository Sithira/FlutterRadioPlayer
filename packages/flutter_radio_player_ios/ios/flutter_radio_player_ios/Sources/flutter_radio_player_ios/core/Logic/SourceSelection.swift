struct SourceSelection: Sendable, Equatable {
    let index: Int?
    let keepStream: Bool
}

/// `setSources` selection rules 1-3.
func selectSource<T>(
    old: [T],
    oldIndex: Int?,
    new: [T],
    initialIndex: Int?,
    id: (T) -> String,
    sameStream: (T, T) -> Bool
) -> SourceSelection {
    if new.isEmpty { return SourceSelection(index: nil, keepStream: false) }
    let previous = oldIndex.flatMap { old.indices.contains($0) ? old[$0] : nil }
    let index = initialIndex ?? followCurrent(previous, oldIndex: oldIndex, new: new, id: id)
    let keep = previous.map { sameStream($0, new[index]) } ?? false
    return SourceSelection(index: index, keepStream: keep)
}

private func followCurrent<T>(_ previous: T?, oldIndex: Int?, new: [T], id: (T) -> String) -> Int {
    guard let previous, let oldIndex else { return 0 }
    let previousId = id(previous)
    if oldIndex < new.count && id(new[oldIndex]) == previousId { return oldIndex }
    return new.firstIndex { id($0) == previousId } ?? 0
}

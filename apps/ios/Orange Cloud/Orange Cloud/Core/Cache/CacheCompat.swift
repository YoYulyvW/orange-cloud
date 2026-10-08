//
//  CacheCompat.swift
//  Orange Cloud
//
//  iOS 16.4 移植：替代 SwiftData 的 ModelContext / FetchDescriptor / @Query / modelContainer。
//

import Foundation
import SwiftUI
import Perception

// MARK: - SortDescriptor

struct SortDescriptor<T> {
    let compare: (T, T) -> Bool
    init<V: Comparable>(_ keyPath: KeyPath<T, V>) {
        compare = { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }
}

// MARK: - ModelContext

final class ModelContext {
    init() {}
    init(_ container: Any?) {}

    func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        let store = CacheStore.shared
        var all: [T] = []
        if T.self == CachedZone.self {
            all = store.allZones as! [T]
        } else if T.self == CachedWorkerScript.self {
            all = store.allWorkers as! [T]
        } else if T.self == CachedDNSRecord.self {
            all = store.allRecords as! [T]
        }
        if let p = descriptor.predicate { all = all.filter(p) }
        return all
    }

    func insert<T>(_ model: T) {
        let store = CacheStore.shared
        if let z = model as? CachedZone { store.upsertZone(z) }
        else if let w = model as? CachedWorkerScript { store.upsertWorker(w) }
        else if let r = model as? CachedDNSRecord { store.upsertRecord(r) }
    }

    func delete<T>(_ model: T) {
        let store = CacheStore.shared
        if let z = model as? CachedZone { store.removeZone(id: z.id) }
        else if let w = model as? CachedWorkerScript { store.removeWorker(accountId: w.accountId, id: w.id) }
        else if let r = model as? CachedDNSRecord { store.removeRecord(id: r.id) }
    }

    func save() throws { CacheStore.shared.persist() }
}

// MARK: - FetchDescriptor

struct FetchDescriptor<T> {
    var predicate: ((T) -> Bool)?
    init(predicate: ((T) -> Bool)? = nil) {
        self.predicate = predicate
    }
}

// MARK: - modelContext 环境

private struct ModelContextKey: EnvironmentKey {
    static let defaultValue = ModelContext()
}

extension EnvironmentValues {
    var modelContext: ModelContext {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }
}

extension View {
    func modelContainer(_ any: Any?) -> some View { self }
}

// MARK: - Query（替代 SwiftData @Query）

@propertyWrapper
struct Query<T> {
    private let filter: ((T) -> Bool)?
    private let comparators: [(T, T) -> Bool]

    init() {
        self.filter = nil
        self.comparators = []
    }

    init(filter: ((T) -> Bool)? = nil) {
        self.filter = filter
        self.comparators = []
    }

    init<V: Comparable>(filter: ((T) -> Bool)? = nil, sort: KeyPath<T, V>) {
        self.filter = filter
        self.comparators = [{ $0[keyPath: sort] < $1[keyPath: sort] }]
    }

    init(filter: ((T) -> Bool)? = nil, sort: [SortDescriptor<T>]) {
        self.filter = filter
        self.comparators = sort.map { $0.compare }
    }

    var wrappedValue: [T] {
        let store = CacheStore.shared
        var all: [T] = []
        if T.self == CachedZone.self {
            all = store.allZones as! [T]
        } else if T.self == CachedWorkerScript.self {
            all = store.allWorkers as! [T]
        } else if T.self == CachedDNSRecord.self {
            all = store.allRecords as! [T]
        }
        if let f = filter { all = all.filter(f) }
        if !comparators.isEmpty {
            all = all.sorted { a, b in
                for cmp in comparators {
                    if cmp(a, b) { return true }
                    if cmp(b, a) { return false }
                }
                return false
            }
        }
        return all
    }
}

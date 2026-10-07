//
//  CacheCompat.swift
//  Orange Cloud
//
//  iOS 16.4 移植：替代 SwiftData 的 ModelContext / FetchDescriptor / @Query / modelContainer。
//  缓存是可随时从 API 重拉的次要数据，用 CacheStore（内存 + JSON）承载。
//

import Foundation
import SwiftUI
import Perception

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
        if let s = descriptor.sortBy { all = all.sorted(by: s) }
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
    var sortBy: ((T, T) -> Bool)?
    init(predicate: ((T) -> Bool)? = nil, sortBy: ((T, T) -> Bool)? = nil) {
        self.predicate = predicate
        self.sortBy = sortBy
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
    private let sort: ((T, T) -> Bool)?

    init(filter: ((T) -> Bool)? = nil, sort: ((T, T) -> Bool)? = nil) {
        self.filter = filter
        self.sort = sort
    }

    @MainActor
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
        if let s = sort { all = all.sorted(by: s) }
        return all
    }
}

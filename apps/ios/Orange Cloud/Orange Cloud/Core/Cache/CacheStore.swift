//
//  CacheStore.swift
//  Orange Cloud
//
//  iOS 16.4 移植：替代 SwiftData 的 ModelContainer/ModelContext/@Query。
//  缓存是可随时从 API 重拉的非关键数据，用内存数组 + JSON 落盘即可。
//  通过 @Perceptible 让视图自动刷新（等价 @Query 的响应式）。
//

import Foundation
import Perception

@Perceptible
final class CacheStore {
    static let shared = CacheStore()

    private(set) var zones: [CachedZone] = []
    private(set) var workers: [CachedWorkerScript] = []
    private(set) var records: [CachedDNSRecord] = []

    var allZones: [CachedZone] { zones }
    var allWorkers: [CachedWorkerScript] { workers }
    var allRecords: [CachedDNSRecord] { records }

    /// 数据版本号：任何写操作后自增，供 Query 缓存失效判断。
    private(set) var revision = 0
    func bumpRevision() { revision &+= 1 }

    private let queue = DispatchQueue(label: "oc.cache.store")
    private var loaded = false

    private init() { load() }

    // MARK: - 落盘

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("oc-cache.json")
    }

    private struct Snapshot: Codable {
        var zones: [CachedZone]
        var workers: [CachedWorkerScript]
        var records: [CachedDNSRecord]
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: Self.fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        zones = snap.zones
        workers = snap.workers
        records = snap.records
    }

    func persist() {
        let snap = Snapshot(zones: zones, workers: workers, records: records)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - 读

    func zones(accountId: String) -> [CachedZone] {
        zones.filter { $0.accountId == accountId }
    }
    func zone(id: String) -> CachedZone? { zones.first { $0.id == id } }

    func workers(accountId: String) -> [CachedWorkerScript] {
        workers.filter { $0.accountId == accountId }
    }
    func worker(accountId: String, id: String) -> CachedWorkerScript? {
        workers.first { $0.accountId == accountId && $0.id == id }
    }

    func records(zoneId: String) -> [CachedDNSRecord] {
        records.filter { $0.zoneId == zoneId }
    }
    func record(id: String) -> CachedDNSRecord? { records.first { $0.id == id } }

    // MARK: - 写

    func upsertZone(_ z: CachedZone) {
        if let i = zones.firstIndex(where: { $0.id == z.id }) { zones[i] = z } else { zones.append(z) }
        bumpRevision()
    }
    func removeZone(id: String) { zones.removeAll { $0.id == id }; bumpRevision() }

    func upsertWorker(_ w: CachedWorkerScript) {
        if let i = workers.firstIndex(where: { $0.accountId == w.accountId && $0.id == w.id }) { workers[i] = w } else { workers.append(w) }
        bumpRevision()
    }
    func removeWorker(accountId: String, id: String) { workers.removeAll { $0.accountId == accountId && $0.id == id }; bumpRevision() }

    func upsertRecord(_ r: CachedDNSRecord) {
        if let i = records.firstIndex(where: { $0.id == r.id }) { records[i] = r } else { records.append(r) }
        bumpRevision()
    }
    func removeRecord(id: String) { records.removeAll { $0.id == id }; bumpRevision() }

    func replaceZones(accountId: String, with new: [CachedZone]) {
        zones.removeAll { $0.accountId == accountId }
        zones.append(contentsOf: new)
        bumpRevision()
    }
    func replaceWorkers(accountId: String, with new: [CachedWorkerScript]) {
        workers.removeAll { $0.accountId == accountId }
        workers.append(contentsOf: new)
        bumpRevision()
    }
    func replaceRecords(zoneId: String, with new: [CachedDNSRecord]) {
        records.removeAll { $0.zoneId == zoneId }
        records.append(contentsOf: new)
        bumpRevision()
    }

    func removeAll(accountId: String) {
        zones.removeAll { $0.accountId == accountId }
        workers.removeAll { $0.accountId == accountId }
        bumpRevision()
    }
}

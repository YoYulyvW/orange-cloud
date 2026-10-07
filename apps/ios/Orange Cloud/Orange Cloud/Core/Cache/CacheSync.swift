//
//  CacheSync.swift
//  Orange Cloud
//
//  Zone / Worker 列表 → 缓存的共享同步逻辑。
//

import Foundation
import WidgetKit

@MainActor
enum CacheSync {

    static func syncZones(_ zones: [Zone], accountId: String, accountName: String, context: ModelContext) {
        let store = CacheStore.shared
        let fetchedIDs = Set(zones.map(\.id))
        // 删除远端已不存在的条目（仅当前账号范围）
        for cached in store.zones(accountId: accountId) where !fetchedIDs.contains(cached.id) {
            store.removeZone(id: cached.id)
        }
        for zone in zones {
            if let cached = store.zone(id: zone.id) {
                cached.update(from: zone)
            } else {
                store.upsertZone(CachedZone(from: zone, accountId: accountId))
            }
        }
        store.persist()

        WidgetSnapshot(
            accountId: accountId,
            accountName: accountName,
            totalZones: zones.count,
            activeZones: zones.filter { $0.status == "active" }.count,
            updatedAt: Date()
        ).save()
        WidgetCenter.shared.reloadTimelines(ofKind: "ZoneStatusWidget")
        SpotlightIndexer.indexZones(zones)
    }

    static func syncWorkers(_ scripts: [WorkerScript], accountId: String, context: ModelContext) {
        let store = CacheStore.shared
        let fetchedIDs = Set(scripts.map(\.id))
        for cached in store.workers(accountId: accountId) where !fetchedIDs.contains(cached.id) {
            store.removeWorker(accountId: accountId, id: cached.id)
        }
        for script in scripts {
            if let cached = store.worker(accountId: accountId, id: script.id) {
                cached.update(from: script)
            } else {
                store.upsertWorker(CachedWorkerScript(from: script, accountId: accountId))
            }
        }
        store.persist()
    }
}

//
//  CachePolicy.swift
//  Orange Cloud
//
//  缓存有效期（stale-while-revalidate）。
//

import Foundation

@MainActor
enum CachePolicy {
    static let zones: TimeInterval = 10 * 60
    static let dns: TimeInterval = 10 * 60

    static func isFresh(_ date: Date?, ttl: TimeInterval) -> Bool {
        guard let date else { return false }
        let age = Date().timeIntervalSince(date)
        return age >= 0 && age < ttl
    }

    static func zonesFresh(accountId: String, context: ModelContext) -> Bool {
        let cached = CacheStore.shared.zones(accountId: accountId)
        guard !cached.isEmpty else { return false }
        return isFresh(cached.map(\.updatedAt).max(), ttl: zones)
    }

    static func dnsFresh(zoneId: String, context: ModelContext) -> Bool {
        let cached = CacheStore.shared.records(zoneId: zoneId)
        guard !cached.isEmpty else { return false }
        return isFresh(cached.map(\.updatedAt).max(), ttl: dns)
    }
}

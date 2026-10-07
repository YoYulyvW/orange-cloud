//
//  CacheModels.swift
//  Orange Cloud
//
//  本地缓存模型（iOS 16.4 移植）：原用 SwiftData @Model，改用普通可序列化类 + CacheStore。
//  唯一性由各 upsert 路径在代码层保证。
//

import Foundation

/// 域名缓存
final class CachedZone: Codable, Identifiable, Hashable, Equatable {
    var id: String
    var name: String
    var status: String
    var planName: String
    var nameServers: [String]
    var accountId: String
    var updatedAt: Date
    var pinned: Bool = false
    var dnsRecordCount: Int?
    var paused: Bool = false

    init(from zone: Zone, accountId: String) {
        self.id          = zone.id
        self.name        = zone.name
        self.status      = zone.status
        self.planName    = zone.plan?.name ?? "—"
        self.nameServers = zone.nameServers ?? []
        self.accountId   = accountId
        self.updatedAt   = Date()
        self.paused      = zone.paused ?? false
    }

    func update(from zone: Zone) {
        name        = zone.name
        status      = zone.status
        planName    = zone.plan?.name ?? "—"
        nameServers = zone.nameServers ?? []
        paused      = zone.paused ?? false
        updatedAt   = Date()
    }

    var displayStatus: String { paused ? "paused" : status }

    static func == (lhs: CachedZone, rhs: CachedZone) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Worker 脚本缓存
final class CachedWorkerScript: Codable, Identifiable, Hashable, Equatable {
    var key: String
    var id: String
    var accountId: String
    var createdOn: String?
    var modifiedOn: String?
    var usageModel: String?
    var handlers: [String]
    var logpush: Bool
    var updatedAt: Date

    init(from script: WorkerScript, accountId: String) {
        self.key        = "\(accountId)/\(script.id)"
        self.id         = script.id
        self.accountId  = accountId
        self.createdOn  = script.createdOn
        self.modifiedOn = script.modifiedOn
        self.usageModel = script.usageModel
        self.handlers   = script.handlers ?? []
        self.logpush    = script.logpush ?? false
        self.updatedAt  = Date()
    }

    func update(from script: WorkerScript) {
        createdOn  = script.createdOn
        modifiedOn = script.modifiedOn
        usageModel = script.usageModel
        handlers   = script.handlers ?? []
        logpush    = script.logpush ?? false
        updatedAt  = Date()
    }

    static func == (lhs: CachedWorkerScript, rhs: CachedWorkerScript) -> Bool { lhs.id == rhs.id && lhs.accountId == rhs.accountId }
    func hash(into hasher: inout Hasher) { hasher.combine(key) }
}

/// DNS 记录缓存
final class CachedDNSRecord: Codable, Identifiable, Hashable, Equatable {
    var id: String
    var type: String
    var name: String
    var content: String
    var proxied: Bool
    var ttl: Int
    var priority: Int?
    var comment: String?
    var zoneId: String
    var updatedAt: Date
    var isShadowed: Bool = false
    var shadowedRecordsCount: Int = 0

    init(from record: DNSRecord, zoneId: String) {
        self.id        = record.id
        self.type      = record.type
        self.name      = record.name
        self.content   = record.content
        self.proxied   = record.isProxied
        self.ttl       = record.ttl
        self.priority  = record.priority
        self.comment   = record.comment
        self.zoneId    = zoneId
        self.updatedAt = Date()
        self.isShadowed = record.isShadowed
        self.shadowedRecordsCount = record.shadowedRecordsCount
    }

    func update(from record: DNSRecord, includesShadowMetadata: Bool = false) {
        type      = record.type
        name      = record.name
        content   = record.content
        proxied   = record.isProxied
        ttl       = record.ttl
        priority  = record.priority
        comment   = record.comment
        updatedAt = Date()
        if includesShadowMetadata {
            isShadowed = record.isShadowed
            shadowedRecordsCount = record.shadowedRecordsCount
        }
    }

    static func == (lhs: CachedDNSRecord, rhs: CachedDNSRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

//
//  SafeCache.swift
//  Orange Cloud
//
//  iOS 16.4 移植：原为 SwiftData 的 ObjC 异常收口，现改为 CacheStore 的透传封装。
//  CacheStore 是内存数组 + JSON，不会抛 NSException，这里只保留 API 形状。
//

import Foundation

@MainActor
enum SafeCache {

    /// 兼容旧调用：从 CacheStore 读取。
    static func fetch<T>(
        _ descriptor: FetchDescriptor<T>, context: ModelContext
    ) -> [T]? {
        return try? context.fetch(descriptor)
    }

    @discardableResult
    static func perform(_ label: String, _ body: () throws -> Void) -> Bool {
        do { try body() } catch {
            AppLog.app.info("缓存操作失败（已忽略，\(label)）：\(error.localizedDescription)")
            return false
        }
        return true
    }

    /// 容器健康探针：CacheStore 恒可用。
    static func probe(_ container: Any?) -> Bool { true }
}

//
//  CacheContainer.swift
//  Orange Cloud
//
//  iOS 16.4 移植：原为 SwiftData 容器管理，现由 CacheStore 单例承担，保留 API 形状。
//

import Foundation

enum CacheContainer {
    static var shared: Any? { nil }
    static func warmUp() { _ = CacheStore.shared }
    static func repairIfNeeded() {}
}

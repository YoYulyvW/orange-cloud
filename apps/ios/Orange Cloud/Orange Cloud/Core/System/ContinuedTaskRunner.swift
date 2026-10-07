//
//  ContinuedTaskRunner.swift
//  Orange Cloud
//
//  iOS 26 BGContinuedProcessingTask 封装。
//  iOS 16.4 移植：Xcode 16.4 的 SDK 无此符号，整体降级为空实现（调用方回退前台执行）。
//

import Foundation

nonisolated enum ContinuedTaskRunner {
    struct SubmitFailed: Error {}
    typealias ProgressCallback = @Sendable (Double) -> Void
    typealias Operation = @Sendable (
        _ progress: @escaping ProgressCallback,
        _ isCancelled: @escaping @Sendable () -> Bool
    ) async throws -> Void

    static func register() {}
    static func run(title: String, subtitle: String, operation: @escaping Operation) async throws {
        throw SubmitFailed()
    }
}

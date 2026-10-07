//
//  OnDeviceAI.swift
//  Orange Cloud
//
//  设备端模型（Foundation Models，iOS 26+）的共享门面。
//  iOS 16.4 移植：FoundationModels 仅在 iOS 26 SDK 存在，用 canImport 隔离，老 SDK 整体降级。
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 共享门面

nonisolated enum OnDeviceAI {

    /// 设备端模型此刻是否真的可用——所有 AI 入口的唯一判据。
    static var isReady: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    #if canImport(FoundationModels)
    /// 把框架的生成错误翻成给用户看的本地化文案。
    @available(iOS 26.0, *)
    static func friendlyMessage(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .guardrailViolation:
            return String(localized: "这条描述被安全过滤拦下了，换个说法再试。")
        case .unsupportedLanguageOrLocale:
            return String(localized: "当前语言暂不被设备端模型支持，可改用英文描述。")
        case .exceededContextWindowSize:
            return String(localized: "描述太长了，精简后再试。")
        case .assetsUnavailable, .rateLimited:
            return String(localized: "设备端模型暂时不可用，请稍后再试。")
        default:
            return String(localized: "没能生成结果，换个说法再试试。")
        }
    }
    #endif
}

// MARK: - 共享错误

nonisolated enum OnDeviceAIError: LocalizedError {
    case unsupported
    case emptyResult
    case generation(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:       String(localized: "此设备不支持设备端 AI（需要 iOS 26 及支持 Apple 智能的机型）。")
        case .emptyResult:       String(localized: "没能理解这条描述，换个说法再试试。")
        case .generation(let m): m
        }
    }
}

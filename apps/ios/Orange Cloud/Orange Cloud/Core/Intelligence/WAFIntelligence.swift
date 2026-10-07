//
//  WAFIntelligence.swift
//  Orange Cloud
//
//  设备端模型（Foundation Models，iOS 26+）辅助 WAF 自定义规则。
//  iOS 16.4 移植：FoundationModels 仅在 iOS 26 SDK 存在，整块 AI 逻辑用 canImport 隔离。
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 对外纯数据类型（不依赖 FoundationModels）

/// 渲染完成的规则草稿
nonisolated struct GeneratedWAFRule: Sendable {
    let expression: String
    let action: WAFRuleAction
    let summary: String
}

nonisolated enum WAFAssistantError: LocalizedError {
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

// MARK: - 门面（非门控；FoundationModels 调用都包在 canImport 内）

nonisolated enum WAFAssistant {

    /// 设备端模型此刻是否真的可用
    static var isReady: Bool { OnDeviceAI.isReady }

    static func generateRule(from naturalLanguage: String, locale: Locale = .current) async throws -> GeneratedWAFRule {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { throw WAFAssistantError.unsupported }
        let language = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        let session = LanguageModelSession(instructions: """
            You translate a natural-language description of a web-traffic firewall rule into a \
            structured rule for Cloudflare WAF. Use only the fields and comparators offered by the \
            schema; never invent fields. Guidance:
            • Country values use ISO 3166-1 alpha-2 codes (e.g. CN, US, JP).
            • URL paths keep their leading slash (e.g. /admin).
            • HTTP methods are upper-case (GET, POST, …).
            • For "is one of", put the items in the value separated by commas.
            • Pick the action that best matches the intent; use block when unsure.
            • Write "summary" as one short sentence in the user's language (\(language)).
            """)
        let draft: WAFRuleDraftAI
        do {
            draft = try await session.respond(
                to: naturalLanguage,
                generating: WAFRuleDraftAI.self,
                options: GenerationOptions(temperature: 0.1)
            ).content
        } catch let error as LanguageModelSession.GenerationError {
            throw WAFAssistantError.generation(OnDeviceAI.friendlyMessage(for: error))
        }
        let rule = draft.render()
        guard !rule.expression.isEmpty else { throw WAFAssistantError.emptyResult }
        return rule
        #else
        throw WAFAssistantError.unsupported
        #endif
    }

    static func explainRule(expression: String, action: String?, locale: Locale = .current) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { throw WAFAssistantError.unsupported }
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WAFAssistantError.emptyResult }
        let language = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        let session = LanguageModelSession(instructions: """
            You explain Cloudflare WAF custom-rule expressions to non-experts. Given an expression \
            and its action, describe in plain words which requests it matches and what happens to \
            them. One or two short sentences, no code, no raw field names. Answer in the user's \
            language (\(language)).
            """)
        let text: String
        do {
            text = try await session.respond(
                to: "Action: \(action ?? "block")\nExpression: \(trimmed)",
                options: GenerationOptions(temperature: 0.3)
            ).content
        } catch let error as LanguageModelSession.GenerationError {
            throw WAFAssistantError.generation(OnDeviceAI.friendlyMessage(for: error))
        }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw WAFAssistantError.emptyResult }
        return cleaned
        #else
        throw WAFAssistantError.unsupported
        #endif
    }
}

// MARK: - 值类型与字面量渲染（非门控）

nonisolated enum WAFValueKind {
    case string, number, ip

    nonisolated func literal(for raw: String) -> String {
        switch self {
        case .string: "\(WAFValueKind.escape(raw))"
        case .number: WAFValueKind.numeric(raw)
        case .ip:     raw
        }
    }

    private nonisolated static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private nonisolated static func numeric(_ s: String) -> String {
        let filtered = s.filter { $0.isNumber || $0 == "-" || $0 == "." }
        return filtered.isEmpty ? "0" : filtered
    }
}

// MARK: - 提交前结构 lint

nonisolated enum WAFExpressionLint {
    nonisolated static func problem(in expression: String) -> String? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(localized: "表达式不能为空") }

        var inString = false
        var escaped = false
        var depth = 0
        for ch in trimmed {
            if escaped { escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }
            if ch == "(" { depth += 1 }
            if ch == ")" {
                depth -= 1
                if depth < 0 { return String(localized: "括号不匹配") }
            }
        }
        if inString { return String(localized: "引号不匹配") }
        if depth != 0 { return String(localized: "括号不匹配") }
        return nil
    }
}

// MARK: - 结构化草稿（@Generable，iOS 26+）

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
nonisolated enum WAFFieldDraft {
    case clientIP
    case country
    case asNumber
    case hostname
    case uriPath
    case fullURI
    case queryString
    case httpMethod
    case userAgent
    case referer
    case threatScore
    case botScore

    nonisolated var cfToken: String {
        switch self {
        case .clientIP:    "ip.src"
        case .country:     "ip.geoip.country"
        case .asNumber:    "ip.geoip.asnum"
        case .hostname:    "http.host"
        case .uriPath:     "http.request.uri.path"
        case .fullURI:     "http.request.uri"
        case .queryString: "http.request.uri.query"
        case .httpMethod:  "http.request.method"
        case .userAgent:   "http.user_agent"
        case .referer:     "http.referer"
        case .threatScore: "cf.threat_score"
        case .botScore:    "cf.bot_management.score"
        }
    }

    nonisolated var valueKind: WAFValueKind {
        switch self {
        case .clientIP:                       .ip
        case .asNumber, .threatScore, .botScore: .number
        default:                              .string
        }
    }

    nonisolated func normalized(_ comparator: WAFComparatorDraft) -> WAFComparatorDraft {
        switch valueKind {
        case .string:
            return comparator
        case .number:
            switch comparator {
            case .contains, .matchesRegex: return .equals
            default:                       return comparator
            }
        case .ip:
            switch comparator {
            case .contains, .matchesRegex, .greaterThan, .lessThan: return .equals
            default:                                                return comparator
            }
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated enum WAFComparatorDraft {
    case equals
    case notEquals
    case contains
    case matchesRegex
    case greaterThan
    case lessThan
    case isOneOf

    nonisolated var cfToken: String {
        switch self {
        case .equals:       "eq"
        case .notEquals:    "ne"
        case .contains:     "contains"
        case .matchesRegex: "matches"
        case .greaterThan:  "gt"
        case .lessThan:     "lt"
        case .isOneOf:      "in"
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated enum WAFLogicDraft {
    case all
    case any
}

@available(iOS 26.0, *)
@Generable
nonisolated enum WAFActionDraft {
    case block
    case managedChallenge
    case jsChallenge
    case log

    nonisolated var ruleAction: WAFRuleAction {
        switch self {
        case .block:            .block
        case .managedChallenge: .managedChallenge
        case .jsChallenge:      .jsChallenge
        case .log:              .log
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated struct WAFConditionDraft {
    @Guide(description: "The request attribute to match against.")
    var field: WAFFieldDraft

    @Guide(description: "How to compare the field with the value.")
    var comparator: WAFComparatorDraft

    @Guide(description: "The value to compare against. Country uses an ISO 3166-1 alpha-2 code (CN, US). IP uses dotted form. For 'is one of', separate items with commas.")
    var value: String

    nonisolated var renderedExpression: String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let token = field.cfToken
        let kind = field.valueKind
        let comparator = field.normalized(comparator)

        switch comparator {
        case .isOneOf:
            let items = trimmed
                .split(whereSeparator: { $0 == "," || $0 == "\n" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !items.isEmpty else { return nil }
            let list = items.map { kind.literal(for: $0) }.joined(separator: " ")
            return "\(token) in {\(list)}"
        default:
            return "\(token) \(comparator.cfToken) \(kind.literal(for: trimmed))"
        }
    }
}

@available(iOS 26.0, *)
@Generable
nonisolated struct WAFRuleDraftAI {
    @Guide(description: "One or more conditions describing which requests to match.")
    var conditions: [WAFConditionDraft]

    @Guide(description: "Whether all conditions must match (all) or any one is enough (any).")
    var logic: WAFLogicDraft

    @Guide(description: "What Cloudflare should do with matching requests.")
    var action: WAFActionDraft

    @Guide(description: "One short sentence, in the user's language, plainly describing what this rule does.")
    var summary: String

    nonisolated func render() -> GeneratedWAFRule {
        let parts = conditions.compactMap(\.renderedExpression)
        let expression: String
        switch parts.count {
        case 0:  expression = ""
        case 1:  expression = parts[0]
        default:
            let joiner = logic == .all ? " and " : " or "
            expression = parts.map { "(\($0))" }.joined(separator: joiner)
        }
        return GeneratedWAFRule(
            expression: expression,
            action: action.ruleAction,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
#endif

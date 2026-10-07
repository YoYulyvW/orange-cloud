//
//  DNSIntelligence.swift
//  Orange Cloud
//
//  设备端模型（Foundation Models，iOS 26+）把一句大白话变成一条 DNS 记录草稿。
//  iOS 16.4 移植：FoundationModels 仅在 iOS 26 SDK 存在，用 canImport 隔离。
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 对外纯数据类型

nonisolated struct GeneratedDNSRecord: Sendable {
    let record:  CreateDNSRecord
    let summary: String
}

// MARK: - 门面

nonisolated enum DNSAssistant {

    static var isReady: Bool { OnDeviceAI.isReady }

    static func generateRecord(from naturalLanguage: String, locale: Locale = .current) async throws -> GeneratedDNSRecord {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { throw OnDeviceAIError.unsupported }
        let language = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        let session = LanguageModelSession(instructions: """
            You translate a natural-language request into a single Cloudflare DNS record. Use only the \
            record types offered by the schema; never invent fields. Guidance:
            • "name" is the subdomain label only (e.g. "blog", "www", "mail") or "@" for the root domain. \
              Do not include the zone/domain itself.
            • A records take a dotted IPv4 address; AAAA an IPv6 address; CNAME, MX and NS a hostname; \
              TXT the literal text content.
            • "proxied" only matters for A/AAAA/CNAME; default it to true unless the user clearly wants \
              DNS-only (unproxied).
            • "priority" applies to MX only (lower is higher priority, e.g. 10).
            • Write "summary" as one short sentence in the user's language (\(language)).
            """)
        let draft: DNSRecordDraftAI
        do {
            draft = try await session.respond(
                to: naturalLanguage,
                generating: DNSRecordDraftAI.self,
                options: GenerationOptions(temperature: 0.1)
            ).content
        } catch let error as LanguageModelSession.GenerationError {
            throw OnDeviceAIError.generation(OnDeviceAI.friendlyMessage(for: error))
        }
        guard let result = draft.render() else { throw OnDeviceAIError.emptyResult }
        return result
        #else
        throw OnDeviceAIError.unsupported
        #endif
    }
}

// MARK: - 结构化草稿（@Generable，iOS 26+）

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
nonisolated enum DNSTypeDraft {
    case a
    case aaaa
    case cname
    case txt
    case mx
    case ns

    nonisolated var token: String {
        switch self {
        case .a:     "A"
        case .aaaa:  "AAAA"
        case .cname: "CNAME"
        case .txt:   "TXT"
        case .mx:    "MX"
        case .ns:    "NS"
        }
    }

    nonisolated var supportsProxy: Bool {
        switch self {
        case .a, .aaaa, .cname: true
        default:                false
        }
    }

    nonisolated var isMX: Bool { self == .mx }
}

@available(iOS 26.0, *)
@Generable
nonisolated struct DNSRecordDraftAI {
    @Guide(description: "The DNS record type.")
    var type: DNSTypeDraft

    @Guide(description: "The record name: the subdomain label only (e.g. \"blog\", \"www\"), or \"@\" for the root domain. Never include the zone/domain itself.")
    var name: String

    @Guide(description: "The record value. A: dotted IPv4. AAAA: IPv6. CNAME/MX/NS: a hostname. TXT: the literal text.")
    var content: String

    @Guide(description: "Whether to route through Cloudflare's proxy (orange cloud). Only meaningful for A/AAAA/CNAME; true unless the user asks for DNS-only.")
    var proxied: Bool

    @Guide(description: "Mail server priority for MX records (lower is higher priority, e.g. 10). Use 10 when unsure; ignored for other types.")
    var priority: Int

    @Guide(description: "One short sentence, in the user's language, describing the record being created.")
    var summary: String

    nonisolated func render() -> GeneratedDNSRecord? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = CreateDNSRecord(
            type:     type.token,
            name:     trimmedName.isEmpty ? "@" : trimmedName,
            content:  trimmedContent,
            proxied:  type.supportsProxy && proxied,
            ttl:      1,
            priority: type.isMX ? max(0, min(priority, 65535)) : nil,
            comment:  nil
        )
        return GeneratedDNSRecord(
            record: record,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
#endif

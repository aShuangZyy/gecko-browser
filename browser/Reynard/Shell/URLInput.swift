//
//  URLInput.swift
//  GeckoBrowser / M1
//
//  地址栏输入归一化：完整 URL 原样、裸域名补 https、其余当搜索词。
//

import Foundation

enum URLInput {
    private static let knownSchemes = ["http://", "https://", "file://", "about:", "data:"]

    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "about:blank" }

        let lowercased = trimmed.lowercased()
        if knownSchemes.contains(where: { lowercased.hasPrefix($0) }) {
            return trimmed
        }

        if looksLikeHost(trimmed) {
            return "https://\(trimmed)"
        }

        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return "https://www.bing.com/search?q=\(query)"
    }

    /// 判断输入是否像一个主机名：无空格、含点或为 localhost、端口合法。
    static func looksLikeHost(_ text: String) -> Bool {
        if text.contains(" ") { return false }
        if text.hasPrefix(".") { return false }

        var hostPart = text
        if let colon = text.lastIndex(of: ":"), !text.hasSuffix("]") {
            let portPart = text[text.index(after: colon)...]
            guard let port = Int(portPart), (0...65535).contains(port), !portPart.isEmpty else {
                return false
            }
            hostPart = String(text[..<colon])
        }

        guard !hostPart.isEmpty else { return false }
        if hostPart.caseInsensitiveCompare("localhost") == .orderedSame { return true }
        return hostPart.contains(".")
    }
}

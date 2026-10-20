import SwiftUI
import UIKit

// MARK: - Lightweight Markdown

enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbers([String])
    case quote(String)
    case code(language: String?, code: String)
    case table([[String]])
    case divider
}

enum OZOMarkdownParser {
    static func parse(_ input: String) -> [MarkdownBlock] {
        let normalized = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard !normalized.isEmpty else { return [] }

        let lines = normalized.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let text = paragraph.joined(separator: "\n")
            paragraph.removeAll()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            blocks.append(.paragraph(text))
        }

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let info = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1

                while index < lines.count {
                    let candidate = lines[index]
                    if candidate.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        break
                    }
                    codeLines.append(candidate)
                    index += 1
                }
                if index < lines.count { index += 1 }

                blocks.append(
                    .code(
                        language: info.isEmpty ? nil : info,
                        code: codeLines.joined(separator: "\n")
                    )
                )
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            // Heading
            let hashCount = trimmed.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashCount) {
                let remainder = trimmed.dropFirst(hashCount)
                if remainder.first == " " {
                    let title = remainder.dropFirst().trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        flushParagraph()
                        blocks.append(.heading(level: hashCount, text: title))
                        index += 1
                        continue
                    }
                }
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.divider)
                index += 1
                continue
            }

            // Table
            if trimmed.hasPrefix("|"), trimmed.hasSuffix("|") {
                var gathered: [[String]] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix("|"), candidate.hasSuffix("|") else { break }
                    let cells = tableCells(from: candidate)
                    if !cells.isEmpty, !isTableSeparator(cells) {
                        gathered.append(cells)
                    }
                    index += 1
                }
                if !gathered.isEmpty {
                    flushParagraph()
                    blocks.append(.table(gathered))
                    continue
                }
            }

            // Block quote
            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quoteLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    var content = String(candidate.dropFirst())
                    if content.hasPrefix(" ") { content.removeFirst() }
                    quoteLines.append(content)
                    index += 1
                }
                blocks.append(.quote(quoteLines.joined(separator: "\n")))
                continue
            }

            // Bullet list
            if bulletContentStart(trimmed) != nil {
                flushParagraph()
                var items: [String] = []

                while index < lines.count {
                    let candidateRaw = lines[index]
                    let candidate = candidateRaw.trimmingCharacters(in: .whitespaces)

                    if let start = bulletContentStart(candidate) {
                        items.append(String(candidate[start...]).trimmingCharacters(in: .whitespaces))
                        index += 1
                    } else if !items.isEmpty,
                              candidateRaw.hasPrefix("  "),
                              !candidate.isEmpty,
                              numberedContentStart(candidate) == nil,
                              !candidate.hasPrefix("#") {
                        if let last = items.popLast() {
                            items.append(last + " " + candidate)
                        }
                        index += 1
                    } else {
                        break
                    }
                }

                blocks.append(.bullets(items))
                continue
            }

            // Numbered list
            if numberedContentStart(trimmed) != nil {
                flushParagraph()
                var items: [String] = []

                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let start = numberedContentStart(candidate) else { break }
                    items.append(String(candidate[start...]).trimmingCharacters(in: .whitespaces))
                    index += 1
                }

                blocks.append(.numbers(items))
                continue
            }

            paragraph.append(rawLine)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    static func inline(_ value: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible

        var attributed = (try? AttributedString(markdown: value, options: options))
            ?? AttributedString(value)

        // Collect the code spans first, then style them. Mutating while iterating
        // over `attributed.runs` can trigger an exclusivity conflict.
        var codeRanges: [Range<AttributedString.Index>] = []
        for run in attributed.runs {
            if let intent = run.inlinePresentationIntent, intent.contains(.code) {
                codeRanges.append(run.range)
            }
        }

        for range in codeRanges {
            attributed[range].font = Font.system(size: 14, design: .monospaced)
            attributed[range].backgroundColor = Color(uiColor: .tertiarySystemFill)
        }

        return attributed
    }

    private static func bulletContentStart(_ line: String) -> String.Index? {
        guard let first = line.first, first == "-" || first == "*" || first == "+" else {
            return nil
        }
        let afterMarker = line.index(after: line.startIndex)
        guard afterMarker < line.endIndex, line[afterMarker] == " " else { return nil }
        return line.index(after: afterMarker)
    }

    private static func numberedContentStart(_ line: String) -> String.Index? {
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor].isNumber {
            cursor = line.index(after: cursor)
        }
        guard cursor > line.startIndex,
              cursor < line.endIndex,
              line[cursor] == "." else {
            return nil
        }
        let afterDot = line.index(after: cursor)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        return line.index(after: afterDot)
    }

    private static func tableCells(from line: String) -> [String] {
        let inner = String(line.dropFirst().dropLast())
        return inner.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func isTableSeparator(_ cells: [String]) -> Bool {
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            !cell.isEmpty && cell.contains("-") && cell.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }
}

// MARK: - Rendered message

private enum MarkdownRenderBlock {
    case heading(level: Int, text: AttributedString)
    case paragraph(AttributedString)
    case bullets([AttributedString])
    case numbers([AttributedString])
    case quote(AttributedString)
    case code(language: String?, code: String)
    case table([[AttributedString]])
    case divider
}

/// Caches the parsed and styled blocks for a message. Completed messages are
/// rendered repeatedly as the chat scrolls, so parsing them each time is pure
/// overhead. Only the growing streaming message changes its key.
private final class MarkdownRenderCache {
    private var cachedText: String?
    private var cachedBlocks: [MarkdownRenderBlock] = []

    func blocks(for text: String) -> [MarkdownRenderBlock] {
        if cachedText == text {
            return cachedBlocks
        }

        let rendered = Self.render(text)
        cachedText = text
        cachedBlocks = rendered
        return rendered
    }

    private static func render(_ text: String) -> [MarkdownRenderBlock] {
        OZOMarkdownParser.parse(text).map { block -> MarkdownRenderBlock in
            switch block {
            case .heading(let level, let text):
                return .heading(level: level, text: OZOMarkdownParser.inline(text))
            case .paragraph(let text):
                return .paragraph(OZOMarkdownParser.inline(text))
            case .bullets(let items):
                return .bullets(items.map { OZOMarkdownParser.inline($0) })
            case .numbers(let items):
                return .numbers(items.map { OZOMarkdownParser.inline($0) })
            case .quote(let text):
                return .quote(OZOMarkdownParser.inline(text))
            case .code(let language, let code):
                return .code(language: language, code: code)
            case .table(let rows):
                return .table(rows.map { row in
                    row.map { OZOMarkdownParser.inline($0) }
                })
            case .divider:
                return .divider
            }
        }
    }
}

struct MarkdownMessageView: View {
    let text: String
    let isStreaming: Bool

    @State private var cache = MarkdownRenderCache()

    init(text: String, isStreaming: Bool = false) {
        self.text = text
        self.isStreaming = isStreaming
    }

    var body: some View {
        let blocks = cache.blocks(for: text)

        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }

            if isStreaming {
                StreamingCursor()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownRenderBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .lineSpacing(2)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

        case .paragraph(let text):
            Text(text)
                .font(.system(size: 16))
                .lineSpacing(4.5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Circle()
                            .fill(OZOTheme.accent)
                            .frame(width: 5, height: 5)
                            .offset(y: -2)
                        Text(item)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }

        case .numbers(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("\(itemIndex + 1).")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 18, alignment: .trailing)
                        Text(item)
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }

        case .quote(let text):
            HStack(alignment: .top, spacing: 11) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(OZOTheme.accent.opacity(0.55))
                    .frame(width: 3)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .code(let language, let code):
            MarkdownCodeBlock(language: language, code: code)

        case .table(let rows):
            MarkdownTableView(rows: rows)

        case .divider:
            Divider().padding(.vertical, 2)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 23, weight: .bold, design: .rounded)
        case 2:
            return .system(size: 20, weight: .bold, design: .rounded)
        case 3:
            return .system(size: 18, weight: .semibold, design: .rounded)
        default:
            return .system(size: 16, weight: .semibold, design: .rounded)
        }
    }
}

// MARK: - Code

struct MarkdownCodeBlock: View {
    let language: String?
    let code: String

    @EnvironmentObject private var settings: AppSettings
    @State private var copied = false

    private var languageLabel: String {
        let cleaned = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleaned.isEmpty ? "code" : cleaned
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(languageLabel.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    UIPasteboard.general.string = code
                    Haptics.success(settings.hapticsEnabled)
                    withAnimation(.easeOut(duration: 0.18)) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeOut(duration: 0.18)) { copied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(copied ? OZOTheme.accent : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Code copied" : "Copy code")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.025))

            Divider().opacity(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(13)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
        )
    }
}

// MARK: - Table

struct MarkdownTableView: View {
    let rows: [[AttributedString]]

    private let cellWidth: CGFloat = 148

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                            Text(cell)
                                .font(.system(size: 13, weight: rowIndex == 0 ? .semibold : .regular))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .frame(width: cellWidth, alignment: .leading)
                                .background(cellBackground(rowIndex))

                            if cellIndex < row.count - 1 {
                                Rectangle()
                                    .fill(OZOTheme.hairline)
                                    .frame(width: 0.5)
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    Divider().opacity(0.6)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(OZOTheme.hairline, lineWidth: 0.8)
            )
        }
    }

    private func cellBackground(_ rowIndex: Int) -> Color {
        if rowIndex == 0 { return OZOTheme.accent.opacity(0.08) }
        return rowIndex.isMultiple(of: 2) ? Color.primary.opacity(0.015) : .clear
    }
}

import Foundation

struct ConversationStorage {
    private let fileName = "chat-history.json"

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("OZOAI", isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    init() {
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func load() -> ConversationArchive {
        guard let data = try? Data(contentsOf: fileURL) else {
            return ConversationArchive()
        }
        return (try? decoder.decode(ConversationArchive.self, from: data)) ?? ConversationArchive()
    }

    func save(_ archive: ConversationArchive) {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(archive)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("OZO AI: failed to save conversations — \(error.localizedDescription)")
            #endif
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

import Foundation

public struct F75MacroLibrary: Codable, Sendable {
    public struct Entry: Identifiable, Codable, Equatable, Sendable {
        public let id: UUID
        public var macro: F75Macro
        public init(id: UUID = UUID(), macro: F75Macro) { self.id = id; self.macro = macro }
    }
    public private(set) var entries: [Entry] = []
    public init() {}
    private static let maximumFileSize = 8 * 1024 * 1024

    public static func load(from url: URL) throws -> F75MacroLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return F75MacroLibrary() }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: maximumFileSize + 1) ?? Data()
        guard !data.isEmpty, data.count <= maximumFileSize else { throw F75Error.invalid("The macro library is empty or too large.") }
        let library = try JSONDecoder().decode(Self.self, from: data)
        try library.validate()
        return library
    }

    @discardableResult
    public mutating func save(_ macro: F75Macro, id: UUID? = nil) throws -> UUID {
        _ = try F75MacroCodec.encode(macro)
        if let id {
            guard let index = entries.firstIndex(where: { $0.id == id }) else { throw F75Error.invalid("This saved macro no longer exists.") }
            entries[index].macro = macro
            return id
        }
        let entry = Entry(macro: macro)
        entries.append(entry)
        return entry.id
    }

    public mutating func remove(id: UUID) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { throw F75Error.invalid("This saved macro no longer exists.") }
        entries.remove(at: index)
    }

    public func write(to url: URL) throws {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileSize else { throw F75Error.invalid("The macro library is full. Export and remove unused copies.") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let old = try file.read(upToCount: Self.maximumFileSize + 1) ?? Data()
            guard old.count <= Self.maximumFileSize else { throw F75Error.invalid("The existing library is too large; it was preserved.") }
            try old.write(to: url.deletingPathExtension().appendingPathExtension("previous.json"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }

    private func validate() throws {
        guard Set(entries.map(\.id)).count == entries.count else { throw F75Error.invalid("The macro library has duplicate identifiers.") }
        for entry in entries { _ = try F75MacroCodec.encode(entry.macro) }
    }
}

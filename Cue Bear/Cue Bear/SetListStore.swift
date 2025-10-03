import Foundation
import Combine

final class SetlistStore: ObservableObject {
    @Published var setlist: Setlist
    @Published var mode: AppMode = .regular
    @Published var cuedSong: Song? = nil
    @Published var scrollLock: Bool = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        if let loaded = try? Self.load() {
            self.setlist = loaded
        } else {
            self.setlist = Setlist()
        }

        $setlist
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { _ in try? Self.save(self.setlist) }
            .store(in: &cancellables)
    }

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("setlist.json")
    }

    static func load() throws -> Setlist? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Setlist.self, from: data)
    }

    static func save(_ setlist: Setlist) throws {
        let data = try JSONEncoder().encode(setlist)
        try data.write(to: fileURL, options: [.atomic])
    }

    func addSong(name: String, subtitle: String?, cc: Int, channel: Int = 1) throws {
        if setlist.songs.contains(where: { $0.cc == cc && $0.channel == channel }) {
            throw NSError(domain: "CueBear", code: 1, userInfo: [NSLocalizedDescriptionKey: "CC #\(cc) on channel \(channel) already used."])
        }
        setlist.songs.append(Song(name: name, subtitle: subtitle, cc: cc, channel: channel))
    }

    func deleteSongs(at offsets: IndexSet) { setlist.songs.remove(atOffsets: offsets) }
    func moveSongs(from source: IndexSet, to destination: Int) { setlist.songs.move(fromOffsets: source, toOffset: destination) }
}

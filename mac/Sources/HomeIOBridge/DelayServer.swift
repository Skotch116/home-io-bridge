import Foundation
import Network

/// How much later (or, below zero, earlier) the owner wants each speaker model to play, in milliseconds, so it lines
/// up with the home's AirPlay 2 speakers by ear. Kept as lines of "model<TAB>ms" in `delays.txt`, which the engine
/// reads each time music starts.
enum Delays {
    static let file = Engine.support.appending(path: "delays.txt")
    static let limit = 500
    /// The models the engine can keep in time. Any other model plays unsynced, and a shift would do nothing.
    static let synced: Set<String> = ["Google Nest Hub", "Google Nest Mini", "Nest Audio"]

    static func all() -> [String: Int] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [:] }
        var out: [String: Int] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            if parts.count == 2, let ms = Int(parts[1]) { out[String(parts[0])] = ms }
        }
        return out
    }

    static func set(_ ms: Int, for model: String) {
        var all = all()
        all[model] = min(max(ms, -limit), limit)
        try? FileManager.default.createDirectory(at: Engine.support, withIntermediateDirectories: true)
        let text = all.sorted { $0.key < $1.key }.map { "\($0.key)\t\($0.value)\n" }.joined()
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }
}

/// Lets Home.io on a phone on this network read and set those delays. It announces itself as `_homeio-bridge._tcp`
/// and speaks a very small HTTP:
///   GET /speakers            -> {"speakers":[{"name":"Kitchen Display","model":"Google Nest Hub","delay":0,"synced":true}]}
///   POST /delay {"model":"Google Nest Hub","delay":40} -> the same list
/// A delay is all it can change, and only within `Delays.limit`.
@MainActor
final class DelayServer {
    private var listener: NWListener?
    private let speakers: CastSpeakers

    init(speakers: CastSpeakers) {
        self.speakers = speakers
        guard let l = try? NWListener(using: .tcp) else { return }
        l.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: "_homeio-bridge._tcp")
        l.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { @MainActor in self?.read(connection, so: Data()) }
        }
        l.start(queue: .main)
        listener = l
    }

    /// Reads until the whole request is here (its head, and as much body as it says it has), then answers and closes.
    private func read(_ connection: NWConnection, so far: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, done, error in
            Task { @MainActor in
                guard let self else { return }
                let all = far + (data ?? Data())
                if let request = Self.request(in: all) {
                    self.answer(request, on: connection)
                } else if done || error != nil || all.count > 16384 {
                    connection.cancel()
                } else {
                    self.read(connection, so: all)
                }
            }
        }
    }

    private static func request(in data: Data) -> (method: String, path: String, body: Data)? {
        guard let gap = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<gap.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ")
        guard first.count >= 2 else { return nil }
        let length = lines.dropFirst().first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        let body = data[gap.upperBound...]
        guard body.count >= length else { return nil }
        return (String(first[0]), String(first[1]), Data(body.prefix(length)))
    }

    private func answer(_ request: (method: String, path: String, body: Data), on connection: NWConnection) {
        var status = "200 OK"
        switch (request.method, request.path) {
        case ("GET", "/speakers"):
            break
        case ("POST", "/delay"):
            if let asked = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
               let model = asked["model"] as? String, let ms = asked["delay"] as? Int, Delays.synced.contains(model) {
                Delays.set(ms, for: model)
            } else {
                status = "400 Bad Request"
            }
        default:
            status = "404 Not Found"
        }
        let delays = Delays.all()
        let list = speakers.found.map { s in
            ["name": s.name, "model": s.model, "delay": delays[s.model] ?? 0, "synced": Delays.synced.contains(s.model)] as [String: Any]
        }
        let body = (try? JSONSerialization.data(withJSONObject: ["speakers": list])) ?? Data()
        let head = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }
}

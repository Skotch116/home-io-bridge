import Network
import ServiceManagement
import SwiftUI

/// The Google Cast speakers on this network, as they announce themselves (`_googlecast._tcp`): `fn` is the name the
/// Google Home app shows, `md` the model. Speaker groups made in Google Home announce themselves the same way and are
/// left out: the bridge is about single speakers first.
@MainActor
final class CastSpeakers: ObservableObject {
    struct Speaker: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let model: String
    }

    @Published var found: [Speaker] = []
    /// Ids of the speakers the engine can't bring back into time right now (looked at every 5 seconds).
    @Published var outOfTime: Set<String> = []
    private var browser: NWBrowser?
    private var looking: Timer?

    /// Answers Home.io on a phone about these speakers' delays (not for the `-list` test).
    private var server: DelayServer?

    init() {
        start()
        guard !CommandLine.arguments.contains("-list") else { return }
        server = DelayServer(speakers: self)
        looking = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let late = Delays.outOfTime()
                if self?.outOfTime != late { self?.outOfTime = late }
            }
        }
    }

    /// What the menu says about a speaker's timing, or nil when it is kept in time.
    func note(for s: Speaker) -> String? {
        if !Delays.synced.contains(s.model) { return "not kept in time" }
        return outOfTime.contains(s.id) ? "out of time right now" : nil
    }

    /// Looks until the browser fails, then starts over half a minute on.
    private func start() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: "_googlecast._tcp", domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            let all = results.compactMap(Self.speaker).sorted { $0.name < $1.name }
            Task { @MainActor in self?.found = all }
        }
        b.stateUpdateHandler = { [weak self] state in
            guard case .failed = state else { return }
            b.cancel()
            Task { @MainActor in
                self?.browser = nil
                try? await Task.sleep(for: .seconds(30))
                self?.start()
            }
        }
        b.start(queue: .main)
        browser = b
    }

    nonisolated private static func speaker(_ result: NWBrowser.Result) -> Speaker? {
        guard case .service(let service, _, _, _) = result.endpoint, case .bonjour(let txt) = result.metadata,
              let name = txt.dictionary["fn"], let model = txt.dictionary["md"], model != "Google Cast Group" else { return nil }
        return Speaker(id: txt.dictionary["id"] ?? service, name: name, model: model)
    }
}

/// Runs the engine (the `play-on-air` program beside this one in the app) for as long as the app is open, and
/// starts it again if it stops. The engine is what makes each Google speaker an AirPlay 2 speaker.
@MainActor
final class Engine: ObservableObject {
    @Published var running = false
    /// False when the app was built without the engine.
    let present: Bool
    private var process: Process?
    private var quitting = false
    private let program = Bundle.main.url(forAuxiliaryExecutable: "play-on-air")

    nonisolated static let support = URL.applicationSupportDirectory.appending(path: "Home.io Bridge")
    static let log = URL.libraryDirectory.appending(path: "Logs/Home.io Bridge/engine.log")

    init() {
        present = program != nil
        // The `-list` test only looks; a second engine would fight the first one for its ports.
        guard let program, !CommandLine.arguments.contains("-list") else { return }
        // An engine left behind by a copy of this app that crashed still holds the ports: stop it first.
        let old = Process()
        old.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        old.arguments = ["-f", program.path]
        // Waits without `waitUntilExit`, which runs the run loop and crashes SwiftUI when called from here.
        let gone = DispatchSemaphore(value: 0)
        old.terminationHandler = { _ in gone.signal() }
        if (try? old.run()) != nil { gone.wait() }
        // Quit from the menu, log out and restart all come through here.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        start()
    }

    private func start() {
        guard let program, process == nil, !quitting else { return }
        let files = FileManager.default
        try? files.createDirectory(at: Self.support, withIntermediateDirectories: true)
        try? files.createDirectory(at: Self.log.deletingLastPathComponent(), withIntermediateDirectories: true)
        // One log per run, and the run before it.
        let before = Self.log.deletingLastPathComponent().appending(path: "engine.previous.log")
        try? files.removeItem(at: before)
        try? files.moveItem(at: Self.log, to: before)
        files.createFile(atPath: Self.log.path, contents: nil)

        let p = Process()
        p.executableURL = program
        // The engine's optional rename / hide file, if the owner made one.
        p.arguments = ["--config", Self.support.appending(path: "play-on-air.toml").path]
        p.currentDirectoryURL = Self.support
        let out = try? FileHandle(forWritingTo: Self.log)
        // (the engine ends by itself when this app is gone, however it went)
        p.environment = ProcessInfo.processInfo.environment.merging(["HOMEIO_BRIDGE_PARENT": "1"]) { _, new in new }
        p.standardOutput = out
        p.standardError = out
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                self.running = false
                try? await Task.sleep(for: .seconds(5))
                self.start()
            }
        }
        do {
            try p.run()
            process = p
            running = true
        } catch {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                self.start()
            }
        }
    }

    func stop() {
        quitting = true
        process?.terminate()
    }
}

@main
struct BridgeApp: App {
    @StateObject private var speakers = CastSpeakers()
    @StateObject private var engine = Engine()
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    init() {
        // `HomeIOBridge -nologin` turns Open at Login off and quits, without starting anything: for a Mac where
        // Home.io itself runs the engine now, and the two would fight for the same ports after a restart.
        if CommandLine.arguments.contains("-nologin") {
            UserDefaults.standard.set(true, forKey: "loginChosen")
            try? SMAppService.mainApp.unregister()
            print("open at login: \(SMAppService.mainApp.status == .enabled ? "on" : "off")")
            exit(0)
        }
        // Opens at login from the first run on, so the speakers are there after a restart. The menu turns it off.
        if !UserDefaults.standard.bool(forKey: "loginChosen"), !CommandLine.arguments.contains("-list") {
            UserDefaults.standard.set(true, forKey: "loginChosen")
            try? SMAppService.mainApp.register()
        }
        // Test: `HomeIOBridge -list` prints the speakers found in 5 seconds and quits.
        guard CommandLine.arguments.contains("-list") else { return }
        let found = CastSpeakers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            for s in found.found { print("\(s.name)\t\(s.model)") }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra("Home.io Bridge", systemImage: "hifispeaker.2") {
            if speakers.found.isEmpty {
                Text("Looking for Google speakers…")
            } else {
                Text("Google speakers on this network")
                ForEach(speakers.found) { s in
                    Text("\(s.name) · \(s.model)" + (speakers.note(for: s).map { " · \($0)" } ?? ""))
                }
                if speakers.found.contains(where: { !Delays.synced.contains($0.model) }) {
                    Text("Not kept in time: it plays, but can lag your AirPlay speakers.")
                }
                if speakers.found.contains(where: { speakers.outOfTime.contains($0.id) }) {
                    Text("Out of time right now: stop the music and start it again.")
                }
            }
            Divider()
            Text(!engine.present ? "This copy was built without the AirPlay engine."
                 : engine.running ? "They show up as AirPlay speakers while this is open."
                 : "AirPlay stopped. Starting it again…")
            Divider()
            Toggle("Open at Login", isOn: $opensAtLogin)
                .onChange(of: opensAtLogin) { _, on in
                    if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                    opensAtLogin = SMAppService.mainApp.status == .enabled
                }
            Button("Quit Home.io Bridge") { NSApplication.shared.terminate(nil) }
        }
    }
}

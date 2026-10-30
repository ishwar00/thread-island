// ThreadIsland: a notch panel listing Codex + Claude Code threads. Hover to expand, click to jump.
// All data and jumps come from ~/.local/bin/threads; this file is only the UI.
import AppKit
import SwiftUI

let threadsScript = NSString(string: "~/.local/bin/threads").expandingTildeInPath

struct Row: Codable, Identifiable {
    let key: String, ts: Double, src: String, state: String, title: String, detail: String?
    let action: String, arg: String, cwd: String, age: String, section: String
    var id: String { key }
}

struct Payload: Decodable {
    let rows: [Row]
    let errors: [String]
}

func runThreads(_ args: [String], input: Data? = nil) -> Data {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    p.arguments = [threadsScript] + args
    p.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory()]
    let out = Pipe(), inp = Pipe()
    p.standardOutput = out
    p.standardError = FileHandle.nullDevice
    p.standardInput = inp
    do { try p.run() } catch { return Data() }
    if let input { inp.fileHandleForWriting.write(input) }
    try? inp.fileHandleForWriting.close()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return data
}

/// A moment worth surfacing in the collapsed island: a thread started needing you, or finished working.
struct Alert: Equatable {
    let row: Row
    let label: String
    let color: Color
    static func == (a: Alert, b: Alert) -> Bool { a.row.key == b.row.key && a.label == b.label }
}

final class Store: ObservableObject {
    @Published var rows: [Row] = []
    @Published var errors: [String] = []
    var onAlert: (Alert) -> Void = { _ in }
    private var loading = false
    private var lastStates: [String: String]?  // nil until the first load, so startup doesn't alert

    func refresh() {
        guard !loading else { return }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = runThreads([])
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
            DispatchQueue.main.async {
                self.loading = false
                guard let payload else {
                    self.errors = ["threads script: no readable output (\(data.count) bytes)"]
                    return
                }
                self.detectAlerts(payload.rows)
                self.rows = payload.rows
                self.errors = payload.errors
            }
        }
    }

    private func detectAlerts(_ rows: [Row]) {
        defer { lastStates = Dictionary(rows.map { ($0.key, $0.state) }, uniquingKeysWith: { a, _ in a }) }
        guard let before = lastStates else { return }
        for row in rows {
            let was = before[row.key]
            if row.state == "needs you" && was != "needs you" {
                return onAlert(Alert(row: row, label: "Needs you", color: .orange))
            }
            if was == "working" && row.state != "working" && row.state != "needs you" {
                return onAlert(Alert(row: row, label: row.state == "failed" ? "Failed" : "Done",
                                     color: row.state == "failed" ? .red : .green))
            }
        }
    }

    func jump(_ row: Row) {
        guard let payload = try? JSONEncoder().encode(row) else { return }
        DispatchQueue.global(qos: .userInitiated).async { _ = runThreads(["--jump"], input: payload) }
    }

    var needsYou: Int { rows.filter { $0.state == "needs you" }.count }
    var working: Int { rows.filter { $0.state == "working" }.count }
}

func stateColor(_ state: String) -> Color {
    switch state {
    case "needs you": return .orange
    case "working": return .green
    case "failed": return .red
    default: return .gray.opacity(0.5)
    }
}

// Real app icons, so the source is readable at a glance on the left edge
let codexIcon = NSImage(contentsOfFile: "/Applications/ChatGPT.app/Contents/Resources/icon-codex-dark-color.png")
    ?? NSWorkspace.shared.icon(forFile: "/Applications/ChatGPT.app")
let claudeIcon = NSWorkspace.shared.icon(forFile: "/Applications/Claude.app")

func appIcon(_ row: Row, size: CGFloat) -> some View {
    Image(nsImage: row.src.hasPrefix("codex") ? codexIcon : claudeIcon)
        .resizable().interpolation(.high).frame(width: size, height: size)
}

struct IslandView: View {
    @ObservedObject var store: Store
    let expanded: Bool
    let alert: Alert?
    let notch: CGSize
    let onPick: (Row) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let alert, !expanded { alertWings(alert) } else { badgeWings }
            }
            .frame(height: notch.height)
            if expanded { list }
        }
        .background(UnevenRoundedRectangle(bottomLeadingRadius: expanded ? 22 : 12,
                                           bottomTrailingRadius: expanded ? 22 : 12).fill(.black))
        .contentShape(Rectangle())
        .onTapGesture { if let alert, !expanded { onPick(alert.row) } }
        .contextMenu { Button("Quit ThreadIsland") { NSApp.terminate(nil) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder var badgeWings: some View {
        HStack(spacing: 6) {
            if !store.errors.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundStyle(.red)
            }
            badge(store.needsYou, .orange)
        }
        .frame(maxWidth: .infinity)
        Spacer().frame(width: notch.width)
        badge(store.working, .green).frame(maxWidth: .infinity)
    }

    // The notch hides the middle, so the alert lives in the wings: who on the left, what happened on the right
    @ViewBuilder func alertWings(_ alert: Alert) -> some View {
        HStack(spacing: 7) {
            appIcon(alert.row, size: 18)
            Text(alert.row.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 14)
        .frame(maxWidth: .infinity)
        Spacer().frame(width: notch.width)
        HStack(spacing: 5) {
            Spacer(minLength: 0)
            Circle().fill(alert.color).frame(width: 7, height: 7)
            Text(alert.label).font(.system(size: 12, weight: .semibold)).foregroundStyle(alert.color)
        }
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity)
    }

    func badge(_ n: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            if n > 0 {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("\(n)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            }
        }
    }

    var list: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.errors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11)).foregroundStyle(.red.opacity(0.9)).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.12)))
                }
                if store.rows.isEmpty && store.errors.isEmpty {
                    Text("No threads in the last 7 days").foregroundStyle(.gray).padding()
                }
                ForEach(Array(store.rows.enumerated()), id: \.element.id) { i, row in
                    if i == 0 || store.rows[i - 1].section != row.section {
                        Text(row.section.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.8)
                            .foregroundStyle(row.section == "Priority" ? Color.orange.opacity(0.85) : .white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.top, i == 0 ? 4 : 14).padding(.bottom, 3)
                    }
                    RowView(row: row).onTapGesture { onPick(row) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }
}

struct RowView: View {
    let row: Row
    @State private var hover = false

    var inTerminal: Bool { row.src.hasSuffix("-cli") || row.src == "claude-bg" }
    var stateLabel: String? {
        switch row.state {
        case "needs you": return "Needs you"
        case "working": return "Working"
        case "failed": return "Failed"
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 11) {
            ZStack(alignment: .bottomTrailing) {
                appIcon(row, size: 28)
                if stateLabel != nil {
                    Circle().fill(stateColor(row.state)).frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.black, lineWidth: 2)).offset(x: 2, y: 2)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 5) {
                    Text(row.age).monospacedDigit().foregroundStyle(.white.opacity(0.55))
                    if inTerminal {
                        Image(systemName: "terminal").font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                    }
                    if let stateLabel {
                        Text(stateLabel).fontWeight(.medium).foregroundStyle(stateColor(row.state))
                    }
                    if let detail = row.detail, !detail.isEmpty {
                        Text(detail).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                    }
                }
                .font(.system(size: 11))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hover ? 0.08 : 0)))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

// Non-key panel: take the first click, and track hover even when another app is active.
final class HoverHostingView<V: View>: NSHostingView<V> {
    var onHover: (Bool) -> Void = { _ in }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }
    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }
}

final class Island: NSObject {
    let store = Store()
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    var host: HoverHostingView<IslandView>!
    var expanded = false
    var alert: Alert?
    var notch = CGSize(width: 180, height: 32)
    var hoverWork: DispatchWorkItem?
    var alertWork: DispatchWorkItem?
    var ticks = 0
    let wing: CGFloat = 44, alertWing: CGFloat = 190, expandedSize = CGSize(width: 520, height: 480)

    func start() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        host = HoverHostingView(rootView: view())
        host.onHover = { [weak self] inside in self?.hovered(inside) }
        panel.contentView = host
        store.onAlert = { [weak self] alert in self?.show(alert) }
        layout()
        panel.orderFrontRegardless()
        store.refresh()
        // ponytail: polls the script (~0.5s CPU per run): every 4s while open, every 12s collapsed (alert latency)
        Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.ticks += 1
            if self.expanded || self.ticks % 3 == 0 { self.store.refresh() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.layout() }
    }

    func view() -> IslandView {
        IslandView(store: store, expanded: expanded, alert: alert, notch: notch) { [weak self] row in
            self?.store.jump(row)
            self?.alert = nil
            self?.setExpanded(false)
        }
    }

    func show(_ alert: Alert) {
        self.alert = alert
        alertWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.alert = nil
            self?.layout()
        }
        alertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
        layout()
    }

    func hovered(_ inside: Bool) {
        hoverWork?.cancel()
        // expand only if the cursor rests on the notch, so passing through to the menu bar doesn't open it
        let work = DispatchWorkItem { [weak self] in self?.setExpanded(inside) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? 0.15 : 0.25), execute: work)
    }

    func setExpanded(_ value: Bool) {
        guard value != expanded else { return }
        expanded = value
        if value { store.refresh() }
        layout()
    }

    func layout() {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        if let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            notch = CGSize(width: r.minX - l.maxX, height: screen.safeAreaInsets.top)
        } else {
            notch = CGSize(width: 180, height: NSStatusBar.system.thickness)
        }
        let size = expanded ? expandedSize
            : CGSize(width: notch.width + 2 * (alert == nil ? wing : alertWing), height: notch.height)
        let f = screen.frame
        let frame = NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
        host.rootView = view()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let island = Island()
island.start()
app.run()

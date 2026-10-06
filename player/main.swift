import AppKit
import AVFoundation

enum Mode {
    case single
    case swarm(count: Int)
}

struct VideoInfo {
    let size: CGSize
    let duration: Double

    static func load(from asset: AVURLAsset) async -> VideoInfo {
        let duration = (try? await asset.load(.duration).seconds) ?? 10
        guard
            let track = try? await asset.loadTracks(withMediaType: .video).first,
            let size = try? await track.load(.naturalSize),
            let transform = try? await track.load(.preferredTransform)
        else { return VideoInfo(size: CGSize(width: 16, height: 9), duration: duration) }
        let rotated = size.applying(transform)
        return VideoInfo(size: CGSize(width: abs(rotated.width), height: abs(rotated.height)), duration: duration)
    }
}

@MainActor
final class AdWindow {
    private let window: NSWindow
    private let player: AVPlayer
    private var observers: [NSObjectProtocol] = []
    private var closed = false
    private let onClose: () -> Void

    init(asset: AVURLAsset, frame: NSRect, isPopup: Bool, onClose: @escaping () -> Void) {
        self.onClose = onClose

        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.backgroundColor = isPopup ? .clear : .black
        window.isOpaque = !isPopup
        window.hasShadow = isPopup
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false

        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player.volume = 1.0

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        if isPopup {
            view.layer?.cornerRadius = 10
            view.layer?.masksToBounds = true
            view.layer?.borderWidth = 2
            view.layer?.borderColor = NSColor(calibratedRed: 0.62, green: 0.45, blue: 1.0, alpha: 1).cgColor
        }
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        window.contentView = view

        for name in [Notification.Name.AVPlayerItemDidPlayToEndTime, .AVPlayerItemFailedToPlayToEndTime] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            })
        }
    }

    func show(animated: Bool) {
        if animated {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                window.animator().alphaValue = 1
            }
        } else {
            window.orderFrontRegardless()
        }
        player.play()
    }

    func close() {
        guard !closed else { return }
        closed = true
        observers.forEach(NotificationCenter.default.removeObserver)
        player.pause()
        window.orderOut(nil)
        onClose()
    }
}

@MainActor
final class AdPlayer: NSObject, NSApplicationDelegate {
    private static let swarmSpawnInterval = 0.12...0.35
    private static let swarmWidthFraction = 0.16...0.3

    private let asset: AVURLAsset
    private let mode: Mode
    private var ads: [AdWindow] = []
    private var openAds = 0
    private var allScheduled = false

    init(videoURL: URL, mode: Mode) {
        asset = AVURLAsset(url: videoURL)
        self.mode = mode
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let info = await VideoInfo.load(from: self.asset)
            let screen = Self.activeScreen()
            switch self.mode {
            case .single:
                self.presentSingle(info: info, screen: screen)
            case .swarm(let count):
                self.presentSwarm(count: count, info: info, screen: screen)
            }
        }
    }

    private static func activeScreen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func presentSingle(info: VideoInfo, screen: NSScreen) {
        let bounds = screen.frame
        let height = min(bounds.width * info.size.height / info.size.width, bounds.height)
        let width = height * info.size.width / info.size.height
        let frame = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
        spawn(frame: frame, isPopup: false)
        allScheduled = true
        scheduleFailsafe(after: info.duration + 3)
    }

    private func presentSwarm(count: Int, info: VideoInfo, screen: NSScreen) {
        let bounds = screen.visibleFrame
        var delay = 0.0
        for index in 0..<count {
            let frame = Self.randomFrame(in: bounds, aspect: info.size)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.spawn(frame: frame, isPopup: true)
                if index == count - 1 { self.allScheduled = true }
            }
            delay += Double.random(in: Self.swarmSpawnInterval)
        }
        scheduleFailsafe(after: delay + info.duration + 3)
    }

    private static func randomFrame(in bounds: NSRect, aspect: CGSize) -> NSRect {
        let width = bounds.width * Double.random(in: swarmWidthFraction)
        let height = width * aspect.height / aspect.width
        let originX = bounds.minX + Double.random(in: 0...max(0, bounds.width - width))
        let originY = bounds.minY + Double.random(in: 0...max(0, bounds.height - height))
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private func spawn(frame: NSRect, isPopup: Bool) {
        let ad = AdWindow(asset: asset, frame: frame, isPopup: isPopup) { [weak self] in
            self?.adClosed()
        }
        ads.append(ad)
        openAds += 1
        ad.show(animated: isPopup)
    }

    private func adClosed() {
        openAds -= 1
        if allScheduled && openAds == 0 { NSApp.terminate(nil) }
    }

    private func scheduleFailsafe(after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            NSApp.terminate(nil)
        }
    }
}

func parseArguments(_ arguments: [String]) -> (Mode, URL)? {
    var mode = Mode.single
    var rest = arguments.dropFirst()
    if rest.first == "--swarm" {
        rest = rest.dropFirst()
        guard let count = rest.first.flatMap(Int.init), count > 0 else { return nil }
        mode = .swarm(count: count)
        rest = rest.dropFirst()
    }
    guard rest.count == 1, let path = rest.first else { return nil }
    return (mode, URL(fileURLWithPath: path))
}

guard let (mode, videoURL) = parseArguments(CommandLine.arguments) else {
    FileHandle.standardError.write(Data("usage: musor-drop-player [--swarm <count>] <video>\n".utf8))
    exit(64)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = MainActor.assumeIsolated { AdPlayer(videoURL: videoURL, mode: mode) }
app.delegate = delegate
app.run()

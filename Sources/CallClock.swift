import Cocoa

// A monotonic clock keeps the timer independent of local time changes.
struct LoopTimer {
    var started = ProcessInfo.processInfo.systemUptime
    var accumulated: TimeInterval = 0
    var paused = false

    func elapsed(at now: TimeInterval) -> TimeInterval {
        accumulated + (paused ? 0 : max(0, now - started))
    }

    mutating func toggle(at now: TimeInterval) {
        if paused { started = now } else { accumulated = elapsed(at: now) }
        paused.toggle()
    }

    mutating func reset(at now: TimeInterval) {
        accumulated = 0
        started = now
        paused = false
    }
}

final class ClockView: NSView {
    var clock = LoopTimer()
    private var ticker: Timer?
    private var tracking: NSTrackingArea?
    private let pauseButton = NSButton()
    private let resetButton = NSButton()
    private let closeButton = NSButton()
    private let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    override var mouseDownCanMoveWindow: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure(closeButton, symbol: "xmark", tip: "Quit", action: #selector(quit))
        configure(pauseButton, symbol: "pause.fill", tip: "Pause or resume", action: #selector(pause))
        configure(resetButton, symbol: "arrow.counterclockwise", tip: "Restart for a new call", action: #selector(reset))
        closeButton.frame = NSRect(x: 25, y: 205, width: 24, height: 24)
        pauseButton.frame = NSRect(x: 48, y: 12, width: 68, height: 54)
        resetButton.frame = NSRect(x: 124, y: 12, width: 68, height: 54)
        for button in [pauseButton, resetButton] {
            button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
            button.contentTintColor = .white
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor(calibratedWhite: 0.22, alpha: 1).cgColor
            button.layer?.cornerRadius = 14
        }
        ticker = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(ticker!, forMode: .common)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Five minute call timer")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure(_ button: NSButton, symbol: String, tip: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.contentTintColor = NSColor.white.withAlphaComponent(0.65)
        button.target = self
        button.action = action
        button.toolTip = tip
        button.isHidden = true
        addSubview(button)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { showControls(true) }
    override func mouseExited(with event: NSEvent) { showControls(false) }
    private func showControls(_ show: Bool) {
        [pauseButton, resetButton, closeButton].forEach { $0.isHidden = !show }
    }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }

    @objc private func pause() {
        clock.toggle(at: ProcessInfo.processInfo.systemUptime)
        pauseButton.image = NSImage(systemSymbolName: clock.paused ? "play.fill" : "pause.fill", accessibilityDescription: clock.paused ? "Resume" : "Pause")
        needsDisplay = true
    }
    @objc private func reset() {
        clock.reset(at: ProcessInfo.processInfo.systemUptime)
        pauseButton.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "Pause")
        needsDisplay = true
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func label(_ text: String, y: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        (text as NSString).draw(in: NSRect(x: 30, y: y, width: 180, height: size + 12), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: style
        ])
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.075, green: 0.087, blue: 0.105, alpha: 0.97).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 8), xRadius: 36, yRadius: 36).fill()
        let center = NSPoint(x: 120, y: 126)
        let radius: CGFloat = 91
        let elapsed = clock.elapsed(at: ProcessInfo.processInfo.systemUptime)
        let loops = Int(elapsed / 300)
        let progress = elapsed.truncatingRemainder(dividingBy: 300) / 300
        let track = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        track.lineWidth = 5
        NSColor.white.withAlphaComponent(0.10).setStroke()
        track.stroke()
        let mint = NSColor(calibratedRed: 0.43, green: 0.88, blue: 0.72, alpha: clock.paused ? 0.4 : 1)
        if progress > 0 {
            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - CGFloat(progress * 360), clockwise: true)
            ring.lineWidth = 5
            ring.lineCapStyle = .round
            mint.setStroke()
            ring.stroke()
        }
        let angle = Double.pi / 2 - progress * Double.pi * 2
        mint.setFill()
        let dotX = center.x + radius * CGFloat(Darwin.cos(angle))
        let dotY = center.y + radius * CGFloat(Darwin.sin(angle))
        NSBezierPath(ovalIn: NSRect(x: dotX - 4, y: dotY - 4, width: 8, height: 8)).fill()
        label("\(loops)", y: 127, size: 44, color: .white, weight: .medium)
        label(loops == 1 ? "LOOP COMPLETE" : "LOOPS COMPLETE", y: 108, size: 9, color: .white.withAlphaComponent(0.45), weight: .medium)
        label(timeFormat.string(from: Date()), y: 65, size: 32, color: .white, weight: .medium)
        if clock.paused { label("PAUSED", y: 182, size: 9, color: mint, weight: .medium) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 120, height: 122), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Call Clock"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        let clockView = ClockView(frame: NSRect(x: 0, y: 0, width: 120, height: 122))
        clockView.bounds = NSRect(x: 0, y: 0, width: 240, height: 244)
        panel.contentView = clockView
        panel.setFrameAutosaveName("CallClockPosition")
        if !panel.setFrameUsingName("CallClockPosition"), let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 264, y: screen.visibleFrame.maxY - 268))
        }
        panel.setContentSize(NSSize(width: 120, height: 122))
        panel.orderFrontRegardless()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

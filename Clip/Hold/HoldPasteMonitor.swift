import AppKit
import CoreGraphics

/// Opens history when Command-V is held, and replays a short tap as a normal paste.
final class HoldPasteMonitor {
    static weak var current: HoldPasteMonitor?

    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdTimer: Timer?
    private var arm: Arm = .idle
    private var ignoringSynthetic = 0

    var holdEnabled = true
    private(set) var historyVisible = false

    private enum Arm {
        case idle
        case pending(panelWasOpen: Bool)
        case consumed
    }

    private let holdDelay: TimeInterval = 0.4
    private let keyV: Int64 = 9

    init() {
        Self.current = self
    }

    func setHistoryVisible(_ visible: Bool) {
        historyVisible = visible
    }

    func beginIgnoring(_ count: Int) {
        guard machPort != nil else { return }
        ignoringSynthetic += count
    }

    func start() {
        guard holdEnabled else {
            stop()
            return
        }
        guard machPort == nil else { return }
        installTap()
    }

    func stop() {
        cancelTimer()
        arm = .idle
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        machPort = nil
    }

    private func installTap() {
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HoldPasteMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            return
        }

        ignoringSynthetic = 0
        machPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let machPort {
                CGEvent.tapEnable(tap: machPort, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if SyntheticPaste.isSynthetic(event) || (ignoringSynthetic > 0 && isCommandV(event)) {
            if ignoringSynthetic > 0 {
                ignoringSynthetic -= 1
            }
            return Unmanaged.passUnretained(event)
        }

        guard holdEnabled else { return Unmanaged.passUnretained(event) }

        switch type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        case .flagsChanged:
            return handleFlags(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        // Releasing Command while V is still down posts a new V keyDown with no modifier.
        if case .consumed = arm, isV(event) {
            return nil
        }
        let commandV = isPlainCommandV(event)
        if case .pending = arm, !commandV {
            finishPending(replay: true)
            return Unmanaged.passUnretained(event)
        }
        guard commandV else { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            if case .idle = arm {
                return Unmanaged.passUnretained(event)
            }
            return nil
        }
        if appIsEditing {
            return Unmanaged.passUnretained(event)
        }
        arm = .pending(panelWasOpen: historyVisible)
        startTimer()
        return nil
    }

    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if case .consumed = arm, isV(event) {
            arm = .idle
            return nil
        }
        guard isPlainCommandV(event) else { return Unmanaged.passUnretained(event) }
        switch arm {
        case .idle:
            return Unmanaged.passUnretained(event)
        case .pending(let wasOpen):
            cancelTimer()
            arm = .idle
            if wasOpen {
                DispatchQueue.main.async {
                    AppModel.shared.history.pasteSelected(plainText: false)
                }
            } else {
                replayCommandV()
            }
            return nil
        case .consumed:
            arm = .idle
            return nil
        }
    }

    private func handleFlags(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard !event.flags.contains(.maskCommand) else {
            return Unmanaged.passUnretained(event)
        }
        switch arm {
        case .idle, .consumed:
            return Unmanaged.passUnretained(event)
        case .pending(let wasOpen):
            cancelTimer()
            arm = .idle
            if wasOpen {
                DispatchQueue.main.async {
                    AppModel.shared.history.pasteSelected(plainText: false)
                }
            } else {
                replayCommandV()
            }
            return Unmanaged.passUnretained(event)
        }
    }

    private var appIsEditing: Bool {
        NSApp.isActive && !historyVisible
    }

    private func finishPending(replay: Bool) {
        let shouldReplay: Bool
        if case .pending(let wasOpen) = arm {
            shouldReplay = replay && !wasOpen
        } else {
            shouldReplay = false
        }
        cancelTimer()
        arm = .idle
        if shouldReplay {
            replayCommandV()
        }
    }

    private func startTimer() {
        cancelTimer()
        let timer = Timer(timeInterval: holdDelay, repeats: false) { [weak self] _ in
            self?.holdFired()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func holdFired() {
        holdTimer = nil
        guard case .pending(let wasOpen) = arm else { return }
        arm = .consumed
        guard !wasOpen else { return }
        DispatchQueue.main.async {
            AppModel.shared.history.showNearMouse()
        }
    }

    private func replayCommandV() {
        SyntheticPaste.postCommandV()
    }

    private func isV(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == keyV
    }

    private func isCommandV(_ event: CGEvent) -> Bool {
        isV(event)
    }

    private func isPlainCommandV(_ event: CGEvent) -> Bool {
        guard isCommandV(event) else { return false }
        let flags = event.flags
        guard flags.contains(.maskCommand) else { return false }
        let extras: CGEventFlags = [.maskShift, .maskAlternate, .maskControl]
        return flags.intersection(extras).isEmpty
    }
}

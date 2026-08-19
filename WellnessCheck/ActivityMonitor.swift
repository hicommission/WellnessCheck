import Foundation
import AppKit
import Combine

/// Monitors global mouse/keyboard activity and system sleep/wake events.
final class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()

    @Published private(set) var lastActivityDate: Date
    @Published private(set) var isSleeping = false

    private var globalMouseMonitor: Any?
    private var globalKeyMonitor: Any?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var sleepStart: Date?
    private var accumulatedSleepTime: TimeInterval = 0

    private init() {
        lastActivityDate = WellnessStore.loadLastActivity()
        startMonitoring()
        observeSleepWake()
        log("ActivityMonitor initialized — last activity: \(lastActivityDate)")
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Activity Detection

    private func startMonitoring() {
        // Monitor mouse movement and clicks
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] _ in
            self?.recordActivity()
        }

        // Monitor keyboard
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] _ in
            self?.recordActivity()
        }

        log("Global event monitoring started")
    }

    private func stopMonitoring() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        log("Monitoring stopped")
    }

    func recordActivity() {
        DispatchQueue.main.async {
            self.lastActivityDate = Date()
            WellnessStore.saveLastActivity(self.lastActivityDate)
        }
    }

    /// Manual "I'm Here" confirmation — resets activity timestamp
    func confirmPresence() {
        recordActivity()
    }

    // MARK: - Sleep/Wake

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSleeping = true
            self?.sleepStart = Date()
            self?.log("System going to sleep")
        }

        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let start = self.sleepStart else { return }
            let sleepDuration = Date().timeIntervalSince(start)
            self.accumulatedSleepTime += sleepDuration
            self.isSleeping = false
            self.sleepStart = nil
            self.log("System woke up — slept for \(sleepDuration.formattedDuration), total accumulated sleep: \(self.accumulatedSleepTime.formattedDuration)")
        }
    }

    // MARK: - Inactivity Calculation

    /// Returns how long since last activity, excluding sleep time
    var inactivityDuration: TimeInterval {
        let rawInactivity = Date().timeIntervalSince(lastActivityDate)
        return max(rawInactivity - accumulatedSleepTime, 0)
    }

    /// Reset accumulated sleep time (called when activity is detected)
    func resetSleepAccumulation() {
        accumulatedSleepTime = 0
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [ActivityMonitor] \(message)"
        print(entry)

        let logFile = WellnessManager.logFilePath()
        if let data = (entry + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
}

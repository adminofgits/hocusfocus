import AppKit
import Darwin
import ApplicationServices
import HocusFocusCore
import HocusFocusBrand
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var controller: FocusController!
    private let popover = NSPopover()
    private let model = DashboardModel()
    private let loginItem = LoginItemController()
    private let accessibilityPermission = AccessibilityPermission()
    private var loadedSource: String?
    private var configError: String?
    private var globalClickMonitor: Any?
    private var localEventMonitor: Any?
    private var terminationSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGTERM, SIG_IGN)
        let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termination.setEventHandler { [weak self] in
            self?.closePanel()
            NSApp.terminate(nil)
        }
        termination.resume()
        terminationSignal = termination
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = BrandArtwork.appIcon()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = BrandArtwork.mark(size: 20)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: DashboardView(model: model, loginItem: loginItem))
        controller = FocusController(config: Configuration())
        controller.isConfigurationOpen = { [weak self] in self?.popover.isShown ?? false }
        controller.onPermissionChange = { [weak self] _ in self?.updateStatus() }
        controller.onFocusFailure = { [weak self] message in self?.model.message = message }
        model.onSave = { [weak self] config in self?.save(config) }
        model.onToggle = { [weak self] enabled in
            guard let self, self.configError == nil else { return }
            self.controller.enabled = enabled
            self.updateStatus()
        }
        model.onReload = { [weak self] in self?.reload() }
        model.onEdit = { NSWorkspace.shared.open(ConfigLocation.url) }
        model.onPermissions = { [weak self] in
            self?.accessibilityPermission.request(showSettings: true)
        }
        model.onQuit = { [weak self] in
            self?.closePanel()
            NSApp.terminate(nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleControl(_:)),
            name: NSNotification.Name(AppControl.requestNotification), object: AppControl.bundleID
        )
        do {
            try FileManager.default.createDirectory(at: ConfigLocation.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: ConfigLocation.url.path) {
                try Data(Configuration.defaultTOML.utf8).write(to: ConfigLocation.url, options: .withoutOverwriting)
            }
            try load()
        } catch {
            configError = error.localizedDescription
            model.message = "Configuration error: \(error.localizedDescription)"
            controller.enabled = false
        }
        controller.start()
        updateStatus()
        DispatchQueue.main.async { [weak self] in
            self?.accessibilityPermission.request()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        loginItem.refresh()
    }

    @objc private func togglePanel() {
        if popover.isShown { closePanel(); return }
        guard let button = statusItem.button else { return }
        controller.reset()
        updateStatus()
        model.refreshApps()
        loginItem.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        monitorPanelDismissal()
    }

    private func monitorPanelDismissal() {
        removePanelMonitors()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            self?.closePanel()
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks.union(.keyDown)) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.closePanel(); return nil }
                return event
            }
            let panelWindow = self.popover.contentViewController?.view.window
            // A menu opened by the app picker has its own window. Keep it open.
            let isMenu = (event.window?.level.rawValue ?? 0) >= NSWindow.Level.popUpMenu.rawValue
            let isStatusButton = event.window === self.statusItem.button?.window
            if event.window !== panelWindow && !isMenu && !isStatusButton { self.closePanel() }
            return event
        }
    }

    private func closePanel() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverWillClose(_ notification: Notification) {
        popover.contentViewController?.view.window?.makeFirstResponder(nil)
        if model.config != controller.config { save(model.config) }
    }

    func popoverDidClose(_ notification: Notification) {
        removePanelMonitors()
        controller.reset()
    }

    private func removePanelMonitors() {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        globalClickMonitor = nil
        localEventMonitor = nil
    }

    private func load() throws {
        let source = try String(contentsOf: ConfigLocation.url, encoding: .utf8)
        controller.config = try Configuration.parse(source)
        controller.reset()
        model.config = controller.config
        loadedSource = source
    }

    private func reload() {
        do {
            let recovering = configError != nil
            try load()
            configError = nil
            model.message = nil
            if recovering { controller.enabled = true }
            updateStatus()
        } catch {
            model.message = "Reload failed. Previous settings remain active. \(error.localizedDescription)"
        }
    }

    private func save(_ config: Configuration) {
        do {
            let onDisk = try String(contentsOf: ConfigLocation.url, encoding: .utf8)
            guard onDisk == loadedSource else {
                throw ConfigError.invalid("The TOML file changed on disk. Reload before saving panel changes.")
            }
            let source = try config.toml()
            let validated = try Configuration.parse(source)
            try source.write(to: ConfigLocation.url, atomically: true, encoding: .utf8)
            loadedSource = source
            controller.config = validated
            controller.reset()
            configError = nil
            model.message = nil
            updateStatus()
        } catch {
            model.config = controller.config
            model.message = "Could not save: \(error.localizedDescription)"
        }
    }

    private func updateStatus() {
        if !popover.isShown { model.config = controller.config }
        model.enabled = controller.enabled
        model.trusted = AXIsProcessTrusted()
        model.configValid = configError == nil
        let state = configError != nil ? "Configuration error" : !model.trusted ? "Accessibility permission needed" : model.enabled ? "Active · \(controller.config.focus.delayMS) ms" : "Paused"
        statusItem.button?.appearsDisabled = !model.enabled || !model.trusted
        statusItem.button?.toolTip = "HocusFocus: \(state)"
    }

    @objc private func handleControl(_ notification: Notification) {
        guard let requestID = notification.userInfo?["id"] as? String,
              let command = notification.userInfo?["command"] as? String else { return }
        var requestError: String?
        switch command {
        case "pause": controller.enabled = false
        case "resume":
            if configError == nil { controller.enabled = true } else { requestError = configError }
        case "reload":
            do {
                let recovering = configError != nil
                try load()
                configError = nil
                model.message = nil
                if recovering { controller.enabled = true }
            } catch { requestError = error.localizedDescription }
        case "stop": closePanel()
        case "status": break
        default: requestError = "Unknown control command: \(command)"
        }
        updateStatus()
        let status = RuntimeStatus(
            running: true, enabled: controller.enabled, accessibility: AXIsProcessTrusted(),
            delayMS: controller.config.focus.delayMS, configPath: ConfigLocation.url.path,
            error: requestError ?? configError, processID: ProcessInfo.processInfo.processIdentifier,
            focusState: controller.diagnosticState
        )
        guard let data = try? JSONEncoder().encode(status), let payload = String(data: data, encoding: .utf8) else { return }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(AppControl.responseNotification), object: requestID,
            userInfo: ["payload": payload], deliverImmediately: true
        )
        if command == "stop" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSApp.terminate(nil) }
        }
    }
}

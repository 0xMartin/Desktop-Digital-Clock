import SwiftUI
import ServiceManagement
import os

@main
struct DigitalClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            // Hlavní okno s hodinami, které funguje jako widget na pozadí.
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}



// Třída pro správu událostí aplikace, jako je spuštění,
// a pro vytváření prvků UI, které nejsou přímo součástí SwiftUI (např. NSStatusItem).
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "General")
    
    // Vlastnosti pro správné nastavení hlavního "widget" okna
    private var windowSetupTimer: Timer?
    private var windowSetupAttempts = 0
    private let maxSetupAttempts = 30
    private var forceWindowCreationQueued = false
    
    // Vlastnosti pro ikonu a menu v horní liště
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    //--- Metody životního cyklu ---

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Spustí registraci pro automatické spuštění po přihlášení
        registerAppForLogin()
        
        // Nastaví hlavní okno s hodinami na pozadí
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.windowSetupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.setupWindowIfAvailable()
            }
        }
        
        // Vytvoří ikonu a menu v horní liště
        setupMenuBarIcon()
    }
    
    //--- Správa Menu Baru ---
    
    private func setupMenuBarIcon() {
        // Vytvoříme status item (ikonu) v systémové liště
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Clock Settings")
            
            // Vytvoříme menu, které se zobrazí po kliknutí
            let menu = NSMenu()
            
            // Položka pro otevření nastavení
            menu.addItem(
                withTitle: "Settings...",
                action: #selector(showSettingsWindow),
                keyEquivalent: ","
            )
            
            menu.addItem(NSMenuItem.separator())
            
            // Položka pro ukončení aplikace
            menu.addItem(
                withTitle: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
            
            // Připojíme menu k naší ikoně
            statusItem?.menu = menu
        }
    }
    
    @objc private func showSettingsWindow() {
        // Pokud okno s nastavením ještě neexistuje, vytvoříme ho
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.level = .floating // Zobrazí se nad ostatními okny
            
            window.identifier = NSUserInterfaceItemIdentifier("settingsWindow")
            
            self.settingsWindow = window
        }
        
        // Zobrazíme okno a přesuneme ho do popředí
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    //--- Správa hlavního okna (widgetu) ---
    
    private func setupWindowIfAvailable() {
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue != "settingsWindow" }) {
            configureWindow(window)
            return
        }
        
        windowSetupAttempts += 1
        logger.info("Window not found during setup, attempt \(self.windowSetupAttempts)/\(self.maxSetupAttempts)")
        
        if windowSetupAttempts >= self.maxSetupAttempts && !forceWindowCreationQueued {
            forceWindowCreationQueued = true
            logger.warning("Trying to force window creation after 30 attempts")
            forceCreateWindow()
        }
        
        if windowSetupAttempts >= maxSetupAttempts {
            logger.error("Gave up setting up window after \(self.maxSetupAttempts) attempts.")
            windowSetupTimer?.invalidate()
            windowSetupTimer = nil
        }
    }
    
    private func forceCreateWindow() {
        logger.info("Forcing window creation and app activation")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if NSApplication.shared.windows.isEmpty {
                let window = NSWindow(
                    contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.contentView = NSHostingView(rootView: ContentView())
                window.makeKeyAndOrderFront(nil)
                self.configureWindow(window)
                self.logger.info("Successfully created and configured a new window.")
            } else if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue != "settingsWindow" }) {
                self.configureWindow(window)
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        logger.info("Configuring window properties.")
        window.setFrame(NSScreen.main?.frame ?? .zero, display: true)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable])
        window.hasShadow = false
        
        windowSetupTimer?.invalidate()
        windowSetupTimer = nil
        logger.info("Window setup completed successfully.")
    }
    
    private func registerAppForLogin() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                logger.info("Application successfully registered for login.")
            } catch {
                logger.error("Error registering application for login: \(error.localizedDescription)")
            }
        } else {
            let bundleIdentifier = Bundle.main.bundleIdentifier!
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                logger.info("Application successfully registered for login (older method).")
            } else {
                logger.error("Error registering application for login (older method).")
            }
        }
    }
}

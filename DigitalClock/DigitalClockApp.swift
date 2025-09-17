import SwiftUI
import ServiceManagement
import os

@main
struct DigitalClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "General")
    private var windowSetupTimer: Timer?
    private var windowSetupAttempts = 0
    private let maxSetupAttempts = 30
    private var forceWindowCreationQueued = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerAppForLogin()
        
        // Počkáme 1 sekundu před prvním pokusem o nastavení okna
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.windowSetupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.setupWindowIfAvailable()
            }
        }
    }
    
    private func setupWindowIfAvailable() {
        // Zkusíme získat okno normální cestou
        if let window = NSApplication.shared.windows.first {
            configureWindow(window)
            return
        }
        
        windowSetupAttempts += 1
        logger.info("Window not found during setup, attempt \(self.windowSetupAttempts)/\(self.maxSetupAttempts)")
        
        // Po 30 pokusech se pokusíme vynutit vytvoření okna, pokud jsme to ještě neudělali
        if windowSetupAttempts >= self.maxSetupAttempts && !forceWindowCreationQueued {
            forceWindowCreationQueued = true
            logger.warning("Trying to force window creation after 30 attempts")
            forceCreateWindow()
        }
        
        // Po dosažení maximálního počtu pokusů přestaneme zkoušet
        if windowSetupAttempts >= maxSetupAttempts {
            logger.error("Gave up setting up window after \(self.maxSetupAttempts) attempts.")
            windowSetupTimer?.invalidate()
            windowSetupTimer = nil
        }
    }
    
    private func forceCreateWindow() {
        logger.info("Forcing window creation and app activation")
        
        // Vynucené aktivování aplikace a vytvoření okna
        DispatchQueue.main.async {
            // Pokusíme se aktivovat aplikaci
            NSApp.activate(ignoringOtherApps: true)
            
            // Explicitně vytvoříme nové okno, pokud neexistuje žádné
            if NSApplication.shared.windows.isEmpty {
                let window = NSWindow(
                    contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                
                window.contentView = NSHostingView(rootView: ContentView())
                window.makeKeyAndOrderFront(nil)
                
                // Nakonfigurujeme nové okno
                self.configureWindow(window)
                
                self.logger.info("Successfully created and configured a new window.")
            } else if let window = NSApplication.shared.windows.first {
                // Pokud se okno mezitím objevilo, nakonfigurujeme ho
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
        
        // Úspěšně jsme nastavili okno, zastavíme timer
        windowSetupTimer?.invalidate()
        windowSetupTimer = nil
        
        logger.info("Window setup completed successfully.")
    }
    
    private func registerAppForLogin() {
        // Opravená kontrola dostupnosti API - macOS 13 (Ventura) a novější
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                logger.info("Application successfully registered for login.")
            } catch {
                logger.error("Error registering application for login: \(error.localizedDescription)")
            }
        } else {
            // Záloha pro starší systémy
            let bundleIdentifier = Bundle.main.bundleIdentifier!
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                logger.info("Application successfully registered for login (older method).")
            } else {
                logger.error("Error registering application for login (older method).")
            }
        }
    }
}

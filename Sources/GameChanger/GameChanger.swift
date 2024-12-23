//
//  LaunchMan.swift
//  Created by Todd Bruss on 3/17/24.
//

import SwiftUI
import AppKit
import GameController
import Carbon.HIToolbox

// Configuration settings
private struct AppConfig {
    static let enableScreenshots = false  // Set to true to enable screenshots
    static let mouseSensitivity: CGFloat = 100.0  // Added mouse sensitivity setting
    
    // Title font sizes
    struct TitleFont {
        static let fontName = "Avenir Next Medium"
        static let size720p: CGFloat = 18.0
        static let size1080p: CGFloat = 42.0
        static let size1440p: CGFloat = 56.0
    }
    
    // Label font sizes (for icon labels)
    struct LabelFont {
        static let fontName = "Avenir Next"
        static let size720p: CGFloat = 12.0
        static let size1080p: CGFloat = 22.0
        static let size1440p: CGFloat = 30.0
    }
    
    // Clock font sizes
    struct ClockFont {
        static let fontName = "Avenir Next Medium"
        static let time720p: CGFloat = 24.0
        static let time1080p: CGFloat = 42.0
        static let time1440p: CGFloat = 56.0
        
        static let date720p: CGFloat = 10.0
        static let date1080p: CGFloat = 18.0
        static let date1440p: CGFloat = 24.0
    }
    
    // Mouse indicator settings
    struct MouseIndicator {
        static let inactivityTimeout: TimeInterval = 5.0  // Reset after 10 seconds
        static let size: CGFloat = 64.0
        static let strokeWidth: CGFloat = 3.0
        static let backgroundColor = Color.gray.opacity(0.2)
        static let progressColor = Color.green.opacity(0.8)
    }
    
    // Navigation Dots settings
    struct NavigationDots {
        static let fontName = "Avenir Next"
        static let size720p: CGFloat = 8.0
        static let size1080p: CGFloat = 12.0
        static let size1440p: CGFloat = 16.0
        static let spacing720p: CGFloat = 16.0
        static let spacing1080p: CGFloat = 24.0
        static let spacing1440p: CGFloat = 32.0
        static let opacity: CGFloat = 0.3
        static let bottomPadding720p: CGFloat = 20.0
        static let bottomPadding1080p: CGFloat = 40.0
        static let bottomPadding1440p: CGFloat = 60.0
    }
    
    static func getFont(size: CGFloat) -> Font {
        if let _ = NSFont(name: LabelFont.fontName, size: size) {
            return Font.custom(LabelFont.fontName, size: size)
        }
        return Font.system(size: size, design: .default)
    }
    
    static func getTitleFont(size: CGFloat) -> Font {
        if let _ = NSFont(name: TitleFont.fontName, size: size) {
            return Font.custom(TitleFont.fontName, size: size)
        }
        return Font.system(size: size, design: .default)
    }
}

// Types needed for items
enum Section: String {
    case box = "Game Changer"
    case arcade = "Arcade"
    case console = "Console"
    case system = "System"
    case computer = "Computer"
    case internet = "Internet"
}

enum Action: String, Codable {
    case none = ""
    case restart = "restart"
    case sleep = "sleep"
    case logout = "logout"
    case quit = "quit"
    
    func execute() {
        print("Executing action: \(self)")  // Debug print
        switch self {
        case .none:
            return
        case .restart:
            SystemActions.sendAppleEvent(kAERestart)
        case .sleep:
            SystemActions.sendAppleEvent(kAESleep)
        case .logout:
            SystemActions.sendAppleEvent(kAELogOut)
        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct SystemActions {
    static func sendAppleEvent(_ eventID: UInt32) {
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kSystemProcess))
        let target = NSAppleEventDescriptor(
            descriptorType: typeProcessSerialNumber,
            bytes: &psn,
            length: MemoryLayout.size(ofValue: psn)
        )
        
        let event = NSAppleEventDescriptor(
            eventClass: kCoreEventClass,
            eventID: eventID,
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        
        _ = try? event.sendEvent(
            options: [.noReply],
            timeout: TimeInterval(kAEDefaultTimeout)
        )
    }
}

struct AppItem: Codable {
    let name: String
    let systemIcon: String
    let parent: String?
    let action: String?
    
    var sectionEnum: Section {
        return Section(rawValue: name) ?? .box
    }
    
    var parentEnum: Section? {
        guard let parent = parent else { return nil }
        return Section(rawValue: parent)
    }
    
    var actionEnum: Action {
        guard let action = action else { return .none }
        print("Converting action string: \(action)")
        let actionEnum = Action(rawValue: action)
        print("Converted to enum: \(String(describing: actionEnum))")
        return actionEnum ?? .none
    }
}

// Add a new struct to manage app items
struct AppItemManager {
    static let shared = AppItemManager()
    private var items: [String: [AppItem]] = [:]
    
    private init() {
        loadItems()
    }
    
    private mutating func loadItems() {
        print("=== DEBUG JSON LOADING ===")
        print("Bundle URL:", Bundle.main.bundleURL)
        print("All Bundle Resources:", Bundle.main.paths(forResourcesOfType: nil, inDirectory: nil))
        
        if let url = Bundle.main.url(forResource: "app_items", withExtension: "json") {
            print("Found JSON at:", url)
            do {
                let data = try Data(contentsOf: url)
                print("JSON Content:", String(data: data, encoding: .utf8) ?? "Could not read JSON content")
                self.items = try JSONDecoder().decode([String: [AppItem]].self, from: data)
                print("Successfully loaded sections:", self.items.keys)
                print("Items in Game Changer section:", self.items["Game Changer"]?.count ?? 0)
            } catch {
                print("Error loading/decoding JSON:", error)
                print("Error description:", error.localizedDescription)
            }
        } else {
            print("Failed to find app_items.json in bundle")
        }
        print("=== END DEBUG ===")
    }
    
    func getItems(for section: String) -> [AppItem] {
        let items = items[section] ?? []
        print("Getting items for section:", section)
        print("Found items count:", items.count)
        return items
    }
}

extension Notification.Name {
    static let escKeyPressed = Notification.Name("escKeyPressed")
}

@main
struct GameChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                BackgroundView()
                
                VStack {
                    ClockView()
                    Spacer()
                }
                
                MainWindowView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BackgroundView: View {
    @State private var sizing: CarouselSizing = SizingGuide.getSizing(for: NSScreen.main!.frame.size)
    
    private var logoSize: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.TitleFont.size1440p * 6.8
        } else if screenWidth >= 1920 {
            return AppConfig.TitleFont.size1080p * 6.8
        } else {
            return AppConfig.TitleFont.size720p * 6.8
        }
    }
    
    var body: some View {
        ZStack {

            // Background image and gradient
            GeometryReader { geometry in
                Group {
                    if let backgroundURL = Bundle.main.url(forResource: "backgroundimage", withExtension: "jpg", subdirectory: "images/jpg"),
                       let backgroundImage = NSImage(contentsOf: backgroundURL) {
                        Image(nsImage: backgroundImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        Color.black
                    }
                }
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .edgesIgnoringSafeArea(.all)
            
             // Logo
            if let logoURL = Bundle.main.url(forResource: "superbox64headerlogo", withExtension: "svg", subdirectory: "images/logo"),
               let logoImage = NSImage(contentsOf: logoURL) {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize)
                    .padding(.leading, 30)
                    .padding(.top, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct MainWindowView: View {
    var body: some View {
        ContentView()
    }
}

// Add at top level
class AppState: ObservableObject {
    static let shared = AppState()
    @Published var isLoaded = false
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var cursorHideTimer: Timer?
    @StateObject private var appState = AppState.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Preload images first
        preloadAllImages()
        
        // Mark as loaded after preloading
        DispatchQueue.main.async {
            AppState.shared.isLoaded = true
        }
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard self != nil else { return event }
        
        if event.keyCode == 53 { // ESC key
            NotificationCenter.default.post(name: .escKeyPressed, object: nil)
            return nil
        }
        
        return event
    }

        // Hide cursor and start timer to keep it hidden
        NSCursor.hide()
        cursorHideTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            NSCursor.hide()
        }
        
        // Set up menu bar
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // Add App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Add Quit item
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitMenuItem)
        
    let presOptions: NSApplication.PresentationOptions = [.hideDock]
    NSApp.presentationOptions = presOptions

        // Make window full screen
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.title = ""
                window.toggleFullScreen(nil)
                
                // Take screenshot after a short delay to ensure UI is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.takeScreenshot()
                }
            }
        }
    }
    
    private func preloadAllImages() {
        print("=== DEBUG IMAGE LOADING ===")
        print("Bundle URL:", Bundle.main.bundleURL)
        print("SVG Directory exists:", Bundle.main.url(forResource: nil, withExtension: nil, subdirectory: "images/svg") != nil)
        
        // Preload all sections
        let superboxItems = AppItemManager.shared.getItems(for: "Game Changer")
        print("Game Changer items:", superboxItems.map { $0.name })
        ImageCache.shared.preloadImages(from: superboxItems)
        
        let arcadeItems = AppItemManager.shared.getItems(for: "Arcade")
        print("Arcade items:", arcadeItems.map { $0.name })
        ImageCache.shared.preloadImages(from: arcadeItems)
        
        let consoleItems = AppItemManager.shared.getItems(for: "Console")
        ImageCache.shared.preloadImages(from: consoleItems)
        
        let systemItems = AppItemManager.shared.getItems(for: "System")
        ImageCache.shared.preloadImages(from: systemItems)
        
        print("=== END IMAGE LOADING ===")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cursorHideTimer?.invalidate()
        NSCursor.unhide()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func takeScreenshot() {
        guard AppConfig.enableScreenshots else { return }
        
        if let window = NSApp.windows.first,
           let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.boundsIgnoreFraming]
           ) {
            let image = NSImage(cgImage: cgImage, size: window.frame.size)
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = dateFormatter.string(from: Date())
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let fileURL = desktopURL.appendingPathComponent("GameChanger_\(timestamp).png")
                
                try? pngData.write(to: fileURL)
                print("Screenshot saved to: \(fileURL.path)")
            }
        }
    }
}

struct InterfaceSizing: Codable {
    let carousel: CarouselSizing
    let mouseIndicator: MouseIndicatorSettings
}

struct CarouselSizing: Codable {
    let iconSize: CGFloat
    let iconPadding: CGFloat
    let cornerRadius: CGFloat
    let gridSpacing: CGFloat
    let titleSize: CGFloat
    let labelSize: CGFloat
    let selectionPadding: CGFloat
}

struct GUISettings: Codable {
    let GameChangerUI: [String: InterfaceSizing]
}

struct SizingGuide {
    static private var settings: GUISettings?
    
    static func loadSettings() {
        if let url = Bundle.main.url(forResource: "gamechanger-ui", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            settings = try? JSONDecoder().decode(GUISettings.self, from: data)
        }
    }
    
    static func getSizing(for screenSize: CGSize) -> CarouselSizing {
        let resolution = getResolutionKey(for: screenSize)
        return settings?.GameChangerUI[resolution]?.carousel ?? getDefaultCarouselSizing()
    }
    
    static func getSettings(for resolution: String) -> InterfaceSizing? {
        return settings?.GameChangerUI[resolution]
    }
    
    private static func getResolutionKey(for screenSize: CGSize) -> String {
        if screenSize.width >= 2560 {
            return "2560x1440"
        } else if screenSize.width >= 1920 {
            return "1920x1080"
        }
        return "1280x720"
    }
    
    private static func getDefaultCarouselSizing() -> CarouselSizing {
        return CarouselSizing(
            iconSize: 96,
            iconPadding: 48,
            cornerRadius: 30,
            gridSpacing: 30,
            titleSize: 45,
            labelSize: 30,
            selectionPadding: 30
        )
    }
}

// Add this at the top level
class ImageCache {
    static let shared = ImageCache()
    private var cache: [String: NSImage] = [:]
    
    func preloadImages(from items: [AppItem]) {
        print("Preloading images for items:", items.map { $0.name })
        for item in items {
            if let iconURL = Bundle.main.url(forResource: item.systemIcon, withExtension: "svg", subdirectory: "images/svg") {
                print("Found icon URL for \(item.name): \(iconURL)")
                if let image = NSImage(contentsOf: iconURL) {
                    cache[item.systemIcon] = image
                    print("Successfully cached image for \(item.name)")
                } else {
                    print("Failed to load image for \(item.name)")
                }
            } else {
                print("Failed to find icon URL for \(item.name) with systemIcon: \(item.systemIcon)")
            }
        }
    }
    
    func getImage(named: String) -> NSImage? {
        let image = cache[named]
        print("Getting image for \(named): \(image != nil ? "found" : "not found")")
        return image
    }
}

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    @State private var gameController: GCController?
    @State private var accumulatedMouseX: CGFloat = 0
    @State private var accumulatedMouseY: CGFloat = 0
    @State private var isMouseInWindow = false
    @State private var sizing: CarouselSizing = SizingGuide.getSizing(for: NSScreen.main!.frame.size)
    @State private var currentPage = 0
    @State private var currentSlideOffset: CGFloat = 0
    @State private var nextSlideOffset: CGFloat = 0
    @State private var showingNextSet = false
    @State private var windowWidth: CGFloat = 0
    @State private var animationDirection: Int = 0  // -1 for left, 1 for right
    @State private var isTransitioning = false
    @State private var opacity: Double = 1
    @State private var titleOpacity: Double = 1
    @State private var currentSection: String = "Game Changer"
    @State private var mouseProgress: CGFloat = 0
    @State private var mouseDirection: Int = 0
    @State private var showingProgress = false
    @State private var mouseTimer: Timer?
    
    private var visibleItems: [AppItem] {
        let sourceItems = getSourceItems()
        let startIndex = currentPage * 4
        
        // Add bounds checking
        guard startIndex >= 0 && startIndex < sourceItems.count else {
            return []
        }
        
        let endIndex = min(startIndex + 4, sourceItems.count)
        return Array(sourceItems[startIndex..<endIndex])
    }
    
    private var numberOfPages: Int {
        let sourceItems = getSourceItems()
        return (sourceItems.count + 3) / 4
    }
    
    private var normalizedMouseProgress: CGFloat {
        min(abs(accumulatedMouseX) / AppConfig.mouseSensitivity, 1.0)
    }
    
    private func handleSelection() {
        let sourceItems = getSourceItems()
        let visibleStartIndex = currentPage * 4
        let actualIndex = visibleStartIndex + selectedIndex
        let selectedItem = sourceItems[actualIndex]
        
        // Debug print
        print("Selected item: \(selectedItem.name)")
        print("Action: \(String(describing: selectedItem.action))")
        print("Action enum: \(selectedItem.actionEnum)")
        
        // Handle system actions
        if selectedItem.actionEnum != .none {
            print("Executing action: \(selectedItem.actionEnum)")
            selectedItem.actionEnum.execute()
            return
        }
        
        // Only navigate if there's both a parent section AND items to navigate to
        if let parentSection = selectedItem.parent, 
           !AppItemManager.shared.getItems(for: selectedItem.name).isEmpty {
            // Fade out
            print("parentSection: \(parentSection)")
            withAnimation(slideAnimation) {
                opacity = 0
                titleOpacity = 0
            }
            
            // Wait for fade out, then change section and fade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                // Handle navigation
                selectedIndex = 0
                currentPage = 0
                showingNextSet = false
                currentSlideOffset = 0
                nextSlideOffset = 0
                animationDirection = 0
                currentSection = selectedItem.sectionEnum.rawValue
                
                // Fade in
                withAnimation(slideAnimation) {
                    opacity = 1
                    titleOpacity = 1
                }
            }
        }
        // Do nothing if there's no navigation possible
    }
    
    private let slideAnimation = Animation.timingCurve(0.1, 0.3, 0.3, 1, duration: 0.5)  // More gradual curve
    
    private func resetMouseState() {
        mouseTimer?.invalidate()
        mouseTimer = nil
        accumulatedMouseX = 0
        mouseProgress = 0
        mouseDirection = 0
        showingProgress = false
    }
    
    // Update keyboard handling
    private var keyboardHandler: some View {
        Color.clear
            .focusable()
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    switch Int(event.keyCode) {
                    case kVK_LeftArrow:
                        resetMouseState()
                        moveLeft()
                    case kVK_RightArrow:
                        resetMouseState()
                        moveRight()
                    case kVK_UpArrow:
                        resetMouseState()
                        moveUp()
                    case kVK_DownArrow:
                        resetMouseState()
                        moveDown()
                    case kVK_Return:
                        resetMouseState()
                        handleSelection()
                    case kVK_Escape:
                        resetMouseState()
                        back()
                    default:
                        break
                    }
                    return event
                }
            }
    }
    
    private var titleFontSize: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.TitleFont.size1440p
        } else if screenWidth >= 1920 {
            return AppConfig.TitleFont.size1080p
        } else {
            return AppConfig.TitleFont.size720p
        }
    }
    
    var body: some View {
        Group {
            if appState.isLoaded {
                ZStack {  // Main container
                    // Background and animated content
                    ZStack {
                        VStack(spacing: 0) {
                            Text(currentSection)
                                .font(.custom(AppConfig.TitleFont.fontName, size: titleFontSize))
                                .padding(.top)
                                .padding(.bottom, titleFontSize * 1.5)
                                .foregroundColor(.white)
                                .opacity(titleOpacity)
                                .onReceive(NotificationCenter.default.publisher(for: .escKeyPressed)) { _ in
                                    back()
                                }
                            
                            // Grid content
                            ZStack {
                                // Current set
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: sizing.gridSpacing),
                                    GridItem(.flexible(), spacing: sizing.gridSpacing),
                                    GridItem(.flexible(), spacing: sizing.gridSpacing),
                                    GridItem(.flexible(), spacing: sizing.gridSpacing)
                                ], spacing: sizing.gridSpacing) {
                                    ForEach(0..<visibleItems.count, id: \.self) { index in
                                        AppIconView(
                                            item: visibleItems[index],
                                            isSelected: index == selectedIndex,
                                            sizing: sizing
                                        )
                                        .onTapGesture {
                                            selectedIndex = index
                                            handleSelection()
                                        }
                                    }
                                }
                                .offset(x: currentSlideOffset)
                                .opacity(opacity)
                                
                                // Next set
                                if showingNextSet {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(), spacing: sizing.gridSpacing),
                                        GridItem(.flexible(), spacing: sizing.gridSpacing),
                                        GridItem(.flexible(), spacing: sizing.gridSpacing),
                                        GridItem(.flexible(), spacing: sizing.gridSpacing)
                                    ], spacing: sizing.gridSpacing) {
                                        let nextPage = currentPage + animationDirection
                                        let startIndex = nextPage * 4
                                        let sourceItems = getSourceItems()
                                        if nextPage >= 0 && startIndex < sourceItems.count {
                                            let endIndex = min(startIndex + 4, sourceItems.count)
                                            if startIndex < endIndex {
                                                let nextItems = Array(sourceItems[startIndex..<endIndex])
                                                ForEach(0..<nextItems.count, id: \.self) { index in
                                                    AppIconView(
                                                        item: nextItems[index],
                                                        isSelected: false,
                                                        sizing: sizing
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    .offset(x: nextSlideOffset)
                                    .opacity(opacity)
                                }
                            }
                            .padding(sizing.gridSpacing)
                            .padding(.bottom, sizing.gridSpacing * 4)
                            
                            // Add Navigation Dots here
                            NavigationDotsView(currentPage: currentPage, totalPages: numberOfPages)
                                .opacity(titleOpacity)  // Fade with title
                        }
                    }
                    
                    // Mouse progress indicator
                    if showingProgress {
                        MouseProgressView(progress: normalizedMouseProgress, direction: mouseDirection)
                    }
                }
                
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    setupKeyMonitor()
                    setupGameController()
                    setupMouseMonitor()
                    setupMouseTrackingMonitor()
                    if let screen = NSScreen.main {
                        sizing = SizingGuide.getSizing(for: screen.frame.size)
                        windowWidth = screen.frame.width
                    }
                }
                .onDisappear {
                    if let monitor = keyMonitor {
                        NSEvent.removeMonitor(monitor)
                    }
                    if let monitor = mouseMonitor {
                        NSEvent.removeMonitor(monitor)
                    }
                    NotificationCenter.default.removeObserver(self)
                    NSCursor.unhide()  // Make sure cursor is visible when view disappears
                }
            }
        }
    }
    
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53: // Escape
                resetMouseState()
                back()
            case 126: // Up Arrow
                resetMouseState()
                back()
            case 125: // Down Arrow
                resetMouseState()
                handleSelection()
            case 123: // Left Arrow
                resetMouseState()
                moveLeft()
            case 124: // Right Arrow
                resetMouseState()
                moveRight()
            case 36: // Return
                resetMouseState()
                handleSelection()
            case 49: // Space
                resetMouseState()
                handleSelection()
            default: break
            }
            return event
        }
    }
    
    private func setupGameController() {
        // Watch for controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main) { notification in
                if let controller = notification.object as? GCController {
                    connectController(controller)
                }
        }
        
        // Watch for controller disconnections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main) { _ in
                gameController = nil
        }
        
        // Connect to any already-connected controller
        if let controller = GCController.controllers().first {
            connectController(controller)
        }
    }
    
    private func connectController(_ controller: GCController) {
        gameController = controller
        
        if let gamepad = controller.extendedGamepad {
            // D-pad
            gamepad.dpad.valueChangedHandler = { (_, xValue, yValue) in
                DispatchQueue.main.async {
                    resetMouseState()
                    if yValue == 1 {  // Up
                        back()
                    } else if yValue == -1 {  // Down
                        self.handleSelection()
                    }
                    
                    if xValue == -1 {  // Left
                        self.moveLeft()
                    } else if xValue == 1 {  // Right
                        self.moveRight()
                    }
                }
            }
            
            // Face buttons
            gamepad.buttonA.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.handleSelection()
                    }
                }
            }
            
            gamepad.buttonB.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.moveRight()
                    }
                }
            }
            
            gamepad.buttonX.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.moveLeft()
                    }
                }
            }
            
            gamepad.buttonY.valueChangedHandler = { (_, _, pressed) in
                if pressed {
                    DispatchQueue.main.async {
                        resetMouseState()
                        self.back()
                    }
                }
            }
        }
    }
    
    private func setupMouseMonitor() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            let deltaX = event.deltaX
            
            // Reset and restart inactivity timer
            mouseTimer?.invalidate()
            mouseTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.MouseIndicator.inactivityTimeout, 
                                           repeats: false) { _ in
                self.resetMouseState()
            }
            
            // Check for direction change
            if deltaX != 0 {
                let newDirection = deltaX < 0 ? -1 : 1
                
                if newDirection != mouseDirection {
                    accumulatedMouseX = 0
                    mouseProgress = 0
                    showingProgress = true
                }
                
                mouseDirection = newDirection
            }
            
            accumulatedMouseX += deltaX
            accumulatedMouseY += event.deltaY
            
            mouseProgress = normalizedMouseProgress
            
            if abs(accumulatedMouseX) > AppConfig.mouseSensitivity {
                if accumulatedMouseX < 0 {
                    moveLeft()
                } else {
                    moveRight()
                }
                accumulatedMouseX = 0
                mouseDirection = 0
                mouseProgress = 0
                showingProgress = false
            }
            
            return event
        }
        
        // Add mouse button monitoring
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if let window = NSApp.windows.first {
                let location = event.locationInWindow
                let windowHeight = window.frame.height
                let isUpperHalf = location.y > windowHeight / 2
                
                if isUpperHalf {
                    back()
                } else {
                    self.handleSelection()
                }
            }
            
            return event
        }
    }
    
    private func setupMouseTrackingMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited]) { event in
            switch event.type {
            case .mouseEntered:
                isMouseInWindow = true
            case .mouseExited:
                isMouseInWindow = false
            default:
                break
            }
            return event
        }
        
        // Initial state check
        if let window = NSApp.windows.first,
           let mouseLocation = NSEvent.mouseLocation.asScreenPoint,
           window.frame.contains(mouseLocation) {
            isMouseInWindow = true
        }
    }
    
    private func enforceSelectionRules() {
        let sourceItems = getSourceItems()
        let currentVisibleCount = min(4, sourceItems.count - (currentPage * 4))
        if selectedIndex >= currentVisibleCount {
            selectedIndex = currentVisibleCount - 1
        }
    }
    
    private func moveLeft() {
        if !isTransitioning {
            let sourceItems = getSourceItems()
            
            if selectedIndex == 0 && currentPage > 0 {
                isTransitioning = true
                animationDirection = -1
                showingNextSet = true
                nextSlideOffset = -windowWidth
                
                // Calculate the number of items on the previous page
                let prevPageStart = (currentPage - 1) * 4
                let itemsOnPrevPage = min(4, sourceItems.count - prevPageStart)
                selectedIndex = itemsOnPrevPage - 1  // Select the last item on the previous page
                
                withAnimation(slideAnimation) {
                    currentSlideOffset = windowWidth
                    nextSlideOffset = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentPage = max(0, currentPage - 1)  // Ensure it doesn't go negative
                    currentSlideOffset = 0
                    showingNextSet = false
                    isTransitioning = false
                }
            } else if selectedIndex > 0 {
                selectedIndex -= 1
            }
        }
    }
    
    private func moveRight() {
        if !isTransitioning {
            let sourceItems = getSourceItems()
            let currentVisibleCount = min(4, sourceItems.count - (currentPage * 4))
            
            if selectedIndex == currentVisibleCount - 1 && currentPage < (sourceItems.count - 1) / 4 {
                isTransitioning = true
                animationDirection = 1
                showingNextSet = true
                nextSlideOffset = windowWidth
                
                selectedIndex = 0
                
                withAnimation(slideAnimation) {
                    currentSlideOffset = -windowWidth
                    nextSlideOffset = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentPage += 1
                    selectedIndex = 0
                    currentSlideOffset = 0
                    showingNextSet = false
                    isTransitioning = false
                }
            } else if selectedIndex < currentVisibleCount - 1 {
                selectedIndex += 1
            }
        }
    }
    
    private func moveUp() {
        let sourceItems = getSourceItems()
        if selectedIndex < 4 {
            let bottomRowStart = (sourceItems.count - 1) / 4 * 4
            selectedIndex = min(bottomRowStart + (selectedIndex % 4), sourceItems.count - 1)
        } else {
            selectedIndex -= 4
        }
    }
    
    private func moveDown() {
        let sourceItems = getSourceItems()
        if selectedIndex + 4 >= sourceItems.count {
            selectedIndex = selectedIndex % 4
        } else {
            selectedIndex += 4
        }
    }
    
    public func back() {
        let sourceItems = getSourceItems()
        if !sourceItems.isEmpty, let parentSection = sourceItems[0].parentEnum {
            withAnimation(slideAnimation) {
                opacity = 0
                titleOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                currentSection = parentSection.rawValue
                selectedIndex = 0
                currentPage = 0
                
                withAnimation(slideAnimation) {
                    opacity = 1
                    titleOpacity = 1
                }
            }
        }
    }
    
    private func getSourceItems() -> [AppItem] {
        return AppItemManager.shared.getItems(for: currentSection)
    }
}

// Helper extension to convert NSPoint to screen coordinates
extension NSPoint {
    var asScreenPoint: NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        return NSPoint(x: x, y: screen.frame.height - y)
    }
}

struct AppIconView: View {
    let item: AppItem
    let isSelected: Bool
    let sizing: CarouselSizing
    
    private func loadIcon() -> some View {
        if let image = ImageCache.shared.getImage(named: item.systemIcon) {
            return AnyView(Image(nsImage: image)
                .resizable()
                .frame(width: sizing.iconSize * 2, height: sizing.iconSize * 2)
                .padding(0)
                .cornerRadius(sizing.cornerRadius))
        }
        
        return AnyView(Color.clear
            .frame(width: sizing.iconSize * 2, height: sizing.iconSize * 2))
    }
    
    private var labelFontSize: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.LabelFont.size1440p
        } else if screenWidth >= 1920 {
            return AppConfig.LabelFont.size1080p
        } else {
            return AppConfig.LabelFont.size720p
        }
    }
    
    var body: some View {
        VStack(spacing: sizing.gridSpacing * 0.4) {
            ZStack {
                RoundedRectangle(cornerRadius: sizing.cornerRadius * 1.334)
                    .fill(Color.clear)
                    .frame(
                        width: sizing.iconSize * 2 + sizing.selectionPadding,
                        height: sizing.iconSize * 2 + sizing.selectionPadding
                    )
                
                if isSelected {
                    RoundedRectangle(cornerRadius: sizing.cornerRadius * 1.334)
                        .fill(Color.white.opacity(0.2))
                        .frame(
                            width: sizing.iconSize * 2 + sizing.selectionPadding,
                            height: sizing.iconSize * 2 + sizing.selectionPadding
                        )
                }
                
                loadIcon()
            }
            
            Text(item.name)
                .font(.custom(AppConfig.LabelFont.fontName, size: labelFontSize))
                .foregroundColor(isSelected ? .white : .blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClockView: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
    
    private var clockFontSize: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.ClockFont.time1440p
        } else if screenWidth >= 1920 {
            return AppConfig.ClockFont.time1080p
        } else {
            return AppConfig.ClockFont.time720p
        }
    }
    
    private var dateFontSize: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.ClockFont.date1440p
        } else if screenWidth >= 1920 {
            return AppConfig.ClockFont.date1080p
        } else {
            return AppConfig.ClockFont.date720p
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(timeFormatter.string(from: currentTime))
                .font(.custom(AppConfig.ClockFont.fontName, size: clockFontSize))
                .foregroundColor(.white)
            
            Text(dateFormatter.string(from: currentTime))
                .font(.custom(AppConfig.ClockFont.fontName, size: dateFontSize))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 30)
        .padding(.trailing, 40)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onReceive(timer) { input in
            currentTime = input
        }
    }
}

// Add these structs for decoding
struct MouseIndicatorSettings: Codable {
    let size: CGFloat
    let strokeWidth: CGFloat
    let inactivityTimeout: TimeInterval
    let backgroundColor: [CGFloat]  // [r,g,b,a]
    let progressColor: [CGFloat]    // [r,g,b,a]
    
    var backgroundColorUI: Color {
        Color(.sRGB, 
              red: Double(backgroundColor[0]),
              green: Double(backgroundColor[1]), 
              blue: Double(backgroundColor[2]), 
              opacity: Double(backgroundColor[3]))
    }
    
    var progressColorUI: Color {
        Color(.sRGB, 
              red: Double(progressColor[0]), 
              green: Double(progressColor[1]), 
              blue: Double(progressColor[2]), 
              opacity: Double(progressColor[3]))
    }
}

// Update MouseProgressView to use settings
struct MouseProgressView: View {
    let progress: CGFloat
    let direction: Int
    
    private var settings: MouseIndicatorSettings {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        let resolution = screenWidth >= 2560 ? "2560x1440" :
                        screenWidth >= 1920 ? "1920x1080" : "1280x720"
        
        return SizingGuide.getSettings(for: resolution)?.mouseIndicator ?? 
               MouseIndicatorSettings(
                   size: 64.0,
                   strokeWidth: 3.0,
                   inactivityTimeout: 5.0,
                   backgroundColor: [0.5, 0.5, 0.5, 0.2],
                   progressColor: [0.0, 1.0, 0.0, 0.8]
               )
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(settings.backgroundColorUI,
                       lineWidth: settings.strokeWidth)
                .frame(width: settings.size,
                       height: settings.size)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    settings.progressColorUI,
                    style: StrokeStyle(
                        lineWidth: settings.strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: settings.size,
                       height: settings.size)
                .rotationEffect(
                    direction == -1 ?
                        .degrees(Double(-90) - (Double(progress) * 360)) :
                        .degrees(-90)
                )
            
            // Direction indicator
            Image(systemName: direction == -1 ? "chevron.left" :
                            direction == 1 ? "chevron.right" : "")
                .font(.system(size: settings.size * 0.28, weight: .semibold))
                .foregroundColor(settings.progressColorUI)
        }
        .padding(.bottom, 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

struct NavigationDotsView: View {
    let currentPage: Int
    let totalPages: Int
    
    private var dotSize: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.NavigationDots.size1440p
        } else if screenWidth >= 1920 {
            return AppConfig.NavigationDots.size1080p
        } else {
            return AppConfig.NavigationDots.size720p
        }
    }
    
    private var dotSpacing: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.NavigationDots.spacing1440p
        } else if screenWidth >= 1920 {
            return AppConfig.NavigationDots.spacing1080p
        } else {
            return AppConfig.NavigationDots.spacing720p
        }
    }
    
    private var bottomPadding: CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1920
        if screenWidth >= 2560 {
            return AppConfig.NavigationDots.bottomPadding1440p
        } else if screenWidth >= 1920 {
            return AppConfig.NavigationDots.bottomPadding1080p
        } else {
            return AppConfig.NavigationDots.bottomPadding720p
        }
    }
    
    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(index == currentPage ? 1 : AppConfig.NavigationDots.opacity)
            }
        }
        .padding(.bottom, bottomPadding)
    }
} 
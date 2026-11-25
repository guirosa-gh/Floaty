// Floaty: a tiny draw-on-your-screen overlay for macOS.
//
// Build:  ./build.sh        (makes Floaty.app)
//   or:   swiftc -parse-as-library -O Floaty.swift -o Floaty
//
// Controls
//   Control+Option+D  toggle drawing mode on/off from anywhere
//   Esc               stop drawing (clicks pass through to your apps again)
//   P / E / T         pencil / eraser / text
//   [ / ]             smaller / bigger (pen, eraser or text size)
//   Cmd+Z             undo

import Cocoa
import Carbon.HIToolbox

// MARK: - Model

enum Tool { case pencil, eraser, text }

struct Stroke {
    var points: [CGPoint]
    var color: NSColor
    var width: CGFloat
    var isEraser: Bool
}

struct TextItem {
    var string: String
    var origin: CGPoint
    var color: NSColor
    var font: NSFont
}

enum Item {
    case stroke(Stroke)
    case text(TextItem)
}

extension Notification.Name {
    static let toggleDrawing = Notification.Name("Floaty.toggleDrawing")
}

// MARK: - Canvas (the transparent drawing surface)

final class CanvasView: NSView, NSTextFieldDelegate {
    var tool: Tool = .pencil {
        didSet { commitText(); window?.invalidateCursorRects(for: self) }
    }
    var color: NSColor = .systemRed {
        didSet {   // recolor text that's still being typed
            editor?.textColor = color
            (editor?.currentEditor() as? NSTextView)?.textColor = color
        }
    }
    var lineWidth: CGFloat = 4
    var eraserWidth: CGFloat = 28
    var fontSize: CGFloat = 24 {
        didSet { resizeEditor() }   // resize text that's still being typed
    }
    var onKeyDown: ((NSEvent) -> Bool)?
    var onItemAdded: ((CanvasView) -> Void)?   // lets the app undo across displays

    private var items: [Item] = []
    private var current: Stroke?
    private var editor: NSTextField?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: tool == .text ? .iBeam : .crosshair)
    }

    // Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        for item in items { render(item, in: ctx) }
        if let s = current { render(.stroke(s), in: ctx) }
    }

    private func render(_ item: Item, in ctx: CGContext) {
        switch item {
        case .stroke(let s):
            guard let first = s.points.first else { return }
            ctx.saveGState()
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setLineWidth(s.width)
            if s.isEraser {
                ctx.setBlendMode(.clear)          // punches a transparent hole
            } else {
                ctx.setStrokeColor(s.color.cgColor)
            }
            ctx.beginPath()
            ctx.move(to: first)
            if s.points.count == 1 {
                ctx.addLine(to: CGPoint(x: first.x + 0.1, y: first.y))  // a single dot
            } else {
                for p in s.points.dropFirst() { ctx.addLine(to: p) }
            }
            ctx.strokePath()
            ctx.restoreGState()

        case .text(let t):
            let attrs: [NSAttributedString.Key: Any] = [.font: t.font, .foregroundColor: t.color]
            (t.string as NSString).draw(at: t.origin, withAttributes: attrs)
        }
    }

    // Mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        commitText()
        switch tool {
        case .text:
            beginText(at: p)
        case .pencil, .eraser:
            let erasing = (tool == .eraser)
            current = Stroke(points: [p], color: color,
                             width: erasing ? eraserWidth : lineWidth, isEraser: erasing)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard current != nil else { return }
        current!.points.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let s = current { items.append(.stroke(s)); onItemAdded?(self) }
        current = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true { super.keyDown(with: event) }
    }

    // Text boxes

    private func beginText(at p: CGPoint) {
        NSApp.activate(ignoringOtherApps: true)   // needed so you can type
        window?.makeKey()
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let height = ceil(font.ascender - font.descender) + 6
        let field = NSTextField(frame: NSRect(x: p.x, y: p.y - height / 2, width: 240, height: height))
        field.font = font
        field.textColor = color
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.black.withAlphaComponent(0.12)
        field.focusRingType = .none
        field.placeholderString = "Type, then Return"
        field.cell?.isScrollable = true
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        editor = field
    }

    func controlTextDidChange(_ obj: Notification) {
        fitEditorWidth()
    }

    private func fitEditorWidth() {
        guard let f = editor, let font = f.font else { return }
        let w = (f.stringValue as NSString).size(withAttributes: [.font: font]).width + 30
        f.frame.size.width = max(240, w)
    }

    private func resizeEditor() {
        guard let f = editor else { return }
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let midY = f.frame.midY
        let height = ceil(font.ascender - font.descender) + 6
        f.font = font
        (f.currentEditor() as? NSTextView)?.font = font
        f.frame = NSRect(x: f.frame.minX, y: midY - height / 2, width: f.frame.width, height: height)
        fitEditorWidth()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitText()
    }

    /// Turns the live text field into permanent drawn text.
    func commitText() {
        guard let field = editor else { return }
        editor = nil
        let text = field.stringValue
        if !text.isEmpty, let font = field.font {
            // NSTextField insets its text slightly; nudge so it doesn't jump.
            let origin = CGPoint(x: field.frame.minX + 2, y: field.frame.minY + 3)
            items.append(.text(TextItem(string: text, origin: origin,
                                        color: field.textColor ?? color, font: font)))
            onItemAdded?(self)
        }
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // Actions

    func undo() {
        commitText()
        if !items.isEmpty { items.removeLast() }
        needsDisplay = true
    }

    func clearAll() {
        commitText()
        items.removeAll()
        current = nil
        needsDisplay = true
    }
}

// MARK: - Windows

/// Full-screen, transparent, always-on-top window that holds the canvas.
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless,
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Small floating toolbar that sits above the overlay. Drag it by its background.
final class ToolbarPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }
    override var canBecomeKey: Bool { true }
}

// MARK: - Toolbar look

enum Theme {
    static let bar     = NSColor(srgbRed: 0.137, green: 0.153, blue: 0.188, alpha: 1)  // #23272F
    static let footer  = NSColor(srgbRed: 0.212, green: 0.235, blue: 0.278, alpha: 1)  // #363C47
    static let well    = NSColor(srgbRed: 0.075, green: 0.082, blue: 0.102, alpha: 1)  // #13151A
    static let accent  = NSColor(srgbRed: 0.173, green: 0.443, blue: 0.965, alpha: 1)  // #2C71F6
    static let icon    = NSColor(white: 0.94, alpha: 1)
    static let muted   = NSColor(white: 1, alpha: 0.45)
    static let hover   = NSColor(white: 1, alpha: 0.08)
    static let divider = NSColor(white: 1, alpha: 0.10)
    static let width: CGFloat = 56
    static let button: CGFloat = 40
}

/// Icon button. `.accent` = filled colored square, `.well` = dark square with a colored icon.
final class ToolButton: NSButton {
    enum Style { case plain, accent, well }
    var style: Style = .plain { didSet { refresh() } }
    private var hovering = false { didSet { refresh() } }
    private let pointSize: CGFloat

    init(_ symbol: String, _ tip: String, pointSize: CGFloat = 18, height: CGFloat = Theme.button,
         target: AnyObject?, action: Selector) {
        self.pointSize = pointSize
        super.init(frame: NSRect(x: 0, y: 0, width: Theme.button, height: height))
        self.target = target
        self.action = action
        isBordered = false
        imagePosition = .imageOnly
        toolTip = tip
        setSymbol(symbol)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Theme.button).isActive = true
        heightAnchor.constraint(equalToConstant: height).isActive = true
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    func setSymbol(_ name: String) {
        let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: toolTip)?
            .withSymbolConfiguration(cfg) {
            image = img
            title = ""
        } else {
            image = nil
            title = String((toolTip ?? "?").prefix(1))
        }
    }

    private func refresh() {
        switch style {
        case .accent:
            layer?.backgroundColor = Theme.accent.cgColor
            contentTintColor = .white
        case .well:
            layer?.backgroundColor = Theme.well.cgColor
            contentTintColor = Theme.accent
        case .plain:
            layer?.backgroundColor = (hovering ? Theme.hover : .clear).cgColor
            contentTintColor = Theme.icon
        }
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent)  { hovering = false }
}

/// Round color swatch. The current color gets a white ring.
final class SwatchButton: NSButton {
    var swatchColor: NSColor = .systemRed { didSet { needsDisplay = true } }
    var isCurrent = false { didSet { needsDisplay = true } }
    private var hovering = false { didSet { needsDisplay = true } }

    init(target: AnyObject?, action: Selector) {
        super.init(frame: NSRect(x: 0, y: 0, width: Theme.button, height: 34))
        self.target = target
        self.action = action
        isBordered = false
        title = ""
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Theme.button).isActive = true
        heightAnchor.constraint(equalToConstant: 34).isActive = true
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        let d: CGFloat = 20
        let dot = NSRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)
        if isCurrent || hovering {
            let ring = NSBezierPath(ovalIn: dot.insetBy(dx: -4, dy: -4))
            ring.lineWidth = 2
            (isCurrent ? NSColor.white : NSColor(white: 1, alpha: 0.3)).setStroke()
            ring.stroke()
        }
        swatchColor.setFill()
        NSBezierPath(ovalIn: dot).fill()
        let edge = NSBezierPath(ovalIn: dot.insetBy(dx: 0.5, dy: 0.5))
        edge.lineWidth = 1
        NSColor(white: 1, alpha: 0.2).setStroke()   // keeps black visible on the dark bar
        edge.stroke()
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent)  { hovering = false }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    // One transparent overlay per display, keyed by display ID.
    private var overlays: [CGDirectDisplayID: OverlayWindow] = [:]
    private var canvases: [CanvasView] { overlays.values.compactMap { $0.contentView as? CanvasView } }
    private var undoStack: [CanvasView] = []   // which display each drawing landed on, in order

    // Current tool settings, shared by every display.
    private var tool: Tool = .pencil         { didSet { canvases.forEach { $0.tool = tool } } }
    private var color: NSColor = .systemRed  { didSet { canvases.forEach { $0.color = color } } }
    private var lineWidth: CGFloat = 4       { didSet { canvases.forEach { $0.lineWidth = lineWidth } } }
    private var eraserWidth: CGFloat = 28    { didSet { canvases.forEach { $0.eraserWidth = eraserWidth } } }
    private var fontSize: CGFloat = 24       { didSet { canvases.forEach { $0.fontSize = fontSize } } }

    private var toolbar: ToolbarPanel!
    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!
    private var modeButton: ToolButton!
    private var toolButtons: [Tool: ToolButton] = [:]
    private var swatches: [SwatchButton] = []
    private var sizeLabel: NSTextField!
    private var sizeCaption: NSTextField!
    private var hotKeyRef: EventHotKeyRef?

    // Recent colors: newest first, always exactly 3, remembered between launches.
    private static let defaultColors: [NSColor] = [.systemRed, .systemYellow, .systemBlue]
    private static let recentsKey = "recentColors"
    private var recentColors: [NSColor] = []
    private var colorPanelAddedColor = false

    private let penSizes: [CGFloat]    = [1, 2, 3, 4, 6, 8, 10, 12, 16, 20, 24]
    private let eraserSizes: [CGFloat] = [10, 16, 20, 28, 40, 56, 80]
    private let textSizes: [CGFloat]   = [12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64, 80, 96]

    private var drawingEnabled = true {
        didSet { applyMode() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.screens.first ?? NSScreen.main!   // the one with the menu bar

        NSColorPanel.shared.level = .popUpMenu   // keep the color picker above everything

        loadRecentColors()
        color = recentColors[0]

        buildToolbar(on: screen)
        syncOverlays()
        NotificationCenter.default.addObserver(self, selector: #selector(syncOverlays),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        buildStatusItem()
        registerHotKey()
        refreshSwatches()
        select(.pencil)
        applyMode()
    }

    // Displays: keep one overlay per connected screen, even as monitors come and go.

    @objc private func syncOverlays() {
        var connected = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? CGDirectDisplayID else { continue }
            connected.insert(id)
            if let window = overlays[id] {
                window.setFrame(screen.frame, display: true)   // resolution or arrangement changed
            } else {
                let window = OverlayWindow(screen: screen)
                window.contentView = makeCanvas(size: screen.frame.size)
                window.ignoresMouseEvents = !drawingEnabled
                window.orderFrontRegardless()
                overlays[id] = window
            }
        }
        for (id, window) in overlays where !connected.contains(id) {   // monitor unplugged
            if let c = window.contentView as? CanvasView { undoStack.removeAll { $0 === c } }
            window.orderOut(nil)
            window.close()
            overlays[id] = nil
        }
        keepToolbarOnScreen()
    }

    private func makeCanvas(size: NSSize) -> CanvasView {
        let c = CanvasView(frame: NSRect(origin: .zero, size: size))
        c.tool = tool
        c.color = color
        c.lineWidth = lineWidth
        c.eraserWidth = eraserWidth
        c.fontSize = fontSize
        c.onKeyDown = { [weak self] e in self?.handleKey(e) ?? false }
        c.onItemAdded = { [weak self] c in self?.undoStack.append(c) }
        return c
    }

    /// If the toolbar's display was unplugged, bring it back to the left edge of the main one.
    private func keepToolbarOnScreen() {
        guard let toolbar, !NSScreen.screens.contains(where: { $0.frame.intersects(toolbar.frame) }),
              let screen = NSScreen.screens.first else { return }
        let vf = screen.visibleFrame
        toolbar.setFrameOrigin(NSPoint(x: vf.minX + 12, y: vf.midY - toolbar.frame.height / 2))
    }

    private func handleKey(_ e: NSEvent) -> Bool {
        if e.modifierFlags.contains(.command), e.charactersIgnoringModifiers == "z" {
            undo(); return true
        }
        if e.keyCode == UInt16(kVK_Escape) { drawingEnabled = false; return true }
        switch e.charactersIgnoringModifiers?.lowercased() {
        case "p": select(.pencil); return true
        case "e": select(.eraser); return true
        case "t": select(.text); return true
        case "]": stepSize(+1); return true
        case "[": stepSize(-1); return true
        default:  return false
        }
    }

    // Drawing mode vs. click-through mode

    private func applyMode() {
        canvases.forEach { $0.commitText() }
        for w in overlays.values { w.ignoresMouseEvents = !drawingEnabled }
        modeButton.setSymbol(drawingEnabled ? "hand.draw" : "cursorarrow.rays")
        modeButton.style = drawingEnabled ? .accent : .plain
        modeButton.toolTip = drawingEnabled
            ? "Drawing ON: click to use your apps again (⌃⌥D)"
            : "Drawing OFF: click to draw (⌃⌥D)"
        refreshToolButtons()
        toggleMenuItem.state = drawingEnabled ? .on : .off
        if !drawingEnabled { NSApp.deactivate() }
    }

    private func select(_ tool: Tool) {
        self.tool = tool
        if !drawingEnabled { drawingEnabled = true }   // picking a tool turns drawing on
        refreshToolButtons()
        refreshSizeLabel()
    }

    private func refreshToolButtons() {
        for (t, b) in toolButtons { b.style = (drawingEnabled && t == tool) ? .well : .plain }
    }

    // Toolbar (vertical, meant to live on the left edge of the screen)

    private func buildToolbar(on screen: NSScreen) {
        modeButton = ToolButton("hand.draw", "Toggle drawing (⌃⌥D)",
                                target: self, action: #selector(toggleDrawing))
        let pencil = ToolButton("scribble.variable", "Pencil (P)", target: self, action: #selector(pickPencil))
        let eraser = ToolButton("eraser", "Eraser (E)", target: self, action: #selector(pickEraser))
        let text   = ToolButton("textformat", "Text (T)", target: self, action: #selector(pickText))
        toolButtons = [.pencil: pencil, .eraser: eraser, .text: text]

        swatches = (0..<3).map { i in
            let b = SwatchButton(target: self, action: #selector(pickSwatch(_:)))
            b.tag = i
            b.toolTip = "Recent color"
            return b
        }
        let moreColors = ToolButton("plus.circle", "Pick a new color…",
                                    target: self, action: #selector(showColorPanel))

        let bigger  = ToolButton("plus", "Bigger  ( ] )", pointSize: 12, height: 26,
                                 target: self, action: #selector(sizeUp))
        let smaller = ToolButton("minus", "Smaller  ( [ )", pointSize: 12, height: 26,
                                 target: self, action: #selector(sizeDown))
        sizeLabel = label(.monospacedDigitSystemFont(ofSize: 14, weight: .semibold), Theme.icon)
        sizeCaption = label(.systemFont(ofSize: 8.5, weight: .semibold), Theme.muted)

        let d1 = divider(), d2 = divider(), d3 = divider()
        let mainViews: [NSView] = [modeButton, d1, pencil, eraser, text, d2]
            + swatches + [moreColors, d3, bigger, sizeLabel, sizeCaption, smaller]
        let main = column(mainViews, insets: NSEdgeInsets(top: 8, left: 8, bottom: 10, right: 8))
        for d in [d1, d2, d3] {   // a bit more air around dividers
            if let i = mainViews.firstIndex(of: d), i > 0 { main.setCustomSpacing(10, after: mainViews[i - 1]) }
            main.setCustomSpacing(10, after: d)
        }
        main.setCustomSpacing(0, after: sizeLabel)

        let footer = column([
            ToolButton("arrow.uturn.backward", "Undo (⌘Z)", target: self, action: #selector(undo)),
            ToolButton("trash", "Clear all", target: self, action: #selector(clearAll)),
            ToolButton("xmark", "Quit", target: self, action: #selector(quit)),
        ], insets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        footer.wantsLayer = true
        footer.layer?.backgroundColor = Theme.footer.cgColor

        let stack = NSStackView(views: [main, footer])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = Theme.bar.cgColor
        bg.layer?.cornerRadius = 18
        bg.layer?.cornerCurve = .continuous
        bg.layer?.masksToBounds = true
        bg.layer?.borderWidth = 1
        bg.layer?.borderColor = NSColor(white: 1, alpha: 0.06).cgColor
        bg.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bg.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
        ])

        toolbar = ToolbarPanel()
        toolbar.contentView = bg
        let s = stack.fittingSize
        let vf = screen.visibleFrame
        toolbar.setFrame(NSRect(x: vf.minX + 12, y: vf.midY - s.height / 2,
                                width: s.width, height: s.height), display: true)
        toolbar.orderFrontRegardless()
        toolbar.invalidateShadow()
    }

    // Menu bar icon

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "scribble",
                                           accessibilityDescription: "Floaty")
        let menu = NSMenu()
        toggleMenuItem = menu.addItem(withTitle: "Drawing Mode  (⌃⌥D)",
                                      action: #selector(toggleDrawing), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(withTitle: "Show / Hide Toolbar",
                     action: #selector(toggleToolbar), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Clear All",
                     action: #selector(clearAll), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Floaty",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // Global shortcut: Control+Option+D (works without Accessibility permission)

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            NotificationCenter.default.post(name: .toggleDrawing, object: nil)
            return noErr
        }, 1, &spec, nil, nil)

        let id = EventHotKeyID(signature: OSType(0x534D_4B52), id: 1)   // "SMKR"
        RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)

        NotificationCenter.default.addObserver(self, selector: #selector(toggleDrawing),
                                               name: .toggleDrawing, object: nil)
    }

    // Recent colors

    private func loadRecentColors() {
        var saved: [NSColor] = []
        if let data = UserDefaults.standard.data(forKey: Self.recentsKey),
           let list = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSColor.self, from: data) {
            saved = list
        }
        recentColors = normalized(saved)
    }

    /// Dedupes, converts to sRGB, and tops up with defaults so there are always 3.
    private func normalized(_ list: [NSColor]) -> [NSColor] {
        var out: [NSColor] = []
        for c in list + Self.defaultColors {
            let srgb = c.usingColorSpace(.sRGB) ?? c
            if !out.contains(where: { sameColor($0, srgb) }) { out.append(srgb) }
            if out.count == 3 { break }
        }
        return out
    }

    private func sameColor(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let a = a.usingColorSpace(.sRGB), let b = b.usingColorSpace(.sRGB) else { return false }
        return abs(a.redComponent - b.redComponent) < 0.01
            && abs(a.greenComponent - b.greenComponent) < 0.01
            && abs(a.blueComponent - b.blueComponent) < 0.01
    }

    /// Makes `c` the current color and moves it to the front of the recents.
    private func useColor(_ c: NSColor, replacingNewest: Bool = false) {
        var rest = recentColors
        if replacingNewest, !rest.isEmpty { rest.removeFirst() }
        recentColors = normalized([c] + rest)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: recentColors,
                                                        requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: Self.recentsKey)
        }
        color = recentColors[0]
        refreshSwatches()
        if tool == .eraser { select(.pencil) }
    }

    private func refreshSwatches() {
        for (i, b) in swatches.enumerated() where i < recentColors.count {
            b.swatchColor = recentColors[i]
            b.isCurrent = (i == 0)
        }
    }

    // Size (pen width, eraser width, or text size, depending on the tool)

    private func stepSize(_ dir: Int) {
        func next(_ list: [CGFloat], _ v: CGFloat) -> CGFloat {
            dir > 0 ? (list.first { $0 > v } ?? list.last!) : (list.last { $0 < v } ?? list.first!)
        }
        switch tool {
        case .pencil: lineWidth = next(penSizes, lineWidth)
        case .eraser: eraserWidth = next(eraserSizes, eraserWidth)
        case .text:   fontSize = next(textSizes, fontSize)
        }
        refreshSizeLabel()
    }

    private func refreshSizeLabel() {
        let (value, caption): (CGFloat, String) = {
            switch tool {
            case .pencil: return (lineWidth, "PEN")
            case .eraser: return (eraserWidth, "ERASER")
            case .text:   return (fontSize, "TEXT")
            }
        }()
        sizeLabel.stringValue = "\(Int(value))"
        sizeCaption.stringValue = caption
        sizeLabel.toolTip = "\(caption.capitalized) size"
    }

    // Actions

    @objc private func toggleDrawing() { drawingEnabled.toggle() }
    @objc private func pickPencil() { select(.pencil) }
    @objc private func pickEraser() { select(.eraser) }
    @objc private func pickText()   { select(.text) }
    @objc private func sizeUp()     { stepSize(+1) }
    @objc private func sizeDown()   { stepSize(-1) }

    @objc private func pickSwatch(_ sender: NSButton) {
        guard sender.tag < recentColors.count else { return }
        colorPanelAddedColor = false
        useColor(recentColors[sender.tag])
    }

    @objc private func showColorPanel() {
        let panel = NSColorPanel.shared
        panel.setTarget(nil)              // don't treat the initial color as a pick
        panel.setAction(nil)
        panel.showsAlpha = false
        panel.color = color
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        colorPanelAddedColor = false
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        // While dragging around the picker, keep updating one slot instead of
        // flooding the recents with every in-between color.
        useColor(sender.color, replacingNewest: colorPanelAddedColor)
        colorPanelAddedColor = true
    }

    @objc private func undo() {
        canvases.forEach { $0.commitText() }   // finish any text being typed first
        undoStack.popLast()?.undo()           // undo the last drawing, whichever display it's on
    }

    @objc private func clearAll() {
        canvases.forEach { $0.clearAll() }
        undoStack.removeAll()
    }
    @objc private func quit()     { NSApp.terminate(nil) }

    @objc private func toggleToolbar() {
        if toolbar.isVisible { toolbar.orderOut(nil) } else { toolbar.orderFrontRegardless() }
    }

    // Little UI helpers

    private func column(_ views: [NSView], insets: NSEdgeInsets) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment = .centerX
        s.spacing = 4
        s.edgeInsets = insets
        s.translatesAutoresizingMaskIntoConstraints = false
        s.widthAnchor.constraint(equalToConstant: Theme.width).isActive = true
        return s
    }

    private func label(_ font: NSFont, _ color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = font
        l.textColor = color
        l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        l.widthAnchor.constraint(equalToConstant: Theme.button).isActive = true
        return l
    }

    private func divider() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = Theme.divider.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 28).isActive = true
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
}

// MARK: - Entry point

@main
enum FloatyMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // menu-bar app, no Dock icon
        withExtendedLifetime(delegate) { app.run() }
    }
}

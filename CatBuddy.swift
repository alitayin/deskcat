import Cocoa

enum PetMode {
    case auto
    case idle
    case sleep
}

enum PetAction {
    case idle
    case lookAround
    case walkLeft
    case walkRight
    case groom
    case stretch
    case sleep
}

struct PetSpriteFrames {
    let idle: [NSImage]
    let lookAround: [NSImage]
    let walk: [NSImage]
    let groom: [NSImage]
    let stretch: [NSImage]
    let sleep: [NSImage]

    static let empty = PetSpriteFrames(idle: [], lookAround: [], walk: [], groom: [], stretch: [], sleep: [])

    func frames(for action: PetAction) -> [NSImage] {
        switch action {
        case .idle:
            return idle
        case .lookAround:
            return lookAround.isEmpty ? idle : lookAround
        case .walkLeft, .walkRight:
            return walk
        case .groom:
            return groom.isEmpty ? (lookAround.isEmpty ? idle : lookAround) : groom
        case .stretch:
            return stretch.isEmpty ? (lookAround.isEmpty ? idle : lookAround) : stretch
        case .sleep:
            return sleep
        }
    }

    var hasAny: Bool {
        !idle.isEmpty || !lookAround.isEmpty || !walk.isEmpty || !groom.isEmpty || !stretch.isEmpty || !sleep.isEmpty
    }
}

func loadSprite(named name: String, from directory: URL) -> NSImage? {
    let pngURL = directory.appendingPathComponent(name + ".png")
    return NSImage(contentsOf: pngURL)
}

func spriteIndex(for fileURL: URL, prefix: String) -> Int? {
    let stem = fileURL.deletingPathExtension().lastPathComponent
    let expectedPrefix = prefix + "-"
    guard stem.hasPrefix(expectedPrefix) else {
        return nil
    }
    return Int(stem.dropFirst(expectedPrefix.count))
}

func loadSprites(prefix: String, from directory: URL) -> [NSImage] {
    guard let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
        return []
    }

    return items
        .filter { $0.pathExtension.lowercased() == "png" && spriteIndex(for: $0, prefix: prefix) != nil }
        .sorted { left, right in
            (spriteIndex(for: left, prefix: prefix) ?? 0) < (spriteIndex(for: right, prefix: prefix) ?? 0)
        }
        .compactMap { NSImage(contentsOf: $0) }
}

func loadStableWalkSprites(from directory: URL) -> [NSImage] {
    let explicitRightFacing = loadSprites(prefix: "walk-right", from: directory)
    if !explicitRightFacing.isEmpty {
        return curatedRightWalkFrames(explicitRightFacing)
    }

    let allWalkFrames = loadSprites(prefix: "walk", from: directory)
    guard allWalkFrames.count >= 8 else {
        return curatedRightWalkFrames(allWalkFrames)
    }

    // The first generated sheet mixed left-facing and right-facing poses.
    // Keep only the right-facing cells, then mirror them in code for left walks.
    let stableRightFacingIndexes = [2, 3, 4, 7]
    return stableRightFacingIndexes.compactMap { index in
        index < allWalkFrames.count ? allWalkFrames[index] : nil
    }
}

func curatedRightWalkFrames(_ frames: [NSImage]) -> [NSImage] {
    guard frames.count >= 3 else {
        return frames
    }

    // The generated walk set contains direction and scale drift.
    // These two cells are the closest in pose and both face the same way.
    return [frames[1], frames[2]]
}

func loadPetSprites() -> PetSpriteFrames {
    var searchDirectories: [URL] = []

    if let resourceURL = Bundle.main.resourceURL {
        searchDirectories.append(resourceURL.appendingPathComponent("assets/pet", isDirectory: true))
    }

    let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    searchDirectories.append(currentDirectory.appendingPathComponent("native-swift/assets/pet", isDirectory: true))
    searchDirectories.append(currentDirectory.appendingPathComponent("assets/pet", isDirectory: true))

    for directory in searchDirectories {
        let idle = loadSprites(prefix: "idle", from: directory)
        let lookAround = loadSprites(prefix: "look", from: directory)
        let walk = loadStableWalkSprites(from: directory)
        let groom = loadSprites(prefix: "groom", from: directory)
        let stretch = loadSprites(prefix: "stretch", from: directory)
        let sleep = loadSprites(prefix: "sleep", from: directory)
        let spriteFrames = PetSpriteFrames(
            idle: idle,
            lookAround: lookAround,
            walk: walk,
            groom: groom,
            stretch: stretch,
            sleep: sleep
        )
        if spriteFrames.hasAny {
            return spriteFrames
        }
    }

    return .empty
}

final class SpeechBubbleView: NSView {
    var text: String = "..." {
        didSet {
            needsDisplay = true
        }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bubbleRect = NSRect(x: 6, y: 14, width: bounds.width - 12, height: bounds.height - 20)
        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 18, yRadius: 18)
        NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
        bubblePath.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bounds.midX - 10, y: 18))
        tail.line(to: NSPoint(x: bounds.midX, y: 4))
        tail.line(to: NSPoint(x: bounds.midX + 10, y: 18))
        tail.close()
        tail.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.29, alpha: 1),
            .paragraphStyle: paragraph
        ]

        let textRect = NSRect(x: 18, y: 28, width: bubbleRect.width - 24, height: bubbleRect.height - 18)
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }
}

final class PetCanvasView: NSView {
    var action: PetAction = .idle { didSet { needsDisplay = true } }
    var frameTick: Int = 0 { didSet { needsDisplay = true } }
    var spriteFrames: PetSpriteFrames = .empty { didSet { needsDisplay = true } }
    var petPosition = NSPoint(x: 110, y: 120) { didSet { needsDisplay = true } }
    var onTap: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onDrag: ((NSSize) -> Void)?
    var onInteractionStateChange: ((Bool) -> Void)?

    private var mouseDownPoint: NSPoint = .zero
    private var lastDragPoint: NSPoint = .zero
    private var dragActive = false

    override var isOpaque: Bool { false }

    private var interactionRect: NSRect {
        NSRect(x: petPosition.x - 110, y: petPosition.y, width: 220, height: 220)
    }

    func containsInteractivePoint(_ point: NSPoint) -> Bool {
        interactionRect.insetBy(dx: -10, dy: -10).contains(point)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        containsInteractivePoint(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        lastDragPoint = mouseDownPoint
        dragActive = false
        onInteractionStateChange?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        let currentPoint = event.locationInWindow
        let delta = NSSize(
            width: currentPoint.x - lastDragPoint.x,
            height: currentPoint.y - lastDragPoint.y
        )
        lastDragPoint = currentPoint
        dragActive = true
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        let distance = hypot(event.locationInWindow.x - mouseDownPoint.x, event.locationInWindow.y - mouseDownPoint.y)
        if !dragActive || distance < 3 {
            onTap?()
        }
        dragActive = false
        onInteractionStateChange?(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        onInteractionStateChange?(true)
        onRightClick?()
        onInteractionStateChange?(false)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            return
        }

        ctx.saveGState()

        if drawSpriteIfAvailable(in: ctx) {
            ctx.restoreGState()
            return
        }

        ctx.translateBy(x: petPosition.x - 110, y: petPosition.y)
        if action == .walkLeft {
            ctx.translateBy(x: 220, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }

        let stepPhase = (frameTick / 5) % 2
        let isSleeping = action == .sleep
        let isBlinking = !isSleeping && (frameTick % 26 == 0 || frameTick % 26 == 1)
        let tailLift = CGFloat((frameTick % 10) - 5)

        let bodyColor = NSColor(calibratedRed: 0.82, green: 0.58, blue: 0.32, alpha: 1)
        let bellyColor = NSColor(calibratedRed: 0.95, green: 0.82, blue: 0.66, alpha: 1)
        let lineColor = NSColor(calibratedRed: 0.43, green: 0.28, blue: 0.18, alpha: 1)
        let earColor = NSColor(calibratedRed: 0.95, green: 0.70, blue: 0.49, alpha: 1)

        bodyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 54, y: 34, width: 92, height: 76)).fill()
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 44, width: 56, height: 48)).fill()

        bodyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 84, width: 52, height: 50)).fill()
        bellyColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 82, y: 92, width: 34, height: 26)).fill()

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 79, y: 118))
        leftEar.line(to: NSPoint(x: 88, y: 140))
        leftEar.line(to: NSPoint(x: 98, y: 120))
        leftEar.close()
        bodyColor.setFill()
        leftEar.fill()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 120, y: 118))
        rightEar.line(to: NSPoint(x: 111, y: 140))
        rightEar.line(to: NSPoint(x: 101, y: 120))
        rightEar.close()
        rightEar.fill()

        earColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: 84, y: 119, width: 10, height: 11)).fill()
        NSBezierPath(ovalIn: NSRect(x: 106, y: 119, width: 10, height: 11)).fill()

        if isSleeping || isBlinking {
            lineColor.setStroke()
            let leftEye = NSBezierPath()
            leftEye.move(to: NSPoint(x: 89, y: 108))
            leftEye.curve(to: NSPoint(x: 97, y: 108), controlPoint1: NSPoint(x: 91, y: 104), controlPoint2: NSPoint(x: 95, y: 104))
            leftEye.lineWidth = 2.8
            leftEye.stroke()

            let rightEye = NSBezierPath()
            rightEye.move(to: NSPoint(x: 104, y: 108))
            rightEye.curve(to: NSPoint(x: 112, y: 108), controlPoint1: NSPoint(x: 106, y: 104), controlPoint2: NSPoint(x: 110, y: 104))
            rightEye.lineWidth = 2.8
            rightEye.stroke()
        } else {
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 91, y: 103, width: 6, height: 10)).fill()
            NSBezierPath(ovalIn: NSRect(x: 106, y: 103, width: 6, height: 10)).fill()
        }

        NSColor(calibratedRed: 0.67, green: 0.36, blue: 0.33, alpha: 1).setFill()
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 101, y: 99))
        nose.line(to: NSPoint(x: 96, y: 93))
        nose.line(to: NSPoint(x: 106, y: 93))
        nose.close()
        nose.fill()

        lineColor.setStroke()
        let mouthLeft = NSBezierPath()
        mouthLeft.move(to: NSPoint(x: 101, y: 93))
        mouthLeft.curve(to: NSPoint(x: 92, y: 88), controlPoint1: NSPoint(x: 98, y: 88), controlPoint2: NSPoint(x: 95, y: 87))
        mouthLeft.lineWidth = 2
        mouthLeft.stroke()

        let mouthRight = NSBezierPath()
        mouthRight.move(to: NSPoint(x: 101, y: 93))
        mouthRight.curve(to: NSPoint(x: 110, y: 88), controlPoint1: NSPoint(x: 104, y: 88), controlPoint2: NSPoint(x: 107, y: 87))
        mouthRight.lineWidth = 2
        mouthRight.stroke()

        func legPath(_ x: CGFloat, startY: CGFloat, outward: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: startY))
            path.curve(
                to: NSPoint(x: x + outward, y: 28),
                controlPoint1: NSPoint(x: x + outward * 0.2, y: startY - 6),
                controlPoint2: NSPoint(x: x + outward * 0.8, y: 36)
            )
            path.lineWidth = 7
            path.lineCapStyle = .round
            return path
        }

        let leftFront = legPath(76, startY: 58, outward: stepPhase == 0 ? -8 : 6)
        let rightFront = legPath(122, startY: 58, outward: stepPhase == 0 ? 7 : -7)
        let leftBack = legPath(90, startY: 52, outward: stepPhase == 0 ? 5 : -4)
        let rightBack = legPath(136, startY: 52, outward: stepPhase == 0 ? -4 : 5)
        lineColor.setStroke()
        leftFront.stroke()
        rightFront.stroke()
        leftBack.stroke()
        rightBack.stroke()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 142, y: 68))
        tail.curve(
            to: NSPoint(x: 132, y: 116 + tailLift * 0.4),
            controlPoint1: NSPoint(x: 165, y: 78 + tailLift * 0.2),
            controlPoint2: NSPoint(x: 156, y: 116 + tailLift)
        )
        tail.lineWidth = 8
        tail.lineCapStyle = .round
        lineColor.setStroke()
        tail.stroke()

        if isSleeping {
            let zText = NSAttributedString(
                string: "Z",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: NSColor.systemBlue
                ]
            )
            zText.draw(at: NSPoint(x: 118, y: 130))
        }

        ctx.restoreGState()
    }

    private func drawSpriteIfAvailable(in ctx: CGContext) -> Bool {
        let frames = spriteFrames.frames(for: action)
        guard !frames.isEmpty else {
            return false
        }

        let image = spriteFrame(for: frames)
        let size = action == .sleep ? NSSize(width: 184, height: 134) : NSSize(width: 180, height: 138)
        let rect = NSRect(
            x: petPosition.x - (size.width / 2),
            y: petPosition.y + (action == .sleep ? 10 : 22),
            width: size.width,
            height: size.height
        )

        if action == .walkLeft || action == .walkRight {
            ctx.saveGState()
            ctx.translateBy(x: rect.midX, y: rect.midY)
            if action == .walkLeft {
                ctx.scaleBy(x: -1, y: 1)
            }
            image.draw(in: NSRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height))
            ctx.restoreGState()
        } else if action == .walkLeft {
            ctx.saveGState()
            ctx.translateBy(x: rect.midX, y: rect.midY)
            ctx.scaleBy(x: -1, y: 1)
            image.draw(in: NSRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height))
            ctx.restoreGState()
        } else {
            image.draw(in: rect)
        }
        return true
    }

    private func spriteFrame(for frames: [NSImage]) -> NSImage {
        switch action {
        case .idle:
            return frames[loopedIndex(frameCount: frames.count, pace: 10)]
        case .lookAround:
            return frames[pingPongIndex(frameCount: frames.count, pace: 18)]
        case .walkLeft, .walkRight:
            return frames[loopedIndex(frameCount: frames.count, pace: 14)]
        case .groom:
            return frames[pingPongIndex(frameCount: frames.count, pace: 12)]
        case .stretch:
            return frames[pingPongIndex(frameCount: frames.count, pace: 16)]
        case .sleep:
            return frames[pingPongIndex(frameCount: frames.count, pace: 24)]
        }
    }

    private func loopedIndex(frameCount: Int, pace: Int) -> Int {
        guard frameCount > 1 else {
            return 0
        }
        return (frameTick / max(pace, 1)) % frameCount
    }

    private func pingPongIndex(frameCount: Int, pace: Int) -> Int {
        guard frameCount > 1 else {
            return 0
        }

        let cycleLength = (frameCount * 2) - 2
        let rawIndex = (frameTick / max(pace, 1)) % max(cycleLength, 1)
        if rawIndex < frameCount {
            return rawIndex
        }
        return cycleLength - rawIndex
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var rootView: NSView!
    private var petView: PetCanvasView!
    private var bubbleView: SpeechBubbleView!
    private var animationTimer: Timer?
    private var behaviorTimer: Timer?
    private var bubbleTimer: Timer?
    private var passthroughTimer: Timer?
    private var userIsInteracting = false

    private let sayings = [
        "喵～",
        "喵～～～",
        "咪呜～",
        "喵。"
    ]

    private var mode: PetMode = .auto
    private var action: PetAction = .idle {
        didSet {
            petView.action = action
        }
    }
    private var frameTick: Int = 0 {
        didSet {
            petView.frameTick = frameTick
        }
    }
    private var walkDestination: NSPoint?
    private var nextWalkDirection: CGFloat = 1
    private var petPosition = NSPoint(x: 110, y: 120) {
        didSet {
            petView?.petPosition = petPosition
            updateBubblePosition()
            updateMousePassthrough()
        }
    }

    private let walkSpeed: CGFloat = 3.2

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        wireCallbacks()
        petView.spriteFrames = loadPetSprites()
        moveHome()
        setMode(.auto)
        startAnimationLoop()
        startPassthroughLoop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildWindow() {
        guard let screen = NSScreen.main else {
            fatalError("No main screen available")
        }
        let windowFrame = screen.frame

        window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true

        rootView = NSView(frame: window.contentView!.bounds)
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor

        bubbleView = SpeechBubbleView(frame: NSRect(x: 20, y: 148, width: 180, height: 74))
        bubbleView.isHidden = true
        rootView.addSubview(bubbleView)

        petView = PetCanvasView(frame: rootView.bounds)
        rootView.addSubview(petView)

        window.contentView = rootView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    private func wireCallbacks() {
        petView.onTap = { [weak self] in
            self?.sayRandomLine()
        }

        petView.onRightClick = { [weak self] in
            self?.showContextMenu()
        }

        petView.onDrag = { [weak self] delta in
            self?.dragPet(delta: delta)
        }

        petView.onInteractionStateChange = { [weak self] isInteracting in
            self?.userIsInteracting = isInteracting
            self?.updateMousePassthrough()
        }
    }

    private func startAnimationLoop() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func startPassthroughLoop() {
        passthroughTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.updateMousePassthrough()
        }
    }

    private func tick() {
        frameTick += 1
        updateMousePassthrough()

        switch action {
        case .walkLeft:
            moveWalkStep()
        case .walkRight:
            moveWalkStep()
        default:
            break
        }
    }

    private func dragPet(delta: NSSize) {
        let nextPosition = NSPoint(x: petPosition.x + delta.width, y: petLaneY())
        petPosition = clampedPetPosition(nextPosition)
    }

    private func setMode(_ nextMode: PetMode) {
        mode = nextMode
        behaviorTimer?.invalidate()
        walkDestination = nil

        switch nextMode {
        case .auto:
            action = .idle
            scheduleNextBehavior(after: Double.random(in: 2.2 ... 4.2))
        case .idle:
            action = .idle
        case .sleep:
            action = .sleep
        }
    }

    private func scheduleNextBehavior(after delay: TimeInterval) {
        behaviorTimer?.invalidate()
        guard mode == .auto else {
            return
        }

        behaviorTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.chooseRandomBehavior()
        }
    }

    private func chooseRandomBehavior() {
        guard mode == .auto else {
            return
        }

        let roll = Double.random(in: 0 ... 1)
        if roll < 0.14 {
            action = .idle
            maybeAutoMeow(chance: 0.06)
            scheduleNextBehavior(after: Double.random(in: 3.5 ... 5.5))
        } else if roll < 0.28 {
            action = .lookAround
            maybeAutoMeow(chance: 0.08)
            scheduleNextBehavior(after: Double.random(in: 3.8 ... 5.8))
        } else if roll < 0.68 {
            startWalk()
        } else if roll < 0.78 {
            action = .groom
            scheduleNextBehavior(after: Double.random(in: 5.0 ... 9.0))
        } else if roll < 0.90 {
            action = .stretch
            scheduleNextBehavior(after: Double.random(in: 3.4 ... 5.4))
        } else {
            action = .sleep
            scheduleNextBehavior(after: Double.random(in: 7.0 ... 12.0))
        }
    }

    private func sayRandomLine() {
        say(sayings.randomElement() ?? "喵。", autoHideAfter: 2.8)
    }

    private func maybeAutoMeow(chance: Double) {
        guard Double.random(in: 0 ... 1) < chance else {
            return
        }
        sayRandomLine()
    }

    private func say(_ text: String, autoHideAfter seconds: TimeInterval) {
        bubbleTimer?.invalidate()
        bubbleView.text = text
        bubbleView.isHidden = false
        updateBubblePosition()
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.bubbleView.isHidden = true
        }
    }

    private func showContextMenu() {
        let menu = NSMenu(title: "CatBuddy")
        menu.addItem(withTitle: "自动散步", action: #selector(menuAuto), keyEquivalent: "")
        menu.addItem(withTitle: "发呆", action: #selector(menuIdle), keyEquivalent: "")
        menu.addItem(withTitle: "左看看右看看", action: #selector(menuLookAround), keyEquivalent: "")
        menu.addItem(withTitle: "舔爪洗脸", action: #selector(menuGroom), keyEquivalent: "")
        menu.addItem(withTitle: "伸懒腰", action: #selector(menuStretch), keyEquivalent: "")
        menu.addItem(withTitle: "睡觉", action: #selector(menuSleep), keyEquivalent: "")
        menu.addItem(withTitle: "喵一句", action: #selector(menuSpeak), keyEquivalent: "")
        menu.addItem(withTitle: "回窝", action: #selector(menuHome), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(menuQuit), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: petView)
    }

    @objc private func menuAuto() { setMode(.auto) }
    @objc private func menuIdle() { setMode(.idle) }
    @objc private func menuLookAround() {
        mode = .idle
        behaviorTimer?.invalidate()
        action = .lookAround
    }
    @objc private func menuGroom() {
        mode = .idle
        behaviorTimer?.invalidate()
        action = .groom
    }
    @objc private func menuStretch() {
        mode = .idle
        behaviorTimer?.invalidate()
        action = .stretch
    }
    @objc private func menuSleep() { setMode(.sleep) }
    @objc private func menuSpeak() { sayRandomLine() }
    @objc private func menuHome() {
        moveHome()
        setMode(.sleep)
    }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    private func moveHome() {
        petPosition = clampedPetPosition(NSPoint(x: rootView.bounds.midX, y: petLaneY()))
    }

    private func moveWalkStep() {
        guard let destination = walkDestination else {
            action = .idle
            scheduleNextBehavior(after: Double.random(in: 2.8 ... 5.0))
            return
        }

        let dx = destination.x - petPosition.x
        let distance = abs(dx)

        if distance <= walkSpeed {
            petPosition = clampedPetPosition(destination)
            walkDestination = nil
            action = .idle
            scheduleNextBehavior(after: Double.random(in: 0.8 ... 1.6))
            return
        }

        let stepX = (dx >= 0 ? 1 : -1) * walkSpeed
        petPosition = clampedPetPosition(NSPoint(x: petPosition.x + stepX, y: petLaneY()))
    }

    private func startWalk() {
        let bounds = movementBounds()
        let current = clampedPetPosition(petPosition)
        var direction = nextWalkDirection
        if current.x <= bounds.minX + 24 {
            direction = 1
        } else if current.x >= bounds.maxX - 24 {
            direction = -1
        }
        let maxHorizontalDistance = max(320, min(900, bounds.width * 0.72))
        let minHorizontalDistance = min(320, maxHorizontalDistance)
        let desiredDistance = CGFloat.random(in: minHorizontalDistance ... maxHorizontalDistance)
        let destinationX = min(max(current.x + (direction * desiredDistance), bounds.minX), bounds.maxX)
        nextWalkDirection = -direction
        startWalk(to: NSPoint(x: destinationX, y: petLaneY()))
    }

    private func startWalk(to destination: NSPoint) {
        let clampedDestination = clampedPetPosition(destination)
        walkDestination = clampedDestination
        action = clampedDestination.x >= petPosition.x ? .walkRight : .walkLeft
    }

    private func movementBounds() -> NSRect {
        let screenBounds = rootView.bounds
        let minX: CGFloat = 92
        let maxX = max(minX, screenBounds.width - 110)
        let minY: CGFloat = 42
        let maxY = max(minY, screenBounds.height - 222)
        return NSRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private func petLaneY() -> CGFloat {
        let screenBounds = rootView.bounds
        let minY: CGFloat = 42
        let maxY = max(minY, screenBounds.height - 222)
        return min(max(screenBounds.height * 0.34, minY), maxY)
    }

    private func clampedPetPosition(_ point: NSPoint) -> NSPoint {
        let bounds = movementBounds()
        return NSPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: petLaneY()
        )
    }

    private func updateBubblePosition() {
        guard bubbleView != nil, rootView != nil else {
            return
        }
        let x = max(16, min(petPosition.x - bubbleView.frame.width / 2, rootView.bounds.width - bubbleView.frame.width - 16))
        let y = max(16, min(petPosition.y + 170, rootView.bounds.height - bubbleView.frame.height - 16))
        bubbleView.frame.origin = NSPoint(x: x, y: y)
    }

    private func updateMousePassthrough() {
        guard window != nil, rootView != nil, petView != nil else {
            return
        }

        if userIsInteracting {
            window.ignoresMouseEvents = false
            return
        }

        let mouseLocationOnScreen = NSEvent.mouseLocation
        let mouseLocationInWindow = window.convertPoint(fromScreen: mouseLocationOnScreen)
        let mouseLocationInRoot = rootView.convert(mouseLocationInWindow, from: nil)
        let shouldCapture = petView.containsInteractivePoint(mouseLocationInRoot)
        window.ignoresMouseEvents = !shouldCapture
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()

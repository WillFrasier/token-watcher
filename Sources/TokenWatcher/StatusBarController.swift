import Cocoa
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    private let panelWidth: CGFloat = 340
    private let panelHeight: CGFloat = 580

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupButton()

        UsageStore.shared.$projects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)

        UsageStore.shared.$totalUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)

        UsageStore.shared.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButton() }
            .store(in: &cancellables)
    }

    // MARK: - Button

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        updateButton()
    }

    func updateButton() {
        guard let button = statusItem.button else { return }

        let alertCount = UsageStore.shared.projects.filter(\.isAlerting).count
        let cost = UsageStore.shared.totalUsage.costUSD
        let isLoading = UsageStore.shared.isLoading

        button.image = isLoading ? loadingImage() : circleImage(for: alertCount)
        button.contentTintColor = nil
        button.imagePosition = .imageLeft

        let label = isLoading ? "" : (cost > 0 ? " \(cost.formattedCost)" : "")
        button.attributedTitle = NSAttributedString(
            string: label,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.menuBarFont(ofSize: 11)
            ]
        )
    }

    // MARK: - Icon drawing

    private func circleImage(for alertCount: Int) -> NSImage {
        let base: NSColor
        switch alertCount {
        case 0:       base = NSColor(calibratedRed: 0.18, green: 0.82, blue: 0.44, alpha: 1)  // green
        case 1...2:   base = NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.00, alpha: 1)  // amber
        default:      base = NSColor(calibratedRed: 1.00, green: 0.28, blue: 0.28, alpha: 1)  // red
        }
        return drawCircle(color: base)
    }

    private func loadingImage() -> NSImage {
        let img = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: nil)!
        img.isTemplate = true
        return img
    }

    private func drawCircle(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }

            let cx = rect.midX, cy = rect.midY
            let r: CGFloat = 6.5
            let circle = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)

            // Soft glow behind circle
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 5, color: color.withAlphaComponent(0.7).cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.addEllipse(in: circle)
            ctx.fillPath()
            ctx.restoreGState()

            // Solid fill
            ctx.setFillColor(color.cgColor)
            ctx.addEllipse(in: circle)
            ctx.fillPath()

            // Top shine: white gradient clipped to upper half of circle
            ctx.saveGState()
            ctx.addEllipse(in: circle)
            ctx.clip()
            let shineColors = [
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.45),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0)
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: space, colors: shineColors, locations: [0, 1]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: cx, y: cy + r),
                    end: CGPoint(x: cx, y: cy),
                    options: []
                )
            }
            ctx.restoreGState()

            return true
        }
        img.isTemplate = false
        return img
    }

    // MARK: - Panel

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        if let panel, panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func makePanel() -> NSPanel {
        let contentView = MainView()
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovable = false
        p.contentView = hosting
        return p
    }

    private func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        if panel == nil { panel = makePanel() }
        guard let panel else { return }

        // Convert button frame to screen coordinates
        let buttonBounds = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonBounds)

        // Use the screen the status item button's window lives on — most reliable
        let screen = buttonWindow.screen ?? NSScreen.main ?? NSScreen.screens[0]

        // Right-align panel to button's right edge, clamp within screen bounds
        let panelX = (screenRect.maxX - panelWidth)
            .clamped(to: screen.frame.minX...(screen.frame.maxX - panelWidth))
        // Position flush below menu bar using status bar thickness
        let panelY = screen.frame.maxY - NSStatusBar.system.thickness - panelHeight

        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        panel.makeKeyAndOrderFront(nil)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

}

private extension Sequence {
    func contains(_ keyPath: KeyPath<Element, Bool>) -> Bool {
        contains { $0[keyPath: keyPath] }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

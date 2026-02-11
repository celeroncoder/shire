import AppKit
import QuartzCore

/// A subtle gradient overlay that hints at scrollable content beyond the visible edge.
/// Passes all mouse events through so it doesn't interfere with interaction.
final class ScrollFadeView: NSView {

    enum Edge { case top, bottom }

    private let edge: Edge
    private var gradientLayer: CAGradientLayer?

    init(edge: Edge) {
        self.edge = edge
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        if gradientLayer == nil, let backing = layer {
            let gl = CAGradientLayer()
            let dark = NSColor.black.withAlphaComponent(0.12).cgColor
            let clear = CGColor.clear

            gl.colors = [dark, clear]
            switch edge {
            case .top:
                gl.startPoint = CGPoint(x: 0.5, y: 1.0)
                gl.endPoint = CGPoint(x: 0.5, y: 0.0)
            case .bottom:
                gl.startPoint = CGPoint(x: 0.5, y: 0.0)
                gl.endPoint = CGPoint(x: 0.5, y: 1.0)
            }

            backing.addSublayer(gl)
            gradientLayer = gl
        }

        gradientLayer?.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

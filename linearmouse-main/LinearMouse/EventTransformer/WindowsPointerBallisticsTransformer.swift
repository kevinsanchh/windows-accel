// MIT License
// Copyright (c) 2021-2026 LinearMouse

import CoreGraphics
import Foundation

/// Windows 8–11 EPP as specified in windows-mouse-accel.md. Counts are per
/// packet: deliberately no timestamp, polling-rate or hardware-DPI normalization.
struct WindowsPointerBallistics {
    private static let x = [0.0, Double(0x6E15) / 65536, 1.25, Double(0x3DC29) / 65536, 40]
    private static let y = [0.0, Double(0x111FD) / 65536, Double(0x42400) / 65536,
                            Double(0x12FC00) / 65536, Double(0x1BBC000) / 65536]
    let sensitivity: Double
    let displayDPI: Double
    private var remainderX = 0.0
    private var remainderY = 0.0
    private var previousSignX = 0.0
    private var previousSignY = 0.0

    init(settings: Scheme.Pointer.CustomAcceleration = .init()) {
        sensitivity = settings.effectiveSensitivity
        displayDPI = settings.effectiveDisplayDPI
    }

    func gain(for magnitude: Double) -> Double {
        guard magnitude > 0, magnitude.isFinite else { return 0 }
        let lookup = magnitude / 3.5
        let segment = (0 ..< 3).first { lookup <= Self.x[$0 + 1] } ?? 3
        let slope = (Self.y[segment + 1] - Self.y[segment]) /
            (Self.x[segment + 1] - Self.x[segment])
        let output = Self.y[segment] + slope * (lookup - Self.x[segment])
        return sensitivity / 10 * displayDPI / 120 * output / magnitude
    }

    mutating func transform(dx: Double, dy: Double) -> (x: Int64, y: Int64) {
        guard dx.isFinite, dy.isFinite else { reset(); return (0, 0) }
        let gain = gain(for: hypot(dx, dy))
        return (Self.axis(dx, gain: gain, remainder: &remainderX, previousSign: &previousSignX),
                Self.axis(dy, gain: gain, remainder: &remainderY, previousSign: &previousSignY))
    }

    private static func axis(_ delta: Double, gain: Double, remainder: inout Double,
                             previousSign: inout Double) -> Int64 {
        let sign = delta == 0 ? 0.0 : (delta > 0 ? 1.0 : -1.0)
        if sign == 0 || sign != previousSign { remainder = 0 }
        previousSign = sign
        let total = delta * gain + remainder
        // Guard conversion against malformed synthetic event fields.
        guard total.isFinite, total > Double(Int64.min), total < Double(Int64.max) else {
            remainder = 0
            return 0
        }
        let output = Int64(total.rounded(.towardZero))
        remainder = total - Double(output)
        return output
    }

    mutating func reset() {
        remainderX = 0
        remainderY = 0
        previousSignX = 0
        previousSignY = 0
    }
}

final class WindowsPointerBallisticsTransformer: EventTransformer, Deactivatable {
    private var ballistics: WindowsPointerBallistics
    private let displayBounds: () -> [CGRect]
    private let isReady: (Device?) -> Bool

    init(settings: Scheme.Pointer.CustomAcceleration,
         displayBounds: @escaping () -> [CGRect] = { ScreenManager.shared.displayBoundsSnapshot },
         isReady: @escaping (Device?) -> Bool = { $0?.pointerSchemeState.isCustomAccelerationReady == true }) {
        ballistics = .init(settings: settings)
        self.displayBounds = displayBounds
        self.isReady = isReady
    }

    func transform(_ event: CGEvent, in context: EventTransformerContext) -> CGEvent? {
        guard event.type.isPointerMotion else { return event }
        guard isReady(context.device) else { ballistics.reset(); return event }
        let dx = event.getIntegerValueField(.mouseEventDeltaX)
        let dy = event.getIntegerValueField(.mouseEventDeltaY)
        let output = ballistics.transform(dx: Double(dx), dy: Double(dy))
        let base = CGPoint(x: event.location.x - CGFloat(dx), y: event.location.y - CGFloat(dy))
        event.setIntegerValueField(.mouseEventDeltaX, value: output.x)
        event.setIntegerValueField(.mouseEventDeltaY, value: output.y)
        event.location = Self.clamp(CGPoint(x: base.x + CGFloat(output.x), y: base.y + CGFloat(output.y)),
                                    to: displayBounds())
        return event
    }

    /// Clamp to the nearest actual display, including displays with negative
    /// origins and gaps between displays, rather than the main display alone.
    static func clamp(_ point: CGPoint, to displays: [CGRect]) -> CGPoint {
        if displays.contains(where: { $0.contains(point) }) { return point }
        return displays.filter { !$0.isEmpty }.map { bounds in
            CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX - 1),
                    y: min(max(point.y, bounds.minY), bounds.maxY - 1))
        }.min { hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y) } ?? point
    }

    func deactivate() { ballistics.reset() }
    func reactivate() { ballistics.reset() }
}

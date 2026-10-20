// MIT License
// Copyright (c) 2021-2026 LinearMouse

@testable import LinearMouse
import XCTest

final class WindowsPointerBallisticsTests: XCTestCase {
    func testRegistryKnotsAndInterpolationAndExtrapolation() {
        let engine = WindowsPointerBallistics()
        let x = [Double(0x6E15) / 65536, 1.25, Double(0x3DC29) / 65536, 40]
        let y = [Double(0x111FD) / 65536, 4.140625, 18.984375, 443.75]
        for index in x.indices {
            let m = 3.5 * x[index]
            XCTAssertEqual(engine.gain(for: m), 0.8 * y[index] / m, accuracy: 1e-12)
        }
        // Interpolate output velocity rather than interpolating endpoint gains.
        let midpoint = (x[1] + x[2]) / 2
        XCTAssertEqual(engine.gain(for: midpoint * 3.5), 0.8 * (y[1] + y[2]) / 2 / (midpoint * 3.5), accuracy: 1e-12)
        let extrapolated = y[3] + (y[3] - y[2]) / (x[3] - x[2]) * 40
        XCTAssertEqual(engine.gain(for: 280), 0.8 * extrapolated / 280, accuracy: 1e-12)
        XCTAssertEqual(engine.gain(for: 1), 0.5689020464649434, accuracy: 1e-8)
        XCTAssertEqual(engine.gain(for: 0), 0)
    }

    func testWindowsPresetIgnoresDisplayDPIButAllowsFractionalSensitivity() {
        let custom = Scheme.Pointer.CustomAcceleration(enabled: true, useWindowsAcceleration: true,
                                                        sensitivity: 12.34, displayDPI: 384)
        XCTAssertEqual(WindowsPointerBallistics(settings: custom).gain(for: 10),
                       WindowsPointerBallistics().gain(for: 10) * 1.234, accuracy: 1e-12)
        let scaled = Scheme.Pointer.CustomAcceleration(useWindowsAcceleration: false, sensitivity: 20, displayDPI: 144)
        XCTAssertEqual(WindowsPointerBallistics(settings: scaled).gain(for: 10),
                       WindowsPointerBallistics().gain(for: 10) * 3, accuracy: 1e-12)
    }

    func testDirectionalRemaindersTruncateTowardZeroAndResetPerAxis() {
        var engine = WindowsPointerBallistics()
        XCTAssertEqual(engine.transform(dx: 1, dy: 0).x, 0)
        XCTAssertEqual(engine.transform(dx: 1, dy: 0).x, 1)
        XCTAssertEqual(engine.transform(dx: -1, dy: 0).x, 0)
        XCTAssertEqual(engine.transform(dx: -1, dy: 0).x, -1)
        _ = engine.transform(dx: 0, dy: 0)
        XCTAssertEqual(engine.transform(dx: -1, dy: 0).x, 0)
        engine.reset()
        _ = engine.transform(dx: 1, dy: 1)
        XCTAssertEqual(engine.transform(dx: 0, dy: 1).y, 1)
        XCTAssertEqual(engine.transform(dx: 1, dy: 0).x, 0)
    }

    func testRadialGainAndPacketDependence() {
        var diagonal = WindowsPointerBallistics()
        let gain = diagonal.gain(for: 5)
        let output = diagonal.transform(dx: 3, dy: 4)
        XCTAssertEqual(output.x, Int64((3 * gain).rounded(.towardZero)))
        XCTAssertEqual(output.y, Int64((4 * gain).rounded(.towardZero)))
        XCTAssertGreaterThan(diagonal.gain(for: 8), diagonal.gain(for: 1))
    }

    func testMotionAndEveryDragRewriteLocationAndDeltas() throws {
        for type: CGEventType in [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged] {
            let transformer = WindowsPointerBallisticsTransformer(settings: .init(), displayBounds: { [] }, isReady: { _ in true })
            let event = try XCTUnwrap(CGEvent(source: nil))
            event.type = type
            event.location = CGPoint(x: 110, y: 100)
            event.setIntegerValueField(.mouseEventDeltaX, value: 10)
            event.setIntegerValueField(.mouseEventDeltaY, value: 0)
            XCTAssertNotNil(transformer.transform(event, in: .init(device: nil)))
            let expected = Int64((10 * WindowsPointerBallistics().gain(for: 10)).rounded(.towardZero))
            XCTAssertEqual(event.getIntegerValueField(.mouseEventDeltaX), expected)
            XCTAssertEqual(event.location, CGPoint(x: 100 + Double(expected), y: 100))
            transformer.deactivate()
            transformer.reactivate()
        }
    }

    func testClampingUsesNearestDisplayIncludingNegativeOrigins() {
        let displays = [CGRect(x: 0, y: 0, width: 100, height: 100),
                        CGRect(x: -150, y: 0, width: 100, height: 100)]
        XCTAssertEqual(WindowsPointerBallisticsTransformer.clamp(CGPoint(x: -100, y: 50), to: displays), CGPoint(x: -100, y: 50))
        XCTAssertEqual(WindowsPointerBallisticsTransformer.clamp(CGPoint(x: -70, y: 150), to: displays), CGPoint(x: -70, y: 99))
        XCTAssertEqual(WindowsPointerBallisticsTransformer.clamp(CGPoint(x: 200, y: 50), to: displays), CGPoint(x: 99, y: 50))
    }

    func testConfigurationRoundTripAndInheritance() throws {
        var parent = Scheme.Pointer(customAcceleration: .init(enabled: true, sensitivity: 15, displayDPI: 120))
        Scheme.Pointer(customAcceleration: .init(useWindowsAcceleration: false)).merge(into: &parent)
        XCTAssertEqual(parent.customAcceleration?.enabled, true)
        XCTAssertEqual(parent.customAcceleration?.effectiveSensitivity, 15)
        XCTAssertEqual(parent.customAcceleration?.effectiveDisplayDPI, 120)
        let encoded = try JSONEncoder().encode(parent)
        XCTAssertEqual(try JSONDecoder().decode(Scheme.Pointer.self, from: encoded), parent)
        let disabled = Scheme.Pointer(customAcceleration: .init(enabled: false))
        disabled.merge(into: &parent)
        XCTAssertEqual(parent.customAcceleration?.enabled, false)
    }

    func testCustomAccelerationRequiresAllMotionTypes() {
        var configuration = Configuration()
        configuration.schemes = [Scheme(pointer: .init(customAcceleration: .init(enabled: true)))]
        XCTAssertEqual(PointerMotionRequirements(configuration: configuration), .all)
    }
    func testUnidentifiedOrUnpreparedDevicePassesThroughWithoutDoubleAcceleration() throws {
        let transformer = WindowsPointerBallisticsTransformer(settings: .init(), displayBounds: { [] })
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.type = .mouseMoved
        event.location = CGPoint(x: 110, y: 100)
        event.setIntegerValueField(.mouseEventDeltaX, value: 10)
        _ = transformer.transform(event, in: .init(device: nil))
        XCTAssertEqual(event.getIntegerValueField(.mouseEventDeltaX), 10)
        XCTAssertEqual(event.location, CGPoint(x: 110, y: 100))
    }

    func testSensitivityQuantizationBoundsAndDefault() {
        XCTAssertEqual(Scheme.Pointer.CustomAcceleration.normalizedSensitivity(12.346), 12.35)
        XCTAssertEqual(Scheme.Pointer.CustomAcceleration.normalizedSensitivity(12.344), 12.34)
        XCTAssertEqual(Scheme.Pointer.CustomAcceleration.normalizedSensitivity(0), 1)
        XCTAssertEqual(Scheme.Pointer.CustomAcceleration.normalizedSensitivity(100), 20)
        XCTAssertEqual(Scheme.Pointer.CustomAcceleration.normalizedSensitivity(nil), 10)
        XCTAssertEqual(Scheme.Pointer.CustomAcceleration.normalizedSensitivity(.nan), 10)
    }

}

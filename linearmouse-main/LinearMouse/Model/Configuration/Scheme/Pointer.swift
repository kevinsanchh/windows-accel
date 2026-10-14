// MIT License
// Copyright (c) 2021-2026 LinearMouse

import Foundation

extension Scheme {
    struct Acceleration: Equatable, ClampRange {
        typealias Value = Unsettable<Decimal>
        typealias RangeValue = Decimal

        static var range: ClosedRange<RangeValue> = 0 ... 40

        static func clamp(_ value: Value?) -> Value? {
            guard let value else {
                return nil
            }
            switch value {
            case let .value(v):
                return .value(v.clamped(to: range))
            case .unset:
                return .unset
            }
        }
    }

    struct Speed: Equatable, ClampRange {
        typealias Value = Unsettable<Decimal>
        typealias RangeValue = Decimal

        static var range: ClosedRange<RangeValue> = 0 ... 1

        static func clamp(_ value: Value?) -> Value? {
            guard let value else {
                return nil
            }
            switch value {
            case let .value(v):
                return .value(v.clamped(to: range))
            case .unset:
                return .unset
            }
        }
    }

    struct Pointer: Codable, Equatable, ImplicitInitable {
        @Clamp<Acceleration> var acceleration: Unsettable<Decimal>?

        @Clamp<Speed> var speed: Unsettable<Decimal>?

        var customAcceleration: CustomAcceleration?

        var hardwareDPI: Int?

        /// Match application conditions against the window under the pointer.
        var focusFollowsMouse: Bool?

        var disableAcceleration: Bool?
        var redirectsToScroll: Bool?
        /// When set, pointer movement is redirected to scrolling only while
        /// this trigger is held. Requires `redirectsToScroll`.
        var redirectsToScrollTrigger: Trigger?
    }
}

extension Scheme.Pointer {
    func merge(into pointer: inout Self) {
        if let acceleration {
            pointer.acceleration = acceleration
        }

        if let speed {
            pointer.speed = speed
        }

        if let customAcceleration {
            if pointer.customAcceleration == nil { pointer.customAcceleration = .init() }
            customAcceleration.merge(into: &pointer.customAcceleration!)
        }

        if let hardwareDPI {
            pointer.hardwareDPI = hardwareDPI
        }

        if let focusFollowsMouse {
            pointer.focusFollowsMouse = focusFollowsMouse
        }

        if let disableAcceleration {
            pointer.disableAcceleration = disableAcceleration
        }

        if let redirectsToScroll {
            pointer.redirectsToScroll = redirectsToScroll
        }

        if let redirectsToScrollTrigger {
            pointer.redirectsToScrollTrigger = redirectsToScrollTrigger
        }
    }

    func merge(into pointer: inout Self?) {
        if pointer == nil {
            pointer = Self()
        }

        merge(into: &pointer!)
    }
}

extension Scheme.Trigger {
    /// Whether this trigger can be held to redirect pointer movement to scrolling.
    ///
    /// Only a single mouse button, optionally with modifier keys, is supported.
    /// The primary button without modifier keys is rejected because it would
    /// take over every click.
    var isValidRedirectsToScrollTrigger: Bool {
        guard case let .button(.mouse(buttonNumber)) = input,
              (simultaneous ?? []).isEmpty,
              (whileHeld ?? []).isEmpty else {
            return false
        }

        return buttonNumber != 0 || !modifierFlags.isEmpty
    }
}

/// Simple controls over the documented ballistic curve. Its lookup points,
/// counts-per-poll divisor, extrapolation and remainder rules are fixed.
extension Scheme.Pointer {
    struct CustomAcceleration: Codable, Equatable {
        var enabled: Bool?
        var useWindowsAcceleration: Bool?
        var sensitivity: Double?
        var displayDPI: Double?

        var effectiveSensitivity: Double {
            useWindowsAcceleration ?? true ? 10 : Self.valid(sensitivity, default: 10, range: 1 ... 20)
        }

        var effectiveDisplayDPI: Double {
            useWindowsAcceleration ?? true ? 96 : Self.valid(displayDPI, default: 96, range: 48 ... 384)
        }

        private static func valid(_ value: Double?, default fallback: Double, range: ClosedRange<Double>) -> Double {
            guard let value, value.isFinite else { return fallback }
            return min(max(value, range.lowerBound), range.upperBound)
        }

        func merge(into other: inout Self) {
            if let enabled { other.enabled = enabled }
            if let useWindowsAcceleration { other.useWindowsAcceleration = useWindowsAcceleration }
            if let sensitivity { other.sensitivity = sensitivity }
            if let displayDPI { other.displayDPI = displayDPI }
        }
    }
}

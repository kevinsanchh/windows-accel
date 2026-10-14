// MIT License
// Copyright (c) 2021-2026 LinearMouse

import Foundation

protocol PointerSettingsTarget: AnyObject {
    var supportsLinearPointerScaling: Bool { get }
    func setDisablePointerAcceleration(_ value: Bool) -> Bool
    func setPointerAcceleration(_ value: Double) -> Bool
    func setPointerSpeed(_ value: Double) -> Bool
    func restorePointerAcceleration() -> Bool
    func restorePointerSpeed() -> Bool
}

extension Device: PointerSettingsTarget {}

/// Main-thread state for one device. A failed or partially completed application
/// invalidates the snapshot, including when the next request returns to an older scheme.
final class PointerSchemeApplicationState {
    private(set) var snapshot: Scheme?
    private let readinessLock = NSLock()
    private var customAccelerationReady = false

    /// EventThread may transform only after the native 1:1 baseline succeeded.
    var isCustomAccelerationReady: Bool {
        readinessLock.lock()
        defer { readinessLock.unlock() }
        return customAccelerationReady
    }

    private func setCustomAccelerationReady(_ ready: Bool) {
        readinessLock.lock()
        customAccelerationReady = ready
        readinessLock.unlock()
    }

    @discardableResult
    func apply(_ scheme: Scheme, to target: PointerSettingsTarget) -> Bool {
        let next = Self.normalizeResolvedScheme(scheme)
        let diff = SchemeDiff(previous: snapshot, current: next)
        guard PointerSchemeApplier.apply(diff, to: target) else {
            invalidate()
            return false
        }
        snapshot = next
        setCustomAccelerationReady(next.pointer.customAcceleration?.enabled == true)
        return true
    }

    /// Normalize only after matching and merging, never on raw configuration rules.
    private static func normalizeResolvedScheme(_ resolvedScheme: Scheme) -> Scheme {
        var scheme = resolvedScheme
        scheme.if = nil
        if case .unset = scheme.pointer.speed {
            scheme.pointer.speed = nil
        }
        if case .unset = scheme.pointer.acceleration {
            scheme.pointer.acceleration = nil
        }
        scheme.pointer.disableAcceleration = scheme.pointer.disableAcceleration ?? false
        return scheme
    }

    func invalidate() {
        setCustomAccelerationReady(false)
        snapshot = nil
    }
}

enum PointerSchemeApplier {
    /// Applies changes in dependency order. No hardware reads are used for diffing.
    static func apply(_ diff: SchemeDiff, to device: PointerSettingsTarget) -> Bool {
        let pointer = diff.current.pointer
        let disabled = pointer.disableAcceleration == true
        let customEnabled = pointer.customAcceleration?.enabled == true
        let customModeChanged = diff.previous == nil ||
            (diff.previous?.pointer.customAcceleration?.enabled == true) != customEnabled
        if customEnabled {
            // Native linear tracking at 1 gives the transformer a 1:1 baseline.
            // Legacy drivers use -1 to bypass both acceleration and sensitivity.
            guard customModeChanged || diff.changed(\.pointer.disableAcceleration) ||
                diff.changed(\.pointer.acceleration) || diff.changed(\.pointer.speed) else { return true }
            if device.supportsLinearPointerScaling {
                guard device.setDisablePointerAcceleration(true) else { return false }
                return device.setPointerAcceleration(1)
            }
            return device.setPointerAcceleration(-1)
        }
        let modeChanged = diff.changed(\.pointer.disableAcceleration) || customModeChanged
        if device.supportsLinearPointerScaling, modeChanged {
            guard device.setDisablePointerAcceleration(disabled) else {
                return false
            }
        }

        // Speed changes while disabled are recorded but not applied. Apply speed
        // when re-enabling even if its value is identical in both snapshots.
        let speedChanged = !disabled && (modeChanged || diff.changed(\.pointer.speed))
        var speedSucceeded = true
        if speedChanged {
            if case let .value(value) = pointer.speed {
                speedSucceeded = device.setPointerSpeed(value.asTruncatedDouble)
            } else {
                speedSucceeded = device.restorePointerSpeed()
            }
        }

        if disabled, !device.supportsLinearPointerScaling {
            return !modeChanged || device.setPointerAcceleration(-1)
        }

        // PointerKit reapplies acceleration when setting resolution. Even when
        // that operation fails, attempt the target acceleration independently.
        var accelerationSucceeded = true
        if modeChanged || speedChanged || diff.changed(\.pointer.acceleration) {
            if case let .value(value) = pointer.acceleration {
                accelerationSucceeded = device.setPointerAcceleration(value.asTruncatedDouble)
            } else {
                accelerationSucceeded = device.restorePointerAcceleration()
            }
        }
        return speedSucceeded && accelerationSucceeded
    }
}

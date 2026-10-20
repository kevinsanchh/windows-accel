// MIT License
// Copyright (c) 2021-2026 LinearMouse

import SwiftUI

struct CustomPointerAccelerationSettings: View {
    @Binding var enabled: Bool
    @Binding var useWindowsAcceleration: Bool
    @Binding var sensitivity: Double
    @Binding var displayDPI: Double

    var body: some View {
        Toggle("Custom pointer acceleration", isOn: $enabled.animation())
        if enabled {
            Toggle("Use Windows acceleration", isOn: $useWindowsAcceleration.animation())
            Text(useWindowsAcceleration
                 ? "Windows 10/11 Enhance pointer precision at 96 logical DPI."
                 : "Windows 10/11 Enhance pointer precision with custom sensitivity and logical display DPI.")
                .settingsDescriptionStyle()
            control("Sensitivity", value: $sensitivity, range: 1 ... 20, formatter: Self.sensitivityFormatter)
            Text("Sensitivity 10.00 matches Windows 6/11. Sensitivity scales the Windows curve in both modes.")
                .settingsDescriptionStyle()
            if !useWindowsAcceleration {
                control("Windows logical display DPI", value: $displayDPI, range: 48 ... 384, formatter: formatter)
                Text("Display DPI: 96 = 100%, 120 = 125%, 144 = 150%. The Windows curve and counts per poll remain unchanged.")
                    .settingsDescriptionStyle()
            }
            Text("Native pointer acceleration and tracking speed are overridden while enabled.")
                .settingsDescriptionStyle()
        }
    }

    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, formatter: NumberFormatter) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Slider(value: value, in: range) { Text(title) }
            DeferredNumberField(value: value, formatter: formatter, range: range)
                .frame(width: 80)
                .accessibility(label: Text(title))
        }
    }

    static var sensitivityFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.thousandSeparator = ""
        return formatter
    }
}

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
                 ? "Windows 10/11 Enhance pointer precision, at default sensitivity and 96 logical DPI."
                 : "Windows 10/11 Enhance pointer precision with custom sensitivity and logical display DPI.")
                .settingsDescriptionStyle()
            if !useWindowsAcceleration {
                control("Sensitivity", value: $sensitivity, range: 1 ... 20)
                control("Windows logical display DPI", value: $displayDPI, range: 48 ... 384)
                Text("Sensitivity 10 matches Windows 6/11. Display DPI: 96 = 100%, 120 = 125%, 144 = 150%. The Windows curve and counts per poll remain unchanged.")
                    .settingsDescriptionStyle()
            }
            Text("Native pointer acceleration and tracking speed are overridden while enabled.")
                .settingsDescriptionStyle()
        }
    }

    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Slider(value: value, in: range) { Text(title) }
            DeferredNumberField(value: value, formatter: formatter, range: range)
                .frame(width: 80)
                .accessibility(label: Text(title))
        }
    }

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.allowsFloats = false
        formatter.thousandSeparator = ""
        return formatter
    }
}

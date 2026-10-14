// MIT License
// Copyright (c) 2021-2026 LinearMouse

@testable import LinearMouse
import SwiftUI
import XCTest

final class CustomPointerAccelerationRenderingTests: XCTestCase {
    @MainActor
    func testRenderDisabledWindowsAndCustomModes() throws {
        for (name, enabled, windows) in [("disabled", false, true), ("windows", true, true), ("custom", true, false)] {
            let view = NSHostingView(rootView:
                VStack(alignment: .leading, spacing: 12) {
                    CustomPointerAccelerationSettings(enabled: .constant(enabled),
                        useWindowsAcceleration: .constant(windows), sensitivity: .constant(10), displayDPI: .constant(96))
                }.padding(20).frame(width: 600, height: 340)
                    .background(Color(NSColor.windowBackgroundColor))
            )
            view.frame = CGRect(x: 0, y: 0, width: 600, height: 340)
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "Custom pointer acceleration: \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            try data.write(to: URL(fileURLWithPath: "/tmp/windows-acceleration-\(name).png"))
        }
    }
}

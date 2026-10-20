# Windows pointer acceleration (local fork)

Open **Pointer → Custom pointer acceleration** and enable the section.
**Use Windows acceleration** is enabled by default. It selects the Windows
8–11 Enhance pointer precision curve at sensitivity 10 (Windows 6/11) and
96 logical display DPI. The sensitivity slider applies in both modes and accepts
values from 1.00 to 20.00 in hundredths. Its default is 10.00. Windows mode
ignores the saved custom display DPI.

Use the slider or numeric input to adjust sensitivity while **Use Windows
acceleration** is on. Sensitivity scales all gains by sensitivity / 10 without
changing the curve's input thresholds. Fractional sensitivity extends the
Windows registry's integer settings using the same linear scaling formula.

Turn off **Use Windows acceleration** to also edit Windows logical display DPI
(48–384) with a slider or numeric field. DPI 96, 120 and
144 correspond to Windows display scaling of 100%, 125% and 150%. These are
Windows logical DPI values, not the mouse sensor's hardware DPI.

The transfer function uses the exact registry 16.16 knots in
`windows-mouse-accel.md`, radial magnitude, the 3.5 counts-per-packet divisor,
linear interpolation of output velocity, final-segment extrapolation, and
Windows 10/11's 120 normalization divisor. Both axes share one gain. Fractional
remainders are accumulated and truncated toward zero, then reset per axis on
zero movement or direction reversal. The curve knots and remainder policy are
not exposed as sliders. There is no polling-rate normalization or velocity
smoothing: use the same mouse DPI and polling rate as the Windows system being
matched.

While enabled, the device uses native linear tracking at 1 on modern macOS or
acceleration -1 on legacy drivers, and the event transformer updates both
relative deltas and cursor location for movement and all three drag types.
Display clamping uses actual display bounds, including negative origins and
separated displays. Retina coordinates are logical points. Native pointer
controls become available again when the section is disabled, and saved native
settings are reapplied. Hardware DPI is preserved.

The transformer only runs for an identified device after its native baseline
writes succeed. Unsupported or unidentified devices pass through unchanged.
Exact physical behavior still depends on macOS exposing unaccelerated,
uncoalesced counts and the device accepting linear mode; automated tests do
not establish hardware parity with a Windows workstation.

This is a local change. To build and test without a signing identity:

```sh
xcodebuild test -project LinearMouse.xcodeproj -scheme LinearMouse \
  -destination 'platform=macOS' -derivedDataPath /tmp/windows-accel-build \
  CODE_SIGNING_ALLOWED=NO
```

The app is produced at
`/tmp/windows-accel-build/Build/Products/Debug/LinearMouse.app`.
Grant LinearMouse its normal macOS permissions when running it to use the
system-wide event tap. No settings are enabled automatically by this change.

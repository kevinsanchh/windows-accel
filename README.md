<h1 align="center">
  <a href="https://linearmouse.app">
    <img src="logo.svg" alt="LinearMouse" width="128" height="128" />
    <br />
    WindowsAccel
  </a>
</h1>

<p align="center">
  <a href="https://github.com/linearmouse/linearmouse/releases/latest"><img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/linearmouse/linearmouse?sort=semver"></a>
  <a href="https://github.com/linearmouse/linearmouse/releases/latest/download/LinearMouse.dmg"><img src="https://img.shields.io/github/downloads/linearmouse/linearmouse/total" alt="Downloads" /></a>
  <img src="https://img.shields.io/github/license/linearmouse/linearmouse" alt="MIT License" />
</p>

<p align="center">
The mouse and trackpad utility for Mac.
</p>

## About this fork

**WindowsAccel** is built on top of the existing [LinearMouse](https://github.com/linearmouse/linearmouse) project. This fork adds an optional Windows-compatible mouse acceleration mode for users who want Windows pointer behavior on macOS. Google Gemini Deep Research, using the Argon model, was used to research the Windows mouse acceleration formula; the resulting implementation and research notes are documented in this repository.

## Windows mouse acceleration

Enable **Pointer → Custom pointer acceleration** in WindowsAccel settings, then leave **Use Windows acceleration** enabled to use the Windows 8–11 Enhance pointer precision curve. The feature applies the curve to mouse movement and supports configurable sensitivity; the default sensitivity of 10.00 matches Windows 6/11 at 96 logical DPI. You can disable Windows mode to set a custom logical display DPI instead. Native macOS pointer acceleration and tracking speed are overridden while custom acceleration is active and restored when it is turned off.

See the [Windows pointer acceleration guide](Documentation/WindowsPointerAcceleration.md) for behavior, configuration, limitations, and build instructions. The detailed formula research is in [`windows-mouse-accel.md`](../windows-mouse-accel.md).

## Get started

[Download LinearMouse](https://github.com/linearmouse/linearmouse/releases/latest/download/LinearMouse.dmg) or visit [linearmouse.app](https://linearmouse.app) to learn more.

## Contribute

Bug reports and pull requests are welcome. See the [contributing guide](CONTRIBUTING.md) to get started.

## Help translate

Found a translation that could be better? Copy this prompt into your coding agent and add the language and what you'd like to fix:

```text
Fix the translation issues below in https://github.com/linearmouse/linearmouse.
Check where the text is used in the app, make the corrections, and open a pull request.

[Describe the language and translation issues here.]
```

Prefer a translation editor? You can also contribute through [Crowdin](https://crowdin.com/project/linearmouse).

## Sponsors

Thank you to everyone who supports LinearMouse.

You can support the project through [GitHub Sponsors](https://github.com/sponsors/linearmouse), [Open Collective](https://opencollective.com/linearmouse), or [Ko-fi](https://ko-fi.com/lujjjh).

## Credits

See [LinearMouse/ThirdPartyNotices](LinearMouse/ThirdPartyNotices) for the projects that LinearMouse builds on and their licenses.

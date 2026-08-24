# Live Activity debugging

The Live Activity target contains an `ActivityConfiguration`, not a regular Home Screen widget. Xcode therefore must launch the host app instead of asking SpringBoard to show the extension as a widget.

## Run from Xcode

1. Select either the `SteakCopilot` or `SteakCopilotLiveActivity` shared scheme.
2. Choose an iPhone simulator or device.
3. Run the scheme. Both shared schemes launch `SteakCopilot.app`; the app embeds and registers `SteakCopilotLiveActivity.appex`.
4. Start a cooking session in the app to request the Live Activity.

The `SteakCopilotLiveActivity` scheme intentionally runs the host app. Running a generated extension-only scheme can produce `SBAvocadoDebuggingControllerErrorDomain` / “Failed to get descriptors” because a Live Activity is not a standalone widget that SpringBoard can open directly.

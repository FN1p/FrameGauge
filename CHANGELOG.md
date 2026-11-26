# Changelog

## 0.8.0 — first public beta candidate
- Clarified installation paths and troubleshooting for nested addons folders.
- Added release packaging metadata, store submission instructions and release notes.
- Runtime algorithms and demo gameplay unchanged from 0.7.1; editor version label updated.
- Prior 0.7.1 manually tested in a Windows 3D game; 0.8.0 engine and CI checks remain pending.

## 0.7.1 — release candidate
- Correct editor hint for render timing.
- Preserve unknown local configuration keys on save.
- Extend graphical smoke test for re-bound shortcut and config compatibility.
- Pin engine validation to Godot 4.7.2; selectable renderer.
- Add Windows validation launcher and CI for Windows and Linux; release archives can be reproduced.
- No engine validation has been run in the build container.

## 0.7.0 — stabilization candidate
- Prefix all script preload aliases with FG to avoid native-class name conflicts.
- Linux host CPU counters retain integer precision; reject invalid deltas.
- Avoid unnecessary resets when HUD visibility is unchanged; refresh host counters after metric selection.
- Restore demo FPS/VSync on exit; keep unavailable HUD controls disabled after tests; check actual uncapped state.
- Add isolated validation runner, fifth unit test, graphical HUD smoke scene and GitHub Actions workflow.
- All 24 metrics and existing features remain free; engine and CI runs pending.

## 0.6.2 Hotfix 1
- Fix native Shortcut class collision.

## 0.6.2 — settings candidate
- Complete runtime settings: Appearance, Metrics, Controls, Advanced.
- Rebind menu shortcut locally or set project defaults in the editor Controls tab.
- Reject reserved combinations; retain Alt+F9 default.
- Live refresh rate, graph and sample windows, render timing opt-in.
- Apply / Save & close / Cancel; restore settings after cancellation; input shield for GUI clicks.
- Physics and benchmark algorithms unchanged. Godot runtime verification pending.

## 0.6.1 — usability candidate
- Visible HUD Settings and demo-lab shortcut; Alt+F9 opens even with hidden HUD.
- Quick size presets, corner/layout controls and runtime metric selection.
- Save local appearance, layout and metric selection; reset to project defaults.
- Editor opens Style first and provides quick size presets.
- Physics and benchmark algorithms unchanged. Engine verification pending.

## 0.6.0 — beta candidate
- FrameGauge brand and SVG icon; PFT Studio remains publisher.
- Preserves addon path, autoload, settings, debugger protocol and appearance config.
- Guards A/B when runtime is unavailable or FPS cap is enabled.
- Rejects non-finite locally saved appearance values.
- Corrected documentation and added validation runner and release checklist.
- All existing features remain free. Engine and GUI validation pending.

## 0.5.0
- Appearance panel, live size/background/overall opacity, compact UI.

## 0.4.0
- 24 individual metrics, layouts and presets.

## 0.3.0
- Editor dock, live debug data, workload presets and 60-second test.

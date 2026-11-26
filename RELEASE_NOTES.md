# FrameGauge 0.8.0 Beta

First public beta of FrameGauge, a free performance-monitoring toolkit for Godot by PFT Studio.

- Customizable in-game HUD, FPS and frame-time statistics, 24 selectable metrics.
- Memory, rendering and physics counters; optional editor telemetry.
- Runtime settings, scale, opacity, positioning and a configurable settings shortcut.
- 3D workload and HUD A/B tests in the separate demo project.

Install `FrameGauge_0.8.0_addon.zip` beside your `project.godot` and enable FrameGauge Free in Project Settings > Plugins. F9 toggles the HUD; Alt+F9 opens settings by default.

Beta limitations: Windows CPU/GPU utilization percentages are not implemented; Linux utilization is experimental. Renderer-specific counters may be unavailable. The demo does not establish deterministic physics benchmark results. Report bugs with Godot version, OS, renderer and reproduction steps.

Free under MIT once publisher approval is confirmed. Developed with AI assistance.

Before publishing: confirm automated checks and add actual tested OS/renderer details. Do not claim untested compatibility.

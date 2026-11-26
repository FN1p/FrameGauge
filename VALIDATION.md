# FrameGauge 0.8.0 — validation record

Based on the supplied 0.7.1 release candidate. Runtime code, metric configuration, tests and demo gameplay are unchanged; the editor dock version string is updated. The user reported that 0.7.1 launched in a Windows 3D game and the menu appeared to work. This is a manual observation, not a complete QA result.

Python source checks and ZIP round-trip checks are performed during packaging. Godot is not available in the current environment; 0.8.0 has not been parsed or run by Godot, nor have the CI jobs run. No Linux or exported game validation is claimed.

Run CHECK_WINDOWS.cmd (Python 3 required), select Godot 4.7.2, check FRAMEGAUGE_QA.log. Run the existing GitHub Actions workflow and check both jobs. Manually verify clean install/uninstall, settings, renderers, export and repeated HUD overhead before submission. Publish only after relevant gates pass; mark the version unstable/beta. See RELEASE_CHECKLIST.md.

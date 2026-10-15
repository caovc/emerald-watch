# Battlefield camera controls

- Mouse wheel: zoom toward or away from the ground under the pointer
- Middle mouse drag or Shift + left drag: pan without selecting/building
- Home or the HUD reset button: return to the original centered view
- Touch: drag with one finger to pan; pinch with two fingers to zoom
- A short stationary touch still selects a tower/build pad on release
- Trackpad magnify/pan gestures are supported when supplied by the platform

The orthographic camera stays at its existing angle. Zoom is limited to 18–28 (the same bounds as Settings); ground-plane pan is limited to ±8 on X and ±6 on Z. HUD and modal interactions do not move the camera. Opening a modal, losing focus, or resetting cancels any active drag. Camera controls do not use the right mouse button, which remains cancel-selection, or Space, which starts a wave.

Implementation: `scripts/camera_controller.gd`, installed once after the main scene's settings UI. Level restarts may call `reset_view()` to recenter. The controller keeps the in-memory Settings zoom value in sync; camera motion alone does not write the settings file.

Headless regression command (use disposable XDG directories because scene tests can change settings):

```sh
XDG_DATA_HOME=/tmp/ew-camera/data XDG_CACHE_HOME=/tmp/ew-camera/cache XDG_CONFIG_HOME=/tmp/ew-camera/config godot --headless --path . --script res://tests/camera_controls.gd
```

Synthetic input checks do not substitute for real-device multitouch/trackpad QA.

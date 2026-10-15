# Mobile and desktop display adaptation

The window uses `canvas_items` with `expand`, so the 3D viewport and HUD fill the available aspect ratio without stretching geometry or adding fixed-aspect side bars. iOS/Android use sensor-landscape orientation. Desktop remains windowed/resizable with its existing fullscreen preference.

`responsive_layout.gd` selects a 960 × 600 minimum logical canvas on mobile versus 1440 × 900 on desktop. Wider displays gain horizontal battlefield space; tablet ratios gain vertical space. Mobile controls have 72 logical-unit minimum touch height (45 points at 375-point landscape height; 46.8 at 390 points), larger text, separate status and control rows, bottom tower dock and thumb-accessible ability/entrance controls. Desktop keeps mouse shortcuts and its single-row toolbar.

The native display safe rectangle is converted from physical window coordinates to viewport coordinates. Only UI is inset; the world continues to draw behind the notch/home-indicator area. Context details and modal content scroll rather than shrink or crop. Mobile settings/codex/designer sections stack; the campaign grid uses two columns. The designer's 15-column grid retains large cells and can scroll horizontally. Desktop layouts stay multi-column.

Camera framing preserves vertical scale on wide screens and expands on tablet ratios. Zoom remains a logical 18–28 setting, independent of aspect correction; ray picking and drag/pinch use viewport coordinates. Mobile operating-system fullscreen is not changed by desktop saved preferences.

## Verification

- `tests/responsive_layout.gd`: headless synthetic viewport geometry at 1440×900, 1920×1080, 1024×768, 844×390, 667×375, and 1366×1024; header/dock/action containment, target heights, camera projection round trips, simulated cutouts, context bounds, and modal scroll wrappers
- Run once normally and once with `-- --mobile-ui` to exercise both layout paths
- `test_safe_area` metadata is a test-only logical safe-rectangle injection; production uses DisplayServer

The cloud desktop also completed the same 101-assertion suite in each mode with real GPU rendering and saved 12 battlefield screenshots across these sizes. The 844×390 and 667×375 phone layouts, 1024×768 tablet layout, and 1440×900 desktop layout were visually inspected: no aspect bars, distorted geometry, clipped HUD, or dock overflow. These are synthetic device-size renders, not physical-iPhone validation. Modal scroll behavior and simulated safe-area bounds were checked programmatically; modal touch feel and physical-device safe-area behavior remain to be verified. Final acceptance should include touch operation on an iPhone with a notch/home indicator, both landscape directions, a 4:3 tablet, and desktop resizing. Inspect all campaign routes, open/close every modal, scroll the designer grid, then test tap/drag build, pan, pinch, and interruption cancellation.

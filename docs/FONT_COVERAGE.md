# Bundled font coverage

The original small UI subset did not contain 118 characters introduced by the designer, replay verification, extra maps and camera controls. Linux system fallback could hide the omissions.

The bundled assets/ui-font.otf was regenerated from the installed Noto Sans CJK SC Regular source (NotoSansCJK-Regular.ttc, face 2), retaining all current scripts' characters, printable ASCII, CJK punctuation and CJK Unified Ideographs U+4E00–U+9FEF for locally authored level names. The existing SIL Open Font License and copyright notices remain in assets/FONT-LICENSE.txt.

Automated cmap coverage checks find no missing non-ASCII characters from the current scripts. Characters outside those ranges, such as rare extended ideographs or arbitrary emoji in a custom level name, may still depend on the target system font fallback. Font coverage is not a visual-rendering acceptance test.

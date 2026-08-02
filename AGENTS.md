# AGENTS.md — zig-calc

Guide for AI agents working in this repo. Full function-by-function reference in [FUNCTION-CATALOG.md](FUNCTION-CATALOG.md).

## What this is
Calculator firmware for RP2350 (Raspberry Pi Pico 2) + ILI9341 240x320 SPI display + 6x6 matrix keypad (microzig). Current milestone: a faux REPL (type a line, Enter echoes it, Up/Down highlight history, Enter pastes) plus full-screen picker menus that insert function strings like `sin(` into the input.

## Commands
- Build: `zig build` (PowerShell: `zig build 2>&1`).
- Output: `zig-out/firmware/zig-calc.uf2`. Target: `pico2_arm`, `ReleaseSmall`.
- No test/lint targets. Verify by compiling.

## File map
- `src/main.zig` — REPL, MenuState, draw/render logic, main loop, pin config. **Most work happens here.**
- `src/layout.zig` — `KeyKind` union, `Key` (orig/alpha/shift), `KEY_LAYOUT`, `MenuItem`, `menu()`/`unicode()` helpers.
- `src/gfx.zig` — `DisplayGFX(Display)`, `font5x7`, colors, `drawTextLine`, primitives.
- `src/keypad.zig` — matrix scan, `buttonNumber`, `firstPressed`.
- `src/ili9341.zig` — display driver (unlikely to touch).
- `build.zig`, `key-layout.md` (authoritative physical layout).

## Hard facts / invariants
- **Keypad wiring**: GPIO6–11 = rows 0–5 (inputs, `.pull=.down`), GPIO0–5 = cols 0–5 (outputs).
  Button = `row*6 + (6-col)` → row0/col5=1, row0/col4=2, ... row5/col0=36.
- **`KEY_LAYOUT` is indexed by physical column**: the first entry of each row is col5. `main` computes `row=(btn-1)/6`, `col=5-((btn-1)%6)`.
- **Rendering grid** (row = 8px band, font 5x7 + 1px spacing): top bar y=0, transcript y=8..312 (38 rows), prompt y=312, cursor block at `12 + cursor*6`.
- **All text goes through `drawTextLine`** — one batched SPI transfer per 8px band, clears the whole band to `bg`. Prefer it over `write`/`print` for row-based UI.
- **Sentinels**: UTF-8 script-e → `0xEE` (glyph 96), pi → `0xEF` (glyph 97). Pi is `CF 80`, NOT `CE 80`.
- **Capacity**: `input_cap=38`, `hist_cap=32`, `ring_cap=38`. History is the single source of truth; the transcript is derived, so nothing is lost.
- **`Repl.init()` must use default field init (`.{}`)**. `var r: Repl = undefined;` skips all defaults → garbage-state bugs.
- **`render()` fills the screen black first**, then redraws bar/output/prompt. Use it to fully restore the REPL after any full-screen overlay (menus). `drawMenu` similarly fillScreens black + red outline.
- **Menu model**: `MenuState { open, items: []const MenuItem, sel }`. `items` aliases static data in layout.zig. While `menu.open`, the main loop routes keys to `handleMenuKey` (Up/Down wrap; Enter/digit 1-6 paste value + close; backspace/clear close).

## Zig 0.17.0-dev quirks (this toolchain)
- Brace-less `if` + `-=` in a switch arm fails ("invalid left-hand side to assignment") — use block bodies.
- Void union variants need `.{ .tag = {} }`.
- Payload-union call syntax `.arrow(.left)` unsupported — use `.{ .arrow = .left }`.
- Temporary array literals for `menu(...)` need the address: `menu(&.{ .{...}, ... })`.

## Data flow (main loop)
scan → double-scan debounce → ignore repeats → `firstPressed` → row/col → `KEY_LAYOUT` → if `menu.open` route to `handleMenuKey`, else resolve `kind` via `choose(shift/alpha overrides)` → mutate REPL → redraw (`redraw_all`/`bar_changed`/always prompt; skip all three while menu is open).

# Function Catalog

Catalog of every function/type in the firmware, what it does, and where it lives.
Project: RP2350 (Pico 2) calculator with ILI9341 display and 6x6 matrix keypad.

For the **calculator's math functions** (sin, solve, nCr, etc.) see
[CALCULATOR-FUNCTIONS.md](CALCULATOR-FUNCTIONS.md).

---

## `src/main.zig` — application / REPL

### `Repl` (struct)
State for the command-line-style input area. Key fields:
`input[input_cap]`, `input_len`, `cursor`, `alpha_on`, `shift_on`,
`history[hist_cap][input_cap]`, `hist_lens`, `hist_count`, `hl_k`
(1..hist_count = k-th newest entry highlighted, 0 = none).

| Function | Signature | What it does |
|---|---|---|
| `init` | `fn init() Repl` | Returns a `Repl` with all fields default-initialized. **Must not** be built via `var r: Repl = undefined;` — that skips every field default and leaves garbage state. |
| `copyBytes` | `fn copyBytes(dst: []u8, src: []const u8) void` | Copy `src` into `dst` byte-for-byte. |
| `insertByte` | `fn insertByte(self: *Repl, ch: u8) void` | Insert one byte at the cursor, shifting the rest right. No-op at `input_cap`. |
| `insert` | `fn insert(self: *Repl, s: []const u8) void` | Insert a unicode string. Collapses UTF-8 script-e (`E2 84 AF`) and pi (`CF 80`) into single sentinel bytes `0xEE` / `0xEF` so they render as custom glyphs. |
| `backspace` | `fn backspace(self: *Repl) void` | Delete the byte before the cursor, shifting left. No-op at start. |
| `clearInput` | `fn clearInput(self: *Repl) void` | Reset input length and cursor to 0 (does not touch history). |
| `moveHighlight` | `fn moveHighlight(self: *Repl, up: bool) void` | Move history highlight up/down by one entry, clamped to `1..hist_count`. |
| `paste` | `fn paste(self: *Repl) void` | Copy the highlighted history entry into the input, place cursor at end, clear highlight. |
| `addHistory` | `fn addHistory(self: *Repl) void` | Append the current input to history; when full, shift out the oldest entry. |
| `eval` | `fn eval(self: *Repl) void` | "Evaluate" the input: append to history, clear input, clear highlight. Faux REPL — no math yet. |

### `MenuState` (struct)
State for the full-screen picker. Fields: `open: bool`, `items: []const layout_mod.MenuItem`,
`sel: usize`. `items` points at static data in `layout.zig` (no copy).

### Top-level functions

| Function | Signature | What it does |
|---|---|---|
| `choose` | `fn choose(alt, orig: layout_mod.KeyKind) layout_mod.KeyKind` | Returns `alt` unless it is `.none`, in which case `orig`. Used for alpha/shift overrides. |
| `redrawBar` | `fn redrawBar(gfx: *Gfx, repl: *const Repl) !void` | Draws the top bar row (y=0): "REPL" title plus right-aligned SHIFT/ALPHA mode label. Cyan on black. |
| `redrawOutput` | `fn redrawOutput(gfx: *Gfx, repl: *const Repl) !void` | Renders the transcript (y=8..312). Every history entry becomes two rows: prompt (`> line`, white) and result (same text, darkgrey). Highlighted entry is yellow-inverted. Derives everything from `history`, so no lines are ever lost. |
| `redrawPrompt` | `fn redrawPrompt(gfx: *Gfx, repl: *const Repl) !void` | Draws the `> input` prompt row at y=312 plus a green cursor block at `12 + cursor*6`. |
| `render` | `fn render(gfx: *Gfx, repl: *const Repl) !void` | Full REPL redraw: clears screen to black, then bar + output + prompt. **Call this after anything fills the screen (e.g. a menu) so all menu traces are erased.** |
| `drawMenu` | `fn drawMenu(gfx: *Gfx, menu: *const MenuState) !void` | Full-screen menu: black background, red outline rect (`drawRect(2,2,236,316)`), one row per item as `N label`, selected row yellow-inverted. |
| `handleMenuKey` | `fn handleMenuKey(menu: *MenuState, repl: *Repl, kind) bool` | Route a key while a menu is open. Up/Down move selection (wraps); Enter pastes `items[sel].value` and closes; digit keys 1-6 paste that item and close; backspace/clear close without pasting. Returns true if the screen must be redrawn. |
| `main` | `pub fn main() !void` | Setup (pins, SPI, display, keypad) then the main loop: debounce scan, resolve key, route to menu or REPL, redraw. |

### Constants (main.zig)
- `input_cap = 38` — max input/line length (chars).
- `hist_cap = 32` — history entries kept.
- `ring_cap = 38` — output rows that fit between y=8 and y=312.

---

## `src/layout.zig` — key layout

| Name | Type/Signature | What it does |
|---|---|---|
| `ROWS`, `COLS` | `pub const = 6` | Keypad dimensions. |
| `MenuItem` | `struct { label: []const u8, value: []const u8 }` | One menu entry: what is shown vs. what gets inserted into the input. |
| `KeyKind` | `union(enum)` | What a key does. Variants: `unicode: []const u8`, `alpha`, `shift`, `menu: []const MenuItem`, `pos_neg`, `arrow: enum{left,down,up,right}`, `backspace`, `clear`, `enter`, `none`. |
| `unicode` | `pub fn unicode(s: []const u8) KeyKind` | Helper: builds a `.unicode` key. |
| `menu` | `pub fn menu(s: []const MenuItem) KeyKind` | Helper: builds a `.menu` key from an array of items. Pass `&.{ ... }` for a temporary array literal. |
| `Key` | `struct { orig: KeyKind, alpha: KeyKind = .none, shift: KeyKind = .none }` | A physical key with orig/alpha/shift actions. |
| `KEY_LAYOUT` | `pub const [ROWS][COLS]Key` | The physical key map, indexed `[row][col]` where `col` is the physical column (col5 = first entry). Written as orig/alpha/shift. Menus: trig (6), calc (3), stats (4). |

---

## `src/gfx.zig` — graphics helpers

`DisplayGFX(Display)` builds a struct over an ILI9341. `Colors` is a `ColorTable` (black, white, red, yellow, cyan, green, darkgrey, orange, pink, ...). `font5x7` is a `[98][5]u8` glyph table; indexes 96 = script-e (ℯ, sentinel 0xEE) and 97 = pi (π, sentinel 0xEF).

| Function | Signature | What it does |
|---|---|---|
| `init` | `fn init(display, w, h) Self` | Create a GFX context sized w×h. |
| `drawPixel` | `fn drawPixel(x, y, c) !void` | Plot one pixel. |
| `pushRun` | `fn pushRun(count, c) !void` | (private) Push `count` copies of color `c` in 64-pixel batches. |
| `drawFastVLine` | `fn drawFastVLine(x, y, h, c) !void` | Vertical line in one address window. |
| `drawFastHLine` | `fn drawFastHLine(x, y, w, c) !void` | Horizontal line in one address window. |
| `fillRect` | `fn fillRect(x, y, w, h, c) !void` | Filled rectangle. |
| `drawRect` | `fn drawRect(x, y, w, h, c) !void` | Rectangle outline (4 lines). Used for the menu border. |
| `fillScreen` | `fn fillScreen(c) !void` | Fill the whole display. |
| `drawLine` | `fn drawLine(x0,y0,x1,y1,c) !void` | Bresenham line. |
| `drawCircle` / `fillCircle` | `fn (x0, y0, r, c) !void` | Circle outline / filled circle. |
| `drawTriangle` / `fillTriangle` | `fn (x0,y0,x1,y1,x2,y2,c) !void` | Triangle outline / filled. |
| `drawRoundRect` / `fillRoundRect` | `fn (x, y, w, h, r, c) !void` | Rounded rect outline / filled. |
| `drawChar` | `fn drawChar(x, y, c: u8, fg, bg, size) !void` | Draw one ASCII glyph (0x20..0x7E) at a position; `size` scales pixels. |
| `setCursor` / `setTextColor` / `setTextColorBg` / `setTextSize` / `setTextWrap` | setters | Configure the stateful `write`/`print` cursor. |
| `write` | `fn write(c: u8) !void` | Print one char at the cursor (handles `\n`, `\r`, wrapping). |
| `print` | `fn print(s: []const u8) !void` | Print a string via `write`. |
| `drawTextLine` | `fn drawTextLine(y, s, fg, bg) !void` | Draw a full-width 8px row band in **one batched transfer**. Maps 0xEE→glyph 96, 0xEF→glyph 97. Used by all row-based rendering. |

---

## `src/keypad.zig` — 6x6 matrix scanning

| Name | Type/Signature | What it does |
|---|---|---|
| `ROWS`, `COLS` | `pub const = 6` | Matrix dimensions. |
| `PressedState` | `pub const = [COLS]u6` | Bitmask per column; bit `ri` set means row `ri` is pressed on that column. |
| `Keypad` (struct) | `row_pins`, `col_pins` | Holds pin arrays. |
| `Keypad.init` | `fn init(row_pins, col_pins) Keypad` | Build a Keypad. |
| `Keypad.scan` | `fn scan(self) PressedState` | Drives each column high in turn, reads all rows, builds the press mask. |
| `buttonNumber` | `fn buttonNumber(row, col: u8) u8` | Map a physical (row, col) to a button number. Wiring runs right-to-left: `row*6 + (6-col)`, so row0/col5 = 1 ... row5/col0 = 36. |
| `firstPressed` | `fn firstPressed(pressed) ?u8` | Lowest-numbered button currently pressed, or null. |

---

## `src/ili9341.zig` — display driver

| Name | What it does |
|---|---|
| `ILI9341(display_cfg)` | Comptime constructor: returns a driver type for a `DisplayConfig`. |
| `Resolution` | `struct { width, height }`. |
| `ColorOrder` | `enum(u1) { rgb, bgr }` (default bgr). |
| `Rotation` | `enum(u2) { deg0, deg90, deg180, deg270 }` (default deg0). |
| `DisplayConfig` | Config struct with `lcd240x320` preset. |
| `MADCTL_*` | MADCTL instruction flag bits. |
| `madctl_from_rotation` | (private) Compute the MADCTL byte for a rotation + color order. |
| `init` | `!Self` — sets SPI mode, hard-resets, runs the full init sequence. |
| `set_spi_mode` | (private) Toggle DC pin between command (low) and data (high). |
| `hard_reset` | (private) Pulse the reset pin. |
| `range_to_bigendian_bytes` | (private) Encode two u16 window bounds as 4 big-endian bytes. |
| `init_sequence` | (private) Registers the standard ILI9341 init command block. |
| `set_address_window` | `!void` — set CASET/PASET/RAMWR; skips redundant writes using `old_*` cache. |
| `push_colors` | `!void` — write a pixel buffer as raw bytes. |
| `get_active_resolution` | Returns current resolution. |
| `set_rotation` | `!void` — change rotation, swap resolution for 90/270, rewrite MADCTL. |
| `invert_display` | `!void` — INVON/INVOFF. |
| `scroll_to` | `!void` — vertical scroll offset. |
| `set_scroll_margins` | `!void` — vertical scroll definition. |
| `readcommand8` | `!u8` — read a register byte. |
| `write_raw` / `write_command` | (private) SPI command+params writes. |
| `Command` | enum(u8) of ILI9341 command bytes. |

---

## `build.zig`

| Name | What it does |
|---|---|
| `build` | Sets up the microzig build; produces `zig-calc` firmware for the Pico 2 (`pico2_arm`), `ReleaseSmall`, root `src/main.zig`. Installs the UF2. |

## Build
```
zig build          # → zig-out/firmware/zig-calc.uf2
```

const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const ili9341 = @import("ili9341.zig");
const gfx_mod = @import("gfx.zig");
const keypad_mod = @import("keypad.zig");
const layout_mod = @import("layout.zig");
const Display = ili9341.ILI9341(.lcd240x320);
const Gfx = gfx_mod.DisplayGFX(Display);

pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

comptime {
    _ = microzig.export_startup();
}

const pin_config = rp2xxx.pins.GlobalConfiguration{
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },
    .GPIO18 = .{
        .name = "sck",
        .function = .SPI0_SCK,
    },
    .GPIO19 = .{
        .name = "mosi",
        .function = .SPI0_TX,
    },
    // we dont need miso

    .GPIO17 = .{ .name = "cs", .direction = .out },
    .GPIO16 = .{ .name = "dc", .direction = .out },
    .GPIO20 = .{ .name = "rst", .direction = .out },
    .GPIO22 = .{ .name = "bl", .direction = .out },

    .GPIO11 = .{ .name = "row5", .direction = .in, .pull = .down },
    .GPIO10 = .{ .name = "row4", .direction = .in, .pull = .down },
    .GPIO9 = .{ .name = "row3", .direction = .in, .pull = .down },
    .GPIO8 = .{ .name = "row2", .direction = .in, .pull = .down },
    .GPIO7 = .{ .name = "row1", .direction = .in, .pull = .down },
    .GPIO6 = .{ .name = "row0", .direction = .in, .pull = .down },
    .GPIO5 = .{ .name = "col5", .direction = .out },
    .GPIO4 = .{ .name = "col4", .direction = .out },
    .GPIO3 = .{ .name = "col3", .direction = .out },
    .GPIO2 = .{ .name = "col2", .direction = .out },
    .GPIO1 = .{ .name = "col1", .direction = .out },
    .GPIO0 = .{ .name = "col0", .direction = .out },
};

const input_cap = 38;
const hist_cap = 32;
const ring_cap = 38; // output rows that fit between y=8 and y=312

const Repl = struct {
    input: [input_cap]u8 = undefined,
    input_len: usize = 0,
    cursor: usize = 0,
    alpha_on: bool = false,
    shift_on: bool = false,

    history: [hist_cap][input_cap]u8 = undefined,
    hist_lens: [hist_cap]usize = undefined,
    hist_count: usize = 0,

    hl_k: usize = 0, // 1..hist_count = kth newest history line highlighted, 0 = none

    fn init() Repl {
        return .{
            .hist_lens = std.mem.zeroes([hist_cap]usize),
        };
    }

    fn copyBytes(dst: []u8, src: []const u8) void {
        for (src, 0..) |c, i| dst[i] = c;
    }

    fn insertByte(self: *Repl, ch: u8) void {
        if (self.input_len >= input_cap) return;
        var i = self.input_len;
        while (i > self.cursor) : (i -= 1)
            self.input[i] = self.input[i - 1];
        self.input[self.cursor] = ch;
        self.cursor += 1;
        self.input_len += 1;
    }

    /// Insert a unicode string. The UTF-8 script-e (Euler) and pi are stored
    /// as single sentinel bytes (0xEE / 0xEF) so they render as their own
    /// glyphs.
    fn insert(self: *Repl, s: []const u8) void {
        var i: usize = 0;
        while (i < s.len and self.input_len < input_cap) {
            if (s[i] == 0xE2 and i + 2 < s.len and s[i + 1] == 0x84 and s[i + 2] == 0xAF) {
                self.insertByte(0xEE);
                i += 3;
            } else if (s[i] == 0xCF and i + 1 < s.len and s[i + 1] == 0x80) {
                self.insertByte(0xEF);
                i += 2;
            } else {
                self.insertByte(s[i]);
                i += 1;
            }
        }
    }

    fn backspace(self: *Repl) void {
        if (self.cursor == 0) return;
        var i = self.cursor - 1;
        while (i + 1 < self.input_len) : (i += 1)
            self.input[i] = self.input[i + 1];
        self.cursor -= 1;
        self.input_len -= 1;
    }

    fn clearInput(self: *Repl) void {
        self.input_len = 0;
        self.cursor = 0;
    }

    fn moveHighlight(self: *Repl, up: bool) void {
        if (self.hist_count == 0) return;
        if (up) {
            if (self.hl_k < self.hist_count) self.hl_k += 1;
        } else {
            if (self.hl_k > 0) self.hl_k -= 1;
        }
    }

    fn paste(self: *Repl) void {
        if (self.hl_k == 0) return;
        const slot = self.hist_count - self.hl_k;
        const n = self.hist_lens[slot];
        copyBytes(self.input[0..n], self.history[slot][0..n]);
        self.input_len = n;
        self.cursor = n;
        self.hl_k = 0;
    }

    fn addHistory(self: *Repl) void {
        var slot = self.hist_count;
        if (self.hist_count == hist_cap) {
            var i: usize = 0;
            while (i + 1 < hist_cap) : (i += 1) {
                self.history[i] = self.history[i + 1];
                self.hist_lens[i] = self.hist_lens[i + 1];
            }
            slot = hist_cap - 1;
        } else {
            self.hist_count += 1;
        }
        self.hist_lens[slot] = self.input_len;
        copyBytes(self.history[slot][0..self.input_len], self.input[0..self.input_len]);
    }

    fn eval(self: *Repl) void {
        if (self.input_len == 0) return;
        self.addHistory();
        self.clearInput();
        self.hl_k = 0;
    }
};

const MenuState = struct {
    open: bool = false,
    items: []const layout_mod.MenuItem = &.{},
    sel: usize = 0,
};

fn choose(alt: layout_mod.KeyKind, orig: layout_mod.KeyKind) layout_mod.KeyKind {
    return switch (alt) {
        .none => orig,
        else => alt,
    };
}

fn redrawBar(gfx: *Gfx, repl: *const Repl) !void {
    var s: [input_cap + 2]u8 = undefined;
    @memset(s[0..], ' ');
    const title = "REPL";
    for (title, 0..) |c, i| s[i] = c;
    const mode = if (repl.shift_on) "SHIFT" else if (repl.alpha_on) "ALPHA" else "";
    if (mode.len > 0) {
        const start = (input_cap + 2) - mode.len;
        for (mode, 0..) |c, i| s[start + i] = c;
    }
    try gfx.drawTextLine(0, s[0..], Gfx.Colors.cyan, Gfx.Colors.black);
}

fn redrawOutput(gfx: *Gfx, repl: *const Repl) !void {
    const total = repl.hist_count * 2;
    const visible = @min(total, ring_cap);
    const first = total - visible;
    var i: usize = 0;
    while (i < visible) : (i += 1) {
        const g = first + i;
        const e = g / 2;
        const is_result = (g % 2) == 1;
        const n = repl.hist_lens[e];
        const y: u16 = @intCast(8 + i * 8);
        var hl = false;
        if (repl.hl_k > 0 and !is_result) {
            const slot = repl.hist_count - repl.hl_k;
            if (slot == e) hl = true;
        }
        if (hl) {
            try gfx.drawTextLine(y, repl.history[e][0..n], Gfx.Colors.black, Gfx.Colors.yellow);
        } else if (is_result) {
            try gfx.drawTextLine(y, repl.history[e][0..n], Gfx.Colors.darkgrey, Gfx.Colors.black);
        } else {
            var buf: [input_cap + 2]u8 = undefined;
            buf[0] = '>';
            buf[1] = ' ';
            for (repl.history[e][0..n], 0..) |c, j| buf[2 + j] = c;
            try gfx.drawTextLine(y, buf[0 .. n + 2], Gfx.Colors.white, Gfx.Colors.black);
        }
    }
}

fn redrawPrompt(gfx: *Gfx, repl: *const Repl) !void {
    var s: [input_cap + 2]u8 = undefined;
    s[0] = '>';
    s[1] = ' ';
    for (repl.input[0..repl.input_len], 0..) |c, i| s[2 + i] = c;
    try gfx.drawTextLine(312, s[0 .. repl.input_len + 2], Gfx.Colors.white, Gfx.Colors.black);
    const cx: u16 = @intCast(12 + repl.cursor * 6);
    try gfx.fillRect(cx, 314, 2, 5, Gfx.Colors.green);
}

/// Redraw the full REPL (bar + output + prompt). Call this after anything
/// fills the screen (e.g. a menu) so the whole transcript comes back.
fn render(gfx: *Gfx, repl: *const Repl) !void {
    try gfx.fillScreen(Gfx.Colors.black);
    try redrawBar(gfx, repl);
    try redrawOutput(gfx, repl);
    try redrawPrompt(gfx, repl);
}

/// Draw the menu full-screen: black with a red outline, one row per item
/// (number + label), selected row inverted yellow.
fn drawMenu(gfx: *Gfx, menu: *const MenuState) !void {
    try gfx.fillScreen(Gfx.Colors.black);
    try gfx.drawRect(2, 2, 236, 316, Gfx.Colors.red);
    for (menu.items, 0..) |item, i| {
        var buf: [input_cap + 2]u8 = undefined;
        @memset(buf[0..], ' ');
        buf[0] = '1' + @as(u8, @intCast(i));
        buf[1] = ' ';
        var n: usize = 2;
        for (item.label) |c| {
            buf[n] = c;
            n += 1;
        }
        const y: u16 = @intCast(16 + i * 16);
        if (i == menu.sel) {
            try gfx.drawTextLine(y, buf[0..n], Gfx.Colors.black, Gfx.Colors.yellow);
        } else {
            try gfx.drawTextLine(y, buf[0..n], Gfx.Colors.white, Gfx.Colors.black);
        }
    }
}

/// Handle a key while a menu is open. Returns true if the screen needs a
/// redraw. Enter / number keys paste the selected value into the input and
/// close the menu; backspace / clear close without pasting.
fn handleMenuKey(menu: *MenuState, repl: *Repl, kind: layout_mod.KeyKind) bool {
    return switch (kind) {
        .arrow => |d| switch (d) {
            .up => blk: {
                if (menu.items.len > 0) menu.sel = (menu.sel + menu.items.len - 1) % menu.items.len;
                break :blk true;
            },
            .down => blk: {
                if (menu.items.len > 0) menu.sel = (menu.sel + 1) % menu.items.len;
                break :blk true;
            },
            else => false,
        },
        .enter => blk: {
            if (menu.items.len > 0 and menu.sel < menu.items.len) {
                repl.insert(menu.items[menu.sel].value);
                menu.open = false;
            }
            break :blk true;
        },
        .unicode => |s| blk: {
            if (s.len == 1 and s[0] >= '1' and s[0] <= '6') {
                const idx = s[0] - '1';
                if (idx < menu.items.len) {
                    repl.insert(menu.items[idx].value);
                    menu.open = false;
                }
            }
            break :blk true;
        },
        .backspace, .clear => blk: {
            menu.open = false;
            break :blk true;
        },
        else => false,
    };
}

pub fn main() !void {
    const pins = pin_config.apply();

    rp2xxx.spi.instance.SPI0.apply(.{
        .clock_config = rp2xxx.clocks.config.preset.default(),
        .baud_rate = 62_500_000,
    }) catch {};

    var spi_dev = rp2xxx.drivers.SPI_Device.init(
        rp2xxx.spi.instance.SPI0,
        .{ .chip_select = .{
            .pin = pins.cs,
            .active_level = .low,
        } },
    );

    var dc_dev = rp2xxx.drivers.GPIO_Device.init(pins.dc);
    var rst_dev = rp2xxx.drivers.GPIO_Device.init(pins.rst);

    var display = try Display.init(
        spi_dev.datagram_device(),
        rst_dev.digital_io(),
        dc_dev.digital_io(),
        time.sleep_ms,
    );
    pins.bl.put(1);
    var gfx = Gfx.init(&display, 240, 320);

    try gfx.fillScreen(Gfx.Colors.black);

    const row_pins = [_]rp2xxx.gpio.Pin{ pins.row0, pins.row1, pins.row2, pins.row3, pins.row4, pins.row5 };
    const col_pins = [_]rp2xxx.gpio.Pin{ pins.col0, pins.col1, pins.col2, pins.col3, pins.col4, pins.col5 };
    var keypad = keypad_mod.Keypad.init(row_pins, col_pins);

    const layout = layout_mod.KEY_LAYOUT;
    var repl = Repl.init();
    var menu = MenuState{};

    try render(&gfx, &repl);

    var last_pressed = std.mem.zeroes(keypad_mod.PressedState);

    while (true) {
        var pressed = keypad.scan();
        time.sleep_ms(5);
        const pressed2 = keypad.scan();
        if (!std.mem.eql(u6, &pressed, &pressed2))
            continue;

        if (std.mem.eql(u6, &pressed, &last_pressed))
            continue;
        last_pressed = pressed;

        const btn = keypad_mod.firstPressed(pressed) orelse {
            pins.led.put(0);
            continue;
        };
        pins.led.put(1);

        const row = (btn - 1) / layout_mod.COLS;
        const col = layout_mod.COLS - 1 - ((btn - 1) % layout_mod.COLS);
        const key = layout[row][col];

        if (menu.open) {
            if (handleMenuKey(&menu, &repl, key.orig)) {
                if (menu.open) {
                    try drawMenu(&gfx, &menu);
                } else {
                    try render(&gfx, &repl);
                }
            }
            continue;
        }

        const kind = if (repl.shift_on)
            choose(key.shift, key.orig)
        else if (repl.alpha_on)
            choose(key.alpha, key.orig)
        else
            key.orig;

        var redraw_all = false;
        var bar_changed = false;

        switch (kind) {
            .unicode => |s| repl.insert(s),
            .alpha => {
                repl.alpha_on = !repl.alpha_on;
                if (repl.alpha_on) repl.shift_on = false;
                bar_changed = true;
            },
            .shift => {
                repl.shift_on = !repl.shift_on;
                if (repl.shift_on) repl.alpha_on = false;
                bar_changed = true;
            },
            .arrow => |d| switch (d) {
                .left => {
                    if (repl.cursor > 0) repl.cursor -= 1;
                },
                .right => {
                    if (repl.cursor < repl.input_len) repl.cursor += 1;
                },
                .up => {
                    repl.moveHighlight(true);
                    redraw_all = true;
                },
                .down => {
                    repl.moveHighlight(false);
                    redraw_all = true;
                },
            },
            .enter => {
                if (repl.hl_k > 0) {
                    repl.paste();
                    redraw_all = true;
                } else {
                    repl.eval();
                    redraw_all = true;
                }
            },
            .backspace => repl.backspace(),
            .clear => {
                repl.clearInput();
                repl.hl_k = 0;
                redraw_all = true;
            },
            .menu => |items| {
                menu.open = true;
                menu.items = items;
                menu.sel = 0;
                try drawMenu(&gfx, &menu);
            },
            else => {},
        }

        if (!menu.open) {
            if (redraw_all) try redrawOutput(&gfx, &repl);
            if (bar_changed) try redrawBar(&gfx, &repl);
            try redrawPrompt(&gfx, &repl);
        }
    }
}

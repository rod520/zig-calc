const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const ili9341 = @import("ili9341.zig");
const gfx_mod = @import("gfx.zig");
const keypad_mod = @import("keypad.zig");
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

const grid_x: u16 = 14;
const grid_y: u16 = 28;
const cell: u16 = 32;
const gap: u16 = 4;

fn fmtNum(n: u8, buf: *[3]u8) []const u8 {
    var len: usize = 0;
    if (n >= 100) {
        buf[len] = '0' + n / 100;
        len += 1;
    }
    if (n >= 10) {
        buf[len] = '0' + (n / 10) % 10;
        len += 1;
    }
    buf[len] = '0' + n % 10;
    len += 1;
    return buf[0..len];
}

fn drawGrid(gfx: *Gfx) !void {
    for (0..keypad_mod.ROWS) |r| {
        for (0..keypad_mod.COLS) |c| {
            const x = grid_x + @as(u16, @intCast(c)) * (cell + gap);
            const y = grid_y + @as(u16, @intCast(r)) * (cell + gap);
            try gfx.drawRect(x, y, cell, cell, Gfx.Colors.blue);
        }
    }
}

fn drawCells(gfx: *Gfx, pressed: keypad_mod.PressedState) !void {
    gfx.setTextSize(1);
    for (0..keypad_mod.ROWS) |r| {
        for (0..keypad_mod.COLS) |c| {
            const pc: u8 = @intCast(keypad_mod.COLS - 1 - c);
            const down = ((pressed[pc] >> @intCast(r)) & 1) != 0;
            const x = grid_x + @as(u16, @intCast(c)) * (cell + gap);
            const y = grid_y + @as(u16, @intCast(r)) * (cell + gap);
            if (down) {
                try gfx.fillRect(x + 2, y + 2, cell - 4, cell - 4, Gfx.Colors.green);
                gfx.setTextColorBg(Gfx.Colors.black, Gfx.Colors.green);
            } else {
                try gfx.fillRect(x + 2, y + 2, cell - 4, cell - 4, Gfx.Colors.navy);
                gfx.setTextColorBg(Gfx.Colors.white, Gfx.Colors.navy);
            }
            const n = keypad_mod.buttonNumber(@intCast(r), pc);
            var buf: [3]u8 = undefined;
            const s = fmtNum(n, &buf);
            const tw: u16 = @intCast(s.len * 6);
            gfx.setCursor(x + (cell - tw) / 2, y + (cell - 8) / 2);
            try gfx.print(s);
        }
    }
}

fn drawReadout(gfx: *Gfx, pressed: keypad_mod.PressedState) !void {
    try gfx.fillRect(0, 246, 240, 74, Gfx.Colors.black);
    gfx.setTextColorBg(Gfx.Colors.cyan, Gfx.Colors.black);
    gfx.setTextSize(1);
    gfx.setCursor(10, 250);
    try gfx.print("PRESSED:");

    if (keypad_mod.firstPressed(pressed)) |n| {
        const row = (n - 1) / keypad_mod.COLS;
        const col = keypad_mod.COLS - 1 - ((n - 1) % keypad_mod.COLS);

        gfx.setTextColorBg(Gfx.Colors.green, Gfx.Colors.black);
        gfx.setTextSize(3);
        var buf: [3]u8 = undefined;
        const s = fmtNum(n, &buf);
        gfx.setCursor(10, 262);
        try gfx.print(s);

        gfx.setTextColorBg(Gfx.Colors.white, Gfx.Colors.black);
        gfx.setTextSize(1);
        var line: [12]u8 = undefined;
        line[0] = 'r';
        line[1] = 'o';
        line[2] = 'w';
        line[3] = '=';
        line[4] = '0' + row;
        line[5] = ' ';
        line[6] = 'c';
        line[7] = 'o';
        line[8] = 'l';
        line[9] = '=';
        line[10] = '0' + col;
        gfx.setCursor(10, 300);
        try gfx.print(line[0..11]);
    } else {
        gfx.setTextColorBg(Gfx.Colors.darkgrey, Gfx.Colors.black);
        gfx.setTextSize(2);
        gfx.setCursor(10, 272);
        try gfx.print("NONE");
    }
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

    gfx.setTextColorBg(Gfx.Colors.cyan, Gfx.Colors.black);
    gfx.setTextSize(1);
    gfx.setCursor(8, 6);
    try gfx.print("KEYPAD DEBUG");
    try drawGrid(&gfx);

    var last_pressed = std.mem.zeroes(keypad_mod.PressedState);
    try drawCells(&gfx, last_pressed);
    try drawReadout(&gfx, last_pressed);

    while (true) {
        var pressed = keypad.scan();
        time.sleep_ms(5);
        const pressed2 = keypad.scan();
        if (!std.mem.eql(u6, &pressed, &pressed2))
            continue;

        if (!std.mem.eql(u6, &pressed, &last_pressed)) {
            last_pressed = pressed;
            pins.led.put(if (keypad_mod.firstPressed(pressed) != null) 1 else 0);
            try drawCells(&gfx, pressed);
            try drawReadout(&gfx, pressed);
        }
    }
}

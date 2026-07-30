const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const ili9341 = @import("ili9341.zig");
const gfx_mod = @import("gfx.zig");
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
    .GPIO4 = .{
        .name = "miso",
        .function = .SPI0_RX,
    },
    
    .GPIO17 = .{ .name = "cs", .direction = .out },
    .GPIO16 = .{ .name = "dc", .direction = .out },
    .GPIO20 = .{ .name = "rst", .direction = .out },
    .GPIO22 = .{ .name = "bl", .direction = .out },
};

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
    time.sleep_ms(500);

    try gfx.fillRect(10, 10, 220, 300, Gfx.Colors.navy);
    try gfx.drawRect(5, 5, 230, 310, Gfx.Colors.white);

    try gfx.drawCircle(60, 60, 40, Gfx.Colors.yellow);
    try gfx.fillCircle(180, 60, 40, Gfx.Colors.blue);
    try gfx.drawCircle(180, 60, 40, Gfx.Colors.cyan);

    try gfx.drawTriangle(60, 160, 30, 220, 90, 220, Gfx.Colors.green);
    try gfx.fillTriangle(180, 160, 150, 220, 210, 220, Gfx.Colors.purple);

    try gfx.drawRoundRect(10, 230, 220, 30, 8, Gfx.Colors.orange);
    try gfx.fillRoundRect(10, 270, 220, 30, 8, Gfx.Colors.magenta);

    try gfx.drawFastHLine(10, 145, 220, Gfx.Colors.white);
    try gfx.drawFastVLine(120, 10, 280, Gfx.Colors.white);

    gfx.setTextColor(Gfx.Colors.yellow);
    gfx.setTextSize(2);
    gfx.setCursor(30, 100);
    try gfx.print("Hello, Zig!");

    gfx.setTextColorBg(Gfx.Colors.cyan, Gfx.Colors.navy);
    gfx.setTextSize(1);
    gfx.setCursor(20, 125);
    try gfx.print("ILI9341 @ 62.5MHz");

    {
        var i: u8 = 0;
        while (true) : (i +%= 1) {
            pins.led.toggle();
            gfx.setTextColor(Gfx.Colors.white);
            gfx.setTextSize(3);
            gfx.setCursor(40, 280);
            try gfx.print("COUNT: ");
            try gfx.print(&[_]u8{'0' + (i / 100) % 10, '0' + (i / 10) % 10, '0' + i % 10});
            time.sleep_ms(500);
        }
    }
}

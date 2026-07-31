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

    
    


    try gfx.fillRect(0, 0, 40, 20, Gfx.Colors.red);
    try gfx.fillRect(40, 0, 40, 20, Gfx.Colors.green);
    try gfx.fillRect(80, 0, 40, 20, Gfx.Colors.blue);
    try gfx.fillRect(120, 0, 40, 20, Gfx.Colors.cyan);
    try gfx.fillRect(160, 0, 40, 20, Gfx.Colors.magenta);
    try gfx.fillRect(200, 0, 40, 20, Gfx.Colors.yellow);

    gfx.setTextColorBg(Gfx.Colors.cyan, Gfx.Colors.navy);
    gfx.setTextSize(1);
    gfx.setCursor(20, 125);
    try gfx.print("ILI9341 @ 62.5MHz");


    {
        var i: u8 = 0;
        while (true) : (i +%= 1) {
            pins.led.toggle();
            try gfx.fillRect(40, 280, 160, 8, Gfx.Colors.magenta);
            gfx.setTextColor(Gfx.Colors.white);
            gfx.setTextSize(1);
            gfx.setCursor(40, 280);
            try gfx.print("COUNT: ");
            try gfx.print(&[_]u8{'0' + (i / 100) % 10, '0' + (i / 10) % 10, '0' + i % 10});
            time.sleep_ms(2000);
        }
    }
}

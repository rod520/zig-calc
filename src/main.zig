const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

const ili9341 = @import("ili9341.zig");
const Display = ili9341.ILI9341(.lcd240x320);

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
    .GPIO2 = .{
        .name = "sck",
        .function = .SPI0_SCK,
    },
    .GPIO3 = .{
        .name = "mosi",
        .function = .SPI0_TX,
    },
    .GPIO4 = .{
        .name = "miso",
        .function = .SPI0_RX,
    },
    .GPIO5 = .{ .name = "cs", .direction = .out },
    .GPIO6 = .{ .name = "dc", .direction = .out },
    .GPIO7 = .{ .name = "rst", .direction = .out },
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

    var color: Display.Color = .red;
    var row_buf: [240]Display.Color = undefined;

    while (true) {
        pins.led.toggle();
        time.sleep_ms(250);

        try display.set_address_window(0, 0, 240, 320);
        @memset(&row_buf, color);
        for (0..320) |_| {
            try display.push_colors(&row_buf);
        }
        color = .{ .value = color.value +% 0x001F };
    }
}

const std = @import("std");
const microzig = @import("microzig");
// as it turns out microzig does come with some "drivers". these help with spi communication 
const mdf = microzig.drivers;
// constructor function
pub fn ILI9341(display_cfg: DisplayConfig) type {
    return ILI9341_Generic(display_cfg);
}
// set resolution
pub const Resolution = struct {
    width: u16,
    height: u16,
};
// this is actually kinda unnecessary, we could just set bgr everywhere, but i'll leave this for now because I think this is evaled in comptime
pub const ColorOrder = enum(u1) {
    rgb = 0,
    bgr = 1,
};
// rotation
pub const Rotation = enum(u2) {
    deg0, // my display's pins are down
    deg90, //right i believe
    deg180, // they would be up
    deg270, // left
};

pub const DisplayConfig = struct {
    // display config, 
    resolution: Resolution,
    x_offset: u16 = 0,
    y_offset: u16 = 0,
    color_order: ColorOrder = .bgr,
    rotation: Rotation = .deg0,

    pub const lcd240x320: DisplayConfig = .{
        .resolution = .{ .width = 240, .height = 320 },
    };
};
// these are the instructions for different madctl modes
// row bottom to top
pub const MADCTL_MY = 0x80;
// left to right columns
pub const MADCTL_MX = 0x40;
// row column exchange
pub const MADCTL_MV = 0x20;
// using bgr 
pub const MADCTL_BGR = 0x08;
// no i get whats going on here now: its the madctl instruction from the rotation
fn madctl_from_rotation(rotation: Rotation, color_order: ColorOrder) u8 {
    const bgr_bit: u8 = if (color_order == .bgr) MADCTL_BGR else 0;
    return switch (rotation) {
        .deg0 => MADCTL_MX | bgr_bit,
        .deg90 => MADCTL_MV | bgr_bit,
        .deg180 => MADCTL_MY | bgr_bit,
        .deg270 => MADCTL_MX | MADCTL_MY | MADCTL_MV | bgr_bit,
    };
}

fn ILI9341_Generic(display_cfg: DisplayConfig) type {
    return struct {
        const Self = @This();
        // mdf  gives us colors
        pub const Color = mdf.display.colors.RGB565_Generic(.big);
        // our packet oriented commuication device
        dd: mdf.base.DatagramDevice,
        // this is just the reset pin
        dev_rst: mdf.base.Digital_IO,
        // switching between low and high for commands and data
        dev_datcmd: mdf.base.Digital_IO,
        madctl: u8,
        // display constants
        resolution: Resolution = display_cfg.resolution,
        x_offset: u16 = display_cfg.x_offset,
        y_offset: u16 = display_cfg.y_offset,
        // i think this has to do with making sure the new pixel is different?
        old_x1: u16 = 0xFFFF,
        old_x2: u16 = 0xFFFF,
        old_y1: u16 = 0xFFFF,
        old_y2: u16 = 0xFFFF,

        pub fn init(
            channel: mdf.base.DatagramDevice,
            rst: mdf.base.Digital_IO,
            data_cmd: mdf.base.Digital_IO,
            delay_ms: *const fn (ms: u32) void,
        ) !Self {
            var dri = Self{
                .dd = channel,
                .dev_rst = rst,
                .dev_datcmd = data_cmd,
                .madctl = madctl_from_rotation(display_cfg.rotation, display_cfg.color_order),
            };

            try dri.set_spi_mode(.data);
            try dri.hard_reset(delay_ms);
            try dri.init_sequence(delay_ms);

            return dri;
        }

        fn set_spi_mode(dri: *Self, mode: enum { data, command }) !void {
            try dri.dev_datcmd.write(switch (mode) {
                // switch between modes here
                .command => .low,
                .data => .high,
            });
        }

        fn hard_reset(dri: *Self, delay_ms: *const fn (ms: u32) void) !void {
            // lol are we just spamming the reset button here?
            try dri.dev_rst.write(.high);
            delay_ms(200);
            try dri.dev_rst.write(.low);
            delay_ms(200);
            try dri.dev_rst.write(.high);
            delay_ms(200);
        }

        fn range_to_bigendian_bytes(start: u16, end: u16) [4]u8 {
            // to a new number format
            return .{
                @as(u8, @truncate(start >> 8)),
                @as(u8, @truncate(start)),
                @as(u8, @truncate(end >> 8)),
                @as(u8, @truncate(end)),
            };
        }

        fn init_sequence(dri: *Self, delay_ms: *const fn (ms: u32) void) !void {
            try dri.write_command(.swreset, &.{});
            delay_ms(150);
            // init sequence, I dont get what, I do get how
            try dri.write_raw(0xEF, &.{ 0x03, 0x80, 0x02 });
            try dri.write_raw(0xCF, &.{ 0x00, 0xC1, 0x30 });
            try dri.write_raw(0xED, &.{ 0x64, 0x03, 0x12, 0x81 });
            try dri.write_raw(0xE8, &.{ 0x85, 0x00, 0x78 });
            try dri.write_raw(0xCB, &.{ 0x39, 0x2C, 0x00, 0x34, 0x02 });
            try dri.write_raw(0xF7, &.{0x20});
            try dri.write_raw(0xEA, &.{ 0x00, 0x00 });

            try dri.write_command(.pwctr1, &.{0x23});
            try dri.write_command(.pwctr2, &.{0x10});
            try dri.write_command(.vmctr1, &.{ 0x3E, 0x28 });
            try dri.write_command(.vmctr2, &.{0x86});
            try dri.write_command(.madctl, &.{dri.madctl});
            try dri.write_command(.vscrsadd, &.{ 0x00, 0x00 });
            try dri.write_command(.colmod, &.{0x55});
            try dri.write_command(.frmctr1, &.{ 0x00, 0x18 });
            try dri.write_command(.dfunctr, &.{ 0x08, 0x82, 0x27 });
            try dri.write_raw(0xF2, &.{0x00});
            try dri.write_command(.gammaset, &.{0x01});
            try dri.write_command(.gmctrp1, &.{
                0x0F, 0x31, 0x2B, 0x0C, 0x0E, 0x08, 0x4E, 0xF1,
                0x37, 0x07, 0x10, 0x03, 0x0E, 0x09, 0x00,
            });
            try dri.write_command(.gmctrn1, &.{
                0x00, 0x0E, 0x14, 0x03, 0x11, 0x07, 0x31, 0xC1,
                0x48, 0x08, 0x0F, 0x0C, 0x31, 0x36, 0x0F,
            });

            try dri.write_command(.slpout, &.{});
            delay_ms(150);

            try dri.write_command(.dispon, &.{});
            delay_ms(150);
        }

        pub fn set_address_window(dri: *Self, x: u16, y: u16, w: u16, h: u16) !void {
            const x2 = x + w - 1;
            const y2 = y + h - 1;

            if (x != dri.old_x1 or x2 != dri.old_x2) {
                try dri.write_command(.caset, &range_to_bigendian_bytes(x, x2));
                dri.old_x1 = x;
                dri.old_x2 = x2;
            }
            if (y != dri.old_y1 or y2 != dri.old_y2) {
                try dri.write_command(.paset, &range_to_bigendian_bytes(y, y2));
                dri.old_y1 = y;
                dri.old_y2 = y2;
            }

            try dri.write_command(.ramwr, &.{});
        }

        pub fn push_colors(dri: *Self, colors: []align(1) const Color) !void {
            try dri.set_spi_mode(.data);
            try dri.dd.connect();
            defer dri.dd.disconnect();
            try dri.dd.write(std.mem.sliceAsBytes(colors));
        }

        pub fn get_active_resolution(dri: *const Self) Resolution {
            return dri.resolution;
        }

        pub fn set_rotation(dri: *Self, rotation: Rotation) !void {
            dri.madctl = madctl_from_rotation(rotation, display_cfg.color_order);
            switch (rotation) {
                .deg0, .deg180 => {
                    dri.resolution = .{
                        .width = display_cfg.resolution.width,
                        .height = display_cfg.resolution.height,
                    };
                },
                .deg90, .deg270 => {
                    dri.resolution = .{
                        .width = display_cfg.resolution.height,
                        .height = display_cfg.resolution.width,
                    };
                },
            }
            try dri.write_command(.madctl, &.{dri.madctl});
            dri.old_x1 = 0xFFFF;
            dri.old_x2 = 0xFFFF;
            dri.old_y1 = 0xFFFF;
            dri.old_y2 = 0xFFFF;
        }

        pub fn invert_display(dri: *Self, invert: bool) !void {
            try dri.write_command(if (invert) .invon else .invoff, &.{});
        }

        pub fn scroll_to(dri: *Self, y: u16) !void {
            const data = [2]u8{
                @as(u8, @truncate(y >> 8)),
                @as(u8, @truncate(y)),
            };
            try dri.write_command(.vscrsadd, &data);
        }

        pub fn set_scroll_margins(dri: *Self, top: u16, bottom: u16) !void {
            if (top + bottom <= display_cfg.resolution.height) {
                const middle = display_cfg.resolution.height - (top + bottom);
                const data = [6]u8{
                    @as(u8, @truncate(top >> 8)),
                    @as(u8, @truncate(top)),
                    @as(u8, @truncate(middle >> 8)),
                    @as(u8, @truncate(middle)),
                    @as(u8, @truncate(bottom >> 8)),
                    @as(u8, @truncate(bottom)),
                };
                try dri.write_command(.vscrdef, &data);
            }
        }

        pub fn readcommand8(dri: *Self, command_byte: u8, index: u8) !u8 {
            const data = [_]u8{0x10 + index};
            try dri.write_raw(0xD9, &data);

            try dri.set_spi_mode(.command);
            try dri.dd.connect();
            defer dri.dd.disconnect();
            try dri.dd.write(&[_]u8{command_byte});

            try dri.set_spi_mode(.data);
            var buf: [1]u8 = .{0};
            _ = try dri.dd.read(&buf);
            return buf[0];
        }

        fn write_raw(dri: *Self, cmd: u8, params: []const u8) !void {
            try dri.set_spi_mode(.command);
            try dri.dd.connect();
            defer dri.dd.disconnect();

            try dri.dd.write(&[_]u8{cmd});

            if (params.len > 0) {
                try dri.set_spi_mode(.data);
                try dri.dd.write(params);
            }
        }

        fn write_command(dri: *Self, cmd: Command, params: []const u8) !void {
            try dri.write_raw(@intFromEnum(cmd), params);
        }

        const Command = enum(u8) {
            nop = 0x00,
            swreset = 0x01,
            rddid = 0x04,
            rddst = 0x09,

            slpin = 0x10,
            slpout = 0x11,
            ptlon = 0x12,
            noron = 0x13,

            invoff = 0x20,
            invon = 0x21,
            gammaset = 0x26,
            dispoff = 0x28,
            dispon = 0x29,

            caset = 0x2A,
            paset = 0x2B,
            ramwr = 0x2C,
            ramrd = 0x2E,

            ptlar = 0x30,
            vscrdef = 0x33,
            teoff = 0x34,
            teon = 0x35,
            madctl = 0x36,
            vscrsadd = 0x37,
            colmod = 0x3A,

            frmctr1 = 0xB1,
            frmctr2 = 0xB2,
            frmctr3 = 0xB3,
            invctr = 0xB4,
            dfunctr = 0xB6,

            pwctr1 = 0xC0,
            pwctr2 = 0xC1,
            pwctr3 = 0xC2,
            pwctr4 = 0xC3,
            pwctr5 = 0xC4,
            vmctr1 = 0xC5,
            vmctr2 = 0xC7,

            rdid1 = 0xDA,
            rdid2 = 0xDB,
            rdid3 = 0xDC,
            rdid4 = 0xDD,

            gmctrp1 = 0xE0,
            gmctrn1 = 0xE1,
        };
    };
}

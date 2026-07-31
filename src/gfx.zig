const std = @import("std");

pub fn ColorTable(comptime C: type) type {
    return struct {
        pub const black: C = C.from_rgb(0x00, 0x00, 0x00);
        pub const navy: C = C.from_rgb(0x00, 0x00, 0x80);
        pub const darkgreen: C = C.from_rgb(0x00, 0x80, 0x00);
        pub const darkcyan: C = C.from_rgb(0x00, 0x80, 0x80);
        pub const maroon: C = C.from_rgb(0x80, 0x00, 0x00);
        pub const purple: C = C.from_rgb(0x80, 0x00, 0x80);
        pub const olive: C = C.from_rgb(0x80, 0x80, 0x00);
        pub const lightgrey: C = C.from_rgb(0xC0, 0xC0, 0xC0);
        pub const darkgrey: C = C.from_rgb(0x80, 0x80, 0x80);
        pub const blue: C = C.from_rgb(0x00, 0x00, 0xFF);
        pub const green: C = C.from_rgb(0x00, 0xFF, 0x00);
        pub const cyan: C = C.from_rgb(0x00, 0xFF, 0xFF);
        pub const red: C = C.from_rgb(0xFF, 0x00, 0x00);
        pub const magenta: C = C.from_rgb(0xFF, 0x00, 0xFF);
        pub const yellow: C = C.from_rgb(0xFF, 0xFF, 0x00);
        pub const white: C = C.from_rgb(0xFF, 0xFF, 0xFF);
        pub const orange: C = C.from_rgb(0xFF, 0xA0, 0x00);
        pub const greenyellow: C = C.from_rgb(0xAD, 0xFF, 0x2F);
        pub const pink: C = C.from_rgb(0xFF, 0x80, 0x80);
    };
}

pub const font5x7 = [96][5]u8{
    .{ 0x00, 0x00, 0x00, 0x00, 0x00 }, // 0x20 space
    .{ 0x00, 0x00, 0x5F, 0x00, 0x00 }, // !
    .{ 0x00, 0x07, 0x00, 0x07, 0x00 }, // "
    .{ 0x14, 0x7F, 0x14, 0x7F, 0x14 }, // #
    .{ 0x24, 0x2A, 0x7F, 0x2A, 0x12 }, // $
    .{ 0x23, 0x13, 0x08, 0x64, 0x62 }, // %
    .{ 0x36, 0x49, 0x55, 0x22, 0x50 }, // &
    .{ 0x00, 0x05, 0x03, 0x00, 0x00 }, // '
    .{ 0x00, 0x1C, 0x22, 0x41, 0x00 }, // (
    .{ 0x00, 0x41, 0x22, 0x1C, 0x00 }, // )
    .{ 0x08, 0x2A, 0x1C, 0x2A, 0x08 }, // *
    .{ 0x08, 0x08, 0x3E, 0x08, 0x08 }, // +
    .{ 0x00, 0x50, 0x30, 0x00, 0x00 }, // ,
    .{ 0x08, 0x08, 0x08, 0x08, 0x08 }, // -
    .{ 0x00, 0x60, 0x60, 0x00, 0x00 }, // .
    .{ 0x20, 0x10, 0x08, 0x04, 0x02 }, // /
    .{ 0x3E, 0x51, 0x49, 0x45, 0x3E }, // 0
    .{ 0x00, 0x42, 0x7F, 0x40, 0x00 }, // 1
    .{ 0x42, 0x61, 0x51, 0x49, 0x46 }, // 2
    .{ 0x21, 0x41, 0x45, 0x4B, 0x31 }, // 3
    .{ 0x18, 0x14, 0x12, 0x7F, 0x10 }, // 4
    .{ 0x27, 0x45, 0x45, 0x45, 0x39 }, // 5
    .{ 0x3C, 0x4A, 0x49, 0x49, 0x30 }, // 6
    .{ 0x01, 0x71, 0x09, 0x05, 0x03 }, // 7
    .{ 0x36, 0x49, 0x49, 0x49, 0x36 }, // 8
    .{ 0x06, 0x49, 0x49, 0x29, 0x1E }, // 9
    .{ 0x00, 0x36, 0x36, 0x00, 0x00 }, // :
    .{ 0x00, 0x56, 0x36, 0x00, 0x00 }, // ;
    .{ 0x00, 0x08, 0x14, 0x22, 0x41 }, // <
    .{ 0x14, 0x14, 0x14, 0x14, 0x14 }, // =
    .{ 0x41, 0x22, 0x14, 0x08, 0x00 }, // >
    .{ 0x02, 0x01, 0x51, 0x09, 0x06 }, // ?
    .{ 0x32, 0x49, 0x79, 0x41, 0x3E }, // @
    .{ 0x7E, 0x11, 0x11, 0x11, 0x7E }, // A
    .{ 0x7F, 0x49, 0x49, 0x49, 0x36 }, // B
    .{ 0x3E, 0x41, 0x41, 0x41, 0x22 }, // C
    .{ 0x7F, 0x41, 0x41, 0x22, 0x1C }, // D
    .{ 0x7F, 0x49, 0x49, 0x49, 0x41 }, // E
    .{ 0x7F, 0x09, 0x09, 0x01, 0x01 }, // F
    .{ 0x3E, 0x41, 0x41, 0x51, 0x32 }, // G
    .{ 0x7F, 0x08, 0x08, 0x08, 0x7F }, // H
    .{ 0x00, 0x41, 0x7F, 0x41, 0x00 }, // I
    .{ 0x20, 0x40, 0x41, 0x3F, 0x01 }, // J
    .{ 0x7F, 0x08, 0x14, 0x22, 0x41 }, // K
    .{ 0x7F, 0x40, 0x40, 0x40, 0x40 }, // L
    .{ 0x7F, 0x02, 0x04, 0x02, 0x7F }, // M
    .{ 0x7F, 0x04, 0x08, 0x10, 0x7F }, // N
    .{ 0x3E, 0x41, 0x41, 0x41, 0x3E }, // O
    .{ 0x7F, 0x09, 0x09, 0x09, 0x06 }, // P
    .{ 0x3E, 0x41, 0x51, 0x21, 0x5E }, // Q
    .{ 0x7F, 0x09, 0x19, 0x29, 0x46 }, // R
    .{ 0x46, 0x49, 0x49, 0x49, 0x31 }, // S
    .{ 0x01, 0x01, 0x7F, 0x01, 0x01 }, // T
    .{ 0x3F, 0x40, 0x40, 0x40, 0x3F }, // U
    .{ 0x1F, 0x20, 0x40, 0x20, 0x1F }, // V
    .{ 0x7F, 0x20, 0x18, 0x20, 0x7F }, // W
    .{ 0x63, 0x14, 0x08, 0x14, 0x63 }, // X
    .{ 0x03, 0x04, 0x78, 0x04, 0x03 }, // Y
    .{ 0x61, 0x51, 0x49, 0x45, 0x43 }, // Z
    .{ 0x00, 0x00, 0x7F, 0x41, 0x41 }, // [
    .{ 0x02, 0x04, 0x08, 0x10, 0x20 }, // backslash
    .{ 0x41, 0x41, 0x7F, 0x00, 0x00 }, // ]
    .{ 0x04, 0x02, 0x01, 0x02, 0x04 }, // ^
    .{ 0x40, 0x40, 0x40, 0x40, 0x40 }, // _
    .{ 0x00, 0x01, 0x02, 0x04, 0x00 }, // `
    .{ 0x20, 0x54, 0x54, 0x54, 0x78 }, // a
    .{ 0x7F, 0x48, 0x44, 0x44, 0x38 }, // b
    .{ 0x38, 0x44, 0x44, 0x44, 0x20 }, // c
    .{ 0x38, 0x44, 0x44, 0x48, 0x7F }, // d
    .{ 0x38, 0x54, 0x54, 0x54, 0x18 }, // e
    .{ 0x08, 0x7E, 0x09, 0x01, 0x02 }, // f
    .{ 0x08, 0x14, 0x54, 0x54, 0x3C }, // g
    .{ 0x7F, 0x08, 0x04, 0x04, 0x78 }, // h
    .{ 0x00, 0x44, 0x7D, 0x40, 0x00 }, // i
    .{ 0x20, 0x40, 0x44, 0x3D, 0x00 }, // j
    .{ 0x00, 0x7F, 0x10, 0x28, 0x44 }, // k
    .{ 0x00, 0x41, 0x7F, 0x40, 0x00 }, // l
    .{ 0x7C, 0x04, 0x18, 0x04, 0x78 }, // m
    .{ 0x7C, 0x08, 0x04, 0x04, 0x78 }, // n
    .{ 0x38, 0x44, 0x44, 0x44, 0x38 }, // o
    .{ 0x7C, 0x14, 0x14, 0x14, 0x08 }, // p
    .{ 0x08, 0x14, 0x14, 0x18, 0x7C }, // q
    .{ 0x7C, 0x08, 0x04, 0x04, 0x08 }, // r
    .{ 0x48, 0x54, 0x54, 0x54, 0x20 }, // s
    .{ 0x04, 0x3F, 0x44, 0x40, 0x20 }, // t
    .{ 0x3C, 0x40, 0x40, 0x20, 0x7C }, // u
    .{ 0x1C, 0x20, 0x40, 0x20, 0x1C }, // v
    .{ 0x3C, 0x40, 0x30, 0x40, 0x3C }, // w
    .{ 0x44, 0x28, 0x10, 0x28, 0x44 }, // x
    .{ 0x0C, 0x50, 0x50, 0x50, 0x3C }, // y
    .{ 0x44, 0x64, 0x54, 0x4C, 0x44 }, // z
    .{ 0x00, 0x08, 0x36, 0x41, 0x00 }, // {
    .{ 0x00, 0x00, 0x7F, 0x00, 0x00 }, // |
    .{ 0x00, 0x41, 0x36, 0x08, 0x00 }, // }
    .{ 0x08, 0x08, 0x2A, 0x1C, 0x08 }, // ~
    .{ 0x08, 0x1C, 0x2A, 0x08, 0x08 }, // del
};

pub fn DisplayGFX(comptime Display: type) type {
    return struct {
        const Self = @This();
        const C = Display.Color;
        pub const Colors = ColorTable(C);

        display: *Display,
        width: u16,
        height: u16,
        cursor_x: u16 = 0,
        cursor_y: u16 = 0,
        text_color: C = .white,
        text_bg_color: C = .black,
        text_size: u8 = 1,
        text_wrap: bool = true,

        pub fn init(display: *Display, w: u16, h: u16) Self {
            return .{
                .display = display,
                .width = w,
                .height = h,
            };
        }

        pub fn drawPixel(gfx: *Self, x: u16, y: u16, c: C) !void {
            try gfx.display.set_address_window(x, y, 1, 1);
            try gfx.display.push_colors(&[_]C{c});
        }

        fn pushRun(gfx: *Self, count: u16, c: C) !void {
            var buf: [64]C = undefined;
            @memset(&buf, c);
            var remaining = count;
            while (remaining > 0) {
                const batch = @min(remaining, 64);
                try gfx.display.push_colors(buf[0..batch]);
                remaining -= batch;
            }
        }

        pub fn drawFastVLine(gfx: *Self, x: u16, y: u16, h: u16, c: C) !void {
            try gfx.display.set_address_window(x, y, 1, h);
            try gfx.pushRun(h, c);
        }

        pub fn drawFastHLine(gfx: *Self, x: u16, y: u16, w: u16, c: C) !void {
            try gfx.display.set_address_window(x, y, w, 1);
            try gfx.pushRun(w, c);
        }

        pub fn fillRect(gfx: *Self, x: u16, y: u16, w: u16, h: u16, c: C) !void {
            try gfx.display.set_address_window(x, y, w, h);
            for (0..h) |_| try gfx.pushRun(w, c);
        }

        pub fn drawRect(gfx: *Self, x: u16, y: u16, w: u16, h: u16, c: C) !void {
            try gfx.drawFastHLine(x, y, w, c);
            try gfx.drawFastHLine(x, y + h - 1, w, c);
            try gfx.drawFastVLine(x, y, h, c);
            try gfx.drawFastVLine(x + w - 1, y, h, c);
        }

        pub fn fillScreen(gfx: *Self, c: C) !void {
            try gfx.fillRect(0, 0, gfx.width, gfx.height, c);
        }

        pub fn drawLine(gfx: *Self, x0: u16, y0: u16, x1: u16, y1: u16, c: C) !void {
            const dx = if (x1 > x0) @as(i32, x1) - @as(i32, x0) else @as(i32, x0) - @as(i32, x1);
            const dy = if (y1 > y0) @as(i32, y1) - @as(i32, y0) else @as(i32, y0) - @as(i32, y1);
            const sx: i32 = if (x1 >= x0) 1 else -1;
            const sy: i32 = if (y1 >= y0) 1 else -1;

            var err = dx - dy;
            var x: i32 = @as(i32, x0);
            var y: i32 = @as(i32, y0);

            while (true) {
            try gfx.drawPixel(@intCast(x), @intCast(y), c);
            if (x == @as(i32, x1) and y == @as(i32, y1)) break;
                const e2 = 2 * err;
                if (e2 > -dy) {
                    err -= dy;
                    x += sx;
                }
                if (e2 < dx) {
                    err += dx;
                    y += sy;
                }
            }
        }

        pub fn drawCircle(gfx: *Self, x0: u16, y0: u16, r: u16, c: C) !void {
            var f: i32 = 1 - @as(i32, r);
            var ddF_x: i32 = 1;
            var ddF_y: i32 = -2 * @as(i32, r);
            var x: i32 = 0;
            var y: i32 = @as(i32, r);

            try gfx.drawPixel(@intCast(@as(i32, x0)), @intCast(@as(i32, y0) + r), c);
            try gfx.drawPixel(@intCast(@as(i32, x0)), @intCast(@as(i32, y0) - r), c);
            try gfx.drawPixel(@intCast(@as(i32, x0) + r), @intCast(y0), c);
            try gfx.drawPixel(@intCast(@as(i32, x0) - r), @intCast(y0), c);

            while (x < y) {
                if (f >= 0) {
                    y -= 1;
                    ddF_y += 2;
                    f += ddF_y;
                }
                x += 1;
                ddF_x += 2;
                f += ddF_x;

                const xp = @as(i32, x0);
                const yp = @as(i32, y0);
                try gfx.drawPixel(@intCast(xp + x), @intCast(yp + y), c);
                try gfx.drawPixel(@intCast(xp - x), @intCast(yp + y), c);
                try gfx.drawPixel(@intCast(xp + x), @intCast(yp - y), c);
                try gfx.drawPixel(@intCast(xp - x), @intCast(yp - y), c);
                try gfx.drawPixel(@intCast(xp + y), @intCast(yp + x), c);
                try gfx.drawPixel(@intCast(xp - y), @intCast(yp + x), c);
                try gfx.drawPixel(@intCast(xp + y), @intCast(yp - x), c);
                try gfx.drawPixel(@intCast(xp - y), @intCast(yp - x), c);
            }
        }

        pub fn fillCircle(gfx: *Self, x0: u16, y0: u16, r: u16, c: C) !void {
            try gfx.drawFastVLine(x0, y0 - r, 2 * r + 1, c);
            var f: i32 = 1 - @as(i32, r);
            var ddF_x: i32 = 1;
            var ddF_y: i32 = -2 * @as(i32, r);
            var x: i32 = 0;
            var y: i32 = @as(i32, r);

            while (x < y) {
                if (f >= 0) {
                    y -= 1;
                    ddF_y += 2;
                    f += ddF_y;
                }
                x += 1;
                ddF_x += 2;
                f += ddF_x;

                const xp = @as(i32, x0);
                const yp = @as(i32, y0);
                try gfx.drawFastVLine(@intCast(xp - x), @intCast(yp - y), @intCast(2 * y + 1), c);
                try gfx.drawFastVLine(@intCast(xp + x), @intCast(yp - y), @intCast(2 * y + 1), c);
                try gfx.drawFastVLine(@intCast(xp - y), @intCast(yp - x), @intCast(2 * x + 1), c);
                try gfx.drawFastVLine(@intCast(xp + y), @intCast(yp - x), @intCast(2 * x + 1), c);
            }
        }

        pub fn drawTriangle(gfx: *Self, x0: u16, y0: u16, x1: u16, y1: u16, x2: u16, y2: u16, c: C) !void {
            try gfx.drawLine(x0, y0, x1, y1, c);
            try gfx.drawLine(x1, y1, x2, y2, c);
            try gfx.drawLine(x2, y2, x0, y0, c);
        }

        pub fn fillTriangle(gfx: *Self, x0: u16, y0: u16, x1: u16, y1: u16, x2: u16, y2: u16, color: C) !void {
            var ax = @as(i32, x0);
            var ay = @as(i32, y0);
            var bx = @as(i32, x1);
            var by = @as(i32, y1);
            var cx = @as(i32, x2);
            var cy = @as(i32, y2);

            if (by > cy) { std.mem.swap(i32, &by, &cy); std.mem.swap(i32, &bx, &cx); }
            if (ay > by) { std.mem.swap(i32, &ay, &by); std.mem.swap(i32, &ax, &bx); }
            if (ay > cy) { std.mem.swap(i32, &ay, &cy); std.mem.swap(i32, &ax, &cx); }

            const dx1 = bx - ax;
            const dy1 = by - ay;
            const dx2 = cx - ax;
            const dy2 = cy - ay;

            var slop1: i32 = 0;
            var slop2: i32 = 0;
            if (dy1 != 0) slop1 = @divTrunc(dx1 << 8, dy1);
            if (dy2 != 0) slop2 = @divTrunc(dx2 << 8, dy2);

            var sx = ax;
            var ex = ax;
            if (dy1 != 0) {
                var yy = ay;
                while (yy <= by) : (yy += 1) {
                    try gfx.drawFastHLine(@intCast(sx >> 8), @intCast(yy), @intCast((ex >> 8) - (sx >> 8) + 1), color);
                    sx += slop1;
                    ex += slop2;
                }
            }

            const dx3 = cx - bx;
            const dy3 = cy - by;
            var slop3: i32 = 0;
            if (dy3 != 0) slop3 = @divTrunc(dx3 << 8, dy3);
            sx = bx;
            ex = cx;
            if (dy3 != 0) {
                var yy = by;
                while (yy <= cy) : (yy += 1) {
                    try gfx.drawFastHLine(@intCast(sx >> 8), @intCast(yy), @intCast((ex >> 8) - (sx >> 8) + 1), color);
                    sx += slop3;
                    ex += slop2;
                }
            }
        }

        pub fn drawRoundRect(gfx: *Self, x: u16, y: u16, w: u16, h: u16, r: u16, c: C) !void {
            const radius = @min(r, @min(w / 2, h / 2));
            try gfx.drawFastHLine(x + radius, y, w - 2 * radius, c);
            try gfx.drawFastHLine(x + radius, y + h - 1, w - 2 * radius, c);
            try gfx.drawFastVLine(x, y + radius, h - 2 * radius, c);
            try gfx.drawFastVLine(x + w - 1, y + radius, h - 2 * radius, c);

            var f: i32 = 1 - @as(i32, radius);
            var ddF_x: i32 = 1;
            var ddF_y: i32 = -2 * @as(i32, radius);
            var xx: i32 = 0;
            var yy: i32 = @as(i32, radius);

            while (xx < yy) {
                if (f >= 0) {
                    yy -= 1;
                    ddF_y += 2;
                    f += ddF_y;
                }
                xx += 1;
                ddF_x += 2;
                f += ddF_x;

                const xp = @as(i32, x);
                const yp = @as(i32, y);
                const wp1 = @as(i32, w) - 1;
                const hp1 = @as(i32, h) - 1;
                try gfx.drawPixel(@intCast(xp + xx), @intCast(yp + yy), c);
                try gfx.drawPixel(@intCast(xp + yy), @intCast(yp + xx), c);
                try gfx.drawPixel(@intCast(xp + wp1 - xx), @intCast(yp + yy), c);
                try gfx.drawPixel(@intCast(xp + wp1 - yy), @intCast(yp + xx), c);
                try gfx.drawPixel(@intCast(xp + wp1 - xx), @intCast(yp + hp1 - yy), c);
                try gfx.drawPixel(@intCast(xp + wp1 - yy), @intCast(yp + hp1 - xx), c);
                try gfx.drawPixel(@intCast(xp + xx), @intCast(yp + hp1 - yy), c);
                try gfx.drawPixel(@intCast(xp + yy), @intCast(yp + hp1 - xx), c);
            }
        }

        pub fn fillRoundRect(gfx: *Self, x: u16, y: u16, w: u16, h: u16, r: u16, c: C) !void {
            const radius = @min(r, @min(w / 2, h / 2));
            try gfx.fillRect(x + radius, y, w - 2 * radius, h, c);

            var f: i32 = 1 - @as(i32, radius);
            var ddF_x: i32 = 1;
            var ddF_y: i32 = -2 * @as(i32, radius);
            var xx: i32 = 0;
            var yy: i32 = @as(i32, radius);

            while (xx < yy) {
                if (f >= 0) {
                    yy -= 1;
                    ddF_y += 2;
                    f += ddF_y;
                }
                xx += 1;
                ddF_x += 2;
                f += ddF_x;

                const xp = @as(i32, x);
                const yp = @as(i32, y);
                const w32 = @as(i32, w);
                const hp1 = @as(i32, h) - 1;

                try gfx.drawFastHLine(@intCast(xp + xx), @intCast(yp + yy), @intCast(w32 - 2 * xx), c);
                try gfx.drawFastHLine(@intCast(xp + xx), @intCast(yp + hp1 - yy), @intCast(w32 - 2 * xx), c);
                if (yy != xx) {
                    try gfx.drawFastHLine(@intCast(xp + yy), @intCast(yp + xx), @intCast(w32 - 2 * yy), c);
                    try gfx.drawFastHLine(@intCast(xp + yy), @intCast(yp + hp1 - xx), @intCast(w32 - 2 * yy), c);
                }
            }
        }

        pub fn drawChar(gfx: *Self, x: u16, y: u16, c: u8, fg: C, bg: C, size: u8) !void {
            if (c < 0x20 or c > 0x7E) return;
            const ci = c - 0x20;
            const ch = font5x7[ci];

            for (0..5) |col| {
                var line = ch[col];
                for (0..8) |row| {
                    if (line & 1 != 0) {
                        if (size == 1) {
                            try gfx.drawPixel(x + @as(u16, @intCast(col)), y + @as(u16, @intCast(row)), fg);
                        } else {
                            try gfx.fillRect(
                                x + @as(u16, @intCast(col)) * size,
                                y + @as(u16, @intCast(row)) * size,
                                size, size, fg,
                            );
                        }
                    } else if (fg.value != bg.value) {
                        if (size == 1) {
                            try gfx.drawPixel(x + @as(u16, @intCast(col)), y + @as(u16, @intCast(row)), bg);
                        } else {
                            try gfx.fillRect(
                                x + @as(u16, @intCast(col)) * size,
                                y + @as(u16, @intCast(row)) * size,
                                size, size, bg,
                            );
                        }
                    }
                    line >>= 1;
                }
            }
        }

        pub fn setCursor(gfx: *Self, x: u16, y: u16) void {
            gfx.cursor_x = x;
            gfx.cursor_y = y;
        }

        pub fn setTextColor(gfx: *Self, fg: C) void {
            gfx.text_color = fg;
            gfx.text_bg_color = fg;
        }

        pub fn setTextColorBg(gfx: *Self, fg: C, bg: C) void {
            gfx.text_color = fg;
            gfx.text_bg_color = bg;
        }

        pub fn setTextSize(gfx: *Self, size: u8) void {
            gfx.text_size = size;
        }

        pub fn setTextWrap(gfx: *Self, wrap: bool) void {
            gfx.text_wrap = wrap;
        }

        pub fn write(gfx: *Self, c: u8) !void {
            if (c == '\n') {
                gfx.cursor_y += gfx.text_size * 8;
                gfx.cursor_x = 0;
                return;
            }
            if (c == '\r') {
                gfx.cursor_x = 0;
                return;
            }

            try gfx.drawChar(gfx.cursor_x, gfx.cursor_y, c, gfx.text_color, gfx.text_bg_color, gfx.text_size);
            gfx.cursor_x += gfx.text_size * 6;
            if (gfx.text_wrap and gfx.cursor_x > gfx.width - gfx.text_size * 6) {
                gfx.cursor_y += gfx.text_size * 8;
                gfx.cursor_x = 0;
            }
        }

        pub fn print(gfx: *Self, s: []const u8) !void {
            for (s) |c| try gfx.write(c);
        }
    };
}

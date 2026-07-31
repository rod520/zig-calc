const std = @import("std");
const microzig = @import("microzig");
const rp2xxx = microzig.hal;
const time = rp2xxx.time;

pub const ROWS = 6;
pub const COLS = 6;

/// Bitmask per column; bit `ri` set means row `ri` is pressed on that column.
pub const PressedState = [COLS]u6;

pub const Keypad = struct {
    row_pins: [ROWS]rp2xxx.gpio.Pin,
    col_pins: [COLS]rp2xxx.gpio.Pin,

    pub fn init(row_pins: [ROWS]rp2xxx.gpio.Pin, col_pins: [COLS]rp2xxx.gpio.Pin) Keypad {
        return .{ .row_pins = row_pins, .col_pins = col_pins };
    }

    /// Drive each column high one at a time and read the rows.
    pub fn scan(self: *Keypad) PressedState {
        var pressed = std.mem.zeroes(PressedState);
        for (self.col_pins) |c| c.put(0);
        for (self.col_pins, 0..) |col, ci| {
            col.put(1);
            time.sleep_us(100);
            for (self.row_pins, 0..) |row, ri| {
                if (row.read() == 1)
                    pressed[ci] |= @as(u6, 1) << @intCast(ri);
            }
            col.put(0);
        }
        return pressed;
    }
};

/// Map a physical (row, col) to a button number.
/// Physical wiring runs right-to-left: row0/col5 = 1 ... row5/col0 = 36.
pub fn buttonNumber(row: u8, col: u8) u8 {
    return row * COLS + (COLS - col);
}

/// The lowest-numbered button currently pressed, or null if none.
pub fn firstPressed(pressed: PressedState) ?u8 {
    for (0..ROWS) |r| {
        for (0..COLS) |c| {
            const bit: u6 = @as(u6, 1) << @intCast(r);
            if (pressed[c] & bit != 0)
                return buttonNumber(@intCast(r), @intCast(c));
        }
    }
    return null;
}

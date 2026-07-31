const std = @import("std");

pub const ROWS = 6;
pub const COLS = 6;

/// What a key inserts or does when pressed.
pub const KeyKind = union(enum) {
    unicode: []const u8, // inserts this string
    alpha,               // toggles alpha mode
    shift,               // toggles shift mode
    // soon gonna make menu an array of unicodes, which gets selected over using the display
    menu: []const u8,    // opens a menu, label = payload ("calc_menu", ...)
    pos_neg,             // +/- sign toggle
    arrow: enum { left, down, up, right }, // cursor movement
    backspace,           // delete the char before the cursor
    clear,               // clear the current input
    enter,               // run the current input / paste a highlighted line
    none, // blank / unused slot
};

pub fn unicode(s: []const u8) KeyKind {
    return .{ .unicode = s };
}

pub fn menu(s: []const u8) KeyKind {
    return .{ .menu = s };
}

pub const Key = struct {
    orig: KeyKind,
    alpha: KeyKind = .{ .none = {} },
    shift: KeyKind = .{ .none = {} },
};

/// From key-layout.md, indexed as [row][col] with col = physical column
/// (col5 is the first entry in the md, button 1 = row0/col5).
/// Written as orig/alpha/shift.
pub const KEY_LAYOUT = [ROWS][COLS]Key{
    .{
        .{ .orig = .{ .arrow = .right } },
        .{ .orig = .{ .arrow = .up } },
        .{ .orig = .{ .arrow = .down } },
        .{ .orig = .{ .arrow = .left } },
        .{ .orig = .shift },
        .{ .orig = .alpha },
    },
    .{
        .{ .orig = .enter, .alpha = unicode("f") },
        .{ .orig = unicode("sqrt"), .alpha = unicode("e"), .shift = unicode("n_log") },
        .{ .orig = unicode("ℯ"), .alpha = unicode("d"), .shift = unicode("ln") },
        .{ .orig = unicode("^"), .alpha = unicode("c"), .shift = unicode("log_b") },
        .{ .orig = menu("trig_menu"), .alpha = unicode("b") },
        .{ .orig = menu("calc_menu"), .alpha = unicode("a"), .shift = menu("stats_menu") },
    },
    .{
        .{ .orig = unicode("/") },
        .{ .orig = unicode("9"), .alpha = unicode("k") },
        .{ .orig = unicode("8"), .alpha = unicode("j") },
        .{ .orig = unicode("7"), .alpha = unicode("i") },
        .{ .orig = unicode("y"), .alpha = unicode("h") },
        .{ .orig = unicode("x"), .alpha = unicode("g") },
    },
    .{
        .{ .orig = unicode("*"), .shift = unicode("r") },
        .{ .orig = unicode("6"), .alpha = unicode("q") },
        .{ .orig = unicode("5"), .alpha = unicode("p") },
        .{ .orig = unicode("4"), .alpha = unicode("o") },
        .{ .orig = unicode("("), .alpha = unicode("n") },
        .{ .orig = unicode(":="), .alpha = unicode("m") },
    },
    .{
        .{ .orig = unicode("-"), .shift = unicode("x") },
        .{ .orig = unicode("3"), .alpha = unicode("w") },
        .{ .orig = unicode("2"), .alpha = unicode("v") },
        .{ .orig = unicode("1"), .alpha = unicode("u") },
        .{ .orig = unicode(")"), .alpha = unicode("t") },
        .{ .orig = unicode("π"), .alpha = unicode("s") },
    },
    .{
        .{ .orig = unicode("+") },
        .{ .orig = .pos_neg },
        .{ .orig = unicode(".") },
        .{ .orig = unicode("0") },
        .{ .orig = .backspace, .alpha = unicode("z") },
        .{ .orig = .clear, .alpha = unicode("y") },
    },
};

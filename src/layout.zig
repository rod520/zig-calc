const std = @import("std");

pub const ROWS = 6;
pub const COLS = 6;

/// A menu entry: what the user sees and the value it inserts.
pub const MenuItem = struct {
    label: []const u8,
    value: []const u8,
};

/// What a key inserts or does when pressed.
pub const KeyKind = union(enum) {
    unicode: []const u8, // inserts this string
    alpha, // toggles alpha mode
    shift, // toggles shift mode
    menu: []const MenuItem, // opens a menu (label/value pairs, picked on the display)
    pos_neg, // +/- sign toggle
    arrow: enum { left, down, up, right }, // cursor movement
    backspace, // delete the char before the cursor
    clear, // clear the current input
    enter, // run the current input / paste a highlighted line
    none, // blank / unused slot
};

pub fn unicode(s: []const u8) KeyKind {
    return .{ .unicode = s };
}

pub fn menu(s: []const MenuItem) KeyKind {
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
        .{ .orig = .enter, .alpha = unicode("F") },
        .{ .orig = unicode("sqrt"), .alpha = unicode("E"), .shift = unicode("log(") },
        .{ .orig = unicode("ℯ"), .alpha = unicode("D"), .shift = unicode("ln(") },
        .{ .orig = unicode("^("), .alpha = unicode("C"), .shift = unicode("log_b(") },

        .{
            .orig = menu(&.{
                // all trig functions here
                .{ .label = "sin", .value = "sin(" },
                .{ .label = "cos", .value = "cos(" },
                .{ .label = "tan", .value = "tan(" },
                // arctrig, only one argument
                .{ .label = "asin", .value = "asin(" },
                .{ .label = "acos", .value = "acos(" },
                .{ .label = "atan", .value = "atan(" },
            }),
            .alpha = unicode("B"),
        },
        .{ // calc menu: solve, diff, int
            .orig = menu(&.{
            .{ .label = "solve", .value = "solve(" },
            .{ .label = "diff", .value = "diff(" },
            .{ .label = "int", .value = "int(" },
        }),
        // stats menu
         .alpha = unicode("A"), .shift = menu(&.{
            .{ .label = "normal", .value = "normal(" },
            .{ .label = "invNormal", .value = "invnorm(" },
            .{ .label = "nCr", .value = "ncr(" },
            .{ .label = "nPr", .value = "npr(" },
            .{ .label = "factorial", .value = "fact(" },
         }) },
    },
    .{
        .{ .orig = unicode("/"), .alpha = unicode("L") },
        .{ .orig = unicode("9"), .alpha = unicode("K") },
        .{ .orig = unicode("8"), .alpha = unicode("J") },
        .{ .orig = unicode("7"), .alpha = unicode("I") },
        .{ .orig = unicode("^(2)"), .alpha = unicode("H") },
        .{ .orig = unicode("x"), .alpha = unicode("G") },
    },
    .{
        .{ .orig = unicode("*"), .shift = unicode("R") },
        .{ .orig = unicode("6"), .alpha = unicode("Q") },
        .{ .orig = unicode("5"), .alpha = unicode("P") },
        .{ .orig = unicode("4"), .alpha = unicode("O") },
        .{ .orig = unicode("("), .alpha = unicode("N") },
        .{ .orig = unicode(":="), .alpha = unicode("M") },
    },
    .{
        .{ .orig = unicode("-"), .shift = unicode("X") },
        .{ .orig = unicode("3"), .alpha = unicode("W") },
        .{ .orig = unicode("2"), .alpha = unicode("V") },
        .{ .orig = unicode("1"), .alpha = unicode("U") },
        .{ .orig = unicode(")"), .alpha = unicode("T") },
        .{ .orig = unicode("π"), .alpha = unicode("S") },
    },
    .{
        .{ .orig = unicode("+") },
        .{ .orig = .pos_neg },
        .{ .orig = unicode(".") },
        .{ .orig = unicode("0") },
        .{ .orig = .backspace, .alpha = unicode("Z") },
        .{ .orig = .clear, .alpha = unicode("Y") },
    },
};

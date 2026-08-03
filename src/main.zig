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

const input_cap = 64;
const hist_cap = 32;
const ring_cap = 38; // transcript rows that fit between y=8 and y=312
const line_max = 40; // chars per display row (240px / 6px per char)
const tail_vis = line_max - 2; // chars visible after "> " when a line overflows
const res_cap = 64; // result string buffer (must be >= 53 for float render)

const Repl = struct {
    input: [input_cap]u8 = undefined,
    input_len: usize = 0,
    cursor: usize = 0,
    alpha_on: bool = false,
    shift_on: bool = false,

    // A-Z variables (uppercase only); NaN = unassigned.
    vars: [26]f64 = @splat(std.math.nan(f64)),

    history: [hist_cap]HistoryEntry = undefined,
    hist_count: usize = 0,

    hl_k: usize = 0, // 1..hist_count = kth newest history line highlighted, 0 = none

    fn init() Repl {
        return .{};
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

    /// Insert a unicode string. Multi-byte characters collapse to single
    /// sentinel bytes: 0xEE (Euler script-e), 0xEF (pi), 0xAF (raised minus)
    /// so they render as their own glyphs.
    fn insert(self: *Repl, s: []const u8) void {
        var i: usize = 0;
        while (i < s.len and self.input_len < input_cap) {
            if (s[i] == 0xE2 and i + 2 < s.len and s[i + 1] == 0x84 and s[i + 2] == 0xAF) {
                self.insertByte(0xEE);
                i += 3;
            } else if (s[i] == 0xCF and i + 1 < s.len and s[i + 1] == 0x80) {
                self.insertByte(0xEF);
                i += 2;
            } else if (s[i] == 0xC2 and i + 1 < s.len and s[i + 1] == 0xAF) {
                self.insertByte(0xAF);
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
        const src = self.history[slot].line[0..self.history[slot].len];
        const fit = @min(src.len, input_cap - self.input_len);
        var i = self.input_len;
        while (i > self.cursor) : (i -= 1)
            self.input[i + fit] = self.input[i];
        copyBytes(self.input[self.cursor .. self.cursor + fit], src[0..fit]);
        self.cursor += fit;
        self.input_len += fit;
        self.hl_k = 0;
    }

    fn addHistory(self: *Repl, e: HistoryEntry) void {
        var slot = self.hist_count;
        if (self.hist_count == hist_cap) {
            var i: usize = 0;
            while (i + 1 < hist_cap) : (i += 1) self.history[i] = self.history[i + 1];
            slot = hist_cap - 1;
        } else {
            self.hist_count += 1;
        }
        self.history[slot] = e;
    }

    fn writeResult(e: *HistoryEntry, msg: []const u8) void {
        const m = if (msg.len == 0) "evaluation failed" else msg;
        const pre = "error: ";
        copyBytes(e.result[0..pre.len], pre);
        var n: usize = pre.len;
        for (m) |c| {
            if (n >= res_cap) break;
            e.result[n] = c;
            n += 1;
        }
        e.rlen = n;
    }

    fn eval(self: *Repl) void {
        if (self.input_len == 0) return;
        var entry = HistoryEntry{};
        entry.len = self.input_len;
        copyBytes(entry.line[0..self.input_len], self.input[0..self.input_len]);
        self.computeResult(&entry);
        self.addHistory(entry);
        self.clearInput();
        self.hl_k = 0;
    }

    fn computeResult(self: *Repl, e: *HistoryEntry) void {
        const src = e.line[0..e.len];
        var p = Parser.init(src);

        // "A := expr" assignment. Detected by the ":=" at index 1.
        if (e.len >= 3 and src[0] >= 'A' and src[0] <= 'Z' and src[1] == ':' and src[2] == '=') {
            p = Parser.init(src[3..]);
            const root = p.parseExpr() catch {
                writeResult(e, p.err);
                return;
            };
            p.skipSpaces();
            if (p.pos != src.len - 3) {
                writeResult(e, "trailing characters");
                return;
            }
            const v = evalNode(self, &p, root, null) catch {
                writeResult(e, p.err);
                return;
            };
            if (std.math.isNan(v) or std.math.isInf(v)) {
                writeResult(e, "invalid assignment value");
                return;
            }
            self.vars[src[0] - 'A'] = v;
            formatResult(e, v);
            return;
        }

        const root = p.parseExpr() catch {
            writeResult(e, p.err);
            return;
        };
        p.skipSpaces();
        if (p.pos != src.len) {
            writeResult(e, "trailing characters");
            return;
        }
        const v = evalNode(self, &p, root, null) catch {
            writeResult(e, p.err);
            return;
        };
        if (std.math.isNan(v)) {
            writeResult(e, "result is not a number");
            return;
        }
        if (std.math.isInf(v)) {
            writeResult(e, "result is too large");
            return;
        }
        formatResult(e, v);
    }
};

const HistoryEntry = struct {
    line: [input_cap]u8 = undefined,
    len: usize = 0,
    result: [res_cap]u8 = undefined,
    rlen: usize = 0,
};

// ---------------------------------------------------------------------------
// Expression parser + evaluator
// ---------------------------------------------------------------------------

const NodeTag = enum { num, variable, neg, bin, call };

const Func = enum {
    sin, cos, tan, asin, acos, atan,
    sqrt, ln, log, log_b, exp,
    floor, ceil, round, abs,
    fact, ncr, npr, normal, invnorm,
    solve, diff, int,
    none,
};

const Node = struct {
    tag: NodeTag = .num,
    val: f64 = 0, // number value
    ch: u8 = 0, // variable letter
    op: u8 = 0, // binary operator: + - * / ^
    func: Func = .none,
    argc: u8 = 0,
    kids: [4]u16 = .{ 0, 0, 0, 0 },
};

const NodePoolSize = 160;

const EvalError = error{Eval};

const Parser = struct {
    src: []const u8,
    pos: usize = 0,
    nodes: [NodePoolSize]Node = undefined,
    nn: u16 = 0,
    err: []const u8 = "",

    fn init(src: []const u8) Parser {
        return .{ .src = src };
    }

    fn fail(p: *Parser, msg: []const u8) error{Eval} {
        if (p.err.len == 0) p.err = msg;
        return error.Eval;
    }

    fn peek(p: *Parser) u8 {
        if (p.pos < p.src.len) return p.src[p.pos];
        return 0;
    }

    fn bump(p: *Parser) void {
        if (p.pos < p.src.len) p.pos += 1;
    }

    fn skipSpaces(p: *Parser) void {
        while (p.peek() == ' ') p.bump();
    }

    fn newNode(p: *Parser, n: Node) EvalError!u16 {
        if (p.nn >= p.nodes.len) return p.fail("expression too complex");
        p.nodes[p.nn] = n;
        p.nn += 1;
        return p.nn - 1;
    }

    fn startsPrimary(c: u8) bool {
        return (c >= '0' and c <= '9') or c == '.' or c == '(' or
            c == 0xEE or c == 0xEF or isIdentStart(c);
    }

    fn parseExpr(p: *Parser) EvalError!u16 {
        var left = try p.parseTerm();
        while (true) {
            p.skipSpaces();
            const c = p.peek();
            if (c != '+' and c != '-') break;
            p.bump();
            const right = try p.parseTerm();
            left = try p.newNode(.{ .tag = .bin, .op = c, .kids = .{ left, right, 0, 0 } });
        }
        return left;
    }

    fn parseTerm(p: *Parser) EvalError!u16 {
        var left = try p.parseUnary();
        while (true) {
            p.skipSpaces();
            const c = p.peek();
            if (c == '*' or c == '/') {
                p.bump();
                const right = try p.parseUnary();
                left = try p.newNode(.{ .tag = .bin, .op = c, .kids = .{ left, right, 0, 0 } });
            } else if (startsPrimary(c)) {
                // implicit multiplication: 2π, 3(4), 2x, 2sin(3)
                const right = try p.parseUnary();
                left = try p.newNode(.{ .tag = .bin, .op = '*', .kids = .{ left, right, 0, 0 } });
            } else break;
        }
        return left;
    }

    fn parseUnary(p: *Parser) EvalError!u16 {
        p.skipSpaces();
        const c = p.peek();
        if (c == '-' or c == 0xAF) {
            p.bump();
            const kid = try p.parseUnary();
            return p.newNode(.{ .tag = .neg, .kids = .{ kid, 0, 0, 0 } });
        }
        return p.parsePower();
    }

    fn parsePower(p: *Parser) EvalError!u16 {
        const left = try p.parsePrimary();
        p.skipSpaces();
        if (p.peek() == '^') {
            p.bump();
            const right = try p.parseUnary(); // right-associative
            return p.newNode(.{ .tag = .bin, .op = '^', .kids = .{ left, right, 0, 0 } });
        }
        return left;
    }

    fn parsePrimary(p: *Parser) EvalError!u16 {
        p.skipSpaces();
        const c = p.peek();
        if (c == 0) return p.fail("unexpected end of expression");
        if (c >= '0' and c <= '9' or c == '.') return p.parseNumber();
        if (c == '(') {
            p.bump();
            const inner = try p.parseExpr();
            p.skipSpaces();
            if (p.peek() != ')') return p.fail("expected )");
            p.bump();
            return inner;
        }
        if (c == 0xEE) {
            p.bump();
            return p.newNode(.{ .tag = .num, .val = std.math.e });
        }
        if (c == 0xEF) {
            p.bump();
            return p.newNode(.{ .tag = .num, .val = std.math.pi });
        }
        if (isIdentStart(c)) return p.parseIdent();
        return p.fail("unexpected character");
    }

    fn parseNumber(p: *Parser) EvalError!u16 {
        var v: f64 = 0;
        var frac_scale: f64 = 1;
        var have_digit = false;
        var c = p.peek();
        while (c >= '0' and c <= '9') {
            v = v * 10 + @as(f64, @floatFromInt(c - '0'));
            have_digit = true;
            p.bump();
            c = p.peek();
        }
        if (c == '.') {
            p.bump();
            c = p.peek();
            while (c >= '0' and c <= '9') {
                frac_scale *= 10;
                v += @as(f64, @floatFromInt(c - '0')) / frac_scale;
                have_digit = true;
                p.bump();
                c = p.peek();
            }
        }
        if (!have_digit) return p.fail("malformed number");
        return p.newNode(.{ .tag = .num, .val = v });
    }

    fn parseIdent(p: *Parser) EvalError!u16 {
        const start = p.pos;
        while (isIdentStart(p.peek())) p.bump();
        const name = p.src[start..p.pos];
        if (name.len == 1) {
            const ch = name[0];
            if ((ch >= 'A' and ch <= 'Z') or ch == 'x')
                return p.newNode(.{ .tag = .variable, .ch = ch });
            return p.fail("unknown variable");
        }
        const f = nameToFunc(name) orelse return p.fail("unknown function");
        p.skipSpaces();
        if (p.peek() != '(') return p.fail("function needs (");
        p.bump();
        return p.parseCall(f);
    }

    fn parseCall(p: *Parser, f: Func) EvalError!u16 {
        var kids: [4]u16 = .{ 0, 0, 0, 0 };
        var argc: u8 = 0;
        if (p.peek() != ')') {
            while (true) {
                if (argc >= 4) return p.fail("too many arguments");
                kids[argc] = try p.parseExpr();
                argc += 1;
                p.skipSpaces();
                const c = p.peek();
                if (c == ')') break;
                if (c == ',') {
                    p.bump();
                    continue;
                }
                return p.fail("expected , or )");
            }
        }
        p.bump();
        if (argc != argCount(f)) return p.fail("wrong argument count");
        return p.newNode(.{ .tag = .call, .func = f, .argc = argc, .kids = kids });
    }
};

fn isIdentStart(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}

fn nameToFunc(name: []const u8) ?Func {
    const table = [_]struct { n: []const u8, f: Func }{
        .{ .n = "sin", .f = .sin },
        .{ .n = "cos", .f = .cos },
        .{ .n = "tan", .f = .tan },
        .{ .n = "asin", .f = .asin },
        .{ .n = "acos", .f = .acos },
        .{ .n = "atan", .f = .atan },
        .{ .n = "sqrt", .f = .sqrt },
        .{ .n = "ln", .f = .ln },
        .{ .n = "log", .f = .log },
        .{ .n = "log_b", .f = .log_b },
        .{ .n = "exp", .f = .exp },
        .{ .n = "floor", .f = .floor },
        .{ .n = "ceil", .f = .ceil },
        .{ .n = "round", .f = .round },
        .{ .n = "abs", .f = .abs },
        .{ .n = "fact", .f = .fact },
        .{ .n = "ncr", .f = .ncr },
        .{ .n = "npr", .f = .npr },
        .{ .n = "normal", .f = .normal },
        .{ .n = "invnorm", .f = .invnorm },
        .{ .n = "solve", .f = .solve },
        .{ .n = "diff", .f = .diff },
        .{ .n = "int", .f = .int },
    };
    for (table) |entry| {
        if (std.mem.eql(u8, name, entry.n)) return entry.f;
    }
    return null;
}

fn argCount(f: Func) u8 {
    return switch (f) {
        .sin, .cos, .tan, .asin, .acos, .atan,
        .sqrt, .ln, .log, .exp, .floor, .ceil, .round, .abs, .fact => 1,
        .log_b, .ncr, .npr, .solve, .diff => 2,
        .invnorm, .int => 3,
        .normal => 4,
        .none => 0,
    };
}

// -- evaluation -------------------------------------------------------------

fn evalNode(repl: *Repl, p: *Parser, idx: u16, xv: ?f64) EvalError!f64 {
    const n = &p.nodes[idx];
    return switch (n.tag) {
        .num => n.val,
        .variable => blk: {
            if (n.ch == 'x') {
                if (xv) |v| break :blk v;
                return p.fail("x is undefined");
            }
            const v = repl.vars[n.ch - 'A'];
            if (std.math.isNan(v)) return p.fail("variable is unassigned");
            break :blk v;
        },
        .neg => -try evalNode(repl, p, n.kids[0], xv),
        .bin => blk: {
            const l = try evalNode(repl, p, n.kids[0], xv);
            const r = try evalNode(repl, p, n.kids[1], xv);
            switch (n.op) {
                '+' => break :blk l + r,
                '-' => break :blk l - r,
                '*' => break :blk l * r,
                '/' => if (r == 0) return p.fail("division by zero") else break :blk l / r,
                '^' => break :blk std.math.pow(f64, l, r),
                else => return p.fail("bad operator"),
            }
        },
        .call => evalCall(repl, p, n, xv),
    };
}

fn evalCall(repl: *Repl, p: *Parser, n: *const Node, xv: ?f64) EvalError!f64 {
    switch (n.func) {
        .solve => {
            const guess = try evalNode(repl, p, n.kids[1], null);
            return evalSolve(repl, p, n.kids[0], guess);
        },
        .diff => {
            const x0 = try evalNode(repl, p, n.kids[1], null);
            return evalDiff(repl, p, n.kids[0], x0);
        },
        .int => {
            const a = try evalNode(repl, p, n.kids[1], null);
            const b = try evalNode(repl, p, n.kids[2], null);
            return evalInt(repl, p, n.kids[0], a, b);
        },
        else => {
            var args: [4]f64 = undefined;
            var i: usize = 0;
            while (i < n.argc) : (i += 1)
                args[i] = try evalNode(repl, p, n.kids[i], xv);
            return switch (n.func) {
                .sin => std.math.sin(args[0]),
                .cos => std.math.cos(args[0]),
                .tan => std.math.tan(args[0]),
                .asin => blk: {
                    if (args[0] < -1 or args[0] > 1) return p.fail("asin domain error");
                    break :blk std.math.asin(args[0]);
                },
                .acos => blk: {
                    if (args[0] < -1 or args[0] > 1) return p.fail("acos domain error");
                    break :blk std.math.acos(args[0]);
                },
                .atan => std.math.atan(args[0]),
                .sqrt => blk: {
                    if (args[0] < 0) return p.fail("sqrt of negative");
                    break :blk std.math.sqrt(args[0]);
                },
                .ln => blk: {
                    if (args[0] <= 0) return p.fail("ln of non-positive");
                    break :blk std.math.log(f64, std.math.e, args[0]);
                },
                .log => blk: {
                    if (args[0] <= 0) return p.fail("log of non-positive");
                    break :blk std.math.log10(args[0]);
                },
                .log_b => logBase(p, args[0], args[1]),
                .exp => std.math.exp(args[0]),
                .floor => std.math.floor(args[0]),
                .ceil => std.math.ceil(args[0]),
                .round => std.math.round(args[0]),
                .abs => @abs(args[0]),
                .fact => factorial(p, args[0]),
                .ncr => nCr(p, args[0], args[1]),
                .npr => nPr(p, args[0], args[1]),
                .normal => normalP(p, args[0], args[1], args[2], args[3]),
                .invnorm => invNorm(p, args[0], args[1], args[2]),
                else => return p.fail("bad function"),
            };
        },
    }
}

fn logBase(p: *Parser, b: f64, x: f64) EvalError!f64 {
    if (b <= 0 or b == 1) return p.fail("invalid log base");
    if (x <= 0) return p.fail("log of non-positive");
    return std.math.log(f64, b, x);
}

fn factorial(p: *Parser, v: f64) EvalError!f64 {
    if (v < 0) return p.fail("factorial of negative");
    if (v != std.math.floor(v)) return p.fail("factorial needs an integer");
    const n: u64 = @intFromFloat(v);
    if (n > 170) return p.fail("factorial too large");
    var r: f64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) r *= @as(f64, @floatFromInt(i));
    return r;
}

fn nCr(p: *Parser, a: f64, b: f64) EvalError!f64 {
    if (a < 0 or b < 0) return p.fail("nCr needs non-negative numbers");
    if (a != std.math.floor(a) or b != std.math.floor(b)) return p.fail("nCr needs integers");
    const n: u64 = @intFromFloat(a);
    const rr: u64 = @intFromFloat(b);
    if (rr > n) return p.fail("r must not exceed n");
    const r = @min(rr, n - rr);
    var acc: f64 = 1;
    var k: u64 = 0;
    while (k < r) : (k += 1)
        acc = acc * @as(f64, @floatFromInt(n - k)) / @as(f64, @floatFromInt(k + 1));
    return acc;
}

fn nPr(p: *Parser, a: f64, b: f64) EvalError!f64 {
    if (a < 0 or b < 0) return p.fail("nPr needs non-negative numbers");
    if (a != std.math.floor(a) or b != std.math.floor(b)) return p.fail("nPr needs integers");
    const n: u64 = @intFromFloat(a);
    const r: u64 = @intFromFloat(b);
    if (r > n) return p.fail("r must not exceed n");
    var acc: f64 = 1;
    var k: u64 = 0;
    while (k < r) : (k += 1) acc *= @as(f64, @floatFromInt(n - k));
    return acc;
}

/// Abramowitz & Stegun 7.1.26, max abs error ~1.5e-7.
fn erf(x: f64) f64 {
    const sign: f64 = if (x < 0) -1 else 1;
    const ax = @abs(x);
    const t = 1 / (1 + 0.3275911 * ax);
    const poly = ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t;
    return sign * (1 - poly * std.math.exp(-ax * ax));
}

/// Standard normal CDF.
fn phi(x: f64) f64 {
    return 0.5 * (1 + erf(x / std.math.sqrt(2.0)));
}

fn normalP(p: *Parser, lower: f64, upper: f64, mu: f64, sigma: f64) EvalError!f64 {
    if (sigma <= 0) return p.fail("sigma must be positive");
    const zu = (upper - mu) / sigma;
    const zl = (lower - mu) / sigma;
    return phi(zu) - phi(zl);
}

/// Standard normal quantile via rational start + Newton polish.
fn invPhi(px: f64) f64 {
    if (px == 0.5) return 0;
    if (px < 0.5) return -invPhi(1 - px);
    const t = std.math.sqrt(-2 * std.math.log(f64, std.math.e, 1 - px));
    const num = 2.515517 + 0.802853 * t + 0.010328 * t * t;
    const den = 1 + 1.432788 * t + 0.189269 * t * t + 0.001308 * t * t * t;
    var z = t - num / den;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const d = phi(z) - px;
        const dp = 0.3989422804014327 * std.math.exp(-z * z / 2);
        const nz = z - d / dp;
        if (nz == z) break;
        z = nz;
    }
    return z;
}

fn invNorm(p: *Parser, prob: f64, mu: f64, sigma: f64) EvalError!f64 {
    if (sigma <= 0) return p.fail("sigma must be positive");
    if (prob <= 0 or prob >= 1) return p.fail("p must be between 0 and 1");
    return mu + sigma * invPhi(prob);
}

fn evalDiff(repl: *Repl, p: *Parser, eq: u16, x0: f64) EvalError!f64 {
    const h = 1e-6 * (1 + @abs(x0));
    const fa = try evalNode(repl, p, eq, x0 - h);
    const fb = try evalNode(repl, p, eq, x0 + h);
    return (fb - fa) / (2 * h);
}

const simpson_max_depth = 8;

fn simpson(repl: *Repl, p: *Parser, eq: u16, a: f64, b: f64, fa: f64, fm: f64, fb: f64, depth: usize) EvalError!f64 {
    const whole = (b - a) / 6 * (fa + 4 * fm + fb);
    if (depth >= simpson_max_depth) return whole;
    const mid = (a + b) / 2;
    const lm = (a + mid) / 2;
    const rm = (mid + b) / 2;
    const flm = try evalNode(repl, p, eq, lm);
    const frm = try evalNode(repl, p, eq, rm);
    const left = (mid - a) / 6 * (fa + 4 * flm + fm);
    const right = (b - mid) / 6 * (fm + 4 * frm + fb);
    const delta = (left + right) - whole;
    const mag = if (@abs(left + right) > 1e-30) @abs(left + right) else 1e-30;
    if (@abs(delta) <= 1e-9 * mag) return left + right + delta / 15;
    return (try simpson(repl, p, eq, a, mid, fa, flm, fm, depth + 1)) +
        (try simpson(repl, p, eq, mid, b, fm, frm, fb, depth + 1));
}

fn evalInt(repl: *Repl, p: *Parser, eq: u16, a: f64, b: f64) EvalError!f64 {
    if (a == b) return 0;
    const fa = try evalNode(repl, p, eq, a);
    const fm = try evalNode(repl, p, eq, (a + b) / 2);
    const fb = try evalNode(repl, p, eq, b);
    return simpson(repl, p, eq, a, b, fa, fm, fb, 0);
}

fn evalSolve(repl: *Repl, p: *Parser, eq: u16, guess: f64) EvalError!f64 {
    const fg = try evalNode(repl, p, eq, guess);
    if (fg == 0) return guess;

    // Bracket a root around the guess, then bisect.
    var delta: f64 = if (guess == 0) 1 else @abs(guess) / 4;
    const max_delta = 1e6 * @max(1, @abs(guess));
    var i: usize = 0;
    while (i < 60 and delta <= max_delta) : (i += 1) {
        const a = guess - delta;
        const b = guess + delta;
        const fa = try evalNode(repl, p, eq, a);
        const fb = try evalNode(repl, p, eq, b);
        if ((fa <= 0 and fb >= 0) or (fa >= 0 and fb <= 0)) {
            var lo = a;
            var hi = b;
            var flo = fa;
            var k: usize = 0;
            while (k < 80) : (k += 1) {
                const mid = (lo + hi) / 2;
                const fm = try evalNode(repl, p, eq, mid);
                if (fm == 0 or (hi - lo) <= 1e-15 * @max(1, @abs(mid))) return mid;
                if ((flo <= 0 and fm >= 0) or (flo >= 0 and fm <= 0)) {
                    hi = mid;
                } else {
                    lo = mid;
                    flo = fm;
                }
            }
            return (lo + hi) / 2;
        }
        delta *= 2;
    }

    // Fall back to Newton from the guess.
    var x = guess;
    var k: usize = 0;
    while (k < 40) : (k += 1) {
        const fx = try evalNode(repl, p, eq, x);
        if (@abs(fx) <= 1e-12 * @max(1, @abs(x))) return x;
        const h = 1e-6 * (1 + @abs(x));
        const fh = try evalNode(repl, p, eq, x + h);
        const deriv = (fh - fx) / h;
        if (deriv == 0) return p.fail("cannot find a solution");
        const nx = x - fx / deriv;
        if (nx == x or !std.math.isFinite(nx)) return p.fail("cannot find a solution");
        x = nx;
    }
    return p.fail("cannot find a solution");
}

// -- result formatting ------------------------------------------------------

/// Format a number with up to 10 significant digits, %g-style: plain decimal
/// for normal magnitudes, scientific otherwise. Trailing zeros are trimmed.
fn formatResult(e: *HistoryEntry, v: f64) void {
    var buf: [res_cap]u8 = undefined;
    var s: []const u8 = undefined;
    if (v == 0) {
        s = "0";
    } else {
        const a = @abs(v);
        if (a >= 1e9 or a < 1e-4) {
            s = std.fmt.float.render(&buf, v, .{ .mode = .scientific, .precision = 9 }) catch "error: overflow";
        } else {
            const int_digits: i32 = @as(i32, @intFromFloat(@floor(std.math.log10(a)))) + 1;
            const dec: usize = @intCast(@max(0, 10 - int_digits));
            s = std.fmt.float.render(&buf, v, .{ .mode = .decimal, .precision = dec }) catch "error: overflow";
        }
    }
    // Trim trailing zeros (and a bare '.') only after a decimal point.
    var out: [res_cap]u8 = undefined;
    var n: usize = 0;
    const epos = std.mem.indexOfScalar(u8, s, 'e');
    var mant = if (epos) |ep| s[0..ep] else s;
    if (std.mem.indexOfScalar(u8, mant, '.') != null) {
        while (mant.len > 1 and mant[mant.len - 1] == '0') mant = mant[0 .. mant.len - 1];
        if (mant[mant.len - 1] == '.') mant = mant[0 .. mant.len - 1];
    }
    for (mant) |c| {
        out[n] = c;
        n += 1;
    }
    if (epos) |ep| for (s[ep..]) |c| {
        out[n] = c;
        n += 1;
    };
    e.rlen = @min(n, res_cap);
    Repl.copyBytes(e.result[0..e.rlen], out[0..e.rlen]);
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

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
    var s: [line_max]u8 = undefined;
    @memset(s[0..], ' ');
    const title = "REPL";
    for (title, 0..) |c, i| s[i] = c;
    const mode = if (repl.shift_on) "SHIFT" else if (repl.alpha_on) "ALPHA" else "";
    if (mode.len > 0) {
        const start = line_max - mode.len;
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
        const y: u16 = @intCast(8 + i * 8);
        const entry = &repl.history[e];
        if (is_result) {
            try gfx.drawTextLine(y, entry.result[0..entry.rlen], Gfx.Colors.darkgrey, Gfx.Colors.black);
            continue;
        }
        var hl = false;
        if (repl.hl_k > 0) {
            const slot = repl.hist_count - repl.hl_k;
            if (slot == e) hl = true;
        }
        var buf: [line_max]u8 = undefined;
        const n = entry.len;
        if (n <= tail_vis) {
            buf[0] = '>';
            buf[1] = ' ';
            for (entry.line[0..n], 0..) |c, j| buf[2 + j] = c;
            if (hl) {
                try gfx.drawTextLine(y, buf[0 .. n + 2], Gfx.Colors.black, Gfx.Colors.yellow);
            } else {
                try gfx.drawTextLine(y, buf[0 .. n + 2], Gfx.Colors.white, Gfx.Colors.black);
            }
        } else {
            buf[0] = '>';
            buf[1] = ' ';
            for (entry.line[n - tail_vis .. n], 0..) |c, j| buf[2 + j] = c;
            if (hl) {
                try gfx.drawTextLine(y, buf[0..line_max], Gfx.Colors.black, Gfx.Colors.yellow);
            } else {
                try gfx.drawTextLine(y, buf[0..line_max], Gfx.Colors.white, Gfx.Colors.black);
            }
        }
    }
}

fn redrawPrompt(gfx: *Gfx, repl: *const Repl) !void {
    var s: [line_max]u8 = undefined;
    s[0] = '>';
    s[1] = ' ';
    var rel: usize = repl.cursor;
    if (repl.input_len <= tail_vis) {
        for (repl.input[0..repl.input_len], 0..) |c, i| s[2 + i] = c;
        try gfx.drawTextLine(312, s[0 .. repl.input_len + 2], Gfx.Colors.white, Gfx.Colors.black);
    } else {
        const start = repl.input_len - tail_vis;
        for (repl.input[start..repl.input_len], 0..) |c, i| s[2 + i] = c;
        try gfx.drawTextLine(312, s[0..line_max], Gfx.Colors.white, Gfx.Colors.black);
        rel = if (repl.cursor < start) 0 else repl.cursor - start;
    }
    const cx: u16 = @intCast(@min(12 + rel * 6, 238));
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
        var buf: [line_max]u8 = undefined;
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
            .pos_neg => repl.insert("¯"),
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

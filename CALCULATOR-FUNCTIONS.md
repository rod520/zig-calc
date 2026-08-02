# Calculator Function Catalog

Every math function the calculator exposes (menu items + direct keys) — the label,
the string inserted into the input, its signature, and intended semantics.

> **Status**: the REPL is still a faux echo — these strings insert but are not
> yet evaluated. Angles are assumed **radians** unless a DEG mode is added.
> `n`, `r`, `a`, `b` below stand for whatever numbers/expressions the user types.

---

## Menu functions

### Trig menu (`trig_menu`, orig of the `b` key)

| Label | Inserts | Signature | Meaning                                                        |
| ----- | ------- | --------- | -------------------------------------------------------------- |
| sin   | `sin(`  | `sin(x)`  | Sine.                                                          |
| cos   | `cos(`  | `cos(x)`  | Cosine.                                                        |
| tan   | `tan(`  | `tan(x)`  | Tangent.                                                       |
| asin  | `asin(` | `asin(x)` | Arcsin (inverse sine). Domain `[-1,1]`; returns `[-π/2, π/2]`. |
| acos  | `acos(` | `acos(x)` | Arccos. Domain `[-1,1]`; returns `[0, π]`.                     |
| atan  | `atan(` | `atan(x)` | Arctan. Returns `(-π/2, π/2)`.                                 |

### Calc menu (`calc_menu`, orig of the `a` key)

| Label | Inserts  | Signature                | Meaning                                                                                      |
| ----- | -------- | ------------------------ | -------------------------------------------------------------------------------------------- |
| solve | `solve(` | `solve(eq, var, guess)`  | Find a solution (zero) of an expression `eq` for `var`, e.g. `solve(x^2-4, x, 1)` → `x = 2`. |
| diff  | `diff(`  | `diff(expr, var, value)` | Derivative of `expr` w.r.t. `var`, e.g. `diff(x^2, x, 1)` → `2`.                             |
| int   | `int(`   | `int(expr, var, a, b)`   | Definite integral over `[a, b]`.                                                             |

### Stats menu (`stats_menu`, shift of the `a` key)

| Label     | Inserts    | Signature                    | Meaning                                                                             |
| --------- | ---------- | ---------------------------- | ----------------------------------------------------------------------------------- |
| normal    | `normal(`  | `normal(lower, upper, μ, σ)` | Normal CDF: `P(lower ≤ X ≤ upper)` for `X ~ N(μ, σ)`.                               |
| invNormal | `invnorm(` | `invnorm(p, μ, σ)`           | Inverse normal (quantile): returns `x` with `P(X ≤ x) = p` for `X ~ N(μ, σ)`.       |
| nCr       | `ncr(`     | `ncr(n, r)`                  | Combinations: `n! / (r! (n-r)!)`, number of ways to pick `r` of `n` ignoring order. |
| nPr       | `npr(`     | `npr(n, r)`                  | Permutations: `n! / (n-r)!`, number of ordered arrangements of `r` from `n`.        |
| fact      | `fact(`    | `fact(n)`                    | Factorial: n*(n-1)*...\*1                                                           |

---

## Direct keys (not menus)

| Key   | Mode          | Inserts  | Signature      | Meaning                                                                      |
| ----- | ------------- | -------- | -------------- | ---------------------------------------------------------------------------- |
| sqrt  | orig          | `sqrt`   | `sqrt(x)`      | Positive square root.                                                        |
| ℯ     | orig          | `ℯ`      | constant       | Euler's number, ≈ 2.71828. Rendered as the script-e glyph (sentinel `0xEE`). |
| π     | orig          | `π`      | constant       | Pi, ≈ 3.14159. Rendered as the pi glyph (sentinel `0xEF`).                   |
| ^(    | orig          | `^(`     | `x^(y)`        | Power; opens a paren so the exponent is explicit, e.g. `2^(3)`.              |
| ln    | shift of ℯ    | `ln(`    | `ln(x)`        | Natural log (base `ℯ`).                                                      |
| log_b | shift of ^    | `log_b(` | `log_b(b, x)`  | Logarithm of `x` in base `b`. (user-chosen base), e.g. `log_b(2, 8)` → `3`.  |
| log   | shift of sqrt | `log(`   | `log(x)`       | Logarithm of `x` in base 10                                                  |
| :=    | orig (m key)  | `:=`     | `name := expr` | Variable assignment for later `solve`/`diff`/`int` use, e.g. `A := 2`.       |

---

## Implementation notes for evaluator work

- `insert()` in `main.zig` collapses UTF-8 `ℯ` (`E2 84 AF`) → `0xEE` and `π` (`CF 80`) → `0xEF`
  as single sentinel bytes; the evaluator must accept those as constants.
- Menu value strings end with `(` so typing continues inside the call;
  auto-closing the paren (cursor-aware) is future work.
- `nCr`/`nPr` need integer arguments; `normal`/`invnorm` need floating point.

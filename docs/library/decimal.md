---
description: The native decimal, fractions, statistics and numbers modules, as CPython's - exact decimal arithmetic with contexts and signals, rational numbers, statistics and the numeric tower - and where 64-bit ints make them differ.
keywords: decimal, decimal.Decimal, Decimal, decimal.Context, decimal.getcontext, decimal.setcontext, decimal.localcontext, decimal.DecimalTuple, decimal.ROUND_HALF_UP, decimal.ROUND_HALF_EVEN, decimal.InvalidOperation, decimal.DivisionByZero, decimal.Inexact, decimal.Rounded, decimal.IEEEContext, fractions, fractions.Fraction, Fraction, statistics, statistics.mean, statistics.fmean, statistics.median, statistics.mode, statistics.multimode, statistics.stdev, statistics.pstdev, statistics.variance, statistics.pvariance, statistics.quantiles, statistics.correlation, statistics.covariance, statistics.linear_regression, statistics.NormalDist, statistics.StatisticsError, statistics.kde, numbers.Number, numbers.Complex, numbers.Real, numbers.Rational, numbers.Integral
---
# decimal, fractions, statistics and numbers

These four modules are CPython's, written in Jac: `decimal`'s decimal floating point with
contexts, rounding modes and signals; `fractions.Fraction`; `statistics`, from `mean` to
`NormalDist` and `kde`; and `numbers`, the abstract classes of the numeric tower. Each has the
whole interface of CPython 3.15's module, and gives CPython's results. They are native (see
[The library](index.md), `jac docs library`).

```jac
import decimal;
import from decimal { Decimal, localcontext, ROUND_HALF_UP }

with entry {
    print(Decimal("1.1") + Decimal("2.2"), Decimal(1) / Decimal(7));
    print(Decimal(2).sqrt(), Decimal("1.005").quantize(Decimal("0.01"), rounding=ROUND_HALF_UP));
    with localcontext() as ctx {
        ctx.prec = 5;
        print(Decimal(1) / Decimal(3), Decimal("123456789").normalize());
    }
    print(Decimal(0.1));
    print(
        Decimal("-0"),
        Decimal("NaN").is_nan(),
        Decimal("1E+3").to_integral_value(),
        Decimal("2.50") == Decimal("2.5"),
    );
    print(decimal.getcontext().prec, Decimal("-3.14").as_tuple());
    try {
        Decimal(1) / Decimal(0);
    } except decimal.DivisionByZero as e {
        print(type(e).__name__);
    }
    try {
        Decimal("one");
    } except decimal.InvalidOperation as e {
        print(type(e).__name__);
    }
    print(Decimal("7.325").exp(), Decimal(10).ln(), Decimal(2) ** Decimal("0.5"));
}
```

```output
3.3 0.1428571428571428571428571429
1.414213562373095048801688724 1.01
0.33333 1.2346E+8
0.1000000000000000055511151231257827021181583404541015625
-0 True 1E+3 True
28 DecimalTuple(sign=1, digits=(3, 1, 4), exponent=-2)
DivisionByZero
InvalidOperation
1517.773898663651270177780543 2.302585092994045684017991455 1.414213562373095048801688724
```

## decimal

`Decimal` is exact at any precision: its coefficient is held as an arbitrary-precision number
inside the module, whatever the 64-bit `int` holds. Every operation of CPython's `Decimal` and
`Context` is there, with the eight rounding modes, the signals (`InvalidOperation`,
`DivisionByZero`, `Inexact`, `Rounded`, `Subnormal`, `Overflow`, `Underflow`, `Clamped`,
`FloatOperation`) and their traps and flags, `localcontext`, `DefaultContext`, `BasicContext`,
`ExtendedContext` and Python 3.14's `IEEEContext`. Results agree with CPython's `libmpdec`
digit for digit, on 10,500 random operations of every kind.

- **`int(d)` of a value past 64 bits raises `OverflowError`**, as every `int` result does;
  `str(d)` and `d.as_tuple()` give every digit.
- **Speed**: parsing and `str` are within CPython's; addition is about 2 times slower than
  CPython's C, division 6 times, and `sqrt`, `exp` and `ln` 8 to 10 times.

## fractions and statistics

```jac
import statistics;
import numbers;
import from fractions { Fraction }

with entry {
    print(Fraction(3, 4) + Fraction(1, 6), Fraction("0.125"), Fraction(1.5), Fraction(6, -4));
    print(
        Fraction(355, 113).limit_denominator(10), Fraction.from_float(0.1).limit_denominator(100)
    );
    print(Fraction(7, 2).as_integer_ratio(), float(Fraction(1, 8)), round(Fraction(5, 2)));
    print(
        statistics.mean([1, 2, 3, 4]),
        statistics.median([3, 1, 2]),
        statistics.mode(["a", "b", "a"]),
    );
    print(
        statistics.stdev([2, 4, 4, 4, 5, 5, 7, 9]),
        statistics.quantiles([1, 2, 3, 4, 5, 6, 7, 8], n=4),
    );
    print(statistics.fmean([1.5, 2.5]), statistics.correlation([1, 2, 3], [2, 4, 7]));
    nd = statistics.NormalDist(100, 15);
    print(round(nd.cdf(115), 4), nd.inv_cdf(0.5), nd);
    try {
        statistics.mean([]);
    } except statistics.StatisticsError as e {
        print("StatisticsError:", e);
    }
    print(isinstance(Fraction(1, 2), numbers.Rational), isinstance(1, numbers.Integral));
}
```

```output
11/12 1/8 3/2 -3/2
22/7 1/10
(7, 2) 0.125 2
2.5 2 a
2.138089935299395 [2.25, 4.5, 6.75]
2.0 0.9933992677987828
0.8413 100.0 NormalDist(mu=100.0, sigma=15.0)
StatisticsError: mean requires at least one data point
True False
```

- **A `Fraction`'s numerator and denominator are `int`s**, so a fraction whose terms pass 64
  bits raises `OverflowError`. `Fraction.from_decimal` and `Fraction(Decimal(...))` take a
  `Decimal`.
- **`statistics` sums exactly**, as CPython's does, with an arbitrary-precision helper inside
  the module, so `mean` and `variance` of floats give CPython's last digit.

## numbers

`numbers` declares `Number`, `Complex`, `Real`, `Rational` and `Integral` with CPython's
abstract methods and mixin methods. A program's class derives from the one it is and implements
the abstract methods; `Fraction` is a `Rational` and `Decimal` a `Number`.

- **The builtin types are not registered**: `isinstance(1, numbers.Integral)` and
  `isinstance(1.5, numbers.Real)` are `False`, where CPython registers `int`, `float` and
  `complex` with the tower. Test `isinstance(x, int)` and the other builtin types directly.

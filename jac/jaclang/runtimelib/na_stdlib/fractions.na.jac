def _gcd(a: int, b: int) -> int {
    x: int = a;
    if x < 0 {
        x = -x;
    }
    y: int = b;
    if y < 0 {
        y = -y;
    }
    while y != 0 {
        t: int = y;
        y = x % y;
        x = t;
    }
    return x;
}


obj:pub Fraction {
    has numerator: int = 0,
        denominator: int = 1;

    def init(numerator: int = 0, denominator: int = 1) {
        if denominator == 0 {
            raise ZeroDivisionError("Fraction(" + str(numerator) + ", 0)");
        }
        n: int = numerator;
        d: int = denominator;
        if d < 0 {
            n = -n;
            d = -d;
        }
        g: int = _gcd(n, d);
        self.numerator = n // g;
        self.denominator = d // g;
    }

    def __str__ -> str {
        if self.denominator == 1 {
            return str(self.numerator);
        }
        return str(self.numerator) + "/" + str(self.denominator);
    }

    def add(other: Fraction) -> Fraction {
        return Fraction(
            self.numerator * other.denominator + other.numerator * self.denominator,
            self.denominator * other.denominator
        );
    }

    def sub(other: Fraction) -> Fraction {
        return Fraction(
            self.numerator * other.denominator - other.numerator * self.denominator,
            self.denominator * other.denominator
        );
    }

    def mul(other: Fraction) -> Fraction {
        return Fraction(
            self.numerator * other.numerator, self.denominator * other.denominator
        );
    }

    def div(other: Fraction) -> Fraction {
        return Fraction(
            self.numerator * other.denominator, self.denominator * other.numerator
        );
    }

    def eq(other: Fraction) -> bool {
        return self.numerator == other.numerator
        and self.denominator == other.denominator;
    }

    def lt(other: Fraction) -> bool {
        return self.numerator * other.denominator < other.numerator * self.denominator;
    }
}

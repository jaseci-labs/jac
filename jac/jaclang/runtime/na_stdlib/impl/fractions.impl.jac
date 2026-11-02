impl Fraction.init(numerator: int = 0, denominator: int = 1) {
    if denominator == 0 {
        raise ZeroDivisionError("Fraction(" + str(numerator) + ", 0)");
    }
    n: int = numerator;
    d: int = denominator;
    if d < 0 {
        n = -n;
        d = -d;
    }
    g: int = gcd(n, d);
    self.numerator = n // g;
    self.denominator = d // g;
}

impl Fraction.__str__ -> str {
    if self.denominator == 1 {
        return str(self.numerator);
    }
    return str(self.numerator) + "/" + str(self.denominator);
}

impl Fraction.__add__(other: Fraction) -> Fraction {
    return Fraction(
        self.numerator * other.denominator + other.numerator * self.denominator,
        self.denominator * other.denominator
    );
}

impl Fraction.__sub__(other: Fraction) -> Fraction {
    return Fraction(
        self.numerator * other.denominator - other.numerator * self.denominator,
        self.denominator * other.denominator
    );
}

impl Fraction.__mul__(other: Fraction) -> Fraction {
    return Fraction(
        self.numerator * other.numerator, self.denominator * other.denominator
    );
}

impl Fraction.__truediv__(other: Fraction) -> Fraction {
    if other.numerator == 0 {
        raise ZeroDivisionError("Fraction(1, 0)");
    }
    return Fraction(
        self.numerator * other.denominator, self.denominator * other.numerator
    );
}

impl Fraction.__eq__(other: Fraction) -> bool {
    return self.numerator == other.numerator and self.denominator == other.denominator;
}

impl Fraction.__lt__(other: Fraction) -> bool {
    return self.numerator * other.denominator < other.numerator * self.denominator;
}

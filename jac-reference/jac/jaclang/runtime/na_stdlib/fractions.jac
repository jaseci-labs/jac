import from math { gcd }

obj:pub Fraction {
    has numerator: int = 0,
        denominator: int = 1;

    def init(numerator: int = 0, denominator: int = 1);
    def __str__ -> str;
    def __add__(other: Fraction) -> Fraction;
    def __sub__(other: Fraction) -> Fraction;
    def __mul__(other: Fraction) -> Fraction;
    def __truediv__(other: Fraction) -> Fraction;
    def __eq__(other: Fraction) -> bool;
    def __lt__(other: Fraction) -> bool;
}

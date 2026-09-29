import from _math_native { m_fma }

def:pub fmadd(a: float, b: float, c: float) -> float {
    return m_fma(a, b, c);
}

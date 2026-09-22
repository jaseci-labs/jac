import from m { def acos(x: f64) -> f64;  }
import from m { def acosh(x: f64) -> f64;  }
import from m { def asin(x: f64) -> f64;  }
import from m { def asinh(x: f64) -> f64;  }
import from m { def atan(x: f64) -> f64;  }
import from m { def atanh(x: f64) -> f64;  }
import from m { def atan2(y: f64, x: f64) -> f64;  }
import from m { def cbrt(x: f64) -> f64;  }
import from m { def ceil(x: f64) -> f64;  }
import from m { def copysign(x: f64, y: f64) -> f64;  }
import from m { def cos(x: f64) -> f64;  }
import from m { def cosh(x: f64) -> f64;  }
import from m { def erf(x: f64) -> f64;  }
import from m { def erfc(x: f64) -> f64;  }
import from m { def exp(x: f64) -> f64;  }
import from m { def exp2(x: f64) -> f64;  }
import from m { def expm1(x: f64) -> f64;  }
import from m { def fabs(x: f64) -> f64;  }
import from m { def floor(x: f64) -> f64;  }
import from m { def fma(x: f64, y: f64, z: f64) -> f64;  }
import from m { def fmod(x: f64, y: f64) -> f64;  }
import from m { def hypot(x: f64, y: f64) -> f64;  }
import from m { def lgamma(x: f64) -> f64;  }
import from m { def log(x: f64) -> f64;  }
import from m { def log2(x: f64) -> f64;  }
import from m { def log10(x: f64) -> f64;  }
import from m { def log1p(x: f64) -> f64;  }
import from m { def pow(x: f64, y: f64) -> f64;  }
import from m { def remainder(x: f64, y: f64) -> f64;  }
import from m { def sin(x: f64) -> f64;  }
import from m { def sinh(x: f64) -> f64;  }
import from m { def sqrt(x: f64) -> f64;  }
import from m { def tan(x: f64) -> f64;  }
import from m { def tanh(x: f64) -> f64;  }
import from m { def tgamma(x: f64) -> f64;  }
import from m { def trunc(x: f64) -> f64;  }


def:pub m_acos(x: float) -> float {
    return acos(f64(x));
}


def:pub m_acosh(x: float) -> float {
    return acosh(f64(x));
}


def:pub m_asin(x: float) -> float {
    return asin(f64(x));
}


def:pub m_asinh(x: float) -> float {
    return asinh(f64(x));
}


def:pub m_atan(x: float) -> float {
    return atan(f64(x));
}


def:pub m_atanh(x: float) -> float {
    return atanh(f64(x));
}


def:pub m_atan2(y: float, x: float) -> float {
    return atan2(f64(y), f64(x));
}


def:pub m_cbrt(x: float) -> float {
    return cbrt(f64(x));
}


def:pub m_ceil(x: float) -> float {
    return ceil(f64(x));
}


def:pub m_copysign(x: float, y: float) -> float {
    return copysign(f64(x), f64(y));
}


def:pub m_cos(x: float) -> float {
    return cos(f64(x));
}


def:pub m_cosh(x: float) -> float {
    return cosh(f64(x));
}


def:pub m_erf(x: float) -> float {
    return erf(f64(x));
}


def:pub m_erfc(x: float) -> float {
    return erfc(f64(x));
}


def:pub m_exp(x: float) -> float {
    return exp(f64(x));
}


def:pub m_exp2(x: float) -> float {
    return exp2(f64(x));
}


def:pub m_expm1(x: float) -> float {
    return expm1(f64(x));
}


def:pub m_fabs(x: float) -> float {
    return fabs(f64(x));
}


def:pub m_floor(x: float) -> float {
    return floor(f64(x));
}


def:pub m_fma(x: float, y: float, z: float) -> float {
    return fma(f64(x), f64(y), f64(z));
}


def:pub m_fmod(x: float, y: float) -> float {
    return fmod(f64(x), f64(y));
}


def:pub m_hypot(x: float, y: float) -> float {
    return hypot(f64(x), f64(y));
}

def:pub m_lgamma(x: float) -> float {
    return lgamma(f64(x));
}


def:pub m_log(x: float) -> float {
    return log(f64(x));
}


def:pub m_log2(x: float) -> float {
    return log2(f64(x));
}


def:pub m_log10(x: float) -> float {
    return log10(f64(x));
}


def:pub m_log1p(x: float) -> float {
    return log1p(f64(x));
}


def:pub m_pow(x: float, y: float) -> float {
    return pow(f64(x), f64(y));
}


def:pub m_remainder(x: float, y: float) -> float {
    return remainder(f64(x), f64(y));
}


def:pub m_sin(x: float) -> float {
    return sin(f64(x));
}


def:pub m_sinh(x: float) -> float {
    return sinh(f64(x));
}


def:pub m_sqrt(x: float) -> float {
    return sqrt(f64(x));
}


def:pub m_tan(x: float) -> float {
    return tan(f64(x));
}


def:pub m_tanh(x: float) -> float {
    return tanh(f64(x));
}


def:pub m_tgamma(x: float) -> float {
    return tgamma(f64(x));
}


def:pub m_trunc(x: float) -> float {
    return trunc(f64(x));
}

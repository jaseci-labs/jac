"""Inverse normal cumulative distribution for the statistics module.

CPython supplies the Python values and their float conversion. The rational
approximation evaluates natively over machine doubles.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""
import from jaclang.runtime.python.capi {
    jacpy_float,
    jacpy_number_as_double,
    jacpy_error_pending,
    object_error
}
import from jaclang.runtime.python.modules.numeric { fabs, log, sqrt }

# Wichura, M.J. (1988). "Algorithm AS241: The Percentage Points of the Normal
# Distribution". Applied Statistics 37 (3): 477-484. Each branch below is one
# ratio of two degree-seven polynomials in a branch-specific variable.
glob:priv central_numerator = [
         2.5090809287301226727e+3,
         3.3430575583588128105e+4,
         6.7265770927008700853e+4,
         4.5921953931549871457e+4,
         1.3731693765509461125e+4,
         1.9715909503065514427e+3,
         1.3314166789178437745e+2,
         3.3871328727963666080e+0
     ],
     central_denominator = [
         5.2264952788528545610e+3,
         2.8729085735721942674e+4,
         3.9307895800092710610e+4,
         2.1213794301586595867e+4,
         5.3941960214247511077e+3,
         6.8718700749205790830e+2,
         4.2313330701600911252e+1,
         1.0
     ],
     near_numerator = [
         7.74545014278341407640e-4,
         2.27238449892691845833e-2,
         2.41780725177450611770e-1,
         1.27045825245236838258e+0,
         3.64784832476320460504e+0,
         5.76949722146069140550e+0,
         4.63033784615654529590e+0,
         1.42343711074968357734e+0
     ],
     near_denominator = [
         1.05075007164441684324e-9,
         5.47593808499534494600e-4,
         1.51986665636164571966e-2,
         1.48103976427480074590e-1,
         6.89767334985100004550e-1,
         1.67638483018380384940e+0,
         2.05319162663775882187e+0,
         1.0
     ],
     tail_numerator = [
         2.01033439929228813265e-7,
         2.71155556874348757815e-5,
         1.24266094738807843860e-3,
         2.65321895265761230930e-2,
         2.96560571828504891230e-1,
         1.78482653991729133580e+0,
         5.46378491116411436990e+0,
         6.65790464350110377720e+0
     ],
     tail_denominator = [
         2.04426310338993978564e-15,
         1.42151175831644588870e-7,
         1.84631831751005468180e-5,
         7.86869131145613259100e-4,
         1.48753612908506148525e-2,
         1.36929880922735805310e-1,
         5.99832206555887937690e-1,
         1.0
     ];

# Horner's method, highest-order coefficient first. The multiply-add order
# matches the reference implementation's nested expression exactly.
def:priv polynomial(coefficients: list[float], value: float) -> float {
    total = coefficients[0];
    for index in range(1, len(coefficients)) {
        total = total * value + coefficients[index];
    }
    return total;
}

def:priv undefined -> u64 {
    object_error("ValueError", "inv_cdf undefined for these parameters");
    return 0;
}

# PyFloat_AsDouble, reporting a failed conversion as None rather than the
# -1.0 the C API overloads for it.
def:priv input_float(value: u64) -> (float | None) {
    result = jacpy_number_as_double(value);
    if jacpy_error_pending() != 0 {
        return None;
    }
    return result;
}

# Every comparison keeps the reference implementation's orientation so that a
# NaN probability falls through to the tail branch and yields NaN instead of
# raising.
def:pub jacpy_statistics_inv_cdf(probability: u64, mean: u64, deviation: u64) -> u64 {
    p = input_float(probability);
    if p is None {
        return 0;
    }
    mu = input_float(mean);
    if mu is None {
        return 0;
    }
    sigma = input_float(deviation);
    if sigma is None {
        return 0;
    }
    if p <= 0.0 or p >= 1.0 {
        return undefined();
    }
    q = p - 0.5;
    r: float = 0.0;
    den: float = 0.0;
    x: float = 0.0;
    if fabs(q) <= 0.425 {
        r = 0.180625 - q * q;
        den = polynomial(central_denominator, r);
        if den == 0.0 {
            return undefined();
        }
        x = polynomial(central_numerator, r) * q / den;
        return jacpy_float(mu + x * sigma);
    }
    r = p if q <= 0.0 else 1.0 - p;
    if r <= 0.0 or r >= 1.0 {
        return undefined();
    }
    r = sqrt(-log(r));
    if r <= 5.0 {
        r -= 1.6;
        den = polynomial(near_denominator, r);
        if den == 0.0 {
            return undefined();
        }
        x = polynomial(near_numerator, r) / den;
    } else {
        r -= 5.0;
        den = polynomial(tail_denominator, r);
        if den == 0.0 {
            return undefined();
        }
        x = polynomial(tail_numerator, r) / den;
    }
    if q < 0.0 {
        x = -x;
    }
    return jacpy_float(mu + x * sigma);
}

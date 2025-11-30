import from scipy { stats, optimize }
import from utils.fake_helpers { helper_func }
import from non_existent_module { foo }
import nonexistent_module as nm;

with entry {
    a: int = stats.norm.cdf(0);
    d: float = optimize.minimize_scalar(lambda  x: int: x ** 2).fun;
    result = helper_func();
    b: int = foo();
    c = nm.some_func();
}

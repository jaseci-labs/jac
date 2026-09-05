"""Fixture main: pulls one function through a native cross-module import."""

import from memrelease_dep { mr_scale }

def mr_use(n: int) -> int {
    return mr_scale(n) + 1;
}

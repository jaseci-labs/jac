"""Stdlib functions imported by bare name must lower natively.

The native stdlib intercepts recognise only the `module.func(...)` shape, so
`from os import getcwd` left `getcwd()` invisible to them: the call demoted
with E5092 and took its whole caller -- and transitively the module -- to the
server lane over nothing but an import style.
"""

import from os { getcwd, getpid }
import from os.path { basename, join as path_join }
import from random { randint, seed }
import from struct { calcsize }

def cwd_nonempty -> bool {
    return len(getcwd()) > 0;
}

def pid_positive -> bool {
    return getpid() > 0;
}

def base_of(p: str) -> str {
    return basename(p);
}

def joined(a: str, b: str) -> str {
    return path_join(a, b);
}

def rolled -> int {
    seed(7);
    return randint(1, 6);
}

def q_size -> int {
    return calcsize("q");
}

with entry {
    print(cwd_nonempty(), pid_positive(), base_of("/a/b.txt"), joined("a", "b"));
    print(rolled() >= 1, q_size());
}

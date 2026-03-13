"""Fixture for W2031: Unused import."""

import from os { path }           # <-- Warning W2031: unused import 'path'
import from os { getcwd }

with entry {
    print(getcwd());  # <-- Ok: getcwd is used
}

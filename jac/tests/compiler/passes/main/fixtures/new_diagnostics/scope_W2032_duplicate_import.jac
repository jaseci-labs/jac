"""Fixture for W2032: Duplicate import."""

import from os { getcwd }
import from os { getcwd }  # <-- Warning W2032: duplicate import of 'getcwd'

with entry {
    print(getcwd());
}

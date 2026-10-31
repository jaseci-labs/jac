"""Imports a name that only the source module's `__getattr__` provides."""

import from lazy_import_lib { lazy_value }

glob as_int: int = lazy_value,
     as_str: str = lazy_value;

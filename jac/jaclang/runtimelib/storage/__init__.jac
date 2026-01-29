"""Core Storage Abstraction for Jac.

This module provides a pluggable storage interface that can be overridden
by plugins (like jac-scale) to provide cloud storage backends.
"""

import from jaclang.runtimelib.storage.storage { Storage }
import from jaclang.runtimelib.storage.local_storage { LocalStorage }

glob __all__ = ["Storage", "LocalStorage"];

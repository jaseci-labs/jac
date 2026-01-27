"""Core Storage Abstraction for Jac.

This module provides a pluggable storage interface that can be overridden
"""

import from jaclang.runtimelib.storage.storage { Storage }
import from jaclang.runtimelib.storage.local_storage { LocalStorage }
import from jaclang.runtimelib.storage.config { BaseStorageConfig, LocalStorageConfig }

glob __all__ = [
         'Storage',
         'LocalStorage',
         'BaseStorageConfig',
         'LocalStorageConfig'
     ];

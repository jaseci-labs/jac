"""A native module the backend has nothing to lower from.

An AOT build of this module cannot produce a binary, so the compile must say
so with a diagnostic instead of handing the caller an empty artifact.
"""

"""Process-lifecycle coordination for the jac-scale runtime.

Connection draining, signal handling, and cross-replica leader election - the
concerns that govern how a serving process starts, sheds load, and coordinates
with its peers. Leader election is backed by the StateBackend port, so it is a
no-op singleton locally and real cross-pod coordination under --scale.
"""

"""Eject output targets (backend / frontend / fullstack) for `jac eject`.

Each module here implements one value of `[eject].target` in jac.toml. The
default (no `[eject]` section) keeps the original jaclang-coupled Python+JS
eject; any target value produces standalone, zero-jaclang output.
"""

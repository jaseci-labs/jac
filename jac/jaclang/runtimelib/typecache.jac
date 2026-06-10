"""Cached dataclass field-type introspection.

Provides `get_field_types(cls)` which resolves and caches the
{field_name: resolved_annotation} map for dataclasses. The cache avoids
repeated `typing.get_type_hints` calls which are extremely expensive
(~350 us per call) and dominate deserialization cost when processing
many anchors of the same class.
"""

"""Return a {field_name: resolved_annotation} map for a dataclass.

Uses typing.get_type_hints for forward-ref resolution, falling back to
raw __annotations__ if hints resolution fails (e.g. circular imports).
Non-dataclass classes return empty. Results are cached per class.
"""
def get_field_types(cls: type) -> dict[str, object];

"""Invalidate the cache entry for a single class (e.g. after HMR reload)."""
def invalidate(cls: type) -> None;

"""Clear the entire field-types cache."""
def clear -> None;

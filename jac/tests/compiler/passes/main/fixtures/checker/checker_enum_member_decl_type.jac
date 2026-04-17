"""Fixture for enum member declaration type resolution.

Enum member declaration sites (the Name nodes inside the enum body) should
resolve to EnumMemberType, not to the enum's ClassType. This ensures hover
info, W1051 coverage, and assign-compatibility checks all see the correct
per-member type.
"""

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, OTHER }

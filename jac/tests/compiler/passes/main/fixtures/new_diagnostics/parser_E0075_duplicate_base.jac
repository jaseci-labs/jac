"""Fixture for E0075: Duplicate base class in archetype definition."""

obj Base { }

obj Good(Base) { }  # <-- Ok

obj Bad(Base, Base) { }  # <-- Error E0075: duplicate base class

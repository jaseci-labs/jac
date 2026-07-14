"""A property whose accessor bodies live in a separate impl file.

The decorated declarations must collapse into a native accessor block, and the
matching impl definitions must be re-targeted to dotted-impl form.
"""

obj Temperature {
    has _celsius: float = 0.0;

    @property
    def celsius -> float;

    @celsius.setter
    def celsius(value: float);
}

# Regression: super.init(...) on a parent whose init is dataclass-synthesized
# from `has` vars was emitting a spurious W1051 ("Expression type could not be
# resolved (Unknown)") because the synthesized FunctionType returned by
# _create_dataclass_init_method had return_type=UnknownType. Arg validation
# worked, but the call expression itself typed as Unknown.
#
# An implicit __init__ returns None in Python; the synthesized init must
# reflect that so super.init(...) calls type cleanly.

# Single-level inheritance: parent has only `has` fields (synthesized init).
obj Shape {
    has shape_type: str;
}

obj Circle(Shape) {
    has radius: float;

    def init(radius: float) {
        super.init("Circle");
        self.radius = radius;
    }
}

# Two-level inheritance: middle and root both rely on synthesized inits.
obj ColoredShape(Shape) {
    has color: str;
}

obj ColoredCircle(ColoredShape) {
    has radius: float;

    def init(radius: float, color: str) {
        super.init("ColoredCircle", color);
        self.radius = radius;
    }
}

# The result of super.init(...) must type as None so it can be assigned to a
# None-annotated variable without E1001.
obj Box(Shape) {
    has w: float;

    def init(w: float) {
        result: None = super.init("Box");
        self.w = w;
    }
}

# Test super.init() with has variables (implicit dataclass init)

# Base class with has var
obj Shape {
    has shape_type: str;
}

# Valid: Child class calling parent's implicit init
obj Circle(Shape) {
    has radius: float;

    def init(radius: float) {
        super.init("Circle");
        self.radius = radius;
    }
}

# Multi-level inheritance with has vars
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

# ERROR: Wrong type - passing int instead of str
obj BadCircle1(Shape) {
    has radius: float;
    def init(radius: float) {
        super.init(123);  # ERROR
        self.radius = radius;
    }
}

# ERROR: Too many arguments
obj BadCircle2(Shape) {
    has radius: float;
    def init(radius: float) {
        super.init("Circle", "extra_arg");  # ERROR
        self.radius = radius;
    }
}

# ERROR: Missing required argument
obj BadCircle3(Shape) {
    has radius: float;
    def init(radius: float) {
        super.init();  # ERROR
        self.radius = radius;
    }
}

# Match class patterns - Pattern matching in match statements

obj Point {
    has x: float,
        y: float;
}

obj Circle {
    has center: Point,
        radius: float;
}

with entry {
    # Class pattern with positional and keyword matching
    data = Point(x=9, y=0);
    match data {
        case Point(int(a), y = 0):
            print(f"Point on x-axis with x={a}");
        case _:
            print("Point not on axis");
    }

    # Class pattern with keyword argument extraction
    p1 = Point(x=5.0, y=10.0);
    match p1 {
        case Point(x=x_val, y=y_val):
            print(f"Point at ({x_val}, {y_val})");
    }

    # Class pattern checking specific values
    p2 = Point(x=0.0, y=0.0);
    match p2 {
        case Point(x=0.0, y=0.0):
            print("Point at origin");
        case Point(x=0.0, y=y):
            print(f"Point on y-axis at y={y}");
        case _:
            print("Point elsewhere");
    }

    # Nested class pattern
    c = Circle(center=Point(x=3.0, y=4.0), radius=5.0);
    match c {
        case Circle(center=Point(x=cx, y=cy), radius=r):
            print(f"Circle at ({cx}, {cy}) with radius {r}");
    }
}

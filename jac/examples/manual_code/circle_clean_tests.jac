import circle_clean;

glob expected_area = 78.53981633974483;

test { assert almostEqual(calculate_area(RAD), expected_area); }

test { c = Circle(RAD); assert almostEqual(c.area(), expected_area); }

test { c = Circle(RAD); assert c.shape_type == ShapeType.CIRCLE; }

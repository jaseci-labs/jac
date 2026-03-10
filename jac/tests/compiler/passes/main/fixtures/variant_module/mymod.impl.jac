impl Circle.area -> float {
    return 3.14159 * self.radius * self.radius;
}

impl Display.render -> str {
    return "Displaying: " + self.label;
}

# Test 1: Basic two-parent inheritance
obj Flyable {
    has altitude: int = 0;

    def fly() -> int {
        return self.altitude;
    }
}

obj Swimmable {
    has depth: int = 0;

    def swim() -> int {
        return self.depth;
    }
}

obj Duck(Flyable, Swimmable) {
    has name_id: int = 0;

    def quack() -> int {
        return 42;
    }
}

# Test 2: Diamond pattern
obj Base {
    has id: int = 0;

    def get_id() -> int {
        return self.id;
    }
}

obj Left(Base) {
    has left_val: int = 10;

    def get_left() -> int {
        return self.left_val;
    }
}

obj Right(Base) {
    has right_val: int = 20;

    def get_right() -> int {
        return self.right_val;
    }
}

obj Diamond(Left, Right) {
    has diamond_val: int = 99;
}

# Test 3: MRO method resolution
obj A4 {
    def method() -> int {
        return 1;
    }
}

obj B4(A4) {
    def method() -> int {
        return 2;
    }
}

obj C4(A4) {
    def method() -> int {
        return 3;
    }
}

obj D4(B4, C4) {
}

# Test 4: Three mixins
obj Printable {
    has print_id: int = 0;

    def get_pid() -> int {
        return self.print_id;
    }
}

obj Serializable {
    has ser_id: int = 0;

    def get_sid() -> int {
        return self.ser_id;
    }
}

obj Loggable {
    has log_id: int = 0;

    def get_lid() -> int {
        return self.log_id;
    }
}

obj Service(Printable, Serializable, Loggable) {
    has svc_id: int = 0;
}

# --- Test functions ---

def test_two_parent_fields() -> int {
    d: Duck = Duck(altitude=100, depth=50, name_id=1);
    return d.altitude + d.depth + d.name_id;
}

def test_two_parent_methods() -> int {
    d: Duck = Duck(altitude=100, depth=50, name_id=1);
    return d.fly() + d.swim() + d.quack();
}

def test_diamond_field_access() -> int {
    d: Diamond = Diamond(id=1, left_val=10, right_val=20, diamond_val=99);
    return d.get_id() + d.get_left() + d.get_right() + d.diamond_val;
}

def test_diamond_single_id() -> int {
    d: Diamond = Diamond(id=42, left_val=0, right_val=0, diamond_val=0);
    return d.get_id();
}

def test_mro_method_resolution() -> int {
    d: D4 = D4();
    return d.method();
}

def test_three_mixins() -> int {
    s: Service = Service(print_id=1, ser_id=2, log_id=3, svc_id=4);
    return s.get_pid() + s.get_sid() + s.get_lid() + s.svc_id;
}

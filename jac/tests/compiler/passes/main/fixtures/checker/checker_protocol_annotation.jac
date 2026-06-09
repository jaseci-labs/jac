"""Protocol annotation support with structural typing.

Tests Protocol classes used as type annotations, ensuring structural typing
and isinstance checking work correctly (especially with @runtime_checkable).
"""
import from typing { Protocol, runtime_checkable }

# Basic protocol
obj Drawable {
    @runtime_checkable
    def draw() -> None;
}

# Protocol with methods
@runtime_checkable
obj Sized {
    def __len__() -> int;
}

# Protocol with multiple methods
@runtime_checkable
obj Comparable {
    def __lt__(other: 'Comparable') -> bool;
    def __eq__(other: object) -> bool;
}

# Concrete implementation
obj Circle {
    has radius: float;

    def draw() -> None {
        print(f"Drawing circle with radius {self.radius}");
        return;
    }
}

obj Rectangle {
    has width: float;
    has height: float;

    def draw() -> None {
        print(f"Drawing rectangle {self.width}x{self.height}");
        return;
    }

    def __len__() -> int {
        return int(self.width * self.height);
    }
}

obj Person {
    has name: str;
    has age: int;

    def __lt__(other: 'Person') -> bool {
        return self.age < other.age;
    }

    def __eq__(other: object) -> bool {
        if isinstance(other, Person) {
            return self.name == other.name;
        }
        return False;
    }
}

# --- Valid: Protocol parameter acceptance ---
def draw_shape(shape: Drawable) -> None {
    shape.draw();
    return;
}

def get_size(container: Sized) -> int {
    return len(container);
}

def compare_items[T: Comparable](a: T, b: T) -> bool {
    return a < b;
}

def ok_protocol_call() -> None {
    c = Circle(radius=5.0);
    draw_shape(c);
    return;
}

def ok_protocol_method() -> int {
    r = Rectangle(width=10.0, height=20.0);
    return get_size(r);
}

def ok_protocol_generic() -> bool {
    p1 = Person(name="Alice", age=25);
    p2 = Person(name="Bob", age=30);
    return compare_items(p1, p2);
}

# --- Valid: isinstance with runtime_checkable ---
def ok_isinstance_check(obj: object) -> bool {
    return isinstance(obj, Drawable);
}

def ok_isinstance_sized(obj: object) -> bool {
    if isinstance(obj, Sized) {
        return True;
    }
    return False;
}

# --- Valid: Protocol assignment ---
def ok_assign_to_protocol() -> Drawable {
    c = Circle(radius=3.0);
    shape: Drawable = c;
    return shape;
}

# --- Invalid: Missing required method ---
def bad_incomplete_implementation() -> None {
    obj BadDrawable {
        # Missing draw() method - violates Drawable protocol
        def other_method() -> None { return; }
    }
    
    b = BadDrawable();
    draw_shape(b);  # Should fail: doesn't implement Drawable
    return;
}

# --- Invalid: Wrong method signature ---
def bad_wrong_signature() -> None {
    obj WrongDrawable {
        def draw(x: int) -> None {  # Wrong signature
            return;
        }
    }
    
    w = WrongDrawable();
    draw_shape(w);  # Should fail: draw() signature doesn't match
    return;
}

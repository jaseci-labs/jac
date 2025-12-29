"""Match statements: Pattern matching with all pattern types."""

# Define classes for class pattern examples
obj Point {
    has x: float,
        y: float;
}

obj Circle {
    has center: Point,
        radius: float;
}

obj Rectangle {
    has width: float,
        height: float;
}

# ========================================
# LITERAL PATTERNS
# ========================================

# Integer literal patterns
glob status_code = 200;

with entry {
    match status_code {
        case 200:
            print("OK");

        case 404:
            print("Not Found");

        case 500:
            print("Server Error");

        case _:
            print("Other status");

    }
}

# Float literal patterns
glob pi = 3.14;

with entry {
    match pi {
        case 3.14:
            print("Matched pi");

        case 2.71:
            print("Matched e");

        case _:
            print("Other number");

    }
}

# String literal patterns
glob command = "start";

with entry {
    match command {
        case "start":
            print("Starting");

        case "stop":
            print("Stopping");

        case "pause":
            print("Pausing");

        case _:
            print("Unknown command");

    }
}

# ========================================
# SINGLETON PATTERNS
# ========================================

# Boolean singleton patterns
glob flag = True;

with entry {
    match flag {
        case True:
            print("Flag is True");

        case False:
            print("Flag is False");

    }
}

# None singleton pattern
glob optional_value = None;

with entry {
    match optional_value {
        case None:
            print("Value is None");

        case _:
            print("Value exists");

    }
}

# ========================================
# CAPTURE PATTERNS
# ========================================

# Basic capture pattern - binds to variable
glob value = 42;

with entry {
    match value {
        case x:
            print(f"Captured value: {x}");

    }
}

# Wildcard pattern (_) - matches anything without binding
glob day = "sunday";

with entry {
    match day {
        case "monday":
            print("It's Monday");

        case _:
            print("Not Monday");

    }
}

# AS pattern - capture with explicit naming
glob number = 100;

with entry {
    match number {
        case x as captured_num:
            print(f"Captured as: {captured_num}");

    }
}

# ========================================
# SEQUENCE PATTERNS
# ========================================

# Exact sequence match with list
glob coords = [1, 2, 3];

with entry {
    match coords {
        case [ 1 , 2 , 3 ]:
            print("Matched exact sequence");

        case _:
            print("Different sequence");

    }
}

# Sequence with variable binding
glob point = [10, 20];

with entry {
    match point {
        case [ x , y ]:
            print(f"Point at ({x}, {y})");

    }
}

# Star pattern (*) - captures remaining elements
glob numbers = [1, 2, 3, 4, 5];

with entry {
    match numbers {
        case [ first , * middle , last ]:
            print(f"First: {first}, middle: {middle}, last: {last}");

        case [ * all_items ]:
            print(f"All items: {all_items}");

    }
}

# Star at different positions
glob data = [100, 200, 300, 400];

with entry {
    match data {
        case [ * start , 400 ]:
            print(f"Ends with 400, start: {start}");

        case [ 100 , * rest ]:
            print(f"Starts with 100, rest: {rest}");

    }
}

# Nested sequence patterns
glob matrix = [[1, 2], [3, 4]];

with entry {
    match matrix {
        case [ [ a , b ] , [ c , d ] ]:
            print(f"2x2 matrix: [{a},{b}], [{c},{d}]");

    }
}

# ========================================
# MAPPING PATTERNS
# ========================================

# Basic mapping pattern with exact keys
glob user = {"name": "Alice", "age": 30};

with entry {
    match user {
        case { "name" : "Alice" , "age" : 30 }:
            print("Matched exact user");

        case _:
            print("Different user");

    }
}

# Mapping with value capture
glob person = {"id": 123, "role": "admin"};

with entry {
    match person {
        case { "id" : user_id , "role" : user_role }:
            print(f"User {user_id} is {user_role}");

    }
}

# Double-star pattern (**) - captures remaining key-value pairs
glob config = {
         "host": "localhost",
         "port": 8080,
         "debug": True,
         "timeout": 30
     };

with entry {
    match config {
        case { "host" : h , "port" : p , ** rest }:
            print(f"Server: {h}:{p}, other settings: {rest}");

    }
}

# Nested mapping patterns
glob response = {
         "status": 200,
         "data": {"name": "Bob", "score": 95}
     };

with entry {
    match response {
        case { "status" : 200 , "data" : { "name" : n , "score" : s } }:
            print(f"Success: {n} scored {s}");

    }
}

# ========================================
# CLASS PATTERNS
# ========================================

# Basic class pattern with keyword arguments
glob p1 = Point(x=5.0, y=10.0);

with entry {
    match p1 {
        case Point(x = x_val, y = y_val):
            print(f"Point at ({x_val}, {y_val})");

    }
}

# Class pattern with specific value matching
glob origin = Point(x=0.0, y=0.0);

with entry {
    match origin {
        case Point(x = 0.0, y = 0.0):
            print("Point at origin");

        case Point(x = 0.0, y = y):
            print(f"On y-axis at {y}");

        case Point(x = x, y = 0.0):
            print(f"On x-axis at {x}");

        case _:
            print("Point elsewhere");

    }
}

# Nested class patterns
glob circle = Circle(
         center=Point(x=3.0, y=4.0), radius=5.0
     );

with entry {
    match circle {
        case Circle(center = Point(x = cx, y = cy), radius = r):
            print(f"Circle at ({cx}, {cy}) with radius {r}");

    }
}

# Class pattern with AS capture
glob rect = Rectangle(width=10.0, height=20.0);

with entry {
    match rect {
        case Rectangle(width = w, height = h) as captured_rect:
            print(f"Rectangle {w}x{h}, object: {captured_rect}");

    }
}

# ========================================
# OR PATTERNS
# ========================================

# Multiple alternative patterns with | (or)
glob code = 404;

with entry {
    match code {
        case 200 | 201 | 204:
            print("Success status");

        case 400 | 401 | 403 | 404:
            print("Client error");

        case 500 | 502 | 503:
            print("Server error");

        case _:
            print("Other code");

    }
}

# ========================================
# GUARD CLAUSES (if conditions)
# ========================================

# Pattern with guard condition
glob age = 25;

with entry {
    match age {
        case x if x < 18:
            print("Minor");

        case x if x < 65:
            print("Adult");

        case x:
            print("Senior");

    }
}

# Complex guard with multiple conditions
glob score = 85;

with entry {
    match score {
        case s if s >= 90:
            print("Grade: A");

        case s if s >= 80:
            print("Grade: B");

        case s if s >= 70:
            print("Grade: C");

        case s if s >= 60:
            print("Grade: D");

        case _:
            print("Grade: F");

    }
}

# ========================================
# COMBINED PATTERNS
# ========================================

# Combining different pattern types
glob shape_data = {
         "type": "circle",
         "center": [0, 0],
         "radius": 10
     };

with entry {
    match shape_data {
        case { "type" : "circle" , "center" : [ x , y ] , "radius" : r }:
            print(f"Circle at ({x},{y}) r={r}");

        case { "type" : "rectangle" , "corners" : [ [ x1 , y1 ] , [ x2 , y2 ] ] }:
            print(f"Rectangle from ({x1},{y1}) to ({x2},{y2})");

        case _:
            print("Unknown shape");

    }
}

# Multiple statements in case block
glob result = "success";

with entry {
    match result {
        case "success":
            print("Operation succeeded");
            status_val = 200;
            print(f"Status code: {status_val}");

        case "error":
            print("Operation failed");
            status_val = 500;
            print(f"Status code: {status_val}");

        case _:
            print("Unknown result");
            status_val = 0;

    }

    print("Match patterns demonstration complete");
}

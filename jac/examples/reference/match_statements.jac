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

with entry {
    # ========================================
    # LITERAL PATTERNS
    # ========================================

    # Integer literal patterns
    status_code = 200;
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

    # Float literal patterns
    pi = 3.14;
    match pi {
        case 3.14:
            print("Matched pi");

        case 2.71:
            print("Matched e");

        case _:
            print("Other number");

    }

    # String literal patterns
    command = "start";
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

    # ========================================
    # SINGLETON PATTERNS
    # ========================================

    # Boolean singleton patterns
    flag = True;
    match flag {
        case True:
            print("Flag is True");

        case False:
            print("Flag is False");

    }

    # None singleton pattern
    optional_value = None;
    match optional_value {
        case None:
            print("Value is None");

        case _:
            print("Value exists");

    }

    # ========================================
    # CAPTURE PATTERNS
    # ========================================

    # Basic capture pattern - binds to variable
    value = 42;
    match value {
        case x:
            print(f"Captured value: {x}");

    }

    # Wildcard pattern (_) - matches anything without binding
    day = "sunday";
    match day {
        case "monday":
            print("It's Monday");

        case _:
            print("Not Monday");

    }

    # AS pattern - capture with explicit naming
    number = 100;
    match number {
        case x as captured_num:
            print(f"Captured as: {captured_num}");

    }

    # ========================================
    # SEQUENCE PATTERNS
    # ========================================

    # Exact sequence match with list
    coords = [1, 2, 3];
    match coords {
        case [ 1 , 2 , 3 ]:
            print("Matched exact sequence");

        case _:
            print("Different sequence");

    }

    # Sequence with variable binding
    point = [10, 20];
    match point {
        case [ x , y ]:
            print(f"Point at ({x}, {y})");

    }

    # Star pattern (*) - captures remaining elements
    numbers = [1, 2, 3, 4, 5];
    match numbers {
        case [ first , * middle , last ]:
            print(f"First: {first}, middle: {middle}, last: {last}");

        case [ * all_items ]:
            print(f"All items: {all_items}");

    }

    # Star at different positions
    data = [100, 200, 300, 400];
    match data {
        case [ * start , 400 ]:
            print(f"Ends with 400, start: {start}");

        case [ 100 , * rest ]:
            print(f"Starts with 100, rest: {rest}");

    }

    # Nested sequence patterns
    matrix = [[1, 2], [3, 4]];
    match matrix {
        case [ [ a , b ] , [ c , d ] ]:
            print(f"2x2 matrix: [{a},{b}], [{c},{d}]");

    }

    # ========================================
    # MAPPING PATTERNS
    # ========================================

    # Basic mapping pattern with exact keys
    user = {"name": "Alice", "age": 30};
    match user {
        case { "name" : "Alice" , "age" : 30 }:
            print("Matched exact user");

        case _:
            print("Different user");

    }

    # Mapping with value capture
    person = {"id": 123, "role": "admin"};
    match person {
        case { "id" : user_id , "role" : user_role }:
            print(f"User {user_id} is {user_role}");

    }

    # Double-star pattern (**) - captures remaining key-value pairs
    config = {"host": "localhost", "port": 8080, "debug": True, "timeout": 30};
    match config {
        case { "host" : h , "port" : p , ** rest }:
            print(f"Server: {h}:{p}, other settings: {rest}");

    }

    # Nested mapping patterns
    response = {"status": 200, "data": {"name": "Bob", "score": 95}};
    match response {
        case { "status" : 200 , "data" : { "name" : n , "score" : s } }:
            print(f"Success: {n} scored {s}");

    }

    # ========================================
    # CLASS PATTERNS
    # ========================================

    # Basic class pattern with keyword arguments
    p1 = Point(x=5.0, y=10.0);
    match p1 {
        case Point(x = x_val, y = y_val):
            print(f"Point at ({x_val}, {y_val})");

    }

    # Class pattern with specific value matching
    origin = Point(x=0.0, y=0.0);
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

    # Nested class patterns
    circle = Circle(center=Point(x=3.0, y=4.0), radius=5.0);
    match circle {
        case Circle(center = Point(x = cx, y = cy), radius = r):
            print(f"Circle at ({cx}, {cy}) with radius {r}");

    }

    # Class pattern with AS capture
    rect = Rectangle(width=10.0, height=20.0);
    match rect {
        case Rectangle(width = w, height = h) as captured_rect:
            print(f"Rectangle {w}x{h}, object: {captured_rect}");

    }

    # ========================================
    # OR PATTERNS
    # ========================================

    # Multiple alternative patterns with | (or)
    code = 404;
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

    # ========================================
    # GUARD CLAUSES (if conditions)
    # ========================================

    # Pattern with guard condition
    age = 25;
    match age {
        case x if x < 18:
            print("Minor");

        case x if x < 65:
            print("Adult");

        case x:
            print("Senior");

    }

    # Complex guard with multiple conditions
    score = 85;
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

    # ========================================
    # COMBINED PATTERNS
    # ========================================

    # Combining different pattern types
    shape_data = {"type": "circle", "center": [0, 0], "radius": 10};
    match shape_data {
        case { "type" : "circle" , "center" : [ x , y ] , "radius" : r }:
            print(f"Circle at ({x},{y}) r={r}");

        case { "type" : "rectangle" , "corners" : [ [ x1 , y1 ] , [ x2 , y2 ] ] }:
            print(f"Rectangle from ({x1},{y1}) to ({x2},{y2})");

        case _:
            print("Unknown shape");

    }

    # Multiple statements in case block
    result = "success";
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

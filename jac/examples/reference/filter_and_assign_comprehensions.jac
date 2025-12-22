"""Filter and assign comprehensions: Filter and assign comprehension syntax."""

import random;

# ===== Object Definitions =====
obj TestObj {
    has x: int = 0,
        y: int = 0,
        z: int = 0;
}

obj Person {
    has name: str,
        age: int = 0,
        score: int = 0;
}

# ===== Node and Edge Definitions for Spatial Comprehensions =====
node Employee {
    has name: str,
        salary: int = 0,
        department: str = "Unknown";
}

edge ReportsTo {
    has years: int = 0;
}

edge Collaborates {
    has project: str = "None";
}

# ===== Walker for Demonstrating Edge Comprehensions =====
walker ComprehensionDemo {
    can demo_basic with `root entry {
        print("=== 1. Basic Filter Comprehension ===");
        # Create objects with varying attributes
        random.seed(42);
        items = [];
        for i = 0 to i < 10 by i += 1 {
            items.append(
                TestObj(x=random.randint(0, 20), y=random.randint(0, 20), z=i)
            );
        }

        # Filter comprehension: collection(?condition1, condition2, ...)
        # Filters objects where ALL conditions are true
        filtered = items(?x>=10,y<15);
        print(f"Filtered {len(items)} items to {len(filtered)} where x>=10 and y<15");

        print("\n=== 2. Filter with Single Condition ===");
        high_x = items(?x>15);
        print(f"Items with x > 15: {len(high_x)}");

        print("\n=== 3. Filter with Multiple Conditions ===");
        complex_filter = items(?x>=5,x<=15,y>10);
        print(f"Items with 5 <= x <= 15 and y > 10: {len(complex_filter)}");

        print("\n=== 4. Basic Assign Comprehension ===");
        # Create fresh objects
        objs = [TestObj(x=i) for i in range(3)];
        print(f"Before assign: x values = {[o.x for o in objs]}");

        # Assign comprehension: collection(=attr1=val1, attr2=val2, ...)
        # Sets attributes on ALL objects in collection
        objs(=y=100,z=200);
        print(f"After assign(=y=100, z=200): y values = {[o.y for o in objs]}");

        print("\n=== 5. Chained Filter and Assign ===");
        # Filter THEN assign
        people = [
            Person(name="Alice", age=25, score=80),
            Person(name="Bob", age=30, score=90),
            Person(name="Charlie", age=35, score=70)
        ];

        # Filter people age >= 30, then boost their scores
        people(?age>=30)(=score=95);
        print("People after filter(age>=30) + assign(score=95):");
        for p in people {
            print(f"  {p.name}: age={p.age}, score={p.score}");
        }

        print("\n=== 6. Multiple Chained Filters ===");
        data = [TestObj(x=i, y=i * 2, z=i * 3) for i in range(10)];
        # Apply multiple filters in sequence
        result = data(?x>2)(?y<15)(?z>=6);
        print(f"Triple filtered from {len(data)} to {len(result)} items");

        # Build graph for spatial comprehensions
        print("\n=== Building Organization Graph ===");
        mgr = Employee(name="Manager", salary=100000, department="Engineering");
        dev1 = Employee(name="Dev1", salary=80000, department="Engineering");
        dev2 = Employee(name="Dev2", salary=75000, department="Engineering");
        dev3 = Employee(name="Dev3", salary=70000, department="Sales");

        root ++> mgr;
        mgr +>: ReportsTo(years=5) :+> dev1;
        mgr +>: ReportsTo(years=2) :+> dev2;
        mgr +>: ReportsTo(years=1) :+> dev3;
        dev1 <+: Collaborates(project="ProjectX") :+> dev2;

        print("Graph built: Manager -> 3 Devs");

        # Visit employees to demonstrate edge comprehensions
        visit [-->];
    }

    can demo_edge_filters with Employee entry {
        print(f"\n=== At {here.name} ===");

        print("=== 7. Filter Comprehension on Edge Results ===");
        # Edge traversal returns nodes; filter on NODE attributes
        # Syntax: [edge_expr](?node_attribute_filter)

        # Get all direct reports and filter by salary
        all_reports = [-->];
        high_paid = all_reports(?salary>75000);
        print(
            f"Direct reports: {len(all_reports)}, high paid (>75k): {len(high_paid)}"
        );

        print("\n=== 8. Typed Edge with Node Filter ===");
        # Traverse specific edge type, filter resulting nodes
        reports_via_edge = [->:ReportsTo:->];
        engineering = reports_via_edge(?department=="Engineering");
        print(
            f"ReportsTo edges: {len(reports_via_edge)}, in Engineering: {len(
                engineering
            )}"
        );

        print("\n=== 9. Assign Comprehension on Edge Results ===");
        # Get nodes via edges, then modify them
        if len(all_reports) > 0 {
            # Assign to all employees found via outgoing edges
            all_reports(=department="Updated");
            print(f"Updated department for {len(all_reports)} employees");
        }

        print("\n=== 10. Chained Edge Traversal + Filter + Assign ===");
        # Get nodes, filter them, then modify filtered subset
        targets = [-->];
        if len(targets) > 0 {
            high_earners = targets(?salary>=75000);
            if len(high_earners) > 0 {
                high_earners(=salary=90000);
                print(f"Gave raise to {len(high_earners)} employees");
            }
        }

        print("\n=== 11. Outgoing Edge Results Only ===");
        # Focus on outgoing edges which return only Employee nodes
        out_edges = [-->];
        print(f"Total outgoing connections: {len(out_edges)}");

        disengage;
    }
}

# ===== Additional Comprehension Patterns =====
with entry {
    print("=== 12. Filter Comprehension Comparison Operators ===");
}

glob nums = [TestObj(x=i) for i in range(10)],
     equal_five = nums(?x==5),
     not_five = nums(?x!=5),
     greater = nums(?x>5),
     greater_eq = nums(?x>=5),
     less = nums(?x<5),
     less_eq = nums(?x<=5);

with entry {
    print(f"x==5: {len(equal_five)}, x!=5: {len(not_five)}");
    print(f"x>5: {len(greater)}, x>=5: {len(greater_eq)}");
    print(f"x<5: {len(less)}, x<=5: {len(less_eq)}");

    print("\n=== 13. Assign with Multiple Attributes ===");
}

glob people = [Person(name=f"Person{i}") for i in range(5)];

with entry {
    people(=age=25,score=100);
    print(f"Assigned age=25, score=100 to {len(people)} people");
    print(f"First person: age={people[0].age}, score={people[0].score}");

    print("\n=== 14. Empty Collection Handling ===");
}

glob empty = [],
     filtered_empty = empty(?x>5),
     assigned_empty = empty(=x=10);

with entry {
    print(f"Filter on empty: {len(filtered_empty)}");
    print(f"Assign on empty: {len(assigned_empty)}");

    print("\n=== 15. Comprehension Return Values ===");
}

glob original = [TestObj(x=i) for i in range(3)],
     filtered = original(?x>0),
     assigned = original(=y=50);

with entry {
    print(f"Original list: {len(original)} items");
    print(f"Filtered returns: {len(filtered)} items (new list)");
    print(f"Assigned returns: {len(assigned)} items (same list, modified)");
    print(f"Original[0].y after assign: {original[0].y}");

    print("\n=== Running Walker Demo ===");
    root spawn ComprehensionDemo();

    print("\n✓ All special comprehension variations demonstrated!");
}

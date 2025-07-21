# Chapter 10: Walkers and Abilities

Walkers are the heart of Object-Spatial Programming - they are mobile computational entities that traverse your graph and execute code at each location. Combined with abilities, they enable reactive, event-driven programming where computation happens exactly where and when it's needed.


> Unlike traditional functions that operate on data passed to them, walkers travel to where data lives, making computation truly spatial and enabling powerful distributed processing patterns.

## Walker Spawn and Visit
---
Walkers move through graphs using `spawn` (to start) and `visit` (to continue to connected nodes). This enables complex traversal patterns with simple syntax.




### Advanced Traversal Control

```jac
import random;

node Student {
    has name: str;
    has grade_level: int;
    has messages: list[str] = [];
}

edge StudyGroup {
    has subject: str;
}

walker AttendanceChecker {
    has present_students: list[str] = [];
    has absent_students: list[str] = [];
    has max_checks: int = 5;
    has checks_done: int = 0;

    can check_attendance with Student entry {
        self.checks_done += 1;

        # Simulate checking if student is present (random for demo)
        is_present = random.choice([True, False]);

        if is_present {
            print(f"{here.name} is present");
            self.present_students.append(here.name);
        } else {
            print(f"{here.name} is absent");
            self.absent_students.append(here.name);
        }

        # Control flow based on conditions
        if self.checks_done >= self.max_checks {
            print(f"Reached maximum checks ({self.max_checks})");
            self.report_final();
            disengage;  # Stop the walker
        }

        # Skip if no more connections
        connections = [-->];
        if not connections {
            print("No more students to check");
            self.report_final();
            disengage;
        }

        # Continue to next student
        visit [-->];
    }

    def report_final() -> None {
        print(f" Attendance Report:");
        print(f"   Present: {self.present_students}");
        print(f"   Absent: {self.absent_students}");
        print(f"   Total checked: {self.checks_done}");
    }
}

with entry {
    # Create a chain of students
    alice = root ++> Student(name="Alice", grade_level=9);
    bob = alice ++> Student(name="Bob", grade_level=9);
    charlie = bob ++> Student(name="Charlie", grade_level=9);
    diana = charlie ++> Student(name="Diana", grade_level=9);
    eve = diana ++> Student(name="Eve", grade_level=9);

    # Start attendance check
    checker = AttendanceChecker(max_checks=3);
    alice[0] spawn checker;
}
```


## Walker Control Flow
---
Walkers can control their movement through the graph using special statements like `visit` and `disengage`.

### Controlling Walker Behavior

```jac
node Student {
    has name: str;
    has grade_level: int;
}

walker AttendanceChecker {
    has present_students: list[str] = [];
    has absent_students: list[str] = [];
    has max_checks: int = 5;
    has checks_done: int = 0;

    can check_attendance with Student entry {
        self.checks_done += 1;

        # Simulate checking if student is present (random for demo)
        import random;
        is_present = random.choice([True, False]);

        if is_present {
            print(f"{here.name} is present");
            self.present_students.append(here.name);
        } else {
            print(f"{here.name} is absent");
            self.absent_students.append(here.name);
        }

        # Control flow based on conditions
        if self.checks_done >= self.max_checks {
            print(f"Reached maximum checks ({self.max_checks})");
            self.report_final();
            disengage;  # Stop the walker
        }

        # Skip if no more connections
        connections = [-->];
        if not connections {
            print("No more students to check");
            self.report_final();
            disengage;
        }

        # Continue to next student
        visit [-->];
    }

    def report_final() -> None {
        print(f" Attendance Report:");
        print(f"   Present: {self.present_students}");
        print(f"   Absent: {self.absent_students}");
        print(f"   Total checked: {self.checks_done}");
    }
}

with entry {
    # Create a chain of students
    alice = root ++> Student(name="Alice", grade_level=9);
    bob = alice ++> Student(name="Bob", grade_level=9);
    charlie = bob ++> Student(name="Charlie", grade_level=9);
    diana = charlie ++> Student(name="Diana", grade_level=9);
    eve = diana ++> Student(name="Eve", grade_level=9);

    # Start attendance check
    checker = AttendanceChecker(max_checks=3);
    alice[0] spawn checker;
}
```


## Key Concepts Summary
---
- **Walkers** are mobile computational entities that traverse graphs
- **Abilities** are event-driven methods that execute automatically during traversal
- **Entry abilities** trigger when a walker arrives at a node
- **Exit abilities** trigger when a walker leaves a node
- **Spawn** activates a walker at a specific starting location
- **Visit** moves a walker to connected nodes
- **Disengage** stops a walker's execution

## Best Practices
---
- **Keep abilities focused**: Each ability should have a single, clear purpose
- **Use descriptive names**: Make it clear what each walker and ability does
- **Handle edge cases**: Check for empty connections before visiting
- **Control traversal flow**: Use conditions to avoid infinite loops
- **Report results**: Use exit abilities to summarize walker activities
- **Manage state**: Use walker properties to track progress and results

## Key Takeaways
---
**Walker System:**

- **Mobile computation**: Walkers bring processing directly to data locations
- **State management**: Walkers carry their own state as they traverse
- **Traversal control**: Fine-grained control over movement patterns
- **Spawning mechanism**: Activate walkers at specific graph locations

**Ability System:**

- **Event-driven execution**: Abilities trigger automatically based on walker location
- **Entry/exit patterns**: React to walker arrival and departure events
- **Context awareness**: Abilities have access to current node (`here`) and walker state
- **Conditional execution**: Abilities can include logic to control when they execute

**Traversal Patterns:**

- **Visit statements**: Direct walker movement to connected nodes
- **Filtering support**: Visit only nodes that match specific criteria
- **Flow control**: Use `disengage` to stop walker execution
- **Recursive traversal**: Walkers can spawn other walkers for complex patterns

**Practical Applications:**

- **Data processing**: Process distributed data where it lives
- **Graph analysis**: Analyze relationships and connections
- **Message delivery**: Distribute information through networks
- **State propagation**: Update related nodes based on changes

!!! tip "Try It Yourself"
    Master walkers and abilities by building:
    - A message delivery system that traverses social networks
    - An attendance checker that visits classrooms
    - A family tree explorer that analyzes relationships
    - A network analyzer that processes organizational structures

    Remember: Walkers bring computation to data - think about how your processing can move through your graph!

---

*Walkers and abilities are now part of your toolkit. Let's master advanced graph operations and sophisticated traversal patterns!*

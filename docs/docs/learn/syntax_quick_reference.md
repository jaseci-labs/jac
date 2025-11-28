# Syntax Quick Reference

<!-- started with https://learnxinyminutes.com/go-->
```jac
# jac is a superset of python and contains all of its features
# You can run code with
# jac run <filename>

# Single line comment
#*
    Multi-line
    Comment
*#

# Import declaration declares library packages referenced in this file.
# Simple imports
import os;
import sys, json;
import time;

# Import with alias
import datetime as dt;

# Import from with specific items
import from math { sqrt, pi, log as logarithm }


# functions are defined with the def keyword and a control block
def nextFunction {
	x = 3;     # Variable assignment.
	y = 4;
	(add, mult) = learnMultiple(x, y);       # Function returns two values.
	print(f"sum: {add} prod:{mult}"); 		 # values can be formatted with f-strings
	learnFlowControl();
}

# same as Python, Jac supports default paremeters and multiple return values
def learnMultiple(x: int, y: int = 5) -> (int, int) {
	return (x + y, x * y); # Return two values.
}

def learnFlowControl() {
	x = 9;

	# All control blocks require brackets, but not parentheses
	if x < 5 {
		print("Doesn't run");
	} elif x < 10 {
		print("Run");
	} else {
		print("Also doesn't run");
	}

	# chains of if-else can be replaced with match statements
	match x {
		case 1:
			print("Exactly one");
		case int() if 10 <= x < 15:
			print("Within a range");
		case _:
			print("Everything else");
	}

	# Like if, for doesn't use parens either.
	# jac provides both indexed and range-based for loops
	for i = 10 to i <= 20 by i += 2 {
		print(f"element: {i}");
	}

	for x in ["a", "b", "c"] {
		print(f"element: {x}");
	}

	# while loops follow similar syntax
	a = 4;
	while a != 1{
		a /= 2;
	}

	learnCollections();
	learnSpecial();
}

def learnCollections() {
	# lists and slicing
	fruits = ["apple", "banana", "cherry"];
	print(fruits[1]); # banana
	print(fruits[:1]); # [apple, banana]
	print(fruits[-1]); # cherry

	# dictionary
    person = {
        "name": "Alice",
        "age": 25,
        "city": "Seattle"
    };

    # Access values by key
    print(person["name"]);  # Alice
    print(person["age"]);   # 25

	# tuples are immutable lists
	point = (10,20);
    print(point[0]);  # 10
    print(point[1]);  # 20

	# tuples can be unpacked with parentheses
	(x, y) = point;
    print(f"x={x}, y={y}");

	# list comprehensions
    squares = [i ** 2 for i in range(5)];
    print(squares);  # [0, 1, 4, 9, 16]

    # With condition
    evens = [i for i in range(10) if i % 2 == 0];
    print(evens);  # [0, 2, 4, 6, 8]

	learnClasses();
	learnOSP();
}

def learnClasses() {

    # the class keyword follows default Python behavior
    # all members are static
    class Cat {
        has name: str = "Unnamed";
        def meow {
			print(f"{self.name} says meow!");
        }
    }

    your_cat = Cat();
    my_cat = Cat();
    my_cat.name = "Shrodinger";

    my_cat.meow();   # Shrodinger says meow!
    your_cat.meow(); # Shrodinger says meow!

	# the obj keyword follows the behavior of Python dataclasses
    # all members are per-instance
	obj Dog {
		has name: str = "Unnamed";
		has age: int = 0;

		def bark {
			print(f"{self.name} says Woof!");
		}
	}
    your_dog = Dog();
    my_dog = Dog();
    my_dog.name = "Buddy";
    my_dog.age = 3;

	your_dog.bark(); # Unnamed says Woof!
	my_dog.bark();   # Buddy says Woof!

	# inheritance
	obj Puppy(Dog){
		has parent: str = 0;
		def bark { # override
			print(f"Child of {self.parent} says Woof!");
		}
	}
}

# Jac also supports graph relationships within the type system
# This is called Object Spatial Programming

# nodes are objs with special properties
node Person {
    has name: str;
    has age: int;
}

def learnOSP(){
	a = Person(name="Alice",age=25);
	b = Person(name="Bob",age=30);
	c = Person(name="Charlie",age=28);

	# connection operators create edges between nodes
	a ++>  b; # forward a->b
	b <++  c; # backward c->b
	a <++> c; # bidirectional a <-> c

	# edges can be typed, providing additional meaning
	edge Friend {
		has since: int;
	}

	a +>:Friend(since=2020):+> b;
	a +>:Friend(since=1995):+> c;


    # edges and nodes can be queried with filters

    # returns all outgoing nodes with friend edges since 2018
    old_friend_nodes = [node a ->:Friend:since > 2018:->];

    # returns all outgoing friend edges since 2018
    old_friend_edges = [edge a->:Friend:since > 2017:->];

	# Walkers are objects that "walk" across nodes doing operations
	# Walkers contain automatic methods that trigger on events
	# These methods are called abilities
	walker Visitor {
        has name: str;

        # abilities follow can <name> with <type> <operation> syntax
		# runs when walker spawns at root
		can start with `root entry {
			print(f"Starting!");
			# visit moves to an adjacent node
			visit [-->]; # [-->] corresponds to outgoing connections
			# visit [<--]; incoming connections
			# visit [<-->]; all connections
		}

		# runs when walker visits any person
		can meet_person with Person entry {
			# here refers to current node
			# self refers to walker
			print(f"Visiting {here.name} with walker {self.name}");
			if here.name == "Joe" {
				print("Found Joe");
				disengage; # stop traversal immediately
			}

            # report returns a value without stopping exeuction
            # all reported values are accessed as a list after traversal
			report here.name;
			visit [-->];
		}

		# runs when walker is done
		can finish with exit {
			print("Ending!");
		}
	}

	# nodes can also have abilities
	node FriendlyPerson(Person) {
		has name:str;
		can greet with Visitor entry{
			print(f"Welcome, visitor");
		}
	}

    f = FriendlyPerson(name="Joe",age=10);

    # root is a special named node in all graphs
    root ++> f ++> a;

    # walker can then be spawned at a node in the graph
    root spawn Visitor("Jim");
}

def learnSpecial(){
    # lambdas create anonymous functions
    add = lambda a: int, b: int -> int : a + b;
    print(add(5, 3));

    # walrus operator allow assignment within expressions
    result = (y := 20) + 10;
    print(f"y = {y}, result = {result}");

    # flow/wait is jac's equivalent to async/await for concurrency
    # in jac, these are executed in a thread pool
    def compute(x: int, y: int) -> int {
        print(f"Computing {x} + {y}");
        return x + y;
    }

    def slow_task(n: int) -> int {
        print(f"Task {n} started");
        time.sleep(1);
        print(f"Task {n} done");
        return n * 2;
    }

    task1 = flow slow_task(42);
    task2 = flow compute(5, 10);
    task3 = flow compute(3, 7);

    result1 = wait task1;
    result2 = wait task2;
    result3 = wait task3;
    print(f"Results: {result1}, {result2}, {result3}");
    #* Output:
    Task 42 started
    Computing 5 + 10
    Computing 3 + 7
    Task 42 done
    Results: 84, 15, 10
    *#
}

# all programs start from the entry node
with entry {
    # print function outputs a line to stdout
    print("Hello world!");

    # call some other function
    nextFunction();
}
```

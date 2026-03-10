"""Comprehensive tests for Self type across the Jac language.

Self (capital S) refers to the current enclosing type. It is:
- Auto-injected as the first parameter in `class def` (classmethod) methods
- Usable as a return type annotation in instance methods (fluent/builder pattern)
- Polymorphic: in a subclass, Self resolves to the subclass type
- Valid in obj, node, edge, walker, enum, and generic contexts
"""

import from typing { TypeVar, Callable }

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: class def — classmethod basics
# ═══════════════════════════════════════════════════════════════════════════════

"""Basic classmethod using `class def` with auto-injected Self."""
obj Counter {
    has count: int = 0;

    class def create() -> Self {
        return Self(count=0);
    }

    class def create_with(n: int) -> Self {
        return Self(count=n);
    }

    def increment() -> Self {
        self.count += 1;
        return self;
    }
}

with entry:__main__ {
    # --- Section 1: class def basics ---
    c1 = Counter.create();
    print(f"1.1: {c1.count}");  # 0

    c2 = Counter.create_with(42);
    print(f"1.2: {c2.count}");  # 42

    c3 = Counter.create().increment().increment().increment();
    print(f"1.3: {c3.count}");  # 3
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: class def — Self refers to the class, not an instance
# ═══════════════════════════════════════════════════════════════════════════════

"""Self in classmethod should provide access to class-level attributes."""
obj Registry {
    has name: str,
        tag: str = "default";

    class def class_name() -> str {
        return Self.__name__;
    }

    class def make(name: str) -> Self {
        return Self(name=name);
    }

    class def make_tagged(name: str, tag: str) -> Self {
        return Self(name=name, tag=tag);
    }
}

with entry:__main__ {
    # --- Section 2: Self refers to the class ---
    print(f"2.1: {Registry.class_name()}");  # Registry

    r = Registry.make("alpha");
    print(f"2.2: {r.name}");  # alpha
    print(f"2.3: {r.tag}");   # default

    r2 = Registry.make_tagged("beta", "vip");
    print(f"2.4: {r2.name} {r2.tag}");  # beta vip
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: Self as return type in instance methods (fluent/builder pattern)
# ═══════════════════════════════════════════════════════════════════════════════

"""Builder pattern using Self as return type annotation."""
obj QueryBuilder {
    has table: str = "",
        conditions: list[str] = [],
        limit_val: int = -1;

    def from_table(table: str) -> Self {
        self.table = table;
        return self;
    }

    def where(condition: str) -> Self {
        self.conditions.append(condition);
        return self;
    }

    def limit(n: int) -> Self {
        self.limit_val = n;
        return self;
    }

    def build() -> str {
        q = f"SELECT * FROM {self.table}";
        if self.conditions {
            q += " WHERE " + " AND ".join(self.conditions);
        }
        if self.limit_val > 0 {
            q += f" LIMIT {self.limit_val}";
        }
        return q;
    }
}

with entry:__main__ {
    # --- Section 3: fluent builder ---
    q = QueryBuilder().from_table("users").where("age > 18").where("active = 1").limit(10).build();
    print(f"3.1: {q}");  # SELECT * FROM users WHERE age > 18 AND active = 1 LIMIT 10
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: Self with inheritance — polymorphic behavior
# ═══════════════════════════════════════════════════════════════════════════════

"""Self should resolve to the actual subclass type in inherited classmethods."""
obj Animal {
    has name: str,
        sound: str = "...";

    class def create(name: str) -> Self {
        return Self(name=name);
    }

    def speak() -> str {
        return f"{self.name} says {self.sound}";
    }
}

obj Dog(Animal) {
    has sound: str = "woof";
}

obj Cat(Animal) {
    has sound: str = "meow";
}

with entry:__main__ {
    # --- Section 4: inheritance polymorphism ---
    d = Dog.create("Rex");
    c = Cat.create("Whiskers");

    print(f"4.1: {d.speak()}");  # Rex says woof
    print(f"4.2: {c.speak()}");  # Whiskers says meow
    print(f"4.3: {type(d).__name__}");  # Dog
    print(f"4.4: {type(c).__name__}");  # Cat
}

"""Self return type in instance methods should also be polymorphic."""
obj Base {
    has val: int = 0;

    def set_val(v: int) -> Self {
        self.val = v;
        return self;
    }
}

obj Derived(Base) {
    has extra: str = "derived";
}

with entry:__main__ {
    # set_val returns Derived, not Base
    d = Derived().set_val(99);
    print(f"4.5: {type(d).__name__} {d.val} {d.extra}");  # Derived 99 derived
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: Self in multi-level inheritance chains
# ═══════════════════════════════════════════════════════════════════════════════

"""Self should propagate correctly through deep inheritance."""
obj Shape {
    has x: float = 0.0,
        y: float = 0.0;

    class def at_origin() -> Self {
        return Self();
    }

    class def at(x: float, y: float) -> Self {
        inst = Self();
        inst.x = x;
        inst.y = y;
        return inst;
    }

    def move(dx: float, dy: float) -> Self {
        self.x += dx;
        self.y += dy;
        return self;
    }

    def pos() -> str {
        return f"({self.x}, {self.y})";
    }
}

obj Circle(Shape) {
    has radius: float = 1.0;
}

obj ColoredCircle(Circle) {
    has color: str = "red";
}

with entry:__main__ {
    # --- Section 5: multi-level inheritance ---
    s = Shape.at(1.0, 2.0);
    print(f"5.1: {type(s).__name__} {s.pos()}");  # Shape (1.0, 2.0)

    c = Circle.at(3.0, 4.0);
    print(f"5.2: {type(c).__name__} {c.pos()}");  # Circle (3.0, 4.0)

    cc = ColoredCircle.at_origin().move(5.0, 6.0);
    print(f"5.3: {type(cc).__name__} {cc.pos()} {cc.color}");  # ColoredCircle (5.0, 6.0) red
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: Self as parameter type (accepting same-type arguments)
# ═══════════════════════════════════════════════════════════════════════════════

"""Self as a parameter type for methods that accept same-type arguments."""
obj Vector {
    has x: float = 0.0,
        y: float = 0.0;

    def add(other: Self) -> Self {
        return Self(x=self.x + other.x, y=self.y + other.y);
    }

    def equals(other: Self) -> bool {
        return self.x == other.x and self.y == other.y;
    }

    def __str__() -> str {
        return f"Vector({self.x}, {self.y})";
    }
}

with entry:__main__ {
    # --- Section 6: Self as parameter type ---
    v1 = Vector(x=1.0, y=2.0);
    v2 = Vector(x=3.0, y=4.0);
    v3 = v1.add(v2);
    print(f"6.1: {v3}");  # Vector(4.0, 6.0)
    print(f"6.2: {v1.equals(Vector(x=1.0, y=2.0))}");  # True
    print(f"6.3: {v1.equals(v2)}");  # False
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: Self in node, edge, walker archetypes
# ═══════════════════════════════════════════════════════════════════════════════

"""Self should work in all archetype kinds: node, edge, walker."""
node TreeNode {
    has label: str,
        depth: int = 0;

    class def root(label: str) -> Self {
        return Self(label=label, depth=0);
    }

    class def child(label: str, depth: int) -> Self {
        return Self(label=label, depth=depth);
    }

    def describe() -> str {
        return f"{self.label}@d{self.depth}";
    }
}

edge WeightedEdge {
    has weight: float = 1.0;

    class def with_weight(w: float) -> Self {
        return Self(weight=w);
    }

    def scale(factor: float) -> Self {
        self.weight *= factor;
        return self;
    }
}

walker DepthWalker {
    has max_depth: int = 3,
        visited: list[str] = [];

    class def create(max_depth: int) -> Self {
        return Self(max_depth=max_depth);
    }

    def record(label: str) -> Self {
        self.visited.append(label);
        return self;
    }
}

with entry:__main__ {
    # --- Section 7: node/edge/walker ---
    root_node = TreeNode.root("root");
    child = TreeNode.child("leaf", 2);
    print(f"7.1: {root_node.describe()}");  # root@d0
    print(f"7.2: {child.describe()}");  # leaf@d2
    print(f"7.3: {type(root_node).__name__}");  # TreeNode

    e = WeightedEdge.with_weight(2.5).scale(2.0);
    print(f"7.4: {e.weight}");  # 5.0

    w = DepthWalker.create(5).record("a").record("b");
    print(f"7.5: {w.max_depth} {w.visited}");  # 5 ['a', 'b']
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: Self with generics
# ═══════════════════════════════════════════════════════════════════════════════

"""Self in generic classes should preserve type parameters."""
glob T = TypeVar('T');

obj Stack[T] {
    has items: list[T] = [];

    class def empty() -> Self {
        return Self();
    }

    def push(item: T) -> Self {
        self.items.append(item);
        return self;
    }

    def peek() -> T {
        return self.items[-1];
    }

    def size() -> int {
        return len(self.items);
    }
}

with entry:__main__ {
    # --- Section 8: generics ---
    s = Stack[int].empty().push(1).push(2).push(3);
    print(f"8.1: {s.size()}");  # 3
    print(f"8.2: {s.peek()}");  # 3

    ss = Stack[str].empty().push("hello").push("world");
    print(f"8.3: {ss.peek()}");  # world
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 9: Self in enum methods
# ═══════════════════════════════════════════════════════════════════════════════

"""Self in enum — reference enum members via the enum name."""
enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

with entry:__main__ {
    # --- Section 9: enum ---
    primaries = [Color.RED, Color.GREEN, Color.BLUE];
    print(f"9.1: {len(primaries)}");  # 3
    print(f"9.2: {Color.RED == Color.RED}");  # True
    print(f"9.3: {Color.BLUE == Color.RED}");  # False
    print(f"9.4: Color: {Color.GREEN.value}");  # Color: green
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: Self in abstract methods
# ═══════════════════════════════════════════════════════════════════════════════

"""Self as return type in abstract method declarations."""
obj Cloneable {
    def clone() -> Self abs;
}

obj Point(Cloneable) {
    has x: int = 0,
        y: int = 0;

    override def clone() -> Self {
        return Self(x=self.x, y=self.y);
    }
}

obj Point3D(Point) {
    has z: int = 0;

    override def clone() -> Self {
        return Self(x=self.x, y=self.y, z=self.z);
    }
}

with entry:__main__ {
    # --- Section 10: abstract methods ---
    p = Point(x=3, y=4);
    p2 = p.clone();
    print(f"10.1: {p2.x} {p2.y}");  # 3 4
    print(f"10.2: {type(p2).__name__}");  # Point
    print(f"10.3: {p is not p2}");  # True (distinct objects)

    p3d = Point3D(x=1, y=2, z=3);
    p3d_clone = p3d.clone();
    print(f"10.4: {p3d_clone.x} {p3d_clone.y} {p3d_clone.z}");  # 1 2 3
    print(f"10.5: {type(p3d_clone).__name__}");  # Point3D
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 11: Self in impl blocks (separate declaration and definition)
# ═══════════════════════════════════════════════════════════════════════════════

"""Self should resolve correctly in detached impl blocks."""
obj Config {
    has debug: bool = False,
        verbose: bool = False,
        level: int = 0;

    class def default() -> Self;
    def with_debug() -> Self;
    def with_verbose() -> Self;
    def with_level(n: int) -> Self;
}

impl Config.default() -> Self {
    return Self(debug=False, verbose=False, level=0);
}

impl Config.with_debug() -> Self {
    self.debug = True;
    return self;
}

impl Config.with_verbose() -> Self {
    self.verbose = True;
    return self;
}

impl Config.with_level(n: int) -> Self {
    self.level = n;
    return self;
}

with entry:__main__ {
    # --- Section 11: impl blocks ---
    cfg = Config.default().with_debug().with_verbose().with_level(3);
    print(f"11.1: debug={cfg.debug} verbose={cfg.verbose} level={cfg.level}");
    # debug=True verbose=True level=3
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 12: Self with class-level has (static fields)
# ═══════════════════════════════════════════════════════════════════════════════

"""class def interacting with static (class-level) has fields."""
obj Singleton {
    static has _instance: Singleton | None = None;
    has value: int = 0;

    class def get_instance() -> Self {
        if Self._instance is None {
            Self._instance = Self(value=0);
        }
        return Self._instance;
    }

    def set_value(v: int) -> Self {
        self.value = v;
        return self;
    }
}

with entry:__main__ {
    # --- Section 12: static fields ---
    s1 = Singleton.get_instance().set_value(42);
    s2 = Singleton.get_instance();
    print(f"12.1: {s1.value}");  # 42
    print(f"12.2: {s2.value}");  # 42
    print(f"12.3: {s1 is s2}");  # True
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 13: Self in comparison and equality methods
# ═══════════════════════════════════════════════════════════════════════════════

"""Self as parameter type in dunder/magic methods."""
obj Money {
    has amount: float,
        currency: str = "USD";

    def __eq__(other: Self) -> bool {
        return self.amount == other.amount and self.currency == other.currency;
    }

    def __add__(other: Self) -> Self {
        if self.currency != other.currency {
            raise ValueError("Currency mismatch");
        }
        return Self(amount=self.amount + other.amount, currency=self.currency);
    }

    def __str__() -> str {
        return f"{self.amount} {self.currency}";
    }
}

with entry:__main__ {
    # --- Section 13: dunder methods ---
    m1 = Money(amount=10.0);
    m2 = Money(amount=20.0);
    m3 = m1 + m2;
    print(f"13.1: {m3}");  # 30.0 USD
    print(f"13.2: {m1 == Money(amount=10.0)}");  # True
    print(f"13.3: {m1 == m2}");  # False
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 14: Self used alongside explicit self parameter
# ═══════════════════════════════════════════════════════════════════════════════

"""Self (type) and self (instance) coexist without conflict."""
obj Wrapper {
    has data: str = "";

    def copy() -> Self {
        # self = instance, Self = the type
        return Self(data=self.data);
    }

    def transform(fn: Callable[[str], str]) -> Self {
        return Self(data=fn(self.data));
    }

    class def from_str(s: str) -> Self {
        # Self = the class (auto-injected), no self here
        return Self(data=s);
    }
}

with entry:__main__ {
    # --- Section 14: Self vs self coexistence ---
    w = Wrapper.from_str("hello");
    w2 = w.copy();
    w3 = w.transform(str.upper);
    print(f"14.1: {w.data}");   # hello
    print(f"14.2: {w2.data}");  # hello
    print(f"14.3: {w3.data}");  # HELLO
    print(f"14.4: {w is not w2}");  # True
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 15: class def with multiple class defs in same obj
# ═══════════════════════════════════════════════════════════════════════════════

"""Multiple classmethods coexisting, calling each other via Self."""
obj Formatter {
    has text: str = "",
        width: int = 80;

    class def narrow(text: str) -> Self {
        return Self(text=text, width=40);
    }

    class def wide(text: str) -> Self {
        return Self(text=text, width=120);
    }

    class def default_fmt(text: str) -> Self {
        return Self(text=text);
    }

    def format() -> str {
        if len(self.text) > self.width {
            return self.text[:self.width] + "...";
        }
        return self.text;
    }
}

with entry:__main__ {
    # --- Section 15: multiple classmethods ---
    f1 = Formatter.narrow("short");
    f2 = Formatter.narrow("a" * 50);
    f3 = Formatter.wide("b" * 50);
    print(f"15.1: {f1.format()}");  # short
    print(f"15.2: {len(f2.format())}");  # 43 (40 + "...")
    print(f"15.3: {f3.format()}");  # 50 b's (under 120)
}

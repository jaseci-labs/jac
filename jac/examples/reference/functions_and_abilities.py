from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _jl

class BasicMath(_jl.Obj):

    def add(self, x: int, y: int) -> int:
        return x + y

    def get_default(self) -> int:
        return 42

    def multiply(self, a: object, b: object) -> object:
        return a * b

class Calculator(_jl.Obj):
    instance_name: str = 'calc'

    @staticmethod
    def square(x: int) -> int:
        return x * x

    @staticmethod
    def internal_helper(x: int) -> int:
        return x + 100

    def public_method(self, x: int) -> int:
        return x * 2

    def protected_method(self) -> str:
        return 'protected'

class AbstractCalculator(_jl.Obj):

    @abstractmethod
    def compute(self, x: int, y: int) -> int:
        pass

    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/functions_and_abilities.jac')
    def process(self, value: float) -> float:
        return value * 1.5

    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/functions_and_abilities.jac')
    def aggregate(self, *numbers: tuple) -> float:
        return sum(numbers) / len(numbers) if numbers else 0.0

    @_jl.impl_patch_filename('/home/ninja/jaseci/jac/examples/reference/functions_and_abilities.jac')
    def configure(self, **options: dict) -> dict:
        options['configured'] = True
        return options

class ConcreteCalculator(AbstractCalculator, _jl.Obj):

    def compute(self, x: int, y: int) -> int:
        return x - y

class Variadic(_jl.Obj):

    def sum_all(self, *values: tuple) -> int:
        return sum(values)

    def collect_options(self, **opts: dict) -> dict:
        return opts

    def combined(self, base: int, *extras: tuple, **options: dict) -> dict:
        return {'base': base, 'extras': extras, 'options': options}

async def fetch_remote(url: str) -> dict:
    return {'url': url, 'status': 'fetched'}

async def process_batch(items: list) -> list:
    return [item * 2 for item in items]

def logger(func: object) -> None:
    print(f'Decorator applied to {func.__name__}')
    return func

def tracer(func: object) -> None:
    print('Tracer applied')
    return func

@logger
def logged_func(x: int) -> int:
    return x + 1

@logger
@tracer
def double_decorated(x: int) -> int:
    return x * 2

class BasicWalker(_jl.Walker):
    counter: int = 0

    @_jl.entry
    def initialize(self, here) -> None:
        self.counter = 0
        print('BasicWalker: initialized')

    @_jl.exit
    def finalize(self, here) -> None:
        print(f'BasicWalker: done, counter={self.counter}')

class Person(_jl.Node):
    name: str
    age: int = 0

class City(_jl.Node):
    name: str
    population: int = 0

class TypedWalker(_jl.Walker):
    people_visited: int = 0
    cities_visited: int = 0

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        print('TypedWalker: Starting at root')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def handle_person(self, here: Person) -> None:
        self.people_visited += 1
        print(f'  Visiting person: {here.name}, age {here.age}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def handle_city(self, here: City) -> None:
        self.cities_visited += 1
        print(f'  Visiting city: {here.name}, pop {here.population}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.exit
    def report(self, here) -> None:
        print(f'TypedWalker: Visited {self.people_visited} people, {self.cities_visited} cities')

class MultiAbilityWalker(_jl.Walker):
    stage: str = 'initial'

    @_jl.entry
    def first_pass(self, here: Person) -> None:
        if self.stage == 'initial':
            print(f'  First pass: {here.name}')
            self.stage = 'processed'

    @_jl.entry
    def second_pass(self, here: Person) -> None:
        if self.stage == 'processed':
            print(f'  Second pass: {here.name}')

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class InteractivePerson(_jl.Node):
    name: str
    greeted: bool = False

    @_jl.entry
    def greet_typed(self, visitor: TypedWalker) -> None:
        print(f'    {self.name} says: Hello TypedWalker!')
        self.greeted = True

    @_jl.entry
    def greet_multi(self, visitor: MultiAbilityWalker) -> None:
        print(f'    {self.name} says: Hello MultiAbilityWalker!')

class AsyncWalker(_jl.Walker):
    __jac_async__ = True

    @_jl.entry
    async def process(self, here) -> None:
        print('AsyncWalker: async processing')

    @_jl.entry
    async def handle(self, here: Person) -> None:
        print(f'AsyncWalker: async handling {here.name}')
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

class AbstractWalker(_jl.Walker):

    @_jl.entry
    @abstractmethod
    def must_override(self, here) -> None:
        pass

class ConcreteWalker(AbstractWalker, _jl.Walker):

    @_jl.entry
    def must_override(self, here) -> None:
        print('ConcreteWalker: implemented abstract ability')

class StaticAbilityWalker(_jl.Walker):
    instance_data: int = 0

    @staticmethod
    @_jl.entry
    def class_level(self, here) -> None:
        print('Static ability executed')

    @_jl.entry
    def instance_level(self, here) -> None:
        self.instance_data += 1
        print(f'Instance ability: data={self.instance_data}')

class ControlFlowWalker(_jl.Walker):
    max_depth: int = 2
    current_depth: int = 0

    @_jl.entry
    def traverse(self, here: Person) -> None:
        print(f'  Depth {self.current_depth}: {here.name}')
        if self.current_depth >= self.max_depth:
            print('  Max depth reached - stopping')
            _jl.disengage(self)
            return
        self.current_depth += 1
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))

    @_jl.entry
    def start(self, here: _jl.Root) -> None:
        _jl.visit(self, _jl.refs(_jl.Path(here)._out().visit()))
print('=== 1. Basic Functions ===')
math = BasicMath()
print(f'add(5, 3) = {math.add(5, 3)}')
print(f'get_default() = {math.get_default()}')
print(f'multiply(4, 7) = {math.multiply(4, 7)}')
print('\n=== 2. Static and Access Modifiers ===')
print(f'Calculator.square(5) = {Calculator.square(5)}')
calc = Calculator()
print(f'calc.public_method(10) = {calc.public_method(10)}')
print('\n=== 3. Abstract Methods ===')
concrete = ConcreteCalculator()
print(f'compute(10, 3) = {concrete.compute(10, 3)}')
print(f'process(2.5) = {concrete.process(2.5)}')
print(f'aggregate(1,2,3,4,5) = {concrete.aggregate(1, 2, 3, 4, 5)}')
print(f'configure(x=1,y=2) = {concrete.configure(x=1, y=2)}')
print('\n=== 4. Variadic Parameters ===')
v = Variadic()
print(f'sum_all(1,2,3,4,5) = {v.sum_all(1, 2, 3, 4, 5)}')
print(f'collect_options(a=1,b=2) = {v.collect_options(a=1, b=2)}')
print(f'combined(10, 20, 30, x=1, y=2) = {v.combined(10, 20, 30, x=1, y=2)}')
print('\n=== 5. Basic Walker Abilities ===')
_jl.spawn(_jl.root(), BasicWalker())
print('\n=== 6. Walker Abilities with Typed Node Context ===')
alice = Person(name='Alice', age=30)
bob = Person(name='Bob', age=25)
nyc = City(name='NYC', population=8000000)
_jl.connect(left=_jl.root(), right=alice)
_jl.connect(left=_jl.root(), right=bob)
_jl.connect(left=alice, right=nyc)
_jl.spawn(_jl.root(), TypedWalker())
print('\n=== 7. Multiple Abilities on Same Node Type ===')
_jl.spawn(_jl.root(), MultiAbilityWalker())
print('\n=== 8. Node Abilities ===')
charlie = InteractivePerson(name='Charlie')
diana = InteractivePerson(name='Diana')
_jl.connect(left=_jl.root(), right=charlie)
_jl.connect(left=charlie, right=diana)
_jl.spawn(_jl.root(), TypedWalker())
print(f'Charlie greeted: {charlie.greeted}')
print('\n=== 9. Ability Execution and Control Flow ===')
person1 = Person(name='P1', age=20)
person2 = Person(name='P2', age=21)
person3 = Person(name='P3', age=22)
person4 = Person(name='P4', age=23)
_jl.connect(left=_jl.root(), right=person1)
_jl.connect(left=person1, right=person2)
_jl.connect(left=person2, right=person3)
_jl.connect(left=person3, right=person4)
_jl.spawn(_jl.root(), ControlFlowWalker())
print('\n=== 10. Concrete Walker from Abstract ===')
_jl.spawn(_jl.root(), ConcreteWalker())
print('\n✓ Functions and abilities demonstrated!')

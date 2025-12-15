// Interfaces and Types TypeScript fixture

// Basic interface
interface Person {
    name: string;
    age: number;
}

// Optional and readonly properties
interface Config {
    readonly id: string;
    name?: string;
    value: number;
}

// Method signatures
interface Calculator {
    add(a: number, b: number): number;
    subtract(a: number, b: number): number;
}

// Index signatures
interface StringMap {
    [key: string]: string;
}

// Extending interfaces
interface Employee extends Person {
    employeeId: string;
    department: string;
}

// Generic interface
interface Container<T> {
    value: T;
    getValue(): T;
}

// Call signature
interface Callable {
    (x: number): number;
}

// Construct signature
interface Constructable {
    new (name: string): Person;
}

// Type aliases
type StringOrNumber = string | number;
type ID = string | number;

// Function type
type BinaryOp = (a: number, b: number) => number;

// Tuple type
type Pair = [string, number];

// Generic type alias
type Wrapper<T> = T | null;

// Utility types usage
type PartialPerson = Partial<Person>;
type RequiredConfig = Required<Config>;

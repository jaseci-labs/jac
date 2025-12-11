// Decorators TypeScript fixture (Stage 2)

// Simple decorator
function sealed(constructor: Function) {
    Object.seal(constructor);
}

// Property decorator
function readonly(target: any, key: string) {
    console.log("readonly: " + key);
}

// Method decorator
function logged(target: any, key: string, descriptor: PropertyDescriptor) {
    console.log("logged: " + key);
}

// Class with decorators
@sealed
class DecoratedClass {
    @readonly
    name: string;

    constructor(name: string) {
        this.name = name;
    }

    @logged
    greet(): string {
        return "Hello, " + this.name;
    }
}

// Multiple decorators on class
@sealed
class MultiDecorated {
    value: number;
}

// Another decorated class
@sealed
class AnotherClass {
    @readonly
    id: number;
}

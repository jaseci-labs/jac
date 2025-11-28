// Simple TypeScript fixture for basic parsing tests

const message: string = "Hello, TypeScript!";

function greet(name: string): string {
    return "Hello, " + name;
}

class Person {
    name: string;

    constructor(name: string) {
        this.name = name;
    }
}

interface Greeting {
    message: string;
}

type ID = string | number;

enum Status {
    Active,
    Inactive,
}

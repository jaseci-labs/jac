// TypeScript utility module for testing cross-language type checking

export const VERSION: string = "1.0.0";

export function greet(name: string): string {
    return `Hello, ${name}!`;
}

export function add(a: number, b: number): number {
    return a + b;
}

export class Calculator {
    value: number;

    constructor(initialValue: number) {
        this.value = initialValue;
    }

    add(n: number): Calculator {
        this.value += n;
        return this;
    }

    getValue(): number {
        return this.value;
    }
}

export interface Person {
    name: string;
    age: number;
}

export type ID = string | number;

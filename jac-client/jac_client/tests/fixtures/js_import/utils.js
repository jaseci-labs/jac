// JavaScript utility functions for testing JS imports in Jac

export function formatMessage(name) {
    return `Hello, ${name}!`;
}

export function calculateSum(a, b) {
    return a + b;
}

export const JS_CONSTANT = "Imported from JavaScript";

export class MessageFormatter {
    constructor(prefix) {
        this.prefix = prefix;
    }

    format(text) {
        return `${this.prefix}: ${text}`;
    }
}

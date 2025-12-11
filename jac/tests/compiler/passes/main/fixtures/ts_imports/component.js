// JavaScript module for testing cross-language type checking

export const theme = "dark";
export const version = 2;

export function render(element) {
    console.log("Rendering:", element);
}

export class Component {
    constructor(name) {
        this.name = name;
    }

    getName() {
        return this.name;
    }
}

export const PI = 3.14159;
export function double(x) { return x * 2; }
export class Point {
    constructor(x, y) { this.x = x; this.y = y; }
    toString() { return `(${this.x},${this.y})`; }
}
export default "default-export";

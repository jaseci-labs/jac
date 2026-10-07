// Shared exports for ESM syntax comprehensive (ESM-X-001, live binding)
export let counter = 0;
export function inc() {
    counter++;
}
export function double(x) {
    return x * 2;
}
export class C {
    constructor(n) {
        this.n = n;
    }
}
export async function af() {
    return "af";
}
export default 99;

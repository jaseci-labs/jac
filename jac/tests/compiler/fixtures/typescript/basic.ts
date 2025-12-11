// Basic TypeScript fixture - variables and functions

// Variable declarations
var oldStyle = "var declaration";
let mutableVar = 42;
const immutableVar = "constant";

// Type annotations
let typedString: string = "hello";
let typedNumber: number = 123;
let typedBool: boolean = true;

// Function declarations
function simpleFunc() {
    return "simple";
}

function funcWithParams(a: string, b: number): string {
    return a + b.toString();
}

async function asyncFunc(): Promise<string> {
    return "async result";
}

function* generatorFunc() {
    yield 1;
    yield 2;
}

// Arrow functions (expression body)
const arrowSimple = () => "arrow";
const arrowWithParam = (x: number) => x * 2;
const arrowMultiParam = (a: string, b: string): string => a + b;

// Arrow function with block body - as function argument (works inside parens)
setTimeout(() => {
    console.log("delayed");
}, 1000);

// Async arrow (expression body)
const asyncArrow = async () => "async arrow";

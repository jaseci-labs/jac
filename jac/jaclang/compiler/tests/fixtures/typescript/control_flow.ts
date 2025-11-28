// Control Flow TypeScript fixture

// If statements
function checkValue(x: number): string {
    if (x > 0) {
        return "positive";
    } else if (x < 0) {
        return "negative";
    } else {
        return "zero";
    }
}

// For loop
function sumArray(arr: number[]): number {
    let sum = 0;
    for (let i = 0; i < arr.length; i++) {
        sum += arr[i];
    }
    return sum;
}

// For-of loop
function joinStrings(strings: string[]): string {
    let result = "";
    for (const s of strings) {
        result += s;
    }
    return result;
}

// For-in loop
function getKeys(obj: object): string[] {
    const keys: string[] = [];
    for (const key in obj) {
        keys.push(key);
    }
    return keys;
}

// While loop
function countdown(n: number): number[] {
    const result: number[] = [];
    while (n > 0) {
        result.push(n);
        n--;
    }
    return result;
}

// Do-while loop
function doCountdown(n: number): number[] {
    const result: number[] = [];
    do {
        result.push(n);
        n--;
    } while (n > 0);
    return result;
}

// Switch statement
function getDayName(day: number): string {
    switch (day) {
        case 0:
            return "Sunday";
        case 1:
            return "Monday";
        case 2:
            return "Tuesday";
        default:
            return "Unknown";
    }
}

// Try-catch-finally
function safeParse(json: string): object | null {
    try {
        return JSON.parse(json);
    } catch (e) {
        console.error("Parse error:", e);
        return null;
    } finally {
        console.log("Parsing complete");
    }
}

// Break and continue
function findFirst(arr: number[], target: number): number {
    let index = -1;
    for (let i = 0; i < arr.length; i++) {
        if (arr[i] === target) {
            index = i;
            break;
        }
    }
    return index;
}

function sumPositive(arr: number[]): number {
    let sum = 0;
    for (const n of arr) {
        if (n < 0) {
            continue;
        }
        sum += n;
    }
    return sum;
}

// Throw
function assertPositive(x: number): void {
    if (x <= 0) {
        throw new Error("Value must be positive");
    }
}

console.log("tla-before");
await Promise.reject(new Error("tla-boom"));
console.log("tla-after");

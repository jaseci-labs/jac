console.log("tla-before");
await new Promise((resolve, reject) => setTimeout(() => reject(new Error("tla-boom")), 5));
console.log("tla-after");

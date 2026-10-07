// ESM-A-001: top-level await before exports
await Promise.resolve(0);
export const afterTla = 3;

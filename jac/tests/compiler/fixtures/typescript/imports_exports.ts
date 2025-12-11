// Import and Export TypeScript fixture

// Various import forms
import defaultExport from "./module";
import * as namespace from "./module";
import { named1, named2 } from "./module";
import { original as alias } from "./module";
import defaultExport2, { named3 } from "./module";
import defaultExport3, * as ns from "./module";
import "./side-effect-module";

// Type-only imports
import type { SomeType } from "./types";
import type DefaultType from "./types";

// Export forms
export const exportedConst = 42;
export let exportedLet = "mutable";
export var exportedVar = true;

export function exportedFunction(): void {}

export class ExportedClass {
    value: number;
}

export interface ExportedInterface {
    name: string;
}

export type ExportedType = string | number;

export enum ExportedEnum {
    A,
    B,
}

// Re-exports
export { named1 } from "./module";
export { original as renamed } from "./module";
export * from "./module";
export * as reexportNs from "./module";

// Default export (simple value)
export default 42;

// Named exports block
export { exportedConst, exportedFunction };
export { exportedConst as aliasedExport };

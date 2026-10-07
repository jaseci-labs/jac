// ESM-I-004: side-effect module
var g =
    typeof globalThis !== "undefined"
        ? globalThis
        : typeof global !== "undefined"
          ? global
          : null;
if (g) {
    g.__esm_syntax_side_runs = (g.__esm_syntax_side_runs || 0) + 1;
}

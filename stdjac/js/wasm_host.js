// `@jac/wasm_host`: a `wasm` space in the page: its module, with its host's imports.
import * as $j from "./core.js";

// The host of the space whose export `exportFn` is: what the module imports.
export function bind_na_host(exportFn, host) {
    $j.bindWasmHost(exportFn.__jacSpace, host);
}

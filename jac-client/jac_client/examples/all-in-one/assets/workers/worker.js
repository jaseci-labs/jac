// worker.js
importScripts("https://cdn.jsdelivr.net/pyodide/v0.25.0/full/pyodide.js");

let pyodideReadyPromise = (async () => {
    self.pyodide = await loadPyodide();
    const response = await fetch("/workers/worker.py");
    const pyCode = await response.text();
    self.pyodide.runPython(pyCode);
})();

self.onmessage = async (event) => {
    await pyodideReadyPromise;
    self.pyodide.globals.set();
    const result = self.pyodide.runPython(`handle_message()`);
    self.postMessage(result);
};

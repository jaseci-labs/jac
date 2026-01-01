// worker.js
importScripts("https://cdn.jsdelivr.net/pyodide/v0.25.0/full/pyodide.js");

let pyodideReadyPromise = (async () => {
    self.pyodide = await loadPyodide();

    // Load Python file from assets
    const response = await fetch("/workers/worker.py");
    const pyCode = await response.text();

    // Run Python code (defines handle_message)
    self.pyodide.runPython(pyCode);
})();

self.onmessage = async (event) => {
    await pyodideReadyPromise;

    // Pass data to Python
    self.pyodide.globals.set();

    // Call Python function
    const result = self.pyodide.runPython(`handle_message()`);  

    // Send result back to React
    self.postMessage(result);
};

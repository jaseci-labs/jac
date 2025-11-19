
// ----------------------------------------------------------------------------
// Globals
// ----------------------------------------------------------------------------
var pyodide = null;
var breakpoints_buff = [];
var dbg = null;  // The debugger instance.

var sharedInts = null;
var continueExecution = false;

// Doc Use
const PLAYGROUND_PATH = "/playground";

// Development Use
// const PLAYGROUND_PATH = "";

const LOG_PATH = "/tmp/logs.log";


// ----------------------------------------------------------------------------
// Message passing protocol
// ----------------------------------------------------------------------------
onmessage = async (event) => {
  const data = event.data;
  switch (data.type) {

    case 'initialize':
      sharedInts = new Int32Array(data.sharedBuffer);
      importScripts("https://cdn.jsdelivr.net/pyodide/v0.28.0/full/pyodide.js");
      logMessage("Loading Pyodide...");
      pyodide = await loadPyodide();
      logMessage("Pyodide loaded.");
      const success = await loadPyodideAndJacLang();
      logMessage(`Pyodide and JacLang loaded: success=${success}`);
      self.postMessage({ type: 'initialized', success: success });
      break;

    case 'setBreakpoints':
      if (dbg) {
        dbg.clear_breakpoints();
        for (const bp of data.breakpoints) {
          dbg.set_breakpoint(bp);
          logMessage(`Breakpoint set at line ${bp}`);
        }
      } else {
        breakpoints_buff = data.breakpoints;
      }
      break;

    case 'startExecution':
      logMessage("Starting execution...");
      await startExecution(data.code);
      logMessage(`Execution finished`);
      self.postMessage({ type: 'execEnd' });
      break;

    case 'convertCode':
      logMessage(`Starting ${data.conversionType} conversion...`);
      await convertCode(data.conversionType, data.inputCode);
      logMessage(`Conversion finished`);
      break;

    case 'executePython':
      logMessage("Starting Python execution...");
      await executePython(data.code);
      logMessage(`Python execution finished`);
      self.postMessage({ type: 'execEnd' });
      break;

    default:
      console.error("Unknown message type:", data.type);
  }

};


// ----------------------------------------------------------------------------
// Utility functions
// ----------------------------------------------------------------------------
function logMessage(message) {
  console.log("[PythonThread] " + message);
}

async function readFileAsString(fileName) {
  const response = await fetch(PLAYGROUND_PATH + fileName);
  // const response = await fetch(fileName);
  return await response.text();
};

async function readFileAsBytes(fileName) {
  const response = await fetch(PLAYGROUND_PATH + fileName);
  // const response = await fetch(fileName);
  const buffer = await response.arrayBuffer();
  return new Uint8Array(buffer);
}


// ----------------------------------------------------------------------------
// Jaclang Initialization
// ----------------------------------------------------------------------------
async function loadPyodideAndJacLang() {
  try {
    await loadPythonResources(pyodide);
    const success = await checkJaclangLoaded(pyodide);

    // Run the debugger module.
    await pyodide.runPythonAsync(
      await readFileAsString("/python/debugger.py")
    );
    return success;

  } catch (error) {
    console.error("Error loading JacLang:", error);
    return false;
  }
}

async function loadPythonResources(pyodide) {
  const data = await readFileAsBytes("/jaclang.zip");
  await pyodide.FS.writeFile("/jaclang.zip", data);
  await pyodide.runPythonAsync(
    await readFileAsString("/python/extract_jaclang.py")
  );
}

async function checkJaclangLoaded(pyodide) {
  try {
    await pyodide.runPythonAsync(`from jaclang.cli.cli import run`);
    console.log("JacLang is available.");
    return true;
  } catch (error) {
    console.error("JacLang is not available:", error);
    return false;
  }
}


// ----------------------------------------------------------------------------
// Execution
// ----------------------------------------------------------------------------
function callbackBreak(dbg, line) {

  logMessage(`before ui: line=$${line}`);
  self.postMessage({ type: 'breakHit', line: line });

  continueExecution = false;
  while (!continueExecution) {
    Atomics.wait(sharedInts, 0, 0); // Block until the UI responds.
    sharedInts[0] = 0;  // Reset the shared memory.

    switch (sharedInts[1]) {
      case 1: // Clear breakpoints
        if (dbg) {
          dbg.clear_breakpoints();
          logMessage("Breakpoints cleared.");
        }
        break;

      case 2: // Set breakpoint
        const lineNumber = sharedInts[2];
        if (dbg) {
          dbg.set_breakpoint(lineNumber);
          logMessage(`Breakpoint set at line ${lineNumber}`);
        }
        break;

      case 3: // Continue execution
        dbg.do_continue();
        continueExecution = true;
        break;

      case 4: // Step over
        if (dbg) {
          dbg.do_step_over();
          logMessage("Stepped over.");
        }
        continueExecution = true;
        break;

      case 5: // Step into
        if (dbg) {
          dbg.do_step_into();
          logMessage("Stepped into.");
        }
        continueExecution = true;
        break;

      case 6: // Step out
        if (dbg) {
          dbg.do_step_out();
          logMessage("Stepped out.");
        }
        continueExecution = true;
        break;

      case 7: // Terminate execution
        if (dbg) {
          try {
            // Set a timeout for termination to avoid hanging
            setTimeout(() => {
              if (dbg) {
                dbg = null;
                logMessage("Forced cleanup after timeout.");
              }
            }, 1000);

            dbg.do_terminate();
            logMessage("Execution stopped.");
          } catch (error) {
            logMessage("Execution terminated (cleanup warning ignored).");
          } finally {
            // Ensure cleanup
            dbg = null;
          }
        }
        continueExecution = true;
        break;
    }
  }
  logMessage("after ui");
}

function callbackStdout(output) {
  self.postMessage({ type: 'stdout', output: output });
}

function callbackStderr(output) {
  self.postMessage({ type: 'stderr', output: output });
}

function callbackGraph(graph) {
  self.postMessage({ type: 'jacGraph', graph: graph });
}

async function startExecution(safeCode) {
  safeCode += `
with entry {
    print("<==START PRINT GRAPH==>");
    graph_json = printgraph(format='json');
    print(graph_json);
    print("<==END PRINT GRAPH==>");
}
  `;
  pyodide.globals.set('SAFE_CODE', safeCode);
  pyodide.globals.set('CB_STDOUT', callbackStdout);
  pyodide.globals.set('CB_STDERR', callbackStderr);

  dbg = pyodide.globals.get('Debugger')();
  dbg.cb_break = callbackBreak;
  dbg.cb_graph = callbackGraph;
  pyodide.globals.set('debugger', dbg);

  dbg.clear_breakpoints();
  for (const bp of breakpoints_buff) {
    dbg.set_breakpoint(bp);
    logMessage(`Breakpoint set at line ${bp}`);
  }

  // Run the main script
  logMessage("Execution started.");
  try {
    await pyodide.runPythonAsync(
      await readFileAsString("/python/main_playground.py")
    );
  } catch (error) {
    // Handle any remaining execution errors
    if (error.message && (
        error.message.includes("DebuggerTerminated") ||
        error.message.includes("terminated") ||
        error.message.includes("Not a directory") ||
        error.message.includes("No such file")
    )) {
      logMessage("Execution terminated by user.");
    } else {
      logMessage(`Execution error: ${error.message}`);
      throw error; // Re-throw if it's not a termination error
    }
  }
  logMessage("Execution finished.");
  dbg = null;
}

async function convertCode(conversionType, inputCode) {
  pyodide.globals.set('CONVERSION_TYPE', conversionType);
  pyodide.globals.set('INPUT_CODE', inputCode);
  pyodide.globals.set('CB_STDOUT', callbackStdout);
  pyodide.globals.set('CB_STDERR', callbackStderr);
  pyodide.globals.set('CB_RESULT', callbackConversionResult);

  // Run the conversion script
  logMessage("Conversion started.");
  try {
    await pyodide.runPythonAsync(
      await readFileAsString("/python/main_conversion.py")
    );
  } catch (error) {
    logMessage(`Conversion error: ${error.message}`);
    // Send error result back to main thread
    callbackConversionResult(`// Error during conversion:\n// ${error.message}`);
  }
  logMessage("Conversion finished.");
}

function callbackConversionResult(result) {
  self.postMessage({ type: 'conversionResult', result: result });
}

async function executePython(pythonCode) {
  pyodide.globals.set('PYTHON_CODE', pythonCode);
  pyodide.globals.set('CB_STDOUT', callbackStdout);
  pyodide.globals.set('CB_STDERR', callbackStderr);

  // Run the Python execution script
  logMessage("Python execution started.");
  try {
    await pyodide.runPythonAsync(
      await readFileAsString("/python/main_python_execution.py")
    );
  } catch (error) {
    logMessage(`Python execution error: ${error.message}`);
    // Send error to stderr callback
    callbackStderr(`Python execution error: ${error.message}`);
  }
  logMessage("Python execution finished.");
}

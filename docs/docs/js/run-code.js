let pyodideWorker = null;
let pyodideReady = false;
let pyodideInitPromise = null;
let monacoLoaded = false;
let monacoLoadPromise = null;
let sab = null;
const initializedBlocks = new WeakSet();

// Initialize Pyodide Worker
function initPyodideWorker() {
    if (pyodideWorker) return pyodideInitPromise;
    if (pyodideInitPromise) return pyodideInitPromise;

    const DATA_CAP = 4096;
    sab = new SharedArrayBuffer(8 + DATA_CAP);
    ctrl = new Int32Array(sab, 0, 2);
    dataBytes = new Uint8Array(sab, 8);

    pyodideWorker = new Worker("/js/pyodide-worker.js");
    pyodideInitPromise = new Promise((resolve, reject) => {
        pyodideWorker.onmessage = (event) => {
            if (event.data.type === "ready") {
                pyodideReady = true;
                resolve();
            }
        };
        pyodideWorker.onerror = (e) => reject(e);
    });
    pyodideWorker.postMessage({ type: "init", sab });
    return pyodideInitPromise;
}

// Run Jac Code in Worker
function runJacCodeInWorker(code, inputHandler) {
    return new Promise(async (resolve, reject) => {
        await initPyodideWorker();
        const handleMessage = async (event) => {
            let message;
            if (typeof event.data === "string") {
                message = JSON.parse(event.data);
            } else {
                message = event.data;
            }

            if (message.type === "streaming_output") {
                // Handle real-time output streaming
                const event = new CustomEvent('jacOutputUpdate', {
                    detail: { output: message.output, stream: message.stream }
                });
                document.dispatchEvent(event);
            } else if (message.type === "execution_complete") {
                pyodideWorker.removeEventListener("message", handleMessage);
                resolve("");
            } else if (message.type === "input_request") {
                console.log("Input requested");
                try {
                    const userInput = await inputHandler(message.prompt || "Enter input:");

                    const enc = new TextEncoder();
                    const bytes = enc.encode(userInput);
                    const n = Math.min(bytes.length, dataBytes.length);
                    dataBytes.set(bytes.subarray(0, n), 0);

                    Atomics.store(ctrl, 1, n);
                    Atomics.store(ctrl, 0, 1);
                    Atomics.notify(ctrl, 0, 1);
                } catch (error) {
                    pyodideWorker.removeEventListener("message", handleMessage);
                    reject(error);
                }
            } else if (message.type === "error") {
                pyodideWorker.removeEventListener("message", handleMessage);
                reject(message.error);
            }
        };
        pyodideWorker.addEventListener("message", handleMessage);
        pyodideWorker.postMessage({ type: "run", code });
    });
}

// Load Monaco Editor Globally
function loadMonacoEditor() {
    if (monacoLoaded) return monacoLoadPromise;
    if (monacoLoadPromise) return monacoLoadPromise;

    monacoLoadPromise = new Promise((resolve, reject) => {
        require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs' } });
        require(['vs/editor/editor.main'], function () {
            monacoLoaded = true;
            monaco.languages.register({ id: 'jac' });
            monaco.languages.setMonarchTokensProvider('jac', window.jaclangMonarchSyntax);

            fetch('/../playground/language-configuration.json')
                .then(resp => resp.json())
                .then(config => monaco.languages.setLanguageConfiguration('jac', config));
            monaco.editor.defineTheme('jac-theme', {
                base: 'vs-dark',
                inherit: true,
                rules: window.jacThemeRules,
                colors: window.jacThemeColors
            });
            monaco.editor.setTheme('jac-theme');
            resolve();
        }, reject);
    });
    console.log("Loading Monaco Editor...");
    return monacoLoadPromise;
}

// Setup Code Block with Monaco Editor
async function setupCodeBlock(div) {
    if (div._monacoInitialized) return;

    div._monacoInitialized = true;
    const originalCode = div.textContent.trim();

    div.innerHTML = `
        <div class="jac-code-loading" style="padding: 10px; font-style: italic; color: gray;">
            Loading editor...
        </div>
    `;

    await loadMonacoEditor();

    div.innerHTML = `
    <div class="jac-code" style="border: 1px solid #ccc;"></div>
    <button class="md-button md-button--primary run-code-btn">Run</button>
    <div class="input-dialog" style="display: none; background: linear-gradient(135deg, #2a2a2a 0%, #1e1e1e 100%); border: 1px solid #4a90e2; padding: 12px; margin: 8px 0; border-radius: 8px; box-shadow: 0 4px 16px rgba(0,0,0,0.2);">
        <div style="display: flex; gap: 10px; align-items: center;">
            <div class="input-prompt" style="color: #ffffff; font-family: 'Segoe UI', sans-serif; font-size: 13px; font-weight: 500; white-space: nowrap; min-width: fit-content;"></div>
            <input type="text" class="user-input" style="flex: 1; padding: 8px 12px; background: rgba(255,255,255,0.08); border: 1px solid #444; color: #ffffff; border-radius: 6px; font-family: 'Consolas', monospace; font-size: 13px; transition: all 0.2s ease; outline: none;" placeholder="Enter input...">
            <button class="submit-input" style="padding: 8px 14px; background: linear-gradient(135deg, #4a90e2 0%, #357abd 100%); color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 12px; transition: all 0.2s ease; box-shadow: 0 2px 8px rgba(74, 144, 226, 0.3); white-space: nowrap;">Submit</button>
            <button class="cancel-input" style="padding: 8px 14px; background: linear-gradient(135deg, #666 0%, #555 100%); color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 12px; transition: all 0.2s ease; box-shadow: 0 2px 8px rgba(0,0,0,0.2); white-space: nowrap;">Cancel</button>
        </div>
    </div>
    <pre class="code-output" style="display:none; white-space: pre-wrap; background: #1e1e1e; color: #d4d4d4; padding: 10px;"></pre>
    `;

    const container = div.querySelector(".jac-code");
    const runButton = div.querySelector(".run-code-btn");
    const outputBlock = div.querySelector(".code-output");
    const inputDialog = div.querySelector(".input-dialog");
    const inputPrompt = div.querySelector(".input-prompt");
    const userInput = div.querySelector(".user-input");
    const submitButton = div.querySelector(".submit-input");
    const cancelButton = div.querySelector(".cancel-input");

    const editor = monaco.editor.create(container, {
        value: originalCode || '# Write your Jac code here',
        language: 'jac',
        theme: 'jac-theme',
        scrollBeyondLastLine: false,
        scrollbar: {
            vertical: 'hidden',
            handleMouseWheel: false,
        },
        minimap: {
            enabled: false
        },
        automaticLayout: true,
        padding: {
            top: 10,
            bottom: 10
        }
    });

    // Update editor height based on content
    function updateEditorHeight() {
        const lineCount = editor.getModel().getLineCount();
        const lineHeight = editor.getOption(monaco.editor.EditorOption.lineHeight);
        const height = lineCount * lineHeight + 20;
        container.style.height = `${height}px`;
        editor.layout();
    }
    updateEditorHeight();
    editor.onDidChangeModelContent(updateEditorHeight);

    // Custom input handler function
    function createInputHandler() {
        return function(prompt) {
            return new Promise((resolve, reject) => {
                inputPrompt.textContent = prompt;
                inputDialog.style.display = "block";
                userInput.value = "";
                userInput.focus();

                const handleSubmit = () => {
                    const value = userInput.value;
                    inputDialog.style.display = "none";
                    // Add the input to output for visibility
                    outputBlock.textContent += `${prompt}${value}\n`;
                    outputBlock.scrollTop = outputBlock.scrollHeight;
                    resolve(value);
                    cleanup();
                };

                const handleCancel = () => {
                    inputDialog.style.display = "none";
                    reject(new Error("Input cancelled by user"));
                    cleanup();
                };

                const handleKeyPress = (e) => {
                    if (e.key === "Enter") {
                        e.preventDefault();
                        handleSubmit();
                    } else if (e.key === "Escape") {
                        e.preventDefault();
                        handleCancel();
                    }
                };

                const cleanup = () => {
                    submitButton.removeEventListener("click", handleSubmit);
                    cancelButton.removeEventListener("click", handleCancel);
                    userInput.removeEventListener("keypress", handleKeyPress);
                };

                submitButton.addEventListener("click", handleSubmit);
                cancelButton.addEventListener("click", handleCancel);
                userInput.addEventListener("keypress", handleKeyPress);
            });
        };
    }

    runButton.addEventListener("click", async () => {
        outputBlock.style.display = "block";
        outputBlock.textContent = "";
        inputDialog.style.display = "none";

        if (!pyodideReady) {
            outputBlock.textContent = "Loading Jac runner...";
            await initPyodideWorker();
            outputBlock.textContent = "";
        }

        // Listen for streaming output updates
        const outputHandler = (event) => {
            const { output, stream } = event.detail;
            outputBlock.textContent += output;
            outputBlock.scrollTop = outputBlock.scrollHeight;
        };

        document.addEventListener('jacOutputUpdate', outputHandler);

        try {
            const codeToRun = editor.getValue();
            const inputHandler = createInputHandler();
            await runJacCodeInWorker(codeToRun, inputHandler);
        } catch (error) {
            outputBlock.textContent += `\nError: ${error}`;
        } finally {
            document.removeEventListener('jacOutputUpdate', outputHandler);
            inputDialog.style.display = "none";
        }
    });

    userInput.addEventListener('focus', () => {
        userInput.style.borderColor = '#4a90e2';
        userInput.style.boxShadow = '0 0 0 2px rgba(74, 144, 226, 0.15)';
        userInput.style.background = 'rgba(255,255,255,0.12)';
    });

    userInput.addEventListener('blur', () => {
        userInput.style.borderColor = '#444';
        userInput.style.boxShadow = 'none';
        userInput.style.background = 'rgba(255,255,255,0.08)';
    });

    submitButton.addEventListener('mouseenter', () => {
        submitButton.style.transform = 'translateY(-1px)';
        submitButton.style.boxShadow = '0 4px 12px rgba(74, 144, 226, 0.4)';
    });

    submitButton.addEventListener('mouseleave', () => {
        submitButton.style.transform = 'translateY(0)';
        submitButton.style.boxShadow = '0 2px 8px rgba(74, 144, 226, 0.3)';
    });

    cancelButton.addEventListener('mouseenter', () => {
        cancelButton.style.transform = 'translateY(-1px)';
        cancelButton.style.background = 'linear-gradient(135deg, #777 0%, #666 100%)';
    });

    cancelButton.addEventListener('mouseleave', () => {
        cancelButton.style.transform = 'translateY(0)';
        cancelButton.style.background = 'linear-gradient(135deg, #666 0%, #555 100%)';
    });
}

// Lazy load code blocks using Intersection Observer
const lazyObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const div = entry.target;
            if (!initializedBlocks.has(div)) {
                setupCodeBlock(div);
                initializedBlocks.add(div);
                lazyObserver.unobserve(div);
            }
        }
    });
}, {
    root: null,
    rootMargin: "0px",
    threshold: 0.1
});

// Observe all uninitialized code blocks
function observeUninitializedCodeBlocks() {
    document.querySelectorAll('.code-block').forEach((block) => {
        if (!initializedBlocks.has(block)) {
            lazyObserver.observe(block);
        }
    });
}

const domObserver = new MutationObserver(() => {
    observeUninitializedCodeBlocks();
});

domObserver.observe(document.body, {
    childList: true,
    subtree: true
});

// Initialize on DOMContentLoaded
document.addEventListener("DOMContentLoaded", async () => {
    observeUninitializedCodeBlocks();
    initPyodideWorker();
});

// Add nav link mutation observer for playground links
document.addEventListener("DOMContentLoaded", function () {
    const observer = new MutationObserver(() => {
        const links = document.querySelectorAll("nav a[href='/playground/']");
        links.forEach(link => {
            link.setAttribute("target", "_blank");
            link.setAttribute("rel", "noopener");
        });
    });

    observer.observe(document.body, { childList: true, subtree: true });
});

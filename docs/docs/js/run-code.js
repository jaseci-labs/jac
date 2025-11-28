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

function executeJacCodeInWorker(code, inputHandler, commandType = "run") {
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
                // handle DOT graph output
            } else if (message.type === "dot") {
                const event = new CustomEvent('jacDotOutput', { detail: { dot: message.dot }});
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
        pyodideWorker.postMessage({ type: commandType, code });
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
    <div class="button-container" style="display: flex; gap: 8px;">
        <button class="md-button md-button--primary run-code-btn">Run</button>
        <button class="md-button md-button--primary serve-code-btn" style="background: linear-gradient(90deg, #0288d1 0%, #03a9f4 100%);">Serve</button>
        <button class="md-button md-button--primary dot-code-btn" style="background: linear-gradient(90deg, #b859e0ff 0%, #df76f1ff 100%);">Graph</button>
    </div>
    <div class="input-dialog" style="display: none; background: linear-gradient(135deg, #2a2a2a 0%, #1e1e1e 100%); border: 1px solid #4a90e2; padding: 12px; margin: 8px 0; border-radius: 8px; box-shadow: 0 4px 16px rgba(0,0,0,0.2);">
        <div style="display: flex; gap: 10px; align-items: center;">
            <div class="input-prompt" style="color: #ffffff; font-family: 'Segoe UI', sans-serif; font-size: 13px; font-weight: 500; white-space: nowrap; min-width: fit-content;"></div>
            <input type="text" class="user-input" style="flex: 1; padding: 8px 12px; background: rgba(255,255,255,0.08); border: 1px solid #444; color: #ffffff; border-radius: 6px; font-family: 'Consolas', monospace; font-size: 13px; transition: all 0.2s ease; outline: none;" placeholder="Enter input...">
            <button class="submit-input" style="padding: 8px 14px; background: linear-gradient(135deg, #4a90e2 0%, #357abd 100%); color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 12px; transition: all 0.2s ease; box-shadow: 0 2px 8px rgba(74, 144, 226, 0.3); white-space: nowrap;">Submit</button>
            <button class="cancel-input" style="padding: 8px 14px; background: linear-gradient(135deg, #666 0%, #555 100%); color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; font-size: 12px; transition: all 0.2s ease; box-shadow: 0 2px 8px rgba(0,0,0,0.2); white-space: nowrap;">Cancel</button>
        </div>
    </div>
    <pre class="code-output" style="display:none; white-space: pre-wrap; background: #1e1e1e; color: #d4d4d4; padding: 10px;"></pre>
    <div class="graph-container" style="display:none; margin-top:12px; border-radius:8px; overflow:auto; background:#ffffff; padding:4px; height:340px; max-height:800px;"></div>
    `;

    const container = div.querySelector(".jac-code");
    const runButton = div.querySelector(".run-code-btn");
    const serveButton = div.querySelector(".serve-code-btn");
    const dotButton = div.querySelector(".dot-code-btn");
    const graphContainer = div.querySelector(".graph-container");
    const outputBlock = div.querySelector(".code-output");
    const inputDialog = div.querySelector(".input-dialog");
    const inputPrompt = div.querySelector(".input-prompt");
    const userInput = div.querySelector(".user-input");
    const submitButton = div.querySelector(".submit-input");
    const cancelButton = div.querySelector(".cancel-input");

    // Handle button visibility based on classnames
    serveButton.style.display = 'none';
    dotButton.style.display = 'none';
    if (div.classList.contains('serve-only')) {
        runButton.style.display = 'none';
        serveButton.style.display = 'inline-block';
    } else if (div.classList.contains('run-serve')) {
        serveButton.style.display = 'inline-block';
    } else if (div.classList.contains('run-dot')) {
        dotButton.style.display = 'inline-block';
    } else if (div.classList.contains('serve-dot')) {
        runButton.style.display = 'none';
        serveButton.style.display = 'inline-block';
        dotButton.style.display = 'inline-block';
    } else if (div.classList.contains('run-dot-serve')) {
        dotButton.style.display = 'inline-block';
        serveButton.style.display = 'inline-block';
    }

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

    function decodeHtmlEntities(str) {
    // handles &amp;, &#x27;, etc.
    const txt = document.createElement("textarea");
    txt.innerHTML = str;
    return txt.value;
    }

    function renderDotToGraph(dotText) {
        const decoded = decodeHtmlEntities(dotText || "");
        if (!decoded.trim()) { graphContainer.style.display = "none"; return; }
        if (typeof Viz === "undefined") { graphContainer.textContent = "Graph rendering library not loaded."; graphContainer.style.display = "block"; return; }

        const viz = new Viz();
        viz.renderSVGElement(decoded)
            .then(svgEl => {
                // reset container
                graphContainer.innerHTML = "";
                graphContainer.style.display = "block";
                graphContainer.style.position = graphContainer.style.position || "relative";

                // ensure SVG is measurable
                svgEl.style.display = "block";
                svgEl.style.maxWidth = "none";
                svgEl.style.maxHeight = "none";

                // temporary measure
                const measureWrap = document.createElement("div");
                measureWrap.style.cssText = "position:absolute;visibility:hidden;pointer-events:none;";
                measureWrap.appendChild(svgEl);
                graphContainer.appendChild(measureWrap);

                // determine intrinsic svg size
                let svgW = NaN, svgH = NaN;
                const vb = svgEl.getAttribute("viewBox");
                if (vb) {
                    const parts = vb.trim().split(/\s+/);
                    if (parts.length === 4) { svgW = parseFloat(parts[2]) || svgW; svgH = parseFloat(parts[3]) || svgH; }
                }
                try {
                    if (!isFinite(svgW) || !isFinite(svgH)) {
                        const bbox = svgEl.getBBox();
                        svgW = svgW || bbox.width; svgH = svgH || bbox.height;
                    }
                } catch (e) {
                    const wa = svgEl.getAttribute("width"), ha = svgEl.getAttribute("height");
                    svgW = svgW || (wa ? parseFloat(String(wa).replace("px", "")) : 800);
                    svgH = svgH || (ha ? parseFloat(String(ha).replace("px", "")) : 400);
                }
                measureWrap.remove();
                if (!isFinite(svgW) || svgW <= 0) svgW = 800;
                if (!isFinite(svgH) || svgH <= 0) svgH = 600;

                // container visible area
                const containerW = Math.max(100, graphContainer.clientWidth || 800);
                const containerH = Math.max(100, graphContainer.clientHeight || 400);

                // compute fit scale so SVG fills available without cropping
                const fitScale = Math.min(containerW / svgW, containerH / svgH);
                const displayW = Math.max(1, Math.round(svgW * fitScale));
                const displayH = Math.max(1, Math.round(svgH * fitScale));

                // set SVG attributes so it fits perfectly
                svgEl.setAttribute("width", displayW);
                svgEl.setAttribute("height", displayH);
                svgEl.setAttribute("preserveAspectRatio", "xMidYMid meet");
                svgEl.style.display = "block";
                svgEl.style.transformOrigin = "0 0";

                // build wrapper and controls
                const wrapper = document.createElement("div");
                wrapper.className = "viz-viewport";
                wrapper.appendChild(svgEl);

                const controls = document.createElement("div");
                controls.className = "graph-controls";
                const resetBtn = document.createElement("button");
                resetBtn.type = "button";
                resetBtn.className = "graph-reset-btn";
                resetBtn.textContent = "Reset";
                controls.appendChild(resetBtn);

                graphContainer.appendChild(wrapper);
                graphContainer.appendChild(controls);

                // pan/zoom state (transforms applied to svg)
                let scale = 1, translate = { x: 0, y: 0 }, isPanning = false, start = {}, startT = {};
                const setTransform = () => svgEl.style.transform = `translate(${translate.x}px, ${translate.y}px) scale(${scale})`;

                const onWheel = (ev) => {
                    ev.preventDefault();
                    const rect = wrapper.getBoundingClientRect();
                    const cx = ev.clientX - rect.left, cy = ev.clientY - rect.top;
                    const prev = scale;
                    scale = Math.max(0.2, Math.min(6, scale * (ev.deltaY > 0 ? 0.9 : 1.1)));
                    const px = (cx - translate.x) / prev, py = (cy - translate.y) / prev;
                    translate.x -= px * (scale - prev); translate.y -= py * (scale - prev);
                    setTransform();
                };

                const onPointerDown = (ev) => {
                    if (ev.button !== 0) return;
                    isPanning = true; wrapper.setPointerCapture(ev.pointerId); wrapper.style.cursor = "grabbing";
                    start = { x: ev.clientX, y: ev.clientY }; startT = { x: translate.x, y: translate.y };
                };
                const onPointerMove = (ev) => {
                    if (!isPanning) return;
                    translate.x = startT.x + (ev.clientX - start.x); translate.y = startT.y + (ev.clientY - start.y);
                    setTransform();
                };
                const onPointerUp = (ev) => { if (!isPanning) return; isPanning = false; try { wrapper.releasePointerCapture(ev.pointerId); } catch {} wrapper.style.cursor = "grab"; };

                resetBtn.addEventListener("click", (e) => { e.stopPropagation(); scale = 1; translate = { x: 0, y: 0 }; setTransform(); });

                // attach interactions
                wrapper.addEventListener("wheel", onWheel, { passive: false });
                wrapper.addEventListener("pointerdown", onPointerDown);
                wrapper.addEventListener("pointermove", onPointerMove);
                wrapper.addEventListener("pointerup", onPointerUp);
                wrapper.addEventListener("pointercancel", onPointerUp);

                // initial transform (SVG already sized to fit; transforms start neutral)
                setTransform();
            })
            .catch(err => {
                console.error("Viz render error:", err);
                graphContainer.style.display = "block";
                graphContainer.textContent = "Failed to render graph. DOT:\n\n" + decoded;
            });
    }

    function createButtonHandler(commandType, initialMessage = "") {
        return async () => {
            outputBlock.style.display = "block";
            outputBlock.textContent = initialMessage;
            inputDialog.style.display = "none";

            // clear any previous graph immediately so repeated clicks look fresh
            try { graphContainer.innerHTML = ""; graphContainer.style.display = "none"; } catch (e) { /* ignore */ }

            // disable buttons while this invocation runs to avoid concurrent runs
            runButton.disabled = true;
            serveButton.disabled = true;
            dotButton.disabled = true;

            if (!pyodideReady) {
                const loadingMsg = "Loading Jac runner...";
                outputBlock.textContent += loadingMsg + (initialMessage ? "\n" : "");
                await initPyodideWorker();
                outputBlock.textContent = outputBlock.textContent.replace(loadingMsg + (initialMessage ? "\n" : ""), "");
            }

            // show the run's output for graph,
            let showOutputs = true;

            const outputHandler = (event) => {
                if (!showOutputs) return;               // suppress when requested
                const { output, stream } = event.detail;
                outputBlock.textContent += output;
                outputBlock.scrollTop = outputBlock.scrollHeight;
            };

            const dotHandler = (event) => {
                graphContainer.innerHTML = "";
                renderDotToGraph(event.detail.dot);
            };

            document.addEventListener('jacOutputUpdate', outputHandler);
            document.addEventListener('jacDotOutput', dotHandler);

            try {
                const codeToRun = editor.getValue();
                const inputHandler = createInputHandler();
                if (commandType === "dot") {
                    await executeJacCodeInWorker(codeToRun, inputHandler, "run");
                    showOutputs = false;     // avoid duplicate outputs
                    await executeJacCodeInWorker(codeToRun, inputHandler, "dot");
                } else {
                    await executeJacCodeInWorker(codeToRun, inputHandler, commandType);
                }
            } catch (error) {
                outputBlock.textContent += `\nError: ${error}`;
            } finally {
                document.removeEventListener('jacDotOutput', dotHandler);
                document.removeEventListener('jacOutputUpdate', outputHandler);
                inputDialog.style.display = "none";
                // re-enable buttons
                runButton.disabled = false;
                serveButton.disabled = false;
                dotButton.disabled = false;
            }
        };
    }

    runButton.addEventListener("click", createButtonHandler("run"));
    serveButton.addEventListener("click", createButtonHandler("serve", "Starting serve mode...\n"));
    dotButton.addEventListener("click", createButtonHandler("dot", "Generating graph...\n"));

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

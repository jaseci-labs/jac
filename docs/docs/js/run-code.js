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
                const event = new CustomEvent('jacOutputUpdate', {
                    detail: { output: message.output, stream: message.stream }
                });
                document.dispatchEvent(event);
            } else if (message.type === "dot") {
                const event = new CustomEvent('jacDotOutput', { detail: { dot: message.dot }});
                document.dispatchEvent(event);
            } else if (message.type === "execution_complete") {
                pyodideWorker.removeEventListener("message", handleMessage);
                resolve("");
            } else if (message.type === "input_request") {
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
    return monacoLoadPromise;
}

// SVG icons
const ICONS = {
    run: '<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>',
    serve: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>',
    graph: '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><circle cx="12" cy="5" r="2.5"/><circle cx="5" cy="19" r="2.5"/><circle cx="19" cy="19" r="2.5"/><line x1="12" y1="7.5" x2="5" y2="16.5"/><line x1="12" y1="7.5" x2="19" y2="16.5"/></svg>',
};

// Setup Code Block with Monaco Editor
async function setupCodeBlock(div) {
    if (div._monacoInitialized) return;
    div._monacoInitialized = true;
    const originalCode = div.textContent.trim();

    div.innerHTML = `<div class="jcb-loading"><div class="jcb-loading-bar"></div></div>`;

    await loadMonacoEditor();

    div.innerHTML = `
    <div class="jcb-editor-wrap">
        <div class="jac-code"></div>
        <div class="jcb-progress" style="display:none;"></div>
    </div>
    <div class="jcb-actions">
        <button class="jcb-btn jcb-btn--run run-code-btn">${ICONS.run} Run</button>
        <button class="jcb-btn jcb-btn--serve serve-code-btn">${ICONS.serve} Serve</button>
        <button class="jcb-btn jcb-btn--graph dot-code-btn">${ICONS.graph} Graph</button>
    </div>
    <div class="jcb-output-wrap" style="display:none;">
        <pre class="code-output"></pre>
    </div>
    <div class="jcb-input-dialog" style="display:none;">
        <div class="jcb-input-row">
            <div class="input-prompt"></div>
            <input type="text" class="user-input" placeholder="Enter input...">
            <button class="jcb-input-submit submit-input">Submit</button>
            <button class="jcb-input-cancel cancel-input">Cancel</button>
        </div>
    </div>
    <div class="graph-container" style="display:none;"></div>
    `;

    const container = div.querySelector(".jac-code");
    const runButton = div.querySelector(".run-code-btn");
    const serveButton = div.querySelector(".serve-code-btn");
    const dotButton = div.querySelector(".dot-code-btn");
    const graphContainer = div.querySelector(".graph-container");
    const outputWrap = div.querySelector(".jcb-output-wrap");
    const outputBlock = div.querySelector(".code-output");
    const progressBar = div.querySelector(".jcb-progress");
    const inputDialog = div.querySelector(".jcb-input-dialog");
    const inputPrompt = div.querySelector(".input-prompt");
    const userInput = div.querySelector(".user-input");
    const submitButton = div.querySelector(".submit-input");
    const cancelButton = div.querySelector(".cancel-input");

    // Handle button visibility based on classnames
    serveButton.style.display = 'none';
    dotButton.style.display = 'none';
    if (div.classList.contains('serve-only')) {
        runButton.style.display = 'none';
        serveButton.style.display = 'inline-flex';
    } else if (div.classList.contains('run-serve')) {
        serveButton.style.display = 'inline-flex';
    } else if (div.classList.contains('run-dot')) {
        dotButton.style.display = 'inline-flex';
    } else if (div.classList.contains('serve-dot')) {
        runButton.style.display = 'none';
        serveButton.style.display = 'inline-flex';
        dotButton.style.display = 'inline-flex';
    } else if (div.classList.contains('run-dot-serve')) {
        dotButton.style.display = 'inline-flex';
        serveButton.style.display = 'inline-flex';
    }

    const editor = monaco.editor.create(container, {
        value: originalCode || '# Write your Jac code here',
        language: 'jac',
        theme: 'jac-theme',
        scrollBeyondLastLine: false,
        scrollbar: { vertical: 'hidden', handleMouseWheel: false },
        minimap: { enabled: false },
        automaticLayout: true,
        padding: { top: 10, bottom: 10 },
        fontSize: 13.5,
        lineHeight: 20,
        renderLineHighlight: 'none',
        overviewRulerLanes: 0,
        hideCursorInOverviewRuler: true,
        overviewRulerBorder: false,
    });

    function updateEditorHeight() {
        const lineCount = editor.getModel().getLineCount();
        const lineHeight = editor.getOption(monaco.editor.EditorOption.lineHeight);
        const height = lineCount * lineHeight + 20;
        container.style.height = `${height}px`;
        editor.layout();
    }
    updateEditorHeight();
    editor.onDidChangeModelContent(updateEditorHeight);

    // State helpers
    function setRunning() {
        progressBar.style.display = "block";
        div.classList.add("jcb-running");
        runButton.disabled = true;
        serveButton.disabled = true;
        dotButton.disabled = true;
    }

    function setIdle() {
        progressBar.style.display = "none";
        div.classList.remove("jcb-running");
        runButton.disabled = false;
        serveButton.disabled = false;
        dotButton.disabled = false;
    }

    // Input handler
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
                    if (e.key === "Enter") { e.preventDefault(); handleSubmit(); }
                    else if (e.key === "Escape") { e.preventDefault(); handleCancel(); }
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
                graphContainer.innerHTML = "";
                graphContainer.style.display = "block";
                graphContainer.style.position = graphContainer.style.position || "relative";

                svgEl.style.display = "block";
                svgEl.style.maxWidth = "none";
                svgEl.style.maxHeight = "none";

                const measureWrap = document.createElement("div");
                measureWrap.style.cssText = "position:absolute;visibility:hidden;pointer-events:none;";
                measureWrap.appendChild(svgEl);
                graphContainer.appendChild(measureWrap);

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

                const containerW = Math.max(100, graphContainer.clientWidth || 800);
                const containerH = Math.max(100, graphContainer.clientHeight || 400);
                const fitScale = Math.min(containerW / svgW, containerH / svgH);
                const displayW = Math.max(1, Math.round(svgW * fitScale));
                const displayH = Math.max(1, Math.round(svgH * fitScale));

                svgEl.setAttribute("width", displayW);
                svgEl.setAttribute("height", displayH);
                svgEl.setAttribute("preserveAspectRatio", "xMidYMid meet");
                svgEl.style.display = "block";
                svgEl.style.transformOrigin = "0 0";

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

                wrapper.addEventListener("wheel", onWheel, { passive: false });
                wrapper.addEventListener("pointerdown", onPointerDown);
                wrapper.addEventListener("pointermove", onPointerMove);
                wrapper.addEventListener("pointerup", onPointerUp);
                wrapper.addEventListener("pointercancel", onPointerUp);

                setTransform();
            })
            .catch(err => {
                console.error("Viz render error:", err);
                graphContainer.style.display = "block";
                graphContainer.textContent = "Failed to render graph. DOT:\n\n" + decoded;
            });
    }

    function createButtonHandler(commandType) {
        return async () => {
            outputBlock.textContent = "";
            outputWrap.style.display = "block";
            inputDialog.style.display = "none";
            try { graphContainer.innerHTML = ""; graphContainer.style.display = "none"; } catch (e) { /* ignore */ }

            setRunning();

            if (!pyodideReady) {
                await initPyodideWorker();
            }

            const outputHandler = (event) => {
                const { output } = event.detail;
                if (output === ">>> Graph content saved to /home/pyodide/temp.dot") return;
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
                await executeJacCodeInWorker(codeToRun, inputHandler, commandType);
            } catch (error) {
                outputBlock.textContent += `\nError: ${error}`;
            } finally {
                document.removeEventListener('jacDotOutput', dotHandler);
                document.removeEventListener('jacOutputUpdate', outputHandler);
                inputDialog.style.display = "none";
                setIdle();
            }
        };
    }

    runButton.addEventListener("click", createButtonHandler("run"));
    serveButton.addEventListener("click", createButtonHandler("serve"));
    dotButton.addEventListener("click", createButtonHandler("dot"));
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

document.addEventListener("DOMContentLoaded", async () => {
    observeUninitializedCodeBlocks();
    initPyodideWorker();
});

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

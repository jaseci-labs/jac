import from react { useRef, useCallback }
import from "..services.ideService" { ideBatchWrite }

def _isTauri() -> bool {
    return Boolean(globalThis.__TAURI_INTERNALS__);
}

def _tauriInvoke(cmd: str, args: Any) -> Any {
    return globalThis.__TAURI_INTERNALS__.invoke(cmd, args);
}

async def _tauriPickFolder() -> Any {
    selected = await _tauriInvoke("plugin:dialog|open", {
        "directory": True,
        "multiple": False,
        "recursive": False,
        "title": "Select Folder"
    });
    return selected;
}

async def _tauriReadDir(dirPath: str) -> Any {
    entries = await _tauriInvoke("plugin:fs|read_dir", {"path": dirPath});
    return entries;
}

async def _tauriReadTextFile(filePath: str) -> Any {
    content = await _tauriInvoke("plugin:fs|read_text_file", {"path": filePath});
    return content;
}

async def _tauriScanFolder(dirPath: str, basePath: str, collected: list, skippedCount: Any) -> None {
    try {
        entries = await _tauriReadDir(dirPath);
    } except Exception as _e {
        return;
    }
    i = 0;
    while i < entries.length {
        item = entries[i];
        i = i + 1;
        name = item.name;
        if not name { continue; }
        if item.isDirectory {
            if _shouldSkipDir(name) {
                skippedCount.value = skippedCount.value + 1;
                continue;
            }
            childBase = (basePath + "/" + name if basePath else name);
            childPath = dirPath + "/" + name;
            await _tauriScanFolder(childPath, childBase, collected, skippedCount);
        } else {
            if _shouldSkipFile(name) {
                skippedCount.value = skippedCount.value + 1;
                continue;
            }
            relPath = (basePath + "/" + name if basePath else name);
            fullPath = dirPath + "/" + name;
            try {
                content = await _tauriReadTextFile(fullPath);
                collected.push({"path": relPath, "content": content});
            } except Exception as _e2 {
                skippedCount.value = skippedCount.value + 1;
            }
        }
    }
}

glob _SKIP_DIRS: Any = {
    ".git": True, "node_modules": True, "__pycache__": True,
    ".jac": True, ".jac-ide": True, "__jac_gen__": True,
    "dist": True, "build": True, ".next": True
};
glob _SKIP_FILES: Any = {".DS_Store": True, "Thumbs.db": True, ".gitkeep": True};
glob _SKIP_EXTS: Any = {
    ".exe": True, ".dll": True, ".so": True, ".dylib": True,
    ".pyc": True, ".pyo": True, ".class": True, ".o": True,
    ".jacpack": True, ".wasm": True
};
glob _BINARY_FILE_EXTS: Any = {
    ".png": True, ".jpg": True, ".jpeg": True, ".gif": True, ".ico": True, ".webp": True,
    ".bmp": True, ".tiff": True, ".tif": True,
    ".woff": True, ".woff2": True, ".ttf": True, ".eot": True, ".otf": True,
    ".zip": True, ".tar": True, ".gz": True, ".bz2": True, ".7z": True, ".rar": True,
    ".pdf": True, ".mp3": True, ".mp4": True, ".wav": True, ".avi": True, ".webm": True, ".ogg": True
};
glob _MAX_FILE_SIZE: int = 2097152;

def _shouldSkipDir(name: str) -> bool {
    return Boolean(_SKIP_DIRS[name]);
}

def _shouldSkipFile(name: str) -> bool {
    if Boolean(_SKIP_FILES[name]) { return True; }
    lower = name.toLowerCase();
    dotIdx = lower.lastIndexOf(".");
    if dotIdx >= 0 {
        ext = lower.substring(dotIdx);
        if Boolean(_SKIP_EXTS[ext]) { return True; }
    }
    return False;
}

def _isBinaryFile(name: str) -> bool {
    lower = name.toLowerCase();
    dotIdx = lower.lastIndexOf(".");
    if dotIdx >= 0 {
        ext = lower.substring(dotIdx);
        return Boolean(_BINARY_FILE_EXTS[ext]);
    }
    return False;
}

def _readAllEntries(reader: Any) -> Any {
    return Reflect.construct(Promise, [lambda(resolve: Any, reject: Any) {
        allEntries: list = [];
        resolveFn = resolve;
        rejectFn = reject;
        def readBatch() -> None {
            reader.readEntries(
                lambda(entries: Any) {
                    if not entries or entries.length == 0 {
                        resolveFn.call(None, allEntries);
                    } else {
                        for e in entries {
                            allEntries.push(e);
                        }
                        readBatch();
                    }
                },
                lambda(err: Any) { rejectFn.call(None, err); }
            );
        }
        readBatch();
    }]);
}

def _collectEntries(fsEntry: Any, basePath: str, collected: list, skippedCount: Any) -> Any {
    return Reflect.construct(Promise, [lambda(resolve: Any, _reject: Any) {
        resolveFn = resolve;
        if fsEntry.isFile {
            if _shouldSkipFile(fsEntry.name) {
                skippedCount.value = skippedCount.value + 1;
                resolveFn.call(None, None);
            } else {
                fsEntry.file(
                    lambda(f: Any) {
                        if f.size > _MAX_FILE_SIZE {
                            skippedCount.value = skippedCount.value + 1;
                        } else {
                            path = (basePath + "/" + fsEntry.name if basePath else fsEntry.name);
                            collected.push({"file": f, "path": path});
                        }
                        resolveFn.call(None, None);
                    },
                    lambda(_err: Any) {
                        skippedCount.value = skippedCount.value + 1;
                        resolveFn.call(None, None);
                    }
                );
            }
        } elif fsEntry.isDirectory {
            if _shouldSkipDir(fsEntry.name) {
                skippedCount.value = skippedCount.value + 1;
                resolveFn.call(None, None);
            } else {
                dirPath = (basePath + "/" + fsEntry.name if basePath else fsEntry.name);
                reader = fsEntry.createReader();
                _readAllEntries(reader).then(lambda(entries: Any) {
                    promises: list = [];
                    for child in entries {
                        promises.push(_collectEntries(child, dirPath, collected, skippedCount));
                    }
                    Promise.all(promises).then(lambda(_: Any) {
                        resolveFn.call(None, None);
                    });
                });
            }
        } else {
            resolveFn.call(None, None);
        }
    }]);
}

glob _LARGE_FOLDER_THRESHOLD: int = 500;

def:pub useFolderUpload(projectId: str, onComplete: Any) -> Any {
    has isUploading: bool = False;
    has uploadPhase: str = "";
    has scannedCount: int = 0;
    has uploadedCount: int = 0;
    has totalCount: int = 0;
    has skippedCount: int = 0;
    has errorCount: int = 0;
    has progressPct: int = 0;
    has showConfirm: bool = False;
    has confirmWarning: str = "";

    fileInputRef = useRef(None);
    pendingRef = useRef(None);
    completeFn = onComplete;

    def reset() -> None {
        isUploading = False;
        uploadPhase = "";
        scannedCount = 0;
        uploadedCount = 0;
        totalCount = 0;
        skippedCount = 0;
        errorCount = 0;
        progressPct = 0;
        showConfirm = False;
        confirmWarning = "";
        pendingRef.current = None;
    }

    async def _executeUpload(collected: list, skipped: int) -> None {
        totalCount = collected.length;
        skippedCount = skipped;

        if collected.length == 0 {
            uploadPhase = "done";
            progressPct = 100;
            isUploading = False;
            return;
        }

        uploadPhase = "reading";
        progressPct = 30;
        payloads: list = [];
        for item in collected {
            try {
                if _isBinaryFile(item.file.name) {
                    arrayBuffer = await item.file.arrayBuffer();
                    uint8 = Reflect.construct(Uint8Array, [arrayBuffer]);
                    binaryString = Array.from(uint8).map(lambda b: Any -> Any { return String.fromCharCode(b); }).join("");
                    payloads.push({"path": item.path, "content": btoa(binaryString), "encoding": "base64"});
                } else {
                    text = await item.file.text();
                    payloads.push({"path": item.path, "content": text});
                }
            } except Exception as _e {
                skippedCount = skippedCount + 1;
            }
        }

        uploadPhase = "uploading";
        progressPct = 60;
        result = await ideBatchWrite(projectId, payloads);
        if result and result.success {
            uploadedCount = (result.written_count or 0);
            errorCount = (result.error_count or 0);
        } else {
            errorCount = payloads.length;
        }
        uploadPhase = "done";
        progressPct = 100;
        if completeFn {
            completeFn.call(None);
        }
        setTimeout(lambda { isUploading = False; }, 1500);
    }

    async def _doUpload(collected: list, skipped: int) -> None {
        count = collected.length;
        warning = "";
        if count >= _LARGE_FOLDER_THRESHOLD {
            warning = String(count) + " files found. Large uploads may take a while.";
        }
        if count > 0 {
            warning = (warning + " " if warning else "") + "Existing files with the same names will be overwritten.";
        }
        scannedCount = count;
        skippedCount = skipped;
        pendingRef.current = {"collected": collected, "skipped": skipped};
        confirmWarning = warning;
        showConfirm = True;
    }

    async def confirmUpload() -> None {
        showConfirm = False;
        pending = pendingRef.current;
        pendingRef.current = None;
        if not pending { return; }
        if pending.isTauri {
            await _doUploadPayloads(pending.payloads, pending.skipped);
        } else {
            await _executeUpload(pending.collected, pending.skipped);
        }
    }

    def cancelUpload() -> None {
        showConfirm = False;
        pendingRef.current = None;
        isUploading = False;
        uploadPhase = "";
        scannedCount = 0;
        skippedCount = 0;
    }

    async def _doUploadPayloads(payloads: list, skipped: int) -> None {
        totalCount = payloads.length;
        skippedCount = skipped;
        if payloads.length == 0 {
            uploadPhase = "done";
            progressPct = 100;
            isUploading = False;
            return;
        }
        uploadPhase = "uploading";
        progressPct = 60;
        result = await ideBatchWrite(projectId, payloads);
        if result and result.success {
            uploadedCount = (result.written_count or 0);
            errorCount = (result.error_count or 0);
        } else {
            errorCount = payloads.length;
        }
        uploadPhase = "done";
        progressPct = 100;
        if completeFn {
            completeFn.call(None);
        }
        setTimeout(lambda { isUploading = False; }, 1500);
    }

    uploadFromDataTransfer = useCallback(lambda(dataTransfer: Any, targetPath: Any) -> None {
        if isUploading or not projectId { return; }
        items = dataTransfer.items;
        if not items or items.length == 0 {
            if _isTauri() {
                _tauriUploadFolder(targetPath or "");
            }
            return;
        }

        entries: list = [];
        i = 0;
        while i < items.length {
            item = items[i];
            if item.webkitGetAsEntry {
                fsEnt = item.webkitGetAsEntry();
                if fsEnt { entries.push(fsEnt); }
            }
            i = i + 1;
        }
        if entries.length == 0 {
            if _isTauri() {
                _tauriUploadFolder(targetPath or "");
            }
            return;
        }

        basePath = targetPath or "";

        isUploading = True;
        uploadPhase = "scanning";
        progressPct = 10;
        collected: list = [];
        skippedObj = {"value": 0};

        promises: list = [];
        for ent in entries {
            promises.push(_collectEntries(ent, basePath, collected, skippedObj));
        }

        Promise.all(promises).then(lambda(_: Any) {
            scannedCount = collected.length;
            _doUpload(collected, skippedObj.value);
        });
    }, [projectId, isUploading]);

    async def _tauriUploadFolder(targetPath: str) -> None {
        if isUploading or not projectId { return; }
        try {
            folderPath = await _tauriPickFolder();
            if not folderPath { return; }
            isUploading = True;
            uploadPhase = "scanning";
            progressPct = 10;
            collected: list = [];
            skippedObj = {"value": 0};
            basePath = targetPath or "";
            await _tauriScanFolder(folderPath, basePath, collected, skippedObj);
            scannedCount = collected.length;
            count = collected.length;
            skippedVal = skippedObj.value;
            skippedCount = skippedVal;
            payloads: list = [];
            for item in collected {
                payloads.push({"path": item.path, "content": item.content});
            }
            warning = "";
            if count >= _LARGE_FOLDER_THRESHOLD {
                warning = String(count) + " files found. Large uploads may take a while.";
            }
            if count > 0 {
                warning = (warning + " " if warning else "") + "Existing files with the same names will be overwritten.";
            }
            pendingRef.current = {"payloads": payloads, "skipped": skippedVal, "isTauri": True};
            confirmWarning = warning;
            showConfirm = True;
        } except Exception as _e {
            isUploading = False;
            uploadPhase = "";
        }
    }

    def triggerFolderPicker() -> None {
        if _isTauri() {
            _tauriUploadFolder("");
            return;
        }
        if fileInputRef.current {
            fileInputRef.current.value = "";
            fileInputRef.current.click();
        }
    }

    handleFileInputChange = useCallback(lambda(e: Any) -> None {
        if isUploading or not projectId { return; }
        filesList = e.target.files;
        if not filesList or filesList.length == 0 { return; }

        isUploading = True;
        uploadPhase = "scanning";
        progressPct = 10;
        collected: list = [];
        skipped = 0;
        i = 0;
        while i < filesList.length {
            f = filesList[i];
            relPath = f.webkitRelativePath or f.name;
            parts = relPath.split("/");
            skipFile = False;
            j = 0;
            while j < parts.length - 1 {
                if _shouldSkipDir(parts[j]) {
                    skipFile = True;
                    break;
                }
                j = j + 1;
            }
            if not skipFile and _shouldSkipFile(parts[parts.length - 1]) {
                skipFile = True;
            }
            if not skipFile and f.size > _MAX_FILE_SIZE {
                skipFile = True;
            }
            if skipFile {
                skipped = skipped + 1;
            } else {
                cleanPath = parts.join("/");
                collected.push({"file": f, "path": cleanPath});
            }
            i = i + 1;
        }
        scannedCount = collected.length;
        _doUpload(collected, skipped);
    }, [projectId, isUploading]);

    return {
        "isUploading": isUploading,
        "uploadPhase": uploadPhase,
        "scannedCount": scannedCount,
        "uploadedCount": uploadedCount,
        "totalCount": totalCount,
        "skippedCount": skippedCount,
        "errorCount": errorCount,
        "progressPct": progressPct,
        "showConfirm": showConfirm,
        "confirmWarning": confirmWarning,
        "confirmUpload": confirmUpload,
        "cancelUpload": cancelUpload,
        "uploadFromDataTransfer": uploadFromDataTransfer,
        "triggerFolderPicker": triggerFolderPicker,
        "handleFileInputChange": handleFileInputChange,
        "fileInputRef": fileInputRef,
        "reset": reset
    };
}

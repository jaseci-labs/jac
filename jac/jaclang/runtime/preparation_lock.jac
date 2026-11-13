import threading;

glob PREPARATION_LOCK: threading.RLock = threading.RLock();

class SourcesChanged(RuntimeError) {}

class BuildFailed(RuntimeError) {}

import os;

import from pathlib { Path }

obj AndroidEnvironment {
    has java_home: Path,
        sdk_home: Path;

    def env -> dict[str, str];
}

def ensure_jdk -> Path;

def ensure_android -> AndroidEnvironment;

import socket;

glob PORT_RETRY_LIMIT: int = 10,
     ERRNO_ADDR_IN_USE_LINUX: int = 98,
     ERRNO_ADDR_IN_USE_MACOS: int = 48,
     ERRNO_ADDR_IN_USE_WINDOWS: int = 10048;


def find_available_port(
    start_port: int,
    max_retries: int = PORT_RETRY_LIMIT,
    skip_port: int = 0,
    strict: bool = False
) -> int {
    candidate = start_port;
    pinned_taken = f"Port {start_port} is already in use";
    for _ in range(max_retries) {
        if candidate == skip_port {
            if strict {
                raise OSError(pinned_taken) from None;
            }
            candidate += 1;
            continue;
        }
        try {
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe {
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
                probe.bind(('0.0.0.0', candidate));
            }
            return candidate;
        } except OSError as e {
            in_use = e.errno
                in (
                    ERRNO_ADDR_IN_USE_LINUX,
                    ERRNO_ADDR_IN_USE_MACOS,
                    ERRNO_ADDR_IN_USE_WINDOWS
                )
                or "Address already in use" in str(e);
            if not in_use {
                raise;
            }
            if strict {
                raise OSError(pinned_taken) from None;
            }
            candidate += 1;
        }
    }
    raise OSError(
        f"Could not find an available port after trying {start_port}-{candidate}"
    );
}

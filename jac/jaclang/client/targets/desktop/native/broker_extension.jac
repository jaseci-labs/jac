import asyncio;
import json;
import queue;
import webbrowser;
import from urllib.parse { urlparse }


glob MAX_INVOKE_BYTES: int = 1048576;


def _host_allowed(request: Request) -> bool;


def _origin_allowed(request: Request) -> bool;


def _query(request: Request, name: str, fallback: str = "") -> str;


def event_stream(host: any, q: queue.Queue, keepalive_s: float = 15.0) -> any;


async def _pull(gen: any) -> any;


obj DesktopBrokerExtension(ServerExtension) {
    has store: SessionStore,
        host: any = None,
        opener: Callable[[str], bool] = webbrowser.open,
        prefix: str = DEFAULT_PREFIX,
        pending: PendingAuth = PendingAuth();

    def register(server: JacAPIServer);
}

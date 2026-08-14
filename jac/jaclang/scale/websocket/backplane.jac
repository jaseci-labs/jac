import asyncio;
import json;
import logging;
import from typing { Any }

glob logger = logging.getLogger(__name__);

obj BaseBackplane {
    async def start -> None;
    async def publish(channel: str, message: dict[str, any]) -> None;
    async def subscribe(channel: str, handler: Any) -> None;
    async def unsubscribe(channel: str, handler: Any) -> None;
    async def close -> None;
}

obj MemoryBackplane(BaseBackplane) {
    has _subs: dict[str, list[Any]] = {},
        _warned: bool = False;

    async def start;
    async def publish(channel: str, message: dict[str, any]) -> None;
    async def subscribe(channel: str, handler: Any);
    async def unsubscribe(channel: str, handler: Any);
    async def close;
}

obj PgBackplane(BaseBackplane) {
    has _store: Any = None,
        _loop: Any = None,
        _handlers: dict[str, list[Any]] = {},
        _listening: set[str] = set(),
        _closed: bool = False;

    async def start -> None;
    async def publish(channel: str, message: dict[str, any]) -> None;
    async def subscribe(channel: str, handler: Any);
    async def unsubscribe(channel: str, handler: Any);
    async def close;
    def _pg_channel(channel: str) -> str;
    def _on_notify(channel: str, payload: str) -> None;
    async def _dispatch(channel: str, message: dict[str, any]) -> None;
}

def build_backplane(cfg: dict[str, any]) -> BaseBackplane;

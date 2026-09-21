import asyncio;
import json;
import logging;
glob logger = logging.getLogger(__name__);

obj BaseBackplane {
    async def start -> None abst;
    async def publish(channel: str, message: dict[str, any]) -> None abst;
    async def subscribe(channel: str, handler: any) -> None abst;
    async def unsubscribe(channel: str, handler: any) -> None abst;
    async def close -> None abst;
}

obj MemoryBackplane(BaseBackplane) {
    has _subs: dict[str, list[Callable]] = {},
        _warned: bool = False;

    async def start;
    async def publish(channel: str, message: dict[str, any]) -> None;
    async def subscribe(channel: str, handler: any);
    async def unsubscribe(channel: str, handler: any);
    async def close;
}

obj PgBackplane(BaseBackplane) {
    has _store: any = None,
        _loop: any = None,
        _handlers: dict[str, list[Callable]] = {},
        _listening: set[str] = set(),
        _closed: bool = False;

    async def start -> None;
    async def publish(channel: str, message: dict[str, any]) -> None;
    async def subscribe(channel: str, handler: any);
    async def unsubscribe(channel: str, handler: any);
    async def close;
    def _pg_channel(channel: str) -> str;
    def _on_notify(channel: str, payload: str) -> None;
    async def _dispatch(channel: str, message: dict[str, any]) -> None;
}

def build_backplane(cfg: dict[str, any]) -> BaseBackplane;

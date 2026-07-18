import asyncio;
import json;
import logging;
import from typing { Any }

glob logger = logging.getLogger(__name__);

obj BaseBackplane {
    async def start -> None;
    async def publish(channel: str, message: dict) -> None;
    async def subscribe(channel: str, handler: Any) -> None;
    async def unsubscribe(channel: str, handler: Any) -> None;
    async def close -> None;
}

obj MemoryBackplane(BaseBackplane) {
    has _subs: dict[str, list[Any]] = {},
        _warned: bool = False;

    async def start;
    async def publish(channel: str, message: dict) -> None;
    async def subscribe(channel: str, handler: Any);
    async def unsubscribe(channel: str, handler: Any);
    async def close;
}

obj RedisBackplane(BaseBackplane) {
    has url: str,
        _client: any = None,
        _pubsub: any = None,
        _reader_task: any = None,
        _handlers: dict[str, list[Any]] = {},
        _lock: any = None,
        _closed: bool = False;

    def _get_lock -> Any;
    async def start -> None;
    async def _reader_loop -> None;
    async def publish(channel: str, message: dict) -> None;
    async def subscribe(channel: str, handler: Any);
    async def unsubscribe(channel: str, handler: Any);
    async def close;
}

def build_backplane(cfg: dict) -> BaseBackplane;

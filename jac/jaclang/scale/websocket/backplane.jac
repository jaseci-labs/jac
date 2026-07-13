"""Pluggable WebSocket pub/sub backplane.

Broadcast fan-out for WebSocket targets. The in-process `MemoryBackplane`
keeps messages local to one worker; `RedisBackplane` uses Redis pub/sub so a
broadcast published on any worker reaches every worker's local connections.

Redis pub/sub (not Streams) is used deliberately: WebSocket broadcast is
ephemeral fan-out with dynamic per-target subscribe/unsubscribe, which is a
poor fit for the durable competing-consumer semantics of the events/ package.
"""
import asyncio;
import json;
import logging;
import from typing { Any }

glob logger = logging.getLogger(__name__);

"""Protocol-agnostic backplane interface."""
obj BaseBackplane {
    async def start -> None;
    async def publish(channel: str, message: dict) -> None;
    async def subscribe(channel: str, handler: Any) -> None;
    async def unsubscribe(channel: str, handler: Any) -> None;
    async def close -> None;
}

"""In-process backplane; messages never leave this worker."""
obj MemoryBackplane(BaseBackplane) {
    has _subs: dict[str, list[Any]] = {},
        _warned: bool = False;

    async def start;
    async def publish(channel: str, message: dict) -> None;
    async def subscribe(channel: str, handler: Any);
    async def unsubscribe(channel: str, handler: Any);
    async def close;
}

"""Redis pub/sub backplane; broadcasts reach every subscribed worker."""
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

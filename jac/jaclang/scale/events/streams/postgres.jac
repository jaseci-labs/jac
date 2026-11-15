import json;
import logging;
import socket;
import os;
import time;
import uuid;
import from threading { Thread, Event as _ThreadStop }
import from typing { cast }

def _jsonable(o: any) -> str;


glob _logger = logging.getLogger(__name__),
     _POLL_SECONDS = 0.5,
     _STREAM_SCHEMA = [
         """
         CREATE TABLE IF NOT EXISTS jac_events (
             id         bigserial PRIMARY KEY,
             topic      text NOT NULL,
             payload    jsonb NOT NULL,
             created_at timestamptz NOT NULL DEFAULT now()
         )
         """,
         """
         CREATE INDEX IF NOT EXISTS idx_jac_events_topic
             ON jac_events (topic, id)
         """,
         """
         CREATE TABLE IF NOT EXISTS jac_event_offsets (
             topic   text NOT NULL,
             grp     text NOT NULL,
             last_id bigint NOT NULL DEFAULT 0,
             PRIMARY KEY (topic, grp)
         )
         """
     ];


obj PgEventStream(EventStreamBroker) {
    has config: dict[str, any] = {},
        _store: any = None,
        _consumer_name: str = "",
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _positioned: set[str] = set();

    def postinit;
    def _ensure_store -> any;
    def start;
    def stop(drain: bool = True);
    def publish(topic: str, event: Event, key: str | None = None);
    def _ensure_offset(topic: str, group: str, start_from: str) -> None;
    def _claim(topic: str, group: str, max_messages: int) -> list[any];
    def _advance(topic: str, group: str, hi: int);
    def _to_event(payload: any) -> Event;
    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = StreamPosition.LATEST.value
    ) -> list[Event];

    def ack(event: Event);
    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy);
    def _handle_with_retry(
        topic: str, group: str, event: Event, handler: Callable, retry: RetryPolicy
    );

    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = StreamPosition.LATEST.value
    );

    def health -> HealthStatus;
}

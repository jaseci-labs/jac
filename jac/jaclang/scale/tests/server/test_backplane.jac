"""Cross-pod fan-out for the WebSocket RedisBackplane.

Every other connection-manager test drives MemoryBackplane, so the Redis wire
path (publish -> Redis pub/sub -> reader loop -> handler on another instance) is
otherwise only asserted via isinstance. These tests stand up ONE real Redis and
TWO independent RedisBackplane instances against it - pod A and pod B, each with
its own redis client - and prove a message published on A is delivered, byte for
byte, to a handler subscribed on B, and that B never sees traffic for a channel
it did not subscribe to.
"""
import asyncio;
import unittest;
import from testcontainers.community.redis { RedisContainer }
import from jaclang.scale.websocket.backplane { RedisBackplane }

glob _redis_uri: str = "";

with entry {
    try {
        _container = RedisContainer("redis:7.2-alpine");
        _container.start();
        host = _container.get_container_host_ip();
        port = _container.get_exposed_port(6379);
        _redis_uri = f"redis://{host}:{port}/0";
    } except Exception as e {
        print(f"[skip] Redis container unavailable: {e}");
    }
}


def _require_redis -> str {
    if not _redis_uri {
        raise unittest.SkipTest("Redis container unavailable");
    }
    return _redis_uri;
}


test "a message published on one RedisBackplane reaches a handler subscribed on a second" {
    uri = _require_redis();

    async def body -> list {
        received: list = [];
        arrived = asyncio.Event();

        async def handler(channel: any, message: dict) {
            received.append((str(channel), message));
            arrived.set();
        }

        pod_a = RedisBackplane(url=uri);
        pod_b = RedisBackplane(url=uri);
        await pod_a.start();
        await pod_b.start();
        try {
            await pod_b.subscribe("walker:room-1", handler);
            # let Redis register the SUBSCRIBE and the reader loop spin up
            await asyncio.sleep(0.25);

            payload = {"type": "broadcast", "n": 7, "text": "hello-pod-B"};
            await pod_a.publish("walker:room-1", payload);

            try {
                await asyncio.wait_for(arrived.wait(), timeout=5.0);
            } except asyncio.TimeoutError {
                pass;
            }
            return list(received);
        } finally {
            await pod_a.close();
            await pod_b.close();
        }
    }

    received = asyncio.run(body());
    assert len(received) == 1 , f"expected exactly one cross-pod delivery, got {received}";
    (channel, message) = received[0];
    assert channel == "walker:room-1" , f"delivered on wrong channel: {channel}";
    # the payload survives the json.dumps -> Redis -> json.loads round trip intact
    assert message == {"type": "broadcast", "n": 7, "text": "hello-pod-B"} , f"payload was mangled on the wire: {message}";
}


test "a RedisBackplane only receives messages for channels it subscribed to" {
    uri = _require_redis();

    async def body -> list {
        received: list = [];
        arrived = asyncio.Event();

        async def handler(channel: any, message: dict) {
            received.append((str(channel), message));
            arrived.set();
        }

        pod_a = RedisBackplane(url=uri);
        pod_b = RedisBackplane(url=uri);
        await pod_a.start();
        await pod_b.start();
        try {
            await pod_b.subscribe("walker:subscribed", handler);
            await asyncio.sleep(0.25);

            # B never subscribed to this channel; Redis must filter it out
            await pod_a.publish("walker:elsewhere", {"text": "do-not-deliver"});
            # a message on the subscribed channel, published right after, is the
            # fence: once it arrives we know the earlier one had its chance and
            # was correctly dropped
            await pod_a.publish("walker:subscribed", {"text": "deliver-me"});

            try {
                await asyncio.wait_for(arrived.wait(), timeout=5.0);
            } except asyncio.TimeoutError {
                pass;
            }
            # give any stray delivery a beat to (not) show up
            await asyncio.sleep(0.1);
            return list(received);
        } finally {
            await pod_a.close();
            await pod_b.close();
        }
    }

    received = asyncio.run(body());
    assert len(received) == 1 , f"only the subscribed channel should be delivered, got {received}";
    (channel, message) = received[0];
    assert channel == "walker:subscribed" , f"delivered on wrong channel: {channel}";
    assert message == {"text": "deliver-me"} , f"got {message}";
    assert message != {"text": "do-not-deliver"};
}

"""Service transport: how an `sv` call reaches its target service.

The `ServiceTransport` port has two adapters. `InProcessTransport` dispatches to
a locally-registered callable with no network hop - this is how a monolith
collapses the microservice blueprint to N=1. `HttpTransport` forwards over the
network for distributed topologies, delegating to the rpc layer for auth/trace
forwarding, retry+backoff, the circuit breaker, and SSE. The sv-RPC hooks call
the port (`http_transport().call_function/call_walker`), never a concrete
transport, so they never branch on topology.
"""

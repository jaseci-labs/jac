"""The serving gateway.

The `Gateway` port has two adapters: `EmbeddedGateway` runs in the app process
(monolith, no second process) and `ProcessGateway` runs as its own process or pod
(microservice). Both share one request-dispatch decision (`classify_route`) and
one middleware registry, so they differ only in hosting and in whether a proxy
hop is an in-process call or a network call.
"""

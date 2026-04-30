"""Microservice mode for jac-scale.

Hosts the gateway, deployer, orchestrator, process manager, and the
production-hardening modules (drain, trace, auth context, rate limit,
CORS, errors, OpenAPI aggregation, SSE framing) that turn a single
`jac` server into a fleet of `sv import`-discovered services.
"""

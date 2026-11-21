"""Postgres connection facade over jac's own wire client.

Historically this loaded a vendored pg8000; the runtime now ships its own
minimal protocol implementation (jaclang.data.pgwire), so this module
is just the one place that maps ConnInfo-style fields onto it (unix socket
FILE path vs host, defaulted ports).
"""

import os


def connect(
    user,
    host=None,
    port=5432,
    unix_socket_dir=None,
    database="postgres",
    password=None,
    timeout=None,
    startup_params=None,
):
    """Open a wire connection from ConnInfo-style fields."""
    from jaclang.data.pgwire import PgWireConnection

    unix_sock = None
    if unix_socket_dir:
        unix_sock = os.path.join(unix_socket_dir, f".s.PGSQL.{port}")
    app_name = "jac"
    if startup_params and isinstance(startup_params, dict):
        app_name = str(startup_params.get("application_name", app_name))
    return PgWireConnection(
        user=user,
        host=host,
        port=port,
        unix_sock=unix_sock,
        database=database,
        password=password,
        timeout=timeout,
        application_name=app_name,
    )

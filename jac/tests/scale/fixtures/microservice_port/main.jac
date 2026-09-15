"""Entry point for the gateway-port fixture."""

import from echo_service { echo }

def:pub greet -> str {
    return echo("ready");
}

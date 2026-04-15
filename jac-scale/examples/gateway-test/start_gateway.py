"""Manual gateway test script.

Usage:
  1. Start the consumer first (auto-spawns math_service):
     cd examples/gateway-test
     jac start calculator_service.jac --port 8002

  2. Find the math_service port from the logs:
     Look for "sv-to-sv service 'math_service' ... at http://127.0.0.1:XXXXX"

  3. Run this script (in another terminal):
     python start_gateway.py --math-port XXXXX

  4. Test through gateway:
     curl -X POST http://localhost:8000/api/calc/function/sum_list \
       -H "Content-Type: application/json" -d '{"numbers": [1,2,3,4,5]}'

     curl http://localhost:8000/health
"""

import argparse
import sys
import os

# Add jac-scale to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from jaclang.runtimelib import sv_client
from jac_scale.microservices.gateway import MicroserviceGateway


def main():
    parser = argparse.ArgumentParser(description="Start the microservice gateway")
    parser.add_argument("--math-port", type=int, required=True, help="Port of math_service")
    parser.add_argument("--calc-port", type=int, default=8002, help="Port of calculator_service")
    parser.add_argument("--gateway-port", type=int, default=8000, help="Gateway port")
    args = parser.parse_args()

    # Register services in sv_client (normally ensure_sv_service does this)
    sv_client.register("math_service", f"http://127.0.0.1:{args.math_port}")
    sv_client.register("calculator_service", f"http://127.0.0.1:{args.calc_port}")

    print(f"Registered math_service at :{ args.math_port}")
    print(f"Registered calculator_service at :{args.calc_port}")

    # Start gateway
    gw = MicroserviceGateway(
        routes={
            "math_service": "/api/math",
            "calculator_service": "/api/calc",
        },
        port=args.gateway_port,
    )
    print(f"\nStarting gateway on :{args.gateway_port}")
    print(f"  /api/math/*  → :{ args.math_port}")
    print(f"  /api/calc/*  → :{args.calc_port}")
    print(f"  /health      → service status\n")
    gw.start()


if __name__ == "__main__":
    main()

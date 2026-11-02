import logging;
import from pathlib { Path }

glob logger: logging.Logger = logging.getLogger('jaclang.serve'),
     CL_PREFIX: str = 'cl/',
     API_PREFIXES: tuple[str, ...] = (
         'walker/',
         'function/',
         'user/',
         'static/',
         'healthz'
     );


def _dev_client_elsewhere -> JSONResponse;


def _static_base(server: JacAPIServer) -> str;


def _render(
    server: JacAPIServer, name: str, args: dict[str, any], status: int = 200
) -> Response;


def _sibling_response(request: Request, dist: Path, rel: str) -> Response;


def register_page_endpoints(server: JacAPIServer);


def register_graph_endpoints(server: JacAPIServer);


def register_diagnostics_endpoints(server: JacAPIServer);

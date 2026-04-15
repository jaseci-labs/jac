"""Raw HTTP forwarding — plain Python to work around Jac type checker aiohttp limitations."""

import logging

import aiohttp

logger = logging.getLogger(__name__)


async def raw_forward(
    method: str,
    url: str,
    headers: dict[str, str],
    body: bytes,
    timeout: int = 30,
) -> tuple[int, dict[str, str], bytes] | None:
    """Forward an HTTP request. Returns (status, headers, body) or None on error."""
    try:
        async with (
            aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=timeout)
            ) as session,
            session.request(
                method=method,
                url=url,
                headers=headers,
                data=body,
                allow_redirects=False,
            ) as resp,
        ):
            resp_body = await resp.read()
            resp_headers = {
                k: v
                for k, v in resp.headers.items()
                if k.lower()
                not in ("host", "transfer-encoding", "connection", "keep-alive")
            }
            return (resp.status, resp_headers, resp_body)
    except (aiohttp.ClientError, OSError) as e:
        logger.error(f"HTTP forward error: {e}")
        return None

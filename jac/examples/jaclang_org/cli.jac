import argparse;
import asyncio;
import sys;
import from jaclang.server.bridge {
    BridgeError,
    BridgeRejected,
    BridgeTimeout,
    BridgeUnavailable
}

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     EXIT_TIMEOUT: int = 4,
     EXIT_REJECTED: int = 5;

glob START_HINT: str = "hint: start the site with `jac run web`";

def warn(text: str);

def _suffix(detail: str) -> str;

def explain_bridge_error(e: BridgeError) -> int;

def render_status(st: DocsStatus) -> str;

async def run_docs(action: str) -> int;

obj FeedLine {
    has author: str = "",
        content: str = "",
        created_at: str = "",
        likes: int = 0,
        comments: int = 0;
}


def render_line(line: FeedLine) -> str;

async def run_feed(limit: int, query: str) -> int;

async def run_post(text: str) -> int;

glob PROG: str = "jacorg",
     DEFAULT_LIMIT: int = 20;

obj Invocation {
    has command: str = "",
        action: str = "",
        limit: int = DEFAULT_LIMIT,
        query: str = "",
        text: str = "";
}

def build_parser -> argparse.ArgumentParser;

def parse_args(argv: list[str]) -> Invocation;

async def dispatch(inv: Invocation) -> int;

async def main(argv: list[str]) -> int;

with entry:__main__ {
    sys.`exit(asyncio.run(main(sys.argv[1:])));
}

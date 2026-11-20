import sys;
import from stdjac.remote { RemoteError, RemoteRejected, RemoteTimeout, RemoteUnavailable }

glob EXIT_OK: int = 0,
     EXIT_FAILURE: int = 1,
     EXIT_USAGE: int = 2,
     EXIT_UNAVAILABLE: int = 3,
     EXIT_TIMEOUT: int = 4,
     EXIT_REJECTED: int = 5;

glob START_HINT: str = "hint: start the site with `jac run web`, and set JAC_REMOTE_SOCIAL and JAC_REMOTE_SITE_API to its URL";

def warn(text: str);

def _suffix(detail: str) -> str;

def explain_bridge_error(e: RemoteError) -> int;

def render_status(st: DocsStatus) -> str;

def run_docs(action: str) -> int;

obj FeedLine {
    has author: str = "",
        content: str = "",
        created_at: str = "",
        likes: int = 0,
        comments: int = 0;
}

def render_line(line: FeedLine) -> str;

def run_feed(limit: int, query: str) -> int;

def run_post(text: str) -> int;

glob USAGE: str = "usage: jacorg docs {sync,status} | feed [--limit N] [--search TEXT] | post TEXT",
     PROG: str = "jacorg",
     DEFAULT_LIMIT: int = 20;

obj Invocation {
    has command: str = "",
        action: str = "",
        limit: int = DEFAULT_LIMIT,
        query: str = "",
        text: str = "";
}

"""What the arguments ask for, or why they can't be read: `error` is what to say."""
obj Parsed {
    has inv: Invocation = Invocation(),
        error: str = "",
        show_help: bool = False;
}

def parse_args(argv: list[str]) -> Parsed;

def dispatch(inv: Invocation) -> int;

def main(argv: list[str]) -> int;

with entry:__main__ {
    sys.exit(main(sys.argv[1:]));
}

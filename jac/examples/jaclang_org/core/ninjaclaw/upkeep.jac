import threading;
import from uuid { uuid4 }

obj SweepItem {
    has slug: str = "",
        body: str = "";
}

obj Chore {
    has lock: threading.Lock = threading.Lock(),
        kind: str = "",
        run_id: str = "",
        progress: str = "",
        result: any = None,
        error: str = "",
        finished: bool = False;

    def busy -> bool;
    def start(kind: str, work: Callable) -> bool;
    def note(phase: str, text: str) -> None;
    def status -> tuple[str, str];
    def peek -> tuple[str, str, any, str] | None;
    def ack(run_id: str) -> None;
}

glob CHORE: Chore = Chore();

def sweep_items(
    tutorials: list[tuple[str, str, str, str, str]], version: str
) -> list[SweepItem];

def sweep(items: list[SweepItem], note: Callable) -> dict[str, list[BlockView]];

def sweep_passed(blocks: list[BlockView]) -> bool;

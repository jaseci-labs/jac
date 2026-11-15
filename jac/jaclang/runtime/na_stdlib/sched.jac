import time;


obj:pub Event {
    has time: float,
        priority: int,
        sequence: int,
        action: Callable[[], None],
        argument: list[any],
        kwargs: dict[str, any];

    def __eq__(other: Event) -> bool;
    def __lt__(other: Event) -> bool;
    def __le__(other: Event) -> bool;
    def __gt__(other: Event) -> bool;
    def __ge__(other: Event) -> bool;
}


def _default_time -> float;


def _default_delay(delay: float);


obj:pub scheduler {
    has _queue: list[Event],
        _seq: int,
        timefunc: Callable[[], float],
        delayfunc: Callable[[float], None];

    has queue: list[Event] { getter; }

    def init(
        timefunc: (Callable[[], float] | None) = None,
        delayfunc: (Callable[[float], None] | None) = None
    );

    def enterabs(
        time: float,
        priority: int,
        action: Callable[[], None],
        argument: (list[any] | None) = None,
        kwargs: (dict[str, any] | None) = None
    ) -> Event;

    def enter(
        delay: float,
        priority: int,
        action: Callable[[], None],
        argument: (list[any] | None) = None,
        kwargs: (dict[str, any] | None) = None
    ) -> Event;

    def _insert(ev: Event);
    def cancel(event: Event) -> None;
    def empty -> bool;
    def run(blocking: bool = True) -> float | None;
}

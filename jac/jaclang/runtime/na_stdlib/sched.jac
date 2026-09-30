import time;


obj:pub Event {
    has time: float,
        priority: int,
        sequence: int,
        action: Callable[[], None],
        argument: list[any],
        kwargs: dict[str, any];

    def __eq__(other: Event) -> bool {
        return self.time == other.time
            and self.priority == other.priority
            and self.sequence == other.sequence;
    }

    def __lt__(other: Event) -> bool {
        if self.time != other.time {
            return self.time < other.time;
        }
        if self.priority != other.priority {
            return self.priority < other.priority;
        }
        return self.sequence < other.sequence;
    }

    def __le__(other: Event) -> bool {
        return not other.__lt__(self);
    }

    def __gt__(other: Event) -> bool {
        return other.__lt__(self);
    }

    def __ge__(other: Event) -> bool {
        return not self.__lt__(other);
    }
}


def _default_time -> float {
    return time.monotonic();
}


def _default_delay(delay: float) {
    time.sleep(delay);
}


obj:pub scheduler {
    has _queue: list[Event],
        _seq: int,
        timefunc: Callable[[], float],
        delayfunc: Callable[[float], None];

    has queue: list[Event] { getter; }

    def init(
        timefunc: (Callable[[], float] | None) = None,
        delayfunc: (Callable[[float], None] | None) = None
    ) {
        self._queue = [];
        self._seq = 0;
        tf = timefunc;
        if tf is None {
            self.timefunc = _default_time;
        } else {
            self.timefunc = tf;
        }
        df = delayfunc;
        if df is None {
            self.delayfunc = _default_delay;
        } else {
            self.delayfunc = df;
        }
    }

    def enterabs(
        time: float,
        priority: int,
        action: Callable[[], None],
        argument: (list[any] | None) = None,
        kwargs: (dict[str, any] | None) = None
    ) -> Event {
        args: list[any] = [];
        if argument is not None {
            args = argument;
        }
        kw: dict[str, any] = {};
        if kwargs is not None {
            kw = kwargs;
        }
        if len(args) > 0 or len(kw) > 0 {
            raise TypeError(
                "na_stdlib sched: action arguments are not supported;"
                " bind them in a closure instead"
            );
        }
        ev: Event = Event(
            time=time,
            priority=priority,
            sequence=self._seq,
            action=action,
            argument=args,
            kwargs=kw
        );
        self._seq += 1;
        self._insert(ev);
        return ev;
    }

    def enter(
        delay: float,
        priority: int,
        action: Callable[[], None],
        argument: (list[any] | None) = None,
        kwargs: (dict[str, any] | None) = None
    ) -> Event {
        tf = self.timefunc;
        at: float = tf() + delay;
        return self.enterabs(at, priority, action, argument, kwargs);
    }

    def _insert(ev: Event) {
        n: int = len(self._queue);
        at: int = n;
        i: int = 0;
        while i < n {
            if ev.__lt__(self._queue[i]) {
                at = i;
                break;
            }
            i += 1;
        }
        self._queue.insert(at, ev);
    }

    def cancel(event: Event) -> None {
        n: int = len(self._queue);
        i: int = 0;
        while i < n {
            if self._queue[i].sequence == event.sequence {
                self._queue.pop(i);
                return;
            }
            i += 1;
        }
        raise ValueError("list.remove(x): x not in list");
    }

    def empty -> bool {
        return len(self._queue) == 0;
    }

    def run(blocking: bool = True) -> float | None {
        tf = self.timefunc;
        df = self.delayfunc;
        while len(self._queue) > 0 {
            head: Event = self._queue[0];
            now: float = tf();
            if head.time > now {
                if not blocking {
                    return head.time - now;
                }
                df(head.time - now);
            } else {
                self._queue.pop(0);
                act = head.action;
                act();
                df(0.0);
            }
        }
        return None;
    }
}


impl scheduler.queue.getter -> list[Event] {
    out: list[Event] = [];
    for ev in self._queue {
        out.append(ev);
    }
    return out;
}

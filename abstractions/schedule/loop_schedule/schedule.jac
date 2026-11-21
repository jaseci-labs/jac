"""The standard scheduler: each scheduled function is run every so
many seconds by the thread the program listens on, the first time as it
starts. A thread of its own keeps the time, and hands each function that is
due to that thread: so a scheduled function of a space the program runs in
its own process runs where the space's code must, and one that runs long
holds up no other's clock."""

import threading;
import time;
import from common.contract { Host }
import from schedule.contract { Scheduled, Scheduler }

obj LoopSchedule(Scheduler) {
    """How often the clock looks for a function that is due, in seconds."""
    has tick: float = 0.25;

    """Nothing to open: it asks nothing of the program until it is given
    what to run (`start`)."""
    def open(host: dyn Host) {}

    def start(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None]) {
        tick = self.tick;
        threading.Thread(target=lambda { keep_time(work, on_loop, tick) }, daemon=True).start();
    }
}

"""Run `s` once: a failure of its own is said, and it runs again at its next
turn."""
def run_once(s: Scheduled) {
    try {
        s.run();
    } except Exception as e {
        print(s.name + " failed: " + str(e));
    }
}

"""One turn of `s`, for the listening thread to take: it runs `s`, and then
says that `s` waits no longer. (Made here, one for each turn, so that each
holds its own function: a lambda written in the clock's loop would hold the
loop's variables, and run whichever function the loop came to last.)"""
def turn_of(s: Scheduled, waiting: list[bool], at: int) -> Callable[[], None] {
    return lambda {
        try {
            run_once(s);
        } finally {
            waiting[at] = False;
        }
    };
}

"""The clock's life: each of `work` handed to `on_loop` when it is due, a
function still waiting for its last turn not handed again."""
def keep_time(work: list[Scheduled], on_loop: Callable[[Callable[[], None]], None], tick: float) {
    due: list[float] = [time.time() for _ in work];
    waiting: list[bool] = [False for _ in work];
    forever {
        now = time.time();
        for k in range(len(work)) {
            if due[k] <= now and not waiting[k] {
                due[k] = now + work[k].every;
                waiting[k] = True;
                on_loop(turn_of(work[k], waiting, k));
            }
        }
        time.sleep(tick);
    }
}

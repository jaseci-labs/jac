"""The contract of the `jobs` abstraction: `Jobs`, the interface of the plugin
that runs a program's jobs apart from what started them, what crosses it,
and `JobsHost`, what such a plugin asks of the program it runs in."""

import from common.contract { Host }

"""What a job has said since it was last read, and its end: whether it has
ended, with its result as JSON's values, or what it failed with."""
obj JobState {
    has notes: list[tuple[str, str]] = [],
        done: bool = False,
        result: any = None,
        failed: str = "";
}

"""What a `jobs` plugin may ask of the program it runs in: what every plugin
may (`Host`), and

- `command`, the command that runs this program again: before its
  arguments.
- `owner`, the space whose jobs this program's are, to a copy started for
  one: "" for the program's own.
- `run`, which runs the program's job `name` on `input`, JSON's values,
  telling `note(phase, text)` how it goes: its result, as JSON's values.
  ValueError for a name that is no job's. What a plugin calls where the job
  runs.
- `run_space`, the same for a job of the space `owner`, which the program
  runs in its own process. ValueError for a space it runs none of."""
obj JobsHost(Host) {
    def command -> list[str] abst;
    def owner -> str abst;
    def run(name: str, input: any, note: Callable[[str, str], None]) -> any abst;
    def run_space(owner: str, name: str, input: any, note: Callable[[str, str], None]) -> any abst;
}

"""What runs a program's jobs apart: the interface of the `jobs`
abstraction's plugins.

- `open` is the first thing asked of it, given the program it runs in.
- `start` starts job `name` (its module's and its own) on `input`, JSON's
  values, and gives what names that run.
- `read` gives what run `id` has said since it was last read, and whether
  it has ended.
- `work` is asked as a program starts: it runs the job this process was
  started for, if it was started for one, and says whether it was."""
obj Jobs {
    def open(host: dyn JobsHost) abst;
    def start(name: str, input: any) -> str abst;
    def read(id: str) -> JobState abst;
    def work -> bool abst;
}

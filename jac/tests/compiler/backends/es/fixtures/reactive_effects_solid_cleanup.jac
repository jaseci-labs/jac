"""A lifecycle hook for exercising Solid cleanup without DOM rendering."""
import from "solid-js" { getOwner }

def:pub subscribe(read: Callable[[], int], events: list[str]) {
    assert getOwner() is not None;
    can with entry {
        snapshot = read();
        if snapshot == 2 {
            return;
        }
        events.append("setup:" + str(snapshot));
        return lambda { events.append("cleanup:" + str(snapshot)); };
    }
}

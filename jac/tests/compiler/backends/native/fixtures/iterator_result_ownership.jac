glob dropped: int = 0;

obj Item {
    has value: int;

    def drop {
        dropped += 1;
    }
}

obj Stream {
    has index: int = 0;

    def __iter__ -> Stream {
        return self;
    }

    def __next__ -> Item {
        if self.index == 3 {
            raise StopIteration();
        }
        self.index += 1;
        return Item(self.index);
    }
}

def consume(stop_early: bool) -> int {
    total = 0;
    for item in Stream() {
        total += item.value;
        if stop_early {
            break;
        }
    }
    return total;
}

def check(stop_early: bool) -> bool {
    dropped = 0;
    total = consume(stop_early);
    return total == (1 if stop_early else 6) and dropped == (1 if stop_early else 3);
}

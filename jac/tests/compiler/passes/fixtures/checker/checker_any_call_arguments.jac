obj Item {
    has flag: bool,
        value: int;
}

def keyword_any_call(items: list[Item]) {
    print(any([item.flag and item.value == 1 for item in items]));
}

def any_callee(items: list[Item], callback: any) {
    callback([item.flag or item.value > 1 for item in items]);
}

def any_callee_keyword(items: list[Item], callback: any) {
    callback(flags=[not item.flag for item in items]);
}

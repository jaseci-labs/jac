import from datetime { date, time, timedelta, tzinfo }

obj:pub Error(Exception) {}

def:pub copy(x: any) -> any;

def:pub deepcopy(x: any) -> any;

def _is_atomic(x: any) -> bool;

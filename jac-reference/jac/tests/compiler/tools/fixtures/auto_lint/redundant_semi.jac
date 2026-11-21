"""Test fixture for removing redundant standalone semicolons."""

def empty_fn {;}

def stray_semis -> int {
    x = 1;
    ;
    y = 2;;
    return x + y;
}

obj Container {
    def method {;}
}

walker Visitor {
    can act with Root entry {;}
}

def control(flag: bool) {
    if flag {;}
    if flag {
        taken = 1;
    } else {;}
    while flag {;}
    for i in range(1) {;}
    try {;} except Exception {;} finally {;}
}

test {;}

with entry:named {;}

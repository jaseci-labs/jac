enum E { A = 0, B = 1, }

sem E= "An enum representing some values.";
sem E. A= "The first value of the enum E.";
sem E. B= "The second value of the enum E.";

obj Person {
    has name: str;
    has yob: int;

    def calc_age(year: int) -> int {
        return year - self.yob;
    }
}

obj OuterClass {
    obj InnerClass {
        has inner_value: str;
    }
}

def summarize_text(text: str) -> str {
    return text;
}

def evaluate_score(text: str) -> int {
    return 0;
}

def merge_results(a: str, b: str) -> str {
    return a + b;
}

def fetch_data(query: str) -> str {
    return query;
}

with entry {
    print(E.A);
}

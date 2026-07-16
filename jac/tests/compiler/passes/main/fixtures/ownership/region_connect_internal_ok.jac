node City {
    has name: str = "";
}

def run {
    in Region() {
        a = City();
        b = City();
        a ++> b;
        print(len([a, b]));
    }
}

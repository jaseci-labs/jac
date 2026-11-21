node City {
    has name: str = "";
}

def run {
    anchor = City();
    in Region() {
        c = City();
        anchor ++> c;
    }
}

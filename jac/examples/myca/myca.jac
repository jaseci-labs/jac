"""Myca Lite to serve as example for Myca in Jaclang"""
import from datetime { datetime }

edge next_epoc {}
edge prev_epoc {}

node epoc {
    has date: datetime;

    def quantize { }
}

node life(epoc) {
    def quantize { }
}

node year(epoc) {
    def quantize { }
}

node month(epoc) {
    def quantize { }
}

node week(epoc) {
    def quantize { }
}

node day(epoc) {
    def quantize { }
}

node item {
    has title: str;
}

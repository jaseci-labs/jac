"""File with bug related to cl js generation."""

cl {
    glob setB = lambda  item: int  -> None{ item.b = 90;} ;
}

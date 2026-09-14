import from enum { StrEnum }

class Constants(StrEnum) {
    with entry {
        HERE = 'here';
        ROOT = 'root';
        VISITOR = 'visitor';
        GUEST = '__guest__';
        SUPER_ROOT_UUID = '00000000-0000-0000-0000-000000000000';
    }

    def __str__(self: Constants) -> str {
        return self.value;
    }
}

enum EdgeDir: int { IN = 1, OUT = 2, ANY = 3 }

glob colors: list[str] = [
         '#FFE9E9',
         '#F0FFF0',
         '#F5E5FF',
         '#FFFFE0',
         '#D2FEFF',
         '#E8FFD7',
         '#FFDEAD',
         '#FFF0F5',
         '#F5FFFA',
         '#FFC0CB',
         '#7FFFD4',
         '#C0C0C0',
         '#ADD8E6',
         '#FFFAF0',
         '#f4f3f7',
         '#f5efff',
         '#b5d7fd',
         '#ffc0cb',
         '#FFC0CB',
         '#e1d4c0',
         '#FCDFFF',
         '#F0FFFF',
         '#F0F8FF',
         '#F8F8FF',
         '#F0FFFF'
     ];

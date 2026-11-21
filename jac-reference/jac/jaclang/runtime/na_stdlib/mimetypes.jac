import from os.path { splitext, isfile }


def _split_words(line: str) -> list[str];


def _scheme_of(url: str) -> str;


obj:pub MimeTypes {
    has encodings_map: dict[str, str],
        suffix_map: dict[str, str],
        _strict_map: dict[str, str],
        _lax_map: dict[str, str],
        _strict_inv: dict[str, list[str]],
        _lax_inv: dict[str, list[str]];

    def init(filenames: (list[str] | None) = None, strict: bool = True);
    def add_type(type: str, ext: str, strict: bool = True) -> None;
    def _guess(path: str, strict: bool) -> tuple[str | None, str | None];
    def guess_file_type(
        path: str, strict: bool = True
    ) -> tuple[str | None, str | None];

    def guess_type(url: str, strict: bool = True) -> tuple[str | None, str | None];
    def guess_all_extensions(type: str, strict: bool = True) -> list[str];
    def guess_extension(type: str, strict: bool = True) -> str | None;
    def read(filename: str, strict: bool = True);
    def _strict_table -> dict[str, str];
    def _lax_table -> dict[str, str];
}


def _boot -> MimeTypes;


glob _DB: MimeTypes = _boot();

glob:pub inited: bool = True;

glob:pub suffix_map: dict[str, str] = _DB.suffix_map,
     encodings_map: dict[str, str] = _DB.encodings_map,
     types_map: dict[str, str] = _DB._strict_table(),
     common_types: dict[str, str] = _DB._lax_table();


def:pub init(files: (list[str] | None) = None);


def:pub guess_type(url: str, strict: bool = True) -> tuple[str | None, str | None];


def:pub guess_file_type(
    path: str, strict: bool = True
) -> tuple[str | None, str | None];


def:pub guess_all_extensions(type: str, strict: bool = True) -> list[str];


def:pub guess_extension(type: str, strict: bool = True) -> str | None;


def:pub add_type(type: str, ext: str, strict: bool = True);


def:pub read_mime_types(file: str) -> dict[str, str] | None;

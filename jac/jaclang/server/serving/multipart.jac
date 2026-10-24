import io;
import tempfile;
import from urllib.parse { parse_qs }


glob MAX_PARTS: int = 1000,
     MAX_PART_HEADER_BYTES: int = 16384,
     MAX_FIELD_BYTES: int = 1048576,
     CHUNK_BYTES: int = 65536,
     DEFAULT_SPOOL_BYTES: int = 1048576;


def _content_type_param(header_value: str, param: str) -> (str | None);

def _parse_part_headers(raw: bytes) -> dict[str, str];


obj _PartReader {
    has source: any,
        delim: bytes,
        buf: bytes = b'',
        eof: bool = False,
        finished: bool = False;

    def _fill -> bool;
    def _consume_delimiter_tail;
    def skip_preamble;
    def read_part_headers -> dict[str, str];
    def copy_part_body(sink: any, cap: int = 0) -> int;
}


def parse_multipart(request: Request, spool_bytes: int = DEFAULT_SPOOL_BYTES);

def parse_urlencoded_form(request: Request);

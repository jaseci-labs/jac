"""Native ZIP reader: public APIs, error types and context-manager lifetime."""
import zipfile;
import from zipfile { ZipFile, BadZipFile }
import from zlib { crc32 }

def archive_checks(path: str) -> bool {
    with zipfile.ZipFile(path) as archive {
        assert archive.namelist()
            == [
                "stored",
                "deflated",
                "empty",
                "folder/",
                "café.txt",
                "duplicate",
                "duplicate"
            ];
        assert archive.comment == b"archive comment PK\x05\x06";
        assert archive.read("stored") == b"\x00\xffstored\x00";
        assert archive.read("deflated") == b"deflated\x00" * 1000;
        assert archive.read("empty") == b"";
        assert archive.read("folder/") == b"";
        assert archive.read("café.txt") == b"unicode";
        assert archive.read("duplicate") == b"last";
        assert archive.getinfo("folder/").is_dir();
        assert not archive.getinfo("stored").is_dir();
        assert archive.getinfo("deflated").file_size == 9000;
        assert archive.getinfo("deflated").compress_type == zipfile.ZIP_DEFLATED;
        assert archive.getinfo("stored").compress_type == zipfile.ZIP_STORED;
        assert len(archive.infolist()) == 7;
        infos = archive.infolist();
        infos.clear();
        assert len(archive.infolist()) == 7;
    }
    try {
        archive.read("stored");
    } except ValueError {
        archive.close();
        assert len(archive.namelist()) == 7;
        return True;
    }
    return False;
}

def member_crc(path: str, name: str) -> int {
    with ZipFile(path, "r") as archive {
        return crc32(archive.read(name));
    }
}

def count_members(path: str) -> int {
    with ZipFile(path) as archive {
        return len(archive.namelist());
    }
}

def read_error(path: str, name: str) -> int {
    try {
        with ZipFile(path) as archive {
            archive.read(name);
        }
    } except BadZipFile {
        return 1;
    } except NotImplementedError {
        return 2;
    } except KeyError {
        return 3;
    } except ValueError {
        return 4;
    }
    return 0;
}

def wrong_mode(path: str) -> bool {
    try {
        ZipFile(path, "w");
    } except NotImplementedError {
        return True;
    }
    return False;
}

def exceptional_exit(path: str) -> bool {
    archive = ZipFile(path);
    try {
        with archive {
            raise RuntimeError("inside with");
        }
    } except RuntimeError {
        try {
            archive.read("stored");
        } except ValueError {
            return True;
        }
    }
    return False;
}

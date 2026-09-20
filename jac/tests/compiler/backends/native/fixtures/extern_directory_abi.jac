import os;
import from pathlib { Path }
import sys;

glob folder = sys.argv[1],
     expected = "present.bin";

with entry {
    native_names = [path.name for path in Path(folder).iterdir()];
    lowered_names = os.listdir(folder);
    assert expected in native_names and expected in lowered_names;
    assert len(native_names) == len(lowered_names);
    assert expected in os.listdir(folder);
    assert expected in [path.name for path in Path(folder).iterdir()];
    errors = 0;
    try {
        os.listdir(folder + "/missing");
    } except FileNotFoundError {
        errors += 1;
    }
    try {
        list(Path(folder + "/missing").iterdir());
    } except FileNotFoundError {
        errors += 1;
    }
    try {
        os.listdir(folder + "/present.bin");
    } except NotADirectoryError {
        errors += 1;
    }
    assert errors == 3;
    print("EXTERN DIRECTORY ABI PASS");
}

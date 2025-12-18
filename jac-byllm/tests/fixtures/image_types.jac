import from byllm.lib { Image }
import from PIL { Image as PILImage }
import io;
import os;
import base64;
import from pathlib { Path }

glob img_file_path = os.path.join(os.path.dirname(__file__), "alan-m-turing.jpg");

with entry {
    print("PIL Image");
}

glob
    pil_image = PILImage.open(img_file_path),
    image = Image(pil_image);

with entry {
    print("Image from file path");
}

glob image2 = Image(img_file_path);

with entry {
    print("Image from URL");
}

glob image3 = Image("https://en.wikipedia.org/wiki/File:Alan_turing_header.jpg");

with entry {
    print("Image from BytesIO");
}

glob bytes_buf = io.BytesIO();

with entry {
    pil_image.save(bytes_buf, format="PNG");
}

glob image4 = Image(bytes_buf);

with entry {
    print("Image from raw bytes");
}

glob bytes_buf2 = io.BytesIO();

with entry {
    pil_image.save(bytes_buf2, format="PNG");
}

glob
    raw_bytes = bytes_buf2.getvalue(),
    image5 = Image(raw_bytes);

with entry {
    print("Image from memoryview");
}

glob
    mv = memoryview(raw_bytes),
    image6 = Image(mv);

with entry {
    print("Image from data URL");
}

glob bytes_buf3 = io.BytesIO();

with entry {
    pil_image.save(bytes_buf3, format="PNG");
}

glob
    b64 = base64.b64encode(bytes_buf3.getvalue()).decode("utf-8"),
    data_url = "data:image/png;base64," + b64,
    image7 = Image(data_url);

with entry {
    print("Image from PathLike");
}

glob
    p = Path(img_file_path),
    image8 = Image(p);

with entry {
    print("Image from file-like without getvalue");
}

# Use a BufferedReader to simulate a stream lacking getvalue
glob tmp_buf = io.BytesIO();

with entry {
    pil_image.save(tmp_buf, format="PNG");
}

glob
    reader = io.BufferedReader(io.BytesIO(tmp_buf.getvalue())),
    image9 = Image(reader);

with entry {
    print("Image from bytearray");
}

glob
    ba = bytearray(raw_bytes),
    image10 = Image(ba);

with entry {
    print("Image from gs:// URL");
}

glob image11 = Image("gs://bucket/path/alan_turing.png");

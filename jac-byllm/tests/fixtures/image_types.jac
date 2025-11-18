import from byllm.lib {Image}
import from PIL {Image as PILImage}
import io;
import os;
import base64;
import from pathlib {Path}

glob img_file_path = os.path.join(os.path.dirname(__file__), "alan-m-turing.jpg");

with entry {
    print("PIL Image");
    pil_image = PILImage.open(img_file_path);
    image = Image(pil_image);

    print("Image from file path");
    image2 = Image(img_file_path);
    print("Image from URL");
    image3 = Image("https://en.wikipedia.org/wiki/File:Alan_turing_header.jpg");

    print("Image from BytesIO");
    bytes_buf = io.BytesIO();
    pil_image.save(bytes_buf, format="PNG");
    image4 = Image(bytes_buf);

    print("Image from raw bytes");
    bytes_buf2 = io.BytesIO();
    pil_image.save(bytes_buf2, format="PNG");
    raw_bytes = bytes_buf2.getvalue();
    image5 = Image(raw_bytes);

    print("Image from memoryview");
    mv = memoryview(raw_bytes);
    image6 = Image(mv);

    print("Image from data URL");
    bytes_buf3 = io.BytesIO();
    pil_image.save(bytes_buf3, format="PNG");
    b64 = base64.b64encode(bytes_buf3.getvalue()).decode("utf-8");
    data_url = "data:image/png;base64," + b64;
    image7 = Image(data_url);

    print("Image from PathLike");
    p = Path(img_file_path);
    image8 = Image(p);

    print("Image from file-like without getvalue");
    # Use a BufferedReader to simulate a stream lacking getvalue
    tmp_buf = io.BytesIO();
    pil_image.save(tmp_buf, format="PNG");
    reader = io.BufferedReader(io.BytesIO(tmp_buf.getvalue()));
    image9 = Image(reader);

    print("Image from bytearray");
    ba = bytearray(raw_bytes);
    image10 = Image(ba);

    print("Image from gs:// URL");
    image11 = Image("gs://bucket/path/alan_turing.png");

}
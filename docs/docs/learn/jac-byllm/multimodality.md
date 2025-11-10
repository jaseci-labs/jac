# Using Multi-modal Models

byLLM supports multimodal inputs including text, images, and videos. This section covers how byLLM handles multimodal inputs.

Images are supported in the default byLLM distribution. Video support requires installing byllm with the `video` extra:

```bash
pip install byllm[video]
```

## Image

byLLM supports image inputs through the `Image` format. Images can be provided as input to byLLM functions or methods:

```jac
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

'Personality of the Person'
enum Personality {
   INTROVERT,
   EXTROVERT
}

sem Personality.INTROVERT = 'Person who is shy and reticent';
sem Personality.EXTROVERT = 'Person who is outgoing and socially confident';



obj Person {
    has full_name: str,
        yod: int,
        personality: Personality;
}

def get_person_info(img: Image) -> Person by llm();

with entry {
    image = Image("photo.jpg");
    person_obj = get_person_info(image);
    print(person_obj);
}
```

Input Image :
[person.png](https://rarehistoricalphotos.com/wp-content/uploads/2022/06/albert-einstein-tongue-3.webp)


??? example "Output"
    Person(full_name='Albert Einstein', yod=1955, personality=Personality.INTROVERT)

In this example, an image of a person is provided as input to the `get_person_info` method. The method returns a `Person` object containing the extracted information from the image.

### More ways to pass images

`Image` accepts multiple input forms beyond file paths:

- URLs: `http://`, `https://`, `gs://` (left as-is)
- Data URLs: `data:image/...;base64,...` (left as-is)
- Path-like: `pathlib.Path` (resolved to a local file)
- In-memory: `bytes`, `bytearray`, `memoryview`, `io.BytesIO` or any file-like object returning bytes
- PIL: `PIL.Image.Image`

Python example for in-memory usage:

```jac
import from byllm {Image}
import io;
Import from PIL {Image as PILImage}

with entry {
    pil_img = PILImage.open("photo.jpg");

    # BytesIO buffer
    buf = io.BytesIO();
    pil_img.save(buf, format="PNG");
    img_a = Image(buf);

    # Raw bytes
    raw = buf.getvalue();
    img_b = Image(raw);

    # PIL image instance
    img_c = Image(pil_img);

    # You can also pass data URLs and gs:// links directly
    img_d = Image("data:image/png;base64,<...>");
    img_e = Image("gs://bucket/path/image.png");
}
```

## Video

byLLM supports video inputs through the `Video` format. Videos can be provided as input to byLLM functions or methods:

```jac
import from byllm.lib { Model, Video }

glob llm = Model(model_name="gpt-4o");

def explain_the_video(video: Video) -> str by llm();

with entry {
    video_file_path = "SampleVideo_1280x720_2mb.mp4";
    target_fps = 1
    video = Video(path=video_file_path, fps=target_fps);
    print(explain_the_video(video));
}
```

Input Video:
[SampleVideo_1280x720_2mb.mp4](https://github.com/Jaseci-Labs/jaseci/raw/refs/heads/main/jac-byllm/tests/fixtures/SampleVideo_1280x720_2mb.mp4)


??? example "Output"
    The video features a large rabbit emerging from a burrow in a lush, green environment. The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere.

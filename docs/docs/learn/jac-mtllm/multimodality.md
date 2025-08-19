# Using Multi-modal Models

MTLLM supports multimodal inputs including text, images, and videos. This section covers how MTLLM handles multimodal inputs.

Images are supported in the default MTLLM distribution. Video support requires installing mtllm with the `video` extra:

```bash
pip install mtllm[video]
```

## Image

MTLLM supports image inputs through the `Image` format. Images can be provided as input to MTLLM functions or methods:

```jac
import from mtllm.llm { Model, Image }

glob llm = Model(model_name="gpt-4o");

'Personality of the Person'
enum Personality {
   INTROVERT = "Introvert",
   EXTROVERT = "Extrovert"
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

## Video

MTLLM supports video inputs through the `Video` format. Videos can be provided as input to MTLLM functions or methods:

```jac
import from mtllm { Model, Video }

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
[SampleVideo_1280x720_2mb.mp4](https://github.com/Jaseci-Labs/jaseci/raw/refs/heads/main/jac-mtllm/tests/fixtures/SampleVideo_1280x720_2mb.mp4)


??? example "Output"
    The video features a large rabbit emerging from a burrow in a lush, green environment. The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere.

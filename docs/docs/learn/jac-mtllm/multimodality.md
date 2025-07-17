# Using Multi-modal Models

For MTLLM to have actual neurosymbolic powers, it needs to be able to handle multimodal inputs and outputs. This means that it should be able to understand text, images, and videos. In this section, we will discuss how MTLLM can handle multimodal inputs.

Images are directly supported in the default distribution of MTLLM. However, videos are not supported by default. To use videos, you need to install mtllm with the `video` extra. You can do this by running the following command:

```bash
pip install mtllm[video]
```

## Image

MTLLM can handle images as inputs. You can provide an image as input to the MTLLM Function or Method using the `Image` format of mtllm. Here is an example of how you can provide an image as input to the MTLLM Function or Method:

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

Input Image (person.png):
![person.png](https://rarehistoricalphotos.com/wp-content/uploads/2022/06/albert-einstein-tongue-3.webp)


??? example "Output"
    Person(full_name='Albert Einstein', yod=1955, personality=Personality.INTROVERT)

In the above example, we have provided an image of a person ("Albert Einstein") as input to the `get_person_info` method. The method returns the information of the person in the image. The output of the method is a `Person` object with the name, year of death, and personality of the person in the image.

## Video

Similarly, MTLLM can handle videos as inputs. You can provide a video as input to the MTLLM Function or Method using the `Video` format of mtllm. Here is an example of how you can provide a video as input to the MTLLM Function or Method:

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

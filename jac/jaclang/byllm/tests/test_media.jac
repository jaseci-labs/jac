"""Image and video inputs: how a media argument reaches the model.

Assert on the message blocks byLLM actually sent, not on a rendered string.
"""

import os;
import from jaclang.byllm.lib { Image, Video }
import from jaclang.byllm.lib { MockLLM }
import from support_tests {
    prompt_text,
    data_url,
    media_blocks,
    need,
    roles,
    say,
    user_blocks
}

glob FIXTURE_DIR: str = os.path.join(os.path.dirname(__file__), "fixtures");


enum Personality { INTROVERT = "Introvert", EXTROVERT = "Extrovert" }

obj Person {
    has full_name: str,
        year_of_death: str,
        personality: Personality;
}


test "an image argument is inlined in its own format, under a system prompt" {
    need("PIL", "Pillow");
    # (file, expected data-url mime). A webp must not be transcoded to jpeg.
    for (filename, mime) in [
        ("math_question.jpg", "data:image/jpeg;base64,"),
        ("webp_image_of_person.webp", "data:image/webp;base64,")
    ] {
        llm = MockLLM(outputs=[say("answered")]);

        def describe(question_img: Image) -> str by llm();

        assert describe(Image(os.path.join(FIXTURE_DIR, filename))) == "answered";
        assert roles(llm) == ["system", "user"] , f"{filename}: got {roles(llm)}";

        blocks = user_blocks(llm);
        assert blocks[0]["type"] == "text" , f"{filename}: got {blocks[0]}";
        assert "describe" in blocks[0]["text"] , (
            f"{filename}: the caller name introduces the argument, got {blocks[0][
                'text'
            ][:60]!r}"
        );

        images = media_blocks(llm);
        assert len(images) == 1 , f"{filename}: expected one image block, got {len(
            images
        )}";
        assert data_url(images[0]).startswith(mime) , (
            f"{filename}: expected {mime}, got {data_url(images[0])[:40]!r}"
        );
    }
}


test "an image answer is parsed into its declared type" {
    need("PIL", "Pillow");
    llm = MockLLM(
        outputs=[
            {
                "full_name": "Albert Einstein",
                "year_of_death": "1955",
                "personality": Personality.EXTROVERT.value
            }
        ]
    );

    def get_person_info(image_content: Image) -> Person by llm();

    person = get_person_info(
        Image(os.path.join(FIXTURE_DIR, "webp_image_of_person.webp"))
    );
    assert person.full_name == "Albert Einstein" , f"got {person!r}";
    assert person.year_of_death == "1955" , f"got {person!r}";
    assert person.personality == Personality.EXTROVERT , f"got {person.personality!r}";
}


test "a video argument is sampled into several inlined frames" {
    need("cv2", "OpenCV");
    explanation = (
        "The video features a large rabbit emerging from a burrow in a lush, "
        "green environment."
    );
    llm = MockLLM(outputs=[say(explanation)]);

    def explain_the_video(video: Video) -> str by llm();

    result = explain_the_video(
        Video(path=os.path.join(FIXTURE_DIR, "SampleVideo_1280x720_2mb.mp4"), fps=1)
    );
    assert result == explanation;

    frames = media_blocks(llm);
    assert len(frames) > 1 , (
        f"a video should sample several frames, got {len(frames)}: sampling is a no-op"
    );
    for (i, frame) in enumerate(frames) {
        assert data_url(frame).startswith("data:image/") , (
            f"frame {i} must be an inlined image, got {data_url(frame)[:60]!r}"
        );
    }
}


# `sem` is module-level, so this pair sits beside its test.
glob _sem_llm = MockLLM(outputs=[say("A hot air balloon.")]);

def _describe_image(img: Image) -> str by _sem_llm();

sem _describe_image.img = "User-attached image to describe.";


test "an image parameter carrying a sem still encodes, and the sem is dropped" {
    # Subject: a `sem <fn>.<param>` beside an Image parameter must not break
    # Message.to_dict, which it used to.
    #
    # It also pins a gap. The parameter sem never reaches the model: the user
    # turn is the caller name and the image, and the sem text appears in no
    # message. A function-level sem does reach the prompt (test_prompting.jac
    # asserts that), so this is specific to parameter sems. Reported on #9002.
    # Flip the last assertion when that is fixed.
    need("PIL", "Pillow");
    result = _describe_image(Image(os.path.join(FIXTURE_DIR, "image.jpg")));
    assert "hot air balloon" in result.lower() , f"got {result!r}";

    images = media_blocks(_sem_llm);
    assert len(images) == 1 , f"the image must still be inlined, got {len(
        images
    )} blocks";
    assert data_url(images[0]).startswith("data:image/jpeg;base64,");

    assert "User-attached image to describe." not in prompt_text(_sem_llm) , (
        "parameter sems now reach the prompt: delete this assertion and assert "
        "the sem is present instead"
    );
}


test "every accepted image source becomes a usable url" {
    need("PIL", "Pillow");
    import base64;
    import io;
    import from pathlib { Path }
    import from PIL { Image as PILImage }
    jpg = os.path.join(FIXTURE_DIR, "alan-m-turing.jpg");
    pil = PILImage.open(jpg);

    def png_bytes -> bytes {
        buf = io.BytesIO();
        pil.save(buf, format="PNG");
        return buf.getvalue();
    }
    raw = png_bytes();
    data_url = "data:image/png;base64," + base64.b64encode(raw).decode("utf-8");

    # (label, what the caller hands to Image(), what the url must start with).
    # A remote or data url passes through untouched; everything else is read and
    # inlined.
    for (label, source, prefix) in [
        ("PIL Image", pil, "data:image/"),
        ("file path", jpg, "data:image/jpeg"),
        ("PathLike", Path(jpg), "data:image/jpeg"),
        ("raw bytes", raw, "data:image/"),
        ("bytearray", bytearray(raw), "data:image/"),
        ("memoryview", memoryview(raw), "data:image/"),
        ("BytesIO", io.BytesIO(raw), "data:image/"),
        ("stream without getvalue", io.BufferedReader(io.BytesIO(raw)), "data:image/"),
        ("data url", data_url, "data:image/png"),
        ("http url", "https://example.com/turing.jpg", "https://"),
        ("gs url", "gs://bucket/path/turing.png", "gs://")
    ] {
        url = str(Image(source).url);
        assert url.startswith(prefix) , f"{label}: expected {prefix}, got {url[:48]!r}";
    }
}

# Multimodal AI

Modern vision-capable LLMs (like GPT-4o and Gemini) can understand images and videos alongside text. byLLM integrates this capability through the `Image` and `Video` types -- you pass them as parameters to any `by llm()` function, and the LLM "sees" the visual content when generating its response.

`Image` is also a return type: declare it and the call generates an image instead of answering in text.

This enables powerful use cases: extracting structured data from photos (receipts, documents, diagrams), classifying images, describing scenes, analyzing video content, generating artwork from a typed function, and combining visual understanding with text processing. All the structured output patterns from the previous tutorial (enums, objects, lists) work with multimodal inputs, so you can extract typed data directly from images.

> **Prerequisites**
>
> - Completed: [Structured Outputs](structured-outputs.md)
> - Time: ~25 minutes

---

## Installation

Images are supported in the default byLLM distribution:

```bash
jac install byllm
```

For video support, install with the `video` extra:

```bash
jac install 'byllm[video]'
```

---

## Working with Images

byLLM supports image inputs through the `Image` type. Images can be provided as input to any `by llm()` function or method.

!!! tip "Model for vision tasks"
    Vision tasks require a vision-capable model like `anthropic/claude-sonnet-4-6`. Set it in your `jac.toml`:
    ```toml
    [byllm.model]
    default_model = "anthropic/claude-sonnet-4-6"
    ```

### Basic Example

```jac
import from jaclang.byllm.lib { Image }

"""Describe what you see in this image."""
def describe_image(img: Image) -> str by llm();

with entry {
    image = Image("photo.jpg");
    description = describe_image(image);
    print(description);
}
```

### Structured Output from Images

Combine image input with structured outputs for powerful data extraction:

```jac
import from jaclang.byllm.lib { Image }

enum Personality {
    INTROVERT,
    EXTROVERT
}

sem Personality.INTROVERT = "Person who is shy and reticent";
sem Personality.EXTROVERT = "Person who is outgoing and socially confident";

obj Person {
    has full_name: str;
    has year_of_death: int;
    has personality: Personality;
}

"""Extract person information from the image."""
def get_person_info(img: Image) -> Person by llm();

with entry {
    image = Image("einstein.jpg");
    person = get_person_info(image);
    print(f"Name: {person.full_name}");
    print(f"Year of Death: {person.year_of_death}");
    print(f"Personality: {person.personality}");
}
```

**Output:**

```
Name: Albert Einstein
Year of Death: 1955
Personality: Personality.INTROVERT
```

---

## Image Input Formats

The `Image` type accepts multiple input formats:

| Format | Example |
|--------|---------|
| File path | `Image("photo.jpg")` |
| URL (http/https) | `Image("https://example.com/image.png")` |
| Google Cloud Storage | `Image("gs://bucket/path/image.png")` |
| Data URL | `Image("data:image/png;base64,...")` |
| PIL Image | `Image(pil_image)` |
| Bytes | `Image(raw_bytes)` |
| BytesIO | `Image(bytes_io_buffer)` |
| pathlib.Path | `Image(Path("photo.jpg"))` |

> **Note**: All eight forms are accepted at runtime. Only the string-valued forms (file paths, URLs, GCS URIs, data URLs) are statically verified by `jac check` today; the `PIL.Image`, `bytes`, `BytesIO`, and `pathlib.Path` forms work through duck typing and may produce `E1053` warnings until the `Image` constructor stub is widened.

### In-Memory Usage

```jac
import from jaclang.byllm.lib { Image }
import io;
import from PIL { Image as PILImage }

with entry {
    # Load with PIL
    pil_img = PILImage.open("photo.jpg");

    # From BytesIO buffer
    buf = io.BytesIO();
    pil_img.save(buf, format="PNG");
    img_from_buffer = Image(buf);

    # From raw bytes
    raw = buf.getvalue();
    img_from_bytes = Image(raw);

    # From PIL image directly
    img_from_pil = Image(pil_img);

    # From URLs
    img_from_url = Image("https://example.com/image.png");
    img_from_gs = Image("gs://bucket/path/image.png");
}
```

---

## Generating Images

The same `Image` type is also a return type. Declare it and the call becomes an
image-generation call instead of a chat completion: byLLM builds the prompt the
way it always does - from the docstring, the `sem` strings and the argument
values - sends it to the image model, and hands the result back as an `Image`.

!!! tip "Model for generation"
    Generation needs an image model, not a chat model. Name one on the call
    rather than changing your default:
    ```jac
    import from jaclang.byllm.lib { Model }
    glob painter = Model(model_name="dall-e-3");
    ```

```jac
import from jaclang.byllm.lib { Image, Model }

glob painter = Model(model_name="dall-e-3");

"""A flat vector poster, bold shapes, no text."""
def draw_poster(subject: str, mood: str) -> Image by painter();

with entry {
    poster = draw_poster("a hot air balloon over Kandy", "calm");
    print(poster.url);
}
```

What comes back is an ordinary `Image`, so it goes straight into a vision call:

```jac
"""Would this poster read clearly on a phone screen?"""
def critique(poster: Image) -> str by llm();

with entry {
    print(critique(draw_poster("a tuk-tuk in the rain", "playful")));
}
```

### Several Images at Once

Return `list[Image]` and pass `n` to keep every image the provider sent:

```jac
def draw_variants(subject: str) -> list[Image] by painter(n=3, size="1024x1024");

with entry {
    for (i, shot) in enumerate(draw_variants("a kingfisher on a wire")) {
        print(f"variant {i}: {shot.url[:48]}");
    }
}
```

### Generation Parameters

| Parameter | Description |
|-----------|-------------|
| `n` | How many images to generate |
| `size` | Pixel size, e.g. `"1024x1024"` |
| `quality` | Provider quality tier, e.g. `"hd"` |
| `style` | Provider style, e.g. `"vivid"` |
| `response_format` | `"b64_json"` (default) or `"url"` |
| `user` | End-user identifier for provider-side abuse tracking |
| `timeout` | Request timeout in seconds |

byLLM asks for `b64_json` by default, so the `Image` you get back holds the
bytes as a data URL instead of a provider URL that expires an hour later. Pass
`response_format="url"` if you would rather keep the hosted URL.

`system_prompt`, from `jac.toml` or from the call, is prepended to the prompt.
byLLM's built-in chat persona is dropped for an image return, so it does not
steer the image model. A custom `base_url` is honoured the same way it is on a
completion.

### What Generation Cannot Do

- `tools=` and `stream=` are refused with a `ConfigurationError`: generation is
  one call, with nothing to stream and no loop to run tools in.
- An `Image` or `Video` argument cannot be sent alongside an image return. The
  generation endpoint takes text only, so there is no image editing yet.
- Generation goes through LiteLLM; the `proxy` and `http_client` transports do
  not carry it.

---

## Working with Videos

byLLM supports video inputs through the `Video` type. Videos are processed by extracting frames at a specified rate.

### Basic Example

```jac
import from jaclang.byllm.lib { Video }

"""Describe what happens in this video."""
def explain_video(video: Video) -> str by llm();

with entry {
    video = Video(path="sample_video.mp4", fps=1);
    explanation = explain_video(video);
    print(explanation);
}
```

**Output:**

```
The video features a large rabbit emerging from a burrow in a lush, green
environment. The rabbit stretches and yawns, seemingly enjoying the morning.
The scene is set in a vibrant, natural setting with bright skies and trees,
creating a peaceful and cheerful atmosphere.
```

### Video Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | str | Path to the video file |
| `fps` | int | Frames per second to extract (default: 1) |

Lower `fps` values extract fewer frames, reducing token usage. Higher values provide more temporal detail.

```jac
import from jaclang.byllm.lib { Video }

with entry {
    # Extract 1 frame per second (good for most cases)
    video = Video(path="video.mp4", fps=1);

    # Extract 2 frames per second (more detail)
    video = Video(path="video.mp4", fps=2);
}
```

---

## Practical Examples

### Receipt Analyzer

```jac
import from jaclang.byllm.lib { Image }

obj LineItem {
    has description: str;
    has quantity: int;
    has price: float;
}

obj Receipt {
    has store_name: str;
    has date: str;
    has items: list[LineItem];
    has total: float;
}

"""Extract all information from this receipt image."""
def parse_receipt(img: Image) -> Receipt by llm();

with entry {
    receipt_image = Image("receipt.jpg");
    receipt = parse_receipt(receipt_image);

    print(f"Store: {receipt.store_name}");
    print(f"Date: {receipt.date}");
    print("Items:");
    for item in receipt.items {
        print(f"  - {item.description}: ${item.price}");
    }
    print(f"Total: ${receipt.total}");
}
```

### Math Problem Solver

```jac
import from jaclang.byllm.lib { Image }

obj MathSolution {
    has problem: str;
    has steps: list[str];
    has answer: str;
}

"""Solve the math problem shown in the image."""
def solve_math(img: Image) -> MathSolution by llm();

with entry {
    problem_image = Image("math_problem.png");
    solution = solve_math(problem_image);

    print(f"Problem: {solution.problem}");
    print("Solution steps:");
    idx = 0;
    for step in solution.steps {
        print(f"  {idx+1}. {step}");
        idx += 1;
    }
    print(f"Answer: {solution.answer}");
}
```

### Video Content Analysis

```jac
import from jaclang.byllm.lib { Video }

obj VideoAnalysis {
    has summary: str;
    has key_events: list[str];
    has duration_estimate: str;
    has content_type: str;
}

"""Analyze this video and extract key information."""
def analyze_video(video: Video) -> VideoAnalysis by llm();

with entry {
    video = Video(path="presentation.mp4", fps=1);
    analysis = analyze_video(video);

    print(f"Summary: {analysis.summary}");
    print(f"Content Type: {analysis.content_type}");
    print("Key Events:");
    for event in analysis.key_events {
        print(f"  - {event}");
    }
}
```

---

## Combining with Tools

Multimodal inputs work with tool calling:

```jac
import from jaclang.byllm.lib { Image }

"""Search for products matching the description."""
def search_products(query: str) -> list[str] {
    # Simulated product search
    return [f"Product matching '{query}' - $29.99"];
}

"""Look at the image and find similar products."""
def find_similar_products(img: Image) -> str by llm(
    tools=[search_products]
);

with entry {
    product_image = Image("shoe.jpg");
    results = find_similar_products(product_image);
    print(results);
}
```

---

## Key Takeaways

| Concept | Usage |
|---------|-------|
| Image input | `Image("path.jpg")` or `Image(url)` |
| Image output | `def draw(...) -> Image by painter();` |
| Video input | `Video(path="video.mp4", fps=1)` |
| Structured output | Return objects/enums from images |
| Multiple formats | URLs, files, PIL, bytes all supported |
| Install video | `jac install 'byllm[video]'` |

---

## Next Steps

- [Agentic AI](agentic.md) - Combine multimodal with tool calling
- [byLLM Reference](../../reference/plugins/byllm.md) - Complete documentation

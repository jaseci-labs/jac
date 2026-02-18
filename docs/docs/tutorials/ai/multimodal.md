# Multimodal AI

Work with images and videos in byLLM.

> **Prerequisites**
>
> - Completed: [Structured Outputs](structured-outputs.md)
> - Time: ~25 minutes

---

## Installation

Images are supported in the default byLLM distribution:

```bash
pip install byllm
```

For video support, install with the `video` extra:

```bash
pip install byllm[video]
```

---

## Working with Images

byLLM supports image inputs through the `Image` type. Images can be provided as input to any `by llm()` function or method.

### Basic Example

```jac
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

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
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

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

### In-Memory Usage

```jac
import from byllm.lib { Image }
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

## Working with Videos

byLLM supports video inputs through the `Video` type. Videos are processed by extracting frames at a specified rate.

### Basic Example

```jac
import from byllm.lib { Model, Video }

glob llm = Model(model_name="gpt-4o");

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
import from byllm.lib { Video }

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
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

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
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

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
import from byllm.lib { Model, Video }

glob llm = Model(model_name="gpt-4o");

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
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

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
| Video input | `Video(path="video.mp4", fps=1)` |
| Structured output | Return objects/enums from images |
| Multiple formats | URLs, files, PIL, bytes all supported |
| Install video | `pip install byllm[video]` |

---

## Next Steps

- [Agentic AI](agentic.md) - Combine multimodal with tool calling
- [byLLM Reference](../../reference/plugins/byllm.md) - Complete documentation
- [Examples Gallery](../examples/index.md) - More multimodal examples

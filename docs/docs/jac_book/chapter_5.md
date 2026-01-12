# Chapter 5: Advanced AI Operations

!!! tip "Quick Reference"
    For a condensed AI integration reference, see the [AI Integration with byLLM Guide](../ai-integration/index.md) which covers MTP, providers, tools, and streaming.

---
In this chapter, you will learn to integrate advanced AI capabilities directly into your Jac applications using the byLLM (Meaning-Typed LLM) framework. We will build a multi-modal image analysis tool to demonstrate how Jac simplifies complex AI operations, including model configuration, context enhancement, and multi-modal data handling.

## byLLM Overview

---
byLLM (Meaning Typed LLM) is Jac's native AI integration framework. It transforms the way developers interact with Large Language Models by shifting from manual prompt engineering and complex API calls to a streamlined, function-based approach that is fully integrated with Jac's type system.

!!! success "byLLM Benefits"
    - **Zero Prompt Engineering**: Define function signatures, let AI handle implementation
    - **Type Safety**: AI functions integrate with Jac's type system
    - **Model Flexibility**: Switch between different AI models easily
    - **Multimodal Support**: Handle text, images, and audio seamlessly
    - **Built-in Optimization**: Automatic prompt optimization and caching

## Functions as Prompts

---
Up until this point, we've used Jac's functions to define behavior. However, what if we wanted to incorperate AI capabilities directly into our Jac applications? For example, lets say we're writing a poetry application that can generate poems based on a user supplied topic.

Since Jac is a super set of Python, we can create a function `write_poetry` that takes a topic as input and then make a call to an OpenAI model using its python or langchain library to generate the poem.

First, install the OpenAI Python package:

```bash
pip install openai
```

<br />
then set your OpenAI API key as an environment variable:

```bash
export OPENAI_API_KEY="your-api-key"
```

<br />
Now we can write our Jac code to integrate with OpenAI's API:

```jac
import from openai { OpenAI }

glob client = OpenAI();

""" Write a poem about topic """
def write_poetry(topic: str) -> str {
    response = client.responses.create(
        model="gpt-4.1-mini",
        input=f"Write a poem about {topic}."
    );
    return response.output_text;
}

with entry {
    poem = write_poetry("A serene landscape with mountains.");
    print(poem);
}
```

<br />

Finally, lets generate our poetic masterpiece by running the Jac code:

```console
$ jac run poetry.jac
Amidst the quiet, mountains rise,
Their peaks adorned with endless skies.
A tranquil breeze, a gentle stream,
Within this landscape, like a dream.

Soft whispers of the morning light,
Embrace the earth in pure delight.
A serene world, where hearts find peace,
In nature's hold, all worries cease.
```

<br />

Very nice! However, this approach requires manual API management (what if we want to switch to a different AI provider?), and we still have to write the prompt ourselves. Wouldn't it be great if we could just define the function signature and let the AI handle the rest? *Imagine a world where the function was the prompt?* Where we could simply declare a function and the AI would understand what to do? That's the power of byLLM.

Let's see how this works.

First we'll need to install the byLLM package:

```bash
pip install byllm
```

<br />
Next we replace the OpenAI import with that of the byLLM package

```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4.1-mini");
```

<br />
Instead of writing the function ourselves, we simply declare the function signature and use the `by` keyword to indicate that this function should be handled by the AI model referenced by `llm()`. The byLLM framework will automatically generate the appropriate prompt based on the function signature.
```jac
def write_poetry(topic: str) -> str by llm();
```

Finally, lets put it all together and run the Jac code:

```jac
# mt_poem.jac - Simple AI integration
import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4.1-mini");

""" Write a poem about topic """
def write_poetry(topic: str) -> str by llm();

with entry {
    poem = write_poetry("A serene landscape with mountains.");
    print(poem);
}
```

<br />

```console
$ jac run mt_poem.jac
Beneath the sky so vast and grand,
Mountains rise like ancient bands,
Whispers soft in tranquil air,
A serene landscape, calm and fair.

Colors blend in gentle hues,
Nature's brush with peaceful views,
Rivers sing and breezes dance,
In this quiet, soul’s expanse.
```

<br />

### Simple Image Captioning Tool

To further illustrate byLLM's capabilities, let's build a simple image captioning tool. This tool will analyze an image and generate a descriptive caption using an AI model.

First lets grab an image from upsplash to work with. You can use any image you like, but for this example, we'll use a photo of a french bulldog. Download the image and save it as `photo.jpg` in the same directory as your Jac code.

Next we'll make use of MLTLLM's `Image` function to handle image inputs. This function allows us to pass images directly to the AI model for analysis. We'll use OpenAI's `gpt-4o-mini` model for this task.

```jac
# image_captioning.jac - Simple Image Captioning Tool
import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o-mini");

"""Generate a detailed caption for the given image."""
def caption_image(image: Image) -> str by llm();

with entry {
    caption = caption_image(Image("photo.jpg"));
    print(caption);
}
```

<br />
Now we can run our Jac code to generate a caption for the image:
```console
$ jac run image_captioning.jac

A stylish French Bulldog poses confidently against a vibrant yellow backdrop,
showcasing its trendy black and yellow hoodie emblazoned with "WOOF." The pup's
playful demeanor is accentuated by a shiny gold chain draped around its neck,
adding a touch of flair to its outfit. With its adorable large ears perked up
and tongue playfully sticking out, this fashion-forward canine is ready to steal
the spotlight and capture hearts with its charm and personality.

```
<br />

## Model Declaration and Configuration
---
byLLM supports various AI models through the unified `Model` interface. For example, you can load multiple models like OpenAI's GPT-4, Google's Gemini, or any other compatible model in the same way. This allows you to switch between models easily without changing your code structure.

```jac
# basic_setup.jac
import from byllm.lib { Model, Image }

# Configure different models
glob text_model = Model(model_name="gpt-4o");
glob vision_model = Model(model_name="gpt-4-vision-preview");
glob gemini_model = Model(model_name="gemini-2.0-flash");
```

<br />

### Model Configuration Options

The `Model` class allows you to configure various parameters for your AI model, such as temperature, max tokens, and more. Here's an example of how to set up a model with custom parameters:

```jac
import from byllm.lib { Model, Image }

# Configure model with custom parameters
glob creative_model = Model(
    model_name="gpt-4.1-mini",
    temperature=0.9,  # More creative
    max_tokens=500,
    verbose=True      # Show prompts for debugging
);
```

<br />
Below is a breakdown of the parameters you can configure when creating a `Model` instance:

| Parameter         | Purpose / Description                                                                                      | Default Value / Example                     |
|-------------------|-----------------------------------------------------------------------------------------------------------|---------------------------------------------|
| `model`           | Specifies the name of the language model to use (e.g., "gpt-3.5-turbo", "claude-3-sonnet-20240229").      | Required (set during initialization)        |
| `api_base`        | Sets the base URL for the API endpoint. Used to override the default endpoint for the model provider.      | Optional                                   |
| `messages`        | List of formatted message objects (system/user/assistant) for the LLM prompt.                             | Required (built from function call context) |
| `tools`           | List of tool definitions for function/tool calls the LLM can invoke.                                       | Optional                                   |
| `response_format` | Specifies the output schema or format expected from the model (e.g., JSON schema, plain text).             | Optional                                   |
| `temperature`     | Controls randomness/creativity of the model output (higher = more random).                                 | 0.7 (if not explicitly set)                 |
| `max_tokens`      | Maximum number of tokens in the generated response. (Commented out; can be enabled)                        | 100 (if enabled and not set)                |
| `top_k`           | Limits sampling to the top K probable tokens. (Commented out; can be enabled)                              | 50 (if enabled and not set)                 |
| `top_p`           | Controls token selection by probability sum (nucleus sampling). (Commented out; can be enabled)            | 0.9 (if enabled and not set)                |

Here we have a simple example of how to use the `Model` class to create a model instance with custom parameters:

```jac
# model_config.jac
import from byllm.lib { Model, Image }

# Configure model with custom parameters
glob creative_model = Model(
    model_name="gpt-4.1-mini",
    temperature=0.9,  # More creative
    max_tokens=500,
    verbose=True      # Show prompts for debugging
);

glob precise_model = Model(
    model_name="gpt-4.1-mini",
    temperature=0.1,  # More deterministic
    max_tokens=200
);

"""Generate creative story from image."""
def create_story(image: Image) -> str by creative_model();

"""Extract factual information from image."""
def extract_facts(image: Image) -> str by precise_model();


with entry {
    # Example usage
    story = create_story(Image("photo.jpg"));
    print("Creative Story:", story);

    facts = extract_facts(Image("photo.jpg"));
    print("Extracted Facts:", facts);
}
```

<br />

## Updating the Image Captioning Tool

---
Let's progressively build an image captioning tool that demonstrates byLLM's capabilities.

```jac
# image_captioner.jac
import from byllm.lib { Model, Image }

glob vision_llm = Model(model_name="gpt-4o-mini");

obj ImageCaptioner {
    has name: str;

    """Generate a brief, descriptive caption for the image."""
    def generate_caption(image: Image) -> str by vision_llm();

    """Extract specific objects visible in the image."""
    def identify_objects(image: Image) -> list[str] by vision_llm();

    """Determine the mood or atmosphere of the image."""
    def analyze_mood(image: Image) -> str by vision_llm();
}

with entry {
    captioner = ImageCaptioner(name="AI Photo Assistant");
    image = Image("photo.jpg");

    # Generate basic caption
    caption = captioner.generate_caption(image);
    print(f"Caption: {caption}");

    # Identify objects
    objects = captioner.identify_objects(image);
    print(f"Objects found: {objects}");

    # Analyze mood
    mood = captioner.analyze_mood(image);
    print(f"Mood: {mood}");
}
```

<br />

```console
$ jac run image_captioner.jac

Caption: A stylish French Bulldog poses confidently in a black and yellow "WOOF" sweatshirt,
accessorized with a chunky gold chain against a vibrant yellow backdrop.

Objects found: ['dog', 'sweater', 'chain', 'yellow background']

Mood: The mood of the image is playful and cheerful. The bright yellow background and
the stylish outfit of the dog contribute to a fun and lighthearted atmosphere.
```

<br />

## Semantic Strings and Context Enhancement

---
**Semantic strings** provide additional context to AI functions via the `sem` keyword, allowing for more nuanced understanding without cluttering your code. They're particularly useful for domain-specific applications.

```jac
# enhanced_captioner.jac
import from byllm.lib { Model, Image }

glob vision_llm = Model(model_name="gpt-4.1-mini");

obj PhotoAnalyzer {
    has photographer_name: str;
    has style_preference: str;
    has image: Image;
}

# Add semantic context for better AI understanding
sem PhotoAnalyzer = "Professional photo analysis tool for photographers";
sem PhotoAnalyzer.photographer_name = "Name of the photographer for personalized analysis";
sem PhotoAnalyzer.style_preference = "Preferred photography style (artistic, documentary, commercial)";


"""Generate caption considering photographer's style preference."""
def generate_styled_caption(pa: PhotoAnalyzer) -> str by vision_llm();

"""Provide technical photography feedback."""
def analyze_composition(pa: PhotoAnalyzer) -> list[str] by vision_llm();

"""Suggest improvements for the photo."""
def suggest_improvements(pa: PhotoAnalyzer) -> list[str] by vision_llm();


with entry {
    analyzer = PhotoAnalyzer(
        photographer_name="Alice",
        style_preference="artistic",
        image=Image("photo.jpg")
    );

    # Generate styled caption
    caption = generate_styled_caption(analyzer);
    print(f"Styled caption: {caption}");

    # Analyze composition
    composition = analyze_composition(analyzer);
    print(f"Composition analysis: {composition}");

    # Get improvement suggestions
    suggestions = suggest_improvements(analyzer);
    print(f"Suggestions: {suggestions}");
}
```

<br />

## Testing and Error Handling

---
AI applications require robust error handling and testing strategies.

### Robust AI Integration

```jac
# robust_ai.jac
import from byllm.lib { Model, Image }

glob reliable_llm = Model(model_name="gpt-4o", max_tries=3);

obj RobustCaptioner {
    has fallback_enabled: bool = True;

    """Generate caption with error handling."""
    def safe_caption(image_path: str) -> dict {
        try {
            caption = self.generate_caption_ai(image_path);
            return {
                "success": True,
                "caption": caption,
                "source": "ai"
            };
        } except Exception as e {
            if self.fallback_enabled {
                fallback_caption = f"Image analysis unavailable for {image_path}";
                return {
                    "success": False,
                    "caption": fallback_caption,
                    "source": "fallback",
                    "error": str(e)
                };
            } else {
                raise e;
            }
        }
    }

    """AI-powered caption generation."""
    def generate_caption_ai(image_path: str) -> str by reliable_llm();

    """Validate generated content."""
    def validate_caption(caption: str) -> bool {
        # Basic validation rules
        if len(caption) < 10 {
            return False;
        }
        if "error" in caption.lower() {
            return False;
        }
        return True;
    }
}

with entry {
    captioner = RobustCaptioner(fallback_enabled=True);

    # Test with different scenarios
    test_images = [
        Image("valid_photo.jpg"),
        Image("corrupted.jpg"),
        Image("missing.jpg")
    ];

    for image in test_images {
        result = captioner.safe_caption(image);

        if result["success"] {
            is_valid = captioner.validate_caption(result["caption"]);
            print(f"{image}: {result['caption']} (Valid: {is_valid})");
        } else {
            print(f"{image}: Failed - {result['error']}");
        }
    }
}
```

<br />

## Best Practices

---
!!! tip "AI Development Guidelines"
    - **Start Simple**: Begin with basic AI functions, add complexity gradually
    - **Use Semantic Strings**: Provide context without cluttering function signatures
    - **Handle Failures**: Always implement fallback strategies for AI functions
    - **Test Thoroughly**: AI outputs can be unpredictable, test with various inputs
    - **Optimize Models**: Choose appropriate models and parameters for your use case

## Key Takeaways

!!! summary "What We've Learned"
    **byLLM Integration:**

    - **Simple AI Functions**: Define AI capabilities with `by llm()` syntax
    - **Model Configuration**: Flexible model selection and parameter tuning
    - **Type Safety**: AI functions integrate seamlessly with Jac's type system
    - **Zero Prompt Engineering**: Function signatures become prompts automatically

    **Advanced Features:**

    - **Semantic Context**: Enhanced AI understanding through semantic strings
    - **Multimodal Support**: Seamless handling of images, text, and audio
    - **Error Handling**: Robust patterns for production AI applications
    - **Model Selection**: Easy switching between different AI providers and models

    **Practical Applications:**

    - **Content Generation**: Automated text and media analysis
    - **Data Processing**: Intelligent data transformation and extraction
    - **API Integration**: Direct AI integration without complex setup
    - **Scalable Architecture**: AI functions work in both local and cloud deployments

!!! tip "Try It Yourself"
    Enhance the image captioning tool by adding:
    - Batch processing for multiple images
    - Integration with cloud storage services
    - Custom model fine-tuning capabilities
    - Real-time image analysis from camera feeds

    Remember: AI functions in Jac are as easy to use as regular functions, but with the power of Large Language Models!

---

If you are interested in learning more about byLLM, check out [Quickstart to byLLM](../learn/jac-byllm/with_llm.md)

*Ready to learn about imports and modular programming? Continue to [Chapter 6: Imports System and File Operations](chapter_6.md)!*

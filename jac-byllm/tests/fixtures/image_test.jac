import from byllm.lib { MockLLM, Image }
import os;

glob llm = MockLLM(
    model_name="mockllm",
    config={
        "outputs": [
            'The image shows a hot air balloon shaped like a heart. It is red with white accents and is floating in the sky during either sunrise or sunset, as indicated by the warm light and colors in the clouds and sky. The scene conveys a sense of romance and adventure.',

        ]
    },
);

def explain_the_image(image: Image) -> str by llm();

with entry {
    image = Image(os.path.join(os.path.dirname(__file__), 'image.jpg'));
    print(explain_the_image(image));
}

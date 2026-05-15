"""Image parameter with an explicit `sem` declaration."""
import from byllm.lib { MockLLM, Image }
import os;

glob llm = MockLLM(
    model_name="mockllm",
    config={"outputs": ["A hot air balloon."]}
);

def describe_image(img: Image) -> str by llm();

sem describe_image.img = "User-attached image to describe.";

glob img = Image(os.path.join(os.path.dirname(__file__), 'image.jpg'));

with entry {
    result = describe_image(img);
    assert "hot air balloon" in result.lower();
    print("IMAGE_SEM_PASS");
}

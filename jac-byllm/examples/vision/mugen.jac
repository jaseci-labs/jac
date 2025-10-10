import from byllm { Model, Video }

glob llm = Model(model_name="gpt-4o");

"""
Mugen is a moving character
"""
def is_aligned(video: Video, text: str) -> bool by llm();

with entry {
    video = Video("mugen.mp4", 1);
    text = "Mugen jumps off and collects few coins.";
    print(is_aligned(video, text));
}

import from byllm.lib { Model, Video }

glob llm = Model(model_name="gpt-4o");

"""
Mugen is a moving character
"""
def is_aligned(video: Video, text: str) -> bool by llm();

glob
    video = Video("mugen.mp4", 1),
    text = "Mugen jumps off and collects few coins.";

with entry {
    print(is_aligned(video, text));
}

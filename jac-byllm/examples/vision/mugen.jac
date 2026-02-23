import from byllm.lib { Video }

"""
Mugen is a moving character
"""
def is_aligned(video: Video, text: str) -> bool by llm();

glob video = Video("mugen.mp4", 1),
     text = "Mugen jumps off and collects few coins.";

with entry {
    print(is_aligned(video, text));
}

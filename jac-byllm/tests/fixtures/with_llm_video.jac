import from byllm.lib { MockLLM, Video }
import os;


glob llm = MockLLM(
    model_name="mockllm",
    outputs = [
        'The video features a large rabbit emerging from a burrow in a lush, green environment. The rabbit stretches and yawns, seemingly enjoying the morning. The scene is set in a vibrant, natural setting with bright skies and trees, creating a peaceful and cheerful atmosphere.'
    ]
);

def explain_the_video(video: Video) -> str by llm();

with entry {
    video_file_path = os.path.join(os.path.dirname(__file__), "SampleVideo_1280x720_2mb.mp4");
    target_fps = 1;
    video = Video(path=video_file_path, fps=target_fps);
    print(explain_the_video(video));
}

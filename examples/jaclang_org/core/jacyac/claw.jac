import from "react" { useRef }
import from "@jac/runtime" { RemoteError }

obj ClawModel {
    has activity: Activity | None,
        job: JobView | None,
        tutorials: list[TutorialCard],
        tutorial: TutorialView | None,
        loading: bool,
        error: str,
        refresh: Callable[[], Coroutine[any, any, None]];
}

glob CLAW_POLL_MS: int = 3000;

def useClaw(view: str, focus: str) -> ClawModel;

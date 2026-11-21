import from "react" { useEffect, useRef }
import from "@jac/runtime" { BridgeError }

obj ClawModel {
    has activity: Activity | None,
        job: JobView | None,
        tutorials: list[TutorialCard],
        tutorial: TutorialView | None,
        loading: bool,
        error: str,
        refresh: Callable[[], None];
}

glob CLAW_POLL_MS: int = 3000;

def:pub useClaw(view: str, focus: str) -> ClawModel;

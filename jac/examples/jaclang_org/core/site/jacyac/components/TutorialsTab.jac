import from "lucide-react" {
    BookOpen,
    ArrowLeft,
    CircleCheck,
    CircleAlert,
    ShieldCheck
}
import from "@jac/runtime" { Link }

def:pub TutorialsTab(model: ClawModel, focus: str) -> JsxElement;

def TutorialRow(card: TutorialCard) -> JsxElement;

def TutorialDetail(view: TutorialView) -> JsxElement;

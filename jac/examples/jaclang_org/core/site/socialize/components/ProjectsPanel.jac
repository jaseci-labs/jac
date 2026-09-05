import from "lucide-react" { FolderGit2, Plus, AlertCircle, CheckCircle2 }
import from core.site.ui.button { Button }
import from core.site.ui.input { Input }
import from .ProjectCard { ProjectCard }
import from core.social_graph { Project }

def:pub ProjectsPanel(
    projects: list[Project],
    isMine: bool,
    avatars: dict[str, str],
    busy: bool,
    error: str,
    notice: str,
    onAdd: Callable[[str], None],
    onRemove: Callable[[str], None],
    onRescore: Callable[[str], None],
    onViewOwner: Callable[[str], None],
) -> JsxElement {
    has url: str = "";

    def submit(e: FormEvent) {
        e.preventDefault();
        if url.strip() and not busy {
            onAdd(url.strip());
            url = "";
        }
    }

    <section className="border-t border-border" id="lx-projects">
        <div className="flex items-center gap-2 px-4 pt-4 pb-2">
            <FolderGit2 size={16} className="text-primary"/>
            <span className="font-display text-base font-extrabold">Projects</span>
            <span className="text-sm text-muted-foreground">{str(len(projects))}</span>
        </div>
        {if isMine {
            <form onSubmit={submit} className="flex flex-col gap-2 px-4 pb-3">
                <div className="flex gap-2">
                    <Input
                        id="lx-project-url"
                        placeholder="github.com/owner/repo"
                        value={url}
                        disabled={busy}
                        onChange={lambda (e: ChangeEvent) { url = e.target.value; }}
                    />
                    <Button
                        type="submit"
                        id="lx-add-project"
                        className="shrink-0 font-semibold"
                        disabled={busy or not url.strip()}
                    >
                        <Plus size={16}/>
                        {"Scoring..." if busy else "Add"}
                    </Button>
                </div>
                <p className="text-xs text-muted-foreground">
                    Public GitHub repos only. Every project is scored by Ninja Scores when you add it.
                </p>
                {if error {
                    <div
                        className="flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive"
                        id="lx-project-error"
                    >
                        <AlertCircle size={16} className="shrink-0"/>
                        <span>{error}</span>
                    </div>
                }}
                {if notice {
                    <div
                        className="flex items-center gap-2 rounded-lg border border-primary/30 bg-primary/10 px-3 py-2 text-sm text-foreground"
                        id="lx-project-notice"
                    >
                        <CheckCircle2 size={16} className="shrink-0 text-primary"/>
                        <span>{notice}</span>
                    </div>
                }}
            </form>
        }}
        {if len(projects) == 0 {
            <p className="px-4 pb-4 text-sm text-muted-foreground">
                {"Add a GitHub repo above to show what you are building."
                    if isMine
                    else "No projects yet."}
            </p>
        }}
        {for p in projects {
            <ProjectCard
                key={jid(p)}
                project={p}
                {isMine}
                showOwner={False}
                {avatars}
                {busy}
                {onRemove}
                {onRescore}
                {onViewOwner}
            />
        }}
    </section>
}

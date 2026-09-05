import from "lucide-react" {
    Star,
    GitFork,
    ExternalLink,
    Trash2,
    RefreshCw,
    AlertTriangle,
    FolderGit2
}
import from core.site.ui.button { Button }
import from core.site.ui.badge { Badge }
import from core.site.ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from core.site.ui.alert_dialog {
    AlertDialog,
    AlertDialogTrigger,
    AlertDialogContent,
    AlertDialogHeader,
    AlertDialogFooter,
    AlertDialogTitle,
    AlertDialogDescription,
    AlertDialogAction,
    AlertDialogCancel
}
import from core.utils { cn }
import from core.leaderboard.format { belt_class, belt_label, time_ago }
import from core.social_graph { Project }
import from ..identity { handle_of, initial_of, avatar_of, project_error_message }

def:pub ProjectCard(
    project: Project,
    isMine: bool,
    showOwner: bool,
    avatars: dict[str, str],
    busy: bool,
    onRemove: Callable[[str], None],
    onRescore: Callable[[str], None],
    onViewOwner: Callable[[str], None],
) -> JsxElement {
    scored = project.status == "scored";
    owner_handle = handle_of(project.owner_username);
    permalink = (project.html_url + "/tree/" + project.scored_sha)
        if project.scored_sha
        else project.html_url;

    <div
        className="lx-fade-up flex gap-3 border-b border-border px-4 py-3 transition-colors hover:bg-muted/30"
        data-project={project.full}
    >
        <div
            className="flex size-11 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-muted text-muted-foreground"
        >
            {if project.avatar_url {
                <img
                    src={project.avatar_url}
                    alt={project.owner}
                    className="size-full object-cover"
                />
            } else {
                <FolderGit2 size={20}/>
            } }
        </div>
        <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                <a
                    href={permalink}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex min-w-0 items-center gap-1 font-display font-bold text-foreground hover:underline"
                >
                    <span className="truncate">{project.full}</span>
                    <ExternalLink size={13} className="shrink-0 text-muted-foreground"/>
                </a>
                {if scored {
                    <Badge className={cn("rounded-full", belt_class(project.belt))}>
                        {belt_label(project.belt)}
                    </Badge>
                    <span className="font-mono text-sm font-semibold text-primary">
                        {str(project.score)} pts
                    </span>
                } else {
                    <Badge variant="outline" className="rounded-full">
                        {"Scoring" if project.status == "pending" else "Not scored"}
                    </Badge>
                } }
            </div>
            {if project.description {
                <p className="mt-0.5 line-clamp-2 text-sm text-foreground/85">
                    {project.description}
                </p>
            }}
            {if scored {
                <div
                    className="mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground"
                >
                    <span className="inline-flex items-center gap-1">
                        <Star size={12}/>
                        {str(project.stars)}
                    </span>
                    <span className="inline-flex items-center gap-1">
                        <GitFork size={12}/>
                        {str(project.forks)}
                    </span>
                    <span>{str(project.jac_lines)} Jac lines</span>
                    <span>{str(project.jac_pct)}% Jac</span>
                    {if project.scored_at {
                        <span>scored {time_ago(project.scored_at)}</span>
                    }}
                </div>
            }}
            {if scored and project.features {
                <div className="mt-1.5 flex flex-wrap gap-1">
                    {for f in project.features {
                        <Badge
                            key={f}
                            variant="secondary"
                            className="rounded-full font-mono text-[10px] uppercase"
                        >
                            {f}
                        </Badge>
                    }}
                </div>
            }}
            {if not scored and project.error and isMine {
                <div
                    className="mt-1.5 flex items-start gap-1.5 text-xs text-destructive"
                >
                    <AlertTriangle size={13} className="mt-0.5 shrink-0"/>
                    <span>{project_error_message(project.error)}</span>
                </div>
            } elif not scored {
                <p className="mt-1.5 text-xs text-muted-foreground">Not scored yet.</p>
            } }
            {if showOwner {
                <button
                    type="button"
                    className="mt-2 inline-flex items-center gap-1.5 rounded-full bg-muted/60 py-0.5 pl-0.5 pr-2.5 text-xs text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                    onClick={lambda { onViewOwner(project.owner_username); }}
                >
                    <Avatar className="size-5">
                        <AvatarImage
                            src={avatar_of(avatars, project.owner_username)}
                            alt={owner_handle}
                        />
                        <AvatarFallback className="text-[0.55rem]">
                            {initial_of(owner_handle)}
                        </AvatarFallback>
                    </Avatar>
                    {"@" + owner_handle}
                </button>
            }}
        </div>
        {if isMine {
            <div className="flex shrink-0 flex-col items-end gap-1">
                <Button
                    variant="ghost"
                    size="icon"
                    title="Score again"
                    className="size-8 text-muted-foreground hover:text-foreground"
                    disabled={busy}
                    onClick={lambda { onRescore(jid(project)); }}
                >
                    <RefreshCw size={15} className={"animate-spin" if busy else ""}/>
                </Button>
                <AlertDialog>
                    <AlertDialogTrigger asChild={True}>
                        <Button
                            variant="ghost"
                            size="icon"
                            title="Remove project"
                            className="size-8 text-muted-foreground hover:bg-destructive/10 hover:text-destructive"
                            disabled={busy}
                        >
                            <Trash2 size={15}/>
                        </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                        <AlertDialogHeader>
                            <AlertDialogTitle>Remove this project?</AlertDialogTitle>
                            <AlertDialogDescription>
                                {project.full} will no longer show on your profile or in Explore. You can add it again later.
                            </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                            <AlertDialogCancel>Cancel</AlertDialogCancel>
                            <AlertDialogAction
                                className="bg-destructive text-white hover:bg-destructive/90"
                                onClick={lambda { onRemove(jid(project)); }}
                            >
                                Remove
                            </AlertDialogAction>
                        </AlertDialogFooter>
                    </AlertDialogContent>
                </AlertDialog>
            </div>
        }}
    </div>
}

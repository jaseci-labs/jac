"""Community gallery — browse, clone, and remove shared JacPack projects."""
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.badge { Badge }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.alert { Alert }
import from ..ui.spinner { Spinner }
import from ..ui.skeleton { Skeleton }
import from ..ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from ..ui.avatar { Avatar, AvatarFallback }
import from ..ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription }
import from ..ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from "..ui.alert-dialog" {
    AlertDialog, AlertDialogContent, AlertDialogHeader,
    AlertDialogTitle, AlertDialogDescription,
    AlertDialogFooter, AlertDialogCancel, AlertDialogAction
}
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Search01Icon, Copy01Icon, Delete02Icon, Globe02Icon,
    Tag01Icon, ArrowRight01Icon
}

"""Single community gallery card."""
def:pub CommunityCard(props: Any) -> Any {
    item = props.item;
    currentUserId = props.currentUserId;
    onClone = props.onClone;
    onRemove = props.onRemove;

    authorInitial = (item.display_name.charAt(0).toUpperCase() if item.display_name else "A");

    return <Card className="overflow-hidden cursor-default transition-shadow duration-150 hover:border-primary/25 hover:shadow-lg hover:shadow-black/20">
        <div className="relative w-full h-[170px] bg-background flex items-center justify-center overflow-hidden border-b border-border">
            <img src="/static/assets/logo-builder.png" className="w-10 h-10 object-contain grayscale opacity-35 relative z-[1]" alt="" />
        </div>
        <CardContent className="flex flex-col gap-2 p-3">
            <div className="flex items-start justify-between gap-2">
                <div className="flex items-center gap-1.5 flex-1 min-w-0">
                    <div className="size-[7px] rounded-full bg-primary flex-shrink-0 mt-[5px]" />
                    <span className="text-sm font-semibold text-foreground truncate">{item.name}</span>
                </div>
                {item.user_id == currentUserId and <Button
                    variant="ghost" size="icon-xs"
                    className="text-destructive hover:text-destructive shrink-0"
                    onClick={lambda(e: Any) { e.stopPropagation(); onRemove(item.id); }}
                    title="Remove from community"
                >
                    <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                </Button>}
            </div>

            <div className="flex items-center gap-1.5">
                <Avatar className="size-4">
                    <AvatarFallback className="text-[9px] bg-primary/20 text-primary">{authorInitial}</AvatarFallback>
                </Avatar>
                <span className="text-muted-foreground text-[11px] leading-[1.4]">{"by @" + (item.display_name or "anonymous")}</span>
            </div>

            {item.description and <span className="text-xs text-muted-foreground line-clamp-2 leading-normal">
                {item.description}
            </span>}

            {item.tags and item.tags.length > 0 and <div className="flex items-center gap-1 flex-wrap">
                {item.tags.map(lambda tag: Any -> Any {
                    return <Badge key={tag} variant="secondary" className="text-[10px] font-mono px-1.5 py-0">{tag}</Badge>;
                })}
            </div>}

            <div className="flex items-center justify-between mt-1">
                <span className="text-muted-foreground text-[11px] leading-[1.4]">
                    {String.fromCharCode(9112) + " " + String(item.clone_count or 0) + " clones"}
                </span>
                <Button
                    size="sm"
                    variant="secondary"
                    onClick={lambda(e: Any) { e.stopPropagation(); onClone(item); }}
                >
                    <HugeiconsIcon icon={Copy01Icon} strokeWidth={2} className="size-3" />
                    {"Clone"}
                </Button>
            </div>
        </CardContent>
    </Card>;
}

"""Community gallery: search, tag filter, cards grid, clone modal."""
def:pub CommunityGallery(props: Any) -> Any {
    community = props.community;
    currentUserId = props.currentUserId;

    return <div className="p-7">
        <div className="flex flex-col gap-6 max-w-[960px] mx-auto">
            <div>
                <div className="flex items-center gap-2 mb-1">
                    <HugeiconsIcon icon={Globe02Icon} strokeWidth={2} className="size-5 text-primary" />
                    <span className="text-xl font-semibold text-foreground">{"Community"}</span>
                    <Badge variant="secondary" className="text-xs">{String(community.itemCount or community.items.length)}</Badge>
                </div>
                <span className="text-xs text-muted-foreground">{"Discover and clone open Jac projects"}</span>
            </div>

            <div className="flex items-center gap-3">
                <div className="relative flex-1">
                    <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
                    <Input
                        placeholder="Search community..."
                        value={community.searchQuery}
                        onChange={lambda e: Any {
                            setter = community.setSearchQuery;
                            setter.call(None, e.target.value);
                        }}
                        className="pl-8"
                    />
                </div>
                <Select
                    value={community.selectedTag or "all"}
                    onValueChange={lambda v: Any {
                        setter = community.setSelectedTag;
                        setter.call(None, (v == "all" and "" or v));
                    }}
                >
                    <SelectTrigger className="w-[140px]">
                        <HugeiconsIcon icon={Tag01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
                        <SelectValue placeholder="All tags" />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="all">{"All tags"}</SelectItem>
                        <SelectItem value="web">{"web"}</SelectItem>
                        <SelectItem value="api">{"api"}</SelectItem>
                        <SelectItem value="demo">{"demo"}</SelectItem>
                        <SelectItem value="game">{"game"}</SelectItem>
                        <SelectItem value="tool">{"tool"}</SelectItem>
                    </SelectContent>
                </Select>
            </div>

            {community.isLoading and <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {[1, 2, 3, 4, 5, 6].map(lambda k: int -> Any {
                    return <div key={String(k)} className="rounded-lg border border-border overflow-hidden">
                        <Skeleton className="w-full h-[170px] rounded-none" />
                        <div className="p-3 flex flex-col gap-2">
                            <Skeleton className="h-4 w-3/4" />
                            <Skeleton className="h-3 w-1/2" />
                            <div className="flex gap-1">
                                <Skeleton className="h-4 w-10" />
                                <Skeleton className="h-4 w-10" />
                            </div>
                        </div>
                    </div>;
                })}
            </div>}

            {not community.isLoading and community.items.length == 0 and
                <div className="flex flex-col items-center justify-center text-center pt-20 pb-16">
                    <div className="size-12 rounded-xl bg-muted flex items-center justify-center mb-4">
                        <HugeiconsIcon icon={Globe02Icon} strokeWidth={1.5} className="size-6 text-muted-foreground" />
                    </div>
                    <p className="text-sm font-medium text-foreground mb-1">{community.searchQuery and "No results for \"" + community.searchQuery + "\"" or "No community projects yet"}</p>
                    <p className="text-xs text-muted-foreground">{community.searchQuery and "Try a different search term or tag" or "Be the first to share a project!"}</p>
                </div>
            }

            {not community.isLoading and community.items.length > 0 and
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {community.items.map(lambda item: Any -> Any {
                        onCloneHandler = community.openCloneModal;
                        onRemoveHandler = community.confirmRemove;
                        return <CommunityCard
                            key={item.id}
                            item={item}
                            currentUserId={currentUserId}
                            onClone={onCloneHandler}
                            onRemove={onRemoveHandler}
                        />;
                    })}
                </div>
            }
        </div>

        <AlertDialog
            open={Boolean(community.removeConfirmId)}
            onOpenChange={lambda v: Any { if not v { community.cancelRemove(); } }}
        >
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>{"Remove from Community"}</AlertDialogTitle>
                    <AlertDialogDescription>{"Are you sure you want to remove this project from the community gallery? This action cannot be undone."}</AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel onClick={lambda { community.cancelRemove(); }}>{"Cancel"}</AlertDialogCancel>
                    <AlertDialogAction onClick={lambda { community.doRemove(); }} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">{"Remove"}</AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>

        <Dialog
            open={community.cloneModalOpen}
            onOpenChange={lambda v: Any { if not v { community.closeCloneModal(); } }}
        >
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"Clone Project"}</DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-4">
                    {community.cloneTarget and <div className="flex items-center gap-1.5">
                        <span className="text-sm text-muted-foreground">{"Cloning: "}</span>
                        <span className="text-sm text-foreground">{community.cloneTarget.name}</span>
                        <span className="text-xs text-muted-foreground">{"by @" + (community.cloneTarget.display_name or "anonymous")}</span>
                    </div>}
                    <div className="flex flex-col gap-2">
                        <Label>{"Project Name"}</Label>
                        <Input
                            placeholder="my-cloned-app"
                            value={community.cloneName}
                            onChange={lambda e: Any {
                                setter = community.setCloneName;
                                setter.call(None, e.target.value);
                            }}
                            disabled={community.isCloning}
                        />
                    </div>
                    {community.cloneError and <Alert variant="destructive">{community.cloneError}</Alert>}
                    <div className="flex justify-end gap-2">
                        <Button
                            variant="ghost"
                            onClick={lambda { community.closeCloneModal(); }}
                            disabled={community.isCloning}
                        >
                            {"Cancel"}
                        </Button>
                        <Button
                            disabled={not community.cloneName or community.isCloning}
                            onClick={lambda { community.doClone(); }}
                        >
                            {community.isCloning and <Spinner className="size-4" /> or None}
                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                            {"Clone to My Projects"}
                        </Button>
                    </div>
                </div>
            </DialogContent>
        </Dialog>
    </div>;
}

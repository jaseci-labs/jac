"""Environment variable panel — manage project .env vars."""

import from react { useEffect }
import from "..ui.scroll-area" { ScrollArea }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from "..ui.password-input" { PasswordInput }
import from ..ui.separator { Separator }
import from ..ui.spinner { Spinner }
import from ..ui.field { Field, FieldLabel }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Delete02Icon, PlusSignIcon, FloppyDiskIcon }

def:pub EnvVarPanel(props: Any) -> Any {
    settings = props.settings;

    has newProjectKey: str = "";
    has newProjectVal: str = "";

    useEffect(lambda {
        settings.loadProjectVars();
    }, []);

    def handleAddProjectVar() -> None {
        if not newProjectKey { return; }
        settings.addProjectVar(newProjectKey, newProjectVal);
        newProjectKey = "";
        newProjectVal = "";
    }

    return <ScrollArea className="h-[340px]">
        <div className="flex flex-col gap-3 p-4">
            <div className="flex items-start justify-between">
                <div className="flex flex-col gap-0.5">
                    <span className="text-sm font-semibold text-foreground">{"Project Variables"}</span>
                    <span className="text-xs text-muted-foreground">{".env in project directory"}</span>
                </div>
                <Button
                    size="sm"
                    variant="secondary"
                    onClick={lambda { settings.saveProjectVars(); }}
                    disabled={settings.projectVarsSaving}
                    className="mt-1"
                >
                    {settings.projectVarsSaving and <Spinner className="size-3" /> or <HugeiconsIcon icon={FloppyDiskIcon} strokeWidth={2} className="size-3" />}
                    {"Save"}
                </Button>
            </div>
            <Separator />
            {settings.projectVarsLoading and <Spinner className="size-3.5" /> or None}
            {settings.projectVars.map(lambda (v: Any) -> Any {
                vkey = v.key;
                return <div key={vkey} className="flex items-center gap-2 flex-nowrap">
                    <span
                        className="text-xs font-mono text-muted-foreground overflow-hidden text-ellipsis min-w-[120px] flex-shrink-0"
                    >{vkey}</span>
                    <PasswordInput
                        value={v.value}
                        onChange={lambda (e: Any) -> None { settings.updateProjectVar(vkey, e.target.value); }}
                        className="flex-1 font-mono text-xs"
                    />
                    <Button
                        size="icon-xs"
                        variant="ghost"
                        className="text-destructive hover:text-destructive shrink-0"
                        onClick={lambda { settings.deleteProjectVar(vkey); }}
                    >
                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                    </Button>
                </div>;
            })}
            {settings.projectVars.length == 0 and not settings.projectVarsLoading and <span className="text-xs text-muted-foreground">{"No project variables."}</span> or None}
            <div className="flex flex-col gap-2 mt-1">
                <Field>
                    <FieldLabel className="text-[11px] text-muted-foreground">{"Key"}</FieldLabel>
                    <Input
                        placeholder="MY_API_KEY"
                        value={newProjectKey}
                        onChange={lambda (e: Any) -> None { newProjectKey = e.target.value; }}
                        className="h-7 text-xs"
                    />
                </Field>
                <Field>
                    <FieldLabel className="text-[11px] text-muted-foreground">{"Value"}</FieldLabel>
                    <Input
                        placeholder="sk-..."
                        value={newProjectVal}
                        onChange={lambda (e: Any) -> None { newProjectVal = e.target.value; }}
                        className="h-7 text-xs"
                    />
                </Field>
                <Button
                    size="sm"
                    variant="secondary"
                    onClick={lambda { handleAddProjectVar(); }}
                    disabled={not newProjectKey}
                    className="w-full"
                >
                    <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-3.5" />
                    {"Add Variable"}
                </Button>
            </div>
            {settings.projectVarsError and <span className="text-xs text-destructive mt-1">{settings.projectVarsError}</span> or None}
            <span className="text-xs text-muted-foreground mt-1 italic">{"Restart preview to apply environment variable changes."}</span>
        </div>
    </ScrollArea>;
}

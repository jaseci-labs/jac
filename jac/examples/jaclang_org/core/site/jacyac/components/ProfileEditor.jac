import from "lucide-react" { AlertCircle }
import from core.site.ui.button { Button }
import from core.site.ui.input { Input }
import from core.site.ui.textarea { Textarea }
import from core.site.ui.field { Field, FieldLabel }
import from core.social_graph { Profile }

def:pub ProfileEditor(
    profile: Profile,
    saving: bool,
    error: str,
    onSave: Callable[[dict[str, str]], None],
    onCancel: Callable[[], None],
) -> JsxElement {
    has displayName: str = "",
        bio: str = "",
        location: str = "",
        website: str = "",
        github: str = "";

    can with entry {
        displayName = profile.display_name;
        bio = profile.bio;
        location = profile.location;
        website = profile.website;
        github = profile.github;
    }

    def submit(e: FormEvent) {
        e.preventDefault();
        onSave(
            {
                "display_name": displayName,
                "bio": bio,
                "location": location,
                "website": website,
                "github": github
            }
        );
    }

    <form onSubmit={submit} className="flex flex-col gap-4 px-4 py-4">
        {if error {
            <div
                className="flex items-center gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive"
            >
                <AlertCircle size={16}/>
                <span>{error}</span>
            </div>
        }}
        <Field>
            <FieldLabel htmlFor="lx-display-name">Display name</FieldLabel>
            <Input
                id="lx-display-name"
                placeholder="How you want to be shown"
                maxLength={50}
                value={displayName}
                onChange={lambda (e: ChangeEvent) { displayName = e.target.value; }}
            />
        </Field>
        <Field>
            <FieldLabel htmlFor="lx-bio">Bio</FieldLabel>
            <Textarea
                id="lx-bio"
                rows={3}
                maxLength={280}
                placeholder="What are you building in Jac?"
                value={bio}
                onChange={lambda (e: ChangeEvent) { bio = e.target.value; }}
            />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
            <Field>
                <FieldLabel htmlFor="lx-location">Location</FieldLabel>
                <Input
                    id="lx-location"
                    placeholder="City, Country"
                    maxLength={60}
                    value={location}
                    onChange={lambda (e: ChangeEvent) { location = e.target.value; }}
                />
            </Field>
            <Field>
                <FieldLabel htmlFor="lx-github">GitHub</FieldLabel>
                <Input
                    id="lx-github"
                    placeholder="username"
                    value={github}
                    onChange={lambda (e: ChangeEvent) { github = e.target.value; }}
                />
            </Field>
        </div>
        <Field>
            <FieldLabel htmlFor="lx-website">Website</FieldLabel>
            <Input
                id="lx-website"
                type="text"
                inputMode="url"
                placeholder="https://"
                value={website}
                onChange={lambda (e: ChangeEvent) { website = e.target.value; }}
            />
        </Field>
        <div className="flex gap-2">
            <Button
                type="submit"
                size="sm"
                className="font-semibold"
                disabled={saving}
                id="lx-save-profile"
            >
                {"Saving..." if saving else "Save profile"}
            </Button>
            <Button
                type="button"
                size="sm"
                variant="outline"
                disabled={saving}
                onClick={lambda { onCancel(); }}
            >
                Cancel
            </Button>
        </div>
    </form>
}

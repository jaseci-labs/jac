"""Custom on/off switch (@jac/mobui has no Switch primitive)."""

cl {
    import from "@jac/mobui" { View }
    import from ..hooks.useStudio { useStudio }

    def:pub Toggle(on: bool) -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        return
            <View style={([styles.switchTrack, styles.switchTrackOn] if on else styles.switchTrack)}>
                <View style={styles.switchThumb}/>
            </View>;
    }
}

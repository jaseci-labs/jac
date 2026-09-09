import from "@jac/mobui" { View, Text }
import from core.jacyac.native.theme { makeStyles }
import from core.brand.theme { useTheme }
import from core.jacyac.native.icon { Icon }

def:pub EmptyState(icon: str, title: str, hint: str) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    <View style={styles.empty}>
        <Icon name={icon} size={30} color={C.muted}/>
        <Text style={styles.emptyTitle}>{title}</Text>
        <Text style={styles.emptyText}>{hint}</Text>
    </View>
}

def:pub LoadingRows(count: int) -> JsxElement {
    theme = useTheme();
    C = theme.colors;
    styles = makeStyles(C);
    <View style={styles.skeletonList}>
        {[
            <View style={styles.skeletonRow} key={i}>
                <View style={styles.skeletonAvatar}/>
                <View style={styles.skeletonBody}>
                    <View style={[styles.skeletonLine, {"width": "40%"}]}/>
                    <View style={styles.skeletonLine}/>
                    <View style={[styles.skeletonLine, {"width": "70%"}]}/>
                </View>
            </View> for i in range(count)
        ]}
    </View>
}

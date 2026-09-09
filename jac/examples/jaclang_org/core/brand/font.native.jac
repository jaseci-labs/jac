import from "expo-font" { useFonts }
import from "@jac/runtime" { __getApiBaseUrl }

def:pub useBrandFont -> bool {
    result = useFonts({"Geist": __getApiBaseUrl() + "/static/assets/Geist.ttf"});
    return bool(result[0]);
}

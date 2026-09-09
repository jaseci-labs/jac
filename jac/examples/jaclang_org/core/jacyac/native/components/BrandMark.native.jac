import from "react-native-svg" { SvgXml }
import from core.brand.logo { logo_xml }

def:pub BrandMark(size: int = 40) -> JsxElement {
    return <SvgXml xml={logo_xml()} width={size} height={size}/>;
}

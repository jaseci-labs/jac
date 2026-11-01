impl BrandMark(size: int = 40) -> JsxElement {
    return <SvgXml xml={logo_xml()} width={size} height={size}/>;
}

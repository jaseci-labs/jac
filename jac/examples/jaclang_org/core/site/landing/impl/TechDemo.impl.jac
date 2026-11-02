impl TechDemo -> JsxElement {
    return
        <>
            <SectionRail items={HOME_NAV}/>
            <div id="h-arena" className="scroll-mt-24 pt-16">
                <WasmGame/>
            </div>
            <div id="h-mobile" className="scroll-mt-24">
                <MobileShowcase/>
            </div>
            <div id="h-agents" className="scroll-mt-24">
                <Agents/>
            </div>
            <div id="h-book" className="scroll-mt-24">
                <BookSection/>
            </div>
            <div id="h-explore" className="scroll-mt-24">
                <ExplorerFinale/>
            </div>
        </>;
}

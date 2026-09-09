import from core.site.landing.Hero { Hero }
import from core.site.landing.StatsBand { StatsBand }
import from core.site.landing.WasmGame { WasmGame }
import from core.site.landing.MobileShowcase { MobileShowcase }
import from core.site.landing.WhyJac { WhyJac }
import from core.site.landing.Showcase { Showcase }
import from core.site.landing.Capabilities { Capabilities }
import from core.site.landing.OneBinary { OneBinary }
import from core.site.landing.Agents { Agents }
import from core.site.landing.BookSection { BookSection }
import from core.site.landing.ExplorerFinale { ExplorerFinale }
import from core.site.ui.SectionRail { SectionRail }

glob HOME_NAV: list[dict] = [
         {"id": "h-arena", "label": "arena"},
         {"id": "h-mobile", "label": "mobile"},
         {"id": "h-why", "label": "why jac"},
         {"id": "h-showcase", "label": "showcase"},
         {"id": "h-capabilities", "label": "capabilities"},
         {"id": "h-onebinary", "label": "one binary"},
         {"id": "h-agents", "label": "agents"},
         {"id": "h-book", "label": "the book"},
         {"id": "h-explore", "label": "explore"},

     ];

def:pub Home -> JsxElement {
    return
        <>
            <SectionRail items={HOME_NAV}/>
            <Hero/>
            <StatsBand/>
            <div id="h-arena" className="scroll-mt-24">
                <WasmGame/>
            </div>
            <div id="h-mobile" className="scroll-mt-24">
                <MobileShowcase/>
            </div>
            <div id="h-why" className="scroll-mt-24">
                <WhyJac/>
            </div>
            <div id="h-showcase" className="scroll-mt-24">
                <Showcase/>
            </div>
            <div id="h-capabilities" className="scroll-mt-24">
                <Capabilities/>
            </div>
            <div id="h-onebinary" className="scroll-mt-24">
                <OneBinary/>
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

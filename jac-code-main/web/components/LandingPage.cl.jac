import from .Navbar { Navbar }
import from .Hero { Hero }
import from .Features { Features }
import from .SeeItInAction { SeeItInAction }
import from .Architecture { Architecture }
import from .GettingStarted { GettingStarted }
import from .BuiltWithJac { BuiltWithJac }
import from .FinalCTA { FinalCTA }
import from .Footer { Footer }


def:pub LandingPage() -> JsxElement {

    can with entry {
        doc = globalThis.document;

        # --- Cursor glow ---
        glow = doc.createElement("div");
        glow.className = "cursor-glow";
        doc.body.appendChild(glow);

        state = {"hero": None};
        def on_mouse_move(e: any) -> None {
            glow.style.transform = "translate(" + str(e.clientX) + "px," + str(e.clientY) + "px)";

            if state["hero"] is None {
                state["hero"] = doc.querySelector(".hero-gradient");
            }
            hg = state["hero"];
            if hg {
                vw = globalThis.window.innerWidth;
                vh = globalThis.window.innerHeight;
                dx = (e.clientX - vw / 2) * 0.015;
                dy = (e.clientY - vh / 2) * 0.015;
                hg.style.transform = "translate(" + str(dx) + "px," + str(dy) + "px)";
            }
        }
        globalThis.window.addEventListener("mousemove", on_mouse_move);

        # --- Card spotlight ---
        def init_spotlights() -> None {
            cards = doc.querySelectorAll(".spot-card");
            for card in cards {
                def make_handler(c: any) -> any {
                    def handler(e: any) -> None {
                        rect = c.getBoundingClientRect();
                        x = e.clientX - rect.left;
                        y = e.clientY - rect.top;
                        c.style.setProperty("--spot-x", str(x) + "px");
                        c.style.setProperty("--spot-y", str(y) + "px");
                    }
                    return handler;
                }
                card.addEventListener("mousemove", make_handler(card));
            }
        }
        globalThis.setTimeout(init_spotlights, 300);

        # --- Scroll reveal ---
        def handle_intersect(entries: any) -> None {
            for entry in entries {
                if entry.isIntersecting {
                    entry.target.classList.add("visible");
                }
            }
        }
        observer = Reflect.construct(
            globalThis.IntersectionObserver,
            [handle_intersect, {"threshold": 0.06, "rootMargin": "0px 0px -60px 0px"}]
        );
        def observe_all() -> None {
            elements = doc.querySelectorAll(".scroll-fade");
            for el in elements {
                observer.observe(el);
            }
        }
        globalThis.setTimeout(observe_all, 150);
    }

    return (
        <div className="min-h-screen text-white noise-overlay">
            <div className="page-canvas"></div>
            <div className="relative z-[2]">
                <Navbar />
                <main>
                    <Hero />
                    <div className="scroll-fade"><Features /></div>
                    <div className="scroll-fade"><SeeItInAction /></div>
                    <div className="scroll-fade"><Architecture /></div>
                    <div className="scroll-fade"><GettingStarted /></div>
                    <div className="scroll-fade"><BuiltWithJac /></div>
                    <div className="scroll-fade"><FinalCTA /></div>
                </main>
                <Footer />
            </div>
        </div>
    );
}

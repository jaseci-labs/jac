import from core.site.ui.badge { Badge }
import from core.site.ui.CodeBlock { CodeBlock }
import from .Reveal { Reveal }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { CheckmarkCircle01Icon, ArrowUpRight01Icon }
import from core.socialize_mobile.SocializeMobile { SocializeMobile }

glob _IMPORT_LINES: list[str] = [
         "import from core.socialize_mobile.SocializeMobile {",
         "    SocializeMobile",
         "}",
         "",
         "<PhoneFrame>",
         "    <SocializeMobile embedded={True}/>",
         "</PhoneFrame>"
     ],
     _POINTS: list[str] = [
         "Every screen is @jac/mobui: View, Text, Pressable, ScrollView. No div, no CSS. Built natively it is React Native; on this page react-native-web draws it.",
         "The same account and the same graph as /socialize. Sign in on either and the other already knows you; post here and it lands in the site feed.",
         "It talks to core/social_graph.jac by spawning walkers. There is no API client in the phone and no route table on the server.",
         "jac run mobile puts the identical source on an Android or iOS device through Expo; jac build --platform ios mobile ships it."
     ];

def:pub PhoneFrame(children: any = None) -> JsxElement {
    return
        <div className="mx-auto w-[344px] max-w-full">
            <div
                className="relative rounded-[3rem] border-[10px] border-neutral-950 bg-neutral-950 shadow-[0_30px_80px_-20px_rgba(0,0,0,0.7)] ring-1 ring-white/10"
            >
                <div
                    className="pointer-events-none absolute left-1/2 top-2.5 z-20 h-6 w-24 -translate-x-1/2 rounded-full bg-black"
                ></div>
                <div
                    className="pointer-events-none absolute -left-[13px] top-24 h-8 w-[3px] rounded-l bg-neutral-800"
                ></div>
                <div
                    className="pointer-events-none absolute -left-[13px] top-36 h-14 w-[3px] rounded-l bg-neutral-800"
                ></div>
                <div
                    className="pointer-events-none absolute -right-[13px] top-32 h-20 w-[3px] rounded-r bg-neutral-800"
                ></div>
                <div
                    className="relative h-[700px] overflow-hidden rounded-[2.4rem] bg-[#0b0d12]"
                >
                    {children}
                </div>
            </div>
        </div>;
}

def:pub MobileShowcase -> JsxElement {
    return
        <section
            id="mobile"
            className="border-t border-border/60 pt-16 pb-16 sm:pt-24 sm:pb-24"
        >
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <Badge variant="outline" className="mb-4">mobUI</Badge>
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            The phone on this page is the mobile app.
                        </h2>
                        <p className="mt-4 text-balance text-lg text-muted-foreground">
                            Not a video, not a mockup. The React Native app in{" "}
                            <span className="font-mono">mobile/</span>{" "}
                            is imported into the site as a component and runs here, logged into the same graph as everything else. Use it.
                        </p>
                    </div>
                </Reveal>
                <div
                    className="mt-12 grid grid-cols-1 items-start gap-10 lg:grid-cols-[auto_1fr] lg:gap-16"
                >
                    <Reveal delay={120}>
                        <PhoneFrame>
                            <SocializeMobile embedded={True}/>
                        </PhoneFrame>
                        <p className="mt-4 text-center text-sm text-muted-foreground">
                            Live. Sign up, post, follow, join a channel.
                        </p>
                    </Reveal>
                    <Reveal delay={200}>
                        <div className="pt-2">
                            <CodeBlock
                                lines={_IMPORT_LINES}
                                title="core/site/landing/MobileShowcase.jac"
                            />
                            <h3 className="mt-8 text-xl font-semibold tracking-tight">
                                One import. That is the whole embed.
                            </h3>
                            <p
                                className="mt-3 text-base leading-relaxed text-muted-foreground"
                            >
                                The phone UI lives in{" "}
                                <span className="font-mono">
                                    core/socialize_mobile/
                                </span>
                                , shared by two apps: the{" "}
                                <span className="font-mono">mobile</span>{" "}
                                app wraps it for Android and iOS, and this page wraps it in a bezel. The compiler picks the native icon variant for the device build and the web one here, and type-checks both.
                            </p>
                            <ul className="mt-6 flex flex-col gap-4">
                                {for (i, pt) in enumerate(_POINTS) {
                                    <li key={str(i)} className="flex items-start gap-3">
                                        <HugeiconsIcon
                                            icon={CheckmarkCircle01Icon}
                                            strokeWidth={2}
                                            className="mt-0.5 size-4 shrink-0 text-primary"
                                        />
                                        <span
                                            className="text-sm leading-relaxed text-muted-foreground"
                                        >
                                            {pt}
                                        </span>
                                    </li>
                                }}
                            </ul>
                            <Link
                                to="/socialize"
                                className="mt-6 inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline"
                            >
                                Open the web version side by side
                                <HugeiconsIcon
                                    icon={ArrowUpRight01Icon}
                                    strokeWidth={2}
                                    className="size-3.5"
                                />
                            </Link>
                        </div>
                    </Reveal>
                </div>
            </div>
        </section>;
}

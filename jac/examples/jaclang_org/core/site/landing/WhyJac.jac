import from core.site.ui.badge { Badge }
import from core.site.ui.carousel {
    Carousel,
    CarouselContent,
    CarouselItem,
    CarouselPrevious,
    CarouselNext,
    CarouselDots
}
import from .Reveal { Reveal }
import from core.site.landing.diagrams.SynechicDiagram { SynechicDiagram }
import from core.site.landing.diagrams.TopokineticDiagram { TopokineticDiagram }
import from core.site.landing.diagrams.GradualBorrowDiagram { GradualBorrowDiagram }

def:pub WhySlide(
    title: str = "", accent: str = "", sub: str = "", children: any = None
) -> JsxElement {
    return
        <div
            className="flex h-full flex-col rounded-2xl border border-border/70 bg-card/30 pt-8 pb-8 pl-6 pr-6 sm:pl-12 sm:pr-12"
        >
            {if title != "" or accent != "" {
                <div className="mb-6 text-center">
                    <h3
                        className="text-balance text-2xl font-bold tracking-tight sm:text-3xl"
                    >
                        {title}{" "}
                        {if accent != "" {
                            <span>
                                <span className="text-gradient">{accent}</span>
                            </span>
                        }}
                    </h3>
                    {if sub != "" {
                        <p
                            className="mt-3 font-mono text-xs uppercase tracking-widest text-primary"
                        >
                            {sub}
                        </p>
                    }}
                </div>
            }}
            <div className="flex min-w-0 flex-1 flex-col justify-center">
                {children}
            </div>
        </div>;
}

def:pub WhyJac -> JsxElement {
    return
        <section id="why" className="pt-16 pb-16 sm:pt-24 sm:pb-24">
            <div
                className="mx-auto max-w-7xl pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
            >
                <Reveal>
                    <div className="mx-auto max-w-2xl text-center">
                        <Badge variant="outline" className="mb-4">Why Jac exists</Badge>
                        <h2
                            className="text-balance text-3xl font-bold tracking-tight sm:text-4xl"
                        >
                            No compiler can see across your stack...
                            <br/>
                            until now.
                        </h2>
                    </div>
                </Reveal>
                <Reveal delay={100}>
                    <div className="relative mt-12">
                        <Carousel className="w-full" opts={{"loop": True}}>
                            <CarouselContent>
                                <CarouselItem>
                                    <WhySlide>
                                        <figure
                                            className="mx-auto max-w-3xl text-center"
                                        >
                                            <blockquote
                                                className="text-balance text-3xl font-semibold tracking-tight sm:text-4xl"
                                            >
                                                {"“The whole-program type checker of the modern stack is "}
                                                <span
                                                    className="text-gradient font-mono"
                                                >
                                                    grep
                                                </span>
                                                {".”"}
                                            </blockquote>
                                            <figcaption
                                                className="mt-4 text-sm text-muted-foreground"
                                            >
                                                Jac is one bet against each of the two assumptions that made it so.
                                            </figcaption>
                                        </figure>
                                    </WhySlide>
                                </CarouselItem>
                                <CarouselItem>
                                    <WhySlide
                                        title="Jac is"
                                        accent="synechic"
                                        sub="One continuous, checked medium"
                                    >
                                        <SynechicDiagram/>
                                    </WhySlide>
                                </CarouselItem>
                                <CarouselItem>
                                    <WhySlide
                                        title="Jac is"
                                        accent="topokinetic"
                                        sub="Computation moves to data with Object Spatial Programming"
                                    >
                                        <TopokineticDiagram/>
                                    </WhySlide>
                                </CarouselItem>
                                <CarouselItem>
                                    <WhySlide
                                        title="Jac introduces"
                                        accent="gradual borrow checking"
                                        sub="From fully managed to zero-RC native, one declaration at a time"
                                    >
                                        <GradualBorrowDiagram/>
                                    </WhySlide>
                                </CarouselItem>
                            </CarouselContent>
                            <CarouselPrevious className="left-3"/>
                            <CarouselNext className="right-3"/>
                            <CarouselDots className="mt-5"/>
                        </Carousel>
                    </div>
                </Reveal>
            </div>
        </section>;
}

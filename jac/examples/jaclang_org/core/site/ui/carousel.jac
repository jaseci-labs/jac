import from "embla-carousel-react" { default as useEmblaCarousel }
import from react { createContext, useContext, useEffect }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, ArrowRight01Icon }

glob CarouselContext: any = createContext(None);

def:pub Carousel(props: any) -> JsxElement;

def:pub CarouselContent(props: any) -> JsxElement;

def:pub CarouselItem(props: any) -> JsxElement;

def:pub CarouselDot(index: int, selected: int) -> JsxElement;

def:pub CarouselDots(props: any) -> JsxElement;

def:pub CarouselPrevious(props: any) -> JsxElement;

def:pub CarouselNext(props: any) -> JsxElement;

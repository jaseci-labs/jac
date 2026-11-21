import from "embla-carousel-react" { default as useEmblaCarousel }
import from react { createContext, useContext, useEffect }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, ArrowRight01Icon }

glob CarouselContext: any = createContext(None);

def:pub Carousel(**kwargs: any) -> JsxElement;

def:pub CarouselContent(**kwargs: any) -> JsxElement;

def:pub CarouselItem(**kwargs: any) -> JsxElement;

def:pub CarouselDot(index: int, selected: int) -> JsxElement;

def:pub CarouselDots(**kwargs: any) -> JsxElement;

def:pub CarouselPrevious(**kwargs: any) -> JsxElement;

def:pub CarouselNext(**kwargs: any) -> JsxElement;

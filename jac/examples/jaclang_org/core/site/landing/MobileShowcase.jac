import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { CheckmarkCircle01Icon, ArrowUpRight01Icon }

glob _POINTS: list[str] = [
         "Every screen is @jac/mobui: View, Text, Pressable, ScrollView. No div, no CSS. Built natively it is React Native; on this page react-native-web draws it.",
         "The same account and the same graph as /jacyac. Sign in on either and the other already knows you; post here and it lands in the site feed.",
         "It talks to core/social_graph.jac by spawning walkers. There is no API client in the phone and no route table on the server.",
         "jac run mobile puts the identical source on an Android or iOS device through Expo; jac build --platform ios mobile ships it."
     ];

def:pub PhoneFrame(children: any = None) -> JsxElement;

def:pub MobileShowcase -> JsxElement;

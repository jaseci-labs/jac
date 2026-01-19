

import from "i18next"  {default as i18n}
import from "react-i18next" { initReactI18next, useTranslation, I18nextProvider }

glob i18nInstance = <>i18n.<>use(initReactI18next).<>init({
    "debug": true,
    "fallbackLng": "en",
    "resources": {
        "en": {
            "translation": {
                "Welcome_to_React": "Welcome to React and react-i18next",
                "localization_testing": "This is a localization test."
            }
        },
        "tr": {
            "translation": {
                "Welcome_to_React": "React ve react-i18next'e hoş geldiniz",
                "localization_testing": "Bu bir yerelleştirme testidir."
            }
        }
    },
    "interpolation": {
        "escapeValue": false,
    },
    "react": {
        "useSuspense": false,
    },
});

def:pub Home() -> any {
     interference = useTranslation();

    def changeLanguage(lng: str) -> None {
        interference.i18n.changeLanguage(lng);
    }

    if (interference.ready) {
        return <I18nextProvider i18n={i18nInstance} defaultNS={"translation"}>
            <div className="Home-header">
                <h2>{interference.t("Welcome_to_React")}</h2>
                <button onClick={lambda -> None {changeLanguage("tr");}}>tr</button>
                <button onClick={lambda -> None {changeLanguage("en");}}>en</button>
                <div>{interference.t("localization_testing")}</div>
            </div>
        </I18nextProvider>;
    }
    return <span>Loading...</span>;
}
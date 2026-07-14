"""App constants — the hosted backend URL and the static presentational copy
(prompt suggestions, plan catalogue) that has no backend source. jacBuilder keeps
these client-side too (GuestHome `_SUGGESTIONS`, BillingPage `_TIER_CARDS`).
"""

cl {
    # jacBuilder hosted backend — jachammer is a client of it (no local backend).
    glob:pub JB_API = "https://jac-builder-dev.jaseci.org";

    # Example prompts for the Home composer's chips — UI hints, not data.
    glob:pub SUGGESTIONS = [
             "Build a full-stack expense tracker with accounts and a dashboard",
             "Build a social app where users follow each other and share projects",
             "Build a real-time multiplayer quiz with rooms and leaderboards",
             "Build an analytics dashboard",
             "Build a weather widget"
         ];

    # Static pricing catalogue; checkout is handled on jacbuilder.app via Stripe.
    glob:pub PLANS = [
             {
                 "name": "Free",
                 "price": "$0",
                 "note": "3 projects · 200 credits/mo · sandbox previews"
             },
             {
                 "name": "Builder",
                 "price": "$15",
                 "note": "5 projects · 600 credits/mo · 1 permanent deploy"
             },
             {
                 "name": "Pro",
                 "price": "$25",
                 "note": "10 projects · 1,500 credits/mo · Opus unlocked"
             }
         ];
}

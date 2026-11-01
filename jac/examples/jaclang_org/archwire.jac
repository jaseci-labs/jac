graph import {
    edge AppOverCore: core.* --> cli | desktop | mobile.* | pages.* | web;
    edge BridgeFunnel: jaclang.server.bridge --> cli | core.docs.sync;
    edge CoreInternal: core.* --> core.*;
    edge SsoFunnel: jaclang.scale.sso.* --> core.jacyac.github.auth;

    core.docs.graph ++> [
        cli { DocsStatus, docs_status },
        web,
    ]
    core.docs.sync ++> [
        cli { docs_sync_tick },
        web,
    ]
    core.install ++> web;
    core.jacyac.github.auth ++> desktop | web;
    core.jacyac.limits ++> cli { PostingDenied }
    core.jacyac.native.JacYacMobile ++> mobile.main { JacYacMobile }
    core.packages.catalog ++> web;
    core.site.docs.DocsShell ++> pages.docs.index { DocsShell }
    core.site.home.Home ++> pages.index { Home }
    core.site.jacyac.GithubCallback ++> pages.jacyac.github.callback { GithubCallback }
    core.site.jacyac.JacYac ++> pages.jacyac
        | pages.jacyac.ninjaclaw
        | pages.jacyac.tutorials
        | pages.socialize { JacYac }
    core.site.packages.PackagesShell ++> pages.packages.index { PackagesShell }
    core.site.ui.SiteShell ++> pages.layout { SiteShell }
    core.social_graph ++> cli { create_tweet, load_feed }
    core.source.files ++> web;
}

graph import core {
    async_utils ++> site.docs.DocsShell { sleep }
    brand.font ++> jacyac.native.JacYacMobile { useBrandFont }
    brand.theme ++> jacyac.native.JacYacMobile
        | jacyac.native.components.Avatar
        | jacyac.native.components.BridgeBanner
        | jacyac.native.components.Composer
        | jacyac.native.components.StatusView
        | jacyac.native.components.TabBar
        | jacyac.native.components.TweetCard
        | jacyac.native.screens.AuthScreen
        | jacyac.native.screens.ChannelsScreen
        | jacyac.native.screens.ClawScreen
        | jacyac.native.screens.ExploreScreen
        | jacyac.native.screens.FeedScreen
        | jacyac.native.screens.ProfileScreen
        | site.ui.Navbar { useTheme }
    brand.tokens ++> jacyac.native.theme { Colors, font_family, fonts, radii, spacing }
    docs.corpus ++> knowledge_service { DocBundle, bundle_from, label_of }
    docs.graph ++> [
        site.docs.DocsArticle { DocPageView },
        site.docs.DocsGraphFloat { TreeNode },
        site.docs.DocsShell {
            DocPageView,
            TreeNode,
            VersionInfo,
            doc_page,
            doc_tree,
            docs_status
        },
        site.docs.DocsSidebar { TreeNode, VersionInfo },
        site.docs.DocsTocRail { TocEntry },
    ]
    github ++> [
        install { fetch },
        packages.catalog { API_ROOT, fetch, parse_repo_url },
    ]
    install ++> site.ui.Navbar { ensure_install }
    jac_tokenizer ++> site.ui.CodeBlock { Token, tokenize_lines }
    jacyac.claw ++> [
        site.jacyac.JacYac { useClaw },
        site.jacyac.components.NinjaclawTab | site.jacyac.components.TutorialsTab {
            ClawModel
        },
    ]
    jacyac.format ++> [
        site.jacyac.components.ExploreTab
            | site.jacyac.components.ProfileHeader
            | site.jacyac.components.RightSidebar
            | site.jacyac.components.TweetCard { handle_of, initial_of },
        site.jacyac.components.NinjaclawTab | site.jacyac.components.Sidebar {
            handle_of
        },
        site.jacyac.components.RichText { text_segments },
        site.jacyac.components.TutorialsTab { count_label },
    ]
    jacyac.github.auth ++> site.jacyac.GithubCallback {
        complete_native_github,
        github_callback_mode
    }
    jacyac.github.login ++> site.jacyac.GithubCallback { complete_web_login }
    jacyac.identity ++> [
        site.jacyac.JacYac
            | site.jacyac.components.ExploreTab
            | site.jacyac.components.ProfileHeader
            | site.jacyac.components.RightSidebar { avatar_of, name_of },
        site.jacyac.components.TweetCard { avatar_of },
    ]
    jacyac.limits ++> social_graph { PostingDenied, posting_limit }
    jacyac.native.JacYacMobile ++> site.landing.MobileShowcase { JacYacMobile }
    jacyac.state ++> site.jacyac.JacYac { useJacYac }
    jacyac.validation ++> [
        site.jacyac.components.Composer { chars_left, post_limit, valid_post },
        social_graph { valid_post },
    ]
    knowledge.repo ++> [
        knowledge_service {
            DOCS_PATH,
            ReleaseLine,
            RepoStatus,
            checkout_root,
            ensure_repo,
            export_docs,
            read_status
        },
        ninjaclaw.secret | ninjaclaw.verify { knowledge_dir },
    ]
    knowledge_service ++> [
        docs.sync { release_doc_lines, release_docs },
        jacyac.claw {
            ninjaclaw_activity,
            ninjaclaw_job,
            ninjaclaw_tutorial,
            ninjaclaw_tutorials
        },
        social_graph {
            ninjaclaw_forget,
            ninjaclaw_results,
            ninjaclaw_retained,
            ninjaclaw_submit
        },
    ]
    ninjaclaw.graph ++> knowledge_service {
        ClawHub,
        ClawJob,
        JOB_RETENTION,
        RECENT_LIMIT,
        apply_pr,
        apply_pr_state,
        apply_sweep,
        claim_chore,
        claim_job,
        claw_gaps,
        claw_hub,
        claw_jobs,
        claw_tutorials,
        enqueue_asks,
        find_hub,
        forget_jobs,
        job_view,
        next_queued,
        pr_cooling,
        pr_due,
        promote_candidates,
        prune_jobs,
        record_outcome,
        release_chore,
        renew_chore,
        renew_job,
        replies_for,
        requeue_stale,
        sweep_inputs,
        take_budget,
        tutorial_by_slug,
        tutorial_card
    }
    ninjaclaw.index ++> knowledge_service { IndexDoc, docs_from_tree, index_doc }
    ninjaclaw.model ++> [
        jacyac.claw { Activity, JobView, TutorialCard, TutorialView },
        jacyac.native.screens.ClawScreen { JobView },
        knowledge_service {
            Activity,
            AskInput,
            BlockView,
            JobReply,
            JobView,
            StepView,
            TutorialCard,
            TutorialView,
            UpkeepView
        },
        site.jacyac.components.NinjaclawTab { JobView, StepView },
        site.jacyac.components.TutorialsTab { TutorialCard, TutorialView },
        social_graph { AskInput },
    ]
    ninjaclaw.promote ++> knowledge_service {
        PrResult,
        eligible,
        github,
        open_docs_pr,
        pr_state,
        promote_config,
        promote_ready
    }
    ninjaclaw.runner ++> knowledge_service { JobSpec, Outcome, RUNNER, run_pipeline }
    ninjaclaw.secret ++> [
        knowledge_service { secret_ok },
        social_graph { service_secret },
    ]
    ninjaclaw.upkeep ++> knowledge_service { CHORE, sweep, sweep_items }
    packages.catalog ++> [
        site.packages.ApiDocs { ApiMember, ApiModule, ApiParam, ApiSymbol },
        site.packages.PackagePage { PackageDetail, PackageVersion },
        site.packages.PackagesIndex { PackageCatalog, PackageSummary },
        site.packages.PackagesShell {
            PackageCatalog,
            PackageDetail,
            package_catalog,
            package_detail
        },
    ]
    social_graph ++> [
        jacyac.native.components.TweetCard
            | jacyac.native.screens.FeedScreen
            | site.jacyac.components.FeedTab
            | site.jacyac.components.TweetCard { Tweet },
        jacyac.native.screens.ChannelsScreen | site.jacyac.components.ChannelsTab {
            ChannelBundle,
            Tweet
        },
        jacyac.native.screens.ExploreScreen | site.jacyac.components.RightSidebar {
            Profile,
            TrendingTag
        },
        jacyac.native.screens.ProfileScreen | site.jacyac.components.ProfileHeader {
            ProfileBundle
        },
        jacyac.state {
            ChannelBundle,
            Profile,
            ProfileBundle,
            TrendingTag,
            Tweet,
            add_comment,
            clear_avatar,
            create_channel,
            create_channel_tweet,
            create_tweet,
            delete_tweet,
            follow_user,
            get_all_profiles,
            get_avatars,
            get_channel_detail,
            get_channels,
            get_profile,
            get_trending,
            get_user_profile,
            join_channel,
            leave_channel,
            like_tweet,
            load_feed,
            set_avatar,
            setup_profile,
            unfollow_user,
            update_profile
        },
        site.jacyac.components.ExploreTab | site.jacyac.components.ProfileEditor {
            Profile
        },
    ]
    source.files ++> [
        site.source.CodeSpotlight { SourceSpan, source_span },
        site.source.SourceBrowser { SourceFile, SourceView, source_file, source_tree },
    ]
    timefmt ++> [
        docs.sync | progress | social_graph { now_iso },
        install { now_iso, seconds_since },
    ]
    utils ++> site.docs.DocsSidebar
        | site.docs.DocsTocRail
        | site.home.NoGlue
        | site.home.OneLanguage
        | site.home.kit
        | site.jacyac.components.MobileNav
        | site.jacyac.components.Sidebar
        | site.jacyac.components.TweetCard
        | site.landing.CopyCommand
        | site.landing.Reveal
        | site.source.FloatingSource
        | site.ui.CodeBlock
        | site.ui.Navbar
        | site.ui.accordion
        | site.ui.alert_dialog
        | site.ui.avatar
        | site.ui.badge
        | site.ui.button
        | site.ui.card
        | site.ui.carousel
        | site.ui.dialog
        | site.ui.dropdown_menu
        | site.ui.empty
        | site.ui.field
        | site.ui.hover_card
        | site.ui.input
        | site.ui.label
        | site.ui.select
        | site.ui.separator
        | site.ui.skeleton
        | site.ui.tabs
        | site.ui.textarea
        | site.ui.tooltip { cn }
}

graph import core.brand {
    logo ++> styles { logo_xml }
    tokens ++> [
        styles { Colors, dark_palette, font_family, light_palette, radii, spacing },
        theme { Colors, dark_palette, light_palette },
    ]
}

graph import core.docs {
    corpus ++> sync { DocBundle, bundle_from, label_of }
    graph ++> sync {
        DocVersion,
        DocsHub,
        HasHub,
        HasVersion,
        NextPage,
        _get_hub,
        _pretty,
        _sweep_stale,
        _teardown_version,
        _version,
        place_page,
        rewrite_href,
        toc_of
    }
}

graph import core.jacyac {
    claw ++> native.screens.ClawScreen { useClaw }
    format ++> [
        identity
            | native.components.TweetCard
            | native.screens.ExploreScreen
            | native.screens.ProfileScreen { handle_of },
        native.components.Avatar { handle_of, initial_of },
        native.screens.ChannelsScreen { count_label },
        native.screens.ClawScreen { count_label, handle_of },
    ]
    github.auth ++> session { github_enabled }
    github.login ++> session { github_login }
    identity ++> [
        native.components.Avatar { avatar_of },
        native.screens.ExploreScreen | native.screens.ProfileScreen { name_of },
    ]
    session ++> state { Session, stored_username, useSession }
    state ++> native.JacYacMobile { useJacYac }
    validation ++> [
        native.components.Composer { chars_left },
        state { valid_post },
    ]
}

graph import core.jacyac.github {
    auth ++> login { begin_github, finish_github }
}

graph import core.jacyac.native {
    components.Avatar ++> screens.ExploreScreen | screens.ProfileScreen { Avatar }
    components.BrandMark ++> JacYacMobile | screens.AuthScreen { BrandMark }
    components.BridgeBanner ++> JacYacMobile { BridgeBanner }
    components.Composer ++> screens.ChannelsScreen | screens.FeedScreen { Composer }
    components.StatusView ++> [
        screens.ChannelsScreen
            | screens.ClawScreen
            | screens.ExploreScreen
            | screens.FeedScreen { EmptyState, LoadingRows },
        screens.ProfileScreen { EmptyState },
    ]
    components.TabBar ++> JacYacMobile { TabBar }
    components.TweetCard ++> screens.ChannelsScreen
        | screens.FeedScreen
        | screens.ProfileScreen { TweetCard }
    icon ++> components.BridgeBanner
        | components.StatusView
        | components.TabBar
        | components.TweetCard
        | screens.AuthScreen
        | screens.ChannelsScreen
        | screens.ClawScreen
        | screens.ExploreScreen
        | screens.FeedScreen
        | screens.ProfileScreen { Icon }
    screens.AuthScreen ++> JacYacMobile { AuthScreen }
    screens.ChannelsScreen ++> JacYacMobile { ChannelsScreen }
    screens.ClawScreen ++> JacYacMobile { ClawScreen }
    screens.ExploreScreen ++> JacYacMobile { ExploreScreen }
    screens.FeedScreen ++> JacYacMobile { FeedScreen }
    screens.ProfileScreen ++> JacYacMobile { ProfileScreen }
    theme ++> JacYacMobile
        | components.Avatar
        | components.BridgeBanner
        | components.Composer
        | components.StatusView
        | components.TabBar
        | components.TweetCard
        | screens.AuthScreen
        | screens.ChannelsScreen
        | screens.ClawScreen
        | screens.ExploreScreen
        | screens.FeedScreen
        | screens.ProfileScreen { makeStyles }
}

graph import core.jacyac.native.components {
    Avatar ++> Composer | TweetCard { Avatar }
}

graph import core.ninjaclaw {
    brain ++> runner {
        AskKind,
        CALL_MAX_S,
        Candidate,
        DEADLINE,
        classify_ask,
        pick_answer,
        repair_tutorial,
        write_tutorial
    }
    index ++> [
        runner { IndexDoc, excerpt, search },
        tools { IndexDoc, docs_from_tree, excerpt, index_doc, search },
    ]
    model ++> [
        graph {
            AskInput,
            BlockView,
            JobReply,
            JobView,
            LinkView,
            StepView,
            TutorialCard
        },
        runner { BlockView, LinkView, StepView },
        upkeep | verify { BlockView },
    ]
    promote ++> graph { PrResult, PromoteCandidate }
    runner ++> graph { JOB_LEASE_S, Outcome, WORKER_ID, stamp }
    tools ++> [
        brain { list_jac_guides, read_jac_file, read_jac_guide, search_jac },
        runner { agent_catalog, open_toolbox },
    ]
    upkeep ++> graph { sweep_passed }
    verify ++> runner | upkeep { verify_markdown }
}

graph import core.site {
    docs.Markdown ++> [
        jacyac.components.TutorialsTab { MDSpans, Markdown },
        packages.PackagePage { Markdown },
    ]
    game.webgl_host ++> landing.WasmGame { run_game }
    landing.CopyCommand ++> home.HomeClose
        | home.HomeHero
        | packages.PackagePage
        | packages.PackagesIndex { CopyCommand }
    landing.Reveal ++> home.AgentNative
        | home.HomeClose
        | home.InProduction
        | home.NativeBench
        | home.NoGlue
        | home.OneLanguage
        | home.ReadableTiers
        | home.kit { Reveal }
    source.CodeSpotlight ++> landing.MobileShowcase | landing.WaitWuuut {
        CodeSpotlight
    }
    source.FloatingSource ++> landing.WaitWuuut { FloatingSource }
    source.SourceBrowser ++> landing.ExplorerFinale { SourceBrowser }
    ui.CodeBlock ++> docs.Markdown
        | docs.MermaidDiagram
        | home.kit
        | source.CodeSpotlight
        | source.SourceBrowser { CodeLines }
    ui.GraphBackdrop ++> docs.DocsShell { GraphBackdrop }
    ui.SectionRail ++> home.Home | landing.TechDemo | landing.WaitWuuut { SectionRail }
    ui.alert_dialog ++> jacyac.components.TweetCard {
        AlertDialog,
        AlertDialogAction,
        AlertDialogCancel,
        AlertDialogContent,
        AlertDialogDescription,
        AlertDialogFooter,
        AlertDialogHeader,
        AlertDialogTitle,
        AlertDialogTrigger
    }
    ui.avatar ++> jacyac.components.Composer
        | jacyac.components.ExploreTab
        | jacyac.components.ProfileHeader
        | jacyac.components.RightSidebar
        | jacyac.components.Sidebar
        | jacyac.components.TweetCard { Avatar, AvatarFallback, AvatarImage }
    ui.badge ++> jacyac.components.ChannelsTab
        | jacyac.components.NinjaclawTab
        | jacyac.components.RightSidebar
        | jacyac.components.Sidebar
        | jacyac.components.TutorialsTab
        | landing.Agents
        | landing.BookSection
        | landing.ExplorerFinale
        | landing.MobileShowcase
        | landing.WaitWuuut
        | landing.WasmGame
        | packages.PackagePage
        | packages.PackagesIndex { Badge }
    ui.button ++> [
        jacyac.JacYac
            | jacyac.components.AuthForm
            | jacyac.components.ChannelsTab
            | jacyac.components.Composer
            | jacyac.components.ExploreTab
            | jacyac.components.ProfileEditor
            | jacyac.components.ProfileHeader
            | jacyac.components.RightSidebar
            | jacyac.components.Sidebar
            | jacyac.components.TweetCard
            | jacyac.components.WelcomeBanner
            | landing.WasmGame { Button },
        landing.BookSection | landing.ExplorerFinale { buttonVariants },
    ]
    ui.card ++> [
        jacyac.components.AuthForm {
            Card,
            CardContent,
            CardDescription,
            CardHeader,
            CardTitle
        },
        jacyac.components.RightSidebar { Card, CardContent, CardHeader, CardTitle },
    ]
    ui.dialog ++> jacyac.components.ChannelsTab {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogFooter,
        DialogHeader,
        DialogTitle
    }
    ui.dropdown_menu ++> jacyac.components.Sidebar {
        DropdownMenu,
        DropdownMenuContent,
        DropdownMenuGroup,
        DropdownMenuItem,
        DropdownMenuTrigger
    }
    ui.empty ++> jacyac.components.ChannelsTab
        | jacyac.components.ExploreTab
        | jacyac.components.FeedTab
        | jacyac.components.TutorialsTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle
    }
    ui.field ++> jacyac.components.AuthForm
        | jacyac.components.ChannelsTab
        | jacyac.components.ProfileEditor { Field, FieldLabel }
    ui.hover_card ++> jacyac.components.RightSidebar {
        HoverCard,
        HoverCardContent,
        HoverCardTrigger
    }
    ui.input ++> docs.DocsSidebar
        | jacyac.components.AuthForm
        | jacyac.components.ChannelsTab
        | jacyac.components.ProfileEditor
        | jacyac.components.RightSidebar
        | jacyac.components.TweetCard
        | packages.PackagesIndex { Input }
    ui.select ++> docs.DocsSidebar {
        Select,
        SelectContent,
        SelectGroup,
        SelectItem,
        SelectTrigger,
        SelectValue
    }
    ui.skeleton ++> docs.DocsArticle
        | docs.DocsSidebar
        | jacyac.components.ChannelsTab
        | jacyac.components.ExploreTab
        | jacyac.components.FeedTab { Skeleton }
    ui.tabs ++> docs.Markdown { Tabs, TabsContent, TabsList, TabsTrigger }
    ui.textarea ++> jacyac.components.ChannelsTab
        | jacyac.components.Composer
        | jacyac.components.ProfileEditor { Textarea }
    ui.tooltip ++> jacyac.components.TweetCard {
        Tooltip,
        TooltipContent,
        TooltipProvider,
        TooltipTrigger
    }
}

graph import core.site.docs {
    DocsArticle ++> DocsShell { DocsArticle, DocsArticleSkeleton }
    DocsGraphFloat ++> DocsSidebar { DocsGraphFloat }
    DocsSidebar ++> DocsShell { DocsSidebar }
    DocsTocRail ++> DocsShell { DocsTocRail }
    Markdown ++> DocsArticle { Markdown }
    MermaidDiagram ++> Markdown { MermaidDiagram }
}

graph import core.site.game {
    arena ++> webgl_host { frame, get_deaths, get_hp, get_score, init, shutdown }
    gmath ++> [
        arena { clampf, jsin, lerp },
        sim { DEG2RAD, Rng, jcos, jsin, jsqrt, rand_range, rand_sign },
    ]
    platform_rl ++> arena {
        KEY_A,
        KEY_D,
        KEY_DOWN,
        KEY_LEFT,
        KEY_RIGHT,
        KEY_S,
        KEY_SPACE,
        KEY_TAB,
        KEY_UP,
        KEY_W,
        MOUSE_LEFT,
        SCREEN_H,
        SCREEN_W,
        begin_frame,
        begin_model,
        begin_overlay,
        close_window,
        draw_box,
        draw_floor,
        draw_fps,
        draw_rect2d,
        end_frame,
        end_model,
        frame_dt,
        key_held,
        key_tapped,
        lock_mouse,
        mouse_pressed,
        mouse_x,
        mouse_y,
        open_window,
        set_camera,
        should_close,
        unlock_mouse
    }
    sim ++> arena {
        CHARGE_T,
        Cmd,
        EnemyPool,
        FIRE_COOLDOWN,
        Game,
        HP_MAX,
        MAX_ENEMIES,
        PITCH_LIMIT,
        Player,
        ProjectilePool,
        SparkPool,
        Stats,
        TICK_DT,
        TICK_MAX_CATCHUP,
        sim_tick,
        world_new
    }
    type sim ++> webgl_host { Game }
}

graph import core.site.home {
    AgentNative ++> Home { AgentNative }
    HomeClose ++> Home { HomeClose }
    HomeHero ++> Home { HomeHero }
    InProduction ++> Home { InProduction }
    NativeBench ++> Home { NativeBench }
    NoGlue ++> Home { NoGlue }
    OneLanguage ++> Home { OneLanguage }
    ReadableTiers ++> Home { ReadableTiers }
    kit ++> [
        AgentNative { CodeWindow, Figure, HomeSection, Prose, SectionHead },
        HomeClose { HomeSection, Prose },
        InProduction | NativeBench | OneLanguage {
            Fact,
            Figure,
            HomeSection,
            SectionHead
        },
        NoGlue | ReadableTiers {
            CodeWindow,
            Fact,
            Figure,
            HomeSection,
            Prose,
            SectionHead
        },
    ]
}

graph import core.site.jacyac {
    components.AuthForm ++> JacYac { AuthForm }
    components.ChannelsTab ++> JacYac { ChannelsTab }
    components.ExploreTab ++> JacYac { ExploreTab }
    components.FeedTab ++> JacYac { FeedTab }
    components.MobileNav ++> JacYac { MobileNav }
    components.NinjaclawTab ++> JacYac { NinjaclawTab }
    components.ProfileEditor ++> JacYac { ProfileEditor }
    components.ProfileHeader ++> JacYac { ProfileHeader }
    components.RightSidebar ++> JacYac { RightSidebar }
    components.Sidebar ++> JacYac { Sidebar }
    components.TutorialsTab ++> JacYac { TutorialsTab }
    components.TweetCard ++> JacYac { TweetCard }
}

graph import core.site.jacyac.components {
    Composer ++> ChannelsTab | FeedTab { Composer }
    RichText ++> NinjaclawTab | TweetCard { RichText }
    TweetCard ++> ChannelsTab | FeedTab { TweetCard }
    WelcomeBanner ++> FeedTab { WelcomeBanner }
}

graph import core.site.landing {
    Agents ++> TechDemo { Agents }
    BookSection ++> TechDemo { BookSection }
    CopyCommand ++> [
        Agents { CopyCommand },
        ExplorerFinale { CopyCommandBlock },
    ]
    ExplorerFinale ++> TechDemo { ExplorerFinale }
    MobileShowcase ++> TechDemo { MobileShowcase }
    Reveal ++> Agents
        | BookSection
        | ExplorerFinale
        | MobileShowcase
        | WaitWuuut
        | WasmGame { Reveal }
    WasmGame ++> TechDemo { WasmGame }
}

graph import core.site.packages {
    ApiDocs ++> PackagePage { ApiDocs }
    PackagePage ++> PackagesShell { PackagePage }
    PackagesIndex ++> PackagesShell { PackagesIndex }
}

graph import core.site.source {
    SourceBrowser ++> FloatingSource { SourceBrowser }
}

graph import core.site.ui {
    Footer ++> SiteShell { Footer }
    GraphBackdrop ++> NotFound { GraphBackdrop }
    Navbar ++> SiteShell { Navbar }
    button ++> [
        Navbar | NotFound | dialog { buttonVariants },
        alert_dialog | carousel { Button },
    ]
    dropdown_menu ++> Navbar {
        DropdownMenu,
        DropdownMenuContent,
        DropdownMenuItem,
        DropdownMenuTrigger
    }
    label ++> field { Label }
    separator ++> field { Separator }
}

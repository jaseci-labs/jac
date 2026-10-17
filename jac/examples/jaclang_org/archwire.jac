graph import {
    edge AppOverCore: core.* --> cli.* | desktop.* | mobile.* | web.*;
    edge BridgeFunnel: jaclang.server.bridge --> cli.commands.*;
    edge CliInternal: cli.* --> cli.*;
    edge CoreInternal: core.* --> core.*;
    edge DesktopInternal: desktop.* --> desktop.*;
    edge MobileInternal: mobile.* --> mobile.*;
    edge SsoFunnel: jaclang.scale.sso.* --> core.jacyac.github.auth;
    edge WebInternal: web.* --> web.*;

    core.ai ++> cli.commands.score { optional_review }
    core.docs.graph ++> [
        cli.commands.docs { DocsStatus, docs_status },
        web.main,
    ]
    core.docs.sync ++> [
        cli.commands.docs { docs_sync_tick },
        web.main,
    ]
    core.github ++> cli.commands.score {
        RepoMeta,
        code_breakdown,
        download_tarball,
        head_sha,
        mb_of,
        repo_meta,
        text_of,
        untar
    }
    core.install ++> web.main;
    core.jacyac.github.auth ++> desktop.main | web.main;
    core.jacyac.github.repos ++> desktop.main | web.main;
    core.jacyac.limits ++> cli.commands.feed { PostingDenied }
    core.jacyac.native.JacYacMobile ++> mobile.main { JacYacMobile }
    core.leaderboard.scoring ++> cli.commands.score {
        RepoAnalysis,
        ScoreBreakdown,
        analyze,
        score
    }
    core.packages.catalog ++> web.main;
    core.site.docs.DocsShell ++> desktop.pages.docs.index | web.pages.docs.index {
        DocsShell
    }
    core.site.jacyac.GithubCallback ++> desktop.pages.jacyac.github.callback
        | web.pages.jacyac.github.callback { GithubCallback }
    core.site.jacyac.JacYac ++> desktop.pages.jacyac
        | desktop.pages.jacyac.scores
        | desktop.pages.socialize
        | web.pages.jacyac
        | web.pages.jacyac.scores
        | web.pages.socialize { JacYac }
    core.site.landing.Home ++> desktop.pages.index | web.pages.index { Home }
    core.site.leaderboard.Methodology ++> desktop.pages.methodology
        | web.pages.methodology { Methodology }
    core.site.packages.PackagesShell ++> desktop.pages.packages.index
        | web.pages.packages.index { PackagesShell }
    core.site.ui.SiteShell ++> desktop.pages.layout | web.pages.layout { SiteShell }
    core.social_graph ++> cli.commands.feed { create_tweet, load_feed }
    core.source.files ++> web.main;
}

graph import cli {
    commands.common ++> main { EXIT_USAGE, warn }
    commands.docs ++> main { run_docs }
    commands.feed ++> main { run_feed, run_post }
    commands.score ++> main { run_score }
}

graph import cli.commands {
    common ++> [
        docs { EXIT_OK, explain_bridge_error },
        feed { EXIT_OK, EXIT_REJECTED, EXIT_USAGE, explain_bridge_error, warn },
        score { EXIT_FAILURE, EXIT_OK, EXIT_USAGE, warn },
    ]
}

graph import core {
    ai ++> [
        leaderboard.scoring { CodeReview },
        scoring_service { optional_review },
    ]
    async_utils ++> jacyac.registration | site.docs.DocsShell { sleep }
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
        | jacyac.native.screens.ExploreScreen
        | jacyac.native.screens.FeedScreen
        | jacyac.native.screens.ProfileScreen
        | jacyac.native.screens.ScoresScreen
        | site.ui.Navbar { useTheme }
    brand.tokens ++> jacyac.native.theme { Colors, font_family, fonts, radii, spacing }
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
        install | jacyac.github.repos { fetch },
        leaderboard.board | social_graph { parse_repo_url },
        leaderboard.scoring { RepoMeta },
        packages.catalog { API_ROOT, fetch, parse_repo_url },
        scoring_service {
            RepoMeta,
            code_breakdown,
            download_tarball,
            head_sha,
            repo_meta,
            text_of,
            untar
        },
    ]
    github_contracts ++> [
        github { GithubCommit, GithubRepository },
        jacyac.github.repos { GithubRepository, GithubUser },
    ]
    install ++> site.ui.Navbar { ensure_install }
    jac_tokenizer ++> site.ui.CodeBlock { Token, tokenize_lines }
    jacyac.format ++> [
        site.jacyac.components.ExploreTab
            | site.jacyac.components.ProfileHeader
            | site.jacyac.components.ProjectCard
            | site.jacyac.components.RightSidebar
            | site.jacyac.components.TweetCard { handle_of, initial_of },
        site.jacyac.components.Sidebar { handle_of },
    ]
    jacyac.genius ++> social_graph { GuideSample, optional_fact, random_guide }
    jacyac.github.auth ++> [
        site.jacyac.GithubCallback { complete_native_github, github_callback_mode },
        social_graph { users },
    ]
    jacyac.github.login ++> site.jacyac.GithubCallback { complete_web_login }
    jacyac.github.repos ++> social_graph { verified_owner }
    jacyac.identity ++> [
        site.jacyac.JacYac
            | site.jacyac.components.ExploreTab
            | site.jacyac.components.ProfileHeader
            | site.jacyac.components.RightSidebar { avatar_of, name_of },
        site.jacyac.components.ProjectCard { avatar_of, project_error_message },
        site.jacyac.components.TweetCard { avatar_of },
    ]
    jacyac.limits ++> social_graph { PostingDenied, posting_limit }
    jacyac.native.JacYacMobile ++> site.landing.MobileShowcase { JacYacMobile }
    jacyac.scores ++> site.jacyac.components.NinjaScores { useScores }
    jacyac.state ++> [
        site.jacyac.JacYac { useJacYac },
        site.jacyac.components.NinjaScores { JacYacState },
    ]
    jacyac.validation ++> [
        site.jacyac.components.Composer { chars_left, post_limit, valid_post },
        social_graph { valid_post },
    ]
    leaderboard.board ++> social_graph { BoardHub, OnBoard, RepoEntry }
    leaderboard.format ++> [
        site.jacyac.components.ProjectCard { belt_class, belt_label, time_ago },
        site.leaderboard.Methodology { belt_class, belt_label },
    ]
    leaderboard.scoring ++> [
        scoring_service { RepoAnalysis, ScoreBreakdown, analyze, score },
        social_graph { ScoreBreakdown },
    ]
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
    scoring_service ++> social_graph { ScoredPayload, fetch_and_score }
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
        jacyac.scores
            | site.jacyac.components.ProjectCard
            | site.jacyac.components.ProjectsPanel { Project },
        jacyac.state {
            ChannelBundle,
            Profile,
            ProfileBundle,
            Project,
            TrendingTag,
            Tweet,
            add_comment,
            add_project,
            clear_avatar,
            create_channel,
            create_channel_tweet,
            create_tweet,
            delete_tweet,
            follow_user,
            get_all_profiles,
            get_all_projects,
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
            remove_project,
            rescore_project,
            set_avatar,
            setup_profile,
            unfollow_user,
            update_profile
        },
        site.jacyac.components.ExploreTab { Profile, Project },
        site.jacyac.components.ProfileEditor { Profile },
    ]
    source.files ++> [
        site.landing.Showcase { SourceView, example_sources },
        site.source.CodeSpotlight { SourceSpan, source_span },
        site.source.SourceBrowser { SourceFile, SourceView, source_file, source_tree },
    ]
    timefmt ++> [
        docs.sync | progress { now_iso },
        install | social_graph { now_iso, seconds_since },
        leaderboard.scoring { days_since },
    ]
    utils ++> site.docs.DocsSidebar
        | site.docs.DocsTocRail
        | site.jacyac.components.ExploreTab
        | site.jacyac.components.MobileNav
        | site.jacyac.components.ProjectCard
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
    graph ++> sync {
        DocVersion,
        DocsHub,
        HasHub,
        HasVersion,
        NextPage,
        _pretty,
        _sweep_stale,
        _version,
        place_page,
        rewrite_href,
        toc_of
    }
}

graph import core.jacyac {
    format ++> [
        identity
            | native.components.TweetCard
            | native.screens.ExploreScreen
            | native.screens.ProfileScreen { handle_of },
        native.components.Avatar { handle_of, initial_of },
        native.screens.ChannelsScreen { count_label },
    ]
    github.auth ++> session { github_enabled }
    github.login ++> session { github_login }
    github.repos ++> scores { GithubRepo, github_repositories }
    identity ++> [
        native.components.Avatar { avatar_of },
        native.screens.ExploreScreen | native.screens.ProfileScreen { name_of },
        state { project_error_message },
    ]
    registration ++> session { register_with_challenge }
    scores ++> native.screens.ScoresScreen { useScores }
    session ++> state { Session, stored_username, useSession }
    state ++> [
        native.JacYacMobile { useJacYac },
        native.screens.ScoresScreen | scores { JacYacState },
    ]
    validation ++> [
        native.components.Composer { chars_left },
        state { valid_post },
    ]
}

graph import core.jacyac.github {
    auth ++> [
        login { begin_github, finish_github },
        repos { github_id },
    ]
}

graph import core.jacyac.native {
    components.Avatar ++> screens.ExploreScreen | screens.ProfileScreen { Avatar }
    components.BrandMark ++> JacYacMobile | screens.AuthScreen { BrandMark }
    components.BridgeBanner ++> JacYacMobile { BridgeBanner }
    components.Composer ++> screens.ChannelsScreen | screens.FeedScreen { Composer }
    components.StatusView ++> [
        screens.ChannelsScreen | screens.ExploreScreen | screens.FeedScreen {
            EmptyState,
            LoadingRows
        },
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
        | screens.ExploreScreen
        | screens.FeedScreen
        | screens.ProfileScreen { Icon }
    screens.AuthScreen ++> JacYacMobile { AuthScreen }
    screens.ChannelsScreen ++> JacYacMobile { ChannelsScreen }
    screens.ExploreScreen ++> JacYacMobile { ExploreScreen }
    screens.FeedScreen ++> JacYacMobile { FeedScreen }
    screens.ProfileScreen ++> JacYacMobile { ProfileScreen }
    screens.ScoresScreen ++> JacYacMobile { ScoresScreen }
    theme ++> JacYacMobile
        | components.Avatar
        | components.BridgeBanner
        | components.Composer
        | components.StatusView
        | components.TabBar
        | components.TweetCard
        | screens.AuthScreen
        | screens.ChannelsScreen
        | screens.ExploreScreen
        | screens.FeedScreen
        | screens.ProfileScreen
        | screens.ScoresScreen { makeStyles }
}

graph import core.jacyac.native.components {
    Avatar ++> Composer | TweetCard { Avatar }
}

graph import core.leaderboard {
    scoring ++> board { RepoFeatures, ScoreBreakdown }
}

graph import core.site {
    docs.Markdown ++> packages.PackagePage { Markdown }
    game.webgl_host ++> landing.WasmGame { run_game }
    landing.CopyCommand ++> packages.PackagePage | packages.PackagesIndex {
        CopyCommand
    }
    leaderboard.Methodology ++> jacyac.components.NinjaScores { Methodology }
    source.CodeSpotlight ++> landing.MobileShowcase | landing.WaitWuuut {
        CodeSpotlight
    }
    source.FloatingSource ++> landing.Hero | landing.WaitWuuut { FloatingSource }
    source.SourceBrowser ++> landing.ExplorerFinale { SourceBrowser }
    ui.CodeBlock ++> [
        docs.Markdown
            | docs.MermaidDiagram
            | source.CodeSpotlight
            | source.SourceBrowser { CodeLines },
        landing.Showcase { CodeBlock },
    ]
    ui.GraphBackdrop ++> docs.DocsShell | landing.Hero | leaderboard.Methodology {
        GraphBackdrop
    }
    ui.SectionRail ++> landing.Home | landing.WaitWuuut { SectionRail }
    ui.alert_dialog ++> jacyac.components.ProjectCard | jacyac.components.TweetCard {
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
        | jacyac.components.ProjectCard
        | jacyac.components.RightSidebar
        | jacyac.components.Sidebar
        | jacyac.components.TweetCard { Avatar, AvatarFallback, AvatarImage }
    ui.badge ++> jacyac.components.ChannelsTab
        | jacyac.components.ProjectCard
        | jacyac.components.RightSidebar
        | jacyac.components.Sidebar
        | landing.Agents
        | landing.BookSection
        | landing.ExplorerFinale
        | landing.Hero
        | landing.MobileShowcase
        | landing.OneBinary
        | landing.Showcase
        | landing.WaitWuuut
        | landing.WasmGame
        | landing.WhyJac
        | leaderboard.Methodology
        | packages.PackagePage
        | packages.PackagesIndex { Badge }
    ui.button ++> [
        jacyac.JacYac
            | jacyac.components.AuthForm
            | jacyac.components.ChannelsTab
            | jacyac.components.Composer
            | jacyac.components.ExploreTab
            | jacyac.components.NinjaScores
            | jacyac.components.ProfileEditor
            | jacyac.components.ProfileHeader
            | jacyac.components.ProjectCard
            | jacyac.components.ProjectsPanel
            | jacyac.components.RightSidebar
            | jacyac.components.Sidebar
            | jacyac.components.TweetCard
            | jacyac.components.WelcomeBanner
            | landing.WasmGame { Button },
        landing.BookSection | landing.ExplorerFinale | landing.Hero { buttonVariants },
    ]
    ui.card ++> [
        jacyac.components.AuthForm {
            Card,
            CardContent,
            CardDescription,
            CardHeader,
            CardTitle
        },
        jacyac.components.RightSidebar | landing.Capabilities {
            Card,
            CardContent,
            CardHeader,
            CardTitle
        },
    ]
    ui.carousel ++> landing.Capabilities | landing.WhyJac {
        Carousel,
        CarouselContent,
        CarouselDots,
        CarouselItem,
        CarouselNext,
        CarouselPrevious
    }
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
        | jacyac.components.FeedTab {
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
        | jacyac.components.NinjaScores
        | jacyac.components.ProfileEditor
        | jacyac.components.ProjectsPanel
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
    ui.tabs ++> docs.Markdown | landing.Showcase {
        Tabs,
        TabsContent,
        TabsList,
        TabsTrigger
    }
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

graph import core.site.jacyac {
    components.AuthForm ++> JacYac { AuthForm }
    components.ChannelsTab ++> JacYac { ChannelsTab }
    components.ExploreTab ++> JacYac { ExploreTab }
    components.FeedTab ++> JacYac { FeedTab }
    components.MobileNav ++> JacYac { MobileNav }
    components.NinjaScores ++> JacYac { NinjaScores }
    components.ProfileEditor ++> JacYac { ProfileEditor }
    components.ProfileHeader ++> JacYac { ProfileHeader }
    components.ProjectsPanel ++> JacYac { ProjectsPanel }
    components.RightSidebar ++> JacYac { RightSidebar }
    components.Sidebar ++> JacYac { Sidebar }
    components.TweetCard ++> JacYac { TweetCard }
}

graph import core.site.jacyac.components {
    Composer ++> ChannelsTab | FeedTab { Composer }
    ProjectCard ++> ExploreTab | NinjaScores | ProjectsPanel { ProjectCard }
    TweetCard ++> ChannelsTab | FeedTab { TweetCard }
    WelcomeBanner ++> FeedTab { WelcomeBanner }
}

graph import core.site.landing {
    Agents ++> Home { Agents }
    BookSection ++> Home { BookSection }
    Capabilities ++> Home { Capabilities }
    CopyCommand ++> [
        Agents | Hero { CopyCommand },
        ExplorerFinale { CopyCommandBlock },
    ]
    ExplorerFinale ++> Home { ExplorerFinale }
    Hero ++> Home { Hero }
    MobileShowcase ++> Home { MobileShowcase }
    OneBinary ++> Home { OneBinary }
    Reveal ++> Agents
        | BookSection
        | Capabilities
        | ExplorerFinale
        | MobileShowcase
        | OneBinary
        | Showcase
        | StatsBand
        | WaitWuuut
        | WasmGame
        | WhyJac { Reveal }
    Showcase ++> Home { Showcase }
    StatsBand ++> Home { StatsBand }
    WasmGame ++> Home { WasmGame }
    WhyJac ++> [
        Capabilities { WhySlide },
        Home { WhyJac },
    ]
    diagrams.GradualBorrowDiagram ++> WaitWuuut | WhyJac { GradualBorrowDiagram }
    diagrams.PolypilerDiagram ++> OneBinary | WaitWuuut { PolypilerDiagram }
    diagrams.SynechicDiagram ++> WaitWuuut | WhyJac { SynechicDiagram }
    diagrams.TopokineticDiagram ++> WaitWuuut | WhyJac { TopokineticDiagram }
}

graph import core.site.landing.diagrams {
    motion ++> GradualBorrowDiagram
        | PolypilerDiagram
        | SynechicDiagram
        | TopokineticDiagram { view_once }
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
    label ++> field { Label }
    separator ++> field { Separator }
}

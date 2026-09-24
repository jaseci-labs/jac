impl import {
    edge CoreInternal: core.* --> core.*;
    edge AppOverCore: core.* --> web.* | mobile.* | cli.* | desktop.*;
    edge WebInternal: web.* --> web.*;
    edge MobileInternal: mobile.* --> mobile.*;
    edge CliInternal: cli.* --> cli.*;
    edge DesktopInternal: desktop.* --> desktop.*;
    edge SsoFunnel: jaclang.scale.sso.* --> core.jacyac.github.auth;
    edge BridgeFunnel: jaclang.server.bridge --> cli.commands.*;
}

impl import cli.commands {
    common --> cli.commands.docs { EXIT_OK, explain_bridge_error }
    common --> cli.commands.feed {
        EXIT_OK,
        EXIT_REJECTED,
        EXIT_USAGE,
        explain_bridge_error,
        warn
    }
    common --> cli.commands.score { EXIT_FAILURE, EXIT_OK, EXIT_USAGE, warn }
    common --> cli.main { EXIT_USAGE, warn }
    docs --> cli.main { run_docs }
    feed --> cli.main { run_feed, run_post }
    score --> cli.main { run_score }
}

impl import core {
    ai --> cli.commands.score | core.scoring_service { optional_review }
    ai --> core.leaderboard.scoring { CodeReview }
    async_utils --> core.jacyac.registration | core.site.docs.DocsShell { sleep }
    github --> cli.commands.score {
        RepoMeta,
        code_breakdown,
        download_tarball,
        head_sha,
        mb_of,
        repo_meta,
        text_of,
        untar
    }
    github --> core.install | core.jacyac.github.repos { fetch }
    github --> core.leaderboard.scoring { RepoMeta }
    github --> core.scoring_service {
        RepoMeta,
        code_breakdown,
        download_tarball,
        head_sha,
        repo_meta,
        text_of,
        untar
    }
    github --> core.social_graph | core.leaderboard.board { parse_repo_url }
    github_contracts --> core.github { GithubCommit, GithubRepository }
    github_contracts --> core.jacyac.github.repos { GithubRepository, GithubUser }
    install --> core.site.ui.Navbar { ensure_install }
    install --> web.main { ensure_install, install_sh }
    jac_tokenizer --> core.site.ui.CodeBlock { Token, tokenize_lines }
    scoring_service --> core.social_graph { ScoredPayload, fetch_and_score }
    social_graph --> cli.commands.feed { create_tweet, load_feed }
    social_graph --> core.jacyac.native.components.TweetCard { Tweet }
    social_graph --> core.jacyac.native.screens.ChannelsScreen { ChannelBundle, Tweet }
    social_graph --> core.jacyac.native.screens.ExploreScreen { Profile, TrendingTag }
    social_graph --> core.jacyac.native.screens.FeedScreen { Tweet }
    social_graph --> core.jacyac.native.screens.ProfileScreen { ProfileBundle }
    social_graph --> core.jacyac.scores { Project }
    social_graph --> core.jacyac.state {
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
    }
    social_graph --> core.site.jacyac.components.ChannelsTab { ChannelBundle, Tweet }
    social_graph --> core.site.jacyac.components.ExploreTab { Profile, Project }
    social_graph --> core.site.jacyac.components.FeedTab { Tweet }
    social_graph --> core.site.jacyac.components.ProfileEditor { Profile }
    social_graph --> core.site.jacyac.components.ProfileHeader { ProfileBundle }
    social_graph --> core.site.jacyac.components.ProjectCard { Project }
    social_graph --> core.site.jacyac.components.ProjectsPanel { Project }
    social_graph --> core.site.jacyac.components.RightSidebar { Profile, TrendingTag }
    social_graph --> core.site.jacyac.components.TweetCard { Tweet }
    timefmt --> core.install | core.social_graph { now_iso, seconds_since }
    timefmt --> core.leaderboard.scoring { days_since }
    timefmt --> core.progress | core.docs.sync { now_iso }
    utils --> core.site.docs.DocsSidebar { cn }
    utils --> core.site.docs.DocsTocRail { cn }
    utils --> core.site.jacyac.components.ExploreTab { cn }
    utils --> core.site.jacyac.components.MobileNav { cn }
    utils --> core.site.jacyac.components.ProjectCard { cn }
    utils --> core.site.jacyac.components.Sidebar { cn }
    utils --> core.site.jacyac.components.TweetCard { cn }
    utils --> core.site.landing.BookSection { cn }
    utils --> core.site.landing.CopyCommand { cn }
    utils --> core.site.landing.Hero { cn }
    utils --> core.site.ui.CodeBlock { cn }
    utils --> core.site.ui.Navbar { cn }
    utils --> core.site.ui.accordion { cn }
    utils --> core.site.ui.alert_dialog { cn }
    utils --> core.site.ui.avatar { cn }
    utils --> core.site.ui.badge { cn }
    utils --> core.site.ui.button { cn }
    utils --> core.site.ui.card { cn }
    utils --> core.site.ui.carousel { cn }
    utils --> core.site.ui.dialog { cn }
    utils --> core.site.ui.dropdown_menu { cn }
    utils --> core.site.ui.empty { cn }
    utils --> core.site.ui.field { cn }
    utils --> core.site.ui.hover_card { cn }
    utils --> core.site.ui.input { cn }
    utils --> core.site.ui.label { cn }
    utils --> core.site.ui.select { cn }
    utils --> core.site.ui.separator { cn }
    utils --> core.site.ui.skeleton { cn }
    utils --> core.site.ui.tabs { cn }
    utils --> core.site.ui.textarea { cn }
    utils --> core.site.ui.tooltip { cn }
    utils --> core.site.landing.Reveal | core.site.source.FloatingSource { cn }
}

impl import core.brand {
    font --> core.jacyac.native.JacYacMobile { useBrandFont }
    logo --> core.brand.styles { logo_xml }
    theme --> core.jacyac.native.JacYacMobile { useTheme }
    theme --> core.jacyac.native.components.Avatar { useTheme }
    theme --> core.jacyac.native.components.BridgeBanner { useTheme }
    theme --> core.jacyac.native.components.Composer { useTheme }
    theme --> core.jacyac.native.components.StatusView { useTheme }
    theme --> core.jacyac.native.components.TabBar { useTheme }
    theme --> core.jacyac.native.components.TweetCard { useTheme }
    theme --> core.jacyac.native.screens.AuthScreen { useTheme }
    theme --> core.jacyac.native.screens.ChannelsScreen { useTheme }
    theme --> core.jacyac.native.screens.ExploreScreen { useTheme }
    theme --> core.jacyac.native.screens.FeedScreen { useTheme }
    theme --> core.jacyac.native.screens.ProfileScreen { useTheme }
    theme --> core.jacyac.native.screens.ScoresScreen { useTheme }
    theme --> core.site.ui.Navbar { useTheme }
    tokens --> core.brand.styles {
        Colors,
        dark_palette,
        font_family,
        fonts,
        light_palette,
        radii,
        spacing
    }
    tokens --> core.brand.theme { Colors, dark_palette, light_palette }
    tokens --> core.jacyac.native.theme { Colors, font_family, fonts, radii, spacing }
}

impl import core.docs {
    graph --> cli.commands.docs { DocsStatus, docs_status }
    graph --> core.docs.sync {
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
    graph --> core.site.docs.DocsArticle { DocPageView }
    graph --> core.site.docs.DocsGraphFloat { TreeNode }
    graph --> core.site.docs.DocsShell {
        DocPageView,
        DocTree,
        DocsStatus,
        TreeNode,
        VersionInfo,
        doc_page,
        doc_tree,
        docs_status
    }
    graph --> core.site.docs.DocsSidebar { TreeNode, VersionInfo }
    graph --> core.site.docs.DocsTocRail { TocEntry }
    graph --> web.main { doc_page, doc_tree, docs_status, llms_txt }
    sync --> cli.commands.docs | web.main { docs_sync_tick }
}

impl import core.jacyac {
    format --> core.jacyac.identity { handle_of }
    format --> core.jacyac.native.components.Avatar { handle_of, initial_of }
    format --> core.jacyac.native.components.TweetCard { handle_of }
    format --> core.jacyac.native.screens.ChannelsScreen { count_label }
    format --> core.jacyac.native.screens.ExploreScreen { handle_of }
    format --> core.jacyac.native.screens.ProfileScreen { handle_of }
    format --> core.site.jacyac.components.ExploreTab { handle_of, initial_of }
    format --> core.site.jacyac.components.ProfileHeader { handle_of, initial_of }
    format --> core.site.jacyac.components.ProjectCard { handle_of, initial_of }
    format --> core.site.jacyac.components.RightSidebar { handle_of, initial_of }
    format --> core.site.jacyac.components.Sidebar { handle_of }
    format --> core.site.jacyac.components.TweetCard { handle_of, initial_of }
    genius --> core.social_graph { GuideSample, optional_fact, random_guide }
    identity --> core.jacyac.native.components.Avatar { avatar_of }
    identity --> core.jacyac.native.screens.ExploreScreen { name_of }
    identity --> core.jacyac.native.screens.ProfileScreen { name_of }
    identity --> core.jacyac.state { project_error_message }
    identity --> core.site.jacyac.JacYac { avatar_of, name_of }
    identity --> core.site.jacyac.components.ExploreTab { avatar_of, name_of }
    identity --> core.site.jacyac.components.ProfileHeader { avatar_of, name_of }
    identity --> core.site.jacyac.components.ProjectCard {
        avatar_of,
        project_error_message
    }
    identity --> core.site.jacyac.components.RightSidebar { avatar_of, name_of }
    identity --> core.site.jacyac.components.TweetCard { avatar_of }
    limits --> cli.commands.feed { PostingDenied }
    limits --> core.social_graph { PostingDenied, posting_limit }
    registration --> core.jacyac.session { register_with_challenge }
    scores --> core.jacyac.native.screens.ScoresScreen { useScores }
    scores --> core.site.jacyac.components.NinjaScores { useScores }
    session --> core.jacyac.state { Session, stored_username, useSession }
    state --> core.jacyac.native.JacYacMobile | core.site.jacyac.JacYac { useJacYac }
    state --> core.jacyac.native.screens.ScoresScreen { JacYacState }
    state --> core.jacyac.scores { JacYacState }
    state --> core.site.jacyac.components.NinjaScores { JacYacState }
    validation --> core.jacyac.native.components.Composer { chars_left }
    validation --> core.site.jacyac.components.Composer {
        chars_left,
        post_limit,
        valid_post
    }
    validation --> core.social_graph | core.jacyac.state { valid_post }
}

impl import core.jacyac.github {
    auth --> core.jacyac.github.login { begin_github, finish_github }
    auth --> core.jacyac.github.repos { github_id }
    auth --> core.jacyac.session { github_enabled }
    auth --> core.site.jacyac.GithubCallback {
        complete_native_github,
        github_callback_mode
    }
    auth --> core.social_graph { users }
    auth --> desktop.main {
        begin_github,
        complete_native_github,
        finish_github,
        github_callback_mode,
        github_enabled,
        poll_github
    }
    auth --> web.main {
        begin_github,
        complete_native_github,
        finish_github,
        github_callback_mode,
        github_enabled,
        poll_github
    }
    login --> core.jacyac.session { github_login }
    login --> core.site.jacyac.GithubCallback { complete_web_login }
    repos --> core.jacyac.scores { GithubRepo, github_repositories }
    repos --> core.social_graph { verified_owner }
    repos --> desktop.main | web.main { github_repositories }
}

impl import core.jacyac.native {
    JacYacMobile --> core.site.landing.MobileShowcase | mobile.main { JacYacMobile }
    icon --> core.jacyac.native.JacYacMobile { Icon }
    icon --> core.jacyac.native.components.BridgeBanner { Icon }
    icon --> core.jacyac.native.components.StatusView { Icon }
    icon --> core.jacyac.native.components.TabBar { Icon }
    icon --> core.jacyac.native.components.TweetCard { Icon }
    icon --> core.jacyac.native.screens.AuthScreen { Icon }
    icon --> core.jacyac.native.screens.ChannelsScreen { Icon }
    icon --> core.jacyac.native.screens.ExploreScreen { Icon }
    icon --> core.jacyac.native.screens.FeedScreen { Icon }
    icon --> core.jacyac.native.screens.ProfileScreen { Icon }
    theme --> core.jacyac.native.JacYacMobile { makeStyles }
    theme --> core.jacyac.native.components.Avatar { makeStyles }
    theme --> core.jacyac.native.components.BridgeBanner { makeStyles }
    theme --> core.jacyac.native.components.Composer { makeStyles }
    theme --> core.jacyac.native.components.StatusView { makeStyles }
    theme --> core.jacyac.native.components.TabBar { makeStyles }
    theme --> core.jacyac.native.components.TweetCard { makeStyles }
    theme --> core.jacyac.native.screens.AuthScreen { makeStyles }
    theme --> core.jacyac.native.screens.ChannelsScreen { makeStyles }
    theme --> core.jacyac.native.screens.ExploreScreen { makeStyles }
    theme --> core.jacyac.native.screens.FeedScreen { makeStyles }
    theme --> core.jacyac.native.screens.ProfileScreen { makeStyles }
    theme --> core.jacyac.native.screens.ScoresScreen { makeStyles }
}

impl import core.jacyac.native.components {
    Avatar --> core.jacyac.native.components.Composer { Avatar }
    Avatar --> core.jacyac.native.components.TweetCard { Avatar }
    Avatar --> core.jacyac.native.screens.ExploreScreen { Avatar }
    Avatar --> core.jacyac.native.screens.ProfileScreen { Avatar }
    BrandMark --> core.jacyac.native.JacYacMobile { BrandMark }
    BrandMark --> core.jacyac.native.screens.AuthScreen { BrandMark }
    BridgeBanner --> core.jacyac.native.JacYacMobile { BridgeBanner }
    Composer --> core.jacyac.native.screens.ChannelsScreen { Composer }
    Composer --> core.jacyac.native.screens.FeedScreen { Composer }
    StatusView --> core.jacyac.native.screens.ChannelsScreen { EmptyState, LoadingRows }
    StatusView --> core.jacyac.native.screens.ExploreScreen { EmptyState, LoadingRows }
    StatusView --> core.jacyac.native.screens.FeedScreen { EmptyState, LoadingRows }
    StatusView --> core.jacyac.native.screens.ProfileScreen { EmptyState }
    TabBar --> core.jacyac.native.JacYacMobile { TabBar }
    TweetCard --> core.jacyac.native.screens.ChannelsScreen { TweetCard }
    TweetCard --> core.jacyac.native.screens.FeedScreen { TweetCard }
    TweetCard --> core.jacyac.native.screens.ProfileScreen { TweetCard }
}

impl import core.jacyac.native.screens {
    AuthScreen --> core.jacyac.native.JacYacMobile { AuthScreen }
    ChannelsScreen --> core.jacyac.native.JacYacMobile { ChannelsScreen }
    ExploreScreen --> core.jacyac.native.JacYacMobile { ExploreScreen }
    FeedScreen --> core.jacyac.native.JacYacMobile { FeedScreen }
    ProfileScreen --> core.jacyac.native.JacYacMobile { ProfileScreen }
    ScoresScreen --> core.jacyac.native.JacYacMobile { ScoresScreen }
}

impl import core.leaderboard {
    board --> core.social_graph { BoardHub, OnBoard, RepoEntry }
    format --> core.site.jacyac.components.ProjectCard {
        belt_class,
        belt_label,
        time_ago
    }
    format --> core.site.leaderboard.Methodology { belt_class, belt_label }
    scoring --> cli.commands.score { RepoAnalysis, ScoreBreakdown, analyze, score }
    scoring --> core.leaderboard.board { RepoFeatures, ScoreBreakdown }
    scoring --> core.scoring_service { RepoAnalysis, ScoreBreakdown, analyze, score }
    scoring --> core.social_graph { ScoreBreakdown }
}

impl import core.site.docs {
    DocsArticle --> core.site.docs.DocsShell { DocsArticle, DocsArticleSkeleton }
    DocsGraphFloat --> core.site.docs.DocsSidebar { DocsGraphFloat }
    DocsShell --> desktop.pages.docs.index | web.pages.docs.index { DocsShell }
    DocsSidebar --> core.site.docs.DocsShell { DocsSidebar }
    DocsTocRail --> core.site.docs.DocsShell { DocsTocRail }
    Markdown --> core.site.docs.DocsArticle { Markdown }
    MermaidDiagram --> core.site.docs.Markdown { MermaidDiagram }
}

impl import core.site.game {
    webgl_host --> core.site.landing.WasmGame { run_game }
    arena --> core.site.game.webgl_host {
        frame,
        get_deaths,
        get_hp,
        get_score,
        init,
        shutdown
    }
    gmath --> core.site.game.arena { clampf, jsin, lerp }
    gmath --> core.site.game.sim {
        DEG2RAD,
        Rng,
        jcos,
        jsin,
        jsqrt,
        rand01,
        rand_range,
        rand_sign
    }
    platform_rl --> core.site.game.arena {
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
    sim --> core.site.game.arena {
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
    type sim --> core.site.game.webgl_host { Game }
}

impl import core.site.jacyac {
    GithubCallback --> desktop.pages.jacyac.github.callback { GithubCallback }
    GithubCallback --> web.pages.jacyac.github.callback { GithubCallback }
    JacYac --> desktop.pages.jacyac { JacYac }
    JacYac --> desktop.pages.jacyac.scores { JacYac }
    JacYac --> desktop.pages.socialize { JacYac }
    JacYac --> web.pages.jacyac { JacYac }
    JacYac --> web.pages.jacyac.scores { JacYac }
    JacYac --> web.pages.socialize { JacYac }
}

impl import core.site.jacyac.components {
    AuthForm --> core.site.jacyac.JacYac { AuthForm }
    ChannelsTab --> core.site.jacyac.JacYac { ChannelsTab }
    Composer --> core.site.jacyac.components.ChannelsTab { Composer }
    Composer --> core.site.jacyac.components.FeedTab { Composer }
    ExploreTab --> core.site.jacyac.JacYac { ExploreTab }
    FeedTab --> core.site.jacyac.JacYac { FeedTab }
    MobileNav --> core.site.jacyac.JacYac { MobileNav }
    NinjaScores --> core.site.jacyac.JacYac { NinjaScores }
    ProfileEditor --> core.site.jacyac.JacYac { ProfileEditor }
    ProfileHeader --> core.site.jacyac.JacYac { ProfileHeader }
    ProjectCard --> core.site.jacyac.components.ExploreTab { ProjectCard }
    ProjectCard --> core.site.jacyac.components.NinjaScores { ProjectCard }
    ProjectCard --> core.site.jacyac.components.ProjectsPanel { ProjectCard }
    ProjectsPanel --> core.site.jacyac.JacYac { ProjectsPanel }
    RightSidebar --> core.site.jacyac.JacYac { RightSidebar }
    Sidebar --> core.site.jacyac.JacYac { Sidebar }
    TweetCard --> core.site.jacyac.JacYac { TweetCard }
    TweetCard --> core.site.jacyac.components.ChannelsTab { TweetCard }
    TweetCard --> core.site.jacyac.components.FeedTab { TweetCard }
    WelcomeBanner --> core.site.jacyac.components.FeedTab { WelcomeBanner }
}

impl import core.site.landing {
    Agents --> core.site.landing.Home { Agents }
    BookSection --> core.site.landing.Home { BookSection }
    Capabilities --> core.site.landing.Home { Capabilities }
    CopyCommand --> core.site.landing.Agents | core.site.landing.Hero { CopyCommand }
    CopyCommand --> core.site.landing.ExplorerFinale { CopyCommandBlock }
    ExplorerFinale --> core.site.landing.Home { ExplorerFinale }
    Hero --> core.site.landing.Home { Hero }
    Home --> desktop.pages.index | web.pages.index { Home }
    MobileShowcase --> core.site.landing.Home { MobileShowcase }
    OneBinary --> core.site.landing.Home { OneBinary }
    Reveal --> core.site.landing.Agents { Reveal }
    Reveal --> core.site.landing.BookSection { Reveal }
    Reveal --> core.site.landing.Capabilities { Reveal }
    Reveal --> core.site.landing.ExplorerFinale { Reveal }
    Reveal --> core.site.landing.MobileShowcase { Reveal }
    Reveal --> core.site.landing.OneBinary { Reveal }
    Reveal --> core.site.landing.Showcase { Reveal }
    Reveal --> core.site.landing.StatsBand { Reveal }
    Reveal --> core.site.landing.WaitWuuut { Reveal }
    Reveal --> core.site.landing.WasmGame { Reveal }
    Reveal --> core.site.landing.WhyJac { Reveal }
    Showcase --> core.site.landing.Home { Showcase }
    StatsBand --> core.site.landing.Home { StatsBand }
    WasmGame --> core.site.landing.Home { WasmGame }
    WhyJac --> core.site.landing.Capabilities { WhySlide }
    WhyJac --> core.site.landing.Home { WhyJac }
}

impl import core.site.landing.diagrams {
    GradualBorrowDiagram --> core.site.landing.WaitWuuut { GradualBorrowDiagram }
    GradualBorrowDiagram --> core.site.landing.WhyJac { GradualBorrowDiagram }
    PolypilerDiagram --> core.site.landing.OneBinary { PolypilerDiagram }
    PolypilerDiagram --> core.site.landing.WaitWuuut { PolypilerDiagram }
    SynechicDiagram --> core.site.landing.WaitWuuut { SynechicDiagram }
    SynechicDiagram --> core.site.landing.WhyJac { SynechicDiagram }
    TopokineticDiagram --> core.site.landing.WaitWuuut { TopokineticDiagram }
    TopokineticDiagram --> core.site.landing.WhyJac { TopokineticDiagram }
    motion --> core.site.landing.diagrams.GradualBorrowDiagram { view_once }
    motion --> core.site.landing.diagrams.PolypilerDiagram { view_once }
    motion --> core.site.landing.diagrams.SynechicDiagram { view_once }
    motion --> core.site.landing.diagrams.TopokineticDiagram { view_once }
}

impl import core.site.leaderboard {
    Methodology --> core.site.jacyac.components.NinjaScores { Methodology }
    Methodology --> desktop.pages.methodology { Methodology }
    Methodology --> web.pages.methodology { Methodology }
}

impl import core.site.source {
    CodeSpotlight --> core.site.landing.MobileShowcase { CodeSpotlight }
    CodeSpotlight --> core.site.landing.WaitWuuut { CodeSpotlight }
    FloatingSource --> core.site.landing.Hero { FloatingSource }
    FloatingSource --> core.site.landing.WaitWuuut { FloatingSource }
    SourceBrowser --> core.site.landing.ExplorerFinale { SourceBrowser }
    SourceBrowser --> core.site.source.FloatingSource { SourceBrowser }
}

impl import core.site.ui {
    CodeBlock --> core.site.docs.Markdown { CodeLines }
    CodeBlock --> core.site.docs.MermaidDiagram { CodeLines }
    CodeBlock --> core.site.landing.Showcase { CodeBlock }
    CodeBlock --> core.site.source.CodeSpotlight { CodeLines }
    CodeBlock --> core.site.source.SourceBrowser { CodeLines }
    Footer --> core.site.ui.SiteShell { Footer }
    GraphBackdrop --> core.site.docs.DocsShell { GraphBackdrop }
    GraphBackdrop --> core.site.landing.Hero { GraphBackdrop }
    GraphBackdrop --> core.site.leaderboard.Methodology { GraphBackdrop }
    GraphBackdrop --> core.site.ui.NotFound { GraphBackdrop }
    Navbar --> core.site.ui.SiteShell { Navbar }
    SectionRail --> core.site.landing.Home | core.site.landing.WaitWuuut { SectionRail }
    SiteShell --> desktop.pages.layout | web.pages.layout { SiteShell }
    alert_dialog --> core.site.jacyac.components.ProjectCard {
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
    alert_dialog --> core.site.jacyac.components.TweetCard {
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
    avatar --> core.site.jacyac.components.Composer {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    avatar --> core.site.jacyac.components.ExploreTab {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    avatar --> core.site.jacyac.components.ProfileHeader {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    avatar --> core.site.jacyac.components.ProjectCard {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    avatar --> core.site.jacyac.components.RightSidebar {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    avatar --> core.site.jacyac.components.Sidebar {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    avatar --> core.site.jacyac.components.TweetCard {
        Avatar,
        AvatarFallback,
        AvatarImage
    }
    badge --> core.site.jacyac.components.ChannelsTab { Badge }
    badge --> core.site.jacyac.components.ProjectCard { Badge }
    badge --> core.site.jacyac.components.RightSidebar { Badge }
    badge --> core.site.jacyac.components.Sidebar { Badge }
    badge --> core.site.landing.Agents { Badge }
    badge --> core.site.landing.BookSection { Badge }
    badge --> core.site.landing.ExplorerFinale { Badge }
    badge --> core.site.landing.Hero { Badge }
    badge --> core.site.landing.MobileShowcase { Badge }
    badge --> core.site.landing.OneBinary { Badge }
    badge --> core.site.landing.Showcase { Badge }
    badge --> core.site.landing.WaitWuuut { Badge }
    badge --> core.site.landing.WasmGame { Badge }
    badge --> core.site.landing.WhyJac { Badge }
    badge --> core.site.leaderboard.Methodology { Badge }
    button --> core.site.jacyac.JacYac { Button }
    button --> core.site.jacyac.components.AuthForm { Button }
    button --> core.site.jacyac.components.ChannelsTab { Button }
    button --> core.site.jacyac.components.Composer { Button }
    button --> core.site.jacyac.components.ExploreTab { Button }
    button --> core.site.jacyac.components.NinjaScores { Button }
    button --> core.site.jacyac.components.ProfileEditor { Button }
    button --> core.site.jacyac.components.ProfileHeader { Button }
    button --> core.site.jacyac.components.ProjectCard { Button }
    button --> core.site.jacyac.components.ProjectsPanel { Button }
    button --> core.site.jacyac.components.RightSidebar { Button }
    button --> core.site.jacyac.components.Sidebar { Button }
    button --> core.site.jacyac.components.TweetCard { Button }
    button --> core.site.jacyac.components.WelcomeBanner { Button }
    button --> core.site.landing.BookSection { buttonVariants }
    button --> core.site.landing.ExplorerFinale { buttonVariants }
    button --> core.site.landing.Hero { buttonVariants }
    button --> core.site.landing.WasmGame { Button }
    button --> core.site.ui.Navbar { buttonVariants }
    button --> core.site.ui.NotFound { buttonVariants }
    button --> core.site.ui.alert_dialog { Button }
    button --> core.site.ui.carousel { Button }
    button --> core.site.ui.dialog { buttonVariants }
    card --> core.site.jacyac.components.AuthForm {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle
    }
    card --> core.site.jacyac.components.RightSidebar {
        Card,
        CardContent,
        CardHeader,
        CardTitle
    }
    card --> core.site.landing.Capabilities { Card, CardContent, CardHeader, CardTitle }
    carousel --> core.site.landing.Capabilities {
        Carousel,
        CarouselContent,
        CarouselDots,
        CarouselItem,
        CarouselNext,
        CarouselPrevious
    }
    carousel --> core.site.landing.WhyJac {
        Carousel,
        CarouselContent,
        CarouselDots,
        CarouselItem,
        CarouselNext,
        CarouselPrevious
    }
    dialog --> core.site.jacyac.components.ChannelsTab {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogFooter,
        DialogHeader,
        DialogTitle
    }
    dropdown_menu --> core.site.jacyac.components.Sidebar {
        DropdownMenu,
        DropdownMenuContent,
        DropdownMenuGroup,
        DropdownMenuItem,
        DropdownMenuTrigger
    }
    empty --> core.site.jacyac.components.ChannelsTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle
    }
    empty --> core.site.jacyac.components.ExploreTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle
    }
    empty --> core.site.jacyac.components.FeedTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle
    }
    field --> core.site.jacyac.components.AuthForm { Field, FieldLabel }
    field --> core.site.jacyac.components.ChannelsTab { Field, FieldLabel }
    field --> core.site.jacyac.components.ProfileEditor { Field, FieldLabel }
    hover_card --> core.site.jacyac.components.RightSidebar {
        HoverCard,
        HoverCardContent,
        HoverCardTrigger
    }
    input --> core.site.docs.DocsSidebar { Input }
    input --> core.site.jacyac.components.AuthForm { Input }
    input --> core.site.jacyac.components.ChannelsTab { Input }
    input --> core.site.jacyac.components.NinjaScores { Input }
    input --> core.site.jacyac.components.ProfileEditor { Input }
    input --> core.site.jacyac.components.ProjectsPanel { Input }
    input --> core.site.jacyac.components.RightSidebar { Input }
    input --> core.site.jacyac.components.TweetCard { Input }
    label --> core.site.ui.field { Label }
    select --> core.site.docs.DocsSidebar {
        Select,
        SelectContent,
        SelectGroup,
        SelectItem,
        SelectTrigger,
        SelectValue
    }
    separator --> core.site.ui.field { Separator }
    skeleton --> core.site.docs.DocsArticle { Skeleton }
    skeleton --> core.site.docs.DocsSidebar { Skeleton }
    skeleton --> core.site.jacyac.components.ChannelsTab { Skeleton }
    skeleton --> core.site.jacyac.components.ExploreTab { Skeleton }
    skeleton --> core.site.jacyac.components.FeedTab { Skeleton }
    tabs --> core.site.docs.Markdown { Tabs, TabsContent, TabsList, TabsTrigger }
    tabs --> core.site.landing.Showcase { Tabs, TabsContent, TabsList, TabsTrigger }
    textarea --> core.site.jacyac.components.ChannelsTab { Textarea }
    textarea --> core.site.jacyac.components.Composer { Textarea }
    textarea --> core.site.jacyac.components.ProfileEditor { Textarea }
    tooltip --> core.site.jacyac.components.TweetCard {
        Tooltip,
        TooltipContent,
        TooltipProvider,
        TooltipTrigger
    }
}

impl import core.source {
    files --> core.site.landing.Showcase { SourceView, example_sources }
    files --> core.site.source.CodeSpotlight { SourceSpan, source_span }
    files --> core.site.source.SourceBrowser {
        SourceFile,
        SourceView,
        source_file,
        source_tree
    }
    files --> web.main {
        SourceFile,
        SourceSpan,
        SourceView,
        example_sources,
        source_file,
        source_span,
        source_tree
    }
}

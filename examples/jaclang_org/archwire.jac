graph layers {
    layer cli { cli; }
    layer core { core.*; }
    layer demos { demos.*; }
    layer mobile { mobile.*; }
    layer pages { pages.*; }
    """What no wire joins to the rest."""
    layer apart { web; }
}

graph spaces {
    space site: browser { entry web; pages.* | core.site.*; }
    space phone: hermes { entry mobile.main; }
    space arena: wasm {
        core.site.game.arena
            | core.site.game.sim
            | core.site.game.gmath
            | core.site.game.platform_rl;
    }
    space site_api: native {
        core.demo.api
            | core.docs.graph
            | core.docs.sync
            | core.source.*
            | core.install
            | core.github
            | core.packages.catalog;
    }
    space social: native { core.social_graph | core.jacyac.limits; }
    space knowledge: native { core.knowledge_service | core.knowledge.* | core.ninjaclaw.*; }
    space cli: native { entry cli; }
    space demo_preact: browser { entry demos.preact; }
    space demo_solid: browser { entry demos.solid; }

    app web { run site_api, social, knowledge; serve site, arena, demo_preact, demo_solid; }
    app desktop { run site, arena, demo_preact, demo_solid; }
    app mobile { run phone; }
    app cli { run cli; }
}

graph spaces fleet {
    app web { run site_api, social; serve site, arena, demo_preact, demo_solid; }
    app knowledge { run knowledge; }
}

graph spaces offline {
    app desktop { run site, arena, demo_preact, demo_solid, site_api, social, knowledge; }
}

graph import {
    edge Core: core --> cli | demos | mobile | pages;

    core.async_utils ++> core.site.docs.DocsShell { sleep }
    core.brand.font ++> core.jacyac.native.JacYacMobile { useBrandFont }
    core.brand.logo ++> core.brand.styles { logo_xml }
    core.brand.logo ++> core.jacyac.native.components.BrandMark.hermes { logo_xml }
    core.brand.theme ++> core.jacyac.native.JacYacMobile { useTheme }
    core.brand.theme ++> core.jacyac.native.components.Avatar { useTheme }
    core.brand.theme ++> core.jacyac.native.components.RemoteBanner { useTheme }
    core.brand.theme ++> core.jacyac.native.components.Composer { useTheme }
    core.brand.theme ++> core.jacyac.native.components.StatusView { useTheme }
    core.brand.theme ++> core.jacyac.native.components.TabBar { useTheme }
    core.brand.theme ++> core.jacyac.native.components.TweetCard { useTheme }
    core.brand.theme ++> core.jacyac.native.screens.AuthScreen { useTheme }
    core.brand.theme ++> core.jacyac.native.screens.ChannelsScreen { useTheme }
    core.brand.theme ++> core.jacyac.native.screens.ClawScreen { useTheme }
    core.brand.theme ++> core.jacyac.native.screens.ExploreScreen { useTheme }
    core.brand.theme ++> core.jacyac.native.screens.FeedScreen { useTheme }
    core.brand.theme ++> core.jacyac.native.screens.ProfileScreen { useTheme }
    core.brand.theme ++> core.site.ui.Navbar { useTheme }
    core.brand.tokens ++> core.brand.styles {
        Colors,
        dark_palette,
        font_family,
        light_palette,
        radii,
        spacing,
    }
    core.brand.tokens ++> core.brand.theme { Colors, dark_palette, light_palette }
    core.brand.tokens ++> core.jacyac.native.theme { Colors, font_family, fonts, radii, spacing }
    core.docs.corpus ++> core.docs.sync { DocBundle, bundle_from, label_of }
    core.docs.graph ++> cli { docs_status }
    core.docs.graph ++> core.docs.sync {
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
        page_name,
        page_path,
        place_page,
        rewrite_href,
        toc_of,
    }
    core.docs.graph ++> core.site.docs.DocsShell { doc_page, doc_tree, docs_status }
    core.docs.sync ++> cli { docs_sync_tick }
    core.github ++> core.install { fetch }
    core.github ++> core.packages.catalog { API_ROOT, fetch, parse_repo_url }
    core.docs.guides ++> core.docs.corpus { docs_version, nav_pages, parse_guide }
    core.docs.guides ++> core.docs.sync { DOCS_ENV, docs_dir }
    core.packages.index ++> core.packages.catalog {
        DEFAULT_REGISTRY_NAME,
        IndexEntry,
        Registry,
        is_package_name,
        registry_urls,
    }
    core.packages.semver ++> core.packages.catalog { SemverError, Version }
    core.site.landing.TechDemo ++> pages.tech_demo { TechDemo }
    core.site.landing.WaitWuuut ++> pages.wait_wuuut { WaitWuuut }
    core.site.ui.NotFound ++> pages.index { NotFound }
    core.version ++> core.knowledge_service { resolve_cli_version }
    core.version ++> core.ninjaclaw.graph { resolve_cli_version }
    core.install ++> core.site.ui.Navbar { ensure_install }
    core.jac_tokenizer ++> core.site.ui.CodeBlock { Token, tokenize_lines }
    core.jacyac.claw ++> core.jacyac.native.screens.ClawScreen { useClaw }
    core.jacyac.claw ++> core.site.jacyac.JacYac { useClaw }
    core.jacyac.claw ++> core.site.jacyac.components.NinjaclawTab { ClawModel }
    core.jacyac.claw ++> core.site.jacyac.components.TutorialsTab { ClawModel }
    core.jacyac.format ++> core.jacyac.identity { handle_of }
    core.jacyac.format ++> core.jacyac.native.components.Avatar { handle_of, initial_of }
    core.jacyac.format ++> core.jacyac.native.components.TweetCard { handle_of }
    core.jacyac.format ++> core.jacyac.native.screens.ChannelsScreen { count_label }
    core.jacyac.format ++> core.jacyac.native.screens.ClawScreen { count_label, handle_of }
    core.jacyac.format ++> core.jacyac.native.screens.ExploreScreen { handle_of }
    core.jacyac.format ++> core.jacyac.native.screens.ProfileScreen { handle_of }
    core.jacyac.format ++> core.site.jacyac.components.ExploreTab { handle_of, initial_of }
    core.jacyac.format ++> core.site.jacyac.components.NinjaclawTab { handle_of }
    core.jacyac.format ++> core.site.jacyac.components.ProfileHeader { handle_of, initial_of }
    core.jacyac.format ++> core.site.jacyac.components.RichText { text_segments }
    core.jacyac.format ++> core.site.jacyac.components.RightSidebar { handle_of, initial_of }
    core.jacyac.format ++> core.site.jacyac.components.Sidebar { handle_of }
    core.jacyac.format ++> core.site.jacyac.components.TutorialsTab { count_label }
    core.jacyac.format ++> core.site.jacyac.components.TweetCard { handle_of, initial_of }
    core.jacyac.identity ++> core.jacyac.native.components.Avatar { avatar_of }
    core.jacyac.identity ++> core.jacyac.native.screens.ExploreScreen { name_of }
    core.jacyac.identity ++> core.jacyac.native.screens.ProfileScreen { name_of }
    core.jacyac.identity ++> core.site.jacyac.JacYac { avatar_of, name_of }
    core.jacyac.identity ++> core.site.jacyac.components.ExploreTab { avatar_of, name_of }
    core.jacyac.identity ++> core.site.jacyac.components.ProfileHeader { avatar_of, name_of }
    core.jacyac.identity ++> core.site.jacyac.components.RightSidebar { avatar_of, name_of }
    core.jacyac.identity ++> core.site.jacyac.components.TweetCard { avatar_of }
    core.jacyac.limits ++> core.social_graph { posting_limit }
    core.jacyac.native.JacYacMobile ++> core.site.landing.MobileShowcase { JacYacMobile }
    core.jacyac.native.JacYacMobile ++> mobile.main { JacYacMobile }
    core.jacyac.native.components.Avatar ++> core.jacyac.native.components.Composer { Avatar }
    core.jacyac.native.components.Avatar ++> core.jacyac.native.components.TweetCard { Avatar }
    core.jacyac.native.components.Avatar ++> core.jacyac.native.screens.ExploreScreen { Avatar }
    core.jacyac.native.components.Avatar ++> core.jacyac.native.screens.ProfileScreen { Avatar }
    core.jacyac.native.components.BrandMark ++> core.jacyac.native.JacYacMobile { BrandMark }
    core.jacyac.native.components.BrandMark ++> core.jacyac.native.screens.AuthScreen { BrandMark }
    core.jacyac.native.components.RemoteBanner ++> core.jacyac.native.JacYacMobile { RemoteBanner }
    core.jacyac.native.components.Composer ++> core.jacyac.native.screens.ChannelsScreen {
        Composer,
    }
    core.jacyac.native.components.Composer ++> core.jacyac.native.screens.FeedScreen { Composer }
    core.jacyac.native.components.StatusView ++> core.jacyac.native.screens.ChannelsScreen {
        EmptyState,
        LoadingRows,
    }
    core.jacyac.native.components.StatusView ++> core.jacyac.native.screens.ClawScreen {
        EmptyState,
        LoadingRows,
    }
    core.jacyac.native.components.StatusView ++> core.jacyac.native.screens.ExploreScreen {
        EmptyState,
        LoadingRows,
    }
    core.jacyac.native.components.StatusView ++> core.jacyac.native.screens.FeedScreen {
        EmptyState,
        LoadingRows,
    }
    core.jacyac.native.components.StatusView ++> core.jacyac.native.screens.ProfileScreen {
        EmptyState,
    }
    core.jacyac.native.components.TabBar ++> core.jacyac.native.JacYacMobile { TabBar }
    core.jacyac.native.components.TweetCard ++> core.jacyac.native.screens.ChannelsScreen {
        TweetCard,
    }
    core.jacyac.native.components.TweetCard ++> core.jacyac.native.screens.FeedScreen { TweetCard }
    core.jacyac.native.components.TweetCard ++> core.jacyac.native.screens.ProfileScreen {
        TweetCard,
    }
    core.jacyac.native.icon ++> core.jacyac.native.components.RemoteBanner { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.components.StatusView { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.components.TabBar { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.components.TweetCard { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.screens.ChannelsScreen { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.screens.ClawScreen { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.screens.ExploreScreen { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.screens.FeedScreen { Icon }
    core.jacyac.native.icon ++> core.jacyac.native.screens.ProfileScreen { Icon }
    core.jacyac.native.screens.AuthScreen ++> core.jacyac.native.JacYacMobile { AuthScreen }
    core.jacyac.native.screens.ChannelsScreen ++> core.jacyac.native.JacYacMobile { ChannelsScreen }
    core.jacyac.native.screens.ClawScreen ++> core.jacyac.native.JacYacMobile { ClawScreen }
    core.jacyac.native.screens.ExploreScreen ++> core.jacyac.native.JacYacMobile { ExploreScreen }
    core.jacyac.native.screens.FeedScreen ++> core.jacyac.native.JacYacMobile { FeedScreen }
    core.jacyac.native.screens.ProfileScreen ++> core.jacyac.native.JacYacMobile { ProfileScreen }
    core.jacyac.native.theme ++> core.jacyac.native.JacYacMobile { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.components.Avatar { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.components.RemoteBanner { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.components.Composer { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.components.StatusView { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.components.TabBar { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.components.TweetCard { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.screens.AuthScreen { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.screens.ChannelsScreen { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.screens.ClawScreen { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.screens.ExploreScreen { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.screens.FeedScreen { makeStyles }
    core.jacyac.native.theme ++> core.jacyac.native.screens.ProfileScreen { makeStyles }
    core.jacyac.session ++> core.jacyac.state { Session, useSession }
    core.jacyac.state ++> core.jacyac.native.JacYacMobile { useJacYac }
    core.jacyac.state ++> core.site.jacyac.JacYac { useJacYac }
    core.jacyac.validation ++> core.jacyac.native.components.Composer { chars_left }
    core.jacyac.validation ++> core.jacyac.state { valid_post }
    core.jacyac.validation ++> core.site.jacyac.components.Composer {
        chars_left,
        post_limit,
        valid_post,
    }
    core.jacyac.validation ++> core.social_graph { valid_post }
    core.knowledge.repo ++> core.knowledge_service {
        DOCS_PATH,
        docs_source_url,
        RepoStatus,
        checkout_root,
        ensure_repo,
        read_status,
    }
    core.knowledge.repo ++> core.ninjaclaw.verify { knowledge_dir }
    core.knowledge_service ++> core.jacyac.claw {
        ninjaclaw_activity,
        ninjaclaw_job,
        ninjaclaw_tutorial,
        ninjaclaw_tutorials,
    }
    core.knowledge_service ++> core.social_graph {
        ninjaclaw_forget,
        ninjaclaw_results,
        ninjaclaw_retained,
        ninjaclaw_submit,
    }
    core.model.docs ++> cli { DocsStatus }
    core.model.docs ++> core.docs.graph {
        DocPageView,
        DocTree,
        DocsStatus,
        PageRef,
        TocEntry,
        TreeNode,
        VersionInfo,
    }
    core.model.docs ++> core.site.docs.DocsArticle { DocPageView }
    core.model.docs ++> core.site.docs.DocsGraphFloat { TreeNode }
    core.model.docs ++> core.site.docs.DocsShell { DocPageView, TreeNode, VersionInfo }
    core.model.docs ++> core.site.docs.DocsSidebar { TreeNode, VersionInfo }
    core.model.docs ++> core.site.docs.DocsTocRail { TocEntry }
    core.model.ninjaclaw ++> core.jacyac.claw { Activity, JobView, TutorialCard, TutorialView }
    core.model.ninjaclaw ++> core.jacyac.native.screens.ClawScreen { JobView }
    core.model.ninjaclaw ++> core.knowledge_service {
        Activity,
        AskInput,
        BlockView,
        JobReply,
        JobView,
        StepView,
        TutorialCard,
        TutorialView,
        UpkeepView,
    }
    core.model.ninjaclaw ++> core.ninjaclaw.graph {
        AskInput,
        BlockView,
        JobReply,
        JobView,
        LinkView,
        StepView,
        TutorialCard,
    }
    core.model.ninjaclaw ++> core.ninjaclaw.runner { BlockView, LinkView, StepView }
    core.model.ninjaclaw ++> core.ninjaclaw.upkeep { BlockView }
    core.model.ninjaclaw ++> core.ninjaclaw.verify { BlockView }
    core.model.ninjaclaw ++> core.site.jacyac.components.NinjaclawTab { JobView, StepView }
    core.model.ninjaclaw ++> core.site.jacyac.components.TutorialsTab { TutorialCard, TutorialView }
    core.model.ninjaclaw ++> core.social_graph { AskInput }
    core.model.packages ++> core.packages.catalog {
        ApiMember,
        ApiModule,
        ApiParam,
        ApiSymbol,
        PackageCatalog,
        PackageDetail,
        PackageSummary,
        PackageVersion,
        RepoReadme,
    }
    core.model.packages ++> core.site.packages.ApiDocs { ApiMember, ApiModule, ApiParam, ApiSymbol }
    core.model.packages ++> core.site.packages.PackagePage { PackageDetail, PackageVersion }
    core.model.packages ++> core.site.packages.PackagesIndex { PackageCatalog, PackageSummary }
    core.model.packages ++> core.site.packages.PackagesShell { PackageCatalog, PackageDetail }
    core.model.social ++> cli { Tweet }
    core.model.social ++> core.jacyac.limits { PostingDenied }
    core.model.social ++> core.jacyac.native.components.TweetCard { Tweet }
    core.model.social ++> core.jacyac.native.screens.ChannelsScreen { ChannelBundle, Tweet }
    core.model.social ++> core.jacyac.native.screens.ExploreScreen { Profile, TrendingTag }
    core.model.social ++> core.jacyac.native.screens.FeedScreen { Tweet }
    core.model.social ++> core.jacyac.native.screens.ProfileScreen { ProfileBundle }
    core.model.social ++> core.jacyac.state {
        ChannelBundle,
        Profile,
        ProfileBundle,
        TrendingTag,
        Tweet,
    }
    core.model.social ++> core.site.jacyac.components.ChannelsTab { ChannelBundle, Tweet }
    core.model.social ++> core.site.jacyac.components.ExploreTab { Profile }
    core.model.social ++> core.site.jacyac.components.FeedTab { Tweet }
    core.model.social ++> core.site.jacyac.components.ProfileEditor { Profile }
    core.model.social ++> core.site.jacyac.components.ProfileHeader { ProfileBundle }
    core.model.social ++> core.site.jacyac.components.RightSidebar { Profile, TrendingTag }
    core.model.social ++> core.site.jacyac.components.TweetCard { Tweet }
    core.model.social ++> core.social_graph {
        Avatar,
        AvatarCheck,
        AvatarResult,
        Channel,
        ChannelBundle,
        Commented,
        FieldCheck,
        Liked,
        Posted,
        Profile,
        ProfileBundle,
        ProfileResult,
        TrendingTag,
        Tweet,
    }
    core.model.source ++> core.site.source.CodeSpotlight { SourceSpan }
    core.model.source ++> core.site.source.SourceBrowser { SourceFile, SourceView }
    core.model.source ++> core.source.files { SourceFile, SourceSpan, SourceView }
    core.ninjaclaw.brain ++> core.ninjaclaw.runner {
        AskKind,
        CALL_MAX_S,
        Candidate,
        DEADLINE,
        classify_ask,
        pick_answer,
        repair_tutorial,
        write_tutorial,
    }
    core.ninjaclaw.graph ++> core.knowledge_service {
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
        tutorial_card,
    }
    core.ninjaclaw.index ++> core.knowledge_service { IndexDoc, docs_from_tree, index_doc }
    core.ninjaclaw.index ++> core.ninjaclaw.runner { IndexDoc, excerpt, search }
    core.ninjaclaw.index ++> core.ninjaclaw.tools {
        IndexDoc,
        docs_from_tree,
        excerpt,
        index_doc,
        search,
    }
    core.ninjaclaw.promote ++> core.knowledge_service {
        PrResult,
        eligible,
        github,
        open_docs_pr,
        pr_state,
        promote_config,
        promote_ready,
    }
    core.ninjaclaw.promote ++> core.ninjaclaw.graph { PrResult, PromoteCandidate }
    core.ninjaclaw.runner ++> core.knowledge_service { JobSpec, Outcome, RUNNER }
    core.ninjaclaw.runner ++> core.ninjaclaw.graph { JOB_LEASE_S, Outcome, WORKER_ID, stamp }
    core.ninjaclaw.tools ++> core.ninjaclaw.brain {
        list_jac_guides,
        read_jac_file,
        read_jac_guide,
        search_jac,
    }
    core.ninjaclaw.tools ++> core.ninjaclaw.runner { agent_catalog, open_toolbox }
    core.ninjaclaw.upkeep ++> core.knowledge_service { CHORE, sweep, sweep_items }
    core.ninjaclaw.upkeep ++> core.ninjaclaw.graph { sweep_passed }
    core.ninjaclaw.verify ++> core.ninjaclaw.runner { verify_markdown }
    core.ninjaclaw.verify ++> core.ninjaclaw.upkeep { verify_markdown }
    core.packages.catalog ++> core.site.packages.PackagesShell { package_catalog, package_detail }
    core.site.docs.DocsArticle ++> core.site.docs.DocsShell { DocsArticle, DocsArticleSkeleton }
    core.site.docs.DocsGraphFloat ++> core.site.docs.DocsSidebar { DocsGraphFloat }
    core.site.docs.DocsShell ++> pages.docs.index { DocsShell }
    core.site.docs.DocsSidebar ++> core.site.docs.DocsShell { DocsSidebar, section_key }
    core.site.docs.DocsTocRail ++> core.site.docs.DocsShell { DocsTocRail }
    core.site.docs.Markdown ++> core.site.docs.DocsArticle { Markdown }
    core.site.docs.Markdown ++> core.site.jacyac.components.TutorialsTab { MDSpans, Markdown }
    core.site.docs.Markdown ++> core.site.packages.PackagePage { Markdown }
    core.site.docs.MermaidDiagram ++> core.site.docs.Markdown { MermaidDiagram }
    core.site.game.arena ++> core.site.game.webgl_host {
        frame,
        get_deaths,
        get_hp,
        get_score,
        init,
        shutdown,
    }
    core.site.game.gmath ++> core.site.game.arena { clampf, jsin, lerp }
    core.site.game.gmath ++> core.site.game.sim {
        DEG2RAD,
        Rng,
        jcos,
        jsin,
        jsqrt,
        rand_range,
        rand_sign,
    }
    core.site.game.platform_rl ++> core.site.game.arena {
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
        unlock_mouse,
    }
    core.site.game.sim ++> core.site.game.arena {
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
        world_new,
    }
    type core.site.game.sim ++> core.site.game.webgl_host { Game }
    core.site.game.webgl ++> core.site.game.webgl_host {
        WebGLHost,
        _init_gl,
        _install_input,
        _m_ident,
        _remove_input,
    }
    core.site.game.webgl_host ++> core.site.landing.WasmGame { run_game }
    core.site.home.AgentNative ++> core.site.home.Home { AgentNative }
    core.site.home.Home ++> pages.index { Home }
    core.site.home.HomeClose ++> core.site.home.Home { HomeClose }
    core.site.home.HomeHero ++> core.site.home.Home { HomeHero }
    core.site.home.InProduction ++> core.site.home.Home { InProduction }
    core.site.home.NativeBench ++> core.site.home.Home { NativeBench }
    core.site.home.NoGlue ++> core.site.home.Home { NoGlue }
    core.site.home.OneLanguage ++> core.site.home.Home { OneLanguage }
    core.site.home.ReadableTiers ++> core.site.home.Home { ReadableTiers }
    core.site.home.kit ++> core.site.home.AgentNative {
        CodeWindow,
        Figure,
        HomeSection,
        Prose,
        SectionHead,
    }
    core.site.home.kit ++> core.site.home.HomeClose { HomeSection, Prose }
    core.site.home.kit ++> core.site.home.InProduction { Fact, Figure, HomeSection, SectionHead }
    core.site.home.kit ++> core.site.home.NativeBench { Fact, Figure, HomeSection, SectionHead }
    core.site.home.kit ++> core.site.home.NoGlue {
        CodeWindow,
        Fact,
        Figure,
        HomeSection,
        Prose,
        SectionHead,
    }
    core.site.home.kit ++> core.site.home.OneLanguage { Fact, Figure, HomeSection, SectionHead }
    core.site.home.kit ++> core.site.home.ReadableTiers {
        CodeWindow,
        Fact,
        Figure,
        HomeSection,
        Prose,
        SectionHead,
    }
    core.site.jacyac.JacYac ++> pages.jacyac { JacYac }
    core.site.jacyac.JacYac ++> pages.jacyac.ninjaclaw { JacYac }
    core.site.jacyac.JacYac ++> pages.jacyac.tutorials { JacYac }
    core.site.jacyac.JacYac ++> pages.socialize { JacYac }
    core.site.jacyac.components.AuthForm ++> core.site.jacyac.JacYac { AuthForm }
    core.site.jacyac.components.ChannelsTab ++> core.site.jacyac.JacYac { ChannelsTab }
    core.site.jacyac.components.Composer ++> core.site.jacyac.components.ChannelsTab { Composer }
    core.site.jacyac.components.Composer ++> core.site.jacyac.components.FeedTab { Composer }
    core.site.jacyac.components.ExploreTab ++> core.site.jacyac.JacYac { ExploreTab }
    core.site.jacyac.components.FeedTab ++> core.site.jacyac.JacYac { FeedTab }
    core.site.jacyac.components.MobileNav ++> core.site.jacyac.JacYac { MobileNav }
    core.site.jacyac.components.NinjaclawTab ++> core.site.jacyac.JacYac { NinjaclawTab }
    core.site.jacyac.components.ProfileEditor ++> core.site.jacyac.JacYac { ProfileEditor }
    core.site.jacyac.components.ProfileHeader ++> core.site.jacyac.JacYac { ProfileHeader }
    core.site.jacyac.components.RichText ++> core.site.jacyac.components.NinjaclawTab { RichText }
    core.site.jacyac.components.RichText ++> core.site.jacyac.components.TweetCard { RichText }
    core.site.jacyac.components.RightSidebar ++> core.site.jacyac.JacYac { RightSidebar }
    core.site.jacyac.components.Sidebar ++> core.site.jacyac.JacYac { Sidebar }
    core.site.jacyac.components.TutorialsTab ++> core.site.jacyac.JacYac { TutorialsTab }
    core.site.jacyac.components.TweetCard ++> core.site.jacyac.JacYac { TweetCard }
    core.site.jacyac.components.TweetCard ++> core.site.jacyac.components.ChannelsTab { TweetCard }
    core.site.jacyac.components.TweetCard ++> core.site.jacyac.components.FeedTab { TweetCard }
    core.site.jacyac.components.WelcomeBanner ++> core.site.jacyac.components.FeedTab {
        WelcomeBanner,
    }
    core.site.landing.Agents ++> core.site.landing.TechDemo { Agents }
    core.site.landing.BookSection ++> core.site.landing.TechDemo { BookSection }
    core.site.landing.CopyCommand ++> core.site.home.HomeClose { CopyCommand }
    core.site.landing.CopyCommand ++> core.site.home.HomeHero { CopyCommand }
    core.site.landing.CopyCommand ++> core.site.landing.Agents { CopyCommand }
    core.site.landing.CopyCommand ++> core.site.landing.ExplorerFinale { CopyCommandBlock }
    core.site.landing.CopyCommand ++> core.site.packages.PackagePage { CopyCommand }
    core.site.landing.CopyCommand ++> core.site.packages.PackagesIndex { CopyCommand }
    core.site.landing.ExplorerFinale ++> core.site.landing.TechDemo { ExplorerFinale }
    core.site.landing.MobileShowcase ++> core.site.landing.TechDemo { MobileShowcase }
    core.site.landing.UiLibraries ++> core.site.landing.TechDemo { UiLibraries }
    core.demo.Playground ++> core.site.landing.UiLibraries { Playground }
    core.demo.Playground ++> demos.preact { Playground }
    core.demo.Playground ++> demos.solid { Playground }
    core.demo.api ++> core.demo.Playground { demo_hello }
    core.demo.kit ++> core.demo.Playground { Btn, Card, Label, Line, Title }
    core.site.landing.Reveal ++> core.site.home.AgentNative { Reveal }
    core.site.landing.Reveal ++> core.site.home.HomeClose { Reveal }
    core.site.landing.Reveal ++> core.site.home.InProduction { Reveal }
    core.site.landing.Reveal ++> core.site.home.NativeBench { Reveal }
    core.site.landing.Reveal ++> core.site.home.NoGlue { Reveal }
    core.site.landing.Reveal ++> core.site.home.OneLanguage { Reveal }
    core.site.landing.Reveal ++> core.site.home.ReadableTiers { Reveal }
    core.site.landing.Reveal ++> core.site.home.kit { Reveal }
    core.site.landing.Reveal ++> core.site.landing.Agents { Reveal }
    core.site.landing.Reveal ++> core.site.landing.BookSection { Reveal }
    core.site.landing.Reveal ++> core.site.landing.ExplorerFinale { Reveal }
    core.site.landing.Reveal ++> core.site.landing.MobileShowcase { Reveal }
    core.site.landing.Reveal ++> core.site.landing.WaitWuuut { Reveal }
    core.site.landing.Reveal ++> core.site.landing.WasmGame { Reveal }
    core.site.landing.WasmGame ++> core.site.landing.TechDemo { WasmGame }
    core.site.packages.ApiDocs ++> core.site.packages.PackagePage { ApiDocs }
    core.site.packages.PackagePage ++> core.site.packages.PackagesShell { PackagePage }
    core.site.packages.PackagesIndex ++> core.site.packages.PackagesShell { PackagesIndex }
    core.site.packages.PackagesShell ++> pages.packages.index { PackagesShell }
    core.site.source.CodeSpotlight ++> core.site.landing.MobileShowcase { CodeSpotlight }
    core.site.source.CodeSpotlight ++> core.site.landing.WaitWuuut { CodeSpotlight }
    core.site.source.FloatingSource ++> core.site.landing.WaitWuuut { FloatingSource }
    core.site.source.SourceBrowser ++> core.site.landing.ExplorerFinale { SourceBrowser }
    core.site.source.SourceBrowser ++> core.site.source.FloatingSource { SourceBrowser }
    core.site.ui.CodeBlock ++> core.site.docs.Markdown { CodeLines }
    core.site.ui.CodeBlock ++> core.site.docs.MermaidDiagram { CodeLines }
    core.site.ui.CodeBlock ++> core.site.home.kit { CodeLines }
    core.site.ui.CodeBlock ++> core.site.source.CodeSpotlight { CodeLines }
    core.site.ui.CodeBlock ++> core.site.source.SourceBrowser { CodeLines }
    core.site.ui.Footer ++> core.site.ui.SiteShell { Footer }
    core.site.ui.GraphBackdrop ++> core.site.docs.DocsShell { GraphBackdrop }
    core.site.ui.GraphBackdrop ++> core.site.ui.NotFound { GraphBackdrop }
    core.site.ui.Navbar ++> core.site.ui.SiteShell { Navbar }
    core.site.ui.SectionRail ++> core.site.home.Home { SectionRail }
    core.site.ui.SectionRail ++> core.site.landing.TechDemo { SectionRail }
    core.site.ui.SectionRail ++> core.site.landing.WaitWuuut { SectionRail }
    core.site.ui.SiteShell ++> pages.layout { SiteShell }
    core.site.ui.alert_dialog ++> core.site.jacyac.components.TweetCard {
        AlertDialog,
        AlertDialogAction,
        AlertDialogCancel,
        AlertDialogContent,
        AlertDialogDescription,
        AlertDialogFooter,
        AlertDialogHeader,
        AlertDialogTitle,
        AlertDialogTrigger,
    }
    core.site.ui.avatar ++> core.site.jacyac.components.Composer {
        Avatar,
        AvatarFallback,
        AvatarImage,
    }
    core.site.ui.avatar ++> core.site.jacyac.components.ExploreTab {
        Avatar,
        AvatarFallback,
        AvatarImage,
    }
    core.site.ui.avatar ++> core.site.jacyac.components.ProfileHeader {
        Avatar,
        AvatarFallback,
        AvatarImage,
    }
    core.site.ui.avatar ++> core.site.jacyac.components.RightSidebar {
        Avatar,
        AvatarFallback,
        AvatarImage,
    }
    core.site.ui.avatar ++> core.site.jacyac.components.Sidebar {
        Avatar,
        AvatarFallback,
        AvatarImage,
    }
    core.site.ui.avatar ++> core.site.jacyac.components.TweetCard {
        Avatar,
        AvatarFallback,
        AvatarImage,
    }
    core.site.ui.badge ++> core.site.jacyac.components.ChannelsTab { Badge }
    core.site.ui.badge ++> core.site.jacyac.components.NinjaclawTab { Badge }
    core.site.ui.badge ++> core.site.jacyac.components.RightSidebar { Badge }
    core.site.ui.badge ++> core.site.jacyac.components.Sidebar { Badge }
    core.site.ui.badge ++> core.site.jacyac.components.TutorialsTab { Badge }
    core.site.ui.badge ++> core.site.landing.Agents { Badge }
    core.site.ui.badge ++> core.site.landing.BookSection { Badge }
    core.site.ui.badge ++> core.site.landing.ExplorerFinale { Badge }
    core.site.ui.badge ++> core.site.landing.MobileShowcase { Badge }
    core.site.ui.badge ++> core.site.landing.WaitWuuut { Badge }
    core.site.ui.badge ++> core.site.landing.WasmGame { Badge }
    core.site.ui.badge ++> core.site.packages.PackagePage { Badge }
    core.site.ui.badge ++> core.site.packages.PackagesIndex { Badge }
    core.site.ui.button ++> core.site.jacyac.JacYac { Button }
    core.site.ui.button ++> core.site.jacyac.components.AuthForm { Button }
    core.site.ui.button ++> core.site.jacyac.components.ChannelsTab { Button }
    core.site.ui.button ++> core.site.jacyac.components.Composer { Button }
    core.site.ui.button ++> core.site.jacyac.components.ExploreTab { Button }
    core.site.ui.button ++> core.site.jacyac.components.ProfileEditor { Button }
    core.site.ui.button ++> core.site.jacyac.components.ProfileHeader { Button }
    core.site.ui.button ++> core.site.jacyac.components.RightSidebar { Button }
    core.site.ui.button ++> core.site.jacyac.components.Sidebar { Button }
    core.site.ui.button ++> core.site.jacyac.components.TweetCard { Button }
    core.site.ui.button ++> core.site.jacyac.components.WelcomeBanner { Button }
    core.site.ui.button ++> core.site.landing.BookSection { buttonVariants }
    core.site.ui.button ++> core.site.landing.ExplorerFinale { buttonVariants }
    core.site.ui.button ++> core.site.landing.WasmGame { Button }
    core.site.ui.button ++> core.site.ui.Navbar { buttonVariants }
    core.site.ui.button ++> core.site.ui.NotFound { buttonVariants }
    core.site.ui.button ++> core.site.ui.alert_dialog { Button }
    core.site.ui.button ++> core.site.ui.carousel { Button }
    core.site.ui.button ++> core.site.ui.dialog { buttonVariants }
    core.site.ui.card ++> core.site.jacyac.components.AuthForm {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    }
    core.site.ui.card ++> core.site.jacyac.components.RightSidebar {
        Card,
        CardContent,
        CardHeader,
        CardTitle,
    }
    core.site.ui.dialog ++> core.site.jacyac.components.ChannelsTab {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogFooter,
        DialogHeader,
        DialogTitle,
    }
    core.site.ui.dropdown_menu ++> core.site.jacyac.components.Sidebar {
        DropdownMenu,
        DropdownMenuContent,
        DropdownMenuGroup,
        DropdownMenuItem,
        DropdownMenuTrigger,
    }
    core.site.ui.dropdown_menu ++> core.site.ui.Navbar {
        DropdownMenu,
        DropdownMenuContent,
        DropdownMenuItem,
        DropdownMenuTrigger,
    }
    core.site.ui.empty ++> core.site.jacyac.components.ChannelsTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle,
    }
    core.site.ui.empty ++> core.site.jacyac.components.ExploreTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle,
    }
    core.site.ui.empty ++> core.site.jacyac.components.FeedTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle,
    }
    core.site.ui.empty ++> core.site.jacyac.components.TutorialsTab {
        Empty,
        EmptyDescription,
        EmptyHeader,
        EmptyMedia,
        EmptyTitle,
    }
    core.site.ui.field ++> core.site.jacyac.components.ChannelsTab { Field, FieldLabel }
    core.site.ui.field ++> core.site.jacyac.components.ProfileEditor { Field, FieldLabel }
    core.site.ui.hover_card ++> core.site.jacyac.components.RightSidebar {
        HoverCard,
        HoverCardContent,
        HoverCardTrigger,
    }
    core.site.ui.input ++> core.site.docs.DocsSidebar { Input }
    core.site.ui.input ++> core.site.jacyac.components.ChannelsTab { Input }
    core.site.ui.input ++> core.site.jacyac.components.ProfileEditor { Input }
    core.site.ui.input ++> core.site.jacyac.components.RightSidebar { Input }
    core.site.ui.input ++> core.site.jacyac.components.TweetCard { Input }
    core.site.ui.input ++> core.site.packages.PackagesIndex { Input }
    core.site.ui.label ++> core.site.ui.field { Label }
    core.site.ui.select ++> core.site.docs.DocsSidebar {
        Select,
        SelectContent,
        SelectGroup,
        SelectItem,
        SelectTrigger,
        SelectValue,
    }
    core.site.ui.separator ++> core.site.ui.field { Separator }
    core.site.ui.skeleton ++> core.site.docs.DocsArticle { Skeleton }
    core.site.ui.skeleton ++> core.site.docs.DocsSidebar { Skeleton }
    core.site.ui.skeleton ++> core.site.jacyac.components.ChannelsTab { Skeleton }
    core.site.ui.skeleton ++> core.site.jacyac.components.ExploreTab { Skeleton }
    core.site.ui.skeleton ++> core.site.jacyac.components.FeedTab { Skeleton }
    core.site.ui.tabs ++> core.site.docs.Markdown { Tabs, TabsContent, TabsList, TabsTrigger }
    core.site.ui.textarea ++> core.site.jacyac.components.ChannelsTab { Textarea }
    core.site.ui.textarea ++> core.site.jacyac.components.Composer { Textarea }
    core.site.ui.textarea ++> core.site.jacyac.components.ProfileEditor { Textarea }
    core.site.ui.tooltip ++> core.site.jacyac.components.TweetCard {
        Tooltip,
        TooltipContent,
        TooltipProvider,
        TooltipTrigger,
    }
    core.social_graph ++> cli { create_tweet, load_feed }
    core.social_graph ++> core.jacyac.state {
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
        update_profile,
    }
    core.source.files ++> core.site.source.CodeSpotlight { source_span }
    core.source.files ++> core.site.source.SourceBrowser { source_file, source_tree }
    core.timefmt ++> core.docs.sync { now_iso }
    core.timefmt ++> core.install { now_iso, seconds_since }
    core.timefmt ++> core.progress { now_iso }
    core.timefmt ++> core.social_graph { now_iso }
    core.utils ++> core.site.docs.DocsSidebar { cn }
    core.utils ++> core.site.docs.DocsTocRail { cn }
    core.utils ++> core.site.home.NoGlue { cn }
    core.utils ++> core.site.home.OneLanguage { cn }
    core.utils ++> core.site.home.kit { cn }
    core.utils ++> core.site.jacyac.components.MobileNav { cn }
    core.utils ++> core.site.jacyac.components.Sidebar { cn }
    core.utils ++> core.site.jacyac.components.TweetCard { cn }
    core.utils ++> core.site.landing.CopyCommand { cn }
    core.utils ++> core.site.landing.Reveal { cn }
    core.utils ++> core.site.source.FloatingSource { cn }
    core.utils ++> core.site.ui.CodeBlock { cn }
    core.utils ++> core.site.ui.Navbar { cn }
    core.utils ++> core.site.ui.accordion { cn }
    core.utils ++> core.site.ui.alert_dialog { cn }
    core.utils ++> core.site.ui.avatar { cn }
    core.utils ++> core.site.ui.badge { cn }
    core.utils ++> core.site.ui.button { cn }
    core.utils ++> core.site.ui.card { cn }
    core.utils ++> core.site.ui.carousel { cn }
    core.utils ++> core.site.ui.dialog { cn }
    core.utils ++> core.site.ui.dropdown_menu { cn }
    core.utils ++> core.site.ui.empty { cn }
    core.utils ++> core.site.ui.field { cn }
    core.utils ++> core.site.ui.hover_card { cn }
    core.utils ++> core.site.ui.input { cn }
    core.utils ++> core.site.ui.label { cn }
    core.utils ++> core.site.ui.select { cn }
    core.utils ++> core.site.ui.separator { cn }
    core.utils ++> core.site.ui.skeleton { cn }
    core.utils ++> core.site.ui.tabs { cn }
    core.utils ++> core.site.ui.textarea { cn }
    core.utils ++> core.site.ui.tooltip { cn }
}

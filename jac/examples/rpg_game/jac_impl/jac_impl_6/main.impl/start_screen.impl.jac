impl start_screen.intro_screen{
    # print("Walker Entry -> Intro Screen");
    if self.game_started == False {
        self.game_started = True;
        visitor.g.intro_screen();
        new_ID = str(1) + "_" + str(random.randint(1000, 9000));
        self +>: play : level_id=new_ID :+> level(game_level=1, level_id=new_ID);
        visitor.fwd_dir = True;
        visit [->:play:level_id==new_ID:->];
    } else {
        new_ID = str(1) + "_" + str(random.randint(1000, 9000));
        self +>: play : level_id=new_ID :+> level(game_level=1, level_id=new_ID);
        print(":-: Visiting Intro Screen | Created Level ID :", new_ID);
        visitor.fwd_dir = True;
        visit [->:play:level_id==new_ID:->];
    }
}

impl start_screen.exit_game{
    if visitor.g.running == False {
        pygame.quit();
        sys.exit();
        disengage;
    }
}

import sys;

impl level.run_game {
    # print("Walker Entry ->", self.level_id);

    if self.played == False {
        if visitor.current_level != self.game_level {
            visitor.current_level = self.game_level;
        }
        if visitor.manager.current_level != self.game_level {
            if self.game_level != 1 {
                visitor.manager.current_level = self.game_level;
                next_level = visitor.manager.get_next_level(self.game_level);
                self.level_config.map = next_level;
            }
        } else {
            self.level_config.map = [[<--][0] -->](`?level)(?level_id==visitor.last_level_id)[0].level_config.map;
        }
        visitor.g.GameMap.map = self.level_config.map;
        visitor.g.new();
        print(":-: Playing Level :", self.game_level, "| Level ID :",  self.level_id, "| Played :", str(self.played));
        start_time = time.time();
        visitor.g.main();
        end_time = time.time();
        visitor.last_level_id = self.level_id;
        if visitor.g.won == True{
            self.level_time = end_time - start_time;
            if visitor.manager.prev_levels {
                visitor.manager.prev_levels[-1].time = self.level_time;
            }
            visitor.g.game_won();
            self.played = True;
            visitor.g.won = False;
            visitor.fwd_dir =True;
            new_ID = str(self.game_level+1) + "_" + str(random.randint(1000, 9000));
            self +>:play:level_id=new_ID:+> level(game_level = self.game_level+1, level_id = new_ID);
            visit [->:play:level_id==new_ID:->];
        } else {
            visitor.g.game_over();
            # visitor.map_directory[str(self.game_level)].nos_retry += 1;
            self.played = True;
            visitor.g.won = False;
            visitor.fwd_dir = False;
            visit [<-:play:<-];
        }
    } elif visitor.fwd_dir == False{
        new_ID = str(self.game_level+1) + "_" + str(random.randint(1000, 9000));
        print(":-: Visiting Level :", self.game_level, "| Level ID :",  self.level_id, "| Played :", str(self.played), '| Created Level ID :', new_ID);
        visitor.fwd_dir = True;
        self +>:play:level_id=new_ID:+> level(game_level = self.game_level+1, level_id = new_ID);
        visit [->:play:level_id==new_ID:->];
    } else {
        print(":-: Visiting Level :", self.game_level, "| Level ID :",  self.level_id, "| Played :", str(self.played));
        visit [<--];
    }
}

impl level.exit_game {
    if visitor.g.running == False {
        pygame.quit();
        sys.exit();
        disengage;
    }
}
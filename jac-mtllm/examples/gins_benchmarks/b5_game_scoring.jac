"""\nGame scoring system with compound bonus interactions.\nThe assert failure occurs when multiple bonuses stack beyond reasonable bounds.\n"""

import time;
import random;


class Player {
    def init(self: Player, name: Any, level: Any = 1) {
        self.name = name;
        self.level = level;
        self.base_score = 0;
        self.multiplier_stack = [];
        self.active_bonuses = {};
        self.game_state = 'active';
    }

    """Add a score multiplier from various sources."""
    def add_multiplier(self: Player, multiplier: Any, source: Any) {
        self.multiplier_stack.append(
            {'value' : multiplier , 'source' : source , 'timestamp' : time.time() }
        );
    }

    """Calculate effective multiplier from all sources."""
    def get_effective_multiplier(self: Player) {
        if not self.multiplier_stack {
            return 1.0;
        }
        total = 1.0;
        for mult in self.multiplier_stack {
            total *= mult['value'];
        }
        level_bonus = (1.0 + ((self.level - 1) * 0.1));
        return (total * level_bonus);
    }

    """Add temporary bonus."""
    def add_bonus(self: Player, bonus_type: Any, value: Any) {
        self.active_bonuses[bonus_type] = value;
    }
}


class GameEngine {
    def init(self: GameEngine) {
        self.players = {};
        self.round_number = 1;
        self.difficulty_modifier = 1.0;
        self.special_event_active = False;
        self.last_score_time = 0;
    }

    """Add a player to the game."""
    def add_player(self: GameEngine, player_name: Any, level: Any = 1) {
        self.players[player_name] = Player(player_name, level);
    }

    """Start special event with score bonuses."""
    def start_special_event(self: GameEngine) {
        self.special_event_active = True;
        for player in self.players.values() {
            player.add_multiplier(2.0, 'special_event');
        }
        self.difficulty_modifier = 1.5;
    }

    """Calculate bonus based on round number."""
    def calculate_round_bonus(self: GameEngine) {
        if (self.round_number <= 5) {
            return (1.0 + (self.round_number * 0.2));
        } else {
            return (2.0 + ((self.round_number - 5) * 0.1));
        }
    }

    """Award points to player with all modifiers applied."""
    def award_score(self: GameEngine, player_name: Any, base_points: Any) {
        if (player_name not in self.players) {
            raise ValueError(f"'Player '{player_name}' not found'") ;
        }
        player = self.players[player_name];
        player_multiplier = player.get_effective_multiplier();
        round_bonus = self.calculate_round_bonus();
        difficulty_bonus = (1.0 + ((self.difficulty_modifier - 1.0) * 0.5));
        combo_bonus = player.active_bonuses.get('combo', 1.0);
        streak_bonus = player.active_bonuses.get('streak', 1.0);
        final_score = (((((base_points * player_multiplier) * round_bonus) * difficulty_bonus) * combo_bonus) * streak_bonus);
        player.base_score += final_score;
        self.last_score_time = time.time();
        max_reasonable_score = (base_points * 10);
        assert (final_score <= max_reasonable_score) , f"Score multiplier exceeded reasonable bounds" ;
        return final_score;
    }

    """Advance to next round."""
    def advance_round(self: GameEngine) {
        self.round_number += 1;
        if ((random.random() < 0.3) and not self.special_event_active ) {
            self.start_special_event();
        }
    }
}


"""Simulate a game that will trigger the compound bonus assert failure."""
def simulate_game() {
    random.seed(42);
    game = GameEngine();
    game.add_player('Alice', level=5);
    alice = game.players['Alice'];
    print('=== Game Scoring System Example ===');
    print(f"Alice's level: {alice.level}");
    for round_num in range(1, 8) {
        print(f"--- Round {round_num} ---");
        if (round_num > 1) {
            game.advance_round();
        }
        if (round_num == 3) {
            alice.add_bonus('combo', 1.5);
            print('Combo bonus activated!');
        }
        if (round_num == 5) {
            alice.add_bonus('streak', 1.8);
            print('Streak bonus activated!');
        }
        if (round_num == 6) {
            alice.add_multiplier(1.3, 'power_up');
            print('Power-up multiplier added!');
        }
        if (round_num == 7) {
            game.start_special_event();
            print('Special event started!');
        }
        base_points = 100;
        final_score = game.award_score('Alice', base_points);
        print(f"Alice scored: {final_score} points");
        print(f"Alice's total: {alice.base_score}");
        print(f"Current multiplier: {(final_score / base_points)}x");
    }
    return True;
}


with entry {
    if (__name__ == '__main__') {
        success = simulate_game();
        if success {
            print('All rounds completed successfully!');
        }
    }
}

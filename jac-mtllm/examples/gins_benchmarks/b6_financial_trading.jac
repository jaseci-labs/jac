"""\nComplex financial trading system with multiple interacting components.\nThe assert failure occurs due to compound effects across configuration,\nmarket data, portfolio state, and risk calculations.\n"""

import os;
import random;
import time;
import from datetime { datetime, timedelta }


class Config {
    def init(self: Config) {
        self.environment = os.getenv('TRADING_ENV', 'development');
        self.risk_tolerance = self._get_risk_tolerance();
        self.max_position_size = self._get_max_position_size();
        self.trading_hours = self._get_trading_hours();
    }
    def _get_risk_tolerance(self: Config) {
        base_risk = 0.02 if (self.environment == 'production') else 0.05 ;
        current_day = datetime.now().weekday();
        if (current_day >= 5) {
            return (base_risk * 0.5);
        }
        return base_risk;
    }
    def _get_max_position_size(self: Config) {
        if (self.environment == 'production') {
            return (1000000 * self.risk_tolerance);
        }
        return (100000 * self.risk_tolerance);
    }
    def _get_trading_hours(self: Config) {
        if (self.environment == 'production') {
            return {'start' : 9 , 'end' : 16 };
        }
        return {'start' : 0 , 'end' : 23 };
    }
}


class MarketDataProvider {
    def init(self: MarketDataProvider, config: Any) {
        self.config = config;
        self.cache = {};
        self.cache_ttl = 300;
        self.volatility_multiplier = self._calculate_volatility_multiplier();
    }
    def _calculate_volatility_multiplier(self: MarketDataProvider) {
        hour = datetime.now().hour;
        if (hour in [9, 10, 15, 16]) {
            return 1.5;
        }
        if (12 <= hour <= 14) {
            return 0.7;
        }
        return 1.0;
    }
    """Get current price with caching."""
    def get_price(self: MarketDataProvider, symbol: Any) {
        cache_key = f"{symbol}'_'{int((time.time() // self.cache_ttl))}";
        if (cache_key in self.cache) {
            return self.cache[cache_key];
        }
        base_price = self._get_base_price(symbol);
        volatility = (0.01 * self.volatility_multiplier);
        noise = random.gauss(0, volatility);
        price = (base_price * (1 + noise));
        self.cache[cache_key] = price;
        return price;
    }

    """Get base price for symbol."""
    def _get_base_price(self: MarketDataProvider, symbol: Any) {
        base_prices =
        {'AAPL' : 150.0 , 'GOOGL' : 2500.0 , 'TSLA' : 800.0 , 'MSFT' : 300.0 };
        return base_prices.get(symbol, 100.0);
    }

    """Calculate historical volatility."""
    def get_historical_volatility(self: MarketDataProvider, symbol: Any, days: Any = 30) {
        prices = [];
        base_price = self._get_base_price(symbol);
        for i in range(days) {
            trend = (0.001 * (i - (days / 2)));
            noise = random.gauss(0, 0.02);
            price = (base_price * ((1 + trend) + noise));
            prices.append(price);
        }
        returns = [ ((prices[i] / prices[(i - 1)]) - 1) for i in range(1, len(prices)) ];
        if not returns {
            return 0.02;
        }
        mean_return = (sum(returns) / len(returns));
        variance = (sum(( ((r - mean_return) ** 2) for r in returns )) / len(returns));
        return (variance ** 0.5);
    }
}


class Position {
    def init(
        self: Position,
        symbol: Any,
        quantity: Any,
        entry_price: Any,
        timestamp: Any = None
    ) {
        self.symbol = symbol;
        self.quantity = quantity;
        self.entry_price = entry_price;
        self.timestamp = (timestamp or datetime.now() );
        self.unrealized_pnl = 0.0;
    }

    """Update unrealized P&L."""
    def update_pnl(self: Position, current_price: Any) {
        self.unrealized_pnl = ((current_price - self.entry_price) * self.quantity);
    }

    """Get current market value."""
    def get_market_value(self: Position, current_price: Any) {
        return (current_price * <>abs(self.quantity));
    }
}


class Portfolio {
    def init(self: Portfolio, config: Any, market_data: Any) {
        self.config = config;
        self.market_data = market_data;
        self.positions = {};
        self.cash = 1000000;
        self.transaction_history = [];
    }
    """Add or update a position."""
    def add_position(self: Portfolio, symbol: Any, quantity: Any, price: Any) {
        if (symbol in self.positions) {
            existing = self.positions[symbol];
            total_quantity = (existing.quantity + quantity);
            if (total_quantity != 0) {
                avg_price = (((existing.entry_price * existing.quantity) + (price * quantity)) / total_quantity);
                self.positions[symbol] = Position(symbol, total_quantity, avg_price);
            } else {
                del (self.positions[symbol], ) ;
            }
        } else {
            self.positions[symbol] = Position(symbol, quantity, price);
        }
        self.cash -= (quantity * price);
        self.transaction_history.append(

            {'symbol' : symbol , 'quantity' : quantity , 'price' : price , 'timestamp' : datetime.now() , 'type' : 'BUY' if (quantity > 0) else 'SELL'  }
        );
    }

    """Calculate total portfolio exposure."""
    def get_total_exposure(self: Portfolio) {
        total_exposure = 0;
        for (symbol, position) in self.positions.items() {
            current_price = self.market_data.get_price(symbol);
            market_value = position.get_market_value(current_price);
            total_exposure += market_value;
        }
        return total_exposure;
    }

    """Calculate total portfolio value."""
    def get_portfolio_value(self: Portfolio) {
        portfolio_value = self.cash;
        for (symbol, position) in self.positions.items() {
            current_price = self.market_data.get_price(symbol);
            position.update_pnl(current_price);
            portfolio_value += (position.quantity * current_price);
        }
        return portfolio_value;
    }
}


class TradingEngine {
    def init(self: TradingEngine) {
        self.config = Config();
        self.market_data = MarketDataProvider(self.config);
        self.portfolio = Portfolio(self.config, self.market_data);
    }
    """Execute a trade with full risk management."""
    def execute_trade(
        self: TradingEngine,
        symbol: Any,
        quantity: Any,
        price: Any = None
    ) {
        if (price is None) {
            price = self.market_data.get_price(symbol);
        }
        self.portfolio.add_position(symbol, quantity, price);
        self._post_trade_validation(symbol, quantity, price);
        return True;
    }

    """Critical post-trade validation - this is where the complex assert will fail."""
    def _post_trade_validation(
        self: TradingEngine,
        symbol: Any,
        quantity: Any,
        price: Any
    ) {
        portfolio_value = self.portfolio.get_portfolio_value();
        total_exposure = self.portfolio.get_total_exposure();
        effective_leverage = (total_exposure / portfolio_value)
        if (portfolio_value > 0)
        else 0
        ;
        base_leverage_limit = (1.0 / self.config.risk_tolerance);
        avg_volatility = self._calculate_average_portfolio_volatility();
        volatility_adjustment = (1.0 - ((avg_volatility - 0.02) * 10));
        volatility_adjustment = max(0.1, min(2.0, volatility_adjustment));
        time_adjustment = self._get_time_of_day_adjustment();
        concentration_penalty = self._calculate_concentration_penalty();
        adjusted_leverage_limit = (((base_leverage_limit * volatility_adjustment) * time_adjustment) * concentration_penalty);
        assert (effective_leverage <= adjusted_leverage_limit) , f"Leverage limit exceeded:" ;
    }

    """Calculate weighted average volatility of portfolio."""
    def _calculate_average_portfolio_volatility(self: TradingEngine) {
        if not self.portfolio.positions {
            return 0.02;
        }
        total_weight = 0;
        weighted_vol = 0;
        for (symbol, position) in self.portfolio.positions.items() {
            weight = <>abs((position.quantity * self.market_data.get_price(symbol)));
            vol = self.market_data.get_historical_volatility(symbol);
            weighted_vol += (weight * vol);
            total_weight += weight;
        }
        return (weighted_vol / total_weight) if (total_weight > 0) else 0.02 ;
    }

    """Get time-of-day adjustment factor."""
    def _get_time_of_day_adjustment(self: TradingEngine) {
        hour = datetime.now().hour;
        if (12 <= hour <= 14) {
            return 1.2;
        }
        if (hour in [9, 10, 15, 16]) {
            return 0.8;
        }
        return 1.0;
    }

    """Calculate penalty for portfolio concentration."""
    def _calculate_concentration_penalty(self: TradingEngine) {
        if not self.portfolio.positions {
            return 1.0;
        }
        portfolio_value = self.portfolio.get_portfolio_value();
        max_position_weight = 0;
        for (symbol, position) in self.portfolio.positions.items() {
            price = self.market_data.get_price(symbol);
            position_value = <>abs((position.quantity * price));
            weight = (position_value / portfolio_value) if (portfolio_value > 0) else 0 ;
            max_position_weight = max(max_position_weight, weight);
        }
        if (max_position_weight > 0.15) {
            penalty = (1.0 - ((max_position_weight - 0.15) * 2));
            return max(0.5, penalty);
        }
        return 1.0;
    }
}


"""Simulate trading that will trigger the complex assert failure."""
def simulate_trading() {
    os.environ['TRADING_ENV'] = 'production';
    random.seed(42);
    engine = TradingEngine();
    print('=== Financial Trading System Example ===');
    print(f"'Environment: '{engine.config.environment}");
    print(f"'Risk tolerance: '{engine.config.risk_tolerance}");
    print(f"'Current hour: '{datetime.now().hour}");
    print(f"'Is weekend: '{(datetime.now().weekday() >= 5)}");
    print(f"'Market volatility multiplier: '{engine.market_data.volatility_multiplier}");
    print();
    trades = [('AAPL', 20000),
    ('GOOGL', 12000),
    ('TSLA', 18000),
    ('AAPL', 15000),
    ('MSFT', 25000)];
    for (i, (symbol, quantity)) in enumerate(trades, 1) {
        print(f"'Trade '{i}': '{quantity}' shares of '{symbol}");
        # try {
        engine.execute_trade(symbol, quantity);
        pv = engine.portfolio.get_portfolio_value();
        te = engine.portfolio.get_total_exposure();
        print(f"'  Portfolio value: $'{pv}");
        print(f"'  Total exposure: $'{te}");
        print(f"'  Current leverage: '{(te / pv)}");
        print();
        # } except AssertionError as e {
        #     print(f"'\nASSERT FAILED: '{e}");
        #     print(f"'\nRuntime state:'");
        #     pv = engine.portfolio.get_portfolio_value();
        #     te = engine.portfolio.get_total_exposure();
        #     print(f"'  Portfolio value: $'{pv}");
        #     print(f"'  Total exposure: $'{te}");
        #     print(f"'  Effective leverage: '{(te / pv)}");
        #     print(f"'  Environment: '{engine.config.environment}");
        #     print(f"'  Risk tolerance: '{engine.config.risk_tolerance}");
        #     print(f"'  Weekend adjustment active: '{(datetime.now().weekday() >= 5)}");
        #     print(f"'  Current hour: '{datetime.now().hour}");
        #     print(
        #         f"'  Market volatility multiplier: '{engine.market_data.volatility_multiplier}"
        #     );
        #     base_limit = (1.0 / engine.config.risk_tolerance);
        #     vol_adj = engine._calculate_average_portfolio_volatility();
        #     time_adj = engine._get_time_of_day_adjustment();
        #     conc_penalty = engine._calculate_concentration_penalty();
        #     print(f"'  Base leverage limit: '{base_limit}");
        #     print(
        #         f"'  Volatility adjustment factor: '{(1.0 - ((vol_adj - 0.02) * 10))}"
        #     );
        #     print(f"'  Time adjustment factor: '{time_adj}");
        #     print(f"'  Concentration penalty: '{conc_penalty}");
        #     print(f"'  Current positions:'");
        #     for (sym, pos) in engine.portfolio.positions.items() {
        #         price = engine.market_data.get_price(sym);
        #         value = <>abs((pos.quantity * price));
        #         weight = ((value / pv) * 100);
        #         print(
        #             f"'    '{sym}': '{pos.quantity}' shares, $'{value}' ('{weight}'%)'"
        #         );
        #     }
        #     return False;
        # }
        # except Exception as e {
        #     print(f"'Other error: '{e}");
        #     return False;
        # }

    }
    print('All trades completed successfully!');
    return True;
}


with entry {
    if (__name__ == '__main__') {
        success = simulate_trading();
        if not success {
            print('\nThis demonstrates how complex financial calculations');
            print('can fail due to subtle interactions between multiple factors.');
        }

    }
}

#!/usr/bin/env python3
"""
Pendle Strategy Backtesting
Historical testing with 3-hour rebalancing simulation
"""

import asyncio
import aiohttp
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import logging

from strategy import PendleStrategy

logger = logging.getLogger(__name__)

@dataclass
class BacktestResults:
    """Backtest results container"""
    portfolio_values: pd.DataFrame
    total_return: float
    annualized_return: float
    sharpe_ratio: float
    max_drawdown: float
    win_rate: float
    benchmark_returns: Dict[str, float]
    outperformance: Dict[str, float]
    rebalance_count: int
    total_fees: float

class PendleBacktester:
    """Historical backtesting with 3-hour rebalancing simulation"""
    
    def __init__(self, initial_investment: float = 10000, chain_id: int = 56):
        self.initial_investment = initial_investment
        self.chain_id = chain_id
        self.transaction_cost = 0.003  # 0.3% per rebalance
        self.rebalance_threshold = 0.02  # 2% APY improvement needed
        self.rebalance_interval_hours = 3  # Check every 3 hours
        
    async def fetch_historical_data(self, market_address: str, start_date: datetime, end_date: datetime) -> Optional[pd.DataFrame]:
        """Create mock historical data using current market data (since Pendle doesn't provide historical data)"""
        try:
            # Import strategy to get current market data
            from strategy import PendleStrategy
            strategy = PendleStrategy(self.chain_id)
            current_data = await strategy.fetch_market_data(market_address)
            
            if not current_data:
                logger.warning(f"No current data available for market {market_address}")
                return None
            
            # Create mock historical data using current APYs with some variation
            records = []
            current_time = start_date
            
            # Get current APYs from our strategy
            pt_apy = strategy.calculate_pt_apy(current_data)
            yt_apy = strategy.calculate_yt_apy(current_data) 
            lp_apy = strategy.calculate_lp_apy(current_data)
            
            # Create hourly records with slight variations (±10% random walk)
            import random
            random.seed(42)  # Reproducible results
            
            pt_variation = 1.0
            yt_variation = 1.0 
            lp_variation = 1.0
            
            while current_time <= end_date:
                # Random walk variations (±10%)
                pt_variation *= random.uniform(0.95, 1.05)
                yt_variation *= random.uniform(0.9, 1.1)  # YT more volatile
                lp_variation *= random.uniform(0.98, 1.02)  # LP more stable
                
                # Keep variations reasonable
                pt_variation = max(0.5, min(2.0, pt_variation))
                yt_variation = max(0.3, min(3.0, yt_variation))
                lp_variation = max(0.8, min(1.2, lp_variation))
                
                records.append({
                    'timestamp': current_time,
                    'pt_apy': max(0, pt_apy * pt_variation),
                    'yt_apy': max(0, yt_apy * yt_variation),
                    'lp_apy': max(0, lp_apy * lp_variation),
                    'pt_price': 1.0,
                    'liquidity': 1000000,  # Mock liquidity
                    'market_address': market_address
                })
                
                current_time += timedelta(hours=1)
            
            if not records:
                logger.warning(f"No mock records generated for market {market_address}")
                return None
            
            df = pd.DataFrame(records)
            df['timestamp'] = pd.to_datetime(df['timestamp'])
            logger.info(f"✅ Generated {len(records)} mock historical records for {market_address[:8]}...")
            return df
                        
        except Exception as e:
            logger.error(f"Failed to create mock historical data for {market_address}: {e}")
            return None
    
    def simulate_3_hour_rebalancing(self, all_market_data: Dict[str, pd.DataFrame], 
                                   initial_investment: float) -> Tuple[pd.DataFrame, int, float]:
        """Simulate strategy with 3-hour rebalancing checks"""
        
        # Create hourly timestamp range
        all_timestamps = []
        for df in all_market_data.values():
            all_timestamps.extend(df['timestamp'].tolist())
        
        if not all_timestamps:
            raise ValueError("No historical data available")
        
        start_time = max(min(df['timestamp']) for df in all_market_data.values())
        end_time = min(max(df['timestamp']) for df in all_market_data.values())
        
        # Create 3-hour intervals
        current_time = start_time
        check_times = []
        while current_time <= end_time:
            check_times.append(current_time)
            current_time += timedelta(hours=self.rebalance_interval_hours)
        
        # Initialize tracking
        portfolio_value = initial_investment
        portfolio_values = []
        current_allocation = None
        rebalance_count = 0
        total_fees = 0
        
        allocation_weights = [0.40, 0.30, 0.20, 0.10]
        
        for check_time in check_times:
            # Collect opportunities at this time
            opportunities = []
            
            for market_address, df in all_market_data.items():
                # Find data closest to check_time
                df_before = df[df['timestamp'] <= check_time]
                if df_before.empty:
                    continue
                
                latest_data = df_before.iloc[-1]
                
                # No liquidity filtering - pure profit-focused allocation
                
                # Find best strategy APY
                pt_apy = latest_data['pt_apy']
                yt_apy = latest_data['yt_apy']
                lp_apy = latest_data['lp_apy']
                
                best_apy = max(pt_apy, yt_apy, lp_apy)
                best_strategy = 'PT' if best_apy == pt_apy else 'YT' if best_apy == yt_apy else 'LP'
                
                opportunities.append({
                    'market_address': market_address,
                    'strategy': best_strategy,
                    'apy': best_apy,
                    'timestamp': check_time
                })
            
            if not opportunities:
                continue
                
            # Sort by APY descending
            opportunities.sort(key=lambda x: x['apy'], reverse=True)
            
            # Create new allocation
            new_allocation = []
            total_expected_apy = 0
            
            for i, weight in enumerate(allocation_weights):
                if i < len(opportunities):
                    opp = opportunities[i]
                    new_allocation.append({
                        'market_address': opp['market_address'],
                        'strategy': opp['strategy'],
                        'apy': opp['apy'],
                        'weight': weight
                    })
                    total_expected_apy += opp['apy'] * weight
                else:
                    # Use best available
                    if opportunities:
                        best_opp = opportunities[0]
                        new_allocation.append({
                            'market_address': best_opp['market_address'],
                            'strategy': best_opp['strategy'],
                            'apy': best_opp['apy'],
                            'weight': weight
                        })
                        total_expected_apy += best_opp['apy'] * weight
            
            # Check if rebalancing needed
            should_rebalance = False
            
            if current_allocation is None:
                should_rebalance = True  # First allocation
            else:
                current_expected_apy = sum(pos['apy'] * pos['weight'] for pos in current_allocation)
                apy_improvement = total_expected_apy - current_expected_apy
                
                if apy_improvement >= self.rebalance_threshold:
                    should_rebalance = True
            
            if should_rebalance:
                # Apply transaction costs
                transaction_cost = portfolio_value * self.transaction_cost
                portfolio_value -= transaction_cost
                total_fees += transaction_cost
                
                current_allocation = new_allocation
                rebalance_count += 1
            
            # Apply returns for next 3 hours (if we have current allocation)
            if current_allocation:
                current_apy = sum(pos['apy'] * pos['weight'] for pos in current_allocation)
                hours_return = current_apy / (365 * 24) * self.rebalance_interval_hours
                portfolio_value *= (1 + hours_return)
            
            # Record portfolio value
            portfolio_values.append({
                'timestamp': check_time,
                'portfolio_value': portfolio_value,
                'expected_apy': total_expected_apy if current_allocation else 0,
                'rebalanced': should_rebalance
            })
        
        portfolio_df = pd.DataFrame(portfolio_values)
        portfolio_df['timestamp'] = pd.to_datetime(portfolio_df['timestamp'])
        
        return portfolio_df, rebalance_count, total_fees
    
    def calculate_benchmarks(self, start_date: datetime, end_date: datetime) -> Dict[str, float]:
        """Calculate benchmark returns"""
        days = (end_date - start_date).days
        
        benchmarks = {
            'Risk-Free': 0.03,      # 3% annual
            'DeFi Average': 0.065,  # 6.5% annual
            'Aggressive DeFi': 0.11 # 11% annual
        }
        
        benchmark_returns = {}
        for name, annual_rate in benchmarks.items():
            total_return = (1 + annual_rate) ** (days / 365) - 1
            benchmark_returns[name] = total_return
        
        return benchmark_returns
    
    def calculate_metrics(self, portfolio_df: pd.DataFrame, start_date: datetime, 
                         end_date: datetime, rebalance_count: int, total_fees: float) -> BacktestResults:
        """Calculate backtest performance metrics"""
        
        if portfolio_df.empty:
            raise ValueError("No portfolio data to analyze")
        
        # Basic returns
        initial_value = self.initial_investment
        final_value = portfolio_df['portfolio_value'].iloc[-1]
        total_return = (final_value / initial_value) - 1
        
        # Annualized return
        days = (end_date - start_date).days
        if days > 0:
            annualized_return = (final_value / initial_value) ** (365 / days) - 1
        else:
            annualized_return = 0
        
        # Calculate daily returns for volatility
        portfolio_df = portfolio_df.sort_values('timestamp')
        portfolio_df['daily_return'] = portfolio_df['portfolio_value'].pct_change()
        daily_returns = portfolio_df['daily_return'].dropna()
        
        # Sharpe ratio
        if len(daily_returns) > 1:
            daily_vol = daily_returns.std()
            annual_vol = daily_vol * np.sqrt(365 * 24 / self.rebalance_interval_hours)  # Adjust for 3-hour intervals
            
            if annual_vol > 0:
                sharpe_ratio = (annualized_return - 0.03) / annual_vol
            else:
                sharpe_ratio = 0
        else:
            sharpe_ratio = 0
        
        # Maximum drawdown
        portfolio_df['cumulative_max'] = portfolio_df['portfolio_value'].cummax()
        portfolio_df['drawdown'] = (portfolio_df['portfolio_value'] / portfolio_df['cumulative_max']) - 1
        max_drawdown = portfolio_df['drawdown'].min()
        
        # Win rate
        if len(daily_returns) > 0:
            win_rate = (daily_returns > 0).mean()
        else:
            win_rate = 0
        
        # Benchmarks
        benchmark_returns = self.calculate_benchmarks(start_date, end_date)
        
        # Outperformance
        outperformance = {}
        for benchmark_name, benchmark_return in benchmark_returns.items():
            outperformance[benchmark_name] = total_return - benchmark_return
        
        return BacktestResults(
            portfolio_values=portfolio_df,
            total_return=total_return,
            annualized_return=annualized_return,
            sharpe_ratio=sharpe_ratio,
            max_drawdown=max_drawdown,
            win_rate=win_rate,
            benchmark_returns=benchmark_returns,
            outperformance=outperformance,
            rebalance_count=rebalance_count,
            total_fees=total_fees
        )
    
    async def run_backtest(self, market_addresses: List[str], start_date: datetime, 
                          end_date: datetime) -> Optional[BacktestResults]:
        """Run complete backtest with 3-hour rebalancing"""
        logger.info(f"🔄 Running 3-hour rebalancing backtest")
        logger.info(f"   Period: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")
        logger.info(f"   Markets: {len(market_addresses)}")
        logger.info(f"   Rebalance interval: {self.rebalance_interval_hours} hours")
        logger.info(f"   APY threshold: {self.rebalance_threshold:.1%}")
        
        try:
            # Fetch historical data
            all_market_data = {}
            
            for market_address in market_addresses:
                logger.info(f"   Fetching hourly data for {market_address[:8]}...")
                market_data = await self.fetch_historical_data(market_address, start_date, end_date)
                
                if market_data is not None and not market_data.empty:
                    all_market_data[market_address] = market_data
                    logger.info(f"     ✅ Got {len(market_data)} hourly records")
                else:
                    logger.warning(f"     ❌ No data available")
            
            if not all_market_data:
                logger.error("❌ No historical data available")
                return None
            
            logger.info(f"✅ Data loaded for {len(all_market_data)} markets")
            
            # Run 3-hour simulation
            logger.info("🧮 Simulating 3-hour rebalancing strategy...")
            portfolio_df, rebalance_count, total_fees = self.simulate_3_hour_rebalancing(
                all_market_data, self.initial_investment
            )
            
            # Calculate metrics
            results = self.calculate_metrics(
                portfolio_df, start_date, end_date, rebalance_count, total_fees
            )
            
            logger.info("✅ Backtest completed")
            logger.info(f"   Total rebalances: {rebalance_count}")
            logger.info(f"   Final return: {results.total_return:.2%}")
            
            return results
            
        except Exception as e:
            logger.error(f"❌ Backtest failed: {e}")
            import traceback
            traceback.print_exc()
            return None

# Simple helper function
async def run_pendle_backtest(initial_investment: float = 10000,
                             market_addresses: List[str] = None,
                             start_date: datetime = None,
                             end_date: datetime = None,
                             chain_id: int = 56) -> Optional[BacktestResults]:
    """Run Pendle backtest with 3-hour rebalancing"""
    
    # Set defaults
    if market_addresses is None:
        market_addresses = [
            "0x74c5050a89046c40296a32aeaed31be89d6a6d87",  # satUSD+ market
            "0xb5b56637810e4d090894785993f4cdd6875d927e",  # USDe market
            "0x9edac81bac78a2c06b59514d6eb62dd7a57adf21"   # sigmaSP market
        ]
    
    if start_date is None:
        start_date = datetime.now() - timedelta(days=30)
    
    if end_date is None:
        end_date = datetime.now() - timedelta(days=1)
    
    backtester = PendleBacktester(initial_investment, chain_id)
    return await backtester.run_backtest(market_addresses, start_date, end_date)
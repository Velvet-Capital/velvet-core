#!/usr/bin/env python3
"""
Automated Yield Optimization Scheduler

Runs every 1-2 hours to:
1. Call optimizer.py to analyze opportunities
2. Check if rebalancing is profitable
3. Execute rebalancing if profitable
4. Log results and wait for next interval

Usage:
    python3 yield_scheduler.py --interval 3600  # Run every 1 hour
    python3 yield_scheduler.py --interval 7200  # Run every 2 hours
"""

import asyncio
import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from typing import Dict, Optional

# Add the current directory to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

from core.optimizer import SimpleOptimizer
from core.executor import SimpleExecutor

class YieldScheduler:
    """Automated yield optimization scheduler"""
    
    def __init__(self, portfolio_address: str, check_interval: int = 7200):
        """
        Initialize the yield scheduler
        
        Args:
            portfolio_address: The vault/portfolio address to optimize
            check_interval: How often to check for opportunities (seconds, default 2 hours)
        """
        self.portfolio_address = portfolio_address
        self.check_interval = check_interval
        self.optimizer = SimpleOptimizer(portfolio_address)
        self.executor = SimpleExecutor(portfolio_address)
        
        # Logging setup
        self.log_file = os.path.join(current_dir, "logs", "yield_scheduler.log")
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
        
        # Stats tracking
        self.stats = {
            'total_runs': 0,
            'opportunities_found': 0,
            'successful_rebalances': 0,
            'failed_rebalances': 0,
            'skipped_unprofitable': 0,
            'last_rebalance': None,
            'start_time': datetime.now(timezone.utc).isoformat()
        }
    
    def log_message(self, message: str, level: str = "INFO"):
        """Log message with timestamp to both console and file"""
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        log_entry = f"[{timestamp}] [{level}] {message}"
        
        # Print to console
        print(log_entry)
        
        # Write to log file
        try:
            with open(self.log_file, 'a') as f:
                f.write(log_entry + "\n")
        except Exception as e:
            print(f"Warning: Could not write to log file: {e}")
    
    def save_stats(self):
        """Save scheduler statistics"""
        try:
            stats_file = os.path.join(current_dir, "logs", "scheduler_stats.json")
            with open(stats_file, 'w') as f:
                json.dump(self.stats, f, indent=2)
        except Exception as e:
            self.log_message(f"Could not save stats: {e}", "WARNING")
    
    async def check_opportunities(self) -> Optional[Dict]:
        """
        Check for optimization opportunities using the optimizer
        Returns plan if rebalancing is needed, None otherwise
        """
        try:
            self.log_message("🔍 Checking for yield optimization opportunities...")
            
            # Generate optimization plan
            plan = await self.optimizer.generate_plan()
            
            if plan and plan.get('needs_rebalancing', False):
                self.log_message(f"✅ Profitable opportunity found!")
                self.log_message(f"   Expected APY: {plan['total_expected_apy']:.2%}")
                self.log_message(f"   Rebalancing steps: {len(plan['rebalancing_steps'])}")
                self.stats['opportunities_found'] += 1
                return plan
            else:
                self.log_message("ℹ️  No profitable opportunities found")
                self.stats['skipped_unprofitable'] += 1
                return None
                
        except Exception as e:
            self.log_message(f"❌ Error checking opportunities: {e}", "ERROR")
            return None
    
    async def execute_rebalancing(self, plan: Dict) -> bool:
        """Execute rebalancing using the executor"""
        try:
            self.log_message("🚀 Executing rebalancing...")
            
            # Execute rebalancing
            success = await self.executor.execute_rebalancing()
            
            if success:
                self.log_message("✅ Rebalancing completed successfully!")
                self.stats['successful_rebalances'] += 1
                self.stats['last_rebalance'] = datetime.now(timezone.utc).isoformat()
                return True
            else:
                self.log_message("❌ Rebalancing failed", "ERROR")
                self.stats['failed_rebalances'] += 1
                return False
                
        except Exception as e:
            self.log_message(f"❌ Error executing rebalancing: {e}", "ERROR")
            self.stats['failed_rebalances'] += 1
            return False
    
    async def run_single_check(self):
        """Run a single optimization check cycle"""
        self.stats['total_runs'] += 1
        
        self.log_message(f"🔄 Starting optimization check #{self.stats['total_runs']}")
        self.log_message(f"📍 Portfolio: {self.portfolio_address}")
        
        # Check for opportunities
        plan = await self.check_opportunities()
        
        if plan:
            # Execute rebalancing if opportunity found
            await self.execute_rebalancing(plan)
        
        # Save stats
        self.save_stats()
        
        # Log summary
        self.log_message(f"📊 Session stats: {self.stats['successful_rebalances']} successful, "
                        f"{self.stats['failed_rebalances']} failed, "
                        f"{self.stats['skipped_unprofitable']} skipped")
    
    async def run_scheduler(self):
        """Main scheduler loop - runs continuously"""
        self.log_message("🤖 Yield Optimization Scheduler started")
        self.log_message(f"⏰ Check interval: {self.check_interval / 3600:.1f} hours ({self.check_interval} seconds)")
        self.log_message(f"📍 Portfolio: {self.portfolio_address}")
        
        try:
            while True:
                await self.run_single_check()
                
                # Wait for next interval
                self.log_message(f"😴 Sleeping for {self.check_interval / 3600:.1f} hours until next check...")
                await asyncio.sleep(self.check_interval)
                
        except KeyboardInterrupt:
            self.log_message("⏹️  Scheduler stopped by user")
        except Exception as e:
            self.log_message(f"💥 Scheduler crashed: {e}", "ERROR")
            raise
        finally:
            self.save_stats()
            self.log_message("👋 Yield Optimization Scheduler stopped")

async def main():
    """Main function with CLI argument parsing"""
    parser = argparse.ArgumentParser(description="Automated Yield Optimization Scheduler")
    parser.add_argument('--interval', type=int, default=7200, 
                       help='Check interval in seconds (default: 7200 = 2 hours)')
    parser.add_argument('--portfolio', type=str, 
                       default="0xbD35fCaC7813FC3B4bc14a5D0AC686c8e8b780Bc",
                       help='Portfolio address to optimize')
    parser.add_argument('--once', action='store_true',
                       help='Run once and exit (useful for testing)')
    
    args = parser.parse_args()
    
    # Validate interval (minimum 30 minutes, maximum 24 hours)
    if args.interval < 1800:  # 30 minutes
        print("❌ Minimum interval is 1800 seconds (30 minutes)")
        sys.exit(1)
    elif args.interval > 86400:  # 24 hours
        print("❌ Maximum interval is 86400 seconds (24 hours)")
        sys.exit(1)
    
    # Initialize scheduler
    scheduler = YieldScheduler(args.portfolio, args.interval)
    
    if args.once:
        # Run once for testing
        await scheduler.run_single_check()
    else:
        # Run continuously
        await scheduler.run_scheduler()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Scheduler stopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n💥 Fatal error: {e}")
        sys.exit(1)
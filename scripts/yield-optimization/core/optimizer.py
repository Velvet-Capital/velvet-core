import asyncio
import json
import sys
import os
from typing import Dict, List

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from adapters.api_adapter import APIAdapter, NON_YIELD_TOKENS, IGNORED_YIELD_TOKENS
from adapters.pendle_adapter import PendleAdapter
from core.portfolio_fetcher import SimplePortfolioFetcher


class SimpleOptimizer:
    """Simple cross-protocol optimizer - keep it minimal and effective"""
    
    def __init__(self, vault_address: str):
        self.vault_address = vault_address
        self.allocation_weights = [0.40, 0.30, 0.20, 0.10] 
        self.portfolio_fetcher = SimplePortfolioFetcher(vault_address)
        
        # Initialize adapters (now using unified API adapter)
        self.adapters = [
            APIAdapter(chain_id=56, protocols=["pendle", "pendle-yt", "pendle-sy", "pendle-pt", "euler"], token_search="BNB", min_apy=0.04),
            # PendleAdapter(chain_id=56),
        ]
        
        # Add caching to eliminate double API calls
        self._token_cache = None
        self._cache_timestamp = None
    
    async def get_all_tokens(self, use_cache: bool = True) -> List[Dict]:
        """Get tokens from all adapters with smart deduplication and optimization"""
        import time
        
        # Check cache first (5 minutes cache lifetime)
        if use_cache and self._token_cache is not None and self._cache_timestamp is not None:
            cache_age = time.time() - self._cache_timestamp
            if cache_age < 300:  # 5 minutes
                print(f"🔍 get_all_tokens() using cached data (age: {cache_age:.1f}s)")
                return self._token_cache
        
        print("🔍 get_all_tokens() fetching fresh data...")
        all_tokens = []
        
        print(f"📡 Processing {len(self.adapters)} adapter(s)...")
        for i, adapter in enumerate(self.adapters):
            try:
                print(f"   📊 Adapter {i+1}: {adapter.get_protocol_name()} - getting tokens with impact...")
                # Get tokens with price impact check
                tokens = await adapter.get_tokens_with_impact()
                all_tokens.extend(tokens)
                print(f"   ✅ Adapter {i+1} returned {len(tokens)} tokens")
            except Exception as e:
                print(f"   ❌ Adapter {adapter.get_protocol_name()} failed: {e}")
                continue
        
        print(f"📊 Step 1: Collected {len(all_tokens)} raw tokens from all adapters")
        
        # Smart deduplication - keep highest APY version of each token address
        print("🔄 Step 2: Deduplicating tokens by address (keeping highest APY)...")
        deduplicated_map = {}
        duplicate_count = 0
        
        for token in all_tokens:
            addr = token['address'].lower()
            if addr in deduplicated_map:
                duplicate_count += 1
                # Keep token with higher APY
                if token['apy'] > deduplicated_map[addr]['apy']:
                    print(f"   🔄 Better APY found for {token.get('symbol', addr[:10])}...: {deduplicated_map[addr]['apy']:.2%} → {token['apy']:.2%}")
                    deduplicated_map[addr] = token
            else:
                deduplicated_map[addr] = token
        
        deduplicated_tokens = list(deduplicated_map.values())
        print(f"   📊 Removed {duplicate_count} duplicates: {len(all_tokens)} → {len(deduplicated_tokens)} unique tokens")
        
        # Sort by APY for better logging
        deduplicated_tokens.sort(key=lambda x: x['apy'], reverse=True)
        
        # Log top tokens for verification
        print("🔍 Step 3: Top tokens after deduplication:")
        for i, token in enumerate(deduplicated_tokens[:8]):  # Show top 8
            protocol = token.get('protocol', 'unknown')
            print(f"   {i+1}. {token.get('symbol', 'Unknown')}: {token['apy']:.2%} APY ({protocol})")
        
        print(f"✅ Final result: {len(deduplicated_tokens)} optimized unique tokens ready for selection")
        
        # Cache the results to avoid double API calls
        import time
        self._token_cache = deduplicated_tokens
        self._cache_timestamp = time.time()
        print(f"💾 Token data cached for future use")
        
        return deduplicated_tokens
    
    async def get_current_portfolio_top4_apys(self, current_state: Dict) -> List[float]:
        """
        Get current portfolio's top 4 token APYs sorted by performance (highest first).
        Returns list of 4 APY values for position-by-position comparison.
        """
        print("🔍 get_current_portfolio_top4_apys() starting...")
        
        try:
            current_tokens = current_state.get('current_tokens', [])
            print(f"📊 Current portfolio has {len(current_tokens)} tokens")
            
            if not current_tokens:
                print("⚠️  No current tokens found, returning [0%, 0%, 0%, 0%]")
                return [0.0, 0.0, 0.0, 0.0]
            
            # Get all available tokens with enhanced deduplication (use cache to avoid double API calls)
            print(f"🔍 Getting APY data using cached token collection...")
            try:
                all_adapter_tokens = await self.get_all_tokens(use_cache=True)
                print(f"   ✅ Token collection returned {len(all_adapter_tokens)} deduplicated tokens")
            except Exception as e:
                print(f"   ❌ Enhanced token collection failed: {e}")
                print("   🔄 Falling back to direct adapter calls...")
                # Fallback to old method if enhanced fails
                all_adapter_tokens = []
                for i, adapter in enumerate(self.adapters):
                    try:
                        print(f"   📡 Fallback: Calling adapter {i+1}/{len(self.adapters)}: {adapter.get_protocol_name()}")
                        adapter_tokens = await adapter.get_tokens()
                        all_adapter_tokens.extend(adapter_tokens)
                        print(f"   ✅ Fallback: Adapter {i+1} returned {len(adapter_tokens)} tokens")
                    except Exception as e:
                        print(f"   ❌ Adapter {adapter.get_protocol_name()} failed in APY lookup: {e}")
                        continue
            
            # Create APY lookup map
            token_apy_map = {}
            for token in all_adapter_tokens:
                token_apy_map[token['address'].lower()] = token['apy']
            
            # Get APY for each current token
            current_token_apys = []
            
            for token_address in current_tokens:
                # Look up APY for this token
                token_apy = token_apy_map.get(token_address.lower(), None)
                
                if token_apy is not None:
                    current_token_apys.append({
                        'address': token_address,
                        'apy': token_apy
                    })
                    print(f"   📊 {token_address[:10]}...: {token_apy:.2%} APY")
                else:
                    # Check if it's a known non-yield token
                    if token_address.lower() in NON_YIELD_TOKENS:
                        current_token_apys.append({
                            'address': token_address,
                            'apy': 0.0
                        })
                        print(f"   📊 {token_address[:10]}... (Non-yield): 0.00% APY")
                    else:
                        # Unknown token - conservative 0% APY
                        current_token_apys.append({
                            'address': token_address,
                            'apy': 0.0
                        })
                        print(f"   ⚠️  {token_address[:10]}...: Unknown, using 0.00% APY")
            
            # Sort by APY (highest first) and take top 4
            current_token_apys.sort(key=lambda x: x['apy'], reverse=True)
            top4_apys = [token['apy'] for token in current_token_apys[:4]]
            
            # Pad with 0% if fewer than 4 tokens
            while len(top4_apys) < 4:
                top4_apys.append(0.0)
            
            print(f"💰 Current portfolio top 4 APYs: {[f'{apy:.2%}' for apy in top4_apys]}")
            return top4_apys
                
        except Exception as e:
            print(f"❌ Error getting current portfolio APYs: {e}")
            print("⚠️  Using fallback [0%, 0%, 0%, 0%]")
            return [0.0, 0.0, 0.0, 0.0]
    
    async def calculate_rebalancing_profitability(self, current_state: Dict, target_allocation: List[Dict], total_expected_apy: float) -> bool:
        """
        Calculate if rebalancing is profitable using position-by-position APY comparison.
        Returns True if rebalancing is recommended, False otherwise.
        """
        try:
            # Get current portfolio's top 4 APYs (sorted highest to lowest)
            current_top4_apys = await self.get_current_portfolio_top4_apys(current_state)
            
            # Get target portfolio's 4 APYs (already sorted by selection process)
            target_top4_apys = [alloc['apy'] for alloc in target_allocation[:4]]
            
            # Pad target APYs if fewer than 4
            while len(target_top4_apys) < 4:
                target_top4_apys.append(0.0)
            
            print(f"🔍 Position-by-position APY comparison:")
            print(f"   Current: {[f'{apy:.2%}' for apy in current_top4_apys]}")
            print(f"   Target:  {[f'{apy:.2%}' for apy in target_top4_apys]}")
            
            # Compare position by position and sum positive improvements
            total_improvement = 0.0
            position_improvements = []
            
            for i in range(4):
                improvement = target_top4_apys[i] - current_top4_apys[i]
                position_improvements.append(improvement)
                
                # Only count positive improvements toward threshold
                if improvement > 0:
                    total_improvement += improvement
                    print(f"   Position {i+1}: +{improvement:.2%} improvement")
                elif improvement == 0:
                    print(f"   Position {i+1}: No change (same APY)")
                else:
                    print(f"   Position {i+1}: {improvement:.2%} (target lower, no contribution)")
            
            print(f"🎯 Total APY improvement: {total_improvement:.2%}")
            
            # APY improvement threshold - must improve by at least 1.5%
            if total_improvement < 0.015:  # Less than 1.5% improvement
                print(f"🔍 Total improvement ({total_improvement:.2%}) below 1.5% threshold")
                return False
            
            # Get portfolio value for gas cost analysis
            portfolio_value = current_state.get('total_value_usd', 0)
            if portfolio_value == 0:
                print("⚠️  Cannot determine portfolio value, proceeding with rebalancing")
                return True  # Default to rebalancing if we can't determine value
            
            # Estimate gas cost (rough calculation)
            # Typical rebalancing: ~500k gas at ~5 gwei = ~0.025 BNB = ~$7.5
            estimated_gas_cost_usd = 10.0  # Conservative estimate in USD
            
            # Calculate expected daily profit from APY improvement
            expected_daily_profit = (portfolio_value * total_improvement) / 365
            
            # Profitability check - daily profit should exceed 2x gas cost for safety margin
            profit_threshold = estimated_gas_cost_usd * 2  # 2x safety margin
            
            if expected_daily_profit < profit_threshold:
                print(f"🔍 Profitability check failed:")
                print(f"   Expected daily profit: ${expected_daily_profit:.2f}")
                print(f"   Required threshold: ${profit_threshold:.2f}")
                print(f"   Portfolio value: ${portfolio_value:.2f}")
                print(f"   Total APY improvement: {total_improvement:.2%}")
                return False
            
            print(f"✅ Rebalancing profitable:")
            print(f"   Total APY improvement: {total_improvement:.2%}")
            print(f"   Expected daily profit: ${expected_daily_profit:.2f}")
            print(f"   Gas cost estimate: ${estimated_gas_cost_usd:.2f}")
            
            return True
            
        except Exception as e:
            print(f"⚠️  Error in profitability calculation: {e}")
            return True  # Default to rebalancing on error
    
    async def get_optimal_allocation(self) -> Dict:
        """Get optimal allocation - simple and direct"""
        print("🎯 get_optimal_allocation() starting...")
        
        # Get current portfolio state
        print("📊 Step 1: Getting current portfolio state...")
        current_state = await self.portfolio_fetcher.get_portfolio_state()
        print(f"   ✅ Portfolio state retrieved: {len(current_state.get('current_tokens', []))} tokens")
        
        # Get all available tokens with liquidity check
        print("📡 Step 2: Getting all available tokens from adapters...")
        all_tokens = await self.get_all_tokens()
        
        if not all_tokens:
            print("❌ No liquid tokens found!")
            raise Exception("No liquid tokens found")
        
        print(f"   ✅ Found {len(all_tokens)} liquid tokens")
        
        # Sort by APY (highest first) and select top 4 tokens
        print("📊 Step 3: Sorting all tokens by APY and selecting top 4...")
        all_tokens.sort(key=lambda x: x['apy'], reverse=True)
        
        # Take top 4 tokens for 40/30/20/10 allocation (regardless of current holdings)
        selected_tokens = all_tokens[:4]
        
        print("🎯 Selected top 4 tokens for target allocation:")
        for i, token in enumerate(selected_tokens):
            weight = self.allocation_weights[i] if i < len(self.allocation_weights) else 0.10
            print(f"   {i+1}. {token.get('symbol', 'Unknown')}: {token['apy']:.2%} APY (weight: {weight:.0%})")
        
        # Store for optimization summary  
        total_tokens_before_filter = len(all_tokens)
        filtered_count = 0  # No filtering anymore
        
        # Build target allocation
        target_allocation = []
        total_expected_apy = 0
        
        for i, token in enumerate(selected_tokens):
            weight = self.allocation_weights[i] if i < len(self.allocation_weights) else 0.10
            
            target_allocation.append({
                'token_address': token['address'],
                'symbol': token['symbol'],
                'protocol': token['protocol'],
                'apy': token['apy'],
                'weight': weight,
                'price_impact': token.get('price_impact', 0.02)
            })
            
            total_expected_apy += token['apy'] * weight
        
        # Smart rebalancing decision with profitability analysis
        print("🔍 Step 4: Analyzing rebalancing necessity...")
        current_tokens = set(current_state['current_tokens'])
        target_tokens = set(alloc['token_address'] for alloc in target_allocation)
        
        print(f"   Current tokens: {len(current_tokens)}")
        print(f"   Target tokens: {len(target_tokens)}")
        
        # First check if tokens are different
        tokens_different = current_tokens != target_tokens
        
        if not tokens_different:
            print("🔍 Portfolio already optimal - no token changes needed")
            needs_rebalancing = False
        else:
            # Check profitability if tokens need changing
            print("🔍 Step 5: Running profitability analysis (this may take time)...")
            needs_rebalancing = await self.calculate_rebalancing_profitability(
                current_state, target_allocation, total_expected_apy
            )
            print(f"   ✅ Profitability analysis complete: needs_rebalancing = {needs_rebalancing}")
        
        # Generate simple rebalancing steps
        steps = []
        if needs_rebalancing:
            step_counter = 1
            
            # Sell tokens not in target
            for token in current_tokens - target_tokens:
                steps.append({
                    'step': step_counter,
                    'action': 'sell',
                    'token_address': token,
                    'reason': 'Not in optimal allocation'
                })
                step_counter += 1
            
            # Buy tokens in target but not current
            for alloc in target_allocation:
                if alloc['token_address'] not in current_tokens:
                    steps.append({
                        'step': step_counter,
                        'action': 'buy',
                        'token_address': alloc['token_address'],
                        'target_weight': alloc['weight'],
                        'reason': f"Target {alloc['weight']:.0%} allocation"
                    })
                    step_counter += 1
        
        return {
            'current_portfolio': current_state,
            'target_allocation': target_allocation,
            'total_expected_apy': total_expected_apy,
            'needs_rebalancing': needs_rebalancing,
            'rebalancing_steps': steps,
            'optimization_summary': {
                'total_tokens_analyzed': len(all_tokens),
                'total_tokens_from_adapters': total_tokens_before_filter,
                'protocols_used': list(set(token['protocol'] for token in selected_tokens)),
                'top_apy': selected_tokens[0]['apy'] if selected_tokens else 0,
                'deduplication_applied': True
            }
        }
    
    async def generate_plan(self, output_file: str = None) -> Dict:
        """Generate optimization plan and save to JSON"""
        try:
            plan = await self.get_optimal_allocation()
            
            # Default output location
            if output_file is None:
                output_file = os.path.join(
                    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                    'output', 
                    'plan.json'
                )
            
            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_file), exist_ok=True)
            
            # Save plan
            with open(output_file, 'w') as f:
                json.dump(plan, f, indent=2, default=str)
            
            print(f"✅ Optimization plan saved: {output_file}")
            print(f"📊 Expected APY: {plan['total_expected_apy']:.2%}")
            print(f"🔄 Needs Rebalancing: {plan['needs_rebalancing']}")
            print(f"📝 Steps Required: {len(plan['rebalancing_steps'])}")
            
            return plan
            
        except Exception as e:
            print(f"❌ Optimization failed: {e}")
            raise

# CLI interface for testing
async def main():
    portfolio_address = "0xbD35fCaC7813FC3B4bc14a5D0AC686c8e8b780Bc"  # Your portfolio
    
    optimizer = SimpleOptimizer(portfolio_address)
    plan = await optimizer.generate_plan()
    
    print("\n" + "="*50)
    print("🎯 SIMPLE CROSS-PROTOCOL OPTIMIZATION")
    print("="*50)
    
    for i, alloc in enumerate(plan['target_allocation']):
        print(f"{i+1}. {alloc['weight']:.0%} → {alloc['symbol']} ({alloc['protocol']}) - APY: {alloc['apy']:.2%}")

if __name__ == "__main__":
    asyncio.run(main())
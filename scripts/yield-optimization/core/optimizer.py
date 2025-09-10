import asyncio
import json
import sys
import os
from typing import Dict, List

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from adapters.pendle_adapter import PendleAdapter
from core.portfolio_fetcher import SimplePortfolioFetcher

# Token Classification Constants
# Non-yield bearing tokens (stablecoins, base tokens) - get 0% APY
NON_YIELD_TOKENS = {
    "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",  # WBNB
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d",  # USDC
    "0x55d398326f99059ff775485246999027b3197955",  # USDT
    "0xe9e7cea3dedca5984780bafc599bd69add087d56",  # BUSD
    "0x2170ed0880ac9a755fd29b2688956bd959f933f8",  # ETH
}

# Yield tokens to exclude from optimization selection (manual blacklist)
IGNORED_YIELD_TOKENS = {
    # Add token addresses you want to exclude from optimization
    # Example: "0x1234567890123456789012345678901234567890",
}

class SimpleOptimizer:
    """Simple cross-protocol optimizer - keep it minimal and effective"""
    
    def __init__(self, vault_address: str):
        self.vault_address = vault_address
        self.allocation_weights = [0.40, 0.30, 0.20, 0.10] 
        self.portfolio_fetcher = SimplePortfolioFetcher(vault_address)
        
        # Initialize adapters (start with Pendle, add more later)
        self.adapters = [
            PendleAdapter(chain_id=56)
        ]
    
    async def get_all_tokens(self) -> List[Dict]:
        """Get tokens from all adapters with price impact filtering"""
        all_tokens = []
        
        for adapter in self.adapters:
            try:
                # Get tokens with price impact check
                tokens = await adapter.get_tokens_with_impact()
                all_tokens.extend(tokens)
            except Exception as e:
                print(f"Warning: Adapter {adapter.protocol_name} failed: {e}")
                continue
        
        # Filter out manually ignored yield tokens
        if IGNORED_YIELD_TOKENS:
            initial_count = len(all_tokens)
            filtered_tokens = [
                token for token in all_tokens 
                if token['address'].lower() not in IGNORED_YIELD_TOKENS
            ]
            
            if len(filtered_tokens) < initial_count:
                ignored_count = initial_count - len(filtered_tokens)
                print(f"🚫 Filtered out {ignored_count} ignored yield tokens")
            
            return filtered_tokens
        
        return all_tokens
    
    async def calculate_current_portfolio_apy(self, current_state: Dict) -> float:
        """
        Calculate the current portfolio's weighted average APY using adapters.
        Returns the actual current APY for accurate profitability comparison.
        """
        try:
            current_tokens = current_state.get('current_tokens', [])
            balances = current_state.get('balances', {})
            
            if not current_tokens or not balances:
                print(f"⚠️  No current tokens ({len(current_tokens)}) or balances ({len(balances)}) found, using default 5% APY")
                return 0.05
            
            # Get all available tokens with APY data from adapters
            all_adapter_tokens = []
            for adapter in self.adapters:
                try:
                    adapter_tokens = await adapter.get_tokens()
                    all_adapter_tokens.extend(adapter_tokens)
                except Exception as e:
                    print(f"Warning: Adapter {adapter.get_protocol_name()} failed in APY calculation: {e}")
                    continue
            
            # Create APY lookup map
            token_apy_map = {}
            for token in all_adapter_tokens:
                token_apy_map[token['address'].lower()] = token['apy']
            
            # Calculate weighted APY
            total_weighted_apy = 0
            total_balance_value = 0
            found_apys = 0
            
            for token_address in current_tokens:
                token_balance = balances.get(token_address, 0)
                if token_balance > 0:
                    # Look up APY for this token
                    token_apy = token_apy_map.get(token_address.lower(), None)
                    
                    if token_apy is not None:
                        # Weight by balance (simple approach - assume all tokens have similar price)
                        total_weighted_apy += token_apy * token_balance
                        total_balance_value += token_balance
                        found_apys += 1
                        print(f"   📊 {token_address[:10]}...: {token_apy:.2%} APY")
                    else:
                        # Token not found in adapters - check if it's a known non-yield token
                        if token_address.lower() in NON_YIELD_TOKENS:
                            # Non-yield bearing token (stablecoin/base token)
                            total_weighted_apy += 0 * token_balance
                            total_balance_value += token_balance
                            print(f"   📊 {token_address[:10]}... (Non-yield): 0.00% APY")
                        else:
                            # Unknown token - conservative 0% APY
                            total_balance_value += token_balance
                            print(f"   ⚠️  {token_address[:10]}...: Unknown, using 0.00% APY")
            
            if total_balance_value > 0:
                current_portfolio_apy = total_weighted_apy / total_balance_value
                print(f"💰 Current portfolio APY: {current_portfolio_apy:.2%} (based on {found_apys} tokens)")
                return current_portfolio_apy
            else:
                print("⚠️  No token balances found, using default 5% APY")
                return 0.05
                
        except Exception as e:
            print(f"❌ Error calculating current portfolio APY: {e}")
            print("⚠️  Using default 5% APY as fallback")
            return 0.05
    
    async def calculate_rebalancing_profitability(self, current_state: Dict, target_allocation: List[Dict], total_expected_apy: float) -> bool:
        """
        Calculate if rebalancing is profitable after considering gas costs and APY improvement.
        Returns True if rebalancing is recommended, False otherwise.
        """
        try:
            # Calculate actual current portfolio APY
            current_apy = await self.calculate_current_portfolio_apy(current_state)
            
            # APY improvement threshold - must improve by at least 1.5%
            apy_improvement = total_expected_apy - current_apy
            if apy_improvement < 0.015:  # Less than 1.5% improvement
                print(f"🔍 APY improvement ({apy_improvement:.2%}) below 1.5% threshold")
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
            expected_daily_profit = (portfolio_value * apy_improvement) / 365
            
            # Profitability check - daily profit should exceed 2x gas cost for safety margin
            profit_threshold = estimated_gas_cost_usd * 2  # 2x safety margin
            
            if expected_daily_profit < profit_threshold:
                print(f"🔍 Profitability check failed:")
                print(f"   Expected daily profit: ${expected_daily_profit:.2f}")
                print(f"   Required threshold: ${profit_threshold:.2f}")
                print(f"   Portfolio value: ${portfolio_value:.2f}")
                print(f"   APY improvement: {apy_improvement:.2%}")
                return False
            
            print(f"✅ Rebalancing profitable:")
            print(f"   APY improvement: {apy_improvement:.2%}")
            print(f"   Expected daily profit: ${expected_daily_profit:.2f}")
            print(f"   Gas cost estimate: ${estimated_gas_cost_usd:.2f}")
            
            return True
            
        except Exception as e:
            print(f"⚠️  Error in profitability calculation: {e}")
            return True  # Default to rebalancing on error
    
    async def get_optimal_allocation(self) -> Dict:
        """Get optimal allocation - simple and direct"""
        
        # Get current portfolio state
        current_state = await self.portfolio_fetcher.get_portfolio_state()
        
        # Get all available tokens with liquidity check
        all_tokens = await self.get_all_tokens()
        
        if not all_tokens:
            raise Exception("No liquid tokens found")
        
        # Sort by APY (highest first)
        all_tokens.sort(key=lambda x: x['apy'], reverse=True)
        
        # Take top 4 tokens for 40/30/20/10 allocation
        selected_tokens = all_tokens[:4]
        
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
        current_tokens = set(current_state['current_tokens'])
        target_tokens = set(alloc['token_address'] for alloc in target_allocation)
        
        # First check if tokens are different
        tokens_different = current_tokens != target_tokens
        
        if not tokens_different:
            print("🔍 Portfolio already optimal - no token changes needed")
            needs_rebalancing = False
        else:
            # Check profitability if tokens need changing
            print("🔍 Analyzing rebalancing profitability...")
            needs_rebalancing = await self.calculate_rebalancing_profitability(
                current_state, target_allocation, total_expected_apy
            )
        
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
                'protocols_used': list(set(token['protocol'] for token in selected_tokens)),
                'top_apy': selected_tokens[0]['apy'] if selected_tokens else 0
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
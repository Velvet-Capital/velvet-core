#!/usr/bin/env python3
"""
Flexible Token Swap Script
Swap a specific token to another token with configurable percentage
"""
import asyncio
import sys
import os

# Add the current directory to Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

from core.executor import SimpleExecutor

# ============================================
# CONFIGURATION - MODIFY THESE VALUES
# ============================================

# Token addresses (leave blank to fill in)
TOKEN_IN = "0x7608eB2fc533343556e443511a2747F605E49C9B"   # Input token address to sell
TOKEN_OUT = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"  # Output token address to buy

# Percentage to sell (1-100)
PERCENTAGE = 100  # How much % of tokenIn to sell (100 = all)

# ============================================

async def execute_token_swap(token_in: str, token_out: str, percentage: float):
    """Execute token swap with specified parameters"""
    try:
        print("🔄 Starting Token Swap...")
        print("=" * 50)
        print(f"📤 Token IN:  {token_in}")
        print(f"📥 Token OUT: {token_out}")
        print(f"📊 Percentage: {percentage}%")
        print("=" * 50)
        
        # Validate inputs
        if not token_in or not token_out:
            print("❌ Please configure TOKEN_IN and TOKEN_OUT addresses")
            return False
            
        if not (1 <= percentage <= 100):
            print("❌ Percentage must be between 1 and 100")
            return False
        
        # Initialize executor
        portfolio_address = "0xbD35fCaC7813FC3B4bc14a5D0AC686c8e8b780Bc"
        executor = SimpleExecutor(portfolio_address)
        
        print(f"🔐 Using vault owner: {executor.owner.address}")
        print(f"🏦 Portfolio address: {executor.portfolio_address}")
        
        # Get current portfolio state
        current_state = await executor.get_current_portfolio_state()
        current_tokens = current_state.get('current_tokens', [])
        balances = current_state.get('balances', {})
        vault_address = current_state.get('vault_address', executor.vault_address)
        
        print(f"📊 Portfolio has {len(current_tokens)} tokens")
        
        # Check if tokenIn exists in portfolio
        token_in_balance = 0
        token_in_found = False
        
        for token in current_tokens:
            if token.lower() == token_in.lower():
                token_in_balance = balances.get(token, 0)
                token_in_found = True
                token_in = token  # Use the exact case from portfolio
                break
        
        if not token_in_found:
            print(f"❌ Token {token_in} not found in portfolio")
            print("Available tokens:")
            for token in current_tokens:
                balance = balances.get(token, 0)
                print(f"  - {token}: {balance / 1e18:.6f}")
            return False
        
        if token_in_balance == 0:
            print(f"❌ Token {token_in} has zero balance")
            return False
        
        # Calculate amount to swap based on percentage
        swap_amount = int(token_in_balance * percentage / 100)
        remaining_amount = token_in_balance - swap_amount
        
        print(f"💰 Total balance: {token_in_balance / 1e18:.6f}")
        print(f"🔄 Swapping: {swap_amount / 1e18:.6f} ({percentage}%)")
        print(f"💼 Remaining: {remaining_amount / 1e18:.6f} ({100-percentage}%)")
        
        # Prepare swap data
        tokens_to_swap = [token_in]
        swap_balances = {token_in: swap_amount}
        
        # Generate swap calldata
        print("\n📞 Calling Enso API for swap calldata...")
        swap_calldata = await executor.get_enso_liquidation_calldata(
            tokens_to_swap, swap_balances, vault_address
        )
        
        if not swap_calldata:
            print("❌ Failed to generate swap calldata")
            return False
        
        # Build new token list
        new_tokens = []
        
        # Add existing tokens (excluding token_in if selling 100%)
        for token in current_tokens:
            if token.lower() == token_in.lower():
                # Keep token_in only if not selling 100%
                if percentage < 100:
                    new_tokens.append(token)
            else:
                new_tokens.append(token)
        
        # Add token_out if not already in portfolio
        token_out_exists = any(token.lower() == token_out.lower() for token in new_tokens)
        if not token_out_exists:
            new_tokens.append(executor.w3.to_checksum_address(token_out))
        
        print(f"\n📋 New token list ({len(new_tokens)} tokens):")
        for i, token in enumerate(new_tokens, 1):
            print(f"  {i}. {token}")
        
        # Execute the swap
        print(f"\n🚀 Executing swap via Rebalancing.updateTokens...")
        
        success = await executor.execute_rebalancing_update_tokens(
            tokens_to_swap,
            new_tokens,
            swap_balances,
            swap_calldata
        )
        
        if success:
            print(f"\n🎉 Successfully swapped {percentage}% of {token_in[:10]}... to {token_out[:10]}...!")
            return True
        else:
            print(f"\n❌ Token swap failed")
            return False
            
    except Exception as e:
        print(f"❌ Error in token swap: {e}")
        import traceback
        traceback.print_exc()
        return False

async def main():
    """Main execution"""
    try:
        if not TOKEN_IN or not TOKEN_OUT:
            print("⚠️  Please configure the script first:")
            print("1. Set TOKEN_IN address")
            print("2. Set TOKEN_OUT address") 
            print("3. Set PERCENTAGE (1-100)")
            print("\nExample:")
            print('TOKEN_IN = "0x50956c8e46a4f7Dfc7475e3957c162D29b39F75f"')
            print('TOKEN_OUT = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"  # WBNB')
            print('PERCENTAGE = 50  # Sell 50% of the token')
            return
        
        success = await execute_token_swap(TOKEN_IN, TOKEN_OUT, PERCENTAGE)
        
        if success:
            print(f"\n✅ Token swap completed successfully!")
        else:
            print(f"\n❌ Token swap failed")
            
    except Exception as e:
        print(f"❌ Main execution error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
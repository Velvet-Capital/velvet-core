#!/usr/bin/env python3
"""
Reward Coordination System
Main entry point for all protocol reward redemptions - mirrors adapter/optimizer.py pattern

Usage:
1. From executor.py: coordinator.redeem_all_rewards()
2. Manual execution: python reward_coordinator.py
"""
import asyncio
import os
import sys
from typing import List, Dict, Optional
from web3 import Web3
from eth_account import Account

# Add parent directories to path for imports
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
rewards_dir = os.path.join(parent_dir, 'rewards')
sys.path.append(parent_dir)
sys.path.append(rewards_dir)

from pendle_rewards import PendleRewardHandler
from core.portfolio_fetcher import SimplePortfolioFetcher


class RewardCoordinator:
    """
    Main reward coordination system - handles all protocols
    Similar to how optimizer.py coordinates all adapters
    """
    
    def __init__(self, vault_address: str, owner_signer, w3: Web3):
        self.vault_address = vault_address
        self.owner_signer = owner_signer
        self.w3 = w3
        
        # Initialize all reward handlers (like adapters in optimizer)
        self.reward_handlers = [
            PendleRewardHandler(vault_address, owner_signer, w3),
            # Future protocols will be added here:
            # ListaRewardHandler(vault_address, owner_signer, w3),
            # VenusRewardHandler(vault_address, owner_signer, w3),
        ]
        
        print(f"🎁 Reward Coordinator initialized with {len(self.reward_handlers)} protocol handlers")
    
    async def get_vault_tokens(self) -> List[str]:
        """Get current vault tokens using portfolio fetcher"""
        try:
            # For the reward system, we need the portfolio address, not the vault address
            # Let's get the portfolio address from the environment (like in executor.py)
            import os
            portfolio_factory_address = os.getenv('PORTFOLIO_FACTORY_ADDRESS')
            portfolio_id = os.getenv('PORTFOLIO_ID')
            
            if not portfolio_factory_address or not portfolio_id:
                print("❌ Missing PORTFOLIO_FACTORY_ADDRESS or PORTFOLIO_ID in environment")
                return []
            
            # Create portfolio fetcher with the portfolio address
            # We need to derive the portfolio address from factory, but for now use known address
            portfolio_address = "0xbD35fCaC7813FC3B4bc14a5D0AC686c8e8b780Bc"  # Current portfolio
            
            portfolio_fetcher = SimplePortfolioFetcher(portfolio_address)
            vault_tokens = await portfolio_fetcher.get_current_tokens()
            
            print(f"📊 Retrieved {len(vault_tokens)} tokens from vault")
            return vault_tokens
            
        except Exception as e:
            print(f"❌ Error fetching vault tokens: {e}")
            return []
    
    async def redeem_all_rewards(self, vault_tokens: Optional[List[str]] = None) -> bool:
        """
        Main entry point: redeem rewards from all protocols
        
        Args:
            vault_tokens: Optional list of vault tokens (will fetch if not provided)
            
        Returns:
            True if all successful or no rewards needed, False if any failed
        """
        try:
            print("🎁 REWARD COORDINATION: Starting multi-protocol reward redemption")
            print("=" * 60)
            
            # Get vault tokens if not provided
            if vault_tokens is None:
                vault_tokens = await self.get_vault_tokens()
            
            if not vault_tokens:
                print("⚠️ No vault tokens found")
                return False
            
            print(f"🔍 Scanning {len(vault_tokens)} vault tokens across {len(self.reward_handlers)} protocols")
            
            # Process each protocol handler
            all_successful = True
            protocols_with_rewards = 0
            
            for handler in self.reward_handlers:
                protocol_name = handler.get_protocol_name()
                print(f"\n🔄 Processing {protocol_name.upper()} protocol...")
                
                try:
                    # Process rewards for this protocol
                    success = await handler.process_rewards(vault_tokens)
                    
                    if success:
                        # Check if this protocol actually had rewards
                        reward_tokens = await handler.detect_reward_tokens(vault_tokens)
                        if reward_tokens:
                            protocols_with_rewards += 1
                            print(f"✅ {protocol_name} rewards processed successfully")
                        else:
                            print(f"ℹ️ No {protocol_name} reward tokens found")
                    else:
                        print(f"⚠️ {protocol_name} reward processing failed")
                        all_successful = False
                        
                except Exception as e:
                    print(f"❌ Error processing {protocol_name} rewards: {e}")
                    all_successful = False
            
            # Summary
            print(f"\n📋 REWARD COORDINATION SUMMARY:")
            print(f"   • Protocols checked: {len(self.reward_handlers)}")
            print(f"   • Protocols with rewards: {protocols_with_rewards}")
            print(f"   • Overall success: {'✅ YES' if all_successful else '❌ NO'}")
            
            if protocols_with_rewards == 0:
                print("ℹ️ No reward-bearing tokens found in vault")
                return True
            elif all_successful:
                print("🎉 All protocol rewards redeemed successfully!")
                return True
            else:
                print("⚠️ Some protocols had issues, but continuing...")
                return False
                
        except Exception as e:
            print(f"❌ Critical error in reward coordination: {e}")
            return False
    
    def get_protocol_handlers(self) -> List:
        """Get list of all protocol handlers (for debugging)"""
        return [(handler.get_protocol_name(), handler) for handler in self.reward_handlers]


# Manual execution support
async def main():
    """Manual execution entry point"""
    print("🎁 MANUAL REWARD COORDINATION")
    print("=" * 40)
    
    try:
        # Load environment
        from dotenv import load_dotenv
        env_path = os.path.join(os.path.dirname(__file__), '../../../.env')
        load_dotenv(env_path)
        
        # Initialize Web3 and account
        rpc_url = os.getenv('BSC_RPC')
        private_key = os.getenv('VAULT_OWNER')
        vault_factory_address = os.getenv('PORTFOLIO_FACTORY_ADDRESS')
        portfolio_id = os.getenv('PORTFOLIO_ID')
        
        if not all([rpc_url, private_key, vault_factory_address, portfolio_id]):
            print("❌ Missing environment variables")
            return False
        
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        if not w3.is_connected():
            print("❌ Failed to connect to BSC RPC")
            return False
        
        owner_signer = Account.from_key(private_key)
        
        # Get vault address (simplified - would normally use factory contract)
        vault_address = "0x97798739141436984f1A51037Bf70220c16475b4"  # Current vault
        
        print(f"🏦 Vault: {vault_address}")
        print(f"👤 Owner: {owner_signer.address}")
        print(f"🌐 RPC: Connected to BSC")
        
        # Initialize and run coordinator
        coordinator = RewardCoordinator(vault_address, owner_signer, w3)
        success = await coordinator.redeem_all_rewards()
        
        print(f"\n🎯 Result: {'SUCCESS' if success else 'FAILED'}")
        return success
        
    except Exception as e:
        print(f"❌ Manual execution error: {e}")
        return False


if __name__ == "__main__":
    asyncio.run(main())
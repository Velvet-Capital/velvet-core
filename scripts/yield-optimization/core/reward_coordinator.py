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

# Import API adapter for token data
try:
    from adapters.api_adapter import APIAdapter
except ImportError:
    APIAdapter = None


class RewardCoordinator:
    """
    Main reward coordination system - handles all protocols
    Simple direct instance mapping approach
    """
    
    def __init__(self, vault_address: str, owner_signer, w3: Web3):
        self.vault_address = vault_address
        self.owner_signer = owner_signer
        self.w3 = w3
        
        # Direct reward handler instances - simple approach
        self.handlers = {
            'pendle': PendleRewardHandler(vault_address, owner_signer, w3),
            'pendle-yt': PendleRewardHandler(vault_address, owner_signer, w3),
            'pendle-sy': PendleRewardHandler(vault_address, owner_signer, w3),
            'pendle-pt': PendleRewardHandler(vault_address, owner_signer, w3)
        }
        
        # Initialize API adapter for protocol detection (if available)
        self.api_adapter = APIAdapter(chain_id=56) if APIAdapter else None
        
        print(f"🎁 Reward Coordinator initialized with direct handler instances")
        print(f"📊 Available reward protocols: {list(self.handlers.keys())}")
    
    def get_handler_for_protocol(self, protocol: str):
        """Get reward handler for given protocol - simple direct lookup"""
        handler = self.handlers.get(protocol)
        if handler is None:
            print(f"ℹ️  No reward handler available for protocol: {protocol}")
        return handler
    
    async def get_token_protocols(self, token_addresses: List[str], cached_token_data: Optional[List[Dict]] = None) -> Dict[str, str]:
        """Map token addresses to their protocols using cached data or API adapter"""
        token_to_protocol = {}
        
        # Use cached data if available (avoids API call)
        if cached_token_data:
            print("🔍 Using cached token data for protocol detection (no API call needed)")
            api_tokens = cached_token_data
        elif not self.api_adapter:
            print("⚠️  No cached data and API adapter not available, using fallback protocol detection")
            # Fallback: assume all tokens are Pendle for backward compatibility
            for token_addr in token_addresses:
                token_to_protocol[token_addr] = 'pendle'
            return token_to_protocol
        else:
            try:
                print("🔍 No cached data available, fetching from API...")
                # Get all tokens from API to find protocols
                api_tokens = await self.api_adapter.get_tokens()
            except Exception as e:
                print(f"❌ Error fetching from API: {e}")
                # Fallback: assume all are Pendle
                for token_addr in token_addresses:
                    token_to_protocol[token_addr] = 'pendle'
                return token_to_protocol
        
        # Create address to protocol mapping (common logic for both cached and API data)
        try:
            for token_addr in token_addresses:
                found_protocol = None
                for api_token in api_tokens:
                    if api_token['address'].lower() == token_addr.lower():
                        found_protocol = api_token['protocol']
                        break
                
                if found_protocol:
                    token_to_protocol[token_addr] = found_protocol
                    print(f"🔍 Token {token_addr[:10]}... → {found_protocol}")
                else:
                    # Fallback to Pendle for unknown tokens
                    token_to_protocol[token_addr] = 'pendle'
                    print(f"⚠️  Unknown token {token_addr[:10]}..., assuming Pendle")
            
            return token_to_protocol
            
        except Exception as e:
            print(f"❌ Error detecting token protocols: {e}")
            # Fallback: assume all are Pendle
            for token_addr in token_addresses:
                token_to_protocol[token_addr] = 'pendle'
            return token_to_protocol
    
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
    
    async def redeem_all_rewards(self, vault_tokens: Optional[List[str]] = None, cached_token_data: Optional[List[Dict]] = None) -> bool:
        """
        Main entry point: redeem rewards from all protocols
        
        Args:
            vault_tokens: Optional list of vault tokens (will fetch if not provided)
            cached_token_data: Optional cached token data from optimizer (avoids API call)
            
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
            
            print(f"🔍 Analyzing {len(vault_tokens)} vault tokens for protocol detection")
            
            # Detect protocols for each token (use cached data if available)
            token_protocols = await self.get_token_protocols(vault_tokens, cached_token_data)
            
            # Group tokens by protocol
            protocol_tokens = {}
            for token_addr, protocol in token_protocols.items():
                if protocol not in protocol_tokens:
                    protocol_tokens[protocol] = []
                protocol_tokens[protocol].append(token_addr)
            
            print(f"📊 Found tokens across {len(protocol_tokens)} protocols:")
            for protocol, tokens in protocol_tokens.items():
                print(f"   • {protocol}: {len(tokens)} tokens")
            
            # Process each protocol with its tokens
            all_successful = True
            protocols_with_rewards = 0
            
            for protocol, protocol_token_list in protocol_tokens.items():
                print(f"\n🔄 Processing {protocol.upper()} protocol...")
                
                # Get handler for this protocol
                handler = self.get_handler_for_protocol(protocol)
                if not handler:
                    print(f"ℹ️  Skipping {protocol} (no reward handler available)")
                    continue
                
                try:
                    # Process rewards for this protocol's tokens only
                    success = await handler.process_rewards(protocol_token_list)
                    
                    if success:
                        # Check if this protocol actually had rewards
                        reward_tokens = await handler.detect_reward_tokens(protocol_token_list)
                        if reward_tokens:
                            protocols_with_rewards += 1
                            print(f"✅ {protocol} rewards processed successfully")
                        else:
                            print(f"ℹ️ No {protocol} reward tokens found")
                    else:
                        print(f"⚠️ {protocol} reward processing failed")
                        all_successful = False
                        
                except Exception as e:
                    print(f"❌ Error processing {protocol} rewards: {e}")
                    all_successful = False
            
            # Summary
            print(f"\n📋 REWARD COORDINATION SUMMARY:")
            print(f"   • Protocols detected: {len(protocol_tokens)}")
            print(f"   • Protocols with handlers: {len([p for p in protocol_tokens.keys() if self.handlers.get(p)])}")
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
        """Get list of active protocol handlers (for debugging)"""
        return [(protocol, handler) for protocol, handler in self.handlers.items()]
    
    def get_supported_protocols(self) -> List[str]:
        """Get list of protocols with reward handler support"""
        return list(self.handlers.keys())


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
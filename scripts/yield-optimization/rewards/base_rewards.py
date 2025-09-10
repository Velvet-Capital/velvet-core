#!/usr/bin/env python3
"""
Base reward handler class - template for all protocol reward handlers
Similar to base_adapter.py pattern
"""
from abc import ABC, abstractmethod
from typing import List, Dict, Optional
from web3 import Web3


class BaseRewardHandler(ABC):
    """Base class for all protocol reward handlers"""
    
    def __init__(self, vault_address: str, owner_signer, w3: Web3):
        self.vault_address = vault_address
        self.owner_signer = owner_signer
        self.w3 = w3
    
    @abstractmethod
    def get_protocol_name(self) -> str:
        """Return protocol name (e.g., 'pendle', 'lista', 'venus')"""
        pass
    
    @abstractmethod
    async def detect_reward_tokens(self, vault_tokens: List[str]) -> Dict[str, dict]:
        """
        Detect which vault tokens belong to this protocol and need reward redemption
        
        Args:
            vault_tokens: List of token addresses in the vault
            
        Returns:
            Dict mapping token addresses to their reward configuration
        """
        pass
    
    @abstractmethod
    async def redeem_rewards(self, reward_tokens: Dict[str, dict]) -> bool:
        """
        Redeem rewards for the detected tokens
        
        Args:
            reward_tokens: Output from detect_reward_tokens()
            
        Returns:
            True if successful, False otherwise
        """
        pass
    
    async def process_rewards(self, vault_tokens: List[str]) -> bool:
        """
        Main entry point: detect tokens and redeem rewards if needed
        
        Args:
            vault_tokens: List of token addresses in the vault
            
        Returns:
            True if successful or no rewards needed, False on error
        """
        try:
            protocol_name = self.get_protocol_name()
            print(f"🔍 Checking {protocol_name} rewards...")
            
            # Detect reward tokens for this protocol
            reward_tokens = await self.detect_reward_tokens(vault_tokens)
            
            if not reward_tokens:
                print(f"✅ No {protocol_name} reward tokens found")
                return True
            
            print(f"🎁 Found {len(reward_tokens)} {protocol_name} reward tokens")
            
            # Redeem rewards
            success = await self.redeem_rewards(reward_tokens)
            
            if success:
                print(f"✅ {protocol_name} reward redemption completed successfully")
            else:
                print(f"⚠️ {protocol_name} reward redemption had issues")
            
            return success
            
        except Exception as e:
            print(f"❌ Error processing {self.get_protocol_name()} rewards: {e}")
            return False
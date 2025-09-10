from abc import ABC, abstractmethod
from typing import List, Dict
import asyncio
import aiohttp

class BaseAdapter(ABC):
    """Simple base adapter interface - minimal and clean"""
    
    def __init__(self, chain_id: int = 56):
        self.chain_id = chain_id
        self.protocol_name = self.get_protocol_name()
    
    @abstractmethod
    def get_protocol_name(self) -> str:
        """Return protocol name (e.g., 'pendle', 'pancakeswap')"""
        pass
    
    @abstractmethod 
    async def get_tokens(self) -> List[Dict]:
        """Get available tokens with basic info
        Returns: [{'address': '0x...', 'symbol': 'PT-ETH', 'apy': 0.25}]
        """
        pass
    
    async def check_price_impact(self, token_address: str, amount_usd: float = 2500) -> float:
        """Check price impact using Enso API with proper parameters"""
        try:
            # Use exactly 2 BNB = 2 * 10^18 wei as requested
            amount_in_wei = str(2 * 10**18)  # 2 BNB in wei
            
            # Use same format as your example
            params = {
                'chainId': self.chain_id,
                'fromAddress': '0x69a7700c676Bd1d7156565dAC011BFd5Eb98b30d',  # Example vault address
                'receiver': '0x69a7700c676Bd1d7156565dAC011BFd5Eb98b30d',
                'spender': '0x69a7700c676Bd1d7156565dAC011BFd5Eb98b30d', 
                'amountIn': amount_in_wei,
                'slippage': '700',  # 7%
                'tokenIn': '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',  # BNB
                'tokenOut': token_address,
                'routingStrategy': 'delegate'
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.get('https://api.enso.finance/api/v1/shortcuts/route', 
                                     params=params) as response:
                    if response.status == 200:
                        data = await response.json()
                        price_impact_bps = data.get('priceImpact', None)
                        if price_impact_bps is not None:
                            # Convert from basis points to decimal (10000 bps = 100% = 1.0)
                            return price_impact_bps / 10000.0
            
            # If API fails or no priceImpact field, return high impact to exclude token
            return 0.05  # 5% - will be filtered out
            
        except Exception as e:
            # If any error, return high impact to exclude token  
            return 0.05
    
    async def get_tokens_with_impact(self) -> List[Dict]:
        """Get tokens with price impact filtering - simple and effective"""
        tokens = await self.get_tokens()
        enhanced_tokens = []
        
        for token in tokens:
            impact = await self.check_price_impact(token['address'])
            if impact < 0.02:  # Only liquid tokens (< 2% impact)
                token['price_impact'] = impact
                token['protocol'] = self.protocol_name
                enhanced_tokens.append(token)
        
        return enhanced_tokens
import asyncio
import aiohttp
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional
try:
    from .base_adapter import BaseAdapter
except ImportError:
    from base_adapter import BaseAdapter

logger = logging.getLogger(__name__)

class PendleAdapter(BaseAdapter):
    """Simple Pendle adapter - migrated from strategy.py"""
    
    def __init__(self, chain_id: int = 56):
        super().__init__(chain_id)
        self.market_addresses = [
            "0xbd577ddabb5a1672d3c786726b87a175de652b96",
            "0x7608eb2fc533343556e443511a2747f605e49c9b"
        ]
    
    def get_protocol_name(self) -> str:
        return "pendle"
    
    async def fetch_market_data(self, market_address: str) -> Optional[Dict]:
        """Fetch market data from Pendle API"""
        url = f"https://api-v2.pendle.finance/core/v1/{self.chain_id}/markets/{market_address}"
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url) as response:
                    if response.status == 200:
                        return await response.json()
                    return None
        except Exception as e:
            logger.error(f"Failed to fetch market data: {e}")
            return None
    
    def calculate_pt_apy(self, market_data: Dict) -> float:
        """Calculate PT APY using impliedApy from API"""
        try:
            # Use impliedApy which is the actual annualized APY for PT holders
            implied_apy = market_data.get('impliedApy', 0)
            return max(0, implied_apy)
        except:
            return 0
    
    def calculate_yt_apy(self, market_data: Dict) -> float:
        """Calculate YT APY using ytRoi from API"""
        try:
            yt_roi = market_data.get('ytRoi', 0)
            if yt_roi <= 0:
                return 0
            
            # Get days to maturity
            expiry_str = market_data.get('expiry', '')
            if expiry_str:
                expiry_date = datetime.fromisoformat(expiry_str.replace('Z', '+00:00'))
                days_to_maturity = max(1, (expiry_date - datetime.now(timezone.utc)).days)
                years_to_expiry = days_to_maturity / 365
            else:
                years_to_expiry = 1.0
                
            # Convert period return to annualized APY
            if years_to_expiry > 0:
                annualized_apy = ((1 + yt_roi) ** (1/years_to_expiry)) - 1
                return max(0, min(annualized_apy, 5.0))
            return 0
        except:
            return 0
    
    def calculate_lp_apy(self, market_data: Dict) -> float:
        """Calculate LP APY from aggregated APY"""
        try:
            return max(0, market_data.get('aggregatedApy', 0))
        except:
            return 0
    
    async def get_tokens(self) -> List[Dict]:
        """Get all Pendle tokens with APY - simple format"""
        tokens = []
        
        for market_address in self.market_addresses:
            market_data = await self.fetch_market_data(market_address)
            if not market_data:
                continue

            # Check liquidity instead of TVL
            liquidity_usd = market_data.get('liquidity', {}).get('usd', 0)
            if liquidity_usd < 100000:  # Skip if liquidity < 100k USD
                continue
            
            # Calculate APYs for each token type
            pt_apy = self.calculate_pt_apy(market_data)
            yt_apy = self.calculate_yt_apy(market_data)
            lp_apy = self.calculate_lp_apy(market_data)
            
            # Get token addresses
            pt_address = market_data.get('pt', {}).get('address', market_address)
            yt_address = market_data.get('yt', {}).get('address', market_address)
            lp_address = market_data.get('lp', {}).get('address', market_address)
            
            # Add tokens with positive APY
            if pt_apy > 0:
                tokens.append({
                    'address': pt_address,
                    'symbol': f"PT-{market_data.get('underlyingAsset', {}).get('symbol', 'TOKEN')}",
                    'apy': pt_apy,
                    'type': 'PT',
                    'market_address': market_address
                })
            
            if yt_apy > 0:
                tokens.append({
                    'address': yt_address,
                    'symbol': f"YT-{market_data.get('underlyingAsset', {}).get('symbol', 'TOKEN')}", 
                    'apy': yt_apy,
                    'type': 'YT',
                    'market_address': market_address
                })
            
            if lp_apy > 5:
                tokens.append({
                    'address': lp_address,
                    'symbol': f"LP-{market_data.get('underlyingAsset', {}).get('symbol', 'TOKEN')}",
                    'apy': lp_apy,
                    'type': 'LP', 
                    'market_address': market_address
                })
        
        return tokens
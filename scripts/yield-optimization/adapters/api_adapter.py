import asyncio
import aiohttp
import logging
from typing import Dict, List, Optional
try:
    from .base_adapter import BaseAdapter
except ImportError:
    from base_adapter import BaseAdapter

logger = logging.getLogger(__name__)

# Import reward handlers for mapping
try:
    import sys
    import os
    # Add rewards directory to path
    rewards_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'rewards')
    if rewards_dir not in sys.path:
        sys.path.append(rewards_dir)
    
    from pendle_rewards import PendleRewardHandler
except ImportError:
    PendleRewardHandler = None
    logger.warning("Could not import PendleRewardHandler")

# Token Classification Constants - Moved from optimizer.py for consolidated filtering
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

# Reward handler mapping moved to reward_coordinator.py for cleaner separation

class APIAdapter(BaseAdapter):
    """Universal adapter using Velvet API for all yield protocols"""
    
    def __init__(self, chain_id: int = 56, min_liquidity: Optional[float] = None, 
                 min_apy: Optional[float] = None, protocols: Optional[List[str]] = None,
                 token_search: Optional[str] = None, non_yield_tokens: Optional[set] = None,
                 ignored_tokens: Optional[set] = None):
        """
        Initialize APIAdapter with optional filters (all 6 filters consolidated)
        
        Args:
            chain_id: Blockchain chain ID (default: 56 for BSC)
            min_liquidity: Minimum liquidity in USD (e.g., 100000)
            min_apy: Minimum APY as decimal (e.g., 0.05 for 5%)
            protocols: List of protocols to include (e.g., ["pendle", "lista"])
            token_search: Search term for token name/symbol (e.g., "BNB")
            non_yield_tokens: Set of non-yield token addresses (whitelist)
            ignored_tokens: Set of token addresses to exclude (blacklist)
        """
        super().__init__(chain_id)
        self.min_liquidity = min_liquidity
        self.min_apy = min_apy
        self.protocols = protocols
        self.token_search = token_search
        self.non_yield_tokens = non_yield_tokens or NON_YIELD_TOKENS
        self.ignored_tokens = ignored_tokens or IGNORED_YIELD_TOKENS
        
        # API endpoint
        self.api_url = f"https://api.velvet.capital/api/v3/token/lp?tag=yield&chainID={chain_id}"
        
        logger.info(f"🔌 APIAdapter initialized with 6 consolidated filters:")
        logger.info(f"   - Min liquidity: {self.min_liquidity}")
        logger.info(f"   - Min APY: {self.min_apy}")
        logger.info(f"   - Protocols: {self.protocols}")
        logger.info(f"   - Token search: {self.token_search}")
        logger.info(f"   - Non-yield tokens: {len(self.non_yield_tokens)} addresses")
        logger.info(f"   - Ignored tokens: {len(self.ignored_tokens)} addresses")
    
    def get_protocol_name(self) -> str:
        return "api"
    
    def token_matches_search(self, token: Dict, search_term: str) -> bool:
        """Enhanced token search with pattern matching"""
        name = token.get('name', '').lower()
        symbol = token.get('symbol', '').lower()
        search_term = search_term.lower()
        
        # Direct substring matches (original logic)
        if search_term in name or search_term in symbol:
            return True
        
        # Enhanced pattern matching for common token types
        if search_term == 'bnb':
            # Handle BNB variations: wbnb, clisbnb, lisbnb, sbnb, ynbnbx, etc.
            bnb_patterns = ['bnb', 'wbnb', 'clisbnb', 'lisbnb', 'sbnb', 'ynbnb']
            if any(pattern in name or pattern in symbol for pattern in bnb_patterns):
                return True
        
        elif search_term == 'usdt':
            # Handle USDT variations: usdt, busdt, lisusdt, etc.
            usdt_patterns = ['usdt', 'busdt', 'lisusdt', 'mevusdt']
            if any(pattern in name or pattern in symbol for pattern in usdt_patterns):
                return True
        
        elif search_term == 'usdc':
            # Handle USDC variations: usdc, eusdc, etc.
            usdc_patterns = ['usdc', 'eusdc']
            if any(pattern in name or pattern in symbol for pattern in usdc_patterns):
                return True
        
        elif search_term == 'btc':
            # Handle BTC variations: btc, wbtc, solvbtc, ebtc, etc.
            btc_patterns = ['btc', 'wbtc', 'solvbtc', 'ebtc']
            if any(pattern in name or pattern in symbol for pattern in btc_patterns):
                return True
        
        # Default: no match
        return False
    
    async def fetch_api_data(self, max_retries: int = 3, timeout_seconds: int = 30) -> Optional[List[Dict]]:
        """Fetch token data from Velvet API with timeout and retry logic"""
        print(f"🌐 Fetching data from Velvet API (timeout: {timeout_seconds}s, max retries: {max_retries})")
        
        for attempt in range(max_retries):
            try:
                # Create session with timeout
                timeout = aiohttp.ClientTimeout(total=timeout_seconds)
                async with aiohttp.ClientSession(timeout=timeout) as session:
                    print(f"📡 API request attempt {attempt + 1}/{max_retries}")
                    
                    async with session.get(self.api_url) as response:
                        if response.status == 200:
                            print("✅ API response received, parsing JSON...")
                            data = await response.json()
                            token_count = len(data.get('data', []))
                            print(f"📊 Parsed {token_count} tokens from API")
                            return data.get('data', [])
                        else:
                            print(f"❌ API request failed with status {response.status}")
                            if attempt == max_retries - 1:
                                logger.error(f"API request failed with status {response.status} after {max_retries} attempts")
                            
            except asyncio.TimeoutError:
                print(f"⏰ API request timeout (attempt {attempt + 1}/{max_retries})")
                if attempt == max_retries - 1:
                    logger.error(f"API request timed out after {max_retries} attempts")
                else:
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
                    
            except Exception as e:
                print(f"❌ API request error (attempt {attempt + 1}/{max_retries}): {e}")
                if attempt == max_retries - 1:
                    logger.error(f"Failed to fetch API data after {max_retries} attempts: {e}")
                else:
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
        
        print("🚫 All API attempts failed, returning None")
        return None
    
    def apply_filters(self, tokens: List[Dict]) -> List[Dict]:
        """Apply configured filters to token list"""
        filtered_tokens = tokens.copy()
        
        # Filter by liquidity
        if self.min_liquidity is not None:
            initial_count = len(filtered_tokens)
            filtered_tokens = [t for t in filtered_tokens if t.get('liquidity', 0) >= self.min_liquidity]
            if len(filtered_tokens) < initial_count:
                logger.info(f"📊 Liquidity filter: {initial_count} → {len(filtered_tokens)} tokens")
        
        # Filter by APY
        if self.min_apy is not None:
            initial_count = len(filtered_tokens)
            filtered_tokens = [
                t for t in filtered_tokens 
                if float(t.get('metrics', {}).get('apy', '0')) / 100 >= self.min_apy
            ]
            if len(filtered_tokens) < initial_count:
                logger.info(f"📊 APY filter: {initial_count} → {len(filtered_tokens)} tokens")
        
        # Filter by protocols
        if self.protocols:
            initial_count = len(filtered_tokens)
            filtered_tokens = [t for t in filtered_tokens if t.get('platform') in self.protocols]
            if len(filtered_tokens) < initial_count:
                logger.info(f"📊 Protocol filter: {initial_count} → {len(filtered_tokens)} tokens")
        
        # Filter by enhanced token search
        if self.token_search:
            initial_count = len(filtered_tokens)
            filtered_tokens = [
                t for t in filtered_tokens 
                if self.token_matches_search(t, self.token_search)
            ]
            if len(filtered_tokens) < initial_count:
                logger.info(f"📊 Enhanced token search filter ({self.token_search}): {initial_count} → {len(filtered_tokens)} tokens")
        
        # Filter out blacklisted tokens (ignored tokens)
        if self.ignored_tokens:
            initial_count = len(filtered_tokens)
            filtered_tokens = [
                t for t in filtered_tokens 
                if t.get('address', '').lower() not in {addr.lower() for addr in self.ignored_tokens}
            ]
            if len(filtered_tokens) < initial_count:
                ignored_count = initial_count - len(filtered_tokens)
                logger.info(f"📊 Blacklist filter: {initial_count} → {len(filtered_tokens)} tokens ({ignored_count} ignored)")
        
        # Note: Non-yield tokens are handled differently - they're allowed but marked with 0% APY
        # This happens during standardization process, not filtering
        
        return filtered_tokens
    
    async def get_tokens(self) -> List[Dict]:
        """Get yield tokens from Velvet API with filtering and fallback"""
        print("🔍 APIAdapter.get_tokens() starting...")
        
        try:
            # Fetch data from API
            print("📡 Step 1: Fetching data from Velvet API...")
            api_tokens = await self.fetch_api_data()
            if not api_tokens:
                print("⚠️ No data received from Velvet API, trying fallback...")
                return await self.get_fallback_tokens()
            
            print(f"📊 Step 2: Applying filters to {len(api_tokens)} tokens...")
            
            # Apply filters
            filtered_tokens = self.apply_filters(api_tokens)
            print(f"🔍 Step 3: After filtering - {len(filtered_tokens)} tokens remain")
            
            # Convert to standard adapter format
            print(f"📊 Step 4: Converting {len(filtered_tokens)} tokens to standard format...")
            standardized_tokens = []
            
            for i, token in enumerate(filtered_tokens):
                try:
                    # Progress logging for large datasets
                    if i % 10 == 0 and i > 0:
                        print(f"   Processing token {i+1}/{len(filtered_tokens)}...")
                    
                    # Convert APY from string percentage to decimal
                    apy_str = token.get('metrics', {}).get('apy', '0')
                    apy_decimal = float(apy_str) / 100  # "12.806" → 0.12806
                    
                    # Handle non-yield tokens (override APY to 0% for known non-yield tokens)
                    token_address = token.get('address', '').lower()
                    if token_address in {addr.lower() for addr in self.non_yield_tokens}:
                        apy_decimal = 0.0
                        print(f"      🔒 {token.get('symbol', 'Unknown')} identified as non-yield token (0% APY)")
                    
                    # Skip tokens with zero or negative APY (unless they're explicitly non-yield tokens)
                    elif apy_decimal <= 0:
                        continue
                    
                    standardized_token = {
                        'address': token.get('address', ''),
                        'symbol': token.get('symbol', ''),
                        'apy': apy_decimal,
                        'protocol': token.get('platform', 'unknown'),
                        'liquidity_usd': token.get('liquidity', 0),
                        'name': token.get('name', ''),
                        'api_token_id': token.get('tokenId', ''),
                        # Add metadata for debugging
                        'api_data': {
                            'baseApy': token.get('metrics', {}).get('baseApy', '0'),
                            'totalSupply': token.get('totalSupply', '0'),
                            'pricePerShare': token.get('pricePerShare', '1')
                        }
                    }
                    
                    standardized_tokens.append(standardized_token)
                    logger.debug(f"   📊 {standardized_token['symbol']}: {standardized_token['apy']:.2%} APY")
                    
                except Exception as e:
                    logger.warning(f"Failed to process token {token.get('symbol', 'Unknown')}: {e}")
                    continue
            
            print(f"✅ Step 5: Successfully standardized {len(standardized_tokens)} tokens for optimizer")
            return standardized_tokens
            
        except Exception as e:
            print(f"❌ Critical error in get_tokens(): {e}")
            logger.error(f"Critical error in get_tokens(): {e}")
            print("🔄 Trying fallback token source...")
            return await self.get_fallback_tokens()
    
    async def get_fallback_tokens(self) -> List[Dict]:
        """Fallback token list when API is unavailable"""
        print("🚨 Using fallback token list (hardcoded high-APY tokens)")
        
        # Hardcoded fallback tokens with known good performance
        fallback_tokens = [
            {
                'address': '0x27faf900007b4cba7803000251ec96bc69ff1bea',  # SY-CLISBNB
                'symbol': 'SY-CLISBNB',
                'apy': 0.10,  # Conservative estimate
                'protocol': 'pendle-sy',
                'liquidity_usd': 18000000,
                'name': 'SY Lista collateral BNB',
                'api_token_id': 'fallback-1'
            },
            {
                'address': '0x7608eb2fc533343556e443511a2747f605e49c9b',  # PT Token
                'symbol': 'PT-CLISBNB',
                'apy': 0.12,  # Conservative estimate
                'protocol': 'pendle-pt',
                'liquidity_usd': 15000000,
                'name': 'PT Lista collateral BNB',
                'api_token_id': 'fallback-2'
            },
            # Add more fallback tokens as needed
        ]
        
        # Apply filters to fallback tokens as well
        filtered_fallback = self.apply_filters(fallback_tokens)
        
        print(f"🔄 Fallback: returning {len(filtered_fallback)} tokens")
        return filtered_fallback


# Test function removed - production code only
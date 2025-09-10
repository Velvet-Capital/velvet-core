#!/usr/bin/env python3
"""
Pendle Protocol Reward Handler
Handles reward redemption for Pendle PT, SY, and YT tokens using Pendle API
"""
import asyncio
import aiohttp
import sys
import os
from typing import List, Dict, Optional
from web3 import Web3
from base_rewards import BaseRewardHandler

# Import PendleAdapter for dynamic token discovery
adapters_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'adapters')
sys.path.append(adapters_path)
sys.path.append(os.path.dirname(adapters_path))  # Add parent for base_adapter import

from pendle_adapter import PendleAdapter

# Pendle API configuration
PENDLE_API_BASE = "https://api-v2.pendle.finance/core/v1"
PENDLE_ROUTER_ADDRESS = "0x888888888889758f76e7103c6cbf23abbf58f946"

# Pendle Router ABI for reward redemption
PENDLE_ROUTER_ABI = [
    {
        "inputs": [
            {"name": "SYs", "type": "address[]"},
            {"name": "YTs", "type": "tuple[]", "components": [
                {"name": "yt", "type": "address"},
                {"name": "doRedeemInterest", "type": "bool"},
                {"name": "doRedeemRewards", "type": "bool"},
                {"name": "tokenRedeemSy", "type": "address"},
                {"name": "minTokenRedeemOut", "type": "uint256"}
            ]},
            {"name": "markets", "type": "address[]"},
            {"name": "pendleSwap", "type": "address"},
            {"name": "swaps", "type": "tuple[]", "components": [
                {"name": "tokenIn", "type": "address"},
                {"name": "tokenOut", "type": "address"},
                {"name": "minOut", "type": "uint256"},
                {"name": "swapData", "type": "tuple", "components": [
                    {"name": "swapType", "type": "uint8"},
                    {"name": "extRouter", "type": "address"},
                    {"name": "extCalldata", "type": "bytes"},
                    {"name": "needScale", "type": "bool"}
                ]}
            ]}
        ],
        "name": "redeemDueInterestAndRewardsV2",
        "outputs": [
            {"name": "netOutFromSwaps", "type": "uint256[]"},
            {"name": "netInterests", "type": "uint256[]"}
        ],
        "type": "function"
    }
]

# Gnosis Safe ABI for transaction execution
GNOSIS_SAFE_ABI = [
    {
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "value", "type": "uint256"},
            {"name": "data", "type": "bytes"},
            {"name": "operation", "type": "uint8"},
            {"name": "safeTxGas", "type": "uint256"},
            {"name": "baseGas", "type": "uint256"},
            {"name": "gasPrice", "type": "uint256"},
            {"name": "gasToken", "type": "address"},
            {"name": "refundReceiver", "type": "address"},
            {"name": "signatures", "type": "bytes"}
        ],
        "name": "execTransaction",
        "outputs": [{"name": "success", "type": "bool"}],
        "type": "function"
    },
    {
        "inputs": [{"name": "owner", "type": "address"}],
        "name": "isOwner",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getThreshold",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function"
    },
    {
        "inputs": [],
        "name": "nonce",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function"
    },
    {
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "value", "type": "uint256"},
            {"name": "data", "type": "bytes"},
            {"name": "operation", "type": "uint8"},
            {"name": "safeTxGas", "type": "uint256"},
            {"name": "baseGas", "type": "uint256"},
            {"name": "gasPrice", "type": "uint256"},
            {"name": "gasToken", "type": "address"},
            {"name": "refundReceiver", "type": "address"},
            {"name": "_nonce", "type": "uint256"}
        ],
        "name": "getTransactionHash",
        "outputs": [{"name": "", "type": "bytes32"}],
        "type": "function"
    }
]


async def call_pendle_api(receiver: str, sys: List[str], yts: List[str], markets: List[str], chain_id: int = 56) -> Optional[Dict]:
    """
    Call Pendle API to get reward redemption transaction data
    
    Args:
        receiver: Vault address to receive rewards
        sys: List of SY token addresses  
        yts: List of YT token addresses
        markets: List of market addresses
        chain_id: Chain ID (56 for BSC)
        
    Returns:
        API response with transaction data or None if failed
    """
    try:
        # Build API URL
        url = f"{PENDLE_API_BASE}/sdk/{chain_id}/redeem-interests-and-rewards"
        
        # Build query parameters - use comma-separated strings for multiple values
        params = {
            'receiver': receiver
        }
        
        # Add SY tokens as comma-separated string
        if sys:
            params['sys'] = ','.join(sys)
            
        # Add YT tokens as comma-separated string
        if yts:
            params['yts'] = ','.join(yts)
            
        # Add markets as comma-separated string
        if markets:
            params['markets'] = ','.join(markets)
        
        print(f"📞 Calling Pendle API: {len(sys)} SY, {len(yts)} YT, {len(markets)} markets")
        
        async with aiohttp.ClientSession() as session:
            async with session.get(url, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"✅ Pendle API response received: method={data.get('method')}")
                    return data
                else:
                    error_text = await response.text()
                    print(f"❌ Pendle API error: {response.status}")
                    print(f"   URL: {response.url}")
                    print(f"   Response: {error_text[:200]}...")
                    return None
                    
    except Exception as e:
        print(f"❌ Error calling Pendle API: {e}")
        return None


class PendleRewardHandler(BaseRewardHandler):
    """Pendle-specific reward redemption handler with dynamic token discovery"""
    
    def __init__(self, vault_address: str, owner_signer, w3: Web3):
        super().__init__(vault_address, owner_signer, w3)
        self.gnosis_safe = w3.eth.contract(address=vault_address, abi=GNOSIS_SAFE_ABI)
        self.pendle_adapter = PendleAdapter(chain_id=56)  # Initialize adapter
    
    def get_protocol_name(self) -> str:
        return "pendle"
    
    async def detect_reward_tokens(self, vault_tokens: List[str]) -> Dict[str, dict]:
        """Detect which vault tokens are Pendle reward-bearing tokens using adapter"""
        try:
            print("🔍 Getting Pendle tokens from adapter...")
            
            # Get all Pendle tokens from adapter (calls live Pendle API)
            pendle_tokens = await self.pendle_adapter.get_tokens()
            print(f"📊 Adapter returned {len(pendle_tokens)} Pendle tokens from {len(self.pendle_adapter.market_addresses)} markets")
            
            # Build token → market mapping
            pendle_token_map = {}
            for token_info in pendle_tokens:
                token_address = token_info['address']
                pendle_token_map[token_address.lower()] = {
                    'address': token_address,
                    'market_address': token_info['market_address'],
                    'type': token_info['type'],  # PT, YT, LP
                    'symbol': token_info['symbol'],
                    'protocol': 'pendle'
                }
            
            # Check which vault tokens are Pendle tokens
            reward_tokens_found = {}
            for vault_token in vault_tokens:
                vault_token_lower = vault_token.lower()
                if vault_token_lower in pendle_token_map:
                    reward_tokens_found[vault_token] = pendle_token_map[vault_token_lower]
                    token_info = pendle_token_map[vault_token_lower]
                    print(f"📋 Found Pendle {token_info['type']} token: {token_info['symbol']} ({vault_token})")
            
            return reward_tokens_found
            
        except Exception as e:
            print(f"❌ Error in dynamic token detection: {e}")
            return {}
    
    async def redeem_rewards(self, reward_tokens: Dict[str, dict]) -> bool:
        """Redeem rewards for ALL detected Pendle tokens using API"""
        try:
            if not reward_tokens:
                return True
                
            print(f"🎯 Redeeming Pendle rewards for {len(reward_tokens)} tokens using API...")
            
            # Group tokens by market for batch processing
            markets_data = {}
            
            for token_address, token_info in reward_tokens.items():
                market_address = token_info['market_address']
                
                if market_address not in markets_data:
                    markets_data[market_address] = {
                        'market': market_address,
                        'sy_tokens': [],
                        'yt_tokens': [],
                        'pt_tokens': [],
                        'tokens': []
                    }
                
                # Add token to appropriate category
                token_type = token_info['type']
                markets_data[market_address]['tokens'].append(token_address)
                
                if token_type == 'PT':
                    markets_data[market_address]['pt_tokens'].append(token_address)
                elif token_type == 'YT':
                    markets_data[market_address]['yt_tokens'].append(token_address)
                # Note: For SY tokens, we need to get the actual SY address from market data
            
            print(f"📊 Processing {len(markets_data)} markets with tokens")
            
            # For API call, we need actual SY and YT addresses from market data
            # Get market data for each market to find SY/YT addresses
            sy_tokens = []
            yt_tokens = []
            markets = list(markets_data.keys())
            
            for market_address in markets:
                try:
                    # Call adapter to get market data
                    market_data = await self.pendle_adapter.fetch_market_data(market_address)
                    if market_data:
                        # Get SY and YT addresses from market data
                        sy_address = market_data.get('sy', {}).get('address')
                        yt_address = market_data.get('yt', {}).get('address')
                        
                        if sy_address and sy_address not in sy_tokens:
                            sy_tokens.append(sy_address)
                        # if yt_address and yt_address not in yt_tokens:
                        #     yt_tokens.append(yt_address)
                            
                        print(f"📋 Market {market_address}: SY={sy_address}, YT={yt_address}")
                    
                except Exception as e:
                    print(f"⚠️ Error fetching market data for {market_address}: {e}")
            
            print(f"📊 API parameters: {len(sy_tokens)} SY, {len(yt_tokens)} YT, {len(markets)} markets")
            
            # Only call API if we have some valid tokens to process
            if not sy_tokens and not yt_tokens and not markets:
                print("⚠️ No valid token mappings found for API call")
                return True  # Don't fail the whole process for unmapped tokens
            
            # Call Pendle API to get redemption transaction data
            api_response = await call_pendle_api(
                receiver=self.vault_address,
                sys=sy_tokens,
                yts=yt_tokens,
                markets=markets,
                chain_id=56
            )
            
            if not api_response:
                print("❌ Failed to get redemption data from Pendle API")
                return False
            
            # Extract transaction data
            tx_data = api_response.get('tx', {})
            target_address = tx_data.get('to', PENDLE_ROUTER_ADDRESS)
            calldata = tx_data.get('data')
            
            if not calldata:
                print("❌ No calldata received from Pendle API")
                return False
                
            print(f"📄 Received calldata from API: {len(calldata)} characters")
            
            # Execute via Gnosis Safe
            calldata_bytes = bytes.fromhex(calldata[2:])  # Remove 0x prefix
            return await self.execute_via_gnosis_safe(target_address, calldata_bytes)
            
        except Exception as e:
            print(f"❌ Error redeeming Pendle rewards via API: {e}")
            return False
    
    async def execute_via_gnosis_safe(self, target_address: str, calldata: bytes) -> bool:
        """Execute reward redemption transaction via Gnosis Safe"""
        try:
            print(f"🔐 Executing via Gnosis Safe...")
            print(f"📍 Target: {target_address}")
            print(f"📄 Calldata: {len(calldata)} bytes")
            
            # Check Gnosis Safe configuration
            is_owner = self.gnosis_safe.functions.isOwner(self.owner_signer.address).call()
            threshold = self.gnosis_safe.functions.getThreshold().call()
            current_nonce = self.gnosis_safe.functions.nonce().call()
            
            print(f"👤 Is owner: {is_owner}")
            print(f"🔢 Threshold: {threshold}")
            print(f"🆔 Nonce: {current_nonce}")
            
            if not is_owner:
                print("❌ Not a Gnosis Safe owner - cannot execute")
                return False
                
            if threshold != 1:
                print("❌ Multi-sig threshold > 1 not supported")
                return False
            
            # Generate transaction hash for signing
            tx_hash = self.gnosis_safe.functions.getTransactionHash(
                self.w3.to_checksum_address(target_address),  # to
                0,                                           # value
                calldata,                                    # data
                0,                                          # operation (CALL)
                0,                                          # safeTxGas
                0,                                          # baseGas
                0,                                          # gasPrice
                '0x0000000000000000000000000000000000000000',  # gasToken
                '0x0000000000000000000000000000000000000000',  # refundReceiver
                current_nonce                               # nonce
            ).call()
            
            print(f"📝 Transaction hash: {tx_hash.hex()}")
            
            # Sign the transaction hash
            from eth_account.messages import encode_defunct
            message = encode_defunct(tx_hash)
            signature = self.owner_signer.sign_message(message)
            
            # Adjust signature for Gnosis Safe format (add 4 to v value)
            sig_bytes = signature.signature
            adjusted_sig = sig_bytes[:-1] + bytes([sig_bytes[-1] + 4])
            
            print("✍️ Transaction signed")
            
            # Execute the transaction
            print("🚀 Submitting transaction...")
            
            execute_tx = self.gnosis_safe.functions.execTransaction(
                self.w3.to_checksum_address(target_address),  # to
                0,                                           # value
                calldata,                                    # data
                0,                                          # operation
                0,                                          # safeTxGas
                0,                                          # baseGas
                0,                                          # gasPrice
                '0x0000000000000000000000000000000000000000',  # gasToken
                '0x0000000000000000000000000000000000000000',  # refundReceiver
                adjusted_sig                                # signatures
            ).build_transaction({
                'from': self.owner_signer.address,
                'nonce': self.w3.eth.get_transaction_count(self.owner_signer.address),
                'gas': 5000000,  # High gas limit for complex operation
                'gasPrice': self.w3.eth.gas_price
            })
            
            # Sign and send transaction
            signed_tx = self.owner_signer.sign_transaction(execute_tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            
            print(f"📤 Transaction sent: {tx_hash.hex()}")
            
            # Wait for confirmation
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            
            if receipt.status == 1:
                print(f"✅ Pendle reward redemption successful!")
                print(f"⛽ Gas used: {receipt.gasUsed:,}")
                return True
            else:
                print(f"❌ Transaction failed")
                return False
                
        except Exception as e:
            print(f"❌ Error executing via Gnosis Safe: {e}")
            return False
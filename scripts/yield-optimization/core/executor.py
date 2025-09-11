#!/usr/bin/env python3
"""
Python Executor for Yield Optimization
Simple two-phase rebalancing: All → WBNB → Target allocation
Uses direct asset manager execution with Rebalancing.updateTokens
"""
import json
import os
import sys
import asyncio
import aiohttp
from web3 import Web3
from eth_account import Account
from eth_abi import encode
from typing import Dict, List, Optional

# Try to load .env file if python-dotenv is available
try:
    from dotenv import load_dotenv
    # Look for .env file in project root
    env_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
        print(f"📄 Loaded environment from: {env_path}")
except ImportError:
    pass  # python-dotenv not installed, continue without it

class SimpleExecutor:
    """Simple executor using direct asset manager execution"""
    
    def __init__(self, portfolio_address: str, owner_private_key: str = None, rpc_url: str = None):
        self.portfolio_address = portfolio_address
        
        # Get RPC URL from environment or use default
        if rpc_url is None:
            rpc_url = os.getenv("BSC_RPC", "https://bsc-dataseed.binance.org/")
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        
        # Get private key from environment, parameter, or config file
        if owner_private_key is None:
            owner_private_key = os.getenv("VAULT_OWNER")
        
        # Get Enso API key for authenticated requests
        self.enso_api_key = os.getenv("ENSO_KEY")
        if self.enso_api_key:
            print(f"🔑 Enso API key loaded")
        else:
            print(f"⚠️  No Enso API key found - using rate-limited requests")
        
        # Fallback to config.json if no environment variable
        if not owner_private_key:
            config_path = os.path.join(os.path.dirname(__file__), '..', 'config.json')
            if os.path.exists(config_path):
                try:
                    with open(config_path, 'r') as f:
                        config = json.load(f)
                        owner_private_key = config.get('VAULT_OWNER')
                        if owner_private_key:
                            print(f"📄 Loaded private key from: {config_path}")
                except Exception as e:
                    print(f"⚠️  Error reading config file: {e}")
        
        if not owner_private_key:
            raise ValueError("VAULT_OWNER private key must be provided via:\n  1. Environment variable: export VAULT_OWNER=your_key\n  2. .env file in project root\n  3. config.json file in scripts/yield-optimization/")
        
        self.owner = Account.from_key(owner_private_key)
        
        # Initialize portfolio fetcher to get vault address
        current_dir = os.path.dirname(os.path.abspath(__file__))
        parent_dir = os.path.dirname(current_dir)
        if current_dir not in sys.path:
            sys.path.append(current_dir)
        if parent_dir not in sys.path:
            sys.path.append(parent_dir)
        
        from portfolio_fetcher import SimplePortfolioFetcher
        self.portfolio_fetcher = SimplePortfolioFetcher(self.portfolio_address, rpc_url)
        
        # Get vault address from portfolio (this is the actual Gnosis Safe)
        self.vault_address = self.portfolio_fetcher.vault_address
        if not self.vault_address:
            print(f"⚠️  Could not get vault address, using portfolio address as fallback")
            self.vault_address = self.portfolio_address
        else:
            print(f"📍 Vault address: {self.vault_address}")
        
        # Get Rebalancing contract address from portfolio
        self.rebalancing_address = self.portfolio_fetcher.get_rebalancing_address()
        if self.rebalancing_address:
            print(f"📍 Rebalancing address: {self.rebalancing_address}")
        else:
            print(f"⚠️  Could not get rebalancing address from portfolio contract")
            # For testing, allow manual override via environment variable
            manual_rebalancing = os.getenv("REBALANCING_ADDRESS")
            if manual_rebalancing:
                self.rebalancing_address = manual_rebalancing
                print(f"📍 Using manual rebalancing address: {self.rebalancing_address}")
            else:
                print(f"💡 Tip: Set REBALANCING_ADDRESS environment variable for testing")
                self.rebalancing_address = None
        
        # Real contract addresses (ensure they're checksummed)
        self.enso_handler = self.w3.to_checksum_address("0x9D292ba959A8f37F215317eB7f264cd1aE408aEA")
        self.wbnb_address = self.w3.to_checksum_address("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c")
        
        # Load Rebalancing contract ABI
        rebalancing_abi_path = os.path.join(os.path.dirname(__file__), "..", "abi", "rebalancing.json")
        with open(rebalancing_abi_path, 'r') as f:
            self.rebalancing_abi = json.load(f)
        
        # ERC20 ABI for balance check
        self.erc20_abi = [
            {
                "inputs": [{"name": "owner", "type": "address"}],
                "name": "balanceOf",
                "outputs": [{"name": "", "type": "uint256"}],
                "type": "function"
            }
        ]
        
    async def get_current_portfolio_state(self) -> Dict:
        """Get current portfolio tokens and balances using portfolio fetcher"""
        try:
            print(f"🔍 Fetching portfolio state from: {self.portfolio_address}")
            
            # Use the portfolio fetcher to get current state
            portfolio_state = await self.portfolio_fetcher.get_portfolio_state()
            
            # Get token balances if we have tokens and a valid vault
            if portfolio_state['current_tokens'] and self.vault_address:
                balances = await self.portfolio_fetcher.get_token_balances(self.vault_address)
                portfolio_state['balances'] = balances
                print(f"🔍 Found {len(portfolio_state['current_tokens'])} tokens, {len(balances)} with balances")
            else:
                portfolio_state['balances'] = {}
                print(f"🔍 No tokens found or invalid vault address")
            
            # Add vault address to state
            portfolio_state['vault_address'] = self.vault_address
            
            return portfolio_state
            
        except Exception as e:
            print(f"❌ Error fetching portfolio state: {e}")
            return {'tokens': [], 'balances': {}, 'total_value_usd': 0, 'vault_address': None}
    
    async def get_enso_individual_route_calldata(self, token_in: str, token_out: str, amount_in: int, vault_address: str = None) -> Optional[Dict]:
        """Get individual Enso route calldata for a single token swap"""
        try:
            # Use provided vault address or default
            if vault_address is None:
                vault_address = self.vault_address
                
            # Use EnsoHandler as fromAddress (vault will transfer tokens to it)
            from_address_checksum = self.w3.to_checksum_address(self.enso_handler)
            
            route_params = {
                'chainId': 56,
                'fromAddress': from_address_checksum,
                'receiver': from_address_checksum,
                'spender': from_address_checksum,
                'slippage': '500',  # 3%
                'tokenIn': self.w3.to_checksum_address(token_in),
                'tokenOut': self.w3.to_checksum_address(token_out),
                'amountIn': str(amount_in),
                'routingStrategy': 'delegate'
            }
            
            # Build headers with API key if available
            headers = {}
            if self.enso_api_key:
                if self.enso_api_key.startswith('Bearer '):
                    headers['Authorization'] = self.enso_api_key
                else:
                    headers['Authorization'] = f'Bearer {self.enso_api_key}'
            
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    'https://api.enso.finance/api/v1/shortcuts/route',
                    params=route_params,
                    headers=headers
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        print(f"❌ Enso route API error: {response.status} - {error_text}")
                        return None
                    
                    data = await response.json()
                    if 'tx' not in data or 'data' not in data['tx']:
                        print(f"❌ Invalid Enso route response: {data}")
                        return None
                    
                    return {
                        'calldata': data['tx']['data'],
                        'amountOut': int(data.get('amountOut', '0')),
                        'tokenOut': token_out
                    }
                    
        except Exception as e:
            print(f"❌ Error getting individual route calldata: {e}")
            return None
            
    async def get_enso_liquidation_calldata(self, tokens_to_sell: List[str], balances: Dict[str, int], vault_address: str = None) -> Optional[bytes]:
        """Get Enso calldata to liquidate all tokens to WBNB using individual route calls"""
        try:
            # Use provided vault address or default
            if vault_address is None:
                vault_address = self.vault_address
                
            # Build simple arrays (following test pattern)
            calldata_array = []      # Raw hex strings with 0x
            tokens_array = []        # Token addresses  
            min_outputs_array = []   # Min expected outputs
            
            print(f"🔄 Liquidating {len(tokens_to_sell)} tokens to WBNB using individual routes...")
            
            for token_address in tokens_to_sell:
                if token_address in balances and balances[token_address] > 0:
                    # Get individual route data
                    route_data = await self.get_enso_individual_route_calldata(
                        token_address, self.wbnb_address, balances[token_address], vault_address
                    )
                    
                    if route_data:
                        # Keep raw calldata string (with 0x prefix)
                        calldata_array.append(route_data['calldata'])
                        tokens_array.append(self.wbnb_address)
                        
                        # Set minimum expected output (97% of expected for 3% slippage)
                        expected_output = route_data['amountOut']
                        min_expected = int(expected_output * 0.97) if expected_output > 0 else 0
                        min_outputs_array.append(min_expected)
                        
                        print(f"  - {token_address[:10]}... → WBNB: {balances[token_address] / 1e18:.6f} tokens")
                        print(f"    Expected: {expected_output / 1e18:.6f} WBNB, Min: {min_expected / 1e18:.6f} WBNB")
                    else:
                        print(f"⚠️  Failed to get route data for {token_address}")
                        
            if not calldata_array:
                print("⚠️  No valid liquidation routes found")
                return None
            
            # Convert hex strings to bytes for ABI encoding
            calldata_bytes = []
            for calldata_hex in calldata_array:
                if calldata_hex.startswith('0x'):
                    calldata_bytes.append(bytes.fromhex(calldata_hex[2:]))
                else:
                    calldata_bytes.append(bytes.fromhex(calldata_hex))
            
            # ABI encode the arrays (just like the test)
            encoded_parameters = encode(
                ['bytes[]', 'address[]', 'uint256[]'],
                [calldata_bytes, tokens_array, min_outputs_array]
            )
            
            print(f"✅ Generated liquidation calldata for {len(calldata_array)} swaps: {len(encoded_parameters)} bytes")
            return encoded_parameters
            
        except Exception as e:
            print(f"❌ Error getting liquidation calldata: {e}")
            return None
    
    async def execute_individual_liquidation(self, tokens_to_liquidate: List[str], balances: Dict[str, int], vault_address: str) -> Dict[str, bool]:
        """
        Execute individual token liquidation as fallback when batch liquidation fails.
        Returns dict with token -> success/failure status for manual intervention tracking.
        """
        print(f"🔄 Falling back to individual liquidation for {len(tokens_to_liquidate)} tokens...")
        results = {}
        successful_liquidations = 0
        
        for token_address in tokens_to_liquidate:
            try:
                print(f"\n🎯 Attempting individual liquidation: {token_address[:10]}...")
                
                if token_address not in balances or balances[token_address] == 0:
                    print(f"⚠️  Token {token_address[:10]}... has no balance, skipping")
                    results[token_address] = False
                    continue
                
                # Get individual token liquidation calldata
                token_calldata = await self.get_enso_liquidation_calldata(
                    [token_address], 
                    {token_address: balances[token_address]}, 
                    vault_address
                )
                
                if not token_calldata:
                    print(f"❌ Failed to generate calldata for {token_address[:10]}..., skipping")
                    results[token_address] = False
                    continue
                
                # Execute individual liquidation
                success = await self.execute_rebalancing_update_tokens(
                    [token_address],
                    [self.wbnb_address],
                    {token_address: balances[token_address]},
                    token_calldata
                )
                
                if success:
                    print(f"✅ Successfully liquidated {token_address[:10]}...")
                    successful_liquidations += 1
                    results[token_address] = True
                    
                    # Brief wait between individual transactions
                    await asyncio.sleep(2)
                else:
                    print(f"❌ Failed to liquidate {token_address[:10]}... - requires manual intervention")
                    results[token_address] = False
                    
            except Exception as e:
                print(f"❌ Error liquidating {token_address[:10]}...: {e}")
                results[token_address] = False
        
        # Summary
        failed_count = len(tokens_to_liquidate) - successful_liquidations
        print(f"\n📊 Individual liquidation results:")
        print(f"   ✅ Successful: {successful_liquidations}/{len(tokens_to_liquidate)} tokens")
        print(f"   ❌ Failed: {failed_count}/{len(tokens_to_liquidate)} tokens")
        
        if failed_count > 0:
            failed_tokens = [token for token, success in results.items() if not success]
            print(f"   🔧 Manual intervention needed for: {[token[:10]+'...' for token in failed_tokens]}")
        
        return results
    
    def analyze_portfolio_changes(self, current_tokens: List[str], target_allocation: List[Dict]) -> Dict:
        """
        Analyze what tokens need to be changed between current and target portfolio.
        Returns analysis for deciding between surgical vs full rebalancing.
        """
        try:
            current_token_set = set(token.lower() for token in current_tokens)
            target_token_set = set(alloc['token_address'].lower() for alloc in target_allocation)
            
            tokens_to_remove = [token for token in current_tokens 
                              if token.lower() in (current_token_set - target_token_set)]
            tokens_to_add = [alloc for alloc in target_allocation 
                           if alloc['token_address'].lower() in (target_token_set - current_token_set)]
            unchanged_tokens = [token for token in current_tokens 
                              if token.lower() in (current_token_set & target_token_set)]
            
            analysis = {
                'tokens_to_remove': tokens_to_remove,
                'tokens_to_add': tokens_to_add,
                'unchanged_tokens': unchanged_tokens,
                'remove_count': len(tokens_to_remove),
                'add_count': len(tokens_to_add),
                'unchanged_count': len(unchanged_tokens),
                'surgical_recommended': len(tokens_to_remove) <= 2 and len(tokens_to_add) <= 2
            }
            
            print(f"📊 Portfolio change analysis:")
            print(f"   🔴 Tokens to remove: {analysis['remove_count']}")
            print(f"   🟢 Tokens to add: {analysis['add_count']}")
            print(f"   🔵 Unchanged tokens: {analysis['unchanged_count']}")
            print(f"   🎯 Surgical recommended: {analysis['surgical_recommended']}")
            
            return analysis
            
        except Exception as e:
            print(f"❌ Error analyzing portfolio changes: {e}")
            return {
                'tokens_to_remove': [],
                'tokens_to_add': [],
                'unchanged_tokens': current_tokens,
                'remove_count': 0,
                'add_count': 0,
                'unchanged_count': len(current_tokens),
                'surgical_recommended': False
            }
    
    def calculate_correct_allocation_amounts(self, target_allocation: List[Dict], current_state: Dict, 
                                           tokens_to_add: List[Dict]) -> List[Dict]:
        """
        Calculate correct allocation amounts based on total portfolio value, not just WBNB balance.
        This ensures proper percentage allocation for surgical rebalancing.
        """
        try:
            # Get total portfolio value (ideally in USD, fallback to token count)
            total_portfolio_value = current_state.get('total_value_usd', 0)
            
            if total_portfolio_value == 0:
                # Fallback: estimate based on WBNB balance if available
                wbnb_balance = 0
                for token_addr, balance in current_state.get('balances', {}).items():
                    if token_addr.lower() == self.wbnb_address.lower():
                        wbnb_balance = balance
                        break
                
                # Very rough estimation: assume WBNB is ~$300
                total_portfolio_value = (wbnb_balance / 1e18) * 300 if wbnb_balance > 0 else 10000
                print(f"⚠️  Using estimated portfolio value: ${total_portfolio_value:.2f}")
            
            corrected_allocations = []
            
            for token_alloc in tokens_to_add:
                target_weight = token_alloc['weight']
                target_value_usd = total_portfolio_value * target_weight
                
                # For now, we'll use the original weight but add metadata for future enhancement
                corrected_allocation = {
                    'token_address': token_alloc['token_address'],
                    'symbol': token_alloc.get('symbol', 'UNKNOWN'),
                    'protocol': token_alloc.get('protocol', 'unknown'),
                    'weight': target_weight,
                    'target_value_usd': target_value_usd,
                    'apy': token_alloc.get('apy', 0)
                }
                
                corrected_allocations.append(corrected_allocation)
                print(f"   📊 {corrected_allocation['symbol']}: {target_weight:.1%} (${target_value_usd:.2f})")
            
            print(f"💰 Total portfolio value used: ${total_portfolio_value:.2f}")
            return corrected_allocations
            
        except Exception as e:
            print(f"❌ Error calculating allocation amounts: {e}")
            return tokens_to_add  # Return original if calculation fails
    
    async def execute_surgical_rebalancing(self, analysis: Dict, current_state: Dict, target_allocation: List[Dict]) -> bool:
        """
        Execute surgical rebalancing by only changing tokens that need to be changed.
        Uses batch operations where possible, individual fallbacks for failed operations.
        """
        try:
            print(f"🎯 Executing surgical rebalancing...")
            vault_address = current_state.get('vault_address', self.vault_address)
            balances = current_state.get('balances', {})
            
            # Phase 1: Surgical Liquidation (only tokens that need removal, excluding WBNB)
            tokens_to_liquidate = [
                token for token in analysis['tokens_to_remove'] 
                if token.lower() != self.wbnb_address.lower()
            ]
            
            if tokens_to_liquidate:
                print(f"\n🔴 Phase 1: Surgical liquidation of {len(tokens_to_liquidate)} tokens")
                if len(analysis['tokens_to_remove']) > len(tokens_to_liquidate):
                    print(f"   ℹ️  Skipping WBNB liquidation (will use existing balance for purchases)")
                
                # Try batch liquidation first
                liquidation_calldata = await self.get_enso_liquidation_calldata(
                    tokens_to_liquidate, balances, vault_address
                )
                
                if liquidation_calldata:
                    try:
                        print("🔄 Attempting batch surgical liquidation...")
                        success = await self.execute_rebalancing_update_tokens(
                            tokens_to_liquidate,
                            [self.wbnb_address] + analysis['unchanged_tokens'],  # Keep unchanged tokens
                            balances,
                            liquidation_calldata
                        )
                        
                        if not success:
                            print("⚠️  Batch surgical liquidation failed, trying individual...")
                            individual_results = await self.execute_individual_liquidation(
                                tokens_to_liquidate, balances, vault_address
                            )
                            
                            # Check if any liquidation succeeded
                            successful_liquidations = sum(1 for success in individual_results.values() if success)
                            if successful_liquidations == 0:
                                print("❌ All surgical liquidations failed")
                                return False
                        else:
                            print("✅ Batch surgical liquidation successful")
                            
                    except Exception as e:
                        print(f"❌ Batch surgical liquidation error: {e}")
                        print("🔄 Falling back to individual liquidation...")
                        
                        individual_results = await self.execute_individual_liquidation(
                            tokens_to_liquidate, balances, vault_address
                        )
                        
                        successful_liquidations = sum(1 for success in individual_results.values() if success)
                        if successful_liquidations == 0:
                            print("❌ All individual liquidations failed")
                            return False
                else:
                    print("❌ Failed to generate surgical liquidation calldata")
                    return False
            elif analysis['tokens_to_remove']:
                print(f"ℹ️  Only WBNB needs replacement - skipping liquidation phase")
                print(f"   Will use existing WBNB balance to purchase new tokens")
                
                # Wait for liquidation to settle
                print("⏳ Waiting for liquidation settlement...")
                await asyncio.sleep(5)
            
            # Phase 2: Surgical Allocation (only new tokens needed)
            if analysis['tokens_to_add']:
                print(f"\n🟢 Phase 2: Surgical allocation to {len(analysis['tokens_to_add'])} new tokens")
                
                # Calculate correct allocation amounts
                corrected_allocations = self.calculate_correct_allocation_amounts(
                    target_allocation, current_state, analysis['tokens_to_add']
                )
                
                # Get current WBNB balance after liquidation
                wbnb_contract = self.w3.eth.contract(address=self.wbnb_address, abi=self.erc20_abi)
                current_wbnb_balance = wbnb_contract.functions.balanceOf(vault_address).call()
                
                if current_wbnb_balance > 0:
                    # Try batch allocation
                    allocation_calldata = await self.get_enso_allocation_calldata(
                        corrected_allocations, vault_address
                    )
                    
                    if allocation_calldata:
                        try:
                            print("🔄 Attempting batch surgical allocation...")
                            
                            # Build final token list: unchanged + new tokens
                            final_tokens = analysis['unchanged_tokens'] + [
                                alloc['token_address'] for alloc in corrected_allocations
                            ]
                            
                            success = await self.execute_rebalancing_update_tokens(
                                [self.wbnb_address],  # Sell WBNB
                                final_tokens,  # Buy new tokens, keep unchanged
                                {self.wbnb_address: current_wbnb_balance},
                                allocation_calldata
                            )
                            
                            if success:
                                print("✅ Surgical rebalancing completed successfully!")
                                return True
                            else:
                                print("❌ Batch surgical allocation failed")
                                # Could add individual allocation fallback here
                                return False
                                
                        except Exception as e:
                            print(f"❌ Batch surgical allocation error: {e}")
                            return False
                    else:
                        print("❌ Failed to generate surgical allocation calldata")
                        return False
                else:
                    print("❌ No WBNB balance available for allocation")
                    return False
            
            # If we get here, surgical rebalancing completed
            print("✅ Surgical rebalancing completed successfully!")
            return True
            
        except Exception as e:
            print(f"❌ Error in surgical rebalancing: {e}")
            return False
    
    async def get_enso_allocation_calldata(self, target_allocation: List[Dict], vault_address: str = None) -> Optional[bytes]:
        """Get Enso calldata to buy target allocation from WBNB using individual route calls"""
        try:
            # Use provided vault address or default
            if vault_address is None:
                vault_address = self.vault_address
                
            # Get current WBNB balance
            wbnb_contract = self.w3.eth.contract(address=self.wbnb_address, abi=self.erc20_abi)
            wbnb_balance = wbnb_contract.functions.balanceOf(vault_address).call()
            
            if wbnb_balance == 0:
                print("❌ No WBNB balance for allocation")
                return None
            
            print(f"💰 WBNB balance: {wbnb_balance / 1e18:.6f} WBNB")
            
            # Build simple arrays (following test pattern)
            calldata_array = []      # Raw hex strings with 0x
            tokens_array = []        # Token addresses  
            min_outputs_array = []   # Min expected outputs
            
            print(f"🎯 Allocating WBNB to {len(target_allocation)} target tokens using individual routes...")
            
            for i, allocation in enumerate(target_allocation):
                is_last_token = (i == len(target_allocation) - 1)
                
                if is_last_token:
                    # For last token: Use precise remaining calculation to handle dust
                    try:
                        # Calculate how much has been allocated to previous tokens
                        total_allocated = sum(int(wbnb_balance * alloc['weight']) for alloc in target_allocation[:-1])
                        remaining_wbnb = wbnb_balance - total_allocated
                        
                        # Also include any dust from EnsoHandler for complete cleanup
                        wbnb_contract = self.w3.eth.contract(address=self.wbnb_address, abi=self.erc20_abi)
                        enso_wbnb_balance = wbnb_contract.functions.balanceOf(self.enso_handler).call()
                        
                        amount_to_spend = remaining_wbnb + enso_wbnb_balance
                        
                        if enso_wbnb_balance > 0:
                            print(f"   💰 Last token: {remaining_wbnb / 1e18:.6f} remaining + {enso_wbnb_balance / 1e18:.6f} handler dust")
                        else:
                            print(f"   💰 Last token: {remaining_wbnb / 1e18:.6f} remaining WBNB")
                            
                    except Exception as e:
                        print(f"   ⚠️  Could not calculate remaining balance, using percentage: {e}")
                        amount_to_spend = int(wbnb_balance * allocation['weight'])  # Fallback to existing logic
                else:
                    # For first N-1 tokens: Use existing percentage logic
                    amount_to_spend = int(wbnb_balance * allocation['weight'])
                
                if amount_to_spend > 0:
                    # Get individual route data
                    route_data = await self.get_enso_individual_route_calldata(
                        self.wbnb_address, allocation['token_address'], amount_to_spend, vault_address
                    )
                    
                    if route_data:
                        # Keep raw calldata string (with 0x prefix)
                        calldata_array.append(route_data['calldata'])
                        tokens_array.append(allocation['token_address'])
                        
                        # Set minimum expected output (97% of expected for 3% slippage)
                        expected_output = route_data['amountOut']
                        min_expected = int(expected_output * 0.97) if expected_output > 0 else 0
                        min_outputs_array.append(min_expected)
                        
                        print(f"  - {allocation['weight']:.1%} → {allocation['symbol']}: {amount_to_spend / 1e18:.6f} WBNB")
                        print(f"    Expected: {expected_output / 1e18:.6f} {allocation['symbol']}, Min: {min_expected / 1e18:.6f} {allocation['symbol']}")
                    else:
                        print(f"⚠️  Failed to get route data for {allocation['symbol']}")
                        
            if not calldata_array:
                print("❌ No valid allocation routes found")
                return None
            
            # Convert hex strings to bytes for ABI encoding
            calldata_bytes = []
            for calldata_hex in calldata_array:
                if calldata_hex.startswith('0x'):
                    calldata_bytes.append(bytes.fromhex(calldata_hex[2:]))
                else:
                    calldata_bytes.append(bytes.fromhex(calldata_hex))
            
            # ABI encode the arrays (just like the test)
            encoded_parameters = encode(
                ['bytes[]', 'address[]', 'uint256[]'],
                [calldata_bytes, tokens_array, min_outputs_array]
            )
            
            print(f"✅ Generated allocation calldata for {len(calldata_array)} swaps: {len(encoded_parameters)} bytes")
            return encoded_parameters
            
        except Exception as e:
            print(f"❌ Error getting allocation calldata: {e}")
            return None
    
    
    async def execute_rebalancing_update_tokens(self, sell_tokens: list, new_tokens: list, balances: dict, enso_calldata: bytes) -> bool:
        """Execute rebalancing via direct call to Rebalancing.updateTokens using asset manager private key"""
        try:
            # Build sell amounts array from balances
            sell_amounts = []
            total_sell_value = 0
            
            for sell_token in sell_tokens:
                if sell_token in balances:
                    sell_amount = balances[sell_token]
                    sell_amounts.append(sell_amount)
                    total_sell_value += sell_amount / 1e18
                    print(f"  - Selling {sell_token[:10]}...: {sell_amount / 1e18:.6f} tokens")
                else:
                    print(f"❌ Token {sell_token} not found in balances")
                    return False
            
            print(f"🔄 Rebalancing: {len(sell_tokens)} sell tokens → {len(new_tokens)} target tokens")
            print(f"💰 Total sell value: ~{total_sell_value:.6f} tokens")
            
            if not self.rebalancing_address:
                print(f"❌ Rebalancing contract address not available")
                return False
            
            # Create Rebalancing contract instance
            rebalancing_contract = self.w3.eth.contract(
                address=self.rebalancing_address,
                abi=self.rebalancing_abi
            )
            
            # Ensure all addresses are checksummed
            checksummed_new_tokens = [self.w3.to_checksum_address(token) for token in new_tokens]
            checksummed_sell_tokens = [self.w3.to_checksum_address(token) for token in sell_tokens]
            checksummed_handler = self.w3.to_checksum_address(self.enso_handler)
            
            # Build RebalanceIntent struct
            rebalance_intent = {
                '_newTokens': checksummed_new_tokens,
                '_sellTokens': checksummed_sell_tokens,
                '_sellAmounts': sell_amounts,
                '_handler': checksummed_handler,
                '_callData': enso_calldata
            }
            
            print(f"📞 Calling Rebalancing.updateTokens directly as asset manager")
            print(f"🏦 Rebalancing contract: {self.rebalancing_address}")
            print(f"👤 Asset manager: {self.owner.address}")
            print(f"🔢 Sell tokens: {len(sell_tokens)}, New tokens: {len(new_tokens)}")
            
            # Build transaction
            transaction = rebalancing_contract.functions.updateTokens(rebalance_intent)
            
            # Estimate gas
            # try:
            #     estimated_gas = transaction.estimate_gas({'from': self.owner.address})
            #     gas_limit = int(estimated_gas * 4) 
            #     print(f"⛽ Estimated gas: {estimated_gas:,}, using: {gas_limit:,}")
            # except Exception as gas_error:
            #     print(f"⚠️ Gas estimation failed: {gas_error}")
            #     # Higher fallback for multi-token operations - increase based on number of tokens
            #     base_gas = 500000
            #     gas_per_token = 300000  # ~300k gas per token swap
            #     num_operations = max(len(sell_tokens), len(new_tokens))
            #     gas_limit = base_gas + (gas_per_token * num_operations)
            #     print(f"⛽ Using fallback gas limit for {num_operations} operations: {gas_limit:,}")
            
            # Use dynamic gas price from network
            gas_price = self.w3.eth.gas_price
            print(f"💰 Network gas price: {gas_price / 1e9:.2f} gwei")
            
            # Build and sign transaction
            tx = transaction.build_transaction({
                'from': self.owner.address,
                'nonce': self.w3.eth.get_transaction_count(self.owner.address),
                'gas': 40000000,
                'gasPrice': gas_price
            })
            
            # Sign and send transaction
            signed_tx = self.owner.sign_transaction(tx)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            
            print(f"📤 Transaction sent: {tx_hash.hex()}")
            
            # Wait for confirmation
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
            
            if receipt.status == 1:
                print(f"✅ Transaction successful: {tx_hash.hex()[:10]}...")
                return True
            else:
                print(f"❌ Transaction failed: {tx_hash.hex()[:10]}...")
                print(f"   Gas used: {receipt.gasUsed:,} / {tx['gas']:,}")
                print(f"   Gas price: {gas_price / 1e9:.2f} gwei")
                print(f"   Block: {receipt.blockNumber}")
                
                # Try to get revert reason if possible
                try:
                    # Recreate the transaction call to get revert reason
                    self.w3.eth.call({
                        'from': self.owner.address,
                        'to': self.rebalancing_address,
                        'data': transaction._encode_transaction_data()
                    }, receipt.blockNumber)
                except Exception as revert_error:
                    print(f"   Revert reason: {str(revert_error)}")
                
                return False
            
        except Exception as e:
            print(f"❌ Error executing rebalancing update: {e}")
            return False
    
    
    
    async def execute_rebalancing(self, plan_file: str = None, optimizer = None) -> bool:
        """Execute complete rebalancing: Current → WBNB → Target"""
        print("🚀 Starting Three-Phase Rebalancing")
        print("=" * 50)
        
        # Load optimization plan
        if plan_file is None:
            plan_file = os.path.join(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                'output', 'plan.json'
            )
        
        if not os.path.exists(plan_file):
            print(f"❌ Plan file not found: {plan_file}")
            return False
        
        with open(plan_file, 'r') as f:
            plan = json.load(f)
        
        print(f"📊 Plan loaded: {plan['total_expected_apy']*100:.2f}% expected APY")
        print(f"🎯 Target tokens: {len(plan['target_allocation'])}")
        
        # Get current portfolio state first
        current_state = await self.get_current_portfolio_state()
        current_tokens = current_state.get('current_tokens', [])
        
        # Phase 0: Reward Redemption
        print("\n🎁 PHASE 0: Reward Redemption")
        print("-" * 40)
        
        # Import and initialize unified reward coordinator
        from reward_coordinator import RewardCoordinator
        reward_coordinator = RewardCoordinator(self.vault_address, self.owner, self.w3)
        
        # Get cached token data from optimizer to avoid duplicate API calls
        cached_token_data = None
        if optimizer and hasattr(optimizer, '_token_cache'):
            cached_token_data = optimizer._token_cache
            print("💾 Using cached token data from optimizer for reward coordination")
        
        # Redeem rewards from all protocols
        rewards_success = await reward_coordinator.redeem_all_rewards(current_tokens, cached_token_data)
        if not rewards_success:
            print("⚠️ Reward redemption had issues, but continuing with rebalancing...")
        
        # Wait for reward transactions to settle
        if rewards_success:
            print("⏳ Waiting for reward transactions to settle...")
            await asyncio.sleep(10)  # Give rewards time to process
        
        # Phase 1: Portfolio State & Liquidation  
        print("\n1️⃣ PHASE 1: Portfolio State & Liquidation")
        print("-" * 40)
        
        # Refresh portfolio state after reward redemption
        current_state = await self.get_current_portfolio_state()
        if not current_state.get('current_tokens', []):
            print("⚠️  No current tokens found, skipping liquidation")
        else:
            # Filter out WBNB from liquidation (we want to keep it)
            tokens_to_liquidate = [
                token for token in current_state.get('current_tokens', [])
                if token.lower() != self.wbnb_address.lower()
            ]
            
            if not tokens_to_liquidate:
                print("⚠️  Only WBNB in portfolio, skipping liquidation")
            else:
                print(f"🔍 Current tokens: {len(current_state.get('current_tokens', []))}")
                print(f"🔄 Tokens to liquidate: {len(tokens_to_liquidate)}")
                
                # Smart Decision: Surgical vs Full Liquidation
                actual_vault = current_state.get('vault_address', self.vault_address)
                
                # Analyze portfolio changes to decide rebalancing strategy
                analysis = self.analyze_portfolio_changes(
                    current_state.get('current_tokens', []), 
                    plan['target_allocation']
                )
                
                # Choose rebalancing strategy based on analysis
                if analysis['surgical_recommended'] and analysis['unchanged_count'] > 0:
                    print("🎯 Using surgical rebalancing (only change what needs changing)")
                    success = await self.execute_surgical_rebalancing(
                        analysis, current_state, plan['target_allocation']
                    )
                    
                    if success:
                        print("✅ Surgical rebalancing completed successfully!")
                        # Skip to end since surgical rebalancing handles both phases
                        print(f"\n🎉 Smart rebalancing completed successfully!")
                        return True
                    else:
                        print("⚠️  Surgical rebalancing failed, falling back to full liquidation...")
                        # Continue with full liquidation below
                
                print("🔄 Using full liquidation approach...")
                
                # Get liquidation calldata (only for non-WBNB tokens)
                liquidation_calldata = await self.get_enso_liquidation_calldata(
                    tokens_to_liquidate, 
                    current_state.get('balances', {}),
                    actual_vault
                )
                
                if liquidation_calldata:
                    print("🔄 Executing batch liquidation via Rebalancing.updateTokens...")
                    try:
                        success = await self.execute_rebalancing_update_tokens(
                            tokens_to_liquidate,
                            [self.wbnb_address],  # New tokens (WBNB only)
                            current_state.get('balances', {}),
                            liquidation_calldata
                        )
                        
                        if success:
                            print("✅ Batch liquidation successful!")
                            # Wait for transaction confirmation before proceeding
                            print("⏳ Waiting for liquidation confirmation...")
                            await asyncio.sleep(10)  # Give blockchain time to confirm
                        else:
                            # Batch liquidation failed - try individual fallback
                            print("⚠️  Batch liquidation failed, attempting individual token liquidation...")
                            individual_results = await self.execute_individual_liquidation(
                                tokens_to_liquidate,
                                current_state.get('balances', {}),
                                actual_vault
                            )
                            
                            # Check if any tokens were successfully liquidated
                            successful_tokens = sum(1 for success in individual_results.values() if success)
                            if successful_tokens > 0:
                                print(f"✅ Individual liquidation completed: {successful_tokens}/{len(tokens_to_liquidate)} tokens liquidated")
                                print("⏳ Waiting for individual liquidation confirmations...")
                                await asyncio.sleep(10)  # Give blockchain time to confirm
                            else:
                                print("❌ All individual liquidations failed - manual intervention required")
                                return False
                                
                    except Exception as e:
                        print(f"❌ Batch liquidation error: {e}")
                        print("🔄 Attempting individual token liquidation as fallback...")
                        
                        # Fallback to individual liquidation on batch error
                        individual_results = await self.execute_individual_liquidation(
                            tokens_to_liquidate,
                            current_state.get('balances', {}),
                            actual_vault
                        )
                        
                        # Check if any tokens were successfully liquidated
                        successful_tokens = sum(1 for success in individual_results.values() if success)
                        if successful_tokens > 0:
                            print(f"✅ Individual liquidation completed: {successful_tokens}/{len(tokens_to_liquidate)} tokens liquidated")
                            print("⏳ Waiting for individual liquidation confirmations...")
                            await asyncio.sleep(10)  # Give blockchain time to confirm
                        else:
                            print("❌ All individual liquidations failed - manual intervention required")
                            return False
                else:
                    print("⚠️  Skipping liquidation (no calldata)")
        
        # Phase 2: Allocate to target tokens
        print("\n2️⃣ PHASE 2: Target Allocation")
        print("-" * 40)
        
        # Validate target allocation
        if not plan['target_allocation']:
            print("❌ No target allocation found in plan")
            return False
        
        # Check minimum WBNB balance threshold - use actual vault address
        actual_vault = current_state.get('vault_address', self.vault_address)
        print(f"🏦 Using vault address: {actual_vault}")
        
        wbnb_contract = self.w3.eth.contract(address=self.wbnb_address, abi=self.erc20_abi)
        wbnb_balance = wbnb_contract.functions.balanceOf(actual_vault).call()
        min_wbnb_threshold = int(0.001 * 1e18)  # 0.001 WBNB minimum (reduced for testing)
        
        if wbnb_balance < min_wbnb_threshold:
            print(f"❌ WBNB balance too low: {wbnb_balance / 1e18:.6f} WBNB (minimum: 0.001 WBNB)")
            return False
        
        # Get allocation calldata using actual vault address
        allocation_calldata = await self.get_enso_allocation_calldata(
            plan['target_allocation'], actual_vault
        )
        
        if allocation_calldata:
            print("🎯 Executing allocation via Rebalancing.updateTokens...")
            success = await self.execute_rebalancing_update_tokens(
                [self.wbnb_address],  # Sell tokens (WBNB)
                [token['token_address'] for token in plan['target_allocation']],  # New tokens from plan
                {self.wbnb_address: wbnb_balance},
                allocation_calldata
            )
            if success:
                print("🎉 Rebalancing completed successfully!")
                return True
            else:
                print("❌ Allocation failed")
                return False
        else:
            print("⚠️  No allocation calldata generated")
            return False

# CLI interface
async def main():
    """Main execution"""
    portfolio_address = "0xbD35fCaC7813FC3B4bc14a5D0AC686c8e8b780Bc"
    
    try:
        # Use environment variables for configuration
        executor = SimpleExecutor(portfolio_address)
        print(f"🔐 Using vault owner: {executor.owner.address}")
        print(f"🏦 Portfolio address: {executor.portfolio_address}")
        print(f"🌐 BSC RPC: Connected")
    except ValueError as e:
        print(f"❌ Configuration error: {e}")
        print("💡 Make sure to set environment variables:")
        print("   export VAULT_OWNER=your_private_key")
        print("   export BSC_RPC=your_bsc_rpc_url  # Optional")
        print("   export ENSO_KEY=your_enso_key  # Optional")
        return
    except Exception as e:
        print(f"❌ Initialization error: {e}")
        return
    success = await executor.execute_rebalancing()
    
    if success:
        print("\n✅ Yield optimization completed successfully!")
    else:
        print("\n❌ Yield optimization failed")

if __name__ == "__main__":
    asyncio.run(main())
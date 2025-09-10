import asyncio
import aiohttp
import warnings
import os
import json
warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL 1.1.1+")
from web3 import Web3
from typing import Dict, List

class SimplePortfolioFetcher:
    """Simple portfolio state fetcher - no overengineering"""
    
    def __init__(self, portfolio_address: str, rpc_url: str = None):
        self.portfolio_address = portfolio_address
        if rpc_url is None:
            rpc_url = os.getenv("BSC_RPC", "https://bsc-dataseed.binance.org/")
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        print(f"🌐 Portfolio fetcher using RPC: {rpc_url[:50]}...")
        
        # Load Portfolio ABI
        abi_path = os.path.join(os.path.dirname(__file__), "..", "abi", "portfolio.json")
        with open(abi_path, 'r') as f:
            self.portfolio_abi = json.load(f)
        
        # Create contract instance
        self.portfolio_contract = self.w3.eth.contract(
            address=self.portfolio_address,
            abi=self.portfolio_abi
        )
        
        # Get vault address from portfolio contract
        try:
            self.vault_address = self.portfolio_contract.functions.vault().call()
            print(f"✅ Got vault address: {self.vault_address}")
        except Exception as e:
            print(f"❌ Could not get vault address: {e}")
            self.vault_address = None
    
    def get_rebalancing_address(self) -> str:
        """Get Rebalancing contract address from PortfolioFactory"""
        try:
            # We need the PortfolioFactory address and the portfolio ID
            # For now, let's add a parameter to pass this information
            # TODO: Get these from environment or config
            portfolio_factory_address = os.getenv("PORTFOLIO_FACTORY_ADDRESS")
            portfolio_id = os.getenv("PORTFOLIO_ID", "0")
            
            if not portfolio_factory_address:
                print("❌ PORTFOLIO_FACTORY_ADDRESS not set in environment")
                return None
            
            # Load PortfolioFactory ABI
            factory_abi_path = os.path.join(os.path.dirname(__file__), "..", "abi", "portfolioFactory.json")
            with open(factory_abi_path, 'r') as f:
                portfolio_factory_abi = json.load(f)
            
            # Create PortfolioFactory contract instance
            factory_contract = self.w3.eth.contract(
                address=portfolio_factory_address,
                abi=portfolio_factory_abi
            )
            
            # Get portfolio info - PortfolioInfolList returns tuple of addresses
            portfolio_info = factory_contract.functions.PortfolioInfolList(int(portfolio_id)).call()
            # Based on ABI: (portfolio, tokenExclusionManager, rebalancing, owner, assetManagementConfig, feeModule, vaultAddress, gnosisModule)
            rebalancing_address = portfolio_info[2]  # rebalancing is at index 2
            
            print(f"✅ Found rebalancing address: {rebalancing_address}")
            return rebalancing_address
            
        except Exception as e:
            print(f"❌ Error getting rebalancing address: {e}")
            return None
        
    async def get_current_tokens(self) -> List[str]:
        """Get current token addresses from portfolio.getTokens()"""
        try:
            tokens = self.portfolio_contract.functions.getTokens().call()
            print(f"✅ Retrieved {len(tokens)} tokens from portfolio")
            return [self.w3.to_checksum_address(token) for token in tokens]
        except Exception as e:
            print(f"❌ Error getting tokens from portfolio: {e}")
            return []

    async def get_token_balances(self, vault_address: str) -> Dict[str, int]:
        """Get ERC20 token balances from vault"""
        try:
            tokens = await self.get_current_tokens()
            if not tokens:
                return {}
            
            balances = {}
            
            # Simple ERC20 balanceOf ABI
            erc20_abi = [{
                "constant": True,
                "inputs": [{"name": "_owner", "type": "address"}],
                "name": "balanceOf",
                "outputs": [{"name": "balance", "type": "uint256"}],
                "type": "function"
            }]
            
            for token in tokens:
                try:
                    # Tokens are already checksummed from get_current_tokens
                    vault_checksum = self.w3.to_checksum_address(vault_address)
                    
                    # Create ERC20 contract instance
                    token_contract = self.w3.eth.contract(
                        address=token,
                        abi=erc20_abi
                    )
                    
                    # Get balance
                    balance = token_contract.functions.balanceOf(vault_checksum).call()
                    balances[token] = balance
                    
                except Exception as e:
                    print(f"Error getting balance for {token}: {e}")
                    balances[token] = 0
            
            return balances
            
        except Exception as e:
            print(f"Error getting balances: {e}")
            return {}
    
    async def get_token_usd_value(self, token_address: str, balance: int = None) -> float:
        """Get USD value of token using Enso API"""
        if balance is None:
            balance = 1000000000000000000  # 1 token in wei
            
        try:
            params = {
                'chainId': 56,
                'tokenIn': token_address,
                'tokenOut': '0x55d398326f99059fF775485246999027B3197955',  # USDT
                'amountIn': balance
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.get('https://api.enso.finance/api/v1/shortcuts/route', 
                                     params=params) as response:
                    data = await response.json()
                    return float(data.get('amountOut', 0)) / 1e18
        except:
            return 0.0
    
    async def get_portfolio_state(self) -> Dict:
        """Get simple portfolio state"""
        current_tokens = await self.get_current_tokens()
        
        portfolio_state = {
            'vault_address': self.vault_address,
            'current_tokens': current_tokens,
            'token_count': len(current_tokens),
            'total_value_usd': 0.0
        }
        
        # # Get values for each token
        # for token_address in current_tokens:
        #     try:
        #         value = await self.get_token_usd_value(token_address)
        #         portfolio_state['total_value_usd'] += value
        #     except:
        #         continue
        
        return portfolio_state
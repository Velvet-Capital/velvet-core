# Enhanced Multi-Protocol Strategy Integration Architecture

Complete implementation plan for a modular, protocol-agnostic optimization system with portfolio awareness and anti-over-rebalancing logic.

## Current Status

### ✅ **Phase 1: Foundation Complete**
- **Python Strategy** - Pendle APY optimization with 40/30/20/10% allocation
- **Reward Claiming** - Working scripts for Pendle reward redemption via Gnosis Safe
- **Market Analysis** - Real-time PT/YT/LP token assessment

### 🔄 **Phase 2: Enhanced Multi-Protocol System** (Current)
Evolution to modular, protocol-agnostic architecture with portfolio state awareness and intelligent rebalancing.

## Enhanced Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROTOCOL ADAPTER LAYER                      │
├─────────────────────────────────────────────────────────────────┤
│ pendle_adapter.py    │ pancakeswap_adapter.py │ lita_adapter.py  │
│ • get_tokens()       │ • get_tokens()         │ • get_tokens()   │
│ • calculate_apy()    │ • calculate_apy()      │ • calculate_apy()│
│ • get_profit_est()   │ • get_profit_est()     │ • get_profit_est()│
│ • check_liquidity()  │ • check_liquidity()    │ • check_liquidity()│
│                      │                        │                  │
│ Common Output Format:                                            │
│ {                                                                │
│   "protocol": "pendle",                                          │
│   "tokens": [                                                    │
│     {                                                            │
│       "address": "0x...",                                        │
│       "symbol": "PT-stETH",                                      │
│       "apy": 0.28,                                              │
│       "profit_estimate": 2800,                                  │
│       "price_impact": 0.015,                                    │
│       "liquidity_score": 0.85,                                  │
│       "protocol": "pendle"                                       │
│     }                                                            │
│   ]                                                              │
│ }                                                                │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                PORTFOLIO STATE MANAGEMENT                       │
├─────────────────────────────────────────────────────────────────┤
│ portfolio_state_manager.py                                      │
│ • Fetch current holdings via portfolio.getTokens()             │
│ • Get total USD value of vault                                  │
│ • Calculate current allocation percentages                      │
│ • Track portfolio performance and changes                       │
│                                                                 │
│ Current Portfolio State:                                        │
│ {                                                               │
│   "total_value_usd": 50000,                                     │
│   "current_tokens": [                                           │
│     {"address": "0x...", "symbol": "PT-stETH", "value": 20000, │
│      "percentage": 0.40},                                       │
│     {"address": "0x...", "symbol": "YT-BNB", "value": 15000,   │
│      "percentage": 0.30}                                        │
│   ],                                                            │
│   "last_rebalance": "2025-01-05T10:00:00Z"                     │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                ENHANCED STRATEGY ENGINE                         │
├─────────────────────────────────────────────────────────────────┤
│ generalized_optimizer.py                                        │
│ • Aggregate tokens from all protocol adapters                   │
│ • Filter by price impact threshold (< 2%)                      │
│ • Apply 40/30/20/10 optimization across all protocols          │
│ • Anti-over-rebalancing logic (5% deviation threshold)         │
│ • Sequential rebalancing planning (one token at a time)        │
│ • Cost-benefit analysis (gas costs vs profit gains)            │
│                                                                 │
│ OUTPUT: rebalancing_plan.json                                   │
│ {                                                               │
│   "should_rebalance": true,                                     │
│   "rebalancing_reason": "5.2% deviation from optimal",         │
│   "target_allocation": [                                        │
│     {"token": "0x...", "target_percentage": 0.40,              │
│      "current_percentage": 0.35, "action": "buy_more"},        │
│   ],                                                            │
│   "rebalancing_steps": [                                        │
│     {"step": 1, "action": "sell", "token": "0x...",            │
│      "amount": 5000, "expected_impact": 0.012},                │
│     {"step": 2, "action": "buy", "token": "0x...",             │
│      "amount": 5000, "expected_impact": 0.018}                 │
│   ],                                                            │
│   "expected_apy_improvement": 0.024                             │
│ }                                                               │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                 EXECUTION COORDINATION LAYER                   │
├─────────────────────────────────────────────────────────────────┤
│ execution_coordinator.ts (Enhanced)                             │
│ • Read rebalancing_plan.json                                   │
│ • Execute sequential rebalancing steps                         │
│ • All swaps via Enso routing (no limit orders)                │
│ • Gnosis Safe transaction execution                            │
│ • Progress tracking and validation                             │
│                                                                 │
│ Sequential Execution Logic:                                     │
│ FOR each step in rebalancing_steps:                            │
│   • Validate price impact still acceptable                     │
│   • Create Enso swap transaction                               │
│   • Execute via Gnosis Safe                                    │
│   • Wait for confirmation                                       │
│   • Update portfolio state                                      │
│   • Continue to next step                                       │
│                                                                 │
│ Execution Monitoring:                                           │
│ • Real-time portfolio value tracking                           │
│ • Performance validation after each step                       │
│ • Rollback capability for failed transactions                  │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Implementation Plan

### Phase 2A: Protocol Adapter Layer Implementation

**Create modular adapter system for different DeFi protocols**

#### Base Adapter Interface

**File: `scripts/pendle-optimization/adapters/base_adapter.py`**

```python
from abc import ABC, abstractmethod
from typing import Dict, List
import aiohttp
import asyncio

class BaseProtocolAdapter(ABC):
    """Base class for all protocol adapters"""
    
    def __init__(self, chain_id: int = 56):
        self.chain_id = chain_id
        self.protocol_name = self.get_protocol_name()
    
    @abstractmethod
    def get_protocol_name(self) -> str:
        """Return protocol name (e.g., 'pendle', 'pancakeswap')"""
        pass
    
    @abstractmethod
    async def get_tokens(self) -> List[Dict]:
        """Get available tokens from this protocol"""
        pass
    
    @abstractmethod
    async def calculate_apy(self, token_address: str) -> float:
        """Calculate APY for a specific token"""
        pass
    
    @abstractmethod
    async def get_profit_estimate(self, token_address: str, investment_amount: float) -> float:
        """Estimate profit for given investment amount"""
        pass
    
    async def check_price_impact(self, token_in: str, token_out: str, amount_in: int) -> Dict:
        """Check price impact via Enso API"""
        params = {
            'chainId': self.chain_id,
            'tokenIn': token_in,
            'tokenOut': token_out,
            'amountIn': amount_in,
            'slippage': 300  # 3%
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get('https://api.enso.finance/api/v1/shortcuts/route', 
                                     params=params) as response:
                    data = await response.json()
            
            return {
                'price_impact': data.get('priceImpact', 0),
                'is_liquid': data.get('priceImpact', 0) < 0.02,  # < 2% impact
                'liquidity_score': 1.0 - min(data.get('priceImpact', 0), 0.1) / 0.1
            }
        except Exception as e:
            # Fallback to conservative estimate
            return {'price_impact': 0.05, 'is_liquid': False, 'liquidity_score': 0.0}
    
    async def get_standardized_token_data(self, investment_amount: float = 10000) -> Dict:
        """Return standardized token data for this protocol"""
        tokens = await self.get_tokens()
        enhanced_tokens = []
        
        for token in tokens:
            # Add price impact and liquidity data
            token_amount = investment_amount * 0.25  # Assume 25% allocation for testing
            impact_data = await self.check_price_impact(
                "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",  # BNB
                token['address'],
                int(token_amount * 10**18)
            )
            
            enhanced_token = {
                'address': token['address'],
                'symbol': token['symbol'],
                'apy': await self.calculate_apy(token['address']),
                'profit_estimate': await self.get_profit_estimate(token['address'], investment_amount),
                'price_impact': impact_data['price_impact'],
                'liquidity_score': impact_data['liquidity_score'],
                'is_liquid': impact_data['is_liquid'],
                'protocol': self.protocol_name
            }
            enhanced_tokens.append(enhanced_token)
        
        return {
            'protocol': self.protocol_name,
            'tokens': enhanced_tokens
        }
```

#### Pendle Protocol Adapter

**File: `scripts/pendle-optimization/adapters/pendle_adapter.py`**

```python
from .base_adapter import BaseProtocolAdapter
from ..strategy import PendleStrategyAnalyzer
from typing import Dict, List

class PendleAdapter(BaseProtocolAdapter):
    """Adapter for Pendle protocol"""
    
    def __init__(self, chain_id: int = 56):
        super().__init__(chain_id)
        self.analyzer = PendleStrategyAnalyzer()
    
    def get_protocol_name(self) -> str:
        return "pendle"
    
    async def get_tokens(self) -> List[Dict]:
        """Get PT/YT/LP tokens from Pendle"""
        # Use existing logic from strategy.py
        market_addresses = [
            "0x2C1AAA13C2b0af5aD0D2F5be4A9aD8CE01eE7ecd",
            "0xB1FD1A10C1F54b8B7F4F1B9DA57dc32c8b80c4AC",
            "0x9F7bEc966F83b09c90cF8c44923B4Be2dCCAa8Db",
            "0x54CdfDa988c3bf5ab8CdF31b7fF76A61A5AdB8Ed",
            "0x70F4DbcFCdAAa62103A86B5B2C9e5b8Edd22F421",
        ]
        
        tokens = []
        for market_address in market_addresses:
            market_info = self.analyzer.get_market_info(market_address)
            
            # Add PT token
            tokens.append({
                'address': market_info['pt_address'],
                'symbol': f"PT-{market_info['underlying_symbol']}",
                'market_address': market_address,
                'type': 'PT',
                'maturity': market_info['maturity']
            })
            
            # Add YT token  
            tokens.append({
                'address': market_info['yt_address'],
                'symbol': f"YT-{market_info['underlying_symbol']}",
                'market_address': market_address,
                'type': 'YT',
                'maturity': market_info['maturity']
            })
        
        return tokens
    
    async def calculate_apy(self, token_address: str) -> float:
        """Calculate APY using existing Pendle logic"""
        # Use analyzer to calculate APY for this token
        return self.analyzer.calculate_token_apy(token_address)
    
    async def get_profit_estimate(self, token_address: str, investment_amount: float) -> float:
        """Estimate profit for maturity tokens"""
        apy = await self.calculate_apy(token_address)
        # Simplified profit calculation (assuming 1 year holding period)
        return investment_amount * apy
```

### Phase 2B: Portfolio State Management

**File: `scripts/pendle-optimization/core/portfolio_state_manager.py`**

```python
import asyncio
import aiohttp
from typing import Dict, List
from web3 import Web3
import json

class PortfolioStateManager:
    """Manages current portfolio state and tracks changes"""
    
    def __init__(self, vault_address: str, rpc_url: str):
        self.vault_address = vault_address
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        self.portfolio_abi = self._load_portfolio_abi()
    
    def _load_portfolio_abi(self) -> List:
        """Load portfolio contract ABI"""
        # Load from existing contract artifacts
        with open('artifacts/contracts/portfolio/PortfolioFactory.sol/PortfolioFactory.json') as f:
            contract_data = json.load(f)
            return contract_data['abi']
    
    async def get_current_portfolio_state(self) -> Dict:
        """Fetch current portfolio holdings and values"""
        portfolio_contract = self.w3.eth.contract(
            address=self.vault_address,
            abi=self.portfolio_abi
        )
        
        # Get current tokens in portfolio
        token_addresses = portfolio_contract.functions.getTokens().call()
        
        portfolio_state = {
            'vault_address': self.vault_address,
            'total_value_usd': 0,
            'current_tokens': [],
            'token_count': len(token_addresses),
            'last_updated': asyncio.get_event_loop().time()
        }
        
        # Get value for each token
        for token_address in token_addresses:
            token_info = await self._get_token_info(token_address, portfolio_contract)
            portfolio_state['current_tokens'].append(token_info)
            portfolio_state['total_value_usd'] += token_info['value_usd']
        
        # Calculate allocation percentages
        if portfolio_state['total_value_usd'] > 0:
            for token in portfolio_state['current_tokens']:
                token['percentage'] = token['value_usd'] / portfolio_state['total_value_usd']
        
        return portfolio_state
    
    async def _get_token_info(self, token_address: str, portfolio_contract) -> Dict:
        """Get detailed info for a specific token"""
        # Get token balance
        balance = portfolio_contract.functions.getTokenBalance(token_address).call()
        
        # Get USD value (using existing price oracle or Enso API)
        usd_value = await self._get_token_usd_value(token_address, balance)
        
        # Get token symbol
        token_contract = self.w3.eth.contract(
            address=token_address,
            abi=[{"constant":True,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"}]
        )
        symbol = token_contract.functions.symbol().call()
        
        return {
            'address': token_address,
            'symbol': symbol,
            'balance': balance,
            'value_usd': usd_value,
            'percentage': 0  # Will be calculated later
        }
    
    async def _get_token_usd_value(self, token_address: str, balance: int) -> float:
        """Get USD value of token balance using price oracle"""
        # Use Enso API or existing price oracle
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
    
    async def calculate_rebalancing_need(self, target_allocation: List[Dict]) -> Dict:
        """Determine if rebalancing is needed based on current vs target allocation"""
        current_state = await self.get_current_portfolio_state()
        
        rebalancing_analysis = {
            'should_rebalance': False,
            'max_deviation': 0,
            'deviations': [],
            'threshold': 0.05,  # 5% deviation threshold
            'cost_benefit_ratio': 0
        }
        
        # Calculate deviations for each target token
        for target in target_allocation:
            current_percentage = self._find_current_percentage(
                target['token_address'], 
                current_state['current_tokens']
            )
            
            deviation = abs(target['target_percentage'] - current_percentage)
            rebalancing_analysis['deviations'].append({
                'token': target['token_address'],
                'target': target['target_percentage'],
                'current': current_percentage,
                'deviation': deviation,
                'action': 'buy' if target['target_percentage'] > current_percentage else 'sell'
            })
            
            if deviation > rebalancing_analysis['max_deviation']:
                rebalancing_analysis['max_deviation'] = deviation
        
        # Decide if rebalancing is needed
        if rebalancing_analysis['max_deviation'] > rebalancing_analysis['threshold']:
            rebalancing_analysis['should_rebalance'] = True
            rebalancing_analysis['rebalancing_reason'] = f"{rebalancing_analysis['max_deviation']:.1%} deviation from optimal"
        
        return rebalancing_analysis
    
    def _find_current_percentage(self, token_address: str, current_tokens: List[Dict]) -> float:
        """Find current percentage allocation for a token"""
        for token in current_tokens:
            if token['address'].lower() == token_address.lower():
                return token['percentage']
        return 0.0
```

### Phase 2C: Generalized Optimization Engine

**File: `scripts/pendle-optimization/core/generalized_optimizer.py`**

```python
import asyncio
from typing import Dict, List, Optional
from ..adapters.pendle_adapter import PendleAdapter
# Import other adapters as they're implemented
# from ..adapters.pancakeswap_adapter import PancakeSwapAdapter
# from ..adapters.lita_adapter import LitaAdapter
from .portfolio_state_manager import PortfolioStateManager

class GeneralizedOptimizer:
    """Cross-protocol optimization engine with anti-over-rebalancing logic"""
    
    def __init__(self, vault_address: str, rpc_url: str):
        self.vault_address = vault_address
        self.portfolio_manager = PortfolioStateManager(vault_address, rpc_url)
        self.adapters = self._initialize_adapters()
        self.allocation_weights = [0.40, 0.30, 0.20, 0.10]  # 40/30/20/10
    
    def _initialize_adapters(self) -> List:
        """Initialize all available protocol adapters"""
        adapters = [
            PendleAdapter(chain_id=56),
            # PancakeSwapAdapter(chain_id=56),  # Add when implemented
            # LitaAdapter(chain_id=56),         # Add when implemented
        ]
        return adapters
    
    async def get_optimal_allocation(self, investment_amount: Optional[float] = None) -> Dict:
        """Get optimal token allocation across all protocols"""
        # Get current portfolio state
        current_state = await self.portfolio_manager.get_current_portfolio_state()
        
        if investment_amount is None:
            investment_amount = current_state['total_value_usd']
        
        # Collect tokens from all adapters
        all_tokens = []
        for adapter in self.adapters:
            adapter_data = await adapter.get_standardized_token_data(investment_amount)
            all_tokens.extend(adapter_data['tokens'])
        
        # Filter by liquidity (price impact < 2%)
        liquid_tokens = [token for token in all_tokens if token['is_liquid']]
        
        if len(liquid_tokens) < 4:
            # If not enough liquid tokens, include some with higher impact
            all_tokens.sort(key=lambda x: x['price_impact'])
            liquid_tokens = all_tokens[:4]
        
        # Sort by APY and select top tokens
        liquid_tokens.sort(key=lambda x: x['apy'], reverse=True)
        selected_tokens = liquid_tokens[:4]  # Top 4 tokens
        
        # Apply 40/30/20/10 allocation
        target_allocation = []
        for i, token in enumerate(selected_tokens):
            target_allocation.append({
                'token_address': token['address'],
                'symbol': token['symbol'],
                'protocol': token['protocol'],
                'target_percentage': self.allocation_weights[i],
                'expected_apy': token['apy'],
                'price_impact': token['price_impact'],
                'profit_estimate': token['profit_estimate'] * self.allocation_weights[i]
            })
        
        # Check if rebalancing is needed
        rebalancing_analysis = await self.portfolio_manager.calculate_rebalancing_need(target_allocation)
        
        # Generate rebalancing plan if needed
        if rebalancing_analysis['should_rebalance']:
            rebalancing_steps = await self._plan_sequential_rebalancing(
                current_state, 
                target_allocation,
                rebalancing_analysis
            )
        else:
            rebalancing_steps = []
        
        return {
            'current_portfolio': current_state,
            'target_allocation': target_allocation,
            'rebalancing_analysis': rebalancing_analysis,
            'rebalancing_steps': rebalancing_steps,
            'total_expected_apy': sum(token['expected_apy'] * token['target_percentage'] 
                                    for token in target_allocation),
            'optimization_summary': {
                'protocols_used': list(set(token['protocol'] for token in target_allocation)),
                'total_tokens_analyzed': len(all_tokens),
                'liquid_tokens_available': len(liquid_tokens),
                'selected_tokens': len(selected_tokens)
            }
        }
    
    async def _plan_sequential_rebalancing(self, current_state: Dict, 
                                         target_allocation: List[Dict],
                                         rebalancing_analysis: Dict) -> List[Dict]:
        """Plan sequential rebalancing steps (one token at a time)"""
        steps = []
        step_counter = 1
        
        # Sort deviations by magnitude (largest first)
        deviations = sorted(rebalancing_analysis['deviations'], 
                          key=lambda x: x['deviation'], reverse=True)
        
        for deviation in deviations:
            if deviation['deviation'] > 0.02:  # Only rebalance if > 2% deviation
                if deviation['action'] == 'sell':
                    # Step 1: Sell overallocated token
                    sell_amount = (deviation['current'] - deviation['target']) * current_state['total_value_usd']
                    steps.append({
                        'step': step_counter,
                        'action': 'sell',
                        'token': deviation['token'],
                        'amount_usd': sell_amount,
                        'expected_impact': 0.015,  # Will be calculated precisely
                        'reason': f"Reduce allocation from {deviation['current']:.1%} to {deviation['target']:.1%}"
                    })
                    step_counter += 1
                
                elif deviation['action'] == 'buy':
                    # Step 2: Buy underallocated token
                    buy_amount = (deviation['target'] - deviation['current']) * current_state['total_value_usd']
                    steps.append({
                        'step': step_counter,
                        'action': 'buy',
                        'token': deviation['token'],
                        'amount_usd': buy_amount,
                        'expected_impact': 0.018,  # Will be calculated precisely
                        'reason': f"Increase allocation from {deviation['current']:.1%} to {deviation['target']:.1%}"
                    })
                    step_counter += 1
        
        return steps
```

### Phase 2D: Enhanced Execution Coordination

**File: `scripts/pendle-optimization/integration/execution_coordinator.ts`**

Enhanced execution system using only Enso routing with sequential rebalancing support:

```typescript
import fs from 'fs';
import { ethers } from 'hardhat';
import { createEnsoCallDataRoute } from '../../testing/IntentCalculations';
import { deployedAddresses } from '../../testing/deployedAddresses';

interface RebalancingStep {
  step: number;
  action: 'buy' | 'sell';
  token: string;
  amount_usd: number;
  expected_impact: number;
  reason: string;
}

interface RebalancingPlan {
  should_rebalance: boolean;
  rebalancing_reason: string;
  target_allocation: any[];
  rebalancing_steps: RebalancingStep[];
  current_portfolio: any;
  total_expected_apy: number;
}

class EnhancedExecutionCoordinator {
  private vaultAddress: string;
  private owner: any;
  
  constructor() {
    this.vaultAddress = deployedAddresses.vaultAddress;
  }
  
  async initialize(): Promise<void> {
    const accounts = await ethers.getSigners();
    this.owner = accounts[1]; // owner2 as in existing scripts
    
    console.log("🚀 Enhanced Execution Coordinator Initialized");
    console.log("   Vault Address:", this.vaultAddress);
    console.log("   Executor:", this.owner.address);
  }
  
  async processRebalancingPlan(): Promise<void> {
    // Read Python optimizer output
    const plan: RebalancingPlan = JSON.parse(
      fs.readFileSync('scripts/pendle-optimization/output/rebalancing_plan.json', 'utf8')
    );
    
    console.log("📊 Current Portfolio Analysis:");
    console.log(`   Total Value: $${plan.current_portfolio.total_value_usd.toLocaleString()}`);
    console.log(`   Token Count: ${plan.current_portfolio.token_count}`);
    console.log(`   Expected APY: ${(plan.total_expected_apy * 100).toFixed(2)}%`);
    
    if (!plan.should_rebalance) {
      console.log("✅ Portfolio is optimally balanced - no rebalancing needed");
      console.log(`   Reason: ${plan.rebalancing_reason || 'Within acceptable deviation threshold'}`);
      return;
    }
    
    console.log("🔄 Rebalancing Required:");
    console.log(`   Reason: ${plan.rebalancing_reason}`);
    console.log(`   Steps Planned: ${plan.rebalancing_steps.length}`);
    
    // Execute rebalancing steps sequentially
    await this.executeSequentialRebalancing(plan.rebalancing_steps);
  }
  
  async executeSequentialRebalancing(steps: RebalancingStep[]): Promise<void> {
    console.log(`\n🎯 Executing ${steps.length} rebalancing steps sequentially...\n`);
    
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      console.log(`📝 Step ${step.step}/${steps.length}: ${step.action.toUpperCase()} ${step.token.slice(0,8)}...`);
      console.log(`   Amount: $${step.amount_usd.toFixed(2)}`);
      console.log(`   Expected Impact: ${(step.expected_impact * 100).toFixed(2)}%`);
      console.log(`   Reason: ${step.reason}`);
      
      try {
        // Execute the step via Enso
        await this.executeRebalancingStep(step);
        
        console.log(`✅ Step ${step.step} completed successfully\n`);
        
        // Brief pause between steps for blockchain finality
        if (i < steps.length - 1) {
          console.log("⏱️  Waiting for transaction finality before next step...");
          await this.sleep(5000); // 5 second pause
        }
        
      } catch (error) {
        console.error(`❌ Step ${step.step} failed:`, error.message);
        console.log("🛑 Stopping sequential rebalancing due to error");
        break;
      }
    }
    
    console.log("🎉 Sequential rebalancing completed!");
  }
  
  async executeRebalancingStep(step: RebalancingStep): Promise<void> {
    const amountInWei = ethers.utils.parseEther(step.amount_usd.toString());
    
    if (step.action === 'sell') {
      // Sell token for BNB
      await this.executeEnsoSwap(
        step.token,                                              // tokenIn
        "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",            // tokenOut (BNB)
        amountInWei,
        `Sell ${step.token.slice(0,8)}...`
      );
      
    } else if (step.action === 'buy') {
      // Buy token with BNB  
      await this.executeEnsoSwap(
        "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",            // tokenIn (BNB)
        step.token,                                              // tokenOut
        amountInWei,
        `Buy ${step.token.slice(0,8)}...`
      );
    }
  }
  
  async executeEnsoSwap(tokenIn: string, tokenOut: string, 
                       amountIn: ethers.BigNumber, description: string): Promise<void> {
    console.log(`   🔄 ${description} via Enso...`);
    
    try {
      // Get Enso route data
      const ensoResponse = await createEnsoCallDataRoute(
        this.vaultAddress,   // from
        this.vaultAddress,   // to  
        tokenIn,
        tokenOut,
        amountIn.toString()
      );
      
      if (!ensoResponse?.data?.tx?.data) {
        throw new Error("Failed to get Enso route data");
      }
      
      // Execute via Gnosis Safe (using existing pattern)
      const txHash = await this.executeViaGnosisSafe(
        ensoResponse.data.tx.to,
        ensoResponse.data.tx.data
      );
      
      console.log(`   ✅ Transaction submitted: ${txHash.slice(0,10)}...`);
      
    } catch (error) {
      console.error(`   ❌ Enso swap failed: ${error.message}`);
      throw error;
    }
  }
  
  async executeViaGnosisSafe(target: string, callData: string): Promise<string> {
    // Use exact pattern from pendleExecuteRedemption.ts
    const GnosisSafeABI = [
      "function execTransaction(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes calldata signatures) external returns (bool success)",
      "function getTransactionHash(address to, uint256 value, bytes calldata data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce) external view returns (bytes32)",
      "function nonce() external view returns (uint256)"
    ];
    
    const gnosisSafe = new ethers.Contract(this.vaultAddress, GnosisSafeABI, this.owner);
    const nonce = await gnosisSafe.nonce();
    
    // Generate transaction hash
    const txHash = await gnosisSafe.getTransactionHash(
      target,                                    // to
      0,                                        // value
      callData,                                 // data
      0,                                        // operation (CALL)
      0,                                        // safeTxGas
      0,                                        // baseGas
      0,                                        // gasPrice
      ethers.constants.AddressZero,            // gasToken
      ethers.constants.AddressZero,            // refundReceiver
      nonce                                     // nonce
    );
    
    // Sign transaction
    const messageBytes = ethers.utils.arrayify(txHash);
    const signature = await this.owner.signMessage(messageBytes);
    const sigBytes = ethers.utils.arrayify(signature);
    sigBytes[64] += 4; // Adjust for Gnosis Safe format
    const adjustedSignature = ethers.utils.hexlify(sigBytes);
    
    // Execute transaction
    const executeTx = await gnosisSafe.execTransaction(
      target,
      0,
      callData,
      0,
      0,
      0,
      0,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      adjustedSignature,
      {
        maxFeePerGas: ethers.utils.parseUnits("3", "gwei"),
        maxPriorityFeePerGas: ethers.utils.parseUnits("0.1", "gwei"),
        gasLimit: 2000000
      }
    );
    
    // Wait for confirmation
    const receipt = await executeTx.wait();
    
    if (receipt.status === 0) {
      throw new Error("Transaction failed");
    }
    
    return executeTx.hash;
  }
  
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Main execution function
async function main() {
  const coordinator = new EnhancedExecutionCoordinator();
  await coordinator.initialize();
  await coordinator.processRebalancingPlan();
}

export { EnhancedExecutionCoordinator };

// Run if called directly
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("Execution failed:", error);
      process.exit(1);
    });
}
```

## Enhanced Integration Flow

### 1. **Cross-Protocol Token Analysis**
```bash
# Run protocol adapters to collect token data
python3 scripts/pendle-optimization/core/run_optimization.py --vault-address 0x123... --investment-amount 50000
# Outputs: rebalancing_plan.json with cross-protocol analysis
```

**What happens:**
- All protocol adapters (Pendle, PancakeSwap, Lita) fetch available tokens
- Price impact analysis via Enso API for each token
- APY and profit estimates calculated per protocol
- Cross-protocol optimization with 40/30/20/10 allocation
- Portfolio state awareness prevents over-rebalancing

### 2. **Portfolio State Assessment**  
```bash
# Get current portfolio holdings and allocation
python3 scripts/pendle-optimization/core/portfolio_state_manager.py --vault-address 0x123...
# Analysis: Current vs optimal allocation deviations
```

**What happens:**
- Fetches current token holdings via `portfolio.getTokens()`
- Calculates USD values and allocation percentages
- Determines rebalancing necessity (5% deviation threshold)
- Plans sequential rebalancing steps (one token at a time)

### 3. **Enhanced Execution Coordination**
```bash  
# Execute optimized rebalancing via Enso routing
npx hardhat run scripts/pendle-optimization/integration/execution_coordinator.ts
# Reads: rebalancing_plan.json
# Executes: Sequential swaps via Enso + Gnosis Safe
```

**What happens:**
- Sequential execution of buy/sell steps
- All swaps via Enso routing (no limit orders)
- Gnosis Safe transaction signing and execution  
- Real-time validation and error handling
- Portfolio state updates after each step

## Enhanced Risk Management

### Liquidity-First Approach  
- **< 2% Price Impact:** Include in optimization ✅ Maximum efficiency
- **>= 2% Price Impact:** Exclude from selection ❌ Avoid high slippage  
- **Fallback Strategy:** If insufficient liquid tokens, include best available

### Anti-Over-Rebalancing Logic
- **Deviation Threshold:** Only rebalance if > 5% allocation drift
- **Cost-Benefit Analysis:** Consider gas costs vs expected APY gains
- **Cooldown Periods:** Prevent frequent rebalancing (configurable)
- **Emergency Override:** Manual rebalancing capability maintained

### Sequential Execution Safety
- **One-Step-at-a-Time:** Handles contract constraint elegantly  
- **Transaction Validation:** Each step validated before execution
- **Rollback Capability:** Failed steps stop sequence, maintain safety
- **Progress Tracking:** Clear visibility into rebalancing progress

### Fallback Mechanisms
- **Enso API Failure:** Conservative price impact estimates (5%)
- **Portfolio State Error:** Use last known state with warnings  
- **Execution Failure:** Graceful degradation, manual intervention alerts
- **Protocol Adapter Issues:** Continue with available adapters

## Enhanced File Structure & Implementation Roadmap

### Phase 2A: Protocol Adapter Layer
```
scripts/pendle-optimization/adapters/
├── __init__.py
├── base_adapter.py                    # Abstract base class for all adapters
├── pendle_adapter.py                  # Enhanced Pendle protocol adapter
├── pancakeswap_adapter.py            # PancakeSwap farms/pools adapter
└── lita_adapter.py                   # Lita protocol adapter (future)
```

### Phase 2B: Core Engine Components  
```
scripts/pendle-optimization/core/
├── __init__.py
├── portfolio_state_manager.py        # Portfolio holdings and state tracking
├── generalized_optimizer.py          # Cross-protocol optimization engine
├── rebalancing_planner.py            # Sequential rebalancing logic
└── run_optimization.py               # Main optimization entry point
```

### Phase 2C: Integration Layer
```
scripts/pendle-optimization/integration/
├── execution_coordinator.ts          # Enhanced TypeScript execution
├── portfolio_monitor.ts              # Real-time portfolio tracking
└── performance_analyzer.ts           # APY realization analysis
```

### Phase 2D: Configuration & Utilities
```
scripts/pendle-optimization/
├── config/
│   ├── optimization_config.json      # System configuration
│   └── protocol_addresses.json       # Contract addresses per chain
├── output/
│   ├── rebalancing_plan.json         # Generated rebalancing plan
│   └── execution_log.json            # Execution history and results
└── utils/
    ├── price_oracle.py               # Price data utilities
    └── validation.py                 # Data validation helpers
```

## Implementation Priority Roadmap

### ✅ **Phase 1: Foundation** (Complete)
- Pendle strategy algorithm with 40/30/20/10 allocation
- Reward claiming scripts working via Gnosis Safe  
- Market analysis and APY optimization for Pendle

### 🔄 **Phase 2A: Adapter Pattern** (Current Priority)
1. **Base Adapter Interface** - Abstract class with standardized methods
2. **Enhanced Pendle Adapter** - Refactor existing strategy.py into adapter pattern  
3. **Price Impact Integration** - Enso API integration for liquidity analysis
4. **Token Standardization** - Common output format across all adapters

### 🔄 **Phase 2B: Portfolio Intelligence** (Next)
1. **Portfolio State Manager** - Real-time holdings tracking via blockchain calls
2. **Anti-Over-Rebalancing** - Deviation thresholds and cost-benefit analysis  
3. **Generalized Optimizer** - Cross-protocol token selection and allocation
4. **Sequential Planning** - One-token-at-a-time rebalancing strategy

### 🔄 **Phase 2C: Enhanced Execution** (Final)
1. **Execution Coordinator** - Enso-only routing with Gnosis Safe integration
2. **Performance Monitoring** - APY realization and execution cost tracking
3. **Error Handling** - Graceful degradation and recovery mechanisms
4. **Integration Testing** - End-to-end validation with real portfolio

## Testing Strategy & Validation

### Protocol Adapter Testing
- **Mock vs Real Data** - Validate adapter output consistency
- **Price Impact Accuracy** - Compare Enso API results with execution reality
- **Cross-Protocol Comparison** - Ensure fair APY comparisons across protocols
- **Error Resilience** - Test adapter behavior with API failures

### Optimization Engine Testing  
- **Portfolio State Accuracy** - Validate blockchain data fetching
- **Rebalancing Logic** - Test deviation calculations and threshold triggers
- **Sequential Planning** - Verify one-token-at-a-time constraint handling
- **Performance Simulation** - Backtest optimization decisions

### Integration Testing
- **End-to-End Flow** - Python analysis → JSON output → TypeScript execution
- **Gnosis Safe Execution** - Validate transaction signing and execution
- **Error Recovery** - Test partial execution failures and rollback  
- **Performance Monitoring** - Real portfolio tracking and APY validation

## Success Metrics & KPIs

### Technical Success
- **Modularity Achievement** - Easy addition of new protocol adapters
- **Execution Efficiency** - < 2% average price impact on rebalancing  
- **System Reliability** - 99%+ successful rebalancing execution rate
- **Portfolio Responsiveness** - < 5 minute analysis-to-execution time

### Financial Performance  
- **APY Optimization** - Consistent achievement of projected returns
- **Cost Efficiency** - Gas costs < 1% of rebalancing amounts
- **Risk Management** - Maximum drawdown within acceptable limits  
- **Diversification Benefit** - Cross-protocol risk distribution effectiveness

---

## Immediate Next Steps (Phase 2A Implementation)

### Week 1: Base Adapter Infrastructure
1. ✅ **Architecture Planning Complete** - Enhanced multi-protocol design finalized
2. 🔄 **Base Adapter Interface** - Create `base_adapter.py` with standardized methods
3. 🔄 **Pendle Adapter Migration** - Refactor existing `strategy.py` into adapter pattern
4. 🔄 **Price Impact Integration** - Add Enso API integration for liquidity checking

### Week 2: Portfolio State Management  
1. 🔄 **Portfolio State Manager** - Implement blockchain data fetching
2. 🔄 **Anti-Over-Rebalancing Logic** - Add deviation thresholds and cooldowns
3. 🔄 **Testing Framework** - Create unit tests for core components
4. 🔄 **Configuration System** - Set up JSON-based configuration management

### Week 3: Generalized Optimization
1. 🔄 **Cross-Protocol Optimizer** - Implement generalized token selection  
2. 🔄 **Sequential Rebalancing** - Add one-token-at-a-time planning logic
3. 🔄 **Additional Protocol Adapters** - Begin PancakeSwap adapter implementation
4. 🔄 **Integration Testing** - Test Python → JSON output pipeline

### Week 4: Enhanced Execution System
1. 🔄 **Execution Coordinator** - Implement TypeScript execution layer
2. 🔄 **Gnosis Safe Integration** - Enhance with sequential transaction support
3. 🔄 **End-to-End Testing** - Complete Python → TypeScript → Blockchain flow
4. 🔄 **Performance Monitoring** - Add execution tracking and APY validation

## Long-term Roadmap (Post Phase 2)

### Phase 3: Advanced Features (Month 2)
- **Dynamic Allocation Weights** - ML-driven optimization beyond 40/30/20/10
- **Risk-Adjusted Returns** - Sharpe ratio and volatility considerations  
- **Multi-Chain Support** - Expand beyond BSC to Ethereum, Arbitrum, etc.
- **Advanced Monitoring** - Real-time dashboards and alerting systems

### Phase 4: Production Scaling (Month 3)
- **High-Frequency Optimization** - Intraday rebalancing capabilities
- **Institutional Features** - Multi-vault management and reporting
- **API Integration** - External portfolio management platform integration
- **Automated Governance** - DAO-style decision making for strategy updates

**The enhanced foundation enables unlimited protocol expansion and intelligent portfolio management. Ready to build the future of cross-protocol DeFi optimization.**
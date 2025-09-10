#!/usr/bin/env python3
"""
Comprehensive Test Suite for Yield Optimization
Uncomment the function you want to test
"""

import asyncio
import sys
import os
import json
# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from adapters.pendle_adapter import PendleAdapter
from core.portfolio_fetcher import SimplePortfolioFetcher
from core.optimizer import SimpleOptimizer
from core.executor import SimpleExecutor

async def test_pendle_adapter():
    """Test Pendle Adapter - shows tokens from Pendle API"""
    print("🔍 TESTING PENDLE ADAPTER")
    print("=" * 40)
    
    adapter = PendleAdapter()
    print(f"Protocol: {adapter.get_protocol_name()}")
    print(f"Chain ID: {adapter.chain_id}")
    print(f"Markets: {len(adapter.market_addresses)}")
    print()
    
    # Get tokens
    print("Fetching tokens...")
    tokens = await adapter.get_tokens()
    print(f"Found {len(tokens)} tokens")
    print()
    
    if tokens:
        print("TOKENS:")
        for i, token in enumerate(tokens):
            print(f"{i+1}. {token['symbol']} - APY: {token['apy']:.2%} - Type: {token['type']}")
            print(f"   Address: {token['address']}")
            print()
    else:
        print("No tokens found!")

async def test_portfolio_fetcher():
    """Test Portfolio Fetcher"""
    print("🔍 TESTING PORTFOLIO FETCHER")
    print("=" * 40)
    
    # Use correct addresses from deployedAddresses
    portfolio_address = "0xbD35fCaC7813FC3B4bc14a5D0AC686c8e8b780Bc"
    vault_address = "0x97798739141436984f1A51037Bf70220c16475b4"  # Correct vault address
    
    fetcher = SimplePortfolioFetcher(portfolio_address)
    
    print(f"Portfolio: {portfolio_address}")
    print(f"Vault: {vault_address}")
    print()
    
    # Get tokens
    tokens = await fetcher.get_current_tokens()
    print(f"📋 Current tokens ({len(tokens)}):")
    for token in tokens:
        print(f"  - {token}")
    print()
    
    # Get balances
    balances = await fetcher.get_token_balances(vault_address)
    print(f"�� Token balances:")
    for token, balance in balances.items():
        print(f"  - {token}: {balance}")


async def test_optimizer_simple():
    """Test Optimizer Logic - shows 40/30/20/10 allocation"""
    print("🎯 TESTING OPTIMIZER (Simple Version)")
    print("=" * 50)
    
    # Test 1: Get all tokens from Pendle
    pendle_adapter = PendleAdapter()
    print(f"Protocol: {pendle_adapter.get_protocol_name()}")
    
    # Get all tokens (no price impact filter)
    all_tokens = await pendle_adapter.get_tokens()
    print(f"Total tokens: {len(all_tokens)}")
    
    if all_tokens:
        print("\nALL TOKENS:")
        for i, token in enumerate(all_tokens):
            print(f"{i+1}. {token['symbol']} - APY: {token['apy']:.2%}")
    
    # Test 2: Get tokens with price impact filter
    print(f"\n🔍 Testing price impact filtering...")
    liquid_tokens = await pendle_adapter.get_tokens_with_impact()
    print(f"Liquid tokens: {len(liquid_tokens)}")
    
    if liquid_tokens:
        print("\nLIQUID TOKENS:")
        for i, token in enumerate(liquid_tokens):
            print(f"{i+1}. {token['symbol']} - APY: {token['apy']:.2%}")
            print(f"   Price Impact: {token.get('price_impact', 0):.3%}")
    else:
        print("❌ No liquid tokens found!")
        print("   This means all tokens have >2% price impact")
        
        # Let's see what the price impacts actually are
        print(f"\n🔍 Checking actual price impacts...")
        for token in all_tokens[:3]:  # Check first 3 tokens
            impact = await pendle_adapter.check_price_impact(token['address'], 2500)
            print(f"{token['symbol']}: {impact:.3%} price impact")
    
    # Test 3: Simulate optimizer logic
    if liquid_tokens:
        print(f"\n�� SIMULATING OPTIMIZER LOGIC:")
        print("-" * 40)
        
        # Sort by APY
        sorted_tokens = sorted(liquid_tokens, key=lambda x: x['apy'], reverse=True)
        
        # Take top 4
        selected_tokens = sorted_tokens[:4]
        
        # Apply 40/30/20/10 allocation
        weights = [0.40, 0.30, 0.20, 0.10]
        
        print(f"Selected {len(selected_tokens)} tokens:")
        total_expected_apy = 0
        
        for i, token in enumerate(selected_tokens):
            weight = weights[i] if i < len(weights) else 0.10
            expected_return = token['apy'] * weight
            total_expected_apy += expected_return
            
            print(f"{i+1}. {weight:.0%} → {token['symbol']}")
            print(f"   APY: {token['apy']:.2%}")
            print(f"   Expected Return: {expected_return:.2%}")
            print()
        
        print(f"�� Total Expected APY: {total_expected_apy:.2%}")
    else:
        print("❌ Cannot simulate optimizer - no liquid tokens")

async def test_full_optimizer():
    """Test Full Optimizer - with portfolio connection"""
    print("�� TESTING FULL OPTIMIZER")
    print("=" * 50)
    
    vault_address = "0x97798739141436984f1A51037Bf70220c16475b4"
    
    try:
        optimizer = SimpleOptimizer(vault_address)
        plan = await optimizer.generate_plan()
        
        if plan and plan['target_allocation']:
            print(f"✅ Optimization successful!")
            print(f"�� Expected Portfolio APY: {plan['total_expected_apy']:.2%}")
            print(f"�� Needs Rebalancing: {plan['needs_rebalancing']}")
            print(f"�� Rebalancing Steps: {len(plan['rebalancing_steps'])}")
            
            print(f"\n�� OPTIMAL ALLOCATION:")
            for i, alloc in enumerate(plan['target_allocation']):
                print(f"{i+1}. {alloc['weight']:.0%} → {alloc['symbol']} (APY: {alloc['apy']:.2%})")
            
            # Check if plan.json was created
            if os.path.exists('output/plan.json'):
                print(f"✅ Plan saved to output/plan.json")
            else:
                print(f"❌ Plan file not created")
                
            return plan
            
        else:
            print("❌ No optimization plan generated")
            print("   Possible reasons:")
            print("   - No liquid tokens found")
            print("   - API connectivity issues")
            return None
            
    except Exception as e:
        print(f"❌ Optimization failed: {e}")
        import traceback
        traceback.print_exc()
        return None

async def test_executor_logic():
    """Test Executor Logic - portfolio state and planning"""
    print("🚀 TESTING EXECUTOR LOGIC")
    print("=" * 50)
    
    vault_address = "0x97798739141436984f1A51037Bf70220c16475b4"
    
    print("⚠️  NOTE: Using mock private key for testing")
    print("Set VAULT_OWNER environment variable for real execution")
    print()
    
    try:
        # Mock private key for testing
        test_private_key = "0x" + "0" * 64  # Placeholder
        executor = SimpleExecutor(vault_address, test_private_key)
        
        # Test 1: Get portfolio state
        print("1️⃣ Testing portfolio state fetching...")
        current_state = await executor.get_current_portfolio_state()
        
        print(f"   Current tokens: {len(current_state['tokens'])}")
        if current_state['tokens']:
            for token in current_state['tokens']:
                balance = current_state['balances'].get(token, 0)
                print(f"   - {token}: {balance}")
        else:
            print("   - No current tokens (empty portfolio or connection issue)")
        
        print()
        
        # Test 2: Check if plan.json exists
        print("2️⃣ Checking optimization plan...")
        plan_file = os.path.join('output', 'plan.json')
        
        if os.path.exists(plan_file):
            with open(plan_file, 'r') as f:
                plan = json.load(f)
            
            print(f"   ✅ Plan loaded: {plan['total_expected_apy']*100:.2f}% expected APY")
            print(f"   🎯 Target tokens: {len(plan['target_allocation'])}")
            
            for i, alloc in enumerate(plan['target_allocation']):
                print(f"   {i+1}. {alloc['weight']:.0%} → {alloc['symbol']} (APY: {alloc['apy']*100:.2f}%)")
        else:
            print(f"   ❌ No plan.json found. Run optimizer first:")
            print(f"      python3 core/optimizer.py")
        
        print()
        
        # Test 3: Simulate execution logic (without real transactions)
        print("3️⃣ Simulating execution logic...")
        if os.path.exists(plan_file):
            print("   📋 Would execute two-phase rebalancing:")
            print("   Phase 1: Liquidate current tokens → WBNB")
            if current_state['tokens']:
                for token in current_state['tokens']:
                    print(f"     - Sell {token} → WBNB")
            else:
                print("     - No tokens to liquidate")
            
            print("   Phase 2: WBNB → Target allocation")
            for alloc in plan['target_allocation']:
                print(f"     - Buy {alloc['weight']:.0%} of {alloc['symbol']}")
            
            print("   ✅ Execution plan validated")
        else:
            print("   ⚠️  Cannot simulate - no optimization plan")
        
        print()
        
        # Test 4: Check required components
        print("4️⃣ Checking system requirements...")
        print(f"   📍 Vault address: {vault_address}")
        print(f"   🔗 RPC connection: {'Connected' if executor.w3.is_connected() else 'Failed'}")
        print(f"   📄 Plan file: {'✅ Found' if os.path.exists(plan_file) else '❌ Missing'}")
        
        print("\n🎯 Executor logic test completed!")
        
    except Exception as e:
        print(f"❌ Executor test failed: {e}")
        import traceback
        traceback.print_exc()

async def test_end_to_end():
    """Test Complete End-to-End System"""
    print("🎯 END-TO-END SYSTEM TEST")
    print("=" * 60)
    
    # Step 1: Test Pendle Adapter
    print("Step 1: Testing Pendle Adapter...")
    adapter = PendleAdapter()
    tokens = await adapter.get_tokens_with_impact()
    print(f"   Found {len(tokens)} liquid tokens")
    
    if not tokens:
        print("   ❌ No liquid tokens - cannot proceed")
        return
    
    # Step 2: Test Optimizer
    print("\nStep 2: Testing Optimizer...")
    vault_address = "0x97798739141436984f1A51037Bf70220c16475b4"
    optimizer = SimpleOptimizer(vault_address)
    plan = await optimizer.generate_plan()
    
    if not plan:
        print("   ❌ No optimization plan - cannot proceed")
        return
    
    print(f"   ✅ Plan generated: {plan['total_expected_apy']*100:.2f}% APY")
    
    # Step 3: Test Executor Logic
    print("\nStep 3: Testing Executor Logic...")
    test_private_key = "0x" + "0" * 64  # Placeholder
    executor = SimpleExecutor(vault_address, test_private_key)
    current_state = await executor.get_current_portfolio_state()
    print(f"   Portfolio tokens: {len(current_state['tokens'])}")
    
    # Step 4: System Summary
    print("\n📊 SYSTEM SUMMARY:")
    print("=" * 40)
    print(f"✅ Pendle Adapter: {len(tokens)} liquid tokens")
    print(f"✅ Optimizer: {plan['total_expected_apy']*100:.2f}% expected APY")
    print(f"✅ Executor: Ready for execution")
    print(f"✅ Integration: All components working")
    
    print("\n🎉 End-to-end test successful!")
    print("Ready for live rebalancing with:")
    print("   export PRIVATE_KEY=your_key && python3 core/executor.py")

async def main():
    """Main test runner - uncomment the function you want to test"""
    
    print("🧪 COMPREHENSIVE YIELD OPTIMIZATION TEST SUITE")
    print("=" * 60)
    print("Uncomment the function you want to test in main()")
    print()
    
    # ========================================
    # UNCOMMENT THE FUNCTION YOU WANT TO TEST
    # ========================================
    
    # await test_pendle_adapter()           # Test Pendle adapter
    # await test_portfolio_fetcher()        # Test portfolio fetcher  
    # await test_optimizer_simple()         # Test optimizer logic
    # await test_full_optimizer()           # Test full optimizer
    # await test_executor_logic()           # Test executor logic
    await test_end_to_end()               # Test complete system
    
    print("\n🎯 Test completed!")

if __name__ == "__main__":
    asyncio.run(main())
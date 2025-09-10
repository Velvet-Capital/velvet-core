#!/bin/bash

# Yield Optimization Runner
# Single command to run everything together

echo "🚀 YIELD OPTIMIZATION SYSTEM"
echo "=============================="
echo "Running cross-protocol optimization with live data"
echo ""

# Check if we're in the right directory
if [ ! -f "core/optimizer.py" ]; then
    echo "❌ Error: Run this script from the yield-optimization directory"
    echo "   Usage: cd scripts/yield-optimization && ./run_optimization.sh"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p output

echo "1️⃣ Testing with live Pendle API data..."
echo "--------------------------------------"
python3 test_live.py

echo ""
echo "2️⃣ Running optimization..."
echo "-------------------------"
python3 core/optimizer.py

echo ""
echo "3️⃣ Checking results..."
echo "----------------------"

if [ -f "output/plan.json" ]; then
    echo "✅ Optimization plan generated: output/plan.json"
    echo ""
    echo "📊 Quick Summary:"
    echo "-----------------"
    
    # Extract key info from JSON using Python
    python3 -c "
import json
try:
    with open('output/plan.json', 'r') as f:
        plan = json.load(f)
    print(f\"📈 Expected APY: {plan['total_expected_apy']:.2%}\")
    print(f\"🔄 Needs Rebalancing: {plan['needs_rebalancing']}\")
    print(f\"📝 Steps Required: {len(plan['rebalancing_steps'])}\")
    print(f\"🏗️ Protocols: {', '.join(plan['optimization_summary']['protocols_used'])}\")
    print(f\"🎯 Top APY: {plan['optimization_summary']['top_apy']:.2%}\")
except Exception as e:
    print(f'❌ Could not read plan: {e}')
"

    echo ""
    echo "4️⃣ Next Steps:"
    echo "--------------"
    echo "✅ Plan ready for execution"
    echo "📋 To execute: npx ts-node core/executor.ts"
    echo "📄 Full plan: cat output/plan.json"
    echo ""
    
else
    echo "❌ No optimization plan generated"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "-------------------"
    echo "• Check internet connection"
    echo "• Install dependencies: pip3 install web3 aiohttp"
    echo "• Try running: python3 test_live.py"
    echo ""
fi

echo "🎯 Optimization complete!"
echo "========================="
#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "Importing Supabase tools into watsonx Orchestrate"
echo "=================================================="
echo ""

# 1. Connection configuration
echo "1️⃣  Configuring the Supabase connection..."
./scripts/configure_supabase_connection.sh
echo ""

# 2. Remove old tools (if any)
echo "2️⃣  Removing old Supabase tools (if any)..."
TOOL_NAMES=$(orchestrate tools list 2>/dev/null | grep -E '^(get_spare_part|list_low_stock_parts|list_orders_for_part|propose_supplier_order|create_supplier_order)' | awk '{print $1}' || true)

if [ -n "$TOOL_NAMES" ]; then
    echo "$TOOL_NAMES" | while read -r tool_name; do
        echo "   Removing $tool_name..."
        orchestrate tools remove --name "$tool_name" || true
    done
else
    echo "   No existing Supabase tools found"
fi
echo ""

# 3. Import the new tools
echo "3️⃣  Importing Supabase tools..."
orchestrate tools import \
    --kind python \
    --file tools/supabase_tools.py \
    --app-id supabase_conn \
    --requirements-file tools/requirements.txt

echo ""
echo "4️⃣  Verifying imported tools..."
orchestrate tools list | grep -E '(spare_part|supplier_order|low_stock)' | awk '{print "   ✓ " $1}'

echo ""
echo "✅ Supabase tools imported successfully!"
echo ""
echo "Available tools:"
echo "  📖 Read:"
echo "     - get_spare_part          : Look up a spare part"
echo "     - list_low_stock_parts    : List parts that are out of stock"
echo "     - list_orders_for_part    : List orders for a part"
echo "  ✍️  Write (2-step workflow):"
echo "     - propose_supplier_order  : Propose a supplier order"
echo "     - create_supplier_order   : Create the order (after confirmation)"
echo ""

# Made with Bob

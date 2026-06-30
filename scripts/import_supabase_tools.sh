#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "Import des outils Supabase dans watsonx Orchestrate"
echo "=================================================="
echo ""

# 1. Configuration de la connexion
echo "1️⃣  Configuration de la connexion Supabase..."
./scripts/configure_supabase_connection.sh
echo ""

# 2. Suppression des anciens outils (si existants)
echo "2️⃣  Suppression des anciens outils Supabase (si existants)..."
TOOL_NAMES=$(orchestrate tools list 2>/dev/null | grep -E '^(get_spare_part|list_low_stock_parts|list_orders_for_part|propose_supplier_order|create_supplier_order)' | awk '{print $1}' || true)

if [ -n "$TOOL_NAMES" ]; then
    echo "$TOOL_NAMES" | while read -r tool_name; do
        echo "   Suppression de $tool_name..."
        orchestrate tools remove --name "$tool_name" || true
    done
else
    echo "   Aucun outil Supabase existant trouvé"
fi
echo ""

# 3. Import des nouveaux outils
echo "3️⃣  Import des outils Supabase..."
orchestrate tools import \
    --kind python \
    --file tools/supabase_tools.py \
    --app-id supabase_conn \
    --requirements-file tools/requirements.txt

echo ""
echo "4️⃣  Vérification des outils importés..."
orchestrate tools list | grep -E '(spare_part|supplier_order|low_stock)' | awk '{print "   ✓ " $1}'

echo ""
echo "✅ Import des outils Supabase terminé avec succès !"
echo ""
echo "Outils disponibles :"
echo "  📖 Lecture :"
echo "     - get_spare_part          : Consulter une pièce détachée"
echo "     - list_low_stock_parts    : Lister les pièces en rupture de stock"
echo "     - list_orders_for_part    : Lister les commandes pour une pièce"
echo "  ✍️  Écriture (workflow en 2 temps) :"
echo "     - propose_supplier_order  : Proposer une commande fournisseur"
echo "     - create_supplier_order   : Créer la commande (après confirmation)"
echo ""

# Made with Bob

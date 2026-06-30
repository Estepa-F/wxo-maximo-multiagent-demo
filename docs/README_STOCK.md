# 📦 Agent de Gestion du Stock - Guide Complet

## Vue d'ensemble

L'agent `maximo_stock_agent` gère l'inventaire des pièces détachées via Supabase. Il permet de :
- ✅ Vérifier la disponibilité des pièces
- ✅ Identifier les ruptures de stock
- ✅ Passer des commandes fournisseur (avec confirmation)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   maximo_orchestrator                        │
│  (Point d'entrée - route vers les agents spécialisés)       │
└────────────┬────────────────────────────────────────────────┘
             │
             ├─→ maximo_diagnostic_agent (lecture Maximo)
             ├─→ maximo_planning_agent (écriture Maximo)
             └─→ maximo_stock_agent (gestion stock Supabase)
                      │
                      ├─→ get_spare_part
                      ├─→ list_low_stock_parts
                      ├─→ list_orders_for_part
                      ├─→ propose_supplier_order
                      └─→ create_supplier_order
```

## 🔧 Configuration

### 1. Connexion Supabase

La connexion est déjà configurée dans `connections/supabase_conn.yaml` :

```yaml
name: supabase_conn
kind: api_key
description: Connexion à l'inventaire Supabase
```

### 2. Import des outils et de l'agent

```bash
# Import automatique (recommandé)
./scripts/import_supabase_tools.sh

# Ou manuellement
orchestrate tools import \
    --kind python \
    --path tools/supabase_tools.py \
    --app-id supabase_conn \
    --requirements-file tools/requirements.txt

orchestrate agents import --path agents/maximo_stock_agent.yaml
orchestrate agents import --path agents/maximo_orchestrator.yaml
```

## 📚 Outils disponibles

### 🔍 Outils de lecture

#### `get_spare_part`
Consulte une pièce détachée par sa référence.

**Paramètres :**
- `reference` (str) : Référence de la pièce (ex: "DRV-100-AS")

**Retour :**
```python
{
    "reference": "DRV-100-AS",
    "description": "Drive belt 100mm AS type",
    "stock_qty": 3,
    "min_stock": 5,
    "location": "Warehouse A-12",
    "supplier": "Industrial Parts Co.",
    "unit_price": 45.50,
    "lead_time_days": 7,
    "is_in_stock": true,
    "is_below_min": true  # ⚠️ Rupture de stock !
}
```

#### `list_low_stock_parts`
Liste toutes les pièces en rupture de stock (stock_qty ≤ min_stock).

**Retour :** Liste de pièces avec les mêmes champs que `get_spare_part`.

#### `list_orders_for_part`
Liste les commandes fournisseur pour une pièce.

**Paramètres :**
- `reference` (str) : Référence de la pièce

**Retour :**
```python
[
    {
        "id": 123,
        "reference": "DRV-100-AS",
        "quantity": 10,
        "supplier": "Industrial Parts Co.",
        "unit_price": 45.50,
        "total_amount": 455.00,
        "status": "PENDING",
        "related_wonum": "WO12345",
        "created_at": "2026-06-01T10:00:00Z",
        "expected_delivery": "2026-06-08"
    }
]
```

### ✍️ Outils d'écriture (workflow en 2 temps)

#### `propose_supplier_order`
**PREMIÈRE ÉTAPE** : Génère une proposition de commande (DRY-RUN).

**Paramètres :**
- `reference` (str) : Référence de la pièce
- `quantity` (int) : Quantité à commander (défaut: 1)
- `related_wonum` (str, optionnel) : Work order Maximo associée

**Retour :**
```python
{
    "summary": """
Proposition de commande fournisseur — à confirmer :
  • Référence       : DRV-100-AS (Drive belt 100mm AS type)
  • Quantité        : 10
  • Fournisseur     : Industrial Parts Co.
  • Prix unitaire   : 45.50 €
  • Montant total   : 455.00 €
  • Délai           : 7 jour(s)
  • Livraison prévue: 2026-06-08
  • WO associée     : WO12345

Confirmez-vous la commande ? (oui / non)
    """,
    "reference": "DRV-100-AS",
    "quantity": 10,
    "supplier": "Industrial Parts Co.",
    "unit_price": 45.50,
    "total_amount": 455.00,
    "lead_time_days": 7,
    "expected_delivery": "2026-06-08",
    "related_wonum": "WO12345",
    "requires_confirmation": true
}
```

#### `create_supplier_order`
**DEUXIÈME ÉTAPE** : Crée réellement la commande (après confirmation).

⚠️ **Ne JAMAIS appeler directement** - toujours passer par `propose_supplier_order` d'abord.

**Paramètres :** Identiques à `propose_supplier_order`

**Retour :** La commande créée avec son ID.

## 🎯 Exemples d'utilisation

### Exemple 1 : Vérifier une pièce avant de créer une WO

**Utilisateur :** "Vérifie si on a la pièce DRV-100-AS en stock"

**Orchestrateur** → délègue à `maximo_stock_agent`

**Stock agent :**
```python
get_spare_part(reference="DRV-100-AS")
# → stock_qty=3, min_stock=5, is_below_min=true
```

**Réponse :** "La pièce DRV-100-AS est disponible (3 unités) mais en dessous du seuil de réapprovisionnement (minimum: 5). Souhaitez-vous passer une commande fournisseur ?"

### Exemple 2 : Lister les ruptures de stock

**Utilisateur :** "Quelles pièces sont en rupture de stock ?"

**Stock agent :**
```python
list_low_stock_parts()
# → [DRV-100-AS, JC-T21-EPDM-32, ...]
```

**Réponse :** Liste formatée avec quantités et seuils.

### Exemple 3 : Passer une commande (workflow complet)

**Utilisateur :** "Commande 10 unités de DRV-100-AS pour la WO12345"

**Stock agent - Étape 1 :**
```python
propose_supplier_order(
    reference="DRV-100-AS",
    quantity=10,
    related_wonum="WO12345"
)
```

**Réponse :** Affiche le résumé avec prix, délai, etc. + "Confirmez-vous ?"

**Utilisateur :** "Oui, confirme"

**Stock agent - Étape 2 :**
```python
create_supplier_order(
    reference="DRV-100-AS",
    quantity=10,
    related_wonum="WO12345"
)
```

**Réponse :** "Commande #123 créée avec succès. Livraison prévue le 2026-06-08."

### Exemple 4 : Workflow cross-système

**Utilisateur :** "Crée une WO pour remplacer la courroie de la pompe P-001"

**Orchestrateur :**
1. Délègue à `maximo_diagnostic_agent` → trouve que P-001 utilise la pièce DRV-100-AS
2. Délègue à `maximo_stock_agent` → vérifie le stock (3 unités, en rupture)
3. Informe l'utilisateur : "La pièce est disponible mais en rupture. Voulez-vous créer la WO et commander des pièces ?"
4. Si oui → délègue à `maximo_planning_agent` pour la WO + `maximo_stock_agent` pour la commande

## 🔐 Sécurité

- La connexion Supabase utilise l'**ANON KEY** (clé publique)
- Les Row Level Security (RLS) policies de Supabase contrôlent les accès
- Les credentials sont stockés dans la connexion `supabase_conn`
- Jamais de credentials en dur dans le code

## 🧪 Tests

```bash
# Test de la connexion
orchestrate connections list | grep supabase

# Test des outils
orchestrate tools list | grep -E "(spare_part|supplier_order|low_stock)"

# Test de l'agent
orchestrate agents chat --name maximo_stock_agent
> Quelles pièces sont en rupture de stock ?
```

## 📊 Modèle de données Supabase

### Table `spare_parts`
```sql
CREATE TABLE spare_parts (
    reference TEXT PRIMARY KEY,
    description TEXT,
    stock_qty INTEGER NOT NULL,
    min_stock INTEGER NOT NULL,
    location TEXT,
    supplier TEXT,
    unit_price NUMERIC(10,2),
    lead_time_days INTEGER
);
```

### Table `supplier_orders`
```sql
CREATE TABLE supplier_orders (
    id SERIAL PRIMARY KEY,
    reference TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    supplier TEXT NOT NULL,
    unit_price NUMERIC(10,2),
    total_amount NUMERIC(10,2),
    status TEXT NOT NULL,
    related_wonum TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    expected_delivery DATE
);
```

## 🚀 Déploiement

```bash
# 1. Configurer la connexion
./scripts/configure_supabase_connection.sh

# 2. Importer les outils
./scripts/import_supabase_tools.sh

# 3. Importer tous les agents (y compris l'orchestrateur mis à jour)
./scripts/import_all_agents.sh

# 4. Tester
orchestrate agents chat --name maximo_orchestrator
> Vérifie le stock de la pièce DRV-100-AS
```

## 📝 Notes importantes

1. **Pattern de confirmation** : Toujours `propose` → confirmation → `create`
2. **Routage automatique** : L'orchestrateur détecte les mots-clés "pièce", "stock", "disponibilité"
3. **Cross-système** : L'orchestrateur peut coordonner Maximo + Supabase dans une même conversation
4. **Pas d'invention** : L'agent ne doit JAMAIS inventer de données - uniquement utiliser les tools

## 🔗 Fichiers associés

- `tools/supabase_tools.py` - Implémentation des outils
- `agents/maximo_stock_agent.yaml` - Configuration de l'agent
- `agents/maximo_orchestrator.yaml` - Orchestrateur mis à jour
- `connections/supabase_conn.yaml` - Connexion Supabase
- `scripts/import_supabase_tools.sh` - Script d'import automatique
- `scripts/configure_supabase_connection.sh` - Configuration de la connexion
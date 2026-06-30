# 🚀 Guide de Déploiement Complet

## Vue d'ensemble

Ce guide explique comment déployer l'architecture complète Maximo + Stock dans watsonx Orchestrate.

## Architecture déployée

```
┌─────────────────────────────────────────────────────────────┐
│                   maximo_orchestrator                        │
│         (Point d'entrée - routage intelligent)               │
└────────────┬────────────────────────────────────────────────┘
             │
             ├─→ maximo_diagnostic_agent (5 outils Maximo)
             │   - search_assets_by_keyword
             │   - get_work_orders_for_asset
             │   - get_worklogs_for_workorder
             │   - list_asset_attachments
             │   - get_attachment_text
             │
             ├─→ maximo_planning_agent (2 outils Maximo)
             │   - propose_work_order
             │   - create_work_order
             │
             └─→ maximo_stock_agent (5 outils Supabase)
                 - get_spare_part
                 - list_low_stock_parts
                 - list_orders_for_part
                 - propose_supplier_order
                 - create_supplier_order
```

## Prérequis

### 1. Fichier de configuration

Créez le fichier `.env.sdk` à partir de `.env.sdk.exemple` :

```bash
cp .env.sdk.exemple .env.sdk
```

Remplissez les valeurs :

```bash
# watsonx Orchestrate
ORCHESTRATE_API_KEY=your_orchestrate_api_key
ORCHESTRATE_URL=https://your-instance.watson-orchestrate.ibm.com

# Maximo
MAXIMO_URL=https://your-maximo-instance.com
MAXIMO_API_KEY=your_maximo_api_key

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 2. Dépendances Python

Les dépendances sont listées dans `tools/requirements.txt` :
- `requests`
- `pydantic`
- `ibm-watsonx-orchestrate` (installé automatiquement par le SDK)

## 🚀 Déploiement automatique (recommandé)

### Option 1 : Script complet

Déployez tout en une seule commande :

```bash
./scripts/deploy_complete.sh
```

Ce script effectue automatiquement :
1. ✅ Configuration des connexions (Maximo + Supabase)
2. ✅ Import des outils Maximo (7 outils)
3. ✅ Import des outils Supabase (5 outils)
4. ✅ Import des agents (4 agents)
5. ✅ Vérification finale

### Option 2 : Scripts individuels

Si vous préférez déployer étape par étape :

```bash
# 1. Connexions
./scripts/configure_maximo_connection.sh
./scripts/configure_supabase_connection.sh

# 2. Outils
./scripts/reimport_maximo_tools.sh
./scripts/import_supabase_tools.sh

# 3. Agents
./scripts/import_all_agents.sh
```

## 📋 Déploiement manuel

Si vous préférez tout faire manuellement :

### 1. Connexions

```bash
# Maximo
orchestrate connections create --app-id maximo_conn
orchestrate connections import --path connections/maximo_conn.yaml
orchestrate connections configure \
    --app-id maximo_conn \
    --environment draft \
    --type team \
    --kind api_key
orchestrate connections set-credentials \
    --app-id maximo_conn \
    --environment draft \
    --api-key "$MAXIMO_API_KEY"

# Supabase
orchestrate connections create --app-id supabase_conn
orchestrate connections import --path connections/supabase_conn.yaml
orchestrate connections configure \
    --app-id supabase_conn \
    --environment draft \
    --type team \
    --kind api_key
orchestrate connections set-credentials \
    --app-id supabase_conn \
    --environment draft \
    --api-key "$SUPABASE_ANON_KEY"
```

### 2. Outils

```bash
# Maximo
orchestrate tools import \
    --kind python \
    --path tools/maximo_tools.py \
    --app-id maximo_conn \
    --requirements-file tools/requirements.txt

# Supabase
orchestrate tools import \
    --kind python \
    --path tools/supabase_tools.py \
    --app-id supabase_conn \
    --requirements-file tools/requirements.txt
```

### 3. Agents

```bash
# Ordre important : agents spécialisés d'abord, orchestrateur ensuite
orchestrate agents import --path agents/maximo_diagnostic_agent.yaml
orchestrate agents import --path agents/maximo_planning_agent.yaml
orchestrate agents import --path agents/maximo_stock_agent.yaml
orchestrate agents import --path agents/maximo_orchestrator.yaml
```

## ✅ Vérification

### Connexions

```bash
orchestrate connections list | grep -E "(maximo_conn|supabase_conn)"
```

Résultat attendu :
```
maximo_conn    api_key    draft    Connexion à l'API Maximo
supabase_conn  api_key    draft    Connexion à l'inventaire Supabase
```

### Outils

```bash
# Maximo (7 outils)
orchestrate tools list | grep -E "(asset|work_order|worklog|attachment)"

# Supabase (5 outils)
orchestrate tools list | grep -E "(spare_part|supplier_order|low_stock)"
```

### Agents

```bash
orchestrate agents list | grep maximo
```

Résultat attendu :
```
maximo_orchestrator        native    groq/openai/gpt-oss-120b
maximo_diagnostic_agent    native    groq/openai/gpt-oss-120b
maximo_planning_agent      native    groq/openai/gpt-oss-120b
maximo_stock_agent         native    groq/openai/gpt-oss-120b
```

## 🧪 Tests

### Test de l'orchestrateur

```bash
orchestrate agents chat --name maximo_orchestrator
```

### Exemples de commandes

#### 1. Consultation Maximo
```
> Quels sont les work orders de la pompe P-001 ?
```

L'orchestrateur délègue à `maximo_diagnostic_agent`.

#### 2. Consultation Stock
```
> Vérifie le stock de la pièce DRV-100-AS
```

L'orchestrateur délègue à `maximo_stock_agent`.

#### 3. Création de WO simple
```
> Crée une WO pour inspecter la pompe P-001
```

L'orchestrateur délègue à `maximo_planning_agent` qui :
1. Appelle `propose_work_order`
2. Demande confirmation
3. Appelle `create_work_order`

#### 4. Workflow cross-système (LA VALEUR AJOUTÉE !)
```
> Crée une WO pour remplacer la courroie DRV-100-AS sur la pompe P-001
```

L'orchestrateur coordonne :
1. `maximo_stock_agent` → vérifie le stock de DRV-100-AS
2. Informe l'utilisateur du niveau de stock
3. `maximo_planning_agent` → crée la WO
4. Propose de commander des pièces si rupture
5. `maximo_stock_agent` → passe la commande fournisseur (si confirmé)

## 🔄 Mise à jour

Pour mettre à jour après des modifications :

```bash
# Réimporter tout
./scripts/deploy_complete.sh

# Ou seulement les outils
./scripts/reimport_maximo_tools.sh
./scripts/import_supabase_tools.sh

# Ou seulement les agents
./scripts/import_all_agents.sh
```

## 🐛 Dépannage

### Erreur : "Connection not found"

```bash
# Vérifier que les connexions existent
orchestrate connections list

# Reconfigurer si nécessaire
./scripts/configure_maximo_connection.sh
./scripts/configure_supabase_connection.sh
```

### Erreur : "Tool not found"

```bash
# Vérifier que les outils sont importés
orchestrate tools list

# Réimporter si nécessaire
./scripts/reimport_maximo_tools.sh
./scripts/import_supabase_tools.sh
```

### Erreur : "Agent not found"

```bash
# Vérifier que les agents existent
orchestrate agents list

# Réimporter si nécessaire
./scripts/import_all_agents.sh
```

### Erreur d'import Python

Si vous voyez des erreurs d'import (`pydantic`, `requests`, etc.) :

```bash
# Vérifier requirements.txt
cat tools/requirements.txt

# Les dépendances sont installées automatiquement par Orchestrate
# lors de l'import des outils
```

## 📚 Documentation

- **README_CONNECTION.md** : Guide des connexions
- **README_AGENTS.md** : Architecture multi-agents
- **README_STOCK.md** : Agent de gestion du stock
- **README_SUPABASE.md** : Configuration Supabase

## 🎯 Prochaines étapes

1. **Tester les workflows** : Essayez les exemples ci-dessus
2. **Personnaliser les instructions** : Adaptez les agents à vos besoins
3. **Ajouter des outils** : Créez de nouveaux outils si nécessaire
4. **Déployer en production** : Passez de `draft` à `live`

```bash
# Pour déployer en production
orchestrate connections configure --environment live ...
orchestrate agents publish --name maximo_orchestrator
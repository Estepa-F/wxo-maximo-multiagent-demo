# Guide d'installation et de déploiement

Ce guide explique comment déployer l'architecture complète du projet dans WatsonX Orchestrate, depuis l'environnement vide jusqu'à la conversation fonctionnelle avec l'orchestrateur.

## Prérequis

- IBM WatsonX Orchestrate (instance entreprise ou compte développeur)
- Python 3.12+
- Accès aux 4 systèmes externes : ServiceNow, IBM Maximo, Supabase, Slack
- Repo cloné en local

## Vue d'ensemble du déploiement

Le déploiement se fait en 4 étapes, dans cet ordre **impératif** :

```
1. Connections    →  Authentification vers les 4 systèmes externes
2. Tools          →  Code Python publié dans WXO, lié à une connection
3. Agents         →  Définitions YAML des 6 agents, importées dans WXO
4. Test           →  Validation par conversation avec l'orchestrateur
```

Chaque étape dépend de la précédente : un tool ne peut être importé qu'une fois sa connection prête, et un agent ne peut être importé qu'une fois ses tools disponibles.

## Étape 0 — Préparation de l'environnement

```bash
# 1. Cloner le repo
git clone https://github.com/Estepa-F/wxo-maximo-multiagent-demo.git
cd wxo-maximo-multiagent-demo

# 2. Créer un environnement Python virtuel
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# .\venv\Scripts\activate.ps1  # Windows

# 3. Installer le SDK Orchestrate
pip install ibm-watsonx-orchestrate

# 4. Configurer l'environnement Orchestrate
orchestrate env add -n production -u <votre-url-wxo> --activate
orchestrate env activate production

# 5. Préparer le fichier de variables
cp .env.sdk.exemple .env.sdk
# Éditer .env.sdk avec ses propres credentials (cf. connections.md)
```

## Étape 1 — Connections

Le détail complet de chaque connection est dans [`connections.md`](connections.md). Pour un déploiement rapide, lancer les 4 scripts :

```bash
./scripts/configure_maximo_connection.sh
./scripts/configure_servicenow_connection.sh
./scripts/configure_supabase_connection.sh
./scripts/configure_slack_connection.sh
```

Chaque script lit les valeurs nécessaires depuis `.env.sdk` et configure la connection pour l'environnement `draft`.

**Vérification** :

```bash
orchestrate connections list
```

Doit afficher les 4 connections avec leurs types respectifs :

```
maximo_conn       api_key                        draft   Connexion à l'API Maximo
servicenow_conn   oauth_auth_password_flow       draft   Connexion ServiceNow OAuth
supabase_conn     api_key                        draft   Connexion à l'inventaire Supabase
slack_conn        api_key                        draft   Connexion Slack webhook
```

## Étape 2 — Tools Python

Quatre modules Python exposent les opérations métier vers les systèmes externes. Chaque module est lié à sa connection respective via le paramètre `--app-id`.

### Import des 4 modules

```bash
# Tools Maximo (7 outils : search_assets, get_work_orders, get_worklogs,
# list_attachments, get_attachment_text, propose_work_order, create_work_order)
orchestrate tools import \
  -k python \
  -f tools/maximo_tools.py \
  -r tools/requirements.txt \
  --app-id maximo_conn

# Tools ServiceNow (4 outils : get_incident, list_open_incidents,
# propose_incident_update, update_incident)
orchestrate tools import \
  -k python \
  -f tools/servicenow_tools.py \
  -r tools/requirements.txt \
  --app-id servicenow_conn

# Tools Supabase / ERP stock (5 outils : get_spare_part, list_low_stock_parts,
# list_orders_for_part, propose_supplier_order, create_supplier_order)
orchestrate tools import \
  -k python \
  -f tools/supabase_tools.py \
  -r tools/requirements.txt \
  --app-id supabase_conn

# Tools Slack (1 outil : send_incident_summary)
orchestrate tools import \
  -k python \
  -f tools/slack_tools.py \
  -r tools/requirements.txt \
  --app-id slack_conn
```

### Vérification

```bash
orchestrate tools list
```

Doit afficher au total **17 tools** répartis sur les 4 modules.

### Reimport après modification

Si on modifie un fichier `tools/*.py`, il suffit de relancer la commande d'import. Orchestrate écrase la version précédente sans demande de confirmation.

```bash
./scripts/reimport_maximo_tools.sh   # raccourci pour Maximo
```

## Étape 3 — Agents

Les 6 agents sont importés **dans un ordre précis** : d'abord les collaborateurs, ensuite l'orchestrateur qui les référence.

```bash
# 1. Importer les 5 agents spécialistes
orchestrate agents import -f agents/servicenow_ITSM_agent.yaml
orchestrate agents import -f agents/maximo_diagnostic_agent.yaml
orchestrate agents import -f agents/maximo_planning_agent.yaml
orchestrate agents import -f agents/maximo_stock_agent.yaml
orchestrate agents import -f agents/slack_notifier_agent.yaml

# 2. Importer l'orchestrateur (qui référence les 5 ci-dessus)
orchestrate agents import -f agents/maximo_orchestrator.yaml
```

Ou via le script :

```bash
./scripts/import_all_agents.sh
```

### Vérification

```bash
orchestrate agents list | grep -E "(maximo|servicenow|slack)"
```

Doit afficher les 6 agents :

```
maximo_orchestrator         native    groq/openai/gpt-oss-120b
servicenow_ITSM_agent       native    groq/openai/gpt-oss-120b
maximo_diagnostic_agent     native    groq/openai/gpt-oss-120b
maximo_planning_agent       native    groq/openai/gpt-oss-120b
maximo_stock_agent          native    groq/openai/gpt-oss-120b
slack_notifier_agent        native    groq/openai/gpt-oss-120b
```

## Déploiement automatique tout-en-un

Pour un déploiement complet en une seule commande (connections + tools + agents) :

```bash
./scripts/deploy_complete.sh
```

Ce script effectue les étapes 1, 2 et 3 dans l'ordre, en lisant les credentials depuis `.env.sdk`.

## Étape 4 — Test

### Test rapide via CLI

```bash
orchestrate agents chat --name maximo_orchestrator
```

Premier message à essayer :

> Quelle est la disponibilité de la pièce DRV-100-AS en stock ?

Attendu :
1. Routage : `chat_with_collaborator_maximo_stock_agent`
2. Tool : `get_spare_part(reference="DRV-100-AS")`
3. Réponse : "La pièce DRV-100-AS est en rupture de stock (0 unité). Fournisseur Crane Industries, prix 245 €, délai 5 jours."

### Test du parcours complet (12 questions)

Pour rejouer la démo de bout en bout (incident → diagnostic → commande → WO → clôture → cascade Slack), suivre [`scenario-demo.md`](scenario-demo.md).

## Mise à jour

Après modification du code ou des définitions YAML, relancer simplement la commande d'import correspondante :

```bash
# Si on a modifié un tool Python
orchestrate tools import -k python -f tools/<module>.py \
  -r tools/requirements.txt --app-id <conn>

# Si on a modifié un agent YAML
orchestrate agents import -f agents/<agent>.yaml

# Si on a modifié plusieurs choses
./scripts/deploy_complete.sh
```

Les imports sont idempotents : ils écrasent la version précédente.

## Promotion vers la production

Tout le guide ci-dessus utilise l'environnement `draft`. Pour publier en `live` :

```bash
# Pour chaque connection, refaire la configuration et l'injection des credentials
orchestrate connections configure -a <conn> --env live ...
orchestrate connections set-credentials -a <conn> --env live ...

# Puis publier les agents
orchestrate agents publish --name maximo_orchestrator
```

## Dépannage

### `Connection not found` lors de l'import d'un tool

La connection référencée par `--app-id` n'a pas été créée. Revenir à l'étape 1.

### `Agent collaborator not found` lors de l'import de l'orchestrateur

L'un des 5 agents spécialistes n'a pas encore été importé. Relancer dans l'ordre — les spécialistes d'abord, l'orchestrateur ensuite.

### `Tool not found` lors de l'import d'un agent

Le tool référencé dans la liste `tools:` de l'agent YAML n'existe pas dans WXO. Vérifier le nom (cf. `orchestrate tools list`) et relancer l'import du module Python concerné.

### Erreur Python à l'import (`Module not found`, etc.)

Le fichier `tools/requirements.txt` ne liste pas une dépendance utilisée par le code. Vérifier le contenu et ajouter au besoin :

```
requests
pydantic
pypdf
```

### Token ServiceNow expiré pendant un test

Les tokens OAuth ServiceNow expirent par défaut au bout de 30 minutes. Le code des tools le renouvelle automatiquement. Si une vérification cURL échoue, regénérer un token manuellement (cf. [`connections.md`](connections.md)).

### L'orchestrateur affirme une action qui n'a pas été faite

C'est le piège classique du pattern propose / confirm. Vérifier dans Show Reasoning que le tool `*_create` ou `update_*` a bien été appelé (et pas seulement le tool `propose_*`). Si l'agent saute systématiquement le tool d'exécution, renforcer les instructions de l'agent concerné (cf. [`patterns.md`](patterns.md) → règles absolues).

### La cascade Slack ne se déclenche pas à la clôture

Vérifier dans Show Reasoning que :
1. Le retour de `update_incident` contient bien le bloc `⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE`
2. `servicenow_ITSM_agent` a recopié ce bloc intégralement (sans le résumer)
3. L'orchestrateur a bien délégué à `slack_notifier_agent`

Si une étape manque, revoir les instructions des agents concernés.

## Scripts disponibles

Pour référence, les scripts du dossier `scripts/` :

| Script | Rôle |
|--------|------|
| `configure_maximo_connection.sh` | Création + config de la connection Maximo |
| `configure_servicenow_connection.sh` | Idem pour ServiceNow |
| `configure_supabase_connection.sh` | Idem pour Supabase |
| `configure_slack_connection.sh` | Idem pour Slack |
| `create_connections.sh` | Lance les 4 scripts précédents en une fois |
| `reimport_maximo_tools.sh` | Réimporte tools/maximo_tools.py |
| `import_supabase_tools.sh` | Importe tools/supabase_tools.py |
| `import_all_agents.sh` | Importe les 6 agents dans le bon ordre |
| `deploy_complete.sh` | Pipeline complet : connections + tools + agents |

## Prochaines étapes

Une fois l'installation validée :
- Rejouer le [scénario complet en 12 questions](scenario-demo.md)
- Adapter les agents à son propre contexte (instructions, prompts, routage)
- Ajouter d'autres systèmes selon le pattern décrit dans [`architecture.md`](architecture.md)

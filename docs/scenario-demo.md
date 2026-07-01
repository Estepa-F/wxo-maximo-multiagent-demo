# Scénario de démo — 12 questions

Ce document décrit le **scénario complet** à rejouer pour démontrer la valeur de l'architecture multi-agents. Il couvre :

- La préparation des données dans les 4 systèmes (ServiceNow, Maximo, Supabase, Slack)
- Les 12 questions à enchaîner dans l'interface conversationnelle
- Ce qui doit se passer à chaque étape (tools appelés, résultats attendus)
- Le moment "wow" final : la cascade automatique de notification Slack

## Le narratif métier

Une pompe industrielle (asset Maximo `11430`) du site `BEDFORD` présente un bruit anormal. Un opérateur crée un ticket d'incident dans ServiceNow (`INC0010003`). Un manager de maintenance va traiter ce ticket de bout en bout en s'adressant uniquement à l'orchestrateur :

1. Lire le ticket d'incident
2. Consulter l'historique des interventions sur l'asset
3. Lire le guide de maintenance attaché à l'asset
4. Vérifier le stock de la pièce nécessaire
5. Passer la commande fournisseur (la pièce est en rupture)
6. Créer la work order corrective dans Maximo
7. Ajouter une note de progression au ticket
8. Clôturer le ticket en état Résolu
9. ⚡ La notification Slack à l'équipe d'astreinte se déclenche **automatiquement**

Tout cela en moins de 5 minutes, dans une seule conversation, sans jamais quitter l'interface.

---

## Préparation des données

### ServiceNow — Créer l'incident `INC0010003`

```bash
curl -X POST "$SN_INSTANCE_URL/api/now/table/incident" \
  -H "Authorization: Bearer $SN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "short_description": "Bruit anormal et baisse de pression sur la pompe condensat de la salle B2",
    "description": "Operateur signale un bruit anormal sur la pompe de retour de condensat (asset Maximo 11430, site BEDFORD). Pression aspiration basse. Suspicion blocage vanne admission, probleme deja signale en 2011. A investiguer rapidement.",
    "priority": "3",
    "impact": "2",
    "urgency": "2",
    "category": "hardware",
    "state": "1"
  }'
```

⚠️ Le `number` est généré par ServiceNow. Si l'instance a été réinitialisée, ce sera probablement `INC0010003`. Sinon, adapter le numéro dans les questions ci-dessous.

### Supabase — Charger les pièces de rechange

Le fichier `data/supabase_schema.sql` contient le DDL des tables. Pour la démo, charger les 5 pièces de référence avec la `DRV-100-AS` volontairement en rupture (c'est ce qui crée le moment "wow" plus tard) :

```sql
INSERT INTO spare_parts (reference, description, stock_qty, min_stock, location, supplier, unit_price, lead_time_days) VALUES
  ('DRV-100-AS',     'Vanne d''admission Crane',                  0, 1, 'Réserve B2-04', 'Crane Industries',   245.00,  5),
  ('JC-T21-EPDM-32', 'Joint mécanique John Crane Type 21 (EPDM)', 2, 2, 'Réserve B2-01', 'John Crane',          89.50,  3),
  ('SKF-6306-2RS',   'Roulement à billes étanche SKF 6306',       4, 4, 'Réserve B2-02', 'SKF France',          32.00,  2),
  ('OR-152-EPDM',    'Joint torique de capot EPDM 152 mm',        5, 5, 'Réserve B2-01', 'EuroSeals',            8.75,  1),
  ('IMP-152-CI',     'Impulseur fonte 152 mm',                    1, 1, 'Réserve B2-03', 'ITT Goulds',         580.00, 14);
```

Vider la table `supplier_orders` et réinitialiser la séquence avant chaque démo :

```sql
TRUNCATE supplier_orders;
ALTER SEQUENCE supplier_orders_id_seq RESTART WITH 1;
```

### Maximo — Asset 11430 et guide PDF

L'asset `11430` (pompe de retour de condensat, site `BEDFORD`) doit exister dans Maximo. Sur l'environnement TechZone, c'est un asset standard pré-existant.

Avant de rejouer la démo, **supprimer toute work order créée par une session précédente** sur l'asset `11430` qui serait en état `WAPPR`. Identifier le `rest_id` de la WO à supprimer :

```bash
curl -k "$MAXIMO_URL/api/os/mxapiwodetail?oslc.where=assetnum%3D%2211430%22+and+status%3D%22WAPPR%22&oslc.select=wonum,href&lean=1" \
  -H "apikey: $MAXIMO_API_KEY" | jq '.member[]'
```

Puis supprimer :

```bash
curl -k -X DELETE "$MAXIMO_URL/api/os/mxapiwodetail/<rest_id>" \
  -H "apikey: $MAXIMO_API_KEY"
```

Vérifier que le **guide PDF** `Guide_Maintenance_11430.pdf` est attaché à l'asset 11430 dans Maximo (Doclinks). Ce PDF contient la section sur la vanne d'admission qui sera lue à la question 3.

### Slack — Canal de notification

Vérifier que le webhook Slack pointe vers le bon canal (idéalement un canal dédié `#maintenance-alerts`). Aucune préparation de données nécessaire — le message arrivera au moment de la cascade.

---

## Le scénario en 12 questions

À taper successivement dans l'interface conversationnelle de l'orchestrateur (claude.ai chat, ou l'UI WatsonX Orchestrate).

### Question 1 — Lecture du ticket

```
Je viens de recevoir le ticket INC0010003, peux-tu me dire de quoi il s'agit ?
```

**Ce qui se passe** :
- Routage → `servicenow_ITSM_agent`
- Tool : `get_incident(number="INC0010003")`
- Réponse : résumé de l'incident — bruit anormal sur la pompe de retour de condensat, asset 11430, site BEDFORD, suspicion de blocage de vanne d'admission

### Question 2 — Historique de l'asset

```
Quelles sont les dernières interventions sur l'asset 11430 ?
```

**Ce qui se passe** :
- Routage → `maximo_diagnostic_agent`
- Tool : `get_work_orders_for_asset(assetnum="11430", limit=10)`
- Réponse : liste des WO historiques (maintenance annuelle, contrôles flotteur, contacteur, impulseur, etc.) avec dates et statuts

### Question 3 — Lecture du guide PDF

```
Le worklog mentionne un problème de vanne d'admission. Que dit le guide de maintenance de l'asset 11430 à ce sujet ?
```

⚠️ Mentionner explicitement "asset 11430" dans la question : ça évite à l'orchestrateur de halluciner un autre numéro.

**Ce qui se passe** :
- Routage → `maximo_diagnostic_agent`
- Tools enchaînés :
  - `list_asset_attachments(assetnum="11430")` → identifier le guide
  - `get_attachment_text(assetnum="11430", attachment_id=...)` → extraire le contenu
- Réponse : citation de la section pertinente du PDF — "la vanne d'admission présente des épisodes d'adhérence récurrents", référence pièce `DRV-100-AS`

C'est le **premier wow-moment** : l'agent a croisé le worklog 2011 avec le PDF 2023 pour identifier la pièce à remplacer.

### Question 4 — Vérification du stock

```
Quelle est la disponibilité de la pièce DRV-100-AS en stock ?
```

**Ce qui se passe** :
- Routage → `maximo_stock_agent`
- Tool : `get_spare_part(reference="DRV-100-AS")`
- Réponse : "stock_qty=0, en rupture (sous le seuil de 1). Fournisseur Crane Industries, prix 245 €, délai 5 jours"

C'est le **deuxième wow-moment** : la rupture déclenche naturellement la suite.

### Question 5 — Proposition de commande

```
Passe la commande fournisseur pour 1 unité de DRV-100-AS
```

**Ce qui se passe** :
- Routage → `maximo_stock_agent`
- Tool : `propose_supplier_order(reference="DRV-100-AS", quantity=1)`
- Réponse : résumé complet avec prix unitaire (245 €), montant total (245 €), délai (5 jours), date de livraison estimée, demande de confirmation

⚠️ **Pas de création réelle à ce stade.** C'est le pattern propose / confirm.

### Question 6 — Confirmation de la commande

```
Oui, confirme
```

**Ce qui se passe** :
- Le `maximo_stock_agent` reconnaît la confirmation et appelle `create_supplier_order(reference="DRV-100-AS", quantity=1)`
- Réponse : "Commande #1 créée. Statut PENDING. Livraison prévue le ..."

### Question 7 — Proposition de work order

```
Crée la work order corrective sur l'asset 11430 pour remplacer la vanne d'admission, priorité haute, date cible dans 7 jours à 8h
```

⚠️ Préciser **"à 8h"** : sans cela, le format de date par défaut (T00:00:00) peut être rejeté par Maximo. T08:00:00 fonctionne.

**Ce qui se passe** :
- Routage → `maximo_planning_agent`
- Tool : `propose_work_order(assetnum="11430", description="...", priority=2, target_date="...")`
- Réponse : résumé de la WO à créer avec demande de confirmation

### Question 8 — Confirmation de la WO

```
Oui, confirme la création
```

**Ce qui se passe** :
- Tool : `create_work_order(...)`
- Réponse : "Work order 1208 créée dans Maximo, statut WAPPR"

⚠️ Le numéro de WO (1208) peut varier selon l'historique. C'est normal.

### Question 9 — Note de progression dans ServiceNow

```
Ajoute une note de progression au ticket INC0010003 indiquant que la WO Maximo et la commande de pièce sont créées
```

**Ce qui se passe** :
- Routage → `servicenow_ITSM_agent`
- Tool : `propose_incident_update(number="INC0010003", work_notes="WO Maximo 1208 créée. Commande pièce DRV-100-AS en cours...")`
- Réponse : résumé de la modification proposée, demande de confirmation

### Question 10 — Confirmation de la note

```
Oui, confirme
```

**Ce qui se passe** :
- Tool : `update_incident(number="INC0010003", work_notes="...")`
- Réponse : "Note ajoutée au ticket INC0010003"

### Question 11 — Proposition de clôture

```
Clôt le ticket INC0010003 en état Résolu avec le close_code "Solution provided" et un résumé des actions
```

**Ce qui se passe** :
- Routage → `servicenow_ITSM_agent`
- Tool : `propose_incident_update(number="INC0010003", new_state="6", close_code="Solution provided", close_notes="Diagnostic terminé...")`
- Réponse : résumé de la clôture proposée, demande de confirmation

### Question 12 — Confirmation de la clôture + cascade Slack automatique

```
Oui, confirme
```

**Ce qui se passe** (le **moment magique** de la démo) :

1. **Step 1** : `servicenow_ITSM_agent` appelle `update_incident(number="INC0010003", target_state="6", close_code="Solution provided", close_notes="...")`
2. **Step 2** : le tool `update_incident` retourne sa réponse, contenant le bloc :
   ```
   ✅ Incident INC0010003 clôturé avec succès.

   ⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE

   Tu DOIS maintenant déléguer à slack_notifier_agent pour notifier l'équipe
   d'astreinte. Paramètres : ...
   ```
3. **Step 3** : `servicenow_ITSM_agent` recopie intégralement le bloc dans sa réponse à l'orchestrateur (cf. `patterns.md`)
4. **Step 4** : l'orchestrateur **lit la directive** et délègue à `slack_notifier_agent`
5. **Step 5** : `slack_notifier_agent` appelle `send_incident_summary(...)` qui envoie un message Block Kit structuré sur le canal Slack maintenance
6. **Step 6** : message dans le canal Slack — récap structuré : incident, asset, work order, pièce commandée, fournisseur, date de livraison

Tout cela **sans que l'utilisateur ait demandé** d'envoyer la notification Slack. C'est l'orchestrateur qui a exécuté la directive de cascade automatiquement.

---

## Vérifications post-démo

Une fois le parcours terminé, valider que les écritures sont bien réelles dans les 4 systèmes :

```bash
# 1. ServiceNow — l'incident est résolu
curl "$SN_INSTANCE_URL/api/now/table/incident?sysparm_query=number=INC0010003&sysparm_fields=number,state,close_code" \
  -H "Authorization: Bearer $SN_TOKEN" | jq '.result[0]'
# Attendu : state=6 (Résolu), close_code="Solution provided"

# 2. Maximo — la WO existe
curl -k "$MAXIMO_URL/api/os/mxapiwodetail?oslc.where=wonum%3D%221208%22&oslc.select=wonum,status,assetnum&lean=1" \
  -H "apikey: $MAXIMO_API_KEY" | jq
# Attendu : wonum=1208, status=WAPPR, assetnum=11430

# 3. Supabase — la commande existe
curl "$SUPABASE_URL/rest/v1/supplier_orders?select=*&id=eq.1" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" | jq
# Attendu : id=1, reference="DRV-100-AS", status="PENDING"

# 4. Slack — le message est dans le canal (vérification visuelle)
```

---

## Reset complet entre deux démos

Pour rejouer la démo, lancer :

```bash
./scripts/reset_demo.sh
```

Ce script effectue :
1. Recréation de l'incident `INC0010003` dans ServiceNow (si nécessaire — sinon l'incident reste à l'état Résolu)
2. Suppression de la WO `1208` dans Maximo
3. Vidage de la table `supplier_orders` dans Supabase + reset de la séquence

Le scénario peut alors être rejoué dans les mêmes conditions.

---

## Conseils pour la démo en direct

### Avant la démo
- Tester le parcours complet en privé une fois pour valider que tout est OK
- Vérifier que les tokens ServiceNow sont valides (durée 30 min)
- Préparer une fenêtre avec ServiceNow ouvert, une avec Maximo, et le canal Slack visible — pour montrer en parallèle que les écritures sont bien réelles

### Pendant la démo
- Mentionner explicitement l'asset (11430) et le ticket (INC0010003) dans les questions où ils sont concernés — évite les hallucinations de chiffres
- Préciser "à 8h" sur la question 7 (formatage de date Maximo)
- Insister sur le pattern propose / confirm aux questions 5-6 et 7-8 (argument fort de gouvernance)
- **Garder le silence** au moment du tour 12 quand la cascade Slack se déclenche — laisser l'audience découvrir le message qui arrive dans le canal sans rien dire

### Après la démo
- Ouvrir Show Reasoning sur le tour 12 pour montrer la chaîne complète : ServiceNow → directive → orchestrateur → Slack
- Lancer les 4 cURL de vérification ci-dessus pour prouver que les écritures sont bien réelles (pas une simulation)

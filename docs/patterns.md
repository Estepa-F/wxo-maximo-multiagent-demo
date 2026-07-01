# Patterns architecturaux

Deux patterns clés sous-tendent toute l'architecture du projet. Ce document explique pourquoi ils existent, comment ils sont implémentés, et quelles erreurs ils évitent.

## 1. Propose / Confirm — la gouvernance des écritures

### Le principe

Aucune écriture dans aucun système (Maximo, ServiceNow, ERP de stock) ne se déclenche sans **validation explicite** de l'utilisateur. Chaque action d'écriture se décompose en deux tools distincts :

- Un tool `propose_*` qui ne fait **aucune écriture**. Il prépare un résumé textuel des paramètres de l'opération (référence, quantité, prix, date, etc.) et le retourne à l'utilisateur.
- Un tool `*_create` (ou équivalent : `update_*`, `create_supplier_order`, etc.) qui fait l'écriture réelle. Il n'est appelé **qu'après** une confirmation explicite de l'utilisateur ("oui", "confirme", "valide").

### L'illustration

```
Utilisateur : "Passe la commande fournisseur pour 1 unité de DRV-100-AS"
       ↓
Agent : appelle propose_supplier_order(reference="DRV-100-AS", quantity=1)
       ↓
Agent : affiche le résumé
       "Proposition de commande fournisseur — à confirmer :
          • Référence       : DRV-100-AS (Vanne d'admission Crane)
          • Quantité        : 1
          • Fournisseur     : Crane Industries
          • Prix unitaire   : 245.00 €
          • Montant total   : 245.00 €
          • Délai           : 5 jour(s)
          • Livraison prévue: 2026-06-07
        Confirmez-vous la commande ? (oui / non)"
       ↓
Utilisateur : "oui, confirme"
       ↓
Agent : appelle create_supplier_order(reference="DRV-100-AS", quantity=1)
       ↓
Système : commande créée avec id=1, status="PENDING"
       ↓
Agent : "Commande #1 créée. Livraison prévue le 7 juin 2026."
```

### Pourquoi ce pattern est non négociable en production

Sans `propose / confirm`, un LLM peut tout à fait :

- Halluciner les paramètres d'une commande
- Confondre deux commandes proches dans le contexte
- Écrire dans un système métier à partir d'une demande ambiguë
- Affirmer qu'une action a été faite alors qu'elle ne l'a pas été (le pire des cas)

Avec `propose / confirm`, chaque écriture est tracée et validée. L'utilisateur voit exactement ce qui va se passer. Si la proposition est fausse, il dit "non" et corrige. Si elle est juste, il dit "oui". Et l'écriture suit ce qu'a été affiché.

### Les opérations couvertes par le pattern

| Opération | Tool propose | Tool execute |
|-----------|--------------|--------------|
| Créer une work order Maximo | `propose_work_order` | `create_work_order` |
| Passer une commande fournisseur | `propose_supplier_order` | `create_supplier_order` |
| Mettre à jour un incident ServiceNow (note, clôture) | `propose_incident_update` | `update_incident` |

### Implémentation côté tool Python

Les deux tools partagent leurs paramètres : `propose_*` calcule un résumé sans toucher au système ; `*_execute` fait l'écriture réelle. Exemple simplifié pour la commande fournisseur :

```python
@tool
def propose_supplier_order(reference: str, quantity: int = 1,
                           related_wonum: Optional[str] = None) -> SupplierOrderProposal:
    """Construit la proposition. Ne crée RIEN."""
    part = _fetch_part(reference)
    summary = (
        f"Proposition de commande fournisseur — à confirmer :\n"
        f"  • Référence : {reference} ({part['description']})\n"
        f"  • Quantité  : {quantity}\n"
        f"  • Fournisseur : {part['supplier']}\n"
        f"  • Prix total : {part['unit_price'] * quantity:.2f} €\n"
        f"\nConfirmez-vous la commande ? (oui / non)"
    )
    return SupplierOrderProposal(summary=summary, ...)


@tool
def create_supplier_order(reference: str, quantity: int = 1,
                          related_wonum: Optional[str] = None) -> SupplierOrder:
    """Crée RÉELLEMENT la commande. À n'appeler qu'après confirmation."""
    part = _fetch_part(reference)
    row = _insert("supplier_orders", { ... })
    return SupplierOrder(**row)
```

### Implémentation côté instructions agent

Les instructions de l'agent (champ `instructions:` dans le YAML) doivent rendre la séparation propose / execute **non ambiguë**. Le LLM doit comprendre que :

1. Quand l'utilisateur demande de **commander**, on appelle `propose_supplier_order`, on affiche le résumé, on **s'arrête là**.
2. Quand l'utilisateur **confirme** ("oui", "confirme", "valide"), on appelle **directement** `create_supplier_order`. On ne ré-appelle PAS `propose_supplier_order`.
3. Une commande n'est créée que si `create_supplier_order` a renvoyé un objet avec un `id` numérique. Sinon, c'est une hallucination, et l'agent doit le signaler.

Exemple d'instructions claires dans `agents/maximo_stock_agent.yaml` :

```yaml
instructions: |
  ÉTAPE A — Demande de commande :
    1. Appelle UNIQUEMENT propose_supplier_order
    2. Affiche le résumé mot pour mot
    3. Termine par "Confirmez-vous la commande ? (oui / non)"
    4. STOP. N'appelle PAS create_supplier_order à ce stade.

  ÉTAPE B — Confirmation utilisateur :
    1. Appelle DIRECTEMENT create_supplier_order avec les MÊMES paramètres
    2. N'appelle PAS propose_supplier_order une seconde fois
    3. Annonce le résultat avec le numéro d'id réellement retourné

  RÈGLE ABSOLUE :
    Ne JAMAIS dire "commande créée" / "commande confirmée" sans avoir
    effectivement appelé create_supplier_order et obtenu un id.
```

### Le piège à éviter

Sans cette précision dans les instructions, un LLM peut tomber dans un piège classique : recevoir un "oui" et **rappeler `propose_*` au lieu de `*_create`**. L'utilisateur croit que sa commande est passée alors que rien n'a été écrit. C'est un bug subtil parce que la conversation paraît correcte.

La défense consiste à toujours **vérifier visuellement le retour du tool d'écriture** : un `id` numérique, un message de succès, et idéalement une re-lecture immédiate via un tool `list_*` ou `get_*` pour confirmation utilisateur.

---

## 2. Tools Chaining déclaratif — la cascade automatique

### Le principe

Quand un tool exécute une écriture qui doit déclencher un **effet de bord** dans un autre système (par exemple : notifier Slack après la clôture d'un incident), le tool retourne dans sa réponse une **directive structurée** que l'orchestrateur lit et exécute automatiquement.

Concrètement : au moment de clôturer un incident ServiceNow, le tool `update_incident` détecte que l'état cible est "Résolu" ou "Fermé" et retourne dans son champ `message` un bloc visuellement frappant :

```
✅ Incident INC0010003 clôturé avec succès.
Numéro    : INC0010003
État      : Résolu (6)
Close code: Solution provided

⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE

Tu DOIS maintenant déléguer à slack_notifier_agent pour notifier l'équipe
d'astreinte de la clôture de cet incident.

Paramètres à passer :
  - incident_number : INC0010003
  - asset           : 11430
  - work_order      : 1208
  - parts_ordered   : DRV-100-AS
  - supplier        : Crane Industries
  - resolution      : Solution provided
```

L'orchestrateur, dans ses propres instructions, a la règle suivante :

> **RÈGLE INVIOLABLE** : si la réponse d'un agent contient un bloc commençant par `⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE`, tu DOIS exécuter cette directive immédiatement, dans le même tour, sans demander confirmation à l'utilisateur.

### Pourquoi ce pattern fonctionne mieux qu'une règle dans le prompt

L'alternative naïve serait de mettre dans le prompt système de l'orchestrateur :

> "À chaque clôture d'incident ServiceNow, notifie Slack."

Cette règle est ignorée par le LLM dans environ 1 conversation sur 4 — parce qu'elle est abstraite, parce que d'autres règles entrent en concurrence, parce que le contexte conversationnel pollue.

La directive embarquée dans la réponse du tool, elle, **arrive au moment exact** où la décision doit être prise. Le LLM la voit dans le contenu du dernier tool call, encadrée d'un format frappant. Elle est **infiniment plus difficile à ignorer**.

### Le piège de la transmission

Pour que cela fonctionne, le bloc directive doit traverser l'agent intermédiaire **sans être réécrit**. Concrètement : quand `servicenow_ITSM_agent` reçoit la réponse du tool `update_incident`, il doit recopier **intégralement** le bloc dans sa réponse à l'orchestrateur. S'il le résume ("J'ai clôturé le ticket et il faut notifier Slack"), la directive est interceptée et perdue.

Les instructions de `servicenow_ITSM_agent` contiennent donc explicitement :

```yaml
instructions: |
  Si le champ "message" du retour d'un tool ServiceNow contient un bloc
  "⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE", tu DOIS le
  recopier INTÉGRALEMENT dans ta réponse, sans le résumer, sans le
  paraphraser. Ce bloc est destiné à l'orchestrateur, pas à toi.
```

### Implémentation côté tool Python

Dans `tools/servicenow_tools.py` :

```python
@tool
def update_incident(number: str, target_state: str, close_code: str = None,
                    close_notes: str = None, ...) -> IncidentUpdateResult:
    # ... logique de mise à jour ServiceNow ...

    base_message = f"Incident {number} mis à jour : état → {target_state}"

    # Si on clôture, on embarque la directive de cascade Slack
    if target_state in ("6", "7"):  # Résolu ou Fermé
        directive = f"""
✅ Incident {number} clôturé avec succès.

⚠️ ATTENTION ORCHESTRATEUR — ACTION RESTANTE OBLIGATOIRE

Tu DOIS maintenant déléguer à slack_notifier_agent pour notifier l'équipe
d'astreinte de la clôture de cet incident.

Paramètres à passer :
  - incident_number : {number}
  - resolution      : {close_code}
"""
        return IncidentUpdateResult(
            number=number,
            state=target_state,
            message=base_message + "\n\n" + directive,
        )

    return IncidentUpdateResult(number=number, state=target_state, message=base_message)
```

### Pourquoi ce pattern dépasse la simple notification

Une fois en place, ce pattern permet d'enchaîner **n'importe quel effet de bord** sans modifier l'orchestrateur :

- Notifier Slack à la clôture d'un incident
- Créer une entrée dans un journal d'audit à chaque écriture critique
- Envoyer un email récapitulatif au manager à la création d'une WO de priorité 1
- Déclencher un workflow externe (Zapier, n8n) après une mise à jour

Il suffit que le tool concerné connaisse la règle métier et embarque la directive correspondante. L'orchestrateur reste générique. C'est ce qui rend l'architecture **scalable** et **maintenable** dans la durée.

---

## En résumé

| Pattern | Quand l'utiliser | Bénéfice principal |
|---------|------------------|---------------------|
| Propose / Confirm | Sur toute écriture dans un système métier | Gouvernance + zéro écriture non validée |
| Tools chaining déclaratif | Pour automatiser un effet de bord après une action | Cascade fiable + orchestrateur générique |

Ensemble, ces deux patterns transforment une démo "qui marche en local" en architecture **déployable en production**.

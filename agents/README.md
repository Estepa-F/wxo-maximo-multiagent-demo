# Agents

This folder contains the YAML definitions of the agents used in the watsonx Orchestrate demo.

## Purpose of the agents

Agents split the user journey into specialized roles, each responsible for a specific business domain. This separation brings several benefits:

- clearer responsibilities
- simpler routing of user requests
- stricter control over read and write actions
- shorter, more specialized prompts
- multi-step workflows that are easier to orchestrate

In this project, an orchestrator agent receives the user request and then delegates to the specialized agents according to the detected intent.

## Agents in this folder

### [`maximo_orchestrator.yaml`](maximo_orchestrator.yaml)
Main agent exposed to the user.

It is used to:
- analyze the request
- choose the right collaborator agent
- keep the overall workflow logic
- chain actions across several systems when necessary

### [`maximo_diagnostic_agent.yaml`](maximo_diagnostic_agent.yaml)
Read-only Maximo consultation agent.

It is used to:
- search assets
- look up work orders
- read worklogs
- list and read attached documents
- help with diagnosis before an action

### [`maximo_planning_agent.yaml`](maximo_planning_agent.yaml)
Work order creation agent in Maximo.

It is used to:
- prepare a work order
- present a summary before validation
- create the work order after explicit confirmation

### [`maximo_stock_agent.yaml`](maximo_stock_agent.yaml)
Agent dedicated to spare parts stock.

It is used to:
- check the availability of a part
- identify stock-outs
- propose a supplier order
- create the order after confirmation

### [`servicenow_ITSM_agent.yaml`](servicenow_ITSM_agent.yaml)
Agent dedicated to ServiceNow tickets.

It is used to:
- read an incident
- prepare an update
- add work notes
- resolve an incident with a closure summary

### [`slack_notifier_agent.yaml`](slack_notifier_agent.yaml)
Slack notification agent.

It is used to:
- send a simple message to the team
- publish an incident handling recap

## In practice

This folder therefore gathers the project's AI behaviors. Each YAML file defines:
- the agent's name
- its description
- its instructions
- its allowed tools
- its configuration

This organization makes the agents more reliable, easier to maintain and simpler to evolve.

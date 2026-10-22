# Tools

This folder contains the Python implementations of the tools used by the agents in watsonx Orchestrate.

## Purpose of the tools

Tools are the project's building blocks for actions and data access. Where an agent carries the conversational logic and decision-making, a tool performs a concrete operation on an external system.

Tools are used in particular to:
- query business systems
- read or write data through APIs
- encapsulate the technical integration logic
- secure write actions with confirmation flows
- expose reusable capabilities to several agents

In practice, agents do not talk directly to the APIs: they call the tools defined in this folder.

## Files in this folder

### [`maximo_tools.py`](maximo_tools.py)
Implements the tools for IBM Maximo.

It is used to:
- search for assets
- read the work orders of a piece of equipment
- read worklogs
- list attached documents
- extract the text of an attachment
- propose and then create a work order

### [`servicenow_tools.py`](servicenow_tools.py)
Implements the tools for ServiceNow.

It is used to:
- read an incident
- list open incidents
- prepare an incident update
- apply an update after confirmation

### [`supabase_tools.py`](supabase_tools.py)
Implements the tools for inventory and supplier orders via Supabase.

It is used to:
- look up a spare part
- list parts below the stock threshold
- look up the order history
- propose and then create a supplier order

### [`slack_tools.py`](slack_tools.py)
Implements the Slack notification tools.

It is used to:
- send a simple message
- send a formatted end-of-processing recap

### [`requirements.txt`](requirements.txt)
Lists the Python dependencies required to run these integrations.

## In practice

This folder therefore groups the project's technical integration layer. Each file defines functions exposed as Orchestrate tools, with their input and output schemas, their API calls and their usage rules.

This organization makes it possible to clearly separate:
- the conversational logic in the agents
- the technical logic in the tools
- access to external systems in dedicated modules

The result is more readable, more maintainable and easier to evolve.

# Connections

This folder contains the definitions of the connections used by the tools and agents in watsonx Orchestrate.

## Purpose of the connections

Connections declare how the project accesses external systems. They centralize the connection information the tools need without hard-coding it in the Python files.

The connections are used to:
- configure access to external systems
- separate configuration from application logic
- store technical parameters per environment
- let the tools use the right credentials and URLs
- make deploying and maintaining the integrations easier

In practice, the tools read these connections through watsonx Orchestrate to call Maximo, ServiceNow, Slack or Supabase.

## Files in this folder

### [`maximo_conn.yaml`](maximo_conn.yaml)
Defines the connection to IBM Maximo.

It is used to:
- declare the Maximo server URL
- configure API key authentication
- provide the connection base used by [`maximo_tools.py`](../tools/maximo_tools.py)

### [`servicenow_conn.yaml`](servicenow_conn.yaml)
Defines the connection to ServiceNow.

It is used to:
- declare the ServiceNow instance URL
- configure OAuth password flow authentication
- provide the connection used by [`servicenow_tools.py`](../tools/servicenow_tools.py)

### [`slack_conn.yaml`](slack_conn.yaml)
Defines the connection to Slack.

It is used to:
- store the variables needed to send notifications
- configure a key/value connection
- provide the configuration used by [`slack_tools.py`](../tools/slack_tools.py)

### [`supabase_conn.yaml`](supabase_conn.yaml)
Defines the connection to Supabase.

It is used to:
- store the Supabase URL and access key
- configure a key/value connection
- provide the configuration used by [`supabase_tools.py`](../tools/supabase_tools.py)

## In practice

This folder therefore holds the access configuration for the project's external services. Each YAML file defines an `app_id`, a connection type and the available environments, usually `draft` and `live`.

This organization makes it possible to clearly separate:
- secrets and access parameters in the connections
- the technical logic in the tools
- the conversational logic in the agents

The result is cleaner, more secure and simpler to administer.
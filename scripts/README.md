# Scripts

This folder contains the shell scripts used to configure the connections, import the components and deploy the project to watsonx Orchestrate.

## Purpose of the scripts

The scripts automate the project's repetitive operations. They avoid manually replaying long sequences of CLI commands to configure the connections, import the tools and publish the agents.

In particular, the scripts make it possible to:
- configure the connections to external systems
- import or re-import the Python tools
- import the agents in the right order
- deploy the whole project faster
- reduce manual errors during setup

## Files in this folder

### [`configure_maximo_connection.sh`](configure_maximo_connection.sh)
Configures the Maximo connection in watsonx Orchestrate.

### [`configure_servicenow_connection.sh`](configure_servicenow_connection.sh)
Configures the ServiceNow connection in watsonx Orchestrate.

### [`configure_supabase_connection.sh`](configure_supabase_connection.sh)
Configures the Supabase connection in watsonx Orchestrate.

### [`create_connections.sh`](create_connections.sh)
Imports and then configures all of the project's connections.

### [`reimport_maximo_tools.sh`](reimport_maximo_tools.sh)
Re-imports the Maximo tools with the right connection.

### [`import_supabase_tools.sh`](import_supabase_tools.sh)
Imports the Supabase tools.

### [`import_all_agents.sh`](import_all_agents.sh)
Imports the project's main agents in the right order.

### [`deploy_complete.sh`](deploy_complete.sh)
Runs the full deployment of the project: connections, tools and agents.

## In practice

This folder therefore holds the project's operational automation layer. These scripts rely mainly on the `orchestrate` CLI to run the configuration and deployment tasks.

This organization makes it possible to clearly separate:
- access configuration in [`connections/`](../connections/)
- the technical integration logic in [`tools/`](../tools/)
- the conversational logic in [`agents/`](../agents/)
- operational automation in this folder

The result is a project that is simpler to install, more consistent to deploy and easier to maintain.
<h1 align="center">WatsonX Orchestrate × Maximo — Multi-Agent Demo</h1>
<p align="center">
<strong>A hands-on agentic AI demo for industrial maintenance.<br>
  One assistant. Four systems. Zero silos.</strong>
</p>
<!-- BADGES -->
<p align="center">
<img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="Version">
<img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
<img src="https://img.shields.io/badge/python-3.12+-blue.svg" alt="Python">
<img src="https://img.shields.io/badge/IBM-WatsonX_Orchestrate-052FAD.svg?logo=ibm&logoColor=white" alt="IBM WatsonX Orchestrate">
<img src="https://img.shields.io/badge/IBM-Maximo-052FAD.svg?logo=ibm&logoColor=white" alt="IBM Maximo">
<img src="https://img.shields.io/badge/ServiceNow-grey?logo=servicenow&logoColor=white" alt="ServiceNow">
<img src="https://img.shields.io/badge/Slack-4A154B?logo=slack&logoColor=white" alt="Slack">
</p>
<!-- VIDEO CTA -->
<p align="center">
<a href="https://youtu.be/5qgKqxjqO4A">
<img src="https://img.shields.io/badge/▶️_Watch_Demo_on_YouTube-red?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch demo on YouTube" height="50">
</a>
  &nbsp;&nbsp;
  <a href="https://www.linkedin.com/in/estepa/">
<img src="https://img.shields.io/badge/💬_Discuss_on_LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="Discuss on LinkedIn" height="50">
</a>
</p>
<!-- DEMO GIF -->
<p align="center">
<em>The automatic cascade: when the ServiceNow ticket is closed, the orchestrator triggers the Slack notification — with no human intervention.</em>
</p>

A watsonx Orchestrate demo project built around a multi-agent industrial maintenance journey.

The project brings together several systems:
- IBM Maximo for maintenance
- ServiceNow for ITSM incidents
- Supabase for the parts inventory
- Slack for team notifications

## 🎯 The problem

On an industrial site, handling a maintenance incident forces the manager to juggle **at least 4 systems**:

- 🎫 **ServiceNow** for the incident ticket
- 🔧 **IBM Maximo** for asset management and work orders
- 📦 **ERP** to check stock and place orders
- 💬 **Slack** to notify the on-call team

The result: **at least 20 minutes per incident**, data-entry errors, missed notifications, and zero unified traceability.

## 💡 The solution

A **multi-agent architecture** where:

- **The user talks to a single orchestrator** in a natural conversation
- The **orchestrator delegates** each task to an agent specialized in one system
- Every **write goes through a propose / confirm protocol** — the human stays in the loop
- **Side effects** (notifications) are triggered **automatically** by the tools themselves through a declarative tool chaining pattern

## 🏗️ Architecture

```
                  ┌─────────────────────────┐
                  │   maximo_orchestrator   │
                  │   (entry point)         │
                  └────────────┬────────────┘
                               │
        ┌──────────────┬───────┴───────┬─────────────┬─────────────┐
        ▼              ▼               ▼             ▼             ▼
  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ServiceNow│  │  Maximo     │  │  Maximo  │  │  Stock   │  │  Slack   │
  │   ITSM   │  │ Diagnostic  │  │ Planning │  │ (Supabase│  │ Notifier │
  │  Agent   │  │   Agent     │  │  Agent   │  │  Agent)  │  │  Agent   │
  └────┬─────┘  └──────┬──────┘  └─────┬────┘  └────┬─────┘  └─────┬────┘
       │               │               │            │              │
       ▼               ▼               ▼            ▼              ▼
  ┌──────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │ServiceNow│  │   Maximo    │  │  Maximo  │  │ Supabase │  │  Slack   │
  │   REST   │  │   OSLC      │  │   OSLC   │  │   REST   │  │ Webhook  │
  │  OAuth2  │  │  API Key    │  │ API Key  │  │ API Key  │  │   URL    │
  └──────────┘  └─────────────┘  └──────────┘  └──────────┘  └──────────┘
```

## Project structure

- [`agents/`](agents/): Orchestrate agent definitions
- [`tools/`](tools/): Python tools called by the agents
- [`connections/`](connections/): connection definitions for the external systems
- [`scripts/`](scripts/): setup, import and deployment scripts

## Quick start

### 1. Prepare the environment

- create a local `.env.sdk` file from [`.env.sdk.exemple`](.env.sdk.exemple)
- configure the required credentials for Maximo, ServiceNow, Supabase and Slack
- activate your watsonx Orchestrate environment

### Variables to edit in [`.env.sdk.exemple`](.env.sdk.exemple)

Before running the scripts, whoever installs the project must create their own local `.env.sdk` file from [`.env.sdk.exemple`](.env.sdk.exemple) and replace the example values with their own information.

#### watsonx Orchestrate
- `WO_INSTANCE_ALIAS`: local alias of the watsonx Orchestrate environment
- `WO_INSTANCE`: watsonx Orchestrate instance URL
- `WO_API_KEY`: watsonx Orchestrate API key

#### Maximo
- `MAXIMO_URL`: Maximo instance URL
- `MAXIMO_API_KEY`: Maximo API key

The scripts read `MAXIMO_URL` from the local `.env.sdk` file. The value in [`connections/maximo_conn.yaml`](connections/maximo_conn.yaml) remains a public placeholder used for the initial import.

#### ServiceNow
- `SN_INSTANCE_URL`: ServiceNow instance URL
- `SN_USERNAME`: service account username
- `SN_PASSWORD`: service account password
- `SN_CLIENT_ID`: OAuth client ID
- `SN_CLIENT_SECRET`: OAuth secret

The scripts read `SN_INSTANCE_URL` from the local `.env.sdk` file. The value in [`connections/servicenow_conn.yaml`](connections/servicenow_conn.yaml) remains a public placeholder used for the initial import.

#### Supabase
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_KEY`: Supabase API key used by the setup scripts

#### Slack
- `SLACK_WEBHOOK_URL`: Slack webhook URL used for notifications

### 2. Deploy the project

```bash
./scripts/deploy_complete.sh
```

### 3. Deploy step by step

```bash
./scripts/create_connections.sh
./scripts/reimport_maximo_tools.sh
./scripts/import_supabase_tools.sh
./scripts/import_all_agents.sh
```

## Documentation

### Per-folder documentation

- [`agents/README.md`](agents/README.md)
- [`tools/README.md`](tools/README.md)
- [`connections/README.md`](connections/README.md)
- [`scripts/README.md`](scripts/README.md)

### Detailed guides in [`docs/`](docs/)

- [`docs/installation.md`](docs/installation.md) — installation and deployment guide
- [`docs/architecture.md`](docs/architecture.md) — multi-agent architecture and systems overview
- [`docs/connections.md`](docs/connections.md) — configuring the Maximo, ServiceNow, Supabase and Slack connections
- [`docs/patterns.md`](docs/patterns.md) — architectural patterns used in the project
- [`docs/scenario-demo.md`](docs/scenario-demo.md) — full demo scenario
- [`docs/maximo_wxo_deck.pptx`](docs/maximo_wxo_deck.pptx) — presentation deck

## 🎥 External resources

- 🎬 [Full demo video on YouTube](https://youtu.be/5qgKqxjqO4A)
- 💼 [LinkedIn profile](https://www.linkedin.com/in/estepa/)

## ⚖️ License

This project is distributed under the MIT license. See [LICENSE](LICENSE) for details.

```
MIT License
Copyright (c) 2026 François Estepa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction [...]
```

## 🙏 Credits

Built with:
- [IBM WatsonX Orchestrate](https://www.ibm.com/products/watsonx-orchestrate) and its [ADK](https://developer.watson-orchestrate.ibm.com/)
- [IBM Maximo Application Suite](https://www.ibm.com/products/maximo)
- [ServiceNow Developer PDI](https://developer.servicenow.com/)
- [Supabase](https://supabase.com/) for the demo ERP layer
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)

---

<p align="center">
  ⭐ If this project inspired you, give the repo a star. It helps other architects find it.<br>
  💬 Questions? Open an issue or reach out on <a href="https://www.linkedin.com/in/estepa/">LinkedIn</a>.
</p>

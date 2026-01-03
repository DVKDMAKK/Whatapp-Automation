# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an n8n workflow automation project that runs a Field Force AI Agent via WhatsApp. The system enables Medical Representatives (MRs) and Head Office (HO) staff to interact with an AI assistant through WhatsApp for task management and team coordination.

## Development Commands

### Start n8n
```bash
docker-compose up -d
```

### Stop n8n
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f n8n
```

### Access n8n UI
Navigate to `http://localhost:5678` after starting the container.

## Architecture

### Infrastructure
- **n8n**: Runs in Docker container using `n8nio/n8n:latest`
- **Data persistence**: SQLite database stored in `./n8n_data/`
- **Webhooks**: Exposed via ngrok for WhatsApp integration

### External Services
- **WhatsApp Business API**: Trigger and messaging
- **Supabase**: Database for user authentication and work tracking (`staff` table)
- **Google Gemini**: AI model (gemini-2.5-pro) for agent intelligence

### Workflow Structure
- `Field Force AI Agent (Main).json` / `workflows/`: Main workflow definitions
- `Field Force Tools.json`: Sub-workflows called as tools by the AI agent

### AI Agent Tools
The agent has role-based access to these tools:
- `get_pending_works`: Retrieves current user's pending tasks
- `update_work_status`: Updates task completion status (requires id and notes)
- `check_team_status`: HO-only - checks team member work status
- `remind_team`: HO-only - sends reminders to team members
- `hcp_wish`: MR-only - generates greeting messages with images

### Role-Based Access
- **MR (Medical Representative)**: Can manage own tasks and request greeting messages
- **HO (Head Office)**: Can additionally view team status and send reminders

## Key Configuration

### docker-compose.yml
- Port: 5678
- Webhook URL must be updated when ngrok URL changes
- n8n data persisted to `./n8n_data` volume

### Custom Nodes
The project uses `n8n-nodes-convert-image` package for image processing.

##SQL Queries
Use .md file to provide the sql queries to the user

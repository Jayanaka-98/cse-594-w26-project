# cse-594-w26-project

A small Jac-based frontend project for a Kanban-style task manager. This repository contains the UI components and entry points for a student project built with Jac files and a simple component structure.

## Features
- Component-driven UI (Kanban board, task cards, modals, profile panel)
- Simple styling in `styles.css`
- Entry point: `main.jac`

## Quickstart
Prerequisites: Install the Jac runtime/tooling used by this project.

To run locally (if you have Jac installed):

```
jac run main.jac
```

If your workflow differs, open `jac.toml` to inspect project config.

## Project structure
- `main.jac` — application entry point
- `jac.toml` — project configuration
- `styles.css` — global styles
- `components/` — UI components
  - `KanbanBoard.cl.jac`
  - `TaskCard.cl.jac`
  - `TaskDetailPanel.cl.jac`
  - `TaskModal.cl.jac`
  - `Sidebar.cl.jac`
  - `ProfilePanel.cl.jac`
  - `AuthForm.cl.jac`
  - `AnalyticsView.cl.jac`

## Development
- Edit components in the `components/` directory.
- Update styles in `styles.css`.
- Keep `main.jac` as the application entry point.

## Contributing
Open an issue or submit a pull request. Keep changes focused and include a short description of what you changed.

## License
See the repository `LICENSE` for license details.

----
If you'd like, I can add a simple run script or a short CONTRIBUTING.md next.

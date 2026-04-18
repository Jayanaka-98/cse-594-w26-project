# FlowBoard Activity Tracker — macOS Widget

A lightweight macOS menu bar app that monitors what you're working on, automatically tracks time against your scheduled tasks, and reports out-of-scope activity back to FlowBoard.

## How it works

Every `--interval` seconds (default: 120) the widget takes a screenshot, sends it to the FlowBoard server for vision analysis, and decides which scheduled task (if any) you're currently working on. It then starts or pauses timers accordingly.

---

## Quick start (run from source)

### 1. Prerequisites

- macOS 12+
- Python 3.10+
- A running FlowBoard server

### 2. Install dependencies

```bash
cd widget
pip install rumps requests
```

### 3. Run

```bash
python widget.py --server http://<your-server>:8000
```

Additional options:

| Flag | Default | Description |
|------|---------|-------------|
| `--server` | `http://localhost:8000` | FlowBoard server URL |
| `--interval` | `120` | Screenshot poll interval in seconds |

You can also set these via environment variables instead:

```bash
export FLOWBOARD_URL=http://<------->:8000
export POLL_INTERVAL=60
python widget.py
```

### 4. First run — sign in

Click the `⚡` icon in the menu bar and choose **Sign In**. Enter your FlowBoard username and password. The token is saved to `~/.studysync_token` so you only need to do this once.

---

## Package as a macOS .app

This bundles the widget into a standalone `.app` that can be distributed and launched without Python installed.

### 1. Install py2app

```bash
pip install py2app
```

### 2. Build the app

```bash
cd widget
python setup.py py2app
```

Output is at `dist/FlowBoard Activity Tracker.app`.

> **Note:** The build must be run on a Mac. The resulting `.app` only runs on macOS.

### 3. Test the built app

```bash
open "dist/FlowBoard Activity Tracker.app"
```

To pass the `--server` flag to the packaged app, right-click → Show Package Contents → edit `Contents/MacOS/FlowBoard Activity Tracker` or set `FLOWBOARD_URL` in your environment before opening.

### 4. Wrap in a .dmg for distribution

```bash
brew install create-dmg

create-dmg \
  --volname "FlowBoard Activity Tracker" \
  --window-size 600 400 \
  --icon-size 128 \
  --app-drop-link 450 185 \
  "FlowBoard Activity Tracker.dmg" \
  "dist/"
```

This produces a drag-to-install `.dmg` you can share with others.

---

## macOS permissions

On first launch macOS will prompt for:

- **Screen Recording** — required for screenshot-based task matching
- **Notifications** — used to alert when you go out-of-scope or finish a task

Grant both in **System Settings → Privacy & Security**.

---

## Uninstall

```bash
rm ~/.studysync_token
```

Then delete the `.app` from your Applications folder (or wherever you placed it).

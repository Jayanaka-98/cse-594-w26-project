"""FlowBoard Activity Tracker — macOS menu bar widget.

Runs in the background, polls FlowBoard every POLL_INTERVAL seconds,
takes a screenshot when a task is active, and asks the server to analyse
whether you're on-task.  Alerts appear as macOS notifications and in the
FlowBoard chat panel.

Requirements: pip install rumps requests
Run:          python widget.py
Package:      python setup.py py2app
"""

import base64
import json
import os
import subprocess
import tempfile
import threading
from datetime import datetime

import requests
import rumps

# ---------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------
FLOWBOARD_URL = os.environ.get("FLOWBOARD_URL", "http://localhost:8000").rstrip("/")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "120"))
TOKEN_FILE = os.path.expanduser("~/.flowboard_token")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _save_token(token: str) -> None:
    with open(TOKEN_FILE, "w") as f:
        f.write(token)
    os.chmod(TOKEN_FILE, 0o600)


def _load_token() -> str | None:
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            t = f.read().strip()
        return t if t else None
    return None


def _delete_token() -> None:
    if os.path.exists(TOKEN_FILE):
        os.remove(TOKEN_FILE)


def _notify(title: str, subtitle: str, message: str) -> None:
    """Show a macOS system notification via osascript."""
    script = (
        f'display notification "{message}" '
        f'with title "{title}" subtitle "{subtitle}"'
    )
    try:
        subprocess.run(["osascript", "-e", script], timeout=5, check=False)
    except Exception:
        pass


def _elapsed_minutes(timer_start: str, timer_accumulated: int) -> int:
    """Compute total elapsed minutes from Jaseci timer fields."""
    elapsed = timer_accumulated
    if timer_start:
        try:
            started = datetime.fromisoformat(timer_start)
            delta = (datetime.now() - started).total_seconds()
            elapsed += int(delta / 60)
        except Exception:
            pass
    return elapsed


# ---------------------------------------------------------------------------
# Login window
# ---------------------------------------------------------------------------

def _osascript_input(prompt: str, title: str, hidden: bool = False) -> str | None:
    """Show a native macOS dialog with a text input field via osascript.
    Returns the entered text, or None if cancelled.
    Hidden=True masks the input (for passwords).
    """
    hidden_clause = " with hidden answer" if hidden else ""
    script = (
        f'display dialog "{prompt}" '
        f'with title "{title}" '
        f'default answer ""{hidden_clause}'
    )
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return None  # user cancelled
    for part in result.stdout.strip().split(","):
        if "text returned:" in part:
            return part.split("text returned:", 1)[1].strip()
    return None


def _login_dialog(app: "FlowBoardWidget", _timer=None) -> None:
    """Prompt for credentials using native osascript dialogs (focus-safe)."""
    if _timer is not None:
        _timer.stop()  # one-shot

    username = _osascript_input(
        "Enter your FlowBoard username:",
        "FlowBoard — Sign In",
    )
    if not username:
        return

    password = _osascript_input(
        "Enter your password:",
        "FlowBoard — Sign In",
        hidden=True,
    )
    if not password:
        return

    threading.Thread(
        target=_do_login, args=(app, username, password), daemon=True
    ).start()


def _do_login(app: "FlowBoardWidget", username: str, password: str) -> None:
    # Runs on a background thread — use _notify instead of rumps.alert
    try:
        resp = requests.post(
            f"{FLOWBOARD_URL}/user/login",
            json={"username": username, "password": password},
            timeout=10,
        )
        data = resp.json()
        if not data.get("ok"):
            msg = data.get("error", {}).get("message", "Unknown error")
            _notify("FlowBoard", "Sign In Failed", msg)
            return
        token = (data.get("data") or {}).get("token")
        if not token:
            _notify("FlowBoard", "Sign In", "Login failed: no token returned.")
            return
        app.token = token
        _save_token(token)
        app._set_status("Idle")
        _notify("FlowBoard", "Sign In", f"Signed in as {username}.")
        threading.Thread(target=app._poll, daemon=True).start()
    except Exception as exc:
        _notify("FlowBoard", "Sign In Error", str(exc))


# ---------------------------------------------------------------------------
# Main app
# ---------------------------------------------------------------------------

class FlowBoardWidget(rumps.App):
    def __init__(self):
        super().__init__(
            name="FlowBoard",
            title="FB",           # Menu bar text when no icon
            quit_button="Quit FlowBoard",
        )

        self.token: str | None = _load_token()
        self._paused = False
        self._current_task: dict | None = None

        # Build menu
        self._status_item = rumps.MenuItem("Status: Idle")
        self._status_item.set_callback(None)  # non-clickable label

        self._task_item = rumps.MenuItem("No active task")
        self._task_item.set_callback(None)

        self._pause_item = rumps.MenuItem("Pause Tracking", callback=self._toggle_pause)
        self._login_item = rumps.MenuItem("Sign In / Switch Account", callback=self._show_login)
        self._logout_item = rumps.MenuItem("Sign Out", callback=self._logout)

        self.menu = [
            self._status_item,
            self._task_item,
            None,  # separator
            self._pause_item,
            None,
            self._login_item,
            self._logout_item,
        ]

        # Start the polling timer
        self._timer = rumps.Timer(self._poll, POLL_INTERVAL)
        self._timer.start()

        if self.token:
            # Already logged in — immediate first poll on background thread
            threading.Thread(target=self._poll, daemon=True).start()
        else:
            # Show login dialog on the main thread via a one-shot timer
            t = rumps.Timer(lambda sender: _login_dialog(self, sender), 0.3)
            t.start()

    # ------------------------------------------------------------------
    # Menu callbacks
    # ------------------------------------------------------------------

    @rumps.clicked("Pause Tracking")
    def _toggle_pause(self, sender):
        self._paused = not self._paused
        sender.title = "Resume Tracking" if self._paused else "Pause Tracking"
        self._set_status("Paused" if self._paused else "Idle")

    def _show_login(self, _):
        # Menu callbacks run on the main thread — call directly
        _login_dialog(self)

    def _logout(self, _):
        self.token = None
        _delete_token()
        self._set_status("Not signed in")
        self._task_item.title = "No active task"

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _set_status(self, status: str) -> None:
        self._status_item.title = f"Status: {status}"

    def _auth_headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    # ------------------------------------------------------------------
    # Polling
    # ------------------------------------------------------------------

    def _poll(self, _timer=None) -> None:
        """Called by the timer (and manually on startup/login)."""
        if not self.token or self._paused:
            return
        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/GetActiveTask",
                headers=self._auth_headers(),
                json={},
                timeout=10,
            )
        except Exception as exc:
            print(f"[FlowBoard] Poll request failed: {exc}")
            return

        if resp.status_code == 401:
            # Token expired or invalid
            self.token = None
            _delete_token()
            self._set_status("Session expired — please sign in")
            return

        try:
            data = resp.json()
        except Exception:
            return

        # Response shape: {"ok": true, "data": {"reports": [...]}}
        reports = (data.get("data") or {}).get("reports", [])
        result = reports[0] if reports else {}

        if not result.get("active"):
            self._current_task = None
            self._set_status("Idle")
            self._task_item.title = "No active task"
            return

        task = result["task"]
        self._current_task = task
        elapsed = _elapsed_minutes(
            result.get("timer_start", ""),
            result.get("timer_accumulated", 0),
        )

        self._set_status(f"Tracking ({elapsed} min elapsed)")
        title_display = task["title"][:40] + "…" if len(task["title"]) > 40 else task["title"]
        self._task_item.title = f"Task: {title_display}"

        # Run screenshot + analysis on a background thread
        threading.Thread(
            target=self._analyze, args=(task, elapsed), daemon=True
        ).start()

    # ------------------------------------------------------------------
    # Screenshot + analysis
    # ------------------------------------------------------------------

    def _analyze(self, task: dict, elapsed_minutes: int) -> None:
        """Take a screenshot and send it to AnalyzeScreenshot walker."""
        tmp_path = None
        try:
            # Capture screen silently (no shutter sound, no UI)
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tf:
                tmp_path = tf.name

            subprocess.run(
                ["screencapture", "-x", "-t", "png", tmp_path],
                check=True,
                timeout=10,
            )

            with open(tmp_path, "rb") as f:
                screenshot_b64 = base64.b64encode(f.read()).decode()

        except Exception as exc:
            print(f"[FlowBoard] Screenshot failed: {exc}")
            return
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.unlink(tmp_path)

        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/AnalyzeScreenshot",
                headers=self._auth_headers(),
                json={
                    "screenshot_b64": screenshot_b64,
                    "task_id": task["id"],
                    "task_title": task["title"],
                    "task_category": task.get("category", ""),
                    "elapsed_minutes": elapsed_minutes,
                    "estimated_minutes": task.get("estimated_duration", 60),
                },
                timeout=30,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            print(f"[FlowBoard] Analysis request failed: {exc}")
            return

        reports = (data.get("data") or {}).get("reports", [])
        result = reports[0] if reports else {}

        on_task = result.get("on_task", True)
        description = result.get("description", "")
        alert_sent = result.get("alert_sent", False)

        # Update menu bar status
        icon = "✓" if on_task else "⚠"
        self._set_status(f"{icon} {elapsed_minutes} min elapsed")

        # Show native notification if the server triggered an alert
        if alert_sent:
            if not on_task:
                notif_msg = description or "You may be off task."
            else:
                over = elapsed_minutes - task.get("estimated_duration", 60)
                notif_msg = f"You're {over} min over the estimate. Time to wrap up?"
            _notify(
                title="FlowBoard",
                subtitle=f"Task: {task['title']}",
                message=notif_msg,
            )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    FlowBoardWidget().run()

"""FlowBoard Activity Tracker — macOS menu bar widget.

Runs in the background, polls FlowBoard every POLL_INTERVAL seconds,
takes a screenshot on every tick, and uses vision LLM to decide which
(if any) scheduled task the user is currently working on.

State machine
─────────────
  IDLE           No active task, no scheduled tasks in window (or nothing matched)
  TRACKING       Timer running for a specific task
  OUT_OF_SCOPE   Tasks are scheduled right now but the user is doing something
                 unrelated; elapsed time is accumulated and reported to the server

Transitions
───────────
  Any  + match(task)            → TRACKING(task)  [start/switch timer]
  TRACKING(t) + no_match + scheduled_now  → OUT_OF_SCOPE  [pause timer]
  TRACKING(t) + no_match + not scheduled  → IDLE  [pause timer]
  OUT_OF_SCOPE + no_match + not scheduled → IDLE  [record out-of-scope time]
  OUT_OF_SCOPE + no_match + scheduled_now → stay OUT_OF_SCOPE
  IDLE + anything                         → stay IDLE  (until a match appears)

Requirements: pip install rumps requests
Run:          python widget.py
Package:      python setup.py py2app
"""

import argparse
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
# Configuration (CLI args > env vars > defaults)
# ---------------------------------------------------------------------------
def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="FlowBoard Activity Tracker")
    p.add_argument("--server", default=None, help="FlowBoard server URL (e.g. http://147.224.167.95:8000)")
    p.add_argument("--interval", type=int, default=None, help="Poll interval in seconds (default: 120)")
    return p.parse_known_args()[0]  # parse_known_args so rumps args don't cause errors

_args = _parse_args()
FLOWBOARD_URL = (_args.server or os.environ.get("FLOWBOARD_URL", "http://localhost:8000")).rstrip("/")
POLL_INTERVAL = _args.interval or int(os.environ.get("POLL_INTERVAL", "120"))
TOKEN_FILE = os.path.expanduser("~/.flowboard_token")

# States
STATE_IDLE = "IDLE"
STATE_TRACKING = "TRACKING"
STATE_OUT_OF_SCOPE = "OUT_OF_SCOPE"


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

        # --- State machine ---
        self._state: str = STATE_IDLE
        self._active_task_id: str = ""
        self._active_task: dict | None = None
        self._out_of_scope_start: datetime | None = None
        self._paused = False

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
        if self._paused:
            self._set_status("Paused")
            # If we were tracking, pause the server timer
            if self._state == STATE_TRACKING and self._active_task_id:
                threading.Thread(
                    target=self._server_pause_timer,
                    args=(self._active_task_id,),
                    daemon=True,
                ).start()
            # If out-of-scope, record accumulated time
            elif self._state == STATE_OUT_OF_SCOPE:
                self._flush_out_of_scope()
            self._state = STATE_IDLE
            self._active_task_id = ""
            self._active_task = None
        else:
            self._set_status("Idle — watching")

    def _show_login(self, _):
        _login_dialog(self)

    def _logout(self, _):
        self.token = None
        _delete_token()
        self._state = STATE_IDLE
        self._active_task_id = ""
        self._active_task = None
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
    # Server timer calls (run on background threads)
    # ------------------------------------------------------------------

    def _server_start_timer(self, task_id: str) -> bool:
        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/StartTaskTimer",
                headers=self._auth_headers(),
                json={"task_id": task_id},
                timeout=10,
            )
            resp.raise_for_status()
            return True
        except Exception as exc:
            print(f"[FlowBoard] StartTaskTimer failed: {exc}")
            return False

    def _server_pause_timer(self, task_id: str, elapsed_minutes: int = 0) -> bool:
        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/PauseTaskTimer",
                headers=self._auth_headers(),
                json={"task_id": task_id, "elapsed_minutes": elapsed_minutes},
                timeout=10,
            )
            resp.raise_for_status()
            return True
        except Exception as exc:
            print(f"[FlowBoard] PauseTaskTimer failed: {exc}")
            return False

    def _server_record_out_of_scope(self, minutes: int) -> None:
        if minutes <= 0:
            return
        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/RecordOutOfScopeTime",
                headers=self._auth_headers(),
                json={"minutes": minutes},
                timeout=10,
            )
            resp.raise_for_status()
            print(f"[FlowBoard] Recorded {minutes} min out-of-scope")
        except Exception as exc:
            print(f"[FlowBoard] RecordOutOfScopeTime failed: {exc}")

    def _flush_out_of_scope(self) -> None:
        """Record accumulated out-of-scope time to the server and reset."""
        if self._out_of_scope_start is not None:
            minutes = int((datetime.now() - self._out_of_scope_start).total_seconds() / 60)
            self._out_of_scope_start = None
            if minutes > 0:
                threading.Thread(
                    target=self._server_record_out_of_scope,
                    args=(minutes,),
                    daemon=True,
                ).start()

    # ------------------------------------------------------------------
    # Screenshot helper
    # ------------------------------------------------------------------

    def _take_screenshot_b64(self) -> str | None:
        """Capture the screen and return base64-encoded PNG, or None on failure."""
        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tf:
                tmp_path = tf.name
            subprocess.run(
                ["screencapture", "-x", "-t", "png", tmp_path],
                check=True, timeout=10,
            )
            with open(tmp_path, "rb") as f:
                return base64.b64encode(f.read()).decode()
        except Exception as exc:
            print(f"[FlowBoard] Screenshot failed: {exc}")
            return None
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.unlink(tmp_path)

    # ------------------------------------------------------------------
    # Polling — unified state machine
    # ------------------------------------------------------------------

    def _poll(self, _timer=None) -> None:
        """Main poll: screenshot → match → apply state machine transitions."""
        if not self.token or self._paused:
            return

        screenshot_b64 = self._take_screenshot_b64()
        if not screenshot_b64:
            return

        today = datetime.now().strftime("%Y-%m-%d")
        now_time = datetime.now().strftime("%H:%M")

        # --- Call MatchTaskFromScreenshot ---
        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/MatchTaskFromScreenshot",
                headers=self._auth_headers(),
                json={
                    "screenshot_b64": screenshot_b64,
                    "today_date": today,
                    "current_time": now_time,
                },
                timeout=30,
            )
        except Exception as exc:
            print(f"[FlowBoard] MatchTaskFromScreenshot request failed: {exc}")
            return

        if resp.status_code == 401:
            self.token = None
            _delete_token()
            self._set_status("Session expired — please sign in")
            return

        try:
            data = resp.json()
        except Exception:
            return

        reports = (data.get("data") or {}).get("reports", [])
        result = reports[0] if reports else {}

        matched: bool = result.get("matched", False)
        scheduled_now: bool = result.get("scheduled_now", False)
        task_id: str = result.get("task_id", "")
        task_title: str = result.get("task_title", "")
        confidence: int = result.get("confidence", 0)
        reasoning: str = result.get("reasoning", "")

        print(
            f"[FlowBoard] state={self._state} matched={matched} "
            f"scheduled_now={scheduled_now} task_id={task_id} "
            f"confidence={confidence}% reason={reasoning!r}"
        )

        self._apply_transition(
            matched, scheduled_now, task_id, task_title, confidence, reasoning,
            screenshot_b64,
        )

    def _apply_transition(
        self,
        matched: bool,
        scheduled_now: bool,
        task_id: str,
        task_title: str,
        confidence: int,
        reasoning: str,
        screenshot_b64: str,
    ) -> None:
        prev_task_id = self._active_task_id

        if matched and task_id:
            # --- Transition to TRACKING ---
            if self._state == STATE_OUT_OF_SCOPE:
                # Record out-of-scope time before starting task
                self._flush_out_of_scope()

            if self._state == STATE_TRACKING and prev_task_id != task_id:
                # Switch: pause old task, start new one
                elapsed = self._get_active_elapsed()
                threading.Thread(
                    target=self._server_pause_timer,
                    args=(prev_task_id, elapsed),
                    daemon=True,
                ).start()
                _notify(
                    "FlowBoard",
                    f"Switched task",
                    f"Stopped '{self._active_task.get('title', prev_task_id) if self._active_task else prev_task_id}', "
                    f"starting '{task_title}'",
                )

            if self._state != STATE_TRACKING or prev_task_id != task_id:
                # Start the new task timer
                ok = self._server_start_timer(task_id)
                if not ok:
                    return
                self._state = STATE_TRACKING
                self._active_task_id = task_id
                self._active_task = {"id": task_id, "title": task_title}
                title_display = task_title[:40] + "…" if len(task_title) > 40 else task_title
                self._set_status(f"▶ {title_display}")
                self._task_item.title = f"Task: {title_display}"
                _notify(
                    "FlowBoard",
                    f"Timer started: {task_title}",
                    f"{reasoning} (confidence {confidence}%)",
                )
                print(f"[FlowBoard] Started timer for task_id={task_id} ({confidence}%)")
            else:
                # Already tracking the same task — run on-task analysis
                threading.Thread(
                    target=self._analyze_active_task,
                    args=(task_id, task_title, screenshot_b64),
                    daemon=True,
                ).start()

        else:
            # --- No match ---
            if self._state == STATE_TRACKING:
                # Pause the running task
                elapsed = self._get_active_elapsed()
                prev_title = self._active_task.get("title", prev_task_id) if self._active_task else prev_task_id
                threading.Thread(
                    target=self._server_pause_timer,
                    args=(prev_task_id, elapsed),
                    daemon=True,
                ).start()
                self._active_task_id = ""
                self._active_task = None

                if scheduled_now:
                    # Tasks are scheduled but user isn't doing any of them
                    self._state = STATE_OUT_OF_SCOPE
                    self._out_of_scope_start = datetime.now()
                    self._set_status("Out of scope — tasks scheduled")
                    self._task_item.title = "Out of scope"
                    _notify(
                        "FlowBoard",
                        "Timer paused",
                        f"Paused '{prev_title}' — you seem to be doing something else.",
                    )
                    print(f"[FlowBoard] Entered OUT_OF_SCOPE (tasks scheduled, no match)")
                else:
                    # Nothing scheduled — just idle
                    self._state = STATE_IDLE
                    self._set_status("Idle — no scheduled tasks")
                    self._task_item.title = "No active task"
                    _notify(
                        "FlowBoard",
                        "Timer paused",
                        f"No matching task detected. Timer paused for '{prev_title}'.",
                    )
                    print(f"[FlowBoard] Entered IDLE (no scheduled tasks, no match)")

            elif self._state == STATE_OUT_OF_SCOPE:
                if not scheduled_now:
                    # Scheduled window ended — record out-of-scope time and go idle
                    self._flush_out_of_scope()
                    self._state = STATE_IDLE
                    self._set_status("Idle — schedule window ended")
                    self._task_item.title = "No active task"
                    print(f"[FlowBoard] OUT_OF_SCOPE → IDLE (schedule window ended)")
                else:
                    # Still in a scheduled window, still not doing any task
                    elapsed_oos = 0
                    if self._out_of_scope_start:
                        elapsed_oos = int(
                            (datetime.now() - self._out_of_scope_start).total_seconds() / 60
                        )
                    self._set_status(f"Out of scope ({elapsed_oos} min)")
                    print(f"[FlowBoard] Still OUT_OF_SCOPE ({elapsed_oos} min accumulated)")

            else:
                # IDLE — nothing to do
                self._set_status("Idle — watching for tasks")
                self._task_item.title = "No active task"

    def _get_active_elapsed(self) -> int:
        """Get elapsed minutes for the currently active task from server."""
        if not self._active_task_id:
            return 0
        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/GetActiveTask",
                headers=self._auth_headers(),
                json={},
                timeout=10,
            )
            data = resp.json()
            reports = (data.get("data") or {}).get("reports", [])
            result = reports[0] if reports else {}
            if result.get("active"):
                return _elapsed_minutes(
                    result.get("timer_start", ""),
                    result.get("timer_accumulated", 0),
                )
        except Exception:
            pass
        return 0

    # ------------------------------------------------------------------
    # On-task analysis (called when continuing to track the same task)
    # ------------------------------------------------------------------

    def _analyze_active_task(
        self, task_id: str, task_title: str, screenshot_b64: str
    ) -> None:
        """Run AnalyzeScreenshot to check if user is actually on the active task."""
        elapsed = self._get_active_elapsed()

        # Get task details for category + estimated duration
        task = self._active_task or {}
        category = task.get("category", "")
        estimated = task.get("estimated_duration", 60)

        try:
            resp = requests.post(
                f"{FLOWBOARD_URL}/walker/AnalyzeScreenshot",
                headers=self._auth_headers(),
                json={
                    "screenshot_b64": screenshot_b64,
                    "task_id": task_id,
                    "task_title": task_title,
                    "task_category": category,
                    "elapsed_minutes": elapsed,
                    "estimated_minutes": estimated,
                },
                timeout=30,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as exc:
            print(f"[FlowBoard] AnalyzeScreenshot failed: {exc}")
            return

        reports = (data.get("data") or {}).get("reports", [])
        result = reports[0] if reports else {}

        on_task = result.get("on_task", True)
        description = result.get("description", "")
        alert_sent = result.get("alert_sent", False)

        title_display = task_title[:30] + "…" if len(task_title) > 30 else task_title

        if not on_task:
            # User is distracted — pause timer and enter OUT_OF_SCOPE
            self._server_pause_timer(task_id, elapsed)
            self._state = STATE_OUT_OF_SCOPE
            self._active_task_id = ""
            self._active_task = None
            self._out_of_scope_start = datetime.now()
            self._set_status("⚠ Off task — timer paused")
            self._task_item.title = "Out of scope"
            _notify(
                title="FlowBoard",
                subtitle=f"Timer paused: {task_title}",
                message=description or "You appear to be off task. Timer paused.",
            )
            print(f"[FlowBoard] AnalyzeScreenshot off-task → OUT_OF_SCOPE, paused timer for {task_id}")
        else:
            icon = "✓"
            self._set_status(f"{icon} {title_display} ({elapsed} min)")
            if alert_sent:
                over = elapsed - estimated
                _notify(
                    title="FlowBoard",
                    subtitle=f"Task: {task_title}",
                    message=f"You're {over} min over the estimate. Time to wrap up?",
                )


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    FlowBoardWidget().run()

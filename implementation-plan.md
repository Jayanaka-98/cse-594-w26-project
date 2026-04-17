# FlowBoard Agentic AI — Implementation Plan

## Architecture Overview

```
Phase 5 (data) ──────────────────────────────┐
                                              ▼
Phase 1 (duration)   ←── historical data ── UserPatterns

Phase 3 (timer) ──── generates TaskHistory ──► Phase 5

Re-enable conflicts ──┐
                      ▼
Phase 2 (reschedule) ◄─── Phase 3 "Need More Time"
                      │
                      ▼
Phase 4 (optimizer) ◄─── needs conflicting_task_ids from Phase 2
```

**Conflict philosophy:** Rule-based detection (already implemented, just disabled), AI only for *resolving*. Rescheduling/optimization is **always user-initiated** — conflicts prompt, never auto-fix.

---

## Build Order

| Step | Phase | Work |
|---|---|---|
| 1 | Phase 1 | `AIEstimateDuration` walker + TaskModal + ChatPanel wiring |
| 2 | — | Re-enable rule-based conflict detection (one-line fix in `frontend.impl.jac:69`) |
| 3 | Phase 2 | `AIRescheduleTask` walker + conflict prompt + resolution modal |
| 4 | Phase 3 | `NowWorkingOn` component + timer wiring + "Need More Time" |
| 5 | Phase 4 | Sandbox calendar + `AIOptimizeSchedule` trigger |
| 6 | Phase 5 | `AnalyzeUserPatterns` background walker |

---

## Phase 1 — AI Duration Estimation

**Goal:** When creating a task (manually or via chat), AI suggests how long it will realistically take.

### What Already Exists
- `estimate_task_duration(task_title, category, historical_completions)` LLM function → `DurationEstimate` (`suggested_minutes`, `confidence_pct`, `rationale`) in `main.jac`
- `TaskHistory` node schema in `main.jac`
- `fetchAIDuration()` stub in `TaskModal.cl.jac` (lines 37–40) — returns immediately
- `AgentCheckReady` already extracts `task_estimated_duration` from conversation — but doesn't call AI estimation

### Backend Changes (`main.jac`)
- Add `AIEstimateDuration` walker:
  - Traverses `TaskHistory` nodes to build `historical_completions` list
  - Calls `estimate_task_duration(task_title, category, historical_completions)`
  - Reports `{ suggested_minutes, confidence_pct, rationale }`

### Frontend Changes

**`TaskModal.cl.jac`**
- Wire `fetchAIDuration()` to spawn `AIEstimateDuration` on category change or title blur (whichever fires last, debounced)
- Show suggestion inline below the duration field: e.g. `"~45 min (72% confident) — Coding tasks in your history typically run 40% longer"`
- User can accept (fills duration field) or ignore (types their own value)
- Show loading spinner while fetching

**`ChatPanel.cl.jac`**
- After `AgentCheckReady` returns a task with no explicit duration, call `AIEstimateDuration`
- Use the suggested value as `task_estimated_duration` in the confirmation bar
- Show the rationale in the confirmation message: `"I'll create 'Fix auth bug' (AI suggests ~45 min based on your history)"`

### Works Without History
LLM falls back to category + title heuristics. Improves as Phase 5 populates `TaskHistory`.

---

## Phase 2 — AI Rescheduler per Task

**Goal:** When a task is placed on the calendar and conflicts arise, prompt the user to let AI resolve conflicts. User decides whether to act.

### What Already Exists
- `detect_schedule_conflicts_and_replan(new_task, current_schedule, locked_task_ids)` LLM function → `ReplanProposal` in `main.jac`
- `ApplyReplanChanges` walker in `main.jac`
- `computeConflicts()` rule-based logic in `frontend.cl.jac` (lines 136–166) — correct, just disabled
- `ConflictAlertModal` UI component in `frontend.cl.jac` — exists, never triggered

### Step 1: Re-enable Rule-Based Conflict Detection
- In `frontend.impl.jac` lines 69–73: remove the override that zeros out `conflictInfo` and sets `conflictsActive = False`
- `computeConflicts()` will then run naturally after `fetchTasks()`
- This unblocks the `ConflictAlertModal` from appearing

### Backend Changes (`main.jac`)
- Add `AIRescheduleTask` walker:
  - Inputs: `new_task_id: str`, `locked_task_ids: list`
  - Traverses to collect all scheduled tasks (with `start_date` and `start_time`)
  - Finds the triggering task by ID, builds `new_task` dict
  - Calls `detect_schedule_conflicts_and_replan(new_task, current_schedule, locked_task_ids)`
  - Reports the full `ReplanProposal` (list of `ScheduleChange` objects: `task_id`, `new_start_date`, `new_start_time`, `new_end_time`, `reason`)

### Frontend Changes

**Conflict Prompt (user-initiated, not automatic)**
- When `conflictsActive` is true, show a non-blocking banner/toast: `"⚠ Schedule conflict detected. [View & Resolve →]"`
- Clicking "View & Resolve" opens the `ConflictResolutionModal`

**`ConflictResolutionModal` (new or replace `ConflictAlertModal`)**
- Shows list of conflicting tasks and their overlaps
- "Let AI suggest reschedule" button → calls `AIRescheduleTask`
- Loading state while AI runs
- Shows proposed changes: `[ ] Move 'Code review' from Mon 2pm → Mon 4pm (reason: lower priority)`
- Per-change approve/reject checkboxes
- "Apply Selected" → calls `ApplyReplanChanges` for checked items only
- "Cancel" → dismiss, do nothing

**Trigger Points**
- After `createTask()` or `updateTask()` with a `start_time` set
- After drag-drop in CalendarView
- After "Need More Time" in Phase 3

### ChatPanel
- Replace stub at `ChatPanel.cl.jac:137` with: spawn `AIRescheduleTask` → open `ConflictResolutionModal`

---

## Phase 3 — "Now Working On" Panel

**Goal:** Persistent card (like Apple Music's Now Playing) showing the active task with a live timer, pause, done, and "Need More Time" actions.

### What Already Exists
- `StartTaskTimer` walker in `main.jac` (lines 1378–1402)
- `PauseTaskTimer` walker in `main.jac` (lines 1404–1420)
- `FinishTaskTimer` walker in `main.jac` (lines 1422–1464) — writes `TaskHistory` on finish
- `UserPatterns` node: `active_task_id`, `timer_start`, `timer_accumulated`
- Zero frontend wiring

### Backend Changes (`main.jac`)
- Add `GetActiveTask` walker: reads `UserPatterns.active_task_id`, finds that `Task` node, reports full task data + `timer_accumulated` + `timer_start` (so frontend can resume elapsed display)
- `FinishTaskTimer` already writes `TaskHistory` — no changes needed
- Wire `FinishTaskTimer` to trigger `AnalyzeUserPatterns` (Phase 5) asynchronously

### Frontend Changes

**New component: `NowWorkingOn.cl.jac`**
- Floating card, fixed bottom-right, `z-index` above calendar
- Only visible when `activeTaskId != ""`
- Displays: task title, category badge, live elapsed timer (local JS `setInterval`), progress bar against `estimated_duration`
- **Actions:**
  - **Pause** → spawn `PauseTaskTimer(elapsed_minutes)`, hide timer tick
  - **Done** → spawn `FinishTaskTimer(actual_duration)`, clear `activeTaskId` in app state, dismiss card
  - **Need More Time** → inline popover with `+15`, `+30`, `+60 min`, or custom input
    - Updates `task.end_time` via `updateTask()`
    - Triggers Phase 2 conflict detection for tasks that follow → shows conflict prompt if needed

**Global app state additions (`frontend.cl.jac`)**
- `activeTaskId: str = ""`
- `activeTaskTitle: str = ""`
- `activeTaskEstimated: int = 0`
- `timerElapsed: int = 0` (updated via `setInterval`)

**Start task trigger**
- "Start" button on `TaskDetailPanel` and on CalendarView task cards → spawn `StartTaskTimer(task_id)`, set global `activeTaskId`
- On app load: call `GetActiveTask` to restore in-progress timer across reloads

---

## Phase 4 — Sandbox Calendar (Global Schedule Optimizer)

**Goal:** User-triggered global optimization shown as a sandbox overlay on the calendar. Only future tasks within the next 7 days. Nothing writes to real calendar until explicit approval.

### Scope Constraint
- Only tasks with `start_date` in `[today, today + 7 days]` are included in the optimization input and sandbox overlay
- Locked tasks (`is_locked = true`) are never moved

### What Already Exists
- `AIOptimizeSchedule` walker fully implemented in `main.jac` (lines 1760–1835)
- `optimize_conflicted_schedule()` LLM function with full semantic annotations
- `ApplyReplanChanges` walker in `main.jac`
- `ModifyScheduleView` component — exists but never shown
- `UserPatterns.productivity_peaks` used by the optimizer

### Trigger (User-Initiated)
- "Optimize Week" button in CalendarView toolbar, only enabled when `conflictsActive == true` (i.e., there are known conflicts)
- Also accessible from the conflict prompt banner: `"[Optimize full week →]"`

### Backend Changes (`main.jac`)
- Modify `AIOptimizeSchedule` to accept a `date_range_end: str` parameter and filter tasks to `start_date <= date_range_end` (7 days from today)
- Or filter on the frontend before spawning the walker — simpler, prefer this

### Frontend Changes

**Sandbox state additions (`frontend.cl.jac`)**
- `sandboxMode: bool = False`
- `sandboxChanges: list = []` — AI proposed changes (each: `task_id`, `new_start_date`, `new_start_time`, `new_end_time`, `reason`)
- `sandboxApproved: set = {}` — IDs of changes the user has approved
- `sandboxUserOverrides: dict = {}` — user-dragged adjustments within the sandbox

**CalendarView sandbox rendering**
- When `sandboxMode == true`:
  - Existing scheduled tasks render at 30% opacity with a dashed border (the "shadow")
  - Each proposed change renders as a full-opacity card in a distinct color (teal/purple) at the new proposed time
  - Proposed cards are draggable — dragging updates `sandboxUserOverrides[task_id]` (does not touch real task data)
  - Each proposed card has an inline ✓ (approve) and ✗ (reject) button
  - Approved cards turn green; rejected cards disappear (original shadow remains)
  - Toolbar shows: `"Sandbox Mode — X of Y changes approved"` + **"Approve All"** + **"Discard"**

**"Approve All" flow**
- Merges `sandboxChanges` with `sandboxUserOverrides` for final positions
- Calls `ApplyReplanChanges` with the merged change list
- Exits sandbox mode, `fetchTasks()` to reload real data

**"Discard" flow**
- Clears all sandbox state, exits sandbox mode — real calendar unchanged

---

## Phase 5 — Background Memory / Timing Analysis

**Goal:** Asynchronously analyse `TaskHistory` to update `UserPatterns` (real overrun ratios, productivity peaks). Runs silently, feeds back into Phase 1 and Phase 2.

### What Already Exists
- `UserPatterns` node: `category_overrun_ratios` dict, `productivity_peaks` dict
- `TaskHistory` nodes written by `FinishTaskTimer`
- `GetUserPatterns` / `UpdateUserPatterns` walkers
- Frontend currently uses **hardcoded** ratios (Coding: 1.42x, Research: 1.35x, etc.) instead of real ones

### Backend Changes (`main.jac`)
- Add `AnalyzeUserPatterns` walker:
  - Collects all `TaskHistory` nodes from root
  - Groups by `category`, computes `mean(actual_duration / estimated_duration)` per group
  - Updates `UserPatterns.category_overrun_ratios`
  - Optionally: derives `productivity_peaks` from what hours tasks were started and completed fastest (needs more `TaskHistory` data — can defer)
  - Reports `{ updated: true, ratios: {...} }`
- Chain: call `AnalyzeUserPatterns` at the end of `FinishTaskTimer` (background — fire and forget, don't block the response)

### Frontend Changes
- `computeConflicts()` in `frontend.cl.jac` currently uses hardcoded overrun ratios
- After `fetchTasks()`, also fetch `UserPatterns` via `GetUserPatterns`
- Pass real `category_overrun_ratios` into `computeConflicts()` instead of the hardcoded map
- CalendarView's `computeLocalConflicts()` has its own hardcoded copy — update it too

### When It Runs
- Triggered automatically after `FinishTaskTimer` — silent, no UI feedback
- No scheduled polling or cron needed initially; event-driven is sufficient
- Later: could run on login if `last_updated` is stale (> 24 hours)

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Conflict detection = rule-based, resolution = AI | Rule-based is fast, deterministic, and already implemented. AI is only needed for the creative part: *where* to move things. |
| All rescheduling is user-initiated | Avoid surprising the user with silent changes. Show a prompt, let them choose. |
| Sandbox only covers next 7 days | Optimization beyond a week is too speculative to be useful; keeps the AI's context small and its suggestions concrete. |
| `NowWorkingOn` feeds `TaskHistory` feeds `UserPatterns` feeds duration estimation | The data flywheel: using the app improves its suggestions over time. |
| `AnalyzeUserPatterns` is event-driven, not scheduled | Simpler to implement, sufficient for now. Run after every task completion. |

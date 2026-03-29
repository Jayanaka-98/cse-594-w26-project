"""Now Working On — floating timer card showing the active task with pause/done/more-time."""

sv import from main { GetActiveTask, StartTaskTimer, PauseTaskTimer, FinishTaskTimer, UpdateTask }
import from "lucide-react" { Play, Pause, CheckCircle, Clock, Plus }

def:pub NowWorkingOn(
    onTasksChanged: any,
    taskToStart: dict = {}
) -> any {
    has activeId: str = "",
        activeTitle: str = "",
        activeCat: str = "",
        activeDur: int = 60,
        activeStatus: str = "",
        activePrio: str = "",
        activeDue: str = "",
        activeSd: str = "",
        activeSt: str = "",
        activeEt: str = "",
        activeDesc: str = "",
        isRunning: bool = False,
        elapsedSeconds: int = 0,
        intervalId: int = 0,
        showMoreTime: bool = False,
        customMinutes: str = "",
        loaded: bool = False;

    can with entry {
        if not loaded { loaded = True; restoreActive(); }
    }

    can with [taskToStart] entry {
        if taskToStart {
            rawId = taskToStart["id"];
            tid: str = str(rawId) if rawId else "";
            if tid != "" and tid != activeId { beginTask(taskToStart); }
        }
    }

    async def restoreActive -> None {
        result = root spawn GetActiveTask();
        if result.reports and result.reports[0] {
            d = result.reports[0];
            if d["active"] and d["task"] {
                t = d["task"];
                activeId     = str(t["id"]) if t["id"] else "";
                activeTitle  = str(t["title"]) if t["title"] else "";
                activeCat    = str(t["category"]) if t["category"] else "";
                activeDur    = int(t["estimated_duration"]) if t["estimated_duration"] else 60;
                activeStatus = str(t["status"]) if t["status"] else "";
                activePrio   = str(t["priority"]) if t["priority"] else "normal";
                activeDue    = str(t["due_date"]) if t["due_date"] else "";
                activeSd     = str(t["start_date"]) if t["start_date"] else "";
                activeSt     = str(t["start_time"]) if t["start_time"] else "";
                activeEt     = str(t["end_time"]) if t["end_time"] else "";
                activeDesc   = str(t["description"]) if t["description"] else "";
                accumulated: int = int(d["timer_accumulated"]) if d["timer_accumulated"] else 0;
                elapsedSeconds = accumulated * 60;
                isRunning = True;
                startTick();
            }
        }
    }

    def startTick -> None {
        if intervalId { clearInterval(intervalId); }
        intervalId = setInterval(lambda -> None { elapsedSeconds = elapsedSeconds + 1; }, 1000);
    }

    def stopTick -> None {
        if intervalId { clearInterval(intervalId); intervalId = 0; }
    }

    async def beginTask(task: dict) -> None {
        rawId   = task["id"];
        rawTitl = task["title"];
        rawCat  = task["category"];
        rawDur  = task["estimated_duration"];
        rawStat = task["status"];
        rawPrio = task["priority"];
        rawDue  = task["due_date"];
        rawSd   = task["start_date"];
        rawSt   = task["start_time"];
        rawEt   = task["end_time"];
        rawDesc = task["description"];
        activeId     = str(rawId) if rawId else "";
        activeTitle  = str(rawTitl) if rawTitl else "";
        activeCat    = str(rawCat) if rawCat else "";
        activeDur    = int(rawDur) if rawDur else 60;
        activeStatus = str(rawStat) if rawStat else "";
        activePrio   = str(rawPrio) if rawPrio else "normal";
        activeDue    = str(rawDue) if rawDue else "";
        activeSd     = str(rawSd) if rawSd else "";
        activeSt     = str(rawSt) if rawSt else "";
        activeEt     = str(rawEt) if rawEt else "";
        activeDesc   = str(rawDesc) if rawDesc else "";
        root spawn StartTaskTimer(task_id=activeId);
        isRunning = True;
        elapsedSeconds = 0;
        startTick();
    }

    async def pauseTask -> None {
        stopTick();
        isRunning = False;
        elapsedMins: int = elapsedSeconds // 60;
        root spawn PauseTaskTimer(task_id=activeId, elapsed_minutes=elapsedMins);
    }

    async def resumeTask -> None {
        isRunning = True;
        startTick();
        root spawn StartTaskTimer(task_id=activeId);
    }

    async def finishTask -> None {
        stopTick();
        elapsedMins: int = elapsedSeconds // 60;
        root spawn FinishTaskTimer(task_id=activeId, actual_duration=elapsedMins);
        activeId = "";
        isRunning = False;
        elapsedSeconds = 0;
        showMoreTime = False;
        onTasksChanged();
    }

    async def addMoreTime(extraMins: int) -> None {
        if activeId == "" { return; }
        showMoreTime = False;
        etVal: str = activeEt;
        newEnd: str = etVal;
        if etVal != "" {
            parts: list = etVal.split(":");
            if len(parts) == 2 {
                totalMins: int = int(parts[0]) * 60 + int(parts[1]) + extraMins;
                h: int = (totalMins // 60) % 24;
                m: int = totalMins % 60;
                newEnd = str(h).zfill(2) + ":" + str(m).zfill(2);
            }
        }
        root spawn UpdateTask(
            task_id=activeId, title=activeTitle, description=activeDesc,
            status=activeStatus, priority=activePrio, due_date=activeDue,
            start_date=activeSd, start_time=activeSt, end_time=newEnd,
            estimated_duration=activeDur, category=activeCat
        );
        activeEt = newEnd;
        onTasksChanged();
    }

    def formatElapsed(secs: int) -> str {
        m: int = secs // 60;
        s: int = secs % 60;
        return str(m).zfill(2) + ":" + str(s).zfill(2);
    }

    hasActive: bool = activeId != "";
    estimatedSecs: int = activeDur * 60 if hasActive else 3600;
    rawPct: int = elapsedSeconds * 100 // estimatedSecs if estimatedSecs > 0 else 0;
    pct: int = rawPct if rawPct < 100 else 100;
    isOverrun: bool = elapsedSeconds > estimatedSecs;
    displayCat: str = activeCat if activeCat != "" else "Other";

    return
        <div className="nwo-card">
            <div className="nwo-header">
                <span className="nwo-label">Now Working On</span>
                <Clock size={13} className="nwo-label" />
            </div>
            {(
                <div className="nwo-body">
                    <p className="nwo-task-title">{activeTitle}</p>
                    <span className="nwo-cat-badge">{displayCat}</span>
                    <div className="nwo-timer">{formatElapsed(elapsedSeconds)}</div>
                    <div className="nwo-progress-bar">
                        <div
                            className={"nwo-progress-fill" + (" overrun" if isOverrun else "")}
                            style={{"width": str(pct) + "%"}}
                        ></div>
                    </div>
                    <div className="nwo-actions">
                        {(
                            <button className="nwo-btn" onClick={lambda -> None { pauseTask(); }}>
                                <Pause size={13} /> Pause
                            </button>
                        ) if isRunning else (
                            <button className="nwo-btn" onClick={lambda -> None { resumeTask(); }}>
                                <Play size={13} /> Resume
                            </button>
                        )}
                        <button className="nwo-btn" onClick={lambda -> None { showMoreTime = not showMoreTime; }}>
                            <Plus size={13} /> More Time
                        </button>
                        <button className="nwo-btn nwo-btn-done" onClick={lambda -> None { finishTask(); }}>
                            <CheckCircle size={13} /> Done
                        </button>
                    </div>
                    {(
                        <div className="nwo-more-time-popover">
                            <span className="nwo-more-time-label">Add how much time?</span>
                            <div className="nwo-time-chips">
                                <button className="nwo-chip" onClick={lambda -> None { addMoreTime(15); }}>+15 min</button>
                                <button className="nwo-chip" onClick={lambda -> None { addMoreTime(30); }}>+30 min</button>
                                <button className="nwo-chip" onClick={lambda -> None { addMoreTime(60); }}>+1 hr</button>
                            </div>
                            <div className="nwo-custom-row">
                                <input
                                    type="number"
                                    value={customMinutes}
                                    onChange={lambda e: any -> None { customMinutes = e.target.value; }}
                                    placeholder="Custom min"
                                    className="nwo-custom-input"
                                    min={1}
                                />
                                <button
                                    className="nwo-custom-btn"
                                    onClick={lambda -> None {
                                        if customMinutes { addMoreTime(int(customMinutes)); customMinutes = ""; }
                                    }}
                                >Add</button>
                            </div>
                        </div>
                    ) if showMoreTime else None}
                </div>
            ) if hasActive else (
                <div className="nwo-idle">
                    <Clock size={28} className="nwo-idle-icon" />
                    <p className="nwo-idle-text">No task in progress</p>
                    <p className="nwo-idle-sub">Open a task and click Start to begin tracking</p>
                </div>
            )}
        </div>;
}

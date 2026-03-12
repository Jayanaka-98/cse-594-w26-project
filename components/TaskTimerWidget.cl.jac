"""Floating task timer widget — shows active task, elapsed time, pause/finish controls."""

sv import from main { StartTaskTimer, PauseTaskTimer, FinishTaskTimer, ListTasks, AIGenerateOverrunAlert }
import from "lucide-react" { AlertTriangle, Check, Pause, Play }

def:pub TaskTimerWidget(
    onTimerFinish: any,
    onOverrunAlert: any
) -> any {
    has activeTaskId: str = "",
        activeTask: any = None,
        elapsedSeconds: int = 0,
        isRunning: bool = False,
        intervalId: any = None,
        nextTask: any = None,
        tasks: list = [],
        overrunTriggered: bool = False;

    can with entry {
        fetchTasks();
    }

    async def fetchTasks -> None {
        result = root spawn ListTasks(list_id="");
        tasks = result.reports[0] if result.reports else [];
    }

    def findNextTask -> any {
        scheduled = tasks.filter(lambda t: any -> bool {
            return t.start_date != "" and t.start_time != "" and t.id != activeTaskId and t.status != "done";
        });
        if len(scheduled) == 0 { return None; }
        sorted = scheduled.sort(lambda a: any, b: any -> int {
            ka = a.start_date + "T" + a.start_time;
            kb = b.start_date + "T" + b.start_time;
            return 0 if ka == kb else (-1 if ka < kb else 1);
        });
        return sorted[0];
    }

    def formatElapsed(secs: int) -> str {
        m = Math.floor(secs / 60);
        s = secs % 60;
        return m.toString().padStart(2, "0") + ":" + s.toString().padStart(2, "0");
    }

    def formatTaskTime(t: str) -> str {
        if not t or t == "" { return ""; }
        parts = t.split(":");
        h = parseInt(parts[0]);
        suffix = "AM" if h < 12 else "PM";
        dh = h if h <= 12 else h - 12;
        if h == 0 { dh = 12; }
        return dh.toString() + ":" + parts[1] + " " + suffix;
    }

    async def startTask(task: any) -> None {
        activeTaskId = task.id;
        activeTask = task;
        elapsedSeconds = 0;
        isRunning = True;
        overrunTriggered = False;
        nextTask = findNextTask();
        root spawn StartTaskTimer(task_id=task.id);
        if intervalId { clearInterval(intervalId); }
        intervalId = setInterval(lambda -> None { tick(); }, 1000);
    }

    def tick -> None {
        elapsedSeconds = elapsedSeconds + 1;
        elapsedMins = Math.floor(elapsedSeconds / 60);
        if activeTask and not overrunTriggered and elapsedMins >= activeTask.estimated_duration and activeTask.estimated_duration > 0 {
            overrunTriggered = True;
            triggerOverrunAlert(elapsedMins);
        }
    }

    async def triggerOverrunAlert(elapsedMins: int) -> None {
        result = root spawn AIGenerateOverrunAlert(task_id=activeTaskId, elapsed_minutes=elapsedMins);
        if result.reports {
            onOverrunAlert(result.reports[0]);
        }
    }

    async def pauseTask -> None {
        isRunning = False;
        if intervalId { clearInterval(intervalId); intervalId = None; }
        elapsedMins = Math.floor(elapsedSeconds / 60);
        root spawn PauseTaskTimer(task_id=activeTaskId, elapsed_minutes=elapsedMins);
    }

    async def finishTask -> None {
        if intervalId { clearInterval(intervalId); intervalId = None; }
        elapsedMins = Math.floor(elapsedSeconds / 60);
        root spawn FinishTaskTimer(task_id=activeTaskId, actual_duration=elapsedMins);
        onTimerFinish(activeTaskId, elapsedMins);
        activeTaskId = "";
        activeTask = None;
        elapsedSeconds = 0;
        isRunning = False;
        overrunTriggered = False;
        await fetchTasks();
    }

    if activeTask == None {
        schedulable = tasks.filter(lambda t: any -> bool {
            return t.status != "done" and t.status == "in_progress";
        });
        if len(schedulable) == 0 {
            schedulable = tasks.filter(lambda t: any -> bool {
                return t.status == "todo" and t.start_date != "" and t.start_time != "";
            });
        }

        return
            <div className="timer-widget timer-widget-idle">
                <div className="timer-widget-header">
                    <span className="timer-widget-label">TASK TIMER</span>
                </div>
                <p className="timer-idle-text">No active task</p>
                {(
                    <div className="timer-start-list">
                        {[
                            <button
                                key={t.id}
                                className="timer-start-btn"
                                onClick={lambda -> None { startTask(t); }}
                            >
                                <Play size={11} /> {t.title}
                            </button>
                            for t in schedulable.slice(0, 3)
                        ]}
                    </div>
                ) if len(schedulable) > 0 else None}
            </div>;
    }

    elapsedMins = Math.floor(elapsedSeconds / 60);
    isOverrun = activeTask and elapsedMins >= activeTask.estimated_duration and activeTask.estimated_duration > 0;

    return
        <div className={"timer-widget" + (" timer-widget-overrun" if isOverrun else "")}>
            <div className="timer-widget-header">
                <span className="timer-widget-label">CURRENT TASK</span>
                {(
                    <span className="timer-overrun-badge"><AlertTriangle size={12} /> Overrun</span>
                ) if isOverrun else None}
            </div>
            <div className="timer-task-name">{activeTask.title}</div>
            {(
                <div className={"timer-category-tag timer-cat-" + activeTask.category.toLowerCase()}>
                    {activeTask.category}
                </div>
            ) if activeTask.category and activeTask.category != "" else None}
            <div className={"timer-elapsed" + (" timer-elapsed-overrun" if isOverrun else "")}>
                {formatElapsed(elapsedSeconds)}
            </div>
            {(
                <div className="timer-estimate-row">
                    <span className="timer-estimate-label">Est:</span>
                    <span className="timer-estimate-val">
                        {activeTask.estimated_duration.toString() + " min"}
                    </span>
                </div>
            ) if activeTask.estimated_duration > 0 else None}
            <div className="timer-controls">
                {(
                    <button className="timer-btn-pause" onClick={lambda -> None { pauseTask(); }}>
                        <Pause size={13} /> Pause
                    </button>
                ) if isRunning else (
                    <button className="timer-btn-resume" onClick={lambda -> None {
                        isRunning = True;
                        intervalId = setInterval(lambda -> None { tick(); }, 1000);
                    }}>
                        <Play size={13} /> Resume
                    </button>
                )}
                <button className="timer-btn-finish" onClick={lambda -> None { finishTask(); }}>
                    <Check size={13} /> Finish
                </button>
            </div>
            {(
                <div className="timer-next-task">
                    <span className="timer-next-label">Next Task:</span>
                    <span className="timer-next-name">{nextTask.title}</span>
                    <span className="timer-next-time">{formatTaskTime(nextTask.start_time)}</span>
                </div>
            ) if nextTask else None}
        </div>;
}

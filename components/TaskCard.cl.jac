"""Task card component for list and board views."""

import from "lucide-react" { X, Play, Pause, Check }

def:pub TaskCard(
    task: dict,
    onOpenDetail: any,
    onStatusChange: any,
    onDelete: any,
    activeTask: dict = {},
    timerTick: int = 0,
    onStartTimer: any = None,
    onPauseTimer: any = None,
    onResumeTimer: any = None,
    onFinishTimer: any = None
) -> JsxElement {
    priorityClass = (
        "priority-urgent" if task.priority == "urgent"
        else ("priority-high" if task.priority == "high"
        else ("priority-normal" if task.priority == "normal"
        else "priority-low"))
    );
    priorityLabel = (
        "URGENT" if task.priority == "urgent"
        else ("HIGH" if task.priority == "high"
        else ("NORMAL" if task.priority == "normal"
        else "LOW"))
    );
    statusClass = (
        "status-todo" if task.status == "todo"
        else ("status-in-progress" if task.status == "in_progress"
        else ("status-review" if task.status == "review"
        else "status-done"))
    );
    hasActiveTimer = activeTask and activeTask["active_task_id"] and activeTask["active_task_id"] != "";
    isRunning = hasActiveTimer and activeTask["is_running"];

    def elapsedMinutes -> int {
        if not hasActiveTimer { return 0; }
        base = int(activeTask["timer_accumulated"]) if activeTask["timer_accumulated"] else 0;
        if not isRunning { return base; }
        started = Reflect.construct(Date, [activeTask["last_updated"]]);
        now = Reflect.construct(Date, []);
        extra = Math.floor((now.getTime() - started.getTime()) / 60000);
        return base + (extra if extra > 0 else 0);
    }

    elapsedMins = elapsedMinutes();

    return
        <div className="task-card" onClick={lambda -> None { onOpenDetail(task); }}>
            <div className="task-card-top">
                <div className={"priority-bar " + priorityClass}></div>
                <div className="task-card-body">
                    <div className="task-card-header">
                        <span className="task-card-title">{task.title}</span>
                        <button
                            onClick={lambda e: any -> None { e.stopPropagation(); onDelete(task.id); }}
                            className="task-delete-btn"
                            title="Delete task"
                        >
                            <X size={14} />
                        </button>
                    </div>
                    {(
                        <p className="task-card-desc">
                            {task.description}
                        </p>
                    ) if task.description else None}
                    <div className="task-card-footer">
                        <select
                            value={task.status}
                            onClick={lambda e: any -> None { e.stopPropagation(); }}
                            onChange={lambda e: any -> None { e.stopPropagation(); onStatusChange(task.id, e.target.value); }}
                            className={"status-select " + statusClass}
                        >
                            <option value="todo">Todo</option>
                            <option value="in_progress">In Progress</option>
                            <option value="review">Review</option>
                            <option value="done">Done</option>
                        </select>
                        <span className={"priority-badge " + priorityClass}>
                            {priorityLabel}
                        </span>
                        {(
                            <span className="task-timer-chip">
                                {str(elapsedMins) + " min"}
                            </span>
                        ) if hasActiveTimer else None}
                        {(
                            <button
                                onClick={lambda e: any -> None { e.stopPropagation(); onStartTimer(task); }}
                                className="btn-primary btn-xs"
                                title="Start timer"
                            >
                                <Play size={12} /> Start
                            </button>
                        ) if onStartTimer and not hasActiveTimer and task.status != "done" else (
                            <button
                                onClick={lambda e: any -> None { e.stopPropagation(); onPauseTimer(task.id, elapsedMins); }}
                                className="btn-secondary btn-xs"
                                title="Pause timer"
                            >
                                <Pause size={12} /> Pause
                            </button>
                        ) if onPauseTimer and hasActiveTimer and isRunning else (
                            <button
                                onClick={lambda e: any -> None { e.stopPropagation(); onResumeTimer(task); }}
                                className="btn-primary btn-xs"
                                title="Resume timer"
                            >
                                <Play size={12} /> Resume
                            </button>
                        ) if onResumeTimer and hasActiveTimer and not isRunning else None}
                        {(
                            <button
                                onClick={lambda e: any -> None { e.stopPropagation(); onFinishTimer(task.id, elapsedMins); }}
                                className="btn-secondary btn-xs"
                                title="Finish task"
                            >
                                <Check size={12} /> Finish
                            </button>
                        ) if onFinishTimer and hasActiveTimer else None}
                    </div>
                </div>
            </div>
        </div>;
}

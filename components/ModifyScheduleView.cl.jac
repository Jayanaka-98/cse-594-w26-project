"""Modify Schedule — 3-panel AI conflict resolution view."""

sv import from main { AIOptimizeSchedule, ApplyReplanChanges }
import from "lucide-react" { ArrowLeft, AlertTriangle, CheckCircle, GripVertical, Clock, Check }

def:pub ModifyScheduleView(
    tasks: list,
    conflictInfo: dict,
    onBack: any,
    onSaved: any
) -> any {
    has loading: bool = True,
        optimization: any = None,
        suggestedTasks: list = [],
        dragIndex: int = -1,
        saving: bool = False,
        saved: bool = False;

    can with entry {
        fetchOptimization();
    }

    async def fetchOptimization -> None {
        loading = True;
        conflictingIds = conflictInfo.conflicting_ids if conflictInfo.conflicting_ids else [];
        result = root spawn AIOptimizeSchedule(conflicting_task_ids=conflictingIds);
        if result.reports {
            optimization = result.reports[0];
            suggestedTasks = buildSuggestedList(optimization.changes);
        }
        loading = False;
    }

    def buildSuggestedList(changes: list) -> list {
        taskMap = {};
        for t in tasks {
            taskMap[t.id] = t;
        }
        suggested = [];
        changedIds = [c.task_id for c in changes];
        for change in changes {
            orig = taskMap[change.task_id] if change.task_id in taskMap else None;
            if orig {
                suggested.append({
                    "id": orig.id,
                    "title": orig.title,
                    "start_date": change.new_start_date,
                    "start_time": change.new_start_time,
                    "end_time": change.new_end_time,
                    "category": orig.category,
                    "estimated_duration": orig.estimated_duration,
                    "priority": orig.priority,
                    "reason": change.reason,
                    "changed": True
                });
            }
        }
        for t in tasks {
            if t.start_date != "" and t.start_time != "" and t.status != "done" and not changedIds.includes(t.id) {
                suggested.append({
                    "id": t.id,
                    "title": t.title,
                    "start_date": t.start_date,
                    "start_time": t.start_time,
                    "end_time": t.end_time,
                    "category": t.category,
                    "estimated_duration": t.estimated_duration,
                    "priority": t.priority,
                    "reason": "",
                    "changed": False
                });
            }
        }
        return suggested.sort(lambda a: any, b: any -> int {
            ka = a.start_date + "T" + a.start_time;
            kb = b.start_date + "T" + b.start_time;
            return 0 if ka == kb else (-1 if ka < kb else 1);
        });
    }

    def formatTime(t: str) -> str {
        if not t or t == "" { return ""; }
        parts = t.split(":");
        h = parseInt(parts[0]);
        suffix = "AM" if h < 12 else "PM";
        dh = h if h <= 12 else h - 12;
        if h == 0 { dh = 12; }
        return dh.toString() + ":" + parts[1] + " " + suffix;
    }

    def formatDate(d: str) -> str {
        if not d or d == "" { return ""; }
        dt = Reflect.construct(Date, [d + "T12:00:00"]);
        days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return days[dt.getDay()] + ", " + months[dt.getMonth()] + " " + dt.getDate().toString();
    }

    def getPriorityColor(p: str) -> str {
        if p == "urgent" { return "#ef4444"; }
        if p == "high" { return "#f97316"; }
        if p == "normal" { return "#6366f1"; }
        return "#64748b";
    }

    conflictingIds = conflictInfo.conflicting_ids if conflictInfo.conflicting_ids else [];

    scheduledTasks = tasks.filter(lambda t: any -> bool {
        return t.start_date != "" and t.start_time != "" and t.status != "done";
    }).sort(lambda a: any, b: any -> int {
        ka = a.start_date + "T" + a.start_time;
        kb = b.start_date + "T" + b.start_time;
        return 0 if ka == kb else (-1 if ka < kb else 1);
    });

    totalSuggestedMins = 0;
    for st in suggestedTasks {
        totalSuggestedMins = totalSuggestedMins + (st.estimated_duration if st.estimated_duration else 0);
    }

    async def handleSave -> None {
        saving = True;
        changes = [
            {
                "task_id": st.id,
                "new_start_date": st.start_date,
                "new_start_time": st.start_time,
                "new_end_time": st.end_time
            }
            for st in suggestedTasks if st.changed
        ];
        if len(changes) > 0 {
            root spawn ApplyReplanChanges(changes=changes);
        }
        saving = False;
        saved = True;
        onSaved();
    }

    def handleRevertToAI -> None {
        if optimization {
            suggestedTasks = buildSuggestedList(optimization.changes);
        }
    }

    return
        <div className="msv-root">

            <div className="msv-topbar">
                <button className="msv-back-btn" onClick={onBack}>
                    <ArrowLeft size={16} /> Modify Schedule
                </button>
                <span className="msv-date-label">
                    {Reflect.construct(Date, []).toLocaleDateString("en-US", {"weekday": "long", "year": "numeric", "month": "long", "day": "numeric"})}
                </span>
            </div>

            <div className="msv-body">

                <div className="msv-panel msv-panel-current">
                    <div className="msv-panel-header">
                        <span className="msv-panel-title">Current Schedule</span>
                        <span className="msv-panel-subtitle">Your original schedule with conflicts</span>
                    </div>
                    <div className="msv-task-list">
                        {[
                            <div
                                key={t.id}
                                className={"msv-task-row" + (" msv-task-conflict" if conflictingIds.includes(t.id) else "")}
                            >
                                <div className="msv-task-time">
                                    <Clock size={12} />
                                    {formatTime(t.start_time) + "  " + (t.estimated_duration.toString() + " min")}
                                </div>
                                <div className="msv-task-info">
                                    <span className="msv-task-title">{t.title}</span>
                                    {(
                                        <span className={"msv-task-cat msv-cat-" + t.category.toLowerCase()}>
                                            {t.category}
                                        </span>
                                    ) if t.category else None}
                                </div>
                                {(
                                    <div className="msv-conflict-label">
                                        <AlertTriangle size={11} /> Conflicts with other tasks
                                    </div>
                                ) if conflictingIds.includes(t.id) else None}
                            </div>
                            for t in scheduledTasks
                        ]}
                    </div>
                </div>

                <div className="msv-panel msv-panel-ai">
                    <div className="msv-panel-header">
                        <span className="msv-panel-title">AI Suggested Schedule</span>
                        <span className="msv-panel-subtitle">Drag and drop to customize the AI recommendations</span>
                    </div>
                    {(
                        <div className="msv-loading">
                            <div className="loading-spinner"></div>
                            <span>Generating AI schedule...</span>
                        </div>
                    ) if loading else (
                        <div>
                            <div className="msv-task-list">
                                {[
                                    <div
                                        key={st.id}
                                        className={"msv-task-row msv-task-suggested" + (" msv-task-changed" if st.changed else "")}
                                        draggable={True}
                                        onDragStart={lambda -> None { dragIndex = suggestedTasks.indexOf(st); }}
                                        onDragOver={lambda e: any -> None { e.preventDefault(); }}
                                        onDrop={lambda -> None {
                                            dropIdx = suggestedTasks.indexOf(st);
                                            if dragIndex >= 0 and dragIndex != dropIdx {
                                                reordered = suggestedTasks.filter(lambda x: any -> bool { return x.id != suggestedTasks[dragIndex].id; });
                                                reordered.splice(dropIdx, 0, suggestedTasks[dragIndex]);
                                                suggestedTasks = reordered;
                                            }
                                            dragIndex = -1;
                                        }}
                                    >
                                        <GripVertical size={14} className="msv-drag-handle" />
                                        <div className="msv-task-time">
                                            <Clock size={12} />
                                            {formatTime(st.start_time) + "  " + (st.estimated_duration.toString() + " min")}
                                        </div>
                                        <div className="msv-task-info">
                                            <span className="msv-task-title">{st.title}</span>
                                            {(
                                                <span className={"msv-task-cat msv-cat-" + st.category.toLowerCase()}>
                                                    {st.category}
                                                </span>
                                            ) if st.category else None}
                                        </div>
                                    </div>
                                    for st in suggestedTasks
                                ]}
                            </div>
                            {(
                                <div className="msv-resolved-banner">
                                    <CheckCircle size={14} />
                                    {"All conflicts resolved. This schedule includes " + str(len(suggestedTasks)) + " tasks totaling " + totalSuggestedMins.toString() + " minutes."}
                                </div>
                            ) if optimization and optimization.all_conflicts_resolved else None}
                        </div>
                    )}
                </div>

                <div className="msv-panel msv-panel-why">
                    <div className="msv-panel-header">
                        <span className="msv-panel-title">Why This Schedule?</span>
                    </div>
                    {(
                        <div>
                            <div className="msv-overview-card">
                                <div className="msv-overview-label">Schedule Overview</div>
                                <p className="msv-overview-text">
                                    {optimization.overview if optimization else "Analyzing your schedule..."}
                                </p>
                            </div>
                            {(
                                <div className="msv-optimizations">
                                    <div className="msv-opt-label">Key Optimizations</div>
                                    {[
                                        <div key={entry[0].toString()} className="msv-opt-row">
                                            <div className="msv-opt-num">{(entry[0] + 1).toString()}</div>
                                            <div className="msv-opt-content">
                                                <div className="msv-opt-title">{entry[1].title}</div>
                                                <div className="msv-opt-desc">{entry[1].description}</div>
                                            </div>
                                        </div>
                                        for entry in optimization.optimizations.entries()
                                    ]}
                                </div>
                            ) if optimization and optimization.optimizations and len(optimization.optimizations) > 0 else None}
                        </div>
                    ) if not loading else (
                        <div className="msv-loading">
                            <div className="loading-spinner"></div>
                        </div>
                    )}
                </div>

            </div>

            <div className="msv-footer">
                <button className="msv-btn-decline" onClick={onBack}>
                    Decline Changes
                </button>
                <div className="msv-footer-right">
                    <button className="msv-btn-revert" onClick={lambda -> None { handleRevertToAI(); }}>
                        Revert to AI Plan
                    </button>
                    <button
                        className="msv-btn-save"
                        onClick={lambda -> None { handleSave(); }}
                        disabled={saving or loading}
                    >
                        {(<div className="loading-spinner loading-spinner-sm"></div>) if saving else (<Check size={14} />)}
                        Save Changes
                    </button>
                </div>
            </div>

        </div>;
}

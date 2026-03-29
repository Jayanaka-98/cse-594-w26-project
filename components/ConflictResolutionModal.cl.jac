"""Conflict resolution modal — shows detected conflicts and lets user send them to the calendar sandbox."""

sv import from main { AIOptimizeSchedule }
import from "lucide-react" { AlertTriangle, X, Zap }

def:pub ConflictResolutionModal(
    conflictInfo: dict,
    conflictingTaskIds: list,
    onClose: any,
    onResolved: any
) -> any {
    has aiLoading: bool = False;

    tasksAffected = conflictInfo["tasks_affected"] if conflictInfo["tasks_affected"] else 0;

    async def runAI -> None {
        aiLoading = True;
        if len(conflictingTaskIds) == 0 { aiLoading = False; return; }
        result = root spawn AIOptimizeSchedule(conflicting_task_ids=conflictingTaskIds, optimize_only_ids=conflictingTaskIds);
        aiLoading = False;
        if result.reports and result.reports[0] {
            onResolved(result.reports[0]);
        }
    }

    return
        <div className="crm-overlay" onClick={lambda e: any -> None { e.stopPropagation(); }}>
            <div className="crm-panel">
                <div className="crm-header">
                    <div className="crm-header-left">
                        <AlertTriangle size={16} className="crm-header-icon" />
                        <span className="crm-title">Schedule Conflict</span>
                    </div>
                    <button className="crm-close" onClick={onClose}><X size={16} /></button>
                </div>

                <div className="crm-body">
                    <p className="crm-summary">
                        {str(tasksAffected) + " task" + ("s have" if tasksAffected != 1 else " has") + " overlapping scheduled times (including estimated overrun)."}
                    </p>

                    {(
                        <ul className="crm-conflict-list">
                            {[
                                <li key={t["id"]} className="crm-conflict-task">
                                    <span className="crm-conflict-bullet"></span>
                                    <div className="crm-conflict-task-info">
                                        <span className="crm-conflict-task-title">{t["title"]}</span>
                                        <span className="crm-conflict-task-time">{t["start_date"] + "  ·  " + t["start_time"] + " – " + t["end_time"]}</span>
                                    </div>
                                </li>
                                for t in (conflictInfo["conflicting_tasks"] if conflictInfo["conflicting_tasks"] else [])
                            ]}
                        </ul>
                    ) if conflictInfo["conflicting_tasks"] and len(conflictInfo["conflicting_tasks"]) > 0 else None}

                    {(
                        <div className="crm-loading">
                            <span className="crm-spinner"></span>
                            AI is finding the best reschedule...
                        </div>
                    ) if aiLoading else None}
                </div>

                <div className="crm-footer">
                    <button className="crm-btn-cancel" onClick={onClose}>Dismiss</button>
                    <button className="crm-btn-ai" onClick={lambda -> None { runAI(); }} disabled={aiLoading}>
                        <Zap size={14} />
                        {("AI is thinking..." if aiLoading else "Optimize These Tasks")}
                    </button>
                </div>
            </div>
        </div>;
}

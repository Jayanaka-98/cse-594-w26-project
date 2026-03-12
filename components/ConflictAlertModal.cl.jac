"""Scheduling conflict alert modal — shown when scheduled tasks have time overlaps."""

import from "lucide-react" { AlertTriangle, X, Zap }

def:pub ConflictAlertModal(
    conflictInfo: dict,
    onIgnore: any,
    onViewPlan: any
) -> any {
    tasksAffected = conflictInfo.tasks_affected if conflictInfo.tasks_affected else 0;
    adjustMins = conflictInfo.total_adjustment_minutes if conflictInfo.total_adjustment_minutes else 0;

    return
        <div className="conflict-overlay" onClick={lambda e: any -> None { e.stopPropagation(); }}>
            <div className="conflict-modal">

                <div className="conflict-icon-wrap">
                    <div className="conflict-icon-bg">
                        <AlertTriangle size={28} className="conflict-icon" />
                    </div>
                </div>

                <h2 className="conflict-title">Scheduling Conflict Detected</h2>
                <p className="conflict-body">
                    {"Your current schedule has " + tasksAffected.toString() + " overlapping task" + ("s" if tasksAffected != 1 else "") + ". AI has generated an alternative schedule based on your past task completion patterns."}
                </p>

                <div className="conflict-stats">
                    <div className="conflict-stat-row">
                        <span className="conflict-stat-label">Tasks affected:</span>
                        <span className="conflict-stat-val">{tasksAffected}</span>
                    </div>
                    <div className="conflict-stat-row">
                        <span className="conflict-stat-label">Estimated schedule adjustment:</span>
                        <span className="conflict-stat-val conflict-stat-orange">{("+" + adjustMins.toString() + " minutes")}</span>
                    </div>
                </div>

                <div className="conflict-actions">
                    <button className="conflict-btn-ignore" onClick={onIgnore}>
                        Ignore
                    </button>
                    <button className="conflict-btn-plan" onClick={onViewPlan}>
                        <Zap size={14} /> View AI Plan
                    </button>
                </div>

            </div>
        </div>;
}

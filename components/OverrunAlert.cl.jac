"""Schedule disruption modal — shown when active task exceeds estimated duration."""

sv import from main { ApplyReplanChanges }
import from "lucide-react" { AlertTriangle }

def:pub OverrunAlert(
    alert: any,
    onAccept: any,
    onIgnore: any,
    onViewSchedule: any
) -> any {

    def formatTime(t: str) -> str {
        if not t or t == "" { return t; }
        parts = t.split(":");
        if len(parts) < 2 { return t; }
        h = parseInt(parts[0]);
        suffix = "AM" if h < 12 else "PM";
        dh = h if h <= 12 else h - 12;
        if h == 0 { dh = 12; }
        return dh.toString() + ":" + parts[1] + " " + suffix;
    }

    overMins = alert.elapsed_minutes - alert.estimated_minutes;

    return
        <div className="overrun-overlay" onClick={lambda e: any -> None { e.stopPropagation(); }}>
            <div className="overrun-modal">

                <div className="overrun-header">
                    <AlertTriangle size={20} className="overrun-icon" />
                    <div>
                        <div className="overrun-title">Schedule Update</div>
                        <div className="overrun-subtitle">{alert.headline}</div>
                    </div>
                </div>

                <div className="overrun-task-card">
                    <div className="overrun-task-name">{alert.running_task_title}</div>
                    <div className="overrun-time-row">
                        <div className="overrun-time-item">
                            <span className="overrun-time-label">Estimated:</span>
                            <span className="overrun-time-val">{alert.estimated_minutes.toString() + "h" if alert.estimated_minutes >= 60 else alert.estimated_minutes.toString() + " min"}</span>
                        </div>
                        <div className="overrun-time-item">
                            <span className="overrun-time-label">Current:</span>
                            <span className="overrun-time-val overrun-time-over">
                                {alert.elapsed_minutes.toString() + " min"}
                                <span className="overrun-over-delta">{" (+" + overMins.toString() + "m)"}</span>
                            </span>
                        </div>
                    </div>
                </div>

                {(
                    <div className="overrun-affected-card">
                        <div className="overrun-affected-badge">NEXT TASK AFFECTED</div>
                        <div className="overrun-affected-name">{alert.affected_task_title}</div>
                    </div>
                ) if alert.affected_task_title and alert.affected_task_title != "" else None}

                {(
                    <div className="overrun-observation">
                        <span className="overrun-obs-label">OBSERVATION:</span>
                        <p className="overrun-obs-text">{alert.observation}</p>
                    </div>
                ) if alert.observation and alert.observation != "" else None}

                {(
                    <div className="overrun-change-card">
                        <span className="overrun-change-label">Changes Proposed:</span>
                        <p className="overrun-change-text">
                            {"Move \"" + alert.affected_task_title + "\" to " + alert.proposed_new_time}
                        </p>
                    </div>
                ) if alert.proposed_new_time and alert.proposed_new_time != "" else None}

                <div className="overrun-actions">
                    <button
                        className="overrun-btn-view"
                        onClick={lambda -> None { onViewSchedule(); onIgnore(); }}
                    >
                        View Full Schedule
                    </button>
                    <div className="overrun-primary-actions">
                        {(
                            <button
                                className="overrun-btn-accept"
                                onClick={lambda -> None { onAccept(alert); }}
                            >
                                Accept Change
                            </button>
                        ) if alert.proposed_new_time and alert.proposed_new_time != "" else None}
                        <button
                            className="overrun-btn-ignore"
                            onClick={lambda -> None { onIgnore(); }}
                        >
                            Ignore
                        </button>
                    </div>
                </div>

            </div>
        </div>;
}

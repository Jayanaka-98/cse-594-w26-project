"""Task card component for list and board views."""

 

def:pub TaskCard(
    task: dict,
    onOpenDetail: any,
    onStatusChange: any,
    onDelete: any
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
                            ×
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
                        
                    </div>
                </div>
            </div>
        </div>;
}

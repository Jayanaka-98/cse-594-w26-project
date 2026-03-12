"""Task detail panel - right side panel showing full task details."""

import from "lucide-react" { X, Trash2 }

def:pub TaskDetailPanel(
    task: dict,
    comments: list,
    editTitle: str,
    editDescription: str,
    editStatus: str,
    editPriority: str,
    editStartDate: str,
    editStartTime: str,
    editEndTime: str,
    commentText: str,
    allTasks: list,
    onClose: any,
    onSave: any,
    onDelete: any,
    onEditTitleChange: any,
    onEditDescriptionChange: any,
    onEditStatusChange: any,
    onEditPriorityChange: any,
    onEditStartDateChange: any,
    onEditStartTimeChange: any,
    onEditEndTimeChange: any,
    onCommentTextChange: any,
    onAddComment: any,
    onDeleteComment: any,
    onAddSubtask: any
) -> any {
    subtasks = allTasks.filter(
        lambda t: any -> bool { return t.parent_task_id == task.id; }
    );

    priorityClass = (
        "priority-urgent" if editPriority == "urgent"
        else ("priority-high" if editPriority == "high"
        else ("priority-normal" if editPriority == "normal"
        else "priority-low"))
    );
    statusClass = (
        "status-todo" if editStatus == "todo"
        else ("status-in-progress" if editStatus == "in_progress"
        else ("status-review" if editStatus == "review"
        else "status-done"))
    );

    return
        <div className="detail-panel">
            <div className="detail-panel-header">
                <h3 className="detail-panel-task-id">Task</h3>
                <div className="detail-panel-actions">
                    <button onClick={onDelete} className="btn-danger-sm" title="Delete task">
                        <Trash2 size={14} />
                    </button>
                    <button onClick={onClose} className="btn-close" title="Close">
                        <X size={16} />
                    </button>
                </div>
            </div>
            <div className="detail-panel-body">
                <div className="detail-section">
                    <input
                        type="text"
                        value={editTitle}
                        onChange={onEditTitleChange}
                        className="detail-title-input"
                        placeholder="Task title"
                    />
                </div>
                <div className="detail-section detail-meta">
                    <div className="detail-meta-row">
                        <span className="detail-meta-label">Status</span>
                        <select
                            value={editStatus}
                            onChange={lambda e: any -> None { onEditStatusChange(e.target.value); }}
                            className={"detail-select " + statusClass}
                        >
                            <option value="todo">Todo</option>
                            <option value="in_progress">In Progress</option>
                            <option value="review">Review</option>
                            <option value="done">Done</option>
                        </select>
                    </div>
                    <div className="detail-meta-row">
                        <span className="detail-meta-label">Priority</span>
                        <select
                            value={editPriority}
                            onChange={lambda e: any -> None { onEditPriorityChange(e.target.value); }}
                            className={"detail-select " + priorityClass}
                        >
                            <option value="urgent">Urgent</option>
                            <option value="high">High</option>
                            <option value="normal">Normal</option>
                            <option value="low">Low</option>
                        </select>
                    </div>
                    <div className="detail-meta-row detail-schedule-row">
                        <span className="detail-meta-label">Schedule</span>
                        <div className="detail-schedule-inputs">
                            <input
                                type="date"
                                value={editStartDate}
                                onChange={onEditStartDateChange}
                                className="detail-schedule-input"
                                title="Start date"
                            />
                            <input
                                type="time"
                                value={editStartTime}
                                onChange={onEditStartTimeChange}
                                className="detail-schedule-input"
                                title="Start time"
                            />
                            <span className="detail-schedule-sep">to</span>
                            <input
                                type="time"
                                value={editEndTime}
                                onChange={onEditEndTimeChange}
                                className="detail-schedule-input"
                                title="End time"
                            />
                        </div>
                    </div>
                </div>
                <div className="detail-section">
                    <label className="detail-section-label">Description</label>
                    <textarea
                        value={editDescription}
                        onChange={onEditDescriptionChange}
                        placeholder="Add a description..."
                        className="detail-textarea"
                        rows={4}
                    />
                </div>
                <div className="detail-save-row">
                    <button onClick={onSave} className="btn-primary btn-sm">
                        Save Changes
                    </button>
                </div>
                <div className="detail-section">
                    <div className="detail-section-header">
                        <label className="detail-section-label">
                            Subtasks ({subtasks.length})
                        </label>
                    </div>
                    {(
                        <div className="subtasks-list">
                            {[
                                <SubtaskRow
                                    key={st.id}
                                    subtask={st}
                                /> for st in subtasks
                            ]}
                        </div>
                    ) if subtasks.length > 0 else None}
                    <AddSubtaskRow onAdd={onAddSubtask} />
                </div>
                <div className="detail-section">
                    <label className="detail-section-label">
                        Comments ({comments.length})
                    </label>
                    <div className="comments-list">
                        {[
                            <CommentRow
                                key={comment.id}
                                comment={comment}
                                onDelete={onDeleteComment}
                            /> for comment in comments
                        ]}
                    </div>
                    <div className="comment-input-row">
                        <textarea
                            value={commentText}
                            onChange={onCommentTextChange}
                            placeholder="Write a comment..."
                            className="comment-textarea"
                            rows={2}
                        />
                        <button
                            onClick={onAddComment}
                            className="btn-primary btn-sm"
                            disabled={commentText.trim() == ""}
                        >
                            Add
                        </button>
                    </div>
                </div>
            </div>
        </div>;
}

def:pub SubtaskRow(subtask: dict) -> any {
    statusClass = (
        "status-done" if subtask.status == "done"
        else "status-todo"
    );

    return
        <div className="subtask-row">
            <span className={"subtask-dot " + statusClass}></span>
            <span className={"subtask-title" + (" subtask-done" if subtask.status == "done" else "")}>
                {subtask.title}
            </span>
            <span className={"subtask-status " + statusClass}>
                {subtask.status}
            </span>
        </div>;
}

def:pub AddSubtaskRow(onAdd: any) -> any {
    has subtaskTitle: str = "",
        showInput: bool = False;

    def handleAdd -> None {
        if subtaskTitle.trim() == "" { return; }
        onAdd(subtaskTitle);
        subtaskTitle = "";
        showInput = False;
    }

    return
        <div className="add-subtask-row">
            {(
                <div className="subtask-input-row">
                    <input
                        type="text"
                        value={subtaskTitle}
                        onChange={lambda e: any -> None { subtaskTitle = e.target.value; }}
                        placeholder="Subtask title"
                        className="subtask-input"
                        autoFocus={True}
                        onKeyPress={lambda e: any -> None { if e.key == "Enter" { handleAdd(); } }}
                    />
                    <button onClick={lambda -> None { handleAdd(); }} className="btn-primary btn-xs">Add</button>
                    <button onClick={lambda -> None { showInput = False; subtaskTitle = ""; }} className="btn-secondary btn-xs">Cancel</button>
                </div>
            ) if showInput else (
                <button
                    onClick={lambda -> None { showInput = True; }}
                    className="btn-text"
                >
                    + Add subtask
                </button>
            )}
        </div>;
}

def:pub CommentRow(comment: dict, onDelete: any) -> any {
    return
        <div className="comment-row">
            <div className="comment-bubble">
                <p className="comment-content">{comment.content}</p>
            </div>
            <button
                onClick={lambda -> None { onDelete(comment.id); }}
                className="comment-delete-btn"
                title="Delete comment"
            >
                <X size={13} />
            </button>
        </div>;
}


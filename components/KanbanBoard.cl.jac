"""Kanban board component with status columns."""

import from .TaskCard { TaskCard }

def:pub KanbanBoard(
    tasks: list,
    onOpenDetail: any,
    onStatusChange: any,
    onDelete: any,
    activeTasks: list = [],
    timerTick: int = 0,
    onStartTimer: any = None,
    onPauseTimer: any = None,
    onResumeTimer: any = None,
    onFinishTimer: any = None
) -> any {
    todoTasks = tasks.filter(lambda t: any -> bool { return t.status == "todo"; });
    inProgressTasks = tasks.filter(lambda t: any -> bool { return t.status == "in_progress"; });
    reviewTasks = tasks.filter(lambda t: any -> bool { return t.status == "review"; });
    doneTasks = tasks.filter(lambda t: any -> bool { return t.status == "done"; });

    return
        <div className="kanban-board">
            <KanbanColumn
                title="Todo"
                count={len(todoTasks)}
                colorClass="col-todo"
                tasks={todoTasks}
                activeTasks={activeTasks}
                timerTick={timerTick}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
                onStartTimer={onStartTimer}
                onPauseTimer={onPauseTimer}
                onResumeTimer={onResumeTimer}
                onFinishTimer={onFinishTimer}
            />
            <KanbanColumn
                title="In Progress"
                count={len(inProgressTasks)}
                colorClass="col-in-progress"
                tasks={inProgressTasks}
                activeTasks={activeTasks}
                timerTick={timerTick}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
                onStartTimer={onStartTimer}
                onPauseTimer={onPauseTimer}
                onResumeTimer={onResumeTimer}
                onFinishTimer={onFinishTimer}
            />
            <KanbanColumn
                title="Review"
                count={len(reviewTasks)}
                colorClass="col-review"
                tasks={reviewTasks}
                activeTasks={activeTasks}
                timerTick={timerTick}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
                onStartTimer={onStartTimer}
                onPauseTimer={onPauseTimer}
                onResumeTimer={onResumeTimer}
                onFinishTimer={onFinishTimer}
            />
            <KanbanColumn
                title="Done"
                count={len(doneTasks)}
                colorClass="col-done"
                tasks={doneTasks}
                activeTasks={activeTasks}
                timerTick={timerTick}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
                onStartTimer={onStartTimer}
                onPauseTimer={onPauseTimer}
                onResumeTimer={onResumeTimer}
                onFinishTimer={onFinishTimer}
            />
        </div>;
}

def:pub KanbanColumn(
    title: str,
    count: int,
    colorClass: str,
    tasks: list,
    onOpenDetail: any,
    onStatusChange: any,
    onDelete: any,
    activeTasks: list = [],
    timerTick: int = 0,
    onStartTimer: any = None,
    onPauseTimer: any = None,
    onResumeTimer: any = None,
    onFinishTimer: any = None
) -> any {
    def getActiveTask(taskId: str) -> dict {
        matches = activeTasks.filter(lambda a: any -> bool { return a.active_task_id == taskId; });
        if len(matches) > 0 { return matches[0]; }
        return {};
    }

    return
        <div className="kanban-column">
            <div className={"kanban-col-header " + colorClass}>
                <span className="kanban-col-title">{title}</span>
                <span className="kanban-col-count">{count}</span>
            </div>
            <div className="kanban-col-tasks">
                {(
                    <div className="kanban-empty">
                        No tasks
                    </div>
                ) if len(tasks) == 0 else (
                    <div>
                        {[
                            <TaskCard
                                key={task.id}
                                task={task}
                                activeTask={getActiveTask(task.id)}
                                timerTick={timerTick}
                                onOpenDetail={onOpenDetail}
                                onStatusChange={onStatusChange}
                                onDelete={onDelete}
                                onStartTimer={onStartTimer}
                                onPauseTimer={onPauseTimer}
                                onResumeTimer={onResumeTimer}
                                onFinishTimer={onFinishTimer}
                            /> for task in tasks
                        ]}
                    </div>
                )}
            </div>
        </div>;
}

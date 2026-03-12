"""Kanban board component with status columns."""

import from .TaskCard { TaskCard }

def:pub KanbanBoard(
    tasks: list,
    onOpenDetail: any,
    onStatusChange: any,
    onDelete: any
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
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
            />
            <KanbanColumn
                title="In Progress"
                count={len(inProgressTasks)}
                colorClass="col-in-progress"
                tasks={inProgressTasks}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
            />
            <KanbanColumn
                title="Review"
                count={len(reviewTasks)}
                colorClass="col-review"
                tasks={reviewTasks}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
            />
            <KanbanColumn
                title="Done"
                count={len(doneTasks)}
                colorClass="col-done"
                tasks={doneTasks}
                onOpenDetail={onOpenDetail}
                onStatusChange={onStatusChange}
                onDelete={onDelete}
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
    onDelete: any
) -> any {
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
                                onOpenDetail={onOpenDetail}
                                onStatusChange={onStatusChange}
                                onDelete={onDelete}
                            /> for task in tasks
                        ]}
                    </div>
                )}
            </div>
        </div>;
}

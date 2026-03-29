"""Sidebar navigation component for FlowBoard."""

import from "lucide-react" { List, X }

def:pub Sidebar(
    lists: list,
    tasks: list,
    selectedListId: str,
    listsLoading: bool,
    onSelectList: any,
    onCreateList: any,
    onDeleteList: any
) -> any {
    return
        <div className="sidebar">
            <div className="sidebar-section">
                <div className="sidebar-section-header">
                    <span className="sidebar-section-title">LISTS</span>
                    <button
                        onClick={onCreateList}
                        className="sidebar-add-btn"
                        title="Create List"
                    >
                        +
                    </button>
                </div>
                {(
                    <div className="sidebar-loading">Loading...</div>
                ) if listsLoading else (
                    <div className="spaces-list">
                        {(
                            <div className="sidebar-empty">
                                No lists yet
                            </div>
                        ) if len(lists) == 0 else (
                            <div>
                                {[
                                    <ListItem
                                        key={lst.id}
                                        lst={lst}
                                        tasks={tasks}
                                        selectedListId={selectedListId}
                                        onSelectList={onSelectList}
                                        onDeleteList={onDeleteList}
                                    /> for lst in lists
                                ]}
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>;
}

def:pub ListItem(
    lst: dict,
    tasks: list,
    selectedListId: str,
    onSelectList: any,
    onDeleteList: any
) -> any {
    listClass = (
        "list-row list-row-selected"
        if lst.id == selectedListId
        else "list-row"
    );
    taskCount = len(tasks.filter(lambda t: any -> bool { return t.list_id == lst.id and t.parent_task_id == ""; }));

    return
        <div className={listClass}>
            <button
                className="list-row-main"
                onClick={lambda -> None { onSelectList(lst.id); }}
            >
                <List size={14} className="list-icon" />
                <span className="list-name">{lst.name}</span>
                <span className="task-count">{taskCount}</span>
            </button>
            <button
                onClick={lambda -> None { onDeleteList(lst.id); }}
                className="sidebar-delete-btn"
                title="Delete list"
            >
                <X size={14} />
            </button>
        </div>;
}

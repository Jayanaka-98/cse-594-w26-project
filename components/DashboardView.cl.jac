"""Central task dashboard across all spaces and lists."""

sv import from main { ListTasks, ListSpaces, ListLists }

def:pub DashboardView(onOpenDetail: any) -> any {
    has tasks: list = [],
        spaces: list = [],
        lists: list = [],
        filterStatus: str = "",
        filterPriority: str = "",
        searchText: str = "",
        loading: bool = True;

    can with entry {
        fetchAll();
    }

    async def fetchAll -> None {
        loading = True;
        rT = root spawn ListTasks(list_id="");
        rS = root spawn ListSpaces();
        rL = root spawn ListLists(space_id="");
        tasks = rT.reports[0] if rT.reports else [];
        spaces = rS.reports[0] if rS.reports else [];
        lists = rL.reports[0] if rL.reports else [];
        loading = False;
    }

    def getFilteredTasks -> list {
        filtered = tasks.filter(lambda t: any -> bool { return t.parent_task_id == ""; });
        if filterStatus != "" {
            filtered = filtered.filter(lambda t: any -> bool { return t.status == filterStatus; });
        }
        if filterPriority != "" {
            filtered = filtered.filter(lambda t: any -> bool { return t.priority == filterPriority; });
        }
        if searchText.trim() != "" {
            q = searchText.toLowerCase();
            filtered = filtered.filter(lambda t: any -> bool { return t.title.toLowerCase().includes(q); });
        }
        return filtered;
    }

    def getListsForSpace(spaceId: str) -> list {
        return lists.filter(lambda l: any -> bool { return l.space_id == spaceId; });
    }

    def getTasksForList(listId: str, ft: list) -> list {
        return ft.filter(lambda t: any -> bool { return t.list_id == listId; });
    }

    def spaceHasTasks(spaceId: str, ft: list) -> bool {
        sl = getListsForSpace(spaceId);
        ids = sl.map(lambda l: any -> str { return l.id; });
        return ft.filter(lambda t: any -> bool { return ids.includes(t.list_id); }).length > 0;
    }

    def spaceTaskCount(spaceId: str, ft: list) -> int {
        sl = getListsForSpace(spaceId);
        ids = sl.map(lambda l: any -> str { return l.id; });
        return ft.filter(lambda t: any -> bool { return ids.includes(t.list_id); }).length;
    }

    def countByStatus(s: str) -> int {
        return tasks.filter(lambda t: any -> bool { return t.parent_task_id == "" and t.status == s; }).length;
    }

    def priClass(p: str) -> str {
        if p == "urgent" { return "dash-pri-urgent"; }
        if p == "high" { return "dash-pri-high"; }
        if p == "normal" { return "dash-pri-normal"; }
        return "dash-pri-low";
    }

    def stClass(s: str) -> str {
        if s == "todo" { return "dash-st-todo"; }
        if s == "in_progress" { return "dash-st-progress"; }
        if s == "review" { return "dash-st-review"; }
        return "dash-st-done";
    }

    def stLabel(s: str) -> str {
        if s == "todo" { return "Todo"; }
        if s == "in_progress" { return "In Progress"; }
        if s == "review" { return "Review"; }
        return "Done";
    }

    totalRoot = tasks.filter(lambda t: any -> bool { return t.parent_task_id == ""; }).length;
    ft = getFilteredTasks();

    return
        <div className="dashboard-view">
            <div className="dash-header">
                <h2 className="dash-title">All Tasks</h2>
                <button
                    onClick={lambda -> None { fetchAll(); }}
                    className="btn-secondary btn-sm"
                    title="Refresh dashboard"
                >
                    ↻ Refresh
                </button>
            </div>

            {(
                <div className="dash-loading">
                    <div className="loading-spinner"></div>
                    Loading...
                </div>
            ) if loading else (
                <div>
                    <div className="dash-stats">
                        <div
                            className={"dash-stat" + (" dash-stat-active" if filterStatus == "" else "")}
                            onClick={lambda -> None { filterStatus = ""; }}
                            title="Show all"
                        >
                            <span className="dash-stat-n">{totalRoot}</span>
                            <span className="dash-stat-lbl">All</span>
                        </div>
                        <div
                            className={"dash-stat dash-stat-todo" + (" dash-stat-active" if filterStatus == "todo" else "")}
                            onClick={lambda -> None { filterStatus = ("" if filterStatus == "todo" else "todo"); }}
                        >
                            <span className="dash-stat-n">{countByStatus("todo")}</span>
                            <span className="dash-stat-lbl">Todo</span>
                        </div>
                        <div
                            className={"dash-stat dash-stat-prog" + (" dash-stat-active" if filterStatus == "in_progress" else "")}
                            onClick={lambda -> None { filterStatus = ("" if filterStatus == "in_progress" else "in_progress"); }}
                        >
                            <span className="dash-stat-n">{countByStatus("in_progress")}</span>
                            <span className="dash-stat-lbl">In Progress</span>
                        </div>
                        <div
                            className={"dash-stat dash-stat-review" + (" dash-stat-active" if filterStatus == "review" else "")}
                            onClick={lambda -> None { filterStatus = ("" if filterStatus == "review" else "review"); }}
                        >
                            <span className="dash-stat-n">{countByStatus("review")}</span>
                            <span className="dash-stat-lbl">Review</span>
                        </div>
                        <div
                            className={"dash-stat dash-stat-done" + (" dash-stat-active" if filterStatus == "done" else "")}
                            onClick={lambda -> None { filterStatus = ("" if filterStatus == "done" else "done"); }}
                        >
                            <span className="dash-stat-n">{countByStatus("done")}</span>
                            <span className="dash-stat-lbl">Done</span>
                        </div>
                    </div>

                    <div className="dash-filters">
                        <input
                            type="text"
                            value={searchText}
                            onChange={lambda e: any -> None { searchText = e.target.value; }}
                            placeholder="Search tasks..."
                            className="dash-search"
                        />
                        <select
                            value={filterPriority}
                            onChange={lambda e: any -> None { filterPriority = e.target.value; }}
                            className="form-select dash-filter-sel"
                        >
                            <option value="">All priorities</option>
                            <option value="urgent">Urgent</option>
                            <option value="high">High</option>
                            <option value="normal">Normal</option>
                            <option value="low">Low</option>
                        </select>
                    </div>

                    {(
                        <p className="dash-empty">No tasks match your filters.</p>
                    ) if ft.length == 0 else (
                        <div className="dash-spaces">
                            {[
                                <div key={sp.id} className="dash-space-group">
                                    <div className={"dash-space-hdr dash-sp-" + sp.color}>
                                        <span className="dash-space-dot"></span>
                                        <span className="dash-space-name">{sp.name}</span>
                                        <span className="dash-space-cnt">{spaceTaskCount(sp.id, ft)}</span>
                                    </div>
                                    {[
                                        <div key={lst.id} className="dash-list-group">
                                            <div className="dash-list-hdr">
                                                <span className="dash-list-name">{lst.name}</span>
                                                <span className="dash-list-cnt">{getTasksForList(lst.id, ft).length}</span>
                                            </div>
                                            <div className="dash-task-rows">
                                                {[
                                                    <div
                                                        key={task.id}
                                                        className="dash-task-row"
                                                        onClick={lambda -> None { onOpenDetail(task); }}
                                                    >
                                                        <span className={"dash-pri-dot " + priClass(task.priority)} title={task.priority}></span>
                                                        <span className="dash-task-title">{task.title}</span>
                                                        <span className={"dash-task-st " + stClass(task.status)}>
                                                            {stLabel(task.status)}
                                                        </span>
                                                        {(
                                                            <span className="dash-task-due">{task.due_date}</span>
                                                        ) if task.due_date and task.due_date != "" else None}
                                                    </div>
                                                    for task in getTasksForList(lst.id, ft)
                                                ]}
                                            </div>
                                        </div>
                                        for lst in getListsForSpace(sp.id)
                                        if getTasksForList(lst.id, ft).length > 0
                                    ]}
                                </div>
                                for sp in spaces
                                if spaceHasTasks(sp.id, ft)
                            ]}
                        </div>
                    )}
                </div>
            )}
        </div>;
}

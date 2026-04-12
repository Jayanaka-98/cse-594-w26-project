"""FlowBoard - ClickUp-style Project Management Frontend."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
import from "lucide-react" { Moon, Sun, List, LayoutGrid, Calendar, BarChart2, TrendingUp, X, AlertTriangle, GitMerge, ChevronLeft, ChevronRight }

import "./styles.css";

import from .components.AuthForm { AuthForm }
import from .components.TaskCard { TaskCard }
import from .components.KanbanBoard { KanbanBoard }
import from .components.TaskModal { TaskModal }
import from .components.TaskDetailPanel { TaskDetailPanel }
import from .components.ProfilePanel { ProfilePanel }
import from .components.CalendarView { CalendarView }
import from .components.GlobalTaskModal { GlobalTaskModal }
import from .components.DashboardView { DashboardView }
import from .components.AnalyticsView { AnalyticsView }

import from .components.ModifyScheduleView { ModifyScheduleView }
import from .components.ChatPanel { ChatPanel }
import from .components.ConflictResolutionModal { ConflictResolutionModal }
import from .components.NowWorkingOn { NowWorkingOn }

sv import from main {
    CreateList, ListLists, DeleteList,
    CreateTask, ListTasks, UpdateTask, DeleteTask,
    AddComment, ListComments, DeleteComment,
    GetUserProfile, UpdateUserProfile,
    SeedDemoData, ListTaskHistory,
    GetUserPatterns, UpdateUserPatterns,
    AIOptimizeSchedule, ApplyReplanChanges
}

def:pub app -> any {
    has isLoggedIn: bool = False,
        checkingAuth: bool = True,
        isSignup: bool = False,
        username: str = "",
        password: str = "",
        authError: str = "",
        authLoading: bool = False,

        # Theme & profile
        darkMode: bool = True,
        showProfile: bool = False,
        loggedInUsername: str = "",
        profileDisplayName: str = "",
        profileDefaultView: str = "list",

        # Data
        lists: list = [],
        tasks: list = [],
        comments: list = [],

        # Navigation
        selectedListId: str = "",
        view: str = "list",

        # Task detail panel state
        selectedTask: dict = {},
        showTaskDetail: bool = False,
        editTitle: str = "",
        editDescription: str = "",
        editStatus: str = "",
        editPriority: str = "",
        editStartDate: str = "",
        editStartTime: str = "",
        editEndTime: str = "",
        commentText: str = "",

        # Create task modal
        showCreateTask: bool = False,
        showGlobalCreateTask: bool = False,

        # Create list modal
        showCreateList: bool = False,

        # Loading
        listsLoading: bool = True,
        tasksLoading: bool = False,

        # Conflict detection
        conflictsActive: bool = False,
        conflictInfo: dict = {},
        showConflictResolution: bool = False,
        conflictReplan: any = None,

        taskToStart: dict = {},
        leftPanelOpen: bool = True,
        overrunRatios: dict = {},
        aiPlan: any = None,
        aiPlanLoading: bool = False,
        explanationCache: dict = {},
        calendarRefreshKey: int = 0,
        calendarEvalBump: int = 0;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
        saved = localStorage.getItem("flowboard_view");
        if saved and saved != "" { view = saved; }
    }

    can with [view] entry {
        localStorage.setItem("flowboard_view", view);
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchProfile();
            fetchLists();
            fetchTasks();
        }
    }

    # Method declarations (implementations in frontend.impl.jac)
    async def fetchLists -> None;
    async def fetchTasks -> None;
    async def fetchProfile -> None;
    async def saveProfile(displayName: str, theme: str, defaultView: str) -> None;
    async def toggleTheme -> None;
    def openProfile -> None;
    def closeProfile -> None;
    async def createList(name: str) -> None;
    async def createTask(title: str, description: str, status: str, priority: str, dueDate: str, parentTaskId: str, startDate: str, startTime: str, endTime: str, category: str, estimatedDuration: int) -> None;
    async def updateTask(taskId: str, title: str, description: str, status: str, priority: str, dueDate: str, startDate: str, startTime: str, endTime: str) -> None;
    async def updateTaskStatus(taskId: str, status: str) -> None;
    async def deleteTask(taskId: str) -> None;
    async def deleteList(listId: str) -> None;
    async def fetchComments(taskId: str) -> None;
    async def addComment(taskId: str, content: str) -> None;
    async def deleteComment(commentId: str) -> None;
    async def handleLogin -> None;
    async def handleSignup -> None;
    def handleLogout -> None;
    async def handleAuthSubmit(e: any) -> None;
    async def openTask(task: dict) -> None;
    def closeTask -> None;
    def getSelectedList -> dict;
    async def saveTaskChanges -> None;

    def computeConflicts(taskList: any, ratios: any) -> dict {
        defaultRatios = {"Coding": 1.42, "Research": 1.35, "Writing": 1.22, "Meeting": 1.08, "Admin": 1.05};
        scheduled = taskList.filter(lambda t: any -> bool {
            return t.start_date != "" and t.start_time != "" and t.status != "done";
        });
        conflictingIds = [];
        totalOverlapMins = 0;
        scheduled.forEach(lambda a: any -> None {
            scheduled.forEach(lambda b: any -> None {
                if a.id == b.id { return; }
                if a.start_date != b.start_date { return; }
                aStart = parseInt(a.start_time.split(":")[0]) * 60 + parseInt(a.start_time.split(":")[1]);
                aDur = a.estimated_duration if a.estimated_duration else 60;
                aRatio = ratios[a.category] if (a.category and ratios[a.category]) else (defaultRatios[a.category] if (a.category and defaultRatios[a.category]) else 1.1);
                aEnd = aStart + Math.ceil(aDur * aRatio);
                bStart = parseInt(b.start_time.split(":")[0]) * 60 + parseInt(b.start_time.split(":")[1]);
                bDur = b.estimated_duration if b.estimated_duration else 60;
                bRatio = ratios[b.category] if (b.category and ratios[b.category]) else (defaultRatios[b.category] if (b.category and defaultRatios[b.category]) else 1.1);
                bEnd = bStart + Math.ceil(bDur * bRatio);
                if aStart < bEnd and bStart < aEnd {
                    if not conflictingIds.includes(a.id) { conflictingIds.push(a.id); }
                    totalOverlapMins += Math.min(aEnd, bEnd) - Math.max(aStart, bStart);
                }
            });
        });
        conflictingTasks = scheduled.filter(lambda t: any -> bool {
            return conflictingIds.includes(t.id);
        }).map(lambda t: any -> dict {
            return {"id": t.id, "title": t.title, "start_date": t.start_date, "start_time": t.start_time, "end_time": t.end_time};
        });
        return {
            "conflicting_ids": conflictingIds,
            "conflicting_tasks": conflictingTasks,
            "tasks_affected": len(conflictingIds),
            "total_adjustment_minutes": Math.round(totalOverlapMins / 2)
        };
    }

    themeClass = "app-root" + (" light" if not darkMode else "");

    if checkingAuth {
        return
            <div className={themeClass}>
                <div className="app-loading">
                    <div className="loading-spinner"></div>
                </div>
            </div>;
    }

    if not isLoggedIn {
        return
            <div className={themeClass}>
                <AuthForm
                    isSignup={isSignup}
                    username={username}
                    password={password}
                    error={authError}
                    loading={authLoading}
                    onUsernameChange={lambda e: any -> None { username = e.target.value; }}
                    onPasswordChange={lambda e: any -> None { password = e.target.value; }}
                    onSubmit={handleAuthSubmit}
                    onToggleMode={lambda -> None { isSignup = not isSignup; authError = ""; }}
                />
            </div>;
    }

    currentList = getSelectedList();
    avatarLabel = profileDisplayName if profileDisplayName != "" else loggedInUsername;
    avatarInitial = (avatarLabel[0].toUpperCase() if avatarLabel != "" else "?");

    return
        <div className={themeClass}>
            <div className="top-bar">
                <span className="top-bar-logo">⚡ FlowBoard</span>
                <button
                    onClick={lambda -> None { showGlobalCreateTask = True; }}
                    className="btn-primary btn-sm top-bar-new-task"
                    title="Create a new task"
                >
                    + New Task
                </button>
                <div className="top-bar-right">
                    <div
                        className="theme-toggle"
                        onClick={lambda -> None { toggleTheme(); }}
                        title={(
                            "Switch to light mode" if darkMode else "Switch to dark mode"
                        )}
                    >
                        <span className="theme-icon">
                            {(<Moon size={16} />) if darkMode else (<Sun size={16} />)}
                        </span>
                        <div className={"toggle-track" + (" on" if not darkMode else "")}>
                            <div className="toggle-thumb"></div>
                        </div>
                    </div>
                    <button
                        onClick={lambda -> None { openProfile(); }}
                        className="avatar-btn"
                        title={"Profile"}
                    >
                        {avatarInitial}
                    </button>
                    <button onClick={handleLogout} className="btn-signout">
                        Sign Out
                    </button>
                </div>
            </div>
            <div className="app-body">
                <div className={"left-panel" + (" left-panel-collapsed" if not leftPanelOpen else "")}>
                    <button
                        className="left-panel-toggle"
                        onClick={lambda -> None { leftPanelOpen = not leftPanelOpen; }}
                        title={("Collapse panel" if leftPanelOpen else "Expand panel")}
                    >
                        {(<ChevronLeft size={16} />) if leftPanelOpen else (<ChevronRight size={16} />)}
                    </button>
                    <div className="left-panel-content">
                        <NowWorkingOn
                            onTasksChanged={lambda -> None { fetchTasks(); calendarRefreshKey = calendarRefreshKey + 1; }}
                            taskToStart={taskToStart}
                        />
                    </div>
                </div>
                <div className="main-content">
                    <div className="view-tab-bar">
                        <button
                            onClick={lambda -> None { view = "list"; }}
                            className={("view-tab active" if view == "list" else "view-tab")}
                        >
                            <List size={14} /> List
                        </button>
                        <button
                            onClick={lambda -> None { view = "board"; }}
                            className={("view-tab active" if view == "board" else "view-tab")}
                        >
                            <LayoutGrid size={14} /> Board
                        </button>
                        <button
                            onClick={lambda -> None { view = "calendar"; }}
                            className={("view-tab active" if view == "calendar" else "view-tab")}
                        >
                            <Calendar size={14} /> Calendar
                        </button>
                        <button
                            onClick={lambda -> None { view = "dashboard"; }}
                            className={("view-tab active" if view == "dashboard" else "view-tab")}
                        >
                            <BarChart2 size={14} /> Dashboard
                        </button>
                        <button
                            onClick={lambda -> None { view = "analytics"; }}
                            className={("view-tab active" if view == "analytics" else "view-tab")}
                        >
                            <TrendingUp size={14} /> Analytics
                        </button>
                        <button
                            onClick={lambda -> None { view = "replanning"; }}
                            className={("view-tab active" if view == "replanning" else "view-tab")}
                        >
                            <GitMerge size={14} /> Replanning
                        </button>
                    </div>

                    {(
                        <ModifyScheduleView
                            tasks={tasks}
                            conflictInfo={conflictInfo}
                            aiPlan={aiPlan}
                            aiPlanLoading={aiPlanLoading}
                            onBack={lambda -> None { view = "calendar"; }}
                            onSaved={lambda -> None {
                                conflictsActive = False;
                                conflictInfo = {};
                                aiPlan = None;
                                fetchTasks();
                            }}
                        />
                    ) if view == "replanning" else (
                        <DashboardView onOpenDetail={openTask} />
                    ) if view == "dashboard" else (
                        <AnalyticsView tasks={tasks} />
                    ) if view == "analytics" else (
                        <CalendarView
                            onUpdateTask={updateTask}
                            onOpenDetail={openTask}
                            explanationCache={explanationCache}
                            refreshKey={calendarRefreshKey}
                            evalBumpKey={calendarEvalBump}
                            externalReplan={conflictReplan}
                        />
                    ) if view == "calendar" else (
                        (
                            <div className="empty-state">
                                <div className="empty-state-icon">⚡</div>
                                <h2 className="empty-state-title">Welcome to FlowBoard</h2>
                                <p className="empty-state-text">
                                    Create a List to organize your work, then add Tasks.
                                </p>
                                <button
                                    onClick={lambda -> None { showCreateList = True; }}
                                    className="btn-primary btn-lg"
                                >
                                    + Create List
                                </button>
                            </div>
                        ) if len(lists) == 0 else (
                            <div className="nested-view">
                                {(
                                    <div className="loading-tasks">
                                        <div className="loading-spinner"></div>
                                        Loading tasks...
                                    </div>
                                ) if tasksLoading else (
                                    <div>
                                        {[
                                            <div className="list-section" key={lst.id}>
                                                <div className="list-section-header">
                                                    <span className="list-section-title">{lst.name}</span>
                                                    <span className="task-count">
                                                        {len(tasks.filter(lambda t: any -> bool { return t.list_id == lst.id and t.parent_task_id == ""; }))} tasks
                                                    </span>
                                                    <button
                                                        onClick={lambda -> None { selectedListId = lst.id; showCreateTask = True; }}
                                                        className="btn-text btn-xs"
                                                    >
                                                        + New Task
                                                    </button>
                                                </div>
                                                {(
                                                    <div className="nested-board-wrap">
                                                        <KanbanBoard
                                                            tasks={tasks.filter(lambda t: any -> bool { return t.list_id == lst.id and t.parent_task_id == ""; })}
                                                            onOpenDetail={openTask}
                                                            onStatusChange={updateTaskStatus}
                                                            onDelete={deleteTask}
                                                        />
                                                    </div>
                                                ) if view == "board" else (
                                                    <div className="list-section-tasks">
                                                        {(
                                                            <div className="list-empty-tasks">No tasks yet.</div>
                                                        ) if len(tasks.filter(lambda t: any -> bool { return t.list_id == lst.id and t.parent_task_id == ""; })) == 0 else (
                                                            <div>
                                                                {[
                                                                    <TaskCard
                                                                        key={task.id}
                                                                        task={task}
                                                                        onOpenDetail={openTask}
                                                                        onStatusChange={updateTaskStatus}
                                                                        onDelete={deleteTask}
                                                                    /> for task in tasks if task.list_id == lst.id and task.parent_task_id == ""
                                                                ]}
                                                            </div>
                                                        )}
                                                    </div>
                                                )}
                                            </div>
                                            for lst in lists
                                        ]}
                                    </div>
                                )}
                            </div>
                        )
                    )}
                </div>
                {(
                    <TaskDetailPanel
                        task={selectedTask}
                        comments={comments}
                        editTitle={editTitle}
                        editDescription={editDescription}
                        editStatus={editStatus}
                        editPriority={editPriority}
                        commentText={commentText}
                        allTasks={tasks}
                        onClose={closeTask}
                        onSave={saveTaskChanges}
                        onDelete={lambda -> None { deleteTask(selectedTask.id); }}
                        onEditTitleChange={lambda e: any -> None { editTitle = e.target.value; }}
                        onEditDescriptionChange={lambda e: any -> None { editDescription = e.target.value; }}
                        onEditStatusChange={lambda v: str -> None { editStatus = v; }}
                        onEditPriorityChange={lambda v: str -> None { editPriority = v; }}
                        onCommentTextChange={lambda e: any -> None { commentText = e.target.value; }}
                        editStartDate={editStartDate}
                        editStartTime={editStartTime}
                        editEndTime={editEndTime}
                        onEditStartDateChange={lambda e: any -> None { editStartDate = e.target.value; }}
                        onEditStartTimeChange={lambda e: any -> None { editStartTime = e.target.value; }}
                        onEditEndTimeChange={lambda e: any -> None { editEndTime = e.target.value; }}
                        onAddComment={lambda -> None { addComment(selectedTask.id, commentText); commentText = ""; }}
                        onDeleteComment={deleteComment}
                        onAddSubtask={lambda title: str -> None { createTask(title, "", "todo", "normal", "", selectedTask.id, "", "", "", "", 0); }}
                        onStartTask={lambda t: dict -> None { taskToStart = t; }}
                    />
                ) if showTaskDetail else None}
            </div>
            {(
                <GlobalTaskModal
                    onClose={lambda -> None { showGlobalCreateTask = False; }}
                    onCreated={lambda -> None { fetchLists(); fetchTasks(); }}
                />
            ) if showGlobalCreateTask else None}
            {(
                <TaskModal
                    listId={selectedListId}
                    onClose={lambda -> None { showCreateTask = False; }}
                    onCreate={createTask}
                />
            ) if showCreateTask else None}
            {(
                <div className="modal-overlay" onClick={lambda -> None { showCreateList = False; }}>
                    <div className="modal-box" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                        <div className="modal-header">
                            <h3 className="modal-title">Create List</h3>
                            <button
                                onClick={lambda -> None { showCreateList = False; }}
                                className="btn-close"
                            >
                                <X size={16} />
                            </button>
                        </div>
                        <CreateListForm
                            onClose={lambda -> None { showCreateList = False; }}
                            onCreate={createList}
                        />
                    </div>
                </div>
            ) if showCreateList else None}
            {(
                <ProfilePanel
                    username={loggedInUsername}
                    displayName={profileDisplayName}
                    darkMode={darkMode}
                    defaultView={profileDefaultView}
                    onClose={closeProfile}
                    onSave={saveProfile}
                />
            ) if showProfile else None}

            <ChatPanel
                onTasksChanged={lambda -> None { fetchLists(); fetchTasks(); calendarRefreshKey = calendarRefreshKey + 1; }}
            />
        </div>;
}

def:pub CreateListForm(onClose: any, onCreate: any) -> any {
    has name: str = "";

    return
        <div>
            <div className="modal-body">
                <div className="form-field">
                    <label className="form-label">List Name</label>
                    <input
                        type="text"
                        value={name}
                        onChange={lambda e: any -> None { name = e.target.value; }}
                        placeholder="e.g. Sprint 1, Backlog"
                        className="form-input"
                        autoFocus={True}
                    />
                </div>
            </div>
            <div className="modal-footer">
                <button onClick={onClose} className="btn-secondary">Cancel</button>
                <button
                    onClick={lambda -> None { onCreate(name); onClose(); }}
                    className="btn-primary"
                    disabled={name.trim() == ""}
                >
                    Create List
                </button>
            </div>
        </div>;
}

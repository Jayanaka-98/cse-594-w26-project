"""FlowBoard - ClickUp-style Project Management Frontend."""

import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }

import "./styles.css";

import from .components.AuthForm { AuthForm }
import from .components.Sidebar { Sidebar }
import from .components.TaskCard { TaskCard }
import from .components.KanbanBoard { KanbanBoard }
import from .components.TaskModal { TaskModal }
import from .components.TaskDetailPanel { TaskDetailPanel }
import from .components.ProfilePanel { ProfilePanel }
import from .components.CalendarView { CalendarView }
import from .components.GlobalTaskModal { GlobalTaskModal }
import from .components.DashboardView { DashboardView }

sv import from main {
    CreateSpace, ListSpaces, DeleteSpace,
    CreateList, ListLists, DeleteList,
    CreateTask, ListTasks, UpdateTask, DeleteTask,
    AddComment, ListComments, DeleteComment,
    GetUserProfile, UpdateUserProfile
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
        spaces: list = [],
        lists: list = [],
        tasks: list = [],
        comments: list = [],

        # Navigation
        selectedSpaceId: str = "",
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

        # Calendar
        calendarTasks: list = [],

        # Create task modal
        showCreateTask: bool = False,
        showGlobalCreateTask: bool = False,

        # Create space modal
        showCreateSpace: bool = False,

        # Create list modal
        showCreateList: bool = False,
        createListForSpaceId: str = "",

        # Loading
        spacesLoading: bool = True,
        tasksLoading: bool = False;

    can with entry {
        isLoggedIn = jacIsLoggedIn();
        checkingAuth = False;
    }

    can with [isLoggedIn] entry {
        if isLoggedIn {
            fetchProfile();
            fetchSpaces();
            fetchLists();
        }
    }

    can with [selectedListId] entry {
        if selectedListId != "" {
            fetchTasks();
        }
    }

    can with [view] entry {
        if view == "calendar" {
            fetchCalendarTasks();
        }
    }

    # Method declarations (implementations in frontend.impl.jac)
    async def fetchSpaces -> None;
    async def fetchLists -> None;
    async def fetchTasks -> None;
    async def fetchCalendarTasks -> None;
    async def fetchProfile -> None;
    async def saveProfile(displayName: str, theme: str, defaultView: str) -> None;
    async def toggleTheme -> None;
    def openProfile -> None;
    def closeProfile -> None;
    async def createSpace(name: str, color: str) -> None;
    async def createList(name: str, spaceId: str) -> None;
    async def createTask(title: str, description: str, status: str, priority: str, dueDate: str, parentTaskId: str, startDate: str, startTime: str, endTime: str) -> None;
    async def updateTask(taskId: str, title: str, description: str, status: str, priority: str, dueDate: str, startDate: str, startTime: str, endTime: str) -> None;
    async def updateTaskStatus(taskId: str, status: str) -> None;
    async def deleteTask(taskId: str) -> None;
    async def deleteSpace(spaceId: str) -> None;
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
                            {("🌙" if darkMode else "☀️")}
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
                <Sidebar
                    spaces={spaces}
                    lists={lists}
                    tasks={tasks}
                    selectedSpaceId={selectedSpaceId}
                    selectedListId={selectedListId}
                    spacesLoading={spacesLoading}
                    onSelectSpace={lambda spaceId: str -> None { selectedSpaceId = spaceId; selectedListId = ""; tasks = []; showTaskDetail = False; }}
                    onSelectList={lambda listId: str -> None { selectedListId = listId; showTaskDetail = False; }}
                    onCreateSpace={lambda -> None { showCreateSpace = True; }}
                    onCreateList={lambda spaceId: str -> None { createListForSpaceId = spaceId; showCreateList = True; }}
                    onDeleteSpace={deleteSpace}
                    onDeleteList={deleteList}
                    
                />
                <div className="main-content">
                    <div className="view-tab-bar">
                        <button
                            onClick={lambda -> None { view = "list"; }}
                            className={("view-tab active" if view == "list" else "view-tab")}
                            disabled={selectedListId == ""}
                        >
                            ≡ List
                        </button>
                        <button
                            onClick={lambda -> None { view = "board"; }}
                            className={("view-tab active" if view == "board" else "view-tab")}
                            disabled={selectedListId == ""}
                        >
                            ⊞ Board
                        </button>
                        <button
                            onClick={lambda -> None { view = "calendar"; fetchCalendarTasks(); }}
                            className={("view-tab active" if view == "calendar" else "view-tab")}
                        >
                            📅 Calendar
                        </button>
                        <button
                            onClick={lambda -> None { view = "dashboard"; }}
                            className={("view-tab active" if view == "dashboard" else "view-tab")}
                        >
                            📊 Dashboard
                        </button>
                        {(
                            <button
                                onClick={lambda -> None { showCreateTask = True; }}
                                className="btn-primary btn-sm view-tab-action"
                            >
                                + New Task
                            </button>
                        ) if selectedListId != "" and view != "calendar" and view != "dashboard" else None}
                    </div>

                    {(
                        <DashboardView onOpenDetail={openTask} />
                    ) if view == "dashboard" else (
                        <CalendarView
                            allTasks={calendarTasks}
                            onUpdateTask={updateTask}
                            onOpenDetail={openTask}
                        />
                    ) if view == "calendar" else (
                        (
                            <div className="empty-state">
                                <div className="empty-state-icon">⚡</div>
                                <h2 className="empty-state-title">Welcome to FlowBoard</h2>
                                <p className="empty-state-text">
                                    Create a Space to organize your work, then add Lists and Tasks.
                                </p>
                                <button
                                    onClick={lambda -> None { showCreateSpace = True; }}
                                    className="btn-primary btn-lg"
                                >
                                    + Create Space
                                </button>
                            </div>
                        ) if selectedListId == "" else (
                            <div className="content-area">
                                <div className="content-header">
                                    <div className="content-header-left">
                                        <h2 className="list-title">
                                            {currentList.name if currentList else "Tasks"}
                                        </h2>
                                        <span className="task-count">
                                            {tasks.filter(lambda t: any -> bool { return t.parent_task_id == ""; }).length} tasks
                                        </span>
                                    </div>
                                </div>
                                {(
                                    <div className="loading-tasks">
                                        <div className="loading-spinner"></div>
                                        Loading tasks...
                                    </div>
                                ) if tasksLoading else (
                                    <div>
                                        {(
                                            <KanbanBoard
                                                tasks={tasks.filter(lambda t: any -> bool { return t.parent_task_id == ""; })}
                                                onOpenDetail={openTask}
                                                onStatusChange={updateTaskStatus}
                                                onDelete={deleteTask}
                                            />
                                        ) if view == "board" else (
                                            <div className="task-list">
                                                {(
                                                    <div className="empty-tasks">
                                                        <p className="empty-tasks-text">No tasks yet.</p>
                                                        <button
                                                            onClick={lambda -> None { showCreateTask = True; }}
                                                            className="btn-text"
                                                        >
                                                            + Create your first task
                                                        </button>
                                                    </div>
                                                ) if tasks.filter(lambda t: any -> bool { return t.parent_task_id == ""; }).length == 0 else (
                                                    <div>
                                                        {[
                                                            <TaskCard
                                                                key={task.id}
                                                                task={task}
                                                                onOpenDetail={openTask}
                                                                onStatusChange={updateTaskStatus}
                                                                onDelete={deleteTask}
                                                            /> for task in tasks if task.parent_task_id == ""
                                                        ]}
                                                    </div>
                                                )}
                                            </div>
                                        )}
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
                        onAddSubtask={lambda title: str -> None { createTask(title, "", "todo", "normal", "", selectedTask.id, "", "", ""); }}
                    />
                ) if showTaskDetail else None}
            </div>
            {(
                <GlobalTaskModal
                    onClose={lambda -> None { showGlobalCreateTask = False; }}
                    onCreated={lambda -> None { fetchSpaces(); fetchLists(); fetchTasks(); fetchCalendarTasks(); }}
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
                <div className="modal-overlay" onClick={lambda -> None { showCreateSpace = False; }}>
                    <div className="modal-box" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                        <div className="modal-header">
                            <h3 className="modal-title">Create Space</h3>
                            <button
                                onClick={lambda -> None { showCreateSpace = False; }}
                                className="btn-close"
                            >
                                ×
                            </button>
                        </div>
                        <CreateSpaceForm
                            onClose={lambda -> None { showCreateSpace = False; }}
                            onCreate={createSpace}
                        />
                    </div>
                </div>
            ) if showCreateSpace else None}
            {(
                <div className="modal-overlay" onClick={lambda -> None { showCreateList = False; }}>
                    <div className="modal-box" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                        <div className="modal-header">
                            <h3 className="modal-title">Create List</h3>
                            <button
                                onClick={lambda -> None { showCreateList = False; }}
                                className="btn-close"
                            >
                                ×
                            </button>
                        </div>
                        <CreateListForm
                            spaceId={createListForSpaceId}
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
        </div>;
}

def:pub CreateSpaceForm(onClose: any, onCreate: any) -> any {
    has name: str = "",
        color: str = "purple";

    return
        <div>
            <div className="modal-body">
                <div className="form-field">
                    <label className="form-label">Space Name</label>
                    <input
                        type="text"
                        value={name}
                        onChange={lambda e: any -> None { name = e.target.value; }}
                        placeholder="e.g. Marketing, Engineering"
                        className="form-input"
                        autoFocus={True}
                    />
                </div>
                <div className="form-field">
                    <label className="form-label">Color</label>
                    <div className="color-picker">
                        {[
                            <button
                                key={c}
                                className={("color-dot color-" + c + (" selected" if c == color else ""))}
                                onClick={lambda -> None { color = c; }}
                                title={c}
                            /> for c in ["purple", "blue", "green", "red", "orange", "pink"]
                        ]}
                    </div>
                </div>
            </div>
            <div className="modal-footer">
                <button onClick={onClose} className="btn-secondary">Cancel</button>
                <button
                    onClick={lambda -> None { onCreate(name, color); onClose(); }}
                    className="btn-primary"
                    disabled={name.trim() == ""}
                >
                    Create Space
                </button>
            </div>
        </div>;
}

def:pub CreateListForm(spaceId: str, onClose: any, onCreate: any) -> any {
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
                    onClick={lambda -> None { onCreate(name, spaceId); onClose(); }}
                    className="btn-primary"
                    disabled={name.trim() == ""}
                >
                    Create List
                </button>
            </div>
        </div>;
}

"""Calendar view with week grid, unscheduled sidebar, drag-and-drop scheduling, and resize."""

sv import from main { ListTasks, UpdateTaskLock, AIReplanSchedule, ApplyReplanChanges }
import from .ExplanationPanel { ExplanationPanel }
import from "lucide-react" { Lock, LockOpen, AlertTriangle, ChevronLeft, ChevronRight }

def:pub CalendarView(
    onUpdateTask: any,
    onOpenDetail: any
) -> any {
    has weekOffset: int = 0,
        weekDates: list = [],
        internalTasks: list = [],
        draggingTaskId: str = "",
        draggingFromCalendar: bool = False,
        resizingTaskId: str = "",
        resizeStartY: int = 0,
        resizeOriginalEnd: str = "",
        resizeCurrentEndTime: str = "",
        explanationTaskId: str = "",
        explanationPinned: bool = False,
        explanationCache: dict = {},
        hoverTimerId: int = 0,
        conflictingIds: list = [],
        replanBannerChanges: list = [],
        replanBannerExplanation: str = "";

    can with entry {
        fetchTasks();
        scrollToNow();
    }

    can with [weekOffset] entry {
        computeWeekDates();
    }

    async def fetchTasks -> None {
        result = root spawn ListTasks(list_id="");
        loaded = result.reports[0] if result.reports else [];
        internalTasks = loaded;
        conflictingIds = computeLocalConflicts(loaded);
    }

    def computeLocalConflicts(taskList: list) -> list {
        defaultRatios = {"Coding": 1.42, "Research": 1.35, "Writing": 1.22, "Meeting": 1.08, "Admin": 1.05};
        scheduled = taskList.filter(lambda t: any -> bool {
            return t.start_date != "" and t.start_time != "" and t.status != "done";
        });
        ids = [];
        scheduled.forEach(lambda a: any -> None {
            scheduled.forEach(lambda b: any -> None {
                if a.id == b.id { return; }
                if a.start_date != b.start_date { return; }
                aStart = parseInt(a.start_time.split(":")[0]) * 60 + parseInt(a.start_time.split(":")[1]);
                aDur = a.estimated_duration if a.estimated_duration else 60;
                aRatio = defaultRatios[a.category] if (a.category and defaultRatios[a.category]) else 1.1;
                aEnd = aStart + Math.ceil(aDur * aRatio);
                bStart = parseInt(b.start_time.split(":")[0]) * 60 + parseInt(b.start_time.split(":")[1]);
                bDur = b.estimated_duration if b.estimated_duration else 60;
                bRatio = defaultRatios[b.category] if (b.category and defaultRatios[b.category]) else 1.1;
                bEnd = bStart + Math.ceil(bDur * bRatio);
                if aStart < bEnd and bStart < aEnd {
                    if not ids.includes(a.id) { ids.push(a.id); }
                }
            });
        });
        return ids;
    }

    def scrollToNow -> None {
        el = document.querySelector(".cal-grid-scroll");
        if el { el.scrollTop = 120; }
    }

    def computeWeekDates -> None {
        today = Reflect.construct(Date, []);
        dayOfWeek = today.getDay();
        # offset so Monday = index 0
        offset = (dayOfWeek + 6) % 7;
        dates = [];
        for i in [0, 1, 2, 3, 4, 5, 6] {
            d = Reflect.construct(Date, [today]);
            d.setDate(today.getDate() - offset + i + weekOffset * 7);
            y = d.getFullYear().toString();
            mo = (d.getMonth() + 1).toString().padStart(2, "0");
            dy = d.getDate().toString().padStart(2, "0");
            dates.append(y + "-" + mo + "-" + dy);
        }
        weekDates = dates;
    }

    def formatDayHeader(dateStr: str) -> str {
        if not dateStr or dateStr == "" { return ""; }
        d = Reflect.construct(Date, [dateStr + "T12:00:00"]);
        dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return dayNames[d.getDay()] + " " + d.getDate().toString();
    }

    def formatWeekLabel -> str {
        if len(weekDates) == 0 { return "Loading..."; }
        d1 = Reflect.construct(Date, [weekDates[0] + "T12:00:00"]);
        d2 = Reflect.construct(Date, [weekDates[6] + "T12:00:00"]);
        months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[d1.getMonth()] + " " + d1.getDate().toString() + " – " + months[d2.getMonth()] + " " + d2.getDate().toString() + ", " + d1.getFullYear().toString();
    }

    def isToday(dateStr: str) -> bool {
        t = Reflect.construct(Date, []);
        y = t.getFullYear().toString();
        mo = (t.getMonth() + 1).toString().padStart(2, "0");
        dy = t.getDate().toString().padStart(2, "0");
        return dateStr == (y + "-" + mo + "-" + dy);
    }

    def timeToMins(t: str) -> int {
        if not t or t == "" { return 0; }
        parts = t.split(":");
        return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }

    def minsToTime(m: int) -> str {
        h = Math.floor(m / 60);
        mn = m % 60;
        return h.toString().padStart(2, "0") + ":" + mn.toString().padStart(2, "0");
    }

    def getTaskTop(task: any) -> str {
        startMins = timeToMins(task.start_time);
        top = Math.max(0, startMins - 360);
        return top.toString() + "px";
    }

    def getTaskHeight(task: any) -> str {
        startMins = timeToMins(task.start_time);
        endTimeStr = (resizeCurrentEndTime if (resizingTaskId == task.id and resizeCurrentEndTime != "") else task.end_time);
        endMins = timeToMins(endTimeStr);
        if endMins <= startMins { endMins = startMins + 60; }
        h = Math.max(30, endMins - startMins);
        return h.toString() + "px";
    }

    def getTasksForDate(dateStr: str) -> list {
        return internalTasks.filter(lambda t: any -> bool { return t.start_date == dateStr and t.start_time != "" and t.start_time != None; });
    }

    def getUnscheduledTasks -> list {
        return internalTasks.filter(lambda t: any -> bool {
            return t.parent_task_id == "" and (not t.start_date or t.start_date == "" or not t.start_time or t.start_time == "");
        });
    }

    async def handleDrop(e: any, dateStr: str) -> None {
        e.preventDefault();
        if draggingTaskId == "" { return; }
        matches = internalTasks.filter(lambda t: any -> bool { return t.id == draggingTaskId; });
        if len(matches) == 0 { draggingTaskId = ""; return; }
        task = matches[0];
        colEl = e.currentTarget;
        rect = colEl.getBoundingClientRect();
        relY = Math.max(0, e.clientY - rect.top);
        snapped = Math.floor(relY / 15) * 15;
        startTotalMins = 360 + snapped;
        startH = Math.min(22, Math.floor(startTotalMins / 60));
        startM = startTotalMins % 60;
        endTotalMins = startH * 60 + startM + 60;
        endH = Math.min(23, Math.floor(endTotalMins / 60));
        endM = endTotalMins % 60;
        st = startH.toString().padStart(2, "0") + ":" + startM.toString().padStart(2, "0");
        et = endH.toString().padStart(2, "0") + ":" + endM.toString().padStart(2, "0");
        droppedTaskId = draggingTaskId;
        draggingTaskId = "";
        await onUpdateTask(task.id, task.title, task.description, task.status, task.priority, task.due_date, dateStr, st, et);
        await fetchTasks();
        replanResult = root spawn AIReplanSchedule(new_task_id=droppedTaskId);
        if replanResult.reports {
            proposal = replanResult.reports[0];
            if proposal.has_conflict {
                replanBannerChanges = proposal.changes;
                replanBannerExplanation = proposal.explanation;
            }
        }
    }

    def startResize(e: any, task: any) -> None {
        e.preventDefault();
        e.stopPropagation();
        resizingTaskId = task.id;
        resizeStartY = e.clientY;
        resizeOriginalEnd = task.end_time;
        resizeCurrentEndTime = task.end_time;
    }

    def handleResizeMove(e: any) -> None {
        if resizingTaskId == "" { return; }
        deltaY = e.clientY - resizeStartY;
        deltaMins = Math.round(deltaY / 15) * 15;
        origEndMins = timeToMins(resizeOriginalEnd);
        newEndMins = Math.max(origEndMins + 15, origEndMins + deltaMins);
        newEndMins = Math.min(23 * 60, newEndMins);
        resizeCurrentEndTime = minsToTime(newEndMins);
    }

    async def handleResizeEnd(e: any) -> None {
        if resizingTaskId == "" { return; }
        matches = internalTasks.filter(lambda t: any -> bool { return t.id == resizingTaskId; });
        if len(matches) > 0 and resizeCurrentEndTime != "" {
            task = matches[0];
            await onUpdateTask(task.id, task.title, task.description, task.status, task.priority, task.due_date, task.start_date, task.start_time, resizeCurrentEndTime);
        }
        resizingTaskId = "";
        resizeStartY = 0;
        resizeOriginalEnd = "";
        resizeCurrentEndTime = "";
        await fetchTasks();
    }

    def formatHourLabel(h: int) -> str {
        suffix = "am" if h < 12 else "pm";
        displayH = h if h <= 12 else h - 12;
        if h == 0 { displayH = 12; }
        return displayH.toString() + suffix;
    }

    def getPriorityClass(priority: str) -> str {
        if priority == "urgent" { return "cal-event-urgent"; }
        if priority == "high" { return "cal-event-high"; }
        if priority == "normal" { return "cal-event-normal"; }
        return "cal-event-low";
    }

    def getConfidenceClass(task: any) -> str {
        if task.ai_confidence >= 80 { return " cal-event-confident"; }
        if task.ai_confidence > 0 and task.ai_confidence < 60 { return " cal-event-uncertain"; }
        return "";
    }

    def handleTaskHover(task: any) -> None {
        if hoverTimerId != 0 { clearTimeout(hoverTimerId); }
        hoverTimerId = setTimeout(lambda -> None {
            if not explanationPinned { explanationTaskId = task.id; }
            hoverTimerId = 0;
        }, 400);
    }

    def handleTaskLeave -> None {
        if hoverTimerId != 0 { clearTimeout(hoverTimerId); hoverTimerId = 0; }
        # Panel stays visible after hover — user can move cursor to it and click buttons
        # Only explicit close/accept/reject hides it
    }

    def handleTaskClick(task: any) -> None {
        explanationTaskId = task.id;
        explanationPinned = True;
    }

    async def toggleLock(e: any, task: any) -> None {
        e.stopPropagation();
        root spawn UpdateTaskLock(task_id=task.id, is_locked=(not task.is_locked));
        await fetchTasks();
    }

    async def acceptReplan -> None {
        root spawn ApplyReplanChanges(changes=replanBannerChanges);
        replanBannerChanges = [];
        replanBannerExplanation = "";
        await fetchTasks();
    }

    hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
    unscheduled = getUnscheduledTasks();

    explanationTaskMatches = internalTasks.filter(lambda t: any -> bool { return t.id == explanationTaskId; });
    explanationTask = explanationTaskMatches[0] if len(explanationTaskMatches) > 0 else None;

    return
        <div className="cal-container">
            {(
                <div
                    className="cal-resize-overlay"
                    onMouseMove={handleResizeMove}
                    onMouseUp={handleResizeEnd}
                />
            ) if resizingTaskId != "" else None}

            {(
                <div className="cal-replan-banner">
                    <AlertTriangle size={16} className="cal-replan-icon" />
                    <span className="cal-replan-text">{replanBannerExplanation}</span>
                    <button className="cal-replan-accept" onClick={lambda -> None { acceptReplan(); }}>
                        Accept Changes
                    </button>
                    <button className="cal-replan-dismiss" onClick={lambda -> None { replanBannerChanges = []; replanBannerExplanation = ""; }}>
                        Dismiss
                    </button>
                </div>
            ) if len(replanBannerChanges) > 0 else None}

            {(
                <ExplanationPanel
                    key={explanationTaskId}
                    task={explanationTask}
                    cachedData={explanationCache[explanationTaskId] if explanationCache[explanationTaskId] else None}
                    onCached={lambda data: any -> None { explanationCache[explanationTaskId] = data; }}
                    onClose={lambda -> None { explanationTaskId = ""; explanationPinned = False; }}
                    onAccept={lambda -> None { explanationTaskId = ""; explanationPinned = False; }}
                    onModify={lambda -> None { onOpenDetail(explanationTask); explanationTaskId = ""; explanationPinned = False; }}
                    onReject={lambda -> None { explanationTaskId = ""; explanationPinned = False; }}
                />
            ) if explanationTask != None else None}

            <div className="cal-sidebar">
                <div className="cal-sidebar-header">
                    <span className="cal-sidebar-title">Unscheduled</span>
                    <span className="cal-sidebar-count">{len(unscheduled)}</span>
                </div>
                <div className="cal-sidebar-tasks">
                    {(
                        <p className="cal-sidebar-empty">All tasks scheduled</p>
                    ) if len(unscheduled) == 0 else (
                        <div>
                            {[
                                <div
                                    key={task.id}
                                    className={"cal-sidebar-task cal-side-" + task.priority}
                                    draggable={True}
                                    onDragStart={lambda e: any -> None {
                                        draggingTaskId = task.id;
                                        draggingFromCalendar = False;
                                        e.dataTransfer.effectAllowed = "move";
                                        e.dataTransfer.setData("text/plain", task.id);
                                    }}
                                    onClick={lambda -> None { onOpenDetail(task); }}
                                    title={"Drag to schedule: " + task.title}
                                >
                                    <span className="cal-sidebar-task-bullet"></span>
                                    <span className="cal-sidebar-task-title">{task.title}</span>
                                    <span className={"cal-sidebar-task-pri pri-" + task.priority}>
                                        {task.priority[0].toUpperCase()}
                                    </span>
                                </div>
                                for task in unscheduled
                            ]}
                        </div>
                    )}
                </div>
            </div>

            <div className="cal-main">
                <div className="cal-nav">
                    <button
                        className="cal-nav-btn"
                        onClick={lambda -> None { weekOffset = weekOffset - 1; }}
                        title="Previous week"
                    >
                        <ChevronLeft size={18} />
                    </button>
                    <span className="cal-nav-label">{formatWeekLabel()}</span>
                    <button
                        className="cal-nav-btn"
                        onClick={lambda -> None { weekOffset = weekOffset + 1; }}
                        title="Next week"
                    >
                        <ChevronRight size={18} />
                    </button>
                    <button
                        className="cal-nav-today"
                        onClick={lambda -> None { weekOffset = 0; }}
                    >
                        Today
                    </button>
                </div>

                <div className="cal-day-headers">
                    <div className="cal-time-gutter-head"></div>
                    {[
                        <div
                            key={dateStr}
                            className={"cal-day-header-cell" + (" cal-day-today" if isToday(dateStr) else "")}
                        >
                            {formatDayHeader(dateStr)}
                        </div>
                        for dateStr in weekDates
                    ]}
                </div>

                <div className="cal-grid-scroll">
                    <div className="cal-grid-inner">
                        <div className="cal-time-gutter">
                            {[
                                <div key={h} className="cal-hour-label">
                                    {formatHourLabel(h)}
                                </div>
                                for h in hours
                            ]}
                        </div>

                        {[
                            <div
                                key={dateStr}
                                className={"cal-day-col" + (" cal-day-col-today" if isToday(dateStr) else "")}
                                onDragOver={lambda e: any -> None { e.preventDefault(); }}
                                onDrop={lambda e: any -> None { handleDrop(e, dateStr); }}
                            >
                                {[
                                    <div
                                        key={h}
                                        className="cal-hour-line"
                                        style={{top: ((h - 6) * 60).toString() + "px"}}
                                    ></div>
                                    for h in hours
                                ]}

                                {[
                                    <div
                                        key={"h" + h.toString()}
                                        className="cal-half-line"
                                        style={{top: ((h - 6) * 60 + 30).toString() + "px"}}
                                    ></div>
                                    for h in hours
                                ]}

                                {[
                                    <div
                                        key={task.id}
                                        className={"cal-event " + getPriorityClass(task.priority) + getConfidenceClass(task) + ((" cal-event-locked") if task.is_locked else "") + ((" cal-event-conflict") if conflictingIds.includes(task.id) else "")}
                                        style={{
                                            top: getTaskTop(task),
                                            height: getTaskHeight(task)
                                        }}
                                        draggable={(not task.is_locked)}
                                        onMouseEnter={lambda e: any -> None { handleTaskHover(task); }}
                                        onMouseLeave={lambda -> None { handleTaskLeave(); }}
                                        onDragStart={lambda e: any -> None {
                                            if task.is_locked { return; }
                                            draggingTaskId = task.id;
                                            draggingFromCalendar = True;
                                            e.dataTransfer.effectAllowed = "move";
                                            e.dataTransfer.setData("text/plain", task.id);
                                        }}
                                        onClick={lambda -> None { handleTaskClick(task); }}
                                    >
                                        <div className="cal-event-body">
                                            <span className="cal-event-title">{task.title}</span>
                                            <span className="cal-event-time">
                                                {task.start_time + " – " + (resizeCurrentEndTime if (resizingTaskId == task.id and resizeCurrentEndTime != "") else task.end_time)}
                                            </span>
                                            {(
                                                <span className="cal-event-conflict-badge">⚠ overrun conflict</span>
                                            ) if conflictingIds.includes(task.id) else None}
                                        </div>
                                        <button
                                            className={"cal-event-lock" + (" cal-event-lock-active" if task.is_locked else "")}
                                            onClick={lambda e: any -> None { toggleLock(e, task); }}
                                            title={("Unlock" if task.is_locked else "Lock position")}
                                        >
                                            {(<Lock size={11} />) if task.is_locked else (<LockOpen size={11} />)}
                                        </button>
                                        <div
                                            className="cal-event-resize-handle"
                                            onMouseDown={lambda e: any -> None { startResize(e, task); }}
                                            title="Drag to resize"
                                        >
                                            ⠿
                                        </div>
                                    </div>
                                    for task in getTasksForDate(dateStr)
                                ]}
                            </div>
                            for dateStr in weekDates
                        ]}
                    </div>
                </div>
            </div>
        </div>;
}

"""Calendar view with week grid, unscheduled sidebar, drag-and-drop scheduling, and resize."""

sv import from main { ListTasks }

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
        resizeCurrentEndTime: str = "";

    can with entry {
        fetchTasks();
        scrollToNow();
    }

    can with [weekOffset] entry {
        computeWeekDates();
    }

    async def fetchTasks -> None {
        result = root spawn ListTasks(list_id="");
        internalTasks = result.reports[0] if result.reports else [];
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
        if weekDates.length == 0 { return "Loading..."; }
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
        if matches.length == 0 { draggingTaskId = ""; return; }
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
        draggingTaskId = "";
        await onUpdateTask(task.id, task.title, task.description, task.status, task.priority, task.due_date, dateStr, st, et);
        await fetchTasks();
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
        if matches.length > 0 and resizeCurrentEndTime != "" {
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

    hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22];
    unscheduled = getUnscheduledTasks();

    return
        <div className="cal-container">
            {(
                <div
                    className="cal-resize-overlay"
                    onMouseMove={handleResizeMove}
                    onMouseUp={handleResizeEnd}
                />
            ) if resizingTaskId != "" else None}

            <div className="cal-sidebar">
                <div className="cal-sidebar-header">
                    <span className="cal-sidebar-title">Unscheduled</span>
                    <span className="cal-sidebar-count">{unscheduled.length}</span>
                </div>
                <div className="cal-sidebar-tasks">
                    {(
                        <p className="cal-sidebar-empty">All tasks scheduled</p>
                    ) if unscheduled.length == 0 else (
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
                        ‹
                    </button>
                    <span className="cal-nav-label">{formatWeekLabel()}</span>
                    <button
                        className="cal-nav-btn"
                        onClick={lambda -> None { weekOffset = weekOffset + 1; }}
                        title="Next week"
                    >
                        ›
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
                                        className={"cal-event " + getPriorityClass(task.priority)}
                                        style={{
                                            top: getTaskTop(task),
                                            height: getTaskHeight(task)
                                        }}
                                        draggable={True}
                                        onDragStart={lambda e: any -> None {
                                            draggingTaskId = task.id;
                                            draggingFromCalendar = True;
                                            e.dataTransfer.effectAllowed = "move";
                                            e.dataTransfer.setData("text/plain", task.id);
                                        }}
                                        onClick={lambda -> None { onOpenDetail(task); }}
                                    >
                                        <div className="cal-event-body">
                                            <span className="cal-event-title">{task.title}</span>
                                            <span className="cal-event-time">
                                                {task.start_time + " – " + (resizeCurrentEndTime if (resizingTaskId == task.id and resizeCurrentEndTime != "") else task.end_time)}
                                            </span>
                                        </div>
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

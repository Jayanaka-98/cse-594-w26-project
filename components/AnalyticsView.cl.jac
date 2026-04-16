"""Analytics dashboard — status, priority, estimation accuracy, productivity, and task history."""

import from "recharts" { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer }
sv import from main { ListTaskHistory, GetUserPatterns }

def:pub AnalyticsView(tasks: list) -> JsxElement {
    has history: list = [];
    has patterns: dict = {};

    can with entry {
        fetchHistory();
        fetchPatterns();
    }

    async def fetchHistory -> None {
        result = root spawn ListTaskHistory();
        history = result.reports[0] if result.reports else [];
    }

    async def fetchPatterns -> None {
        result = root spawn GetUserPatterns();
        patterns = result.reports[0] if result.reports else {};
    }

    # ── Task status / priority counts ─────────────────────────────────
    todoCount       = len(tasks.filter(lambda t: any -> bool { return t.status == "todo"; }));
    inProgressCount = len(tasks.filter(lambda t: any -> bool { return t.status == "in_progress"; }));
    reviewCount     = len(tasks.filter(lambda t: any -> bool { return t.status == "review"; }));
    doneCount       = len(tasks.filter(lambda t: any -> bool { return t.status == "done"; }));
    urgentCount     = len(tasks.filter(lambda t: any -> bool { return t.priority == "urgent"; }));
    highCount       = len(tasks.filter(lambda t: any -> bool { return t.priority == "high"; }));
    normalCount     = len(tasks.filter(lambda t: any -> bool { return t.priority == "normal"; }));
    lowCount        = len(tasks.filter(lambda t: any -> bool { return t.priority == "low"; }));
    totalTasks      = len(tasks);
    completionRate  = (Math.round(doneCount / totalTasks * 100)) if totalTasks > 0 else 0;

    # ── Patterns data ─────────────────────────────────────────────────
    catProductivity = patterns["category_productivity"] if patterns and patterns["category_productivity"] else {};
    catOverrun      = patterns["category_overrun_ratios"] if patterns and patterns["category_overrun_ratios"] else {};
    oosMinutes      = patterns["out_of_scope_minutes"] if patterns and patterns["out_of_scope_minutes"] else 0;
    oosHours        = Math.round(oosMinutes / 60 * 10) / 10;

    prodValues = Object.values(catProductivity);
    avgProductivity = (Math.round(prodValues.reduce(lambda acc: any, v: any -> any { return acc + v; }, 0) / prodValues.length * 100)) if prodValues.length > 0 else None;

    # ── Chart datasets ────────────────────────────────────────────────
    statusData = [
        {"name": "Todo",        "value": todoCount,       "fill": "#6366f1"},
        {"name": "In Progress", "value": inProgressCount, "fill": "#f59e0b"},
        {"name": "Review",      "value": reviewCount,     "fill": "#8b5cf6"},
        {"name": "Done",        "value": doneCount,       "fill": "#10b981"}
    ];
    priorityData = [
        {"name": "Urgent", "value": urgentCount, "fill": "#ef4444"},
        {"name": "High",   "value": highCount,   "fill": "#f97316"},
        {"name": "Normal", "value": normalCount, "fill": "#6366f1"},
        {"name": "Low",    "value": lowCount,    "fill": "#64748b"}
    ];

    def getCategoryAccuracy(cat: str) -> dict {
        catHistory = history.filter(lambda h: any -> bool { return h.category == cat; });
        if len(catHistory) == 0 { return {"name": cat, "Estimated": 0, "Actual": 0}; }
        totalEst = 0;
        totalAct = 0;
        for item in catHistory {
            totalEst = totalEst + item.estimated_duration;
            totalAct = totalAct + item.actual_duration;
        }
        return {
            "name": cat,
            "Estimated": Math.round(totalEst / len(catHistory)),
            "Actual": Math.round(totalAct / len(catHistory))
        };
    }

    accuracyData = ["Research", "Coding", "Meeting", "Writing", "Admin"].map(
        lambda cat: str -> dict { return getCategoryAccuracy(cat); }
    ).filter(lambda d: any -> bool { return d.Estimated > 0; });

    def countTasksAtHour(h: int) -> int {
        return len(tasks.filter(lambda t: any -> bool {
            if not t.start_time or t.start_time == "" { return False; }
            parts = t.start_time.split(":");
            return parseInt(parts[0]) == h;
        }));
    }

    hourlyData = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22].map(
        lambda h: int -> dict { return {"hour": h.toString() + ":00", "Tasks": countTasksAtHour(h)}; }
    );

    productivityData = Object.entries(catProductivity).map(
        lambda `entry: any -> dict {
            return {"name": `entry[0], "Productivity": Math.round(`entry[1] * 100)};
        }
    ).sort(lambda a: any, b: any -> any { return b.Productivity - a.Productivity; });

    overrunData = Object.entries(catOverrun).map(
        lambda `entry: any -> dict { return {"name": `entry[0], "Ratio": `entry[1]}; }
    ).sort(lambda a: any, b: any -> any { return b.Ratio - a.Ratio; });

    sortedHistory = history;

    def overrunLabel(est: int, act: int) -> str {
        if est == 0 or act == 0 { return "—"; }
        diff = act - est;
        if diff > 0 { return "+" + str(diff) + " min"; }
        if diff < 0 { return str(diff) + " min"; }
        return "on time";
    }

    def overrunClass(est: int, act: int) -> str {
        if est == 0 or act == 0 { return ""; }
        diff = act - est;
        if diff > 5 { return "history-over"; }
        if diff < -5 { return "history-under"; }
        return "history-ontime";
    }

    def prodColor(pct: int) -> str {
        if pct >= 80 { return "#10b981"; }
        if pct >= 60 { return "#f59e0b"; }
        return "#ef4444";
    }

    tooltipStyle  = {"background": "#1a2030", "border": "1px solid #21262d", "borderRadius": "8px", "color": "#e2e8f0"};
    axisTickStyle = {"fill": "#94a3b8", "fontSize": 11};

    return
        <div className="analytics-view">

            <div className="analytics-stats-row">
                <div className="analytics-stat-card">
                    <span className="analytics-stat-num">{totalTasks}</span>
                    <span className="analytics-stat-label">Total Tasks</span>
                </div>
                <div className="analytics-stat-card analytics-stat-done">
                    <span className="analytics-stat-num">{doneCount}</span>
                    <span className="analytics-stat-label">Completed</span>
                </div>
                <div className="analytics-stat-card analytics-stat-progress">
                    <span className="analytics-stat-num">{String(completionRate) + "%"}</span>
                    <span className="analytics-stat-label">Completion Rate</span>
                </div>
                <div className="analytics-stat-card analytics-stat-inprogress">
                    <span className="analytics-stat-num">{inProgressCount}</span>
                    <span className="analytics-stat-label">In Progress</span>
                </div>
            </div>

            {(
                <div className="analytics-stats-row">
                    <div className="analytics-stat-card analytics-stat-oos">
                        <span className="analytics-stat-num">
                            {(String(oosHours) + " hr") if oosMinutes >= 60 else (String(oosMinutes) + " min")}
                        </span>
                        <span className="analytics-stat-label">Out-of-Scope Time</span>
                    </div>
                    <div className="analytics-stat-card">
                        <span className="analytics-stat-num">
                            {(String(avgProductivity) + "%") if avgProductivity != None else "—"}
                        </span>
                        <span className="analytics-stat-label">Avg On-Task Rate</span>
                    </div>
                    <div className="analytics-stat-card">
                        <span className="analytics-stat-num">{len(history)}</span>
                        <span className="analytics-stat-label">Tasks Finished</span>
                    </div>
                    <div className="analytics-stat-card">
                        <span className="analytics-stat-num">{len(productivityData)}</span>
                        <span className="analytics-stat-label">Categories Tracked</span>
                    </div>
                </div>
            ) if patterns else None}

            {(
                <div className="analytics-empty">
                    <p>No tasks yet. Create some tasks to see analytics.</p>
                </div>
            ) if totalTasks == 0 else (
                <div>

                    <div className="analytics-charts-row">
                        <div className="analytics-chart-card">
                            <h4 className="analytics-chart-title">Tasks by Status</h4>
                            <ResponsiveContainer width="100%" height={220}>
                                <PieChart>
                                    <Pie data={statusData} dataKey="value" nameKey="name"
                                         cx="50%" cy="50%" outerRadius={80} innerRadius={40}>
                                        {[<Cell key={entry.name} fill={entry.fill} /> for entry in statusData]}
                                    </Pie>
                                    <Tooltip />
                                    <Legend />
                                </PieChart>
                            </ResponsiveContainer>
                        </div>
                        <div className="analytics-chart-card">
                            <h4 className="analytics-chart-title">Tasks by Priority</h4>
                            <ResponsiveContainer width="100%" height={220}>
                                <BarChart data={priorityData} barSize={32}>
                                    <XAxis dataKey="name" tick={axisTickStyle} axisLine={False} tickLine={False} />
                                    <YAxis tick={axisTickStyle} axisLine={False} tickLine={False} />
                                    <Tooltip contentStyle={tooltipStyle} />
                                    <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                                        {[<Cell key={entry.name} fill={entry.fill} /> for entry in priorityData]}
                                    </Bar>
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </div>

                    {(
                        <div className="analytics-charts-row">
                            <div className="analytics-chart-card analytics-chart-wide">
                                <h4 className="analytics-chart-title">Estimation Accuracy by Category</h4>
                                <p className="analytics-chart-subtitle">Avg estimated vs actual duration (min) from completed tasks</p>
                                <ResponsiveContainer width="100%" height={220}>
                                    <BarChart data={accuracyData} barSize={20}>
                                        <XAxis dataKey="name" tick={axisTickStyle} axisLine={False} tickLine={False} />
                                        <YAxis tick={axisTickStyle} axisLine={False} tickLine={False} />
                                        <Tooltip contentStyle={tooltipStyle} />
                                        <Legend />
                                        <Bar dataKey="Estimated" fill="#6366f1" radius={[4, 4, 0, 0]} />
                                        <Bar dataKey="Actual" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>
                        </div>
                    ) if len(accuracyData) > 0 else None}

                    {(
                        <div className="analytics-charts-row">
                            <div className="analytics-chart-card">
                                <h4 className="analytics-chart-title">On-Task Rate by Category</h4>
                                <p className="analytics-chart-subtitle">% of checks where you were actually on task (from widget tracking)</p>
                                <div className="analytics-prod-list">
                                    {[
                                        <div className="analytics-prod-row" key={item.name}>
                                            <span className="analytics-prod-label">{item.name}</span>
                                            <div className="analytics-prod-bar-bg">
                                                <div
                                                    className="analytics-prod-bar-fill"
                                                    style={{"width": String(item.Productivity) + "%", "background": prodColor(item.Productivity)}}
                                                ></div>
                                            </div>
                                            <span className="analytics-prod-pct" style={{"color": prodColor(item.Productivity)}}>
                                                {String(item.Productivity) + "%"}
                                            </span>
                                        </div>
                                        for item in productivityData
                                    ]}
                                </div>
                            </div>

                            <div className="analytics-chart-card">
                                <h4 className="analytics-chart-title">AI-Adjusted Overrun Ratios</h4>
                                <p className="analytics-chart-subtitle">Predicted time multiplier (history + productivity factor)</p>
                                <ResponsiveContainer width="100%" height={200}>
                                    <BarChart data={overrunData} barSize={28} layout="vertical">
                                        <XAxis type="number" tick={axisTickStyle} axisLine={False} tickLine={False} domain={[0, "dataMax + 0.2"]} />
                                        <YAxis type="category" dataKey="name" tick={axisTickStyle} axisLine={False} tickLine={False} width={60} />
                                        <Tooltip contentStyle={tooltipStyle}
                                            formatter={lambda v: any -> any { return [v.toFixed(2) + "×", "Overrun"]; }} />
                                        <Bar dataKey="Ratio" radius={[0, 4, 4, 0]}>
                                            {[
                                                <Cell key={item.name} fill={"#ef4444" if item.Ratio > 1.3 else ("#f59e0b" if item.Ratio > 1.1 else "#10b981")} />
                                                for item in overrunData
                                            ]}
                                        </Bar>
                                    </BarChart>
                                </ResponsiveContainer>
                            </div>
                        </div>
                    ) if len(productivityData) > 0 or len(overrunData) > 0 else None}

                    <div className="analytics-charts-row">
                        <div className="analytics-chart-card analytics-chart-wide">
                            <h4 className="analytics-chart-title">Schedule Density by Hour</h4>
                            <p className="analytics-chart-subtitle">Number of tasks scheduled per hour of the day</p>
                            <ResponsiveContainer width="100%" height={180}>
                                <BarChart data={hourlyData} barSize={16}>
                                    <XAxis dataKey="hour" tick={axisTickStyle} axisLine={False} tickLine={False} />
                                    <YAxis tick={axisTickStyle} axisLine={False} tickLine={False} allowDecimals={False} />
                                    <Tooltip contentStyle={tooltipStyle} />
                                    <Bar dataKey="Tasks" fill="#10b981" radius={[4, 4, 0, 0]} />
                                </BarChart>
                            </ResponsiveContainer>
                        </div>
                    </div>

                    {(
                        <div className="analytics-charts-row">
                            <div className="analytics-chart-card analytics-chart-wide">
                                <h4 className="analytics-chart-title">Completed Task History</h4>
                                <p className="analytics-chart-subtitle">Every finished task — actual vs estimated time</p>
                                <div className="analytics-history-table">
                                    <div className="analytics-history-header">
                                        <span className="ahc ahc-task">Task</span>
                                        <span className="ahc ahc-cat">Category</span>
                                        <span className="ahc ahc-num">Estimated</span>
                                        <span className="ahc ahc-num">Actual</span>
                                        <span className="ahc ahc-num">Overrun</span>
                                        <span className="ahc ahc-date">Completed</span>
                                    </div>
                                    {[
                                        <div className="analytics-history-row" key={item.id}>
                                            <span className="ahc ahc-task analytics-history-name">{item.task_title}</span>
                                            <span className="ahc ahc-cat">
                                                <span className="analytics-cat-badge">{item.category if item.category else "Other"}</span>
                                            </span>
                                            <span className="ahc ahc-num">{String(item.estimated_duration) + " min"}</span>
                                            <span className="ahc ahc-num">{String(item.actual_duration) + " min"}</span>
                                            <span className={"ahc ahc-num " + overrunClass(item.estimated_duration, item.actual_duration)}>
                                                {overrunLabel(item.estimated_duration, item.actual_duration)}
                                            </span>
                                            <span className="ahc ahc-date">
                                                {(item.completed_at or "").split("T")[0] if item.completed_at else "—"}
                                            </span>
                                        </div>
                                        for item in sortedHistory
                                    ]}
                                </div>
                            </div>
                        </div>
                    ) if len(sortedHistory) > 0 else None}

                </div>
            )}
        </div>;
}

"""Analytics dashboard — status, priority, estimation accuracy, and schedule density."""

import from "recharts" { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer }
sv import from main { ListTaskHistory }

def:pub AnalyticsView(tasks: list) -> JsxElement {
    has history: list = [];

    can with entry {
        fetchHistory();
    }

    async def fetchHistory -> None {
        result = root spawn ListTaskHistory();
        history = result.reports[0] if result.reports else [];
    }

    todoCount = tasks.filter(lambda t: any -> bool { return t.status == "todo"; }).length;
    inProgressCount = tasks.filter(lambda t: any -> bool { return t.status == "in_progress"; }).length;
    reviewCount = tasks.filter(lambda t: any -> bool { return t.status == "review"; }).length;
    doneCount = tasks.filter(lambda t: any -> bool { return t.status == "done"; }).length;

    urgentCount = tasks.filter(lambda t: any -> bool { return t.priority == "urgent"; }).length;
    highCount = tasks.filter(lambda t: any -> bool { return t.priority == "high"; }).length;
    normalCount = tasks.filter(lambda t: any -> bool { return t.priority == "normal"; }).length;
    lowCount = tasks.filter(lambda t: any -> bool { return t.priority == "low"; }).length;

    totalTasks = tasks.length;
    completionRate = (Math.round(doneCount / totalTasks * 100)) if totalTasks > 0 else 0;

    statusData = [
        {"name": "Todo", "value": todoCount, "fill": "#6366f1"},
        {"name": "In Progress", "value": inProgressCount, "fill": "#f59e0b"},
        {"name": "Review", "value": reviewCount, "fill": "#8b5cf6"},
        {"name": "Done", "value": doneCount, "fill": "#10b981"}
    ];

    priorityData = [
        {"name": "Urgent", "value": urgentCount, "fill": "#ef4444"},
        {"name": "High", "value": highCount, "fill": "#f97316"},
        {"name": "Normal", "value": normalCount, "fill": "#6366f1"},
        {"name": "Low", "value": lowCount, "fill": "#64748b"}
    ];

    def getCategoryAccuracy(cat: str) -> dict {
        catHistory = history.filter(lambda h: any -> bool { return h.category == cat; });
        if catHistory.length == 0 { return {"name": cat, "Estimated": 0, "Actual": 0}; }
        totalEst = 0;
        totalAct = 0;
        for item in catHistory {
            totalEst = totalEst + item.estimated_duration;
            totalAct = totalAct + item.actual_duration;
        }
        return {
            "name": cat,
            "Estimated": Math.round(totalEst / catHistory.length),
            "Actual": Math.round(totalAct / catHistory.length)
        };
    }

    accuracyData = ["Research", "Coding", "Meeting", "Writing", "Admin"].map(
        lambda cat: str -> dict { return getCategoryAccuracy(cat); }
    ).filter(lambda d: any -> bool { return d.Estimated > 0; });

    def countTasksAtHour(h: int) -> int {
        return tasks.filter(lambda t: any -> bool {
            if not t.start_time or t.start_time == "" { return False; }
            parts = t.start_time.split(":");
            return parseInt(parts[0]) == h;
        }).length;
    }

    hourlyData = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22].map(
        lambda h: int -> dict { return {"hour": h.toString() + ":00", "Tasks": countTasksAtHour(h)}; }
    );

    tooltipStyle = {"background": "#1a2030", "border": "1px solid #21262d", "borderRadius": "8px", "color": "#e2e8f0"};
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
                                    <Pie
                                        data={statusData}
                                        dataKey="value"
                                        nameKey="name"
                                        cx="50%"
                                        cy="50%"
                                        outerRadius={80}
                                        innerRadius={40}
                                    >
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
                                <p className="analytics-chart-subtitle">Avg estimated vs actual duration (minutes) from task history</p>
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
                    ) if history.length > 0 else None}

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
                </div>
            )}
        </div>;
}

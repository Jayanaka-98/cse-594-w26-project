"""Analytics dashboard showing task distribution charts."""

import from "recharts" { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, Tooltip, Legend, ResponsiveContainer }

def:pub AnalyticsView(tasks: list) -> JsxElement {
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
                                <XAxis dataKey="name" tick={{"fill": "#94a3b8", "fontSize": 12}} axisLine={False} tickLine={False} />
                                <YAxis tick={{"fill": "#94a3b8", "fontSize": 12}} axisLine={False} tickLine={False} />
                                <Tooltip
                                    contentStyle={{"background": "#1a2030", "border": "1px solid #21262d", "borderRadius": "8px", "color": "#e2e8f0"}}
                                />
                                <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                                    {[<Cell key={entry.name} fill={entry.fill} /> for entry in priorityData]}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            )}
        </div>;
}

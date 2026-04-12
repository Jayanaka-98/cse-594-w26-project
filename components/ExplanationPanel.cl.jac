"""AI Scheduling Explanation Panel — hover/pin panel with 4 tabs and Accept/Reject."""

sv import from main { AIExplainSchedule, AIGetAlternativeSlots, UpdateTask }
import from "lucide-react" { Brain, Pin, PinOff, X, TrendingUp, Sparkles, Flag, Check, Pencil, ArrowLeft, Calendar, Zap }

def:pub ExplanationPanel(
    task: any,
    cachedData: any,
    onCached: any,
    onClose: any,
    onModify: any
) -> any {
    has activeTab: str = "workload",
        explanation: any = cachedData,
        loading: bool = (False if cachedData else True),
        isPinned: bool = False,
        showRejectionView: bool = False,
        altSlotsLoading: bool = False,
        alternativeSlots: list = [];

    can with entry {
        if cachedData {
            explanation = cachedData;
            loading = False;
        } elif task.ai_explanation and task.ai_explanation != "" {
            explanation = JSON.parse(task.ai_explanation);
            loading = False;
            if onCached { onCached(explanation); }
        } else {
            fetchExplanation();
        }
    }

    async def fetchExplanation {
        loading = True;
        result = root spawn AIExplainSchedule(task_id=task.id);
        if result.reports and result.reports[0] {
            d = result.reports[0];
            explanation = d;
            if onCached { onCached(d); }
        }
        loading = False;
    }

    async def fetchAlternatives {
        altSlotsLoading = True;
        result = root spawn AIGetAlternativeSlots(task_id=task.id);
        if result.reports and result.reports[0] {
            slots = result.reports[0]["slots"] if result.reports[0]["slots"] else [];
            alternativeSlots = slots;
        }
        altSlotsLoading = False;
    }

    async def handleFindBetterSlot {
        if len(alternativeSlots) == 0 and not altSlotsLoading {
            fetchAlternatives();
        }
    }

    async def applyAlternativeSlot(slot: any) {
        root spawn UpdateTask(
            task_id=task.id,
            title=task.title,
            description=(task.description if task.description else ""),
            status=(task.status if task.status else "todo"),
            priority=(task.priority if task.priority else "normal"),
            due_date=(task.due_date if task.due_date else ""),
            start_date=slot.start_date,
            start_time=slot.start_time,
            end_time=slot.end_time,
            estimated_duration=(task.estimated_duration if task.estimated_duration else 60),
            category=(task.category if task.category else "")
        );
        if onClose { onClose("reeval"); }
    }

    def formatTime(t: str) -> str {
        if not t or t == "" { return ""; }
        parts = t.split(":");
        h = parseInt(parts[0]);
        m = parts[1];
        suffix = "AM" if h < 12 else "PM";
        displayH = h if h <= 12 else h - 12;
        if h == 0 { displayH = 12; }
        return displayH.toString() + ":" + m + " " + suffix;
    }

    def formatDate(d: str) -> str {
        if not d or d == "" { return ""; }
        dt = Reflect.construct(Date, [d + "T12:00:00"]);
        days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return days[dt.getDay()] + ", " + months[dt.getMonth()] + " " + dt.getDate().toString();
    }

    def getFactorColor(score: int) -> str {
        if score >= 80 { return "factor-bar-green"; }
        if score >= 60 { return "factor-bar-blue"; }
        if score >= 40 { return "factor-bar-orange"; }
        return "factor-bar-purple";
    }

    def getConfidenceColor(score: int) -> str {
        if score >= 80 { return "#10b981"; }
        if score >= 60 { return "#6366f1"; }
        return "#f59e0b";
    }

    def getOverallConfidence(score: int) -> str {
        if score >= 80 { return "High"; }
        if score >= 60 { return "Medium"; }
        return "Low";
    }

    isAiOptimized = task.schedule_source == "ai_optimized";
    confidence = task.ai_confidence if task.ai_confidence else (explanation.productivity_score if explanation else 0);
    scheduledLabel = formatDate(task.start_date) + " · " + formatTime(task.start_time) if (task.start_date and task.start_time) else "Not scheduled";
    bestSlot = alternativeSlots[0] if len(alternativeSlots) > 0 else None;

    return
        <div className="exp-overlay" onClick={lambda e: any -> None { e.stopPropagation(); }}>
            <div className="exp-panel">

                <div className="exp-header">
                    <div className="exp-header-left">
                        <Brain size={22} className="exp-brain-icon" />
                        <div>
                            <div className="exp-header-title-row">
                                <span className="exp-title-label">AI Scheduling Explanation</span>
                                {(
                                    <span className="exp-pinned-badge"><Pin size={10} /> Pinned</span>
                                ) if isPinned else None}
                                {(
                                    <span className="exp-ai-optimized-badge"><Zap size={10} /> AI Optimized</span>
                                ) if isAiOptimized else None}
                            </div>
                            <div className="exp-task-name">{task.title}</div>
                        </div>
                    </div>
                    <div className="exp-header-actions">
                        <button
                            className="exp-pin-btn"
                            onClick={lambda -> None { isPinned = not isPinned; }}
                            title={("Unpin panel" if isPinned else "Pin panel")}
                        >
                            {(<Pin size={14} />) if isPinned else (<PinOff size={14} />)}
                        </button>
                        <button className="exp-close-btn" onClick={onClose}><X size={16} /></button>
                    </div>
                </div>

                <div className="exp-hero">
                    <div className="exp-confidence-ring" style={{"--conf-color": getConfidenceColor(confidence)}}>
                        <svg viewBox="0 0 60 60" className="exp-ring-svg">
                            <circle cx="30" cy="30" r="24" className="exp-ring-bg" />
                            <circle
                                cx="30" cy="30" r="24"
                                className="exp-ring-fill"
                                style={{
                                    strokeDasharray: (2 * 3.14159 * 24).toString(),
                                    strokeDashoffset: ((2 * 3.14159 * 24) * (1 - confidence / 100)).toString(),
                                    stroke: getConfidenceColor(confidence)
                                }}
                            />
                        </svg>
                        <div className="exp-ring-text">
                            <span className="exp-ring-pct">{confidence.toString() + "%"}</span>
                            <span className="exp-ring-label">conf.</span>
                        </div>
                    </div>
                    <div className="exp-hero-right">
                        <div className="exp-scheduled-slot">
                            <strong>Scheduled:</strong> {scheduledLabel}
                        </div>
                        <div className="exp-headline">
                            {(explanation.headline if explanation else "Analyzing scheduling decision...")}
                        </div>
                    </div>
                </div>

                {(
                    # ── Rejection view: 3 alternatives + keep as is ──
                    <div className="exp-rejection-view">
                        <div className="exp-rejected-banner">
                            <X size={16} className="exp-rejected-icon" />
                            <div>
                                <div className="exp-rejected-title">Choose a different slot</div>
                                <div className="exp-rejected-sub">Pick an AI-suggested alternative or keep the current slot.</div>
                            </div>
                        </div>
                        {(
                            <div className="exp-loading">
                                <div className="loading-spinner"></div>
                                <span>Finding alternatives...</span>
                            </div>
                        ) if altSlotsLoading else (
                            <div className="exp-alt-slots">
                                {[
                                    <button
                                        key={slot.start_date + slot.start_time}
                                        className="exp-alt-slot"
                                        onClick={lambda -> None { applyAlternativeSlot(slot); }}
                                    >
                                        <Calendar size={14} className="exp-alt-slot-icon" />
                                        <div className="exp-alt-slot-info">
                                            <div className="exp-alt-slot-date">{formatDate(slot.start_date) + " · " + formatTime(slot.start_time)}</div>
                                            <div className="exp-alt-slot-bar-wrap">
                                                <div className="exp-alt-slot-bar-fill" style={{"width": slot.productivity_score.toString() + "%"}}></div>
                                                <span className="exp-alt-slot-pct">{slot.productivity_score.toString() + "% productivity"}</span>
                                            </div>
                                        </div>
                                    </button>
                                    for slot in alternativeSlots
                                ]}
                                <button className="exp-keep-original" onClick={onClose}>
                                    <span className="exp-keep-icon">⏱</span>
                                    Keep current slot (no change)
                                </button>
                            </div>
                        )}
                        <button className="exp-back-btn" onClick={lambda -> None { showRejectionView = False; }}>
                            <ArrowLeft size={14} /> Back
                        </button>
                    </div>
                ) if showRejectionView else (
                    <div className="exp-loading">
                        <div className="loading-spinner"></div>
                        <span>Generating explanation...</span>
                    </div>
                ) if loading else (
                    <div>
                        <div className="exp-tabs">
                            {[
                                {"id": "workload", "label": "Workload"},
                                {"id": "deadline", "label": "Deadline"}
                            ].map(lambda tab: any -> any {
                                return
                                    <button
                                        key={tab.id}
                                        className={"exp-tab" + (" exp-tab-active" if activeTab == tab.id else "")}
                                        onClick={lambda -> None { activeTab = tab.id; }}
                                    >
                                        {tab.label}
                                    </button>;
                            })}
                        </div>

                        <div className="exp-tab-content">

                            {(
                                <div className="exp-tab-pane">
                                    <div className="exp-insight-card">
                                        <TrendingUp size={14} className="exp-trend-icon" />
                                        <p className="exp-insight-text">
                                            {explanation.workload_insight if explanation else ""}
                                        </p>
                                    </div>
                                    <div className="exp-score-row">
                                        <span className="exp-score-label">Productivity Score for This Slot</span>
                                        <span className="exp-score-num" style={{"color": getConfidenceColor(explanation.productivity_score if explanation else 0)}}>
                                            {(explanation.productivity_score if explanation else 0).toString() + "/100"}
                                        </span>
                                    </div>
                                    <div className="exp-score-bar-wrap">
                                        <div
                                            className="exp-score-bar-fill"
                                            style={{
                                                width: (explanation.productivity_score if explanation else 0).toString() + "%",
                                                background: getConfidenceColor(explanation.productivity_score if explanation else 0)
                                            }}
                                        ></div>
                                    </div>
                                    <div className="exp-tip-card">
                                        <Sparkles size={12} className="exp-tip-icon" />
                                        <span className="exp-tip-label">AI Tip</span>
                                        <p className="exp-tip-text">{explanation.tip if explanation else ""}</p>
                                    </div>
                                </div>
                            ) if activeTab == "workload" else None}

                            {(
                                <div className="exp-tab-pane">
                                    <div className="exp-duration-cards">
                                        <div className="exp-dur-card exp-dur-user">
                                            <span className="exp-dur-label">Your Estimate</span>
                                            <span className="exp-dur-value">
                                                {(Math.floor((explanation.user_estimated_duration if explanation else task.estimated_duration) / 60).toString() + "h " if (explanation.user_estimated_duration if explanation else task.estimated_duration) >= 60 else "") +
                                                 ((explanation.user_estimated_duration if explanation else task.estimated_duration) % 60).toString() + "m"}
                                            </span>
                                        </div>
                                        <div className="exp-dur-card exp-dur-ai">
                                            <span className="exp-dur-label">AI Adjusted</span>
                                            <span className="exp-dur-value exp-dur-ai-val">
                                                {(Math.floor((explanation.ai_adjusted_duration if explanation else task.estimated_duration) / 60).toString() + "h " if (explanation.ai_adjusted_duration if explanation else task.estimated_duration) >= 60 else "") +
                                                 ((explanation.ai_adjusted_duration if explanation else task.estimated_duration) % 60).toString() + "m"}
                                            </span>
                                            {(
                                                <span className="exp-dur-delta">
                                                    {"+" + ((explanation.ai_adjusted_duration - explanation.user_estimated_duration)).toString() + "m"}
                                                </span>
                                            ) if (explanation and explanation.ai_adjusted_duration > explanation.user_estimated_duration) else None}
                                        </div>
                                    </div>
                                    <div className="exp-insight-card">
                                        <p className="exp-insight-text">
                                            {explanation.duration_insight if explanation else ""}
                                        </p>
                                    </div>
                                    <div className="exp-accuracy-row">
                                        <span className="exp-accuracy-label">Historical Estimation Accuracy</span>
                                        <span className="exp-accuracy-pct" style={{"color": "#ef4444"}}>
                                            {(explanation.historical_accuracy_pct if explanation else 0).toString() + "%"}
                                        </span>
                                    </div>
                                    <div className="exp-score-bar-wrap">
                                        <div
                                            className="exp-score-bar-fill"
                                            style={{
                                                width: (explanation.historical_accuracy_pct if explanation else 0).toString() + "%",
                                                background: "#ef4444"
                                            }}
                                        ></div>
                                    </div>
                                    <div className="exp-tip-card">
                                        <Sparkles size={12} className="exp-tip-icon" />
                                        <span className="exp-tip-label">AI Tip</span>
                                        <p className="exp-tip-text">{explanation.tip if explanation else ""}</p>
                                    </div>
                                </div>
                            ) if activeTab == "duration" else None}

                            {(
                                <div className="exp-tab-pane">
                                    <div className="exp-insight-card">
                                        <Flag size={14} className="exp-trend-icon" />
                                        <p className="exp-insight-text">
                                            {explanation.deadline_insight if explanation else ""}
                                        </p>
                                    </div>
                                    {(
                                        <div className="exp-deadline-badge">
                                            <span>Due: {task.due_date}</span>
                                        </div>
                                    ) if task.due_date and task.due_date != "" else None}
                                    <div className="exp-tip-card">
                                        <Sparkles size={12} className="exp-tip-icon" />
                                        <span className="exp-tip-label">AI Tip</span>
                                        <p className="exp-tip-text">{explanation.tip if explanation else ""}</p>
                                    </div>
                                </div>
                            ) if activeTab == "deadline" else None}

                            {(
                                <div className="exp-tab-pane">
                                    <p className="exp-factors-intro">Factors weighted by AI to determine this scheduling decision:</p>
                                    <div className="exp-factors-list">
                                        {(explanation.factors if explanation else []).map(lambda f: any -> any {
                                            return
                                                <div key={f.factor} className="exp-factor-row">
                                                    <span className="exp-factor-name">{f.factor}</span>
                                                    <div className="exp-factor-bar-wrap">
                                                        <div
                                                            className={"exp-factor-bar " + getFactorColor(f.score)}
                                                            style={{width: f.score.toString() + "%"}}
                                                        ></div>
                                                    </div>
                                                    <span className="exp-factor-score">{f.score.toString() + "%"}</span>
                                                </div>;
                                        })}
                                    </div>
                                    <div className="exp-overall-row">
                                        <span className="exp-overall-label">Overall Decision Confidence</span>
                                        <span className="exp-overall-val" style={{"color": getConfidenceColor(confidence)}}>
                                            {getOverallConfidence(confidence)}
                                        </span>
                                    </div>
                                    <div className="exp-score-bar-wrap">
                                        <div
                                            className="exp-score-bar-fill"
                                            style={{
                                                width: confidence.toString() + "%",
                                                background: getConfidenceColor(confidence)
                                            }}
                                        ></div>
                                    </div>
                                    <div className="exp-tip-card">
                                        <Sparkles size={12} className="exp-tip-icon" />
                                        <span className="exp-tip-label">AI Tip</span>
                                        <p className="exp-tip-text">{explanation.tip if explanation else ""}</p>
                                    </div>
                                </div>
                            ) if activeTab == "factors" else None}

                        </div>
                    </div>
                )}

                <div className="exp-footer">
                    {(
                        # Suggestion loaded — show inline with Accept
                        <div>
                            <div className="exp-suggestion-bar">
                                <Zap size={13} className="exp-suggestion-icon" />
                                <div className="exp-suggestion-content">
                                    <span className="exp-suggestion-text">
                                        {formatDate(bestSlot.start_date) + " · " + formatTime(bestSlot.start_time) + " — " + str(bestSlot.productivity_score) + "% productivity"}
                                    </span>
                                    <span className="exp-suggestion-reason">{bestSlot.reasoning}</span>
                                </div>
                            </div>
                            <div className="exp-footer-actions">
                                <button
                                    className="exp-btn-accept"
                                    onClick={lambda { applyAlternativeSlot(bestSlot); }}
                                >
                                    <Check size={14} /> Accept
                                </button>
                                <button
                                    className="exp-btn-see-all"
                                    onClick={lambda { showRejectionView = True; }}
                                >
                                    See all options
                                </button>
                                {(
                                    <button className="exp-btn-modify" onClick={onModify}>
                                        <Pencil size={13} /> Modify
                                    </button>
                                ) if not isAiOptimized else None}
                            </div>
                        </div>
                    ) if bestSlot else (
                        # Fetching in progress
                        <div className="exp-footer-actions">
                            <button className="exp-btn-find-slot" disabled={True}>
                                <div className="loading-spinner loading-spinner-sm"></div>
                                Finding slots...
                            </button>
                        </div>
                    ) if altSlotsLoading else (
                        # Default — show Find Better Slot button
                        <div className="exp-footer-actions">
                            <button
                                className="exp-btn-find-slot"
                                onClick={lambda { handleFindBetterSlot(); }}
                            >
                                <Zap size={13} /> Find Better Slot
                            </button>
                            {(
                                <button className="exp-btn-modify" onClick={onModify}>
                                    <Pencil size={13} /> Modify
                                </button>
                            ) if not isAiOptimized else None}
                        </div>
                    )}
                </div>

            </div>
        </div>;
}

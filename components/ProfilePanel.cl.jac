"""User profile and settings panel for FlowBoard."""

sv import from main { GetUserPatterns, UpdateUserPatterns }
import from "lucide-react" { Moon, Sun, LayoutList, LayoutGrid, Check, X }

def:pub ProfilePanel(
    username: str,
    displayName: str,
    darkMode: bool,
    defaultView: str,
    onClose: any,
    onSave: any
) -> any {
    has editDisplayName: str = displayName,
        editTheme: str = ("dark" if darkMode else "light"),
        editDefaultView: str = defaultView,
        peaks: dict = {},
        overruns: dict = {},
        activeTab: str = "account";

    avatarLabel = displayName if displayName != "" else username;
    avatarInitial = avatarLabel[0].toUpperCase() if avatarLabel != "" else "?";

    can with entry {
        fetchPatterns();
    }

    async def fetchPatterns -> None {
        result = root spawn GetUserPatterns();
        if result.reports {
            p = result.reports[0];
            peaks = p.productivity_peaks;
            overruns = p.category_overrun_ratios;
        }
    }

    def setPeakScore(h: int, score: int) -> None {
        updated = {};
        for k in [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22] {
            key = k.toString();
            if k == h {
                updated[key] = score;
            } else {
                updated[key] = (peaks[key] if key in peaks else 0);
            }
        }
        peaks = updated;
    }

    def setOverrun(cat: str, pct: int) -> None {
        updated = {};
        for c in ["Research", "Coding", "Meeting", "Writing", "Admin", "Other"] {
            if c == cat {
                updated[c] = 1.0 + pct / 100.0;
            } else {
                updated[c] = (overruns[c] if c in overruns else 1.0);
            }
        }
        overruns = updated;
    }

    def formatHour(h: int) -> str {
        suffix = "am" if h < 12 else "pm";
        dh = h if h <= 12 else h - 12;
        if h == 0 { dh = 12; }
        return dh.toString() + suffix;
    }

    async def handleSave -> None {
        onSave(editDisplayName, editTheme, editDefaultView);
        root spawn UpdateUserPatterns(
            productivity_peaks=peaks,
            category_overrun_ratios=overruns
        );
    }

    return
        <div className="modal-overlay" onClick={onClose}>
            <div className="profile-modal" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                <div className="profile-header">
                    <h2 className="profile-title">Profile & Settings</h2>
                    <button onClick={onClose} className="btn-close">×</button>
                </div>

                <div className="profile-tabs">
                    <button
                        className={"profile-tab" + (" profile-tab-active" if activeTab == "account" else "")}
                        onClick={lambda -> None { activeTab = "account"; }}
                    >Account</button>
                    <button
                        className={"profile-tab" + (" profile-tab-active" if activeTab == "ai" else "")}
                        onClick={lambda -> None { activeTab = "ai"; }}
                    >AI Behavior</button>
                </div>

                <div className="profile-body">

                    {(
                        <div>
                            <div className="profile-avatar-section">
                                <div className="profile-avatar-lg">{avatarInitial}</div>
                                <div className="profile-user-info">
                                    <p className="profile-display-name">{(displayName if displayName != "" else username)}</p>
                                    <p className="profile-username">@{username}</p>
                                </div>
                            </div>
                            <div className="profile-divider"></div>
                            <div className="profile-section">
                                <h3 className="profile-section-title">Account</h3>
                                <div className="form-field">
                                    <label className="form-label">Display Name</label>
                                    <input
                                        type="text"
                                        value={editDisplayName}
                                        onChange={lambda e: any -> None { editDisplayName = e.target.value; }}
                                        placeholder={username}
                                        className="form-input"
                                    />
                                    <p className="form-hint">How your name appears in the app. Leave blank to use your username.</p>
                                </div>
                            </div>
                            <div className="profile-divider"></div>
                            <div className="profile-section">
                                <h3 className="profile-section-title">Appearance</h3>
                                <div className="form-field">
                                    <label className="form-label">Theme</label>
                                    <div className="theme-options">
                                        <button
                                            onClick={lambda -> None { editTheme = "dark"; }}
                                            className={("theme-option active" if editTheme == "dark" else "theme-option")}
                                        >
                                            <Moon size={14} className="theme-option-icon" />
                                            <span className="theme-option-label">Dark</span>
                                            {(<Check size={12} className="theme-option-check" />) if editTheme == "dark" else None}
                                        </button>
                                        <button
                                            onClick={lambda -> None { editTheme = "light"; }}
                                            className={("theme-option active" if editTheme == "light" else "theme-option")}
                                        >
                                            <Sun size={14} className="theme-option-icon" />
                                            <span className="theme-option-label">Light</span>
                                            {(<Check size={12} className="theme-option-check" />) if editTheme == "light" else None}
                                        </button>
                                    </div>
                                </div>
                            </div>
                            <div className="profile-divider"></div>
                            <div className="profile-section">
                                <h3 className="profile-section-title">Defaults</h3>
                                <div className="form-field">
                                    <label className="form-label">Default Task View</label>
                                    <div className="view-options">
                                        <button
                                            onClick={lambda -> None { editDefaultView = "list"; }}
                                            className={("view-option active" if editDefaultView == "list" else "view-option")}
                                        >
                                            <LayoutList size={14} className="view-option-icon" />
                                            <span>List</span>
                                            {(<Check size={12} className="theme-option-check" />) if editDefaultView == "list" else None}
                                        </button>
                                        <button
                                            onClick={lambda -> None { editDefaultView = "board"; }}
                                            className={("view-option active" if editDefaultView == "board" else "view-option")}
                                        >
                                            <LayoutGrid size={14} className="view-option-icon" />
                                            <span>Board</span>
                                            {(<Check size={12} className="theme-option-check" />) if editDefaultView == "board" else None}
                                        </button>
                                    </div>
                                    <p className="form-hint">New lists will open in this view by default.</p>
                                </div>
                            </div>
                        </div>
                    ) if activeTab == "account" else None}

                    {(
                        <div>
                            <div className="profile-section">
                                <h3 className="profile-section-title">Peak Productivity Hours</h3>
                                <p className="profile-ai-hint">
                                    Tell the AI when you work best. It will prefer scheduling tasks in high-score hours.
                                    Drag the sliders to set your energy level for each hour (0 = low, 100 = peak).
                                </p>
                                <div className="pref-peaks-grid">
                                    {[
                                        <div key={h} className="pref-peak-row">
                                            <span className="pref-peak-hour">{formatHour(h)}</span>
                                            <input
                                                type="range"
                                                min={0}
                                                max={100}
                                                step={5}
                                                value={(peaks[h.toString()] if h.toString() in peaks else 0)}
                                                onChange={lambda e: any -> None { setPeakScore(h, parseInt(e.target.value)); }}
                                                className="pref-peak-slider"
                                            />
                                            <span className="pref-peak-score">{(peaks[h.toString()] if h.toString() in peaks else 0).toString()}</span>
                                        </div>
                                        for h in [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
                                    ]}
                                </div>
                            </div>
                            <div className="profile-divider"></div>
                            <div className="profile-section">
                                <h3 className="profile-section-title">AI Duration Buffer by Category</h3>
                                <p className="profile-ai-hint">
                                    How much extra time should the AI add to your estimates per category?
                                    Based on your history, but you can override it.
                                </p>
                                <div className="pref-overrun-list">
                                    {[
                                        <div key={cat} className="pref-overrun-row">
                                            <span className="pref-overrun-cat">{cat}</span>
                                            <input
                                                type="range"
                                                min={0}
                                                max={100}
                                                step={5}
                                                value={Math.round(((overruns[cat] if cat in overruns else 1.0) - 1.0) * 100)}
                                                onChange={lambda e: any -> None { setOverrun(cat, parseInt(e.target.value)); }}
                                                className="pref-peak-slider"
                                            />
                                            <span className="pref-overrun-pct">
                                                {"+" + Math.round(((overruns[cat] if cat in overruns else 1.0) - 1.0) * 100).toString() + "%"}
                                            </span>
                                        </div>
                                        for cat in ["Research", "Coding", "Meeting", "Writing", "Admin", "Other"]
                                    ]}
                                </div>
                            </div>
                        </div>
                    ) if activeTab == "ai" else None}

                </div>
                <div className="profile-footer">
                    <button onClick={onClose} className="btn-secondary">Cancel</button>
                    <button onClick={lambda -> None { handleSave(); }} className="btn-primary">
                        Save Settings
                    </button>
                </div>
            </div>
        </div>;
}

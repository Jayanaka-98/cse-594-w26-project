"""User profile and settings panel for FlowBoard."""

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
        editDefaultView: str = defaultView;

    avatarLabel = displayName if displayName != "" else username;
    avatarInitial = (avatarLabel[0].toUpperCase() if avatarLabel != "" else "?");

    def handleSave -> None {
        onSave(editDisplayName, editTheme, editDefaultView);
    }

    return
        <div className="modal-overlay" onClick={onClose}>
            <div className="profile-modal" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                <div className="profile-header">
                    <h2 className="profile-title">Profile & Settings</h2>
                    <button onClick={onClose} className="btn-close">×</button>
                </div>
                <div className="profile-body">
                    <div className="profile-avatar-section">
                        <div className="profile-avatar-lg">
                            {avatarInitial}
                        </div>
                        <div className="profile-user-info">
                            <p className="profile-display-name">
                                {(displayName if displayName != "" else username)}
                            </p>
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
                            <p className="form-hint">
                                How your name appears in the app. Leave blank to use your username.
                            </p>
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
                                    <span className="theme-option-icon">🌙</span>
                                    <span className="theme-option-label">Dark</span>
                                    {(
                                        <span className="theme-option-check">✓</span>
                                    ) if editTheme == "dark" else None}
                                </button>
                                <button
                                    onClick={lambda -> None { editTheme = "light"; }}
                                    className={("theme-option active" if editTheme == "light" else "theme-option")}
                                >
                                    <span className="theme-option-icon">☀️</span>
                                    <span className="theme-option-label">Light</span>
                                    {(
                                        <span className="theme-option-check">✓</span>
                                    ) if editTheme == "light" else None}
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
                                    <span className="view-option-icon">≡</span>
                                    <span>List</span>
                                    {(
                                        <span className="theme-option-check">✓</span>
                                    ) if editDefaultView == "list" else None}
                                </button>
                                <button
                                    onClick={lambda -> None { editDefaultView = "board"; }}
                                    className={("view-option active" if editDefaultView == "board" else "view-option")}
                                >
                                    <span className="view-option-icon">⊞</span>
                                    <span>Board</span>
                                    {(
                                        <span className="theme-option-check">✓</span>
                                    ) if editDefaultView == "board" else None}
                                </button>
                            </div>
                            <p className="form-hint">
                                New lists will open in this view by default.
                            </p>
                        </div>
                    </div>
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

"""Authentication form component for FlowBoard."""

def:pub AuthForm(
    isSignup: bool,
    username: str,
    password: str,
    error: str,
    loading: bool,
    onUsernameChange: any,
    onPasswordChange: any,
    onSubmit: any,
    onToggleMode: any
) -> any {
    return
        <div className="auth-container">
            <div className="auth-card">
                <div className="auth-header">
                    <div className="auth-logo">⚡</div>
                    <h1 className="auth-title">FlowBoard</h1>
                    <p className="auth-subtitle">
                        {("Create your account" if isSignup else "Sign in to continue")}
                    </p>
                </div>
                {(
                    <div className="auth-error">
                        {error}
                    </div>
                ) if error else None}
                <form onSubmit={onSubmit} className="auth-form">
                    <div className="form-field">
                        <label className="form-label">Username</label>
                        <input
                            type="text"
                            value={username}
                            onChange={onUsernameChange}
                            placeholder="Enter username"
                            className="form-input"
                            autoComplete="username"
                        />
                    </div>
                    <div className="form-field">
                        <label className="form-label">Password</label>
                        <input
                            type="password"
                            value={password}
                            onChange={onPasswordChange}
                            placeholder="Enter password"
                            className="form-input"
                            autoComplete={(
                                "new-password" if isSignup else "current-password"
                            )}
                        />
                    </div>
                    <button
                        type="submit"
                        disabled={loading}
                        className="auth-submit"
                    >
                        {(
                            "Processing..."
                            if loading
                            else ("Create Account" if isSignup else "Sign In")
                        )}
                    </button>
                </form>
                <div className="auth-toggle">
                    <span className="auth-toggle-text">
                        {(
                            "Already have an account? "
                            if isSignup
                            else "Don't have an account? "
                        )}
                    </span>
                    <button
                        type="button"
                        onClick={onToggleMode}
                        className="auth-toggle-btn"
                    >
                        {("Sign In" if isSignup else "Sign Up")}
                    </button>
                </div>
            </div>
        </div>;
}

"""
py2app build script for FlowBoard Activity Tracker.

Usage:
    pip install py2app
    python setup.py py2app

Output: dist/FlowBoard Activity Tracker.app
Then wrap in a .dmg with:
    brew install create-dmg
    create-dmg \
        --volname "FlowBoard Activity Tracker" \
        --window-size 600 400 \
        --icon-size 128 \
        --app-drop-link 450 185 \
        "FlowBoard Activity Tracker.dmg" \
        "dist/"
"""

from setuptools import setup

APP = ["widget.py"]

OPTIONS = {
    # argv_emulation: let the app respond to Apple Events (needed for proper
    # menu bar lifecycle under py2app)
    "argv_emulation": True,
    "plist": {
        # App metadata shown in About box / Spotlight
        "CFBundleName": "FlowBoard Activity Tracker",
        "CFBundleDisplayName": "FlowBoard Activity Tracker",
        "CFBundleIdentifier": "com.flowboard.activity-tracker",
        "CFBundleVersion": "1.0.0",
        "CFBundleShortVersionString": "1.0",
        # LSUIElement=True: menu-bar-only app — no dock icon, no app switcher entry
        "LSUIElement": True,
        # Allow high-DPI rendering on Retina displays
        "NSHighResolutionCapable": True,
        # Explain why we capture the screen (required by macOS privacy prompts)
        "NSScreenCaptureUsageDescription": (
            "FlowBoard needs to take periodic screenshots to check whether "
            "you are on task. Screenshots are sent to your local FlowBoard "
            "server and are never stored permanently."
        ),
        # Suppress the quarantine dialog for local development builds
        "NSAppleEventsUsageDescription": "FlowBoard uses Apple Events for notifications.",
    },
    # Bundle these packages into the app so no system Python is required
    "packages": ["rumps", "requests", "certifi", "charset_normalizer", "idna", "urllib3"],
    # Exclude heavyweight packages that might get auto-included
    "excludes": ["tkinter", "test", "unittest"],
}

setup(
    name="FlowBoard Activity Tracker",
    app=APP,
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
)

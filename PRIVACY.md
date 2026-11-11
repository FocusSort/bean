# Privacy

**Bean collects nothing.** It has no accounts, analytics, advertising or tracking code, and it never connects to the internet. The App Sandbox enforces this: the app has no network entitlement.

- **What stays on your Mac.** Only your preferences: which keep-awake options you chose, whether a session is timed, and the number of minutes. They are stored in Bean's private sandbox container, and deleting the app removes them.
- **How keeping awake works.** Bean asks macOS directly for power assertions through Apple's public IOKit API. They end when you press Stop, when the timer runs out, or when you quit. macOS also drops them if the app ever exits unexpectedly.
- **Launch at Login.** It is off until you turn it on. When on, macOS records the choice in System Settings › General › Login Items.

The same policy is shown inside the app under **Privacy**.

# VoicePi iOS Keyboard Spike Validation Checklist (Updated 2026-04-30)

This document tracks the validation of the Phase 0 Technical Spike.
**Update:** Per @pi-dal's decision, v1 will focus on **"Waveform/Duration Preview + Final-only ASR"**. Real-time streaming text preview is moved to "Future Investigation".

## 1. Validation Matrix (Host Environments)

| Host App | Scenario | Focus | Result |
| :--- | :--- | :--- | :--- |
| Safari (Web) | Google Search / Form field | Focus retention, `textDocumentProxy` stability | TBD |
| WeChat / Slack | Chat input field | Custom UI text field handling | TBD |
| Notes App | Long text dictation | Memory growth over 60s recording | TBD |
| Spotlight Search | Quick trigger | Lifecycle speed (viewWillAppear) | TBD |

## 2. Technical Stability Checklist

### Audio & Interruptions
- [ ] Incoming Call: Does recording stop gracefully? Can we resume?
- [ ] Music Playing: Does `AVAudioSession` mix correctly or pause/resume as expected?
- [ ] Mic Permission: Does the app handle "Denied" or "Restricted" state without crashing?

### Memory & Performance (OOM Guard)
- [ ] Idle Memory: Check baseline RSS. (Target: < 20MB)
- [ ] Active Recording Memory: Check peak RSS during 30s capture. (Target: < 50MB)
- [ ] Long Recording Stress Test: Capture for 120s. Does system kill the extension? **(Critical)**

### Connectivity & ASR
- [x] ASR Mode: **Final-only path accepted** for v1.
- [ ] Final Text Commit: Does the text insert exactly at the cursor position?
- [ ] Context Loss: What happens if the user dismisses the keyboard mid-request?

## 3. Validation Log

| Date | Tester | Target Task | Findings / Blockers |
| :--- | :--- | :--- | :--- |
| 2026-04-30 | Abraxas | Initial Setup | Checklist defined. |
| 2026-04-30 | Abraxas | Scope Alignment | Updated checklist to reflect Final-only ASR decision. Partial preview moved to future roadmap. |

## 4. Manual Test Scripts (Step-by-Step)

### Script A: Audio Interruption (Incoming Call)
1.  **Start** recording on the VoicePi Keyboard.
2.  **Trigger** an incoming phone call to the device.
3.  **Decline** the call and return to the original app.
4.  **Verify**:
    *   Keyboard state has reset to `idle`.
    *   No partial audio or failed ASR request is hanging.
    *   Preview bar is clear.

### Script B: Cross-App Context Switching
1.  Open **Messages** app, tap input field, start VoicePi recording.
2.  **Speak** a short sentence, then tap **Stop**.
3.  While in `readyToCommit` state, **Switch** to **Safari**.
4.  Tap a search field in Safari.
5.  Tap **Commit** on the VoicePi Keyboard.
6.  **Verify**: Text is inserted into the Safari search field (the currently active `textDocumentProxy`).

### Script C: Memory Pressure Test
1.  Open **Notes** app.
2.  Start recording and **Speak** continuously for 90 seconds.
3.  Monitor RSS via the (future) Debug Overlay or Instruments.
4.  **Verify**: 
    *   Extension does not crash.
    *   Memory stays stable after the 10MB buffer limit is reached.

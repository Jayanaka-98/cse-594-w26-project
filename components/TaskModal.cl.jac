"""Task creation modal component with audio mode and AI duration estimation."""

sv import from main { AIExtractTaskFromTranscript, AIEstimateDuration }
import from "lucide-react" { Mic, Square, X }

def:pub TaskModal(
    listId: str,
    onClose: any,
    onCreate: any
) -> any {
    has title: str = "",
        description: str = "",
        status: str = "todo",
        priority: str = "normal",
        dueDate: str = "",
        startDate: str = "",
        startTime: str = "",
        endTime: str = "",
        category: str = "",
        estimatedDuration: int = 60,
        aiSuggestedMinutes: int = 0,
        aiSuggestedRationale: str = "",
        aiSuggestedConfidence: int = 0,
        isEstimating: bool = False,
        isRecording: bool = False,
        isProcessingAudio: bool = False,
        audioError: str = "",
        audioTranscript: str = "",
        recognizerRef: any = None;

    def handleSubmit -> None {
        if not title.trim() { return; }
        onCreate(title, description, status, priority, dueDate, "", startDate, startTime, endTime, category, estimatedDuration);
        onClose();
    }

    async def fetchAIDuration -> None {
        if not title.trim() or category == "" { return; }
        isEstimating = True;
        result = root spawn AIEstimateDuration(task_title=title, category=category);
        if result.reports {
            d = result.reports[0];
            aiSuggestedMinutes = d.suggested_minutes;
            aiSuggestedRationale = d.rationale;
            aiSuggestedConfidence = d.confidence_pct;
        }
        isEstimating = False;
    }

    def handleKeyPress(e: any) -> None {
        if e.key == "Enter" and not e.shiftKey { handleSubmit(); }
    }

    async def processTranscript(transcript: str) -> None {
        audioTranscript = transcript;
        isProcessingAudio = True;
        result = root spawn AIExtractTaskFromTranscript(transcript=transcript);
        if result.reports {
            data = result.reports[0];
            title = data.title if data.title else title;
            description = data.description if data.description else description;
            status = data.status if data.status else status;
            priority = data.priority if data.priority else priority;
            dueDate = data.due_date if data.due_date else dueDate;
        }
        isProcessingAudio = False;
    }

    def startRecording -> None {
        audioError = "";
        audioTranscript = "";
        SpeechRecognitionAPI = window.SpeechRecognition or window.webkitSpeechRecognition;
        if not SpeechRecognitionAPI {
            audioError = "Speech recognition not supported in this browser";
            return;
        }
        rec = Reflect.construct(SpeechRecognitionAPI, []);
        rec.continuous = False;
        rec.interimResults = False;
        rec.lang = "en-US";
        rec.onresult = lambda e: any -> None {
            t = e.results[0][0].transcript;
            processTranscript(t);
        };
        rec.onerror = lambda e: any -> None {
            audioError = "Could not record: " + e.error;
            isRecording = False;
        };
        rec.onend = lambda -> None {
            isRecording = False;
        };
        rec.start();
        recognizerRef = rec;
        isRecording = True;
    }

    def stopRecording -> None {
        if recognizerRef { recognizerRef.stop(); }
        isRecording = False;
    }

    return
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal-box modal-task" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                <div className="modal-header">
                    <h3 className="modal-title">New Task</h3>
                    <button onClick={onClose} className="btn-close"><X size={16} /></button>
                </div>
                <div className="modal-body">
                    <div className="form-field">
                        <div className="audio-input-row">
                            <input
                                type="text"
                                value={title}
                                onChange={lambda e: any -> None { title = e.target.value; }}
                                onKeyPress={handleKeyPress}
                                placeholder="Task title"
                                className="form-input task-title-input"
                                autoFocus={True}
                            />
                            {(
                                <button
                                    onClick={lambda -> None { stopRecording(); }}
                                    className="btn-mic recording"
                                    title="Stop recording"
                                    disabled={isProcessingAudio}
                                >
                                    <Square size={14} />
                                </button>
                            ) if isRecording else (
                                <button
                                    onClick={lambda -> None { startRecording(); }}
                                    className="btn-mic"
                                    title="Dictate task via voice"
                                    disabled={isProcessingAudio}
                                >
                                    <Mic size={14} />
                                </button>
                            )}
                        </div>
                        {(
                            <div className="audio-status">
                                {(
                                    <span className="audio-status-recording"><span className="audio-rec-dot"></span> Listening...</span>
                                ) if isRecording else (
                                    <span className="audio-status-processing">
                                        <span className="audio-spinner"></span>
                                        Extracting task details...
                                    </span>
                                ) if isProcessingAudio else None}
                            </div>
                        ) if isRecording or isProcessingAudio else None}
                        {(
                            <div className="audio-error">{audioError}</div>
                        ) if audioError != "" else None}
                        {(
                            <div className="audio-transcript">
                                Heard: <em>{audioTranscript}</em>
                            </div>
                        ) if audioTranscript != "" and not isProcessingAudio else None}
                    </div>
                    <div className="form-field">
                        <textarea
                            value={description}
                            onChange={lambda e: any -> None { description = e.target.value; }}
                            placeholder="Description (optional)"
                            className="form-textarea"
                            rows={3}
                        />
                    </div>
                    <div className="form-row">
                        <div className="form-field form-field-half">
                            <label className="form-label">Category</label>
                            <select
                                value={category}
                                onChange={lambda e: any -> None { category = e.target.value; }}
                                onBlur={lambda -> None { fetchAIDuration(); }}
                                className="form-select"
                            >
                                <option value="">— select —</option>
                                <option value="Research">Research</option>
                                <option value="Coding">Coding</option>
                                <option value="Meeting">Meeting</option>
                                <option value="Writing">Writing</option>
                                <option value="Admin">Admin</option>
                                <option value="Other">Other</option>
                            </select>
                        </div>
                        <div className="form-field form-field-half">
                            <label className="form-label">Est. Duration (min)</label>
                            <input
                                type="number"
                                value={estimatedDuration}
                                onChange={lambda e: any -> None { estimatedDuration = parseInt(e.target.value) if e.target.value else 0; }}
                                className="form-input"
                                min={1}
                            />
                            {(
                                <div className="ai-duration-suggestion">
                                    {(
                                        <span className="ai-duration-loading">AI estimating...</span>
                                    ) if isEstimating else (
                                        <span
                                            className="ai-duration-badge"
                                            title={aiSuggestedRationale}
                                            onClick={lambda -> None { estimatedDuration = aiSuggestedMinutes; }}
                                        >
                                            AI suggests: {aiSuggestedMinutes.toString()} min ({aiSuggestedConfidence.toString()}% conf) — click to use
                                        </span>
                                    )}
                                </div>
                            ) if isEstimating or aiSuggestedMinutes > 0 else None}
                        </div>
                    </div>
                    <div className="form-row">
                        <div className="form-field form-field-half">
                            <label className="form-label">Status</label>
                            <select
                                value={status}
                                onChange={lambda e: any -> None { status = e.target.value; }}
                                className="form-select"
                            >
                                <option value="todo">Todo</option>
                                <option value="in_progress">In Progress</option>
                                <option value="review">Review</option>
                                <option value="done">Done</option>
                            </select>
                        </div>
                        <div className="form-field form-field-half">
                            <label className="form-label">Priority</label>
                            <select
                                value={priority}
                                onChange={lambda e: any -> None { priority = e.target.value; }}
                                className="form-select"
                            >
                                <option value="urgent">Urgent</option>
                                <option value="high">High</option>
                                <option value="normal">Normal</option>
                                <option value="low">Low</option>
                            </select>
                        </div>
                    </div>
                    <div className="form-field">
                        <label className="form-label">Due Date</label>
                        <input
                            type="date"
                            value={dueDate}
                            onChange={lambda e: any -> None { dueDate = e.target.value; }}
                            className="form-input"
                        />
                    </div>
                    <div className="form-field">
                        <label className="form-label">Schedule (optional)</label>
                        <div className="form-row">
                            <div className="form-field form-field-third">
                                <label className="form-label-sm">Date</label>
                                <input
                                    type="date"
                                    value={startDate}
                                    onChange={lambda e: any -> None { startDate = e.target.value; }}
                                    className="form-input"
                                />
                            </div>
                            <div className="form-field form-field-third">
                                <label className="form-label-sm">Start Time</label>
                                <input
                                    type="time"
                                    value={startTime}
                                    onChange={lambda e: any -> None { startTime = e.target.value; }}
                                    className="form-input"
                                />
                            </div>
                            <div className="form-field form-field-third">
                                <label className="form-label-sm">End Time</label>
                                <input
                                    type="time"
                                    value={endTime}
                                    onChange={lambda e: any -> None { endTime = e.target.value; }}
                                    className="form-input"
                                />
                            </div>
                        </div>
                    </div>
                </div>
                <div className="modal-footer">
                    <button onClick={onClose} className="btn-secondary">Cancel</button>
                    <button
                        onClick={lambda -> None { handleSubmit(); }}
                        className="btn-primary"
                        disabled={title.trim() == "" or isProcessingAudio}
                    >
                        Create Task
                    </button>
                </div>
            </div>
        </div>;
}

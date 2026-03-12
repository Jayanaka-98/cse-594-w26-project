"""Global task creation modal with inline space and list selection/creation."""

sv import from main { ListSpaces, ListLists, CreateSpace, CreateList, CreateTask, AIExtractTaskFromTranscript, AIEstimateDuration }
import from "lucide-react" { Mic, Square, X }

def:pub GlobalTaskModal(
    onClose: any,
    onCreated: any
) -> any {
    has selectedSpaceId: str = "",
        selectedListId: str = "",
        spaces: list = [],
        lists: list = [],

        showNewSpace: bool = False,
        newSpaceName: str = "",
        newSpaceColor: str = "purple",

        showNewList: bool = False,
        newListName: str = "",

        title: str = "",
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

    can with entry {
        fetchSpaces();
        fetchAllLists();
    }

    async def fetchSpaces -> None {
        result = root spawn ListSpaces();
        spaces = result.reports[0] if result.reports else [];
        if spaces.length == 1 {
            selectedSpaceId = spaces[0].id;
        }
    }

    async def fetchAllLists -> None {
        result = root spawn ListLists(space_id="");
        lists = result.reports[0] if result.reports else [];
    }

    async def handleCreateSpace -> None {
        if not newSpaceName.trim() { return; }
        result = root spawn CreateSpace(name=newSpaceName, color=newSpaceColor);
        if result.reports {
            s = result.reports[0];
            spaces = spaces.concat([{
                "id": s.id,
                "name": s.name,
                "color": s.color,
                "description": s.description
            }]);
            selectedSpaceId = s.id;
            selectedListId = "";
        }
        newSpaceName = "";
        newSpaceColor = "purple";
        showNewSpace = False;
    }

    async def handleCreateList -> None {
        if not newListName.trim() or selectedSpaceId == "" { return; }
        result = root spawn CreateList(name=newListName, space_id=selectedSpaceId);
        if result.reports {
            l = result.reports[0];
            lists = lists.concat([{
                "id": l.id,
                "name": l.name,
                "space_id": l.space_id,
                "color": l.color
            }]);
            selectedListId = l.id;
        }
        newListName = "";
        showNewList = False;
    }

    async def handleSubmit -> None {
        if not title.trim() or selectedListId == "" { return; }
        root spawn CreateTask(
            title=title,
            description=description,
            status=status,
            priority=priority,
            due_date=dueDate,
            list_id=selectedListId,
            parent_task_id="",
            start_date=startDate,
            start_time=startTime,
            end_time=endTime,
            category=category,
            estimated_duration=estimatedDuration
        );
        onCreated();
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

    filteredLists = (
        lists.filter(lambda l: any -> bool { return l.space_id == selectedSpaceId; })
        if selectedSpaceId != ""
        else []
    );

    return
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal-box modal-global-task" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                <div className="modal-header">
                    <h3 className="modal-title">New Task</h3>
                    <button onClick={onClose} className="btn-close"><X size={16} /></button>
                </div>
                <div className="modal-body">

                    <div className="gtm-location-section">
                        <div className="form-field">
                            <label className="form-label">Space</label>
                            <div className="gtm-select-row">
                                <select
                                    value={selectedSpaceId}
                                    onChange={lambda e: any -> None {
                                        selectedSpaceId = e.target.value;
                                        selectedListId = "";
                                        showNewList = False;
                                    }}
                                    className="form-select"
                                >
                                    <option value="">— select space —</option>
                                    {[
                                        <option key={s.id} value={s.id}>{s.name}</option>
                                        for s in spaces
                                    ]}
                                </select>
                                <button
                                    onClick={lambda -> None { showNewSpace = not showNewSpace; showNewList = False; }}
                                    className={"btn-outline btn-sm" + (" active" if showNewSpace else "")}
                                    title="Create a new space"
                                >
                                    + New
                                </button>
                            </div>
                            {(
                                <div className="inline-create-form">
                                    <input
                                        type="text"
                                        value={newSpaceName}
                                        onChange={lambda e: any -> None { newSpaceName = e.target.value; }}
                                        placeholder="Space name"
                                        className="form-input"
                                        autoFocus={True}
                                        onKeyPress={lambda e: any -> None { if e.key == "Enter" { handleCreateSpace(); } }}
                                    />
                                    <div className="color-picker">
                                        {[
                                            <button
                                                key={c}
                                                className={("color-dot color-" + c + (" selected" if c == newSpaceColor else ""))}
                                                onClick={lambda -> None { newSpaceColor = c; }}
                                                title={c}
                                            /> for c in ["purple", "blue", "green", "red", "orange", "pink"]
                                        ]}
                                    </div>
                                    <div className="inline-create-actions">
                                        <button
                                            onClick={lambda -> None { handleCreateSpace(); }}
                                            className="btn-primary btn-sm"
                                            disabled={newSpaceName.trim() == ""}
                                        >
                                            Create Space
                                        </button>
                                        <button
                                            onClick={lambda -> None { showNewSpace = False; newSpaceName = ""; }}
                                            className="btn-secondary btn-sm"
                                        >
                                            Cancel
                                        </button>
                                    </div>
                                </div>
                            ) if showNewSpace else None}
                        </div>

                        <div className="form-field">
                            <label className="form-label">List</label>
                            <div className="gtm-select-row">
                                <select
                                    value={selectedListId}
                                    onChange={lambda e: any -> None { selectedListId = e.target.value; }}
                                    className="form-select"
                                    disabled={selectedSpaceId == ""}
                                >
                                    <option value="">
                                        {("— select list —" if selectedSpaceId != "" else "— select a space first —")}
                                    </option>
                                    {[
                                        <option key={l.id} value={l.id}>{l.name}</option>
                                        for l in filteredLists
                                    ]}
                                </select>
                                <button
                                    onClick={lambda -> None { showNewList = not showNewList; showNewSpace = False; }}
                                    className={"btn-outline btn-sm" + (" active" if showNewList else "")}
                                    disabled={selectedSpaceId == ""}
                                    title="Create a new list"
                                >
                                    + New
                                </button>
                            </div>
                            {(
                                <div className="inline-create-form">
                                    <input
                                        type="text"
                                        value={newListName}
                                        onChange={lambda e: any -> None { newListName = e.target.value; }}
                                        placeholder="List name"
                                        className="form-input"
                                        autoFocus={True}
                                        onKeyPress={lambda e: any -> None { if e.key == "Enter" { handleCreateList(); } }}
                                    />
                                    <div className="inline-create-actions">
                                        <button
                                            onClick={lambda -> None { handleCreateList(); }}
                                            className="btn-primary btn-sm"
                                            disabled={newListName.trim() == ""}
                                        >
                                            Create List
                                        </button>
                                        <button
                                            onClick={lambda -> None { showNewList = False; newListName = ""; }}
                                            className="btn-secondary btn-sm"
                                        >
                                            Cancel
                                        </button>
                                    </div>
                                </div>
                            ) if showNewList else None}
                        </div>
                    </div>

                    <div className="form-field">
                        <div className="audio-input-row">
                            <input
                                type="text"
                                value={title}
                                onChange={lambda e: any -> None { title = e.target.value; }}
                                placeholder="Task title"
                                className="form-input task-title-input"
                                autoFocus={not showNewSpace and not showNewList}
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
                            rows={2}
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
                                <label className="form-label-sm">Start</label>
                                <input
                                    type="time"
                                    value={startTime}
                                    onChange={lambda e: any -> None { startTime = e.target.value; }}
                                    className="form-input"
                                />
                            </div>
                            <div className="form-field form-field-third">
                                <label className="form-label-sm">End</label>
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
                        disabled={title.trim() == "" or selectedListId == "" or isProcessingAudio}
                    >
                        Create Task
                    </button>
                </div>
            </div>
        </div>;
}

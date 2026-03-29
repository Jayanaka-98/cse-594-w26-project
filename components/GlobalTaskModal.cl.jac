"""Global task creation modal with list selection/creation."""

sv import from main { ListLists, CreateList, CreateTask }
import from "lucide-react" { Mic, Square, X }

def:pub GlobalTaskModal(
    onClose: any,
    onCreated: any
) -> any {
    has selectedListId: str = "",
        lists: list = [],

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

        isRecording: bool = False,
        isProcessingAudio: bool = False,
        audioError: str = "",
        audioTranscript: str = "",
        recognizerRef: any = None;

    can with entry {
        fetchAllLists();
    }

    async def fetchAllLists -> None {
        result = root spawn ListLists(space_id="");
        lists = result.reports[0] if result.reports else [];
        if len(lists) == 1 {
            selectedListId = lists[0].id;
        }
    }

    async def handleCreateList -> None {
        if not newListName.trim() { return; }
        result = root spawn CreateList(name=newListName, space_id="");
        if result.reports {
            l = result.reports[0];
            lists = lists.concat([{
                "id": l.id,
                "name": l.name,
                "space_id": "",
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

    async def processTranscript(transcript: str) -> None {
        audioTranscript = transcript;
        title = transcript;
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
            <div className="modal-box modal-global-task" onClick={lambda e: any -> None { e.stopPropagation(); }}>
                <div className="modal-header">
                    <h3 className="modal-title">New Task</h3>
                    <button onClick={onClose} className="btn-close"><X size={16} /></button>
                </div>
                <div className="modal-body">

                    <div className="gtm-location-section">
                        <div className="form-field">
                            <label className="form-label">List</label>
                            <div className="gtm-select-row">
                                <select
                                    value={selectedListId}
                                    onChange={lambda e: any -> None { selectedListId = e.target.value; }}
                                    className="form-select"
                                >
                                    <option value="">— select list —</option>
                                    {[
                                        <option key={l.id} value={l.id}>{l.name}</option>
                                        for l in lists
                                    ]}
                                </select>
                                <button
                                    onClick={lambda -> None { showNewList = not showNewList; }}
                                    className={"btn-outline btn-sm" + (" active" if showNewList else "")}
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
                                autoFocus={not showNewList}
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

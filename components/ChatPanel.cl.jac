"""Conversational AI chat panel for agentic task management."""

sv import from main { AgentChat, AgentCheckReady, AgentExecuteCreate, AgentExecuteUpdate, AgentExecuteDelete, ListChatHistory, ClearChatHistory, AIOptimizeSchedule, ApplyReplanChanges }
import from "lucide-react" { MessageSquare, Send, X, Check, XCircle, Trash2, Bot, User, Search, ChevronDown, ChevronRight }
import from "react-markdown" { default as Markdown }

def:pub ChatPanel(
    onTasksChanged: any
) -> any {
    has isOpen: bool = False,
        messages: list = [],
        inputText: str = "",
        loading: bool = False,
        pendingAction: dict = {},
        historyLoaded: bool = False,
        toolLogs: dict = {},
        expandedLogs: dict = {};

    can with [isOpen] entry {
        if isOpen and not historyLoaded {
            fetchHistory();
        }
    }

    can with [messages] entry {
        scrollToBottom();
    }

    def scrollToBottom -> None {
        setTimeout(lambda -> None {
            el = document.querySelector(".chat-messages");
            if el { el.scrollTop = el.scrollHeight; }
        }, 50);
    }

    async def fetchHistory -> None {
        result = root spawn ListChatHistory();
        if result.reports {
            msgs = result.reports[0];
            # Only replace messages if server has history (don't wipe local messages)
            if len(msgs) > 0 {
                msgs.sort(lambda a: any, b: any -> int {
                    aNum = parseInt(a.id.replace("chat_", "")) if a.id else 0;
                    bNum = parseInt(b.id.replace("chat_", "")) if b.id else 0;
                    return aNum - bNum;
                });
                messages = msgs;
            }
        }
        historyLoaded = True;
    }

    async def sendMessage -> None {
        msg = inputText.trim();
        if not msg or loading { return; }
        inputText = "";
        loading = True;

        # Optimistic user message (bot response added after LLM returns)
        botMsgId = "bot_" + Date.now().toString();
        userMsg = {
            "id": "local_u_" + Date.now().toString(),
            "role": "user",
            "content": msg,
            "action_type": "",
            "action_status": "",
            "timestamp": ""
        };
        # Keep a local reference to avoid stale state in async continuation
        currentMessages = messages.concat([userMsg]);
        messages = currentMessages;

        try {
            # Call AgentChat via root spawn — returns full response
            chatResult = root spawn AgentChat(message=msg);
            fullText = "";

            if chatResult.reports and chatResult.reports[0] {
                data = chatResult.reports[0];
                fullText = data.content if data.content else "";

                # Add bot response message using local reference to preserve user msg
                currentMessages = currentMessages.concat([{
                    "id": botMsgId,
                    "role": "assistant",
                    "content": fullText,
                    "action_type": "",
                    "action_status": "",
                    "timestamp": ""
                }]);
                messages = currentMessages;

                # Capture tool events for the log
                if data.tool_events {
                    newLogs = {};
                    Object.assign(newLogs, toolLogs);
                    newLogs[botMsgId] = data.tool_events;
                    toolLogs = newLogs;
                }
            }

            # Phase 2: Check if all required info is gathered and action is ready
            if fullText != "" {
                todayDate = Reflect.construct(Date, []);
                todayStr = todayDate.getFullYear().toString() + "-" + (todayDate.getMonth() + 1).toString().padStart(2, "0") + "-" + todayDate.getDate().toString().padStart(2, "0");

                readyResult = root spawn AgentCheckReady(
                    history=currentMessages,
                    current_date=todayStr
                );
                if readyResult.reports {
                    readiness = readyResult.reports[0];
                    if readiness["ready"] and readiness["action_type"] != "none" and readiness["action_type"] != "" {
                        pendingAction = {
                            "action_type": readiness["action_type"],
                            "target_task_id": readiness["target_task_id"],
                            "task_title": readiness["task_title"],
                            "task_description": readiness["task_description"],
                            "task_status": readiness["task_status"],
                            "task_priority": readiness["task_priority"],
                            "task_due_date": readiness["task_due_date"],
                            "task_list_id": readiness["task_list_id"],
                            "task_start_date": readiness["task_start_date"],
                            "task_start_time": readiness["task_start_time"],
                            "task_end_time": readiness["task_end_time"],
                            "task_category": readiness["task_category"],
                            "task_estimated_duration": readiness["task_estimated_duration"]
                        };
                    }
                }
            }

        } except Exception as e {
            console.error("Chat error:", e);
            currentMessages = currentMessages.concat([{
                "id": botMsgId,
                "role": "assistant",
                "content": "Sorry, something went wrong. Please try again.",
                "action_type": "", "action_status": "", "timestamp": ""
            }]);
            messages = currentMessages;
        }

        loading = False;
    }

    async def confirmAction -> None {
        if not pendingAction or not pendingAction.action_type { return; }
        loading = True;
        confirmMsg = "";
        success = False;

        execResult = None;
        if pendingAction.action_type == "create_task" {
            execResult = root spawn AgentExecuteCreate(
                task_title=pendingAction.task_title if pendingAction.task_title else "",
                task_description=pendingAction.task_description if pendingAction.task_description else "",
                task_status=pendingAction.task_status if pendingAction.task_status else "",
                task_priority=pendingAction.task_priority if pendingAction.task_priority else "",
                task_due_date=pendingAction.task_due_date if pendingAction.task_due_date else "",
                task_list_id=pendingAction.task_list_id if pendingAction.task_list_id else "",
                task_start_date=pendingAction.task_start_date if pendingAction.task_start_date else "",
                task_start_time=pendingAction.task_start_time if pendingAction.task_start_time else "",
                task_end_time=pendingAction.task_end_time if pendingAction.task_end_time else "",
                task_category=pendingAction.task_category if pendingAction.task_category else "",
                task_estimated_duration=pendingAction.task_estimated_duration if pendingAction.task_estimated_duration else 60
            );
            if execResult.reports and execResult.reports[0].success {
                confirmMsg = "Done! Task created successfully.";
                success = True;
            } else {
                confirmMsg = "Sorry, I could not create that task. Please try again.";
            }
        } elif pendingAction.action_type == "update_task" {
            execResult = root spawn AgentExecuteUpdate(
                target_task_id=pendingAction.target_task_id if pendingAction.target_task_id else "",
                task_title=pendingAction.task_title if pendingAction.task_title else "",
                task_description=pendingAction.task_description if pendingAction.task_description else "",
                task_status=pendingAction.task_status if pendingAction.task_status else "",
                task_priority=pendingAction.task_priority if pendingAction.task_priority else "",
                task_due_date=pendingAction.task_due_date if pendingAction.task_due_date else "",
                task_start_date=pendingAction.task_start_date if pendingAction.task_start_date else "",
                task_start_time=pendingAction.task_start_time if pendingAction.task_start_time else "",
                task_end_time=pendingAction.task_end_time if pendingAction.task_end_time else "",
                task_category=pendingAction.task_category if pendingAction.task_category else "",
                task_estimated_duration=pendingAction.task_estimated_duration if pendingAction.task_estimated_duration else 0
            );
            if execResult.reports and execResult.reports[0].success {
                confirmMsg = "Done! Task updated successfully.";
                success = True;
            } else {
                confirmMsg = "Sorry, I could not update that task. Please try again.";
            }
        } elif pendingAction.action_type == "delete_task" {
            execResult = root spawn AgentExecuteDelete(
                target_task_id=pendingAction.target_task_id if pendingAction.target_task_id else "",
                task_title=pendingAction.task_title if pendingAction.task_title else ""
            );
            if execResult.reports and execResult.reports[0].success {
                confirmMsg = "Done! Task deleted.";
                success = True;
            } else {
                confirmMsg = "Sorry, I could not delete that task. Please try again.";
            }
        } elif pendingAction.action_type == "reschedule" {
            confirmMsg = "Rescheduling is not enabled yet.";
        } else {
            confirmMsg = "Sorry, I could not complete that action. Please try again.";
        }

        messages = messages.concat([{
            "id": "sys_" + Date.now().toString(),
            "role": "assistant",
            "content": confirmMsg,
            "action_type": "",
            "action_status": "",
            "timestamp": ""
        }]);

        pendingAction = {};
        loading = False;
        if success { onTasksChanged(); }
    }

    def rejectAction -> None {
        pendingAction = {};
        messages = messages.concat([{
            "id": "sys_" + Date.now().toString(),
            "role": "assistant",
            "content": "OK, I won't make that change. Let me know if you need anything else.",
            "action_type": "",
            "action_status": "",
            "timestamp": ""
        }]);
    }

    async def clearHistory -> None {
        root spawn ClearChatHistory();
        messages = [];
        pendingAction = {};
    }

    def handleKeyDown(e: any) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            sendMessage();
        }
    }

    def getActionLabel(actionType: str) -> str {
        if actionType == "create_task" { return "Create Task"; }
        if actionType == "delete_task" { return "Delete Task"; }
        if actionType == "update_task" { return "Update Task"; }
        if actionType == "reschedule" { return "Reschedule"; }
        return actionType;
    }

    def getToolLabel(toolName: str) -> str {
        if toolName == "tool_list_tasks" { return "Listing tasks"; }
        if toolName == "tool_get_task_details" { return "Reading task details"; }
        if toolName == "tool_get_tasks_for_date" { return "Checking schedule"; }
        if toolName == "tool_list_spaces_and_lists" { return "Listing spaces & lists"; }
        if toolName == "tool_get_unscheduled_tasks" { return "Finding unscheduled tasks"; }
        if toolName == "tool_check_schedule_conflicts" { return "Checking conflicts"; }
        return toolName;
    }

    def toggleLogExpanded(msgId: str) -> None {
        newExpanded = {};
        Object.assign(newExpanded, expandedLogs);
        current = newExpanded[msgId] if newExpanded[msgId] else False;
        newExpanded[msgId] = not current;
        expandedLogs = newExpanded;
    }

    def getActionColor(actionType: str) -> str {
        if actionType == "create_task" { return "chat-action-create"; }
        if actionType == "delete_task" { return "chat-action-delete"; }
        if actionType == "update_task" { return "chat-action-update"; }
        if actionType == "reschedule" { return "chat-action-reschedule"; }
        return "";
    }

    return
        <div className="chat-container">
            {(
                <button
                    className="chat-fab"
                    onClick={lambda -> None { isOpen = True; }}
                    title="Chat with FlowBoard AI"
                >
                    <MessageSquare size={20} />
                </button>
            ) if not isOpen else (
                <div className="chat-panel">
                    <div className="chat-header">
                        <div className="chat-header-left">
                            <Bot size={18} className="chat-header-icon" />
                            <span className="chat-header-title">FlowBoard AI</span>
                        </div>
                        <div className="chat-header-actions">
                            <button
                                className="chat-header-btn"
                                onClick={lambda -> None { clearHistory(); }}
                                title="Clear chat"
                            >
                                <Trash2 size={14} />
                            </button>
                            <button
                                className="chat-header-btn"
                                onClick={lambda -> None { isOpen = False; }}
                                title="Close"
                            >
                                <X size={16} />
                            </button>
                        </div>
                    </div>

                    <div className="chat-messages">
                        {(
                            <div className="chat-empty">
                                <Bot size={32} className="chat-empty-icon" />
                                <p className="chat-empty-title">Hi! I'm your FlowBoard assistant.</p>
                                <p className="chat-empty-sub">I can create, modify, delete, and reschedule tasks. Just ask!</p>
                                <div className="chat-suggestions">
                                    {[
                                        <button
                                            key={s}
                                            className="chat-suggestion"
                                            onClick={lambda -> None { inputText = s; sendMessage(); }}
                                        >
                                            {s}
                                        </button>
                                        for s in [
                                            "Add a team meeting tomorrow at 2pm",
                                            "What tasks do I have this week?",
                                            "Reschedule my tasks to avoid conflicts"
                                        ]
                                    ]}
                                </div>
                            </div>
                        ) if len(messages) == 0 and not loading else (
                            <div>
                                {[
                                    <div key={msg.id} className="chat-msg-wrap">
                                        <ToolLogBlock
                                            msgId={msg.id}
                                            role={msg.role}
                                            toolLogs={toolLogs}
                                            expandedLogs={expandedLogs}
                                            onToggle={toggleLogExpanded}
                                            getToolLabel={getToolLabel}
                                        />
                                        <div className={"chat-msg " + ("chat-msg-user" if msg.role == "user" else "chat-msg-assistant")}>
                                            <div className="chat-msg-avatar">
                                                {(<User size={14} />) if msg.role == "user" else (<Bot size={14} />)}
                                            </div>
                                            <div className="chat-msg-body">
                                                <div className="chat-msg-content">
                                                    {(<Markdown>{msg.content}</Markdown>) if msg.role == "assistant" else msg.content}
                                                </div>
                                                {(
                                                    <div className={"chat-action-badge " + getActionColor(msg.action_type)}>
                                                        {getActionLabel(msg.action_type)}
                                                    </div>
                                                ) if msg.action_type and msg.action_type != "" and msg.action_type != "none" else None}
                                            </div>
                                        </div>
                                    </div>
                                    for msg in messages
                                ]}
                                {(
                                    <div className="chat-msg chat-msg-assistant">
                                        <div className="chat-msg-avatar"><Bot size={14} /></div>
                                        <div className="chat-msg-body">
                                            <div className="chat-typing">
                                                <span className="chat-typing-dot"></span>
                                                <span className="chat-typing-dot"></span>
                                                <span className="chat-typing-dot"></span>
                                            </div>
                                        </div>
                                    </div>
                                ) if loading else None}
                                <div className="chat-scroll-anchor"></div>
                            </div>
                        )}
                    </div>

                    {(
                        <div className="chat-confirm-bar">
                            <span className="chat-confirm-label">
                                {getActionLabel(pendingAction.action_type) + "?"}
                            </span>
                            <div className="chat-confirm-btns">
                                <button
                                    className="chat-confirm-yes"
                                    onClick={lambda -> None { confirmAction(); }}
                                    disabled={loading}
                                >
                                    <Check size={14} /> Confirm
                                </button>
                                <button
                                    className="chat-confirm-no"
                                    onClick={lambda -> None { rejectAction(); }}
                                    disabled={loading}
                                >
                                    <XCircle size={14} /> Reject
                                </button>
                            </div>
                        </div>
                    ) if pendingAction and pendingAction.action_type else None}

                    <div className="chat-input-area">
                        <input
                            type="text"
                            className="chat-input"
                            value={inputText}
                            onChange={lambda e: any -> None { inputText = e.target.value; }}
                            onKeyDown={handleKeyDown}
                            placeholder="Ask me to manage your tasks..."
                            disabled={loading}
                            autoFocus={True}
                        />
                        <button
                            className="chat-send-btn"
                            onClick={lambda -> None { sendMessage(); }}
                            disabled={loading or inputText.trim() == ""}
                            title="Send"
                        >
                            <Send size={16} />
                        </button>
                    </div>
                </div>
            )}
        </div>;
}

def:pub ToolLogBlock(
    msgId: str,
    role: str,
    toolLogs: dict,
    expandedLogs: dict,
    onToggle: any,
    getToolLabel: any
) -> any {
    if role != "assistant" or not toolLogs[msgId] {
        return <span></span>;
    }

    log = toolLogs[msgId];
    isExpanded = expandedLogs[msgId] if expandedLogs[msgId] else False;

    # Filter to just call entries
    calls = log.filter(lambda s: any -> bool { return s["type"] == "call"; });

    return
        <div className="chat-tool-log">
            <button
                className="chat-tool-toggle"
                onClick={lambda -> None { onToggle(msgId); }}
            >
                {(<ChevronDown size={12} />) if isExpanded else (<ChevronRight size={12} />)}
                <Search size={12} className="chat-tool-icon" />
                <span>{len(calls).toString() + " tool calls"}</span>
            </button>
            {(
                <div className="chat-tool-steps">
                    {[
                        <div key={call["tool"]} className="chat-tool-step">
                            <span className="chat-tool-step-label">
                                {getToolLabel(call["tool"])}
                            </span>
                        </div>
                        for call in calls
                    ]}
                </div>
            ) if isExpanded else None}
        </div>;
}

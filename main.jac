"""FlowBoard - ClickUp-style Project Management App.

Combines server-side endpoints with client-side UI.
"""

import from byllm.lib { Model, Image }
import from datetime { datetime, timedelta }
import from json { dumps as json_dumps, loads as json_loads }

glob llm = Model(model_name="gpt-4o-mini");

enum ScheduleSource {
    USER = "user",
    AI_OPTIMIZED = "ai_optimized",
    UNSCHEDULED = ""
}

# Client-side UI
cl {
    import from frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return
            <ClientApp />;
    }
}

# ===== DATA NODES =====

node Space {
    has id: str,
        name: str,
        color: str = "purple",
        description: str = "";
}

node List {
    has id: str,
        name: str,
        space_id: str,
        color: str = "gray";
}

node Task {
    has id: str,
        title: str,
        description: str = "",
        status: str = "todo",
        priority: str = "normal",
        due_date: str = "",
        list_id: str = "",
        parent_task_id: str = "",
        start_date: str = "",
        start_time: str = "",
        end_time: str = "",
        estimated_duration: int = 60,
        actual_duration: int = 0,
        category: str = "",
        is_locked: bool = False,
        ai_confidence: int = 0,
        ai_explanation: str = "",
        schedule_source: ScheduleSource = ScheduleSource.UNSCHEDULED;
}

node TaskHistory {
    has id: str,
        task_title: str,
        category: str,
        estimated_duration: int,
        actual_duration: int,
        completed_at: str,
        started_at: str = "";
}

node UserPatterns {
    has productivity_peaks: dict = {},
        category_overrun_ratios: dict = {},
        category_productivity: dict = {},
        out_of_scope_minutes: int = 0,
        last_updated: str = "";
}

node ActiveTask {
    has active_task_id: str = "",
        timer_start: str = "",
        timer_accumulated: int = 0,
        is_running: bool = False,
        last_updated: str = "";
}

node Comment {
    has id: str,
        content: str,
        task_id: str;
}

# ===== USER PROFILE NODE =====

node UserProfile {
    has display_name: str = "",
        theme: str = "dark",
        default_view: str = "list";
}

node ChatSession {
    has id: str = "chat_session";
}

node ChatMessage {
    has id: str,
        role: str,
        content: str,
        action_type: str = "",
        action_status: str = "",
        timestamp: str = "";
}

node CalendarDay {
    has date: str;  # YYYY-MM-DD — one node per date that has scheduled tasks
}

node ActivityReport {
    has id: str,
        task_id: str,
        task_title: str,
        task_category: str,
        on_task: bool,
        elapsed_minutes: int,
        reported_at: str,
        off_task_description: str = "";
}

# ===== GLOBAL COUNTERS =====

glob space_counter: int = 0;
glob list_counter: int = 0;
glob task_counter: int = 0;
glob comment_counter: int = 0;
glob task_history_counter: int = 0;
glob chat_msg_counter: int = 0;
glob activity_report_counter: int = 0;

# ===== USER PROFILE WALKERS =====

walker:priv GetUserProfile {
    can search with Root entry {
        visit [-->];
    }

    can retrieve with UserProfile entry {
        report {
            "display_name": here.display_name,
            "theme": here.theme,
            "default_view": here.default_view
        };
    }

    can report_default with Root exit {
        report {
            "display_name": "",
            "theme": "dark",
            "default_view": "list"
        };
    }
}

walker:priv UpdateUserProfile {
    has display_name: str,
        theme: str,
        default_view: str;
    has found: bool = False;

    can get_or_create with Root entry {
        visit [-->];
        if not self.found {
            here ++> UserProfile(
                display_name=self.display_name,
                theme=self.theme,
                default_view=self.default_view
            );
        }
        report {
            "display_name": self.display_name,
            "theme": self.theme,
            "default_view": self.default_view
        };
    }

    can do_update with UserProfile entry {
        self.found = True;
        here.display_name = self.display_name;
        here.theme = self.theme;
        here.default_view = self.default_view;
    }
}

# ===== SPACE WALKERS =====

walker:priv CreateSpace {
    has name: str,
        color: str = "purple",
        description: str = "";

    can create with Root entry {
        global space_counter;
        space_counter += 1;
        new_id = "space_" + str(space_counter);
        new_space = here ++> Space(
            id=new_id,
            name=self.name,
            color=self.color,
            description=self.description
        );
        if new_space {
            report {
                "id": new_space[0].id,
                "name": new_space[0].name,
                "color": new_space[0].color,
                "description": new_space[0].description
            };
        }
    }
}

walker:priv ListSpaces {
    has spaces: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with Space entry {
        self.spaces.append({
            "id": here.id,
            "name": here.name,
            "color": here.color,
            "description": here.description
        });
    }

    can report_all with Root exit {
        report self.spaces;
    }
}

walker:priv DeleteSpace {
    has space_id: str,
        deleted_task_ids: list = [];

    can search with Root entry {
        visit [-->];
    }

    can delete_space with Space entry {
        if here.id == self.space_id {
            visit [-->];
            del here;
            report {"deleted": self.space_id};
        }
    }

    can delete_list with List entry {
        visit [-->];
        del here;
    }

    can delete_task with Task entry {
        self.deleted_task_ids.append(here.id);
        del here;
    }

    can cleanup_active with Root exit {
        for tid in self.deleted_task_ids {
            active_nodes = [-->][?:ActiveTask, active_task_id == tid];
            for active in active_nodes {
                del active;
            }
        }
    }
}

# ===== LIST WALKERS =====

walker:priv CreateList {
    has name: str,
        space_id: str = "",
        color: str = "gray";

    can create with Root entry {
        global list_counter;
        list_counter += 1;
        new_id = "list_" + str(list_counter);
        new_list = here ++> List(
            id=new_id,
            name=self.name,
            space_id="",
            color=self.color
        );
        if new_list {
            report {
                "id": new_list[0].id,
                "name": new_list[0].name,
                "space_id": "",
                "color": new_list[0].color
            };
        }
    }
}

walker:priv ListLists {
    has lists: list = [],
        space_id: str = "";

    can collect with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can gather with List entry {
        if self.space_id == "" or here.space_id == self.space_id {
            self.lists.append({
                "id": here.id,
                "name": here.name,
                "space_id": here.space_id,
                "color": here.color
            });
        }
    }

    can report_all with Root exit {
        report self.lists;
    }
}

walker:priv DeleteList {
    has list_id: str,
        deleted_task_ids: list = [];

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can delete_list with List entry {
        if here.id == self.list_id {
            visit [-->];
            del here;
            report {"deleted": self.list_id};
        }
    }

    can delete_task with Task entry {
        self.deleted_task_ids.append(here.id);
        del here;
    }

    can cleanup_active with Root exit {
        for tid in self.deleted_task_ids {
            active_nodes = [-->][?:ActiveTask, active_task_id == tid];
            for active in active_nodes {
                del active;
            }
        }
    }
}

# ===== TASK WALKERS =====

walker:priv CreateTask {
    has title: str,
        description: str = "",
        status: str = "todo",
        priority: str = "normal",
        due_date: str = "",
        list_id: str = "",
        parent_task_id: str = "",
        start_date: str = "",
        start_time: str = "",
        end_time: str = "",
        estimated_duration: int = 60,
        category: str = "";
    has created: bool = False;
    has new_task_ref: list = [];  # stores [task_node] after creation

    can start with Root entry {
        if self.list_id == "" {
            global task_counter;
            task_counter += 1;
            new_id = "task_" + str(task_counter);
            src = ScheduleSource.USER if (self.start_date != "" and self.start_time != "") else ScheduleSource.UNSCHEDULED;
            new_task = here ++> Task(
                id=new_id, title=self.title, description=self.description,
                status=self.status, priority=self.priority, due_date=self.due_date,
                list_id=self.list_id, parent_task_id=self.parent_task_id,
                start_date=self.start_date, start_time=self.start_time, end_time=self.end_time,
                estimated_duration=self.estimated_duration, category=self.category,
                schedule_source=src
            );
            if new_task {
                self.created = True;
                self.new_task_ref = new_task;
                report {
                    "id": new_task[0].id, "title": new_task[0].title,
                    "description": new_task[0].description, "status": new_task[0].status,
                    "priority": new_task[0].priority, "due_date": new_task[0].due_date,
                    "list_id": new_task[0].list_id, "parent_task_id": new_task[0].parent_task_id,
                    "start_date": new_task[0].start_date, "start_time": new_task[0].start_time,
                    "end_time": new_task[0].end_time, "estimated_duration": new_task[0].estimated_duration,
                    "actual_duration": new_task[0].actual_duration, "category": new_task[0].category,
                    "is_locked": new_task[0].is_locked, "ai_confidence": new_task[0].ai_confidence,
                    "ai_explanation": new_task[0].ai_explanation,
                    "schedule_source": new_task[0].schedule_source.value
                };
            }
        } else {
            visit [-->];
        }
    }

    can pass_space with Space entry {
        if not self.created {
            visit [-->];
        }
    }

    can attach_to_list with List entry {
        if not self.created and here.id == self.list_id {
            global task_counter;
            task_counter += 1;
            new_id = "task_" + str(task_counter);
            src = ScheduleSource.USER if (self.start_date != "" and self.start_time != "") else ScheduleSource.UNSCHEDULED;
            new_task = here ++> Task(
                id=new_id, title=self.title, description=self.description,
                status=self.status, priority=self.priority, due_date=self.due_date,
                list_id=self.list_id, parent_task_id=self.parent_task_id,
                start_date=self.start_date, start_time=self.start_time, end_time=self.end_time,
                estimated_duration=self.estimated_duration, category=self.category,
                schedule_source=src
            );
            if new_task {
                self.created = True;
                self.new_task_ref = new_task;
                report {
                    "id": new_task[0].id, "title": new_task[0].title,
                    "description": new_task[0].description, "status": new_task[0].status,
                    "priority": new_task[0].priority, "due_date": new_task[0].due_date,
                    "list_id": new_task[0].list_id, "parent_task_id": new_task[0].parent_task_id,
                    "start_date": new_task[0].start_date, "start_time": new_task[0].start_time,
                    "end_time": new_task[0].end_time, "estimated_duration": new_task[0].estimated_duration,
                    "actual_duration": new_task[0].actual_duration, "category": new_task[0].category,
                    "is_locked": new_task[0].is_locked, "ai_confidence": new_task[0].ai_confidence,
                    "ai_explanation": new_task[0].ai_explanation,
                    "schedule_source": new_task[0].schedule_source.value
                };
            }
        }
    }

    can link_calendar with Root exit {
        # Link new task to its CalendarDay node (here is Root at exit)
        if not self.new_task_ref or self.start_date == "" { return; }
        task_node = self.new_task_ref[0];
        cd_list = [-->][?:CalendarDay, date == self.start_date];
        if not cd_list {
            cd_list = here ++> CalendarDay(date=self.start_date);
        }
        cd_list[0] ++> task_node;
    }
}

walker:priv ListTasks {
    has tasks: list = [],
        list_id: str = "";

    can collect with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can gather with Task entry {
        if self.list_id == "" or here.list_id == self.list_id {
            self.tasks.append({
                "id": here.id,
                "title": here.title,
                "description": here.description,
                "status": here.status,
                "priority": here.priority,
                "due_date": here.due_date,
                "list_id": here.list_id,
                "parent_task_id": here.parent_task_id,
                "start_date": here.start_date,
                "start_time": here.start_time,
                "end_time": here.end_time,
                "estimated_duration": here.estimated_duration,
                "actual_duration": here.actual_duration,
                "category": here.category,
                "is_locked": here.is_locked,
                "ai_confidence": here.ai_confidence,
                "ai_explanation": here.ai_explanation,
                "schedule_source": here.schedule_source.value
            });
        }
    }

    can report_all with Root exit {
        report self.tasks;
    }
}

walker:priv ListTasksForDate {
    has date: str;
    has tasks: list = [];

    can collect with Root entry {
        # Navigate directly to the CalendarDay for this date
        day_nodes = [-->][?:CalendarDay, date == self.date];
        if day_nodes {
            visit day_nodes[0];
        }
    }

    can gather_from_day with CalendarDay entry {
        visit [-->];
    }

    can gather with Task entry {
        self.tasks.append({
            "id": here.id,
            "title": here.title,
            "description": here.description,
            "status": here.status,
            "priority": here.priority,
            "due_date": here.due_date,
            "list_id": here.list_id,
            "parent_task_id": here.parent_task_id,
            "start_date": here.start_date,
            "start_time": here.start_time,
            "end_time": here.end_time,
            "estimated_duration": here.estimated_duration,
            "actual_duration": here.actual_duration,
            "category": here.category,
            "is_locked": here.is_locked,
            "ai_confidence": here.ai_confidence,
            "ai_explanation": here.ai_explanation,
            "schedule_source": here.schedule_source.value
        });
    }

    can report_all with Root exit {
        report self.tasks;
    }
}

walker:priv UpdateTask {
    has task_id: str,
        title: str,
        description: str,
        status: str,
        priority: str,
        due_date: str,
        start_date: str = "",
        start_time: str = "",
        end_time: str = "",
        estimated_duration: int = 60,
        category: str = "";
    has updated_task_ref: list = [];
    has old_start_date: str = "";

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can do_update with Task entry {
        if here.id == self.task_id {
            self.old_start_date = here.start_date;
            scheduling_changed = (here.start_date != self.start_date or here.start_time != self.start_time
                    or here.end_time != self.end_time);
            # Clear explanation if any scheduling-relevant field changed
            if (scheduling_changed or here.estimated_duration != self.estimated_duration
                    or here.category != self.category or here.title != self.title) {
                here.ai_explanation = "";
                here.ai_confidence = 0;
            }
            # Update schedule_source when the time slot changes
            if scheduling_changed {
                if self.start_date != "" and self.start_time != "" {
                    here.schedule_source = ScheduleSource.USER;
                } else {
                    here.schedule_source = ScheduleSource.UNSCHEDULED;
                }
            }
            here.title = self.title;
            here.description = self.description;
            here.status = self.status;
            here.priority = self.priority;
            here.due_date = self.due_date;
            here.start_date = self.start_date;
            here.start_time = self.start_time;
            here.end_time = self.end_time;
            here.estimated_duration = self.estimated_duration;
            here.category = self.category;
            self.updated_task_ref = [here];
            report {
                "id": here.id,
                "title": here.title,
                "description": here.description,
                "status": here.status,
                "priority": here.priority,
                "due_date": here.due_date,
                "list_id": here.list_id,
                "parent_task_id": here.parent_task_id,
                "start_date": here.start_date,
                "start_time": here.start_time,
                "end_time": here.end_time,
                "estimated_duration": here.estimated_duration,
                "actual_duration": here.actual_duration,
                "category": here.category,
                "is_locked": here.is_locked,
                "ai_confidence": here.ai_confidence,
                "ai_explanation": here.ai_explanation,
                "schedule_source": here.schedule_source.value
            };
        }
    }

    can update_calendar with Root exit {
        if not self.updated_task_ref { return; }
        task_node = self.updated_task_ref[0];
        # Remove from old CalendarDay if date changed
        if self.old_start_date != "" and self.old_start_date != self.start_date {
            old_cd_list = [-->][?:CalendarDay, date == self.old_start_date];
            for cd in old_cd_list {
                cd del --> task_node;
            }
        }
        # Link to new CalendarDay if scheduled
        if self.start_date != "" {
            cd_list = [-->][?:CalendarDay, date == self.start_date];
            if not cd_list {
                cd_list = here ++> CalendarDay(date=self.start_date);
            }
            cd_list[0] ++> task_node;
        }
    }
}

walker:priv DeleteTask {
    has task_id: str;

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can delete_task with Task entry {
        if here.id == self.task_id or here.parent_task_id == self.task_id {
            del here;
            report {"deleted": self.task_id};
        }
    }

    can cleanup_active with Root exit {
        active_nodes = [-->][?:ActiveTask, active_task_id == self.task_id];
        for active in active_nodes {
            del active;
        }
    }
}

# ===== COMMENT WALKERS =====

walker:priv AddComment {
    has content: str,
        task_id: str;

    can create with Root entry {
        global comment_counter;
        comment_counter += 1;
        new_id = "comment_" + str(comment_counter);
        new_comment = here ++> Comment(
            id=new_id,
            content=self.content,
            task_id=self.task_id
        );
        if new_comment {
            report {
                "id": new_comment[0].id,
                "content": new_comment[0].content,
                "task_id": new_comment[0].task_id
            };
        }
    }
}

walker:priv ListComments {
    has comments: list = [],
        task_id: str = "";

    can collect with Root entry {
        visit [-->];
    }

    can gather with Comment entry {
        if self.task_id == "" or here.task_id == self.task_id {
            self.comments.append({
                "id": here.id,
                "content": here.content,
                "task_id": here.task_id
            });
        }
    }

    can report_all with Root exit {
        report self.comments;
    }
}

walker:priv DeleteComment {
    has comment_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete_comment with Comment entry {
        if here.id == self.comment_id {
            del here;
            report {"deleted": self.comment_id};
        }
    }
}

# ===== VOICE TASK EXTRACTION =====

obj TaskDetails {
    has title: str,
        description: str = "",
        status: str = "todo",
        priority: str = "normal",
        due_date: str = "";
}

sem TaskDetails = "Task details extracted from spoken voice input.";
sem TaskDetails.title = "Concise task name, required.";
sem TaskDetails.description = "Optional additional details. Empty string if none.";
sem TaskDetails.status = "Task status: exactly one of todo, in_progress, review, done.";
sem TaskDetails.priority = "Task priority: exactly one of urgent, high, normal, low.";
sem TaskDetails.due_date = "Due date in YYYY-MM-DD format if mentioned, otherwise empty string.";

def extract_task_details(spoken_input: str, current_datetime: str) -> TaskDetails by llm(temperature=0.1);
sem extract_task_details = "Extract task management details from a transcribed voice input. Use current_datetime to resolve relative date references like 'tomorrow', 'next week', or 'by Friday'.";
sem extract_task_details.current_datetime = "Today's date and weekday, used to compute absolute due dates from relative references.";

walker:priv AIExtractTaskFromTranscript {
    has transcript: str;

    can run with Root entry {
        current_dt = datetime.now().strftime("%Y-%m-%d (weekday: %A)");
        details = extract_task_details(self.transcript, current_dt);
        report {
            "title": details.title,
            "description": details.description,
            "status": details.status,
            "priority": details.priority,
            "due_date": details.due_date
        };
    }
}

# ===== TASK-SCREEN MATCHING =====

obj TaskMatch {
    has task_id: str,
        task_title: str,
        confidence: int,
        reasoning: str;
}
sem TaskMatch.task_id = "ID of the task the user is working on, or empty string if nothing matches";
sem TaskMatch.task_title = "Title of the matched task, or empty string if no match";
sem TaskMatch.confidence = "Confidence score 0-100 that the user is actively working on this specific task";
sem TaskMatch.reasoning = "One sentence explaining what on screen matched this task";

def match_task_to_screen(img: Image, tasks_summary: str, current_time: str) -> TaskMatch by llm(temperature=0.1);
sem match_task_to_screen = "You are a task-detection system. Look at the screenshot and the list of tasks scheduled for today. Find which task (if any) the user is actively working on based on what is visible on screen. Match app context to task category: Coding tasks need a code editor or terminal; Writing tasks need a document editor; Meeting tasks need a video call app; Research tasks need relevant browser tabs. Only return a match when confidence >= 70. If nothing clearly matches, return empty task_id and confidence 0.";
sem match_task_to_screen.img = "Screenshot of the user's screen";
sem match_task_to_screen.tasks_summary = "Newline-separated list of today's tasks in format: [task_id] title (category) scheduled HH:MM";
sem match_task_to_screen.current_time = "Current time in HH:MM 24-hour format";

# ===== ACTIVITY TRACKING =====

obj ActivityAnalysis {
    has on_task: bool,
        description: str;
}
sem ActivityAnalysis.on_task = "True if the user appears to be actively working on the specified task, False if they are visibly doing something unrelated";
sem ActivityAnalysis.description = "One sentence describing what is visible on screen and how it relates (or does not relate) to the task";

def check_user_activity(img: Image, task_title: str, task_category: str) -> ActivityAnalysis by llm(temperature=0.1);
sem check_user_activity = "You are a focus coach. Examine the screenshot and decide if the user is working on their task. The task title is in task_title and its category is in task_category. Common on-task evidence: code editor, relevant browser tab, document editor matching the category. Off-task evidence: social media, games, unrelated video, messaging apps unrelated to work. Return on_task=True only if there is clear evidence of working on the task.";
sem check_user_activity.img = "Screenshot of the user's screen";
sem check_user_activity.task_title = "Title of the task the user is supposed to be working on";
sem check_user_activity.task_category = "Category of the task (e.g. coding, writing, research, design)";

# ===== AI SCHEDULING — RETURN TYPES =====

obj ScheduleSlot {
    has start_date: str,
        start_time: str,
        end_time: str,
        confidence: int,
        reasoning: str;
}
sem ScheduleSlot.start_date = "Date in YYYY-MM-DD format";
sem ScheduleSlot.start_time = "Start time in HH:MM 24-hour format";
sem ScheduleSlot.end_time = "End time in HH:MM 24-hour format";
sem ScheduleSlot.confidence = "Scheduling confidence score 0-100";
sem ScheduleSlot.reasoning = "One-sentence explanation for why this slot was chosen";

obj FactorScore {
    has factor: str,
        score: int;
}
sem FactorScore.factor = "Factor name: one of Productivity Peak, Deadline Urgency, Calendar Fit, Task Complexity";
sem FactorScore.score = "Factor weight score 0-100";

obj AlternativeSlot {
    has start_date: str,
        start_time: str,
        end_time: str,
        productivity_score: int,
        reasoning: str;
}
sem AlternativeSlot.start_date = "Date in YYYY-MM-DD format";
sem AlternativeSlot.start_time = "Start time in HH:MM 24-hour format";
sem AlternativeSlot.end_time = "End time in HH:MM 24-hour format";
sem AlternativeSlot.productivity_score = "Productivity suitability score for this slot 0-100, based on user patterns";
sem AlternativeSlot.reasoning = "One-sentence reason this slot is a good alternative";

obj AlternativeSlots {
    has slots: list[AlternativeSlot];
}
sem AlternativeSlots.slots = "Exactly 3 alternative time slots, sorted by productivity_score descending";

obj ScheduleExplanation {
    has headline: str,
        workload_insight: str,
        duration_insight: str,
        deadline_insight: str,
        productivity_score: int,
        ai_adjusted_duration: int,
        historical_accuracy_pct: int,
        tip: str,
        factors: list[FactorScore];
}
sem ScheduleExplanation.headline = "Short sentence explaining why this slot was chosen, e.g. 'Scheduled Monday 11 AM to leverage your peak focus window for research tasks'";
sem ScheduleExplanation.workload_insight = "Insight about the user's workload pattern around this time slot";
sem ScheduleExplanation.duration_insight = "Insight about estimated vs typical actual duration for this task category, e.g. 'Research interviews historically run 40-60% longer than estimated'";
sem ScheduleExplanation.deadline_insight = "Insight about deadline urgency relative to the scheduled position";
sem ScheduleExplanation.productivity_score = "Productivity score 0-100 for this time slot based on the user's peak hours";
sem ScheduleExplanation.ai_adjusted_duration = "Realistic duration estimate in minutes after applying the historical overrun ratio for this category";
sem ScheduleExplanation.historical_accuracy_pct = "User's historical estimation accuracy percentage for this task category, 0-100";
sem ScheduleExplanation.tip = "A short actionable AI tip related to this task or time slot, e.g. 'Consider blocking 30 min after for synthesis notes'";
sem ScheduleExplanation.factors = "Exactly 4 scoring factors that influenced this scheduling decision, covering Productivity Peak, Deadline Urgency, Calendar Fit, and Task Complexity";

obj ScheduleChange {
    has task_id: str,
        task_title: str,
        new_start_date: str,
        new_start_time: str,
        new_end_time: str,
        reason: str;
}
sem ScheduleChange.task_id = "ID of the task being rescheduled, copied exactly from the input";
sem ScheduleChange.task_title = "Title of the task being rescheduled, copied exactly from the input";
sem ScheduleChange.new_start_date = "New scheduled date in YYYY-MM-DD format";
sem ScheduleChange.new_start_time = "New start time in HH:MM 24-hour format";
sem ScheduleChange.new_end_time = "New end time in HH:MM 24-hour format, calculated from start time plus task duration";
sem ScheduleChange.reason = "Brief explanation of why this task was moved to resolve the conflict or improve the schedule";

obj ReplanProposal {
    has has_conflict: bool,
        changes: list[ScheduleChange],
        explanation: str;
}
sem ReplanProposal.has_conflict = "True if the new task causes scheduling conflicts with existing tasks";
sem ReplanProposal.changes = "List of proposed task reschedules to resolve conflicts. Empty list if has_conflict is false";
sem ReplanProposal.explanation = "Human-readable summary of what changed and why, shown to the user";

obj OverrunAlert {
    has headline: str,
        affected_task_title: str,
        proposed_new_time: str,
        observation: str;
}
sem OverrunAlert.headline = "Short alert headline, e.g. 'Your current task is taking longer than expected'";
sem OverrunAlert.affected_task_title = "Title of the next scheduled task that will be impacted by the overrun";
sem OverrunAlert.proposed_new_time = "Proposed new start time for the affected task in human-readable format, e.g. '3:30 PM'";
sem OverrunAlert.observation = "Behavioral observation about the user, e.g. 'You usually take longer on coding tasks. Starting the next task now helps avoid deadline pressure.'";

obj DurationEstimate {
    has suggested_minutes: int,
        confidence_pct: int,
        rationale: str;
}
sem DurationEstimate.suggested_minutes = "Estimated task duration in minutes based on title, category and history";
sem DurationEstimate.confidence_pct = "Confidence in this estimate 0-100, higher when more matching history exists";
sem DurationEstimate.rationale = "Brief explanation referencing historical patterns, e.g. 'Research tasks in your history typically run 40-60% longer than estimated'";

# ===== AI SCHEDULING — BYLLM FUNCTIONS =====

def suggest_schedule_slot(
    task_title: str,
    category: str,
    estimated_duration_minutes: int,
    due_date: str,
    existing_schedule: list[dict],
    user_productivity_peaks: dict
) -> ScheduleSlot by llm(temperature=0.1);
sem suggest_schedule_slot = "Suggest the optimal time slot to schedule a new task given the user's existing schedule and productivity patterns. Prefer slots that match the user's peak productivity hours for this task category. Avoid scheduling conflicts with existing tasks. Respect due dates — do not schedule past the due date. If no schedule data exists, suggest a reasonable working-hours slot starting from today.";
sem suggest_schedule_slot.existing_schedule = "List of already-scheduled tasks, each with start_date, start_time, end_time, title, category, is_locked fields";
sem suggest_schedule_slot.user_productivity_peaks = "Dict mapping hour (0-23 as string keys) to productivity score (0-100). Empty dict if no data yet.";

def suggest_alternative_slots(
    task_title: str,
    category: str,
    estimated_duration_minutes: int,
    original_slot: dict,
    existing_schedule: list[dict],
    category_overrun_ratios: dict,
    user_productivity_peaks: dict
) -> AlternativeSlots by llm(temperature=0.3);
sem suggest_alternative_slots = "Suggest exactly 3 alternative time slots for the task. Each suggested slot MUST NOT overlap with any existing task's effective occupied window. A task's effective window is [start_time, start_time + estimated_duration * overrun_ratio] where overrun_ratio comes from category_overrun_ratios (default 1.1 if category not listed). Compute the effective end time for every existing task before placing a new slot. Do not repeat the original_slot. Prefer slots near the user's productivity peaks for this category. Sort alternatives by productivity_score descending.";
sem suggest_alternative_slots.original_slot = "The current slot being reconsidered, with start_date, start_time, end_time fields. Do not suggest this slot.";
sem suggest_alternative_slots.existing_schedule = "All currently scheduled tasks. Each entry has: title, start_date, start_time, end_time, estimated_duration (minutes), category. Use estimated_duration and category_overrun_ratios to compute each task's effective occupied window before deciding if a slot is free.";
sem suggest_alternative_slots.category_overrun_ratios = "Dict mapping category name to overrun multiplier (e.g. {'Coding': 1.42, 'Meeting': 1.08}). Apply to estimated_duration to get the real occupied time. Use 1.1 for any category not listed.";
sem suggest_alternative_slots.user_productivity_peaks = "Dict mapping hour (0-23 as string keys) to productivity score (0-100). Empty dict if no data.";

def generate_schedule_explanation(
    task_title: str,
    category: str,
    scheduled_slot: dict,
    user_estimated_duration: int,
    historical_overrun_ratio: float,
    productivity_peaks: dict,
    due_date: str,
    surrounding_tasks: list[dict]
) -> ScheduleExplanation by llm(temperature=0.3);
sem generate_schedule_explanation = "Generate a detailed, transparent explanation of why a task was scheduled at a particular time slot. The explanation is shown to the user in a panel with four sections: workload analysis, duration adjustment, deadline urgency, and scoring factors. Make the reasoning concrete and reference the user's actual patterns where available.";
sem generate_schedule_explanation.historical_overrun_ratio = "Average ratio of actual/estimated duration for this task category. 1.0 means on-time, 1.4 means user takes 40% longer than estimated on average.";
sem generate_schedule_explanation.surrounding_tasks = "Tasks on the SAME DATE as the task being explained, scheduled within 3 hours before or after it. Use these as the actual workload context for this day. Each has title, start_time, end_time. Only reference tasks from this list — do not invent or reference tasks from other days.";

def detect_schedule_conflicts_and_replan(
    new_task: dict,
    current_schedule: list[dict],
    locked_task_ids: list[str]
) -> ReplanProposal by llm(temperature=0.1);
sem detect_schedule_conflicts_and_replan = "Detect if placing the new task causes time overlaps with existing scheduled tasks. If conflicts exist, propose the minimum set of task reschedules to resolve them. Never move tasks whose IDs appear in locked_task_ids. Prioritize moving lower-priority tasks first. If no conflicts, set has_conflict to false and return empty changes list.";
sem detect_schedule_conflicts_and_replan.new_task = "The newly added task with start_date, start_time, end_time, title, priority, estimated_duration fields";
sem detect_schedule_conflicts_and_replan.current_schedule = "All currently scheduled tasks with id, title, start_date, start_time, end_time, priority, is_locked fields";
sem detect_schedule_conflicts_and_replan.locked_task_ids = "List of task IDs that must not be rescheduled regardless of conflicts";

def generate_overrun_alert(
    running_task_title: str,
    estimated_minutes: int,
    elapsed_minutes: int,
    next_scheduled_tasks: list[dict]
) -> OverrunAlert by llm(temperature=0.2);
sem generate_overrun_alert = "Generate a helpful alert because the user's current task has exceeded its estimated duration. Identify the most critically impacted upcoming task (highest priority or nearest deadline) and suggest a realistic new start time for it. Include a brief observation about the user's typical behavior for context.";
sem generate_overrun_alert.next_scheduled_tasks = "Upcoming tasks ordered by scheduled start time, each with id, title, start_time, end_time, priority, is_locked fields";

def estimate_task_duration(
    task_title: str,
    category: str,
    historical_completions: list[dict]
) -> DurationEstimate by llm(temperature=0.1);
sem estimate_task_duration = "Estimate how long a task will realistically take based on its title, category, and the user's past completion data for similar tasks. Account for the user's typical overrun patterns. If no history exists, provide a reasonable estimate based on the task category and title alone.";
sem estimate_task_duration.historical_completions = "Past completed tasks with fields: task_title, category, estimated_duration (minutes), actual_duration (minutes)";

# ===== AI SCHEDULING WALKERS =====

walker:priv AIScheduleTask {
    has task_id: str;
    has all_task_data: list = [];
    has user_peaks: dict = {};
    has target_title: str = "";
    has target_category: str = "";
    has target_duration: int = 60;
    has target_due_date: str = "";
    has target_found: bool = False;

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect with Task entry {
        self.all_task_data.append({
            "id": here.id, "title": here.title,
            "start_date": here.start_date, "start_time": here.start_time,
            "end_time": here.end_time, "category": here.category,
            "is_locked": here.is_locked
        });
        if here.id == self.task_id {
            self.target_found = True;
            self.target_title = here.title;
            self.target_category = here.category;
            self.target_duration = here.estimated_duration;
            self.target_due_date = here.due_date;
        }
    }

    can collect_patterns with UserPatterns entry {
        self.user_peaks = here.productivity_peaks;
    }

    can finalize with Root exit {
        if not self.target_found {
            report {"error": "Task not found"};
            return;
        }
        existing_schedule = [
            t for t in self.all_task_data
            if t["id"] != self.task_id and t["start_date"] != "" and t["start_time"] != ""
        ];
        slot = suggest_schedule_slot(
            task_title=self.target_title,
            category=self.target_category,
            estimated_duration_minutes=self.target_duration,
            due_date=self.target_due_date,
            existing_schedule=existing_schedule,
            user_productivity_peaks=self.user_peaks
        );
        report {
            "task_id": self.task_id,
            "start_date": slot.start_date,
            "start_time": slot.start_time,
            "end_time": slot.end_time,
            "confidence": slot.confidence,
            "reasoning": slot.reasoning
        };
    }
}

walker:priv AIExplainSchedule {
    has task_id: str;
    has surrounding: list = [];
    has user_peaks: dict = {};
    has cat_ratios: dict = {};
    has history: list = [];
    has target_title: str = "";
    has target_category: str = "";
    has target_duration: int = 60;
    has target_due_date: str = "";
    has target_start_date: str = "";
    has target_start_time: str = "";
    has target_end_time: str = "";
    has target_found: bool = False;
    has task_node_ref: list = [];

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect_tasks with Task entry {
        if here.id == self.task_id {
            self.target_found = True;
            self.target_title = here.title;
            self.target_category = here.category;
            self.target_duration = here.estimated_duration;
            self.target_due_date = here.due_date;
            self.target_start_date = here.start_date;
            self.target_start_time = here.start_time;
            self.target_end_time = here.end_time;
            self.task_node_ref = [here];
        } elif here.start_date != "" and here.start_time != "" {
            self.surrounding.append({
                "title": here.title,
                "start_date": here.start_date,
                "start_time": here.start_time,
                "end_time": here.end_time
            });
        }
    }

    can collect_patterns with UserPatterns entry {
        self.user_peaks = here.productivity_peaks;
        self.cat_ratios = here.category_overrun_ratios;
    }

    can collect_history with TaskHistory entry {
        self.history.append({
            "task_title": here.task_title,
            "category": here.category,
            "estimated_duration": here.estimated_duration,
            "actual_duration": here.actual_duration
        });
    }

    can finalize with Root exit {
        if not self.target_found {
            report {"error": "Task not found"};
            return;
        }
        overrun_ratio = self.cat_ratios.get(self.target_category, 1.0) if self.target_category != "" else 1.0;
        slot_dict = {
            "start_date": self.target_start_date,
            "start_time": self.target_start_time,
            "end_time": self.target_end_time
        };
        # Filter surrounding to same date only, then narrow to tasks within 3 hours of target slot
        target_parts = self.target_start_time.split(":") if self.target_start_time else ["0", "0"];
        target_mins = int(target_parts[0]) * 60 + int(target_parts[1]);
        same_day_adjacent = [];
        for s in self.surrounding {
            if s.get("start_date", "") != self.target_start_date { continue; }
            s_parts = s["start_time"].split(":");
            s_mins = int(s_parts[0]) * 60 + int(s_parts[1]);
            if abs(s_mins - target_mins) <= 180 {
                same_day_adjacent.append({"title": s["title"], "start_time": s["start_time"], "end_time": s["end_time"]});
            }
        }
        explanation = generate_schedule_explanation(
            task_title=self.target_title,
            category=self.target_category,
            scheduled_slot=slot_dict,
            user_estimated_duration=self.target_duration,
            historical_overrun_ratio=overrun_ratio,
            productivity_peaks=self.user_peaks,
            due_date=self.target_due_date,
            surrounding_tasks=same_day_adjacent
        );
        result_dict = {
            "headline": explanation.headline,
            "workload_insight": explanation.workload_insight,
            "duration_insight": explanation.duration_insight,
            "deadline_insight": explanation.deadline_insight,
            "productivity_score": explanation.productivity_score,
            "ai_adjusted_duration": explanation.ai_adjusted_duration,
            "historical_accuracy_pct": explanation.historical_accuracy_pct,
            "user_estimated_duration": self.target_duration,
            "tip": explanation.tip,
            "factors": [{"factor": f.factor, "score": f.score} for f in explanation.factors]
        };
        # Persist explanation to Task node so future hovers are instant
        if self.task_node_ref {
            self.task_node_ref[0].ai_explanation = json_dumps(result_dict);
            self.task_node_ref[0].ai_confidence = explanation.productivity_score;
        }
        report result_dict;
    }
}

walker:priv GenerateAllExplanations {
    has task_node_refs: list = [];
    has task_data_list: list = [];
    has surrounding: list = [];
    has user_peaks: dict = {};
    has cat_ratios: dict = {};
    has generated: int = 0;

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect with Task entry {
        if here.start_date != "" and here.start_time != "" and here.status != "done" {
            self.surrounding.append({
                "title": here.title,
                "start_date": here.start_date,
                "start_time": here.start_time,
                "end_time": here.end_time
            });
            if here.ai_explanation == "" and len(self.task_data_list) < 5 {
                self.task_node_refs.append(here);
                self.task_data_list.append({
                    "title": here.title,
                    "category": here.category,
                    "estimated_duration": here.estimated_duration,
                    "due_date": here.due_date,
                    "start_date": here.start_date,
                    "start_time": here.start_time,
                    "end_time": here.end_time
                });
            }
        }
    }

    can collect_patterns with UserPatterns entry {
        self.user_peaks = here.productivity_peaks;
        self.cat_ratios = here.category_overrun_ratios;
    }

    can finalize with Root exit {
        for i in range(len(self.task_data_list)) {
            t = self.task_data_list[i];
            task_node = self.task_node_refs[i];
            overrun_ratio = self.cat_ratios.get(t["category"], 1.0) if t["category"] != "" else 1.0;
            slot_dict = {
                "start_date": t["start_date"],
                "start_time": t["start_time"],
                "end_time": t["end_time"]
            };
            t_parts = t["start_time"].split(":");
            t_mins = int(t_parts[0]) * 60 + int(t_parts[1]);
            surrounding_others = [];
            for s in self.surrounding {
                if s.get("start_date", "") != t["start_date"] { continue; }
                if s["title"] == t["title"] and s["start_time"] == t["start_time"] { continue; }
                s_parts = s["start_time"].split(":");
                s_mins = int(s_parts[0]) * 60 + int(s_parts[1]);
                if abs(s_mins - t_mins) <= 180 {
                    surrounding_others.append({"title": s["title"], "start_time": s["start_time"], "end_time": s["end_time"]});
                }
            }
            explanation = generate_schedule_explanation(
                task_title=t["title"],
                category=t["category"],
                scheduled_slot=slot_dict,
                user_estimated_duration=t["estimated_duration"],
                historical_overrun_ratio=overrun_ratio,
                productivity_peaks=self.user_peaks,
                due_date=t["due_date"],
                surrounding_tasks=surrounding_others
            );
            result_dict = {
                "headline": explanation.headline,
                "workload_insight": explanation.workload_insight,
                "duration_insight": explanation.duration_insight,
                "deadline_insight": explanation.deadline_insight,
                "productivity_score": explanation.productivity_score,
                "ai_adjusted_duration": explanation.ai_adjusted_duration,
                "historical_accuracy_pct": explanation.historical_accuracy_pct,
                "user_estimated_duration": t["estimated_duration"],
                "tip": explanation.tip,
                "factors": [{"factor": f.factor, "score": f.score} for f in explanation.factors]
            };
            task_node.ai_explanation = json_dumps(result_dict);
            task_node.ai_confidence = explanation.productivity_score;
            self.generated += 1;
        }
        report {"generated": self.generated};
    }
}

walker:priv AIGetAlternativeSlots {
    has task_id: str;
    has all_tasks: list = [];
    has user_peaks: dict = {};
    has cat_ratios: dict = {};
    has target_found: bool = False;
    has target_title: str = "";
    has target_category: str = "";
    has target_duration: int = 60;
    has target_start_date: str = "";
    has target_start_time: str = "";
    has target_end_time: str = "";

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect_tasks with Task entry {
        if here.id == self.task_id {
            self.target_found = True;
            self.target_title = here.title;
            self.target_category = here.category;
            self.target_duration = here.estimated_duration;
            self.target_start_date = here.start_date;
            self.target_start_time = here.start_time;
            self.target_end_time = here.end_time;
        }
        if here.start_date != "" and here.start_time != "" and here.id != self.task_id and here.status != "done" {
            self.all_tasks.append({
                "title": here.title,
                "start_date": here.start_date,
                "start_time": here.start_time,
                "end_time": here.end_time,
                "estimated_duration": here.estimated_duration,
                "category": here.category
            });
        }
    }

    can collect_patterns with UserPatterns entry {
        self.user_peaks = here.productivity_peaks;
        self.cat_ratios = here.category_overrun_ratios;
    }

    can finalize with Root exit {
        if not self.target_found {
            report {"slots": []};
            return;
        }
        # Merge user's real overrun ratios with hardcoded defaults for any missing categories
        default_ratios = {"Coding": 1.42, "Research": 1.35, "Writing": 1.22, "Meeting": 1.08, "Admin": 1.05};
        merged_ratios = {**default_ratios, **self.cat_ratios};
        original = {
            "start_date": self.target_start_date,
            "start_time": self.target_start_time,
            "end_time": self.target_end_time
        };
        result = suggest_alternative_slots(
            task_title=self.target_title,
            category=self.target_category,
            estimated_duration_minutes=self.target_duration,
            original_slot=original,
            existing_schedule=self.all_tasks,
            category_overrun_ratios=merged_ratios,
            user_productivity_peaks=self.user_peaks
        );
        report {
            "slots": [
                {
                    "start_date": s.start_date,
                    "start_time": s.start_time,
                    "end_time": s.end_time,
                    "productivity_score": s.productivity_score,
                    "reasoning": s.reasoning
                }
                for s in result.slots
            ]
        };
    }
}

walker:priv AIReplanSchedule {
    has new_task_id: str;
    has all_tasks: list = [];
    has new_task_data: dict = {};
    has found: bool = False;

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect_tasks with Task entry {
        task_dict = {
            "id": here.id, "title": here.title,
            "start_date": here.start_date, "start_time": here.start_time,
            "end_time": here.end_time, "priority": here.priority,
            "is_locked": here.is_locked, "estimated_duration": here.estimated_duration
        };
        self.all_tasks.append(task_dict);
        if here.id == self.new_task_id {
            self.found = True;
            self.new_task_data = task_dict;
        }
    }

    can finalize with Root exit {
        if not self.found {
            report {"has_conflict": False, "changes": [], "explanation": "Task not found"};
            return;
        }
        locked_ids = [t["id"] for t in self.all_tasks if t["is_locked"]];
        proposal = detect_schedule_conflicts_and_replan(
            new_task=self.new_task_data,
            current_schedule=self.all_tasks,
            locked_task_ids=locked_ids
        );
        report {
            "has_conflict": proposal.has_conflict,
            "changes": [
                {
                    "task_id": c.task_id,
                    "task_title": c.task_title,
                    "new_start_date": c.new_start_date,
                    "new_start_time": c.new_start_time,
                    "new_end_time": c.new_end_time,
                    "reason": c.reason
                }
                for c in proposal.changes
            ],
            "explanation": proposal.explanation
        };
    }
}

walker:priv AIEstimateDuration {
    has task_title: str,
        category: str;
    has history: list = [];

    can start with Root entry {
        visit [-->];
    }

    can collect_history with TaskHistory entry {
        if self.category == "" or here.category == self.category {
            self.history.append({
                "task_title": here.task_title,
                "category": here.category,
                "estimated_duration": here.estimated_duration,
                "actual_duration": here.actual_duration
            });
        }
    }

    can finalize with Root exit {
        estimate = estimate_task_duration(
            task_title=self.task_title,
            category=self.category,
            historical_completions=self.history
        );
        report {
            "suggested_minutes": estimate.suggested_minutes,
            "confidence_pct": estimate.confidence_pct,
            "rationale": estimate.rationale
        };
    }
}

walker:priv AIGenerateOverrunAlert {
    has task_id: str,
        elapsed_minutes: int;
    has upcoming: list = [];
    has running_title: str = "";
    has running_est_duration: int = 60;
    has target_found: bool = False;

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect_tasks with Task entry {
        if here.id == self.task_id {
            self.target_found = True;
            self.running_title = here.title;
            self.running_est_duration = here.estimated_duration;
        } elif here.start_date != "" and here.start_time != "" and here.status != "done" {
            self.upcoming.append({
                "id": here.id, "title": here.title,
                "start_time": here.start_time, "end_time": here.end_time,
                "priority": here.priority, "is_locked": here.is_locked
            });
        }
    }

    can finalize with Root exit {
        if not self.target_found {
            report {"error": "Task not found"};
            return;
        }
        alert = generate_overrun_alert(
            running_task_title=self.running_title,
            estimated_minutes=self.running_est_duration,
            elapsed_minutes=self.elapsed_minutes,
            next_scheduled_tasks=self.upcoming
        );
        report {
            "headline": alert.headline,
            "affected_task_title": alert.affected_task_title,
            "proposed_new_time": alert.proposed_new_time,
            "observation": alert.observation,
            "running_task_title": self.running_title,
            "estimated_minutes": self.running_est_duration,
            "elapsed_minutes": self.elapsed_minutes
        };
    }
}

walker:priv UpdateTaskLock {
    has task_id: str,
        is_locked: bool;

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can do_update with Task entry {
        if here.id == self.task_id {
            here.is_locked = self.is_locked;
            report {"id": here.id, "is_locked": here.is_locked};
        }
    }
}

walker:priv AIRescheduleTask {
    has task_id: str,
        locked_task_ids: list = [];
    has all_tasks: list = [];
    has target_task: dict = {};
    has target_found: bool = False;

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect with Task entry {
        if here.start_date != "" and here.start_time != "" and here.status != "done" {
            td = {
                "id": here.id, "title": here.title,
                "start_date": here.start_date, "start_time": here.start_time,
                "end_time": here.end_time, "priority": here.priority,
                "is_locked": here.is_locked, "estimated_duration": here.estimated_duration
            };
            self.all_tasks.append(td);
            if here.id == self.task_id {
                self.target_found = True;
                self.target_task = {
                    "id": here.id, "title": here.title,
                    "start_date": here.start_date, "start_time": here.start_time,
                    "end_time": here.end_time, "priority": here.priority,
                    "estimated_duration": here.estimated_duration
                };
            }
            if here.is_locked {
                self.locked_task_ids.append(here.id);
            }
        }
    }

    can finalize with Root exit {
        if not self.target_found {
            report {"has_conflict": False, "changes": [], "explanation": "Task not found or not scheduled."};
            return;
        }
        other_tasks = [t for t in self.all_tasks if t["id"] != self.task_id];
        proposal = detect_schedule_conflicts_and_replan(
            new_task=self.target_task,
            current_schedule=other_tasks,
            locked_task_ids=self.locked_task_ids
        );
        report {
            "has_conflict": proposal.has_conflict,
            "explanation": proposal.explanation,
            "changes": [
                {
                    "task_id": c.task_id,
                    "task_title": c.task_title,
                    "new_start_date": c.new_start_date,
                    "new_start_time": c.new_start_time,
                    "new_end_time": c.new_end_time,
                    "reason": c.reason
                }
                for c in proposal.changes
            ]
        };
    }
}

walker:priv ApplyReplanChanges {
    has changes: list;

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can do_update with Task entry {
        for change in self.changes {
            if here.id == change["task_id"] and not here.is_locked {
                here.start_date = change["new_start_date"];
                here.start_time = change["new_start_time"];
                here.end_time = change["new_end_time"];
                here.ai_explanation = "";
                here.schedule_source = ScheduleSource.AI_OPTIMIZED;
            }
        }
        report {"applied": True};
    }
}

walker:priv RolloverPastTasks {
    has moved_count: int = 0,
        moved_titles: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can rollover with Task entry {
        if here.start_date == "" or here.status == "done" or here.is_locked {
            return;
        }
        today_str = datetime.now().date().isoformat();
        if here.start_date < today_str {
            d = datetime.fromisoformat(here.start_date);
            next_week = d + timedelta(days=7);
            here.start_date = next_week.date().isoformat();
            here.ai_explanation = "";
            self.moved_count += 1;
            self.moved_titles.append(here.title);
        }
    }

    can report_moved with Root exit {
        report {"moved_count": self.moved_count, "moved_titles": self.moved_titles};
    }
}

walker:priv GetActiveTask {
    has active_id: str = "";
    has active_task: dict = {};
    has timer_start: str = "";
    has timer_accumulated: int = 0;
    has is_running: bool = False;

    can start with Root entry {
        visit [-->];
    }

    can read_active with ActiveTask entry {
        if self.active_id == "" {
            self.active_id = here.active_task_id;
            self.timer_start = here.timer_start;
            self.timer_accumulated = here.timer_accumulated;
            self.is_running = here.is_running;
        }
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can find_task with Task entry {
        if here.id == self.active_id {
            self.active_task = {
                "id": here.id, "title": here.title,
                "category": here.category, "estimated_duration": here.estimated_duration,
                "start_date": here.start_date, "start_time": here.start_time,
                "end_time": here.end_time, "priority": here.priority
            };
        }
    }

    can finalize with Root exit {
        if self.active_id == "" or len(self.active_task) == 0 {
            report {"active": False};
            return;
        }
        report {
            "active": True,
            "task": self.active_task,
            "timer_start": self.timer_start,
            "timer_accumulated": self.timer_accumulated,
            "is_running": self.is_running
        };
    }
}

walker:priv StartTaskTimer {
    has task_id: str;
    has found_active: bool = False;

    can run with Root entry {
        visit [-->];
        report {"task_id": self.task_id, "started": True};
    }

    can update_task with Task entry {
        if here.id == self.task_id and here.status != "done" {
            here.status = "in_progress";
        }
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can setup_active with ActiveTask entry {
        if here.active_task_id == self.task_id {
            self.found_active = True;
            now = datetime.now().isoformat();
            if here.timer_start == "" {
                here.timer_start = now;
            }
            here.last_updated = now;
            here.is_running = True;
        }
    }

    can create_active with Root exit {
        if not self.found_active {
            now = datetime.now().isoformat();
            here ++> ActiveTask(
                active_task_id=self.task_id,
                timer_start=now,
                timer_accumulated=0,
                is_running=True,
                last_updated=now
            );
        }
    }
}

walker:priv ListActiveTasks {
    has active_tasks: list = [];

    can run with Root entry {
        visit [-->];
    }

    can gather with ActiveTask entry {
        self.active_tasks.append({
            "active_task_id": here.active_task_id,
            "timer_start": here.timer_start,
            "timer_accumulated": here.timer_accumulated,
            "is_running": here.is_running,
            "last_updated": here.last_updated
        });
    }

    can finalize with Root exit {
        report self.active_tasks;
    }
}

walker:priv PauseTaskTimer {
    has task_id: str,
        elapsed_minutes: int;

    can run with Root entry {
        visit [-->];
        report {"task_id": self.task_id, "paused": True, "elapsed_minutes": self.elapsed_minutes};
    }

    can do_pause with ActiveTask entry {
        if here.active_task_id == self.task_id {
            here.timer_accumulated = self.elapsed_minutes;
            here.is_running = False;
            here.last_updated = datetime.now().isoformat();
        }
    }
}

walker:priv FinishTaskTimer {
    has task_id: str,
        actual_duration: int;
    has started_at: str = "";

    can run with Root entry {
        global task_history_counter;
        visit [-->];
        # Background analysis — update user patterns after each task finish
        root spawn AnalyzeUserPatterns();
        report {"task_id": self.task_id, "finished": True, "actual_duration": self.actual_duration};
    }

    can read_active with ActiveTask entry {
        if here.active_task_id == self.task_id {
            self.started_at = here.timer_start;
            here.last_updated = datetime.now().isoformat();
            del here;
        }
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can record_task with Task entry {
        if here.id == self.task_id {
            here.actual_duration = self.actual_duration;
            here.status = "done";

            global task_history_counter;
            task_history_counter += 1;
            hist_id = "hist_" + str(task_history_counter);
            root ++> TaskHistory(
                id=hist_id,
                task_title=here.title,
                category=here.category,
                estimated_duration=here.estimated_duration,
                actual_duration=self.actual_duration,
                started_at=self.started_at,
                completed_at=datetime.now().isoformat()
            );
        }
    }
}

walker:priv RecordOutOfScopeTime {
    has minutes: int;
    has found: bool = False;

    can run with Root entry {
        visit [-->];
    }

    can record with UserPatterns entry {
        self.found = True;
        here.out_of_scope_minutes = here.out_of_scope_minutes + self.minutes;
        here.last_updated = str(datetime.now());
    }

    can create_if_missing with Root exit {
        if not self.found {
            here ++> UserPatterns(out_of_scope_minutes=self.minutes);
        }
    }
}

walker:priv AnalyzeUserPatterns {
    has history: list = [];
    has activity_reports: list = [];
    has patterns_node: any = None;

    can start with Root entry {
        visit [-->];
    }

    can collect_history with TaskHistory entry {
        if here.estimated_duration > 0 and here.actual_duration > 0 {
            self.history.append({
                "category": here.category,
                "estimated": here.estimated_duration,
                "actual": here.actual_duration
            });
        }
    }

    can collect_reports with ActivityReport entry {
        cat = here.task_category if here.task_category else "Other";
        self.activity_reports.append({
            "category": cat,
            "on_task": here.on_task
        });
    }

    can find_patterns with UserPatterns entry {
        self.patterns_node = here;
    }

    can finalize with Root exit {
        if len(self.history) == 0 and len(self.activity_reports) == 0 { return; }

        # --- Overrun ratios from task history ---
        cat_sums: dict = {};
        cat_counts: dict = {};
        for h in self.history {
            cat = h["category"] if h["category"] else "Other";
            if cat not in cat_sums {
                cat_sums[cat] = 0.0;
                cat_counts[cat] = 0;
            }
            cat_sums[cat] = cat_sums[cat] + (h["actual"] / h["estimated"]);
            cat_counts[cat] = cat_counts[cat] + 1;
        }
        new_ratios: dict = {};
        for cat in cat_sums {
            new_ratios[cat] = round(cat_sums[cat] / cat_counts[cat], 2);
        }

        # --- Productivity scores from activity reports ---
        # on_task_counts[cat] = total checks, on_task_hits[cat] = on-task checks
        on_task_total: dict = {};
        on_task_hits: dict = {};
        for r in self.activity_reports {
            cat = r["category"];
            if cat not in on_task_total {
                on_task_total[cat] = 0;
                on_task_hits[cat] = 0;
            }
            on_task_total[cat] = on_task_total[cat] + 1;
            if r["on_task"] {
                on_task_hits[cat] = on_task_hits[cat] + 1;
            }
        }
        new_productivity: dict = {};
        for cat in on_task_total {
            total = on_task_total[cat];
            hits = on_task_hits[cat];
            new_productivity[cat] = round(hits / total, 2) if total > 0 else 1.0;
        }

        # --- Adjust overrun ratios by productivity ---
        # If a category has low productivity, effective work pace is slower,
        # so inflate the overrun ratio to compensate: adjusted = raw / productivity
        for cat in new_ratios {
            if cat in new_productivity and new_productivity[cat] > 0.0 {
                adjusted = round(new_ratios[cat] / new_productivity[cat], 2);
                new_ratios[cat] = adjusted;
            }
        }

        # --- Persist ---
        if self.patterns_node {
            if len(new_ratios) > 0 {
                self.patterns_node.category_overrun_ratios = new_ratios;
            }
            if len(new_productivity) > 0 {
                self.patterns_node.category_productivity = new_productivity;
            }
            self.patterns_node.last_updated = str(datetime.now());
        } else {
            root ++> UserPatterns(
                category_overrun_ratios=new_ratios,
                category_productivity=new_productivity
            );
        }
        report {
            "updated": True,
            "ratios": new_ratios,
            "productivity": new_productivity
        };
    }
}

walker:priv SeedDemoData {
    has already_seeded: bool = False;

    can check_seeded with Root entry {
        visit [-->];
    }

    can detect_space with Space entry {
        self.already_seeded = True;
    }

    can detect_list with List entry {
        self.already_seeded = True;
    }

    can seed with Root exit {
        global space_counter, list_counter, task_counter, task_history_counter;
        if self.already_seeded {
            report {"seeded": False, "reason": "Already has data"};
            return;
        }

        # Create lists directly on root (no spaces)
        list_counter += 1;
        l1 = here ++> List(id="list_" + str(list_counter), name="AI Project", space_id="", color="indigo");

        list_counter += 1;
        l2 = here ++> List(id="list_" + str(list_counter), name="Research", space_id="", color="teal");

        list_counter += 1;
        l3 = here ++> List(id="list_" + str(list_counter), name="Habits", space_id="", color="green");

        lid = l1[0].id;
        rid = l2[0].id;

        # Create scheduled tasks — connect to parent List
        task_counter += 1;
        l2[0] ++> Task(
            id="task_" + str(task_counter), title="Research AI scheduling algorithms",
            description="Survey existing approaches to AI-driven calendar scheduling and time-boxing.",
            status="todo", priority="high", category="Research", estimated_duration=120,
            list_id=rid, start_date="2026-03-09", start_time="09:00", end_time="11:00",
            ai_confidence=87, due_date="2026-03-11"
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Team standup",
            description="Daily sync with the project team.",
            status="todo", priority="normal", category="Meeting", estimated_duration=30,
            list_id=lid, start_date="2026-03-09", start_time="11:00", end_time="11:30",
            ai_confidence=95, due_date=""
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Design task data model",
            description="Define the Task node fields, edges, and relationships for the scheduling engine.",
            status="todo", priority="high", category="Coding", estimated_duration=90,
            list_id=lid, start_date="2026-03-09", start_time="11:30", end_time="13:00",
            ai_confidence=73, due_date="2026-03-10"
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Write project proposal",
            description="Draft the 3-page proposal covering scope, timeline, and AI features.",
            status="todo", priority="urgent", category="Writing", estimated_duration=150,
            list_id=lid, start_date="2026-03-10", start_time="09:00", end_time="11:30",
            ai_confidence=68, due_date="2026-03-10"
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Code review session",
            description="Review PRs with the team and discuss architectural decisions.",
            status="todo", priority="normal", category="Meeting", estimated_duration=60,
            list_id=lid, start_date="2026-03-10", start_time="14:00", end_time="15:00",
            ai_confidence=91, due_date=""
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Implement AI scheduler walker",
            description="Build the AIScheduleTask walker using byLLM to suggest optimal time slots.",
            status="todo", priority="urgent", category="Coding", estimated_duration=180,
            list_id=lid, start_date="2026-03-11", start_time="09:00", end_time="12:00",
            ai_confidence=55, due_date="2026-03-13"
        );

        task_counter += 1;
        l2[0] ++> Task(
            id="task_" + str(task_counter), title="User testing interviews",
            description="Conduct 3 x 40-min moderated sessions with study participants.",
            status="todo", priority="high", category="Research", estimated_duration=120,
            list_id=rid, start_date="2026-03-11", start_time="12:00", end_time="14:00",
            ai_confidence=82, due_date="2026-03-12"
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Update API documentation",
            description="Document all new walker endpoints and their request/response schemas.",
            status="todo", priority="normal", category="Writing", estimated_duration=120,
            list_id=lid, start_date="2026-03-12", start_time="10:00", end_time="12:00",
            ai_confidence=78, due_date="2026-03-14"
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Admin: respond to emails & planning",
            description="Clear inbox and plan next sprint backlog.",
            status="todo", priority="low", category="Admin", estimated_duration=60,
            list_id=lid, start_date="2026-03-12", start_time="13:00", end_time="14:00",
            ai_confidence=90, due_date=""
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Sprint retrospective",
            description="Team retro: what went well, what didn't, action items.",
            status="todo", priority="normal", category="Meeting", estimated_duration=90,
            list_id=lid, start_date="2026-03-13", start_time="14:00", end_time="15:30",
            ai_confidence=88, due_date=""
        );

        # Unscheduled backlog tasks
        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Refactor authentication module",
            description="Clean up the auth flow and add proper error handling.",
            status="todo", priority="high", category="Coding", estimated_duration=120,
            list_id=lid, start_date="", start_time="", end_time="",
            ai_confidence=0, due_date="2026-03-20"
        );

        task_counter += 1;
        l1[0] ++> Task(
            id="task_" + str(task_counter), title="Set up CI/CD pipeline",
            description="Configure GitHub Actions for automated testing and deployment.",
            status="todo", priority="normal", category="Admin", estimated_duration=90,
            list_id=lid, start_date="", start_time="", end_time="",
            ai_confidence=0, due_date="2026-03-21"
        );

        # Seed task history for analytics
        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Literature review",
            category="Research", estimated_duration=90, actual_duration=130,
            started_at="2026-03-03T10:00:00",
            completed_at="2026-03-03T11:30:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Write introduction section",
            category="Writing", estimated_duration=60, actual_duration=75,
            started_at="2026-03-03T12:45:00",
            completed_at="2026-03-03T14:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Build prototype UI",
            category="Coding", estimated_duration=120, actual_duration=175,
            started_at="2026-03-04T09:05:00",
            completed_at="2026-03-04T12:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Weekly planning meeting",
            category="Meeting", estimated_duration=60, actual_duration=65,
            started_at="2026-03-04T13:55:00",
            completed_at="2026-03-04T15:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Fix auth bug",
            category="Coding", estimated_duration=45, actual_duration=90,
            started_at="2026-03-05T09:30:00",
            completed_at="2026-03-05T11:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Survey design & distribution",
            category="Research", estimated_duration=60, actual_duration=80,
            started_at="2026-03-06T08:40:00",
            completed_at="2026-03-06T10:00:00"
        );

        # Seed user productivity patterns
        here ++> UserPatterns(
            productivity_peaks={
                "8": 55, "9": 88, "10": 92, "11": 85,
                "12": 40, "13": 38, "14": 75, "15": 72,
                "16": 60, "17": 45, "18": 30
            },
            category_overrun_ratios={
                "Coding": 1.42, "Research": 1.35,
                "Writing": 1.22, "Meeting": 1.08, "Admin": 1.05
            },
            last_updated="2026-03-06T18:00:00"
        );

        report {"seeded": True, "lists": 3, "tasks": 12};
    }
}

walker:priv GetUserPatterns {
    has found: bool = False;

    can run with Root entry {
        visit [-->];
    }

    can retrieve with UserPatterns entry {
        self.found = True;
        report {
            "productivity_peaks": here.productivity_peaks,
            "category_overrun_ratios": here.category_overrun_ratios,
            "category_productivity": here.category_productivity,
            "out_of_scope_minutes": here.out_of_scope_minutes
        };
    }

    can fallback with Root exit {
        if not self.found {
            report {
                "productivity_peaks": {},
                "category_overrun_ratios": {},
                "category_productivity": {},
                "out_of_scope_minutes": 0
            };
        }
    }
}

walker:priv UpdateUserPatterns {
    has productivity_peaks: dict = {},
        category_overrun_ratios: dict = {};
    has found: bool = False;

    can run with Root entry {
        visit [-->];
    }

    can update with UserPatterns entry {
        self.found = True;
        here.productivity_peaks = self.productivity_peaks;
        here.category_overrun_ratios = self.category_overrun_ratios;
        report {
            "productivity_peaks": here.productivity_peaks,
            "category_overrun_ratios": here.category_overrun_ratios
        };
    }

    can create_if_missing with Root exit {
        if not self.found {
            here ++> UserPatterns(
                productivity_peaks=self.productivity_peaks,
                category_overrun_ratios=self.category_overrun_ratios
            );
            report {
                "productivity_peaks": self.productivity_peaks,
                "category_overrun_ratios": self.category_overrun_ratios
            };
        }
    }
}

# ===== SCHEDULE CONFLICT HELPERS =====

def detect_conflicts_with_overrun(tasks: list) -> list {
    default_ratios = {"Coding": 1.42, "Research": 1.35, "Writing": 1.22, "Meeting": 1.08, "Admin": 1.05};
    conflicting_ids = [];
    scheduled = [t for t in tasks if t.get("start_date") and t.get("start_time") and t.get("status", "") != "done"];
    for a in scheduled {
        for b in scheduled {
            if a["id"] == b["id"] { continue; }
            if a["start_date"] != b["start_date"] { continue; }
            pa = a["start_time"].split(":");
            a_start = int(pa[0]) * 60 + int(pa[1]);
            a_dur = a.get("estimated_duration") or 60;
            a_ratio = default_ratios.get(a.get("category", ""), 1.1);
            a_end = a_start + int(a_dur * a_ratio + 0.5);
            pb = b["start_time"].split(":");
            b_start = int(pb[0]) * 60 + int(pb[1]);
            b_dur = b.get("estimated_duration") or 60;
            b_ratio = default_ratios.get(b.get("category", ""), 1.1);
            b_end = b_start + int(b_dur * b_ratio + 0.5);
            if a_start < b_end and b_start < a_end {
                if a["id"] not in conflicting_ids { conflicting_ids.append(a["id"]); }
            }
        }
    }
    return conflicting_ids;
}

def compute_blocked_slots(tasks: list, movable_ids: list) -> list {
    # Include effective windows of ALL tasks NOT being rescheduled this pass
    # so the LLM knows every occupied slot and can avoid placing tasks there.
    # effective_end = MAX(actual end_time, start_time + estimated_duration * overrun_ratio)
    # This ensures the blocked window covers both the calendar-visible end and the overrun.
    default_ratios = {"Coding": 1.42, "Research": 1.35, "Writing": 1.22, "Meeting": 1.08, "Admin": 1.05};
    blocked = [];
    for t in tasks {
        if t["id"] in movable_ids { continue; }
        if not t.get("start_date") or not t.get("start_time") { continue; }
        p = t["start_time"].split(":");
        start_mins = int(p[0]) * 60 + int(p[1]);
        dur = t.get("estimated_duration") or 60;
        ratio = default_ratios.get(t.get("category", ""), 1.1);
        eff_end_mins = start_mins + int(dur * ratio + 0.5);
        # Also respect the task's explicit end_time if it extends further
        if t.get("end_time") {
            ep = t["end_time"].split(":");
            explicit_end = int(ep[0]) * 60 + int(ep[1]);
            if explicit_end > eff_end_mins { eff_end_mins = explicit_end; }
        }
        eff_end_str = str(eff_end_mins // 60).zfill(2) + ":" + str(eff_end_mins % 60).zfill(2);
        blocked.append({
            "task_id": t["id"], "title": t["title"],
            "date": t["start_date"], "start_time": t["start_time"],
            "effective_end_time": eff_end_str,
            "is_locked": t.get("is_locked", False)
        });
    }
    return blocked;
}

# ===== AI SCHEDULE OPTIMIZATION — BYLLM =====

obj OptimizationPoint {
    has title: str,
        description: str;
}
sem OptimizationPoint.title = "Short title for this optimization, e.g. 'Academic Work Clustered Morning'";
sem OptimizationPoint.description = "One-sentence explanation of this optimization and the benefit it provides to the user";

obj ScheduleOptimization {
    has overview: str,
        optimizations: list[OptimizationPoint],
        changes: list[ScheduleChange],
        all_conflicts_resolved: bool,
        total_minutes: int;
}
sem ScheduleOptimization.overview = "2-3 sentence summary of how the optimized schedule improves on the current one, referencing specific productivity patterns and conflicts resolved";
sem ScheduleOptimization.optimizations = "3-5 key optimization decisions the AI made, each explaining a specific improvement to the schedule";
sem ScheduleOptimization.changes = "All tasks that need to be rescheduled to resolve conflicts and improve schedule quality. Only include tasks that actually move";
sem ScheduleOptimization.all_conflicts_resolved = "True if every detected time overlap between tasks is eliminated by the proposed changes";
sem ScheduleOptimization.total_minutes = "Sum of scheduled durations in minutes across all tasks after optimization";

def optimize_conflicted_schedule(
    current_schedule: list[dict],
    conflicting_task_ids: list[str],
    locked_task_ids: list[str],
    blocked_slots: list[dict],
    user_productivity_peaks: dict
) -> ScheduleOptimization by llm(temperature=0.2);
sem optimize_conflicted_schedule = "Reschedule ONLY the tasks provided in current_schedule (which are exactly the conflicting tasks) to resolve all time overlaps. STEP 1: Treat every entry in blocked_slots as an immovable hard constraint — no rescheduled task may start before that entry's effective_end_time on the same date. STEP 2: A rescheduled task's own effective window is [new_start_time, new_start_time + estimated_duration * overrun_ratio] where overrun_ratios: Coding=1.42, Research=1.35, Writing=1.22, Meeting=1.08, Admin=1.05, others=1.1. STEP 3: Choose new_start_time so that: (a) the task's effective window [new_start, new_start + dur*ratio] does not overlap ANY blocked_slot's [start_time, effective_end_time] on the same date, AND (b) rescheduled tasks do not overlap each other. Set new_end_time = new_start_time + estimated_duration (no overrun, just raw duration). Align with productivity peaks and keep tasks within reasonable working hours (07:00-22:00).";
sem optimize_conflicted_schedule.current_schedule = "Only the tasks that must be rescheduled (exactly the tasks in conflicting_task_ids). All other fixed tasks are represented in blocked_slots as hard constraints.";
sem optimize_conflicted_schedule.conflicting_task_ids = "Exactly these task IDs must be rescheduled. Do not move any task not in this list.";
sem optimize_conflicted_schedule.locked_task_ids = "ABSOLUTE CONSTRAINT: these task IDs must NEVER be moved or rescheduled under any circumstances. They are immovable anchors. If a conflicting_task_id also appears here, treat it as fixed and move the other conflicting task instead.";
sem optimize_conflicted_schedule.blocked_slots = "HARD CONSTRAINTS: occupied windows of every non-conflicting task, including overrun. Each entry has start_time and effective_end_time on a given date. No rescheduled task's effective window may overlap any of these. is_locked=true entries are especially critical.";
sem optimize_conflicted_schedule.user_productivity_peaks = "Dict mapping hour (0-23 as string keys) to productivity score (0-100). Use this to place demanding tasks in high-score slots.";

walker:priv AIOptimizeSchedule {
    has conflicting_task_ids: list;
    has date_range: list = [];
    has optimize_only_ids: list = [];
    has all_tasks: list = [];
    has user_peaks: dict = {};
    has locked_ids: list = [];

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect_tasks with Task entry {
        if here.start_date != "" and here.start_time != "" and here.status != "done" {
            if len(self.date_range) > 0 and here.start_date not in self.date_range {
                return;
            }
            self.all_tasks.append({
                "id": here.id, "title": here.title,
                "start_date": here.start_date, "start_time": here.start_time,
                "end_time": here.end_time, "priority": here.priority,
                "is_locked": here.is_locked, "category": here.category,
                "estimated_duration": here.estimated_duration
            });
            if here.is_locked {
                self.locked_ids.append(here.id);
            } elif len(self.optimize_only_ids) > 0 and here.id not in self.optimize_only_ids {
                self.locked_ids.append(here.id);
            }
        }
    }

    can collect_peaks with UserPatterns entry {
        self.user_peaks = here.productivity_peaks;
    }

    can finalize with Root exit {
        if len(self.all_tasks) == 0 {
            report {
                "overview": "No scheduled tasks found to optimize.",
                "optimizations": [],
                "changes": [],
                "all_conflicts_resolved": True,
                "total_minutes": 0
            };
            return;
        }

        MAX_ITER = 4;   # iterations per attempt
        MAX_RETRIES = 3; # full retry attempts if result still has conflicts
        base_conflict_ids = [cid for cid in self.conflicting_task_ids if cid not in self.locked_ids];
        merged_changes = {};
        final_overview = "";
        final_optimizations = [];
        current_conflict_ids = [];

        for retry in range(MAX_RETRIES) {
            # Reset virtual schedule and conflicts for each retry attempt
            virtual_schedule = [dict(t) for t in self.all_tasks];
            current_conflict_ids = [cid for cid in base_conflict_ids];
            attempt_changes = {};

            for iteration in range(MAX_ITER) {
                if len(current_conflict_ids) == 0 { break; }
                blocked = compute_blocked_slots(virtual_schedule, current_conflict_ids);
                # Only pass the movable tasks to the LLM — fixed tasks are already fully
                # described in blocked_slots with their effective windows. Passing all tasks
                # causes contradictory info (end_time vs effective_end_time in blocked_slots)
                # which causes the LLM to ignore blocked_slots constraints.
                movable_schedule = [t for t in virtual_schedule if t["id"] in current_conflict_ids];
                optimization = optimize_conflicted_schedule(
                    current_schedule=movable_schedule,
                    conflicting_task_ids=current_conflict_ids,
                    locked_task_ids=self.locked_ids,
                    blocked_slots=blocked,
                    user_productivity_peaks=self.user_peaks
                );
                if retry == 0 and iteration == 0 {
                    final_overview = optimization.overview;
                    final_optimizations = optimization.optimizations;
                }
                for change in optimization.changes {
                    cid = change.task_id;
                    # Never record or apply a change to a locked task
                    if cid in self.locked_ids { continue; }
                    attempt_changes[cid] = {
                        "task_id": cid,
                        "task_title": change.task_title,
                        "new_start_date": change.new_start_date,
                        "new_start_time": change.new_start_time,
                        "new_end_time": change.new_end_time,
                        "reason": change.reason
                    };
                    for t in virtual_schedule {
                        if t["id"] == cid {
                            t["start_date"] = change.new_start_date;
                            t["start_time"] = change.new_start_time;
                            t["end_time"] = change.new_end_time;
                        }
                    }
                }
                current_conflict_ids = detect_conflicts_with_overrun(virtual_schedule);
            }

            # Conflict-free result — accept this attempt
            if len(current_conflict_ids) == 0 {
                merged_changes = attempt_changes;
                break;
            }
            # Still conflicts — on final retry keep best attempt, otherwise loop again
            if retry == MAX_RETRIES - 1 {
                merged_changes = attempt_changes;
            }
        }

        total_mins = 0;
        for t in virtual_schedule {
            if t.get("start_time") and t.get("end_time") {
                tp = t["start_time"].split(":");
                ep = t["end_time"].split(":");
                t_start = int(tp[0]) * 60 + int(tp[1]);
                t_end = int(ep[0]) * 60 + int(ep[1]);
                if t_end > t_start { total_mins += t_end - t_start; }
            }
        }

        report {
            "overview": final_overview,
            "optimizations": [
                {"title": o.title, "description": o.description}
                for o in final_optimizations
            ],
            "changes": list(merged_changes.values()),
            "all_conflicts_resolved": len(current_conflict_ids) == 0,
            "total_minutes": total_mins
        };
    }
}

walker:priv ListTaskHistory {
    has history: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with TaskHistory entry {
        self.history.append({
            "id": here.id,
            "task_title": here.task_title,
            "category": here.category,
            "estimated_duration": here.estimated_duration,
            "actual_duration": here.actual_duration,
            "started_at": here.started_at,
            "completed_at": here.completed_at
        });
    }

    can report_all with Root exit {
        report self.history;
    }
}

# ===== CONVERSATIONAL AGENT (INVOKE + EXTRACT + PIPE) =====

# --- Combined agent turn: response + action in one LLM call ---

obj AgentTurn {
    has response: str;
    has action_type: str = "";
    has ready: bool = False;
    has task_title: str = "";
    has task_list_name: str = "";
    has task_list_id: str = "";
    has task_start_date: str = "";
    has task_start_time: str = "";
    has task_end_time: str = "";
    has task_estimated_duration: int = 0;
    has task_category: str = "";
    has task_priority: str = "";
    has task_status: str = "";
    has task_due_date: str = "";
    has task_description: str = "";
    has target_task_id: str = "";
}
sem AgentTurn.response = "The assistant's next reply shown to the user.";
sem AgentTurn.action_type = "Exactly one of: create_list, create_task, update_task, delete_task, reschedule, none. Set to the action this turn is confirming or gathering info for. 'none' for questions/chitchat.";
sem AgentTurn.ready = "True ONLY when your response is asking the user to confirm a specific action ('Shall I go ahead?'). False while still gathering missing fields.";
sem AgentTurn.task_list_name = "For create_list: the exact name of the list to create. Empty string otherwise.";
sem AgentTurn.task_list_id = "For create_task: list ID from available_lists (e.g. 'list_1'). If user named a just-created list not yet in available_lists, use its name — the system will resolve it. Empty string if truly unknown.";
sem AgentTurn.task_title = "Task title extracted from conversation. Empty string if unknown.";
sem AgentTurn.task_description = "Task description if mentioned. Empty string otherwise.";
sem AgentTurn.task_status = "One of: todo, in_progress, review, done. Empty string if not specified.";
sem AgentTurn.task_priority = "One of: urgent, high, normal, low. Empty string if not specified.";
sem AgentTurn.task_due_date = "Deadline date YYYY-MM-DD only if explicitly stated. Empty string otherwise.";
sem AgentTurn.task_start_date = "Scheduled date YYYY-MM-DD resolved from conversation. Empty string if unknown.";
sem AgentTurn.task_start_time = "Start time HH:MM 24h (e.g. '2pm' -> '14:00'). Empty string if unknown.";
sem AgentTurn.task_end_time = "End time HH:MM 24h = start_time + task_estimated_duration. Empty string if either unknown.";
sem AgentTurn.task_category = "One of: Coding, Research, Writing, Meeting, Admin. Empty string if not specified.";
sem AgentTurn.task_estimated_duration = "Duration in minutes explicitly provided by the user. 0 if not yet provided.";
sem AgentTurn.target_task_id = "For reschedule/update/delete: the exact task ID from all_tasks. Empty string otherwise.";

def agent_turn(
    history: list[dict],
    current_date: str,
    available_lists: str,
    all_tasks: str
) -> AgentTurn by llm(temperature=0.1);
sem agent_turn = "You are FlowBoard AI. In ONE pass, generate the assistant reply AND extract structured action fields. CONVERSATION RULES: 1) CREATE LIST — only when user explicitly wants a new list OR no lists exist and user wants to add a task. As soon as you have the list name, set response='Got it! I\\'ll create a new list called \"[name]\". Shall I go ahead?', action_type='create_list', task_list_name='[name]', ready=True. 2) CREATE TASK — for any add/schedule/create request. Silently extract title, list, date, start_time, duration from the full history. Ask ONLY for the single next missing field in this ORDER: title → list → date → start_time → duration. When asking duration give an example: 'How long will this take? e.g. 30 or 60 minutes'. NEVER set ready=True if task_estimated_duration is 0 or unknown — duration is REQUIRED. Once title+list+date+start_time+duration are ALL present, set response to a confirmation summary ending with 'Shall I go ahead?', action_type='create_task', ready=True, fill all extracted fields. 3) RESCHEDULE — match task in all_tasks, set response='I\\'ll find better slots for \"[title]\" — shall I go ahead?', action_type='reschedule', target_task_id=<exact id>, ready=True. 4) DELETE/UPDATE — find task in all_tasks, confirm, set action_type and target_task_id, ready=True. 5) Questions — answer helpfully, action_type='none', ready=True. CRITICAL: ready=True ONLY when your response ends with a 'Shall I go ahead?' confirmation AND all required fields are filled. ready=False while gathering any missing field. Resolve relative dates with current_date. Be concise and warm.";
sem agent_turn.history = "Complete conversation as {role, content} dicts with the user's latest message last.";
sem agent_turn.current_date = "Today's date YYYY-MM-DD for resolving relative dates.";
sem agent_turn.available_lists = "All existing lists with IDs. Show these when asking which list.";
sem agent_turn.all_tasks = "All tasks with IDs and details. Use for reschedule/update/delete and answering questions.";

# --- Post-action LLM confirmation ---

def gen_post_action_msg(action_type: str, action_name: str) -> str by llm(temperature=0.7);
sem gen_post_action_msg = "You are FlowBoard AI. Generate a brief (1-2 sentence), warm, natural confirmation message after completing an action in a task manager. action_type is one of: create_list, create_task, update_task, delete_task. action_name is the name of the task or list. Be conversational and varied — avoid starting every response the same way. For create_list, naturally offer to add a task to it. For create_task, let them know it's scheduled and ask if they need anything else. For update_task or delete_task, confirm briefly.";

walker:priv AgentPostAction {
    has action_type: str;
    has action_name: str = "";

    can run with Root entry {
        msg = gen_post_action_msg(action_type=self.action_type, action_name=self.action_name);
        report {"message": str(msg) if msg else "All set! Let me know what's next."};
    }
}

# --- Action types ---

obj ChatAction {
    has action_type: str,
        target_task_id: str = "",
        task_title: str = "",
        task_description: str = "",
        task_status: str = "",
        task_priority: str = "",
        task_due_date: str = "",
        task_list_id: str = "",
        task_list_name: str = "",
        task_start_date: str = "",
        task_start_time: str = "",
        task_end_time: str = "",
        task_category: str = "",
        task_estimated_duration: int = 0;
}
sem ChatAction.action_type = "Exactly one of: create_list, create_task, update_task, delete_task, reschedule, none.";
sem ChatAction.target_task_id = "For update_task or delete_task: the exact task ID from the system. Empty string otherwise.";
sem ChatAction.task_title = "Task title. Empty string if not applicable.";
sem ChatAction.task_description = "Task description if specified. Empty string if not.";
sem ChatAction.task_status = "One of: todo, in_progress, review, done. Empty string if not changing.";
sem ChatAction.task_priority = "One of: urgent, high, normal, low. Empty string if not specified.";
sem ChatAction.task_due_date = "Deadline date YYYY-MM-DD only if explicitly stated as a deadline. Empty string otherwise.";
sem ChatAction.task_list_id = "List ID (e.g. 'list_1'). Must match the actual system ID. Empty string if unknown.";
sem ChatAction.task_list_name = "For create_list: the name of the new list to create. Empty string otherwise.";
sem ChatAction.task_start_date = "Scheduled date YYYY-MM-DD resolved from conversation (e.g. 'tomorrow' → next day). Empty string if unknown.";
sem ChatAction.task_start_time = "Start time HH:MM 24h (e.g. '2pm' → '14:00'). Empty string if unknown.";
sem ChatAction.task_end_time = "End time HH:MM 24h computed as start_time + estimated_duration. Empty string if unknown.";
sem ChatAction.task_category = "One of: Coding, Research, Writing, Meeting, Admin. Empty string if not specified.";
sem ChatAction.task_estimated_duration = "Duration in minutes. 0 if not known.";

obj TaskReadiness {
    has ready: bool,
        missing: list[str],
        action_type: str,
        target_task_id: str,
        task_title: str,
        task_description: str,
        task_status: str,
        task_priority: str,
        task_due_date: str,
        task_list_id: str,
        task_list_name: str,
        task_start_date: str,
        task_start_time: str,
        task_end_time: str,
        task_category: str,
        task_estimated_duration: int;
}
sem TaskReadiness = "Result of extracting task action fields from the full conversation history.";
sem TaskReadiness.ready = "True when all required fields ARE present in the conversation and have been extracted. For create_list: true when task_list_name != ''. For create_task: true when task_title != '', task_list_id != '', task_start_date != '', task_start_time != '', and task_estimated_duration > 0. For update_task/delete_task: true when target_task_id != ''. For action_type='none': always true. Set False only when one or more required fields genuinely cannot be found anywhere in the conversation.";
sem TaskReadiness.missing = "Names of fields that have NO value anywhere in the entire conversation (e.g. ['duration', 'list']). If a field WAS mentioned by the user in any prior message, do NOT include it here. Empty list when ready=True.";
sem TaskReadiness.action_type = "Exactly one of: create_list, create_task, update_task, delete_task, reschedule, none.";
sem TaskReadiness.target_task_id = "For update_task or delete_task: the exact task ID from the system. Empty string otherwise.";
sem TaskReadiness.task_title = "Task title extracted from conversation. Empty string if unknown.";
sem TaskReadiness.task_description = "Task description if mentioned. Empty string if not.";
sem TaskReadiness.task_status = "One of: todo, in_progress, review, done. Empty string if not specified.";
sem TaskReadiness.task_priority = "One of: urgent, high, normal, low. Empty string if not specified.";
sem TaskReadiness.task_due_date = "Deadline date YYYY-MM-DD only if explicitly stated. Empty string otherwise.";
sem TaskReadiness.task_list_id = "List ID (e.g. 'list_1') resolved from available_lists. Empty string if unknown.";
sem TaskReadiness.task_list_name = "For create_list: the name the user wants to give the new list. Empty string otherwise.";
sem TaskReadiness.task_start_date = "Scheduled date YYYY-MM-DD resolved using current_date (e.g. 'tomorrow' → next day). Empty string if unknown.";
sem TaskReadiness.task_start_time = "Start time HH:MM 24h (e.g. '2pm' → '14:00'). Empty string if unknown.";
sem TaskReadiness.task_end_time = "End time HH:MM 24h = start_time + task_estimated_duration minutes. Empty string if either is unknown.";
sem TaskReadiness.task_category = "One of: Coding, Research, Writing, Meeting, Admin. Empty string if not specified.";
sem TaskReadiness.task_estimated_duration = "Duration in minutes from conversation. 0 if not yet provided.";

def check_task_readiness(
    history: list[dict],
    current_date: str,
    available_lists: str,
    available_tasks: str
) -> TaskReadiness by llm(temperature=0.1);
sem check_task_readiness = "Analyze the COMPLETE conversation history and extract all task action fields. STEP 1 — Determine action_type from the MOST RECENT assistant message, not the user's original intent: if the most recent assistant message says it will create a list (e.g. contains 'create a new list called' or 'create a list called'), set action_type='create_list'. If the most recent assistant message is confirming a task will be added/created, set action_type='create_task'. If it is confirming a reschedule, set action_type='reschedule'. If it is confirming a delete or update, set action_type accordingly. If it is asking a clarifying question (not confirming an action), infer action_type from the overall conversation goal. STEP 2 — Extract fields: (1) Scan every message for title, list, date, time, duration. (2) For create_list: ready=True as soon as task_list_name is known. Extract task_list_name from the most recent assistant message if it names the list. (3) For create_task: ready=True when task_title, task_list_id, task_start_date, task_start_time, and task_estimated_duration > 0 are ALL extractable. If the user referred to a list by name that does not yet appear in available_lists, set task_list_id to that name — the system will resolve it. (4) For reschedule: match the task against available_tasks, set target_task_id to its exact id. ready=True as soon as target_task_id is identified. (5) For delete_task or update_task: match task in available_tasks by title/schedule, set target_task_id to exact id. ready=True when identified. (6) For general questions: action_type='none', ready=True. (7) Resolve relative dates with current_date. Convert 12h to 24h. Compute task_end_time = start_time + duration. (8) Match list names to IDs using available_lists.";
sem check_task_readiness.history = "Full conversation as list of {role, content} dicts. Scan ALL entries.";
sem check_task_readiness.current_date = "Today's date YYYY-MM-DD for resolving relative dates.";
sem check_task_readiness.available_lists = "List names with IDs (e.g. 'Research (id: list_2)'). Match user's list name to the correct ID.";
sem check_task_readiness.available_tasks = "All current tasks with exact IDs and details. Use to find the correct target_task_id for delete/update by matching title and schedule.";

# --- Chat walkers ---

walker:priv AgentChat {
    has message: str;
    has all_tasks: list = [];
    has all_lists: list = [];
    has history_msgs: list = [];

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can collect_list with List entry {
        self.all_lists.append({
            "id": here.id,
            "name": here.name
        });
        visit [-->];
    }

    can collect_task with Task entry {
        self.all_tasks.append({
            "id": here.id,
            "title": here.title,
            "description": here.description,
            "status": here.status,
            "priority": here.priority,
            "due_date": here.due_date,
            "list_id": here.list_id,
            "parent_task_id": here.parent_task_id,
            "start_date": here.start_date,
            "start_time": here.start_time,
            "end_time": here.end_time,
            "estimated_duration": here.estimated_duration,
            "category": here.category
        });
    }

    can enter_session with ChatSession entry {
        visit [-->];
    }

    can collect_chat with ChatMessage entry {
        self.history_msgs.append({
            "id": here.id,
            "role": here.role,
            "content": here.content
        });
    }

    can finalize with Root exit {
        global chat_msg_counter;

        # Format lists context
        sl_lines = [];
        for l in self.all_lists {
            sl_lines.append("List: " + str(l["name"]) + " (id: " + str(l["id"]) + ")");
        }
        lists_ctx = "\n".join(sl_lines) if sl_lines else "No lists exist yet.";

        # Format tasks context
        task_lines = [];
        for t in self.all_tasks {
            line = "[" + str(t["id"]) + "] " + str(t["title"]);
            line += " | status:" + str(t["status"]) + " | priority:" + str(t["priority"]);
            if t.get("category", "") != "" {
                line += " | category:" + str(t["category"]);
            }
            if t.get("start_date", "") != "" and t.get("start_time", "") != "" {
                line += " | scheduled:" + str(t["start_date"]) + " " + str(t["start_time"]) + "-" + str(t.get("end_time", ""));
            }
            if t.get("due_date", "") != "" {
                line += " | due:" + str(t["due_date"]);
            }
            if t.get("estimated_duration", 0) > 0 {
                line += " | est:" + str(t["estimated_duration"]) + "min";
            }
            if t.get("list_id", "") != "" {
                line += " | list:" + str(t["list_id"]);
            }
            task_lines.append(line);
        }
        tasks_ctx = "\n".join(task_lines) if task_lines else "No tasks exist yet.";

        # Build full conversation history including the current user message as last entry
        self.history_msgs.sort(
            key=lambda m: int(m["id"].replace("chat_", "")) if m["id"].startswith("chat_") else 0
        );
        history_list = [
            {"role": msg["role"], "content": msg["content"]}
            for msg in self.history_msgs[-20:]
        ];
        # Append current user message so model sees the full turn
        history_list.append({"role": "user", "content": self.message});

        current_dt = datetime.now().strftime("%Y-%m-%d");

        # Pre-check: if no lists exist, tell the LLM so it prompts the user to create one first
        if len(self.all_lists) == 0 {
            history_list.insert(0, {
                "role": "system",
                "content": "No lists exist in the system yet. If the user wants to create a task, you MUST first ask them to create a list. Suggest they create one (e.g. 'To add a task, you\\'ll need a list first — what would you like to call it?')."
            });
        }

        # Single LLM call: generates response AND extracts action fields simultaneously
        turn = agent_turn(
            history=history_list,
            current_date=str(current_dt),
            available_lists=lists_ctx,
            all_tasks=tasks_ctx
        );
        response_text: str = str(turn.response) if turn.response else "";

        # Find or create ChatSession, then save messages there
        session = None;
        for child in [-->] {
            if isinstance(child, ChatSession) {
                session = child;
            }
        }
        if session is None {
            result = here ++> ChatSession(id="chat_session");
            session = result[0];
        }

        chat_msg_counter += 1;
        session ++> ChatMessage(
            id="chat_" + str(chat_msg_counter),
            role="user",
            content=self.message,
            timestamp=datetime.now().isoformat()
        );

        chat_msg_counter += 1;
        session ++> ChatMessage(
            id="chat_" + str(chat_msg_counter),
            role="assistant",
            content=response_text,
            timestamp=datetime.now().isoformat()
        );

        report {
            "content": response_text,
            "action_type": str(turn.action_type) if turn.action_type else "",
            "ready": turn.ready if turn.ready else False,
            "task_title": str(turn.task_title) if turn.task_title else "",
            "task_list_name": str(turn.task_list_name) if turn.task_list_name else "",
            "task_list_id": str(turn.task_list_id) if turn.task_list_id else "",
            "task_start_date": str(turn.task_start_date) if turn.task_start_date else "",
            "task_start_time": str(turn.task_start_time) if turn.task_start_time else "",
            "task_end_time": str(turn.task_end_time) if turn.task_end_time else "",
            "task_estimated_duration": turn.task_estimated_duration if turn.task_estimated_duration else 0,
            "task_category": str(turn.task_category) if turn.task_category else "",
            "task_priority": str(turn.task_priority) if turn.task_priority else "",
            "task_status": str(turn.task_status) if turn.task_status else "",
            "task_due_date": str(turn.task_due_date) if turn.task_due_date else "",
            "task_description": str(turn.task_description) if turn.task_description else "",
            "target_task_id": str(turn.target_task_id) if turn.target_task_id else "",
            "tool_events": []
        };
    }
}

walker:priv AgentCheckReady {
    has current_date: str;
    has history: list = [];  # list of {role, content, ...} message dicts from frontend
    has all_lists: list = [];
    has all_tasks: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can gather_list with List entry {
        self.all_lists.append(here.name + " (id: " + here.id + ")");
        visit [-->];
    }

    can gather_task with Task entry {
        line = "[" + here.id + "] " + here.title;
        if here.start_date != "" and here.start_time != "" {
            line += " | " + here.start_date + " " + here.start_time + "-" + here.end_time;
        }
        line += " | list:" + here.list_id;
        self.all_tasks.append(line);
    }

    can finalize with Root exit {
        lists_str = ", ".join(self.all_lists) if self.all_lists else "No lists available";
        tasks_str = "\n".join(self.all_tasks) if self.all_tasks else "No tasks yet";
        clean_history = [{"role": m["role"], "content": m["content"]} for m in self.history];
        result = check_task_readiness(
            history=clean_history,
            current_date=self.current_date,
            available_lists=lists_str,
            available_tasks=tasks_str
        );
        report {
            "ready": result.ready,
            "missing": result.missing,
            "action_type": result.action_type,
            "target_task_id": result.target_task_id,
            "task_title": result.task_title,
            "task_description": result.task_description,
            "task_status": result.task_status,
            "task_priority": result.task_priority,
            "task_due_date": result.task_due_date,
            "task_list_id": result.task_list_id,
            "task_list_name": result.task_list_name,
            "task_start_date": result.task_start_date,
            "task_start_time": result.task_start_time,
            "task_end_time": result.task_end_time,
            "task_category": result.task_category,
            "task_estimated_duration": result.task_estimated_duration
        };
    }
}

walker:priv AgentExecuteAction {
    has action_type: str,
        target_task_id: str = "",
        task_title: str = "",
        task_description: str = "",
        task_status: str = "",
        task_priority: str = "",
        task_due_date: str = "",
        task_list_id: str = "",
        task_start_date: str = "",
        task_start_time: str = "",
        task_end_time: str = "",
        task_category: str = "",
        task_estimated_duration: int = 0;
    has executed: bool = False;
    has new_task_ref: list = [];

    can start with Root entry {
        if self.action_type == "create_task" and self.task_list_id == "" {
            # No list specified — create task on root
            global task_counter;
            task_counter += 1;
            new_id = "task_" + str(task_counter);
            new_task = here ++> Task(
                id=new_id,
                title=self.task_title,
                description=(self.task_description if self.task_description else ""),
                status=(self.task_status if self.task_status != "" else "todo"),
                priority=(self.task_priority if self.task_priority != "" else "normal"),
                due_date=(self.task_due_date if self.task_due_date else ""),
                list_id="",
                start_date=(self.task_start_date if self.task_start_date else ""),
                start_time=(self.task_start_time if self.task_start_time else ""),
                end_time=(self.task_end_time if self.task_end_time else ""),
                estimated_duration=(self.task_estimated_duration if self.task_estimated_duration > 0 else 60),
                category=(self.task_category if self.task_category else "")
            );
            self.new_task_ref = new_task;
            self.executed = True;
            report {"success": True, "action": "create_task", "task_id": new_id};
        } else {
            visit [-->];
        }
    }

    can pass_space with Space entry {
        if not self.executed {
            visit [-->];
        }
    }

    can handle_list with List entry {
        if self.executed {
            return;
        }
        # Match by ID or by name (LLM sometimes sends the name instead of ID)
        list_matches = (
            self.action_type == "create_task" and
            (here.id == self.task_list_id or here.name == self.task_list_id)
        );
        if list_matches {
            global task_counter;
            task_counter += 1;
            new_id = "task_" + str(task_counter);
            new_task = here ++> Task(
                id=new_id,
                title=self.task_title,
                description=(self.task_description if self.task_description else ""),
                status=(self.task_status if self.task_status != "" else "todo"),
                priority=(self.task_priority if self.task_priority != "" else "normal"),
                due_date=(self.task_due_date if self.task_due_date else ""),
                list_id=here.id,
                start_date=(self.task_start_date if self.task_start_date else ""),
                start_time=(self.task_start_time if self.task_start_time else ""),
                end_time=(self.task_end_time if self.task_end_time else ""),
                estimated_duration=(self.task_estimated_duration if self.task_estimated_duration > 0 else 60),
                category=(self.task_category if self.task_category else "")
            );
            self.new_task_ref = new_task;
            self.executed = True;
            report {"success": True, "action": "create_task", "task_id": new_id};
        } else {
            visit [-->];
        }
    }

    can handle_task with Task entry {
        if self.executed {
            return;
        }
        if self.action_type == "delete_task" and here.id == self.target_task_id {
            del here;
            self.executed = True;
            report {"success": True, "action": "delete_task"};
        } elif self.action_type == "update_task" and here.id == self.target_task_id {
            if self.task_title != "" {
                here.title = self.task_title;
            }
            if self.task_description != "" {
                here.description = self.task_description;
            }
            if self.task_status != "" {
                here.status = self.task_status;
            }
            if self.task_priority != "" {
                here.priority = self.task_priority;
            }
            if self.task_due_date != "" {
                here.due_date = self.task_due_date;
            }
            if self.task_start_date != "" {
                here.start_date = self.task_start_date;
            }
            if self.task_start_time != "" {
                here.start_time = self.task_start_time;
            }
            if self.task_end_time != "" {
                here.end_time = self.task_end_time;
            }
            if self.task_category != "" {
                here.category = self.task_category;
            }
            if self.task_estimated_duration > 0 {
                here.estimated_duration = self.task_estimated_duration;
            }
            self.executed = True;
            report {"success": True, "action": "update_task"};
        }
    }

    can fallback with Root exit {
        if not self.executed {
            report {"success": False, "error": "Could not execute action"};
        }
        # Link newly created task to its CalendarDay node
        if self.new_task_ref and self.task_start_date != "" {
            task_node = self.new_task_ref[0];
            cd_list = [-->][?:CalendarDay, date == self.task_start_date];
            if not cd_list {
                cd_list = here ++> CalendarDay(date=self.task_start_date);
            }
            cd_list[0] ++> task_node;
        }
    }
}

walker:priv AgentExecuteCreate {
    has task_title: str,
        task_description: str = "",
        task_status: str = "todo",
        task_priority: str = "normal",
        task_due_date: str = "",
        task_list_id: str = "",
        task_start_date: str = "",
        task_start_time: str = "",
        task_end_time: str = "",
        task_category: str = "",
        task_estimated_duration: int = 60;
    has executed: bool = False;
    has new_task_ref: list = [];

    can start with Root entry {
        if self.task_list_id == "" {
            global task_counter;
            task_counter += 1;
            new_id = "task_" + str(task_counter);
            new_task = here ++> Task(
                id=new_id,
                title=self.task_title,
                description=self.task_description,
                status=self.task_status if self.task_status != "" else "todo",
                priority=self.task_priority if self.task_priority != "" else "normal",
                due_date=self.task_due_date,
                list_id="",
                start_date=self.task_start_date,
                start_time=self.task_start_time,
                end_time=self.task_end_time,
                estimated_duration=self.task_estimated_duration if self.task_estimated_duration > 0 else 60,
                category=self.task_category
            );
            if new_task {
                self.new_task_ref = new_task;
                self.executed = True;
                report {"success": True, "action": "create_task", "task_id": new_task[0].id};
            }
        } else {
            visit [-->];
        }
    }

    can pass_space with Space entry {
        if not self.executed { visit [-->]; }
    }

    can handle_list with List entry {
        if self.executed { return; }
        if here.id == self.task_list_id or here.name == self.task_list_id {
            global task_counter;
            task_counter += 1;
            new_id = "task_" + str(task_counter);
            new_task = here ++> Task(
                id=new_id,
                title=self.task_title,
                description=self.task_description,
                status=self.task_status if self.task_status != "" else "todo",
                priority=self.task_priority if self.task_priority != "" else "normal",
                due_date=self.task_due_date,
                list_id=here.id,
                start_date=self.task_start_date,
                start_time=self.task_start_time,
                end_time=self.task_end_time,
                estimated_duration=self.task_estimated_duration if self.task_estimated_duration > 0 else 60,
                category=self.task_category
            );
            if new_task {
                self.new_task_ref = new_task;
                self.executed = True;
                report {"success": True, "action": "create_task", "task_id": new_task[0].id};
            }
        }
    }

    can link_calendar with Root exit {
        if not self.executed {
            report {"success": False, "error": "Could not create task"};
            return;
        }
        if self.new_task_ref and self.task_start_date != "" {
            task_node = self.new_task_ref[0];
            cd_list = [-->][?:CalendarDay, date == self.task_start_date];
            if not cd_list {
                cd_list = here ++> CalendarDay(date=self.task_start_date);
            }
            cd_list[0] ++> task_node;
        }
    }
}

walker:priv AgentExecuteCreateList {
    has list_name: str;

    can create with Root entry {
        global list_counter;
        list_counter += 1;
        new_id = "list_" + str(list_counter);
        new_list = here ++> List(
            id=new_id,
            name=self.list_name,
            space_id="",
            color="gray"
        );
        if new_list {
            report {"success": True, "action": "create_list", "list_id": new_list[0].id, "list_name": new_list[0].name};
        } else {
            report {"success": False, "error": "Could not create list"};
        }
    }
}

walker:priv SaveChatMessages {
    has user_message: str = "";
    has assistant_message: str = "";

    can save with Root entry {
        global chat_msg_counter;
        session = None;
        for child in [-->] {
            if isinstance(child, ChatSession) { session = child; }
        }
        if session is None {
            result = here ++> ChatSession(id="chat_session");
            session = result[0];
        }
        if self.user_message != "" {
            chat_msg_counter += 1;
            session ++> ChatMessage(id="chat_" + str(chat_msg_counter), role="user", content=self.user_message, timestamp=datetime.now().isoformat());
        }
        if self.assistant_message != "" {
            chat_msg_counter += 1;
            session ++> ChatMessage(id="chat_" + str(chat_msg_counter), role="assistant", content=self.assistant_message, timestamp=datetime.now().isoformat());
        }
        report {"saved": True};
    }
}

walker:priv AgentExecuteUpdate {
    has target_task_id: str,
        task_title: str = "",
        task_description: str = "",
        task_status: str = "",
        task_priority: str = "",
        task_due_date: str = "",
        task_start_date: str = "",
        task_start_time: str = "",
        task_end_time: str = "",
        task_category: str = "",
        task_estimated_duration: int = 0;
    has executed: bool = False;
    has updated_task_ref: list = [];
    has old_start_date: str = "";

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        if not self.executed { visit [-->]; }
    }

    can pass_list with List entry {
        if not self.executed { visit [-->]; }
    }

    can handle_task with Task entry {
        if self.executed { return; }
        if here.id == self.target_task_id {
            self.old_start_date = here.start_date;
            if self.task_title != "" { here.title = self.task_title; }
            if self.task_description != "" { here.description = self.task_description; }
            if self.task_status != "" { here.status = self.task_status; }
            if self.task_priority != "" { here.priority = self.task_priority; }
            if self.task_due_date != "" { here.due_date = self.task_due_date; }
            if self.task_start_date != "" { here.start_date = self.task_start_date; }
            if self.task_start_time != "" { here.start_time = self.task_start_time; }
            if self.task_end_time != "" { here.end_time = self.task_end_time; }
            if self.task_category != "" { here.category = self.task_category; }
            if self.task_estimated_duration > 0 { here.estimated_duration = self.task_estimated_duration; }
            self.updated_task_ref = [here];
            self.executed = True;
            report {"success": True, "action": "update_task"};
        }
    }

    can update_calendar with Root exit {
        if not self.executed {
            report {"success": False, "error": "Task not found"};
            return;
        }
        task_node = self.updated_task_ref[0];
        # Remove from old CalendarDay if date changed
        if self.old_start_date != "" and self.old_start_date != self.task_start_date {
            old_cd_list = [-->][?:CalendarDay, date == self.old_start_date];
            for cd in old_cd_list {
                cd del --> task_node;
            }
        }
        # Link to new CalendarDay if scheduled
        if self.task_start_date != "" {
            cd_list = [-->][?:CalendarDay, date == self.task_start_date];
            if not cd_list {
                cd_list = here ++> CalendarDay(date=self.task_start_date);
            }
            cd_list[0] ++> task_node;
        }
    }
}

walker:priv AgentExecuteDelete {
    has target_task_id: str = "",
        task_title: str = "";
    has executed: bool = False;

    can search with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        if not self.executed { visit [-->]; }
    }

    can pass_list with List entry {
        if not self.executed { visit [-->]; }
    }

    can handle_task with Task entry {
        if self.executed { return; }
        matched_by_id = self.target_task_id != "" and here.id == self.target_task_id;
        matched_by_title = self.task_title != "" and here.title.lower() == self.task_title.lower();
        if matched_by_id or matched_by_title {
            del here;
            self.executed = True;
            report {"success": True, "action": "delete_task"};
        }
    }

    can fallback with Root exit {
        if not self.executed {
            report {"success": False, "error": "Task not found"};
        }
    }
}

walker:priv ListChatHistory {
    has messages: list = [];

    can find_session with Root entry {
        visit [-->];
    }

    can enter_session with ChatSession entry {
        visit [-->];
    }

    can gather with ChatMessage entry {
        self.messages.append({
            "id": here.id,
            "role": here.role,
            "content": here.content,
            "action_type": here.action_type,
            "action_status": here.action_status,
            "timestamp": here.timestamp
        });
    }

    can report_all with Root exit {
        report self.messages;
    }
}

walker:priv ClearChatHistory {
    can find_session with Root entry {
        visit [-->];
    }

    can enter_session with ChatSession entry {
        visit [-->];
    }

    can delete_msg with ChatMessage entry {
        del here;
    }

    can done with Root exit {
        report {"cleared": True};
    }
}

# ===== TASK-SCREEN MATCHING WALKER =====

walker:priv MatchTaskFromScreenshot {
    has screenshot_b64: str,
        today_date: str,
        current_time: str;
    has candidate_tasks: list = [];
    has scheduled_now_ids: list = [];

    can start with Root entry {
        visit [-->];
    }

    can pass_space with Space entry {
        visit [-->];
    }

    can pass_list with List entry {
        visit [-->];
    }

    can collect_task with Task entry {
        if here.status != "done" and here.start_date == self.today_date {
            st: str = here.start_time if here.start_time else "";
            et: str = here.end_time if here.end_time else "";
            # Check if current_time falls within the scheduled window
            in_window: bool = False;
            if st != "" and et != "" {
                in_window = st <= self.current_time and self.current_time <= et;
            }
            self.candidate_tasks.append({
                "id": here.id,
                "title": here.title,
                "category": here.category,
                "start_time": st,
                "end_time": et,
                "in_window": in_window
            });
            if in_window {
                self.scheduled_now_ids.append(here.id);
            }
        }
    }

    can finalize with Root exit {
        scheduled_now = len(self.scheduled_now_ids) > 0;

        if len(self.candidate_tasks) == 0 {
            report {
                "matched": False,
                "scheduled_now": False,
                "task_id": "", "task_title": "", "confidence": 0,
                "reasoning": "No tasks scheduled for today"
            };
            return;
        }

        task_lines = [];
        for t in self.candidate_tasks {
            line = "[" + str(t["id"]) + "] " + str(t["title"]);
            if t["category"] and t["category"] != "" {
                line = line + " (" + str(t["category"]) + ")";
            }
            if t["start_time"] != "" {
                line = line + " @ " + str(t["start_time"]);
                if t["end_time"] != "" {
                    line = line + "-" + str(t["end_time"]);
                }
            }
            if t["in_window"] {
                line = line + " [SCHEDULED NOW]";
            }
            task_lines.append(line);
        }
        tasks_summary = "\n".join(task_lines);

        img = Image("data:image/png;base64," + self.screenshot_b64);
        match_result = match_task_to_screen(img, tasks_summary, self.current_time);

        report {
            "matched": match_result.confidence >= 70 and match_result.task_id != "",
            "scheduled_now": scheduled_now,
            "task_id": match_result.task_id,
            "task_title": match_result.task_title,
            "confidence": match_result.confidence,
            "reasoning": match_result.reasoning
        };
    }
}

# ===== ACTIVITY TRACKING WALKER =====

walker:priv AnalyzeScreenshot {
    has screenshot_b64: str,
        task_id: str,
        task_title: str,
        task_category: str,
        elapsed_minutes: int,
        estimated_minutes: int;
    has found_session: list = [];

    can start with Root entry {
        visit [-->];
    }

    can capture_session with ChatSession entry {
        self.found_session = [here];
    }

    can finalize with Root exit {
        global activity_report_counter, chat_msg_counter;

        # Vision analysis
        img = Image("data:image/png;base64," + self.screenshot_b64);
        result = check_user_activity(img, self.task_title, self.task_category);

        # Store activity report on graph
        activity_report_counter += 1;
        here ++> ActivityReport(
            id="ar_" + str(activity_report_counter),
            task_id=self.task_id,
            task_title=self.task_title,
            task_category=self.task_category,
            on_task=result.on_task,
            elapsed_minutes=self.elapsed_minutes,
            reported_at=str(datetime.now()),
            off_task_description=(result.description if not result.on_task else "")
        );

        needs_alert = (not result.on_task) or (self.estimated_minutes > 0 and self.elapsed_minutes > self.estimated_minutes);

        alert_sent = False;
        if needs_alert {
            if len(self.found_session) > 0 {
                session = self.found_session[0];
            } else {
                sess_nodes = here ++> ChatSession(id="chat_session");
                session = sess_nodes[0];
            }

            chat_msg_counter += 1;
            if not result.on_task {
                alert_text = (
                    "Hey! It looks like you might be off task. "
                    + "You're supposed to be working on \""
                    + self.task_title
                    + "\". "
                    + result.description
                    + " Want to refocus?"
                );
            } else {
                over = self.elapsed_minutes - self.estimated_minutes;
                alert_text = (
                    "Heads up! You've been on \""
                    + self.task_title
                    + "\" for "
                    + str(self.elapsed_minutes)
                    + " min (estimated "
                    + str(self.estimated_minutes)
                    + " min — you're "
                    + str(over)
                    + " min over). Want to wrap up or update the estimate?"
                );
            }

            session ++> ChatMessage(
                id="chat_" + str(chat_msg_counter),
                role="assistant",
                content=alert_text,
                action_type="activity_alert",
                timestamp=datetime.now().isoformat()
            );
            alert_sent = True;
        }

        report {
            "on_task": result.on_task,
            "description": result.description,
            "alert_sent": alert_sent
        };
    }
}

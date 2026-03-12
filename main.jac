"""FlowBoard - ClickUp-style Project Management App.

Combines server-side endpoints with client-side UI.
"""

import from byllm.lib { Model }
import from datetime { datetime }

glob llm = Model(model_name="claude-haiku-4-5-20251001");

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
        ai_explanation: str = "";
}

node TaskHistory {
    has id: str,
        task_title: str,
        category: str,
        estimated_duration: int,
        actual_duration: int,
        completed_at: str;
}

node UserPatterns {
    has productivity_peaks: dict = {},
        category_overrun_ratios: dict = {},
        active_task_id: str = "",
        timer_start: str = "",
        timer_accumulated: int = 0,
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

# ===== GLOBAL COUNTERS =====

glob space_counter: int = 0;
glob list_counter: int = 0;
glob task_counter: int = 0;
glob comment_counter: int = 0;
glob task_history_counter: int = 0;

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
    has space_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete_space with Space entry {
        if here.id == self.space_id {
            del here;
            report {"deleted": self.space_id};
        }
    }

    can delete_lists with List entry {
        if here.space_id == self.space_id {
            del here;
        }
    }
}

# ===== LIST WALKERS =====

walker:priv CreateList {
    has name: str,
        space_id: str,
        color: str = "gray";

    can create with Root entry {
        global list_counter;
        list_counter += 1;
        new_id = "list_" + str(list_counter);
        new_list = here ++> List(
            id=new_id,
            name=self.name,
            space_id=self.space_id,
            color=self.color
        );
        if new_list {
            report {
                "id": new_list[0].id,
                "name": new_list[0].name,
                "space_id": new_list[0].space_id,
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
    has list_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete_list with List entry {
        if here.id == self.list_id {
            del here;
            report {"deleted": self.list_id};
        }
    }

    can delete_tasks with Task entry {
        if here.list_id == self.list_id {
            del here;
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

    can create with Root entry {
        global task_counter;
        task_counter += 1;
        new_id = "task_" + str(task_counter);
        new_task = here ++> Task(
            id=new_id,
            title=self.title,
            description=self.description,
            status=self.status,
            priority=self.priority,
            due_date=self.due_date,
            list_id=self.list_id,
            parent_task_id=self.parent_task_id,
            start_date=self.start_date,
            start_time=self.start_time,
            end_time=self.end_time,
            estimated_duration=self.estimated_duration,
            category=self.category
        );
        if new_task {
            report {
                "id": new_task[0].id,
                "title": new_task[0].title,
                "description": new_task[0].description,
                "status": new_task[0].status,
                "priority": new_task[0].priority,
                "due_date": new_task[0].due_date,
                "list_id": new_task[0].list_id,
                "parent_task_id": new_task[0].parent_task_id,
                "start_date": new_task[0].start_date,
                "start_time": new_task[0].start_time,
                "end_time": new_task[0].end_time,
                "estimated_duration": new_task[0].estimated_duration,
                "actual_duration": new_task[0].actual_duration,
                "category": new_task[0].category,
                "is_locked": new_task[0].is_locked,
                "ai_confidence": new_task[0].ai_confidence,
                "ai_explanation": new_task[0].ai_explanation
            };
        }
    }
}

walker:priv ListTasks {
    has tasks: list = [],
        list_id: str = "";

    can collect with Root entry {
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
                "ai_explanation": here.ai_explanation
            });
        }
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

    can search with Root entry {
        visit [-->];
    }

    can do_update with Task entry {
        if here.id == self.task_id {
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
                "ai_explanation": here.ai_explanation
            };
        }
    }
}

walker:priv DeleteTask {
    has task_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete_task with Task entry {
        if here.id == self.task_id or here.parent_task_id == self.task_id {
            del here;
            report {"deleted": self.task_id};
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
sem generate_schedule_explanation.surrounding_tasks = "Tasks scheduled in adjacent time slots, for workload context. Each has title, start_time, end_time.";

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

    can start with Root entry {
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
        } elif here.start_date != "" and here.start_time != "" {
            self.surrounding.append({
                "title": here.title,
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
        explanation = generate_schedule_explanation(
            task_title=self.target_title,
            category=self.target_category,
            scheduled_slot=slot_dict,
            user_estimated_duration=self.target_duration,
            historical_overrun_ratio=overrun_ratio,
            productivity_peaks=self.user_peaks,
            due_date=self.target_due_date,
            surrounding_tasks=self.surrounding
        );
        report {
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

    can do_update with Task entry {
        if here.id == self.task_id {
            here.is_locked = self.is_locked;
            report {"id": here.id, "is_locked": here.is_locked};
        }
    }
}

walker:priv ApplyReplanChanges {
    has changes: list;

    can search with Root entry {
        visit [-->];
    }

    can do_update with Task entry {
        for change in self.changes {
            if here.id == change["task_id"] and not here.is_locked {
                here.start_date = change["new_start_date"];
                here.start_time = change["new_start_time"];
                here.end_time = change["new_end_time"];
                here.ai_explanation = "";
            }
        }
        report {"applied": True};
    }
}

walker:priv StartTaskTimer {
    has task_id: str;

    can run with Root entry {
        visit [-->];
        report {"task_id": self.task_id, "started": True};
    }

    can setup_patterns with UserPatterns entry {
        here.active_task_id = self.task_id;
        here.timer_start = datetime.now().isoformat();
        here.timer_accumulated = 0;
    }

    can create_patterns with Root exit {
        existing = [n for n in [-->] if isinstance(n, UserPatterns)];
        if not existing {
            here ++> UserPatterns(
                active_task_id=self.task_id,
                timer_start=datetime.now().isoformat(),
                timer_accumulated=0
            );
        }
    }
}

walker:priv PauseTaskTimer {
    has task_id: str,
        elapsed_minutes: int;

    can run with Root entry {
        visit [-->];
        report {"task_id": self.task_id, "paused": True, "elapsed_minutes": self.elapsed_minutes};
    }

    can do_pause with UserPatterns entry {
        if here.active_task_id == self.task_id {
            here.timer_accumulated = self.elapsed_minutes;
            here.active_task_id = "";
            here.timer_start = "";
        }
    }
}

walker:priv FinishTaskTimer {
    has task_id: str,
        actual_duration: int;

    can run with Root entry {
        global task_history_counter;
        visit [-->];
        report {"task_id": self.task_id, "finished": True, "actual_duration": self.actual_duration};
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
                completed_at=datetime.now().isoformat()
            );
        }
    }

    can update_patterns with UserPatterns entry {
        here.active_task_id = "";
        here.timer_start = "";
        here.timer_accumulated = 0;
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

    can seed with Root exit {
        global space_counter, list_counter, task_counter, task_history_counter;
        if self.already_seeded {
            report {"seeded": False, "reason": "Already has data"};
            return;
        }

        # Create two spaces
        space_counter += 1;
        s1 = here ++> Space(id="space_" + str(space_counter), name="FlowBoard Demo", color="purple");

        space_counter += 1;
        s2 = here ++> Space(id="space_" + str(space_counter), name="Personal", color="blue");

        # Create lists
        list_counter += 1;
        l1 = here ++> List(id="list_" + str(list_counter), name="AI Project", space_id=s1[0].id, color="indigo");

        list_counter += 1;
        l2 = here ++> List(id="list_" + str(list_counter), name="Research", space_id=s1[0].id, color="teal");

        list_counter += 1;
        l3 = here ++> List(id="list_" + str(list_counter), name="Habits", space_id=s2[0].id, color="green");

        lid = l1[0].id;
        rid = l2[0].id;

        # Create scheduled tasks for the week of 2026-03-09 to 2026-03-13
        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Research AI scheduling algorithms",
            description="Survey existing approaches to AI-driven calendar scheduling and time-boxing.",
            status="todo", priority="high", category="Research", estimated_duration=120,
            list_id=rid, start_date="2026-03-09", start_time="09:00", end_time="11:00",
            ai_confidence=87, due_date="2026-03-11"
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Team standup",
            description="Daily sync with the project team.",
            status="todo", priority="normal", category="Meeting", estimated_duration=30,
            list_id=lid, start_date="2026-03-09", start_time="11:00", end_time="11:30",
            ai_confidence=95, due_date=""
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Design task data model",
            description="Define the Task node fields, edges, and relationships for the scheduling engine.",
            status="todo", priority="high", category="Coding", estimated_duration=90,
            list_id=lid, start_date="2026-03-09", start_time="11:30", end_time="13:00",
            ai_confidence=73, due_date="2026-03-10"
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Write project proposal",
            description="Draft the 3-page proposal covering scope, timeline, and AI features.",
            status="todo", priority="urgent", category="Writing", estimated_duration=150,
            list_id=lid, start_date="2026-03-10", start_time="09:00", end_time="11:30",
            ai_confidence=68, due_date="2026-03-10"
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Code review session",
            description="Review PRs with the team and discuss architectural decisions.",
            status="todo", priority="normal", category="Meeting", estimated_duration=60,
            list_id=lid, start_date="2026-03-10", start_time="14:00", end_time="15:00",
            ai_confidence=91, due_date=""
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Implement AI scheduler walker",
            description="Build the AIScheduleTask walker using byLLM to suggest optimal time slots.",
            status="todo", priority="urgent", category="Coding", estimated_duration=180,
            list_id=lid, start_date="2026-03-11", start_time="09:00", end_time="12:00",
            ai_confidence=55, due_date="2026-03-13"
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="User testing interviews",
            description="Conduct 3 x 40-min moderated sessions with study participants.",
            status="todo", priority="high", category="Research", estimated_duration=120,
            list_id=rid, start_date="2026-03-11", start_time="12:00", end_time="14:00",
            ai_confidence=82, due_date="2026-03-12"
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Update API documentation",
            description="Document all new walker endpoints and their request/response schemas.",
            status="todo", priority="normal", category="Writing", estimated_duration=120,
            list_id=lid, start_date="2026-03-12", start_time="10:00", end_time="12:00",
            ai_confidence=78, due_date="2026-03-14"
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Admin: respond to emails & planning",
            description="Clear inbox and plan next sprint backlog.",
            status="todo", priority="low", category="Admin", estimated_duration=60,
            list_id=lid, start_date="2026-03-12", start_time="13:00", end_time="14:00",
            ai_confidence=90, due_date=""
        );

        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Sprint retrospective",
            description="Team retro: what went well, what didn't, action items.",
            status="todo", priority="normal", category="Meeting", estimated_duration=90,
            list_id=lid, start_date="2026-03-13", start_time="14:00", end_time="15:30",
            ai_confidence=88, due_date=""
        );

        # Unscheduled backlog tasks
        task_counter += 1;
        here ++> Task(
            id="task_" + str(task_counter), title="Refactor authentication module",
            description="Clean up the auth flow and add proper error handling.",
            status="todo", priority="high", category="Coding", estimated_duration=120,
            list_id=lid, start_date="", start_time="", end_time="",
            ai_confidence=0, due_date="2026-03-20"
        );

        task_counter += 1;
        here ++> Task(
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
            completed_at="2026-03-03T11:30:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Write introduction section",
            category="Writing", estimated_duration=60, actual_duration=75,
            completed_at="2026-03-03T14:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Build prototype UI",
            category="Coding", estimated_duration=120, actual_duration=175,
            completed_at="2026-03-04T12:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Weekly planning meeting",
            category="Meeting", estimated_duration=60, actual_duration=65,
            completed_at="2026-03-04T15:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Fix auth bug",
            category="Coding", estimated_duration=45, actual_duration=90,
            completed_at="2026-03-05T11:00:00"
        );

        task_history_counter += 1;
        here ++> TaskHistory(
            id="hist_" + str(task_history_counter), task_title="Survey design & distribution",
            category="Research", estimated_duration=60, actual_duration=80,
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

        report {"seeded": True, "spaces": 2, "tasks": 12};
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
            "category_overrun_ratios": here.category_overrun_ratios
        };
    }

    can fallback with Root exit {
        if not self.found {
            report {"productivity_peaks": {}, "category_overrun_ratios": {}};
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
    user_productivity_peaks: dict
) -> ScheduleOptimization by llm(temperature=0.2);
sem optimize_conflicted_schedule = "Generate an optimized schedule that resolves all detected time conflicts while aligning tasks with the user's peak productivity hours. Group similar tasks together to minimize context-switching, respect locked tasks, schedule urgent/high-priority tasks during peak hours, and provide clear numbered optimization points explaining each key decision.";
sem optimize_conflicted_schedule.current_schedule = "All currently scheduled tasks with id, title, start_date, start_time, end_time, priority, is_locked, category, estimated_duration fields";
sem optimize_conflicted_schedule.conflicting_task_ids = "IDs of tasks that currently have time overlaps that must be resolved";
sem optimize_conflicted_schedule.user_productivity_peaks = "Dict mapping hour (0-23 as string keys) to productivity score (0-100). Use this to place demanding tasks in high-score slots.";

walker:priv AIOptimizeSchedule {
    has conflicting_task_ids: list;
    has all_tasks: list = [];
    has user_peaks: dict = {};
    has locked_ids: list = [];

    can start with Root entry {
        visit [-->];
    }

    can collect_tasks with Task entry {
        if here.start_date != "" and here.start_time != "" and here.status != "done" {
            self.all_tasks.append({
                "id": here.id, "title": here.title,
                "start_date": here.start_date, "start_time": here.start_time,
                "end_time": here.end_time, "priority": here.priority,
                "is_locked": here.is_locked, "category": here.category,
                "estimated_duration": here.estimated_duration
            });
            if here.is_locked {
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
        optimization = optimize_conflicted_schedule(
            current_schedule=self.all_tasks,
            conflicting_task_ids=self.conflicting_task_ids,
            locked_task_ids=self.locked_ids,
            user_productivity_peaks=self.user_peaks
        );
        report {
            "overview": optimization.overview,
            "optimizations": [
                {"title": o.title, "description": o.description}
                for o in optimization.optimizations
            ],
            "changes": [
                {
                    "task_id": c.task_id,
                    "task_title": c.task_title,
                    "new_start_date": c.new_start_date,
                    "new_start_time": c.new_start_time,
                    "new_end_time": c.new_end_time,
                    "reason": c.reason
                }
                for c in optimization.changes
            ],
            "all_conflicts_resolved": optimization.all_conflicts_resolved,
            "total_minutes": optimization.total_minutes
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
            "completed_at": here.completed_at
        });
    }

    can report_all with Root exit {
        report self.history;
    }
}



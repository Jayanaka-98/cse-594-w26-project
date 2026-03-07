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
        end_time: str = "";
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
        end_time: str = "";

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
            end_time=self.end_time
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
                "end_time": new_task[0].end_time
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
                "end_time": here.end_time
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
        end_time: str = "";

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
                "end_time": here.end_time
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

# ===== AI WALKERS =====

walker:priv AIDescribeTask {
    has title: str,
        context: str = "";

    can run with Root entry {
        extra = (" Context: " + self.context) if self.context else " Be specific and actionable.";
        prompt = f"Write a concise, professional task description (2-3 sentences) for: \"{self.title}\"." + extra;
        # Use Jac byLLM integration (returns plain text)
        resp = prompt by llm(temperature=0.2, max_tokens=300);
        report resp;
    }
}

walker:priv AISuggestSubtasks {
    has title: str,
        description: str = "";

    can run with Root entry {
        desc_part = (f" Description: {self.description}.") if self.description else "";
        prompt = f"Break this task into 3-5 concrete subtasks. Task: \"{self.title}\"." + desc_part + " Return ONLY a JSON array of strings. No other text. Example: [\"subtask 1\", \"subtask 2\"]";
        resp = prompt by llm(temperature=0.2, max_tokens=300);
        report resp;
    }
}

walker:priv AISmartPriority {
    has title: str,
        description: str = "",
        due_date: str = "";

    can run with Root entry {
        desc_part = (f" Description: {self.description}.") if self.description else "";
        due_part = (f" Due date: {self.due_date}.") if self.due_date else "";
        prompt = f"Analyze this task and recommend a priority. Task: \"{self.title}\"." + desc_part + due_part + " Return ONLY one word — exactly one of: urgent, high, normal, low";
        resp = prompt by llm(temperature=0.0, max_tokens=20);
        raw = resp.strip().lower();
        valid_priorities = ["urgent", "high", "normal", "low"];
        report (raw if raw in valid_priorities else "normal");
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

 

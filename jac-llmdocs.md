# Jac Language Reference (v0.10.2)

# 1. TYPES
`int` `float` `str` `bool` `bytes` `any`; `list[T]` `dict[K,V]` `set[T]` `tuple`; `int|None` for optionals (NOT `int?`)
`has x: int;` `has y: str = "default";` `-> ReturnType` for function returns
`True`/`False` capitalized (`true`/`false` pass syntax but FAIL at runtime)
Non-default attributes MUST come before default attributes in same archetype
WRONG: `node N { has x: int = 0; has y: str; }` RIGHT: `node N { has y: str; has x: int = 0; }`

# 2. CONTROL
```jac
if x > 0 { print("pos"); } elif x < 0 { print("neg"); } else { print("zero"); }
for item in items { print(item); }
for i=0 to i<10 by i+=1 { print(i); }
for (i, x) in enumerate(items) { print(i, x); }  # Parens required
while cond { stmt; }
match x { case 1: print("one"); case "hi": print("hi"); case _: print("other"); }
try { risky(); } except ValueError as e { print(e); } finally { cleanup(); }
```
No ternary `?:` -- use `result = ("yes") if x > 0 else ("no");`
No `pass` keyword -- use `{}` or comment
match/case: COLON then statement, NO braces per case. WRONG: `case 1 { stmt; }` WRONG: `case "hi": { stmt; }` RIGHT: `case "hi": stmt;` RIGHT: `case "hi": if True { multi; stmt; }`
`except` not `catch`; `not x` not `!x`

# 3. FUNCTIONS
```jac
def add(x: int, y: int) -> int { return x + y; }
f = lambda x: int -> int : x * 2;                    # Expression form
f = lambda x: int -> int { return x * 2; };           # Block form (MUST return)
g = lambda x: int, y: int -> int : x + y;             # Multi-param
items.sort(key=lambda x: dict -> float : x["v"]);     # As argument
h = lambda e: any -> None { input_val = e.target.value; };  # Assignment = block
noop = lambda e: any -> None { 0; };                   # Empty body (NOT {})
"hello" |> print;                                      # Pipe operator
```
`glob config: dict = {"debug": True};` at module level; access by name in functions
Top-level: only declarations. Executable statements MUST go in `with entry { }` or function body
Docstrings go BEFORE declarations, not inside bodies. Never name abilities `list`/`dict`/`str`/`int`
f-strings: `f"Hello {name}"` (server only, NOT in cl{})

# 4. IMPORTS
```jac
import os;                            # Plain import (semicolon)
import from math { sqrt }             # Selective (NO semicolon after })
import from os { getenv }             # Standard lib
```
WRONG: `import from math, sqrt;` WRONG: `import:py from os { path }`
`include utils;` = C-style merge into current scope (inlines code). `import` = Python-style namespace
`__init__.jac` required for packages. WRONG: `include nodes;` RIGHT: `include mypackage.nodes;`
`with entry { }` always runs when module loads; `with entry:__main__ { }` only when file is main

# 5. ARCHETYPES
```jac
node City { has name: str; has pop: int = 0; }
edge Road { has toll: bool = False; has dist: int = 0; }
walker Explorer { has results: list = []; can explore with City entry; }
obj Config { has debug: bool = False; def show -> None { print(self.debug); } }
enum Priority { LOW, MEDIUM, HIGH }
enum Color { RED = "red", GREEN = "green" }
obj Child(Parent) { }                  # Inheritance
walker W(BaseW) { }                    # Walker inheritance
```
`can` for abilities (with entry/exit); `def` for regular methods
`impl W.ability { code }` for separate implementation blocks
`has f: T by postinit; def postinit { self.f = val; }` for computed fields
Reserved keywords: `obj` `node` `walker` `edge` `enum` `can` `has` -- NEVER use as variable names
WRONG: `obj = json.loads(s);` RIGHT: `data = json.loads(s);`
Boolean NOT: `not x` (Python-style). WRONG: `!x`

# 6. ACCESS
`has:priv x: int;` or `has :priv x: int;` (both valid); `has:pub` `has:protect`
`def:pub method` `can:priv ability`; `walker :pub W { }` = public endpoint (no auth)
Without `:pub` on walker = requires auth token

# 7. GRAPH
```jac
a ++> b;                              # Untyped forward connect
a +>: Friend(since=2020) :+> b;       # Typed forward connect
a <+: Friend() :<+ b;                 # Backward typed connect
a del--> b;                           # Disconnect
people = [-->](?:Person);             # Type filter (assign to var!)
adults = [-->](?:Person, age > 18);   # Type+attr filter
old = [-->](?age > 18);              # Untyped attr filter
friends = [->:Friend:since > 2020:->]; # Edge attr filter
neighbors = [city_a ->:Road:->];      # Variable node traversal
untyped = [node_var -->];             # Untyped from variable
[->:E1:->->:E2:->]                   # Chained typed traversal
root +>: E() :+> (end := A(val=10)); # Walrus on connect
nodes = root ++> Person();            # Returns list; use [0] for single
visit : 0 : [-->];                    # Visit first only (indexed)
```
WRONG: `a ++> Edge() ++> b;` `[-->:E:]` `del a --> b;` `[-->:E1:->-->:E2:->]`
Filters must be assigned or used in expression -- never bare statements

# 8. ABILITIES
```jac
walker Greeter {
    can greet with Root entry { visit [-->]; }
    can meet with Person entry { print(here.name); }
    can done with Root exit { report self.results; }
}
node Person {
    has name: str;
    can announce with FriendFinder entry { print(here.name); }
}
```
`self` = walker/obj instance; `here` = current node; `visitor` = visiting walker (in node abilities)
Root type: capital `Root` in event clauses. WRONG: `` can act with `root entry ``
Union: `can act with Root | MyNode entry { }`

# 9. WALKERS
```jac
result = root spawn W();              # Both spawn forms valid
result = W() spawn root;
visit [-->];                          # Queues nodes (NOT immediate)
visit [->:Road:->];                   # Queue via typed edge
visit [-->] else { print("leaf"); }   # Fallback for dead ends
visit self.target;                    # Visit specific node
report here.value;                    # Appends to .reports array
disengage;                            # Stops walker; exit abilities SKIPPED
skip;                                 # Skip to next queued node (like continue)
```
`result.reports` = list of all reported values. Safe: `result.reports[0] if result.reports else None`
DFS traversal: entries depth-first, exits LIFO. root→A→B: Enter root, Enter A, Enter B, Exit B, Exit A, Exit root
WRONG: `node spawn W();` (`node` is keyword). Use `root` or variable name

# 10. BY_LLM
```jac
import from byllm.lib { Model }
glob llm = Model(model_name="gpt-4o-mini");

# sem Analysis.sentiment = "overall emotional tone"

obj Analysis {
    has sentiment: str = ""
    """overall emotional tone""";
    has confidence: float = 0.0
    """0.0 to 1.0 confidence score""";
}

def classify(text: str) -> str by llm;
def analyze(text: str) -> Analysis by llm();
def translate(text: str, lang: str) -> str by llm(temperature=0.7);

enum Category { WORK, PERSONAL, URGENT }
def categorize(title: str) -> Category by llm();

with entry {
    result = "I love this" by llm;     # Inline
}
```
Semstrings: `has desc: str = "" """hint""";` -- default value REQUIRED before hint
`by llm;` or `by llm();` both valid. `by llm(temperature=0.7)` for params. No import needed for `by llm`

# 11. FILE_JSON
```jac
import json;
with entry {
    f = open("data.json", "r");
    data = json.loads(f.read());       # NOT obj = json.loads(...)
    f.close();
    output = json.dumps(data, indent=2);
}
```
`obj` is a reserved keyword -- never use as variable name

# 12. API
CLI: `jac start file.jac` (NOT `jac serve`); `jac check file.jac`
ALL walkers register at `POST /walker/<WalkerName>`. `GET /walker/<Name>` returns metadata only (does NOT execute)
`__specs__` is VESTIGIAL in 0.10.2 -- methods, path, path_prefix are IGNORED by server
`:pub` on walker = public (no auth). Without `:pub` = requires auth token
Auth endpoints: `POST /user/register` and `POST /user/login`
`:pub` walker root access: READ-ONLY. Graph writes silently fail when `here` is root
Walker `has` fields become POST body params. Non-default `has` = required in POST body
Walkers CANNOT access HTTP headers, query params, cookies, or request object. ALL data via `has` fields
Response: `{"ok":true, "data":{"result":..., "reports":[...]}, "error":null}`
Client fetch: `response.data.reports[0]` for reported values
Union types `T | None = None` in walker has: may cause 422 in jac-scale. Use concrete defaults
OAuth GET redirects can't hit walkers (POST-only). Redirect to frontend, then POST to walker
SSO routes (`/sso/{platform}/{operation}`) and OpenAPI (`/docs`) = jac-scale plugin only
Compiler does NOT catch missing method params at compile time -- fails at runtime

# 13. WEBSOCKET
```jac
async walker :pub Echo {
    async can echo with Root entry { report here; }
}
```
Connect: `ws://host/walker/Echo`
`socket.notify_users(ids, msg);` `socket.notify_channels(names, msg);` `broadcast=True` for all clients
Remove `:pub` for authenticated websocket

# 14. WEBHOOKS
```jac
walker :pub WebhookHandler {
    obj __specs__ {
        static has webhook: dict = {"type": "header", "name": "X-Sig"};
    }
    can handle with Root entry { report "ok"; }
}
```

# 15. SCHEDULER
```jac
walker DailyTask {
    obj __specs__ {
        static has schedule: dict = {"trigger": "cron", "hour": "9"};
        static has private: bool = True;
    }
    can run with Root entry { report "done"; }
}
```
Triggers: `cron` `interval` `date`

# 16. ASYNC
```jac
async walker :pub AsyncW { async can work with Root entry { report "done"; } }
future = flow expensive_fn();          # Thread pool (CPU-bound)
result = wait future;                  # Blocks until done
```
`async`/`await` = event loop (I/O-bound). `flow`/`wait` = thread pool (CPU-bound)
Task status: `task.__jac__.status;` `task.__jac__.reports;` `task.__jac__.error;`

# 17. PERMISSIONS
```jac
node.__jac__.grant(root, WritePerm);
node.__jac__.revoke(root, WritePerm);
node.__jac__.check_access(root, ReadPerm);
```
Levels: `NoPerm` `ReadPerm` `ConnectPerm` `WritePerm`

# 18. PERSISTENCE
Nodes connected to root auto-persist. `save(node);` `commit();` `&id` for reference; `del node;` `commit();`

# 19. TESTING
```jac
test { assert 1 + 1 == 2; }
test { assert "hello".upper() == "HELLO"; }
```
0.10.2: no test names. WRONG: `test "name" { }` WRONG: `test my_test { }`

# 20. STDLIB
`print()` `len()` `range()` `enumerate()` `zip()` `map()` `filter()` `sorted()` `type()` `isinstance()`
`str.upper()` `.lower()` `.strip()` `.split()` `.replace()` `.startswith()` `.format()`
`list.append()` `.extend()` `.pop()` `.sort()` `.reverse()` `list[i]` `list[a:b]`
`dict.keys()` `.values()` `.items()` `.get(k, default)` `.update()` `.pop(k)`
`(a, b) = func();` tuple unpacking (parens required)

# 21. JSX/CLIENT
TWO approaches: (1) `.cl.jac` files = entire file is client-side (no `cl{}` wrapper). (2) `cl{}` blocks in `.jac` files = mixed server+client. Both work.
`.cl.jac` files: auto client-side, never `include` them
`cl import` / `sv import` prefixes at TOP LEVEL (outside `cl{}` block) for cross-context imports
```jac
cl import from react { useEffect }
sv import from __main__ { GetCount, Increment }

cl {
    def:pub app() -> JsxElement {
        has count: int = 0;            # Reactive state (auto useState)

        async def fetchCount() -> None {
            result = root spawn GetCount();
            count = result.reports[0] if result.reports else 0;
        }

        can with entry { fetchCount(); }  # useEffect mount

        return <div className="app">
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                async def doInc() -> None {
                    root spawn Increment();
                    fetchCount();
                }
                doInc();
            }}>+1</button>
        </div>;
    }
}
```
`has` inside `def:pub` = reactive state (auto `useState`). `can with entry { }` = `useEffect(fn, [])`. `can with exit { }` = cleanup. `can with [dep] entry { }` = `useEffect(fn, [dep])`
`root spawn` in cl{} compiles to `await`; function MUST be `async def`
Component return type: `-> JsxElement` (NOT `-> any` which conflicts with builtin)
JSX comprehensions: `{[<li>{item}</li> for item in items]}` compiles to `.map()`; `{[<li>{x}</li> for x in items if x.active]}` compiles to `.filter().map()`
cl{} JS builtins: `.length` not `len()`; `String(x)` not `str(x)`; `parseInt(x)` not `int(x)`; `Math.min`/`Math.max`; `.trim()` not `.strip()`; no `range()`; no f-strings (use `+`); no tuple unpacking; `className` not `class`
`new` keyword does NOT exist. WRONG: `new Date()`. RIGHT: `Reflect.construct(Date, [val])`
`None` compiles to `null` in cl{} context. Use `None` in Jac source
List concat in cl{}: use `items.append(x)` not `items = items + [x]`
CSS: `import "./styles.css";` or `import '.styles.css';` (dot-prefix auto-converts)
`.jac/` auto-generated, never modify manually. npm deps: ALL in `jac.toml`; NEVER `npm install` in `.jac/client/`

# 22. CLIENT_AUTH
```jac
cl import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
cl {
    def:pub app() -> JsxElement {
        has isLoggedIn: bool = False;
        can with entry { isLoggedIn = jacIsLoggedIn(); }
        # jacSignup(email, password) jacLogin(email, password) jacLogout()
    }
}
```
Per-user graph isolation: each authenticated user gets their own root node

# 23. JAC.TOML
```
[project]
name = "myapp"
entry-point = "main.jac"

[dependencies]
python-dotenv = ">=1.0.0"

[dependencies.npm]
tailwindcss = "^4.0.0"
"@tailwindcss/postcss" = "^4.0.0"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"

[serve]
base_route_app = "app"
port = 8000

[plugins.client]
port = 5173
```
`base_route_app` must match `def:pub app` function name. Tailwind v4: add both packages to `[dependencies.npm]`

# 24. FULLSTACK_SETUP
`jac create --use client` (NOT `--use fullstack`); `jac install` syncs all deps; `jac add --npm pkgname`
Project structure: `main.jac` (entry), `__init__.jac` (with full dotted paths), `jac.toml`, `.jac/` (auto-gen)
WRONG: `include nodes;` in `__init__.jac` RIGHT: `include mypackage.nodes;`

# 25. DEV_SERVER
`jac start --dev` for development; `--port` = Vite frontend (8000); `--api_port` = backend (8001, auto-proxied)
Proxy routes: `/walker/*` `/function/*` `/user/*` forwarded to backend
`jac start --no-client` for API-only mode

# 26. DEPLOY_ENV
```
FROM python:3.11-slim
RUN pip install jaseci
COPY . /app
WORKDIR /app
CMD ["jac", "start", "main.jac"]
```
`jaseci` = full runtime (persistence/auth plugins). `jaclang` = compiler-only
`jac start --scale` for production scaling (no `-t` flag)
Env vars: `DATABASE_URL` `JAC_SECRET_KEY` `OPENAI_API_KEY`
`.env` not auto-loaded: `import from dotenv { load_dotenv }` then `glob _: bool = load_dotenv() or True;`

# PATTERN 1: Fullstack Counter (single-file with cl{} block)
```jac
# main.jac
node Counter { has val: int = 0; }

walker :pub GetCount {
    can get with Root entry {
        counts = [-->](?:Counter);
        if counts { report counts[0].val; }
        else { report 0; }
    }
}

walker :pub Increment {
    can inc with Root entry {
        counts = [-->](?:Counter);
        if counts { counts[0].val += 1; }
    }
}

with entry {
    root ++> Counter(val=0);
}

cl import from react { useEffect }
sv import from __main__ { GetCount, Increment }

cl {
    def:pub app() -> JsxElement {
        has count: int = 0;

        async def fetchCount() -> None {
            result = root spawn GetCount();
            count = result.reports[0] if result.reports else 0;
        }

        can with entry { fetchCount(); }

        return <div className="counter">
            <h1>Count: {count}</h1>
            <button onClick={lambda e: any -> None {
                async def doInc() -> None {
                    root spawn Increment();
                    fetchCount();
                }
                doInc();
            }}>+1</button>
        </div>;
    }
}
```
```
# jac.toml
[project]
name = "counter"
entry-point = "main.jac"
[serve]
base_route_app = "app"
```

# PATTERN 2: Walker Graph Traversal (Cities/Roads)
```jac
node City { has name: str; has pop: int = 0; }
edge Road { has toll: bool = False; has dist: int = 0; }

walker FindReachable {
    has reachable: list = [];
    can start with Root entry { visit [-->]; }
    can explore with City entry {
        self.reachable.append({"name": here.name, "pop": here.pop});
        visit [->:Road:->];
    }
    can done with Root exit { report self.reachable; }
}

walker DeleteRoute {
    has from_city: str;
    has to_city: str;
    can start with Root entry { visit [-->]; }
    can find with City entry {
        if here.name == self.from_city {
            targets = [->:Road:->](?:City, name == self.to_city);
            for t in targets { here del--> t; }
            disengage;
        }
        visit [->:Road:->];
    }
}

with entry {
    a = City(name="NYC", pop=8000000);
    b = City(name="Boston", pop=700000);
    c = City(name="DC", pop=700000);
    root ++> a;
    a +>: Road(dist=200) :+> b;
    a +>: Road(toll=True, dist=230) :+> c;
    b +>: Road(dist=440) :+> c;

    # Traverse from specific variable node
    neighbors = [a ->:Road:->];
    toll_roads = [a ->:Road:toll == True:->];

    result = root spawn FindReachable();
    print(result.reports[0]);

    root spawn DeleteRoute(from_city="NYC", to_city="DC");
    result2 = root spawn FindReachable();
    print(result2.reports[0]);
}
```

# PATTERN 3: API Endpoints (Todo CRUD)
```jac
node Todo {
    has id: str;
    has title: str;
    has done: bool = False;
    has priority: str = "medium";
}

walker :pub ListTodos {
    has todos: list = [];
    can start with Root entry { visit [-->]; }
    can collect with Todo entry {
        self.todos.append({
            "id": here.id, "title": here.title,
            "done": here.done, "priority": here.priority
        });
    }
    can done with Root exit { report self.todos; }
}

walker :pub AddTodo {
    has title: str;
    has priority: str = "medium";
    can add with Root entry {
        import uuid;
        new_id = str(uuid.uuid4());
        nodes = here ++> Todo(id=new_id, title=self.title, priority=self.priority);
        report {"id": new_id, "title": self.title};
    }
}

walker :pub FilterTodos {
    has filter_by: str = "all";
    has results: list = [];
    can start with Root entry { visit [-->]; }
    can check with Todo entry {
        match self.filter_by {
            case "high": if here.priority == "high" { self.results.append(here.title); }
            case "done": if here.done { self.results.append(here.title); }
            case _: self.results.append(here.title);
        }
    }
    can done with Root exit { report self.results; }
}

with entry { }
```
Client fetch: `fetch("/walker/AddTodo", {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({"title":"Buy milk"})}).then(r => r.json()).then(d => d.data.reports[0])`

# COMMON ERRORS
WRONG: `true`/`false` -> RIGHT: `True`/`False`
WRONG: `entry { }` -> RIGHT: `with entry { }`
WRONG: `import from math, sqrt;` -> RIGHT: `import from math { sqrt }`
WRONG: `import:py from os { path }` -> RIGHT: `import from os { path }`
WRONG: `node spawn W();` -> RIGHT: `root spawn W();` (node is keyword)
WRONG: `a ++> Edge() ++> b;` -> RIGHT: `a +>: Edge() :+> b;`
WRONG: `[-->:E:]` -> RIGHT: `[->:E:->]`
WRONG: `[-->:E1:->-->:E2:->]` -> RIGHT: `[->:E1:->->:E2:->]`
WRONG: `del a --> b;` -> RIGHT: `a del--> b;`
WRONG: `` (`?Type) `` -> RIGHT: `(?:Type)`
WRONG: `` (`?Type:attr>v) `` -> RIGHT: `(?:Type, attr > v)`
WRONG: `` can act with `root entry `` -> RIGHT: `can act with Root entry`
WRONG: `test "name" { }` -> RIGHT: `test { }` (no names in 0.10.2)
WRONG: `test my_test { }` -> RIGHT: `test { }`
WRONG: `obj = json.loads(s);` -> RIGHT: `data = json.loads(s);`
WRONG: `str?` -> RIGHT: `str | None`
WRONG: `jac serve file.jac` -> RIGHT: `jac start file.jac`
WRONG: `jac create --use fullstack` -> RIGHT: `jac create --use client`
WRONG: `static has auth: bool = False;` in __specs__ -> RIGHT: `walker :pub W { }`
WRONG: `<div class="x">` -> RIGHT: `<div className="x">`
WRONG: `len(items)` in cl{} -> RIGHT: `items.length`
WRONG: `str(x)` in cl{} -> RIGHT: `String(x)`
WRONG: `f"Hello {x}"` in cl{} -> RIGHT: `"Hello " + x`
WRONG: `items = items + [x]` in cl{} -> RIGHT: `items.append(x)`
WRONG: `lambda e: any -> None {}` -> RIGHT: `lambda e: any -> None { 0; }`
WRONG: `include nodes;` in __init__.jac -> RIGHT: `include mypackage.nodes;`
WRONG: `npm install` in .jac/client/ -> RIGHT: `jac add --npm pkgname`
WRONG: `print("x");` at top level -> RIGHT: `with entry { print("x"); }`
WRONG: `case 1 { stmt; }` -> RIGHT: `case 1: stmt;`
WRONG: `case "hi": { stmt; }` -> RIGHT: `case "hi": if True { stmt; }`
WRONG: `catch Error as e { }` -> RIGHT: `except Error as e { }`
WRONG: `result = x > 0 ? "y" : "n";` -> RIGHT: `result = ("y") if x > 0 else ("n");`
WRONG: `has x: int = 0; has y: str;` -> RIGHT: `has y: str; has x: int = 0;`
WRONG: `glob counter;` inside function -> RIGHT: just use `counter` directly
WRONG: `result.returns[0]` -> RIGHT: `result.reports[0]`
WRONG: `.map(lambda x -> ...)` in JSX -> RIGHT: `{[<li>{x}</li> for x in items]}`
WRONG: `pass` -> RIGHT: `{}` or comment
WRONG: `!x` -> RIGHT: `not x`
WRONG: `__specs__` methods/path/path_prefix -> RIGHT: ignored in 0.10.2; all walkers POST /walker/<Name>
WRONG: `new Date()` in cl{} -> RIGHT: `Reflect.construct(Date, [val])`
WRONG: `def:pub app() -> any` -> RIGHT: `def:pub app() -> JsxElement`
WRONG: `fetch("/api/todos")` -> RIGHT: `fetch("/walker/ListTodos", {method:"POST"})`
WRONG: `ExecutionContext.get()` for headers -> RIGHT: pass data as walker `has` field in POST body
WRONG: `has x: list;` (no default) -> RIGHT: `has x: list = [];` (non-default = required POST param)
WRONG: `GET /walker/Name` to execute -> RIGHT: `POST /walker/Name`
WRONG: OAuth redirect to `/walker/Callback` -> RIGHT: redirect to frontend, then POST to walker
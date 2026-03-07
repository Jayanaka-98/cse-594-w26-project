import from os { listdir, path }

# Node types for filesystem graph
node FileNode {
    has path: str;
    has code: str = "";
}

node DirNode {
    has path: str;
}

node Project {
    has path: str;
    has toml: str = "";
}

edge Contains {
    has name: str = "";
}

walker :pub BuildGraph {
    has created: list = [];
    has base_dir: str = ".";
    has tree_lines: list = [];

    can start with Root entry {
        base = "."; # run from project root (cwd)
        self.base_dir = base;
        self.tree_lines = [];
        self.traverse(base, 0);

        # build single string from lines
        out = "";
        for l in self.tree_lines { out += l + "\n"; }
        report out;
    }
    def traverse(dir_path: str, indent: int) -> None {
        # create a Dir node for this path
        dir_node = DirNode(path=dir_path);
        root ++> dir_node;
        self.created.append({"type": "dir", "path": dir_path});

        # append directory display line
        indent_str = "";
        for i in range(indent) { indent_str += "  "; }
        name_disp = path.basename(dir_path);
        if name_disp == "" { name_disp = dir_path; }
        self.tree_lines.append(indent_str + name_disp + "/");

        # list entries; skip dot-starting entries
        items = listdir(dir_path);
        for name in items {
            # skip hidden files/dirs
            if name[0] == "." { continue; }
            p = path.join(dir_path, name);
            # directories: recurse and link, but skip dot dirs
            if path.isdir(p) {
                child = DirNode(path=p);
                root ++> child;
                dir_node +>: Contains(name=name) :+> child;
                self.created.append({"type": "dir", "path": p});
                self.traverse(p, indent + 1);
            } else {
                # include file if it's in base dir (any file) or endswith .jac
                if dir_path != self.base_dir and not name.endswith(".jac") { continue; }

                # read file contents when possible
                file_code = "";
                try { f = open(p, "r"); file_code = f.read(); f.close(); }
                except Exception as e { file_code = ""; }

                fnode = FileNode(path=p, code=file_code);
                root ++> fnode;
                dir_node +>: Contains(name=name) :+> fnode;
                self.created.append({"type": "file", "path": p});

                # append file display line
                indent_str2 = "";
                for i in range(indent + 1) { indent_str2 += "  "; }
                self.tree_lines.append(indent_str2 + name);

                # create Project node when encountering jac.toml
                if name == "jac.toml" or name == "Jac.toml" {
                    proj = Project(path=dir_path, toml=file_code);
                    root ++> proj;
                    dir_node +>: Contains(name="jac.toml") :+> proj;
                    self.created.append({"type": "project", "path": dir_path});
                }
            }
        }
    }
}

with entry {
    result = root spawn BuildGraph();
    # print(result.reports[0] if result.reports else []);
}




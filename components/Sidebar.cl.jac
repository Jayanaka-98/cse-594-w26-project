"""Sidebar navigation component for FlowBoard."""

def:pub Sidebar(
    spaces: list,
    lists: list,
    selectedSpaceId: str,
    selectedListId: str,
    spacesLoading: bool,
    onSelectSpace: any,
    onSelectList: any,
    onCreateSpace: any,
    onCreateList: any,
    onDeleteSpace: any,
    onDeleteList: any
) -> any {
    return
        <div className="sidebar">
            <div className="sidebar-section">
                <div className="sidebar-section-header">
                    <span className="sidebar-section-title">SPACES</span>
                    <button
                        onClick={onCreateSpace}
                        className="sidebar-add-btn"
                        title="Create Space"
                    >
                        +
                    </button>
                </div>
                {(
                    <div className="sidebar-loading">Loading...</div>
                ) if spacesLoading else (
                    <div className="spaces-list">
                        {(
                            <div className="sidebar-empty">
                                No spaces yet
                            </div>
                        ) if spaces.length == 0 else (
                            <div>
                                {[
                                    <SpaceItem
                                        key={space.id}
                                        space={space}
                                        lists={lists.filter(
                                            lambda l: any -> bool { return l.space_id == space.id; }
                                        )}
                                        selectedSpaceId={selectedSpaceId}
                                        selectedListId={selectedListId}
                                        onSelectSpace={onSelectSpace}
                                        onSelectList={onSelectList}
                                        onCreateList={onCreateList}
                                        onDeleteSpace={onDeleteSpace}
                                        onDeleteList={onDeleteList}
                                    /> for space in spaces
                                ]}
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>;
}

def:pub SpaceItem(
    space: dict,
    lists: list,
    selectedSpaceId: str,
    selectedListId: str,
    onSelectSpace: any,
    onSelectList: any,
    onCreateList: any,
    onDeleteSpace: any,
    onDeleteList: any
) -> any {
    isExpanded = space.id == selectedSpaceId;
    spaceClass = (
        "space-row space-row-selected"
        if isExpanded
        else "space-row"
    );

    return
        <div className="space-group">
            <div className={spaceClass}>
                <button
                    className="space-row-main"
                    onClick={lambda -> None { onSelectSpace(space.id); }}
                >
                    <span className={"space-dot space-color-" + space.color}></span>
                    <span className="space-name">{space.name}</span>
                    <span className="space-arrow">{("▾" if isExpanded else "▸")}</span>
                </button>
                <button
                    onClick={lambda -> None { onDeleteSpace(space.id); }}
                    className="sidebar-delete-btn"
                    title="Delete space"
                >
                    ×
                </button>
            </div>
            {(
                <div className="lists-group">
                    {[
                        <ListItem
                            key={lst.id}
                            lst={lst}
                            selectedListId={selectedListId}
                            onSelectList={onSelectList}
                            onDeleteList={onDeleteList}
                        /> for lst in lists
                    ]}
                    <button
                        onClick={lambda -> None { onCreateList(space.id); }}
                        className="add-list-btn"
                    >
                        + Add List
                    </button>
                </div>
            ) if isExpanded else None}
        </div>;
}

def:pub ListItem(
    lst: dict,
    selectedListId: str,
    onSelectList: any,
    onDeleteList: any
) -> any {
    listClass = (
        "list-row list-row-selected"
        if lst.id == selectedListId
        else "list-row"
    );

    return
        <div className={listClass}>
            <button
                className="list-row-main"
                onClick={lambda -> None { onSelectList(lst.id); }}
            >
                <span className="list-icon">≡</span>
                <span className="list-name">{lst.name}</span>
            </button>
            <button
                onClick={lambda -> None { onDeleteList(lst.id); }}
                className="sidebar-delete-btn"
                title="Delete list"
            >
                ×
            </button>
        </div>;
}

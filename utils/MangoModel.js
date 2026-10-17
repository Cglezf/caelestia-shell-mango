.pragma library

function workspaceId(monitorId, tag) {
    return tag === 0 ? -(monitorId + 1) : monitorId * 1000 + tag;
}

function clientTags(client) {
    return client.tags && client.tags.length ? client.tags : [1];
}

function onTag(client, output, tag) {
    return client.monitor === output && clientTags(client).includes(tag);
}

function clientAddress(clientId) {
    return "0x" + Number(clientId).toString(16);
}

function selectorId(request) {
    const match = /address:(?:0x)?([0-9a-fA-F]+)/.exec(request);
    return match ? parseInt(match[1], 16) : -1;
}

function specialVisible(clients, output) {
    return clients.some(c => onTag(c, output, 0) && c.is_visible);
}

// Workspace numbers and shell filtering tags are different concepts. Mango
// does not expose Hyprland window tags; apply app-ID rules locally instead.
function windowTags(client, rules) {
    const appid = client.appid || "";
    const tags = appid ? [appid] : [];
    for (const pattern of Object.keys(rules || {})) {
        if (pattern.endsWith("*") ? appid.startsWith(pattern.slice(0, -1)) : appid === pattern) {
            const values = rules[pattern];
            if (Array.isArray(values)) tags.push(...values.filter(tag => typeof tag === "string"));
        }
    }
    return [...new Set(tags)];
}

// Visibility is authoritative for multi-tag views, global windows and overlays.
function visibleToplevels(toplevels, monitor) {
    return monitor ? toplevels.filter(t => t.monitor === monitor && t.lastIpcObject.visible && t.lastIpcObject.mapped) : [];
}

function workspaceLabel(workspace, fallback) {
    if (!workspace) return String(fallback);
    const name = workspace.name;
    return name.startsWith("special:") ? name.slice(8)[0] : name;
}

function keyboardChanges(previous, current) {
    if (!previous || !current.ready || !previous.ready) return [];
    return ["capsLock", "numLock", "layout"].filter(key => previous[key] !== current[key]
        && (key !== "layout" || (previous.layout && current.layout)));
}

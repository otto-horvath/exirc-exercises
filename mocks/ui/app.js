(() => {
  "use strict";

  const MAX_MESSAGE_LENGTH = 400;
  const STORAGE = {
    nick: "exirc:mock:nick",
    channel: "exirc:mock:channel",
  };

  const NICK_PATTERN = /^[A-Za-z0-9_\-\[\]\\`^{}|]{1,30}$/;
  const CHANNEL_PATTERN = /^[#&][A-Za-z0-9_\-\[\]\\`^{}|]{1,63}$/;
  const NICK_CHAR = /[A-Za-z0-9_\-\[\]\\`^{}|]/;

  const DEMO = {
    nicks: ["carla", "diego", "elisa", "felipe", "gabi", "hugo", "iris", "joana"],
    messages: [
      "the mock is holding up well.",
      "try disconnecting and reconnecting.",
      "Alt+arrow keys cycle the open tabs.",
      "the composer is deliberately plain text.",
      "has anyone tried joining a second channel?",
      "this message came from the demo panel.",
      "the member list is only a local array.",
    ],
    mentions: [
      "{nick}: check the unread badge after switching tabs.",
      "{nick}, the member drawer opens on narrow screens.",
      "ping {nick} — this is a simulated mention.",
    ],
    joinNicks: ["hugo", "iris", "joana", "kai", "lucas", "marta"],
    dmNicks: ["bruno", "carla", "diego", "elisa", "felipe"],
    dmMessages: [
      "hey, got a minute?",
      "the DM tab opens from a click on a nick.",
      "this is only local demo data.",
      "try Alt+1 and Alt+2 from the composer.",
    ],
  };

  const timeFormatter = new Intl.DateTimeFormat("en", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const dayFormatter = new Intl.DateTimeFormat("en", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });

  const els = {
    connectionPill: document.getElementById("connection-pill"),
    connectionLabel: document.getElementById("connection-label"),
    connectionBanner: document.getElementById("connection-banner"),
    connectionBannerText: document.getElementById("connection-banner-text"),
    bannerReconnect: document.getElementById("banner-reconnect"),
    tabs: document.getElementById("tabs"),
    joinButton: document.getElementById("join-button"),
    conversationPanel: document.getElementById("conversation-panel"),
    conversationKind: document.getElementById("conversation-kind"),
    conversationName: document.getElementById("conversation-name"),
    conversationTopic: document.getElementById("conversation-topic"),
    memberCount: document.getElementById("member-count"),
    messageLog: document.getElementById("message-log"),
    jumpLatest: document.getElementById("jump-latest"),
    composerPrompt: document.getElementById("composer-prompt"),
    composerInput: document.getElementById("composer-input"),
    sendButton: document.getElementById("send-button"),
    composerCount: document.getElementById("composer-count"),
    memberList: document.getElementById("member-list"),
    membersSummary: document.getElementById("members-summary"),
    membersButton: document.getElementById("members-button"),
    sidebar: document.getElementById("sidebar"),
    sidebarClose: document.getElementById("sidebar-close"),
    sidebarOverlay: document.getElementById("sidebar-overlay"),
    demoToggle: document.getElementById("demo-toggle"),
    shortcutsButton: document.getElementById("shortcuts-button"),
    joinDialog: document.getElementById("join-dialog"),
    joinForm: document.getElementById("join-form"),
    joinInput: document.getElementById("join-channel"),
    joinError: document.getElementById("join-error"),
    shortcutsDialog: document.getElementById("shortcuts-dialog"),
    toast: document.getElementById("toast"),
  };

  const state = {
    nick: "guest",
    server: "irc.brasirc.com.br",
    port: "6697",
    network: "BrasIRC",
    connection: "online",
    tabs: [],
    messages: new Map(),
    activeTabId: "",
    messageSeq: 0,
    guestSeq: 0,
    reconnectTimer: null,
    completion: null,
    sidebarReturnFocus: null,
  };

  let toastTimer = null;
  let demoButtons = [];

  function readStorage(key) {
    try {
      return sessionStorage.getItem(key) || "";
    } catch {
      return "";
    }
  }

  function safeNick(value) {
    const nick = String(value || "").trim();
    return NICK_PATTERN.test(nick) ? nick : "guest";
  }

  function normalizeChannel(value) {
    const trimmed = String(value || "").trim();
    if (!trimmed) return "";
    return /^[#&]/.test(trimmed) ? trimmed : `#${trimmed}`;
  }

  function initialChannelName() {
    const name = normalizeChannel(readStorage(STORAGE.channel) || "#brasirc");
    return CHANNEL_PATTERN.test(name) ? name : "#brasirc";
  }

  function findTab(id) {
    return state.tabs.find((tab) => tab.id === id);
  }

  function activeTab() {
    return findTab(state.activeTabId);
  }

  function stripPrefix(name) {
    return String(name || "").replace(/^[@&+~%]/, "");
  }

  function memberRank(name) {
    if (/^[@&]/.test(name)) return 0;
    if (/^\+/.test(name)) return 1;
    if (/^[~%]/.test(name)) return 2;
    return 3;
  }

  function lower(value) {
    return String(value || "").toLowerCase();
  }

  function isSelf(nick) {
    return lower(nick) === lower(state.nick);
  }

  function isNarrow() {
    return window.matchMedia("(max-width: 900px)").matches;
  }

  function pad2(value) {
    return String(value).padStart(2, "0");
  }

  function formatTime(date) {
    return timeFormatter.format(date);
  }

  function dayKey(date) {
    return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
  }

  function formatDay(date) {
    return dayKey(date) === dayKey(new Date()) ? "Today" : dayFormatter.format(date);
  }

  function minutesAgo(minutes) {
    return new Date(Date.now() - minutes * 60_000);
  }

  function messageHasMention(text) {
    const haystack = lower(text);
    const needle = lower(state.nick);
    if (!needle) return false;

    let from = 0;
    let index = haystack.indexOf(needle, from);

    while (index !== -1) {
      const before = index === 0 ? " " : haystack[index - 1];
      const afterIndex = index + needle.length;
      const after = afterIndex >= haystack.length ? " " : haystack[afterIndex];

      if (!NICK_CHAR.test(before) && !NICK_CHAR.test(after)) return true;
      from = index + 1;
      index = haystack.indexOf(needle, from);
    }

    return false;
  }

  function makeMessage(data) {
    const type = data.type || "message";
    const text = data.text == null ? "" : String(data.text);
    const nick = data.nick || "";

    let mention = false;
    if (Object.prototype.hasOwnProperty.call(data, "mention")) {
      mention = Boolean(data.mention);
    } else if ((type === "message" || type === "action") && !isSelf(nick)) {
      mention = messageHasMention(text);
    }

    return {
      id: `m${++state.messageSeq}`,
      type,
      nick,
      text,
      mention,
      time: data.time instanceof Date ? data.time : new Date(),
    };
  }

  function seedMessage(tabId, data) {
    const tab = findTab(tabId);
    if (!tab) return null;

    const message = makeMessage(data);
    const messages = state.messages.get(tabId) || [];
    messages.push(message);
    state.messages.set(tabId, messages);
    return message;
  }

  function pushMessage(tabId, data, options = {}) {
    const tab = findTab(tabId);
    if (!tab) return null;

    const stickToBottom = options.forceScroll === true || isNearBottom();
    const message = makeMessage(data);
    const messages = state.messages.get(tabId) || [];
    messages.push(message);
    state.messages.set(tabId, messages);

    if (
      tabId !== state.activeTabId &&
      options.incrementUnread !== false &&
      message.type !== "system"
    ) {
      tab.unread = (tab.unread || 0) + 1;
      if (message.mention) tab.mentions = (tab.mentions || 0) + 1;
    }

    if (tabId === state.activeTabId) {
      renderLog({ forceScroll: stickToBottom });
    }

    renderTabs();
    updateTitle();
    return message;
  }

  function isNearBottom() {
    const log = els.messageLog;
    return log.scrollHeight - log.scrollTop - log.clientHeight < 80;
  }

  function updateJumpButton() {
    const log = els.messageLog;
    const distance = log.scrollHeight - log.scrollTop - log.clientHeight;
    els.jumpLatest.hidden = distance < 80 || log.scrollHeight <= log.clientHeight + 10;
  }

  function appendNick(parent, nick) {
    if (isSelf(nick)) {
      const span = document.createElement("span");
      span.className = "nick self";
      span.textContent = nick;
      parent.append(span);
      return;
    }

    const button = document.createElement("button");
    button.type = "button";
    button.className = "nick";
    button.textContent = nick;
    button.title = `Open a private conversation with ${nick}`;
    button.addEventListener("click", () => openDm(nick));
    parent.append(button);
  }

  function createMessageElement(message) {
    const row = document.createElement("div");
    row.className = `message ${message.type}${message.mention ? " mention" : ""}`;

    const time = document.createElement("time");
    time.className = "time";
    time.dateTime = message.time.toISOString();
    time.textContent = formatTime(message.time);
    time.title = message.time.toLocaleString();

    const body = document.createElement("div");
    body.className = "body";

    if (message.type === "system") {
      const text = document.createElement("span");
      text.className = "system-text";
      text.textContent = message.text;
      body.append(text);
    } else if (message.type === "notice") {
      const prefix = document.createElement("span");
      prefix.className = "notice-prefix";
      prefix.textContent = `-${message.nick || "server"}-`;

      const text = document.createElement("span");
      text.className = "text";
      text.textContent = ` ${message.text}`;

      body.append(prefix, text);
    } else if (message.type === "action") {
      const star = document.createElement("span");
      star.className = "action-text";
      star.textContent = "* ";

      const text = document.createElement("span");
      text.className = "text action-text";
      text.textContent = ` ${message.text}`;

      body.append(star);
      appendNick(body, message.nick);
      body.append(text);
    } else {
      appendNick(body, message.nick);
      const text = document.createElement("span");
      text.className = "text";
      text.textContent = ` ${message.text}`;
      body.append(text);
    }

    row.append(time, body);
    return row;
  }

  function createDateDivider(date) {
    const divider = document.createElement("div");
    divider.className = "date-divider";
    divider.textContent = formatDay(date);
    return divider;
  }

  function renderLog({ forceScroll = false } = {}) {
    const tab = activeTab();
    if (!tab) return;

    const log = els.messageLog;
    const stickToBottom = forceScroll || isNearBottom();
    const messages = state.messages.get(tab.id) || [];

    log.textContent = "";

    if (messages.length === 0) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent =
        "No messages in this tab yet. Send one from the composer or use the demo panel.";
      log.append(empty);
    } else {
      let currentDay = "";

      for (const message of messages) {
        const key = dayKey(message.time);
        if (key !== currentDay) {
          currentDay = key;
          log.append(createDateDivider(message.time));
        }
        log.append(createMessageElement(message));
      }
    }

    if (stickToBottom) log.scrollTop = log.scrollHeight;
    updateJumpButton();
  }

  function badgeText(count) {
    return count > 99 ? "99+" : String(count);
  }

  function renderTabs() {
    els.tabs.textContent = "";

    state.tabs.forEach((tab, index) => {
      const isActive = tab.id === state.activeTabId;
      const isChannel = tab.type === "channel";
      const kind = isChannel ? tab.name.charAt(0) : "@";
      const displayName = isChannel ? tab.name.slice(1) : tab.name;

      const button = document.createElement("button");
      button.type = "button";
      button.className = "tab";
      button.setAttribute("role", "tab");
      button.setAttribute("aria-selected", String(isActive));
      button.setAttribute("aria-controls", "conversation-panel");
      button.dataset.tabId = tab.id;
      button.tabIndex = isActive ? 0 : -1;
      button.title = isChannel ? tab.name : `Direct message with ${tab.name}`;

      const kindSpan = document.createElement("span");
      kindSpan.className = "tab-kind";
      kindSpan.setAttribute("aria-hidden", "true");
      kindSpan.textContent = kind;

      const nameSpan = document.createElement("span");
      nameSpan.textContent = displayName;

      button.append(kindSpan, nameSpan);

      const unread = tab.unread || 0;
      const mentions = tab.mentions || 0;
      const count = mentions || unread;

      if (count > 0) {
        const badge = document.createElement("span");
        badge.className = `badge${mentions ? " badge-mention" : ""}`;
        badge.textContent = badgeText(count);
        button.append(badge);
      }

      const unreadLabel = mentions
        ? `, ${mentions} mention${mentions === 1 ? "" : "s"}`
        : unread
          ? `, ${unread} unread message${unread === 1 ? "" : "s"}`
          : "";
      button.setAttribute(
        "aria-label",
        `${isChannel ? `Channel ${tab.name}` : `Direct message with ${tab.name}`}${unreadLabel}`,
      );

      button.addEventListener("click", () => {
        activateTab(tab.id, { focus: "auto" });
      });

      els.tabs.append(button);
      if (isActive) scrollTabIntoView(button);
    });
  }

  function scrollTabIntoView(button) {
    const container = els.tabs;
    const containerRect = container.getBoundingClientRect();
    const buttonRect = button.getBoundingClientRect();

    if (buttonRect.left < containerRect.left || buttonRect.right > containerRect.right) {
      button.scrollIntoView({ block: "nearest", inline: "nearest" });
    }
  }

  function renderTopic() {
    const tab = activeTab();
    if (!tab) return;

    const isChannel = tab.type === "channel";
    const online = state.connection === "online";
    const count = isChannel ? tab.members.length : 2;

    els.conversationKind.textContent = isChannel ? tab.name.charAt(0) : "@";
    els.conversationName.textContent = tab.name;
    els.conversationTopic.textContent = tab.topic;
    els.conversationPanel.setAttribute(
      "aria-label",
      isChannel ? `Channel ${tab.name}` : `Direct message with ${tab.name}`,
    );

    els.memberCount.textContent = isChannel
      ? `${count} member${count === 1 ? "" : "s"}`
      : "private";

    els.composerPrompt.textContent = `${isChannel ? tab.name : `@${tab.name}`} >`;
    els.composerInput.placeholder = online
      ? `Message ${tab.name}`
      : "Reconnect to send a message";
    els.composerInput.setAttribute("aria-label", `Message ${tab.name}`);
  }

  function renderMembers() {
    const tab = activeTab();
    if (!tab) return;

    const members = tab.type === "dm" ? [tab.name, state.nick] : tab.members;
    const sorted = [...members].sort((a, b) => {
      const rank = memberRank(a) - memberRank(b);
      if (rank !== 0) return rank;
      return stripPrefix(a).localeCompare(stripPrefix(b), undefined, {
        sensitivity: "base",
      });
    });

    els.memberList.textContent = "";

    if (sorted.length === 0) {
      const empty = document.createElement("p");
      empty.className = "member-empty";
      empty.textContent = "No members to show.";
      els.memberList.append(empty);
      els.membersSummary.textContent = "0";
      return;
    }

    for (const entry of sorted) {
      const prefixMatch = entry.match(/^[@&+~%]/);
      const prefix = prefixMatch ? prefixMatch[0] : "";
      const nick = stripPrefix(entry);
      const self = isSelf(nick);

      const row = document.createElement(self ? "div" : "button");
      row.className = [
        "member",
        prefix === "+" ? "voiced" : "",
        self ? "self" : "",
      ]
        .filter(Boolean)
        .join(" ");

      if (!self) {
        row.type = "button";
        row.title = `Open a private conversation with ${nick}`;
        row.addEventListener("click", () => openDm(nick));
      }

      const prefixSpan = document.createElement("span");
      prefixSpan.className = "prefix";
      prefixSpan.textContent = prefix || "\u00a0";

      const nameSpan = document.createElement("span");
      nameSpan.className = "member-name";
      nameSpan.textContent = nick;

      row.append(prefixSpan, nameSpan);

      if (self) {
        const you = document.createElement("span");
        you.className = "you";
        you.textContent = "you";
        row.append(you);
      }

      els.memberList.append(row);
    }

    els.membersSummary.textContent = String(sorted.length);
  }

  function updateTitle() {
    const tab = activeTab();
    const unread = state.tabs.reduce((total, item) => total + (item.unread || 0), 0);
    const activeName = tab
      ? tab.type === "channel"
        ? tab.name
        : `@${tab.name}`
      : "BrasIRC mock";

    document.title = `${unread ? `(${unread}) ` : ""}exirc — ${activeName}`;
  }

  function activateTab(id, { focus = "none" } = {}) {
    const tab = findTab(id);
    if (!tab) return;

    state.activeTabId = id;
    tab.unread = 0;
    tab.mentions = 0;
    state.completion = null;

    renderTabs();
    renderTopic();
    renderMembers();
    renderLog({ forceScroll: true });
    updateTitle();

    const focusComposer = focus === "composer" || (focus === "auto" && !isNarrow());

    if (focusComposer && !els.composerInput.disabled) {
      els.composerInput.focus({ preventScroll: true });
    } else if (focus === "tab") {
      const activeButton = els.tabs.querySelector('[aria-selected="true"]');
      if (activeButton) activeButton.focus({ preventScroll: true });
    }
  }

  function cycleTab(delta, focus = "composer") {
    if (state.tabs.length === 0) return;

    const currentIndex = state.tabs.findIndex((tab) => tab.id === state.activeTabId);
    const nextIndex = (currentIndex + delta + state.tabs.length) % state.tabs.length;
    const next = state.tabs[nextIndex];

    if (next) activateTab(next.id, { focus });
  }

  function openDm(rawNick) {
    const nick = stripPrefix(String(rawNick || "").trim());

    if (!nick) return;
    if (isSelf(nick)) {
      showToast("That is your own nickname.");
      return;
    }
    if (!NICK_PATTERN.test(nick)) {
      showToast("That does not look like an IRC nickname.");
      return;
    }

    const id = `dm:${lower(nick)}`;
    let tab = findTab(id);

    if (!tab) {
      tab = {
        id,
        type: "dm",
        name: nick,
        topic: `Private conversation with ${nick}.`,
        members: [nick, state.nick],
        unread: 0,
        mentions: 0,
      };
      state.tabs.push(tab);
      state.messages.set(id, []);
      seedMessage(id, { type: "system", text: `Private conversation with ${nick}.` });
    }

    if (isNarrow()) closeSidebar({ restoreFocus: false });
    activateTab(id, { focus: "auto" });
  }

  function setConnection(status) {
    state.connection = status;

    const online = status === "online";
    const reconnecting = status === "reconnecting";

    els.connectionPill.className = `status-pill status-${
      online ? "online" : reconnecting ? "reconnecting" : "offline"
    }`;
    els.connectionLabel.textContent = online
      ? "Connected"
      : reconnecting
        ? "Reconnecting…"
        : "Disconnected";

    els.connectionBanner.hidden = online;
    els.connectionBannerText.textContent = reconnecting
      ? "Reconnecting to irc.brasirc.com.br:6697…"
      : "Connection lost. The mock is offline until you reconnect.";
    els.bannerReconnect.hidden = reconnecting;

    els.composerInput.disabled = !online;
    els.sendButton.disabled = !online;
    els.joinButton.disabled = !online;

    renderTopic();
    updateDemoButtons();
  }

  function updateDemoButtons() {
    for (const button of demoButtons) {
      const action = button.dataset.demo;
      let disabled = false;

      if (action === "reconnect") {
        disabled = state.connection !== "offline";
      } else if (action === "disconnect") {
        disabled = state.connection !== "online";
      } else if (action === "clear") {
        disabled = false;
      } else {
        disabled = state.connection !== "online";
      }

      button.disabled = disabled;
    }
  }

  function showToast(message) {
    window.clearTimeout(toastTimer);
    els.toast.textContent = message;
    els.toast.hidden = false;
    toastTimer = window.setTimeout(() => {
      els.toast.hidden = true;
    }, 2200);
  }

  function showJoinError(message) {
    els.joinError.textContent = message;
    els.joinError.hidden = false;
  }

  function clearJoinError() {
    els.joinError.textContent = "";
    els.joinError.hidden = true;
  }

  function openDialog(dialog) {
    if (!dialog) return;
    if (typeof dialog.showModal === "function") {
      if (!dialog.open) dialog.showModal();
    } else {
      dialog.setAttribute("open", "");
    }
  }

  function closeDialog(dialog) {
    if (!dialog) return;
    if (typeof dialog.close === "function") {
      if (dialog.open) dialog.close();
    } else {
      dialog.removeAttribute("open");
    }
  }

  function openJoinDialog() {
    if (state.connection !== "online") {
      showToast("Reconnect before joining a channel.");
      return;
    }

    if (isNarrow()) closeSidebar({ restoreFocus: false });
    clearJoinError();
    els.joinInput.value = "";
    openDialog(els.joinDialog);
    window.setTimeout(() => els.joinInput.focus(), 0);
  }

  function joinChannel(rawName, { focus = "composer" } = {}) {
    if (state.connection !== "online") {
      showToast("Reconnect before joining a channel.");
      return false;
    }

    const name = normalizeChannel(rawName);

    if (!name || !CHANNEL_PATTERN.test(name)) {
      showToast("Use a channel name like #exirc.");
      return false;
    }

    const existing = state.tabs.find(
      (tab) => tab.type === "channel" && lower(tab.name) === lower(name),
    );

    if (existing) {
      activateTab(existing.id, { focus });
      showToast(`Already in ${existing.name}.`);
      return true;
    }

    const tab = {
      id: name,
      type: "channel",
      name,
      topic: "A new simulated channel.",
      members: [state.nick],
      unread: 0,
      mentions: 0,
    };

    state.tabs.push(tab);
    state.messages.set(tab.id, []);
    seedMessage(tab.id, { type: "system", text: `You joined ${name}.` });
    activateTab(tab.id, { focus });
    showToast(`Joined ${name} (simulated).`);
    return true;
  }

  function clearActiveTab() {
    const tab = activeTab();
    if (!tab) return;

    state.messages.set(tab.id, []);
    tab.unread = 0;
    tab.mentions = 0;
    renderLog({ forceScroll: true });
    renderTabs();
    updateTitle();
    showToast("Cleared this tab.");
  }

  function addSystemMessage(text) {
    const tab = activeTab();
    if (tab) pushMessage(tab.id, { type: "system", text }, { forceScroll: true });
  }

  function handleCommand(text) {
    const body = text.slice(1);
    const spaceIndex = body.search(/\s/);
    const command = (spaceIndex === -1 ? body : body.slice(0, spaceIndex)).toLowerCase();
    const args = spaceIndex === -1 ? "" : body.slice(spaceIndex + 1).trim();

    switch (command) {
      case "me": {
        if (!args) {
          addSystemMessage("Usage: /me action");
          return;
        }
        const tab = activeTab();
        if (tab) {
          pushMessage(
            tab.id,
            { type: "action", nick: state.nick, text: args },
            { forceScroll: true },
          );
        }
        return;
      }

      case "msg": {
        const match = args.match(/^(\S+)\s+([\s\S]+)$/);
        if (!match) {
          addSystemMessage("Usage: /msg nickname message");
          return;
        }

        const [, nick, message] = match;
        if (!NICK_PATTERN.test(nick)) {
          addSystemMessage("That does not look like an IRC nickname.");
          return;
        }

        openDm(nick);
        const dm = findTab(`dm:${lower(nick)}`);
        if (dm) {
          pushMessage(
            dm.id,
            { type: "message", nick: state.nick, text: message },
            { forceScroll: true },
          );
        }
        return;
      }

      case "join": {
        if (!args) {
          addSystemMessage("Usage: /join #channel");
          return;
        }
        if (!joinChannel(args, { focus: "composer" })) {
          addSystemMessage("Usage: /join #channel");
        }
        return;
      }

      case "clear":
        clearActiveTab();
        return;

      case "help":
        openDialog(els.shortcutsDialog);
        return;

      default:
        addSystemMessage(
          `Unknown command: /${command}. Try /me, /msg, /join, /clear, or /help.`,
        );
    }
  }

  function updateComposerCount() {
    els.composerCount.textContent = `${els.composerInput.value.length}/${MAX_MESSAGE_LENGTH}`;
  }

  function resizeComposer() {
    const input = els.composerInput;
    input.style.height = "auto";
    input.style.height = `${Math.min(input.scrollHeight, 120)}px`;
  }

  function resetComposer() {
    els.composerInput.value = "";
    els.composerInput.style.height = "";
    state.completion = null;
    updateComposerCount();
    els.composerInput.focus({ preventScroll: true });
  }

  function submitComposer() {
    if (state.connection !== "online") {
      showToast("Reconnect before sending a message.");
      return;
    }

    const text = els.composerInput.value.trim();
    if (!text) return;

    if (text.startsWith("/")) {
      handleCommand(text);
    } else {
      const tab = activeTab();
      if (tab) {
        pushMessage(
          tab.id,
          { type: "message", nick: state.nick, text },
          { forceScroll: true },
        );
      }
    }

    resetComposer();
  }

  function completableNicks() {
    const tab = activeTab();
    if (!tab) return [];

    const raw = tab.type === "dm" ? [tab.name] : tab.members.map(stripPrefix);
    const unique = new Map();

    for (const name of raw) {
      if (!name || isSelf(name)) continue;
      const key = lower(name);
      if (!unique.has(key)) unique.set(key, name);
    }

    return [...unique.values()];
  }

  function completeNick() {
    const input = els.composerInput;

    if (input.selectionStart !== input.selectionEnd) return false;

    const value = input.value;
    const cursor = input.selectionStart;
    const completion = state.completion;

    if (completion && cursor === completion.cursorEnd) {
      const nextIndex = (completion.index + 1) % completion.matches.length;
      const nextNick = completion.matches[nextIndex];
      const nextValue =
        value.slice(0, completion.start) +
        nextNick +
        completion.suffix +
        value.slice(completion.cursorEnd);
      const nextCursor = completion.start + nextNick.length + completion.suffix.length;

      input.value = nextValue;
      input.setSelectionRange(nextCursor, nextCursor);
      state.completion = {
        ...completion,
        index: nextIndex,
        cursorEnd: nextCursor,
      };
      updateComposerCount();
      return true;
    }

    const before = value.slice(0, cursor);
    const tokenMatch = before.match(/(\S*)$/);
    const token = tokenMatch ? tokenMatch[1] : "";

    if (!token || token.startsWith("/")) return false;

    const start = cursor - token.length;
    const matches = completableNicks()
      .filter((nick) => lower(nick).startsWith(lower(token)))
      .sort((a, b) => a.localeCompare(b, undefined, { sensitivity: "base" }));

    if (matches.length === 0) return false;

    const after = value.slice(cursor);
    const suffix = start === 0 ? ": " : /^[\s,:;]/.test(after) ? "" : " ";
    const nick = matches[0];
    const nextValue = value.slice(0, start) + nick + suffix + after;
    const nextCursor = start + nick.length + suffix.length;

    input.value = nextValue;
    input.setSelectionRange(nextCursor, nextCursor);
    state.completion = {
      start,
      cursorEnd: nextCursor,
      matches,
      index: 0,
      suffix,
    };
    updateComposerCount();
    return true;
  }

  function openSidebar() {
    state.sidebarReturnFocus = document.activeElement;
    document.body.classList.add("sidebar-open");
    els.sidebarOverlay.hidden = false;
    els.demoToggle.setAttribute("aria-expanded", "true");
    els.membersButton.setAttribute("aria-expanded", "true");
    window.setTimeout(() => els.sidebarClose.focus(), 0);
  }

  function closeSidebar({ restoreFocus = true } = {}) {
    document.body.classList.remove("sidebar-open");
    els.sidebarOverlay.hidden = true;
    els.demoToggle.setAttribute("aria-expanded", "false");
    els.membersButton.setAttribute("aria-expanded", "false");

    if (
      restoreFocus &&
      state.sidebarReturnFocus &&
      document.contains(state.sidebarReturnFocus)
    ) {
      state.sidebarReturnFocus.focus();
    }
    state.sidebarReturnFocus = null;
  }

  function pick(values) {
    return values[Math.floor(Math.random() * values.length)];
  }

  function firstChannel() {
    return state.tabs.find((tab) => tab.type === "channel");
  }

  function demoChannel() {
    const tab = activeTab();
    return tab && tab.type === "channel" ? tab : firstChannel();
  }

  function channelNicks(tab) {
    return tab.members.map(stripPrefix).filter((nick) => !isSelf(nick));
  }

  function nextDemoNick(excluded = []) {
    const blocked = new Set(excluded.map(lower));
    blocked.add(lower(state.nick));

    const available = DEMO.nicks.filter((nick) => !blocked.has(lower(nick)));
    return available.length > 0 ? pick(available) : `guest_${++state.guestSeq}`;
  }

  function ensureOnline(verb) {
    if (state.connection === "online") return true;
    showToast(`Reconnect before you ${verb}.`);
    return false;
  }

  function simulateMessage(mention = false) {
    if (!ensureOnline(mention ? "send a mention" : "simulate a message")) return;

    const tab = activeTab();
    if (!tab) return;

    let nick;

    if (tab.type === "dm") {
      nick = tab.name;
    } else {
      let candidates = channelNicks(tab);

      if (candidates.length === 0) {
        nick = nextDemoNick([...tab.members, state.nick]);
        tab.members.push(nick);
        pushMessage(tab.id, {
          type: "system",
          text: `${nick} joined ${tab.name}.`,
        });
        renderMembers();
        renderTopic();
      } else {
        nick = pick(candidates);
      }
    }

    const template = mention ? pick(DEMO.mentions) : pick(DEMO.messages);
    const text = template.replace(/\{nick\}/g, state.nick);

    pushMessage(
      tab.id,
      { type: "message", nick, text, mention },
      { forceScroll: true },
    );

    showToast(mention ? "Mention simulated." : "Message simulated.");
  }

  function simulateJoin() {
    if (!ensureOnline("simulate a join")) return;

    const tab = demoChannel();
    if (!tab) {
      showToast("No channel is open.");
      return;
    }

    const existing = tab.members.map(stripPrefix);
    const nick = nextDemoNick(existing);
    tab.members.push(nick);

    pushMessage(tab.id, {
      type: "system",
      text: `${nick} joined ${tab.name}.`,
    });

    if (tab.id === state.activeTabId) {
      renderMembers();
      renderTopic();
    }

    showToast(`${nick} joined ${tab.name}.`);
  }

  function simulatePart() {
    if (!ensureOnline("simulate a part")) return;

    const tab = demoChannel();
    if (!tab) {
      showToast("No channel is open.");
      return;
    }

    const candidates = channelNicks(tab);
    if (candidates.length === 0) {
      showToast("There is nobody else to remove from this channel.");
      return;
    }

    const nick = pick(candidates);
    tab.members = tab.members.filter((entry) => lower(stripPrefix(entry)) !== lower(nick));

    pushMessage(tab.id, {
      type: "system",
      text: `${nick} left ${tab.name} (demo).`,
    });

    if (tab.id === state.activeTabId) {
      renderMembers();
      renderTopic();
    }

    showToast(`${nick} left ${tab.name}.`);
  }

  function simulateDm() {
    if (!ensureOnline("open a demo DM")) return;

    const channel = demoChannel();
    const candidates = channel ? channelNicks(channel) : [];
    const excluded = new Set([lower(state.nick)]);
    const tab = activeTab();

    if (tab && tab.type === "dm") excluded.add(lower(tab.name));

    const available = [...new Set([...candidates, ...DEMO.dmNicks, ...DEMO.nicks])].filter(
      (nick) => !excluded.has(lower(nick)),
    );

    const nick = available.length > 0 ? pick(available) : `guest_${++state.guestSeq}`;
    openDm(nick);

    const dm = findTab(`dm:${lower(nick)}`);
    if (dm) {
      pushMessage(
        dm.id,
        { type: "message", nick, text: pick(DEMO.dmMessages) },
        { forceScroll: true },
      );
    }

    showToast(`DM with ${nick} (simulated).`);
  }

  function simulateDisconnect() {
    if (state.connection === "offline") {
      showToast("The mock is already offline.");
      return;
    }

    if (state.reconnectTimer) {
      window.clearTimeout(state.reconnectTimer);
      state.reconnectTimer = null;
    }

    setConnection("offline");
    addSystemMessage(
      "Connection to irc.brasirc.com.br:6697 lost. This is still a local mock.",
    );
    showToast("Disconnected (simulated).");
  }

  function simulateReconnect() {
    if (state.connection === "online") {
      showToast("Already connected.");
      return;
    }
    if (state.connection === "reconnecting") return;

    setConnection("reconnecting");
    addSystemMessage("Reconnecting to irc.brasirc.com.br:6697…");

    state.reconnectTimer = window.setTimeout(() => {
      state.reconnectTimer = null;
      setConnection("online");
      addSystemMessage(`Connected to BrasIRC as ${state.nick}.`);
      showToast("Reconnected (simulated).");
    }, 900);
  }

  function handleDemo(action) {
    switch (action) {
      case "message":
        simulateMessage(false);
        break;
      case "mention":
        simulateMessage(true);
        break;
      case "join":
        simulateJoin();
        break;
      case "part":
        simulatePart();
        break;
      case "dm":
        simulateDm();
        break;
      case "clear":
        clearActiveTab();
        break;
      case "disconnect":
        simulateDisconnect();
        break;
      case "reconnect":
        simulateReconnect();
        break;
      default:
        return;
    }

    if (isNarrow()) closeSidebar({ restoreFocus: false });
  }

  function seedState() {
    state.nick = safeNick(readStorage(STORAGE.nick));
    const channelName = initialChannelName();
    const firstDmNick = lower(state.nick) === "ana" ? "bruno" : "ana";

    const baseMembers = ["@ana", "+bruno", "carla", "diego", "elisa", "felipe", "gabi"];
    const members = baseMembers.filter(
      (entry) => lower(stripPrefix(entry)) !== lower(state.nick),
    );
    members.push(state.nick);

    const channel = {
      id: channelName,
      type: "channel",
      name: channelName,
      topic: "A small, fictional corner of BrasIRC for interface testing.",
      members,
      unread: 0,
      mentions: 0,
    };

    const dm = {
      id: `dm:${lower(firstDmNick)}`,
      type: "dm",
      name: firstDmNick,
      topic: `Private conversation with ${firstDmNick}.`,
      members: [firstDmNick, state.nick],
      unread: 1,
      mentions: 0,
    };

    state.tabs.push(channel, dm);
    state.messages.set(channel.id, []);
    state.messages.set(dm.id, []);
    state.activeTabId = channel.id;

    seedMessage(channel.id, {
      type: "system",
      text: `Connected to ${state.server}:${state.port} as ${state.nick} (simulated, no socket).`,
      time: minutesAgo(9),
    });
    seedMessage(channel.id, {
      type: "system",
      text: `You joined ${channel.name}.`,
      time: minutesAgo(8),
    });
    seedMessage(channel.id, {
      type: "notice",
      nick: "server",
      text: `Topic for ${channel.name}: ${channel.topic}`,
      time: minutesAgo(7),
    });
    seedMessage(channel.id, {
      type: "message",
      nick: "ana",
      text: "morning. this is the clickable mock, not a real connection.",
      time: minutesAgo(6),
    });
    seedMessage(channel.id, {
      type: "message",
      nick: "bruno",
      text: "top tabs only. no sidebar channel list.",
      time: minutesAgo(5),
    });
    seedMessage(channel.id, {
      type: "message",
      nick: "carla",
      text: `${state.nick}: the member list is on the right. click a nick to open a DM.`,
      mention: true,
      time: minutesAgo(4),
    });
    seedMessage(channel.id, {
      type: "action",
      nick: "diego",
      text: "is already poking at the demo panel.",
      time: minutesAgo(3),
    });

    seedMessage(dm.id, {
      type: "message",
      nick: firstDmNick,
      text: "hey — private tabs work the same way as channels.",
      time: minutesAgo(12),
    });
    seedMessage(dm.id, {
      type: "message",
      nick: firstDmNick,
      text: "click any nick in the member list to start one.",
      time: minutesAgo(11),
    });
  }

  function bindEvents() {
    els.composerInput.addEventListener("input", () => {
      state.completion = null;
      updateComposerCount();
      resizeComposer();
    });

    els.composerInput.addEventListener("keydown", (event) => {
      if (event.isComposing) return;

      if (event.key !== "Tab") state.completion = null;

      if (
        event.key === "Enter" &&
        !event.shiftKey &&
        !event.altKey &&
        !event.ctrlKey &&
        !event.metaKey
      ) {
        event.preventDefault();
        submitComposer();
        return;
      }

      if (
        event.key === "Tab" &&
        !event.shiftKey &&
        !event.altKey &&
        !event.ctrlKey &&
        !event.metaKey
      ) {
        if (completeNick()) event.preventDefault();
      }
    });

    els.sendButton.addEventListener("click", submitComposer);
    els.bannerReconnect.addEventListener("click", simulateReconnect);
    els.joinButton.addEventListener("click", openJoinDialog);
    els.shortcutsButton.addEventListener("click", () => openDialog(els.shortcutsDialog));

    els.tabs.addEventListener("keydown", (event) => {
      if (event.altKey || event.ctrlKey || event.metaKey) return;
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        event.preventDefault();
        cycleTab(event.key === "ArrowRight" ? 1 : -1, "tab");
      }
    });

    els.messageLog.addEventListener("scroll", updateJumpButton);

    els.jumpLatest.addEventListener("click", () => {
      els.messageLog.scrollTop = els.messageLog.scrollHeight;
      updateJumpButton();
    });

    els.joinForm.addEventListener("submit", (event) => {
      event.preventDefault();
      clearJoinError();

      if (state.connection !== "online") {
        showJoinError("Reconnect before joining a channel.");
        return;
      }

      const name = normalizeChannel(els.joinInput.value);
      if (!name) {
        showJoinError("Enter a channel name.");
        els.joinInput.focus();
        return;
      }
      if (!CHANNEL_PATTERN.test(name)) {
        showJoinError("Use a channel name like #exirc.");
        els.joinInput.focus();
        return;
      }

      if (joinChannel(name, { focus: "composer" })) {
        closeDialog(els.joinDialog);
      }
    });

    els.joinInput.addEventListener("input", clearJoinError);

    document.querySelectorAll("[data-close-dialog]").forEach((button) => {
      button.addEventListener("click", () => {
        closeDialog(document.getElementById(button.dataset.closeDialog));
      });
    });

    [els.joinDialog, els.shortcutsDialog].forEach((dialog) => {
      dialog.addEventListener("click", (event) => {
        if (event.target === dialog) closeDialog(dialog);
      });
    });

    els.demoToggle.addEventListener("click", openSidebar);
    els.membersButton.addEventListener("click", openSidebar);
    els.sidebarClose.addEventListener("click", () => closeSidebar());
    els.sidebarOverlay.addEventListener("click", () => closeSidebar());

    demoButtons = [...document.querySelectorAll("[data-demo]")];
    demoButtons.forEach((button) => {
      button.addEventListener("click", () => handleDemo(button.dataset.demo));
    });

    document.addEventListener("keydown", (event) => {
      if (event.defaultPrevented) return;
      if (document.querySelector("dialog[open]")) return;

      if (event.key === "Escape") {
        if (document.body.classList.contains("sidebar-open")) {
          event.preventDefault();
          closeSidebar();
        }
        return;
      }

      if (!event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;

      if (/^[1-9]$/.test(event.key)) {
        const index = Number(event.key) - 1;
        const tab = state.tabs[index];
        if (tab) {
          event.preventDefault();
          activateTab(tab.id, { focus: "composer" });
        }
        return;
      }

      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        event.preventDefault();
        cycleTab(event.key === "ArrowRight" ? 1 : -1, "composer");
      }
    });

    window.addEventListener("resize", () => {
      if (!isNarrow() && document.body.classList.contains("sidebar-open")) {
        closeSidebar({ restoreFocus: false });
      }
    });
  }

  function init() {
    seedState();
    bindEvents();
    updateComposerCount();
    setConnection("online");
    renderTabs();
    renderMembers();
    renderLog({ forceScroll: true });
    updateTitle();
  }

  init();
})();

(() => {
  "use strict";

  const STORAGE = {
    nick: "exirc:mock:nick",
    channel: "exirc:mock:channel",
    session: "exirc:mock:session",
  };

  const NICK_PATTERN = /^[A-Za-z0-9_\-\[\]\\`^{}|]{1,30}$/;
  const CHANNEL_PATTERN = /^[#&][A-Za-z0-9_\-\[\]\\`^{}|]{1,63}$/;

  const form = document.getElementById("connect-form");
  const nickInput = document.getElementById("nickname");
  const channelInput = document.getElementById("channel");
  const serverPassword = document.getElementById("server-password");
  const nickservPassword = document.getElementById("nickserv-password");
  const formError = document.getElementById("form-error");
  const demoButton = document.getElementById("demo-connect");

  function readStorage(key) {
    try {
      return sessionStorage.getItem(key) || "";
    } catch {
      return "";
    }
  }

  function writeStorage(key, value) {
    try {
      sessionStorage.setItem(key, value);
    } catch {
      // The mock still works when storage is unavailable.
    }
  }

  function showError(message) {
    formError.textContent = message;
    formError.hidden = false;
  }

  function clearError() {
    formError.textContent = "";
    formError.hidden = true;
  }

  function normalizeChannel(value) {
    const trimmed = value.trim();
    if (!trimmed) return "";
    return /^[#&]/.test(trimmed) ? trimmed : `#${trimmed}`;
  }

  function connect() {
    clearError();

    const nick = nickInput.value.trim();
    const channel = normalizeChannel(channelInput.value);

    if (!nick) {
      showError("Choose a nickname before connecting.");
      nickInput.focus();
      return;
    }

    if (!NICK_PATTERN.test(nick)) {
      showError(
        "Use 1–30 letters, numbers, or IRC nickname symbols. Spaces are not allowed.",
      );
      nickInput.focus();
      return;
    }

    if (channel && !CHANNEL_PATTERN.test(channel)) {
      showError(
        "Channel names must start with # and cannot contain spaces or punctuation.",
      );
      channelInput.focus();
      return;
    }

    writeStorage(STORAGE.nick, nick);
    writeStorage(STORAGE.channel, channel || "#brasirc");
    writeStorage(STORAGE.session, "connected");

    // The mock never stores or sends these fields.
    if (serverPassword) serverPassword.value = "";
    if (nickservPassword) nickservPassword.value = "";

    window.location.href = "app.html";
  }

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    connect();
  });

  form.addEventListener("input", (event) => {
    if (event.target !== formError) clearError();
  });

  demoButton.addEventListener("click", () => {
    nickInput.value = "otter";
    channelInput.value = "#brasirc";
    connect();
  });

  const storedNick = readStorage(STORAGE.nick);
  const storedChannel = readStorage(STORAGE.channel);

  if (storedNick) nickInput.value = storedNick;
  if (storedChannel) channelInput.value = storedChannel;
})();

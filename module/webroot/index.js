import { exec, toast } from './assets/kernelsu.js';

const MODULE_DIR = '/data/adb/modules/HyperUnlocked';
const SHELL_PATH = '/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH';
const DEFAULT_DEVICE_LEVEL_LIST_FILE = '/data/adb/HyperUnlocked/default_deviceLevelList.txt';
const DEVICE_LEVEL_REGEX = /v:\d+,c:\d+,g:\d+/g;

const COMMAND_WARNINGS = [
    {
        pattern: /^sh\s+webui\.sh\s+set\s+leica\s+true$/,
        title: 'Warning',
        description: 'LEICA Camera Spoof only works if your camera is the latest version.\nThis feature has only been tested on Xiaomi 17 Series and WILL clear camera app data.\nContinue?',
    },
];

const state = {
    status: {},
    defaultDeviceLevels: new Set(),
    warningResolver: null,
};

function getTerminalElement() {
    return document.getElementById('terminalOutput');
}

function appendTerminalLine(text, type = '') {
    const terminal = getTerminalElement();
    if (!terminal) return;

    const line = document.createElement('div');
    line.className = `terminal-line ${type}`.trim();
    line.textContent = text;
    terminal.appendChild(line);
    terminal.scrollTop = terminal.scrollHeight;
}

function appendChunk(chunk, type = '') {
    const normalized = String(chunk || '').replace(/\r/g, '');
    if (!normalized) return;

    normalized.split('\n').forEach((line) => {
        if (line !== '') appendTerminalLine(line, type);
    });
}

function buildCommand(command) {
    return `if [ -d "${MODULE_DIR}" ]; then cd "${MODULE_DIR}"; fi; ${command}`;
}

function normalizeCommand(command) {
    return String(command || '').trim().replace(/\s+/g, ' ');
}

async function runShellCommand(command, { silent = false } = {}) {
    if (!command || typeof command !== 'string') {
        if (!silent) appendTerminalLine('[js] Invalid command', 'error');
        return { errno: 1, stdout: '', stderr: 'Invalid command' };
    }

    if (!silent) appendTerminalLine(`$ ${command}`, 'command');

    try {
        const { errno, stdout, stderr } = await exec(buildCommand(command), {
            env: { PATH: SHELL_PATH },
        });

        if (!silent) {
            appendChunk(stdout);
            appendChunk(stderr, 'error');
            if (errno !== 0) {
                appendTerminalLine(`[exit ${errno}]`, 'error');
            }
        }

        if (errno !== 0) toast(`Command exited with ${errno}`);
        return { errno, stdout, stderr };
    } catch (error) {
        const message = error?.message || String(error);
        if (!silent) appendTerminalLine(`[js] ${message}`, 'error');
        toast('Unexpected JS error');
        return { errno: 1, stdout: '', stderr: message };
    }
}

function clearTerminal() {
    const terminal = getTerminalElement();
    if (terminal) terminal.textContent = '';
}

function parseStatus(stdout = '') {
    const parsed = {};

    String(stdout)
        .replace(/\r/g, '')
        .split('\n')
        .forEach((line) => {
            const idx = line.indexOf('=');
            if (idx <= 0) return;
            const key = line.slice(0, idx).trim();
            const value = line.slice(idx + 1).trim();
            if (key) parsed[key] = value;
        });

    return parsed;
}

function isTrue(value) {
    return String(value).toLowerCase() === 'true';
}

function getEffectiveStatusValue(status, key) {
    const pendingKey = `pending.${key}`;
    if (Object.prototype.hasOwnProperty.call(status, pendingKey)) return status[pendingKey];
    return status[`current.${key}`];
}

function updateSubtitleFromStatus(status) {
    const subtitle = document.getElementById('headerSubtitle');
    if (!subtitle) return;

    const version = status.version;
    const versionCode = status.versionCode;

    if (version && versionCode) subtitle.textContent = `${version} (${versionCode})`;
    else if (version) subtitle.textContent = version;
    else subtitle.textContent = 'Version unavailable';
}

function setPendingWarningVisible(visible) {
    const warning = document.getElementById('pendingWarning');
    if (!warning) return;
    warning.classList.toggle('hidden', !visible);
}

function updateDeviceLevelOptionLabels(defaultLevels) {
    const select = document.getElementById('deviceLevelSelect');
    if (!select) return;

    Array.from(select.options).forEach((option) => {
        const baseLabel = option.dataset.baseLabel || option.textContent.replace(/ \(Default\)$/, '');
        option.dataset.baseLabel = baseLabel;
        option.textContent = defaultLevels.has(option.value) ? `${baseLabel} (Default)` : baseLabel;
    });
}

function resolveDeviceLevelValue(status, defaultLevels) {
    let value = getEffectiveStatusValue(status, 'device_level') || status['current.device_level'] || '';

    if (value === 'default') {
        const firstDefault = Array.from(defaultLevels)[0];
        value = firstDefault || status['current.device_level'] || '';
    }

    return value;
}

function syncControlsFromStatus(status) {
    const blurToggle = document.getElementById('blurToggle');
    const screenshotBlurToggle = document.getElementById('screenshotBlurToggle');
    const leicaToggle = document.getElementById('leicaToggle');
    const deviceLevelSelect = document.getElementById('deviceLevelSelect');

    if (blurToggle) blurToggle.checked = isTrue(getEffectiveStatusValue(status, 'blur'));
    if (screenshotBlurToggle) screenshotBlurToggle.checked = isTrue(getEffectiveStatusValue(status, 'screenshot_blur'));
    if (leicaToggle) leicaToggle.checked = isTrue(getEffectiveStatusValue(status, 'leica'));

    if (deviceLevelSelect) {
        const wanted = resolveDeviceLevelValue(status, state.defaultDeviceLevels);
        const exists = Array.from(deviceLevelSelect.options).some((opt) => opt.value === wanted);
        if (exists) deviceLevelSelect.value = wanted;
    }
}

function parseDeviceLevelList(text = '') {
    const matches = String(text).match(DEVICE_LEVEL_REGEX) || [];
    return new Set(matches);
}

async function loadDefaultDeviceLevels() {
    const result = await runShellCommand(`cat ${DEFAULT_DEVICE_LEVEL_LIST_FILE} 2>/dev/null || true`, { silent: true });
    return parseDeviceLevelList(result.stdout);
}

async function refreshStatus({ silent = true } = {}) {
    state.defaultDeviceLevels = await loadDefaultDeviceLevels();
    updateDeviceLevelOptionLabels(state.defaultDeviceLevels);

    const result = await runShellCommand('sh webui.sh status', { silent });
    if (!result || typeof result.stdout !== 'string') return result;

    state.status = parseStatus(result.stdout);
    updateSubtitleFromStatus(state.status);
    setPendingWarningVisible(isTrue(state.status['pending.config']));
    syncControlsFromStatus(state.status);
    return result;
}

function shouldAutoRefreshStatus(command) {
    return /^sh\s+webui\.sh\s+(set|apply|clear)\b/.test(normalizeCommand(command));
}

function isStatusCommand(command) {
    return /^sh\s+webui\.sh\s+status\b/.test(normalizeCommand(command));
}

function getCommandWarning(command) {
    const normalized = normalizeCommand(command);
    return COMMAND_WARNINGS.find((rule) => rule.pattern.test(normalized));
}

function ensureWarningModalClosed() {
    const modal = document.getElementById('warningModal');
    if (modal) modal.classList.add('hidden');
}

function closeWarningModal(confirmed) {
    ensureWarningModalClosed();

    const resolver = state.warningResolver;
    state.warningResolver = null;
    if (resolver) resolver(Boolean(confirmed));
}

function showWarningModal({ title, description }) {
    const modal = document.getElementById('warningModal');
    const modalTitle = document.getElementById('warningModalTitle');
    const modalDescription = document.getElementById('warningModalDescription');

    if (!modal || !modalTitle || !modalDescription) {
        return Promise.resolve(window.confirm(`${title}\n\n${description}`));
    }

    if (state.warningResolver) {
        state.warningResolver(false);
        state.warningResolver = null;
    }

    modalTitle.textContent = title;
    modalDescription.textContent = description;
    modal.classList.remove('hidden');

    return new Promise((resolve) => {
        state.warningResolver = resolve;
    });
}

function setupWarningModalInteractions() {
    const modal = document.getElementById('warningModal');
    if (!modal) return;

    modal.addEventListener('click', (event) => {
        if (event.target === modal) closeWarningModal(false);
    });
}

async function executeShell(command, options = {}) {
    const { source = null } = options || {};
    const warning = getCommandWarning(command);

    if (warning) {
        const confirmed = await showWarningModal(warning);
        if (!confirmed) {
            if (source && source.type === 'checkbox') source.checked = !source.checked;
            return { errno: 130, stdout: '', stderr: 'Cancelled by user' };
        }
    }

    const result = await runShellCommand(command, { silent: false });

    if (isStatusCommand(command) && typeof result.stdout === 'string') {
        state.status = parseStatus(result.stdout);
        updateSubtitleFromStatus(state.status);
        setPendingWarningVisible(isTrue(state.status['pending.config']));
        syncControlsFromStatus(state.status);
        return result;
    }

    if (shouldAutoRefreshStatus(command)) {
        await refreshStatus({ silent: true });
    }

    return result;
}

async function initWebUI() {
    appendTerminalLine('[-] HyperUnlocked WebUI ready.');
    appendTerminalLine(`[-] Working directory: ${MODULE_DIR}`);

    setupWarningModalInteractions();
    await refreshStatus({ silent: false });
}

window.executeShell = executeShell;
window.clearTerminal = clearTerminal;
window.initWebUI = initWebUI;
window.closeWarningModal = closeWarningModal;

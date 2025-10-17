Option Explicit

Const ELECTRON_VERSION = "28.2.0"
Const ELECTRON_ZIP_NAME = "electron-" & ELECTRON_VERSION & "-win32-x64.zip"
Const ELECTRON_URL = "https://github.com/electron/electron/releases/download/v" & ELECTRON_VERSION & "/electron-v" & ELECTRON_VERSION & "-win32-x64.zip"

Dim shell, fso
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

Call Main()

Sub Main()
    On Error GoTo 0

    Dim localAppData
    localAppData = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
    If localAppData = "%LOCALAPPDATA%" Then
        Fail "Unable to resolve LocalAppData folder."
    End If

    Dim installRoot, installApp, desktopPath
    installRoot = localAppData & "\Omnichat"
    installApp = installRoot & "\resources\app"
    desktopPath = shell.SpecialFolders("Desktop")

    shell.Popup "Installing Omnichat. Please wait...", 2, "Omnichat Setup", 64

    StopRunningInstances

    If fso.FolderExists(installRoot) Then
        On Error Resume Next
        fso.DeleteFolder installRoot, True
        If Err.Number <> 0 Then
            Err.Clear
            WScript.Sleep 500
            fso.DeleteFolder installRoot, True
        End If
        On Error GoTo 0
    End If
    CreateFolderRecursive installRoot

    InstallElectron installRoot

    Dim defaultAsar
    defaultAsar = installRoot & "\resources\default_app.asar"
    If fso.FileExists(defaultAsar) Then
        On Error Resume Next
        fso.DeleteFile defaultAsar, True
        On Error GoTo 0
    End If

    If fso.FolderExists(installApp) Then
        On Error Resume Next
        fso.DeleteFolder installApp, True
        On Error GoTo 0
    End If
    CreateFolderRecursive installApp

    WriteAppFiles installApp

    CreateShortcut desktopPath & "\Omnichat.lnk", installRoot & "\Omnichat.exe", installRoot

    LaunchApp installRoot & "\Omnichat.exe"

    shell.Popup "Omnichat is ready to use!", 5, "Omnichat Setup", 64
End Sub

Sub StopRunningInstances()
    On Error Resume Next
    shell.Run "taskkill /IM Omnichat.exe /F", 0, True
    On Error GoTo 0
End Sub

Sub InstallElectron(installRoot)
    Dim tempPath, electronZip, extractFolder
    tempPath = shell.ExpandEnvironmentStrings("%TEMP%")
    electronZip = tempPath & "\" & ELECTRON_ZIP_NAME
    extractFolder = tempPath & "\omnichat-electron"

    If fso.FileExists(electronZip) Then fso.DeleteFile electronZip, True
    If fso.FolderExists(extractFolder) Then fso.DeleteFolder extractFolder, True
    CreateFolderRecursive extractFolder

    DownloadFile ELECTRON_URL, electronZip
    ExtractZip electronZip, extractFolder

    Dim extractedRoot
    extractedRoot = extractFolder & "\electron-v" & ELECTRON_VERSION & "-win32-x64"
    If Not fso.FolderExists(extractedRoot) Then
        extractedRoot = extractFolder
    End If

    CopyFolderContents extractedRoot, installRoot

    On Error Resume Next
    If fso.FileExists(installRoot & "\electron.exe") Then
        fso.MoveFile installRoot & "\electron.exe", installRoot & "\Omnichat.exe"
    End If
    On Error GoTo 0

    If fso.FileExists(electronZip) Then fso.DeleteFile electronZip, True
    If fso.FolderExists(extractFolder) Then fso.DeleteFolder extractFolder, True
End Sub

Sub DownloadFile(url, destination)
    Dim xhr
    Set xhr = CreateObject("MSXML2.XMLHTTP")
    xhr.Open "GET", url, False
    xhr.send
    If xhr.Status <> 200 Then
        Fail "Failed to download Electron runtime. Status: " & xhr.Status
    End If

    Dim stream
    Set stream = CreateObject("ADODB.Stream")
    stream.Type = 1
    stream.Open
    stream.Write xhr.responseBody
    stream.SaveToFile destination, 2
    stream.Close
End Sub

Sub ExtractZip(zipPath, destination)
    Dim shellApp
    Set shellApp = CreateObject("Shell.Application")
    shellApp.NameSpace(destination).CopyHere shellApp.NameSpace(zipPath).Items, 16

    Dim expected
    expected = shellApp.NameSpace(zipPath).Items.Count
    Do While shellApp.NameSpace(destination).Items.Count < expected
        WScript.Sleep 500
    Loop
    WScript.Sleep 500
End Sub

Sub CopyFolderContents(sourceFolder, destinationFolder)
    CreateFolderRecursive destinationFolder

    On Error Resume Next
    fso.CopyFolder sourceFolder & "\*", destinationFolder, True
    If Err.Number <> 0 Then
        Err.Clear
        Dim shellApp
        Set shellApp = CreateObject("Shell.Application")
        shellApp.NameSpace(destinationFolder).CopyHere shellApp.NameSpace(sourceFolder).Items, 16
        WScript.Sleep 1000
    End If
    On Error GoTo 0
End Sub

Sub CreateShortcut(shortcutPath, targetPath, workingDir)
    Dim wsh
    Set wsh = CreateObject("WScript.Shell")
    Dim shortcut
    Set shortcut = wsh.CreateShortcut(shortcutPath)
    shortcut.TargetPath = targetPath
    shortcut.WorkingDirectory = workingDir
    shortcut.WindowStyle = 1
    shortcut.IconLocation = targetPath
    shortcut.Save
End Sub

Sub LaunchApp(executablePath)
    If fso.FileExists(executablePath) Then
        shell.Run """" & executablePath & """", 0, False
    End If
End Sub

Sub CreateFolderRecursive(path)
    If path = "" Then Exit Sub
    If fso.FolderExists(path) Then Exit Sub
    Dim parent
    parent = fso.GetParentFolderName(path)
    If parent <> "" And Not fso.FolderExists(parent) Then
        CreateFolderRecursive parent
    End If
    fso.CreateFolder path
End Sub

Sub WriteText(path, content)
    Dim parent
    parent = fso.GetParentFolderName(path)
    If parent <> "" Then CreateFolderRecursive parent
    Dim file
    Set file = fso.OpenTextFile(path, 2, True)
    file.Write content
    file.Close
End Sub

Sub WriteAppFiles(installApp)
    WriteText installApp & "\package.json", _
        Join(Array( _
        "{", _
        "  ""name"": ""omnichat"",", _
        "  ""version"": ""0.1.0"",", _
        "  ""description"": ""Omnichat desktop orchestration app for AI assistants."",", _
        "  ""main"": ""src/main/main.js"",", _
        "  ""author"": """",", _
        "  ""license"": ""MIT"",", _
        "  ""scripts"": {", _
        "    ""start"": ""electron ."",", _
        "    ""package"": ""electron-builder --win portable""", _
        "  },", _
        "  ""dependencies"": {},", _
        "  ""devDependencies"": {", _
        "    ""electron"": ""^28.2.0"",", _
        "    ""electron-builder"": ""^24.6.0""", _
        "  }", _
        "}" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\resources\FIRST_RUN.txt", _
        Join(Array( _
        "Welcome to Omnichat!", _
        "", _
        "1. Double-click OmnichatSetup to install everything automatically.", _
        "2. Open Omnichat from your new desktop shortcut.", _
        "3. Sign in to each assistant tab (ChatGPT, Claude, Copilot, Gemini).", _
        "4. Use Broadcast to send a message to the selected assistants.", _
        "5. Start a Round-table session to orchestrate K conversational turns." _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\resources\selectors.json", _
        Join(Array( _
        "{", _
        "  ""chatgpt"": {", _
        "    ""input"": [", _
        "      ""textarea"",", _
        "      ""textarea[data-testid='chat-input']"",", _
        "      ""div[contenteditable='true']""", _
        "    ],", _
        "    ""sendButton"": [", _
        "      ""button[data-testid='send-button']"",", _
        "      ""button[aria-label='Send']""", _
        "    ],", _
        "    ""messageContainer"": [", _
        "      ""main"",", _
        "      ""div[class*='conversation']""", _
        "    ]", _
        "  },", _
        "  ""claude"": {", _
        "    ""input"": [", _
        "      ""textarea"",", _
        "      ""textarea[placeholder*='Message']"",", _
        "      ""div[contenteditable='true']""", _
        "    ],", _
        "    ""sendButton"": [", _
        "      ""button[type='submit']"",", _
        "      ""button[aria-label='Send']""", _
        "    ],", _
        "    ""messageContainer"": [", _
        "      ""main"",", _
        "      ""div[class*='conversation']""", _
        "    ]", _
        "  },", _
        "  ""copilot"": {", _
        "    ""input"": [", _
        "      ""textarea#userInput"",", _
        "      ""textarea"",", _
        "      ""div[contenteditable='true']"",", _
        "      ""textarea[placeholder*='Ask me']""", _
        "    ],", _
        "    ""sendButton"": [", _
        "      ""button[aria-label='Send']"",", _
        "      ""button[data-testid='send-button']""", _
        "    ],", _
        "    ""messageContainer"": [", _
        "      ""main"",", _
        "      ""div[class*='conversation']""", _
        "    ]", _
        "  },", _
        "  ""gemini"": {", _
        "    ""input"": [", _
        "      ""textarea"",", _
        "      ""div[contenteditable='true']"",", _
        "      ""textarea[aria-label*='Message']""", _
        "    ],", _
        "    ""sendButton"": [", _
        "      ""button[aria-label='Send']"",", _
        "      ""button[type='submit']""", _
        "    ],", _
        "    ""messageContainer"": [", _
        "      ""main"",", _
        "      ""div[class*='conversation']""", _
        "    ]", _
        "  }", _
        "}" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\main\log-store.js", _
        Join(Array( _
        "const { app } = require('electron');", _
        "const fs = require('fs');", _
        "const path = require('path');", _
        "", _
        "class LogStore {", _
        "  constructor() {", _
        "    this.entries = [];", _
        "  }", _
        "", _
        "  append(entry) {", _
        "    const enriched = {", _
        "      timestamp: new Date().toISOString(),", _
        "      ...entry", _
        "    };", _
        "    this.entries.push(enriched);", _
        "  }", _
        "", _
        "  getEntries() {", _
        "    return this.entries.slice(-500);", _
        "  }", _
        "", _
        "  serialize() {", _
        "    return this.entries", _
        "      .map((entry) => `${entry.timestamp}\t${entry.type.toUpperCase()}\t${entry.message}`)", _
        "      .join('\n');", _
        "  }", _
        "", _
        "  exportToFile(filename = 'Omnichat-log.txt') {", _
        "    const exportPath = path.join(app.getPath('documents'), filename);", _
        "    fs.writeFileSync(exportPath, this.serialize(), 'utf8');", _
        "    return exportPath;", _
        "  }", _
        "}", _
        "", _
        "module.exports = { LogStore };" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\main\main.js", _
        Join(Array( _
        "const path = require('path');", _
        "const fs = require('fs');", _
        "const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');", _
        "const { SettingsStore } = require('./settings-store');", _
        "const { AgentManager } = require('./manager');", _
        "const { LogStore } = require('./log-store');", _
        "", _
        "const APP_NAME = 'Omnichat';", _
        "const SELECTOR_FILE = 'selectors.json';", _
        "const FIRST_RUN_FILE = 'FIRST_RUN.txt';", _
        "", _
        "const defaultSettings = {", _
        "  manualConfirm: true,", _
        "  delayRange: { min: 1200, max: 2500 },", _
        "  throttleMs: 8000,", _
        "  messagesToRead: 10,", _
        "  roundTableTurns: 2,", _
        "  copilotHost: 'https://copilot.microsoft.com',", _
        "  localModel: {", _
        "    enabled: false,", _
        "    endpoint: 'http://localhost:11434/api/generate'", _
        "  }", _
        "};", _
        "", _
        "const store = new SettingsStore({ name: 'settings.json', defaults: defaultSettings });", _
        "const logStore = new LogStore();", _
        "", _
        "let mainWindow;", _
        "let agentManager;", _
        "", _
        "function resolveResource(relPath) {", _
        "  const appDir = app.isPackaged ? process.resourcesPath : path.join(__dirname, '../../resources');", _
        "  return path.join(appDir, relPath);", _
        "}", _
        "", _
        "function ensureSelectorsFile() {", _
        "  const target = path.join(app.getPath('userData'), SELECTOR_FILE);", _
        "  if (!fs.existsSync(target)) {", _
        "    const source = resolveResource(SELECTOR_FILE);", _
        "    fs.copyFileSync(source, target);", _
        "  }", _
        "  return target;", _
        "}", _
        "", _
        "function ensureFirstRunFile() {", _
        "  const target = path.join(app.getPath('userData'), FIRST_RUN_FILE);", _
        "  if (!fs.existsSync(target)) {", _
        "    fs.copyFileSync(resolveResource(FIRST_RUN_FILE), target);", _
        "  }", _
        "  return target;", _
        "}", _
        "", _
        "function createWindow() {", _
        "  mainWindow = new BrowserWindow({", _
        "    width: 1400,", _
        "    height: 900,", _
        "    title: APP_NAME,", _
        "    webPreferences: {", _
        "      preload: path.join(__dirname, '../preload/index.js'),", _
        "      contextIsolation: true,", _
        "      nodeIntegration: false", _
        "    }", _
        "  });", _
        "", _
        "  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));", _
        "", _
        "  mainWindow.on('closed', () => {", _
        "    mainWindow = null;", _
        "    agentManager?.dispose();", _
        "  });", _
        "}", _
        "", _
        "function bootstrapAgentManager() {", _
        "  const selectorsPath = ensureSelectorsFile();", _
        "  const selectors = JSON.parse(fs.readFileSync(selectorsPath, 'utf8'));", _
        "  agentManager = new AgentManager({", _
        "    selectors,", _
        "    selectorsPath,", _
        "    logStore,", _
        "    settingsStore: store", _
        "  });", _
        "}", _
        "", _
        "app.on('ready', () => {", _
        "  ensureSelectorsFile();", _
        "  ensureFirstRunFile();", _
        "  bootstrapAgentManager();", _
        "  createWindow();", _
        "});", _
        "", _
        "app.on('window-all-closed', () => {", _
        "  if (process.platform !== 'darwin') {", _
        "    app.quit();", _
        "  }", _
        "});", _
        "", _
        "app.on('activate', () => {", _
        "  if (mainWindow === null) {", _
        "    createWindow();", _
        "  }", _
        "});", _
        "", _
        "ipcMain.handle('selectors:get', async () => {", _
        "  const selectorsPath = ensureSelectorsFile();", _
        "  const content = fs.readFileSync(selectorsPath, 'utf8');", _
        "  return JSON.parse(content);", _
        "});", _
        "", _
        "ipcMain.handle('selectors:save', async (_, payload) => {", _
        "  const selectorsPath = ensureSelectorsFile();", _
        "  fs.writeFileSync(selectorsPath, JSON.stringify(payload, null, 2), 'utf8');", _
        "  agentManager?.updateSelectors(payload);", _
        "  return true;", _
        "});", _
        "", _
        "ipcMain.handle('settings:get', () => store.all);", _
        "", _
        "ipcMain.handle('settings:save', (_, newSettings) => {", _
        "  const updated = { ...store.all, ...newSettings };", _
        "  store.all = updated;", _
        "  return updated;", _
        "});", _
        "", _
        "ipcMain.handle('agents:list', () => agentManager.getAgentsInfo());", _
        "ipcMain.handle('agents:broadcast', (_, payload) => agentManager.broadcast(payload));", _
        "ipcMain.handle('agents:send-single', (_, payload) => agentManager.sendToSingle(payload));", _
        "ipcMain.handle('agents:start-round-table', (_, payload) => agentManager.startRoundTable(payload));", _
        "ipcMain.handle('agents:pause-round-table', () => agentManager.pauseRoundTable());", _
        "ipcMain.handle('agents:resume-round-table', () => agentManager.resumeRoundTable());", _
        "ipcMain.handle('agents:stop-round-table', () => agentManager.stopRoundTable());", _
        "ipcMain.handle('agents:local-model', (_, payload) => agentManager.invokeLocalModel(payload));", _
        "ipcMain.handle('agents:selection', (_, payload) => agentManager.captureSelection(payload));", _
        "ipcMain.handle('agents:snapshot', (_, payload) => agentManager.captureSnapshot(payload));", _
        "", _
        "ipcMain.handle('log:get', () => logStore.getEntries());", _
        "ipcMain.handle('log:export', async (_, targetPath) => {", _
        "  const filePath = targetPath || dialog.showSaveDialogSync(mainWindow, {", _
        "    title: 'Export Log',", _
        "    defaultPath: path.join(app.getPath('documents'), 'Omnichat-log.txt'),", _
        "    filters: [{ name: 'Text', extensions: ['txt'] }]", _
        "  });", _
        "", _
        "  if (!filePath) {", _
        "    return null;", _
        "  }", _
        "", _
        "  fs.writeFileSync(filePath, logStore.serialize(), 'utf8');", _
        "  shell.showItemInFolder(filePath);", _
        "  return filePath;", _
        "});", _
        "", _
        "ipcMain.handle('open-external', (_, url) => {", _
        "  if (url) {", _
        "    shell.openExternal(url);", _
        "  }", _
        "  return true;", _
        "});", _
        "", _
        "ipcMain.handle('first-run:get-path', () => ensureFirstRunFile());" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\main\manager.js", _
        Join(Array( _
        "const path = require('path');", _
        "const { BrowserWindow, dialog } = require('electron');", _
        "const { randomUUID } = require('crypto');", _
        "const { randomInt } = require('./utils');", _
        "", _
        "const SITES = {", _
        "  chatgpt: { name: 'ChatGPT', url: 'https://chatgpt.com/' },", _
        "  claude: { name: 'Claude', url: 'https://claude.ai/' },", _
        "  copilot: { name: 'Copilot', url: 'https://copilot.microsoft.com/' },", _
        "  gemini: { name: 'Gemini', url: 'https://gemini.google.com/' }", _
        "};", _
        "", _
        "class AgentManager {", _
        "  constructor({ selectors, selectorsPath, logStore, settingsStore }) {", _
        "    this.selectors = selectors;", _
        "    this.selectorsPath = selectorsPath;", _
        "    this.logStore = logStore;", _
        "    this.settingsStore = settingsStore;", _
        "    this.roundTable = null;", _
        "    this.initAgents();", _
        "  }", _
        "", _
        "  initAgents() {", _
        "    this.agents = new Map();", _
        "    Object.entries(SITES).forEach(([key, site]) => {", _
        "      const win = new BrowserWindow({", _
        "        width: 1280,", _
        "        height: 720,", _
        "        show: false,", _
        "        title: `${site.name} - Omnichat`,", _
        "        webPreferences: {", _
        "          preload: path.join(__dirname, '../preload/agent-preload.js'),", _
        "          contextIsolation: true,", _
        "          nodeIntegration: false,", _
        "          additionalArguments: [`--agent-key=${key}`]", _
        "        }", _
        "      });", _
        "      win.loadURL(site.url);", _
        "      this.agents.set(key, { key, site, window: win, status: 'idle' });", _
        "    });", _
        "  }", _
        "", _
        "  dispose() {", _
        "    this.agents?.forEach(({ window }) => window.destroy());", _
        "    this.agents?.clear();", _
        "  }", _
        "", _
        "  updateSelectors(newSelectors) {", _
        "    this.selectors = newSelectors;", _
        "  }", _
        "", _
        "  getAgentsInfo() {", _
        "    return Array.from(this.agents.values()).map(({ key, site, status }) => ({", _
        "      key,", _
        "      name: site.name,", _
        "      status", _
        "    }));", _
        "  }", _
        "", _
        "  async confirmSend(targets, message) {", _
        "    if (!this.settingsStore.get('manualConfirm')) {", _
        "      return true;", _
        "    }", _
        "    const response = dialog.showMessageBoxSync({", _
        "      type: 'question',", _
        "      buttons: ['Send', 'Cancel'],", _
        "      defaultId: 0,", _
        "      cancelId: 1,", _
        "      title: 'Confirm broadcast',", _
        "      message: `Send to ${targets.join(', ')}?`,", _
        "      detail: message", _
        "    });", _
        "    return response === 0;", _
        "  }", _
        "", _
        "  async broadcast({ agents, message }) {", _
        "    const activeAgents = agents.filter((key) => this.agents.has(key));", _
        "    if (!activeAgents.length) return false;", _
        "    if (!(await this.confirmSend(activeAgents.map((k) => SITES[k].name), message))) {", _
        "      return false;", _
        "    }", _
        "    for (const agentKey of activeAgents) {", _
        "      await this.performSend(agentKey, message);", _
        "    }", _
        "    return true;", _
        "  }", _
        "", _
        "  async sendToSingle({ agent, message }) {", _
        "    if (!this.agents.has(agent)) return false;", _
        "    if (!(await this.confirmSend([SITES[agent].name], message))) {", _
        "      return false;", _
        "    }", _
        "    await this.performSend(agent, message);", _
        "    return true;", _
        "  }", _
        "", _
        "  async performSend(agentKey, message) {", _
        "    const agent = this.agents.get(agentKey);", _
        "    if (!agent) return;", _
        "", _
        "    const delay = this.randomizedDelay();", _
        "    agent.status = 'sending';", _
        "    this.logStore.append({", _
        "      id: randomUUID(),", _
        "      type: 'status',", _
        "      message: `Scheduled send to ${agent.site.name} in ${delay}ms`", _
        "    });", _
        "    await new Promise((resolve) => setTimeout(resolve, delay));", _
        "", _
        "    const selectors = this.selectors[agentKey] || {};", _
        "    await agent.window.webContents.executeJavaScript(`window.agentBridge ? window.agentBridge.sendMessage(${JSON.stringify({ message, selectors })}) : false`);", _
        "    agent.status = 'idle';", _
        "    this.logStore.append({", _
        "      id: randomUUID(),", _
        "      type: 'event',", _
        "      message: `Sent message to ${agent.site.name}`", _
        "    });", _
        "  }", _
        "", _
        "  async startRoundTable({ agents, message, turns }) {", _
        "    const activeAgents = agents.filter((key) => this.agents.has(key));", _
        "    if (!activeAgents.length) return false;", _
        "    const confirm = await this.confirmSend(activeAgents.map((k) => SITES[k].name), `Round-table for ${turns} turns. Initial message: ${message}`);", _
        "    if (!confirm) return false;", _
        "", _
        "    this.roundTable = {", _
        "      queue: [...activeAgents],", _
        "      turnsRemaining: turns,", _
        "      paused: false,", _
        "      baseMessage: message", _
        "    };", _
        "    this.logStore.append({ id: randomUUID(), type: 'event', message: 'Round-table session started.' });", _
        "    this.advanceRoundTable();", _
        "    return true;", _
        "  }", _
        "", _
        "  async advanceRoundTable() {", _
        "    if (!this.roundTable || this.roundTable.paused || this.roundTable.turnsRemaining <= 0) {", _
        "      if (this.roundTable && this.roundTable.turnsRemaining <= 0) {", _
        "        this.logStore.append({ id: randomUUID(), type: 'event', message: 'Round-table session completed.' });", _
        "        this.roundTable = null;", _
        "      }", _
        "      return;", _
        "    }", _
        "", _
        "    const agentKey = this.roundTable.queue[0];", _
        "    this.roundTable.queue.push(this.roundTable.queue.shift());", _
        "    this.roundTable.turnsRemaining -= 1;", _
        "", _
        "    const composedMessage = `${this.roundTable.baseMessage}\nTurn remaining: ${this.roundTable.turnsRemaining}`;", _
        "    await this.performSend(agentKey, composedMessage);", _
        "    const throttle = this.settingsStore.get('throttleMs');", _
        "    setTimeout(() => this.advanceRoundTable(), throttle);", _
        "  }", _
        "", _
        "  pauseRoundTable() {", _
        "    if (!this.roundTable) return false;", _
        "    this.roundTable.paused = true;", _
        "    this.logStore.append({ id: randomUUID(), type: 'status', message: 'Round-table paused.' });", _
        "    return true;", _
        "  }", _
        "", _
        "  resumeRoundTable() {", _
        "    if (!this.roundTable) return false;", _
        "    this.roundTable.paused = false;", _
        "    this.logStore.append({ id: randomUUID(), type: 'status', message: 'Round-table resumed.' });", _
        "    this.advanceRoundTable();", _
        "    return true;", _
        "  }", _
        "", _
        "  stopRoundTable() {", _
        "    if (!this.roundTable) return false;", _
        "    this.roundTable = null;", _
        "    this.logStore.append({ id: randomUUID(), type: 'event', message: 'Round-table stopped.' });", _
        "    return true;", _
        "  }", _
        "", _
        "  randomizedDelay() {", _
        "    const { min, max } = this.settingsStore.get('delayRange');", _
        "    return randomInt(min, max);", _
        "  }", _
        "", _
        "  async invokeLocalModel({ prompt }) {", _
        "    const localModel = this.settingsStore.get('localModel');", _
        "    if (!localModel.enabled) {", _
        "      return { error: 'Local model disabled.' };", _
        "    }", _
        "    try {", _
        "      const response = await fetch(localModel.endpoint, {", _
        "        method: 'POST',", _
        "        headers: { 'Content-Type': 'application/json' },", _
        "        body: JSON.stringify({ prompt })", _
        "      });", _
        "      const data = await response.json();", _
        "      return data;", _
        "    } catch (err) {", _
        "      return { error: err.message };", _
        "    }", _
        "  }", _
        "", _
        "  async captureSelection({ agent }) {", _
        "    const agentData = this.agents.get(agent);", _
        "    if (!agentData) return null;", _
        "    const result = await agentData.window.webContents.executeJavaScript('window.agentBridge.captureSelection()');", _
        "    return result;", _
        "  }", _
        "", _
        "  async captureSnapshot({ agent, maxLength = 2000 }) {", _
        "    const agentData = this.agents.get(agent);", _
        "    if (!agentData) return null;", _
        "    const result = await agentData.window.webContents.executeJavaScript(`window.agentBridge.captureSnapshot(${maxLength})`);", _
        "    return result;", _
        "  }", _
        "}", _
        "", _
        "module.exports = { AgentManager, SITES };" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\main\settings-store.js", _
        Join(Array( _
        "const fs = require('fs');", _
        "const path = require('path');", _
        "const { app } = require('electron');", _
        "", _
        "class SettingsStore {", _
        "  constructor({ name = 'settings.json', defaults = {} } = {}) {", _
        "    this.name = name;", _
        "    this.defaults = defaults;", _
        "    this.filePath = path.join(app.getPath('userData'), name);", _
        "    this._data = null;", _
        "  }", _
        "", _
        "  load() {", _
        "    if (this._data) {", _
        "      return this._data;", _
        "    }", _
        "    try {", _
        "      const raw = fs.readFileSync(this.filePath, 'utf8');", _
        "      this._data = JSON.parse(raw);", _
        "    } catch (err) {", _
        "      this._data = { ...this.defaults };", _
        "      this.save(this._data);", _
        "    }", _
        "    return this._data;", _
        "  }", _
        "", _
        "  get(key) {", _
        "    const data = this.load();", _
        "    return data[key];", _
        "  }", _
        "", _
        "  set(key, value) {", _
        "    const data = this.load();", _
        "    data[key] = value;", _
        "    this.save(data);", _
        "  }", _
        "", _
        "  save(newData) {", _
        "    this._data = { ...this.defaults, ...newData };", _
        "    fs.writeFileSync(this.filePath, JSON.stringify(this._data, null, 2), 'utf8');", _
        "  }", _
        "", _
        "  get all() {", _
        "    return this.load();", _
        "  }", _
        "", _
        "  set all(newData) {", _
        "    this.save(newData);", _
        "  }", _
        "}", _
        "", _
        "module.exports = { SettingsStore };" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\main\utils.js", _
        Join(Array( _
        "function randomInt(min, max) {", _
        "  const lower = Math.ceil(min);", _
        "  const upper = Math.floor(max);", _
        "  return Math.floor(Math.random() * (upper - lower + 1)) + lower;", _
        "}", _
        "", _
        "module.exports = { randomInt };" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\preload\agent-preload.js", _
        Join(Array( _
        "const { contextBridge } = require('electron');", _
        "", _
        "const getArgumentValue = (name) => {", _
        "  const prefix = `--${name}=`;", _
        "  for (const arg of process.argv) {", _
        "    if (arg.startsWith(prefix)) {", _
        "      return arg.replace(prefix, '');", _
        "    }", _
        "  }", _
        "  return null;", _
        "};", _
        "", _
        "contextBridge.exposeInMainWorld('agentBridge', {", _
        "  sendMessage: async ({ message, selectors }) => {", _
        "    const inputSelector = selectors.input?.find((sel) => document.querySelector(sel));", _
        "    const sendButtonSelector = selectors.sendButton?.find((sel) => document.querySelector(sel));", _
        "", _
        "    if (inputSelector) {", _
        "      const inputEl = document.querySelector(inputSelector);", _
        "      const prop = inputEl.tagName === 'TEXTAREA' || inputEl.tagName === 'INPUT' ? 'value' : 'textContent';", _
        "      inputEl.focus();", _
        "      inputEl[prop] = message;", _
        "      inputEl.dispatchEvent(new Event('input', { bubbles: true }));", _
        "    }", _
        "", _
        "    if (sendButtonSelector) {", _
        "      const btn = document.querySelector(sendButtonSelector);", _
        "      btn?.click();", _
        "    } else if (inputSelector) {", _
        "      const inputEl = document.querySelector(inputSelector);", _
        "      inputEl?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));", _
        "      inputEl?.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', bubbles: true }));", _
        "    }", _
        "", _
        "    return true;", _
        "  },", _
        "  captureSelection: () => {", _
        "    const selection = window.getSelection();", _
        "    return {", _
        "      agent: getArgumentValue('agent-key'),", _
        "      selection: selection ? selection.toString() : ''", _
        "    };", _
        "  },", _
        "  captureSnapshot: (maxLength = 2000) => {", _
        "    const title = document.title;", _
        "    const url = window.location.href;", _
        "    const containerSelector = ['main', 'article', 'body'];", _
        "    const container = containerSelector", _
        "      .map((sel) => document.querySelector(sel))", _
        "      .find(Boolean);", _
        "    const text = container ? container.innerText.slice(0, maxLength) : '';", _
        "    return { agent: getArgumentValue('agent-key'), title, url, text };", _
        "  }", _
        "});" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\preload\index.js", _
        Join(Array( _
        "const { contextBridge, ipcRenderer } = require('electron');", _
        "", _
        "contextBridge.exposeInMainWorld('omniSwitch', {", _
        "  getSelectors: () => ipcRenderer.invoke('selectors:get'),", _
        "  saveSelectors: (payload) => ipcRenderer.invoke('selectors:save', payload),", _
        "  getSettings: () => ipcRenderer.invoke('settings:get'),", _
        "  saveSettings: (payload) => ipcRenderer.invoke('settings:save', payload),", _
        "  listAgents: () => ipcRenderer.invoke('agents:list'),", _
        "  broadcast: (payload) => ipcRenderer.invoke('agents:broadcast', payload),", _
        "  sendToAgent: (payload) => ipcRenderer.invoke('agents:send-single', payload),", _
        "  startRoundTable: (payload) => ipcRenderer.invoke('agents:start-round-table', payload),", _
        "  pauseRoundTable: () => ipcRenderer.invoke('agents:pause-round-table'),", _
        "  resumeRoundTable: () => ipcRenderer.invoke('agents:resume-round-table'),", _
        "  stopRoundTable: () => ipcRenderer.invoke('agents:stop-round-table'),", _
        "  invokeLocalModel: (payload) => ipcRenderer.invoke('agents:local-model', payload),", _
        "  captureSelection: (payload) => ipcRenderer.invoke('agents:selection', payload),", _
        "  captureSnapshot: (payload) => ipcRenderer.invoke('agents:snapshot', payload),", _
        "  getLog: () => ipcRenderer.invoke('log:get'),", _
        "  exportLog: (targetPath) => ipcRenderer.invoke('log:export', targetPath),", _
        "  getFirstRunPath: () => ipcRenderer.invoke('first-run:get-path')", _
        "});", _
        "", _
        "contextBridge.exposeInMainWorld('dialogAPI', {", _
        "  openExternal: (url) => ipcRenderer.invoke('open-external', url)", _
        "});" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\renderer\index.html", _
        Join(Array( _
        "<!DOCTYPE html>", _
        "<html lang=""en"">", _
        "  <head>", _
        "    <meta charset=""UTF-8"" />", _
        "    <meta http-equiv=""X-UA-Compatible"" content=""IE=edge"" />", _
        "    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"" />", _
        "    <title>Omnichat</title>", _
        "    <link rel=""stylesheet"" href=""styles.css"" />", _
        "  </head>", _
        "  <body>", _
        "    <div id=""app"">", _
        "      <aside class=""sidebar"">", _
        "        <h1>Agents</h1>", _
        "        <div id=""agent-list"" class=""agent-list""></div>", _
        "        <div class=""sidebar-actions"">", _
        "          <button id=""refresh-agents"">Refresh</button>", _
        "          <button id=""open-settings"">Settings</button>", _
        "          <button id=""open-first-run"">First Run Guide</button>", _
        "        </div>", _
        "      </aside>", _
        "      <main class=""main"">", _
        "        <section class=""composer"">", _
        "          <textarea id=""composer-input"" placeholder=""Compose your broadcast..."" rows=""6""></textarea>", _
        "          <div class=""composer-actions"">", _
        "            <button id=""broadcast-btn"">Broadcast</button>", _
        "            <button id=""send-selected-btn"" disabled>Send to Selected</button>", _
        "            <button id=""round-table-btn"">Start Round-table</button>", _
        "            <button id=""pause-round-table-btn"" disabled>Pause</button>", _
        "            <button id=""resume-round-table-btn"" disabled>Resume</button>", _
        "            <button id=""stop-round-table-btn"" disabled>Stop</button>", _
        "          </div>", _
        "          <div class=""toolbox"">", _
        "            <button id=""quote-selection-btn"">Quote selection → composer</button>", _
        "            <button id=""snapshot-btn"">Page snapshot → composer</button>", _
        "            <button id=""quick-snippet-btn"">Quick attach snippet</button>", _
        "            <button id=""local-model-btn"">Run local model</button>", _
        "          </div>", _
        "          <div class=""tool-output"" id=""tool-output""></div>", _
        "        </section>", _
        "      </main>", _
        "      <aside class=""log-panel"">", _
        "        <h2>Live Log</h2>", _
        "        <div id=""log-entries"" class=""log-entries""></div>", _
        "        <button id=""export-log-btn"">Export .txt</button>", _
        "      </aside>", _
        "    </div>", _
        "", _
        "    <div id=""settings-modal"" class=""modal hidden"">", _
        "      <div class=""modal-content"">", _
        "        <header>", _
        "          <h2>Settings</h2>", _
        "          <button id=""close-settings"">×</button>", _
        "        </header>", _
        "        <section class=""modal-body"">", _
        "          <form id=""settings-form"">", _
        "            <label>", _
        "              Manual confirm before send", _
        "              <input type=""checkbox"" name=""manualConfirm"" />", _
        "            </label>", _
        "            <label>", _
        "              Delay range (ms)", _
        "              <div class=""inline"">", _
        "                <input type=""number"" name=""delayMin"" min=""0"" />", _
        "                <span>to</span>", _
        "                <input type=""number"" name=""delayMax"" min=""0"" />", _
        "              </div>", _
        "            </label>", _
        "            <label>", _
        "              Throttle interval (ms)", _
        "              <input type=""number"" name=""throttleMs"" min=""0"" />", _
        "            </label>", _
        "            <label>", _
        "              Messages to read (N)", _
        "              <input type=""number"" name=""messagesToRead"" min=""1"" />", _
        "            </label>", _
        "            <label>", _
        "              Round-table turns (K)", _
        "              <input type=""number"" name=""roundTableTurns"" min=""1"" />", _
        "            </label>", _
        "            <label>", _
        "              Copilot host", _
        "              <input type=""text"" name=""copilotHost"" />", _
        "            </label>", _
        "            <fieldset>", _
        "              <legend>Local model</legend>", _
        "              <label>", _
        "                Enable", _
        "                <input type=""checkbox"" name=""localModelEnabled"" />", _
        "              </label>", _
        "              <label>", _
        "                Endpoint", _
        "                <input type=""text"" name=""localModelEndpoint"" />", _
        "              </label>", _
        "            </fieldset>", _
        "            <fieldset>", _
        "              <legend>Selectors JSON</legend>", _
        "              <textarea id=""selectors-json"" rows=""10""></textarea>", _
        "            </fieldset>", _
        "            <div class=""modal-actions"">", _
        "              <button type=""submit"">Save</button>", _
        "            </div>", _
        "          </form>", _
        "        </section>", _
        "      </div>", _
        "    </div>", _
        "", _
        "    <script src=""renderer.js"" type=""module""></script>", _
        "  </body>", _
        "</html>" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\renderer\renderer.js", _
        Join(Array( _
        "const agentListEl = document.getElementById('agent-list');", _
        "const refreshAgentsBtn = document.getElementById('refresh-agents');", _
        "const openSettingsBtn = document.getElementById('open-settings');", _
        "const firstRunBtn = document.getElementById('open-first-run');", _
        "const settingsModal = document.getElementById('settings-modal');", _
        "const closeSettingsBtn = document.getElementById('close-settings');", _
        "const settingsForm = document.getElementById('settings-form');", _
        "const selectorsTextArea = document.getElementById('selectors-json');", _
        "const composerInput = document.getElementById('composer-input');", _
        "const broadcastBtn = document.getElementById('broadcast-btn');", _
        "const sendSelectedBtn = document.getElementById('send-selected-btn');", _
        "const roundTableBtn = document.getElementById('round-table-btn');", _
        "const pauseRoundTableBtn = document.getElementById('pause-round-table-btn');", _
        "const resumeRoundTableBtn = document.getElementById('resume-round-table-btn');", _
        "const stopRoundTableBtn = document.getElementById('stop-round-table-btn');", _
        "const logEntriesEl = document.getElementById('log-entries');", _
        "const exportLogBtn = document.getElementById('export-log-btn');", _
        "const quoteSelectionBtn = document.getElementById('quote-selection-btn');", _
        "const snapshotBtn = document.getElementById('snapshot-btn');", _
        "const quickSnippetBtn = document.getElementById('quick-snippet-btn');", _
        "const localModelBtn = document.getElementById('local-model-btn');", _
        "const toolOutputEl = document.getElementById('tool-output');", _
        "", _
        "let agentCache = [];", _
        "let selectedAgents = new Set();", _
        "let currentSettings = null;", _
        "", _
        "async function loadAgents() {", _
        "  agentCache = await window.omniSwitch.listAgents();", _
        "  agentListEl.innerHTML = '';", _
        "  agentCache.forEach((agent) => {", _
        "    const item = document.createElement('label');", _
        "    item.className = 'agent-item';", _
        "    item.innerHTML = `", _
        "      <div>", _
        "        <input type=""checkbox"" data-agent=""${agent.key}"" ${selectedAgents.has(agent.key) ? 'checked' : ''} />", _
        "        <span>${agent.name}</span>", _
        "      </div>", _
        "      <span class=""agent-status"">${agent.status}</span>", _
        "    `;", _
        "    item.querySelector('input').addEventListener('change', (event) => {", _
        "      const key = event.target.dataset.agent;", _
        "      if (event.target.checked) {", _
        "        selectedAgents.add(key);", _
        "      } else {", _
        "        selectedAgents.delete(key);", _
        "      }", _
        "      updateActionStates();", _
        "    });", _
        "    agentListEl.appendChild(item);", _
        "  });", _
        "  updateActionStates();", _
        "}", _
        "", _
        "function updateActionStates() {", _
        "  const hasSelection = selectedAgents.size > 0;", _
        "  sendSelectedBtn.disabled = !hasSelection;", _
        "  roundTableBtn.disabled = !hasSelection;", _
        "}", _
        "", _
        "function openSettings() {", _
        "  settingsModal.classList.remove('hidden');", _
        "}", _
        "", _
        "function closeSettings() {", _
        "  settingsModal.classList.add('hidden');", _
        "}", _
        "", _
        "async function loadSettings() {", _
        "  currentSettings = await window.omniSwitch.getSettings();", _
        "  settingsForm.manualConfirm.checked = currentSettings.manualConfirm;", _
        "  settingsForm.delayMin.value = currentSettings.delayRange.min;", _
        "  settingsForm.delayMax.value = currentSettings.delayRange.max;", _
        "  settingsForm.throttleMs.value = currentSettings.throttleMs;", _
        "  settingsForm.messagesToRead.value = currentSettings.messagesToRead;", _
        "  settingsForm.roundTableTurns.value = currentSettings.roundTableTurns;", _
        "  settingsForm.copilotHost.value = currentSettings.copilotHost;", _
        "  settingsForm.localModelEnabled.checked = currentSettings.localModel.enabled;", _
        "  settingsForm.localModelEndpoint.value = currentSettings.localModel.endpoint;", _
        "", _
        "  const selectors = await window.omniSwitch.getSelectors();", _
        "  selectorsTextArea.value = JSON.stringify(selectors, null, 2);", _
        "}", _
        "", _
        "settingsForm.addEventListener('submit', async (event) => {", _
        "  event.preventDefault();", _
        "  const manualConfirm = settingsForm.manualConfirm.checked;", _
        "  const delayMin = Number(settingsForm.delayMin.value);", _
        "  const delayMax = Number(settingsForm.delayMax.value);", _
        "  const throttleMs = Number(settingsForm.throttleMs.value);", _
        "  const messagesToRead = Number(settingsForm.messagesToRead.value);", _
        "  const roundTableTurns = Number(settingsForm.roundTableTurns.value);", _
        "  const copilotHost = settingsForm.copilotHost.value;", _
        "  const localModelEnabled = settingsForm.localModelEnabled.checked;", _
        "  const localModelEndpoint = settingsForm.localModelEndpoint.value;", _
        "", _
        "  let selectors;", _
        "  try {", _
        "    selectors = JSON.parse(selectorsTextArea.value);", _
        "  } catch (err) {", _
        "    alert('Invalid selectors JSON');", _
        "    return;", _
        "  }", _
        "", _
        "  await window.omniSwitch.saveSettings({", _
        "    manualConfirm,", _
        "    delayRange: { min: delayMin, max: delayMax },", _
        "    throttleMs,", _
        "    messagesToRead,", _
        "    roundTableTurns,", _
        "    copilotHost,", _
        "    localModel: {", _
        "      enabled: localModelEnabled,", _
        "      endpoint: localModelEndpoint", _
        "    }", _
        "  });", _
        "  await window.omniSwitch.saveSelectors(selectors);", _
        "  await loadSettings();", _
        "  closeSettings();", _
        "});", _
        "", _
        "async function broadcast() {", _
        "  const message = composerInput.value.trim();", _
        "  if (!message) return;", _
        "  await window.omniSwitch.broadcast({ agents: Array.from(selectedAgents), message });", _
        "  await refreshLog();", _
        "}", _
        "", _
        "async function sendSelected() {", _
        "  const message = composerInput.value.trim();", _
        "  if (!message) return;", _
        "  for (const agent of selectedAgents) {", _
        "    await window.omniSwitch.sendToAgent({ agent, message });", _
        "  }", _
        "  await refreshLog();", _
        "}", _
        "", _
        "async function startRoundTable() {", _
        "  const message = composerInput.value.trim();", _
        "  if (!message) return;", _
        "  const turns = Number(currentSettings.roundTableTurns || 2);", _
        "  await window.omniSwitch.startRoundTable({ agents: Array.from(selectedAgents), message, turns });", _
        "  pauseRoundTableBtn.disabled = false;", _
        "  resumeRoundTableBtn.disabled = false;", _
        "  stopRoundTableBtn.disabled = false;", _
        "  await refreshLog();", _
        "}", _
        "", _
        "async function pauseRoundTable() {", _
        "  await window.omniSwitch.pauseRoundTable();", _
        "  await refreshLog();", _
        "}", _
        "", _
        "async function resumeRoundTable() {", _
        "  await window.omniSwitch.resumeRoundTable();", _
        "  await refreshLog();", _
        "}", _
        "", _
        "async function stopRoundTable() {", _
        "  await window.omniSwitch.stopRoundTable();", _
        "  pauseRoundTableBtn.disabled = true;", _
        "  resumeRoundTableBtn.disabled = true;", _
        "  stopRoundTableBtn.disabled = true;", _
        "  await refreshLog();", _
        "}", _
        "", _
        "async function refreshLog() {", _
        "  const entries = await window.omniSwitch.getLog();", _
        "  logEntriesEl.innerHTML = '';", _
        "  entries.forEach((entry) => {", _
        "    const el = document.createElement('div');", _
        "    el.className = 'log-entry';", _
        "    el.innerHTML = `", _
        "      <div class=""timestamp"">${new Date(entry.timestamp).toLocaleString()}</div>", _
        "      <div>${entry.message}</div>", _
        "    `;", _
        "    logEntriesEl.appendChild(el);", _
        "  });", _
        "  logEntriesEl.scrollTop = logEntriesEl.scrollHeight;", _
        "}", _
        "", _
        "async function exportLog() {", _
        "  await window.omniSwitch.exportLog();", _
        "}", _
        "", _
        "async function quoteSelection() {", _
        "  if (!selectedAgents.size) {", _
        "    alert('Select an agent to capture selection.');", _
        "    return;", _
        "  }", _
        "  const agent = Array.from(selectedAgents)[0];", _
        "  const result = await window.omniSwitch.captureSelection({ agent });", _
        "  if (!result || !result.selection) {", _
        "    toolOutputEl.textContent = 'No selection found.';", _
        "    return;", _
        "  }", _
        "  const composed = `> ${result.selection.replace(/\n/g, '\n> ')}\n\n`;", _
        "  composerInput.value += `\n${composed}`;", _
        "  toolOutputEl.textContent = `Quoted from ${agent}:\n${result.selection}`;", _
        "}", _
        "", _
        "async function snapshotPage() {", _
        "  if (!selectedAgents.size) {", _
        "    alert('Select an agent to snapshot.');", _
        "    return;", _
        "  }", _
        "  const agent = Array.from(selectedAgents)[0];", _
        "  const result = await window.omniSwitch.captureSnapshot({ agent, maxLength: 2000 });", _
        "  if (!result) {", _
        "    toolOutputEl.textContent = 'Unable to capture snapshot.';", _
        "    return;", _
        "  }", _
        "  const snippet = `# ${result.title}\n${result.url}\n\n${result.text}\n\n`;", _
        "  composerInput.value += `\n${snippet}`;", _
        "  toolOutputEl.textContent = `Snapshot from ${result.title}`;", _
        "}", _
        "", _
        "function quickSnippet() {", _
        "  const base = composerInput.value.trim();", _
        "  if (!base) {", _
        "    toolOutputEl.textContent = 'Nothing to split.';", _
        "    return;", _
        "  }", _
        "  const parts = [];", _
        "  const maxLen = 2000;", _
        "  for (let i = 0; i < base.length; i += maxLen) {", _
        "    parts.push(base.slice(i, i + maxLen));", _
        "  }", _
        "  toolOutputEl.textContent = `Prepared ${parts.length} snippet(s). Ready to send sequentially.`;", _
        "}", _
        "", _
        "async function runLocalModel() {", _
        "  const prompt = composerInput.value.trim();", _
        "  if (!prompt) {", _
        "    toolOutputEl.textContent = 'Enter prompt for local model.';", _
        "    return;", _
        "  }", _
        "  const response = await window.omniSwitch.invokeLocalModel({ prompt });", _
        "  if (response?.error) {", _
        "    toolOutputEl.textContent = `Local model error: ${response.error}`;", _
        "    return;", _
        "  }", _
        "  if (response?.output) {", _
        "    toolOutputEl.textContent = `Local model output:\n${response.output}`;", _
        "  } else {", _
        "    toolOutputEl.textContent = JSON.stringify(response, null, 2);", _
        "  }", _
        "}", _
        "", _
        "refreshAgentsBtn.addEventListener('click', loadAgents);", _
        "openSettingsBtn.addEventListener('click', () => {", _
        "  loadSettings();", _
        "  openSettings();", _
        "});", _
        "firstRunBtn.addEventListener('click', async () => {", _
        "  const path = await window.omniSwitch.getFirstRunPath();", _
        "  toolOutputEl.textContent = `FIRST_RUN file located at: ${path}`;", _
        "});", _
        "closeSettingsBtn.addEventListener('click', closeSettings);", _
        "broadcastBtn.addEventListener('click', broadcast);", _
        "sendSelectedBtn.addEventListener('click', sendSelected);", _
        "roundTableBtn.addEventListener('click', startRoundTable);", _
        "pauseRoundTableBtn.addEventListener('click', pauseRoundTable);", _
        "resumeRoundTableBtn.addEventListener('click', resumeRoundTable);", _
        "stopRoundTableBtn.addEventListener('click', stopRoundTable);", _
        "exportLogBtn.addEventListener('click', exportLog);", _
        "quoteSelectionBtn.addEventListener('click', quoteSelection);", _
        "snapshotBtn.addEventListener('click', snapshotPage);", _
        "quickSnippetBtn.addEventListener('click', quickSnippet);", _
        "localModelBtn.addEventListener('click', runLocalModel);", _
        "", _
        "loadAgents();", _
        "loadSettings();", _
        "refreshLog();", _
        "setInterval(refreshLog, 4000);" _
    ), vbCrLf) & vbCrLf

    WriteText installApp & "\src\renderer\styles.css", _
        Join(Array( _
        ":root {", _
        "  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;", _
        "  background-color: #1e1f26;", _
        "  color: #f8f9ff;", _
        "}", _
        "", _
        "body, html {", _
        "  margin: 0;", _
        "  padding: 0;", _
        "  height: 100%;", _
        "}", _
        "", _
        "#app {", _
        "  display: flex;", _
        "  height: 100vh;", _
        "}", _
        "", _
        ".sidebar {", _
        "  width: 280px;", _
        "  background-color: #15161c;", _
        "  border-right: 1px solid #2b2d3a;", _
        "  padding: 16px;", _
        "  box-sizing: border-box;", _
        "  display: flex;", _
        "  flex-direction: column;", _
        "}", _
        "", _
        ".sidebar h1 {", _
        "  margin: 0 0 12px 0;", _
        "  font-size: 22px;", _
        "}", _
        "", _
        ".agent-list {", _
        "  flex: 1;", _
        "  overflow-y: auto;", _
        "}", _
        "", _
        ".agent-item {", _
        "  display: flex;", _
        "  align-items: center;", _
        "  justify-content: space-between;", _
        "  padding: 8px;", _
        "  margin-bottom: 8px;", _
        "  border-radius: 8px;", _
        "  background-color: #1f2029;", _
        "  cursor: pointer;", _
        "}", _
        "", _
        ".agent-item input[type='checkbox'] {", _
        "  margin-right: 8px;", _
        "}", _
        "", _
        ".agent-status {", _
        "  font-size: 12px;", _
        "  color: #9aa0b8;", _
        "}", _
        "", _
        ".sidebar-actions {", _
        "  display: flex;", _
        "  flex-direction: column;", _
        "  gap: 8px;", _
        "}", _
        "", _
        ".main {", _
        "  flex: 1;", _
        "  padding: 16px;", _
        "  background-color: #1e1f26;", _
        "}", _
        "", _
        ".composer textarea {", _
        "  width: 100%;", _
        "  border-radius: 8px;", _
        "  border: 1px solid #34364b;", _
        "  background-color: #111218;", _
        "  color: #f8f9ff;", _
        "  padding: 12px;", _
        "  resize: vertical;", _
        "}", _
        "", _
        ".composer-actions {", _
        "  margin-top: 12px;", _
        "  display: flex;", _
        "  gap: 12px;", _
        "  flex-wrap: wrap;", _
        "}", _
        "", _
        ".toolbox {", _
        "  margin-top: 12px;", _
        "  display: flex;", _
        "  gap: 12px;", _
        "  flex-wrap: wrap;", _
        "}", _
        "", _
        "button {", _
        "  border: none;", _
        "  border-radius: 6px;", _
        "  padding: 8px 16px;", _
        "  background-color: #3f46ff;", _
        "  color: #fff;", _
        "  cursor: pointer;", _
        "  font-weight: 600;", _
        "}", _
        "", _
        "button:disabled {", _
        "  background-color: #2a2d44;", _
        "  cursor: not-allowed;", _
        "}", _
        "", _
        ".log-panel {", _
        "  width: 320px;", _
        "  background-color: #15161c;", _
        "  border-left: 1px solid #2b2d3a;", _
        "  padding: 16px;", _
        "  box-sizing: border-box;", _
        "  display: flex;", _
        "  flex-direction: column;", _
        "}", _
        "", _
        ".log-panel h2 {", _
        "  margin-top: 0;", _
        "}", _
        "", _
        ".log-entries {", _
        "  flex: 1;", _
        "  overflow-y: auto;", _
        "  background-color: #1f2029;", _
        "  padding: 12px;", _
        "  border-radius: 8px;", _
        "  font-size: 13px;", _
        "  line-height: 1.4;", _
        "}", _
        "", _
        ".log-entry {", _
        "  margin-bottom: 8px;", _
        "}", _
        "", _
        ".log-entry .timestamp {", _
        "  color: #9aa0b8;", _
        "  font-size: 11px;", _
        "}", _
        "", _
        ".modal {", _
        "  position: fixed;", _
        "  top: 0;", _
        "  left: 0;", _
        "  width: 100vw;", _
        "  height: 100vh;", _
        "  display: flex;", _
        "  align-items: center;", _
        "  justify-content: center;", _
        "  background: rgba(0, 0, 0, 0.5);", _
        "}", _
        "", _
        ".modal.hidden {", _
        "  display: none;", _
        "}", _
        "", _
        ".modal-content {", _
        "  width: 720px;", _
        "  max-height: 90vh;", _
        "  overflow-y: auto;", _
        "  background-color: #111218;", _
        "  border-radius: 12px;", _
        "  padding: 24px;", _
        "}", _
        "", _
        ".modal-content header {", _
        "  display: flex;", _
        "  justify-content: space-between;", _
        "  align-items: center;", _
        "  margin-bottom: 16px;", _
        "}", _
        "", _
        ".modal-content textarea,", _
        ".modal-content input[type='text'],", _
        ".modal-content input[type='number'] {", _
        "  width: 100%;", _
        "  box-sizing: border-box;", _
        "  border-radius: 6px;", _
        "  border: 1px solid #34364b;", _
        "  background-color: #1e1f26;", _
        "  color: #f8f9ff;", _
        "  padding: 8px;", _
        "}", _
        "", _
        ".modal-content fieldset {", _
        "  border: 1px solid #34364b;", _
        "  border-radius: 8px;", _
        "  margin-bottom: 16px;", _
        "  padding: 12px;", _
        "}", _
        "", _
        ".modal-actions {", _
        "  display: flex;", _
        "  justify-content: flex-end;", _
        "}", _
        "", _
        ".inline {", _
        "  display: flex;", _
        "  gap: 8px;", _
        "  align-items: center;", _
        "}", _
        "", _
        ".tool-output {", _
        "  margin-top: 16px;", _
        "  background-color: #111218;", _
        "  border-radius: 8px;", _
        "  padding: 12px;", _
        "  min-height: 60px;", _
        "  border: 1px dashed #34364b;", _
        "  font-size: 13px;", _
        "  color: #c7cbe2;", _
        "  white-space: pre-wrap;", _
        "}" _
    ), vbCrLf) & vbCrLf

End Sub

Sub Fail(message)
    MsgBox message, vbCritical + vbSystemModal, "Omnichat Setup"
    WScript.Quit 1
End Sub

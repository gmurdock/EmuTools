; Pnach Builder - A cheat automation tool for PCSX2
; Part of the EmuTools repository
; https://github.com/gdmurdock/EmuTools
;
; Copyright (C) 2025 Gary Murdock
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program. If not, see <https://www.gnu.org/licenses/>.


#Requires AutoHotkey v2.0
#SingleInstance Force

global isRunning := false
global targetTitle := "GameHacking.org |"
global stopOnFocusLoss := false
global flagShowInstructions := true
global focusStop := 1

;#region Preferences
;
; Generate Settings File
userName := A_UserName
scriptName := A_ScriptName
profilesDir := A_ScriptDir "\profiles"
if !DirExist(profilesDir)
	DirCreate(profilesDir)

toolFilename := StrLower(RegExReplace(scriptName, "\.(ahk|exe)$", ""))
userFilename := StrLower(userName)
iniPath := profilesDir "\" userFilename "-" toolFilename "_settings.ini"

; Retrieve Existing Preferences
if FileExist(iniPath) {
	flagAlwaysOnTop := IniRead(iniPath, "Preferences", "AlwaysOnTop", "false") = "true"
	flagShowInstructions := IniRead(iniPath, "Preferences", "ShowInstructions", "true") = "true"
	focusMode := IniRead(iniPath, "Preferences", "FocusMode", "Stop")
	savedBrowser := IniRead(iniPath, "Preferences", "LastBrowser", "Chrome")
} else {
	flagAlwaysOnTop := false
	flagShowInstructions := true
	focusMode := "Stop"
	savedBrowser := "Chrome"
}
;
;#endregion

;#region User-Interface
;
; GUI Setup
UI := Gui(flagAlwaysOnTop ? "+AlwaysOnTop" : "", "Pnach Builder")
UI.BackColor := "0x1e1e1e"
UI.SetFont("s10 cWhite", "Segoe UI")

; Browser Selection
UI.Add("Text", "y+10 cSilver", "Select your browser:")
browserList := ["Chrome", "Edge", "Firefox", "Brave"]
browserDropdown := UI.Add("DropDownList", "vBrowserChoice w120 Background0x2a2a2a cWhite", browserList)
index := 1
Loop browserList.Length {
	if (browserList[A_Index] = savedBrowser) {
		index := A_Index
		break
	}
}
browserDropdown.Value := index

; UI Buttons
launchBtn := UI.Add("Button", "x+10 w100 Background0x333333 cWhite", "Launch Site")
launchBtn.OnEvent("Click", LaunchSite)
helpBtn := UI.Add("Button", "x+5 w30 Background0x333333 cWhite", "?")
helpBtn.OnEvent("Click", ShowInstructions)

; Show Instructions Checkbox
showInstructionsToggle := UI.Add("CheckBox", "x+10 cSilver", "Show instructions automatically")
showInstructionsToggle.Value := flagShowInstructions

; Master Codes Input
UI.Add("Text", "y+10 cSilver", "Master Codes in total (if any):")
masterInput := UI.Add("Edit", "vNumMasters w150 Background0x2a2a2a cWhite")

; Cheat Codes Input
UI.Add("Text", "y+10 cSilver", "Cheats checkboxes to select (required):")
input := UI.Add("Edit", "vNumChecks w150 Background0x2a2a2a cWhite")

; Tip Message
UI.Add("Text", "w280 cGray", "💡 Tip: Use Ctrl+F in your browser to help count matching author(s) or required code type(s) to estimate total checkboxes.")

; Focus Behaviour
UI.Add("Text", "y+10 cSilver", "On focus loss:")
radioStop := UI.Add("Radio", "vfocusStop cWhite", "Stop sequence")
radioPause := UI.Add("Radio",, "Pause and resume")
if (focusMode = "Pause")
	radioPause.Value := 1
else
	radioStop.Value := 1

; Progress Display
progressText := UI.Add("Text", "x290 y+20 w240 Background0x333333 cSilver", "")

; Execution Buttons
UI.Add("Button", "x454 y244 w80 h29 Background0x444444 cWhite", "Execute").OnEvent("Click", StartSequence)
UI.Add("Button", "x454 y277 w80 h29 Background0x444444 cWhite", "Stop").OnEvent("Click", StopSequence)

; User Label
userLabel := UI.Add("Text", "x7 y317 cSilver", userName)
userLabel.OnEvent("Click", (*) => (
	ToolTip("Settings Profile:`n" iniPath),
	SetTimer(() => ToolTip(), -2000)
))

; Cheats Folder Button
UI.SetFont("s8", "Segoe UI")  ; Override font size
openCheatsBtn := UI.Add("Button", "x72 y317 w100 h29 Background0x333333 cWhite Center", "Open Cheats`nFolder")
openCheatsBtn.OnEvent("Click", OpenCheatsFolder)

; Downloads Folder Button
openDownloadsBtn := UI.Add("Button", "x177 y317 w100 h29 Background0x333333 cWhite Center", "Open Downloads`nFolder")
openDownloadsBtn.OnEvent("Click", OpenDownloadsFolder)
UI.SetFont("s10 cWhite", "Segoe UI")  ; Restore font size

; Logo Image
UI.Add("Text", "y+15")  ; Spacer
if FileExist(A_ScriptDir "\assets\logo.png") {
	logo := UI.Add("Picture", "x7 y77 w268 h229 Center", A_ScriptDir "\assets\logo.png")
	logo.OnEvent("Click", ShowCredits)
}

; Always on Top Checkbox
alwaysOnTopToggle := UI.Add("CheckBox", "x287 y10 cSilver", "Always on top")
alwaysOnTopToggle.Value := flagAlwaysOnTop
alwaysOnTopToggle.OnEvent("Click", ToggleAlwaysOnTop)
;
;#endregion

;#region Events
;
; Show UI
UI.Show("w550 h360")

; Save On Close
UI.OnEvent("Close", OnClose)
OnClose(*) {
	SavePreferences()
	ExitApp()
}
;
;#endregion

;#region Functions
;
SavePreferences() {
	global iniPath, alwaysOnTopToggle, showInstructionsToggle, browserDropdown
	global RadioStop, RadioPause

	IniWrite(alwaysOnTopToggle.Value ? "true" : "false", iniPath, "Preferences", "AlwaysOnTop")
	IniWrite(showInstructionsToggle.Value ? "true" : "false", iniPath, "Preferences", "ShowInstructions")
	IniWrite(browserDropdown.Text, iniPath, "Preferences", "LastBrowser")

	if (RadioStop.Value = 1)
		IniWrite("Stop", iniPath, "Preferences", "FocusMode")
	else if (RadioPause.Value = 1)
		IniWrite("Pause", iniPath, "Preferences", "FocusMode")
}

ToggleAlwaysOnTop(*) {
	global flagAlwaysOnTop, iniPath, UI, alwaysOnTopToggle
	flagAlwaysOnTop := alwaysOnTopToggle.Value
	IniWrite(flagAlwaysOnTop ? "true" : "false", iniPath, "Preferences", "AlwaysOnTop")
	UI.Opt(flagAlwaysOnTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
}

LaunchSite(*) {
	global flagShowInstructions
	browser := browserDropdown.Text
	url := "https://gamehacking.org/search"

	exeMap := Map(
		"Chrome", "chrome.exe",
		"Edge", "msedge.exe",
		"Firefox", "firefox.exe",
		"Brave", "brave.exe"
	)

	if !exeMap.Has(browser) {
		MsgBox "Unsupported browser selected.", "Error", "0x40000"
		return
	}

	exe := exeMap[browser]

	try {
		; Launch browser with URL
		if ProcessExist(exe) {
			switch exe {
				case "chrome.exe", "brave.exe", "msedge.exe":
					Run '"' exe '" --new-tab "' url '"'
				case "firefox.exe":
					Run '"' exe '" -new-tab "' url '"'
				default:
					Run '"' exe '" "' url '"'  ; Fallback
			}
		} else {
			Run '"' exe '" "' url '"'  ; Launch new instance
		}
	}
	catch {
		MsgBox "Could not find or launch the selected browser executable:`n" exe "`n`nPlease check browser selection is installed on this system.", "Browser Not Found", "0x40010"
		return
	}

	; Auto-show instructions
	flagShowInstructions := showInstructionsToggle.Value
	if flagShowInstructions {
		ShowInstructions()
	}
}

StartSequence(*) {
	global isRunning := true
	global stopOnFocusLoss := radioStop.Value = 1

	; Validate cheat codes input
	if !RegExMatch(input.Value, "^\d+$") {
		MsgBox "Please enter a valid integer for total cheats to select.", "Input Error", "0x40000"
		return
	}
	num := Integer(input.Value)

	; Validate master codes input
	masters := 0
	if masterInput.Value != "" {
		if !RegExMatch(masterInput.Value, "^\d+$") {
			MsgBox "Master Codes input is optional, or must be a valid integer.", "Input Error", "0x40000"
			return
		}
		masters := Integer(masterInput.Value)
	}
	
	; Validate input values
	if num < 1 {
		MsgBox "Please enter a valid positive integer for checkbox count.", "Input Error", "0x40000"
		return
	}
	if masters < 0 {
		MsgBox "Master code count must be zero or greater.", "Input Error", "0x40000"
		return
	}

	browser := browserDropdown.Text
	exeMap := Map("Chrome", "chrome.exe", "Edge", "msedge.exe", "Firefox", "firefox.exe", "Brave", "brave.exe")
	exe := exeMap.Has(browser) ? exeMap[browser] : ""

	matches := WinGetList(targetTitle " ahk_exe " exe)
	if matches.Length = 0 {
		MsgBox "No matching window found for:`n" targetTitle "`nwith browser: " browser, "Window Not Found", "0x40000"
		return
	}
	if matches.Length > 1 {
		MsgBox "Multiple matching windows found.`nPlease close all but one to avoid unintended behavior.", "Multiple Windows", "0x40000"
		return
	}

	hwnd := matches[1]
	hwnd_id := "ahk_id " . hwnd
	WinActivate(hwnd_id)
	Sleep 500

	Loop num {
		if !isRunning {
			MsgBox "Sequence stopped.", "Stopped", "0x40000"
			return
		}

		if WinActive(hwnd_id) {
			tabCount := (A_Index <= masters) ? 2 : 3
			Send "{Tab " tabCount "}"
			Sleep 10
			Send " "
			Sleep 10
			progressText.Text := "Selected " A_Index " of " num
		} else {
			if stopOnFocusLoss {
				MsgBox "Window lost focus. Sequence stopped.", "Focus Lost", "0x40000"
				isRunning := false
				return
			} else {
				ToolTip "Paused: Click back into the GameHacking.org window to resume."
				Loop {
					Sleep 200
					if !isRunning
						return
					if WinActive(hwnd_id) {
						ToolTip
						break
					}
				}
			}
		}
	}

	MsgBox "Sequence complete.", "Done", "0x40000"
}

StopSequence(*) {
	global isRunning := false
	ToolTip
	progressText.Text := "Sequence manually stopped."
}

SelectFolder(startingFolder := "", options := 0, prompt := "") {
	global UI, flagAlwaysOnTop
	switchPref := false

	; Alternate AlwaysOnTop, if enabled
	if flagAlwaysOnTop {
		UI.Opt("-AlwaysOnTop")
		switchPref := true
	}

	; Launch Directory Select
	selected := DirSelect(startingFolder, options, prompt)

	; Restore AlwaysOnTop, if modified
	if switchPref
		UI.Opt("+AlwaysOnTop")

	return selected
}

OpenCheatsFolder(*) {
	; Retrieve saved path
	prefDir := IniRead(iniPath, "Paths", "CheatsFolder", "")
	if (prefDir != "" && DirExist(prefDir)) {
		Run prefDir
		return
	}

	; Clean up invalid path
	if (prefDir != "") {
		IniDelete(iniPath, "Paths", "CheatsFolder")
		MsgBox "
		(
Previously saved downloads folder path could not be found:
%prefDir%

Please select a new folder.
		)", "Folder Not Found", "0x40010"
	}

	; Default directory
	defaultDir := A_MyDocuments "\PCSX2\cheats"
	if DirExist(defaultDir) {
		Run defaultDir
		return
	}
	; User select path prompt
	selectDir := ""
	selectDir := SelectFolder("*" A_MyDocuments, 4, "Select your PCSX2 cheats folder")
	if selectDir {
		IniWrite(selectDir, iniPath, "Paths", "CheatsFolder")
		Run selectDir
	}
}

OpenDownloadsFolder(*) {
	; Check if user has saved a custom path
	prefDir := IniRead(iniPath, "Paths", "DownloadsFolder", "")
	if (prefDir != "" && DirExist(prefDir)) {
		Run prefDir
		return
	}

	; If saved path is invalid, clean up and notify
	if (prefDir != "") {
		IniDelete(iniPath, "Paths", "DownloadsFolder")
		MsgBox "
		(
The previously saved downloads folder path could not be found:
%prefDir%

Please select a new folder.
		)", "Folder Not Found", "0x40010"
	}

	; Default downloads path
	defaultDir := EnvGet("USERPROFILE") "\Downloads"
	if DirExist(defaultDir) {
		Run defaultDir
		return
	}

	; Prompt user to select manually
	selectDir := SelectFolder("*" A_MyDocuments, 4, "Select your Downloads folder")
	if selectDir {
		IniWrite(selectDir, iniPath, "Paths", "DownloadsFolder")
		Run selectDir
	}
}

ShowInstructions(*) {
	MsgBox "
	(
🔍 Search for the game title using the search bar
🎯 Filter by your desired code device type and author(s)
📂 Select the required format (e.g. PCSX2 / .pnach)
📑 Expand all relevant cheat categories
✅ Click the first checkbox you want to begin selection from

Once ready, return to this tool and enter the number of checkboxes to select.
	)", "Instructions", "0x40000"
}

ShowCredits(*) {
	MsgBox "
	(
🛠️  Pnach Builder v1.0.1
Created by Gary Murdock
Logo by YureiOtaku

Built with AutoHotkey v2
Designed for GameHacking.org automation

© 2025 — All rights reserved.
	)", "About This Tool", "0x40000"
}
;
;#endregion
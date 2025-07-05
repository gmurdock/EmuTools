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

iniPath := A_ScriptDir "\Settings.ini"

; Load saved preferences
if FileExist(iniPath) {
	flagShowInstructions := IniRead(iniPath, "Preferences", "ShowInstructions", "true") = "true"
	savedBrowser := IniRead(iniPath, "Preferences", "LastBrowser", "Chrome")
} else {
	savedBrowser := "Chrome"
}

; GUI Setup
UI := Gui("+AlwaysOnTop", "Pnach Builder")
UI.BackColor := "0x1e1e1e"
UI.SetFont("s10 cWhite", "Segoe UI")

; Browser selection
UI.Add("Text", "y+10 cSilver", "Select your browser:")
;browserDropdown := UI.Add("DropDownList", "vBrowserChoice w120 Background0x2a2a2a cWhite", ["Chrome", "Edge", "Firefox", "Brave"])
;browserDropdown.Value := browserDropdown.Choose(savedBrowser)

; Define the browser list
browserList := ["Chrome", "Edge", "Firefox", "Brave"]
browserDropdown := UI.Add("DropDownList", "vBrowserChoice w120 Background0x2a2a2a cWhite", browserList)

; Find the index of the saved browser
index := 1  ; Default to first item
Loop browserList.Length {
	if (browserList[A_Index] = savedBrowser) {
		index := A_Index
		break
	}
}
browserDropdown.Value := index

launchBtn := UI.Add("Button", "x+10 w100 Background0x333333 cWhite", "Launch Site")
launchBtn.OnEvent("Click", LaunchSite)

helpBtn := UI.Add("Button", "x+5 w30 Background0x333333 cWhite", "?")
helpBtn.OnEvent("Click", ShowInstructions)

showInstructionsToggle := UI.Add("CheckBox", "x+5 cSilver", "Show instructions automatically")
showInstructionsToggle.Value := flagShowInstructions

; Master code input
UI.Add("Text", "y+10 cSilver", "Master Codes in total (if any):")
masterInput := UI.Add("Edit", "vNumMasters w150 Background0x2a2a2a cWhite")

; Checkbox count input
UI.Add("Text", "y+10 cSilver", "Cheats checkboxes to select (required):")
input := UI.Add("Edit", "vNumChecks w150 Background0x2a2a2a cWhite")

; Tip
UI.Add("Text", "w280 cGray", "💡 Tip: Use Ctrl+F in your browser to help count matching author(s) or required code type(s) to estimate total checkboxes.")

; Focus behavior
UI.Add("Text", "y+10 cSilver", "On focus loss:")
focusGroup := UI.Add("Radio", "vFocusStop Checked cWhite", "Stop sequence")
UI.Add("Radio", "cWhite", "Pause and resume")

; Progress display
progressText := UI.Add("Text", "w300 cSilver", "")

; Buttons
;UI.Add("Button", "Default w80 Background0x444444 cWhite", "Execute").OnEvent("Click", StartSequence)
;UI.Add("Button", "w80 x+10 Background0x444444 cWhite", "Stop").OnEvent("Click", StopSequence)
UI.Add("Button", "x451 y247 w80 h29 Background0x444444 cWhite", "Execute").OnEvent("Click", StartSequence)
UI.Add("Button", "x451 y280 w80 h29 Background0x444444 cWhite", "Stop").OnEvent("Click", StopSequence)

; Logo
UI.Add("Text", "y+15")  ; Spacer
if FileExist(A_ScriptDir "\assets\logo.png") {
	logo := UI.Add("Picture", "x7 y71 w268 h229 Center", A_ScriptDir "\assets\logo.png")
	logo.OnEvent("Click", ShowCredits)
}

; Draw the UI
UI.Show("w549 h320")

StartSequence(*) {
	global isRunning := true
	global stopOnFocusLoss := focusGroup.Value = 1

	num := Integer(input.Value)
	masters := Integer(masterInput.Value)

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
	Sleep 300

	Sleep 5000

	Loop num {
		if !isRunning {
			MsgBox "Sequence stopped.", "Stopped", "0x40000"
			return
		}

		if WinActive(hwnd_id) {
			tabCount := (A_Index <= masters) ? 2 : 3
			Send "{Tab " tabCount "}"
			Sleep 50
			Send " "
			Sleep 50
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

	; Check if the browser executable is available
	try {
		Run '"' exe '" --version', , "Hide"
	} catch {
		MsgBox "Could not find the selected browser executable:`n" exe "`n`nPlease ensure it is installed and available in your system PATH.", "Browser Not Found", "0x40010"
		return
	}

	; Save preferences
	flagShowInstructions := showInstructionsToggle.Value
	IniWrite(flagShowInstructions ? "true" : "false", iniPath, "Preferences", "ShowInstructions")
	IniWrite(browser, iniPath, "Preferences", "LastBrowser")

	; Launch browser with URL
	Run '"' exe '" "' url '"'

	if flagShowInstructions {
		ShowInstructions()
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
🛠️  Pnach Builder v1.0
Created by Gary Murdock

Built with AutoHotkey v2
Designed for GameHacking.org automation

© 2025 — All rights reserved.
	)", "About This Tool", "0x40000"
}
; Inno Setup script. Place at: installer/windows.iss (repo root)
; The workflow passes MyAppVersion, MyAppExe and SourceDir on the command line.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef MyAppExe
  #define MyAppExe "jira_automizer.exe"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#define MyAppName "Jira Automizer"

[Setup]
; Keep this GUID the same forever so upgrades replace the old install
AppId={{B3F2A1C4-7D5E-4A9B-8C21-5E6F7A8B9C01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppName}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\release-assets
OutputBaseFilename=jira-notifier-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installs to C:\Program Files by default (asks for admin).
; The dialog also lets a user without admin rights install for themselves only.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#MyAppExe}
; The app hides in the tray, so close it automatically during upgrades
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

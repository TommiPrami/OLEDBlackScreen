; Script generated by the Inno Setup Script Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

#define MyAppName "OLED Black Screen"
#define MyAppVersion "0.5.10.13"
#define MyAppPublisher "Tommi Prami"
#define MyAppURL "https://github.com/TommiPrami/OLEDBlackScreen"
#define MyAppExeName "OLEDBlackScreen.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{B6B78EAC-6109-43ED-901A-AA490F5EBD2E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={commonpf64}\OLEDBlackScreen
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
LicenseFile=..\LICENSE
; Remove the following line to run in administrative install mode (install for all users.)
PrivilegesRequired=admin
OutputBaseFilename=OLEDBlackScreenInstall
SetupIconFile=..\Assets\Icons\icons8-timer-40.ico
; Compression settings
Compression=lzma2/ultra64
SolidCompression=yes
LZMAAlgorithm=1
LZMAUseSeparateProcess=yes
LZMADictionarySize=948576
LZMANumBlockThreads=1
LZMANumFastBytes=192
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\Win64\Release\{#MyAppExeName}"; DestDir: "{commonpf64}\OLEDBlackScreen"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{commonpf64}\OLEDBlackScreen\{#MyAppExeName}"
; TODO: Some condition and checkbox to the installer GUI for the autorun
Name: "{commonstartup}\{#MyAppName}"; Filename: "{commonpf64}\OLEDBlackScreen\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{commonpf64}\OLEDBlackScreen\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{commonpf64}\OLEDBlackScreen\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent


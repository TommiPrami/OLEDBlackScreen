unit OBSUnit.Utils;

interface

uses
  OBSUnit.Types;

{$IF NOT Defined(DEBUG)}
  procedure DoNothing;
{$ENDIF}

  function GetSecondsSinceLastInput: Integer;
  function GetDefaultSettingsFilename: string;
  procedure LoadSettingsFromFile(const ASettingsFullFilename: string; var ASettings: TSettings);
  procedure LoadSettings(var ASettingsFullFilename: string; var ASettings: TSettings);
  procedure WriteSettings(const ASettingsFullFilename: string; const ASettings: TSettings);
  // Parses an "HH:MM" 24-hour time into minutes since midnight. Returns False (and
  // AMinutes = -1) for anything that is not a valid time., accepts FormatSettings.TimeSeparator, : and .
  function TryParseTime(const AText: string; var AMinutes: Integer): Boolean;
  // Formats minutes since midnight back into "HH:MM". Uses FormatSettings.TimeSeparator
  function MinutesToTime(const AMinutes: Integer): string;
  // Substitutes the locale time separator into a '%s' placeholder, e.g. 'HH%sMM' -> 'HH:MM'.
  // Text without a '%s' placeholder is returned unchanged.
  function ApplyTimeSeparator(const ACaption: string): string;
  // Reads AFileName's version resource. Raises EOSError when the file has no version info.
  procedure GetFileVersion(const AFileName: string; var AMajor, AMinor, ARelease, ABuild: Integer);
  // Returns AFileName's version formatted as "Major.Minor.Release.Build".
  function GetFileVersionStr(const AFileName: string): string;

implementation

uses
  Winapi.Windows, System.Classes, System.IOUtils, System.Math, System.SysUtils, Grijjy.Bson, Grijjy.Bson.IO, Grijjy.Bson.Serialization;

{$IF NOT Defined(DEBUG)}
procedure DoNothing;
asm
  nop
end;
{$ENDIF}

function GetSecondsSinceLastInput: Integer;
var
  LLastInput: TLastInputInfo;
begin
  LLastInput.cbSize := SizeOf(TLastInputInfo);

  if not GetLastInputInfo(LLastInput) then
    Exit(0);

  // dwTime shares GetTickCount's 32-bit clock, so this Cardinal subtraction wraps correctly
  // across the ~49.7-day rollover. (The old Abs() broke that and is not needed.)
  Result := (GetTickCount - LLastInput.dwTime) div 1000;
end;

function GetDefaultSettingsFilename: string;
begin
  Result := TPath.Combine(TPath.GetHomePath, SETTINGS_SUB_DIR);

  if not DirectoryExists(Result) then
    ForceDirectories(Result);

  Result := TPath.Combine(Result, SETTINGS_FILENAME);
end;

procedure LoadSettingsFromFile(const ASettingsFullFilename: string; var ASettings: TSettings);
var
  LReader: IgoJsonReader;
begin
  if FileExists(ASettingsFullFilename) then
  begin
    LReader := TgoJsonReader.Load(ASettingsFullFilename);

    TgoBsonSerializer.Deserialize<TSettings>(LReader, ASettings);
  end;
end;

procedure LoadSettings(var ASettingsFullFilename: string; var ASettings: TSettings);
begin
  ASettingsFullFilename := TPath.Combine(TPath.GetAppPath, SETTINGS_FILENAME);

  if not FileExists(ASettingsFullFilename) then
  begin
    ASettingsFullFilename := GetDefaultSettingsFilename;

    if not FileExists(ASettingsFullFilename) then
      ASettingsFullFilename := '';
  end;

  if not ASettingsFullFilename.IsEmpty then
    LoadSettingsFromFile(ASettingsFullFilename, ASettings);
end;

procedure WriteSettings(const ASettingsFullFilename: string; const ASettings: TSettings);
var
  LSettingsFullFilename: string;
  LWriter: IgoJsonWriter;
  LWriterSettings: TgoJsonWriterSettings;
  LStream: TStringStream;
begin
  if ASettingsFullFilename.IsEmpty or not FileExists(ASettingsFullFilename) then
    LSettingsFullFilename := GetDefaultSettingsFilename
  else
    LSettingsFullFilename := ASettingsFullFilename;

  LWriterSettings := TgoJsonWriterSettings.Create(True);
  LWriter := TgoJsonWriter.Create(LWriterSettings);
  TgoBsonSerializer.Serialize<TSettings>(ASettings, LWriter);

  LStream := TStringStream.Create(LWriter.ToJson, TEncoding.UTF8);
  try
    LStream.SaveToFile(LSettingsFullFilename);
  finally
    LStream.Free;
  end;
end;

function GetTimeSeparatorPosition(const AText: string): Integer;
begin
  Result := Pos(FormatSettings.TimeSeparator, AText);

  if Result <= 0 then
  begin
    Result := Pos(':', AText);

    if Result <= 0 then
      Result := Pos('.', AText);
  end;
end;

function TryParseTime(const AText: string; var AMinutes: Integer): Boolean;
var
  LText: string;
  LTimeSeparator: Integer;
  LHours: Integer;
  LMinutes: Integer;
begin
  Result := False;
  AMinutes := -1;

  LText := Trim(AText);

  LTimeSeparator := GetTimeSeparatorPosition(LText);

  if not TryStrToInt(Copy(LText, 1, LTimeSeparator - 1), LHours) then
    Exit;

  if not TryStrToInt(Copy(LText, LTimeSeparator + 1, Length(LText)), LMinutes) then
    Exit;

  if not InRange(LHours, 0, 23) or not InRange(LMinutes,  0, 59) then
    Exit;

  AMinutes := LHours * 60 + LMinutes;
  Result := True;
end;

function MinutesToTime(const AMinutes: Integer): string;
begin
  // Use the locale time separator so a loaded value matches the suggested format shown by the edit.
  Result := Format('%.2d%s%.2d', [AMinutes div 60, string(FormatSettings.TimeSeparator), AMinutes mod 60]);
end;

function ApplyTimeSeparator(const ACaption: string): string;
begin
  if ACaption.Contains('%s', True) then
    Result := Format(ACaption, [string(FormatSettings.TimeSeparator)])
  else
    Result := ACaption;
end;

procedure GetFileVersion(const AFileName: string; var AMajor, AMinor, ARelease, ABuild: Integer);
var
  LBuffer: TBytes;
  LHandle: DWORD;
  LFixedPtr: PVSFixedFileInfo;
begin
  AMajor := 0;
  AMinor := 0;
  ARelease := 0;
  ABuild := 0;

  var LSize := GetFileVersionInfoSize(PChar(AFileName), LHandle);

  if LSize = 0 then
    RaiseLastOSError;

  SetLength(LBuffer, LSize);

  if not GetFileVersionInfo(PChar(AFileName), LHandle, LSize, LBuffer) then
    RaiseLastOSError;

  if not VerQueryValue(LBuffer, '\', Pointer(LFixedPtr), LSize) then
    RaiseLastOSError;

  AMajor := LongRec(LFixedPtr.dwFileVersionMS).Hi;  //major
  AMinor := LongRec(LFixedPtr.dwFileVersionMS).Lo;  //minor
  ARelease := LongRec(LFixedPtr.dwFileVersionLS).Hi;  //release
  ABuild := LongRec(LFixedPtr.dwFileVersionLS).Lo; //build
end;

function GetFileVersionStr(const AFileName: string): string;
var
  LMajor: Integer;
  LMinor: Integer;
  LRelease: Integer;
  LBuild: Integer;
begin
  GetFileVersion(AFileName, LMajor, LMinor, LRelease, LBuild);

  Result := Format('%d.%d.%d.%d', [LMajor, LMinor, LRelease, LBuild]);
end;

end.

unit OBSUnit.Utils;

interface

uses
  OBSUnit.Types;

  function GetSecondsSinceLastInput: Integer;
  function GetDefaultSettingsFilename: string;
  procedure LoadSettingsFromFile(const ASettingsFullFilename: string; var ASettings: TSettings);
  procedure LoadSettings(var ASettingsFullFilename: string; var ASettings: TSettings);
  procedure WriteSettings(const ASettingsFullFilename: string; const ASettings: TSettings);

implementation

uses
  Winapi.Windows, System.Classes, System.IOUtils, System.SysUtils, Grijjy.Bson, Grijjy.Bson.IO, Grijjy.Bson.Serialization;

function GetSecondsSinceLastInput: Integer;
var
  LLastInput: TLastInputInfo;
begin
  LLastInput.cbSize := SizeOf(TLastInputInfo);

  GetLastInputInfo(LLastInput);

  Result := Abs(GetTickCount - LLastInput.dwTime) div 1000;
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
  end
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

end.

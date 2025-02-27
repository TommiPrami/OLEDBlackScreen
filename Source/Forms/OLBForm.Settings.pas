unit OLBForm.Settings;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.SysUtils, System.Variants, Vcl.ActnList,
  Vcl.Controls, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.Mask, Vcl.StdCtrls, OBSUnit.Types;

type
  TOLBSettingsForm = class(TForm)
    ActionCancel: TAction;
    ActionList: TActionList;
    ActionOK: TAction;
    ButtonCancel: TButton;
    ButtonOK: TButton;
    LabeledEditMouseMoveDistance: TLabeledEdit;
    LabeledEditMouseMoveResetTime: TLabeledEdit;
    LabeledEditUserIdleTime: TLabeledEdit;
    LabelMopuseMoveDIstanceUnit: TLabel;
    LabelMouseMoveResetTimeUnit: TLabel;
    LabelUserIdleTimeUnit: TLabel;
    PanelButtons: TPanel;
    PanelMain: TPanel;
    ScrollBoxMain: TScrollBox;
    LabelVersion: TLabel;
    procedure ActionCancelExecute(Sender: TObject);
    procedure ActionOKExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FSettings: TSettings;
    function ValidateInput: Boolean;
  public
    property Settings: TSettings read FSettings write FSettings;

    class function ClassCreate(const AOwner: TComponent = nil): TCustomForm;
    class function ClassShowModal(AOwner: TComponent; var ASettings: TSettings): Integer;
  end;

var
  OLBSettingsForm: TOLBSettingsForm;

implementation

{$R *.dfm}

{ TOLBSettingsForm }

// TODO: Maybe these version stuff wold be nice to have in some common place
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

procedure GetAppVersion(var AMajor, AMinor, ARelease, ABuild: Integer);
begin
  GetFileVersion(Application.ExeName, AMajor, AMinor, ARelease, ABuild);
end;

function GetAppVersionStr: string;
var
  LMajor: Integer;
  LMinor: Integer;
  LRelease: Integer;
  LBuild: Integer;
begin
  GetAppVersion(LMajor, LMinor, LRelease, LBuild);

  Result := Format('%d.%d.%d.%d', [LMajor, LMinor, LRelease, LBuild]);
end;

procedure TOLBSettingsForm.ActionCancelExecute(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TOLBSettingsForm.ActionOKExecute(Sender: TObject);
var
  LActiveControl: TWinControl;
begin
  LActiveControl := ActiveControl;
  try
    SetFocusedControl(ButtonOK);

    if ValidateInput then
      ModalResult := mrOk;
  finally
    if Assigned(LActiveControl) then
      ActiveControl := LActiveControl;
  end;
end;

class function TOLBSettingsForm.ClassCreate(const AOwner: TComponent): TCustomForm;
begin
  if Assigned(AOwner) then
    Result := Self.Create(AOwner)
  else
    Result := Self.Create(Application);
end;

class function TOLBSettingsForm.ClassShowModal(AOwner: TComponent; var ASettings: TSettings): Integer;
begin
  OLBSettingsForm := ClassCreate(AOwner) as TOLBSettingsForm;

  try
    OLBSettingsForm.Settings := ASettings;
    Result := OLBSettingsForm.ShowModal;

    if Result = mrOk then
      ASettings := OLBSettingsForm.Settings;
  finally
    OLBSettingsForm.Release
  end;
end;

procedure TOLBSettingsForm.FormShow(Sender: TObject);
begin
  LabeledEditUserIdleTime.Text := FSettings.UserIdleTime.ToString;
  LabeledEditMouseMoveDistance.Text := FSettings.MouseMoveDistance.ToString;
  LabeledEditMouseMoveResetTime.Text := FSettings.MouseMoveResetTime.ToString;

  LabelVersion.Caption := 'Version: ' + GetAppVersionStr;
end;

function TOLBSettingsForm.ValidateInput: Boolean;
var
  LIntValue: Integer;
  LFloatValue: Double;
begin
  Result := False;

  if TryStrToInt(LabeledEditUserIdleTime.Text, LIntValue) then
    FSettings.UserIdleTime := LIntValue
  else
    Exit;

  if TryStrToFloat(LabeledEditMouseMoveDistance.Text, LFloatValue) then
    FSettings.MouseMoveDistance := LFloatValue
  else
    Exit;

  if TryStrToInt(LabeledEditMouseMoveResetTime.Text, LIntValue) then
    FSettings.MouseMoveResetTime := LIntValue
  else
    Exit;

  Result := True;
end;


initialization
  OLBSettingsForm := nil;
end.

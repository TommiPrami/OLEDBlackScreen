unit OLBForm.Settings;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.SysUtils, System.UITypes, System.Variants,
  Vcl.ActnList, Vcl.Controls, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.Mask, Vcl.StdCtrls, OBSUnit.Types;

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
    LabelMouseMoveDistanceUnit: TLabel;
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

// TODO: Maybe these version stuff would be nice to have in some common place
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
begin
  // Move focus off the active edit so its content is committed before we validate.
  SetFocusedControl(ButtonOK);

  if ValidateInput then
    ModalResult := mrOk;
  // On failure ValidateInput has already focused the offending edit.
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
    OLBSettingsForm.Release;
    OLBSettingsForm := nil; // Release() frees the form but leaves the global dangling; nil it so it can be reopened
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

  function FieldError(const AEdit: TCustomEdit; const AFieldName: string): Boolean;
  begin
    MessageDlg(Format('Please enter a valid number for "%s".', [AFieldName]), mtError, [mbOK], 0);
    AEdit.SetFocus;

    Result := False;
  end;

var
  LUserIdleTime: Integer;
  LMouseMoveDistance: Double;
  LMouseMoveResetTime: Integer;
begin
  // Validate everything first, then commit, so a later failure cannot leave FSettings half-updated.
  if not TryStrToInt(LabeledEditUserIdleTime.Text, LUserIdleTime) then
    Exit(FieldError(LabeledEditUserIdleTime, 'User idle time'));

  if not TryStrToFloat(LabeledEditMouseMoveDistance.Text, LMouseMoveDistance) then
    Exit(FieldError(LabeledEditMouseMoveDistance, 'Mouse move distance'));

  if not TryStrToInt(LabeledEditMouseMoveResetTime.Text, LMouseMoveResetTime) then
    Exit(FieldError(LabeledEditMouseMoveResetTime, 'Mouse move reset time'));

  FSettings.UserIdleTime := LUserIdleTime;
  FSettings.MouseMoveDistance := LMouseMoveDistance;
  FSettings.MouseMoveResetTime := LMouseMoveResetTime;

  Result := True;
end;


initialization
  OLBSettingsForm := nil;
end.

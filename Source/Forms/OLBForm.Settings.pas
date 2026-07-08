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
    CheckBoxFriday: TCheckBox;
    CheckBoxLockOnScheduleEnd: TCheckBox;
    CheckBoxMonday: TCheckBox;
    CheckBoxSaturday: TCheckBox;
    CheckBoxSunday: TCheckBox;
    CheckBoxThursday: TCheckBox;
    CheckBoxTuesday: TCheckBox;
    CheckBoxWednesday: TCheckBox;
    LabeledEditLockIdleSeconds: TLabeledEdit;
    LabeledEditMouseMoveDistance: TLabeledEdit;
    LabeledEditMouseMoveResetTime: TLabeledEdit;
    LabeledEditScheduleEnd: TLabeledEdit;
    LabeledEditScheduleStart: TLabeledEdit;
    LabeledEditUserIdleTime: TLabeledEdit;
    LabelLockIdleSecondsUnit: TLabel;
    LabelMouseMoveDistanceUnit: TLabel;
    LabelMouseMoveResetTimeUnit: TLabel;
    LabelScheduleHint: TLabel;
    LabelScheduleTitle: TLabel;
    LabelUserIdleTimeUnit: TLabel;
    LabelVersion: TLabel;
    PanelButtons: TPanel;
    PanelMain: TPanel;
    ScrollBoxMain: TScrollBox;
    procedure FormCreate(Sender: TObject);
    procedure ActionCancelExecute(Sender: TObject);
    procedure ActionOKExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ScheduleControlClick(Sender: TObject);
  private
    FSettings: TSettings;
    function DayCheckBoxes: TArray<TCheckBox>;
    function ValidateInput: Boolean;
    procedure LoadScheduleControls;
    procedure SetTimeFormat(const ALabel: TBoundLabel);
    procedure UpdateScheduleControlsEnabled;
  public
    property Settings: TSettings read FSettings write FSettings;

    class function ClassCreate(const AOwner: TComponent = nil): TCustomForm;
    class function ClassShowModal(AOwner: TComponent; var ASettings: TSettings): Integer;
  end;

var
  OLBSettingsForm: TOLBSettingsForm;

implementation

uses
  OBSUnit.Utils;

{$R *.dfm}

{ TOLBSettingsForm }

procedure TOLBSettingsForm.FormCreate(Sender: TObject);
begin
  SetTimeFormat(LabeledEditScheduleStart.EditLabel);
  SetTimeFormat(LabeledEditScheduleEnd.EditLabel);
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

procedure TOLBSettingsForm.ScheduleControlClick(Sender: TObject); //FI:O804
begin
  UpdateScheduleControlsEnabled;
end;

procedure TOLBSettingsForm.SetTimeFormat(const ALabel: TBoundLabel);
begin
  ALabel.Caption := ApplyTimeSeparator(ALabel.Caption);
end;

function TOLBSettingsForm.DayCheckBoxes: TArray<TCheckBox>;
begin
  // Order must match TWeekDay (Monday .. Sunday).
  Result := [CheckBoxMonday, CheckBoxTuesday, CheckBoxWednesday, CheckBoxThursday,
    CheckBoxFriday, CheckBoxSaturday, CheckBoxSunday];
end;

procedure TOLBSettingsForm.FormShow(Sender: TObject);
begin
  LabeledEditUserIdleTime.Text := FSettings.UserIdleTime.ToString;
  LabeledEditMouseMoveDistance.Text := FSettings.MouseMoveDistance.ToString;
  LabeledEditMouseMoveResetTime.Text := FSettings.MouseMoveResetTime.ToString;

  LoadScheduleControls;

  LabelVersion.Caption := 'Version: ' + GetFileVersionStr(Application.ExeName);
end;

procedure TOLBSettingsForm.LoadScheduleControls;
var
  LDay: TWeekDay;
  LCheckBoxes: TArray<TCheckBox>;
begin
  LCheckBoxes := DayCheckBoxes;

  for LDay := Low(TWeekDay) to High(TWeekDay) do
    LCheckBoxes[Ord(LDay)].Checked := LDay in FSettings.ScheduleDays;

  if FSettings.ScheduleStartMinutes >= 0 then
    LabeledEditScheduleStart.Text := MinutesToTime(FSettings.ScheduleStartMinutes)
  else
    LabeledEditScheduleStart.Text := '';

  if FSettings.ScheduleEndMinutes >= 0 then
    LabeledEditScheduleEnd.Text := MinutesToTime(FSettings.ScheduleEndMinutes)
  else
    LabeledEditScheduleEnd.Text := '';

  CheckBoxLockOnScheduleEnd.Checked := FSettings.LockWhenScheduleEnds;
  LabeledEditLockIdleSeconds.Text := FSettings.LockIdleSeconds.ToString;

  UpdateScheduleControlsEnabled;
end;

procedure TOLBSettingsForm.UpdateScheduleControlsEnabled;
var
  LCheckBox: TCheckBox;
  LAnyDayChecked: Boolean;
begin
  LAnyDayChecked := False;

  for LCheckBox in DayCheckBoxes do
    if LCheckBox.Checked then
    begin
      LAnyDayChecked := True;
      Break;
    end;

  // The times and the auto-lock are only meaningful when the schedule is active.
  LabeledEditScheduleStart.Enabled := LAnyDayChecked;
  LabeledEditScheduleEnd.Enabled := LAnyDayChecked;
  CheckBoxLockOnScheduleEnd.Enabled := LAnyDayChecked;
  LabeledEditLockIdleSeconds.Enabled := LAnyDayChecked and CheckBoxLockOnScheduleEnd.Checked;
end;

function TOLBSettingsForm.ValidateInput: Boolean;

  function FieldError(const AControl: TWinControl; const AMessage: string): Boolean;
  begin
    MessageDlg(AMessage, mtError, [mbOK], 0);

    if AControl.CanFocus then
      AControl.SetFocus;

    Result := False;
  end;

  // Reads an optional "HH:MM" / "HH.MM" edit. Empty text is allowed and yields AMinutes = -1.
  function TryReadOptionalTime(const AEdit: TLabeledEdit; const AFieldName: string; out AMinutes: Integer): Boolean;
  begin
    if Trim(AEdit.Text).IsEmpty then
    begin
      AMinutes := -1;
      Exit(True);
    end;

    Result := TryParseTime(AEdit.Text, AMinutes);

    if not Result then
      FieldError(AEdit, Format('Please enter "%s" as HH%sMM (24-hour), or leave it empty.', [AFieldName,
        string(FormatSettings.TimeSeparator)]));
  end;

var
  LUserIdleTime: Integer;
  LMouseMoveDistance: Double;
  LMouseMoveResetTime: Integer;
  LDays: TWeekDays;
  LStartMinutes: Integer;
  LEndMinutes: Integer;
  LDay: TWeekDay;
  LCheckBoxes: TArray<TCheckBox>;
  LLockWhenEnds: Boolean;
  LLockIdleSeconds: Integer;
begin
  // Validate everything first, then commit, so a later failure cannot leave FSettings half-updated.
  if not TryStrToInt(LabeledEditUserIdleTime.Text, LUserIdleTime) then
    Exit(FieldError(LabeledEditUserIdleTime, 'Please enter a valid number for "User idle time".'));

  if not TryStrToFloat(LabeledEditMouseMoveDistance.Text, LMouseMoveDistance) then
    Exit(FieldError(LabeledEditMouseMoveDistance, 'Please enter a valid number for "Mouse move distance".'));

  if not TryStrToInt(LabeledEditMouseMoveResetTime.Text, LMouseMoveResetTime) then
    Exit(FieldError(LabeledEditMouseMoveResetTime, 'Please enter a valid number for "Mouse move reset time".'));

  LDays := [];
  LCheckBoxes := DayCheckBoxes;
  for LDay := Low(TWeekDay) to High(TWeekDay) do
    if LCheckBoxes[Ord(LDay)].Checked then
      Include(LDays, LDay);

  // Times only matter when a day is chosen; otherwise the schedule is off entirely.
  if LDays = [] then
  begin
    LStartMinutes := -1;
    LEndMinutes := -1;
  end
  else
  begin
    if not TryReadOptionalTime(LabeledEditScheduleStart, 'Start time', LStartMinutes) then
      Exit(False);

    if not TryReadOptionalTime(LabeledEditScheduleEnd, 'End time', LEndMinutes) then
      Exit(False);

    if (LStartMinutes >= 0) and (LEndMinutes >= 0) and (LStartMinutes >= LEndMinutes) then
      Exit(FieldError(LabeledEditScheduleStart, 'The schedule start time must be earlier than the end time.'));
  end;

  // Auto-lock only applies when a schedule is set. Validate the idle grace strictly
  // when it is enabled; otherwise keep a sane value without blocking the save.
  LLockWhenEnds := (LDays <> []) and CheckBoxLockOnScheduleEnd.Checked;

  if LLockWhenEnds then
  begin
    if not TryStrToInt(LabeledEditLockIdleSeconds.Text, LLockIdleSeconds) or (LLockIdleSeconds <= 0) then
      Exit(FieldError(LabeledEditLockIdleSeconds,
        'Please enter "Lock after idle" as a whole number of seconds greater than zero.'));
  end
  else if not TryStrToInt(LabeledEditLockIdleSeconds.Text, LLockIdleSeconds) then
    LLockIdleSeconds := FSettings.LockIdleSeconds;

  FSettings.UserIdleTime := LUserIdleTime;
  FSettings.MouseMoveDistance := LMouseMoveDistance;
  FSettings.MouseMoveResetTime := LMouseMoveResetTime;
  FSettings.ScheduleDays := LDays;
  FSettings.ScheduleStartMinutes := LStartMinutes;
  FSettings.ScheduleEndMinutes := LEndMinutes;
  FSettings.LockWhenScheduleEnds := LLockWhenEnds;
  FSettings.LockIdleSeconds := LLockIdleSeconds;

  Result := True;
end;


initialization
  OLBSettingsForm := nil;
end.

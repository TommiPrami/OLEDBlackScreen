unit OLBForm.Settings;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.SysUtils, System.Variants, Vcl.ActnList,
  Vcl.Controls, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.Mask, Vcl.StdCtrls, OBSUnit.Types;

type
  TOLBSettingsForm = class(TForm)
    ActionCancel: TAction;
    ActionList1: TActionList;
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

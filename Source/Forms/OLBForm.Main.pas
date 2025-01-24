unit OLBForm.Main;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.Diagnostics, System.ImageList,
  System.SysUtils, System.Variants, System.Win.TaskbarCore, Vcl.ActnList, Vcl.BaseImageCollection, Vcl.Controls,
  Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.ImgList, Vcl.StdActns, Vcl.Taskbar, Vcl.VirtualImageList,
  OBSUnit.SystemCritical, OBSUnit.Types, SVGIconImageCollection, SVGIconVirtualImageList, Vcl.ImageCollection, Vcl.Menus,
  Vcl.StdCtrls;

{ TODO:
    Check these:
      - https://github.com/aehimself/AEFramework/blob/master/AE.Comp.KeepMeAwake.pas
      - https://stackoverflow.com/questions/2212823/how-to-detect-inactive-user
      - https://stackoverflow.com/questions/2177513/receive-screensaver-notification
}

type
  TOLBMainForm = class(TForm)
    ActionClose: TAction;
    ActionList: TActionList;
    ActionSettings: TAction;
    ActionStopSavingScreen: TAction;
    ImageListTrayIcon: TImageList;
    LabelDebug: TLabel;
    MenuItemExit: TMenuItem;
    MenuItemPause: TMenuItem;
    MenuItemPause10min: TMenuItem;
    MenuItemPause30min: TMenuItem;
    MenuItemPause45min: TMenuItem;
    MenuItemPause60min: TMenuItem;
    MenuItemSeparator: TMenuItem;
    MenuItemSettings: TMenuItem;
    PopupMenuTrayIcon: TPopupMenu;
    Timer: TTimer;
    TimerAfterShow: TTimer;
    TrayIcon: TTrayIcon;
    procedure ActionCloseExecute(Sender: TObject);
    procedure ActionSettingsExecute(Sender: TObject);
    procedure ActionStopSavingScreenExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuItemPauseClick(Sender: TObject);
    procedure TimerAfterShowTimer(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  strict private
    FMouseDistance: TMouseDistance;
    FPauseUntil: TDateTime;
    FSettings: TSettings;
    FSettingsFullFilename: string;
    procedure AddDebugLine(const ADebugLine: string; const AClear: Boolean = False);
    procedure GetRidOfCheckedPauseMenu;
    procedure HideForm;
    procedure PauseFor(const AMinutesToPause: Integer);
    procedure ShowForm;
    procedure StartSavingScreen;
    procedure StopSavingScreen;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  end;

var
  OLBMainForm: TOLBMainForm;

implementation

uses
  System.DateUtils, System.Math, OBSUnit.Utils, OLBForm.Settings;

{$R *.dfm}

procedure TOLBMainForm.ActionCloseExecute(Sender: TObject);
begin
  Close;
end;

procedure TOLBMainForm.ActionSettingsExecute(Sender: TObject);
begin
  if not Assigned(OLBSettingsForm) then
    if TOLBSettingsForm.ClassShowModal(Self, FSettings) = mrOk then
      WriteSettings(FSettingsFullFilename, FSettings);
end;

procedure TOLBMainForm.ActionStopSavingScreenExecute(Sender: TObject);
begin
  StopSavingScreen;
end;

procedure TOLBMainForm.AddDebugLine(const ADebugLine: string; const AClear: Boolean = False); //FI:O804
begin
  {$IFDEF DEBUG}
  if AClear then
    LabelDebug.Caption := '';

  LabelDebug.Caption := LabelDebug.Caption + sLineBreak + ADebugLine;
  {$ELSE}
  DoNothing;
  {$ENDIF}
end;

procedure TOLBMainForm.CreateParams(var AParams: TCreateParams);
begin
  inherited;

  AParams.ExStyle := AParams.ExStyle and not WS_EX_APPWINDOW;
  AParams.WndParent := Application.Handle;
end;

procedure TOLBMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SystemCritical.Stop;
end;

procedure TOLBMainForm.FormCreate(Sender: TObject);
begin
  FMouseDistance := TMouseDistance.Create(FSettings.MouseMoveResetTime);
  FPauseUntil := 0.00;

  LabelDebug.Visible := {$IFDEF DEBUG}True{$ELSE}False{$ENDIF};
  Visible := LabelDebug.Visible;

  LoadSettings(FSettingsFullFilename, FSettings);

  SystemCritical.Start;
end;

procedure TOLBMainForm.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key in [Ord('A')..Ord('Z'), VK_SPACE] then
    ActionStopSavingScreen.Execute;
end;

procedure TOLBMainForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FMouseDistance.AddCoordinate(X, Y) > FSettings.MouseMoveDistance then
    StopSavingScreen;
end;

procedure TOLBMainForm.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    PopupMenuTrayIcon.Popup(X, Y)
  else
    StopSavingScreen;
end;

procedure TOLBMainForm.GetRidOfCheckedPauseMenu;
begin
  for var LIndex := 0 to MenuItemPause.Count - 1 do
    if MenuItemPause.Items[LIndex].Checked then
      MenuItemPause.Items[LIndex].Checked := False;
end;

procedure TOLBMainForm.HideForm;
begin
  {$IFDEF RELEASE}
  AlphaBlendValue := 0;
  AlphaBlend := True;
  WindowState := TWindowState.wsMinimized;
  Visible := False;
  ShowWindow(Handle, SW_HIDE);
  {$ELSE}
  AddDebugLine('Hide Form...', True);
  {$ENDIF}
end;

procedure TOLBMainForm.MenuItemPauseClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    var LMenuItem := Sender as TMenuItem;

    if LMenuItem.Tag > 0 then
    begin
      if LMenuItem.Checked then
      begin
        LMenuItem.Checked := True; // Kludge: AutoCheck does not work visually, this shold fix it
        PauseFor(LMenuItem.Tag);
      end
      else
      begin
        GetRidOfCheckedPauseMenu;
        PauseFor(0);
      end;
    end;
  end;
end;

procedure TOLBMainForm.PauseFor(const AMinutesToPause: Integer);
begin
  if AMinutesToPause > 0 then
    FPauseUntil := IncMinute(Now, AMinutesToPause)
  else
    FPauseUntil := 0.00;
end;

procedure TOLBMainForm.ShowForm;
begin
  BorderStyle := bsNone;
  WindowState := {$IFDEF RELEASE}TWindowState.wsMaximized{$ELSE}TWindowState.wsNormal{$ENDIF};

  FormStyle := fsStayOnTop;
  Visible := True;
  AlphaBlendValue := 255;
  AlphaBlend := False;

  // Last step
  Application.BringToFront;
end;

procedure TOLBMainForm.StartSavingScreen;
begin
  ShowForm;

  FMouseDistance.Clear;
end;

procedure TOLBMainForm.StopSavingScreen;
begin
  HideForm;

  FPauseUntil := 0.00;

  FMouseDistance.Clear;
end;

procedure TOLBMainForm.TimerAfterShowTimer(Sender: TObject);
begin
  TimerAfterShow.Enabled := False;

  StopSavingScreen;

  {$IFDEF DEBUG}
  ShowForm;
  Left := Screen.MonitorFromWindow(Handle).Width div 6;
  Top := Screen.MonitorFromWindow(Handle).Height div 6;
  {$ENDIF};
end;

procedure TOLBMainForm.TimerTimer(Sender: TObject);
begin
  AddDebugLine('', True);

  if TimerAfterShow.Enabled then
    Exit;

  if (FPauseUntil < 0.00) or (not IsZero(FPauseUntil) and (Now > FPauseUntil)) then
  begin
    GetRidOfCheckedPauseMenu;
    FPauseUntil := 0.00;
  end;

  if WindowState = TWindowState.wsMaximized then
  begin
    // Do something for the teams and shit...
  end
  else
  begin
    if IsZero(FPauseUntil) then
    begin
      var LTImeToScreenSaving := FSettings.UserIdleTime - GetSecondsSinceLastInput;

      if LTImeToScreenSaving <= 0 then
      begin
        StartSavingScreen;

        AddDebugLine('Saving screen...');
      end
      else
        AddDebugLine('Time to saving screen: ' + LTImeToScreenSaving.ToString);
    end
    {$IFDEF DEBUG}
    else
    begin
      var LPauseTimeLeft: TDateTime := Now - FPauseUntil;

      AddDebugLine('Paused...');
      AddDebugLine('  - Paused for ' + TimeToStr(LPauseTimeLeft));
    end;
    {$ENDIF}
  end;
end;

procedure TOLBMainForm.TrayIconDblClick(Sender: TObject);
begin
  ActionSettings.Execute;
end;

end.

unit OLBForm.Main;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.Diagnostics, System.ImageList,
  System.SysUtils, System.Variants, System.Win.TaskbarCore, Vcl.ActnList, Vcl.BaseImageCollection, Vcl.Controls,
  Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.ImgList, Vcl.StdActns, Vcl.Taskbar, Vcl.VirtualImageList,
  OBSUnit.SystemCritical, OBSUnit.Types, SVGIconImageCollection, SVGIconVirtualImageList, Vcl.ImageCollection, Vcl.Menus,
  Vcl.StdCtrls;

{
  TODO:
    Check these:
      - https://github.com/aehimself/AEFramework/blob/master/AE.Comp.KeepMeAwake.pas
      - https://stackoverflow.com/questions/2212823/how-to-detect-inactive-user
      - https://stackoverflow.com/questions/2177513/receive-screensaver-notification
      - Possibly add some random char sensing also with SendInput API
        - Maybe in  same time to add some randomness to the mouse time also...
    - Some timeout, to let system to LogOut, and is there way to tell monitor to go to the "power saving mode" in that case, so screen would not be static
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
    procedure ActionCloseExecute(ASender: TObject);
    procedure ActionSettingsExecute(ASender: TObject);
    procedure ActionStopSavingScreenExecute(ASender: TObject);
    procedure FormClose(ASender: TObject; var AAction: TCloseAction);
    procedure FormCreate(ASender: TObject);
    procedure FormKeyUp(ASender: TObject; var AKey: Word; AShift: TShiftState);
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Integer);
    procedure FormMouseUp(ASender: TObject; AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
    procedure MenuItemPauseClick(ASender: TObject);
    procedure TimerAfterShowTimer(ASender: TObject);
    procedure TimerTimer(ASender: TObject);
    procedure TrayIconDblClick(ASender: TObject);
  strict private
    FIdleWatch: TStopwatch;
    FLockingBlocked: Boolean;
    FMaxIdleMoveDistance: Integer;
    FMinIdleMouseMoveInterval: Double; // Seconds
    FMouseDistance: TMouseDistance;
    FPauseUntil: TDateTime;
    FPendingLock: Boolean;
    FSavingScreen: Boolean;
    FSettings: TSettings;
    FSettingsFullFilename: string;
    function GetRandomMouseInput: TInput;
    procedure AddDebugLine(const ADebugLine: string; const AClear: Boolean = False);
    procedure ApplySettings;
    procedure CalculateIdleMouseMoveDistanceAndTime;
    procedure GetRidOfCheckedPauseMenu;
    procedure HideForm;
    procedure PauseFor(const AMinutesToPause: Integer);
    procedure ProcessPendingLock;
    procedure ShowForm;
    procedure StartSavingScreen;
    procedure StopSavingScreen;
    procedure UpdateLockingState;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  end;

var
  OLBMainForm: TOLBMainForm;

implementation

uses
  System.DateUtils, System.Math, OBSUnit.Utils, OLBForm.Settings;

{$R *.dfm}

procedure TOLBMainForm.ActionCloseExecute(ASender: TObject);
begin
  Close;
end;

procedure TOLBMainForm.ActionSettingsExecute(ASender: TObject);
begin
  if not Assigned(OLBSettingsForm) then
    if TOLBSettingsForm.ClassShowModal(Self, FSettings) = mrOk then
    begin
      WriteSettings(FSettingsFullFilename, FSettings);
      ApplySettings; // Re-read the cached, derived values so changes take effect without a restart
    end;
end;

procedure TOLBMainForm.ActionStopSavingScreenExecute(ASender: TObject);
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

procedure TOLBMainForm.ApplySettings;
begin
  // (Re)build the state derived from FSettings. Safe to call again whenever the settings change.
  FMouseDistance := TMouseDistance.Create(FSettings.MouseMoveResetTime);

  CalculateIdleMouseMoveDistanceAndTime;
end;

procedure TOLBMainForm.CalculateIdleMouseMoveDistanceAndTime;
const
  MOUSE_MOVE_GRANULARITY = 10;
  // Nudge the mouse a few times per reset window so accumulated jitter never trips the reset timeout.
  MOUSE_MOVES_PER_RESET_TIME = 3;
begin
  FMaxIdleMoveDistance := Round(FSettings.MouseMoveDistance / MOUSE_MOVE_GRANULARITY);
  FMinIdleMouseMoveInterval := FSettings.MouseMoveResetTime / MOUSE_MOVES_PER_RESET_TIME;
  FIdleWatch := TStopwatch.Create;

  FIdleWatch.Stop;
  FIdleWatch.Reset;
end;

procedure TOLBMainForm.CreateParams(var AParams: TCreateParams);
begin
  inherited;

  AParams.ExStyle := AParams.ExStyle and not WS_EX_APPWINDOW;
  AParams.WndParent := Application.Handle;
end;

procedure TOLBMainForm.FormClose(ASender: TObject; var AAction: TCloseAction);
begin
  SystemCritical.Stop;
end;

procedure TOLBMainForm.FormCreate(ASender: TObject);
begin
  Randomize; // So GetRandomMouseInput does not produce the same jitter sequence every launch

  FPauseUntil := 0.00;

  LabelDebug.Visible := {$IFDEF DEBUG}True{$ELSE}False{$ENDIF};
  Visible := LabelDebug.Visible;

  LoadSettings(FSettingsFullFilename, FSettings);
  ApplySettings; // Must run after LoadSettings so FMouseDistance uses the loaded MouseMoveResetTime

  UpdateLockingState; // Set the initial "prevent locking" state from the (possibly scheduled) settings
end;

procedure TOLBMainForm.FormKeyUp(ASender: TObject; var AKey: Word; AShift: TShiftState);
begin
  if (AShift = []) and (AKey in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'), VK_SPACE]) then
    ActionStopSavingScreen.Execute
  else if (AShift = [ssCtrl]) and (AKey in [Ord('x'), Ord('z'), Ord('X'), Ord('Z')]) then
    ActionStopSavingScreen.Execute;
end;

procedure TOLBMainForm.FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Integer);
begin
  if FMouseDistance.AddCoordinate(AX, AY) > FSettings.MouseMoveDistance then
    StopSavingScreen;
end;

procedure TOLBMainForm.FormMouseUp(ASender: TObject; AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
begin
  if AButton = mbRight then
    PopupMenuTrayIcon.Popup(AX, AY)
  else
    StopSavingScreen;
end;

function TOLBMainForm.GetRandomMouseInput: TInput;
const
  MAX_MOVE_FRACTION = 8; // Keep each nudge to roughly an eighth of the max idle distance
begin
  FillChar(Result, SizeOf(TInput), 0);

  var LMaxMoveDistance := FMaxIdleMoveDistance div MAX_MOVE_FRACTION;

  Result.Itype := INPUT_MOUSE;
  Result.mi.dwFlags := MOUSEEVENTF_MOVE;
  Result.mi.dx := RandomRange(-LMaxMoveDistance, LMaxMoveDistance);
  Result.mi.dy := RandomRange(-LMaxMoveDistance, LMaxMoveDistance);
  Result.mi.time := GetTickCount;
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

procedure TOLBMainForm.MenuItemPauseClick(ASender: TObject);
begin
  if ASender is TMenuItem then
  begin
    var LMenuItem := ASender as TMenuItem;

    if LMenuItem.Tag > 0 then
    begin
      // AutoCheck has already toggled this item; capture that, then clear every item so the
      // durations behave like a radio group (only the clicked one can stay checked).
      var LWasChecked := LMenuItem.Checked;

      GetRidOfCheckedPauseMenu;

      if LWasChecked then
      begin
        LMenuItem.Checked := True;
        PauseFor(LMenuItem.Tag);
      end
      else
        PauseFor(0);
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
  FSavingScreen := True;
end;

procedure TOLBMainForm.StopSavingScreen;
begin
  HideForm;

  FPauseUntil := 0.00;

  FMouseDistance.Clear;
  FSavingScreen := False;
end;

procedure TOLBMainForm.ProcessPendingLock;
begin
  if not FPendingLock then
    Exit;

  // Avoid locking mid-action: only lock once the user is clearly idle. If the screen
  // saver is already up they have been idle at least UserIdleTime; otherwise wait for
  // the configured number of seconds without real mouse/keyboard input.
  if FSavingScreen or (GetSecondsSinceLastInput >= FSettings.LockIdleSeconds) then
  begin
    FPendingLock := False;

    if not LockWorkStation then
      AddDebugLine('LockWorkStation failed: ' + SysErrorMessage(GetLastError));
  end;
end;

procedure TOLBMainForm.UpdateLockingState;
var
  LShouldBlock: Boolean;
begin
  // The schedule governs only whether we keep the computer from locking; the
  // screen-saving (black screen) feature is intentionally left untouched.
  LShouldBlock := FSettings.BlocksLockingAt(Now);

  if LShouldBlock then
    SystemCritical.Start
  else
    SystemCritical.Stop;

  // The moment the no-lock window ends, optionally arm a lock. Re-entering a window
  // cancels a pending lock so we never lock while we are supposed to stay awake.
  if LShouldBlock then
    FPendingLock := False
  else if FLockingBlocked and FSettings.LockWhenScheduleEnds then
    FPendingLock := True;

  FLockingBlocked := LShouldBlock;

  AddDebugLine('Blocking locking: ' + BoolToStr(LShouldBlock, True));
end;

procedure TOLBMainForm.TimerAfterShowTimer(ASender: TObject);
begin
  TimerAfterShow.Enabled := False;

  StopSavingScreen;

  {$IFDEF DEBUG}
  ShowForm;
  Left := Round(Screen.MonitorFromWindow(Handle).Width * 0.07);
  Top := Round(Screen.MonitorFromWindow(Handle).Height * 0.07);
  {$ENDIF};

  FIdleWatch.Stop;
  FIdleWatch.Reset;
end;

procedure TOLBMainForm.TimerTimer(ASender: TObject);
begin
  AddDebugLine('', True);

  UpdateLockingState; // Keep the "prevent locking" state in sync with the schedule, independent of screen saving
  ProcessPendingLock; // Lock the workstation once the no-lock window has ended and the user is idle

  if TimerAfterShow.Enabled then
    Exit;

  if not IsZero(FPauseUntil) and (Now > FPauseUntil) then
  begin
    GetRidOfCheckedPauseMenu;
    FPauseUntil := 0.00;
  end;

  if FSavingScreen then
  begin
    if not FIdleWatch.IsRunning then
      FIdleWatch := TStopwatch.StartNew;

    if FIdleWatch.Elapsed.TotalSeconds > FMinIdleMouseMoveInterval then
    begin
      var LInput := GetRandomMouseInput;

      if SendInput(1, LInput, SizeOf(TInput)) = 1 then
      begin
        FMouseDistance.SubtractMouseOffset(LInput.mi.dx, LInput.mi.dy);

        {$IFDEF DEBUG}
        LabelDebug.Caption := 'Move mouse: X=' + LInput.mi.dx.ToString + ' Y=' + LInput.mi.dy.ToString;
        {$ENDIF}
      end;

      FIdleWatch := TStopwatch.StartNew;
    end;
  end
  else
  begin
    if IsZero(FPauseUntil) then
    begin
      var LTimeToScreenSaving := FSettings.UserIdleTime - GetSecondsSinceLastInput;

      if LTimeToScreenSaving <= 0 then
      begin
        StartSavingScreen;

        AddDebugLine('Saving screen...');
      end
      else
        AddDebugLine('Time to saving screen: ' + LTimeToScreenSaving.ToString);
    end
    {$IFDEF DEBUG}
    else
    begin
      var LPauseTimeLeft: TDateTime := FPauseUntil - Now;

      AddDebugLine('Paused...');
      AddDebugLine('  - Paused for ' + TimeToStr(LPauseTimeLeft));
    end;
    {$ENDIF}
  end;
end;

procedure TOLBMainForm.TrayIconDblClick(ASender: TObject);
begin
  ActionSettings.Execute;
end;

end.

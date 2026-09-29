unit OLBForm.Main;

interface

uses
  Winapi.Messages, Winapi.Windows, System.Actions, System.Classes, System.Diagnostics, System.Generics.Collections,
  System.ImageList, System.SysUtils, System.Types, System.Variants, System.Win.TaskbarCore, Vcl.ActnList,
  Vcl.BaseImageCollection, Vcl.Controls, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.ImgList, Vcl.StdActns,
  Vcl.Taskbar, Vcl.VirtualImageList, OBSUnit.InputHook, OBSUnit.SystemCritical, OBSUnit.Types, OLBForm.Cover,
  SVGIconImageCollection, SVGIconVirtualImageList, Vcl.ImageCollection, Vcl.Menus, Vcl.StdCtrls;

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
    procedure FormDestroy(ASender: TObject);
    procedure FormKeyUp(ASender: TObject; var AKey: Word; AShift: TShiftState);
    procedure FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Integer);
    procedure FormMouseUp(ASender: TObject; AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
    procedure MenuItemPauseClick(ASender: TObject);
    procedure TimerAfterShowTimer(ASender: TObject);
    procedure TimerTimer(ASender: TObject);
    procedure TrayIconDblClick(ASender: TObject);
  strict private
    FCovers: TList<TOLBCoverForm>;
    FDisplayChanged: Boolean;
    FIdleWatch: TStopwatch;
    FInputCaptured: Boolean;
    FLockingBlocked: Boolean;
    FMaxIdleMoveDistance: Integer;
    FMinIdleMouseMoveInterval: Double; // Seconds
    FMouseDistance: TMouseDistance;
    FPauseUntil: TDateTime;
    FPendingLock: Boolean;
    FSavingScreen: Boolean;
    FSettings: TSettings;
    FSettingsFullFilename: string;
    function GetCoverRect(const AMonitor: TMonitor): TRect;
    function GetRandomMouseInput: TInput;
    procedure AddDebugLine(const ADebugLine: string; const AClear: Boolean = False);
    procedure ApplySettings;
    procedure CalculateIdleMouseMoveDistanceAndTime;
    procedure GetRidOfCheckedPauseMenu;
    procedure HideCovers;
    procedure LockComputer;
    procedure PauseFor(const AMinutesToPause: Integer);
    procedure ProcessPendingLock;
    procedure SetCoversCursor(const ACursor: TCursor);
    procedure SetUpMainWindow;
    procedure ShowCovers;
    procedure StartInputCaptureOrFallBack;
    procedure StartSavingScreen;
    procedure StopSavingScreen;
    procedure UpdateLockingState;
    procedure WMDisplayChange(var AMessage: TMessage); message WM_DISPLAYCHANGE;
    procedure WMInputHookIdle(var AMessage: TMessage); message WM_OBS_INPUT_HOOK_IDLE;
    procedure WMUserInput(var AMessage: TMessage); message WM_OBS_USER_INPUT;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  end;

var
  OLBMainForm: TOLBMainForm;

implementation

uses
  System.DateUtils, System.Math, System.UITypes, OBSUnit.Utils, OLBForm.Settings;

{$R *.dfm}

procedure TOLBMainForm.ActionCloseExecute(ASender: TObject);
begin
  Close;
end;

procedure TOLBMainForm.ActionSettingsExecute(ASender: TObject);
begin
  if Assigned(OLBSettingsForm) then
    Exit;

  // The dialog is not topmost, so it would open hidden behind the black screen, and while it is modal
  // the (disabled) black screen gets no mouse input to dismiss it.
  if FSavingScreen then
    StopSavingScreen;

  if TOLBSettingsForm.ClassShowModal(Self, FSettings) = mrOk then
  begin
    ApplySettings; // Re-read the cached, derived values so changes take effect without a restart, even if saving fails
    WriteSettings(FSettingsFullFilename, FSettings);
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
  StopInputCapture;
  SystemCritical.Stop;
end;

procedure TOLBMainForm.FormCreate(ASender: TObject);
var
  LDefaultSettings: TSettings;
begin
  Randomize; // So GetRandomMouseInput does not produce the same jitter sequence every launch

  FCovers := TList<TOLBCoverForm>.Create; // The covers themselves are owned (and freed) by the form
  FPauseUntil := 0.00;

  LabelDebug.Visible := {$IFDEF DEBUG}True{$ELSE}False{$ENDIF};
  Visible := LabelDebug.Visible;

  try
    LoadSettings(FSettingsFullFilename, FSettings);
  except
    on E: Exception do
    begin
      // A broken settings file must not abort FormCreate half-way (ApplySettings would never run);
      // fall back to the defaults, a later save from the settings dialog overwrites the broken file.
      FSettings := LDefaultSettings;

      MessageDlg(Format('Could not read the settings from "%s", using the defaults.%s%s',
        [FSettingsFullFilename, sLineBreak + sLineBreak, E.Message]), mtWarning, [mbOK], 0);
    end;
  end;

  ApplySettings; // Must run after LoadSettings so FMouseDistance uses the loaded MouseMoveResetTime

  UpdateLockingState; // Set the initial "prevent locking" state from the (possibly scheduled) settings
end;

procedure TOLBMainForm.FormDestroy(ASender: TObject);
begin
  FCovers.Free;
end;

procedure TOLBMainForm.FormKeyUp(ASender: TObject; var AKey: Word; AShift: TShiftState);
begin
  // Normally the input hook handles keys (see WMUserInput); this only runs when it could not be installed
  // and the black screen took the focus instead, or for the Debug window.
  if GetKeyKind(AKey) = kkKey then
  begin
    ActionStopSavingScreen.Execute;
  end;
end;

procedure TOLBMainForm.FormMouseMove(ASender: TObject; AShift: TShiftState; AX, AY: Integer);
begin
  if not FSavingScreen then
    Exit;

  // Screen coordinates, so a move from one monitor's cover onto the next adds up correctly
  var LScreenPoint := (ASender as TControl).ClientToScreen(Point(AX, AY));

  if FMouseDistance.AddCoordinate(LScreenPoint.X, LScreenPoint.Y) > FSettings.MouseMoveDistance then
    StopSavingScreen;
end;

procedure TOLBMainForm.FormMouseUp(ASender: TObject; AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
begin
  if AButton = mbRight then
  begin
    var LScreenPoint := (ASender as TControl).ClientToScreen(Point(AX, AY)); // Popup wants screen coordinates

    // The menu must get the keys while it is open, and like a tray menu it needs our application in the
    // foreground to close properly when clicking elsewhere.
    StopInputCapture;
    try
      SetForegroundWindow(Application.Handle);
      PopupMenuTrayIcon.Popup(LScreenPoint.X, LScreenPoint.Y);
    finally
      if FSavingScreen then
        StartInputCaptureOrFallBack;
    end;
  end
  else
    StopSavingScreen;
end;

function TOLBMainForm.GetCoverRect(const AMonitor: TMonitor): TRect;
begin
  Result := AMonitor.BoundsRect; // The whole monitor, taskbar included: it must not stay lit either

  {$IFDEF DEBUG}
  // Debug: a third of each monitor in its bottom-right corner, so the desktop stays usable while testing
  const LMargin = 64;

  Result := Rect(Result.Right - AMonitor.Width div 3 - LMargin, Result.Bottom - AMonitor.Height div 3 - LMargin,
    Result.Right - LMargin, Result.Bottom - LMargin);
  {$ENDIF}
end;

function TOLBMainForm.GetRandomMouseInput: TInput;
const
  MAX_MOVE_FRACTION = 8; // Keep each nudge to roughly an eighth of the max idle distance
begin
  FillChar(Result, SizeOf(TInput), 0);

  // At least one pixel, so a small MouseMoveDistance does not turn every nudge into a zero move
  var LMaxMoveDistance := Max(FMaxIdleMoveDistance div MAX_MOVE_FRACTION, 1);

  Result.Itype := INPUT_MOUSE;
  Result.mi.dwFlags := MOUSEEVENTF_MOVE;
  // RandomRange excludes the upper bound; without the + 1 the cursor slowly drifts up and left
  Result.mi.dx := RandomRange(-LMaxMoveDistance, LMaxMoveDistance + 1);
  Result.mi.dy := RandomRange(-LMaxMoveDistance, LMaxMoveDistance + 1);
  Result.mi.time := GetTickCount;
end;

procedure TOLBMainForm.GetRidOfCheckedPauseMenu;
begin
  for var LIndex := 0 to MenuItemPause.Count - 1 do
    if MenuItemPause.Items[LIndex].Checked then
      MenuItemPause.Items[LIndex].Checked := False;
end;

procedure TOLBMainForm.HideCovers;
begin
  for var LCover in FCovers do
    LCover.HideCover;
end;

procedure TOLBMainForm.LockComputer;
begin
  if not LockWorkStation then
    AddDebugLine('LockWorkStation failed: ' + SysErrorMessage(GetLastError));
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
  begin
    FPauseUntil := IncMinute(Now, AMinutesToPause);

    // Picked from the black screen's own right-click menu: pausing means "give me the screen back"
    if FSavingScreen then
      StopSavingScreen;
  end
  else
    FPauseUntil := 0.00;
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

    LockComputer;
  end;
end;

procedure TOLBMainForm.SetCoversCursor(const ACursor: TCursor);
begin
  for var LCover in FCovers do
    LCover.Cursor := ACursor; // Takes effect at once when the mouse is over the cover (CM_CURSORCHANGED)
end;

procedure TOLBMainForm.SetUpMainWindow;
begin
  // The main form is never the black screen itself, the per-monitor covers are.
  {$IFDEF DEBUG}
  // Debug: a small stay-on-top window that shows the debug lines
  BorderStyle := bsNone;
  WindowState := TWindowState.wsNormal;
  FormStyle := fsStayOnTop;
  Visible := True;
  AlphaBlendValue := 255;
  AlphaBlend := False;
  Left := Round(Screen.MonitorFromWindow(Handle).Width * 0.07);
  Top := Round(Screen.MonitorFromWindow(Handle).Height * 0.07);
  {$ELSE}
  // Release: never shown
  AlphaBlendValue := 0;
  AlphaBlend := True;
  WindowState := TWindowState.wsMinimized;
  Visible := False;
  ShowWindow(Handle, SW_HIDE);
  {$ENDIF}
end;

procedure TOLBMainForm.ShowCovers;
begin
  // Monitors can come and go between two black screens (VCL refreshes Screen.Monitors on WM_DISPLAYCHANGE),
  // so keep exactly one cover per monitor. Never called from a cover's own event handler, so Free is safe.
  while FCovers.Count > Screen.MonitorCount do
  begin
    FCovers.Last.Free;
    FCovers.Delete(FCovers.Count - 1);
  end;

  while FCovers.Count < Screen.MonitorCount do
  begin
    var LCover := TOLBCoverForm.Create(Self);

    LCover.OnKeyUp := FormKeyUp;
    LCover.OnMouseMove := FormMouseMove;
    LCover.OnMouseUp := FormMouseUp;

    FCovers.Add(LCover);
  end;

  for var LIndex := 0 to FCovers.Count - 1 do
    FCovers[LIndex].ShowCover(GetCoverRect(Screen.Monitors[LIndex]));
end;

procedure TOLBMainForm.StartInputCaptureOrFallBack;
begin
  FInputCaptured := StartInputCapture(Handle);

  if not FInputCaptured then
  begin
    AddDebugLine('Could not install the input hooks: ' + SysErrorMessage(GetLastError));

    // Fallback: take the focus, so FormKeyUp at least sees the keys. The cursor stays visible, because
    // without the mouse hook a real mouse move cannot be told apart from our own nudges.
    if FCovers.Count > 0 then
      SetForegroundWindow(FCovers.First.Handle);
  end;
end;

procedure TOLBMainForm.StartSavingScreen;
begin
  FMouseDistance.Clear;
  FSavingScreen := True;

  ShowCovers;
  StartInputCaptureOrFallBack;

  // Hide the cursor until the user is back (WMUserInput shows it again on the first real mouse or key input)
  if FInputCaptured then
    SetCoversCursor(crNone)
  else
    SetCoversCursor(crDefault);
end;

procedure TOLBMainForm.StopSavingScreen;
begin
  StopInputCapture;
  HideCovers;
  // Back to default while hidden, so the next StartSavingScreen's crNone is a real change and VCL applies it
  // at once (setting the same Cursor value again does nothing, and the cursor would stay until moved).
  SetCoversCursor(crDefault);

  FMouseDistance.Clear;
  FSavingScreen := False;
end;

procedure TOLBMainForm.UpdateLockingState;
var
  LShouldBlock: Boolean;
begin
  // The schedule governs whether we keep the computer from locking. The black screen still shows
  // outside the window, but TimerTimer stops its mouse nudges there so Windows can lock too.
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

  SetUpMainWindow;

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
    // A monitor was added, removed or changed while the black screen is up. Handled here, a tick later,
    // because VCL refreshes Screen.Monitors on its own WM_DISPLAYCHANGE, which may come after ours.
    if FDisplayChanged then
    begin
      FDisplayChanged := False;
      ShowCovers;
    end;

    // Windows silently drops a low-level hook that does not answer in time (e.g. the process sat at a
    // breakpoint), after which keys would no longer end the black screen. Fresh hooks each tick undo that.
    if FInputCaptured then
      RenewInputCapture;

    if not FIdleWatch.IsRunning then
      FIdleWatch := TStopwatch.StartNew;

    // The mouse nudges exist only to keep Windows from locking. Outside the no-lock window they
    // must stop, or they reset Windows' own idle timer and the computer never locks behind the black screen.
    if FLockingBlocked and (FIdleWatch.Elapsed.TotalSeconds > FMinIdleMouseMoveInterval) then
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

      // Never cover an open modal dialog (settings, message box): the black screen is disabled then,
      // so mouse moves could not dismiss it and the dialog would be stuck invisible behind it.
      if Application.ModalLevel > 0 then
        AddDebugLine('Modal dialog open, not saving screen')
      else if LTimeToScreenSaving <= 0 then
      begin
        StartSavingScreen;

        AddDebugLine('Saving screen...');

        // Once today's no-lock window is over, going idle locks the computer as well. This covers being
        // unlocked again after the end-of-window lock, and starting (or waking) the computer after the window.
        if FSettings.LockWhenScheduleEnds and FSettings.ScheduleEndedEarlierToday(Now) then
          LockComputer;
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

procedure TOLBMainForm.WMDisplayChange(var AMessage: TMessage);
begin
  inherited;

  FDisplayChanged := True;
end;

procedure TOLBMainForm.WMInputHookIdle(var AMessage: TMessage);
begin
  ReleaseIdleInputHook;
end;

procedure TOLBMainForm.WMUserInput(var AMessage: TMessage);
begin
  if not FSavingScreen then
    Exit;

  // The user is back: show the cursor again. Any key other than Shift/Ctrl/Alt/Win also ends the black screen
  // (the hook has already swallowed it, so it never reaches the application underneath).
  SetCoversCursor(crDefault);

  if TUserInputKind(AMessage.WParam) = uikKey then
    StopSavingScreen;
end;

end.

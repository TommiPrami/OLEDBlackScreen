unit OBSUnit.InputHook;

{
  Low-level keyboard and mouse hooks used while the black screen is showing.

  The black screen never takes the keyboard focus (that would pull focus away from the application the user was
  working in), so without these hooks a key pressed to dismiss it would be typed into that hidden application.
  While capturing, real (not injected) key presses are swallowed and reported to the notify window instead.
  Real mouse input is only reported (once per capture), never swallowed, so the cursor can be shown again.

  Windows silently removes a low-level hook that does not answer in time, e.g. while the process is paused in
  the debugger. There is no notification, so RenewInputCapture replaces the hooks regularly while capturing.
}

interface

uses
  Winapi.Messages, Winapi.Windows;

const
  // Posted to the notify window: WParam = Ord(TUserInputKind), LParam = virtual-key code for key input
  WM_OBS_USER_INPUT = WM_APP + 100;
  // Posted once capturing has ended and every swallowed key has been released: call ReleaseIdleInputHook
  WM_OBS_INPUT_HOOK_IDLE = WM_APP + 101;

type
  TUserInputKind = (uikMouse, uikModifierKey, uikKey);

  TKeyKind = (kkKey, kkModifier, kkPassThrough);

  TKeyEventAction = (keaPass, keaSwallow, keaSwallowAndReport);

  // The keyboard hook's bookkeeping, kept apart from the hook itself so it can be unit tested.
  TKeyCaptureState = record
  strict private
    FCapturing: Boolean;
    FSwallowedKeys: array[Byte] of Boolean;
  public
    // Starts capturing and forgets keys swallowed earlier (their release may never have been seen)
    procedure BeginCapture;
    procedure EndCapture;
    function HasSwallowedKeys: Boolean;
    // What to do with a real (not injected) key event
    function KeyEvent(const AVirtualKey: Cardinal; const AKeyDown: Boolean): TKeyEventAction;
    property Capturing: Boolean read FCapturing;
  end;

  // Shift/Ctrl/Alt/Win are modifiers; media, volume and browser keys pass straight through (they are global
  // hot keys and do not type anything); everything else is an ordinary key.
  function GetKeyKind(const AVirtualKey: Cardinal): TKeyKind;

  // Starts swallowing and reporting input with freshly installed hooks. Returns False if they could not be installed.
  function StartInputCapture(const ANotifyWindow: HWND): Boolean;
  // Replaces the hooks while capturing, in case Windows has silently removed them. Call regularly (every tick).
  procedure RenewInputCapture;
  // Stops swallowing new key presses. The keyboard hook stays until the keys it swallowed are released, so the
  // application underneath never sees a lone key-up (a lone Alt or Win key-up can open a menu).
  procedure StopInputCapture;
  // Removes the keyboard hook once it has nothing left to do. Call on WM_OBS_INPUT_HOOK_IDLE.
  procedure ReleaseIdleInputHook;

implementation

type
  // Not declared in Winapi.Windows
  TKbdLLHookStruct = record
    vkCode: DWORD;
    scanCode: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  PKbdLLHookStruct = ^TKbdLLHookStruct;

  TMsLLHookStruct = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  PMsLLHookStruct = ^TMsLLHookStruct;

const
  LLKHF_INJECTED = $00000010;
  LLMHF_INJECTED = $00000001;

var
  KeyCapture: TKeyCaptureState;
  KeyboardHook: HHOOK;
  MouseHook: HHOOK;
  MouseReported: Boolean;
  NotifyWindow: HWND;

function GetKeyKind(const AVirtualKey: Cardinal): TKeyKind;
begin
  case AVirtualKey of
    VK_SHIFT, VK_CONTROL, VK_MENU, VK_LWIN, VK_RWIN, VK_LSHIFT, VK_RSHIFT, VK_LCONTROL, VK_RCONTROL, VK_LMENU,
    VK_RMENU:
      Result := kkModifier;
    VK_BROWSER_BACK..VK_LAUNCH_APP2:
      Result := kkPassThrough;
  else
    Result := kkKey;
  end;
end;

{ TKeyCaptureState }

procedure TKeyCaptureState.BeginCapture;
begin
  FillChar(FSwallowedKeys, SizeOf(FSwallowedKeys), 0);
  FCapturing := True;
end;

procedure TKeyCaptureState.EndCapture;
begin
  FCapturing := False;
end;

function TKeyCaptureState.HasSwallowedKeys: Boolean;
begin
  for var LKey := Low(FSwallowedKeys) to High(FSwallowedKeys) do
    if FSwallowedKeys[LKey] then
      Exit(True);

  Result := False;
end;

function TKeyCaptureState.KeyEvent(const AVirtualKey: Cardinal; const AKeyDown: Boolean): TKeyEventAction;
begin
  Result := keaPass;

  if (AVirtualKey > High(Byte)) or (GetKeyKind(AVirtualKey) = kkPassThrough) then
    Exit;

  var LKey := Byte(AVirtualKey);

  if AKeyDown then
  begin
    // An already swallowed key going down again is auto-repeat: keep swallowing it even after capturing
    // ended, or holding the key that dismissed the black screen would type into the application underneath.
    if FCapturing or FSwallowedKeys[LKey] then
    begin
      if FCapturing and not FSwallowedKeys[LKey] then
        Result := keaSwallowAndReport
      else
        Result := keaSwallow;

      FSwallowedKeys[LKey] := True;
    end;
  end
  else if FSwallowedKeys[LKey] then
  begin
    FSwallowedKeys[LKey] := False;
    Result := keaSwallow;
  end;
end;

{ Hooks }

function KeyboardHookProc(ACode: Integer; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  LKeyInfo: PKbdLLHookStruct;
begin
  if ACode = HC_ACTION then
  begin
    LKeyInfo := PKbdLLHookStruct(ALParam);

    if LKeyInfo.flags and LLKHF_INJECTED = 0 then
      case KeyCapture.KeyEvent(LKeyInfo.vkCode, (AWParam = WM_KEYDOWN) or (AWParam = WM_SYSKEYDOWN)) of
        keaSwallowAndReport:
          begin
            if GetKeyKind(LKeyInfo.vkCode) = kkModifier then
              PostMessage(NotifyWindow, WM_OBS_USER_INPUT, Ord(uikModifierKey), LKeyInfo.vkCode)
            else
              PostMessage(NotifyWindow, WM_OBS_USER_INPUT, Ord(uikKey), LKeyInfo.vkCode);

            Exit(1);
          end;
        keaSwallow:
          begin
            if not KeyCapture.Capturing and not KeyCapture.HasSwallowedKeys then
              PostMessage(NotifyWindow, WM_OBS_INPUT_HOOK_IDLE, 0, 0);

            Exit(1);
          end;
      end;
  end;

  Result := CallNextHookEx(KeyboardHook, ACode, AWParam, ALParam);
end;

function MouseHookProc(ACode: Integer; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
begin
  // Our own mouse nudges are injected, so they never count as the user being back
  if (ACode = HC_ACTION) and KeyCapture.Capturing and not MouseReported
    and (PMsLLHookStruct(ALParam).flags and LLMHF_INJECTED = 0) then
  begin
    MouseReported := True;
    PostMessage(NotifyWindow, WM_OBS_USER_INPUT, Ord(uikMouse), 0);
  end;

  Result := CallNextHookEx(MouseHook, ACode, AWParam, ALParam);
end;

// Installs a fresh hook before removing the old one, so input is never unhooked in between. Removing the
// old handle fails harmlessly when Windows has already dropped it. On failure the old hook is kept.
function ReplaceHook(const AHookId: Integer; const AHookProc: Pointer; var AHook: HHOOK): Boolean;
begin
  var LNewHook := SetWindowsHookEx(AHookId, AHookProc, HInstance, 0);

  if LNewHook = 0 then
    Exit(False);

  if AHook <> 0 then
    UnhookWindowsHookEx(AHook);

  AHook := LNewHook;
  Result := True;
end;

procedure RemoveHook(var AHook: HHOOK);
begin
  if AHook <> 0 then
  begin
    UnhookWindowsHookEx(AHook);
    AHook := 0;
  end;
end;

function StartInputCapture(const ANotifyWindow: HWND): Boolean;
begin
  NotifyWindow := ANotifyWindow;
  MouseReported := False;
  KeyCapture.BeginCapture;

  Result := ReplaceHook(WH_KEYBOARD_LL, @KeyboardHookProc, KeyboardHook)
    and ReplaceHook(WH_MOUSE_LL, @MouseHookProc, MouseHook);

  if not Result then
    StopInputCapture;
end;

procedure RenewInputCapture;
begin
  if not KeyCapture.Capturing then
    Exit;

  ReplaceHook(WH_KEYBOARD_LL, @KeyboardHookProc, KeyboardHook);
  ReplaceHook(WH_MOUSE_LL, @MouseHookProc, MouseHook);
end;

procedure StopInputCapture;
begin
  KeyCapture.EndCapture;
  RemoveHook(MouseHook);

  ReleaseIdleInputHook;
end;

procedure ReleaseIdleInputHook;
begin
  if not KeyCapture.Capturing and not KeyCapture.HasSwallowedKeys then
    RemoveHook(KeyboardHook);
end;

initialization

finalization
  KeyCapture.EndCapture;
  RemoveHook(MouseHook);
  RemoveHook(KeyboardHook);

end.

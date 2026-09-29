unit OBSUnit.SystemCritical;

interface

uses
  Winapi.Windows;

type
  TSystemCritical = class
  private
    FIsCritical: Boolean;
    procedure SetIsCritical(const Value: Boolean) ;
  protected
    procedure UpdateCritical(Value: Boolean) ; virtual;
  public
    constructor Create;
    property IsCritical: Boolean read FIsCritical write SetIsCritical;
    procedure Start;
    procedure Stop;
  end;

  function SystemCritical: TSystemCritical;

implementation

uses
  System.SysUtils;

var
  SystemCriticalSingleton: TSystemCritical;

function SystemCritical: TSystemCritical;
begin
  if not Assigned(SystemCriticalSingleton) then
    SystemCriticalSingleton := TSystemCritical.Create;

  Result := SystemCriticalSingleton;
end;

{ TSystemCritical }

// SetThreadExecutionState and the ES_* flags come from Winapi.Windows.
// REF: https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate

constructor TSystemCritical.Create;
begin
  inherited;

  FIsCritical := False;
end;

procedure TSystemCritical.SetIsCritical(const Value: Boolean) ;
begin
  if FIsCritical = Value then
    Exit;

  FIsCritical := Value;
  UpdateCritical(FIsCritical);
end;

procedure TSystemCritical.Start;
begin
  if not FIsCritical then
    IsCritical := True;
end;

procedure TSystemCritical.Stop;
begin
  if FIsCritical then
    IsCritical := False;
end;

procedure TSystemCritical.UpdateCritical(Value: Boolean) ;
begin
  if Value then
  begin
    // Prevent the sleep idle time-out and Power off.
    SetThreadExecutionState(ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED or ES_CONTINUOUS);
  end
  else
  begin
    // Clear EXECUTION_STATE flags to disable away mode and allow the
    // system to idle to sleep normally.
    SetThreadExecutionState(ES_CONTINUOUS);
  end;
end;

initialization
  SystemCriticalSingleton := nil;

finalization
  if Assigned(SystemCriticalSingleton) then
  begin
    SystemCriticalSingleton.Stop;
    FreeAndNil(SystemCriticalSingleton);
  end;
end.

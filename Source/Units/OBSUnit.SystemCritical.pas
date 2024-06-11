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

// REF: https://msdn.microsoft.com/en-us/library/aa373208.aspx
type
  EXECUTION_STATE = DWORD;

const
  ES_SYSTEM_REQUIRED = $00000001;
  ES_DISPLAY_REQUIRED = $00000002;
  ES_USER_PRESENT = $00000004;
  ES_AWAYMODE_REQUIRED = $00000040;
  ES_CONTINUOUS = $80000000;

  KernelDLL = 'kernel32.dll';

{
  SetThreadExecutionState Function
  Enables an application to inform the system that it is in use,
  thereby preventing the system from entering sleep or turning off the
  display while the application is running.
}
procedure SetThreadExecutionState(ESFlags: EXECUTION_STATE); stdcall; external kernel32 name 'SetThreadExecutionState';

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

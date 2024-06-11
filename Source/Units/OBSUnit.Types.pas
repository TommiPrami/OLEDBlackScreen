unit OBSUnit.Types;

interface

uses
  System.Diagnostics;

const
  SETTINGS_SUB_DIR = 'OLEDBlaskScreen';
  SETTINGS_FILENAME = SETTINGS_SUB_DIR + 'Settings.json';

type
  TMouseDistance = record
  strict private
    MouseMoveResetTime: Integer;
  public
    IdleMouseDistance: Double;
    LastX: Integer;
    LastY: Integer;
    MouseStopWatch: TStopWatch;

    constructor Create(const AMouseMoveResetTime: Integer);
    procedure Clear;
    procedure ResetTimeout;
    function AddCoordinate(const AX, AY: Integer): Double;
  end;

  TSettings = record
    MouseMoveDistance: Double;// In pixels
    UserIdleTime: Integer; // Seconds
    MouseMoveResetTime: Integer; // Seconds

    class operator Initialize(out ADest: TSettings);
  end;

implementation

{ TMouseDistance }

function TMouseDistance.AddCoordinate(const AX, AY: Integer): Double;
begin
  if (LastX = 0) and (LastY = 0) then
  begin
    MouseStopWatch.Start;
    LastX := AX;
    LastY := AY;
  end
  else
  begin
    if MouseStopWatch.Elapsed.TotalSeconds > MouseMoveResetTime then
      Clear
    else
    begin
      IdleMouseDistance := IdleMouseDistance + Abs(Sqrt(Sqr(Ax - LastX) + Sqr(AY - LastY)));

      LastX := AX;
      LastY := AY;
    end;
  end;

  Result := IdleMouseDistance;
end;

procedure TMouseDistance.Clear;
begin
  IdleMouseDistance := 0.00;
  LastX := 0;
  LAstY := 0;

  ResetTimeout;
end;

constructor TMouseDistance.Create(const AMouseMoveResetTime: Integer);
begin
  Clear;

  MouseMoveResetTime := AMouseMoveResetTime;
end;

procedure TMouseDistance.ResetTimeout;
begin
  MouseStopWatch.Stop;
  MouseStopWatch.Reset;
end;

{ TSettings }

class operator TSettings.Initialize(out ADest: TSettings);
begin
  ADest.MouseMoveDistance := 300;
  ADest.UserIdleTime := 120;
  ADest.MouseMoveResetTime := 10;
end;

end.

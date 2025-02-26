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
    SubtractMouseDistance: Double;
    IdleMouseDistance: Double;
    LastX: Integer;
    LastY: Integer;
    MouseStopWatch: TStopWatch;
    function CalculateDistance(const AX, AY, ALastX, ALastY: Integer): Double;
  public
    constructor Create(const AMouseMoveResetTime: Integer);
    procedure Clear;
    procedure ResetTimeout;
    function AddCoordinate(const AX, AY: Integer): Double;
    procedure SubtractMouseOffset(const ADeltaX, ADeltaY: Integer);
  end;

  TSettings = record
    MouseMoveDistance: Double;// In pixels
    UserIdleTime: Integer; // Seconds
    MouseMoveResetTime: Integer; // Seconds

    class operator Initialize(out ADest: TSettings);
  end;

implementation

uses
  System.Math;


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
      IdleMouseDistance := IdleMouseDistance + CalculateDistance(AX, AY, LastX, LastY);

      LastX := AX;
      LastY := AY;
    end;
  end;

  Result := Max(IdleMouseDistance - SubtractMOuseDistance, 0.00);
end;

function TMouseDistance.CalculateDistance(const AX, AY, ALastX, ALastY: Integer): Double;
begin
  var LLastX := ALastX;
  var LLastY := ALastY;

  Result := Abs(Sqrt(Sqr(Ax - LLastX) + Sqr(AY - LLastY)));
end;

procedure TMouseDistance.Clear;
begin
  IdleMouseDistance := 0.00;
  SubtractMouseDistance := 0.00;
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

procedure TMouseDistance.SubtractMouseOffset(const ADeltaX, ADeltaY: Integer);
begin
  SubtractMouseDistance := SubtractMouseDistance + CalculateDistance(ADeltaX, ADeltaY,  0, 0);
end;

{ TSettings }

class operator TSettings.Initialize(out ADest: TSettings);
begin
  ADest.MouseMoveDistance := 300;
  ADest.UserIdleTime := 120;
  ADest.MouseMoveResetTime := 10;
end;

end.

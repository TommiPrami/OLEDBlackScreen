unit OBSUnit.Types;

interface

uses
  System.Diagnostics;

const
  SETTINGS_SUB_DIR = 'OLEDBlackScreen';
  SETTINGS_FILENAME = 'Settings.json';

type
  TMouseDistance = record
  strict private
    IdleMouseDistance: Double;
    LastX: Integer;
    LastY: Integer;
    MouseMoveResetTime: Integer;
    MouseStopWatch: TStopWatch;
    SubtractMouseDistance: Double;
    function CalculateDistance(const AX, AY, ALastX, ALastY: Integer): Double;
  public
    constructor Create(const AMouseMoveResetTime: Integer);
    function AddCoordinate(const AX, AY: Integer): Double;
    procedure Clear;
    procedure ResetTimeout;
    procedure SubtractMouseOffset(const ADeltaX, ADeltaY: Integer);
  end;

  TWeekDay = (wdMonday, wdTuesday, wdWednesday, wdThursday, wdFriday, wdSaturday, wdSunday);
  TWeekDays = set of TWeekDay;

  TSettings = record
    MouseMoveDistance: Double; // In pixels
    UserIdleTime: Integer; // Seconds
    MouseMoveResetTime: Integer; // Seconds

    // "Prevent locking" schedule. When ScheduleDays is empty the app keeps the
    // computer from locking around the clock (legacy behaviour). When at least one
    // day is set, locking is only prevented on those days, optionally narrowed to a
    // time window. Times are minutes since midnight, or -1 when not given:
    //   - both given: block between them
    //   - only start: block from start until 23:59
    //   - only end:   block from 00:00 until end
    // The schedule never affects the screen-saving (black screen) feature.
    ScheduleDays: TWeekDays;
    ScheduleStartMinutes: Integer;
    ScheduleEndMinutes: Integer;

    // When set, the computer is locked once the no-lock window ends - but only
    // after the user has been idle for LockIdleSeconds, so it never locks mid-action.
    LockWhenScheduleEnds: Boolean;
    LockIdleSeconds: Integer;

    class operator Initialize(out ADest: TSettings);
    function BlocksLockingAt(const ADateTime: TDateTime): Boolean;
  end;

implementation

uses
  System.DateUtils, System.Math, System.SysUtils;


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

  ADest.ScheduleDays := [];
  ADest.ScheduleStartMinutes := -1;
  ADest.ScheduleEndMinutes := -1;

  ADest.LockWhenScheduleEnds := False;
  ADest.LockIdleSeconds := 30;
end;

function TSettings.BlocksLockingAt(const ADateTime: TDateTime): Boolean;
const
  LAST_MINUTE_OF_DAY = 24 * 60 - 1;
var
  LWeekDay: TWeekDay;
  LNowMinutes: Integer;
  LStartMinutes: Integer;
  LEndMinutes: Integer;
begin
  // No day selected -> keep blocking all the time, like before the schedule existed.
  if ScheduleDays = [] then
    Exit(True);

  LWeekDay := TWeekDay(DayOfTheWeek(ADateTime) - 1); // DayOfTheWeek: 1 = Monday .. 7 = Sunday

  if not (LWeekDay in ScheduleDays) then
    Exit(False);

  // A missing start/end opens that side of the window, which also covers the
  // "only one time given" cases without any special handling.
  if ScheduleStartMinutes >= 0 then
    LStartMinutes := ScheduleStartMinutes
  else
    LStartMinutes := 0;

  if ScheduleEndMinutes >= 0 then
    LEndMinutes := ScheduleEndMinutes
  else
    LEndMinutes := LAST_MINUTE_OF_DAY;

  LNowMinutes := HourOf(ADateTime) * 60 + MinuteOf(ADateTime);

  Result := (LNowMinutes >= LStartMinutes) and (LNowMinutes <= LEndMinutes);
end;

end.

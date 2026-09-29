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
    HasLastCoordinate: Boolean;
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
    //   - both given: block from start until end (end is exclusive: end 14:20 stops blocking at 14:20)
    //   - start later than end: an overnight window, from start on a scheduled day until end on the next day
    //   - only start: block from start until midnight
    //   - only end:   block from 00:00 until end
    // The black screen still shows outside the window, but it stops nudging the mouse there,
    // so Windows' own idle lock can kick in behind it.
    ScheduleDays: TWeekDays;
    ScheduleStartMinutes: Integer;
    ScheduleEndMinutes: Integer;

    // When set, the computer is locked once the no-lock window ends - but only
    // after the user has been idle for LockIdleSeconds, so it never locks mid-action.
    // For the rest of that day it is also locked whenever the black screen comes on.
    LockWhenScheduleEnds: Boolean;
    LockIdleSeconds: Integer;
  strict private
    function BlocksLockingAtMinute(const AWeekDay: TWeekDay; const AMinuteOfDay: Integer): Boolean;
  public
    class operator Initialize(out ADest: TSettings);
    function BlocksLockingAt(const ADateTime: TDateTime): Boolean;
    // True when locking is not blocked at ADateTime but was blocked earlier the same day (counting a window
    // that ran until midnight as ending at 00:00): the no-lock window is over for today.
    function ScheduleEndedEarlierToday(const ADateTime: TDateTime): Boolean;
  end;

implementation

uses
  System.DateUtils, System.Math, System.SysUtils;


{ TMouseDistance }

function TMouseDistance.AddCoordinate(const AX, AY: Integer): Double;
begin
  // A flag instead of LastX/LastY = 0, so a real move to (0, 0) is not mistaken for "no coordinate yet"
  if not HasLastCoordinate then
  begin
    HasLastCoordinate := True;
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

  Result := Max(IdleMouseDistance - SubtractMouseDistance, 0.00);
end;

function TMouseDistance.CalculateDistance(const AX, AY, ALastX, ALastY: Integer): Double;
begin
  Result := Hypot(AX - ALastX, AY - ALastY);
end;

procedure TMouseDistance.Clear;
begin
  HasLastCoordinate := False;
  IdleMouseDistance := 0.00;
  SubtractMouseDistance := 0.00;
  LastX := 0;
  LastY := 0;

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

function PreviousWeekDay(const AWeekDay: TWeekDay): TWeekDay;
begin
  if AWeekDay = Low(TWeekDay) then
    Result := High(TWeekDay)
  else
    Result := Pred(AWeekDay);
end;

function WeekDayOf(const ADateTime: TDateTime): TWeekDay;
begin
  Result := TWeekDay(DayOfTheWeek(ADateTime) - 1); // DayOfTheWeek: 1 = Monday .. 7 = Sunday
end;

function TSettings.BlocksLockingAt(const ADateTime: TDateTime): Boolean;
begin
  Result := BlocksLockingAtMinute(WeekDayOf(ADateTime), HourOf(ADateTime) * MinsPerHour + MinuteOf(ADateTime));
end;

function TSettings.BlocksLockingAtMinute(const AWeekDay: TWeekDay; const AMinuteOfDay: Integer): Boolean;
var
  LStartMinutes: Integer;
  LEndMinutes: Integer;
begin
  // No day selected -> keep blocking all the time, like before the schedule existed.
  if ScheduleDays = [] then
    Exit(True);

  // A missing start/end opens that side of the window, which also covers the
  // "only one time given" cases without any special handling.
  if ScheduleStartMinutes >= 0 then
    LStartMinutes := ScheduleStartMinutes
  else
    LStartMinutes := 0;

  if ScheduleEndMinutes >= 0 then
    LEndMinutes := ScheduleEndMinutes
  else
    LEndMinutes := MinsPerDay;

  // End is exclusive, so an end time of 14:20 lets the computer lock at 14:20:00, not at 14:21:00
  if LStartMinutes < LEndMinutes then
    Exit((AWeekDay in ScheduleDays) and (AMinuteOfDay >= LStartMinutes) and (AMinuteOfDay < LEndMinutes));

  // Overnight window: it belongs to the scheduled day it starts on and runs past midnight into the next day
  Result := ((AWeekDay in ScheduleDays) and (AMinuteOfDay >= LStartMinutes))
    or ((PreviousWeekDay(AWeekDay) in ScheduleDays) and (AMinuteOfDay < LEndMinutes));
end;

function TSettings.ScheduleEndedEarlierToday(const ADateTime: TDateTime): Boolean;
var
  LWeekDay: TWeekDay;
  LNowMinutes: Integer;
begin
  LWeekDay := WeekDayOf(ADateTime);
  LNowMinutes := HourOf(ADateTime) * MinsPerHour + MinuteOf(ADateTime);

  if BlocksLockingAtMinute(LWeekDay, LNowMinutes) then
    Exit(False);

  // A window that ran until midnight ended at 00:00 today
  if BlocksLockingAtMinute(PreviousWeekDay(LWeekDay), MinsPerDay - 1) then
    Exit(True);

  // At most one day of minutes, and only checked when the black screen comes on
  for var LMinute := 0 to LNowMinutes - 1 do
    if BlocksLockingAtMinute(LWeekDay, LMinute) then
      Exit(True);

  Result := False;
end;

end.

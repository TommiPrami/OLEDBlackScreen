unit Tests.OBSUnit.Types;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSettingsDefaultsTests = class
  public
    [Test]
    procedure Initialize_SetsExpectedDefaults;
  end;

  // TSettings.BlocksLockingAt - the "prevent locking" schedule logic.
  [TestFixture]
  TBlocksLockingTests = class
  public
    [Test]
    procedure NoDays_AlwaysBlocks;
    [Test]
    procedure MatchingDay_WithinWindow_Blocks;
    [Test]
    procedure MatchingDay_BeforeStart_DoesNotBlock;
    [Test]
    procedure MatchingDay_AfterEnd_DoesNotBlock;
    [Test]
    procedure NonMatchingDay_DoesNotBlock;
    [Test]
    procedure StartOnly_BlocksFromStartUntilEndOfDay;
    [Test]
    procedure EndOnly_BlocksFromMidnightUntilEnd;
    [Test]
    procedure NoTimes_BlocksTheWholeMatchingDay;
    [Test]
    procedure Window_StartInclusive_EndExclusive;
    [Test]
    procedure Overnight_BlocksFromStartUntilEndOnTheNextDay;
  end;

  // TSettings.ScheduleEndedEarlierToday - "the no-lock window is over for today", which re-locks on idle.
  [TestFixture]
  TScheduleEndedTests = class
  public
    [Test]
    procedure NoDays_NeverEnds;
    [Test]
    procedure BeforeAndInsideWindow_NotEnded;
    [Test]
    procedure AfterEnd_EndedForTheRestOfTheDay;
    [Test]
    procedure UnscheduledDay_NotEnded;
    [Test]
    procedure WholeDayWindow_EndsAtMidnight;
    [Test]
    procedure Overnight_EndsOnTheNextMorning;
  end;

  [TestFixture]
  TMouseDistanceTests = class
  public
    [Test]
    procedure AddCoordinate_AccumulatesEuclideanDistance;
    [Test]
    procedure AddCoordinate_OriginIsARealCoordinate;
    [Test]
    procedure SubtractMouseOffset_ReducesReportedDistance;
    [Test]
    procedure Clear_ResetsAccumulatedDistance;
  end;

implementation

uses
  System.DateUtils, OBSUnit.Types;

// 2024-01-01 is a Monday; 2024-01-06 a Saturday.
function AtMonday(const AHour, AMinute: Integer): TDateTime;
begin
  Result := EncodeDateTime(2024, 1, 1, AHour, AMinute, 0, 0);
end;

function AtSaturday(const AHour, AMinute: Integer): TDateTime;
begin
  Result := EncodeDateTime(2024, 1, 6, AHour, AMinute, 0, 0);
end;

// January 2024 starts on a Monday: day 1 = Monday .. 7 = Sunday, 8 = Monday again.
function AtJanuary(const ADay, AHour, AMinute: Integer): TDateTime;
begin
  Result := EncodeDateTime(2024, 1, ADay, AHour, AMinute, 0, 0);
end;

function WeekdaySchedule: TSettings;
begin
  Result.ScheduleDays := [wdMonday, wdTuesday, wdWednesday, wdThursday, wdFriday];
end;

function WeekdayOvernightSchedule: TSettings;
begin
  Result := WeekdaySchedule;
  Result.ScheduleStartMinutes := 22 * 60; // 22:00
  Result.ScheduleEndMinutes := 6 * 60;    // 06:00 the next day
end;

{ TSettingsDefaultsTests }

procedure TSettingsDefaultsTests.Initialize_SetsExpectedDefaults;
var
  LSettings: TSettings;
begin
  Assert.AreEqual(300.0, LSettings.MouseMoveDistance, 0.0001, 'MouseMoveDistance');
  Assert.AreEqual(120, LSettings.UserIdleTime, 'UserIdleTime');
  Assert.AreEqual(10, LSettings.MouseMoveResetTime, 'MouseMoveResetTime');
  Assert.IsTrue(LSettings.ScheduleDays = [], 'ScheduleDays should be empty');
  Assert.AreEqual(-1, LSettings.ScheduleStartMinutes, 'ScheduleStartMinutes');
  Assert.AreEqual(-1, LSettings.ScheduleEndMinutes, 'ScheduleEndMinutes');
  Assert.IsFalse(LSettings.LockWhenScheduleEnds, 'LockWhenScheduleEnds');
  Assert.AreEqual(30, LSettings.LockIdleSeconds, 'LockIdleSeconds');
end;

{ TBlocksLockingTests }

procedure TBlocksLockingTests.NoDays_AlwaysBlocks;
var
  LSettings: TSettings; // defaults: no days
begin
  Assert.IsTrue(LSettings.BlocksLockingAt(AtSaturday(3, 0)));
  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(23, 30)));
end;

procedure TBlocksLockingTests.MatchingDay_WithinWindow_Blocks;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 7 * 60;        // 07:00
  LSettings.ScheduleEndMinutes := 15 * 60 + 15;    // 15:15

  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(10, 0)));
end;

procedure TBlocksLockingTests.MatchingDay_BeforeStart_DoesNotBlock;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 7 * 60;
  LSettings.ScheduleEndMinutes := 15 * 60 + 15;

  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(6, 59)));
end;

procedure TBlocksLockingTests.MatchingDay_AfterEnd_DoesNotBlock;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 7 * 60;
  LSettings.ScheduleEndMinutes := 15 * 60 + 15;

  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(15, 16)));
end;

procedure TBlocksLockingTests.NonMatchingDay_DoesNotBlock;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule; // Mon-Fri only
  LSettings.ScheduleStartMinutes := 7 * 60;
  LSettings.ScheduleEndMinutes := 15 * 60 + 15;

  Assert.IsFalse(LSettings.BlocksLockingAt(AtSaturday(10, 0)));
end;

procedure TBlocksLockingTests.StartOnly_BlocksFromStartUntilEndOfDay;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 9 * 60; // 09:00
  LSettings.ScheduleEndMinutes := -1;       // open-ended -> until 23:59

  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(23, 59)));
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(8, 0)));
end;

procedure TBlocksLockingTests.EndOnly_BlocksFromMidnightUntilEnd;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := -1;      // open-ended -> from 00:00
  LSettings.ScheduleEndMinutes := 12 * 60;   // 12:00

  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(0, 0)));
  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(11, 59)));
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(12, 0)));
end;

procedure TBlocksLockingTests.NoTimes_BlocksTheWholeMatchingDay;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule; // no start/end -> whole day on matching days

  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(0, 0)));
  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(23, 59)));
  Assert.IsFalse(LSettings.BlocksLockingAt(AtSaturday(12, 0)));
end;

procedure TBlocksLockingTests.Window_StartInclusive_EndExclusive;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 7 * 60;      // 07:00
  LSettings.ScheduleEndMinutes := 15 * 60 + 15;  // 15:15

  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(7, 0)), 'start minute is inclusive');
  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(15, 14)), 'last blocking minute');
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(15, 15)), 'end minute is exclusive');
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(6, 59)));
end;

procedure TBlocksLockingTests.Overnight_BlocksFromStartUntilEndOnTheNextDay;
var
  LSettings: TSettings;
begin
  LSettings := WeekdayOvernightSchedule;

  Assert.IsFalse(LSettings.BlocksLockingAt(AtJanuary(1, 21, 59)), 'Monday before start');
  Assert.IsTrue(LSettings.BlocksLockingAt(AtJanuary(1, 22, 0)), 'Monday from start');
  Assert.IsTrue(LSettings.BlocksLockingAt(AtJanuary(2, 5, 59)), 'Monday''s window runs into Tuesday');
  Assert.IsFalse(LSettings.BlocksLockingAt(AtJanuary(2, 6, 0)), 'end is exclusive');
  Assert.IsTrue(LSettings.BlocksLockingAt(AtJanuary(6, 5, 59)), 'Friday''s window runs into Saturday');
  Assert.IsFalse(LSettings.BlocksLockingAt(AtJanuary(6, 22, 0)), 'no window starts on Saturday');
  Assert.IsFalse(LSettings.BlocksLockingAt(AtJanuary(8, 5, 59)), 'no window started on Sunday');
end;

{ TScheduleEndedTests }

procedure TScheduleEndedTests.NoDays_NeverEnds;
var
  LSettings: TSettings; // Defaults: no days, block around the clock
begin
  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(1, 23, 59)));
  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(6, 12, 0)));
end;

procedure TScheduleEndedTests.BeforeAndInsideWindow_NotEnded;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 6 * 60 + 25;  // 06:25
  LSettings.ScheduleEndMinutes := 14 * 60 + 20;   // 14:20

  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(5, 6, 0)), 'before the window');
  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(5, 14, 19)), 'last minute of the window');
end;

procedure TScheduleEndedTests.AfterEnd_EndedForTheRestOfTheDay;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 6 * 60 + 25;  // 06:25
  LSettings.ScheduleEndMinutes := 14 * 60 + 20;   // 14:20

  Assert.IsTrue(LSettings.ScheduleEndedEarlierToday(AtJanuary(5, 14, 20)), 'right at the end');
  Assert.IsTrue(LSettings.ScheduleEndedEarlierToday(AtJanuary(5, 23, 59)), 'late evening');
end;

procedure TScheduleEndedTests.UnscheduledDay_NotEnded;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 6 * 60 + 25;
  LSettings.ScheduleEndMinutes := 14 * 60 + 20;

  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(6, 15, 0)), 'Saturday');
end;

procedure TScheduleEndedTests.WholeDayWindow_EndsAtMidnight;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule; // No times: all of Monday..Friday

  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(5, 23, 59)), 'still Friday');
  Assert.IsTrue(LSettings.ScheduleEndedEarlierToday(AtJanuary(6, 10, 0)), 'Friday''s window ended at 00:00 Saturday');
  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(7, 10, 0)), 'Sunday: nothing ended today');
end;

procedure TScheduleEndedTests.Overnight_EndsOnTheNextMorning;
var
  LSettings: TSettings;
begin
  LSettings := WeekdayOvernightSchedule;

  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(1, 12, 0)), 'Monday noon: no window yet');
  Assert.IsTrue(LSettings.ScheduleEndedEarlierToday(AtJanuary(2, 6, 0)), 'Tuesday morning, Monday''s window over');
  Assert.IsTrue(LSettings.ScheduleEndedEarlierToday(AtJanuary(2, 21, 59)), 'until Tuesday''s own window starts');
  Assert.IsTrue(LSettings.ScheduleEndedEarlierToday(AtJanuary(6, 12, 0)), 'Saturday, Friday''s window over');
  Assert.IsFalse(LSettings.ScheduleEndedEarlierToday(AtJanuary(7, 12, 0)), 'Sunday');
end;

{ TMouseDistanceTests }

procedure TMouseDistanceTests.AddCoordinate_AccumulatesEuclideanDistance;
var
  LMouse: TMouseDistance;
begin
  LMouse := TMouseDistance.Create(3600); // large reset window so the stopwatch never trips

  Assert.AreEqual(0.0, LMouse.AddCoordinate(100, 100), 0.0001, 'first coordinate seeds, no distance');
  Assert.AreEqual(5.0, LMouse.AddCoordinate(103, 104), 0.0001, '3-4-5 triangle');
  Assert.AreEqual(10.0, LMouse.AddCoordinate(106, 108), 0.0001, 'accumulates another 5');
end;

procedure TMouseDistanceTests.AddCoordinate_OriginIsARealCoordinate;
var
  LMouse: TMouseDistance;
begin
  LMouse := TMouseDistance.Create(3600);

  LMouse.AddCoordinate(3, 4);
  Assert.AreEqual(5.0, LMouse.AddCoordinate(0, 0), 0.0001, 'move to the origin counts');
  Assert.AreEqual(10.0, LMouse.AddCoordinate(3, 4), 0.0001, 'origin did not re-seed');
end;

procedure TMouseDistanceTests.SubtractMouseOffset_ReducesReportedDistance;
var
  LMouse: TMouseDistance;
begin
  LMouse := TMouseDistance.Create(3600);

  LMouse.AddCoordinate(100, 100);
  LMouse.AddCoordinate(103, 104);   // accumulated 5
  LMouse.SubtractMouseOffset(3, 4); // our own injected move of length 5

  Assert.AreEqual(5.0, LMouse.AddCoordinate(106, 108), 0.0001, '10 accumulated minus 5 injected');
end;

procedure TMouseDistanceTests.Clear_ResetsAccumulatedDistance;
var
  LMouse: TMouseDistance;
begin
  LMouse := TMouseDistance.Create(3600);

  LMouse.AddCoordinate(100, 100);
  LMouse.AddCoordinate(103, 104); // accumulated 5
  LMouse.Clear;

  LMouse.AddCoordinate(100, 100); // seed again after clear
  Assert.AreEqual(5.0, LMouse.AddCoordinate(103, 104), 0.0001, 'fresh 5, not 10');
end;

end.

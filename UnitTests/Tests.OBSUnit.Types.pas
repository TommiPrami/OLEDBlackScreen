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
    procedure Window_BoundariesAreInclusive;
  end;

  [TestFixture]
  TMouseDistanceTests = class
  public
    [Test]
    procedure AddCoordinate_AccumulatesEuclideanDistance;
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

function WeekdaySchedule: TSettings;
begin
  Result.ScheduleDays := [wdMonday, wdTuesday, wdWednesday, wdThursday, wdFriday];
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
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(12, 1)));
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

procedure TBlocksLockingTests.Window_BoundariesAreInclusive;
var
  LSettings: TSettings;
begin
  LSettings := WeekdaySchedule;
  LSettings.ScheduleStartMinutes := 7 * 60;      // 07:00
  LSettings.ScheduleEndMinutes := 15 * 60 + 15;  // 15:15

  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(7, 0)), 'start minute is inclusive');
  Assert.IsTrue(LSettings.BlocksLockingAt(AtMonday(15, 15)), 'end minute is inclusive');
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(6, 59)));
  Assert.IsFalse(LSettings.BlocksLockingAt(AtMonday(15, 16)));
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

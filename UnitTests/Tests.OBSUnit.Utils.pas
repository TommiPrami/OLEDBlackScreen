unit Tests.OBSUnit.Utils;

interface

uses
  DUnitX.TestFramework;

type
  // Time parsing / formatting, exercised across different FormatSettings.TimeSeparator values.
  [TestFixture]
  TTimeFormatTests = class
  strict private
    FSavedSeparator: Char;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('colon',        '07:30,450')]
    [TestCase('dot',          '07.30,450')]
    [TestCase('midnight',     '00:00,0')]
    [TestCase('one-minute',   '00:01,1')]
    [TestCase('last-minute',  '23:59,1439')]
    [TestCase('single-digit', '7:5,425')]
    [TestCase('surrounding-spaces', ' 7:5 ,425')]
    procedure TryParseTime_Valid(const AInput: string; const AExpected: Integer);

    [Test]
    [TestCase('empty',        '')]
    [TestCase('no-separator', '0730')]
    [TestCase('hour-too-big', '24:00')]
    [TestCase('minute-too-big', '10:60')]
    [TestCase('negative-hour', '-1:00')]
    [TestCase('letters',      'ab:cd')]
    [TestCase('separator-only', ':')]
    [TestCase('missing-minutes', '12:')]
    procedure TryParseTime_Invalid(const AInput: string);

    [Test]
    procedure TryParseTime_SetsMinusOneOnFailure;
    [Test]
    procedure TryParseTime_AcceptsColonAndDotWhateverTheLocale;

    [Test]
    procedure MinutesToTime_UsesColonSeparator;
    [Test]
    procedure MinutesToTime_UsesDotSeparator;
    [Test]
    procedure MinutesToTime_RoundTripsThroughParse;

    [Test]
    procedure ApplyTimeSeparator_SubstitutesColon;
    [Test]
    procedure ApplyTimeSeparator_SubstitutesDot;
    [Test]
    procedure ApplyTimeSeparator_LeavesTextWithoutPlaceholderUnchanged;
  end;

  [TestFixture]
  TFileVersionTests = class
  public
    [Test]
    procedure GetFileVersion_ReadsKnownSystemDll;
    [Test]
    procedure GetFileVersionStr_HasFourNumericParts;
    [Test]
    procedure GetFileVersion_RaisesForMissingFile;
  end;

  [TestFixture]
  TSettingsPersistenceTests = class
  strict private
    FTempFile: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure WriteThenLoad_RoundTripsAllFields;
    [Test]
    procedure LoadFromMissingFile_LeavesSettingsUnchanged;
    [Test]
    procedure GetDefaultSettingsFilename_EndsWithExpectedPath;
  end;

  [TestFixture]
  TInputTests = class
  public
    [Test]
    procedure GetSecondsSinceLastInput_IsNonNegative;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, OBSUnit.Types, OBSUnit.Utils;

function SystemKernel32: string;
begin
  Result := TPath.Combine(TPath.Combine(GetEnvironmentVariable('SystemRoot'), 'System32'), 'kernel32.dll');
end;

{ TTimeFormatTests }

procedure TTimeFormatTests.Setup;
begin
  FSavedSeparator := FormatSettings.TimeSeparator;
end;

procedure TTimeFormatTests.TearDown;
begin
  FormatSettings.TimeSeparator := FSavedSeparator;
end;

procedure TTimeFormatTests.TryParseTime_Valid(const AInput: string; const AExpected: Integer);
var
  LMinutes: Integer;
begin
  Assert.IsTrue(TryParseTime(AInput, LMinutes), 'Expected "' + AInput + '" to parse');
  Assert.AreEqual(AExpected, LMinutes);
end;

procedure TTimeFormatTests.TryParseTime_Invalid(const AInput: string);
var
  LMinutes: Integer;
begin
  Assert.IsFalse(TryParseTime(AInput, LMinutes), 'Expected "' + AInput + '" to be rejected');
end;

procedure TTimeFormatTests.TryParseTime_SetsMinusOneOnFailure;
var
  LMinutes: Integer;
begin
  LMinutes := 999;
  Assert.IsFalse(TryParseTime('not-a-time', LMinutes));
  Assert.AreEqual(-1, LMinutes);
end;

procedure TTimeFormatTests.TryParseTime_AcceptsColonAndDotWhateverTheLocale;
var
  LMinutes: Integer;
begin
  FormatSettings.TimeSeparator := ':';
  Assert.IsTrue(TryParseTime('07:30', LMinutes) and (LMinutes = 450), 'colon locale, colon input');
  Assert.IsTrue(TryParseTime('07.30', LMinutes) and (LMinutes = 450), 'colon locale, dot input');

  FormatSettings.TimeSeparator := '.';
  Assert.IsTrue(TryParseTime('07.30', LMinutes) and (LMinutes = 450), 'dot locale, dot input');
  Assert.IsTrue(TryParseTime('07:30', LMinutes) and (LMinutes = 450), 'dot locale, colon input');
end;

procedure TTimeFormatTests.MinutesToTime_UsesColonSeparator;
begin
  FormatSettings.TimeSeparator := ':';
  Assert.AreEqual('07:30', MinutesToTime(450));
  Assert.AreEqual('00:00', MinutesToTime(0));
  Assert.AreEqual('23:59', MinutesToTime(1439));
end;

procedure TTimeFormatTests.MinutesToTime_UsesDotSeparator;
begin
  FormatSettings.TimeSeparator := '.';
  Assert.AreEqual('07.30', MinutesToTime(450));
end;

procedure TTimeFormatTests.MinutesToTime_RoundTripsThroughParse;
var
  LMinutes: Integer;
begin
  FormatSettings.TimeSeparator := '.';
  Assert.IsTrue(TryParseTime(MinutesToTime(915), LMinutes));
  Assert.AreEqual(915, LMinutes);
end;

procedure TTimeFormatTests.ApplyTimeSeparator_SubstitutesColon;
begin
  FormatSettings.TimeSeparator := ':';
  Assert.AreEqual('Start time (HH:MM)', ApplyTimeSeparator('Start time (HH%sMM)'));
end;

procedure TTimeFormatTests.ApplyTimeSeparator_SubstitutesDot;
begin
  FormatSettings.TimeSeparator := '.';
  Assert.AreEqual('Start time (HH.MM)', ApplyTimeSeparator('Start time (HH%sMM)'));
end;

procedure TTimeFormatTests.ApplyTimeSeparator_LeavesTextWithoutPlaceholderUnchanged;
begin
  Assert.AreEqual('No placeholder here', ApplyTimeSeparator('No placeholder here'));
end;

{ TFileVersionTests }

procedure TFileVersionTests.GetFileVersion_ReadsKnownSystemDll;
var
  LMajor, LMinor, LRelease, LBuild: Integer;
begin
  GetFileVersion(SystemKernel32, LMajor, LMinor, LRelease, LBuild);

  Assert.IsTrue(LMajor > 0, 'kernel32.dll should report a major version > 0');
end;

procedure TFileVersionTests.GetFileVersionStr_HasFourNumericParts;
var
  LParts: TArray<string>;
  LPart: string;
  LValue: Integer;
  LPartCount: Integer;
begin
  LParts := GetFileVersionStr(SystemKernel32).Split(['.']);

  LPartCount := Length(LParts); // Length is NativeInt (Int64 on Win64); keep the compare Integer-typed
  Assert.AreEqual(4, LPartCount, 'expected Major.Minor.Release.Build');

  for LPart in LParts do
    Assert.IsTrue(TryStrToInt(LPart, LValue), 'each part should be numeric, got: ' + LPart);
end;

procedure TFileVersionTests.GetFileVersion_RaisesForMissingFile;
begin
  Assert.WillRaise(
    procedure
    var
      LMajor, LMinor, LRelease, LBuild: Integer;
    begin
      GetFileVersion('C:\no-such-dir\no-such-file-zzz.dll', LMajor, LMinor, LRelease, LBuild);
    end);
end;

{ TSettingsPersistenceTests }

procedure TSettingsPersistenceTests.Setup;
begin
  // GetTempFileName creates a real (empty) file, so WriteSettings uses it as-is.
  FTempFile := TPath.GetTempFileName;
end;

procedure TSettingsPersistenceTests.TearDown;
begin
  if TFile.Exists(FTempFile) then
    TFile.Delete(FTempFile);
end;

procedure TSettingsPersistenceTests.WriteThenLoad_RoundTripsAllFields;
var
  LSource: TSettings;
  LLoaded: TSettings;
begin
  LSource.MouseMoveDistance := 321;
  LSource.UserIdleTime := 90;
  LSource.MouseMoveResetTime := 12;
  LSource.ScheduleDays := [wdMonday, wdWednesday, wdFriday];
  LSource.ScheduleStartMinutes := 7 * 60;
  LSource.ScheduleEndMinutes := 15 * 60 + 15;
  LSource.LockWhenScheduleEnds := True;
  LSource.LockIdleSeconds := 45;

  WriteSettings(FTempFile, LSource);
  LoadSettingsFromFile(FTempFile, LLoaded);

  Assert.AreEqual(321.0, LLoaded.MouseMoveDistance, 0.0001, 'MouseMoveDistance');
  Assert.AreEqual(90, LLoaded.UserIdleTime, 'UserIdleTime');
  Assert.AreEqual(12, LLoaded.MouseMoveResetTime, 'MouseMoveResetTime');
  Assert.IsTrue(LLoaded.ScheduleDays = [wdMonday, wdWednesday, wdFriday], 'ScheduleDays');
  Assert.AreEqual(7 * 60, LLoaded.ScheduleStartMinutes, 'ScheduleStartMinutes');
  Assert.AreEqual(15 * 60 + 15, LLoaded.ScheduleEndMinutes, 'ScheduleEndMinutes');
  Assert.IsTrue(LLoaded.LockWhenScheduleEnds, 'LockWhenScheduleEnds');
  Assert.AreEqual(45, LLoaded.LockIdleSeconds, 'LockIdleSeconds');
end;

procedure TSettingsPersistenceTests.LoadFromMissingFile_LeavesSettingsUnchanged;
var
  LSettings: TSettings; // Initialize gives defaults
begin
  LoadSettingsFromFile('C:\no-such-dir\no-such-file-zzz.json', LSettings);

  Assert.AreEqual(300.0, LSettings.MouseMoveDistance, 0.0001);
  Assert.AreEqual(120, LSettings.UserIdleTime);
end;

procedure TSettingsPersistenceTests.GetDefaultSettingsFilename_EndsWithExpectedPath;
var
  LName: string;
begin
  LName := GetDefaultSettingsFilename;

  Assert.IsTrue(LName.EndsWith(TPath.Combine(SETTINGS_SUB_DIR, SETTINGS_FILENAME)),
    'unexpected default settings path: ' + LName);
end;

{ TInputTests }

procedure TInputTests.GetSecondsSinceLastInput_IsNonNegative;
begin
  Assert.IsTrue(GetSecondsSinceLastInput >= 0);
end;

end.

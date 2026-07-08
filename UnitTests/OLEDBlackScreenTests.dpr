program OLEDBlackScreenTests;

{$IFNDEF TESTINSIGHT}
  {$APPTYPE CONSOLE}
{$ENDIF}

{$STRONGLINKTYPES ON}
uses
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
    {$IFDEF USE_FILE_LOGGER}
  DUnitX.Loggers.Xml.NUnit,
    {$ENDIF }
  {$ENDIF}
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  OBSUnit.Types in '..\Source\Units\OBSUnit.Types.pas',
  OBSUnit.Utils in '..\Source\Units\OBSUnit.Utils.pas',
  Tests.OBSUnit.Utils in 'Tests.OBSUnit.Utils.pas',
  Tests.OBSUnit.Types in 'Tests.OBSUnit.Types.pas';

{$IF NOT Defined(TESTINSIGHT)}
var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
  {$IFDEF USE_FILE_LOGGER}
  LNUnitLogger: ITestLogger;
  {$ENDIF}
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    LRunner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    LRunner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    LRunner.FailsOnNoAsserts := False;

    //tell the runner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      LLogger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      LRunner.AddLogger(LLogger);
    end;

  {$IFDEF USE_FILE_LOGGER}
    //Generate an NUnit compatible XML File
    LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNunitLogger);
  {$ENDIF}

    //Run tests
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}

end.

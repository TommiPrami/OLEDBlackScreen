program OLEDBlackScreen;

uses
  Vcl.Forms,
  OLBForm.Main in 'Source\Forms\OLBForm.Main.pas' {OLBMainForm},
  OBSUnit.SystemCritical in 'Source\Units\OBSUnit.SystemCritical.pas',
  OLBForm.Settings in 'Source\Forms\OLBForm.Settings.pas' {OLBSettingsForm},
  OBSUnit.Types in 'Source\Units\OBSUnit.Types.pas',
  OBSUnit.Utils in 'Source\Units\OBSUnit.Utils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TOLBMainForm, OLBMainForm);
  Application.Run;
end.

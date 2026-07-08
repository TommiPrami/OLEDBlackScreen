object OLBSettingsForm: TOLBSettingsForm
  Left = 0
  Top = 0
  Caption = 'OLED Black Screen Settings'
  ClientHeight = 460
  ClientWidth = 426
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object PanelButtons: TPanel
    Left = 0
    Top = 417
    Width = 426
    Height = 43
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 9
    Padding.Top = 8
    Padding.Right = 9
    Padding.Bottom = 8
    ShowCaption = False
    TabOrder = 1
    object ButtonOK: TButton
      AlignWithMargins = True
      Left = 262
      Top = 8
      Width = 75
      Height = 27
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 5
      Margins.Bottom = 0
      Action = ActionOK
      Align = alRight
      TabOrder = 0
    end
    object ButtonCancel: TButton
      Left = 342
      Top = 8
      Width = 75
      Height = 27
      Action = ActionCancel
      Align = alRight
      TabOrder = 1
    end
  end
  object ScrollBoxMain: TScrollBox
    Left = 0
    Top = 0
    Width = 426
    Height = 417
    Align = alClient
    BevelInner = bvNone
    BevelOuter = bvNone
    BorderStyle = bsNone
    ParentBackground = True
    TabOrder = 0
    object PanelMain: TPanel
      Left = 0
      Top = 0
      Width = 426
      Height = 417
      Align = alClient
      BevelOuter = bvNone
      ParentColor = True
      ShowCaption = False
      TabOrder = 0
      object LabelUserIdleTimeUnit: TLabel
        Left = 136
        Top = 27
        Width = 43
        Height = 15
        Caption = 'seconds'
      end
      object LabelMouseMoveDistanceUnit: TLabel
        Left = 136
        Top = 77
        Width = 29
        Height = 15
        Caption = 'pixels'
      end
      object LabelMouseMoveResetTimeUnit: TLabel
        Left = 136
        Top = 127
        Width = 43
        Height = 15
        Caption = 'seconds'
      end
      object LabelVersion: TLabel
        AlignWithMargins = True
        Left = 8
        Top = 399
        Width = 410
        Height = 15
        Margins.Left = 8
        Margins.Right = 8
        Align = alBottom
        Caption = 'Version: '
      end
      object LabelScheduleTitle: TLabel
        Left = 8
        Top = 164
        Width = 186
        Height = 15
        Caption = 'Prevent locking only on these days:'
      end
      object LabelScheduleHint: TLabel
        Left = 8
        Top = 348
        Width = 401
        Height = 45
        Caption = 
          'Leave all days unchecked to prevent locking around the clock. Wi' +
          'th a single time set, the other side of the window stays open. A' +
          'uto-lock waits until you have been idle before locking, so it ne' +
          'ver locks mid-action.'
        WordWrap = True
      end
      object LabelLockIdleSecondsUnit: TLabel
        Left = 136
        Top = 313
        Width = 43
        Height = 15
        Caption = 'seconds'
      end
      object LabeledEditMouseMoveDistance: TLabeledEdit
        Left = 8
        Top = 74
        Width = 120
        Height = 23
        EditLabel.Width = 116
        EditLabel.Height = 15
        EditLabel.Caption = 'Mouse move distance'
        TabOrder = 1
        Text = ''
      end
      object LabeledEditUserIdleTime: TLabeledEdit
        Left = 8
        Top = 24
        Width = 120
        Height = 23
        EditLabel.Width = 72
        EditLabel.Height = 15
        EditLabel.Caption = 'User idle time'
        NumbersOnly = True
        TabOrder = 0
        Text = ''
      end
      object LabeledEditMouseMoveResetTime: TLabeledEdit
        Left = 8
        Top = 124
        Width = 120
        Height = 23
        EditLabel.Width = 124
        EditLabel.Height = 15
        EditLabel.Caption = 'Mouse move reset time'
        NumbersOnly = True
        TabOrder = 2
        Text = ''
      end
      object CheckBoxMonday: TCheckBox
        Left = 8
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Mon'
        TabOrder = 3
        OnClick = ScheduleControlClick
      end
      object CheckBoxTuesday: TCheckBox
        Left = 64
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Tue'
        TabOrder = 4
        OnClick = ScheduleControlClick
      end
      object CheckBoxWednesday: TCheckBox
        Left = 120
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Wed'
        TabOrder = 5
        OnClick = ScheduleControlClick
      end
      object CheckBoxThursday: TCheckBox
        Left = 176
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Thu'
        TabOrder = 6
        OnClick = ScheduleControlClick
      end
      object CheckBoxFriday: TCheckBox
        Left = 232
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Fri'
        TabOrder = 7
        OnClick = ScheduleControlClick
      end
      object CheckBoxSaturday: TCheckBox
        Left = 288
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Sat'
        TabOrder = 8
        OnClick = ScheduleControlClick
      end
      object CheckBoxSunday: TCheckBox
        Left = 344
        Top = 186
        Width = 52
        Height = 17
        Caption = 'Sun'
        TabOrder = 9
        OnClick = ScheduleControlClick
      end
      object LabeledEditScheduleStart: TLabeledEdit
        Left = 8
        Top = 232
        Width = 100
        Height = 23
        EditLabel.Width = 117
        EditLabel.Height = 15
        EditLabel.Caption = 'Start time (HH%sMM)'
        TabOrder = 10
        Text = ''
      end
      object LabeledEditScheduleEnd: TLabeledEdit
        Left = 160
        Top = 232
        Width = 100
        Height = 23
        EditLabel.Width = 113
        EditLabel.Height = 15
        EditLabel.Caption = 'End time (HH%sMM)'
        TabOrder = 11
        Text = ''
      end
      object CheckBoxLockOnScheduleEnd: TCheckBox
        Left = 8
        Top = 268
        Width = 300
        Height = 17
        Caption = 'Lock the computer when the schedule ends'
        TabOrder = 12
        OnClick = ScheduleControlClick
      end
      object LabeledEditLockIdleSeconds: TLabeledEdit
        Left = 8
        Top = 310
        Width = 120
        Height = 23
        EditLabel.Width = 74
        EditLabel.Height = 15
        EditLabel.Caption = 'Lock after idle'
        NumbersOnly = True
        TabOrder = 13
        Text = ''
      end
    end
  end
  object ActionList: TActionList
    Left = 360
    Top = 8
    object ActionOK: TAction
      Caption = 'OK'
      OnExecute = ActionOKExecute
    end
    object ActionCancel: TAction
      Caption = 'Cancel'
      OnExecute = ActionCancelExecute
    end
  end
end

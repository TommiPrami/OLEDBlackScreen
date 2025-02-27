object OLBSettingsForm: TOLBSettingsForm
  Left = 0
  Top = 0
  Caption = 'OLED Black Screen Settings'
  ClientHeight = 323
  ClientWidth = 426
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  OnShow = FormShow
  TextHeight = 15
  object PanelButtons: TPanel
    Left = 0
    Top = 280
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
    Height = 280
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
      Height = 280
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
      object LabelMopuseMoveDIstanceUnit: TLabel
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
        Top = 262
        Width = 410
        Height = 15
        Margins.Left = 8
        Margins.Right = 8
        Align = alBottom
        Caption = 'Version: '
      end
      object LabeledEditMouseMoveDistance: TLabeledEdit
        Left = 8
        Top = 74
        Width = 120
        Height = 23
        EditLabel.Width = 116
        EditLabel.Height = 15
        EditLabel.Caption = 'Mouse move distance'
        NumbersOnly = True
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

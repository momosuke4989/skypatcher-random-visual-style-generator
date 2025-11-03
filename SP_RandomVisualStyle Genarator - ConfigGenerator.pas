unit userscripts;

uses 'NPC Replacer Converter - Shared\NPCRC_CommonUtils';

const
  APPLYCHANCE = '99';

var
  // イニシャル処理で設定・使用する変数
  RVSFactionName: TStringList;
  RVSGFileName: string;
  addRVS: boolean;
  
  // プロセス処理で設定する変数
  formListPrefix: string;

procedure AssignRVSExportString(const RVSFactionName, prefix: string; var slExportString: TStringList);
var
  RVSOperation: string;
begin
  
  if addRVS = true then
    RVSOperation := 'add'
  else
    RVSOperation := 'set';
    
    slExportString.Add(';' + RVSFactionName);
    slExportString.Add('filterByEditorIdContains=Enc, ' + RVSFactionName + ':filterByEditorIdContainsExcluded=Template:restrictToGender=male:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_Male_RVSG~' + APPLYCHANCE);

    slExportString.Add('filterByEditorIdContains=Enc, ' + RVSFactionName + ':filterByEditorIdContainsExcluded=Template:restrictToGender=female:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_Female_RVSG~' + APPLYCHANCE);
    
  
end;

function MyStrToBool(s: string): boolean;
begin
  s := LowerCase(Trim(s));
  if (s = 'true') or (s = '1') or (s = 'yes') then
    Result := True
  else
    Result := False;
end;

function Initialize: integer;
var
  opts, checkedOpts, disableOpts, selected: TStringList;
  checkBoxCaption: string;
  i: Integer;
begin
  Result := 0;
  RVSFactionName   := TStringList.Create;
  
  RVSGFileName     := '';
  
  opts             := TStringList.Create;
  checkedOpts      := TStringList.Create;
  disableOpts      := TStringList.Create;
  selected         := TStringList.Create;

  RVSFactionName.Add('Bandit=false');
  RVSFactionName.Add('Warlock=false');
  RVSFactionName.Add('Witch=false');
  RVSFactionName.Add('Forsworn=false');
  RVSFactionName.Add('GuardImperial=false');
  RVSFactionName.Add('SoldierImperial=false');
  RVSFactionName.Add('GuardSons=false');
  RVSFactionName.Add('SoldierSons=false');
  RVSFactionName.Add('VigilantOfStendarr=false');
  RVSFactionName.Add('Dawnguard=false');
  RVSFactionName.Add('Vampire=false');
  RVSFactionName.Add('Hunter=false');
  RVSFactionName.Add('Sailor=false');
  RVSFactionName.Add('Thalmor=false');
  RVSFactionName.Add('Alikr=false');
  RVSFactionName.Add('Penitus=false');
  RVSFactionName.Add('Afflicted=false');
  RVSFactionName.Add('Cultist=false');
  
  checkBoxCaption := 'Target faction select';
  
  if MessageDlg(
    'Select which Random Visual Style Operation:' + #13#10 +
    'Yes = Add' + #13#10 +
    'No = Set',
    mtConfirmation, [mbYes, mbNo], 0
    ) = mrYes then
    addRVS := true;
  
  // 各オプションの設定
  try
    opts.Add('Bandits');
    opts.Add('Warlocks');
    opts.Add('Witches');
    opts.Add('Forsworn');
    opts.Add('Imperial Guard');
    opts.Add('Imperial Soldier');
    opts.Add('Stormcloak Guard');
    opts.Add('Stormcloak Soldier');
    opts.Add('Vigilants of Stendarr');
    opts.Add('Dawnguard');
    opts.Add('Vampires');
    opts.Add('Hunters and Fishermen');
    opts.Add('Sailors');
    opts.Add('Thalmor');
    opts.Add('Alikr');
    opts.Add('Penitus');
    opts.Add('Afflicted');
    opts.Add('Cultists');
    

    if ShowCheckboxForm(opts, checkedOpts, disableOpts, selected, checkBoxCaption) then
    begin
      AddMessage('You selected:');
      for i := 0 to selected.Count - 1 do begin
        AddMessage(opts[i] + ' - ' + selected[i]);
        RVSFactionName.ValueFromIndex[i] := selected[i];
      end;
    end
    else begin
      AddMessage('Selection was canceled.');
      Result := -1;
      Exit;
    end;
    
  finally
    opts.Free;
    checkedOpts.Free;
    disableOpts.Free;
    selected.Free;
  end;
  
end;

function Process(e: IInterface): integer;
var
  formListEditorID: string;
  i, underscorePos: cardinal;
begin
  Result := 0;
  underscorePos := 0;
  
  formListEditorID := '';
  
  // FormListレコードでなければスキップ
  if Signature(e) <> 'FLST' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not Form List record.');
    Exit;
  end;
  
  if RVSGFileName = '' then begin
    RVSGFileName := GetFileName(GetFile(e));
    RVSGFileName := ChangeFileExt(RVSGFileName, '');
  end;
  
  if formListPrefix = '' then begin
    formListEditorID := GetElementEditValues(e, 'EDID');
    underscorePos := Pos('_', formListEditorID);
    formListPrefix := Copy(formListEditorID, 1, underscorePos - 1);
  end;
  
  //AddMessage(RVSGFileName);
  //AddMessage(formListPrefix);
  
end;

function Finalize: integer;
var
  // 設定ファイル出力用変数
  slExport: TStringList;
  
  dlgSave: TSaveDialog;
  exportFileName, saveDir, filterString, fileExtension: string;
  RVSOperation: string;
  i: Cardinal;
begin
  Result := 0;
  
  if RVSGFileName = '' then begin
    AddMessage('The information required to generate a configuration file could not be obtained.');
    Exit;
  end;
  
  slExport         := TStringList.Create;
  
  if addRVS = true then
    RVSOperation := 'ADD - '
  else
    RVSOperation := 'SET - ';
  
  // 出力設定
  saveDir := DataPath + 'SkyPatcher Random Visual Style Generator\SKSE\Plugins\SkyPatcher\npc\SkyPatcher Random Visual Style Generator\';
  filterString := 'Ini (*.ini)|*.ini';
  fileExtension := '.ini';
    
  // ディレクトリ作成
  if not DirectoryExists(saveDir) then
    ForceDirectories(saveDir);
    
  dlgSave := TSaveDialog.Create(nil);
  try
    // ファイル保存
    dlgSave.Options := dlgSave.Options + [ofOverwritePrompt];
    dlgSave.Filter := filterString;
    dlgSave.InitialDir := saveDir;
    for i := 0 to RVSFactionName.Count -1 do begin
      if MyStrToBool(RVSFactionName.ValueFromIndex[i]) then begin
        slExport.Clear;
        AssignRVSExportString(RVSFactionName.Names[i], formListPrefix, slExport);
        dlgSave.FileName := RVSOperation + RVSGFileName + ' - ' + RVSFactionName.Names[i] + fileExtension;
        if dlgSave.Execute then begin
          exportFileName := dlgSave.FileName;
          AddMessage('Saving ' + exportFileName);
          slExport.SaveToFile(exportFileName);
        end;
      end;
    end;
  finally
    dlgSave.Free;
  end;
  if Assigned(slExport) then
    slExport.Free;
  if Assigned(RVSFactionName) then
    RVSFactionName.Free;
    
end;

end.

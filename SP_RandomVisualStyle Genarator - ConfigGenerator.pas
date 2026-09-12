unit userscripts;

uses 'NPC Replacer Converter - Shared\NPCRC_CommonUtils';

const
  APPLYCHANCE = '100';

  WORLD_ENCOUNTER_KEYWORD   = 'WorldEncounter';
  WORLD_ENCOUNTER_EDITORIDS = 'WEThief, WEAssassin, WEAdventurer, WERoadCourier';

  BANDIT_KEYWORD = 'Bandit';
  FORSWORN_KEYWORD = 'Forsworn';
  HUNTER_KEYWORD = 'Hunter';
  DAWNGUARD_KEYWORD = 'Dawnguard';
  VAMPIRE_KEYWORD = 'Vampire';
  CULTIST_KEYWORD = 'Cultist';
  SAINTS_KEYWORD = 'Saints';
  SEDUCERS_KEYWORD = 'Seducers';

  SKYRIM_FILE_NAME = 'Skyrim.esm, Update.esm';
  DAWNGUARD_FILE_NAME = 'Dawnguard.esm';
  DRAGONBORN_FILE_NAME = 'Dragonborn.esm';
  SAINTS_AND_SEDUCERS_FILE_NAME = 'ccBGSSSE025-AdvDSGS.esm';

var
  // イニシャライズ処理で設定・使用する変数
  slBasicRaces: TStringList;
  slRVSFactionName: TStringList;
  RVSGFileName, targetPluginName: string;
  addRVS, restrictToRaces, isModTarget: boolean;

  // プロセス処理で設定する変数
  formListPrefix: string;

// isModTargetの選択結果と、targetの中身に応じて適切なSkyPatcherフィルタ句を生成する
// - isModTarget = True の場合: filterByModName=<値>
// - isModTarget = False かつ target = 'WorldEncounter' の場合: filterByEditorIdContains=<固定のEditorIDリスト>
// - それ以外(isModTarget = False): 従来通り filterByEditorIdContains=Enc, <値>
function GenerateTargetFilterString(const target: string; isModTarget: boolean): string;
begin
  if isModTarget then
    Result := 'filterByModNames=' + target
  else if SameText(target, WORLD_ENCOUNTER_KEYWORD) then
    Result := 'filterByModNames=' + SKYRIM_FILE_NAME + ':filterByEditorIdContainsOr=' + WORLD_ENCOUNTER_EDITORIDS + ':filterByEditorIdContainsExclude=Lvl'
  else if SameText(target, BANDIT_KEYWORD) then
    Result := 'filterByModNames=' + SKYRIM_FILE_NAME + ', ' + DRAGONBORN_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target + ':filterByEditorIdContainsExclude=dog, wolf'
  else if SameText(target, FORSWORN_KEYWORD) then
    Result := 'filterByModNames=' + SKYRIM_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target + ':filterByEditorIdContainsExclude=dog'
  else if SameText(target, HUNTER_KEYWORD) then
    Result := 'filterByModNames=' + SKYRIM_FILE_NAME + ', ' + DRAGONBORN_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target + ':filterByEditorIdContainsExclude=DLC1'
  else if SameText(target, DAWNGUARD_KEYWORD) then
    Result := 'filterByModNames=' + DAWNGUARD_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target
  else if SameText(target, VAMPIRE_KEYWORD) then
    Result := 'filterByModNames=' + SKYRIM_FILE_NAME + ', ' + DAWNGUARD_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target
  else if SameText(target, CULTIST_KEYWORD) then
    Result := 'filterByModNames=' + DRAGONBORN_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target
  else if SameText(target, SAINTS_KEYWORD) then
    Result := 'filterByModNames=' + SAINTS_AND_SEDUCERS_FILE_NAME + ':filterByEditorIdContains=EncBanditSaint'
  else if SameText(target, SEDUCERS_KEYWORD) then
    Result := 'filterByModNames=' + SAINTS_AND_SEDUCERS_FILE_NAME + ':filterByEditorIdContains=EncBanditSeducer'
  else
    Result := 'filterByModNames=' + SKYRIM_FILE_NAME + ':filterByEditorIdContains=Enc, ' + target;
end;

procedure AssignRVSExportString(const slRVSFactionName, prefix, filterString: string; var slExportString: TStringList);
var
  RVSOperation, disableGender, disableRaceGender: string;
  i: Cardinal;
begin

  if addRVS = true then
    RVSOperation := 'add'
  else
    RVSOperation := 'set';

  if restrictToRaces = true then
  begin
    disableGender := ';';
    disableRaceGender := '';
  end
  else begin
    disableGender := '';
    disableRaceGender := ';';
  end;

  slExportString.Add(';' + slRVSFactionName);
  // 性別のみで制限する場合は、性別ごとのFormListを割り当てる
  slExportString.Add(';Restrict to Gender Only');
  slExportString.Add(disableGender + filterString + ':rvsRestrictToTraits=true:restrictToGender=male:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_Male_RVSG~' + APPLYCHANCE);

  slExportString.Add(disableGender + filterString + ':rvsRestrictToTraits=true:restrictToGender=female:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_Female_RVSG~' + APPLYCHANCE);

  // 種族と性別で制限する場合は、種族名+性別のFormListを割り当てる
  slExportString.Add(#13#10);
  slExportString.Add(';Restrict to Basic Race and Gender');
  for i := 0 to slBasicRaces.Count - 1 do
  begin
    slExportString.Add(disableRaceGender + filterString + ':rvsRestrictToTraits=true:restrictToRaces=' + slBasicRaces[i] + ':restrictToGender=male:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_' + slBasicRaces[i] + 'Male_RVSG~' + APPLYCHANCE);

    slExportString.Add(disableRaceGender + filterString + ':rvsRestrictToTraits=true:restrictToRaces=' + slBasicRaces[i] + ':restrictToGender=female:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_' + slBasicRaces  [i] + 'Female_RVSG~' + APPLYCHANCE);
  end;

  // 吸血鬼種族も追加
  slExportString.Add(#13#10);
  slExportString.Add(';Basic Vampire Race and Gender');
  for i := 0 to slBasicRaces.Count - 1 do
  begin
    slExportString.Add(disableRaceGender + filterString + ':rvsRestrictToTraits=true:restrictToRaces=' + slBasicRaces[i] + 'Vampire:restrictToGender=male:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_' + slBasicRaces[i] + 'VampireMale_RVSG~' + APPLYCHANCE);

    slExportString.Add(disableRaceGender + filterString + ':rvsRestrictToTraits=true:restrictToRaces=' + slBasicRaces[i] + 'Vampire:restrictToGender=female:' + RVSOperation + 'RandomVisualStyle=' + prefix + '_' + slBasicRaces  [i] + 'VampireFemale_RVSG~' + APPLYCHANCE);
  end;


end;

function Initialize: integer;
var
  disableOpts: TStringList;
  checkBoxCaption: string;
  i: Integer;
begin
  Result := 0;
  slBasicRaces     := TStringList.Create;
  slRVSFactionName := TStringList.Create;

  RVSGFileName     := '';

  disableOpts      := TStringList.Create;

  slBasicRaces.Add('NordRace');
  slBasicRaces.Add('ImperialRace');
  slBasicRaces.Add('BretonRace');
  slBasicRaces.Add('RedguardRace');
  slBasicRaces.Add('HighElfRace');
  slBasicRaces.Add('WoodElfRace');
  slBasicRaces.Add('DarkElfRace');
  slBasicRaces.Add('OrcRace');
  slBasicRaces.Add('KhajiitRace');
  slBasicRaces.Add('ArgonianRace');

  slRVSFactionName.Add('Bandit=false');
  slRVSFactionName.Add('Warlock=false');
  slRVSFactionName.Add('Witch=false');
  slRVSFactionName.Add('Forsworn=false');
  slRVSFactionName.Add('GuardImperial=false');
  slRVSFactionName.Add('SoldierImperial=false');
  slRVSFactionName.Add('GuardSons=false');
  slRVSFactionName.Add('SoldierSons=false');
  slRVSFactionName.Add('VigilantOfStendarr=false');
  slRVSFactionName.Add('Dawnguard=false');
  slRVSFactionName.Add('Vampire=false');
  slRVSFactionName.Add('Hunter=false');
  slRVSFactionName.Add('Sailor=false');
  slRVSFactionName.Add('Thalmor=false');
  slRVSFactionName.Add('Alikr=false');
  slRVSFactionName.Add('Penitus=false');
  slRVSFactionName.Add('Afflicted=false');
  slRVSFactionName.Add('Cultist=false');
  slRVSFactionName.Add('WorldEncounter=false');
  slRVSFactionName.Add('Saints=false');
  slRVSFactionName.Add('Seducers=false');

  checkBoxCaption := 'Target faction select';

  addRVS := false;
  restrictToRaces := false;
  isModTarget := false;

  if MessageDlg(
    'Select which Random Visual Style Operation:' + #13#10 +
    'Yes = Add (Recommend)' + #13#10 +
    'No = Set',
    mtConfirmation, [mbYes, mbNo], 0
    ) = mrYes then
    addRVS := true;

  if MessageDlg(
    'Select restriction type:' + #13#10 +
    'Yes = Restrict to Basic Races and Gender' + #13#10 +
    'No = Gender Only Restriction',
    mtConfirmation, [mbYes, mbNo], 0
    ) = mrYes then
    restrictToRaces := true;

  if MessageDlg(
    'What should this filter target?' + #13#10 +
    'Yes = A specific mod (.esp/.esm/.esl)' + #13#10 +
    'No = A faction (Editor ID keyword)',
    mtConfirmation, [mbYes, mbNo], 0
    ) = mrYes then
  isModTarget := true;

  // 各オプションの設定
  if not isModTarget then begin
    try
      if ShowCheckboxForm(slRVSFactionName, disableOpts, checkBoxCaption) then
      begin
        AddMessage('You selected:');
        for i := 0 to slRVSFactionName.Count - 1 do begin
          AddMessage('  ' + slRVSFactionName.Names[i] + ' - ' + slRVSFactionName.ValueFromIndex[i]);
        end;
      end
      else begin
        AddMessage('Selection was canceled.');
        Result := -1;
        Exit;
      end;

    finally
      disableOpts.Free;
    end;
  end
  else begin
    if not InputQuery('Target Plugin name entry', 'Enter the Form List Plugin name (e.g. MyPlugin.esp)', targetPluginName) then
    begin
      AddMessage('Target plugin name entry was canceled.');
      Result := 1;
      Exit;
    end;
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

  // レコードヘッダーはスキップ
  if Signature(e) = 'TES4' then
    Exit;

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

  filterString, exportFileName, exportFilePath, saveDir, saveDirChild, fileSaveDir, fileExtension: string;
  RVSOperation: string;
  i: Cardinal;
begin
  Result := 0;

  if RVSGFileName = '' then begin
    AddMessage('The information required to generate a configuration file could not be obtained.');
    Exit;
  end;

  slExport         := TStringList.Create;

  if not addRVS then
    RVSOperation := 'SET - ';

  // 出力設定
  saveDir := DataPath + 'SkyPatcher Random Visual Style Generator\SKSE\Plugins\SkyPatcher\npc\SkyPatcher Random Visual Style Generator\';
  fileExtension := '.ini';

  // ディレクトリ作成
  if not DirectoryExists(saveDir) then
    ForceDirectories(saveDir);

  // ファイル保存
  if isModTarget then begin
    AddMessage('====================================================================================================');
    AddMessage('Saving config file under: Data\SkyPatcher Random Visual Style Generator\SKSE\Plugins\SkyPatcher\npc\SkyPatcher Random Visual Style Generator\Mods\');
    AddMessage('====================================================================================================');

    filterString := GenerateTargetFilterString(targetPluginName, isModTarget);
    AssignRVSExportString(RVSGFileName, formListPrefix, filterString, slExport);
    saveDirChild := 'Mods\' + targetPluginName + '\';
    fileSaveDir := saveDir + saveDirChild;
    if not DirectoryExists(fileSaveDir) then
      ForceDirectories(fileSaveDir);

    exportFileName := RVSOperation + RVSGFileName + ' - ' + ChangeFileExt(targetPluginName, '') + fileExtension;
    exportFilePath := fileSaveDir + exportFileName;

    AddMessage(Format('  [%s] %s', [targetPluginName, exportFileName]));
    slExport.SaveToFile(exportFilePath);

  end
  else begin
    AddMessage('====================================================================================================');
    AddMessage('Saving config files under: Data\SkyPatcher Random Visual Style Generator\SKSE\Plugins\SkyPatcher\npc\SkyPatcher Random Visual Style Generator\factions\');
    AddMessage('====================================================================================================');

    for i := 0 to slRVSFactionName.Count -1 do begin
      if GetBoolSLValue(slRVSFactionName.ValueFromIndex[i]) then begin
        slExport.Clear;
        filterString := GenerateTargetFilterString(slRVSFactionName.Names[i], isModTarget);
        AssignRVSExportString(slRVSFactionName.Names[i], formListPrefix, filterString, slExport);

        saveDirChild := 'factions\' + slRVSFactionName.Names[i] + '\';
        fileSaveDir := saveDir + saveDirChild;
        if not DirectoryExists(fileSaveDir) then
          ForceDirectories(fileSaveDir);

        exportFileName := RVSOperation + RVSGFileName + ' - ' + slRVSFactionName.Names[i] + fileExtension;
        exportFilePath := fileSaveDir + exportFileName;

        AddMessage(Format('  [%s] %s', [slRVSFactionName.Names[i], exportFileName]));
        slExport.SaveToFile(exportFilePath);
      end;
    end;
  end;



  AddMessage('====================================================================================================');
  AddMessage('Done.');

  if Assigned(slExport) then
    slExport.Free;
  if Assigned(slBasicRaces) then
    slBasicRaces.Free;
  if Assigned(slRVSFactionName) then
    slRVSFactionName.Free;

end;

end.

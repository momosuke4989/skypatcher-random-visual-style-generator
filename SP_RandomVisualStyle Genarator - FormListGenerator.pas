unit userscript;

uses 'xEdit_mmskCommonLibrary\xEdit_mmskCommonLibrary';

const
  DRAUGRWEAPONS = $00000D14; // FomrID Listコピー参照用
  EDITORIDSUFFIX = '_RVSG';

  UNIQUE_ONLY = False; // ユニークフラグを持つNPCのみをFormListに追加する場合はTrue、すべてのNPCを追加する場合はFalse
  NON_UNIQUE_ONLY = False; // ユニークフラグを持たないNPCのみをFormListに追加する場合はTrue、すべてのNPCを追加する場合はFalse

var
  pluginName, formListPrefix: string;
  createNewPlugin, tergetPluginInit: boolean;

  newPlugin, tergetPlugin: IwbFile;
  baseFormList: IwbMainRecord;
  slNewFormListEditorIDs, slBasicRaces, slExcludeRaces: TStringList;
  lNewFormListRecords: TList;

procedure AssignNPCToFormList(e, formListRecord: IwbMainRecord);
var
  formIDList, newFormList: IInterface;

begin
  formIDList := ElementByName(formListRecord, 'FormIDs');
  newFormList := ElementAssign(formIDList, HighInteger, nil, False);
  SetEditValue(newFormList, IntToHex(GetLoadOrderFormID(e), 8));
  if Assigned(newFormList) then
    AddMessage('Added FormList:' + EditorID(formListRecord));
end;

function CreateNewFormList(newFormListEditorID: string; tergetPlugin: IwbFile): integer;
var
  lastIndex: integer;
    newFormList, entries, formIDs: IwbElement;

begin
  newFormList := wbCopyElementToFile(baseFormList, tergetPlugin, True, True);
  if not Assigned(newFormList) then
  begin
    AddMessage('Failed to create FormList:' + newFormListEditorID);
    Continue;
  end;

  // 'FormIDs' サブレコードを取得、エントリがあれば削除
  entries := ElementByPath(newFormList, 'FormIDs');
  if Assigned(entries) then begin
    RemoveElement(newFormList, 'FormIDs');
    AddMessage('The FormList contents have been cleared.');
  end;
  // FormListのEditor IDを設定
  SetElementEditValues(newFormList, 'EDID', newFormListEditorID);
  // FormIDsエレメントを再設定
  entries := Add(newFormList, 'FormIDs', True);
  // 自動追加されるFormIDs #0を削除
  formIDs := ElementByIndex(entries, 0);
  RemoveElement(entries, formIDs);
  // レコード配列に追加したFormListレコードを格納
  lNewFormListRecords.Add(newFormList);
  lastIndex := lNewFormListRecords.Count - 1;
  AddMessage('Created FormList:' + EditorID(ObjectToElement(lNewFormListRecords[lastIndex])));
  Result := lastIndex;
end;

function GetRaceFaceGenHeadFlag(raceRecord: IInterface): Boolean;
var
  flags: cardinal;
begin
  // DATA\Flags を取得
  flags := GetElementNativeValues(raceRecord, 'DATA\Flags');

  // "FaceGen Head" フラグが ON かどうかを返す
  if (flags and $02) = 2 then
    Result := true
  else
    Result := false;
end;

function ShouldExcludeNPC(e: IInterface): Boolean;
var
  raceRecord: IInterface;
  raceString: string;
  npcFlag: cardinal;
begin
  Result := false;

  // 種族の取得
  raceRecord := LinksTo(ElementByPath(e, 'RNAM'));
  raceString := EditorID(raceRecord);


  // 除外種族リストに含まれる種族かどうかを判定
  if slExcludeRaces.IndexOf(raceString) <> -1 then begin
    AddMessage('This record is in the exclude races list.');
    Result := true;
    Exit;
  end;

    // 種族名にchildを含むNPCはスキップ
  if Pos('child', LowerCase(raceString(e))) > 0 then begin
    AddMessage('This record is a child NPC.');
    Result := true;
    Exit;
  end;

  // playerレコードはスキップ
  if CompareText(EditorID(e), 'player') = 0 then begin
    AddMessage('This record is player.');
    Result := true;
    Exit;
  end;

  // Editor IDにTemplateを含むNPCはスキップ
  if Pos('template', LowerCase(EditorID(e))) > 0 then begin
    AddMessage('This record is a NPC template.');
    Result := true;
    Exit;
  end;

  npcFlag := GetElementNativeValues(e, 'ACBS\Flags');
  // CharGen Presetはスキップ
  if (npcFlag and $4) = 4 then begin
    AddMessage('This record is a CharGen Prest.');
    Result := true;
    Exit;
  end;

  // FaceGenHeadフラグを持たない種族はスキップ
  if not GetRaceFaceGenHeadFlag(raceRecord) then begin
    AddMessage(raceString + ' doesn''t have FaceGen Head Flag.');
    Result := true;
    Exit;
  end;

  // UseTraitsテンプレートフラグを持つNPCはスキップ
  if IsNPCUsingTraits(e) then begin
    AddMessage('This record uses a template and has the Use Traits flag.');
    Result := true;
    Exit;
  end;

end;

function Initialize: integer;
var
    newFormList, entries, formIDs: IwbElement;
    tempRace: string;
begin
  Result := 0;
  createNewPlugin       := false;
  tergetPluginInit  := false;

  slNewFormListEditorIDs := TStringList.Create;
  slBasicRaces := TStringList.Create;
  slExcludeRaces := TStringList.Create;
  lNewFormListRecords := TList.Create;

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

  slExcludeRaces.Add('DefaultRace');
  slExcludeRaces.Add('InvisibleRace');
  slExcludeRaces.Add('ManakinRace');
  slExcludeRaces.Add('TestRace');
  slExcludeRaces.Add('DLC1NordRace');
  slExcludeRaces.Add('NordRaceAstrid');  // 正常に機能すると思うが見た目がホラーなので
  slExcludeRaces.Add('DremoraRace');  // 多分追加しても問題ないがとりあえず除外指定
  slExcludeRaces.Add('DLC2DremoraRace');

  if MessageDlg(
    'Do you want to create a new plugin file for Form List registration?' + #13#10 +
    'Yes = Form Lists are registered in a new esp file.' + #13#10 +
    'No = Form Lists are registered in the file containing NPC records.', mtConfirmation, [mbYes, mbNo], 0
    ) = mrYes then
    createNewPlugin := true;

  if createNewPlugin then begin
    // ユーザーにファイル名を入力してもらう
    if not AskInputDialog('New Plugin name entry', 'Enter the Form List Plugin name (e.g. MyPlugin.esp)', pluginName) then
    begin
      AddMessage('Plugin name entry was canceled.');
      Result := 1;
      Exit;
    end;

    // ファイル名の拡張子を確認し、必要に応じて追加
    if LowerCase(ExtractFileExt(pluginName)) <> '.esp' then
      pluginName := pluginName + '.esp';

    // 新しいプラグインを作成し、ESL フラグを設定
    newPlugin := AddNewFileName(pluginName, True);
    if not Assigned(newPlugin) then
    begin
      AddMessage('Failed to create plugin.');
      Result := 1;
      Exit;
    end;

    AddMasterIfMissing(newPlugin, 'Skyrim.esm');
    AddMessage('A new plugin has been created:' + pluginName);
  end;

// ユーザーにForm Listのプレフィックスを入力してもらう
  if not AskEditorIDPrefix('Set Form List Prefix',
    'Enter the prefix. Only letters (a-z, A-Z) and digits (0-9) are allowed.' + #13#10 + 'Underscore (_) will be added to the prefix you enter:',
    false,
    formListPrefix) then
  begin
    AddMessage('Prefix entry was canceled.');
    Result := 1;
    Exit;
  end;

  // プレフィックスにアンダースコアを追加
  formListPrefix := formListPrefix + '_';
  AddMessage('Form List Prefix:' + formListPrefix);

  // レコードを直接追加できないので、バニラのFormListレコードをコピー
  baseFormList := RecordByFormID(FileByIndex(0), DRAUGRWEAPONS, True);

  // Editor ID のリストを初期化
  // 全員および性別
  slNewFormListEditorIDs.Add(formListPrefix + 'All' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add(formListPrefix + 'Male' + EDITORIDSUFFIX);
  slNewFormListEditorIDs.Add(formListPrefix + 'Female' + EDITORIDSUFFIX);

end;

function Process(e: IInterface): integer;
var
  raceRecord: IInterface;
  i, templateFlag, npcFlag, indxAll, indxGender, indxRaceGender: cardinal;
  NPCGender, raceString: string;
  raceFaceGenHeadFlag: boolean;
begin
  Result := 0;

  if not tergetPluginInit then begin
    if createNewPlugin then
        tergetPlugin := newPlugin
    else
        tergetPlugin := Getfile(e);
    // 各 Editor ID に対して FormList を作成
    for i := 0 to slNewFormListEditorIDs.count - 1 do
    begin
      CreateNewFormList(slNewFormListEditorIDs[i], tergetPlugin);
    end;
    tergetPluginInit := true;
  end;

  // NPCレコード以外のレコードはスキップ
  if Signature(e) <> 'NPC_' then begin
    AddMessage('This record is not an NPC record.');
    Exit;
  end;

  if not IsMaster(e) then begin
    AddMessage('This record overrides another record, so it is skipped.');
    Exit;
  end;

  AddMessage('Record to operate on:' + EditorID(e));

  // レコードが所属するプラグインをマスター指定する
  AddMasterIfMissing(newPlugin, GetFileName(GetFile(e)));

  if ShouldExcludeNPC(e) then begin
    AddMessage('This NPC record is excluded from RVSG Form List.');
    Exit;
  end;

  // NPCレコードフラグを取得
  npcFlag := GetElementNativeValues(e, 'ACBS\Flags');

  if UNIQUE_ONLY and ((npcFlag and $20) = 0) then begin
    AddMessage('This record is not unique, so it is excluded from the Form List.');
    Exit;
  end;

  if NON_UNIQUE_ONLY and ((npcFlag and $20) <> 0) then begin
    AddMessage('This record is unique, so it is excluded from the Form List.');
    Exit;
  end;


  // 種族の取得
  raceRecord := LinksTo(ElementByPath(e, 'RNAM'));
  raceString := EditorID(raceRecord);

  // 性別の判定
  if IsNPCFemale(e) then
    NPCGender := 'Female'
  else
    NPCGender := 'Male';

  // EditorIDを基にFormListを取得（ lNewFormListRecords を先に対応づけ済み）
  // 共通: "All" は全員に割り当て
  indxAll := slNewFormListEditorIDs.IndexOf(formListPrefix + 'All' + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxAll]));

  // 性別マッチ（Male/Femaleのみ)
  indxGender := slNewFormListEditorIDs.IndexOf(formListPrefix + NPCGender + EDITORIDSUFFIX);
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxGender]));

  // 種族+性別マッチ
  indxRaceGender := slNewFormListEditorIDs.IndexOf(formListPrefix + raceString + NPCGender + EDITORIDSUFFIX);
  // FormListが存在しない場合は新規作成してから割り当て
  if indxRaceGender = -1 then
  begin
    indxRaceGender := CreateNewFormList(formListPrefix + raceString + NPCGender + EDITORIDSUFFIX, tergetPlugin);
    slNewFormListEditorIDs.Add(formListPrefix + raceString + NPCGender + EDITORIDSUFFIX);
  end;
  AssignNPCToFormList(e, ObjectToElement(lNewFormListRecords[indxRaceGender]));

end;

function Finalize: integer;
begin
  Result := 0;

  if Assigned(slNewFormListEditorIDs) then
    slNewFormListEditorIDs.Free;
  if Assigned(slBasicRaces) then
    slBasicRaces.Free;
  if Assigned(slExcludeRaces) then
    slExcludeRaces.Free;
  if Assigned(lNewFormListRecords) then
    lNewFormListRecords.Free;
end;

end.

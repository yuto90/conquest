// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get awardsTitle => '任務・アワード';

  @override
  String get awardsAssignments => '任務';

  @override
  String get awardsCollection => 'アワード';

  @override
  String get awardsRibbons => 'リボン';

  @override
  String get awardsMedals => 'メダル';

  @override
  String get awardsIntroduction =>
      '通常CPU戦の完了で進行します。解放済みの任務はすべて自動集計。報酬はバッジのみで追加XPはありません。';

  @override
  String get awardsLocalOnly =>
      'この端末内に保存します。アプリ・ブラウザのデータ消去で記録は消えます。未完了の試合は集計しません。';

  @override
  String get awardsLocked => 'ロック中';

  @override
  String get awardsInProgress => '進行中';

  @override
  String get awardsCompleted => '達成済み';

  @override
  String get awardsUnearned => '未獲得';

  @override
  String get awardsBronze => 'ブロンズ';

  @override
  String get awardsSilver => 'シルバー';

  @override
  String get awardsGold => 'ゴールド';

  @override
  String get awardsCaptureTrack => '占領';

  @override
  String get awardsCommandTrack => '指揮';

  @override
  String get awardsTacticsTrack => '戦術';

  @override
  String get awardsCaptureBronze => '上陸訓練';

  @override
  String get awardsCaptureSilver => '熟練の上陸部隊';

  @override
  String get awardsCaptureGold => '群島の征服者';

  @override
  String get awardsCommandBronze => '初めての指揮';

  @override
  String get awardsCommandSilver => '戦場の指揮官';

  @override
  String get awardsCommandGold => '歴戦の指揮官';

  @override
  String get awardsTacticsBronze => '連続攻勢';

  @override
  String get awardsTacticsSilver => '戦術的勝利';

  @override
  String get awardsTacticsGold => '迅速な決着';

  @override
  String get awardsCapture => '占領';

  @override
  String get awardsManeuver => '機動';

  @override
  String get awardsDeployment => '兵力派遣';

  @override
  String get awardsVictory => '勝利';

  @override
  String get awardsHardVictory => '難敵撃破';

  @override
  String get awardsSwiftVictory => '速攻';

  @override
  String get awardsCapturesMetric => '占領回数';

  @override
  String get awardsDispatchesMetric => '成立した出兵回数';

  @override
  String get awardsForcesMetric => '派遣兵力';

  @override
  String get awardsWinsMetric => '勝利数';

  @override
  String get awardsNormalWinsMetric => 'Normal・Hardでの勝利数';

  @override
  String get awardsHardWinsMetric => 'Hardでの勝利数';

  @override
  String get awardsCaptureRibbonsMetric => '占領リボン';

  @override
  String get awardsSingleMatch => '同じ1試合で（完了試合のベスト記録）';

  @override
  String get awardsCumulative => 'アワード導入後の累計';

  @override
  String get awardsThisMatch => '今回のアワード';

  @override
  String get awardsEmpty => '今回はアワードを獲得していません。';

  @override
  String get awardsSaving => 'アワードを保存中…';

  @override
  String get awardsUnsaved => 'アワードは未保存です。二重加算せず再試行できます。再戦も可能です。';

  @override
  String get awardsUnavailable => '実績を読み込めません。既存データは上書きしません。';

  @override
  String get awardsRetry => '実績保存を再試行';

  @override
  String get awardsLoading => '実績を読み込み中…';

  @override
  String get awardsBadgeReward => '報酬：任務達成バッジ';

  @override
  String awardsPrerequisite({required String name}) {
    return '前提任務：$name';
  }

  @override
  String awardsCount({required int count}) {
    return '獲得数：$count';
  }

  @override
  String awardsNextMedal({required int count, required int target}) {
    return '次のメダル：リボン $count / $target 個';
  }

  @override
  String awardsPerMatch({required int count, required String metric}) {
    return '1試合：$metric $count ごとにリボン1個';
  }

  @override
  String awardsWithin({required int seconds}) {
    return 'Normal・Hardで$seconds秒以内に勝利';
  }

  @override
  String awardsTimeCondition({required String time, required int seconds}) {
    return 'ゲーム内時間：$time / $seconds秒以内';
  }

  @override
  String awardsMedalCondition({required int count}) {
    return '対応リボン$count個ごとにメダル1個（リボンは消費しません）';
  }

  @override
  String awardsCompletedAt({required String date}) {
    return '初回達成：$date';
  }

  @override
  String get myPageAll => 'すべて';

  @override
  String get myPageResult => '勝敗・終了状態';

  @override
  String get myPageIslandCount => '島数';

  @override
  String get myPageClearFilters => '絞り込みを解除';

  @override
  String get myPageRefresh => '更新';

  @override
  String get myPageNoMatchingMatches => '条件に該当する試合はありません。';

  @override
  String get myPageLoadingMore => '追加の試合を読込み中…';

  @override
  String get myPageLoadMore => 'さらに20件読込む';

  @override
  String get myPageLoadMoreError => '追加の試合を読込めませんでした。表示済みの記録は保持されています。';

  @override
  String get myPageMatchMissing => 'このプロフィールに試合が見つかりません。';

  @override
  String get myPageUnknown => '不明';

  @override
  String get myPageStartedAt => '開始日時（現地時間）';

  @override
  String get myPageEndedAt => '終了日時（現地時間）';

  @override
  String get myPageRecoveredAt => '中断の検出日時（現地時間）';

  @override
  String get myPageMatchTime => 'ゲーム内時間（時:分:秒）';

  @override
  String get myPageXpAwarded => 'この試合の獲得XP';

  @override
  String get myPageAppVersion => 'アプリバージョン';

  @override
  String get myPageRulesVersion => 'ルールバージョン';

  @override
  String get myPageMetricsVersion => '集計バージョン';

  @override
  String get myPageMetricDefinitions =>
      '出兵回数には味方への増援を含みます。派遣兵力は出兵時の兵数です。占領回数には再占領を含み、現在の所有島数とは異なります。ゲーム内時間にはカウントダウンと一時停止を含みません。XPはこの試合に保存された付与額です。';

  @override
  String get myPageTitle => 'マイページ / PROFILE';

  @override
  String get myPageStats => '戦績';

  @override
  String get myPageHistory => '履歴';

  @override
  String get myPageDefaultName => '司令官';

  @override
  String get myPageEdit => 'プロフィール編集';

  @override
  String get myPageLocalDevice => 'この端末に保存。クラウド同期は行いません。';

  @override
  String get myPageProfileSaved => 'プロフィールをこの端末に保存しました。';

  @override
  String get myPageLoading => '保存データを読み込み中…';

  @override
  String get myPageReadError => '保存データを読み込めませんでした。記録は削除していません。';

  @override
  String get myPageRetry => '再試行';

  @override
  String get myPageName => '表示名';

  @override
  String get myPageNameHint => '前後の空白を除き1〜20文字。既定名を使う場合は未入力のままにしてください。';

  @override
  String get myPageInvalidName => '制御文字を含まない1〜20文字で入力してください。';

  @override
  String get myPageAvatar => 'プロフィールアイコン';

  @override
  String get myPageSave => '保存';

  @override
  String get myPageSaving => 'プロフィールを保存中…';

  @override
  String get myPageSaveError => '未保存です。編集内容を保持しています。保存を再試行してください。';

  @override
  String get myPageUnsavedChanges => '未保存の変更があります';

  @override
  String get myPageDiscardTitle => '編集内容を破棄しますか？';

  @override
  String get myPageKeepEditing => '編集を続ける';

  @override
  String get myPageDiscard => '破棄';

  @override
  String get myPageCompleted => '完了試合数';

  @override
  String get myPageWins => '勝利';

  @override
  String get myPageLosses => '敗北';

  @override
  String get myPageDraws => '引分';

  @override
  String get myPageWinRate => '勝率';

  @override
  String get myPageCompletedTime => '完了試合の累計時間（時:分:秒）';

  @override
  String get myPageDispatches => '出兵回数';

  @override
  String get myPageForces => '派遣兵力';

  @override
  String get myPageCaptures => '占領回数';

  @override
  String get myPageAbandoned => '途中終了';

  @override
  String get myPageInterrupted => '結果不明';

  @override
  String get myPageInProgress => '対戦中';

  @override
  String get myPageNoCompleted => '記録された完了試合はまだありません。';

  @override
  String get myPageByDifficulty => '難易度別戦績';

  @override
  String get myPageFastest => '条件別最短勝利時間（時:分:秒）';

  @override
  String get myPageRecent => '最近5試合';

  @override
  String get myPageNoMatches => '記録された試合はまだありません。';

  @override
  String get myPageViewHistory => '履歴を見る';

  @override
  String get myPageMatchDetail => '試合詳細';

  @override
  String myPageTotalXp({required int xp}) {
    return '累積XP: $xp';
  }

  @override
  String myPageMatchXp({required int xp}) {
    return '獲得XP: $xp';
  }

  @override
  String myPageStatsSince({required String date}) {
    return '戦績は$dateの記録開始以降です。それ以前のXPには試合記録がありません。';
  }

  @override
  String myPageAvatarChoice({required int number}) {
    return 'アイコン$number';
  }

  @override
  String get appTitle => 'CONQUEST ISLES';

  @override
  String get titleStart => 'はじめる';

  @override
  String get titleHowToPlay => '遊び方';

  @override
  String get titleHowToGoal => '島を占領して兵力を増やし、相手の軍を全滅させましょう。';

  @override
  String get titleHowToSelect => '1. 兵力が2以上ある、緑色の自軍の島をタップします。';

  @override
  String get titleHowToSend => '2. 別の島をタップすると、兵力の半分を送り出します。自軍の島には増援を送れます。';

  @override
  String get titleHowToCapture =>
      '3. 相手の兵力を上回る部隊を送ると、島を占領できます。相手の島と移動中の部隊をすべてなくすと勝利です。';

  @override
  String get titleSound => 'サウンド';

  @override
  String get titleSoundDescription => 'BGMは対戦設定と一時停止メニューで切り替えられます。';

  @override
  String get titleClose => '閉じる';

  @override
  String get returnTitle => 'タイトルへ戻る';

  @override
  String get startWord => 'START';

  @override
  String get difficultyVeryEasy => 'Very Easy';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get settingsStep => '対戦設定 / 01';

  @override
  String get settingsTitle => '対戦設定';

  @override
  String get settingsDescription => '海域の規模とCPUの判断速度を選択してください。';

  @override
  String get howToPlay => '遊び方';

  @override
  String get tutorialTitle => '遊び方';

  @override
  String get tutorialStepSourceTitle => '1. 自分の島を選ぼう';

  @override
  String get tutorialStepDestinationTitle => '2. 兵士を送ろう';

  @override
  String get tutorialStepCaptureTitle => '3. 島を手に入れよう';

  @override
  String get tutorialStepVictoryTitle => '4. 相手を倒して勝利！';

  @override
  String get tutorialSourceInstruction => '緑の島があなたの島です。「100」の島をタップしましょう。';

  @override
  String get tutorialDestinationInstruction => '枠の付いた灰色の島をタップ。兵士の半分を送ります。';

  @override
  String get tutorialCaptureInstruction => '送った兵士が島の数字より多いと、自分の島にできます。';

  @override
  String get tutorialVictoryInstruction =>
      '自分の島では兵士が1秒に1人増えます。赤い島と移動中の相手部隊をすべてなくすと勝利！';

  @override
  String tutorialDispatchFromTo({required int remaining}) {
    return '出発時：100 → $remaining人';
  }

  @override
  String tutorialDispatchBreakdown({
    required int sent,
    required int remaining,
  }) {
    return '$sent人を送る / $remaining人を残す';
  }

  @override
  String tutorialCaptureValues({
    required int attack,
    required int defense,
    required int captured,
  }) {
    return '$attack − $defense = $captured人';
  }

  @override
  String get tutorialCaptureComplete => '島が緑になりました！';

  @override
  String tutorialGrowthDemo({required int growth}) {
    return '+$growth / 秒';
  }

  @override
  String tutorialProgress({required int step}) {
    return '手順 $step / 4';
  }

  @override
  String tutorialBoardSemantics({required int step}) {
    return '遊び方マップ、4手順中$step手順目';
  }

  @override
  String get tutorialBack => '戻る';

  @override
  String get tutorialNext => '次へ';

  @override
  String get tutorialReturnSettings => '対戦設定へ戻る';

  @override
  String get tutorialLifecyclePaused => '練習を一時停止しました。「再開」で続けられます。';

  @override
  String get tutorialLifecycleResizeRequired => '画面を広げると再開できます。';

  @override
  String get tutorialResume => '再開';

  @override
  String get tutorialSpectatorNotice => '観戦を選んでいても、遊び方では自分で島を選び、兵士を送ります。';

  @override
  String get tutorialRetrySource => '緑の島をタップしてください。';

  @override
  String get tutorialRetryDestination => '枠の付いた灰色の島をタップしてください。';

  @override
  String get tutorialRetryCapture => '兵士が島に着くまで待ってください。';

  @override
  String get tutorialRulesHeading => '覚えておくルール';

  @override
  String get tutorialRuleEqualForces => '同じ数では島を取れません';

  @override
  String get tutorialRuleReinforce => '自分の島にも兵士を送れます';

  @override
  String get tutorialRuleMinimumForces => '兵士が1人以下の島からは送れません';

  @override
  String get rankTitleRecruit => '新兵';

  @override
  String get rankTitlePrivateFirstClass => '一等兵';

  @override
  String get rankTitleLanceCorporal => '上等兵';

  @override
  String get rankTitleCorporal => '伍長';

  @override
  String get rankTitleSergeant => '軍曹';

  @override
  String get rankTitleStaffSergeant => '二等軍曹';

  @override
  String get rankTitleGunnerySergeant => '一等軍曹';

  @override
  String get rankTitleMasterSergeant => '曹長';

  @override
  String get rankTitleFirstSergeant => '専任曹長';

  @override
  String get rankTitleMasterGunnerySergeant => '上級曹長';

  @override
  String get rankTitleSergeantMajor => '最先任上級曹長';

  @override
  String get rankTitleWarrantOfficerOne => '准尉';

  @override
  String get rankTitleChiefWarrantOfficerTwo => '准尉2級';

  @override
  String get rankTitleChiefWarrantOfficerThree => '准尉3級';

  @override
  String get rankTitleChiefWarrantOfficerFour => '准尉4級';

  @override
  String get rankTitleChiefWarrantOfficerFive => '准尉5級';

  @override
  String get rankTitleSecondLieutenant => '少尉';

  @override
  String get rankTitleFirstLieutenant => '中尉';

  @override
  String get rankTitleCaptain => '大尉';

  @override
  String get rankTitleMajor => '少佐';

  @override
  String get rankTitleLieutenantColonel => '中佐';

  @override
  String get rankTitleColonel => '大佐';

  @override
  String get rankTitleBrigadierGeneral => '准将';

  @override
  String get rankTitleMajorGeneral => '少将';

  @override
  String get rankTitleLieutenantGeneral => '中将';

  @override
  String get rankTitleGeneral => '大将';

  @override
  String rankDisplay({required int rank, required String title}) {
    return 'ランク $rank・$title';
  }

  @override
  String rankProgress({required int xp}) {
    return '次の昇級まで $xp XP';
  }

  @override
  String get rankMax => 'MAX';

  @override
  String get islandCountLabel => '島数';

  @override
  String get gameModeLabel => 'ゲームモード';

  @override
  String get cpuDifficultyLabel => 'CPU難易度';

  @override
  String get playerCpuDifficultyLabel => '1P CPU難易度';

  @override
  String get opponentCpuDifficultyLabel => '2P CPU難易度';

  @override
  String get bgmLabel => 'BGM';

  @override
  String get bgmOn => 'オン';

  @override
  String get bgmOff => 'オフ';

  @override
  String bgmToggleSemantics({required String state}) {
    return 'BGM：$state';
  }

  @override
  String get startGame => 'ゲーム開始';

  @override
  String get mapUnavailableMessage =>
      '現在の画面サイズでは盤面を準備できません。ウィンドウを広げるか、縦向きで開き直してください。';

  @override
  String get viewportTooSmallTitle => 'ウィンドウが小さすぎます';

  @override
  String get viewportTooSmallDescription =>
      '盤面を安全に表示できるまで対戦を保持しています。ウィンドウを広げてください。';

  @override
  String get viewportReadyDescription => '盤面を表示できます。「再開」を押すと対戦を続けます。';

  @override
  String selectedSummary({
    required int islandCount,
    required String difficulty,
  }) {
    return '選択中：$islandCount島 / $difficulty';
  }

  @override
  String selectedSummarySpectator({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  }) {
    return '選択中：$islandCount島 / 1P $playerDifficulty / 2P $cpuDifficulty';
  }

  @override
  String get modePlayerVsCpu => 'CPU対戦';

  @override
  String get modeCpuVsCpu => 'CPU同士を観戦';

  @override
  String startGameSemantics({
    required int islandCount,
    required String difficulty,
  }) {
    return '$islandCount島、$difficulty CPUでゲームを開始';
  }

  @override
  String startSpectatorSemantics({
    required int islandCount,
    required String playerDifficulty,
    required String cpuDifficulty,
  }) {
    return '$islandCount島、1P $playerDifficulty、2P $cpuDifficultyのCPU対戦を観戦';
  }

  @override
  String islandCountChoice({required int count}) {
    return '$count島';
  }

  @override
  String difficultyChoice({required String owner, required String difficulty}) {
    return '$owner$difficulty CPU難易度';
  }

  @override
  String boardMapSemantics({required int islandCount}) {
    return '島のマップ、$islandCount島';
  }

  @override
  String boardTitle({required String difficulty, required int islandCount}) {
    return '$difficulty / $islandCount島';
  }

  @override
  String boardTitleSpectator({
    required String playerDifficulty,
    required String cpuDifficulty,
    required int islandCount,
  }) {
    return '1P $playerDifficulty / 2P $cpuDifficulty / $islandCount島';
  }

  @override
  String get boardStatusSelected => '出兵元を選択中';

  @override
  String get boardStatusSelectedDetail => 'タップで目標を指定\n兵力の半分を派遣';

  @override
  String get spectatorStatus => '観戦中';

  @override
  String get spectatorDetail => 'CPU同士の対戦を表示中';

  @override
  String get pauseGame => '対戦を一時停止';

  @override
  String get pauseHeading => '対戦を一時停止';

  @override
  String get pauseTitle => '一時停止';

  @override
  String get pauseDescription => '現在の盤面を確認できます。';

  @override
  String get resume => '再開';

  @override
  String get returnSettings => '設定へ戻る';

  @override
  String get quitTitle => '対戦を終了しますか？';

  @override
  String get quitDescription =>
      'この対戦は再開できません。通常対戦は保存に成功すると途中終了として記録されます。観戦・練習は記録されません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get quit => '終了';

  @override
  String get resultHeading => '戦闘終了';

  @override
  String get victory => '勝利';

  @override
  String get defeat => '敗北';

  @override
  String get draw => '引き分け';

  @override
  String get matchSummaryHeading => '試合サマリー';

  @override
  String matchSummarySettings({
    required int islandCount,
    required String difficulty,
  }) {
    return '$islandCount島 / CPU $difficulty';
  }

  @override
  String matchSummaryTime({required String time}) {
    return '対戦時間 $time';
  }

  @override
  String matchSummaryDispatches({required int count}) {
    return '兵力派遣回数 $count回';
  }

  @override
  String matchSummaryForces({required int forces}) {
    return '派遣兵力数 $forces';
  }

  @override
  String matchSummaryCaptures({required int count}) {
    return '占領した島 $count';
  }

  @override
  String matchSummarySemantics({
    required String settings,
    required String time,
    required String dispatches,
    required String forces,
    required String captures,
  }) {
    return '試合サマリー。$settings。$time。$dispatches。$forces。$captures。';
  }

  @override
  String xpEarned({required int xp}) {
    return '+$xp XP';
  }

  @override
  String rankUp({required int rank, required String title}) {
    return '昇級！ ランク $rank・$title';
  }

  @override
  String get spectatorPlayerWin => '1P 勝利';

  @override
  String get spectatorCpuWin => '2P 勝利';

  @override
  String get spectatorDraw => '引き分け';

  @override
  String get replay => '新しいマップで対戦';

  @override
  String countdownSemantics({required String countdown}) {
    return 'ゲーム開始 $countdown';
  }

  @override
  String get prepareToDeploy => '出撃準備';

  @override
  String get sourceBadge => '出兵元';

  @override
  String get factionPlayer => 'プレイヤー';

  @override
  String get factionCpu => 'CPU';

  @override
  String get factionNeutral => '中立';

  @override
  String get factionPlayerOne => '1P';

  @override
  String get factionPlayerTwo => '2P';

  @override
  String get islandSizeSmall => '小島';

  @override
  String get islandSizeMedium => '中島';

  @override
  String get islandSizeLarge => '大島';

  @override
  String get islandSizeHeadquarters => '本拠地';

  @override
  String islandOwnedSemantics({
    required String faction,
    required String size,
    required int forces,
    required int capacity,
    required int value,
  }) {
    return '$factionの$size、兵力$forces/$capacity、現在値$value';
  }

  @override
  String islandNeutralSemantics({
    required String faction,
    required String size,
    required int durability,
    required int value,
  }) {
    return '$factionの$size、耐久力$durability、現在値$value';
  }

  @override
  String get islandActionSelected => '出兵元を選択中';

  @override
  String get islandActionDestination => '出兵可能な目標';

  @override
  String get islandActionAvailable => '出兵元として選択可能';

  @override
  String get islandActionUnavailable => '出兵元として選択不可';

  @override
  String get islandHintSelected => 'もう一度タップして選択を解除するか、出兵可能な目標を選択してください。';

  @override
  String get islandHintDestination => 'タップしてここへ出兵します。';

  @override
  String get islandHintAvailable => 'タップしてこの島を出兵元に選択します。';

  @override
  String get islandHintUnavailable => 'この島は出兵元に選択できません。';

  @override
  String movingForceSemantics({
    required String faction,
    required int strength,
    required int value,
    required int source,
    required int destination,
  }) {
    return '$factionの移動部隊、兵力$strength、現在値$value、島$sourceから島$destinationへ移動中、操作不可、タップ不可';
  }

  @override
  String get feedbackUnavailableSource => '兵力が2以上ある自軍の島を選択してください。';

  @override
  String get feedbackInvalidatedSource => '出兵できません。出兵元は自軍が所有し、兵力が2以上必要です。';

  @override
  String get bgmUnavailableMessage => 'BGMを再生できません。音なしで対戦を続けます。';

  @override
  String get bgmRetry => 'BGMを再生';

  @override
  String get rematch => '同じマップで再戦';

  @override
  String get rematchHint => '同じマップ・難易度で再戦します';

  @override
  String get rematchSpectatorHint => '同じマップ・両CPUの難易度で再戦します';

  @override
  String get rematchMissing => '再戦用の初期盤面を利用できません';

  @override
  String get rematchEnlarge => '同じマップで再戦するには画面を広げてください';

  @override
  String get storageChecking => '端末の保存領域を確認中…';

  @override
  String get storageOwned =>
      '先に開いたConquestタブを使うか、そのタブを閉じて再試行してください。2つのタブで通常対戦は開始できません。';

  @override
  String get storageUnavailable => '端末保存が利用できません。ゲームは続行できます。未保存の試合は再試行できます。';

  @override
  String get matchSaving => '試合を保存中…';

  @override
  String get matchUnsaved => '試合が未保存です';

  @override
  String get matchSaved => '試合を保存しました';

  @override
  String get storageRetry => '保存を再試行';

  @override
  String get rankUnavailable => '保存データの読込み後に階級を表示します';
}

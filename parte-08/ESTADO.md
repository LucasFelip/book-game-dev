# Estado da Parte VIII — Engenharia

## 1. Capítulos concluídos

- [x] Cap. 56 — Save Systems (`cap-56-save-systems.md`)
- [x] Cap. 57 — Persistence (`cap-57-persistence.md`)
- [x] Cap. 58 — Performance (`cap-58-performance.md`)
- [x] Cap. 59 — Profiling (`cap-59-profiling.md`)
- [x] Cap. 60 — Optimization (`cap-60-optimization.md`)
- [x] Cap. 61 — Debugging (`cap-61-debugging.md`)
- [x] Cap. 62 — Packaging (`cap-62-packaging.md`), com o bloco "Estado do Livro (fim da Parte VIII)" e "➡️ Próximo" para `../interludio-2/decompondo-mundo-aberto.md`

Cabeçalho de parte no Cap. 56. A seção de projeto dos capítulos se chama **"Projeto Vigília — …"** (a Parte VIII não tem número de projeto próprio; o coordenador pode harmonizar com a Parte VII).

## 2. Classes, tags, CVars, cheats e testes (nomes exatos)

### Cap. 56
- `Save/VGSaveGame.h`: `FVGPlayerRecord` (`BatteryCharge` (-1 = não gravado), `Weapon` `TSoftClassPtr<AVGWeapon>`, `AmmoInMagazine`, `ReserveAmmo`, `Items` (`Item.*`), legado `Flares` só para a migração 1→2); `UVGSaveGame : USaveGame` (`SaveVersion` (padrão 0), `SavedAtUtc`, `BuildVersion`, `MapName` (nome curto), `CheckpointId`, `Narrative` (`FVGNarrativeState`), `Player`). Campos com `UPROPERTY(SaveGame)`.
- `Save/VGSaveRules.h/.cpp`: `namespace VGSaveRules` — `CurrentVersion = 2`, `SlotName = "Vigilia_Checkpoint"`, `UserIndex = 0`, `Migrate(UVGSaveGame&, FString&)`, `FCheckpointContext`, `CanCheckpoint` (viva, sem `Hunting`, sem `Peak`, sem cinemática).
- `Save/VGSaveSubsystem.h/.cpp`: `UVGSaveSubsystem : UGameInstanceSubsystem` — `Get`, `RequestCheckpoint(FName)`, `ForceCheckpoint`, `HasSave`, `ContinueGame`, `ReloadLastCheckpoint`, `StartNewGame(FName FirstMap)`, `ApplyPendingLoad` (chamado em `AVGGameMode::InitGame`), `ConsumeSpawnCheckpoint`, `StorePlayerRecord`/`ConsumePlayerRecord`, `CapturePlayer`/`ApplyPlayer` (estáticos), `DescribeForDebug`; delegates nativos `OnCheckpointSaved(bool)` e `OnLoadFailed`. Gravação `AsyncSaveGameToSlot`, uma por vez (`bSaveQueued`); retry de 0,5 s pelo timer do `UGameInstance` enquanto o momento não é seguro.
- `Save/VGCheckpoint.h/.cpp`: `AVGCheckpoint : APlayerStart` com `SaveVolume` (`UBoxComponent`, perfil `Trigger`); `PlayerStartTag` = id do checkpoint.
- 🔁 `AVGGameMode`: `InitGame` (→ `ApplyPendingLoad`), `ChoosePlayerStart_Implementation` (checkpoint por `PlayerStartTag`), `HandleRespawnRequest(AController*)`.
- 🔁 `AVGPlayerController::RequestRespawn` → `AVGGameMode::HandleRespawnRequest`.
- 🔁 `AVGCharacter`: `BeginPlay` consome o registro; `EndPlay(LevelTransition)` guarda o registro.
- 🔁 `AVGWeapon::RestoreAmmo(int32 InMagazine, int32 Reserve)` (com `Clamp`).
- 🔁 `FVGNarrativeState`: campos marcados `UPROPERTY(SaveGame)`.
- Tag nativa nova: `TAG_Item` (`"Item"`).
- Cheats: `VGSave`, `VGLoad`, `VGDumpSave`, `VGDeleteSave`; 🔁 `VGNewGame` → `StartNewGame(nível atual)`.
- Teste: `FVGSaveTest`, `"Vigilia.Save.RoundTripMigrationGate"` (ida e volta em memória, migração 1→2, recusa sem versão/do futuro, trava de momento).
- Build.cs: `EngineSettings` (para `UGeneralProjectSettings::ProjectVersion`).
- Conteúdo: `CP_S1_Hall`, `CP_S1_Corredor`, `CP_S1_Subsolo`, `CP_S1_Controle` em `L_CasaDeForca`; `docs/design/save.md`; `Tests/SaveFixtures/`.

### Cap. 57
- `Save/VGSaveGame.h`: `FVGActorRecord` (`bDestroyed`, `bHasTransform`, `Transform`, `Properties` `TArray<uint8>`); `UVGSaveGame::World` (`TMap<FGuid, FVGActorRecord>`), **sem** subir `SaveVersion`.
- `Save/VGPersistence.h/.cpp`: `namespace VGPersistence` — `WriteSaveGameProperties(UObject&, TArray<uint8>&)` / `ReadSaveGameProperties(UObject&, const TArray<uint8>&)` com `FMemoryWriter/Reader` + `FObjectAndNameAsStringProxyArchive`, `ArIsSaveGame = true`, `ArNoDelta = true`.
- `Save/VGPersistenceComponent.h/.cpp`: `UVGPersistenceComponent` — `PersistentId` (`FGuid`, gerado em `OnRegister` no editor; regenerado em `PostEditImport` e `PostDuplicate(!PIE)`), `bSaveTransform`, `RestoreOwner()` (contrato: chamado no FIM do `PostInitializeComponents` do dono), `CaptureOwner()`, `BeginPlay` (registra; destrói se o registro diz "destruído"), `EndPlay` (Destroyed → registro destruído; RemovedFromWorld/LevelTransition → captura). Recusa atores sem id (spawnados) com aviso.
- 🔁 `UVGSaveSubsystem`: `RegisterPersistent`/`UnregisterPersistent` (duplicata → `ensureMsgf`), `FindRecord`, `StoreRecord`, `CaptureLiveWorld`, `DescribeWorldForDebug`; `WorldRecords` (um mapa só, global) e `LiveComponents`. `WriteCheckpoint` captura e copia para `Save->World`; `ApplyPendingLoad` substitui `WorldRecords` (depois da desmontagem do mundo velho) e zera `LiveComponents`; `StartNewGame` zera.
- 🔁 `AVGDoor`: `State`/`OpenAlpha` com `UPROPERTY(SaveGame)`; estado inicial movido do `BeginPlay` para `PostInitializeComponents` + `RestoreOwner`; `SnapToState()` silencioso; `ApplyNavArea()` extraído do `TransitionTo` (Cap. 35); `BeginPlay` só tranca se `State == Closed` e o disjuntor está desligado.
- 🔁 `AVGBreakerSwitch` (`bIsOn` SaveGame), `AVGEventTrigger` (`bHasTriggered` SaveGame), `AVGPickup` (só o componente).
- 🔁 `AVGSector`: derivado do disjuntor no `BeginPlay` via `SetPowered(bool bAnnounce)` (restauração não publica `Event.Sector.Powered`).
- 🔁 `AVGReadable::BeginPlay`: esconde se `bTakeOnRead` e o `ReadFact` existe (derivado dos fatos; resolve o "o Cap. 57 decide se ele volta").
- Teste: `FVGPersistenceTest`, `"Vigilia.Save.Persistence.SaveGameFilterNoDelta"`, com a classe `UVGPersistenceTestObject` (`Tests/VGPersistenceTestTypes.h`).
- Cheat: `VGDumpPersistence`.
- Conteúdo: subnível de teste `L_CasaDeForca_Deposito` (exercício de *streaming*).

### Cap. 58
- `Core/VGStats.h/.cpp`: `STATGROUP_Vigilia` (`stat Vigilia`); ciclos `STAT_VGAwarenessTick`, `STAT_VGDirectorTick`, `STAT_VGInteractionScan`, `STAT_VGFlickerTick`, `STAT_VGDialogueTick`, `STAT_VGQuestDrain`, `STAT_VGSaveCapture`; contador `STAT_VGFlickerTicks` (`DECLARE_DWORD_COUNTER_STAT_EXTERN`). `SCOPE_CYCLE_COUNTER` nos ticks/scan/drain e em `WriteCheckpoint`.
- `Debug/VGPerfRules.h/.cpp`: `FVGFrameTimes`, `EVGFrameBound` (WithinBudget/GameThread/RenderThread/RhiThread/Gpu), `namespace VGPerfRules` — `BudgetMs`, `Classify`, `Percentile`, `ToString`.
- Cheat: `VGPerfCapture(float Seconds = 10, float TargetFps = 60)` — `FTSTicker`, lê `GGameThreadTime`/`GRenderThreadTime`/`GRHIThreadTime`/`RHIGetGPUFrameCycles(0)` (⚠️ marcado), escreve uma linha `PERF ...` no log.
- Teste: `FVGPerfRulesTest`, `"Vigilia.Perf.Rules.BudgetBoundPercentile"`.
- Build.cs: `RHI`.
- Docs: `docs/tech/maquina-alvo.md`, `docs/tech/orcamento.md`.

### Cap. 59
- Marcadores `TRACE_BOOKMARK` (`ProfilingDebugging/MiscTrace.h`): `UVGDirectorSubsystem::EnterPhase` ("Director: <fase>", via `UEnum::GetValueAsString` se `EVGDirectorPhase` for `UENUM`), `UVGSaveSubsystem::WriteCheckpoint` ("Checkpoint: <id>"), `AVGGameMode::InitGame` ("Level: <mapa>"), início/fim de cinemática (ator do Cap. 49).
- Cheat: `VGPerfHunt(float Seconds = 20)` — `PushScriptLock(Peak, "PerfHunt")` + `VGPerfCapture` + `PopScriptLock` por timer (`CreateWeakLambda`), com marcadores.
- Conteúdo: decalque `M_PerfMark` em `/Game/Developers/` no corredor.
- Sem teste automatizado (sem lógica nova não trivial; declarado no capítulo).
- **Sessão de profiling da caçada: números [HIPOTÉTICO], explicitamente ilustrativos** (o capítulo não afirma medições reais). Achados: H1 sombras de 9 lâmpadas (corrigido: sombra só em 2), H2 EQS da Presença num frame, H3 PSO do material de dissolução da Presença (frio), H4 40 `Flicker Ticks`/frame, H5 *overdraw* da névoa → Cap. 60.

### Cap. 60
- `World/VGSignificanceRules.h/.cpp`: `namespace VGSignificanceRules` — `FlickerSignificance(Distance, FacingDot, MaxDistance)` (atrás conta metade), `FlickerTickInterval(Significance)` (≥0,5 → 0 = todo frame; ≥0,1 → 0,1 s; senão −1 = parado).
- 🔁 `UVGFlickerComponent`: `SignificanceDistance` (4000 cm); registra no Significance Manager (tag `VGFlicker`; avaliação só lê; pós-significância `Sequential` liga/desliga tick e ajusta intervalo); desregistra no `EndPlay`. Sem manager, comportamento antigo.
- 🔁 `AVGPlayerController::PlayerTick`: `USignificanceManager::Update` com a câmera (um ponto de vista).
- 🔁 `UVGAwarenessComponent`: intervalo 0,25 s em `Unaware`, 0,1 s nos demais.
- Configuração: inimigos (Presença, vigias) com `VisibilityBasedAnimTickOption = AlwaysTickPose` + `bEnableUpdateRateOptimizations` (URO); EQS da caçada com intervalo 0,5 s + *Random Deviation* 0,15, menos pontos, testes baratos primeiro, `MaxAllowedTestingTime` (⚠️); névoa da curva com menos *cards* + *depth fade*; lâmpadas pequenas com *Max Draw Distance*.
- Padrões apresentados e **não aplicados** (recusas declaradas): carga assíncrona das vozes do diálogo (`TSoftObjectPtr` + `FStreamableManager::RequestAsyncLoad`, handle por conversa) até o `memreport` pedir; `FVGSpatialGrid` (laboratório); sem pool de sinalizadores; sem paralelismo próprio.
- Teste: `FVGSignificanceRulesTest`, `"Vigilia.Perf.Significance.FlickerPolicy"`.
- Build.cs: `SignificanceManager` (+ *plugin* habilitado no `.uproject`).
- Cobertos (pedido do coordenador / Interlúdio II): *World Partition*, HLOD (camadas), Significance Manager, URO + `VisibilityBasedAnimTickOption`, grade espacial; cita `UVGPopulationSubsystem` (LOD de simulação, fatia fixa, `Reduced` a 0,25 s) e a regra dos anéis como referência adiante; *City Sample* como estudo de caso.

### Cap. 61
- `Debug/VGDebugRules.h/.cpp`: `VGDebugRules::GroupByPrefix(const TArray<FString>&)` → grupos ordenados (descarta 2 segmentos; 3º = grupo; resto = item; curtos → "-"). 🔁 `vg.Debug.Narrative` passa a usá-la.
- `Debug/VGGameplayDebuggerCategories.h/.cpp` (`#if WITH_GAMEPLAY_DEBUGGER`): `FVGGameplayDebuggerCategory_Narrative` (global, `bShowOnlyWithDebugActor = false`: fatos agrupados, contadores, quests, `DescribeForDebug`/`DescribeWorldForDebug` do save) e `FVGGameplayDebuggerCategory_AI` (por agente: consciência, alvo visível, última posição como `FGameplayDebuggerShape::MakePoint`; ameaça e Diretor). Dados em `FRepData { TArray<FString> Lines; }` com `SetDataPackReplication`.
- 🔁 `Vigilia.cpp`: `FVigiliaModule : FDefaultGameModuleImpl` registra as categorias "VigiliaNarrative" (slot 6) e "VigiliaAI" (slot 7); `IMPLEMENT_PRIMARY_GAME_MODULE(FVigiliaModule, Vigilia, "Vigilia")`.
- Build.cs: `if (Target.bUseGameplayDebugger) PrivateDependencyModuleNames.Add("GameplayDebugger");` (⚠️ macro por versão).
- 🔁 `AVGAIController::GrabDebugSnapshot` (`#if ENABLE_VISUAL_LOG`): categoria "Vigilia: consciência". `UE_VLOG_LOCATION` na transição de consciência; `UE_VLOG` no `EnterPhase` do Diretor.
- Cheats: `VGGotoCheckpoint(FName)`, `VGGod(bool)` (🔁 `UVGHealthComponent::SetInvulnerable(bool)`), `VGAIFreeze(bool)` (`PauseLogic`/`ResumeLogic` + `StopMovement`). Regra: cheats explícitos, idempotentes, com log `Cheat:`.
- Teste: `FVGDebugRulesTest`, `"Vigilia.Debug.Rules.GroupFactsByPrefix"`.
- Docs: `docs/qa/ferramentas.md`, `docs/qa/receitas.md`.
- Dor 9 ✅ → **as 12 dores do Interlúdio I resolvidas**.

### Cap. 62
- `Source/Vigilia.Target.cs` (alvo `Game`, `BuildSettingsVersion.Latest`, Shipping padrão).
- `Config/DefaultGame.ini`: `ProjectVersion=0.8.0`; `GameDefaultMap=L_MenuPrincipal`; `ProjectPackagingSettings` (Shipping, pak, IoStore, pré-requisitos, sem debug files; `MapsToCook` = `L_MenuPrincipal`, `L_Patio`, `L_CasaDeForca`; `DirectoriesToAlwaysCook` = `/Game/Vigilia/Data`; `DirectoriesToNeverCook` = `/Game/Developers`); `AssetManagerSettings` com `VGDocument` (`AlwaysCook`).
- Teste (editor): `FVGBuildContentTest`, `"Vigilia.Build.Content.CookRules"` (`#if WITH_DEV_AUTOMATION_TESTS && WITH_EDITOR`; documentos registrados, `DA_FatosDoJogo` em diretório sempre cozido, lista de mapas não vazia e sem `/Developers/`).
- Build.cs: `if (Target.bBuildEditor) PrivateDependencyModuleNames.Add("UnrealEd");`.
- `Tools/BuildVigilia.bat`: testes (`UnrealEditor-Cmd ... Automation RunTests Vigilia`) → `RunUAT BuildCookRun -build -cook -stage -pak -iostore -prereqs -archive` → cópia dos `.pdb` para `Builds/<Cfg>-Symbols`.
- Lista de verificação de máquina limpa (8 itens) e H3 (PSO) medida no build Test; cache de PSO empacotado só se o *hitch* frio passar de 33 ms.

## 3. Decisões firmadas

1. Checkpoints automáticos, **um slot**, morte = recarregar o último checkpoint; sem save manual e sem save ao sair.
2. Trava de momento: só grava com a jogadora viva, ameaça ≠ `Hunting`, Diretor ≠ `Peak`, sem cinemática. O checkpoint registra o lugar; o momento espera a calma. Pedido pendente é descartado no load.
3. A posição é o **nome** do checkpoint (`PlayerStartTag`), não um transform.
4. 🔁 A **vida não é salva** (revisão da tabela do Cap. 23): regeneração + trava tornam o campo redundante.
5. Carregar = reabrir o nível: narrativa em `InitGame`, checkpoint em `ChoosePlayerStart`, jogadora no `BeginPlay` dela ("quem é restaurado puxa o estado quando está pronto").
6. Versionamento: `SaveVersion` com padrão neutro (0), migrações puras e imutáveis, recusa explícita; nomes (tags, assets, checkpoints) não se renomeiam; arquivos reais de cada versão em `Tests/SaveFixtures/`.
7. Opções ficam em `UGameUserSettings`, nunca no save de progresso.
8. (Cap. 57) Mundo = conteúdo + diferença; a Vigília persiste alterados, destruídos e movidos, **deriva** o resto (setor pelo disjuntor, documentos pelos fatos, encontros de vigias pelo fato de resultado `S2.GuardsCleared` via contador) e **não persiste atores spawnados**. Liga-se à distinção identidade × agregado do Interlúdio II (citada adiante).
9. (Cap. 57) Restaurar ≠ reencenar: estado em silêncio (sem som, ruído de IA ou eventos); atores restauram no fim do `PostInitializeComponents`; push no `EndPlay`, pull na inicialização (cobre checkpoint, troca de nível e *streaming*).
10. (Cap. 58) **Orçamento [DECISÃO DE PROJETO, revisto no Cap. 83]:** 60 FPS a 1080p na máquina-alvo (documentada, real), preset Médio, cada estágio ≤ 14 ms no pior cenário; nenhum frame > 33 ms fora de carregamento. Game thread: IA 1,0 · animação 1,5 · física 1,0 · UI 1,0 · gameplay/BP 2,0 · narrativa 0,3 · áudio 0,5 ms. GPU: iluminação/sombras/Lumen 7,0 · base pass 3,0 · translucidez/VFX 1,5 · pós/upscaling 1,5 ms. Frame de checkpoint ≤ 2 ms. Cenários de pior caso: caçada no corredor, frame do checkpoint, primeira entrada no subsolo (PSO), Salão das Turbinas (futuro). Não há modo 120 (desafio).
11. (Cap. 59) Método fixo de profiling (reproduzir, medir, localizar, hipótese escrita, uma mudança, medir, registrar); medições fria e quente, três repetições, mediana; `stat` triagem, Insights diagnóstico, CSV regressão.
12. (Cap. 60) Ordem do ataque (não fazer → menos vezes → menos coisas → mais barato → paralelo); sombra só onde é vista; Nanite/WP/HLOD do Salão das Turbinas decididos por profiling no Cap. 77 (critérios escritos no Cap. 60); `AlwaysTickPose` nos inimigos (os *notifies* de passo não podem sumir fora da tela); recusas declaradas (vozes assíncronas, grade espacial, pool de sinalizadores, paralelismo próprio).
13. (Cap. 61) O painel é o Gameplay Debugger (VigiliaNarrative + VigiliaAI); cheats pela API, explícitos (`1`/`0`), com log `Cheat:`, fora do Shipping; `check` sem efeito colateral, `ensure` para o recuperável, `IsValid` para o que pode sumir.
14. (Cap. 62) Development = dia a dia, Test = medir, Shipping = jogadora, DebugGame = depurar o próprio código. Lista **explícita** de mapas (Galpão, Arena e laboratório ficam fora por omissão); `/Game/Developers` nunca cozido; `/Game/Vigilia/Data` sempre cozido; `VGDocument` com `CookRule=AlwaysCook`. Shipping padrão (sem logs/checks/console/cheats); versão no menu e no save; símbolos arquivados por build; máquina limpa como critério de pronto. Versão do fim da Parte VIII: `0.8.0`.

## 4. Pendências para os capítulos seguintes

- Desafios opcionais: rotação de dois slots (Cap. 56), persistência de atores spawnados (Cap. 57), modo 120 (Cap. 58), comparação automática de CSV (Cap. 59), política "top N" de significância (Cap. 60), `VGValidateLevel` (Cap. 61), teste no build empacotado (Cap. 62).
- **Cap. 77:** decidir *World Partition*/HLOD/Nanite para o Salão das Turbinas com os critérios do Cap. 60.
- **Cap. 83:** ✅ orçamento revisto no jogo inteiro; portão automatizado (`Tools/PerfGate.bat`, `Tools/perf_gate.py`, `Tools/perf_budget.json`).
- **Cap. 84:** reutilizar `Tools/BuildVigilia.bat`, a lista de máquina limpa e o arquivo de símbolos.
- **Números de profiling:** a sessão do Cap. 59 é **[HIPOTÉTICO]** (ilustrativa); nenhum número de medição real foi afirmado na Parte VIII.

## 5. Ajustes sugeridos em capítulos de outras partes (não editados)

- **Cap. 46:** (a) marcar os campos de `FVGNarrativeState`/`FVGQuestRecord` com `UPROPERTY(SaveGame)` (o Cap. 56 mostra o 🔁); (b) deixar explícito que o `UVGQuestSubsystem` se inscreve em `OnRestored` no `OnWorldBeginPlay` (depois de enfileirar a retomada), porque o Cap. 56 restaura a snapshot em `AVGGameMode::InitGame` e uma inscrição no `Initialize` retomaria as quests duas vezes.
- **Cap. 23:** a tabela de estado marca a vida como salvável; o Cap. 56 revisa para "não salva" (com motivo). Talvez uma nota de rodapé "revisto no Cap. 56".
- **Cap. 49:** o Cap. 56 usa `UVGCinematicSubsystem::IsPlaying()` na trava de checkpoint (o comentário do Cap. 49 já diz "consultado pelo save (Cap. 56)"). Confirmar o nome final.
- **Cap. 55 (Parte VII):** a UI consome `UVGSaveSubsystem`: ícone de "salvando" (`OnCheckpointSaved`), "Continuar" (`HasSave`/`ContinueGame`), "Novo jogo" com confirmação (`StartNewGame`), mensagem de falha (`OnLoadFailed`), e opções em `UGameUserSettings`.
- **Cap. 35:** o Cap. 57 pede extrair a atualização do modificador de navegação de `AVGDoor::TransitionTo` para `ApplyNavArea()`; se o Cap. 35 já tiver um nome para isso, o Cap. 57 deve usá-lo.
- **Caps. 23–24:** o Cap. 57 assume que o `AVGSector` tem um método de energização que pode receber `bAnnounce` (`SetPowered`); harmonizar com o nome real, se houver.
- **Cap. 48:** o comentário "o Cap. 57 decide se ele volta" agora tem resposta (volta se não foi lido; derivado dos fatos no `BeginPlay`).
- **Interlúdio II / Cap. 77:** o Salão das Turbinas pode usar *World Partition* ou *streaming*; o `UVGPersistenceComponent` já cobre `RemovedFromWorld`.
- **Cap. 22:** `UVGHealthComponent` ganha `SetInvulnerable(bool)` (Cap. 61); `RequestRespawn` delega ao GameMode (Cap. 56).
- **Caps. 36 e 42:** os Caps. 59–61 usam `UEnum::GetValueAsString`/`GetDisplayValueAsText` em `EVGDirectorPhase` e `EVGThreatLevel`, o que exige `UENUM()`; os capítulos indicam a alternativa com `switch` se não forem.
- **Cap. 11 / Cap. 18 / Cap. 55:** `vg.Flicker.Enabled` e `vg.Camera.Motion` precisam estar no menu de opções e gravados em `UGameUserSettings` (sem console em Shipping, Cap. 62). Pedido explícito para a Parte VII.
- **Cap. 55:** mostrar a versão (`ProjectVersion`) num canto do menu principal (Cap. 62).
- **Cap. 76:** a "máquina-alvo" do risco do Salão das Turbinas agora é definida no Cap. 58 (`docs/tech/maquina-alvo.md`).
- **Cap. 32:** concordo com o Interlúdio II: o `Release` do pool só desliga o tick do ator; o Cap. 60 cita isso nas armadilhas.
- **README:** registrar as classes da Parte VIII (seção 2) e o fim das 12 dores do Interlúdio I.
- **Guia, seção 8:** cita `FVGNarrativeSnapshot`; o nome real é `FVGNarrativeState` (o guia já diz que o capítulo real prevalece).

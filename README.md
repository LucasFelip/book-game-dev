# Desenvolvimento de Jogos com IA — livro de estudos personalizado

Unreal Engine 5 · C++ · Blueprint · Game AI · Narrativa · Multiplayer · IA generativa

**PDF:** gerado pela CI a cada push na `main` (artefato `livro-gamedev-ia-pdf` em *Actions*) e anexado às releases das tags `v*`. Localmente: `bash pdf/build.sh` (precisa de pandoc e xelatex).

## Índice

- [Introdução: perfil, lacunas, mapa de competências, roadmap, cronograma](00-introducao.md)

### Parte I — Pensando como Game Developer ✅
1. [O que diferencia software de jogos](parte-01/cap-01-software-vs-jogos.md)
2. [Game Loop](parte-01/cap-02-game-loop.md)
3. [Frames, Delta Time e Update](parte-01/cap-03-frames-delta-time-update.md)
4. [Estado e eventos](parte-01/cap-04-estado-e-eventos.md)
5. [Gameplay Loop](parte-01/cap-05-gameplay-loop.md)
6. [Game Architecture](parte-01/cap-06-game-architecture.md)

### Parte II — Unreal Engine 5 · Projeto 1 (Pátio da Usina) ✅
7. [Conhecendo a Engine](parte-02/cap-07-conhecendo-a-engine.md)
8. [Actors](parte-02/cap-08-actors.md)
9. [Components](parte-02/cap-09-components.md)
10. [Gameplay Framework](parte-02/cap-10-gameplay-framework.md)
11. [C++ na Unreal](parte-02/cap-11-cpp-na-unreal.md)
12. [Blueprint](parte-02/cap-12-blueprint.md)
13. [C++ + Blueprint](parte-02/cap-13-cpp-e-blueprint.md)
14. [Input](parte-02/cap-14-input.md)
15. [Collision e Physics](parte-02/cap-15-collision-e-physics.md)

### Parte III — Gameplay Programming · Projeto 3 (Interação) ✅ · Projeto 2 (início) ✅
16. [Player Controller](parte-03/cap-16-player-controller.md)
17. [Character](parte-03/cap-17-character.md)
18. [Camera](parte-03/cap-18-camera.md)
19. [Interaction](parte-03/cap-19-interaction.md)
20. [Weapons](parte-03/cap-20-weapons.md)
21. [Combat](parte-03/cap-21-combat.md)
22. [Health/Damage](parte-03/cap-22-health-damage.md)
23. [Gameplay State](parte-03/cap-23-gameplay-state.md)
24. [Events e comunicação](parte-03/cap-24-events-e-comunicacao.md)

### Parte IV — Construindo um FPS · Projeto 2 (Galpão de Testes) ✅
25. [FPS Controller](parte-04/cap-25-fps-controller.md)
26. [Weapon System](parte-04/cap-26-weapon-system.md)
27. [Hitscan](parte-04/cap-27-hitscan.md)
28. [Projectile](parte-04/cap-28-projectile.md)
29. [Recoil](parte-04/cap-29-recoil.md)
30. [Enemy](parte-04/cap-30-enemy.md)
31. [Objectives](parte-04/cap-31-objectives.md)
32. [Spawn System](parte-04/cap-32-spawn-system.md)

### Interlúdio I — Projeto 4: "Turno da Noite" ✅
- [Projeto 4 — Turno da Noite (versão ingênua)](interludio-1/projeto-4-turno-da-noite.md)

### Parte V — Game AI · Projeto 5 (o Vigia e a Presença) ✅
33. [Introdução à Game AI](parte-05/cap-33-introducao-game-ai.md)
34. [FSM](parte-05/cap-34-fsm.md)
35. [Navigation](parte-05/cap-35-navigation.md)
36. [Perception](parte-05/cap-36-perception.md)
37. [Behavior Trees](parte-05/cap-37-behavior-trees.md)
38. [Blackboard](parte-05/cap-38-blackboard.md)
39. [EQS](parte-05/cap-39-eqs.md)
40. [Utility AI](parte-05/cap-40-utility-ai.md)
41. [Tactical AI](parte-05/cap-41-tactical-ai.md)
42. [Squad AI](parte-05/cap-42-squad-ai.md)

### Parte VI — Narrative Games · Projeto 6 (refatoração do Turno da Noite)
[43. Narrative Design](parte-06/cap-43-narrative-design.md) · [44. Dialogue Systems](parte-06/cap-44-dialogue-systems.md) · [45. Quest Systems](parte-06/cap-45-quest-systems.md) · [46. Narrative State](parte-06/cap-46-narrative-state.md) · [47. Branching](parte-06/cap-47-branching.md) · [48. Environmental Storytelling](parte-06/cap-48-environmental-storytelling.md) · [49. Cinematics](parte-06/cap-49-cinematics.md) ✅

### Parte VII — World Building ✅
50. [Level Design](parte-07/cap-50-level-design.md)
51. [Lighting](parte-07/cap-51-lighting.md)
52. [Audio](parte-07/cap-52-audio.md)
53. [Animation](parte-07/cap-53-animation.md)
54. [VFX](parte-07/cap-54-vfx.md)
55. [UI/UX](parte-07/cap-55-ui-ux.md)

### Parte VIII — Engenharia ✅
56. [Save Systems](parte-08/cap-56-save-systems.md)
57. [Persistence](parte-08/cap-57-persistence.md)
58. [Performance](parte-08/cap-58-performance.md)
59. [Profiling](parte-08/cap-59-profiling.md)
60. [Optimization](parte-08/cap-60-optimization.md)
61. [Debugging](parte-08/cap-61-debugging.md)
62. [Packaging](parte-08/cap-62-packaging.md)

### Interlúdio II ✅
- [Decompondo um mundo aberto: GTA San Andreas, IV e V](interludio-2/decompondo-mundo-aberto.md) (laboratório "Quarteirão Vivo")

### Parte IX — Multiplayer · Projeto Arena ✅
63. [Client/Server](parte-09/cap-63-client-server.md)
64. [Authority](parte-09/cap-64-authority.md)
65. [Replication](parte-09/cap-65-replication.md)
66. [RPC](parte-09/cap-66-rpc.md)
67. [Prediction](parte-09/cap-67-prediction.md)
68. [Latency](parte-09/cap-68-latency.md)

### Interlúdio III ✅
- [Multiplayer avançado](interludio-3/multiplayer-avancado.md) (servidor dedicado, partida, lobby; IA, física e mundo aberto em rede; a Vigília para dois)

### Parte X — IA Generativa ✅
69. [IA como ferramenta de programação](parte-10/cap-69-ia-ferramenta-programacao.md)
70. [IA para Game Design](parte-10/cap-70-ia-game-design.md)
71. [IA para Narrative Design](parte-10/cap-71-ia-narrative-design.md)
72. [IA para Game AI](parte-10/cap-72-ia-game-ai.md)
73. [LLMs dentro de jogos](parte-10/cap-73-llms-dentro-de-jogos.md)
74. [NPCs com IA generativa](parte-10/cap-74-npcs-ia-generativa.md)
75. [Limitações e arquitetura híbrida](parte-10/cap-75-limitacoes-arquitetura-hibrida.md)

### Parte XI — Projeto Final: *Vigília* ✅
76. [Conceito](parte-11/cap-76-conceito.md)
77. [Arquitetura](parte-11/cap-77-arquitetura.md)
78. [Vertical Slice](parte-11/cap-78-vertical-slice.md) (Projeto 7)
79. [Implementação](parte-11/cap-79-implementacao.md)
80. [AI](parte-11/cap-80-ai.md)
81. [Narrative](parte-11/cap-81-narrative.md)
82. [Polish](parte-11/cap-82-polish.md)
83. [Performance](parte-11/cap-83-performance.md)
84. [Build](parte-11/cap-84-build.md)
85. [Postmortem](parte-11/cap-85-postmortem.md)

---

## Estado do Livro

- **Capítulos concluídos:** **todos**: Introdução; Caps. 1–85 (Partes I–XI); Interlúdios I, II e III. Produção das Partes VII–XI guiada por [GUIA-DE-PRODUCAO.md](GUIA-DE-PRODUCAO.md). Os nomes exatos de classes, tags, CVars, cheats e testes de cada parte estão no `ESTADO.md` da pasta (`parte-07/` a `parte-11/`, `interludio-2/`). Revisão técnica de 2026-11-03 aplicada (ver [revisao-2026-11-03.md](revisao-2026-11-03.md)).
- **Projetos:** Projeto 1 (Pátio) ✅; Projeto 3 (Interação) ✅; Projeto 2 (Galpão de Testes) ✅. Projeto 4 (Turno da Noite, ingênuo, `L_CasaDeForca`, 9 beats, inventário de 12 dores) ✅; Projeto 5 (IA) ✅. Projeto 6 (refatoração narrativa do Projeto 4) ✅: rádio (Cap. 44), quest (45), estado narrativo (46), consequências (47), documentos e vinhetas (48), cenas (49). No Level Blueprint sobra só `StartQuest` (o puzzle virou `AVGSequencePuzzle` no Cap. 50); com o save (Cap. 56) e o debugging (Cap. 61), **as 12 dores do Interlúdio I estão resolvidas**. Projeto Arena (Parte IX) ✅; Quarteirão Vivo (Interlúdio II, laboratório) ✅; Projeto 7 (vertical slice, Cap. 78) ✅; Projeto Final *Vigília* (Caps. 76–85) ✅, com o ramo experimental `exp/coop-s1` (Cap. 84).
- **Código do projeto `Vigilia` (UE5 C++, prefixo `VG`, módulo único; deps: EnhancedInput, GameplayTags, PhysicsCore (Cap. 17), Niagara (Cap. 27)):**
  - Core/: `VGLog`, `VGMathUtils.h`, `UVGTimeDilationSubsystem`, `UVGBlueprintLibrary`, `AVGGameMode`, `VGCollision.h` (`ECC_VGInteraction`), `VGGameplayTags` (Status/Faction/World/Event nativas), `UVGStatusTagsComponent` (identidade + status com contagem), `UVGGameplayEventSubsystem` (barramento por canal-tag; `vg.Debug.Events`).
  - Player/: `AVGCharacter` (Move/Look/Jump/Sprint/Crouch/Interact/Fire/Reload; câmera suave ao agachar; tags de status; `IGameplayTagAssetInterface`; morte → controller), `AVGPlayerController` (pilha de modos `EVGInputMode` Exploration/Reading/Cinematic/UI/Dead; `HandlePawnDied`/`RequestRespawn`), `VGInputModes.h`, `AVGPlayerCameraManager`, `UVGFirstPersonCameraModifier` (head bob por distância, FOV ao correr, `vg.Camera.Motion`), `UVGFootstepComponent` (passos por distância/superfície/intensidade), `UVGBatteryComponent`.
  - Interaction/: `IVGInteractable` (CanInteract/Interact/GetInteractionPrompt via Execute_), `UVGInteractionComponent` (sweep 20 Hz, foco, prompt, custom depth), `AVGDoor` (FSM 5 estados, PowerSource, RequiredTag), `AVGBreakerSwitch`, `AVGPickup` (ApplyPickup NativeEvent; publica Event.Item.Collected).
  - Combat/: `UVGWeaponData`, `AVGWeapon` (Holstered/Equipping/Ready/Reloading; cadência por acumulador; buffer; PerformShot aplica ApplyPointDamage — trace simples), `UVGWeaponComponent`, `VGDamageTypes` (Physical/Bullet/Light/Presence), `UVGHealthComponent` (pipeline, morte única, multiplicadores por hierarquia, regen).
  - World/: `AVGSpawner`, `UVGFlickerComponent`, `UVGFlickerProfile`, `AVGAlarm`, `AVGEventTrigger`, `AVGSafeZone` (concede Status.Zone.Safe com simetria), `AVGSector` (desafio do Cap. 23, obrigatório a partir do 24; `World.Sector.Powered` + `Event.Sector.Powered`).
  - Parte IV: `UVGMovementProfile` (perfis Vigília/Galpão; coyote time, jump buffer, aterrissagem dura; `vg.Debug.Movement`); `FVGWeaponStats` + `UVGWeaponModifier` (efetivo = (base+Σ)×Π, testado); inventário com slots e ADS (alfa) no `UVGWeaponComponent` (+ `AttachSocketName`, coice, balanço); hitscan da câmera (`ECC_VGWeapon` = GameTraceChannel2; `UVGPhysicalMaterial` dano/penetração; `UVGImpactEffects`; FRandomStream por disparo; `OnHitConfirmed`); `AVGProjectile` + `AVGFlareProjectile` (Flying/Burning/Spent, zona segura temporária, dano Light); `UVGRecoilComponent` (pendente/acumulado/recuperação respeitando compensação; bloom); `AVGEnemyCharacter` (reações, stagger, ragdoll) + `UVGSimpleCombatBrain` (FSM ingênua — dívida p/ Parte V); objetivos (`UVGObjectiveData`, `VGObjectiveRules`, `UVGObjectiveSubsystem` tickable; `Event.Trigger.Entered` c/ LocationTag); spawn (`AVGSpawnPoint`, `UVGWaveData`, `AVGWaveSpawner`), pool (`IVGPoolable`, `UVGActorPoolSubsystem`). Tags novas: `Event.Actor.Died`, `Event.Trigger.Entered`, `Faction.Target`.
  - Parte V (AI/): deps AIModule/GameplayTasks/NavigationSystem; `AVGAIController` (EVGTeam, IGenericTeamAgentInterface, BT como dado, AI Perception visão+audição, `OnAgentMoveCompleted`); `FVGHierarchicalStateMachine` (HFSM genérica, C++ puro; ficou sem cliente depois do Cap. 42 — material de estudo, YAGNI registrado); navegação com agentes Humano/Presenca, `UVGNavArea_Lit`/`DoorClosed`, `UVGNavFilter_Presence` (exclui luz e portas fechadas), NavModifier em `AVGSafeZone` e `AVGDoor` (Dynamic Modifiers Only); `UVGNoiseLibrary` (`vg.Debug.Noise`), `UVGAwarenessComponent` (consciência gradual Unaware/Suspicious/Aware, fatores distância/periferia/luz/postura via tags; escreve BB), `UVGThreatSubsystem` (Calm/Uneasy/Hunting); BTs `BT_Presenca` (Recuar→Caçar→Investigar→Espreitar) e `BT_Vigia` (stagger→combate por intenção→investigar→patrulha); tasks/services C++ com memória de nó (Telegraph, PresenceAttack, AimAtTarget, FireBurst, LookAround, UtilitySelect, AcquireToken/HoldToken); `VGBlackboardKeys.h` + BB_InimigoBase→BB_Presenca/BB_Vigia (contrato em docs/design/blackboards.md); `UVGPresenceReactionComponent` (reação da Presença à luz); EQS (contextos VGTarget/LastKnownLocation/PlayerView/StunOrigin/RetreatOrigin; teste InSafeZone; consultas Cobertura/Espreita/Recuo/Busca/Flanco); Utility (`VGUtility::ScoreAction/SelectBest`, produto compensado + inércia); `UVGSuppressionComponent` (near miss); `UVGTokenSubsystem` (Attack 2, Flank 1, Suppress 1, Bark 1); `UVGSquadSubsystem` (papéis por utilidade — só desenho; implementação é exercício do Cap. 42); `UVGDirectorSubsystem` (Relax/BuildUp/Peak/Recovery num `switch`; travas de roteiro; sem pico durante leitura; escreve DirectorMode). Tags novas: `Status.Light.Flashlight`, `Status.Suppressed`, `Squad.Token.*` (Attack/Flank/Suppress/Bark), `Event.AI.*` (SearchPointChosen/StalkPointChosen), `Event.Director.BuildUp`.
  - Parte VI (Narrative/): `UVGSpeakerData`; `UVGDialogueData` (nós com Id, falante, `FText`, voz, `DelayBefore`, condição `FGameplayTagQuery`, `GrantFacts`, `bOnce`, `Next`/`End`, escolhas com tempo-limite; prioridade Ambient/Normal/Critical, `MaxWait`, `bResumeAfterInterruption`; `IsDataValid`); `VGDialogueRules` (puras, testadas); `UVGDialogueSubsystem` (tickable; canal único, fila por prioridade, interrupção com retomada, expiração, só Critical começa durante leitura, relógio de áudio, efeitos/memória no fim da fala, `vg.Debug.Dialogue`; **fatos `Narrative.Fact.*` provisoriamente aqui até o Cap. 46**); respostas por contexto sobreposto `IMC_RespostaRadio` no `AVGPlayerController`; cheat `VGAddFact`. Tags novas: `Event.Dialogue.Started`/`Finished`; conteúdo `Dialogue.*`, `Narrative.Fact.*`. Conteúdo: `DA_Dlg_S1_*`, `ST_Radio_Setor1`, `WBP_Legenda`, `WBP_RespostasRadio`.
    - Cap. 45: `UVGQuestAction` (Abstract, EditInlineNew, DefaultToInstanced; `Execute(UWorld&) const`) + `_GrantFact`, `_PlayConversation`, `_StartQuest`, `_PublishSignal` (escotilha para o nível: `Event.Quest.Signal` + `Signal.*`); `UVGQuestData` (etapas com objetivos do Cap. 31 obrigatórios/opcionais, `AllRequired`/`AnyRequired`, `CompletedIf`, `OnEnter`/`OnComplete`, transições por fato avaliadas DEPOIS do `OnComplete`, `End`; `StartCondition`, `OnCompleted`/`OnFailed`; `IsDataValid`); `VGQuestRules` (puras, testadas); `FVGQuestState`; `UVGQuestSubsystem` (sem tick; TODA mutação em `Drain()` via `SetTimerForNextTick`, limite 256 itens/tick; quests não repetíveis; `vg.Debug.Quests`; cheat `VGQuestJump`). 🔁 `UVGDialogueSubsystem::GetFacts()`; 🔁 `AVGEventTrigger` ganha `RequiredFacts` + `FactOnTrigger`. Tags: `Event.Quest.Started/StageEntered/Completed/Failed/Signal`; conteúdo `Quest.*`, `Signal.*`. Conteúdo: `DA_Quest_S1_NightShift`, `DA_Obj_S1_*`, `WBP_Diario`; fatos `S1.BreakersRestored`, `S1.ScareDone`, `S1.Completed`.
    - Cap. 46: `FVGNarrativeState` (USTRUCT versionado = estado + snapshot: Facts, Counters, SaidLines, PlayedConversations, `FVGQuestRecord`s com `TSoftObjectPtr`); `UVGNarrativeSubsystem` (**GameInstanceSubsystem**, dono único; `AddFact`/`SetExclusiveFact`/`RemoveFact`/`HasFact`/`MatchesFacts`/`GetFacts`, contadores, memória de diálogo, registros de quest, `CaptureSnapshot`/`RestoreSnapshot`/`ResetForNewGame`, `OnFactChanged(Native)`, `OnRestored`, profundidade de anúncio ≤ 8; `Get(WorldContext)`); `UVGFactRuleSet` + `UVGNarrativeSettings` (UDeveloperSettings → `DA_FatosDoJogo`) + `UVGFactRulesSubsystem` (evento → fato/contador/limiar); diálogo, quests (registros, retomada entre níveis, reação a fatos; `OnEnter` só idempotente), gatilhos e cheats migrados; cheats `VGRemoveFact`, `VGNewGame`, `VGDumpNarrative`; `vg.Debug.Narrative`. Dep `DeveloperSettings`.
    - Cap. 47: `UVGFactGateComponent` (ator existe conforme fatos; adia enquanto `WasRecentlyRendered`); `VGBranchAudit` (combinações mudas, nós inalcançáveis; testado). `docs/design/ramificacao.md`: 1 escolha estrutural (final A/B no setor 3), o resto estado/sabor.
    - Cap. 48: `UVGDocumentData` (páginas, `ReadFact`, `PaperStyle`, primary asset `VGDocument`); `VGDocumentRules` (lido = última página OU metade do tempo estimado; testado); `UVGDocumentReaderSubsystem` (dono do modo Reading, relógio real, arquivo deduzido via Asset Manager + fatos); `AVGReadable` (Interaction/). Tags `Event.Document.Opened/Read`, conteúdo `Document.*`, `Paper.*`.
    - Cap. 49: `AVGCinematicActor` (subclasse de `ALevelSequenceActor`; disparo por evento do barramento; `bTakeControl`, `bSkippable`, `bHoldDirector`; estado no `Finish` único: pular aplica, cancelar não; morte cancela evento roteirizado), `UVGCinematicSubsystem` (cena atual, `SkipCurrent`, `IsPlaying` para o save). `IA_Pular` com gatilho Hold. Tags `Event.Cinematic.Started/Finished`, conteúdo `Cinematic.*`. Deps `LevelSequence`, `MovieScene`.
  - Parte VII (detalhes em `parte-07/ESTADO.md`): `AVGSequencePuzzle`; `UVGFlashlightComponent` (deriva de `USpotLightComponent`; sobrecarga `IA_SobrecargaLanterna`, `Status.Light.Overcharge`), `AVGLightFixture` (lê fatos; dona da zona segura); `UVGAudioMixSubsystem` (mix derivado do modo de input; silêncio por handle), `UVGAudioSettings`, `UVGSpeakerData::VoiceChain` (filtro de rádio); `UVGAnimInstance`, `UVGPhysicalReactionComponent`, `UVGHitReactionData`; `UVGDirectorSignalComponent`, orçamento de impactos; `UVGHUDLayout` (5 camadas derivadas do modo), `UVGSubtitleWidget`, `UVGGameUserSettings` (acessibilidade).
  - Parte VIII (`parte-08/ESTADO.md`): `UVGSaveGame`, `UVGSaveSubsystem`, `AVGCheckpoint`, `VGSaveRules` (versão 2, migração); `UVGPersistenceComponent` (`FGuid`), `VGPersistence`; `STATGROUP_Vigilia`, `VGPerfRules`, `VGPerfCapture`/`VGPerfHunt`; `VGSignificanceRules`; categorias do Gameplay Debugger `VigiliaNarrative`/`VigiliaAI`; `Tools/BuildVigilia.bat`. Deps `EngineSettings`, `RHI`, `SignificanceManager`, `GameplayDebugger`.
  - Interlúdio II (`interludio-2/ESTADO.md`): laboratório `L_Lab_QuarteiraoVivo` — `UVGPopulationSubsystem`, `UVGWorldClockSubsystem`, `UVGAlertSubsystem`, `VGVisibility` (fora do jogo).
  - Parte IX (`parte-09/ESTADO.md`): `AVGArenaGameMode`/`GameState`/`PlayerState`, CMC preditivo com flags, disparo por pedido validado (`NetSeed` + `ShotId`), `UVGHitboxHistoryComponent` (rewind simplificado), inventário de quebras Q1–Q10.
  - Parte X (`parte-10/ESTADO.md`): `GenAI/` isolado — `UVGLLMSubsystem` (HTTP assíncrono, prazo de 3 s, reserva autorada, cache, `vg.GenAI.Fake`), Sônia com intenções fechadas; `UVGUtilityProfile`; `VG_WITH_GENAI` = 0 em Shipping; ADR-0010.
  - Parte XI (`parte-11/ESTADO.md`): `Tools/check_layers.py` (regras de camadas), ADRs 0001–0012; `UVGTelemetrySubsystem` (CSV de playtest); `UVGSectorManifest` + teste de conteúdo; `UVGDirectorProfile` (perfis por setor) e `AVGDirectorLockZone`; espelho de fatos cooperativo (Cap. 84).
  - Debug/: probes, `UVGCheatManager`. Tests/: bateria, dilatação, vida, modificadores, objetivos, HFSM, utilidade, diálogo, quests, estado narrativo, auditoria de ramificação, documentos, puzzle, lanterna, áudio, animação, impactos, UI, save, persistência, performance, significância, debug, build, GenAI, telemetria, manifestos, perfil do Diretor.
- **Decisões de design firmadas:** Presença invencível; sinalizador repele/atordoa (máx. 4 cartuchos = pente 1 + reserva 3); Presença vê até 30 m (raio de visão = melhor caso, lanterna acesa; o escuro atenua); "dois toques, o primeiro é aviso" (vida 100, toque 60, regen 8 s/15 por s); sem estamina (custo da corrida = ruído); vigias derrotáveis num trecho único.
- **Decisões de produção do projeto final (Caps. 76–81):** sobrecarga da lanterna no combate v1.0; checkpoints com trava de momento, um slot, vida não salva; um nível por setor, sem World Partition (ADR-0011); release sem IA generativa em runtime (ADR-0010); multiplayer só como ramo experimental (ADR-0012); escolha final única (desligar × deixar girar a turbina 3) com epílogo de variantes por fatos.
- **Situação:** livro concluído. Para continuar estudando, ver os próximos passos no [Capítulo 85](parte-11/cap-85-postmortem.md).

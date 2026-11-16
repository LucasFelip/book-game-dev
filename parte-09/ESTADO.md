# Estado da Parte IX — Multiplayer (Projeto Arena)

## 1. Capítulos concluídos

- Cap. 63 — Client/Server (`cap-63-client-server.md`)
- Cap. 64 — Authority (`cap-64-authority.md`)
- Cap. 65 — Replication (`cap-65-replication.md`)
- Cap. 66 — RPC (`cap-66-rpc.md`)
- Cap. 67 — Prediction (`cap-67-prediction.md`)
- Cap. 68 — Latency (`cap-68-latency.md`) — com o bloco "Estado do Livro (fim da Parte IX)". **Projeto Arena concluído** (Q1–Q10 fechadas).
- Interlúdio III — Multiplayer avançado (`../interludio-3/multiplayer-avancado.md`): servidor dedicado (`VigiliaServer.Target.cs`, esboço), partida, lobby, sessões (esboço `CreateSession` com OSS Null) × matchmaking, IA, física/destruição, mundo aberto, escala, Vigília cooperativa. Decisões [HIPOTÉTICO]: segundo jogador = segundo técnico do turno; rádio opção A (os dois têm rádio, fala sincronizada pelo relógio do servidor); Diretor/ameaça por grupo (tensão do mais tenso; sem pico se qualquer um estiver lendo); fatos espelhados num `FGameplayTagContainer` replicado no GameState cooperativo; escopo do Cap. 84 = setor 1, 2 jogadores, listen server, sem entrar no meio, sem save no cooperativo.

## 2. Código criado (nomes exatos)

**Pasta nova:** `Source/Vigilia/Arena/` (classes de partida do experimento; removível). Refatorações de rede de classes existentes ficam nas pastas originais.

- Cap. 63
  - `Arena/VGArenaRules.h` — `namespace VGArenaRules`: `PickFarthestSpawn(TConstArrayView<FVector> Spawns, TConstArrayView<FVector> Threats)`.
  - `AVGArenaGameMode : AGameMode` — `ReadyToStartMatch_Implementation` (sala cheia: `PlayersToStart = 2`), `ChoosePlayerStart_Implementation` (ponto mais longe dos adversários).
  - `AVGArenaGameState : AGameState` — timer de depuração `DrawNetDebug` (4 Hz).
  - `AVGArenaPlayerState : APlayerState` — vazio.
  - `Debug/VGNetDebug.h` — `namespace VGNetDebug`: `RoleName(ENetRole)`, `NetModeName(ENetMode)`.
  - CVar `vg.Debug.Net` (modo de rede + papéis local/remoto sobre cada pawn).
  - Teste `Vigilia.Arena.Rules` (`Tests/VGArenaRulesTest.cpp`).
  - Conteúdo: `L_Arena` (recorte do Galpão, 4 `PlayerStart`), `BP_VGArenaGameMode`, `BP_ArenaJogador` (filho de `BP_VGJogadora`, corpo *Owner No See*, `StartingWeaponClass = BP_Fuzil`).
- Cap. 64
  - 🔁 `UVGHealthComponent`: `CanMutateHealth()` (dono tem autoridade) guarda `ReceiveDamage`, `Heal`, `Revive`; `Event.Actor.Died` publicado **antes** do `OnDied` (o corpo ainda está possuído).
  - 🔁 `UVGWeaponComponent`: arma inicial e `GiveWeapon` só com autoridade. 🔁 `AVGWeapon`: `bReplicates = true`; `PerformShot` só com autoridade em `FireOnce`.
  - 🔁 `AVGCharacter::HandleDied`: corpo (todas as máquinas) × decisão (só servidor: `HandlePawnDied`, `SetLifeSpan`).
  - 🔁 `AVGPlayerController::OnPossess`: sai de `EVGInputMode::Dead` se local (anfitrião). `RequestRespawn` só funciona com GameMode local (log se nulo).
  - `AVGArenaPlayerState`: `Kills`, `Deaths`, `GetKills/GetDeaths`, `AddKill/AddDeath` (`ensure(HasAuthority())`).
  - `AVGArenaGameMode`: ouve `Event.Actor.Died` no barramento (`HandleGameplayEvent` → `ScoreDeath`), respawn por timer (`RespawnDelay = 3`, `TWeakObjectPtr`), `ReadyToEndMatch_Implementation`, `HandleMatchHasStarted/Ended`, `RestartGame` após `PostMatchDuration = 10`; `KillLimit = 10`, `MatchDuration = 300`; `MatchStartTime` (provisório).
  - `VGArenaRules::IsMatchOver`, `VGArenaRules::PickWinner` (+ casos no teste `Vigilia.Arena.Rules`).
- Cap. 65
  - `Build.cs`: `NetCore` (push model).
  - 🔁 `UVGHealthComponent`: `SetIsReplicatedByDefault(true)`; `Health` (`OnRep_Health(float Old)`, relatório parcial sem instigador) e `LifeState` (`OnRep_LifeState(EVGLifeState Old)`, reconstrói `OnDied` na transição) replicados.
  - `AVGArenaPlayerState`: `Kills`/`Deaths` push-based (`DOREPLIFETIME_WITH_PARAMS_FAST`, `MARK_PROPERTY_DIRTY_FROM_NAME`), `OnRep_Score`, `OnScoreChanged` (servidor anuncia à mão), `ForceNetUpdate` ao pontuar.
  - `AVGArenaGameState`: `FVGArenaResult {bDecided, Winner}` (`OnRep_Result`, `OnResultDecided`), `KillLimit` (`COND_InitialOnly`), `MatchEndServerTime` (double), `GetRemainingTime()` via `GetServerWorldTimeSeconds()`, `StartMatchClock`, `SetResult`.
  - 🔁 `AVGArenaGameMode`: `InitGameState` (limite), relógio no GameState, `SetResult` no fim; `MatchStartTime` removido.
  - 🔁 `UVGWeaponComponent`: replicado; `Slots` (`OnRep_Slots`) e `CurrentSlot` (`OnRep_CurrentSlot`) replicados; `ApplyEquippedWeapon()` idempotente (anexa/equipa localmente; `AppliedWeapon` transiente); `EquipSlot` só no servidor; anexação sai do `GiveWeapon`.
  - 🔁 `AVGWeapon`: `bNetUseOwnerRelevancy`, `SetReplicatingMovement(false)`; `AmmoInMagazine`/`ReserveAmmo` `COND_OwnerOnly` com `OnRep_Ammo` (provisório: Cap. 67 troca por predição); inicialização de munição no `BeginPlay` só com autoridade.
  - `AVGArenaHealthStation : AActor, IVGInteractable` — `bAvailable` replicado, `NetDormancy = DORM_Initial`, `FlushNetDormancy` em `SetAvailable`, cura 50, recarga 20 s, `OnAvailabilityChanged` (BP).
  - Conteúdo: `WBP_ArenaPlacar`, `BP_ArenaEstacaoCura`.
- Cap. 66
  - `Combat/VGShotTypes.h` — `FVGShotRequest {Origin (FVector_NetQuantize10), AimPitch/AimYaw (uint16, CompressAxisToShort), ShotId; SetAim(), GetAim()}`.
  - `Combat/VGNetRules.h` — `namespace VGNetRules`: `FFireBudget`, `TryConsumeShot` (balde de fichas), `IsOriginPlausible`. Teste `Vigilia.Net.Rules` (`Tests/VGNetRulesTest.cpp`).
  - 🔁 `AVGWeapon`: `ServerFireShot` (Server, Reliable, WithValidation; `_Validate` = `ShotId > LastReceivedShotId`), `ServerReload` (Server, Reliable), `MulticastShotFx` (NetMulticast, Unreliable), `ClientConfirmHit` (Client, Unreliable); `MakeShotRequest`, `ResolveShot(const FVGShotRequest&)` (substitui `PerformShot`), `PlayShotFx`, `IsLocallyOwned`; folgas `MaxOriginError = 100`, `FireBurstAllowance = 3`, `ReloadGraceTime = 0.15`; munição só muda no servidor (`FinishReload` com autoridade).
  - 🔁 `UVGInteractionComponent`: replicado; `ServerInteract` (Server, Reliable) com folga `ServerRangeTolerance = 100` e distância à caixa do alvo; `InteractWith`.
  - 🔁 `AVGPlayerController`: `HandlePawnDied` → `UnPossess` + `ClientOnPawnDied` (Client, Reliable); `AcknowledgePossession` sai do modo `Dead`.
  - `AVGArenaGameState::MulticastKillFeed` (NetMulticast, Reliable) + `OnKill`; GameMode chama em `ScoreDeath`. HUD de abate ouve `OnKill` (substitui o barramento no cliente).
  - Conteúdo: `WBP_KillFeed`.
- Cap. 67
  - `Player/VGCharacterMovementComponent.h/.cpp`: `UVGCharacterMovementComponent` (`SetWantsToSprint`/`SetWantsToAim` → `FLAG_Custom_0`/`FLAG_Custom_1`; `SetAimSpeedMultiplier`; `IsSprinting()` usa `Acceleration`; `GetMaxSpeed`; `CoyoteClock` em tempo de movimento: `OpenCoyoteWindow`/`CloseCoyoteWindow`/`IsInCoyoteWindow`; `OnMovementUpdated` avança o relógio e chama `SetSprintingState` fora do replay), `FSavedMove_VG` (`Clear`, `GetCompressedFlags`, `CanCombineWith`, `SetMoveFor`, `PrepMoveFor` restaura `CoyoteClock`), `FNetworkPredictionData_Client_VG`.
  - 🔁 `AVGCharacter`: construtor `AVGCharacter(const FObjectInitializer&)` com `SetDefaultSubobjectClass<UVGCharacterMovementComponent>`; `GetVGMovement()`; `UpdateSprint` só declara intenção; `SetSprintingState` (tags do Cap. 23); `ApplyMovementProfile` define `MaxWalkSpeed`/`SprintSpeed`; `CanJumpInternal` usa a janela do CMC; `OnMovementModeChanged` abre/fecha janela e guarda o jump buffer com `!bClientUpdating && IsLocallyControlled()`; `OnJumped` fecha a janela. Removidos `LeftGroundTime`, `bJumpedSinceGrounded`.
  - 🔁 `UVGWeaponComponent`: `StartAim/StopAim` → `SetWantsToAim`; `ApplyEquippedWeapon` define `SetAimSpeedMultiplier`; `GetMoveSpeedMultiplier` deixa de afetar a velocidade.
  - 🔁 `FVGShotRequest.SpreadDegrees`. 🔁 `AVGWeapon`: `NetSeed` (`COND_OwnerOnly`, sorteado no servidor) + `MakeShotStream(ShotId)` (substitui `GetUniqueID`); `TraceShot(Request, bAuthoritative)`; `FirePellet(..., bAuthoritative)`; impacto previsto só em paredes (personagem espera `ClientConfirmHit`); `MulticastShotFx` ignora o dono; `MaxPlausibleSpread = 30`; munição prevista: `ClientAckAmmo(LastProcessedShotId, ServerMagazine, ServerReserve)` (Client, Unreliable) via `SendAmmoAck()` (`ON_SCOPE_EXIT` no `ServerFireShot`; só para dono remoto); `AmmoInMagazine`/`ReserveAmmo` deixam de ser replicados; `FinishReload` prevê a transferência.
  - `VGNetRules::ReconcileAmmo`, `VGNetRules::IsSpreadPlausible` (+ casos em `Vigilia.Net.Rules`).
- Cap. 68
  - `Combat/VGLagCompRules.h` — `struct FVGHitboxFrame` (Time, BodyCenter/HalfHeight/Radius, HeadCenter/Radius), `enum class EVGHitboxPart {None, Body, Head}`, `namespace VGLagCompRules`: `RaySphere`, `RayCapsule` (usa `FMath::SegmentDistToSegmentSafe`; distância do ponto mais próximo), `RayHitbox` (cabeça primeiro), `SampleHistory` (interpola; extremos fora da janela). Teste `Vigilia.Net.LagCompensation`.
  - `UVGHitboxHistoryComponent` (Combat/) — grava só no servidor em rede (`TG_PostUpdateWork`), `HistorySeconds = 0.5`, `HeadRadius = 12` (cabeça no topo da cápsula, sem ossos), `GetFrameAt(Time)`, `static FindRewoundHit(...)` (ignora mortos agora). Adicionado ao `BP_ArenaJogador`.
  - 🔁 `AVGWeapon`: `EstimateShooterViewTime()` (agora − RTT/2 via `APlayerState::GetPingInMilliseconds()` ⚠️ − `vg.LagComp.ProxyDelay`, limitado por `vg.LagComp.MaxRewind`; anfitrião/IA = presente), `FirePelletRewound(Origin, Dir, ViewTime)` (mundo no presente ignorando personagens com histórico; personagens rebobinados; `FHitResult` sintético; sem penetração), `RewoundHeadMultiplier = 2.0`; `TraceShot` autoritativo usa o caminho rebobinado com a CVar ligada.
  - CVars: `vg.LagComp.Enable` (true), `vg.LagComp.ProxyDelay` (0.05), `vg.LagComp.MaxRewind` (0.25), `vg.Debug.LagComp` (cápsula verde = rebobinada, vermelha = atual).

## 3. Decisões firmadas

- Cliente/servidor autoritativo (modelo da engine); lockstep descartado.
- Listen server para iterar no PIE; *Play As Client* (servidor dedicado) para validar cada capítulo.
- Toda verificação de rede roda pelo menos uma vez com 100 ms de latência e 2% de perda.
- Ordem da parte: separar (63) → decidir/autoridade (64) → propagar/replicação (65) → pedir/RPC (66) → antecipar/predição (67) → compensar/latência (68). Autoridade antes de replicação, de propósito.
- Três camadas de estado: simulação autoritativa (servidor), intenção (cliente dono → servidor), apresentação (local).
- Inventário de quebras Q1–Q10 da Arena = critério de conclusão da Parte IX.
- Guarda de autoridade no **dono do estado** (não no chamador). Clientes enviam intenções, nunca resultados.
- Validação de forma pode desconectar (`_Validate`); validação de regra recusa em silêncio, com folga.
- Tabela de autoridade da Arena (Cap. 64, seção 64.3) é o contrato de estado da parte.
- Respawn automático na Arena (regra do GameMode); o fluxo "continuar" fica para a Vigília.
- Replicar estado; eventos por RPC ou transformados em estado. Transições reconstruídas no `OnRep` com valor anterior.
- O servidor anuncia à mão o que o `OnRep` anuncia nos clientes (o anfitrião depende disso).
- Relógio de partida = instante final no relógio do servidor; resultado como struct com `bDecided`.
- Anexação de armas local em cada máquina (sem replicar movimento da arma).
- Disparo = um pedido por tiro (origem, mira comprimida, ShotId); o cliente decide quando, o servidor decide o quê.
- Confiabilidade pelo custo da perda: pedidos/avisos raros confiáveis; efeitos/confirmações frequentes não confiáveis.
- Folgas explícitas e calibráveis (balde de fichas, origem, carência de recarga, alcance).
- Barramento de eventos = sistemas do servidor; HUD de cliente recebe eventos por RPC.
- Variáveis de sistemas preditivos: entrada (viaja no movimento) / estado simulado (reconciliado ou salvo-restaurado) / dados (iguais nas pontas) / efeito colateral (nunca no replay).
- Entradas de movimento como flags do CMC, nunca RPC paralelo. Semente de disparo = `NetSeed` + `ShotId`.
- Impacto em personagem e dano só com confirmação do servidor; rastro e impacto em parede previstos.
- Aterrissagem dura (Cap. 25) já roda dentro do passo do CMC: não precisou de mudança.
- Compensação de latência: instante estimado pelo SERVIDOR (não pelo cliente: evita *backtrack*); mundo no presente, personagens no passado; cópia geométrica das hitboxes (não move colisores).
- Empate: ordem de chegada + "morto não atira" (trocas = desafio do Cap. 68).

## 4. Pendências para os capítulos seguintes

- ✅ Q1–Q10 fechadas no Cap. 68.
- Interlúdio III: servidor dedicado/partida/lobby/matchmaking; IA, física, mundo aberto, escala; Vigília cooperativa (preparar o Cap. 84).
- Cap. 84 (parte-11, outro autor): branch experimental cooperativa deve partir da tabela "Vigília cooperativa" do Interlúdio III; o código de rede da Arena (autoridade no dono, CMC da Vigília, disparo por pedido) já está nas classes da Vigília.
- Limites conhecidos registrados: trapaças de input/informação; hitboxes grosseiras; sem penetração rebobinada; jitter na estimativa; sem trocas; projéteis sem compensação (exercício opcional do Cap. 68).

## 5. Ajustes sugeridos em outras partes (não editados)

- **Cap. 25 (parte-04), "Explicação das decisões", item "Aterrissagem dura":** a frase "em multiplayer, precisaria ser integrada ao movimento preditivo (Capítulo 67)" não se confirma: o `Landed` roda dentro do passo do CMC nas duas pontas. Sugestão: "em multiplayer, ela já roda dentro do passo de movimento; o Capítulo 67 confere (o que precisa mudar é o *coyote time*, que usa o relógio do mundo)".
- **Cap. 27 (parte-04), seção 7 "Confirmação de abate":** especificar que `Event.Actor.Died` é publicado **antes** do `OnDied.Broadcast` (o Cap. 64 depende disso para achar o controller da vítima).
- **Cap. 27 (parte-04), "Explicação das decisões", semente:** o texto diz "no Capítulo 67, ela será substituída por uma semente compartilhada" — correto; o Cap. 67 usa `NetSeed` (replicado ao dono) + `ShotId`.
- **Cap. 16 (parte-03), item 2 sobre `OnPossess`:** coerente com o Cap. 66 (`AcknowledgePossession` no cliente). Nada a mudar.

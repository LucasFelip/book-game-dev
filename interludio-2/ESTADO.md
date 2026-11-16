# Estado — Interlúdio II

## 1. Concluído

- `decompondo-mundo-aberto.md` — Interlúdio II, "Decompondo um mundo aberto" (~9 mil palavras por `wc -w`, código incluído). Projeto: **Quarteirão Vivo** (laboratório, fora da Vigília).

## 2. Criado (nomes exatos)

**Classes e tipos** (todos em `Source/Vigilia/World/`):
- `VGPopulationRules.h`: `enum class EVGSimLod : uint8 { Full, Reduced, Discard }` (sem UENUM); `namespace VGPopulationRules` com `DensityAt(const TArray<float>&, float Hour)`, `TargetCount(int32, float, float)`, `IsHourInWindow(float, float From, float To)` (cruza meia-noite), `SimLodFor(float Distance, bool bVisible, float FullRadius, float DespawnRadius)`.
- `UVGWorldClockSubsystem` (`UTickableWorldSubsystem`): `GetHour()`, `SetHour(float)`, `HoursPerSecond` (1/30), hora inicial 13,5. Relógio: delta do mundo (dilata e pausa).
- `UVGPopulationData` (`UPrimaryDataAsset`): `PawnClasses`, `HourlyDensity` (24), `MaxAlive`, `FullLodRadius` < `SpawnMinRadius` < `SpawnMaxRadius` < `DespawnRadius` (validado em `IsDataValid`).
- `UVGPopulationSubsystem` (`UTickableWorldSubsystem`): `SetProfile`, `SetDensityScale`, `CountWitnesses(Location, Radius, Ignored)`; passo de 4 Hz, 6 agentes por passo (round-robin), 1 spawn por passo, carência de descarte 2 s, `Reduced` = tick 0,25 s em pawn, controller e componentes; `SetDormant` desliga tick de componentes e para a BT (`StopLogic`) antes de devolver ao pool. `DrawDebug` declarado; implementação fica como exercício.
- `VGAlertRules.h`: `USTRUCT FVGAlertTuning` (`HeatPerLevel` 100, `MaxLevel` 3, `Hysteresis` 15, `DecayDelay` 6, `DecayPerSecond` 20, `WitnessRadius` 3000); `namespace VGAlertRules` com `AddIncident` (teto = `HeatPerLevel × (MaxLevel + 0,5)`), `Decay`, `LevelFor` (histerese).
- `UVGAlertSubsystem` (`UTickableWorldSubsystem`): `SetTuning`, `ReportPlayerSeen`, `GetLevel`, `GetHeat`, `DebugAddHeat`, `OnAlertLevelChanged(int32 Old, int32 New)`.
- `VGVisibility.h/.cpp`: `VGVisibility::IsVisibleToPlayer(const UWorld*, const FVector&, float HalfAngleDeg, const AActor* Ignored = nullptr)`. 🔁 extraído de `AVGWaveSpawner::IsVisibleToPlayer` (Cap. 32), que passa a chamá-lo.

**Tags nativas** (`VGGameplayTags`): `Event.Alert.Incident`, `Event.Alert.LevelChanged` (Magnitude = nível), `Event.Alert.Cleared`, `Spawn.Population`.
**Tags de conteúdo:** `Spawn.Security`.

**CVars:** `vg.Debug.Population`, `vg.Debug.Alert`.
**Cheats** (`UVGCheatManager`): `VGSetHour(float)`, `VGAlertHeat(float)`.
**Testes** (`Tests/VGOpenWorldRulesTest.cpp`): `Vigilia.World.Alert.HeatDecayHysteresis`, `Vigilia.World.Population.DensityScheduleLod`.

**Conteúdo do laboratório** (`/Game/Developers/<usuário>/`): `L_Lab_QuarteiraoVivo`, `DA_Pop_Patio`, `DA_Pop_Vila`, `BP_Figurante` (ACharacter simples, `IVGPoolable` em BP, roda `BT_Figurante` no `OnPoolAcquired`), `BP_RespostaAlerta`, `DA_Onda_Seguranca`.

## 3. Decisões firmadas

1. "O mundo continua existindo" = **bolha + memória + fabricação**; nunca simulação contínua do mundo inteiro.
2. **Anéis aninhados**: Full ⊂ spawn ⊂ despawn ⊂ carregamento (World Partition) ⊂ HLOD.
3. **Zona = perfil de população ativo**; densidade por hora no perfil.
4. **Pool para população** com figurantes simples por contrato; a dormência dos componentes é feita pela população, não pelo pool.
5. **LOD de simulação em fatias com custo fixo**; testemunhar exige LOD Full.
6. **Alerta ≠ ameaça**: alerta (mundo humano, `UVGAlertSubsystem`) é distinto do nível de ameaça da Presença (`UVGThreatSubsystem`, Cap. 36).
7. **Regra do interlúdio:** correção onde a jogadora pode verificar; plausibilidade onde não pode; ninguém some à vista.
8. **Nada do laboratório entra na Vigília** sem decisão do Cap. 76.

## 4. Pendências para capítulos seguintes

- **Parte IX (Cap. 63) / Interlúdio III:** o Exercício, Parte 4 ("a segunda observadora") deixa a pergunta "o que muda quando a outra observadora é outra jogadora". Bom gancho para relevância/interest management (Cap. 65) e para GTA Online (Int. III).
- **Desafio "O turno C tem agenda":** NPCs com agenda como registro + fabricação sob demanda (nível "Registro" do LOD). Pode ser retomado no Cap. 79/80 se a Vigília tiver NPCs com rotina.
- `UVGPopulationSubsystem` não persiste nada (por design); se o Cap. 57 quiser um exemplo de "o que NÃO persistir", este é um.

## 5. Ajustes sugeridos em outras partes (não editados)

- **Cap. 32:** mencionar, numa nota, que `IsVisibleToPlayer` é extraído para `VGVisibility` no Interlúdio II (🔁).
- **Cap. 32 (pool):** o `UVGActorPoolSubsystem::Release` desliga só o tick do ator; componentes continuam ticando. Vale uma frase em "Armadilhas" (o Interlúdio II resolve isso na população, via `SetDormant`).
- **Cap. 57 (Persistence):** pode citar os exemplos de identidade × agregado do Interlúdio II, seção 9 (carro na rua × garagem; território como agregado).
- **Cap. 60 (Optimization):** o interlúdio referencia World Partition, HLOD, Significance Manager, URO/`VisibilityBasedAnimTickOption` e grade espacial "no Cap. 60" sem detalhar; confirmar que o capítulo cobre esses itens. A "regra dos anéis" (despawn dentro do raio de carregamento) pode ser citada lá.
- **Cap. 59 (Profiling):** o critério de conclusão pede `stat game`/`stat unit` com 12 figurantes.
- **README:** adicionar Interlúdio II ao índice e ao estado; registrar as classes/tags acima como "laboratório (fora da Vigília)".
- **Introdução, seção 8 (trilhas):** a trilha "Mundo aberto / Simulação" pode incluir o Cap. 32 (spawn/pool), usado pesadamente aqui.

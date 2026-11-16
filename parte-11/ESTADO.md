# Parte XI — Estado

## 1. Capítulos

- Caps. 76–85 ✅ (76–81 e 85 pelo coordenador; 82–84 por agentes de produção). **Livro concluído.**

## 2. Decisões de história (cânone para a Parte XI)

- **Os vigias** são seguranças da **Serra Funda Geração S.A.** (empresa fictícia). Ela comprou a usina e, em segredo, religou a turbina 3 em caráter "experimental". A empresa conhecia o relatório de 1994. Uma ordem de serviço de 2026 no setor 2 revela isso (`Document.S2.WorkOrder`): é o horror humano, ao lado do horror da máquina.
- **O que aconteceu em 1994:** o turno C religou a turbina 3 contra a ordem de Moraes. As luzes "andaram". Os seis desapareceram. A Presença tem relação com eles e com a máquina, mas o jogo **nunca** diz "a Presença é o turno C". Ele mostra: seis pares de pegadas no poço, os nomes, as luzes que andam.
- **Quem aciona a turbina agora** (pergunta 5 do livro-razão): a empresa começou; a máquina continua sozinha. No comando manual, Helena vê que a alavanca está travada na posição "ligado" por dentro.
- **Escolha final (estrutural, única):** no comando manual (`L_Final`):
  - **Final A — Desligar a turbina 3** (`Narrative.Fact.Final.TurbineStopped`): silêncio, as luzes da usina se apagam, o rádio volta, e no escuro Helena ouve passos se afastando, seis.
  - **Final B — Deixá-la girar** (`Narrative.Fact.Final.TurbineKept`): a energia volta à cidade de Serra Funda. No epílogo de rádio, Sônia relata que as luzes da rua apagaram de uma ponta à outra, "como se alguém viesse andando com elas". É a volta da última entrada do livro de ocorrências.
- **Variantes do epílogo de rádio** por fatos: memorando lido, admitiu a Sônia, seis crachás, rota (Sônia × Moraes), vigias (`S2.GuardsCleared` × evitados), susto visto.

## 3. Nomes (contrato)

- **Fatos novos:**
  - `S2.Route.Sonia` / `S2.Route.Moraes`: fatos monotônicos (a primeira rota tomada vence, por `RequiredFacts` nos gatilhos; Cap. 79), sem grupo exclusivo;
  - `S2.GuardsCleared`; `S2.GuardsAvoided` (*could*: furtivo);
  - `Document.WorkOrder.Read`; `S3.WellSeen`; `S3.ChaseSurvived`;
  - `Final.TurbineStopped` / `Final.TurbineKept`.
- **Quests:**
  - `DA_Quest_Prologo` (`Quest.Prologue`);
  - `DA_Quest_S1_NightShift`;
  - `DA_Quest_S2_Substation` (`Quest.S2.Substation`);
  - `DA_Quest_S3_Turbines` (`Quest.S3.Turbines`);
  - `DA_Quest_Final` (`Quest.Final.Choice`).
- **Níveis:** `L_MenuPrincipal`, `L_Patio`, `L_CasaDeForca`, `L_Subestacao`, `L_Turbinas`, `L_Final` (um nível por setor, sem World Partition; Cap. 50).
- **Versões:** 0.8.0 no fim da Parte VIII; **1.0.0** no build de release (Cap. 84).
- **Ramo experimental:** `exp/coop-s1` (escopo do Interlúdio III: só o setor 1, 2 jogadores, *listen server*, rádio opção A).
- **IA generativa:** fora do release (ADR-0010; `bAllowGenAIInShipping = false`; `VG_WITH_GENAI` = 0 em Shipping; `vg.GenAI.Enabled` = 0).
- **Telemetria de playtest (Cap. 78):** `UVGTelemetrySubsystem` grava eventos do barramento em CSV (`Saved/Telemetry/`), com a CVar `vg.Telemetry.Enabled`. Fora do Shipping.
- **Manifesto de setor (Cap. 79):** `UVGSectorManifest` (quest, documentos, conversas, checkpoints, tetos do inventário) e o teste `Vigilia.Content.SectorManifests`.
- **Perfil do Diretor por setor (Cap. 80):** `UVGDirectorProfile` (Data Asset), aplicado pelo `AVGGameMode`.
- **ADRs:** índice em `docs/adr/` criado no Cap. 77, de ADR-0001 a ADR-0012. ADR-0010 = "Release sem IA generativa em runtime" (Parte X).

## 4. Nomes criados nos Caps. 82–84

- **Cap. 82 (Polish):**
  - script `Tools/telemetry_report.py` (`load_session`, `summarize`, `report`, `_self_test`; uma pasta = uma sessão, um CSV por nível carregado);
  - docs `docs/qa/polimento.md`, `bugs.md`, `bug-bash.md`, `ritmo.md`, e as pastas `playtests/<apelido>/`;
  - 🔁 `UVGDirectorProfile::MaxReadingHold` (60 s) e `UVGDirectorSubsystem::ReadingTime`: o teto de leitura vale só em `Relax→BuildUp`. Fecha a pendência "ler para congelar o Diretor" da Parte X.
- **Cap. 83 (Performance):**
  - `UVGPerfGateSubsystem` (Debug/; `Start`, `Report`, `ReportPath` → `Saved/Profiling/VGPerf.log`) e o cheat `VGPerfGate`;
  - linhas de relatório `PERFSCENE`/`PERFLOAD`/`PERFMEM`/`PERFGATE`; 🔁 `VGPerfCapture` passa a escrever via `Report`, com a linha `PERF` inalterada;
  - `Core/VGQualityRules.h` (`QualityForGpuIndex`) e 🔁 `UVGGameUserSettings::DetectQualityOnce`/`bQualityDetected`; teste `Vigilia.Perf.Quality.FromGpuIndex`;
  - `Tools/perf_gate.py`, `Tools/perf_budget.json`, `Tools/PerfGate.bat`, `Config/DefaultScalability.ini`;
  - cenários `S1.Corredor.Cacada(.Fria)`, `S1.Subsolo.Checkpoint`, `S3.Galeria(.Fria)`, `S3.Poco.Chegada`, `S3.Poco.Perseguicao`.
- **Cap. 84 (Build):**
  - release: `Tools/release.py` (`check`/`record`), modo candidato do `Tools/BuildVigilia.bat`, `docs/release/builds.csv` (histórico de builds), `THIRD_PARTY.md`, `ST_Creditos`, `Release/1.0.0/` com `ENGINE.txt`, símbolos e `DEVLOG.md`;
  - ramo `exp/coop-s1`: `AVGCoopGameState` (fatos replicados), `AVGCoopGameMode` (`StartFacts`, `HandleCheckpointReached`), `VGCoopRules`, `FVGDialoguePresentation`/`ApplyRemotePresentation`, `ServerChooseDialogueOption`, `ServerFlashlightInput`, 🔁 `UVGNarrativeSubsystem::SetReplicaMode`/`ApplyReplicatedFacts`;
  - teste `Vigilia.Net.Coop.Rules`, CVar `vg.Debug.Coop`, inventário de quebras C1–C16, `docs/coop/relatorio.md`.
- **Fora do 1.0.0:** a pergunta livre ao rádio (IA generativa; ADR-0010).
- **Ajuste de arquitetura (Cap. 77):** a exceção `("World", "Save")` foi declarada no `check_layers.py`, porque o GameMode aplica o load pendente no `InitGame`. O `Build.cs` final ganhou `bAllowGenAIInShipping = false`.

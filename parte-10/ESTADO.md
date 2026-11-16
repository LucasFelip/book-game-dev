# Parte X — IA Generativa — ESTADO

## 1. Capítulos concluídos

- Cap. 69 — IA como ferramenta de programação (`cap-69-ia-ferramenta-programacao.md`). Abre a parte com `# PARTE X — IA Generativa`.
- Cap. 70 — IA para Game Design (`cap-70-ia-game-design.md`).
- Cap. 71 — IA para Narrative Design (`cap-71-ia-narrative-design.md`).
- Cap. 72 — IA para Game AI (`cap-72-ia-game-ai.md`).
- Cap. 73 — LLMs dentro de jogos (`cap-73-llms-dentro-de-jogos.md`).
- Cap. 74 — NPCs com IA generativa (`cap-74-npcs-ia-generativa.md`).
- Cap. 75 — Limitações e arquitetura híbrida (`cap-75-limitacoes-arquitetura-hibrida.md`). Termina com "Estado do Livro (fim da Parte X)" e `➡️ **Próximo:**` para `../parte-11/cap-76-conceito.md`.

**Parte X concluída.** Palavras (wc -w, código incluído / só prosa): 69 = 6.510 / 5.765; 70 = 5.116 / 4.468; 71 = 5.412 / 4.549; 72 = 5.302 / 4.580; 73 = 7.987 / 5.654; 74 = 7.773 / 4.999; 75 = 5.247 / 4.795. Blocos de código com número par de cercas em todos.

## 2. Classes, tags, CVars, cheats e testes criados

**Cap. 69** (ferramenta, sem código de jogo):
- `docs/ia/CONTEXTO.md` (arquivo de contexto para pessoas e IAs: versão, convenções, decisões firmadas, armadilhas conhecidas, limites da IA, como verificar).
- `docs/ia/protocolo.md` (7 passos antes de aceitar código vindo de IA).
- `docs/ia/apis-verificadas.md` (API · header · versão · data).
- `docs/ia/prompts/` (biblioteca de prompts por tarefa) — 🔁 as seções "Uso de IA" viram biblioteca.
- `scripts/run-tests.ps1` (Build.bat + `UnrealEditor-Cmd.exe -ExecCmds="Automation RunTests Vigilia" -TestExit=...`; ⚠️ argumentos a conferir na versão).

**Cap. 70** (ferramenta, C++ padrão fora da engine):
- `tools/balance_sweep.cpp` (varre dano × RPM da pistola dos vigias; metas TTK p50 ∈ [0,5; 1,0] s com 70% de acerto e TTD p50 ≥ 2 s com acerto suposto de 35% dos vigias; CSV; semente 2026).
- `docs/design/ideias.md` (registro: origem eu/IA/playtest, status, motivo, falsificador); `loops.md` ganha "RISCOS DETECTADOS"; `combate.md` v0.2 com faixa de design explícita e candidatas da varredura.

**Cap. 71:**
- Cheat de editor `UVGCheatManager::VGExportScript()` (`#if WITH_EDITOR`; Asset Registry → `Saved/Narrative/roteiro.md` com texto, condição, `GrantFacts` e escolhas de todo `UVGDialogueData`, e páginas/`ReadFact` de todo `UVGDocumentData`). ⚠️ `GetAssetsByClass(GetClassPathName())` (UE 5.1+) e `FGameplayTagQuery::GetDescription()` marcados para conferir.
- `Build.cs`: `"AssetRegistry"`.
- `docs/narrativa/biblia.md` (status `[CÂNONE]`/`[RASCUNHO]`/`[NUNCA]`, pessoas, regras de voz verificáveis, glossário); `docs/ia/prompts/revisar-roteiro.md` (6 verificações: contradição, ordem, conhecimento, condição, NUNCA, voz).
- Conteúdo para o protótipo dos Caps. 73–74: `DA_Dlg_Free_*` (um por intenção: `Ask.Objective`, `Ask.TurnoC`, `Ask.Moraes`, `Ask.Presence`, `Talk.Fear`, `Ask.Sonia`, `Unknown`, mais a fala "ocupada"), prioridade Normal, `bOnce = false`, `Next = End` em cada nó; texto em `ST_Radio_Livre`. Variantes por `S1.BreakersRestored`, `S1.Completed`, `Document.Logbook.Read`, `Document.Memo.Read`. `Ask.Presence` sem variante (nunca explica).

**Cap. 72:**
- 🔁 `UVGUtilityProfile` (`AI/Utility/VGUtilityProfile.h`, `UPrimaryDataAsset` com `TArray<FVGUtilityAction> Actions`). O `UBTService_VGUtilitySelect` troca `TArray<FVGUtilityAction> Actions` por `TObjectPtr<const UVGUtilityProfile> Profile` e chama `VGUtility::SelectBest(Profile->Actions, …)`. Conteúdo: `/Game/Vigilia/Data/AI/DA_Utility_Vigia`.
- Teste `Vigilia.AI.Utility.Scenarios` (`Tests/VGUtilityScenarioTest.cpp`): carrega o perfil real via `LoadObject`; linha de base + sobrescritas; cenários proibitivos (`bForbidden`); mensagem com todas as pontuações.
- Docs: `docs/design/ai/{bt_vigia.txt, bt_presenca.txt, curvas.md, eqs.md}`.
- Curva de cobertura por vida calculada: logística decrescente, `x0 = 0,475`, `k = ln 9 / 0,125 ≈ 17,6` (u(0,6)=0,1; u(0,35)=0,9); piso opcional `0,05 + 0,95·u` porque perto de zero é veto no produto compensado.

**Cap. 73 — infraestrutura do protótipo (pasta nova `Source/Vigilia/GenAI/`):**
- `Build.cs`: `"HTTP"`, `"Json"` (públicas) e `PublicDefinitions.Add("VG_WITH_GENAI=" + (Target.Configuration != UnrealTargetConfiguration.Shipping ? "1" : "0"))`.
- `UVGGenAISettings` (`UDeveloperSettings`, Config=Game, DefaultConfig; `GatewayUrl = http://127.0.0.1:8787/v1/complete`, `DeadlineSeconds = 3`, `MaxRequestsPerMinute = 6`, `MaxCacheEntries = 64`; nenhum segredo).
- `VGLLMTypes.h` (C++ puro): `EVGLLMResult {Ok, Cached, Timeout, Failed, Refused}`, `FVGLLMRequest {Task, PromptVersion, Instructions, Input, Culture, MaxOutputChars, DeadlineSeconds}`, `FVGLLMResponse {Result, Text, LatencySeconds}`, `FVGLLMResponseDelegate`.
- `namespace VGLLMRules`: `SanitizeInput`, `MakeCacheKey`, `TryConsumeBudget` (janela 60 s), `BuildRequestBody` (FJsonObject), `ParseResponseBody` (`{"text": …}`).
- `UVGLLMSubsystem` (`UGameInstanceSubsystem`; `ShouldCreateSubsystem` = `VG_WITH_GENAI != 0`; `Get(WorldContext)`; `IsEnabled()`; `Complete(Request, OnDone)` — nunca bloqueia, termina exatamente uma vez; `FHttpModule::Get().CreateRequest()` + `OnProcessRequestComplete().BindUObject(..., Id)`; `check(IsInGameThread())` no callback; prazo em relógio de parede via `FTSTicker`; resolve antes de `CancelRequest`; cache FIFO; modo falso lê `Saved/GenAI/fake_reply.txt`; log sem a entrada da jogadora).
- CVars: `vg.GenAI.Enabled` (0), `vg.GenAI.Fake` (0), `vg.GenAI.FakeLatency` (0,8), `vg.Debug.GenAI`.
- Teste `Vigilia.GenAI.LLM.SanitizeCacheBudget` (`Tests/VGLLMRulesTest.cpp`).
- Contrato do gateway do projeto (`POST /v1/complete`, `{task, prompt_version, instructions, input, culture, max_output_chars}` → `{text}`), documentado em `docs/ia/gateway.md`; gateway em `tools/gateway/` na linguagem do leitor (código não mostrado).

**Cap. 74 — o NPC híbrido (Sônia, perguntas livres, intenções fechadas):**
- `UVGRadioTalkData` (`UPrimaryDataAsset`; `Persona` sem `[NUNCA]`, `TArray<FVGRadioIntent> Intents`, `UnknownIntent = "Unknown"`, `BusyResponse`, `GeneratedSpeaker`, `GeneratedVoice`, `Glossary`, `MaxLineChars = 160`, `PromptVersion`, `FindIntent`, `IsDataValid`) e `FVGRadioIntent {Id, Description, Keywords, Response}`.
- 🔁 `UVGGenAISettings::RadioTalk` (`TSoftObjectPtr<UVGRadioTalkData>`).
- `namespace VGRadioTalkRules`: `FAllowedAnswer {Intent, Description, Line}`, `ELineCheck {Ok, Empty, TooLong, UnknownNameOrNumber}`, `BuildInstructions`, `ParseReply` (recorta `{…}`), `CheckLine` (nomes próprios/números só da fala permitida + glossário), `ClassifyByKeywords` (ouvido de reserva).
- `UVGRadioTalkSubsystem` (`UWorldSubsystem`): `CanTalkNow()` (Diretor `Relax`/`Recovery`, `Status.Zone.Safe`, `UVGDocumentReaderSubsystem::IsReading()`, `UVGDialogueSubsystem::IsSpeaking()`, uma pergunta por vez), `Ask(Question)`; *grounding* por `VGDialogueRules::FindPlayable` sobre `UVGNarrativeSubsystem::GetFacts()/GetSaidLines()`; callback `CreateWeakLambda`; reconfere calmaria e fala permitida ao receber; fala gerada = conversa efêmera `NewObject<UVGDialogueData>(this, NAME_None, RF_Transient)` com UM nó copiado do autorado (texto via `FText::FromString`, falante `DA_Falante_Sonia_Gerada`, voz = clique).
- 🔁 `UVGDialogueSubsystem`: `FinishLine`/`EndConversation` não chamam `MarkLineSaid`/`MarkConversationPlayed` para conversas com `RF_Transient` (efeitos sim, memória não).
- CVar `vg.GenAI.RadioTalk.Verbalize` (0 = só ouvido, fala autorada dublada; 1 = também paráfrase). Cheat `VGAskSonia "texto"`. Entrada `IA_FalarRadio` + `WBP_PerguntaRadio` no modo `EVGInputMode::UI`; recusa = `SFX_RadioChiado`.
- Teste `Vigilia.GenAI.RadioTalk.ParseCheckClassify` (`Tests/VGRadioTalkRulesTest.cpp`).
- Conteúdo: `DA_RadioTalk_Sonia`, `DA_Dlg_Free_*`, `DA_Falante_Sonia_Gerada`, `ST_Radio_Livre`, `SFX_RadioClique`, `SFX_RadioChiado`. Avaliação: `docs/ia/eval/sonia.csv` (inclui paráfrases e injeções) e `docs/ia/eval/resultados.md`.

**Cap. 75:**
- `docs/adr/0010-ia-generativa-runtime.md` (decisão: release **sem** IA em runtime; lacunas para os números do leitor; critério de reabertura).
- 🔁 `Vigilia.Build.cs`: `const bool bAllowGenAIInShipping = false;` e `bWithGenAI = Target.Configuration != Shipping || bAllowGenAIInShipping`.
- `docs/ia/relatorio-prototipo.md` (métricas, playtest, achados sobre o jogo).

## 3. Decisões firmadas

- Conversa para aprender; IDE para o que já domina; agente só para tarefas mecânicas com critério de pronto verificável (`run-tests.ps1`).
- Escada de verificação: compila → teste → PIE instrumentado → código da engine → documentação → playtest. O código da engine é a fonte da verdade.
- Revisão por lista de armadilhas conhecidas (as do guia de produção + as do `DEVLOG.md`).
- O livro é declarado, no Cap. 69, como produzido com IA generativa e revisado; `revisao-2026-11-03.md` é o estudo de caso de "erros plausíveis".
- Design (Cap. 70): a IA diverge, a convergência é humana; toda ideia vira hipótese com falsificador; preferir variações que **conectam** sistemas existentes; números de balanceamento só de programas reproduzíveis (a IA escreve e lê, não calcula); otimizador automático recusado.
- Variações da lanterna escolhidas para protótipo: dínamo de manivela com ruído; bateria compartilhada com a sobrecarga. Recusadas: inventário de baterias, barra de sanidade, feixe concentrado (dissonância "perita, não soldada").
- Arquitetura híbrida (Cap. 75): quatro camadas (Game AI decide; sistemas de NPC guardam estado e entregam; planejador ordena — quests + Diretor; IA generativa interpreta/verbaliza), com a **regra das fronteiras**: a camada gerativa não decide, não escreve estado e sempre tem reserva. **Preservação:** o jogo é completo sem o serviço. "Quando usar" = 8 perguntas (entrada aberta, latência na ficção, reserva, pior caso por estrutura, sem agência, custo, mensurável, playtest). **Decisão para a Parte XI: Abordagem A** — release sem IA em runtime (ADR-0010); protótipo só em desenvolvimento; ferramentas offline (69–72) no fluxo de produção.
- NPC híbrido (Cap. 74): **Sônia com perguntas livres em intenções fechadas** (e não variações de *bark* dos vigias). Critério: modelo em runtime só onde a **entrada é aberta**; *barks* = entrada fechada + latência zero + voz 3D → offline. Game AI e narrativa decidem quando e o quê; o modelo interpreta ("ouvido", padrão) e opcionalmente parafraseia ("boca", experimento). *Grounding* estrutural: o prompt só contém falas já permitidas pelos fatos ("não peça segredo ao modelo; não lhe dê o segredo"). Reserva em cadeia sempre autorada e dublada; a funcionalidade existe sem modelo (palavras-chave). Fala gerada passa pelo canal do Cap. 44 sem mudar a interface dele.
- LLM em runtime (Cap. 73): o jogo decide, o modelo produz texto, o jogo valida; **gateway do projeto** (chave, moderação, limites, *kill switch*), nunca fornecedor direto; nenhuma chamada bloqueia a game thread; toda chamada termina num prazo do jogo (relógio de parede); **reserva autorada sempre** (o jogo é completo sem o modelo); sem *streaming* na Vigília (validação exige a frase inteira); privacidade por construção (desligado por padrão, consentimento, minimização, logs sem conteúdo); três camadas de teste (regras, modo falso, avaliação versionada pelo prompt). Escolha de arquitetura: B (cliente → gateway) para o protótipo; D (pré-geração offline) para todo conteúdo do jogo.
- Game AI (Cap. 72): IA generativa **constrói** (rascunho em texto, revisão dirigida, cenários de teste); Game AI **decide**. Nenhum modelo de linguagem participa de decisão de agente em runtime. Garantias de design ("nenhum ataque sem telegrafia") ficam na estrutura da árvore.
- Narrativa (Cap. 71): texto final humano; IA revisa, varia e rascunha tradução. *Barks* dos vigias = geração **offline** + curadoria + gravação (nenhum modelo em runtime). `[NUNCA]` entra na revisão e fica fora da geração ("não peça segredo ao modelo; não lhe dê o segredo").

## 4. Pendências para capítulos seguintes

- **Cap. 84 (build de release):** citar o ADR-0010 e a constante `bAllowGenAIInShipping = false`; confirmar que `vg.GenAI.Enabled` não é ligado em nenhum `.ini`; incluir o checklist de **preservação** (desafio do Cap. 75: o jogo funciona sem rede e sem serviço externo). Ligar a IA num Shipping exige revisar o ADR e cumprir os requisitos do Cap. 73 (consentimento, privacidade, regras de loja, moderação, *kill switch*).
- **Cap. 76 (conceito):** decidir o destino das falas livres de Sônia (`DA_Dlg_Free_*`): menu autorado no release (Abordagem A do Cap. 74), ou só no protótipo.
- **Cap. 77 (arquitetura):** revisar o `docs/design/arquitetura.md` com o diagrama de camadas do Cap. 75 (exercício Parte 4).
- **Cap. 85 (postmortem):** usar os três registros pedidos no Cap. 75 (tempo economizado/custado pela IA, erros pegos pelo protocolo, o que o protótipo ensinou sobre o jogo) e a coluna Origem do `docs/design/ideias.md` (Cap. 70).
- **Cap. 62 (packaging) / 84:** checar que o `DefaultGame.ini` não contém segredo e que a pasta `GenAI/` não executa nada em Shipping.
- **Cap. 55 (UI/UX):** `WBP_PerguntaRadio` (caixa de texto no modo `UI`), marcador visível de texto gerado na `WBP_Legenda` quando o falante é `DA_Falante_Sonia_Gerada`, e a tela de consentimento da funcionalidade (texto escrito no exercício do Cap. 73).
- **Cap. 56 (save):** nada da IA generativa é salvo; conversas efêmeras (`RF_Transient`) não entram em `SaidLines`/`PlayedConversations`. Os fatos concedidos por falas geradas são os da fala autorada e entram normalmente.
- **Cap. 80/81 (projeto final):** se o protótipo for mantido em build de desenvolvimento, as falas livres de Sônia dos setores 2 e 3 seguem o padrão do Cap. 71 (uma conversa por intenção, variantes por fato).

- **Exploit "ler para congelar o Diretor"** (Cap. 70): o `UVGDirectorSubsystem::UpdatePhase` (Cap. 42) não avança `Relax→BuildUp` nem `BuildUp→Peak` enquanto a jogadora lê. Opções registradas: aceitar / teto de leitura (constante nova em `VGDirectorTuning`) / pico ao fechar o documento. Decisão do leitor no `DEVLOG.md`. ✅ Fechada no Cap. 82: teto de leitura só na transição `Relax→BuildUp` (`UVGDirectorProfile::MaxReadingHold`).

## 5. Ajustes sugeridos em capítulos de outras partes

- **Introdução, seção 9.3:** pode apontar para `docs/ia/CONTEXTO.md` e `docs/ia/protocolo.md` como os artefatos concretos do princípio "acelerar o entendimento".
- **Cap. 42 (Diretor):** registrar nas Armadilhas a interação "leitura bloqueia as transições do Diretor" → leitura longa congela o ritmo (achado do Cap. 70).
- **Cap. 5 (`loops.md`) e Cap. 21 (`combate.md`):** podem citar que a v0.2 dos documentos nasce no Cap. 70 (faixa de design explícita, riscos detectados).
- **Cap. 7 (lista de módulos do `Build.cs`):** acrescentar `AssetRegistry` (Cap. 71), `HTTP` e `Json` (Cap. 73).
- **Cap. 43 (documento de narrativa):** pode apontar para `docs/narrativa/biblia.md` (Cap. 71) como o lugar do cânone, das regras de voz e da seção `[NUNCA]`.
- **Cap. 47 (auditoria combinatória):** pode citar o `VGExportScript` (Cap. 71) como o complemento textual da auditoria estrutural.
- **Cap. 40 (Utility):** o desafio "veterano/recruta" pode apontar o 🔁 do Cap. 72 (`UVGUtilityProfile` por arquétipo) como a resposta adotada; o README deve listar `UVGUtilityProfile` e o teste `Vigilia.AI.Utility.Scenarios`.
- **Cap. 80 (AI do projeto final):** usar o teste de cenários como critério de pronto da IA dos vigias e checar a garantia "nenhum ataque sem telegrafia" na `BT_Presenca`.
- **Caps. 44 e 46 (`UVGDialogueSubsystem`):** registrar o 🔁 do Cap. 74 (memória ignorada para conversas `RF_Transient`) ou, ao menos, citá-lo; e o `IsPlayerReading()` do canal e do Diretor (Cap. 42) pode migrar para `UVGDocumentReaderSubsystem::IsReading()` (Cap. 48), dono do modo `Reading` — o Cap. 74 é o terceiro leitor dessa pergunta.
- **GUIA-DE-PRODUCAO.md, seção 3, e Introdução 6.3 (pastas):** acrescentar `Source/Vigilia/GenAI/` (protótipo de IA generativa em runtime, isolado; criado no Cap. 73).
- **README:** dependências passam a incluir `DeveloperSettings` (Cap. 46), `AssetRegistry` (Cap. 71), `HTTP` e `Json` (Cap. 73); a definição `VG_WITH_GENAI` (0 em Shipping).

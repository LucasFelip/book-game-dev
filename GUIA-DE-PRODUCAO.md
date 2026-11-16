# Guia de produção do livro (para quem escreve os capítulos 46–85)

Este guia reúne as regras de continuidade, estilo e correção técnica do livro. A **spec original** está em `Prompt pra gerar livro para estudo de jogos.txt`, sobretudo nas seções 11, 12, 13 e 22, e prevalece sobre este guia. O **estado do projeto** está no `README.md`, e o **roadmap**, na seção 7 de `00-introducao.md`.

## 1. Arquivos (nomes fixos, para os links entre partes funcionarem)

| Cap. | Arquivo |
|---|---|
| 46 | `parte-06/cap-46-narrative-state.md` |
| 47 | `parte-06/cap-47-branching.md` |
| 48 | `parte-06/cap-48-environmental-storytelling.md` |
| 49 | `parte-06/cap-49-cinematics.md` |
| 50 | `parte-07/cap-50-level-design.md` |
| 51 | `parte-07/cap-51-lighting.md` |
| 52 | `parte-07/cap-52-audio.md` |
| 53 | `parte-07/cap-53-animation.md` |
| 54 | `parte-07/cap-54-vfx.md` |
| 55 | `parte-07/cap-55-ui-ux.md` |
| 56 | `parte-08/cap-56-save-systems.md` |
| 57 | `parte-08/cap-57-persistence.md` |
| 58 | `parte-08/cap-58-performance.md` |
| 59 | `parte-08/cap-59-profiling.md` |
| 60 | `parte-08/cap-60-optimization.md` |
| 61 | `parte-08/cap-61-debugging.md` |
| 62 | `parte-08/cap-62-packaging.md` |
| Int. II | `interludio-2/decompondo-mundo-aberto.md` |
| 63 | `parte-09/cap-63-client-server.md` |
| 64 | `parte-09/cap-64-authority.md` |
| 65 | `parte-09/cap-65-replication.md` |
| 66 | `parte-09/cap-66-rpc.md` |
| 67 | `parte-09/cap-67-prediction.md` |
| 68 | `parte-09/cap-68-latency.md` |
| Int. III | `interludio-3/multiplayer-avancado.md` |
| 69 | `parte-10/cap-69-ia-ferramenta-programacao.md` |
| 70 | `parte-10/cap-70-ia-game-design.md` |
| 71 | `parte-10/cap-71-ia-narrative-design.md` |
| 72 | `parte-10/cap-72-ia-game-ai.md` |
| 73 | `parte-10/cap-73-llms-dentro-de-jogos.md` |
| 74 | `parte-10/cap-74-npcs-ia-generativa.md` |
| 75 | `parte-10/cap-75-limitacoes-arquitetura-hibrida.md` |
| 76–85 | `parte-11/cap-76-conceito.md`, `cap-77-arquitetura.md`, `cap-78-vertical-slice.md`, `cap-79-implementacao.md`, `cap-80-ai.md`, `cap-81-narrative.md`, `cap-82-polish.md`, `cap-83-performance.md`, `cap-84-build.md`, `cap-85-postmortem.md` |

Ordem de leitura e o "➡️ **Próximo:**" de cada arquivo:
- 49 → 50; 55 → 56; 62 → Interlúdio II; Interlúdio II → 63; 68 → Interlúdio III; Interlúdio III → 69; 75 → 76.
- 85 encerra o livro.
- O **Projeto Arena** é o projeto da Parte IX e é construído ao longo dos Caps. 63–68, sem arquivo próprio.
- Toda primeira página de parte começa com `# PARTE N — Título`, uma linha em itálico com o projeto, `---` e depois `# Capítulo NN — Título`. Use `parte-06/cap-43-narrative-design.md` como modelo.

## 2. Estrutura de cada capítulo

Siga o padrão dos capítulos mais recentes (`parte-06/cap-44-dialogue-systems.md` e `cap-45-quest-systems.md`, que são as **referências de estilo**). Os títulos de seção são estes, nesta ordem, com o capítulo em `##`:

1. `## Objetivo`: uma lista "Ao final deste capítulo você deve conseguir".
2. `## Contexto`: por que o conceito existe, e qual dor do projeto ele resolve.
3. `## NN.1 …`, `## NN.2 …`: os conceitos, com duas camadas.
   - Primeiro o domínio de jogos.
   - Depois, quando houver uma analogia útil, uma ponte com engenharia de software: `> 🌉 **Ponte:**` seguido de `> 🧱 **Onde a ponte cai:**`. Nunca force a ponte.
4. `## Estudo de caso: …` ou `## Estudos de caso`, com jogos das referências do leitor (seção 5).
5. `## Comparação com o desenvolvimento tradicional`: uma tabela "conceito | o que você conhece | onde a analogia cai".
6. `## Unreal Engine: …`: o que a engine oferece e o que não oferece.
7. `## Abordagens`, quando há escolha real: uma tabela A/B/C com complexidade, performance, extensibilidade, manutenção, prototipação e adequação, seguida da **Decisão**.
8. `## Implementação`: o código, seguido de `### Explicação das decisões`.
9. `## Projeto N — …`: o que muda no projeto Vigília (ou Arena), com 🔁 para refatorações.
10. `## Decisões arquiteturais`: uma lista numerada.
11. `## Armadilhas`
12. `## Exercício`: partes com tempo estimado, por exemplo "**Parte 1 — … (1,5 h).**".
13. `## Desafio — título`
14. `## Uso de IA`: de 3 a 4 prompts em blocos `>`, terminando em "**Cuidado específico:**".
15. `## Checklist`: itens `- [ ]`.
16. `## Para ir além`: só recursos reais (seção 6).
17. Uma linha `---` e o `➡️ **Próximo:** [Capítulo NN — Título](caminho.md)`.

Os títulos `Objetivo`, `Armadilhas`, `Exercício`, `Desafio`, `Uso de IA` e `Checklist` são **obrigatórios**. Um script de auditoria confere cada um deles.

Sobre o tamanho:
- **Capítulos técnicos:** de 5 a 9 mil palavras, código incluído.
- **Capítulos conceituais:** de 3,5 a 6 mil.
- **Interlúdios:** de 4 a 8 mil.
- **Não encha.** A revisão do livro achou redundância nos capítulos antigos: o mesmo ponto repetido na ponte, numa tabela consolidada, em Decisões e no Checklist. Diga cada coisa uma vez e com profundidade.

## 3. Convenções do projeto e do código

- **Idioma:** português do Brasil, com termos técnicos em inglês em itálico na primeira vez (*blockout*, *replication*). A protagonista é **Helena Duarte**; a pessoa que joga é **"a jogadora"**. Sônia é a voz do rádio (Central de Despacho). O Eng. Valter Moraes só existe em documentos. O setor 1 é a Casa de Força (*Turno da Noite*). A usina é a de **Serra Funda**, e o turno C desapareceu em **14/08/1994**.
- **Projeto:** `Vigilia`, módulo único, prefixo `VG`, macro `VIGILIA_API`.
  - Pastas: `Source/Vigilia/{Core, Player, Interaction, Combat, AI, Narrative, World, Save, UI, GenAI, Debug, Tests}`. `GenAI/` é o protótipo isolado da Parte X e fica fora do release (`VG_WITH_GENAI` = 0 em Shipping).
  - Includes no formato `"Core/VGLog.h"`. Categoria de log: `LogVigilia`.
- **Depuração:**
  - CVars: `vg.Debug.<Sistema>` (`TAutoConsoleVariable`).
  - Cheats: `UFUNCTION(Exec)` em `UVGCheatManager`, com nome `VGAlgo`.
  - Testes: `IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVG…Test, "Vigilia.<Área>.<Nome>", EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)`, dentro de `#if WITH_DEV_AUTOMATION_TESTS`.
- **Regras puras e testáveis:** num `namespace VG<Algo>Rules`, como `VGObjectiveRules` (Cap. 31), `VGDialogueRules` (Cap. 44) e `VGQuestRules` (Cap. 45). Cada sistema com lógica não trivial deixa **um** teste.
- **Dados e validação:**
  - Data Assets: `UPrimaryDataAsset`.
  - Validação: `virtual EDataValidationResult IsDataValid(class FDataValidationContext& Context) const override;`, dentro de `#if WITH_EDITOR`.
- **Tags e barramento:**
  - Gameplay Tags nativas em `VGGameplayTags.h/.cpp` (`UE_DECLARE_GAMEPLAY_TAG_EXTERN` / `UE_DEFINE_GAMEPLAY_TAG`). Tags de conteúdo são criadas no editor e registradas em `docs/design/tags.md`.
  - Barramento de eventos: `UVGGameplayEventSubsystem::PublishFrom(WorldContext, Channel, Instigator, Target, Context, Magnitude)`.
- **Comentários `// Simplificação:`** marcam decisões deliberadamente simples e dizem até onde vão e em que capítulo são revistas.
- **Ativos:** prefixos `BP_`, `DA_`, `WBP_`, `IA_`, `IMC_`, `MS_`, `NS_`, `M_`/`MI_`, `SM_`, `SK_`, `ABP_`, `BT_`, `BB_`, `EQS_`, `LS_` (*Level Sequence*), `ST_` (*String Table*), `L_` (nível).
- **Continuidade:**
  - Não contradiga decisões firmadas (README, "Decisões de design firmadas").
  - Refatorações de código anterior levam 🔁 e explicam o que havia antes, o problema, a nova solução, os *trade-offs* e o que se aprendeu.
  - Use as classes que já existem, conferindo nomes e assinaturas nos capítulos anteriores com `grep`, antes de inventar outras.

## 4. Correção técnica: armadilhas que a revisão já encontrou

Não as repita. Na dúvida sobre uma API, **leia** o capítulo anterior que a usa ou escreva "⚠️ verifique na sua versão da engine".

- **Blueprint e reflexão:** uma `UFUNCTION` `const` com `BlueprintCallable` vira nó **puro**. Para manter os pinos de execução, declare `BlueprintPure = false`.
- **Behavior Trees:**
  - A memória de nó chega **zerada, não construída**. Use `InitializeMemory`/`CleanupMemory` com `InitializeNodeMemory<T>`/`CleanupNodeMemory<T>` (UE 5.2+).
  - `OnBecomeRelevant`/`OnCeaseRelevant` de services exigem `bNotifyBecomeRelevant`/`bNotifyCeaseRelevant = true`.
- **IA:** o `AAIController` reescreve a control rotation a cada tick. Para mirar, use `SetFocus`.
- **Colisão:** um canal novo com resposta padrão Block também bloqueia na **cápsula** do personagem. Para tiro, a cápsula ignora o canal e a malha bloqueia.
- **Ciclo de vida dos atores:**
  - A ordem de `BeginPlay` **entre atores** não é garantida. Estado inicial próprio vai em `PostInitializeComponents`.
  - Valores editados no Blueprint não existem no construtor. Aplique-os em `PostInitializeComponents`/`BeginPlay`.
- **Reentrância:** não mute o estado de quem está notificando, dentro da notificação. Use cópias, índices em vez de referências quando o `TArray` pode crescer, e filas processadas depois (Cap. 45).
- **Relógios:** declare o relógio de cada sistema.
  - `GetTimeSeconds`: dilata e pausa.
  - `GetRealTimeSeconds`: não dilata e não pausa.
  - `GetAudioTimeSeconds`: pausa e não dilata.
- **Contêineres e ponteiros:** `TSet<TWeakObjectPtr>.Remove(nullptr)` não remove ponteiros obsoletos; itere e remova. E `TSubclassOf` não se constrói a partir de `const UClass*`.
- **Build.cs:** declare os módulos (`PhysicsCore`, `Niagara`, `AIModule`, `NavigationSystem`, `GameplayTasks`, `UMG`, `NetCore`, `HTTP`, `Json`/`JsonUtilities`…) no capítulo em que passam a ser usados.
- **Imprecisões frequentes:** prefira não afirmar números ou comportamentos da engine sem certeza. Quando afirmar, aponte a fonte (o código da engine, a documentação oficial).

## 5. Jogos comerciais: honestidade

Toda afirmação sobre um jogo comercial leva um rótulo:

- **[FATO PÚBLICO]**: publicado pelo estúdio, em documentação, talk ou postmortem, ou diretamente observável jogando. Diga qual dos dois.
- **[INFERÊNCIA]**: o que provavelmente está por trás do comportamento.
- **[SIMPLIFICAÇÃO DIDÁTICA]** ou **[HIPOTÉTICO]**: modelos do livro.

Regras:
- Nunca invente detalhes de implementação proprietária.
- Títulos de palestras e de livros só se você tiver certeza; caso contrário, descreva e escreva "(confira o título no GDC Vault)".

Referências do leitor:
- Alan Wake 1 e 2, Control, Quantum Break, Max Payne 1–3 (o 3 é da Rockstar).
- Outlast, Amnesia (The Dark Descent, A Machine for Pigs, que é a favorita, e Rebirth).
- Battlefield 4 e 6, Call of Duty (a "era de ouro" e o MW 2019), Star Wars Battlefront II, Apex.
- PES 2011 e FIFA 14 no PS2, jogados com primos (o eFootball roda em Unreal desde 2021).
- GTA San Andreas, IV e V.

Siga os seis passos da spec 3.5: experiência → sistema → decisão → tecnologia → versão simplificada → lição.

## 6. "Para ir além"

Só vale recurso real:
- documentação oficial (dev.epicgames.com/documentation, cppreference.com);
- GDC Vault (gdcvault.com);
- livros conhecidos, com título e autor certos (por exemplo, *Game Programming Patterns*, de Robert Nystrom; *Multiplayer Game Programming*, de Glazer e Madhav; *Game Engine Architecture*, de Jason Gregory; *The Art of Game Design*, de Jesse Schell);
- artigos clássicos amplamente conhecidos (os de Gabriel Gambetta sobre *client-side prediction*; a documentação de rede da Valve, *Source Multiplayer Networking*).

Não invente links nem cursos.

## 7. Estado de cada parte

Quem escreve uma parte mantém um `ESTADO.md` na pasta dela, atualizado **depois de cada capítulo**, com:

1. capítulos concluídos;
2. classes, tags, CVars, cheats e testes criados (os nomes exatos);
3. decisões firmadas;
4. pendências para capítulos seguintes;
5. ajustes sugeridos em capítulos de **outras** partes. Não edite arquivos fora da sua pasta: anote aqui.

O `README.md` é atualizado só pelo coordenador, a partir desses arquivos.

## 8. API planejada para os Caps. 46–49 (para quem precisar referenciar antes de existirem)

- **Cap. 46.** `UVGNarrativeSubsystem` (`UGameInstanceSubsystem`) passa a ser o dono dos fatos, que saem do `UVGDialogueSubsystem`.
  - Consultas: `AddFact`, `RemoveFact`, `HasFact`, `GetFacts`.
  - Contadores: `SetCounter`, `AddToCounter`, `GetCounter`.
  - Memória de diálogo: `MarkLineSaid`/`HasSaidLine`, `MarkConversationPlayed`.
  - Registros de quest: `FVGQuestRecord`.
  - Anúncio de mudança: `OnFactChanged`.
  - Save: `FVGNarrativeSnapshot` com `CaptureSnapshot()`/`RestoreSnapshot()`, que o Cap. 56 serializa.
  - Regras de derivação "quando acontecer o evento X, registre o fato Y" em Data Asset (`UVGFactRuleSet`).
- **Cap. 47.** Consequências tardias e convergência: variantes por fato, *flags* de "o que Helena contou a Sônia".
- **Cap. 48.** Documentos como dados (`UVGDocumentData`), registro de leitura como fato, o leitor de documentos (modo `Reading`), narrativa ambiental.
- **Cap. 49.** Sequencer: `LS_*`, eventos de Sequencer chamando sistemas, transições entre gameplay e cinemática, cancelamento e "pular", trava do Diretor durante a cena, diálogo dentro de cinemática pelo canal do Cap. 44.

Se o capítulo real divergir deste plano, o capítulo real prevalece. Confira antes de citar.

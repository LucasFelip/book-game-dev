# Capítulo 75 — Limitações e arquitetura híbrida

## Objetivo

Ao final deste capítulo você deve conseguir:

- mapear **onde modelos de linguagem falham em jogos**: consistência, latência, custo, segurança, controle de design e ludonarrativa;
- associar a cada falha um **padrão de contenção** e localizar esse padrão no código da Vigília;
- desenhar a **arquitetura híbrida** completa (Game AI tradicional, sistemas de NPC, planejamento e IA generativa), com a regra que governa as fronteiras entre as camadas;
- decidir, com uma lista de perguntas, **se** uma funcionalidade deve usar um modelo em runtime;
- registrar a decisão sobre o protótipo num **ADR** e levá-la para a Parte XI, com o build de release protegido por uma exceção explícita.

---

## Contexto

Os Capítulos 73 e 74 construíram um protótipo honesto: um cliente que nunca bloqueia, uma Sônia que só entende sete intenções, só parafraseia falas já permitidas e cai numa fala dublada a qualquer falha. Você jogou com ele, mediu o ouvido contra as palavras-chave e perguntou a pessoas de playtest se preferem a paráfrase ou a fala gravada.

Este capítulo fecha a Parte X com três perguntas. **Onde, exatamente, modelos de linguagem falham em jogos?** **Como a arquitetura contém cada falha?** E a mais prática: **o que da Parte X vai para o projeto final?** A Parte XI começa no próximo capítulo, com o documento de conceito da Vigília completa, e precisa saber o que herda.

A spec do livro pediu, desde o começo, um diagrama de quatro ramos para estudar "depois dos fundamentos": Game AI tradicional, sistemas de NPC, planejador e IA generativa. Este é o capítulo em que esse diagrama ganha conteúdo, porque agora cada ramo tem código.

---

## 75.1 Consistência

Um modelo de linguagem não tem estado entre chamadas. Tudo o que ele "lembra" está no contexto que você manda, e o contexto é limitado em tamanho e caro em tokens. As falhas típicas:

- **Contradição entre respostas.** Sem memória, a segunda resposta pode contradizer a primeira ("Moraes era o engenheiro-chefe" e, minutos depois, "Moraes? Nunca ouvi falar").
- **Deriva de personagem.** Ao longo de uma conversa longa, a voz escorrega para o registro "médio" do modelo: mais educada, mais explicativa, menos Sônia.
- **Deriva de versão.** O fornecedor atualiza o modelo e o mesmo prompt passa a produzir outra coisa (Capítulo 73).
- **Fatos inventados com segurança**, quando a pergunta cai fora do que o contexto cobre.

A correção que costuma ser sugerida é dar ao modelo **mais memória**: histórico da conversa, resumo de tudo o que aconteceu, uma descrição longa da personagem. Isso piora três coisas ao mesmo tempo: o custo (o histórico é pago a cada chamada), a superfície de *prompt injection* (o histórico contém texto da jogadora) e a deriva (quanto mais contexto livre, mais espaço para o modelo "preencher").

A contenção da Vigília vai na direção contrária:

- **O estado mora fora do modelo**, no `UVGNarrativeSubsystem` (Capítulo 46). O que Sônia sabe é um conjunto de fatos, e não uma conversa lembrada.
- **Cada pergunta é independente.** Nenhum histórico vai ao modelo; a "memória" de Sônia são os fatos que as respostas autoradas concedem.
- **O conteúdo é a fala permitida**, escrita e revisada (Capítulo 71); o modelo só a parafraseia.
- **Cache** dá a mesma resposta à mesma pergunta no mesmo estado: consistência como efeito colateral (Capítulo 73).

---

## 75.2 Latência

O livro inteiro mediu tempo em frames, e um modelo responde em segundos. Isso exclui modelos de linguagem, em runtime, de tudo o que precisa acontecer **agora**:

- decisões de agentes a cada tick (Capítulo 72);
- *barks* sincronizados com eventos de combate (Capítulo 74);
- falas sincronizadas com animação facial, cinemática ou física;
- qualquer coisa num caminho que o frame espera.

E a latência só se acomoda onde a **ficção** tem lugar para ela. O rádio da Vigília tem: chiado, clique de transmissão, uma pessoa a quarenta quilômetros procurando nos papéis. Um NPC frente a frente não teria: dois segundos olhando para a jogadora antes de responder parecem defeito. É por isso que a escolha do Capítulo 74 não foi "um NPC com IA", mas uma **voz distante**, num canal que já é lento por natureza.

Contenção: prazo e reserva (Capítulo 73); acomodação diegética; pré-geração offline sempre que a entrada for previsível; o modo "só ouvido", em que a parte lenta (o modelo) só escolhe uma intenção e a resposta tocada é um áudio que já existe.

---

## 75.3 Custo, e o fim do serviço

O custo de um modelo na nuvem é recorrente e cresce com o uso, ou seja, com o **sucesso** do jogo (Capítulo 73). Há um custo menos discutido, e mais grave para um jogo: **o serviço acaba.** Fornecedores mudam preços, descontinuam modelos, alteram termos; o seu gateway vai ser desligado algum dia, nem que seja porque você parou de pagar. Jogos, por outro lado, continuam sendo jogados por anos, às vezes décadas, inclusive offline.

A regra que sai disso é de **preservação**: *o jogo precisa ser completo sem o serviço.* Uma funcionalidade que deixa de existir quando o gateway cai é aceitável; um jogo que deixa de funcionar, não. A Vigília cumpre a regra por construção: sem modelo, a conversa livre degrada para palavras-chave e falas dubladas, e em Shipping nem existe.

Contenção: orçamento por minuto, cache, modelo pequeno (local, se possível) para tarefas baratas como classificar, *kill switch* no gateway, e a reserva autorada.

---

## 75.4 Segurança

As falhas de segurança de um modelo dentro de um jogo vêm em quatro sabores:

1. **Conteúdo** incompatível com a classificação etária pretendida.
2. ***Prompt injection*** pela jogadora: tirar o personagem do papel, arrancar o que ele "sabe", ou fazê-lo dizer algo vergonhoso.
3. **Reputação.** A captura de tela de um NPC dizendo algo absurdo circula mais do que qualquer *trailer*. O "ataque" não precisa ser perigoso; só precisa ser engraçado.
4. **Agência excessiva.** Um modelo que pode chamar funções do jogo (conceder itens, abrir portas, mudar fatos) transforma cada injeção bem-sucedida numa trapaça.

Contenção, da mais forte para a mais fraca: **nenhuma agência** (o modelo não altera estado); **saída fechada** (intenções); ***grounding*** **por falas permitidas** (o segredo nunca está no prompt); **validação** da saída; **moderação** no gateway; **avaliação** com perguntas adversariais a cada versão do prompt. As três primeiras dão garantias; as outras reduzem frequência. O desafio do Capítulo 74 (o livro-razão sob ataque) é o teste dessa hierarquia.

---

## 75.5 Controle de design

Um jogo autoral é uma sequência de decisões sobre **o que a jogadora vive, quando e em que ordem**: o ritmo do Diretor, a ordem das revelações do livro-razão, o tom de cada fala. Um modelo de linguagem é, por definição, uma fonte de variação que o designer não controla fala a fala. Três consequências práticas:

- **QA não enumera saídas.** Testar um sistema gerativo é amostrar. Só garantias estruturais (o que **não pode** acontecer) são verificáveis por completo; o resto é estatística (Capítulo 73, avaliação).
- **Depurar "por que ela disse isso?"** exige reconstruir o pedido: versão do prompt, falas permitidas naquele estado, resultado. O protótipo registra a intenção, o motivo e o tamanho da fala; a versão do prompt vai no pedido. O texto da jogadora, não (privacidade).
- **O ritmo é da Game AI.** Quem decide quando Sônia pode conversar é o Diretor (Capítulo 74), pelo mesmo princípio do Capítulo 42: o sistema de ritmo controla a **frequência** dos eventos, nunca as **regras** deles. A camada gerativa herda essa disciplina: ela não muda as regras das camadas de baixo, nem decide quando entra em cena.

---

## 75.6 Ludonarrativa

A falha mais sutil não é técnica. O Capítulo 43 definiu harmonia ludonarrativa como a mecânica e a história dizendo a mesma coisa. Um modelo de linguagem dentro do jogo cria **promessas mecânicas** que podem contradizer a história:

- **A promessa da caixa de texto.** Uma caixa em que se pode digitar qualquer coisa promete que **qualquer coisa será entendida**. Sônia entende sete intenções. Cada "a linha tá ruim" é a mecânica dizendo "não te ouvi", e, se acontecer demais, a jogadora para de perguntar ou começa a testar o sistema em vez de jogar o jogo.
- **A voz que muda.** Uma Sônia dublada nas falas de roteiro e legendada sem voz nas paráfrases soa como duas personagens. A fala gerada pode até responder melhor à pergunta e, ainda assim, quebrar a presença da atriz.
- **A personagem que a jogadora escreve.** Helena quase não fala; "a jogadora fala por ela" (Capítulo 44). Uma caixa de texto leva isso ao pé da letra: a jogadora pode dar a Helena uma voz que contradiz tudo o que o jogo construiu (piadas, deboche, perguntas meta sobre o próprio jogo).
- **A solidão.** O documento de narrativa (Capítulo 43) já perguntava: *a Sônia fala demais?* Uma Sônia sempre disponível para conversar dissolve o isolamento que o terror da Vigília precisa. Num jogo de terror, o silêncio do rádio é conteúdo.

Contenção, aqui, é design: **escassez** (só no claro, só na calmaria, uma pergunta por vez); **desculpa diegética** para o mal-entendido; **escopo declarado na ficção** ("Sônia só sabe o que está no papel e o que você contou a ela", dito no começo do jogo pela própria Sônia); e o playtest como juiz final, com a pergunta direta: *você preferiu perguntar com as suas palavras, ou teria preferido escolher entre opções?*

> 🌉 **Ponte:** é a diferença entre uma interface que promete mais do que o sistema entrega e uma que mostra o escopo. Uma busca que aceita linguagem natural e erra metade das vezes frustra mais que um formulário com campos claros.
>
> 🧱 **Onde a ponte cai:** num produto, a resposta é deixar o escopo visível. Num jogo de terror, mostrar o escopo (um menu com sete perguntas) também tem custo: tira a jogadora do mundo para ler uma lista. O equilíbrio é estético, e só o playtest decide.

---

## 75.7 A arquitetura híbrida

O diagrama da spec, preenchido com a Vigília:

```text
 VIGÍLIA
  │
  ├── GAME AI TRADICIONAL ── DECIDE, a cada tick, com garantias ─────────────────────────────┐
  │     Percepção · BT_Presenca / BT_Vigia · Utility (UVGUtilityProfile) · EQS · tokens        │
  │     Diretor: decide QUANDO (fases, ritmo, "pode conversar?")                               │
  │                                                                                            │
  ├── SISTEMAS DE NPC ────── GUARDAM O ESTADO E ENTREGAM ─────────────────────────────────────┤
  │     estado narrativo (fatos) · canal de rádio (fila, prioridade, legenda) · quests        │
  │     barks por regras (conteúdo offline) · falas autoradas = significado E reserva          │
  │                                                                                            │
  ├── PLANEJADOR ─────────── ORDENA ──────────────────────────────────────────────────────────┤
  │     na Vigília: quests (etapas, transições) + Diretor; GOAP/HTN estudados no Cap. 41       │
  │                                                                                            │
  └── IA GENERATIVA ──────── INTERPRETA E VERBALIZA, dentro de limites ────────────────────────┘
        runtime (protótipo, fora do Shipping): ouvido de Sônia (intenção); boca (paráfrase)
        offline (produção): revisão de código e roteiro, variações, barks, curvas, testes

 REGRA DAS FRONTEIRAS: cada camada só lê das de cima e só entrega para a de baixo pelos
 canais que já existem. A camada gerativa nunca decide, nunca escreve estado, e sempre tem reserva.
```

E o fluxo de uma fala gerada, atravessando as camadas (Capítulo 74):

```text
 DECIDE (Diretor, zona segura, leitura) → RESTRINGE (fatos → falas permitidas) → INTERPRETA/VERBALIZA (modelo)
   → VALIDA (regras puras) → ENTREGA (canal do Cap. 44) ─ ou ─ RESERVA (fala autorada, dublada)
```

Os padrões de contenção, reunidos:

| Falha | Padrão | Onde mora na Vigília |
|---|---|---|
| Inconsistência | Estado fora do modelo; pergunta independente; cache | `UVGNarrativeSubsystem`; sem histórico; cache do `UVGLLMSubsystem` |
| Revelação fora de hora | *Grounding* por falas permitidas | `UVGRadioTalkSubsystem::CollectAllowed` |
| Latência | Prazo + reserva; acomodação diegética; offline | Prazo de 3 s; o rádio; *barks* offline |
| Custo e fim do serviço | Orçamento, cache, *kill switch*, jogo completo sem modelo | `MaxRequestsPerMinute`; gateway; ouvido de reserva |
| Segurança | Sem agência; saída fechada; validação; moderação | Efeitos = fala autorada; intenções; `CheckLine`; gateway |
| Controle de design | Game AI decide quando; conteúdo autorado decide o quê | `CanTalkNow`; `DA_Dlg_Free_*` |
| Ludonarrativa | Escassez; desculpa diegética; escopo na ficção | Só no claro e na calmaria; "a linha tá ruim" |
| Testabilidade | Regras puras; modo falso; avaliação versionada | 3 testes `Vigilia.GenAI.*`/`Vigilia.AI.*`; `vg.GenAI.Fake`; `docs/ia/eval/` |

---

## 75.8 Quando usar

Uma lista de perguntas, em ordem. A primeira resposta "não" encerra a discussão, ou manda redesenhar.

1. **A entrada é aberta?** Se for enumerável, escreva ou gere **antes** (Capítulos 71–72) e escolha por regras.
2. **A latência cabe na ficção?** Se a resposta precisa ser instantânea, não é para modelo em runtime.
3. **Existe reserva autorada** que deixa o jogo completo sem o modelo, inclusive quando o serviço acabar?
4. **O pior texto possível é aceitável**, garantido por **estrutura**, para a classificação, o tom e o livro-razão?
5. **O modelo dispensa poder sobre o estado?** Se ele precisa conceder, abrir ou mudar algo, redesenhe até não precisar.
6. **O custo cabe se o jogo der certo?**
7. **Dá para medir e depurar?** Conjunto de avaliação, versão do prompt, falas permitidas registradas.
8. **No playtest, as pessoas preferem com o modelo** do que com a melhor alternativa autoral?

A conversa livre com Sônia passa nas sete primeiras por construção. A oitava é a que decide, e é exatamente a que um livro não pode responder por você.

---

## Estudos de caso

### Alien: Isolation — duas camadas de controle

**[FATO PÚBLICO — relatado pelos desenvolvedores em entrevistas e amplamente analisado; confira as fontes]** Em *Alien: Isolation* (Creative Assembly, 2014), o comportamento da criatura combina duas camadas: um sistema de direção que sabe onde a jogadora está e, de tempos em tempos, aproxima a criatura da região dela para manter a pressão, e o comportamento da própria criatura, que precisa **efetivamente** encontrá-la pelos sentidos (ver, ouvir) para atacar.

**[INFERÊNCIA]** A camada de cima controla o **ritmo** (com que frequência a ameaça chega perto); a de baixo, a **justiça** (a criatura só encontra quem ela consegue perceber). Uma camada não invade a responsabilidade da outra: o diretor nunca entrega a posição exata para o ataque, e a criatura não decide sozinha o ritmo do jogo.

**Lição para a Vigília:** é a mesma divisão entre o Diretor e a Presença do Capítulo 42, e é a mesma disciplina que a camada gerativa precisa respeitar. A arquitetura híbrida não é uma ideia nova trazida pelos modelos de linguagem. É a extensão de uma regra que a boa Game AI já seguia: **cada camada tem uma responsabilidade, e nenhuma decide o que é de outra.**

### Middle-earth: Shadow of Mordor — memória sem geração

**[FATO PÚBLICO — observável jogando]** Em *Middle-earth: Shadow of Mordor* (Monolith, 2014), o *Nemesis System* faz os capitães orcs **lembrarem** dos encontros com o jogador: um orc que matou o protagonista é promovido e se gaba disso no próximo encontro; um que fugiu queimado volta com cicatrizes e menciona o fogo. Jogadores relatam a sensação de rivais com personalidade e história.

**[INFERÊNCIA]** O efeito vem de **estado sistêmico** (registros de encontros, traços, hierarquia) combinado com **conjuntos de falas autoradas** escolhidas por esse estado. Nenhuma fala é gerada em runtime; o que parece "ele se lembra de mim" é uma consulta a um registro, seguida de uma fala condicionada.

**Lição para a Vigília:** grande parte do que se espera de "NPCs com IA" (que lembrem, que reajam ao que aconteceu, que pareçam ter personalidade) é um problema de **estado** e de **conteúdo condicionado**, e a Vigília já tem as duas peças: os fatos do Capítulo 46 e as condições do Capítulo 44. O modelo de linguagem acrescenta uma coisa só: **interpretar entrada aberta**. Antes de colocar um modelo num NPC, pergunte se o que falta é linguagem ou memória. Se for memória, o modelo é a ferramenta errada.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Modelo como componente não confiável | *Zero trust*; validar tudo que vem de fora | O componente não confiável também **molda a experiência**: validar não basta, ele precisa soar certo |
| Decidir × verbalizar | Modelo e *view*; a apresentação derivada do Capítulo 4 | A "*view*" gerativa pode errar o conteúdo, não só a forma |
| Reserva autorada | Degradação graciosa | O modo degradado tem de continuar na ficção, e às vezes é **melhor** que o completo |
| ADR + *flag* de build | *Feature flag* e registro de decisão | Num jogo publicado, ligar a *flag* é uma decisão com consequências de loja, classificação e privacidade |
| Fim do serviço | Descontinuação de dependência | O produto (o jogo) precisa sobreviver a ela por anos, sem *deploy* |

---

## Unreal Engine: onde cada camada mora

| Camada | Classes e assets da Vigília |
|---|---|
| Decide | `UVGDirectorSubsystem`, `BT_Presenca`, `BT_Vigia`, `UBTService_VGUtilitySelect` + `UVGUtilityProfile`, EQS, `UVGTokenSubsystem`, `UVGThreatSubsystem` |
| Guarda o estado | `UVGNarrativeSubsystem` (fatos, contadores, memória do diálogo, quests) |
| Ordena | `UVGQuestSubsystem`, `UVGQuestData`; o Diretor |
| Restringe (conteúdo) | `UVGDialogueData` + `VGDialogueRules`, `UVGRadioTalkData`, `DA_Dlg_Free_*`, `ST_Radio_Livre` |
| Interpreta/verbaliza | `UVGLLMSubsystem` + gateway do projeto |
| Valida | `VGLLMRules`, `VGRadioTalkRules` |
| Entrega | `UVGDialogueSubsystem`, `WBP_Legenda` |
| Reserva | `ClassifyByKeywords`, falas autoradas dubladas |
| Offline (produção) | `docs/ia/`, `tools/balance_sweep.cpp`, `VGExportScript`, `docs/design/ai/`, testes |

Nenhuma classe nova é necessária para a arquitetura: ela é a soma das partes do livro, com uma camada a mais, isolada numa pasta e atrás de duas travas.

---

## Abordagens

O que fazer com o protótipo no projeto final:

| Critério | **A. Release sem IA em runtime; protótipo só em desenvolvimento** | B. Release com "só ouvido", opcional | C. Release com "ouvido e boca" |
|---|---|---|---|
| **Complexidade** | Nenhuma além do que existe | Consentimento, gateway em produção, moderação, *kill switch*, termos | Tudo de B + revisão contínua de tom |
| **Performance** | — | Latência acomodada pelo rádio | Idem |
| **Extensibilidade** | A conversa livre pode virar menu autorado | Novas intenções = novos assets | Idem |
| **Manutenção** | Zero custo recorrente | Custo recorrente, avaliação a cada mudança, prazo de vida do serviço | Idem, mais exposição |
| **Prototipação** | Já feita | Já feita | Já feita |
| **Adequação à Vigília** | **Sim**: jogo individual, 15 minutos, terror que vive de silêncio | Possível, se o playtest pedir e os requisitos forem cumpridos | Não: a voz da atriz e o tom valem mais que a paráfrase |

**Decisão:** **A**. O build de release do Capítulo 84 sai sem IA generativa em runtime, e a decisão fica registrada num ADR. O protótipo continua no projeto, em builds de desenvolvimento, desligado por padrão, como experimento e como material de estudo. As ferramentas offline dos Capítulos 69–72 continuam no fluxo de produção da Parte XI. **B** tem um critério de reabertura escrito; **C** está fora pelos motivos de 75.6.

Repare que a decisão não diz "a IA generativa não funciona". Diz que, **para este jogo**, o ganho medido não paga o custo de produção, a exposição e a quebra de voz. Num jogo diferente (um mistério de interrogatório, por exemplo, em que entender a pergunta da jogadora **é** a mecânica central), as mesmas medições podem apontar para B.

---

## Implementação: a decisão como artefato

### 1. O ADR

```text
# docs/adr/0010-ia-generativa-runtime.md

STATUS     Aceito em ____ (data). Reavaliar quando o critério de reabertura for atingido.

CONTEXTO   Protótipo dos Caps. 73–74: Sônia responde a perguntas livres em 7 intenções fechadas;
           grounding por falas permitidas; reserva autorada; fora do Shipping; desligado por padrão.
           Avaliação: docs/ia/eval/resultados.md (versão do prompt: __).
           Playtest: __ pessoas; preferência entre paráfrase e fala dublada: __.

DECISÃO    O build de release (Cap. 84) NÃO inclui IA generativa em runtime:
           VG_WITH_GENAI = 0 em Shipping; bAllowGenAIInShipping = false no Build.cs.
           Ferramentas offline (Caps. 69–72) seguem no fluxo de produção.
           O protótipo permanece em builds de desenvolvimento, com vg.GenAI.Enabled = 0.

MOTIVOS    (com os SEUS números)
           - acerto do ouvido nas paráfrases: __% contra __% das palavras-chave;
           - latência p90: __ s; reservas por prazo: __%;
           - preferência no playtest: __;
           - requisitos não cumpridos para release: consentimento __, moderação __,
             kill switch __, regras de loja __, classificação __, custo por sessão __.

CONSEQUÊNCIAS
           Sônia responde só por roteiro na versão final. A conversa livre pode virar
           menu autorado (Abordagem A do Cap. 74): decisão do Cap. 76.
           O jogo é completo sem rede e sem serviço externo.

REABERTURA Se o ouvido superar as palavras-chave em pelo menos __ pontos nas paráfrases,
           E o playtest mostrar preferência clara pela pergunta livre,
           E o gateway de produção tiver consentimento, moderação, limite e kill switch.
```

### 2. A exceção explícita no `Build.cs`

🔁 **O que havia** (Capítulo 73): `VG_WITH_GENAI` derivado só da configuração. **O problema**: a única forma de ligar a IA num Shipping seria mudar a expressão, sem nenhum rastro de que aquilo é uma decisão de produto. **A solução**: uma constante com nome, comentário e referência ao ADR.

```csharp
// Vigilia.Build.cs (🔁 Cap. 75)
// Exceção de release: mudar para true exige revisar o ADR-0010 e o checklist do Cap. 84.
const bool bAllowGenAIInShipping = false;
bool bWithGenAI = Target.Configuration != UnrealTargetConfiguration.Shipping || bAllowGenAIInShipping;
PublicDefinitions.Add("VG_WITH_GENAI=" + (bWithGenAI ? "1" : "0"));
```

### Explicação das decisões

- **O ADR tem lacunas para os seus números.** Uma decisão sobre IA generativa tomada com números de outra pessoa (ou de um livro) envelhece em meses. Os campos obrigam a decisão a se apoiar no **seu** protótipo e no **seu** playtest.
- **O critério de reabertura vem escrito** na mesma página da decisão. Sem ele, a pergunta "e se a gente ligasse?" volta a cada sprint, sem dados novos.
- **A exceção no `Build.cs` tem nome.** Quem procurar "por que a IA não está no Shipping?" encontra a constante, o comentário e o ADR, em vez de uma expressão booleana anônima.

---

## Projeto Vigília — o relatório do protótipo e a passagem para a Parte XI

O que muda:

```text
docs/adr/0010-ia-generativa-runtime.md     a decisão, com os seus números
docs/ia/relatorio-prototipo.md             métricas, playtest, o que surpreendeu, o que você faria diferente
Vigilia.Build.cs                           bAllowGenAIInShipping = false
```

**O que a Parte XI herda da Parte X:**

| Herança | Onde é usada |
|---|---|
| Kit de verificação (`CONTEXTO.md`, protocolo, `run-tests.ps1`) | Todo o desenvolvimento dos Caps. 76–85 |
| Registro de ideias e varredura de balanceamento | Cap. 76 (conceito), 82 (polish) |
| Bíblia, `VGExportScript`, revisão do roteiro | Cap. 81 (a história completa no sistema narrativo) |
| BTs em texto, `UVGUtilityProfile`, teste de cenários | Cap. 80 (a IA do jogo final) |
| Protótipo de rádio híbrido | Fora do release (ADR-0010); disponível em desenvolvimento |
| Falas livres autoradas de Sônia | Cap. 76 decide se viram menu autorado, ou ficam só no protótipo |
| Decisão "nenhum serviço externo no release" | Cap. 84 (build) e 85 (postmortem) |

**Para o postmortem (Capítulo 85)**, guarde desde já três registros do `DEVLOG.md`: quanto tempo a Parte X economizou (ou custou) nas tarefas de produção; que erros de IA o protocolo pegou; e o que o protótipo ensinou sobre o próprio jogo. O último costuma ser o mais valioso: perguntas livres de playtest mostram o que a jogadora **quer saber**, e isso é material de narrative design, use você um modelo ou não.

---

## Decisões arquiteturais

1. **Arquitetura híbrida em quatro camadas** (Game AI decide, sistemas de NPC guardam e entregam, planejador ordena, IA generativa interpreta e verbaliza), com a **regra das fronteiras**: a camada gerativa não decide, não escreve estado e sempre tem reserva.
2. **Cada falha conhecida tem um padrão de contenção localizável no código** (tabela 75.7).
3. **Preservação:** o jogo é completo sem o serviço.
4. **"Quando usar" é uma lista de oito perguntas**, e a oitava (playtest) não se responde por análise.
5. **Release sem IA em runtime** (ADR-0010), com exceção explícita no `Build.cs` e critério de reabertura escrito.

---

## Armadilhas

- **Dar mais memória ao modelo para resolver inconsistência.** Mais contexto livre é mais custo, mais deriva e mais superfície de injeção; o estado mora fora.
- **Usar um modelo onde falta memória, não linguagem.** "O NPC lembra de mim" é um problema de estado (estudo de caso de *Shadow of Mordor*).
- **Tratar a acomodação diegética como universal.** O rádio absorve latência; um rosto na frente da jogadora, não.
- **Deixar a camada gerativa decidir quando entra em cena.** O ritmo é da Game AI.
- **Um jogo que depende do serviço.** Ele vai acabar antes do jogo.
- **Decidir pelo entusiasmo, sem números**, ou com números de outra pessoa. O ADR exige os seus.
- **Ignorar a promessa da caixa de texto.** Entrada livre promete entendimento; se o sistema entende pouco, a mecânica contradiz a ficção.
- **Confundir "não serve para este jogo" com "não funciona".** A mesma arquitetura pode ser certa num jogo em que interpretar a jogadora é a mecânica central.

---

## Exercício

**Parte 1 — o mapa de falhas (1 h).** Para cada linha da tabela 75.7, abra o código ou o asset indicado e confirme que o padrão está lá e funciona: provoque a falha (desligue o gateway, faça uma pergunta no escuro, injete uma instrução, peça algo do setor 3) e registre o comportamento observado.

**Parte 2 — o relatório (1,5 h).** Escreva o `docs/ia/relatorio-prototipo.md` com as métricas da avaliação do Capítulo 74, as respostas do playtest e três achados sobre o **jogo** (não sobre a IA) que as perguntas livres revelaram.

**Parte 3 — a decisão (45 min).** Preencha o ADR-0010 com os seus números. Se os seus dados apontarem para B, e não para A, escreva o ADR com a sua decisão e liste, no lugar das consequências, tudo o que o Capítulo 84 precisa cumprir antes do release.

**Parte 4 — o diagrama (30 min).** Desenhe a arquitetura híbrida da **sua** Vigília (a tabela "onde cada camada mora" com as suas classes reais) e anexe ao `docs/design/arquitetura.md`, que o Capítulo 77 vai revisar.

---

## Desafio — o jogo depois do serviço

Simule o fim do serviço e prove que a Vigília sobrevive:

1. Faça o gateway responder `500` para tudo e jogue o setor 1 inteiro com `vg.GenAI.Enabled 1`. Nenhuma pergunta pode ficar sem resposta, nenhum frame pode travar, nenhuma quest pode depender de uma resposta gerada.
2. Repita sem rede nenhuma, e depois num build **Shipping** (onde o subsistema nem existe).
3. Procure, no código e nos assets, qualquer caminho em que um fato, uma quest ou uma porta dependa de algo que só o modelo produziria. Se encontrar, ele viola a regra das fronteiras: corrija.
4. Escreva um checklist de **preservação** para o Capítulo 84: o que precisa ser verdade para o jogo funcionar daqui a dez anos, sem nenhum serviço externo.

---

## Uso de IA

O fim da Parte X é um bom momento para um balanço do uso de IA no livro inteiro. Prompts meta:

1. **Para o balanço da formação:**
   > "Aqui estão as entradas do meu DEVLOG que mencionam IA, desde a Parte I. Separe-as por parte do livro e por tipo de uso (estudo, revisão, geração de código, depuração, design, narrativa). Em que partes eu dependi mais de IA? Cruze com as partes em que meus checklists ficaram com mais itens em aberto. Não tire conclusões que os dados não sustentam."

2. **Para o teste sem IA:**
   > "Escolha três sistemas da Vigília (por exemplo, o canal de rádio, o Diretor e o subsistema de quests). Para cada um, me faça cinco perguntas que só quem o implementou responde sem consultar nada. Eu respondo; depois você aponta, com base no código que vou colar, onde eu errei."

3. **Para revisar a arquitetura híbrida com olho de fora:**
   > "Este é o diagrama de camadas de um jogo com IA generativa em runtime, a regra das fronteiras e a tabela de contenções. Procure: uma falha conhecida de modelos de linguagem em jogos que não esteja na tabela; um caminho pelo qual a camada gerativa influencia uma decisão; e um ponto em que a reserva não cobre a falha. [diagrama] [tabela]"

4. **Para a pergunta que sobra:**
   > "Com base no meu relatório do protótipo, argumente a favor da decisão oposta à que eu tomei no ADR, da forma mais forte possível, usando só os meus dados. Depois diga que dado novo mudaria a sua argumentação."

**Cuidado específico:** pedidas para avaliar o futuro da IA generativa em jogos, IAs tendem ao entusiasmo ou ao alarme, com afirmações sobre "o que a indústria está fazendo" que raramente têm fonte. Para decidir o **seu** jogo, só valem os seus dados: o protótipo, a avaliação, o playtest. Peça argumentos ancorados neles, e trate o resto como opinião.

---

## Checklist

- [ ] Sei listar onde modelos de linguagem falham em jogos e dar um exemplo concreto de cada falha na Vigília.
- [ ] Sei associar cada falha a um padrão de contenção e encontrá-lo no código.
- [ ] Sei desenhar a arquitetura híbrida em quatro camadas e explicar a regra das fronteiras.
- [ ] Sei por que "memória" de NPC é, quase sempre, um problema de estado, e não de linguagem.
- [ ] Sei aplicar as oito perguntas de "quando usar" a uma funcionalidade nova.
- [ ] Escrevi o relatório do protótipo e o ADR-0010 com os meus números.
- [ ] O `Build.cs` tem a exceção de release explícita, e o jogo funciona sem o serviço.

---

## Para ir além

- **Tanya X. Short e Tarn Adams (org.), *Procedural Generation in Game Design*.** Coletânea sobre geração procedural com autoria: a mesma tensão entre variedade e controle que este capítulo discute, vista por quem faz jogos sistêmicos há anos.
- **Kate Compton, *So you want to build a generator…*** (texto publicado no blog da autora; confira o endereço atual). Um guia curto e prático sobre desenhar geradores com restrições, que vale para pensar qualquer camada gerativa.
- **GDC Vault** (gdcvault.com): *Building Fear in Alien: Isolation*, de Alistair Hope (GDC 2015), sobre o design do medo no jogo, e *Helping Players Hate (or Love) Their Nemesis*, de Chris Hoge (GDC 2018), sobre o *Nemesis System* de *Shadow of Mordor* e *Shadow of War*; e as palestras recentes sobre personagens com IA generativa, lidas com os rótulos do livro.
- **OWASP Top 10 for Large Language Model Applications** (owasp.org), para manter a tabela de contenções atualizada à medida que os riscos conhecidos mudam.
- **Michael T. Nygard, *Release It!*.** A disciplina de projetar para a falha de dependências, que é, no fundo, o assunto da Parte X inteira.

---

## Estado do Livro (fim da Parte X)

- **Capítulos concluídos nesta parte:** 69 (IA como ferramenta de programação), 70 (IA para Game Design), 71 (IA para Narrative Design), 72 (IA para Game AI), 73 (LLMs dentro de jogos), 74 (NPCs com IA generativa), 75 (Limitações e arquitetura híbrida). O estado das partes escritas em paralelo está no `README.md` e nos `ESTADO.md` de cada pasta.
- **Projeto:** a Vigília ganhou ferramentas de produção com IA (kit de verificação, laboratório de design, bíblia e exportador do roteiro, BTs em texto, perfil de utilidade com teste de cenários) e um **protótipo isolado de rádio híbrido** (Sônia com perguntas livres em intenções fechadas), fora do Shipping, desligado por padrão e com a decisão de release registrada no ADR-0010.
- **Conceitos consolidados na Parte X:**
  - IA para acelerar o entendimento, com verificação em escada e revisão por armadilhas conhecidas;
  - divergir com IA, convergir com pilares; números só de programas reproduzíveis;
  - texto final humano; bíblia com `[NUNCA]` fora da geração; consistência contra três fontes;
  - IA generativa constrói, Game AI decide;
  - modelo em runtime: assíncrono, com prazo, reserva, cache, orçamento, gateway, privacidade e avaliação;
  - NPC híbrido: decidir, restringir, interpretar, verbalizar, validar, entregar, reservar; *grounding* estrutural;
  - arquitetura em camadas com regra das fronteiras; preservação; "quando usar" em oito perguntas.
- **Ponto de continuação:** Parte XI — Capítulo 76, Conceito: o documento de design da Vigília completa, que decide, entre outras coisas, o destino das falas livres de Sônia.

---

➡️ **Próximo:** [Capítulo 76 — Conceito](../parte-11/cap-76-conceito.md)

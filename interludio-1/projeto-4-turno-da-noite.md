# INTERLÚDIO I — Projeto 4: "Turno da Noite"

*Uma experiência narrativa de 5 a 15 minutos, construída deliberadamente do jeito mais rápido e ingênuo possível.*

---

## Objetivo

Ao final deste interlúdio você terá:

- uma **experiência narrativa completa e jogável** na Casa de Força da Usina de Serra Funda: chegada, exploração, documentos, rádio, portas trancadas, um puzzle, um evento de terror roteirizado, uma cinemática e um final;
- usado **todos os sistemas** construídos até aqui (movimento, câmera, interação, portas, disjuntores, pickups, gatilhos, alarme, flicker, zonas seguras, objetivos, barramento, sinalizador) como **peças de conteúdo**;
- construído a **cola narrativa** — o que conecta esses sistemas numa história — do jeito **errado-mas-rápido**: Level Blueprint, variáveis booleanas soltas, referências diretas entre atores, cadeias de `Delay`;
- um **inventário de dores** detalhado, que é a especificação da Parte VI.

---

## Por que fazer errado de propósito

A Introdução (seção 6.2) anunciou este projeto assim: *"ele vai funcionar. E vai começar a doer quando você tentar adicionar um segundo caminho narrativo, salvar o jogo ou reaproveitar a lógica em outro nível."*

Há três razões para construir assim, e nenhuma delas é preguiça:

1. **É assim que protótipos narrativos são feitos de verdade.** Num estúdio, a primeira versão de uma sequência narrativa costuma ser montada rápido, com scripts de nível, para descobrir se a história funciona **jogada** — ritmo, revelações, sustos. Ninguém escreve um sistema de diálogos antes de saber se a cena funciona. Você está fazendo o que o Capítulo 1 (seção 1.8) chamou de **protótipo**: código descartável que responde a uma pergunta de design.
2. **Arquitetura que resolve dores não sentidas é arquitetura imposta.** O sistema narrativo da Parte VI — quests, diálogos, estado narrativo, ramificação — faz sentido **como resposta** a problemas concretos. Se você nunca os sentiu, ele parece burocracia.
3. **O protótipo é valioso mesmo depois de reescrito.** A Parte VI não joga fora o *Turno da Noite*: ela o **migra**. O conteúdo (textos, falas, espaço, ritmo) sobrevive; a cola é substituída. Como no Capítulo 13 com o alarme, o que se aprende com a versão anterior é parte do resultado.

A regra deste interlúdio, portanto: **os sistemas existentes são usados como estão; a cola narrativa é feita no Level Blueprint, com o mínimo de estrutura.** Sem criar classes C++ novas para narrativa, sem Data Assets de diálogo, sem subsistema narrativo. Quando sentir vontade de criar um, **anote no inventário de dores** e siga em frente.

---

## 1. O conceito

### A premissa

> *Helena Duarte, perita do Departamento Estadual de Energia, chega à Usina de Serra Funda perto da meia-noite. A usina está desativada há trinta anos — desde a noite de 14 de agosto de 1994, quando os seis homens do turno da noite desapareceram sem deixar rastro. Esta noite, os sensores remotos registraram as turbinas girando. Pelo rádio, Sônia, da Central de Despacho, é a única voz que acompanha Helena.*

O *Turno da Noite* é o **primeiro capítulo** dessa história: a entrada na **Casa de Força**, o prédio onde ficam a sala de controle e o salão das turbinas.

### Experiência-alvo (Capítulo 5)

1. **Curiosidade** — "o que aconteceu com o turno da noite?"
2. **Inquietação crescente** — a usina não está tão abandonada quanto deveria.
3. **Um único susto bem colocado** — a primeira aparição da Presença, sem combate.
4. **Um final que abre a próxima pergunta** — as turbinas não estão girando sozinhas.

### Escopo

- **Duração:** 8 a 12 minutos para quem explora; ~5 minutos para quem vai direto.
- **Espaço:** a Casa de Força (cinco ambientes) — um nível novo, `L_CasaDeForca`, acessado pela porta da Casa de Força do Pátio.
- **Combate:** nenhum. O sinalizador pode ser encontrado, mas não há ameaça que exija usá-lo. (A Presença aparece, mas é **cenografia** — não há IA ainda. Isso é proposital: é o "smoke and mirrors" do Capítulo 1.)
- **Mecânicas usadas:** andar, agachar, lanterna (a bateria do Capítulo 4 com o flicker do Capítulo 9, numa lanterna simples em Blueprint), interação (portas, disjuntores, pickups), documentos, rádio, um puzzle, objetivos.

---

## 2. O espaço

```text
                              CASA DE FORÇA — térreo (nível 0) e subsolo (nível −1)

   ┌────────────────────────────────────────────────────────────────────────────┐
   │                                                                            │
   │   ┌───────────────┐   ┌──────────────────┐    ┌────────────────────────┐   │
   │   │ VESTIÁRIO     │   │ SALA DO          │    │ SALA DE CONTROLE       │   │
   │   │ armários,     │   │ ENGENHEIRO-CHEFE │    │ (trancada: sem energia)│   │
   │   │ bancos,       │   │ mesa, arquivo,   │    │ painéis, janela para o │   │
   │   │ LIVRO DE      │   │ MEMORANDO        │    │ salão das turbinas     │   │
   │   │ OCORRÊNCIAS   │   │ (porta trancada: │    │                        │   │
   │   │               │   │  chave no        │    │                        │   │
   │   └──────┬────────┘   │  vestiário)      │    └───────────┬────────────┘   │
   │          │            └────────┬─────────┘                │                │
   │   ═══════╧═════════════════════╧══════════════════════════╧═══════════     │
   │                         CORREDOR PRINCIPAL                                 │
   │   ═══════╤══════════════════════════════════════════════════════════════   │
   │          │                                                                 │
   │   ┌──────┴──────┐                                ┌──────────────────────┐  │
   │   │ HALL DE     │◄── entrada (do Pátio)          │ ESCADA METÁLICA      │  │
   │   │ ENTRADA     │                                │ para o subsolo  ↓    │  │
   │   └─────────────┘                                └──────────────────────┘  │
   └────────────────────────────────────────────────────────────────────────────┘

   SUBSOLO (−1): DEPÓSITO DE FUSÍVEIS — corredor estreito, passarelas metálicas sobre
   o poço das turbinas; três quadros de disjuntores (o puzzle); escuro total.
```

Diretrizes de grey-box (Capítulo 7, métricas; o Capítulo 50 aprofunda):

- **O corredor principal é longo e tem uma curva**: o fim dele não é visível do hall. É onde a Presença vai aparecer.
- **A sala de controle tem uma janela grande** para o salão das turbinas (que fica dois andares abaixo, visível mas inacessível): é o palco da cinemática final.
- **O subsolo é estreito e metálico**: passos ecoam (as passarelas usam `PM_Metal` — Capítulo 17).
- **O hall de entrada é a única zona segura** no início (as luzes de emergência funcionam): um `AVGSafeZone` com luz estável.

---

## 3. A estrutura narrativa

### Os beats

Um **beat** é uma unidade de ritmo narrativo: algo acontece e muda o que a jogadora sabe ou sente. O *Turno da Noite* tem nove:

| # | Beat | Onde | O que a jogadora aprende/sente | Gatilho |
|---|---|---|---|---|
| 1 | **Chegada** | Hall | Sônia no rádio: o contexto. A usina está escura; só as luzes de emergência. | Entrar no nível |
| 2 | **O livro de ocorrências** | Vestiário | A última entrada do turno de 1994. Algo "no salão das turbinas". | Pegar o livro |
| 3 | **A chave** | Vestiário (armário) | Chave da sala do engenheiro. | Pegar a chave |
| 4 | **O memorando** | Sala do engenheiro | O engenheiro-chefe pedia para **não** religar a turbina 3. Contradiz o livro. | Pegar o memorando |
| 5 | **A sala de controle está sem energia** | Corredor | Objetivo: descer ao depósito e religar os disjuntores. | Tentar a porta |
| 6 | **O primeiro susto** | Corredor (curva) | As luzes falham em cascata; uma silhueta no fim do corredor; silêncio. | Gatilho na curva, **ao voltar do depósito** |
| 7 | **O puzzle dos disjuntores** | Subsolo | A ordem certa está escrita no livro de ocorrências. | Três disjuntores |
| 8 | **A sala de controle** | Sala de controle | Os painéis acendem. Pela janela: a turbina 3 está girando. | Abrir a porta energizada |
| 9 | **Final (cinemática)** | Sala de controle | Os painéis mostram a turbina sendo **acionada manualmente**, agora. O rádio de Sônia corta. Fim do capítulo. | Interagir com o painel principal |

### A curva de tensão

```text
 tensão
   ▲                                              6 (susto)
   │                                              ╭╮
   │                                             ╭╯╰╮         9 (final)
   │                         4                  ╭╯  ╰╮          ╭─╮
   │              2         ╭╮         7 ╭─────╯    ╰─╮  8   ╭╯  │
   │    1        ╭╮        ╭╯╰╮   5     ╭╯            ╰──╮ ╭─╯   │
   │   ╭─╮      ╭╯╰╮  3   ╭╯  ╰─────────╯                ╰─╯     ╰──
   │───╯ ╰──────╯  ╰──────╯
   └──────────────────────────────────────────────────────────────────► tempo
```

O susto (beat 6) acontece **depois** do puzzle, no caminho de volta — quando a jogadora já passou pelo corredor duas vezes e começou a se sentir segura nele. É a "tensão criada pela expectativa" (Capítulo 5, seção 5.7): o corredor só é assustador porque ela já o conhece.

### A ramificação (pequena)

Há **uma** escolha implícita: a jogadora pode ou não ler o memorando (beat 4) antes de descer ao subsolo (a sala do engenheiro é opcional — a chave está num armário que é fácil de ignorar).

- **Se leu o memorando**, quando ela religa os disjuntores (beat 7), Sônia comenta: *"Espera. O memorando dizia para não religar a três. Você religou a três?"*
- **Se não leu**, Sônia diz apenas: *"Os painéis estão respondendo. Bom trabalho."*

E na cinemática final (beat 9), a última fala de Sônia muda conforme a jogadora leu ou não o memorando. É pouco — e é exatamente o suficiente para o protótipo sentir o custo de ramificação (Capítulo 47).

---

## 4. O conteúdo escrito

Textos originais do *Turno da Noite*. Eles vão sobreviver à refatoração da Parte VI — só mudam de lugar.

### Documento 1 — Livro de ocorrências (última página)

> **USINA DE SERRA FUNDA — LIVRO DE OCORRÊNCIAS — TURNO C (NOITE)**
>
> **14/08/1994 — 23h10** — Ronda completa. Nível do reservatório estável. Turbinas 1 e 2 em operação normal. Turbina 3 parada para manutenção, conforme ordem do Eng. Moraes.
>
> **23h52** — Oscilação na rede do setor B. Luzes do corredor principal piscando. Teixeira foi verificar o depósito.
>
> **00h20** — Teixeira não voltou. Rádio só com chiado. Almeida e Prado desceram.
>
> **00h41** — Ouvimos a turbina 3. Ela não pode estar girando. Os disjuntores do subsolo estão na posição de manutenção. Para religar a sala de controle, a sequência é **ALIMENTAÇÃO, EXCITAÇÃO, SINCRONISMO** — nessa ordem, nunca outra.
>
> **00h58** — As luzes do corredor apagaram de uma ponta à outra, como se alguém viesse andando com elas. Vou descer. Se alguém ler isto: não religue a

*(A frase termina aí. A caneta riscou a página até o fim.)*

### Documento 2 — Memorando do engenheiro-chefe

> **MEMORANDO INTERNO Nº 117/94**
> **De:** Eng. Valter Moraes, Engenharia de Operação
> **Para:** Supervisores de turno A, B e C
> **Assunto:** Turbina 3 — suspensão por tempo indeterminado
>
> Conforme relatado verbalmente, a turbina 3 deve permanecer **desligada e desacoplada** até segunda ordem. Os registros de vibração das últimas três semanas não correspondem a nenhuma falha mecânica conhecida. Ouvi das equipes relatos que prefiro não pôr no papel.
>
> Em hipótese alguma religuem a alimentação da sala de controle sem a minha presença. Se a turbina 3 girar com os disjuntores em posição de manutenção, **saiam da casa de força e acionem a central**.
>
> V. Moraes

### Documento 3 — Bilhete no armário (com a chave)

> Teixeira — deixei a chave da sala do Moraes aqui. Ele pediu pra ninguém mexer nos papéis dele, mas você sabe que ele esquece o rádio na mesa. Volta antes da meia-noite. — P.

### Falas de rádio — Sônia (Central de Despacho)

| Beat | Condição | Fala |
|---|---|---|
| 1 | — | "Helena, aqui é a Sônia, da Central. Tô te vendo no mapa: você entrou na casa de força. Os sensores continuam marcando rotação na turbina três. Isso não faz sentido nenhum — a usina tá desligada da rede desde noventa e quatro." |
| 1 | (8 s depois) | "Sem energia aí, né? Só as luzes de emergência do hall. Procura o livro de ocorrências do último turno. Se alguém anotou alguma coisa naquela noite, foi lá." |
| 2 | — | "Achou? Lê pra mim a última entrada... Não. Deixa. Eu li esse relatório quando entrei aqui. Ninguém nunca explicou a última frase." |
| 5 | — | "A sala de controle não abre sem energia. Os disjuntores ficam no depósito do subsolo. Vai com calma, Helena. Tem trinta anos de poeira nessas passarelas." |
| 7 | leu o memorando | "Espera. O memorando dizia pra não religar a três sem o Moraes. Você religou a três?" |
| 7 | não leu | "Os painéis estão respondendo aqui na central. Bom trabalho." |
| 6 | (após o susto) | "Helena? Você tá aí? O seu sinal sumiu por uns segundos." |
| 9 | leu o memorando | "Helena, sai daí. O memorando era claro. Se ela gira com os disjuntores em manutenção, alguém— *[chiado]*" |
| 9 | não leu | "Helena, os painéis mostram acionamento manual. Agora. Tem alguém aí com você— *[chiado]*" |

---

## 5. A implementação ingênua

### As regras do jogo

- **Toda a cola narrativa no Level Blueprint de `L_CasaDeForca`.**
- **Estado narrativo em variáveis booleanas do Level Blueprint** (`bLeuLivro`, `bPegouChave`, `bLeuMemorando`, `bDisjuntoresOk`, `bSustoAconteceu`...).
- **Referências diretas**: arraste os atores do Outliner para o grafo.
- **Falas de rádio**: um `Play Sound 2D` (placeholder: grave as falas você mesmo, ou use um som de chiado) + um widget simples de legenda (`WBP_Legenda`, com uma função `MostrarTexto(FText, Duração)`) chamado diretamente do Level Blueprint. O texto das falas fica **nos nós** do grafo.
- **Documentos**: um `BP_PickupDocumento` (filho de `AVGPickup`) com uma propriedade `Texto` (FText multilinha) que, ao ser pego, abre um `WBP_Documento` mostrando o texto e empilha o modo `Reading` (Capítulo 16). O Level Blueprint escuta o pickup (`OnDestroyed`, ou um dispatcher do Blueprint) e marca a variável correspondente.
- **Sequências**: cadeias de `Delay`.
- **Objetivos**: use o `UVGObjectiveSubsystem` (Capítulo 31) — ele já existe e funciona bem para isso. O que é ingênuo é **quem decide** a sequência de objetivos: o Level Blueprint.

### Beat 1 — Chegada

```text
[Event BeginPlay]
  → Delay(1.5)
  → Rádio("Helena, aqui é a Sônia, da Central...")      -- função local: Play Sound 2D + WBP_Legenda
  → Delay(8.0)
  → Rádio("Sem energia aí, né?...")
  → ActivateObjective(DA_Obj_LivroDeOcorrencias)
```

### Beats 2–4 — Documentos e chave

```text
[PickupLivro.OnPickedUp]                                -- referência direta ao ator no nível
  → Set {bLeuLivro} = true
  → Delay(2.0)
  → Rádio("Achou? Lê pra mim a última entrada...")
  → ActivateObjective(DA_Obj_SalaDeControle)

[PickupChave.OnPickedUp]
  → Set {bPegouChave} = true                            -- (a porta usa RequiredTag; isto é só para a narrativa)

[PickupMemorando.OnPickedUp]
  → Set {bLeuMemorando} = true
```

### Beat 5 — A porta sem energia

```text
[GatilhoPortaControle.OnTriggered]                      -- AVGEventTrigger na frente da porta
  → Branch({bLeuLivro})
      True  → Rádio("A sala de controle não abre sem energia...")
            → ActivateObjective(DA_Obj_Disjuntores)
      False → (nada)                                    -- e se ela chegar aqui antes do livro? (anote a dor)
```

### Beat 7 — O puzzle dos disjuntores

Três `BP_Disjuntor` no subsolo (`Alimentacao`, `Excitacao`, `Sincronismo`), com `bOneWay = false`. A ordem certa é a do livro.

```text
-- variável inteira {PassoPuzzle} = 0

[DisjAlimentacao.OnToggled(bIsOn)]
  → Branch(bIsOn AND {PassoPuzzle} == 0)
      True  → Set {PassoPuzzle} = 1
      False → FalharPuzzle

[DisjExcitacao.OnToggled(bIsOn)]
  → Branch(bIsOn AND {PassoPuzzle} == 1)
      True  → Set {PassoPuzzle} = 2
      False → FalharPuzzle

[DisjSincronismo.OnToggled(bIsOn)]
  → Branch(bIsOn AND {PassoPuzzle} == 2)
      True  → Set {PassoPuzzle} = 3
            → Set {bDisjuntoresOk} = true
            → PortaControle.Unlock
            → AlarmeCasaDeForca.TriggerAlarm               -- a usina reage (Cap. 13)
            → Branch({bLeuMemorando})
                  True  → Rádio("Espera. O memorando dizia...")
                  False → Rádio("Os painéis estão respondendo...")
            → ArmarSusto                                    -- o gatilho do beat 6 só vale agora
      False → FalharPuzzle

[FalharPuzzle]                                          -- evento custom
  → Delay(0.5)
  → Set Off nos três disjuntores                        -- (SetOn(false) em cada um)
  → Set {PassoPuzzle} = 0
  → Tocar som de "desarme" + flicker forte nas luzes do subsolo
```

### Beat 6 — O primeiro susto (smoke and mirrors)

A Presença **não existe** como IA. O susto é cenografia: um ator `BP_SilhuetaPresenca` (uma malha escura alta, sem colisão, escondida) no fim do corredor, e um gatilho na curva.

```text
[ArmarSusto]                                            -- chamado pelo puzzle
  → Set {bSustoArmado} = true

[GatilhoCurvaCorredor.OnTriggered]                      -- bTriggerOnce = false (ver dor nº 7)
  → Branch({bSustoArmado} AND NOT {bSustoAconteceu})
      True  → Set {bSustoAconteceu} = true
            → PushInputMode(Cinematic)?  -- NÃO: a jogadora continua no controle (tensão)
            → Luz1.Flicker.SetPattern("a")  → Delay(0.3)  -- cascata do fundo para a frente
            → Luz2.Flicker.SetPattern("a")  → Delay(0.3)
            → Luz3.Flicker.SetPattern("a")
            → SilhuetaPresenca.SetActorHiddenInGame(false)
            → Tocar som grave (MS_Presenca_Respira) na posição da silhueta
            → Delay(1.6)
            → SilhuetaPresenca.SetActorHiddenInGame(true)
            → Delay(2.0)
            → Luz3.Flicker.SetPattern("mmnmmommommnonmmonqnmmo") → Luz2... → Luz1...
            → Delay(1.0)
            → Rádio("Helena? Você tá aí? O seu sinal sumiu por uns segundos.")
```

Note o que o grafo faz, e o que ele **não** faz: se a jogadora correr de volta para o subsolo no meio da cascata, a sequência continua. Se ela morrer (não há como, aqui — mas haverá), a sequência continua. Se ela salvar no meio... não há save. Anote tudo.

### Beats 8–9 — Sala de controle e cinemática final

Uma **Level Sequence** simples (`LS_FinalTurnoDaNoite`), criada com o Sequencer: um corte de câmera para trás dos painéis, um travelling lento até a janela, a turbina 3 girando lá embaixo (um ator com `URotatingMovementComponent` — Capítulo 9 — ligado pela sequência), as luzes dos painéis acendendo em sequência, e a câmera voltando para a jogadora. (O Capítulo 49 trata o Sequencer em profundidade; aqui, use a ferramenta no modo mais básico: trilhas de câmera, de transform e de evento.)

```text
[PainelPrincipal.OnInteracted]                          -- um BP interativo simples
  → PushInputMode(Cinematic)
  → Play(LS_FinalTurnoDaNoite)
  → Delay(6.0)                                          -- duração da sequência (escrito à mão!)
  → Branch({bLeuMemorando})
      True  → Rádio("Helena, sai daí. O memorando era claro...")
      False → Rádio("Helena, os painéis mostram acionamento manual...")
  → Delay(4.0)
  → Tela preta (fade) → "FIM DO CAPÍTULO 1"
  → PopInputMode(Cinematic)
```

### A lanterna (versão mínima)

Para o protótipo, uma lanterna simples em Blueprint no `BP_VGJogadora`: um `SpotLight` preso à câmera, uma ação `IA_Lanterna` que liga/desliga, o `UVGBatteryComponent` drenando enquanto ligada, e o `UVGFlickerComponent` recebendo um padrão de falha quando a bateria entra em `Low` (o desafio do Capítulo 9). Baterias espalhadas pela Casa de Força (`BP_PickupBateria`, Capítulo 19). A versão definitiva da lanterna vem no Capítulo 51.

---

## 6. Áudio e atmosfera (mínimos)

O Capítulo 52 trata áudio em profundidade. Para o protótipo, o mínimo que faz o *Turno da Noite* funcionar:

- **Ambiente:** um zumbido elétrico baixo constante; gotejamento no subsolo; vento pelas frestas no hall.
- **A usina "respira":** um som grave e distante de maquinário a cada 30–60 s (um `AVGAlarm` sem sirene, só com esse som — reutilize a classe do Capítulo 13 com um Blueprint filho diferente).
- **Passos** nas passarelas metálicas mais altos que no concreto (os materiais físicos do Capítulo 17 + sons diferentes por superfície).
- **Silêncio antes do susto:** no beat 6, o zumbido elétrico **para** um segundo antes da cascata de luzes. O silêncio súbito é mais assustador que qualquer som — e é uma linha no grafo.

---

## 7. Critérios de conclusão

- [ ] O nível `L_CasaDeForca` é acessível pela porta da Casa de Força do Pátio.
- [ ] Os nove beats acontecem, na ordem pretendida, numa partida normal.
- [ ] Os três documentos podem ser lidos, com o modo de leitura (Capítulo 16).
- [ ] As falas de rádio aparecem como legendas e tocam algum som.
- [ ] O puzzle dos disjuntores funciona, falha corretamente com a ordem errada e libera a sala de controle.
- [ ] O susto acontece uma vez, no caminho de volta, e só depois do puzzle.
- [ ] A cinemática final toca e a fala final muda conforme o memorando foi lido.
- [ ] Uma pessoa que não conhece o projeto consegue jogar do início ao fim sem ajuda.
- [ ] A experiência dura entre 5 e 15 minutos.

### Playtest

Peça para **duas pessoas** jogarem. Não explique nada. Observe e anote (Capítulo 1, seção 1.9: o playtest é o seu teste de integração):

- Onde elas se perderam?
- Leram os documentos? Inteiros?
- O susto funcionou? (Pergunte depois, não durante.)
- Entenderam o puzzle sem você dizer que a ordem estava no livro?
- O que elas acham que aconteceu com o turno da noite?

---

## 8. O inventário de dores

Esta é a parte mais importante do interlúdio. Ao longo da construção e do playtest, você vai esbarrar em problemas. Anote cada um no `DEVLOG.md`, com a situação concreta em que apareceu. Abaixo, as dores que este protótipo **vai** produzir — confira se você sentiu cada uma, e acrescente as suas.

| # | Dor | Situação concreta | Resolvida em |
|---|---|---|---|
| 1 | **Estado narrativo espalhado e invisível** | As variáveis `bLeuLivro`, `bLeuMemorando`, `PassoPuzzle`... estão no Level Blueprint. Nada fora dele as enxerga. Um NPC de outro nível não sabe que você leu o memorando. | Cap. 46 (Narrative State) |
| 2 | **Impossível salvar** | Não há onde ler "o que aconteceu até agora". Salvar no meio do capítulo exigiria serializar o Level Blueprint. | Caps. 46, 56–57 |
| 3 | **Texto de diálogo dentro do grafo** | Para corrigir uma fala, é preciso abrir o Level Blueprint e achar o nó. Um roteirista não consegue revisar o roteiro. Localizar para inglês é inviável. | Cap. 44 (Dialogue Systems) |
| 4 | **Ramificação vira `Branch` espalhado** | Duas falas condicionais já exigem dois `Branch` em lugares diferentes, que precisam "concordar" sobre a mesma variável. Uma segunda escolha multiplicaria os casos. | Caps. 45, 47 |
| 5 | **Ordem de beats não garantida** | A jogadora chega à porta da sala de controle **antes** de ler o livro: o rádio não fala nada e o objetivo do disjuntor nunca é ativado. Ela fica perdida. | Cap. 45 (Quests: pré-condições e etapas) |
| 6 | **Sequências sem cancelamento** | A cascata de luzes e a cinemática continuam se algo der errado no meio; a duração da cinemática está escrita à mão num `Delay` e quebra se a sequência for editada. | Caps. 4 (revisitado), 49 |
| 7 | **Gatilhos que "lembram" errado** | O gatilho da curva precisou de `bTriggerOnce = false` e de uma variável `bSustoArmado` no Level Blueprint, porque o estado "o susto pode acontecer" não é do gatilho. | Cap. 46 |
| 8 | **Nada é reutilizável** | O capítulo 2 da Vigília (o próximo setor) vai ter rádio, documentos e beats — e nada deste grafo pode ser reaproveitado. | Parte VI inteira |
| 9 | **Nada é testável** | Para verificar a fala final do caminho "leu o memorando", é preciso jogar o capítulo inteiro. Não há como pular para um estado. | Caps. 46 (estado consultável), 61 (cheats) |
| 10 | **O rádio não sabe o que já disse** | Se a jogadora pegar o livro duas vezes (não pode, mas e se pudesse?), Sônia repetiria a fala. Não há memória de "falas já ditas". | Cap. 44 |
| 11 | **A Presença é uma malha que aparece e some** | Funciona uma vez. Não sabe onde a jogadora está, não reage a nada, não pode existir em outro lugar. | Parte V |
| 12 | **O Level Blueprint cresce sem controle** | Ao final, o grafo tem dezenas de nós, eventos espalhados, comentários que tentam explicar a ordem. Ninguém além de você o entende — e você, daqui a um mês, também não. | Parte VI |

### O que funcionou (anote também)

Nem tudo é dor. Registre o que o protótipo **provou**:

- A história funciona jogada? Em que beats?
- O ritmo (curva de tensão) se confirmou no playtest?
- Os sistemas das Partes II–IV (portas, disjuntores, pickups, gatilhos, flicker, alarme, objetivos) aguentaram ser usados como conteúdo sem mudanças?

Esta segunda lista é tão importante quanto a primeira: ela diz **o que preservar** na migração da Parte VI.

---

## Uso de IA

1. **Para revisar a estrutura narrativa:**
   > "Atue como narrative designer de jogos de terror. Avalie esta estrutura de 9 beats para um capítulo de 10 minutos (premissa, beats, curva de tensão, documentos e falas de rádio abaixo). Aponte: onde a jogadora pode se perder, se o susto está bem posicionado em relação à expectativa, se os documentos revelam demais ou de menos, e uma alteração que tornaria o final mais forte. [conteúdo]"

2. **Para escrever variações:**
   > "Escreva três variações da fala final da operadora de rádio para cada um dos dois caminhos (leu ou não leu o memorando), mantendo o tom: cansada, profissional, assustada sem admitir. Cada fala com no máximo 25 palavras, terminando cortada por chiado."
   *(Use as variações como matéria-prima — reescreva com a sua voz.)*

3. **Para antecipar a Parte VI:**
   > "Tenho um protótipo narrativo feito no Level Blueprint com variáveis booleanas, referências diretas e Delays (inventário de dores abaixo). Sem me dar código ainda, descreva a arquitetura mínima de sistema narrativo que resolveria cada dor, e em que ordem você atacaria os problemas. [inventário]"

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Level Blueprint** e **Sequencer** (introdução: criar uma Level Sequence, trilhas de câmera e de evento).
- **GDC Vault** (gdcvault.com) — busque postmortems e talks de desenvolvedores de jogos narrativos sobre **prototipação de narrativa** e *greyboxing* de sequências roteirizadas.

---

## Estado do projeto ao final do Interlúdio I

- **Projeto 4 (Turno da Noite): concluído**, como protótipo deliberadamente ingênuo, jogável do início ao fim, com inventário de dores e lista do que funcionou.
- **A Presença existe apenas como cenografia.** A Parte V dá a ela — e aos vigias — um cérebro de verdade.

➡️ **Próximo:** [Parte V — Capítulo 33: Introdução à Game AI](../parte-05/cap-33-introducao-game-ai.md)

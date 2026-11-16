# Capítulo 6 — Game Architecture

## Objetivo

Ao final deste capítulo você deve conseguir:

- comparar com precisão a arquitetura de uma aplicação corporativa em camadas com a arquitetura de um jogo, entendendo **por que elas são organizadas por eixos diferentes**;
- explicar a evolução dos modelos de objetos de jogo — **hierarquia de herança, componentes, ECS** — e os problemas que cada um resolve;
- entender por que **localidade de dados** e cache importam em jogos, e quando isso justifica uma arquitetura orientada a dados;
- usar **subsistemas** da Unreal como alternativa a singletons e *managers*, entendendo seus ciclos de vida;
- distinguir **arquitetura elegante** de **arquitetura adequada para um jogo**, com critérios concretos;
- saber o que da Clean Architecture e do DDD transfere para jogos — e o que vira um ERP para uma porta;
- implementar o primeiro subsistema do projeto Vigília, resolvendo o problema da dilatação do tempo deixado pelos Capítulos 3 e 4.

Este é o capítulo que fecha a Parte I. Ele reúne tudo o que veio antes — loop, tempo, estado, eventos, loops de design — numa visão de arquitetura.

---

## Contexto

Você passou anos aprendendo a organizar software. Sabe por que um *controller* não deve conter regra de negócio, por que o domínio não deve depender da infraestrutura, por que um agregado protege suas invariantes, por que um serviço não deve conhecer o banco de outro serviço. Essas regras não são arbitrárias: elas existem porque sistemas corporativos têm forças específicas — longa vida útil, muitas equipes, requisitos que mudam por decisão de negócio, integração com outros sistemas, necessidade de auditoria e de testes.

Jogos têm **outras forças**. Eles vivem sob um orçamento de frame, são ajustados por não programadores, mudam de design semanalmente durante a produção, e — uma vez lançados — muitas vezes param de evoluir. Sua arquitetura precisa ser rápida para iterar, previsível em custo e amigável a ferramentas visuais.

A pergunta deste capítulo não é "qual é a arquitetura correta de um jogo?". É: **dadas as forças de um jogo, que decisões de arquitetura fazem sentido — e quais dos seus reflexos corporativos ajudam ou atrapalham?**

---

## 6.1 Duas arquiteturas, dois eixos

Comece pelo diagrama que você conhece:

```text
APLICAÇÃO CORPORATIVA — organizada por DEPENDÊNCIA e ABSTRAÇÃO

  requisição HTTP
        │
        ▼
  ┌──────────────┐   adapta protocolo, valida entrada
  │  Controller  │
  └──────┬───────┘
         ▼
  ┌──────────────┐   orquestra o caso de uso, define transação
  │   Service    │
  └──────┬───────┘
         ▼
  ┌──────────────┐   regras e invariantes (o domínio)
  │   Domain     │
  └──────┬───────┘
         ▼
  ┌──────────────┐   abstrai persistência
  │  Repository  │
  └──────┬───────┘
         ▼
     Database
```

Agora, o diagrama equivalente de um jogo:

```text
JOGO — organizado por TEMPO (a ordem das fases dentro do frame)

  ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
  │   Input    │ → │  Gameplay  │ → │  Physics   │ → │ Animation  │ ─┐
  └────────────┘   └────────────┘   └────────────┘   └────────────┘  │
        ▲                                                            ▼
        │          ┌────────────┐   ┌────────────┐   ┌────────────┐  │
        └───────── │ Next Frame │ ← │   Audio    │ ← │ Rendering  │ ◄┘
                   └────────────┘   └────────────┘   └────────────┘
```

A diferença não é só de nomes. É de **eixo de organização**:

- A aplicação corporativa é organizada por **direção de dependência**: camadas de cima dependem das de baixo; o fluxo de uma requisição desce e sobe *uma vez*. A pergunta que ela responde é "**quem pode conhecer quem?**".
- O jogo é organizado por **ordem temporal**: as fases executam em sequência, a cada frame, para sempre. A pergunta que o diagrama responde é "**o que acontece antes do quê?**" — exatamente o tema do Capítulo 2.

E há um terceiro eixo que o diagrama do jogo nem mostra: **o modelo de objetos**. Uma porta, um inimigo e a jogadora não são "camadas" — são **entidades** que participam de **todas** as fases. A porta tem input (interação), gameplay (estado), física (colisão), animação (rotação), render (malha) e áudio (rangido). Ela atravessa o pipeline inteiro.

```text
                 Input   Gameplay   Physics   Animation   Render   Audio
                 ─────   ────────   ───────   ─────────   ──────   ─────
  Jogadora         ●        ●          ●          ●          ●        ●
  Presença                  ●          ●          ●          ●        ●
  Porta            ●        ●          ●          ●          ●        ●
  Lâmpada                   ●                                ●        ●
  Documento        ●        ●                                ●
```

Essa matriz é a tensão fundamental da arquitetura de jogos. Você pode organizar o código **por linha** (cada entidade é um objeto que sabe fazer tudo de que precisa: orientação a objetos) ou **por coluna** (cada fase é um sistema que processa todas as entidades que participam dela: orientação a sistemas/dados). Toda a história dos modelos de objetos de jogo — seção 6.3 — é a história de como essa matriz foi atravessada.

> 🌉 **Ponte:** a matriz lembra a tensão entre arquitetura em camadas (horizontal) e *vertical slices* / arquitetura por *feature* em sistemas corporativos.
>
> 🧱 **Onde a ponte cai:** em sistemas corporativos, a escolha entre fatiar vertical ou horizontalmente é sobre **organização de código e de equipes**. Em jogos, ela também é sobre **performance**: processar por coluna (todas as posições, depois todas as velocidades) tem um comportamento de memória radicalmente diferente de processar por linha (tudo do objeto 1, depois tudo do objeto 2). A seção 6.3 explica por quê.

---

## 6.2 As forças de um jogo

Antes de avaliar arquiteturas, liste as forças. Toda decisão desta seção em diante será justificada por elas.

| Força | Em sistemas corporativos | Em jogos |
|---|---|---|
| **Orçamento de tempo** | Latência por requisição, com escala horizontal | 16,67 ms por frame, hardware fixo, todos os sistemas juntos |
| **Taxa de mudança do design** | Mudanças por decisão de negócio, com ciclos de semanas | Mudanças diárias durante a produção ("encontrar a diversão") |
| **Quem altera o comportamento** | Programadores, via deploy | Designers e artistas, via editor, sem recompilar |
| **Vida útil do código** | Anos a décadas, com evolução contínua | Ciclo de produção (meses a poucos anos), muitas vezes congelado após o lançamento |
| **Escala de objetos** | Milhões de registros, poucos em memória ao mesmo tempo | Centenas a milhares de objetos vivos, **todos** atualizados todo frame |
| **Observabilidade** | Logs, métricas, traces | Debug visual no mundo, profiler de frame, "jogar e ver" |
| **Testes** | Automação ampla | Automação para lógica pura; playtest para todo o resto |
| **Integração** | Muitos sistemas externos, contratos estáveis | Uma engine, que é a plataforma |

Três dessas forças são decisivas para tudo o que segue:

1. **O design muda o tempo todo.** Logo, a arquitetura deve tornar **barato mudar e apagar** comportamento — não necessariamente barato estender.
2. **Não programadores são usuários do código.** Logo, a arquitetura deve se expressar **no editor**: propriedades, componentes que se adicionam com um clique, eventos que se ligam em Blueprint.
3. **Tudo roda todo frame.** Logo, a arquitetura deve tornar o **custo previsível**: você precisa conseguir responder "quanto custa este sistema com 200 objetos?" antes de construí-lo.

---

## 6.3 Modelos de objetos de jogo

### Modelo A — Hierarquia de herança

O primeiro instinto, e historicamente o primeiro modelo usado em muitas engines, é modelar entidades com herança:

```text
                          GameObject
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
          StaticProp       Pickup           Pawn
                              │               │
                     ┌────────┴──┐       ┌────┴─────────┐
                     ▼           ▼       ▼              ▼
                 BatteryPickup  Document Player       Enemy
                                                      │
                                              ┌───────┴────────┐
                                              ▼                ▼
                                         GroundEnemy      FlyingEnemy
```

Funciona bem por algum tempo. Depois, o design pede coisas que a árvore não comporta:

- **Um inimigo que voa e nada.** `FlyingEnemy` e `SwimmingEnemy` são irmãos. Herança múltipla (o "diamante") ou duplicação de código?
- **Um documento que também é uma armadilha.** `Document` herda de `Pickup`; `Trap` está em outro galho. Mover na árvore quebra tudo que dependia da posição antiga.
- **"Coisas que podem ser destruídas".** Caixas, portas, inimigos, lâmpadas — espalhados por galhos diferentes. A lógica de "destrutível" sobe para a raiz, `GameObject`, porque é o único ancestral comum.

O último ponto é o sintoma mais característico: com o tempo, a classe raiz vira um **blob** com dezenas de campos e métodos que só fazem sentido para uma fração dos objetos. Todo objeto paga, em memória e em complexidade, por capacidades que não usa.

> 🌉 **Ponte:** você conhece a máxima "prefira composição a herança" do *Design Patterns* (GoF). Em jogos, ela não é preferência estética; é a lição aprendida dolorosamente por uma geração de engines.

### Modelo B — Componentes

A resposta foi trocar "**o que o objeto é**" por "**o que o objeto tem**". Uma entidade passa a ser um **contêiner de componentes**, e cada componente encapsula uma capacidade:

```text
   Porta                  Presença                 Lâmpada pendurada
   ├─ Malha               ├─ Malha esquelética     ├─ Malha
   ├─ Colisão             ├─ Cápsula de colisão    ├─ Luz
   ├─ Interagível         ├─ Movimento             ├─ Flicker
   ├─ Áudio               ├─ Percepção             ├─ Áudio
   └─ Destrutível         ├─ Vida                  └─ Destrutível
                          └─ Áudio
```

"Destrutível" agora é um componente que se adiciona a qualquer coisa. Um inimigo que voa e nada tem um componente de movimento que suporta os dois modos. A árvore de herança fica **rasa** — e é exatamente o modelo da Unreal: um `AActor` com `UActorComponent`s (Capítulos 8 e 9), e o modelo de muitas outras engines.

Componentes trazem seus próprios problemas, que você vai encontrar no livro:

- **Comunicação entre componentes.** O componente de vida precisa avisar o de áudio que houve dano. Referência direta? Evento no ator? Interface? (Capítulos 9 e 24.)
- **Ordem de atualização entre componentes.** O mesmo problema do Capítulo 2, agora dentro de um único objeto.
- **Descoberta.** "Este ator tem um componente de vida?" vira uma consulta em tempo de execução, não uma garantia de tipo.

### Modelo C — Entity Component System (ECS)

O modelo de componentes ainda é **orientado a objetos**: cada componente é um objeto com dados e comportamento, e cada entidade é um objeto que contém componentes. O **ECS** leva a separação ao extremo:

- **Entidade:** apenas um identificador (um inteiro).
- **Componente:** apenas **dados**, sem comportamento (`Position { x, y, z }`, `Velocity { x, y, z }`).
- **Sistema:** apenas **comportamento**, uma função que processa todas as entidades que têm um certo conjunto de componentes (`MovementSystem`: para toda entidade com `Position` e `Velocity`, `Position += Velocity × Δt`).

Os componentes de mesmo tipo ficam **contíguos na memória**, em arrays. É a organização "por coluna" da matriz da seção 6.1.

```text
ORIENTADO A OBJETOS (por linha)          ECS (por coluna)

 Objeto 1: [pos][vel][vida][malha]...    Positions:  [p1][p2][p3][p4][p5]...
 Objeto 2: [pos][vel][vida][malha]...    Velocities: [v1][v2][v3][v4][v5]...
 Objeto 3: [pos][vel][vida][malha]...    Healths:    [h1][h2][h3][h4][h5]...
 (espalhados pela memória, via ponteiros)
                                         MovementSystem percorre Positions e
                                         Velocities sequencialmente
```

### Por que a organização da memória importa tanto

Aqui está um conhecimento que raramente importa em sistemas corporativos e que é central em jogos. Uma CPU moderna não lê a memória principal byte a byte: ela traz **linhas de cache** (tipicamente 64 bytes) para caches muito mais rápidos (L1, L2, L3). Acessar um dado que já está no cache L1 é muito mais rápido — da ordem de **dezenas a centenas de vezes** — do que buscá-lo na memória principal.

Consequências:

- **Percorrer um array contíguo** é extremamente eficiente: cada linha de cache trazida contém os próximos elementos, e o processador consegue antecipar os próximos acessos (*prefetching*).
- **Seguir ponteiros** (objeto → componente → outro objeto) espalhados pela memória causa uma falha de cache (*cache miss*) a cada salto. O processador passa a maior parte do tempo **esperando a memória**.

Para 50 objetos, a diferença é irrelevante. Para 50.000 partículas, 10.000 pedestres de uma multidão ou 5.000 projéteis, ela decide se o sistema cabe no orçamento de frame. Essa é a motivação do **design orientado a dados** (*data-oriented design*) — popularizado, entre outros, pela palestra de Mike Acton na CppCon 2014, *Data-Oriented Design and C++*: projetar a partir da forma como os dados são transformados e acessados, não a partir de uma taxonomia de objetos.

> 🌉 **Ponte:** você conhece o efeito de localidade em bancos de dados — armazenamento colunar (como em data warehouses) é muito mais rápido para agregações sobre uma coluna, porque lê só os dados necessários, em sequência. ECS é armazenamento colunar para objetos de jogo.
>
> 🧱 **Onde a ponte cai:** em bancos de dados, a escolha entre linha e coluna é feita por *workload* de consulta. Em jogos, o mesmo objeto participa de vários "workloads" por frame (física, IA, render), e a escolha afeta também a **ergonomia de autoria**: um designer pensa em "a porta", não em "a linha 4.317 da tabela de rotações".

### Modelo D — Híbrido (o que a Unreal faz)

Na prática, engines modernas combinam modelos conforme a natureza dos objetos:

| Tipo de objeto | Quantidade típica | Complexidade de cada um | Modelo adequado | Na Unreal |
|---|---|---|---|---|
| Jogador, inimigos principais, portas, interativos | Dezenas a centenas | Alta, únicos, autorados por designers | Componentes (OO) | `AActor` + `UActorComponent` |
| Multidões, tráfego, enxames, pássaros | Milhares | Baixa, homogêneos | ECS / orientado a dados | **Mass Entity** (framework ECS da Unreal) |
| Partículas, efeitos | Dezenas de milhares | Muito baixa | Sistemas especializados (GPU) | Niagara |
| Serviços globais (tempo, narrativa, áudio) | Um por mundo/jogo | Variável | Sistemas/serviços | Subsystems |

**[FATO PÚBLICO]** A Epic usou o framework Mass em demonstrações públicas como o *City Sample* (derivado da demonstração *The Matrix Awakens*), para simular multidões e tráfego em uma cidade com milhares de agentes.

Para a Vigília — uma usina com uma Presença, poucos inimigos e dezenas de interativos — **Actors e Components são a escolha certa para tudo**, e Mass seria uma complexidade sem benefício. Mas você precisa saber que o modelo existe e por que, porque é a ferramenta que entra em cena quando uma ideia de design exige "muitos" — e porque, no Interlúdio II, a população de uma cidade como a de GTA é exatamente esse caso.

---

## 6.4 Sistemas globais: managers, singletons e subsistemas

Nem tudo é entidade. Um jogo tem **serviços globais**: o dono da dilatação do tempo, o sistema narrativo, o gerenciador de música, o sistema de save. No Capítulo 4, a regra do dono único apontou para eles.

### O caminho histórico (e seus problemas)

**Singletons.** A forma mais comum em código de jogos antigo — `AudioManager::Get()`, `GameManager::Instance()`. Robert Nystrom dedica um capítulo inteiro de *Game Programming Patterns* a explicar por que eles costumam ser uma má ideia: estado global oculto, ordem de inicialização frágil, dificuldade de testar, acoplamento invisível.

Na Unreal, há um problema adicional e muito concreto: **em Play In Editor com vários clientes simulados (Parte IX), vários mundos de jogo coexistem no mesmo processo.** Um singleton estático é compartilhado por todos eles. O "nível de ameaça global" do cliente 1 vaza para o cliente 2. Bugs assim são quase impossíveis de entender se você não sabe que há dois mundos no processo.

**"Managers" em atores.** Outra prática comum: colocar no nível um ator invisível `BP_GameManager` e fazer todo mundo procurá-lo com `GetAllActorsOfClass`. Funciona, mas depende de alguém lembrar de colocá-lo em cada nível, tem custo de busca, e não tem ciclo de vida claro.

### Subsistemas da Unreal

A Unreal resolve o problema com **Subsystems**: classes que a engine **cria e destrói automaticamente**, com o ciclo de vida de um objeto "hospedeiro". Você não instancia, não registra, não procura: declara a classe, e ela existe.

| Tipo | Vive enquanto existir... | Uso típico |
|---|---|---|
| `UEngineSubsystem` | O processo da engine | Serviços de baixo nível, raros em gameplay |
| `UEditorSubsystem` | O editor (não existe no jogo empacotado) | Ferramentas de editor |
| `UGameInstanceSubsystem` | A `UGameInstance` — a sessão de jogo inteira, **atravessando trocas de nível** | Progressão, save, estado narrativo persistente, sessão online |
| `UWorldSubsystem` | Um `UWorld` — **um nível carregado** | Serviços do mundo atual: tempo, nível de ameaça, rede elétrica |
| `ULocalPlayerSubsystem` | Um jogador local | Configurações e input por jogador (multiplayer local — o seu PES com o primo!) |

O acesso é tipado e sempre a partir do hospedeiro correto:

```cpp
UVGTimeDilationSubsystem* Time = GetWorld()->GetSubsystem<UVGTimeDilationSubsystem>();
UVGNarrativeSubsystem* Narrative = GetGameInstance()->GetSubsystem<UVGNarrativeSubsystem>();
```

Por que isso é melhor que um singleton:

- **Ciclo de vida explícito.** Um `UWorldSubsystem` nasce com o mundo e morre com ele. Trocar de nível destrói e recria — sem estado velho vazando.
- **Escopo correto em PIE.** Cada mundo tem o seu. Dois clientes simulados, dois subsistemas.
- **Sem registro manual.** Não há ator para esquecer de colocar no nível.
- **Integrado ao Blueprint.** Subsistemas podem expor funções a Blueprint, e há nós para obtê-los.

> 🌉 **Ponte:** subsistemas lembram *beans* com escopo num contêiner de injeção de dependência — `@Singleton`, `@RequestScoped`, `@SessionScoped`. `UGameInstanceSubsystem` ≈ escopo de sessão; `UWorldSubsystem` ≈ escopo de "nível".
>
> 🧱 **Onde a ponte cai:** a Unreal não tem um contêiner de DI. Não há injeção por construtor, não há configuração de *bindings*, não há interfaces resolvidas por tipo. Os mecanismos de composição da Unreal são outros: **componentes** (para entidades), **subsistemas** (para serviços), **referências editáveis** no editor (para conectar objetos de um nível) e **classes configuráveis** em *Project Settings* e no GameMode (para escolher implementações). Tentar trazer um framework de DI para dentro da Unreal é um exemplo clássico de arquitetura elegante e inadequada.

---

## 6.5 Camadas que fazem sentido num jogo

Jogos também têm camadas — só que elas são definidas por **quem cria** e **com que frequência muda**, não por abstração técnica.

```text
  ┌─────────────────────────────────────────────────────────────────────┐
  │  CONTEÚDO            níveis, Blueprints de conteúdo, Data Assets,   │  muda todo dia
  │  (designers)         sequências, áudio, malhas                      │  feito no editor
  ├─────────────────────────────────────────────────────────────────────┤
  │  SISTEMAS DE         vida, bateria, interação, armas, IA,           │  muda toda semana
  │  GAMEPLAY (C++)      narrativa, save — componentes e subsistemas    │  feito em C++
  ├─────────────────────────────────────────────────────────────────────┤
  │  FRAMEWORK           GameMode, PlayerController, Character,         │  muda pouco
  │  DO PROJETO          classes base do projeto (AVG...)                │
  ├─────────────────────────────────────────────────────────────────────┤
  │  ENGINE              Unreal: Actors, física, render, áudio,         │  você não muda
  │                      Gameplay Framework, AI, rede                    │
  └─────────────────────────────────────────────────────────────────────┘
```

A regra de dependência é a que você esperaria: **camadas de cima dependem das de baixo, nunca o contrário.** Um sistema de gameplay em C++ não referencia um Blueprint de conteúdo específico (`BP_Porta_SalaDeControle`); ele define um contrato (uma interface, um evento, uma Gameplay Tag) que o conteúdo usa. Isso é o que permite a designers criarem cem portas diferentes sem tocar em C++ — e é a "regra de camadas" anunciada na Introdução, detalhada no Capítulo 13.

Duas observações de proporção:

- **Para um projeto individual do tamanho da Vigília, um único módulo C++ é suficiente.** Separar o jogo em múltiplos módulos ou *plugins* traz benefícios reais em projetos grandes (tempo de compilação, fronteiras explícitas, reaproveitamento), e custos reais (configuração, dependências circulares a resolver). Decisão do projeto: um módulo, `Vigilia`, organizado por pastas. Se um sistema se provar reaproveitável, ele pode virar um plugin depois.
- **A camada de conteúdo é a maior e a mais importante.** Num jogo terminado, a maior parte das horas de trabalho está nela. Uma arquitetura de sistemas que dificulta o trabalho no conteúdo é uma arquitetura ruim, por mais limpa que seja.

---

## 6.6 Clean Architecture e DDD em jogos: o que transfere

Esta é talvez a seção mais importante do livro para você. Vamos ser específicos.

### O que transfere bem

1. **Isolar lógica pura e testá-la.** Fórmulas de dano, a resolução de pedidos de dilatação do tempo, as transições da máquina de estado de uma quest, a lógica do nível de ameaça. Essas regras não precisam de mundo, física ou tempo real. Extraí-las para funções puras (ou classes sem dependência de engine) e testá-las é exatamente o que você já faz com o domínio. O `UVGBatteryComponent` do Capítulo 4 e o subsistema deste capítulo seguem isso.
2. **Direção de dependência.** Conteúdo depende de sistemas; sistemas dependem da engine. Nunca o contrário (seção 6.5).
3. **Dono único e invariantes.** O equivalente a proteger um agregado (Capítulo 4).
4. **Linguagem ubíqua.** Usar no código os termos do design ("setor", "zona segura", "nível de ameaça"), não termos técnicos genéricos ("area", "safeVolume", "aggroValue"). Isso ajuda tanto quanto em DDD — e mais, porque designers leem os nomes no editor.
5. **Contextos delimitados, em escala pequena.** Narrativa, combate e IA têm vocabulários diferentes; manter suas fronteiras explícitas (comunicação por eventos e tags, não por referências cruzadas) evita que o projeto vire uma bola de lama.

### O que não transfere (ou transfere mal)

1. **Abstrair a engine atrás de portas e adaptadores.** Criar `IPhysicsPort`, `IRenderingGateway`, `IAudioAdapter` para "não depender da Unreal". A engine não é um detalhe de infraestrutura substituível como um banco de dados: ela é a **plataforma**, como a JVM é para você. Ninguém abstrai a JVM. Você vai abrir mão de ferramentas do editor, de Blueprint, de debug visual e de performance — para ganhar uma portabilidade que nunca será usada.
2. **Repositórios para estado de jogo.** O estado vive na memória, nos objetos (Capítulo 1). Não há "carregar a porta do repositório" a cada frame. Persistência é o save (Capítulo 56), com outra natureza.
3. **DTOs e mapeamentos entre camadas.** Converter objetos entre camadas a cada frame aloca memória e custa tempo, multiplicado por todos os objetos, para sempre.
4. **Contêineres de injeção de dependência.** Ver seção 6.4.
5. **Generalização preventiva.** "E se no futuro precisarmos de portas que..." Em jogos, o futuro do design é imprevisível por natureza. Generalize **depois** do terceiro caso concreto, não antes do primeiro.
6. **Modelo anêmico com serviços.** Em DDD, você aprendeu a evitar modelos anêmicos. Em jogos, o risco oposto também existe — mas a tendência natural da engine já é de objetos ricos (atores e componentes com comportamento). Não crie uma camada de "serviços de gameplay" que manipula atores anêmicos de fora.

### O ERP para uma porta

O critério fica mais claro com um exemplo exagerado — mas não tanto quanto parece. Eis uma porta projetada com todos os reflexos corporativos:

```text
IDoorRepository ──────────────► DoorRepositoryImpl (TMap<FGuid, FDoorEntity>)
        ▲
DoorApplicationService
        │ OpenDoorCommand → OpenDoorCommandHandler
        │                        │
        │                        ├─ IDoorPolicy (LockedDoorPolicy, KeyDoorPolicy)
        │                        ├─ IDoorStateMachineFactory
        │                        └─ IDomainEventPublisher → DoorOpenedEvent
        ▼
DoorPresenter ──► IDoorView ──► ADoorViewActor (a malha, finalmente)
```

Quatorze tipos. Cada um defensável isoladamente em outro contexto. Juntos, eles produzem uma porta que:

- não aparece no editor como uma coisa só (o designer precisa entender cinco classes para colocar uma porta trancada);
- tem o estado longe do ator que está no mundo (o debug visual mostra a malha, mas o estado está num `TMap` em outro lugar);
- custa alocações e indireções a cada interação;
- é **difícil de apagar** quando o design decidir que portas da Vigília deslizam em vez de girar.

A porta adequada, que você vai construir no Capítulo 19:

```text
AVGDoor (Actor)
 ├─ malha, colisão, áudio (componentes)
 ├─ estado: EVGDoorState (enum, dono único)
 ├─ implementa IVGInteractable (contrato com o sistema de interação)
 ├─ propriedades editáveis: duração, curva, trancada?, chave necessária
 └─ evento OnDoorStateChanged (áudio, narrativa, IA reagem)
```

Um tipo principal, um contrato, um evento. Tudo visível no editor. A política "precisa de chave" é uma **propriedade**, não uma estratégia polimórfica — até o dia em que houver três políticas de verdade, e então se refatora.

### Critérios de "arquitetura adequada para um jogo"

Para avaliar uma decisão de arquitetura neste livro, usaremos seis perguntas:

| # | Critério | Pergunta |
|---|---|---|
| 1 | **Iteração** | Quanto tempo leva para testar uma mudança de design neste sistema? |
| 2 | **Custo previsível** | Consigo estimar o custo por frame com N objetos? |
| 3 | **Autorabilidade** | Um designer consegue usar e ajustar isto no editor, sem programador? |
| 4 | **Depurabilidade** | Consigo **ver** o estado e o comportamento no jogo rodando? |
| 5 | **Deletabilidade** | Se o design mudar, consigo remover isto sem efeitos em cascata? |
| 6 | **A favor da engine** | Estou usando os mecanismos da engine, ou lutando contra eles? |

O critério 5 merece destaque porque inverte uma intuição sua. Em sistemas corporativos, você otimiza para **extensibilidade**: adicionar funcionalidade sem quebrar o existente. Em jogos, durante a produção, otimize também para **deletabilidade**: a maior parte das funcionalidades que você construir num protótipo será jogada fora, e código fácil de remover é código barato de errar.

> 🌉 **Ponte:** "arquitetura adequada" é a mesma ideia de *fitness function* em arquitetura evolutiva — critérios objetivos que dizem se uma arquitetura serve às forças do sistema. As seis perguntas acima são as *fitness functions* de um jogo.

---

## 6.7 O fluxo de um frame, revisitado com sistemas reais

Agora é possível reescrever o diagrama do jogo da seção 6.1 com o que a Unreal faz em cada fase, e com quem é dono de quê:

```text
┌─────────────┬──────────────────────────────────────┬──────────────────────────────┐
│ Fase        │ Na Unreal                            │ Na Vigília (exemplos)        │
├─────────────┼──────────────────────────────────────┼──────────────────────────────┤
│ Input       │ Enhanced Input → PlayerController    │ lanterna, andar, interagir   │
│ Gameplay    │ Tick de Actors/Components            │ bateria drena, Presença      │
│ (pré-física)│ (TG_PrePhysics), timers, IA          │ decide, porta abre           │
│ Physics     │ Chaos (TG_StartPhysics..EndPhysics)  │ caixa empurrada cai          │
│ Pós-física  │ TG_PostPhysics                       │ reagir à colisão da caixa    │
│ Animation   │ Animation Blueprints, avaliação      │ passos e respiração          │
│             │ (parcialmente em worker threads)     │                              │
│ Camera      │ PlayerCameraManager                  │ head bob, tremores           │
│ Audio       │ Audio Mixer (thread própria)         │ maquinário, rangidos         │
│ Rendering   │ Render thread → RHI → GPU            │ luz da lanterna, Lumen       │
│ Next frame  │ FEngineLoop::Tick                    │                              │
└─────────────┴──────────────────────────────────────┴──────────────────────────────┘

Transversais (fora da sequência): Subsystems (serviços com dono único),
eventos/delegates (comunicação entre sistemas), streaming de níveis/assets (assíncrono).
```

E, lado a lado com o fluxo corporativo, a comparação que o seu instinto vai querer fazer:

| Aplicação | Jogo | Equivalência? |
|---|---|---|
| Controller (adapta protocolo) | PlayerController + Enhanced Input (adapta dispositivo em intenção) | **Parcial.** Ambos traduzem uma entrada externa em intenção. Mas o PlayerController persiste e tem estado (câmera, alvo de interação). |
| Service (orquestra caso de uso) | — | **Não há equivalente direto.** Não há "caso de uso" com começo e fim; há objetos que se atualizam continuamente. O que mais se aproxima são sequências roteirizadas (Capítulo 4) e GameMode (regras da partida). |
| Domain (regras e invariantes) | Componentes de gameplay e subsistemas | **Sim**, no sentido de dono do estado e das regras. |
| Repository / Database | Memória (o mundo) + SaveGame | **Não.** O mundo em memória é a fonte da verdade; o save é um snapshot ocasional. |
| Requisição (unidade de trabalho) | Frame | **Não.** O frame não pertence a ninguém; é o ritmo de todos. |

---

## Estudo de caso: Control — um mundo sistêmico exige contratos uniformes

> **Pergunta:** que tipo de arquitetura um jogo precisa para que *qualquer* objeto do cenário possa participar do combate?

### O que é publicamente conhecido

**[FATO PÚBLICO]** *Control* (Remedy Entertainment, 2019) roda na engine proprietária da Remedy, a **Northlight**. A protagonista, Jesse Faden, tem poderes sobrenaturais; o principal deles, *Launch*, permite arrancar objetos do ambiente — e até pedaços da própria arquitetura, como blocos de concreto — e arremessá-los contra inimigos. O jogo é conhecido por ambientes amplamente destrutíveis, com grande quantidade de detritos, partículas e objetos físicos reagindo a tiros e poderes. A Remedy apresentou publicamente aspectos técnicos de Control (por exemplo, sobre renderização e iluminação) em eventos da indústria.

O que segue é análise.

### 1. Experiência

Poder sobrenatural num lugar que reage. Cada sala é uma arma em potencial; o combate deixa marcas visíveis no espaço; o jogador se sente **dono da física do ambiente**.

### 2. Sistema

```text
             QUALQUER OBJETO DO CENÁRIO
                        │
      ┌─────────────────┼─────────────────┬─────────────────┐
      ▼                 ▼                 ▼                 ▼
 pode ser          pode causar       pode ser          gera feedback
 agarrado          dano ao colidir   destruído         (partículas, som,
 (Launch)          (projétil)        (detritos)        decals, câmera)
      └─────────────────┴────────┬────────┴─────────────────┘
                                 ▼
                 combate sistêmico + ambiente que conta
                 a história do combate (narrativa ambiental)
```

### 3. Design

A decisão central é **não** tratar "objetos que viram armas" como uma lista de casos especiais. Se só algumas caixas marcadas à mão pudessem ser arremessadas, o poder seria um truque; como praticamente tudo pode, ele é um sistema. Isso transfere a variedade do combate do **conteúdo roteirizado** para a **interação de sistemas** — o lado direito do espectro da seção 5.6.

### 4. Tecnologia

**[INFERÊNCIA]** Para que isso funcione, a arquitetura precisa de **contratos uniformes** — e é aqui que o estudo de caso encontra este capítulo. Sem nenhuma afirmação sobre a Northlight:

- objetos arremessáveis precisam de uma **representação física comum** (massa, colisão, resposta a forças), independentemente de serem uma cadeira ou um bloco de parede;
- o sistema de dano precisa aceitar **qualquer fonte** — "objeto físico com velocidade e massa colidiu com um inimigo" —, e não "o projétil do tipo X";
- a destruição precisa ser um **componente ou capacidade genérica** aplicável a muitos tipos de geometria;
- o feedback (som, partículas, decals) precisa vir de **dados associados ao material**, não de scripts por objeto;
- e tudo isso precisa caber no orçamento de frame com dezenas de objetos físicos ativos ao mesmo tempo — o que pressiona por sistemas eficientes e por regras de quando objetos "adormecem" fisicamente.

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]** Na Unreal, a versão mínima de "qualquer objeto pode ferir ao ser arremessado" é surpreendentemente pequena, **se** os contratos forem uniformes:

```text
1. Todo objeto arremessável: um StaticMeshComponent com física simulada
   e um Physical Material (Cap. 15) — nenhuma classe especial necessária.
2. "Agarrar e arremessar": um componente no jogador que faz um trace,
   prende o corpo físico com um Physics Handle e aplica um impulso.
3. Dano: um evento de colisão (OnComponentHit) genérico que converte
   velocidade relativa × massa em dano e chama o sistema de dano padrão (Cap. 22).
4. Feedback: som e partícula escolhidos pelo Physical Material da superfície.
```

Nenhum desses passos menciona "cadeira" ou "bloco". É isso que torna o sistema escalável em conteúdo: um artista coloca um objeto novo no nível, ativa física, escolhe o material — e o objeto já participa do combate.

### 6. Lição

**Sistemas emergentes exigem contratos uniformes; casos especiais matam a emergência.** Cada `if (objeto == cadeiraEspecial)` é um ponto onde o sistema deixa de ser sistema. A arquitetura de um jogo sistêmico investe em **poucos contratos genéricos e bem escolhidos** (física comum, dano genérico, feedback por material, interação por interface) em vez de muitas classes específicas. É a mesma lição da seção 6.3 (componentes em vez de herança) vista pelo lado do design.

Para a Vigília: a interação (Capítulo 19), o dano (Capítulo 22) e o ruído que atrai a Presença (Capítulo 36) serão contratos genéricos. Qualquer objeto que caia faz ruído; qualquer porta pode ser trancada; qualquer coisa que emite luz pode ser parte da rede elétrica.

---

## Implementação: o subsistema de dilatação do tempo

🔁 **Refatoração.** No Capítulo 3, o hitstop e o bullet time escreviam diretamente na dilatação global do tempo, e um sobrescrevia o outro. No Capítulo 4, a regra do dono único levou à ideia de **pedidos com handle**, e você implementou a lógica de resolução em C++ puro. Agora ela ganha sua casa definitiva: um `UWorldSubsystem`.

**Por que `UWorldSubsystem`:** a dilatação global é propriedade de **um mundo**. Ao trocar de nível, os pedidos antigos não fazem sentido; em PIE com vários clientes, cada mundo tem a sua.

**Uma decisão de design incorporada:** no exercício do Capítulo 4, a pergunta era se "o mínimo vence" é sempre a regra certa. Não é: uma cinemática precisa **forçar** velocidade normal, mesmo com bullet time ativo. A regra adotada: **a maior prioridade vence; entre pedidos de mesma prioridade, vence a menor escala.**

```cpp
// Source/Vigilia/Core/VGTimeDilationSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGTimeDilationSubsystem.generated.h"

/** Um pedido de dilatação do tempo. Não é exposto a Blueprint; é estado interno do subsistema. */
struct FVGTimeDilationRequest
{
    float Scale = 1.0f;
    int32 Priority = 0;
    FName Reason;
};

/**
 * Dono único da dilatação global do tempo de um mundo.
 * Sistemas pedem uma escala com prioridade e recebem um handle; liberam o próprio pedido ao terminar.
 * Regra: maior prioridade vence; empate → menor escala.
 * Prioridades sugeridas: 0 gameplay (bullet time), 10 feedback (hitstop), 100 cinemática/UI.
 */
UCLASS()
class VIGILIA_API UVGTimeDilationSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Time")
    int32 RequestDilation(float Scale, int32 Priority, FName Reason);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Time")
    void ReleaseDilation(int32 Handle);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Time")
    float GetEffectiveDilation() const { return EffectiveDilation; }

    /** Regra de resolução, pura e testável sem mundo. */
    static float ResolveEffective(const TArray<FVGTimeDilationRequest>& Requests);

protected:
    virtual bool DoesSupportWorldType(const EWorldType::Type WorldType) const override;

private:
    void ApplyEffective();

    TMap<int32, FVGTimeDilationRequest> ActiveRequests;
    int32 NextHandle = 1;
    float EffectiveDilation = 1.0f;
};
```

```cpp
// Source/Vigilia/Core/VGTimeDilationSubsystem.cpp
#include "Core/VGTimeDilationSubsystem.h"

#include "Kismet/GameplayStatics.h"

bool UVGTimeDilationSubsystem::DoesSupportWorldType(const EWorldType::Type WorldType) const
{
    // Só faz sentido em mundos de jogo (jogo empacotado ou PIE), não em mundos de preview do editor.
    return WorldType == EWorldType::Game || WorldType == EWorldType::PIE;
}

int32 UVGTimeDilationSubsystem::RequestDilation(float Scale, int32 Priority, FName Reason)
{
    FVGTimeDilationRequest Request;
    Request.Scale = FMath::Max(Scale, 0.0001f); // zero absoluto congelaria timers e ticks de jogo
    Request.Priority = Priority;
    Request.Reason = Reason;

    const int32 Handle = NextHandle++;
    ActiveRequests.Add(Handle, Request);
    ApplyEffective();
    return Handle;
}

void UVGTimeDilationSubsystem::ReleaseDilation(int32 Handle)
{
    if (ActiveRequests.Remove(Handle) > 0)
    {
        ApplyEffective();
    }
}

float UVGTimeDilationSubsystem::ResolveEffective(const TArray<FVGTimeDilationRequest>& Requests)
{
    if (Requests.IsEmpty())
    {
        return 1.0f;
    }

    int32 TopPriority = TNumericLimits<int32>::Lowest();
    for (const FVGTimeDilationRequest& Request : Requests)
    {
        TopPriority = FMath::Max(TopPriority, Request.Priority);
    }

    float Result = TNumericLimits<float>::Max();
    for (const FVGTimeDilationRequest& Request : Requests)
    {
        if (Request.Priority == TopPriority)
        {
            Result = FMath::Min(Result, Request.Scale);
        }
    }
    return Result;
}

void UVGTimeDilationSubsystem::ApplyEffective()
{
    TArray<FVGTimeDilationRequest> Requests;
    ActiveRequests.GenerateValueArray(Requests);

    EffectiveDilation = ResolveEffective(Requests);
    UGameplayStatics::SetGlobalTimeDilation(GetWorld(), EffectiveDilation);
}
```

### Explicação das decisões

- **`FVGTimeDilationRequest` é uma `struct` C++ simples, não um `USTRUCT`.** Ela não precisa de reflexão: não aparece no editor, não vai para Blueprint, não é salva. Usar o sistema de reflexão onde ele não é necessário é custo sem benefício (seção 6.6, item 5).
- **`ActiveRequests` não é `UPROPERTY`.** O `TMap` contém apenas valores simples (sem ponteiros para `UObject`), então o garbage collector não precisa enxergá-lo. Se contivesse ponteiros para `UObject`, **precisaria** ser `UPROPERTY` — um detalhe crucial que o Capítulo 11 explica.
- **`ResolveEffective` é estática e pura.** É a regra de negócio, isolada e testável — o item 1 do "o que transfere" da seção 6.6.
- **`Reason` existe para depuração.** Quando a dilatação estiver errada, a primeira pergunta será "quem pediu?". Um exercício abaixo expõe isso visualmente.
- **`DoesSupportWorldType`** evita criar o subsistema em mundos que não são de jogo (por exemplo, mundos de pré-visualização de assets no editor).
- **Escala mínima de 0,0001.** Uma dilatação de zero absoluto pararia completamente o tempo de jogo — incluindo os timers que deveriam encerrar o próprio pedido. A Unreal também impõe limites de dilatação nas *World Settings*.

### O hitstop, refatorado

Com o subsistema, a solução de referência do desafio do Capítulo 3 fica assim:

```cpp
// Trecho de um UVGHitstopComponent (solução de referência do desafio do Cap. 3)
void UVGHitstopComponent::TriggerHitstop(float RealDurationSeconds, float TimeScale)
{
    UVGTimeDilationSubsystem* Time = GetWorld()->GetSubsystem<UVGTimeDilationSubsystem>();
    if (!Time) { return; }

    if (RequestHandle == INDEX_NONE)
    {
        RequestHandle = Time->RequestDilation(TimeScale, /*Priority=*/10, TEXT("Hitstop"));
    }

    // Estende em vez de empilhar; mede em TEMPO REAL, imune à própria dilatação.
    EndRealTime = FMath::Max(EndRealTime, GetWorld()->GetRealTimeSeconds() + RealDurationSeconds);
    SetComponentTickEnabled(true);
}

void UVGHitstopComponent::TickComponent(float DeltaSeconds, ELevelTick TickType,
                                        FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaSeconds, TickType, ThisTickFunction);

    if (GetWorld()->GetRealTimeSeconds() >= EndRealTime)
    {
        if (UVGTimeDilationSubsystem* Time = GetWorld()->GetSubsystem<UVGTimeDilationSubsystem>())
        {
            Time->ReleaseDilation(RequestHandle);
        }
        RequestHandle = INDEX_NONE;
        SetComponentTickEnabled(false);
    }
}
```

O hitstop não sabe que o bullet time existe, e vice-versa. Quando o hitstop libera o seu pedido, o subsistema recalcula e o bullet time volta a valer. E uma cinemática com prioridade 100 suprime ambos — sem que nenhum deles precise saber disso.

> **Cuidado com o ciclo de vida:** se o componente for destruído com um pedido ativo, o pedido fica órfão e o mundo permanece em câmera lenta. Uma implementação completa libera o pedido em `EndPlay`. Esse é o "risco 3" do Capítulo 4 (ciclo de vida) aparecendo de novo — e é o tipo de detalhe que a checklist do capítulo pede para verificar.

### O teste

```cpp
// Source/Vigilia/Tests/VGTimeDilationSubsystemTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGTimeDilationSubsystem.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGTimeDilationResolveTest,
    "Vigilia.Core.TimeDilation.Resolve",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGTimeDilationResolveTest::RunTest(const FString& Parameters)
{
    auto Make = [](float Scale, int32 Priority)
    {
        FVGTimeDilationRequest Request;
        Request.Scale = Scale;
        Request.Priority = Priority;
        return Request;
    };

    TestEqual(TEXT("Sem pedidos → 1.0"),
        UVGTimeDilationSubsystem::ResolveEffective({}), 1.0f);

    TestEqual(TEXT("Mesma prioridade → menor escala"),
        UVGTimeDilationSubsystem::ResolveEffective({ Make(0.3f, 0), Make(0.05f, 0) }), 0.05f);

    TestEqual(TEXT("Hitstop (10) vence bullet time (0)"),
        UVGTimeDilationSubsystem::ResolveEffective({ Make(0.3f, 0), Make(0.05f, 10) }), 0.05f);

    TestEqual(TEXT("Cinemática (100) força 1.0"),
        UVGTimeDilationSubsystem::ResolveEffective({ Make(0.3f, 0), Make(0.05f, 10), Make(1.0f, 100) }), 1.0f);

    return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
```

---

## Decisões arquiteturais (consolidação da Parte I)

Estas são as regras de arquitetura do projeto Vigília daqui em diante. Elas consolidam os seis capítulos da Parte I.

1. **Modelo de objetos:** Actors + Components para tudo que existe no mundo. Herança rasa: no máximo uma classe base do projeto entre a classe da engine e o Blueprint de conteúdo (ex.: `ACharacter → AVGCharacter → BP_Jogadora`).
2. **Serviços globais:** Subsystems. `UWorldSubsystem` para o que pertence a um nível; `UGameInstanceSubsystem` para o que atravessa níveis. **Nenhum singleton estático com estado.**
3. **Estado:** dono único, estados discretos como enum ou Gameplay Tag, apresentação sempre derivada (Capítulo 4).
4. **Comunicação:** eventos para transições discretas, consulta para valores contínuos; contratos por interface para capacidades genéricas (interação, dano, ruído).
5. **Tempo:** tick só quando útil; Δt em tudo; decaimento exponencial para suavização; relógio declarado por sistema; dilatação global só via `UVGTimeDilationSubsystem` (Capítulos 2–3, 6).
6. **Camadas:** Engine → Framework do projeto → Sistemas de gameplay (C++) → Conteúdo (Blueprint, dados, níveis). Sistemas não referenciam conteúdo específico.
7. **Lógica pura é extraída e testada.** Tudo que pode ser uma função sem mundo, é.
8. **Um módulo C++.** Pastas por domínio (`Core`, `Player`, `Interaction`, `Combat`, `AI`, `Narrative`, `World`, `Save`, `UI`, `Debug`, `Tests`).
9. **Generalização depois do terceiro caso concreto.** Até lá, propriedades e enums.
10. **As seis perguntas da seção 6.6** são o critério de revisão de qualquer sistema novo.

---

## Armadilhas

- **Hierarquias profundas** de classes de gameplay. Se você está criando o quarto nível de herança abaixo de `AActor`, pare e pense em componentes.
- **Abstrair a engine.** Portas e adaptadores em volta da Unreal.
- **Singletons estáticos com estado.** Quebram em PIE com vários mundos e na troca de nível.
- **Managers no nível procurados com `GetAllActorsOfClass`.** Use subsistemas.
- **ECS onde não há "muitos".** Mass Entity para uma usina com dez interativos é complexidade sem retorno.
- **Ignorar a memória onde há "muitos".** Milhares de atores completos para uma multidão.
- **Sistemas que referenciam conteúdo específico.** C++ que conhece `BP_Porta_Sala3`.
- **Otimizar para extensibilidade em vez de deletabilidade** durante a fase de protótipo.
- **Generalização preventiva.** Estratégias, fábricas e políticas para um caso só.

---

## Exercício

**Parte 1 — matriz de entidades (45 min).** Monte a matriz da seção 6.1 para a Vigília completa (use o documento de loops do Capítulo 5): liste pelo menos 12 tipos de entidade e marque em que fases cada uma participa. Para cada entidade, indique o modelo adequado (Actor + Components, Mass, Niagara, Subsystem) e justifique as escolhas que não forem óbvias.

**Parte 2 — o subsistema (1,5 h).** Implemente o `UVGTimeDilationSubsystem` e o teste. Depois, crie um Blueprint de teste com duas teclas: uma pede bullet time (0,3, prioridade 0) e libera ao soltar; outra pede um hitstop de 0,1 s reais (0,05, prioridade 10). Verifique que o hitstop durante o bullet time volta para 0,3, e não para 1,0.

**Parte 3 — observabilidade (45 min).** Adicione ao subsistema uma função de debug que escreva na tela (`GEngine->AddOnScreenDebugMessage`) a lista de pedidos ativos com `Reason`, prioridade e escala, e o valor efetivo. Chame-a a partir de um comando de console ou de um tick de debug. Pergunte-se: em que momento do projeto isso vai salvar horas?

**Parte 4 — revisão crítica (30 min).** Pegue um sistema que você já projetou profissionalmente (um serviço, um módulo) e responda às seis perguntas da seção 6.6 como se ele fosse um sistema de jogo. Em quais ele iria mal? Por quê? Escreva no `DEVLOG.md`.

---

## Desafio — o ERP para uma porta, ao contrário

Escreva, em pseudocódigo ou C++, a versão "corporativa" da porta (seção 6.6) com pelo menos oito tipos. Em seguida, escreva a versão adequada. Agora aplique três mudanças de design, uma de cada vez, às duas versões, e conte quantos arquivos você precisou alterar em cada:

1. "As portas da subestação deslizam em vez de girar."
2. "Algumas portas só abrem com a rede elétrica do setor ligada."
3. "Removam as portas com chave; os playtesters acharam chato."

Que versão venceu em cada mudança? Houve alguma mudança em que a versão corporativa foi melhor? Se sim, qual característica do requisito tornou isso possível — e com que frequência requisitos assim aparecem num jogo?

---

## Uso de IA

1. **Para revisar arquitetura com as forças certas:**
   > "Vou descrever a arquitetura de um sistema de gameplay em Unreal Engine 5. Avalie-a pelos seguintes critérios, nesta ordem: velocidade de iteração de design, previsibilidade de custo por frame, facilidade de uso por designers no editor, depurabilidade visual, facilidade de remoção e alinhamento com os mecanismos da engine. Aponte abstrações que você removeria. Não sugira padrões corporativos (DI, repositórios, camadas de serviço) a menos que justifique pelas forças acima. [descrição]"

2. **Para entender ECS na prática:**
   > "Explique, com um exemplo concreto de 10.000 pedestres numa cidade, por que um modelo ECS orientado a dados é mais eficiente que 10.000 atores com componentes. Fale de linhas de cache, fragmentação de memória, custo de tick por objeto e de como as duas abordagens coexistem numa engine como a Unreal (Actors e Mass Entity). Indique quando você NÃO usaria ECS."

3. **Para escolher o tipo de subsistema:**
   > "Para cada serviço a seguir, de um jogo narrativo em Unreal Engine 5, diga qual tipo de subsystem você usaria (Engine, GameInstance, World, LocalPlayer) ou se não usaria subsystem, e justifique pelo ciclo de vida: dilatação do tempo, estado narrativo, nível de ameaça do inimigo, configurações de áudio do jogador, sistema de save, gerenciador de música dinâmica, catálogo de documentos colecionáveis."

**Cuidado específico:** pedidos genéricos como "projete a arquitetura do meu jogo" tendem a produzir respostas com muitas camadas e padrões corporativos, porque essa é a maior parte do material de "arquitetura" disponível. Sempre explicite as forças de um jogo no prompt.

---

## Checklist

- [ ] Sei explicar por que a aplicação corporativa é organizada por dependência e o jogo por tempo e por entidades.
- [ ] Consigo desenhar a matriz entidades × fases e explicar a tensão entre organizar por linha e por coluna.
- [ ] Sei os problemas da hierarquia de herança, as vantagens e custos de componentes e a motivação do ECS.
- [ ] Sei explicar linha de cache, cache miss e por que dados contíguos importam com "muitos" objetos.
- [ ] Sei quando usar Actors, Mass, Niagara e Subsystems.
- [ ] Conheço os tipos de subsistema da Unreal e seus ciclos de vida, e por que singletons estáticos quebram em PIE.
- [ ] Sei listar o que transfere da Clean Architecture/DDD e o que não transfere.
- [ ] Sei aplicar as seis perguntas de "arquitetura adequada".
- [ ] Implementei e testei o `UVGTimeDilationSubsystem`, e entendo por que ele resolve o conflito dos Capítulos 3 e 4.
- [ ] Consigo explicar, com o estudo de caso de Control, por que sistemas emergentes exigem contratos uniformes.

---

## Para ir além

- **Robert Nystrom, *Game Programming Patterns*** — capítulos **"Component"**, **"Update Method"**, **"Singleton"**, **"Service Locator"** e **"Data Locality"**. Juntos, são praticamente um curso de arquitetura de objetos de jogo.
- **Jason Gregory, *Game Engine Architecture*** — os capítulos sobre sistemas de fundação de gameplay em runtime (*Runtime Gameplay Foundation Systems*): modelos de objetos, atualização, eventos.
- **Mike Acton, *Data-Oriented Design and C++*** (CppCon 2014) — palestra disponível publicamente; provocativa e fundamental.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre **Programming Subsystems** e sobre **Mass Entity**.

---

## Fechamento da Parte I

A Parte I construiu o modelo mental sem o qual a engine seria apenas um conjunto de botões:

```text
Cap. 1  Um jogo é uma simulação interativa em tempo real; o requisito é a experiência.
Cap. 2  O game loop: fases, ordem, threads, tick groups; Tick vs. Timer vs. Evento.
Cap. 3  O tempo como entrada: Δt, passo fixo, integração, relógios, dilatação.
Cap. 4  Estado e eventos: categorias, dono único, FSM, histerese, eventos síncronos.
Cap. 5  O gameplay loop: escalas, MDA, realimentação, feedback, emergência, pacing.
Cap. 6  Arquitetura: eixos, modelos de objetos, dados, subsistemas, o que é adequado.
```

Na Parte II, a engine deixa de ser referência e passa a ser a ferramenta de trabalho. O primeiro passo é abrir o editor, criar o projeto `Vigilia` de verdade e construir o **Projeto 1 — o Pátio da Usina**.

➡️ **Próximo:** [Capítulo 7 — Conhecendo a Engine](../parte-02/cap-07-conhecendo-a-engine.md)

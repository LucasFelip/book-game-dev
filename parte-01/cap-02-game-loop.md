# Capítulo 2 — Game Loop

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que todo jogo é construído em torno de um laço principal que nunca para, e o que acontece em cada fase desse laço;
- entender por que a **ordem** das fases dentro de um frame importa, e reconhecer os bugs que nascem de uma ordem errada;
- descrever como engines modernas distribuem o frame entre várias threads (*game thread*, *render thread*, GPU) e o que isso custa em latência;
- mapear tudo isso para a Unreal: `FEngineLoop`, `UWorld::Tick`, *tick functions* e **tick groups**;
- escolher conscientemente entre **Tick**, **timers** e **eventos** para fazer algo acontecer ao longo do tempo.

O Capítulo 1 disse que a unidade fundamental de um jogo é o frame. Este capítulo abre o frame e mostra o que há dentro.

---

## Contexto

Todo programa interativo precisa resolver o mesmo problema: **ler o que o usuário quer, atualizar o estado e mostrar o resultado**. Num servidor web, esse ciclo é disparado de fora — uma requisição chega e o framework chama o seu código. Você nunca escreve o laço; o Tomcat, o Netty ou o Kubernetes fazem isso por você, e seu código vive *dentro* de callbacks.

Em jogos, o ciclo não é disparado por nada externo. O jogo precisa avançar mesmo sem input; precisa desenhar mesmo sem mudanças; precisa ler o controle sem ficar bloqueado esperando por ele. A solução é o padrão mais antigo e mais universal da programação de jogos: o **game loop**.

Robert Nystrom, em *Game Programming Patterns*, resume a intenção do padrão assim: desacoplar a progressão do tempo do jogo tanto do input do usuário quanto da velocidade do processador. As duas metades dessa frase são os dois problemas deste capítulo e do próximo.

---

## 2.1 Do programa que espera ao programa que não para

Considere o jogo interativo mais simples possível: uma aventura de texto.

```cpp
while (!bGameOver)
{
    std::string command = ReadLineFromConsole(); // BLOQUEIA até o usuário digitar
    UpdateWorld(command);
    PrintDescription();
}
```

Isso já é um game loop — e é exatamente o modelo de um servidor: o programa **espera** um comando, processa, responde, espera de novo. Para jogos por turnos (xadrez, aventuras de texto, alguns RPGs), funciona perfeitamente, porque o mundo *só muda quando o jogador age*.

Agora imagine que, nessa aventura, uma criatura se aproxima enquanto o jogador pensa. Com `ReadLineFromConsole()` bloqueante, a criatura está congelada até o jogador apertar Enter. O mundo não pode existir de forma independente do jogador.

A primeira mudança conceitual é, portanto, **parar de esperar input**. Em vez de "esperar um comando", o jogo pergunta a cada volta do laço "há algum input novo?" e segue em frente com a resposta, seja ela qual for:

```cpp
while (bRunning)
{
    ProcessInput();  // NÃO bloqueia: consome o que chegou desde o último frame
    Update();        // avança o mundo — com ou sem input
    Render();        // desenha o estado atual
}
```

Essas três linhas são o esqueleto de praticamente todo jogo em tempo real já feito, do Pong à Unreal Engine 5. O resto deste capítulo é sobre os detalhes que tornam esse esqueleto utilizável.

### O que "ProcessInput" realmente significa

O sistema operacional entrega eventos de teclado, mouse e controle de forma assíncrona. O jogo os acumula numa fila (ou consulta o estado atual dos dispositivos) e, no início de cada frame, **drena** essa fila. O resultado é uma "foto" do input para aquele frame: quais botões estão pressionados, quais foram apertados ou soltos desde o último frame, quanto o mouse se moveu, onde estão os analógicos.

Essa foto é importante: durante todo o frame, todos os sistemas enxergam **o mesmo input**. Se o sistema de movimento e o sistema de armas lessem o hardware em momentos diferentes do frame, poderiam ver estados diferentes — o jogador estaria "pulando" para um e "parado" para outro.

> 🌉 **Ponte:** é a mesma ideia de ler uma configuração ou um *snapshot* consistente no início de uma transação, em vez de consultar uma fonte mutável várias vezes durante o processamento.

---

## 2.2 O problema da velocidade

O laço mínimo tem um defeito grave: ele roda **o mais rápido possível**. Numa máquina rápida, ele dá 500 voltas por segundo; numa lenta, 40. Se `Update()` move o personagem "um pouco" a cada volta, a velocidade do personagem depende do processador.

Existem três estratégias clássicas para resolver isso. Vamos apresentá-las aqui em alto nível; o Capítulo 3 é inteiramente dedicado a elas.

**Estratégia 1 — Frame rate fixo com espera.** Cada frame tem uma duração-alvo (por exemplo, 16,67 ms). Se o trabalho terminou antes, o laço dorme o tempo que falta.

```cpp
while (bRunning)
{
    const auto frameStart = Clock::now();
    ProcessInput();
    Update();           // assume que cada chamada representa exatamente 1/60 s
    Render();
    SleepUntil(frameStart + TargetFrameDuration);
}
```

Simples, mas frágil: se um frame demora mais do que o alvo, o jogo **fica mais lento** (o tempo do jogo atrasa em relação ao tempo real). Muitos jogos de console antigos, com hardware fixo e conhecido, funcionavam essencialmente assim.

**Estratégia 2 — Delta time variável.** Mede-se quanto tempo passou desde o último frame e passa-se esse valor (Δt) para o `Update`, que escala tudo por ele.

```cpp
auto previous = Clock::now();
while (bRunning)
{
    const auto now = Clock::now();
    const float dt = SecondsBetween(previous, now);
    previous = now;

    ProcessInput();
    Update(dt);         // move = velocidade * dt
    Render();
}
```

O jogo agora roda na mesma velocidade em qualquer máquina. É a estratégia que a Unreal usa para o tick de gameplay — e o `float DeltaSeconds` que você viu no Capítulo 1 vem daqui. O custo: com Δt variável, a simulação fica **não determinística** e sensível a frames longos (um Δt de 200 ms faz um projétil "atravessar" uma parede fina de uma vez).

**Estratégia 3 — Passo fixo para a simulação, renderização livre.** A simulação avança sempre em passos de tamanho fixo (por exemplo, 1/60 s), quantas vezes forem necessárias para "alcançar" o tempo real; a renderização acontece uma vez por volta do laço, interpolando entre os dois últimos estados.

```cpp
double accumulator = 0.0;
while (bRunning)
{
    accumulator += MeasureFrameTime();
    ProcessInput();
    while (accumulator >= FixedStep)
    {
        Update(FixedStep);   // sempre o mesmo dt: determinístico e estável
        accumulator -= FixedStep;
    }
    Render(accumulator / FixedStep); // fator de interpolação para suavizar
}
```

É a estratégia preferida para física e para simulações que precisam ser estáveis ou reproduzíveis (incluindo muitos jogos multiplayer). É também a forma do famoso artigo *Fix Your Timestep!*, de Glenn Fiedler, que vamos estudar em detalhe no próximo capítulo.

Na prática, engines modernas **combinam** estratégias: gameplay com Δt variável, física com passo fixo ou subdividido (*substepping*), animação com Δt variável, rede com uma taxa própria. Guarde a ideia de que **sistemas diferentes podem ter relógios diferentes dentro do mesmo frame**.

---

## 2.3 Anatomia de um frame

As três linhas `ProcessInput / Update / Render` são uma simplificação. Num jogo real em primeira pessoa, um frame se parece mais com isto:

```text
┌──────────────────────────────── UM FRAME ────────────────────────────────┐
│                                                                          │
│  1. Plataforma      mensagens do SO, janela, foco, eventos do sistema    │
│  2. Input           drenar dispositivos → "foto" do input deste frame    │
│  3. Rede (entrada)  pacotes recebidos → estado remoto (Parte IX)         │
│  4. Gameplay        lógica: personagem, armas, IA, scripts, timers       │
│  5. Física          simular corpos, resolver colisões                    │
│  6. Pós-física      gameplay que precisa do resultado da física          │
│  7. Animação        avaliar poses dos esqueletos                         │
│  8. Câmera          posicionar a câmera DEPOIS de tudo se mover          │
│  9. Áudio           atualizar posição de fontes e ouvinte, mixagem       │
│ 10. Rede (saída)    enviar estado/inputs (Parte IX)                      │
│ 11. Render          decidir o que é visível, montar comandos para GPU    │
│ 12. Present         entregar a imagem à tela (sincronizada ou não)       │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

A lista exata varia de engine para engine, mas a **lógica da ordem** é universal, e vale entendê-la porque cada inversão produz um tipo de bug característico:

- **Input antes de gameplay.** Óbvio, mas importante: o input lido no frame N deve afetar a simulação do frame N. Se o input for lido depois do gameplay, ele só tem efeito no frame N+1 — um frame inteiro de latência extra, que um jogador de FPS sente.
- **Física entre dois momentos de gameplay.** Algumas lógicas precisam rodar *antes* da física (aplicar a força de um pulo, mover um objeto cinemático), outras *depois* (reagir a uma colisão que acabou de acontecer, posicionar algo grudado num objeto que a física moveu).
- **Animação depois do movimento.** A pose do personagem depende de sua velocidade e do estado de movimento deste frame. Avaliada antes, ela mostra a pose do frame anterior.
- **Câmera por último entre os sistemas de mundo.** Se a câmera for posicionada antes de o personagem se mover, ela fica sempre um frame atrasada. Em primeira pessoa, isso aparece como um **tremor sutil** (*jitter*), especialmente em movimentos rápidos — um dos bugs mais clássicos de iniciantes, e o tema do desafio deste capítulo.
- **Render por último.** Ele precisa ver o mundo no estado final do frame.

> 🌉 **Ponte:** pense no frame como um **pipeline de estágios com dependências de dados**, parecido com um DAG de um job de processamento (ou com as fases de um build). Cada estágio consome o que os anteriores produziram. Inverter dois estágios não dá erro de compilação: dá resultado com um frame de atraso.
>
> 🧱 **Onde a ponte cai:** num DAG de dados, uma dependência mal declarada costuma produzir um resultado *errado* que um teste pega. No game loop, ela produz um resultado *atrasado em 16 ms* — correto em valor, errado em tempo. Nenhum teste unitário pega isso; os seus olhos pegam.

---

## 2.4 Pipelining: o frame não acontece numa thread só

Até aqui, descrevemos o frame como uma sequência. Em engines modernas, é mais sutil: **o trabalho de um frame é distribuído entre várias threads, e frames consecutivos se sobrepõem**.

A divisão típica, que a Unreal segue, é:

- **Game thread** — input, gameplay, física (coordenação), animação (coordenação), câmera. É onde roda quase todo o código que você vai escrever.
- **Render thread** — recebe do game thread uma descrição do que existe no mundo e decide *como* desenhar: visibilidade, ordenação, preparação de comandos de renderização.
- **RHI thread** (*Rendering Hardware Interface*) — traduz esses comandos para a API gráfica concreta (DirectX 12, Vulkan, Metal) e os submete ao driver.
- **GPU** — executa os comandos e produz a imagem.
- **Worker threads** — um conjunto de threads auxiliares que executam tarefas paralelas sob demanda: partes da física, avaliação de animação, áudio, streaming, etc.

Para não deixar ninguém ocioso, esses estágios trabalham **em frames diferentes ao mesmo tempo**:

```text
tempo ──────────────────────────────────────────────────────────►

Game thread    │ Frame N   │ Frame N+1 │ Frame N+2 │ Frame N+3 │
Render thread  │           │ Frame N   │ Frame N+1 │ Frame N+2 │
GPU            │           │           │ Frame N   │ Frame N+1 │
                                         ▲
                                         └─ a imagem do frame N chega à tela
                                            ~2–3 frames depois do input
```

Isso é exatamente um **pipeline de CPU** aplicado ao frame: cada estágio processa um item diferente, e o *throughput* (frames por segundo) é determinado pelo **estágio mais lento**, não pela soma de todos.

Duas consequências práticas, ambas importantes para FPS:

1. **O FPS é limitado pelo gargalo.** Se o game thread leva 10 ms, a render thread 7 ms e a GPU 14 ms, o jogo roda a ~14 ms por frame (≈ 71 FPS) — limitado pela GPU. Otimizar o gameplay nesse caso **não melhora nada**. Saber identificar se um jogo está *game-thread bound*, *render-thread bound* ou *GPU bound* é a primeira pergunta de qualquer investigação de performance (Capítulo 58). O comando `stat unit` da Unreal mostra exatamente esses três tempos lado a lado.
2. **Pipelining compra throughput pagando com latência.** O input do frame N só aparece na tela alguns frames depois. Esse atraso total — do botão apertado ao fóton saindo da tela — é chamado de **input latency** (ou *click-to-photon*), e é uma das coisas que separam um shooter que "parece responsivo" de um que "parece pesado". Engines expõem configurações para reduzir a profundidade do pipeline (na Unreal, por exemplo, a console variable `r.OneFrameThreadLag` controla se a render thread pode ficar um frame atrás do game thread), e existem tecnologias de fabricantes de GPU voltadas especificamente a reduzir essa latência. Quando chegarmos ao Capítulo 25, você vai entender por que jogos competitivos se importam tanto com isso.

> 🌉 **Ponte:** você conhece esse trade-off de sistemas de mensageria: aumentar o tamanho do lote e a profundidade da fila aumenta throughput e aumenta latência. Um pipeline de render com mais frames "em voo" é uma fila mais profunda.
>
> 🧱 **Onde a ponte cai:** em mensageria, latência de centenas de milissegundos costuma ser aceitável. Aqui, cada frame extra de pipeline custa 8–17 ms de latência percebida **pelas mãos do jogador**, e a fila tem profundidade 2 ou 3, não milhares.

### Consequência para o seu código: o game thread é dono do estado de gameplay

Como o render thread trabalha num frame anterior, ele **não pode ler diretamente** os objetos de gameplay — eles já estão sendo alterados pelo frame seguinte. Por isso a Unreal mantém representações separadas: o componente de malha que você manipula no game thread (`UPrimitiveComponent`) tem uma contraparte no render thread (o *scene proxy*), e mudanças são enviadas de um para o outro por comandos enfileirados.

Para você, nos próximos 50 capítulos, a regra prática é simples: **código de gameplay roda no game thread e mexe em objetos de gameplay; não tente acessar o lado do render nem mexer em `UObject`s a partir de outras threads.** Quando precisar de paralelismo (Capítulo 60), a engine oferece mecanismos próprios e seguros.

---

## 2.5 O loop da Unreal Engine

Agora podemos olhar para o game loop real de uma engine de produção. O que segue é uma **visão simplificada** — o código-fonte da Unreal é público (para quem aceita a licença e vincula a conta Epic ao GitHub), e vale a pena navegar por ele no Capítulo 11, mas os detalhes exatos mudam entre versões.

### Do processo ao mundo

```text
main / WinMain (Launch)
   │
   ▼
FEngineLoop::PreInit / Init      inicialização de módulos, engine, primeiro mundo
   │
   ▼
while (!IsEngineExitRequested())
   │
   └─► FEngineLoop::Tick()               (LaunchEngineLoop.cpp)
          │  mensagens da plataforma, input, tempo do frame (Δt)
          │
          ├─► GEngine->Tick(DeltaSeconds)
          │      UGameEngine (jogo empacotado) ou UEditorEngine (editor/PIE)
          │      │
          │      └─► para cada mundo ativo: UWorld::Tick(LEVELTICK_All, Δt)
          │             rede (entrada) · tick groups · timers · câmera · rede (saída)
          │
          ├─► UI (Slate) tick
          ├─► sincronização com o render thread / submissão do frame
          └─► controle de frame rate (limite, vsync)
```

Três observações importantes:

1. **O loop é da engine, não seu.** Você nunca escreve `while (bRunning)` na Unreal. Assim como em Spring você escreve *controllers* e o framework escreve o servidor, na Unreal você escreve **objetos que são chamados pelo loop**. É inversão de controle — mas com o relógio como fonte de eventos.
2. **O mundo (`UWorld`) é a unidade de simulação.** Normalmente há um mundo de jogo ativo. No editor, durante *Play In Editor*, existem o mundo do editor e um ou mais mundos de jogo (um por cliente simulado, no caso de multiplayer em PIE). Isso vai importar na Parte IX.
3. **Δt é calculado uma vez por frame** pela engine e repassado a todos. Ele pode ser modificado por **time dilation** (câmera lenta global ou por ator — Max Payne mandou lembranças; Capítulo 3) e pode ser limitado (*clamp*) para evitar saltos absurdos após uma travada.

### Tick functions e tick groups

Dentro de `UWorld::Tick`, a engine não chama "todos os atores em alguma ordem". Ela usa um sistema mais estruturado:

- Cada objeto que quer ser atualizado registra uma ou mais **tick functions**. Um `AActor` tem uma (`PrimaryActorTick`); cada `UActorComponent` tem a sua (`PrimaryComponentTick`). O seu `Tick()` é chamado através delas.
- Cada tick function pertence a um **tick group**, que define *em que fase do frame* ela roda.
- Dentro de um grupo, a ordem é indefinida — a menos que você declare **pré-requisitos** ("eu só posso rodar depois que aquele ator rodar").
- O gerenciador de ticks (`FTickTaskManager`) monta, a cada frame, um grafo de tarefas respeitando grupos e pré-requisitos, e executa grupo a grupo.

Os tick groups principais, na ordem em que acontecem (enum `ETickingGroup`):

| Tick group | Quando roda | Uso típico |
|---|---|---|
| `TG_PrePhysics` | Antes de a física começar o passo | **Padrão para atores e componentes.** Gameplay que move coisas ou aplica forças: movimento do personagem, IA, armas. |
| `TG_StartPhysics` | Marca o início da simulação física | Interno da engine. |
| `TG_DuringPhysics` | **Em paralelo** com a simulação física | Trabalho que não depende do resultado da física deste frame e não mexe em corpos simulados (ex.: atualizar UI, lógica independente). |
| `TG_EndPhysics` | Marca o fim da física | Interno da engine. |
| `TG_PostPhysics` | Depois da física | Lógica que precisa do resultado da física: reagir a onde um objeto simulado parou, mirar a partir de uma posição já resolvida. |
| `TG_PostUpdateWork` | Depois das atualizações principais (e da câmera) | Trabalho tardio que precisa do estado final do frame. |
| `TG_LastDemotable` | Final do frame | Itens "rebaixados" para o fim. |
| `TG_NewlySpawned` | Pseudo-grupo | Objetos criados durante o frame, que ainda não tinham sido agendados. |

E, de forma simplificada, a sequência dentro de `UWorld::Tick` fica assim:

```text
UWorld::Tick
 ├─ rede: processar pacotes recebidos
 ├─ TG_PrePhysics        ← maior parte do seu código de gameplay
 ├─ TG_StartPhysics      ─┐
 ├─ TG_DuringPhysics      │ física (Chaos) simulando em paralelo
 ├─ TG_EndPhysics        ─┘
 ├─ TG_PostPhysics
 ├─ timers (FTimerManager) e objetos "tickáveis" avulsos
 ├─ atualização das câmeras dos jogadores
 ├─ TG_PostUpdateWork
 ├─ TG_LastDemotable
 └─ rede: replicar estado / enviar pacotes
```

**[SIMPLIFICAÇÃO DIDÁTICA]** A ordem exata de alguns itens (timers, câmeras, objetos tickáveis avulsos, tarefas de streaming) é um detalhe de implementação que pode variar entre versões. O que você deve memorizar é a estrutura: **pré-física → física → pós-física → câmera → trabalho tardio**, com a rede nas pontas.

### As ferramentas que você tem sobre o tick

```cpp
// No construtor do Actor:
PrimaryActorTick.bCanEverTick = true;           // este ator PODE tickar (se false, nunca)
PrimaryActorTick.bStartWithTickEnabled = false; // começa desligado; liga quando precisar
PrimaryActorTick.TickGroup = TG_PostPhysics;    // em que fase do frame
PrimaryActorTick.TickInterval = 0.2f;           // no máximo 5x por segundo (0 = todo frame)

// Em tempo de execução:
SetActorTickEnabled(true);                      // liga/desliga
SetActorTickInterval(0.5f);                     // muda a frequência
SetTickGroup(TG_PrePhysics);                    // muda a fase
AddTickPrerequisiteActor(OtherActor);           // só rodo depois de OtherActor
```

Componentes têm equivalentes (`PrimaryComponentTick`, `SetComponentTickEnabled`, `AddTickPrerequisiteComponent`, etc.).

Repare em `bCanEverTick`: por padrão, um `AActor` criado a partir do template de C++ da Unreal costuma vir com tick ligado. **Desligar o tick de tudo que não precisa dele é uma das otimizações mais baratas e eficazes que existem** — lembre-se das 80 portas da usina.

---

## 2.6 Tick, timers e eventos: três formas de fazer algo acontecer no tempo

Em backend, você tem três ferramentas para "fazer algo acontecer": responder a uma requisição/mensagem (evento), agendar um job (cron/scheduler) e, raramente, *polling*. Em jogos, as mesmas três existem, com pesos diferentes:

### Tick (atualização contínua)

Executar código **todo frame** (ou a cada intervalo de tick). É a ferramenta certa quando algo **muda continuamente** com o tempo e precisa ser visualmente suave:

- movimento, rotação, interpolação (a porta abrindo);
- câmera, mira, recoil;
- um valor que decai ou se acumula com o tempo (o escudo de escuridão do Capítulo 1);
- verificações que precisam de resposta imediata (o inimigo está no cone da lanterna?).

### Timer (execução agendada)

Executar código **depois de um tempo**, uma vez ou de forma repetida, sem pagar custo a cada frame enquanto isso:

```cpp
// Recarregar a arma em 2,1 s
GetWorldTimerManager().SetTimer(
    ReloadTimerHandle, this, &AVGWeapon::FinishReload, 2.1f, /*bLoop=*/false);

// Checar a cada 0,25 s se o jogador está perto (mais barato que todo frame)
GetWorldTimerManager().SetTimer(
    ProximityTimerHandle, this, &AVGProximitySensor::CheckPlayer, 0.25f, /*bLoop=*/true);
```

Ferramenta certa para atrasos discretos (recarga, *cooldown*, respawn, uma luz que se apaga 3 segundos depois de um evento) e para verificações periódicas que não precisam de precisão de frame. Timers são tempo de **jogo**: respeitam pausa e time dilation.

### Evento (reação)

Executar código **quando algo acontece**: o jogador entrou num volume (*overlap*), um projétil bateu em algo (*hit*), um botão foi pressionado, a vida chegou a zero, uma porta terminou de abrir. Na Unreal, eventos chegam por funções virtuais (`NotifyActorBeginOverlap`), por **delegates** (o `OnDoorOpened.Broadcast()` do Capítulo 1) e pelo sistema de input. Não custam nada enquanto não acontecem.

### Como escolher

```text
A coisa muda continuamente e precisa ser suave?          → Tick
   └─ precisa de cada frame?  não → Tick com TickInterval, ou Timer em loop
A coisa acontece depois de um tempo conhecido?            → Timer
A coisa acontece em resposta a algo identificável?        → Evento
A coisa só precisa rodar enquanto um estado durar?        → Tick ligado SÓ nesse estado
```

A última linha é a mais importante e a mais esquecida: **Tick não é "sempre ligado ou sempre desligado"**. A porta do Capítulo 1 liga o tick ao começar a abrir e desliga ao terminar. Um inimigo pode tickar a cada frame quando está perseguindo o jogador e a cada meio segundo quando está patrulhando longe dele. Esse padrão — *tick proporcional à relevância* — é a semente do conceito de *significance* que veremos no Capítulo 60.

> 🌉 **Ponte:** tick ≈ *polling*, timer ≈ *scheduler*, evento ≈ *message consumer*. A diferença de peso é cultural: em backend, *polling* é quase sempre um *code smell*. Em jogos, ele é a ferramenta **padrão** para tudo que é contínuo — porque o laço já está rodando de qualquer jeito, e a pergunta "o inimigo me vê?" muda de resposta a cada frame. Transformar isso em eventos ("avise quando o inimigo começar a me ver") só desloca o polling para outro lugar.

---

## Comparação com o desenvolvimento tradicional

Três modelos que você conhece se parecem com o game loop. Vale comparar com precisão.

**1. Event loop de servidor (Node.js, Netty, Vert.x).**
Semelhança: uma thread executa a lógica, sem locks, enquanto I/O e trabalho pesado rodam em outro lugar. Diferença decisiva: o event loop **dorme** sem eventos e acorda por I/O; o game loop **roda continuamente** e é ritmado pelo relógio e pela tela. Num servidor, um callback demorado atrasa *outras requisições*; num jogo, um tick demorado atrasa *o mundo inteiro*, para todo mundo, visivelmente.

**2. Reconciliation loop de um controller Kubernetes.**
Esta é, curiosamente, a analogia que mais se aproxima do *espírito* do gameplay: um laço que, repetidamente, observa o estado atual, compara com o desejado e age para convergir. Uma IA de inimigo faz algo muito parecido — "onde estou, onde o jogador está, o que devo fazer para chegar lá?" — a cada atualização. Diferença: o reconciliador roda em escala de segundos, tolera atrasos e é idempotente por projeto; o tick de jogo roda em milissegundos, tem prazo e frequentemente **não** é idempotente (aplicar dano duas vezes é um bug).

**3. Pipeline de processamento em estágios.**
Como discutido em 2.4, o frame distribuído entre game thread, render thread e GPU é literalmente um pipeline com throughput limitado pelo estágio mais lento e latência proporcional à profundidade. Essa analogia funciona muito bem e vale manter.

O que **não** tem paralelo no seu mundo: um sistema em que *toda a lógica de negócio* roda dentro de um único laço com prazo de 16 ms, sem requisição, sem fila, sem retry, e em que o resultado é avaliado pela suavidade com que um ser humano o percebe.

---

## Exemplo e implementação

### Parte A — um game loop do zero (C++ padrão, fora da Unreal)

Antes de usar o loop da engine, vale escrever um. O programa abaixo simula duas "bolas" se movendo: uma usando a regra errada (andar uma quantidade fixa por frame) e outra usando a regra certa (andar proporcionalmente ao Δt). O custo de cada frame é simulado com uma espera configurável, para imitar uma máquina rápida ou lenta.

```cpp
// game_loop.cpp — compile com: g++ -std=c++20 -O2 game_loop.cpp -o game_loop
// (ou crie um projeto "Console App" no Visual Studio)
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <thread>

using Clock = std::chrono::steady_clock;

struct Ball
{
    double X = 0.0;
};

int main(int argc, char** argv)
{
    // Custo simulado de um frame, em ms. 16 ≈ máquina a 60 FPS; 33 ≈ 30 FPS.
    const int SimulatedFrameMs = (argc > 1) ? std::atoi(argv[1]) : 16;
    const double SpeedPerSecond = 5.0;    // unidades por segundo
    const double StepPerFrame   = 0.083;  // "calibrado" para 60 FPS — o erro clássico

    Ball PerFrameBall;   // move por frame (errado)
    Ball PerSecondBall;  // move por Δt (certo)

    const auto Start = Clock::now();
    auto Previous = Start;
    long long Frame = 0;

    while (true)
    {
        // --- Tempo ---------------------------------------------------------
        const auto Now = Clock::now();
        const double Dt = std::chrono::duration<double>(Now - Previous).count();
        const double Elapsed = std::chrono::duration<double>(Now - Start).count();
        Previous = Now;

        // --- Input (não bloqueante) ----------------------------------------
        // Num jogo real: drenar a fila de eventos do SO aqui.

        // --- Update --------------------------------------------------------
        PerFrameBall.X  += StepPerFrame;          // depende do FPS
        PerSecondBall.X += SpeedPerSecond * Dt;   // depende do tempo

        // --- "Render" ------------------------------------------------------
        if (++Frame % 20 == 0)
        {
            std::printf("t=%5.2fs  frame=%4lld  dt=%6.2fms  porFrame=%6.2f  porSegundo=%6.2f\n",
                        Elapsed, Frame, Dt * 1000.0, PerFrameBall.X, PerSecondBall.X);
        }

        if (Elapsed >= 3.0)
        {
            break;
        }

        // --- Custo simulado do frame -----------------------------------------
        std::this_thread::sleep_for(std::chrono::milliseconds(SimulatedFrameMs));
    }

    std::printf("\nApós ~3s: porFrame=%.2f  porSegundo=%.2f (esperado ~15.00)\n",
                PerFrameBall.X, PerSecondBall.X);
    return 0;
}
```

Rode com `16` e com `33`. A bola "por segundo" chega a aproximadamente 15 unidades nos dois casos. A bola "por frame" chega a ~15 só na máquina "rápida" — e a cerca da metade disso na "lenta". Esse é o bug do folclore dos jogos que aceleravam em PCs novos, reproduzido em 50 linhas.

Note também a estrutura do laço: **tempo → input → update → render**. Você vai reconhecer exatamente essa estrutura no `FEngineLoop::Tick`.

> Se preferir, escreva a mesma coisa em Java com `System.nanoTime()`. O objetivo é o modelo mental, não a linguagem — mas, se puder, faça em C++: é um primeiro contato de baixo risco com a linguagem que você usará a partir do Capítulo 11.

### Parte B — observando o loop da Unreal

Este exercício exige um projeto Unreal C++. Se ainda não criou o projeto `Vigilia`, você pode fazê-lo agora (Unreal Editor → *Games* → *Blank* → **C++**, nome `Vigilia`) ou voltar a esta parte depois do Capítulo 7, que explica a criação do projeto em detalhe.

O ator abaixo, `AVGTickProbe`, existe apenas para **observar** o loop: ele registra no log o número do frame, o seu tick group e o Δt. Colocando vários deles no nível com configurações diferentes, você vê a ordem de execução real.

```cpp
// Source/Vigilia/Debug/VGTickProbe.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGTickProbe.generated.h"

/**
 * Ator de diagnóstico: registra no log quando e em que tick group ele é atualizado.
 * Não tem função de gameplay; existe para tornar o game loop observável.
 */
UCLASS()
class VIGILIA_API AVGTickProbe : public AActor
{
    GENERATED_BODY()

public:
    AVGTickProbe();

    virtual void Tick(float DeltaSeconds) override;

protected:
    virtual void BeginPlay() override;

    /** Fase do frame em que este probe roda. */
    UPROPERTY(EditAnywhere, Category = "Tick Probe")
    TEnumAsByte<ETickingGroup> ProbeTickGroup = TG_PrePhysics;

    /** Se definido, este probe só tica depois do ator indicado (pré-requisito). */
    UPROPERTY(EditInstanceOnly, Category = "Tick Probe")
    TObjectPtr<AActor> TickAfter;

    /** Quantos frames registrar antes de silenciar (evita inundar o log). */
    UPROPERTY(EditAnywhere, Category = "Tick Probe", meta = (ClampMin = "1"))
    int32 FramesToLog = 5;

private:
    int32 LoggedFrames = 0;
};
```

```cpp
// Source/Vigilia/Debug/VGTickProbe.cpp
#include "Debug/VGTickProbe.h"

DEFINE_LOG_CATEGORY_STATIC(LogVGTick, Log, All);

AVGTickProbe::AVGTickProbe()
{
    PrimaryActorTick.bCanEverTick = true;
}

void AVGTickProbe::BeginPlay()
{
    Super::BeginPlay();

    // A configuração editada no nível é aplicada ao registrar o tick.
    SetTickGroup(ProbeTickGroup);

    if (TickAfter)
    {
        AddTickPrerequisiteActor(TickAfter);
    }
}

void AVGTickProbe::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (LoggedFrames >= FramesToLog)
    {
        SetActorTickEnabled(false); // terminou de observar: não pague mais custo por frame
        return;
    }
    ++LoggedFrames;

    UE_LOG(LogVGTick, Log, TEXT("[Frame %llu] %-20s group=%-18s dt=%.2f ms"),
        GFrameCounter,
        *GetActorNameOrLabel(),
        *UEnum::GetValueAsString(ProbeTickGroup.GetValue()),
        DeltaSeconds * 1000.0f);
}
```

**Explicação do código:**

- `UCLASS()`, `GENERATED_BODY()`, `UPROPERTY(...)` e o include `VGTickProbe.generated.h` fazem parte do sistema de reflexão da Unreal. Eles tornam a classe visível para o editor e para o Blueprint, e permitem editar `ProbeTickGroup`, `TickAfter` e `FramesToLog` no painel de detalhes. O Capítulo 11 explica a mecânica; por enquanto, aceite-os como "anotações que geram código".
- `VIGILIA_API` é a macro de exportação do módulo `Vigilia` (gerada com o projeto).
- `TObjectPtr<AActor>` é o tipo recomendado no UE5 para referências a `UObject`s em propriedades. `EditInstanceOnly` permite escolher o ator apenas nas instâncias colocadas no nível — não faz sentido um valor padrão de classe apontar para um ator específico de um mapa.
- `SetTickGroup` e `AddTickPrerequisiteActor` são as ferramentas da seção 2.5.
- `GFrameCounter` é um contador global de frames da engine: é o que permite ver que vários probes rodaram **no mesmo frame**.
- `GetActorNameOrLabel()` devolve o rótulo que você vê no *Outliner* (`Probe_A`) em builds com editor, e o nome do objeto fora delas. `GetName()` devolveria o nome interno gerado pela engine, que **não muda** quando você renomeia o ator no Outliner — e o log não bateria com a tabela abaixo.
- `DEFINE_LOG_CATEGORY_STATIC` cria uma categoria de log própria (`LogVGTick`), que você pode filtrar no *Output Log*. Usar `LogTemp` para tudo é um hábito ruim que fica caro quando o projeto cresce.
- Desligar o tick ao terminar de logar é o princípio "tick só enquanto for útil", aplicado até num ator de debug.

**Como usar:** compile, abra um nível vazio, arraste três `VGTickProbe` para a cena, renomeie-os no *Outliner* e configure:

| Instância | ProbeTickGroup | TickAfter |
|---|---|---|
| `Probe_A` | `TG_PostPhysics` | — |
| `Probe_B` | `TG_PrePhysics` | `Probe_C` |
| `Probe_C` | `TG_PrePhysics` | — |

Dê *Play* e abra o *Output Log* filtrando por `LogVGTick`. Em cada frame, você deve ver `Probe_C` antes de `Probe_B` (pré-requisito) e ambos antes de `Probe_A` (grupo posterior), todos com o mesmo número de frame.

---

## Decisões arquiteturais

1. **Não escrevemos nosso próprio loop na Unreal.** A engine é dona do loop; nosso código é composto de objetos que ele chama. Isso é inversão de controle consciente, e tentar contorná-la (por exemplo, um "gerenciador central" que chama manualmente o update de todos os objetos do jogo) quase sempre é pior do que usar tick groups e pré-requisitos.
2. **`TG_PrePhysics` é o padrão; mudar de grupo exige motivo.** Use `TG_PostPhysics` quando o código depende do resultado da física; `TG_DuringPhysics` para trabalho independente; `TG_PostUpdateWork` para o que precisa do estado final do frame.
3. **Pré-requisitos em vez de suposições de ordem.** Se A precisa rodar depois de B no mesmo grupo, declare. Ordem implícita dentro de um grupo funciona "por acaso" até o dia em que deixa de funcionar.
4. **Tick só enquanto for útil.** Todo ator e componente do projeto Vigília começa com a pergunta: precisa tickar? Se sim, sempre? Em que frequência?
5. **Timers para atrasos, eventos para reações, tick para continuidade.** A tabela da seção 2.6 vale como regra do projeto.

---

## Armadilhas

- **Lógica dependente de frame.** Qualquer `X += constante` dentro de `Tick` sem multiplicar por `DeltaSeconds` é um bug esperando uma máquina diferente para aparecer.
- **Tick em tudo.** Centenas de atores com tick ligado e vazio (ou quase vazio) custam tempo de game thread a cada frame — especialmente em Blueprint, onde cada evento de tick tem um custo de execução da máquina virtual. Desligue o que não precisa.
- **Depender da ordem dentro de um grupo.** "Funciona na minha máquina" com dois atores no mesmo tick group, sem pré-requisito, é um bug de ordem latente.
- **Câmera ou objeto acoplado atualizado antes do alvo.** Produz o tremor de um frame descrito em 2.3. A causa é quase sempre ordem de tick.
- **Trabalho pesado no tick.** Buscas no mundo inteiro (`GetAllActorsOfClass`), alocações grandes, *traces* complexos para muitos objetos — a cada frame. Faça uma vez, guarde o resultado, ou use timers.
- **Confundir tempo real e tempo de jogo.** Timers e `DeltaSeconds` respeitam pausa e time dilation; o relógio do sistema não. Usar o relógio do sistema para lógica de jogo quebra pausa e câmera lenta.
- **Tocar em `UObject`s de outras threads.** O estado de gameplay pertence ao game thread. Paralelismo tem regras próprias (Capítulo 60).

---

## Exercício

**Parte 1 — o loop do zero (1–1,5 h).**
Compile e rode o `game_loop.cpp` com custos de frame de 8, 16, 33 e 100 ms. Registre, para cada caso, as posições finais das duas bolas. Depois:

1. Adicione uma terceira bola que se move com Δt, mas cujo Δt é **limitado** a no máximo 50 ms (`std::min(Dt, 0.05)`). Rode com 100 ms. O que acontece com ela em relação ao tempo real? Por que uma engine faria isso? *(Pense no que acontece com um projétil depois de uma travada de 2 segundos.)*
2. Adicione, a cada 40 frames, um frame "pesado" que dorme 200 ms. Observe o Δt desse frame e o salto da bola. Anote: esse é o problema que o Capítulo 3 resolve.

**Parte 2 — o loop da Unreal (1–1,5 h).**
Crie o `AVGTickProbe`, monte a configuração da tabela acima e confirme a ordem no log. Em seguida:

1. Troque `Probe_A` para `TG_DuringPhysics`. Sua posição relativa no log muda?
2. Defina `TickInterval = 0.5` em um dos probes (via `PrimaryActorTick.TickInterval` no construtor, ou criando uma propriedade editável e aplicando com `SetActorTickInterval` no `BeginPlay`). Observe o Δt que ele recebe. O que isso diz sobre como timers e intervalos de tick acumulam tempo?
3. Rode o comando de console `stat unit` durante o PIE e identifique os tempos de `Game`, `Draw` e `GPU`. Qual deles é o gargalo num nível vazio?

Registre no `DEVLOG.md` o que observou.

---

## Desafio — o tremor de um frame

Crie dois atores:

- `AVGMover`: move-se em círculo pelo nível, rapidamente, no seu `Tick` (posição = centro + raio × (cos(t), sin(t))).
- `AVGFollower`: a cada tick, posiciona-se exatamente 100 unidades acima do `AVGMover`.

Coloque uma câmera ou um mesh visível no `AVGFollower` e observe. Dependendo da ordem em que os dois tickam, o seguidor ora acompanha perfeitamente, ora fica **um frame atrasado** — o que aparece como um tremor ou como um "rastro" relativo ao alvo.

1. Force o problema: faça o seguidor tickar *antes* do alvo (pré-requisito invertido ou grupo anterior) e observe o atraso.
2. Corrija de três formas diferentes: (a) pré-requisito de tick; (b) tick group posterior; (c) sem tick nenhum, anexando o seguidor ao alvo como filho na hierarquia de componentes (`AttachToActor`).
3. Compare as três soluções em termos de custo por frame, acoplamento e clareza. Qual você usaria para uma arma presa à mão do personagem? E para uma câmera que segue o jogador com suavização?

Esse é o seu primeiro problema real de arquitetura de jogos: **um bug que não está em nenhuma linha de código, e sim na ordem em que as linhas rodam.**

---

## Uso de IA

1. **Para ler o código-fonte da engine com um guia:**
   > "Estou estudando o game loop da Unreal Engine 5. Explique o papel de `FEngineLoop::Tick`, `UGameEngine::Tick` e `UWorld::Tick`, e como o `FTickTaskManager` executa os tick groups. Indique os arquivos onde eu deveria procurar no código-fonte e diga explicitamente quando não tiver certeza de um detalhe ou quando ele puder variar entre versões da engine."
   *(Depois, abra os arquivos e confira. IAs frequentemente erram nomes de funções internas ou misturam versões.)*

2. **Para revisar seu loop standalone:**
   > "Escrevi este game loop em C++ (abaixo). Revise como um programador de engine: identifique problemas de precisão de tempo, comportamento após travadas longas, uso do relógio e o que faltaria para separar a simulação da renderização com passo fixo. Não reescreva o código inteiro; aponte os problemas e explique."

3. **Para treinar decisões de tick:**
   > "Para cada um destes comportamentos de um jogo de terror em primeira pessoa, diga se você usaria Tick (todo frame), Tick com intervalo, Timer ou Evento, e justifique em termos de custo e responsividade: lanterna oscilando; bateria da lanterna descarregando; inimigo verificando se vê o jogador; porta abrindo; luz que apaga 3 segundos após o jogador entrar numa sala; legenda de uma fala de rádio; atualização da barra de vida na HUD."
   *(Responda você primeiro; depois compare.)*

4. **Para diagnosticar o desafio:**
   > "Na Unreal, tenho um ator que segue outro ator a cada tick, e ele aparece com um tremor sutil. Liste as causas possíveis relacionadas a ordem de tick, tick groups, anexação de componentes e atualização de câmera, e como verificar cada uma."

---

## Checklist

- [ ] Sei explicar por que um jogo em tempo real não pode bloquear esperando input.
- [ ] Consigo descrever as fases de um frame e justificar a ordem: input → gameplay → física → pós-física → animação → câmera → render.
- [ ] Entendo o que é pipelining entre game thread, render thread e GPU, e por que ele aumenta a latência de input.
- [ ] Sei o que `stat unit` mostra e o que significa um jogo ser *GPU bound* ou *game-thread bound*.
- [ ] Sei o caminho simplificado `FEngineLoop::Tick → UEngine::Tick → UWorld::Tick → tick groups`.
- [ ] Conheço os tick groups principais e quando usar cada um.
- [ ] Sei configurar `bCanEverTick`, `TickInterval`, tick group e pré-requisitos.
- [ ] Sei escolher entre Tick, Timer e Evento para um comportamento.
- [ ] Reproduzi o bug do movimento dependente de frame e o tremor de um frame de atraso.

---

## Para ir além

- **Robert Nystrom, *Game Programming Patterns*, capítulo "Game Loop"** (gameprogrammingpatterns.com) — a melhor introdução curta ao padrão e às variantes de controle de tempo.
- **Glenn Fiedler, "Fix Your Timestep!"** (Gaffer On Games) — leitura obrigatória antes do Capítulo 3.
- **Documentação oficial da Unreal: "Actor Ticking"** (dev.epicgames.com/documentation) — tick groups, pré-requisitos e configurações de tick.
- **Jason Gregory, *Game Engine Architecture*** — o capítulo sobre o game loop e o tempo real cobre em profundidade as variantes de loop e o pipelining entre CPU e GPU.

---

➡️ **Próximo:** [Capítulo 3 — Frames, Delta Time e Update](cap-03-frames-delta-time-update.md)

# Capítulo 59 — Profiling

## Objetivo

Ao final deste capítulo você deve conseguir:

- seguir um método de profiling: reproduzir, medir, localizar de cima para baixo, formular uma hipótese, mudar **uma** coisa, medir de novo e registrar;
- usar os comandos `stat` certos para cada pergunta (`unit`, `unitgraph`, `fps`, `game`, `gpu`, `scenerendering`, `initviews` e outros) e saber o que cada um custa;
- gravar um *trace* e lê-lo no **Unreal Insights**: frames, trilhas por thread, *timers*, chamadores e marcadores;
- investigar a GPU com `stat gpu`, `ProfileGPU` e os modos de visualização, e saber quando sair para uma ferramenta externa;
- caçar *hitches*: coleta de lixo, carregamento, compilação de *shaders*, picos de IA;
- fazer o profiling de um trecho real da Vigília, a **caçada no corredor**, e transformar o resultado em hipóteses para o Capítulo 60.

---

## Contexto

O Capítulo 58 terminou com uma linha de base: algumas linhas `PERF ...` no `DEVLOG.md`, uma por cenário, com média, percentis e o estágio que limita. Ela diz **que** o corredor estoura o orçamento e **qual estágio** está estourando. Não diz **por quê**.

O livro adiou essa pergunta várias vezes:

- o Capítulo 12 disse que "o Unreal Insights (Capítulo 59) mostra quais Blueprints custam";
- o Capítulo 32 pediu para medir o pool "com `stat game`, `stat unit` e, se quiser, o Unreal Insights";
- o Capítulo 42 pôs no checklist que a IA, com quatro vigias e a Presença, custa menos de 1 ms, "meça com `stat` e o Unreal Insights";
- o Interlúdio II pede `stat game` e `stat unit` para medir a população do quarteirão.

Este capítulo dá o método e as ferramentas, e faz o profiling do pior cenário que a Vigília já tem: a Presença caçando no corredor da Casa de Força, com a lanterna acesa, as lâmpadas piscando e o Diretor no pico.

---

## 59.1 Método antes de ferramenta

O erro mais comum em profiling não é usar a ferramenta errada. É **otimizar sem medir**: ter um palpite ("deve ser a IA"), mudar três coisas, sentir que ficou mais rápido e seguir em frente. Às vezes o palpite está certo; quase sempre, as três mudanças misturam um ganho, um efeito nulo e uma regressão que só aparece semanas depois.

O ciclo:

```text
  1. REPRODUZIR   um cenário fixo: mesmo build, mesmo lugar, mesma câmera, mesmas configurações
       │
  2. MEDIR        a linha de base (VGPerfCapture, três vezes; use a mediana)
       │
  3. LOCALIZAR    de cima para baixo: frame → estágio → sistema → função
       │
  4. HIPÓTESE     escrita ANTES da mudança: "se X, ao fazer Y, Z cai cerca de N ms"
       │
  5. UMA MUDANÇA  só uma
       │
  6. MEDIR        de novo, do mesmo jeito
       │
  7. REGISTRAR    no DEVLOG: hipótese, mudança, antes, depois, decisão (manter ou reverter)
       └────────► volta ao 3 com o próximo gargalo
```

Três detalhes fazem a diferença entre medir e se enganar:

- **Reprodutibilidade.** O mesmo cenário em configurações diferentes não é o mesmo cenário. Fixe e registre: configuração de build (*Development* em *Standalone* para investigar; *Test* para números próximos do produto, Capítulo 62), resolução, preset de qualidade, VSync desligado, cache de *shaders* quente ou frio (e diga qual). A IA da Presença não é determinística, por isso cada medição é repetida três vezes e você usa a mediana.
- **De cima para baixo.** Não abra o Insights procurando "o que está lento". Comece pelo frame (`stat unit`), escolha o estágio, depois o sistema, e só então a função. Cada passo descarta a maior parte do espaço de busca.
- **Efeito do observador.** Toda ferramenta custa: desenhar o `stat` na tela custa, gravar um *trace* custa, e o build *Development* tem *checks* e *stats* que o *Shipping* não tem. Compare sempre medições feitas do **mesmo** jeito, e desconfie de ganhos menores que a variação entre as três repetições.

> 🌉 **Ponte:** é o profiling que você faz em serviços: um APM para achar o *endpoint* lento, um *profiler* de amostragem (pprof, async-profiler) para achar a função, *flame graphs* para ver a pilha.
>
> 🧱 **Onde a ponte cai:** num serviço, a unidade é a requisição, e a média por *endpoint* faz sentido. Num jogo, a unidade é o **frame**, e o que importa é o frame ruim: um *profiler* de amostragem que agrega minutos de execução apaga o pico de um frame que a jogadora viu. Por isso as ferramentas de jogos são organizadas em **linha do tempo por frame**, com escopos instrumentados, e não em agregados.

---

## 59.2 Os comandos `stat`

Os `stat` são o primeiro instrumento: baratos, na tela, sem preparação. Cada um responde a uma pergunta.

| Comando | Pergunta que responde | O que olhar |
|---|---|---|
| `stat unit` | Qual estágio limita o frame? | `Frame`, `Game`, `Draw`, `RHIT`, `GPU` (Cap. 58) |
| `stat unitgraph` | Como o tempo varia ao longo do tempo? | Picos isolados (*hitches*) e serrilhados periódicos |
| `stat fps` | Qual o FPS e o tempo de frame agora? | Só para referência rápida |
| `stat game` | Quanto custa o tick do mundo? | Tempo de tick por grupo, de atores e componentes, de navegação e de IA |
| `stat Vigilia` | Quanto custam os sistemas da Vigília? | Os escopos do Cap. 58 e o contador de *flicker* |
| `stat gpu` | Quanto custa cada passo da GPU? | Sombras, base pass, Lumen, translucidez, pós-processo |
| `stat scenerendering` | Quanto o render thread está trabalhando? | Chamadas de desenho, luzes, tempo de montagem da cena |
| `stat initviews` | Quanto custa decidir o que é visível? | Primitivas processadas, ocluídas, tempo de *culling* |
| `stat rhi` | O que chega à API gráfica? | Chamadas de desenho e triângulos por frame |
| `stat anim` | Quanto custa a animação? | Avaliação de *Animation Blueprints*, *workers* |
| `stat ai`, `stat navigation` | Quanto custam IA e navegação? | Tick de controladores, BTs, consultas de caminho |
| `stat physics`, `stat collision` | Quanto custam física e consultas de colisão? | Corpos simulados, *traces* por frame |
| `stat memory`, `stat streaming`, `stat levels` | Memória e *streaming* | Uso por categoria, *pool* de texturas, estado dos subníveis |
| `stat dumphitches` | Por que aquele frame travou? | Escreve no log os *stats* dos frames acima de um limite |
| `stat none` | — | Desliga tudo |

⚠️ Alguns grupos mudam de nome ou de conteúdo entre versões, e alguns só mostram dados em certas configurações (estatísticas de GPU, por exemplo, dependem do suporte da plataforma). Se um `stat` aparece vazio, confira a documentação da sua versão antes de concluir que o custo é zero.

Duas regras de uso:

- **Um ou dois de cada vez.** Vários `stat` ligados ao mesmo tempo custam desenho e cobrem a tela. Use `stat unit` sempre, mais o da pergunta do momento.
- **`stat` dá números agregados por frame, não causas.** `stat game` diz que o tick do mundo custa 6 ms, mas não diz qual ator. Para isso, vá ao Insights.

---

## 59.3 Unreal Insights

O **Unreal Insights** é a ferramenta de análise de desempenho da Unreal 5. O jogo emite um ***trace***, um fluxo de eventos com marcação de tempo (escopos de CPU, frames, logs, marcadores, memória, rede), e o Insights o lê, ao vivo ou depois, numa linha do tempo.

### Gravar

Há três jeitos de gravar, e todos produzem um arquivo `.utrace`:

- **Pela linha de comando**, desde o início: `-trace=default` (os canais padrão: CPU, GPU, frames, log e marcadores; ⚠️ confira a composição na sua versão) ou uma lista explícita, como `-trace=cpu,gpu,frame,log,bookmark`. Acrescente `-statnamedevents` para que os escopos de *stats* (os `SCOPE_CYCLE_COUNTER` do Capítulo 58) apareçam como eventos nomeados na linha do tempo. O destino é `-tracehost=127.0.0.1` (o servidor de *trace* local, que guarda as sessões para o Insights) ou `-tracefile=<caminho>`.
- **Pelo console, durante o jogo:** `Trace.Start` (com canais), `Trace.Stop` e `Trace.Bookmark <nome>`. Útil para gravar só o trecho que interessa.
- **Pelo editor:** a barra de status do editor tem um controle de *trace* em versões recentes (⚠️ a localização muda entre versões).

O executável do Insights fica em `Engine/Binaries/Win64/UnrealInsights.exe`, e também abre pelo menu de ferramentas do editor.

### Ler: Timing Insights

A janela principal de análise de tempo tem quatro peças que você vai usar sempre:

```text
 ┌ FRAMES ────────────────────────────────────────────────────────────────┐
 │ ▁▁▂▁▁▁▁▂▁▁▁█▁▁▁▂▁▁▁▁▁▂▁▁   um gráfico de barras: cada barra é um frame   │
 └────────────────────────────── clique no pico → a linha do tempo vai lá ┘
 ┌ TIMING VIEW ───────────────────────────────────────────────────────────┐
 │ GameThread   [FrameTime                                            ]   │
 │                [WorldTick          ][Slate]                            │
 │                  [TickActors][AI][Anim][Vigilia: Awareness Tick]       │
 │ RenderThread [  InitViews  ][  RenderShadows  ][ BasePass ]            │
 │ RHIThread         [ submit ]                                           │
 │ GPU                [ Shadows ][ Lumen    ][Base][Transl][Post]         │
 │ Workers         [anim eval][anim eval]     [physics]                   │
 │ ┆ Bookmark: "Director: Peak"                                           │
 └────────────────────────────────────────────────────────────────────────┘
 ┌ TIMERS ──────────────────────┐  ┌ CALLERS / CALLEES ─────────────────┐
 │ nome     incl.  excl.  vezes │  │ quem chamou o escopo selecionado,  │
 │ (agregado sobre a seleção)   │  │ e o que ele chama                  │
 └──────────────────────────────┘  └────────────────────────────────────┘
```

O fluxo de investigação:

1. No painel **Frames**, encontre um frame ruim (um pico) e um frame típico.
2. Na **Timing View**, compare os dois. Qual trilha está mais longa no frame ruim? Dentro dela, qual escopo cresceu?
3. Selecione um intervalo (vários frames) e olhe o painel **Timers**, ordenado por tempo **exclusivo** (o tempo do próprio escopo, sem os filhos). O tempo **inclusivo** diz onde o tempo passa; o exclusivo diz quem o gasta.
4. Use **Callers/Callees** para subir até quem chamou: um `LineTraceSingle` caro não é o problema; o sistema que o chama quarenta vezes por frame é.
5. **Marcadores** (*bookmarks*) aparecem como linhas verticais. Com eles, você acha "o momento em que o Diretor entrou em `Peak`" sem procurar.

### Instrumentar o próprio código

A engine já instrumenta muito do que importa (tick, render, animação, física, IA). No seu código, três ferramentas:

- **`TRACE_CPUPROFILER_EVENT_SCOPE(Nome)`**: um escopo nomeado no *trace* de CPU, sempre que o canal `cpu` está ligado. É o equivalente do `SCOPE_CYCLE_COUNTER` sem o sistema de *stats*.
- **Os *stats* do Capítulo 58**, que aparecem no *trace* com `-statnamedevents`. A Vigília fica com eles: um escopo serve ao `stat Vigilia` e ao Insights.
- **`TRACE_BOOKMARK(TEXT("formato"), ...)`**: um marcador na linha do tempo, para momentos de gameplay.

Blueprints aparecem no *trace* com mais detalhe quando os eventos nomeados estão ligados (`-statnamedevents`); é assim que se responde à pergunta do Capítulo 12 sobre **quais** Blueprints custam (⚠️ o nível de detalhe por nó varia entre versões).

### As outras janelas

- **Memory Insights**: alocações ao longo do tempo, por *tag* de memória e pilha de chamadas (requer o canal de memória ligado desde o início do processo; ⚠️ confira o nome do canal na sua versão).
- **Networking Insights**: pacotes, replicação, RPCs. É a ferramenta da Parte IX.

---

## 59.4 A GPU

O `stat unit` diz se a GPU é o gargalo. Para saber **onde** dentro dela:

- **`stat gpu`**: o tempo de cada passo principal da GPU, atualizado na tela. É o primeiro olhar: sombras, Lumen, *base pass*, translucidez, pós-processo.
- **`ProfileGPU`** (atalho Ctrl+Shift+vírgula): captura **um** frame e mostra a árvore completa de passos com tempos. No editor, abre o *GPU Visualizer*; num jogo sem editor, escreve no log (⚠️ a ferramenta de profiling de GPU mudou em versões recentes, com tempos de GPU também no Insights; confira qual caminho a sua versão usa).
- **Modos de visualização** (menu *View Mode* do *viewport*, ou `viewmode` no console): *Shader Complexity* (quão caro é o material de cada pixel), *Light Complexity* (quantas luzes afetam cada pixel), *Quad Overdraw* (quanto se desenha por cima do mesmo pixel, o problema clássico de translucidez), e as visualizações de Lumen e Nanite.
- ***Show flags*** para experimentos de A/B: desligar uma categoria inteira (`ShowFlag.Particles 0`, `ShowFlag.DynamicShadows 0`) e medir de novo responde "quanto isto custa?" em segundos. Não é otimização; é diagnóstico.
- **Ferramentas externas**, quando a pergunta é sobre um *draw call* específico: RenderDoc (há um *plugin* na engine), PIX no Windows e as ferramentas dos fabricantes de GPU. Elas mostram o frame chamada por chamada, com estado e recursos.

---

## 59.5 *Hitches*: o frame que a jogadora lembra

Um *hitch* é um frame isolado muito acima do orçamento. Ele quase nunca tem a mesma causa que o custo médio, e por isso merece uma caçada própria:

| Causa | Como aparece | Onde confirmar |
|---|---|---|
| Coleta de lixo | Pico periódico, intervalo regular | Escopo de coleta de lixo no game thread (Insights) |
| Carregamento síncrono | Pico ao entrar numa sala ou disparar algo pela primeira vez | Escopos de carregamento de pacote; `LoadSynchronous` no seu código |
| Compilação de *shaders* (PSO) | Pico na **primeira** vez que um material aparece | Some na segunda passagem; escopos de criação de PSO no render thread |
| Rajada de *spawn* | Pico quando muitos atores nascem juntos | `SpawnActor` no game thread; pool (Cap. 32) |
| Consulta cara num frame | Pico periódico ligado a um comportamento | Escopos de EQS, de *traces* ou do seu código |
| Frame de checkpoint | Pico ao atravessar um `AVGCheckpoint` | `STAT_VGSaveCapture` (Caps. 56–58) |

Ferramentas: o painel **Frames** do Insights para achar os picos; `stat dumphitches` para registrar no log os *stats* de cada frame que passa do limite; e o `VGPerfCapture`, que mostra o máximo e o p99 separados da média.

### Memória, de passagem

A memória não é o foco deste capítulo, mas as ferramentas cabem numa lista: `stat memory` para a visão geral; `memreport -full` grava um relatório detalhado em `Saved/Profiling/` (texturas, malhas, objetos por classe); `obj list class=<Classe>` conta e mede objetos de uma classe; o *Low-Level Memory Tracker* (`-llm` na linha de comando, `stat llm` e `stat llmfull` no console) dá o uso por categoria de sistema; e o Memory Insights mostra a linha do tempo de alocações.

---

## Estudos de caso

### O *stutter* de compilação de *shaders* no PC

**[FATO PÚBLICO]** Travadas curtas na primeira vez que um efeito, uma área ou um inimigo aparece se tornaram uma queixa frequente em lançamentos para PC na última década, inclusive de jogos feitos em Unreal. Análises técnicas da imprensa especializada documentaram o padrão com gráficos de tempo de frame, e a Epic documentou mecanismos de cache e pré-compilação de *pipeline state objects* (PSO) para reduzi-lo.

**[INFERÊNCIA]** Em consoles, o hardware é fixo e os *shaders* podem ser compilados antes de o jogo chegar ao jogador. No PC, a combinação de placa e driver só é conhecida na máquina do jogador, e parte da compilação acontece em execução. O problema escapa de equipes que medem sempre na mesma máquina, com o cache já quente: na segunda passagem, o *hitch* não existe.

**Lição para a Vigília:** todo profiling de cenário tem duas versões, **fria** (cache de *shaders* limpo, primeira passagem) e **quente**, e as duas vão para o `DEVLOG.md`. O jogo inteiro da Vigília dura 15 minutos; boa parte dele **é** primeira passagem.

### A análise pública de tempo de frame

**[FATO PÚBLICO]** Análises técnicas de jogos publicadas pela imprensa especializada passaram a mostrar gráficos de tempo de frame e métricas como o "1% low", e não só o FPS médio. Jogadores de PC também medem com ferramentas de sobreposição disponíveis ao público.

**[INFERÊNCIA]** O público aprendeu a ver o que o Capítulo 58 recomendou medir: variação, pior frame e *hitches*. Um jogo que entrega 60 de média com travadas é percebido, e descrito, como um jogo com problema de desempenho.

**Lição para a Vigília:** meça do jeito que quem vai jogar mede: tempo de frame, percentis, primeira passagem. O `VGPerfCapture` existe para isso.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Método de profiling | Investigação de desempenho com hipótese | O cenário precisa ser reproduzido **no jogo**, com a mesma câmera e a mesma IA |
| `stat` | Métricas de painel (dashboard) | Por frame, na tela, sem histórico (salvo o `unitgraph`) |
| *Trace* do Insights | *Tracing* distribuído | Uma máquina, várias threads, organizado por frame |
| Tempo exclusivo × inclusivo | *Self time* × *total time* num *flame graph* | Igual, mas agregado sobre uma **seleção de frames** |
| *Bookmarks* | Anotações de *deploy* num gráfico de métricas | Marcam momentos de gameplay, não de infraestrutura |
| *Hitch* | Pico de latência p99.9 | A causa costuma ser única (primeira vez, GC) e não carga |

---

## Unreal Engine: o que existe

- **`stat`**: os da tabela da seção 59.2, mais os grupos que você declarar.
- **Unreal Insights**: Timing, Memory e Networking Insights; *trace* por linha de comando, console ou editor.
- **Macros de instrumentação**: `TRACE_CPUPROFILER_EVENT_SCOPE`, `TRACE_BOOKMARK`, e os *stats* (`SCOPE_CYCLE_COUNTER`) com `-statnamedevents`.
- **GPU**: `stat gpu`, `ProfileGPU`, os modos de visualização e o *plugin* de RenderDoc.
- **Medição em série**: o *CSV Profiler* grava métricas por frame em arquivos CSV para comparação entre execuções (`CsvProfile Start`/`Stop` no console, saída em `Saved/Profiling/`; ⚠️ confira os comandos na sua versão), e o *Gauntlet* é o *framework* da engine para execuções automatizadas, inclusive de desempenho.

O que a engine **não** dá: o cenário reproduzível. Nenhuma ferramenta sabe que "a caçada no corredor" é o seu pior caso nem como montá-lo. É o que a implementação deste capítulo constrói.

---

## Abordagens

| Critério | A. `stat` na tela | B. *Trace* no Insights | C. Medição em série (CSV, execuções automáticas) |
|---|---|---|---|
| **Complexidade** | Nenhuma | Baixa: um parâmetro e uma janela | Média: roteiro, coleta, comparação |
| **Custo de observação** | Baixo | Médio | Baixo a médio |
| **Profundidade** | Por frame, agregado | Função por função, frame por frame | Tendência entre builds |
| **Bom para** | Triagem: qual estágio, qual sistema | Diagnóstico: qual função, qual frame | Regressão: piorou desde o último milestone? |
| **Adequação à Vigília** | **Sim**, sempre | **Sim**, para cada hipótese | **Sim**, a cada milestone (Caps. 62, 83) |

**Decisão:** as três, cada uma para a sua pergunta. `stat` para triar, Insights para diagnosticar, captura em série para vigiar regressões. O que muda de um projeto para outro é a frequência: a Vigília faz triagem quando algo parece lento, diagnóstico a cada hipótese, e série a cada milestone.

---

## Implementação

O código deste capítulo é pequeno: marcadores nos momentos de gameplay que importam e um cheat que monta o pior cenário de forma reproduzível.

### 1. Marcadores

```cpp
// UVGDirectorSubsystem::EnterPhase (Cap. 42): no fim, depois de a fase mudar
#include "ProfilingDebugging/MiscTrace.h"

TRACE_BOOKMARK(TEXT("Director: %s"), *UEnum::GetValueAsString(NewPhase));
```

```cpp
// UVGSaveSubsystem::WriteCheckpoint (Cap. 56)
TRACE_BOOKMARK(TEXT("Checkpoint: %s"), *RequestedCheckpoint.ToString());

// AVGGameMode::InitGame (Cap. 56)
TRACE_BOOKMARK(TEXT("Level: %s"), *MapName);
```

Para `UEnum::GetValueAsString`, o `EVGDirectorPhase` precisa ser um `UENUM()`. Se o do Capítulo 42 não for, use um `switch` com os quatro nomes.

Faça o mesmo no início e no fim de cada cinemática, no ator de cinemática do Capítulo 49. Com esses marcadores, abrir um *trace* de dez minutos e ir direto ao "Director: Peak" leva um clique.

### 2. O cenário reproduzível

```cpp
// UVGCheatManager (adição)
/** Monta o pior cenário do corredor: Diretor travado em Peak por Seconds, com captura e marcadores. */
UFUNCTION(Exec) void VGPerfHunt(float Seconds = 20.0f);
```

```cpp
// UVGCheatManager.cpp (adição)
#include "AI/VGDirectorSubsystem.h"
#include "ProfilingDebugging/MiscTrace.h"
#include "TimerManager.h"

void UVGCheatManager::VGPerfHunt(float Seconds)
{
    UWorld* World = GetWorld();
    UVGDirectorSubsystem* Director = World ? World->GetSubsystem<UVGDirectorSubsystem>() : nullptr;
    if (!Director)
    {
        return;
    }
    // A trava de roteiro do Cap. 42: o Diretor fica em Peak e empurra a Presença para a caçada.
    const int32 Lock = Director->PushScriptLock(EVGDirectorPhase::Peak, TEXT("PerfHunt"));
    TRACE_BOOKMARK(TEXT("PerfHunt: start"));
    VGPerfCapture(Seconds, 60.0f);

    FTimerHandle Handle;
    World->GetTimerManager().SetTimer(Handle, FTimerDelegate::CreateWeakLambda(Director, [Director, Lock]()
    {
        Director->PopScriptLock(Lock);
        TRACE_BOOKMARK(TEXT("PerfHunt: end"));
    }), Seconds, /*bLoop*/ false);
}
```

O cenário completo exige também o **lugar** e a **câmera**: um decalque discreto no chão do corredor (`M_PerfMark`, em `/Game/Developers/`, para nunca ir ao build final) marca onde ficar e para onde olhar. A IA continua não determinística; por isso o método pede três repetições.

### Explicação das decisões

- **Marcadores nos momentos de gameplay, não em funções.** A pergunta do profiling de jogo é "o que estava acontecendo quando travou?". Fase do Diretor, checkpoint, nível e cinemática respondem isso; escopos de função são trabalho do *trace* de CPU.
- **O cenário usa as APIs do jogo.** A trava de roteiro do Diretor já existe para cinemáticas (Capítulo 42); o cheat a reaproveita. Nenhum "modo de teste" foi enfiado na IA, e o que se mede é o caminho real.
- **A captura do Capítulo 58 dentro do cenário.** O mesmo número, do mesmo jeito, antes e depois de cada mudança.
- **Sem teste automatizado.** Não há lógica nova não trivial: marcadores e um cheat que compõe APIs existentes. O teste deste capítulo é a sessão de profiling da seção seguinte.

---

## Projeto Vigília — o profiling da caçada

### Preparação

1. **Build e execução.** *Development*, em *Standalone*, com o editor fechado ou ao menos sem PIE aberto. Pela linha de comando:

```text
UnrealEditor.exe "C:\...\Vigilia.uproject" L_CasaDeForca -game -windowed -ResX=1920 -ResY=1080
    -trace=default -statnamedevents -tracehost=127.0.0.1
```

   (Para números finais, repita no build *Test* do Capítulo 62.)

2. **Console**: `r.VSync 0`, `t.MaxFPS 0`, `stat unit`. Preset de qualidade "Médio".
3. **Lugar**: `VGLoad` no `CP_S1_Corredor` (ou jogue até lá), posicione-se sobre o decalque, olhe para a curva.
4. **Passagem fria**: na **primeira** execução depois de limpar o cache de *shaders* (⚠️ a pasta de cache depende da versão e do RHI; confira a documentação de PSO da sua versão), rode `VGPerfHunt 20`. Registre a linha como **fria**.
5. **Passagens quentes**: três vezes `VGPerfHunt 20`. Registre a mediana como **quente**.

### O que fazer com os números

Siga o método, de cima para baixo:

1. **Qual estágio?** A linha `PERF` diz quem limita a maioria dos frames. Confirme com o teste da resolução do Capítulo 58.
2. **Se for GPU:** `stat gpu` durante a caçada, um `ProfileGPU` no momento da cascata de luzes, e os modos *Light Complexity* e *Quad Overdraw* parado no decalque. Hipóteses típicas: luzes com sombra demais, Lumen caro para a resolução, translucidez sobreposta.
3. **Se for game thread:** abra o *trace* no Insights, vá ao marcador "PerfHunt: start", selecione os 20 segundos e ordene os *Timers* do game thread por tempo exclusivo. Procure os escopos da Vigília (`Awareness Tick`, `Director Tick`, `Flicker Tick`), da IA da engine (BT, EQS, percepção), da animação e dos Blueprints.
4. **Para os picos:** no painel *Frames*, os cinco piores frames. Para cada um, a causa (tabela da seção 59.5).

### Uma sessão de exemplo

**[HIPOTÉTICO]** O que segue é uma sessão **ilustrativa**, com números plausíveis para uma máquina de configuração média. Ela mostra **como ler** e **como raciocinar**; os seus números serão outros, e o seu gargalo pode ser outro. Não copie as conclusões: refaça a sessão.

**Linha de base, quente** (mediana de três):

```text
PERF 1068 frames | média 17,9 ms | p95 21,6 | p99 24,8 | máx 31,2 | acima de 16,67 ms: 431 (40,4%), mais limitados por GPU
```

**Linha de base, fria:**

```text
PERF 1012 frames | média 18,4 ms | p95 22,0 | p99 27,9 | máx 46,7 | acima de 16,67 ms: 452 (44,7%), mais limitados por GPU
```

**Passo 1: o estágio.** No auge da caçada, o `stat unit` mostra algo como `Game 8,7 · Draw 6,9 · GPU 18,3`. Com `r.ScreenPercentage 50`, a GPU cai para perto de 10 ms e o frame acompanha. **GPU-bound**, confirmado.

**Passo 2: dentro da GPU.** O `stat gpu` mostra sombras em torno de 5 ms, Lumen em torno de 6 ms, translucidez em torno de 2,4 ms. O orçamento do Capítulo 58 dá 7 ms para iluminação, sombras e Lumen **juntos**, e 1,5 ms para translucidez. Os dois estouram. No modo *Light Complexity*, o corredor aparece quente de ponta a ponta: as nove lâmpadas que piscam têm raio grande, se sobrepõem, e **todas projetam sombra dinâmica**.

**Hipótese H1** (escrita antes): *"As nove lâmpadas do corredor projetam sombra. A jogadora só distingue a sombra das duas mais próximas da curva, porque as outras ficam no escuro entre piscadas. Se as outras sete deixarem de projetar sombra, o passo de sombras cai cerca de 3 ms, sem diferença visível em jogo."*

**Mudança:** *Cast Shadows* desligado em sete lâmpadas (uma propriedade por instância, no nível).

**Medição:**

```text
PERF 1203 frames | média 15,2 ms | p95 18,1 | p99 21,9 | máx 29,8 | acima de 16,67 ms: 214 (17,8%), mais limitados por GPU
```

**Decisão:** manter. As sombras caíram para perto de 2 ms; a média entrou no orçamento. Mas o p99 continua acima, e 18% dos frames também. Um olhar lado a lado, em jogo, confirma que a diferença visual não é perceptível no escuro: essa verificação faz parte da medição, porque performance que piora a experiência não é ganho.

**Passo 3: os picos.** No Insights, os piores frames quentes têm o **game thread** maior que o normal, a cada meio segundo, aproximadamente: um escopo de consulta de EQS da Presença (a consulta de busca do Capítulo 39) que, durante a caçada, roda em um frame só e custa por volta de 2 ms. A IA inteira estoura o próprio orçamento de 1 ms nesses frames. **H2, para o Capítulo 60:** espalhar a consulta no tempo e reduzir a frequência fora do pico.

**Passo 4: o frame frio.** O máximo de 46,7 ms só aparece na passagem fria, no primeiro instante em que a Presença surge: no render thread, um escopo de criação de PSO, ligado ao material de dissolução dela. **H3, para os Capítulos 60 e 62:** o cache e a pré-compilação de PSO.

**Passo 5: o que mais apareceu.** O `stat Vigilia` mostra cerca de 40 `Flicker Ticks` por frame e algumas dezenas de microssegundos no total. Pouco, mas são quarenta componentes trabalhando o tempo todo, inclusive os do outro lado da parede. **H4, para o Capítulo 60:** a significância. E a translucidez acima do orçamento vem dos *cards* de névoa empilhados na curva. **H5:** *overdraw*.

### O registro

No `DEVLOG.md`, uma tabela por sessão:

| # | Hipótese | Mudança | Antes (média / p99 / máx) | Depois | Decisão |
|---|---|---|---|---|---|
| H1 | Sombras de 9 lâmpadas | *Cast Shadows* em 2 de 9 | 17,9 / 24,8 / 31,2 | 15,2 / 21,9 / 29,8 | Manter |
| H2 | EQS da Presença num frame | — | — | — | Cap. 60 |
| H3 | PSO do material da Presença | — | máx frio 46,7 | — | Caps. 60, 62 |
| H4 | 40 *flickers* sempre ativos | — | — | — | Cap. 60 |
| H5 | *Overdraw* da névoa | — | — | — | Cap. 60 |

Repare que o profiling **não** terminou com tudo resolvido. Ele terminou com uma correção medida e quatro hipóteses ordenadas, cada uma com o lugar onde atacar. É o resultado normal de uma boa sessão.

---

## Decisões arquiteturais

1. **Método fixo**: reproduzir, medir, localizar de cima para baixo, hipótese escrita, uma mudança, medir, registrar.
2. **Três ferramentas, três perguntas**: `stat` para triagem, Insights para diagnóstico, captura em série para regressão.
3. **Cenários reproduzíveis por cheat** (`VGPerfHunt`), usando as APIs do jogo, e marcados no *trace*.
4. **Marcadores nos momentos de gameplay** (fase do Diretor, checkpoint, nível, cinemática).
5. **Toda medição tem versão fria e quente**, e três repetições com mediana.
6. **A verificação visual faz parte da medição**: um ganho que a jogadora percebe como perda não é ganho.

---

## Armadilhas

- **Mudar três coisas de uma vez.** Você nunca vai saber qual delas ajudou e qual atrapalhou.
- **Profiling no PIE, ou no build errado.** O editor distorce, e *Development* custa mais que *Shipping*; compare só medições feitas do mesmo jeito.
- **Uma medição só.** A IA e o *streaming* variam; três repetições e a mediana.
- **Olhar tempo inclusivo procurando culpado.** O escopo que "custa 8 ms" pode ser o pai de tudo. O exclusivo diz quem gasta.
- **Esquecer a passagem fria.** O pior frame do jogo é quase sempre o da primeira vez.
- **Deixar o *trace* ligado em todo teste.** Ele custa. Ligue para diagnosticar.
- **Confundir diagnóstico com otimização.** Desligar sombras com *show flags* responde "quanto custa"; a otimização é decidir quais sombras a jogadora não perde.
- **Acreditar no `stat` vazio.** Um grupo sem dados pode ser um grupo sem suporte na sua plataforma ou configuração, não custo zero.

---

## Exercício

**Parte 1 — `stat` (45 min).** No corredor, percorra os comandos da tabela 59.2, um ou dois de cada vez. Para cada um, escreva no `DEVLOG.md` uma frase: o que ele disse sobre a Vigília naquele lugar.

**Parte 2 — marcadores e cenário (1 h).** Implemente os marcadores e o `VGPerfHunt`. Grave um *trace* de uma caçada e encontre os marcadores no Insights. Meça o custo do próprio *trace*: rode o `VGPerfHunt` com e sem `-trace` e compare as linhas.

**Parte 3 — a sessão (2,5 h).** Faça a sessão completa da seção Projeto, com os **seus** números: passagem fria, três quentes, o estágio, o diagnóstico, pelo menos uma hipótese testada com uma mudança e a tabela de registro.

**Parte 4 — a promessa do Capítulo 42 (30 min).** Com quatro vigias e a Presença ativos no Galpão, meça o custo total da IA no Insights (selecione 10 s e some os escopos de IA e navegação do game thread). Está abaixo de 1 ms? Registre e, se não estiver, escreva a hipótese.

---

## Desafio — o *trace* que se compara sozinho

A tabela de registro é manual. Automatize a comparação:

1. Grave o `VGPerfHunt` duas vezes com o *CSV Profiler* ligado (`CsvProfile Start` antes, `CsvProfile Stop` depois; confira os comandos e a pasta de saída na sua versão).
2. Escreva um pequeno *script* (Python, PowerShell, o que preferir, fora do jogo) que lê os dois CSV e imprime, para cada métrica do frame e de cada escopo da Vigília, a média e o p99 de cada execução e a diferença.
3. Faça uma mudança qualquer (por exemplo, reverta o H1) e rode o *script*. Ele aponta a mudança sem você abrir o Insights?
4. Responda no `DEVLOG.md`: que limite de diferença você usaria para dizer "regressão" e não "ruído", dado o que viu nas três repetições?

---

## Uso de IA

1. **Para ler um *trace* com você:**
   > "Estou analisando um *trace* do Unreal Insights de um frame de 24 ms num jogo com alvo de 16,67 ms. Estes são os escopos do game thread ordenados por tempo exclusivo, com contagem de chamadas: [lista]. E estes são os passos da GPU: [lista]. Qual estágio limita o frame, quais escopos merecem investigação primeiro, e que pergunta eu deveria responder antes de mudar qualquer coisa?"

2. **Para escrever hipóteses testáveis:**
   > "Com base nesta observação de profiling [descrição], escreva três hipóteses no formato 'se X, ao fazer Y, a métrica Z muda cerca de N', ordenadas por relação entre ganho esperado e custo de testar. Para cada uma, diga como eu mediria e o que me faria rejeitá-la."

3. **Para revisar o método:**
   > "Este é o meu protocolo de profiling [protocolo]. Aponte fontes de variação que eu não controlei, efeitos de observador, e situações em que as minhas conclusões poderiam estar erradas mesmo com números consistentes."

**Cuidado específico:** a IA não vê o seu *trace*. Ela vai produzir explicações plausíveis para qualquer número que você der, inclusive para números que vieram de uma medição mal feita. Use-a para **organizar** a investigação e para gerar hipóteses; a confirmação é sempre uma medição sua, do jeito do método.

---

## Checklist

- [ ] Sigo o ciclo: reproduzir, medir, localizar, hipótese escrita, uma mudança, medir, registrar.
- [ ] Sei qual `stat` usar para cada pergunta, e não ligo dez de uma vez.
- [ ] Sei gravar um *trace*, ir a um marcador, comparar um frame ruim com um típico e ler tempo exclusivo.
- [ ] Sei investigar a GPU com `stat gpu`, `ProfileGPU` e os modos de visualização.
- [ ] Tenho medições frias e quentes da caçada no corredor, com três repetições.
- [ ] Terminei uma sessão com pelo menos uma hipótese testada e uma lista ordenada para o Capítulo 60.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Unreal Insights** (incluindo *Timing Insights*, *Trace* e *Memory Insights*), **Stat Commands**, **Introduction to Performance Profiling and Configuration** (inclui o perfil de GPU com `ProfileGPU`), **CSV Profiler** e as páginas sobre **PSO caching** e **PSO precaching**.
- **RenderDoc** (renderdoc.org): a documentação da ferramenta de captura de frames, útil quando a pergunta é sobre uma chamada de desenho específica.
- ***Game Engine Architecture***, de Jason Gregory: o capítulo sobre ferramentas de depuração e profiling discute instrumentação, *stats* e medição dentro de engines.
- **GDC Vault** (gdcvault.com): palestras de equipes de tecnologia sobre profiling e otimização de títulos em Unreal (procure por "Unreal Insights" e "profiling"; confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 60 — Optimization](cap-60-optimization.md)

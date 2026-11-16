# Capítulo 58 — Performance

## Objetivo

Ao final deste capítulo você deve conseguir:

- raciocinar em **tempo de frame** (milissegundos) e não em FPS, e explicar por que "ganhar 10 FPS" não significa nada sem o ponto de partida;
- olhar para o **pior frame** e para a variação entre frames, e não para a média;
- descrever os estágios de um frame na Unreal (game thread, render thread, RHI thread, GPU, *workers*) e dizer qual deles limita o jogo;
- distinguir um jogo **CPU-bound** de um **GPU-bound** com dois testes simples, e saber por que otimizar o lado errado não muda nada;
- montar um **orçamento** por estágio, por sistema e por cenário de pior caso, com folga;
- entender os custos de memória que importam (texturas, objetos, coleta de lixo, carregamento) e como eles viram *hitches*;
- reconhecer quantas decisões de arquitetura do livro já foram decisões de orçamento.

---

## Contexto

O Capítulo 1 pôs na mesa a tabela de orçamentos (33,33 ms a 30 FPS, 16,67 ms a 60, 8,33 ms a 120) e disse que a linha entre otimização prematura e projeto dentro do orçamento "será traçada com dados no Capítulo 58". O Capítulo 2 mostrou o frame distribuído entre threads e pediu um `stat unit` num nível vazio. O Capítulo 3 falou de *frame pacing* e de *hitches*. O Capítulo 11 avisou que a coleta de lixo "custa frames" e deixou a medição para cá. O Capítulo 42 fixou um teto de 1 ms para a IA. E o Capítulo 76 listou como risco "mais de 16,67 ms na máquina-alvo" no Salão das Turbinas, com a resposta "orçamento por setor desde o Milestone 6".

Até aqui, o livro tomou decisões **pensando** em custo: portas que só ticam enquanto se movem, interação a 20 Hz, consciência a 10 Hz, eventos em vez de consulta, pooling, *tokens* de ataque. Este capítulo dá a essas decisões uma moldura: o que é o orçamento, como ele se divide, como saber qual parte está estourando e como ele muda a arquitetura. O Capítulo 59 ensina a **medir**, e o 60, a **cortar**.

A Parte VII (iluminação com Lumen, áudio, animação, VFX com Niagara e UI) traz boa parte do custo de GPU e de memória do jogo. Este capítulo trata esses sistemas pelo lado do orçamento e deixa os detalhes de cada um para os capítulos deles.

---

## 58.1 Tempo de frame, não FPS

FPS é o inverso do tempo de frame, e a relação não é linear:

| Mudança | Tempo de frame | Diferença |
|---|---|---|
| 30 → 40 FPS | 33,3 → 25,0 ms | 8,3 ms |
| 50 → 60 FPS | 20,0 → 16,7 ms | 3,3 ms |
| 60 → 70 FPS | 16,7 → 14,3 ms | 2,4 ms |
| 100 → 120 FPS | 10,0 → 8,3 ms | 1,7 ms |

"Ganhei 10 FPS" pode ser 8 ms ou 2 ms de trabalho a menos. Engenheiros de jogos falam em milissegundos porque milissegundos **somam**: se a IA custa 1,2 ms e a física 0,8 ms, as duas juntas custam 2 ms. FPS não soma.

A mesma não linearidade explica por que alvos altos são caros. A 60 FPS, 1 ms é 6% do frame. A 120 FPS, é 12%. Um sistema que "não pesa nada" a 30 FPS pode ser o gargalo a 120.

### O pior frame, não a média

O Capítulo 1 já usou a comparação com SLOs de latência: um jogo a "60 de média" com um frame de 80 ms a cada segundo é pior que um jogo estável a 45. Na prática, isso vira três números que você vai registrar em toda medição:

- **Média do tempo de frame**, para ter uma ideia geral do custo.
- **Percentis altos** (p95, p99; jogadores e análises técnicas falam em "1% low", o FPS do 1% de frames mais lentos), que dizem como é o jogo nos momentos ruins.
- **Hitches:** frames isolados muito acima do orçamento (o dobro ou mais), com a causa de cada um. Um *hitch* por minuto é perceptível; um a cada troca de sala é um defeito.

### Folga

Um orçamento de 16,67 ms não é para ser gasto até o fim. O conteúdo varia (uma sala com mais luzes, um ângulo com mais partículas), o sistema operacional e o driver roubam tempo de vez em quando, e a máquina do jogador esquenta. Planeje cada estágio do frame para caber em **cerca de 14 ms no pior cenário**, e trate os 2,5 ms restantes como reserva.

> 🌉 **Ponte:** é planejamento de capacidade com folga. Você não roda um serviço a 100% de utilização, porque, perto do limite, qualquer pico vira fila e a latência explode.
>
> 🧱 **Onde a ponte cai:** no serviço, o pico é estatístico e você responde escalando. No jogo, não há escala horizontal, e o pico é **determinístico**: ele mora num lugar (a sala com trinta luzes) ou num momento (a Presença surgindo durante a cascata de luzes). Por isso o orçamento de jogo é medido por **cenário**, e não por média ao longo da sessão.

### Medir o que a jogadora vê

Duas coisas escondem o custo real:

- **VSync e limites de FPS.** Com VSync, um jogo que poderia rodar a 90 FPS mostra 60, e um que roda a 55 pode cair para 30 (em monitores sem taxa variável). Para medir, desligue (`r.VSync 0`) e tire o limite (`t.MaxFPS 0`). Para **julgar a experiência**, ligue de novo.
- **O editor.** O PIE roda dentro do editor, que tem o próprio custo de desenho, de *ticks* e de memória. Meça em *Standalone* ou num build (Capítulos 59 e 62).

---

## 58.2 Onde o tempo vai: os estágios do frame

O Capítulo 2 mostrou o frame como um *pipeline*. Aqui está ele de novo, com o que cada estágio faz na Unreal 5:

```text
 frame N     GAME THREAD     input · tick groups · física (sincronização) · IA · animação (parte)
                │            UI (UMG) · lógica de Blueprint e C++ · áudio (comandos)
                ▼
 frame N-1   RENDER THREAD   visibilidade e culling · gerar comandos de desenho por malha/material
                │            preparar sombras, luzes, Lumen, partículas
                ▼
 frame N-1/2 RHI THREAD      traduzir para a API gráfica (DirectX 12, Vulkan) e submeter ao driver
                │
                ▼
             GPU             profundidade · base pass · sombras · Lumen (GI e reflexos)
                             translucidez · pós-processo · upscaling (TSR)

 em paralelo: WORKERS (task graph): avaliação de animação, física, partículas, culling paralelo...
```

Em regime estável, os estágios trabalham em frames diferentes ao mesmo tempo, e o tempo de frame fica perto do **estágio mais lento**, mais as esperas de sincronização entre eles. O `stat unit` mostra o tempo de trabalho de cada um: `Game` (game thread), `Draw` (render thread), `RHIT` (RHI thread) e `GPU`, além de `Frame`, o total percebido.

Algumas consequências práticas:

- **O game thread não é só "gameplay".** Animação, física e UI disputam o mesmo estágio que a IA e os seus Blueprints.
- **O render thread é CPU.** Um jogo pode ser "CPU-bound" no render thread com o game thread folgado: muitos objetos visíveis, muitos materiais diferentes, muitas luzes com sombra.
- **A GPU escala com resolução; o game thread, não.** Diminuir a resolução alivia a GPU e não muda em nada a IA.
- ***Workers* escondem custo.** A avaliação de animação roda em *workers*, mas o game thread pode esperar por ela. No Insights (Capítulo 59), essa espera aparece como uma barra de "esperando tarefa".

---

## 58.3 CPU-bound ou GPU-bound

Antes de otimizar qualquer coisa, descubra **qual estágio** está limitando. O Capítulo 2 já deixou a regra: se a GPU é o gargalo, otimizar gameplay não muda nada.

Dois testes resolvem a maioria dos casos:

1. **`stat unit`.** O estágio cujo tempo está mais perto de `Frame` é o candidato. Se `GPU` mostra 18 ms e `Game` mostra 9 ms, o jogo está limitado pela GPU.
2. **O teste da resolução.** Rode `r.ScreenPercentage 50`. Se o tempo de frame cai muito, a GPU era o gargalo (ela agora processa um quarto dos pixels). Se quase não muda, o limite está na CPU (game ou render thread).

Dois casos enganam:

- **Os dois lados perto do limite.** Corrigir a GPU faz o game thread aparecer como gargalo logo em seguida. É normal: otimização é uma sequência de gargalos.
- **Esperas.** Um estágio esperando por outro pode parecer ocupado. Quando os números do `stat unit` não fecham, o Insights mostra quem está trabalhando e quem está esperando.

### *Draw calls* e o custo do render thread

Cada malha visível, com cada seção de material, vira comandos de desenho. Gerar e submeter esses comandos custa CPU no render thread e na RHI thread, independentemente de quantos pixels a malha ocupa. Uma sala com quinhentos parafusos separados pode custar mais CPU que uma sala com uma turbina enorme. As saídas clássicas são desenhar **menos coisas** (culling, Capítulo 60), **juntar** coisas iguais (*instancing*: `UInstancedStaticMeshComponent` e a versão hierárquica para muitas instâncias), reduzir **seções de material** por malha, e usar Nanite, que muda o modelo de custo das malhas compatíveis (Capítulo 60, com as ressalvas de versão).

---

## 58.4 Os custos de um jogo como a Vigília

A tabela abaixo é um mapa de suspeitos, não de números. Os números são da sua máquina e vêm do Capítulo 59.

| Sistema | Onde custa | O que faz o custo crescer | No livro |
|---|---|---|---|
| Luzes com sombra (lanterna, lâmpadas que piscam) | GPU (sombras), render thread | Número de luzes **com sombra** na tela, raio de influência | Caps. 9, 51 |
| Lumen | GPU | Resolução, qualidade, cenas grandes e abertas | Cap. 51 |
| Translucidez e partículas (névoa, poeira, faíscas) | GPU (*overdraw*) | Camadas transparentes sobrepostas cobrindo a tela | Cap. 54 |
| Animação (Presença, vigias) | Game thread e *workers* | Personagens visíveis, complexidade do *Animation Blueprint* | Cap. 53 |
| IA (BT, percepção, EQS) | Game thread | Agentes ativos, frequência de consultas | Caps. 36–42 |
| Física | Game thread e *workers* | Corpos acordados, *ragdolls* | Caps. 15, 30 |
| UI (UMG) | Game e render thread | Widgets que se redesenham todo frame | Cap. 55 |
| Áudio | Thread de áudio | Vozes simultâneas, efeitos por voz | Cap. 52 |
| Blueprints com *Tick* | Game thread | Atores com `Event Tick` fazendo trabalho todo frame | Cap. 12 |
| Narrativa (diálogo, quests, fatos) | Game thread | Quase nada, mas meça antes de afirmar | Caps. 44–46 |
| Save e persistência | Game thread, num frame só | Atores persistentes capturados no checkpoint | Caps. 56–57 |
| *Streaming* e carregamento | Game thread e E/S | Cargas síncronas, células grandes | Caps. 57, 60 |
| Compilação de *shaders* (PSO) | Render thread, na primeira vez | Materiais e combinações vistos pela primeira vez | Cap. 59 |

A última linha merece destaque porque ela não aparece nas medições "quentes". No PC, a primeira vez que uma combinação de material e estado de renderização é desenhada pode exigir compilar um *pipeline state object* (PSO), o que pode travar um frame por dezenas de milissegundos. A engine tem mecanismos de cache e pré-compilação de PSO que mudaram bastante ao longo das versões 5.x (⚠️ confira *PSO caching* e *PSO precaching* na documentação da sua versão). Para o orçamento, a regra é: **meça também a primeira passagem por cada lugar**, e não só a segunda.

---

## 58.5 Memória

Memória é orçamento de outro tipo: estourá-la não deixa o jogo lento, deixa o jogo **quebrado** (falta de memória é *crash*), ou lento de um jeito específico (*paging*, *streaming* de texturas que não acompanha, *hitches*).

| Categoria | O que é | O que fazer |
|---|---|---|
| **Texturas** | Normalmente a maior fatia de memória de vídeo | *Texture streaming* (só os mips necessários), tamanhos adequados ao uso, compressão certa |
| **Malhas** | Vértices e índices; com Nanite, um *pool* de *streaming* próprio | LODs (Capítulo 60), Nanite onde couber |
| **Áudio** | Ondas comprimidas, *streaming* para as longas | Comprimir, transmitir música e ambiente |
| **Animação** | Sequências e curvas | Compressão de animação |
| ***Render targets*** | Buffers do frame, proporcionais à resolução | Resolução e qualidade de pós-processo |
| **`UObject`s** | Atores, componentes, assets carregados, objetos de dados | Menos objetos; dados em *structs* |

### Coleta de lixo

A coleta de lixo da Unreal (Capítulo 11) percorre o grafo de objetos que a reflexão conhece, marca os alcançáveis e libera o resto. O custo cresce com o **número** de `UObject`s vivos, e acontece em rajadas: uma coleta a cada intervalo (configurável, `gc.TimeBetweenPurgingPendingKillObjects`) ou quando a pressão de memória pede. Em projetos grandes, uma coleta pode custar vários milissegundos num frame só, o *hitch* periódico que o Capítulo 3 descreveu.

O que ajuda:

- **Criar menos `UObject`s.** Dados que não precisam de reflexão, de Blueprint ou de referência fraca podem ser *structs*. Eventos do barramento (Capítulo 24) já são *structs*.
- **Não criar e destruir objetos em ritmo de frame.** É o argumento do pooling (Capítulo 32).
- **Opções da engine**: agrupamento de objetos em *clusters*, liberação incremental e, em versões recentes, análise de alcançabilidade incremental (⚠️ confira o estado dessas opções na sua versão antes de ligá-las).

### Carregamento

`LoadSynchronous` (que o Capítulo 56 usou para a arma, durante a abertura do nível) bloqueia o game thread até o asset chegar do disco. Durante a abertura de um nível, atrás de um fade, é aceitável. No meio do jogo, é um *hitch*. O Capítulo 44 deixou registrado que as vozes do diálogo deveriam ser carregadas de forma assíncrona ao entrar na fila; o Capítulo 60 faz isso.

### O orçamento de memória

Memória se orçamenta pela máquina-alvo: quanto de RAM o processo pode ocupar sem que o sistema comece a paginar, e quanto de memória de vídeo o preset de qualidade pode usar sem que o *streaming* de texturas comece a perder. Ferramentas (Capítulo 59): `stat memory`, `memreport -full`, `obj list`, o *Low-Level Memory Tracker* (`-llm` e `stat llm`) e o Memory Insights.

---

## 58.6 O orçamento muda a arquitetura

Releia o livro com o orçamento na cabeça e muitas decisões aparecem de outro jeito:

| Decisão | Capítulo | O que ela economiza |
|---|---|---|
| A porta só tica enquanto se move | 1, 19 | 80 portas paradas custam zero |
| Interação por *sweep* a 20 Hz | 19 | Dois terços do trabalho a 60 FPS, sem diferença perceptível |
| Consciência da IA a 10 Hz | 36 | Idem, e o atraso é até desejável (percepção "humana") |
| Eventos em vez de consulta | 4, 24 | Ninguém pergunta "mudou?" todo frame |
| Pool de projéteis | 32 | Criação de atores e pressão no GC |
| *Tokens* de ataque e o Diretor | 42 | Limitam quantos agentes estão em modo caro ao mesmo tempo |
| Checkpoints em vez de save livre | 56 | O save não precisa capturar simulação, e o frame de checkpoint é previsível |
| Gravação assíncrona | 56 | O disco nunca segura o frame |
| Derivar em vez de persistir | 57 | Menos atores capturados no checkpoint e no *streaming* |

Essas decisões têm um padrão: **trabalho por frame, por objeto, é o inimigo**, e as saídas são fazer menos vezes, fazer para menos objetos, ou fazer só quando algo muda. O Capítulo 1 chamou isso de "a chamada de rede dentro do laço" dos jogos.

O orçamento também muda **o que o design pede**. A Vigília tem uma Presença e até quatro vigias, e não trinta inimigos, em parte por tom e em parte por orçamento de IA e de animação. A usina é escura, o que é uma escolha estética que também limita quanto da cena precisa de detalhe visível. A lanterna é **uma** luz com sombra que acompanha a jogadora, e o resto das luzes pode ser mais barato. Boa parte da arte de performance em jogos é fazer o design e o orçamento concordarem antes de o código existir.

### Orçamento por sistema e por cenário

Um orçamento útil tem duas dimensões:

- **Por sistema**: quanto cada sistema pode gastar, para que cada dono saiba o seu limite (a IA com 1 ms do Capítulo 42 é um exemplo).
- **Por cenário de pior caso**: os momentos e lugares em que tudo acontece junto, onde o orçamento é **verificado**.

Um orçamento por sistema sem cenários é uma soma no papel. Um cenário sem orçamento por sistema diz "está lento", mas não diz de quem é o problema.

---

## Estudos de caso

### Call of Duty: 60 como decisão de design

**[FATO PÚBLICO]** A série *Call of Duty* tem 60 FPS como alvo nos consoles desde *Call of Duty 4: Modern Warfare* (2007), algo destacado pela imprensa e pelos próprios estúdios numa época em que muitos jogos de tiro de console miravam 30. Análises técnicas da época apontaram que, para isso, o jogo renderizava abaixo da resolução nativa de 720p naquela geração.

**[INFERÊNCIA]** A taxa de quadros é parte do *game feel* de um jogo de tiro competitivo: menor latência entre o comando e a imagem, movimento mais legível. A decisão veio primeiro, e a engenharia se organizou em volta dela, inclusive sacrificando resolução, que é a parte do orçamento de GPU que o jogador tolera perder.

**Lição para a Vigília:** a taxa de quadros é uma decisão de **design**, tomada no começo. A Vigília escolhe 60 porque o controle em primeira pessoa e a perseguição pedem resposta rápida, e não 120 porque o terror lento não ganha o bastante para pagar o dobro de orçamento.

### Battlefield 4 e a resolução como válvula

**[FATO PÚBLICO]** No lançamento da geração PlayStation 4 e Xbox One, em 2013, foi amplamente noticiado que *Battlefield 4* rodava em resoluções diferentes nos dois consoles (900p e 720p, respectivamente), mirando 60 FPS nos dois.

**[INFERÊNCIA]** Com o mesmo jogo, a mesma simulação e hardwares de GPU diferentes, o estúdio manteve a taxa de quadros e ajustou o que escala com a GPU: o número de pixels.

**Lição para a Vigília:** resolução (e hoje o *upscaling*) é a parte **elástica** do orçamento de GPU. O game thread não tem válvula equivalente: a IA custa o mesmo em qualquer resolução. Por isso o orçamento de CPU é o que exige mais disciplina de arquitetura.

### Alan Wake 2: dois modos, dois orçamentos

**[FATO PÚBLICO]** *Alan Wake 2* (Remedy, 2023) oferece, no PlayStation 5 e no Xbox Series X, um modo de qualidade a 30 FPS e um modo de desempenho a 60 FPS (o Xbox Series S tem um modo só, a 30 FPS).

**[INFERÊNCIA]** São dois orçamentos de GPU para o mesmo jogo: 33,3 ms com mais qualidade de imagem, ou 16,7 ms com menos. O game thread precisa caber no orçamento mais apertado nos dois modos, já que a simulação não muda entre eles.

**Lição para a Vigília:** um modo de desempenho só é possível se a CPU **já** cabe no orçamento mais curto. Uma arquitetura que folga em 16,67 ms é a que permite, um dia, um modo a 120 ajustando só o lado da GPU.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Tempo de frame | Latência por requisição | Cada frame tem prazo fixo e o atraso é visível |
| p99 do tempo de frame | p99 de latência | O pico mora num lugar e num momento do jogo; meça por cenário |
| Folga de 15% | Utilização-alvo abaixo de 100% | Sem escala horizontal: a folga é a única defesa |
| Estágios do *pipeline* | *Pipeline* de processamento com estágios | A vazão é a do estágio mais lento, e cada estágio é uma thread fixa |
| Orçamento por sistema | Orçamento de erro / de latência por serviço | Os "serviços" disputam a mesma thread, não máquinas diferentes |
| Coleta de lixo | Pausas de GC da JVM | Uma pausa de 20 ms é um frame perdido que a jogadora vê |

---

## Unreal Engine: o que existe

- **`stat unit`** (tempos por estágio), **`stat unitgraph`** (o mesmo, em gráfico ao longo do tempo), **`stat fps`**. O Capítulo 59 cobre os demais `stat`.
- **`t.MaxFPS`**, **`r.VSync`**, **`r.ScreenPercentage`**: os controles do experimento.
- **Escalabilidade**: os grupos `sg.*` (sombras, texturas, efeitos, pós-processo, distância de visão...), expostos no menu *Settings → Engine Scalability Settings* do editor e, no jogo, pelo `UGameUserSettings`. São o mecanismo de presets de qualidade.
- **Resolução dinâmica e *upscaling*** (TSR): ajustam a resolução interna para segurar a taxa de quadros (⚠️ confira os CVars de resolução dinâmica e o suporte por plataforma na sua versão).
- **O sistema de *stats***: grupos e contadores próprios (`DECLARE_STATS_GROUP`, `DECLARE_CYCLE_STAT`, `SCOPE_CYCLE_COUNTER`), visíveis com `stat <Grupo>` e no Insights. Some de builds sem *stats* (Shipping, Capítulo 62).
- **Unreal Insights**, **CSV Profiler**, **FPS charts** e **LLM**: as ferramentas de medição do Capítulo 59.

O que a engine **não** dá: o orçamento. Nenhuma ferramenta sabe que a IA da Vigília tem 1 ms, nem que a caçada no corredor é o pior cenário.

---

## Abordagens

| Critério | A. Otimizar no fim | B. Orçamento por sistema desde o início | C. Orçamento por cenário de pior caso |
|---|---|---|---|
| **Complexidade** | Nenhuma até o fim; enorme no fim | Baixa: uma tabela e contadores | Baixa: uma lista de cenários reproduzíveis |
| **Performance final** | Imprevisível; às vezes exige refazer arquitetura | Boa, se os limites forem medidos | Boa nos lugares que importam |
| **Extensibilidade** | Cada sistema novo é uma surpresa | Cada sistema novo nasce com um limite | Cada área nova ganha um cenário |
| **Manutenção** | Nenhuma rotina | Medir de vez em quando | Medir os cenários a cada milestone |
| **Prototipação** | A mais rápida no começo | Quase tão rápida | Quase tão rápida |
| **Adequação à Vigília** | Não: o risco do Salão das Turbinas já foi identificado | **Sim** | **Sim** |

**Decisão: B e C juntas.** Um limite por sistema, para cada dono saber o seu, e uma lista curta de cenários de pior caso, medidos a cada milestone. A abordagem A não é "nunca otimizar cedo"; é descobrir na última semana que a arquitetura não cabe.

---

## Implementação

O capítulo não otimiza nada. Ele prepara a medição: um grupo de *stats* da Vigília nos pontos quentes e uma ferramenta pequena que captura uma janela de frames e resume em uma linha, com percentis e o estágio que limita.

### 1. Os *stats* da Vigília

```cpp
// Source/Vigilia/Core/VGStats.h
#pragma once

#include "Stats/Stats.h"

// `stat Vigilia` no console mostra este grupo. Some em builds sem stats (Shipping).
DECLARE_STATS_GROUP(TEXT("Vigilia"), STATGROUP_Vigilia, STATCAT_Advanced);

DECLARE_CYCLE_STAT_EXTERN(TEXT("Awareness Tick"), STAT_VGAwarenessTick, STATGROUP_Vigilia, VIGILIA_API);
DECLARE_CYCLE_STAT_EXTERN(TEXT("Director Tick"), STAT_VGDirectorTick, STATGROUP_Vigilia, VIGILIA_API);
DECLARE_CYCLE_STAT_EXTERN(TEXT("Interaction Scan"), STAT_VGInteractionScan, STATGROUP_Vigilia, VIGILIA_API);
DECLARE_CYCLE_STAT_EXTERN(TEXT("Flicker Tick"), STAT_VGFlickerTick, STATGROUP_Vigilia, VIGILIA_API);
DECLARE_CYCLE_STAT_EXTERN(TEXT("Dialogue Tick"), STAT_VGDialogueTick, STATGROUP_Vigilia, VIGILIA_API);
DECLARE_CYCLE_STAT_EXTERN(TEXT("Quest Drain"), STAT_VGQuestDrain, STATGROUP_Vigilia, VIGILIA_API);
DECLARE_CYCLE_STAT_EXTERN(TEXT("Save Capture"), STAT_VGSaveCapture, STATGROUP_Vigilia, VIGILIA_API);

// Quantas vezes por frame (o Cap. 60 usa para conferir o efeito da significância).
DECLARE_DWORD_COUNTER_STAT_EXTERN(TEXT("Flicker Ticks"), STAT_VGFlickerTicks, STATGROUP_Vigilia, VIGILIA_API);
```

```cpp
// Source/Vigilia/Core/VGStats.cpp
#include "Core/VGStats.h"

DEFINE_STAT(STAT_VGAwarenessTick);
DEFINE_STAT(STAT_VGDirectorTick);
DEFINE_STAT(STAT_VGInteractionScan);
DEFINE_STAT(STAT_VGFlickerTick);
DEFINE_STAT(STAT_VGDialogueTick);
DEFINE_STAT(STAT_VGQuestDrain);
DEFINE_STAT(STAT_VGSaveCapture);
DEFINE_STAT(STAT_VGFlickerTicks);
```

E uma linha no começo de cada ponto quente:

```cpp
void UVGAwarenessComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                          FActorComponentTickFunction* ThisTickFunction)
{
    SCOPE_CYCLE_COUNTER(STAT_VGAwarenessTick);
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    // ... como antes ...
}

void UVGFlickerComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                        FActorComponentTickFunction* ThisTickFunction)
{
    SCOPE_CYCLE_COUNTER(STAT_VGFlickerTick);
    INC_DWORD_STAT(STAT_VGFlickerTicks);
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    // ... como antes ...
}

// UVGSaveSubsystem::WriteCheckpoint: em volta de CaptureLiveWorld + CaptureSnapshot + CapturePlayer
{
    SCOPE_CYCLE_COUNTER(STAT_VGSaveCapture);
    // ...
}
```

Faça o mesmo em `UVGDirectorSubsystem::Tick`, `UVGInteractionComponent::Scan`, `UVGDialogueSubsystem::Tick` e `UVGQuestSubsystem::Drain`. O contador de ciclo mede **tempo inclusivo** do escopo; o contador `DWORD` conta ocorrências, e é zerado a cada frame.

### 2. Regras puras para ler um frame

```cpp
// Source/Vigilia/Debug/VGPerfRules.h
#pragma once

#include "CoreMinimal.h"

/** Tempos de um frame, em ms, como o `stat unit` os mostra. */
struct FVGFrameTimes
{
    float FrameMs = 0.0f;
    float GameMs = 0.0f;
    float RenderMs = 0.0f;
    float RhiMs = 0.0f;
    float GpuMs = 0.0f;
};

enum class EVGFrameBound : uint8
{
    WithinBudget,
    GameThread,
    RenderThread,
    RhiThread,
    Gpu
};

namespace VGPerfRules
{
    /** 60 → 16,67; 120 → 8,33. */
    inline float BudgetMs(float TargetFps) { return TargetFps > 0.0f ? 1000.0f / TargetFps : 0.0f; }

    /** Dentro do orçamento, ou o estágio mais lento (o candidato a gargalo, seção 58.3). */
    EVGFrameBound Classify(const FVGFrameTimes& Times, float BudgetMs);

    /** Percentil (0..100) por ordenação; copia as amostras. */
    float Percentile(TArray<float> Samples, float Percent);

    const TCHAR* ToString(EVGFrameBound Bound);
}
```

```cpp
// Source/Vigilia/Debug/VGPerfRules.cpp
#include "Debug/VGPerfRules.h"

EVGFrameBound VGPerfRules::Classify(const FVGFrameTimes& Times, float BudgetMs)
{
    if (Times.FrameMs <= BudgetMs)
    {
        return EVGFrameBound::WithinBudget;
    }
    // Simplificação: o maior tempo de trabalho é o gargalo. Esperas entre estágios distorcem isso;
    // quando o resultado não fizer sentido, o Insights decide (Cap. 59).
    EVGFrameBound Bound = EVGFrameBound::GameThread;
    float Worst = Times.GameMs;
    auto Consider = [&](float Ms, EVGFrameBound Candidate)
    {
        if (Ms > Worst) { Worst = Ms; Bound = Candidate; }
    };
    Consider(Times.RenderMs, EVGFrameBound::RenderThread);
    Consider(Times.RhiMs, EVGFrameBound::RhiThread);
    Consider(Times.GpuMs, EVGFrameBound::Gpu);
    return Bound;
}

float VGPerfRules::Percentile(TArray<float> Samples, float Percent)
{
    if (Samples.IsEmpty())
    {
        return 0.0f;
    }
    Samples.Sort();
    const int32 Index = FMath::Clamp(FMath::CeilToInt(Percent / 100.0f * Samples.Num()) - 1, 0, Samples.Num() - 1);
    return Samples[Index];
}

const TCHAR* VGPerfRules::ToString(EVGFrameBound Bound)
{
    switch (Bound)
    {
    case EVGFrameBound::WithinBudget: return TEXT("dentro do orçamento");
    case EVGFrameBound::GameThread:   return TEXT("game thread");
    case EVGFrameBound::RenderThread: return TEXT("render thread");
    case EVGFrameBound::RhiThread:    return TEXT("RHI thread");
    case EVGFrameBound::Gpu:          return TEXT("GPU");
    }
    return TEXT("?");
}
```

### 3. A captura: `VGPerfCapture`

Um cheat que amostra os tempos de cada frame por alguns segundos e escreve **uma linha** no log, pronta para o `DEVLOG.md`. Ele lê as mesmas variáveis que o `stat unit` lê.

```cpp
// UVGCheatManager (adição)
UFUNCTION(Exec) void VGPerfCapture(float Seconds = 10.0f, float TargetFps = 60.0f);
```

```cpp
// UVGCheatManager.cpp (adição)
#include "Containers/Ticker.h"
#include "Debug/VGPerfRules.h"
#include "DynamicRHI.h"
#include "Misc/App.h"

void UVGCheatManager::VGPerfCapture(float Seconds, float TargetFps)
{
    struct FCapture
    {
        TArray<float> Frames;
        TMap<EVGFrameBound, int32> Bounds;
        double EndTime = 0.0;
        float BudgetMs = 0.0f;
    };
    TSharedRef<FCapture> Capture = MakeShared<FCapture>();
    Capture->EndTime = FPlatformTime::Seconds() + Seconds; // relógio real: medimos frames, não jogo
    Capture->BudgetMs = VGPerfRules::BudgetMs(TargetFps);

    FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateLambda([Capture](float)
    {
        // ⚠️ As mesmas fontes do `stat unit` (UnrealClient.cpp); confira os nomes na sua versão.
        FVGFrameTimes Times;
        Times.FrameMs = static_cast<float>(FApp::GetDeltaTime() * 1000.0);
        Times.GameMs = FPlatformTime::ToMilliseconds(GGameThreadTime);
        Times.RenderMs = FPlatformTime::ToMilliseconds(GRenderThreadTime);
        Times.RhiMs = FPlatformTime::ToMilliseconds(GRHIThreadTime);
        Times.GpuMs = FPlatformTime::ToMilliseconds(RHIGetGPUFrameCycles(0));
        Capture->Frames.Add(Times.FrameMs);
        Capture->Bounds.FindOrAdd(VGPerfRules::Classify(Times, Capture->BudgetMs))++;

        if (FPlatformTime::Seconds() < Capture->EndTime)
        {
            return true; // continua no próximo frame
        }
        float Sum = 0.0f;
        for (float Ms : Capture->Frames) { Sum += Ms; }
        const int32 Over = Capture->Frames.Num() - Capture->Bounds.FindRef(EVGFrameBound::WithinBudget);
        EVGFrameBound Worst = EVGFrameBound::WithinBudget;
        int32 WorstCount = 0;
        for (const TPair<EVGFrameBound, int32>& Pair : Capture->Bounds)
        {
            if (Pair.Key != EVGFrameBound::WithinBudget && Pair.Value > WorstCount)
            {
                Worst = Pair.Key;
                WorstCount = Pair.Value;
            }
        }
        UE_LOG(LogVigilia, Display,
            TEXT("PERF %d frames | média %.2f ms | p95 %.2f | p99 %.2f | máx %.2f | acima de %.2f ms: %d (%.1f%%), mais limitados por %s"),
            Capture->Frames.Num(), Sum / Capture->Frames.Num(),
            VGPerfRules::Percentile(Capture->Frames, 95.0f), VGPerfRules::Percentile(Capture->Frames, 99.0f),
            VGPerfRules::Percentile(Capture->Frames, 100.0f), Capture->BudgetMs,
            Over, 100.0f * Over / Capture->Frames.Num(), VGPerfRules::ToString(Worst));
        return false; // remove o ticker
    }));
}
```

`Build.cs`: acrescente `"RHI"` (para `RHIGetGPUFrameCycles`). As variáveis `GGameThreadTime`, `GRenderThreadTime` e `GRHIThreadTime` são globais da engine declaradas no módulo `Core`.

### Explicação das decisões

- ***Stats* em vez de logs com tempo.** Um contador de ciclo custa quase nada, aparece agregado com `stat Vigilia`, entra no Insights (Capítulo 59) e desaparece de builds sem *stats*. Um `UE_LOG` com `FPlatformTime` em cada tick custa a formatação e polui o log.
- **Pontos quentes escolhidos, não tudo.** Instrumentar cada função cria ruído e custo. Os sete escopos cobrem o que a Vigília faz por frame; o Insights encontra o resto.
- **Uma linha por captura.** O objetivo é **comparar**: antes e depois de uma mudança, nesta máquina e naquela, neste milestone e no próximo. Uma linha no `DEVLOG.md` por cenário é comparável; uma captura de tela do `stat unit`, não.
- **`FTSTicker` e relógio real.** A captura não pode depender do tempo de jogo (pausa e dilatação o distorcem, Capítulo 3), nem de um ator no mundo, que poderia ser destruído no meio da captura.
- **A classificação é uma heurística declarada.** "O maior tempo é o gargalo" acerta na maioria dos casos e erra quando um estágio espera pelo outro. O comentário diz isso, e o Capítulo 59 diz como desempatar.

### 4. Teste

```cpp
// Source/Vigilia/Tests/VGPerfRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Debug/VGPerfRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGPerfRulesTest, "Vigilia.Perf.Rules.BudgetBoundPercentile",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGPerfRulesTest::RunTest(const FString& Parameters)
{
    TestEqual(TEXT("60 FPS"), VGPerfRules::BudgetMs(60.0f), 1000.0f / 60.0f);

    FVGFrameTimes Gpu{ 19.0f, 9.0f, 6.0f, 3.0f, 18.5f };
    TestTrue(TEXT("GPU-bound"), VGPerfRules::Classify(Gpu, 16.67f) == EVGFrameBound::Gpu);

    FVGFrameTimes Game{ 21.0f, 20.0f, 7.0f, 3.0f, 12.0f };
    TestTrue(TEXT("Game-thread-bound"), VGPerfRules::Classify(Game, 16.67f) == EVGFrameBound::GameThread);

    FVGFrameTimes Fine{ 14.0f, 9.0f, 6.0f, 3.0f, 13.0f };
    TestTrue(TEXT("Dentro"), VGPerfRules::Classify(Fine, 16.67f) == EVGFrameBound::WithinBudget);

    TArray<float> Samples;
    for (int32 i = 1; i <= 100; ++i) { Samples.Add(static_cast<float>(i)); } // 1..100 ms
    TestEqual(TEXT("p50"), VGPerfRules::Percentile(Samples, 50.0f), 50.0f);
    TestEqual(TEXT("p99"), VGPerfRules::Percentile(Samples, 99.0f), 99.0f);
    TestEqual(TEXT("máx"), VGPerfRules::Percentile(Samples, 100.0f), 100.0f);
    TestEqual(TEXT("vazio"), VGPerfRules::Percentile(TArray<float>(), 99.0f), 0.0f);
    return true;
}

#endif
```

---

## Projeto Vigília — o orçamento

### A máquina-alvo

O risco do Capítulo 76 fala em "máquina-alvo", e ela ainda não foi definida. Defina-a agora, por escrito, em `docs/tech/maquina-alvo.md`: o processador, a placa de vídeo, a memória e o armazenamento de uma máquina **real à qual você tem acesso**, de preferência a mais modesta. Se só tem uma máquina, use-a e registre que o alvo é ela com o preset de qualidade um degrau abaixo do máximo. A *Steam Hardware Survey* (store.steampowered.com/hwsurvey) mostra o que é comum entre jogadores de PC e ajuda a calibrar a escolha.

A máquina-alvo não é "a máquina de desenvolvimento". A sua máquina de trabalho roda o editor, o compilador e o navegador; a da jogadora roda o jogo. Se você só mede na mais forte, o primeiro playtest numa máquina comum é o primeiro profiling de verdade.

### O orçamento da Vigília

**[DECISÃO DE PROJETO — revista no Capítulo 83 com medições]**

**Alvo:** 60 FPS (16,67 ms) a 1080p na máquina-alvo, no preset "Médio", com cada estágio abaixo de **14 ms no pior cenário**. Nenhum frame acima de 33 ms fora de telas de carregamento.

| Game thread (≤ 14 ms) | Limite | Dono |
|---|---|---|
| IA: Presença + até 4 vigias (BT, percepção, EQS, consciência, Diretor) | 1,0 ms | Caps. 36–42 |
| Animação (parte do game thread) | 1,5 ms | Cap. 53 |
| Física | 1,0 ms | Caps. 15, 30 |
| UI | 1,0 ms | Cap. 55 |
| Gameplay e Blueprints (personagem, interação, armas, interativos) | 2,0 ms | Partes III–IV |
| Narrativa (diálogo, quests, fatos, documentos) | 0,3 ms | Parte VI |
| Áudio (lado do game thread) | 0,5 ms | Cap. 52 |
| Reserva (engine, sincronização, o que ninguém previu) | o restante | — |

| GPU (≤ 14 ms) | Limite | Dono |
|---|---|---|
| Iluminação, sombras e Lumen | 7,0 ms | Cap. 51 |
| Base pass e geometria | 3,0 ms | Caps. 50, 60 |
| Translucidez e VFX | 1,5 ms | Cap. 54 |
| Pós-processo e *upscaling* | 1,5 ms | Caps. 51, 60 |
| Reserva | o restante | — |

| Eventos de frame único | Limite |
|---|---|
| Frame do checkpoint (`STAT_VGSaveCapture`) | 2 ms |
| Primeira passagem por uma sala (PSO, *streaming*) | sem frame acima de 33 ms |

Os números são **limites de planejamento**, e não estimativas do que a engine custa. Eles servem para cada sistema saber o próprio teto e para a medição ter contra o que comparar. Se a medição mostrar que a iluminação precisa de 9 ms, alguém precisa ceder 2 ms, e a discussão acontece com números.

### Os cenários de pior caso

| Cenário | Por que é o pior | Como reproduzir |
|---|---|---|
| **A caçada no corredor** | Presença em `Hunting`, lanterna acesa, cascata de lâmpadas piscando, Diretor em `Peak`, áudio no máximo | `CP_S1_Corredor` + o cheat do Cap. 59 |
| **O frame do checkpoint** | Captura de narrativa, jogadora e mundo num frame | Atravessar `CP_S1_Subsolo` |
| **A primeira entrada no subsolo** | Materiais e efeitos vistos pela primeira vez (PSO), carregamentos | Build novo, cache limpo, primeira passagem |
| **O Salão das Turbinas** (futuro) | Espaço grande, Lumen, partículas | Quando o setor existir (Cap. 77) |

### A primeira medição

Em *Standalone*, com `r.VSync 0` e `t.MaxFPS 0`, rode `VGPerfCapture 20` em cada cenário disponível e cole as linhas no `DEVLOG.md`, com a data, a máquina, o preset e o build. É a **linha de base**. O Capítulo 59 abre cada uma delas para descobrir o porquê.

---

## Decisões arquiteturais

1. **Tempo de frame em milissegundos**, com média, p95, p99, máximo e *hitches*; nunca só o FPS médio.
2. **60 FPS a 1080p na máquina-alvo, preset Médio, cada estágio abaixo de 14 ms no pior cenário**; nenhum frame acima de 33 ms fora de carregamento.
3. **Orçamento por sistema e por cenário de pior caso**, com donos e limites escritos.
4. **A máquina-alvo é uma máquina real, documentada**, e não a máquina de desenvolvimento.
5. ***Stats* da Vigília nos pontos quentes** (`STATGROUP_Vigilia`) e uma captura que resume uma janela de frames em uma linha comparável (`VGPerfCapture`).
6. **Medir em *Standalone* ou build**, com VSync e limite de FPS desligados para medir e ligados para julgar.

---

## Armadilhas

- **Medir no PIE.** O editor tem o próprio custo de render, de *ticks* e de memória, e distorce os números para cima ou para baixo, conforme o caso.
- **Medir com VSync.** Você vê o limite do monitor, não o custo do jogo.
- **Olhar a média.** O jogo com média de 60 e um *hitch* por segundo é o pior jogo da comparação.
- **Otimizar sem saber qual estágio limita.** Uma semana tirando milissegundos do game thread de um jogo GPU-bound melhora zero frames.
- **Orçar o caso médio.** O orçamento é verificado no pior cenário, não no corredor vazio.
- **Comparar medições de builds diferentes.** Development tem *checks*, *stats* e logs que Shipping não tem; o Capítulo 62 mostra a configuração Test, que é a certa para medir algo próximo do produto final.
- **Esquecer a primeira vez.** Compilação de PSO e carregamentos só aparecem na primeira passagem, e a jogadora sempre passa a primeira vez.
- **Notebook na tomada e fora dela.** Perfis de energia e temperatura mudam os números. Meça sempre nas mesmas condições e registre-as.

---

## Exercício

**Parte 1 — instrumentação (1 h).** Crie `VGStats.h/.cpp` e os sete escopos. Rode o setor 1 com `stat Vigilia` e `stat unit` ligados. Anote, para cada escopo, o tempo típico e o maior que você viu.

**Parte 2 — a captura (1 h).** Implemente `VGPerfRules`, o teste e o `VGPerfCapture`. Compare a linha do `VGPerfCapture` com o que o `stat unit` mostra no mesmo trecho. Elas concordam?

**Parte 3 — CPU ou GPU (45 min).** No corredor da Casa de Força, com a lanterna acesa, faça o teste da resolução (`r.ScreenPercentage 100` e `50`), duas capturas de 10 s cada. Escreva no `DEVLOG.md`: o jogo, ali, é limitado por qual estágio? O que mudou entre as duas capturas, e o que não mudou?

**Parte 4 — o orçamento (1 h).** Escreva o `docs/tech/maquina-alvo.md` e o `docs/tech/orcamento.md` com as tabelas deste capítulo, ajustadas à sua máquina-alvo. Faça a linha de base dos cenários disponíveis.

---

## Desafio — e se fosse 120?

Suponha que a Vigília ganhe um "modo desempenho" a 120 FPS (8,33 ms).

1. Refaça o orçamento com o mesmo formato. Quais limites caem pela metade e quais não podem cair?
2. Para cada linha do game thread, diga o que teria de mudar na **arquitetura** (não só no ajuste) para caber: frequência da IA, número de vigias, animação, UI.
3. Para a GPU, diga o que o *upscaling* resolve sozinho e o que ele não resolve.
4. Conclua no `DEVLOG.md`: o modo 120 é viável sem mudar o design da Vigília? Que decisão de design você mudaria primeiro, se precisasse?

---

## Uso de IA

1. **Para montar um orçamento:**
   > "Estou fazendo um FPS narrativo de terror em Unreal Engine 5, com alvo de 60 FPS a 1080p numa máquina-alvo [descrição]. O jogo tem uma criatura com IA (BT, percepção, EQS), até 4 inimigos humanos, uma lanterna com sombra, lâmpadas que piscam, Lumen e névoa. Proponha uma divisão do orçamento de game thread e de GPU por sistema, diga quais números são estimativas grosseiras e o que eu deveria medir primeiro para validar cada um."

2. **Para interpretar números:**
   > "Estes são os tempos do `stat unit` de três cenários do meu jogo, com e sem `r.ScreenPercentage 50`: [números]. Em cada cenário, o jogo está limitado por qual estágio? Que hipóteses você testaria primeiro, e com qual ferramenta?"

3. **Para revisar decisões de arquitetura pelo custo:**
   > "Aqui está a lista dos sistemas que rodam todo frame no meu jogo e a frequência de cada um: [lista]. Para cada um, diga se ele precisa mesmo rodar nessa frequência, se poderia ser orientado a eventos, e qual seria o efeito perceptível de reduzir a frequência."

**Cuidado específico:** a IA vai oferecer números de custo da Unreal ("Lumen custa X ms", "uma luz com sombra custa Y") com confiança. Esses números dependem da versão, da plataforma, do conteúdo e das configurações, e frequentemente estão errados ou são de outra versão. Use a IA para estruturar o orçamento e as hipóteses; os números vêm da sua medição, na sua máquina-alvo.

---

## Checklist

- [ ] Penso em milissegundos e sei converter FPS em orçamento e de volta.
- [ ] Registro média, p95, p99, máximo e *hitches*, e sei por que a média sozinha engana.
- [ ] Sei dizer o que cada estágio do frame faz e qual limita o jogo, com `stat unit` e o teste da resolução.
- [ ] Tenho uma máquina-alvo documentada e um orçamento por sistema e por cenário.
- [ ] Os pontos quentes da Vigília têm *stats*, e tenho uma linha de base no `DEVLOG.md`.
- [ ] Sei apontar no livro três decisões de arquitetura que foram decisões de orçamento.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Introduction to Performance Profiling and Configuration** (visão geral), **Stat Commands**, **Scalability Reference** e **Unreal Insights**.
- ***Game Engine Architecture***, de Jason Gregory: os capítulos sobre o *game loop*, a arquitetura em threads e o *pipeline* de renderização dão o modelo por trás do `stat unit`.
- ***Real-Time Rendering***, de Tomas Akenine-Möller, Eric Haines e Naty Hoffman: a referência para entender o que a GPU faz em cada passo do frame.
- **GDC Vault** (gdcvault.com): palestras de equipes de tecnologia sobre orçamento de frame e performance em consoles e PC (procure por "frame budget" e "performance"; confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 59 — Profiling](cap-59-profiling.md)

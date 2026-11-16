# Capítulo 60 — Optimization

## Objetivo

Ao final deste capítulo você deve conseguir:

- atacar um custo na ordem certa: não fazer, fazer menos vezes, fazer para menos coisas, fazer mais barato, fazer em paralelo;
- reduzir o custo de render com *culling*, LOD, HLOD e, com cautela de versão, Nanite;
- tratar luzes com sombra e translucidez como os custos que mais crescem num jogo escuro e enevoado;
- usar *World Partition* e carregamento assíncrono sem trocar custo de frame por *hitches*;
- tornar o tick uma decisão: desligado, ligado só quando útil, com intervalo, por relevância;
- usar o **Significance Manager** para decidir quem merece atualização completa;
- reduzir a frequência da IA e da animação (incluindo o **URO**) sem quebrar o que a jogadora ouve;
- saber quando *pooling*, grades espaciais e paralelismo pagam, e quando são complexidade sem retorno;
- aplicar às hipóteses do Capítulo 59 e medir o resultado.

---

## Contexto

O Capítulo 59 terminou com uma correção medida (as sombras de sete lâmpadas do corredor) e quatro hipóteses abertas, na ordem em que apareceram:

- **H2:** a consulta de busca da Presença (EQS) roda num frame só durante a caçada e estoura o orçamento de IA;
- **H3:** o material de dissolução da Presença compila um PSO na primeira aparição, um *hitch* de passagem fria;
- **H4:** quarenta componentes de *flicker* atualizam todo frame, inclusive os do outro lado da parede;
- **H5:** os *cards* de névoa empilhados na curva estouram o orçamento de translucidez.

E o livro deixou promessas para cá:

- **Capítulo 1:** "se a usina tem 80 portas, nenhuma delas deve consumir processamento quando está parada".
- **Capítulo 2:** "paralelismo tem regras próprias (Capítulo 60)".
- **Capítulo 7:** *World Partition* e *One File Per Actor*.
- **Capítulo 44:** as vozes do diálogo "com carga assíncrona ao enfileirar (Caps. 57 e 60)".
- **Capítulo 76:** o risco de performance no Salão das Turbinas, com a resposta "LOD e oclusão (Cap. 60)".

O Interlúdio II, que vem logo depois desta parte, aplica várias técnicas deste capítulo a um mundo aberto em miniatura: anéis de carregamento, LOD de simulação, *significance*, URO e grades espaciais. Este capítulo dá a base; o interlúdio mostra a escala.

---

## 60.1 A ordem do ataque

Toda otimização é uma destas cinco, e elas estão em ordem de retorno:

1. **Não fazer.** O trabalho mais barato é o que não existe: o tick de uma porta parada, a sombra de uma luz que ninguém vê, a consulta cujo resultado ninguém usa.
2. **Fazer menos vezes.** A 10 Hz em vez de a cada frame, quando a diferença não é perceptível; só quando algo muda, em vez de perguntar todo frame.
3. **Fazer para menos coisas.** Só para os objetos perto, visíveis ou relevantes.
4. **Fazer mais barato.** Um LOD com menos triângulos, um material mais simples, uma consulta com menos pontos.
5. **Fazer em paralelo.** Mover trabalho para outras threads. É o último da lista porque é o mais caro de acertar, e porque não reduz o trabalho: só o distribui.

No render, a mesma ordem tem nomes próprios: **desenhar menos** (*culling*), **desenhar mais simples** (LOD, HLOD) e **desenhar mais barato** (luzes, sombras, materiais, translucidez).

Duas regras atravessam o capítulo. Cada otimização responde a uma **hipótese medida** (Capítulo 59), e cada uma passa pela **verificação visual e sonora**: se a jogadora percebe a perda, não houve ganho.

> 🌉 **Ponte:** é a ordem que você usa para otimizar um serviço: remover a chamada desnecessária, *cachear*, agrupar em lote, só então paralelizar ou escalar.
>
> 🧱 **Onde a ponte cai:** num serviço, "fazer menos vezes" tem de manter a resposta correta. Num jogo, ela só precisa **parecer** correta. A percepção da jogadora é um recurso de otimização: a 40 metros, no escuro, uma lâmpada que pisca a 10 Hz e uma que pisca a 60 são a mesma lâmpada. É a "mentira legítima" do Capítulo 1, aplicada ao orçamento.

---

## 60.2 Desenhar menos: *culling*

Antes de desenhar, a engine decide **o que** desenhar, em camadas:

- ***Frustum culling*:** o que está fora do campo de visão da câmera não é desenhado. Automático.
- ***Occlusion culling*:** o que está atrás de outra coisa não é desenhado. A Unreal usa, por padrão, consultas de oclusão na GPU, com o resultado do frame anterior; por isso, em giros muito rápidos de câmera, um objeto pode aparecer um frame atrasado. O custo dessas consultas aparece no render thread (`stat initviews`).
- ***Distance culling*:** o que está longe demais não é desenhado. Por primitiva (*Desired Max Draw Distance*, nos detalhes de renderização do componente) ou por volume (*Cull Distance Volume*, que mapeia tamanhos de objeto a distâncias). Luzes têm o próprio *Max Draw Distance*.

Para ver o *culling* acontecer, `FreezeRendering` no console congela a visibilidade: você anda pelo nível e vê o que a engine tinha decidido desenhar do ponto em que congelou.

O *culling* mais barato é o do **level design**. Um corredor com uma curva, como o do Interlúdio I, esconde o que vem depois; uma porta fechada esconde a sala inteira. Os interiores da Casa de Força são quase todos assim, e a oclusão funciona bem neles. O Salão das Turbinas é o oposto: um espaço grande, aberto, com tudo à vista; nele, a oclusão ajuda pouco, e o trabalho passa para LOD, distância e o próprio desenho do espaço (Capítulo 50).

---

## 60.3 Desenhar mais simples: LOD, HLOD e Nanite

### LOD

Uma malha estática pode ter vários **níveis de detalhe** (LOD), trocados conforme o tamanho que ocupa na tela (*screen size*). A engine gera LODs automaticamente pela redução de malha, configurável por malha ou por *LOD Group*; artistas podem fornecer os seus. Malhas esqueléticas (a Presença, os vigias) também têm LODs, com menos ossos e menos vértices nos níveis distantes.

O custo do LOD é a **transição visível** (*popping*). As defesas são distâncias bem escolhidas e transições suavizadas no material (*dithered LOD transition*). A forma de conferir é olhar: `r.ForceLOD <n>` força um nível para inspeção (⚠️ confira o nome na sua versão).

### HLOD

LOD troca **uma** malha por versões mais simples. **HLOD** (*Hierarchical LOD*) troca **um grupo** de malhas distantes por uma única malha simplificada, construída antes (no editor), que custa um desenho em vez de centenas. No *World Partition*, o HLOD é organizado em **camadas de HLOD** (*HLOD layers*) e construído por células: quando uma célula está longe demais para ser carregada, o HLOD dela continua visível como uma "maquete". É o anel mais externo da regra que o Interlúdio II desenha: o que está fora do raio de carregamento ainda precisa **parecer** existir.

Para a Vigília, HLOD só faz sentido se o Salão das Turbinas for dividido por *World Partition* com raio de carregamento menor que o salão. Num nível de interiores, como a Casa de Força, não há "longe" o bastante.

### Nanite

**Nanite** é o sistema de geometria virtualizada da Unreal 5: a malha é dividida em *clusters* e a engine transmite e desenha, a cada frame, só o detalhe que a tela precisa. Para as malhas compatíveis, ele reduz drasticamente o custo de CPU por objeto e a necessidade de autorar LODs, e permite geometria muito densa.

Com cautela de versão:

- **O suporte mudou ao longo das versões 5.x**: tipos de material (máscara, *World Position Offset*), folhagem, malhas esqueléticas e outros casos ganharam suporte, às vezes experimental, em versões diferentes. ⚠️ Antes de decidir, leia a página de Nanite **da sua versão**, incluindo a lista de recursos suportados e não suportados.
- **Há um custo fixo** de usar Nanite; em cenas pequenas e simples, ele pode não compensar.
- **Há requisitos de hardware.** Confira os da sua versão contra a máquina-alvo do Capítulo 58.

**Decisão para a Vigília:** a geometria industrial densa do Salão das Turbinas (turbinas, tubulações, estruturas) é candidata natural a Nanite. A decisão fica para o Capítulo 77, com profiling do salão real: se o *base pass* e o render thread estiverem pressionados por quantidade de objetos e triângulos, Nanite entra; se não, LODs tradicionais bastam.

---

## 60.4 Desenhar mais barato: luzes, sombras e translucidez

Num jogo escuro, com lanterna e lâmpadas que piscam, a iluminação é o maior custo de GPU, e o Capítulo 59 mostrou por quê. As alavancas, em ordem:

- **Sombra é por luz.** Cada luz dinâmica que projeta sombra custa um passo de sombra para a área que ela alcança. A pergunta não é "esta luz projeta sombra?", mas "a jogadora **vê** a sombra desta luz?". Na Vigília, a lanterna sempre projeta (ela é a mecânica); as lâmpadas do cenário projetam só onde a sombra conta uma história (Capítulo 51).
- **Raio de atenuação.** Uma luz com raio grande afeta mais pixels e mais objetos. Raios grandes e sobrepostos são o que o modo *Light Complexity* mostra em vermelho.
- ***Max Draw Distance* da luz.** Luzes pequenas e distantes podem simplesmente deixar de ser desenhadas.
- **Lumen.** As configurações de qualidade de Lumen escalam com a resolução e com o preset. O Capítulo 51 decide como a luz é usada; este capítulo só lembra que o custo de Lumen é a fatia maior do orçamento de GPU e que é controlado pela escalabilidade (`sg.GlobalIlluminationQuality`, `sg.ReflectionQuality`; ⚠️ confira os grupos na sua versão).

A **translucidez** é o outro custo que cresce em silêncio. Superfícies transparentes não escrevem profundidade, e cada camada sobreposta é desenhada inteira: três *cards* de névoa um atrás do outro custam três vezes o mesmo pixel (*overdraw*). O modo *Quad Overdraw* mostra onde. As defesas: menos camadas, *cards* menores, materiais translúcidos mais simples, *depth fade* para evitar camadas grossas, e, onde fizer sentido, névoa volumétrica no lugar de *cards* (com o custo dela, medido). Partículas do Niagara têm escalabilidade e LOD próprios (Capítulo 54).

Por fim, a válvula elástica do Capítulo 58: **resolução interna e *upscaling***. Baixar `r.ScreenPercentage` e reconstruir a imagem com TSR alivia toda a GPU de uma vez. É a última alavanca, não a primeira, porque troca nitidez por tempo e não corrige nada.

---

## 60.5 *World Partition*, *streaming* e carregar sem travar

O *World Partition* (Capítulos 7, 8 e 57) divide um nível grande numa grade e carrega células conforme a distância das **fontes de *streaming*** (por padrão, a jogadora). Vem com *One File Per Actor*, camadas de HLOD e *Data Layers*. Ele resolve memória e tempo de render: o que está longe não existe na memória, e o que está fora do alcance é HLOD.

Ele não resolve, sozinho, o custo de **entrar** uma célula. Carregar uma célula é ler do disco (em segundo plano) e depois **adicionar ao mundo** (no game thread): registrar componentes, criar estado de física e chamar `BeginPlay` de cada ator. Uma célula com centenas de atores, ou com atores de `BeginPlay` pesado, vira um *hitch*. As defesas:

- células e atores leves, com `BeginPlay` barato;
- trabalho pesado de inicialização adiado ou espalhado (um timer, uma fatia por frame);
- e, para a persistência do Capítulo 57, poucos atores persistentes por célula.

O Interlúdio II formaliza a geometria disso como uma **regra de anéis**: o LOD de simulação mais rico fica dentro do anel de *spawn*, que fica dentro do de *despawn*, que fica dentro do raio de carregamento, que fica dentro do HLOD. Um anel fora de ordem é um bug clássico de mundo aberto (figurantes andando para células que não existem).

Para a Vigília, que troca de nível inteiro, o equivalente é o **carregamento de nível**: o que acontece entre o fade de saída e o de entrada. Cargas síncronas durante o jogo (`LoadSynchronous`) são *hitches*; durante a abertura do nível, atrás do fade, são aceitáveis.

### Carregar sem travar

O padrão é: referência *soft* no dado, pedido assíncrono **antes** de precisar, e um *handle* mantido enquanto o asset for necessário.

```cpp
#include "Engine/AssetManager.h"
#include "Engine/StreamableManager.h"

// Pedido: quando a conversa entra na fila, não quando a fala começa.
TArray<FSoftObjectPath> Paths;
for (const FVGDialogueNode& Node : Conversation->Nodes)
{
    if (!Node.Voice.IsNull())
    {
        Paths.Add(Node.Voice.ToSoftObjectPath());
    }
}
// O handle mantém os áudios na memória até ser liberado (fim da conversa).
VoiceHandles.Add(Conversation, UAssetManager::GetStreamableManager().RequestAsyncLoad(Paths));

// Uso: se a carga ainda não terminou, a fala vai sem voz (só legenda) e o log avisa.
USoundBase* VoiceAsset = Node.Voice.Get();
```

É a troca que o Capítulo 44 anunciou para o `Voice` do `FVGDialogueNode` (de `TObjectPtr<USoundBase>` para `TSoftObjectPtr<USoundBase>`), com `VoiceHandles` como um `TMap` de conversa para `TSharedPtr<FStreamableHandle>` no subsistema de diálogo.

**Decisão para a Vigília: ainda não.** O Capítulo 44 condicionou a troca a "centenas de falas", e a Vigília tem um teto de trinta conversas (Capítulo 76). Com referência forte, os áudios de um setor carregam com o nível, atrás do fade. Rode `memreport -full` no setor 1 e olhe a memória de áudio: se ela couber no orçamento de memória do Capítulo 58, o padrão acima fica documentado e guardado para quando o `memreport` disser o contrário. Otimizar sem uma medição que peça é exatamente o que o Capítulo 59 ensinou a não fazer.

---

## 60.6 Tick: só quando é útil

O Capítulo 2 disse que tick "não é sempre ligado ou sempre desligado". Este é o inventário das regras, em ordem:

1. **Não ticar.** `PrimaryActorTick.bCanEverTick = false` (e `PrimaryComponentTick` para componentes) em tudo o que reage a eventos. Em Blueprint, um `Event Tick` vazio ainda custa: apague o nó ou desligue *Start with Tick Enabled*.
2. **Ticar só enquanto algo acontece.** A porta do Capítulo 19 liga o tick ao começar a se mover e desliga ao parar. O `UVGFactGateComponent` do Capítulo 47 só tica enquanto há uma mudança adiada.
3. **Ticar com intervalo.** `SetActorTickInterval`/`SetComponentTickInterval`, ou `TickInterval` no construtor. O `DeltaTime` recebido é o tempo desde o último tick daquela função, e não o do frame (⚠️ confira em `FTickFunction` na sua versão se o seu código depende disso). A interação (20 Hz) e a consciência (10 Hz) já fazem isso.
4. **Timers para o que é pontual.** "Daqui a 2 segundos" é um timer, não um tick que conta.
5. **Ticar por relevância.** A frequência depende de quão importante o objeto é agora: perto, à vista, envolvido na ação. É a próxima seção.

Um detalhe que gera picos: componentes com o **mesmo** intervalo, ligados no mesmo frame, ticam no mesmo frame. Vinte componentes a 10 Hz criam um frame pesado a cada seis, em vez de um custo espalhado. O Interlúdio II usa a saída de custo fixo: uma **fatia** de N agentes por passo, em rodízio. Para componentes independentes, variar levemente o intervalo de cada um já desfaz o alinhamento.

### As 80 portas

A promessa do Capítulo 1 se confere com uma ferramenta: `DumpTicks` no console lista as funções de tick registradas, com o estado de cada uma (⚠️ confira os argumentos disponíveis na sua versão). Rode-o com todas as portas da Casa de Força paradas: nenhuma delas deve aparecer como habilitada. Rode de novo com uma porta abrindo: só ela aparece.

---

## 60.7 Relevância: o Significance Manager

Muitas otimizações dependem de uma pergunta: **quão importante é este objeto agora?** Uma lâmpada a dois metros, à frente da câmera, é muito importante; uma a trinta metros, atrás de uma parede, quase nada. Responder isso em cada componente, cada um com a própria regra de distância, espalha a mesma lógica por todo o código.

O **Significance Manager** é a peça da Unreal para centralizar essa pergunta. Ele é um *plugin* (habilite-o e acrescente o módulo `SignificanceManager` ao `Build.cs`) e funciona assim:

- cada objeto se **registra** com uma *tag* (o tipo de objeto), uma **função de significância** (recebe o objeto e um ponto de vista, devolve um `float`) e, opcionalmente, uma **função pós-significância** (recebe o valor antigo e o novo, e é onde o jogo **age**);
- **você** chama `Update` com os pontos de vista (em geral, a câmera da jogadora), uma vez por frame; ele não roda sozinho;
- a função pós-significância pode rodar em paralelo (`Concurrent`) ou em sequência no game thread (`Sequential`); se ela mexe em componentes, use `Sequential`.

A documentação é explícita sobre a divisão de trabalho: a engine fornece o arcabouço (registro, avaliação, ordenação por *tag*) e o jogo fornece a política. O manager não sabe o que é uma lâmpada; ele sabe ordenar números.

⚠️ As assinaturas abaixo seguem o `SignificanceManager.h` das versões 5.x que conheço; confira-as na sua. Se `FSignificanceManagerModule::Get` devolver nulo, confira se o *plugin* está habilitado e a configuração da classe do manager no `DefaultEngine.ini`.

A Vigília usa o manager para a H4: as lâmpadas que piscam. A política é simples e testável:

| Significância | Situação típica | Tick do *flicker* |
|---|---|---|
| ≥ 0,5 | Perto e à frente | Todo frame |
| 0,1 a 0,5 | Meia distância, ou perto e atrás | 10 Hz: o olho não separa |
| < 0,1 | Longe | Parado no último valor |

Por que não uma checagem de distância em cada componente? Para quarenta lâmpadas, ela funcionaria. O manager vence por três motivos: a regra mora num lugar (a mesma pergunta vai servir a emissores de som ambiente e, no setor 3, a outros objetos); ele permite políticas por **orçamento** ("só as N mais importantes em qualidade total"), que uma checagem por componente não consegue fazer porque não vê os outros; e o custo de avaliação fica num ponto só, mensurável.

---

## 60.8 IA e animação em frequência reduzida

### IA

A Vigília já reduz a frequência da IA em vários pontos: consciência a 10 Hz (Capítulo 36), serviços de BT com intervalo (Capítulo 37), o Diretor limitando quantos agentes estão em modo caro (Capítulo 42). O Capítulo 59 achou o que falta (H2): a consulta de busca da Presença, que roda inteira num frame.

As alavancas para EQS, na ordem do ataque:

- **Fazer menos vezes:** o serviço que dispara a consulta durante a caçada pode ter intervalo maior e **desvio aleatório** (*Random Deviation*, uma propriedade dos serviços de BT), o que desalinha a consulta de outros trabalhos periódicos.
- **Fazer para menos coisas:** o gerador da consulta (Capítulo 39) com raio menor ou espaçamento maior produz menos pontos para testar.
- **Fazer mais barato:** testes baratos primeiro, para descartar pontos antes dos caros (o `Cost` dos testes, que o Capítulo 39 configurou, é o que ordena).
- **Espalhar no tempo:** o gerenciador de EQS tem um limite de tempo de teste por frame e continua a consulta no frame seguinte (`MaxAllowedTestingTime` nas configurações do `EnvQueryManager`; ⚠️ confira o nome e o padrão na sua versão).

A percepção visual tem limites parecidos (número de *traces* por tick na configuração do sentido de visão; ⚠️ confira os nomes em `AISense_Sight` na sua versão).

A consciência ganha uma regra por estado: uma Presença que **não desconfia** de nada pode avaliar a consciência a 4 Hz; desconfiada ou ciente, volta aos 10 Hz. O custo é, no máximo, cerca de 150 ms a mais para começar a desconfiar, o que é imperceptível e, num jogo de terror, até desejável.

Em escala maior, isso vira **LOD de simulação**: o Interlúdio II constrói o `UVGPopulationSubsystem`, que avalia uma fatia fixa de agentes por passo e põe os distantes em LOD `Reduced`, com tick de 0,25 s no pawn, no controller e nos componentes. É o mesmo raciocínio deste capítulo com centenas de agentes em vez de cinco.

### Animação

Personagens animados custam no game thread e nos *workers*, e a Unreal tem duas alavancas por componente de malha esquelética:

- **URO (*Update Rate Optimizations*)**: com `bEnableUpdateRateOptimizations`, a engine avalia a animação de personagens pequenos na tela (distantes) com menos frequência e interpola. Há um modo de depuração que colore os personagens pela taxa (`bDisplayDebugUpdateRateOptimizations`).
- **`VisibilityBasedAnimTickOption`**: o que fazer quando o personagem **não está sendo renderizado**: continuar avaliando a pose e os ossos, avaliar a pose sem atualizar os ossos, ou parar.

A armadilha específica de um jogo de terror: com `OnlyTickPoseWhenRendered`, um personagem fora da tela não avalia a animação, e os ***Anim Notifies* não disparam**. Os passos da Presença, que vêm de *notifies* na animação de andar (Capítulo 53), **somem** quando ela está atrás da jogadora, que é exatamente quando o som dos passos é a única informação que a jogadora tem. Para a Presença e os vigias, use `AlwaysTickPose` (avalia a pose e dispara os *notifies*, mas só atualiza os ossos quando renderizado). Para figurantes sem som relevante, `OnlyTickPoseWhenRendered` está ótimo. Depois de ligar o URO, **ouça** os passos de novo.

---

## 60.9 *Pooling* e coleta de lixo, revistos

O pool do Capítulo 32 paga quando há **muitos *spawns* repetidos**: projéteis de uma metralhadora, impactos, população. *Spawn* custa construção, registro de componentes, criação de física e `BeginPlay`; destruir custa pressão na coleta de lixo. O pool troca esse custo por memória ocupada e pela obrigação de **reiniciar** o ator corretamente.

Ele **não** paga quando os *spawns* são raros. A Vigília tem, por decisão firmada, no máximo quatro cartuchos de sinalizador: um pool para eles é complexidade sem retorno, e eles continuam sendo spawnados normalmente. O pool continua servindo ao Galpão e à população do Interlúdio II.

Uma armadilha do pool que o Interlúdio II encontra: devolver um ator ao pool desligando só o tick **do ator** deixa os **componentes** ticando. A população resolve isso com um passo de dormência próprio. Ao usar o pool, confira com `DumpTicks` que nada do que está guardado continua trabalhando.

Efeitos do Niagara têm *pooling* próprio, escolhido no *spawn* (o método de pool, como `AutoRelease`, ao criar o sistema por código); use-o para impactos e faíscas repetidos (Capítulo 54).

Sobre a coleta de lixo: se o Insights mostrar coletas como *hitches*, as primeiras perguntas são "quantos objetos estou criando por segundo?" e "algo poderia ser *struct* em vez de `UObject`?". Ajustar o intervalo e as opções incrementais da coleta vem depois, medindo.

---

## 60.10 Consultas espaciais: quando a grade paga

Muitos sistemas perguntam "o que está perto daqui?": a zona segura mais próxima, quantos figurantes testemunharam algo, que ponto de *spawn* está fora de vista. A implementação ingênua percorre **todos** os candidatos: custo proporcional a N, por consulta.

Com dez zonas seguras, percorrer dez é mais rápido que qualquer estrutura. Com centenas de candidatos e várias consultas por frame, uma **grade espacial** paga: o espaço é dividido em células de tamanho fixo, cada objeto é guardado na célula da sua posição, e a consulta olha só as células em volta do ponto.

```cpp
// Laboratório, não Vigília: o miolo de uma grade uniforme em 2D.
// Simplificação: objetos estáticos; os que se movem precisam ser re-inseridos ao mudar de célula.
struct FVGSpatialGrid
{
    float CellSize = 2000.0f; // ≈ o raio típico de consulta
    TMap<FIntPoint, TArray<TWeakObjectPtr<AActor>>> Cells;

    FIntPoint CellOf(const FVector& P) const
    {
        return FIntPoint(FMath::FloorToInt(P.X / CellSize), FMath::FloorToInt(P.Y / CellSize));
    }

    void Add(AActor* Actor) { Cells.FindOrAdd(CellOf(Actor->GetActorLocation())).Add(Actor); }

    /** Candidatos no raio (Radius ≤ CellSize): as 3×3 células em volta; o chamador filtra pela distância exata. */
    void Query(const FVector& Center, TArray<AActor*>& Out) const
    {
        const FIntPoint C = CellOf(Center);
        for (int32 Y = -1; Y <= 1; ++Y)
        {
            for (int32 X = -1; X <= 1; ++X)
            {
                if (const TArray<TWeakObjectPtr<AActor>>* Cell = Cells.Find(C + FIntPoint(X, Y)))
                {
                    for (const TWeakObjectPtr<AActor>& Weak : *Cell)
                    {
                        if (AActor* Actor = Weak.Get()) { Out.Add(Actor); }
                    }
                }
            }
        }
    }
};
```

Antes de escrever a sua, considere o que a engine já tem: **consultas de sobreposição da física** (`OverlapMultiByChannel` e afins) usam a estrutura de aceleração do motor de física e respondem "o que está nesta esfera" sem nenhuma estrutura sua; a engine tem um *octree* genérico (`TOctree2`) e grades de *hash* usadas internamente por sistemas como o Mass (⚠️ confira o que é público na sua versão). A grade própria vale quando os objetos não têm colisão ou quando você precisa de uma pergunta que a física não responde.

**Decisão para a Vigília:** nenhuma grade. Os conjuntos são pequenos (zonas seguras, pontos de busca, checkpoints), e a varredura linear é mais simples e mais rápida. O Interlúdio II, com população, é onde a pergunta muda.

---

## 60.11 Paralelismo

O Capítulo 2 estabeleceu que o estado de gameplay pertence ao game thread. Paralelizar trabalho de gameplay significa respeitar isso:

- **`ParallelFor`** divide um laço entre *workers* e espera todos terminarem. Bom para cálculo puro sobre dados (pontuar mil pontos, suavizar um caminho), em que cada iteração lê dados próprios e escreve num lugar próprio.
- **`UE::Tasks::Launch`** cria uma tarefa assíncrona; o resultado volta ao game thread por uma tarefa de continuação ou por `AsyncTask(ENamedThreads::GameThread, ...)`.
- **Regras:** nada de criar, destruir ou modificar `UObject`s fora do game thread; leituras de dados que o game thread pode estar mudando ao mesmo tempo precisam de cópia ou de sincronização; e o custo de despachar tarefas pequenas pode superar o ganho.

A engine já paraleliza o que mais pesa: avaliação de animação, física, partículas, parte do render. **Decisão para a Vigília:** nenhum paralelismo próprio. Nenhum custo medido de gameplay é grande o bastante para pagar a complexidade. O Interlúdio III, com servidor dedicado e muitos agentes, é onde a pergunta reaparece.

---

## Estudos de caso

### Corredores com curva: o level design como *culling*

**[FATO PÚBLICO — observável jogando]** Jogos de terror em primeira pessoa como *Amnesia* e *Outlast* são construídos majoritariamente com corredores estreitos, salas pequenas, curvas e portas.

**[INFERÊNCIA]** A razão principal é de design: espaços estreitos limitam a visão, criam antecipação e controlam o ritmo (Capítulo 50). O efeito técnico é que quase nada fica à vista ao mesmo tempo, e o *culling* por oclusão trabalha a favor do orçamento. Não sabemos quanto o orçamento pesou nas decisões desses estúdios; sabemos que as duas razões apontam na mesma direção.

**Lição para a Vigília:** a curva do corredor do Interlúdio I é uma decisão de susto e de orçamento ao mesmo tempo. O Salão das Turbinas, o único espaço aberto da Vigília, é onde o orçamento precisa de atenção explícita, e o Capítulo 76 já o marcou como risco.

### *City Sample*: as peças em escala

**[FATO PÚBLICO]** A Epic publicou o projeto *City Sample*, derivado da demonstração *The Matrix Awakens*, como exemplo de uma cidade grande em Unreal 5, construída com *World Partition* e com multidões e trânsito simulados pelo Mass.

**[INFERÊNCIA]** É o caso oposto da Vigília: um mundo onde *streaming*, HLOD e LOD de simulação não são otimizações, são a arquitetura. Agentes de multidão não são atores ricos; são entidades processadas em lote, e só os próximos ganham representação completa.

**Lição para a Vigília:** as técnicas são as mesmas, e o que muda é a escala em que cada uma passa a pagar. O Interlúdio II percorre esse caminho com o `UVGPopulationSubsystem`; a Vigília usa as versões pequenas.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Ordem do ataque | Remover chamada, *cachear*, lote, paralelizar | "Fazer menos vezes" só precisa **parecer** correto |
| *Culling* | Não buscar o que não será exibido (paginação) | A decisão é geométrica e refeita a cada frame |
| LOD e HLOD | Resumos e agregados pré-calculados | A troca precisa ser invisível, e a "visibilidade" é ótica |
| Significance Manager | Priorização por relevância, filas com prioridade | A relevância muda a cada frame com a câmera |
| URO | *Sampling* de métricas em baixa frequência | Pular a avaliação pode silenciar efeitos (os *notifies*) |
| Carga assíncrona | *Prefetch*, *lazy loading* | O prazo é o próximo frame; a falta vira *hitch* visível |
| Grade espacial | Índice geoespacial | Os objetos se movem e o índice precisa acompanhar |

---

## Unreal Engine: o que existe

- ***Culling***: *frustum* e oclusão automáticos; *Desired Max Draw Distance*; *Cull Distance Volume*; `FreezeRendering` para inspeção.
- **LOD**: geração automática por redução, *LOD Groups*, LODs de malhas esqueléticas, transição suavizada.
- **HLOD** em camadas no *World Partition*.
- **Nanite**, com a lista de recursos suportados por versão.
- **Escalabilidade** (`sg.*`), resolução dinâmica, TSR.
- ***World Partition***, *Level Streaming*, *Data Layers*, `FStreamableManager` (`UAssetManager::GetStreamableManager()`).
- **Tick**: `bCanEverTick`, `bStartWithTickEnabled`, `TickInterval`, `SetComponentTickEnabled`, `DumpTicks`.
- **Significance Manager** (*plugin*).
- **IA**: intervalo e desvio aleatório de serviços de BT, custo de testes de EQS, limite de tempo de teste do EQS, limites do sentido de visão.
- **Animação**: URO, `VisibilityBasedAnimTickOption`.
- ***Pooling***: o do Capítulo 32 e o do Niagara.
- **Paralelismo**: `ParallelFor`, `UE::Tasks`, `AsyncTask`.

O que a engine **não** dá: a política. Ela não sabe quais sombras a jogadora vê, quais passos ela precisa ouvir, nem quanto da Presença pode ser economizado sem que o medo diminua.

---

## Abordagens

Para a H4 (relevância das lâmpadas):

| Critério | A. Distância em cada componente | **B. Significance Manager** | C. Um gerenciador próprio que tica todas as lâmpadas |
|---|---|---|---|
| **Complexidade** | Mínima | Baixa: registro + duas funções | Média: lista, ordem, ciclo de vida |
| **Performance** | Boa, mas cada componente ainda tica para checar | Boa: avaliação central, componentes desligados de fato | Ótima em lote |
| **Extensibilidade** | A regra se repete em cada tipo de objeto | Uma *tag* por tipo, políticas por orçamento | Um gerenciador por tipo |
| **Manutenção** | Regras espalhadas | Um lugar | Um lugar, mas é código seu |
| **Prototipação** | Imediata | Rápida | Lenta |
| **Adequação à Vigília** | Suficiente hoje | **Sim**: a mesma pergunta vai servir a outros objetos | Excesso |

**Decisão: B**, com a política em funções puras e testadas. A abordagem A é a resposta certa para um tipo de objeto só e uma regra que nunca muda; a Vigília já tem um segundo candidato (o som ambiente) e uma política por orçamento em vista.

---

## Implementação

### 1. A política, pura

```cpp
// Source/Vigilia/World/VGSignificanceRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGSignificanceRules
{
    /** 0..1. Perto e à frente da câmera ≈ 1; além de MaxDistance = 0; atrás conta metade (a luz vaza). */
    float FlickerSignificance(float Distance, float FacingDot, float MaxDistance);

    /** Intervalo de tick para a significância: 0 = todo frame; negativo = parado no último valor. */
    float FlickerTickInterval(float Significance);
}
```

```cpp
// Source/Vigilia/World/VGSignificanceRules.cpp
#include "World/VGSignificanceRules.h"

float VGSignificanceRules::FlickerSignificance(float Distance, float FacingDot, float MaxDistance)
{
    if (MaxDistance <= 0.0f || Distance >= MaxDistance)
    {
        return 0.0f;
    }
    const float Near = 1.0f - Distance / MaxDistance;
    const float Facing = FMath::GetMappedRangeValueClamped(FVector2f(-1.0f, 1.0f), FVector2f(0.5f, 1.0f), FacingDot);
    return Near * Facing;
}

float VGSignificanceRules::FlickerTickInterval(float Significance)
{
    if (Significance >= 0.5f)
    {
        return 0.0f;  // perto e à vista: todo frame
    }
    if (Significance >= 0.1f)
    {
        return 0.1f;  // 10 Hz: o olho não separa
    }
    return -1.0f;     // longe: parado no último valor
}
```

### 2. As lâmpadas se registram

🔁 `UVGFlickerComponent` (Capítulos 9 e 11):

```cpp
// UVGFlickerComponent.h (adição)
/** Além desta distância (cm), o flicker para no último valor (Cap. 60). */
UPROPERTY(EditAnywhere, Category = "Vigilia|Flicker", meta = (ClampMin = "100.0"))
float SignificanceDistance = 4000.0f;
```

```cpp
// UVGFlickerComponent.cpp (adições)
#include "SignificanceManager.h"
#include "World/VGSignificanceRules.h"

static const FName FlickerSignificanceTag(TEXT("VGFlicker"));

void UVGFlickerComponent::BeginPlay()
{
    Super::BeginPlay();
    // ... como antes ...
    USignificanceManager* Significance = FSignificanceManagerModule::Get(GetWorld());
    if (!Significance)
    {
        return; // sem plugin ou sem manager: o flicker continua ticando todo frame, como antes
    }
    Significance->RegisterObject(this, FlickerSignificanceTag,
        // Avaliação: pode rodar em paralelo. Só LEIA.
        [](USignificanceManager::FManagedObjectInfo* Info, const FTransform& View) -> float
        {
            const UVGFlickerComponent* Flicker = CastChecked<UVGFlickerComponent>(Info->GetObject());
            const FVector ToLamp = Flicker->GetOwner()->GetActorLocation() - View.GetLocation();
            const float Distance = ToLamp.Size();
            const float Facing = Distance > KINDA_SMALL_NUMBER
                ? FVector::DotProduct(ToLamp / Distance, View.GetRotation().GetForwardVector())
                : 1.0f;
            return VGSignificanceRules::FlickerSignificance(Distance, Facing, Flicker->SignificanceDistance);
        },
        // Ação: em sequência, no game thread, porque mexe no tick do componente.
        USignificanceManager::EPostSignificanceType::Sequential,
        [](USignificanceManager::FManagedObjectInfo* Info, float OldSignificance, float NewSignificance, bool bFinal)
        {
            if (bFinal)
            {
                return; // desregistrando
            }
            UVGFlickerComponent* Flicker = CastChecked<UVGFlickerComponent>(Info->GetObject());
            const float Interval = VGSignificanceRules::FlickerTickInterval(NewSignificance);
            Flicker->SetComponentTickEnabled(Interval >= 0.0f);
            if (Interval >= 0.0f)
            {
                Flicker->SetComponentTickInterval(Interval);
            }
        });
}

void UVGFlickerComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (USignificanceManager* Significance = FSignificanceManagerModule::Get(GetWorld()))
    {
        Significance->UnregisterObject(this);
    }
    Super::EndPlay(EndPlayReason);
}
```

O flicker usa tempo de jogo (Capítulo 9); com intervalo, o `DeltaTime` acumulado mantém o padrão andando na velocidade certa, só com menos amostras. A opção de acessibilidade `vg.Flicker.Enabled` (Capítulo 11) continua mandando: com ela desligada, nada pisca, em qualquer significância.

### 3. Quem chama `Update`

```cpp
// AVGPlayerController (adição)
virtual void PlayerTick(float DeltaTime) override;
```

```cpp
// AVGPlayerController.cpp (adição)
#include "SignificanceManager.h"

void AVGPlayerController::PlayerTick(float DeltaTime)
{
    Super::PlayerTick(DeltaTime);
    // Uma vez por frame, do ponto de vista da câmera. Simplificação: um jogador (a Parte IX revê).
    USignificanceManager* Significance = FSignificanceManagerModule::Get(GetWorld());
    if (Significance && PlayerCameraManager)
    {
        const FTransform View(PlayerCameraManager->GetCameraRotation(), PlayerCameraManager->GetCameraLocation());
        Significance->Update(TArrayView<const FTransform>(&View, 1));
    }
}
```

`Build.cs`: acrescente `"SignificanceManager"`, e habilite o *plugin* *Significance Manager* no projeto.

### 4. A consciência por estado

🔁 `UVGAwarenessComponent` (Capítulo 36), no ponto em que a transição de estado já acontece:

```cpp
// Ao mudar de estado (depois de atualizar State e antes de anunciar, como no Cap. 36)
// Simplificação: dois degraus. Desconfiada ou ciente, os 10 Hz do Cap. 36; sem desconfiar, 4 Hz.
SetComponentTickInterval(State == EVGAwarenessState::Unaware ? 0.25f : 0.1f);
```

### 5. Configuração, sem código

- **Presença e vigias** (classe C++ dos inimigos ou `BP_Presenca`/`BP_Vigia`), no componente de malha: `VisibilityBasedAnimTickOption = AlwaysTickPose` e `bEnableUpdateRateOptimizations = true`. Depois, ouça os passos atrás de você.
- **Consulta de busca da Presença** (H2): serviço da caçada com intervalo de 0,5 s e *Random Deviation* de 0,15; gerador com espaçamento maior; testes baratos primeiro; limite de tempo de EQS por frame na configuração do `EnvQueryManager`.
- **Névoa da curva** (H5): de cinco *cards* sobrepostos para dois, menores, com *depth fade*; confira no *Quad Overdraw*.
- **Lâmpadas** (H1, já aplicado no Cap. 59): sombra só nas duas que contam; *Max Draw Distance* nas lâmpadas pequenas.

O PSO da Presença (H3) não se resolve neste capítulo: o cache e a pré-compilação de PSO dependem da configuração do build e do RHI, e o Capítulo 62 trata disso junto com o empacotamento.

### Explicação das decisões

- **Política em funções puras.** O manager avalia; as regras de quanto vale uma lâmpada e do que fazer com o valor são números testáveis, fora de qualquer componente.
- **`Sequential` na ação.** A ação liga e desliga ticks de componentes, e isso é estado do game thread.
- **Sem manager, comportamento antigo.** Se o *plugin* faltar, as lâmpadas ticam todo frame, como antes. A otimização é aditiva e não quebra o jogo.
- **Um ponto de vista, chamado pelo controller.** Single-player, uma câmera. A Parte IX, com duas jogadoras, passa dois pontos de vista para o mesmo `Update`, e a política continua igual.
- **A Presença perde frequência, não presença.** Os 4 Hz valem só sem desconfiança, e a animação continua disparando *notifies* fora da tela. O que a jogadora ouve não muda.
- **Duas recusas declaradas.** Carga assíncrona de vozes e grade espacial ficam documentadas e **não** aplicadas, porque nenhuma medição da Vigília pede.

### 6. Teste

```cpp
// Source/Vigilia/Tests/VGSignificanceRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "World/VGSignificanceRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGSignificanceRulesTest, "Vigilia.Perf.Significance.FlickerPolicy",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGSignificanceRulesTest::RunTest(const FString& Parameters)
{
    using namespace VGSignificanceRules;
    const float Max = 4000.0f;

    TestEqual(TEXT("Colada e à frente"), FlickerSignificance(0.0f, 1.0f, Max), 1.0f);
    TestEqual(TEXT("Além do limite"), FlickerSignificance(Max, 1.0f, Max), 0.0f);
    TestEqual(TEXT("Atrás conta metade"), FlickerSignificance(0.0f, -1.0f, Max), 0.5f);
    TestTrue(TEXT("Perto vale mais que longe"), FlickerSignificance(500.0f, 1.0f, Max) > FlickerSignificance(3000.0f, 1.0f, Max));

    TestEqual(TEXT("Alta: todo frame"), FlickerTickInterval(0.8f), 0.0f);
    TestEqual(TEXT("Média: 10 Hz"), FlickerTickInterval(0.3f), 0.1f);
    TestTrue(TEXT("Baixa: parada"), FlickerTickInterval(0.05f) < 0.0f);

    // A política em conjunto: uma lâmpada colada atrás da jogadora ainda pisca a 10 Hz (a luz vaza).
    TestEqual(TEXT("Perto e atrás"), FlickerTickInterval(FlickerSignificance(200.0f, -1.0f, Max)), 0.1f);
    return true;
}

#endif
```

---

## Projeto Vigília — fechando as hipóteses

### Aplicar e medir, uma por vez

Volte ao cenário do Capítulo 59 (`VGPerfHunt`, três repetições quentes e uma fria) e aplique as mudanças **uma de cada vez**, na ordem da tabela, medindo depois de cada uma:

| # | Mudança | O que medir além da linha `PERF` | Verificação sensorial |
|---|---|---|---|
| H4 | Significance nas lâmpadas | `Flicker Ticks` por frame no `stat Vigilia` | As lâmpadas à vista piscam igual? |
| H2 | EQS espalhado, menos pontos | Escopos de EQS nos piores frames (Insights) | A Presença ainda procura bem? |
| — | Consciência a 4 Hz sem desconfiança | `Awareness Tick` | O tempo até ela desconfiar mudou de forma perceptível? |
| — | `AlwaysTickPose` + URO nos inimigos | `stat anim` | Os passos atrás de você continuam soando? |
| H5 | Névoa com menos camadas | Translucidez no `stat gpu` | A curva continua enevoada? |

Registre cada linha no `DEVLOG.md` como no Capítulo 59: hipótese, mudança, antes, depois, decisão. Algumas mudanças vão ganhar pouco: a significância de quarenta lâmpadas custa microssegundos, e o ganho em milissegundos pode ficar abaixo da variação entre repetições. **Registre assim mesmo.** "Não ganhou o suficiente para medir" é um resultado, e a decisão de manter vem de outra razão (aqui, a arquitetura que vai servir a outros objetos).

### As 80 portas

Rode `DumpTicks` na Casa de Força com todas as portas paradas. Nenhuma porta pode aparecer habilitada. Abra uma e rode de novo. Copie as duas saídas (só as linhas das portas) para o `DEVLOG.md`: a promessa do Capítulo 1 agora tem prova.

### O Salão das Turbinas, antes de existir

O setor ainda não existe, mas a decisão de arquitetura dele (Capítulo 77) já tem critérios:

| Se o profiling do *blockout* do salão mostrar… | Então… |
|---|---|
| Render thread pressionado por quantidade de objetos | Nanite para a geometria estática densa, *instancing* para repetições |
| GPU pressionada por Lumen num espaço aberto | Escalabilidade de Lumen por preset; luzes com sombra só onde contam |
| Memória acima do orçamento com o salão inteiro carregado | *World Partition* (ou subníveis), com HLOD para o lado distante |
| Nada disso | Nível comum, como a Casa de Força |

### O inventário de dores

Nenhuma dor do Interlúdio I era de performance. Mas a pergunta que o Capítulo 1 fez, "se a usina tem 80 portas, quanto elas custam paradas?", agora tem resposta medida.

---

## Decisões arquiteturais

1. **Ordem do ataque**: não fazer, menos vezes, menos coisas, mais barato, paralelo; cada mudança responde a uma hipótese medida e passa por verificação sensorial.
2. **Sombra só onde a jogadora a vê**; luzes com raio e distância de desenho escolhidos; translucidez com poucas camadas.
3. **Nanite, *World Partition* e HLOD decididos por profiling do Salão das Turbinas** (Cap. 77), com critérios escritos.
4. **Significance Manager para relevância**, com política em funções puras e ação `Sequential`; o controller chama `Update` uma vez por frame.
5. **IA e animação em frequência reduzida sem perder informação**: consciência a 4 Hz só sem desconfiança; `AlwaysTickPose` nos inimigos para os *notifies* de passo.
6. **Recusas declaradas**: sem carga assíncrona de vozes, sem grade espacial, sem pool de sinalizadores e sem paralelismo próprio, até uma medição pedir.

---

## Armadilhas

- **Otimizar sem hipótese medida.** É o atalho para três mudanças misturadas e um ganho que ninguém sabe de onde veio.
- **Ganhar milissegundos e perder a experiência.** Sombras que contavam a história, passos que sumiram, névoa que deixou de esconder. Toda mudança tem verificação sensorial.
- **`OnlyTickPoseWhenRendered` em quem faz barulho.** Os *notifies* não disparam fora da tela.
- **Intervalos alinhados.** Vários componentes com o mesmo intervalo ticam no mesmo frame e criam um pico periódico.
- **Pool para *spawns* raros.** Complexidade, memória ocupada e bugs de reinício, sem retorno.
- **Devolver ao pool sem dormir os componentes.** O ator "guardado" continua trabalhando.
- **Trocar `LoadSynchronous` por carga assíncrona sem plano para "ainda não chegou".** O asset que não carregou a tempo precisa de um comportamento definido (a legenda sem voz), não de um ponteiro nulo.
- **Nanite e *World Partition* por moda.** Eles mudam o modelo de custo e o fluxo de trabalho; decida por medição e conferindo o suporte da sua versão.
- **Paralelizar gameplay que mexe em `UObject`s.** Corrida de dados e *crash* intermitente, o pior tipo de bug (Capítulo 61).

---

## Exercício

**Parte 1 — significância (1,5 h).** Habilite o *plugin*, implemente `VGSignificanceRules`, o teste, o registro no `UVGFlickerComponent` e o `Update` no controller. Com `stat Vigilia`, confira os `Flicker Ticks` por frame no corredor, de frente e de costas para as lâmpadas.

**Parte 2 — IA e animação (1,5 h).** Aplique o intervalo por estado na consciência e a configuração de animação nos inimigos. Com a Presença atrás de você, sem renderizar, confirme que os passos soam. Depois troque para `OnlyTickPoseWhenRendered` por um momento e ouça a diferença.

**Parte 3 — as hipóteses (2 h).** Aplique H2, H4 e H5, uma por vez, com medição e verificação sensorial, e preencha a tabela do Projeto no `DEVLOG.md`.

**Parte 4 — as 80 portas e o *culling* (45 min).** Faça a prova com `DumpTicks`. Depois, no corredor, use `FreezeRendering` antes da curva e ande até depois dela: o que a engine tinha decidido não desenhar?

---

## Desafio — as N lâmpadas mais importantes

A política deste capítulo decide cada lâmpada pela própria significância. Troque-a por uma política de **orçamento**:

1. Só as **6** lâmpadas mais significativas ticam todo frame; as **10** seguintes, a 10 Hz; o resto para. (Dica: o manager ordena os objetos de uma *tag*; ⚠️ confira na sua versão como obter a lista ordenada.)
2. Compare com a política por limiar em dois lugares: o corredor (muitas lâmpadas juntas) e uma sala com duas lâmpadas. Qual política se comporta melhor em cada um?
3. Responda no `DEVLOG.md`: por que uma política por orçamento é impossível com a abordagem A (distância em cada componente)? Que outro sistema da Vigília se beneficiaria de um orçamento "top N"?

---

## Uso de IA

1. **Para revisar uma mudança de otimização:**
   > "Mudei [descrição] para reduzir o custo de [sistema] num jogo de terror em Unreal Engine 5. A medição antes/depois foi [números]. Liste o que essa mudança pode ter quebrado na experiência (som, leitura visual, comportamento da IA, casos de borda de estado), e como eu testaria cada item."

2. **Para escolher a alavanca:**
   > "Este é o custo medido de [sistema], com a frequência e o número de objetos: [dados]. Usando a ordem 'não fazer, fazer menos vezes, fazer para menos coisas, fazer mais barato, paralelizar', proponha uma opção em cada degrau, com o risco perceptível de cada uma."

3. **Para conferir uma API:**
   > "Quero registrar componentes no Significance Manager da Unreal Engine [versão]. Mostre as assinaturas de RegisterObject, Update e dos tipos de função, e diga quais partes você tem certeza de que existem nessa versão e quais devo conferir no SignificanceManager.h."

**Cuidado específico:** a IA sugere otimizações genéricas de Unreal (desligar Lumen, reduzir a resolução, usar Nanite em tudo, pool para tudo) sem saber qual estágio limita o seu jogo e o que a sua experiência precisa. Uma lista de "dez dicas de performance" é o oposto do método do Capítulo 59. Dê à IA a medição e a hipótese, e peça crítica, não receitas.

---

## Checklist

- [ ] Sei a ordem do ataque e escolho a alavanca pela hipótese medida.
- [ ] Sei usar *culling*, LOD, HLOD e quando Nanite é candidato, conferindo o suporte da minha versão.
- [ ] Trato sombras e translucidez como custos de decisão, não de padrão.
- [ ] Sei o que o *World Partition* resolve e o que custa entrar uma célula; sei carregar assets sem travar.
- [ ] Meus ticks estão desligados, condicionados, com intervalo ou por relevância, e provei as 80 portas com `DumpTicks`.
- [ ] Usei o Significance Manager com política testada e ação no game thread.
- [ ] Reduzi a frequência da IA e da animação sem perder os passos da Presença.
- [ ] Sei quando pool, grade espacial e paralelismo pagam, e registrei por que a Vigília não usa os três.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Visibility and Occlusion Culling**, as páginas sobre **LODs** de malhas estáticas e esqueléticas, **World Partition** (*HLOD*, *Data Layers*), **Nanite Virtualized Geometry** (com a lista de recursos suportados da sua versão), **Significance Manager**, **Animation Optimization** (URO e `VisibilityBasedAnimTickOption`), **Asynchronous Asset Loading** e **Environment Query System** (configurações de desempenho).
- ***Game Programming Patterns***, de Robert Nystrom: os capítulos *Object Pool*, *Spatial Partition* e *Dirty Flag* tratam, fora de qualquer engine, de três técnicas deste capítulo.
- ***Real-Time Rendering***, de Akenine-Möller, Haines e Hoffman: *culling*, LOD e custo de sombras e transparência explicados do lado da GPU.
- **GDC Vault** (gdcvault.com): palestras sobre otimização de jogos em Unreal e sobre *streaming* de mundos (procure por "World Partition", "Nanite" e "optimization"; confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 61 — Debugging](cap-61-debugging.md)

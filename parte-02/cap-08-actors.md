# Capítulo 8 — Actors

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar a relação entre `UObject` e `AActor`, e o que um Actor tem que um objeto comum não tem;
- entender o **Class Default Object (CDO)** e por que o construtor de um Actor não é o lugar para lógica de gameplay;
- descrever o **ciclo de vida completo** de um Actor — colocado no nível ou criado em runtime — e em que etapa cada tipo de inicialização deve acontecer;
- trabalhar com **transforms**, espaços local e mundo, e mover atores com e sem *sweep*;
- **criar** atores em runtime (`SpawnActor`, spawn diferido, `TSubclassOf`) e **destruí-los** com segurança;
- entender `UWorld`, níveis, *Owner* e *Instigator*;
- implementar o `AVGSpawner`, que evoluirá até o sistema de spawn do Capítulo 32.

---

## Contexto

No Capítulo 6, a decisão de arquitetura foi: tudo que existe no mundo é um **Actor com componentes**. Agora é hora de entender o que isso significa concretamente.

Para quem vem de Java, a tentação é pensar em um Actor como "um objeto com uma posição". Ele é bem mais do que isso — e bem mais restrito. Um Actor tem **ciclo de vida controlado pela engine**: você não chama `new AVGDoor()`; você pede ao mundo que crie um, e o mundo decide quando ele é construído, inicializado, atualizado e destruído. Você não o apaga com `delete`; você pede que ele seja destruído, e o garbage collector da Unreal decide quando liberar a memória.

> 🌉 **Ponte:** o modelo mais próximo que você conhece é o **ciclo de vida de beans** num contêiner: você não instancia o bean, o contêiner cria, injeta, chama `@PostConstruct`, gerencia e, no fim, chama `@PreDestroy`.
>
> 🧱 **Onde a ponte cai:** beans são, em geral, poucos e longevos. Atores são **muitos**, criados e destruídos o tempo todo (projéteis, efeitos, inimigos), e o "contêiner" — o mundo — é recriado a cada troca de nível. Além disso, existe uma etapa sem análogo no Spring: o **Class Default Object**, descrito a seguir.

---

## 8.1 UObject e AActor

A hierarquia básica de tipos da Unreal:

```text
UObject                  reflexão, garbage collection, serialização, nome, outer
  │
  ├── UActorComponent    capacidade anexável a um Actor (Cap. 9)
  │     └── USceneComponent    + transform e hierarquia
  │           └── UPrimitiveComponent    + geometria, colisão, renderização
  │
  └── AActor             objeto que existe num mundo
        ├── APawn            pode ser possuído por um Controller (Cap. 10)
        │     └── ACharacter     pawn humanoide com movimento pronto (Cap. 17)
        ├── AController      a "vontade" que possui pawns (Cap. 10, 16)
        ├── AInfo            atores sem presença física (GameMode, GameState...)
        └── ... (luzes, câmeras, volumes, etc.)
```

**`UObject`** é a base de quase tudo que a engine gerencia. Ele traz:

- **reflexão** — a engine sabe quais propriedades e funções a classe tem (é o que alimenta o editor e o Blueprint);
- **garbage collection** — objetos alcançáveis a partir de raízes são mantidos; inalcançáveis são coletados;
- **serialização** — propriedades marcadas podem ser salvas em assets e níveis;
- **nome e *Outer*** — todo `UObject` tem um nome e um objeto "dono" na hierarquia de objetos (um ator tem como *Outer* o seu nível; um componente, o seu ator).

**`AActor`** acrescenta tudo que é necessário para existir **num mundo**:

- pertence a um `ULevel` dentro de um `UWorld`;
- tem uma **posição no espaço** (através do seu componente raiz);
- pode **tickar** (Capítulo 2);
- contém **componentes**;
- pode ser **replicado** em rede (Parte IX);
- tem um **ciclo de vida de gameplay** (`BeginPlay`, `EndPlay`).

Os prefixos de nome não são estilo: **`A`** para classes derivadas de `AActor`, **`U`** para derivadas de `UObject` (incluindo componentes), **`F`** para structs e tipos que não são `UObject`, **`E`** para enums, **`I`** para interfaces, **`T`** para templates. O UHT exige os prefixos corretos em classes reflexivas.

---

## 8.2 O Class Default Object

Este é o conceito que mais confunde programadores experientes nas primeiras semanas de Unreal — e entendê-lo evita uma categoria inteira de bugs.

Para cada classe `UObject` (incluindo cada classe de Actor e cada Blueprint), a engine cria, no carregamento, **uma instância especial chamada Class Default Object (CDO)**. O CDO guarda os **valores padrão** daquela classe. Quando você cria uma nova instância, ela é **inicializada copiando o CDO**.

```text
              construtor de AVGSpawner executa para criar o CDO
                                  │
                                  ▼
                   ┌──────────────────────────────┐
                   │  CDO de AVGSpawner            │  SpawnInterval = 2.0
                   │  (Default__VGSpawner)         │  MaxAlive = 5
                   └──────────────┬───────────────┘
                                  │ Blueprint BP_SpawnerCaixas herda e
                                  │ sobrescreve padrões → tem SEU próprio CDO
                                  ▼
                   ┌──────────────────────────────┐
                   │  CDO de BP_SpawnerCaixas      │  SpawnInterval = 0.5
                   └──────────────┬───────────────┘
                     cada instância no nível copia o CDO
                     e pode sobrescrever valores por instância
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
            Spawner_Galpao              Spawner_Patio
            SpawnInterval = 0.5         SpawnInterval = 3.0 (sobrescrito)
```

Consequências práticas:

1. **O construtor C++ de um Actor executa para criar o CDO**, muito antes de existir qualquer mundo de jogo — no carregamento do editor ou do jogo. E executa de novo para cada instância criada.
2. **No construtor, não existe mundo.** `GetWorld()` pode ser nulo; não há outros atores; não há jogador. Lógica de gameplay no construtor quebra (ou, pior, funciona por acaso no editor e quebra no jogo).
3. **O construtor serve para definir padrões e criar componentes** (`CreateDefaultSubobject`, Capítulo 9) — exatamente o que vai ser copiado para todas as instâncias.
4. **Valores por instância sobrescrevem o CDO.** No painel Details, propriedades com valor diferente do padrão mostram uma seta amarela de "restaurar padrão". O nível salva apenas as diferenças.

> 🌉 **Ponte:** o CDO é o **protótipo** do padrão Prototype (GoF): novas instâncias são clones de um objeto modelo. Também lembra as definições de bean com escopo *prototype*, cujo modelo vem da configuração.
>
> 🧱 **Onde a ponte cai:** em Java, o construtor executa uma vez por instância e só. Na Unreal, ele executa **também para o CDO**, num contexto sem mundo — e Blueprints filhos criam seus próprios CDOs. Código que assume "o construtor só roda quando o objeto entra no jogo" está errado.

---

## 8.3 O ciclo de vida de um Actor

O ciclo de vida tem caminhos diferentes para atores **colocados no nível** (salvos no `.umap`) e atores **criados em runtime** (spawn). A versão simplificada, com as etapas que você vai sobrescrever com frequência:

```text
  ATOR CRIADO EM RUNTIME (SpawnActor)          ATOR CARREGADO DO NÍVEL
  ───────────────────────────────────          ───────────────────────
  construtor (cópia do CDO)                    construtor (cópia do CDO)
        │                                      desserialização das propriedades
        ▼                                      salvas no nível (PostLoad)
  PostActorCreated                                     │
        │                                              │
        ▼                                              │
  OnConstruction  ◄── "Construction Script"            │
        │             (também roda NO EDITOR,          │
        │              a cada mudança)                 │
        └─────────────────────┬────────────────────────┘
                              ▼
                  PreInitializeComponents
                              ▼
            (InitializeComponent de cada componente)
                              ▼
                  PostInitializeComponents   ← componentes prontos; ainda sem BeginPlay
                              ▼
                         BeginPlay           ← o mundo está rodando: lógica de gameplay começa
                              ▼
                     Tick (todo frame)       ← se habilitado
                              ▼
                  EndPlay(Reason)            ← Destroyed, LevelTransition, EndPlayInEditor,
                              ▼                 RemovedFromWorld, Quit
                         Destroyed           ← só em destruição explícita (ver "Detalhes que importam")
                              ▼
                 (coletado pelo GC mais tarde)
```

### O que fazer em cada etapa

| Etapa | Use para | Não use para |
|---|---|---|
| **Construtor** | Criar componentes; definir valores padrão; configurar tick | Acessar o mundo, outros atores, assets carregados dinamicamente |
| **OnConstruction** | Lógica que depende de propriedades editadas e deve se refletir **no editor** (ex.: gerar N postes ao longo de uma cerca conforme um parâmetro) | Lógica de gameplay; roda muitas vezes no editor |
| **PostInitializeComponents** | Ligar componentes entre si (inscrever-se em eventos de um componente próprio) | Interagir com outros atores (eles podem não estar prontos) |
| **BeginPlay** | **Início da lógica de gameplay:** inscrever-se em eventos externos, buscar subsistemas, iniciar timers, registrar-se em sistemas | — é o lugar padrão |
| **Tick** | Atualização contínua (Capítulo 2) | Inicialização tardia "na primeira vez que tickar" |
| **EndPlay** | **Limpar:** cancelar timers, desinscrever-se de eventos, liberar pedidos a subsistemas (Capítulo 6) | Assumir que outros atores ainda existem |

### Detalhes que importam

- **`OnConstruction` roda no editor.** Cada vez que você move o ator ou muda uma propriedade no Details, o *construction script* é executado novamente. É o que permite criar ferramentas de level design (uma cerca que se estende sozinha). Também é por isso que não se coloca lógica de gameplay lá.
- **A ordem de `BeginPlay` entre atores não é garantida.** Se o ator A, no seu `BeginPlay`, depende de que o ator B já tenha executado o `BeginPlay` dele, você tem uma dependência de ordem implícita — o mesmo problema dos tick groups (Capítulo 2). Soluções: não depender (preferível), adiar para o próximo frame, ou fazer B **anunciar** que está pronto (Capítulo 4).
- **`EndPlay` tem um motivo.** `EEndPlayReason::Destroyed` (o ator foi destruído), `LevelTransition` (troca de nível), `EndPlayInEditor` (parou o PIE), `RemovedFromWorld` (nível descarregado por streaming), `Quit` (o jogo fechou). Às vezes a limpeza depende do motivo: um ator destruído em combate pode deixar um efeito; um ator removido por streaming, não.
- **`Destroyed` envolve o `EndPlay`.** Numa destruição explícita (`Destroy`, `SetLifeSpan`), é a própria `AActor::Destroyed()` que chama `EndPlay(EEndPlayReason::Destroyed)` e só depois dispara o *Event Destroyed* do Blueprint e o delegate `OnDestroyed` — daí a ordem do diagrama. Por isso o probe abaixo registra `Destroyed` **depois** do `Super::Destroyed()`. Em troca de nível ou ao parar o PIE, em geral só o `EndPlay` acontece; o probe confirma na sua versão.
- **Sempre chame `Super::`.** Em `BeginPlay`, `EndPlay`, `Tick`, `PostInitializeComponents`: a implementação da classe base faz trabalho essencial (no caso de `BeginPlay`, inclusive disparar o evento *BeginPlay* do Blueprint e iniciar o *life span*). Esquecer o `Super::BeginPlay()` é um dos bugs mais comuns de iniciante — e um dos mais confusos, porque o Blueprint filho "simplesmente não executa".

---

## 8.4 Transforms

Todo Actor com presença no espaço tem um **transform**: posição (*location*), rotação (*rotation*) e escala (*scale*). Na Unreal:

- `FVector` — posição ou direção, em centímetros (`X` para frente, `Y` para a direita, `Z` para cima, num sistema de coordenadas *left-handed*, com `Z` para cima).
- `FRotator` — rotação como três ângulos em graus: **Pitch** (inclinação para cima/baixo, em torno de Y), **Yaw** (giro para os lados, em torno de Z), **Roll** (rolamento, em torno de X). Intuitivo para editar; o Capítulo 18 explica por que, internamente, rotações compostas usam `FQuat` (quaternions).
- `FTransform` — a combinação de posição, rotação (como quaternion) e escala.

O transform de um Actor **é o transform do seu componente raiz** (Capítulo 9). Componentes filhos têm transforms **relativos** ao pai; o transform em **espaço de mundo** é a composição de toda a cadeia.

```cpp
const FVector WorldLocation = GetActorLocation();        // espaço de mundo
const FRotator WorldRotation = GetActorRotation();
const FVector Forward = GetActorForwardVector();          // direção X do ator, no mundo

SetActorLocation(NewLocation);                            // teleporta
SetActorLocation(NewLocation, /*bSweep=*/true, &Hit);     // move testando colisão no caminho
AddActorWorldOffset(FVector(0.0, 0.0, 10.0), /*bSweep=*/true);
```

O parâmetro **`bSweep`** é a ponte com o Capítulo 3: sem sweep, o ator **teleporta** e pode atravessar paredes (*tunneling*); com sweep, a engine testa a colisão ao longo do caminho e para no primeiro bloqueio, preenchendo um `FHitResult`. Movimento de personagem usa sweep o tempo todo (o `CharacterMovementComponent` faz isso por você no Capítulo 17).

> **Ator estático vs. móvel.** Componentes têm uma propriedade **Mobility**: *Static* (nunca se move; permite iluminação pré-calculada e otimizações), *Stationary* (luzes que não se movem mas mudam de intensidade) e *Movable* (pode se mover em runtime). Tentar mover em runtime um ator *Static* gera um aviso e não funciona. Para o grey-box, as paredes do pátio podem ser *Static*; uma porta, uma lâmpada que balança ou um objeto criado em runtime precisa ser *Movable*.

---

## 8.5 O mundo e os níveis

`UWorld` é o contêiner da simulação (Capítulo 2). Ele contém um ou mais **níveis** (`ULevel`):

- o **nível persistente** — sempre carregado enquanto o mundo existe;
- **níveis de streaming** — carregados e descarregados dinamicamente (Capítulo 57), ou células do **World Partition** em mundos grandes (Capítulo 60).

Todo Actor pertence a exatamente um nível. Para chegar ao mundo a partir de um ator, de um componente ou de qualquer objeto com contexto de mundo: `GetWorld()`.

### Encontrar outros atores

A forma mais direta — e a mais abusada — é iterar o mundo:

```cpp
for (TActorIterator<AVGSpawner> It(GetWorld()); It; ++It)
{
    AVGSpawner* Spawner = *It;
    // ...
}
// ou, em Blueprint/C++: UGameplayStatics::GetAllActorsOfClass(...)
```

Isso percorre os atores do mundo. É aceitável **uma vez**, numa inicialização, num mundo pequeno. É um problema dentro de `Tick`, ou como forma padrão de comunicação entre sistemas. As alternativas melhores, em ordem de preferência:

1. **Referência editável** — o designer aponta, no editor, qual ator se conecta a qual (uma porta aponta para o painel elétrico que a destranca). Barato, explícito, visível.
2. **Registro em um subsistema** — atores se registram num `UWorldSubsystem` no `BeginPlay` e se removem no `EndPlay` (Capítulo 6). O subsistema mantém a lista.
3. **Eventos e interfaces** — em vez de procurar quem reage, anunciar (Capítulo 4).
4. **Consultas espaciais** — traces e overlaps, quando a pergunta é espacial ("o que está à minha frente?") (Capítulo 15).

---

## 8.6 Criando atores em runtime

### `SpawnActor` e `TSubclassOf`

Para criar um ator, peça ao mundo:

```cpp
FActorSpawnParameters Params;
Params.Owner = this;
Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

AActor* Spawned = GetWorld()->SpawnActor<AActor>(ActorClass, GetActorTransform(), Params);
```

`ActorClass` é do tipo **`TSubclassOf<AActor>`**: uma referência a uma **classe** (não a uma instância), restrita a subclasses de `AActor`. Exposta como `UPROPERTY(EditAnywhere)`, ela aparece no editor como um seletor de classe — e é assim que **o designer escolhe o Blueprint** que será criado, sem que o C++ precise conhecê-lo. É a regra de camadas do Capítulo 6 em ação: o sistema (C++) sabe *criar coisas*; o conteúdo (editor) decide *quais coisas*.

O parâmetro `SpawnCollisionHandlingOverride` decide o que acontece se o local de spawn estiver ocupado: criar assim mesmo, tentar ajustar a posição, ou não criar. Spawns de inimigos e de jogadores (Capítulo 32) precisam escolher isso com cuidado.

### Spawn diferido

Às vezes você precisa configurar o ator **antes** que o `BeginPlay` dele execute — por exemplo, entregar a um inimigo a rota de patrulha que ele usa no próprio `BeginPlay`. O spawn normal executa todo o ciclo, incluindo `BeginPlay`, antes de retornar. O **spawn diferido** para no meio:

```cpp
// Hipotético: AVGPatrolEnemy lê PatrolRoute no próprio BeginPlay.
const FTransform SpawnTransform = GetActorTransform();
AVGPatrolEnemy* Enemy = GetWorld()->SpawnActorDeferred<AVGPatrolEnemy>(
    EnemyClass, SpawnTransform, /*Owner=*/this, /*Instigator=*/nullptr,
    ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn);

if (Enemy)
{
    Enemy->PatrolRoute = Route;           // configurado ANTES do BeginPlay
    Enemy->FinishSpawning(SpawnTransform); // agora sim: construção termina e BeginPlay executa
}
```

> 🌉 **Ponte:** é o equivalente a injeção por construtor quando a linguagem não permite construtor com parâmetros: você precisa entregar dependências **antes** do `@PostConstruct`. Como atores não aceitam parâmetros no construtor (o construtor serve ao CDO), o spawn diferido é o caminho.

### Owner e Instigator

Dois campos de `FActorSpawnParameters` com significado de gameplay:

- **Owner** — o ator "dono" deste: a jogadora é dona da lanterna; o spawner é dono do que criou. O conceito ganha peso em multiplayer (Capítulo 64), onde o *owner* define quem pode chamar certas funções.
- **Instigator** — o *pawn* responsável pelas ações deste ator: um projétil tem como instigator quem atirou. O sistema de dano usa isso para saber **quem causou** o dano (Capítulo 22).

---

## 8.7 Destruindo atores

```cpp
Spawned->Destroy();          // destrói agora (Destroyed chama EndPlay por dentro), memória liberada pelo GC depois
Spawned->SetLifeSpan(5.0f);  // destrói daqui a 5 segundos de tempo de jogo
```

Depois de `Destroy()`, o objeto **ainda está na memória** até a próxima coleta do garbage collector, mas está marcado como inválido. Qualquer ponteiro que você guardou para ele passa a apontar para um objeto "morto". Por isso:

```cpp
if (IsValid(Target))   // verifica nulo E se o objeto não está pendente de destruição
{
    // ...
}
```

E, para guardar referências a atores que podem ser destruídos por outros sistemas sem que você seja avisado, use **`TWeakObjectPtr<T>`** — um ponteiro fraco que "fica nulo" quando o objeto é coletado e não impede a coleta. O Capítulo 11 detalha os tipos de ponteiro e a interação com o GC.

### Destruir ou desativar?

Criar e destruir atores tem custo (alocação, inicialização de componentes, registro na física e no render). Para objetos que aparecem e somem o tempo todo — projéteis, efeitos de impacto, inimigos de ondas —, a alternativa é **desativar e reutilizar** (*object pooling*):

```cpp
Actor->SetActorHiddenInGame(true);
Actor->SetActorEnableCollision(false);
Actor->SetActorTickEnabled(false);
```

O Capítulo 32 implementa pooling no spawner. Por enquanto, a regra: **destrua por padrão; faça pooling quando o profiler mostrar que o custo de spawn importa.**

---

## Comparação com o desenvolvimento tradicional

| Conceito Unreal | O que você conhece | Onde a analogia cai |
|---|---|---|
| Ciclo de vida do Actor | Ciclo de vida de bean (`@PostConstruct`, `@PreDestroy`) | Atores são muitos, efêmeros, e o "contêiner" (mundo) é recriado por nível |
| CDO | Padrão Prototype; definição de bean | O construtor roda também para o CDO, sem mundo |
| `SpawnActor` | `ApplicationContext.getBean()` / factory | Você pede ao mundo; o mundo controla a construção |
| Spawn diferido | Injeção antes do `@PostConstruct` | Necessário porque o construtor não aceita parâmetros |
| `Destroy` + GC | Liberar referência e deixar o GC agir | O objeto "morto" ainda existe até a coleta; `IsValid` é obrigatório |
| `GetAllActorsOfClass` | Varrer uma tabela inteira | Custo por chamada; nunca em Tick |
| Referência editável entre atores | Configuração externa / *wiring* | É feito por designers, visualmente, no editor |

---

## Unreal Engine: Blueprint e o ciclo de vida

Os mesmos eventos aparecem em Blueprint com outros nomes: **Construction Script** (= `OnConstruction`), **Event BeginPlay**, **Event Tick**, **Event EndPlay**, **Event Destroyed**. Quando uma classe C++ é herdada por um Blueprint, a ordem é: o `BeginPlay` C++ executa, e **dentro** do `Super::BeginPlay()` da classe `AActor` o evento *BeginPlay* do Blueprint é disparado. É por isso que o código C++ que você escreve **depois** de `Super::BeginPlay()` executa **depois** do Blueprint, e o que escreve antes executa antes — um detalhe que o Capítulo 13 explora.

---

## Exemplo e implementação

### Parte A — observando o ciclo de vida

Como nos Capítulos 2 e 3, primeiro um ator de diagnóstico, para **ver** o ciclo acontecer.

```cpp
// Source/Vigilia/Debug/VGLifecycleProbe.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGLifecycleProbe.generated.h"

/** Ator de diagnóstico: registra no log cada etapa do próprio ciclo de vida. */
UCLASS()
class VIGILIA_API AVGLifecycleProbe : public AActor
{
    GENERATED_BODY()

public:
    AVGLifecycleProbe();

    virtual void PostActorCreated() override;
    virtual void OnConstruction(const FTransform& Transform) override;
    virtual void PreInitializeComponents() override;
    virtual void PostInitializeComponents() override;
    virtual void Destroyed() override;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
};
```

```cpp
// Source/Vigilia/Debug/VGLifecycleProbe.cpp
#include "Debug/VGLifecycleProbe.h"

DEFINE_LOG_CATEGORY_STATIC(LogVGLifecycle, Log, All);

#define VG_LIFECYCLE_LOG(Stage) \
    UE_LOG(LogVGLifecycle, Log, TEXT("%-26s %-40s CDO=%d World=%s"), TEXT(Stage), *GetName(), \
        HasAnyFlags(RF_ClassDefaultObject) ? 1 : 0, GetWorld() ? *GetWorld()->GetName() : TEXT("(nenhum)"))

AVGLifecycleProbe::AVGLifecycleProbe()
{
    PrimaryActorTick.bCanEverTick = false;
    VG_LIFECYCLE_LOG("Construtor");
}

void AVGLifecycleProbe::PostActorCreated()            { Super::PostActorCreated();            VG_LIFECYCLE_LOG("PostActorCreated"); }
void AVGLifecycleProbe::OnConstruction(const FTransform& Transform) { Super::OnConstruction(Transform); VG_LIFECYCLE_LOG("OnConstruction"); }
void AVGLifecycleProbe::PreInitializeComponents()     { Super::PreInitializeComponents();     VG_LIFECYCLE_LOG("PreInitializeComponents"); }
void AVGLifecycleProbe::PostInitializeComponents()    { Super::PostInitializeComponents();    VG_LIFECYCLE_LOG("PostInitializeComponents"); }
void AVGLifecycleProbe::BeginPlay()                   { Super::BeginPlay();                   VG_LIFECYCLE_LOG("BeginPlay"); }
void AVGLifecycleProbe::Destroyed()                   { Super::Destroyed();                   VG_LIFECYCLE_LOG("Destroyed"); } // o EndPlay roda dentro do Super

void AVGLifecycleProbe::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    UE_LOG(LogVGLifecycle, Log, TEXT("EndPlay                    %-40s Reason=%s"),
        *GetName(), *UEnum::GetValueAsString(EndPlayReason));
    Super::EndPlay(EndPlayReason);
}
```

Uma macro local reduz a repetição — num ator de diagnóstico, isso é aceitável. Em código de gameplay, prefira funções.

O que observar (exercício abaixo): o construtor roda **com `CDO=1` e sem mundo** ao abrir o editor; arrastar o ator para o nível dispara construtor e `OnConstruction`; **movê-lo no editor** dispara `OnConstruction` de novo; apertar *Play* cria uma **cópia** do nível para o mundo de PIE — e o ciclo roda outra vez, agora com o mundo de PIE; parar o PIE gera `EndPlay` com motivo `EndPlayInEditor` (em geral, sem `Destroyed`); destruir o ator durante o jogo gera `EndPlay` com motivo `Destroyed` e, logo depois, a linha `Destroyed`.

### Parte B — o `AVGSpawner`

Agora um ator de gameplay real. O spawner cria periodicamente instâncias de uma classe escolhida no editor, respeita um limite de instâncias vivas e, opcionalmente, um tempo de vida. Ele é deliberadamente simples, e vai evoluir:

- **Capítulo 32:** pontos de spawn, spawn seguro (fora da visão do jogador), ondas e pooling.
- **Parte IX:** spawn com autoridade do servidor.

```cpp
// Source/Vigilia/World/VGSpawner.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGSpawner.generated.h"

/**
 * Cria periodicamente instâncias de uma classe escolhida no editor, até um limite de vivas.
 * Simplificação: spawn sempre no transform do próprio ator, sem checagem de visão do jogador
 * e sem pooling. Evolui no Cap. 32 (Spawn System).
 */
UCLASS()
class VIGILIA_API AVGSpawner : public AActor
{
    GENERATED_BODY()

public:
    AVGSpawner();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    /** Classe a criar. O designer escolhe um Blueprint aqui. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Spawner")
    TSubclassOf<AActor> ActorClass;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Spawner", meta = (ClampMin = "0.1"))
    float SpawnInterval = 2.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Spawner", meta = (ClampMin = "1"))
    int32 MaxAlive = 5;

    /** Segundos de vida de cada instância; 0 = vive até ser destruída por outro sistema. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Spawner", meta = (ClampMin = "0.0"))
    float SpawnedLifeSpan = 0.0f;

private:
    void TrySpawn();

    UFUNCTION()
    void HandleSpawnedDestroyed(AActor* DestroyedActor);

    UPROPERTY(VisibleAnywhere, Category = "Vigilia|Spawner")
    TObjectPtr<USceneComponent> Root;

    int32 AliveCount = 0;
    FTimerHandle SpawnTimerHandle;
};
```

```cpp
// Source/Vigilia/World/VGSpawner.cpp
#include "World/VGSpawner.h"

#include "Components/SceneComponent.h"
#include "Engine/World.h"
#include "TimerManager.h"

AVGSpawner::AVGSpawner()
{
    PrimaryActorTick.bCanEverTick = false; // o ritmo vem de um timer, não do tick

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);
}

void AVGSpawner::BeginPlay()
{
    Super::BeginPlay();

    if (!ActorClass)
    {
        UE_LOG(LogTemp, Warning, TEXT("%s: ActorClass não configurada; spawner inativo."), *GetName());
        return;
    }

    GetWorldTimerManager().SetTimer(
        SpawnTimerHandle, this, &AVGSpawner::TrySpawn, SpawnInterval, /*bLoop=*/true);
}

void AVGSpawner::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearTimer(SpawnTimerHandle);
    Super::EndPlay(EndPlayReason);
}

void AVGSpawner::TrySpawn()
{
    if (AliveCount >= MaxAlive)
    {
        return;
    }

    FActorSpawnParameters Params;
    Params.Owner = this;
    Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

    AActor* Spawned = GetWorld()->SpawnActor<AActor>(ActorClass, GetActorTransform(), Params);
    if (!Spawned)
    {
        return;
    }

    ++AliveCount;
    Spawned->OnDestroyed.AddDynamic(this, &AVGSpawner::HandleSpawnedDestroyed);

    if (SpawnedLifeSpan > 0.0f)
    {
        Spawned->SetLifeSpan(SpawnedLifeSpan);
    }
}

void AVGSpawner::HandleSpawnedDestroyed(AActor* DestroyedActor)
{
    AliveCount = FMath::Max(AliveCount - 1, 0);
}
```

### Explicação das decisões

- **Timer, não tick.** O spawn é um evento periódico discreto (Capítulo 2, seção 2.6).
- **`TSubclassOf<AActor>` editável.** O C++ não conhece nenhum Blueprint específico.
- **Contagem por evento.** Em vez de guardar uma lista de ponteiros e varrê-la, o spawner se inscreve no evento `OnDestroyed` de cada ator criado (Capítulo 4: transições discretas por evento). O handler precisa ser `UFUNCTION()` porque `OnDestroyed` é um delegate **dinâmico** — eles só aceitam funções conhecidas pelo sistema de reflexão.
- **E se o spawner for destruído antes dos atores criados?** O delegate dinâmico guarda uma referência fraca ao spawner; se ele não existir mais, a chamada é ignorada. Os atores criados continuam vivos — o que pode ou não ser o desejado. No Capítulo 32, essa decisão ("o que acontece com os filhos quando o spawner some?") vira uma propriedade.
- **`EndPlay` limpa o timer.** Timers associados a um objeto destruído não executam, mas limpar explicitamente torna a intenção clara e cobre trocas de nível.
- **Um `USceneComponent` como raiz.** Um ator precisa de um componente raiz para ter transform. O Capítulo 9 explica componentes; por ora, é a "âncora" do spawner no espaço.
- **Aviso no log quando mal configurado.** Erros de configuração de conteúdo devem ser **visíveis** — o designer precisa descobrir por que "o spawner não faz nada" sem abrir o depurador. No Capítulo 13, veremos formas melhores (validação de dados no editor).

---

## Estudo de caso: a população ambiente de GTA V

> **Pergunta:** como um jogo cria a sensação de uma cidade cheia de gente sem simular uma cidade inteira de gente?

**[FATO PÚBLICO]** Em *GTA V* (Rockstar, 2013), ruas, calçadas e estradas são povoadas por pedestres e veículos que aparecem ao redor do jogador; é amplamente observado por jogadores que veículos e pedestres que saem do campo de visão podem desaparecer, e que outros surgem fora de vista. A densidade e o tipo de população variam por bairro e por horário.

**[INFERÊNCIA]** Esse comportamento é compatível com um sistema de **spawn e despawn por relevância**: atores de população são criados em pontos fora da visão do jogador, numa faixa de distância ao redor dele, e removidos (ou devolvidos a um pool) quando ficam longe ou fora de vista por tempo suficiente. O tipo de NPC criado é escolhido a partir de **dados por região e horário**. O "mundo cheio" é, em grande parte, um palco montado em tempo real ao redor do jogador.

**[SIMPLIFICAÇÃO DIDÁTICA]** O `AVGSpawner` deste capítulo é o embrião dessa ideia: ele já tem um **limite de instâncias vivas** (o orçamento de população) e destruição por **tempo de vida**. Faltam três peças, que entram no Capítulo 32 e no Interlúdio II: spawn **fora da visão do jogador**, despawn por **distância/relevância** e **pooling**.

**Lição:** a sensação de "o mundo continua existindo quando eu não estou olhando" é produzida, em boa parte, por **criar e destruir atores no momento certo** — e por garantir que o jogador nunca veja nenhum dos dois acontecer. O ciclo de vida de um ator, que parece um detalhe técnico, é uma ferramenta de design.

---

## Decisões arquiteturais

1. **Construtores só criam componentes e definem padrões.** Nenhum acesso a mundo ou a outros atores.
2. **`BeginPlay` inicia gameplay; `EndPlay` limpa.** Todo timer, inscrição em evento ou pedido a subsistema iniciado em `BeginPlay` tem limpeza correspondente em `EndPlay`.
3. **Nenhuma dependência de ordem de `BeginPlay` entre atores.** Quando houver, ela é explicitada por evento ou registro.
4. **Classes de conteúdo chegam ao C++ por `TSubclassOf` editável**, nunca por caminho de asset fixo no código.
5. **Conexões entre atores:** referência editável > registro em subsistema > eventos > iteração do mundo (só em inicialização).
6. **`IsValid` antes de usar atores que podem ter sido destruídos; `TWeakObjectPtr` para guardá-los.**
7. **Destruir por padrão; pooling só com evidência de profiler.**

---

## Armadilhas

- **Lógica de gameplay no construtor** (ou no Construction Script).
- **Esquecer `Super::`** em `BeginPlay`/`EndPlay`/`Tick`.
- **Depender da ordem de `BeginPlay`** entre atores diferentes.
- **`GetAllActorsOfClass` em Tick** ou como mecanismo de comunicação padrão.
- **Ponteiros crus para atores que podem ser destruídos**, usados sem `IsValid`.
- **Mover atores *Static*** em runtime.
- **Teleportar sem sweep** algo que deveria colidir.
- **Não limpar em `EndPlay`** — pedidos órfãos, timers e inscrições.
- **Spawn sem tratar falha** (`SpawnActor` pode retornar nulo).

---

## Exercício

**Parte 1 — ciclo de vida (1 h).** Compile o `AVGLifecycleProbe`. Abra o editor e filtre o Output Log por `LogVGLifecycle`. Registre no `DEVLOG.md` a sequência de logs para: (a) abrir o editor; (b) arrastar o probe para o nível; (c) movê-lo três vezes; (d) mudar uma propriedade; (e) apertar *Play*; (f) parar o PIE; (g) apagar o probe do nível. Explique cada linha.

**Parte 2 — spawner (1,5 h).** Implemente o `AVGSpawner`. Crie um Blueprint `BP_CaixaTeste` (um ator com um cubo pequeno) em `/Game/Developers/`. No Pátio, coloque dois spawners: um no galpão (`SpawnInterval = 0.5`, `MaxAlive = 10`, `SpawnedLifeSpan = 3`) e outro na guarita com os padrões. Observe no Outliner os atores aparecendo e sumindo durante o PIE. Use `F8` para ejetar e inspecionar um spawner: o `AliveCount` não aparece — por quê? Torne-o visível no Details sem permitir edição.

**Parte 3 — spawn diferido (45 min).** Crie uma classe `AVGTimedMarker` com uma propriedade `Label` (`FString`) que é escrita no log **no `BeginPlay`**. Crie uma versão do spawner que define `Label` antes do `BeginPlay`, usando spawn diferido. Depois, tente definir `Label` após um `SpawnActor` normal e observe a diferença no log.

---

## Desafio — o spawner "educado"

Modifique o `AVGSpawner` para **não criar atores quando o jogador estiver olhando para o ponto de spawn**. Você ainda não tem personagem nem conhece traces (Capítulo 15), mas já tem tudo o que precisa para uma versão aproximada:

1. Obtenha a localização e a direção da câmera do jogador (`UGameplayStatics::GetPlayerCameraManager(this, 0)` → `GetCameraLocation()`, `GetCameraRotation().Vector()`).
2. Calcule o vetor da câmera até o spawner e use o **produto escalar** com a direção da câmera para saber se o spawner está dentro de um cone de, digamos, 60°.
3. Se estiver, adie o spawn.

Pergunte-se: e se houver uma parede entre a câmera e o spawner? A versão do produto escalar diz que o jogador "está vendo" quando não está. Que peça falta? (Resposta: um *line trace* — Capítulo 15. Anote a pergunta; você vai voltar a ela no Capítulo 32 e de novo na percepção da IA, no Capítulo 36.)

---

## Uso de IA

1. **Para fixar o ciclo de vida:**
   > "Explique o ciclo de vida de um AActor na Unreal Engine 5 para dois casos — ator carregado do nível e ator criado com SpawnActor — incluindo construtor/CDO, PostActorCreated, OnConstruction, PreInitializeComponents, PostInitializeComponents, BeginPlay e EndPlay. Para cada etapa, dê um exemplo do que fazer e do que não fazer. Aponte onde Blueprints filhos entram na sequência."

2. **Para revisar código de spawn:**
   > "Revise este código de spawn de atores em Unreal C++. Verifique: tratamento de falha do SpawnActor, escolha do SpawnCollisionHandlingOverride, limpeza em EndPlay, ponteiros para atores que podem ser destruídos, uso de delegates dinâmicos e custo por chamada. [código]"

3. **Para entender o CDO com perguntas:**
   > "Faça-me cinco perguntas, uma por vez, para verificar se entendi o Class Default Object da Unreal. Depois de cada resposta minha, corrija-me e explique."

**Cuidado específico:** a ordem exata de algumas etapas internas do ciclo de vida (e quais funções são chamadas em cada caminho) tem nuances entre versões da engine e entre o editor e o jogo. O `AVGLifecycleProbe` é a sua fonte da verdade: quando a IA e o log discordarem, o log vence.

---

## Checklist

- [ ] Sei o que `UObject` traz e o que `AActor` acrescenta.
- [ ] Sei explicar o CDO e por que o construtor não pode ter lógica de gameplay.
- [ ] Conheço as etapas do ciclo de vida e o que pertence a cada uma.
- [ ] Sei por que `OnConstruction` roda no editor e o que isso permite.
- [ ] Sei por que a ordem de `BeginPlay` entre atores não é garantida e como lidar com isso.
- [ ] Sei usar `FVector`, `FRotator`, `FTransform` e mover com e sem sweep; conheço Mobility.
- [ ] Sei as alternativas a `GetAllActorsOfClass` e quando usar cada uma.
- [ ] Sei usar `SpawnActor`, `TSubclassOf`, spawn diferido, Owner e Instigator.
- [ ] Sei destruir atores, usar `SetLifeSpan`, `IsValid` e `TWeakObjectPtr`.
- [ ] Implementei o `AVGSpawner` e o `AVGLifecycleProbe`.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre **Actor Lifecycle**, **Spawning Actors** e **Unreal Object Handling**.
- **Jason Gregory, *Game Engine Architecture*** — seções sobre criação e destruição de objetos de jogo e gerenciamento de memória de objetos em runtime.

---

➡️ **Próximo:** [Capítulo 9 — Components](cap-09-components.md)

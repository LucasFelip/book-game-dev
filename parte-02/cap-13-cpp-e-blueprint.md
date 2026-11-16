# Capítulo 13 — C++ + Blueprint

## Objetivo

Ao final deste capítulo você deve conseguir:

- formular a **regra de camadas** do projeto: o que fica em C++, o que fica em Blueprint, o que fica em dados — e justificar cada fronteira;
- expor C++ ao Blueprint com `BlueprintCallable`, `BlueprintPure`, `BlueprintImplementableEvent` e `BlueprintNativeEvent`, sabendo quando usar cada um;
- projetar **classes base em C++ pensadas para serem estendidas** em Blueprint, com pontos de extensão explícitos;
- usar **Blueprint Function Libraries** e **Data Assets** como fronteiras entre código e conteúdo;
- **validar** conteúdo no editor, para que erros de configuração apareçam antes do PIE;
- realizar a primeira **migração de Blueprint para C++** do projeto, com o alarme do Capítulo 12.

---

## Contexto

O Capítulo 11 apresentou a linguagem; o Capítulo 12, a linguagem visual. Este capítulo responde à pergunta que todo programador faz na primeira semana de Unreal e que a maioria responde errado nos primeiros meses: **onde cada coisa deve ser escrita?**

As respostas extremas são fáceis e ruins. "Tudo em C++" produz um jogo que só programadores conseguem ajustar, com ciclos de iteração lentos e designers dependendo de você para mudar o tempo de abertura de uma porta. "Tudo em Blueprint" produz um jogo com sistemas centrais impossíveis de revisar, caros de executar e frágeis de modificar.

A resposta boa é uma **arquitetura de camadas** — não por abstração técnica, mas por **quem altera** e **com que frequência** (Capítulo 6, seção 6.5). Este capítulo a formaliza e mostra as ferramentas de fronteira.

---

## 13.1 A regra de camadas

```text
┌─────────────────────────────────────────────────────────────────────────┐
│  DADOS (Data Assets, tabelas, curvas, propriedades editáveis)           │
│  "QUANTO e QUAL"   números, curvas, listas, escolhas de assets           │
│  quem muda: designers · frequência: o tempo todo · ferramenta: editor   │
├─────────────────────────────────────────────────────────────────────────┤
│  BLUEPRINT (classes filhas, eventos de conteúdo, composição)            │
│  "COMO ESTE CONTEÚDO ESPECÍFICO SE COMPORTA"                             │
│  quem muda: designers técnicos e programadores · frequência: semanal    │
├─────────────────────────────────────────────────────────────────────────┤
│  C++ (classes base, componentes, subsistemas, regras)                   │
│  "COMO O SISTEMA FUNCIONA"   regras, invariantes, estado, performance   │
│  quem muda: programadores · frequência: quando o sistema muda           │
└─────────────────────────────────────────────────────────────────────────┘
```

Para decidir onde uma coisa vai, faça as perguntas nesta ordem:

| # | Pergunta | Se sim → |
|---|---|---|
| 1 | É **um número, uma curva, uma escolha de asset** que alguém vai querer ajustar? | **Dados** (propriedade editável ou Data Asset) |
| 2 | É uma **regra ou invariante** que outros sistemas dependem que seja verdadeira? | **C++** |
| 3 | Guarda **estado** que vai para o save ou para a rede? | **C++** (dono do estado — Capítulo 4) |
| 4 | Roda **todo frame em muitas instâncias**, ou é algorítmico? | **C++** |
| 5 | **Outros sistemas C++** precisam chamar isso? | **C++** |
| 6 | É **específico deste conteúdo** (desta porta, deste nível, deste inimigo)? | **Blueprint** |
| 7 | É **apresentação** — som, efeito, luz, animação disparada por um evento? | **Blueprint** (reagindo a eventos C++) |
| 8 | É um **experimento** cujo valor ainda não se provou? | **Blueprint** (prototipar), C++ depois se ficar |

Algumas aplicações imediatas na Vigília:

| Coisa | Camada | Por quê (pergunta) |
|---|---|---|
| Taxa de drenagem da bateria | Dados | 1 |
| "A carga nunca fica negativa"; transições Charged/Low/Depleted | C++ | 2, 3 |
| A lanterna pisca quando a bateria fica fraca | Blueprint (conecta componentes C++) | 6, 7 |
| Dilatação do tempo com pedidos e prioridades | C++ | 2, 5 |
| O padrão de falha de um poste específico | Dados (propriedade) | 1 |
| A lógica de falha (`UVGFlickerComponent`) | C++ | 4 (muitas instâncias, todo frame) |
| "Esta porta abre e toca um rangido metálico" | Blueprint + dados | 6, 7 |
| "Uma porta nunca abre se estiver trancada" | C++ | 2 |

> 🌉 **Ponte:** a camada de dados é a sua **configuração externalizada**; a de C++ é o **domínio e a plataforma**; a de Blueprint não tem um equivalente perfeito no seu mundo — o mais próximo seria uma camada de **regras de negócio configuráveis por usuários avançados** (motores de regras, BPMN), mas com acesso à linguagem completa.

---

## 13.2 Expondo C++ ao Blueprint: chamadas

### `BlueprintCallable` e `BlueprintPure`

Você já usou os dois. Recapitulando com a precisão que o Capítulo 12 permite:

```cpp
UFUNCTION(BlueprintCallable, Category = "Vigilia|Battery")
void Drain(float Amount);                 // comando: nó com pinos de execução

UFUNCTION(BlueprintPure, Category = "Vigilia|Battery")
float GetChargeRatio() const;             // consulta: nó sem execução, REAVALIADO a cada uso
```

A escolha entre os dois não é estética. **`BlueprintPure` só para funções baratas e sem efeitos colaterais**, porque o nó é reavaliado a cada fio que sai dele (Capítulo 12, Armadilha 1). Uma função `const` cara (um *trace*, uma busca) deve ganhar pinos de execução, mesmo sendo uma consulta — o designer vê os pinos e entende que aquilo "faz algo" e deve ter seu resultado guardado.

Cuidado com uma regra implícita da UHT: **uma função membro `const` marcada só com `BlueprintCallable` vira pura automaticamente**. O `const` é lido como "consulta", e o nó sai sem pinos de execução — exatamente a armadilha que se queria evitar. Para uma consulta `const` cara, declare explicitamente `BlueprintCallable, BlueprintPure = false`, como no `FindInteractable` abaixo.

### Parâmetros e retornos

```cpp
// Múltiplas saídas: parâmetros por referência não-const viram pinos de SAÍDA no Blueprint.
// BlueprintPure = false: sem isso, o const tornaria o nó puro (e o trace rodaria a cada fio).
UFUNCTION(BlueprintCallable, BlueprintPure = false, Category = "Vigilia|Interaction")
bool FindInteractable(AActor*& OutActor, FVector& OutLocation) const;

// Para receber uma struct sem cópia, como ENTRADA: const&
UFUNCTION(BlueprintCallable, Category = "Vigilia|Combat")
void ApplyHit(const FHitResult& Hit);
```

A convenção do `Out` no nome (Capítulo 11) se torna visível: os pinos de saída aparecem do lado direito do nó.

### `meta` úteis para quem usa os nós

```cpp
UFUNCTION(BlueprintCallable, Category = "Vigilia|Time",
          meta = (WorldContext = "WorldContextObject", ReturnDisplayName = "Handle"))
static int32 RequestTimeDilation(const UObject* WorldContextObject, float Scale, int32 Priority, FName Reason);
```

- **`WorldContext`** — em funções estáticas, indica o parâmetro de onde o mundo é obtido; o Blueprint o preenche automaticamente com `self`.
- **`ReturnDisplayName`**, **`DisplayName`**, **`Keywords`**, **`CompactNodeTitle`** — como o nó aparece e é encontrado na paleta.
- **`DeterminesOutputType`** — faz um nó retornar o tipo exato da classe passada (evita um `Cast` em seguida).

Nomes de funções e categorias são **interface de usuário** para o designer. Uma função bem nomeada, na categoria certa, com tooltip (o comentário `/** */` acima da declaração vira tooltip), é a diferença entre um sistema usado e um sistema contornado.

---

## 13.3 Expondo C++ ao Blueprint: pontos de extensão

Chamadas vão do Blueprint para o C++. Muitas vezes, você precisa do caminho inverso: o **sistema C++ decide quando** algo acontece, e o **conteúdo decide como** aquilo se apresenta. Há duas ferramentas.

### `BlueprintImplementableEvent`: o C++ avisa, o Blueprint implementa

```cpp
// Declarado em C++, SEM implementação em C++.
UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Alarm")
void OnAlarmStarted();
```

O C++ chama `OnAlarmStarted()` como uma função normal. Se o Blueprint filho implementou o evento, ele executa; se não, nada acontece. É o ponto de extensão ideal para **apresentação**: "o alarme começou — toque o que quiser".

### `BlueprintNativeEvent`: o C++ tem um padrão, o Blueprint pode sobrescrever

```cpp
// Declarado em C++, COM implementação padrão em C++.
UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Alarm")
float ComputeNextInterval();

// No .cpp, a implementação padrão leva o sufixo _Implementation:
float AVGAlarm::ComputeNextInterval_Implementation()
{
    return FMath::FRandRange(MinInterval, MaxInterval);
}
```

O C++ chama `ComputeNextInterval()` (sem sufixo). Se o Blueprint sobrescreveu, roda a versão do Blueprint — que pode, ela mesma, chamar a implementação "pai" (o nó *Parent: Compute Next Interval*). Se não, roda a `_Implementation`. É o ponto de extensão para **políticas com padrão razoável**: o sistema funciona sozinho, e um conteúdo específico pode mudar a regra.

### Delegates como alternativa

Um terceiro mecanismo é o **delegate dinâmico** (`BlueprintAssignable`), que você usou no Capítulo 4 (`OnBatteryStateChanged`). A diferença:

| Mecanismo | Quem reage | Quantos | Conhece o dono? |
|---|---|---|---|
| `BlueprintImplementableEvent` / `NativeEvent` | **A própria classe** (o Blueprint filho) | Um | É o dono |
| Delegate `BlueprintAssignable` | **Outros objetos** que se inscreveram | Vários | Precisa de uma referência para se inscrever |

Regra prática: **evento de extensão quando a reação pertence à própria classe** ("como *este tipo de alarme* soa"); **delegate quando outros objetos reagem** ("os postes reagem ao alarme").

> 🌉 **Ponte:** `BlueprintImplementableEvent` é o **Template Method** (GoF) com o passo opcional; `BlueprintNativeEvent` é o Template Method com implementação padrão sobrescrevível; delegates são **Observer**.

### Desenhando uma classe base para ser estendida

Uma classe C++ que será base de Blueprints de conteúdo deve ser desenhada como uma **API para designers**. Princípios:

1. **O estado e as regras ficam no C++, privados ou protegidos.** O Blueprint não escreve estado diretamente; usa funções (Capítulo 4).
2. **Pontos de extensão são explícitos e nomeados por intenção** (`OnAlarmStarted`, `ComputeNextInterval`), não por mecanismo (`Tick2`, `CustomUpdate`).
3. **Configuração é propriedade editável**, com categoria, tooltip, limites e `EditDefaultsOnly`/`EditInstanceOnly` escolhidos com cuidado.
4. **A classe funciona sem nenhum Blueprint por cima** — com apresentação mínima ou nenhuma. Isso a torna testável e garante que o sistema não depende de conteúdo.
5. **Poucos pontos de extensão.** Cada `BlueprintNativeEvent` é uma promessa de compatibilidade: se você mudar quando ele é chamado, quebra Blueprints que dependem disso.

---

## 13.4 Blueprint Function Libraries

Uma **Blueprint Function Library** é uma classe com funções **estáticas** expostas ao Blueprint — o lugar para utilitários sem estado que o conteúdo usa em muitos lugares.

```cpp
// Source/Vigilia/Core/VGBlueprintLibrary.h
#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "VGBlueprintLibrary.generated.h"

UCLASS()
class VIGILIA_API UVGBlueprintLibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /** Suavização exponencial independente de frame rate (ver Cap. 3). */
    UFUNCTION(BlueprintPure, Category = "Vigilia|Math", meta = (Keywords = "smooth lerp interp decay"))
    static float ExpDecayFloat(float Current, float Target, float Rate, float DeltaSeconds);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Math", meta = (Keywords = "smooth lerp interp decay"))
    static FVector ExpDecayVector(const FVector& Current, const FVector& Target, float Rate, float DeltaSeconds);

    /** Pede uma dilatação global do tempo ao subsistema do mundo (ver Cap. 6). Retorna -1 se indisponível. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Time", meta = (WorldContext = "WorldContextObject"))
    static int32 RequestTimeDilation(const UObject* WorldContextObject, float Scale, int32 Priority, FName Reason);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Time", meta = (WorldContext = "WorldContextObject"))
    static void ReleaseTimeDilation(const UObject* WorldContextObject, int32 Handle);
};
```

```cpp
// Source/Vigilia/Core/VGBlueprintLibrary.cpp
#include "Core/VGBlueprintLibrary.h"

#include "Core/VGMathUtils.h"
#include "Core/VGTimeDilationSubsystem.h"
#include "Engine/Engine.h"
#include "Engine/World.h"

float UVGBlueprintLibrary::ExpDecayFloat(float Current, float Target, float Rate, float DeltaSeconds)
{
    return VGMath::ExpDecayTo(Current, Target, Rate, DeltaSeconds);
}

FVector UVGBlueprintLibrary::ExpDecayVector(const FVector& Current, const FVector& Target, float Rate, float DeltaSeconds)
{
    return VGMath::ExpDecayTo(Current, Target, Rate, DeltaSeconds);
}

static UVGTimeDilationSubsystem* GetTimeSubsystem(const UObject* WorldContextObject)
{
    const UWorld* World = GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::LogAndReturnNull);
    return World ? World->GetSubsystem<UVGTimeDilationSubsystem>() : nullptr;
}

int32 UVGBlueprintLibrary::RequestTimeDilation(const UObject* WorldContextObject, float Scale, int32 Priority, FName Reason)
{
    UVGTimeDilationSubsystem* Time = GetTimeSubsystem(WorldContextObject);
    return Time ? Time->RequestDilation(Scale, Priority, Reason) : INDEX_NONE;
}

void UVGBlueprintLibrary::ReleaseTimeDilation(const UObject* WorldContextObject, int32 Handle)
{
    if (UVGTimeDilationSubsystem* Time = GetTimeSubsystem(WorldContextObject))
    {
        Time->ReleaseDilation(Handle);
    }
}
```

Duas observações:

- O **subsistema já é acessível de Blueprint** (há nós para obter subsistemas, e as funções dele são `BlueprintCallable`). As funções de conveniência da biblioteca existem para **reduzir atrito**: um nó só, encontrável pela paleta com palavras-chave. Isso só vale a pena para operações que o conteúdo usa com frequência — não crie uma biblioteca espelhando todo o C++.
- `ExpDecayFloat`/`ExpDecayVector` levam a decisão do Capítulo 3 ("nenhum `Lerp` com fator constante por frame") para o Blueprint: um designer que quer suavizar algo encontra o nó certo procurando "smooth" ou "lerp".

---

## 13.5 Data Assets: a fronteira com os dados

Propriedades editáveis em atores resolvem configuração **por instância** ou **por classe**. Mas há configuração que é **compartilhada entre classes** e que designers querem editar **num lugar só**: as características de cada tipo de bateria, os perfis de falha de luz, o balanceamento de cada arma (Capítulo 20), os dados de cada documento (Capítulo 48).

Para isso, a Unreal tem **Data Assets**: assets cujo conteúdo é só dados, definidos por uma classe C++.

```cpp
// Source/Vigilia/World/VGFlickerProfile.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGFlickerProfile.generated.h"

/** Perfil de falha de luz reutilizável (ex.: "Lâmpada velha", "Sobrecarga", "Presença próxima"). */
UCLASS(BlueprintType)
class VIGILIA_API UVGFlickerProfile : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    /** 'a' = apagada, 'm' = normal, 'z' ≈ 2x. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Flicker")
    FString Pattern = TEXT("mmamammmmammamamaaamammma");

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Flicker", meta = (ClampMin = "0.1"))
    float StepsPerSecond = 10.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Flicker", meta = (ClampMin = "0.0"))
    float SmoothingRate = 0.0f;
};
```

O designer cria, no Content Browser, assets `DA_Flicker_LampadaVelha`, `DA_Flicker_Sobrecarga`, `DA_Flicker_Presenca` — cada um uma instância de `UVGFlickerProfile` com valores próprios. Componentes e Blueprints referenciam o **perfil**, não números soltos. Ajustar "como é uma sobrecarga" passa a ser editar um asset, e todos os lugares que o usam mudam juntos.

> 🌉 **Ponte:** Data Assets são **configuração tipada e versionada como artefato** — próximos de arquivos de configuração validados por schema, mas editados numa ferramenta visual e referenciados por objetos do jogo.
>
> 🧱 **Onde a ponte cai:** um Data Asset é um `UObject` carregado na memória e **compartilhado** por todos que o referenciam. Escrever nele em runtime altera o valor para todos — e, no editor, pode persistir a alteração no asset (Capítulo 4, armadilha "mexer em Data Assets em runtime"). Data Assets são **somente leitura em runtime** por convenção do projeto; por isso as propriedades acima são `BlueprintReadOnly`.

**`UDataAsset` vs. `UPrimaryDataAsset`:** o segundo pode ser gerenciado pelo **Asset Manager** da engine (carregamento sob demanda, listagem de todos os assets de um tipo, inclusão controlada no cooking). Para perfis pequenos, a diferença é pouca; usar `UPrimaryDataAsset` desde já deixa a porta aberta.

**E tabelas (`UDataTable`)?** Para dados **tabulares e numerosos** (cem documentos, cinquenta linhas de diálogo), uma `UDataTable` baseada numa struct, editável como planilha e importável de CSV/JSON, é mais prática. A Parte VI discute quando usar cada formato.

---

## 13.6 Validação de conteúdo no editor

Até aqui, configurações erradas geram **avisos no log em runtime** (`ActorClass não configurada`, `nenhum ULightComponent`). É melhor que nada, e é tarde: o designer precisa apertar *Play*, chegar até o objeto e ler o log.

A Unreal permite **validar** objetos no editor — ao salvar um asset, ao rodar o *Data Validation* manualmente ou antes de submeter alterações. Basta sobrescrever `IsDataValid`:

```cpp
// VGSpawner.h (adição)
#if WITH_EDITOR
    virtual EDataValidationResult IsDataValid(class FDataValidationContext& Context) const override;
#endif
```

```cpp
// VGSpawner.cpp (adição)
#if WITH_EDITOR
#include "Misc/DataValidation.h"

EDataValidationResult AVGSpawner::IsDataValid(FDataValidationContext& Context) const
{
    EDataValidationResult Result = Super::IsDataValid(Context);

    if (!ActorClass)
    {
        Context.AddError(FText::FromString(TEXT("ActorClass não configurada: o spawner não fará nada.")));
        Result = EDataValidationResult::Invalid;
    }
    return Result;
}
#endif
```

Três detalhes:

- **`#if WITH_EDITOR`** — validação é código de editor; não existe no jogo empacotado (Capítulo 7, seção 7.8).
- **A mensagem é para um designer**, em linguagem de conteúdo, dizendo a consequência.
- A **assinatura de `IsDataValid` mudou ao longo do UE5** (versões antigas recebiam um `TArray<FText>&`). Use a que a sua versão declara em `UObject` — confira no código da engine (Capítulo 11, seção 11.12).

Para validar ainda mais cedo — no momento em que o designer altera uma propriedade —, existe `PostEditChangeProperty`, também editor-only. Use com moderação: validação no salvamento costuma bastar.

---

## 13.7 A ordem de execução entre C++ e Blueprint

Quando uma classe C++ tem um Blueprint filho, eventos como `BeginPlay` executam **em camadas**. Para `BeginPlay`:

```cpp
void AVGAlarm::BeginPlay()
{
    // (1) código C++ ANTES do Super: executa antes do Blueprint
    Super::BeginPlay();   // (2) AActor::BeginPlay dispara o "Event BeginPlay" do Blueprint aqui dentro
    // (3) código C++ DEPOIS do Super: executa depois do Blueprint
}
```

Isso importa quando o Blueprint depende de algo que o C++ prepara, ou vice-versa. A convenção do projeto:

- **Inicialização de estado e de regras: antes do `Super::BeginPlay()`**, para que o Blueprint encontre o sistema pronto.
- **Ações que podem depender do que o Blueprint configurou: depois.**
- Quando a dependência for sutil, **não dependa da ordem**: ofereça um ponto de extensão explícito (`OnAlarmReady`) chamado quando o C++ terminou.

> Em projetos C++ "padrão" (incluindo os templates), é comum ver tudo depois do `Super::BeginPlay()`. Funciona na maioria dos casos. Quando não funcionar — o Blueprint lê algo que o C++ ainda não preparou —, a seção acima explica por quê.

---

## Implementação: migrando o alarme para uma classe base C++

### 🔁 Refatoração: por quê, e o quê

No Capítulo 12, o alarme da usina foi feito 100% em Blueprint — a decisão certa naquele momento: era um experimento de atmosfera, específico do Pátio. O desafio do capítulo terminou com uma pergunta: *quais partes são conteúdo e quais começam a parecer sistema?*

O que mudou desde então:

1. **A Vigília vai ter alarmes em outros níveis** (a Casa de Força no Projeto 4, os setores do jogo final). A lógica de intervalo, guarda de estado e duração vai se repetir.
2. **O nível de ameaça da Presença (Capítulo 36) vai querer reagir ao alarme** — e é um sistema C++. Hoje, para reagir, ele teria que conhecer `BP_AlarmeUsina` (referência forte a um Blueprint de conteúdo, violando a regra de camadas).
3. **O desafio do Capítulo 12 acrescentou regras** (intervalo variável, escalada) que são política, não apresentação.

O que **não** mudou: o **som, a luz vermelha, a curva do pulso** e o **padrão de falha dos postes** continuam sendo conteúdo.

A divisão nova:

| Parte | Antes | Depois |
|---|---|---|
| Intervalo, duração, guarda de estado, agendamento | Blueprint | **C++** (`AVGAlarm`) |
| Política do próximo intervalo (aleatório, escalada) | Blueprint (desafio) | **C++ com padrão**, sobrescrevível (`BlueprintNativeEvent`) |
| Eventos de início/fim para outros objetos | Event Dispatchers | **Delegates C++ `BlueprintAssignable`** |
| Sirene, luz, Timeline do pulso | Blueprint | **Blueprint** (`BP_AlarmeUsina` herda de `AVGAlarm`) |
| Postes reagindo | Blueprint, referência a `BP_AlarmeUsina` | Blueprint, referência a **`AVGAlarm`** (classe C++) |

### O código

```cpp
// Source/Vigilia/World/VGAlarm.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGAlarm.generated.h"

class AVGAlarm;
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGAlarmSignature, AVGAlarm*, Alarm);

/**
 * Alarme periódico da usina: agenda, guarda contra sobreposição e anuncia início/fim.
 * Apresentação (som, luz, efeitos) fica no Blueprint filho via OnAlarmStarted/OnAlarmEnded.
 */
UCLASS(Abstract, Blueprintable)
class VIGILIA_API AVGAlarm : public AActor
{
    GENERATED_BODY()

public:
    AVGAlarm();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Alarm")
    void TriggerAlarm();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Alarm")
    bool IsAlarmActive() const { return bActive; }

    /** Outros objetos reagem aqui (postes, nível de ameaça). */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Alarm")
    FVGAlarmSignature OnAlarmStartedEvent;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Alarm")
    FVGAlarmSignature OnAlarmEndedEvent;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    /** Apresentação do próprio alarme (som, luz). Implementado no Blueprint filho. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Alarm")
    void OnAlarmStarted();

    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Alarm")
    void OnAlarmEnded();

    /** Política do próximo intervalo. Padrão: aleatório entre Min e Max. Sobrescrevível no Blueprint. */
    UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Alarm")
    float ComputeNextInterval();

    UPROPERTY(EditAnywhere, Category = "Vigilia|Alarm", meta = (ClampMin = "1.0"))
    float MinInterval = 60.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Alarm", meta = (ClampMin = "1.0"))
    float MaxInterval = 120.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Alarm", meta = (ClampMin = "0.5"))
    float Duration = 6.0f;

    /** Se falso, o alarme só toca quando alguém chama TriggerAlarm (ex.: evento roteirizado). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Alarm")
    bool bPeriodic = true;

private:
    void ScheduleNext();
    void EndAlarm();

    bool bActive = false;
    FTimerHandle NextAlarmHandle;
    FTimerHandle EndAlarmHandle;
};
```

```cpp
// Source/Vigilia/World/VGAlarm.cpp
#include "World/VGAlarm.h"

#include "TimerManager.h"

AVGAlarm::AVGAlarm()
{
    PrimaryActorTick.bCanEverTick = false;
    SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("Root")));
}

void AVGAlarm::BeginPlay()
{
    // Regras prontas antes do Blueprint: o "Event BeginPlay" do filho encontra o alarme agendado.
    if (bPeriodic)
    {
        ScheduleNext();
    }
    Super::BeginPlay();
}

void AVGAlarm::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearAllTimersForObject(this);
    Super::EndPlay(EndPlayReason);
}

void AVGAlarm::TriggerAlarm()
{
    if (bActive)
    {
        return; // guarda de estado (Cap. 4): nunca dois alarmes sobrepostos
    }

    bActive = true;
    GetWorldTimerManager().SetTimer(EndAlarmHandle, this, &AVGAlarm::EndAlarm, Duration, false);

    OnAlarmStarted();                     // apresentação da própria classe
    OnAlarmStartedEvent.Broadcast(this);  // outros objetos
}

void AVGAlarm::EndAlarm()
{
    bActive = false;

    OnAlarmEnded();
    OnAlarmEndedEvent.Broadcast(this);

    if (bPeriodic)
    {
        ScheduleNext();
    }
}

void AVGAlarm::ScheduleNext()
{
    const float Interval = FMath::Max(ComputeNextInterval(), 1.0f);
    GetWorldTimerManager().SetTimer(NextAlarmHandle, this, &AVGAlarm::TriggerAlarm, Interval, false);
}

float AVGAlarm::ComputeNextInterval_Implementation()
{
    return FMath::FRandRange(MinInterval, FMath::Max(MinInterval, MaxInterval));
}
```

### Explicação das decisões

- **`UCLASS(Abstract, Blueprintable)`.** `Abstract` impede que alguém coloque um `AVGAlarm` "cru" no nível — ele não teria apresentação nenhuma. O designer usa sempre um Blueprint filho.
- **Agendamento por timer de disparo único, reagendado ao final.** No Blueprint do Capítulo 12, um timer em loop disparava o alarme a cada intervalo fixo. Agora, com intervalos variáveis, cada alarme agenda o próximo quando termina. Efeito colateral bom: o intervalo passa a contar **a partir do fim** do alarme anterior, e sobreposição é impossível por construção (a guarda continua como defesa).
- **`TriggerAlarm` é público e `BlueprintCallable`.** Um evento roteirizado (Projeto 4) pode disparar o alarme num momento exato, com `bPeriodic = false`.
- **Dois mecanismos de saída, com papéis diferentes:** `OnAlarmStarted` (evento de extensão, para a apresentação do próprio alarme) e `OnAlarmStartedEvent` (delegate, para outros objetos). Os nomes deixam o papel claro: o sufixo `Event` indica o delegate. Para a apresentação, a classe chama primeiro o evento de extensão e depois o delegate — a ordem raramente importa aqui, e a regra do Capítulo 4 (estado consistente antes de anunciar) é respeitada: `bActive` já é verdadeiro.
- **`ComputeNextInterval` como `BlueprintNativeEvent`.** O padrão (aleatório entre min e max) resolve a maioria dos casos. A regra de **escalada** do desafio do Capítulo 12 vira uma sobrescrita no Blueprint de um alarme específico — ou, se se provar útil em vários lugares, uma propriedade no C++. A decisão fica adiada até haver um segundo caso (Capítulo 6).
- **Inicialização antes do `Super::BeginPlay()`** (seção 13.7).
- **`ClearAllTimersForObject` no `EndPlay`.**

### A migração do conteúdo

1. Compile e reabra o editor.
2. Abra `BP_AlarmeUsina` → *Class Settings* → **Parent Class = `VGAlarm`**. (Reparentar um Blueprint é uma operação suportada; faça backup ou commit antes.)
3. **Remova do Blueprint** o que agora é do C++: a variável `bAlarmeAtivo`, os timers, os Event Dispatchers `OnAlarmeIniciado`/`OnAlarmeTerminado`, e as variáveis `IntervaloAlarme`/`DuracaoAlarme` (substituídas por `MinInterval`, `MaxInterval`, `Duration`).
4. **Mantenha** no Blueprint: componentes (`LuzAlarme`, `Sirene`), a Timeline `TL_Pulso`, `IntensidadeMaxima`, `PadraoFalhaPostes`.
5. Implemente os eventos herdados:

```text
[Event OnAlarmStarted]          -- evento de extensão vindo do C++
  → Sirene.Play
  → TL_Pulso.Play from Start

[Event OnAlarmEnded]
  → TL_Pulso.Stop
  → LuzAlarme.Set Intensity(0)
  → Sirene.Stop

[TL_Pulso.Update]
  → LuzAlarme.Set Intensity(Pulso × {IntensidadeMaxima})
```

6. Nos postes (`BP_PosteLuz`), troque o tipo da variável `Alarme` de `BP_AlarmeUsina` para **`VGAlarm`** (a classe C++) e religue os *binds* aos delegates `OnAlarmStartedEvent` / `OnAlarmEndedEvent`. O padrão de falha dos postes, que vinha de uma variável do `BP_AlarmeUsina`, agora exige um cast para o Blueprint — **ou**, melhor, vira uma propriedade do **poste** (`PadraoDuranteAlarme`), já que é o poste que decide como reage. Faça a segunda opção: ela elimina a referência do poste ao Blueprint do alarme.

7. Recoloque nos postes as referências ao alarme no nível (a mudança de tipo pode limpar o valor) e teste: o comportamento deve ser idêntico ao do Capítulo 12, com intervalos agora variáveis.

### O que se aprendeu com a versão anterior

A versão 100% Blueprint **não foi um erro**. Ela permitiu descobrir, em uma tarde, se o alarme funcionava como atmosfera — e funcionou. O que a tornou insuficiente não foi a qualidade, foi **o crescimento do escopo**: o alarme deixou de ser um objeto de um nível e virou um sistema que outros sistemas precisam observar. É o ciclo saudável de um projeto de jogo: **prototipar em Blueprint, consolidar em C++ o que se provou sistema, manter em Blueprint o que é conteúdo.**

---

## Comparação com o desenvolvimento tradicional

| Ferramenta | O que você conhece | Onde a analogia cai |
|---|---|---|
| Regra de camadas | Camadas por responsabilidade | O critério é **quem altera e com que frequência**, não abstração |
| `BlueprintImplementableEvent` | Template Method com passo opcional | O "filho" é conteúdo editado por designers |
| `BlueprintNativeEvent` | Template Method com padrão | Cada evento é uma promessa de compatibilidade com conteúdo |
| Delegate `BlueprintAssignable` | Observer | Síncrono (Capítulo 4) |
| Function Library | Classe utilitária estática | É também **descoberta** (paleta, palavras-chave) |
| Data Asset | Configuração tipada externalizada | É um `UObject` compartilhado; somente leitura em runtime por convenção |
| `IsDataValid` | Validação de schema / linter de configuração | Roda no editor, para designers, antes do jogo |
| Reparentar Blueprint | Extrair superclasse | Operação no editor, sobre binários — commit antes |

---

## Decisões arquiteturais

1. **A regra de camadas** (seção 13.1) é o critério do projeto, aplicada com as oito perguntas.
2. **Classes base C++ de conteúdo são `Abstract` quando não fazem sentido sem apresentação.**
3. **Pontos de extensão:** `BlueprintImplementableEvent` para apresentação da própria classe; `BlueprintNativeEvent` para políticas com padrão; delegates para outros objetos. Poucos, nomeados por intenção.
4. **`BlueprintPure` só para funções baratas e sem efeitos.**
5. **`UVGBlueprintLibrary`** para utilitários de uso frequente pelo conteúdo — não para espelhar o C++.
6. **Data Assets (`UPrimaryDataAsset`) para configuração compartilhada; somente leitura em runtime.**
7. **Validação de conteúdo no editor (`IsDataValid`)** em toda classe que pode ser mal configurada.
8. **Inicialização de regras antes do `Super::BeginPlay()`.**
9. **Prototipar em Blueprint; consolidar em C++ quando virar sistema;** registrar a migração no `DEVLOG.md`.

---

## Armadilhas

- **Tudo em C++** (designers bloqueados) ou **tudo em Blueprint** (sistemas frágeis).
- **`BlueprintPure` em funções caras.**
- **Pontos de extensão demais**, que congelam a classe base.
- **Blueprint escrevendo estado do C++ diretamente** (propriedades `BlueprintReadWrite` de estado).
- **Escrever em Data Assets em runtime.**
- **Mensagens de validação técnicas** que um designer não entende.
- **Esquecer `#if WITH_EDITOR`** em código de validação.
- **Reparentar Blueprints sem commit antes.**
- **Depender da ordem C++/Blueprint no `BeginPlay`** sem saber qual é.

---

## Exercício

**Parte 1 — a migração (2 h).** Implemente `AVGAlarm` e faça a migração do `BP_AlarmeUsina` e dos postes, seguindo os passos. Verifique que o comportamento é o mesmo do Capítulo 12. Registre no `DEVLOG.md` a migração, com o formato de um ADR: contexto, decisão, consequências.

**Parte 2 — política sobrescrita (45 min).** Crie um segundo Blueprint filho, `BP_AlarmeEscalada`, que sobrescreve `ComputeNextInterval` para que cada intervalo seja 80% do anterior, até um mínimo de 10 s (chame o *Parent* na primeira vez). Coloque-o num nível de teste e verifique.

**Parte 3 — Data Asset (1 h).** Implemente `UVGFlickerProfile`. Adicione ao `UVGFlickerComponent` uma propriedade `Profile` (`TObjectPtr<UVGFlickerProfile>`): se definida, ela fornece padrão, velocidade e suavização; se não, valem as propriedades locais. Crie três perfis e aplique-os aos postes.

**Parte 4 — validação (45 min).** Implemente `IsDataValid` no `AVGSpawner` e no `UVGFlickerComponent` (padrão vazio **e** sem perfil, ou caracteres fora de `a`–`z` no padrão). Rode a validação de dados do editor (clique direito no asset/pasta → validar) e verifique as mensagens.

---

## Desafio — a biblioteca e o designer

Peça a alguém que não programa (ou faça você mesmo, fingindo não saber C++) para criar, só com o editor, uma **lâmpada de emergência** que: começa apagada; acende com uma falha suave quando o alarme começa; e apaga quando ele termina. Observe (ou anote) **onde a pessoa trava**: não encontra o nó? Não entende uma propriedade? Faz um cast desnecessário?

Para cada ponto de atrito, decida se a solução é: (a) renomear ou recategorizar algo; (b) adicionar um tooltip; (c) adicionar uma função à `UVGBlueprintLibrary`; (d) adicionar um ponto de extensão; ou (e) nada — o atrito é aceitável. Implemente as melhorias que valerem a pena. Este exercício é, essencialmente, **teste de usabilidade da sua API** — com o designer como usuário.

---

## Uso de IA

1. **Para aplicar a regra de camadas:**
   > "Este é um sistema de [descrição] em Unreal Engine 5. Usando os critérios a seguir — ajustabilidade por designers, invariantes, estado salvo/replicado, execução por frame em muitas instâncias, chamadas por outros sistemas C++, especificidade de conteúdo, apresentação, maturidade da ideia —, proponha a divisão entre C++, Blueprint e Data Assets, e os pontos de extensão (BlueprintImplementableEvent, BlueprintNativeEvent, delegates) necessários. Evite mais de três pontos de extensão."

2. **Para revisar uma classe base:**
   > "Revise esta classe C++ da Unreal pensada para ser base de Blueprints de conteúdo. Avalie: o estado está protegido? Os pontos de extensão têm nomes de intenção e são poucos? As propriedades editáveis têm categoria, tooltip, limites e o especificador Edit* adequado? A classe funciona sem Blueprint? Existe validação no editor? [código]"

3. **Para planejar migrações:**
   > "Tenho um Blueprint que vou reparentar para uma nova classe C++ base. Liste os riscos (variáveis duplicadas, referências que se perdem, dispatchers substituídos por delegates, valores por instância nos níveis) e um passo a passo seguro, incluindo o que verificar depois."

**Cuidado específico:** assinaturas de funções virtuais de editor (`IsDataValid`, `PostEditChangeProperty`) e alguns especificadores de metadados mudaram entre versões do UE5. Sempre confira a declaração na classe base da sua versão antes de sobrescrever.

---

## Checklist

- [ ] Sei aplicar as oito perguntas da regra de camadas.
- [ ] Sei escolher entre `BlueprintCallable` e `BlueprintPure` pelo custo.
- [ ] Sei usar `BlueprintImplementableEvent`, `BlueprintNativeEvent` e delegates, e quando cada um é o certo.
- [ ] Sei desenhar uma classe base C++ para designers: estado protegido, poucos pontos de extensão, configuração bem exposta, funciona sem Blueprint.
- [ ] Criei a `UVGBlueprintLibrary` com funções úteis e encontráveis.
- [ ] Sei criar e usar Data Assets e por que são somente leitura em runtime.
- [ ] Implementei validação de conteúdo com `IsDataValid`.
- [ ] Sei a ordem de execução entre C++ e Blueprint no `BeginPlay`.
- [ ] Migrei o alarme para `AVGAlarm` e sei explicar o que motivou a migração.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Exposing Gameplay Elements to Blueprints**, **Blueprint Function Libraries**, **Data Assets**, **Asset Manager**, **Data Validation**.
- **Busque talks e artigos da Epic sobre "Blueprints vs. C++"** — a própria Epic publica orientações sobre a divisão, e elas concordam, em linhas gerais, com a regra de camadas deste capítulo.

---

➡️ **Próximo:** [Capítulo 14 — Input](cap-14-input.md)

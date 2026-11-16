# Capítulo 31 — Objectives

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir **objetivos de modo de jogo** (regras de uma partida ou desafio) de **objetivos narrativos** (quests — Parte VI);
- modelar um objetivo como **definição** (dados) + **estado** (runtime) + **regra de progresso** (função pura);
- alimentar objetivos pelo **barramento de eventos** (Capítulo 24), sem que as fontes saibam que objetivos existem;
- separar **quem acompanha** objetivos (um subsistema) de **quem decide o que eles significam** (as regras do modo);
- construir o **desafio de tiro** do Galpão e entender como modos clássicos de FPS (Dominação, Conquista) se decompõem do mesmo jeito.

---

## Contexto

O Galpão tem armas, alvos e vigias. Ainda não tem **propósito**: a jogadora atira porque quer. Objetivos dão propósito, estrutura e feedback de progresso — e, num jogo de FPS multiplayer, eles **são** o modo de jogo: capturar pontos, eliminar o time adversário, manter uma bandeira.

Este capítulo constrói um sistema de objetivos **pequeno e honesto**: suficiente para desafios de tiro, objetivos de nível ("religue o disjuntor", "chegue à Casa de Força") e para o HUD mostrar "o que fazer agora". Ele **não** é um sistema de quests — sem ramificações, condições compostas, recompensas ou persistência entre níveis. A Parte VI (Capítulo 45) parte dele e o generaliza, e vai explicar exatamente o que faltou.

---

## 31.1 Dois tipos de objetivo

| | Objetivo de modo / desafio | Objetivo narrativo (quest) |
|---|---|---|
| Exemplo | "Derrube 10 alvos em 60 s"; "capture o ponto B" | "Descubra o que aconteceu com o turno da noite" |
| Duração | Segundos a minutos | Minutos a horas; atravessa níveis |
| Estrutura | Linear; uma condição de sucesso, às vezes uma de falha | Etapas, ramificações, condições, consequências |
| Persistência | Geralmente nenhuma | Salvo; afeta o mundo e o diálogo |
| Dono das regras | GameMode / controlador do desafio | Sistema narrativo (Parte VI) |
| Capítulo | **31** | 45–47 |

A linha é útil porque evita dois erros opostos: construir um sistema de quests completo para contar alvos derrubados (arquitetura elegante, inadequada — Capítulo 6), ou tentar contar a história da usina com contadores de eventos (o Projeto 4 vai sentir essa dor).

---

## 31.2 Definição, estado e regra

Um objetivo tem três partes, que espelham a separação dados/estado/comportamento das armas (Capítulo 20):

```text
DEFINIÇÃO (Data Asset — o que o objetivo É)
  título e descrição (FText)
  tipo: contar eventos | sobreviver por um tempo
  canal do evento (ex.: Event.Actor.Died) + filtro (ex.: alvo com tag Faction.Target)
  quantidade necessária; limite de tempo (opcional)

ESTADO (runtime — o que o objetivo ESTÁ)
  Inactive → Active → Completed | Failed
  progresso (ex.: 7 / 10), tempo restante

REGRA (função pura)
  dado (definição, estado, evento) → novo estado
```

A regra como **função pura** é o que permite testar objetivos sem mundo, sem tempo e sem física (Capítulo 6, seção 6.6 — o que transfere da Clean Architecture). E o **tempo** entra como entrada explícita (Δt), como em todo o resto do jogo (Capítulo 1, seção 1.5).

### Objetivos alimentados por eventos

O barramento do Capítulo 24 já publica os fatos de que os objetivos precisam: `Event.Actor.Died` (com instigador e alvo), `Event.Item.Collected` (com o item), `Event.Door.Opened`, `Event.Sector.Powered`. Falta um: **"a jogadora chegou a um lugar"**. O `AVGEventTrigger` (Capítulo 15) passa a publicar `Event.Trigger.Entered`, com uma **tag de contexto** configurada no próprio gatilho (`Location.PowerHouse.Entrance`).

Com isso, quase qualquer objetivo simples é uma **contagem de eventos filtrados**:

| Objetivo | Canal | Filtro | Quantidade |
|---|---|---|---|
| Derrube 10 alvos | `Event.Actor.Died` | alvo com `Faction.Target`; instigador é a jogadora | 10 |
| Pegue 3 baterias | `Event.Item.Collected` | contexto `Item.Battery` | 3 |
| Religue o setor B | `Event.Sector.Powered` | contexto `Sector.B` | 1 |
| Chegue à Casa de Força | `Event.Trigger.Entered` | contexto `Location.PowerHouse.Entrance` | 1 |

E **nenhuma das fontes sabe que objetivos existem**: o alvo morre e anuncia; o pickup é coletado e anuncia; o gatilho é atravessado e anuncia. É o caso de uso para o qual o barramento foi criado: relações muitos-para-muitos sem referência natural.

---

## 31.3 Quem acompanha e quem decide

Duas responsabilidades diferentes:

- **Acompanhar** — manter o estado dos objetivos ativos, aplicar eventos, contar tempo, anunciar mudanças para a HUD. Isso é **igual** em todos os níveis e modos → um **subsistema** (`UVGObjectiveSubsystem`, de mundo).
- **Decidir** — quais objetivos ativar, em que ordem, e **o que acontece** quando um é concluído ou falha (abrir uma porta, encerrar o desafio, dar uma recompensa, iniciar o próximo). Isso é **regra** do modo ou do nível → o **GameMode** (Capítulo 10) ou, para desafios dentro de um nível, um **controlador de desafio** (um ator com a lógica em Blueprint).

```text
   fontes ──► barramento ──► UVGObjectiveSubsystem ──► OnObjectiveUpdated ──► HUD
                                   ▲        │
                   Activate(Def)   │        │ OnObjectiveCompleted / Failed
                                   │        ▼
                         CONTROLADOR (GameMode / desafio): decide o que vem depois
```

É a separação "mecanismo vs. política" do Capítulo 10 (seção 10.2), aplicada a objetivos.

---

## Estudo de caso: modos de jogo como regras sobre eventos

> **Pergunta:** como modos clássicos de FPS multiplayer se decompõem em sistemas?

**[FATO PÚBLICO]** Na série Call of Duty, o modo **Dominação** (*Domination*) tem tipicamente três pontos de captura (A, B, C); times ganham pontos ao longo do tempo pelos pontos que controlam, e a partida termina quando um time atinge o limite de pontos ou o tempo acaba. Na série Battlefield, o modo **Conquista** (*Conquest*) usa **tickets**: cada time começa com uma quantidade, que diminui a cada reaparecimento (*respawn*) de um jogador seu — um aliado reanimado não custa ticket — e com a posse de bandeiras pelo adversário; o time que zera os tickets perde.

**[INFERÊNCIA]** Decompostos com o vocabulário deste livro, ambos são:

```text
 ESTADO COMPARTILHADO (GameState — Cap. 10)   placar/tickets por time, dono de cada ponto
 EVENTOS                                      jogador morreu (instigador, vítima, times);
                                              ponto começou/terminou de ser capturado
 REGRAS (GameMode, no servidor)               a cada segundo: +pontos/−tickets por pontos possuídos;
                                              a cada morte: −ticket do time da vítima;
                                              fim: limite atingido ou tempo esgotado
 APRESENTAÇÃO (HUD, áudio, anunciador)        reage ao estado e aos eventos
```

A "inteligência" do modo está nas **regras**, que são poucas; o resto é estado compartilhado e eventos — exatamente a estrutura do `UVGObjectiveSubsystem` + controlador deste capítulo, com a diferença crucial de que, em multiplayer, as regras rodam **no servidor** e o estado é **replicado** (Parte IX). Nenhuma afirmação é feita sobre as implementações reais.

**Lição:** **modos de jogo e objetivos são regras sobre um fluxo de eventos e um estado compartilhado.** Desenhar os eventos e o estado bem torna as regras pequenas — e trocar de modo vira trocar de regras, não de sistemas.

---

## Comparação com o desenvolvimento tradicional

| Objetivos | O que você conhece | Onde a analogia cai |
|---|---|---|
| Definição + estado + regra pura | Máquina de estado de processo com reducer | O tempo é uma entrada contínua (Δt) |
| Progresso por eventos filtrados | Consumidor que agrega eventos de um tópico | Síncrono, no mesmo frame |
| Subsistema acompanha, controlador decide | Engine de workflow vs. definição do processo | O "processo" muda a cada nível e é autorado por designers |

> 🌉 **Ponte:** a função `ApplyEvent(definição, estado, evento) → estado` é um **reducer** — o mesmo padrão de Redux ou de *event sourcing*. Ela é pura, determinística e testável; o subsistema é o "store" que a executa.

---

## Implementação

### 1. Canais e contexto

Novas tags nativas: `TAG_Event_Trigger_Entered` (`Event.Trigger.Entered`) e `TAG_Faction_Target` (`Faction.Target`, para alvos de treino). Tags de conteúdo sob `Location.*`, `Item.*` e `Sector.*` registradas no `docs/design/tags.md`.

🔁 O `AVGEventTrigger` ganha `UPROPERTY(EditAnywhere, meta = (Categories = "Location")) FGameplayTag LocationTag;` e, ao disparar, publica:

```cpp
UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Trigger_Entered, OtherActor, this, LocationTag);
```

### 2. A definição

```cpp
// Source/Vigilia/World/VGObjectiveData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "GameplayTagContainer.h"
#include "VGObjectiveData.generated.h"

UENUM(BlueprintType)
enum class EVGObjectiveKind : uint8
{
    CountEvents,   // conclui ao contar N eventos que passam no filtro
    Survive        // conclui ao sobreviver pelo tempo-limite (falha por outro meio)
};

/** O que um objetivo É. Imutável em runtime. */
UCLASS(BlueprintType)
class VIGILIA_API UVGObjectiveData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective")
    FText Title;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective", meta = (MultiLine = "true"))
    FText Description;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective")
    EVGObjectiveKind Kind = EVGObjectiveKind::CountEvents;

    /** Canal do barramento observado (ex.: Event.Actor.Died). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective|Filter", meta = (Categories = "Event"))
    FGameplayTag EventChannel;

    /** Se definida, o evento precisa ter este contexto (ou um filho dele). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective|Filter")
    FGameplayTag RequiredContext;

    /** Se definida, o ALVO do evento precisa ter esta tag (ex.: Faction.Target). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective|Filter")
    FGameplayTag RequiredTargetTag;

    /** Se verdadeiro, só conta eventos cujo instigador é um pawn controlado por jogador. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective|Filter")
    bool bRequirePlayerInstigator = false;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective", meta = (ClampMin = "1"))
    int32 RequiredCount = 1;

    /** 0 = sem limite. CountEvents: falha ao esgotar. Survive: conclui ao esgotar. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Objective", meta = (ClampMin = "0.0"))
    float TimeLimit = 0.0f;
};
```

### 3. Estado e regra pura

```cpp
// Source/Vigilia/World/VGObjectiveTypes.h
#pragma once

#include "CoreMinimal.h"
#include "VGObjectiveTypes.generated.h"

class UVGObjectiveData;
struct FVGGameplayEvent;

UENUM(BlueprintType)
enum class EVGObjectiveStatus : uint8
{
    Inactive,
    Active,
    Completed,
    Failed
};

USTRUCT(BlueprintType)
struct FVGObjectiveState
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Objective")
    TObjectPtr<const UVGObjectiveData> Definition;

    UPROPERTY(BlueprintReadOnly, Category = "Objective")
    EVGObjectiveStatus Status = EVGObjectiveStatus::Inactive;

    UPROPERTY(BlueprintReadOnly, Category = "Objective")
    int32 Progress = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Objective")
    float TimeRemaining = 0.0f;
};

/** Regras de objetivo como funções puras (testáveis sem mundo). Retornam true se o estado mudou. */
namespace VGObjectiveRules
{
    bool EventMatches(const UVGObjectiveData& Def, const FVGGameplayEvent& Event);
    bool ApplyEvent(FVGObjectiveState& State, const FVGGameplayEvent& Event);
    bool AdvanceTime(FVGObjectiveState& State, float DeltaSeconds);
}
```

```cpp
// Source/Vigilia/World/VGObjectiveTypes.cpp
#include "World/VGObjectiveTypes.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGStatusTagsComponent.h"
#include "GameFramework/Pawn.h"
#include "GameplayTagAssetInterface.h"
#include "World/VGObjectiveData.h"

bool VGObjectiveRules::EventMatches(const UVGObjectiveData& Def, const FVGGameplayEvent& Event)
{
    if (!Event.Channel.MatchesTag(Def.EventChannel))
    {
        return false;
    }
    if (Def.RequiredContext.IsValid() && !Event.Context.MatchesTag(Def.RequiredContext))
    {
        return false;
    }
    if (Def.RequiredTargetTag.IsValid())
    {
        // Atores C++ expõem tags pela interface (Cap. 23). Blueprints puros — como os alvos
        // manequins — não podem implementá-la (CannotImplementInterfaceInBlueprint): para eles,
        // o componente de tags.
        bool bHasTag = false;
        if (const IGameplayTagAssetInterface* Tagged = Cast<IGameplayTagAssetInterface>(Event.Target))
        {
            bHasTag = Tagged->HasMatchingGameplayTag(Def.RequiredTargetTag);
        }
        else if (Event.Target)
        {
            const UVGStatusTagsComponent* Tags = Event.Target->FindComponentByClass<UVGStatusTagsComponent>();
            bHasTag = Tags && Tags->HasTag(Def.RequiredTargetTag);
        }
        if (!bHasTag)
        {
            return false;
        }
    }
    if (Def.bRequirePlayerInstigator)
    {
        const APawn* Pawn = Cast<APawn>(Event.Instigator);
        if (!Pawn || !Pawn->IsPlayerControlled())
        {
            return false;
        }
    }
    return true;
}

bool VGObjectiveRules::ApplyEvent(FVGObjectiveState& State, const FVGGameplayEvent& Event)
{
    if (State.Status != EVGObjectiveStatus::Active || !State.Definition
        || State.Definition->Kind != EVGObjectiveKind::CountEvents
        || !EventMatches(*State.Definition, Event))
    {
        return false;
    }
    State.Progress = FMath::Min(State.Progress + 1, State.Definition->RequiredCount);
    if (State.Progress >= State.Definition->RequiredCount)
    {
        State.Status = EVGObjectiveStatus::Completed;
    }
    return true;
}

bool VGObjectiveRules::AdvanceTime(FVGObjectiveState& State, float DeltaSeconds)
{
    if (State.Status != EVGObjectiveStatus::Active || !State.Definition || State.Definition->TimeLimit <= 0.0f)
    {
        return false;
    }
    State.TimeRemaining = FMath::Max(State.TimeRemaining - DeltaSeconds, 0.0f);
    if (State.TimeRemaining <= 0.0f)
    {
        State.Status = (State.Definition->Kind == EVGObjectiveKind::Survive)
            ? EVGObjectiveStatus::Completed
            : EVGObjectiveStatus::Failed;
    }
    return true; // o tempo mudou (a HUD consulta; ver abaixo)
}
```

`MatchesTag` (o "é um" hierárquico, Capítulo 23) permite filtros genéricos: um objetivo com `RequiredContext = Item.Battery` conta qualquer `Item.Battery.*`.

### 4. O subsistema

```cpp
// Source/Vigilia/World/VGObjectiveSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "Tickable.h"
#include "World/VGObjectiveTypes.h"
#include "VGObjectiveSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGObjectiveChangedSignature, const FVGObjectiveState&, State);

/**
 * Acompanha objetivos ativos do mundo: aplica eventos do barramento e o tempo, e anuncia mudanças
 * DISCRETAS (progresso, conclusão, falha). O tempo restante é consultado pela HUD (contínuo).
 * Quem decide quais objetivos ativar e o que acontece depois é o controlador (GameMode/desafio).
 */
UCLASS()
class VIGILIA_API UVGObjectiveSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Deinitialize() override;
    virtual void Tick(float DeltaTime) override;
    virtual TStatId GetStatId() const override;

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Objectives")
    void ActivateObjective(const UVGObjectiveData* Definition);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Objectives")
    void CancelObjective(const UVGObjectiveData* Definition);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Objectives")
    TArray<FVGObjectiveState> GetActiveObjectives() const;

    /** Progresso mudou (sem concluir). */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Objectives")
    FVGObjectiveChangedSignature OnObjectiveUpdated;

    /** Concluído ou falhou: o controlador decide o que vem depois. */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Objectives")
    FVGObjectiveChangedSignature OnObjectiveFinished;

private:
    void HandleEvent(const FVGGameplayEvent& Event);
    void Finish(int32 Index);

    TArray<FVGObjectiveState> Objectives;
    FDelegateHandle EventHandle;
};
```

```cpp
// Source/Vigilia/World/VGObjectiveSubsystem.cpp
#include "World/VGObjectiveSubsystem.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "World/VGObjectiveData.h"

void UVGObjectiveSubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
    if (UVGGameplayEventSubsystem* Bus = InWorld.GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &UVGObjectiveSubsystem::HandleEvent);
    }
}

void UVGObjectiveSubsystem::Deinitialize()
{
    if (UVGGameplayEventSubsystem* Bus = GetWorld() ? GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>() : nullptr)
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::Deinitialize();
}

TStatId UVGObjectiveSubsystem::GetStatId() const
{
    RETURN_QUICK_DECLARE_CYCLE_STAT(UVGObjectiveSubsystem, STATGROUP_Tickables);
}

void UVGObjectiveSubsystem::ActivateObjective(const UVGObjectiveData* Definition)
{
    if (!Definition || Objectives.ContainsByPredicate([Definition](const FVGObjectiveState& S) { return S.Definition == Definition; }))
    {
        return; // já ativo (guarda de estado)
    }
    FVGObjectiveState& State = Objectives.AddDefaulted_GetRef();
    State.Definition = Definition;
    State.Status = EVGObjectiveStatus::Active;
    State.TimeRemaining = Definition->TimeLimit;
    OnObjectiveUpdated.Broadcast(State);
}

void UVGObjectiveSubsystem::CancelObjective(const UVGObjectiveData* Definition)
{
    Objectives.RemoveAll([Definition](const FVGObjectiveState& S) { return S.Definition == Definition; });
}

TArray<FVGObjectiveState> UVGObjectiveSubsystem::GetActiveObjectives() const
{
    return Objectives;
}

void UVGObjectiveSubsystem::HandleEvent(const FVGGameplayEvent& Event)
{
    for (int32 i = Objectives.Num() - 1; i >= 0; --i) // de trás para frente: Finish remove (Cap. 11)
    {
        if (VGObjectiveRules::ApplyEvent(Objectives[i], Event))
        {
            if (Objectives[i].Status == EVGObjectiveStatus::Active)
            {
                OnObjectiveUpdated.Broadcast(Objectives[i]);
            }
            else
            {
                Finish(i);
            }
        }
    }
}

void UVGObjectiveSubsystem::Tick(float DeltaTime)
{
    for (int32 i = Objectives.Num() - 1; i >= 0; --i)
    {
        if (VGObjectiveRules::AdvanceTime(Objectives[i], DeltaTime)
            && Objectives[i].Status != EVGObjectiveStatus::Active)
        {
            Finish(i);
        }
    }
}

void UVGObjectiveSubsystem::Finish(int32 Index)
{
    const FVGObjectiveState Finished = Objectives[Index]; // cópia: o ouvinte pode ativar outro objetivo
    Objectives.RemoveAt(Index);
    OnObjectiveFinished.Broadcast(Finished);
}
```

### Explicação das decisões

- **`UTickableWorldSubsystem`**: um subsistema de mundo que também tica — necessário para o tempo-limite. Ele só faz trabalho real quando há objetivos com limite.
- **Ouvinte nativo do barramento** (`AddUObject` + `FDelegateHandle`), removido no `Deinitialize` (Capítulo 24): o subsistema é C++, e o handle permite remoção precisa.
- **Iteração de trás para frente** porque `Finish` remove do array (Capítulo 11, seção 11.6).
- **Cópia do estado em `Finish` antes do broadcast**, e remoção antes de anunciar: o controlador, ao receber "concluído", pode ativar o próximo objetivo — o que altera o array — sem invalidar o que está sendo anunciado (reentrância, Capítulo 4).
- **Anúncios discretos** (progresso, conclusão, falha); o tempo restante é **consultado** (`GetActiveObjectives`) pela HUD a cada frame (Capítulo 4: contínuo → consulta).
- **Guarda contra ativar o mesmo objetivo duas vezes.**

### 5. Teste da regra

```cpp
// Source/Vigilia/Tests/VGObjectiveRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "World/VGObjectiveData.h"
#include "World/VGObjectiveTypes.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGObjectiveRulesTest, "Vigilia.World.Objectives.CountAndTime",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGObjectiveRulesTest::RunTest(const FString& Parameters)
{
    UVGObjectiveData* Def = NewObject<UVGObjectiveData>();
    Def->Kind = EVGObjectiveKind::CountEvents;
    Def->EventChannel = TAG_Event_Item_Collected;
    Def->RequiredCount = 2;
    Def->TimeLimit = 10.0f;

    FVGObjectiveState State;
    State.Definition = Def;
    State.Status = EVGObjectiveStatus::Active;
    State.TimeRemaining = Def->TimeLimit;

    FVGGameplayEvent Collected;
    Collected.Channel = TAG_Event_Item_Collected;
    FVGGameplayEvent Other;
    Other.Channel = TAG_Event_Door_Opened;

    TestFalse(TEXT("Canal diferente não conta"), VGObjectiveRules::ApplyEvent(State, Other));
    TestTrue(TEXT("Primeiro item conta"), VGObjectiveRules::ApplyEvent(State, Collected));
    TestEqual(TEXT("Progresso 1"), State.Progress, 1);

    VGObjectiveRules::AdvanceTime(State, 4.0f);
    TestTrue(TEXT("Ainda ativo após 4 s"), State.Status == EVGObjectiveStatus::Active);

    VGObjectiveRules::ApplyEvent(State, Collected);
    TestTrue(TEXT("Concluído com 2 itens"), State.Status == EVGObjectiveStatus::Completed);
    TestFalse(TEXT("Concluído não recebe mais eventos"), VGObjectiveRules::ApplyEvent(State, Collected));

    FVGObjectiveState Late = State;
    Late.Status = EVGObjectiveStatus::Active;
    Late.Progress = 0;
    Late.TimeRemaining = 1.0f;
    VGObjectiveRules::AdvanceTime(Late, 2.0f);
    TestTrue(TEXT("Contagem com tempo esgotado falha"), Late.Status == EVGObjectiveStatus::Failed);
    return true;
}

#endif
```

---

## Projeto 2 — o desafio de tiro

1. **`DA_Obj_Treino10Alvos`**: `CountEvents`, canal `Event.Actor.Died`, `RequiredTargetTag = Faction.Target`, `bRequirePlayerInstigator`, 10, limite 60 s.
2. Os alvos manequins (Capítulo 27) ganham um `UVGStatusTagsComponent` com `IdentityTags = Faction.Target` (são Blueprints de `AActor`: não podem implementar `IGameplayTagAssetInterface`, por isso o filtro também consulta o componente) — e passam a publicar `Event.Actor.Died` pelo componente de vida (Capítulo 27).
3. **`BP_ControladorDesafio`** (um ator no Galpão, em Blueprint): um botão interativo (filho de `AVGPickup` sem consumo) chama `ActivateObjective`; o controlador escuta `OnObjectiveFinished` e, em caso de sucesso, abre a porta dos fundos do Galpão (`AVGDoor::Unlock`), e em caso de falha, reinicia os alvos.
4. **HUD de objetivos** (widget de debug): título, progresso e tempo restante do objetivo ativo, consultando o subsistema.
5. **Objetivos de nível no Pátio** (ativados no `BeginPlay` do Pátio por um controlador simples): "Religue a energia do Galpão" (`Event.Sector.Powered`, contexto `Sector.Galpao`) e, ao concluir, "Vá até a Casa de Força" (`Event.Trigger.Entered`, `Location.PowerHouse.Entrance`).

---

## Decisões arquiteturais

1. **Objetivos de modo/desafio (este capítulo) ≠ quests (Parte VI).**
2. **Definição (Data Asset) + estado (struct) + regra (funções puras testadas).**
3. **Progresso por eventos filtrados do barramento**; fontes não conhecem objetivos.
4. **O subsistema acompanha; o controlador (GameMode ou ator de desafio) decide o que os objetivos significam.**
5. **Anúncios discretos; tempo consultado.**
6. **`AVGEventTrigger` publica `Event.Trigger.Entered` com tag de local.**

---

## Armadilhas

- **Fontes que chamam o sistema de objetivos diretamente** ("o alvo avisa o desafio").
- **Regras de progresso espalhadas** por Blueprints de nível em vez de uma função.
- **Broadcast durante iteração** sem copiar e remover antes (reentrância).
- **Anunciar o tempo restante a cada frame.**
- **Usar este sistema para narrativa** — ramificações e consequências viram `if`s em controladores.
- **Filtros por classe** (`Cast<BP_Alvo>`) em vez de tags.

---

## Exercício

**Parte 1 — o sistema (2 h).** Implemente definição, estado, regras, subsistema e teste. Faça o `AVGEventTrigger` publicar entradas com tag de local.

**Parte 2 — desafio (1,5 h).** Monte o desafio de tiro no Galpão, com controlador, HUD e porta dos fundos.

**Parte 3 — objetivos do Pátio (1 h).** Implemente a cadeia "religar o Galpão → ir até a Casa de Força". Observe com `vg.Debug.Events` os eventos que fazem o progresso avançar.

**Parte 4 — modos (45 min).** Escreva, no formato do estudo de caso (estado compartilhado, eventos, regras, apresentação), a decomposição de um modo de jogo que você conhece bem e que não foi citado (por exemplo, *Search and Destroy*, *Capture the Flag*, ou um modo de um jogo de futebol: "primeiro a 3 gols").

---

## Desafio — o objetivo que o sistema não consegue expressar

Tente expressar, **só** com o sistema deste capítulo, o seguinte objetivo do Projeto 4 (Interlúdio I):

> *"Religue os três disjuntores do subsolo na ordem anotada no livro de ocorrências. Se você já leu o memorando do engenheiro, a operadora no rádio comenta a contradição entre os dois; se não leu, ela só confirma que os painéis responderam. Em qualquer caso, depois disso, a porta da sala de controle fica energizada."*

(São os beats 7 e 8 do Interlúdio I. Ler o memorando é opcional, e é dele que vem a ramificação.)

Liste exatamente o que falta (condições sobre fatos passados, ramificação, ações ao concluir que dependem do estado, persistência) e quanto disso você conseguiria improvisar no controlador em Blueprint. Esse improviso é o que o Projeto 4 vai fazer — e a lista é o requisito do sistema de quests do Capítulo 45.

---

## Uso de IA

1. **Para revisar o reducer:**
   > "Revise estas regras de objetivo (EventMatches, ApplyEvent, AdvanceTime) como funções puras: casos de borda (eventos após conclusão, tempo negativo, limite zero, filtros vazios), comportamento de MatchesTag com hierarquia de tags, e se o tipo Survive está correto. Sugira testes que estão faltando. [código]"

2. **Para decompor modos de jogo:**
   > "Decomponha os modos Dominação, Conquista com tickets e Search and Destroy em: estado compartilhado (o que fica no GameState), eventos, regras (o que roda no GameMode, no servidor) e apresentação. Separe o que é observável nos jogos do que é inferência sobre implementação."

3. **Para a fronteira com quests:**
   > "Tenho um sistema de objetivos baseado em contagem de eventos filtrados por tag, com tempo-limite. Quais requisitos típicos de quests narrativas (pré-condições, ramificações, etapas, consequências, persistência, objetivos opcionais) ele não atende, e qual seria a menor generalização que atenderia cada um sem virar um sistema genérico demais?"

---

## Checklist

- [ ] Sei distinguir objetivos de modo/desafio de quests.
- [ ] Modelei objetivo como definição + estado + regra pura, com testes.
- [ ] O progresso vem do barramento de eventos, com filtros por canal, contexto, tag do alvo e instigador.
- [ ] O subsistema acompanha; um controlador decide as consequências.
- [ ] Montei o desafio de tiro e os objetivos do Pátio.
- [ ] Consigo decompor modos de jogo multiplayer em estado, eventos, regras e apresentação.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Programming Subsystems** (e a referência de API de `UTickableWorldSubsystem`) e **Game Mode and Game State**.
- **Lyra Starter Game** — os modos de jogo da Lyra (como o de eliminação e o de captura de pontos) são exemplos de regras sobre eventos e estado replicado.

---

➡️ **Próximo:** [Capítulo 32 — Spawn System](cap-32-spawn-system.md)

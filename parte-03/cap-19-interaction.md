# Capítulo 19 — Interaction

*Projeto 3: Sistema de interação*

## Objetivo

Ao final deste capítulo você deve conseguir:

- comparar **quatro arquiteturas** para interação — herança, interface, componente e orientação a eventos — em complexidade, performance, extensibilidade, manutenção, prototipação e adequação ao projeto;
- implementar uma **interface Unreal** (`UINTERFACE`) com funções sobrescrevíveis em C++ e em Blueprint, e chamá-la corretamente (`Execute_`);
- construir o **componente de interação** da jogadora: detecção, foco, destaque visual, *prompt* contextual e execução;
- implementar a **porta** como máquina de estado com tempo (a promessa do Capítulo 1), o **disjuntor** e os **pickups**;
- montar o **Projeto 3**: portas, disjuntores, baterias, mensagens e interação contextual no Pátio e no Galpão.

---

## Contexto

"Apertar E para abrir a porta" é, possivelmente, a interação mais comum dos jogos em primeira pessoa. No Capítulo 1, ela foi usada para mostrar que até uma porta toca dez sistemas. Agora é hora de construí-la — e, mais importante, de construir o **sistema** que permite que **qualquer coisa** no mundo seja interativa: portas, disjuntores, gavetas, baterias, documentos, monitores, um NPC com quem conversar.

Este é o primeiro capítulo do livro em que a decisão de arquitetura vem **antes** do código, como o pedido original determinou: *mostre a arquitetura antes do código quando o problema for arquitetural*. Há pelo menos quatro formas razoáveis de construir um sistema de interação, e cada uma tem uma consequência real nos próximos 60 capítulos.

---

## 19.1 O problema

O sistema de interação precisa responder, continuamente, a quatro perguntas:

```text
 1. DETECÇÃO   O que está diante da jogadora, ao alcance?          (consulta espacial — Cap. 15)
 2. FOCO       Disso, o que é interativo? Qual é "o" alvo agora?   (estado: um alvo por vez)
 3. CONTEXTO   O que a interação faria? ("Abrir", "Trancada")      (prompt — depende do estado do alvo)
 4. AÇÃO       A jogadora pediu: execute, se for permitido.        (input → efeito no alvo)
```

E duas regras de design de partida:

- **Um alvo por vez.** Se duas coisas estão no centro da tela, uma é escolhida de forma previsível.
- **O prompt diz a verdade.** Se a porta está trancada, o prompt diz "Trancada" — e não "Abrir" seguido de nada acontecer. Isso é feedback (Capítulo 5): o jogador nunca deve precisar adivinhar.

A pergunta de arquitetura é: **como o sistema conversa com as coisas interativas** — que são de tipos muito diferentes, criadas por designers, e que vão se multiplicar?

---

## 19.2 Quatro arquiteturas

### Abordagem A — Herança

Uma classe base para tudo que é interativo:

```cpp
UCLASS(Abstract)
class AVGInteractableBase : public AActor
{
    GENERATED_BODY()
public:
    virtual bool CanInteract(AActor* Interactor) const { return true; }
    virtual void Interact(AActor* Interactor) PURE_VIRTUAL(AVGInteractableBase::Interact, );
    virtual FText GetPrompt(AActor* Interactor) const { return PromptText; }
protected:
    UPROPERTY(EditAnywhere) FText PromptText;
};

class AVGDoor : public AVGInteractableBase { /* ... */ };
class AVGPickup : public AVGInteractableBase { /* ... */ };
```

O sistema detecta com `Cast<AVGInteractableBase>(HitActor)`.

**Onde funciona:** é simples, direto e fácil de entender no primeiro dia.

**Onde quebra:** a primeira vez que algo **que já tem outra base** precisar ser interativo. O NPC com quem a jogadora conversa (Capítulo 44) é um `ACharacter`; ele não pode herdar de `AVGInteractableBase`. Um veículo é um `APawn`. Um objeto físico que se pega é um `AStaticMeshActor` com física. O C++ não tem herança múltipla de classes `UObject`. A hierarquia de herança força uma escolha que o design não quer fazer: "ser interativo" e "ser um personagem" são **capacidades independentes** — o problema da seção 6.3.

### Abordagem B — Interface

Uma **interface** declara o contrato; qualquer classe a implementa, não importa de quem herde:

```cpp
UINTERFACE(MinimalAPI, BlueprintType)
class UVGInteractable : public UInterface { GENERATED_BODY() };

class IVGInteractable
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintNativeEvent) bool CanInteract(AActor* Interactor) const;
    UFUNCTION(BlueprintNativeEvent) void Interact(AActor* Interactor);
    UFUNCTION(BlueprintNativeEvent) FText GetInteractionPrompt(AActor* Interactor) const;
};

class AVGDoor : public AActor, public IVGInteractable { /* ... */ };
class AVGNpc  : public ACharacter, public IVGInteractable { /* ... */ };   // ✓ agora funciona
```

O sistema detecta com `Actor->Implements<UVGInteractable>()` e chama `IVGInteractable::Execute_Interact(Actor, Interactor)`.

**Onde funciona:** qualquer ator pode ser interativo; o sistema de interação não conhece nenhuma classe concreta; Blueprints podem implementar a interface sem C++.

**Onde custa:** cada classe interativa implementa as funções — inclusive as que seriam iguais em todas (por exemplo, um prompt fixo). E a configuração (o texto do prompt, o alcance) fica espalhada pelas classes.

### Abordagem C — Componente

Interação vira uma **capacidade anexável**: um `UVGInteractableComponent` que se adiciona a qualquer ator, com propriedades configuráveis e um evento:

```cpp
UCLASS(meta = (BlueprintSpawnableComponent))
class UVGInteractableComponent : public USceneComponent
{
    GENERATED_BODY()
public:
    UPROPERTY(EditAnywhere) FText PromptText;
    UPROPERTY(EditAnywhere) bool bEnabled = true;
    UPROPERTY(BlueprintAssignable) FVGInteractedSignature OnInteracted;
};
```

O sistema procura o componente no ator atingido; o comportamento fica **no dono**, que se inscreve em `OnInteracted`.

**Onde funciona:** designers adicionam interação a **qualquer** coisa com um clique, inclusive atores da engine que não têm código próprio (uma caixa, uma malha estática); a configuração é editável num lugar padronizado; o componente pode ter posição (um botão específico num painel grande).

**Onde custa:** o comportamento "real" (o que acontece ao interagir) mora fora do componente, numa inscrição; o prompt contextual ("Abrir"/"Fechar"/"Trancada") exige que o dono atualize o componente sempre que o estado muda — ou que o componente pergunte ao dono, o que nos leva de volta a uma interface.

### Abordagem D — Orientação a eventos

A interação é publicada como um **evento** num canal global ("a jogadora interagiu com X"), e quem se interessa reage:

```text
InteractionComponent ── "interagiu com ator X" ──► barramento de eventos ──► porta, narrativa, áudio...
```

**Onde funciona:** desacoplamento máximo; vários sistemas podem reagir à mesma interação (a porta abre **e** a narrativa registra **e** a IA ouve).

**Onde quebra como abordagem principal:** o **prompt** e o **"pode interagir?"** são perguntas que precisam de resposta **síncrona** do alvo antes da ação — e eventos não respondem perguntas. Quem decide se a porta está trancada? Se a resposta é "a porta", então a porta precisa de um contrato direto com o sistema de interação — de novo, uma interface.

A orientação a eventos é a forma certa para o **depois** da interação (quem reage ao que aconteceu), não para o **durante**.

### Comparação

| Critério | A — Herança | B — Interface | C — Componente | D — Eventos |
|---|---|---|---|---|
| **Complexidade inicial** | Baixa | Média | Média | Alta |
| **Performance** | Ótima (cast) | Ótima | Boa (busca de componente) | Boa |
| **Funciona com qualquer ator** | ✗ | ✓ | ✓ | ✓ |
| **Prompt contextual** | ✓ (virtual) | ✓ (o alvo responde) | Exige sincronia com o dono | ✗ (sem resposta síncrona) |
| **"Pode interagir?" pelo alvo** | ✓ | ✓ | Parcial | ✗ |
| **Configuração por designers** | Média | Por classe | **Ótima** (padronizada) | — |
| **Interagir com atores sem código** | ✗ | ✗ (exige Blueprint) | **✓** | ✓ |
| **Vários sistemas reagem** | Manual | Manual | Via delegate | **Natural** |
| **Prototipação** | Rápida | Rápida | **Muito rápida** | Lenta |
| **Manutenção a longo prazo** | Ruim (hierarquia) | Boa | Boa | Boa, mas fluxo implícito |

### A decisão da Vigília

Nenhuma das quatro sozinha é a melhor. A decisão do projeto combina **B** como contrato e **D** para o depois, deixando a porta aberta para **C**:

```text
                        ┌──────────────────────────────┐
  UVGInteractionComponent│ detecta, mantém o foco,      │  (na jogadora)
  (o "sistema")          │ pergunta, executa            │
                        └──────────────┬───────────────┘
                                       │ fala SÓ com o contrato
                                       ▼
                              IVGInteractable                (interface)
                       CanInteract · Interact · GetInteractionPrompt
                    ┌──────────────────┼─────────────────────┐
                    ▼                  ▼                     ▼
               AVGDoor          AVGBreakerSwitch         AVGPickup  ... (C++ ou Blueprint)
                    │                  │                     │
                    └─── cada um ANUNCIA o que aconteceu (delegates) ───► narrativa, áudio, IA
```

1. **Contrato por interface (B).** O sistema de interação conhece apenas `IVGInteractable`. O alvo responde às três perguntas.
2. **Depois da interação, eventos (D).** Cada objeto anuncia o que lhe aconteceu (`OnDoorStateChanged`, `OnToggled`, `OnPickedUp`); outros sistemas se inscrevem.
3. **Interface também em componentes (abre espaço para C).** O sistema procura a interface primeiro **no ator** e, se não achar, **em algum componente** do ator. Isso permite, no futuro, um componente genérico que implemente a interface para atores sem código — se e quando ele for necessário (Capítulo 6: depois do terceiro caso concreto).
4. **Destaque visual genérico no sistema**, não em cada objeto: o objeto em foco ganha um contorno sem implementar nada (contrato uniforme — estudo de caso de Control, Capítulo 6).

> 🌉 **Ponte:** a interface é uma **porta** (*port*) no sentido da arquitetura hexagonal — um contrato que o "núcleo" (o sistema de interação) define e que os "adaptadores" (portas, NPCs, pickups) implementam. Aqui, ao contrário do Capítulo 6 (seção 6.6), a analogia **funciona**, porque o contrato é entre sistemas de gameplay, não uma tentativa de esconder a engine.
>
> 🧱 **Onde a ponte cai:** interfaces da Unreal não são interfaces do Java. Elas podem ser implementadas **em Blueprint**, e por isso a chamada precisa passar pelo sistema de reflexão (`Execute_...`), não por um cast para `IVGInteractable*` — que seria nulo para um Blueprint que implementou a interface sem C++. A seção 19.3 explica.

---

## 19.3 Interfaces na Unreal

Uma interface Unreal tem **duas classes** no mesmo header:

- `UVGInteractable` (prefixo `U`, deriva de `UInterface`) — existe para o **sistema de reflexão**; você nunca a usa diretamente, exceto para perguntar "implementa?" (`Implements<UVGInteractable>()`) e como tipo de classe.
- `IVGInteractable` (prefixo `I`) — a interface de verdade, com as funções, que as classes **herdam**.

Funções de interface que devem poder ser implementadas em Blueprint são declaradas como `BlueprintNativeEvent` (ou `BlueprintImplementableEvent`). Para chamá-las, **sempre** use a função estática gerada `Execute_`:

```cpp
if (Target->Implements<UVGInteractable>())
{
    IVGInteractable::Execute_Interact(Target, Interactor); // funciona para C++ E para Blueprint
}
```

Por que não `Cast<IVGInteractable>(Target)->Interact(...)`? Porque um Blueprint que implementou a interface **só no editor** não tem a interface na sua parte C++; o cast retornaria nulo. O `Execute_` passa pelo sistema de reflexão e encontra a implementação onde ela estiver.

Classes C++ que implementam a interface sobrescrevem as versões `_Implementation`:

```cpp
class AVGDoor : public AActor, public IVGInteractable
{
    // ...
    virtual bool CanInteract_Implementation(AActor* Interactor) const override;
    virtual void Interact_Implementation(AActor* Interactor) override;
    virtual FText GetInteractionPrompt_Implementation(AActor* Interactor) const override;
};
```

---

## 19.4 Detecção, foco e prompt

### Detecção: um sweep curto a partir dos olhos

A detecção usa o canal `ECC_VGInteraction` do Capítulo 15, a partir do **ponto de vista** da jogadora — de preferência o ponto de vista **final** da câmera, que inclui os efeitos do Capítulo 18 (o `GetPlayerViewPoint` do controller fornece isso). Em vez de uma linha, um **sweep de esfera** de poucos centímetros: uma linha exige mirar com precisão de pixel num interruptor pequeno, o que é frustrante; uma esfera de 8–10 cm dá **tolerância** — uma pequena "assistência de mira" para a interação, na mesma linha de raciocínio do estudo de caso do Capítulo 14.

### Frequência

Não é preciso detectar todo frame. Vinte vezes por segundo (a cada 0,05 s) é imperceptível para o prompt e custa um terço do trabalho a 60 FPS. O `TickInterval` do componente resolve isso (Capítulo 2).

### Foco e prompt

O foco é **estado** (Capítulo 4): um alvo por vez, com transições anunciadas. O componente anuncia `OnFocusChanged(Ator, Prompt)` quando o alvo muda **ou quando o prompt do mesmo alvo muda** (a porta terminou de abrir: "Abrir" → "Fechar"). A UI — por enquanto um widget mínimo — se inscreve e mostra o texto. **O componente não sabe que existe UI**; ele anuncia.

Um detalhe de design: o foco considera objetos que implementam a interface **mesmo quando eles não podem ser usados agora**. A porta trancada ganha foco e mostra "Trancada — sem energia". Interagir com ela não faz nada (ou toca um som de "trancada"). Isso é o "o prompt diz a verdade" da seção 19.1.

### Destaque visual

O objeto em foco é destacado de forma **genérica**: o componente liga a renderização de *custom depth* nos componentes primitivos do alvo, e um material de pós-processamento (Capítulo 54) desenha o contorno. Nenhum objeto precisa implementar "ser destacado". Até o material de contorno existir, o efeito é invisível — e tudo bem: a arquitetura já está pronta.

---

## Estudo de caso: Amnesia — a forma de interagir é a experiência

> **Pergunta:** a interação é só um meio para chegar a um fim, ou ela pode ser parte da experiência?

**[FATO PÚBLICO]** Nos jogos da Frictional Games, como *Amnesia: The Dark Descent* (2010) e a série anterior *Penumbra*, a interação com portas, gavetas, alavancas e objetos é **baseada em física e em gestos**: o jogador agarra o objeto e o move com o mouse — puxando uma porta para abri-la aos poucos, arrastando uma gaveta, girando uma válvula.

**[INFERÊNCIA]** A consequência de design é que **abrir uma porta deixa de ser um evento binário e vira uma ação contínua e controlável**. O jogador pode abrir uma fresta e espiar, fechar devagar para não fazer barulho, ou fechar de uma vez ao ver algo do outro lado. A interação se torna parte do vocabulário de tensão do jogo: a mesma porta, aberta de dois jeitos, produz duas experiências. Implementações desse tipo combinam, plausivelmente, um sistema de "segurar" objetos físicos (como o *Physics Handle* do Capítulo 15) com restrições físicas (a dobradiça da porta), em vez de animações disparadas.

**[SIMPLIFICAÇÃO DIDÁTICA]** A Vigília usa a interação "apertar para usar", mais simples e mais acessível — mas a **porta** deste capítulo já tem o que é necessário para uma versão intermediária: ela é uma máquina de estado com **progresso contínuo** (`OpenAlpha`), e a direção pode ser invertida no meio. O desafio do capítulo transforma isso em "segurar para abrir devagar, com menos ruído".

**Lição:** **o verbo de interação é uma decisão de design, não um detalhe de implementação.** "Apertar E" e "agarrar e puxar" produzem jogos diferentes. Uma arquitetura que separa o **contrato** (o que se pode fazer com o objeto) do **verbo** (como o jogador o faz) permite experimentar com o segundo sem reescrever o primeiro.

---

## Implementação

### 1. A interface

```cpp
// Source/Vigilia/Interaction/VGInteractable.h
#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "VGInteractable.generated.h"

UINTERFACE(MinimalAPI, BlueprintType)
class UVGInteractable : public UInterface
{
    GENERATED_BODY()
};

/**
 * Contrato de qualquer coisa com que a jogadora pode interagir (ator ou componente).
 * Sempre chame pelas funções Execute_ (funciona para implementações em C++ e em Blueprint).
 */
class VIGILIA_API IVGInteractable
{
    GENERATED_BODY()

public:
    /** Pode ser usado AGORA por este interator? (Um objeto pode ter foco e não poder ser usado.) */
    UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Vigilia|Interaction")
    bool CanInteract(AActor* Interactor) const;

    UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Vigilia|Interaction")
    void Interact(AActor* Interactor);

    /** Texto mostrado ao jogador: deve refletir o estado atual ("Abrir", "Trancada"...). */
    UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Vigilia|Interaction")
    FText GetInteractionPrompt(AActor* Interactor) const;
};
```

### 2. O componente de interação

```cpp
// Source/Vigilia/Interaction/VGInteractionComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGInteractionComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGInteractionFocusChangedSignature,
    AActor*, FocusedActor, FText, Prompt);

/**
 * Sistema de interação da jogadora: detecta o alvo à frente, mantém o foco, anuncia o prompt
 * e executa a interação a pedido. Fala só com IVGInteractable.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGInteractionComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGInteractionComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Interaction")
    void TryInteract();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Interaction")
    AActor* GetFocusedActor() const { return FocusedActor.Get(); }

    /** Disparado quando o alvo muda ou quando o prompt do alvo atual muda. */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Interaction")
    FVGInteractionFocusChangedSignature OnFocusChanged;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Interaction", meta = (ClampMin = "10.0"))
    float InteractionRange = 220.0f;

    /** Raio do sweep: tolerância para não exigir mira de precisão em objetos pequenos. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Interaction", meta = (ClampMin = "0.0"))
    float ProbeRadius = 8.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Interaction", meta = (ClampMin = "0.0"))
    float ScanInterval = 0.05f;

private:
    void Scan();
    AActor* FindCandidate() const;
    void SetFocus(AActor* NewFocus);
    void SetHighlight(AActor* Actor, bool bOn) const;

    /** O objeto que implementa a interface: o próprio ator ou um de seus componentes. */
    static UObject* ResolveInteractable(AActor* Actor);

    TWeakObjectPtr<AActor> FocusedActor;
    FText CurrentPrompt;
};
```

```cpp
// Source/Vigilia/Interaction/VGInteractionComponent.cpp
#include "Interaction/VGInteractionComponent.h"

#include "Components/PrimitiveComponent.h"
#include "Core/VGCollision.h"
#include "GameFramework/Controller.h"
#include "GameFramework/Pawn.h"
#include "Interaction/VGInteractable.h"

UVGInteractionComponent::UVGInteractionComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
}

void UVGInteractionComponent::BeginPlay()
{
    Super::BeginPlay();
    SetComponentTickInterval(ScanInterval); // ~20 Hz basta para foco e prompt
}

void UVGInteractionComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    SetFocus(nullptr); // remove destaque e avisa a UI
    Super::EndPlay(EndPlayReason);
}

void UVGInteractionComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                            FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    Scan();
}

UObject* UVGInteractionComponent::ResolveInteractable(AActor* Actor)
{
    if (!IsValid(Actor))
    {
        return nullptr;
    }
    if (Actor->Implements<UVGInteractable>())
    {
        return Actor;
    }
    return Actor->FindComponentByInterface(UVGInteractable::StaticClass());
}

AActor* UVGInteractionComponent::FindCandidate() const
{
    const APawn* Pawn = Cast<APawn>(GetOwner());
    const AController* Controller = Pawn ? Pawn->GetController() : nullptr;
    if (!Controller)
    {
        return nullptr;
    }

    FVector ViewLocation;
    FRotator ViewRotation;
    Controller->GetPlayerViewPoint(ViewLocation, ViewRotation); // ponto de vista final da câmera

    const FVector End = ViewLocation + ViewRotation.Vector() * InteractionRange;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGInteractionScan), /*bTraceComplex=*/false, GetOwner());

    FHitResult Hit;
    const bool bHit = GetWorld()->SweepSingleByChannel(
        Hit, ViewLocation, End, FQuat::Identity, ECC_VGInteraction,
        FCollisionShape::MakeSphere(ProbeRadius), Params);

    return (bHit && ResolveInteractable(Hit.GetActor())) ? Hit.GetActor() : nullptr;
}

void UVGInteractionComponent::Scan()
{
    AActor* Candidate = FindCandidate();
    // Alvo destruído (um pickup consumido): o ponteiro fraco vira nulo, e "nulo == nulo" esconderia
    // a perda de foco — o prompt antigo ficaria na tela. Se ainda há prompt, o foco precisa ser limpo.
    const bool bFocusLost = !FocusedActor.IsValid() && !CurrentPrompt.IsEmpty();
    if (Candidate != FocusedActor.Get() || bFocusLost)
    {
        SetFocus(Candidate);
        return;
    }

    // Mesmo alvo: o prompt pode ter mudado (a porta terminou de abrir).
    if (UObject* Target = ResolveInteractable(Candidate))
    {
        const FText Prompt = IVGInteractable::Execute_GetInteractionPrompt(Target, GetOwner());
        if (!Prompt.EqualTo(CurrentPrompt))
        {
            CurrentPrompt = Prompt;
            OnFocusChanged.Broadcast(Candidate, CurrentPrompt);
        }
    }
}

void UVGInteractionComponent::SetFocus(AActor* NewFocus)
{
    SetHighlight(FocusedActor.Get(), false);
    FocusedActor = NewFocus;
    SetHighlight(NewFocus, true);

    UObject* Target = ResolveInteractable(NewFocus);
    CurrentPrompt = Target ? IVGInteractable::Execute_GetInteractionPrompt(Target, GetOwner()) : FText::GetEmpty();
    OnFocusChanged.Broadcast(NewFocus, CurrentPrompt);
}

void UVGInteractionComponent::SetHighlight(AActor* Actor, bool bOn) const
{
    if (!IsValid(Actor))
    {
        return;
    }
    TArray<UPrimitiveComponent*> Primitives;
    Actor->GetComponents(Primitives);
    for (UPrimitiveComponent* Primitive : Primitives)
    {
        Primitive->SetRenderCustomDepth(bOn); // contorno desenhado por pós-processamento (Cap. 54)
    }
}

void UVGInteractionComponent::TryInteract()
{
    AActor* Focus = FocusedActor.Get();
    UObject* Target = ResolveInteractable(Focus);
    if (!Target)
    {
        return;
    }

    if (IVGInteractable::Execute_CanInteract(Target, GetOwner()))
    {
        IVGInteractable::Execute_Interact(Target, GetOwner());
    }
    Scan(); // atualiza o prompt imediatamente, sem esperar o próximo ciclo
}
```

### 3. A porta

A promessa do Capítulo 1, agora real: uma máquina de estado com cinco estados, progresso no tempo por Δt, curva de abertura, tick só enquanto se move, eventos de transição e interação contextual.

```cpp
// Source/Vigilia/Interaction/VGDoor.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/VGInteractable.h"
#include "VGDoor.generated.h"

class AVGBreakerSwitch;
class UCurveFloat;
class AVGDoor;

UENUM(BlueprintType)
enum class EVGDoorState : uint8
{
    Closed,
    Opening,
    Open,
    Closing,
    Locked
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGDoorStateChangedSignature,
    AVGDoor*, Door, EVGDoorState, OldState, EVGDoorState, NewState);

/**
 * Porta de dobradiça: máquina de estado com progresso contínuo.
 * Simplificação: a rotação não testa colisão com a jogadora (ver desafio do Cap. 19)
 * e a energia só destranca (desligar não volta a trancar).
 */
UCLASS(Blueprintable)
class VIGILIA_API AVGDoor : public AActor, public IVGInteractable
{
    GENERATED_BODY()

public:
    AVGDoor();

    virtual void Tick(float DeltaSeconds) override;

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Door")
    void Unlock();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Door")
    void Lock();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Door")
    EVGDoorState GetDoorState() const { return State; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Door")
    FVGDoorStateChangedSignature OnDoorStateChanged;

    // IVGInteractable
    virtual bool CanInteract_Implementation(AActor* Interactor) const override;
    virtual void Interact_Implementation(AActor* Interactor) override;
    virtual FText GetInteractionPrompt_Implementation(AActor* Interactor) const override;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<USceneComponent> Root;

    /** Ponto de giro (a dobradiça). Posicione-o na borda da porta no editor. */
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<USceneComponent> Hinge;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UStaticMeshComponent> DoorMesh;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door")
    float OpenAngle = 95.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door", meta = (ClampMin = "0.05"))
    float OpenDuration = 1.1f;

    /** Curva 0→1 do movimento (devagar → rápido → devagar). Sem curva: smoothstep. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Door")
    TObjectPtr<UCurveFloat> OpenCurve;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door")
    bool bStartsLocked = false;

    /** Se definido, a porta fica trancada até este disjuntor ser ligado. */
    UPROPERTY(EditInstanceOnly, Category = "Vigilia|Door")
    TObjectPtr<AVGBreakerSwitch> PowerSource;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door|Prompt")
    FText PromptOpen = NSLOCTEXT("Vigilia", "DoorOpen", "Abrir");

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door|Prompt")
    FText PromptClose = NSLOCTEXT("Vigilia", "DoorClose", "Fechar");

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door|Prompt")
    FText PromptLocked = NSLOCTEXT("Vigilia", "DoorLocked", "Trancada");

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door|Prompt")
    FText PromptNoPower = NSLOCTEXT("Vigilia", "DoorNoPower", "Trancada — sem energia");

private:
    void TransitionTo(EVGDoorState NewState);
    void ApplyAlpha();

    UFUNCTION()
    void HandlePowerToggled(AVGBreakerSwitch* Switch, bool bIsOn);

    EVGDoorState State = EVGDoorState::Closed;
    float OpenAlpha = 0.0f; // 0 = fechada, 1 = aberta
};
```

```cpp
// Source/Vigilia/Interaction/VGDoor.cpp
#include "Interaction/VGDoor.h"

#include "Components/StaticMeshComponent.h"
#include "Core/VGCollision.h"
#include "Curves/CurveFloat.h"
#include "Interaction/VGBreakerSwitch.h"

AVGDoor::AVGDoor()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = false; // só tica enquanto se move

    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    Hinge = CreateDefaultSubobject<USceneComponent>(TEXT("Hinge"));
    Hinge->SetupAttachment(Root);

    DoorMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("DoorMesh"));
    DoorMesh->SetupAttachment(Hinge);
    DoorMesh->SetCollisionResponseToChannel(ECC_VGInteraction, ECR_Block); // detectável pela interação
}

void AVGDoor::BeginPlay()
{
    Super::BeginPlay();

    if (PowerSource)
    {
        PowerSource->OnToggled.AddDynamic(this, &AVGDoor::HandlePowerToggled);
    }
    if (bStartsLocked || (PowerSource && !PowerSource->IsOn()))
    {
        TransitionTo(EVGDoorState::Locked);
    }
}

void AVGDoor::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (PowerSource)
    {
        PowerSource->OnToggled.RemoveDynamic(this, &AVGDoor::HandlePowerToggled);
    }
    Super::EndPlay(EndPlayReason);
}

bool AVGDoor::CanInteract_Implementation(AActor* Interactor) const
{
    return State != EVGDoorState::Locked;
}

void AVGDoor::Interact_Implementation(AActor* Interactor)
{
    switch (State)
    {
    case EVGDoorState::Closed:
    case EVGDoorState::Closing: TransitionTo(EVGDoorState::Opening); break; // pode inverter no meio
    case EVGDoorState::Open:
    case EVGDoorState::Opening: TransitionTo(EVGDoorState::Closing); break;
    case EVGDoorState::Locked:  break;
    }
}

FText AVGDoor::GetInteractionPrompt_Implementation(AActor* Interactor) const
{
    switch (State)
    {
    case EVGDoorState::Locked:  return (PowerSource && !PowerSource->IsOn()) ? PromptNoPower : PromptLocked;
    case EVGDoorState::Open:
    case EVGDoorState::Opening: return PromptClose;
    default:                    return PromptOpen;
    }
}

void AVGDoor::Lock()
{
    if (State == EVGDoorState::Closed)
    {
        TransitionTo(EVGDoorState::Locked); // simplificação: só tranca se estiver fechada
    }
}

void AVGDoor::Unlock()
{
    if (State == EVGDoorState::Locked)
    {
        TransitionTo(EVGDoorState::Closed);
    }
}

void AVGDoor::HandlePowerToggled(AVGBreakerSwitch* Switch, bool bIsOn)
{
    if (bIsOn)
    {
        Unlock();
    }
}

void AVGDoor::TransitionTo(EVGDoorState NewState)
{
    if (NewState == State)
    {
        return;
    }
    const EVGDoorState OldState = State;
    State = NewState;

    const bool bMoving = (State == EVGDoorState::Opening || State == EVGDoorState::Closing);
    SetActorTickEnabled(bMoving);

    OnDoorStateChanged.Broadcast(this, OldState, NewState); // áudio, narrativa e IA reagem
}

void AVGDoor::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    const float Step = DeltaSeconds / OpenDuration; // progresso por tempo, não por frame (Cap. 1/3)
    if (State == EVGDoorState::Opening)
    {
        OpenAlpha = FMath::Min(OpenAlpha + Step, 1.0f);
        if (OpenAlpha >= 1.0f) { TransitionTo(EVGDoorState::Open); }
    }
    else if (State == EVGDoorState::Closing)
    {
        OpenAlpha = FMath::Max(OpenAlpha - Step, 0.0f);
        if (OpenAlpha <= 0.0f) { TransitionTo(EVGDoorState::Closed); }
    }
    ApplyAlpha();
}

void AVGDoor::ApplyAlpha()
{
    const float Shaped = OpenCurve ? OpenCurve->GetFloatValue(OpenAlpha)
                                   : FMath::SmoothStep(0.0f, 1.0f, OpenAlpha);
    Hinge->SetRelativeRotation(FRotator(0.0, OpenAngle * Shaped, 0.0));
}
```

### 4. O disjuntor

```cpp
// Source/Vigilia/Interaction/VGBreakerSwitch.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/VGInteractable.h"
#include "VGBreakerSwitch.generated.h"

class AVGBreakerSwitch;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGBreakerToggledSignature,
    AVGBreakerSwitch*, Switch, bool, bIsOn);

/** Disjuntor/alavanca. Anuncia quando muda; quem depende dele (portas, luzes) se inscreve. */
UCLASS(Blueprintable)
class VIGILIA_API AVGBreakerSwitch : public AActor, public IVGInteractable
{
    GENERATED_BODY()

public:
    AVGBreakerSwitch();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Breaker")
    bool IsOn() const { return bIsOn; }

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Breaker")
    void SetOn(bool bNewOn);

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Breaker")
    FVGBreakerToggledSignature OnToggled;

    virtual bool CanInteract_Implementation(AActor* Interactor) const override;
    virtual void Interact_Implementation(AActor* Interactor) override;
    virtual FText GetInteractionPrompt_Implementation(AActor* Interactor) const override;

protected:
    /** Apresentação (alavanca, faísca, som) — no Blueprint filho. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Breaker")
    void OnSwitchVisualChanged(bool bNewOn);

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UStaticMeshComponent> Mesh;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Breaker")
    bool bStartsOn = false;

    /** Depois de ligado, não pode ser desligado pela jogadora (típico de "restaurar energia"). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Breaker")
    bool bOneWay = true;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Breaker|Prompt")
    FText PromptTurnOn = NSLOCTEXT("Vigilia", "BreakerOn", "Ligar disjuntor");

    UPROPERTY(EditAnywhere, Category = "Vigilia|Breaker|Prompt")
    FText PromptTurnOff = NSLOCTEXT("Vigilia", "BreakerOff", "Desligar disjuntor");

    virtual void PostInitializeComponents() override;
    virtual void BeginPlay() override;

private:
    bool bIsOn = false;
};
```

```cpp
// Source/Vigilia/Interaction/VGBreakerSwitch.cpp
#include "Interaction/VGBreakerSwitch.h"

#include "Components/StaticMeshComponent.h"
#include "Core/VGCollision.h"

AVGBreakerSwitch::AVGBreakerSwitch()
{
    PrimaryActorTick.bCanEverTick = false;
    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    SetRootComponent(Mesh);
    Mesh->SetCollisionResponseToChannel(ECC_VGInteraction, ECR_Block);
}

void AVGBreakerSwitch::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    // Estado inicial antes de QUALQUER BeginPlay do nível: a porta lê IsOn() no próprio BeginPlay.
    // Atribuição direta, sem broadcast: ninguém recebe um "ligou" falso (Cap. 13).
    bIsOn = bStartsOn;
}

void AVGBreakerSwitch::BeginPlay()
{
    Super::BeginPlay();
    OnSwitchVisualChanged(bIsOn); // apresentação inicial no Blueprint filho
}

bool AVGBreakerSwitch::CanInteract_Implementation(AActor* Interactor) const
{
    return !(bOneWay && bIsOn);
}

void AVGBreakerSwitch::Interact_Implementation(AActor* Interactor)
{
    SetOn(!bIsOn);
}

FText AVGBreakerSwitch::GetInteractionPrompt_Implementation(AActor* Interactor) const
{
    return bIsOn ? PromptTurnOff : PromptTurnOn;
}

void AVGBreakerSwitch::SetOn(bool bNewOn)
{
    if (bNewOn == bIsOn)
    {
        return;
    }
    bIsOn = bNewOn;
    OnSwitchVisualChanged(bIsOn);
    OnToggled.Broadcast(this, bIsOn);
}
```

⚠️ **Por que `PostInitializeComponents`, e não `BeginPlay`?** A engine não garante a ordem de `BeginPlay` entre atores. Se a porta rodasse antes de um disjuntor com `bStartsOn`, leria "desligado", trancaria e nunca destrancaria (nenhum `OnToggled` viria). Na carga de um nível, todos os atores passam por `PostInitializeComponents` antes do primeiro `BeginPlay` — o mesmo recurso que a zona segura usa no Capítulo 23.

Repare num detalhe de UX: um disjuntor `bOneWay` já ligado **não pode** ser usado, e por isso `CanInteract` retorna falso — mas ele continua ganhando foco e mostrando "Desligar disjuntor"? Não deveria: um prompt de ação impossível mente para a jogadora. A correção está no exercício (prompt vazio ou "Ligado", e a decisão de o objeto perder o foco).

### 5. Pickups

```cpp
// Source/Vigilia/Interaction/VGPickup.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/VGInteractable.h"
#include "VGPickup.generated.h"

/**
 * Objeto que se pega. O C++ cuida do ciclo (foco, prompt, consumo); o efeito fica no Blueprint
 * filho (ApplyPickup), que devolve falso se não puder ser aplicado (ex.: bateria já cheia).
 */
UCLASS(Abstract, Blueprintable)
class VIGILIA_API AVGPickup : public AActor, public IVGInteractable
{
    GENERATED_BODY()

public:
    AVGPickup();

    virtual bool CanInteract_Implementation(AActor* Interactor) const override;
    virtual void Interact_Implementation(AActor* Interactor) override;
    virtual FText GetInteractionPrompt_Implementation(AActor* Interactor) const override;

protected:
    /** Efeito do pickup sobre quem o pegou. Retorna verdadeiro se foi consumido. */
    UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Pickup")
    bool ApplyPickup(AActor* Interactor);

    /** Apresentação (som, partícula). */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Pickup")
    void OnPickedUp(AActor* Interactor);

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UStaticMeshComponent> Mesh;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Pickup")
    FText PromptText = NSLOCTEXT("Vigilia", "PickupDefault", "Pegar");

private:
    bool bConsumed = false;
};
```

```cpp
// Source/Vigilia/Interaction/VGPickup.cpp
#include "Interaction/VGPickup.h"

#include "Components/StaticMeshComponent.h"
#include "Core/VGCollision.h"

AVGPickup::AVGPickup()
{
    PrimaryActorTick.bCanEverTick = false;
    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    SetRootComponent(Mesh);
    Mesh->SetCollisionResponseToChannel(ECC_VGInteraction, ECR_Block);
}

bool AVGPickup::CanInteract_Implementation(AActor* Interactor) const { return !bConsumed; }
FText AVGPickup::GetInteractionPrompt_Implementation(AActor* Interactor) const { return PromptText; }
bool AVGPickup::ApplyPickup_Implementation(AActor* Interactor) { return true; }

void AVGPickup::Interact_Implementation(AActor* Interactor)
{
    if (bConsumed || !ApplyPickup(Interactor))
    {
        return; // não pôde aplicar: o pickup continua no mundo
    }
    bConsumed = true;
    OnPickedUp(Interactor);
    Destroy();
}
```

O `BP_PickupBateria` (filho de `AVGPickup`) sobrescreve `ApplyPickup`: encontra o `UVGBatteryComponent` no interator, chama `Recharge(40)` e retorna verdadeiro. **Por ora, a bateria fica na própria jogadora** (adicione o componente ao `BP_VGJogadora`); o Capítulo 51 decide se ela pertence à lanterna.

### 6. Ligando à jogadora

No `AVGCharacter`: crie o componente (`Interaction = CreateDefaultSubobject<UVGInteractionComponent>(TEXT("Interaction"))`), uma `IA_Interact` (`E` / botão do controle) no `IMC_Exploracao` e o binding em `Started` chamando `Interaction->TryInteract()`.

Para o prompt, um widget mínimo em Blueprint, `WBP_PromptInteracao` (um texto centralizado abaixo da mira), criado pelo `BP_VGPlayerController` no `BeginPlay` — o widget é da sessão da jogadora. Já a **inscrição** em `OnFocusChanged` do componente de interação depende do **corpo**, e por isso acontece a cada possessão (o evento *On Possess* do controller ou o delegate `OnPossessedPawnChanged`), desfazendo a inscrição no pawn anterior: no `BeginPlay` o pawn pode ainda não existir, e depois de um respawn (Capítulo 22) o corpo é outro (seção 16.2). Texto vazio → widget escondido; texto preenchido → visível. O Capítulo 55 substitui isso pela UI definitiva.

---

## Projeto 3 — Sistema de interação

### Entregáveis

No Pátio e no Galpão:

1. **Guarita:** porta comum (`BP_PortaMadeira`, filho de `AVGDoor`).
2. **Galpão:** portão (`BP_PortaoGalpao`, `OpenAngle` grande ou, no desafio, deslizante), **trancado por um disjuntor** (`PowerSource`) que fica na lateral externa do galpão, numa caixa de força.
3. **Disjuntor** (`BP_Disjuntor`, filho de `AVGBreakerSwitch`) com alavanca animada por Timeline e som no `OnSwitchVisualChanged`.
4. **Baterias** (`BP_PickupBateria`) espalhadas pelo Pátio.
5. **Uma nota** (`BP_PickupNota`, outro filho de `AVGPickup`) que, ao ser pega, mostra uma mensagem na tela — o embrião dos documentos do Capítulo 48.
6. **Um evento conectado:** ligar o disjuntor do galpão dispara o alarme (`AVGAlarm::TriggerAlarm`) — a usina reage ao primeiro setor religado.

### Critérios de conclusão

- [ ] O prompt aparece só quando há algo interativo à frente, e sempre diz a verdade.
- [ ] A porta do galpão mostra "Trancada — sem energia" até o disjuntor ser ligado; depois, abre.
- [ ] Portas podem ser invertidas no meio do movimento.
- [ ] Nenhuma porta tica quando parada (verifique com `stat game` ou com o Gameplay Debugger/`DrawDebug` — ou simplesmente com um log no Tick).
- [ ] Baterias recarregam a bateria da jogadora; com a bateria cheia, o pickup não é consumido.
- [ ] O sistema de interação não conhece nenhuma classe concreta (verifique os includes de `VGInteractionComponent.cpp`).
- [ ] Um ator implementado **só em Blueprint** (sem C++), implementando `IVGInteractable` pelo editor, funciona com o sistema.

---

## Decisões arquiteturais

1. **Contrato por interface (`IVGInteractable`), chamado sempre via `Execute_`.** O sistema não conhece classes concretas.
2. **Interface procurada no ator e, depois, em componentes** — espaço aberto para um componente genérico quando houver necessidade.
3. **O depois da interação é por eventos** (`OnDoorStateChanged`, `OnToggled`, `OnPickedUp`).
4. **Detecção por sweep de esfera a ~20 Hz**, a partir do ponto de vista final; foco é estado; prompt reflete o estado do alvo.
5. **Destaque visual genérico** (custom depth), sem código por objeto.
6. **Portas são máquinas de estado com progresso contínuo**; tick só durante o movimento.
7. **Dependência de energia: o consumidor (porta) conhece a fonte (disjuntor)**, inscrevendo-se no evento — a mesma direção dos postes e do alarme.
8. **Pickups: ciclo em C++, efeito em Blueprint** (`ApplyPickup` como `BlueprintNativeEvent`).
9. **Texto do jogador em `FText` com `NSLOCTEXT`**, configurável por instância.

---

## Armadilhas

- **Chamar funções de interface com cast** em vez de `Execute_` — quebra implementações em Blueprint.
- **Herança como mecanismo de interação** — impede NPCs e outros atores de serem interativos.
- **Prompt que mente** ("Abrir" numa porta trancada; ação impossível anunciada).
- **Trace de linha fina** para objetos pequenos — frustrante.
- **Detecção a partir da cápsula** em vez do ponto de vista.
- **Foco num alvo destruído** sem anúncio: com `TWeakObjectPtr`, "nulo == nulo" parece "nada mudou", e o prompt do pickup consumido fica na tela.
- **Porta que tica para sempre.**
- **Sistema de interação com `if (Cast<AVGDoor>)`.**
- **Objetos que esquecem de bloquear o canal de interação** — "não consigo interagir com isso".
- **Esquecer `RemoveDynamic`** em portas que se inscrevem em disjuntores.

---

## Exercício

**Parte 1 — o sistema (2 h).** Implemente a interface, o componente de interação, a porta, o disjuntor e o pickup. Monte os entregáveis do Projeto 3.

**Parte 2 — Blueprint puro (45 min).** Crie `BP_Gaveta`, um ator **sem classe C++ própria** (filho de `Actor`), que implementa `IVGInteractable` pelo painel *Class Settings → Interfaces*, e abre/fecha com uma Timeline. Verifique que o sistema de interação funciona com ela sem nenhuma mudança no C++. Isso valida o `Execute_`.

**Parte 3 — o prompt honesto (30 min).** Corrija o prompt do disjuntor `bOneWay` já ligado. Decida e justifique no `DEVLOG.md`: o objeto deve **perder o foco** (o sistema ignora alvos que não podem ser usados **e** não têm nada a informar) ou mostrar um estado ("Ligado")? Implemente a decisão — de preferência sem mudar a interface.

**Parte 4 — comparação (45 min).** Escreva, em pseudocódigo, como o NPC do Capítulo 44 (um `ACharacter`) se tornaria interativo em cada uma das quatro abordagens. Conte quantas classes mudam em cada uma.

---

## Desafio — abrir devagar

Inspirado no estudo de caso de Amnesia, adicione à porta um **segundo verbo**: **segurar** a tecla de interação abre a porta **devagar** (3× mais lento) e de forma **silenciosa**; apertar e soltar abre normalmente.

1. Configure `IA_Interact` com triggers que distingam *Tap* e *Hold* (Capítulo 14), ou crie uma segunda ação.
2. A porta ganha um modo de velocidade (normal/cuidadosa) que afeta `OpenDuration` **e** é incluído no evento de mudança de estado — para que o áudio (Capítulo 52) toque um rangido mais baixo e a percepção (Capítulo 36) receba um ruído menor.
3. **Bônus:** faça a rotação da porta usar *sweep* e **parar** se encontrar a jogadora no caminho, em vez de atravessá-la (a simplificação marcada no código).

Pergunta: o "modo cuidadoso" é uma propriedade da **interação** (passada pelo sistema à porta) ou da **porta**? A interface atual tem espaço para isso? Se não tem, como você a estenderia sem quebrar os interativos existentes? *(Pense em um parâmetro de contexto de interação — uma struct — em vez de um novo método.)*

---

## Uso de IA

1. **Para comparar arquiteturas com o seu caso:**
   > "Tenho um sistema de interação em Unreal Engine 5 baseado em interface (IVGInteractable com CanInteract, Interact e GetInteractionPrompt) e eventos depois da interação. Quero adicionar: interações que exigem segurar por um tempo, interações com dois jogadores ao mesmo tempo, e objetos com várias interações (porta: abrir/trancar com chave). Para cada requisito, proponha a menor mudança na arquitetura e avalie se ela quebra os interativos existentes."

2. **Para revisar a porta:**
   > "Revise esta máquina de estado de porta em Unreal C++. Verifique: estados impossíveis, transições não cobertas, tick ligado só durante o movimento, eventos disparados depois da mudança de estado, comportamento ao ser destruída durante o movimento e o que acontece se Unlock e Interact forem chamados no mesmo frame. [código]"

3. **Para design de interação:**
   > "Compare a interação 'apertar para usar' com a interação física por gestos (como nos jogos da Frictional Games) em jogos de terror: acessibilidade, tensão, legibilidade, custo de implementação e riscos de frustração. Separe o que é observável nos jogos do que é inferência."

**Cuidado específico:** a sintaxe de interfaces Unreal (`UINTERFACE`, `Execute_`, `_Implementation`) é uma fonte frequente de código errado gerado por IA — especialmente chamadas diretas sem `Execute_` e declarações inconsistentes de `const`. Compile e teste com um implementador em Blueprint.

---

## Checklist

- [ ] Sei comparar herança, interface, componente e eventos para interação, pelos seis critérios.
- [ ] Sei declarar uma interface Unreal e chamá-la com `Execute_`, e por que o cast não basta.
- [ ] Implementei detecção por sweep a partir do ponto de vista, foco como estado e prompt contextual.
- [ ] Implementei a porta como máquina de estado com progresso por Δt e tick só durante o movimento.
- [ ] Implementei o disjuntor e a dependência de energia da porta por evento.
- [ ] Implementei pickups com ciclo em C++ e efeito em Blueprint.
- [ ] Um interativo feito só em Blueprint funciona com o sistema.
- [ ] Concluí o Projeto 3 segundo os critérios.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Interfaces** (incluindo a chamada de funções de interface implementadas em Blueprint).
- **Lyra Starter Game** (projeto de exemplo da Epic) — contém um sistema de interação baseado em interfaces e em *gameplay abilities*, útil como referência de como um projeto maior organiza o mesmo problema. Leia depois de implementar o seu.

---

➡️ **Próximo:** [Capítulo 20 — Weapons](cap-20-weapons.md)

# Capítulo 23 — Gameplay State

## Objetivo

Ao final deste capítulo você deve conseguir:

- mapear **onde mora cada estado** do projeto até aqui e reconhecer os problemas que começam a surgir quando muitos sistemas precisam consultar o estado de outros;
- usar **Gameplay Tags** — nomes hierárquicos registrados no projeto — para status, identidade, requisitos e categorias, e saber quando preferi-las a enums, classes e booleanos;
- implementar um **contêiner de tags de status com contagem de referências**, para que várias fontes possam conceder o mesmo status sem se atropelar;
- expor tags de um ator pela interface padrão (`IGameplayTagAssetInterface`), para que qualquer sistema consulte "o que este ator é/está" sem conhecer sua classe;
- aplicar tags a problemas reais da Vigília: correndo/agachada, zona segura, requisitos de portas e estados de setor;
- reconhecer a **explosão de tags** e estabelecer governança.

---

## Contexto

A Parte III já espalhou estado por muitos donos: a bateria, a vida, a arma, a porta, o disjuntor, o alarme, a pilha de modos do controller, o subsistema de dilatação. Cada um respeita a regra do dono único do Capítulo 4 — e isso é bom.

Mas uma nova classe de perguntas começa a aparecer, e ela não cabe em nenhum dono específico:

- A Presença (Parte V) vai precisar saber: **a jogadora está numa zona iluminada? Está agachada? Está escondida? Está correndo?**
- A porta da subestação vai precisar saber: **quem está tentando abri-la tem a chave?**
- A música (Capítulo 52) vai querer saber: **a jogadora está em perigo? Está lendo um documento?**
- O nível de ameaça (Capítulo 36) vai querer saber: **este ator que fez barulho é a jogadora, um vigia ou uma caixa?**

A resposta ingênua é cada sistema fazer `Cast<AVGCharacter>` e ler um booleano: `Player->bIsInSafeZone`, `Player->bIsHidden`, `Player->IsSprinting()`. Isso funciona por um tempo — e cria exatamente o acoplamento que o Capítulo 6 pediu para evitar: todo sistema passa a conhecer a classe da jogadora, cada novo status vira uma propriedade nova numa classe que todos incluem, e a Presença não consegue usar a mesma lógica para perceber um vigia.

Este capítulo apresenta a ferramenta que a Unreal oferece para isso: **Gameplay Tags**.

---

## 23.1 Onde o estado mora, até agora

Antes da ferramenta, o inventário. Esta tabela é o "mapa de estado" do projeto no fim da Parte III — e a primeira versão da especificação de save (Capítulo 56) e de replicação (Parte IX):

| Estado | Dono | Categoria (Cap. 4) | Save? | Quem consulta |
|---|---|---|:-:|---|
| Carga da bateria | `UVGBatteryComponent` | Gameplay | ✓ | HUD, lanterna |
| Vida | `UVGHealthComponent` | Gameplay | ✓ | HUD, áudio |
| Munição, estado da arma | `AVGWeapon` | Gameplay | ✓ | HUD |
| Estado da porta | `AVGDoor` | Gameplay | ✓ | Interação, IA (navegação), áudio |
| Disjuntor ligado | `AVGBreakerSwitch` | Gameplay/mundo | ✓ | Portas, alarme |
| Alarme tocando | `AVGAlarm` | Mundo (transitório) | ✗ | Postes, ameaça |
| Pilha de modos de input | `AVGPlayerController` | Sessão do jogador | ✗ | UI, áudio |
| Dilatação do tempo | `UVGTimeDilationSubsystem` | Mundo (transitório) | ✗ | — |
| Correndo, agachada | `AVGCharacter` / CMC | Simulação | ✗ | IA, câmera, passos |
| Na zona segura, escondida | **ninguém ainda** | Status derivado | ✗ | IA, música |
| Tem a chave X | **ninguém ainda** | Progresso | ✓ | Portas |

As duas últimas linhas são o problema deste capítulo: **status** que muitos sistemas consultam, que podem ser concedidos por várias fontes, e que não pertencem naturalmente a nenhuma classe.

---

## 23.2 Gameplay Tags

Uma **Gameplay Tag** é um **nome hierárquico**, separado por pontos, registrado no projeto:

```text
Status.Movement.Sprinting
Status.Movement.Crouched
Status.Zone.Safe
Status.Hidden
Faction.Player
Faction.Presence
Faction.Guard
Item.Key.Substation
World.Sector.Powered
```

Propriedades que tornam as tags úteis:

- **Registradas centralmente.** Uma tag só existe se estiver registrada (em *Project Settings → GameplayTags*, em arquivos `.ini`, ou declarada em C++). Isso evita erros de digitação silenciosos: o editor oferece um **seletor de tags**, e não um campo de texto livre.
- **Hierárquicas.** `Status.Zone.Safe` é "filha" de `Status.Zone` e de `Status`. Uma consulta por `Status.Zone` encontra qualquer status de zona.
- **Baratas.** Internamente, são baseadas em `FName` (Capítulo 11): comparação rápida e cópia barata.
- **Agrupáveis.** `FGameplayTagContainer` é um conjunto de tags, com consultas prontas: `HasTag`, `HasTagExact`, `HasAny`, `HasAll`, e consultas compostas (`FGameplayTagQuery`).
- **Editáveis por designers.** Uma propriedade `FGameplayTag` ou `FGameplayTagContainer` aparece no editor como um seletor hierárquico.
- **Serializáveis e replicáveis** de forma compacta — o que as torna boas candidatas a estado que vai para o save e para a rede.

### Hierarquia na prática

```cpp
const FGameplayTagContainer& Tags = ...; // contém: Status.Zone.Safe, Status.Movement.Crouched

Tags.HasTag(TAG_Status_Zone);            // true  — Status.Zone.Safe "é um" Status.Zone
Tags.HasTagExact(TAG_Status_Zone);       // false — a tag exata Status.Zone não está lá
Tags.HasTag(TAG_Status_Zone_Safe);       // true
Tags.HasAny(FGameplayTagContainer(TAG_Status_Hidden)); // false
```

A distinção entre `HasTag` (aceita filhas) e `HasTagExact` é a primeira coisa a fixar — e é a fonte do primeiro bug com tags de quase todo mundo.

### Tags nativas e tags de conteúdo

Há duas formas de registrar tags:

- **Tags nativas (em C++)** — declaradas e definidas no código, com macros. Use para tags que o **código** referencia: assim, o compilador garante que a tag existe e o código usa uma variável, não uma string.
- **Tags de conteúdo (em `.ini` / editor)** — criadas no editor por designers. Use para tags que só o **conteúdo** usa (Blueprints, Data Assets).

```cpp
// Declaração (header)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Status_Zone_Safe);

// Definição (.cpp)
UE_DEFINE_GAMEPLAY_TAG(TAG_Status_Zone_Safe, "Status.Zone.Safe");
```

Regra do projeto: **se o C++ usa a tag, ela é nativa.** Nenhum `FGameplayTag::RequestGameplayTag(TEXT("..."))` espalhado pelo código.

---

## 23.3 Tags, enums, classes ou booleanos?

Gameplay Tags não substituem tudo. A escolha depende da natureza do que se quer representar:

| Representação | Melhor para | Evite quando |
|---|---|---|
| **`bool`** | Um único fato interno de um dono (`bHasTriggered`) | Vários sistemas precisam consultar; há muitos fatos parecidos |
| **`enum`** | Estados **exclusivos** e **fechados** de um dono (`EVGDoorState`) | O conjunto é aberto, definido por designers, ou estados se sobrepõem |
| **Classe / `Cast`** | Comportamento diferente por tipo (polimorfismo) | Só se quer **identificar** uma categoria (acopla à classe e, em Blueprint, carrega assets — Capítulo 12) |
| **Interface** | Uma **capacidade** com operações (`IVGInteractable`) | Só se quer saber "é/está" sem chamar nada |
| **Gameplay Tag** | Status que **se sobrepõem**, identidade/categoria **consultada por muitos**, requisitos configuráveis por designers, conjuntos **abertos** | Estados exclusivos com transições rígidas (use enum); fatos com dados associados (use struct) |

Alguns exemplos da Vigília:

- `EVGDoorState` continua **enum**: os estados são exclusivos, fechados e governados por uma máquina de estado.
- "A jogadora está correndo **e** agachada **e** na zona segura" — status que se sobrepõem → **tags**.
- "Esta porta exige a chave da subestação" — requisito configurado por designer → **tag** (`Item.Key.Substation`) numa propriedade da porta.
- "Este ator que fez barulho é a jogadora?" → **tag** de facção, não `Cast<AVGCharacter>`.
- "A jogadora coletou 3 de 7 documentos" → **não** é tag (é um número com dados associados) → estado narrativo (Capítulo 46).

> 🌉 **Ponte:** Gameplay Tags lembram **labels** no Kubernetes (`app=api`, `tier=backend`): metadados hierárquicos/estruturados consultados por seletores, que permitem a muitos sistemas operar sobre objetos sem conhecer seus tipos. Também lembram *claims* num token: um conjunto de afirmações sobre o portador, verificadas por quem precisa.
>
> 🧱 **Onde a ponte cai:** labels do Kubernetes são strings livres; Gameplay Tags são **registradas** e validadas, o que evita o "label com erro de digitação que ninguém percebe". Por outro lado, tags não carregam valores — `Status.Zone.Safe` não diz **qual** zona nem **quanto** —, o que labels com valor dizem.

---

## 23.4 Status com várias fontes: contagem de referências

O status `Status.Zone.Safe` é concedido por **zonas seguras** — volumes iluminados da usina. A jogadora pode estar dentro de **duas zonas sobrepostas** (a luz de um corredor e a de uma sala adjacente). Ao sair de uma delas, ela continua dentro da outra — e o status não pode ser removido.

Com um conjunto simples de tags, a primeira saída removeria a tag. A solução é **contar**: cada fonte "concede" o status (+1) e "revoga" (−1); a tag existe enquanto a contagem for maior que zero.

```text
  entra na Zona A   → Safe: 1  (tag presente)
  entra na Zona B   → Safe: 2
  sai da Zona A     → Safe: 1  (tag continua)
  sai da Zona B     → Safe: 0  (tag removida → evento "perdeu Safe")
```

É o mesmo padrão dos pedidos de dilatação do Capítulo 6 — **valor efetivo derivado de pedidos de várias fontes** —, numa forma mais simples. E o mesmo princípio de dono único: o **componente de tags** é o dono da contagem; as fontes pedem e revogam, nunca escrevem diretamente.

> O *Gameplay Ability System* (Capítulo 22) tem exatamente esse mecanismo (*loose gameplay tags* com contagem). Como a Vigília não usa o GAS, o projeto implementa a versão mínima.

---

## 23.5 Expondo tags de um ator

A engine define uma interface padrão para "este objeto tem tags": **`IGameplayTagAssetInterface`**, com `GetOwnedGameplayTags` e consultas de conveniência (`HasMatchingGameplayTag`, `HasAllMatchingGameplayTags`, `HasAnyMatchingGameplayTags`). Qualquer sistema pode perguntar a qualquer ator:

```cpp
if (const IGameplayTagAssetInterface* Tagged = Cast<IGameplayTagAssetInterface>(Actor))
{
    if (Tagged->HasMatchingGameplayTag(TAG_Faction_Player)) { /* é a jogadora (ou alguém controlado por ela) */ }
}
```

Aqui o `Cast` para a interface é correto (ao contrário de `IVGInteractable`, Capítulo 19): `IGameplayTagAssetInterface` é uma interface **nativa** de consulta, implementada em C++ pelas classes que a declaram, sem funções `BlueprintNativeEvent`.

---

## Estudo de caso: Control — estado de região como linguagem compartilhada

> **Pergunta:** como um único estado de uma região do mundo pode coordenar muitos sistemas ao mesmo tempo?

**[FATO PÚBLICO]** Em *Control* (Remedy, 2019), o prédio da Oldest House está tomado pelo *Hiss*, uma força hostil. Ao longo do jogo, a protagonista encontra e **purifica *Control Points***, que passam a funcionar como pontos de retorno (*checkpoints*) e de viagem rápida. Áreas tomadas e áreas recuperadas têm atmosferas perceptivelmente diferentes.

**[INFERÊNCIA]** Um desenho compatível com esse comportamento é um **estado por região** — algo como *tomada* → *purificada* — consumido por vários sistemas: a população de inimigos daquela região, a iluminação e o áudio ambiente, a disponibilidade de viagem rápida, eventuais diálogos e documentos novos. O ponto central é que **nenhum desses sistemas precisa saber dos outros**: todos consultam (ou reagem a) o mesmo estado de região. Nenhuma afirmação é feita sobre a implementação real.

**[SIMPLIFICAÇÃO DIDÁTICA]** A Vigília tem exatamente essa estrutura nos **setores da usina**: cada setor começa *escuro* e passa a *energizado* quando a jogadora religa o disjuntor principal dele. Representado como uma tag de mundo por setor (`World.Sector.Powered`, associada ao setor), esse estado pode ser consumido por:

```text
 World.Sector.Powered (setor B)
     ├── luzes do setor acendem (Cap. 51)
     ├── zonas seguras do setor ficam ativas (este capítulo)
     ├── a Presença evita o setor (Parte V)
     ├── a música muda para um tema de alívio (Cap. 52)
     ├── portas elétricas do setor destrancam (Cap. 19, PowerSource)
     └── um fato narrativo é registrado (Cap. 46)
```

**Lição:** **um estado bem escolhido, exposto de forma uniforme, coordena sistemas sem acoplá-los.** É a versão, para o estado, do "contrato uniforme" do Capítulo 6: em vez de o disjuntor conhecer luzes, música, IA e narrativa, cada sistema conhece o **estado do setor**.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Gameplay Tags | Labels do Kubernetes; claims de token | Registradas e validadas; sem valores |
| Hierarquia de tags | Namespaces / prefixos com seletores | `HasTag` aceita filhas — fonte de bugs se esquecido |
| Tags nativas vs. de conteúdo | Constantes no código vs. configuração | Ambas vivem no mesmo registro |
| Contagem de referências de status | Reference counting / semáforo de leitores | A transição para zero é um **evento de gameplay** |
| `IGameplayTagAssetInterface` | Interface de metadados consultável | Permite consulta sem conhecer a classe |

---

## Implementação

### 1. Dependência

No `Vigilia.Build.cs`, adicione `"GameplayTags"` às dependências públicas.

### 2. As tags nativas do projeto

```cpp
// Source/Vigilia/Core/VGGameplayTags.h
#pragma once

#include "NativeGameplayTags.h"

// Status (concedidos e revogados em runtime)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Status_Movement_Sprinting);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Status_Movement_Crouched);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Status_Zone_Safe);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Status_Hidden);

// Identidade
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Faction_Player);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Faction_Presence);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Faction_Guard);

// Mundo
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_World_Sector_Powered);
```

```cpp
// Source/Vigilia/Core/VGGameplayTags.cpp
#include "Core/VGGameplayTags.h"

UE_DEFINE_GAMEPLAY_TAG(TAG_Status_Movement_Sprinting, "Status.Movement.Sprinting");
UE_DEFINE_GAMEPLAY_TAG(TAG_Status_Movement_Crouched,  "Status.Movement.Crouched");
UE_DEFINE_GAMEPLAY_TAG(TAG_Status_Zone_Safe,          "Status.Zone.Safe");
UE_DEFINE_GAMEPLAY_TAG(TAG_Status_Hidden,             "Status.Hidden");

UE_DEFINE_GAMEPLAY_TAG(TAG_Faction_Player,   "Faction.Player");
UE_DEFINE_GAMEPLAY_TAG(TAG_Faction_Presence, "Faction.Presence");
UE_DEFINE_GAMEPLAY_TAG(TAG_Faction_Guard,    "Faction.Guard");

UE_DEFINE_GAMEPLAY_TAG(TAG_World_Sector_Powered, "World.Sector.Powered");
```

Tags de itens (`Item.Key.*`) são **de conteúdo**: criadas pelo designer no editor, porque o código não referencia nenhuma chave específica — ele só compara a tag exigida pela porta com as tags da jogadora.

### 3. O componente de tags de status

```cpp
// Source/Vigilia/Core/VGStatusTagsComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "GameplayTagContainer.h"
#include "VGStatusTagsComponent.generated.h"

class UVGStatusTagsComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGStatusTagChangedSignature,
    UVGStatusTagsComponent*, Component, FGameplayTag, Tag, bool, bPresent);

/**
 * Dono das tags de um ator. Tags fixas (identidade) + tags de status com contagem:
 * várias fontes podem conceder o mesmo status; ele existe enquanto a contagem > 0.
 * Anuncia apenas transições (ausente ↔ presente), não cada concessão.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGStatusTagsComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGStatusTagsComponent();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Tags")
    void GrantStatus(FGameplayTag Tag);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Tags")
    void RevokeStatus(FGameplayTag Tag);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Tags")
    bool HasTag(FGameplayTag Tag) const { return GetAllTags().HasTag(Tag); }

    /** Identidade + status atuais. */
    FGameplayTagContainer GetAllTags() const;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Tags")
    FVGStatusTagChangedSignature OnStatusTagChanged;

protected:
    /** Tags fixas deste ator (ex.: Faction.Player). Configuradas no Blueprint. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Tags")
    FGameplayTagContainer IdentityTags;

private:
    TMap<FGameplayTag, int32> StatusCounts;
    FGameplayTagContainer StatusTags; // espelho das tags com contagem > 0, para consulta rápida
};
```

```cpp
// Source/Vigilia/Core/VGStatusTagsComponent.cpp
#include "Core/VGStatusTagsComponent.h"

#include "Core/VGLog.h"

UVGStatusTagsComponent::UVGStatusTagsComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UVGStatusTagsComponent::GrantStatus(FGameplayTag Tag)
{
    if (!Tag.IsValid())
    {
        return;
    }
    int32& Count = StatusCounts.FindOrAdd(Tag);
    if (++Count == 1)
    {
        StatusTags.AddTag(Tag);                          // estado...
        OnStatusTagChanged.Broadcast(this, Tag, true);   // ...depois anúncio (Cap. 4)
    }
}

void UVGStatusTagsComponent::RevokeStatus(FGameplayTag Tag)
{
    int32* Count = StatusCounts.Find(Tag);
    if (!ensureMsgf(Count && *Count > 0, TEXT("%s: RevokeStatus(%s) sem Grant correspondente."),
                    *GetNameSafe(GetOwner()), *Tag.ToString()))
    {
        return;
    }
    if (--(*Count) == 0)
    {
        StatusCounts.Remove(Tag);
        StatusTags.RemoveTag(Tag);
        OnStatusTagChanged.Broadcast(this, Tag, false);
    }
}

FGameplayTagContainer UVGStatusTagsComponent::GetAllTags() const
{
    FGameplayTagContainer All = IdentityTags;
    All.AppendTags(StatusTags);
    return All;
}
```

### Explicação das decisões

- **Identidade e status separados.** Identidade (`Faction.Player`) é configuração fixa do Blueprint; status é concedido e revogado em runtime. Misturá-los permitiria que um sistema "revogasse" a facção de alguém por engano.
- **Contagem por tag, anúncio só nas transições** (0 → 1 e 1 → 0): a música e a IA não precisam saber que a jogadora entrou numa segunda zona segura; precisam saber quando ela **deixou de estar** em qualquer uma.
- **`RevokeStatus` sem `Grant` correspondente é um `ensure`**: um bug de lógica recuperável, com mensagem clara — o mesmo padrão do `PopInputMode` fora de ordem (Capítulo 16). Simetria entre conceder e revogar é responsabilidade de quem concede.
- **`StatusTags` como espelho** da contagem, para que consultas (muito mais frequentes que mudanças) não reconstruam o contêiner. `GetAllTags()` ainda copia; se o profiler apontar, uma versão que preenche um contêiner de saída resolve.

### 4. A jogadora expõe suas tags

```cpp
// VGCharacter.h (adições)
#include "GameplayTagAssetInterface.h"

UCLASS()
class VIGILIA_API AVGCharacter : public ACharacter, public IGameplayTagAssetInterface
{
    // ...
public:
    virtual void GetOwnedGameplayTags(FGameplayTagContainer& TagContainer) const override;

protected:
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGStatusTagsComponent> StatusTags;
};
```

```cpp
// VGCharacter.cpp (adições)
#include "Core/VGGameplayTags.h"
#include "Core/VGStatusTagsComponent.h"

// no construtor:
//   StatusTags = CreateDefaultSubobject<UVGStatusTagsComponent>(TEXT("StatusTags"));

void AVGCharacter::GetOwnedGameplayTags(FGameplayTagContainer& TagContainer) const
{
    TagContainer = StatusTags->GetAllTags();
}
```

E as transições de movimento passam a conceder e revogar status. Em `UpdateSprint`, onde `bIsSprinting` muda:

```cpp
if (bShouldSprint != bIsSprinting)
{
    bIsSprinting = bShouldSprint;
    GetCharacterMovement()->MaxWalkSpeed = bIsSprinting ? SprintSpeed : WalkSpeed;
    if (bIsSprinting) { StatusTags->GrantStatus(TAG_Status_Movement_Sprinting); }
    else              { StatusTags->RevokeStatus(TAG_Status_Movement_Sprinting); }
}
```

E em `OnStartCrouch`/`OnEndCrouch`, `Grant`/`Revoke` de `TAG_Status_Movement_Crouched`. No `BP_VGJogadora`, configure `IdentityTags = Faction.Player`.

Repare que `bIsSprinting` **continua existindo**: ele é estado interno do personagem (com a regra de corrida). A tag é a **projeção pública** desse estado para outros sistemas. O dono único continua sendo o personagem.

🔁 O primeiro leitor a migrar é o modificador de câmera do Capítulo 18. Ele perguntava "está correndo?" com `Cast<AVGCharacter>` + `IsSprinting()`, ou seja, conhecendo a classe da jogadora. Agora pergunta pela tag:

```cpp
// UVGFirstPersonCameraModifier::ModifyCamera — FOV dinâmico (Cap. 18), agora por tag
const IGameplayTagAssetInterface* Tagged = Cast<IGameplayTagAssetInterface>(CameraOwner->GetViewTarget());
const bool bSprinting = Tagged && Tagged->HasMatchingGameplayTag(TAG_Status_Movement_Sprinting);
const float TargetFOVBonus = bSprinting ? SprintFOVBonus : 0.0f;
```

O `Cast` para o personagem continua no modificador, mas só para o que é **corpo**: o movimento e os passos. A pergunta sobre **estado** passa pela tag. Com isso, qualquer view target que exponha a tag (um veículo, um personagem de cinemática) ganha o FOV de corrida sem que o modificador conheça a classe dele.

### 5. Zonas seguras

```cpp
// Source/Vigilia/World/VGSafeZone.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGSafeZone.generated.h"

class UBoxComponent;

/**
 * Volume iluminado onde a Presença não entra. Concede Status.Zone.Safe a quem está dentro.
 * Pode estar inativo (setor sem energia) e ser ativado depois.
 */
UCLASS()
class VIGILIA_API AVGSafeZone : public AActor
{
    GENERATED_BODY()

public:
    AVGSafeZone();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|SafeZone")
    void SetZoneActive(bool bActive);

    UFUNCTION(BlueprintPure, Category = "Vigilia|SafeZone")
    bool IsZoneActive() const { return bZoneActive; }

protected:
    virtual void PostInitializeComponents() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UBoxComponent> Volume;

    UPROPERTY(EditAnywhere, Category = "Vigilia|SafeZone")
    bool bStartsActive = true;

private:
    UFUNCTION()
    void HandleBeginOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                            UPrimitiveComponent* OtherComp, int32 OtherBodyIndex,
                            bool bFromSweep, const FHitResult& SweepResult);

    UFUNCTION()
    void HandleEndOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                          UPrimitiveComponent* OtherComp, int32 OtherBodyIndex);

    void Grant(AActor* Actor);
    void Revoke(AActor* Actor);

    bool bZoneActive = false;

    /** Quem recebeu o status desta zona — para revogar exatamente o que foi concedido. */
    TSet<TWeakObjectPtr<AActor>> Granted;
};
```

```cpp
// Source/Vigilia/World/VGSafeZone.cpp
#include "World/VGSafeZone.h"

#include "Components/BoxComponent.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGStatusTagsComponent.h"

AVGSafeZone::AVGSafeZone()
{
    PrimaryActorTick.bCanEverTick = false;
    Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
    Volume->SetBoxExtent(FVector(300.0, 300.0, 200.0));
    Volume->SetCollisionProfileName(TEXT("Trigger"));
    SetRootComponent(Volume);
}

void AVGSafeZone::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    Volume->OnComponentBeginOverlap.AddDynamic(this, &AVGSafeZone::HandleBeginOverlap);
    Volume->OnComponentEndOverlap.AddDynamic(this, &AVGSafeZone::HandleEndOverlap);
    bZoneActive = bStartsActive;
}

void AVGSafeZone::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    SetZoneActive(false); // revoga tudo que concedeu: nenhum status "órfão" sobrevive à zona
    Super::EndPlay(EndPlayReason);
}

void AVGSafeZone::SetZoneActive(bool bActive)
{
    if (bActive == bZoneActive)
    {
        return;
    }
    bZoneActive = bActive;

    if (bZoneActive)
    {
        TArray<AActor*> Inside;
        Volume->GetOverlappingActors(Inside); // quem já estava dentro quando a luz voltou
        for (AActor* Actor : Inside) { Grant(Actor); }
    }
    else
    {
        for (const TWeakObjectPtr<AActor>& Actor : Granted.Array()) { Revoke(Actor.Get()); }
        Granted.Empty();
    }
}

void AVGSafeZone::HandleBeginOverlap(UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*,
                                     int32, bool, const FHitResult&)
{
    if (bZoneActive) { Grant(OtherActor); }
}

void AVGSafeZone::HandleEndOverlap(UPrimitiveComponent*, AActor* OtherActor, UPrimitiveComponent*, int32)
{
    Revoke(OtherActor);
}

void AVGSafeZone::Grant(AActor* Actor)
{
    if (!IsValid(Actor) || Granted.Contains(Actor))
    {
        return;
    }
    if (UVGStatusTagsComponent* Tags = Actor->FindComponentByClass<UVGStatusTagsComponent>())
    {
        Tags->GrantStatus(TAG_Status_Zone_Safe);
        Granted.Add(Actor);
    }
}

void AVGSafeZone::Revoke(AActor* Actor)
{
    if (!IsValid(Actor) || !Granted.Contains(Actor))
    {
        return;
    }
    if (UVGStatusTagsComponent* Tags = Actor->FindComponentByClass<UVGStatusTagsComponent>())
    {
        Tags->RevokeStatus(TAG_Status_Zone_Safe);
    }
    Granted.Remove(Actor);
}
```

### Explicação das decisões

- **A zona lembra o que concedeu** (`Granted`) e revoga **exatamente** isso: ao sair, ao ser desativada, ao ser destruída. Isso mantém a simetria exigida pelo componente de tags — e torna impossível o "status órfão" de uma zona que sumiu.
- **Ativar uma zona com a jogadora já dentro concede o status** (`GetOverlappingActors`). Quando a energia de um setor volta e a luz acende sobre ela, ela fica segura imediatamente — sem precisar sair e entrar.
- **A zona não sabe quem é a Presença nem quem é a jogadora.** Ela concede status a qualquer ator com um componente de tags. É a Presença que, na Parte V, vai **evitar** atores e áreas com `Status.Zone.Safe` — e um vigia dentro da luz também ganha o status, o que pode ou não ser desejado (uma decisão para o Capítulo 41).
- **`TWeakObjectPtr` no conjunto**: a zona não mantém atores vivos nem quebra se um deles for destruído dentro dela.

### 6. Requisitos por tag: portas com chave

A porta do Capítulo 19 ganha um requisito opcional:

```cpp
// VGDoor.h (adições)
    /** Se definida, só quem tem esta tag (ex.: Item.Key.Substation) pode abrir. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Door")
    FGameplayTag RequiredTag;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Door|Prompt")
    FText PromptNeedsKey = NSLOCTEXT("Vigilia", "DoorNeedsKey", "Trancada — precisa de uma chave");
```

```cpp
// VGDoor.cpp
#include "GameplayTagAssetInterface.h"

static bool HasRequiredTag(const AActor* Interactor, const FGameplayTag& Required)
{
    if (!Required.IsValid())
    {
        return true;
    }
    const IGameplayTagAssetInterface* Tagged = Cast<IGameplayTagAssetInterface>(Interactor);
    return Tagged && Tagged->HasMatchingGameplayTag(Required);
}

bool AVGDoor::CanInteract_Implementation(AActor* Interactor) const
{
    return State != EVGDoorState::Locked && HasRequiredTag(Interactor, RequiredTag);
}
// GetInteractionPrompt_Implementation: se faltar a tag, devolve PromptNeedsKey.
```

E a chave é um `BP_PickupChave` (filho de `AVGPickup`) cujo `ApplyPickup` concede uma tag configurada (`Item.Key.Substation`) ao componente de tags do interator.

> **Simplificação com prazo:** chaves como **status permanente** (concedido e nunca revogado) funcionam, mas misturam "o que eu sou/estou" com "o que eu tenho". Quando a Vigília tiver itens que se gastam, se combinam ou precisam aparecer numa tela, eles vão para um **inventário** próprio, e as tags de chave passam a ser derivadas dele. Isso é discutido junto com quests e objetivos (Capítulo 45).

---

## 23.6 Governança: evitando a explosão de tags

Tags são baratas de criar — e por isso se multiplicam. Projetos sem disciplina chegam a centenas de tags redundantes, com nomes inconsistentes (`Status.Safe`, `State.InSafeZone`, `Zone.Safe`), e as tags deixam de ser uma linguagem compartilhada para virar ruído. Regras do projeto:

1. **Raízes fixas e documentadas:** `Status.*`, `Faction.*`, `Item.*`, `World.*`, `Narrative.*` (Capítulo 46), `Damage.*` (se necessário). Nenhuma raiz nova sem registro no `docs/design/tags.md`.
2. **Tags usadas pelo código são nativas** (`VGGameplayTags.h`); tags de conteúdo vivem no `.ini` do projeto, com descrição.
3. **Use a restrição de categorias** nas propriedades: `UPROPERTY(meta = (Categories = "Item.Key"))` faz o seletor do editor mostrar apenas tags sob `Item.Key` — o designer não consegue escolher uma tag de status como requisito de chave.
4. **Revisão periódica:** procure tags não usadas (o editor tem ferramentas para listar referências de tags).
5. **Nunca use tags para dados com valor** (contagens, quantidades, progresso).

---

## Decisões arquiteturais

1. **Gameplay Tags para status sobrepostos, identidade consultada por muitos, requisitos configuráveis e conjuntos abertos.** Enums para estados exclusivos de um dono; interfaces para capacidades com operações.
2. **Tags usadas no C++ são nativas.** Nenhuma tag por string no código.
3. **`UVGStatusTagsComponent`**: identidade fixa + status com contagem; anúncio só nas transições.
4. **Quem concede, revoga**, e lembra o que concedeu (zonas seguras).
5. **Atores expõem tags por `IGameplayTagAssetInterface`**; ninguém faz `Cast` para a classe da jogadora para saber o que ela está fazendo.
6. **Tags como projeção pública** de estado interno (correndo, agachada); o dono continua sendo o sistema original.
7. **Governança de tags documentada** em `docs/design/tags.md`, com categorias restritas nos seletores.
8. **Chaves como tags é uma simplificação** até existir inventário.

---

## Armadilhas

- **Confundir `HasTag` (aceita filhas) com `HasTagExact`.**
- **Tags por string no código** (`RequestGameplayTag(TEXT("..."))`), com erro de digitação descoberto em runtime.
- **Status sem contagem** com várias fontes — o primeiro a sair remove para todos.
- **Revogar o que não concedeu** (ou não revogar o que concedeu).
- **Tags para tudo**, inclusive estados exclusivos com transições rígidas.
- **Tags com valor implícito** (`Ammo.Five`, `Progress.Three`).
- **Explosão de tags** sem raízes nem revisão.
- **`Cast<AVGCharacter>` em sistemas que só querem saber "é a jogadora?"**

---

## Exercício

**Parte 1 — tags e componente (1,5 h).** Adicione `GameplayTags` ao módulo, crie as tags nativas, o `UVGStatusTagsComponent` e a exposição via `IGameplayTagAssetInterface` na jogadora. Faça correr e agachar concederem/revogarem status. Crie um cheat `VGDumpTags` que liste as tags da jogadora.

**Parte 2 — zonas seguras (1,5 h).** Implemente o `AVGSafeZone`. No Pátio, coloque duas zonas sobrepostas sob os postes estáveis. Verifique com o cheat: entrar em uma, entrar na segunda, sair da primeira — a tag continua; sair da segunda — a tag some, e o evento `OnStatusTagChanged` dispara uma única vez em cada transição.

**Parte 3 — energia (45 min).** Faça a zona segura dentro do Galpão começar **inativa** e ser ativada pelo disjuntor do Galpão (Projeto 3). Fique dentro do galpão, ligue o disjuntor: a tag aparece sem você sair e entrar.

**Parte 4 — chave (45 min).** Crie a tag de conteúdo `Item.Key.Substation`, o `BP_PickupChave` e uma porta na subestação que exige a chave. Restrinja o seletor de `RequiredTag` com `meta = (Categories = "Item.Key")`.

**Parte 5 — governança (30 min).** Escreva o `docs/design/tags.md` com as raízes, a convenção de nomes e a lista de tags atuais com uma frase de descrição cada.

---

## Desafio — o estado do setor

Implemente a versão mínima do estudo de caso de Control: **setores da usina com estado**.

1. Crie um `AVGSector` (um ator por setor, com uma lista de zonas seguras e um disjuntor principal referenciados no editor) que, ao receber `OnToggled` do disjuntor, passa ao estado energizado e **concede a si mesmo** a tag `World.Sector.Powered` (o setor também implementa `IGameplayTagAssetInterface`).
2. Ao energizar, ativa as zonas seguras do setor e anuncia `OnSectorPowered`.
3. Os postes do Pátio que pertencem ao setor (referência editável) passam a escutar o setor, e não mais o disjuntor diretamente.

Pergunta para o `DEVLOG.md`: o que mudou na direção das dependências? Quantas coisas precisam conhecer o disjuntor agora, comparado a antes? E onde deveria morar a **lista de todos os setores** e a pergunta "quantos setores estão energizados?" — num setor, num subsistema de mundo, no GameMode? *(Releia a árvore de decisão do Capítulo 10, seção 10.5. O Capítulo 46 responde de forma definitiva.)*

---

## Uso de IA

1. **Para desenhar a taxonomia de tags:**
   > "Estou desenhando a taxonomia de Gameplay Tags de um jogo de terror em primeira pessoa (jogadora, uma criatura invencível, vigias humanos, setores com energia, zonas seguras, documentos, chaves). Proponha raízes e uma hierarquia de tags, indique quais seriam nativas (usadas pelo C++) e quais de conteúdo, e aponte coisas que NÃO deveriam ser tags (e o que usar no lugar)."

2. **Para revisar o uso de tags:**
   > "Revise este código que usa Gameplay Tags na Unreal Engine 5. Procure: uso de HasTag quando deveria ser HasTagExact (e vice-versa), tags obtidas por string, status sem contagem com múltiplas fontes, concessões sem revogação simétrica, e tags usadas para representar valores. [código]"

3. **Para escolher a representação:**
   > "Para cada item a seguir, diga se deveria ser bool, enum, classe, interface, Gameplay Tag ou estado narrativo com dados, e justifique: porta aberta/fechada/trancada; jogadora agachada; jogadora na luz; criatura é inimiga; quantos documentos foram lidos; jogadora tem a chave da subestação; tipo de dano; setor energizado; o vigia está alerta."

---

## Checklist

- [ ] Tenho o mapa de estado do projeto e sei quem é dono de cada estado.
- [ ] Sei o que são Gameplay Tags, como a hierarquia funciona e a diferença entre `HasTag` e `HasTagExact`.
- [ ] Sei registrar tags nativas e de conteúdo, e quando usar cada uma.
- [ ] Sei escolher entre bool, enum, classe, interface e tag.
- [ ] Implementei o componente de status com contagem e anúncio só nas transições.
- [ ] Atores expõem tags pela `IGameplayTagAssetInterface`.
- [ ] Implementei zonas seguras que concedem e revogam simetricamente, inclusive ao serem ativadas e destruídas.
- [ ] Implementei requisitos de porta por tag e um pickup de chave.
- [ ] Escrevi a governança de tags do projeto.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Gameplay Tags** (incluindo tags nativas, consultas e `IGameplayTagAssetInterface`).
- **Lyra Starter Game** — a Lyra usa Gameplay Tags extensivamente (status, input, mensagens, habilidades); é uma boa referência de taxonomia em um projeto grande.

---

➡️ **Próximo:** [Capítulo 24 — Events e comunicação](cap-24-events-e-comunicacao.md)

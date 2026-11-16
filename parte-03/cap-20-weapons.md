# Capítulo 20 — Weapons

*Projeto 2: FPS básico — "Galpão de Testes"*

## Objetivo

Ao final deste capítulo você deve conseguir:

- decompor uma arma em quatro camadas — **dados, estado, comportamento e apresentação** — e saber onde cada uma mora;
- modelar a arma como **máquina de estado** (guardada, equipando, pronta, recarregando) e o disparo como um **pipeline**;
- implementar **cadência de tiro** (*rate of fire*) que não depende do frame rate, com **buffer de input** para armas semiautomáticas;
- implementar **munição, recarga e troca** com regras claras de interrupção;
- decidir entre arma como **ator**, **componente** ou **objeto**, e montar o elo personagem → componente de armas → arma;
- começar o **Projeto 2** no Galpão de Testes com uma pistola e o sinalizador da Vigília.

---

## Contexto

A Vigília quase não tem combate. Então por que o livro dedica uma parte inteira (a IV) a FPS, e começa armas aqui?

Por três motivos. Primeiro, o pedido original: entender como armas, tiro, mira, recoil e combate são construídos, com Call of Duty e Battlefield como referências conceituais. Segundo, a Vigília **tem** um combate curto e intenso — o sinalizador com poucos cartuchos —, e ele precisa ser bom exatamente porque é raro. Terceiro, armas são o melhor laboratório possível para tudo que o livro construiu até aqui: dados vs. estado (Capítulo 4), tempo (Capítulo 3), feedback (Capítulo 5), regra de camadas (Capítulo 13) e, mais adiante, rede (Parte IX). Uma arma de FPS é um sistema pequeno com todos os problemas de um sistema grande.

---

## 20.1 Anatomia de uma arma

Olhe para uma arma de qualquer FPS e separe o que você vê em camadas:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ DADOS (o que a arma É)            dano, cadência, pente, recarga, alcance,  │
│ Data Asset, imutável em runtime   dispersão, modo de disparo, sons, efeitos │
├─────────────────────────────────────────────────────────────────────────────┤
│ ESTADO (o que a arma ESTÁ)        munição no pente, munição reserva, estado │
│ Ator da arma, mutável             (pronta/recarregando...), gatilho         │
│                                   pressionado, tempo até o próximo tiro     │
├─────────────────────────────────────────────────────────────────────────────┤
│ COMPORTAMENTO (o que a arma FAZ)  posso atirar? atirar = consumir munição + │
│ C++                               executar o disparo + anunciar; recarregar │
├─────────────────────────────────────────────────────────────────────────────┤
│ APRESENTAÇÃO (como a arma PARECE) som, flash no cano, cartucho, recoil      │
│ Blueprint + assets                visual, tremor de câmera, animação        │
└─────────────────────────────────────────────────────────────────────────────┘
```

Essa separação não é só organização: cada camada responde a forças diferentes (Capítulo 13).

- **Dados** mudam o tempo todo durante o balanceamento, por designers, e são compartilhados: todas as pistolas do mesmo tipo usam o mesmo asset.
- **Estado** é por instância e é o que vai para o save e para a rede.
- **Comportamento** tem regras e invariantes ("munição nunca negativa", "não se atira recarregando").
- **Apresentação** é onde mora o *game feel*, e é ajustada por artistas e designers.

> 🌉 **Ponte:** é a separação entre **definição de produto** (catálogo), **instância** (o item no inventário de um cliente, com estado próprio), **regras de domínio** e **visualização**. Um `UVGWeaponData` é a linha do catálogo; um `AVGWeapon` é o item que a jogadora carrega.

---

## 20.2 A arma como máquina de estado

Estados de uma arma simples:

```text
             Equip()                      tempo de equipar
  ┌──────────┐ ──────► ┌───────────┐ ─────────────────────► ┌───────┐
  │Holstered │         │ Equipping │                        │ Ready │◄─────────┐
  └──────────┘ ◄────── └───────────┘                        └───┬───┘          │
       ▲     Holster()                                          │              │
       │                                     StartReload()      │              │
       │                                 (pente não cheio e     ▼              │
       │                                   há reserva)    ┌───────────┐        │
       └──────────────── Holster() (cancela) ─────────────│ Reloading │────────┘
                                                          └───────────┘ tempo de
                                                                        recarga
```

Disparar **não** é um estado próprio nesta modelagem: disparos acontecem **dentro** do estado `Ready`, controlados por uma cadência. Isso é uma escolha: algumas implementações têm um estado `Firing` explícito (útil quando o disparo tem fases longas, como uma arma que precisa "aquecer"). Para armas comuns, tratar o disparo como **evento dentro de `Ready`**, com um temporizador de cadência, mantém a máquina pequena.

As **regras de interrupção** são decisões de design que a máquina torna explícitas:

| Situação | Regra da Vigília | Alternativa comum em FPS |
|---|---|---|
| Atirar durante a recarga | Não pode | Alguns jogos cancelam a recarga ao atirar (se houver munição no pente) |
| Trocar de arma durante a recarga | Cancela a recarga; a munição não é transferida | Igual |
| Recarregar com pente cheio | Ignorado | Igual |
| Atirar sem munição | "Clique seco" + recarga automática se houver reserva | Alguns exigem recarga manual |
| Correr durante a recarga | Permitido (Vigília); a recarga continua | Muitos FPS cancelam ou bloqueiam |

Cada linha muda a sensação do combate. "Correr cancela a recarga" pune a fuga; "atirar cancela a recarga" premia a reação rápida. Por isso a máquina de estado não é só uma estrutura de código: ela é a **especificação das regras de combate**.

---

## 20.3 Cadência de tiro sem depender do frame rate

A cadência é normalmente especificada em **disparos por minuto** (RPM, *rounds per minute*). O intervalo entre disparos é `60 / RPM` segundos:

```text
 RPM     intervalo     disparos/s
 120     500 ms           2        (pistola de ação lenta, sinalizador)
 400     150 ms          ~6,7      (pistola semiautomática ágil)
 750      80 ms          12,5      (fuzil automático)
1200      50 ms          20        (submetralhadora rápida)
```

### O bug clássico

A implementação ingênua, a cada frame:

```cpp
if (bTriggerHeld && (Now - LastFireTime) >= Interval)
{
    Fire();
    LastFireTime = Now;
}
```

Ela dispara **no máximo uma vez por frame**. Com 1.200 RPM (50 ms) e o jogo a 15 FPS (66 ms por frame), a arma dispara 15 vezes por segundo em vez de 20. Pior: mesmo a 60 FPS, `LastFireTime = Now` descarta o "atraso" acumulado — se o frame termina 10 ms depois do momento ideal do disparo, o próximo disparo também atrasa 10 ms, e o erro se acumula. A cadência real fica dependente do frame rate.

Este é o problema do Capítulo 3, de novo: **o passo do tempo não é um bom relógio para eventos com período próprio**. A solução também é a do Capítulo 3 — um **acumulador**:

```text
tempo_até_próximo −= Δt
enquanto quero atirar e tempo_até_próximo ≤ 0:
    atirar
    tempo_até_próximo += intervalo     ← soma, não "zera": preserva o resto
se tempo_até_próximo < 0:
    tempo_até_próximo = 0              ← parado não acumula "crédito" de tiros
```

Com isso, uma arma a 1.200 RPM dispara 20 vezes por segundo a 15, 60 ou 144 FPS — às vezes dois disparos no mesmo frame, quando o frame é longo. A última linha é importante: sem ela, ficar parado com a arma pronta acumularia "tiros devidos", e apertar o gatilho dispararia uma rajada instantânea.

### Buffer de input em armas semiautomáticas

Numa arma semiautomática, cada clique é um disparo. Se o jogador clicar **um pouco antes** de o intervalo terminar, o que acontece? Ignorar o clique faz a arma parecer "que não respondeu"; guardá-lo indefinidamente faz a arma disparar "sozinha" muito depois.

A solução comum é um **buffer curto**: um clique feito quando falta pouco para o próximo disparo ser permitido (digamos, menos de 0,1–0,15 s) é **guardado** e executado assim que possível; cliques feitos muito antes são ignorados. É a mesma ideia do *jump buffering* do Capítulo 1, aplicada ao gatilho — e é invisível quando funciona, que é o objetivo.

Para o sinalizador da Vigília, com intervalo longo, o buffer é essencial no sentido inverso: ele **impede** que um clique ansioso no meio do intervalo resulte num disparo inesperado segundos depois, gastando um dos poucos cartuchos.

---

## 20.4 Munição e recarga

Munição tem dois números: **no pente** (o que pode ser disparado agora) e **reserva** (o que pode ser carregado). A recarga transfere da reserva para o pente:

```text
transferir = min(capacidade_do_pente − no_pente, reserva)
no_pente  += transferir
reserva   −= transferir
```

Decisões de design embutidas:

- **Recarga parcial preserva a munição restante no pente** (o modelo acima). Alguns jogos descartam o pente parcialmente usado — uma escolha "realista" que pune recargas frequentes. A Vigília preserva.
- **Recarga por cartucho** (escopetas, o próprio sinalizador) é um modelo diferente: cada cartucho é uma pequena ação, e a recarga pode ser interrompida entre eles. É uma extensão natural da máquina de estado — e o desafio deste capítulo.
- **Tempo de recarga** é um dado, e um dos parâmetros de balanceamento mais importantes: ele define a **janela de vulnerabilidade** do jogador. Num jogo de terror, uma recarga lenta do sinalizador é tensão pura.

A recarga é um **processo que atravessa frames** (Capítulo 4): ela tem início, duração e fim, e as perguntas de cancelamento se aplicam. Nesta implementação, ela é um timer: cancelável (troca de arma), não salvável (um save no meio da recarga simplesmente volta ao estado anterior — aceitável) e protegida contra disparo duplo (só começa a partir de `Ready`).

---

## 20.5 Onde a arma mora: ator, componente ou objeto?

Três opções razoáveis:

| | Arma como **Ator** | Arma como **Componente** do personagem | Arma como **UObject** (dados + estado) |
|---|---|---|---|
| Tem malha própria e se anexa | ✓ natural | Possível (componentes de malha) | ✗ (precisa de outro objeto para a malha) |
| Pode existir no mundo (largada, coletável) | ✓ | ✗ (precisa virar ator) | ✗ |
| Replicação em rede | ✓ (ator replicado) | ✓ (componente replicado) | Mais trabalhosa |
| Várias armas no inventário | Vários atores (escondidos) | Vários componentes | Leve: vários objetos |
| Custo | Maior | Médio | Menor |

A Vigília usa **arma como ator**, por três razões: a arma tem malha e efeitos próprios; armas e munição podem ser **coletadas no mundo** (o sinalizador é encontrado, não começa com a jogadora); e a Parte IX vai replicar armas, o que é natural com atores. O personagem não fala diretamente com a arma: ele fala com um **componente de armas** (`UVGWeaponComponent`), que é dono do inventário e da arma equipada.

```text
AVGCharacter
 ├── input: IA_Fire, IA_Reload  ──► UVGWeaponComponent (inventário, arma atual)
 │                                       │ cria, anexa, equipa
 │                                       ▼
 │                                  AVGWeapon (ator: estado + comportamento)
 │                                       │ lê
 │                                       ▼
 │                                  UVGWeaponData (Data Asset: os números)
 └── FirstPersonCamera  ◄── a arma é anexada à câmera (por enquanto, sem braços)
```

**Simplificação declarada:** sem modelo de braços, a arma é anexada **à câmera**, deslocada para a frente e para a direita — o visual de um FPS dos anos 1990. Os braços e as animações de primeira pessoa entram no Capítulo 53.

---

## 20.6 O pipeline de disparo

Um disparo, do clique ao efeito, passa por etapas que convém manter separadas:

```text
 input (IA_Fire)
   │
   ▼
 UVGWeaponComponent.StartFire ──► AVGWeapon.StartFire  (registra intenção: gatilho, buffer)
                                       │
                                       ▼ Tick (acumulador de cadência)
                                  POSSO ATIRAR?  estado Ready · munição · cadência
                                       │ sim                    │ sem munição
                                       ▼                        ▼
                                  CONSUMIR munição          clique seco → recarga automática?
                                       │
                                       ▼
                                  EXECUTAR o disparo       ← PerformShot: hitscan (Cap. 27)
                                       │                     ou projétil (Cap. 28)
                                       ▼
                                  ANUNCIAR                 ← OnFired, OnAmmoChanged
                                       │
                                       ▼
                                  APRESENTAR               ← som, flash, tremor, recoil (Cap. 29)
```

O ponto de extensão central é **`PerformShot`** — o que o disparo faz no mundo. Neste capítulo, ele é um trace simples de teste. No Capítulo 27, vira hitscan completo (dispersão, penetração, dano); no Capítulo 28, o sinalizador o sobrescreve para lançar um projétil. O resto do pipeline — cadência, munição, estados, anúncios — **não muda**.

---

## Estudo de caso: armas como dados em FPS

> **Pergunta:** por que tantas armas diferentes num FPS parecem diferentes, se todas "fazem a mesma coisa"?

**[FATO PÚBLICO]** Shooters como as séries Call of Duty e Battlefield apresentam ao jogador, nas telas de equipamento, **estatísticas das armas** (por exemplo, dano, cadência, alcance, precisão, mobilidade — os nomes e o formato variam entre jogos e edições) e permitem modificar armas com **acessórios** (miras, canos, pentes, coronhas) que alteram essas estatísticas, às vezes melhorando uma característica à custa de outra.

**[INFERÊNCIA]** Isso indica, de forma bem direta, um modelo **orientado a dados**: a arma é definida por um conjunto de parâmetros, e acessórios funcionam como **modificadores** aplicados sobre esses parâmetros. A variedade de armas — e a variedade combinatória de configurações — vem dos **dados**, não de código diferente para cada arma. O código do pipeline de disparo é compartilhado; o que muda é a planilha. Nenhuma afirmação é feita aqui sobre como esses jogos estruturam internamente seus sistemas.

**[SIMPLIFICAÇÃO DIDÁTICA]** A versão mínima é este capítulo: `UVGWeaponData` com os parâmetros base, e um único pipeline em `AVGWeapon`. O passo seguinte (Capítulo 26) é separar **parâmetros base** de **parâmetros efetivos**, calculados aplicando modificadores — a mesma ideia do "valor efetivo derivado de pedidos" do subsistema de dilatação do tempo (Capítulo 6).

**Lição:** **variedade de gameplay barata vem de dados sobre um pipeline estável.** Investir na qualidade do pipeline (cadência correta, buffer, estados, feedback) beneficia todas as armas de uma vez; cada arma nova custa um Data Asset e um pouco de apresentação.

---

## Comparação com o desenvolvimento tradicional

| Arma | O que você conhece | Onde a analogia cai |
|---|---|---|
| Dados / estado / comportamento / apresentação | Catálogo / instância / domínio / view | A "view" (feedback) é metade da qualidade percebida |
| Máquina de estado da arma | Ciclo de vida de entidade | Transições em frações de segundo, com regras de interrupção que são design |
| Cadência com acumulador | Rate limiter com *token bucket* | Aqui, o "bucket" não pode acumular crédito ocioso |
| Buffer de input | Debounce / fila curta de comandos | A janela é de ~100 ms, ajustada por sensação |
| Recarga como timer | Processo assíncrono com timeout | Cancelável por eventos de gameplay; não precisa sobreviver a um save |

A comparação com o *token bucket* é precisa e útil: um rate limiter clássico permite rajadas se houver tokens acumulados. A arma é um rate limiter **sem acúmulo ocioso** — por design, porque rajadas instantâneas ao apertar o gatilho seriam um bug de jogo.

---

## Implementação

### 1. Os dados

```cpp
// Source/Vigilia/Combat/VGWeaponData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGWeaponData.generated.h"

class USoundBase;
class UCameraShakeBase;

UENUM(BlueprintType)
enum class EVGFireMode : uint8
{
    SemiAuto,   // um disparo por clique
    FullAuto    // dispara enquanto o gatilho estiver pressionado
};

/** Definição de uma arma: o que ela É. Imutável em runtime. */
UCLASS(BlueprintType)
class VIGILIA_API UVGWeaponData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon")
    FText DisplayName;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Firing")
    EVGFireMode FireMode = EVGFireMode::SemiAuto;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Firing", meta = (ClampMin = "1.0"))
    float RoundsPerMinute = 400.0f;

    /** Cliques feitos até este tempo antes do próximo disparo permitido são guardados (semiauto). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Firing", meta = (ClampMin = "0.0"))
    float ShotBufferTime = 0.12f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Firing", meta = (ClampMin = "0.0"))
    float Damage = 25.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Firing", meta = (ClampMin = "100.0"))
    float Range = 5000.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Ammo", meta = (ClampMin = "1"))
    int32 MagazineSize = 8;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Ammo", meta = (ClampMin = "0"))
    int32 MaxReserveAmmo = 32;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Ammo", meta = (ClampMin = "0.05"))
    float ReloadTime = 1.6f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Ammo")
    bool bAutoReloadWhenEmpty = true;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Handling", meta = (ClampMin = "0.0"))
    float EquipTime = 0.4f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Feedback")
    TSubclassOf<UCameraShakeBase> FireCameraShake;

    float GetFireInterval() const { return 60.0f / FMath::Max(RoundsPerMinute, 1.0f); }
};
```

Sons e efeitos visuais ficam **no Blueprint da arma** (apresentação), não no Data Asset — com uma exceção, o tremor de câmera, que é parâmetro de *feel* compartilhado por todas as instâncias. A fronteira é discutível; o critério usado: **o que o designer de balanceamento ajusta** fica no Data Asset; **o que o artista ajusta** fica no Blueprint.

### 2. A arma

```cpp
// Source/Vigilia/Combat/VGWeapon.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGWeapon.generated.h"

class UVGWeaponData;
class AVGWeapon;

UENUM(BlueprintType)
enum class EVGWeaponState : uint8
{
    Holstered,
    Equipping,
    Ready,
    Reloading
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGWeaponAmmoChangedSignature,
    AVGWeapon*, Weapon, int32, InMagazine, int32, Reserve);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGWeaponFiredSignature, AVGWeapon*, Weapon);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGWeaponStateChangedSignature,
    AVGWeapon*, Weapon, EVGWeaponState, OldState, EVGWeaponState, NewState);

/**
 * Arma: estado (munição, estado, cadência) e comportamento (pipeline de disparo).
 * Os números vêm de UVGWeaponData; a apresentação fica no Blueprint filho.
 */
UCLASS(Abstract, Blueprintable)
class VIGILIA_API AVGWeapon : public AActor
{
    GENERATED_BODY()

public:
    AVGWeapon();

    virtual void Tick(float DeltaSeconds) override;

    void Equip();
    void Holster();
    void StartFire();
    void StopFire();
    void StartReload();

    /** Adiciona munição à reserva (pickups). Retorna quanto foi efetivamente adicionado. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Weapon")
    int32 AddReserveAmmo(int32 Amount);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    EVGWeaponState GetWeaponState() const { return State; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    int32 GetAmmoInMagazine() const { return AmmoInMagazine; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    int32 GetReserveAmmo() const { return ReserveAmmo; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    const UVGWeaponData* GetWeaponData() const { return Data; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Weapon")
    FVGWeaponAmmoChangedSignature OnAmmoChanged;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Weapon")
    FVGWeaponFiredSignature OnFired;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Weapon")
    FVGWeaponStateChangedSignature OnWeaponStateChanged;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    /** O que o disparo faz no mundo. Padrão: trace de teste. Cap. 27 (hitscan), Cap. 28 (projétil). */
    UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Weapon")
    void PerformShot();

    /** Apresentação do disparo (som, flash no cano) — Blueprint filho. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Weapon")
    void OnShotFeedback();

    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Weapon")
    void OnDryFire();

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon")
    TObjectPtr<UVGWeaponData> Data;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Weapon", meta = (ClampMin = "0"))
    int32 InitialReserveAmmo = 16;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UStaticMeshComponent> Mesh;

    /** Ponto de saída do disparo/efeitos. Posicione na ponta do cano no Blueprint. */
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<USceneComponent> Muzzle;

private:
    void TransitionTo(EVGWeaponState NewState);
    bool WantsToFire() const;
    void FireOnce();
    void HandleEmpty();
    void FinishEquip();
    void FinishReload();
    void BroadcastAmmo();

    EVGWeaponState State = EVGWeaponState::Holstered;
    int32 AmmoInMagazine = 0;
    int32 ReserveAmmo = 0;
    bool bTriggerHeld = false;
    bool bShotQueued = false;
    float TimeUntilNextShot = 0.0f;
    FTimerHandle ActionTimerHandle;
};
```

```cpp
// Source/Vigilia/Combat/VGWeapon.cpp
#include "Combat/VGWeapon.h"

#include "Camera/CameraShakeBase.h"
#include "Combat/VGWeaponData.h"
#include "Components/StaticMeshComponent.h"
#include "Core/VGLog.h"
#include "DrawDebugHelpers.h"
#include "GameFramework/PlayerController.h"
#include "TimerManager.h"

AVGWeapon::AVGWeapon()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = false; // só tica enquanto há intenção de atirar

    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    Mesh->SetCollisionEnabled(ECollisionEnabled::NoCollision); // a arma em 1ª pessoa não colide
    SetRootComponent(Mesh);

    Muzzle = CreateDefaultSubobject<USceneComponent>(TEXT("Muzzle"));
    Muzzle->SetupAttachment(Mesh);
}

void AVGWeapon::BeginPlay()
{
    Super::BeginPlay();

    if (!ensureMsgf(Data, TEXT("%s sem UVGWeaponData."), *GetName()))
    {
        return;
    }
    AmmoInMagazine = Data->MagazineSize;
    ReserveAmmo = FMath::Clamp(InitialReserveAmmo, 0, Data->MaxReserveAmmo);
    BroadcastAmmo();
}

void AVGWeapon::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearAllTimersForObject(this);
    Super::EndPlay(EndPlayReason);
}

// ---- Estados -----------------------------------------------------------------

void AVGWeapon::TransitionTo(EVGWeaponState NewState)
{
    if (NewState == State)
    {
        return;
    }
    const EVGWeaponState OldState = State;
    State = NewState;
    OnWeaponStateChanged.Broadcast(this, OldState, NewState);
}

void AVGWeapon::Equip()
{
    if (!Data || State != EVGWeaponState::Holstered)
    {
        return;
    }
    SetActorHiddenInGame(false);
    TransitionTo(EVGWeaponState::Equipping);
    GetWorldTimerManager().SetTimer(ActionTimerHandle, this, &AVGWeapon::FinishEquip, Data->EquipTime, false);
}

void AVGWeapon::FinishEquip()
{
    TimeUntilNextShot = 0.0f;
    TransitionTo(EVGWeaponState::Ready);
    if (WantsToFire())
    {
        SetActorTickEnabled(true); // gatilho já pressionado durante o equipar
    }
}

void AVGWeapon::Holster()
{
    GetWorldTimerManager().ClearTimer(ActionTimerHandle); // cancela equipar/recarregar
    bTriggerHeld = false;
    bShotQueued = false;
    SetActorTickEnabled(false);
    SetActorHiddenInGame(true);
    TransitionTo(EVGWeaponState::Holstered);
}

// ---- Disparo -----------------------------------------------------------------

void AVGWeapon::StartFire()
{
    bTriggerHeld = true;
    if (Data && Data->FireMode == EVGFireMode::SemiAuto)
    {
        // Buffer: só guarda o clique se a arma estiver pronta e o próximo disparo estiver próximo.
        // Em Reloading/Equipping o clique é descartado — senão dispararia sozinho ao fim da ação.
        bShotQueued = (State == EVGWeaponState::Ready && TimeUntilNextShot <= Data->ShotBufferTime);
    }
    SetActorTickEnabled(true);
}

void AVGWeapon::StopFire()
{
    bTriggerHeld = false;
}

bool AVGWeapon::WantsToFire() const
{
    if (!Data)
    {
        return false;
    }
    return Data->FireMode == EVGFireMode::FullAuto ? bTriggerHeld : bShotQueued;
}

void AVGWeapon::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (!Data)
    {
        SetActorTickEnabled(false); // arma mal configurada: o ensure do BeginPlay já avisou
        return;
    }

    TimeUntilNextShot -= DeltaSeconds;
    const float Interval = Data->GetFireInterval();

    // Acumulador (Cap. 3): pode disparar mais de uma vez por frame se o frame for longo.
    while (State == EVGWeaponState::Ready && TimeUntilNextShot <= 0.0f && WantsToFire())
    {
        if (AmmoInMagazine <= 0)
        {
            HandleEmpty();
            break;
        }
        FireOnce();
        TimeUntilNextShot += Interval;
        bShotQueued = false;
    }

    if (TimeUntilNextShot < 0.0f)
    {
        TimeUntilNextShot = 0.0f; // parada, a arma não acumula "crédito" de disparos
    }
    if (!WantsToFire() && TimeUntilNextShot <= 0.0f)
    {
        SetActorTickEnabled(false);
    }
}

void AVGWeapon::FireOnce()
{
    --AmmoInMagazine;               // 1. estado
    PerformShot();                  // 2. efeito no mundo
    OnShotFeedback();               // 3. apresentação da própria arma
    OnFired.Broadcast(this);        // 4. outros sistemas (recoil, ruído para a IA, HUD)
    BroadcastAmmo();

    if (Data->FireCameraShake)
    {
        if (APlayerController* PC = Cast<APlayerController>(GetInstigatorController()))
        {
            PC->ClientStartCameraShake(Data->FireCameraShake);
        }
    }
}

void AVGWeapon::HandleEmpty()
{
    bShotQueued = false;
    bTriggerHeld = false; // evita "cliques secos" em sequência a cada frame
    OnDryFire();
    if (Data->bAutoReloadWhenEmpty)
    {
        StartReload();
    }
}

void AVGWeapon::PerformShot_Implementation()
{
    // Simplificação: trace de teste a partir do ponto de vista do atirador, sem dano.
    // Substituído pelo hitscan completo no Cap. 27.
    const AController* Controller = GetInstigatorController();
    if (!Controller)
    {
        return;
    }
    FVector ViewLocation;
    FRotator ViewRotation;
    Controller->GetPlayerViewPoint(ViewLocation, ViewRotation);

    const FVector End = ViewLocation + ViewRotation.Vector() * Data->Range;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGWeaponTestShot), false, GetInstigator());
    Params.AddIgnoredActor(this);

    FHitResult Hit;
    const bool bHit = GetWorld()->LineTraceSingleByChannel(Hit, ViewLocation, End, ECC_Visibility, Params);
    DrawDebugLine(GetWorld(), Muzzle->GetComponentLocation(), bHit ? Hit.ImpactPoint : End,
                  bHit ? FColor::Red : FColor::White, false, 0.5f);
    if (bHit)
    {
        UE_LOG(LogVigilia, Verbose, TEXT("%s acertou %s"), *GetName(), *GetNameSafe(Hit.GetActor()));
    }
}

// ---- Munição -----------------------------------------------------------------

void AVGWeapon::StartReload()
{
    if (!Data || State != EVGWeaponState::Ready
        || AmmoInMagazine >= Data->MagazineSize || ReserveAmmo <= 0)
    {
        return;
    }
    TransitionTo(EVGWeaponState::Reloading);
    GetWorldTimerManager().SetTimer(ActionTimerHandle, this, &AVGWeapon::FinishReload, Data->ReloadTime, false);
}

void AVGWeapon::FinishReload()
{
    const int32 Transfer = FMath::Min(Data->MagazineSize - AmmoInMagazine, ReserveAmmo);
    AmmoInMagazine += Transfer;
    ReserveAmmo -= Transfer;
    TransitionTo(EVGWeaponState::Ready);
    BroadcastAmmo();
}

int32 AVGWeapon::AddReserveAmmo(int32 Amount)
{
    if (!Data || Amount <= 0)
    {
        return 0;
    }
    const int32 Added = FMath::Min(Amount, Data->MaxReserveAmmo - ReserveAmmo);
    ReserveAmmo += Added;
    BroadcastAmmo();
    return Added;
}

void AVGWeapon::BroadcastAmmo()
{
    OnAmmoChanged.Broadcast(this, AmmoInMagazine, ReserveAmmo);
}
```

### Explicação das decisões

- **Tick ligado só com intenção de atirar.** Uma arma pronta e parada não custa nada por frame. `StartFire` liga; o próprio Tick desliga quando não há mais intenção nem cadência pendente.
- **O acumulador é o do Capítulo 3**, com o "sem crédito ocioso" da seção 20.3. Teste: a 1.200 RPM e `t.MaxFPS 15`, a contagem de disparos por segundo deve ser 20.
- **Ordem em `FireOnce`: estado → efeito → apresentação → anúncio.** A munição já foi decrementada quando a HUD recebe `OnAmmoChanged` (Capítulo 4: broadcast depois do estado consistente).
- **`HandleEmpty` solta o gatilho.** Sem isso, numa arma automática sem munição, cada frame produziria um "clique seco".
- **O buffer só vale em `Ready`.** Um clique durante a recarga ou o equipar é descartado. Guardá-lo faria o sinalizador disparar sozinho 2,5 s depois, ao fim da recarga, gastando um cartucho — o "buffer infinito" das Armadilhas, entrando por outra porta. (Numa arma automática, quem segura o gatilho durante a recarga volta a atirar ao fim dela; aí a intenção ainda está presente.)
- **Recarga e equipar por timer**, ambos canceláveis por `Holster` (um único handle de "ação em andamento" — a arma só faz uma ação temporizada por vez).
- **`GetInstigatorController()`** para o ponto de vista e o tremor: a arma não sabe que é a jogadora que a segura. Uma IA com a mesma arma (o Vigia, Parte V) funcionaria com `PerformShot` a partir do ponto de vista dela — o `GetPlayerViewPoint` de um `AIController` devolve a posição dos olhos do pawn.
- **`AddReserveAmmo`** para pickups de munição, com limite do Data Asset (um invariante: a reserva nunca passa do máximo).

### 3. O componente de armas

```cpp
// Source/Vigilia/Combat/VGWeaponComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGWeaponComponent.generated.h"

class AVGWeapon;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGWeaponEquippedSignature, AVGWeapon*, Weapon);

/** Dono das armas do personagem: cria, anexa, equipa e encaminha o input para a arma atual. */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGWeaponComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGWeaponComponent();

    /** Cria uma arma da classe dada, anexa e equipa (substitui a atual). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Weapon")
    AVGWeapon* GiveWeapon(TSubclassOf<AVGWeapon> WeaponClass);

    void StartFire();
    void StopFire();
    void Reload();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    AVGWeapon* GetCurrentWeapon() const { return CurrentWeapon; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Weapon")
    FVGWeaponEquippedSignature OnWeaponEquipped;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    /** Arma inicial (vazio = começa desarmada, como na Vigília). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon")
    TSubclassOf<AVGWeapon> StartingWeaponClass;

    /** Posição da arma relativa à câmera (simplificação sem braços). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon")
    FTransform WeaponOffset = FTransform(FVector(35.0, 14.0, -14.0));

private:
    USceneComponent* GetAttachParent() const;

    UPROPERTY(Transient)
    TObjectPtr<AVGWeapon> CurrentWeapon;
};
```

```cpp
// Source/Vigilia/Combat/VGWeaponComponent.cpp
#include "Combat/VGWeaponComponent.h"

#include "Camera/CameraComponent.h"
#include "Combat/VGWeapon.h"
#include "Player/VGCharacter.h"

UVGWeaponComponent::UVGWeaponComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UVGWeaponComponent::BeginPlay()
{
    Super::BeginPlay();
    if (StartingWeaponClass)
    {
        GiveWeapon(StartingWeaponClass);
    }
}

void UVGWeaponComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (CurrentWeapon)
    {
        CurrentWeapon->Destroy(); // a arma pertence ao personagem nesta fase do projeto
        CurrentWeapon = nullptr;
    }
    Super::EndPlay(EndPlayReason);
}

USceneComponent* UVGWeaponComponent::GetAttachParent() const
{
    const AVGCharacter* Character = Cast<AVGCharacter>(GetOwner());
    return Character ? Character->GetFirstPersonCamera() : GetOwner()->GetRootComponent();
}

AVGWeapon* UVGWeaponComponent::GiveWeapon(TSubclassOf<AVGWeapon> WeaponClass)
{
    if (!WeaponClass)
    {
        return nullptr;
    }
    if (CurrentWeapon)
    {
        CurrentWeapon->Holster();
        CurrentWeapon->Destroy(); // Simplificação: uma arma por vez; inventário real no Cap. 26
    }

    FActorSpawnParameters Params;
    Params.Owner = GetOwner();
    Params.Instigator = Cast<APawn>(GetOwner());
    Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    CurrentWeapon = GetWorld()->SpawnActor<AVGWeapon>(WeaponClass, FTransform::Identity, Params);
    if (!CurrentWeapon)
    {
        return nullptr;
    }

    CurrentWeapon->AttachToComponent(GetAttachParent(), FAttachmentTransformRules::SnapToTargetNotIncludingScale);
    CurrentWeapon->SetActorRelativeTransform(WeaponOffset);
    CurrentWeapon->SetActorHiddenInGame(true);
    CurrentWeapon->Equip();
    OnWeaponEquipped.Broadcast(CurrentWeapon);
    return CurrentWeapon;
}

void UVGWeaponComponent::StartFire() { if (CurrentWeapon) { CurrentWeapon->StartFire(); } }
void UVGWeaponComponent::StopFire()  { if (CurrentWeapon) { CurrentWeapon->StopFire(); } }
void UVGWeaponComponent::Reload()    { if (CurrentWeapon) { CurrentWeapon->StartReload(); } }
```

**Instigator** é configurado no spawn (Capítulo 8): é por ele que a arma sabe quem atira, e é por ele que o sistema de dano (Capítulo 22) saberá **quem causou** o dano.

### 4. Ligando ao personagem

No `AVGCharacter`: crie o `UVGWeaponComponent`, as ações `IA_Fire` (botão esquerdo / gatilho direito) e `IA_Reload` (`R` / botão do controle), e os bindings — `IA_Fire` em `Started` → `StartFire`, em `Completed` → `StopFire`; `IA_Reload` em `Started` → `Reload`.

---

## Projeto 2 — Galpão de Testes (início)

O Galpão do Pátio (Projeto 1), destrancado pelo disjuntor (Projeto 3), vira o **campo de testes de armas**:

1. **Layout:** um estande com alvos (cubos e cilindros) a 5, 10, 20 e 40 metros; uma parede de materiais (concreto, metal, madeira) para testar impactos no Capítulo 27; uma área aberta para o inimigo simples do Capítulo 30.
2. **`DA_Pistola`** (semiauto, 400 RPM, pente 8, recarga 1,6 s) e **`BP_Pistola`** (filho de `AVGWeapon`, um cubo alongado como malha, som de disparo placeholder no `OnShotFeedback`).
3. **`DA_Fuzil`** (automático, 750 RPM, pente 30, recarga 2,2 s) e **`BP_Fuzil`**.
4. **`DA_Sinalizador`** (semiauto, 60 RPM, pente 1, recarga 2,5 s, reserva máxima 3, `InitialReserveAmmo = 0`) e **`BP_Sinalizador`**. Pente mais reserva dão os **4 cartuchos no máximo** do documento de combate (Capítulo 21), e a arma chega só com o cartucho do pente, porque o `BeginPlay` enche o pente na coleta. — a arma da Vigília. Por enquanto, com o trace de teste; no Capítulo 28, ele dispara um projétil luminoso.
5. **Três suportes** no galpão (`BP_SuporteArma`, filhos de `AVGPickup`) que, ao interagir, chamam `GiveWeapon` com a classe configurada — o sistema de interação (Capítulo 19) e o de armas se conectando por um Blueprint de dez nós.
6. Um texto de debug na tela (temporário, até o Capítulo 55) mostrando munição no pente e reserva, alimentado por `OnAmmoChanged`.

---

## Decisões arquiteturais

1. **Quatro camadas:** dados (`UVGWeaponData`), estado e comportamento (`AVGWeapon`), apresentação (Blueprint filho).
2. **Arma como ator**, possuída por um `UVGWeaponComponent` no personagem.
3. **Máquina de estado pequena** (`Holstered`, `Equipping`, `Ready`, `Reloading`); disparo como evento dentro de `Ready`.
4. **Cadência por acumulador, sem crédito ocioso; buffer curto em semiautomáticas.**
5. **`PerformShot` como ponto de extensão** do efeito no mundo; o resto do pipeline é estável.
6. **Ordem do disparo: estado → efeito → apresentação → anúncio.**
7. **Regras de interrupção explícitas** (tabela da seção 20.2), registradas como decisões de design.
8. **A arma não conhece a jogadora:** usa `Instigator` e o controller do instigador.

---

## Armadilhas

- **Cadência dependente do frame rate** (`LastFireTime = Now`).
- **Acumular crédito de disparos** com a arma parada — rajadas instantâneas.
- **Buffer infinito** em semiautomáticas — disparos "fantasmas".
- **Clique seco a cada frame** com arma automática vazia.
- **Recarga que não é cancelada** ao trocar de arma, transferindo munição para uma arma guardada.
- **Números de balanceamento no código** em vez do Data Asset.
- **Sons e efeitos dentro do pipeline em C++** em vez de eventos para o Blueprint.
- **A arma consultando a jogadora diretamente** (`Cast<AVGCharacter>`) para decidir de onde atirar.
- **Esquecer o Instigator no spawn** — o dano (Capítulo 22) não saberá quem atirou.

---

## Exercício

**Parte 1 — o sistema (2 h).** Implemente `UVGWeaponData`, `AVGWeapon`, `UVGWeaponComponent` e os bindings. Monte o Galpão de Testes com as três armas e os suportes.

**Parte 2 — cadência (45 min).** Crie um cheat (`UVGCheatManager`) que liga um contador: quantos disparos por segundo a arma atual fez nos últimos 3 segundos. Teste o fuzil (750 RPM → 12,5/s) com `t.MaxFPS 15`, `30`, `60` e `144`. Depois, troque o acumulador pela versão ingênua da seção 20.3 e repita. Registre a tabela no `DEVLOG.md`.

**Parte 3 — buffer (30 min).** Com a pistola, clique o mais rápido que conseguir. Mude `ShotBufferTime` para 0 e para 0,5. Qual valor parece "responsivo"? Qual parece que "a arma atira sozinha"? E com o sinalizador?

**Parte 4 — regras (30 min).** Implemente uma das alternativas da tabela da seção 20.2 (por exemplo, "atirar cancela a recarga se houver munição no pente") como propriedade do Data Asset. Jogue com e sem a regra.

---

## Desafio — recarga por cartucho

O sinalizador da Vigília usa cartuchos individuais. Implemente o modelo de **recarga por cartucho**:

1. `UVGWeaponData` ganha `bReloadPerRound` e `PerRoundReloadTime`.
2. Com `bReloadPerRound`, a recarga insere **um cartucho por vez**, a cada `PerRoundReloadTime`, até o pente encher ou a reserva acabar.
3. **Atirar durante a recarga** interrompe a recarga (se houver ao menos um cartucho no pente) e dispara.
4. O anúncio `OnAmmoChanged` acontece a cada cartucho inserido (a HUD mostra o pente "enchendo").

Pergunta para o `DEVLOG.md`: a máquina de estado precisou de um estado novo, ou `Reloading` com um timer em loop foi suficiente? O que isso diz sobre quando vale a pena adicionar estados? *(Releia a seção 4.3 do Capítulo 4.)*

---

## Uso de IA

1. **Para validar a cadência:**
   > "Tenho um sistema de cadência de tiro com acumulador: TimeUntilNextShot -= dt; enquanto quero atirar e TimeUntilNextShot <= 0, disparo e somo o intervalo; no fim, se TimeUntilNextShot < 0, zero. Prove (ou refute) que a cadência média é independente do frame rate, analise o comportamento com frames muito longos (500 ms) e proponha um limite de disparos por frame se necessário. Explique o efeito do 'zerar' no final."

2. **Para desenhar regras de combate:**
   > "Para um jogo de terror em primeira pessoa com uma única arma de poucos cartuchos (um sinalizador), proponha regras de recarga, interrupção, troca e munição que maximizem a tensão sem frustrar. Para cada regra, explique a dinâmica esperada (no sentido do MDA) e como testar em playtest."

3. **Para revisar a arquitetura:**
   > "Revise esta arquitetura de armas em Unreal Engine 5 (Data Asset com os números, ator com estado e comportamento, componente no personagem, apresentação em Blueprint). Que mudanças seriam necessárias para: acessórios que modificam estatísticas, duas armas equipadas (primária e secundária), armas largadas no chão e coletáveis, e replicação em multiplayer? Aponte quais partes não mudariam."

---

## Checklist

- [ ] Sei separar dados, estado, comportamento e apresentação de uma arma.
- [ ] Modelei a arma como máquina de estado com regras de interrupção explícitas.
- [ ] Implementei cadência por acumulador, sem crédito ocioso, e verifiquei a independência do frame rate.
- [ ] Implementei buffer de input em semiautomáticas e entendo o seu efeito em armas lentas.
- [ ] Implementei munição, recarga e pickups de munição com invariantes.
- [ ] Sei justificar a arma como ator e o componente de armas como dono.
- [ ] O pipeline de disparo tem `PerformShot` como ponto de extensão.
- [ ] O Galpão de Testes tem pistola, fuzil e sinalizador funcionando.

---

## Para ir além

- **Projeto `RefFirstPerson`** (Capítulo 7) — compare a arma do template (da 5.6 em diante, a da variante *Arena Shooter*) com a da Vigília: onde ficam os dados, o estado e a apresentação?
- **GDC Vault** (gdcvault.com) — busque talks de desenvolvedores de shooters sobre design de armas e *gunplay*; elas costumam discutir cadência, feedback e balanceamento a partir de dados.
- **Lyra Starter Game** — o sistema de armas da Lyra (baseado em *Gameplay Ability System*) é uma referência de como um projeto grande da Epic organiza o mesmo problema; leia depois do Capítulo 26.

---

➡️ **Próximo:** [Capítulo 21 — Combat](cap-21-combat.md)

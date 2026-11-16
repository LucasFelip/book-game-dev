# Capítulo 26 — Weapon System

## Objetivo

Ao final deste capítulo você deve conseguir:

- separar **estatísticas base** de **estatísticas efetivas**, e calcular as efetivas aplicando **modificadores** (acessórios) com uma ordem de operações explícita e testável;
- evoluir o componente de armas para um **inventário com slots**, troca de arma com tempos e regras de interrupção;
- implementar **mira com a arma** (*aim down sights*, ADS) como uma transição contínua que afeta dispersão, FOV, posição da arma e velocidade;
- decidir **onde mora cada estado** do sistema de armas (na arma, no componente, no personagem);
- entender por que sistemas de customização de armas em shooters são, essencialmente, **pipelines de modificadores sobre dados**.

---

## Contexto

O Capítulo 20 construiu uma arma: dados, estado, cadência, munição, recarga. Ela funciona sozinha. Um **sistema** de armas acrescenta as perguntas que surgem quando há várias armas e várias formas de usá-las:

- A jogadora carrega duas armas. Como troca? Quanto tempo leva? Pode trocar no meio da recarga?
- Mirar com a arma (*ADS*) reduz a dispersão, aproxima a câmera e desacelera o movimento. Quem é dono de "estou mirando"?
- Uma luneta aumenta o zoom e diminui a cadência efetiva da mira; um cano longo aumenta o alcance e piora o manuseio. Como os números se combinam?

O padrão que responde a todas é o mesmo que o livro já usou duas vezes — no subsistema de dilatação do tempo (Capítulo 6) e nas tags de status com contagem (Capítulo 23): **um valor efetivo derivado de uma base e de contribuições**, calculado num lugar só.

---

## 26.1 Estatísticas base e efetivas

🔁 **Refatoração do Capítulo 20.** Os números da arma deixam de ser propriedades soltas do `UVGWeaponData` e passam a formar uma **struct de estatísticas**:

```text
UVGWeaponData                         AVGWeapon
──────────────                        ─────────
FireMode, DamageType, feedback        Attachments (modificadores equipados)
BaseStats: FVGWeaponStats      ──►    EffectiveStats = Compute(BaseStats, Attachments)
  Damage, RPM, Magazine,                    │
  Reload, Equip, Range,                     └─► usado por TODO o pipeline:
  HipSpread, AimSpread,                          cadência, recarga, disparo, ADS, recoil
  AimTime, AimFOV, ...
```

A regra: **o pipeline nunca lê as estatísticas base diretamente.** Ele lê sempre as **efetivas**. Assim, um modificador novo (um acessório, um efeito de dificuldade, um *debuff* de "mãos trêmulas" quando a jogadora está com pouca vida) não exige mudar o pipeline — só o cálculo.

### Modificadores e ordem de operações

Um modificador é uma lista de operações sobre estatísticas: "+2 de pente", "×0,9 de cadência", "×1,25 de alcance". Quando há vários, a **ordem importa**:

```text
base = 10, modificadores: +5 e ×2

(10 + 5) × 2 = 30      somas primeiro, multiplicações depois
(10 × 2) + 5 = 25      multiplicações primeiro
```

O sistema precisa de uma regra **fixa e documentada**. A do projeto — comum em jogos com atributos — é:

```text
efetivo = (base + Σ somas) × Π multiplicadores
```

Somas primeiro, multiplicações depois, e todas as multiplicações combinadas por produto. Com isso, a ordem em que os acessórios foram equipados não altera o resultado — uma propriedade importante para o jogador (dois jogadores com os mesmos acessórios têm a mesma arma) e para a rede (Parte IX: o servidor e o cliente chegam ao mesmo valor).

> 🌉 **Ponte:** é uma **função pura de agregação** sobre uma lista de contribuições — exatamente o tipo de lógica que você já extrai e testa no domínio. E a regra "somas, depois produtos" garante **comutatividade** dentro de cada grupo, como uma agregação bem definida num pipeline de dados.

---

## 26.2 Inventário e troca

A Vigília precisa de dois slots — o **sinalizador** e, no trecho dos vigias, uma **pistola** coletada. O Galpão, de dois a três. O modelo:

```text
UVGWeaponComponent
 ├── Slots: [0] Sinalizador   [1] Pistola   (armas são atores, criados ao coletar)
 ├── CurrentSlot
 ├── PendingSlot (troca pedida enquanto a arma atual não pode guardar)
 └── estado de mira (ADS) — seção 26.3
```

Regras de troca, como decisões de design explícitas (no espírito da tabela do Capítulo 20, seção 20.2):

| Situação | Regra do projeto |
|---|---|
| Trocar durante a recarga | Cancela a recarga; nenhuma munição é transferida |
| Trocar durante o equipar | Permitido; a nova arma começa a equipar do zero |
| Trocar mirando | A mira é desfeita; a nova arma começa sem mira |
| Trocar para o slot já equipado | Ignorado |
| Atirar durante a troca | Ignorado até a nova arma ficar pronta (`Ready`) |

As armas que não estão em uso **continuam existindo** (escondidas, com tick desligado), preservando munição e estado — por isso o inventário guarda atores, não classes.

---

## 26.3 Mirar com a arma (ADS)

Mirar não é um "modo" binário: é uma **transição contínua** de algumas centenas de milissegundos entre "atirando do quadril" (*hip fire*) e "mirando pela mira" (*aim down sights*). Um único valor — o **alfa de mira**, de 0 a 1 — governa todos os efeitos:

```text
               alfa de mira: 0 ─────────────────────────────► 1
dispersão       HipSpread  ──────────────────────────────────► AimSpread
FOV             FOV base   ──────────────────────────────────► FOV × AimFOVMultiplier
posição da arma quadril    ──────────────────────────────────► centro (mira alinhada)
velocidade      100%       ──────────────────────────────────► AimMoveSpeedMultiplier
balanço         100%       ──────────────────────────────────► reduzido
```

O alfa avança no tempo (`Δt / AimTime`) enquanto o botão de mira está pressionado e recua quando é solto. Atirar com alfa 0,5 — no meio da transição — usa uma dispersão intermediária. Isso é o que faz a mira parecer **física**: não há um "clique" de estado, há um movimento.

### Quem é dono do quê

| Estado | Dono | Por quê |
|---|---|---|
| Dispersão e tempo de mira **da arma** | Estatísticas efetivas da arma | São características da arma (e dos acessórios) |
| **Estar mirando** (alfa) | `UVGWeaponComponent` | É sobre **como a jogadora segura** a arma atual; muda ao trocar de arma |
| FOV de mira aplicado | Modificador de câmera (Capítulo 18) | Efeito do ponto de vista; consulta o componente |
| Velocidade reduzida | Personagem / perfil de movimento | O corpo; consulta o componente |

### Regras de interação com o movimento

- **Correr cancela a mira**, e **mirar cancela a corrida** — a regra mais comum em shooters, porque correr e mirar com precisão são ações que competem.
- **Mirar no ar** é permitido, com o alfa avançando normalmente (a dispersão no ar pode ser penalizada no Capítulo 27).

---

## Estudo de caso: customização de armas como pipeline de modificadores

> **Pergunta:** como um shooter oferece centenas de configurações de armas sem centenas de armas programadas?

**[FATO PÚBLICO]** *Call of Duty: Modern Warfare* (2019) introduziu o **Gunsmith**, um sistema de customização em que cada arma aceita um número limitado de acessórios (em categorias como cano, mira, coronha, pente, empunhadura e outros), cada um com **vantagens e desvantagens** apresentadas ao jogador (por exemplo, mais alcance ao custo de mobilidade ou de velocidade de mira). Sistemas de acessórios com trade-offs semelhantes existem em outros shooters, como a série Battlefield.

**[INFERÊNCIA]** A estrutura que torna isso viável é a da seção 26.1: **estatísticas base por arma**, **acessórios como conjuntos de modificadores** e um **cálculo único** das estatísticas efetivas, consumidas por um pipeline de disparo compartilhado. Os *trade-offs* são uma decisão de design imposta pelos **dados** de cada acessório (todo bônus vem com um ônus), e o limite de acessórios é uma regra do inventário. A variedade combinatória — o jogador sente que "montou a sua arma" — custa, para a engenharia, principalmente **conteúdo** (modelos, dados) e **balanceamento**, não código novo. Nenhuma afirmação é feita sobre a implementação real.

**[SIMPLIFICAÇÃO DIDÁTICA]** A versão mínima é este capítulo: `UVGWeaponModifier` (um Data Asset com operações sobre estatísticas), uma lista de modificadores equipados na arma e `ComputeEffectiveStats`. No Galpão, três acessórios de teste.

**Lição:** **quando a variedade é combinatória, invista na função que combina.** Uma função de agregação correta, testada e com ordem de operações definida suporta qualquer quantidade de conteúdo. Uma "regra especial" para cada acessório transformaria o sistema num `switch` gigante — o contrário do contrato uniforme do Capítulo 6.

---

## Comparação com o desenvolvimento tradicional

| Sistema de armas | O que você conhece | Onde a analogia cai |
|---|---|---|
| Base + modificadores → efetivo | Precificação com descontos e impostos; regras de cálculo | A "regra de ordem" afeta o *feel* e o balanceamento |
| Inventário de atores | Coleção de entidades com estado próprio | Itens inativos continuam no mundo (escondidos) |
| Alfa de mira | Transição animada de estado de UI | Governa simultaneamente física, câmera e regras |
| Regras de troca | Máquina de estado com cancelamento | Decisões de design que definem o ritmo do combate |

---

## Implementação

### 1. As estatísticas

```cpp
// Source/Vigilia/Combat/VGWeaponStats.h
#pragma once

#include "CoreMinimal.h"
#include "VGWeaponStats.generated.h"

UENUM(BlueprintType)
enum class EVGWeaponStat : uint8
{
    Damage,
    RoundsPerMinute,
    MagazineSize,
    ReloadTime,
    EquipTime,
    Range,
    HipSpread,
    AimSpread,
    AimTime,
    AimFOVMultiplier,
    AimMoveSpeedMultiplier,
    RecoilVertical,
    RecoilHorizontal
};

USTRUCT(BlueprintType)
struct FVGWeaponStats
{
    GENERATED_BODY()

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float Damage = 25.0f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float RoundsPerMinute = 400.0f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float MagazineSize = 8.0f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float ReloadTime = 1.6f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float EquipTime = 0.4f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float Range = 5000.0f;
    /** Dispersão do quadril e mirando, em graus (meio-ângulo do cone). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float HipSpread = 3.0f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float AimSpread = 0.4f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float AimTime = 0.22f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float AimFOVMultiplier = 0.8f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float AimMoveSpeedMultiplier = 0.6f;
    /** Usados no Cap. 29 (graus por disparo). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float RecoilVertical = 0.8f;
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Stats") float RecoilHorizontal = 0.3f;

    float GetFireInterval() const { return 60.0f / FMath::Max(RoundsPerMinute, 1.0f); }
    int32 GetMagazineSize() const { return FMath::Max(FMath::RoundToInt(MagazineSize), 1); }

    float& GetMutable(EVGWeaponStat Stat);
};
```

```cpp
// Source/Vigilia/Combat/VGWeaponStats.cpp
#include "Combat/VGWeaponStats.h"

float& FVGWeaponStats::GetMutable(EVGWeaponStat Stat)
{
    switch (Stat)
    {
    case EVGWeaponStat::Damage:                 return Damage;
    case EVGWeaponStat::RoundsPerMinute:        return RoundsPerMinute;
    case EVGWeaponStat::MagazineSize:           return MagazineSize;
    case EVGWeaponStat::ReloadTime:             return ReloadTime;
    case EVGWeaponStat::EquipTime:              return EquipTime;
    case EVGWeaponStat::Range:                  return Range;
    case EVGWeaponStat::HipSpread:              return HipSpread;
    case EVGWeaponStat::AimSpread:              return AimSpread;
    case EVGWeaponStat::AimTime:                return AimTime;
    case EVGWeaponStat::AimFOVMultiplier:       return AimFOVMultiplier;
    case EVGWeaponStat::AimMoveSpeedMultiplier: return AimMoveSpeedMultiplier;
    case EVGWeaponStat::RecoilVertical:         return RecoilVertical;
    case EVGWeaponStat::RecoilHorizontal:       return RecoilHorizontal;
    }
    checkNoEntry();
    return Damage;
}
```

Todas as estatísticas são `float`, inclusive o tamanho do pente (arredondado ao ler): isso permite que **qualquer** modificador se aplique a **qualquer** estatística com a mesma regra. O `switch` em `GetMutable` é a única ponte entre o enum e os campos — um preço pequeno para manter a struct editável no editor com nomes claros. (`checkNoEntry()` marca um caminho que nunca deve ser executado; se for, é um bug — um enum novo sem caso no `switch`.)

### 2. Modificadores (acessórios)

```cpp
// Source/Vigilia/Combat/VGWeaponModifier.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Combat/VGWeaponStats.h"
#include "VGWeaponModifier.generated.h"

UENUM(BlueprintType)
enum class EVGModifierOp : uint8
{
    Add,
    Multiply
};

USTRUCT(BlueprintType)
struct FVGStatModifier
{
    GENERATED_BODY()

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Modifier")
    EVGWeaponStat Stat = EVGWeaponStat::Damage;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Modifier")
    EVGModifierOp Op = EVGModifierOp::Multiply;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Modifier")
    float Value = 1.0f;
};

/** Um acessório (ou qualquer efeito) que altera estatísticas de arma. */
UCLASS(BlueprintType)
class VIGILIA_API UVGWeaponModifier : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Modifier")
    FText DisplayName;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Modifier")
    TArray<FVGStatModifier> Modifiers;

    /** efetivo = (base + Σ somas) × Π multiplicadores. Independe da ordem dos modificadores. */
    static FVGWeaponStats ComputeEffectiveStats(const FVGWeaponStats& Base,
                                                const TArray<const UVGWeaponModifier*>& Applied);
};
```

```cpp
// Source/Vigilia/Combat/VGWeaponModifier.cpp
#include "Combat/VGWeaponModifier.h"

FVGWeaponStats UVGWeaponModifier::ComputeEffectiveStats(const FVGWeaponStats& Base,
                                                        const TArray<const UVGWeaponModifier*>& Applied)
{
    FVGWeaponStats Result = Base;

    // Passada 1: somas. Passada 2: multiplicações. A ordem dos acessórios não importa.
    for (const EVGModifierOp Pass : { EVGModifierOp::Add, EVGModifierOp::Multiply })
    {
        for (const UVGWeaponModifier* Modifier : Applied)
        {
            if (!Modifier)
            {
                continue;
            }
            for (const FVGStatModifier& Mod : Modifier->Modifiers)
            {
                if (Mod.Op != Pass)
                {
                    continue;
                }
                float& Value = Result.GetMutable(Mod.Stat);
                Value = (Pass == EVGModifierOp::Add) ? Value + Mod.Value : Value * Mod.Value;
            }
        }
    }
    return Result;
}
```

### 3. O teste da agregação

```cpp
// Source/Vigilia/Tests/VGWeaponModifierTest.cpp
#include "Misc/AutomationTest.h"
#include "Combat/VGWeaponModifier.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGWeaponModifierOrderTest,
    "Vigilia.Combat.WeaponModifier.OrderIndependent",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGWeaponModifierOrderTest::RunTest(const FString& Parameters)
{
    auto Make = [](EVGModifierOp Op, float Value)
    {
        UVGWeaponModifier* Modifier = NewObject<UVGWeaponModifier>();
        FVGStatModifier Mod;
        Mod.Stat = EVGWeaponStat::Damage;
        Mod.Op = Op;
        Mod.Value = Value;
        Modifier->Modifiers.Add(Mod);
        return Modifier;
    };

    FVGWeaponStats Base;
    Base.Damage = 10.0f;
    const UVGWeaponModifier* Plus5 = Make(EVGModifierOp::Add, 5.0f);
    const UVGWeaponModifier* Times2 = Make(EVGModifierOp::Multiply, 2.0f);

    const float A = UVGWeaponModifier::ComputeEffectiveStats(Base, { Plus5, Times2 }).Damage;
    const float B = UVGWeaponModifier::ComputeEffectiveStats(Base, { Times2, Plus5 }).Damage;

    TestEqual(TEXT("(10 + 5) × 2 = 30"), A, 30.0f);
    TestEqual(TEXT("A ordem dos acessórios não importa"), B, A);
    TestEqual(TEXT("Sem modificadores, efetivo = base"),
              UVGWeaponModifier::ComputeEffectiveStats(Base, {}).Damage, 10.0f);
    return true;
}

#endif
```

### 4. A arma usa as estatísticas efetivas

🔁 Em `UVGWeaponData`, as propriedades numéricas do Capítulo 20 viram `FVGWeaponStats BaseStats` (mantendo `FireMode`, `ShotBufferTime`, `bAutoReloadWhenEmpty`, `DamageType` e `FireCameraShake`). Em `AVGWeapon`:

```cpp
// VGWeapon.h (adições)
public:
    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    const FVGWeaponStats& GetEffectiveStats() const { return EffectiveStats; }

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Weapon")
    void SetAttachments(const TArray<UVGWeaponModifier*>& NewAttachments);

protected:
    /** Acessórios equipados (configuráveis por instância/Blueprint). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Weapon")
    TArray<TObjectPtr<UVGWeaponModifier>> Attachments;

private:
    void RecomputeStats();

    FVGWeaponStats EffectiveStats;
```

```cpp
// VGWeapon.cpp (trechos)
void AVGWeapon::RecomputeStats()
{
    TArray<const UVGWeaponModifier*> Applied;
    for (const UVGWeaponModifier* Attachment : Attachments) { Applied.Add(Attachment); }
    EffectiveStats = UVGWeaponModifier::ComputeEffectiveStats(Data->BaseStats, Applied);

    // Invariante: o pente nunca excede a capacidade efetiva (um acessório pode ter sido removido).
    AmmoInMagazine = FMath::Min(AmmoInMagazine, EffectiveStats.GetMagazineSize());
    BroadcastAmmo();
}

void AVGWeapon::SetAttachments(const TArray<UVGWeaponModifier*>& NewAttachments)
{
    Attachments.Reset();
    for (UVGWeaponModifier* Attachment : NewAttachments) { Attachments.Add(Attachment); }
    RecomputeStats();
}

// BeginPlay: RecomputeStats() antes de encher o pente com EffectiveStats.GetMagazineSize().
// Em TODO o pipeline: Data->X → EffectiveStats.X
//   (GetFireInterval, ReloadTime, EquipTime, GetMagazineSize, Damage, Range)
```

### 5. Inventário e mira no componente

```cpp
// VGWeaponComponent.h (versão evoluída — trechos principais)
public:
    /** Adiciona a arma ao primeiro slot livre (ou substitui a atual se cheio). Equipa se for a primeira. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Weapon")
    AVGWeapon* GiveWeapon(TSubclassOf<AVGWeapon> WeaponClass);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Weapon")
    void EquipSlot(int32 SlotIndex);

    void EquipNext();
    void StartAim();
    void StopAim();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    float GetAimAlpha() const { return AimAlpha; }

    /** Dispersão atual (graus), interpolada entre quadril e mira pelo alfa. */
    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    float GetCurrentSpread() const;

    /** Multiplicadores para outros sistemas (câmera, movimento). 1.0 sem mira. */
    float GetFOVMultiplier() const;
    float GetMoveSpeedMultiplier() const;

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon", meta = (ClampMin = "1"))
    int32 MaxSlots = 2;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon")
    FTransform HipOffset = FTransform(FVector(35.0, 14.0, -14.0));

    /** Posição com a mira alinhada ao centro da tela. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon")
    FTransform AimOffset = FTransform(FVector(28.0, 0.0, -8.0));

public:
    UFUNCTION(BlueprintPure, Category = "Vigilia|Weapon")
    AVGWeapon* GetCurrentWeapon() const { return Slots.IsValidIndex(CurrentSlot) ? Slots[CurrentSlot].Get() : nullptr; }

private:
    void ApplyWeaponOffset();

    UPROPERTY(Transient)
    TArray<TObjectPtr<AVGWeapon>> Slots;

    int32 CurrentSlot = INDEX_NONE;
    bool bWantsToAim = false;
    float AimAlpha = 0.0f;
```

```cpp
// VGWeaponComponent.cpp (trechos principais)
void UVGWeaponComponent::EquipSlot(int32 SlotIndex)
{
    if (!Slots.IsValidIndex(SlotIndex) || SlotIndex == CurrentSlot)
    {
        return;
    }
    if (AVGWeapon* Current = GetCurrentWeapon())
    {
        Current->Holster(); // cancela recarga/equipar em andamento (Cap. 20)
    }
    bWantsToAim = false;    // trocar desfaz a mira
    AimAlpha = 0.0f;

    CurrentSlot = SlotIndex;
    Slots[CurrentSlot]->Equip();
    ApplyWeaponOffset();
    OnWeaponEquipped.Broadcast(Slots[CurrentSlot]);
}

void UVGWeaponComponent::EquipNext()
{
    if (Slots.Num() > 1)
    {
        EquipSlot((CurrentSlot + 1) % Slots.Num());
    }
}

void UVGWeaponComponent::StartAim() { bWantsToAim = true;  SetComponentTickEnabled(true); }
void UVGWeaponComponent::StopAim()  { bWantsToAim = false; SetComponentTickEnabled(true); }

void UVGWeaponComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                       FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    const AVGWeapon* Weapon = GetCurrentWeapon();
    const float AimTime = Weapon ? FMath::Max(Weapon->GetEffectiveStats().AimTime, 0.01f) : 0.2f;
    const bool bCanAim = bWantsToAim && Weapon && Weapon->GetWeaponState() == EVGWeaponState::Ready;

    const float Step = DeltaTime / AimTime; // progresso por tempo (Cap. 3)
    AimAlpha = FMath::Clamp(AimAlpha + (bCanAim ? Step : -Step), 0.0f, 1.0f);
    ApplyWeaponOffset();

    // Desliga só com o botão solto e a arma de volta ao quadril. Com o botão pressionado, o tick
    // continua: a arma pode sair de Ready (recarga) e voltar, e ninguém mais religaria o tick.
    if (!bWantsToAim && AimAlpha <= 0.0f)
    {
        SetComponentTickEnabled(false);
    }
}

void UVGWeaponComponent::ApplyWeaponOffset()
{
    if (AVGWeapon* Weapon = GetCurrentWeapon())
    {
        const float Shaped = FMath::SmoothStep(0.0f, 1.0f, AimAlpha);
        FTransform Blended;
        Blended.Blend(HipOffset, AimOffset, Shaped);
        Weapon->SetActorRelativeTransform(Blended);
    }
}

float UVGWeaponComponent::GetCurrentSpread() const
{
    const AVGWeapon* Weapon = GetCurrentWeapon();
    if (!Weapon)
    {
        return 0.0f;
    }
    const FVGWeaponStats& Stats = Weapon->GetEffectiveStats();
    return FMath::Lerp(Stats.HipSpread, Stats.AimSpread, AimAlpha);
}

float UVGWeaponComponent::GetFOVMultiplier() const
{
    const AVGWeapon* Weapon = GetCurrentWeapon();
    return Weapon ? FMath::Lerp(1.0f, Weapon->GetEffectiveStats().AimFOVMultiplier, AimAlpha) : 1.0f;
}

float UVGWeaponComponent::GetMoveSpeedMultiplier() const
{
    const AVGWeapon* Weapon = GetCurrentWeapon();
    return Weapon ? FMath::Lerp(1.0f, Weapon->GetEffectiveStats().AimMoveSpeedMultiplier, AimAlpha) : 1.0f;
}
```

### Explicação das decisões

- **O alfa de mira é do componente**, e as estatísticas de mira são da arma. Trocar de arma zera o alfa; a próxima arma traz o seu próprio `AimTime`.
- **Só se mira com a arma em `Ready`.** Durante a recarga ou o equipar, o alfa recua — e volta a avançar quando a arma fica pronta, se o botão continuar pressionado. Sem regra especial — desde que o tick não desligue no meio. A tentação é desligá-lo sempre que o alfa "assenta" (em 0 ou em 1); mas, assentado com o botão pressionado, o componente não percebe a recarga começar nem terminar, e a mira congela. Por isso o tick só desliga com o botão solto e o alfa em zero.
- **`FTransform::Blend` com `SmoothStep`** para a posição da arma: o movimento acelera e desacelera, sem um salto no início ou no fim.
- **Outros sistemas consultam** (`GetFOVMultiplier`, `GetMoveSpeedMultiplier`): o modificador de câmera multiplica o FOV; o personagem multiplica `MaxWalkSpeed` (no `UpdateSprint`, que passa a se chamar com mais propriedade `UpdateMoveSpeed`). O componente de armas não conhece a câmera nem o movimento — eles conhecem o componente.
- **Corrida e mira se cancelam**: `StartAim` também pede ao personagem que pare de correr; `HandleSprintStarted` chama `StopAim`. A regra mora no personagem, que é dono da corrida — e conhece o componente de armas, não o contrário.

### 6. Input

Novas ações: `IA_Aim` (botão direito / gatilho esquerdo; `Started` → `StartAim`, `Completed` → `StopAim`) e `IA_SwitchWeapon` (roda do mouse / botão Y; `Started` → `EquipNext`). Para quem prefere **alternar** a mira em vez de segurar, um trigger diferente no mapeamento resolve — mais uma vez, configuração, não código.

---

## Projeto 2 — o Galpão ganha acessórios

1. Converta `DA_Pistola`, `DA_Fuzil` e `DA_Sinalizador` para `BaseStats`.
2. Crie três acessórios de teste: `DA_Acc_CanoLongo` (alcance ×1,3; `AimTime` ×1,15), `DA_Acc_PenteEstendido` (pente +10; `ReloadTime` ×1,2) e `DA_Acc_MiraRapida` (`AimTime` ×0,7; `AimFOVMultiplier` +0,05).
3. Uma bancada interativa (`BP_Bancada`, filho de `AVGPickup` sem consumo) que alterna os acessórios do fuzil e mostra as estatísticas efetivas na tela.
4. Mira com a arma em todas as armas, com FOV e posição interpolados.
5. Dois slots: pistola e fuzil no Galpão; na Vigília, sinalizador e (mais tarde) a pistola dos vigias.

---

## Decisões arquiteturais

1. **Estatísticas base no Data Asset; efetivas calculadas na arma; o pipeline só lê as efetivas.**
2. **`efetivo = (base + Σ somas) × Π multiplicadores`**, independente da ordem, numa função pura testada.
3. **Acessórios (e outros efeitos) são `UVGWeaponModifier`** — Data Assets com operações.
4. **Inventário de atores em slots**, com regras de troca explícitas; armas inativas preservam estado.
5. **Alfa de mira contínuo no componente de armas**; câmera e movimento consultam multiplicadores.
6. **Corrida e mira se cancelam; a regra mora no personagem.**

---

## Armadilhas

- **Pipeline lendo estatísticas base** em algum lugar esquecido — o acessório "não funciona" só naquela parte.
- **Ordem de modificadores dependente da ordem de equipar.**
- **Pente acima da capacidade** depois de remover um pente estendido.
- **Mira como booleano** — transições bruscas de FOV e dispersão.
- **O componente de armas mexendo na câmera ou no CMC diretamente.**
- **Destruir armas ao trocar** e perder a munição.

---

## Exercício

**Parte 1 — estatísticas e modificadores (1,5 h).** Implemente `FVGWeaponStats`, `UVGWeaponModifier`, o teste e a refatoração da arma. Verifique, com um cheat que imprime as estatísticas efetivas, que equipar acessórios em ordens diferentes produz o mesmo resultado.

**Parte 2 — inventário (1 h).** Evolua o `UVGWeaponComponent` para slots, com `EquipSlot`, `EquipNext` e as regras de troca. Teste trocar durante a recarga e durante o equipar.

**Parte 3 — mira (1,5 h).** Implemente o alfa de mira, a posição interpolada, o FOV no modificador de câmera e a redução de velocidade. Teste a interação com a corrida. Ajuste `AimTime` até a mira parecer "pesada" no fuzil e "ágil" na pistola.

**Parte 4 — bancada (45 min).** Monte a bancada de acessórios no Galpão.

---

## Desafio — modificadores de estado

Use o mesmo pipeline para um efeito que **não é acessório**: quando a jogadora estiver com vida abaixo de 50% (Capítulo 22), as armas ganham "mãos trêmulas": `HipSpread` ×1,5 e `AimTime` ×1,3.

1. A arma passa a combinar **duas listas**: acessórios (da arma) e **modificadores de portador** (fornecidos pelo componente de armas, a partir do estado do personagem).
2. O componente de armas escuta `OnHealthChanged` do `UVGHealthComponent` e, nas transições através do limiar de 50% (com histerese, Capítulo 4), adiciona ou remove o modificador e pede à arma que recalcule.

Pergunta para o `DEVLOG.md`: onde deveria morar a regra "vida baixa → mãos trêmulas" — no componente de vida, no de armas, no personagem, num Data Asset? Qual escolha respeita melhor "quem conhece quem" (Capítulo 24)?

---

## Uso de IA

1. **Para validar a agregação:**
   > "Tenho estatísticas de arma calculadas como efetivo = (base + soma das somas) × produto dos multiplicadores. Demonstre que o resultado independe da ordem dos modificadores, mostre um contraexemplo de por que aplicar na ordem de equipar quebraria isso, e discuta casos-limite (multiplicador zero, somas negativas, estatísticas que precisam de mínimo e máximo)."

2. **Para design de customização:**
   > "Proponha 8 acessórios para um fuzil num shooter de teste, cada um com uma vantagem e uma desvantagem expressas como modificadores sobre: dano, cadência, pente, recarga, alcance, dispersão do quadril, dispersão mirando, tempo de mira, FOV de mira e velocidade mirando. Explique a decisão tática que cada um cria."

3. **Para revisar o ADS:**
   > "Revise esta implementação de mira com a arma (aim down sights) na Unreal Engine 5: alfa contínuo, posição interpolada, FOV via modificador de câmera, velocidade reduzida, cancelamento com a corrida e comportamento durante recarga e troca. Aponte estados inconsistentes possíveis. [código]"

---

## Checklist

- [ ] Sei separar estatísticas base e efetivas e garantir que o pipeline use só as efetivas.
- [ ] Implementei e testei a agregação de modificadores independente da ordem.
- [ ] Implementei acessórios como Data Assets de modificadores.
- [ ] Implementei inventário com slots e regras de troca explícitas.
- [ ] Implementei mira contínua (alfa) afetando dispersão, FOV, posição e velocidade.
- [ ] Sei quem é dono de cada estado do sistema de armas e quem consulta quem.

---

## Para ir além

- **GDC Vault** (gdcvault.com) — busque talks sobre sistemas de customização de armas e balanceamento em shooters.
- **Lyra Starter Game** — o sistema de armas da Lyra (com instâncias de equipamento e fragmentos de item) é uma referência de inventário e equipamento em um projeto maior.

---

➡️ **Próximo:** [Capítulo 27 — Hitscan](cap-27-hitscan.md)

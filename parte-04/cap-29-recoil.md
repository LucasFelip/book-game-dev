# Capítulo 29 — Recoil

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir as cinco "imprecisões" de uma arma — **recuo** (*recoil*), **dispersão**, **florescimento** (*bloom*), **coice visual** e **balanço** (*sway*) — e o papel de design de cada uma;
- implementar recuo de câmera como **impulso aplicado ao longo do tempo**, com **recuperação** que respeita a compensação do próprio jogador;
- escolher entre recuo **aleatório** e **padronizado** (aprendível), e entender o que cada um faz com a habilidade e a legibilidade;
- implementar o **florescimento** como dispersão que cresce com o disparo contínuo e decai com o tempo;
- dar à arma um **coice visual** e um **balanço** discretos, coerentes com o feedback do Capítulo 5.

---

## Contexto

O Galpão de Testes agora tem armas com cadência correta, dispersão em camadas, materiais, penetração, projéteis e um sinalizador. Atire uma rajada longa com o fuzil, porém, e algo está errado: a mira fica **parada**. Todos os tiros saem do mesmo centro de tela, com o mesmo cone. A arma não "reage" ao disparo — e, por isso, parece leve, sem força, e uma rajada de 30 tiros é tão precisa quanto o primeiro.

Recuo é a resposta, e ele cumpre dois papéis ao mesmo tempo:

- **Feedback** (Capítulo 5): comunica força, peso e cadência. Uma arma potente "chuta".
- **Mecânica**: cria um custo para o disparo contínuo e um eixo de habilidade (controlar a arma).

Na Vigília, o sinalizador tem um único disparo forte, com um coice marcante; os vigias têm pistolas. No Galpão, o fuzil é o laboratório.

---

## 29.1 As cinco imprecisões

| Efeito | O que é | O que o jogador sente | Ele pode controlar? |
|---|---|---|---|
| **Recuo (recoil)** | A **mira** (control rotation) é empurrada a cada disparo | "A arma sobe" | **Sim** — compensando com o mouse/analógico |
| **Dispersão (spread)** | Cada disparo sai num cone em volta da mira (Capítulo 27) | "Os tiros se espalham" | Indiretamente (parar, mirar, agachar) |
| **Florescimento (bloom)** | A dispersão **cresce** com disparos seguidos e decai com o tempo | "Atirar sem parar piora a precisão" | Sim — rajadas curtas |
| **Coice visual (kick)** | A **arma** (o modelo) recua e gira, e volta | "Força, peso" | Não — é só apresentação |
| **Balanço (sway)** | A arma oscila ao respirar e ao se mover | "Há mãos segurando isto" | Não — é apresentação (ou, mirando, pode afetar levemente) |

A distinção mais importante é entre **recuo** e **dispersão**: o recuo move a mira — e o jogador vê para onde ela foi e pode corrigir —; a dispersão é aleatória em torno da mira e o jogador não pode corrigir tiro a tiro. Um shooter que premia habilidade tende a ter **mais recuo controlável e menos dispersão aleatória**; um que premia posicionamento e decisão, o contrário.

---

## 29.2 Recuo como impulso ao longo do tempo

A implementação ingênua de recuo é somar alguns graus de *pitch* à mira a cada disparo, instantaneamente. O resultado é uma câmera que "pula" em degraus — mecânica, sem peso. O recuo bom é um **impulso**: cada disparo adiciona um "recuo pendente", e a mira se move suavemente em direção a ele ao longo de alguns frames (decaimento exponencial, Capítulo 3):

```text
disparo:   pendente += chute (vertical ↑, horizontal ±)
cada frame:
   aplicar = pendente × α(taxa, Δt)       ← parte do pendente vira movimento da mira
   pendente −= aplicar
   mira += aplicar;  deslocamento_acumulado += aplicar
```

O `deslocamento_acumulado` é **quanto o recuo empurrou a mira**, e ele é a base da recuperação.

### Recuperação

Quando o jogador para de atirar, muitas armas **voltam** parcialmente em direção ao ponto de origem — a recuperação. Ela não pode simplesmente desfazer o `deslocamento_acumulado`: se o jogador já **compensou** o recuo puxando a mira para baixo durante a rajada, desfazer o recuo inteiro jogaria a mira **abaixo** do alvo (*overcorrection*), punindo exatamente quem controlou bem a arma.

A regra correta: **a compensação do jogador consome o deslocamento acumulado.** Se o recuo subiu a mira 6° e o jogador puxou 4° para baixo, restam 2° a recuperar.

```text
 recuo acumulado:     ↑ 6°
 jogador compensou:   ↓ 4°   → acumulado restante: ↑ 2°
 recuperação:         desfaz só os 2° restantes
```

Para medir a compensação, o componente de recuo compara, a cada frame, a mudança total da mira com a parte que **ele próprio** aplicou: a diferença foi o jogador. Se essa diferença tem sentido oposto ao acumulado, ela o reduz.

> 🌉 **Ponte:** é a lógica de um **controlador** que separa a própria contribuição de perturbações externas — como um autoscaler que não deve "desfazer" uma mudança manual de réplicas feita por um operador. O recuo só desfaz o que ele mesmo fez e que ainda não foi corrigido.

---

## 29.3 Aleatório ou padronizado?

| | Recuo aleatório | Recuo padronizado |
|---|---|---|
| Cada rajada | Diferente | Igual (o *n*-ésimo disparo sempre chuta igual) |
| Aprendível | Não | **Sim** — o jogador memoriza e compensa |
| Eixo de habilidade | Reação | Memória muscular + reação |
| Legibilidade | Baixa | Alta |
| Risco | Parecer injusto | Ficar "resolvido" por quem treina |

**[INFERÊNCIA]** Shooters competitivos tendem a usar recuo **total ou parcialmente padronizado** — uma componente previsível (a "forma" da rajada) somada a uma componente aleatória pequena —, porque isso transforma o controle da arma numa habilidade treinável, e jogadores dessas comunidades frequentemente estudam e discutem os padrões de cada arma. Jogos menos competitivos tendem a usar recuo mais aleatório e suave.

Para o projeto: o fuzil do Galpão tem um **padrão** (uma curva de chute por índice do disparo, com um pouco de aleatoriedade horizontal); a pistola e o sinalizador, recuo simples (um chute vertical por disparo). O índice do disparo **reinicia** depois de uma pausa curta sem atirar.

---

## 29.4 Florescimento

O florescimento é **dispersão que depende do histórico**: cada disparo soma um pouco ao raio do cone, até um máximo; sem disparar, ele decai. É uma realimentação (Capítulo 5) que pune o "spray" e premia rajadas curtas e controladas.

```text
 dispersão efetiva = base (quadril↔mira) + movimento + ar + bloom
 bloom: + por disparo (até um teto), − por segundo sem atirar
```

O florescimento entra exatamente no ponto que o Capítulo 27 preparou: a dispersão **externa** que o portador fornece à arma (`SetExternalSpread`).

---

## 29.5 Coice visual e balanço

O **coice visual** é apresentação pura: a arma recua alguns centímetros e gira alguns graus para cima a cada disparo, e volta suavemente. Ele **não** altera a mira — mas é o que faz o recuo de câmera parecer causado pela arma, e não pela câmera. Sem coice visual, o recuo de câmera parece que "alguém empurrou a cabeça".

O **balanço** dá vida à arma parada (uma oscilação lenta, como respiração) e em movimento (oscilação ligada à passada, como o *head bob* do Capítulo 18). Ao mirar, o balanço diminui muito. Em jogos táticos, o balanço ao mirar às vezes afeta a precisão — em jogos de ação, raramente.

Ambos vivem no **componente de armas**, que já é dono da posição da arma (`ApplyWeaponOffset`, Capítulo 26): o deslocamento final da arma passa a ser *posição de mira* + *coice* + *balanço*.

---

## Estudo de caso: recuo como linguagem

> **Pergunta:** por que duas armas com o mesmo dano e a mesma cadência podem parecer completamente diferentes?

**[FATO PÚBLICO]** *Call of Duty: Modern Warfare* (2019) foi amplamente elogiado na época do lançamento, por críticos e jogadores, pela **sensação das armas** — com destaque recorrente para o **design de som** dos disparos e para a resposta visual das armas. Em comunidades de shooters, a "sensação" (*gun feel*) de uma arma é um dos critérios mais discutidos, frequentemente separado das estatísticas.

**[INFERÊNCIA]** A "sensação" de uma arma é a soma coordenada de camadas que este livro tratou separadamente: o **som** do disparo e sua cauda no ambiente (Capítulo 52), o **coice visual** e a animação da arma, o **recuo de câmera** com recuperação, o **tremor** de câmera (Capítulo 18), o *muzzle flash* e os efeitos de impacto (Capítulos 27 e 54), o *hit marker* (Capítulo 27). Duas armas com estatísticas idênticas, mas com camadas diferentes — um chute curto e seco contra um empurrão longo; um estampido agudo contra um estrondo grave —, comunicam armas diferentes. As estatísticas definem o que a arma **faz**; as camadas de feedback definem o que ela **é** para o jogador. Nenhuma afirmação é feita sobre como esse jogo implementa nada disso.

**Lição:** **recuo é metade mecânica, metade linguagem.** Ajustá-lo só pelos números de precisão perde metade do seu valor. Ajuste o recuo **junto** com o som, o coice e o tremor, como uma única peça de feedback.

---

## Comparação com o desenvolvimento tradicional

| Recuo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Recuo pendente com decaimento | Suavização de um sinal de controle | O "sinal" é sentido pela mão do jogador |
| Recuperação que respeita compensação | Controlador que não desfaz intervenção manual | Precisa separar, a cada frame, a própria contribuição |
| Florescimento | Penalidade por uso contínuo (*rate limiting* suave) | É um eixo de habilidade, não uma proteção |
| Padrão de recuo | Comportamento determinístico documentado | Aprendê-lo é **parte do jogo** |

---

## Implementação

### 1. Dados

Em `UVGWeaponData`, os parâmetros de recuo que não são modificáveis por acessórios (os modificáveis — `RecoilVertical`, `RecoilHorizontal` — já estão em `FVGWeaponStats`, Capítulo 26):

```cpp
    /** Padrão opcional por índice do disparo na rajada: X = yaw, Y = pitch, em múltiplos de
        RecoilHorizontal/RecoilVertical efetivos (1 = um chute base). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Recoil")
    TObjectPtr<UCurveVector> RecoilPattern;

    /** Quão rápido o recuo pendente é aplicado à mira (1/s). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Recoil", meta = (ClampMin = "0.0"))
    float RecoilApplyRate = 25.0f;

    /** Quão rápido a mira volta depois da rajada (1/s). 0 = sem recuperação. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Recoil", meta = (ClampMin = "0.0"))
    float RecoilRecoveryRate = 6.0f;

    /** Tempo sem atirar até a recuperação começar e o índice do padrão reiniciar (s). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Recoil", meta = (ClampMin = "0.0"))
    float RecoilResetTime = 0.25f;

    /** Fator de recuo mirando (multiplica o chute com alfa de mira = 1). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Recoil", meta = (ClampMin = "0.0"))
    float AimRecoilScale = 0.6f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Bloom", meta = (ClampMin = "0.0"))
    float BloomPerShot = 0.35f;     // graus

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Bloom", meta = (ClampMin = "0.0"))
    float MaxBloom = 3.0f;          // graus

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Bloom", meta = (ClampMin = "0.0"))
    float BloomRecoveryPerSecond = 4.0f;
```

### 2. O componente de recuo

```cpp
// Source/Vigilia/Combat/VGRecoilComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGRecoilComponent.generated.h"

class AVGWeapon;
class UVGWeaponComponent;

/**
 * Recuo de mira e florescimento da arma atual. Aplica o recuo à control rotation ao longo do tempo,
 * recupera depois da rajada e não desfaz a compensação feita pelo jogador.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGRecoilComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGRecoilComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    /** Dispersão extra (graus) pelo florescimento atual. */
    UFUNCTION(BlueprintPure, Category = "Vigilia|Recoil")
    float GetBloom() const { return Bloom; }

protected:
    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleWeaponEquipped(AVGWeapon* Weapon);

    UFUNCTION()
    void HandleWeaponFired(AVGWeapon* Weapon);

    AController* GetOwnerController() const;

    UPROPERTY(Transient)
    TObjectPtr<UVGWeaponComponent> WeaponComponent;

    UPROPERTY(Transient)
    TObjectPtr<AVGWeapon> BoundWeapon;

    FVector2D PendingKick = FVector2D::ZeroVector;   // X = yaw, Y = pitch (graus)
    FVector2D Accumulated = FVector2D::ZeroVector;   // quanto o recuo empurrou a mira e ainda não foi corrigido
    FRotator LastControlRotation = FRotator::ZeroRotator;
    FVector2D LastApplied = FVector2D::ZeroVector;

    float Bloom = 0.0f;
    float LastShotTime = -100.0f;
    int32 ShotIndex = 0;
    int32 RecoilSeed = 0;
};
```

```cpp
// Source/Vigilia/Combat/VGRecoilComponent.cpp
#include "Combat/VGRecoilComponent.h"

#include "Combat/VGWeapon.h"
#include "Combat/VGWeaponComponent.h"
#include "Combat/VGWeaponData.h"
#include "Core/VGMathUtils.h"
#include "Curves/CurveVector.h"
#include "GameFramework/Controller.h"
#include "GameFramework/Pawn.h"

UVGRecoilComponent::UVGRecoilComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false;
    // Depois do input (TG_PrePhysics padrão do personagem) e antes da câmera final do frame.
    PrimaryComponentTick.TickGroup = TG_PostPhysics;
}

void UVGRecoilComponent::BeginPlay()
{
    Super::BeginPlay();
    WeaponComponent = GetOwner()->FindComponentByClass<UVGWeaponComponent>();
    if (WeaponComponent)
    {
        WeaponComponent->OnWeaponEquipped.AddDynamic(this, &UVGRecoilComponent::HandleWeaponEquipped);
        HandleWeaponEquipped(WeaponComponent->GetCurrentWeapon());
    }
}

AController* UVGRecoilComponent::GetOwnerController() const
{
    const APawn* Pawn = Cast<APawn>(GetOwner());
    return Pawn ? Pawn->GetController() : nullptr;
}

void UVGRecoilComponent::HandleWeaponEquipped(AVGWeapon* Weapon)
{
    if (BoundWeapon)
    {
        BoundWeapon->OnFired.RemoveDynamic(this, &UVGRecoilComponent::HandleWeaponFired);
    }
    BoundWeapon = Weapon;
    if (BoundWeapon)
    {
        BoundWeapon->OnFired.AddDynamic(this, &UVGRecoilComponent::HandleWeaponFired);
    }
    // Trocar de arma zera o histórico da rajada (o florescimento também).
    PendingKick = Accumulated = FVector2D::ZeroVector;
    Bloom = 0.0f;
    ShotIndex = 0;
}

void UVGRecoilComponent::HandleWeaponFired(AVGWeapon* Weapon)
{
    const UVGWeaponData* Data = Weapon->GetWeaponData();
    const FVGWeaponStats& Stats = Weapon->GetEffectiveStats();
    const float Now = GetWorld()->GetTimeSeconds();

    if (Now - LastShotTime > Data->RecoilResetTime)
    {
        ShotIndex = 0; // pausa curta: nova rajada, o padrão recomeça
    }
    LastShotTime = Now;

    // Semente misturada, pelo mesmo motivo da dispersão (Cap. 27): sementes consecutivas cruas
    // fariam o chute horizontal "andar" em dente-de-serra, disparo após disparo.
    const FRandomStream Stream(static_cast<int32>(HashCombine(GetUniqueID(), static_cast<uint32>(RecoilSeed++))));
    const float RandomYaw = Stream.FRandRange(-1.0f, 1.0f);

    FVector2D Kick;
    if (Data->RecoilPattern)
    {
        // A curva dá a FORMA da rajada, em múltiplos do chute base; as estatísticas EFETIVAS dão a
        // escala — assim os acessórios (Cap. 26) também valem para armas com padrão.
        const FVector Pattern = Data->RecoilPattern->GetVectorValue(static_cast<float>(ShotIndex));
        Kick = FVector2D((Pattern.X + 0.25f * RandomYaw) * Stats.RecoilHorizontal, // + um pouco de acaso no yaw
                         Pattern.Y * Stats.RecoilVertical);
    }
    else
    {
        Kick = FVector2D(RandomYaw * Stats.RecoilHorizontal, Stats.RecoilVertical);
    }
    ++ShotIndex;

    const float AimAlpha = WeaponComponent ? WeaponComponent->GetAimAlpha() : 0.0f;
    PendingKick += Kick * FMath::Lerp(1.0f, Data->AimRecoilScale, AimAlpha);

    Bloom = FMath::Min(Bloom + Data->BloomPerShot, Data->MaxBloom);

    if (AController* Controller = GetOwnerController())
    {
        if (!IsComponentTickEnabled())
        {
            LastControlRotation = Controller->GetControlRotation();
            LastApplied = FVector2D::ZeroVector;
        }
    }
    SetComponentTickEnabled(true);
}

void UVGRecoilComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                       FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    AController* Controller = GetOwnerController();
    const UVGWeaponData* Data = BoundWeapon ? BoundWeapon->GetWeaponData() : nullptr;
    if (!Controller || !Data)
    {
        SetComponentTickEnabled(false);
        return;
    }

    // 1. Quanto a mira mudou desde o último frame além do que o recuo aplicou? Foi o jogador.
    const FRotator Current = Controller->GetControlRotation();
    const FRotator Delta = (Current - LastControlRotation).GetNormalized();
    const FVector2D PlayerDelta(Delta.Yaw - LastApplied.X, Delta.Pitch - LastApplied.Y);

    // Compensação no sentido oposto ao acumulado consome o acumulado (sem passar de zero).
    auto Consume = [](float& Acc, float PlayerMove)
    {
        if (Acc * PlayerMove < 0.0f)
        {
            const float Amount = FMath::Min(FMath::Abs(PlayerMove), FMath::Abs(Acc));
            Acc -= FMath::Sign(Acc) * Amount;
        }
    };
    Consume(Accumulated.X, PlayerDelta.X);
    Consume(Accumulated.Y, PlayerDelta.Y);

    // 2. Aplicar parte do recuo pendente.
    FVector2D Apply = PendingKick * VGMath::ExpDecayAlpha(Data->RecoilApplyRate, DeltaTime);
    PendingKick -= Apply;
    Accumulated += Apply;

    // 3. Recuperação: depois da pausa, desfazer o que restou do acumulado.
    const bool bRecovering = (GetWorld()->GetTimeSeconds() - LastShotTime) > Data->RecoilResetTime;
    if (bRecovering && Data->RecoilRecoveryRate > 0.0f)
    {
        const FVector2D Recover = Accumulated * VGMath::ExpDecayAlpha(Data->RecoilRecoveryRate, DeltaTime);
        Accumulated -= Recover;
        Apply -= Recover;
    }

    // 4. Florescimento decai com o tempo.
    Bloom = FMath::Max(Bloom - Data->BloomRecoveryPerSecond * DeltaTime, 0.0f);

    const FRotator NewRotation = Current + FRotator(Apply.Y, Apply.X, 0.0f); // Pitch positivo = para cima
    Controller->SetControlRotation(NewRotation);
    // Referência ANTES do recuo deste frame: no próximo tick, (Current − LastControlRotation)
    // = recuo aplicado agora + movimento do jogador; subtraindo LastApplied, sobra só o jogador.
    // (Guardar NewRotation aqui contaria o recuo duas vezes: ele seria lido como compensação.)
    LastControlRotation = Current;
    LastApplied = Apply;

    const bool bSettled = PendingKick.IsNearlyZero(0.01f) && Accumulated.IsNearlyZero(0.01f) && Bloom <= 0.0f;
    if (bSettled)
    {
        SetComponentTickEnabled(false);
    }
}
```

### Explicação das decisões

- **Um componente próprio**, separado do de armas: recuo mexe na **mira** (do controller) e tem um ciclo próprio (pendente, acumulado, recuperação). O componente de armas continua dono de "qual arma" e "como ela é segurada".
- **Rebind ao trocar de arma** (`OnWeaponEquipped`), com desinscrição da arma anterior (Capítulo 24) e histórico zerado.
- **Separação da contribuição do jogador**: `PlayerDelta = mudança total − o que o recuo aplicou no frame anterior`. Para isso a referência (`LastControlRotation`) é a rotação **antes** de aplicar o recuo; se fosse a rotação já com o recuo, ele seria descontado duas vezes, o próprio coice pareceria compensação e a recuperação sumiria. Só a compensação **no sentido oposto** ao acumulado o reduz — mover a mira a favor do recuo não "rouba" recuperação.
- **Recuperação só do que restou**, depois de `RecoilResetTime`. Quem compensou bem não é jogado para baixo do alvo.
- **`SetControlRotation` direto** em vez de `AddControllerPitchInput`: o recuo é em graus, e passar pelas escalas de input (Capítulo 14) o tornaria dependente da sensibilidade do jogador. O limite de *pitch* do camera manager continua valendo.
- **`TG_PostPhysics`**: o recuo é aplicado depois de o personagem processar o input do frame, para que a medição da compensação do jogador inclua o movimento do mouse **deste** frame.
- **Tick só enquanto há algo a fazer**, desligado quando tudo assentou.
- **Semente própria** para a componente aleatória, como a dispersão (Capítulo 27).

### 3. Florescimento na dispersão

No `UVGWeaponComponent`, a dispersão externa passa a ser `GetCurrentSpread() + Recoil->GetBloom()` — o componente de armas procura o de recuo no `BeginPlay` (dependência opcional, Capítulo 9). O Capítulo 27 já fazia a arma somar a dispersão externa com as penalidades de movimento e de ar.

### 4. Coice visual e balanço

No `UVGWeaponComponent`, a posição final da arma passa a ser a mistura quadril↔mira (Capítulo 26) **mais** um coice que decai e **mais** um balanço:

```cpp
// VGWeaponComponent.cpp — trechos
void UVGWeaponComponent::HandleCurrentWeaponFired(AVGWeapon* Weapon)
{
    // Coice: recua e gira para cima; decai no tick.
    KickOffset += FVector(-KickBack, 0.0, 0.0);
    KickPitch += KickRotationDegrees;
    SetComponentTickEnabled(true);
}

void UVGWeaponComponent::ApplyWeaponOffset(float DeltaTime)
{
    KickOffset = VGMath::ExpDecayTo(KickOffset, FVector::ZeroVector, KickRecoveryRate, DeltaTime);
    KickPitch = VGMath::ExpDecayTo(KickPitch, 0.0f, KickRecoveryRate, DeltaTime);

    // Balanço lento ("respiração"), reduzido ao mirar.
    SwayTime += DeltaTime;
    const float SwayScale = FMath::Lerp(1.0f, AimSwayScale, AimAlpha);
    const FVector Sway(0.0, FMath::Sin(SwayTime * 1.1f) * SwayAmplitude, FMath::Sin(SwayTime * 2.2f) * SwayAmplitude * 0.5f);

    FTransform Blended;
    Blended.Blend(HipOffset, AimOffset, FMath::SmoothStep(0.0f, 1.0f, AimAlpha));
    Blended.AddToTranslation(KickOffset + Sway * SwayScale);
    Blended.ConcatenateRotation(FRotator(KickPitch, 0.0, 0.0).Quaternion());

    if (AVGWeapon* Weapon = GetCurrentWeapon())
    {
        Weapon->SetActorRelativeTransform(Blended);
    }
}
```

Com o balanço contínuo, o tick do componente de armas passa a ficar ligado sempre que houver arma equipada (o custo é pequeno: uma única arma). Os parâmetros (`KickBack`, `KickRotationDegrees`, `KickRecoveryRate`, `SwayAmplitude`, `AimSwayScale`) são propriedades editáveis — ou, melhor, campos de apresentação no Blueprint da arma, lidos pelo componente. A escolha fica registrada no `DEVLOG.md`. O balanço respeita `vg.Camera.Motion` (Capítulo 18).

---

## Projeto 2 — armas com peso

1. **Fuzil:** padrão de recuo (`CV_Recuo_Fuzil`, uma curva vetorial com subida vertical constante e um desvio horizontal que muda de lado por volta do 10º disparo), florescimento moderado, recuperação média.
2. **Pistola:** chute vertical forte por disparo, sem padrão, recuperação rápida.
3. **Sinalizador:** chute vertical grande e lento, coice visual marcado, sem florescimento (um disparo).
4. **Escopeta:** chute grande, recuperação lenta.
5. Ajuste **som, coice, recuo e tremor juntos** para cada arma, como uma única peça de feedback (estudo de caso).

---

## Decisões arquiteturais

1. **Cinco imprecisões distintas**: recuo (mira), dispersão (cone), florescimento (histórico), coice e balanço (apresentação).
2. **Recuo como impulso pendente aplicado por decaimento exponencial**, com recuperação depois de uma pausa.
3. **A recuperação não desfaz a compensação do jogador.**
4. **Padrão de recuo opcional por curva**; índice reinicia após pausa; componente aleatória com semente.
5. **`UVGRecoilComponent` separado**, reagindo ao `OnFired` da arma atual; `SetControlRotation` em graus.
6. **Florescimento soma-se à dispersão externa**; coice e balanço na posição da arma, no componente de armas.

---

## Armadilhas

- **Recuo instantâneo** — a câmera "pula" em degraus.
- **Recuperação que desfaz tudo** — joga a mira abaixo do alvo de quem compensou.
- **Recuo via `AddControllerPitchInput`** — dependente da sensibilidade.
- **Esquecer de desinscrever** o `OnFired` da arma anterior.
- **Padrão que não reinicia** — a 30ª bala de uma rajada nova chuta como a 30ª da anterior.
- **Ajustar recuo isolado** de som, coice e tremor.
- **Balanço que ignora a opção de reduzir movimento de câmera.**

---

## Exercício

**Parte 1 — recuo (2 h).** Implemente os dados, o `UVGRecoilComponent` e a integração do florescimento. Teste: rajada longa sem compensar (a mira sobe e depois volta), rajada compensando (a mira não é jogada para baixo ao parar), trocar de arma no meio da rajada.

**Parte 2 — padrão (1 h).** Crie `CV_Recuo_Fuzil` e desenhe, num alvo grande do Galpão, o padrão de impactos de uma rajada de 30 tiros sem compensar. Depois, tente compensar o padrão. Em quantas tentativas você "aprendeu" a arma?

**Parte 3 — coice e balanço (1 h).** Implemente coice visual e balanço. Desligue o coice e mantenha o recuo de câmera: descreva a sensação. Depois o inverso.

**Parte 4 — a peça inteira (1 h).** Para o sinalizador, ajuste som (placeholder), coice, recuo, tremor de câmera e flash até que um disparo pareça **pesado e precioso**. Registre os valores finais.

---

## Desafio — recuo e postura

Faça a postura afetar o recuo, como em muitos shooters táticos:

1. Agachada: recuo ×0,8 e florescimento ×0,8.
2. Em movimento: recuo ×1,15.
3. Implemente como **modificadores de portador** (o desafio do Capítulo 26), e não como `if`s no componente de recuo: o componente de armas fornece à arma modificadores conforme as tags de status da jogadora (`Status.Movement.Crouched`, Capítulo 23).

Pergunta para o `DEVLOG.md`: agora há três sistemas que influenciam a precisão (estatísticas da arma, modificadores de portador, componente de recuo). Desenhe o fluxo de dados entre eles. Há alguma informação calculada em dois lugares? *(Se houver, escolha um dono.)*

---

## Uso de IA

1. **Para revisar a matemática do recuo:**
   > "Revise este componente de recuo: recuo pendente aplicado por decaimento exponencial, acumulado, separação da compensação do jogador pela diferença entre a mudança total da control rotation e a parte aplicada pelo recuo, e recuperação do acumulado restante. Encontre casos em que a recuperação pune a compensação, em que o yaw dá a volta (359° → 0°) e em que o frame rate altera o resultado. [código]"

2. **Para desenhar padrões:**
   > "Proponha três padrões de recuo (curvas de yaw/pitch por índice do disparo) para: um fuzil fácil de controlar, um fuzil de alta cadência difícil e uma submetralhadora. Para cada um, descreva a habilidade que ele exige e como o jogador perceberia o aprendizado."

3. **Para pensar em gun feel:**
   > "Liste as camadas de feedback que compõem a sensação de uma arma em primeira pessoa (som, coice, recuo, tremor, flash, impacto, hit marker). Para cada uma, diga que parâmetros a definem e como ajustar duas armas com as mesmas estatísticas para que pareçam diferentes."

---

## Checklist

- [ ] Sei distinguir recuo, dispersão, florescimento, coice visual e balanço.
- [ ] Implementei recuo como impulso com recuperação que respeita a compensação do jogador.
- [ ] Implementei padrão de recuo opcional com reinício após pausa.
- [ ] Implementei florescimento somado à dispersão.
- [ ] Implementei coice visual e balanço discretos e acessíveis.
- [ ] Ajustei cada arma como uma peça única de feedback.

---

## Para ir além

- **GDC Vault** (gdcvault.com) — busque talks sobre *gun feel*, *weapon feedback* e design de som de armas em shooters.
- **Steve Swink, *Game Feel*** — os capítulos sobre "polish" e camadas de resposta.

---

➡️ **Próximo:** [Capítulo 30 — Enemy](cap-30-enemy.md)

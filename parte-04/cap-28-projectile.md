# Capítulo 28 — Projectile

## Objetivo

Ao final deste capítulo você deve conseguir:

- implementar **projéteis** como atores com o `ProjectileMovementComponent`: velocidade, gravidade, quique, orientação e tempo de vida;
- lançar projéteis **do cano em direção ao ponto mirado**, mantendo a mira honesta;
- tratar colisão de projéteis rápidos (*tunneling*), o próprio atirador e superfícies diferentes;
- integrar projéteis ao **mesmo pipeline de armas** do Capítulo 20, escolhendo hitscan ou projétil por dados;
- construir o **sinalizador** da Vigília: um projétil que quica, queima, ilumina, cria uma zona segura temporária e repele a Presença;
- entender o custo de projéteis em escala e quando usar outra abordagem.

---

## Contexto

O Capítulo 27 resolveu o disparo instantâneo. Muitas armas, porém, disparam **coisas que existem no mundo por um tempo**: granadas que quicam, foguetes que voam, flechas que caem, e — o que importa para a Vigília — um **sinalizador** que, depois de disparado, continua queimando no chão por alguns segundos, iluminando o corredor e afastando a Presença.

Projéteis mudam a natureza do combate (Capítulo 27, seção 27.1): o jogador passa a mirar **onde o alvo vai estar**, e o disparo tem **consequências que duram**. Na engenharia, eles mudam o custo: em vez de um trace no frame do disparo, há um ator que se move, colide e reage a cada frame até desaparecer.

---

## 28.1 O `ProjectileMovementComponent`

A Unreal tem um componente pronto para movimento de projéteis — mais um caso da regra "a engine já tem isso?" do Capítulo 9:

| Propriedade | Efeito |
|---|---|
| `InitialSpeed` / `MaxSpeed` | Velocidade de saída e limite (cm/s) |
| `ProjectileGravityScale` | 0 = linha reta (foguete); 1 = gravidade normal (granada, flecha) |
| `bShouldBounce`, `Bounciness`, `Friction` | Quique: quanto da velocidade é preservado e quanto se perde no contato |
| `bRotationFollowsVelocity` | O projétil aponta para onde está indo (flechas, foguetes) |
| `bForceSubStepping`, `MaxSimulationTimeStep` | Subpassos para estabilidade e para reduzir *tunneling* (Capítulo 3) |
| `bIsHomingProjectile`, `HomingTargetComponent` | Teleguiado (raramente desejável em terror) |

O componente move o **componente raiz** do ator com **sweep** (Capítulo 8): a cada passo, ele testa a colisão ao longo do caminho, o que já protege contra a maior parte do *tunneling*. Para projéteis muito rápidos, os subpassos reduzem ainda mais o risco.

Eventos importantes:

- **Colisão** — o componente de colisão raiz dispara `OnComponentHit` quando o movimento é bloqueado.
- **`OnProjectileBounce`** — a cada quique.
- **`OnProjectileStop`** — quando o projétil para (velocidade abaixo de um limiar, após quicar e perder energia).

### O atirador não pode se acertar

O projétil nasce dentro (ou muito perto) da cápsula de quem atirou. Sem cuidado, ele colide com o próprio atirador no primeiro frame. A solução é dizer ao componente de colisão que **ignore o instigador ao se mover**:

```cpp
Collision->IgnoreActorWhenMoving(GetInstigator(), true);
```

---

## 28.2 Do cano ao ponto mirado

O Capítulo 27 escolheu a câmera como origem do hitscan. Um projétil, por existir fisicamente, precisa **sair do cano** — senão a granada "nasce" nos olhos da jogadora. Mas, se ele sair do cano na direção do cano, sofre a paralaxe da seção 27.2 e não vai para onde a mira aponta.

A solução é a **abordagem C** do Capítulo 27, que aqui é natural:

```text
 1. trace da câmera ao longo da mira → ponto mirado (primeiro bloqueio, ou alcance máximo)
 2. direção de lançamento = (ponto mirado − cano).normalizado
 3. lançar do cano nessa direção (+ dispersão)
```

Com isso, a mira "não mente" para alvos à frente — o projétil converge para o centro da tela. Para projéteis com gravidade, ele vai **cair** em relação a essa linha ao longo do voo: isso é desejado (é a balística), e é comunicado ao jogador pelo próprio voo visível.

---

## 28.3 Balística e o que ela muda no design

Com projéteis, três grandezas entram em jogo:

- **Tempo de voo** = distância / velocidade. A 3.000 cm/s, um alvo a 30 m é atingido 1 s depois do disparo — se ele ainda estiver lá.
- **Queda** — com gravidade, o projétil cai `½ g t²` em relação à linha de lançamento. Em 1 s, ~4,9 m com gravidade terrestre.
- **Antecipação** (*leading*) — para acertar um alvo em movimento, o jogador mira à frente dele.

**[FATO PÚBLICO]** A série Battlefield é conhecida por modelar a **balística** de muitas armas com projéteis que têm tempo de voo e queda, algo especialmente perceptível com fuzis de precisão a longa distância, em que o jogador precisa compensar a queda e antecipar alvos em movimento.

**[INFERÊNCIA]** A escolha pela balística em mapas grandes faz sentido de design: em distâncias longas, um hitscan perfeito tornaria o atirador de elite trivial; tempo de voo e queda criam um **eixo de habilidade** novo e diminuem a vantagem de quem só aponta. O custo é de engenharia (muitos projéteis simultâneos num servidor com dezenas de jogadores) e de rede (Interlúdio III). Nenhuma afirmação é feita sobre a implementação real.

Para a Vigília, a balística do sinalizador é parte da tensão: ele é lento, cai, quica — a jogadora não "atira" no corredor, ela **arremessa uma luz** nele, e precisa pensar onde ela vai parar.

---

## 28.4 Projéteis e o pipeline de armas

A escolha entre hitscan e projétil pertence aos **dados** da arma, não a uma classe de arma diferente. `UVGWeaponData` ganha um campo `ProjectileClass`: se estiver vazio, a arma é hitscan (Capítulo 27); se estiver definido, `PerformShot` lança um projétil dessa classe. Cadência, munição, recarga, mira, eventos — tudo continua igual. É o pipeline estável do Capítulo 20, seção 20.6, provando o seu valor.

### Quem aplica o dano?

No hitscan, a arma aplica o dano no frame do disparo. No projétil, **o projétil** aplica o dano no momento do impacto — segundos depois, talvez depois de a jogadora ter trocado de arma ou até morrido. Por isso o projétil carrega consigo o **instigador** (configurado no spawn, Capítulo 8) e os dados de dano da arma que o disparou: ele precisa saber **quem** é o responsável, mesmo que a arma não exista mais.

---

## 28.5 O sinalizador

O sinalizador é o objeto mais importante da Vigília depois da lanterna. O documento de combate (Capítulo 21) definiu o que ele faz; agora, como:

```text
 DISPARO ──► VOO (gravidade, quica 1–2 vezes) ──► QUEIMA (8 s) ──► APAGA
               │                                   │
               │ acerto direto na Presença:        ├─ luz intensa (point light)
               │ estímulo de luz forte             ├─ ZONA SEGURA temporária (raio ~6 m)
               │ (atordoamento 4 s)                ├─ pulsos de estímulo de luz em área
               │                                   │   (atordoamento 2 s na Presença)
               │                                   └─ som de queima; fumaça; faíscas
```

Três decisões de engenharia:

1. **O sinalizador é um projétil que muda de fase.** Ele começa como projétil (move, quica) e, ao parar (`OnProjectileStop`) ou depois de um tempo máximo de voo, entra na fase de **queima**. Isso é uma pequena máquina de estado: `Flying → Burning → Spent`.
2. **A zona segura é a do Capítulo 23.** Ao começar a queimar, o sinalizador cria um `AVGSafeZone` ao redor de si. Quando apaga, destrói a zona — e a zona, no seu `EndPlay`, revoga o status de quem estava dentro. Nenhuma regra nova: a luz do sinalizador é **luz**, e a regra "a Presença não entra na luz" já existe.
3. **O efeito na Presença é dano de luz** (Capítulo 22, seção 22.5): um acerto direto aplica dano pontual do tipo `UVGDamageType_Light` com magnitude alta; os pulsos em área aplicam dano radial do mesmo tipo com magnitude menor. A Presença (Parte V) decide como reagir a cada magnitude. O sinalizador não sabe que a Presença existe.

---

## 28.6 Projéteis em escala

Cada projétil é um ator com componentes, colisão e um tick de movimento. Para o sinalizador (no máximo um ou dois existindo ao mesmo tempo), o custo é irrelevante. Para uma metralhadora com projéteis físicos a 900 RPM, com dezenas de inimigos atirando, seriam centenas de atores nascendo e morrendo por segundo — pressão no spawn, no garbage collector (Capítulo 11) e no tick.

As alternativas, quando "muitos projéteis" for um requisito:

- **Hitscan com efeito visual** de projétil (um rastro luminoso): a maioria das armas de fogo em jogos.
- **Pooling** de atores de projétil (Capítulo 32): elimina o custo de criar e destruir.
- **Simulação de projéteis sem atores** — um sistema central que mantém posições e velocidades num array e faz os traces por passo (o modelo orientado a dados do Capítulo 6), com visual por partículas.

A Vigília não precisa de nenhuma delas. O Galpão, para testar, terá uma arma de projéteis rápidos — e o exercício pede para medir o custo.

---

## Comparação com o desenvolvimento tradicional

| Projéteis | O que você conhece | Onde a analogia cai |
|---|---|---|
| Projétil carrega instigador e dados | Mensagem carrega contexto de autenticação/correlação | O "remetente" pode não existir mais quando ela é processada |
| Fases do sinalizador | Máquina de estado de um processo de vida curta | Cada fase tem efeitos físicos e de mundo |
| Muitos projéteis → pool ou sistema central | Pool de conexões; processamento em lote | O lote precisa caber no frame |

---

## Implementação

### 1. O projétil base

```cpp
// Source/Vigilia/Combat/VGProjectile.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGProjectile.generated.h"

class UProjectileMovementComponent;
class USphereComponent;
class UDamageType;
class UVGImpactEffects;

/**
 * Projétil genérico: move com ProjectileMovementComponent, aplica dano no impacto em nome do instigador.
 * Subclasses mudam o que acontece no impacto (HandleImpact) — ex.: o sinalizador.
 */
UCLASS(Blueprintable)
class VIGILIA_API AVGProjectile : public AActor
{
    GENERATED_BODY()

public:
    AVGProjectile();

    /** Chamado pela arma logo após o spawn (antes de qualquer impacto). */
    void InitProjectile(float InDamage, TSubclassOf<UDamageType> InDamageType, UVGImpactEffects* InImpactEffects);

protected:
    virtual void PostInitializeComponents() override;
    virtual void BeginPlay() override;

    /** O que acontece ao acertar algo. Padrão: dano pontual + efeito de impacto + destruir. */
    UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Projectile")
    void HandleImpact(const FHitResult& Hit);

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<USphereComponent> Collision;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UProjectileMovementComponent> Movement;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Projectile", meta = (ClampMin = "0.1"))
    float MaxLifeSpan = 6.0f;

    float Damage = 0.0f;

    UPROPERTY()
    TSubclassOf<UDamageType> DamageType;

    UPROPERTY()
    TObjectPtr<UVGImpactEffects> ImpactEffects;

private:
    UFUNCTION()
    void HandleHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
                   FVector NormalImpulse, const FHitResult& Hit);
};
```

```cpp
// Source/Vigilia/Combat/VGProjectile.cpp
#include "Combat/VGProjectile.h"

#include "Combat/VGImpactEffects.h"
#include "Components/SphereComponent.h"
#include "GameFramework/ProjectileMovementComponent.h"
#include "Kismet/GameplayStatics.h"

AVGProjectile::AVGProjectile()
{
    PrimaryActorTick.bCanEverTick = false; // quem move é o ProjectileMovementComponent

    Collision = CreateDefaultSubobject<USphereComponent>(TEXT("Collision"));
    Collision->InitSphereRadius(4.0f);
    Collision->SetCollisionProfileName(TEXT("Projectile")); // preset do projeto (ver abaixo)
    Collision->SetNotifyRigidBodyCollision(true);            // gera eventos de hit
    SetRootComponent(Collision);

    Movement = CreateDefaultSubobject<UProjectileMovementComponent>(TEXT("Movement"));
    Movement->UpdatedComponent = Collision;
    Movement->InitialSpeed = 3000.0f;
    Movement->MaxSpeed = 3000.0f;
    Movement->bRotationFollowsVelocity = true;
    Movement->ProjectileGravityScale = 1.0f;
}

void AVGProjectile::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    Collision->OnComponentHit.AddDynamic(this, &AVGProjectile::HandleHit);
}

void AVGProjectile::BeginPlay()
{
    Super::BeginPlay();
    SetLifeSpan(MaxLifeSpan);
    if (GetInstigator())
    {
        Collision->IgnoreActorWhenMoving(GetInstigator(), true); // não acertar quem atirou
    }
}

void AVGProjectile::InitProjectile(float InDamage, TSubclassOf<UDamageType> InDamageType,
                                   UVGImpactEffects* InImpactEffects)
{
    Damage = InDamage;
    DamageType = InDamageType;
    ImpactEffects = InImpactEffects;
}

void AVGProjectile::HandleHit(UPrimitiveComponent*, AActor*, UPrimitiveComponent*, FVector, const FHitResult& Hit)
{
    HandleImpact(Hit);
}

void AVGProjectile::HandleImpact_Implementation(const FHitResult& Hit)
{
    if (AActor* HitActor = Hit.GetActor())
    {
        UGameplayStatics::ApplyPointDamage(HitActor, Damage, GetVelocity().GetSafeNormal(), Hit,
                                           GetInstigatorController(), this, DamageType);
    }
    if (ImpactEffects)
    {
        ImpactEffects->PlayAt(this, Hit);
    }
    Destroy();
}
```

Crie em *Project Settings → Collision* um **preset `Projectile`**: tipo `WorldDynamic`, `Query and Physics`, bloqueando `WorldStatic`, `WorldDynamic`, `Pawn` e `PhysicsBody`, ignorando os canais `Interaction` e `Weapon` (projéteis não devem bloquear o trace de interação nem os disparos hitscan).

**Por que `InitProjectile` e não spawn diferido?** Os dados que o projétil recebe (dano, tipo, efeitos) não são usados no `BeginPlay`; eles só importam no impacto. Configurá-los logo após o spawn, antes do primeiro frame de movimento, é suficiente. Se o projétil precisasse deles no `BeginPlay` (por exemplo, para escolher a velocidade inicial), o spawn diferido do Capítulo 8 seria obrigatório.

### 2. A arma lança projéteis

```cpp
// VGWeaponData.h (adição)
    /** Se definido, a arma dispara projéteis desta classe em vez de hitscan. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Projectile")
    TSubclassOf<AVGProjectile> ProjectileClass;
```

```cpp
// VGWeapon.h (adição, privada)
//   void LaunchProjectile(const FVector& ViewLocation, const FRotator& ViewRotation,
//                         const FRandomStream& Stream, float HalfAngleRadians);

// VGWeapon.cpp — início de PerformShot_Implementation
    if (Data->ProjectileClass)
    {
        LaunchProjectile(ViewLocation, ViewRotation, Stream, HalfAngle);
        return;
    }
    // ... hitscan (Cap. 27) ...

void AVGWeapon::LaunchProjectile(const FVector& ViewLocation, const FRotator& ViewRotation,
                                 const FRandomStream& Stream, float HalfAngleRadians)
{
    // 1. Ponto mirado: trace da câmera (seção 28.2).
    const FVector AimEnd = ViewLocation + ViewRotation.Vector() * EffectiveStats.Range;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGProjectileAim), false, GetInstigator());
    Params.AddIgnoredActor(this);
    FHitResult AimHit;
    const FVector AimPoint = GetWorld()->LineTraceSingleByChannel(AimHit, ViewLocation, AimEnd, ECC_VGWeapon, Params)
        ? AimHit.ImpactPoint : AimEnd;

    // 2. Direção do cano até o ponto mirado, com dispersão.
    const FVector MuzzleLocation = Muzzle->GetComponentLocation();
    const FVector BaseDirection = (AimPoint - MuzzleLocation).GetSafeNormal();
    const FVector Direction = Stream.VRandCone(BaseDirection, HalfAngleRadians);

    // 3. Lançar do cano.
    FActorSpawnParameters SpawnParams;
    SpawnParams.Owner = this;
    SpawnParams.Instigator = GetInstigator(); // o projétil leva consigo QUEM é o responsável
    SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

    AVGProjectile* Projectile = GetWorld()->SpawnActor<AVGProjectile>(
        Data->ProjectileClass, MuzzleLocation, Direction.Rotation(), SpawnParams);
    if (Projectile)
    {
        Projectile->InitProjectile(EffectiveStats.Damage, Data->DamageType, Data->ImpactEffects);
    }
}
```

A direção inicial do projétil é a rotação do spawn: o `ProjectileMovementComponent` usa a orientação do ator e `InitialSpeed` para definir a velocidade de saída.

### 3. O sinalizador

```cpp
// Source/Vigilia/Combat/VGFlareProjectile.h
#pragma once

#include "CoreMinimal.h"
#include "Combat/VGProjectile.h"
#include "VGFlareProjectile.generated.h"

class UPointLightComponent;
class AVGSafeZone;

UENUM(BlueprintType)
enum class EVGFlareState : uint8
{
    Flying,
    Burning,
    Spent
};

/**
 * Sinalizador: voa e quica; ao parar, queima por um tempo: ilumina, cria uma zona segura
 * temporária e emite pulsos de estímulo de luz em área. Acerto direto: estímulo de luz forte.
 */
UCLASS(Blueprintable)
class VIGILIA_API AVGFlareProjectile : public AVGProjectile
{
    GENERATED_BODY()

public:
    AVGFlareProjectile();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void HandleImpact_Implementation(const FHitResult& Hit) override;

    /** Apresentação: acender, crepitar, apagar (Blueprint). */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Flare")
    void OnFlareStateChanged(EVGFlareState NewState);

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UPointLightComponent> Light;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare", meta = (ClampMin = "0.5"))
    float BurnDuration = 8.0f;

    /** Se não parar de quicar antes disso, começa a queimar onde estiver. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare", meta = (ClampMin = "0.1"))
    float MaxFlightTime = 2.5f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare", meta = (ClampMin = "0.0"))
    float DirectHitLightMagnitude = 100.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare", meta = (ClampMin = "0.0"))
    float PulseLightMagnitude = 40.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare", meta = (ClampMin = "10.0"))
    float LightRadius = 600.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare", meta = (ClampMin = "0.1"))
    float PulseInterval = 0.5f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flare")
    TSubclassOf<AVGSafeZone> SafeZoneClass;

private:
    UFUNCTION()
    void HandleStop(const FHitResult& ImpactResult);

    void StartBurning();
    void Pulse();
    void Extinguish();
    void SetFlareState(EVGFlareState NewState);

    EVGFlareState State = EVGFlareState::Flying;

    UPROPERTY(Transient)
    TObjectPtr<AVGSafeZone> SafeZone;

    FTimerHandle PhaseTimerHandle;
    FTimerHandle PulseTimerHandle;
};
```

```cpp
// Source/Vigilia/Combat/VGFlareProjectile.cpp
#include "Combat/VGFlareProjectile.h"

#include "Combat/VGDamageTypes.h"
#include "Components/PointLightComponent.h"
#include "GameFramework/ProjectileMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"
#include "World/VGSafeZone.h"

AVGFlareProjectile::AVGFlareProjectile()
{
    Movement->InitialSpeed = 2200.0f;
    Movement->MaxSpeed = 2200.0f;
    Movement->bShouldBounce = true;
    Movement->Bounciness = 0.3f;
    Movement->Friction = 0.6f;
    Movement->bRotationFollowsVelocity = false;

    Light = CreateDefaultSubobject<UPointLightComponent>(TEXT("Light"));
    Light->SetupAttachment(Collision);
    Light->SetIntensity(0.0f); // acende ao queimar

    DamageType = UVGDamageType_Light::StaticClass();
    MaxLifeSpan = 0.0f; // controlado pelas fases, não pelo life span
}

void AVGFlareProjectile::BeginPlay()
{
    Super::BeginPlay();
    SetLifeSpan(0.0f);
    Movement->OnProjectileStop.AddDynamic(this, &AVGFlareProjectile::HandleStop);
    GetWorldTimerManager().SetTimer(PhaseTimerHandle, this, &AVGFlareProjectile::StartBurning, MaxFlightTime, false);
    SetFlareState(EVGFlareState::Flying);
}

void AVGFlareProjectile::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearAllTimersForObject(this);
    if (SafeZone)
    {
        SafeZone->Destroy(); // a zona revoga o status de quem estava dentro (Cap. 23)
    }
    Super::EndPlay(EndPlayReason);
}

void AVGFlareProjectile::HandleImpact_Implementation(const FHitResult& Hit)
{
    // Não destrói ao acertar: quica (o ProjectileMovementComponent cuida disso).
    if (State != EVGFlareState::Flying)
    {
        return;
    }
    if (AActor* HitActor = Hit.GetActor(); HitActor && HitActor->CanBeDamaged())
    {
        // Acerto direto: estímulo de luz forte. Quem reage (a Presença) decide o efeito.
        UGameplayStatics::ApplyPointDamage(HitActor, DirectHitLightMagnitude, GetVelocity().GetSafeNormal(),
                                           Hit, GetInstigatorController(), this, DamageType);
    }
}

void AVGFlareProjectile::HandleStop(const FHitResult& ImpactResult)
{
    StartBurning();
}

void AVGFlareProjectile::StartBurning()
{
    if (State != EVGFlareState::Flying)
    {
        return; // parar e estourar o tempo de voo no mesmo frame: só uma vez
    }
    Movement->StopMovementImmediately(); // zera a velocidade...
    Movement->Deactivate();              // ...e para a simulação: sem isso, a gravidade volta a agir
    SetFlareState(EVGFlareState::Burning);

    if (SafeZoneClass)
    {
        FActorSpawnParameters Params;
        Params.Owner = this;
        SafeZone = GetWorld()->SpawnActor<AVGSafeZone>(SafeZoneClass, GetActorTransform(), Params);
    }

    Pulse();
    GetWorldTimerManager().SetTimer(PulseTimerHandle, this, &AVGFlareProjectile::Pulse, PulseInterval, true);
    GetWorldTimerManager().SetTimer(PhaseTimerHandle, this, &AVGFlareProjectile::Extinguish, BurnDuration, false);
}

void AVGFlareProjectile::Pulse()
{
    // Estímulo de luz em área, bloqueado por paredes (o canal de prevenção é o padrão de Visibility).
    UGameplayStatics::ApplyRadialDamage(this, PulseLightMagnitude, GetActorLocation(), LightRadius,
                                        DamageType, TArray<AActor*>(), this, GetInstigatorController(),
                                        /*bDoFullDamage=*/true);
}

void AVGFlareProjectile::Extinguish()
{
    GetWorldTimerManager().ClearTimer(PulseTimerHandle);
    if (SafeZone)
    {
        SafeZone->Destroy();
        SafeZone = nullptr;
    }
    SetFlareState(EVGFlareState::Spent);
    SetLifeSpan(3.0f); // o cartucho apagado ainda fica um pouco no chão
}

void AVGFlareProjectile::SetFlareState(EVGFlareState NewState)
{
    State = NewState;
    OnFlareStateChanged(NewState); // Blueprint: intensidade da luz, partículas, som
}
```

### Explicação das decisões

- **Exceção consciente à regra 1 do Capítulo 6** (no máximo uma classe base do projeto entre a engine e o Blueprint). `AActor → AVGProjectile → AVGFlareProjectile → BP_Sinalizador` tem duas. A exceção se justifica porque o sinalizador **é** um projétil (voo, colisão, tempo de vida, pool) com uma **fase extra** de comportamento, e essa fase é código, não dado. Como composição, ela seria um componente "queimador" que só faz sentido junto do projétil. A regra continua valendo: uma segunda subclasse especializada de `AVGProjectile` seria o sinal para extrair a fase de queima para um componente. Registre a exceção no `DEVLOG.md`.
- **Fases como máquina de estado** (`Flying → Burning → Spent`), com guarda em `StartBurning`: o sinalizador pode parar de quicar e estourar o tempo máximo de voo no mesmo frame — a transição acontece uma vez.
- **`Deactivate` no movimento ao começar a queimar.** `StopMovementImmediately` só zera a velocidade: o `ProjectileMovementComponent` continua simulando, a gravidade volta a puxar no frame seguinte, e um sinalizador que estourou o tempo de voo no ar (ou parou numa rampa) cairia ou escorregaria para longe da **própria zona segura**, que não está presa a ele. Desativar o componente congela o cartucho "onde estiver", como a regra pede. (Evite `StopSimulating` aqui: ele dispara `OnProjectileStop`, que chama `StartBurning` de novo.)
- **A zona segura é a do Capítulo 23**, criada e destruída pelo sinalizador. A simetria de conceder/revogar é garantida pela própria zona. A classe da zona é escolhida no Blueprint (`SafeZoneClass`) — um `BP_ZonaSinalizador` com a extensão adequada ao raio da luz.
- **Dano de luz como estímulo**, pontual (acerto direto) e radial (pulsos). Humanos têm multiplicador zero para luz (Capítulo 22): os vigias não são afetados. A Presença vai reagir.
- **`ApplyRadialDamage` respeita obstruções** (o parâmetro de canal de prevenção usa, por padrão, um canal de visibilidade): a luz não "atravessa" paredes. Confira a assinatura e o canal padrão na sua versão.
- **Apresentação no Blueprint** (`OnFlareStateChanged`): a curva de intensidade da luz ao acender, o crepitar, a fumaça, o apagar — tudo ajustável sem C++. A luz é *Movable* (Capítulo 8).
- **Life span desligado** durante o voo e a queima: quem controla a duração são as fases. Depois de apagar, um life span curto remove o cartucho.

### 4. Configuração

- `DA_Sinalizador`: `ProjectileClass = BP_Sinalizador` (filho de `AVGFlareProjectile`), `DamageType = Light`, pente 1, recarga 2,5 s (Capítulo 21).
- `BP_Sinalizador`: luz alaranjada intensa, partículas de faíscas e fumaça, som de queima em loop; `SafeZoneClass = BP_ZonaSinalizador`.
- `BP_ZonaSinalizador`: filho de `AVGSafeZone`, caixa de ~6 m.

---

## Projeto 2 — projéteis no Galpão

1. O **sinalizador** funcionando: dispare-o num corredor escuro do Galpão (apague as luzes de um canto) e observe-o quicar, parar, queimar, iluminar e apagar.
2. Com o cheat `VGDumpTags` (Capítulo 23), verifique que a jogadora ganha `Status.Zone.Safe` ao entrar na luz do sinalizador e perde quando ele apaga.
3. Um **lança-granadas de teste** (`DA_LancaGranadas`, projétil com gravidade e explosão radial ao parar — reuse a explosão do desafio do Capítulo 22).
4. Um **fuzil de projéteis rápidos** (`DA_FuzilBalistico`: projétil sem quique, `InitialSpeed = 15000`, gravidade 0,5) para comparar com o hitscan.

---

## Decisões arquiteturais

1. **Hitscan ou projétil é escolha de dados** (`ProjectileClass`), no mesmo pipeline de armas.
2. **Projéteis saem do cano em direção ao ponto mirado** pela câmera.
3. **O projétil carrega instigador e dados de dano**; aplica o dano no impacto.
4. **Projéteis ignoram o instigador ao se mover** e usam o preset `Projectile`.
5. **O sinalizador é uma máquina de fases** que reutiliza a zona segura (Cap. 23) e o dano de luz (Cap. 22).
6. **Muitos projéteis → pool ou sistema central**; a Vigília não precisa.

---

## Armadilhas

- **Projétil que acerta o próprio atirador** no primeiro frame.
- **Lançar na direção do cano** — paralaxe, projéteis que não vão para a mira.
- **Dano aplicado pela arma** em vez do projétil (a arma pode não existir mais).
- **Projéteis rápidos sem subpassos** atravessando paredes finas.
- **Zonas seguras do sinalizador que sobrevivem a ele** (esquecer de destruí-las).
- **Transições de fase duplicadas** (parar + tempo máximo no mesmo frame).
- **Spawn de centenas de atores de projétil por segundo** sem medir.

---

## Exercício

**Parte 1 — projétil base (1,5 h).** Implemente `AVGProjectile`, o preset `Projectile` e o lançamento na arma. Teste o lança-granadas e o fuzil balístico.

**Parte 2 — sinalizador (2 h).** Implemente `AVGFlareProjectile`, os Blueprints e a zona do sinalizador. Verifique as três fases e a zona segura temporária.

**Parte 3 — balística (45 min).** Coloque alvos a 10, 30 e 60 m no Galpão. Com o fuzil balístico, quanto acima do alvo você precisa mirar a 60 m? Calcule a queda esperada (`½ g t²`, com `t = distância / velocidade` e a gravidade escalada) e compare com o observado.

**Parte 4 — custo (45 min).** Com uma arma de projéteis a 900 RPM e 10 "atiradores" de teste (spawners que disparam continuamente), meça com `stat game` e `stat unit` o custo de atores de projétil. Quantos projéteis simultâneos o seu orçamento de 16,67 ms suporta?

---

## Desafio — o arremesso que ensina

Na Vigília, a jogadora precisa **aprender** como o sinalizador se comporta antes do primeiro encontro com a Presença. Projete e implemente um pequeno **momento de aprendizado** no fim do Galpão:

1. Um corredor escuro onde algo "se move" no fundo (por enquanto, um som e uma sombra — nada perigoso).
2. A jogadora encontra o sinalizador e um único cartucho.
3. O espaço é desenhado para que o disparo natural (para o fundo do corredor) faça o sinalizador quicar e parar num lugar visível, iluminando um detalhe narrativo (uma marca na parede, um documento).

Pergunta para o `DEVLOG.md`: como você garante, pelo level design (Capítulo 50), que o sinalizador para **onde você quer**, sem tirar da jogadora a sensação de que a escolha foi dela? *(Pense em geometria: rampas, cantos, um degrau que "segura" o cartucho.)*

---

## Uso de IA

1. **Para revisar o projétil:**
   > "Revise este projétil em Unreal Engine 5 (ProjectileMovementComponent, colisão, ignorar instigador, dano no impacto com instigador, efeitos, life span) e esta subclasse de sinalizador com fases Flying/Burning/Spent. Procure: transições duplicadas, timers não limpos, zona segura que sobrevive ao projétil e problemas com quique em superfícies inclinadas. [código]"

2. **Para calcular balística:**
   > "Para um projétil com velocidade inicial V (cm/s) e gravidade g × escala, derive a queda em função da distância, o ângulo de lançamento necessário para acertar um alvo a distância D na mesma altura, e o quanto mirar à frente de um alvo que se move a velocidade S perpendicular. Dê exemplos numéricos para V = 15000 cm/s, escala 0,5, D = 60 m."

3. **Para escolher a abordagem em escala:**
   > "Compare, para um shooter com muitos projéteis simultâneos (centenas), quatro abordagens: atores com ProjectileMovementComponent, atores com pooling, um gerenciador central de projéteis em arrays com traces por passo, e hitscan com efeito visual. Fale de custo de CPU, garbage collection, rede e complexidade."

---

## Checklist

- [ ] Sei configurar o `ProjectileMovementComponent` para projéteis retos, com gravidade e com quique.
- [ ] Lanço projéteis do cano em direção ao ponto mirado pela câmera.
- [ ] O projétil ignora o atirador e aplica dano em nome do instigador.
- [ ] Hitscan e projétil convivem no mesmo pipeline, escolhidos por dados.
- [ ] Implementei o sinalizador com fases, luz, zona segura temporária e estímulos de luz.
- [ ] Sei quando projéteis em escala exigem pooling ou um sistema central.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Projectile Movement Component** e a referência de `UGameplayStatics::ApplyRadialDamage`.
- **Projeto `RefFirstPerson`** — o projétil do template First Person (da 5.6 em diante, o da variante *Arena Shooter*) é um bom ponto de comparação com o `AVGProjectile`.

---

➡️ **Próximo:** [Capítulo 29 — Recoil](cap-29-recoil.md)

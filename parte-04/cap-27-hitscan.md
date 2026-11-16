# Capítulo 27 — Hitscan

## Objetivo

Ao final deste capítulo você deve conseguir:

- implementar **disparos hitscan** completos: origem, direção com **dispersão**, alcance e resolução do acerto;
- resolver o problema da **origem do disparo** (câmera vs. cano) e entender o trade-off de cada escolha;
- usar um **canal de colisão de armas** e **materiais físicos customizados** como contrato uniforme para multiplicadores de dano por parte do corpo, penetração e efeitos de impacto;
- implementar **queda de dano por distância**, **penetração** simplificada e armas de **múltiplos projéteis** (escopeta);
- produzir **feedback de impacto por superfície** (som, partícula, decal) e **confirmação de acerto** para a HUD;
- manter a dispersão **reproduzível** com sementes — preparando o terreno para o multiplayer.

---

## Contexto

Até aqui, `AVGWeapon::PerformShot` era um trace de teste: uma linha da câmera para a frente, dano fixo no que fosse atingido. Isso basta para provar o pipeline e é muito pouco para um FPS: todos os tiros acertam exatamente o centro da tela, a parede de concreto e a de madeira reagem igual, um tiro na cabeça vale o mesmo que no pé, e a jogadora não sabe se acertou.

Este capítulo substitui o trace de teste pelo disparo **hitscan** completo — o modelo usado pela maioria das armas de fogo em shooters: o disparo é resolvido **instantaneamente**, ao longo de uma linha, no frame em que acontece. O Capítulo 28 trata do outro modelo, o **projétil**, e o sinalizador da Vigília vai usá-lo.

---

## 27.1 O que é hitscan

Um disparo **hitscan** é uma **consulta espacial instantânea** (Capítulo 15): "o que esta linha atinge primeiro?". Não há objeto voando; não há tempo de voo; não há queda balística. O acerto é decidido no mesmo frame do disparo.

| | Hitscan | Projétil (Capítulo 28) |
|---|---|---|
| Resolução | Instantânea (trace) | Ao longo do tempo (ator que se move) |
| Custo | Um ou poucos traces por disparo | Um ator (ou entidade) por projétil, por frame |
| Distância | Ignorada (exceto queda de dano) | Tempo de voo, queda, desvio |
| Habilidade exigida | Mirar no alvo | Mirar **onde o alvo vai estar** |
| Uso típico | Armas de fogo comuns a distâncias de jogo | Foguetes, granadas, flechas, balística de longa distância, sinalizador |

A escolha é de design antes de ser técnica: hitscan premia **precisão e reação**; projétil premia **antecipação**.

---

## 27.2 De onde sai o tiro: câmera ou cano?

Em primeira pessoa, a câmera (os olhos) e o cano da arma estão em lugares diferentes — o cano fica alguns centímetros à frente, à direita e abaixo. Se o disparo sair do cano na direção da câmera, ele **não atinge** o ponto no centro da tela (paralaxe); se sair da câmera, ele pode atravessar uma quina que **bloquearia** o cano.

```text
                  centro da tela (o que a jogadora mira)
                           ●
                          /|
              trace da   / |  trace do cano, paralelo à câmera:
              câmera    /  |  passa ao LADO do alvo (paralaxe)
                       /   |
           olhos ●────/    ● cano
```

Há três abordagens:

| Abordagem | Como | Vantagem | Problema |
|---|---|---|---|
| **A — Da câmera** | Trace da câmera na direção da mira | **O que você vê é o que você acerta**; justo e previsível | Atirar "por cima" de uma cobertura que esconderia o cano |
| **B — Do cano** | Trace do cano na direção do cano | Fisicamente coerente | A mira na tela mente; erros incompreensíveis |
| **C — Câmera para mirar, cano para verificar** | Trace da câmera encontra o **ponto mirado**; trace do cano até esse ponto verifica obstrução | Coerente e quase sempre fiel à mira | Dois traces por disparo; casos de borda em que o cano bate numa quina próxima |

Para a Vigília e o Galpão, a escolha é **A para resolver o acerto**, com o cano usado **só para a apresentação** (o rastro visual do tiro, o *muzzle flash*). Em primeira pessoa, com a arma perto da câmera, os casos em que A "trapaceia" são raros e quase sempre a favor da jogadora — e "a mira não mente" é um requisito de feedback (Capítulo 5). A abordagem C é o exercício de desafio e, **[INFERÊNCIA]** pelo comportamento observável (balas que batem na quina diante do personagem, embora a mira esteja livre), é a mais comum em jogos em terceira pessoa, onde a distância entre câmera e arma é grande.

---

## 27.3 Dispersão

Nenhum disparo real (ou de jogo) vai exatamente para o centro da mira. A **dispersão** (*spread*) desvia a direção de cada disparo aleatoriamente dentro de um **cone**:

```cpp
const FVector Direction = Stream.VRandCone(AimDirection, FMath::DegreesToRadians(SpreadHalfAngleDegrees));
```

A dispersão atual combina várias fontes:

```text
dispersão = base(quadril ↔ mira, pelo alfa de mira — Cap. 26)
          + penalidade de movimento (proporcional à velocidade)
          + penalidade no ar
          + florescimento (bloom: cresce a cada disparo, decai com o tempo — Cap. 29)
```

Cada fonte é uma decisão de design: penalizar o movimento premia quem para para atirar; penalizar o ar desestimula pular atirando; o florescimento premia rajadas curtas. Todos os valores são **dados**.

### Dispersão reproduzível

Usar `FMath::FRand` para a dispersão torna cada disparo irreproduzível. Usar um **`FRandomStream` com semente** (Capítulo 3, seção 3.6) — por exemplo, semeado por um contador de disparos da arma — tem duas vantagens:

- **Depuração:** um bug que acontece "às vezes" com a dispersão pode ser reproduzido fixando a semente.
- **Multiplayer:** se o cliente e o servidor conhecem a mesma semente para cada disparo, ambos calculam **a mesma direção** sem enviar a direção pela rede — uma técnica importante para a predição de disparos (Capítulo 67).

---

## 27.4 Um canal para armas e materiais como contrato

### O canal

O trace de teste usava `ECC_Visibility`. Disparos merecem um **canal próprio** (`Weapon`), pelo mesmo motivo do canal de interação (Capítulo 15): controle explícito. Com ele:

- volumes de trigger e zonas seguras **ignoram** disparos;
- o corpo de um personagem pode ter colisão de **movimento** simples (a cápsula) e colisão de **disparo** detalhada (as partes do corpo na *physics asset* da malha esquelética), cada uma respondendo ao seu canal;
- vidros, grades e telas podem **deixar passar** tiros (Ignore ou Overlap) e bloquear movimento.

### Materiais físicos customizados

O Capítulo 15 introduziu materiais físicos e tipos de superfície; o Capítulo 17 usou-os para os passos. Agora eles viram o **contrato uniforme** dos disparos: uma subclasse de `UPhysicalMaterial` com os dados que o disparo precisa saber sobre **qualquer** superfície:

```text
UVGPhysicalMaterial (subclasse de UPhysicalMaterial)
  DamageMultiplier        ex.: cabeça 2,0; membros 0,75; colete 0,5
  PenetrationResistance   ex.: madeira 1; chapa fina 2; concreto 99 (não atravessa)
  (tipo de superfície)    → efeitos de impacto e som (seção 27.6)
```

Com isso, o multiplicador de **tiro na cabeça** não é um `if (BoneName == "head")` no código da arma: é o material físico do corpo da cabeça na *physics asset* do personagem. O mesmo mecanismo faz um colete reduzir dano, uma porta de madeira deixar a bala passar e uma parede de concreto pará-la. É exatamente a decisão do Capítulo 22, seção 22.2: **o multiplicador de parte do corpo mora com quem atira** — porque quem atira tem o `FHitResult`, e o `FHitResult` traz o material físico.

---

## 27.5 Distância e penetração

### Queda de dano por distância

Armas de fogo em jogos frequentemente causam **menos dano a longa distância** — uma decisão de design que define o papel de cada arma (a escopeta domina a curta distância; o fuzil, a média). A forma mais flexível é uma **curva** (distância → multiplicador) no Data Asset da arma:

```text
multiplicador
 1.0 ┤████████████▄▄▄▄
     │                ▀▀▀▄▄▄
 0.5 ┤                      ▀▀▀▀▀▀▀▀▀▀▀▀
     └──────────────────────────────────► distância
      0         20 m       40 m       80 m
```

### Penetração

Tiros que atravessam superfícies finas (madeira, chapas, portas) tornam o ambiente parte do combate. A versão simplificada da Vigília:

```text
poder de penetração da arma (ex.: 2,0)
trace → atinge superfície com resistência R:
     aplica dano (reduzido proporcionalmente ao poder restante)
     se R < poder restante: poder −= R; continua o trace logo depois do ponto de impacto
     senão: o disparo para
limite de superfícies por disparo (ex.: 3)
```

**Simplificação declarada:** a resistência é por superfície, não pela **espessura** atravessada. Uma versão mais fiel faria um trace reverso a partir do outro lado para estimar a espessura. Para o Galpão, a versão simples basta.

### Múltiplos projéteis

Uma **escopeta** é a mesma arma com `PelletCount = 8`: oito direções com dispersão, oito traces, oito aplicações de dano — com dano por projétil baixo. Nenhuma classe nova; um número no Data Asset.

---

## 27.6 Feedback de impacto e confirmação de acerto

### Efeitos por superfície

Cada impacto precisa responder "**em que** eu acertei?" (Capítulo 5): faíscas e um som metálico no metal, lascas e um baque na madeira, poeira no concreto, sangue (ou, na Vigília, algo mais estranho) em corpos. A tabela de efeitos é um **Data Asset** indexado pelo tipo de superfície:

```text
UVGImpactEffects
  Default  → som genérico, poeira, decal de furo
  Metal    → som metálico, faíscas, decal de furo metálico
  Madeira  → baque, lascas, decal de furo em madeira
  Concreto → impacto seco, poeira, decal
  Carne    → som de impacto em corpo, partícula, sem decal
```

O efeito é posicionado no `ImpactPoint` e orientado pela `ImpactNormal` (Capítulo 15) — uma partícula de faísca "sai" da superfície; um decal fica "colado" nela.

### Confirmação de acerto

A arma anuncia **o que acertou** (`OnHitConfirmed`, com o ator atingido e se foi um acerto crítico — material com multiplicador > 1). A HUD (Capítulo 55) mostra o *hit marker*. Para a confirmação de **abate**, o componente de vida (Capítulo 22) passa a publicar no barramento (Capítulo 24) um evento `Event.Actor.Died` com o instigador: a HUD mostra o marcador de abate quando o instigador é a jogadora. Nem a arma precisa saber que o alvo morreu, nem o componente de vida precisa saber que existe HUD.

> Em multiplayer, o *hit marker* é um dos pontos mais delicados: o cliente quer mostrá-lo **imediatamente**, mas quem decide se o acerto valeu é o **servidor** (Capítulo 68). A separação entre "o disparo foi resolvido" e "a apresentação do acerto" que este capítulo estabelece é o que permite tratar isso depois.

---

## Estudo de caso: a mira que não mente

> **Pergunta:** por que shooters investem tanto em garantir que "o que você vê é o que você acerta"?

**[FATO PÚBLICO]** Em comunidades de shooters competitivos, são recorrentes as reclamações de jogadores sobre acertos que "deveriam ter contado" ou abates "atrás da parede" — percepções que envolvem a diferença entre o que o jogador viu e o que o jogo decidiu. Desenvolvedores de shooters online frequentemente publicam explicações e ajustes sobre *hit registration*.

**[INFERÊNCIA]** A confiança do jogador no sistema de acerto é uma forma de **legibilidade** (Capítulos 1 e 5): se o jogador não entende por que um tiro errou, ele não consegue melhorar e passa a perceber o sistema como aleatório. Em single-player, a principal ameaça a essa confiança é a geometria (câmera vs. cano, colisão de disparo diferente da forma visual); em multiplayer, somam-se latência e divergência entre cliente e servidor. Em ambos os casos, as decisões de engenharia — origem do trace, colisão de disparo fiel à forma visível, feedback imediato e claro — são decisões sobre **confiança**.

**Lição:** **precisão percebida importa mais que precisão física.** Escolher a câmera como origem, ter colisão de disparo coerente com o visual e confirmar cada acerto com feedback claro não são detalhes: são o que faz o jogador acreditar na própria mira.

---

## Comparação com o desenvolvimento tradicional

| Hitscan | O que você conhece | Onde a analogia cai |
|---|---|---|
| Trace de disparo | Consulta indexada | Resolvida no mesmo frame, com efeitos visuais e físicos |
| Materiais como contrato | Metadados de entidade consultados por regras | A "regra" está no **dado do mundo**, não no código da arma |
| Semente por disparo | Requisições idempotentes com chave | Permite que duas máquinas calculem o mesmo resultado aleatório |
| Hit marker vs. decisão do acerto | UI otimista vs. confirmação do servidor | Em single-player, as duas coincidem; em multiplayer, não |

---

## Implementação

### 1. Canal e dependências

Em *Project Settings → Collision*, crie o trace channel **`Weapon`** com resposta padrão **Block** (paredes, chão e objetos bloqueiam tiros por padrão; triggers e volumes configurados para Ignore). No código:

```cpp
// VGCollision.h (adição)
#define ECC_VGWeapon ECC_GameTraceChannel2 // canal "Weapon" — ordem dos canais em Project Settings
```

**Passo que não pode faltar: cápsula ignora, malha bloqueia.** Um canal novo com resposta padrão Block vale para **todos** os presets que não o sobrescrevem — inclusive o preset `Pawn` da cápsula. Sem ajuste, o trace bate na cápsula antes de chegar à *physics asset*: o `FHitResult` não traz `BoneName` nem o material físico da parte do corpo, e somem o tiro na cabeça, as reações por região e a direção do ragdoll (Capítulo 30). Na base dos personagens que levam tiro:

```cpp
// Construtor de AVGCharacter e AVGEnemyCharacter (ou um preset de colisão do projeto, "VGCharacterCapsule")
GetCapsuleComponent()->SetCollisionResponseToChannel(ECC_VGWeapon, ECR_Ignore); // cápsula: só movimento
GetMesh()->SetCollisionEnabled(ECollisionEnabled::QueryOnly);                    // corpos da physics asset respondem a queries
GetMesh()->SetCollisionResponseToChannel(ECC_VGWeapon, ECR_Block);              // malha: recebe o disparo
```

Confira com `show Collision` e com o log do `BoneName` no primeiro disparo: se aparecer `None` num acerto no personagem, o trace ainda está parando na cápsula.

No `Vigilia.Build.cs`, adicione `"Niagara"` (efeitos de impacto). `"PhysicsCore"` (materiais físicos) já foi adicionado no Capítulo 17.

### 2. Material físico do projeto

```cpp
// Source/Vigilia/Combat/VGPhysicalMaterial.h
#pragma once

#include "CoreMinimal.h"
#include "PhysicalMaterials/PhysicalMaterial.h"
#include "VGPhysicalMaterial.generated.h"

/** Material físico com dados de combate: multiplicador de dano e resistência à penetração. */
UCLASS()
class VIGILIA_API UVGPhysicalMaterial : public UPhysicalMaterial
{
    GENERATED_BODY()

public:
    /** Multiplicador aplicado por quem atira (ex.: cabeça 2.0, colete 0.5). */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Vigilia|Combat", meta = (ClampMin = "0.0"))
    float DamageMultiplier = 1.0f;

    /** Quanto do poder de penetração esta superfície consome. Alto = não atravessa. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Vigilia|Combat", meta = (ClampMin = "0.0"))
    float PenetrationResistance = 99.0f;
};
```

### 3. Efeitos de impacto

```cpp
// Source/Vigilia/Combat/VGImpactEffects.h
#pragma once

#include "CoreMinimal.h"
#include "Chaos/ChaosEngineInterface.h"
#include "Engine/DataAsset.h"
#include "VGImpactEffects.generated.h"

class UNiagaraSystem;
class USoundBase;
class UMaterialInterface;

USTRUCT(BlueprintType)
struct FVGImpactEffect
{
    GENERATED_BODY()

    UPROPERTY(EditDefaultsOnly, Category = "Impact") TObjectPtr<USoundBase> Sound;
    UPROPERTY(EditDefaultsOnly, Category = "Impact") TObjectPtr<UNiagaraSystem> Particles;
    UPROPERTY(EditDefaultsOnly, Category = "Impact") TObjectPtr<UMaterialInterface> Decal;
    UPROPERTY(EditDefaultsOnly, Category = "Impact") float DecalSize = 6.0f;
    UPROPERTY(EditDefaultsOnly, Category = "Impact") float DecalLifeSpan = 20.0f;
};

/** Efeitos de impacto por tipo de superfície. */
UCLASS(BlueprintType)
class VIGILIA_API UVGImpactEffects : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Impact")
    FVGImpactEffect Default;

    UPROPERTY(EditDefaultsOnly, Category = "Impact")
    TMap<TEnumAsByte<EPhysicalSurface>, FVGImpactEffect> BySurface;

    /** Toca o efeito adequado à superfície do acerto. */
    void PlayAt(const UObject* WorldContext, const FHitResult& Hit) const;
};
```

```cpp
// Source/Vigilia/Combat/VGImpactEffects.cpp
#include "Combat/VGImpactEffects.h"

#include "Kismet/GameplayStatics.h"
#include "NiagaraFunctionLibrary.h"
#include "PhysicalMaterials/PhysicalMaterial.h"

void UVGImpactEffects::PlayAt(const UObject* WorldContext, const FHitResult& Hit) const
{
    const EPhysicalSurface Surface = UPhysicalMaterial::DetermineSurfaceType(Hit.PhysMaterial.Get());
    const FVGImpactEffect* Found = BySurface.Find(Surface);
    const FVGImpactEffect& Effect = Found ? *Found : Default;

    const FRotator Orientation = Hit.ImpactNormal.Rotation(); // "sai" da superfície

    if (Effect.Sound)
    {
        UGameplayStatics::PlaySoundAtLocation(WorldContext, Effect.Sound, Hit.ImpactPoint);
    }
    if (Effect.Particles)
    {
        UNiagaraFunctionLibrary::SpawnSystemAtLocation(WorldContext, Effect.Particles, Hit.ImpactPoint, Orientation);
    }
    if (Effect.Decal)
    {
        // Decals projetam ao longo do eixo X: orientado para DENTRO da superfície.
        UGameplayStatics::SpawnDecalAtLocation(WorldContext, Effect.Decal, FVector(Effect.DecalSize),
            Hit.ImpactPoint, (-Hit.ImpactNormal).Rotation(), Effect.DecalLifeSpan);
    }
}
```

### 4. Dados da arma

Novos campos em `UVGWeaponData` (fora das estatísticas modificáveis, por serem definições da arma):

```cpp
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Hitscan", meta = (ClampMin = "1"))
    int32 PelletCount = 1;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Hitscan", meta = (ClampMin = "0.0"))
    float PenetrationPower = 0.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Hitscan", meta = (ClampMin = "1"))
    int32 MaxPenetrations = 3;

    /** Distância (cm) → multiplicador de dano. Vazia = sem queda. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Hitscan")
    TObjectPtr<UCurveFloat> DamageFalloff;

    /** Penalidades de dispersão (graus). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Spread")
    float SpreadPerMovementSpeed = 0.004f; // graus por cm/s

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Spread")
    float AirborneSpread = 4.0f;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Feedback")
    TObjectPtr<UVGImpactEffects> ImpactEffects;
```

### 5. O disparo

```cpp
// VGWeapon.h (adições)
DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGHitConfirmedSignature,
    AVGWeapon*, Weapon, AActor*, HitActor, bool, bCritical);

public:
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Weapon")
    FVGHitConfirmedSignature OnHitConfirmed;

    /** Dispersão adicional que o portador fornece (alfa de mira, movimento, bloom). */
    void SetExternalSpread(float SpreadDegrees) { ExternalSpread = SpreadDegrees; }

protected:
    /** Apresentação do rastro (do cano até o impacto). */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Weapon")
    void OnShotTracer(FVector From, FVector To);

private:
    float ComputeSpreadDegrees() const;
    void FirePellet(const FVector& ViewLocation, const FVector& Direction, const FRandomStream& Stream);

    float ExternalSpread = 0.0f;
    int32 ShotCounter = 0;
```

```cpp
// VGWeapon.cpp — o disparo hitscan
#include "Combat/VGHealthComponent.h"
#include "Combat/VGImpactEffects.h"
#include "Combat/VGPhysicalMaterial.h"
#include "Core/VGCollision.h"
#include "Curves/CurveFloat.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Character.h"

float AVGWeapon::ComputeSpreadDegrees() const
{
    float Spread = ExternalSpread; // quadril↔mira (Cap. 26) + bloom (Cap. 29), vindos do portador
    if (const ACharacter* Shooter = Cast<ACharacter>(GetInstigator()))
    {
        const UCharacterMovementComponent* Move = Shooter->GetCharacterMovement();
        Spread += Move->Velocity.Size2D() * Data->SpreadPerMovementSpeed;
        if (Move->IsFalling())
        {
            Spread += Data->AirborneSpread;
        }
    }
    return Spread;
}

void AVGWeapon::PerformShot_Implementation()
{
    const AController* Controller = GetInstigatorController();
    if (!Controller)
    {
        return;
    }
    FVector ViewLocation;
    FRotator ViewRotation;
    Controller->GetPlayerViewPoint(ViewLocation, ViewRotation); // origem: a CÂMERA (seção 27.2)

    // Semente por disparo: reproduzível (debug) e sincronizável (multiplayer, Cap. 67).
    // Misturada com HashCombine: sementes consecutivas cruas dariam dispersões correlacionadas (ver abaixo).
    const FRandomStream Stream(static_cast<int32>(HashCombine(GetUniqueID(), static_cast<uint32>(ShotCounter++))));
    const float HalfAngle = FMath::DegreesToRadians(ComputeSpreadDegrees());

    for (int32 Pellet = 0; Pellet < Data->PelletCount; ++Pellet)
    {
        const FVector Direction = Stream.VRandCone(ViewRotation.Vector(), HalfAngle);
        FirePellet(ViewLocation, Direction, Stream);
    }
}

void AVGWeapon::FirePellet(const FVector& ViewLocation, const FVector& Direction, const FRandomStream& Stream)
{
    const FVGWeaponStats& Stats = EffectiveStats;
    const float DamagePerPellet = Stats.Damage / Data->PelletCount;

    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGWeaponShot), /*bTraceComplex=*/true, GetInstigator());
    Params.AddIgnoredActor(this);
    Params.bReturnPhysicalMaterial = true;

    FVector Start = ViewLocation;
    const FVector End = ViewLocation + Direction * Stats.Range;
    float Power = Data->PenetrationPower;
    float PowerScale = 1.0f;
    FVector LastImpact = End;

    for (int32 Surface = 0; Surface <= Data->MaxPenetrations; ++Surface)
    {
        FHitResult Hit;
        if (!GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_VGWeapon, Params))
        {
            break; // nada mais no caminho
        }
        LastImpact = Hit.ImpactPoint;

        const UVGPhysicalMaterial* Material = Cast<UVGPhysicalMaterial>(Hit.PhysMaterial.Get());
        const float MaterialMultiplier = Material ? Material->DamageMultiplier : 1.0f;
        const float Resistance = Material ? Material->PenetrationResistance : 99.0f;

        const float Distance = FVector::Dist(ViewLocation, Hit.ImpactPoint);
        const float Falloff = Data->DamageFalloff ? Data->DamageFalloff->GetFloatValue(Distance) : 1.0f;
        const float Damage = DamagePerPellet * MaterialMultiplier * Falloff * PowerScale;

        if (AActor* HitActor = Hit.GetActor())
        {
            UGameplayStatics::ApplyPointDamage(HitActor, Damage, Direction, Hit,
                                               GetInstigatorController(), this, Data->DamageType);
            if (HitActor->FindComponentByClass<UVGHealthComponent>()) // tem vida = é alvo
            {
                OnHitConfirmed.Broadcast(this, HitActor, MaterialMultiplier > 1.0f);
            }
        }
        if (Data->ImpactEffects)
        {
            Data->ImpactEffects->PlayAt(this, Hit);
        }

        // Penetração simplificada: por superfície, sem espessura.
        if (Power <= Resistance)
        {
            break;
        }
        PowerScale *= 1.0f - (Resistance / Power);  // cada superfície atravessada reduz o dano
        Power -= Resistance;
        Params.AddIgnoredActor(Hit.GetActor());      // não acertar o mesmo ator de novo
        Start = Hit.ImpactPoint + Direction * 2.0f;  // continua logo depois do impacto
    }

    OnShotTracer(Muzzle->GetComponentLocation(), LastImpact); // apresentação: sai do CANO
}
```

### Explicação das decisões

- **Origem na câmera, rastro saindo do cano** (seção 27.2): a resolução é fiel à mira; a apresentação é fiel à arma.
- **`bTraceComplex = true`** no disparo: tiros devem respeitar a forma visível dos objetos (Capítulo 15). O custo de colisão complexa é aceitável para alguns traces por disparo; corpos de personagens usam as formas simples da *physics asset*, que já são detalhadas por parte do corpo.
- **Dispersão em camadas:** o portador (componente de armas) fornece a parte que depende dele (alfa de mira, florescimento); a arma acrescenta o que depende do corpo do atirador (movimento, ar).
- **`FRandomStream` semeado por arma e contador.** A semente combina o identificador único do objeto e um contador; no Capítulo 67, ela será substituída por uma semente compartilhada entre cliente e servidor.
- ⚠️ **A semente passa por `HashCombine`.** O `FRandomStream` é um gerador congruencial linear: com sementes consecutivas (N, N+1, N+2...), o primeiro número sorteado avança quase em progressão (~0,046 por disparo). A dispersão ganharia um **padrão** visível no alvo — o oposto do que se quer. Misturar a semente antes desfaz a correlação e mantém a reprodutibilidade.
- **Multiplicador por material**, lido do `FHitResult` — sem nenhum `if` sobre ossos ou classes.
- **`OnHitConfirmed` só para atores com `UVGHealthComponent`**: acertar uma parede não é um "acerto" para a HUD. Não use `CanBeDamaged()` para isso — `bCanBeDamaged` é verdadeiro por padrão em **todo** `AActor`, paredes incluídas.
- **Penetração com escala de dano decrescente** e ator ignorado após atravessado; limite de superfícies por disparo.

### 6. O componente de armas fornece a dispersão

No `UVGWeaponComponent`, a cada disparo (ou no tick da mira), `CurrentWeapon->SetExternalSpread(GetCurrentSpread())`. No Capítulo 29, o florescimento entra nessa mesma soma. O componente é o **único** que chama `SetExternalSpread`: quem quiser acrescentar dispersão (o cérebro do inimigo, Capítulo 30) passa por ele.

### 7. Confirmação de abate

No `UVGHealthComponent::ReceiveDamage`, ao morrer, publique no barramento:

```cpp
UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Actor_Died,
    Instigator ? Instigator->GetPawn() : nullptr, GetOwner());
```

(com a tag nativa `Event.Actor.Died`). A HUD — por enquanto um widget de debug — mostra um marcador de abate quando o instigador do evento é o pawn da jogadora.

A publicação acontece **antes** do `OnDied.Broadcast` do componente. Assim, quem ouve o barramento ainda encontra a vítima no estado em que ela morreu: possuída pelo seu controller, antes de qualquer reação ao `OnDied` (ragdoll, *unpossess*, respawn). O Capítulo 64 depende dessa ordem para achar o controller da vítima.

---

## Projeto 2 — o Galpão vira um estande de verdade

1. **Materiais físicos:** `PM_Concreto`, `PM_Metal`, `PM_Madeira` (resistência 1), `PM_ChapaFina` (resistência 1,5), todos `UVGPhysicalMaterial`. Aplique-os às paredes de teste do Galpão (Capítulo 20).
2. **Alvos com zonas:** troque o `BP_Alvo` cilíndrico por um manequim com malha esquelética (o manequim da engine serve) e uma *physics asset* em que o corpo da cabeça usa `PM_Cabeca` (multiplicador 2,0) e os membros `PM_Membro` (0,75).
3. **Efeitos:** `DA_Impactos` com efeitos placeholder por superfície.
4. **Armas:** pistola sem penetração; fuzil com `PenetrationPower = 2`; uma **escopeta** (`DA_Escopeta`: 8 projéteis, dispersão de quadril alta, queda de dano forte).
5. **HUD de debug:** *hit marker* (acerto normal e crítico) e marcador de abate.

---

## Decisões arquiteturais

1. **Hitscan para armas de fogo; projétil para o sinalizador e explosivos.**
2. **Resolução a partir da câmera; apresentação a partir do cano.**
3. **Canal `Weapon` próprio**; triggers e volumes o ignoram.
4. **`UVGPhysicalMaterial` como contrato**: multiplicador de dano por parte do corpo/superfície e resistência à penetração.
5. **Dispersão em camadas** (portador + arma), com `FRandomStream` semeado por disparo.
6. **Queda de dano por curva; penetração simplificada por superfície; múltiplos projéteis por dado.**
7. **Efeitos de impacto por superfície em Data Asset.**
8. **Confirmação de acerto pela arma; de abate pelo barramento.**

---

## Armadilhas

- **Trace do cano na direção da câmera** — a mira mente.
- **`ECC_Visibility` para disparos** — triggers e volumes bloqueando tiros.
- **`if (BoneName == "head")` na arma** em vez de material físico.
- **Dispersão com `FMath::FRand`** — irreproduzível.
- **Penetração sem limite** ou sem ignorar o ator atravessado (acertos repetidos no mesmo corpo).
- **Decal orientado pela normal** sem inverter (o decal projeta "para fora" e não aparece).
- **Hit marker em paredes.**
- **Esquecer `bReturnPhysicalMaterial`.**

---

## Exercício

**Parte 1 — hitscan (2 h).** Implemente o canal, o material físico, os efeitos e o novo `PerformShot`. Teste com as três armas contra as paredes de materiais do Galpão.

**Parte 2 — zonas (1 h).** Configure o manequim com materiais por parte do corpo. Meça o TTK da pistola mirando só na cabeça e só no tronco, e compare com o simulador do Capítulo 21 (ajuste o simulador para considerar o multiplicador).

**Parte 3 — dispersão (45 min).** Com `vg.Debug` ou `DrawDebugLine`, desenhe os traces de cada projétil da escopeta. Compare a dispersão parado, andando, correndo, no ar e mirando.

**Parte 4 — reprodutibilidade (30 min).** Fixe a semente (crie uma CVar `vg.Debug.FixedSpreadSeed`) e verifique que o mesmo padrão de dispersão se repete a cada disparo.

---

## Desafio — câmera para mirar, cano para verificar

Implemente a **abordagem C** da seção 27.2 como opção do Data Asset (`bVerifyFromMuzzle`):

1. Trace da câmera encontra o **ponto mirado** (o primeiro bloqueio, ou o fim do alcance).
2. Trace do cano até o ponto mirado: se bloquear **antes** (a uma distância significativamente menor), o disparo atinge o obstáculo do cano.
3. Construa no Galpão uma situação de teste — atrás de uma mureta, mirando por cima dela — e compare as abordagens A e C.

Pergunta para o `DEVLOG.md`: em qual das abordagens a jogadora se sente mais injustiçada? Por que jogos em terceira pessoa tendem a precisar da abordagem C, e jogos em primeira pessoa, não?

---

## Uso de IA

1. **Para revisar o hitscan:**
   > "Revise este disparo hitscan em Unreal Engine 5: origem do trace, canal de colisão, uso de colisão complexa, dispersão com FRandomStream, multiplicador por material físico, queda de dano por curva, penetração (limites, ator ignorado, ponto de continuação) e efeitos de impacto (orientação de partícula e decal). Aponte bugs e casos de borda. [código]"

2. **Para entender o problema da origem:**
   > "Explique com geometria o problema de paralaxe entre câmera e cano em shooters em primeira e terceira pessoa. Compare três abordagens (trace da câmera, trace do cano, câmera para mirar e cano para verificar), com os casos em que cada uma produz resultados que o jogador percebe como injustos."

3. **Para design de armas:**
   > "Para pistola, fuzil e escopeta num shooter de teste, proponha curvas de queda de dano por distância (pontos da curva), poder de penetração e dispersões (quadril, mira, movimento, ar) que deem a cada arma um papel claro. Explique o papel tático resultante."

**Cuidado específico:** a orientação de decals na Unreal (eixo de projeção) e as assinaturas de funções de spawn de efeitos (Niagara, decals, sons) mudaram ao longo das versões; confirme a assinatura na sua versão antes de copiar.

---

## Checklist

- [ ] Sei a diferença de design e de engenharia entre hitscan e projétil.
- [ ] Sei explicar o problema câmera vs. cano e justificar a escolha do projeto.
- [ ] Implementei dispersão em camadas com `FRandomStream` semeado por disparo.
- [ ] Criei o canal `Weapon` e o `UVGPhysicalMaterial` como contrato de dano e penetração.
- [ ] Implementei queda de dano, penetração simplificada e múltiplos projéteis.
- [ ] Implementei efeitos de impacto por superfície e confirmação de acerto e de abate.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Physical Materials**, **Physics Asset Editor**, **Traces**, **Decals** e **Niagara** (spawn de sistemas em runtime).
- **GDC Vault** (gdcvault.com) — busque talks sobre *hit registration* e *weapon feel* em shooters (o assunto volta, em profundidade, no Capítulo 68).

---

➡️ **Próximo:** [Capítulo 28 — Projectile](cap-28-projectile.md)

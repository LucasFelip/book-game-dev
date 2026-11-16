# Capítulo 30 — Enemy

## Objetivo

Ao final deste capítulo você deve conseguir:

- decompor um inimigo em **corpo, vida, reações, morte, cérebro, ações e apresentação**, e saber quais partes já existem no projeto;
- implementar **reações a acertos** (direção, parte do corpo, atordoamento) e **morte com ragdoll** usando a informação do dano pontual;
- reutilizar o **sistema de armas da jogadora** num inimigo, sem código específico;
- construir um **cérebro deliberadamente ingênuo** — uma pequena máquina de estado — com **telegrafia** e **erro de mira dosado**, para que o inimigo seja justo;
- entender exatamente o que esse cérebro não faz, e por que a Parte V vai substituí-lo;
- montar o primeiro inimigo do Galpão: o **Vigia de testes**.

---

## Contexto

Até aqui, o Galpão tem alvos que morrem e reaparecem. Eles não reagem, não ameaçam, não se movem. Um inimigo é outra coisa: é um **agente** que percebe, decide e age — e que, ao ser atingido, comunica que foi atingido.

Este capítulo constrói um inimigo **simples de propósito**. A Parte V (Game AI) é inteira sobre como inimigos percebem, decidem e se movem bem — com controllers de IA, máquinas de estado hierárquicas, Behavior Trees, percepção, navegação e consultas espaciais. Construir aqui um cérebro ingênuo tem dois objetivos: completar o Projeto 2 com um inimigo que atira de volta, e criar exatamente a **dor** que a Parte V vai resolver — como o Projeto 4 fará com a narrativa.

O que **não** é ingênuo neste capítulo é todo o resto: o corpo, a vida, as reações, a morte e a apresentação são definitivos, e serão reaproveitados pelo Vigia e pela Presença da Parte V.

---

## 30.1 Anatomia de um inimigo

```text
                         INIMIGO
   ┌──────────────┬──────────────┬──────────────┬──────────────┐
   ▼              ▼              ▼              ▼              ▼
 CORPO          VIDA          REAÇÕES         CÉREBRO       APRESENTAÇÃO
 Character,     UVGHealth-    acerto: anim.,  percebe,      sons, falas,
 malha,         Component     atordoamento;   decide        telegrafia,
 physics asset  (Cap. 22)     morte: ragdoll  (Parte V)     efeitos
 (zonas, Cap. 27)                                │
                                                 ▼
                                              AÇÕES
                                              mover (CMC), mirar (control
                                              rotation), atirar (UVGWeaponComponent)
```

Repare que **quase tudo já existe**:

| Parte | Já existe | Capítulo |
|---|---|---|
| Corpo com movimento | `ACharacter` + CMC | 17 |
| Zonas de dano | Physics asset + `UVGPhysicalMaterial` | 27 |
| Vida, morte única, multiplicadores por tipo | `UVGHealthComponent` | 22 |
| Identidade e status | `UVGStatusTagsComponent` (`Faction.Guard`) | 23 |
| Armas, cadência, munição, dispersão | `UVGWeaponComponent` + `AVGWeapon` | 20, 26, 27 |
| Anúncio de morte | Barramento (`Event.Actor.Died`) | 24, 27 |

O que falta é: **reações** (o corpo comunicando que foi atingido), **morte física** (ragdoll), o **cérebro** e a **apresentação** específica do inimigo. É o resultado da arquitetura por componentes e contratos uniformes dos capítulos anteriores: um inimigo novo é **composição**, não código novo.

---

## 30.2 Reações a acertos

Um inimigo que não reage a tiros parece um saco de pancadas — e o jogador não sabe se está acertando (Capítulo 21, confirmação de efeito). As reações combinam três camadas:

1. **Animação de reação** (*hit reaction*): um movimento curto que depende da **direção** do acerto (frente, costas, lados) e, às vezes, da **parte do corpo**. Na Unreal, normalmente um **Anim Montage** tocado sobre a animação base (Capítulo 53).
2. **Atordoamento** (*stagger/flinch*): por uma fração de segundo, o inimigo **interrompe** o que estava fazendo — perde a mira, cancela o ataque. É uma mecânica: acertar primeiro dá vantagem. Para não travar o inimigo para sempre sob fogo contínuo, usa-se um **limiar de atordoamento** (*poise*): só acertos que acumulam dano suficiente numa janela curta causam atordoamento, e há um tempo mínimo entre atordoamentos.
3. **Feedback de material e som**: um som de impacto em corpo, uma partícula, um breve brilho no material.

A informação necessária — direção do disparo, osso atingido, ponto do impacto — vem do **dano pontual** (`OnTakePointDamage`, Capítulo 22). O componente de vida cuida de **quanto**; o inimigo cuida de **como reagir**.

### Direção de um acerto

Para escolher a reação (frente/costas/esquerda/direita), compara-se a direção **de onde veio** o disparo com a orientação do inimigo — dois produtos escalares (Capítulo 17):

```cpp
const FVector FromShot = -ShotDirection.GetSafeNormal2D(); // aponta do inimigo para o atirador
const float Front = FVector::DotProduct(GetActorForwardVector(), FromShot);
const float Right = FVector::DotProduct(GetActorRightVector(), FromShot);

if (FMath::Abs(Front) >= FMath::Abs(Right)) { /* Front > 0 ? frente : costas */ }
else                                        { /* Right > 0 ? direita : esquerda */ }
```

---

## 30.3 Morte e ragdoll

**Ragdoll** é a técnica de, na morte, entregar o esqueleto do personagem à **simulação física**: cada osso com corpo físico na *physics asset* passa a ser simulado, ligado aos vizinhos por restrições. O corpo cai de forma diferente a cada vez — dependendo de onde estava, de como foi atingido, do terreno. É o elo "física → animação → feedback" da cadeia de GTA IV (Capítulo 15), na versão mais simples.

Os passos:

```text
 1. Desligar o movimento (CMC) e a colisão da cápsula (o corpo não deve mais bloquear).
 2. A malha esquelética passa ao perfil de colisão "Ragdoll" e simula física.
 3. Aplicar um impulso no osso atingido, na direção do disparo (o tiro "empurra" o corpo).
 4. Desacoplar o controller (o cérebro para).
 5. Depois de um tempo, remover o corpo (ou deixá-lo, se for importante para a narrativa).
```

O impulso na direção do disparo é o que transforma um ragdoll genérico em **feedback**: o jogador vê o corpo cair **para longe de onde ele atirou**. Por isso o inimigo guarda o último dano pontual recebido — o dano que matou também é o que define a queda.

> **Custo:** um ragdoll simula dezenas de corpos físicos. Três ou quatro ao mesmo tempo não importam; vinte, sim. Inimigos mortos devem **adormecer** (Capítulo 15) e ser removidos ou "congelados" depois de algum tempo. Mais um item para o orçamento de frame do Capítulo 58.

---

## 30.4 Um cérebro ingênuo

A Parte V vai separar **percepção**, **decisão** e **navegação** em sistemas próprios. Para o Galpão, um cérebro mínimo, numa máquina de estado de quatro estados:

```text
            vê o alvo (trace de visão)
  ┌──────┐ ───────────────────────────► ┌───────────┐
  │ Idle │                              │ Telegraph │  vira para o alvo; sinal de
  └──────┘ ◄──── perdeu o alvo ──────── └─────┬─────┘  "vai atirar" (som/luz) por T s
      ▲                                       │ T segundos passaram e ainda vê
      │                                       ▼
      │                                 ┌───────────┐
      │                                 │   Fire    │  rajada curta com erro de mira
      │                                 └─────┬─────┘  decrescente
      │          cooldown terminou            │ rajada terminou
      └─────────────────────────────── ┌─────┴─────┐
                                       │ Cooldown  │
                                       └───────────┘
       (atordoamento, em qualquer estado → interrompe e volta a Telegraph depois)
```

Três decisões de design incorporadas, todas vindas do Capítulo 21:

- **Telegrafia obrigatória.** O inimigo nunca atira sem antes passar pelo estado `Telegraph`, com duração maior que o tempo de reação + resposta da jogadora (0,6–0,9 s para um vigia; o primeiro encontro, mais). A apresentação desse estado — um grito, o som de engatilhar, uma lanterna apontada para a jogadora — é o que torna o ataque **justo**.
- **Erro de mira dosado.** Um inimigo que acerta todo tiro é trivial de programar e injusto de enfrentar (Capítulo 1, seção 1.3). O cérebro adiciona uma **dispersão extra** que começa alta no início de cada engajamento e diminui a cada disparo: os primeiros tiros quase sempre erram — dando à jogadora tempo de reagir —, e o perigo cresce se ela ficar exposta.
- **Atordoamento interrompe.** Acertar o vigia primeiro o faz perder a mira e reiniciar a telegrafia. Recompensa a iniciativa.

### O que este cérebro não faz (e por que dói)

- **Não se move** de forma inteligente: não busca cobertura, não flanqueia, não persegue. (Capítulos 35, 39, 41.)
- **Não ouve**: só "vê", por um trace direto. Passos, portas e tiros não o alertam. (Capítulo 36.)
- **Não tem memória**: se a jogadora sai da linha de visão, ele a "esquece" imediatamente. (Capítulos 36–38.)
- **Não coordena** com outros vigias. (Capítulo 42.)
- **Toda a lógica está num componente C++ com um `switch`.** Adicionar "investigar um som" exige um estado novo, transições novas, e o `switch` cresce. (Capítulos 34 e 37 explicam por que FSMs planas param de escalar e o que fazer.)

Anote essas limitações no `DEVLOG.md`. Elas são a lista de requisitos da Parte V.

---

## 30.5 Armas em inimigos

O inimigo usa o **mesmo** `UVGWeaponComponent` e o **mesmo** `AVGWeapon` da jogadora. Duas adaptações pequenas:

- **De onde mirar.** A arma resolve o disparo a partir de `GetPlayerViewPoint` do controller do instigador (Capítulo 27). Para um `AAIController`, isso devolve o **ponto de vista dos olhos** do pawn controlado. A arma não precisa saber que quem atira é uma IA.
- **Onde prender a arma.** O componente de armas anexava a arma à câmera de primeira pessoa (Capítulo 20). Para um inimigo com malha esquelética, ela deve ir para um **socket** da mão. 🔁 O componente ganha uma propriedade `AttachSocketName`: se o dono tiver uma malha esquelética com esse socket, a arma é anexada a ele; senão, mantém o comportamento anterior.

E a mira do inimigo é a **control rotation** do seu controller — a mesma "vontade" do Capítulo 10. O cérebro diz ao controller para **focar** o alvo (`SetFocus`), e o `AIController` aponta a control rotation para ele; o corpo acompanha a uma taxa limitada (`bUseControllerDesiredRotation` + `RotationRate`); a arma atira na direção da mira. É a separação vontade/corpo fazendo o inimigo funcionar com o código da jogadora.

---

## Estudo de caso: Alan Wake — inimigos legíveis

> **Pergunta:** como um inimigo comunica o próprio estado — e por que isso é tão importante quanto o quanto ele é perigoso?

**[FATO PÚBLICO]** Em *Alan Wake* (Remedy, 2010), os *Taken* — pessoas possuídas — falam enquanto se aproximam: frases fragmentadas, ligadas às vidas que tinham antes (restos de conversas do cotidiano, sobre a cidade ou o trabalho). A camada de escuridão que os protege é visível, e ela se dissipa visivelmente sob a luz da lanterna antes de eles ficarem vulneráveis.

**[INFERÊNCIA]** As falas cumprem várias funções ao mesmo tempo. **Narrativa ambiental** (Capítulo 48): cada Taken carrega um resto da pessoa que foi. **Atmosfera**: vozes humanas distorcidas são perturbadoras. E **legibilidade de combate**: a voz **anuncia a presença e a posição** do inimigo antes do ataque — uma forma de telegrafia sonora. A escuridão visível, por sua vez, comunica o estado mecânico mais importante do inimigo: "ainda não pode ser ferido / agora pode". Um inimigo que comunica bem o próprio estado permite ao jogador **tomar decisões**, e decisões são o que transforma um encontro em gameplay (Capítulo 5). Nenhuma afirmação é feita sobre a implementação.

**[SIMPLIFICAÇÃO DIDÁTICA]** O Vigia deste capítulo comunica três estados: **percebeu** (vira a lanterna para a jogadora e grita — o início da telegrafia), **vai atirar** (som de engatilhar no fim da telegrafia) e **foi atingido** (reação e grito curto). Na Parte V, com percepção e memória, entram mais estados — "ouvi algo", "estou procurando", "perdi você" —, cada um com sua comunicação.

**Lição:** **todo estado relevante de um inimigo precisa de uma forma de ser percebido pelo jogador.** Estados invisíveis — um inimigo que "decidiu atacar" sem nenhum sinal — produzem mortes que o jogador não entende. A apresentação do cérebro é parte do design do cérebro.

---

## Comparação com o desenvolvimento tradicional

| Inimigo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Inimigo por composição | Montar um serviço novo a partir de bibliotecas existentes | Os "componentes" interagem fisicamente, todo frame |
| Telegrafia de estados | Observabilidade do estado interno de um sistema | O "operador" é o jogador, que precisa ler o estado em ~0,3 s |
| Cérebro ingênuo com prazo | Protótipo com dívida técnica explícita | A dívida é registrada como requisitos da próxima fase |
| Erro de mira dosado | — | Não há equivalente: o sistema é **projetado para errar** |

---

## Implementação

### 1. A classe base de personagens não jogáveis

```cpp
// Source/Vigilia/AI/VGEnemyCharacter.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "GameplayTagAssetInterface.h"
#include "VGEnemyCharacter.generated.h"

class UVGHealthComponent;
class UVGStatusTagsComponent;
class UVGWeaponComponent;
class UAnimMontage;
struct FVGDamageReport;

UENUM(BlueprintType)
enum class EVGHitDirection : uint8
{
    Front,
    Back,
    Left,
    Right
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGStaggeredSignature, AVGEnemyCharacter*, Enemy);

/**
 * Base dos inimigos (Vigia, e a Presença na Parte V): corpo, vida, tags, reações a acertos,
 * atordoamento e morte com ragdoll. O CÉREBRO fica fora desta classe.
 */
UCLASS(Abstract, Blueprintable)
class VIGILIA_API AVGEnemyCharacter : public ACharacter, public IGameplayTagAssetInterface
{
    GENERATED_BODY()

public:
    AVGEnemyCharacter();

    virtual void GetOwnedGameplayTags(FGameplayTagContainer& TagContainer) const override;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Enemy")
    bool IsStaggered() const;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Enemy")
    bool IsAlive() const;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Enemy")
    FVGStaggeredSignature OnStaggered;

protected:
    virtual void BeginPlay() override;

    /** Apresentação da reação (montage por direção, som, brilho) — Blueprint. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Enemy")
    void OnHitReaction(EVGHitDirection Direction, FName BoneName, bool bStaggered);

    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Enemy")
    void OnDeath();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGHealthComponent> Health;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGStatusTagsComponent> StatusTags;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGWeaponComponent> Weapons;

    /** Dano acumulado numa janela curta necessário para atordoar. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy|Stagger", meta = (ClampMin = "0.0"))
    float StaggerThreshold = 30.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy|Stagger", meta = (ClampMin = "0.0"))
    float StaggerWindow = 0.6f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy|Stagger", meta = (ClampMin = "0.0"))
    float StaggerDuration = 0.7f;

    /** Tempo mínimo entre atordoamentos (evita travar o inimigo sob fogo contínuo). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy|Stagger", meta = (ClampMin = "0.0"))
    float StaggerCooldown = 2.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy|Death", meta = (ClampMin = "0.0"))
    float DeathImpulse = 6000.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Enemy|Death", meta = (ClampMin = "0.0"))
    float CorpseLifeSpan = 30.0f;

private:
    UFUNCTION()
    void HandlePointDamage(AActor* DamagedActor, float Damage, AController* InstigatedBy, FVector HitLocation,
                           UPrimitiveComponent* FHitComponent, FName BoneName, FVector ShotFromDirection,
                           const UDamageType* DamageType, AActor* DamageCauser);

    UFUNCTION()
    void HandleDamaged(UVGHealthComponent* HealthComponent, const FVGDamageReport& Report);

    UFUNCTION()
    void HandleDied(UVGHealthComponent* HealthComponent, const FVGDamageReport& Report);

    EVGHitDirection ComputeHitDirection(const FVector& ShotDirection) const;
    void StartRagdoll();

    float RecentDamage = 0.0f;
    float RecentDamageStart = -100.0f;
    float StaggeredUntil = -1.0f;
    float LastStaggerTime = -100.0f;

    FVector LastShotDirection = FVector::ZeroVector;
    FName LastHitBone = NAME_None;
};
```

```cpp
// Source/Vigilia/AI/VGEnemyCharacter.cpp
#include "AI/VGEnemyCharacter.h"

#include "Combat/VGHealthComponent.h"
#include "Combat/VGWeaponComponent.h"
#include "Components/CapsuleComponent.h"
#include "Core/VGStatusTagsComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

AVGEnemyCharacter::AVGEnemyCharacter()
{
    PrimaryActorTick.bCanEverTick = false;

    Health = CreateDefaultSubobject<UVGHealthComponent>(TEXT("Health"));
    StatusTags = CreateDefaultSubobject<UVGStatusTagsComponent>(TEXT("StatusTags"));
    Weapons = CreateDefaultSubobject<UVGWeaponComponent>(TEXT("Weapons"));

    // O corpo gira em direção à mira (control rotation) a uma taxa limitada, não instantaneamente.
    bUseControllerRotationYaw = false;
    GetCharacterMovement()->bOrientRotationToMovement = false;
    GetCharacterMovement()->bUseControllerDesiredRotation = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 360.0f, 0.0f); // graus/s
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned; // um AIController assume o corpo
}

void AVGEnemyCharacter::BeginPlay()
{
    Super::BeginPlay();
    OnTakePointDamage.AddDynamic(this, &AVGEnemyCharacter::HandlePointDamage);
    Health->OnDamaged.AddDynamic(this, &AVGEnemyCharacter::HandleDamaged);
    Health->OnDied.AddDynamic(this, &AVGEnemyCharacter::HandleDied);
}

void AVGEnemyCharacter::GetOwnedGameplayTags(FGameplayTagContainer& TagContainer) const
{
    TagContainer = StatusTags->GetAllTags();
}

bool AVGEnemyCharacter::IsAlive() const { return Health->IsAlive(); }

bool AVGEnemyCharacter::IsStaggered() const
{
    return GetWorld()->GetTimeSeconds() < StaggeredUntil;
}

EVGHitDirection AVGEnemyCharacter::ComputeHitDirection(const FVector& ShotDirection) const
{
    const FVector FromShot = -ShotDirection.GetSafeNormal2D(); // do inimigo para quem atirou
    const float Front = FVector::DotProduct(GetActorForwardVector(), FromShot);
    const float Right = FVector::DotProduct(GetActorRightVector(), FromShot);

    if (FMath::Abs(Front) >= FMath::Abs(Right))
    {
        return Front >= 0.0f ? EVGHitDirection::Front : EVGHitDirection::Back;
    }
    return Right >= 0.0f ? EVGHitDirection::Right : EVGHitDirection::Left;
}

void AVGEnemyCharacter::HandlePointDamage(AActor*, float, AController*, FVector, UPrimitiveComponent*,
                                          FName BoneName, FVector ShotFromDirection, const UDamageType*, AActor*)
{
    // Nota: este evento chega ANTES de o componente de vida aplicar o dano (Cap. 22, ordem da engine),
    // com o valor BRUTO. Aqui só se registra ONDE e DE ONDE; quanto doeu vem do OnDamaged, abaixo.
    // O golpe fatal também passa por aqui — e registra a direção usada pelo ragdoll.
    LastShotDirection = ShotFromDirection;
    LastHitBone = BoneName;
}

void AVGEnemyCharacter::HandleDamaged(UVGHealthComponent*, const FVGDamageReport& Report)
{
    if (!Health->IsAlive())
    {
        return; // golpe fatal: quem cuida é o HandleDied (ragdoll)
    }

    // Limiar de atordoamento numa janela curta, com tempo mínimo entre atordoamentos.
    // Report.Amount já passou pelos multiplicadores: luz num vigia (multiplicador 0) nem chega aqui.
    const float Now = GetWorld()->GetTimeSeconds();
    if (Now - RecentDamageStart > StaggerWindow)
    {
        RecentDamage = 0.0f;
        RecentDamageStart = Now;
    }
    RecentDamage += Report.Amount;

    const bool bStagger = RecentDamage >= StaggerThreshold && (Now - LastStaggerTime) >= StaggerCooldown;
    if (bStagger)
    {
        RecentDamage = 0.0f;
        LastStaggerTime = Now;
        StaggeredUntil = Now + StaggerDuration;
        OnStaggered.Broadcast(this); // o cérebro interrompe o que estava fazendo
    }
    OnHitReaction(ComputeHitDirection(LastShotDirection), LastHitBone, bStagger);
}

void AVGEnemyCharacter::HandleDied(UVGHealthComponent*, const FVGDamageReport&)
{
    GetCharacterMovement()->DisableMovement();
    GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    Weapons->StopFire();
    DetachFromControllerPendingDestroy(); // o cérebro para

    StartRagdoll();
    OnDeath();
    SetLifeSpan(CorpseLifeSpan);
}

void AVGEnemyCharacter::StartRagdoll()
{
    USkeletalMeshComponent* Body = GetMesh();
    Body->SetCollisionProfileName(TEXT("Ragdoll"));
    Body->SetSimulatePhysics(true);

    // O golpe fatal empurra o corpo: ele cai para longe de quem atirou.
    const FName Bone = (LastHitBone != NAME_None) ? LastHitBone : FName(TEXT("pelvis"));
    Body->AddImpulse(LastShotDirection.GetSafeNormal() * DeathImpulse, Bone, /*bVelChange=*/false);
}
```

### Explicação das decisões

- **O inimigo não tem cérebro nesta classe.** O corpo, a vida, as reações e a morte são definitivos; o cérebro (ingênuo agora, Behavior Tree na Parte V) é outro componente ou o próprio controller de IA. É a separação vontade/corpo, de novo.
- **`AutoPossessAI`**: inimigos colocados no nível ou criados por spawn são possuídos automaticamente por um controller de IA (a classe padrão `AAIController`, por ora — o Capítulo 33 cria o do projeto).
- **Atordoamento com limiar, janela e cooldown**, anunciado por `OnStaggered`. Quem interrompe ações é o cérebro, que escuta o evento.
- **O atordoamento conta o dano do `OnDamaged`, não o do `OnTakePointDamage`.** O dano pontual chega **bruto**, antes dos multiplicadores do componente de vida: somá-lo ali faria o sinalizador (luz, multiplicador 0 nos vigias) atordoar um vigia que ele nem fere. Cada evento responde ao que sabe: o pontual diz **onde**; o componente de vida diz **quanto**. (Dano não pontual, como o radial, reage com a última direção registrada — simplificação aceitável aqui.)
- **O último dano pontual guarda direção e osso** e é usado para o impulso do ragdoll. O golpe fatal chega ao `HandlePointDamage` (que registra a direção) — repare que, pela ordem da engine, o evento de dano pontual é disparado **antes** do de dano genérico que leva o componente de vida à morte (Capítulo 22, seção 22.1); por isso a direção já está registrada quando o `HandleDied` roda. Se essa ordem mudar numa versão futura, a queda do ragdoll perde a direção — mas nada quebra.
- **`DetachFromControllerPendingDestroy`** desliga o controller do corpo morto de forma segura.
- **Preset `Ragdoll`** na malha: confira que ele existe (é um preset padrão da engine) e que a *physics asset* da malha tem corpos e restrições adequados.

### 2. O cérebro ingênuo

```cpp
// Source/Vigilia/AI/VGSimpleCombatBrain.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGSimpleCombatBrain.generated.h"

class AVGEnemyCharacter;

UENUM(BlueprintType)
enum class EVGSimpleBrainState : uint8
{
    Idle,
    Telegraph,
    Fire,
    Cooldown
};

/**
 * CÉREBRO DELIBERADAMENTE INGÊNUO (Projeto 2). Vê por trace direto, sem memória, sem movimento.
 * Substituído na Parte V (AIController + percepção + Behavior Tree). Ver DEVLOG: "dores do cérebro ingênuo".
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGSimpleCombatBrain : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGSimpleCombatBrain();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

protected:
    virtual void BeginPlay() override;

    /** Apresentação: grito/lanterna ao perceber, som de engatilhar, etc. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Brain")
    void OnBrainStateChanged(EVGSimpleBrainState NewState);

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "100.0"))
    float SightRange = 2500.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.0", ClampMax = "180.0"))
    float SightHalfAngle = 60.0f;

    /** Telegrafia: sempre maior que reação + resposta da jogadora (Cap. 21). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.2"))
    float TelegraphTime = 0.8f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.05"))
    float BurstDuration = 0.6f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.0"))
    float CooldownTime = 1.2f;

    /** Erro de mira (graus) no início de um engajamento; decai a cada disparo até MinAimError. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.0"))
    float InitialAimError = 8.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.0"))
    float MinAimError = 1.5f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Brain", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float AimErrorDecayPerShot = 0.8f;

private:
    UFUNCTION()
    void HandleStaggered(AVGEnemyCharacter* Enemy);

    UFUNCTION()
    void HandleWeaponFired(class AVGWeapon* Weapon);

    void TransitionTo(EVGSimpleBrainState NewState);
    AActor* FindVisibleTarget() const;
    void AimAt(AActor* InTarget);

    UPROPERTY(Transient)
    TObjectPtr<AVGEnemyCharacter> Body;

    TWeakObjectPtr<AActor> Target;
    EVGSimpleBrainState State = EVGSimpleBrainState::Idle;
    float StateTime = 0.0f;
    float CurrentAimError = 0.0f;
};
```

```cpp
// Source/Vigilia/AI/VGSimpleCombatBrain.cpp
#include "AI/VGSimpleCombatBrain.h"

#include "AI/VGEnemyCharacter.h"
#include "AIController.h"
#include "Combat/VGWeapon.h"
#include "Combat/VGWeaponComponent.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGMathUtils.h"
#include "GameplayTagAssetInterface.h"
#include "Kismet/GameplayStatics.h"

UVGSimpleCombatBrain::UVGSimpleCombatBrain()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.TickInterval = 0.0f; // ingênuo: decide todo frame (a Parte V reduz isso)
}

void UVGSimpleCombatBrain::BeginPlay()
{
    Super::BeginPlay();
    Body = Cast<AVGEnemyCharacter>(GetOwner());
    if (!Body)
    {
        SetComponentTickEnabled(false);
        return;
    }
    Body->OnStaggered.AddDynamic(this, &UVGSimpleCombatBrain::HandleStaggered);
    if (UVGWeaponComponent* Weapons = Body->FindComponentByClass<UVGWeaponComponent>())
    {
        if (AVGWeapon* Weapon = Weapons->GetCurrentWeapon())
        {
            Weapon->OnFired.AddDynamic(this, &UVGSimpleCombatBrain::HandleWeaponFired);
        }
    }
}

AActor* UVGSimpleCombatBrain::FindVisibleTarget() const
{
    // Ingênuo: só a jogadora, só por linha de visão direta. Sem audição, sem memória.
    APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
    if (!IsValid(Player))
    {
        return nullptr;
    }
    FVector EyesLocation;
    FRotator EyesRotation;
    Body->GetActorEyesViewPoint(EyesLocation, EyesRotation);

    const FVector ToPlayer = Player->GetActorLocation() - EyesLocation;
    if (ToPlayer.SizeSquared() > FMath::Square(SightRange))
    {
        return nullptr;
    }
    const float CosHalf = FMath::Cos(FMath::DegreesToRadians(SightHalfAngle));
    if (FVector::DotProduct(Body->GetActorForwardVector(), ToPlayer.GetSafeNormal()) < CosHalf)
    {
        return nullptr; // fora do cone de visão (Cap. 17)
    }
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGSimpleBrainSight), false, Body);
    FHitResult Hit;
    const bool bBlocked = GetWorld()->LineTraceSingleByChannel(
        Hit, EyesLocation, Player->GetActorLocation(), ECC_Visibility, Params) && Hit.GetActor() != Player;
    return bBlocked ? nullptr : Player;
}

void UVGSimpleCombatBrain::AimAt(AActor* InTarget)
{
    AAIController* Controller = Cast<AAIController>(Body->GetController());
    if (!Controller || !InTarget)
    {
        return;
    }
    // Não escreva a control rotation de um AAIController à mão: a cada tick, UpdateControlRotation
    // a recalcula (foco → senão, rotação do pawn) e zera o pitch se o foco não for um pawn.
    // O canal da engine para "olhe para isto" é o foco.
    Controller->SetFocus(InTarget);
}

void UVGSimpleCombatBrain::TickComponent(float DeltaTime, ELevelTick TickType,
                                         FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    if (!Body->IsAlive())
    {
        SetComponentTickEnabled(false);
        return;
    }

    StateTime += DeltaTime;
    AActor* Visible = FindVisibleTarget();
    UVGWeaponComponent* Weapons = Body->FindComponentByClass<UVGWeaponComponent>();

    switch (State) // Simplificação: FSM plana num switch — exatamente o que a Parte V substitui.
    {
    case EVGSimpleBrainState::Idle:
        if (Visible)
        {
            Target = Visible;
            CurrentAimError = InitialAimError; // novo engajamento: os primeiros tiros erram
            TransitionTo(EVGSimpleBrainState::Telegraph);
        }
        break;

    case EVGSimpleBrainState::Telegraph:
        if (!Visible) { TransitionTo(EVGSimpleBrainState::Idle); break; }
        AimAt(Visible);
        if (StateTime >= TelegraphTime && !Body->IsStaggered())
        {
            TransitionTo(EVGSimpleBrainState::Fire);
        }
        break;

    case EVGSimpleBrainState::Fire:
        AimAt(Visible ? Visible : Target.Get());
        if (Weapons)
        {
            Weapons->SetExtraSpread(CurrentAimError); // erro dosado: o componente soma e repassa à arma
            Weapons->StartFire();
        }
        if (StateTime >= BurstDuration || !Visible)
        {
            if (Weapons) { Weapons->StopFire(); }
            TransitionTo(EVGSimpleBrainState::Cooldown);
        }
        break;

    case EVGSimpleBrainState::Cooldown:
        if (StateTime >= CooldownTime)
        {
            TransitionTo(Visible ? EVGSimpleBrainState::Telegraph : EVGSimpleBrainState::Idle);
        }
        break;
    }
}

void UVGSimpleCombatBrain::HandleWeaponFired(AVGWeapon* Weapon)
{
    CurrentAimError = FMath::Max(CurrentAimError * AimErrorDecayPerShot, MinAimError);
}

void UVGSimpleCombatBrain::HandleStaggered(AVGEnemyCharacter* Enemy)
{
    if (UVGWeaponComponent* Weapons = Body->FindComponentByClass<UVGWeaponComponent>())
    {
        Weapons->StopFire();
    }
    if (State != EVGSimpleBrainState::Idle)
    {
        TransitionTo(EVGSimpleBrainState::Telegraph); // atordoado: perde a mira e recomeça a telegrafia
    }
}

void UVGSimpleCombatBrain::TransitionTo(EVGSimpleBrainState NewState)
{
    if (NewState == EVGSimpleBrainState::Idle)
    {
        if (AAIController* Controller = Cast<AAIController>(Body->GetController()))
        {
            Controller->ClearFocus(EAIFocusPriority::Gameplay); // sem alvo: para de encarar
        }
    }
    State = NewState;
    StateTime = 0.0f;
    OnBrainStateChanged(NewState);
}
```

### Explicação das decisões

- **Tudo o que este cérebro faz já foi visto em outro lugar**: cone de visão por produto escalar e trace (Capítulos 15 e 17), FSM com transições centralizadas (Capítulo 4), arma da jogadora (Capítulo 20), erro de mira como dispersão externa (Capítulo 27). O que é novo é **a combinação** — e o quanto ela já fica frágil com quatro estados.
- **Mira pelo foco do `AIController` (`SetFocus`), não por `SetControlRotation`.** A tentação é girar a control rotation à mão, com o mesmo decaimento exponencial da câmera (Capítulo 18). Não funciona: o `AAIController`, no próprio tick, recalcula a control rotation (para o ponto de foco ou, sem foco, para a rotação do pawn) e zera o *pitch* quando o foco não é um pawn — o vigia não gira e não mira. A suavidade fica no **corpo**: `bUseControllerDesiredRotation` + `RotationRate` faz o personagem virar até a mira a 360°/s. A mira em si é instantânea; a imprecisão vem do erro de mira e a reação humana, da telegrafia. Como sempre: quando a engine tem um canal para algo, use o canal — e quando o resultado contradiz o código, leia o código da engine (`AAIController::UpdateControlRotation`).
- **`GetPlayerPawn(this, 0)`** é um atalho que só funciona com uma jogadora e acopla o cérebro à ideia de "o jogador". É deliberadamente ingênuo; a percepção da Parte V substitui isso por estímulos.
- **Erro de mira decrescente por disparo**, reiniciado a cada engajamento: o design do Capítulo 21 em três linhas.
- 🔁 **Um único dono para a dispersão externa.** O cérebro **não** chama `SetExternalSpread` na arma: o `UVGWeaponComponent` já faz isso a cada disparo (Capítulos 27 e 29), e dois escritores do mesmo valor significam que o último vence — o erro de mira sumiria em silêncio. O componente ganha `SetExtraSpread(float)`, um termo do portador (uma propriedade `ExtraSpread`, 0 por padrão) somado à dispersão que ele repassa à arma: `GetCurrentSpread() + bloom + ExtraSpread`.
- **`FindComponentByClass` no tick** é uma pequena violação da regra do Capítulo 9 (procure uma vez e guarde). Ela está aqui de propósito, junto com o `switch`, como parte da "dívida" deste cérebro — corrija no exercício.

### 3. O Vigia de testes

`BP_VigiaTeste` (filho de `AVGEnemyCharacter`):

- malha esquelética (o manequim da engine), *physics asset* com materiais de cabeça e membros (Capítulo 27);
- `UVGSimpleCombatBrain` adicionado;
- `Weapons`: `StartingWeaponClass = BP_PistolaVigia` (uma pistola com dano menor), `AttachSocketName = hand_r`;
- `IdentityTags = Faction.Guard`; `Health`: 100, multiplicador 0 para `UVGDamageType_Light`;
- apresentação: no `OnBrainStateChanged(Telegraph)`, um grito placeholder e uma lanterna (spot light) apontada para a frente acesa; no `OnHitReaction`, um som e um montage por direção (se houver animações; senão, um tremor da malha).

---

## Projeto 2 — o Galpão ganha um adversário

Três vigias no Galpão, em posições com linhas de visão diferentes, e caixas como cobertura improvisada. Jogue e responda no `DEVLOG.md`:

1. A telegrafia é suficiente para reagir? (Compare com o teste de justiça planejado no Capítulo 21.)
2. O erro de mira inicial dá tempo de buscar cobertura?
3. Acertar primeiro (atordoar) dá vantagem perceptível?
4. Quais das limitações da seção 30.4 você percebeu jogando — e qual delas mais estraga a ilusão de inteligência?

---

## Decisões arquiteturais

1. **Inimigos são composição** de componentes existentes; `AVGEnemyCharacter` acrescenta reações, atordoamento e ragdoll.
2. **O cérebro fica fora do corpo**; o controller de IA possui o corpo (`AutoPossessAI`).
3. **Reações usam o dano pontual** (direção, osso); vida cuida só da quantidade.
4. **Atordoamento por limiar, janela e cooldown**, anunciado por evento.
5. **Ragdoll com impulso do golpe fatal**; corpo removido depois de um tempo.
6. **Inimigos usam o mesmo sistema de armas**, mirando pela control rotation e presos a um socket.
7. **Telegrafia obrigatória e erro de mira dosado** em todo inimigo.
8. **O cérebro ingênuo é dívida técnica declarada**, com requisitos para a Parte V.

---

## Armadilhas

- **Inimigos que não reagem a acertos.**
- **Atordoamento sem cooldown** — inimigo travado sob fogo contínuo.
- **Ragdoll sem impulso** — corpos que "desmontam" no lugar.
- **Esquecer de desligar a cápsula e o movimento** na morte.
- **Muitos ragdolls ativos** sem dormir ou serem removidos.
- **Inimigos com mira perfeita.**
- **Ataques sem telegrafia.**
- **Lógica de cérebro dentro da classe do corpo.**

---

## Exercício

**Parte 1 — o corpo (1,5 h).** Implemente `AVGEnemyCharacter` com reações, atordoamento e ragdoll. Teste com alvos manequins: tiros de frente e de costas produzem reações diferentes; o golpe fatal derruba o corpo para longe de você.

**Parte 2 — armas em inimigos (45 min).** Adicione `AttachSocketName` ao `UVGWeaponComponent` e equipe o vigia. Verifique que a arma dele usa o mesmo pipeline (munição, recarga, cadência).

**Parte 3 — o cérebro (1,5 h).** Implemente o `UVGSimpleCombatBrain`, monte o `BP_VigiaTeste` e jogue os cenários do Projeto 2. Corrija o `FindComponentByClass` no tick.

**Parte 4 — as dores (30 min).** Escreva no `DEVLOG.md` a lista "dores do cérebro ingênuo", com pelo menos seis itens observados jogando. Para cada um, adivinhe qual capítulo da Parte V o resolve.

---

## Desafio — o quinto estado

Adicione ao cérebro ingênuo o comportamento "**investigar**": ao **perder** a jogadora de vista, o vigia não volta imediatamente a `Idle`; ele gira para a última posição em que a viu e espera 3 segundos olhando para lá.

Faça isso **sem** reescrever a estrutura (mais um estado no `switch`, mais transições). Depois, responda no `DEVLOG.md`:

1. Quantas transições novas você precisou adicionar? Quantas transições existentes precisou alterar?
2. O que aconteceria se fosse necessário também "investigar um som" e "procurar cobertura ao ser atingido"? Desenhe o diagrama de estados resultante.
3. Por que esse diagrama já está ficando difícil de manter? *(O Capítulo 34 dá nome a esse problema — explosão de transições — e o Capítulo 37 apresenta a alternativa.)*

---

## Uso de IA

1. **Para revisar o inimigo:**
   > "Revise esta classe base de inimigo em Unreal Engine 5: reações a dano pontual por direção, atordoamento com limiar, janela e cooldown, e morte com ragdoll (desligar CMC e cápsula, perfil Ragdoll, impulso no osso atingido, desacoplar controller). Aponte problemas de ordem de eventos entre OnTakePointDamage e a morte, custo de ragdolls e casos de borda. [código]"

2. **Para justiça do inimigo:**
   > "Para um inimigo humano armado num jogo de terror em primeira pessoa (com combate limitado), proponha valores iniciais para: tempo de telegrafia, duração da rajada, cooldown, erro de mira inicial e mínimo, e decaimento do erro por disparo — e explique como cada um afeta a sensação de justiça e o TTD da jogadora. Sugira como medir em playtest."

3. **Para preparar a Parte V:**
   > "Tenho um cérebro de inimigo implementado como uma FSM plana num switch (Idle, Telegraph, Fire, Cooldown) com visão por trace direto. Liste, em ordem de impacto na ilusão de inteligência, as dez melhorias mais importantes (percepção, memória, navegação, cobertura, coordenação...) e, para cada uma, a ferramenta da Unreal Engine 5 que resolveria (AIController, AI Perception, Behavior Tree, Blackboard, EQS, Navigation)."

---

## Checklist

- [ ] Sei decompor um inimigo e sei o que o projeto já tinha pronto.
- [ ] Implementei reações por direção e parte do corpo, a partir do dano pontual.
- [ ] Implementei atordoamento com limiar, janela e cooldown.
- [ ] Implementei morte com ragdoll e impulso do golpe fatal.
- [ ] O inimigo usa o mesmo sistema de armas da jogadora.
- [ ] Implementei o cérebro ingênuo com telegrafia e erro de mira dosado.
- [ ] Tenho a lista de dores do cérebro ingênuo como requisitos da Parte V.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Physics Asset Editor**, **Ragdoll** e **Physical Animation Component** (para reações físicas sem morrer); **Animation Montage** (Capítulo 53 aprofunda).
- **GDC Vault** (gdcvault.com) — busque talks sobre *hit reactions*, *enemy readability* e *AI telegraphing* em jogos de ação.

---

➡️ **Próximo:** [Capítulo 31 — Objectives](cap-31-objectives.md)

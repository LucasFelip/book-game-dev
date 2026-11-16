# Capítulo 22 — Health/Damage

## Objetivo

Ao final deste capítulo você deve conseguir:

- usar o **sistema de dano da Unreal** (`TakeDamage`, `ApplyDamage`, `ApplyPointDamage`, `ApplyRadialDamage`, `UDamageType`, eventos de dano) e saber quando ele é suficiente;
- desenhar um **pipeline de dano** — filtrar, modificar, aplicar, anunciar — com um dono único;
- implementar o `UVGHealthComponent` com estados **vivo/morto**, transição de morte idempotente, multiplicadores por tipo de dano e **regeneração com atraso**;
- tratar a **morte** como um fluxo que atravessa sistemas: o corpo, o controller, o GameMode e a UI;
- usar **tipos de dano** como categorias de estímulo — inclusive a luz que afeta a Presença;
- conectar a arma do Capítulo 20 ao dano e fechar o primeiro ciclo completo do Galpão de Testes: atirar, acertar, ferir, abater.

---

## Contexto

O Capítulo 4 usou a vida como exemplo de quase tudo: o broadcast que acontecia antes da mudança de estado, a reentrância do "ao morrer, explode", o abate duplo de dois projéteis no mesmo frame. Agora a vida deixa de ser exemplo e vira código de produção — e todas aquelas armadilhas viram requisitos.

Vida e dano parecem triviais: um número que diminui. Mas o sistema de dano é uma **fronteira** entre muitos sistemas: armas e projéteis produzem dano; explosões, quedas e ambientes produzem dano; armaduras, tipos de inimigo e dificuldade modificam o dano; a HUD, o áudio, a IA, a narrativa e o placar reagem ao dano; a morte desencadeia animação, ragdoll, respawn, telas e, em multiplayer, pontuação. Um sistema de dano mal desenhado vira o lugar onde todos esses sistemas se acoplam uns aos outros.

---

## 22.1 O sistema de dano da Unreal

A engine oferece um sistema de dano básico, integrado a todo `AActor`:

### Aplicar dano

```cpp
// Dano genérico
UGameplayStatics::ApplyDamage(DamagedActor, 25.0f, InstigatorController, DamageCauser, UDamageType::StaticClass());

// Dano pontual — com o FHitResult do acerto (local, osso, normal) e a direção do disparo
UGameplayStatics::ApplyPointDamage(DamagedActor, 25.0f, ShotDirection, Hit,
                                   InstigatorController, DamageCauser, DamageTypeClass);

// Dano em área — com raio e, na variante com falloff, queda de intensidade com a distância
UGameplayStatics::ApplyRadialDamage(this, 80.0f, Origin, 400.0f, DamageTypeClass,
                                    IgnoredActors, DamageCauser, InstigatorController);
```

Os quatro "quem" do dano:

- **Damaged actor** — quem recebe.
- **Instigator** (um `AController`) — **quem é responsável**: o controller do jogador que atirou. É por ele que se atribui um abate, se verifica fogo amigo e se responde "quem me atacou?" na IA.
- **Damage causer** (um `AActor`) — **o que causou fisicamente**: a arma, o projétil, a explosão, a porta que esmagou.
- **Damage type** (uma classe `UDamageType`) — **que tipo** de dano: bala, explosão, queda, fogo, luz.

### Receber dano

Do lado de quem recebe, `AActor::TakeDamage` é a porta de entrada. Ela verifica se o ator pode ser danificado (`bCanBeDamaged`), e dispara eventos:

- `OnTakePointDamage` / `ReceivePointDamage` — para dano pontual, com local do acerto, osso e direção;
- `OnTakeRadialDamage` / `ReceiveRadialDamage` — para dano em área;
- `OnTakeAnyDamage` / `ReceiveAnyDamage` — para **qualquer** dano (disparado em todos os casos, com o valor final).

### Tipos de dano

`UDamageType` é uma **classe**, não um enum. Cada tipo é uma subclasse (`UVGDamageType_Bullet`, `UVGDamageType_Light`), com propriedades opcionais (por exemplo, se o dano é "causado pelo mundo", ou um impulso físico associado). Ao aplicar dano, passa-se a **classe** do tipo, e o receptor recebe o objeto padrão (CDO) correspondente. A vantagem de usar classes é a **hierarquia**: `UVGDamageType_Explosion` pode derivar de `UVGDamageType_Physical`, e um multiplicador para "físico" vale para ambos.

### E o Gameplay Ability System?

A Unreal tem um sistema muito mais completo para atributos, efeitos e habilidades: o **Gameplay Ability System** (GAS), usado em projetos da própria Epic (como a Lyra) e em muitos jogos com sistemas de combate ricos (RPGs, jogos de ação com dezenas de habilidades, multiplayer competitivo com muitos efeitos). Ele modela vida, dano, *buffs* e *debuffs* como atributos e efeitos, com replicação e predição embutidas.

Para a Vigília — uma jogadora frágil, uma criatura que não morre, alguns vigias — o GAS é complexidade sem retorno (critério 6 do Capítulo 6: a favor da engine, sim, mas proporcional ao problema). O sistema de dano básico, mais um componente de vida bem desenhado, é suficiente. Se você um dia fizer um jogo com muitas habilidades e efeitos, estude o GAS: ele resolve exatamente os problemas que este capítulo resolve "na mão", em escala.

---

## 22.2 O pipeline de dano

Todo dano que chega a um ator passa, conceitualmente, por quatro etapas:

```text
  dano chega (TakeDamage / OnTakeAnyDamage)
        │
        ▼
  1. FILTRAR      Está vivo? É invulnerável? É fogo amigo? O tipo de dano o afeta?
        │ passou
        ▼
  2. MODIFICAR    Multiplicador por tipo de dano, armadura, dificuldade
        │         (multiplicadores de ponto de acerto — cabeça — vêm de QUEM ATIRA, Cap. 27)
        ▼
  3. APLICAR      vida = clamp(vida − dano, 0, máx)        ← o DONO muda o estado
        │
        ▼
  4. ANUNCIAR     OnHealthChanged, OnDamaged(relatório)    ← depois do estado consistente
        │
        ▼ vida chegou a 0 e estava vivo?
  TRANSIÇÃO       Alive → Dead (uma única vez)  ──►  OnDied(relatório)
```

Três princípios do Capítulo 4 estão nesse diagrama:

- **O dono decide a transição** (seção 4.6). O projétil não decide que matou; ele pede dano. Só o componente de vida decide que houve morte — e decide **uma vez**.
- **Anunciar depois de mudar** (seção 4.5). A HUD que recebe `OnHealthChanged` lê a vida já atualizada.
- **Transição guardada** — de `Dead`, nenhum dano produz outra morte. É o que resolve o abate duplo e a reentrância do "ao morrer, explode e se fere".

> 🌉 **Ponte:** o pipeline é um *chain of responsibility* de filtros e transformações seguido de um comando aplicado por um agregado, que então publica eventos de domínio. É exatamente o fluxo de um caso de uso bem desenhado — com a diferença de que ele pode rodar dezenas de vezes por segundo (uma submetralhadora contra um inimigo) e precisa ser barato.

### Quem modifica o quê

Uma decisão sutil: **multiplicadores de ponto de acerto** (cabeça causa o dobro) pertencem a quem **atira**, não a quem recebe? Há argumentos para os dois lados. A Vigília adota:

- **Quem atira** calcula o dano bruto do disparo, incluindo o multiplicador de parte do corpo (ele tem o `FHitResult` com o osso atingido e os dados da arma — Capítulo 27).
- **Quem recebe** aplica modificadores **próprios**: resistência por tipo de dano, invulnerabilidade, dificuldade.

A regra prática: **cada multiplicador mora com quem tem a informação para calculá-lo.**

---

## 22.3 Regeneração

Muitos shooters modernos usam **vida regenerativa**: após algum tempo sem levar dano, a vida volta a subir. **[FATO PÚBLICO]** A série Call of Duty é frequentemente citada como uma das que popularizaram a vida regenerativa em campanhas de shooters, a partir de *Call of Duty 2* (2005); outros jogos da época, como a série Halo, já usavam escudos que se recarregavam.

O efeito de design é profundo:

- **Sem regeneração** (kits médicos): cada dano é permanente até haver cura; o jogador entra no próximo encontro com o "saldo" do anterior. Tensão acumulada, economia de cura.
- **Com regeneração**: cada encontro é avaliado isoladamente; o jogador é incentivado a se proteger e recuar para recuperar. Ritmo de "avançar, se ferir, abrigar-se, avançar".

Os parâmetros que definem a sensação:

```text
 atraso para começar a regenerar (ex.: 4–8 s sem dano)
 taxa de regeneração (vida por segundo)
 teto de regeneração (regenera até 100%? até o próximo "bloco"?)
```

### A Vigília: "o primeiro toque é um aviso"

O documento de combate (Capítulo 21) definiu: **dois toques da Presença matam; o primeiro é aviso**. Isso se traduz em números de um componente de vida genérico:

```text
 MaxHealth ............ 100
 dano de um toque ..... 60      → 1 toque: sobrevive (40); 2 toques: morre
 regeneração .......... após 8 s sem dano, volta a 100 a 15/s
```

O resultado: a jogadora tocada uma vez sabe que está em perigo (feedback forte, Capítulo 21), tem uma janela para fugir e se esconder, e, se conseguir ficar segura por tempo suficiente, volta ao estado inicial. É regeneração a serviço do **pacing** — o alívio do Capítulo 5.

---

## 22.4 A morte como fluxo entre sistemas

Quando a vida chega a zero, muitos sistemas precisam reagir — e é exatamente aí que um sistema de dano mal desenhado vira um nó de dependências. A solução é a de sempre: **o componente anuncia; cada sistema reage ao que lhe diz respeito**.

```text
                       UVGHealthComponent.OnDied(relatório)
                                   │
         ┌─────────────────────────┼──────────────────────────┬────────────────────┐
         ▼                         ▼                          ▼                    ▼
   O CORPO (pawn)           O CONTROLLER (Cap. 16)      A IA / O MUNDO        APRESENTAÇÃO
   para o movimento,        empilha o modo "Dead",      quem estava caçando   som, câmera, tela
   desliga colisão de       pede ao GameMode para       a jogadora perde      escurece
   interação, ragdoll       reiniciar quando a          o alvo
   (Cap. 30), some          jogadora "continuar"
   depois de um tempo              │
                                   ▼
                          O GAMEMODE (Cap. 10)
                          decide ONDE e QUANDO renascer
                          (último checkpoint — Cap. 56)
```

Cada seta é uma responsabilidade que já foi atribuída em capítulos anteriores:

- O **corpo** reage como corpo (Capítulo 10: o pawn morre).
- O **controller** reage como sessão do jogador (Capítulo 16: a vontade persiste; o modo muda).
- O **GameMode** decide a regra de respawn (Capítulo 10: regras no GameMode).

O componente de vida **não sabe** de nada disso. Ele é reutilizável numa caixa destrutível, num vigia, numa lâmpada que pode ser quebrada a tiros.

---

## 22.5 Tipos de dano como canais de estímulo

Na Vigília, o tipo de dano mais importante não causa dano nenhum: é a **luz**. O sinalizador atinge a Presença com um evento de dano do tipo `UVGDamageType_Light`, e a Presença **reage** — recua e fica atordoada —, mas sua "vida" não existe.

Por que usar o sistema de dano para algo que não é dano? Porque ele já é o **canal padrão** pelo qual "algo me atingiu, com esta intensidade, vindo deste causador, deste instigador, neste ponto" chega a um ator. Reusar o canal significa que:

- o sinalizador não precisa saber que a Presença é especial — ele aplica dano de luz como aplicaria a qualquer coisa;
- uma lâmpada sobrecarregada que explode, uma luz de emergência acesa sobre a Presença, ou a lanterna em sobrecarga (Capítulo 51) podem usar o **mesmo** canal;
- a Presença decide, por tipo, como reage — e ignora tudo que não é luz.

A Presença terá um componente de vida? Não. Ela terá um **componente de reação** (Capítulo 30 e Parte V) que se inscreve em `OnTakeAnyDamage` e trata o tipo `Light`. O componente de vida é para quem pode morrer.

> **Atenção a um detalhe da engine:** o evento `OnTakeAnyDamage` só é disparado quando o dano final calculado por `TakeDamage` é **diferente de zero**, e só se o ator puder ser danificado (`bCanBeDamaged`). Para que a luz "chegue" à Presença, ela precisa ter `bCanBeDamaged = true`, e o sinalizador precisa aplicar um valor positivo (o valor é a **intensidade** do estímulo, interpretada pela reação).

---

## Comparação com o desenvolvimento tradicional

| Dano | O que você conhece | Onde a analogia cai |
|---|---|---|
| Pipeline filtrar → modificar → aplicar → anunciar | Caso de uso com validação, regras e eventos de domínio | Pode rodar dezenas de vezes por segundo no mesmo objeto |
| Instigator vs. causer | Usuário responsável vs. sistema que executou (auditoria) | Ambos são usados em tempo real pela IA e pelo placar |
| `UDamageType` como classe | Hierarquia de tipos de evento | Herança permite multiplicadores por categoria |
| Morte idempotente | Consumidor idempotente em mensageria | A "mensagem duplicada" vem do mesmo frame, sem rede |
| Tipos de dano como canal de estímulo | Reuso de um barramento de eventos padronizado | O "evento" carrega física (ponto, direção, impulso) |

---

## Implementação

### 1. Tipos de dano do projeto

```cpp
// Source/Vigilia/Combat/VGDamageTypes.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/DamageType.h"
#include "VGDamageTypes.generated.h"

/** Dano físico (balas, impactos, quedas). */
UCLASS()
class VIGILIA_API UVGDamageType_Physical : public UDamageType
{
    GENERATED_BODY()
};

UCLASS()
class VIGILIA_API UVGDamageType_Bullet : public UVGDamageType_Physical
{
    GENERATED_BODY()
};

/** Luz intensa (sinalizador, sobrecarga). Não fere humanos; repele a Presença. */
UCLASS()
class VIGILIA_API UVGDamageType_Light : public UDamageType
{
    GENERATED_BODY()
};

/** O toque da Presença. */
UCLASS()
class VIGILIA_API UVGDamageType_Presence : public UDamageType
{
    GENERATED_BODY()
};
```

### 2. O componente de vida

```cpp
// Source/Vigilia/Combat/VGHealthComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGHealthComponent.generated.h"

class UDamageType;
class UVGHealthComponent;

UENUM(BlueprintType)
enum class EVGLifeState : uint8
{
    Alive,
    Dead
};

/** O que aconteceu num dano: o que os ouvintes precisam para reagir. */
USTRUCT(BlueprintType)
struct FVGDamageReport
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Damage")
    float Amount = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Damage")
    float HealthAfter = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Damage")
    TObjectPtr<const UDamageType> DamageType;

    UPROPERTY(BlueprintReadOnly, Category = "Damage")
    TObjectPtr<AController> Instigator;

    UPROPERTY(BlueprintReadOnly, Category = "Damage")
    TObjectPtr<AActor> Causer;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGDamagedSignature,
    UVGHealthComponent*, Health, const FVGDamageReport&, Report);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGDiedSignature,
    UVGHealthComponent*, Health, const FVGDamageReport&, Report);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGHealthChangedSignature, UVGHealthComponent*, Health);

/**
 * Dono único da vida de um ator. Pipeline: filtrar → modificar → aplicar → anunciar.
 * Recebe dano pelo sistema padrão da engine (OnTakeAnyDamage do dono).
 * Mudanças contínuas (regeneração) não são anunciadas a cada frame: consulte GetHealthRatio().
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGHealthComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGHealthComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    /** Entrada do pipeline. Pública para testes e para fontes de dano fora do sistema da engine. */
    void ReceiveDamage(float Amount, const UDamageType* DamageType, AController* Instigator, AActor* Causer);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Health")
    void Heal(float Amount);

    /** Volta à vida com a vida cheia (checkpoint). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Health")
    void Revive();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Health")
    float GetHealth() const { return Health; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Health")
    float GetHealthRatio() const { return MaxHealth > 0.0f ? Health / MaxHealth : 0.0f; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Health")
    bool IsAlive() const { return LifeState == EVGLifeState::Alive; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Health")
    FVGDamagedSignature OnDamaged;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Health")
    FVGDiedSignature OnDied;

    /** Mudanças discretas (dano, cura, reviver, fim da regeneração). */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Health")
    FVGHealthChangedSignature OnHealthChanged;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Health", meta = (ClampMin = "1.0"))
    float MaxHealth = 100.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Health")
    bool bInvulnerable = false;

    /** Multiplicador por tipo de dano (vale para subclasses). Tipos ausentes: 1.0. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Health")
    TMap<TSubclassOf<UDamageType>, float> DamageMultipliers;

    /** 0 = sem regeneração. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Health|Regen", meta = (ClampMin = "0.0"))
    float RegenRatePerSecond = 0.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Health|Regen", meta = (ClampMin = "0.0"))
    float RegenDelay = 8.0f;

    /** Até que fração da vida máxima a regeneração recupera. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Health|Regen", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float RegenMaxRatio = 1.0f;

private:
    UFUNCTION()
    void HandleAnyDamage(AActor* DamagedActor, float Damage, const UDamageType* DamageType,
                         AController* InstigatedBy, AActor* DamageCauser);

    float GetMultiplier(const UDamageType* DamageType) const;
    void ScheduleRegen();
    void StartRegen();

    UPROPERTY(VisibleInstanceOnly, Category = "Vigilia|Health")
    float Health = 100.0f;

    UPROPERTY(VisibleInstanceOnly, Category = "Vigilia|Health")
    EVGLifeState LifeState = EVGLifeState::Alive;

    FTimerHandle RegenDelayHandle;
};
```

```cpp
// Source/Vigilia/Combat/VGHealthComponent.cpp
#include "Combat/VGHealthComponent.h"

#include "GameFramework/DamageType.h"
#include "TimerManager.h"

UVGHealthComponent::UVGHealthComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false; // só tica regenerando
}

void UVGHealthComponent::BeginPlay()
{
    Super::BeginPlay();
    Health = MaxHealth;
    GetOwner()->OnTakeAnyDamage.AddDynamic(this, &UVGHealthComponent::HandleAnyDamage);
}

void UVGHealthComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetOwner()->OnTakeAnyDamage.RemoveDynamic(this, &UVGHealthComponent::HandleAnyDamage);
    if (const UWorld* World = GetWorld())
    {
        World->GetTimerManager().ClearTimer(RegenDelayHandle);
    }
    Super::EndPlay(EndPlayReason);
}

void UVGHealthComponent::HandleAnyDamage(AActor* DamagedActor, float Damage, const UDamageType* DamageType,
                                         AController* InstigatedBy, AActor* DamageCauser)
{
    ReceiveDamage(Damage, DamageType, InstigatedBy, DamageCauser);
}

float UVGHealthComponent::GetMultiplier(const UDamageType* DamageType) const
{
    if (!DamageType)
    {
        return 1.0f;
    }
    // Procura o multiplicador do tipo ou do ancestral mais próximo (Bullet herda de Physical).
    // UClass* (não const UClass*): TSubclassOf só se constrói implicitamente de ponteiro não-const.
    for (UClass* Class = DamageType->GetClass(); Class; Class = Class->GetSuperClass())
    {
        if (const float* Multiplier = DamageMultipliers.Find(Class))
        {
            return *Multiplier;
        }
    }
    return 1.0f;
}

void UVGHealthComponent::ReceiveDamage(float Amount, const UDamageType* DamageType,
                                       AController* Instigator, AActor* Causer)
{
    // 1. Filtrar
    if (LifeState == EVGLifeState::Dead || bInvulnerable || Amount <= 0.0f)
    {
        return;
    }

    // 2. Modificar
    const float FinalAmount = Amount * GetMultiplier(DamageType);
    if (FinalAmount <= 0.0f)
    {
        return; // tipo de dano que não afeta este ator (ex.: luz num humano)
    }

    // 3. Aplicar (o dono muda o estado)
    Health = FMath::Clamp(Health - FinalAmount, 0.0f, MaxHealth);
    SetComponentTickEnabled(false); // dano interrompe a regeneração em curso

    FVGDamageReport Report;
    Report.Amount = FinalAmount;
    Report.HealthAfter = Health;
    Report.DamageType = DamageType;
    Report.Instigator = Instigator;
    Report.Causer = Causer;

    const bool bDied = (Health <= 0.0f);
    if (bDied)
    {
        LifeState = EVGLifeState::Dead; // transição única: de Dead nada volta a morrer
    }

    // 4. Anunciar (depois do estado consistente)
    OnDamaged.Broadcast(this, Report);
    OnHealthChanged.Broadcast(this);

    if (bDied)
    {
        OnDied.Broadcast(this, Report);
    }
    else
    {
        ScheduleRegen();
    }
}

void UVGHealthComponent::Heal(float Amount)
{
    if (LifeState == EVGLifeState::Dead || Amount <= 0.0f)
    {
        return;
    }
    Health = FMath::Min(Health + Amount, MaxHealth);
    OnHealthChanged.Broadcast(this);
}

void UVGHealthComponent::Revive()
{
    LifeState = EVGLifeState::Alive;
    Health = MaxHealth;
    OnHealthChanged.Broadcast(this);
}

void UVGHealthComponent::ScheduleRegen()
{
    if (RegenRatePerSecond <= 0.0f || !GetWorld())
    {
        return;
    }
    GetWorld()->GetTimerManager().SetTimer(RegenDelayHandle, this, &UVGHealthComponent::StartRegen, RegenDelay, false);
}

void UVGHealthComponent::StartRegen()
{
    if (LifeState == EVGLifeState::Alive && Health < MaxHealth * RegenMaxRatio)
    {
        SetComponentTickEnabled(true);
    }
}

void UVGHealthComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                       FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    const float Cap = MaxHealth * RegenMaxRatio;
    Health = FMath::Min(Health + RegenRatePerSecond * DeltaTime, Cap);
    if (Health >= Cap)
    {
        SetComponentTickEnabled(false);
        OnHealthChanged.Broadcast(this); // fim da regeneração: um anúncio discreto
    }
}
```

### Explicação das decisões

- **A entrada é o evento padrão da engine.** Armas, projéteis, explosões e qualquer coisa que use `UGameplayStatics::Apply*Damage` funcionam sem conhecer o componente. `ReceiveDamage` é pública para testes e para fontes de dano que não passem pela engine.
- **Transição única para `Dead`.** O abate duplo do Capítulo 4 é impossível: o segundo projétil do mesmo frame chega a um componente já morto e é filtrado. A reentrância ("ao morrer, explode e se fere") também: o ouvinte de `OnDied` que aplica dano ao próprio ator encontra `LifeState == Dead`.
- **Multiplicadores por hierarquia de tipos**, subindo pela cadeia de superclasses. Um multiplicador para `UVGDamageType_Physical` vale para `UVGDamageType_Bullet` — a vantagem de tipos de dano serem classes. O custo da busca (poucas iterações por dano) é irrelevante.
- **Luz num humano**: com `DamageMultipliers[UVGDamageType_Light] = 0`, o dano é filtrado sem anúncio. Os vigias são configurados assim.
- **Regeneração com tick ligado só enquanto regenera**, e um único anúncio ao terminar. A HUD consulta `GetHealthRatio()` durante a regeneração (Capítulo 4: contínuo → consulta).
- **`FVGDamageReport` com `TObjectPtr`** em `UPROPERTY`: a struct carrega ponteiros para `UObject`s e é passada por delegates dinâmicos; reflexão nos membros é obrigatória (Capítulo 11).
- **Local e direção do acerto ficam de fora.** Quem precisa disso (a reação do inimigo, o indicador direcional de dano) se inscreve em `OnTakePointDamage` do ator. O componente de vida só cuida de **quanto**.

### 3. O teste

```cpp
// Source/Vigilia/Tests/VGHealthComponentTest.cpp
#include "Misc/AutomationTest.h"
#include "Combat/VGHealthComponent.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGHealthDamageAndDeathTest,
    "Vigilia.Combat.Health.DamageAndDeath",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGHealthDamageAndDeathTest::RunTest(const FString& Parameters)
{
    UVGHealthComponent* Health = NewObject<UVGHealthComponent>(); // sem BeginPlay: vida padrão 100

    int32 DeathCount = 0;
    // Delegates dinâmicos exigem UFUNCTION; para contar mortes no teste, observamos o estado.
    Health->ReceiveDamage(60.0f, nullptr, nullptr, nullptr);
    TestEqual(TEXT("Primeiro toque deixa 40"), Health->GetHealth(), 40.0f);
    TestTrue(TEXT("Continua viva"), Health->IsAlive());

    Health->ReceiveDamage(60.0f, nullptr, nullptr, nullptr);
    TestEqual(TEXT("Vida não fica negativa"), Health->GetHealth(), 0.0f);
    TestFalse(TEXT("Morreu"), Health->IsAlive());
    DeathCount += Health->IsAlive() ? 0 : 1;

    Health->ReceiveDamage(60.0f, nullptr, nullptr, nullptr); // dano depois da morte: filtrado
    TestEqual(TEXT("Morto não recebe dano"), Health->GetHealth(), 0.0f);

    Health->Heal(50.0f);
    TestEqual(TEXT("Morto não é curado"), Health->GetHealth(), 0.0f);

    Health->Revive();
    TestTrue(TEXT("Revive viva"), Health->IsAlive());
    TestEqual(TEXT("Revive com vida cheia"), Health->GetHealth(), 100.0f);

    TestEqual(TEXT("Uma única morte"), DeathCount, 1);
    return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
```

O teste verifica as **invariantes** — vida nunca negativa, morte única, morto não recebe dano nem cura — sem mundo, sem tempo e sem física. (Para verificar o número de **eventos** `OnDied` disparados, seria necessário um objeto ouvinte com uma `UFUNCTION`; o exercício pede isso.)

### 4. A arma passa a causar dano

🔁 **Refatoração do Capítulo 20.** O trace de teste de `AVGWeapon::PerformShot` passa a aplicar dano pontual. `UVGWeaponData` ganha o tipo de dano:

```cpp
// VGWeaponData.h (adição)
UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|Firing")
TSubclassOf<UDamageType> DamageType;
```

```cpp
// VGWeapon.cpp — PerformShot_Implementation (trecho alterado)
#include "Kismet/GameplayStatics.h"

    if (bHit)
    {
        // Simplificação: sem dispersão, penetração nem multiplicador por parte do corpo (Cap. 27).
        UGameplayStatics::ApplyPointDamage(Hit.GetActor(), Data->Damage, ViewRotation.Vector(), Hit,
                                           GetInstigatorController(), this, Data->DamageType);
    }
```

A arma não sabe se o alvo tem vida, se é invulnerável ou se é a Presença. Ela aplica dano pelo canal padrão, com o **instigador** (quem atirou) e o **causador** (a própria arma).

### 5. A morte da jogadora

O fluxo da seção 22.4, implementado com o que os capítulos anteriores já prepararam (é também a solução de referência do desafio do Capítulo 16):

```cpp
// VGCharacter.h (adições)
protected:
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGHealthComponent> Health;

    virtual void BeginPlay() override;

private:
    UFUNCTION()
    void HandleDied(UVGHealthComponent* HealthComponent, const FVGDamageReport& Report);
```

```cpp
// VGCharacter.cpp (adições)
#include "Combat/VGHealthComponent.h"
#include "Player/VGPlayerController.h"

// no construtor:
//   Health = CreateDefaultSubobject<UVGHealthComponent>(TEXT("Health"));

void AVGCharacter::BeginPlay()
{
    Super::BeginPlay();
    Health->OnDied.AddDynamic(this, &AVGCharacter::HandleDied);
}

void AVGCharacter::HandleDied(UVGHealthComponent* HealthComponent, const FVGDamageReport& Report)
{
    // O CORPO reage como corpo.
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false); // Simplificação: sem ragdoll até o Cap. 30

    // A VONTADE reage como sessão do jogador.
    if (AVGPlayerController* PC = Cast<AVGPlayerController>(GetController()))
    {
        PC->HandlePawnDied(this);
    }
    SetLifeSpan(5.0f); // o corpo some depois; o controller já seguiu em frente
}
```

```cpp
// VGPlayerController (adições)
public:
    /** O corpo morreu: modo Dead; ao "continuar", pede ao GameMode para reiniciar. */
    void HandlePawnDied(APawn* DeadPawn);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Player")
    void RequestRespawn();
```

```cpp
// VGPlayerController.cpp
#include "GameFramework/GameModeBase.h"

void AVGPlayerController::HandlePawnDied(APawn* DeadPawn)
{
    UnPossess();
    SetViewTarget(DeadPawn);           // a câmera continua no corpo por um instante
    PushInputMode(EVGInputMode::Dead); // novo modo: só "continuar" (IMC_Morte)
}

void AVGPlayerController::RequestRespawn()
{
    PopInputMode(EVGInputMode::Dead);
    if (AGameModeBase* GameMode = GetWorld()->GetAuthGameMode())
    {
        GameMode->RestartPlayer(this); // a REGRA de onde renascer é do GameMode (Cap. 56: checkpoint)
    }
}
```

`EVGInputMode` ganha o valor `Dead`, configurado no `BP_VGPlayerController` com um `IMC_Morte` (uma ação "continuar" ligada a `RequestRespawn`). `GetAuthGameMode()` retorna o GameMode — que, lembre-se do Capítulo 10, só existe no servidor; em single-player, o processo é o servidor.

Repare na divisão: nenhum sistema faz o trabalho de outro. O componente anuncia; o corpo se desliga; o controller muda o modo e pede; o GameMode decide.

---

## Projeto 2 — o Galpão ganha alvos

1. **`BP_Alvo`** (ator com malha de cilindro e `UVGHealthComponent`, `MaxHealth = 100`): ao morrer, tomba (aplique um impulso e ative física na malha) e reaparece depois de 3 s (`Revive`).
2. Um texto de debug sobre cada alvo mostrando a vida (consulta a `GetHealthRatio()`).
3. **`BP_AlvoBlindado`** com `DamageMultipliers[UVGDamageType_Physical] = 0.5`.
4. **`BP_AlvoSombra`**, um alvo que só é afetado por `UVGDamageType_Light` (multiplicador 0 para físico, 1 para luz) — um protótipo de como a regra da Presença será comunicada ao jogador: tiros comuns não fazem nada.
5. Um **volume de dano** (um `AVGEventTrigger` + Blueprint que aplica 30 de dano do tipo `Physical` a cada segundo enquanto a jogadora estiver dentro) — para testar a morte e o respawn da jogadora.

Compare o TTK observado com o previsto pelo simulador do Capítulo 21.

---

## Decisões arquiteturais

1. **Sistema de dano da engine como canal; `UVGHealthComponent` como dono da vida.** Sem GAS na Vigília.
2. **Pipeline filtrar → modificar → aplicar → anunciar**, com transição única para `Dead`.
3. **Cada multiplicador mora com quem tem a informação:** parte do corpo com quem atira; resistências com quem recebe.
4. **Tipos de dano como classes com hierarquia**, inclusive para estímulos que não ferem (luz).
5. **Regeneração com atraso, tick só durante a regeneração, anúncios discretos.**
6. **A morte é um fluxo entre sistemas:** componente anuncia; corpo, controller e GameMode reagem cada um no seu papel.
7. **Local e direção do acerto ficam fora do componente de vida.**

---

## Armadilhas

- **A arma decidindo que matou.**
- **Morte disparada duas vezes** (sem transição guardada).
- **Broadcast de `OnHealthChanged` a cada frame** durante a regeneração.
- **Esquecer `bCanBeDamaged`** ou aplicar dano zero e esperar o evento.
- **Instigator nulo** — perde-se a autoria do dano (placar, IA, fogo amigo).
- **O componente de vida chamando o GameMode, a UI ou a câmera.**
- **Usar enums para tipos de dano** e perder a hierarquia.
- **Destruir o pawn imediatamente na morte**, cortando animações e a câmera.

---

## Exercício

**Parte 1 — o componente (1,5 h).** Implemente os tipos de dano, o `UVGHealthComponent` e o teste. Escreva um segundo teste que conte quantas vezes `OnDied` é disparado, usando um pequeno `UObject` ouvinte com uma `UFUNCTION` (crie-o no próprio arquivo de teste).

**Parte 2 — o Galpão (1,5 h).** Faça a arma aplicar dano e monte os alvos do Projeto 2. Meça o TTK real com a pistola e o fuzil e compare com o simulador.

**Parte 3 — morte e respawn (1 h).** Implemente o fluxo de morte da jogadora com o modo `Dead` e o volume de dano. Verifique: a câmera fica no corpo, a jogadora renasce no `Player Start`, o corpo antigo some após 5 s, e o novo corpo tem a vida cheia.

**Parte 4 — "o primeiro toque é um aviso" (30 min).** Configure a regeneração da jogadora (atraso 8 s, 15/s). Use o volume de dano com 60 de dano único (não contínuo) para simular o toque da Presença. Entre, saia, espere, entre de novo. A regra se comporta como o documento de combate pede?

---

## Desafio — dano em área com cobertura

Implemente uma **explosão** (um barril no Galpão que explode ao receber dano suficiente):

1. O barril tem um `UVGHealthComponent`; ao morrer, aplica `ApplyRadialDamageWithFalloff` (dano máximo no centro, mínimo na borda) e um impulso físico nas caixas próximas.
2. A explosão **não deve atravessar paredes**: verifique como a função de dano radial da engine trata obstruções (há um canal de prevenção de dano nos parâmetros) e configure-o.
3. Coloque dois barris próximos: a explosão do primeiro deve detonar o segundo — **uma reação em cadeia**. Verifique que nenhum barril explode duas vezes (a transição única do componente de vida) e que não há recursão infinita.

Pergunta para o `DEVLOG.md`: a reação em cadeia acontece no **mesmo frame** (o segundo barril morre dentro do broadcast do primeiro). Isso é um problema? O que mudaria se você quisesse um pequeno atraso entre as explosões, para efeito dramático? *(Releia "adiar efeitos colaterais" no Capítulo 4, seção 4.5.)*

---

## Uso de IA

1. **Para revisar o pipeline:**
   > "Revise este componente de vida da Unreal Engine 5. Verifique: transição de morte única, comportamento com dano após a morte, reentrância (um ouvinte de OnDied que aplica dano), ordem estado → broadcast, regeneração (tick, interrupção por dano, anúncios), multiplicadores por hierarquia de UDamageType e limpeza em EndPlay. [código]"

2. **Para decidir entre sistema simples e GAS:**
   > "Para um jogo com [descrição: número de habilidades, efeitos temporários, multiplayer, atributos], compare implementar vida e dano com um componente próprio sobre o sistema de dano básico da Unreal versus usar o Gameplay Ability System. Liste o custo de aprendizado, o que cada abordagem resolve de graça e o ponto em que o componente próprio passa a ser reimplementação do GAS."

3. **Para design de vida:**
   > "Compare vida regenerativa, vida por kits de cura e o modelo 'dois toques, o primeiro é aviso' num jogo de terror em primeira pessoa. Para cada um, descreva a dinâmica e a estética esperadas (MDA), os parâmetros principais e como eles afetam o pacing."

---

## Checklist

- [ ] Sei usar `ApplyDamage`, `ApplyPointDamage`, `ApplyRadialDamage` e os eventos de dano do `AActor`.
- [ ] Sei o papel de instigator, causer e damage type.
- [ ] Implementei o pipeline filtrar → modificar → aplicar → anunciar com transição única.
- [ ] Sei onde mora cada multiplicador de dano.
- [ ] Implementei regeneração com atraso sem anúncios por frame.
- [ ] Implementei a morte como fluxo entre corpo, controller e GameMode.
- [ ] Entendo tipos de dano como canais de estímulo (a luz e a Presença).
- [ ] A arma causa dano e o Galpão tem alvos com vida, resistências e respawn.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre **Damage** em `AActor` e `UGameplayStatics`, e a introdução ao **Gameplay Ability System**.
- **Lyra Starter Game** — como a Epic modela vida e dano com o GAS (compare com o seu componente depois de implementá-lo).
- **Código-fonte da engine** — `Actor.cpp` (procure `TakeDamage`) e `GameplayStatics.cpp` (procure `ApplyRadialDamageWithFalloff`), para ver exatamente quando cada evento é disparado.

---

➡️ **Próximo:** [Capítulo 23 — Gameplay State](cap-23-gameplay-state.md)

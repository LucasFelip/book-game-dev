# Capítulo 32 — Spawn System

## Objetivo

Ao final deste capítulo você deve conseguir:

- evoluir o spawner do Capítulo 8 para um **sistema de spawn**: pontos de spawn, estratégias de escolha, spawn seguro e ondas;
- escolher pontos de spawn **fora da visão da jogadora** (produto escalar + linha de visão) e **longe o bastante** dela;
- controlar um **orçamento** de inimigos vivos e de inimigos **ativos** — e entender por que ele é uma ferramenta de design e de performance;
- implementar **object pooling** genérico e saber quando ele vale a pena;
- decompor como shooters criam **sensação de escala e intensidade com poucos NPCs** (Battlefield, Call of Duty);
- **concluir o Projeto 2** e fechar a Parte IV.

---

## Contexto

O `AVGSpawner` do Capítulo 8 criava atores num ponto fixo, a um intervalo fixo, até um limite. O desafio daquele capítulo perguntava como não criar inimigos **na frente da jogadora**, e a resposta ficou pela metade: o produto escalar dizia se o ponto estava no cone de visão, mas não se havia uma parede no caminho. Agora o projeto tem tudo que faltava: traces (Capítulo 15), produto escalar (Capítulo 17), inimigos de verdade (Capítulo 30), um barramento que anuncia mortes (Capítulo 24) e objetivos (Capítulo 31).

Spawn parece logística, e é design. **Onde, quando e quantos** inimigos aparecem define o ritmo de um encontro (Capítulo 5, pacing), a justiça (ninguém deve nascer atrás da jogadora e atirar no mesmo segundo), a sensação de escala e — num mundo aberto — a ilusão de que o mundo está cheio (o estudo de caso de GTA V, Capítulo 8).

---

## 32.1 Pontos de spawn

Em vez de um spawner que cria atores na própria posição, o sistema usa **pontos de spawn** espalhados pelo nível pelo designer — atores leves, com uma seta indicando a orientação inicial e **tags** que dizem para que servem:

```text
AVGSpawnPoint
  posição e orientação (seta visível no editor)
  tags: Spawn.Enemy.Guard, Spawn.Area.GalpaoNorte, ...
  raio de verificação (para spawn seguro)
```

Um **spawner de ondas** referencia um conjunto de pontos (ou os encontra por tag, numa área) e decide, a cada spawn, **qual** usar. Separar "onde pode nascer" (pontos, autorados pelo level designer) de "quando e quanto nasce" (ondas, autoradas pelo designer de encontro) é a mesma separação de responsabilidades de todo o livro — cada um ajusta o seu sem tocar no do outro.

---

## 32.2 Escolhendo o ponto

### Regras de rejeição

Um ponto é **descartado** se:

1. **A jogadora está vendo o ponto** — dentro do cone de visão dela (produto escalar com a direção da câmera, Capítulo 17) **e** com linha de visão livre (trace da câmera até o ponto, Capítulo 15). É a resposta completa ao desafio do Capítulo 8.
2. **Está perto demais** da jogadora (um inimigo que nasce a 3 m é uma emboscada injusta, a menos que seja um susto roteirizado — e aí não é spawn sistêmico).
3. **Está ocupado** — há algo no lugar onde a cápsula do inimigo ficaria (spawn seguro, seção 32.3).
4. **Foi usado recentemente** — para não criar todos os inimigos de uma onda no mesmo ponto.

### Regras de preferência

Entre os pontos válidos, a escolha pode preferir os **mais distantes**, os que ficam **à frente da rota** da jogadora (para que os inimigos venham "de onde ela vai"), ou simplesmente sortear com pesos. Uma forma simples e robusta: **pontuar** cada ponto válido e sortear entre os melhores — o embrião das consultas espaciais com pontuação do EQS (Capítulo 39).

```text
 para cada ponto:
   rejeita se visível, perto demais, ocupado ou usado há pouco
   pontuação = distância normalizada (+ bônus por tag preferida) (+ ruído pequeno)
 escolhe aleatoriamente entre os 3 melhores
```

O ruído e o sorteio entre os melhores evitam previsibilidade (os inimigos não vêm **sempre** do mesmo ponto), sem abrir mão da qualidade da escolha.

> **Custo:** cada ponto avaliado custa um trace de visibilidade. Com dezenas de pontos e spawns frequentes, isso soma. Avaliar só os pontos da área ativa, e só no momento do spawn (não todo frame), mantém o custo pequeno.

---

## 32.3 Spawn seguro

Criar um ator dentro de uma parede, de uma caixa física ou de outro inimigo produz comportamentos estranhos — o personagem é empurrado, fica preso, atravessa o chão. Há dois níveis de proteção:

- **Na hora de escolher**: um **teste de sobreposição** com a forma da cápsula do inimigo no ponto (`OverlapBlockingTestByChannel` com uma `FCollisionShape` de cápsula) descarta pontos ocupados.
- **Na hora de criar**: o parâmetro de colisão do spawn (Capítulo 8) — `DontSpawnIfColliding` ou `AdjustIfPossibleButDontSpawnIfColliding` — impede ou ajusta.

O primeiro é preferível: o segundo falha silenciosamente, e o spawner precisaria tentar outro ponto de qualquer forma.

---

## 32.4 Ondas e orçamento

Uma **onda** é uma lista do que criar (classe, quantidade), com parâmetros de ritmo:

```text
UVGWaveData
  entradas: [ (BP_VigiaTeste, 3), (BP_VigiaPesado, 1) ]
  intervalo entre spawns: 1,5 s
  máximo vivos ao mesmo tempo: 3
  atraso antes da onda: 4 s
```

O spawner de ondas é uma máquina de estado (Capítulo 4):

```text
 Idle ──Start──► Preparing (atraso) ──► Spawning ──(tudo criado)──► InProgress ──(todos mortos)──► Cleared
                                            ▲  │                                                    │
                                            └──┘ espera se vivos ≥ máximo                           │
                                                                         próxima onda ◄─────────────┘
```

### O orçamento como ferramenta

O **máximo de vivos** não é só proteção de performance — é a principal alavanca de **intensidade**. Uma onda de 12 vigias com máximo de 3 vivos produz um encontro longo e sustentado; a mesma onda com máximo de 12 produz um massacre curto. O jogador sente a diferença como ritmo, não como número.

Um segundo orçamento, mais sutil, é o de inimigos **ativos**: quantos podem **atacar** ao mesmo tempo. **[INFERÊNCIA]** Em muitos shooters, só alguns inimigos atiram na jogadora ao mesmo tempo, enquanto os outros reposicionam, recarregam e gritam. O padrão é observável jogando; como cada jogo o implementa, em geral, não é público. Isso será formalizado com **tokens de ataque** no Capítulo 42 (Squad AI); por ora, o cérebro ingênuo do Capítulo 30 ataca sempre que vê — mais uma dor registrada.

### Contando mortos sem acoplamento

O spawner precisa saber quando os inimigos que **ele** criou morrem. Ele guarda o conjunto de atores criados (referências fracas) e escuta `Event.Actor.Died` no barramento: se o alvo do evento está no conjunto, conta. Os inimigos não sabem que foram criados por um spawner.

---

## 32.5 Object pooling

Criar e destruir atores custa: alocação, construção de componentes, registro na física e no render, e pressão no garbage collector (Capítulo 11). Para objetos criados e destruídos **o tempo todo** — projéteis rápidos, efeitos de impacto, cartuchos ejetados —, a alternativa é o **pool**: um estoque de atores pré-criados, **desativados**, que são "emprestados" e "devolvidos".

```text
 Acquire(Classe, Transform):
    há um ator livre dessa classe? → reativar, posicionar, OnAcquired
    senão → criar um novo (o pool cresce)
 Release(Ator):
    OnReleased (resetar estado), esconder, desligar colisão e tick, devolver ao estoque
```

O ponto crítico do pooling é o **reset de estado**: um ator reciclado precisa voltar a um estado "como novo". Atores simples (um projétil, um efeito) são fáceis; atores complexos (um inimigo com vida, IA, ragdoll, tags, munição) têm muito estado espalhado e são **difíceis** de resetar corretamente — e um reset incompleto produz bugs muito estranhos ("o inimigo novo nasceu morto", "nasceu com a tag do anterior").

A regra do projeto (Capítulo 8): **destruir por padrão; pool só com evidência do profiler, e só para atores com estado simples.** O pool deste capítulo é genérico e pequeno, e o exercício mede se ele vale a pena para o fuzil balístico do Capítulo 28.

> 🌉 **Ponte:** é exatamente um pool de conexões ou de threads: custo de criação amortizado, e o risco clássico de "vazar" estado de um uso para o próximo (a conexão devolvida com uma transação aberta).

---

## Estudo de caso: escala e intensidade com poucos NPCs

> **Pergunta:** como criar uma experiência de combate com sensação de escala e intensidade sem precisar de dezenas de NPCs?

### O que é publicamente conhecido

**[FATO PÚBLICO]** Os modos multiplayer da série Battlefield são conhecidos por partidas com muitos jogadores — 64 em *Battlefield 4* em várias plataformas — em mapas grandes com veículos, o que produz escala "natural": há, de fato, dezenas de pessoas lutando. As campanhas single-player de shooters como Call of Duty são conhecidas por sequências de alta intensidade com forte roteiro: aliados controlados pela IA, eventos encenados (explosões, aeronaves, desmoronamentos) e uma paisagem sonora densa de combate. Em várias campanhas mais antigas da série Call of Duty, jogadores observaram e discutem amplamente que, em certos trechos, inimigos continuam surgindo até que o jogador **avance** além de determinados pontos — um mecanismo que empurra o jogador para frente.

### 1. Experiência

Estar no meio de uma batalha muito maior do que o que se vê de perto. Ruído, caos, pressão constante — sem que o jogador seja esmagado.

### 2. Sistema

**[INFERÊNCIA]** A sensação de escala pode ser decomposta em camadas com custos muito diferentes:

```text
 CAMADA                               CUSTO       O QUE COMUNICA
 ──────                               ─────       ──────────────
 Áudio ambiente de batalha            baixíssimo  "há combate em toda parte"
 (tiros e explosões distantes, gritos)
 Efeitos à distância                  baixo       "a batalha é visível no horizonte"
 (traçantes, clarões, fumaça, aeronaves em trilhos)
 Figurantes de baixo custo            baixo       "há gente lá longe"
 (silhuetas animadas, sem IA completa)
 Aliados com IA simples               médio       "não estou sozinho"
 Inimigos com IA completa, ENGAJANDO  ALTO        "estou em perigo AGORA"
 a jogadora — poucos, com orçamento
 Spawn contínuo fora de vista +       médio       "eles não param de vir"
 gatilhos de avanço
```

### 3. Design

A decisão central é **concentrar o custo onde o jogador está olhando e agindo**: poucos inimigos de verdade engajando, num orçamento controlado, e tudo o mais como **cenografia** barata — áudio, efeitos, figurantes. O spawn contínuo fora de vista mantém a pressão sem exigir muitos inimigos simultâneos; os gatilhos de avanço transformam a pressão em **direção** (o jogador entende que precisa avançar). É o princípio do Capítulo 1: **simule só o que o jogador percebe ou explora**.

### 4. Tecnologia

Na arquitetura deste livro: um **spawner de ondas** com orçamento de vivos e pontos fora de vista (este capítulo); **tokens de ataque** para limitar quantos inimigos atiram ao mesmo tempo (Capítulo 42); **áudio** em camadas com fontes distantes e mixagem dinâmica (Capítulo 52); **efeitos** Niagara à distância (Capítulo 54); figurantes como malhas animadas em trilhos, sem IA (Capítulo 53); **gatilhos** (Capítulo 15) que encerram ondas e ativam as próximas quando o jogador avança.

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]** No Galpão: um **desafio de defesa** — ondas de vigias (orçamento de 3 vivos) vindo de pontos fora de vista, enquanto **fora** do galpão há som de tiros e explosões distantes e clarões ocasionais pelas janelas altas. Depois de duas ondas, um gatilho no fundo do galpão encerra o desafio quando a jogadora alcança a saída.

### 6. Lição

**Escala percebida é construída em camadas, e só a camada mais próxima precisa ser "real".** O orçamento de inimigos ativos é, ao mesmo tempo, uma decisão de performance e de pacing. E a Vigília, que **não** quer escala — quer solidão —, usa o mesmo princípio ao contrário: um único inimigo "real" (a Presença) e uma cenografia que sugere que ela pode estar em qualquer lugar.

---

## Comparação com o desenvolvimento tradicional

| Spawn | O que você conhece | Onde a analogia cai |
|---|---|---|
| Pontos + ondas | Recursos disponíveis + agendamento de jobs | A "colocação" depende do que um humano está vendo |
| Orçamento de vivos | Limite de concorrência / *bulkhead* | É também a principal alavanca de **ritmo** |
| Escolha por pontuação | Balanceamento de carga ponderado | Os critérios são perceptuais (visível, perto) |
| Pooling | Pool de conexões/threads | Reset de estado de atores complexos é difícil |

---

## Implementação

### 1. O ponto de spawn

```cpp
// Source/Vigilia/World/VGSpawnPoint.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameplayTagContainer.h"
#include "VGSpawnPoint.generated.h"

class UArrowComponent;
class UCapsuleComponent;

/** Ponto de spawn autorado pelo level designer. A cápsula define o espaço que precisa estar livre. */
UCLASS()
class VIGILIA_API AVGSpawnPoint : public AActor
{
    GENERATED_BODY()

public:
    AVGSpawnPoint();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Spawn")
    bool IsClear() const;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Vigilia|Spawn", meta = (Categories = "Spawn"))
    FGameplayTagContainer SpawnTags;

    float LastUsedTime = -100.0f;

protected:
    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UCapsuleComponent> Clearance;

#if WITH_EDITORONLY_DATA
    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UArrowComponent> Arrow;
#endif
};
```

```cpp
// Source/Vigilia/World/VGSpawnPoint.cpp
#include "World/VGSpawnPoint.h"

#include "Components/ArrowComponent.h"
#include "Components/CapsuleComponent.h"

AVGSpawnPoint::AVGSpawnPoint()
{
    PrimaryActorTick.bCanEverTick = false;

    Clearance = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Clearance"));
    Clearance->InitCapsuleSize(40.0f, 92.0f);
    Clearance->SetCollisionEnabled(ECollisionEnabled::NoCollision); // só define a forma do teste
    Clearance->SetHiddenInGame(true);
    SetRootComponent(Clearance);

#if WITH_EDITORONLY_DATA
    Arrow = CreateEditorOnlyDefaultSubobject<UArrowComponent>(TEXT("Arrow"));
    if (Arrow)
    {
        Arrow->SetupAttachment(Clearance);
    }
#endif
}

bool AVGSpawnPoint::IsClear() const
{
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGSpawnClearance), false, this);
    constexpr float Slack = 5.0f; // folga: o chão encostado na base (ou um teto baixo) não conta como ocupado
    const FCollisionShape Shape = FCollisionShape::MakeCapsule(
        Clearance->GetScaledCapsuleRadius(), Clearance->GetScaledCapsuleHalfHeight() - Slack);
    // Blocking, não Any: só o que BLOQUEIA um pawn ocupa o lugar.
    return !GetWorld()->OverlapBlockingTestByChannel(GetActorLocation(), GetActorQuat(), ECC_Pawn, Shape, Params);
}
```

⚠️ **`OverlapAnyTestByChannel` seria o erro natural aqui.** "Any" conta também o que só gera **overlap** com pawns — gatilhos, zonas seguras, volumes de áudio —, e um ponto dentro de qualquer um deles pareceria sempre ocupado. E sem a folga, um ponto posicionado com a base da cápsula rente ao chão "colide" com o próprio chão.

A seta existe **só no editor** (`WITH_EDITORONLY_DATA` + `CreateEditorOnlyDefaultSubobject`): o ponto de spawn não custa nada no jogo empacotado além de um transform e uma forma.

### 2. A onda

```cpp
// Source/Vigilia/World/VGWaveData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGWaveData.generated.h"

USTRUCT(BlueprintType)
struct FVGWaveEntry
{
    GENERATED_BODY()

    UPROPERTY(EditDefaultsOnly, Category = "Wave")
    TSubclassOf<APawn> PawnClass;

    UPROPERTY(EditDefaultsOnly, Category = "Wave", meta = (ClampMin = "1"))
    int32 Count = 1;
};

UCLASS(BlueprintType)
class VIGILIA_API UVGWaveData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Wave")
    TArray<FVGWaveEntry> Entries;

    UPROPERTY(EditDefaultsOnly, Category = "Wave", meta = (ClampMin = "0.0"))
    float StartDelay = 3.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Wave", meta = (ClampMin = "0.1"))
    float SpawnInterval = 1.5f;

    /** Orçamento: quantos desta onda podem estar vivos ao mesmo tempo. */
    UPROPERTY(EditDefaultsOnly, Category = "Wave", meta = (ClampMin = "1"))
    int32 MaxAlive = 3;
};
```

### 3. O spawner de ondas

```cpp
// Source/Vigilia/World/VGWaveSpawner.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGWaveSpawner.generated.h"

class AVGSpawnPoint;
class UVGWaveData;
struct FVGGameplayEvent;

UENUM(BlueprintType)
enum class EVGWaveState : uint8
{
    Idle,
    Preparing,
    Spawning,
    InProgress,
    Cleared
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGWaveSignature, AVGWaveSpawner*, Spawner, int32, WaveIndex);

/**
 * Ondas de pawns em pontos de spawn fora da visão da jogadora, com orçamento de vivos.
 * Conta mortes pelo barramento (Event.Actor.Died), sem que os pawns saibam do spawner.
 */
UCLASS()
class VIGILIA_API AVGWaveSpawner : public AActor
{
    GENERATED_BODY()

public:
    AVGWaveSpawner();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Waves")
    void StartWaves();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Waves")
    void StopWaves();

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Waves")
    FVGWaveSignature OnWaveStarted;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Waves")
    FVGWaveSignature OnWaveCleared;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Waves")
    FVGWaveSignature OnAllWavesCleared;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(EditInstanceOnly, Category = "Vigilia|Waves")
    TArray<TObjectPtr<AVGSpawnPoint>> SpawnPoints;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Waves")
    TArray<TObjectPtr<UVGWaveData>> Waves;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Waves", meta = (ClampMin = "0.0"))
    float MinDistanceFromPlayer = 1200.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Waves", meta = (ClampMin = "0.0"))
    float PointReuseCooldown = 4.0f;

    /** Meio-ângulo do cone considerado "visto pela jogadora" (um pouco maior que o FOV real). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Waves", meta = (ClampMin = "0.0", ClampMax = "180.0"))
    float PlayerViewHalfAngle = 55.0f;

private:
    void BeginWave(int32 Index);
    void SpawnNext();
    AVGSpawnPoint* ChooseSpawnPoint() const;
    bool IsVisibleToPlayer(const AVGSpawnPoint* Point) const;
    void HandleEvent(const FVGGameplayEvent& Event);
    void TransitionTo(EVGWaveState NewState);
    void PruneAlive();
    void TryClearWave();

    EVGWaveState State = EVGWaveState::Idle;
    int32 WaveIndex = INDEX_NONE;
    TArray<TSubclassOf<APawn>> PendingSpawns;
    TSet<TWeakObjectPtr<AActor>> Alive;

    FTimerHandle WaveTimerHandle;
    FDelegateHandle EventHandle;
};
```

```cpp
// Source/Vigilia/World/VGWaveSpawner.cpp
#include "World/VGWaveSpawner.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"
#include "World/VGSpawnPoint.h"
#include "World/VGWaveData.h"

AVGWaveSpawner::AVGWaveSpawner()
{
    PrimaryActorTick.bCanEverTick = false;
    SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("Root")));
}

void AVGWaveSpawner::BeginPlay()
{
    Super::BeginPlay();
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &AVGWaveSpawner::HandleEvent);
    }
}

void AVGWaveSpawner::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    GetWorldTimerManager().ClearAllTimersForObject(this);
    Super::EndPlay(EndPlayReason);
}

void AVGWaveSpawner::StartWaves()
{
    if (State == EVGWaveState::Idle || State == EVGWaveState::Cleared)
    {
        BeginWave(0);
    }
}

void AVGWaveSpawner::StopWaves()
{
    GetWorldTimerManager().ClearAllTimersForObject(this);
    PendingSpawns.Reset();
    TransitionTo(EVGWaveState::Idle);
}

void AVGWaveSpawner::BeginWave(int32 Index)
{
    if (!Waves.IsValidIndex(Index) || !Waves[Index])
    {
        TransitionTo(EVGWaveState::Cleared);
        OnAllWavesCleared.Broadcast(this, WaveIndex);
        return;
    }
    WaveIndex = Index;
    PendingSpawns.Reset();
    for (const FVGWaveEntry& Entry : Waves[Index]->Entries)
    {
        for (int32 i = 0; i < Entry.Count; ++i) { PendingSpawns.Add(Entry.PawnClass); }
    }

    TransitionTo(EVGWaveState::Preparing);
    OnWaveStarted.Broadcast(this, WaveIndex);
    GetWorldTimerManager().SetTimer(WaveTimerHandle, this, &AVGWaveSpawner::SpawnNext,
                                    FMath::Max(Waves[Index]->StartDelay, 0.01f), false);
}

void AVGWaveSpawner::SpawnNext()
{
    const UVGWaveData* Wave = Waves[WaveIndex];
    TransitionTo(PendingSpawns.IsEmpty() ? EVGWaveState::InProgress : EVGWaveState::Spawning);
    if (PendingSpawns.IsEmpty())
    {
        // Tudo criado; a onda termina quando os vivos morrerem (HandleEvent). Mas o último pode
        // ter morrido ANTES deste tick, ainda em Spawning — sem esta checagem, a onda nunca termina.
        TryClearWave();
        return;
    }

    // Orçamento: com o máximo de vivos atingido, tenta de novo depois.
    PruneAlive();
    if (Alive.Num() < Wave->MaxAlive)
    {
        if (AVGSpawnPoint* Point = ChooseSpawnPoint())
        {
            FActorSpawnParameters Params;
            Params.Owner = this;
            Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButDontSpawnIfColliding;

            if (APawn* Spawned = GetWorld()->SpawnActor<APawn>(PendingSpawns.Last(), Point->GetActorTransform(), Params))
            {
                PendingSpawns.Pop();
                Alive.Add(Spawned);
                Point->LastUsedTime = GetWorld()->GetTimeSeconds();
            }
        }
        // Sem ponto válido agora (todos visíveis/ocupados): tenta no próximo intervalo.
    }
    GetWorldTimerManager().SetTimer(WaveTimerHandle, this, &AVGWaveSpawner::SpawnNext, Wave->SpawnInterval, false);
}

AVGSpawnPoint* AVGWaveSpawner::ChooseSpawnPoint() const
{
    const APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
    const float Now = GetWorld()->GetTimeSeconds();

    TArray<TPair<float, AVGSpawnPoint*>> Scored;
    for (AVGSpawnPoint* Point : SpawnPoints)
    {
        if (!IsValid(Point) || Now - Point->LastUsedTime < PointReuseCooldown || !Point->IsClear())
        {
            continue;
        }
        float Distance = 0.0f;
        if (Player)
        {
            Distance = FVector::Dist(Player->GetActorLocation(), Point->GetActorLocation());
            if (Distance < MinDistanceFromPlayer || IsVisibleToPlayer(Point))
            {
                continue; // perto demais ou à vista: injusto
            }
        }
        const float Noise = FMath::FRandRange(0.0f, 300.0f); // Simplificação: sem semente (cosmético)
        Scored.Emplace(Distance + Noise, Point);
    }
    if (Scored.IsEmpty())
    {
        return nullptr;
    }
    Scored.Sort([](const auto& A, const auto& B) { return A.Key > B.Key; }); // mais distantes primeiro
    const int32 Top = FMath::Min(3, Scored.Num());
    return Scored[FMath::RandRange(0, Top - 1)].Value;
}

bool AVGWaveSpawner::IsVisibleToPlayer(const AVGSpawnPoint* Point) const
{
    const APlayerCameraManager* Camera = UGameplayStatics::GetPlayerCameraManager(this, 0);
    if (!Camera)
    {
        return false;
    }
    const FVector Eye = Camera->GetCameraLocation();
    const FVector Target = Point->GetActorLocation() + FVector(0.0, 0.0, 60.0); // ~altura do peito
    const FVector ToPoint = (Target - Eye).GetSafeNormal();

    // 1. Dentro do cone? (produto escalar — Cap. 17)
    const float CosHalf = FMath::Cos(FMath::DegreesToRadians(PlayerViewHalfAngle));
    if (FVector::DotProduct(Camera->GetCameraRotation().Vector(), ToPoint) < CosHalf)
    {
        return false;
    }
    // 2. Linha de visão livre? (trace — Cap. 15) — a peça que faltava no desafio do Cap. 8.
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGSpawnVisibility), false);
    Params.AddIgnoredActor(UGameplayStatics::GetPlayerPawn(this, 0));
    FHitResult Hit;
    return !GetWorld()->LineTraceSingleByChannel(Hit, Eye, Target, ECC_Visibility, Params);
}

void AVGWaveSpawner::HandleEvent(const FVGGameplayEvent& Event)
{
    if (!Event.Channel.MatchesTagExact(TAG_Event_Actor_Died) || !Alive.Contains(Event.Target))
    {
        return;
    }
    Alive.Remove(Event.Target);
    TryClearWave();
}

void AVGWaveSpawner::PruneAlive()
{
    // Atores destruídos sem passar pelo barramento (queda no vazio, Destroy direto).
    // Alive.Remove(nullptr) NÃO serve: o hash de TWeakObjectPtr usa índice/serial do objeto,
    // e um ponteiro fraco obsoleto não é igual a um nulo.
    for (auto It = Alive.CreateIterator(); It; ++It)
    {
        if (!It->IsValid())
        {
            It.RemoveCurrent();
        }
    }
}

void AVGWaveSpawner::TryClearWave()
{
    PruneAlive();
    if (State == EVGWaveState::InProgress && PendingSpawns.IsEmpty() && Alive.IsEmpty())
    {
        OnWaveCleared.Broadcast(this, WaveIndex);
        BeginWave(WaveIndex + 1);
    }
}

void AVGWaveSpawner::TransitionTo(EVGWaveState NewState)
{
    State = NewState;
}
```

### Explicação das decisões

- **Visibilidade = cone + linha de visão.** Um ponto atrás de uma parede, mesmo no centro da tela, é válido; um ponto à vista, mesmo distante, não.
- **Orçamento verificado a cada tentativa de spawn**: com o máximo atingido, o spawner apenas reagenda. Quando um inimigo morre, a próxima tentativa encontra vaga.
- **Sem ponto válido, tenta depois** — em vez de forçar um spawn à vista. Se isso acontecer com frequência, é um problema de **level design** (pontos insuficientes ou mal posicionados), e a correção é no nível.
- **Mortes pelo barramento**, com o conjunto de vivos em referências fracas (`TSet<TWeakObjectPtr<AActor>>`) e `PruneAlive` limpando entradas de atores destruídos por outros meios (iterando e removendo os inválidos — `Alive.Remove(nullptr)` parece fazer isso, mas não faz, porque o ponteiro fraco obsoleto não tem o mesmo hash de um nulo).
- **Um único ponto decide "onda concluída"** (`TryClearWave`), chamado tanto pela morte quanto pelo fim dos spawns. Com a checagem só na morte, um inimigo que morre entre o último spawn e o tick seguinte (estado ainda `Spawning`) deixava a onda presa para sempre — a condição de corrida clássica de "dois eventos, uma condição verificada em só um deles".
- **`AdjustIfPossibleButDontSpawnIfColliding`** como segunda defesa, depois do `IsClear`.
- **O ruído na pontuação não tem semente** — é cosmético e não afeta justiça. Se o projeto precisar reproduzir encontros (para depurar), ele vira um `FRandomStream`.

🔁 **O `AVGSpawner` do Capítulo 8 continua existindo** — para o que ele faz bem: spawn ambiente simples (caixas, objetos decorativos). O `AVGWaveSpawner` é para encontros. Dois sistemas pequenos com propósitos claros, em vez de um sistema genérico com uma dúzia de opções.

### 4. Pool genérico

```cpp
// Source/Vigilia/Core/VGPoolable.h
#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "VGPoolable.generated.h"

UINTERFACE(MinimalAPI, BlueprintType)
class UVGPoolable : public UInterface { GENERATED_BODY() };

/** Atores que podem ser reciclados. OnPoolReleased deve devolver o ator a um estado "como novo". */
class VIGILIA_API IVGPoolable
{
    GENERATED_BODY()
public:
    UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Pool")
    void OnPoolAcquired();

    UFUNCTION(BlueprintNativeEvent, Category = "Vigilia|Pool")
    void OnPoolReleased();
};
```

```cpp
// Source/Vigilia/Core/VGActorPoolSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGActorPoolSubsystem.generated.h"

/**
 * Pool de atores por classe. Só para atores com estado simples (projéteis, efeitos).
 * Simplificação: o pool cresce sem limite; um teto por classe pode ser adicionado se o profiler pedir.
 */
UCLASS()
class VIGILIA_API UVGActorPoolSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    AActor* Acquire(TSubclassOf<AActor> Class, const FTransform& Transform, const FActorSpawnParameters& Params);
    void Release(AActor* Actor);

private:
    TMap<TSubclassOf<AActor>, TArray<TWeakObjectPtr<AActor>>> FreeActors;
};
```

```cpp
// Source/Vigilia/Core/VGActorPoolSubsystem.cpp
#include "Core/VGActorPoolSubsystem.h"

#include "Core/VGPoolable.h"
#include "Engine/World.h"

AActor* UVGActorPoolSubsystem::Acquire(TSubclassOf<AActor> Class, const FTransform& Transform,
                                       const FActorSpawnParameters& Params)
{
    TArray<TWeakObjectPtr<AActor>>& Free = FreeActors.FindOrAdd(Class);
    while (!Free.IsEmpty())
    {
        AActor* Actor = Free.Pop().Get();
        if (!IsValid(Actor))
        {
            continue; // destruído por outro meio enquanto estava no pool
        }
        Actor->SetActorTransform(Transform, false, nullptr, ETeleportType::ResetPhysics);
        Actor->SetOwner(Params.Owner);
        Actor->SetInstigator(Params.Instigator);
        Actor->SetActorHiddenInGame(false);
        Actor->SetActorEnableCollision(true);
        Actor->SetActorTickEnabled(true);
        if (Actor->Implements<UVGPoolable>())
        {
            IVGPoolable::Execute_OnPoolAcquired(Actor);
        }
        return Actor;
    }
    return GetWorld()->SpawnActor<AActor>(Class, Transform, Params); // pool vazio: cria
}

void UVGActorPoolSubsystem::Release(AActor* Actor)
{
    if (!IsValid(Actor))
    {
        return;
    }
    if (Actor->Implements<UVGPoolable>())
    {
        IVGPoolable::Execute_OnPoolReleased(Actor); // o ator volta a um estado "como novo"
    }
    Actor->SetActorHiddenInGame(true);
    Actor->SetActorEnableCollision(false);
    Actor->SetActorTickEnabled(false);
    FreeActors.FindOrAdd(Actor->GetClass()).Add(Actor);
}
```

Para usar o pool com o `AVGProjectile` (Capítulo 28), ele implementa `IVGPoolable` (em `OnPoolAcquired`, reativa o movimento com a velocidade inicial; em `OnPoolReleased`, para o movimento e limpa dano/efeitos) e, em vez de `Destroy()`, chama `Release(this)` no subsistema; a arma usa `Acquire` em vez de `SpawnActor`. O exercício pede a medição antes e depois.

---

## Projeto 2 — conclusão: o Galpão de Testes

### O desafio de defesa

1. Seis `AVGSpawnPoint` no Galpão e no pátio dos fundos, com tags de área.
2. `DA_Onda_1` (3 vigias, máx. 2 vivos) e `DA_Onda_2` (4 vigias + 1 com escopeta, máx. 3 vivos).
3. `BP_ControladorDefesa`: ao interagir com um rádio, ativa um objetivo "Sobreviva às ondas" (Capítulo 31) e chama `StartWaves`; ao `OnAllWavesCleared`, destranca a saída; um gatilho na saída encerra o desafio.
4. **Cenografia de escala** (estudo de caso): sons de tiros e explosões distantes em loop fora do Galpão, clarões ocasionais pelas janelas (uma luz que pisca com o `UVGFlickerComponent` e um perfil apropriado).

### Critérios de conclusão do Projeto 2

- [ ] Movimento com dois perfis (Vigília e Galpão), coyote time, buffer e aterrissagem.
- [ ] Inventário com dois slots, troca com regras, mira com a arma (FOV, posição, dispersão, velocidade).
- [ ] Estatísticas efetivas com acessórios; bancada de acessórios.
- [ ] Hitscan da câmera com dispersão em camadas, materiais (cabeça, membros, penetração), queda de dano, escopeta e efeitos por superfície.
- [ ] Projéteis do cano ao ponto mirado; sinalizador com fases, luz, zona segura e estímulo de luz.
- [ ] Recuo com recuperação que respeita compensação; florescimento; coice e balanço.
- [ ] Vigias com reações, atordoamento, ragdoll e cérebro ingênuo com telegrafia e erro de mira dosado.
- [ ] Desafio de tiro (objetivo com tempo) e desafio de defesa (ondas fora de vista, orçamento).
- [ ] Nenhuma arma, alvo ou inimigo conhece outro por classe; tudo se comunica por interfaces, tags, eventos e o barramento.
- [ ] O jogo empacotado em Development roda o Galpão a pelo menos 60 FPS na sua máquina.

### Retrospectiva do Projeto 2

No `DEVLOG.md`, em uma página:

1. Qual sistema da Parte IV mais mudou a **sensação** do Galpão? (Movimento, recuo, feedback de impacto, inimigos?)
2. Quais decisões dos Capítulos 1–24 pagaram dividendos aqui? (O pipeline estável do Capítulo 20? O barramento? As tags?)
3. Das "dores do cérebro ingênuo" (Capítulo 30), quais apareceram no desafio de defesa?
4. O que, do Galpão, vai para a Vigília? (O sinalizador, os vigias, o movimento da Vigília, a mira... e o que fica só no laboratório?)

---

## Decisões arquiteturais

1. **Pontos de spawn autorados (onde) separados de ondas (quando e quanto).**
2. **Escolha por rejeição (visível, perto, ocupado, usado) + pontuação + sorteio entre os melhores.**
3. **Visibilidade = cone + linha de visão.**
4. **Orçamento de vivos por onda** como alavanca de ritmo; orçamento de atacantes na Parte V.
5. **Mortes contadas pelo barramento**, com vivos em referências fracas.
6. **Pool genérico só para atores simples**, com reset explícito via `IVGPoolable`; destruir por padrão.
7. **Dois spawners pequenos** (ambiente e ondas), não um genérico.

---

## Armadilhas

- **Spawn à vista da jogadora** — ou "fora do cone" mas visível por falta do trace.
- **Spawn em cima da jogadora** (sem distância mínima).
- **Forçar spawn quando não há ponto válido.**
- **Desligar o tick do ator no pool e esquecer o dos componentes.** `SetActorTickEnabled(false)` não desliga o tick dos componentes. Um inimigo "guardado" no pool continua pagando a percepção, a consciência e o movimento. Desligue também cada componente que tica, ou implemente isso uma vez no `IVGPoolable`.
- **Contar mortes por referência direta** (inimigos que conhecem o spawner).
- **Pooling de atores complexos** com reset incompleto.
- **Spawner genérico com opções para todos os casos.**
- **Escala por quantidade de inimigos reais** em vez de camadas.

---

## Exercício

**Parte 1 — pontos e ondas (2 h).** Implemente `AVGSpawnPoint`, `UVGWaveData` e `AVGWaveSpawner`. Monte o desafio de defesa. Com `DrawDebugSphere`, desenhe a cada spawn os pontos rejeitados (vermelho: visível; amarelo: perto; cinza: ocupado) e o escolhido (verde).

**Parte 2 — ritmo (1 h).** Jogue a mesma onda com `MaxAlive` = 1, 3 e 6. Descreva a estética de cada uma (MDA, Capítulo 5). Qual é a mais tensa? Qual é a mais justa?

**Parte 3 — pool (1,5 h).** Implemente o pool e faça o fuzil balístico usá-lo. Meça (com `stat game`, `stat unit` e, se quiser, o Unreal Insights — Capítulo 59) o custo de disparar continuamente por 10 s com e sem pool. A diferença justifica a complexidade?

**Parte 4 — conclusão (2 h).** Passe pelos critérios do Projeto 2, corrija o que faltar, empacote e escreva a retrospectiva.

---

## Desafio — o spawner que observa

Hoje, a visibilidade é avaliada **só no momento do spawn**. Mas a jogadora pode virar a câmera um instante depois e ver o inimigo "surgindo" (a animação de entrada, o primeiro passo). Implemente uma verificação extra: durante 0,5 s após o spawn, se a jogadora passar a ver o ponto, o inimigo **atrasa a ativação do cérebro** (ele já existe, mas fica parado e silencioso, como se sempre tivesse estado ali).

Pergunta para o `DEVLOG.md`: esse truque é desonesto com a jogadora? Em que tipo de jogo ele é aceitável (um shooter com ondas) e em que tipo ele quebraria a confiança (um jogo de furtividade em que a jogadora vasculhou a sala)? Como isso se relaciona com o princípio "simule só o que o jogador percebe" do Capítulo 1?

---

## Uso de IA

1. **Para revisar a escolha de pontos:**
   > "Revise esta lógica de escolha de pontos de spawn: rejeição por visibilidade (cone + trace), distância mínima, ocupação (overlap de cápsula) e reuso recente; pontuação por distância com ruído; sorteio entre os 3 melhores. Aponte casos em que ela falha (jogadora olhando para cima, pontos atrás de vidro, múltiplos jogadores) e o custo de traces por spawn. [código]"

2. **Para design de encontros:**
   > "Para um desafio de defesa de 3 minutos num galpão com seis pontos de spawn, proponha três ondas (composição, intervalo, máximo de vivos, atraso) que criem uma curva de tensão com picos e vales (no sentido de pacing). Explique o papel de cada onda e onde a jogadora deveria ter um respiro."

3. **Para decidir sobre pooling:**
   > "Quando object pooling de atores na Unreal Engine 5 compensa e quando é prejudicial? Considere custo de spawn, garbage collection, memória ociosa, reset de estado (componentes, timers, delegates, física, tags) e bugs típicos. Dê critérios objetivos para decidir com base em medições do profiler."

---

## Checklist

- [ ] Separei pontos de spawn de ondas e uso tags nos pontos.
- [ ] A escolha de ponto rejeita visíveis (cone + trace), próximos, ocupados e recém-usados.
- [ ] As ondas respeitam o orçamento de vivos e contam mortes pelo barramento.
- [ ] Implementei e medi um pool genérico para atores simples.
- [ ] Consigo decompor a sensação de escala em camadas de custo diferente.
- [ ] Concluí o Projeto 2 segundo os critérios e escrevi a retrospectiva.

## Para ir além

- **"The AI Systems of Left 4 Dead"**, de Michael Booth (Valve, 2009): a palestra pública que descreve populações geradas fora de vista e ritmo controlado por um diretor. É a raiz do Diretor que o livro constrói na Parte V.
- **"Object Pool"**, no livro *Game Programming Patterns*, de Robert Nystrom (gratuito em gameprogrammingpatterns.com): o padrão com os custos que este capítulo mediu, como fragmentação, reinício de estado e tamanho do pool.
- **Documentação do Unreal Insights** (Epic Games): use-a para repetir a medição do pool contra o `SpawnActor` no seu hardware, em vez de confiar nos números de outros.

---

## Fechamento da Parte IV

```text
Cap. 25  FPS Controller: métricas, coyote time, buffer, aterrissagem, perfis de movimento.
Cap. 26  Weapon System: estatísticas efetivas, modificadores, inventário, mira (ADS).
Cap. 27  Hitscan: câmera vs. cano, dispersão com semente, materiais como contrato, penetração.
Cap. 28  Projectile: ProjectileMovement, do cano ao ponto mirado, o sinalizador.
Cap. 29  Recoil: recuo com recuperação honesta, padrões, florescimento, coice, balanço.
Cap. 30  Enemy: composição, reações, atordoamento, ragdoll, cérebro ingênuo (e suas dores).
Cap. 31  Objectives: definição + estado + regra pura, alimentados pelo barramento.
Cap. 32  Spawn System: pontos, ondas fora de vista, orçamento, pool, escala em camadas.
```

O **Projeto 2 está concluído**. O próximo passo do livro **não** é a Parte V: é o **Interlúdio I** — o **Projeto 4**, *Turno da Noite*: uma experiência narrativa curta na Casa de Força, construída de propósito do jeito mais rápido e ingênuo possível, para sentir na pele os problemas que a Parte VI resolve.

➡️ **Próximo:** [Interlúdio I — Projeto 4: "Turno da Noite"](../interludio-1/projeto-4-turno-da-noite.md)

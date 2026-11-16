# Capítulo 42 — Squad AI

## Objetivo

Ao final deste capítulo você deve conseguir:

- identificar os problemas de **coordenação** que surgem quando vários agentes individualmente bons agem ao mesmo tempo;
- comparar coordenação **emergente** (informação compartilhada), **centralizada** (um coordenador atribui papéis) e por **tokens** (recursos limitados que autorizam ações);
- implementar um **sistema de tokens** para limitar quantos agentes atacam, flanqueiam ou falam ao mesmo tempo;
- atribuir **papéis** dinamicamente (quem suprime, quem flanqueia) a partir das utilidades de cada agente;
- construir um **Diretor de IA** que controla o **pacing** da Presença — tensão, picos, alívio — reaproveitando a máquina de estados do Capítulo 34;
- concluir o **Projeto 5** e fechar a Parte V.

---

## Contexto

O desafio do Capítulo 41 pediu um encontro de "dois tempos" com três vigias: um prende, outro avança, o terceiro cobre. Se você o implementou só com as ferramentas dos capítulos anteriores, viu o problema: cada vigia, **sozinho**, toma decisões razoáveis — e, **juntos**, eles fazem a mesma coisa ao mesmo tempo. Os três suprimem. Ou os três flanqueiam pelo mesmo lado. Ou os três gritam "recarregando!" no mesmo segundo.

Agentes bons individualmente não formam um esquadrão bom automaticamente. **Coordenação** é um sistema próprio — e, como quase tudo em Game AI, sua função principal não é a eficiência militar dos inimigos: é a **experiência** do jogador. Limitar quantos inimigos atacam ao mesmo tempo é o que torna um combate contra quatro vigias **jogável**; alternar quem fala é o que o torna **legível**.

O mesmo raciocínio, levado ao extremo, produz a peça final da Parte V: um **Diretor** que não coordena agentes entre si, mas coordena **a ameaça com a experiência da jogadora** — decidindo quando a Presença pressiona e quando ela recua, para que a curva de tensão do Capítulo 5 aconteça de fato.

---

## 42.1 Os problemas de coordenação

| Sintoma | Causa | O que a jogadora sente |
|---|---|---|
| Todos atacam ao mesmo tempo | Cada agente decide "atacar" independentemente | Combate injusto; morte sem tempo de reação |
| Todos fazem a mesma tática | Mesmas utilidades, mesmo contexto | IA "burra", previsível |
| Falas sobrepostas | Cada agente fala na sua transição | Ruído; perde-se a informação |
| Todos procuram no mesmo ponto | Mesma consulta de busca, mesma informação | Esconderijos triviais |
| Ninguém faz o papel necessário | Nenhum agente "ganha" a utilidade de, por exemplo, cobrir a retirada | Brechas que parecem descuido |

---

## 42.2 Três formas de coordenar

### Emergente: informação compartilhada

Os agentes não se comunicam diretamente; eles **leem e escrevem** informação comum — a chave sincronizada `SquadAlertLocation` do Capítulo 38, as tags de status da jogadora (ela está suprimida? — Capítulo 41). Cada um decide sozinho, mas sobre um mundo compartilhado. É simples e robusto, e **não impede** que dois façam a mesma coisa.

### Centralizada: um coordenador

Um objeto — um **coordenador de esquadrão** — enxerga todos os agentes e **atribui papéis**: "você suprime, você flanqueia, você segura". Os agentes recebem o papel no Blackboard e o executam. É previsível e controlável, mas o coordenador precisa ser bem projetado (e é um ponto central de decisão que pode se tornar complexo).

### Tokens: recursos que autorizam ações

Um meio-termo elegante: certas ações exigem um **token**, e há poucos tokens. Um agente que quer atacar **pede** um token de ataque; se conseguir, ataca; se não, faz outra coisa (reposiciona, suprime sem acertar, espera). Quando termina, **devolve**. O número de tokens define **quantos podem fazer aquilo ao mesmo tempo**.

```text
  TOKENS DE ATAQUE À JOGADORA: capacidade 2
  ┌──────────┬──────────┐
  │ Vigia A  │ Vigia C  │   ← atacando
  └──────────┴──────────┘
  Vigia B: pediu, negado → reposiciona / suprime
  Vigia D: pediu, negado → espera na cobertura
  (A termina a rajada, devolve → B pede de novo e consegue)
```

> 🌉 **Ponte:** tokens são **semáforos**. Um semáforo de contagem com capacidade 2 limita quantas *threads* entram numa seção crítica; aqui, limita quantos inimigos "entram" no ataque. A mesma disciplina vale: **quem adquire, libera** — inclusive se for interrompido (morreu, foi atordoado) —, senão o token vaza e o combate "trava" com ninguém atacando.
>
> 🧱 **Onde a ponte cai:** num sistema concorrente, o objetivo do semáforo é proteger um recurso. Aqui, o "recurso protegido" é **a jogadora** — a capacidade é um botão de **dificuldade e ritmo**, ajustado por design (e pode variar com a dificuldade escolhida ou com o Diretor).

Tokens não servem só para ataque. O projeto usa quatro tipos:

| Token | Capacidade | Efeito |
|---|:-:|---|
| `Squad.Token.Attack` | 2 | Quantos atiram para acertar ao mesmo tempo |
| `Squad.Token.Flank` | 1 | Só um flanqueia por vez |
| `Squad.Token.Suppress` | 1 | Só um suprime por vez |
| `Squad.Token.Bark` | 1 (com recarga de 1,5 s) | Só uma fala por vez no esquadrão |

---

## 42.3 Papéis dinâmicos

Tokens resolvem "**quantos**"; papéis resolvem "**quem**". Um coordenador simples pode atribuir papéis usando as **utilidades** que cada agente já calcula (Capítulo 40):

```text
 a cada 1 s, para o esquadrão em combate:
   para cada papel (em ordem de importância: Suppress, Flank, Hold):
       escolher o agente LIVRE com maior utilidade para aquele papel
       gravar o papel no Blackboard desse agente
   os demais: Attack (sujeito a tokens)
```

É uma atribuição **gulosa** — não é ótima (o problema geral de atribuição tem algoritmos melhores), mas é barata, previsível e boa o bastante para três ou quatro agentes. E, como cada agente continua decidindo **como** executar o papel (a sua árvore), o coordenador é pequeno.

---

## 42.4 O Diretor

### O problema

A Presença é **um** agente com uma Behavior Tree completa (Capítulos 37–39). Sozinha, ela é sistêmica: espreita, ouve, investiga, caça. Isso produz encontros — mas não produz **ritmo**. Ela pode encontrar a jogadora três vezes em dois minutos e depois nunca mais; pode caçá-la no meio de uma leitura de documento importante; pode nunca aparecer no corredor que o level designer construiu para o susto.

A Vigília precisa da curva de tensão do Capítulo 5: picos e vales, alívio projetado, picos nos lugares certos. Isso não é responsabilidade da Presença (um agente não sabe nada de pacing), nem de um roteiro fixo (que mataria a sensação sistêmica). É responsabilidade de um **Diretor**.

### Uma referência pública

**[FATO PÚBLICO]** *Left 4 Dead* (Valve, 2008) é conhecido pelo seu **AI Director**, um sistema que ajusta dinamicamente o ritmo das partidas — por exemplo, a criação de hordas de inimigos e a distribuição de itens — com base numa estimativa da intensidade que os jogadores estão vivendo, alternando fases de pressão e de relaxamento. O sistema foi descrito publicamente por Michael Booth, da Valve, na palestra *The AI Systems of Left 4 Dead* (2009).

**[INFERÊNCIA]** A ideia central que importa para a Vigília é **separar a ameaça do ritmo**: os agentes cuidam de **como** ameaçar; o Diretor cuida de **quando** e **quanto**. Ele mantém uma estimativa da tensão da jogadora e impõe fases: construir tensão, permitir um pico, forçar alívio. Nenhuma afirmação é feita sobre a implementação da Valve além do que foi apresentado publicamente.

### O Diretor da Vigília

```text
                     ESTIMATIVA DE TENSÃO (0..1, suavizada)
   entradas: nível de ameaça (Cap. 36), dano recente, bateria baixa, tempo desde o último
             encontro, jogadora na luz (alívio), lendo documento (modo Reading — Cap. 16)
                                   │
                                   ▼
          MÁQUINA DE FASES DO DIRETOR (FSM plana, num switch)
   ┌──────────┐  tempo mínimo  ┌──────────┐  tensão alta ou  ┌──────────┐  fim do pico  ┌──────────┐
   │  RELAX   │ ─────────────► │ BUILD-UP │ ───────────────► │   PEAK   │ ────────────► │ RECOVERY │
   │ Presença │   e tensão     │ sinais:  │   tempo máximo   │ caça     │  ou tempo     │ Presença │
   │ longe/   │   baixa        │ luzes,   │                  │ liberada │  máximo       │ recua e  │
   │ dormente │ ◄───────────── │ sons     │                  │          │               │ some     │
   └──────────┘  (volta depois └──────────┘                  └──────────┘               └────┬─────┘
        ▲         do tempo de                                                               │
        └──────────────────────────── tempo mínimo de alívio ───────────────────────────────┘

   SAÍDAS: modo da Presença no Blackboard (DirectorMode), sinais ambientes (flicker, ruídos
           distantes pelo barramento), reposicionamento fora de vista, travas de roteiro
```

As fases:

- **Relax** — a Presença está **dormente** ou longe (o ramo "Espreitar" da BT usa pontos distantes; os ramos de caça estão bloqueados). A jogadora explora, lê, respira.
- **Build-up** — o Diretor começa a **sinalizar**: luzes próximas falham, um ruído distante de passos, a música muda (pelo nível de ameaça e por eventos). A Presença se aproxima (a espreita escolhe pontos mais perto da jogadora). A tensão sobe por antecipação — o "medo pela expectativa" do Capítulo 5.
- **Peak** — a caça é **permitida**: se a Presença perceber a jogadora, ela caça. O pico pode acontecer **ou não**, dependendo do que a jogadora fizer — o Diretor só abre a porta.
- **Recovery** — depois de um pico (ou de um tempo máximo nele), a Presença é **forçada a recuar** e sumir (o ramo de "Retirar-se", com uma consulta de recuo para longe da jogadora). Há um **tempo mínimo de alívio** antes de outro Build-up.

E duas regras de convivência com o roteiro (Capítulo 49 e projeto final):

- **Travas de roteiro**: uma sequência roteirizada (o susto do corredor, a perseguição) pode **travar** o Diretor numa fase ou suspendê-lo, e liberar ao terminar — o mesmo padrão de pedidos com handle do Capítulo 6.
- **Respeito ao estado da jogadora**: durante a leitura de um documento, o Diretor **não** inicia Peak. Ler é um momento de narrativa; ser morto enquanto lê é frustração.

> 🌉 **Ponte:** o Diretor é um **controlador de admissão** com histerese sobre uma métrica suavizada de "carga" (a tensão da jogadora) — como um sistema que só aceita trabalho novo quando a carga baixou e força períodos de resfriamento depois de picos.
>
> 🧱 **Onde a ponte cai:** um controlador de admissão protege um sistema da sobrecarga. O Diretor **provoca** sobrecarga de propósito, nos momentos certos — e mede o sucesso pela curva emocional, não pela estabilidade.

### Honestidade com a jogadora

O Diretor pode **reposicionar** a Presença fora da vista da jogadora (as mesmas regras do spawn do Capítulo 32: fora do cone, linha de visão bloqueada, distância mínima), para que um Build-up não dependa da sorte de onde ela estava. Isso é "fumaça e espelhos" (Capítulo 1) — e é aceitável num jogo de terror **desde que as regras que a jogadora aprendeu continuem valendo**: a Presença nunca aparece na luz, nunca atravessa portas fechadas, nunca ataca sem telegrafia, e nunca surge **à vista**. O que o Diretor controla é a **frequência** dos encontros, não as **regras** deles.

---

## Comparação com o desenvolvimento tradicional

| Coordenação | O que você conhece | Onde a analogia cai |
|---|---|---|
| Tokens | Semáforos de contagem | Protegem a experiência do jogador, não um recurso técnico |
| Coordenador de papéis | Scheduler / atribuição de tarefas a workers | Atribuição gulosa basta; a "eficiência" não é o objetivo |
| Informação compartilhada | Cache/estado compartilhado | Síncrono, no processo, observado por árvores |
| Diretor | Controlador de admissão / autoscaler com cooldown | Provoca picos de propósito; métrica é emocional |
| Travas de roteiro | Locks / feature flags temporárias | Pedidos com handle, como a dilatação do tempo (Cap. 6) |

---

## Implementação

### 1. O subsistema de tokens

```cpp
// Source/Vigilia/AI/VGTokenSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGTokenSubsystem.generated.h"

/**
 * Tokens de coordenação (semáforos de contagem por tipo).
 * Quem adquire libera — inclusive ao ser interrompido; tokens de agentes destruídos são recuperados.
 */
UCLASS()
class VIGILIA_API UVGTokenSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    /** Define a capacidade de um tipo de token (configurado no início do nível ou pelo Diretor). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Tokens")
    void SetCapacity(FGameplayTag TokenType, int32 Capacity, float ReacquireCooldown = 0.0f);

    /** Tenta adquirir. Idempotente: quem já tem, continua tendo (retorna true). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Tokens")
    bool TryAcquire(FGameplayTag TokenType, AActor* Holder);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Tokens")
    void Release(FGameplayTag TokenType, AActor* Holder);

    /** Libera todos os tokens de um agente (morte, atordoamento, troca de ramo). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Tokens")
    void ReleaseAll(AActor* Holder);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Tokens")
    bool HasToken(FGameplayTag TokenType, const AActor* Holder) const;

private:
    struct FPool
    {
        int32 Capacity = 1;
        float ReacquireCooldown = 0.0f;
        float LastReleaseTime = -100.0f;
        TArray<TWeakObjectPtr<AActor>> Holders;
    };
    void Prune(FPool& Pool) const;

    TMap<FGameplayTag, FPool> Pools;
};
```

```cpp
// Source/Vigilia/AI/VGTokenSubsystem.cpp
#include "AI/VGTokenSubsystem.h"

#include "Engine/World.h"

void UVGTokenSubsystem::SetCapacity(FGameplayTag TokenType, int32 Capacity, float ReacquireCooldown)
{
    FPool& Pool = Pools.FindOrAdd(TokenType);
    Pool.Capacity = FMath::Max(Capacity, 0);
    Pool.ReacquireCooldown = ReacquireCooldown;
}

void UVGTokenSubsystem::Prune(FPool& Pool) const
{
    // Recupera tokens de agentes destruídos: um token que vaza "trava" o esquadrão.
    Pool.Holders.RemoveAll([](const TWeakObjectPtr<AActor>& H) { return !H.IsValid(); });
}

bool UVGTokenSubsystem::TryAcquire(FGameplayTag TokenType, AActor* Holder)
{
    FPool* Pool = Pools.Find(TokenType);
    if (!Pool || !IsValid(Holder))
    {
        return false; // tipo não configurado: negar é o padrão seguro
    }
    Prune(*Pool);
    if (Pool->Holders.Contains(Holder))
    {
        return true;
    }
    const float Now = GetWorld()->GetTimeSeconds();
    if (Pool->Holders.Num() >= Pool->Capacity || Now - Pool->LastReleaseTime < Pool->ReacquireCooldown)
    {
        return false;
    }
    Pool->Holders.Add(Holder);
    return true;
}

void UVGTokenSubsystem::Release(FGameplayTag TokenType, AActor* Holder)
{
    if (FPool* Pool = Pools.Find(TokenType))
    {
        if (Pool->Holders.Remove(Holder) > 0)
        {
            Pool->LastReleaseTime = GetWorld()->GetTimeSeconds();
        }
    }
}

void UVGTokenSubsystem::ReleaseAll(AActor* Holder)
{
    for (TPair<FGameplayTag, FPool>& Pair : Pools)
    {
        Release(Pair.Key, Holder);
    }
}

bool UVGTokenSubsystem::HasToken(FGameplayTag TokenType, const AActor* Holder) const
{
    const FPool* Pool = Pools.Find(TokenType);
    return Pool && Pool->Holders.ContainsByPredicate([Holder](const TWeakObjectPtr<AActor>& H) { return H.Get() == Holder; });
}
```

### 2. Tokens na Behavior Tree

Uma task que adquire e um padrão de liberação garantida:

```cpp
// BTTask_VGAcquireToken: tenta adquirir; falha se negado (a sequence falha → outro ramo).
EBTNodeResult::Type UBTTask_VGAcquireToken::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    UVGTokenSubsystem* Tokens = OwnerComp.GetWorld()->GetSubsystem<UVGTokenSubsystem>();
    APawn* Body = OwnerComp.GetAIOwner()->GetPawn();
    return (Tokens && Tokens->TryAcquire(TokenType, Body)) ? EBTNodeResult::Succeeded : EBTNodeResult::Failed;
}
```

E a **liberação** acontece num **service** anexado ao mesmo ramo (`VG Hold Token`), que libera o token em `OnCeaseRelevant` — chamado quando o ramo deixa de estar ativo **por qualquer motivo**: terminou, falhou, foi abortado (perdeu o alvo, foi atordoado). É a garantia de "quem adquire, libera" (o `finally` do semáforo) — **desde que o construtor do service ligue `bNotifyCeaseRelevant = true`** (Capítulo 37). Sem a flag, o `OnCeaseRelevant` nunca roda, cada ataque deixa um token preso e, depois de dois engajamentos, ninguém mais ataca; a recuperação de tokens vazados mascararia o bug com atraso. Além disso, o `AVGEnemyCharacter` chama `ReleaseAll` ao morrer.

O ramo de ataque do vigia fica:

```text
[CombatIntent == Attack]
  SEQUENCE   (Service: VG Hold Token [Squad.Token.Attack])
    ├─ VG Acquire Token (Squad.Token.Attack)     ← negado? a sequence falha
    ├─ VG Telegraph
    ├─ VG Fire Burst
    └─ Wait
  (se a sequence falhar por falta de token, o selector de combate cai para um ramo
   "sem token": reposicionar por EQS ou suprimir sem acertar)
```

E a consideração `TokenAvailable` entra na utilidade de `Attack`, `Flank` e `Suppress` (Capítulo 40): um agente sem chance de token não "quer" tanto aquela ação, e escolhe outra — o que, por si só, já distribui papéis de forma emergente. (`TokenAvailable` é mais uma entrada no `EVGUtilityInput`, antes de `Count`; o `static_assert` do `BuildContext` passa a 12.)

### 3. O coordenador de esquadrão (mínimo)

Um `UVGSquadSubsystem` (de mundo, com tick a 1 Hz) mantém os vigias registrados (eles se registram no `BeginPlay` e saem no `EndPlay` — Capítulo 8, seção 8.5) e, quando há combate, atribui o papel `Suppress` e o papel `Flank` aos agentes com maior utilidade para cada um, escrevendo uma chave `SquadRole` no Blackboard deles. As árvores dos vigias tratam `SquadRole` como um **bônus** de utilidade (não uma ordem): o coordenador sugere, o agente decide — e tokens garantem o limite. Implementação no exercício.

### 4. O Diretor

```cpp
// Source/Vigilia/AI/VGDirectorSubsystem.h (essencial)
UENUM(BlueprintType)
enum class EVGDirectorPhase : uint8
{
    Relax,
    BuildUp,
    Peak,
    Recovery
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGDirectorPhaseChangedSignature,
    EVGDirectorPhase, OldPhase, EVGDirectorPhase, NewPhase);

/**
 * Diretor de pacing da Presença: estima a tensão da jogadora e impõe fases
 * (Relax → BuildUp → Peak → Recovery). Controla a FREQUÊNCIA dos encontros, nunca as REGRAS deles.
 */
UCLASS()
class VIGILIA_API UVGDirectorSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Tick(float DeltaTime) override;
    virtual TStatId GetStatId() const override;

    /** Trava de roteiro: força uma fase até ser liberada (pedido com handle — Cap. 6). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Director")
    int32 PushScriptLock(EVGDirectorPhase ForcedPhase, FName Reason);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Director")
    void PopScriptLock(int32 Handle);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Director")
    EVGDirectorPhase GetPhase() const { return Phase; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Director")
    float GetTension() const { return Tension; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Director")
    FVGDirectorPhaseChangedSignature OnPhaseChanged;

private:
    float ComputeRawTension() const;
    void UpdatePhase(float DeltaTime);
    void EnterPhase(EVGDirectorPhase NewPhase);
    void ApplyToPresence() const;

    EVGDirectorPhase Phase = EVGDirectorPhase::Relax;
    float Tension = 0.0f;
    float TimeInPhase = 0.0f;
    float LastPeakEndTime = -1000.0f;

    TMap<int32, TPair<EVGDirectorPhase, FName>> ScriptLocks;
    int32 NextLockHandle = 1;
};
```

```cpp
// VGDirectorSubsystem.cpp (trechos)
namespace VGDirectorTuning // Simplificação: constantes aqui; no projeto final, um Data Asset de pacing
{
    constexpr float MinRelaxTime    = 45.0f;  // alívio mínimo antes de qualquer Build-up
    constexpr float MaxRelaxTime    = 120.0f; // nunca mais que isto sem nada acontecer
    constexpr float BuildUpTime     = 25.0f;  // duração dos sinais antes de liberar a caça
    constexpr float MaxPeakTime     = 30.0f;  // um pico não dura para sempre
    constexpr float RecoveryTime    = 20.0f;  // a Presença some por pelo menos isto
    constexpr float TensionSmoothing = 0.5f;  // 1/s
}

float UVGDirectorSubsystem::ComputeRawTension() const
{
    float Raw = 0.0f;
    if (const UVGThreatSubsystem* Threat = GetWorld()->GetSubsystem<UVGThreatSubsystem>())
    {
        Raw += Threat->GetThreatLevel() == EVGThreatLevel::Hunting ? 0.7f
             : Threat->GetThreatLevel() == EVGThreatLevel::Uneasy  ? 0.35f : 0.0f;
    }
    // + vida baixa da jogadora, bateria em Low, dano recente; − dentro de zona segura (via tags — Cap. 23)
    // (cada termo é uma linha que consulta o componente correspondente; omitidos por brevidade)
    return FMath::Clamp(Raw, 0.0f, 1.0f);
}

void UVGDirectorSubsystem::Tick(float DeltaTime)
{
    Tension = VGMath::ExpDecayTo(Tension, ComputeRawTension(), VGDirectorTuning::TensionSmoothing, DeltaTime);
    TimeInPhase += DeltaTime;

    if (!ScriptLocks.IsEmpty())
    {
        // Roteiro manda: a trava mais recente define a fase (como a pilha de modos — Cap. 16).
        int32 TopHandle = 0;
        for (const auto& Pair : ScriptLocks) { TopHandle = FMath::Max(TopHandle, Pair.Key); }
        if (ScriptLocks[TopHandle].Key != Phase) { EnterPhase(ScriptLocks[TopHandle].Key); }
        return;
    }
    UpdatePhase(DeltaTime);
}

void UVGDirectorSubsystem::UpdatePhase(float DeltaTime)
{
    using namespace VGDirectorTuning;
    const bool bReading = IsPlayerReading(); // modo Reading na pilha do PlayerController (Cap. 16)

    switch (Phase)
    {
    case EVGDirectorPhase::Relax:
        if ((TimeInPhase >= MinRelaxTime && Tension < 0.2f && !bReading) || TimeInPhase >= MaxRelaxTime)
        {
            EnterPhase(EVGDirectorPhase::BuildUp);
        }
        break;
    case EVGDirectorPhase::BuildUp:
        if (TimeInPhase >= BuildUpTime && !bReading)
        {
            EnterPhase(EVGDirectorPhase::Peak);
        }
        break;
    case EVGDirectorPhase::Peak:
        // O pico termina quando a tensão já subiu e caiu (a jogadora escapou) ou no tempo máximo.
        if (TimeInPhase >= MaxPeakTime || (TimeInPhase > 8.0f && Tension < 0.25f))
        {
            EnterPhase(EVGDirectorPhase::Recovery);
        }
        break;
    case EVGDirectorPhase::Recovery:
        if (TimeInPhase >= RecoveryTime)
        {
            EnterPhase(EVGDirectorPhase::Relax);
        }
        break;
    }
}

void UVGDirectorSubsystem::EnterPhase(EVGDirectorPhase NewPhase)
{
    const EVGDirectorPhase Old = Phase;
    Phase = NewPhase;
    TimeInPhase = 0.0f;
    ApplyToPresence();                     // escreve DirectorMode no Blackboard da Presença
    OnPhaseChanged.Broadcast(Old, NewPhase); // sinais ambientes, música, telemetria reagem
}
```

🔁 **A HFSM do Capítulo 34 não foi usada aqui, de propósito.** O Capítulo 34 justificou a `FVGHierarchicalStateMachine` genérica com dois usos "à vista": o vigia e os modos de alto nível da Presença. Nenhum dos dois se confirmou. O vigia migrou para Behavior Tree no Capítulo 37, e os modos da Presença viraram ramos da árvore dela, ligados pelo `DirectorMode`. O Diretor, que seria o candidato natural, tem quatro fases **planas**, sem sub-estados e sem comportamento herdado entre elas, e para isso um `switch` com transições centralizadas basta (Capítulo 4). Aplicado ao pé da letra, o critério do "terceiro caso" (Capítulo 6) diz que a HFSM genérica ficou sem cliente. É a lição de YAGNI cobrando a conta: a abstração foi construída para um uso previsto que não chegou. A decisão do projeto é mantê-la só como material de estudo, com os testes, fora do código de jogo. Num projeto real, ela seria apagada.

E a Behavior Tree da Presença (Capítulo 37) ganha um decorator no topo de cada ramo, observando a chave `DirectorMode`:

| Fase | Ramos permitidos | Ajustes |
|---|---|---|
| **Relax** | Recuar, Espreitar (pontos **longe** da jogadora) | Caçar e Investigar **bloqueados** |
| **BuildUp** | Recuar, Investigar, Espreitar (pontos **perto**) | Caçar bloqueado; o Diretor dispara sinais (flicker, ruídos distantes) |
| **Peak** | Todos | — |
| **Recovery** | Recuar, Retirar-se (EQS para longe, depois some) | Caçar e Investigar bloqueados |

Repare na fronteira: o ramo **Recuar** (a reação à luz) está liberado em **todas** as fases. O Diretor nunca impede a Presença de obedecer às regras — ele só controla quando ela pode **caçar**.

### 5. Sinais do Build-up

Ao entrar em `BuildUp`, o Diretor publica no barramento (Capítulo 24) um evento `Event.Director.BuildUp`, e um pequeno ator de "ambiência" por setor (em Blueprint) reage: faz uma luz próxima da jogadora falhar com o perfil de "presença" (Capítulo 13), toca um ruído distante de passos metálicos **do lado** onde a Presença está, e muda a camada de música (Capítulo 52). A jogadora sente a aproximação antes de ver qualquer coisa.

---

## Projeto 5 — conclusão

### Critérios

- [ ] **Vigias** (Galpão): percebem com consciência gradual; decidem por BT + utilidade (atacar, cobrir-se, recarregar, avançar, recuar, suprimir, flanquear); posicionam por EQS; coordenam por tokens (no máximo dois atacando, um flanqueando, um suprimindo, uma fala por vez); suprimem e são supressíveis; não atiram através de colegas.
- [ ] **Presença** (Casa de Força): espreita no escuro, ouve passos (mais na passarela metálica), vê muito melhor a lanterna acesa, investiga e procura de forma plausível, caça com telegrafia, ataca em "dois toques", recua da luz do sinalizador, nunca entra na luz nem atravessa portas fechadas.
- [ ] **Diretor**: as fases Relax → Build-up → Peak → Recovery acontecem numa sessão de 10 minutos; o alívio mínimo é respeitado; nenhum pico começa durante a leitura de um documento.
- [ ] **Ferramentas**: Gameplay Debugger mostra percepção, BT, Blackboard e EQS; o Visual Logger tem os estados e pontuações; `vg.Debug.Noise`, `vg.Debug.Utility` e a telemetria funcionam.
- [ ] **Desempenho**: com quatro vigias e a Presença ativos, o custo de IA (tick de BT, percepção, EQS) está abaixo de 1 ms por frame na sua máquina (meça com `stat` e o Unreal Insights — Capítulo 59).

### Retrospectiva

No `DEVLOG.md`:

1. Releia as "dores do cérebro ingênuo" (Capítulo 30). Quais foram resolvidas e por qual capítulo?
2. Qual decisão da Parte V mais mudou a sensação da Presença? (A navegação pela luz? A consciência gradual? O Diretor?)
3. Onde a IA ainda quebra a ilusão? (Anote para o projeto final.)
4. O Turno da Noite (Interlúdio I) com a Presença de verdade: o susto do corredor (que era uma malha aparecendo e sumindo) deve continuar roteirizado ou virar sistêmico? (Pense em travas de roteiro.)

---

## Decisões arquiteturais

1. **Coordenação como sistema próprio**: informação compartilhada + tokens + coordenador mínimo.
2. **Tokens como semáforos**, com liberação garantida (`OnCeaseRelevant`, morte) e recuperação de tokens vazados.
3. **O coordenador sugere papéis (bônus de utilidade); o agente decide; tokens limitam.**
4. **O Diretor controla a frequência dos encontros, nunca as regras.** Recuo da luz é sempre permitido.
5. **Fases de pacing numa máquina de estados** com tempos mínimos e máximos e travas de roteiro com handle.
6. **Nenhum pico durante leitura**; reposicionamento só fora de vista.
7. **Parâmetros de pacing como dados** (Data Asset no projeto final).

---

## Armadilhas

- **Tokens que vazam** (adquiridos e nunca liberados) — o combate para.
- **A leitura que congela o Diretor.** As transições de Relax e BuildUp esperam a jogadora parar de ler. Uma jogadora que mantém um documento aberto (de propósito ou por distração) congela o ritmo do jogo. Limite o efeito: a leitura adia a transição por no máximo alguns segundos, ou o tempo em leitura entra na estimativa de tensão (o Capítulo 70 chega a esse achado analisando o loop com IA).
- **Coordenador que dá ordens rígidas** e quebra a reatividade individual.
- **Diretor que viola regras** (Presença surgindo à vista, na luz, atacando sem telegrafia).
- **Pacing sem tempo mínimo de alívio** — tensão constante deixa de ser tensão.
- **Picos durante momentos narrativos** (leitura, cinemática).
- **Dificuldade sem botão**: capacidades de token fixas no código em vez de dados.

---

## Exercício

**Parte 1 — tokens (2 h).** Implemente o subsistema de tokens, a task de aquisição, o service de liberação garantida e a consideração `TokenAvailable`. Teste com quatro vigias: nunca mais de dois atacando ao mesmo tempo. Mate um vigia que tinha token e verifique que outro o consegue em seguida.

**Parte 2 — papéis (1,5 h).** Implemente o coordenador mínimo com os papéis `Suppress` e `Flank`. Repita o desafio do Capítulo 41 e compare.

**Parte 3 — Diretor (2,5 h).** Implemente o Diretor, o decorator de `DirectorMode` na BT da Presença e os sinais do Build-up. Jogue 15 minutos na Casa de Força e, com a telemetria (Capítulo 24), desenhe a curva de tensão real da sessão. Ela se parece com a curva planejada no Capítulo 5?

**Parte 4 — conclusão do Projeto 5 (2 h).** Passe pelos critérios, meça o custo de IA e escreva a retrospectiva.

---

## Desafio — o Diretor que aprende a jogadora

Hoje, o Diretor usa os mesmos tempos para todas as jogadoras. Faça-o **adaptar** levemente o ritmo:

1. Se a jogadora morreu duas vezes nos últimos 5 minutos, aumente o tempo mínimo de alívio em 50% e reduza a capacidade de tokens de ataque (para os vigias) em 1.
2. Se ela passou mais de 3 minutos em zonas seguras sem avançar, encurte o próximo Relax (ela está "acampando").
3. Tudo de forma **sutil**: nenhuma mudança deve ser perceptível como "o jogo ficou mais fácil".

Pergunta para o `DEVLOG.md`: isso é dificuldade dinâmica (Capítulo 21, seção 21.5)? Que riscos ela traz? Como você verificaria, em playtest, que a jogadora **não** percebe a adaptação? *(Releia a armadilha "realimentação negativa visível" do Capítulo 5.)*

---

## Uso de IA

1. **Para revisar a coordenação:**
   > "Revise este sistema de tokens de coordenação para inimigos (semáforos por tipo, aquisição numa task de Behavior Tree, liberação num service via OnCeaseRelevant, recuperação de tokens de atores destruídos). Encontre cenários em que um token vaza, em que dois agentes acreditam ter o mesmo token e em que o combate trava. [código]"

2. **Para desenhar o Diretor:**
   > "Atue como designer de pacing de jogos de terror. Para um jogo de 15 minutos com uma única criatura, proponha as fases de um diretor de IA (relaxamento, construção, pico, recuperação), as entradas da estimativa de tensão, os tempos mínimos e máximos de cada fase e os sinais audiovisuais da fase de construção. Explique como garantir que o diretor nunca viole as regras que o jogador aprendeu."

3. **Para comparar abordagens de coordenação:**
   > "Compare coordenação emergente (informação compartilhada), centralizada (coordenador que atribui papéis) e por tokens para esquadrões de 3 a 6 inimigos num shooter: complexidade, previsibilidade, robustez a interrupções, efeito na dificuldade e facilidade de depuração."

---

## Checklist

- [ ] Sei identificar problemas de coordenação e escolher entre emergente, centralizada e tokens.
- [ ] Implementei tokens com liberação garantida e recuperação de vazamentos.
- [ ] Implementei atribuição de papéis por utilidade.
- [ ] Implementei o Diretor com fases, estimativa de tensão, travas de roteiro e respeito à leitura.
- [ ] O Diretor controla frequência, não regras.
- [ ] Concluí o Projeto 5 segundo os critérios e escrevi a retrospectiva.

---

## Para ir além

- **Michael Booth, *The AI Systems of Left 4 Dead*** (2009) — apresentação pública sobre o AI Director e o pacing dinâmico.
- **Steve Rabin (org.), *Game AI Pro*** — capítulos sobre coordenação de esquadrões, tokens de ataque e diretores de pacing.
- **GDC Vault** (gdcvault.com) — busque talks sobre *squad AI*, *combat pacing* e *AI directors*.

---

## Fechamento da Parte V

```text
Cap. 33  Game AI: experiência, não otimalidade; perceber → decidir → agir; a pilha da Unreal.
Cap. 34  FSM: padrão State, HFSM, ancestral comum, explosão de transições.
Cap. 35  Navigation: NavMesh, filtros e áreas — a escuridão como mapa; portas.
Cap. 36  Perception: estímulo → percepção → consciência; luz e ruído; nível de ameaça.
Cap. 37  Behavior Trees: prioridades, aborts, nós em C++, a árvore da Presença.
Cap. 38  Blackboard: memória de trabalho, contrato de escrita, herança, chaves de grupo.
Cap. 39  EQS: o melhor lugar para...; cobertura, espreita, recuo, busca.
Cap. 40  Utility AI: considerações, curvas, inércia; utilidade escolhe, BT executa.
Cap. 41  Tactical AI: supressão, flanco, perigo, GOAP/HTN, barks.
Cap. 42  Squad AI: tokens, papéis e o Diretor de pacing.
```

O **Projeto 5 está concluído**: a Presença e os vigias têm cérebros de verdade. Na Parte VI, a outra metade da Vigília — a **história** — ganha os seus sistemas, começando pela refatoração do *Turno da Noite*.

➡️ **Próximo:** [Parte VI — Capítulo 43: Narrative Design](../parte-06/cap-43-narrative-design.md)

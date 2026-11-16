# Capítulo 40 — Utility AI

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar **Utility AI**: cada ação possível recebe uma **pontuação** a partir de **considerações** normalizadas, e o agente escolhe a mais útil;
- usar **curvas de resposta** para transformar fatos do jogo (vida, distância, munição) em "quanto isso importa";
- combinar considerações com **multiplicação compensada** e evitar indecisão com **inércia** e **tempo mínimo de compromisso**;
- decidir quando Utility é melhor que uma Behavior Tree, e montar o **híbrido**: Utility escolhe a **intenção**, a BT a **executa**;
- implementar a escolha de intenção de combate do vigia — atacar, cobrir-se, recarregar, avançar, recuar — com regras puras e testáveis.

---

## Contexto

A Behavior Tree do vigia (Capítulos 37–39) tem um ramo de cobertura com um decorator: "vida < 50% **ou** pente vazio". Essa regra é uma **fronteira dura**: com 51% de vida, o vigia nunca se cobre; com 49%, sempre. Na prática, um soldado plausível pesa várias coisas ao mesmo tempo — "estou ferido, mas a jogadora está perto e exposta; vale mais atirar" ou "tenho munição, mas estou levando tiro sem cobertura há dois segundos; vale mais me proteger". Decisões assim são **graduais e multifatoriais**, e Behavior Trees as expressam mal: cada combinação vira um decorator, e as fronteiras duras produzem comportamento mecânico.

**Utility AI** é a abordagem que trata a decisão como **pontuação**. Ela não substitui a Behavior Tree; ela resolve o tipo de pergunta em que a BT é fraca — "**qual** das opções é melhor agora?" — e deixa a BT fazer o que faz bem: executar a opção escolhida em passos.

---

## 40.1 O modelo

```text
  para cada AÇÃO possível:
       considerações (fatos normalizados 0..1, passados por curvas)
          ├── vida (curva: quanto MENOS vida, MAIS útil se cobrir)
          ├── sob fogo recente (curva: quanto mais recente, mais útil)
          ├── distância da cobertura (curva: perto = útil; longe = pouco)
          └── munição no pente (curva: ...)
       pontuação da ação = combinação das considerações × peso da ação

  escolher a ação de MAIOR pontuação (com inércia para a ação atual)
```

Três elementos:

1. **Ações** — as opções entre as quais o agente escolhe (atacar, cobrir-se, recarregar, avançar, recuar). Cada uma tem as **suas** considerações.
2. **Considerações** — perguntas sobre o mundo, cada uma devolvendo um número entre 0 e 1: "quão ferido estou?", "há quanto tempo levei dano?", "quão perto está o alvo?".
3. **Curvas de resposta** — transformam o fato bruto em **utilidade**. A mesma entrada ("vida 40%") pode significar coisas opostas para ações diferentes: para "cobrir-se", vida baixa é motivo forte; para "avançar", é motivo para não avançar.

### Curvas de resposta

```text
 utilidade                     utilidade                     utilidade
  1 ┤        ╱                  1 ┤╲                           1 ┤          ╭────
    │      ╱                      │ ╲                            │         ╱
    │    ╱                        │  ╲___                        │        │
    │  ╱                          │      ╲____                   │       ╱
  0 ┼╱─────────                 0 ┼───────────╲───             0 ┼──────╯────────
    0   entrada   1               0   entrada   1                0   entrada   1
     LINEAR                        INVERSA (decrescente)          LOGÍSTICA (limiar suave)
```

A **logística** (em "S") é especialmente útil: ela substitui uma fronteira dura ("< 50%") por uma **transição suave** em torno de um limiar — o vigia passa a "pensar" em se cobrir aos 60% e quase certamente se cobre aos 35%. As curvas são **dados**: na Unreal, `UCurveFloat` editáveis no editor de curvas, que designers ajustam vendo o formato.

> 🌉 **Ponte:** é **análise de decisão multicritério** (MCDA) e, mais familiar, **modelos de pontuação** (como um score de risco: cada fator normalizado, transformado e combinado). As curvas de resposta fazem o papel de **funções de transformação de features**.
>
> 🧱 **Onde a ponte cai:** um score de crédito é avaliado uma vez. O de um agente é reavaliado várias vezes por segundo, e precisa de **estabilidade temporal**: um agente que troca de decisão a cada reavaliação parece "nervoso" — a seção 40.3 trata disso.

---

## 40.2 Combinando considerações

Como juntar as considerações de uma ação numa pontuação? Duas opções comuns:

- **Média ponderada** — tolerante: uma consideração ruim é compensada pelas outras. Problema: uma ação com uma razão **proibitiva** ("não tenho munição" para "atacar") ainda pode vencer.
- **Produto** — rigoroso: qualquer consideração zero zera a ação (veto natural). Problema: **ações com mais considerações são punidas** só por terem mais termos (0,9 × 0,9 × 0,9 × 0,9 ≈ 0,66, mesmo que todas sejam "boas").

A solução difundida em palestras e textos sobre Utility AI (por exemplo, nos trabalhos de Dave Mark) é o **produto com fator de compensação**, que preserva o veto e corrige a punição pelo número de termos:

```text
 n = número de considerações
 para cada consideração c (já passada pela curva):
     fator_modificação = 1 − 1/n
     compensação = (1 − c) × fator_modificação
     c' = c + compensação × c
 pontuação = Π c'
```

Com isso, ações com 2 e com 6 considerações "boas" ficam comparáveis, e uma consideração em zero continua vetando a ação.

---

## 40.3 Estabilidade: inércia e compromisso

Um agente que reavalia a cada 0,3 s e escolhe sempre a ação de maior pontuação vai **oscilar** quando duas ações estiverem empatadas: cobre, ataca, cobre, ataca. O jogador vê um soldado indeciso. Duas técnicas resolvem:

- **Inércia** (*momentum*): a ação **atual** ganha um bônus (por exemplo, +15%) na comparação. Outra ação só assume se for **claramente** melhor. É histerese (Capítulo 4) aplicada a decisões.
- **Tempo mínimo de compromisso**: uma ação escolhida não pode ser trocada antes de X segundos, **exceto** por uma ação marcada como interrupção (ex.: "fugir de granada").

E uma terceira, para variedade: **escolha aleatória ponderada entre as melhores** (como no EQS e no spawn): se duas ações estão a menos de 5% uma da outra, sortear entre elas evita que todos os vigias façam exatamente a mesma coisa no mesmo momento.

---

## 40.4 Utility e Behavior Trees: o híbrido

As duas arquiteturas resolvem perguntas diferentes:

| Pergunta | Melhor ferramenta |
|---|---|
| "**Qual** intenção é a melhor agora?" (graduais, multifatoriais) | **Utility** |
| "**Como** realizar essa intenção?" (passos, sequências, condições, interrupções) | **Behavior Tree** |
| "Isso pode interromper aquilo?" (prioridades fixas: atordoado > tudo) | **Behavior Tree** (selector + aborts) |

O padrão do projeto:

```text
 BT_Vigia
  └─ SELECTOR
      ├─ [IsStaggered — abort Both]               Esperar fim do atordoamento   ← prioridade fixa
      ├─ [Aware AND TargetVisible — abort Both]
      │   SELECTOR "Combate"          (Service: VG Utility Select → escreve CombatIntent)
      │     ├─ [CombatIntent == TakeCover — abort Both]  EQS Cobertura → Move To → Recarregar
      │     ├─ [CombatIntent == Reload — abort Both]     Recarregar no lugar
      │     ├─ [CombatIntent == Advance — abort Both]    EQS ponto mais perto com visão → Move To
      │     ├─ [CombatIntent == Retreat — abort Both]    EQS ponto longe da jogadora → Move To
      │     └─ (Attack, padrão)                          Telegrafar → Rajada → Pausa
      ├─ [Suspicious — abort Lower]                Investigar
      └─                                           Patrulhar
```

O **service** de utilidade avalia as intenções periodicamente e escreve **uma chave** (`CombatIntent`); a árvore reage pela troca da chave (aborts). Cada intenção é executada pelo seu ramo — reutilizando as consultas EQS do Capítulo 39. A fronteira dura "vida < 50%" desaparece da árvore e vira uma **curva** numa consideração.

E as prioridades **fixas** (atordoamento, morte, fuga de perigo imediato) continuam na estrutura da árvore — Utility não deve decidir se o agente "considera" reagir a uma granada; isso é uma regra.

---

## Estudo de caso: decisões que parecem humanas

> **Pergunta:** por que agentes com decisões por pontuação parecem mais "humanos" do que agentes com regras rígidas?

**[FATO PÚBLICO]** A abordagem de utilidade em Game AI foi divulgada e sistematizada por desenvolvedores em palestras da GDC e em livros — por exemplo, a palestra *Improving AI Decision Modeling Through Utility Theory* (Dave Mark e Kevin Dill, GDC 2010) e o livro *Behavioral Mathematics for Game AI* (Dave Mark, 2009). Sistemas baseados em utilidade são comumente associados a jogos em que agentes precisam equilibrar muitas necessidades simultâneas, como simulações de vida (o gênero de *The Sims*) e jogos com agentes autônomos em grande número.

**[INFERÊNCIA]** A impressão de "humanidade" vem de três propriedades:

1. **Gradualidade** — um soldado ferido não muda de comportamento num limiar exato; ele fica progressivamente mais cauteloso. Curvas logísticas produzem isso.
2. **Contexto múltiplo** — a mesma ferida leva a decisões diferentes dependendo da distância, da cobertura, do que os colegas fazem. Combinar considerações produz isso.
3. **Variação** — dois agentes na mesma situação não fazem exatamente a mesma coisa. Pequenas diferenças de parâmetros por agente e sorteio entre os melhores produzem isso.

O custo é a **previsibilidade para o designer**: com muitas considerações, é difícil saber, só olhando, o que o agente fará — o que exige ferramentas de depuração que mostrem as pontuações (a seção de implementação inclui uma).

**Lição:** **use regras para o que deve ser certo e pontuação para o que deve parecer pensado.** O vigia **sempre** reage ao atordoamento (regra); ele **pondera** entre atirar e se cobrir (pontuação).

---

## Comparação com o desenvolvimento tradicional

| Utility AI | O que você conhece | Onde a analogia cai |
|---|---|---|
| Considerações normalizadas + curvas | Features normalizadas + funções de transformação | Avaliado várias vezes por segundo |
| Produto compensado | Agregação multiplicativa com correção | O "veto" (zero) é uma ferramenta de design |
| Inércia e compromisso | Histerese / *debounce* em decisões automáticas | O objetivo é parecer **decidido**, não ótimo |
| Utility escolhe, BT executa | Motor de decisão + motor de workflow | Ambos rodam no mesmo frame, para o mesmo agente |

---

## Implementação

### 1. Considerações e ações

```cpp
// Source/Vigilia/AI/Utility/VGUtilityTypes.h
#pragma once

#include "CoreMinimal.h"
#include "VGUtilityTypes.generated.h"

class UCurveFloat;

/** Fatos do mundo que as considerações podem ler (todos normalizados 0..1). */
UENUM(BlueprintType)
enum class EVGUtilityInput : uint8
{
    HealthRatio,          // 1 = vida cheia
    AmmoRatio,            // 1 = pente cheio
    TargetDistance,       // 0 = colado, 1 = no limite de MaxRelevantDistance
    TimeSinceDamaged,     // 0 = acabou de levar dano, 1 = há muito tempo
    TargetVisible,        // 0 ou 1
    HasCoverNearby,       // 0 ou 1 (última consulta de cobertura teve resultado)
    AlliesEngaging,       // fração de aliados atacando a jogadora agora (Cap. 42)
    // Novas entradas entram AQUI, antes de Count (os Capítulos 41 e 42 acrescentam algumas).
    Count UMETA(Hidden)   // não é uma entrada: é o tamanho do contexto
};

/** O "retrato" do mundo para uma avaliação. Montado uma vez por avaliação; regras puras o leem. */
USTRUCT()
struct FVGUtilityContext
{
    GENERATED_BODY()

    static constexpr int32 NumInputs = static_cast<int32>(EVGUtilityInput::Count);
    float Inputs[NumInputs] = {}; // o tamanho acompanha o enum; tudo começa em 0
    float Get(EVGUtilityInput Input) const { return Inputs[static_cast<int32>(Input)]; }
    void Set(EVGUtilityInput Input, float Value) { Inputs[static_cast<int32>(Input)] = FMath::Clamp(Value, 0.f, 1.f); }
};

USTRUCT(BlueprintType)
struct FVGConsideration
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, Category = "Utility")
    EVGUtilityInput Input = EVGUtilityInput::HealthRatio;

    /** Entrada (0..1) → utilidade (0..1). Sem curva: identidade. */
    UPROPERTY(EditAnywhere, Category = "Utility")
    TObjectPtr<UCurveFloat> Curve;
};

USTRUCT(BlueprintType)
struct FVGUtilityAction
{
    GENERATED_BODY()

    /** Valor escrito no Blackboard quando esta ação vence (ex.: TakeCover). */
    UPROPERTY(EditAnywhere, Category = "Utility")
    FName Intent;

    UPROPERTY(EditAnywhere, Category = "Utility", meta = (ClampMin = "0.0"))
    float Weight = 1.0f;

    UPROPERTY(EditAnywhere, Category = "Utility")
    TArray<FVGConsideration> Considerations;
};

namespace VGUtility
{
    /** Produto com fator de compensação. Qualquer consideração 0 veta a ação. */
    float ScoreAction(const FVGUtilityAction& Action, const FVGUtilityContext& Context);

    /** Índice da melhor ação, com inércia para a atual (bônus multiplicativo). INDEX_NONE se todas forem 0. */
    int32 SelectBest(const TArray<FVGUtilityAction>& Actions, const FVGUtilityContext& Context,
                     int32 CurrentIndex, float InertiaBonus, TArray<float>* OutScores = nullptr);
}
```

```cpp
// Source/Vigilia/AI/Utility/VGUtilityTypes.cpp
#include "AI/Utility/VGUtilityTypes.h"

#include "Curves/CurveFloat.h"

float VGUtility::ScoreAction(const FVGUtilityAction& Action, const FVGUtilityContext& Context)
{
    const int32 Count = Action.Considerations.Num();
    if (Count == 0)
    {
        return Action.Weight; // ação "padrão", sem condições
    }

    const float Modification = 1.0f - 1.0f / Count;
    float Score = 1.0f;
    for (const FVGConsideration& Consideration : Action.Considerations)
    {
        const float Raw = Context.Get(Consideration.Input);
        const float Shaped = FMath::Clamp(Consideration.Curve ? Consideration.Curve->GetFloatValue(Raw) : Raw, 0.0f, 1.0f);
        const float MakeUp = (1.0f - Shaped) * Modification;
        Score *= Shaped + MakeUp * Shaped; // compensação pelo número de considerações
        if (Score <= 0.0f)
        {
            return 0.0f; // veto
        }
    }
    return Score * Action.Weight;
}

int32 VGUtility::SelectBest(const TArray<FVGUtilityAction>& Actions, const FVGUtilityContext& Context,
                            int32 CurrentIndex, float InertiaBonus, TArray<float>* OutScores)
{
    int32 Best = INDEX_NONE;
    float BestScore = 0.0f;
    for (int32 i = 0; i < Actions.Num(); ++i)
    {
        float Score = ScoreAction(Actions[i], Context);
        if (i == CurrentIndex)
        {
            Score *= 1.0f + InertiaBonus; // a atual precisa ser superada com folga
        }
        if (OutScores) { OutScores->Add(Score); }
        if (Score > BestScore)
        {
            BestScore = Score;
            Best = i;
        }
    }
    return Best;
}
```

As regras são **funções puras** sobre um contexto — testáveis sem mundo (Capítulo 6). O contexto é montado **uma vez** por avaliação, para que todas as ações vejam o mesmo retrato do mundo.

### 2. O service de seleção

```cpp
// Source/Vigilia/AI/BT/BTService_VGUtilitySelect.h (essencial)
UCLASS()
class VIGILIA_API UBTService_VGUtilitySelect : public UBTService
{
    GENERATED_BODY()
public:
    UBTService_VGUtilitySelect();

protected:
    virtual void TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
    virtual uint16 GetInstanceMemorySize() const override;
    virtual void InitializeMemory(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, EBTMemoryInit::Type InitType) const override;
    virtual void CleanupMemory(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, EBTMemoryClear::Type CleanupType) const override;

    UPROPERTY(EditAnywhere, Category = "Utility")
    TArray<FVGUtilityAction> Actions;

    UPROPERTY(EditAnywhere, Category = "Utility", meta = (ClampMin = "0.0"))
    float InertiaBonus = 0.15f;

    /** Tempo mínimo antes de trocar de intenção (s). */
    UPROPERTY(EditAnywhere, Category = "Utility", meta = (ClampMin = "0.0"))
    float MinCommitTime = 1.0f;

    UPROPERTY(EditAnywhere, Category = "Utility", meta = (ClampMin = "100.0"))
    float MaxRelevantDistance = 2500.0f;

    UPROPERTY(EditAnywhere, Category = "Blackboard")
    FBlackboardKeySelector IntentKey;

private:
    FVGUtilityContext BuildContext(UBehaviorTreeComponent& OwnerComp) const;
};
```

```cpp
// BTService_VGUtilitySelect.cpp (trechos)
namespace
{
    struct FVGUtilityMemory
    {
        int32 CurrentIndex = INDEX_NONE;
        float CommittedAt = -100.0f;
    };
}

UBTService_VGUtilitySelect::UBTService_VGUtilitySelect()
{
    NodeName = TEXT("VG Utility Select");
    Interval = 0.3f;
    RandomDeviation = 0.05f; // agentes diferentes não reavaliam no mesmo frame
}

uint16 UBTService_VGUtilitySelect::GetInstanceMemorySize() const { return sizeof(FVGUtilityMemory); }

// Sem isto, a memória chega zerada e os inicializadores acima NÃO rodam (Capítulo 37):
// CurrentIndex começaria em 0, não INDEX_NONE — a inércia iria para a ação 0 e, se a melhor
// ação fosse justamente a 0, a intenção nunca seria escrita no Blackboard.
void UBTService_VGUtilitySelect::InitializeMemory(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory,
                                                  EBTMemoryInit::Type InitType) const
{
    InitializeNodeMemory<FVGUtilityMemory>(NodeMemory, InitType);
}

void UBTService_VGUtilitySelect::CleanupMemory(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory,
                                               EBTMemoryClear::Type CleanupType) const
{
    CleanupNodeMemory<FVGUtilityMemory>(NodeMemory, CleanupType);
}

void UBTService_VGUtilitySelect::TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
    Super::TickNode(OwnerComp, NodeMemory, DeltaSeconds);
    FVGUtilityMemory* Memory = CastInstanceNodeMemory<FVGUtilityMemory>(NodeMemory);
    const float Now = OwnerComp.GetWorld()->GetTimeSeconds();

    if (Memory->CurrentIndex != INDEX_NONE && Now - Memory->CommittedAt < MinCommitTime)
    {
        return; // compromisso: ainda não pode trocar
    }

    TArray<float> Scores;
    const FVGUtilityContext Context = BuildContext(OwnerComp);
    const int32 Best = VGUtility::SelectBest(Actions, Context, Memory->CurrentIndex, InertiaBonus, &Scores);

    if (Best != INDEX_NONE && Best != Memory->CurrentIndex)
    {
        Memory->CurrentIndex = Best;
        Memory->CommittedAt = Now;
        OwnerComp.GetBlackboardComponent()->SetValueAsName(IntentKey.SelectedKeyName, Actions[Best].Intent);
    }

    // Depuração: as pontuações de todas as ações no Visual Logger (seção 40.5).
    for (int32 i = 0; i < Scores.Num(); ++i)
    {
        UE_VLOG(OwnerComp.GetAIOwner(), LogVigilia, Verbose, TEXT("Utility %s = %.3f%s"),
            *Actions[i].Intent.ToString(), Scores[i], i == Memory->CurrentIndex ? TEXT("  <==") : TEXT(""));
    }
}
```

`BuildContext` lê o corpo (vida pelo `UVGHealthComponent`, munição pela arma atual, distância até o alvo do Blackboard), o Blackboard (alvo visível, cobertura disponível) e um carimbo de tempo do último dano (o componente de vida ganha `GetLastDamageTime()`). Todos os valores são normalizados no contexto. Logo no início do `BuildContext`, uma trava de compilação:

```cpp
static_assert(FVGUtilityContext::NumInputs == 7,
              "Nova entrada de utilidade? Preencha-a no BuildContext e atualize este número.");
```

> ⚠️ **Por que `Count` e não `Inputs[7]`:** com um tamanho literal, acrescentar uma entrada ao enum **compila** e escreve fora do array — corrupção de memória silenciosa. Com o array dimensionado por `Count`, ele cresce sozinho; e o `static_assert` impede que a entrada nova fique esquecida (sempre 0) no `BuildContext`.

### 3. As intenções do vigia

Configuradas no nó do service, na árvore (são **dados**):

| Intenção | Considerações (entrada → curva) | Leitura |
|---|---|---|
| **Attack** | `TargetVisible` (identidade); `AmmoRatio` (degrau suave: 0 → 0, >0 → 1) | Atacar se vê e tem munição |
| **TakeCover** | `HealthRatio` (logística inversa em ~0,5); `TimeSinceDamaged` (inversa: dano recente → alto); `HasCoverNearby` (identidade — veto se não há cobertura) | Ferido e sob fogo, com cobertura por perto |
| **Reload** | `AmmoRatio` (inversa forte: vazio → 1); `TimeSinceDamaged` (crescente: seguro → alto) | Pente baixo e não está levando tiro |
| **Advance** | `TargetDistance` (crescente a partir de ~0,6); `HealthRatio` (crescente); `AlliesEngaging` (crescente: outros dando cobertura) | Longe, saudável, com apoio |
| **Retreat** | `HealthRatio` (inversa forte abaixo de ~0,25); `HasCoverNearby` (inversa: sem cobertura → alto) | Muito ferido e sem onde se esconder |

Repare que a regra "vida < 50% **ou** pente vazio" do Capítulo 38 se dissolveu em duas intenções (`TakeCover` e `Reload`), cada uma com uma **curva** em vez de um limiar, e com contexto (dano recente, cobertura disponível). O service do Capítulo 38 (`VG Combat Needs`) deixa de ser necessário — 🔁 remova-o.

### 4. O teste

```cpp
// Source/Vigilia/Tests/VGUtilityTest.cpp (essencial)
bool FVGUtilityScoringTest::RunTest(const FString& Parameters)
{
    FVGUtilityAction Attack;  Attack.Intent = TEXT("Attack");
    FVGConsideration Visible; Visible.Input = EVGUtilityInput::TargetVisible;
    Attack.Considerations.Add(Visible);

    FVGUtilityAction Idle;    Idle.Intent = TEXT("Idle"); Idle.Weight = 0.2f; // sem considerações

    FVGUtilityContext Seen;   Seen.Set(EVGUtilityInput::TargetVisible, 1.0f);
    FVGUtilityContext Unseen; Unseen.Set(EVGUtilityInput::TargetVisible, 0.0f);

    TestEqual(TEXT("Alvo invisível veta Attack"), VGUtility::ScoreAction(Attack, Unseen), 0.0f);
    TestEqual(TEXT("Vendo: Attack vence"), VGUtility::SelectBest({ Attack, Idle }, Seen, INDEX_NONE, 0.0f), 0);
    TestEqual(TEXT("Sem ver: Idle vence"), VGUtility::SelectBest({ Attack, Idle }, Unseen, INDEX_NONE, 0.0f), 1);

    // Inércia: com Attack quase empatado, a ação atual (Idle) se mantém.
    FVGUtilityContext Weak; Weak.Set(EVGUtilityInput::TargetVisible, 0.21f);
    TestEqual(TEXT("Inércia mantém a ação atual"), VGUtility::SelectBest({ Attack, Idle }, Weak, 1, 0.15f), 1);
    return true;
}
```

### 5. Ver as pontuações

Além do Visual Logger, um modo de debug na tela (`vg.Debug.Utility 1`) desenha sobre cada vigia as cinco pontuações como barras e destaca a escolhida. Sem isso, ajustar curvas é tatear no escuro: você vê o vigia fazer algo estranho e não sabe **por quê**. Com isso, você vê que `Retreat` estava em 0,41 contra `TakeCover` em 0,39 — e ajusta a curva.

---

## Projeto 5 — decisões graduais

1. Configure as cinco intenções no `BT_Vigia` e ajuste as curvas no Galpão.
2. Cenários de teste:
   - vigia com vida cheia, jogadora a 20 m e exposta → avança;
   - vigia ferido a 40%, levando tiro, com caixa por perto → cobre-se e recarrega;
   - vigia a 15% sem cobertura → recua;
   - dois vigias na mesma situação → não fazem exatamente a mesma coisa no mesmo instante (variação de reavaliação e, se quiser, pequenas diferenças de curva por instância).
3. **Para a Presença** (opcional neste capítulo): um service de utilidade escolhendo entre **Espreitar**, **Aproximar** e **Retirar-se** (fingir desistir e sumir no escuro), com considerações como nível de ameaça, tempo desde o último encontro e se a jogadora está na luz. O Capítulo 42 entrega essa decisão ao Diretor.

---

## Decisões arquiteturais

1. **Utility escolhe a intenção; a Behavior Tree executa e mantém as prioridades fixas.**
2. **Considerações normalizadas com curvas editáveis** (`UCurveFloat`); intenções configuradas como dados no nó.
3. **Produto com fator de compensação**; zero veta.
4. **Inércia e tempo mínimo de compromisso** contra indecisão; reavaliação com variação entre agentes.
5. **Regras puras testadas** (`VGUtility::ScoreAction`, `SelectBest`) sobre um contexto montado uma vez.
6. **Pontuações sempre visíveis** (Visual Logger, `vg.Debug.Utility`).

---

## Armadilhas

- **Fronteiras duras** onde a decisão deveria ser gradual.
- **Utility decidindo prioridades fixas** (reagir ao atordoamento).
- **Produto sem compensação** — ações com mais considerações sempre perdem.
- **Sem inércia** — agentes oscilando entre ações empatadas.
- **Contexto lido várias vezes por avaliação**, com o mundo mudando entre leituras.
- **Ajustar curvas sem ver as pontuações.**
- **Considerações demais** — a decisão fica impossível de prever e ajustar.

---

## Exercício

**Parte 1 — o núcleo (1,5 h).** Implemente os tipos, as regras puras e o teste. Acrescente um teste de compensação: uma ação com 4 considerações em 0,9 deve pontuar perto de uma com 1 consideração em 0,9.

**Parte 2 — o service (1,5 h).** Implemente o service, o contexto e a depuração na tela. Integre ao `BT_Vigia`.

**Parte 3 — curvas (1,5 h).** Crie as curvas das cinco intenções e ajuste-as nos cenários do Projeto 5, olhando as pontuações. Registre no `DEVLOG.md` duas situações em que o vigia fazia algo "estranho" e qual curva você mudou.

**Parte 4 — comparação (30 min).** Jogue o mesmo cenário com a regra dura do Capítulo 38 e com a utilidade. Descreva a diferença de sensação (MDA, Capítulo 5).

---

## Desafio — personalidade por curvas

Dê **personalidade** aos vigias sem mudar código: crie dois perfis de curvas (por exemplo, como Data Assets que o service lê, ou variantes da árvore) — **"veterano"** (cobre-se cedo, avança com apoio, recua raramente) e **"recruta"** (atira mais, cobre-se tarde, recua em pânico quando muito ferido). Coloque dois de cada no Galpão.

Pergunta para o `DEVLOG.md`: a jogadora percebe a diferença sem que ninguém conte? Que sinais (falas, animações) ajudariam a comunicá-la (Capítulo 33, ilusão de inteligência)? E onde essas curvas deveriam viver — no nó da árvore, num Data Asset por arquétipo, no pawn?

---

## Uso de IA

1. **Para desenhar curvas:**
   > "Para um soldado inimigo de shooter, proponha curvas de resposta (tipo e parâmetros, com a entrada normalizada 0..1) para as considerações de cinco intenções: atacar, cobrir-se, recarregar, avançar e recuar. As entradas disponíveis são: vida, munição no pente, distância ao alvo, tempo desde o último dano, alvo visível, cobertura disponível, fração de aliados atacando. Explique o comportamento resultante em três cenários."

2. **Para validar a matemática:**
   > "Explique o fator de compensação na combinação multiplicativa de considerações em Utility AI (modification = 1 − 1/n; makeUp = (1 − score) × modification; score' = score + makeUp × score), mostre exemplos numéricos com 1, 3 e 6 considerações, e discuta alternativas (média geométrica, média ponderada) com prós e contras."

3. **Para decidir o híbrido:**
   > "Num agente de jogo, quais decisões deveriam ser feitas por Utility AI e quais por prioridades fixas numa Behavior Tree? Dê critérios e exemplos, e descreva como integrar os dois (um service de utilidade escrevendo uma intenção no Blackboard, ramos da BT condicionados à intenção)."

---

## Checklist

- [ ] Sei explicar ações, considerações e curvas de resposta.
- [ ] Sei combinar considerações com produto compensado e por que o zero veta.
- [ ] Sei evitar indecisão com inércia e tempo de compromisso.
- [ ] Sei quando usar Utility e quando usar prioridades fixas, e montei o híbrido.
- [ ] Implementei e testei as regras puras e o service de seleção.
- [ ] Ajustei as intenções do vigia olhando as pontuações.

---

## Para ir além

- **Dave Mark, *Behavioral Mathematics for Game AI*** (2009) — o livro de referência sobre decisões por utilidade em jogos.
- **Dave Mark e Kevin Dill, *Improving AI Decision Modeling Through Utility Theory*** (GDC 2010) — palestra introdutória clássica (GDC Vault).
- **Steve Rabin (org.), *Game AI Pro*** — capítulos sobre arquiteturas de utilidade, curvas de resposta e depuração.

---

➡️ **Próximo:** [Capítulo 41 — Tactical AI](cap-41-tactical-ai.md)

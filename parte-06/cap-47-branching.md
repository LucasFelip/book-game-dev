# Capítulo 47 — Branching

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir escolhas **de sabor** (*flavor*), **de estado** e **estruturais**, e o custo de conteúdo de cada uma;
- usar os padrões de ramificação de produção: **ramificar e convergir**, **consequência tardia**, **variante por estado**;
- estimar o **orçamento de ramificação** de um jogo antes de escrever o conteúdo;
- fazer o **mundo** reagir a fatos (atores que aparecem, somem ou mudam), não só as falas;
- **auditar** conversas de forma combinatória: falas que nunca tocam, combinações de fatos em que nada é dito;
- desenhar o mapa de ramificação da Vigília inteira, do Turno da Noite ao final.

---

## Contexto

O Interlúdio I sentiu a ramificação no menor tamanho possível: uma escolha implícita (ler ou não o memorando) e duas falas que mudavam. Mesmo assim, a dor 4 apareceu: dois `Branch` em lugares diferentes, que precisavam "concordar" sobre a mesma variável.

Os capítulos seguintes resolveram o **mecanismo**:

- variantes por condição nos dados de diálogo (Capítulo 44);
- transições por fato nas quests (Capítulo 45);
- um estado narrativo com dono, anúncios e *snapshot* (Capítulo 46).

O mecanismo, porém, não responde à pergunta mais difícil, que é de **design e de produção**: *quantas* escolhas, de *que tipo*, com *que consequências*, e quanto conteúdo cada uma custa. Ramificação é a forma mais cara de agência (Capítulo 43, seção 43.3). Cada ramo é conteúdo que parte das jogadoras nunca vai ver.

Este capítulo é sobre gastar esse orçamento bem.

---

## 47.1 Três tipos de escolha

| Tipo | O que muda | Custo | Exemplo na Vigília |
|---|---|---|---|
| **Sabor** (*flavor*) | Uma reação imediata; nada é lembrado | Uma ou duas falas | Responder a Sônia com "Tô bem" ou "Não sei" quando ela pergunta se Helena está bem |
| **Estado** | Um fato é registrado e **lido depois**: falas, documentos, detalhes do mundo | Uma variante em cada lugar que o lê | Admitir ou não a Sônia que religou a turbina três (Capítulo 44) |
| **Estrutural** | O que **acontece**: outra cena, outro espaço, outro final | Um caminho inteiro de conteúdo | A escolha final da Vigília (seção 47.5) |

Os três tipos têm uma relação peculiar entre custo e efeito percebido:

- **Sabor** é barato e dá **reconhecimento imediato**, mas, se for tudo o que o jogo oferece, a jogadora percebe que nada importa.
- **Estado** é o melhor custo-benefício: o fato custa uma linha, e cada leitura dele custa uma variante. Uma consequência que aparece **muito depois** da escolha ("Sônia lembrou") vale mais, em agência percebida, que uma reação imediata.
- **Estrutural** é caro e raro. Bem colocado, é o que a jogadora conta para os amigos; mal colocado, dobra o custo de tudo o que vem depois.

---

## 47.2 Padrões de ramificação

### A árvore e a explosão combinatória

A ramificação ingênua é uma **árvore**: cada escolha divide a história em dois caminhos, e cada caminho continua independente.

```text
           escolha 1              escolha 2             escolha 3
 início ──┬── A ──────────┬── AA ───────────┬── AAA
          │               └── AB ───────────┴── ...      2³ = 8 versões do fim,
          └── B ──────────┬── BA ...                     cada uma escrita, dublada,
                          └── BB ...                     iluminada, testada
```

Três escolhas binárias dão oito finais. Dez dão 1.024. Nenhum estúdio produz árvores, e nenhum jogo do tamanho da Vigília deveria tentar. Os padrões abaixo existem para fugir dessa explosão.

### Ramificar e convergir (*branch and bottleneck*)

```text
            ┌── A (cena curta) ──┐
 escolha ───┤                    ├──► GARGALO (conteúdo comum) ──► ...
            └── B (cena curta) ──┘
                                  └── o fato "escolheu A/B" continua no estado
```

Os ramos são **curtos** e voltam a um ponto comum. A escolha não se perde na convergência: ela vira um **fato**, e o conteúdo comum tem variantes onde importa. É o padrão principal de jogos narrativos com escolhas. O custo é linear no número de escolhas, não exponencial.

### Consequência tardia

```text
 setor 1: escolha ──► fato           ...           setor 3: fala/documento/detalhe lê o fato
          (reação de sabor imediata)                (a consequência "volta")
```

A escolha produz uma reação imediata pequena e um fato. O fato é lido **muito depois**, longe da escolha. A distância é o que dá peso: a jogadora já tinha esquecido, e o jogo não.

### Variante por estado

Não é um padrão de estrutura, e sim de **conteúdo**: o mesmo momento da história tem versões ligeiramente diferentes conforme o estado, e cada variante é **local** (uma fala, um documento, um objeto no cenário). É o mecanismo das falas condicionadas (Capítulo 44) e das *storylets* (Capítulo 46), e é o que dá textura a uma história quase linear.

> 🌉 **Ponte:** a árvore é a explosão de estados de uma máquina de estados que ninguém fatorou. Ramificar e convergir é a **fatoração**: o estado relevante vira uma variável (o fato), e o fluxo volta a ser um só.
>
> 🧱 **Onde a ponte cai:** em software, fatorar estado é quase sempre bom. Em narrativa, a fatoração tem um **custo emocional**: se a jogadora perceber que todo caminho converge, a escolha perde o peso. A convergência precisa ser **disfarçada** por consequências locais bem colocadas. É engenharia de percepção, não só de estado.

---

## 47.3 O orçamento de ramificação

Antes de escrever, estime. Uma tabela simples, mantida em `docs/design/ramificacao.md`, evita a pior surpresa da produção narrativa: descobrir no fim que uma escolha do começo multiplicou o trabalho de todos os capítulos.

```text
 ESCOLHA                   TIPO       LIDA EM (consequências)                        CUSTO ESTIMADO
 Ler o memorando           estado     beat 7 (fala), final S1 (fala), setor 2 (doc)  3 variantes
 Admitir a Sônia (S1)      estado     resposta (fala), final S1 (fala), final (fala) 3 variantes + 3 reações
 Seis crachás (opcional)   estado     final S1 (fala), setor 2 (doc), final (detalhe) 3 variantes
 Escolha final (S3)        estrutural duas cenas finais + epílogo de rádio            2 cinemáticas, ~10 falas
```

Três regras práticas:

1. **Toda escolha de estado precisa de pelo menos uma consequência tardia.** Sem ela, é uma escolha de sabor disfarçada, e a jogadora atenta percebe.
2. **Escolhas estruturais vão para o fim**, onde o custo de dois caminhos é só o que resta do jogo. É por isso que tantos jogos concentram a ramificação estrutural no final (estudo de caso de GTA V).
3. **Cada variante tem um dono no catálogo.** Uma consequência que ninguém sabe que existe é uma variante que ninguém testa.

---

## 47.4 O mundo também se lembra

Até aqui, as consequências foram **falas**. Mas a narrativa ambiental (Capítulo 48) também lê estado: um bilhete que só aparece se a jogadora leu o livro; uma porta barricada se ela admitiu ter religado a turbina; os nomes dos seis homens do turno C escritos no vidro embaçado da sala de controle, se ela encontrou todos os crachás.

Para isso, o mundo precisa de uma peça genérica: um componente que **liga e desliga a presença de um ator** conforme uma condição sobre fatos, e que reage quando os fatos mudam (Capítulo 46, seção 46.5). Com ele, uma consequência no cenário é um ator colocado no nível com uma condição, e nenhum Blueprint de nível precisa decidir nada.

Ele tem uma regra de design importante: **um ator condicionado não pode aparecer ou sumir diante da jogadora sem querer.** Um fato concedido enquanto ela olha para o ator faria o objeto "piscar" para dentro da existência. Na Vigília, isso pode até ser desejado (é um jogo de terror), mas tem de ser **decisão**, não acidente. Por isso o componente tem um modo que só aplica a mudança quando o ator **não está sendo renderizado** (seção de implementação).

---

## 47.5 O mapa de ramificação da Vigília

```text
 PRÓLOGO (Pátio)      SETOR 1 (Casa de Força)          SETOR 2 (Subestação)     SETOR 3 (Turbinas)     FINAL
 ───────────────      ───────────────────────          ────────────────────     ──────────────────     ─────
                      [estado] memorando lido?  ─────► documento de Moraes       ─────────────────────► fala
                      [estado] admitiu a Sônia? ─────► tom de Sônia no setor 2  ─────────────────────► fala
                      [estado] 6 crachás?       ─────► os nomes aparecem         ─────────────────────► detalhe
                      [sabor]  "Tô bem"/"Não sei"
                                                        [estado] seguir Sônia ou
                                                                 o mapa de Moraes? ──► entrada do S3 ──► fala
                                                                                       [ESTRUTURAL]
                                                                                       desligar a turbina 3
                                                                                       ou deixá-la girar  ──► FINAL A / FINAL B
                                                                                                              + epílogo de rádio com
                                                                                                                variantes por todos os fatos
```

A Vigília tem **uma** escolha estrutural, no fim. Todo o resto é estado lido mais tarde, ou sabor. O desenho segue as três regras da seção 47.3, e o custo cabe num projeto individual: duas cenas finais e, em todo o resto, variantes locais. O Capítulo 81 implementa o final; este capítulo implementa as ferramentas e as consequências do setor 1.

---

## Estudos de caso

### Quantum Break — junções

**[FATO PÚBLICO]** *Quantum Break* (Remedy, 2016) alterna atos jogáveis com episódios em *live action*. No fim de cada um dos quatro primeiros atos (são cinco), há uma **junção** (*junction*): o jogador controla Paul Serene, o antagonista, e escolhe entre duas opções. A escolha muda partes do ato seguinte e do episódio filmado que vem depois dela.

**[INFERÊNCIA]** As junções são **poucas, grandes e muito sinalizadas**: o jogo para, mostra as duas possibilidades e deixa claro que é uma escolha importante. O desenho faz sentido diante do custo: cada variação de episódio filmado é produção audiovisual de verdade, e um número pequeno de escolhas, bem marcadas, concentra esse orçamento onde o jogador percebe. A escolha também é feita pelo antagonista, o que dá à jogadora a perspectiva do outro lado da história, uma forma de ironia dramática (Capítulo 43, seção 43.5).

**Lição para a Vigília:** quando a ramificação é cara, faça poucas escolhas e torne-as **inconfundíveis**. A escolha final da Vigília precisa ser assim: clara, consciente e com peso. As escolhas de estado, ao contrário, podem ser discretas, porque o custo delas é baixo e a consequência tardia faz o trabalho.

### GTA V — a ramificação estrutural no fim

**[FATO PÚBLICO]** No fim de *Grand Theft Auto V*, o jogador faz uma escolha que leva a um de três desfechos para o trio de protagonistas.

**[INFERÊNCIA]** Num jogo do tamanho de GTA V, uma escolha estrutural no meio da história multiplicaria um conteúdo enorme. Colocá-la no fim limita o custo ao que resta: as missões finais e o desfecho. É a regra 2 da seção 47.3 aplicada em escala de mundo aberto.

**Lição para a Vigília:** a única escolha estrutural fica no setor 3, depois de todo o resto. O custo dela são duas cenas finais, não dois jogos.

### Jogos de escolhas episódicos — convergência e reconhecimento

**[INFERÊNCIA]** Em jogos narrativos episódicos de escolhas (como os da Telltale), boa parte das escolhas converge para o mesmo enredo. O que sustenta a sensação de agência é o **reconhecimento**: personagens que lembram, falas que mudam, pequenos detalhes que diferem entre as jogadoras. É o padrão ramificar e convergir com consequências locais. A discussão pública sobre esses jogos costuma girar em torno de quanto a convergência é percebida, e de quanto ela incomoda quando é percebida.

**Lição para a Vigília:** convergir não é trapacear, desde que a escolha seja **lembrada** em algum lugar perceptível. O catálogo de consequências (seção 47.3) é a garantia de que nenhuma escolha de estado fica sem eco.

---

## Comparação com o desenvolvimento tradicional

| Ramificação | O que você conhece | Onde a analogia cai |
|---|---|---|
| Árvore de escolhas | Explosão de estados | Fatorar estado é engenharia; disfarçar a fatoração é design |
| Ramificar e convergir | *Fork/join* com o resultado gravado | O *join* precisa **parecer** que não aconteceu |
| Consequência tardia | Leitura de estado gravado muito depois | O valor está na distância temporal, que em software seria acoplamento ruim |
| Orçamento de ramificação | Estimativa de escopo por funcionalidade | O custo cresce com **cada leitura** do fato, não com a escolha |
| Auditoria combinatória | Testes baseados em propriedades / combinatórios | O "erro" pode ser estético: uma fala que nunca toca não quebra nada, só desperdiça |
| Ator condicionado a fatos | *Feature flag* no front-end | Mudar diante do usuário é bug em software; num jogo de terror, pode ser o susto |

---

## Unreal Engine: o que existe

Nada específico de ramificação: os mecanismos são os dos Capítulos 44–46 (condições por `FGameplayTagQuery`, transições de quest, fatos com anúncio). O que a engine oferece para as ferramentas deste capítulo:

- **Componentes de ator** com `SetActorHiddenInGame`, `SetActorEnableCollision` e `SetActorTickEnabled`, para ligar e desligar a presença de um ator.
- **`AActor::WasRecentlyRendered(Tolerance)`**, que diz se o ator foi renderizado nos últimos instantes. É uma aproximação de "a jogadora está vendo isto", suficiente para adiar uma mudança. ⚠️ Confira o comportamento na sua versão e lembre que *renderizado* inclui sombras e reflexos.
- **Testes de automação** e o **Asset Registry** (`IAssetRegistry`), para percorrer todos os assets de diálogo num teste de conteúdo (desafio).

---

## Abordagens: como verificar a ramificação

| Critério | A. Jogar todos os caminhos | B. Cheats para montar estados (Caps. 44–46) | **C. Auditoria combinatória automática** |
|---|---|---|---|
| **Cobertura** | Baixa: ninguém joga 2ⁿ vezes | Média: só os estados que alguém lembra de montar | Total, para os fatos declarados como relevantes |
| **Custo** | Horas por mudança | Minutos por estado | Segundos, em cada execução de testes |
| **O que encontra** | Tudo, inclusive o que é sentido | Bugs nos estados montados | Falas inalcançáveis, conversas mudas, escolhas sem saída |
| **O que não encontra** | O que ninguém jogou | O que ninguém montou | Se a variante é **boa** |

**Decisão: C para cobertura, B para qualidade.** A auditoria garante que todo conteúdo pode tocar e que nenhuma combinação deixa a jogadora sem resposta. Os cheats deixam um humano conferir, em segundos, se cada variante soa certa. Jogar tudo continua necessário, mas só para o que importa sentir.

---

## Implementação

### 1. O mundo condicionado a fatos

```cpp
// Source/Vigilia/Narrative/VGFactGateComponent.h
#pragma once

#include "Components/ActorComponent.h"
#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "VGFactGateComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGFactGateSignature, bool, bOpen);

/**
 * Liga/desliga a presença do ator dono conforme uma condição sobre fatos narrativos.
 * Reage a mudanças de fato e a restaurações de save. Para outros efeitos, escute OnGateChanged.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGFactGateComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGFactGateComponent();

    UPROPERTY(EditAnywhere, Category = "Vigilia|FactGate")
    FGameplayTagQuery Condition;

    /** Inverte: o ator existe ENQUANTO a condição NÃO passa. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|FactGate")
    bool bInvert = false;

    /** Só aplica a mudança quando o ator não está sendo renderizado (nada "pisca" diante da jogadora). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|FactGate")
    bool bDeferWhileVisible = true;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|FactGate")
    FVGFactGateSignature OnGateChanged;

    UFUNCTION(BlueprintPure, Category = "Vigilia|FactGate")
    bool IsOpen() const { return bOpen; }

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
    bool Evaluate() const;
    void Apply(bool bNewOpen);
    void HandleNarrativeChanged();

    bool bOpen = true;
    bool bPending = false;
    FDelegateHandle FactHandle;
    FDelegateHandle RestoreHandle;
};
```

```cpp
// Source/Vigilia/Narrative/VGFactGateComponent.cpp
#include "Narrative/VGFactGateComponent.h"

#include "GameFramework/Actor.h"
#include "Narrative/VGNarrativeSubsystem.h"

UVGFactGateComponent::UVGFactGateComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false; // só tica enquanto há mudança adiada
    PrimaryComponentTick.TickInterval = 0.25f;
}

void UVGFactGateComponent::BeginPlay()
{
    Super::BeginPlay();
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        FactHandle = Narrative->OnFactChangedNative.AddWeakLambda(this, [this](FGameplayTag, bool) { HandleNarrativeChanged(); });
        RestoreHandle = Narrative->OnRestored.AddUObject(this, &UVGFactGateComponent::HandleNarrativeChanged);
    }
    bOpen = !Evaluate(); // força o primeiro Apply
    Apply(Evaluate());   // no BeginPlay, sem adiar: a jogadora ainda não viu nada
}

void UVGFactGateComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        Narrative->OnFactChangedNative.Remove(FactHandle);
        Narrative->OnRestored.Remove(RestoreHandle);
    }
    Super::EndPlay(EndPlayReason);
}

bool UVGFactGateComponent::Evaluate() const
{
    const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);
    const bool bMatches = Narrative && Narrative->MatchesFacts(Condition);
    return bInvert ? !bMatches : bMatches;
}

void UVGFactGateComponent::HandleNarrativeChanged()
{
    const bool bShouldBeOpen = Evaluate();
    if (bShouldBeOpen == bOpen)
    {
        bPending = false;
        SetComponentTickEnabled(false);
        return;
    }
    if (bDeferWhileVisible && GetOwner()->WasRecentlyRendered(0.2f))
    {
        bPending = true;                // tenta de novo quando ninguém estiver olhando
        SetComponentTickEnabled(true);
        return;
    }
    Apply(bShouldBeOpen);
}

void UVGFactGateComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    if (bPending)
    {
        HandleNarrativeChanged();
    }
}

void UVGFactGateComponent::Apply(bool bNewOpen)
{
    bPending = false;
    SetComponentTickEnabled(false);
    if (bNewOpen == bOpen)
    {
        return;
    }
    bOpen = bNewOpen;
    AActor* Owner = GetOwner();
    Owner->SetActorHiddenInGame(!bOpen);
    Owner->SetActorEnableCollision(bOpen);
    OnGateChanged.Broadcast(bOpen);
}
```

### Explicação das decisões

- **Reage a anúncios, não pergunta a cada quadro.** O componente só tica enquanto há uma mudança **adiada**, e a 4 Hz. Um nível com cem atores condicionados custa nada enquanto os fatos não mudam.
- **`AddWeakLambda` e remoção no `EndPlay`.** O dono do estado vive a sessão inteira, e os atores morrem a cada troca de nível. Uma inscrição que sobrevive ao ator é um ponteiro pendente esperando para ser chamado.
- **`OnRestored` reavalia tudo**, porque um load troca o estado inteiro de uma vez (Capítulo 46).
- **Adiar enquanto visível**, por padrão. `WasRecentlyRendered` é uma aproximação: um ator atrás da jogadora mas visível num reflexo ou numa sombra conta como "visto". Para o uso na Vigília, a aproximação é suficiente e conservadora: no pior caso, a mudança espera um pouco mais.
- **Esconder e desligar a colisão** cobre o caso comum (o objeto existe ou não). Efeitos diferentes (trocar o material, mudar o texto de uma placa) ouvem `OnGateChanged` no Blueprint do ator, e o componente continua genérico.
- **Primeiro `Apply` no `BeginPlay`, sem adiar.** Ao carregar o nível, nada foi visto ainda, e o mundo precisa nascer no estado certo, não "aparecer" um quadro depois.

### 2. Auditoria combinatória de conversas

A ferramenta responde a duas perguntas para uma conversa e uma lista de fatos relevantes:

1. **Que combinações de fatos deixam a conversa muda?** Nenhuma fala tocável no início.
2. **Que nós nunca tocam**, em nenhuma combinação e por nenhuma escolha?

```cpp
// Source/Vigilia/Narrative/VGBranchAudit.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"

class UVGDialogueData;

/** Auditoria de conteúdo ramificado: simula conversas sob todas as combinações dos fatos dados. */
namespace VGBranchAudit
{
    struct FResult
    {
        TArray<FGameplayTagContainer> SilentCombinations; // nada toca no início
        TArray<FName> UnreachableNodes;                   // nunca tocam
    };

    /** RelevantFacts: os fatos que as condições da conversa leem (máx. 12 → 4.096 combinações). */
    FResult Audit(const UVGDialogueData& Data, const TArray<FGameplayTag>& RelevantFacts);
}
```

```cpp
// Source/Vigilia/Narrative/VGBranchAudit.cpp
#include "Narrative/VGBranchAudit.h"

#include "Narrative/VGDialogueData.h"
#include "Narrative/VGDialogueRules.h"

namespace
{
    constexpr int32 MaxRelevantFacts = 12;
    constexpr int32 MaxDepth = 64; // laços de saltos em conteúdo

    // Percorre a conversa a partir de Index com os fatos dados, seguindo TODAS as escolhas visíveis
    // (e o silêncio, se houver tempo-limite). Marca os nós alcançados.
    void Walk(const UVGDialogueData& Data, int32 Index, FGameplayTagContainer Facts,
              TSet<int32>& Reached, int32 Depth)
    {
        static const TSet<FName> NoMemory; // auditoria de conteúdo: sem memória de "já dito"
        Index = VGDialogueRules::FindPlayable(Data, Index, Facts, NoMemory);
        if (Index == INDEX_NONE || Depth > MaxDepth)
        {
            return;
        }
        Reached.Add(Index);
        const FVGDialogueNode& Node = Data.Nodes[Index];
        Facts.AppendTags(Node.GrantFacts);

        const TArray<int32> Visible = VGDialogueRules::VisibleChoices(Node, Facts);
        if (Visible.IsEmpty())
        {
            Walk(Data, VGDialogueRules::ResolveNext(Data, Index, Node.Next), Facts, Reached, Depth + 1);
            return;
        }
        for (const int32 ChoiceIndex : Visible)
        {
            const FVGDialogueChoice& Choice = Node.Choices[ChoiceIndex];
            FGameplayTagContainer After = Facts;
            After.AppendTags(Choice.GrantFacts);
            Walk(Data, VGDialogueRules::ResolveNext(Data, Index, Choice.Next), After, Reached, Depth + 1);
        }
        if (Node.ChoiceTimeout > 0.0f) // o silêncio é um caminho
        {
            Walk(Data, VGDialogueRules::ResolveNext(Data, Index, Node.TimeoutNext), Facts, Reached, Depth + 1);
        }
    }
}

VGBranchAudit::FResult VGBranchAudit::Audit(const UVGDialogueData& Data, const TArray<FGameplayTag>& RelevantFacts)
{
    FResult Result;
    if (!ensureMsgf(RelevantFacts.Num() <= MaxRelevantFacts, TEXT("Auditoria: fatos demais (%d)."), RelevantFacts.Num()))
    {
        return Result;
    }
    static const TSet<FName> NoMemory;
    TSet<int32> Reached;
    const int32 Combinations = 1 << RelevantFacts.Num();
    for (int32 Mask = 0; Mask < Combinations; ++Mask)
    {
        FGameplayTagContainer Facts;
        for (int32 Bit = 0; Bit < RelevantFacts.Num(); ++Bit)
        {
            if (Mask & (1 << Bit))
            {
                Facts.AddTag(RelevantFacts[Bit]);
            }
        }
        if (VGDialogueRules::FindPlayable(Data, 0, Facts, NoMemory) == INDEX_NONE)
        {
            Result.SilentCombinations.Add(Facts);
        }
        Walk(Data, 0, Facts, Reached, 0);
    }
    for (int32 i = 0; i < Data.Nodes.Num(); ++i)
    {
        if (!Reached.Contains(i))
        {
            Result.UnreachableNodes.Add(Data.Nodes[i].Id);
        }
    }
    return Result;
}
```

A auditoria **reaproveita** as regras puras do Capítulo 44 (`FindPlayable`, `ResolveNext`, `VisibleChoices`). Ela não reimplementa o fluxo: simula o mesmo fluxo que o subsistema executa. Se as regras mudarem, a auditoria muda junto.

### Explicação das decisões

- **Fatos relevantes declarados, não descobertos.** A auditoria recebe a lista de fatos que importam para aquela conversa (do catálogo, Capítulo 46). Descobri-los lendo as consultas é possível, mas acopla a ferramenta a detalhes internos de `FGameplayTagQuery`, e a lista explícita também documenta a conversa.
- **Limite de 12 fatos (4.096 combinações).** Uma conversa que depende de mais de doze fatos é um sinal de design, não de ferramenta: ela provavelmente deveria ser várias.
- **Simulação de todas as escolhas e do silêncio**, com os fatos que elas concedem. Assim, as respostas condicionadas a escolhas (o padrão "escolher é afirmar um fato" do Capítulo 44) são alcançadas corretamente.
- **Sem memória de "já dito".** A auditoria verifica o **conteúdo**, não uma partida. Falas `bOnce` são tratadas como inéditas.
- **Profundidade limitada** contra laços de saltos no conteúdo. Um laço real é bug de conteúdo, e o `IsDataValid` do Capítulo 44 pode ganhar um aviso para ele (exercício).

### 3. Teste

```cpp
// Source/Vigilia/Tests/VGBranchAuditTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayTags.h"
#include "Narrative/VGBranchAudit.h"
#include "Narrative/VGDialogueData.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGBranchAuditTest, "Vigilia.Narrative.Branching.Audit",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGBranchAuditTest::RunTest(const FString& Parameters)
{
    // Substitutos nativos: Memo = "leu o memorando", Admitted = "admitiu a Sônia".
    const FGameplayTag Memo = TAG_Status_Hidden;
    const FGameplayTag Admitted = TAG_Status_Zone_Safe;

    UVGDialogueData* Data = NewObject<UVGDialogueData>();

    FVGDialogueNode Ask; Ask.Id = TEXT("Pergunta");
    Ask.Condition = FGameplayTagQuery::MakeQuery_MatchTag(Memo);
    FVGDialogueChoice Admit; Admit.GrantFacts.AddTag(Admitted);
    Ask.Choices.Add(Admit);
    Ask.ChoiceTimeout = 6.0f; // o silêncio também é caminho

    FVGDialogueNode Reply; Reply.Id = TEXT("Admitiu");
    Reply.Condition = FGameplayTagQuery::MakeQuery_MatchTag(Admitted);

    FVGDialogueNode Praise; Praise.Id = TEXT("Paineis");
    Praise.Condition = FGameplayTagQuery::MakeQuery_MatchNoTags(FGameplayTagContainer(Memo));

    // Conteúdo morto: depois da resposta a conversa termina (End), e no caminho do silêncio
    // "admitiu" não existe — nenhum caminho chega aqui.
    FVGDialogueNode Dead; Dead.Id = TEXT("Impossivel");
    FGameplayTagContainer DeadTags(Admitted);
    Dead.Condition = FGameplayTagQuery::MakeQuery_MatchAllTags(DeadTags);
    Dead.Next = TEXT("End");

    Data->Nodes = { Praise, Ask, Reply, Dead };
    // Praise vem primeiro e encerra a conversa para quem não leu.
    Data->Nodes[0].Next = TEXT("End");
    Data->Nodes[2].Next = TEXT("End");

    const VGBranchAudit::FResult Result = VGBranchAudit::Audit(*Data, { Memo });

    TestEqual(TEXT("Nenhuma combinação muda"), Result.SilentCombinations.Num(), 0);
    TestTrue(TEXT("O nó impossível é inalcançável"), Result.UnreachableNodes.Contains(FName(TEXT("Impossivel"))));
    TestFalse(TEXT("A resposta é alcançável pela escolha"), Result.UnreachableNodes.Contains(FName(TEXT("Admitiu"))));
    return true;
}

#endif
```

Repare no que o teste prova: o nó `Admitiu` é alcançável **embora `Admitted` não esteja entre os fatos relevantes**, porque a auditoria segue a escolha que o concede. Já o nó `Impossivel` exige `Admitted`. O único caminho que concede esse fato termina na resposta (`End`), e o caminho do silêncio não o concede. Nenhuma combinação o alcança. Esse é exatamente o tipo de conteúdo morto que um roteiro produz quando alguém reorganiza nós sem rever as condições.

---

## Projeto 6 — as consequências do setor 1

🔁 A quarta etapa da refatoração do *Turno da Noite*: as escolhas do setor 1 passam a ter eco.

1. **Consequências tardias no próprio setor.** A conversa final (`DA_Dlg_S1_Final`) ganha variantes para `Helena.AdmittedTurbine3` e `Helena.Doubted`, além das do memorando (Capítulo 44):

| Fatos | Última fala de Sônia antes do chiado |
|---|---|
| leu o memorando + admitiu | "Helena, você me disse que religou. Você sabia. Sai daí agora—" |
| leu o memorando + duvidou | "Helena, sai daí. O memorando era claro. Se ela gira com os disjuntores em manutenção, alguém—" |
| leu o memorando + silêncio | "Helena, responde. O memorando—" |
| não leu | "Helena, os painéis mostram acionamento manual. Agora. Tem alguém aí com você—" |

2. **O mundo lembra.**
   - Na sala de controle, um `BP_NomesNoVidro` (seis nomes escritos na condensação da janela) com `UVGFactGateComponent`, condição `TEM S1.AllBadgesFound`. Ele aparece se a jogadora encontrou os seis crachás, e só quando ela não está olhando para a janela.
   - No hall, um `BP_BilheteTeixeira` (Capítulo 48) com a condição `TEM Document.Logbook.Read E NÃO TEM S1.BreakersRestored`. Ele aparece na volta do vestiário, antes do puzzle, e some depois.
3. **Auditoria.** Um teste de conteúdo roda a auditoria sobre cada conversa do setor 1 com os fatos do catálogo (desafio) e falha se houver combinação muda ou nó inalcançável.
4. **`docs/design/ramificacao.md`** com o orçamento da seção 47.3 e o mapa da seção 47.5.

### O inventário de dores, atualizado

| # | Dor | Situação depois do Cap. 47 |
|---|---|---|
| 4 | Ramificação vira `Branch` espalhado | ✅ Resolvida: escolhas viram fatos, consequências são variantes em dados (falas, quests, atores condicionados) e a cobertura é verificada automaticamente |
| 9 | Nada é testável | 🟡 Conteúdo ramificado agora tem teste; falta o save (Cap. 56) |

---

## Decisões arquiteturais

1. **Três tipos de escolha** (sabor, estado, estrutural), com orçamento estimado antes de escrever.
2. **Uma única escolha estrutural na Vigília, no fim**; o resto é estado com consequência tardia, ou sabor.
3. **Toda escolha de estado tem ao menos uma consequência tardia** registrada no catálogo.
4. **O mundo lê fatos** por um componente genérico (`UVGFactGateComponent`), reativo e que adia mudanças enquanto o ator é visível.
5. **Cobertura de ramificação por auditoria combinatória** sobre as regras do Capítulo 44; qualidade, por humanos com cheats.

---

## Armadilhas

- **Árvore em vez de convergência.** Cada escolha que não volta multiplica o conteúdo de tudo o que vem depois.
- **Escolha de estado sem eco.** O fato é registrado e ninguém lê: é uma escolha de sabor fingindo importância.
- **Escolha estrutural no começo.** Dobra o custo do jogo inteiro.
- **Convergência perceptível.** Quando a jogadora vê que todo caminho leva ao mesmo lugar sem nenhuma diferença, a confiança nas escolhas seguintes acaba.
- **Atores que "piscam".** Uma mudança de fato aplicada diante da jogadora, por acidente.
- **Conteúdo morto.** Variantes que nenhuma combinação alcança, escritas, gravadas e nunca ouvidas.
- **Conversas mudas.** Combinações de fatos em que nenhuma fala toca, e a jogadora não recebe resposta.
- **Testar só o caminho feliz.** O caminho que você joga é o caminho que você escreveu primeiro, e os outros apodrecem.

---

## Exercício

**Parte 1 — o orçamento (1 h).** Escreva `docs/design/ramificacao.md` com a tabela da seção 47.3 para o jogo inteiro (os setores 2 e 3 como esboço) e o mapa da seção 47.5. Para cada escolha de estado, liste pelo menos uma consequência tardia.

**Parte 2 — o mundo lembra (1,5 h).** Implemente `UVGFactGateComponent`. Coloque os dois atores do Projeto 6. Teste a regra do "não piscar":
- conceda `S1.AllBadgesFound` com `VGAddFact` olhando para a janela, e confirme que os nomes **não** aparecem;
- vire de costas e confirme que eles aparecem;
- faça o mesmo com `bDeferWhileVisible` desligado e anote no `DEVLOG.md` qual efeito é mais assustador.

**Parte 3 — auditoria (1,5 h).** Implemente `VGBranchAudit` e o teste. Rode a auditoria sobre `DA_Dlg_S1_Disjuntores` e `DA_Dlg_S1_Final` com os fatos relevantes. Depois, quebre de propósito uma condição (troque um `TEM` por `NÃO TEM`) e veja o que a auditoria aponta.

**Parte 4 — variantes do final (1 h).** Escreva e configure as quatro variantes da fala final. Use `VGAddFact`, `VGRemoveFact` e `VGQuestJump` para ouvir cada uma em menos de um minuto.

---

## Desafio — o teste de conteúdo

Escreva um teste de automação que percorra **todos** os assets `UVGDialogueData` do projeto pelo Asset Registry (`IAssetRegistry`, filtrando pela classe; ⚠️ a assinatura da busca por classe mudou ao longo do UE5, então confira na sua versão) e rode a auditoria sobre cada um. Onde guardar a lista de fatos relevantes de cada conversa?

1. Num campo novo do próprio asset (`AuditFacts`), mantido por quem escreve.
2. Derivada automaticamente das consultas.
3. Do catálogo de fatos, filtrado pelo prefixo do setor.

Implemente uma das três, justifique no `DEVLOG.md` e meça o tempo do teste com todas as conversas do setor 1.

---

## Uso de IA

1. **Para estimar o custo de uma escolha:**
   > "Atue como narrative designer de produção. Para esta escolha do meu jogo (descrição abaixo), liste todos os lugares em que ela poderia ter consequência (falas, documentos, cenário, cinemáticas, final), classifique cada consequência como essencial, desejável ou cortável, e estime o custo de conteúdo de cada uma em falas, documentos e cenas. [escolha + estrutura do jogo]"

2. **Para disfarçar uma convergência:**
   > "Duas escolhas da minha história convergem para a mesma cena (descrição abaixo). Sem criar um ramo novo, proponha cinco variações locais e baratas (uma fala, um objeto, uma reação) que façam cada jogadora sentir que a escolha dela foi lembrada nessa cena."

3. **Para revisar a auditoria:**
   > "Aqui está uma função que audita conversas de jogo combinatoriamente (código abaixo). Procure: caminhos que ela não simula (silêncio, saltos, escolhas condicionadas), casos em que ela marca como alcançável algo que não é (ou o contrário), e riscos de explosão de tempo. [código]"

**Cuidado específico:** pedidas para "deixar a história mais ramificada", IAs tendem a sugerir escolhas estruturais e árvores grandes, o tipo de ramificação que aparece em discussões sobre jogos de escolhas, e não o que um projeto pequeno consegue produzir. Peça sempre o **custo** junto com a ideia, e prefira as sugestões de estado com consequência tardia.

---

## Checklist

- [ ] Sei distinguir escolhas de sabor, de estado e estruturais, e o custo de cada uma.
- [ ] Sei usar ramificar e convergir, consequência tardia e variante por estado.
- [ ] Escrevi o orçamento de ramificação e o mapa da Vigília.
- [ ] Implementei atores condicionados a fatos que não "piscam" diante da jogadora.
- [ ] Implementei a auditoria combinatória e sei o que ela encontra e o que não encontra.
- [ ] As escolhas do setor 1 têm eco no próprio setor e no mapa dos setores seguintes.

---

## Para ir além

- **Emily Short** (emshort.blog): textos sobre estruturas de ramificação, *branch and bottleneck* e consequências; um dos melhores lugares para o vocabulário deste capítulo.
- **Inkle** (inklestudios.com): a documentação do Ink trata variação, estado e convergência na prática da escrita.
- **GDC Vault** (gdcvault.com): palestras de narrative design sobre o custo de escolhas e sobre jogos de escolhas episódicos (confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 48 — Environmental Storytelling](cap-48-environmental-storytelling.md)

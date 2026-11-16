# Capítulo 72 — IA para Game AI

## Objetivo

Ao final deste capítulo você deve conseguir:

- separar com precisão os papéis: **a IA generativa ajuda a construir; a Game AI decide**;
- usar IA para rascunhar e revisar **Behavior Trees** escritas como texto, sabendo os erros típicos que ela comete com a API de BT da Unreal;
- transformar uma intenção verbal ("aos 60% começa a pensar em se cobrir") em **curva de utilidade** com pontos calculados por código, e reconhecer quando a curva certa isolada é errada dentro do agregador;
- usar IA para compor e revisar **consultas EQS**, com as regras de custo e de contexto que a revisão do livro encontrou;
- escrever a intenção de design como **teste de cenários** que carrega o perfil real do vigia, com a IA propondo os casos e você decidindo os resultados esperados;
- explicar por que a Vigília **não** usa um modelo de linguagem como cérebro de um agente.

---

## Contexto

A spec do livro foi clara: estudar a relação entre IA generativa e Game AI **depois** dos fundamentos, e nunca como atalho para não aprender Game AI tradicional. A Parte V cumpriu a primeira metade: FSM, navegação, percepção, Behavior Trees, Blackboard, EQS, Utility, IA tática e de esquadrão, construídas à mão para o Vigia e para a Presença. Você sabe como é uma boa BT porque escreveu uma, sabe por que a memória de nó precisa de `InitializeMemory` porque o bug apareceu, e sabe por que o Diretor controla a **frequência** dos encontros e nunca as **regras** deles.

Este capítulo trata da segunda metade, na direção segura: a IA generativa como **ferramenta para construir** Game AI. Ela rascunha, revisa, propõe casos de teste, ajuda a transformar intenção em números. O agente que decide, a cada tick, continua sendo a BT, o Utility, o EQS e o Diretor.

A pergunta óbvia é por que não ir além: por que não deixar um modelo de linguagem **ser** o cérebro do vigia? Os Capítulos 73–75 respondem em detalhe, mas a resposta curta cabe aqui, e ela orienta tudo o que vem depois.

---

## 72.1 Duas IAs, dois papéis

| Propriedade | Game AI (BT, Utility, EQS, Diretor) | Modelo de linguagem |
|---|---|---|
| **Latência por decisão** | Microssegundos a milissegundos, dentro do frame | De centenas de milissegundos a segundos |
| **Determinismo** | Mesmo estado, mesma decisão (salvo sorteio com semente) | Mesma entrada pode dar saídas diferentes |
| **Depuração** | Ramo ativo no depurador de BT, pontuações na tela, Visual Logger | "Por que respondeu isso?" não tem resposta inspecionável |
| **Autoria** | Designer ajusta curvas, ramos, consultas e vê o efeito | Ajuste por prompt; efeito difuso e instável entre versões |
| **Custo em runtime** | CPU do jogo, orçamento do frame | Rede ou GPU, por chamada |
| **Garantias** | "O vigia sempre reage ao atordoamento" é uma propriedade da árvore | Só por validação externa |

Uma decisão de combate tomada a cada décimo de segundo, que precisa ser justa, legível e depurável, é o pior encaixe possível para um modelo de linguagem, e o melhor encaixe para Game AI. Por isso a divisão do livro é:

```text
 IA GENERATIVA ── CONSTRÓI ──►  artefatos autorados  ── usados por ──►  GAME AI ── DECIDE (em runtime)
 (no seu computador)            BT, curvas, consultas                   (dentro do jogo)
                                EQS, testes, docs
```

A regra prática que sai da tabela: **o artefato que a IA generativa produz tem de ser um que você saberia ter escrito.** Uma árvore que você consegue ler, uma curva cujos pontos você consegue conferir, uma consulta cujo custo você consegue estimar, um teste cuja expectativa você assina. Se o artefato só faz sentido "porque a IA disse", ele não entra.

---

## 72.2 Behavior Trees escritas como texto

O primeiro obstáculo é físico: **BTs são assets binários**. Nenhuma IA lê o seu `BT_Vigia.uasset`. A saída é escrever a árvore como texto, no formato indentado que o livro usou desde o Capítulo 37:

```text
 BT_Vigia (Blackboard: BB_Vigia)
  └─ SELECTOR
      ├─ [IsStaggered — abort Both]               Esperar fim do atordoamento
      ├─ [Aware AND TargetVisible — abort Both]
      │   SELECTOR "Combate"          (Service: VG Utility Select → escreve CombatIntent)
      │     ├─ [CombatIntent == TakeCover — abort Both]  EQS Cobertura → Move To → Recarregar
      │     ├─ [CombatIntent == Reload — abort Both]     Recarregar no lugar
      │     ├─ [CombatIntent == Advance — abort Both]    EQS ponto mais perto com visão → Move To
      │     ├─ [CombatIntent == Retreat — abort Both]    EQS ponto longe da jogadora → Move To
      │     └─ (Attack, padrão)  SEQUENCE (Service: VG Hold Token [Squad.Token.Attack])
      │                            Acquire Token → Telegrafar → Rajada → Pausa
      ├─ [Suspicious — abort Lower]                Investigar
      └─                                           Patrulhar
```

Esse texto é útil mesmo sem IA: é a documentação da árvore, versionada em `docs/design/ai/bt_vigia.txt`, e o diff dele mostra o que mudou entre duas versões, coisa que o asset binário não mostra. Com IA, ele permite dois workflows.

**Rascunhar a partir de um comportamento.** Você descreve o comportamento em prosa, com as **prioridades** explícitas ("atordoamento interrompe tudo; combate interrompe investigação; investigação interrompe patrulha") e as **saídas** de cada ramo ("investigar desiste depois de 20 s"). A IA devolve uma árvore em texto. Você a monta no editor, porque só você pode, e o ato de montar já é uma revisão.

**Revisar uma árvore existente.** Você cola o texto e pede uma lista dirigida. Uma revisão do `BT_Vigia` pedida assim produz achados como estes (**[HIPOTÉTICO]**, ilustrando o formato):

| Achado da IA | Como verificar | Veredito típico |
|---|---|---|
| "Investigar não tem limite de tempo: se o ponto for inalcançável, o vigia fica parado para sempre" | Ler a task de investigação; PIE com o ponto atrás de uma porta trancada | Confirmado se a task não tiver tempo-limite nem falhar quando o *Move To* falha |
| "O ramo de ataque adquire um token, mas a liberação depende do service" | Conferir `bNotifyCeaseRelevant = true` no construtor do service (Capítulo 42) | Já tratado; é a armadilha conhecida |
| "Use um *Parallel* para atirar enquanto se move" | Conferir os compostos da Unreal | A Unreal oferece Selector, Sequence e **Simple Parallel**, com semântica própria (uma task principal e uma árvore de fundo). A sugestão veio de outra biblioteca de BT |

A terceira linha mostra o erro mais comum: **semântica de outra biblioteca.** "Behavior Tree" é um conceito com muitas implementações, e a da Unreal tem particularidades: decoradores com *observer aborts* (`Self`, `Lower Priority`, `Both`), services anexados a compostos, Blackboard como memória, Simple Parallel em vez de um paralelo genérico. Uma IA que mistura implementações propõe nós que não existem ou que não se comportam como ela descreve.

Para nós escritos em C++ (tasks, services, decoradores), a revisão volta à lista do Capítulo 69. Os erros de IA mais frequentes em código de BT são exatamente as armadilhas que o livro já pagou: membros mutáveis em nós não instanciados (o mesmo objeto de nó serve a **todos** os agentes, Capítulo 37), memória de nó sem `InitializeMemory`, `OnCeaseRelevant` sem a *flag*. Peça a revisão com a lista, e teste com **vários agentes**.

---

## 72.3 Curvas de utilidade: da frase ao número

O Capítulo 40 trocou a fronteira dura "vida < 50%" por uma curva logística, e disse: o vigia passa a "pensar" em se cobrir aos 60% e quase certamente se cobre aos 35%. Essa frase é uma **especificação**. Transformá-la em pontos de uma `UCurveFloat` é um trabalho em que a IA ajuda a escolher a **forma**, e o código faz as **contas**.

A forma: uma logística decrescente na vida,

```text
 u(x) = 1 / (1 + e^(k · (x − x0)))       x = HealthRatio (0..1), u = vontade de se cobrir (0..1)
```

com o ponto médio `x0` entre os dois marcos e a inclinação `k` escolhida para que `u(0,60) = 0,1` e `u(0,35) = 0,9`. Resolvendo: `x0 = 0,475` e `k = ln(9) / 0,125 ≈ 17,6`. Os pontos-chave para a curva:

| HealthRatio | 0,00 | 0,20 | 0,35 | 0,475 | 0,60 | 0,80 | 1,00 |
|---|---|---|---|---|---|---|---|
| u | 1,00 | 0,99 | 0,90 | 0,50 | 0,10 | 0,003 | 0,0001 |

Essa tabela foi calculada, não estimada, e é assim que deve chegar ao seu projeto: a IA pode propor a fórmula e o critério, e uma planilha ou três linhas de código produzem os números. O Capítulo 70 explicou por quê: modelos de linguagem erram aritmética com a mesma fluência com que acertam.

Agora o ponto que nenhuma conversa genérica sobre curvas pega. No agregador do Capítulo 40 (produto compensado), **qualquer consideração perto de zero veta a ação**. Com vida cheia, a curva acima dá 0,0001: o vigia **nunca** se cobre quando está inteiro, mesmo sob supressão pesada. Talvez seja o que você quer; talvez não. Se não for, a curva precisa de um **piso** (por exemplo, `0,05 + 0,95 · u`), e essa decisão depende do agregador, que a IA não conhece a menos que você o mostre. Uma curva certa isolada pode ser errada dentro do sistema.

> 🌉 **Ponte:** é *feature engineering* com função de transformação: normalizar a entrada e moldar a resposta. Você já fez isso com *scores* de risco ou de relevância.
>
> 🧱 **Onde a ponte cai:** num modelo de *score*, a curva é ajustada por dados. Aqui, ela é ajustada por **intenção de design** e pelo que a jogadora percebe: um vigia que se cobre "cedo demais" parece covarde, "tarde demais" parece burro, e nenhum conjunto de dados diz qual dos dois você quer.

---

## 72.4 Consultas EQS

Uma consulta EQS (Capítulo 39) tem três partes: um **gerador** de pontos candidatos, **testes** que filtram ou pontuam, e a **pontuação** final. É um artefato bom para rascunhar com IA, porque a composição é declarativa e cabe em texto:

```text
 EQS_CoberturaVigia
   Gerador:  Pathing Grid em volta do vigia (raio 15 m, espaço 1,5 m)
   Testes:
     1. Trace até VGTarget (visibilidade)   → FILTRO: só pontos SEM linha de visão
     2. Distância até VGTarget              → PONTUAÇÃO: preferir 8–15 m
     3. Distância até o vigia               → PONTUAÇÃO: preferir perto
     4. Pathfinding até o ponto             → FILTRO: alcançável
```

A revisão de uma consulta tem três perguntas fixas, e duas delas vieram da revisão do livro:

- **Ordem e custo.** O EQS ordena os testes pelo **custo** declarado de cada tipo de teste, e não pela ordem em que o autor os listou (revisão de 2026-11-03, Capítulo 39). Uma IA que "otimiza" a consulta reordenando os testes no texto está otimizando algo que a engine reordena de qualquer forma. A pergunta útil é outra: algum teste caro (trace, pathfinding) roda sobre pontos demais? Dá para filtrar antes com um teste barato?
- **Contexto adequado ao teste.** O teste de produto escalar (*Dot*) precisa de uma **rotação**; um contexto que fornece só um ponto não serve a ele (também da revisão, Capítulo 39). IAs propõem *Dot* com contextos de posição com frequência.
- **Filtro ou pontuação.** Filtrar elimina candidatos; pontuar ordena. Uma consulta só com filtros pode voltar vazia; uma só com pontuações pode escolher um ponto absurdo, se ele for o "menos ruim". Peça à IA que diga, para cada teste, o que acontece se **nenhum** ponto passar.

A verificação é sempre na engine: o **EQS Testing Pawn** (um ator que você coloca no nível para ver os pontos e as pontuações da consulta no editor) e a categoria de EQS do **Gameplay Debugger**. A IA não roda consultas; você roda.

---

## 72.5 A intenção de design como teste

Os três artefatos anteriores (árvore, curva, consulta) se combinam numa decisão, e a decisão é o que a jogadora vê. A forma mais robusta de garantir que a combinação faz o que o design quer é escrever a intenção como **cenários executáveis**:

```text
 "Vigia inteiro, alvo à vista, com token de ataque"            → ataca
 "Ferido (30%) e acabou de levar tiro, com cobertura perto"   → cobre-se
 "Pente quase vazio, sem dano recente"                         → recarrega
 "Sem token de ataque"                                         → NÃO ataca
 "Ferido, mas sem cobertura por perto"                         → NÃO tenta se cobrir
```

Cada linha é uma frase de design que você assinaria, e cada uma vira um caso de teste. A divisão de trabalho com a IA:

- **A IA propõe cenários**, em especial os de borda que você não pensaria: vida exatamente no ponto médio da curva; sem munição **e** sem cobertura; alvo visível mas muito longe; tudo zero (que ação sobra?). Esse é o pedido em que ela mais ajuda.
- **Você decide o esperado.** "Sem munição e sem cobertura" deve dar recuo? Avanço suicida? Isso é design. Se a IA escrever o esperado olhando as curvas atuais, o teste confirma o comportamento atual, certo ou errado (Capítulo 69).
- **O teste carrega o perfil real.** As curvas são ajustadas no editor por quem joga. O teste não pode ter uma cópia própria delas, ou ele testa um vigia que não existe. Isso exige uma pequena refatoração, mostrada a seguir.

---

## Estudos de caso

### F.E.A.R. — inteligência a partir de peças pequenas

**[FATO PÚBLICO — confira o título no GDC Vault]** Jeff Orkin, da Monolith, apresentou na GDC de 2006 a IA de *F.E.A.R.* (2005), numa palestra conhecida como *Three States and a Plan: The A.I. of F.E.A.R.*. A máquina de estados dos inimigos tinha apenas três estados (ir até um lugar, tocar uma animação, usar um objeto do cenário), e um **planejador** orientado a objetivos (GOAP, Capítulo 41) encadeava **ações** pequenas, cada uma com pré-condições e efeitos, para atingir o objetivo de maior prioridade. Os soldados também **anunciavam** o que faziam em voz alta, o que ajudava o jogador a perceber a coordenação.

**[INFERÊNCIA]** A impressão de inteligência tática vinha da **combinação** de peças autorais pequenas, legíveis e testáveis isoladamente, e não de um comportamento monolítico. Uma ação nova era um dado novo, com pré-condições e efeitos, e o planejador a encaixava onde servia.

**Lição para a Vigília:** é o formato certo para o que uma IA generativa ajuda a produzir: **peças pequenas** (uma consideração com curva, uma consulta, um cenário de teste, uma task) que você revisa uma a uma. Um "gere a IA inteira do vigia" produz um artefato grande demais para revisar e sem as costuras que tornam a depuração possível. E repare nos anúncios dos soldados: a **fala vem depois da decisão** e serve para torná-la legível. O Capítulo 74 constrói o NPC híbrido sobre essa mesma ordem.

### Black & White — quando o comportamento é aprendido

**[FATO PÚBLICO — observável jogando]** Em *Black & White* (Lionhead Studios, 2001), a jogadora cria uma criatura que **aprende** com ela: carinho reforça um comportamento, um tapa o desestimula, e a criatura também imita o que observa. Duas partidas produzem criaturas com hábitos muito diferentes.

**[INFERÊNCIA]** O comportamento aprendido dá autoria à **jogadora**, e é essa a graça do jogo. O preço é tirar parte do controle do **designer**: fica difícil garantir que a criatura nunca aprenda algo que quebre o ritmo, e responder "por que ela fez isso?" exige reconstruir uma história de recompensas, não ler uma árvore.

**Lição para a Vigília:** num jogo de terror de 15 minutos, com ritmo autoral e uma ameaça que precisa ser **justa** (telegrafia, percepção legível, Capítulos 21 e 36), o controle do designer vale mais que a surpresa. Comportamento gerado ou aprendido fica na pista das **ferramentas**; a decisão em runtime fica autoral.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| BT como texto versionado | Diagrama como código (*diagrams as code*) | O texto é documentação; a fonte da verdade continua sendo o asset binário |
| Curva a partir de intenção | *Feature engineering* com transformação | O ajuste é por intenção e percepção, não por dados |
| Revisão de consulta EQS | Revisão de plano de consulta SQL (custo, filtros, índices) | A engine reordena os testes por custo; a ordem do autor não é o plano |
| Cenários executáveis | BDD (*given/when/then*), testes de aceitação | O "então" é uma decisão de design que muda com o playtest |
| Perfil carregado pelo teste | Teste contra a configuração real, não contra *mocks* | O dado é ajustado por quem joga, no editor; o teste protege a intenção contra o ajuste |

---

## Unreal Engine: o que ajuda a verificar

- **Depurador de Behavior Tree**: o ramo ativo e os valores do Blackboard durante o PIE.
- **Gameplay Debugger**, com categorias de IA, BT, EQS e percepção, e o **Visual Logger** para reconstruir uma decisão depois do fato (Capítulo 61).
- **EQS Testing Pawn**, para ver pontos e pontuações de uma consulta no editor.
- **Framework de automação** para regras puras (`VGUtility`), e testes funcionais em nível (*Functional Testing*) para comportamentos que precisam de mundo. ⚠️ Confira na documentação da sua versão como montar um teste funcional; ele é o próximo degrau depois dos cenários deste capítulo.

O que não existe: um formato de texto oficial para BTs e consultas EQS (o texto deste capítulo é convenção do projeto), e qualquer integração de IA generativa com esses editores que este livro possa tratar como estável. Confira o estado atual na documentação da sua versão.

---

## Abordagens

| Critério | A. IA gera o artefato final | B. IA rascunha em texto, você monta | **C. Você monta, IA revisa e gera testes** |
|---|---|---|---|
| **Complexidade** | Baixa no começo, alta para depurar | Média | Média |
| **Performance** (velocidade) | Alta | Média | Média |
| **Extensibilidade** | Ruim: peças grandes e sem costura | Boa: o texto é a especificação | Boa: cada peça ganha um teste |
| **Manutenção** | Ruim: ninguém sabe por que a árvore é assim | Boa | **Boa**: a intenção está nos cenários |
| **Prototipação** | Rápida | Rápida | Média |
| **Adequação à Vigília** | Não: assets binários, armadilhas de API, autoria perdida | **Sim**, para peças novas | **Sim**, para tudo que já existe |

**Decisão:** **B** quando a peça é nova (uma árvore, uma consulta, um conjunto de curvas), **C** para tudo que já existe e para toda mudança. **A** está fora por motivo físico (a IA não produz assets da Unreal) e por motivo de design (a decisão autoral é o que torna a ameaça justa e depurável).

---

## Implementação

### 1. 🔁 O perfil de utilidade sai do nó

**O que havia:** no Capítulo 40, as intenções do vigia (`FVGUtilityAction`, com considerações e curvas) eram configuradas **no nó** `VG Utility Select`, dentro do `BT_Vigia`.

**O problema:** agora há dois leitores do mesmo dado, o service (em runtime) e o teste de cenários. O teste não consegue chegar ao nó de dentro de um asset de BT sem carregar e percorrer a árvore. O desafio do Capítulo 40 já tinha perguntado onde as curvas deveriam viver, e sugerido um Data Asset por arquétipo.

**A solução:** um Data Asset com as ações, lido pelos dois.

```cpp
// Source/Vigilia/AI/Utility/VGUtilityProfile.h
#pragma once

#include "CoreMinimal.h"
#include "AI/Utility/VGUtilityTypes.h"
#include "Engine/DataAsset.h"
#include "VGUtilityProfile.generated.h"

/** As intenções de um arquétipo (DA_Utility_Vigia). Lido pelo service E pelo teste de cenários. */
UCLASS(BlueprintType)
class VIGILIA_API UVGUtilityProfile : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Utility")
    TArray<FVGUtilityAction> Actions;
};
```

```cpp
// Source/Vigilia/AI/BT/BTService_VGUtilitySelect.h (🔁 trecho alterado)
// Antes: UPROPERTY(EditAnywhere, Category = "Utility") TArray<FVGUtilityAction> Actions;
UPROPERTY(EditAnywhere, Category = "Utility")
TObjectPtr<const UVGUtilityProfile> Profile;
```

No `TickNode`, onde o service chamava `VGUtility::SelectBest(Actions, …)`, ele passa a sair cedo se não houver perfil e a chamar `VGUtility::SelectBest(Profile->Actions, …)`. Crie o `DA_Utility_Vigia` copiando as ações que estavam no nó (o editor permite copiar o array inteiro de uma propriedade e colar em outra) e aponte o service para ele.

**Os *trade-offs*:** um asset a mais, e uma indireção para quem ajusta curvas (abre o Data Asset em vez do nó). Em troca, o arquétipo vira dado reutilizável (o "veterano" e o "recruta" do desafio do Capítulo 40 passam a ser dois assets) e testável. **O que se aprendeu:** configurar no nó era a solução mais simples enquanto havia um leitor só. O segundo leitor é o sinal para extrair, o mesmo critério do "terceiro caso" que o livro usa desde o Capítulo 6, aqui disparado mais cedo porque um dos leitores é um teste.

### 2. O teste de cenários

```cpp
// Source/Vigilia/Tests/VGUtilityScenarioTest.cpp
#include "Misc/AutomationTest.h"
#include "AI/Utility/VGUtilityProfile.h"
#include "AI/Utility/VGUtilityTypes.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace
{
    struct FVGInput
    {
        EVGUtilityInput Input;
        float Value;
    };

    /** Uma intenção de design escrita como dado: "nesta situação, o vigia faz (ou NÃO faz) isto". */
    struct FVGScenario
    {
        const TCHAR* Name;
        TArray<FVGInput> Overrides;  // só o que define a situação; o resto vem da linha de base
        FName Intent;
        bool bForbidden = false;     // true: a melhor intenção NÃO pode ser esta
    };

    /** Combate "morno": tudo em ordem, nada urgente. Cada cenário muda só o que o define. */
    FVGUtilityContext Baseline()
    {
        FVGUtilityContext Context; // entradas não citadas (aliados, supressão, flanco) começam em 0
        Context.Set(EVGUtilityInput::HealthRatio, 1.0f);
        Context.Set(EVGUtilityInput::AmmoRatio, 1.0f);
        Context.Set(EVGUtilityInput::TargetDistance, 0.4f);
        Context.Set(EVGUtilityInput::TimeSinceDamaged, 1.0f);
        Context.Set(EVGUtilityInput::TargetVisible, 1.0f);
        Context.Set(EVGUtilityInput::HasCoverNearby, 1.0f);
        Context.Set(EVGUtilityInput::LastKnownRecency, 1.0f);
        Context.Set(EVGUtilityInput::TokenAvailable, 1.0f);
        return Context;
    }

    FString DescribeScores(const TArray<FVGUtilityAction>& Actions, const TArray<float>& Scores)
    {
        FString Out;
        for (int32 i = 0; i < Actions.Num() && i < Scores.Num(); ++i)
        {
            Out += FString::Printf(TEXT("%s=%.2f "), *Actions[i].Intent.ToString(), Scores[i]);
        }
        return Out;
    }
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGUtilityScenarioTest, "Vigilia.AI.Utility.Scenarios",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGUtilityScenarioTest::RunTest(const FString& Parameters)
{
    // O perfil REAL: se alguém ajustar uma curva no editor e trair a intenção, este teste falha.
    const UVGUtilityProfile* Profile = LoadObject<UVGUtilityProfile>(
        nullptr, TEXT("/Game/Vigilia/Data/AI/DA_Utility_Vigia.DA_Utility_Vigia"));
    if (!TestNotNull(TEXT("DA_Utility_Vigia carregado"), Profile))
    {
        return false;
    }

    const TArray<FVGScenario> Scenarios = {
        { TEXT("Inteiro, alvo à vista, com token: ataca"), {}, TEXT("Attack") },
        { TEXT("Ferido e acabou de levar tiro, com cobertura: cobre-se"),
          { { EVGUtilityInput::HealthRatio, 0.3f }, { EVGUtilityInput::TimeSinceDamaged, 0.05f } },
          TEXT("TakeCover") },
        { TEXT("Pente quase vazio, sem dano recente: recarrega"),
          { { EVGUtilityInput::AmmoRatio, 0.05f } }, TEXT("Reload") },
        { TEXT("Sem token de ataque: não ataca"),
          { { EVGUtilityInput::TokenAvailable, 0.0f } }, TEXT("Attack"), /*bForbidden*/ true },
        { TEXT("Ferido, mas sem cobertura por perto: não tenta se cobrir"),
          { { EVGUtilityInput::HealthRatio, 0.3f }, { EVGUtilityInput::HasCoverNearby, 0.0f } },
          TEXT("TakeCover"), /*bForbidden*/ true },
    };

    for (const FVGScenario& Scenario : Scenarios)
    {
        FVGUtilityContext Context = Baseline();
        for (const FVGInput& Override : Scenario.Overrides)
        {
            Context.Set(Override.Input, Override.Value);
        }

        TArray<float> Scores;
        const int32 Best = VGUtility::SelectBest(Profile->Actions, Context, INDEX_NONE, 0.0f, &Scores);
        const FName Chosen = Profile->Actions.IsValidIndex(Best) ? Profile->Actions[Best].Intent : NAME_None;
        const bool bPass = Scenario.bForbidden ? Chosen != Scenario.Intent : Chosen == Scenario.Intent;
        TestTrue(FString::Printf(TEXT("%s | escolheu %s | %s"), Scenario.Name, *Chosen.ToString(),
                                 *DescribeScores(Profile->Actions, Scores)), bPass);
    }
    return true;
}

#endif
```

### Explicação das decisões

- **O teste carrega o asset real** (`LoadObject` com o caminho do Data Asset). É um teste que depende de conteúdo, e por isso roda em `EditorContext`. É exatamente o que se quer: ele falha quando um ajuste de curva no editor trai a intenção. Ajuste o caminho ao seu projeto.
- **Linha de base + sobrescritas.** Cada cenário declara só o que o define. Ler "pente quase vazio → recarrega" no código é ler a frase de design.
- **Cenários proibitivos** (`bForbidden`). Muitas intenções de design são negativas ("sem token, **não** ataca") e não dizem o que o agente faz no lugar. O teste respeita isso, em vez de forçar uma resposta que o design não decidiu.
- **Mensagem que explica a falha.** Quando um cenário falha, a mensagem traz a intenção escolhida e **todas** as pontuações. Quem lê o relatório sabe se o problema é uma curva, um peso ou o próprio cenário.
- **Sem inércia** (`CurrentIndex = INDEX_NONE`, bônus 0). Os cenários testam a decisão "a frio". A inércia (Capítulo 40) é outra propriedade, e merece um cenário próprio se você quiser fixá-la.
- **Um teste por sistema**, como manda a convenção: este é o teste de **intenção** do Utility. Os testes de regra do Capítulo 40 continuam testando o agregador.

---

## Projeto Vigília — a IA da Vigília revisada com IA

O que muda no repositório e no conteúdo:

```text
docs/design/ai/
├── bt_vigia.txt        a árvore em texto (fonte: o asset; atualize junto)
├── bt_presenca.txt
├── curvas.md           cada curva: frase de design → fórmula → pontos calculados → piso, se houver
└── eqs.md              cada consulta: gerador, testes (filtro/pontuação), o que acontece se nada passar
Content: /Game/Vigilia/Data/AI/DA_Utility_Vigia   (🔁 ações saem do nó)
Source:  AI/Utility/VGUtilityProfile.h · Tests/VGUtilityScenarioTest.cpp
```

O roteiro do capítulo, aplicado ao projeto:

1. **Escreva as duas árvores em texto** e peça uma revisão dirigida de cada uma (prioridades, saídas, tokens, nós que talvez não existam na Unreal). Verifique cada achado no editor ou no PIE e registre o veredito.
2. **Documente cada curva** do `DA_Utility_Vigia` em `curvas.md` com a frase de design que a justifica. Curvas sem frase são candidatas a revisão: alguém as ajustou "até parecer bom", e ninguém sabe o que elas querem dizer.
3. **Revise as consultas EQS** com as três perguntas fixas da seção 72.4, usando o EQS Testing Pawn.
4. **Faça a refatoração do perfil** e escreva o teste com os cinco cenários. Depois peça à IA dez cenários de borda e **escolha** quais entram, decidindo o esperado de cada um.

E a **Presença**? Ela não usa Utility; usa BT, percepção, EQS e o Diretor. A revisão em texto da `BT_Presenca` tem uma pergunta específica que vale fazer: "existe algum caminho em que a Presença ataca **sem** telegrafar?". O documento de combate do Capítulo 21 diz "nenhum ataque sem telegrafia", e essa é uma garantia que precisa estar na **estrutura** da árvore (a task de ataque só alcançável depois da de telegrafia), não na boa vontade de quem ajusta o nível.

---

## Decisões arquiteturais

1. **IA generativa constrói, Game AI decide.** Nenhum modelo de linguagem participa de decisões de agentes em runtime na Vigília.
2. **Todo artefato gerado tem de ser um que você saberia ter escrito**: legível, verificável, pequeno.
3. **BTs e consultas EQS têm uma versão em texto em `docs/design/ai/`**, que serve de documentação, de diff e de entrada para revisão.
4. **Curvas nascem de frases de design**, com pontos calculados por código e piso decidido conforme o agregador.
5. **A intenção de design é um teste de cenários** que carrega o perfil real do arquétipo.
6. 🔁 **O perfil de utilidade é um Data Asset por arquétipo** (`UVGUtilityProfile`), lido pelo service e pelo teste.

---

## Armadilhas

- **Pedir "a IA do inimigo inteira".** O resultado é grande demais para revisar e não tem as costuras que permitem depurar.
- **Aceitar nós de outra biblioteca de BT.** A Unreal tem Selector, Sequence e Simple Parallel, decoradores com *observer aborts* e services; o resto é invenção ou outra engine.
- **Membros mutáveis em nós não instanciados**, sugeridos com frequência por IA. Um nó serve a todos os agentes.
- **Curvas com pontos estimados de cabeça.** Calcule.
- **Curva certa, sistema errado.** Um valor próximo de zero é veto no produto compensado; decida o piso olhando o agregador.
- **"Otimizar" uma consulta EQS reordenando testes no texto.** A engine ordena por custo.
- **Teste com cópia das curvas.** Ele testa um vigia que não existe; carregue o perfil real.
- **Deixar a IA escrever os resultados esperados** a partir das curvas atuais. O teste vira fotografia do comportamento, com os bugs incluídos.
- **Garantias de design na boa vontade.** "Nenhum ataque sem telegrafia" tem de estar na estrutura da árvore.

---

## Exercício

**Parte 1 — árvores em texto (1 h).** Escreva `bt_vigia.txt` e `bt_presenca.txt` a partir dos assets atuais. Peça uma revisão dirigida de cada uma (prioridades, saídas sem fim, tokens, nós que não existem na Unreal, ataque sem telegrafia). Verifique cada achado e registre: confirmado, falso, já tratado.

**Parte 2 — uma curva do zero (45 min).** Escolha uma consideração do vigia que ainda use uma curva ajustada "no olho". Escreva a frase de design, peça à IA a forma e o critério, calcule os pontos com uma planilha ou um programa e decida o piso olhando o agregador. Documente em `curvas.md`.

**Parte 3 — o perfil e o teste (1,5 h).** Faça a refatoração do `UVGUtilityProfile`, crie o `DA_Utility_Vigia` e implemente o teste com os cinco cenários. Rode-o com o `run-tests.ps1` do Capítulo 69. Depois quebre uma curva de propósito no editor e confirme que a mensagem de falha diz o que mudou.

**Parte 4 — cenários de borda (45 min).** Peça dez cenários de borda à IA, sem resultados esperados. Escolha quatro, decida o esperado de cada um e acrescente ao teste. Para os que você não soube decidir, registre a pergunta em `docs/design/ideias.md` como pergunta de playtest.

---

## Desafio — o cenário absurdo

Peça a uma IA, com o `DA_Utility_Vigia` descrito em texto (ações, considerações, curvas com pontos, agregador), que encontre **um contexto plausível em que o vigia escolhe algo absurdo**: avançar sem munição contra a jogadora coberta, recarregar com ela a dois metros, recuar inteiro e com token. Depois:

1. Transforme o contexto apontado num cenário de teste e **prove** (ou refute) o absurdo rodando o teste.
2. Se for real, corrija mudando **dados** (curva, piso, peso), não código.
3. Rode todos os cenários de novo: a correção quebrou algum?
4. Registre no `DEVLOG.md` quantas sugestões da IA eram absurdos reais e quantas eram leituras erradas do agregador.

---

## Uso de IA

Prompts meta, para avaliar o seu uso de IA na construção de Game AI:

1. **Para saber se você ainda sabe:**
   > "Descrevi abaixo, sem consulta, como a BT_Vigia decide entre investigar e combater, e o que acontece quando o vigia perde a jogadora de vista no meio de uma rajada. Compare com a árvore em texto e aponte cada ponto em que a minha descrição diverge da estrutura. [minha descrição] [bt_vigia.txt]"

2. **Para medir quanto da IA do jogo você entende:**
   > "Aqui estão as curvas do DA_Utility_Vigia com as frases de design. Escolha três curvas e me pergunte o que acontece com o comportamento se cada uma for deslocada 0,1 para a direita. Eu respondo; depois você calcula com a fórmula e me diz onde errei."

3. **Para revisar com a lista da casa:**
   > "Revise esta task de Behavior Tree em C++ procurando especificamente: membro mutável em nó não instanciado, memória de nó sem InitializeMemory/CleanupMemory, OnBecomeRelevant/OnCeaseRelevant sem as flags, recurso adquirido sem liberação garantida, e uso de API que não exista no UE 5.[versão]. Para cada item: presente, ausente ou não sei. [código]"

4. **Para checar se a IA virou atalho:**
   > "Liste as decisões de IA do jogo que eu tomei nas últimas semanas (DEVLOG abaixo) e marque quais foram tomadas por mim com um motivo de design escrito, e quais foram aceitas de uma sugestão sem motivo registrado."

**Cuidado específico:** pedida para "melhorar a IA do inimigo", uma IA generativa tende a acrescentar comportamentos (flanquear, pedir reforço, usar granadas), porque é isso que os textos sobre IA de FPS descrevem. A Vigília tem dois vigias num trecho único e uma ameaça que precisa ser legível. Peça **cortes** e **garantias**, não comportamentos novos.

---

## Checklist

- [ ] Sei explicar, com a tabela da seção 72.1, por que um modelo de linguagem não decide pelo vigia.
- [ ] Tenho as BTs da Vigília em texto e sei pedir uma revisão dirigida.
- [ ] Sei reconhecer nós e semânticas de outras bibliotecas de BT.
- [ ] Sei transformar uma frase de design em curva, com pontos calculados e piso decidido pelo agregador.
- [ ] Sei as três perguntas fixas da revisão de uma consulta EQS.
- [ ] Fiz a refatoração do `UVGUtilityProfile` e o teste de cenários passa contra o perfil real.
- [ ] Sei por que o resultado esperado de um cenário é decisão minha.

---

## Para ir além

- **Steve Rabin (org.), *Game AI Pro*** (série; vários capítulos disponíveis gratuitamente em gameaipro.com): capítulos sobre Behavior Trees, utilidade, consultas espaciais e depuração de IA, escritos por quem os usou em produção.
- **Dave Mark, *Behavioral Mathematics for Game AI*.** A referência para curvas de resposta e utilidade; útil para escolher a forma antes de calcular os pontos.
- **GDC Vault** (gdcvault.com): a palestra de Jeff Orkin sobre a IA de *F.E.A.R.* (GDC 2006; confira o título lá) e as palestras de utilidade de Dave Mark e Kevin Dill citadas no Capítulo 40.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Behavior Trees**, **Environment Query System** (incluindo o EQS Testing Pawn), **Gameplay Debugger** e **Visual Logger**.

---

➡️ **Próximo:** [Capítulo 73 — LLMs dentro de jogos](cap-73-llms-dentro-de-jogos.md)

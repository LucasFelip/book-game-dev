# Capítulo 39 — EQS

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o **Environment Query System** (EQS) como uma forma de responder "**qual é o melhor lugar para...?**" com geradores, testes, contextos e pontuação;
- escolher **geradores** e **testes** adequados, distinguindo **filtro** de **pontuação**, e ordenar testes pelo custo;
- escrever **contextos** e **testes customizados** em C++;
- integrar consultas à **Behavior Tree**, gravando o resultado no Blackboard;
- usar EQS para os problemas espaciais da Vigília: **cobertura** do vigia, **espreita**, **recuo** e **busca** da Presença;
- depurar consultas com o **EQS Testing Pawn** e o Gameplay Debugger.

---

## Contexto

As Behavior Trees do Capítulo 37 têm tarefas que escolhem lugares — `VG Find Cover`, `VG Find Stalk Point` — implementadas de forma ingênua: o ponto com tag mais próximo, um ponto aleatório alcançável. Funcionam, e são exatamente onde a IA **parece burra**: o vigia escolhe uma "cobertura" que não o protege da jogadora; a Presença espreita num ponto à vista, ou longe demais da última posição conhecida para ser ameaçadora.

Quase toda decisão tática de um agente de jogo termina numa pergunta **espacial**: onde me esconder, onde flanquear, de onde atirar, onde procurar, para onde fugir. O EQS é a ferramenta da Unreal para essas perguntas — e, para você, a analogia mais útil é uma **consulta**: gere candidatos, filtre, pontue, escolha.

---

## 39.1 Anatomia de uma consulta

```text
 CONSULTA EQS: "melhor ponto de cobertura"

 1. GERADOR          cria ITENS candidatos (pontos ou atores)
    ex.: anel de pontos entre 3 e 10 m do vigia, sobre a NavMesh
                │
 2. TESTES          cada teste FILTRA (descarta) e/ou PONTUA (0..1) os itens
    a. Pathfinding   existe caminho até o ponto?                  → filtro
    b. Trace         a linha da JOGADORA até o ponto é bloqueada?  → filtro (é cobertura)
    c. Distance      distância até o vigia (mais perto é melhor)   → pontuação
    d. Distance      distância até a jogadora (6–15 m é o ideal)   → pontuação
                │
 3. RESULTADO       soma ponderada das pontuações; escolhe o melhor
    (ou um aleatório entre os melhores 5% / 25%)
```

### Contextos

Testes e geradores precisam de **referências**: "distância **até quem**?", "trace **a partir de quem**?". Essas referências são **contextos**: o próprio agente (*Querier*), o item sendo testado (*Item*), ou contextos customizados — a jogadora, a última posição conhecida, a origem da luz que atordoou a Presença.

### Filtro e pontuação

Cada teste tem um **propósito**: só filtrar, só pontuar, ou ambos.

- **Filtro** responde sim/não ("há caminho?", "está coberto?"). Itens reprovados são descartados.
- **Pontuação** responde "quão bom?" num valor normalizado entre 0 e 1, com uma **equação** (linear, inversa, quadrática, constante) e limites. Pontuações de testes diferentes são somadas com **pesos**.

O modo de execução decide o resultado: **o melhor item**, **um aleatório entre os melhores 5% ou 25%** (variedade sem perder qualidade — a mesma ideia do spawn do Capítulo 32), ou **todos** os aprovados.

> 🌉 **Ponte:** uma consulta EQS é literalmente um `SELECT`:
> ```sql
> SELECT ponto FROM anel(3m, 10m, ao_redor_de=vigia)          -- gerador
> WHERE  existe_caminho(vigia, ponto)                        -- filtro
>   AND  bloqueado(trace(jogadora, ponto))                   -- filtro
> ORDER BY 0.6 * perto(vigia) + 0.4 * faixa(jogadora, 6m, 15m) DESC  -- pontuação
> LIMIT 1;                                                   -- modo de execução
> ```
> E, como num banco, a **ordem dos filtros importa para o custo**: filtros baratos e seletivos primeiro — e, como num banco, quem ordena é o "otimizador" (seção 39.2), a partir do custo que cada teste declara.
>
> 🧱 **Onde a ponte cai:** a "tabela" é gerada a cada consulta a partir da geometria, e os "predicados" envolvem traces e pathfinding — operações caras que o EQS **fatia ao longo de vários frames**. O resultado chega com atraso e pode estar desatualizado quando a jogadora já se moveu.

---

## 39.2 Geradores e testes mais usados

| Gerador | Produz | Uso típico |
|---|---|---|
| **Simple Grid** | Grade de pontos ao redor de um contexto | Busca genérica em área |
| **Points: Circle / Donut** | Pontos num círculo ou anel | Cobertura, posições ao redor do alvo |
| **Pathing Grid** | Grade **sobre a NavMesh**, só pontos alcançáveis (com filtro de navegação) | Qualquer ponto aonde o agente precisa ir |
| **Actors Of Class** | Atores de uma classe num raio | Escolher entre objetos (pontos de cobertura autorados, Smart Objects) |
| **Current Location** | Um ponto: o próprio contexto | Testes sobre o próprio agente |

| Teste | Mede | Custo |
|---|---|---|
| **Distance** | Distância item ↔ contexto | Baixo |
| **Dot** | Alinhamento entre direções (ex.: "o ponto está à frente da jogadora?") | Baixo |
| **Gameplay Tags** | Tags do item (para atores) | Baixo |
| **Overlap** | Há algo ocupando o ponto? | Médio |
| **Trace** | Linha de visão entre contexto e item | **Alto** |
| **Pathfinding** | Existe caminho / comprimento do caminho | **Alto** |
| **Project** | Projeta o ponto na NavMesh | Médio |

**Regra de custo:** testes baratos que **filtram muito** primeiro; traces e pathfinding por último, sobre o menor número possível de itens. Você não garante isso arrastando testes no editor: o EQS **reordena os testes sozinho** antes de executar — pelo `Cost` que cada um declara (Low → Medium → High) e, no mesmo custo, filtros antes de testes só de pontuação; a ordem do asset só desempata — e pula itens já descartados. (Confira o critério exato na sua versão: `EnvQueryManager.cpp`, `EnvQueryTestSort`.) Seu trabalho é **declarar o custo honestamente** nos testes customizados e escolher bem o propósito (filtro, pontuação ou ambos) de cada teste.

---

## 39.3 As perguntas espaciais da Vigília

### Vigia: onde me cobrir?

```text
 GERADOR  Donut ao redor do Querier (vigia), raio 3–10 m, sobre a NavMesh
 TESTES
   1. Distance (Item → Querier)              filtro: ≤ 10 m; pontuação: inversa (perto é melhor), peso 0,6
   2. Distance (Item → Target)               pontuação: melhor na faixa 6–15 m, peso 0,4
   3. Trace (Target → Item, altura do peito) filtro: deve BLOQUEAR (é cobertura)
   4. Pathfinding (Querier → Item)           filtro: deve existir caminho
 MODO     melhor item
```

O teste 3 é o coração: **um ponto é cobertura em relação a alguém**. O mesmo canto pode cobrir de uma direção e expor de outra — por isso a consulta é refeita quando a jogadora se move muito (um *service* reexecuta a consulta periodicamente enquanto o vigia está no ramo de cobertura).

### Presença: onde espreitar?

A pergunta de design: um ponto **no escuro**, **fora da visão da jogadora**, **mais perto** da última posição conhecida do que o ponto atual — mas não perto demais (espreitar não é atacar).

```text
 GERADOR  Pathing Grid ao redor do Querier, 15 m, com o FILTRO DE NAVEGAÇÃO DA PRESENÇA
          → só pontos no escuro, sem atravessar portas fechadas (Cap. 35)
 TESTES
   1. Distance (Item → LastKnownLocation)    pontuação: melhor entre 8 e 14 m, peso 0,5
   2. Dot (rotação da jogadora · direção jogadora → Item)  pontuação: atrás/ao lado é melhor, peso 0,3
   3. Trace (olhos da jogadora → Item)       filtro: deve BLOQUEAR (fora de vista)
   (contexto da jogadora: VGPlayerView — um ATOR, porque o Dot precisa da rotação dela)
 MODO     aleatório entre os melhores 25%
```

Repare que **"no escuro" não é um teste**: o gerador já usa o filtro de navegação da Presença, que exclui áreas iluminadas. A regra de design continua morando num só lugar — o mapa de navegação.

E o modo aleatório entre os melhores evita o efeito "ela sempre vem pelo mesmo canto", que destrói a tensão depois da segunda vez.

### Presença: para onde recuar?

```text
 GERADOR  Pathing Grid ao redor do Querier, 12 m (filtro da Presença)
 TESTES
   1. Distance (Item → RetreatOrigin = a luz que a atingiu)   pontuação: longe é melhor
   2. Pathfinding (Querier → Item)                            filtro + pontuação: caminho curto
 MODO     melhor item
```

### Presença: onde procurar?

Quando a consciência ainda está alta mas a jogadora sumiu, onde uma criatura "inteligente" procuraria? Nos lugares **onde ela poderia ter se escondido**: pontos perto da última posição conhecida que **não são visíveis** de lá.

```text
 GERADOR  Pathing Grid ao redor de LastKnownLocation, 10 m
 TESTES
   1. Trace (LastKnownLocation → Item)   pontuação: bloqueado é melhor (esconderijo)
   2. Distance (Item → LastKnownLocation) pontuação: perto é melhor
 MODO     aleatório entre os melhores 25%   (a Presença procura em 2–3 desses pontos)
```

Este é o comportamento que o estudo de caso de Outlast (Capítulo 33) pedia: **procurar de um jeito plausível e falível** — os esconderijos óbvios, não o esconderijo certo.

---

## 39.4 Integração com a Behavior Tree

A Behavior Tree executa consultas com a tarefa **Run EQS Query**, que grava o resultado numa chave do Blackboard (um `Vector` para pontos, um `Object` para atores). Se a consulta não encontrar nenhum item, a tarefa **falha** — e a árvore reage (a sequence falha, o selector tenta o próximo ramo). Uma consulta sem resultado é informação útil: "não há cobertura aqui" → o vigia continua atirando.

🔁 **Refatoração do Capítulo 37:**

```text
 BT_Vigia, ramo de cobertura:
   antes:  VG Find Cover (ingênuo) → Move To (CoverLocation) → ...
   depois: Run EQS Query (EQS_CoberturaVigia → CoverLocation) → Move To (CoverLocation) → ...
           + Service no ramo: reexecuta a consulta a cada 1,5 s

 BT_Presenca:
   Espreitar:  Run EQS Query (EQS_EspreitaPresenca → StalkPoint)
   Recuar:     Run EQS Query (EQS_RecuoPresenca → RetreatLocation)
   Investigar: Move To (LastKnownLocation) → Look Around → Run EQS (EQS_BuscaPresenca) → Move To → Look Around
```

A árvore ganhou qualidade sem mudar de forma: a estrutura de prioridades é a mesma; o que mudou foi **onde** cada ação acontece. É a separação do Capítulo 33 (decisão vs. posicionamento tático) funcionando.

---

## 39.5 Custo e depuração

### Custo

Consultas EQS são **executadas ao longo de vários frames** pelo gerenciador de EQS, com orçamento de tempo por frame. Isso protege o frame, mas significa que o resultado **chega depois** — e que dezenas de agentes consultando ao mesmo tempo esperam na fila. Práticas:

- poucos itens (raios e espaçamentos de grade moderados);
- testes caros por último;
- não reexecutar a consulta a cada frame: use services com intervalo, e só quando a situação mudou;
- o modo "melhor item" pode parar cedo em algumas situações; "todos os itens" não.

### Depuração

- **EQS Testing Pawn** — um pawn especial que você coloca no nível **no editor**: ele executa uma consulta continuamente e desenha os itens com suas pontuações (cores e números), **sem dar Play**. Mova o pawn, mova o contexto, e veja a consulta responder. É a melhor ferramenta para ajustar pesos e faixas.
- **Gameplay Debugger**, categoria EQS — mostra as consultas recentes de um agente em jogo, com itens e pontuações.

---

## Comparação com o desenvolvimento tradicional

| EQS | O que você conhece | Onde a analogia cai |
|---|---|---|
| Gerador + filtros + pontuação + limite | `SELECT ... WHERE ... ORDER BY ... LIMIT` | A "tabela" é gerada da geometria a cada consulta |
| Ordem dos testes por custo | Plano de consulta (filtros seletivos primeiro) | O EQS ordena; você declara o custo de cada teste |
| Aleatório entre os melhores | Balanceamento ponderado / top-k sampling | O objetivo é **imprevisibilidade percebida** |
| Execução fatiada em frames | Processamento assíncrono com orçamento | O resultado pode chegar desatualizado |
| EQS Testing Pawn | Explorar uma consulta num console interativo | Visual, no espaço do nível |

---

## Implementação

### 1. Contextos customizados

Os contextos que leem do Blackboard do agente:

```cpp
// Source/Vigilia/AI/EQS/EnvQueryContext_VGBlackboard.h
#pragma once

#include "CoreMinimal.h"
#include "EnvironmentQuery/EnvQueryContext.h"
#include "EnvQueryContext_VGBlackboard.generated.h"

/** O alvo do agente (chave TargetActor do Blackboard). */
UCLASS()
class VIGILIA_API UEnvQueryContext_VGTarget : public UEnvQueryContext
{
    GENERATED_BODY()
public:
    virtual void ProvideContext(FEnvQueryInstance& QueryInstance, FEnvQueryContextData& ContextData) const override;
};

/** A última posição conhecida do alvo (chave LastKnownLocation). */
UCLASS()
class VIGILIA_API UEnvQueryContext_VGLastKnownLocation : public UEnvQueryContext
{
    GENERATED_BODY()
public:
    virtual void ProvideContext(FEnvQueryInstance& QueryInstance, FEnvQueryContextData& ContextData) const override;
};

/** A jogadora como ATOR (localização + rotação), para testes "do ponto de vista dela" (Trace, Dot). */
UCLASS()
class VIGILIA_API UEnvQueryContext_VGPlayerView : public UEnvQueryContext
{
    GENERATED_BODY()
public:
    virtual void ProvideContext(FEnvQueryInstance& QueryInstance, FEnvQueryContextData& ContextData) const override;
};
```

```cpp
// Source/Vigilia/AI/EQS/EnvQueryContext_VGBlackboard.cpp
#include "AI/EQS/EnvQueryContext_VGBlackboard.h"

#include "AI/VGBlackboardKeys.h"
#include "AIController.h"
#include "BehaviorTree/BlackboardComponent.h"
#include "EnvironmentQuery/Items/EnvQueryItemType_Actor.h"
#include "EnvironmentQuery/Items/EnvQueryItemType_Point.h"
#include "Kismet/GameplayStatics.h"

namespace
{
    const UBlackboardComponent* GetQuerierBlackboard(const FEnvQueryInstance& QueryInstance)
    {
        const APawn* Pawn = Cast<APawn>(QueryInstance.Owner.Get());
        const AAIController* Controller = Pawn ? Cast<AAIController>(Pawn->GetController()) : nullptr;
        return Controller ? Controller->GetBlackboardComponent() : nullptr;
    }
}

void UEnvQueryContext_VGTarget::ProvideContext(FEnvQueryInstance& QueryInstance, FEnvQueryContextData& ContextData) const
{
    if (const UBlackboardComponent* BB = GetQuerierBlackboard(QueryInstance))
    {
        if (AActor* Target = Cast<AActor>(BB->GetValueAsObject(VGBBKeys::TargetActor)))
        {
            UEnvQueryItemType_Actor::SetContextHelper(ContextData, Target);
        }
    }
}

void UEnvQueryContext_VGLastKnownLocation::ProvideContext(FEnvQueryInstance& QueryInstance, FEnvQueryContextData& ContextData) const
{
    if (const UBlackboardComponent* BB = GetQuerierBlackboard(QueryInstance))
    {
        UEnvQueryItemType_Point::SetContextHelper(ContextData, BB->GetValueAsVector(VGBBKeys::LastKnownLocation));
    }
}

void UEnvQueryContext_VGPlayerView::ProvideContext(FEnvQueryInstance& QueryInstance, FEnvQueryContextData& ContextData) const
{
    // Um ATOR, não um ponto: o teste Dot precisa da rotação (para onde ela olha), e um ponto não tem.
    if (const APawn* Player = UGameplayStatics::GetPlayerPawn(QueryInstance.World, 0))
    {
        UEnvQueryItemType_Actor::SetContextHelper(ContextData, Player);
    }
}
```

> ⚠️ **Ponto ou ator?** Um contexto fornecido como **ponto** só tem localização; testes que medem direção (Dot usando a rotação do contexto) não têm o que ler. Por isso o `VGPlayerView` fornece o **pawn** da jogadora: localização **e** rotação. Num personagem em primeira pessoa que gira com o controle, a rotação do pawn acompanha o yaw da câmera — use o Dot em 2D. Para o Trace "do ponto de vista dela", aplique no teste um deslocamento de altura do contexto até a altura dos olhos (o pawn é medido no centro da cápsula).

Os contextos leem o Blackboard pelas constantes do contrato (Capítulo 38) — e só **leem**: consultas não escrevem memória; a tarefa *Run EQS Query* grava o **resultado** na chave configurada.

### 2. Um teste customizado: dentro de uma zona segura?

O filtro de navegação já exclui pontos iluminados **para a Presença**. Mas há perguntas sobre luz que não são de navegação — por exemplo, um vigia que **prefere** se cobrir em lugares escuros (onde a jogadora o vê pior). Um teste customizado:

```cpp
// Source/Vigilia/AI/EQS/EnvQueryTest_VGInSafeZone.h
#pragma once

#include "CoreMinimal.h"
#include "EnvironmentQuery/EnvQueryTest.h"
#include "EnvQueryTest_VGInSafeZone.generated.h"

/** Testa se o item está dentro de uma zona segura ativa (área iluminada). Bool: filtro ou pontuação. */
UCLASS()
class VIGILIA_API UEnvQueryTest_VGInSafeZone : public UEnvQueryTest
{
    GENERATED_BODY()
public:
    UEnvQueryTest_VGInSafeZone();
    virtual void RunTest(FEnvQueryInstance& QueryInstance) const override;
};
```

```cpp
// Source/Vigilia/AI/EQS/EnvQueryTest_VGInSafeZone.cpp
#include "AI/EQS/EnvQueryTest_VGInSafeZone.h"

#include "EngineUtils.h"
#include "EnvironmentQuery/Items/EnvQueryItemType_VectorBase.h"
#include "World/VGSafeZone.h"

UEnvQueryTest_VGInSafeZone::UEnvQueryTest_VGInSafeZone()
{
    Cost = EEnvTestCost::Low;
    ValidItemType = UEnvQueryItemType_VectorBase::StaticClass();
    SetWorkOnFloatValues(false); // teste booleano
}

void UEnvQueryTest_VGInSafeZone::RunTest(FEnvQueryInstance& QueryInstance) const
{
    // Simplificação: percorre as zonas seguras do mundo (poucas na Vigília).
    // Com muitas zonas, um registro num subsistema (Cap. 8, seção 8.5) seria o caminho.
    TArray<const AVGSafeZone*> ActiveZones;
    for (TActorIterator<AVGSafeZone> It(QueryInstance.World); It; ++It)
    {
        if (It->IsZoneActive()) { ActiveZones.Add(*It); }
    }

    BoolValue.BindData(QueryInstance.Owner.Get(), QueryInstance.QueryID);
    const bool bWantInside = BoolValue.GetValue();

    for (FEnvQueryInstance::ItemIterator It(this, QueryInstance); It; ++It)
    {
        const FVector Point = GetItemLocation(QueryInstance, It.GetIndex());
        bool bInside = false;
        for (const AVGSafeZone* Zone : ActiveZones)
        {
            if (Zone->ContainsPoint(Point)) { bInside = true; break; }
        }
        It.SetScore(TestPurpose, FilterType, bInside, bWantInside);
    }
}
```

O `AVGSafeZone` ganha `ContainsPoint(FVector)` (teste do ponto contra a caixa do volume, no espaço local). O `Cost = EEnvTestCost::Low` do construtor não é decoração: é por ele que o EQS posiciona o teste na execução (seção 39.2) — um teste caro declarado como `Low` roda cedo, sobre todos os itens. E o comentário `// Simplificação:` documenta o teto: iterar o mundo funciona com poucas zonas e é o tipo de coisa que o profiler do Capítulo 59 vai confirmar ou desmentir.

### 3. As consultas

Crie, no editor, os assets `EQS_CoberturaVigia`, `EQS_EspreitaPresenca`, `EQS_RecuoPresenca` e `EQS_BuscaPresenca` com a composição da seção 39.3, usando os contextos customizados. Para o recuo, o contexto `RetreatOrigin` é um terceiro contexto (lê uma chave `StunOrigin` gravada pelo componente de reação — acrescente-a ao contrato do Blackboard).

### 4. Ajuste com o Testing Pawn

No Galpão, coloque um **EQS Testing Pawn** com a consulta de cobertura, e um ator qualquer representando a jogadora (para o contexto de alvo, configure o testing pawn para usar um contexto fixo, ou crie uma variante do contexto que, no editor, use um ator marcado). Mova o "alvo" pelo galpão e observe os pontos de cobertura mudando. Ajuste pesos e faixas até que os pontos escolhidos sejam os que **você** escolheria.

---

## Projeto 5 — posicionamento

1. **Vigias** com cobertura por EQS no Galpão: atire de posições diferentes e observe os vigias trocando de cobertura.
2. **Presença** na Casa de Força com espreita, recuo e busca por EQS. Teste a busca: esconda-se no vestiário, deixe a consciência dela subir com passos, e observe por onde ela procura.
3. **Telemetria** (Capítulo 24): publique eventos `Event.AI.StalkPointChosen` e `Event.AI.SearchPointChosen` e veja, no CSV de uma sessão, se a Presença está variando os pontos ou repetindo.

---

## Decisões arquiteturais

1. **Perguntas espaciais da IA são consultas EQS**: gerador + filtros + pontuação + modo.
2. **Regras de navegação continuam no filtro de navegação** (o gerador de grade de caminho as herda); testes não as duplicam.
3. **Contextos customizados leem o Blackboard pelo contrato**; consultas não escrevem memória.
4. **Testes baratos primeiro; traces e pathfinding por último.**
5. **Aleatório entre os melhores** para espreita e busca (variedade); **melhor item** para cobertura e recuo (qualidade).
6. **Falha de consulta é informação**: a árvore reage.
7. **Ajuste com o EQS Testing Pawn** antes de testar em jogo.

---

## Armadilhas

- **Consultas a cada frame** — fila do EQS cheia, resultados atrasados.
- **Grades grandes e densas** com testes caros.
- **Custo declarado errado** em testes customizados (um teste caro marcado `Low` roda antes dos filtros baratos).
- **Duplicar regras de navegação em testes** ("não está na luz" num teste e no filtro).
- **Cobertura sem referência a quem** — "cobertura" que não bloqueia a jogadora.
- **Sempre o melhor ponto** em comportamentos que deveriam variar (espreita previsível).
- **Ignorar falha da consulta** — Move To para um ponto não definido.

---

## Exercício

**Parte 1 — contextos e teste (1,5 h).** Implemente os três contextos e o teste de zona segura. Verifique-os com o EQS Testing Pawn.

**Parte 2 — consultas (2 h).** Crie as quatro consultas e integre-as às árvores. Teste no Galpão e na Casa de Força.

**Parte 3 — custo (45 min).** Com cinco vigias, meça (Gameplay Debugger e `stat` de EQS, se disponível na sua versão) o tempo das consultas de cobertura. Troque o propósito de testes (pontuação → filtro onde fizer sentido), reduza o raio e o espaçamento da grade; compare. Depois, reordene os testes no asset e confirme que o tempo praticamente **não** muda — a ordem de execução vem do `Cost` (a do asset só desempata testes de mesmo custo).

**Parte 4 — legibilidade (30 min).** Peça a alguém para jogar a Casa de Força com a Presença usando a busca por EQS. Pergunte: "ela parecia te procurar ou andar a esmo?". Ajuste os pesos se a resposta for "a esmo".

---

## Desafio — o ponto de emboscada

Crie a consulta **`EQS_EmboscadaPresenca`**: um ponto **no escuro**, **ao longo do provável caminho** da jogadora até o próximo objetivo, e **fora da visão** dela agora — para que a Presença chegue **antes** e espere.

1. O "provável caminho" é um problema por si: use o caminho de navegação da jogadora até o objetivo ativo (o `UVGObjectiveSubsystem` do Capítulo 31 sabe o objetivo; o objetivo tem um local, por exemplo, o gatilho do Capítulo 31) e gere itens perto dos pontos desse caminho.
2. Pontue: perto do caminho (melhor), longe da jogadora agora (não pode aparecer na frente dela), escondido da câmera dela.
3. Use a consulta num ramo novo da BT da Presença, acionado **pelo Diretor** (Capítulo 42) — por enquanto, por um cheat.

Pergunta para o `DEVLOG.md`: uma emboscada perfeita, sempre, é boa para o jogo? Como a emboscada se relaciona com a "telegrafia obrigatória" do Capítulo 21? (A Presença pode esperar na emboscada, mas o ataque continua precisando de telegrafia.)

---

## Uso de IA

1. **Para desenhar consultas:**
   > "Desenhe uma consulta EQS da Unreal Engine 5 (gerador, testes com propósito filtro/pontuação, contextos, pesos, modo de execução) para: [pergunta espacial, ex. 'ponto para flanquear a jogadora pela esquerda, a 8–12 m, com linha de visão para ela e fora da linha de tiro dos aliados']. Ordene os testes por custo e explique cada escolha."

2. **Para revisar custo:**
   > "Esta consulta EQS é executada por 6 agentes a cada 0,5 s e está causando atrasos. [descrição] Proponha mudanças para reduzir o custo (gerador, espaçamento, ordem de testes, frequência, modo de execução) sem perder a qualidade da escolha."

3. **Para escrever extensões:**
   > "Mostre como escrever em C++, na Unreal Engine 5, um UEnvQueryContext que fornece um ponto lido do Blackboard do agente e um UEnvQueryTest booleano customizado, explicando ValidItemType, Cost, SetWorkOnFloatValues, BoolValue.BindData e It.SetScore. Indique o que pode variar entre versões."

---

## Checklist

- [ ] Sei explicar gerador, testes, contextos, filtro vs. pontuação e modos de execução.
- [ ] Sei escolher geradores e testes e ordená-los por custo.
- [ ] Escrevi contextos e um teste customizados em C++.
- [ ] Integrei consultas à BT gravando resultados no Blackboard e tratando falha.
- [ ] Implementei cobertura do vigia e espreita, recuo e busca da Presença.
- [ ] Usei o EQS Testing Pawn para ajustar pesos.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Environment Query System** (visão geral, guia rápido, referência de geradores, testes e contextos, EQS Testing Pawn).
- **Steve Rabin (org.), *Game AI Pro*** — capítulos sobre *tactical position selection* e sistemas de consulta espacial em jogos.

---

➡️ **Próximo:** [Capítulo 40 — Utility AI](cap-40-utility-ai.md)

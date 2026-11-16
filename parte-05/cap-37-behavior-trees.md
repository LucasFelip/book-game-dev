# Capítulo 37 — Behavior Trees

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o modelo de **Behavior Tree** (BT): composites (*selector*, *sequence*, *parallel*), tarefas, decorators e services, e os resultados *sucesso*, *falha* e *em andamento*;
- usar a **ordem de prioridade** de um selector e os **observer aborts** para obter comportamento **reativo** sem transições explícitas;
- escrever **tasks, decorators e services em C++**, entendendo a **memória de nó** (nós são compartilhados entre agentes);
- montar a **Behavior Tree da Presença** (atordoada → caçar → investigar → espreitar) e reescrever o vigia como BT;
- comparar BT com a HFSM do Capítulo 34 e conhecer o **StateTree** como alternativa.

---

## Contexto

O Capítulo 34 levou a FSM até o limite e terminou com um desafio desconfortável: adicionar "buscar cobertura" ao vigia. As perguntas eram todas sobre **prioridade** — "quando a cobertura vale mais que atirar?", "o que interrompe o quê?" — e a FSM só sabia responder com **transições**. Cada nova regra exigia pensar em todos os estados de onde ela poderia partir.

Behavior Trees mudam a pergunta. Em vez de "**em que estado estou e para onde vou**", uma BT pergunta, continuamente, "**qual é a coisa mais importante que posso fazer agora?**". O comportamento é uma lista de prioridades com condições, avaliada de cima para baixo. Não há transições: há **preempção** — uma prioridade mais alta que se torna possível interrompe a mais baixa.

Behavior Trees são o padrão de fato da indústria para IA de personagens desde meados dos anos 2000 e são o sistema de decisão principal da Unreal. Este capítulo é o coração da Parte V.

---

## 37.1 O modelo

Uma Behavior Tree é uma árvore em que cada nó, quando executado, termina com um de três resultados:

- **Succeeded** (sucesso) — "consegui";
- **Failed** (falha) — "não consegui / não se aplica";
- **InProgress** (em andamento) — "ainda estou fazendo" (a execução continua em frames futuros).

### Folhas: tasks

**Tarefas** (*tasks*) são as folhas: as **ações** do agente. Mover até um ponto, esperar, tocar uma animação, atirar, telegrafar, procurar. Muitas são **latentes** (duram vários frames) e terminam em sucesso ou falha.

### Composites: como os filhos se combinam

```text
SELECTOR (fallback) — "tente cada filho, da esquerda para a direita, até um dar certo"
   ┌───────────┬───────────┬───────────┐
   A           B           C
   executa A; se A falhar, tenta B; se B falhar, tenta C.
   Sucesso no primeiro que der certo. Falha se todos falharem.

SEQUENCE — "faça cada filho em ordem; pare no primeiro que falhar"
   ┌───────────┬───────────┬───────────┐
   A           B           C
   executa A; se A der certo, B; se B der certo, C.
   Sucesso se todos derem certo. Falha no primeiro que falhar.

SIMPLE PARALLEL — "faça a tarefa principal enquanto uma subárvore de fundo roda"
   ex.: "ande até o ponto" (principal) enquanto "olhe ao redor" (fundo)
```

O **selector** é uma lista de prioridades: **a ordem dos filhos é a ordem de importância**. A **sequence** é um plano curto: "telegrafe, depois avance, depois ataque".

### Decorators: condições sobre um nó

**Decorators** são condições anexadas a um nó: o nó só pode executar se a condição for verdadeira ("a jogadora está visível?", "este ramo não executou nos últimos 5 s?", "a consciência é ≥ Desconfiado?"). Eles transformam o selector numa lista de "**se** posso, faço".

### Services: atualizações enquanto um ramo está ativo

**Services** executam **periodicamente** enquanto o ramo a que pertencem está ativo — tipicamente para atualizar a memória do agente (o Blackboard, Capítulo 38) com informação que muda: a posição atual do alvo, a distância, um valor de utilidade.

### Uma árvore mínima

```text
ROOT
 └─ SELECTOR
     ├─ [vejo o alvo?]          SEQUENCE: Telegrafar → Mover até o alvo → Atacar
     ├─ [ouvi algo?]            SEQUENCE: Mover até o ruído → Olhar ao redor
     └─                         SEQUENCE: Escolher ponto de patrulha → Mover → Esperar
```

Leitura em português: *"se vejo o alvo, ataco; senão, se ouvi algo, investigo; senão, patrulho."* Três linhas, e nenhuma transição. Para acrescentar "se fui atordoado, recuo" com prioridade máxima, insere-se um ramo **à esquerda** de todos — e ele automaticamente interrompe qualquer outro.

---

## 37.2 Reatividade: observer aborts

Uma BT ingênua seria avaliada da raiz a cada frame — caro e com efeitos estranhos (reiniciar tarefas latentes). A Behavior Tree da Unreal é **orientada a eventos**: ela mantém o ramo ativo executando e só **reavalia** quando algo relevante muda. Quem diz "o que é relevante" são os decorators, através dos **observer aborts**:

| Observer abort | Significado |
|---|---|
| **None** | O decorator só é verificado quando o nó vai começar. |
| **Self** | Enquanto o **próprio** ramo executa, se a condição deixar de valer, o ramo é **abortado**. |
| **Lower Priority** | Enquanto um ramo **de menor prioridade** (à direita) executa, se esta condição **passar a valer**, o ramo de menor prioridade é abortado e este assume. |
| **Both** | Self + Lower Priority. |

Com isso, o comportamento da seção 37.1 fica reativo:

```text
 SELECTOR
  ├─ [vejo o alvo?  abort: Both]     ← se passar a ver durante a investigação → interrompe e ataca
  │                                  ← se deixar de ver durante o ataque → interrompe (e cai para investigar)
  ├─ [ouvi algo?    abort: Lower]    ← se ouvir algo durante a patrulha → interrompe e investiga
  └─ patrulha
```

Os decorators baseados em Blackboard (Capítulo 38) **observam chaves**: quando a chave muda, a condição é reavaliada imediatamente. A árvore não precisa "olhar" a cada frame; ela é **notificada**.

> 🌉 **Ponte:** um selector com observer aborts é um **escalonador preemptivo por prioridade**: tarefas de maior prioridade que ficam prontas interrompem as de menor. E a reavaliação por mudança de chave é **reatividade por observação**, como um sistema que reage a mudanças de configuração em vez de fazer *polling*.
>
> 🧱 **Onde a ponte cai:** num escalonador, a tarefa interrompida costuma ser **retomada** depois. Numa BT, o ramo abortado é **cancelado** — e, quando voltar a ser escolhido, começa do início. Tarefas precisam saber limpar o que fizeram ao serem abortadas (`AbortTask`).

---

## 37.3 Nós em C++ e a memória de nó

A Unreal vem com muitos nós prontos (*Move To*, *Wait*, *Rotate to Face BB Entry*, *Run EQS Query*, *Play Sound*, decorators de Blackboard, *Cooldown*, *Loop*, *Time Limit*...). Nós do projeto são escritos em C++ (ou em Blueprint, para prototipação).

### A armadilha: nós são compartilhados

Por padrão, **um nó de Behavior Tree é um único objeto compartilhado por todos os agentes que executam aquela árvore**. Se você guardar estado num membro do nó ("quanto tempo já esperei"), dois agentes executando o mesmo nó vão **sobrescrever** o estado um do outro.

O estado por agente vai para a **memória de nó** (*node memory*): um bloco de memória que a árvore aloca **por agente, por nó**. O nó declara o tamanho (`GetInstanceMemorySize`) e acessa o bloco pelo parâmetro `NodeMemory`:

```cpp
struct FVGTelegraphMemory
{
    float Elapsed = 0.0f;
};

uint16 UBTTask_VGTelegraph::GetInstanceMemorySize() const
{
    return sizeof(FVGTelegraphMemory);
}

// A memória chega ZERADA, não construída: os inicializadores do struct não rodam sozinhos.
// Para que rodem (e para structs com membros não triviais, como TArray), construa e destrua:
void UBTTask_VGTelegraph::InitializeMemory(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory,
                                           EBTMemoryInit::Type InitType) const
{
    InitializeNodeMemory<FVGTelegraphMemory>(NodeMemory, InitType); // placement new (UE 5.2+)
}

void UBTTask_VGTelegraph::CleanupMemory(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory,
                                        EBTMemoryClear::Type CleanupType) const
{
    CleanupNodeMemory<FVGTelegraphMemory>(NodeMemory, CleanupType); // destrutor
}

EBTNodeResult::Type UBTTask_VGTelegraph::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    FVGTelegraphMemory* Memory = CastInstanceNodeMemory<FVGTelegraphMemory>(NodeMemory);
    Memory->Elapsed = 0.0f; // estado DESTE agente, neste nó
    // ...
}
```

A memória de nó é um bloco de bytes que a árvore aloca com zeros — o construtor do struct **não é chamado**. Um `float Elapsed = 0.0f` sobrevive por coincidência (zero é zero), mas um `int32 Index = INDEX_NONE` começa valendo 0, e um `TArray` dentro do struct é comportamento indefinido. A regra do projeto: **todo nó com memória sobrescreve `InitializeMemory`/`CleanupMemory`** com os helpers `InitializeNodeMemory<T>`/`CleanupNodeMemory<T>` (em versões mais antigas da engine, sem esses helpers, `new (NodeMemory) T()` e `~T()` à mão). O Capítulo 40 mostra o bug que isso evita.

A alternativa é marcar o nó como **instanciado** (`bCreateNodeInstance = true`), para que cada agente ganhe uma cópia do objeto — mais simples de escrever, mais caro em memória. A regra do projeto: **memória de nó por padrão; instância só quando o nó precisar de delegates ou de `UPROPERTY`s de runtime**.

> Esse é o bug mais comum de quem escreve o primeiro nó de BT em C++: funciona perfeitamente com um agente e falha de formas bizarras com dois.

### Tarefas latentes

Uma tarefa que dura vários frames retorna `EBTNodeResult::InProgress` em `ExecuteTask` e, mais tarde, chama `FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded)` (ou `Failed`). Ela pode receber tick (`bNotifyTick = true` → `TickTask`) e **deve** tratar `AbortTask` — chamado quando um observer abort cancela o ramo.

---

## 37.4 A Behavior Tree da Presença

A especificação de comportamento da Presença (desafio do Capítulo 33) vira esta árvore:

```text
ROOT  (Blackboard: BB_Presenca — Cap. 38)
 └─ SELECTOR
     │
     ├─ [IsStunned == true   abort: Both]                                ← PRIORIDADE 1: a luz a feriu
     │   SEQUENCE "Recuar"
     │     ├─ VG Present State (Stunned)        grito, recua da luz
     │     ├─ Move To (RetreatLocation)         afasta-se do ponto de luz (Cap. 39 escolhe melhor)
     │     └─ VG Clear Stun (após StunDuration)
     │
     ├─ [AwarenessState == Aware AND TargetVisible   abort: Both]        ← PRIORIDADE 2: caça
     │   SEQUENCE "Caçar"
     │     ├─ VG Telegraph (1,2 s)              som característico + luzes próximas falham
     │     ├─ Move To (TargetActor, raio 120)   persegue (a navegação evita luz e portas — Cap. 35)
     │     └─ VG Presence Attack                o "toque": 60 de dano do tipo Presence (Cap. 22)
     │
     ├─ [AwarenessState >= Suspicious   abort: LowerPriority]            ← PRIORIDADE 3: investiga
     │   SEQUENCE "Investigar"
     │     ├─ VG Present State (Suspicious)     para, a cabeça vira, um som baixo
     │     ├─ Move To (LastKnownLocation)
     │     └─ VG Look Around (3 s)
     │
     └─ SEQUENCE "Espreitar"                                             ← PRIORIDADE 4: padrão
           ├─ VG Find Stalk Point               ponto alcançável no escuro (Cap. 39: EQS)
           ├─ Move To (StalkPoint)
           └─ Wait (4–8 s, aleatório)
```

Repare em como regras de design viraram estrutura:

- **"A luz fere e faz recuar"** é a prioridade 1: o sinalizador (Capítulo 28) aplica dano de luz → a Presença marca `IsStunned` → o ramo "Recuar" interrompe **qualquer** outro, inclusive uma caçada a meio caminho.
- **"Nunca ataca sem telegrafia"** é a ordem da sequence "Caçar": o ataque é o terceiro passo, depois da telegrafia — **estruturalmente impossível** de pular.
- **"Falível"**: se a jogadora quebra a linha de visão durante a caçada, o decorator de "Caçar" (abort Both) cancela o ramo; a consciência ainda está alta, então "Investigar" assume e vai até a última posição conhecida. Se a jogadora se escondeu bem, a Presença olha ao redor, a consciência decai, e ela volta a espreitar.
- **"Evita a luz e as portas"** não aparece na árvore: está na **navegação** (Capítulo 35). A árvore pede "vá até lá"; o mapa decide por onde.

### A reação à luz

A Presença recebe dano de luz pelo canal padrão de dano (Capítulo 22, seção 22.5). Um pequeno componente de reação no corpo (`UVGPresenceReactionComponent`) se inscreve em `OnTakeAnyDamage`, filtra o tipo `UVGDamageType_Light` e, conforme a magnitude (acerto direto do sinalizador = 100 → 4 s; pulso da área = 40 → 2 s — o documento de combate, Capítulo 21), escreve no Blackboard: `IsStunned = true`, `StunDuration`, `RetreatLocation` (um ponto afastado da origem da luz). A árvore faz o resto.

---

## 37.5 O vigia como Behavior Tree

🔁 **Refatoração do Capítulo 34.** A HFSM do vigia é substituída por uma árvore. As **ações** que o componente do cérebro oferecia aos estados (`StartFiring`, `AimAtTarget`, `MoveTo`, `LookAround`...) viram **tasks**; as **regras dos superestados** viram **decorators com aborts**.

```text
ROOT  (BB_Vigia)
 └─ SELECTOR
     ├─ [IsStaggered   abort: Both]       VG Wait For Stagger End
     │
     ├─ [Aware AND TargetVisible   abort: Both]
     │   SELECTOR "Combate"
     │     ├─ [NeedsCover (vida < 50% OU pente vazio)   abort: LowerPriority]
     │     │   SEQUENCE: VG Find Cover (Cap. 39) → Move To (CoverLocation) → VG Reload → Wait (1 s)
     │     └─ SEQUENCE: VG Telegraph (0,8 s) → VG Fire Burst (0,6 s) → Wait (1,2 s)
     │        (Service: VG Aim At Target — mantém a mira enquanto o ramo estiver ativo)
     │
     ├─ [AwarenessState >= Suspicious   abort: LowerPriority]
     │   SEQUENCE: Move To (LastKnownLocation) → VG Look Around (4 s)
     │
     └─ SEQUENCE "Patrulha": VG Next Patrol Point → Move To → Wait (2 s)
```

O desafio do Capítulo 34 — `TakeCover` — virou **um ramo com um decorator**, posicionado à esquerda do ataque. A pergunta "de quais estados se pode ir para a cobertura?" desapareceu: de **qualquer** momento do combate em que a condição ficar verdadeira, o ramo assume. E a busca de cobertura ingênua (os pontos com tag do desafio) será substituída por uma consulta EQS no Capítulo 39, **sem mudar a árvore** — só a task `VG Find Cover`.

---

## Estudo de caso: as origens das Behavior Trees em jogos

> **Pergunta:** por que a indústria adotou Behavior Trees para IA de personagens?

**[FATO PÚBLICO]** As Behavior Trees se popularizaram na indústria de jogos em meados dos anos 2000. Uma referência muito citada é a apresentação de Damian Isla na GDC 2005, *Handling Complexity in the Halo 2 AI*, que descreve uma arquitetura de decisão hierárquica baseada em prioridades usada nos inimigos de *Halo 2* (Bungie, 2004), motivada justamente pela dificuldade de gerenciar a complexidade de comportamentos com as abordagens anteriores. Desde então, BTs se tornaram uma ferramenta padrão em engines comerciais, incluindo a Unreal.

**[INFERÊNCIA]** As razões da adoção são as que este capítulo e o anterior sentiram na prática:

- **Modularidade** — comportamentos (subárvores, tarefas) são reutilizáveis e combináveis; a mesma "investigar" serve ao vigia e à Presença.
- **Prioridade explícita** — a ordem da árvore **é** a política de decisão, legível de cima para baixo.
- **Reatividade sem transições** — interrupções por prioridade substituem o emaranhado de transições.
- **Autorabilidade** — designers editam e ajustam árvores num editor visual, com depuração do ramo ativo em tempo real.

**Lição:** **a arquitetura de decisão deve tornar a política de comportamento visível.** Uma BT bem organizada é, ao mesmo tempo, código executável e documentação de design: "a Presença prefere recuar da luz a caçar, prefere caçar a investigar, prefere investigar a espreitar".

---

## 37.6 BT, FSM e StateTree

| | HFSM (Cap. 34) | Behavior Tree | StateTree (Unreal) |
|---|---|---|---|
| Unidade | Estado | Tarefa + prioridade | Estado com condições de seleção |
| Mudança de comportamento | Transição explícita | Preempção por prioridade (aborts) | Seleção por condições + transições |
| Bom para | Modos exclusivos, poucos estados | Comportamento reativo com prioridades | Lógica hierárquica moderna, eficiente; também fora de IA |
| Fraco em | Muitas prioridades sobrepostas | "Modos" de longa duração; valores contínuos | Ainda menos material de referência |
| Na Vigília | Modos de alto nível da Presença (Cap. 42) | **Vigia e Presença** | Não usado (alternativa a estudar) |

**[FATO PÚBLICO]** O **StateTree** é um sistema da Unreal Engine 5 que combina conceitos de máquinas de estado hierárquicas com seleção de estados por condições, pensado para ser eficiente e de uso geral (IA, lógica de objetos, integração com Mass e Smart Objects). Vale estudá-lo depois de dominar BTs — a documentação oficial tem guias e exemplos. O livro usa BTs por serem o sistema mais estabelecido e mais documentado da engine.

---

## Comparação com o desenvolvimento tradicional

| Behavior Tree | O que você conhece | Onde a analogia cai |
|---|---|---|
| Selector com prioridades | Cadeia de fallback / estratégias ordenadas | Reavaliada por observação de mudanças |
| Observer aborts | Preempção por prioridade | O ramo abortado é cancelado, não retomado |
| Tasks latentes | Operações assíncronas com conclusão | Precisam tratar cancelamento (`AbortTask`) |
| Memória de nó | Estado por requisição num handler sem estado | O "handler" é compartilhado por todos os agentes |
| BT como documentação | Regras de negócio legíveis (DSL) | É executada em tempo real e depurada visualmente |

---

## Implementação

### 1. Uma task latente com memória: telegrafia

```cpp
// Source/Vigilia/AI/BT/BTTask_VGTelegraph.h
#pragma once

#include "CoreMinimal.h"
#include "BehaviorTree/BTTaskNode.h"
#include "BTTask_VGTelegraph.generated.h"

/**
 * Telegrafa um ataque: avisa o corpo (apresentação) e espera Duration segundos.
 * Estado por agente na memória de nó (nós são compartilhados entre agentes).
 */
UCLASS()
class VIGILIA_API UBTTask_VGTelegraph : public UBTTaskNode
{
    GENERATED_BODY()

public:
    UBTTask_VGTelegraph();

    virtual EBTNodeResult::Type ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
    virtual EBTNodeResult::Type AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;
    virtual void TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
    virtual uint16 GetInstanceMemorySize() const override;
    virtual FString GetStaticDescription() const override;

protected:
    /** Nunca menor que reação + resposta da jogadora (Cap. 21). */
    UPROPERTY(EditAnywhere, Category = "Telegraph", meta = (ClampMin = "0.2"))
    float Duration = 1.0f;
};
```

```cpp
// Source/Vigilia/AI/BT/BTTask_VGTelegraph.cpp
#include "AI/BT/BTTask_VGTelegraph.h"

#include "AI/VGEnemyCharacter.h"
#include "AIController.h"

namespace
{
    struct FVGTelegraphMemory
    {
        float Elapsed = 0.0f;
    };
}

UBTTask_VGTelegraph::UBTTask_VGTelegraph()
{
    NodeName = TEXT("VG Telegraph");
    bNotifyTick = true;
}

uint16 UBTTask_VGTelegraph::GetInstanceMemorySize() const
{
    return sizeof(FVGTelegraphMemory);
}

FString UBTTask_VGTelegraph::GetStaticDescription() const
{
    return FString::Printf(TEXT("Telegrafar por %.2f s"), Duration); // aparece no editor da árvore
}

EBTNodeResult::Type UBTTask_VGTelegraph::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    CastInstanceNodeMemory<FVGTelegraphMemory>(NodeMemory)->Elapsed = 0.0f;

    if (AVGEnemyCharacter* Body = Cast<AVGEnemyCharacter>(OwnerComp.GetAIOwner()->GetPawn()))
    {
        Body->NotifyTelegraph(true); // apresentação no Blueprint: som, luzes, animação
    }
    return EBTNodeResult::InProgress;
}

void UBTTask_VGTelegraph::TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
    FVGTelegraphMemory* Memory = CastInstanceNodeMemory<FVGTelegraphMemory>(NodeMemory);
    Memory->Elapsed += DeltaSeconds;
    if (Memory->Elapsed >= Duration)
    {
        if (AVGEnemyCharacter* Body = Cast<AVGEnemyCharacter>(OwnerComp.GetAIOwner()->GetPawn()))
        {
            Body->NotifyTelegraph(false);
        }
        FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
    }
}

EBTNodeResult::Type UBTTask_VGTelegraph::AbortTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    // Interrompida (perdeu o alvo, foi atordoada): desfaz a apresentação.
    if (AVGEnemyCharacter* Body = Cast<AVGEnemyCharacter>(OwnerComp.GetAIOwner()->GetPawn()))
    {
        Body->NotifyTelegraph(false);
    }
    return EBTNodeResult::Aborted;
}
```

`AVGEnemyCharacter` ganha `NotifyTelegraph(bool)`, que chama um `BlueprintImplementableEvent` (`OnTelegraph(bool bActive)`) — a apresentação continua no Blueprint do corpo (Capítulo 13).

### 2. O ataque da Presença

```cpp
// Source/Vigilia/AI/BT/BTTask_VGPresenceAttack.cpp (essencial)
EBTNodeResult::Type UBTTask_VGPresenceAttack::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    AAIController* Controller = OwnerComp.GetAIOwner();
    APawn* Body = Controller->GetPawn();
    AActor* Target = Cast<AActor>(OwnerComp.GetBlackboardComponent()->GetValueAsObject(TargetKey.SelectedKeyName));

    if (!Body || !IsValid(Target) || FVector::Dist(Body->GetActorLocation(), Target->GetActorLocation()) > AttackRange)
    {
        return EBTNodeResult::Failed; // fora do alcance: a sequence falha e a árvore reavalia
    }

    UGameplayStatics::ApplyDamage(Target, Damage, Controller, Body, UVGDamageType_Presence::StaticClass());
    UVGNoiseLibrary::ReportNoise(Body, Body->GetActorLocation(), 1.5f, Body, 2500.0f, TEXT("PresenceAttack"));
    return EBTNodeResult::Succeeded;
}
```

`TargetKey` é um `FBlackboardKeySelector` editável no nó (Capítulo 38), e `Damage = 60`, `AttackRange = 150` são propriedades — o "dois toques" do documento de combate (Capítulo 21). Depois do ataque, a sequence termina; a árvore volta ao topo e, se a jogadora ainda estiver visível e ao alcance, a **telegrafia acontece de novo** antes do segundo toque. A janela de fuga entre os dois toques é estrutural.

### 3. Um service: manter a mira

```cpp
// Source/Vigilia/AI/BT/BTService_VGAimAtTarget.cpp (essencial)
UBTService_VGAimAtTarget::UBTService_VGAimAtTarget()
{
    NodeName = TEXT("VG Aim At Target");
    Interval = 0.05f;          // ~20 Hz
    RandomDeviation = 0.0f;
    bNotifyCeaseRelevant = true; // sem isto, OnCeaseRelevant NUNCA é chamado (o padrão é false)
}

void UBTService_VGAimAtTarget::TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
    Super::TickNode(OwnerComp, NodeMemory, DeltaSeconds);
    AAIController* Controller = OwnerComp.GetAIOwner();
    if (AActor* Target = Cast<AActor>(OwnerComp.GetBlackboardComponent()->GetValueAsObject(TargetKey.SelectedKeyName)))
    {
        Controller->SetFocus(Target); // o AIController gira a control rotation para o foco (Cap. 30)
    }
}

void UBTService_VGAimAtTarget::OnCeaseRelevant(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    OwnerComp.GetAIOwner()->ClearFocus(EAIFocusPriority::Gameplay); // o ramo terminou: solta o foco
    Super::OnCeaseRelevant(OwnerComp, NodeMemory);
}
```

🔁 O foco que o cérebro ingênuo ligava e desligava à mão em cada estado (Capítulos 30 e 34) vira um **service**: o ramo que precisa mirar declara isso, e o `AIController` gira a control rotation para o ator focado a cada frame. O service só define e limpa o foco — e `OnCeaseRelevant` garante a limpeza quando o ramo deixa de estar ativo, por qualquer motivo.

⚠️ **As notificações de um nó auxiliar são opt-in.** `UBTService` liga `bNotifyTick` no construtor, mas `bNotifyBecomeRelevant` e `bNotifyCeaseRelevant` começam **desligados**: sobrescrever `OnBecomeRelevant`/`OnCeaseRelevant` sem ligar a flag correspondente compila, roda e simplesmente nunca é chamado. (Em services Blueprint, a engine liga as flags sozinha conforme os eventos implementados; em C++, é com você.) Aqui o sintoma seria sutil — o vigia continuaria encarando a jogadora depois de sair do combate —; no Capítulo 42, o mesmo esquecimento **vaza tokens**.

### 4. Tasks restantes

Com o mesmo padrão (memória de nó para estado, `AbortTask` limpando efeitos):

- **`VG Fire Burst`** — `StartFire` no componente de armas, espera a duração (memória de nó), `StopFire` ao terminar **e** ao abortar. O erro de mira dosado do Capítulo 30 vai para um service (`VG Aim Error`) que reduz a dispersão externa a cada disparo e a reinicia quando o ramo de combate começa.
- **`VG Look Around`** — gira o foco por alguns pontos ao redor (ou usa `SetFocalPoint` em direções sorteadas), por N segundos.
- **`VG Find Stalk Point`** — por enquanto, `UNavigationSystemV1::GetRandomReachablePointInRadius` com o filtro da Presença (assim o ponto é sempre no escuro); no Capítulo 39, uma consulta EQS.
- **`VG Next Patrol Point`** — percorre uma lista de pontos (atores no nível) referenciada pelo pawn.
- **`VG Present State`** — dispara um evento de apresentação no corpo (estado desconfiado, atordoado).
- **`VG Wait For Stagger End`** e **`VG Clear Stun`** — esperam e limpam as chaves correspondentes.

### 5. Ligando

No `BP_VGAIController_Presenca`: `BehaviorTree = BT_Presenca`. No `BP_VGAIController_Vigia`: `BehaviorTree = BT_Vigia`. O `AVGAIController::OnPossess` (Capítulo 33) já chama `RunBehaviorTree`. Remova o `UVGGuardBrainComponent` dos vigias — a HFSM fica no projeto para o Capítulo 42.

O componente de consciência (Capítulo 36) passa a **escrever no Blackboard** quando o estado muda: `AwarenessState`, `TargetActor`, `TargetVisible`, `LastKnownLocation`. O Capítulo 38 formaliza isso.

---

## Projeto 5 — as árvores

1. **`BT_Presenca`** e **`BB_Presenca`**, com as tasks e o componente de reação à luz.
2. **`BT_Vigia`** e **`BB_Vigia`**, substituindo a HFSM.
3. Na **Casa de Força** (`L_CasaDeForca`): a Presença espreita no subsolo e no corredor. Teste os quatro ramos:
   - acenda a lanterna perto dela → ela caça (com telegrafia);
   - quebre a linha de visão e se esconda → ela investiga e desiste;
   - dispare o sinalizador → ela recua;
   - entre no hall iluminado → ela para na borda da luz (navegação) e fica rondando.
4. No **Galpão**: os vigias com BT, incluindo o ramo de cobertura com a busca ingênua.
5. Durante o PIE, abra as árvores com o **depurador de BT** (selecione o agente) e acompanhe o ramo ativo. Use **breakpoints** num nó para pausar o jogo quando ele executar.

---

## Decisões arquiteturais

1. **Behavior Trees para o vigia e a Presença**; HFSM reservada a modos de alto nível (Capítulo 42).
2. **A ordem do selector é a política de comportamento**; regras de design viram estrutura (telegrafia antes do ataque, luz com prioridade máxima).
3. **Reatividade por decorators com observer aborts**, observando chaves do Blackboard.
4. **Nós em C++ com memória de nó por padrão**; `AbortTask` sempre desfaz efeitos.
5. **Ações viram tasks; regras de contexto viram decorators**; manutenção contínua (mira, erro) vira service.
6. **A reação à luz é dano de luz → chaves do Blackboard**, pelo canal padrão de dano.
7. **A navegação continua dona de "por onde"**; a árvore só pede "para onde".

---

## Armadilhas

- **Estado em membros de nós não instanciados** — agentes sobrescrevendo uns aos outros.
- **Tasks latentes que não tratam `AbortTask`** — o vigia continua atirando depois de perder o alvo.
- **Observer aborts errados** — ramos que nunca interrompem (None) ou que se interrompem em loop.
- **Decorators que consultam o mundo a cada frame** em vez de observar chaves.
- **Árvores gigantes sem subárvores** — vire ramos em `Run Behavior` (subárvores) quando crescerem.
- **Lógica de "por onde ir" na árvore** em vez da navegação.
- **Ataques fora da sequence de telegrafia.**

---

## Exercício

**Parte 1 — tasks (2 h).** Implemente `VG Telegraph`, `VG Presence Attack`, `VG Aim At Target`, `VG Fire Burst` e `VG Look Around`. Teste cada uma isoladamente numa árvore mínima.

**Parte 2 — a Presença (2 h).** Monte `BT_Presenca` e o componente de reação à luz. Faça os quatro testes do Projeto 5 e registre, para cada um, o ramo ativo no depurador.

**Parte 3 — o vigia (1,5 h).** Reescreva o vigia como `BT_Vigia`. Compare com a HFSM: quantos nós? Onde ficou a regra de cobertura? Quanto tempo levou para adicioná-la?

**Parte 4 — o bug dos nós compartilhados (30 min).** Crie uma cópia de `VG Telegraph` que guarda `Elapsed` num **membro** em vez da memória de nó. Coloque três vigias usando-a e observe. Explique o que aconteceu no `DEVLOG.md`, e apague a cópia.

---

## Desafio — a Presença que espera na borda da luz

Hoje, quando a jogadora entra numa zona segura, a Presença (que não encontra caminho até ela) recebe falha no `Move To` e a árvore cai para investigar ou espreitar — o que é correto, mas sem graça. Projete um comportamento de **espera ameaçadora**:

1. Um novo ramo, com prioridade entre "Caçar" e "Investigar": **"Rondar a luz"** — se a jogadora está visível **dentro de uma zona segura** (tag `Status.Zone.Safe`), a Presença vai até a borda da luz mais próxima da jogadora, para, e **observa** (foco na jogadora), deslocando-se lentamente ao longo da borda.
2. Ela permanece enquanto a jogadora estiver na luz, até um limite de tempo, e então recua para o escuro (fingindo desistir).
3. A apresentação: respiração audível, as luzes da **borda** da zona falham levemente.

Pergunta para o `DEVLOG.md`: o que a jogadora sente ao ver a Presença esperando? Como isso muda o valor das zonas seguras na curva de tensão (Capítulo 5)? E que pergunta de design isso abre para o Diretor (Capítulo 42) — quanto tempo a jogadora pode "acampar" na luz?

---

## Uso de IA

1. **Para revisar a árvore:**
   > "Revise esta Behavior Tree da Unreal Engine 5 para uma criatura de terror (estrutura abaixo, com decorators e observer aborts). Procure: ramos que nunca executam, aborts que causam oscilação, ataques possíveis sem telegrafia, falta de tratamento de falha do Move To e prioridades que contradizem a especificação de comportamento. [árvore + especificação]"

2. **Para escrever nós corretamente:**
   > "Mostre como escrever uma task latente de Behavior Tree em C++ na Unreal Engine 5 que espera um tempo configurável, com estado por agente na memória de nó (GetInstanceMemorySize, CastInstanceNodeMemory), TickTask, FinishLatentTask e AbortTask. Explique por que guardar o estado num membro do nó é um bug quando vários agentes usam a mesma árvore."

3. **Para comparar com StateTree:**
   > "Compare Behavior Trees e StateTree na Unreal Engine 5 para a IA de um inimigo de shooter: modelo mental, reatividade, autoria por designers, depuração, desempenho e maturidade. Em que casos você escolheria cada um?"

**Cuidado específico:** a API de nós de Behavior Tree tem muitos detalhes (memória de nó, inicialização, notificações) que IAs frequentemente simplificam de forma errada — por exemplo, sugerindo membros mutáveis em nós não instanciados. Teste sempre com **vários agentes** ao mesmo tempo.

---

## Checklist

- [ ] Sei explicar selector, sequence, parallel, tasks, decorators, services e os três resultados.
- [ ] Sei usar observer aborts para reatividade e escolher entre None, Self, Lower Priority e Both.
- [ ] Sei escrever tasks latentes, decorators e services em C++ com memória de nó e tratamento de aborto.
- [ ] Montei a Behavior Tree da Presença com recuar → caçar → investigar → espreitar.
- [ ] Reescrevi o vigia como BT, com cobertura como ramo priorizado.
- [ ] Sei comparar HFSM, BT e StateTree.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Behavior Trees** (visão geral, guia rápido, referência de nós, decorators e observer aborts, *Behavior Tree User Guide*), e **StateTree**.
- **Damian Isla, *Handling Complexity in the Halo 2 AI*** (GDC 2005) — apresentação clássica sobre decisão hierárquica com prioridades.
- **Steve Rabin (org.), *Game AI Pro*** — há capítulos dedicados a Behavior Trees (incluindo armadilhas comuns e variações).

---

➡️ **Próximo:** [Capítulo 38 — Blackboard](cap-38-blackboard.md)

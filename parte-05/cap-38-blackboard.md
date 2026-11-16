# Capítulo 38 — Blackboard

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o **Blackboard** como a **memória de trabalho** de um agente e o seu papel na reatividade da Behavior Tree;
- usar os **tipos de chave**, a **herança** entre blackboards e as chaves **sincronizadas por instância** (compartilhadas entre agentes);
- decidir **o que pertence** ao Blackboard — e o que pertence a dados de configuração, a subsistemas ou ao estado narrativo;
- estabelecer o **contrato do Blackboard**: cada chave com um único escritor e leitores conhecidos;
- acessar chaves em C++ com segurança, por **constantes de nome** em sistemas e por **seletores de chave** em nós de BT.

---

## Contexto

O Capítulo 37 usou chaves de Blackboard o tempo todo — `IsStunned`, `AwarenessState`, `TargetActor`, `LastKnownLocation` — sem parar para discutir o que elas são. Os decorators "observavam" essas chaves; a consciência (Capítulo 36) "escrevia" nelas; as tasks as "liam". O Blackboard é a peça que conecta percepção, decisão e ação, e é exatamente por isso que ele precisa de disciplina: um Blackboard sem regras vira o **estado global** de cada agente, escrito por qualquer um, lido por todos — o oposto do dono único do Capítulo 4.

Este é um capítulo curto sobre uma ideia simples, com consequências grandes: **o Blackboard é um contrato**.

---

## 38.1 O que é o Blackboard

Um **Blackboard** é um conjunto de **chaves tipadas** — um dicionário com esquema — que representa o que um agente **sabe** e **pretende** neste momento. Cada agente que executa uma Behavior Tree tem a sua **instância** do Blackboard (o `UBlackboardComponent`, criado pelo `RunBehaviorTree`), definida por um **asset** de Blackboard (o esquema).

```text
 BB_Presenca (asset: o esquema)            instância da Presença #1 (runtime)
 ─────────────────────────────             ──────────────────────────────────
 TargetActor        : Object (Actor)       TargetActor       = BP_VGJogadora_C_0
 TargetVisible      : Bool                 TargetVisible     = false
 AwarenessState     : Enum (EVGAwareness)  AwarenessState    = Suspicious
 LastKnownLocation  : Vector               LastKnownLocation = (1200, -340, 90)
 IsStunned          : Bool                 IsStunned         = false
 StunDuration       : Float                StunDuration      = 0.0
 RetreatLocation    : Vector               RetreatLocation   = (não definido)
 StalkPoint         : Vector               StalkPoint        = (800, 200, 90)
```

Tipos disponíveis: `Bool`, `Int`, `Float`, `Enum`, `Name`, `String`, `Vector`, `Rotator`, `Object` (com classe base restringível), `Class`. Chaves `Object` e `Vector` podem estar **definidas** ou **não definidas** — decorators como *Blackboard Based Condition* testam "está definido?" (`Is Set`), o que é útil para "tenho um alvo?" e "tenho um ponto de cobertura?".

### O papel na reatividade

O Blackboard **notifica** quem observa uma chave quando o valor muda. É isso que torna a Behavior Tree da Unreal orientada a eventos (Capítulo 37, seção 37.2): um decorator com abort observa `TargetVisible`; quando a consciência escreve `true`, a árvore reavalia **naquele momento**, sem varrer a árvore a cada frame.

> 🌉 **Ponte:** o padrão tem nome antigo em IA: **arquitetura de quadro-negro** (*blackboard architecture*), em que vários "especialistas" leem e escrevem num espaço de dados compartilhado — usada, por exemplo, no sistema de reconhecimento de fala Hearsay-II, nos anos 1970. Na prática de hoje, ele lembra um **store reativo** (como um store Redux ou um contexto observável): estado centralizado, assinantes notificados por mudança.
>
> 🧱 **Onde a ponte cai:** um store de aplicação costuma ter redutores e ações como único caminho de escrita. O Blackboard da Unreal aceita escrita direta de qualquer código que tenha o componente — e é por isso que o projeto precisa impor o contrato da seção 38.3.

---

## 38.2 O que pertence ao Blackboard

O teste é: **isto é algo que o agente sabe ou pretende agora, e que a decisão precisa observar?**

| Informação | Pertence ao Blackboard? | Onde vai |
|---|:-:|---|
| O alvo atual, se está visível, a última posição conhecida | ✓ | Blackboard (escrita pela consciência) |
| O estado de consciência (desatento/desconfiado/ciente) | ✓ | Blackboard |
| "Fui atordoado", por quanto tempo, para onde recuar | ✓ | Blackboard (escrita pela reação) |
| O ponto escolhido para espreitar, para cobrir-se | ✓ | Blackboard (escrita pela task que escolhe) |
| "Preciso de cobertura" (derivado de vida e munição) | ✓ | Blackboard (escrito por um service) |
| Tempo de telegrafia, dano do ataque, raio de busca | ✗ | **Propriedades dos nós** ou Data Assets (configuração) |
| Todos os estímulos brutos da percepção | ✗ | AI Perception (o Blackboard guarda **conclusões**) |
| Nível de ameaça global, setores energizados | ✗ | **Subsistemas** (Capítulos 23, 36) |
| "A jogadora leu o memorando" | ✗ | **Estado narrativo** (Capítulo 46) |
| Posição e velocidade do próprio corpo | ✗ | O pawn (consulte direto; não duplique) |

Duas regras práticas saem da tabela:

1. **Configuração não é memória.** Um tempo de telegrafia guardado no Blackboard vira um número que qualquer um pode alterar em runtime, e some do lugar onde um designer procuraria (a árvore ou o Data Asset).
2. **Não duplique a fonte da verdade.** Copiar para o Blackboard o que já está disponível de forma barata (a posição do próprio pawn) cria duas versões que podem divergir. Copie só o que a decisão precisa **observar** (para aborts) ou o que é **conclusão** (não fato bruto).

---

## 38.3 O contrato: um escritor por chave

A disciplina do dono único (Capítulo 4) aplicada ao Blackboard: **cada chave tem exatamente um escritor**, documentado.

```text
 CONTRATO — BB_Presenca
 ┌──────────────────────┬────────────────────────────────┬──────────────────────────────┐
 │ Chave                │ Escritor (único)               │ Leitores                     │
 ├──────────────────────┼────────────────────────────────┼──────────────────────────────┤
 │ TargetActor          │ UVGAwarenessComponent          │ Caçar, Attack, AimAtTarget   │
 │ TargetVisible        │ UVGAwarenessComponent          │ decorator de Caçar           │
 │ AwarenessState       │ UVGAwarenessComponent          │ decorators de Caçar/Investig.│
 │ LastKnownLocation    │ UVGAwarenessComponent          │ Investigar                   │
 │ IsStunned            │ UVGPresenceReactionComponent   │ decorator de Recuar          │
 │                      │ (liga) / VG Clear Stun (desliga)│                             │
 │ StunDuration         │ UVGPresenceReactionComponent   │ Recuar                       │
 │ RetreatLocation      │ UVGPresenceReactionComponent   │ Recuar (Move To)             │
 │ StalkPoint           │ VG Find Stalk Point            │ Espreitar (Move To)          │
 └──────────────────────┴────────────────────────────────┴──────────────────────────────┘
```

`IsStunned` tem dois escritores (quem liga e quem desliga) — uma exceção aceitável, porque são dois lados de um mesmo ciclo e estão documentados. Se aparecer um terceiro, é sinal de que o atordoamento merece um dono próprio (o componente de reação, com um timer que desliga a chave sozinho).

O contrato vira um documento (`docs/design/blackboards.md`) e, mais importante, vira **código**: os sistemas escrevem por constantes de nome definidas num único header; os nós de BT leem por **seletores** configurados no editor.

---

## 38.4 Herança e compartilhamento

### Herança

Um Blackboard pode ter um **pai**: herda todas as chaves dele e acrescenta as próprias. O projeto usa:

```text
BB_InimigoBase           TargetActor, TargetVisible, AwarenessState, LastKnownLocation
   ├── BB_Presenca       + IsStunned, StunDuration, RetreatLocation, StalkPoint
   └── BB_Vigia          + IsStaggered, NeedsCover, CoverLocation, PatrolIndex
```

Assim, tudo que lida com percepção e consciência (o componente de consciência, a subárvore de "Investigar") funciona com **qualquer** inimigo, porque as chaves base existem em todos.

### Chaves sincronizadas por instância

Uma chave marcada como **Instance Synced** tem **o mesmo valor em todos os agentes** que usam aquele Blackboard: escrever nela num agente atualiza todos. É a forma mais simples de **conhecimento compartilhado** entre agentes do mesmo tipo:

```text
 BB_Vigia
   SquadAlertLocation : Vector   [Instance Synced]
   → um vigia que ouve um tiro escreve aqui; todos os vigias "sabem" onde investigar
```

É uma ferramenta poderosa e perigosa: é **estado global mutável** entre agentes. Use para uma ou duas informações de grupo bem definidas, com um escritor claro, e prefira os mecanismos de coordenação do Capítulo 42 (tokens, um coordenador de esquadrão) para qualquer coisa mais rica.

---

## 38.5 Acesso em C++

Há duas formas de referenciar chaves em C++, para dois contextos diferentes:

### Em sistemas (componentes): constantes de nome

Componentes que escrevem chaves conhecidas (consciência, reação) usam **constantes** declaradas num único lugar:

```cpp
// Source/Vigilia/AI/VGBlackboardKeys.h
#pragma once

#include "UObject/NameTypes.h"

/** Nomes das chaves do contrato de Blackboard (docs/design/blackboards.md). Fonte única. */
namespace VGBBKeys
{
    inline const FName TargetActor       = TEXT("TargetActor");
    inline const FName TargetVisible     = TEXT("TargetVisible");
    inline const FName AwarenessState    = TEXT("AwarenessState");
    inline const FName LastKnownLocation = TEXT("LastKnownLocation");
    inline const FName IsStunned         = TEXT("IsStunned");
    inline const FName StunDuration      = TEXT("StunDuration");
    inline const FName RetreatLocation   = TEXT("RetreatLocation");
    inline const FName IsStaggered       = TEXT("IsStaggered");
    inline const FName NeedsCover        = TEXT("NeedsCover");
    inline const FName SquadAlertLocation = TEXT("SquadAlertLocation");
}
```

Um erro de digitação numa string espalhada pelo código produz uma escrita silenciosamente ignorada (a chave não existe). Com as constantes, o nome existe uma vez — e um teste de validação (exercício) pode verificar que cada constante existe nos assets de Blackboard.

### Em nós de BT: seletores de chave

Nós de Behavior Tree não devem ter nomes de chave fixos: o designer escolhe a chave no editor, com um **`FBlackboardKeySelector`** filtrado por tipo:

```cpp
// No construtor do nó:
TargetKey.AddObjectFilter(this, GET_MEMBER_NAME_CHECKED(UBTTask_VGPresenceAttack, TargetKey), AActor::StaticClass());

// Ao inicializar com o asset (resolve o nome escolhido para o índice da chave):
void UBTTask_VGPresenceAttack::InitializeFromAsset(UBehaviorTree& Asset)
{
    Super::InitializeFromAsset(Asset);
    if (const UBlackboardData* BBAsset = GetBlackboardAsset())
    {
        TargetKey.ResolveSelectedKey(*BBAsset);
    }
}
```

Assim, o mesmo nó serve a qualquer árvore e a qualquer chave do tipo certo — a task de ataque não "sabe" que a chave se chama `TargetActor`.

> **Regra do projeto:** constantes para **escritores sistêmicos** (componentes C++ que alimentam o Blackboard); seletores para **nós de BT** (reutilizáveis, configurados por designers).

---

## Comparação com o desenvolvimento tradicional

| Blackboard | O que você conhece | Onde a analogia cai |
|---|---|---|
| Memória de trabalho tipada | Contexto de execução / mapa tipado | Observado por decorators com preempção |
| Esquema (asset) + instância | Schema + documento | Herança de esquema entre tipos de agente |
| Contrato de escrita | Ownership de campos num modelo de dados | A engine não impõe; o projeto impõe |
| Instance Synced | Estado compartilhado / cache distribuído | É global e síncrono no processo — use com parcimônia |
| Constantes de chave | Constantes de nomes de campos/tópicos | Erros de nome falham **em silêncio** |

---

## Implementação

### 1. Os assets

Crie `BB_InimigoBase` com as chaves base (o tipo de `AwarenessState` é o enum `EVGAwarenessState` — o Blackboard aceita enums refletidos), e `BB_Presenca`/`BB_Vigia` como filhos (campo *Parent*). Associe cada árvore ao seu Blackboard.

### 2. A consciência escreve

🔁 O `UVGAwarenessComponent` (Capítulo 36) passa a manter o Blackboard atualizado — **só em mudanças**, nunca a cada tick:

```cpp
// VGAwarenessComponent.cpp (trechos)
#include "AI/VGBlackboardKeys.h"
#include "AIController.h"
#include "BehaviorTree/BlackboardComponent.h"

UBlackboardComponent* UVGAwarenessComponent::GetBlackboard() const
{
    // Não-const de propósito: num const AAIController*, GetBlackboardComponent() devolve um ponteiro const.
    AAIController* Controller = Cast<AAIController>(GetOwner());
    return Controller ? Controller->GetBlackboardComponent() : nullptr;
}

void UVGAwarenessComponent::SyncBlackboard()
{
    UBlackboardComponent* BB = GetBlackboard();
    if (!BB)
    {
        return;
    }
    BB->SetValueAsObject(VGBBKeys::TargetActor, Target.Get());
    BB->SetValueAsBool(VGBBKeys::TargetVisible, bTargetVisible);
    BB->SetValueAsEnum(VGBBKeys::AwarenessState, static_cast<uint8>(State));
    BB->SetValueAsVector(VGBBKeys::LastKnownLocation, LastKnownLocation);
}
```

`SyncBlackboard` é chamado ao final de `ReceiveStimulus` e de `UpdateState` quando algo mudou. Para a `LastKnownLocation` enquanto o alvo está visível (que muda continuamente), a escrita é limitada à frequência do tick do componente (10 Hz) e só quando a posição se moveu mais que alguns centímetros — o Blackboard **notifica observadores a cada escrita com valor diferente**, e notificações por frame em várias chaves custam reavaliações desnecessárias da árvore.

### 3. A reação escreve

O `UVGPresenceReactionComponent` (Capítulo 37) escreve `IsStunned`, `StunDuration` e `RetreatLocation` ao receber dano de luz — com uma guarda: um novo estímulo de luz **estende** o atordoamento (o maior entre o restante e o novo), em vez de reiniciá-lo. E o vigia ganha o equivalente para `IsStaggered`, alimentado pelo `OnStaggered` do corpo (Capítulo 30).

### 4. O service de necessidades de combate

```cpp
// Source/Vigilia/AI/BT/BTService_VGCombatNeeds.cpp (essencial)
UBTService_VGCombatNeeds::UBTService_VGCombatNeeds()
{
    NodeName = TEXT("VG Combat Needs");
    Interval = 0.25f;
}

void UBTService_VGCombatNeeds::TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
    Super::TickNode(OwnerComp, NodeMemory, DeltaSeconds);

    const APawn* Body = OwnerComp.GetAIOwner()->GetPawn();
    const UVGHealthComponent* Health = Body ? Body->FindComponentByClass<UVGHealthComponent>() : nullptr;
    const UVGWeaponComponent* Weapons = Body ? Body->FindComponentByClass<UVGWeaponComponent>() : nullptr;
    const AVGWeapon* Weapon = Weapons ? Weapons->GetCurrentWeapon() : nullptr;

    const bool bLowHealth = Health && Health->GetHealthRatio() < LowHealthRatio;
    const bool bEmptyMagazine = Weapon && Weapon->GetAmmoInMagazine() == 0;

    // Escreve só se mudou (a escrita com valor igual não notifica, mas evitamos o trabalho).
    UBlackboardComponent* BB = OwnerComp.GetBlackboardComponent();
    const bool bNeedsCover = bLowHealth || bEmptyMagazine;
    if (BB->GetValueAsBool(NeedsCoverKey.SelectedKeyName) != bNeedsCover)
    {
        BB->SetValueAsBool(NeedsCoverKey.SelectedKeyName, bNeedsCover);
    }
}
```

O service é o **escritor único** de `NeedsCover`; o decorator do ramo de cobertura (Capítulo 37) observa a chave com abort *Lower Priority*. A regra de design "vida < 50% ou pente vazio" vive num único lugar, com o limiar (`LowHealthRatio`) como propriedade do nó.

### 5. Conhecimento de grupo (mínimo)

No `BB_Vigia`, a chave `SquadAlertLocation` (*Instance Synced*). Quando a consciência de um vigia sobe por causa de um **disparo** (ruído com tag `Gunshot`), ele escreve o local. Um decorator no ramo "Investigar" do vigia considera também essa chave: um vigia que não ouviu nada, mas cujo colega ouviu, vai investigar. É o embrião da coordenação do Capítulo 42 — com um único escritor por evento e um único significado.

---

## Decisões arquiteturais

1. **O Blackboard guarda conclusões e intenções atuais**; configuração, fatos brutos, estado global e narrativa ficam fora.
2. **Contrato de Blackboard documentado**: um escritor por chave.
3. **Herança de Blackboards** (`BB_InimigoBase` → Presença, Vigia).
4. **Instance Synced só para uma ou duas informações de grupo** bem definidas.
5. **Constantes de nome para escritores sistêmicos; seletores de chave para nós de BT.**
6. **Escrever só em mudanças**, com limite de frequência para valores contínuos.

---

## Armadilhas

- **Blackboard como depósito** de tudo que algum nó possa precisar.
- **Vários escritores para a mesma chave**, sem dono.
- **Configuração no Blackboard.**
- **Nomes de chave em strings espalhadas** — escritas ignoradas em silêncio.
- **Escrever valores contínuos a cada frame**, provocando reavaliações constantes da árvore.
- **Instance Synced como barramento de grupo** para tudo.
- **Duplicar a posição do próprio pawn** no Blackboard.

---

## Exercício

**Parte 1 — assets e contrato (1 h).** Crie os três Blackboards com herança e escreva o `docs/design/blackboards.md` com o contrato de cada chave (escritor e leitores).

**Parte 2 — escritores (1,5 h).** Implemente `VGBlackboardKeys.h`, a sincronização da consciência, a reação da Presença e o service de necessidades de combate. Verifique no Gameplay Debugger (categoria Blackboard) que as chaves mudam quando devem — e **só** quando devem.

**Parte 3 — validação (45 min).** Escreva um teste de automação (ou um comando de cheat) que carregue os assets de Blackboard do projeto e verifique que cada constante de `VGBBKeys` existe com o tipo esperado no Blackboard adequado.

**Parte 4 — grupo (45 min).** Implemente `SquadAlertLocation` e teste: um tiro perto de um vigia faz os outros investigarem o mesmo ponto.

---

## Desafio — memória com idade

Hoje, `LastKnownLocation` é um ponto; o agente não sabe **há quanto tempo** aquela informação é válida. Acrescente ao contrato uma chave `LastKnownTime` (Float, tempo de jogo) e:

1. Faça o ramo "Investigar" preferir **ruídos recentes** a uma visão antiga: se houver um ruído mais novo que a última visão, o ponto de investigação é o do ruído.
2. Faça o "Olhar ao redor" durar mais quando a informação é recente e menos quando é velha.

Pergunta para o `DEVLOG.md`: o "quão antiga é a informação" deveria estar no Blackboard (para a árvore observar) ou ser calculado sob demanda pela task? Qual escolha respeita a seção 38.2?

---

## Uso de IA

1. **Para revisar o contrato:**
   > "Aqui está o contrato de Blackboard de dois agentes (chaves, tipos, escritores, leitores) e a Behavior Tree de cada um. Aponte: chaves com mais de um escritor, chaves que guardam configuração, chaves que duplicam informação disponível no pawn, e chaves lidas por decorators sem abort adequado. [contrato + árvores]"

2. **Para decidir o que vai no Blackboard:**
   > "Para cada informação a seguir de um inimigo de shooter, diga se ela pertence ao Blackboard, a uma propriedade de nó/Data Asset, a um subsistema global ou ao próprio pawn, e por quê: alvo atual, munição restante, tempo de recarga, posição do esquadrão, ponto de cobertura escolhido, nível de dificuldade, se o alvo está visível, raio de audição."

3. **Para usar seletores em C++:**
   > "Mostre como usar FBlackboardKeySelector num nó de Behavior Tree em C++ na Unreal Engine 5 (filtros por tipo, InitializeFromAsset, ResolveSelectedKey, leitura e escrita), e explique quando preferir constantes de nome em componentes que escrevem no Blackboard."

---

## Checklist

- [ ] Sei explicar o Blackboard como memória de trabalho e seu papel na reatividade.
- [ ] Sei o que pertence e o que não pertence ao Blackboard.
- [ ] Tenho um contrato com um escritor por chave, documentado e refletido no código.
- [ ] Uso herança de Blackboards e sei quando (não) usar Instance Synced.
- [ ] Uso constantes de nome em componentes e seletores em nós.
- [ ] Escrevo no Blackboard só em mudanças.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Blackboard** (tipos de chave, herança, Instance Synced) e **Behavior Tree Node Reference** (decorators baseados em Blackboard).

---

➡️ **Próximo:** [Capítulo 39 — EQS](cap-39-eqs.md)

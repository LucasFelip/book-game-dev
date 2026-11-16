# Capítulo 34 — FSM

## Objetivo

Ao final deste capítulo você deve conseguir:

- implementar uma máquina de estado de IA com o **padrão State** — estados como objetos com entrada, atualização e saída — em vez de um `switch`;
- estruturar comportamentos em **máquinas de estado hierárquicas (HFSM)**, com transições herdadas por superestados;
- implementar o algoritmo de troca de estado numa HFSM (saída e entrada até o **ancestral comum**);
- combinar transições **por evento** e **por condição**;
- medir a **explosão de transições** e reconhecer quando uma FSM deixou de ser a ferramenta certa;
- refatorar o cérebro ingênuo do vigia (Capítulo 30) numa HFSM com investigação e busca — e registrar os limites que levarão às Behavior Trees.

---

## Contexto

Máquinas de estado já apareceram três vezes no livro: no Capítulo 4, como forma de pensar estado discreto (a lanterna); no Capítulo 19, na porta; no Capítulo 30, como o `switch` do cérebro ingênuo. Nas duas primeiras, a FSM era a ferramenta perfeita: poucos estados, transições claras, comportamento previsível. Na terceira, ela começou a doer — e o desafio do Capítulo 30 pediu para acrescentar um quinto estado ("investigar") e contar as transições.

Este capítulo faz duas coisas. Primeiro, mostra como uma FSM **bem implementada** — com o padrão State e hierarquia — vai muito mais longe que um `switch`. Segundo, leva essa FSM até o ponto em que ela, mesmo bem implementada, começa a falhar como arquitetura de IA. Os dois aprendizados importam: FSMs continuam sendo a melhor ferramenta para muita coisa em jogos (animação, armas, portas, fluxo de jogo, modos de alto nível de um agente), e saber **onde** elas param de escalar é o que justifica a Behavior Tree do Capítulo 37.

---

## 34.1 Do `switch` ao padrão State

O cérebro do Capítulo 30 tinha esta forma:

```cpp
switch (State)
{
case Idle:      /* comportamento + transições do Idle */      break;
case Telegraph: /* comportamento + transições do Telegraph */ break;
case Fire:      /* ... */                                     break;
case Cooldown:  /* ... */                                     break;
}
```

Os problemas, que você provavelmente sentiu no desafio:

- **Dados de estados diferentes vivem juntos.** `StateTime`, `Target`, `CurrentAimError` são membros do componente, usados por alguns estados e não por outros. Não fica claro quem lê o quê.
- **Entrada e saída são implícitas.** "Ao entrar em `Fire`, começar a atirar; ao sair, parar" está espalhado: o `StartFire` dentro do caso, o `StopFire` dentro de uma transição.
- **Cada caso conhece todos os outros**, porque decide para onde ir.

O **padrão State** (GoF) transforma cada estado num objeto com três operações e, opcionalmente, dados próprios:

```text
           ┌────────────────────────────┐
           │  FVGBrainState (base)      │
           │  OnEnter()                 │
           │  OnTick(Δt)                │   ← comportamento contínuo + condições de saída
           │  OnExit()                  │
           │  OnEvent(evento)           │   ← reações a eventos (atordoado, ouviu algo)
           └─────────────┬──────────────┘
          ┌──────────────┼───────────────┬──────────────────┐
          ▼              ▼               ▼                  ▼
     IdleState     TelegraphState    FireState        InvestigateState
                   (TempoNoEstado)   (StartFire na     (PontoAlvo,
                                      entrada,          TempoOlhando)
                                      StopFire na
                                      saída)
```

E uma **máquina** que conhece o estado atual e executa a troca:

```text
ChangeState(Novo):
    Atual.OnExit()
    Atual = Novo
    Atual.OnEnter()
```

Ganhos imediatos: entrada e saída explícitas (o `StopFire` mora no `OnExit` do `Fire` e **nunca** é esquecido, não importa por qual transição o estado termine), dados locais a cada estado, e cada estado pode ser lido e testado sozinho.

> 🌉 **Ponte:** é o padrão State do GoF, que você provavelmente já usou para ciclos de vida de pedidos ou documentos. A diferença em jogos é a operação `OnTick`: o estado não só reage a comandos, ele **executa comportamento contínuo** a cada frame.

---

## 34.2 Transições por evento e por condição

Há duas formas de um estado decidir que deve terminar:

- **Por condição (*polling*)** — no `OnTick`, o estado verifica algo: "faz 0,8 s que estou em `Telegraph`?", "ainda vejo o alvo?". É a forma natural para condições contínuas (Capítulo 4: contínuo → consulta).
- **Por evento** — algo acontece fora do estado e é entregue a ele: "fui atordoado", "ouvi um ruído", "o alvo morreu". É a forma natural para transições discretas que vêm de outros sistemas (Capítulo 4: discreto → evento).

A máquina entrega eventos ao estado atual (`OnEvent`), que decide se reage. Isso evita que **todo** estado precise verificar, a cada frame, "fui atordoado?".

---

## 34.3 Máquinas de estado hierárquicas

Com mais estados, aparece um padrão: **muitas transições se repetem**. Considere o vigia com sete estados:

```text
Idle, Patrol, Investigate, Search, Telegraph, Fire, Cooldown
```

- De **qualquer** estado de combate (`Telegraph`, `Fire`, `Cooldown`), "perdi o alvo de vista" leva a `Investigate`.
- De **qualquer** estado calmo ou de alerta (`Idle`, `Patrol`, `Investigate`, `Search`), "vejo o alvo" leva a `Telegraph`.
- De **qualquer** estado, "fui atordoado" interrompe e, se estava em combate, volta a `Telegraph`.

Numa FSM plana, cada uma dessas regras é **repetida** em cada estado: "vejo o alvo" aparece quatro vezes, "perdi o alvo" três. Adicionar um estado novo ao grupo de combate (por exemplo, `TakeCover`) exige lembrar de todas as regras do grupo.

A **FSM hierárquica** agrupa estados em **superestados**, e as transições comuns são declaradas **uma vez**, no superestado:

```text
                                ROOT
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                    ▼
          CALM                 ALERT               COMBAT
      ┌─────┴─────┐        ┌─────┴──────┐     ┌──────┼───────┐
      ▼           ▼        ▼            ▼     ▼      ▼       ▼
    Idle       Patrol  Investigate   Search Telegraph Fire Cooldown

  Regras no superestado (valem para todos os filhos):
    CALM   : "vejo o alvo"            → COMBAT.Telegraph
             "ouvi um ruído"          → ALERT.Investigate
    ALERT  : "vejo o alvo"            → COMBAT.Telegraph
             "terminei de procurar"   → CALM.Patrol
    COMBAT : "perdi o alvo"           → ALERT.Investigate
             "fui atordoado"          → COMBAT.Telegraph
```

Os estados-folha cuidam só do que é **seu**: `Telegraph` conta o tempo de preparação; `Fire` atira; `Cooldown` espera. As regras de contexto ficam no superestado.

### A troca de estado numa HFSM

Quando a máquina vai de `COMBAT.Fire` para `ALERT.Investigate`, quais `OnExit` e `OnEnter` executam? A regra: **sai até o ancestral comum e entra a partir dele.**

```text
 de: ROOT → COMBAT → Fire
 para: ROOT → ALERT → Investigate
 ancestral comum: ROOT

 OnExit(Fire), OnExit(COMBAT), OnEnter(ALERT), OnEnter(Investigate)
```

De `COMBAT.Telegraph` para `COMBAT.Fire`, o ancestral comum é `COMBAT`: só `Telegraph` sai e só `Fire` entra — `COMBAT` **não** sai e entra de novo. Isso permite que superestados tenham comportamento contínuo: `COMBAT.OnEnter` pode, por exemplo, disparar a fala "contato!" e ligar a lanterna do vigia uma única vez, por mais que os filhos troquem entre si.

### A ordem de avaliação

A cada frame, a máquina pergunta primeiro ao **estado-folha** e depois a cada **ancestral**, até a raiz — ou o contrário. As duas escolhas são válidas e têm efeitos diferentes:

- **Folha primeiro:** um estado específico pode "segurar" uma transição geral (por exemplo, `Fire` não aceita "perdi o alvo" até terminar a rajada).
- **Raiz primeiro:** regras gerais têm prioridade (por exemplo, "morreu" ou "atordoado" interrompem qualquer coisa).

A implementação deste capítulo usa **raiz primeiro para eventos** (interrupções gerais têm prioridade) e **folha primeiro para condições** (o estado específico decide quando terminou o que estava fazendo). Registre a escolha — ela é parte do comportamento.

---

## 34.4 A explosão de transições

Mesmo com hierarquia, FSMs têm um limite estrutural. Conte as transições do vigia:

| Modelo | Estados | Transições declaradas |
|---|:-:|:-:|
| Cérebro do Capítulo 30 (plano) | 4 | ~6 |
| Plano com `Investigate` e `Search` (desafio do Cap. 30) | 6 | ~14 |
| Plano com `Patrol` e `TakeCover` | 8 | ~24 |
| **Hierárquico** com os mesmos 8 | 8 folhas + 3 super | ~13 |

A hierarquia corta o crescimento, mas não o elimina. E os comportamentos que o Vigia ainda precisa — **escolher entre** atirar, buscar cobertura, recarregar, avançar, recuar, conforme munição, vida, distância e o que os colegas estão fazendo — não são "estados" no sentido de modos exclusivos: são **escolhas com prioridades**, reavaliadas o tempo todo. Expressá-las como estados com transições explícitas força o designer a pensar em **todas as combinações** de "estou aqui e acontece aquilo".

Os sinais de que uma FSM chegou ao limite:

1. Transições com condições compostas longas ("se vejo o alvo **e** tenho munição **e** não estou atordoado **e** nenhum colega está atirando...").
2. Estados que existem só para "decidir para onde ir" (estados de passagem).
3. Medo de adicionar um estado, porque não se sabe quais transições ele quebra.
4. O mesmo comportamento (ex.: "mover até um ponto") duplicado em vários estados.

A Behavior Tree (Capítulo 37) ataca exatamente esses sinais: em vez de "estados e transições", **prioridades reavaliadas** — "se posso fazer A, faço A; senão, se posso fazer B, faço B" — com comportamentos reutilizáveis como folhas.

---

## 34.5 Onde FSMs continuam sendo a melhor escolha

FSMs **não** são uma ferramenta "ultrapassada". Elas são a melhor escolha quando os estados são **modos exclusivos** com poucas transições bem definidas:

- **Animação** — a máquina de estados do Animation Blueprint (Capítulo 53) é uma FSM: idle, andando, correndo, pulando, caindo.
- **Objetos de gameplay** — a porta (Capítulo 19), a arma (Capítulo 20), o sinalizador (Capítulo 28).
- **Fluxo de jogo** — menu, carregando, jogando, pausado, morto (Capítulo 16, a pilha de modos é uma variação).
- **Modos de alto nível de um agente** — "dormente / caçando / recuando" da Presença, com uma Behavior Tree diferente dentro de cada modo (Capítulo 42).
- **Jogos inteiros**, quando os agentes são simples.

Um exemplo clássico e publicamente documentado ilustra isso.

---

## Estudo de caso: personalidade a partir de estados simples

> **Pergunta:** comportamentos memoráveis exigem arquiteturas complexas?

**[FATO PÚBLICO]** Em *Pac-Man* (Namco, 1980), os fantasmas alternam entre modos de comportamento — perseguir o jogador, dispersar para os cantos do labirinto e fugir (depois que o jogador come uma pílula de energia) —, e cada fantasma tem uma regra própria para escolher seu alvo no modo de perseguição, o que dá a cada um uma "personalidade" distinta. Esse comportamento foi documentado em detalhe por análises da comunidade de jogadores ao longo dos anos.

**[INFERÊNCIA]** O caso é instrutivo para este capítulo por dois motivos. Primeiro: **uma FSM pequena, com modos bem escolhidos e alternados por tempo, produz comportamento percebido como rico** — jogadores atribuem intenção ("ele está me cercando") a regras muito simples. Segundo: a **variedade** vem de **parâmetros e regras de alvo diferentes sobre a mesma estrutura**, não de máquinas diferentes — exatamente o princípio de dados sobre um pipeline estável (Capítulo 20).

**Lição:** **a complexidade da arquitetura deve seguir a complexidade das decisões, não a ambição do projeto.** Se os modos são poucos e exclusivos, uma FSM é imbatível em clareza. Quando as decisões viram prioridades que se sobrepõem, troque de ferramenta.

---

## Comparação com o desenvolvimento tradicional

| FSM de IA | O que você conhece | Onde a analogia cai |
|---|---|---|
| Padrão State | State pattern em ciclos de vida de entidade | Estados executam comportamento contínuo (`OnTick`) |
| HFSM | Statecharts (Harel), máquinas de estado em workflow engines | Avaliada a cada frame, com orçamento de microssegundos |
| Ancestral comum | Saída/entrada aninhada de escopos | Determina efeitos audiovisuais que o jogador percebe |
| Explosão de transições | Explosão combinatória de casos em regras de negócio | A resposta da indústria não é "mais regras", é outra arquitetura (BT) |

> 🌉 **Ponte:** se você já trabalhou com **statecharts** (Harel) ou com máquinas de estado de bibliotecas como XState ou Spring Statemachine, a HFSM deste capítulo é o mesmo conceito — estados aninhados, transições herdadas, entrada e saída até o ancestral comum.

---

## Implementação: o cérebro do vigia como HFSM

🔁 **Refatoração do Capítulo 30.** O `UVGSimpleCombatBrain` é substituído por `UVGGuardBrainComponent`, com estados como objetos C++ comuns (não `UObject`s — o "Mundo 2" do Capítulo 11: posse única com `TUniquePtr`, sem garbage collector, sem reflexão). A percepção continua ingênua (trace direto) até o Capítulo 36; o movimento usa `MoveToLocation` do controller, que exige navegação (Capítulo 35) — para testar agora, coloque um **`NavMeshBoundsVolume`** cobrindo o Galpão (a navegação é explicada no próximo capítulo).

### 1. A máquina genérica (pequena)

```cpp
// Source/Vigilia/AI/VGHierarchicalStateMachine.h
#pragma once

#include "CoreMinimal.h"

/** Evento entregue à máquina (o "o que aconteceu"). */
enum class EVGBrainEvent : uint8
{
    Staggered,
    HeardNoise,
    TargetDied
};

/**
 * Estado de uma HFSM. Objetos C++ comuns (sem UObject): posse única pela máquina.
 * OnTick e OnEvent devolvem o estado de destino, ou nullptr para "não trocar".
 */
class FVGState
{
public:
    explicit FVGState(const TCHAR* InName, FVGState* InParent = nullptr) : Name(InName), Parent(InParent) {}
    virtual ~FVGState() = default;

    virtual void OnEnter() {}
    virtual void OnExit() {}
    virtual FVGState* OnTick(float DeltaTime) { return nullptr; }
    virtual FVGState* OnEvent(EVGBrainEvent Event) { return nullptr; }

    FVGState* GetParent() const { return Parent; }
    const TCHAR* GetName() const { return Name; }
    int32 Depth() const { return Parent ? Parent->Depth() + 1 : 0; }

private:
    const TCHAR* Name;
    FVGState* Parent;
};

/** Máquina hierárquica: troca saindo e entrando até o ancestral comum. */
class FVGHierarchicalStateMachine
{
public:
    /** O estado inicial deve ser uma folha; entra em toda a cadeia de ancestrais. */
    void Start(FVGState* Initial);

    /** Condições: folha primeiro, depois ancestrais (o específico decide quando terminou). */
    void Tick(float DeltaTime);

    /** Eventos: raiz primeiro, depois descendentes (interrupções gerais têm prioridade). */
    void Dispatch(EVGBrainEvent Event);

    void ChangeState(FVGState* Target);

    FVGState* GetCurrent() const { return Current; }
    FString DescribePath() const;

private:
    static FVGState* CommonAncestor(FVGState* A, FVGState* B);

    FVGState* Current = nullptr;
    bool bChanging = false;
};
```

```cpp
// Source/Vigilia/AI/VGHierarchicalStateMachine.cpp
#include "AI/VGHierarchicalStateMachine.h"

void FVGHierarchicalStateMachine::Start(FVGState* Initial)
{
    TArray<FVGState*> Chain;
    for (FVGState* S = Initial; S; S = S->GetParent()) { Chain.Insert(S, 0); } // raiz → folha
    for (FVGState* S : Chain) { S->OnEnter(); }
    Current = Initial;
}

FVGState* FVGHierarchicalStateMachine::CommonAncestor(FVGState* A, FVGState* B)
{
    while (A && B && A->Depth() > B->Depth()) { A = A->GetParent(); }
    while (A && B && B->Depth() > A->Depth()) { B = B->GetParent(); }
    while (A != B) { A = A ? A->GetParent() : nullptr; B = B ? B->GetParent() : nullptr; }
    return A;
}

void FVGHierarchicalStateMachine::ChangeState(FVGState* Target)
{
    if (!Target || Target == Current || bChanging)
    {
        return;
    }
    bChanging = true; // um OnEnter/OnExit que pede outra troca é ignorado (reentrância — Cap. 4)

    FVGState* Ancestor = CommonAncestor(Current, Target);

    // Sai da folha atual até (sem incluir) o ancestral comum.
    for (FVGState* S = Current; S && S != Ancestor; S = S->GetParent()) { S->OnExit(); }

    // Entra do ancestral comum (sem incluir) até a folha de destino.
    TArray<FVGState*> Enter;
    for (FVGState* S = Target; S && S != Ancestor; S = S->GetParent()) { Enter.Insert(S, 0); }
    Current = Target;
    for (FVGState* S : Enter) { S->OnEnter(); }

    bChanging = false;
}

void FVGHierarchicalStateMachine::Tick(float DeltaTime)
{
    for (FVGState* S = Current; S; S = S->GetParent())
    {
        if (FVGState* Next = S->OnTick(DeltaTime))
        {
            ChangeState(Next);
            return; // uma transição por frame
        }
    }
}

void FVGHierarchicalStateMachine::Dispatch(EVGBrainEvent Event)
{
    TArray<FVGState*> Chain;
    for (FVGState* S = Current; S; S = S->GetParent()) { Chain.Insert(S, 0); } // raiz → folha
    for (FVGState* S : Chain)
    {
        if (FVGState* Next = S->OnEvent(Event))
        {
            ChangeState(Next);
            return;
        }
    }
}

FString FVGHierarchicalStateMachine::DescribePath() const
{
    FString Path;
    for (FVGState* S = Current; S; S = S->GetParent())
    {
        Path = Path.IsEmpty() ? FString(S->GetName()) : FString(S->GetName()) + TEXT(".") + Path;
    }
    return Path;
}
```

A máquina inteira tem ~70 linhas, sem dependência de engine além de contêineres. Ela é **genérica** de propósito — há pelo menos dois usos concretos à vista (o vigia agora; os modos de alto nível da Presença no Capítulo 42), o que satisfaz a regra do "terceiro caso" do Capítulo 6 de forma aceitável para uma peça tão pequena. (Guarde essa previsão: o Capítulo 42 confere se esses usos se confirmaram, e eles não se confirmam.)

### 2. Os estados do vigia

```cpp
// Source/Vigilia/AI/VGGuardBrainComponent.cpp (trechos principais)
#include "AI/VGGuardBrainComponent.h"

#include "AI/VGEnemyCharacter.h"
#include "AI/VGHierarchicalStateMachine.h"
#include "AIController.h"
#include "Combat/VGWeapon.h"
#include "Combat/VGWeaponComponent.h"

namespace VGGuardStates
{
    /** Base com acesso ao "contexto" (o componente do cérebro). */
    class FGuardState : public FVGState
    {
    public:
        FGuardState(const TCHAR* Name, UVGGuardBrainComponent& InBrain, FVGState* Parent = nullptr)
            : FVGState(Name, Parent), Brain(InBrain) {}
    protected:
        UVGGuardBrainComponent& Brain;
    };

    // ---- Superestados ---------------------------------------------------------
    class FCalm : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual FVGState* OnTick(float) override
        {
            return Brain.SeesTarget() ? Brain.States.Telegraph.Get() : nullptr;   // vejo → combate
        }
        virtual FVGState* OnEvent(EVGBrainEvent Event) override
        {
            return Event == EVGBrainEvent::HeardNoise ? Brain.States.Investigate.Get() : nullptr;
        }
    };

    class FAlert : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Brain.PresentState(TEXT("Alert")); }   // "quem está aí?"
        virtual FVGState* OnTick(float) override
        {
            return Brain.SeesTarget() ? Brain.States.Telegraph.Get() : nullptr;
        }
    };

    class FCombat : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Brain.PresentState(TEXT("Combat")); Brain.ResetAimError(); } // "contato!"
        virtual void OnExit() override  { Brain.StopFiring(); }
        virtual FVGState* OnTick(float) override
        {
            return Brain.SeesTarget() ? nullptr : Brain.States.Investigate.Get(); // perdi → investigar
        }
        virtual FVGState* OnEvent(EVGBrainEvent Event) override
        {
            return Event == EVGBrainEvent::Staggered ? Brain.States.Telegraph.Get() : nullptr;
        }
    };

    // ---- Folhas ----------------------------------------------------------------
    class FIdle : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
    };

    class FInvestigate : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Brain.MoveTo(Brain.GetLastKnownLocation()); Elapsed = 0.0f; }
        virtual void OnExit() override  { Brain.StopMovement(); }
        virtual FVGState* OnTick(float DeltaTime) override
        {
            Elapsed += DeltaTime;
            const bool bArrived = Brain.HasReachedMoveTarget();
            return (bArrived || Elapsed > 8.0f) ? Brain.States.Search.Get() : nullptr;
        }
    private:
        float Elapsed = 0.0f;
    };

    class FSearch : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Elapsed = 0.0f; }
        virtual FVGState* OnTick(float DeltaTime) override
        {
            Elapsed += DeltaTime;
            Brain.LookAround(DeltaTime);  // gira devagar, "procurando"
            return Elapsed > 4.0f ? Brain.States.Idle.Get() : nullptr; // desiste: volta a calmo
        }
    private:
        float Elapsed = 0.0f;
    };

    class FTelegraph : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Elapsed = 0.0f; Brain.PresentState(TEXT("Telegraph")); }
        virtual FVGState* OnTick(float DeltaTime) override
        {
            Elapsed += DeltaTime;
            Brain.AimAtTarget(DeltaTime);
            return (Elapsed >= Brain.TelegraphTime && !Brain.IsStaggered()) ? Brain.States.Fire.Get() : nullptr;
        }
    private:
        float Elapsed = 0.0f;
    };

    class FFire : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Elapsed = 0.0f; Brain.StartFiring(); }
        virtual void OnExit() override  { Brain.StopFiring(); } // NUNCA esquecido, qualquer que seja a saída
        virtual FVGState* OnTick(float DeltaTime) override
        {
            Elapsed += DeltaTime;
            Brain.AimAtTarget(DeltaTime);
            return Elapsed >= Brain.BurstDuration ? Brain.States.Cooldown.Get() : nullptr;
        }
    private:
        float Elapsed = 0.0f;
    };

    class FCooldown : public FGuardState
    {
    public:
        using FGuardState::FGuardState;
        virtual void OnEnter() override { Elapsed = 0.0f; }
        virtual FVGState* OnTick(float DeltaTime) override
        {
            Elapsed += DeltaTime;
            return Elapsed >= Brain.CooldownTime ? Brain.States.Telegraph.Get() : nullptr;
        }
    private:
        float Elapsed = 0.0f;
    };
}

void UVGGuardBrainComponent::BeginPlay()
{
    Super::BeginPlay();
    using namespace VGGuardStates;

    // A árvore de estados: superestados primeiro, folhas apontando para eles.
    States.Calm      = MakeUnique<FCalm>(TEXT("Calm"), *this);
    States.Alert     = MakeUnique<FAlert>(TEXT("Alert"), *this);
    States.Combat    = MakeUnique<FCombat>(TEXT("Combat"), *this);
    States.Idle      = MakeUnique<FIdle>(TEXT("Idle"), *this, States.Calm.Get());
    States.Investigate = MakeUnique<FInvestigate>(TEXT("Investigate"), *this, States.Alert.Get());
    States.Search    = MakeUnique<FSearch>(TEXT("Search"), *this, States.Alert.Get());
    States.Telegraph = MakeUnique<FTelegraph>(TEXT("Telegraph"), *this, States.Combat.Get());
    States.Fire      = MakeUnique<FFire>(TEXT("Fire"), *this, States.Combat.Get());
    States.Cooldown  = MakeUnique<FCooldown>(TEXT("Cooldown"), *this, States.Combat.Get());

    Machine.Start(States.Idle.Get());
    // ... inscrições: OnStaggered → Machine.Dispatch(Staggered), etc.
}

void UVGGuardBrainComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                           FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    UpdatePerception(); // ainda ingênua: trace direto (Cap. 36 substitui), atualiza LastKnownLocation
    Machine.Tick(DeltaTime);
    UE_VLOG(GetOwner(), LogVigilia, Verbose, TEXT("Guard: %s"), *Machine.DescribePath()); // Visual Logger
}
```

O header do componente declara um struct `FGuardStates` com os `TUniquePtr<FVGState>` de cada estado, a `FVGHierarchicalStateMachine`, os parâmetros editáveis (`TelegraphTime`, `BurstDuration`, `CooldownTime` e os de mira do Capítulo 30) e as funções de "ação" usadas pelos estados (`SeesTarget`, `MoveTo`, `StopMovement`, `HasReachedMoveTarget`, `AimAtTarget`, `StartFiring`, `StopFiring`, `LookAround`, `PresentState`, `ResetAimError`, `GetLastKnownLocation`, `IsStaggered`).

### Explicação das decisões

- **Estados como objetos C++ comuns** com `TUniquePtr`: posse única, destruição automática com o componente, nenhum custo de `UObject`. Os estados não aparecem no editor — e não precisam: são lógica, não conteúdo. Os **parâmetros** (tempos, mira) continuam `UPROPERTY` no componente.
- **O componente é o contexto**: os estados chamam funções de ação dele (`MoveTo`, `StartFiring`...). Os estados decidem **o quê**; o componente sabe **como** (usando o controller, a arma, a navegação). Quando a Behavior Tree chegar, essas mesmas ações viram **tasks**.
- **Saídas garantem limpeza**: `StopFiring` está no `OnExit` de `FFire` **e** de `FCombat`. Não importa como o combate termine — perdeu o alvo, foi atordoado, morreu —, o vigia para de atirar.
- **Investigação e busca** finalmente existem: ao perder o alvo, o vigia vai até a última posição conhecida, procura olhando em volta e desiste. É o "falível" do estudo de caso de Outlast (Capítulo 33).
- **`UE_VLOG`** registra o caminho de estados no Visual Logger: dá para voltar no tempo e ver, frame a frame, em que estado cada vigia estava.
- **Um transição por frame** e proteção contra trocas reentrantes: um `OnEnter` que pedisse outra troca imediatamente criaria cadeias difíceis de depurar.

### O que ainda dói

Anote no `DEVLOG.md`, depois de jogar com a HFSM:

1. **"Ouvi um ruído" não existe de verdade** — `HeardNoise` só é despachado se alguém despachar. Não há audição (Capítulo 36).
2. **`SeesTarget` continua um trace direto** e "esquece" instantaneamente; a memória é só `LastKnownLocation`.
3. **Não há cobertura.** Adicionar `TakeCover` exige decidir: é filho de `Combat`? Quando ele tem prioridade sobre `Fire`? E se a cobertura estiver longe? As respostas são **prioridades**, não transições — o sinal da seção 34.4.
4. **A Presença não cabe nesta estrutura** sem duplicá-la: os estados dela são outros, mas as ações (mover, investigar, procurar) são as mesmas. Em uma Behavior Tree, ações são folhas reutilizáveis.

---

## Decisões arquiteturais

1. **FSMs com o padrão State**: entrada, atualização, saída e eventos por estado; dados locais.
2. **HFSM para agrupar transições comuns**; troca até o ancestral comum.
3. **Eventos da raiz para a folha; condições da folha para a raiz**; uma transição por frame.
4. **Estados como objetos C++ comuns** (sem `UObject`); parâmetros como `UPROPERTY` no componente.
5. **Ações no contexto (componente), decisões nos estados** — preparando a migração para tasks de BT.
6. **FSM continua sendo a escolha para modos exclusivos**: animação, objetos, fluxo de jogo, modos de alto nível de agentes.
7. **O vigia sai da HFSM no Capítulo 37**; ela fica reservada aos modos de alto nível da Presença, uma previsão que o Capítulo 42 desmente (lá, um `switch` basta).

---

## Armadilhas

- **`switch` crescente** como arquitetura de IA.
- **Limpeza em transições** em vez de no `OnExit` — algum caminho esquece.
- **Transições duplicadas** em vários estados em vez de no superestado.
- **Estados de passagem** que só decidem para onde ir.
- **Trocas de estado reentrantes** dentro de `OnEnter`/`OnExit`.
- **Usar FSM para escolhas com prioridades que se sobrepõem.**
- **Abandonar FSMs onde elas são ótimas** (animação, objetos, fluxo).

---

## Exercício

**Parte 1 — a máquina (1,5 h).** Implemente `FVGHierarchicalStateMachine` e escreva um teste de automação que monte uma pequena hierarquia de estados de teste (que registram num array a ordem das chamadas) e verifique a sequência de `OnExit`/`OnEnter` para três trocas: entre irmãos, entre primos e para o próprio superestado.

**Parte 2 — o vigia (2 h).** Implemente o `UVGGuardBrainComponent` com os nove estados, substitua o cérebro ingênuo nos vigias do Galpão e coloque um `NavMeshBoundsVolume`. Teste: atirar e se esconder atrás de uma caixa (o vigia investiga e procura), voltar à vista durante a busca (ele volta ao combate).

**Parte 3 — contar (30 min).** Desenhe o diagrama de estados completo e conte as transições declaradas. Compare com a versão plana que você teria escrito.

**Parte 4 — Visual Logger (30 min).** Grave uma sessão e reconstrua, pela linha do tempo, a história de um vigia: quando viu, quando perdeu, onde investigou, quando desistiu.

---

## Desafio — o estado que não cabe

Tente adicionar **`TakeCover`** à HFSM com estas regras de design: "ao ser atingido com menos de 50% de vida, ou ao ficar sem munição no pente, o vigia procura a cobertura mais próxima que bloqueie a linha de visão da jogadora, recarrega lá e volta ao combate; se não houver cobertura em 8 m, continua atirando".

Implemente o que conseguir (a escolha do ponto de cobertura pode ser ingênua: um conjunto de `AVGSpawnPoint` com tag `Cover`, escolhido pelo mais próximo que bloqueia o trace da jogadora). Depois, responda no `DEVLOG.md`:

1. Onde ficou a regra "vida < 50% ou sem munição"? No `FCombat`? No `FFire`? Nas duas?
2. O que acontece se a jogadora flanquear o vigia enquanto ele está na cobertura? Que transição falta?
3. Quantas condições compostas você escreveu?

Guarde as respostas: o Capítulo 37 vai reescrever exatamente este comportamento como uma Behavior Tree, e o Capítulo 39 vai substituir a escolha ingênua de cobertura por uma consulta EQS.

---

## Uso de IA

1. **Para validar a HFSM:**
   > "Revise esta implementação de máquina de estados hierárquica em C++: cálculo do ancestral comum, ordem de OnExit/OnEnter, avaliação de condições da folha para a raiz e de eventos da raiz para a folha, proteção contra trocas reentrantes. Construa um caso de teste que exponha um bug, se houver. [código]"

2. **Para modelar comportamentos:**
   > "Modele o comportamento de um guarda de jogo furtivo (patrulhar, desconfiar, investigar ruído, procurar, combater, buscar cobertura, chamar reforços) como uma HFSM. Indique superestados, folhas, transições em cada nível, e aponte quais regras ficariam melhores como prioridades numa Behavior Tree."

3. **Para decidir a ferramenta:**
   > "Dê critérios objetivos para decidir entre FSM, HFSM, Behavior Tree e Utility AI para um agente de jogo, com exemplos de agentes em que cada uma é a melhor escolha e sinais de que a escolha atual deixou de escalar."

---

## Checklist

- [ ] Sei implementar uma FSM com o padrão State (entrada, atualização, saída, eventos).
- [ ] Sei estruturar uma HFSM com transições herdadas e trocar até o ancestral comum.
- [ ] Sei escolher a ordem de avaliação de eventos e condições.
- [ ] Sei reconhecer a explosão de transições e os sinais de que a FSM chegou ao limite.
- [ ] Sei onde FSMs continuam sendo a melhor ferramenta.
- [ ] Refatorei o vigia para uma HFSM com investigação e busca, e registrei o que ainda dói.

---

## Para ir além

- **Robert Nystrom, *Game Programming Patterns*, capítulo "State"** — inclui FSMs hierárquicas e autômatos com pilha.
- **David Harel, *Statecharts: A Visual Formalism for Complex Systems*** (1987) — o artigo original sobre estados hierárquicos.
- **Ian Millington, *AI for Games*** — seções sobre máquinas de estado e máquinas hierárquicas.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **StateTree**, a alternativa moderna da Epic que combina máquinas de estado hierárquicas com seleção por condições.

---

➡️ **Próximo:** [Capítulo 35 — Navigation](cap-35-navigation.md)

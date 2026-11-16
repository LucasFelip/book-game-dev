# Capítulo 15 — Collision e Physics

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir as duas famílias de "física" num jogo: **consultas** (traces, sweeps, overlaps) e **simulação** (corpos rígidos);
- configurar colisão com **object types**, **trace channels**, **respostas** (Ignore, Overlap, Block) e **presets**, prevendo o resultado da interação entre dois objetos;
- usar **eventos de overlap e de hit** corretamente — e saber o que eles custam;
- fazer **line traces e sweeps** em C++, interpretar um `FHitResult` e depurar visualmente;
- simular corpos físicos com massa, amortecimento, **materiais físicos**, impulsos e forças;
- entender a relação entre o personagem (cinemático) e objetos simulados;
- criar o `AVGEventTrigger` — o gatilho de eventos roteirizados — e o canal de interação que o Capítulo 19 vai usar;
- **concluir o Projeto 1**.

---

## Contexto

No primeiro playtest do Capítulo 14, você andou pelo Pátio e — se o grey-box foi feito com as formas básicas da engine — não atravessou as paredes. Isso não foi acidente: as malhas de `/Engine/BasicShapes/` vêm com colisão configurada, e o `CharacterMovementComponent` testa colisão a cada passo. Funcionou porque alguém configurou. Agora é a sua vez de configurar — e de entender.

"Física", em jogos, é uma palavra que cobre duas coisas muito diferentes, e confundi-las é a origem de muitos problemas:

- **Consultas espaciais** — perguntas sobre a geometria do mundo: "há algo entre a câmera e esta porta?", "o que está à minha frente a até 2 metros?", "a jogadora está dentro desta sala?". Não movem nada. São a base de interação, armas hitscan, percepção da IA, câmera, spawn seguro.
- **Simulação** — a engine calcula como objetos se movem sob forças, gravidade e colisões: uma caixa empurrada que cai da escada, um corpo em ragdoll, uma lâmpada pendurada que balança.

A grande maioria da "física" de um jogo como a Vigília é **consulta**. Simulação é usada com parcimônia, onde o jogador percebe e se beneficia. GTA IV, como veremos no estudo de caso, é um exemplo famoso de jogo que fez o contrário — e por isso é uma referência tão interessante.

---

## 15.1 Formas de colisão

Para colidir, um objeto precisa de uma **forma de colisão**. A Unreal distingue:

- **Colisão simples** — primitivas (caixas, esferas, cápsulas) e cascos convexos (*convex hulls*) associados a uma malha. Barata de testar. É o que a simulação física usa.
- **Colisão complexa** — os triângulos da própria malha renderizada. Precisa, mas cara. Usada em consultas específicas que pedem precisão (`bTraceComplex`), raramente em simulação.

Toda malha importada pode ter colisão simples gerada ou autorada no editor de Static Mesh. Uma regra de produção: **a colisão simples deve ser simples de verdade.** Uma estátua com 50.000 triângulos pode ter uma cápsula como colisão. Ninguém vai notar — e o personagem não vai tropeçar em dobras invisíveis do manto da estátua.

O personagem usa uma **cápsula** (Capítulo 10): é a forma que desliza melhor por cantos, escadas e rampas, e é a razão pela qual personagens "escorregam" levemente ao encostar numa quina em vez de travar.

---

## 15.2 Canais, tipos e respostas

A configuração de colisão da Unreal parece intimidante no painel *Collision* de um componente. Ela se organiza em três ideias.

### Object Type

Todo componente com colisão **é** de um tipo de objeto (*object type*): `WorldStatic` (paredes, chão), `WorldDynamic` (objetos que se movem, portas), `Pawn` (personagens), `PhysicsBody` (corpos simulados), `Vehicle`, `Destructible`. O projeto pode criar tipos próprios.

### Trace Channels

Além de tipos de objeto, há **canais de consulta** (*trace channels*), usados por traces e sweeps para perguntar "quem bloqueia **esta** consulta?". A engine vem com `Visibility` (o que bloqueia a visão) e `Camera` (o que bloqueia a câmera). O projeto pode criar canais próprios — e a Vigília vai criar o canal `Interaction` neste capítulo.

### Respostas

Cada componente declara, **para cada tipo de objeto e cada canal**, como **ele** responde:

- **Ignore** — não interage.
- **Overlap** — detecta a sobreposição, mas não bloqueia (atravessa e avisa).
- **Block** — bloqueia.

### Como duas respostas se combinam

A interação entre **dois** objetos depende das respostas de **ambos**, e o resultado é a **menos restritiva** das duas:

```text
                         B responde a A com:
                    Ignore      Overlap      Block
A responde   Ignore  Ignore      Ignore       Ignore
a B com:    Overlap  Ignore      Overlap      Overlap
              Block  Ignore      Overlap      Block
```

Para dois objetos se bloquearem, **ambos** precisam bloquear o tipo do outro. Se um deles diz Overlap, eles se sobrepõem. Se um deles diz Ignore, nada acontece.

Exemplo: o volume de um trigger (tipo `WorldDynamic`, responde **Overlap** a `Pawn`) e a cápsula da jogadora (tipo `Pawn`, responde **Block** a `WorldDynamic`). Resultado: **Overlap** — a jogadora atravessa o volume e o evento de overlap dispara. É exatamente o que um trigger precisa.

### Collision Enabled

Cada componente também diz **em que sistemas** participa:

| Collision Enabled | Consultas (traces, overlaps) | Simulação física |
|---|:-:|:-:|
| `No Collision` | — | — |
| `Query Only` | ✓ | — |
| `Physics Only` | — | ✓ |
| `Query and Physics` | ✓ | ✓ |

Desligar a participação em sistemas que um objeto não usa é uma otimização real: um elemento decorativo distante pode ser `No Collision`; um volume de trigger é `Query Only`.

### Presets

Configurar dezenas de respostas por componente seria insustentável. **Presets** (*collision profiles*) agrupam tipo, `Collision Enabled` e respostas com um nome: `BlockAll`, `OverlapAllDynamic`, `Pawn`, `Trigger`, `PhysicsActor`, `NoCollision`... O projeto pode criar presets próprios em *Project Settings → Collision*. **Use presets por padrão; configuração customizada por componente só quando necessário** — e, se a mesma customização se repetir, ela vira um preset.

> 🌉 **Ponte:** a matriz de respostas é um **controle de acesso por pares** — como regras de *firewall* entre zonas, ou políticas de rede entre *namespaces* no Kubernetes, em que o tráfego entre dois *pods* depende das políticas de ambos os lados. Presets são os *security groups* nomeados.

---

## 15.3 Eventos: overlap e hit

### Overlap

Quando dois componentes passam a se sobrepor (resposta resultante **Overlap**), cada um pode disparar eventos:

- `OnComponentBeginOverlap` / `OnComponentEndOverlap` (no componente);
- `NotifyActorBeginOverlap` / `NotifyActorEndOverlap` (no ator, sobrescrevíveis);
- `Event ActorBeginOverlap` em Blueprint.

Para que os eventos disparem, **ambos** os componentes precisam ter **Generate Overlap Events** habilitado. Esquecer isso num dos lados é a causa número um de "meu trigger não funciona".

Overlaps **não são gratuitos**: a cada vez que um componente com overlaps habilitados se move, a engine atualiza o conjunto de sobreposições dele. Centenas de objetos móveis com overlaps habilitados (e sem necessidade) custam tempo de game thread. **Habilite overlaps só onde eles são usados.**

### Hit

Quando um movimento é **bloqueado**, há um **hit**:

- Para movimentos com **sweep** (Capítulo 8, `SetActorLocation(..., bSweep=true)`), e para o movimento do personagem, o hit aparece no `FHitResult` retornado e nos eventos `OnComponentHit` / `NotifyHit`.
- Para **corpos simulados**, os eventos de hit exigem habilitar **Simulation Generates Hit Events** no componente — e podem disparar muitas vezes por segundo enquanto o corpo estiver em contato com algo.

---

## 15.4 Traces e sweeps

Um **line trace** (ou *raycast*) é a consulta espacial mais usada em jogos: uma linha entre dois pontos, perguntando "o que essa linha atinge primeiro?".

```cpp
FHitResult Hit;
const FVector Start = Camera->GetComponentLocation();
const FVector End = Start + Camera->GetForwardVector() * 250.0f; // 2,5 m à frente dos olhos

FCollisionQueryParams Params(SCENE_QUERY_STAT(VGInteractionTrace), /*bTraceComplex=*/false);
Params.AddIgnoredActor(this); // não acertar a própria jogadora

const bool bHit = GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params);
if (bHit)
{
    AActor* HitActor = Hit.GetActor();
    // Hit.ImpactPoint, Hit.ImpactNormal, Hit.Distance, Hit.GetComponent(), Hit.PhysMaterial...
}
```

As variações que você vai usar:

| Consulta | Pergunta |
|---|---|
| `LineTraceSingleByChannel` | O **primeiro** bloqueio ao longo da linha, num canal |
| `LineTraceMultiByChannel` | Todos os **overlaps** até o primeiro bloqueio (útil para penetração — Capítulo 27) |
| `LineTraceSingleByObjectType` | O primeiro objeto de certos **tipos** |
| `SweepSingleByChannel` | Como o trace, mas movendo uma **forma** (esfera, cápsula, caixa) — "uma bola de 20 cm passaria daqui até ali?" |
| `OverlapMultiByChannel` | Quem está **dentro** de uma forma, agora |

### O `FHitResult`

Os campos mais usados:

- `bBlockingHit` — houve bloqueio;
- `ImpactPoint` — onde a consulta tocou a superfície;
- `ImpactNormal` — a direção "para fora" da superfície no ponto de contato (essencial para decals, ricochetes e para orientar efeitos — Capítulo 54);
- `Location` — no sweep, onde o **centro** da forma estava no momento do contato (diferente de `ImpactPoint`);
- `Distance`, `Time` (fração do caminho);
- `GetActor()`, `GetComponent()`, `BoneName` (em malhas esqueléticas — tiro na cabeça, Capítulo 27);
- `PhysMaterial` — o material físico atingido (exige `Params.bReturnPhysicalMaterial = true`).

### Depurar consultas

Consultas são invisíveis. Torne-as visíveis:

```cpp
#include "DrawDebugHelpers.h"

DrawDebugLine(GetWorld(), Start, bHit ? Hit.ImpactPoint : End, bHit ? FColor::Green : FColor::Red, false, 1.0f);
if (bHit)
{
    DrawDebugPoint(GetWorld(), Hit.ImpactPoint, 10.0f, FColor::Yellow, false, 1.0f);
}
```

E, no console, `show collision` mostra as formas de colisão de todo o nível — o jeito mais rápido de descobrir por que a jogadora "bate em algo invisível".

> 🌉 **Ponte:** um trace é uma **consulta indexada** a um banco espacial. A engine mantém estruturas de aceleração (como árvores de volumes delimitadores) para que a pergunta "o que esta linha atinge?" não teste todos os objetos do mundo — como um índice evita um *full scan*.
>
> 🧱 **Onde a ponte cai:** o "banco" muda **todo frame**, e o custo de uma consulta depende da geometria (uma linha longa atravessando uma área densa testa muito mais que uma curta). Traces são baratos individualmente; centenas por frame (IA, armas automáticas, percepção) precisam de orçamento.

---

## 15.5 Simulação física

Marque **Simulate Physics** num componente primitivo com colisão simples, e a engine passa a calcular o movimento dele: gravidade, colisões, atrito, quiques. Na Unreal 5, a simulação é feita pela **Chaos**, a engine física da Epic.

### As propriedades que importam

- **Massa** (em kg) — por padrão calculada a partir do volume da colisão e da densidade do material; pode ser sobrescrita. Massas absurdas (uma caixa de 1 g, um barril de 5 toneladas) produzem comportamentos estranhos.
- **Amortecimento linear e angular** (*damping*) — perda de velocidade ao longo do tempo; sem ele, objetos rolam para sempre.
- **Material físico** (`UPhysicalMaterial`) — **atrito**, **restituição** (quanto quica), **densidade** e um **tipo de superfície** (*surface type*).
- **Sleep** — corpos parados "dormem" e deixam de custar simulação até serem perturbados. É uma otimização essencial; um objeto que nunca dorme (por vibrar sem parar) é um custo permanente.
- **CCD** (*Continuous Collision Detection*) — para corpos rápidos, evita o *tunneling* do Capítulo 3.

### Forças e impulsos

```cpp
// Impulso: mudança instantânea de momento (um chute, uma explosão).
Mesh->AddImpulse(Direction * 50000.0f);

// Força: aplicada continuamente — chame A CADA FRAME enquanto ela deve agir.
Mesh->AddForce(Direction * 20000.0f);

// Impulso que ignora a massa (muda a velocidade diretamente):
Mesh->AddImpulse(Direction * 500.0f, NAME_None, /*bVelChange=*/true);
```

Confundir força e impulso é um erro clássico: aplicar uma "força de explosão" com `AddForce` uma única vez produz um empurrão minúsculo; aplicar um impulso todo frame produz um foguete.

### Restrições e manipulação

- **Physics Constraint** — liga dois corpos com limites (uma dobradiça, uma corrente). A lâmpada pendurada do Capítulo 3 seria, na versão "de engine", um corpo simulado preso por uma restrição.
- **Physics Handle** — "segura" um corpo físico e o arrasta até um alvo, com suavização. É a base de pegar e arremessar objetos (o *Launch* de Control, no estudo de caso do Capítulo 6) e de arrastar uma caixa até um lugar para subir nela.

### Tipos de superfície

Em *Project Settings → Physics → Physical Surface*, o projeto define **tipos de superfície** (`Concreto`, `Metal`, `Madeira`, `Água`, `Grade`...). Cada material físico aponta para um tipo. Quando um trace atinge algo com `bReturnPhysicalMaterial`, você sabe **em que superfície** acertou — e pode escolher o som de passo, o efeito de impacto e o decal certos (Capítulos 52 e 54). É o contrato uniforme que o estudo de caso de Control (Capítulo 6) pedia: o feedback vem do **material**, não de um script por objeto.

### Determinismo, de novo

Como o Capítulo 3 alertou: **não assuma que a simulação física é determinística** entre execuções ou máquinas. Isso não importa para uma caixa que cai num jogo single-player. Importa muito para multiplayer (Capítulo 66 e Interlúdio III) e para replays.

---

## 15.6 O personagem e a física

O `CharacterMovementComponent` **não** é uma simulação física. Ele é um sistema **cinemático**: calcula o movimento a partir do input, da velocidade e de regras (caminhar, cair, nadar), e move a cápsula com **sweeps**, resolvendo colisões geometricamente. Isso dá controle preciso e responsivo — o *game feel* do Capítulo 5 — que uma cápsula simulada por forças não daria.

A consequência: a interação entre o personagem e corpos simulados é **aproximada por regras**. O componente de movimento pode aplicar forças a objetos simulados ao encostar neles (há opções de *physics interaction* e fatores de empurrão no componente), e pode ser empurrado por eles de forma limitada. Para "empurrar uma caixa", isso basta. Para "ser atropelado e voar de forma realista", não — é aí que entram **ragdolls** e animação física (Capítulos 30 e 53).

---

## Estudo de caso: GTA IV — quando sistemas de baixo nível viram experiência

> **Pergunta:** como um sistema técnico de baixo nível — física — pode se transformar diretamente em experiência de gameplay?

### O que é publicamente conhecido

**[FATO PÚBLICO]** *Grand Theft Auto IV* (Rockstar, 2008) foi construído sobre a engine proprietária da Rockstar, a **RAGE**, e incorporou a tecnologia **Euphoria**, da NaturalMotion, para animação de personagens baseada em física: em vez de apenas tocar animações pré-gravadas, personagens reagem fisicamente a empurrões, quedas, atropelamentos e tiros, tentando se equilibrar, apoiar-se e proteger-se. A direção dos veículos em GTA IV foi amplamente percebida por jogadores e pela imprensa como mais "pesada" e simulada do que nos jogos anteriores da série, com suspensão, transferência de peso e colisões com consequências visíveis. A mesma tecnologia de animação física foi usada em jogos posteriores da Rockstar, como *Red Dead Redemption* e *Max Payne 3*.

### 1. Experiência

Um mundo que **reage fisicamente** ao jogador, de forma crível e imprevisível. Cada colisão é diferente. Um pedestre empurrado tropeça de um jeito; o mesmo pedestre, em outra situação, tropeça de outro. Batidas de carro têm peso. O jogador sente que está num lugar com regras físicas, não num cenário.

### 2. Sistema

A cadeia que você descreveu, com os sistemas de cada elo. **[INFERÊNCIA]** Os elos são observáveis jogando, mas como a Rockstar os implementa não é público. Há uma exceção: **[FATO PÚBLICO]** a animação física dos personagens de GTA IV usa o *euphoria*, middleware da NaturalMotion.

```text
Physics                 simulação de corpos e veículos (massa, suspensão, colisão)
   ↓
Vehicle Behavior        transferência de peso, derrapagem, perda de controle
   ↓
Collision               contato veículo × mundo × personagens, com impulsos reais
   ↓
NPC Reaction            percepção do impacto, estado de IA (fugir, xingar, ligar para a polícia)
   ↓
Animation               animação física: o corpo reage ao impulso em vez de tocar um clipe fixo
   ↓
Player Feedback         som, câmera, dano visível, o pedestre que se levanta mancando
   ↓
Emergent Gameplay       perseguições, acidentes, situações únicas e memoráveis
```

### 3. Design

A decisão central é **deixar um sistema de simulação decidir os detalhes**, em vez de um animador ou designer decidir cada caso. Isso troca **controle autoral** por **variedade e credibilidade**. É o lado direito do espectro roteiro ↔ sistema do Capítulo 5, levado ao nível de cada tropeço.

O preço também é de design: simulação produz resultados **menos legíveis** e às vezes **menos responsivos**. Parte da recepção de GTA IV — elogios ao realismo, críticas à direção "pesada" — é exatamente esse trade-off: o mesmo sistema que torna os veículos críveis os torna mais difíceis de controlar.

### 4. Tecnologia

**[INFERÊNCIA]** Sem afirmar nada sobre a RAGE ou a Euphoria além do que é público, o comportamento observado sugere:

- veículos como **corpos simulados** com rodas e suspensão (não cinemáticos como o personagem do Capítulo 17);
- personagens que, ao serem atingidos, passam de um modo **cinemático animado** para um modo **físico controlado**, em que a animação "tenta" manter objetivos (equilíbrio, proteger a cabeça) sob forças reais, e depois **voltam** a animações normais ao recuperar o equilíbrio;
- eventos de colisão alimentando a **IA** (o NPC "sabe" que foi atropelado) e o **áudio**;
- um custo de CPU significativo, gerenciado limitando quantos personagens podem estar em simulação física ao mesmo tempo e por quanto tempo.

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]** Na Unreal, uma versão mínima da cadeia, com o que você aprende neste capítulo e nos próximos:

```text
1. Caixas e barris simulados no Pátio (Simulate Physics + material físico).      ← Cap. 15
2. A jogadora empurra as caixas ao andar (physics interaction do movimento).      ← Cap. 15/17
3. Uma caixa que cai faz barulho proporcional à velocidade do impacto
   (evento de hit → som e evento de "ruído" para a IA).                          ← Cap. 15/36/52
4. Um inimigo atingido entra em ragdoll (simulação dos ossos) e,
   numa versão mais ambiciosa, mistura animação e física (physical animation).    ← Cap. 30/53
```

O item 3 é o elo mais valioso para a Vigília: **física → ruído → percepção da Presença**. Uma caixa derrubada sem querer vira uma decisão tática do inimigo. É a cadeia de GTA IV em escala de um corredor.

### 6. Lição

**Sistemas de baixo nível são candidatos a experiência quando suas saídas se conectam a outros sistemas que o jogador percebe.** Física isolada é só realismo visual. Física conectada a IA, áudio e animação vira gameplay. Para um arquiteto de sistemas, é uma ideia familiar: o valor está nas **integrações**, não nos componentes isolados.

E a lição complementar: **simulação custa controle e frames.** Use-a onde o jogador ganha algo que um script não daria.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Matriz de respostas e presets | Regras de firewall / network policies / security groups | A resposta efetiva é a menos restritiva entre os dois lados |
| Traces | Consulta indexada a um banco espacial | O "banco" muda todo frame; o custo depende da geometria |
| Overlap events | Notificações de entrada/saída de um conjunto | Atualizadas a cada movimento; custo proporcional a objetos móveis com overlap |
| Simulação | Simulação numérica | Não determinística entre máquinas; orçamento de frame |
| Personagem cinemático | Controle por regras vs. modelo físico | Aproximação deliberada em nome do *game feel* |

---

## Implementação

### 1. O canal de interação

Em *Project Settings → Engine → Collision → Trace Channels*, crie o canal **`Interaction`** com resposta padrão **Ignore**. Isso grava no `DefaultEngine.ini` um mapeamento para um dos canais de jogo reservados pela engine (`ECC_GameTraceChannel1`, se for o primeiro criado).

No código, crie um apelido legível:

```cpp
// Source/Vigilia/Core/VGCollision.h
#pragma once

#include "Engine/EngineTypes.h"

// Deve corresponder ao canal "Interaction" definido em Project Settings → Collision.
// Se a ordem dos canais customizados mudar, este apelido precisa ser atualizado.
#define ECC_VGInteraction ECC_GameTraceChannel1
```

Com resposta padrão **Ignore**, **nada** bloqueia o canal de interação até que alguém diga que bloqueia. Objetos interativos (Capítulo 19) vão responder **Block** a ele; paredes vão responder **Block** também — para que não se interaja com algo *atrás* de uma parede. Essa configuração explícita é o que permite ao trace de interação ignorar, por exemplo, volumes de trigger e partículas.

**⚠️ As paredes não bloqueiam sozinhas.** Presets da engine como `BlockAll` e `BlockAllDynamic` (os das formas básicas do grey-box) não têm resposta própria para canais criados depois: eles usam a **resposta padrão do canal** — aqui, Ignore. Sem um passo extra, o trace de interação **atravessa paredes** e encontra a porta do outro lado. O passo: em *Project Settings → Collision → Preset*, crie um preset do projeto **`VG_Parede`** (tipo `WorldStatic`, `Query and Physics`, Block em todos os canais, **inclusive `Interaction`**) e aplique-o a paredes, muros e pisos do grey-box — selecione vários atores no Outliner e troque o *Collision Preset* de uma vez. O Capítulo 27 faz a escolha oposta para o canal de tiro (padrão Block, exceções em Ignore); o critério é o mesmo: **o padrão do canal é o que exige menos exceções.**

### 2. O gatilho de eventos

O Projeto 4 vai precisar de dezenas de gatilhos ("quando a jogadora entrar aqui, a luz falha"; "quando passar por aqui, a porta bate"). O primeiro passo é um gatilho reutilizável, simples, que **anuncia** e não decide nada:

```cpp
// Source/Vigilia/World/VGEventTrigger.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGEventTrigger.generated.h"

class UBoxComponent;
class AVGEventTrigger;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGEventTriggerSignature, AVGEventTrigger*, Trigger, AActor*, Activator);

/**
 * Volume que anuncia quando é ativado. Não sabe o que acontece depois: quem reage se inscreve.
 * Simplificação: só considera entrada (não saída) e só volumes de caixa.
 */
UCLASS()
class VIGILIA_API AVGEventTrigger : public AActor
{
    GENERATED_BODY()

public:
    AVGEventTrigger();

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Trigger")
    FVGEventTriggerSignature OnTriggered;

    /** Permite disparar de novo (ex.: ao recarregar um checkpoint). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Trigger")
    void ResetTrigger() { bHasTriggered = false; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Trigger")
    bool HasTriggered() const { return bHasTriggered; }

protected:
    virtual void PostInitializeComponents() override;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UBoxComponent> Volume;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Trigger")
    bool bTriggerOnce = true;

    /** Se verdadeiro, só pawns controlados por jogadores ativam o gatilho. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Trigger")
    bool bPlayerOnly = true;

private:
    UFUNCTION()
    void HandleBeginOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                            UPrimitiveComponent* OtherComp, int32 OtherBodyIndex,
                            bool bFromSweep, const FHitResult& SweepResult);

    bool bHasTriggered = false;
};
```

```cpp
// Source/Vigilia/World/VGEventTrigger.cpp
#include "World/VGEventTrigger.h"

#include "Components/BoxComponent.h"
#include "GameFramework/Pawn.h"

AVGEventTrigger::AVGEventTrigger()
{
    PrimaryActorTick.bCanEverTick = false;

    Volume = CreateDefaultSubobject<UBoxComponent>(TEXT("Volume"));
    Volume->SetBoxExtent(FVector(100.0, 100.0, 100.0));
    Volume->SetCollisionProfileName(TEXT("Trigger")); // QueryOnly, overlap com tudo
    SetRootComponent(Volume);
}

void AVGEventTrigger::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    // Inscrição em delegates dinâmicos fora do construtor: no construtor, ela iria para o CDO
    // e seria serializada de formas difíceis de prever (Cap. 8).
    Volume->OnComponentBeginOverlap.AddDynamic(this, &AVGEventTrigger::HandleBeginOverlap);
}

void AVGEventTrigger::HandleBeginOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                                         UPrimitiveComponent* OtherComp, int32 OtherBodyIndex,
                                         bool bFromSweep, const FHitResult& SweepResult)
{
    if (bTriggerOnce && bHasTriggered)
    {
        return;
    }

    if (bPlayerOnly)
    {
        const APawn* Pawn = Cast<APawn>(OtherActor);
        if (!Pawn || !Pawn->IsPlayerControlled())
        {
            return;
        }
    }

    bHasTriggered = true;                       // estado consistente...
    OnTriggered.Broadcast(this, OtherActor);    // ...depois anuncia (Cap. 4)
}
```

### Explicação das decisões

- **O gatilho só anuncia.** Ele não toca som, não apaga luz, não abre porta. Quem reage se inscreve em `OnTriggered` — o alarme, uma sequência, um Blueprint de conteúdo. É a regra "objetos anunciam, sistemas reagem" do Capítulo 1, e é o que permite usar o mesmo gatilho para cem eventos diferentes.
- **Preset `Trigger`.** Já é `Query Only` e responde Overlap a tudo. Nenhuma configuração manual de canais.
- **`IsPlayerControlled()` em vez de `Cast<AVGCharacter>`.** O gatilho não precisa conhecer a classe da jogadora; ele precisa saber se é **um jogador**. Isso funciona para qualquer pawn possuído por um PlayerController — inclusive a Presença jogável do desafio do Capítulo 10 — e evita uma dependência de classe desnecessária.
- **`bHasTriggered` é estado consultável e resetável.** Lembre-se das perguntas de cancelamento do Capítulo 4: o gatilho precisa poder ser rearmado ao recarregar um checkpoint (Capítulo 56). Por isso `ResetTrigger` e `HasTriggered` existem desde já.
- **Inscrição em `PostInitializeComponents`**, não no construtor.
- **Simplificação declarada:** só entrada, só caixa. Gatilhos de saída e de formas arbitrárias entram quando forem necessários.

### 3. Usando o gatilho: o alarme na porta da Casa de Força

No Pátio:

1. Coloque um `AVGEventTrigger` diante da porta da Casa de Força, cobrindo a largura da escada.
2. No alarme (`BP_AlarmeUsina`), mantenha o comportamento periódico, mas adicione uma referência editável ao gatilho e, no `BeginPlay`, inscreva-se em `OnTriggered` para chamar `TriggerAlarm`:

```text
[Event BeginPlay]
  → Is Valid({GatilhoCasaDeForca})
      Is Valid → Bind Event to OnTriggered(Target={GatilhoCasaDeForca})  ⇢ [AoGatilho]

[AoGatilho]
  → TriggerAlarm
```

Agora, a primeira vez que a jogadora sobe a escada da Casa de Força, a usina "reage": sirene, luz vermelha, postes falhando. É o primeiro evento roteirizado do projeto — e ele foi construído com **sistemas reutilizáveis** (gatilho, alarme, flicker) conectados por **conteúdo** (referências no nível e um grafo de quatro nós).

### 4. Física no Pátio

Crie `BP_CaixaFisica` (um cubo de 60 cm com **Simulate Physics**, preset `PhysicsActor`) e um material físico `PM_Madeira` (atrito moderado, pouca restituição) com tipo de superfície `Madeira`. Espalhe algumas caixas perto do galpão. Verifique que a jogadora consegue empurrá-las e que elas dormem quando param (o console `p.Chaos.DebugDraw.Enabled` e opções de visualização de física da sua versão podem ajudar; `show collision` mostra as formas).

### 5. Um trace de interação de teste

Antes do Capítulo 19, valide o canal: no `AVGCharacter`, adicione temporariamente (ou num Blueprint de teste) um trace a cada 0,1 s, da câmera para a frente, no canal `ECC_VGInteraction`, desenhando o resultado com `DrawDebugLine`. Configure a porta da guarita para responder **Block** a `Interaction`. Olhe para ela: a linha fica verde. Olhe para uma caixa de física (que responde Ignore ao canal): vermelha. Olhe para a porta **através** de uma parede com o preset `VG_Parede`: a linha deve parar na parede (se chegar à porta, o preset não foi aplicado). Esse trace é o esqueleto do sistema de interação.

---

## Projeto 1 — conclusão

### O que o Pátio tem agora

| Capítulo | O Pátio ganhou |
|---|---|
| 7 | Projeto, repositório com LFS, grey-box em escala humana |
| 8 | `AVGSpawner`, ciclo de vida observado |
| 9 | Postes com `UVGFlickerComponent`, luz giratória com componente da engine |
| 10 | GameMode, PlayerController e Character do projeto |
| 11 | `LogVigilia`, CVar de acessibilidade, comandos de console |
| 12 | Alarme da usina em Blueprint |
| 13 | Alarme migrado para `AVGAlarm` (C++) + Blueprint; Data Assets de flicker; validação |
| 14 | Andar, olhar, pular — o primeiro playtest |
| 15 | Colisão configurada, gatilho de eventos, caixas físicas, canal de interação |

### Critérios de conclusão do Projeto 1

- [ ] O jogo abre no Pátio, com a jogadora no portão, e é possível explorar todo o espaço a pé.
- [ ] Nenhum ponto do pátio permite atravessar paredes ou sair do perímetro.
- [ ] A escala parece humana em primeira pessoa (portas, escada, guarita, Casa de Força).
- [ ] Há pelo menos um marco visual que orienta a jogadora (a caixa d'água).
- [ ] Os postes usam o `UVGFlickerComponent` com perfis de Data Asset; um deles falha constantemente.
- [ ] O alarme toca periodicamente **e** ao subir a escada da Casa de Força, e os postes reagem.
- [ ] `vg.Flicker.Enabled 0` desliga as falhas de luz.
- [ ] Caixas físicas podem ser empurradas.
- [ ] O trace de interação de teste distingue a porta da guarita das caixas.
- [ ] O projeto foi empacotado em Development e jogado fora do editor (desafio do Capítulo 7, repetido agora).
- [ ] O `DEVLOG.md` tem entradas de todos os capítulos da Parte II, incluindo a migração do alarme como ADR.

### Retrospectiva

Escreva no `DEVLOG.md`, em no máximo uma página:

1. O que mais surpreendeu na diferença entre "voar pelo grey-box" e "andar por ele"?
2. Qual decisão da Parte II você tomaria de outro jeito, sabendo o que sabe agora?
3. Que parte do Pátio é a mais "assustadora"? Por quê? (Você vai voltar a esta resposta no Capítulo 50.)

---

## Decisões arquiteturais

1. **Consultas por padrão, simulação onde o jogador ganha algo.**
2. **Presets de colisão por padrão**; customizações repetidas viram presets do projeto.
3. **Overlaps habilitados só onde são usados.**
4. **Canal `Interaction` com resposta padrão Ignore**, apelidado em `VGCollision.h`; paredes bloqueiam via preset do projeto `VG_Parede`.
5. **Gatilhos só anunciam**; reações são inscrições em `OnTriggered`.
6. **Filtrar "é jogador" por `IsPlayerControlled()`**, não por classe.
7. **Feedback de impacto e passos virá de materiais físicos e tipos de superfície**, não de scripts por objeto.
8. **Inscrição em delegates fora do construtor** (`PostInitializeComponents` ou `BeginPlay`).

---

## Armadilhas

- **Generate Overlap Events desligado** num dos lados.
- **Prever a resposta olhando só um dos objetos** — a resposta efetiva depende dos dois.
- **Colisão complexa em simulação** ou em traces frequentes sem necessidade.
- **Malhas detalhadas com colisão detalhada** — personagens tropeçando em detalhes invisíveis.
- **Confundir força e impulso.**
- **Corpos que nunca dormem.**
- **Traces que acertam a própria jogadora** (esquecer `AddIgnoredActor`).
- **Inscrever delegates dinâmicos no construtor.**
- **Gatilhos que fazem tudo** — som, luz, porta, IA — em vez de anunciar.
- **Hardcode de `ECC_GameTraceChannelN`** espalhado pelo código, sem apelido.

---

## Exercício

**Parte 1 — matriz (30 min).** Para cinco pares de objetos do Pátio (jogadora × parede, jogadora × trigger, caixa × chão, trace de interação × caixa, trace de interação × porta), escreva a resposta de cada lado e preveja o resultado. Confirme no jogo.

**Parte 2 — gatilho e alarme (1 h).** Implemente `AVGEventTrigger` e conecte-o ao alarme na Casa de Força. Teste com `bTriggerOnce` ligado e desligado. Coloque a Presença de teste (desafio do Capítulo 10) e verifique que, com `bPlayerOnly`, ela só ativa o gatilho quando está possuída por você.

**Parte 3 — física (1 h).** Crie as caixas físicas e o material físico. Experimente: massa de 1 kg vs. 500 kg; restituição 0 vs. 0,9; amortecimento 0 vs. 2. Descreva a sensação de cada configuração. Qual parece "uma caixa de madeira velha numa usina abandonada"?

**Parte 4 — conclusão do Projeto 1 (2–3 h).** Passe pela lista de critérios de conclusão, corrija o que faltar, empacote e escreva a retrospectiva.

---

## Desafio — física que faz barulho

Implemente o elo "física → ruído" do estudo de caso de GTA IV, em versão mínima:

1. Em `BP_CaixaFisica`, habilite *Simulation Generates Hit Events*.
2. No evento de hit, calcule a intensidade do impacto a partir da velocidade relativa (o `FHitResult` e a velocidade do corpo ajudam) e **ignore impactos pequenos** (senão a caixa "faz barulho" o tempo todo enquanto está apoiada — lembre-se da histerese do Capítulo 4).
3. Para impactos relevantes, toque um som com volume proporcional à intensidade e **anuncie um evento de ruído** (por enquanto, um `UE_LOG` com posição e intensidade, ou um delegate global num subsistema simples).
4. Limite a taxa: no máximo um evento de ruído por caixa a cada 0,3 s.

Pergunta para o `DEVLOG.md`: esse "evento de ruído" deveria ser emitido pela caixa (cada objeto físico conhece o sistema de ruído) ou por um sistema que observa todos os impactos físicos? Qual das opções respeita melhor o "contrato uniforme" do estudo de caso de Control (Capítulo 6)? *(O Capítulo 36 responde com o sistema de percepção da Unreal.)*

---

## Uso de IA

1. **Para depurar colisão:**
   > "Na Unreal Engine 5, meu volume de trigger não dispara o evento de overlap quando o personagem entra nele. Liste todas as causas possíveis em ordem de probabilidade (Generate Overlap Events, preset, Collision Enabled, respostas de ambos os lados, tipo de objeto da cápsula, inscrição no delegate, componente errado) e como verificar cada uma no editor."

2. **Para escolher a consulta certa:**
   > "Para cada caso, diga qual consulta espacial da Unreal eu deveria usar (line trace single/multi, sweep, overlap) e com que canal/forma: interação com objetos à frente da câmera; verificar se um inimigo vê a jogadora; verificar se há espaço para a jogadora levantar após agachar; encontrar todos os objetos atingidos por uma explosão; spawn seguro de um inimigo; câmera que não atravessa paredes."

3. **Para pensar em física como design:**
   > "Dê exemplos de jogos em que a física é central para a experiência (como GTA IV, Half-Life 2, Control) e, para cada um, identifique qual saída do sistema físico se conecta a outro sistema que o jogador percebe (IA, áudio, puzzles, combate). Separe o que é observável do que é inferência sobre a implementação."

**Cuidado específico:** a Unreal 5 trocou a engine física (PhysX → Chaos), e muitas respostas — de IA e de fóruns — ainda citam comandos de console, opções e APIs de PhysX. Se algo não existir na sua versão, procure o equivalente do Chaos.

---

## Checklist

- [ ] Sei distinguir consultas espaciais de simulação e quando usar cada uma.
- [ ] Sei configurar object types, trace channels, respostas, Collision Enabled e presets.
- [ ] Sei prever a resposta efetiva entre dois objetos pela regra da menos restritiva.
- [ ] Sei usar eventos de overlap e hit, e conheço o custo dos overlaps.
- [ ] Sei fazer traces e sweeps, ler um `FHitResult` e depurá-los visualmente.
- [ ] Sei simular corpos com massa, amortecimento, material físico, impulsos e forças.
- [ ] Entendo por que o personagem é cinemático e como ele interage com corpos simulados.
- [ ] Criei o canal `Interaction` e o `AVGEventTrigger`.
- [ ] Consigo decompor a cadeia física → experiência de GTA IV.
- [ ] Concluí o Projeto 1 segundo os critérios.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Collision** (incluindo *Collision Response Reference* e *Collision Filtering*), **Traces**, **Physics** e as páginas sobre a física **Chaos**, **Physical Materials** e **Physics Constraints**.
- **NaturalMotion / Euphoria** — materiais públicos de divulgação da tecnologia e talks sobre animação física em jogos, para o contexto do estudo de caso.

---

## Fechamento da Parte II

A Parte II transformou o modelo mental da Parte I em ferramentas concretas:

```text
Cap. 7   A engine, o projeto, o editor, assets e versionamento.
Cap. 8   Actors: CDO, ciclo de vida, spawn e destruição.
Cap. 9   Components: níveis, hierarquia, comunicação, quando criar.
Cap. 10  Gameplay Framework: vontade e corpo, quem existe onde, onde mora o estado.
Cap. 11  C++ na Unreal: compilação, memória, reflexão, GC, erros, logs, CVars.
Cap. 12  Blueprint: a linguagem de conteúdo, suas armadilhas e seu custo.
Cap. 13  A regra de camadas: C++, Blueprint e dados, e a primeira migração.
Cap. 14  Input: intenção, contextos, mouse vs. analógico, multiplayer local.
Cap. 15  Colisão e física: consultas, simulação, gatilhos e o fim do Projeto 1.
```

Na Parte III, o foco muda de "como a engine funciona" para "como se programa gameplay": o personagem ganha movimento afinado, câmera expressiva, interação com o mundo, uma arma, dano e vida — e começa o **Projeto 2 (FPS básico)** e o **Projeto 3 (Interação)**.

➡️ **Próximo:** [Capítulo 16 — Player Controller](../parte-03/cap-16-player-controller.md)

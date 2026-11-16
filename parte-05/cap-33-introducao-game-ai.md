# PARTE V — Game AI

*Projeto 5: o Vigia e a Presença*

---

# Capítulo 33 — Introdução à Game AI

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que **Game AI** é — e por que ela tem objetivos diferentes da IA acadêmica e da IA generativa;
- usar o ciclo **perceber → decidir → agir** como modelo de qualquer agente de jogo;
- entender a **ilusão de inteligência**: o que faz um agente *parecer* inteligente, e por que isso importa mais do que ele *ser*;
- comparar as principais **arquiteturas de decisão** (FSM, FSM hierárquica, Behavior Tree, Utility, planejamento) antes de estudá-las uma a uma;
- conhecer a **pilha de IA da Unreal** (AIController, Perception, Navigation, Blackboard, Behavior Trees, EQS, StateTree, Smart Objects, Mass) e as ferramentas de depuração;
- definir os dois agentes do Projeto 5 — **o Vigia** e **a Presença** — e o plano para substituir o cérebro ingênuo do Capítulo 30.

---

## Contexto

O Capítulo 30 terminou com uma lista: as **dores do cérebro ingênuo**. O vigia do Galpão vê por um trace direto, não ouve, não lembra, não se move com propósito, não se coordena, e toda a sua lógica está num `switch` que ficou frágil com quatro estados. O Interlúdio I acrescentou outra: a **Presença** é uma malha que aparece e some, sem saber nada do mundo.

A Parte V resolve essas dores, uma de cada vez, e é uma das partes mais importantes do livro — por três razões. Primeiro, porque Game AI é o lugar onde **sistemas produzem comportamento emergente** (Capítulo 5), o que o pedido original destacou. Segundo, porque a Vigília depende inteiramente de **um** agente — a Presença — para existir como jogo de terror. Terceiro, porque Game AI é o tema em que a confusão com **IA generativa** é mais comum, e o livro separa as duas antes de, na Parte X, combiná-las.

---

## 33.1 O que Game AI é — e o que não é

Três coisas compartilham a sigla "IA" e quase nada mais:

| | **Game AI** | **IA acadêmica / clássica** | **IA generativa (LLMs etc.)** |
|---|---|---|---|
| Objetivo | Produzir uma **experiência** para o jogador | Resolver um problema bem | Gerar conteúdo plausível (texto, imagem, código) |
| Critério de sucesso | O jogador se diverte, sente medo, sente desafio justo | Otimalidade, precisão | Qualidade e coerência do conteúdo |
| Deve ganhar? | **Não necessariamente** — frequentemente deve perder bem | Sim | — |
| Determinismo | Desejável (depuração, rede, justiça) | Variável | Baixo |
| Orçamento | Fração de milissegundo por agente, por frame | Ilimitado | Centenas de ms a segundos por resposta |
| Ferramentas | FSM, Behavior Trees, Utility, navegação, percepção, planejamento | Busca, aprendizado, otimização | Modelos treinados, prompts, RAG |

A frase que resume a Game AI é: **o objetivo não é que o inimigo jogue bem; é que o jogador tenha uma boa experiência jogando contra ele.** Um inimigo de FPS que acerta todo tiro, que sempre sabe onde o jogador está e que nunca comete erros é **trivial** de programar — e é péssimo de enfrentar. O trabalho de Game AI é, em grande parte, **dosar** a competência: torná-la legível, justa, variada e no nível certo.

> 🌉 **Ponte:** você conhece o problema de "o sistema tecnicamente correto que o usuário odeia". Game AI é o caso extremo: o adversário otimamente correto **é** o bug.
>
> 🧱 **Onde a ponte cai:** em sistemas corporativos, você otimiza para o resultado e cuida da UX em volta. Em Game AI, a **UX é o resultado**: a "qualidade" de uma decisão da IA é medida pelo que ela faz o jogador sentir.

### Game AI e IA generativa, desde já

Tudo nesta Parte é **IA tradicional de jogos**: algoritmos determinísticos, baratos, autorados por designers, depuráveis. Nenhum LLM decide o que a Presença faz. A Parte X (Capítulos 72–75) estuda onde IA generativa pode **complementar** esses sistemas — por exemplo, verbalizando decisões que a Game AI tomou —, e explica por que ela não os substitui. Como o pedido original exigiu: os fundamentos primeiro.

---

## 33.2 Perceber, decidir, agir

Todo agente de jogo, do fantasma do Pac-Man ao soldado de um shooter moderno, pode ser descrito pelo mesmo ciclo:

```text
        ┌───────────────────────────────────────────────────────────────┐
        │                                                               │
        ▼                                                               │
   ┌──────────┐    o que eu sei     ┌──────────┐    o que vou fazer   ┌──────────┐
   │ PERCEBER │ ──────────────────► │ DECIDIR  │ ───────────────────► │   AGIR   │
   │ visão,   │   (memória do       │ FSM, BT, │   (intenção)         │ mover,   │
   │ audição, │    agente:          │ utility, │                      │ mirar,   │
   │ dano,    │    blackboard)      │ planner  │                      │ atacar,  │
   │ eventos  │                     │          │                      │ falar    │
   └──────────┘                     └──────────┘                      └──────────┘
        ▲                                                               │
        └──────────────────── o mundo muda ◄────────────────────────────┘
```

O "Soldier AI" do pedido original é exatamente esse ciclo com uma etapa a mais:

```text
Perception → Decision → Tactical Position → Navigation → Action
 (Cap. 36)   (34,37,40)     (39, 41)          (35)       (30, 41)
```

A separação em etapas é a mesma separação de responsabilidades que você usaria num sistema: **percepção** transforma estímulos em fatos; **memória** (Capítulo 38) guarda fatos; **decisão** escolhe uma intenção; **posicionamento tático** escolhe *onde* realizar a intenção; **navegação** encontra *como* chegar; **ação** executa no corpo. Cada etapa pode ser trocada, ajustada e depurada isoladamente — e o cérebro ingênuo do Capítulo 30 doía exatamente porque misturava todas num `switch`.

---

## 33.3 A ilusão de inteligência

O jogador nunca vê o código da IA. Ele vê **comportamento** — e infere intenção a partir dele. Por isso, o que faz uma IA *parecer* inteligente é, em boa parte, **comunicação**:

| O que o jogador vê | O que ele conclui | Quanto custa |
|---|---|---|
| O inimigo grita "ali!" e aponta antes de atirar | "Ele me viu e avisou os outros" | Uma fala e uma animação |
| O inimigo corre para trás de uma caixa ao ser atingido | "Ele está se protegendo" | Uma consulta espacial (Cap. 39) |
| O inimigo vai até onde o jogador **estava** e olha em volta | "Ele está me procurando" | Memória da última posição (Cap. 36) |
| Dois inimigos atacam por lados diferentes | "Eles estão me cercando" | Coordenação mínima (Cap. 42) |
| O inimigo hesita, recua, e volta com outro | "Ele foi pedir ajuda" | Uma sequência roteirizada |

Muitos desses comportamentos são **mais simples** do que a conclusão do jogador. Uma IA que flanqueia porque um algoritmo de pontuação escolheu um ponto com boa cobertura lateral **parece** estratégica. Uma IA que "foi pedir ajuda" pode ter apenas trocado de lugar com outra fora de vista. Isso não é desonestidade; é o princípio do Capítulo 1 aplicado ao comportamento: **simule o que o jogador percebe**.

A recíproca é a armadilha mais comum de quem começa: **inteligência invisível é desperdício.** Uma IA que calcula rotas táticas sofisticadas mas não comunica nada parece aleatória. Investir em percepção, decisão e posicionamento sem investir em **apresentação** — falas, animações, olhar, hesitação — é investir em algo que o jogador não recebe.

---

## 33.4 Arquiteturas de decisão: um mapa

O núcleo de um agente é a **decisão**. Há uma família de arquiteturas, e a Parte V estuda as principais. Antes do detalhe, o mapa:

| Arquitetura | Ideia | Força | Fraqueza | Capítulo |
|---|---|---|---|---|
| **FSM** | Estados e transições explícitas | Simples, previsível, fácil de depurar | Explosão de transições com muitos estados | 34 |
| **FSM hierárquica (HFSM)** | Estados que contêm estados | Organiza comportamentos por contexto | Ainda rígida; transições entre níveis complicam | 34 |
| **Behavior Tree** | Árvore de prioridades e sequências reavaliada continuamente | Reativa, modular, autorável por designers, padrão da indústria | Difícil expressar "valores contínuos"; árvores enormes viram labirintos | 37 |
| **Utility AI** | Cada ação recebe uma pontuação; escolhe-se a melhor | Decisões graduais, "humanas", fáceis de ajustar por curvas | Difícil prever; pontuações precisam de muito ajuste | 40 |
| **Planejamento (GOAP, HTN)** | O agente busca uma **sequência de ações** que atinge um objetivo | Comportamento emergente, adaptável | Custo, imprevisibilidade, difícil de autorar narrativa | 41 |
| **StateTree** (Unreal) | Híbrido de HFSM com seleção por condições, da Epic | Moderno, eficiente, integrado | Mais novo; menos material | 37 (menção) |

Não há vencedor. Jogos reais **combinam** arquiteturas: uma FSM no nível mais alto (o "modo" do agente), Behavior Trees dentro de cada modo, Utility para escolhas graduais, e planejamento para situações táticas específicas. A Parte V constrói a Vigília exatamente assim, e o Capítulo 42 mostra o resultado completo.

---

## 33.5 A pilha de IA da Unreal

A Unreal tem um conjunto extenso de ferramentas de IA, e saber qual é qual evita reinventar o que existe (Capítulo 9: "a engine já tem isso?"):

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│  AAIController          o "cérebro" que possui o pawn (Cap. 10: vontade/corpo) │
├──────────────────┬──────────────────┬──────────────────┬──────────────────────┤
│ PERCEPÇÃO        │ MEMÓRIA          │ DECISÃO          │ ESPAÇO               │
│ AI Perception    │ Blackboard       │ Behavior Trees   │ Navigation System    │
│ (visão, audição, │ (Cap. 38)        │ (Cap. 37)        │ (NavMesh, Cap. 35)   │
│ dano, equipe)    │                  │ StateTree        │ EQS (Cap. 39)        │
│ (Cap. 36)        │                  │ (alternativa)    │ Smart Objects        │
├──────────────────┴──────────────────┴──────────────────┴──────────────────────┤
│  EM ESCALA: Mass AI (multidões, tráfego — Cap. 6)                              │
├────────────────────────────────────────────────────────────────────────────────┤
│  DEPURAÇÃO: Gameplay Debugger · Visual Logger · AI debugging no editor        │
└────────────────────────────────────────────────────────────────────────────────┘
```

- **`AAIController`** — o controller dos agentes. Possui o pawn, roda a Behavior Tree, dono do componente de percepção, executa movimentos (`MoveToLocation`, `MoveToActor`) e define **foco** (`SetFocus`: para onde o agente olha/mira).
- **AI Perception** — sentidos configuráveis (visão com cone e raio, audição por eventos de ruído, dano, "equipe"), com memória de estímulos e afiliação (amigo/inimigo/neutro).
- **Navigation System** — malha de navegação (NavMesh) gerada a partir da geometria, busca de caminhos, áreas com custo, filtros por agente, links, evitação.
- **Blackboard** — a memória de trabalho de um agente: um dicionário tipado de fatos.
- **Behavior Trees** — o sistema de decisão padrão da Unreal, com editor visual e depurador.
- **EQS (Environment Query System)** — consultas espaciais com pontuação: "qual o melhor ponto para me esconder?"
- **StateTree** — sistema mais recente da Epic, que combina máquina de estados hierárquica com seleção por condições.
- **Smart Objects** — objetos do mundo que anunciam usos possíveis para agentes ("posso ser usado como cobertura", "posso ser sentado").
- **Mass AI** — IA de multidões no framework ECS (Capítulo 6).

Para a Vigília, a pilha usada será: **AIController + Perception + Navigation + Blackboard + Behavior Trees + EQS**, com um pouco de Utility em C++ (Capítulo 40). É a pilha mais documentada e mais usada em produção, e cada peça corresponde a uma etapa do ciclo da seção 33.2.

> **Dependências de módulo:** a partir daqui, o `Vigilia.Build.cs` precisa de `AIModule`, `GameplayTasks` e `NavigationSystem`.

### Depurar IA

IA é o sistema de jogo **mais difícil de depurar só com logs**, porque o comportamento é o resultado de muitas decisões ao longo do tempo. Duas ferramentas da Unreal são indispensáveis desde o primeiro dia:

- **Gameplay Debugger** — ativado durante o jogo (por padrão, a tecla de apóstrofo), mostra sobre o agente selecionado: a Behavior Tree executando (qual nó), o Blackboard (os fatos), a percepção (o que ele vê e ouve, com cones e raios desenhados), o caminho de navegação.
- **Visual Logger** — grava, ao longo do tempo, logs e formas geométricas por agente; permite **voltar no tempo** e ver o que o agente sabia e decidiu em cada momento. É o *tracing* do Capítulo 1 (seção 1.9) para IA.

> 🌉 **Ponte:** o Gameplay Debugger é o **dashboard ao vivo** de um agente; o Visual Logger é o **trace distribuído** gravado. Você não depura um sistema distribuído só com `println`; não depure IA também.

---

## 33.6 Os agentes do Projeto 5

### O Vigia

Humano, armado, derrotável. Aparece num único trecho da Vigília (Capítulo 21) e é o adversário do Galpão de Testes. Requisitos:

- **Percebe** por visão (cone, raio, linha de visão) e audição (passos, tiros, portas), com memória curta.
- **Comunica** o próprio estado: desconfiado, alerta, combatendo, procurando (Capítulo 30, estudo de caso).
- **Combate** com cobertura, telegrafia e erro de mira dosado (Capítulos 21 e 30).
- **Coordena** minimamente com outros vigias: não atacam todos ao mesmo tempo (Capítulo 42).

### A Presença

O agente que define a Vigília. Não humana, invencível, ligada à escuridão. Requisitos de design:

- **Evita a luz.** Não entra em zonas seguras (Capítulo 23) nem em áreas iluminadas da rede elétrica; recua da luz do sinalizador (Capítulo 28).
- **Percebe por som** mais do que por visão — e vê **muito melhor** a jogadora quando a lanterna dela está acesa.
- **Caça, mas não é onisciente.** Investiga ruídos, procura onde a jogadora estava, desiste e "volta para a escuridão".
- **Persegue** em momentos específicos (a sequência de perseguição do projeto final).
- **Nunca ataca sem telegrafia** (Capítulo 21): o som característico e a falha das luzes próximas.
- **É dosada por um diretor** (Capítulo 42): aparece com uma frequência que respeita a curva de tensão (Capítulo 5), e não "o tempo todo".

### Plano da Parte V

| Capítulo | O que muda no Vigia | O que muda na Presença |
|---|---|---|
| 33 | `AVGAIController` substitui o `AAIController` padrão | Ganha um corpo (`AVGEnemyCharacter`) e um controller |
| 34 | O cérebro ingênuo vira uma FSM hierárquica (e mostra seus limites) | — |
| 35 | Navegação no Galpão | Navegação que **evita áreas iluminadas** |
| 36 | Visão e audição com memória | Audição forte; visão afetada pela lanterna; nível de ameaça |
| 37–38 | Behavior Tree + Blackboard substituem a FSM | Behavior Tree completa: espreitar, investigar, procurar, caçar, recuar |
| 39 | Pontos de cobertura | Pontos de emboscada no escuro, pontos de busca |
| 40 | Utility para escolhas de combate | Utility para "humor" (agressiva ↔ cautelosa) |
| 41 | Táticas: cobertura, supressão, flanco | — |
| 42 | Tokens de ataque, papéis | O **Diretor**: pacing da Presença |

---

## Estudo de caso: Outlast — perseguição sem combate

> **Pergunta:** como criar tensão quando o jogador não possui um sistema tradicional de combate?

**[FATO PÚBLICO]** Em *Outlast* (Red Barrels, 2013), o jogador não pode lutar. Inimigos o perseguem pelos corredores do hospital; ele pode fugir, quebrar a linha de visão, pular obstáculos, fechar portas atrás de si e se esconder em armários e debaixo de camas. Inimigos procuram o jogador nas proximidades depois de perdê-lo de vista, e há sequências de perseguição roteirizadas em pontos específicos do jogo.

**[INFERÊNCIA]** Sem combate, **todo o peso da experiência recai sobre a IA e o espaço**. Para a tensão funcionar, a IA precisa ser:

- **Ameaçadora** — rápida o bastante para ser perigosa;
- **Falível** — perde o jogador de vista, procura nos lugares errados, desiste —, porque uma IA que sempre encontra o jogador transforma esconder-se em inútil;
- **Legível** — o jogador precisa saber se foi visto, se está sendo procurado, se o perigo passou (sons, música, falas);
- **Coerente com o espaço** — esconderijos e rotas de fuga só funcionam se a navegação e a percepção da IA respeitarem as regras que o jogador aprendeu.

E a **alternância** entre sistemas e roteiro (Capítulo 5, seção 5.6) — perseguições roteirizadas nos picos, IA sistêmica entre eles — garante que os momentos mais intensos aconteçam quando o design quer. Nenhuma afirmação é feita sobre a implementação da Red Barrels.

**[SIMPLIFICAÇÃO DIDÁTICA]** A Presença da Vigília é desenhada com essa mesma lista: ameaçadora (rápida na caça), falível (memória que decai, busca por pontos plausíveis), legível (telegrafia, falha de luzes, som), coerente com o espaço (navegação que respeita a luz — a regra que a jogadora aprende). E a perseguição do projeto final será **roteirizada no gatilho e sistêmica na execução** (Capítulo 80).

**Lição:** **sem combate, a IA é o jogo.** E uma IA de terror bem-sucedida não é a que mais vence: é a que **perde do jeito certo** — o suficiente para o jogador escapar, nunca o suficiente para ele relaxar.

---

## Comparação com o desenvolvimento tradicional

| Game AI | O que você conhece | Onde a analogia cai |
|---|---|---|
| Perceber → decidir → agir | Pipeline de processamento / laço de controle | O "controle" deve ser deliberadamente imperfeito |
| Separar percepção, memória, decisão, espaço, ação | Separação em camadas / serviços | Todas rodam no mesmo frame, com orçamento de microssegundos |
| Ilusão de inteligência | Percepção de performance pelo usuário | Aqui, a percepção **é** a especificação |
| Gameplay Debugger / Visual Logger | Dashboards / tracing | O "trace" inclui geometria: cones, caminhos, pontos |

---

## Implementação

### 1. Dependências

```csharp
// Vigilia.Build.cs — adicionar:
"AIModule", "GameplayTasks", "NavigationSystem"
```

### 2. O controller de IA do projeto

```cpp
// Source/Vigilia/AI/VGAIController.h
#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "GenericTeamAgentInterface.h"
#include "VGAIController.generated.h"

class UBehaviorTree;

/** Equipes do projeto (usadas pela percepção para afiliação amigo/inimigo/neutro — Cap. 36). */
UENUM(BlueprintType)
enum class EVGTeam : uint8
{
    Player   = 0,
    Guards   = 1,
    Presence = 2,
    Neutral  = 255
};

/**
 * Cérebro dos agentes da Vigília. Possui o pawn, roda a Behavior Tree (Cap. 37),
 * é dono da percepção (Cap. 36) e define a equipe do agente.
 */
UCLASS()
class VIGILIA_API AVGAIController : public AAIController
{
    GENERATED_BODY()

public:
    AVGAIController();

    // IGenericTeamAgentInterface (herdada via AAIController)
    virtual FGenericTeamId GetGenericTeamId() const override { return FGenericTeamId(static_cast<uint8>(Team)); }
    virtual ETeamAttitude::Type GetTeamAttitudeTowards(const AActor& Other) const override;

protected:
    virtual void OnPossess(APawn* InPawn) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|AI")
    EVGTeam Team = EVGTeam::Guards;

    /** Árvore de comportamento a executar ao possuir um corpo (vazia até o Cap. 37). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|AI")
    TObjectPtr<UBehaviorTree> BehaviorTree;
};
```

```cpp
// Source/Vigilia/AI/VGAIController.cpp
#include "AI/VGAIController.h"

#include "BehaviorTree/BehaviorTree.h"

AVGAIController::AVGAIController()
{
    bWantsPlayerState = false; // agentes não precisam de PlayerState (Cap. 10)
}

void AVGAIController::OnPossess(APawn* InPawn)
{
    Super::OnPossess(InPawn);
    if (BehaviorTree)
    {
        RunBehaviorTree(BehaviorTree); // também inicializa o Blackboard da árvore (Cap. 38)
    }
}

ETeamAttitude::Type AVGAIController::GetTeamAttitudeTowards(const AActor& Other) const
{
    const IGenericTeamAgentInterface* OtherTeamAgent = Cast<const IGenericTeamAgentInterface>(&Other);
    if (const APawn* OtherPawn = Cast<APawn>(&Other))
    {
        // A equipe de um pawn é a do seu controller.
        OtherTeamAgent = Cast<const IGenericTeamAgentInterface>(OtherPawn->GetController());
    }
    if (!OtherTeamAgent)
    {
        return ETeamAttitude::Neutral;
    }
    const uint8 OtherTeam = OtherTeamAgent->GetGenericTeamId().GetId();
    if (OtherTeam == static_cast<uint8>(EVGTeam::Neutral))
    {
        return ETeamAttitude::Neutral;
    }
    return OtherTeam == static_cast<uint8>(Team) ? ETeamAttitude::Friendly : ETeamAttitude::Hostile;
}
```

E, para que a jogadora tenha equipe, o `AVGPlayerController` implementa `IGenericTeamAgentInterface` retornando `EVGTeam::Player` (o `APlayerController` não implementa por padrão — acrescente a interface à classe e sobrescreva `GetGenericTeamId`).

### Explicação das decisões

- **Equipes como `FGenericTeamId`**: é o mecanismo padrão que a percepção da Unreal usa para decidir se um estímulo vem de amigo, inimigo ou neutro (Capítulo 36). Com ele, os vigias não "percebem" uns aos outros como ameaça, e a Presença trata vigias e jogadora como alvos diferentes, se o design quiser.
- **A equipe de um pawn é a do seu controller**: coerente com a separação vontade/corpo (Capítulo 10) — um corpo possuído pela jogadora é "da jogadora".
- **A Behavior Tree é dado** (`EditDefaultsOnly`): o Blueprint do controller de cada agente escolhe a sua. Vazia até o Capítulo 37.
- **Tags vs. equipes:** o projeto já tem `Faction.*` (Capítulo 23). As duas coisas coexistem: tags são a identidade consultada por **sistemas de gameplay** (objetivos, interação); equipes são o mecanismo que a **percepção da engine** entende. O controller pode derivar a equipe das tags do pawn se você quiser uma fonte única da verdade — fica como exercício.

### 3. Os corpos

- `BP_VigiaTeste` (Capítulo 30): `AI Controller Class = BP_VGAIController_Vigia` (filho de `AVGAIController`, `Team = Guards`). O `UVGSimpleCombatBrain` continua por enquanto.
- **`BP_Presenca`**: filho de `AVGEnemyCharacter` (Capítulo 30). Corpo alto e magro (placeholder: cápsula esticada e uma malha escura), **sem** `UVGWeaponComponent` útil (remova a arma inicial), `UVGHealthComponent` com **`bInvulnerable = true`**, `IdentityTags = Faction.Presence`, `AI Controller Class = BP_VGAIController_Presenca` (`Team = Presence`). Por enquanto ela fica parada — ganha cérebro a partir do Capítulo 36.

### 4. Ferramentas

Ative o **Gameplay Debugger** (habilitado por padrão em builds de desenvolvimento) e, durante o PIE, aponte para um vigia e pressione a tecla de ativação: veja as categorias disponíveis (algumas ficarão vazias até os próximos capítulos). Abra o **Visual Logger** (*Tools → Debug → Visual Logger*, ou o caminho equivalente na sua versão), grave alguns segundos de jogo e navegue na linha do tempo.

---

## Decisões arquiteturais

1. **Game AI serve à experiência**: competência dosada, legível e justa.
2. **Ciclo perceber → decidir → (posicionar) → navegar → agir**, cada etapa num sistema próprio.
3. **Apresentação faz parte da IA**: todo estado relevante é comunicado.
4. **Pilha: AIController + Perception + Navigation + Blackboard + Behavior Trees + EQS**, com Utility em C++ onde ajudar.
5. **`AVGAIController`** com equipes (`EVGTeam`) e Behavior Tree como dado.
6. **Gameplay Debugger e Visual Logger desde o primeiro agente.**
7. **Nenhuma IA generativa na tomada de decisão dos agentes.**

---

## Armadilhas

- **IA ótima** — o inimigo que sempre vence.
- **Inteligência invisível** — decisões sofisticadas sem comunicação.
- **Misturar percepção, decisão e ação** num só lugar (o cérebro ingênuo).
- **Reinventar o que a engine tem** (navegação, percepção, consultas espaciais).
- **Depurar IA só com logs de texto.**
- **Confundir Game AI com IA generativa** — e tentar usar um LLM para decidir movimento a cada frame.

---

## Exercício

**Parte 1 — controller e equipes (1 h).** Implemente `AVGAIController` com equipes e faça o `AVGPlayerController` implementar `IGenericTeamAgentInterface`. Configure os vigias e a Presença com controllers próprios.

**Parte 2 — ferramentas (45 min).** Use o Gameplay Debugger e o Visual Logger com os vigias do Galpão (com o cérebro ingênuo). Grave uma sessão de combate no Visual Logger e encontre, na linha do tempo, o momento em que cada vigia mudou de estado. (Dica: faça o `UVGSimpleCombatBrain` registrar as transições com `UE_VLOG` — pesquise a macro.)

**Parte 3 — ilusão (45 min).** Escolha um inimigo de um jogo que você conhece bem (de qualquer gênero). Liste cinco comportamentos que fazem ele parecer inteligente e, para cada um, proponha a implementação **mais barata** que produziria a mesma percepção. Marque fatos e inferências.

---

## Desafio — a ficha da Presença

Escreva a **Ficha de Decomposição** (Capítulo 1) da Presença — não de um jogo existente, mas do **seu** agente — com uma seção extra: **"o que o jogador deve conseguir inferir"**. Para cada estado do agente (dormente, espreitando, investigando, procurando, caçando, atordoada, recuando), defina:

1. O que a Presença está "pensando".
2. O que a jogadora **vê e ouve**.
3. O que a jogadora deve **concluir**.
4. Que decisão isso permite à jogadora tomar.

Esse documento (`docs/design/presenca.md`) é a especificação de comportamento **e** de apresentação da Presença para o resto da Parte V.

---

## Uso de IA

1. **Para separar os três tipos de "IA":**
   > "Explique a diferença entre Game AI (Behavior Trees, FSM, navegação), IA acadêmica e IA generativa (LLMs) em termos de objetivo, critério de sucesso, orçamento de tempo e determinismo. Dê três exemplos de tarefas num jogo de terror e diga qual tipo de IA é adequado para cada uma e por quê."

2. **Para desenhar a ilusão:**
   > "Atue como designer de IA de jogos de terror. Para uma criatura que caça a jogadora e evita a luz, liste comportamentos que maximizam a sensação de inteligência com o menor custo de implementação, e para cada um diga como comunicá-lo (som, animação, luz, música)."

3. **Para entender a pilha da Unreal:**
   > "Descreva o papel de cada parte da pilha de IA da Unreal Engine 5 (AIController, AI Perception, Navigation System, Blackboard, Behavior Trees, EQS, StateTree, Smart Objects, Mass AI) e como elas se conectam num agente típico de shooter. Indique o que pode variar entre versões da engine."

---

## Checklist

- [ ] Sei explicar por que Game AI não busca jogar de forma ótima.
- [ ] Sei descrever o ciclo perceber → decidir → posicionar → navegar → agir.
- [ ] Entendo a ilusão de inteligência e por que apresentação é parte da IA.
- [ ] Conheço as principais arquiteturas de decisão e quando cada uma brilha.
- [ ] Conheço a pilha de IA da Unreal e as ferramentas de depuração.
- [ ] Implementei `AVGAIController` com equipes e configurei Vigia e Presença.
- [ ] Escrevi a especificação de comportamento e apresentação da Presença.

---

## Para ir além

- **Ian Millington, *AI for Games*** (3ª edição) — referência ampla de algoritmos de Game AI (movimento, pathfinding, decisão, tática).
- **Steve Rabin (org.), *Game AI Pro*** — coletânea de artigos de desenvolvedores; vários volumes estão disponíveis gratuitamente no site da série (gameaipro.com).
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Artificial Intelligence** (visão geral), **AI Controllers**, **Gameplay Debugger**, **Visual Logger**.
- **GDC Vault** (gdcvault.com) — a trilha de AI da GDC (incluindo o *AI Summit*) tem décadas de talks; muitas são citadas ao longo da Parte V.

---

➡️ **Próximo:** [Capítulo 34 — FSM](cap-34-fsm.md)

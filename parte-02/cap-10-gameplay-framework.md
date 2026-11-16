# Capítulo 10 — Gameplay Framework

## Objetivo

Ao final deste capítulo você deve conseguir:

- descrever cada classe do **Gameplay Framework** da Unreal — GameInstance, GameMode, GameState, PlayerController, PlayerState, Pawn, Character, HUD, CameraManager — e a responsabilidade de cada uma;
- explicar **onde cada uma existe** (servidor, clientes, só localmente) e por que essa divisão só faz sentido completo quando chega o multiplayer;
- seguir o **fluxo de inicialização** de uma partida: do mapa carregado ao jogador possuindo um pawn;
- entender **possessão**: a separação entre a "vontade" (Controller) e o "corpo" (Pawn);
- decidir **onde mora cada estado** do jogo usando o framework;
- criar as classes de framework da Vigília — e justificar as que **não** criamos.

---

## Contexto

Até agora, o Pátio tem atores, componentes e luzes, mas não tem **jogo**: não há regras, não há jogador com corpo, não há noção de partida. O template Blank colocou um pawn voador padrão porque algo precisava existir. Este capítulo substitui esse improviso pela estrutura que a Unreal oferece para organizar qualquer jogo: o **Gameplay Framework**.

O Gameplay Framework é a parte mais "opinativa" da engine. Ele assume uma certa forma de organizar jogos — derivada, historicamente, de jogos de tiro multiplayer (a linhagem da engine passa por Unreal Tournament) — e oferece classes com papéis definidos. Você pode ignorá-lo, mas trabalhar contra ele é exatamente o tipo de "arquitetura que luta contra a engine" do critério 6 do Capítulo 6. Para um jogo single-player narrativo, nem todas as peças serão usadas a fundo. Mas entender todas é obrigatório — e, na Parte IX, cada uma vai ganhar um significado preciso.

---

## 10.1 As classes e seus papéis

```text
                         UGameInstance  ─────────── sobrevive à troca de níveis
                               │                    (a "sessão" do jogo)
                               │
     ┌─────────────────────── UWorld (um nível carregado) ───────────────────────┐
     │                                                                           │
     │   AGameModeBase ──────── as REGRAS: quem entra, onde nasce, quando acaba  │
     │        │ cria                                                             │
     │        ▼                                                                  │
     │   AGameStateBase ─────── o ESTADO DA PARTIDA visível a todos              │
     │                                                                           │
     │   para cada jogador:                                                      │
     │   APlayerController ──── a VONTADE do jogador: input, câmera, UI          │
     │        │  possui                 │ tem                                    │
     │        ▼                         ▼                                        │
     │   APawn / ACharacter      APlayerState ── dados do jogador visíveis       │
     │   o CORPO no mundo                         a todos (nome, placar)         │
     │                                                                           │
     │   APlayerCameraManager, AHUD ── apresentação local do jogador             │
     └───────────────────────────────────────────────────────────────────────────┘
```

| Classe | Responsabilidade | Existe quanto tempo? |
|---|---|---|
| **`UGameInstance`** | O processo de jogo: o que sobrevive à troca de nível. Hospeda `UGameInstanceSubsystem`s (Capítulo 6). | Do início ao fim da execução |
| **`AGameModeBase`** | **Regras**: classes padrão, onde e como jogadores nascem, quando renascem, condições de vitória. | Um por nível carregado |
| **`AGameStateBase`** | **Estado da partida** compartilhado: tempo, placar do time, fase da partida, lista de PlayerStates. | Um por nível carregado |
| **`APlayerController`** | **A vontade** de um jogador: recebe input, decide o que fazer, controla a câmera, possui a UI daquele jogador. | Enquanto o jogador estiver no nível; sobrevive à morte do pawn |
| **`APlayerState`** | **Dados públicos** de um jogador: nome, pontuação, time. | Enquanto o jogador estiver no nível; sobrevive à morte do pawn |
| **`APawn`** | **O corpo**: qualquer ator que pode ser possuído por um Controller (personagem, veículo, câmera). | Pode morrer e ser recriado várias vezes |
| **`ACharacter`** | Pawn humanoide com cápsula, malha esquelética e `CharacterMovementComponent` (Capítulo 17). | Idem |
| **`APlayerCameraManager`** | O que a câmera daquele jogador mostra, de fato, a cada frame (Capítulo 18). | Junto com o PlayerController |
| **`AHUD`** | Desenho de HUD em *canvas* (legado) e ponto opcional de organização da UI. A UI moderna usa UMG (Capítulo 55). | Junto com o PlayerController |

Note a distinção entre **Controller e Pawn**, e entre **PlayerController e PlayerState**. Elas são as duas ideias mais importantes do framework.

---

## 10.2 Possessão: vontade e corpo

Um **Pawn** é um corpo. Ele sabe se mover, ser atingido, tocar animações. Ele **não** decide o que fazer. Quem decide é um **Controller**, que **possui** o pawn:

```text
   APlayerController ──┐                         ┌── AAIController
   (input humano)      │       Possess()         │   (Behavior Tree, Parte V)
                       └──────────┬──────────────┘
                                  ▼
                         APawn / ACharacter
                    (mesmo corpo, qualquer cérebro)
```

Consequências:

1. **O mesmo pawn pode ser controlado por um humano ou por uma IA.** A Presença da Vigília será um `ACharacter` possuído por um `AAIController`. Em teoria, você poderia possuí-la com o seu PlayerController e "jogar como a Presença" — uma ferramenta de debug excelente para testar se o level design funciona do ponto de vista do inimigo.
2. **Trocar de corpo é trocar de possessão.** Entrar num veículo em GTA, trocar de personagem em GTA V, assumir uma câmera de segurança: conceitualmente, o controller deixa de possuir um pawn e passa a possuir outro.
3. **O controller sobrevive à morte do corpo.** Quando o pawn morre e é destruído, o PlayerController continua existindo — com a câmera, a UI e o input do jogador — até que um pawn novo seja criado e possuído (*respawn*).

> **[INFERÊNCIA]** Em jogos de futebol, o jogador humano troca o atleta controlado o tempo todo — com um botão, ou automaticamente quando a bola muda de região. Num modelo como o da Unreal, isso seria **possessão**: os 22 atletas são pawns; dois são possuídos por PlayerControllers (você e seu primo), e os demais por AIControllers; trocar de atleta é um controller humano trocar de pawn com um controller de IA. Não há informação pública sobre como PES ou FIFA implementam isso internamente — e, na era do PES 2011 e do FIFA 14, ambos usavam motores próprios (o eFootball, sucessor do PES, passou à Unreal Engine em 2021) —, mas o modelo de vontade/corpo descreve o comportamento com precisão. Repare na consequência de design: **o atleta que você deixa de controlar não fica parado** — ele imediatamente ganha um "cérebro" de IA. A transição entre controle humano e IA é invisível, e isso só é possível porque o corpo não sabe quem o controla.

> 🌉 **Ponte:** a separação Controller/Pawn é a separação entre **política e mecanismo** — o mesmo princípio que separa um *scheduler* (decide) de um *executor* (executa), ou um *controller* de reconciliação (decide o que deve existir) dos recursos que ele gerencia.

---

## 10.3 Quem existe onde: o motivo da divisão

Num jogo single-player, todas essas classes vivem na mesma máquina, e a divisão entre GameMode, GameState, PlayerController e PlayerState pode parecer burocracia. Ela faz sentido completo quando se olha o multiplayer (Parte IX):

| Classe | Servidor | Cliente dono | Outros clientes |
|---|:-:|:-:|:-:|
| `UGameInstance` | ✓ (local) | ✓ (local) | ✓ (local) |
| `AGameModeBase` | **✓ só no servidor** | — | — |
| `AGameStateBase` | ✓ | ✓ (replicado) | ✓ (replicado) |
| `APlayerController` | ✓ | ✓ (o seu) | — (não existe o dos outros) |
| `APlayerState` | ✓ | ✓ (replicado) | ✓ (replicado) |
| `APawn` | ✓ | ✓ (replicado) | ✓ (replicado) |
| `AHUD`, `APlayerCameraManager`, widgets | — | ✓ (só local) | — |

Agora cada classe tem um motivo de existir:

- **O GameMode existe só no servidor** porque as regras são autoritativas (Capítulo 64): um cliente não pode decidir que ganhou a partida.
- **O GameState existe** porque os clientes precisam *ver* o estado da partida que o GameMode governa (tempo restante, placar), e eles não têm GameMode.
- **O PlayerController do seu colega não existe na sua máquina** porque ele carrega coisas privadas daquele jogador (input, UI, câmera).
- **O PlayerState existe** porque você precisa ver o *nome e o placar* do seu colega, e o PlayerController dele não está na sua máquina.

Para a Vigília single-player, a regra prática é **seguir as convenções mesmo sem rede**: regras no GameMode, estado da partida no GameState (se houver), dados do jogador onde sobrevivem à morte do pawn, apresentação no lado local. O custo de seguir a convenção é quase zero; o benefício é que a Parte IX e o experimento multiplayer do Capítulo 84 não vão exigir reescrever onde as coisas moram.

---

## 10.4 O fluxo de inicialização

O que acontece entre "o mapa carregou" e "o jogador está andando"? A versão simplificada do fluxo para um jogo local:

```text
 1. UGameInstance::Init                      (uma vez, no início do processo)
 2. Mapa carregado → UWorld criado
 3. GameMode criado                          classe vinda do World Settings do nível
                                             (GameMode Override) ou do padrão do projeto
 4. GameMode::InitGame                       configura a partida
 5. GameState criado pelo GameMode
 6. Atores do nível inicializados            (Cap. 8)
 7. Jogador entra:
      a. PlayerController criado              PlayerControllerClass do GameMode
      b. PlayerState criado                   PlayerStateClass do GameMode
      c. GameMode::PostLogin                  "um jogador entrou"
      d. GameMode escolhe um PlayerStart      ChoosePlayerStart / FindPlayerStart
      e. GameMode cria o pawn                 DefaultPawnClass do GameMode
      f. PlayerController::Possess(Pawn)      a vontade entra no corpo
 8. BeginPlay propagado pelo mundo           (a ordem entre atores não é garantida — Cap. 8)
```

Três pontos de extensão que você vai usar:

- **Classes padrão do GameMode** — `DefaultPawnClass`, `PlayerControllerClass`, `PlayerStateClass`, `GameStateClass`, `HUDClass`. É assim que o jogo escolhe *quais* classes instanciar.
- **Escolha do ponto de nascimento** — sobrescrevendo `ChoosePlayerStart` (para, por exemplo, nascer no último checkpoint — Capítulo 56).
- **Respawn** — `RestartPlayer` recria o pawn de um controller sem pawn; a política de *quando* chamar é do GameMode (Capítulo 32).

### `AGameModeBase` vs. `AGameMode`

A engine oferece duas classes base:

- **`AGameModeBase`** — o essencial: classes padrão, login, spawn de jogadores.
- **`AGameMode`** — acrescenta uma **máquina de estados de partida** (esperando para começar → em andamento → pós-partida) e conceitos de partida multiplayer clássica. Ele exige `AGameState` (e não `AGameStateBase`).

Para a Vigília, `AGameModeBase` é suficiente: não há "partida" com início e fim formais. Para a **Arena** multiplayer da Parte IX, `AGameMode` com sua máquina de estados de partida é a escolha natural.

---

## 10.5 Onde mora cada estado

Esta é a pergunta prática que o framework responde. O critério central é **quanto tempo o estado precisa viver** e **quem precisa vê-lo**:

```text
O estado precisa sobreviver à troca de nível?
   SIM → UGameInstance (melhor: um UGameInstanceSubsystem) + SaveGame
   NÃO ↓
É regra ou configuração da partida?
   SIM → GameMode
   NÃO ↓
É estado da partida que todos precisam ver?
   SIM → GameState
   NÃO ↓
É do jogador e precisa sobreviver à morte do corpo?
   SIM, e é público (placar, nome, time)  → PlayerState
   SIM, e é privado (UI, input, câmera)   → PlayerController
   NÃO ↓
É do corpo e morre com ele?
   SIM → Pawn (ou componente do pawn)
```

Aplicado à Vigília:

| Estado | Onde mora | Por quê |
|---|---|---|
| Fatos narrativos ("encontrou o livro de ocorrências") | `UGameInstanceSubsystem` narrativo (Capítulo 46) | Sobrevive à troca de nível; vai para o save |
| Setores elétricos religados | `UWorldSubsystem` da rede elétrica + save (Capítulos 56–57) | Pertence ao nível da usina |
| Nível de ameaça da Presença | `UWorldSubsystem` (Capítulo 36) | Global ao mundo, um dono |
| Vida da jogadora | Componente de vida no pawn (Capítulo 22) | É do corpo |
| Carga da bateria | `UVGBatteryComponent` na lanterna (Capítulo 4) | É do equipamento |
| Configurações de input e sensibilidade | Configurações do jogador local / `PlayerController` | Privado e local |
| Regras: onde nascer após morrer | GameMode | Regra |

> 🌉 **Ponte:** essa árvore de decisão é uma discussão de **escopo e ciclo de vida** — a mesma que você faz ao decidir se um dado vai em cache de requisição, sessão de usuário ou banco.
>
> 🧱 **Onde a ponte cai:** em backend, o critério dominante é durabilidade e consistência. Aqui, há um critério extra que não existe no seu mundo: **o corpo morre**. O que vive no pawn é perdido no respawn — e às vezes isso é desejado (munição reinicia), às vezes é um bug (a jogadora renasce sem os documentos que coletou).

---

## Estudo de caso: o framework visto por um FPS multiplayer

> **Pergunta:** por que o Gameplay Framework tem tantas classes, e como elas se encaixam num FPS multiplayer clássico?

**[SIMPLIFICAÇÃO DIDÁTICA / HIPOTÉTICO]** O mapeamento abaixo descreve como um modo *Team Deathmatch*, no estilo dos FPS multiplayer clássicos como Call of Duty, **seria** organizado no Gameplay Framework da Unreal. Ele não descreve a implementação de nenhum jogo comercial (a série Call of Duty não usa a Unreal) — é um exercício de como o framework distribui responsabilidades.

```text
TEAM DEATHMATCH — 2 times, primeiro a 75 abates vence, respawn em 3 s

GameMode (servidor)         regras: limite de abates, tempo, respawn após 3 s,
                            escolha do ponto de spawn longe de inimigos (Cap. 32),
                            balanceamento de times na entrada
GameState (todos)           placar por time, tempo restante, fase da partida
PlayerState (todos)         nome, abates, mortes, assistências, time, loadout escolhido
PlayerController (dono)     input, câmera, HUD (mira, minimapa), killcam, menu de classe
Pawn/Character (todos)      o soldado: movimento, arma equipada, vida — morre e renasce
GameInstance (local)        sessão online, conexão com matchmaking, progressão da conta
```

Repare como cada estado vai para a classe certa **por causa do ciclo de vida**:

- os **abates** estão no PlayerState, não no Pawn — senão seriam perdidos a cada morte;
- o **loadout escolhido** também (você escolhe a classe e ela vale no próximo respawn);
- a **vida** está no Pawn — ela deve reiniciar a cada respawn;
- o **placar do time** está no GameState — todos precisam ver; ninguém além do servidor pode alterar;
- a **killcam** está no PlayerController — é apresentação privada daquele jogador.

**Lição:** o Gameplay Framework é, essencialmente, **um conjunto de ciclos de vida e de escopos de visibilidade com nome**. Quando você entende isso, cada classe deixa de ser uma regra arbitrária e passa a ser a resposta à pergunta "por quanto tempo isto vive, e quem pode ver?".

### E o multiplayer local?

Quando você jogava PES com seu primo no mesmo console, havia **dois jogadores locais**. Na Unreal, cada jogador local tem um **`ULocalPlayer`** e um **PlayerController** próprio, no mesmo processo, no mesmo mundo, sob o mesmo GameMode. O input de cada controle é roteado para o PlayerController correspondente; cada um pode ter a sua câmera (tela dividida, que a engine suporta) ou compartilhar uma câmera (como num jogo de futebol, que mostra os dois times na mesma tela). O Capítulo 63 compara esse modelo, em que tudo é local e não há latência, com o multiplayer online.

---

## Comparação com o desenvolvimento tradicional

| Classe do framework | Analogia útil | Onde a analogia cai |
|---|---|---|
| `UGameInstance` | Contexto da aplicação | Existe um por processo; hospeda subsistemas, não beans |
| `AGameModeBase` | Política/regras de negócio de um "processo" | Existe só no servidor em multiplayer; nunca consultado pela UI de cliente |
| `AGameStateBase` | Read model público | É replicado, não projetado de forma eventual |
| `APlayerController` | Sessão de usuário + adaptador de entrada | Persiste por todo o nível; controla câmera e possui pawns |
| `APlayerState` | Perfil público do usuário na sessão | Escopo de nível, não de conta |
| `APawn` | Recurso controlado por um agente | Morre e renasce; o estado nele é efêmero por design |

---

## Implementação: as classes de framework da Vigília

### O que criar — e o que não criar

Seguindo o Capítulo 6 (*generalização depois do terceiro caso concreto*), a Vigília cria apenas as classes de framework que **têm responsabilidade agora ou têm uma necessidade concreta já conhecida**:

| Classe | Criar agora? | Justificativa |
|---|:-:|---|
| `AVGGameMode : AGameModeBase` | **Sim** | Define as classes padrão do jogo; vai ganhar a regra de checkpoint (Cap. 56) |
| `AVGPlayerController : APlayerController` | **Sim** | Vai hospedar os contextos de input (Cap. 14) e a UI (Cap. 55); trocar a classe depois exige atualizar Blueprints e configurações |
| `AVGCharacter : ACharacter` | **Sim** | O corpo da jogadora |
| `AVGGameState` | **Não** | Single-player sem estado de partida compartilhado; o estado global está em subsistemas. Revisto na Parte IX. |
| `AVGPlayerState` | **Não** | Sem dados públicos de jogador em single-player. Revisto na Parte IX. |
| `UVGGameInstance` | **Não** | Estado de sessão vai em `UGameInstanceSubsystem`s, que não exigem uma GameInstance própria |
| `AVGHUD` | **Não** | A UI será feita com UMG, de propriedade do PlayerController (Cap. 55) |

### O GameMode

```cpp
// Source/Vigilia/Core/VGGameMode.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "VGGameMode.generated.h"

/**
 * Regras do jogo single-player da Vigília.
 * Define as classes C++ padrão; o Blueprint BP_VGGameMode substitui pelas classes de conteúdo.
 */
UCLASS()
class VIGILIA_API AVGGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    AVGGameMode();
};
```

```cpp
// Source/Vigilia/Core/VGGameMode.cpp
#include "Core/VGGameMode.h"

#include "Player/VGCharacter.h"
#include "Player/VGPlayerController.h"

AVGGameMode::AVGGameMode()
{
    PlayerControllerClass = AVGPlayerController::StaticClass();
    DefaultPawnClass = AVGCharacter::StaticClass();
}
```

**Por que um Blueprint `BP_VGGameMode` por cima?** O C++ conhece as classes C++ (`AVGCharacter`). O jogo de verdade vai usar um **Blueprint** da personagem (`BP_VGJogadora`), com malha, sons e ajustes de conteúdo. O GameMode C++ não deve conhecer esse Blueprint (Capítulo 6: sistemas não referenciam conteúdo). Então:

```text
AVGGameMode (C++)            DefaultPawnClass = AVGCharacter
      ▲
BP_VGGameMode (Blueprint)    DefaultPawnClass = BP_VGJogadora   ← escolhido no editor
```

E o projeto usa `BP_VGGameMode` como GameMode padrão (*Project Settings → Maps & Modes*).

> **Por que não `ConstructorHelpers::FClassFinder`?** Você vai ver, em templates e tutoriais, construtores que carregam Blueprints por caminho de texto (`TEXT("/Game/FirstPerson/Blueprints/BP_FirstPersonCharacter")`). Funciona, mas acopla o C++ a um caminho de conteúdo: mover o Blueprint quebra a compilação ou o jogo, e o sistema passa a depender do conteúdo. A alternativa adotada — classe C++ com padrões C++, Blueprint filho escolhendo conteúdo — mantém a direção de dependência correta.

### O PlayerController

```cpp
// Source/Vigilia/Player/VGPlayerController.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "VGPlayerController.generated.h"

/**
 * A vontade da jogadora. Ganha responsabilidades no Cap. 14 (contextos de Enhanced Input)
 * e no Cap. 55 (UI). Existe desde já para que GameMode e Blueprints apontem para a classe final.
 */
UCLASS()
class VIGILIA_API AVGPlayerController : public APlayerController
{
    GENERATED_BODY()
};
```

Uma classe vazia é normalmente um sinal de "scaffolding para depois" — algo que o livro critica. Aqui ela é aceitável por um motivo concreto: classes de framework são **referenciadas por configuração** (GameMode, World Settings, Blueprints). Introduzi-la agora evita uma migração de referências depois. A responsabilidade dela chega em quatro capítulos.

### O Character

```cpp
// Source/Vigilia/Player/VGCharacter.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "VGCharacter.generated.h"

class UCameraComponent;

/** O corpo da jogadora: cápsula, movimento (herdado de ACharacter) e câmera em primeira pessoa. */
UCLASS()
class VIGILIA_API AVGCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AVGCharacter();

    UCameraComponent* GetFirstPersonCamera() const { return FirstPersonCamera; }

protected:
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UCameraComponent> FirstPersonCamera;
};
```

```cpp
// Source/Vigilia/Player/VGCharacter.cpp
#include "Player/VGCharacter.h"

#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"

AVGCharacter::AVGCharacter()
{
    PrimaryActorTick.bCanEverTick = false; // o movimento é do CharacterMovementComponent

    // Cápsula: raio 34 cm, meia-altura 88 cm → personagem de ~176 cm.
    GetCapsuleComponent()->InitCapsuleSize(34.0f, 88.0f);

    FirstPersonCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FirstPersonCamera"));
    FirstPersonCamera->SetupAttachment(GetCapsuleComponent());
    // Centro da cápsula fica a 88 cm do chão; +72 cm → olhos a ~160 cm.
    FirstPersonCamera->SetRelativeLocation(FVector(0.0, 0.0, 72.0));
    // A câmera segue a rotação do Controller (a "mira" da jogadora), não a da cápsula.
    FirstPersonCamera->bUsePawnControlRotation = true;
}
```

Duas decisões merecem explicação:

- **As medidas da cápsula e da câmera vêm das métricas de escala do Capítulo 7.** Elas serão ajustadas por *feel* no Capítulo 25, mas começam corretas.
- **`bUsePawnControlRotation = true`.** O Controller guarda uma rotação — a *control rotation*, para onde a jogadora está olhando. O pawn, por padrão, gira apenas em *yaw* com ela (o corpo vira para os lados, mas não inclina para cima e para baixo), e a câmera, com esta opção, segue a rotação completa. É mais uma expressão da separação vontade/corpo: **a mira pertence ao Controller**. O Capítulo 18 aprofunda.

### Configurando o projeto

1. Compile (feche o editor: classes novas e headers reflexivos — Capítulo 7).
2. Crie `BP_VGJogadora` (filho de `AVGCharacter`) em `/Game/Vigilia/Blueprints/Player/`. Ainda sem malha: a jogadora é uma cápsula invisível com uma câmera.
3. Crie `BP_VGGameMode` (filho de `AVGGameMode`) e defina `Default Pawn Class = BP_VGJogadora`.
4. *Project Settings → Maps & Modes → Default GameMode = BP_VGGameMode*.
5. Aperte *Play* no Pátio: você nasce no `Player Start`, na altura dos olhos, olhando para a frente — e **não consegue se mover**.

Isso é esperado: o pawn existe e está possuído, mas nenhum input está conectado. O Capítulo 14 resolve isso com Enhanced Input. Até lá, use *Simulate* ou ejete (`F8`) para voar pelo nível — e observe, no Outliner, os atores que o framework criou: `BP_VGGameMode`, `GameStateBase`, `VGPlayerController`, `PlayerState`, `PlayerCameraManager`, `BP_VGJogadora`.

---

## Decisões arquiteturais

1. **Classes de framework só quando há responsabilidade concreta.** Vigília: GameMode, PlayerController, Character. Sem GameState, PlayerState, GameInstance ou HUD próprios até haver necessidade.
2. **C++ define classes padrão C++; Blueprints filhos escolhem conteúdo.** Nada de `ConstructorHelpers` com caminhos de asset.
3. **Estado vai para onde o ciclo de vida pede**, segundo a árvore da seção 10.5.
4. **Seguir as convenções de multiplayer mesmo em single-player:** regras no GameMode, apresentação local, dados que sobrevivem à morte fora do pawn.
5. **A mira pertence ao Controller** (*control rotation*); o pawn e a câmera a seguem.
6. **`AGameModeBase` para a Vigília; `AGameMode` para a Arena** (Parte IX).

---

## Armadilhas

- **Estado que precisa sobreviver à morte no Pawn** (documentos coletados, progresso).
- **UI consultando o GameMode** — funciona em single-player e quebra no cliente em multiplayer.
- **Lógica de input no Pawn quando ela pertence ao Controller** (ou vice-versa) — o Capítulo 16 discute a fronteira.
- **Criar todas as classes do framework "por completude".**
- **`ConstructorHelpers` com caminhos de Blueprints** no C++.
- **Esquecer o GameMode Override** nas World Settings de um nível de teste — e não entender por que o pawn é outro.
- **Assumir que o pawn existe no `BeginPlay` do PlayerController** — a possessão pode acontecer depois. Para reagir à possessão, use os eventos próprios (`OnPossess` no Controller, `PossessedBy` no Pawn).
- **Confundir `AGameModeBase` com `AGameMode`** e misturar com `AGameStateBase`/`AGameState`.

---

## Exercício

**Parte 1 — observação (45 min).** Dê *Play* no Pátio, ejete com `F8` e encontre no Outliner cada classe do framework. Para cada uma, registre no `DEVLOG.md` a classe concreta instanciada e de onde veio a decisão (Project Settings, World Settings, GameMode).

**Parte 2 — implementação (1 h).** Crie `AVGGameMode`, `AVGPlayerController` e `AVGCharacter`, os Blueprints filhos, e configure o projeto. Crie um nível de testes `L_Dev_Framework` em `/Game/Developers/` com um **GameMode Override** diferente (por exemplo, o GameMode padrão da engine) e observe a diferença.

**Parte 3 — possessão (1 h).** Coloque no Pátio uma segunda instância de `BP_VGJogadora` (sem ser criada pelo GameMode). No Blueprint do `AVGPlayerController` (crie um `BP_VGPlayerController` se quiser), use um evento de tecla de debug para alternar a possessão entre os dois corpos (`Possess`). O que acontece com a câmera? E com o pawn que ficou sem controller?

**Parte 4 — onde mora o estado (30 min).** Classifique, com a árvore da seção 10.5, dez estados da Vigília que você listou no Capítulo 4 (seção 4.1). Algum deles mudou de lugar em relação ao que você imaginava?

---

## Desafio — a Presença jogável

Sem nenhuma IA ainda, faça o seguinte experimento de design: crie um `BP_PresencaTeste` (outro filho de `AVGCharacter`, com uma cápsula maior e uma câmera mais baixa, como se fosse uma criatura curvada) e coloque-o no Pátio. Com a troca de possessão da Parte 3, **jogue como a Presença**: posicione-se em pontos onde ela poderia emboscar a jogadora.

Responda:
1. De que pontos do Pátio a Presença vê a jogadora chegar sem ser vista?
2. Que mudanças no grey-box tornariam o Pátio mais tenso para a jogadora (mais pontos cegos, mais linhas de visão interrompidas)?
3. Por que esse experimento só é possível porque o framework separa Controller de Pawn?

Aplique pelo menos uma mudança no grey-box com base nas respostas.

---

## Uso de IA

1. **Para fixar o framework:**
   > "Explique o Gameplay Framework da Unreal Engine 5 (GameInstance, GameMode, GameState, PlayerController, PlayerState, Pawn, Character, HUD) a partir dos ciclos de vida e de onde cada classe existe num jogo multiplayer com servidor dedicado. Para um modo Team Deathmatch hipotético, diga em que classe ficariam: placar do time, abates de um jogador, vida, loadout escolhido, killcam, tempo restante e regras de respawn — justificando cada escolha."

2. **Para depurar a inicialização:**
   > "Na Unreal Engine 5, meu pawn não é o que eu configurei no GameMode padrão do projeto. Liste, em ordem, todos os lugares onde a classe do pawn e do GameMode podem estar sendo definidas ou sobrescritas (Project Settings, World Settings, Blueprints, linha de comando, código) e como verificar cada um."

3. **Para pensar em possessão:**
   > "Dê cinco exemplos de mecânicas de jogos conhecidos que podem ser descritas como troca de possessão entre Controller e Pawn (por exemplo, entrar em veículos, trocar de personagem, controlar câmeras de segurança). Para cada uma, explique o que acontece com o pawn que ficou sem controle humano e que problemas de design e de implementação surgem."

---

## Checklist

- [ ] Sei a responsabilidade de cada classe do Gameplay Framework.
- [ ] Sei onde cada classe existe em multiplayer e por que isso justifica a divisão.
- [ ] Sei explicar possessão e dar exemplos de troca de corpo.
- [ ] Conheço o fluxo de inicialização até o jogador possuir um pawn.
- [ ] Sei a diferença entre `AGameModeBase` e `AGameMode`.
- [ ] Sei aplicar a árvore de decisão "onde mora este estado?".
- [ ] Criei `AVGGameMode`, `AVGPlayerController`, `AVGCharacter` e os Blueprints filhos, e sei justificar as classes que não criei.
- [ ] Sei por que não usar `ConstructorHelpers` com caminhos de conteúdo.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — a seção **Gameplay Framework**, com páginas para cada classe, e o **Gameplay Framework Quick Reference**.
- **Exi (Cedric Neukirchen), *Multiplayer Network Compendium*** (originalmente um PDF, o *UE4 Network Compendium*) — documento comunitário amplamente usado, que explica o framework do ponto de vista do multiplayer; será leitura central na Parte IX. (Verifique a versão mais recente disponível.)

---

➡️ **Próximo:** [Capítulo 11 — C++ na Unreal](cap-11-cpp-na-unreal.md)

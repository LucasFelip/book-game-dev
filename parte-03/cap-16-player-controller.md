# PARTE III — Gameplay Programming

*Projeto 2 (início): FPS básico — "Galpão de Testes" · Projeto 3: Interação*

---

# Capítulo 16 — Player Controller

## Objetivo

Ao final deste capítulo você deve conseguir:

- delimitar com precisão as responsabilidades do **PlayerController** — e o que **não** pertence a ele;
- reagir corretamente à **possessão** (`OnPossess`, `OnUnPossess`) e à troca de corpo;
- controlar o que o jogador vê com **view targets** e transições de câmera (`SetViewTargetWithBlend`);
- organizar o input como uma **pilha de modos** (exploração, leitura, cinemática, UI), substituindo flags espalhadas;
- usar **pausa**, **modos de input da UI** e o **CheatManager** do jeito previsto pela engine;
- refatorar o PlayerController da Vigília para que ele seja o "dono do modo" da jogadora.

---

## Contexto

A Parte II tratou o PlayerController como coadjuvante: ele recebeu um contexto de input (Capítulo 14) e um comando de console (Capítulo 11). Na Parte III, começa a programação de gameplay propriamente dita, e o primeiro passo é dar ao controller o papel que o Gameplay Framework reserva para ele: **a vontade persistente do jogador**.

Persistente é a palavra-chave. O pawn morre, troca, entra em cinemática, fica sem controle. O controller **continua**: é ele quem sabe que a jogadora está lendo um documento, que o jogo está pausado, que a câmera está mostrando uma cena, que ela acabou de morrer e está esperando o checkpoint. Tudo que diz respeito ao **jogador como pessoa diante do jogo** — e não ao **corpo no mundo** — mora aqui.

---

## 16.1 O que pertence ao PlayerController

Uma forma útil de pensar: o PlayerController é a **sessão** do jogador dentro do mundo. A partir das decisões dos Capítulos 10 e 14:

| Pertence ao PlayerController | Pertence ao Pawn |
|---|---|
| Quais **modos/contextos de input** estão ativos | Ações que o **corpo** sabe fazer (andar, pular, agachar) |
| A **control rotation** (para onde o jogador mira) | A orientação do corpo (que segue a mira em yaw) |
| **O que a câmera mostra** (view target, transições) | A câmera em primeira pessoa **do corpo** |
| **UI** do jogador: HUD, menus, telas de documento | Feedback físico do corpo (animação, sons dos passos) |
| **Pausa**, modo de input da UI, cursor | — |
| Comandos de debug e cheats (via CheatManager) | — |
| Reação à **morte e ao respawn** do ponto de vista do jogador (tela de morte, aguardar checkpoint) | A morte em si (animação, ragdoll, desativar colisão) |

E, igualmente importante, o que **não** pertence a nenhum dos dois:

- **Regras** (quando renascer, onde, condições de fim) → GameMode (Capítulo 10).
- **Estado global** (narrativa, tempo, ameaça) → subsistemas (Capítulo 6).
- **Estado do equipamento** (bateria, munição) → componentes dos equipamentos.

> 🌉 **Ponte:** se o pawn é um "recurso" controlado, o PlayerController é o **agente de sessão** — como o contexto de sessão de um usuário numa aplicação: sabe em que tela ele está, que permissões tem, que modais estão abertos.
>
> 🧱 **Onde a ponte cai:** uma sessão web é passiva — espera requisições. O PlayerController é **ativo**: tica, controla a câmera, possui corpos, recebe input a cada frame. E, em multiplayer, ele existe em **duas máquinas** ao mesmo tempo (servidor e cliente dono — Capítulo 10, seção 10.3), o que impõe cuidados que começam já neste capítulo.

---

## 16.2 Possessão como ciclo de vida

O Capítulo 10 apresentou a possessão; aqui ela vira algo a que o código reage. Os pontos de entrada:

| Onde | Evento | Quando |
|---|---|---|
| `AController` | `OnPossess(APawn*)` | O controller acabou de possuir um pawn |
| `AController` | `OnUnPossess()` | Deixou de possuir |
| `APawn` | `PossessedBy(AController*)` | O pawn foi possuído |
| `APawn` | `UnPossessed()` | O pawn foi liberado |
| `APawn` | `NotifyControllerChanged()` | O controller do pawn mudou (inclusive para nulo) |

Duas regras práticas:

1. **Não assuma que o pawn existe no `BeginPlay` do controller.** O controller pode iniciar antes de o GameMode criar o pawn, ou pode estar sem pawn (morto, espectador). Lógica que depende do pawn vai em `OnPossess`.
2. **Em multiplayer, `OnPossess` executa no servidor.** O cliente fica sabendo da possessão por outros caminhos (o pawn replicado chega e o controller local é associado a ele). Para lógica de **apresentação local** ao trocar de corpo (por exemplo, trocar o contexto de input de "personagem" para "veículo"), o ponto de entrada no cliente é outro — `AcknowledgePossession` e os eventos do pawn como `NotifyControllerChanged` são os caminhos usuais. A Parte IX aprofunda; por ora, saiba que o lugar "óbvio" não é o lugar certo em todos os casos.

---

## 16.3 O que a câmera mostra: view targets

O PlayerController decide **de qual ator a câmera do jogador está tirando a vista**: o **view target**. Normalmente é o pawn possuído (e a câmera em primeira pessoa dele). Mas pode ser qualquer ator com uma câmera — uma câmera de cinemática, uma câmera de segurança da usina, um ponto de vista dramático:

```cpp
// Transição suave de 1,5 s para a câmera de uma cena; a jogadora continua possuindo o corpo.
SetViewTargetWithBlend(CutsceneCameraActor, 1.5f, EViewTargetBlendFunction::VTBlend_EaseInOut, 2.0f);

// Volta para o próprio pawn.
SetViewTargetWithBlend(GetPawn(), 1.0f);
```

Note a separação: **possuir** (quem eu controlo) e **ver** (de onde eu vejo) são coisas diferentes. A jogadora pode continuar possuindo o corpo — com input desativado — enquanto a câmera mostra o corredor por onde a Presença acabou de passar. É a base das transições entre gameplay e cinemática do Capítulo 49 e do estudo de caso de GTA V deste capítulo.

---

## 16.4 Modos de input como pilha

O Capítulo 14 introduziu contextos empilhados por prioridade e, no exercício, funções `EnterReadingMode`/`ExitReadingMode`. Com mais modos chegando (cinemática, UI, inventário), esse par de funções por modo não escala: cada modo precisaria saber como desligar os outros, e uma combinação inesperada (um menu aberto **durante** a leitura de um documento) produziria estados estranhos.

A estrutura certa é uma **pilha de modos**, com um dono — o PlayerController:

```text
       topo  ┌────────────────────┐
             │   UI (pausa)       │  ← contexto IMC_UI, cursor visível, input só UI
             ├────────────────────┤
             │   Leitura          │  ← contexto IMC_Leitura (consome A/D/E)
             ├────────────────────┤
       base  │   Exploração       │  ← contexto IMC_Exploracao (sempre na base)
             └────────────────────┘

  Push(Leitura)  → adiciona IMC_Leitura;            o modo efetivo é Leitura
  Push(UI)       → adiciona IMC_UI; mostra cursor;  o modo efetivo é UI
  Pop(UI)        → remove IMC_UI; esconde cursor;   volta a Leitura
  Pop(Leitura)   → remove IMC_Leitura;              volta a Exploração
```

Propriedades:

- **Cada modo se descreve** por dados: qual contexto de input adiciona, com que prioridade, se mostra o cursor, se o input vai para o jogo, para a UI ou para ambos.
- **O modo efetivo é o topo.** O cursor e o modo de input da UI seguem o topo; os contextos de input se compõem (todos os da pilha estão ativos, e a prioridade resolve conflitos — Capítulo 14).
- **Push e Pop são simétricos.** Quem empilhou, desempilha. Para evitar que um sistema desempilhe o modo de outro, o `Pop` recebe o modo esperado e verifica.

> 🌉 **Ponte:** é a pilha de navegação de uma UI móvel, ou a pilha de *handlers* de um sistema de janelas modais: o topo recebe o foco; fechar o topo devolve o foco ao anterior.

### Modo de input da UI e cursor

O PlayerController tem três modos de input "de janela":

- `FInputModeGameOnly` — input vai só para o jogo; cursor escondido e capturado.
- `FInputModeUIOnly` — input vai só para a UI (com um widget em foco).
- `FInputModeGameAndUI` — os dois; útil para telas que mostram UI sobre o jogo rodando.

Combinado com `bShowMouseCursor`, isso define a relação entre o jogo e a interface. Na pilha de modos, cada modo declara o seu.

### Pausa

`SetPause(true)` (ou `UGameplayStatics::SetGamePaused`) pausa o mundo (Capítulo 3, seção 3.7). Pausar é uma decisão do **jogador** (abrir o menu), por isso é natural que o PlayerController a centralize — e que o modo UI de pausa empilhado seja o que pausa e despausa.

---

## 16.5 CheatManager

O Capítulo 11 criou um comando `Exec` (`VGDumpTimeDilation`) no PlayerController. Funciona, mas mistura ferramentas de desenvolvimento com a classe que vai para o jogador. A engine tem uma classe dedicada: **`UCheatManager`**, instanciada pelo PlayerController em builds de desenvolvimento (e, por padrão, não em Shipping), cujas funções `Exec` ficam disponíveis no console.

🔁 **Refatoração:** os comandos de debug da Vigília migram para `UVGCheatManager`. O PlayerController apenas declara qual classe de cheat manager usar.

```cpp
// Source/Vigilia/Debug/VGCheatManager.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/CheatManager.h"
#include "VGCheatManager.generated.h"

/** Comandos de desenvolvimento da Vigília. Não disponível em builds Shipping (padrão da engine). */
UCLASS()
class VIGILIA_API UVGCheatManager : public UCheatManager
{
    GENERATED_BODY()

public:
    UFUNCTION(Exec)
    void VGDumpTimeDilation();

    UFUNCTION(Exec)
    void VGDumpInputModes();
};
```

```cpp
// Source/Vigilia/Debug/VGCheatManager.cpp
#include "Debug/VGCheatManager.h"

#include "Core/VGLog.h"
#include "Core/VGTimeDilationSubsystem.h"
#include "Player/VGPlayerController.h"

void UVGCheatManager::VGDumpTimeDilation()
{
    const UVGTimeDilationSubsystem* Time = GetWorld()->GetSubsystem<UVGTimeDilationSubsystem>();
    if (!Time)
    {
        UE_LOG(LogVigilia, Warning, TEXT("VGDumpTimeDilation: subsistema indisponível."));
        return;
    }
    TArray<FString> Lines;
    Time->DescribeRequests(Lines);
    for (const FString& Line : Lines)
    {
        UE_LOG(LogVigilia, Display, TEXT("%s"), *Line);
    }
}

void UVGCheatManager::VGDumpInputModes()
{
    if (const AVGPlayerController* PC = Cast<AVGPlayerController>(GetOuterAPlayerController()))
    {
        UE_LOG(LogVigilia, Display, TEXT("%s"), *PC->DescribeInputModes());
    }
}
```

E, no construtor do PlayerController, `CheatClass = UVGCheatManager::StaticClass();`. O Capítulo 61 expande o cheat manager com teleporte, invulnerabilidade, ligar/desligar a IA e outros atalhos de teste.

---

## Estudo de caso: GTA V — trocar de personagem sem parar o mundo

> **Pergunta:** como um jogo troca o corpo que o jogador controla de forma que pareça natural — e que os outros personagens pareçam continuar vivendo?

### O que é publicamente conhecido

**[FATO PÚBLICO]** Em *GTA V* (Rockstar, 2013), o jogador alterna entre três protagonistas — Michael, Franklin e Trevor — fora das missões e, em várias missões, durante a ação. Fora das missões, a troca é apresentada com uma transição em que a câmera se afasta para uma vista aérea alta da cidade e então "mergulha" até a localização do outro personagem. Ao chegar, o personagem frequentemente é encontrado no meio de alguma atividade cotidiana (dirigindo, numa conversa, numa situação cômica), o que reforça a impressão de que ele estava vivendo enquanto não era controlado.

### 1. Experiência

Três vidas paralelas numa cidade que continua funcionando. O jogador sente que **escolhe para onde olhar**, não que o mundo estava pausado esperando por ele.

### 2. Sistema

```text
 escolha do personagem (UI, roda de seleção)
        │
        ▼
 TRANSIÇÃO DE CÂMERA (afastar → vista aérea → aproximar)   ← view target + blend
        │  enquanto isso, longe dos olhos do jogador:
        │   - o destino é carregado (streaming)
        │   - o personagem de destino é posicionado numa atividade
        │   - o personagem de origem passa a ser controlado pelo jogo
        ▼
 POSSESSÃO DO NOVO CORPO                                   ← controller troca de pawn
        │
        ▼
 o corpo anterior: removido, ou entregue a outro "cérebro" ← AI controller / despawn
```

### 3. Design

A decisão central é **transformar uma operação técnica cara e descontínua — saltar para outro ponto do mapa — em espetáculo**. A transição aérea não é só bonita: ela **comunica a geografia** (o jogador vê onde o outro personagem está em relação ao anterior) e **esconde o trabalho** de carregar o destino. A "atividade" em que o personagem é encontrado transforma o salto em narrativa: a cidade e as pessoas tinham vida própria.

### 4. Tecnologia

**[INFERÊNCIA]** Sem nenhuma afirmação sobre a implementação da Rockstar, o comportamento é compatível com:

- a **separação entre ver e possuir** (seção 16.3): a câmera inicia a transição antes de a possessão mudar;
- a transição como **janela de carregamento disfarçada**: a duração e as fases da animação de câmera dão tempo ao sistema de *streaming* para carregar a região de destino (Capítulo 57);
- a "vida" do personagem não controlado como **estado narrativo e de agenda**, e não como simulação contínua: o jogo não precisa ter simulado Franklin dirigindo pela cidade durante meia hora; basta escolher, no momento da troca, uma atividade plausível para aquele personagem, naquele horário, naquele ponto da história, e posicioná-lo nela. (O Interlúdio II aprofunda: "o mundo continua existindo quando eu não estou olhando" é, em grande parte, **decidido no momento em que eu volto a olhar**.)

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]** Na Vigília não há três protagonistas, mas a técnica serve a um momento planejado do projeto final: a jogadora observa, por uma **câmera de segurança** da usina, a Presença atravessando um corredor. Versão mínima:

```text
1. A jogadora interage com um monitor (Cap. 19).
2. PushInputMode(Cinematic): input de movimento desligado; só "sair".
3. SetViewTargetWithBlend(CameraDeSeguranca, 0.8 s).
4. Um evento roteirizado (Cap. 4/49) faz a Presença cruzar o quadro.
5. Ao sair: SetViewTargetWithBlend(Pawn, 0.5 s); PopInputMode(Cinematic).
```

A jogadora **nunca deixou de possuir o próprio corpo**. Ela apenas viu de outro lugar.

### 6. Lição

**Ver e possuir são independentes, e essa independência é uma ferramenta de design.** Transições de câmera servem para comunicar, criar tensão e esconder custo técnico. E a sensação de um mundo com vida própria pode ser produzida **na hora de olhar**, e não necessariamente simulada o tempo todo.

---

## Comparação com o desenvolvimento tradicional

| PlayerController | O que você conhece | Onde a analogia cai |
|---|---|---|
| Vontade persistente do jogador | Contexto de sessão | É ativo (tica, controla câmera) e existe em duas máquinas em multiplayer |
| `OnPossess`/`OnUnPossess` | Eventos de associação a um recurso | Executam no servidor em multiplayer |
| View target | Escolher qual "visão" renderizar | Independente de quem é controlado |
| Pilha de modos | Pilha de navegação / modais | Compõe contextos de input simultâneos por prioridade |
| CheatManager | Endpoints de *actuator*/admin só em ambientes de dev | Removido do build final por padrão |

---

## Implementação: o PlayerController como dono do modo

### O modo e sua descrição

```cpp
// Source/Vigilia/Player/VGInputModes.h
#pragma once

#include "CoreMinimal.h"
#include "VGInputModes.generated.h"

class UInputMappingContext;

UENUM(BlueprintType)
enum class EVGInputMode : uint8
{
    Exploration,
    Reading,
    Cinematic,
    UI
};

/** Como um modo de input se comporta. Configurado no Blueprint do PlayerController. */
USTRUCT(BlueprintType)
struct FVGInputModeConfig
{
    GENERATED_BODY()

    UPROPERTY(EditDefaultsOnly, Category = "Input")
    TObjectPtr<UInputMappingContext> Context;

    UPROPERTY(EditDefaultsOnly, Category = "Input")
    int32 Priority = 0;

    UPROPERTY(EditDefaultsOnly, Category = "Input")
    bool bShowCursor = false;

    /** Se verdadeiro, input vai para a UI e para o jogo; se falso, só para o jogo. */
    UPROPERTY(EditDefaultsOnly, Category = "Input")
    bool bUIReceivesInput = false;

    /** Se verdadeiro, o mundo é pausado enquanto este modo estiver no topo. */
    UPROPERTY(EditDefaultsOnly, Category = "Input")
    bool bPausesGame = false;
};
```

Um `USTRUCT` aqui é justificado (ao contrário do pedido de dilatação do Capítulo 6): ele é **editado no editor** — o designer configura cada modo no Blueprint do controller.

### O PlayerController

```cpp
// Source/Vigilia/Player/VGPlayerController.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "Player/VGInputModes.h"
#include "VGPlayerController.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGInputModeChangedSignature,
    EVGInputMode, OldMode, EVGInputMode, NewMode);

/**
 * A vontade persistente da jogadora: dona da pilha de modos de input, do que a câmera mostra
 * e (Cap. 55) da UI. A base da pilha é sempre Exploration.
 */
UCLASS()
class VIGILIA_API AVGPlayerController : public APlayerController
{
    GENERATED_BODY()

public:
    AVGPlayerController();

    /** Empilha um modo. Empilhar um modo que já está na pilha é ignorado. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Input")
    void PushInputMode(EVGInputMode Mode);

    /** Desempilha o modo indicado, que deve estar no topo. Exploration nunca é removido. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Input")
    void PopInputMode(EVGInputMode Mode);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Input")
    EVGInputMode GetCurrentInputMode() const;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Input")
    FVGInputModeChangedSignature OnInputModeChanged;

    FString DescribeInputModes() const;

protected:
    virtual void BeginPlay() override;
    virtual void OnPossess(APawn* InPawn) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TMap<EVGInputMode, FVGInputModeConfig> InputModeConfigs;

private:
    void ApplyContext(EVGInputMode Mode, bool bAdd);
    void ApplyTopMode();

    TArray<EVGInputMode> ModeStack;
};
```

```cpp
// Source/Vigilia/Player/VGPlayerController.cpp
#include "Player/VGPlayerController.h"

#include "Core/VGLog.h"
#include "Debug/VGCheatManager.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/LocalPlayer.h"
#include "InputMappingContext.h"

AVGPlayerController::AVGPlayerController()
{
    CheatClass = UVGCheatManager::StaticClass();
}

void AVGPlayerController::BeginPlay()
{
    Super::BeginPlay();
    if (IsLocalController())
    {
        PushInputMode(EVGInputMode::Exploration); // a base da pilha
    }
}

void AVGPlayerController::OnPossess(APawn* InPawn)
{
    Super::OnPossess(InPawn);
    // Ao (re)possuir um corpo — inclusive após respawn —, garante que a câmera volta para ele.
    SetViewTarget(InPawn);
}

void AVGPlayerController::PushInputMode(EVGInputMode Mode)
{
    if (!IsLocalController() || ModeStack.Contains(Mode))
    {
        return;
    }

    const EVGInputMode OldMode = GetCurrentInputMode();
    ModeStack.Push(Mode);
    ApplyContext(Mode, /*bAdd=*/true);
    ApplyTopMode();

    if (ModeStack.Num() > 1)
    {
        OnInputModeChanged.Broadcast(OldMode, Mode);
    }
}

void AVGPlayerController::PopInputMode(EVGInputMode Mode)
{
    if (!IsLocalController() || Mode == EVGInputMode::Exploration)
    {
        return;
    }
    if (!ensureMsgf(!ModeStack.IsEmpty() && ModeStack.Last() == Mode,
                    TEXT("PopInputMode(%s) fora de ordem. Pilha: %s"),
                    *UEnum::GetValueAsString(Mode), *DescribeInputModes()))
    {
        return;
    }

    ModeStack.Pop();
    ApplyContext(Mode, /*bAdd=*/false);
    ApplyTopMode();
    OnInputModeChanged.Broadcast(Mode, GetCurrentInputMode());
}

EVGInputMode AVGPlayerController::GetCurrentInputMode() const
{
    return ModeStack.IsEmpty() ? EVGInputMode::Exploration : ModeStack.Last();
}

void AVGPlayerController::ApplyContext(EVGInputMode Mode, bool bAdd)
{
    const FVGInputModeConfig* Config = InputModeConfigs.Find(Mode);
    UEnhancedInputLocalPlayerSubsystem* Input =
        ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer());

    if (!Config || !Config->Context || !Input)
    {
        UE_LOG(LogVigilia, Warning, TEXT("%s: modo %s sem configuração de contexto."),
            *GetName(), *UEnum::GetValueAsString(Mode));
        return;
    }

    if (bAdd)
    {
        Input->AddMappingContext(Config->Context, Config->Priority);
    }
    else
    {
        Input->RemoveMappingContext(Config->Context);
    }
}

void AVGPlayerController::ApplyTopMode()
{
    const FVGInputModeConfig* Config = InputModeConfigs.Find(GetCurrentInputMode());
    const bool bShowCursor = Config && Config->bShowCursor;
    const bool bUI = Config && Config->bUIReceivesInput;
    const bool bPause = Config && Config->bPausesGame;

    SetShowMouseCursor(bShowCursor);
    if (bUI)
    {
        SetInputMode(FInputModeGameAndUI());
    }
    else
    {
        SetInputMode(FInputModeGameOnly());
    }
    SetPause(bPause);
}

FString AVGPlayerController::DescribeInputModes() const
{
    FString Result = TEXT("Pilha de modos (base → topo):");
    for (const EVGInputMode Mode : ModeStack)
    {
        Result += TEXT(" ") + UEnum::GetValueAsString(Mode);
    }
    return Result;
}
```

### Explicação das decisões

- **🔁 Refatoração do Capítulo 14.** O `ExplorationContext` solto e as funções `EnterReadingMode`/`ExitReadingMode` do exercício somem: tudo vira configuração de modos (`InputModeConfigs`) e duas operações simétricas.
- **A configuração é um `TMap` editável** no `BP_VGPlayerController`: para cada modo, qual contexto, prioridade, cursor, UI e pausa. Adicionar um modo novo é adicionar um valor ao enum e uma entrada no mapa.
- **`PopInputMode` exige o modo esperado e verifica a ordem com `ensure`.** Um sistema que desempilha o modo de outro é um bug de lógica — recuperável (não derruba o jogo), mas que precisa aparecer no log com a pilha atual. É a regra do dono único aplicada à pilha: **quem empilhou é dono daquele nível**.
- **`Exploration` nunca sai da pilha.** A base é garantida, o que elimina o estado "nenhum modo ativo".
- **`ApplyTopMode` recalcula cursor, modo de UI e pausa a partir do topo** em vez de cada modo "desfazer" o que fez. É o mesmo princípio do subsistema de dilatação do Capítulo 6: **um valor efetivo derivado do estado**, recalculado a cada mudança, em vez de mutações incrementais que podem dessincronizar.
- **`IsLocalController()` em todas as operações**: modos de input são locais (Capítulo 14).
- **`OnInputModeChanged`** permite que a UI (Capítulo 55), o áudio (abafar o som do mundo ao abrir um documento) e a câmera reajam sem que o controller saiba deles.
- **`OnPossess` reposiciona o view target.** Depois de uma cinemática que tenha mudado a câmera, ou de um respawn, a jogadora sempre volta a ver pelo próprio corpo.

### Configurando

No `BP_VGPlayerController`, preencha `InputModeConfigs`:

| Modo | Contexto | Prioridade | Cursor | UI recebe input | Pausa |
|---|---|:-:|:-:|:-:|:-:|
| Exploration | `IMC_Exploracao` | 0 | ✗ | ✗ | ✗ |
| Reading | `IMC_Leitura` | 10 | ✗ | ✗ | ✗ |
| Cinematic | `IMC_Cinematica` | 20 | ✗ | ✗ | ✗ |
| UI | `IMC_UI` | 30 | ✓ | ✓ | ✓ |

(Crie `IMC_Cinematica` e `IMC_UI` mínimos, com uma ação de "sair"/"voltar" cada.)

> **Atenção à pausa:** com o jogo pausado, Input Actions comuns deixam de disparar. As ações do modo UI (por exemplo, `IA_Voltar`) precisam ter a opção **Trigger when Paused** habilitada no asset da ação — senão a jogadora pausa e não consegue despausar.

O modo `Cinematic` não precisa **remover** a exploração para impedir o movimento: basta que `IMC_Cinematica`, com prioridade maior, mapeie e **consuma** as teclas de movimento (sem ligá-las a nada), ou que o pawn ignore input enquanto o modo estiver ativo. A primeira opção mantém tudo em configuração; a escolha fica registrada no `DEVLOG.md`.

---

## Decisões arquiteturais

1. **O PlayerController é a vontade persistente:** modos de input, mira, view target, UI, pausa, reação do jogador à morte.
2. **Lógica que depende do pawn vai em `OnPossess`**, não em `BeginPlay`; em multiplayer, a contraparte de cliente será tratada na Parte IX.
3. **Ver e possuir são independentes** (`SetViewTargetWithBlend`).
4. **Pilha de modos de input** com configuração por dados, operações simétricas e base fixa (`Exploration`).
5. **Estado efetivo recalculado a partir do topo** (cursor, UI, pausa), nunca desfeito incrementalmente.
6. **Ferramentas de desenvolvimento no `UVGCheatManager`**, fora do PlayerController.

---

## Armadilhas

- **Assumir que `GetPawn()` é válido no `BeginPlay` do controller.**
- **Flags de modo espalhadas** em vez de uma pilha com dono.
- **`Pop` sem verificação** — um sistema desfazendo o modo de outro.
- **Esquecer de devolver o view target** ao pawn depois de uma cena.
- **Pausar sem um modo de UI ativo**, deixando a jogadora sem forma de despausar.
- **Comandos de debug no PlayerController de produção.**
- **Lógica de corpo no controller** (ex.: tocar sons de passo) ou de sessão no pawn (ex.: guardar qual menu está aberto).

---

## Exercício

**Parte 1 — a pilha (1,5 h).** Implemente `EVGInputMode`, `FVGInputModeConfig`, a pilha no `AVGPlayerController` e o `UVGCheatManager`. Configure os quatro modos. Crie atalhos de teste (no `IMC_Debug` ou por comandos `Exec` no cheat manager) para empilhar e desempilhar cada modo, e verifique com `VGDumpInputModes`: o cursor aparece só no modo UI; o jogo pausa só no modo UI; `A`/`D` viram páginas no modo leitura.

**Parte 2 — ordem errada (20 min).** Empilhe `Reading` e depois `UI`, e tente desempilhar `Reading`. Observe o `ensure` no log, com a pilha. Por que um `check` seria a escolha errada aqui?

**Parte 3 — câmera de segurança (1,5 h).** No Pátio, coloque um `CameraActor` no alto da guarita, apontando para a estrada. Implemente a "versão mínima" do estudo de caso de GTA V: um comando de teste empilha `Cinematic`, faz blend para a câmera, espera 4 s (ou até a ação "sair") e volta. Durante a cena, verifique que a jogadora não se move.

---

## Desafio — morrer e voltar

Implemente o fluxo de morte do ponto de vista do **jogador**, preparando o Capítulo 22:

1. Crie um comando de cheat `VGKillPlayer` que destrói o pawn da jogadora.
2. O PlayerController percebe que ficou sem pawn (pense em qual evento usar) e empilha um modo `Dead` (novo valor no enum) com um contexto que só aceita "continuar".
3. Ao "continuar", o controller pede ao **GameMode** que reinicie o jogador (`RestartPlayer`) — o controller não decide onde renascer; a regra é do GameMode.
4. Ao possuir o novo corpo, o modo `Dead` é removido e a câmera volta ao corpo.

Pergunta para o `DEVLOG.md`: que estado da jogadora se perdeu na morte e deveria ter sido preservado? Onde ele deveria estar, segundo a árvore de decisão do Capítulo 10?

---

## Uso de IA

1. **Para delimitar responsabilidades:**
   > "Num jogo em primeira pessoa em Unreal Engine 5, classifique cada responsabilidade como pertencente ao PlayerController, ao Pawn, ao GameMode, a um subsistema ou a um componente de equipamento, e justifique pelo ciclo de vida e por multiplayer: modos de input, mira, câmera de cinemática, sons de passos, tela de morte, regra de respawn, munição, documentos coletados, pausa, cheats."

2. **Para revisar a pilha de modos:**
   > "Revise esta implementação de pilha de modos de input num PlayerController da Unreal. Procure: estados impossíveis, operações não simétricas, problemas com pausa (o jogo pode ficar pausado sem UI?), comportamento em PlayerControllers não locais e casos em que dois sistemas disputam o topo. [código]"

3. **Para pensar em transições:**
   > "Descreva cinco usos de SetViewTargetWithBlend em jogos narrativos e de terror (câmeras de segurança, cenas curtas, revelações), e para cada um diga que modo de input deveria estar ativo, se a jogadora deve continuar vulnerável durante a cena e como evitar que ela perca a orientação ao voltar."

---

## Checklist

- [ ] Sei o que pertence ao PlayerController, ao Pawn, ao GameMode e aos subsistemas.
- [ ] Uso `OnPossess` para lógica que depende do pawn.
- [ ] Sei usar `SetViewTarget`/`SetViewTargetWithBlend` e separar ver de possuir.
- [ ] Implementei a pilha de modos de input com configuração por dados.
- [ ] Sei usar modos de input da UI, cursor e pausa a partir do topo da pilha.
- [ ] Migrei comandos de debug para o `UVGCheatManager`.
- [ ] Consigo decompor a troca de personagem de GTA V em view target, possessão e streaming.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre **PlayerController**, **Cameras** (view targets) e **CheatManager**.
- **Código-fonte da engine** — `PlayerController.h` (procure `SetViewTargetWithBlend`, `SetInputMode`, `OnPossess`, `CheatClass`).

---

➡️ **Próximo:** [Capítulo 17 — Character](cap-17-character.md)

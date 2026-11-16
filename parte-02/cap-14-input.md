# Capítulo 14 — Input

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que jogos separam **dispositivo** (tecla, analógico) de **intenção** (mover, pular, interagir), e como o **Enhanced Input** da Unreal implementa essa separação;
- criar e configurar **Input Actions**, **Input Mapping Contexts**, **Triggers** e **Modifiers**;
- ligar ações a código C++ e decidir **onde** cada binding mora: Pawn ou PlayerController;
- organizar o input em **contextos** (exploração, leitura de documento, cinemática, debug) com prioridades;
- tratar corretamente mouse e analógico (zona morta, curva de resposta, Δt — Capítulo 3);
- entender o input em **multiplayer local** — dois controles, dois jogadores, uma tela;
- finalmente **andar, olhar e pular** pelo Pátio da Usina.

---

## Contexto

No fim do Capítulo 10, você nasceu no Pátio dentro de um corpo que não se movia. O pawn existia, estava possuído pelo PlayerController, tinha câmera na altura certa — e nenhum caminho levava o teclado até ele.

Input parece o sistema mais simples de um jogo: "se apertou W, anda para frente". Não é. Pense no que precisa ser verdade para o micro-loop do Capítulo 5 funcionar:

- O mesmo jogo aceita teclado e mouse, controle de Xbox, controle de PlayStation — e o código de gameplay não deveria saber qual.
- "Andar para frente" é **um eixo contínuo** no analógico e **um botão** no teclado.
- "Interagir" precisa ser um toque; "carregar a sobrecarga da lanterna" é segurar; "correr" pode ser segurar ou alternar, conforme a preferência do jogador.
- Ao abrir um documento, as teclas de movimento devem parar de mover a personagem e passar a virar páginas.
- Ao jogar com seu primo, o controle 1 move o jogador 1, e o controle 2, o jogador 2.
- O jogador quer remapear as teclas.

Tudo isso é responsabilidade do sistema de input. Na Unreal 5, ele se chama **Enhanced Input**.

---

## 14.1 Do dispositivo à intenção

O princípio de arquitetura de qualquer sistema de input sério é uma **camada de indireção** entre o hardware e o gameplay:

```text
  DISPOSITIVO            MAPEAMENTO (contexto)           INTENÇÃO              GAMEPLAY
  ───────────            ─────────────────────           ────────              ────────
  W, A, S, D      ─┐
                   ├──►  IMC_Exploracao              ──► IA_Move (Vector2D) ──► AddMovementInput
  Analógico esq.  ─┘     (+ modifiers: swizzle,
                          negate, dead zone)
  Mouse XY        ─┐
                   ├──►  IMC_Exploracao              ──► IA_Look (Vector2D) ──► AddControllerYaw/Pitch
  Analógico dir.  ─┘     (+ modifiers: negate,
                          scalar, curva, Δt)
  Espaço / (A)    ────►  IMC_Exploracao (+ trigger)  ──► IA_Jump (bool)     ──► Jump / StopJumping
```

O código de gameplay conhece **apenas a coluna "Intenção"**: ações com tipos de valor (`bool`, `float`, `Vector2D`). Tudo à esquerda dela — quais teclas, quais eixos, que transformações — é **configuração** (assets editáveis), que designers e o próprio jogador podem mudar sem tocar no código.

> 🌉 **Ponte:** é o padrão **Command** com uma tabela de roteamento: o dispositivo gera um evento cru, um mapeamento traduz para um comando com semântica, e o handler executa o comando. Se você já configurou *keybindings* em camadas (como os modos de um editor modal), os contextos do Enhanced Input são essas camadas.
>
> 🧱 **Onde a ponte cai:** comandos de backend são discretos. Input de jogo é, em boa parte, **contínuo**: o valor de um eixo existe **em todo frame** e muda continuamente. O sistema precisa tratar estados ("está segurando há 0,4 s") e não só eventos.

---

## 14.2 Os blocos do Enhanced Input

### Input Action (`UInputAction`) — a intenção

Um asset (`IA_Move`, `IA_Look`, `IA_Jump`) que representa **uma coisa que o jogador quer fazer**. A propriedade principal é o **tipo de valor**:

| Value Type | Exemplo |
|---|---|
| `Digital (bool)` | Pular, interagir, ligar a lanterna |
| `Axis1D (float)` | Zoom, acelerador de veículo |
| `Axis2D (Vector2)` | Mover, olhar |
| `Axis3D (Vector)` | Raro em gameplay comum |

Uma ação também pode ter **triggers** e **modifiers** próprios, aplicados a todos os seus mapeamentos.

### Input Mapping Context (`UInputMappingContext`) — o mapeamento

Um asset (`IMC_Exploracao`) que lista **mapeamentos**: "a tecla W aciona `IA_Move`, com estes modifiers e triggers". Contextos são **adicionados e removidos em runtime**, com **prioridade**: quando dois contextos ativos mapeiam a mesma tecla, o de maior prioridade vence (e pode, conforme configuração, consumir o input para que os de baixo não o recebam).

### Modifiers — transformar o valor

Modifiers são aplicados **em sequência** ao valor cru do dispositivo, antes que ele chegue à ação. Os mais usados:

| Modifier | Faz | Uso típico |
|---|---|---|
| **Negate** | Inverte o sinal (por eixo) | `S` = frente negativa; inverter eixo Y do mouse |
| **Swizzle Input Axis Values** | Troca a ordem dos eixos (ex.: X→Y) | Fazer `W` (um botão, que gera X=1) virar o eixo Y de `IA_Move` |
| **Dead Zone** | Ignora valores pequenos do analógico | Eliminar *drift* (deriva) de controles gastos |
| **Scalar** | Multiplica por um fator | Sensibilidade |
| **Response Curve** (exponencial ou por curva) | Aplica uma curva ao valor | Precisão em movimentos pequenos do analógico |
| **Scale By Delta Time** | Multiplica pelo Δt do frame | Converter **taxa** (analógico) em **deslocamento** (Capítulo 3, seção 3.2) |
| **Smooth** | Suaviza o valor ao longo de alguns frames | Raramente; adiciona latência |

### Triggers — decidir quando a ação dispara

Um trigger observa o valor ao longo do tempo e decide o **estado** da ação a cada frame. Os mais usados: **Down** (enquanto pressionado — o padrão implícito), **Pressed** (uma vez, ao pressionar), **Released** (uma vez, ao soltar), **Hold** (depois de segurar por X segundos), **Tap** (pressionar e soltar rapidamente), **Pulse** (repetidamente enquanto segura), **Chorded Action** (só se outra ação também estiver ativa — combinações).

O estado da ação gera **eventos** (`ETriggerEvent`) que o código escuta:

```text
            pressiona                          solta
               │                                 │
  Started ─────┘                                 │
  Ongoing      ░░░░░░░░░ (Hold ainda não atingiu o tempo)
  Triggered              ████████████████████████ (a cada frame em que a condição vale)
  Completed                                      └──── (a ação terminou após ter disparado)
  Canceled     (soltou antes de o Hold atingir o tempo)
```

- **`Started`** — o primeiro frame em que o input foi detectado.
- **`Triggered`** — a condição do trigger foi satisfeita; com *Down*, dispara **todo frame** enquanto pressionado.
- **`Ongoing`** — o trigger está avaliando (ex.: segurando, mas o *Hold* ainda não completou).
- **`Completed`** — terminou depois de ter disparado.
- **`Canceled`** — terminou sem nunca ter disparado.

A escolha do evento no binding é uma decisão de gameplay: movimento escuta `Triggered` (todo frame, com o valor contínuo); pulo escuta `Started` (uma vez) para iniciar e `Completed` para encerrar — o que permite **pulos de altura variável** (soltar cedo corta o pulo, um recurso clássico de *game feel* que o `ACharacter` suporta).

---

## 14.3 Onde mora o binding: Pawn ou Controller?

O Capítulo 10 separou **vontade** (Controller) de **corpo** (Pawn). O input atravessa essa fronteira, e a pergunta "onde eu faço o `BindAction`?" tem uma resposta que segue a mesma lógica:

| Responsabilidade | Onde | Por quê |
|---|---|---|
| **Quais contextos estão ativos** (exploração, leitura, cinemática) | **PlayerController** | É o "modo" do jogador; sobrevive à troca de pawn e à morte |
| **Ações que só fazem sentido para um tipo de corpo** (andar, pular, ligar a lanterna) | **Pawn**, em `SetupPlayerInputComponent` | Outro pawn (um veículo, a câmera de segurança) teria outras ações |
| **Ações que independem do corpo** (pausar, abrir o diário, comandos de debug) | **PlayerController** | Funcionam mesmo sem pawn (morto, em cinemática) |

Quando o controller possui um pawn, a engine cria o componente de input do pawn e chama `SetupPlayerInputComponent`; ao trocar de pawn, os bindings do pawn anterior deixam de valer, e os do novo passam a valer. Trocar de corpo troca de ações — automaticamente.

---

## 14.4 Contextos na Vigília

A Vigília terá, ao longo do livro, estes contextos:

| Contexto | Prioridade | Ações | Ativo quando |
|---|:-:|---|---|
| `IMC_Exploracao` | 0 | mover, olhar, pular, agachar, correr, interagir, lanterna | Jogando normalmente |
| `IMC_Leitura` | 10 | fechar, página anterior/seguinte, olhar (opcional) | Lendo um documento (Capítulo 48) |
| `IMC_Cinematica` | 20 | pular cinemática | Durante cinemáticas (Capítulo 49) |
| `IMC_UI` | 30 | navegar, confirmar, voltar | Menus (Capítulo 55) |
| `IMC_Debug` | 100 | atalhos de desenvolvimento | Só em builds de desenvolvimento |

Repare que **"ler um documento" não remove o contexto de exploração**: ele adiciona um de prioridade maior, que **consome** as teclas que mapeia (por exemplo, `A`/`D` passam a virar páginas em vez de mover). Ao fechar o documento, o contexto de leitura é removido, e a exploração volta a receber as teclas. Essa composição por pilha de contextos evita a alternativa frágil — um `if (bIsReading)` em cada handler de input.

> 🌉 **Ponte:** a pilha de contextos é uma **cadeia de responsabilidade** com prioridade: cada camada pode tratar o input e decidir se ele continua descendo.

### Modo de input da UI

Separado dos contextos, o PlayerController tem um **modo de input** que decide se o input vai para o jogo, para a UI ou para os dois: `SetInputMode(FInputModeGameOnly())`, `FInputModeUIOnly`, `FInputModeGameAndUI`, junto com a visibilidade do cursor (`bShowMouseCursor`). Menus e telas de documento combinam as duas coisas: contexto de UI ativo e modo de input adequado. O Capítulo 55 aprofunda.

---

## 14.5 Mouse, analógico e a unidade de tempo

O Capítulo 3 estabeleceu: **mouse produz deslocamento; analógico produz taxa.** O Enhanced Input permite tratar os dois na **configuração**, mantendo um único handler de "olhar" no código:

```text
IA_Look (Axis2D)

  Mouse XY 2D-Axis
    └─ Negate (só Y)                 ← convenção de eixo vertical (ver abaixo)
    └─ Scalar (sensibilidade)        ← SEM Scale By Delta Time: já é deslocamento

  Gamepad Right Thumbstick 2D-Axis
    └─ Dead Zone (radial, ~0,2)      ← ignora deriva
    └─ Response Curve (exponencial)  ← precisão em movimentos pequenos
    └─ Negate (só Y)
    └─ Scalar (~60)                  ← velocidade máxima de giro: ~150 graus/s efetivos (ver abaixo)
    └─ Scale By Delta Time           ← taxa × Δt = graus neste frame
```

E o código simplesmente aplica o valor que chega:

```cpp
void AVGCharacter::HandleLook(const FInputActionValue& Value)
{
    const FVector2D Axis = Value.Get<FVector2D>();
    AddControllerYawInput(Axis.X);
    AddControllerPitchInput(Axis.Y);
}
```

Duas notas práticas:

- **Eixo vertical invertido.** A convenção de sinal do *pitch* e do eixo Y dos dispositivos pode resultar em "olhar invertido". Se isso acontecer, ajuste o **Negate** no mapeamento — **não** o código. Assim, a opção de "inverter eixo Y" do menu de configurações (Capítulo 55) também será só configuração.
- **⚠️ As escalas legadas.** O `Negate (Y)` acima só produz um olhar "normal" porque o PlayerController ainda aplica, por padrão, as **escalas legadas de input** (`bEnableLegacyInputScales` nas configurações de input do projeto): **yaw × 2,5** e **pitch × −2,5**. É esse sinal negativo, somado ao Negate, que faz "mouse para cima" olhar para cima. Se você desligar as escalas legadas, o vertical inverte (remova o Negate) e a sensibilidade cai 2,5 vezes. Pelo mesmo motivo, o Scalar do analógico é ~60, não 150: 60 × 2,5 ≈ 150 graus/s. O padrão e o nome da opção variam entre versões — verifique na sua e calibre com o **Scalar**, observando o comportamento real.

### Zona morta e curva de resposta

Dois conceitos de *game feel* que parecem detalhes e definem a sensação de mira com controle:

- **Zona morta (*dead zone*).** Analógicos físicos não voltam exatamente a zero; sem zona morta, a câmera "anda sozinha". Zonas mortas grandes demais tornam pequenos ajustes impossíveis. A forma **radial** (sobre a magnitude do vetor) costuma ser melhor que a **axial** (sobre cada eixo), que distorce diagonais.
- **Curva de resposta.** Uma resposta linear faz pequenos desvios do analógico gerarem giros relativamente rápidos, dificultando a precisão. Uma curva (por exemplo, exponencial) torna a região central mais suave e preserva a velocidade máxima nas bordas.

---

## 14.6 Multiplayer local

Quando você jogava PES 2011 com seu primo no PlayStation 2, havia dois controles, dois jogadores humanos, uma tela e um jogo. Na Unreal, esse cenário é suportado diretamente:

- Cada jogador local é um **`ULocalPlayer`**, criado em runtime (`UGameplayStatics::CreatePlayer`), com o seu próprio **PlayerController**.
- **Cada `ULocalPlayer` tem o seu próprio `UEnhancedInputLocalPlayerSubsystem`** — portanto os seus próprios contextos ativos. O jogador 1 pode estar num menu enquanto o jogador 2 continua jogando.
- A engine **roteia dispositivos para jogadores** (controle 1 → jogador 1, controle 2 → jogador 2). Há uma configuração de projeto para que o teclado/mouse e o primeiro controle sejam tratados como jogadores diferentes ou como o mesmo jogador (*Project Settings → Maps & Modes → Local Multiplayer*).
- A câmera pode ser **dividida** (*split screen*, suportada pela engine) ou **compartilhada** — num jogo de futebol, os dois jogadores olham para a mesma câmera do estádio, o que significa que o *PlayerCameraManager* de um deles define a vista, ou que uma câmera de jogo comum é usada para ambos.

> 🌉 **Ponte:** multiplayer local é **multi-tenancy no mesmo processo**: o mesmo mundo, as mesmas regras, estado de sessão separado por jogador (contextos, câmera, UI).
>
> 🧱 **Onde a ponte cai:** os "tenants" compartilham **o mesmo frame e o mesmo estado de mundo**, sem latência e sem isolamento. É exatamente a ausência de latência que faz o multiplayer local ser simples — e o Capítulo 63 mostra tudo que muda quando o segundo jogador está em outra cidade.

---

## Estudo de caso: mira com analógico em shooters de console

> **Pergunta:** por que shooters jogados com controle "ajudam" o jogador a mirar, e o que isso revela sobre input como design?

**[FATO PÚBLICO]** Jogos como a série Call of Duty e Apex Legends oferecem **assistência de mira** (*aim assist*) para jogadores que usam controle. Em jogos com *crossplay* entre controle e mouse, a intensidade da assistência é um tema recorrente e público de debate entre jogadores e de ajustes por parte dos desenvolvedores.

**[INFERÊNCIA]** O motivo de design é a diferença física entre os dispositivos, que o Capítulo 3 formalizou: o **mouse produz deslocamento** com resolução muito alta e permite movimentos rápidos e precisos com o braço e o pulso; o **analógico produz taxa** com um curso físico de poucos milímetros, o que torna correções finas — "girar 0,8° para a esquerda e parar" — muito mais difíceis. Sem algum tipo de ajuda, jogadores de controle ficam em desvantagem clara, e o micro-loop "mirar → atirar → acertar" (Capítulo 5) fica frustrante.

Técnicas comumente descritas em discussões de design de shooters incluem:

- **Desaceleração (*slowdown/friction*)** — a sensibilidade diminui quando a mira passa sobre ou perto de um alvo, facilitando parar sobre ele;
- **Rotação assistida (*magnetism/rotation*)** — a mira acompanha levemente um alvo em movimento enquanto o jogador se move;
- **Curvas de resposta e zonas mortas cuidadosamente ajustadas** — a base de tudo, antes de qualquer "assistência".

Não há afirmação aqui sobre como nenhum jogo específico implementa ou calibra essas técnicas.

**[SIMPLIFICAÇÃO DIDÁTICA]** A versão mínima já está neste capítulo: **zona morta radial + curva de resposta + Δt no analógico**. A desaceleração perto de alvos entra no Capítulo 25, quando a mira tiver alvos; ela é, essencialmente, um **modifier contextual**: um fator de escala no valor de `IA_Look` que depende de o centro da tela estar próximo de um inimigo.

**Lição:** **input não é um detalhe técnico; é design.** A mesma intenção ("mirar") com dispositivos diferentes exige tratamentos diferentes para produzir uma experiência equivalente. Por isso a camada de indireção do Enhanced Input é tão valiosa: ela é o lugar onde essas decisões vivem como configuração ajustável, e não como código espalhado.

---

## Comparação com o desenvolvimento tradicional

| Enhanced Input | O que você conhece | Onde a analogia cai |
|---|---|---|
| Input Action | Comando / intenção com tipo | Pode ser um valor contínuo a cada frame |
| Mapping Context com prioridade | Tabela de roteamento em camadas; *keybindings* modais | Contextos se empilham e consomem input |
| Modifiers | Pipeline de transformação (filtros) | Aplicados todo frame sobre sinais físicos ruidosos |
| Triggers | Debounce, reconhecedores de gestos | Estados temporais (Hold, Tap) com eventos de ciclo |
| Binding no Pawn vs. Controller | Handler por tipo de recurso vs. handler global | A troca de pawn troca os bindings automaticamente |
| Multiplayer local | Multi-tenancy em processo | Mesmo frame, sem latência, sem isolamento |

---

## Implementação: andar, olhar e pular

### 1. Dependência do módulo

No `Vigilia.Build.cs`, adicione `EnhancedInput`:

```csharp
PublicDependencyModuleNames.AddRange(new string[]
{
    "Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput"
});
```

Confirme também, em *Project Settings → Input*, que **Default Player Input Class** e **Default Input Component Class** são as do Enhanced Input (`EnhancedPlayerInput` e `EnhancedInputComponent`) — o padrão em projetos UE5 recentes.

### 2. Os assets

Em `/Game/Vigilia/Input/`:

- **`IA_Move`** — Axis2D.
- **`IA_Look`** — Axis2D.
- **`IA_Jump`** — Digital (bool).
- **`IMC_Exploracao`** com os mapeamentos:

| Ação | Tecla/Eixo | Modifiers |
|---|---|---|
| `IA_Move` | `W` | Swizzle Input Axis Values (YXZ) |
| `IA_Move` | `S` | Swizzle (YXZ), Negate |
| `IA_Move` | `D` | — |
| `IA_Move` | `A` | Negate |
| `IA_Move` | Gamepad Left Thumbstick 2D-Axis | Dead Zone (Radial) |
| `IA_Look` | Mouse XY 2D-Axis | Negate (Y)*, Scalar (sensibilidade) |
| `IA_Look` | Gamepad Right Thumbstick 2D-Axis | Dead Zone (Radial), Response Curve, Negate (Y)*, Scalar (~60), Scale By Delta Time |

\* Valores pressupondo as escalas legadas de input ligadas (seção 14.5).
| `IA_Jump` | `Space Bar` | — |
| `IA_Jump` | Gamepad Face Button Bottom | — |

Por que o *Swizzle* em `W`? Uma tecla gera um valor no eixo **X** (1 quando pressionada). `IA_Move` usa **Y** para frente/trás e **X** para os lados. O swizzle troca X e Y, fazendo `W` produzir `(0, 1)`. É o tipo de detalhe que mostra o valor da camada de configuração: o código recebe sempre um vetor 2D com significado fixo, não importa o dispositivo.

### 3. O PlayerController: dono dos contextos

```cpp
// Source/Vigilia/Player/VGPlayerController.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "VGPlayerController.generated.h"

class UInputMappingContext;

/**
 * A vontade da jogadora: dona dos contextos de input ativos (e, no Cap. 55, da UI).
 */
UCLASS()
class VIGILIA_API AVGPlayerController : public APlayerController
{
    GENERATED_BODY()

public:
    UFUNCTION(Exec)
    void VGDumpTimeDilation();

protected:
    virtual void BeginPlay() override;

    /** Contexto base, sempre ativo durante o jogo. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<UInputMappingContext> ExplorationContext;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    int32 ExplorationPriority = 0;
};
```

```cpp
// Source/Vigilia/Player/VGPlayerController.cpp (trecho novo)
#include "EnhancedInputSubsystems.h"
#include "Engine/LocalPlayer.h"
#include "InputMappingContext.h"

void AVGPlayerController::BeginPlay()
{
    Super::BeginPlay();

    // Contextos pertencem ao jogador LOCAL. Em multiplayer, o servidor tem cópias
    // de PlayerControllers remotos, que não têm LocalPlayer (Parte IX).
    if (!IsLocalController())
    {
        return;
    }

    UEnhancedInputLocalPlayerSubsystem* Input =
        ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer());

    if (Input && ensureMsgf(ExplorationContext, TEXT("%s: ExplorationContext não configurado."), *GetName()))
    {
        Input->AddMappingContext(ExplorationContext, ExplorationPriority);
    }
}
```

O `IsLocalController()` é a primeira linha de código do livro escrita **pensando no multiplayer** — o custo é uma linha, e ela evita um bug obscuro na Parte IX.

Para que o `BP_VGPlayerController` (ou o próprio `AVGPlayerController`) receba o contexto, crie um Blueprint filho `BP_VGPlayerController`, defina `ExplorationContext = IMC_Exploracao` e configure-o como `PlayerControllerClass` no `BP_VGGameMode`. Como sempre: **o C++ não conhece o asset; o Blueprint escolhe**.

### 4. O Character: dono das ações do corpo

```cpp
// Source/Vigilia/Player/VGCharacter.h (adições)
class UInputAction;
struct FInputActionValue;

UCLASS()
class VIGILIA_API AVGCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    AVGCharacter();

    UCameraComponent* GetFirstPersonCamera() const { return FirstPersonCamera; }

protected:
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UCameraComponent> FirstPersonCamera;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<UInputAction> MoveAction;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<UInputAction> LookAction;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<UInputAction> JumpAction;

private:
    void HandleMove(const FInputActionValue& Value);
    void HandleLook(const FInputActionValue& Value);
};
```

```cpp
// Source/Vigilia/Player/VGCharacter.cpp (adições)
#include "EnhancedInputComponent.h"
#include "InputActionValue.h"

void AVGCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);

    UEnhancedInputComponent* Input = CastChecked<UEnhancedInputComponent>(PlayerInputComponent);

    if (MoveAction)
    {
        Input->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AVGCharacter::HandleMove);
    }
    if (LookAction)
    {
        Input->BindAction(LookAction, ETriggerEvent::Triggered, this, &AVGCharacter::HandleLook);
    }
    if (JumpAction)
    {
        Input->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
        Input->BindAction(JumpAction, ETriggerEvent::Completed, this, &ACharacter::StopJumping);
    }
}

void AVGCharacter::HandleMove(const FInputActionValue& Value)
{
    const FVector2D Axis = Value.Get<FVector2D>();
    AddMovementInput(GetActorForwardVector(), Axis.Y);
    AddMovementInput(GetActorRightVector(), Axis.X);
}

void AVGCharacter::HandleLook(const FInputActionValue& Value)
{
    const FVector2D Axis = Value.Get<FVector2D>();
    AddControllerYawInput(Axis.X);
    AddControllerPitchInput(Axis.Y);
}
```

### Explicação das decisões

- **`CastChecked`**: se o componente de input não for o do Enhanced Input, é um erro de **configuração do projeto**, não uma situação esperada — falhar alto é correto (Capítulo 11, seção 11.8).
- **`if (MoveAction)`**: uma ação não configurada no Blueprint não deve derrubar o jogo; ela simplesmente não funciona. Uma validação no editor (`IsDataValid`, Capítulo 13) seria o próximo passo; fica como exercício.
- **`AddMovementInput` não move nada sozinho.** Ele **acumula um pedido** de movimento, que o `CharacterMovementComponent` consome no seu tick, aplicando aceleração, velocidade máxima, atrito, colisão e gravidade. O input diz **para onde a jogadora quer ir**; o movimento decide **como o corpo vai**. É mais uma vez a separação vontade/corpo — e é por isso que o Capítulo 17 (Character) e o Capítulo 25 (FPS Controller) mexem no componente de movimento, não no handler de input.
- **`GetActorForwardVector()`** usa a orientação do corpo, que segue o *yaw* do controller (Capítulo 10). Assim, "frente" é para onde a jogadora está olhando no plano horizontal — e olhar para cima não faz a personagem tentar andar para o céu.
- **`AddControllerYawInput`/`AddControllerPitchInput`** alteram a **control rotation**, que pertence ao Controller; a câmera a segue (`bUsePawnControlRotation`). A mira é da vontade.
- **Pulo com `Started`/`Completed`** habilita o pulo de altura variável do `ACharacter` (configurável no componente de movimento e nas propriedades do personagem).

### 5. Teste

No `BP_VGJogadora`, atribua `IA_Move`, `IA_Look` e `IA_Jump`. Dê *Play* no Pátio. Você deve conseguir andar, olhar e pular. Caminhe até a Casa de Força, entre na guarita, suba a escada. **Pela primeira vez, o grey-box do Capítulo 7 está sendo avaliado na escala e na velocidade de uma pessoa**, e você vai perceber coisas que voando não percebia: distâncias longas demais, uma escada desconfortável, a caixa d'água mais (ou menos) útil como marco do que você imaginava. Anote tudo no `DEVLOG.md` — é o primeiro playtest do projeto.

---

## Decisões arquiteturais

1. **Gameplay conhece só Input Actions.** Teclas, eixos e transformações são configuração.
2. **O PlayerController é dono dos contextos ativos**; o Pawn é dono das ações do corpo; ações independentes do corpo ficam no Controller.
3. **Contextos empilhados por prioridade**, em vez de flags de modo nos handlers.
4. **Mouse sem Δt; analógico com zona morta radial, curva de resposta e Δt** — tudo como modifiers.
5. **Inversão de eixo e sensibilidade são configuração**, nunca código.
6. **`IsLocalController()`** antes de mexer em contextos.
7. **Assets de input em `/Game/Vigilia/Input/`**, referenciados pelos Blueprints, nunca pelo C++.

---

## Armadilhas

- **Ler teclas diretamente no gameplay** (`IsInputKeyDown(EKeys::W)`), ignorando a camada de ações.
- **Esquecer a dependência `EnhancedInput`** no `Build.cs` (erro de linker).
- **Binding em `Triggered` para ações de disparo único** (pular uma vez por frame enquanto segura).
- **Flags de modo nos handlers** (`if (bIsReading) return;`) em vez de contextos.
- **Multiplicar mouse por Δt**, ou esquecer Δt no analógico.
- **Zona morta axial** distorcendo diagonais, ou zona morta grande demais.
- **Corrigir eixo invertido no código.**
- **Adicionar contextos em PlayerControllers não locais.**
- **Esperar que `AddMovementInput` mova o ator imediatamente** — ele é consumido pelo componente de movimento.

---

## Exercício

**Parte 1 — andar (1,5 h).** Implemente os assets, o PlayerController e o Character deste capítulo. Faça o primeiro playtest no Pátio e registre pelo menos cinco observações de escala e fluxo. Ajuste o grey-box com base nelas.

**Parte 2 — controle (45 min).** Se tiver um controle, jogue com ele. Ajuste zona morta, curva e velocidade do analógico até a mira ficar confortável. Compare com o mouse: o que você precisou ajustar para que as duas experiências fossem equivalentes? Rode `t.MaxFPS 30` e `t.MaxFPS 120` e verifique que a velocidade de giro do analógico é a mesma nos dois.

**Parte 3 — contexto de leitura (1 h).** Crie `IA_FecharLeitura` e `IMC_Leitura` (prioridade 10), mapeando `A`/`D` para uma ação de virar página e `Esc`/`E` para fechar. Adicione ao `AVGPlayerController` funções `EnterReadingMode()` e `ExitReadingMode()` (`BlueprintCallable`) que adicionam e removem o contexto. Teste: com o contexto de leitura ativo, `A`/`D` não movem mais a personagem. *(No Capítulo 48, isso vira a tela de documentos.)*

**Parte 4 — validação (30 min).** Adicione `IsDataValid` ao `AVGCharacter` e ao `AVGPlayerController` para avisar quando ações ou contextos não estiverem configurados.

---

## Desafio — dois jogadores no Pátio

Implemente um modo de teste com **dois jogadores locais** no Pátio:

1. No `BeginPlay` do GameMode (ou por um comando `Exec`), crie um segundo jogador com `UGameplayStatics::CreatePlayer`.
2. Ative a tela dividida e verifique que cada controle (ou teclado + controle, conforme a configuração de multiplayer local) move a sua própria jogadora.
3. Abra o "modo leitura" da Parte 3 em **um** dos jogadores e verifique que o outro continua jogando normalmente.

Responda no `DEVLOG.md`: o que, no código que você escreveu até aqui, **já** estava preparado para dois jogadores sem você ter pensado nisso? E o que quebraria? (Pense no subsistema de dilatação do tempo: o bullet time de um jogador deveria desacelerar o mundo do outro? Num jogo de futebol, faz sentido; num cooperativo, talvez não. É uma decisão de design, e o Capítulo 63 volta a ela.)

---

## Uso de IA

1. **Para configurar mapeamentos:**
   > "Na Unreal Engine 5 com Enhanced Input, quero configurar [ação: ex. correr] para funcionar como 'segurar para correr' no teclado e 'clicar o analógico para alternar' no controle, com uma opção nas configurações para o jogador escolher. Proponha os Input Actions, Mapping Contexts, triggers e modifiers, e o código mínimo no Character. Indique o que depende da versão da engine."

2. **Para afinar o game feel:**
   > "Explique zona morta radial vs. axial, curvas de resposta exponenciais e a diferença entre input de mouse (deslocamento) e de analógico (taxa) para a mira em primeira pessoa. Sugira valores iniciais razoáveis para um jogo de terror em primeira pessoa (movimentos lentos e precisos) e para um shooter rápido, e como testar se estão bons."

3. **Para revisar a arquitetura de input:**
   > "Revise a organização de input deste projeto: quais bindings estão no Pawn, quais no PlayerController, quais contextos existem e quando são ativados. Aponte ações que estão no lugar errado considerando troca de pawn, morte, cinemáticas, UI e multiplayer local. [descrição]"

**Cuidado específico:** o Enhanced Input substituiu o sistema de input legado (Action/Axis Mappings) no UE5, e muito material online — e muitas respostas de IA — ainda usa o sistema antigo (`BindAxis`, `BindAction` com nomes em texto). Se o código sugerido usar nomes de ações como strings, ele é do sistema legado.

---

## Checklist

- [ ] Sei explicar a camada de indireção dispositivo → mapeamento → intenção.
- [ ] Sei criar Input Actions com o tipo de valor correto.
- [ ] Sei configurar Mapping Contexts com modifiers (Negate, Swizzle, Dead Zone, Scalar, Response Curve, Scale By Delta Time).
- [ ] Sei usar triggers e escolher o `ETriggerEvent` certo para cada ação.
- [ ] Sei decidir entre binding no Pawn e no PlayerController.
- [ ] Sei empilhar contextos com prioridade em vez de usar flags de modo.
- [ ] Sei tratar mouse e analógico corretamente.
- [ ] Entendo multiplayer local: LocalPlayers, subsistemas por jogador, roteamento de dispositivos.
- [ ] Ando, olho e pulo pelo Pátio, e fiz o primeiro playtest do grey-box.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Enhanced Input**, incluindo as páginas sobre Input Actions, Mapping Contexts, Triggers e Modifiers, e sobre configurações de input mapeáveis pelo jogador (*Player Mappable Input / Enhanced Input User Settings*, conforme a versão).
- **Projeto `RefFirstPerson`** (Capítulo 7) — compare a configuração de input do template com a da Vigília.
- **Steve Swink, *Game Feel*** — os capítulos sobre input e resposta.

---

➡️ **Próximo:** [Capítulo 15 — Collision e Physics](cap-15-collision-e-physics.md)

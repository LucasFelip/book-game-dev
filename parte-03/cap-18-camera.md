# Capítulo 18 — Camera

## Objetivo

Ao final deste capítulo você deve conseguir:

- entender a **arquitetura de câmera** da Unreal: componente de câmera, view target, `PlayerCameraManager`, **modificadores** e **camera shakes**;
- trabalhar com **rotações** sabendo quando usar `FRotator` e quando usar `FQuat`, e por que *gimbal lock* existe;
- escolher e ajustar **campo de visão (FOV)**, limites de *pitch* e efeitos de câmera com consciência de conforto e acessibilidade;
- implementar **balanço de cabeça** (*head bob*), **variação de FOV ao correr** e **tremor de aterrissagem** como camadas independentes;
- tratar a câmera como **ferramenta emocional**, usando Outlast como referência.

---

## Contexto

Em primeira pessoa, a câmera **é** o corpo do jogador. Não há um personagem na tela para comunicar cansaço, peso, medo ou impacto: tudo o que o jogador sabe sobre o próprio corpo chega por **como a imagem se move**. Uma câmera perfeitamente estável, que desliza pelo mundo como um *drone*, comunica "não há ninguém aqui". Uma câmera que oscila levemente a cada passo, que afunda ao pousar, que se abre um pouco ao correr, comunica "há um corpo, e ele está sob esforço".

Ao mesmo tempo, a câmera é a principal causa de **desconforto físico** em jogos em primeira pessoa: balanço exagerado, FOV estreito e tremores frequentes causam náusea em parte dos jogadores. Projetar câmera é, portanto, equilibrar **expressividade** e **conforto** — e oferecer controles para que cada jogador ajuste esse equilíbrio.

---

## 18.1 A arquitetura de câmera da Unreal

A imagem que o jogador vê a cada frame é o resultado de uma cadeia:

```text
  UCameraComponent (no pawn)          posição/rotação/FOV "brutos" da câmera do corpo
          │
          ▼
  View target do PlayerController     de QUAL ator a câmera está tirando a vista (Cap. 16)
          │
          ▼
  APlayerCameraManager::UpdateCamera  calcula o ponto de vista final (FMinimalViewInfo)
          │
          ├──► Camera Modifiers  (pilha ordenada por prioridade: balanço, FOV, inclinação...)
          ├──► Camera Shakes     (tremores temporários: impacto, explosão, aterrissagem)
          ├──► Limites           (pitch mínimo/máximo, etc.)
          ▼
  FMinimalViewInfo final  ──►  renderização (com pós-processamento)
```

Os papéis:

- **`UCameraComponent`** — define a câmera "base" de um ator: onde ela está no corpo, o FOV padrão, configurações de pós-processamento. A câmera em primeira pessoa da `AVGCharacter` (Capítulo 10) é um deles.
- **`APlayerCameraManager`** — um ator criado pelo PlayerController que, a cada frame, decide o **ponto de vista final** daquele jogador. É o lugar certo para efeitos que se aplicam à câmera **do jogador**, independentemente do corpo.
- **`UCameraModifier`** — objetos registrados no camera manager que alteram o ponto de vista a cada frame, em ordem de prioridade. Cada efeito contínuo (balanço, inclinação, FOV dinâmico) pode ser um modificador independente.
- **Camera shakes** (`UCameraShakeBase`) — efeitos temporários, normalmente definidos como **assets** com um padrão de movimento (ruído de Perlin, oscilação senoidal, sequência), iniciados por eventos (`ClientStartCameraShake` no PlayerController, ou um `UCameraShakeSourceComponent` posicionado no mundo, com atenuação por distância).

A razão para essa arquitetura em camadas é a mesma do Capítulo 6: **cada efeito tem um dono e se compõe com os outros sem conhecê-los.** O balanço de cabeça não sabe do tremor da explosão; ambos alteram o ponto de vista em sequência, e o resultado é a soma.

> 🌉 **Ponte:** a pilha de modificadores é um **pipeline de *middlewares*** aplicado ao ponto de vista a cada frame — cada um recebe o resultado do anterior, transforma e passa adiante, em ordem de prioridade.

### Onde colocar um efeito de câmera

| Efeito | Onde | Por quê |
|---|---|---|
| Altura dos olhos, FOV base | `UCameraComponent` no pawn | É do corpo |
| Suavização ao agachar | No pawn (Capítulo 17) | Compensa uma mudança **do corpo** |
| Balanço de cabeça, FOV ao correr, inclinar (*lean*) | **Modificador** no camera manager | Efeitos contínuos do ponto de vista; desligáveis por acessibilidade |
| Tremor de aterrissagem, de dano, de explosão | **Camera shake** (asset) | Temporário, disparado por evento, parametrizado por dados |
| Câmera de cinemática, câmera de segurança | **View target** diferente (Capítulo 16) | É outro ponto de vista |
| Vinheta, granulação, distorção ao ser atingido | Pós-processamento | Efeito de imagem, não de posição |

---

## 18.2 Rotações: rotators, quaternions e gimbal lock

### `FRotator`

Um `FRotator` guarda três ângulos em graus — **Pitch** (inclinar para cima/baixo), **Yaw** (girar para os lados), **Roll** (rolar). É intuitivo, fácil de editar no Details e perfeito para expressar "olhar 30° para cima e 90° para a direita".

### O problema: ângulos de Euler compostos

Ângulos de Euler descrevem uma orientação como **três rotações aplicadas em sequência**. Isso causa dois problemas:

1. **Gimbal lock.** Quando uma das rotações chega a ±90° (por exemplo, pitch apontando direto para cima), dois dos três eixos se alinham, e um grau de liberdade é perdido: girar "yaw" e girar "roll" passam a fazer a mesma coisa. Uma câmera que olha direto para cima e tenta girar se comporta de forma estranha.
2. **Interpolação ruim.** Interpolar cada ângulo separadamente (`Lerp` em pitch, yaw e roll) produz trajetórias tortas e, com ângulos que "dão a volta" (de 350° para 10°), pode girar pelo caminho longo.

### `FQuat`

Um **quaternion** representa uma orientação como uma rotação de um certo ângulo em torno de um eixo, codificada em quatro números. Ele não sofre gimbal lock, compõe rotações de forma estável (multiplicação) e interpola suavemente pelo menor caminho (**slerp**, *spherical linear interpolation*).

A regra prática:

```text
  Editar, expor, pensar         →  FRotator
  Compor, interpolar, acumular  →  FQuat
```

```cpp
// Interpolar suavemente entre duas orientações:
const FQuat From = CurrentRotation.Quaternion();
const FQuat To = TargetRotation.Quaternion();
const FQuat Blended = FQuat::Slerp(From, To, VGMath::ExpDecayAlpha(Rate, DeltaSeconds));
SetActorRotation(Blended);
```

Para a câmera em primeira pessoa, a Unreal já evita a maior parte dos problemas: o *pitch* é **limitado** (por padrão, logo antes de ±90°) pelo camera manager, e a *control rotation* é tratada de forma a evitar o gimbal lock. Você vai sentir a diferença entre rotators e quaternions principalmente ao **interpolar orientações** — numa câmera de cinemática, numa arma que se alinha à mira, num inimigo que gira para encarar a jogadora.

### Limites de pitch

O camera manager tem `ViewPitchMin` e `ViewPitchMax`. Limitar o olhar a, digamos, −80°/+80° tem efeito de design além de técnico: impede que a jogadora olhe para os próprios pés de um jeito que revele que "não há pés" (enquanto não houver um corpo visível) e evita orientações desconfortáveis.

---

## 18.3 Campo de visão

O **FOV** (*field of view*) é o ângulo de visão da câmera. Na Unreal, o valor do `UCameraComponent` é o **FOV horizontal**, em graus; o vertical decorre da proporção da tela. O padrão é 90°.

O FOV muda profundamente a percepção:

| FOV horizontal | Sensação | Uso típico |
|---|---|---|
| ~70–80° | Estreito, claustrofóbico, "zoom"; mais desconforto em movimento | Terror (sensação de túnel), consoles a distância da TV |
| ~90° | Neutro | Padrão |
| ~100–110° | Amplo, rápido, mais consciência periférica | Shooters competitivos em PC |

Três observações:

- **FOV é preferência de conforto.** Jogadores mais sensíveis a enjoo de movimento geralmente precisam de FOV maior. Um **controle deslizante de FOV** é uma opção de acessibilidade básica em jogos em primeira pessoa (Capítulo 55).
- **Variações de FOV comunicam velocidade e foco.** Um leve aumento ao correr transmite velocidade; uma redução ao mirar (*aim down sights*, Capítulo 26) transmite foco. Variações devem ser **suaves** (decaimento exponencial) e **pequenas**.
- **FOV e a arma em primeira pessoa.** Com FOVs amplos, os braços e a arma em primeira pessoa ficam distorcidos e "afastados". Jogos costumam renderizar o modelo de primeira pessoa com um FOV próprio, separado do mundo, e tratar o problema de a arma atravessar paredes. Versões recentes da Unreal incluíram recursos voltados especificamente a renderização em primeira pessoa (FOV e escala próprios para elementos de primeira pessoa); verifique o que a sua versão oferece antes de recorrer a técnicas manuais. O Capítulo 26 retoma o assunto quando a arma tiver malha.

---

## 18.4 Movimento de câmera como linguagem do corpo

### Balanço de cabeça (head bob)

O balanço de cabeça imita o movimento vertical e lateral da cabeça ao andar. Ele precisa de três propriedades:

1. **Sincronia com os passos.** A câmera deve "descer" no momento em que o pé toca o chão. Balanço por **tempo** (um seno a frequência fixa) dessincroniza do som dos passos quando a velocidade muda. Balanço por **distância percorrida** — a mesma ideia dos passos do Capítulo 17 — acompanha a velocidade. E, para manter também a **fase**, a forma mais simples é não ter um segundo relógio: a câmera lê o progresso da passada do próprio componente de passos.
2. **Proporcionalidade.** Parada, sem balanço; andando, pouco; correndo, mais. A intensidade deve **acompanhar suavemente** a velocidade (decaimento exponencial), para não "ligar e desligar".
3. **Moderação e controle.** Amplitudes de poucos centímetros. Exagero causa enjoo. E deve haver uma opção para reduzir ou desligar.

A forma usual combina uma oscilação **vertical** com um ciclo por passo e uma **lateral** com um ciclo a cada dois passos (a cabeça vai para o lado do pé de apoio):

```text
 fase φ avança 2π a cada passada (por DISTÂNCIA); φ = 0 no instante em que o passo soa
 vertical  = −A_v × (cos φ + 1) / 2      → ponto mais baixo quando o pé toca o chão
 lateral   = A_l × sin(φ / 2)            → vai e volta a cada dois passos
 intensidade = velocidade / velocidade_de_referência, suavizada
```

### FOV ao correr

Ao correr, o FOV aumenta alguns graus, suavemente; ao parar, volta. É um dos efeitos mais baratos e eficazes de "sensação de velocidade".

### Tremores

Camera shakes devem ser **eventos** — aterrissar de uma altura, levar dano, uma explosão, a porta de aço da Casa de Força batendo — e devem ser **proporcionais** (Capítulo 5, feedback). Um tremor de aterrissagem que escala com a velocidade de queda comunica a altura da queda sem nenhuma UI.

### Inclinar (lean)

Em jogos furtivos e de terror, é comum permitir **inclinar** a cabeça para os lados (espiar um corredor sem expor o corpo). É uma combinação de deslocamento lateral e *roll* da câmera, com uma verificação de colisão para que a câmera não atravesse a parede. É o desafio deste capítulo.

---

## Estudo de caso: Outlast — a câmera como emoção

> **Pergunta:** como a câmera pode construir tensão num jogo em que o jogador não luta?

### O que é publicamente conhecido

**[FATO PÚBLICO]** Em *Outlast* (Red Barrels, 2013), o jogador controla um jornalista investigando um hospital psiquiátrico, **sem nenhuma forma de combate**: diante das ameaças, as opções são fugir e se esconder (por exemplo, em armários e debaixo de camas). O personagem carrega uma **câmera de vídeo** com **visão noturna**, que consome baterias encontradas pelo cenário; muitos ambientes são escuros a ponto de exigir a visão noturna para enxergar. A imagem vista através da câmera de vídeo aparece com a interface e a textura visual de uma filmadora.

### 1. Experiência

Vulnerabilidade total e presença física. O jogador deve sentir que **é** um corpo frágil num lugar hostil, e que só consegue ver o perigo através de um aparelho que pode falhar.

### 2. Sistema

```text
   CÂMERA DO JOGO (ponto de vista)              CÂMERA NA FICÇÃO (a filmadora)
   ───────────────────────────────              ──────────────────────────────
   corpo presente: movimento, respiração        visão noturna: única forma de ver no escuro
   reação física ao susto e à fuga              bateria limitada: recurso escasso
   esconder-se: câmera em espaço apertado       interface de filmadora: "estou gravando"
        └──────────────────────┬────────────────────────────┘
                               ▼
         ver é perigoso, não ver é pior → tensão sem combate
```

### 3. Design

Duas decisões se combinam:

- **A câmera do jogo é encarnada.** O ponto de vista se comporta como uma cabeça num corpo — com peso e reação. Isso torna cada perseguição uma experiência física.
- **Uma câmera dentro da ficção controla a visão.** Ao amarrar a capacidade de ver no escuro a um objeto com recurso limitado, o jogo transforma a percepção do jogador num **sistema de gerenciamento de risco** — exatamente a mecânica de bateria do Capítulo 5, aplicada à visão em vez da luz.

### 4. Tecnologia

**[INFERÊNCIA]** Na arquitetura deste capítulo, um efeito como esse se decompõe em: modificadores de câmera para o movimento do corpo (balanço, inclinação, reações), camera shakes para sustos e impactos, um modo de **pós-processamento** para a visão noturna (amplificação de luminância, granulação, tonalidade), uma **UI diegética** sobre a imagem (Capítulo 55), e um componente de bateria com estado (Capítulo 4) que, ao esgotar, desliga o pós-processamento e devolve a escuridão.

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]** Na Vigília, a câmera encarnada é este capítulo: balanço sincronizado com os passos (que, lembre-se, também são o ruído que a Presença ouve — o jogador **sente** na câmera o mesmo ritmo que o inimigo **ouve**), FOV que se abre na fuga e tremor ao pousar. A "câmera na ficção" da Vigília não é uma filmadora: é a **lanterna** (Capítulo 51) — mesma estrutura, outro objeto.

### 6. Lição

**Em primeira pessoa, a câmera é o personagem.** Os movimentos de câmera são a única linguagem corporal disponível, e eles devem ser projetados como **feedback do estado do corpo** (andando, correndo, caindo, assustado), com a mesma disciplina de qualquer outro feedback (Capítulo 5): sincronizado, proporcional, multicanal — e ajustável por quem sente desconforto.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Pilha de modificadores | Pipeline de middlewares | Executa todo frame, sobre um valor contínuo |
| Camera shake como asset | Efeito parametrizado por configuração | A "configuração" é uma curva de movimento sentida fisicamente |
| `FRotator` vs. `FQuat` | Representações diferentes do mesmo valor (ex.: datas locais vs. UTC) | A escolha errada produz bugs de comportamento, não de formatação |
| Opções de câmera para conforto | Acessibilidade de UI | Aqui, o desconforto é **físico** (náusea) |

---

## Implementação

### 1. O camera manager do projeto

```cpp
// Source/Vigilia/Player/VGPlayerCameraManager.h
#pragma once

#include "CoreMinimal.h"
#include "Camera/PlayerCameraManager.h"
#include "VGPlayerCameraManager.generated.h"

/** Camera manager da jogadora: limites de pitch e modificadores padrão (configurados no Blueprint). */
UCLASS()
class VIGILIA_API AVGPlayerCameraManager : public APlayerCameraManager
{
    GENERATED_BODY()

public:
    AVGPlayerCameraManager();
};
```

```cpp
// Source/Vigilia/Player/VGPlayerCameraManager.cpp
#include "Player/VGPlayerCameraManager.h"

#include "Player/VGFirstPersonCameraModifier.h"

AVGPlayerCameraManager::AVGPlayerCameraManager()
{
    ViewPitchMin = -80.0f;
    ViewPitchMax = 80.0f;
    DefaultModifiers.Add(UVGFirstPersonCameraModifier::StaticClass());
}
```

E, no construtor do `AVGPlayerController`: `PlayerCameraManagerClass = AVGPlayerCameraManager::StaticClass();`.

`DefaultModifiers` é uma lista da própria `APlayerCameraManager`: modificadores nela são criados e registrados automaticamente quando o camera manager é inicializado.

### 2. O modificador de primeira pessoa

🔁 **Refatoração do Capítulo 17.** Para que a câmera e o som não tenham dois relógios, o `UVGFootstepComponent` passa a expor a fase da passada:

```cpp
// VGFootstepComponent.h (adições)
public:
    /** Progresso da passada atual: 0 = um passo acabou de soar; 1 = o próximo vai soar. */
    float GetStrideProgress() const
    {
        return CurrentStride > 0.0f ? FMath::Min(DistanceSinceStep / CurrentStride, 1.0f) : 0.0f;
    }

    /** Passos emitidos até agora; a paridade indica o pé de apoio (balanço lateral). */
    int32 GetStepCount() const { return StepCount; }

private:
    float CurrentStride = 75.0f; // passada em uso (muda ao agachar e correr)
    int32 StepCount = 0;

// VGFootstepComponent.cpp (alterações)
//   TickComponent: depois de calcular Stride  →  CurrentStride = Stride;
//   EmitStep: antes do Broadcast              →  ++StepCount;
```

```cpp
// Source/Vigilia/Player/VGFirstPersonCameraModifier.h
#pragma once

#include "CoreMinimal.h"
#include "Camera/CameraModifier.h"
#include "VGFirstPersonCameraModifier.generated.h"

/**
 * Movimento de câmera do corpo em primeira pessoa: balanço de cabeça com a fase lida do
 * UVGFootstepComponent (Cap. 17) e aumento de FOV ao correr. Escalável pela CVar vg.Camera.Motion.
 */
UCLASS()
class VIGILIA_API UVGFirstPersonCameraModifier : public UCameraModifier
{
    GENERATED_BODY()

public:
    virtual bool ModifyCamera(float DeltaTime, FMinimalViewInfo& InOutPOV) override;

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|HeadBob", meta = (ClampMin = "0.0"))
    float VerticalAmplitude = 2.0f;   // cm

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|HeadBob", meta = (ClampMin = "0.0"))
    float LateralAmplitude = 1.2f;    // cm

    /** Velocidade (cm/s) em que o balanço atinge intensidade 1. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|HeadBob", meta = (ClampMin = "1.0"))
    float ReferenceSpeed = 480.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|HeadBob", meta = (ClampMin = "0.0"))
    float IntensityRate = 8.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|FOV", meta = (ClampMin = "0.0"))
    float SprintFOVBonus = 6.0f;      // graus

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|FOV", meta = (ClampMin = "0.0"))
    float FOVRate = 6.0f;

private:
    float BobIntensity = 0.0f;
    float CurrentFOVBonus = 0.0f;
};
```

```cpp
// Source/Vigilia/Player/VGFirstPersonCameraModifier.cpp
#include "Player/VGFirstPersonCameraModifier.h"

#include "Camera/PlayerCameraManager.h"
#include "Core/VGMathUtils.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "HAL/IConsoleManager.h"
#include "Player/VGCharacter.h"
#include "Player/VGFootstepComponent.h"

static TAutoConsoleVariable<float> CVarVGCameraMotion(
    TEXT("vg.Camera.Motion"),
    1.0f,
    TEXT("Escala do movimento de câmera (balanço e FOV dinâmico). 0 = desligado (acessibilidade)."),
    ECVF_Default);

bool UVGFirstPersonCameraModifier::ModifyCamera(float DeltaTime, FMinimalViewInfo& InOutPOV)
{
    Super::ModifyCamera(DeltaTime, InOutPOV);

    const AVGCharacter* Character = Cast<AVGCharacter>(CameraOwner ? CameraOwner->GetViewTarget() : nullptr);
    const float MotionScale = FMath::Max(CVarVGCameraMotion.GetValueOnGameThread(), 0.0f) * Alpha;
    if (!Character || MotionScale <= 0.0f)
    {
        return false; // outra câmera (cinemática), ou movimento desligado
    }

    const UCharacterMovementComponent* Move = Character->GetCharacterMovement();
    const bool bGrounded = Move->IsMovingOnGround();
    const float Speed = bGrounded ? Move->Velocity.Size2D() : 0.0f;

    // Fase LIDA dos passos (Cap. 17): φ = 0 quando um passo soa; dois passos = 4π (ciclo lateral).
    const UVGFootstepComponent* Steps = Character->FindComponentByClass<UVGFootstepComponent>();
    const float StepPhase = Steps
        ? 2.0f * PI * (Steps->GetStepCount() % 2 + Steps->GetStrideProgress())
        : 0.0f;

    const float TargetIntensity = FMath::Clamp(Speed / ReferenceSpeed, 0.0f, 1.0f);
    BobIntensity = VGMath::ExpDecayTo(BobIntensity, TargetIntensity, IntensityRate, DeltaTime);

    const float Vertical = -VerticalAmplitude * (FMath::Cos(StepPhase) + 1.0f) * 0.5f; // mais baixo no passo
    const float Lateral = LateralAmplitude * FMath::Sin(StepPhase * 0.5f);
    const FVector Right = FRotationMatrix(InOutPOV.Rotation).GetUnitAxis(EAxis::Y);

    InOutPOV.Location += (FVector::UpVector * Vertical + Right * Lateral) * BobIntensity * MotionScale;

    // FOV dinâmico ao correr.
    const float TargetFOVBonus = Character->IsSprinting() ? SprintFOVBonus : 0.0f;
    CurrentFOVBonus = VGMath::ExpDecayTo(CurrentFOVBonus, TargetFOVBonus, FOVRate, DeltaTime);
    InOutPOV.FOV += CurrentFOVBonus * MotionScale;

    return false; // false: os modificadores seguintes também são aplicados
}
```

### Explicação das decisões

- **Um modificador, não código no personagem.** O balanço é um efeito do **ponto de vista da jogadora**, não do corpo: ele não deve existir durante uma cinemática (o `Cast` para `AVGCharacter` sobre o view target falha e o modificador não faz nada) e deve ser desligável sem tocar no personagem.
- **`IsSprinting()` lido direto do personagem** é uma dívida consciente: o modificador passa a conhecer a classe da jogadora. Por ora é o único jeito de saber. 🔁 No Capítulo 23, essa pergunta vira a tag `Status.Movement.Sprinting`.
- **`Alpha`** é o fator de ativação do próprio modificador (a classe base o mantém, permitindo ligar e desligar com transição suave). Multiplicar por ele respeita esse mecanismo.
- **Fase lida do componente de passos, não calculada de novo.** ⚠️ Dois acumuladores de distância "iguais" não ficam em fase: a passada muda com o estado (agachada, correndo), um acumulador zera ao pousar e o outro não, e o ponto de partida do cosseno decide se o som cai no topo ou no fundo do balanço. Com uma única fonte da verdade, a câmera está no ponto mais baixo exatamente quando o passo soa — e o `StrideLength` deixa de estar duplicado.
- **Fase limitada** ao intervalo de dois passos (`GetStepCount() % 2` + progresso): não cresce sem limite nem perde precisão de `float` depois de horas de jogo.
- **Decaimento exponencial** para a intensidade e o FOV: nada "liga e desliga" bruscamente (Capítulo 3).
- **`vg.Camera.Motion`** é uma opção de acessibilidade desde o primeiro dia, como `vg.Flicker.Enabled` (Capítulo 11). No Capítulo 55, as duas viram opções no menu.
- **Assinatura de `ModifyCamera`:** a versão que recebe `FMinimalViewInfo&` é o ponto de extensão usado aqui; a classe base tem também uma versão com parâmetros separados. Confira as declarações de `UCameraModifier` na sua versão da engine antes de sobrescrever.

### 3. Tremor de aterrissagem

Crie um asset de camera shake (Blueprint filho de `UCameraShakeBase`, com padrão de ruído de Perlin ou de oscilação) chamado `CS_Aterrissagem`: curto (~0,3 s), com movimento principalmente vertical e um pouco de *pitch*.

No `AVGCharacter`:

```cpp
// VGCharacter.h (adições)
protected:
    virtual void Landed(const FHitResult& Hit) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Camera")
    TSubclassOf<UCameraShakeBase> LandingShake;

    /** Velocidade de queda (cm/s) que corresponde a um tremor de escala 1. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Camera", meta = (ClampMin = "1.0"))
    float LandingShakeReferenceSpeed = 1000.0f;
```

```cpp
// VGCharacter.cpp
#include "Camera/CameraShakeBase.h"

void AVGCharacter::Landed(const FHitResult& Hit)
{
    Super::Landed(Hit);

    APlayerController* PC = Cast<APlayerController>(GetController());
    if (!PC || !LandingShake)
    {
        return;
    }

    const float FallSpeed = FMath::Abs(GetCharacterMovement()->Velocity.Z);
    const float Scale = FMath::Clamp(FallSpeed / LandingShakeReferenceSpeed, 0.0f, 1.5f);
    if (Scale > 0.15f) // quedas mínimas não tremem
    {
        PC->ClientStartCameraShake(LandingShake, Scale);
    }
}
```

O tremor é **dado** (o asset define a forma), **disparado por evento** (pousar), **proporcional** (escala pela velocidade de queda) e tem um **limiar** (Capítulo 4: não reagir a ruído). Note o nome `ClientStartCameraShake`: em multiplayer, é uma chamada que o servidor envia ao cliente dono (um RPC — Capítulo 66). Em single-player, funciona localmente. É mais um sinal de como o framework da Unreal foi desenhado com a rede em mente.

> **Acessibilidade:** camera shakes também devem respeitar a escala de movimento. A forma mais simples é multiplicar `Scale` por `vg.Camera.Motion` — faça isso no exercício.

---

## Decisões arquiteturais

1. **Câmera do corpo no pawn; efeitos do ponto de vista em modificadores; efeitos temporários em camera shakes; outros pontos de vista em view targets.**
2. **`AVGPlayerCameraManager`** com limites de pitch e modificadores padrão.
3. **Rotators para editar e expor; quaternions para compor e interpolar.**
4. **Balanço por distância**, sincronizado com os passos; **FOV dinâmico** suave e pequeno.
5. **Toda movimentação de câmera é escalável por `vg.Camera.Motion`** (acessibilidade).
6. **Tremores proporcionais e com limiar**, definidos como assets.

---

## Armadilhas

- **Balanço por tempo** — dessincroniza do som dos passos.
- **Amplitudes exageradas** e tremores frequentes — enjoo.
- **Interpolar rotações por componente** (`Lerp` em pitch/yaw/roll) em vez de `Slerp`.
- **Efeitos de câmera no Tick do personagem**, que continuam ativos durante cinemáticas.
- **FOV fixo e estreito sem opção de ajuste.**
- **Dados duplicados** (passada da câmera vs. passada dos passos) sem um dono.
- **Camera shakes para tudo**, inclusive eventos irrelevantes — o feedback perde valor.

---

## Exercício

**Parte 1 — câmera (1,5 h).** Implemente `AVGPlayerCameraManager`, `UVGFirstPersonCameraModifier` e o tremor de aterrissagem. Ajuste amplitudes e taxas até o balanço ser **perceptível mas discreto**. Peça para outra pessoa jogar dois minutos e pergunte se sentiu algum desconforto.

**Parte 2 — sincronia (30 min).** Ligue os passos (Capítulo 17) a um som curto qualquer. Ande, corra e agache: a câmera desce no momento do som? Como experimento, troque temporariamente a fase lida do componente por um acumulador próprio no modificador (passada fixa de 75 cm) e corra por dez segundos: em quantos passos o som e a câmera saem de fase? Volte à versão com fonte única.

**Parte 3 — acessibilidade (30 min).** Faça o tremor de aterrissagem respeitar `vg.Camera.Motion`. Teste `vg.Camera.Motion 0`, `0.5` e `1`.

**Parte 4 — rotações (45 min).** Crie um ator de teste que, ao apertar uma tecla, gira suavemente até encarar a jogadora. Implemente com `FMath::RInterpTo` sobre `FRotator` e com `FQuat::Slerp`. Teste com a jogadora no alto da caixa d'água (pitch grande) e em volta do ator (yaw dando a volta de 350° para 10°). Alguma das versões se comportou mal?

---

## Desafio — inclinar para espiar

Implemente o **lean** (inclinar a cabeça para os lados com `Q`/`E`), comum em jogos furtivos:

1. Crie `IA_Lean` (Axis1D: −1 esquerda, +1 direita) e um segundo modificador, `UVGLeanCameraModifier`, com prioridade diferente do de primeira pessoa.
2. O modificador desloca a câmera lateralmente (~30 cm) e aplica um *roll* pequeno (~10°), com suavização.
3. **Colisão:** antes de aplicar o deslocamento, faça um **sweep de esfera** da posição base da câmera até a posição inclinada; se bater, limite o deslocamento ao ponto de contato. A câmera nunca deve atravessar a parede.
4. Enquanto inclinada, a jogadora não pode correr.

Pergunta para o `DEVLOG.md`: o lean é apenas câmera, ou ele também deveria mudar **o que a Presença vê** da jogadora (a cabeça sai do canto, o corpo não)? Se a percepção da IA usar a posição da câmera, o lean vira uma mecânica de furtividade real. Anote para o Capítulo 36.

---

## Uso de IA

1. **Para entender rotações:**
   > "Explique gimbal lock com um exemplo de câmera em primeira pessoa olhando para cima, e mostre em C++ da Unreal Engine 5 a diferença entre interpolar FRotator componente a componente e usar FQuat::Slerp, incluindo o caso de yaw indo de 350° para 10°."

2. **Para design de câmera e conforto:**
   > "Quais práticas reduzem enjoo de movimento em jogos em primeira pessoa (FOV, balanço de cabeça, tremores, aceleração da câmera, desfoque de movimento)? Para cada uma, indique valores iniciais razoáveis e que opção de acessibilidade o jogo deveria oferecer."

3. **Para revisar a arquitetura:**
   > "Na Unreal Engine 5, tenho estes efeitos de câmera: balanço ao andar, FOV ao correr, inclinação lateral, tremor ao pousar, tremor ao levar dano, câmera de segurança e visão noturna. Para cada um, diga se deveria ser componente de câmera, modificador, camera shake, view target ou pós-processamento, e por quê."

**Cuidado específico:** a API de camera shakes mudou entre o UE4 e o UE5. A partir da 4.26, classes de padrão como ruído de Perlin e oscilação substituíram as configurações da antiga `UCameraShake`, que virou `UMatineeCameraShake` e, na 5.1, `ULegacyCameraShake`. Código de exemplo com essas classes antigas não serve para o UE5 sem adaptação.

---

## Checklist

- [ ] Entendo a cadeia componente de câmera → view target → camera manager → modificadores → shakes.
- [ ] Sei onde colocar cada tipo de efeito de câmera.
- [ ] Sei quando usar `FRotator` e `FQuat`, e o que é gimbal lock.
- [ ] Sei escolher FOV e limites de pitch considerando design e conforto.
- [ ] Implementei balanço de cabeça por distância e FOV ao correr num modificador.
- [ ] Implementei tremor de aterrissagem proporcional e com limiar.
- [ ] Toda movimentação de câmera respeita `vg.Camera.Motion`.
- [ ] Consigo explicar como Outlast usa a câmera para construir tensão sem combate.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Camera Framework**, **Player Camera Manager**, **Camera Modifiers**, **Camera Shakes**.
- **John Nesky, "50 Camera Mistakes"** (GDC 2014) — talk clássica sobre design de câmera (majoritariamente terceira pessoa, mas os princípios valem).
- **Diretrizes de acessibilidade em jogos** — o projeto **Game Accessibility Guidelines** (gameaccessibilityguidelines.com) tem recomendações sobre movimento de câmera, FOV e efeitos visuais.

---

➡️ **Próximo:** [Capítulo 19 — Interaction](cap-19-interaction.md)

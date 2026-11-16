# PARTE IV — Construindo um FPS

*Projeto 2 (completo): FPS básico — "Galpão de Testes"*

---

# Capítulo 25 — FPS Controller

## Objetivo

Ao final deste capítulo você deve conseguir:

- tratar o movimento de um FPS como **game feel**, mensurável e ajustável, e não como "velocidade máxima";
- medir o movimento com **métricas objetivas** (tempo até a velocidade máxima, distância de parada, altura e duração do pulo);
- implementar as técnicas clássicas que fazem o controle "parecer certo": **coyote time**, **jump buffering**, pulo de altura variável e aterrissagem;
- comparar o design de movimento de shooters rápidos (Call of Duty, Apex Legends, Battlefront) com o de um jogo de terror, e manter **dois perfis** no mesmo código;
- usar o Galpão de Testes como **laboratório de movimento**.

---

## Contexto

O Capítulo 17 montou o movimento da jogadora com o `CharacterMovementComponent`: andar, correr, agachar, pular. Funciona — e "funcionar" é o ponto de partida, não de chegada. A diferença entre um FPS cujo movimento é **bom** e um cujo movimento é **aceitável** raramente está em um sistema grande. Está em dezenas de detalhes de poucos milissegundos que o jogador não sabe nomear, mas sente: o pulo que "devia ter saído", a parada que "escorrega", a curva que "pesa".

A Parte IV constrói o FPS do Projeto 2 até o fim. Começar pelo movimento é deliberado: é o **micro-loop** (Capítulo 5) mais fundamental, sobre o qual mira, recoil, combate e IA serão percebidos. Uma arma perfeita num corpo que se move mal produz um shooter ruim.

---

## 25.1 Movimento como feel, e como medi-lo

"Feel" parece subjetivo, mas boa parte dele é **mensurável**. As métricas que importam:

| Métrica | O que mede | Como obter |
|---|---|---|
| **Tempo até a velocidade máxima** | Responsividade ao começar a andar | `MaxWalkSpeed / MaxAcceleration` (aproximado, sem atrito) |
| **Distância de parada** | Quanto "escorrega" ao soltar o input | ≈ v/F − (B/F²) · ln(1 + F·v/B), com B = frenagem e F = `GroundFriction` × `BrakingFrictionFactor` (aproximado) |
| **Tempo de reversão** | Quão rápido muda de direção 180° | Depende de aceleração, atrito e frenagem |
| **Altura do pulo** | Alcance vertical | ≈ v₀² / (2g × GravityScale) (Capítulo 3), num toque; segurando, soma-se ≈ v₀ × `JumpMaxHoldTime` |
| **Tempo no ar** | Duração do pulo | ≈ 2 v₀ / (g × GravityScale) |
| **Controle aéreo** | Quanto se corrige no ar | `AirControl` |

Alguns exemplos com números da Vigília (Capítulo 17) e de um perfil de shooter:

```text
                          Vigília (terror)         Shooter rápido (referência genérica)
MaxWalkSpeed (andar)      280 cm/s                 ~600 cm/s
MaxAcceleration           900 cm/s²                ~4000 cm/s²
→ tempo até máx. (aprox.) ~0,31 s                  ~0,15 s
Frenagem                  1000 cm/s²               ~3000 cm/s²
GroundFriction            8 (× fator 2 = 16/s)     8 (× fator 2 = 16/s)
→ distância de parada     ~11 cm (~0,11 s)         ~21 cm (~0,09 s) (mais rápido, mas para "seco")
JumpZVelocity             380 cm/s                 ~520 cm/s
GravityScale              1,0                      ~1,5
→ altura do pulo (toque)  ~74 cm                   ~92 cm
→ tempo no ar (toque)     ~0,78 s                  ~0,71 s (pulo mais alto e mais curto)
JumpMaxHoldTime           0,08 s                   ~0,1 s
→ altura segurando        ~104 cm                  ~144 cm
```

⚠️ **O atrito também freia.** Com os padrões do CMC (`bUseSeparateBrakingFriction = false`, `BrakingFrictionFactor = 2`), a frenagem ao soltar o input é a soma de uma parte constante (`BrakingDecelerationWalking`) com uma parte proporcional à velocidade (`GroundFriction × BrakingFrictionFactor`) — e, nas velocidades de caminhada, a segunda domina. A conta ingênua v²/(2 × frenagem) daria ~39 cm para a Vigília, quase quatro vezes o real: para mudar o quanto o corpo "escorrega", o botão principal é o atrito, não a frenagem. É exatamente o tipo de diferença que a ferramenta de medição abaixo expõe.

Os valores do shooter são **ilustrativos**, não de nenhum jogo específico. O que importa é o padrão: shooters rápidos combinam **aceleração alta** (responsividade instantânea), **frenagem alta** (para "seco"), **gravidade aumentada** (pulos curtos e decisivos, que não deixam o jogador exposto no ar) e velocidades altas. Um jogo de terror quer quase o oposto: um corpo que leva um instante para acelerar, que tem peso — sem ficar arrastado.

### Ferramenta de medição

Medir na prática é melhor que estimar. A seção de implementação cria uma CVar `vg.Debug.Movement` que mostra na tela a velocidade horizontal, o modo de movimento e, ao pousar, a altura e a duração do último pulo. Com ela, você ajusta o feel olhando para números — e só então confirma jogando.

> 🌉 **Ponte:** é o mesmo método que você usa com performance: **medir, ajustar, medir de novo**, em vez de ajustar "no feeling". A diferença é que aqui o resultado final ainda é validado por um humano, mas os números evitam ajustes às cegas e documentam a decisão.

---

## 25.2 As técnicas que fazem o controle parecer certo

O Capítulo 1 apresentou o princípio: **o comportamento fisicamente correto frequentemente é o errado**. Aqui estão as técnicas concretas.

### Pulo de altura variável

O binding existe desde o Capítulo 14 (`Started` → `Jump`, `Completed` → `StopJumping`): soltar o botão cedo corta o impulso, e o pulo fica mais baixo. O `ACharacter` controla isso com `JumpMaxHoldTime` (por quanto tempo segurar continua aplicando impulso). Dá ao jogador **controle fino** sobre o pulo com um único botão.

⚠️ O padrão de `JumpMaxHoldTime` é **0**: impulso único, altura fixa — e aí `StopJumping` não muda nada. Até aqui o projeto nunca o ajustou, então o pulo variável **ainda não existia**. A partir deste capítulo, o valor vem do perfil de movimento.

### Coyote time

O jogador corre até a beira de uma plataforma e aperta "pular" **um instante depois** de os pés terem saído do chão. Fisicamente, já está caindo — não há onde apoiar o pulo. Mas a percepção humana diz "apertei a tempo". O **coyote time** (o nome vem do personagem de desenho animado que corre no ar antes de perceber que não há chão) é uma janela curta — tipicamente **100 a 150 ms** — depois de sair do chão sem pular, durante a qual o pulo ainda é permitido.

```text
   chão ███████████████│
                       │   ← saiu do chão (sem pular)
                       │<── coyote time (~0,12 s) ──>│
                       │   pulo ainda permitido      │  pulo negado
```

Detalhe importante: a janela só vale se a jogadora **saiu do chão andando**. Se ela saiu **pulando**, a janela não pode dar um segundo pulo.

### Jump buffering

O espelho do coyote time: o jogador aperta "pular" **um instante antes** de tocar o chão. Sem buffer, o input é ignorado (está no ar) e o pulo "não sai" — uma das frustrações mais comuns em jogos com plataformas. Com buffer, o pedido é **guardado** por uma janela curta e executado no momento do pouso.

```text
                │<── buffer (~0,12 s) ──>│
   apertou ─────┘                        └── tocou o chão → pula imediatamente
```

É a mesma ideia do buffer de disparo da arma semiautomática (Capítulo 20): um input dado um pouco antes do momento permitido não deve se perder.

### Aterrissagem

Ao pousar de uma queda alta, muitos jogos aplicam uma **penalidade breve**: a velocidade é reduzida por uma fração de segundo, a câmera afunda (o tremor do Capítulo 18). Isso dá **peso** à queda e desestimula pular de alturas grandes sem pensar — num jogo de terror, também é um momento de **ruído** (Capítulo 17: a aterrissagem é o passo mais alto).

### Controle aéreo

`AirControl` define quanto o input muda a direção no ar. Zero: o pulo é um compromisso total (realista, punitivo). Um: o jogador "dirige" no ar (arcade). Shooters costumam ficar no meio, com algum controle para correções; jogos de plataforma, perto do alto.

---

## 25.3 Referências: movimento em shooters

**[FATO PÚBLICO]** A movimentação é um dos elementos mais característicos e discutidos dos shooters modernos. *Apex Legends* (Respawn, 2019) é amplamente conhecido por movimentos como **deslizar** (*slide*) a partir da corrida, inclusive em descidas, e por escaladas; *Call of Duty: Modern Warfare* (2019) incluiu deslizar, um modo de corrida mais rápido por tempo limitado (*tactical sprint*) e a possibilidade de apoiar a arma em bordas (*mounting*); *Star Wars Battlefront II* (DICE, 2017) combina movimentação de soldado com personagens heroicos de mobilidade própria. Em comunidades desses jogos, técnicas de movimento — e mudanças nelas entre edições ou atualizações — são tema constante de discussão.

**[INFERÊNCIA]** O que essas referências têm em comum, do ponto de vista de design, é que **movimento é um eixo de habilidade**: jogadores que se movem melhor (mudam de direção com precisão, usam deslizes para mudar a altura do corpo e a velocidade, escolhem rotas) ganham vantagem real em combate. Isso exige que o movimento seja **responsivo** (aceleração e frenagem altas), **expressivo** (ações com timing e técnica) e **previsível** (as mesmas entradas produzem os mesmos resultados — o que exclui aleatoriedade e exige o determinismo de passo do Capítulo 3).

Num jogo de terror, o eixo de habilidade é outro: **decisão** (quando correr, quando agachar, por onde ir) mais que **execução**. Movimento expressivo demais dá poder ao jogador — e, como o Capítulo 21 mostrou, poder dissolve a vulnerabilidade.

### Dois perfis, um código

A conclusão prática para o projeto: o **mesmo** `AVGCharacter` precisa suportar dois perfis de movimento — o da Vigília (terror) e o do Galpão (shooter de teste). Os parâmetros do CMC, mais os parâmetros deste capítulo (coyote time, buffer, aterrissagem), vão para um **perfil de movimento como Data Asset** — o desafio do Capítulo 17, agora consolidado.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Métricas de movimento | SLOs/benchmarks de resposta | O objetivo é uma faixa que produz uma sensação, não um mínimo |
| Coyote time / buffer | Tolerância a jitter; janelas de graça; *retry* com janela | A tolerância existe para corrigir a **percepção humana**, não a rede |
| Perfis de movimento | Configuração por ambiente/tenant | Cada perfil é uma **identidade de jogo** diferente |

---

## Implementação

### 1. O perfil de movimento

```cpp
// Source/Vigilia/Player/VGMovementProfile.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGMovementProfile.generated.h"

/** Identidade de movimento de um personagem: parâmetros do CMC + técnicas de game feel. */
UCLASS(BlueprintType)
class VIGILIA_API UVGMovementProfile : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Speed", meta = (ClampMin = "0.0"))
    float WalkSpeed = 280.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Speed", meta = (ClampMin = "0.0"))
    float SprintSpeed = 480.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Speed", meta = (ClampMin = "0.0"))
    float CrouchSpeed = 150.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Response", meta = (ClampMin = "0.0"))
    float MaxAcceleration = 900.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Response", meta = (ClampMin = "0.0"))
    float BrakingDeceleration = 1000.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Response", meta = (ClampMin = "0.0"))
    float GroundFriction = 8.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Jump", meta = (ClampMin = "0.0"))
    float JumpZVelocity = 380.0f;

    /** Por quanto tempo segurar o botão continua aplicando o impulso (s). 0 = altura fixa. */
    UPROPERTY(EditDefaultsOnly, Category = "Jump", meta = (ClampMin = "0.0"))
    float JumpMaxHoldTime = 0.08f;

    UPROPERTY(EditDefaultsOnly, Category = "Jump", meta = (ClampMin = "0.0"))
    float GravityScale = 1.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Jump", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float AirControl = 0.25f;

    /** Janela após sair do chão andando em que o pulo ainda é permitido (s). */
    UPROPERTY(EditDefaultsOnly, Category = "Feel", meta = (ClampMin = "0.0"))
    float CoyoteTime = 0.12f;

    /** Janela antes de tocar o chão em que um pedido de pulo é guardado (s). */
    UPROPERTY(EditDefaultsOnly, Category = "Feel", meta = (ClampMin = "0.0"))
    float JumpBufferTime = 0.12f;

    /** Velocidade de queda (cm/s) a partir da qual há penalidade de aterrissagem. */
    UPROPERTY(EditDefaultsOnly, Category = "Feel", meta = (ClampMin = "0.0"))
    float HardLandingSpeed = 900.0f;

    /** Fração da velocidade horizontal mantida após uma aterrissagem dura. */
    UPROPERTY(EditDefaultsOnly, Category = "Feel", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float HardLandingSpeedRetained = 0.4f;
};
```

🔁 **Refatoração do Capítulo 17:** `WalkSpeed` e `SprintSpeed` saem do `AVGCharacter` e passam a vir do perfil. O personagem tem uma propriedade `MovementProfile` e aplica o perfil ao CMC no `BeginPlay` (e sempre que o perfil for trocado em runtime — por exemplo, por um cheat no Galpão).

```cpp
// VGCharacter.h (adições)
public:
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Movement")
    void ApplyMovementProfile(UVGMovementProfile* Profile);

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Movement")
    TObjectPtr<UVGMovementProfile> MovementProfile;

    virtual bool CanJumpInternal_Implementation() const override;
    virtual void OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode) override;
    virtual void OnJumped_Implementation() override;

private:
    void HandleJumpPressed();
    void HandleJumpReleased();

    float LeftGroundTime = -1.0f;       // quando saiu do chão SEM pular
    float JumpBufferedUntil = -1.0f;    // até quando um pulo pedido no ar vale
    bool bJumpedSinceGrounded = false;
    bool bJumpHeld = false;
```

```cpp
// VGCharacter.cpp (trechos novos)
#include "Player/VGMovementProfile.h"

void AVGCharacter::ApplyMovementProfile(UVGMovementProfile* Profile)
{
    if (!Profile)
    {
        return;
    }
    MovementProfile = Profile;

    UCharacterMovementComponent* Move = GetCharacterMovement();
    Move->MaxAcceleration = Profile->MaxAcceleration;
    Move->BrakingDecelerationWalking = Profile->BrakingDeceleration;
    Move->GroundFriction = Profile->GroundFriction;
    Move->JumpZVelocity = Profile->JumpZVelocity;
    Move->GravityScale = Profile->GravityScale;
    Move->AirControl = Profile->AirControl;
    Move->MaxWalkSpeedCrouched = Profile->CrouchSpeed;
    Move->MaxWalkSpeed = bIsSprinting ? Profile->SprintSpeed : Profile->WalkSpeed;
    JumpMaxHoldTime = Profile->JumpMaxHoldTime; // propriedade do ACharacter, não do CMC
}

// No BeginPlay: ApplyMovementProfile(MovementProfile);
// Em UpdateSprint: usar MovementProfile->WalkSpeed / SprintSpeed.

// Bindings de pulo trocados por handlers próprios:
//   JumpAction Started   → HandleJumpPressed
//   JumpAction Completed → HandleJumpReleased

void AVGCharacter::HandleJumpPressed()
{
    bJumpHeld = true;
    if (CanJump())
    {
        Jump();
        return;
    }
    // No ar e sem coyote time: guarda o pedido para o pouso (jump buffering).
    if (GetCharacterMovement()->IsFalling() && MovementProfile)
    {
        JumpBufferedUntil = GetWorld()->GetTimeSeconds() + MovementProfile->JumpBufferTime;
    }
}

void AVGCharacter::HandleJumpReleased()
{
    bJumpHeld = false;
    StopJumping(); // pulo de altura variável
}

void AVGCharacter::OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode)
{
    Super::OnMovementModeChanged(PrevMovementMode, PreviousCustomMode);

    const bool bWasGrounded = (PrevMovementMode == MOVE_Walking || PrevMovementMode == MOVE_NavWalking);
    if (bWasGrounded && GetCharacterMovement()->IsFalling() && !bJumpedSinceGrounded)
    {
        LeftGroundTime = GetWorld()->GetTimeSeconds(); // saiu da beirada andando: abre a janela
    }

    // Jump buffering: o pedido feito pouco antes do pouso é executado agora.
    // Tem de ser aqui, e não no Landed: o Landed roda ainda em Falling; logo depois o CMC
    // muda para Walking e o Super acima chama ResetJumpState(), que apagaria um Jump() feito lá.
    const bool bJustLanded = PrevMovementMode == MOVE_Falling && GetCharacterMovement()->IsMovingOnGround();
    if (bJustLanded && GetWorld()->GetTimeSeconds() <= JumpBufferedUntil)
    {
        JumpBufferedUntil = -1.0f;
        Jump(); // consumido pelo CMC no próximo tick (CheckJumpInput)
        if (!bJumpHeld)
        {
            // O botão já foi solto: pulo curto, como se tivesse sido um toque.
            GetWorldTimerManager().SetTimerForNextTick(this, &AVGCharacter::StopJumping);
        }
    }
}

void AVGCharacter::OnJumped_Implementation()
{
    Super::OnJumped_Implementation();
    bJumpedSinceGrounded = true;
    LeftGroundTime = -1.0f; // um pulo fecha a janela de coyote
}

bool AVGCharacter::CanJumpInternal_Implementation() const
{
    if (Super::CanJumpInternal_Implementation())
    {
        return true;
    }
    // Coyote time: caindo, sem ter pulado, pouco depois de sair do chão.
    if (!MovementProfile || bJumpedSinceGrounded || LeftGroundTime < 0.0f || bIsCrouched)
    {
        return false;
    }
    const float SinceLeft = GetWorld()->GetTimeSeconds() - LeftGroundTime;
    return GetCharacterMovement()->IsFalling() && SinceLeft <= MovementProfile->CoyoteTime;
}

void AVGCharacter::Landed(const FHitResult& Hit)
{
    const float FallSpeed = FMath::Abs(GetCharacterMovement()->Velocity.Z); // antes do Super
    Super::Landed(Hit);

    bJumpedSinceGrounded = false;
    LeftGroundTime = -1.0f;

    if (MovementProfile && FallSpeed >= MovementProfile->HardLandingSpeed)
    {
        // Aterrissagem dura: perde parte da velocidade horizontal (peso).
        FVector& Velocity = GetCharacterMovement()->Velocity;
        Velocity.X *= MovementProfile->HardLandingSpeedRetained;
        Velocity.Y *= MovementProfile->HardLandingSpeedRetained;
    }

    // O jump buffer NÃO é executado aqui — ver OnMovementModeChanged.

    // ... tremor de aterrissagem do Cap. 18 (usando FallSpeed) ...
}
```

### Explicação das decisões

- **Coyote time pela própria regra de pulo do personagem** (`CanJumpInternal`), e não por um "pulo manual": o CMC continua aplicando o impulso do jeito dele, com altura variável, e o resto da engine (inclusive a predição de rede do Capítulo 67) continua consultando a mesma função.
- **A janela só abre ao sair do chão sem pular** (`OnMovementModeChanged` + `bJumpedSinceGrounded`): impede o "segundo pulo" no ar.
- **Buffer executado na troca Falling → Walking (`OnMovementModeChanged`), não no `Landed`.** A ordem dentro do CMC importa: `Landed` é chamado com o personagem ainda em `Falling`; em seguida o CMC muda o modo para `Walking`, e o `ACharacter::OnMovementModeChanged` chama `ResetJumpState()`, que zera `bPressedJump`. Um `Jump()` feito no `Landed` seria apagado no mesmo frame — o pulo "não sai", e o bug parece intermitente. Esse é o tipo de detalhe que só a leitura do código da engine (ou o log) revela. Sutileza do botão já solto: o pulo bufferizado vira um pulo curto, coerente com o pulo de altura variável. `SetTimerForNextTick` deixa o impulso do primeiro frame acontecer antes de cortar.
- **Velocidade de queda lida antes do `Super::Landed`**: depois dele, o CMC já zerou a componente vertical.
- **Tempo de jogo** (`GetTimeSeconds`) para as janelas: sob `slomo`, as janelas também desaceleram — coerente com o resto do mundo (Capítulo 3).
- **Aterrissagem dura reduz a velocidade horizontal diretamente.** A alteração acontece dentro do `Landed`, que o próprio CMC chama durante a simulação do movimento. Por isso ela é reexecutada igual no cliente e no servidor, e o Capítulo 67 mostra que ela já é compatível com o movimento preditivo. O cuidado em multiplayer é outro: o valor de `HardLandingSpeedRetained` precisa ser o mesmo nas duas pontas.

### 2. A medição

```cpp
// VGCharacter.cpp
static TAutoConsoleVariable<bool> CVarVGDebugMovement(
    TEXT("vg.Debug.Movement"), false,
    TEXT("Mostra velocidade, modo de movimento e métricas do último pulo."), ECVF_Default);
```

Com a CVar ligada, o personagem (num tick de debug, ligado só enquanto a CVar estiver ativa) mostra com `GEngine->AddOnScreenDebugMessage`: velocidade horizontal, modo de movimento, e — calculadas entre `OnJumped` e `Landed` — a **altura máxima** e a **duração** do último pulo. A implementação é o exercício da Parte 2.

### 3. Os dois perfis

- **`DA_Movimento_Vigilia`** — os valores do Capítulo 17 e da tabela da seção 25.1 (coluna terror).
- **`DA_Movimento_Galpao`** — perfil de shooter: velocidades e acelerações altas, `GravityScale ≈ 1,5`, pulo mais alto e mais curto, `AirControl ≈ 0,4`.

Um cheat `VGMovementProfile <nome>` (no `UVGCheatManager`) troca o perfil em runtime. No Galpão, uma placa interativa (um `BP_Placa` filho de `AVGPickup`, sem consumo) troca para o perfil de shooter ao entrar no estande e de volta ao sair.

---

## Decisões arquiteturais

1. **Movimento é medido** (`vg.Debug.Movement`) antes e depois de cada ajuste.
2. **Perfil de movimento como Data Asset** (`UVGMovementProfile`), aplicado ao CMC; dois perfis no projeto.
3. **Coyote time via `CanJumpInternal`**, só ao sair do chão andando; **buffer executado no pouso** (na troca de modo, depois do `ResetJumpState` da engine), respeitando o pulo variável.
4. **Aterrissagem dura** reduz a velocidade (peso), dentro do fluxo do CMC (compatível com a predição, Cap. 67).
5. **Janelas em tempo de jogo.**
6. **Movimento expressivo (deslizar, escalar) só no perfil do Galpão**, se e quando implementado; a Vigília prioriza decisão, não execução.

---

## Armadilhas

- **Ajustar movimento "no feeling"** sem métricas.
- **Coyote time que permite pulo duplo.**
- **Buffer longo demais** — o personagem pula "sozinho" ao pousar.
- **Executar o buffer no `Landed`** — o `ResetJumpState()` da troca para `Walking` apaga o `Jump()` no mesmo frame.
- **Ler a velocidade de queda depois do `Super::Landed`.**
- **Gravidade e pulo realistas** num shooter rápido (flutuante) — ou movimento de shooter num jogo de terror (poder demais).
- **Parâmetros de movimento espalhados** entre código, Blueprint e CMC sem um dono.

---

## Exercício

**Parte 1 — perfis (1,5 h).** Implemente `UVGMovementProfile`, a refatoração do personagem e os dois perfis. Crie o cheat de troca de perfil.

**Parte 2 — medição (1 h).** Implemente `vg.Debug.Movement` com velocidade, modo e métricas do último pulo. Compare a altura e a duração medidas com as estimativas da tabela da seção 25.1. Por que diferem um pouco? (Pense no Capítulo 3: integração discreta.)

**Parte 3 — coyote e buffer (1 h).** No Galpão, construa um pequeno percurso de plataformas (caixas) com vãos. Jogue com `CoyoteTime = 0` e `JumpBufferTime = 0`, e depois com 0,12. Conte quantas vezes "o pulo não saiu" em cada caso, em dez tentativas. Ajuste até não haver falhas percebidas sem que o percurso fique trivial.

**Parte 4 — os dois mundos (30 min).** Jogue cinco minutos no Pátio com o perfil do Galpão e cinco minutos no Galpão com o perfil da Vigília. Descreva no `DEVLOG.md`, em termos de MDA (Capítulo 5), o que muda na estética de cada espaço.

---

## Desafio — deslizar

Implemente o **deslize** (*slide*) no perfil do Galpão, inspirado nos shooters de referência:

1. Ao apertar "agachar" **enquanto corre** acima de uma velocidade mínima, a jogadora entra num **modo de deslize**: cápsula agachada, atrito muito baixo, frenagem baixa, sem input lateral significativo, por até ~0,8 s ou até a velocidade cair abaixo de um limiar.
2. Em **descidas**, o deslize ganha velocidade (projete a gravidade no plano do chão — Capítulo 17, seção 17.1).
3. Ao terminar, a jogadora fica agachada (e pode levantar).
4. Ao deslizar, a câmera inclina levemente (um *roll* de 3–5° — um modificador, Capítulo 18).

Implementação sugerida: um **modo de movimento customizado** (`MOVE_Custom`) no CMC, numa subclasse do componente de movimento — ou, mais simples, trocar temporariamente atrito e frenagem enquanto um estado `bIsSliding` estiver ativo. Compare as duas abordagens e registre a escolha. *(No Capítulo 67, você vai descobrir que a primeira é a que sobrevive ao multiplayer.)*

---

## Uso de IA

1. **Para ajustar com números:**
   > "Quero que o movimento do meu personagem em primeira pessoa (Unreal Engine 5, CharacterMovementComponent) atinja a velocidade máxima de 600 cm/s em ~0,15 s, pare em ~0,2 s, tenha pulo de ~90 cm de altura com ~0,7 s no ar e controle aéreo moderado. Calcule MaxAcceleration, BrakingDecelerationWalking, JumpZVelocity e GravityScale aproximados, explique as aproximações e o efeito do GroundFriction."

2. **Para revisar as técnicas de feel:**
   > "Revise esta implementação de coyote time e jump buffering num ACharacter da Unreal Engine 5. Procure: pulo duplo indevido, buffer que dispara depois de muito tempo, interação com pulo de altura variável, comportamento ao agachar e problemas que surgiriam em multiplayer com predição de movimento. [código]"

3. **Para comparar design de movimento:**
   > "Compare o design de movimento de shooters rápidos modernos (deslizar, corrida tática, escalada) com o de jogos de terror em primeira pessoa. Para cada técnica de movimento, explique o que ela acrescenta ao eixo de habilidade e o que ela tira da sensação de vulnerabilidade. Separe o que é observável nos jogos do que é inferência."

---

## Checklist

- [ ] Sei medir o movimento com métricas objetivas e estimá-las a partir dos parâmetros.
- [ ] Implementei coyote time sem pulo duplo e jump buffering coerente com o pulo variável.
- [ ] Implementei penalidade de aterrissagem dura.
- [ ] O personagem usa um perfil de movimento como Data Asset, com dois perfis no projeto.
- [ ] Tenho a ferramenta `vg.Debug.Movement` e a usei para ajustar.
- [ ] Sei explicar por que shooters e jogos de terror pedem movimentos diferentes.

---

## Para ir além

- **Steve Swink, *Game Feel*** — capítulos sobre métricas de controle e sobre como medir resposta.
- **GDC Vault** (gdcvault.com) — busque talks sobre *movement design* e *game feel* em shooters e plataformas; muitas discutem coyote time, buffering e curvas de pulo.
- **Código-fonte da engine** — `Character.cpp` (`CanJumpInternal_Implementation`, `CheckJumpInput`) e `CharacterMovementComponent.cpp` (`DoJump`), para ver exatamente como a engine decide pulos.

---

➡️ **Próximo:** [Capítulo 26 — Weapon System](cap-26-weapon-system.md)

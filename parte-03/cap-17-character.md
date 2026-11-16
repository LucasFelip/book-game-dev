# Capítulo 17 — Character

## Objetivo

Ao final deste capítulo você deve conseguir:

- usar com fluência a **matemática vetorial** que o movimento exige: comprimento, normalização, produto escalar, produto vetorial e projeção em plano;
- entender o **pipeline do `CharacterMovementComponent`** a cada frame: do pedido de input à cápsula movida, com colisão, degraus, rampas e gravidade;
- conhecer os **parâmetros que definem a sensação** do movimento e o efeito de cada um;
- implementar **correr** e **agachar** com regras de design (correr só para frente, câmera suave ao agachar);
- criar o **sistema de passos** (`UVGFootstepComponent`) baseado em distância e superfície — a fonte do som dos passos e, mais adiante, do ruído que a Presença ouve.

---

## Contexto

No Capítulo 14, `HandleMove` chamava `AddMovementInput` e a personagem andava. Mas, como aquele capítulo avisou, `AddMovementInput` **não move nada**: ele registra uma intenção. Quem transforma a intenção em movimento é o **`CharacterMovementComponent`** (CMC), um dos sistemas mais sofisticados da engine — ele resolve caminhar em rampas, subir degraus, deslizar em paredes, cair, pousar, nadar, e, em multiplayer, prever e corrigir movimento através da rede (Capítulo 67).

Para a Vigília, o movimento é central de um jeito particular: a experiência-alvo é **vulnerabilidade** (Capítulo 5). Andar devagar, agachar para passar sem ser ouvida, correr quando não há escolha — e cada passo fazendo um som que a Presença pode ouvir. O movimento não é só deslocamento; é uma **decisão tática** com custo sonoro. Este capítulo constrói a base disso.

---

## 17.1 Matemática vetorial, aplicada

Você já viu vetores na graduação. O que importa aqui é a fluência: olhar para uma pergunta de gameplay e enxergar a operação.

### Vetor como posição e como direção

O mesmo `FVector` pode ser um **ponto** (onde algo está) ou uma **direção com magnitude** (para onde e quanto). A diferença entre dois pontos é uma direção:

```cpp
const FVector ToEnemy = EnemyLocation - MyLocation;   // direção (e distância) de mim até o inimigo
const float Distance = ToEnemy.Size();                // comprimento
const FVector Direction = ToEnemy.GetSafeNormal();    // direção unitária (comprimento 1); segura contra vetor zero
```

Use `GetSafeNormal()` em vez de normalizar "na mão": dividir por um comprimento zero é um bug clássico (um inimigo exatamente na mesma posição do jogador).

E uma otimização comum: para **comparar** distâncias, use o comprimento ao quadrado (`SizeSquared()`, `FVector::DistSquared`), que evita a raiz quadrada:

```cpp
if (FVector::DistSquared(A, B) < FMath::Square(Radius)) { /* dentro do raio */ }
```

### Produto escalar: "quanto disto está naquela direção?"

O **produto escalar** (*dot product*) de dois vetores unitários é o **cosseno do ângulo** entre eles: 1 se apontam para o mesmo lado, 0 se são perpendiculares, −1 se opostos. Com um vetor qualquer e um unitário, ele dá a **projeção**: "quanto deste vetor está nesta direção".

```text
          Forward (unitário)
             ▲
             │   ● inimigo (dot > 0: à frente)
             │  /
             │ / θ
   ──────────●─────────►   dot = cos θ
           jogadora
             │
             │   ● (dot < 0: atrás)
```

Perguntas de gameplay que são produtos escalares:

```cpp
// O inimigo está à minha frente?
const bool bInFront = FVector::DotProduct(GetActorForwardVector(), ToEnemy.GetSafeNormal()) > 0.0f;

// Está dentro de um cone de visão de 60° (30° para cada lado)?
const bool bInCone = FVector::DotProduct(Forward, ToEnemy.GetSafeNormal()) > FMath::Cos(FMath::DegreesToRadians(30.0f));

// Quanto da minha velocidade é "para frente" e quanto é "para o lado"?
const float ForwardSpeed = FVector::DotProduct(Velocity, GetActorForwardVector());
const float SideSpeed    = FVector::DotProduct(Velocity, GetActorRightVector());
```

O teste de cone é exatamente a lanterna de Alan Wake (Capítulo 1), o spawner "educado" (Capítulo 8) e a percepção de visão da IA (Capítulo 36). Comparar com o **cosseno** do ângulo, pré-calculado, em vez de calcular o ângulo com `acos`, é a forma barata.

### Produto vetorial: perpendicular e "de que lado"

O **produto vetorial** (*cross product*) de dois vetores é um terceiro vetor **perpendicular** aos dois. Duas aplicações comuns:

```cpp
// De que lado está o inimigo — esquerda ou direita?
const FVector Cross = FVector::CrossProduct(Forward, ToEnemy);
const bool bOnRight = Cross.Z > 0.0f; // atenção: o sinal depende da convenção de eixos da engine — verifique

// Uma direção "lateral" a partir de uma direção e do "para cima"
const FVector Side = FVector::CrossProduct(FVector::UpVector, Forward).GetSafeNormal();
```

O comentário sobre o sinal não é preciosismo: a Unreal usa um sistema de coordenadas *left-handed* (X frente, Y direita, Z cima), e a regra da mão para o produto vetorial muda de acordo. Teste com `DrawDebugLine` antes de confiar.

### Projeção em plano: movimento em rampas

Para mover algo **ao longo de uma superfície inclinada**, projeta-se a direção desejada no plano da superfície, removendo a componente que "entra" no chão:

```cpp
const FVector AlongSlope = FVector::VectorPlaneProject(DesiredDirection, FloorNormal).GetSafeNormal();

// Ângulo de uma rampa em relação ao "para cima":
const float SlopeDegrees = FMath::RadiansToDegrees(FMath::Acos(FVector::DotProduct(FloorNormal, FVector::UpVector)));
```

O CMC faz isso internamente — e você vai precisar da mesma operação para a IA, para posicionar objetos no chão e para efeitos que acompanham superfícies (Capítulo 54).

> 🌉 **Ponte:** se você já trabalhou com *embeddings* e similaridade de cosseno em busca semântica, o produto escalar de vetores unitários é **a mesma operação**, num espaço de 3 dimensões em vez de 1.536.

---

## 17.2 O pipeline do CharacterMovementComponent

A cada tick, o CMC executa, de forma simplificada:

```text
 1. Consumir o input acumulado (AddMovementInput do frame) → vetor de aceleração desejada
 2. Conforme o MODO DE MOVIMENTO atual:
      Walking ─► aceleração limitada por MaxAcceleration
                 + atrito/frenagem (GroundFriction, BrakingDeceleration)
                 + limite de velocidade (MaxWalkSpeed)
                 → mover a cápsula com SWEEP ao longo do chão
                 → se bater num degrau baixo: subir (MaxStepHeight)
                 → se bater numa parede: DESLIZAR ao longo dela
                 → procurar o chão (FindFloor): ainda é "andável"? (WalkableFloorAngle)
      Falling ─► gravidade (× GravityScale) + controle aéreo (AirControl)
                 → sweep; ao tocar chão andável: Landed → Walking
      Swimming / Flying / Custom ─► regras próprias
 3. Frames longos são subdivididos em subpassos (MaxSimulationTimeStep — Cap. 3)
 4. Atualizar a velocidade resultante (Velocity) e notificar mudanças de modo
```

Três detalhes que explicam comportamentos que você já observou no Pátio:

- **Deslizar em paredes.** Ao andar em diagonal contra uma parede, a personagem não para: ela desliza. O CMC remove a componente do movimento que "entra" na parede (uma projeção em plano) e mantém o resto. Sem isso, encostar em qualquer superfície seria grudar.
- **Degraus.** Obstáculos com altura até `MaxStepHeight` são subidos automaticamente. É por isso que a escada da Casa de Força funciona sem rampa invisível — se os degraus respeitarem a métrica do Capítulo 7 (~18 cm) e o `MaxStepHeight` padrão for maior que isso.
- **Rampas íngremes.** Superfícies com inclinação acima de `WalkableFloorAngle` não são "chão": a personagem escorrega ou não sobe. É uma ferramenta de level design — rampas íngremes viram barreiras naturais.

### Modos de movimento e eventos

O modo atual (`MOVE_Walking`, `MOVE_Falling`, `MOVE_Swimming`, `MOVE_Flying`, `MOVE_Custom`, entre outros) é **estado discreto** (Capítulo 4), e mudanças são anunciadas:

- `ACharacter::OnMovementModeChanged` (sobrescrevível) e o delegate `MovementModeChangedDelegate`;
- `ACharacter::Landed` (sobrescrevível) e o delegate `LandedDelegate` — ao pousar, com o `FHitResult` do chão;
- `ACharacter::OnJumped` — ao pular.

Esses eventos são a forma certa de reagir a "começou a cair", "pousou" — por exemplo, para tocar um som de aterrissagem proporcional à velocidade de queda, ou para avisar a IA de um ruído alto.

---

## 17.3 Os parâmetros que definem a sensação

O CMC tem dezenas de propriedades. As que mais mudam o *feel*:

| Parâmetro | O que faz | Sensação quando baixo | Sensação quando alto |
|---|---|---|---|
| `MaxWalkSpeed` (cm/s) | Velocidade máxima andando | Lento, pesado, cauteloso | Rápido, ágil |
| `MaxAcceleration` | Quão rápido atinge a velocidade | "Patinando", com inércia | Responsivo, instantâneo |
| `BrakingDecelerationWalking` | Frenagem sem input | Escorrega ao parar | Para "seco" |
| `GroundFriction` | Atrito com o chão (afeta mudanças de direção) | Gelo | Aderência |
| `JumpZVelocity` | Força do pulo | Pulo baixo | Pulo alto |
| `GravityScale` | Multiplicador da gravidade | Flutuante, "lunar" | Pesado, rápido de cair |
| `AirControl` (0–1) | Quanto se controla no ar | Pulo comprometido | Pulo "dirigível" |
| `MaxStepHeight` | Altura máxima de degrau | Tropeça em pouco | Sobe obstáculos grandes |
| `WalkableFloorAngle` | Rampa máxima andável | Rampas leves bloqueiam | Sobe quase tudo |

Como referência de escala: uma pessoa caminhando tranquilamente anda a cerca de **1,3–1,5 m/s** (130–150 cm/s). Jogos em primeira pessoa costumam usar velocidades bem maiores, porque andar a velocidade real num ambiente virtual parece arrastado — a câmera não transmite o esforço do corpo, e os espaços de jogo são, em geral, maiores que os reais. Para a Vigília, um ponto de partida razoável:

```text
Andar ...................... ~280 cm/s   (cauteloso, mas não tedioso)
Correr ..................... ~480 cm/s   (fuga; sons altos)
Agachado ................... ~150 cm/s   (furtivo; quase silencioso)
```

**[INFERÊNCIA]** Um shooter como os da série Call of Duty transmite velocidades bem mais altas e acelerações quase instantâneas — é o que se sente jogando; os valores internos não são públicos. O Capítulo 25 compara. O ponto agora é que **esses números são dados de design** (`EditDefaultsOnly` no Blueprint), e serão ajustados em playtest.

---

## 17.4 Agachar

O `ACharacter` tem suporte nativo a agachar:

- habilitar (`GetCharacterMovement()->GetNavAgentPropertiesRef().bCanCrouch = true`, ou a opção *Can Crouch* no componente);
- `Crouch()` / `UnCrouch()` — pedem a mudança; o CMC aplica no tick;
- a cápsula encolhe para a meia-altura agachada (*Crouched Half Height*), e a velocidade passa a ser `MaxWalkSpeedCrouched`;
- **levantar pode ser impedido**: se não houver espaço acima (um duto, uma mesa), o CMC mantém a personagem agachada e continua tentando levantar enquanto ela "quiser" (`bWantsToCrouch`). Isso é exatamente o comportamento desejado: a jogadora não fica presa no teto.

### O problema da câmera

Ao agachar, a cápsula encolhe e o ator é **reposicionado para baixo** (para manter os pés no chão). A câmera, presa à cápsula, desce **de uma vez** — num frame. Em primeira pessoa, isso é desconfortável e quebra a sensação de corpo.

A técnica comum é **compensar e suavizar**: no momento em que a cápsula muda, aplicar à câmera um deslocamento igual e oposto ao ajuste (ela "fica onde estava"), e então decair esse deslocamento para zero ao longo de uma fração de segundo. O `ACharacter` avisa exatamente quanto a cápsula mudou, em `OnStartCrouch` e `OnEndCrouch` — e o decaimento usa o `VGMath::ExpDecayTo` do Capítulo 3. A implementação está na seção de código.

---

## 17.5 Correr

Correr, na versão mais simples, é trocar `MaxWalkSpeed`. A versão boa tem **regras de design**:

- **Só para frente.** Correr de lado ou de costas na mesma velocidade parece errado e facilita demais a fuga. Regra: corre-se apenas se a direção pedida estiver dentro de um cone à frente — um **produto escalar** entre o input e a frente (seção 17.1).
- **Não agachado.**
- **No ar, mantém-se o estado** (não se acelera mais, mas também não se perde a velocidade de corrida no meio do pulo).

E uma decisão de design que a Vigília toma conscientemente: **não haverá estamina** (fôlego limitado) nesta fase. Estamina é uma mecânica comum em jogos de terror e de sobrevivência — ela cria tensão nas perseguições —, mas acrescenta um recurso a mais para o jogador gerir, além da bateria. A hipótese, registrada no documento de loops (Capítulo 5), é que **o custo da corrida é o ruído**, não o cansaço. Se o playtest mostrar que correr é "de graça", a estamina volta à mesa.

> **Simplificação com prazo:** trocar `MaxWalkSpeed` diretamente funciona em single-player. Em multiplayer, o servidor e o cliente precisam concordar sobre a velocidade a cada movimento; uma troca feita só no cliente gera **correções** (o personagem "puxado" para trás). A solução correta — incorporar o estado de corrida ao sistema de movimento preditivo do CMC — é assunto do Capítulo 67. O código deste capítulo marca isso.

---

## 17.6 Passos: o movimento que faz barulho

Na Vigília, cada passo é ao mesmo tempo **feedback** (o som dos próprios pés — Capítulo 5) e **informação para o inimigo** (ruído que a Presença ouve — Capítulo 36). O sistema de passos precisa responder, a cada passo: **onde**, **em que superfície**, **com que intensidade**.

### Por distância, não por tempo

A forma ingênua é emitir um passo a cada X segundos enquanto a personagem anda. Ela falha de duas formas: a cadência não acompanha a velocidade (correr deveria ter passos mais frequentes **e** mais longos), e a contagem depende do relógio, não do movimento real (deslizar numa parede ou ser empurrada conta "passos" errados).

A forma robusta é **acumular a distância horizontal percorrida no chão** e emitir um passo a cada **comprimento de passada**:

```text
distância acumulada += velocidade horizontal × Δt     (só enquanto está no chão)
se distância acumulada ≥ passada:
     emitir passo; distância acumulada −= passada
```

A passada muda com o estado (agachada: passos curtos; correndo: longos), e a cadência resultante acompanha a velocidade naturalmente. E, por ser baseada em distância × Δt, ela é **independente do frame rate** (Capítulo 3).

### A superfície

Para saber em que a personagem pisou, um **trace para baixo** a partir dos pés, pedindo o material físico (Capítulo 15):

```cpp
Params.bReturnPhysicalMaterial = true;
// ... LineTraceSingleByChannel para baixo ...
const EPhysicalSurface Surface = UPhysicalMaterial::DetermineSurfaceType(Hit.PhysMaterial.Get());
```

O tipo de superfície (`Concreto`, `Metal`, `Grade`, `Água`) é o **contrato uniforme** do estudo de caso de Control (Capítulo 6): o som do passo vem do material, não de um script por chão. E, para a Presença, uma grade metálica pode ser mais "barulhenta" que concreto — um detalhe de level design que vira tática: evitar as passarelas metálicas da Casa de Força.

### Intensidade

A intensidade (*loudness*) de cada passo depende do estado:

```text
agachada ......... 0,2
andando .......... 0,5
correndo ......... 1,0
aterrissagem ..... proporcional à velocidade de queda
```

(e, no Capítulo 36, multiplicada por um fator da superfície). O componente de passos **não sabe** quem vai usar essa informação: ele **anuncia** cada passo, e o áudio (Capítulo 52) e a percepção (Capítulo 36) se inscrevem.

---

## Estudo de caso: o peso do atleta em jogos de futebol

> **Pergunta:** como jogos de futebol fazem atletas diferentes **se moverem** de forma diferente — e o que isso ensina sobre parâmetros de movimento como dados?

**[FATO PÚBLICO]** Jogos de futebol como as séries FIFA/EA Sports FC e PES/eFootball atribuem a cada atleta **atributos numéricos** publicamente visíveis no jogo, incluindo atributos de movimento como velocidade, aceleração e agilidade (os nomes e as escalas variam entre as séries e as edições). Jogadores percebem e discutem amplamente como atletas com atributos diferentes "se sentem" diferentes ao controlar — um ponta rápido e leve versus um zagueiro forte e mais lento.

**[INFERÊNCIA]** Os parâmetros do CMC da seção 17.3 são exatamente o tipo de grandeza em que atributos como esses podem ser traduzidos: velocidade máxima (`MaxWalkSpeed`), quão rápido ela é atingida (`MaxAcceleration`), capacidade de mudar de direção (atrito, taxa de rotação, e — em jogos com animação mais sofisticada — quais animações de mudança de direção estão disponíveis e quanto duram). Um atleta "ágil" não é só "mais rápido": ele **acelera mais rápido** e **muda de direção com menos perda**. Não há informação pública detalhada sobre como cada jogo mapeia seus atributos em movimento, e a maioria deles usou motores próprios (a exceção recente é o eFootball, em Unreal desde 2021) — mas o princípio de **atributos de design → parâmetros de simulação** é geral.

**[SIMPLIFICAÇÃO DIDÁTICA]** A versão mínima, na Unreal, seria um **Data Asset de perfil de movimento** (velocidade, aceleração, frenagem, atrito, taxa de giro) aplicado ao CMC de cada personagem. Na Vigília, isso não é necessário para a jogadora (um único corpo), mas será útil quando houver **três tipos de agentes** com movimentos distintos: a jogadora, a Presença e o Vigia (Parte V). O exercício deste capítulo pede um esboço.

**Lição:** **a "personalidade" de um personagem em movimento é, em grande parte, um conjunto de números de simulação.** Expor esses números como dados — e não como constantes no código — é o que permite que a diferença entre um ponta e um zagueiro, ou entre a jogadora e a Presença, seja ajustada por design.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Produto escalar / cosseno | Similaridade de cosseno em busca vetorial | Aqui, em 3D, a cada frame, para perguntas espaciais |
| CMC como pipeline de regras | Motor de regras / pipeline de validação | Cada etapa é geométrica e roda em subpassos dentro do frame |
| Modos de movimento | FSM de estado de entidade | Transições dependem de geometria (chão andável), não só de comandos |
| Passos por distância | Amostragem por evento de domínio, não por relógio | Aqui, o "evento" é a distância percorrida |
| Perfil de movimento por dados | Configuração por tenant/tipo | A configuração define a **sensação**, validada só jogando |

---

## Implementação

### 1. Correr e agachar no `AVGCharacter`

```cpp
// Source/Vigilia/Player/VGCharacter.h (adições)
public:
    virtual void PostInitializeComponents() override;
    virtual void Tick(float DeltaSeconds) override;
    virtual void OnStartCrouch(float HalfHeightAdjust, float ScaledHalfHeightAdjust) override;
    virtual void OnEndCrouch(float HalfHeightAdjust, float ScaledHalfHeightAdjust) override;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Movement")
    bool IsSprinting() const { return bIsSprinting; }

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<UInputAction> SprintAction;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<UInputAction> CrouchAction;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Movement", meta = (ClampMin = "0.0"))
    float WalkSpeed = 280.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Movement", meta = (ClampMin = "0.0"))
    float SprintSpeed = 480.0f;

    /** Corre só se o input estiver dentro deste cone à frente (cosseno: 0.7 ≈ 45°). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Movement", meta = (ClampMin = "-1.0", ClampMax = "1.0"))
    float SprintForwardDotMin = 0.7f;

    /** Velocidade com que a câmera acompanha a mudança de altura ao agachar (1/s). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Camera", meta = (ClampMin = "0.0"))
    float CrouchCameraRate = 12.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Camera")
    float CameraHeight = 72.0f;

private:
    void HandleMoveCompleted(const FInputActionValue& Value);
    void HandleSprintStarted();
    void HandleSprintCompleted();
    void HandleCrouchToggle();
    void UpdateSprint();
    void ApplyCameraHeight();

    FVector2D LastMoveInput = FVector2D::ZeroVector;
    bool bWantsToSprint = false;
    bool bIsSprinting = false;
    float CrouchCameraOffset = 0.0f;
```

```cpp
// Source/Vigilia/Player/VGCharacter.cpp (trechos novos e alterados)
#include "Core/VGMathUtils.h"
#include "GameFramework/CharacterMovementComponent.h"

AVGCharacter::AVGCharacter()
{
    // Tick existe, mas só é ligado enquanto a câmera estiver se ajustando ao agachar.
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = false;

    GetCapsuleComponent()->InitCapsuleSize(34.0f, 88.0f);

    FirstPersonCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FirstPersonCamera"));
    FirstPersonCamera->SetupAttachment(GetCapsuleComponent());
    FirstPersonCamera->SetRelativeLocation(FVector(0.0, 0.0, CameraHeight));
    FirstPersonCamera->bUsePawnControlRotation = true;

    GetCharacterMovement()->GetNavAgentPropertiesRef().bCanCrouch = true;
    // Altura agachada e velocidade agachada: configuradas no Blueprint (são dados de design).
}

void AVGCharacter::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    // Aqui os valores editados no Blueprint (WalkSpeed, CameraHeight) já valem; no construtor, ainda não.
    GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
    ApplyCameraHeight();
}

void AVGCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);
    UEnhancedInputComponent* Input = CastChecked<UEnhancedInputComponent>(PlayerInputComponent);

    if (MoveAction)
    {
        Input->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AVGCharacter::HandleMove);
        Input->BindAction(MoveAction, ETriggerEvent::Completed, this, &AVGCharacter::HandleMoveCompleted);
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
    if (SprintAction)
    {
        Input->BindAction(SprintAction, ETriggerEvent::Started, this, &AVGCharacter::HandleSprintStarted);
        Input->BindAction(SprintAction, ETriggerEvent::Completed, this, &AVGCharacter::HandleSprintCompleted);
    }
    if (CrouchAction)
    {
        Input->BindAction(CrouchAction, ETriggerEvent::Started, this, &AVGCharacter::HandleCrouchToggle);
    }
}

void AVGCharacter::HandleMove(const FInputActionValue& Value)
{
    LastMoveInput = Value.Get<FVector2D>();
    AddMovementInput(GetActorForwardVector(), LastMoveInput.Y);
    AddMovementInput(GetActorRightVector(), LastMoveInput.X);
    UpdateSprint();
}

void AVGCharacter::HandleMoveCompleted(const FInputActionValue& Value)
{
    LastMoveInput = FVector2D::ZeroVector;
    UpdateSprint();
}

void AVGCharacter::HandleSprintStarted()   { bWantsToSprint = true;  UpdateSprint(); }
void AVGCharacter::HandleSprintCompleted() { bWantsToSprint = false; UpdateSprint(); }

void AVGCharacter::HandleCrouchToggle()
{
    if (bIsCrouched)
    {
        UnCrouch(); // pode não levantar imediatamente se houver teto: o CMC continua tentando
    }
    else
    {
        Crouch();
    }
}

void AVGCharacter::UpdateSprint()
{
    // No espaço do input, "frente" é (0, 1): o produto escalar com ela é a componente Y.
    const FVector2D Direction = LastMoveInput.GetSafeNormal();
    const bool bForward = Direction.Y >= SprintForwardDotMin;

    const UCharacterMovementComponent* Move = GetCharacterMovement();
    const bool bShouldSprint = bWantsToSprint && bForward && !bIsCrouched
        && (Move->IsMovingOnGround() || bIsSprinting); // no ar, mantém o estado

    if (bShouldSprint != bIsSprinting)
    {
        bIsSprinting = bShouldSprint;
        // Simplificação: correto em single-player; em multiplayer exige integração com a predição
        // do CMC para evitar correções (Cap. 67).
        GetCharacterMovement()->MaxWalkSpeed = bIsSprinting ? SprintSpeed : WalkSpeed;
    }
}

void AVGCharacter::OnStartCrouch(float HalfHeightAdjust, float ScaledHalfHeightAdjust)
{
    Super::OnStartCrouch(HalfHeightAdjust, ScaledHalfHeightAdjust);
    UpdateSprint();                                // agachar interrompe a corrida
    CrouchCameraOffset += ScaledHalfHeightAdjust;  // a câmera "fica onde estava"...
    ApplyCameraHeight();
    SetActorTickEnabled(true);                     // ...e desce suavemente no Tick
}

void AVGCharacter::OnEndCrouch(float HalfHeightAdjust, float ScaledHalfHeightAdjust)
{
    Super::OnEndCrouch(HalfHeightAdjust, ScaledHalfHeightAdjust);
    CrouchCameraOffset -= ScaledHalfHeightAdjust;
    ApplyCameraHeight();
    SetActorTickEnabled(true);
}

void AVGCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    CrouchCameraOffset = VGMath::ExpDecayTo(CrouchCameraOffset, 0.0f, CrouchCameraRate, DeltaSeconds);
    if (FMath::IsNearlyZero(CrouchCameraOffset, 0.1f))
    {
        CrouchCameraOffset = 0.0f;
        SetActorTickEnabled(false); // convergiu: sem custo por frame
    }
    ApplyCameraHeight();
}

void AVGCharacter::ApplyCameraHeight()
{
    FirstPersonCamera->SetRelativeLocation(FVector(0.0, 0.0, CameraHeight + CrouchCameraOffset));
}
```

### Explicação das decisões

- **`LastMoveInput` guardado** porque a decisão de correr depende da direção pedida, e o handler de movimento só é chamado enquanto há input — daí o binding em `Completed` para zerar.
- **Produto escalar no espaço do input.** A regra "só para frente" virou `Direction.Y >= SprintForwardDotMin`: com o vetor de input normalizado, a componente Y **é** o produto escalar com a frente `(0, 1)`. Matemática da seção 17.1 em uma linha.
- **Tick ligado só durante a transição de câmera**, desligado ao convergir — o princípio do Capítulo 2.
- **Dados de design aplicados em `PostInitializeComponents`, não no construtor.** O construtor C++ roda com os valores padrão da classe nativa; os valores editados no `BP_VGJogadora` só são aplicados depois. Se `MaxWalkSpeed = WalkSpeed` ficasse no construtor, um `WalkSpeed` ajustado no Blueprint só valeria a partir da primeira corrida — um bug silencioso de "o ajuste não pegou".
- **`ScaledHalfHeightAdjust`** em vez de `HalfHeightAdjust`, para respeitar a escala do ator.
- **Altura agachada e velocidade agachada no Blueprint** — são dados; o C++ só habilita a capacidade.
- **Agachar é alternância (*toggle*) e correr é segurar.** É uma escolha de design comum, mas não universal; o Capítulo 55 (configurações) pode expor as duas opções para cada ação — e, graças ao Enhanced Input, isso será configuração de triggers, não código novo.

### 2. O componente de passos

Antes do código: no `Vigilia.Build.cs`, adicione `"PhysicsCore"` às dependências públicas. Na UE5, `UPhysicalMaterial` mora nesse módulo; sem a dependência, o `#include` costuma compilar (os headers chegam pelas dependências da engine), mas a chamada a `UPhysicalMaterial::DetermineSurfaceType` falha no **link** com símbolo não resolvido.

```cpp
// Source/Vigilia/Player/VGFootstepComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Chaos/ChaosEngineInterface.h"
#include "VGFootstepComponent.generated.h"

class ACharacter;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGFootstepSignature,
    FVector, Location, TEnumAsByte<EPhysicalSurface>, Surface, float, Loudness);

/**
 * Emite um evento a cada passo do personagem dono, por distância percorrida no chão.
 * Não toca som nem avisa a IA: anuncia; áudio (Cap. 52) e percepção (Cap. 36) se inscrevem.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGFootstepComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGFootstepComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Footsteps")
    FVGFootstepSignature OnFootstep;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    /** Comprimento da passada andando (cm). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps", meta = (ClampMin = "10.0"))
    float StrideLength = 75.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps", meta = (ClampMin = "0.1"))
    float CrouchStrideScale = 0.7f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps", meta = (ClampMin = "0.1"))
    float SprintStrideScale = 1.3f;

    /** Acima desta velocidade (cm/s), o passo é considerado de corrida. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps", meta = (ClampMin = "0.0"))
    float SprintSpeedThreshold = 400.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps|Loudness")
    float CrouchLoudness = 0.2f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps|Loudness")
    float WalkLoudness = 0.5f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps|Loudness")
    float SprintLoudness = 1.0f;

    /** Velocidade vertical (cm/s) que corresponde a uma aterrissagem de intensidade 1. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Footsteps|Loudness", meta = (ClampMin = "1.0"))
    float LandingSpeedForFullLoudness = 900.0f;

private:
    void EmitStep(float Loudness);
    bool TraceGround(FHitResult& OutHit) const;

    UFUNCTION()
    void HandleLanded(const FHitResult& Hit);

    TWeakObjectPtr<ACharacter> OwnerCharacter;
    float DistanceSinceStep = 0.0f;
};
```

```cpp
// Source/Vigilia/Player/VGFootstepComponent.cpp
#include "Player/VGFootstepComponent.h"

#include "Components/CapsuleComponent.h"
#include "Core/VGLog.h"
#include "GameFramework/Character.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "PhysicalMaterials/PhysicalMaterial.h"

UVGFootstepComponent::UVGFootstepComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
}

void UVGFootstepComponent::BeginPlay()
{
    Super::BeginPlay();

    OwnerCharacter = Cast<ACharacter>(GetOwner());
    if (!OwnerCharacter.IsValid())
    {
        UE_LOG(LogVigilia, Warning, TEXT("%s: o dono não é um ACharacter; passos desativados."), *GetName());
        SetComponentTickEnabled(false);
        return;
    }
    OwnerCharacter->LandedDelegate.AddDynamic(this, &UVGFootstepComponent::HandleLanded);
}

void UVGFootstepComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (OwnerCharacter.IsValid())
    {
        OwnerCharacter->LandedDelegate.RemoveDynamic(this, &UVGFootstepComponent::HandleLanded);
    }
    Super::EndPlay(EndPlayReason);
}

void UVGFootstepComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                         FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    ACharacter* Character = OwnerCharacter.Get();
    if (!Character)
    {
        return;
    }

    const UCharacterMovementComponent* Move = Character->GetCharacterMovement();
    if (!Move->IsMovingOnGround())
    {
        return; // no ar não há passos; a aterrissagem é tratada em HandleLanded
    }

    const float Speed = Move->Velocity.Size2D();
    const bool bSprinting = Speed > SprintSpeedThreshold;
    const float Stride = StrideLength
        * (Character->bIsCrouched ? CrouchStrideScale : 1.0f)
        * (bSprinting ? SprintStrideScale : 1.0f);

    DistanceSinceStep += Speed * DeltaTime; // distância × Δt: independente do frame rate
    if (DistanceSinceStep >= Stride)
    {
        DistanceSinceStep -= Stride;
        const float Loudness = Character->bIsCrouched ? CrouchLoudness
                             : (bSprinting ? SprintLoudness : WalkLoudness);
        EmitStep(Loudness);
    }
}

void UVGFootstepComponent::HandleLanded(const FHitResult& Hit)
{
    const ACharacter* Character = OwnerCharacter.Get();
    if (!Character)
    {
        return;
    }
    // Velocity no momento do Landed ainda carrega a velocidade de queda.
    const float FallSpeed = FMath::Abs(Character->GetCharacterMovement()->Velocity.Z);
    DistanceSinceStep = 0.0f;
    EmitStep(FMath::Clamp(FallSpeed / LandingSpeedForFullLoudness, WalkLoudness, 1.5f));
}

void UVGFootstepComponent::EmitStep(float Loudness)
{
    FHitResult Hit;
    const bool bHit = TraceGround(Hit);
    const EPhysicalSurface Surface = bHit
        ? UPhysicalMaterial::DetermineSurfaceType(Hit.PhysMaterial.Get())
        : SurfaceType_Default;
    const FVector Location = bHit ? Hit.ImpactPoint : GetOwner()->GetActorLocation();

    OnFootstep.Broadcast(Location, Surface, Loudness);
}

bool UVGFootstepComponent::TraceGround(FHitResult& OutHit) const
{
    const ACharacter* Character = OwnerCharacter.Get();
    const float HalfHeight = Character->GetCapsuleComponent()->GetScaledCapsuleHalfHeight();
    const FVector Start = Character->GetActorLocation();
    const FVector End = Start - FVector(0.0, 0.0, HalfHeight + 30.0);

    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGFootstepTrace), /*bTraceComplex=*/false, Character);
    Params.bReturnPhysicalMaterial = true;

    return GetWorld()->LineTraceSingleByChannel(OutHit, Start, End, ECC_Visibility, Params);
}
```

### Explicação das decisões

- **O componente só anuncia.** Ele não toca som nem conversa com a IA — o padrão de todo o projeto (gatilhos no Capítulo 15, alarme no Capítulo 13).
- **`TWeakObjectPtr<ACharacter>`** para o dono: o componente observa o personagem sem precisar de `UPROPERTY` (Capítulo 11). Na prática o dono vive mais que o componente, mas o hábito é barato.
- **Inscrição em `LandedDelegate` no `BeginPlay` e remoção no `EndPlay`** (Capítulo 4, risco 3).
- **Aterrissagem com intensidade proporcional à queda**, com um piso (`WalkLoudness`) e um teto: pular de uma caixa alta numa grade metálica deve ser **muito** mais audível que um passo.
- **Trace com `bReturnPhysicalMaterial`** e fallback para `SurfaceType_Default` quando não há material definido — para que a ausência de configuração não quebre nada, só soe genérico.
- **Tick sempre ligado.** O custo é pequeno (algumas operações e, a cada passo, um trace), e há um único personagem com o componente. Se a Presença e o Vigia usarem o mesmo componente (provável), ainda serão três. Fica anotado como simplificação.

### 3. Teste no Pátio

1. Crie `IA_Sprint` (segurar — `Shift`/analógico esquerdo pressionado) e `IA_Crouch` (`C`/`Ctrl`/botão do controle) e mapeie no `IMC_Exploracao`.
2. No `BP_VGJogadora`: atribua as ações; defina *Crouched Half Height* (~58) e *Max Walk Speed Crouched* (~150) no componente de movimento; adicione o `UVGFootstepComponent`.
3. Ligue `OnFootstep` a um `Print String` (temporário) mostrando superfície e intensidade, e a um `DrawDebugSphere` no local com raio proporcional à intensidade.
4. Crie dois materiais físicos (`PM_Concreto`, `PM_Metal`) com os tipos de superfície correspondentes; aplique `PM_Metal` à escada da Casa de Força.
5. Ande, agache, corra, pule da caixa d'água (ou de uma caixa física). Observe as esferas: elas são, literalmente, o "raio de ruído" que a Presença usará no Capítulo 36.

---

## Decisões arquiteturais

1. **Parâmetros de movimento são dados** (`EditDefaultsOnly`), ajustados por playtest.
2. **Correr: segurar; só para frente (cone por produto escalar); não agachado; mantém no ar.** Sem estamina nesta fase — o custo da corrida é o ruído (hipótese de design registrada).
3. **Câmera compensada e suavizada ao agachar**, com tick ligado só durante a transição.
4. **Passos por distância percorrida**, com passada dependente do estado.
5. **Superfície por material físico**; intensidade por estado e aterrissagem.
6. **O componente de passos só anuncia.** Áudio e percepção se inscrevem.
7. **Mudanças de velocidade feitas fora do sistema preditivo do CMC são simplificações de single-player**, marcadas para o Capítulo 67.

---

## Armadilhas

- **Normalizar vetores que podem ser zero** sem `GetSafeNormal`.
- **Calcular ângulos com `acos` para comparar** em vez de comparar cossenos.
- **Confiar no sinal do produto vetorial** sem verificar a convenção de eixos.
- **Mexer na posição da cápsula diretamente** em vez de pedir movimento ao CMC.
- **Câmera que salta ao agachar.**
- **Passos por tempo** em vez de por distância.
- **Componentes de passos que tocam som e avisam a IA diretamente.**
- **Velocidades "reais"** que deixam a exploração arrastada — ou velocidades de shooter num jogo de terror.
- **Esquecer `bReturnPhysicalMaterial`** e receber sempre a superfície padrão.

---

## Exercício

**Parte 1 — vetores (1 h).** Num ator de teste, desenhe com `DrawDebugLine` e `DrawDebugString`, a cada frame, para cada `BP_CaixaFisica` próxima: se está à frente ou atrás da jogadora (produto escalar), à esquerda ou à direita (produto vetorial — verifique o sinal), e se está dentro de um cone de 40°. Ande em volta das caixas e confirme.

**Parte 2 — correr e agachar (1,5 h).** Implemente as mudanças no `AVGCharacter`. Teste: correr de lado (não deve acelerar), agachar sob um obstáculo baixo e tentar levantar (deve continuar agachada até sair), pular correndo (mantém a velocidade).

**Parte 3 — passos (1,5 h).** Implemente o `UVGFootstepComponent` e o teste visual. Meça, com `t.MaxFPS 30` e `t.MaxFPS 120`, quantos passos são emitidos ao percorrer a estrada do Pátio de ponta a ponta. Devem ser praticamente iguais. Por quê?

**Parte 4 — ajuste de sensação (1 h).** Brinque com `MaxAcceleration`, `BrakingDecelerationWalking`, `GroundFriction` e `AirControl`. Encontre uma configuração que pareça "cautelosa, mas não pesada" para a Vigília e outra que pareça "um shooter rápido". Registre os valores das duas no `DEVLOG.md` — a segunda será o ponto de partida do Capítulo 25.

---

## Desafio — o perfil de movimento

Implemente o **perfil de movimento como Data Asset** sugerido pelo estudo de caso:

1. `UVGMovementProfile` (`UPrimaryDataAsset`) com: velocidades (andar, correr, agachado), aceleração, frenagem, atrito, controle aéreo, força do pulo.
2. Uma função no `AVGCharacter` (ou um componente pequeno) que aplica o perfil ao CMC no `BeginPlay`.
3. Dois perfis: `DA_Movimento_Jogadora` e `DA_Movimento_Presenca` (mais lenta para andar, mais rápida para correr, sem pulo). Aplique o segundo à Presença de teste do Capítulo 10 e jogue com ela.

Pergunta para o `DEVLOG.md`: os parâmetros de corrida (`SprintSpeed`, `SprintForwardDotMin`) e de passos (`StrideLength`, intensidades) deveriam estar no mesmo perfil? Que critério você usou para decidir? *(Pense em quem ajusta cada um e em quando eles mudam juntos.)*

---

## Uso de IA

1. **Para treinar matemática vetorial:**
   > "Crie dez perguntas de gameplay de jogos em primeira pessoa que se resolvem com produto escalar, produto vetorial, projeção em plano ou distância ao quadrado (por exemplo: 'o inimigo está no meu campo de visão?'). Para cada uma, peça que eu escreva a fórmula antes de mostrar a solução em C++ da Unreal. Use a convenção de eixos da Unreal (X frente, Y direita, Z cima)."

2. **Para entender o CMC:**
   > "Explique, na ordem em que acontecem num tick, as etapas do UCharacterMovementComponent da Unreal Engine 5 no modo Walking: consumo do input, aceleração, atrito e frenagem, limite de velocidade, sweep da cápsula, deslizamento em paredes, subida de degraus e detecção de chão. Indique os parâmetros que afetam cada etapa e diga quando não tiver certeza de um detalhe para a minha versão."

3. **Para design de movimento:**
   > "Compare o design de movimento de um jogo de terror em primeira pessoa focado em vulnerabilidade e de um shooter competitivo rápido: velocidades, aceleração, frenagem, pulo, agachar, correr, estamina e ruído. Para cada diferença, explique a estética que ela produz (no sentido do MDA)."

---

## Checklist

- [ ] Sei usar comprimento, normalização segura, distância ao quadrado, produto escalar, produto vetorial e projeção em plano para perguntas de gameplay.
- [ ] Entendo o pipeline do CMC e por que a personagem desliza em paredes, sobe degraus e não sobe rampas íngremes.
- [ ] Conheço os parâmetros que definem a sensação do movimento.
- [ ] Implementei correr com regras de design e agachar com câmera suave.
- [ ] Implementei passos por distância, com superfície e intensidade, emitidos como eventos.
- [ ] Sei por que trocar `MaxWalkSpeed` diretamente é uma simplificação de single-player.
- [ ] Consigo explicar como atributos de atletas em jogos de futebol podem se traduzir em parâmetros de movimento.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Character Movement Component** e **Setting Up Character Movement**; a referência de `UCharacterMovementComponent`.
- **Código-fonte da engine** — `CharacterMovementComponent.h/.cpp` (procure `PhysWalking`, `PhysFalling`, `FindFloor`, `SlideAlongSurface`, `StepUp`). É um arquivo longo; leia as funções de `PhysWalking` com calma.
- **Fletcher Dunn e Ian Parberry, *3D Math Primer for Graphics and Game Development*** — referência clássica de matemática 3D para jogos, se quiser aprofundar vetores, matrizes e rotações.

---

➡️ **Próximo:** [Capítulo 18 — Camera](cap-18-camera.md)

# Capítulo 9 — Components

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir **Actor Components**, **Scene Components** e **Primitive Components**, e saber qual usar para cada capacidade;
- montar **hierarquias de anexação** (*attachment*) e entender transforms relativos, sockets e regras de anexação;
- criar componentes no construtor (`CreateDefaultSubobject`) e em runtime (`NewObject` + `RegisterComponent`), entendendo o que é **registrar** um componente;
- escolher como componentes **se comunicam** entre si sem criar acoplamento rígido;
- decidir **quando** uma capacidade merece um componente — e quando a engine já tem um pronto;
- implementar o `UVGFlickerComponent`, a falha de luz que vai assombrar a usina inteira.

---

## Contexto

O Capítulo 6 escolheu **composição** como modelo de objetos: um Actor é um contêiner de capacidades. O Capítulo 8 mostrou o contêiner. Este capítulo mostra as capacidades.

Na prática, a maior parte do código de gameplay que você vai escrever na Unreal é código de **componentes**. A bateria do Capítulo 4 já era um. A vida, a interação, a lanterna, a percepção de ruído, o ponto de save — todos serão componentes. Entender bem o que um componente é, como ele vive e como conversa com os vizinhos é, portanto, entender a unidade básica de trabalho do resto do livro.

---

## 9.1 Os três níveis de componente

```text
UActorComponent              lógica e estado; SEM posição no espaço
  │                          ex.: UVGBatteryComponent, vida, inventário, IA de alto nível
  │
  └── USceneComponent        + TRANSFORM e hierarquia de anexação
        │                    ex.: âncoras, pontos de spawn, USpringArmComponent, UCameraComponent,
        │                         luzes (ULightComponent), áudio (UAudioComponent)
        │
        └── UPrimitiveComponent   + GEOMETRIA: renderização e/ou colisão
                                  ex.: UStaticMeshComponent, USkeletalMeshComponent,
                                       UBoxComponent, USphereComponent, UCapsuleComponent
```

A regra de escolha é direta:

- A capacidade **não tem lugar no espaço**? → `UActorComponent`. (A bateria não "está" em lugar nenhum; ela pertence à lanterna.)
- Ela **tem posição, mas não tem forma**? → `USceneComponent`. (O ponto de onde sai o feixe da lanterna; uma câmera; uma luz; uma fonte de som.)
- Ela **tem forma** — precisa ser desenhada ou colidir? → `UPrimitiveComponent`. (A malha da lanterna; o volume de um trigger.)

O custo cresce na mesma ordem. Um `UActorComponent` é praticamente só um `UObject`. Um `USceneComponent` mantém e propaga transforms. Um `UPrimitiveComponent` se registra na cena de renderização e/ou na cena de física — e é aí que mora o custo de verdade. **Não use um componente de nível superior ao necessário**: um "ponto de referência" não precisa ser uma malha invisível.

### Componentes que a engine já tem

Antes de escrever um componente, a pergunta certa é: **a engine já faz isso?** A Unreal tem dezenas de componentes prontos, e alguns resolvem problemas que iniciantes reimplementam com frequência:

| Necessidade | Componente pronto |
|---|---|
| Girar continuamente (um ventilador, uma sirene) | `URotatingMovementComponent` |
| Mover entre pontos (plataforma, elevador simples) | `UInterpToMovementComponent` |
| Projétil com gravidade, quique, *homing* | `UProjectileMovementComponent` (Capítulo 28) |
| Câmera que segue com distância e colisão | `USpringArmComponent` + `UCameraComponent` (Capítulo 18) |
| Movimento de personagem | `UCharacterMovementComponent` (Capítulo 17) |
| Som posicional | `UAudioComponent` |
| Luzes | `UPointLightComponent`, `USpotLightComponent`, `URectLightComponent` |
| Volumes de detecção | `UBoxComponent`, `USphereComponent`, `UCapsuleComponent` (Capítulo 15) |
| Efeitos de partícula | `UNiagaraComponent` (Capítulo 54) |
| Texto/ícone visível só no editor | `UBillboardComponent`, `UTextRenderComponent` |

Os ventiladores do teto da Casa de Força **não** precisam de código: um `URotatingMovementComponent` com a taxa ajustada no editor resolve. Escrever um `UVGSpinComponent` seria custo sem benefício.

---

## 9.2 Hierarquia de anexação

Scene Components formam uma **árvore**. Todo ator com presença no espaço tem um **componente raiz** (*root component*), e os demais se anexam a ele ou uns aos outros. O transform de cada componente é **relativo ao pai**; o transform no mundo é a composição de toda a cadeia até a raiz.

Um poste de luz do Pátio:

```text
BP_PosteLuz (Actor)
└── Root (USceneComponent)                      ← raiz: o "pé" do poste, no chão
    ├── Haste (UStaticMeshComponent)            ← cilindro, relativo: (0, 0, 0), escala (0.2, 0.2, 6)
    └── Braco (USceneComponent)                 ← relativo: (0, 0, 580)
        ├── Luminaria (UStaticMeshComponent)    ← relativo: (60, 0, 0)
        ├── Luz (USpotLightComponent)           ← relativo: (60, 0, -10), apontando para baixo
        └── Zumbido (UAudioComponent)           ← relativo: (60, 0, 0)
    (UVGFlickerComponent)                       ← Actor Component: fora da árvore, sem transform
```

Mover o ator move a raiz e, com ela, tudo. Girar o `Braco` gira a luminária, a luz e o som juntos. O `UVGFlickerComponent` aparece no ator mas **não** na árvore de transforms — ele é um `UActorComponent`.

Três decisões de design aparecem nessa árvore:

- **Uma raiz "neutra" (`USceneComponent`)** em vez de usar a haste como raiz. Isso permite escalar a haste (cilindro esticado) sem escalar todos os filhos junto — escala na raiz se propaga para tudo.
- **Pontos intermediários (`Braco`)** agrupam componentes que se movem juntos.
- **Posições relativas significativas:** a raiz fica no chão, de modo que "colocar o poste no chão" no editor é colocar o ator em `Z = altura do chão`.

### Anexação em runtime e sockets

No construtor, a anexação é declarada com `SetupAttachment`:

```cpp
Haste->SetupAttachment(Root);
```

Em runtime, usa-se `AttachToComponent` (ou `AttachToActor`), com **regras** que dizem o que fazer com o transform atual:

```cpp
// A lanterna passa a seguir a mão da personagem, encaixando no socket "hand_r".
Flashlight->AttachToComponent(
    CharacterMesh,
    FAttachmentTransformRules::SnapToTargetNotIncludingScale,
    TEXT("hand_r"));
```

- `KeepRelativeTransform` — mantém o transform relativo que o objeto já tinha.
- `KeepWorldTransform` — mantém a posição no mundo; recalcula o relativo.
- `SnapToTargetNotIncludingScale` / `SnapToTargetIncludingScale` — encaixa exatamente no alvo.

**Sockets** são pontos nomeados definidos em malhas (estáticas ou esqueléticas): `hand_r` na mão de um esqueleto, `Muzzle` no cano de uma arma. Anexar a um socket é como você prende uma arma na mão (Capítulo 26) ou define de onde sai o tiro (Capítulo 27).

> Lembre-se do desafio do Capítulo 2: a terceira solução para o "tremor de um frame" era **anexar** o seguidor ao alvo, em vez de copiar a posição no tick. A anexação é resolvida pela engine na propagação de transforms — sem custo de tick e sem problema de ordem.

---

## 9.3 Criando componentes

### No construtor: `CreateDefaultSubobject`

A forma padrão. Componentes criados no construtor são **subobjetos padrão**: fazem parte do CDO (Capítulo 8), existem em toda instância, aparecem na árvore de componentes do editor de Blueprint e podem ter seus valores ajustados por Blueprints filhos e por instância.

```cpp
AVGStreetLight::AVGStreetLight()
{
    Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(Root);

    Light = CreateDefaultSubobject<USpotLightComponent>(TEXT("Light"));
    Light->SetupAttachment(Root);

    Flicker = CreateDefaultSubobject<UVGFlickerComponent>(TEXT("Flicker"));
}
```

```cpp
// No header:
UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
TObjectPtr<USpotLightComponent> Light;
```

O padrão **`VisibleAnywhere` + `BlueprintReadOnly`** para ponteiros de componentes é intencional e parece contraintuitivo: você **quer** que o designer edite a luz (cor, intensidade, ângulo). Mas `VisibleAnywhere` se refere ao **ponteiro**, não ao componente: o designer não pode trocar o componente por outro, mas pode editar todas as propriedades **do** componente no Details. `EditAnywhere` no ponteiro de um subobjeto padrão é um erro comum que causa comportamentos estranhos no editor.

O nome passado a `CreateDefaultSubobject` (`TEXT("Light")`) precisa ser único dentro do ator e **estável**: ele é a identidade do componente na serialização. Renomear depois que instâncias foram salvas em níveis pode fazer valores ajustados no editor se perderem.

### Em runtime: `NewObject` + `RegisterComponent`

Para adicionar um componente durante o jogo:

```cpp
UAudioComponent* Whisper = NewObject<UAudioComponent>(this);   // 'this' é o Outer (o ator)
Whisper->SetupAttachment(GetRootComponent());
Whisper->RegisterComponent();                                   // agora ele existe no mundo
```

Sem `RegisterComponent()`, o componente existe como objeto mas **não participa do mundo**: não é renderizado, não colide, não tica. Registrar é o passo que conecta o componente às **cenas** da engine (renderização, física) e ao sistema de tick.

> 🌉 **Ponte:** registrar um componente é como registrar um *listener* ou um *bean* num contêiner depois de instanciá-lo manualmente: criar o objeto não basta; ele precisa ser conhecido pelo sistema que o executa.

Em Blueprint, o nó *Add Component* faz o equivalente. Na prática, componentes em runtime são menos comuns do que se imagina: muitas vezes é melhor ter o componente criado no construtor, **desativado**, e ativá-lo quando necessário.

### Ativação

Componentes têm um estado de **ativação** separado do registro: `Activate()`, `Deactivate()` e a propriedade `bAutoActivate`. O significado de "ativo" depende do componente — um `UAudioComponent` ativo está tocando; um `UProjectileMovementComponent` ativo está movendo o projétil. Para componentes seus, você decide se a ativação significa algo; o `UVGFlickerComponent` deste capítulo usa o tick ligado/desligado como estado de "em funcionamento".

### Uma advertência sobre `UChildActorComponent`

Existe um componente que permite colocar **um ator inteiro dentro de outro ator** (`UChildActorComponent`). É tentador — "a lanterna é um ator; coloco ela dentro da personagem". Ele tem uma reputação, merecida, de ser fonte de problemas de serialização, replicação e ciclo de vida. Prefira: componentes no próprio ator, ou atores separados criados por spawn e anexados em runtime (como a arma no Capítulo 26).

---

## 9.4 Componentes conversando entre si

Componentes de um mesmo ator frequentemente precisam um do outro: a lanterna precisa da bateria; o flicker precisa das luzes; o som de passos precisa do movimento. Há três estratégias, em ordem crescente de desacoplamento.

### Estratégia 1 — O componente procura o vizinho

```cpp
void UVGFlashlightComponent::BeginPlay()
{
    Super::BeginPlay();
    Battery = GetOwner()->FindComponentByClass<UVGBatteryComponent>();
    if (!Battery)
    {
        UE_LOG(LogTemp, Warning, TEXT("%s: lanterna sem bateria no ator %s."), *GetName(), *GetOwner()->GetName());
    }
}
```

Simples e comum. O custo de `FindComponentByClass` é pequeno, mas **não** deve ir para o tick: procure uma vez e guarde. O acoplamento é explícito e unidirecional (a lanterna conhece a bateria; a bateria não conhece a lanterna), o que está de acordo com a regra do dono único do Capítulo 4.

### Estratégia 2 — O ator conecta os componentes

O ator conhece todos os seus componentes e faz a "fiação" em `PostInitializeComponents` ou `BeginPlay`:

```cpp
void AVGFlashlightActor::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    Battery->OnBatteryStateChanged.AddDynamic(this, &AVGFlashlightActor::HandleBatteryStateChanged);
}
```

O ator funciona como **mediador**: os componentes não se conhecem; o ator sabe como eles se combinam. É a estratégia mais legível quando a combinação é específica daquele tipo de ator.

### Estratégia 3 — Eventos e interfaces

Um componente anuncia transições (Capítulo 4) e quem se interessa se inscreve; ou um componente fala com o dono através de uma **interface** que o dono implementa, sem saber a classe concreta. É o desacoplamento máximo, e o preço é o fluxo de controle implícito. O Capítulo 24 compara as três estratégias com mais profundidade.

### Regra prática

```text
O componente B é uma DEPENDÊNCIA OBRIGATÓRIA de A, e faz sentido em qualquer ator?
    → A procura B no BeginPlay (estratégia 1), com aviso claro se não encontrar.

A combinação de A e B é ESPECÍFICA deste tipo de ator?
    → O ator conecta (estratégia 2).

B precisa reagir a A, mas A não deve saber que B existe?
    → Evento de A (estratégia 3).
```

> 🌉 **Ponte:** a estratégia 1 é *service lookup*; a 2 é o padrão **Mediator**; a 3 é **Observer**. Você conhece os três.
>
> 🧱 **Onde a ponte cai:** num contêiner de DI, dependências faltando quebram a inicialização com um erro claro. Na Unreal, um componente faltando produz um ponteiro nulo e um comportamento silenciosamente errado — a menos que **você** registre o aviso. Em jogos, onde designers montam atores no editor, mensagens de configuração claras valem ouro.

---

## 9.5 Quando criar um componente

Nem toda capacidade precisa virar componente. Use a tabela:

| Situação | Onde a lógica mora |
|---|---|
| A capacidade é **reaproveitada** em tipos diferentes de ator (vida em inimigos, portas destrutíveis e caixas) | **Componente** |
| A capacidade é **intrínseca a um único tipo** de ator e não faz sentido isolada (a lógica de abrir/fechar de uma porta) | **No próprio ator** |
| A capacidade é **global** ao mundo ou ao jogo (dilatação do tempo, estado narrativo) | **Subsistema** (Capítulo 6) |
| A capacidade é **configuração** que varia entre instâncias (dano, duração) | **Propriedade** (ou Data Asset, Capítulo 20) |
| A engine **já tem** um componente que faz isso | **Use o da engine** |

A segunda linha é a que mais contraria o instinto de arquiteto. A lógica da porta não vira `UVGOpenableComponent` só porque "componentes são bons". Ela vira um componente **quando** aparecer o segundo tipo de ator que precisa abrir e fechar da mesma forma — um portão de veículo, um alçapão. Antes disso, é generalização preventiva (Capítulo 6).

### Custo de componentes

Componentes não são gratuitos como as linhas de uma tabela ECS (Capítulo 6). Cada um é um `UObject` completo, com memória própria, registro, possivelmente tick e, se for Primitive, presença nas cenas de render e física. Algumas consequências:

- Um ator com **30 componentes** é um sinal de alerta: muitos deles provavelmente poderiam ser um só, ou nem precisariam existir.
- **Componentes primitivos invisíveis** (malhas escondidas usadas como "marcadores") custam como malhas. Use Scene Components.
- O **tick de componentes** se soma ao do ator. Desligue o que não precisa (Capítulo 2).

---

## Comparação com o desenvolvimento tradicional

| Conceito Unreal | O que você conhece | Onde a analogia cai |
|---|---|---|
| Ator + componentes | Composição; *mixins*; agregados com objetos de valor | Componentes têm ciclo de vida, tick e registro nas cenas da engine |
| `UActorComponent` vs. `USceneComponent` vs. `UPrimitiveComponent` | Níveis de capacidade de uma hierarquia | O custo de runtime cresce muito em cada nível |
| `CreateDefaultSubobject` | Composição declarada no construtor | Faz parte do CDO; o nome é identidade de serialização |
| `RegisterComponent` | Registrar um listener/bean | Conecta o componente às cenas de render, física e tick |
| Ator como mediador | Padrão Mediator | — transfere bem |
| Hierarquia de anexação | Árvore de composição de UI | É uma árvore de **transforms** propagados a cada movimento |

---

## Exemplo e implementação: `UVGFlickerComponent`

### O problema de design

Luz que falha é um dos recursos mais antigos e eficazes do horror em primeira pessoa: uma lâmpada que pisca diz "algo está errado aqui", cria sombras que se movem, esconde e revela. Na Vigília, falhas de luz serão usadas em três contextos:

1. **Ambiente** — lâmpadas defeituosas pela usina, com padrões próprios.
2. **Estado** — a lanterna pisca quando a bateria está em `Low` (Capítulo 4).
3. **Evento** — luzes que começam a falhar quando a Presença se aproxima (Capítulos 36 e 42).

Os três contextos usam o mesmo comportamento, em atores diferentes — postes, lâmpadas de teto, a lanterna. É exatamente o critério da seção 9.5 para um componente.

### Uma convenção com história

Para descrever o padrão de falha, vamos usar uma convenção com uma história curiosa. **[FATO PÚBLICO]** Em *Quake* (id Software, 1996), os padrões de iluminação animada — chamados *light styles* — eram descritos como **sequências de letras**, de `a` (apagado) a `z` (mais brilhante), com `m` representando a intensidade normal; o jogo avançava por essas sequências a uma taxa fixa, gerando pulsos, falhas e piscadas. Essa convenção foi herdada por outros jogos e engines derivados.

Ela é ótima para o nosso caso: compacta, legível, editável por um designer num campo de texto, e versionável. Um designer escreve `"mmamammmmammamamaaamammma"` e ouve, mentalmente, a lâmpada falhando.

### O código

```cpp
// Source/Vigilia/World/VGFlickerComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGFlickerComponent.generated.h"

class ULightComponent;

/**
 * Faz as luzes do ator dono oscilarem segundo um padrão de letras:
 * 'a' = apagada, 'm' = intensidade original, 'z' ≈ 2x (convenção dos light styles de Quake).
 * Afeta todos os ULightComponent do dono. Padrão vazio = desligado (sem tick).
 * As luzes precisam ter Mobility Stationary ou Movable para mudar de intensidade em runtime.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGFlickerComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGFlickerComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    /** Troca o padrão em runtime (ex.: bateria fraca, Presença por perto). Vazio desliga. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Flicker")
    void SetPattern(const FString& NewPattern);

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Flicker")
    FString Pattern = TEXT("mmamammmmammamamaaamammma");

    /** Quantas letras do padrão por segundo (tempo de jogo: respeita slomo). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Flicker", meta = (ClampMin = "0.1"))
    float StepsPerSecond = 10.0f;

    /** Taxa de suavização entre passos (1/s). 0 = degraus secos, como uma lâmpada falhando. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Flicker", meta = (ClampMin = "0.0"))
    float SmoothingRate = 0.0f;

    /** Desloca o início do padrão, para que lâmpadas vizinhas não pisquem em sincronia. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Flicker")
    bool bRandomizeStart = true;

private:
    float SampleScale() const;
    void ApplyScale(float Scale);

    UPROPERTY(Transient)
    TArray<TObjectPtr<ULightComponent>> Lights;

    TArray<float> BaseIntensities;
    float Elapsed = 0.0f;
    float CurrentScale = 1.0f;
};
```

```cpp
// Source/Vigilia/World/VGFlickerComponent.cpp
#include "World/VGFlickerComponent.h"

#include "Components/LightComponent.h"
#include "Core/VGMathUtils.h"

UVGFlickerComponent::UVGFlickerComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false; // liga no BeginPlay, se houver padrão
}

void UVGFlickerComponent::BeginPlay()
{
    Super::BeginPlay();

    TArray<ULightComponent*> Found;
    GetOwner()->GetComponents(Found);
    for (ULightComponent* Light : Found)
    {
        Lights.Add(Light);
        BaseIntensities.Add(Light->Intensity);
    }

    if (Lights.IsEmpty())
    {
        UE_LOG(LogTemp, Warning, TEXT("%s: nenhum ULightComponent em %s; flicker sem efeito."),
            *GetName(), *GetOwner()->GetName());
        return;
    }

    if (bRandomizeStart)
    {
        Elapsed = FMath::FRandRange(0.0f, 10.0f); // Simplificação: sem semente; cosmético, não precisa ser reproduzível
    }

    SetPattern(Pattern);
}

void UVGFlickerComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    ApplyScale(1.0f); // devolve as luzes ao estado original
    Super::EndPlay(EndPlayReason);
}

void UVGFlickerComponent::SetPattern(const FString& NewPattern)
{
    Pattern = NewPattern;
    const bool bActive = !Pattern.IsEmpty() && !Lights.IsEmpty();
    SetComponentTickEnabled(bActive);

    if (!bActive)
    {
        CurrentScale = 1.0f;
        ApplyScale(CurrentScale);
    }
}

void UVGFlickerComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                        FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    Elapsed += DeltaTime;
    const float Target = SampleScale();
    CurrentScale = (SmoothingRate > 0.0f)
        ? VGMath::ExpDecayTo(CurrentScale, Target, SmoothingRate, DeltaTime)
        : Target;

    ApplyScale(CurrentScale);
}

float UVGFlickerComponent::SampleScale() const
{
    const int32 Index = FMath::FloorToInt(Elapsed * StepsPerSecond) % Pattern.Len();
    const TCHAR Letter = FChar::ToLower(Pattern[Index]);
    const int32 Level = FMath::Clamp(static_cast<int32>(Letter - TEXT('a')), 0, 25);
    return Level / 12.0f; // 'm' (12) = 1.0
}

void UVGFlickerComponent::ApplyScale(float Scale)
{
    for (int32 i = 0; i < Lights.Num(); ++i)
    {
        if (IsValid(Lights[i]))
        {
            Lights[i]->SetIntensity(BaseIntensities[i] * Scale);
        }
    }
}
```

### Explicação das decisões

- **`UActorComponent`, não `USceneComponent`.** O flicker não tem posição; ele age sobre luzes que têm.
- **Afeta todas as luzes do dono.** Uma luminária pode ter uma luz principal e uma luz de preenchimento; ambas devem falhar juntas. Se surgir a necessidade de escolher luzes específicas, adiciona-se uma lista de referências — não antes.
- **Tick só quando há padrão.** `bStartWithTickEnabled = false` e `SetPattern` liga ou desliga o tick. Cem lâmpadas estáveis na usina custam zero por frame.
- **Tempo de jogo.** `Elapsed` acumula `DeltaTime`, então `slomo` desacelera as falhas — coerente com o resto do mundo (Capítulo 3). Se uma luz de UI precisasse falhar durante a pausa, a escolha de relógio seria outra.
- **Suavização com `VGMath::ExpDecayTo`.** O utilitário do Capítulo 3 sendo usado pela primeira vez em código de produção: com `SmoothingRate > 0`, o flicker vira uma pulsação suave, independente do frame rate.
- **`bRandomizeStart`.** Dez lâmpadas com o mesmo padrão piscando em sincronia parecem um letreiro de natal, não uma usina abandonada. Um detalhe de design implementado em uma linha.
- **`EndPlay` restaura as intensidades.** O componente altera estado de **outros** componentes; ao sair, devolve o que alterou. É a disciplina de limpeza do Capítulo 8 aplicada a efeitos colaterais.
- **`Lights` como `UPROPERTY(Transient)`.** O array guarda ponteiros para `UObject`s, então precisa ser visível ao garbage collector (Capítulo 11 explica o porquê). `Transient` indica que ele não deve ser salvo — é preenchido em runtime.
- **Aviso quando não há luzes.** Configuração errada de conteúdo deve ser visível.

### Uso no Pátio

1. Crie o Blueprint `BP_PosteLuz` com a árvore da seção 9.2 (use cilindros e cubos da engine; a luz com Mobility *Movable* ou *Stationary*).
2. Adicione o `UVGFlickerComponent` pelo botão *Add* do painel de componentes — ele aparece na categoria *Vigilia* graças a `ClassGroup = (Vigilia)` e `BlueprintSpawnableComponent`.
3. Coloque quatro postes no Pátio. Em três, apague o `Pattern` (ficam estáveis). No poste perto da Casa de Força, use um padrão agressivo: `"mmmmmaaammmmmaaaaaamm"`.
4. Teste com `slomo 0.2` e com `t.MaxFPS 20`: o padrão desacelera com o tempo de jogo e **não** muda com o frame rate.

---

## Decisões arquiteturais

1. **Nível mínimo de componente:** Actor < Scene < Primitive. Nunca uma malha invisível como marcador.
2. **Componentes da engine primeiro.** `URotatingMovementComponent`, `UInterpToMovementComponent` e similares antes de escrever um novo.
3. **Raiz neutra (`USceneComponent`)** nos atores do projeto, para não propagar escalas.
4. **Ponteiros de subobjetos padrão: `VisibleAnywhere, BlueprintReadOnly`.**
5. **Comunicação entre componentes:** dependência obrigatória → busca no `BeginPlay` com aviso; combinação específica → o ator conecta; reação desacoplada → evento.
6. **Componente quando há reuso real entre tipos de ator.** Lógica intrínseca de um único tipo fica no ator.
7. **Componentes que alteram outros componentes restauram o estado em `EndPlay`.**
8. **Evitar `UChildActorComponent`**; preferir componentes ou atores anexados em runtime.

---

## Armadilhas

- **`EditAnywhere` em ponteiros de componentes** criados no construtor.
- **Renomear subobjetos padrão** depois de usados em níveis.
- **Esquecer `RegisterComponent`** em componentes criados em runtime.
- **`FindComponentByClass` no tick.**
- **Raiz com escala**, deformando todos os filhos.
- **Luzes *Static*** que precisam mudar de intensidade.
- **Componentificar tudo** — a porta que vira três componentes genéricos antes de existir a segunda porta diferente.
- **Atores com dezenas de componentes**, muitos deles primitivos invisíveis.
- **Componentes que alteram vizinhos sem restaurar.**

---

## Exercício

**Parte 1 — anatomia (45 min).** Abra um ator de exemplo da engine ou do projeto `RefFirstPerson` (o personagem) e desenhe a árvore de componentes, classificando cada um como Actor, Scene ou Primitive. Para cada Primitive, diga se ele é renderizado, colide ou ambos.

**Parte 2 — o poste (1,5 h).** Implemente o `UVGFlickerComponent`, crie o `BP_PosteLuz` e distribua os postes pelo Pátio. Teste os padrões abaixo e descreva a sensação de cada um no `DEVLOG.md`:
- `"mmnmmommommnonmmonqnmmo"` (pulsação leve);
- `"mmamammmmammamamaaamammma"` (falha);
- `"aaaaaaaazzzzzz"` com `StepsPerSecond = 2` (liga e desliga);
- qualquer padrão com `SmoothingRate = 8`.

**Parte 3 — componentes prontos (30 min).** Adicione ao topo da caixa d'água uma luz de sinalização que **gira** (uma `SpotLight` anexada a um `USceneComponent` com `URotatingMovementComponent`) sem escrever nenhuma linha de C++. Quanto tempo levou, comparado ao flicker?

**Parte 4 — runtime (30 min).** No `AVGSpawner` do Capítulo 8, faça os atores criados ganharem, em runtime, um `UVGFlickerComponent` com um padrão aleatório (crie com `NewObject`, configure e registre). O que acontece se você esquecer `RegisterComponent`?

---

## Desafio — a lanterna que falha

Junte os Capítulos 4 e 9: crie um ator `BP_LanternaTeste` com uma `SpotLight`, um `UVGBatteryComponent` e um `UVGFlickerComponent` (padrão vazio). Faça a bateria drenar com o tempo (um tick em Blueprint chamando `Drain`). Quando a bateria entrar em `Low`, o flicker deve receber um padrão de falha; quando entrar em `Depleted`, a luz deve apagar; ao recarregar (uma tecla de teste), tudo volta ao normal.

Implemente a "fiação" de duas formas — (a) o ator conecta os componentes (estratégia 2), em Blueprint; (b) um componente procura o outro (estratégia 1), em C++ — e compare: qual fica mais fácil de entender para quem abre o Blueprint pela primeira vez? Qual seria mais fácil de reaproveitar numa lâmpada de emergência que funciona a bateria?

---

## Uso de IA

1. **Para escolher componentes da engine:**
   > "Na Unreal Engine 5, quero [comportamento: ex. uma plataforma que vai e volta entre dois pontos com pausa nas pontas]. Existe algum componente ou recurso da engine que faz isso sem código? Liste as opções (componentes, Timeline em Blueprint, Sequencer), com prós e contras de cada uma, e diga quando valeria escrever um componente próprio."

2. **Para revisar um componente:**
   > "Revise este UActorComponent da Unreal: nível correto de componente (Actor/Scene/Primitive), configuração de tick, uso de UPROPERTY em ponteiros para UObject, limpeza em EndPlay, dependências de outros componentes e mensagens para configuração errada no editor. [código]"

3. **Para pensar em design de horror:**
   > "Estou criando um componente de falha de luz para um jogo de terror em primeira pessoa. Sugira 8 padrões de falha diferentes (em sequências de letras 'a'–'z', como os light styles de Quake), cada um associado a uma intenção emocional ou narrativa, e explique como o ritmo e o contraste de cada padrão afetam a percepção do jogador."

---

## Checklist

- [ ] Sei escolher entre Actor, Scene e Primitive Component e conheço o custo de cada um.
- [ ] Conheço os componentes prontos mais úteis da engine e verifico se um deles resolve antes de escrever o meu.
- [ ] Sei montar hierarquias de anexação, usar raiz neutra, sockets e regras de anexação.
- [ ] Sei por que ponteiros de subobjetos padrão são `VisibleAnywhere`.
- [ ] Sei criar componentes no construtor e em runtime, e o que é registrar.
- [ ] Conheço as três estratégias de comunicação entre componentes e quando usar cada uma.
- [ ] Sei decidir entre componente, lógica no ator, subsistema e propriedade.
- [ ] Implementei o `UVGFlickerComponent` e os postes do Pátio.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre **Components**, **Actor Components** e **Scene Components**, e a referência dos componentes de movimento.
- **Robert Nystrom, *Game Programming Patterns*, capítulo "Component"** — releia agora, com a Unreal em mente.

---

➡️ **Próximo:** [Capítulo 10 — Gameplay Framework](cap-10-gameplay-framework.md)

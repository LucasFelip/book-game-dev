# Capítulo 36 — Perception

## Objetivo

Ao final deste capítulo você deve conseguir:

- usar o **AI Perception** da Unreal: sentidos de visão, audição e dano, fontes de estímulo, afiliação e memória de estímulos;
- emitir **ruídos** a partir de passos, portas, disparos e impactos, com intensidade e alcance;
- transformar estímulos brutos em **consciência** (*awareness*): um valor que cresce com o tempo de exposição, decai com o tempo e cruza **limiares com histerese** (desatento → desconfiado → ciente);
- fazer a **luz** afetar a percepção — a lanterna acesa torna a jogadora visível de longe; a escuridão e o agachar a escondem;
- implementar o **nível de ameaça** global prometido no Capítulo 4 e consumido pela música, pelas luzes e pelo Diretor;
- desenhar percepção **justa**: legível, gradual e comunicada ao jogador.

---

## Contexto

O cérebro do vigia "vê" por um trace direto até a jogadora, a cada frame, e não ouve nada. Isso tem três defeitos graves. É **binário**: ou vê perfeitamente, ou não vê — não existe "acho que vi algo". É **onisciente** quanto à identidade: ele sempre sabe que é a jogadora. E é **surdo**: os passos metálicos, as portas rangendo e os tiros, que o livro cuidou de produzir desde o Capítulo 17, não significam nada para ele.

Percepção é onde a IA de um jogo de terror vive ou morre. A Presença precisa perceber o suficiente para ser ameaçadora e pouco o suficiente para ser enganada — e a jogadora precisa **entender** como ela percebe, para poder jogar com isso (Capítulo 1, seção 1.3: um sistema só vira design quando o jogador o entende). A pergunta central deste capítulo não é "como detectar a jogadora", mas **"como detectá-la de um jeito que a jogadora consiga prever e explorar"**.

---

## 36.1 Do estímulo à consciência

A percepção de um agente tem três camadas, e confundi-las é a origem do cérebro ingênuo:

```text
 ESTÍMULO              PERCEPÇÃO                       CONSCIÊNCIA (awareness)
 ────────              ─────────                       ───────────────────────
 "algo está no meu     o sentido registra: ator X,     o agente CONCLUI:
  cone de visão"        local, força, idade            "estou desconfiado de X"
 "houve um ruído de                                    "estou ciente de X, ali"
  passos ali"                                          "perdi X; ele estava ali há 6 s"
        │                        │                                  │
   evento físico           sistema de sentidos                 memória + regras
   (geometria, som)        (AI Perception da Unreal)           (componente do agente)
                                                                    │
                                                                    ▼
                                                           DECISÃO (FSM/BT, Caps. 34, 37)
```

- **Estímulo** é algo que acontece no mundo: um ator visível, um ruído, um dano.
- **Percepção** é o sentido registrando o estímulo, com seus limites (alcance, ângulo, linha de visão, afiliação).
- **Consciência** é o que o agente **conclui** a partir de percepções acumuladas no tempo — e é isso que a decisão deve usar.

A AI Perception da Unreal cuida muito bem das duas primeiras camadas. A terceira — consciência gradual, memória, limiares — é responsabilidade do projeto, e é onde está o design.

---

## 36.2 A AI Perception da Unreal

### O componente e os sentidos

O `UAIPerceptionComponent` fica no **controller** de IA (o cérebro percebe; o corpo é o que é percebido — Capítulo 10). Ele é configurado com **sentidos**:

| Sentido | Configuração principal | Como os estímulos chegam |
|---|---|---|
| **Visão** (`UAISenseConfig_Sight`) | Raio de visão; **raio para perder a visão** (maior que o de ver — histerese!); meio-ângulo da visão periférica; afiliação detectada; idade máxima | Automaticamente, para atores registrados como fonte, com testes de cone e linha de visão |
| **Audição** (`UAISenseConfig_Hearing`) | Alcance de audição; afiliação; idade máxima | Por **eventos de ruído** explícitos (`ReportNoiseEvent`) |
| **Dano** (`UAISenseConfig_Damage`) | Idade máxima | Por eventos de dano reportados |

Detalhes que importam para o design:

- **`LoseSightRadius` > `SightRadius`** é histerese embutida (Capítulo 4): o agente vê a 15 m, mas só "perde" a jogadora quando ela passa de 18 m. Sem isso, a percepção oscila na borda do raio.
- **Idade máxima (*max age*)** faz o estímulo "envelhecer": depois de perder a visão, o agente ainda lembra **onde** viu, por um tempo. É a memória de curto prazo.
- **Afiliação** usa as equipes do Capítulo 33 (`FGenericTeamId`): um vigia não "detecta" outro vigia como ameaça.

### Fontes de estímulo

Para a visão, o ator precisa ser uma **fonte** registrada: o `UAIPerceptionStimuliSourceComponent` registra o ator para os sentidos escolhidos. (Há uma configuração de projeto que registra automaticamente todos os pawns como fonte de visão; deixá-la desligada e registrar explicitamente dá mais controle sobre o que cada agente pode ver.)

Para a audição, não há registro: **ruídos são eventos**, emitidos por quem faz o ruído:

```cpp
UAISense_Hearing::ReportNoiseEvent(GetWorld(), Location, Loudness, Instigator, MaxRange, Tag);
```

- `Loudness` é a intensidade (a percepção usa esse valor junto com o alcance de audição do agente);
- `MaxRange` limita o alcance daquele ruído específico;
- `Tag` identifica o **tipo** de ruído (`Footstep`, `Door`, `Gunshot`, `Impact`) — o agente pode reagir diferente a cada um.

### O evento de percepção

Quando um estímulo muda (começou a ver, deixou de ver, ouviu), o componente dispara `OnTargetPerceptionUpdated(AActor* Actor, FAIStimulus Stimulus)`. O `FAIStimulus` traz:

- `WasSuccessfullySensed()` — verdadeiro ao **começar** a perceber, falso ao **perder** (no caso da visão);
- `StimulusLocation` — **onde** (para ruídos, o local do ruído; para visão, onde o ator foi visto);
- `Strength` — a intensidade;
- `Type` — qual sentido;
- `Tag` — o tipo de ruído;
- a idade do estímulo.

A seção de implementação transforma esse fluxo de eventos em **consciência**.

---

## 36.3 Consciência gradual

Um agente com consciência gradual não passa de "não vi" para "vi" num frame. Ele acumula **suspeita** enquanto a jogadora está parcialmente exposta, e a suspeita decai quando ela some:

```text
consciência
  1.0 ┤                                   ████████ CIENTE  (caça / combate)
      │                              ▄████▀
  0.6 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ▄██▀─ ─ ─ ─ ─ ─ ─ ─  limiar CIENTE (entrada)
      │                         ▄██▀                   ▀▄
  0.5 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ▄█▀ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▀▄─ limiar CIENTE (saída)
      │                     ▄▀▀                          ▀▄
  0.3 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─▄▀─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▀▄─  limiar DESCONFIADO
      │              ▄▄▄▀▀                                     ▀▀▄▄
  0.0 ┼▄▄▄▄▄▄▄▄▄▄▄▀▀▀                                              ▀▀▀▄▄▄▄▄
      └──────────────────────────────────────────────────────────────────► tempo
       a jogadora entra no cone   fica exposta              some de vista
```

A taxa de crescimento depende de **quão exposta** a jogadora está:

```text
ganho por segundo = taxa_base
                  × fator_distância      (perto → rápido; longe → devagar)
                  × fator_exposição      (lanterna acesa → alto; escuro e agachada → baixo)
                  × fator_periferia      (centro do cone → alto; borda → baixo)
```

E ruídos acrescentam **saltos**: um tiro próximo leva a consciência direto ao "ciente" daquele **local** (não necessariamente da jogadora — o agente sabe que **houve** um tiro ali); passos aumentam a suspeita proporcionalmente à intensidade.

Os **estados** derivados da consciência, com histerese (Capítulo 4, seção 4.3):

| Estado | Entrada | Saída | Comportamento típico | Comunicação ao jogador |
|---|---|---|---|---|
| **Desatento** | — | consciência ≥ 0,3 | Patrulha, espreita | Nenhuma |
| **Desconfiado** | ≥ 0,3 | < 0,15 | Para, vira para o estímulo, investiga | Som característico, a cabeça vira, música tensa |
| **Ciente** | ≥ 0,6 | < 0,5 | Combate (vigia) / caça (Presença) | Grito/rugido, telegrafia, música de perseguição |

> 🌉 **Ponte:** é **alerting com limiares e histerese** sobre uma métrica suavizada — o mesmo raciocínio de um alerta de latência que dispara acima de 500 ms sustentados por 2 minutos e só se resolve abaixo de 300 ms. A "métrica" aqui é a exposição da jogadora; o "alerta" é o inimigo vindo atrás dela.
>
> 🧱 **Onde a ponte cai:** um alerta de produção deve ser rápido e preciso. A consciência de um inimigo deve ser **lenta o bastante para dar ao jogador tempo de reagir** e **imprecisa o bastante para ser enganável**. Precisão aqui é um defeito.

---

## 36.4 Luz e percepção

Na Vigília, a luz é o eixo da percepção — o mesmo pilar que governa a navegação (Capítulo 35):

- **Lanterna acesa** → a jogadora é muito visível: o fator de exposição é alto, e a Presença a vê de longe. **Usar a lanterna é se expor.** É a tensão central do micro-loop (Capítulo 5): preciso ver, mas ver me denuncia.
- **No escuro, lanterna apagada** → a jogadora só é vista **de perto**.
- **Agachada no escuro** → ainda menos.
- **Dentro de uma zona segura** → a Presença a vê perfeitamente, mas não pode entrar (navegação). Ver a jogadora na luz deixa a Presença **frustrada e à espera** — um momento de tensão poderoso para o pacing.

A exposição é calculada a partir do **estado da jogadora** — e o projeto já tem a ferramenta certa: as **tags de status** (Capítulo 23). A lanterna concede `Status.Light.Flashlight` quando acesa; a corrida e o agachar já concedem `Status.Movement.*`; as zonas, `Status.Zone.Safe`. A percepção consulta as tags do ator percebido pela `IGameplayTagAssetInterface`, sem conhecer a classe da jogadora.

> **Alternativa da engine:** a Unreal permite que um ator customize **como ele é visto** implementando a interface `IAISightTargetInterface` (a função `CanBeSeenFrom`), substituindo o teste de linha de visão padrão. É poderosa e de baixo nível; sua assinatura mudou entre versões do UE5. O projeto usa o modelo de consciência gradual desta seção, que é independente de versão e mais fácil de ajustar por design.

---

## 36.5 Ruído: quem emite e quanto

Cada fonte de ruído do projeto, com a intensidade base e o tipo:

| Fonte | Tag | Intensidade | Alcance | Origem no projeto |
|---|---|---|---|---|
| Passo agachado | `Footstep` | 0,2 × superfície | 6 m | `UVGFootstepComponent` (Cap. 17) |
| Passo andando | `Footstep` | 0,5 × superfície | 12 m | idem |
| Passo correndo | `Footstep` | 1,0 × superfície | 20 m | idem |
| Aterrissagem | `Footstep` | até 1,5 | 25 m | idem |
| Porta abrindo/fechando | `Door` | 0,6 (0,2 no modo cuidadoso — desafio do Cap. 19) | 15 m | `AVGDoor` (Cap. 19) |
| Disparo | `Gunshot` | 2,0 | 50 m | `AVGWeapon::OnFired` (Cap. 20) |
| Impacto físico forte | `Impact` | proporcional | 15 m | Caixas físicas (desafio do Cap. 15) |

A **superfície** multiplica a intensidade dos passos: o `UVGPhysicalMaterial` (Capítulo 27) ganha um `NoiseMultiplier` — grade metálica 1,6; concreto 1,0; carpete 0,5. As passarelas da Casa de Força são **barulhentas**. É level design (Capítulo 50) feito com materiais.

### Quem chama `ReportNoiseEvent`?

O `UVGFootstepComponent` só **anuncia** passos (Capítulo 17). Quem converte "passo" em "ruído" é a **composição**: o personagem se inscreve em `OnFootstep` e reporta o ruído. Assim, o componente de passos continua sem saber que existe IA, e outros personagens (os vigias) podem ter passos **sem** emitir ruído para a percepção (ou emitir para outra equipe). Para padronizar, o projeto tem uma pequena função de biblioteca, `UVGNoiseLibrary::ReportNoise`, usada por todas as fontes.

---

## 36.6 O nível de ameaça

Desde o Capítulo 4, o livro promete um **nível de ameaça global da Presença** — calma, inquietação, caça — consumido pela música, pelas luzes e pelos eventos roteirizados. Agora ele existe: é a **consciência da Presença sobre a jogadora**, projetada num estado discreto com histerese, num subsistema de mundo:

```text
 consciência da Presença sobre a jogadora (contínua)
        │  limiares com histerese
        ▼
 UVGThreatSubsystem: Calm / Uneasy / Hunting   ──► OnThreatLevelChanged
        │                                            ├─► música (Cap. 52)
        │                                            ├─► luzes próximas falham (flicker)
        │                                            ├─► respiração/batimentos da jogadora
        └─► consulta: GetThreatLevel()               └─► Diretor (Cap. 42)
```

O subsistema é o **dono** do nível de ameaça (Capítulo 4, dono único); a Presença **informa** a sua consciência; os consumidores **reagem** a transições. Nenhum deles conhece a Presença.

---

## Estudo de caso: percepção justa no terror

> **Pergunta:** como um inimigo de terror pode perceber o jogador de forma ameaçadora e, ainda assim, justa?

**[FATO PÚBLICO]** Em *Amnesia: The Dark Descent* (Frictional Games, 2010), o jogador é incentivado a se manter no escuro para não ser visto pelos monstros — mas a escuridão prolongada afeta a sanidade do personagem, com efeitos visuais e sonoros. Em *Outlast* (Red Barrels, 2013), esconder-se e quebrar a linha de visão são as principais defesas, e a visão noturna da câmera permite ver no escuro sem acender luzes visíveis. Nos dois jogos, a música e o som mudam de forma perceptível quando o jogador é detectado ou perseguido.

**[INFERÊNCIA]** Três princípios de percepção justa aparecem de forma consistente no gênero:

1. **As regras são aprendíveis** — luz e som denunciam; escuridão e silêncio protegem. O jogador forma um modelo mental correto.
2. **A detecção é gradual e comunicada** — há sinais de "algo me notou" antes de "estou sendo caçado" (sons, música, comportamento do inimigo), dando tempo de reagir.
3. **A escuridão tem um custo** — esconder-se não pode ser gratuito, senão vira a estratégia dominante. Amnesia cobra com a sanidade; a Vigília cobra com a **orientação** (sem lanterna, a jogadora mal enxerga) e com o **tempo** (a bateria acaba de qualquer forma).

Nenhuma afirmação é feita sobre os sistemas internos desses jogos.

**[SIMPLIFICAÇÃO DIDÁTICA]** A Vigília implementa os três princípios com: fatores de exposição por luz e postura (aprendíveis), consciência gradual com estados comunicados por som e música (o nível de ameaça), e o dilema da lanterna (ver vs. ser vista).

**Lição:** **percepção justa é percepção previsível.** O jogador não precisa ver o cone de visão do inimigo; ele precisa conseguir **prever**, a partir de regras que aprendeu, se será visto — e receber sinais claros quando errou a previsão.

---

## Comparação com o desenvolvimento tradicional

| Percepção | O que você conhece | Onde a analogia cai |
|---|---|---|
| Estímulo → percepção → consciência | Eventos brutos → métricas → alertas | A "conclusão" deve ser lenta e enganável de propósito |
| Consciência com histerese | Alertas com limiares de disparo e resolução | O jogador **joga com** os limiares |
| Idade máxima dos estímulos | TTL de cache / janela de retenção | A memória curta é uma mecânica de fuga |
| Ruído como evento | Publicação de eventos com intensidade | O "assinante" é filtrado por geometria e alcance |
| Nível de ameaça global | Estado agregado de saúde do sistema | Consumido para **apresentação** (música, luz) |

---

## Implementação

### 1. Tags e materiais

Novas tags nativas: `TAG_Status_Light_Flashlight` (`Status.Light.Flashlight`). A lanterna mínima do Interlúdio I passa a conceder/revogar essa tag ao acender/apagar. O `UVGPhysicalMaterial` ganha `UPROPERTY(EditAnywhere) float NoiseMultiplier = 1.0f;`.

### 2. A biblioteca de ruído

```cpp
// Source/Vigilia/AI/VGNoiseLibrary.h
#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "VGNoiseLibrary.generated.h"

UCLASS()
class VIGILIA_API UVGNoiseLibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /** Emite um ruído para a percepção de IA (e para a depuração, com vg.Debug.Noise). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|AI", meta = (WorldContext = "WorldContextObject"))
    static void ReportNoise(const UObject* WorldContextObject, FVector Location, float Loudness,
                            AActor* Instigator, float MaxRange, FName Tag);
};
```

```cpp
// Source/Vigilia/AI/VGNoiseLibrary.cpp
#include "AI/VGNoiseLibrary.h"

#include "DrawDebugHelpers.h"
#include "Engine/Engine.h"
#include "HAL/IConsoleManager.h"
#include "Perception/AISense_Hearing.h"

static TAutoConsoleVariable<bool> CVarVGDebugNoise(
    TEXT("vg.Debug.Noise"), false, TEXT("Desenha os ruídos emitidos para a IA."), ECVF_Default);

void UVGNoiseLibrary::ReportNoise(const UObject* WorldContextObject, FVector Location, float Loudness,
                                  AActor* Instigator, float MaxRange, FName Tag)
{
    UWorld* World = GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull);
    if (!World || Loudness <= 0.0f)
    {
        return;
    }
    UAISense_Hearing::ReportNoiseEvent(World, Location, Loudness, Instigator, MaxRange, Tag);

#if ENABLE_DRAW_DEBUG
    if (CVarVGDebugNoise.GetValueOnGameThread())
    {
        DrawDebugSphere(World, Location, MaxRange, 16, FColor::Cyan, false, 0.5f);
        DrawDebugString(World, Location + FVector(0, 0, 40), Tag.ToString(), nullptr, FColor::Cyan, 0.5f);
    }
#endif
}
```

### 3. As fontes

No `AVGCharacter`, a composição passos → ruído:

```cpp
// BeginPlay: Footsteps->OnFootstep.AddDynamic(this, &AVGCharacter::HandleFootstep);

void AVGCharacter::HandleFootstep(FVector Location, TEnumAsByte<EPhysicalSurface> Surface, float Loudness)
{
    const float SurfaceMultiplier = SurfaceNoiseMultiplier(Surface); // lido do UVGPhysicalMaterial do chão
    const float FinalLoudness = Loudness * SurfaceMultiplier;
    UVGNoiseLibrary::ReportNoise(this, Location, FinalLoudness, this,
                                 /*MaxRange=*/FMath::Lerp(600.0f, 2500.0f, FMath::Clamp(FinalLoudness, 0.0f, 1.0f)),
                                 TEXT("Footstep"));
}
```

(Simplificação: para obter o multiplicador, o componente de passos pode passar também o material físico no evento, em vez do tipo de superfície — faça essa pequena mudança no `FVGFootstepSignature`.) Portas (`AVGDoor::TransitionTo` ao começar a abrir/fechar) e armas (`AVGWeapon::FireOnce`) chamam `ReportNoise` com os valores da tabela da seção 36.5.

### 4. Fontes de visão e percepção no controller

A jogadora ganha um `UAIPerceptionStimuliSourceComponent` registrado para visão (no Blueprint, *Register as Source for Senses = AISense_Sight*, *Auto Register as Source = true*).

No `AVGAIController`:

```cpp
// VGAIController.h (adições)
class UAIPerceptionComponent;
class UAISenseConfig_Sight;
class UAISenseConfig_Hearing;
class UVGAwarenessComponent;

protected:
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UAIPerceptionComponent> Perception;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGAwarenessComponent> Awareness;

    UPROPERTY()
    TObjectPtr<UAISenseConfig_Sight> SightConfig;

    UPROPERTY()
    TObjectPtr<UAISenseConfig_Hearing> HearingConfig;

private:
    UFUNCTION()
    void HandleTargetPerceptionUpdated(AActor* Actor, FAIStimulus Stimulus);
```

```cpp
// VGAIController.cpp (trechos)
#include "AI/VGAwarenessComponent.h"
#include "Perception/AIPerceptionComponent.h"
#include "Perception/AISenseConfig_Hearing.h"
#include "Perception/AISenseConfig_Sight.h"

AVGAIController::AVGAIController()
{
    bWantsPlayerState = false;

    Perception = CreateDefaultSubobject<UAIPerceptionComponent>(TEXT("Perception"));
    Awareness = CreateDefaultSubobject<UVGAwarenessComponent>(TEXT("Awareness"));

    SightConfig = CreateDefaultSubobject<UAISenseConfig_Sight>(TEXT("SightConfig"));
    SightConfig->SightRadius = 2500.0f;
    SightConfig->LoseSightRadius = 3000.0f;               // histerese de visão
    SightConfig->PeripheralVisionAngleDegrees = 60.0f;    // meio-ângulo
    SightConfig->DetectionByAffiliation.bDetectEnemies = true;
    SightConfig->DetectionByAffiliation.bDetectNeutrals = false;
    SightConfig->DetectionByAffiliation.bDetectFriendlies = false;
    SightConfig->SetMaxAge(6.0f);                          // memória da última posição vista

    HearingConfig = CreateDefaultSubobject<UAISenseConfig_Hearing>(TEXT("HearingConfig"));
    HearingConfig->HearingRange = 2500.0f;
    HearingConfig->DetectionByAffiliation.bDetectEnemies = true;
    HearingConfig->DetectionByAffiliation.bDetectNeutrals = true; // ruídos de objetos sem dono
    HearingConfig->DetectionByAffiliation.bDetectFriendlies = false;
    HearingConfig->SetMaxAge(8.0f);

    Perception->ConfigureSense(*SightConfig);
    Perception->ConfigureSense(*HearingConfig);
    Perception->SetDominantSense(SightConfig->GetSenseImplementation());
}

void AVGAIController::BeginPlay()
{
    Super::BeginPlay();
    Perception->OnTargetPerceptionUpdated.AddDynamic(this, &AVGAIController::HandleTargetPerceptionUpdated);
}

void AVGAIController::HandleTargetPerceptionUpdated(AActor* Actor, FAIStimulus Stimulus)
{
    Awareness->ReceiveStimulus(Actor, Stimulus); // o controller encaminha; a consciência decide
}
```

Os valores dos sentidos são **padrões** do C++; cada Blueprint de controller (vigia, Presença) os ajusta. A Presença: visão com raio **maior** (3.000, perda a 3.500), audição com raio maior (3.500), memória mais longa — e, no componente de consciência dela, `FullDistance` = 3.000 e `DarkExposure` bem mais baixo (0,1).

> ⚠️ **O raio de visão é um teto, não uma preferência.** A AI Perception só entrega estímulos de visão dentro de `SightRadius`; o fator de exposição (seção 5) só **atenua** o que passou por esse filtro. Um raio curto na Presença anularia a regra "lanterna acesa = vista de longe": além dele, a lanterna não importa. Por isso o raio é o alcance do **melhor caso** (lanterna acesa), e quem encurta a visão no escuro é a exposição — com `DarkExposure` baixo e o fator de distância, a jogadora de lanterna apagada praticamente só acumula suspeita de perto.

### 5. A consciência

```cpp
// Source/Vigilia/AI/VGAwarenessComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Perception/AIPerceptionTypes.h"
#include "VGAwarenessComponent.generated.h"

UENUM(BlueprintType)
enum class EVGAwarenessState : uint8
{
    Unaware,
    Suspicious,
    Aware
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FVGAwarenessChangedSignature,
    AActor*, Target, EVGAwarenessState, OldState, EVGAwarenessState, NewState);

/**
 * Converte estímulos da AI Perception em CONSCIÊNCIA gradual sobre o alvo principal:
 * cresce com a exposição (distância, luz, postura, periferia), decai sem estímulo,
 * cruza limiares com histerese. Guarda a última localização conhecida/suspeita.
 * Simplificação: um único alvo de interesse (a jogadora).
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGAwarenessComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGAwarenessComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    void ReceiveStimulus(AActor* Actor, const FAIStimulus& Stimulus);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Awareness")
    float GetAwareness() const { return Awareness; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Awareness")
    EVGAwarenessState GetAwarenessState() const { return State; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Awareness")
    AActor* GetTarget() const { return Target.Get(); }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Awareness")
    bool IsTargetVisible() const { return bTargetVisible; }

    /** Onde o agente acha que o alvo está (última vista, ou origem do último ruído relevante). */
    UFUNCTION(BlueprintPure, Category = "Vigilia|Awareness")
    FVector GetLastKnownLocation() const { return LastKnownLocation; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Awareness")
    FVGAwarenessChangedSignature OnAwarenessChanged;

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness", meta = (ClampMin = "0.0"))
    float BaseGainPerSecond = 0.8f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness", meta = (ClampMin = "0.0"))
    float DecayPerSecond = 0.08f;

    /** Distância (cm) em que a exposição por distância cai a zero. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness", meta = (ClampMin = "1.0"))
    float FullDistance = 2500.0f;

    /** Exposição no escuro, sem lanterna (multiplica o ganho); a lanterna leva a 1.0. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float DarkExposure = 0.25f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float CrouchExposureMultiplier = 0.5f;

    /** Ruído de intensidade 1 soma isto (passos), proporcional à intensidade. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness", meta = (ClampMin = "0.0"))
    float NoiseGainPerLoudness = 0.25f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness|Thresholds")
    float SuspiciousEnter = 0.3f;
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness|Thresholds")
    float SuspiciousExit = 0.15f;
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness|Thresholds")
    float AwareEnter = 0.6f;
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Awareness|Thresholds")
    float AwareExit = 0.5f;

private:
    float ComputeExposure() const;
    void UpdateState();

    TWeakObjectPtr<AActor> Target;
    bool bTargetVisible = false;
    float Awareness = 0.0f;
    FVector LastKnownLocation = FVector::ZeroVector;
    EVGAwarenessState State = EVGAwarenessState::Unaware;
};
```

```cpp
// Source/Vigilia/AI/VGAwarenessComponent.cpp
#include "AI/VGAwarenessComponent.h"

#include "AIController.h"
#include "Core/VGGameplayTags.h"
#include "GameplayTagAssetInterface.h"
#include "Perception/AISense_Hearing.h"
#include "Perception/AISense_Sight.h"

UVGAwarenessComponent::UVGAwarenessComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.TickInterval = 0.1f; // 10 Hz: consciência não precisa de precisão de frame
}

void UVGAwarenessComponent::ReceiveStimulus(AActor* Actor, const FAIStimulus& Stimulus)
{
    const FAISenseID SightID = UAISense::GetSenseID<UAISense_Sight>();
    const FAISenseID HearingID = UAISense::GetSenseID<UAISense_Hearing>();

    if (Stimulus.Type == SightID)
    {
        // Simplificação: o primeiro ator hostil visto vira o alvo de interesse.
        if (!Target.IsValid() || Target.Get() == Actor)
        {
            Target = Actor;
            bTargetVisible = Stimulus.WasSuccessfullySensed();
            LastKnownLocation = Stimulus.StimulusLocation;
        }
    }
    else if (Stimulus.Type == HearingID && Stimulus.WasSuccessfullySensed())
    {
        // Ruído: salto de suspeita proporcional à intensidade, e um LOCAL para investigar.
        Awareness = FMath::Min(Awareness + Stimulus.Strength * NoiseGainPerLoudness, 1.0f);
        if (!bTargetVisible)
        {
            LastKnownLocation = Stimulus.StimulusLocation;
        }
        if (!Target.IsValid())
        {
            Target = Actor; // o instigador do ruído (a jogadora, se foram passos dela)
        }
        UpdateState();
    }
}

float UVGAwarenessComponent::ComputeExposure() const
{
    const AActor* TargetActor = Target.Get();
    const AAIController* Controller = Cast<AAIController>(GetOwner());
    const APawn* Body = Controller ? Controller->GetPawn() : nullptr;
    if (!TargetActor || !Body)
    {
        return 0.0f;
    }

    // Distância: perto → 1, longe → 0.
    const float Distance = FVector::Dist(Body->GetActorLocation(), TargetActor->GetActorLocation());
    const float DistanceFactor = FMath::Clamp(1.0f - Distance / FullDistance, 0.0f, 1.0f);

    // Periferia: centro do olhar → 1, borda do cone → ~0,3.
    const FVector ToTarget = (TargetActor->GetActorLocation() - Body->GetActorLocation()).GetSafeNormal();
    const float Facing = FVector::DotProduct(Body->GetActorForwardVector(), ToTarget);
    const float PeripheryFactor = FMath::GetMappedRangeValueClamped(FVector2D(0.5f, 1.0f), FVector2D(0.3f, 1.0f), Facing);

    // Luz e postura, pelas tags do alvo (Cap. 23) — sem conhecer a classe da jogadora.
    float LightFactor = DarkExposure;
    float PostureFactor = 1.0f;
    if (const IGameplayTagAssetInterface* Tagged = Cast<IGameplayTagAssetInterface>(TargetActor))
    {
        if (Tagged->HasMatchingGameplayTag(TAG_Status_Light_Flashlight) || Tagged->HasMatchingGameplayTag(TAG_Status_Zone_Safe))
        {
            LightFactor = 1.0f; // lanterna acesa ou dentro da luz: bem visível
        }
        if (Tagged->HasMatchingGameplayTag(TAG_Status_Movement_Crouched))
        {
            PostureFactor = CrouchExposureMultiplier;
        }
    }
    return DistanceFactor * PeripheryFactor * LightFactor * PostureFactor;
}

void UVGAwarenessComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                          FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    if (bTargetVisible && Target.IsValid())
    {
        Awareness = FMath::Min(Awareness + BaseGainPerSecond * ComputeExposure() * DeltaTime, 1.0f);
        LastKnownLocation = Target->GetActorLocation();
    }
    else
    {
        Awareness = FMath::Max(Awareness - DecayPerSecond * DeltaTime, 0.0f); // a memória esfria
    }
    UpdateState();
}

void UVGAwarenessComponent::UpdateState()
{
    EVGAwarenessState NewState = State;
    switch (State) // limiares com histerese (Cap. 4)
    {
    case EVGAwarenessState::Unaware:
        if (Awareness >= SuspiciousEnter) { NewState = EVGAwarenessState::Suspicious; }
        break;
    case EVGAwarenessState::Suspicious:
        if (Awareness >= AwareEnter)          { NewState = EVGAwarenessState::Aware; }
        else if (Awareness < SuspiciousExit)  { NewState = EVGAwarenessState::Unaware; }
        break;
    case EVGAwarenessState::Aware:
        if (Awareness < AwareExit)            { NewState = EVGAwarenessState::Suspicious; }
        break;
    }
    if (NewState != State)
    {
        const EVGAwarenessState OldState = State;
        State = NewState;                                         // estado...
        OnAwarenessChanged.Broadcast(Target.Get(), OldState, NewState); // ...depois anúncio
    }
}
```

### Explicação das decisões

- **A AI Perception responde "o que percebo"; o componente de consciência responde "o que concluo".** O controller só encaminha.
- **Fatores multiplicativos de exposição**, todos ajustáveis por dados: distância, periferia, luz (pelas tags), postura (pelas tags). A regra de design "lanterna acesa = visível" está numa linha legível.
- **Ruídos dão saltos e um local**: o agente pode ficar desconfiado e ir investigar **onde** ouviu, sem saber exatamente **quem** — e, se a jogadora não estiver lá, ele procura (a HFSM e, depois, a BT).
- **A memória é a consciência decaindo** — e a última localização conhecida. Ficar fora de vista por tempo suficiente faz o agente "esquecer".
- **Tick a 10 Hz**: consciência é contínua mas lenta; não precisa de precisão de frame.
- **Simplificação declarada: um alvo de interesse.** Suficiente para a Vigília (a jogadora); multiplayer cooperativo (Capítulo 84) exigiria consciência por alvo.

🔁 O `UVGGuardBrainComponent` (Capítulo 34) troca o trace ingênuo pela consciência: `SeesTarget()` passa a ser "estado `Aware` e alvo visível"; o evento `HeardNoise` passa a ser despachado quando a consciência entra em `Suspicious`; `GetLastKnownLocation()` vem do componente.

### 6. O nível de ameaça

```cpp
// Source/Vigilia/AI/VGThreatSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGThreatSubsystem.generated.h"

UENUM(BlueprintType)
enum class EVGThreatLevel : uint8
{
    Calm,
    Uneasy,
    Hunting
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGThreatChangedSignature, EVGThreatLevel, OldLevel, EVGThreatLevel, NewLevel);

/** Dono do nível de ameaça global (a Presença informa; música, luzes e Diretor reagem). */
UCLASS()
class VIGILIA_API UVGThreatSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    /** A Presença informa a sua consciência sobre a jogadora (0..1). */
    void ReportPresenceAwareness(float Awareness);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Threat")
    EVGThreatLevel GetThreatLevel() const { return Level; }

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Threat")
    FVGThreatChangedSignature OnThreatLevelChanged;

private:
    EVGThreatLevel Level = EVGThreatLevel::Calm;
};
```

```cpp
// Source/Vigilia/AI/VGThreatSubsystem.cpp
#include "AI/VGThreatSubsystem.h"

void UVGThreatSubsystem::ReportPresenceAwareness(float Awareness)
{
    EVGThreatLevel NewLevel = Level;
    switch (Level) // histerese própria: a ameaça sobe rápido e desce devagar (pacing — Cap. 5)
    {
    case EVGThreatLevel::Calm:    if (Awareness >= 0.25f) { NewLevel = EVGThreatLevel::Uneasy; } break;
    case EVGThreatLevel::Uneasy:  if (Awareness >= 0.6f)  { NewLevel = EVGThreatLevel::Hunting; }
                                  else if (Awareness < 0.1f) { NewLevel = EVGThreatLevel::Calm; } break;
    case EVGThreatLevel::Hunting: if (Awareness < 0.35f)  { NewLevel = EVGThreatLevel::Uneasy; } break;
    }
    if (NewLevel != Level)
    {
        const EVGThreatLevel Old = Level;
        Level = NewLevel;
        OnThreatLevelChanged.Broadcast(Old, NewLevel);
    }
}
```

O controller da Presença (`BP_VGAIController_Presenca`, ou um pequeno componente nele) chama `ReportPresenceAwareness` sempre que a consciência muda de forma relevante. Os limiares do nível de ameaça são **diferentes** dos da consciência: a ameaça (que governa música e clima) sobe mais cedo e desce mais tarde — a jogadora sente o perigo um pouco antes de a Presença "decidir" caçar, e o alívio chega um pouco depois de ela desistir. É pacing (Capítulo 5) implementado como histerese.

---

## Projeto 5 — percepção

1. **Vigias** com visão e audição: passos correndo atraem; agachar e andar devagar permite passar atrás deles; tiros alertam todos num raio grande.
2. **Presença de teste** na Casa de Força: parada no fim do corredor, só percepção e consciência (sem decisão ainda). Com o Gameplay Debugger (categoria de percepção) e um texto de debug com a consciência e o estado, teste:
   - lanterna acesa no corredor escuro → ela fica ciente rápido;
   - lanterna apagada, andando → desconfiada só de perto;
   - agachada e apagada → quase invisível;
   - passos na passarela metálica do subsolo → saltos de suspeita.
3. **Nível de ameaça** ligado a um efeito simples: em `Uneasy`, as luzes próximas passam a falhar (o `UVGFlickerComponent` com um perfil de "presença"); em `Hunting`, um som grave de batimento toca.

---

## Decisões arquiteturais

1. **Três camadas: estímulo, percepção (engine) e consciência (projeto).** A decisão usa a consciência.
2. **AI Perception no controller**, com visão (histerese de raio, memória) e audição (eventos de ruído com tag).
3. **Consciência gradual por fatores de exposição** (distância, periferia, luz, postura), com estados por limiares com histerese.
4. **Luz e postura vêm das tags de status do alvo**; nada conhece a classe da jogadora.
5. **Ruídos emitidos por composição** (`UVGNoiseLibrary`), com intensidade por fonte e multiplicador de superfície.
6. **`UVGThreatSubsystem`** como dono do nível de ameaça, com histerese de pacing.
7. **Um alvo de interesse por agente** (simplificação declarada).

---

## Armadilhas

- **Percepção binária** (vi / não vi num frame).
- **Visão sem histerese de raio** — oscilação na borda.
- **Decisão usando percepção bruta** em vez de consciência.
- **IA onisciente** (lendo a posição da jogadora diretamente).
- **Ruído emitido por todo passo com a mesma intensidade** — sem decisões para o jogador.
- **Esconder-se sem custo** — estratégia dominante.
- **Detecção sem comunicação** — o jogador morre sem entender por quê.
- **Componentes de passos chamando a IA diretamente.**

---

## Exercício

**Parte 1 — sentidos (1,5 h).** Configure a percepção no `AVGAIController`, a fonte de estímulo na jogadora e a biblioteca de ruído. Faça passos, portas e disparos emitirem ruído. Use `vg.Debug.Noise 1` e o Gameplay Debugger para verificar.

**Parte 2 — consciência (2 h).** Implemente o `UVGAwarenessComponent` e substitua o trace ingênuo no cérebro do vigia. Ajuste os fatores até que: correr atrás de um vigia o alerte; andar agachada a 5 m não; lanterna acesa a 20 m de frente o faça desconfiar em ~1 s e ficar ciente em ~2 s.

**Parte 3 — ameaça (1 h).** Implemente o `UVGThreatSubsystem` e ligue-o à Presença de teste e a efeitos de luz e som. Jogue o corredor da Casa de Força com e sem lanterna.

**Parte 4 — legibilidade (45 min).** Peça a alguém para jogar o corredor sem explicação. Depois pergunte: "como você acha que ela te percebe?". A resposta corresponde às regras que você implementou? Se não, que sinal faltou?

---

## Desafio — o ruído que engana

Implemente **distração**: a jogadora pode pegar e **arremessar** pequenos objetos (uma garrafa, um parafuso) que fazem ruído onde caem.

1. Um pickup que concede um "item arremessável" (por simplicidade, um contador no personagem) e uma ação de arremesso que lança um projétil físico (o `AVGProjectile` do Capítulo 28, com gravidade e sem dano).
2. O impacto emite um ruído com tag `Distraction` e intensidade alta.
3. A consciência trata `Distraction` como ruído comum: salto de suspeita e **local** para investigar — **sem** atribuir o ruído à jogadora como alvo (o instigador do evento pode ser a garrafa, não ela).

Teste com a Presença e com um vigia: é possível atraí-los para longe de um corredor? Pergunta para o `DEVLOG.md`: que mudança no componente de consciência foi necessária para que o ruído de distração não "revele" a jogadora? O que isso diz sobre a diferença entre **"ouvi algo ali"** e **"ouvi alguém ali"**?

---

## Uso de IA

1. **Para ajustar a consciência:**
   > "Tenho um modelo de consciência gradual para inimigos: ganho por segundo = base × fator de distância × fator de periferia × fator de luz × fator de postura; decaimento linear sem estímulo; estados com limiares e histerese (0,3/0,15 e 0,6/0,5). Para um jogo de terror com uma criatura que caça a jogadora, proponha valores iniciais, explique o tempo esperado até detectar em 4 cenários (lanterna acesa a 20 m, escuro a 10 m, escuro agachada a 5 m, passos metálicos a 15 m) e como testar em playtest."

2. **Para configurar a AI Perception:**
   > "Explique a configuração dos sentidos de visão e audição da AI Perception na Unreal Engine 5 (SightRadius, LoseSightRadius, PeripheralVisionAngleDegrees, DetectionByAffiliation, MaxAge, HearingRange), o registro de fontes de estímulo e o significado de cada campo de FAIStimulus. Indique o que pode variar entre versões."

3. **Para design de percepção justa:**
   > "Liste princípios de percepção justa para inimigos em jogos de terror e furtividade (regras aprendíveis, detecção gradual, comunicação, custo de se esconder). Para cada princípio, dê um exemplo de sinal audiovisual que comunica o estado da percepção ao jogador sem UI explícita."

---

## Checklist

- [ ] Sei separar estímulo, percepção e consciência.
- [ ] Sei configurar visão, audição, afiliação, histerese de visão e memória na AI Perception.
- [ ] Emito ruídos com intensidade, alcance e tag a partir de passos, portas, armas e impactos.
- [ ] Implementei consciência gradual com fatores de exposição e estados com histerese.
- [ ] A luz (lanterna, zonas) e a postura afetam a percepção pelas tags de status.
- [ ] Implementei o nível de ameaça global e liguei a efeitos de apresentação.
- [ ] Testei a legibilidade da percepção com outra pessoa.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **AI Perception** (sentidos, fontes de estímulo, eventos) e **Gameplay Debugger** (categoria de percepção).
- **GDC Vault** (gdcvault.com) — busque talks sobre *stealth AI*, *perception* e *awareness* em jogos furtivos e de terror; vários discutem medidores de detecção e comunicação ao jogador.
- **Steve Rabin (org.), *Game AI Pro*** — há capítulos sobre percepção e sobre modelagem de sentidos de agentes.

---

➡️ **Próximo:** [Capítulo 37 — Behavior Trees](cap-37-behavior-trees.md)

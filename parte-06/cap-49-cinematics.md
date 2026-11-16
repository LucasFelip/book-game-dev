# Capítulo 49 — Cinematics

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir as **formas de cena** (vídeo pré-renderizado, cinemática *in-engine*, evento roteirizado com controle, painéis, híbrido) e escolher cada uma pelo custo e pelo efeito;
- usar o **Sequencer** da Unreal: *Level Sequences*, trilhas, *bindings*, câmeras de cinema, trilhas de evento;
- projetar **transições** entre gameplay e cinemática que não quebram a imersão;
- tratar **pular** e **cancelar** como problemas de **estado**, não de vídeo: pular aplica o fim, cancelar não;
- separar **apresentação** (o Sequencer) de **efeitos de estado** (o código), e por que essa separação resolve a dor 6 do Interlúdio I;
- integrar cinemáticas ao rádio (Capítulo 44), às quests (Capítulo 45), ao estado narrativo (Capítulo 46) e ao Diretor (Capítulo 42);
- concluir o **Projeto 6**: o *Turno da Noite* sem cola narrativa no Level Blueprint.

---

## Contexto

O Interlúdio I fez a cinemática final do jeito mais rápido possível: `Play(LS_FinalTurnoDaNoite)`, seguido de `Delay(6.0)` "(duração da sequência, escrito à mão!)" e da fala de Sônia. O susto do corredor era uma cadeia de `Delay` e `SetPattern`. O inventário de dores registrou o preço:

- **Dor 6 — sequências sem cancelamento.** A cascata de luzes continua se algo der errado no meio, e a duração da cinemática, escrita à mão num `Delay`, quebra quando a sequência é editada.
- **O que sobra da dor 12.** As sequências são as últimas coisas grandes ainda no Level Blueprint, além do puzzle, que é o Capítulo 50.

Há também uma pergunta que o Interlúdio não enfrentou: **o que acontece quando a jogadora pula uma cena?** No protótipo, nada pulava. Num jogo de verdade, pular é obrigatório (quem rejoga não quer rever a cena), e pular de forma ingênua **quebra estado**: a fala que a cena pedia nunca é pedida, o fato que a cena concedia nunca é concedido, e a quest espera para sempre.

---

## 49.1 Formas de cena

| Forma | Controle da jogadora | Custo | Coerência visual com o jogo | Exemplo |
|---|---|---|---|---|
| **Vídeo pré-renderizado** | Nenhum | Alto (produção externa) e fixo | Pode destoar | Aberturas de muitos jogos |
| **Cinemática *in-engine*** | Nenhum (ou só "pular") | Médio | Total: mesmo mundo, mesma luz | O final do *Turno da Noite* |
| **Evento roteirizado com controle** | Total | Baixo a médio | Total | O susto do corredor: a jogadora continua andando |
| **Painéis / quadrinhos** | Nenhum | Baixo | Estilizada de propósito | Max Payne (estudo de caso) |
| **Híbrido** (*live action* + jogo) | Nenhum nos trechos filmados | Muito alto | Contraste deliberado | Quantum Break (estudo de caso) |

A escolha central é **quanto controle tirar da jogadora**. Num jogo de terror, a perda de controle é ambígua. Por um lado, é vulnerabilidade, o que serve ao medo. Por outro, é desconexão: a jogadora vira espectadora, e espectadores não têm medo do mesmo jeito que quem pode morrer. A Vigília usa as duas pontas com intenção:

- **Eventos roteirizados com controle** para o medo (o susto do corredor). A jogadora vive a cena.
- **Cinemáticas curtas sem controle** para as **revelações** (o fim de cada setor). A jogadora para e olha, e a cena é a recompensa.

---

## 49.2 O Sequencer em uma página

O Sequencer é o editor de cinemáticas da Unreal: uma linha do tempo com **trilhas** que animam propriedades de atores.

```text
 LS_FinalTurnoDaNoite (Level Sequence)
 ├── Camera Cuts           qual câmera está ativa em cada trecho
 ├── CineCamera_Paineis    (spawnable) transform, foco, abertura
 ├── CineCamera_Janela     (spawnable) travelling até a janela
 ├── Turbina3              (possessable: o ator do nível) rotação ligada no frame 90
 ├── Paineis_Luzes         (possessable) intensidade em sequência
 ├── Audio                 zumbido sobe; chiado no fim
 ├── Fade                  fade-out no último segundo
 └── Events                trilha de evento: "PedirFalaFinal" no frame 135
```

- ***Bindings* *possessable* e *spawnable*.** Um *possessable* anima um ator **que já existe no nível** (a turbina, as luzes); um *spawnable* é criado pela sequência e destruído quando ela termina (as câmeras, a silhueta do susto). Regra prática: o que pertence ao mundo é *possessable*, e o que só existe para a cena é *spawnable*.
- **Estado ao terminar.** Cada seção tem uma política para quando a sequência termina: **manter** o estado que ela deixou (*Keep State*) ou **restaurar** o anterior (*Restore State*). A turbina que começou a girar deve continuar girando (manter); a câmera de cinema volta para a da jogadora (restaurar). ⚠️ Os nomes exatos e onde a opção aparece (seção, trilha, configurações de reprodução) variam entre versões: confira na sua.
- **Trilha de evento.** Chama uma função num momento exato da sequência. É a ponte entre a linha do tempo e os sistemas do jogo, e deve ser usada com cuidado (seção 49.4).
- **Reprodução.** Em runtime, uma sequência é tocada por um `ULevelSequencePlayer`, normalmente através de um `ALevelSequenceActor` colocado no nível. O *player* anuncia `OnFinished` quando chega ao fim.

---

## 49.3 Entrar e sair da cena

A transição é onde a imersão quebra. Três coisas precisam acontecer ao **entrar**, e três ao **sair**.

**Ao entrar:**

1. **Input.** Empilhar o modo `Cinematic` (Capítulo 16). O `IMC_Cinematica` consome movimento e olhar e só oferece "pular".
2. **Mundo.** O Diretor não pode escolher este momento para um pico (Capítulo 42). Uma **trava de roteiro** (`PushScriptLock`) força a fase `Relax` durante a cena, e a Presença recua.
3. **Câmera.** Do ponto de vista da jogadora para a primeira câmera da cena, com uma mistura curta (*blend*) ou um corte seco. Corte seco é a escolha honesta quando a cena começa num enquadramento muito diferente. Mistura é melhor quando a primeira câmera está perto dos olhos de Helena.

**Ao sair:**

1. **Câmera de volta**, com o último enquadramento da cena **perto** de onde a jogadora estará. Uma cena que termina olhando para a janela devolve a jogadora olhando para a janela.
2. **Input e Diretor** desempilhados, na ordem inversa.
3. **Estado**: os efeitos da cena aplicados (seção 49.4).

> 🌉 **Ponte:** entrar e sair de uma cinemática é uma **transação** sobre o estado da sessão: modo de input, travas, câmera. Se uma parte falhar no meio, todas precisam ser desfeitas, e o padrão é o mesmo de qualquer recurso adquirido: quem adquire, libera, inclusive no caminho de erro.
>
> 🧱 **Onde a ponte cai:** não há *rollback* do mundo. A cena pode ter girado a turbina, e um cancelamento não a desgira. O que a cena **mudou no mundo** (apresentação) e o que ela **concedeu à história** (estado) precisam de políticas diferentes, e é isso que a próxima seção separa.

---

## 49.4 Pular não é parar

A regra mais importante do capítulo:

> **O Sequencer é apresentação. Efeitos de estado acontecem no código, quando a cena termina, de um jeito que vale igual para "terminou", "foi pulada" e "foi cancelada".**

Considere o que a cinemática final do setor 1 **faz para a história**:

- pede a fala final de Sônia (a variante pelos fatos, Capítulo 47);
- a quest espera essa fala terminar para concluir (Capítulo 45);
- e, ao concluir, o capítulo acaba.

Se o pedido da fala estiver **só** numa trilha de evento no meio da sequência, três coisas dão errado:

| O que acontece | Com o efeito só na trilha de evento |
|---|---|
| A sequência termina normalmente | ✓ funciona |
| A jogadora **pula** antes do evento | ✗ pular salta para o fim **sem disparar** os eventos do meio (⚠️ confira o comportamento de "pular para o fim" na sua versão); a fala nunca é pedida; a quest nunca conclui |
| A sequência é **cancelada** (por exemplo, a jogadora morre num evento roteirizado) | ? depende de onde parou; o estado fica pela metade |

A solução tem três partes:

1. **Efeitos de estado no `Finish`.** O ator da cinemática tem uma lista declarada do que a cena deixa: fatos a conceder, uma conversa a pedir. Quando a cena **termina ou é pulada**, ele aplica essa lista. Quando é **cancelada**, não aplica.
2. **Trilhas de evento só para sincronizar apresentação.** O evento no frame 135 pede a fala de Sônia **no momento exato** em que a câmera chega à janela, porque isso é direção. Se a cena for pulada antes, o `Finish` pede a mesma fala. Ela é pedida uma vez só, porque o canal de rádio recusa uma conversa já pendente ou já tocada (Capítulo 44) e a memória persiste (Capítulo 46). **A idempotência do sistema de diálogo é o que torna a trilha de evento segura.**
3. **Pular aplica o estado final da apresentação.** "Pular" salta a sequência para o fim antes de pará-la, e as seções com "manter estado" deixam o mundo como ele ficaria (a turbina girando). "Parar" deixaria a turbina parada, como se a cena não tivesse acontecido.

O mesmo vale para **cancelar**. O susto do corredor é um evento roteirizado com a jogadora no controle; se ela morrer no meio (no setor 2, onde a Presença é sistêmica, isso é possível), a sequência é cancelada, as luzes **voltam** ao padrão normal (restaurar estado) e nenhum efeito final é aplicado. O fato `S1.ScareDone` foi concedido pelo gatilho **ao disparar** (Capítulo 45), de propósito: o susto conta como acontecido mesmo se interrompido.

---

## 49.5 Diálogo dentro da cena

Há dois jeitos de pôr a voz de Sônia numa cinemática:

| Abordagem | Sincronia com a imagem | Legendas, localização, memória, variantes | Custo |
|---|---|---|---|
| **A. Áudio numa trilha do Sequencer** | Exata, por frame | Fora do sistema do Cap. 44: legenda manual, sem variantes por fato, sem memória | Baixo |
| **B. Trilha de evento pedindo uma conversa ao canal de rádio** | Boa: começa no frame do evento, com a duração da própria fala | Tudo do Cap. 44: legenda, variante, memória, prioridade | Baixo |

A Vigília usa **B** para tudo o que é rádio. As variantes da fala final dependem de fatos (memorando, admissão), e reimplementar isso dentro do Sequencer seria duplicar o sistema de diálogo. A fala entra como **Critical**, e o rádio a toca por cima de qualquer outra. A sincronia exata por frame (lábios, por exemplo) seria um argumento para **A**, e a Vigília não tem personagens falando em cena. Num jogo com diálogo em cena e animação facial, o mais comum é o áudio da fala na trilha do Sequencer e a legenda vinda do mesmo dado (⚠️ assunto do Capítulo 53).

---

## Estudos de caso

### Max Payne — a cinemática como quadrinho

**[FATO PÚBLICO]** *Max Payne* (Remedy, 2001) e *Max Payne 2* (2003) contam boa parte da história em **painéis de história em quadrinhos** (*graphic novel*), com a narração de Max em voz *off*, intercalados com o jogo.

**[INFERÊNCIA]** Os painéis resolvem um problema de custo e de estilo ao mesmo tempo. Uma cena em painéis é muito mais barata de produzir do que uma cinemática animada da época, e a estética noir dos quadrinhos virou identidade: o monólogo interior de Max, que seria estranho numa cena animada, é natural num quadrinho. A forma de cena foi escolhida pelo que o jogo podia produzir **e** pelo que ele queria dizer.

**Lição para a Vigília:** a forma da cena é uma decisão de design, não um padrão técnico. Para um projeto individual, uma cinemática curta *in-engine*, com câmera, luz e rádio, é o equivalente dos painéis de Max Payne: barata, coerente com o jogo e com voz própria.

### Quantum Break — o custo de dois meios

**[FATO PÚBLICO]** *Quantum Break* (Remedy, 2016) intercala atos jogáveis com episódios em *live action*, com atores que também aparecem, digitalizados, dentro do jogo. As escolhas das junções (Capítulo 47) alteram partes dos episódios filmados.

**[INFERÊNCIA]** A integração entre os dois meios é cara em todas as direções: filmar variações, manter a continuidade entre o ator filmado e o personagem digital, e sincronizar o que o jogador fez com o que ele assiste. O desenho concentra o *live action* em pontos fixos e bem marcados (entre atos), em vez de espalhá-lo.

**Lição para a Vigília:** cenas que dependem do estado são caras na proporção do número de variações. As cinemáticas da Vigília **não** variam: as variações moram no rádio, que já resolve variantes por dado. A imagem é a mesma para todas as jogadoras, e a voz de Sônia é que muda.

### GTA V — transições sem costura

**[FATO PÚBLICO — observável jogando]** Em *Grand Theft Auto V*, muitas cenas de missão começam e terminam com a câmera se movendo continuamente entre o enquadramento da cena e a câmera de jogo, e a troca entre os três protagonistas usa uma transição de câmera característica, que se afasta e se aproxima do novo personagem.

**[INFERÊNCIA]** A continuidade de câmera esconde a fronteira entre "cena" e "jogo". O jogador não sente o corte de controle, porque a imagem não corta. Para isso funcionar, a cena precisa terminar num enquadramento compatível com a câmera de jogo, uma decisão de direção que vale para cada cena, não uma função técnica.

**Lição para a Vigília:** a cinemática final do setor 1 termina olhando pela janela, na altura dos olhos de Helena, e devolve a jogadora exatamente ali. A regra vai para o guia de direção do projeto: **toda cena termina onde a jogadora vai estar.**

---

## Comparação com o desenvolvimento tradicional

| Cinemáticas | O que você conhece | Onde a analogia cai |
|---|---|---|
| Entrar e sair da cena | Adquirir e liberar recursos (RAII, `try/finally`) | O mundo não tem *rollback*; o que a cena mudou fica |
| Efeitos no `Finish`, não na trilha | Efeitos colaterais no *commit*, não durante o processamento | "Pular" é um terceiro caminho, que deve aplicar o *commit* sem o processamento |
| Idempotência do pedido de fala | Requisições idempotentes com chave | — (a analogia vale, e é o que torna o desenho seguro) |
| Possessable × spawnable | Referência a recurso existente × recurso efêmero criado pelo processo | — |
| Trilha de evento | *Hook* agendado numa linha do tempo | O "relógio" é o da sequência, que pode ser pulado e cancelado |

---

## Unreal Engine: o que existe

- **Sequencer**, *Level Sequences* e *Cine Camera Actors*, com trilhas de transformação, visibilidade, áudio, fade, cortes de câmera e eventos.
- **`ALevelSequenceActor`**, o ator que toca uma sequência no nível, com configurações de reprodução (`PlaybackSettings`) e o *player* (`GetSequencePlayer()`).
- **`ULevelSequencePlayer` / `UMovieSceneSequencePlayer`**: `Play`, `Stop`, `Pause` e operações de posição (⚠️ `GoToEndAndStop` e a forma de saltar posição com ou sem disparo de eventos variam entre versões: confira na sua), mais o evento `OnFinished`.
- **Trilhas de evento** com *endpoints* num *Director Blueprint* da sequência, ou em objetos vinculados.
- **Enhanced Input**: o gatilho ***Hold*** numa *Input Action* implementa "segure para pular" sem uma linha de código de temporização.
- Módulos: `LevelSequence` e `MovieScene` no `Build.cs`.

---

## Abordagens: onde moram as regras de jogo de uma cena

| Critério | A. Level Blueprint (Interlúdio I) | B. Tudo no Sequencer (trilhas de evento para tudo) | **C. Um ator de cinemática com regras declaradas** |
|---|---|---|---|
| **Pular e cancelar corretos** | Não | Não: eventos no meio são perdidos ao pular | Sim: `Finish` aplica o estado declarado |
| **Duração** | Escrita à mão (`Delay`) | Da sequência | Da sequência (`OnFinished`) |
| **Reuso** (susto, final, fim de capítulo) | Nenhum | Por sequência | O mesmo ator, configurado |
| **Integração** (input, Diretor, rádio, fatos) | Nós espalhados | Por eventos, frágil | Declarada em propriedades |
| **Adequação à Vigília** | Foi a dor | Insuficiente | **Sim** |

**Decisão: C.** Um `AVGCinematicActor`, subclasse de `ALevelSequenceActor`, com as regras de jogo como propriedades e a separação apresentação/estado da seção 49.4.

---

## Implementação

### 1. Tags e o subsistema mínimo

```cpp
// VGGameplayTags.h (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Cinematic_Started);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Cinematic_Finished);

// VGGameplayTags.cpp (adições)
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Cinematic_Started,  "Event.Cinematic.Started");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Cinematic_Finished, "Event.Cinematic.Finished");
```

Conteúdo: `Cinematic.*` identifica cenas (`Cinematic.S1.Final`, `Cinematic.S1.Scare`).

```cpp
// Source/Vigilia/Narrative/VGCinematicSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGCinematicSubsystem.generated.h"

class AVGCinematicActor;

/** Quem está tocando uma cena que tomou o controle. Consultado pelo "pular" e pelo save (Cap. 56). */
UCLASS()
class VIGILIA_API UVGCinematicSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    AVGCinematicActor* GetCurrent() const { return Current.Get(); }
    void SetCurrent(AVGCinematicActor* Cinematic) { Current = Cinematic; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Cinematic")
    bool IsPlaying() const { return Current.IsValid(); }

    /** Chamado pelo controller quando IA_Pular dispara (gatilho Hold no IMC_Cinematica). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Cinematic")
    void SkipCurrent();

private:
    TWeakObjectPtr<AVGCinematicActor> Current;
};
```

### 2. O ator de cinemática

```cpp
// Source/Vigilia/Narrative/VGCinematicActor.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "LevelSequenceActor.h"
#include "VGCinematicActor.generated.h"

class UVGDialogueData;
struct FVGGameplayEvent;

/**
 * Uma Level Sequence com regras de jogo: o que a dispara, o que ela toma da jogadora,
 * se pode ser pulada, e o ESTADO que ela deixa (aplicado no fim ou ao pular; nunca ao cancelar).
 * Regra: o Sequencer é apresentação; efeitos de estado acontecem em Finish(), no código.
 */
UCLASS()
class VIGILIA_API AVGCinematicActor : public ALevelSequenceActor
{
    GENERATED_BODY()

public:
    AVGCinematicActor(const FObjectInitializer& ObjectInitializer);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Cinematic")
    void PlayCinematic();

    /** Salta para o fim aplicando o estado final. Só se bSkippable. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Cinematic")
    void Skip();

    /** Interrompe SEM aplicar o estado final (ex.: a jogadora morreu num evento roteirizado). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Cinematic")
    void Cancel();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Cinematic")
    bool IsRunning() const { return bRunning; }

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic", meta = (Categories = "Cinematic"))
    FGameplayTag CinematicTag;

    /** Dispara sozinho quando este evento passa pelo barramento. Vazio = só por PlayCinematic. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic|Trigger", meta = (Categories = "Event"))
    FGameplayTag TriggerChannel;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic|Trigger")
    FGameplayTag TriggerContext;

    /** Toma o controle (modo Cinematic). Falso = evento roteirizado com a jogadora no controle. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic")
    bool bTakeControl = true;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic")
    bool bSkippable = true;

    /** Força o Diretor em Relax durante a cena (Cap. 42). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic")
    bool bHoldDirector = true;

    /** Pedida no fim (ou ao pular), se ainda não foi pedida pela trilha de evento. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic|End State")
    TObjectPtr<const UVGDialogueData> ConversationAtEnd;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Cinematic|End State", meta = (Categories = "Narrative.Fact"))
    FGameplayTagContainer FactsOnFinish;

private:
    UFUNCTION()
    void HandleSequenceFinished();

    void HandleEvent(const FVGGameplayEvent& Event);
    void Finish(bool bApplyEndState);

    bool bRunning = false;
    int32 DirectorLock = INDEX_NONE;
    FDelegateHandle EventHandle;
};
```

```cpp
// Source/Vigilia/Narrative/VGCinematicActor.cpp
#include "Narrative/VGCinematicActor.h"

#include "AI/VGDirectorSubsystem.h"
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "LevelSequencePlayer.h"
#include "Narrative/VGCinematicSubsystem.h"
#include "Narrative/VGDialogueSubsystem.h"
#include "Narrative/VGNarrativeSubsystem.h"
#include "Player/VGPlayerController.h"

AVGCinematicActor::AVGCinematicActor(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer)
{
    // Quem decide quando toca é o jogo. ⚠️ O campo de auto-play mudou de lugar entre versões: confira.
    PlaybackSettings.bAutoPlay = false;
}

void AVGCinematicActor::BeginPlay()
{
    Super::BeginPlay();
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &AVGCinematicActor::HandleEvent);
    }
    if (ULevelSequencePlayer* Player = GetSequencePlayer())
    {
        Player->OnFinished.AddDynamic(this, &AVGCinematicActor::HandleSequenceFinished);
    }
}

void AVGCinematicActor::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (bRunning)
    {
        Finish(false); // o nível está saindo: libera input e Diretor, sem efeitos
    }
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::EndPlay(EndPlayReason);
}

void AVGCinematicActor::HandleEvent(const FVGGameplayEvent& Event)
{
    if (bRunning)
    {
        // Evento roteirizado com controle não sobrevive à morte da jogadora.
        if (!bTakeControl && Event.Channel.MatchesTagExact(TAG_Event_Player_Died))
        {
            Cancel();
        }
        return;
    }
    const bool bMatches = TriggerChannel.IsValid() && Event.Channel.MatchesTagExact(TriggerChannel)
        && (!TriggerContext.IsValid() || Event.Context.MatchesTagExact(TriggerContext));
    if (bMatches)
    {
        PlayCinematic();
    }
}

void AVGCinematicActor::PlayCinematic()
{
    ULevelSequencePlayer* Player = GetSequencePlayer();
    UVGCinematicSubsystem* Cinematics = GetWorld()->GetSubsystem<UVGCinematicSubsystem>();
    if (bRunning || !Player || (bTakeControl && Cinematics && Cinematics->IsPlaying()))
    {
        return; // uma cena que toma o controle por vez
    }
    bRunning = true;

    if (bTakeControl)
    {
        if (AVGPlayerController* PC = Cast<AVGPlayerController>(GetWorld()->GetFirstPlayerController()))
        {
            PC->PushInputMode(EVGInputMode::Cinematic);
        }
        if (Cinematics)
        {
            Cinematics->SetCurrent(this);
        }
    }
    if (bHoldDirector)
    {
        if (UVGDirectorSubsystem* Director = GetWorld()->GetSubsystem<UVGDirectorSubsystem>())
        {
            DirectorLock = Director->PushScriptLock(EVGDirectorPhase::Relax, GetFName());
        }
    }
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Cinematic_Started, nullptr, this, CinematicTag);
    Player->Play();
}

void AVGCinematicActor::Skip()
{
    if (!bRunning || !bSkippable)
    {
        return;
    }
    if (ULevelSequencePlayer* Player = GetSequencePlayer())
    {
        // Fim da apresentação: seções "manter estado" deixam o mundo como a cena o deixaria.
        // Eventos do meio não disparam ao saltar (⚠️ confira) — por isso o estado mora em Finish.
        Player->GoToEndAndStop();
    }
    Finish(true); // se OnFinished também vier, Finish ignora (bRunning já é falso)
}

void AVGCinematicActor::Cancel()
{
    if (!bRunning)
    {
        return;
    }
    Finish(false); // ANTES do Stop: se Stop anunciar OnFinished, ele não pode aplicar o estado final
    if (ULevelSequencePlayer* Player = GetSequencePlayer())
    {
        Player->Stop();
    }
}

void AVGCinematicActor::HandleSequenceFinished()
{
    Finish(true);
}

void AVGCinematicActor::Finish(bool bApplyEndState)
{
    if (!bRunning)
    {
        return; // termina uma vez só, venha o fim de onde vier
    }
    bRunning = false;

    // 1. Libera o que adquiriu, na ordem inversa.
    if (DirectorLock != INDEX_NONE)
    {
        if (UVGDirectorSubsystem* Director = GetWorld()->GetSubsystem<UVGDirectorSubsystem>())
        {
            Director->PopScriptLock(DirectorLock);
        }
        DirectorLock = INDEX_NONE;
    }
    if (bTakeControl)
    {
        if (UVGCinematicSubsystem* Cinematics = GetWorld()->GetSubsystem<UVGCinematicSubsystem>())
        {
            Cinematics->SetCurrent(nullptr);
        }
        if (AVGPlayerController* PC = Cast<AVGPlayerController>(GetWorld()->GetFirstPlayerController()))
        {
            PC->PopInputMode(EVGInputMode::Cinematic);
        }
    }

    // 2. Efeitos de estado: no fim ou ao pular; nunca ao cancelar.
    if (!bApplyEndState)
    {
        return;
    }
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        for (const FGameplayTag& Fact : FactsOnFinish)
        {
            Narrative->AddFact(Fact);
        }
    }
    if (ConversationAtEnd)
    {
        if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
        {
            Dialogue->RequestConversation(ConversationAtEnd); // recusa se já pendente ou já tocada (Cap. 44)
        }
    }
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Cinematic_Finished, nullptr, this, CinematicTag);
}
```

```cpp
// Source/Vigilia/Narrative/VGCinematicSubsystem.cpp
#include "Narrative/VGCinematicSubsystem.h"

#include "Narrative/VGCinematicActor.h"

void UVGCinematicSubsystem::SkipCurrent()
{
    if (AVGCinematicActor* Cinematic = Current.Get())
    {
        Cinematic->Skip();
    }
}
```

`Build.cs`: acrescente `"LevelSequence"` e `"MovieScene"`.

### 3. Pular: segurar, não apertar

No `IMC_Cinematica` (Capítulo 16), a ação `IA_Pular` recebe um gatilho **Hold** de 1 segundo. O controller liga `ETriggerEvent::Triggered` de `IA_Pular` a `UVGCinematicSubsystem::SkipCurrent`. Segurar evita pulos acidentais de quem só queria apertar um botão para "ver se a cena acabou", e não exige nenhum código de temporização. A UI mostra o progresso do *hold* (Capítulo 55).

### Explicação das decisões

- **Subclasse de `ALevelSequenceActor`**, e não um componente ou um ator separado que aponta para a sequência. O ator **é** a cena no nível, e as regras de jogo ficam no mesmo lugar em que o designer posiciona e edita a sequência.
- **`Finish` é o único lugar de saída**, idempotente pela guarda `bRunning`. Fim natural, pulo, cancelamento e saída do nível passam por ali. A ordem de liberação é a inversa da aquisição.
- **Cancelar chama `Finish(false)` antes do `Stop`.** Se o `Stop` anunciar `OnFinished` de forma síncrona, o `Finish(true)` que viria dali encontra `bRunning` falso e não faz nada. A ordem resolve uma condição de corrida sem nenhum mecanismo extra.
- **Pular chama `GoToEndAndStop` antes de `Finish(true)`**, para que a apresentação chegue ao estado final (seções "manter") antes de os efeitos de estado rodarem.
- **Disparo por evento do barramento** (`TriggerChannel` + `TriggerContext`). O gatilho do susto (Capítulo 45, condicionado a fatos) publica `Event.Trigger.Entered` com o local, e a cena ouve. Nenhum Level Blueprint conecta os dois.
- **Morte cancela só cenas roteirizadas com controle.** Uma cena que tomou o controle não tem como ser interrompida pela morte, porque o Diretor está travado e a jogadora não pode ser atacada.
- **`EndPlay` libera sem efeitos**, porque um nível que sai no meio de uma cena (um load) não pode deixar a pilha de input com `Cinematic` empilhado.
- **Sem teste automatizado de unidade.** O ator é cola entre o Sequencer e os sistemas, e a lógica pura que valeria testar (`Finish` uma vez só) é uma guarda de uma linha. A verificação é uma lista de cenários no PIE (Exercício, Parte 3), e o Capítulo 61 mostra como transformar cenários assim em testes funcionais.

---

## Projeto 6 — fim da refatoração do Turno da Noite

🔁 A última etapa. As sequências saem do Level Blueprint.

### As cenas do setor 1

| Ator | Sequência | Disparo | Controle | Pular | Estado no fim |
|---|---|---|---|---|---|
| `BP_Cena_SustoCorredor` | `LS_SustoCorredor`: cascata de flicker, silêncio, silhueta (*spawnable*), retorno das luzes | `Event.Trigger.Entered` + `Location.S1.CorridorCurve` (o gatilho condicionado do Cap. 45) | **Não toma** | Não | — (o fato veio do gatilho) |
| `BP_Cena_Final` | `LS_FinalTurnoDaNoite`: painéis, travelling até a janela, turbina 3 (*possessable*) girando, chiado | `PlayCinematic`, chamado pelo painel principal, que referencia o ator da cena | Toma | Sim (segurar) | Conversa `DA_Dlg_S1_Final` (também pedida pela trilha de evento no frame 135) |
| `BP_Cena_FimCapitulo` | `LS_FimCapitulo1`: fade e "FIM DO CAPÍTULO 1" | `Event.Quest.Signal` + `Signal.S1.ChapterEnd` | Toma | Não | — |

A cascata de luzes do susto usa a trilha de evento para chamar `SetPattern` no `UVGFlickerComponent` de cada luminária no frame certo, e a seção de cada luz **restaura** o estado ao terminar (as luzes voltam ao normal sozinhas). Num cancelamento, o *restore* devolve as luzes ao normal, sem nenhuma linha extra.

A cadeia do fim do capítulo, inteira, sem nenhum `Delay`:

```text
 jogadora interage com o painel ──► BP_Cena_Final toca (Diretor em Relax, modo Cinematic)
   frame 135: trilha de evento pede DA_Dlg_S1_Final (Critical) ──► Sônia, com a variante pelos fatos
   fim da sequência (ou "pular"): Finish ──► pede DA_Dlg_S1_Final de novo (recusado: já pendente/tocada)
 fala termina ──► Event.Dialogue.Finished ──► objetivo DA_Obj_S1_Painel conclui (Cap. 45)
   ──► quest conclui ──► regra: fato S1.Completed (Cap. 46) ──► sinal Signal.S1.ChapterEnd
   ──► BP_Cena_FimCapitulo toca o fade
```

### O Level Blueprint de `L_CasaDeForca`, no fim da Parte VI

```text
[Event BeginPlay]
  → Start Quest (DA_Quest_S1_NightShift)
[Puzzle dos disjuntores]          -- vira um ator reutilizável no Capítulo 50
```

### O inventário de dores, final da Parte VI

| # | Dor | Resolvida em | Como |
|---|---|---|---|
| 1 | Estado narrativo espalhado e invisível | Cap. 46 | Dono único, catálogo, painel |
| 2 | Impossível salvar | Cap. 46 → **56** | Snapshot pronta; o save em disco é o Cap. 56 |
| 3 | Texto de diálogo no grafo | Cap. 44 | Dados + *String Tables* |
| 4 | Ramificação como `Branch` espalhado | Caps. 44–47 | Fatos, variantes, auditoria |
| 5 | Ordem de beats não garantida | Cap. 45 | Objetivos paralelos, "concluída se" |
| 6 | Sequências sem cancelamento | **Cap. 49** | Ator de cinemática; estado no `Finish`; duração pela sequência |
| 7 | Gatilhos que lembram errado | Cap. 45 | Gatilho condicionado a fatos |
| 8 | Nada é reutilizável | Caps. 44–49 | Diálogo, quests, fatos, documentos e cenas servem a qualquer setor |
| 9 | Nada é testável | Caps. 44–48 | Regras puras testadas, cheats, auditoria, JSON de estados |
| 10 | O rádio não sabe o que disse | Cap. 44 | Memória (persistente desde o Cap. 46) |
| 11 | A Presença é uma malha que aparece e some | Parte V | IA de verdade; a primeira aparição continua roteirizada, de propósito |
| 12 | O Level Blueprint cresce sem controle | Caps. 44–49 → **50** | Sobram uma linha e o puzzle |

A dor 11 merece uma nota de design. A **primeira** aparição da Presença continua sendo cenografia (a silhueta *spawnable* do susto), mesmo com a IA da Parte V pronta. É uma decisão deliberada: o primeiro encontro é **autoral** (a jogadora precisa ver a Presença de um jeito controlado, no lugar e no ritmo certos), e todos os seguintes são **sistêmicos**. É a mistura de narrativa embutida e emergente do Capítulo 43, aplicada a um único personagem.

---

## Decisões arquiteturais

1. **Forma de cena por intenção**: eventos roteirizados com controle para o medo; cinemáticas curtas sem controle para as revelações.
2. **O Sequencer é apresentação; o estado mora no código**, aplicado num `Finish` único e idempotente.
3. **Pular aplica o fim; cancelar não.** Pular salta para o fim e aplica os efeitos declarados; cancelar libera os recursos sem efeitos.
4. **Trilhas de evento só para sincronizar**; elas podem pedir efeitos idempotentes (conversas), que o `Finish` garante de novo.
5. **Rádio em cena pelo canal do Cap. 44** (legenda, variantes, memória), não por áudio na trilha.
6. **Cenas disparadas por eventos do barramento**; nenhum Level Blueprint liga gatilho a sequência.
7. **Toda cena termina onde a jogadora vai estar.**
8. **A primeira aparição da Presença é autoral; as seguintes, sistêmicas.**

---

## Armadilhas

- **Efeitos de estado só em trilhas de evento.** Pular perde o efeito, e a quest espera para sempre.
- **"Pular" implementado como "parar".** A turbina para de girar, a porta volta a fechar, o mundo desfaz a cena.
- **Duração escrita à mão.** A sequência é editada, e o `Delay` mente.
- **Modo de input empilhado e nunca desempilhado** quando o nível sai no meio da cena.
- **O Diretor escolhendo a cena para um pico.** A Presença ataca durante a revelação.
- **Cenas longas sem controle num jogo de terror.** A espectadora deixa de ter medo.
- **Cena que termina longe da jogadora.** O corte de volta desorienta.
- **Variações de cena pelo estado** quando a variação cabe no rádio. Cada variação de imagem custa uma cena inteira.

---

## Exercício

**Parte 1 — o ator (2 h).** Implemente `UVGCinematicSubsystem` e `AVGCinematicActor`, os módulos no `Build.cs`, `IA_Pular` com o gatilho *Hold* no `IMC_Cinematica` e a ligação no controller.

**Parte 2 — as cenas (2 h).** Monte `LS_SustoCorredor`, `LS_FinalTurnoDaNoite` e `LS_FimCapitulo1` e os três atores do Projeto 6. No susto, use a trilha de evento para o flicker e "restaurar estado" nas luzes. Na final, use a trilha de evento no frame em que a câmera chega à janela.

**Parte 3 — os cenários (1 h).** Verifique no PIE, com `vg.Debug.Dialogue`, `vg.Debug.Quests` e `vg.Debug.Narrative` ligados:
- a cena final até o fim: a fala toca uma vez e a quest conclui;
- pular **antes** do frame 135: a fala toca depois da cena e a quest conclui;
- pular **depois** do frame 135: a fala não se repete;
- `VGKillPlayer` (ou o cheat de dano do Cap. 22) no meio do susto: as luzes voltam ao normal e nada fica preso no modo de input;
- recarregar o nível no meio da cena final: a pilha de modos volta limpa (`VGDumpInputModes`).

**Parte 4 — direção (1 h).** Ajuste o último enquadramento da cena final para coincidir com o ponto de vista de Helena diante da janela. Peça a alguém que jogue e pergunte se "percebeu quando a cena acabou". Registre no `DEVLOG.md`.

---

## Desafio — o setor 2 começa em cena

Desenhe a **abertura do setor 2** (a Subestação) como um evento roteirizado **com controle**, no espírito das transições de GTA V: a jogadora sai da Casa de Força e, sem corte, o rádio de Sônia, a câmera e a luz conduzem os primeiros vinte segundos até a entrada da Subestação.

1. Que parte é Sequencer (apresentação) e que parte é sistema (rádio, quest, fatos)?
2. O que acontece se a jogadora **sair do caminho** no meio? (Cancelar? Pausar a cena? Deixar o rádio continuar?)
3. Implemente uma versão em grey-box e escreva no `DEVLOG.md` o que você aprendeu sobre cenas que não tiram o controle.

---

## Uso de IA

1. **Para revisar uma cena como estado:**
   > "Aqui está a descrição de uma cinemática de jogo (trilhas, eventos, o que ela muda no mundo e na história) e o código do ator que a toca. Liste cada efeito e classifique como apresentação ou estado. Para cada efeito de estado, diga o que acontece se a cena for pulada antes dele, cancelada no meio, ou se o nível for descarregado durante a cena. [descrição + código]"

2. **Para direção de câmera:**
   > "Descreva, plano a plano, uma cinemática de 12 segundos para um jogo de terror em primeira pessoa: a jogadora liga os painéis de uma sala de controle de 1994 e vê, pela janela, uma turbina enorme começar a girar sozinha. A cena precisa terminar no ponto de vista dela, olhando pela janela. Indique duração, enquadramento e movimento de cada plano, e onde entra o rádio."

3. **Para revisar o código de ciclo de vida:**
   > "Revise este ator de cinemática da Unreal Engine 5 (subclasse de ALevelSequenceActor). Procure: recursos adquiridos e não liberados em algum caminho (input mode, travas), efeitos aplicados duas vezes ou nenhuma, ordem entre Stop/OnFinished e a lógica de término, e inscrições em delegates que sobrevivem ao ator. [código]"

**Cuidado específico:** a IA conhece bem a linguagem de cinema e mal as particularidades do Sequencer em cada versão da Unreal (nomes de opções, onde fica "manter estado", como saltar posição com ou sem eventos). Use-a para a direção e para a revisão de lógica; para a API, confira na documentação da sua versão.

---

## Checklist

- [ ] Sei escolher a forma de uma cena pelo controle que ela tira e pelo custo.
- [ ] Sei usar o Sequencer: trilhas, *possessables* e *spawnables*, câmeras, eventos, manter e restaurar estado.
- [ ] Sei projetar a entrada e a saída de uma cena (input, Diretor, câmera, estado).
- [ ] Sei por que "pular" não é "parar" e onde moram os efeitos de estado.
- [ ] Implementei o ator de cinemática com `Finish` único, pular por *hold* e cancelamento por morte.
- [ ] O *Turno da Noite* não tem mais cola narrativa no Level Blueprint.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Sequencer** (visão geral, trilhas de evento, *possessables* e *spawnables*, configurações de reprodução) e **Cinematics and Movie Making**.
- **GDC Vault** (gdcvault.com): palestras sobre cinemáticas *in-engine* e transições entre jogo e cena, incluindo apresentações de desenvolvedores da Remedy sobre Quantum Break (confira os títulos lá).

---

## Estado do Livro (fim da Parte VI)

- **Capítulos concluídos:** Introdução; Caps. 1–49 (Partes I–VI); Interlúdio I.
- **Projetos:** 1 (Pátio), 2 (Galpão), 3 (Interação), 4 (Turno da Noite, ingênuo), 5 (IA) e **6 (sistema narrativo: o Turno da Noite refatorado)**, todos concluídos.
- **Conceitos consolidados na Parte VI:**
  - narrative design, embutida × emergente, livro-razão;
  - diálogo como dados e canal de rádio;
  - quests como dados e fila de trabalho;
  - estado narrativo como dono único com snapshot;
  - ramificação com orçamento e auditoria;
  - narrativa ambiental e documentos lidos de fato;
  - cinemáticas com estado no código.
- **Ponto de continuação:** Parte VII, Capítulo 50 — Level Design.

---

➡️ **Próximo:** [Parte VII — Capítulo 50: Level Design](../parte-07/cap-50-level-design.md)

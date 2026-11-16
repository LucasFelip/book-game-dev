# Capítulo 24 — Events e comunicação

## Objetivo

Ao final deste capítulo você deve conseguir:

- posicionar cada mecanismo de comunicação da Unreal num **espectro de acoplamento**: chamada direta, interface, delegate, barramento global, consulta;
- conhecer os **tipos de delegate** (simples, multicast, dinâmicos, eventos), seus custos e suas regras de ciclo de vida, e escolher o certo;
- decidir **quem conhece quem** em cada relação entre sistemas, e reconhecer quando um barramento global vale a pena;
- implementar um **barramento de eventos de gameplay** mínimo, com canais por Gameplay Tag, proteção contra recursão e log de depuração;
- usar o barramento para conectar sistemas que não devem se conhecer (pickups, portas, setores → narrativa e notificações);
- consolidar a Parte III e o estado dos Projetos 2 e 3.

---

## Contexto

Ao longo da Parte III, os sistemas da Vigília foram ligados de várias formas: a porta se inscreve no disjuntor; os postes se inscrevem no alarme; a interação chama a interface do alvo; a HUD lê a munição; o controller recebe a morte do corpo; a zona segura concede tags. Cada ligação foi escolhida caso a caso, com uma justificativa local.

Este capítulo dá nome ao que foi feito e completa o quadro. A pergunta central é a mais antiga da arquitetura de software, e você a conhece bem: **quem conhece quem?** Em sistemas distribuídos, ela se responde com contratos de API, tópicos de mensageria e coreografia vs. orquestração. Dentro de um jogo, as ferramentas são outras — mais rápidas, síncronas, sem rede —, mas o critério é o mesmo: **acoplamento é um custo; desacoplamento também é.**

---

## 24.1 O espectro de acoplamento

```text
 MAIS ACOPLADO                                                        MENOS ACOPLADO
 ───────────────────────────────────────────────────────────────────────────────────►
 Chamada direta      Interface         Delegate            Barramento global     Consulta
 A conhece a         A conhece um      B conhece A         ninguém conhece       ninguém
 CLASSE de B         CONTRATO que      (se inscreve);      ninguém; ambos        avisa ninguém;
                     B implementa      A não conhece B     conhecem o canal      quem precisa, lê
 ─────────────────   ─────────────     ─────────────────   ───────────────────   ───────────────
 Porta.Unlock()      Execute_Interact  Disjuntor.OnToggled Event.Item.Collected  GetChargeRatio()
 (do disjuntor)      (interação→alvo)  (porta se inscreve) (pickup→narrativa)    (HUD → bateria)
```

Cada ponto tem um custo diferente:

| Mecanismo | Rastreabilidade ("quem chama isto?") | Flexibilidade | Custo de runtime | Risco típico |
|---|---|---|---|---|
| **Chamada direta** | Excelente (IDE encontra) | Baixa | Mínimo | Teia de dependências; ciclos |
| **Interface** | Boa | Alta para "muitos tipos, uma operação" | Baixo (Execute_ via reflexão) | Interfaces grandes demais |
| **Delegate** | Média (quem se inscreveu?) | Alta para "um emissor, vários ouvintes" | Baixo (dinâmico: um pouco maior) | Inscrições esquecidas; ordem; reentrância |
| **Barramento global** | Baixa (fluxo implícito) | Máxima para "muitos para muitos" | Baixo a médio | Fluxo invisível; eventos "para ninguém" |
| **Consulta** | Excelente | — | Proporcional a leitores × frequência | Polling caro se mal dimensionado |

A regra que vem dessa tabela: **use o mecanismo mais acoplado que ainda for adequado.** Desacoplar tem custo — principalmente de **rastreabilidade**. Quando um bug aparece ("a porta abriu sozinha"), uma chamada direta se encontra em segundos; um evento num barramento global pode ter vindo de qualquer lugar.

> 🌉 **Ponte:** é a discussão de **orquestração vs. coreografia** em microsserviços. Orquestração (chamadas diretas, um coordenador) é rastreável e rígida; coreografia (eventos num broker) é flexível e opaca. A maturidade está em escolher por relação, não por dogma.
>
> 🧱 **Onde a ponte cai:** num broker real, eventos são duráveis, assíncronos e entregues a processos isolados. Aqui, tudo é **síncrono, no mesmo frame, na mesma thread** (Capítulo 4, seção 4.5). Um "barramento" de gameplay é, na prática, uma lista de funções chamadas em sequência — com todas as consequências de ordem e reentrância.

---

## 24.2 Delegates na Unreal

A Unreal tem várias famílias de delegate. Você já usou duas (dinâmicos multicast, em quase todo capítulo da Parte III; e delegates de timer). O quadro completo:

| Família | Macro | Ouvintes | Visível em Blueprint | Como inscrever | Observação |
|---|---|:-:|:-:|---|---|
| **Simples** | `DECLARE_DELEGATE_*` | 1 | ✗ | `BindUObject`, `BindLambda`, `BindSP`, `BindRaw`, `BindStatic` | Pode ter valor de retorno (`DECLARE_DELEGATE_RetVal_*`) |
| **Multicast** | `DECLARE_MULTICAST_DELEGATE_*` | N | ✗ | `AddUObject`, `AddLambda`, `AddWeakLambda`, `AddSP`, `AddRaw` → devolve `FDelegateHandle` | Rápido; remoção por handle ou por objeto |
| **Dinâmico simples** | `DECLARE_DYNAMIC_DELEGATE_*` | 1 | ✓ | `BindDynamic` (exige `UFUNCTION`) | Serializável; usado como parâmetro de funções Blueprint |
| **Dinâmico multicast** | `DECLARE_DYNAMIC_MULTICAST_DELEGATE_*` | N | ✓ (`BlueprintAssignable`) | `AddDynamic` (exige `UFUNCTION`) | Mais lento (resolução por nome via reflexão); ouvintes `UObject` são referências fracas |
| **Evento** | `DECLARE_EVENT_*` | N | ✗ | Como multicast | Só a classe dona pode disparar (`Broadcast`) |

### Como escolher

```text
Blueprint precisa se inscrever?
   SIM → dinâmico multicast (BlueprintAssignable)
   NÃO ↓
O evento dispara com muita frequência (muitas vezes por frame) ou em sistemas de baixo nível?
   SIM → multicast nativo (AddUObject / AddWeakLambda)
   NÃO → qualquer um; prefira o dinâmico se houver chance de Blueprint precisar no futuro
```

Para eventos de gameplay da Vigília (porta mudou de estado, bateria ficou fraca, alvo morreu), que disparam poucas vezes por segundo, o custo extra dos dinâmicos é irrelevante — e a capacidade de o conteúdo reagir em Blueprint vale muito. Por isso a Parte III usou dinâmicos quase sempre.

### Ciclo de vida das inscrições

A segurança de uma inscrição depende de **como** ela foi feita:

| Forma de inscrição | Se o ouvinte for destruído... |
|---|---|
| `AddDynamic` / `AddUObject` / `AddWeakLambda(this, ...)` | A engine detecta (referência fraca ao `UObject`) e ignora a chamada |
| `AddSP` (ponteiro compartilhado) | Detecta se o objeto compartilhado deixou de existir |
| `AddLambda` capturando `this` | **Não detecta** — chamada sobre memória inválida: crash |
| `AddRaw` | **Não detecta** — crash |

Mesmo nos casos seguros, **desinscrever explicitamente** no `EndPlay` continua sendo a regra (Capítulo 4, risco 3): um ouvinte ainda vivo mas que "não deveria mais reagir" — um ator desativado, um widget escondido — não é detectado por nenhuma referência fraca.

---

## 24.3 Quem conhece quem na Vigília

Um mapa das relações que já existem, com a justificativa de cada direção:

| Relação | Mecanismo | Quem conhece quem | Por quê |
|---|---|---|---|
| Interação → alvo | Interface (`IVGInteractable`) | Sistema conhece o **contrato** | Muitos tipos, mesma operação; resposta síncrona necessária |
| Porta → disjuntor | Delegate (`OnToggled`) | Porta conhece o disjuntor | Relação local, configurada no nível; o disjuntor não deve conhecer quem depende dele |
| Postes → alarme | Delegate (`OnAlarmStartedEvent`) | Postes conhecem o alarme (classe C++) | Idem |
| Corpo → controller (morte) | Chamada direta (`HandlePawnDied`) | Corpo conhece o controller | Relação 1-para-1, estável e definida pelo framework |
| Controller → GameMode | Chamada direta (`RestartPlayer`) | Controller conhece o GameMode | Relação definida pelo framework |
| HUD → bateria, vida, munição | Consulta + delegates de transição | HUD conhece os componentes | Contínuo → consulta; transições → eventos (Capítulo 4) |
| Zona segura → jogadora | Componente de tags (`GrantStatus`) | Zona conhece o **componente de tags** | Qualquer ator com tags; contrato uniforme |
| Qualquer sistema → "é a jogadora?" | Tags (`IGameplayTagAssetInterface`) | Ninguém conhece a classe da jogadora | Identidade consultada por muitos |

Agora, as relações que **ainda não existem** e que os próximos capítulos vão exigir:

- **Qualquer coisa → narrativa.** "A jogadora pegou o livro de ocorrências", "abriu a porta da sala de controle pela primeira vez", "o setor B foi energizado", "morreu pela primeira vez". As **fontes** são dezenas de objetos diferentes, espalhados por níveis; o **consumidor** é um sistema narrativo (Parte VI). Fazer cada objeto conhecer o sistema narrativo é um acoplamento muitos-para-um que transforma todo interativo num "objeto narrativo".
- **Qualquer coisa → notificações da UI.** "Bateria coletada", "Nova anotação no diário".
- **Qualquer coisa → telemetria de design** (o desafio do Capítulo 21).

São relações **muitos-para-muitos** em que **nenhum dos lados tem uma referência natural para o outro**. É exatamente o caso em que um **barramento** se justifica.

---

## 24.4 Um barramento de eventos de gameplay

O desenho mínimo:

```text
                   UVGGameplayEventSubsystem  (UWorldSubsystem)
   publicadores                    │                           ouvintes
   ────────────                    │                           ────────
   AVGPickup  ── Event.Item.Collected ──┐               ┌──► narrativa (Parte VI)
   AVGDoor    ── Event.Door.Opened ─────┼──► Broadcast ─┼──► notificações (UI)
   AVGSector  ── Event.Sector.Powered ──┤               ├──► telemetria (Cap. 21)
   AVGCharacter ─ Event.Player.Died ────┘               └──► áudio / música (Cap. 52)
                                  cada ouvinte filtra pelos canais (tags) que interessam
```

⚠️ O `AVGSector` nasceu como **desafio** do Capítulo 23. A partir daqui ele é **parte do projeto**: este capítulo o faz publicar `Event.Sector.Powered`, e os objetivos do Capítulo 31 dependem desse evento. Se você pulou o desafio, faça-o agora. A versão mínima é um ator com referência ao disjuntor principal e às zonas seguras do setor, que no `OnToggled` concede `World.Sector.Powered` a si mesmo e publica o evento com a tag do setor como contexto.

Escolhas de desenho:

- **Canais são Gameplay Tags** (`Event.Item.Collected`). Isso dá hierarquia de graça: um ouvinte interessado em `Event.Item` recebe todos os eventos de itens.
- **O evento é uma struct pequena e genérica**: o canal, quem causou (*instigator*), sobre o que é (*target*), uma magnitude e, opcionalmente, uma tag de contexto (por exemplo, **qual** item: `Item.Key.Substation`). Nada de herança de tipos de evento: o barramento é deliberadamente "burro".
- **Escopo de mundo** (`UWorldSubsystem`): eventos são do nível atual. Fatos que precisam sobreviver à troca de nível são responsabilidade de quem os **consome** (o sistema narrativo grava; o barramento não guarda nada).
- **Síncrono.** O broadcast chama os ouvintes imediatamente. Para evitar recursões descontroladas (um ouvinte que publica um evento que dispara o mesmo ouvinte...), há um limite de profundidade com `ensure`.
- **Observável.** Uma CVar (`vg.Debug.Events`) registra todo evento publicado no log — o equivalente a ligar o *tracing* de um sistema distribuído.

> **Atenção à tentação:** o barramento é a ferramenta **menos rastreável** do espectro. Ele **não** substitui as relações locais que já existem (a porta continua escutando o disjuntor diretamente). Ele existe para relações muitos-para-muitos sem referência natural. Se você se pegar publicando no barramento um evento que tem **um único** ouvinte conhecido, use um delegate.

> **Referência:** a Epic usa um padrão parecido na Lyra — um *Gameplay Message Router*, distribuído como plugin junto com o projeto de exemplo — com canais por Gameplay Tag e mensagens tipadas por struct. O barramento da Vigília é uma versão mínima da mesma ideia.

---

## Estudo de caso: PES/FIFA — a partida como fluxo de eventos

> **Pergunta:** como um jogo de futebol consegue que comentários, torcida, câmera e replays reajam ao que acontece em campo de forma coerente?

**[FATO PÚBLICO]** Jogos de futebol como as séries PES/eFootball e FIFA/EA Sports FC têm **narração e comentários** que reagem aos lances da partida (gols, faltas, defesas, chances perdidas, cartões), **sons de torcida** que variam com a intensidade do jogo, e **replays** automáticos de lances importantes. A narração é tradicionalmente gravada por locutores reais em vários idiomas — inclusive em português, com narradores e comentaristas brasileiros em diferentes edições.

**[INFERÊNCIA]** O comportamento é compatível com uma arquitetura em que a **simulação da partida publica eventos** de domínio — "chute a gol", "defesa do goleiro", "falta", "gol", "bola na trave" — e **vários sistemas independentes os consomem**:

```text
                 SIMULAÇÃO DA PARTIDA (física, regras, IA)
                                │ publica eventos
            ┌───────────────────┼───────────────────┬─────────────────────┐
            ▼                   ▼                   ▼                     ▼
     NARRAÇÃO              TORCIDA (áudio)       CÂMERA / REPLAY       ESTATÍSTICAS
  escolhe uma fala      intensidade, cantos,   marca o lance para    chutes, posse,
  adequada ao evento,   vaias, "uhhh"          replay; corta para    faltas
  ao contexto (placar,                         ângulos dramáticos
  minuto) e evita
  repetir
```

A narração é um exemplo especialmente interessante: ela precisa reagir **depressa** (um comentário sobre um gol que chega cinco segundos depois soa errado), considerar **contexto** (um gol aos 45 do segundo tempo num empate é diferente de um gol aos 10 minutos numa goleada) e **variar** (o jogador percebe repetição rapidamente). Nenhum desses requisitos exige que a simulação conheça a narração. Nenhuma afirmação é feita aqui sobre como esses jogos são implementados.

**[SIMPLIFICAÇÃO DIDÁTICA]** O barramento deste capítulo é o esqueleto dessa arquitetura: a "partida" da Vigília (a jogadora explorando a usina) publica eventos; narrativa, UI, áudio e telemetria consomem. No Capítulo 44, a operadora no rádio vai reagir a eventos exatamente como um narrador de futebol: escolhendo falas por evento e contexto, e evitando repetição.

**Lição:** **quando muitos sistemas de apresentação precisam reagir ao mesmo fluxo de acontecimentos, publique o fluxo uma vez e deixe cada sistema interpretar.** A simulação fica livre de conhecer quem a observa — e a experiência ganha camadas (narração, torcida, câmera) sem que o núcleo mude.

---

## Comparação com o desenvolvimento tradicional

| Mecanismo na Unreal | O que você conhece | Onde a analogia cai |
|---|---|---|
| Chamada direta / interface | Chamada de serviço / porta hexagonal | Sem latência, sem falha parcial |
| Delegate | Observer / listener in-process | Síncrono; ouvintes `UObject` com referência fraca |
| Barramento de eventos | Event bus / broker com tópicos | Síncrono, sem durabilidade, sem entrega garantida a "assinantes futuros" |
| Canais por Gameplay Tag | Tópicos hierárquicos (wildcards) | A hierarquia é validada no registro de tags |
| `vg.Debug.Events` | Tracing distribuído | Mesmo processo, mesmo frame: o log é a "trace" |
| Limite de profundidade | Proteção contra loops de mensagens | O "loop" acontece na mesma pilha de chamadas |

---

## Implementação

### 1. Os canais

Em `VGGameplayTags.h/.cpp`, novas tags nativas sob a raiz `Event` (registre a raiz no `docs/design/tags.md`):

```cpp
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Item_Collected);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Door_Opened);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Sector_Powered);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Player_Died);
```

```cpp
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Item_Collected, "Event.Item.Collected");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Door_Opened,    "Event.Door.Opened");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Sector_Powered, "Event.Sector.Powered");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Player_Died,    "Event.Player.Died");
```

### 2. O subsistema

```cpp
// Source/Vigilia/Core/VGGameplayEventSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGGameplayEventSubsystem.generated.h"

/** Um acontecimento de gameplay. Genérico de propósito: o canal diz o que é. */
USTRUCT(BlueprintType)
struct FVGGameplayEvent
{
    GENERATED_BODY()

    /** Canal (ex.: Event.Item.Collected). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Event")
    FGameplayTag Channel;

    /** Quem causou (ex.: a jogadora). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Event")
    TObjectPtr<AActor> Instigator;

    /** Sobre o que é (ex.: o pickup, a porta). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Event")
    TObjectPtr<AActor> Target;

    /** Detalhe opcional (ex.: qual item — Item.Key.Substation). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Event")
    FGameplayTag Context;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Event")
    float Magnitude = 0.0f;
};

DECLARE_MULTICAST_DELEGATE_OneParam(FVGGameplayEventNativeSignature, const FVGGameplayEvent&);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGGameplayEventSignature, const FVGGameplayEvent&, Event);

/**
 * Barramento de eventos de gameplay do mundo: para relações muitos-para-muitos sem referência
 * natural (fontes → narrativa, UI, telemetria). Síncrono. Não substitui delegates locais.
 * Simplificação: ouvintes recebem todos os eventos e filtram pelo canal. Se houver muitos
 * ouvintes e muitos eventos por frame, trocar por canais indexados por tag.
 */
UCLASS()
class VIGILIA_API UVGGameplayEventSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Events")
    void Publish(const FVGGameplayEvent& Event);

    /** Para ouvintes C++ (mais barato; use AddUObject/AddWeakLambda). */
    FVGGameplayEventNativeSignature OnEventNative;

    /** Para ouvintes Blueprint. */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Events")
    FVGGameplayEventSignature OnEvent;

    /** Atalho para publicar a partir de qualquer objeto com mundo. */
    static void PublishFrom(const UObject* WorldContext, FGameplayTag Channel, AActor* Instigator,
                            AActor* Target, FGameplayTag Context = FGameplayTag(), float Magnitude = 0.0f);

private:
    int32 PublishDepth = 0;
};
```

```cpp
// Source/Vigilia/Core/VGGameplayEventSubsystem.cpp
#include "Core/VGGameplayEventSubsystem.h"

#include "Core/VGLog.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "HAL/IConsoleManager.h"

static TAutoConsoleVariable<bool> CVarVGDebugEvents(
    TEXT("vg.Debug.Events"),
    false,
    TEXT("Registra no log todo evento publicado no barramento de gameplay."),
    ECVF_Default);

static constexpr int32 MaxPublishDepth = 8;

void UVGGameplayEventSubsystem::Publish(const FVGGameplayEvent& Event)
{
    if (!ensureMsgf(Event.Channel.IsValid(), TEXT("Evento publicado sem canal.")))
    {
        return;
    }
    // Ouvintes podem publicar outros eventos (síncrono); limitamos a cadeia.
    if (!ensureMsgf(PublishDepth < MaxPublishDepth,
                    TEXT("Profundidade de eventos excedida ao publicar %s: provável ciclo."),
                    *Event.Channel.ToString()))
    {
        return;
    }

    if (CVarVGDebugEvents.GetValueOnGameThread())
    {
        const FString Indent = FString::ChrN(PublishDepth * 2, TEXT(' '));
        UE_LOG(LogVigilia, Display, TEXT("[Event]%s %s  instigator=%s  target=%s  context=%s  mag=%.2f"),
            *Indent, *Event.Channel.ToString(), *GetNameSafe(Event.Instigator),
            *GetNameSafe(Event.Target), *Event.Context.ToString(), Event.Magnitude);
    }

    ++PublishDepth;
    OnEventNative.Broadcast(Event);
    OnEvent.Broadcast(Event);
    --PublishDepth;
}

void UVGGameplayEventSubsystem::PublishFrom(const UObject* WorldContext, FGameplayTag Channel, AActor* Instigator,
                                            AActor* Target, FGameplayTag Context, float Magnitude)
{
    const UWorld* World = GEngine->GetWorldFromContextObject(WorldContext, EGetWorldErrorMode::ReturnNull);
    UVGGameplayEventSubsystem* Bus = World ? World->GetSubsystem<UVGGameplayEventSubsystem>() : nullptr;
    if (!Bus)
    {
        return;
    }
    FVGGameplayEvent Event;
    Event.Channel = Channel;
    Event.Instigator = Instigator;
    Event.Target = Target;
    Event.Context = Context;
    Event.Magnitude = Magnitude;
    Bus->Publish(Event);
}
```

### Explicação das decisões

- **Dois delegates**: nativo para ouvintes C++ (mais barato, com `AddUObject`/`AddWeakLambda`) e dinâmico para Blueprint. Os dois recebem os mesmos eventos. É a recomendação da seção 24.2 aplicada a um único emissor com dois públicos.
- **Struct genérica**, sem herança de tipos de evento. O canal (tag) diz o que é; `Context` carrega o "qual". É pouco expressivo de propósito: um barramento que aceita qualquer struct vira um segundo sistema de tipos para manter.
- **Profundidade limitada com `ensure`**: ciclos de eventos síncronos são bugs; o `ensure` mostra o canal e a pilha, sem derrubar o editor.
- **Log com indentação por profundidade**: a saída de `vg.Debug.Events 1` mostra **causalidade** — um evento publicado dentro de outro aparece indentado. É o "trace" da comunicação.
- **`PublishFrom` estático**: publicar é uma linha em qualquer lugar com contexto de mundo.

### 3. Publicando

🔁 **Pequenas refatorações** em classes existentes, cada uma com uma linha:

```cpp
// AVGPickup::Interact_Implementation — depois de consumir:
UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Item_Collected, Interactor, this, ItemTag);
// (AVGPickup ganha uma propriedade editável FGameplayTag ItemTag, com meta = (Categories = "Item"))

// AVGDoor::TransitionTo — ao chegar em Open pela PRIMEIRA vez:
if (NewState == EVGDoorState::Open && !bHasEverOpened)
{
    bHasEverOpened = true;
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Door_Opened, nullptr, this, DoorTag);
}

// AVGCharacter::HandleDied:
UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Player_Died, Report.Causer, this);
```

Repare que a porta publica **"aberta pela primeira vez"**, não cada abertura: o barramento é para **fatos de gameplay** que interessam a sistemas distantes, não para cada mudança de estado — essas continuam no `OnDoorStateChanged`, para quem tem referência à porta.

### 4. Consumindo: notificações na tela

Um consumidor simples e útil: um widget de notificações (`WBP_Notificacoes`, criado pelo `BP_VGPlayerController`) que se inscreve em `OnEvent` e, para `Event.Item.Collected`, mostra por 2 s uma linha como "Bateria coletada" — escolhendo o texto por `Context` numa tabela simples (um `TMap<FGameplayTag, FText>` no próprio widget, por enquanto). O pickup não sabe que existe UI; a UI não sabe que existem pickups.

---

## Fechamento da Parte III

A Parte III transformou a engine em gameplay:

```text
Cap. 16  PlayerController: vontade persistente, view targets, pilha de modos, cheats.
Cap. 17  Character: vetores, CMC, correr e agachar, passos por distância e superfície.
Cap. 18  Camera: camera manager, modificadores, shakes, rotações, FOV, acessibilidade.
Cap. 19  Interaction: quatro arquiteturas comparadas; interface + eventos; porta, disjuntor, pickups.
Cap. 20  Weapons: dados/estado/comportamento/apresentação; cadência por acumulador; munição.
Cap. 21  Combat: TTK/TTD, telegrafia, economia; a Presença é invencível; simulador.
Cap. 22  Health/Damage: pipeline de dano, morte única, regeneração, a morte como fluxo.
Cap. 23  Gameplay State: mapa de estado; Gameplay Tags; status com contagem; zonas seguras.
Cap. 24  Events: espectro de acoplamento, delegates, quem conhece quem, barramento de eventos.
```

### Estado dos projetos

- **Projeto 3 (Interação): concluído.** Portas com estados, disjuntores com energia, pickups, chaves por tag, prompt contextual, destaque genérico, interativos em Blueprint puro.
- **Projeto 2 (FPS básico): em andamento.** O Galpão de Testes tem pistola, fuzil e sinalizador com cadência correta, munição, recarga, dano e alvos com vida e resistências. Falta, na Parte IV: o movimento afinado de FPS, sistema de armas com inventário e mira, hitscan completo, projéteis, recoil, um inimigo simples, objetivos e spawn.

### Critérios de verificação da Parte III

- [ ] A jogadora anda, corre, agacha, pula, olha e interage; a câmera tem balanço e tremores acessíveis.
- [ ] A porta do Galpão exige energia; o disjuntor energiza o setor, ativa a zona segura e dispara o alarme.
- [ ] A chave da subestação abre a porta da subestação.
- [ ] As armas disparam na cadência correta em qualquer frame rate; os alvos morrem, tombam e reaparecem.
- [ ] A jogadora morre num volume de dano, vê o próprio corpo, e renasce ao "continuar".
- [ ] `vg.Debug.Events 1` mostra, no log, cada item coletado, primeira abertura de porta e morte.
- [ ] Nenhum sistema faz `Cast<AVGCharacter>` para descobrir se algo é a jogadora (use tags).

---

## Decisões arquiteturais

1. **O mecanismo mais acoplado que ainda for adequado.** Desacoplamento custa rastreabilidade.
2. **Delegates dinâmicos para eventos de gameplay com público em Blueprint; nativos para alta frequência ou só C++.**
3. **Inscrições seguras** (`AddDynamic`, `AddUObject`, `AddWeakLambda`); nunca `AddLambda` capturando `this` nem `AddRaw` em gameplay; desinscrição explícita no `EndPlay`.
4. **Relações locais por delegate** (consumidor conhece o produtor); **muitos-para-muitos sem referência natural pelo barramento**.
5. **`UVGGameplayEventSubsystem`**: canais por tag, evento genérico, síncrono, profundidade limitada, observável por `vg.Debug.Events`.
6. **O barramento transporta fatos de gameplay**, não cada mudança de estado.
7. **O barramento não guarda nada**: quem precisa lembrar (narrativa) grava.

---

## Armadilhas

- **Barramento para tudo** — fluxo invisível e bugs impossíveis de rastrear.
- **Eventos com um único ouvinte conhecido** publicados no barramento.
- **`AddLambda` capturando `this`** em objetos que podem ser destruídos.
- **Ciclos de eventos síncronos.**
- **Structs de evento que crescem** até virar um sistema de tipos paralelo.
- **Esquecer que o barramento é por mundo** e esperar que eventos sobrevivam à troca de nível.
- **Publicar cada mudança de estado** como fato global.

---

## Exercício

**Parte 1 — o barramento (1,5 h).** Implemente as tags de evento, o subsistema e as publicações em pickups, portas e morte. Ligue `vg.Debug.Events 1` e jogue cinco minutos. Leia o log como se fosse um trace de produção: ele conta a história da sessão?

**Parte 2 — notificações (1 h).** Implemente o `WBP_Notificacoes` consumindo `OnEvent`. Adicione um segundo consumidor, em C++, que conte eventos por canal (com `OnEventNative.AddUObject`) e expõe a contagem num cheat `VGDumpEventStats`.

**Parte 3 — mapa de comunicação (45 min).** Atualize a tabela "quem conhece quem" (seção 24.3) com todas as relações do projeto. Para cada uma, verifique: é o mecanismo mais acoplado adequado? Alguma deveria mudar?

**Parte 4 — ciclo proposital (20 min).** Crie um ouvinte de teste que, ao receber `Event.Door.Opened`, publica `Event.Door.Opened` de novo. Observe o `ensure` e a indentação no log. Remova o teste.

---

## Desafio — telemetria de design

Use o barramento para implementar a **telemetria de design** planejada no desafio do Capítulo 21:

1. Um `UVGTelemetrySubsystem` (de `GameInstance`, para atravessar níveis) que se inscreve no barramento de cada mundo carregado e grava, para cada evento, `(tempo desde o início da sessão, canal, contexto, posição do instigador)`.
2. Ao final da sessão (ou por cheat), grava um arquivo CSV em `Saved/Telemetry/`.
3. Adicione aos eventos existentes os que forem úteis para o playtest da Vigília: entrou numa zona segura, perdeu a zona segura, bateria entrou em `Low`, usou o sinalizador.

Abra o CSV numa planilha depois de uma sessão de teste e responda: quanto tempo a jogadora passou fora de zonas seguras? Onde ela morreu? Quantas baterias encontrou antes da primeira vez que ficou sem luz? Você acabou de construir uma ferramenta de observabilidade **de experiência** — o equivalente ao seu dashboard de produção, apontado para o jogador.

---

## Uso de IA

1. **Para revisar a comunicação:**
   > "Aqui está a lista de relações de comunicação entre sistemas de um jogo em Unreal Engine 5 (emissor, receptor, mecanismo). Para cada uma, avalie se o mecanismo é o mais acoplado ainda adequado, aponte riscos de ciclo de vida (inscrições sem remoção, lambdas capturando this) e sugira mudanças apenas onde houver ganho claro. [tabela]"

2. **Para escolher delegates:**
   > "Explique as diferenças entre DECLARE_DELEGATE, DECLARE_MULTICAST_DELEGATE, DECLARE_DYNAMIC_DELEGATE, DECLARE_DYNAMIC_MULTICAST_DELEGATE e DECLARE_EVENT na Unreal Engine 5: custo, visibilidade em Blueprint, formas de inscrição, segurança quando o ouvinte é destruído e casos de uso. Dê um exemplo de quando cada uma é a escolha certa num jogo."

3. **Para pensar em eventos como design:**
   > "Num jogo narrativo de terror, liste 15 eventos de gameplay que um sistema de narração (uma voz no rádio) poderia usar para comentar a experiência da jogadora, como um narrador de futebol comenta uma partida. Para cada um, diga o contexto que a fala deveria considerar e como evitar repetição."

---

## Checklist

- [ ] Sei posicionar cada mecanismo no espectro de acoplamento e escolher o mais acoplado adequado.
- [ ] Conheço as famílias de delegate, seus custos e regras de ciclo de vida.
- [ ] Tenho o mapa "quem conhece quem" do projeto, com justificativas.
- [ ] Implementei o barramento de eventos com canais por tag, profundidade limitada e log.
- [ ] Publico fatos de gameplay (não cada mudança de estado) e consumo em UI sem acoplamento.
- [ ] Os critérios de verificação da Parte III estão cumpridos.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Delegates** (incluindo multicast, dinâmicos e eventos).
- **Lyra Starter Game** — o plugin *Gameplay Message Router* (mensagens por canal de Gameplay Tag), para comparar com o barramento da Vigília.
- **Robert Nystrom, *Game Programming Patterns*** — releia **"Observer"** e **"Event Queue"**, agora com o barramento implementado.

---

➡️ **Próximo:** [Parte IV — Capítulo 25: FPS Controller](../parte-04/cap-25-fps-controller.md)

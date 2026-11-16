# Capítulo 45 — Quest Systems

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que uma **quest** é do ponto de vista da engenharia: um processo de longa duração, guiado por eventos, que coordena objetivos, condições e consequências;
- modelar quests como **dados** (etapas, objetivos obrigatórios e opcionais, condições, transições, ações) sem um mar de `if/else`;
- distinguir **ordem obrigatória** (etapas) de **ordem livre** (objetivos paralelos) e usar cada uma para o que ela serve;
- entender por que **eventos são o momento e fatos são a memória**, e o que isso muda em objetivos que "perdem" eventos;
- implementar **ações configuráveis** (conceder fato, pedir conversa, iniciar quest, publicar sinal) como objetos instanciados dentro do asset;
- processar o progresso de quests numa **fila de trabalho**, fora de qualquer notificação, evitando a reentrância que derruba sistemas orientados a eventos;
- migrar a sequência do *Turno da Noite* do Level Blueprint para uma quest, resolvendo as dores 5 e 7 do Interlúdio I.

---

## Contexto

O Capítulo 31 construiu **objetivos**: unidades que ouvem o barramento e sabem se concluíram ("pegue 3 baterias", "sobreviva 60 segundos"). E deixou uma frase escrita no comentário do subsistema: *"Quem decide quais objetivos ativar e o que acontece depois é o controlador."* No *Turno da Noite*, esse controlador foi o Level Blueprint, e o inventário de dores registrou o resultado:

- **Dor 5 — ordem de beats não garantida.** A jogadora chega à porta da sala de controle antes de ler o livro: o rádio não fala nada, o objetivo do disjuntor nunca é ativado, e ela fica perdida.
- **Dor 7 — gatilhos que "lembram" errado.** O gatilho do susto precisou de `bTriggerOnce = false` e de uma variável `bSustoArmado` no Level Blueprint, porque "o susto pode acontecer agora" não é estado do gatilho.
- **Dor 12 — o Level Blueprint cresce sem controle.**

O desafio do Capítulo 31 pediu uma lista do que o sistema de objetivos **não** conseguia expressar: condições sobre fatos passados, ramificação, ações ao concluir que dependem do estado, e persistência. Essa lista é o requisito deste capítulo, com uma exceção. A persistência fica para os Capítulos 46 e 56; o resto está aqui.

E o capítulo anterior acrescentou uma pendência: o rádio agora é um sistema, mas **quem decide quando cada conversa é pedida** ainda é o Level Blueprint.

---

## 45.1 O que é uma quest, para um engenheiro

Para a jogadora, uma quest é uma tarefa com um propósito: "descubra o que aconteceu com o turno da noite". Para o sistema, é um **processo de longa duração**: começa em algum momento, avança por etapas em resposta a acontecimentos do mundo, pode ramificar, produz efeitos ao longo do caminho, e termina (com sucesso ou falha) minutos ou horas depois.

```text
 QUEST
 ├── Identidade      tag, título (o que aparece no diário)
 ├── Pré-condição    sobre fatos: quando ela PODE começar
 ├── Etapas          a parte de ordem OBRIGATÓRIA
 │    ├── Objetivos        a parte de ordem LIVRE (paralelos; obrigatórios ou opcionais)
 │    ├── Concluída se     fatos que, por si só, encerram a etapa
 │    ├── Ações            ao entrar, ao concluir cada objetivo, ao concluir a etapa
 │    └── Transições       condicionadas a fatos: a ramificação
 ├── Consequências   ações ao concluir ou falhar a quest (as "recompensas")
 └── Estado          em runtime: etapa atual, progresso, status
```

O enunciado do Projeto 6 (Introdução) pedia exatamente estas peças: *Quest → Objectives, Conditions, Rewards, State*. A diferença está em como elas se combinam: **nenhuma delas é código específico de uma quest**. São dados, interpretados por um sistema genérico pequeno.

> 🌉 **Ponte:** uma quest é uma **saga** (ou *process manager*): uma máquina de estados de longa duração que reage a eventos de domínio, decide o próximo passo e emite comandos. Objetivos são os eventos esperados, ações são os comandos, fatos são o modelo de leitura.
>
> 🧱 **Onde a ponte cai:** uma saga de pedido compensa falhas (estorna, cancela reserva). Uma quest quase nunca desfaz nada: a história não volta atrás. E a "experiência do usuário" de uma saga é invisível, enquanto a de uma quest é o próprio produto. Uma etapa que trava não é um pedido pendente no banco: é uma jogadora parada no escuro sem saber o que fazer.

### Recompensas, na Vigília

Em RPGs, "recompensa" costuma ser experiência, ouro, itens. A Vigília não tem nada disso, e as suas recompensas são de outro tipo:

- **Informação**: um fato narrativo que muda falas, documentos e o final.
- **Acesso**: uma porta energizada, um setor novo.
- **Recursos**: baterias e cartuchos de sinalizador, raros de propósito (Capítulo 21).
- **Alívio**: uma zona segura, um silêncio, a voz de Sônia.

Por isso o sistema não tem um tipo "recompensa". Tem **ações**, e uma recompensa é só uma ação que acontece ao concluir algo.

---

## 45.2 Ordem obrigatória e ordem livre

A dor 5 nasceu de uma decisão implícita do Level Blueprint: o objetivo da porta só existia **depois** do livro. Uma jogadora que explorasse em outra ordem quebrava a sequência.

Há duas ferramentas para ordem, e confundi-las é a origem da maioria dos travamentos em quests:

| Ferramenta | Significa | Use quando |
|---|---|---|
| **Etapas** (sequência) | "B só faz sentido depois de A" | Há uma dependência real de mundo ou de história: a sala só abre com energia; a revelação só faz sentido depois da pista |
| **Objetivos paralelos** (numa etapa) | "A e B, em qualquer ordem" | A ordem é preferência do roteiro, não necessidade: ler o livro e encontrar a porta |

O *Turno da Noite*, redesenhado com essas ferramentas:

```text
 ETAPA "Investigar"          (todos os obrigatórios, em qualquer ordem)
   ├── Encontrar o livro de ocorrências      → fato Logbook.Read; Sônia comenta
   └── Chegar à porta da sala de controle    → Sônia: "não abre sem energia"
                                               (+ "procura o livro", SE ainda não leu)
          │
          ▼
 ETAPA "Disjuntores"         concluída pelo objetivo OU pelo fato BreakersRestored
   └── Religar os disjuntores do subsolo     → Sônia: a pergunta do memorando (Cap. 44)
          │
          ▼
 ETAPA "SalaDeControle"
   └── Entrar na sala de controle
          │
          ▼
 ETAPA "Painel"
   └── Examinar o painel principal (conclui quando a fala final de Sônia termina)
          │
          ▼
 QUEST CONCLUÍDA → fato S1.Completed; sinal S1.ChapterEnd
```

O caso "chegou à porta sem o livro" deixa de ser um buraco: o objetivo da porta está ativo desde o começo, e a fala de Sônia tem uma **variante condicionada** a não ter lido o livro (o mecanismo do Capítulo 44). Nenhum `if` decide nada. A ordem livre está nos dados, e a fala certa sai da condição.

---

## 45.3 Eventos são o momento; fatos são a memória

Há um segundo buraco, mais sutil. O puzzle dos disjuntores fica no subsolo, e nada impede a jogadora de descer **antes** de encontrar o livro e tentar a sequência por tentativa e erro. Se ela acertar durante a etapa "Investigar", o evento `Event.Sector.Powered` é publicado... e **ninguém está ouvindo**: o objetivo dos disjuntores só será ativado na etapa seguinte. Quando a etapa chegar, o evento já passou, e o objetivo espera por algo que nunca vai acontecer de novo.

Esse é o problema central de sistemas guiados por eventos: **um evento só existe para quem estava ouvindo naquele instante**. A solução não é "ouvir tudo desde o começo", porque isso faria cada objetivo virar estado global. A solução é registrar as mudanças importantes como **fatos**, e deixar a etapa perguntar pelo fato:

- O puzzle, ao ser resolvido, **concede o fato** `Narrative.Fact.S1.BreakersRestored` (além de publicar o evento).
- A etapa "Disjuntores" tem uma condição **"concluída se"**: `TEM S1.BreakersRestored`. Ao entrar na etapa, a condição é avaliada; se o fato já existe, a etapa conclui na hora.

O objetivo continua lá, porque é ele que aparece na HUD ("Religue os disjuntores do subsolo") e o que conclui a etapa no caminho normal. O fato cobre o caminho fora de ordem.

> 🌉 **Ponte:** é a diferença entre **evento** e **estado**. Quem consome eventos e chega atrasado perdeu a mensagem; quem consulta uma projeção (o *read model*) vê o resultado acumulado. Fatos narrativos são a projeção dos eventos que importam para a história.
>
> 🧱 **Onde a ponte cai:** na Vigília, a projeção ainda é feita **à mão**: alguém precisa lembrar de conceder o fato. O Capítulo 46 transforma isso em regra ("quando acontecer X, registre Y") e faz o estado narrativo **anunciar** mudanças de fato. Aí condições como "concluída se" poderão ser reavaliadas a cada mudança, e não só nos momentos em que a quest se mexe.

### Nem tudo é quest

O mesmo raciocínio resolve a dor 7. O susto do corredor não é um passo da quest, porque a jogadora não está "tentando" levar um susto. É uma **regra do mundo**: "depois que os disjuntores forem religados, a primeira passagem pela curva do corredor dispara o susto". Uma regra do mundo condicionada a fatos cabe no próprio gatilho:

- `RequiredFacts`: `TEM S1.BreakersRestored` e `NÃO TEM S1.ScareDone`.
- `FactOnTrigger`: `S1.ScareDone`.

O gatilho deixa de precisar do `bSustoArmado` e do `bSustoAconteceu` do Level Blueprint: a "memória" dele virou fato narrativo, consultável por qualquer sistema. Sônia pode comentar o susto, um documento do setor 2 pode mencionar "as luzes andando", e o Capítulo 46 vai salvar o fato.

A regra geral: **quests modelam o que a jogadora está tentando fazer; regras do mundo modelam como o mundo reage aos fatos.** Colocar o susto dentro da quest acoplaria uma reação ambiente ao roteiro de objetivos, e qualquer mudança no roteiro mexeria no susto.

---

## 45.4 Ações como dados

As consequências precisam de **verbos**: conceder um fato, pedir uma conversa, iniciar outra quest, avisar o nível de que algo aconteceu. No Level Blueprint, cada verbo era um nó. Num sistema de quests, há três formas de expressá-los:

| Forma | Como | Problema |
|---|---|---|
| **Enum + switch** | `EVGQuestEffect::GrantFact`, um campo para cada parâmetro possível, um `switch` no subsistema | O `switch` cresce a cada verbo; metade dos campos não se aplica a cada caso |
| **Script por quest** | Um Blueprint por quest, com eventos `OnStageEntered` | Volta o mar de nós, agora em vários Blueprints |
| **Objetos instanciados** | Uma classe pequena por verbo; o designer **compõe** uma lista de instâncias dentro do asset da quest | — |

A terceira forma é um padrão clássico da Unreal: uma classe base `UObject` marcada `EditInlineNew` e `DefaultToInstanced`, e propriedades `Instanced` que guardam **instâncias** dessas classes dentro do asset. No editor, o designer clica em "+", escolhe "Conceder fato" ou "Pedir conversa" numa lista, e preenche os campos daquela ação, e só os daquela ação. Cada verbo é uma classe de vinte linhas. Um verbo novo é uma classe nova, e nada do que já existe muda.

> 🌉 **Ponte:** é o padrão **Command** (ou **Strategy**) com composição declarativa, como uma lista de *steps* configurados em YAML num pipeline de CI, cada um com o seu tipo e os seus parâmetros.
>
> 🧱 **Onde a ponte cai:** as instâncias vivem **dentro do asset** e são compartilhadas por toda execução da quest. Elas não podem guardar estado de runtime (`Execute` é `const`), e não podem referenciar atores do nível: um Data Asset não sabe em que mapa vai ser usado.

### A escotilha: sinais

Essa última restrição é importante. Muitas consequências envolvem o nível ("acenda as luzes do hall", "toque o alarme da Casa de Força"), e um asset de quest não pode apontar para um ator de um mapa específico. A saída é a mesma do Capítulo 24: **publicar no barramento**. A ação "Publicar sinal" emite `Event.Quest.Signal` com uma tag de contexto (`Signal.S1.ChapterEnd`), e quem estiver no nível e se importar com aquele sinal reage. A quest não sabe quem reage, e o nível não sabe qual quest emitiu.

É a escotilha que mantém o sistema pequeno: o caso comum é dado, e o caso específico de um nível é um sinal mais uma reação local, sem que o sistema de quests ganhe uma ação nova a cada necessidade.

---

## 45.5 Reentrância: a fila de trabalho

Sistemas guiados por eventos têm uma armadilha que o Capítulo 4 apresentou e que aqui fica séria. Siga a cadeia:

```text
 1. O barramento publica Event.Item.Collected (o livro)
 2. O subsistema de objetivos, ITERANDO a sua lista, conclui o objetivo do livro
    e anuncia OnObjectiveFinished
 3. A quest, dentro desse anúncio, conclui a etapa, CANCELA os objetivos restantes
    e ATIVA os da próxima etapa
 4. → a lista que o subsistema de objetivos está iterando mudou embaixo dele
```

O passo 4 é um acesso fora dos limites esperando para acontecer: o subsistema de objetivos itera de trás para frente e remove o objetivo concluído, mas não espera que **outro** elemento suma no meio do laço. E a cadeia pode ser mais longa: uma ação da quest publica um sinal, que conclui outro objetivo, que avança outra quest...

A regra que resolve isso: **não mexa no estado de quem está te notificando, dentro da notificação.** O subsistema de quests não processa nada no momento em que é avisado. Ele **enfileira** o trabalho ("o objetivo X concluiu", "inicie a quest Y", "reavalie a etapa da quest Z") e o processa no **próximo tick**, num laço, fora de qualquer anúncio:

```text
  notificações (a qualquer momento)            próximo tick
  ─────────────────────────────────            ────────────────────────────────
  objetivo concluiu ──┐                        Drain():
  StartQuest()   ─────┼──► FILA DE TRABALHO ──►  para cada item (a fila pode crescer):
  ação de quest  ─────┘     (só enfileira)          processa: entra/sai de etapas,
                                                    ativa/cancela objetivos, ações
                                                  limite de itens por tick (laços)
```

O custo é **um quadro de atraso** entre o objetivo concluir e a quest reagir, imperceptível para a jogadora. O ganho é que toda mutação de quest acontece num único lugar, numa ordem previsível, sem recursão.

> 🌉 **Ponte:** é o modelo de **atores** (a caixa de mensagens do Akka) ou o *event loop* do Node: mensagens são enfileiradas, e o processamento é sequencial e fora da pilha de quem enviou.
>
> 🧱 **Onde a ponte cai:** tudo roda na mesma thread, e a "caixa de mensagens" é esvaziada uma vez por quadro. Não há concorrência real, só **reentrância**: o perigo não são duas threads, é uma única pilha de chamadas que volta para dentro de si mesma.

---

## Estudos de caso

### GTA: San Andreas — missões como programas

**[FATO PÚBLICO]** Nos GTA da era do PlayStation 2 (*GTA III*, *Vice City*, *San Andreas*), as missões e boa parte da lógica do mundo ficam num arquivo de script compilado, o `main.scm`, interpretado pelo jogo. A comunidade de modding decompila e edita esse script há anos, com ferramentas próprias, e é assim que boa parte dos mods de missão desses jogos foi feita.

**[INFERÊNCIA]** Num jogo com dezenas de missões muito diferentes entre si (perseguições, corridas, tiroteios, cenas), uma **linguagem de script** dá o máximo de flexibilidade: cada missão é um pequeno programa. O custo é o oposto da flexibilidade: cada missão é código, com os seus `if`, as suas esperas e os seus casos esquecidos, e quem escreve missões precisa programar.

**Lição para a Vigília:** a escolha entre script e dados é de **escala e de variedade**. Um jogo de 15 minutos com missões parecidas (investigar, religar, chegar a algum lugar) cabe em dados, com uma escotilha para o que é único. É a comparação "arquitetura elegante × arquitetura adequada" que a Introdução prometeu: dados não são "melhores" que script, são **adequados** a este projeto.

### Skyrim — etapas, objetivos e fragmentos

**[FATO PÚBLICO]** No *Creation Kit*, a ferramenta de edição de *The Elder Scrolls V: Skyrim* (Bethesda), quests são organizadas em **etapas numeradas** (*stages*), com **objetivos** exibidos ao jogador e **condições** avaliadas pelo motor. Cada etapa pode ter um pequeno **fragmento de script** (*Papyrus*) executado quando a quest chega a ela. A documentação pública do *Creation Kit* descreve esse modelo.

**[INFERÊNCIA]** É um sistema **híbrido**: a estrutura (etapas, objetivos, condições) é dado, e o comportamento específico de cada etapa é um fragmento de código curto e local. O dado dá forma e visibilidade (dá para ver uma quest inteira como lista de etapas); o fragmento dá a escotilha.

**Lição para a Vigília:** é o mesmo desenho deste capítulo em escala maior. As etapas, objetivos e condições são dados; os "fragmentos" são as ações instanciadas (verbos genéricos) e os sinais (a escotilha para o nível).

### Alan Wake 2 — a investigação como fatos

**[FATO PÚBLICO]** Em *Alan Wake 2* (Remedy, 2023), a agente Saga Anderson tem um espaço mental, o *Mind Place*, com um quadro de investigação (*Case Board*) em que o jogador posiciona pistas encontradas para avançar os casos.

**[INFERÊNCIA]** O avanço da investigação depende do que o jogador **descobriu e conectou**, não de onde ele está. É progresso por **fatos**: a pergunta não é "o jogador entrou na sala X?", e sim "o jogador já sabe Y e Z?". O quadro torna esses fatos visíveis e transforma "conectar" numa ação do jogador.

**Lição para a Vigília:** condições por fatos ("concluída se", pré-condições, transições) são o mecanismo que permite progresso por conhecimento. O livro-razão de mistério do Capítulo 43 é, em essência, um quadro de investigação que só o designer vê. O desafio do Capítulo 48 pode torná-lo visível para a jogadora.

---

## Comparação com o desenvolvimento tradicional

| Quests | O que você conhece | Onde a analogia cai |
|---|---|---|
| Quest como processo de etapas | Saga / *process manager* | Quase nunca há compensação; travar é uma falha de experiência, não um pedido pendente |
| Objetivos paralelos numa etapa | *Fork/join* num workflow (BPMN: gateway paralelo) | O *join* é "todos" ou "qualquer um", e o que sobrar é cancelado |
| Transições condicionadas a fatos | Gateway exclusivo (BPMN) com expressões | As expressões são escritas por designers, sobre tags, não por devs |
| Fatos como memória dos eventos | *Read model*, projeção de eventos | A projeção ainda é manual até o Cap. 46 |
| Ações instanciadas | Command / Strategy declarativos (steps de pipeline) | As instâncias são do asset: sem estado de runtime, sem referência ao nível |
| Fila de trabalho processada no tick | Caixa de mensagens de ator, *event loop* | Uma thread, um quadro de latência; o inimigo é a reentrância, não a concorrência |

---

## Unreal Engine: o que existe

A Unreal não tem um sistema de quests. Tem as peças, quase todas já usadas no livro:

- **Data Assets** (`UPrimaryDataAsset`, Capítulo 13). Como *primary assets*, as quests podem ser listadas pelo *Asset Manager*, o que será útil para o diário e para o save (Capítulo 56).
- **Subobjetos instanciados.** Uma classe `UObject` com os especificadores `EditInlineNew` e `DefaultToInstanced`, mais propriedades marcadas `Instanced`, permite que o designer crie e configure objetos **dentro** do asset, escolhendo a subclasse numa lista. É o mecanismo das ações.
- **Gameplay Tags e Tag Queries** (Capítulo 23) para condições, e o **barramento** (Capítulo 24) para eventos e sinais.
- **Subsystems** (Capítulo 6) para o runtime, e o **Timer Manager**, com `SetTimerForNextTick`, para adiar o processamento para fora das notificações.

⚠️ Há plugins (da comunidade e do Marketplace/Fab) que oferecem quests e grafos de fluxo prontos. Avalie com os critérios da seção "Abordagens" antes de adotar: a quantidade de conteúdo da Vigília não justifica uma dependência, mas um jogo maior talvez justifique.

---

## Abordagens

| Critério | A. Script por quest (Blueprint ou linguagem de script) | B. Lista linear de objetivos (controlador do Cap. 31) | **C. Etapas + condições + ações como dados** | D. Grafo visual de fluxo (plugin ou editor próprio) |
|---|---|---|---|---|
| **Complexidade** | Baixa por quest, alta no total | Mínima | Média: um subsistema e uma família de ações | Alta (editor) ou dependência externa |
| **Performance** | Boa | Trivial | Trivial (event-driven, sem tick) | Boa |
| **Extensibilidade** | Total, caso a caso | Nenhuma: sem condições nem ramificação | Novos verbos = novas classes de ação; o resto é dado | Alta |
| **Manutenção** | Difícil: cada quest é um programa | Fácil, até precisar de algo além de sequência | Fácil: quests são legíveis como dados e validadas no editor | Depende de quem mantém o editor |
| **Prototipação** | Rápida | Rápida | Rápida, depois de pronto | Rápida para designers |
| **Adequação à Vigília** | Foi o Interlúdio, e doeu | Não basta | **Sim** | Excesso para 4 setores |

**Decisão: C**, com duas escotilhas deliberadas: **sinais** para reações específicas do nível, e **novas classes de ação** para verbos novos. Se um dia uma quest precisar de algo que nenhuma das duas resolve, isso indica que talvez ela não seja uma quest: talvez seja uma sequência roteirizada (Capítulo 49) ou uma regra do mundo (seção 45.3).

---

## Implementação

### 1. Tags

```cpp
// VGGameplayTags.h (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Quest_Started);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Quest_StageEntered);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Quest_Completed);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Quest_Failed);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Quest_Signal);

// VGGameplayTags.cpp (adições)
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Quest_Started,      "Event.Quest.Started");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Quest_StageEntered, "Event.Quest.StageEntered");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Quest_Completed,    "Event.Quest.Completed");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Quest_Failed,       "Event.Quest.Failed");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Quest_Signal,       "Event.Quest.Signal");
```

Tags de conteúdo, no editor: `Quest.*` (identidade de quests) e `Signal.*` (sinais para o nível).

### 2. As ações

```cpp
// Source/Vigilia/Narrative/VGQuestActions.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "UObject/Object.h"
#include "VGQuestActions.generated.h"

class UVGDialogueData;
class UVGQuestData;

/**
 * Um efeito de quest, configurado como dado: instâncias vivem DENTRO do asset da quest.
 * Imutável em runtime (Execute é const) e sem referências ao nível: para o nível, use um sinal.
 */
UCLASS(Abstract, EditInlineNew, DefaultToInstanced, CollapseCategories)
class VIGILIA_API UVGQuestAction : public UObject
{
    GENERATED_BODY()

public:
    virtual void Execute(UWorld& World) const PURE_VIRTUAL(UVGQuestAction::Execute, );

    /** Uma linha para o log de depuração (vg.Debug.Quests). */
    virtual FString Describe() const { return GetClass()->GetName(); }
};

UCLASS(meta = (DisplayName = "Conceder fato"))
class VIGILIA_API UVGQuestAction_GrantFact : public UVGQuestAction
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, Category = "Action", meta = (Categories = "Narrative.Fact"))
    FGameplayTag Fact;

    virtual void Execute(UWorld& World) const override;
    virtual FString Describe() const override { return TEXT("Fato ") + Fact.ToString(); }
};

UCLASS(meta = (DisplayName = "Pedir conversa"))
class VIGILIA_API UVGQuestAction_PlayConversation : public UVGQuestAction
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, Category = "Action")
    TObjectPtr<const UVGDialogueData> Conversation;

    virtual void Execute(UWorld& World) const override;
    virtual FString Describe() const override; // no .cpp: aqui UVGDialogueData é só declarado
};

UCLASS(meta = (DisplayName = "Iniciar quest"))
class VIGILIA_API UVGQuestAction_StartQuest : public UVGQuestAction
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, Category = "Action")
    TObjectPtr<const UVGQuestData> Quest;

    virtual void Execute(UWorld& World) const override;
    virtual FString Describe() const override;
};

/** A escotilha para o nível: publica Event.Quest.Signal com esta tag; quem se importa, reage. */
UCLASS(meta = (DisplayName = "Publicar sinal"))
class VIGILIA_API UVGQuestAction_PublishSignal : public UVGQuestAction
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, Category = "Action", meta = (Categories = "Signal"))
    FGameplayTag Signal;

    virtual void Execute(UWorld& World) const override;
    virtual FString Describe() const override { return TEXT("Sinal ") + Signal.ToString(); }
};
```

```cpp
// Source/Vigilia/Narrative/VGQuestActions.cpp
#include "Narrative/VGQuestActions.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Engine/World.h"
#include "Narrative/VGDialogueData.h"
#include "Narrative/VGDialogueSubsystem.h"
#include "Narrative/VGQuestData.h"
#include "Narrative/VGQuestSubsystem.h"

void UVGQuestAction_GrantFact::Execute(UWorld& World) const
{
    // Os fatos ainda moram no subsistema de diálogo (Cap. 44); o Cap. 46 os muda de casa.
    if (UVGDialogueSubsystem* Facts = World.GetSubsystem<UVGDialogueSubsystem>())
    {
        Facts->AddFact(Fact);
    }
}

void UVGQuestAction_PlayConversation::Execute(UWorld& World) const
{
    if (UVGDialogueSubsystem* Dialogue = World.GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->RequestConversation(Conversation);
    }
}

void UVGQuestAction_StartQuest::Execute(UWorld& World) const
{
    if (UVGQuestSubsystem* Quests = World.GetSubsystem<UVGQuestSubsystem>())
    {
        Quests->StartQuest(Quest);
    }
}

FString UVGQuestAction_PlayConversation::Describe() const { return TEXT("Conversa ") + GetNameSafe(Conversation); }
FString UVGQuestAction_StartQuest::Describe() const { return TEXT("Quest ") + GetNameSafe(Quest); }

void UVGQuestAction_PublishSignal::Execute(UWorld& World) const
{
    UVGGameplayEventSubsystem::PublishFrom(&World, TAG_Event_Quest_Signal, nullptr, nullptr, Signal);
}
```

### 3. A definição da quest

```cpp
// Source/Vigilia/Narrative/VGQuestData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "GameplayTagContainer.h"
#include "VGQuestData.generated.h"

class UVGObjectiveData;
class UVGQuestAction;

UENUM(BlueprintType)
enum class EVGStageCompletion : uint8
{
    AllRequired,   // todos os obrigatórios (ordem livre)
    AnyRequired    // qualquer um dos obrigatórios (caminhos alternativos)
};

USTRUCT(BlueprintType)
struct FVGQuestObjectiveEntry
{
    GENERATED_BODY()

    /** Um objetivo do Cap. 31. Pertence a uma única entrada desta quest. */
    UPROPERTY(EditAnywhere, Category = "Objective")
    TObjectPtr<const UVGObjectiveData> Objective;

    /** Opcional: não conta para concluir a etapa e é cancelado quando ela termina. */
    UPROPERTY(EditAnywhere, Category = "Objective")
    bool bOptional = false;

    UPROPERTY(EditAnywhere, Instanced, Category = "Objective")
    TArray<TObjectPtr<UVGQuestAction>> OnCompleted;
};

USTRUCT(BlueprintType)
struct FVGQuestTransition
{
    GENERATED_BODY()

    /** Vazia = sempre passa. */
    UPROPERTY(EditAnywhere, Category = "Transition")
    FGameplayTagQuery Condition;

    /** Id da próxima etapa; "End" conclui a quest. */
    UPROPERTY(EditAnywhere, Category = "Transition")
    FName NextStage;
};

USTRUCT(BlueprintType)
struct FVGQuestStage
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, Category = "Stage")
    FName Id;

    /** Texto do diário enquanto a quest está nesta etapa. */
    UPROPERTY(EditAnywhere, Category = "Stage", meta = (MultiLine = "true"))
    FText Summary;

    UPROPERTY(EditAnywhere, Category = "Stage")
    EVGStageCompletion Completion = EVGStageCompletion::AllRequired;

    UPROPERTY(EditAnywhere, Category = "Stage")
    TArray<FVGQuestObjectiveEntry> Objectives;

    /** Se os fatos já satisfazem esta consulta, a etapa conclui (eventos que aconteceram "antes da hora"). */
    UPROPERTY(EditAnywhere, Category = "Stage")
    FGameplayTagQuery CompletedIf;

    UPROPERTY(EditAnywhere, Instanced, Category = "Stage")
    TArray<TObjectPtr<UVGQuestAction>> OnEnter;

    UPROPERTY(EditAnywhere, Instanced, Category = "Stage")
    TArray<TObjectPtr<UVGQuestAction>> OnComplete;

    /** Avaliadas em ordem DEPOIS do OnComplete; a primeira que passa decide.
     *  Nenhuma (ou nenhuma passa): a etapa seguinte do array; depois da última, a quest conclui. */
    UPROPERTY(EditAnywhere, Category = "Stage")
    TArray<FVGQuestTransition> Transitions;
};

/** Uma quest: o QUE a jogadora persegue e em que estrutura. Imutável em runtime. */
UCLASS(BlueprintType)
class VIGILIA_API UVGQuestData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Quest", meta = (Categories = "Quest"))
    FGameplayTag QuestTag;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Quest")
    FText Title;

    /** Pré-condição para iniciar. Vazia = sempre. */
    UPROPERTY(EditDefaultsOnly, Category = "Quest")
    FGameplayTagQuery StartCondition;

    UPROPERTY(EditDefaultsOnly, Category = "Quest")
    TArray<FVGQuestStage> Stages;

    UPROPERTY(EditDefaultsOnly, Instanced, Category = "Quest")
    TArray<TObjectPtr<UVGQuestAction>> OnCompleted;

    UPROPERTY(EditDefaultsOnly, Instanced, Category = "Quest")
    TArray<TObjectPtr<UVGQuestAction>> OnFailed;

    int32 FindStageIndex(FName Id) const;

#if WITH_EDITOR
    virtual EDataValidationResult IsDataValid(class FDataValidationContext& Context) const override;
#endif
};
```

A validação segue o padrão do Capítulo 44, com as regras próprias de quests:

```cpp
// Source/Vigilia/Narrative/VGQuestData.cpp
#include "Narrative/VGQuestData.h"

#include "Narrative/VGQuestRules.h"
#include "World/VGObjectiveData.h"
#if WITH_EDITOR
#include "Misc/DataValidation.h"
#endif

int32 UVGQuestData::FindStageIndex(FName Id) const
{
    return Stages.IndexOfByPredicate([Id](const FVGQuestStage& Stage) { return Stage.Id == Id; });
}

#if WITH_EDITOR
EDataValidationResult UVGQuestData::IsDataValid(FDataValidationContext& Context) const
{
    EDataValidationResult Result = Super::IsDataValid(Context);
    auto Error = [&](const FString& Message)
    {
        Context.AddError(FText::FromString(Message));
        Result = EDataValidationResult::Invalid;
    };

    if (!QuestTag.IsValid()) { Error(TEXT("QuestTag vazia.")); }
    if (Stages.IsEmpty())    { Error(TEXT("Quest sem etapas.")); }

    TSet<FName> StageIds;
    TSet<const UVGObjectiveData*> SeenObjectives;
    for (const FVGQuestStage& Stage : Stages)
    {
        if (Stage.Id.IsNone() || Stage.Id == VGQuestRules::EndId() || StageIds.Contains(Stage.Id))
        {
            Error(FString::Printf(TEXT("Etapa '%s': Id vazio, reservado ou duplicado."), *Stage.Id.ToString()));
        }
        StageIds.Add(Stage.Id);

        bool bHasRequired = false;
        for (const FVGQuestObjectiveEntry& Entry : Stage.Objectives)
        {
            if (!Entry.Objective)
            {
                Error(FString::Printf(TEXT("Etapa '%s': objetivo vazio."), *Stage.Id.ToString()));
                continue;
            }
            if (SeenObjectives.Contains(Entry.Objective))
            {
                Error(FString::Printf(TEXT("Objetivo '%s' aparece mais de uma vez na quest."), *Entry.Objective->GetName()));
            }
            SeenObjectives.Add(Entry.Objective);
            bHasRequired |= !Entry.bOptional;
        }
        if (!bHasRequired && !Stage.Objectives.IsEmpty())
        {
            Context.AddWarning(FText::FromString(FString::Printf(
                TEXT("Etapa '%s' só tem opcionais: ela conclui ao entrar e os cancela."), *Stage.Id.ToString())));
        }
        for (const FVGQuestTransition& Transition : Stage.Transitions)
        {
            if (Transition.NextStage != VGQuestRules::EndId() && FindStageIndex(Transition.NextStage) == INDEX_NONE)
            {
                Error(FString::Printf(TEXT("Etapa '%s': transição para '%s', que não existe."),
                    *Stage.Id.ToString(), *Transition.NextStage.ToString()));
            }
        }
    }
    return Result;
}
#endif
```

A regra "um objetivo aparece uma vez por quest" existe porque o subsistema de objetivos (Capítulo 31) recusa ativar o mesmo objetivo duas vezes, e porque, ao concluir, a quest precisa saber **qual** entrada concluiu. Que um objetivo não pertença a **duas quests** é uma regra que o validador de um asset não consegue verificar sozinho. Fica no `docs/design/quests.md`, com o padrão de nomes `DA_Obj_<Setor>_<Coisa>`.

### 4. Regras puras e estado

```cpp
// Source/Vigilia/Narrative/VGQuestRules.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGQuestData.h"

namespace VGQuestRules
{
    /** Destino reservado: conclui a quest. */
    FName EndId();

    /** Sem obrigatórios = etapa de passagem (conclui ao entrar). */
    bool IsStageComplete(EVGStageCompletion Completion, int32 RequiredTotal, int32 RequiredDone);

    /** Próxima etapa depois de concluir StageIndex. INDEX_NONE = a quest conclui. */
    int32 SelectNextStage(const UVGQuestData& Quest, int32 StageIndex, const FGameplayTagContainer& Facts);
}
```

```cpp
// Source/Vigilia/Narrative/VGQuestRules.cpp
#include "Narrative/VGQuestRules.h"

FName VGQuestRules::EndId()
{
    static const FName End(TEXT("End"));
    return End;
}

bool VGQuestRules::IsStageComplete(EVGStageCompletion Completion, int32 RequiredTotal, int32 RequiredDone)
{
    if (RequiredTotal == 0)
    {
        return true;
    }
    return Completion == EVGStageCompletion::AllRequired ? RequiredDone >= RequiredTotal : RequiredDone > 0;
}

int32 VGQuestRules::SelectNextStage(const UVGQuestData& Quest, int32 StageIndex, const FGameplayTagContainer& Facts)
{
    for (const FVGQuestTransition& Transition : Quest.Stages[StageIndex].Transitions)
    {
        if (Transition.Condition.IsEmpty() || Transition.Condition.Matches(Facts))
        {
            return Transition.NextStage == EndId() ? INDEX_NONE : Quest.FindStageIndex(Transition.NextStage);
        }
    }
    return Quest.Stages.IsValidIndex(StageIndex + 1) ? StageIndex + 1 : INDEX_NONE;
}
```

```cpp
// Source/Vigilia/Narrative/VGQuestTypes.h
#pragma once

#include "CoreMinimal.h"
#include "VGQuestTypes.generated.h"

class UVGQuestData;

UENUM(BlueprintType)
enum class EVGQuestStatus : uint8
{
    Inactive,
    Active,
    Completed,
    Failed
};

USTRUCT(BlueprintType)
struct FVGQuestState
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Quest")
    TObjectPtr<const UVGQuestData> Quest;

    UPROPERTY(BlueprintReadOnly, Category = "Quest")
    EVGQuestStatus Status = EVGQuestStatus::Inactive;

    UPROPERTY(BlueprintReadOnly, Category = "Quest")
    int32 StageIndex = INDEX_NONE;

    /** Obrigatórios concluídos na etapa atual. */
    UPROPERTY(BlueprintReadOnly, Category = "Quest")
    int32 RequiredDone = 0;

    /** Cópia do resumo da etapa, para a UI (apresentação derivada, Cap. 4). */
    UPROPERTY(BlueprintReadOnly, Category = "Quest")
    FText StageSummary;
};
```

### 5. O subsistema

```cpp
// Source/Vigilia/Narrative/VGQuestSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGQuestTypes.h"
#include "Subsystems/WorldSubsystem.h"
#include "World/VGObjectiveTypes.h"
#include "VGQuestSubsystem.generated.h"

class UVGObjectiveData;
class UVGQuestAction;
class UVGQuestData;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGQuestChangedSignature, const FVGQuestState&, Quest);

/**
 * Coordena quests: entra e sai de etapas, ativa e cancela objetivos (Cap. 31), executa ações.
 * TODA mutação acontece em Drain(), no tick seguinte, fora de qualquer notificação (reentrância).
 * Simplificação: estado por mundo e sem persistência (Caps. 46 e 56); quests não se repetem.
 */
UCLASS()
class VIGILIA_API UVGQuestSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Deinitialize() override;

    /** Enfileira o início. false se a quest é inválida ou já foi iniciada. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Quests")
    bool StartQuest(const UVGQuestData* Quest);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Quests")
    EVGQuestStatus GetQuestStatus(const UVGQuestData* Quest) const;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Quests")
    TArray<FVGQuestState> GetQuests() const { return Quests; }

    /** Depuração: pula para uma etapa sem executar as ações das etapas puladas. */
    void DebugJumpToStage(FGameplayTag QuestTag, FName StageId);

    FString DescribeForDebug() const;

    /** Mudou de etapa, concluiu ou falhou. */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Quests")
    FVGQuestChangedSignature OnQuestChanged;

private:
    struct FWork
    {
        enum class EKind : uint8 { Start, ObjectiveFinished, CheckStage, JumpTo };
        EKind Kind = EKind::CheckStage;
        TWeakObjectPtr<const UVGQuestData> Quest;          // Start
        TWeakObjectPtr<const UVGObjectiveData> Objective;  // ObjectiveFinished
        EVGObjectiveStatus Result = EVGObjectiveStatus::Completed;
        int32 QuestIndex = INDEX_NONE;                     // CheckStage, JumpTo
        FName StageId;                                     // JumpTo
    };

    UFUNCTION()
    void HandleObjectiveFinished(const FVGObjectiveState& Objective);

    void Enqueue(const FWork& Work);
    void Drain();
    void ProcessStart(const UVGQuestData* Quest);
    void ProcessObjective(const UVGObjectiveData* Objective, EVGObjectiveStatus Result);
    void CheckStage(int32 QuestIndex);
    void EnterStage(int32 QuestIndex, int32 StageIndex);
    void CancelStageObjectives(int32 QuestIndex);
    void FinishQuest(int32 QuestIndex, EVGQuestStatus Result);
    void RunActions(const TArray<TObjectPtr<UVGQuestAction>>& Actions);
    const FGameplayTagContainer& GetFacts() const;

    /** Ativas e encerradas: a memória da sessão ("já fiz esta quest"). */
    UPROPERTY()
    TArray<FVGQuestState> Quests;

    TArray<FWork> Pending;
    bool bDrainScheduled = false;
};
```

```cpp
// Source/Vigilia/Narrative/VGQuestSubsystem.cpp (essencial)
#include "Narrative/VGQuestSubsystem.h"

#include "Algo/Count.h"
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGLog.h"
#include "Engine/World.h"
#include "HAL/IConsoleManager.h"
#include "Narrative/VGDialogueSubsystem.h"
#include "Narrative/VGQuestActions.h"
#include "Narrative/VGQuestData.h"
#include "Narrative/VGQuestRules.h"
#include "TimerManager.h"
#include "World/VGObjectiveData.h"
#include "World/VGObjectiveSubsystem.h"

static TAutoConsoleVariable<bool> CVarVGDebugQuests(
    TEXT("vg.Debug.Quests"),
    false,
    TEXT("Registra no log cada etapa, objetivo e ação de quest; mostra as quests ativas na tela."),
    ECVF_Default);

void UVGQuestSubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
    if (UVGObjectiveSubsystem* Objectives = InWorld.GetSubsystem<UVGObjectiveSubsystem>())
    {
        Objectives->OnObjectiveFinished.AddDynamic(this, &UVGQuestSubsystem::HandleObjectiveFinished);
    }
}

void UVGQuestSubsystem::Deinitialize()
{
    if (UVGObjectiveSubsystem* Objectives = GetWorld() ? GetWorld()->GetSubsystem<UVGObjectiveSubsystem>() : nullptr)
    {
        Objectives->OnObjectiveFinished.RemoveDynamic(this, &UVGQuestSubsystem::HandleObjectiveFinished);
    }
    Super::Deinitialize();
}

bool UVGQuestSubsystem::StartQuest(const UVGQuestData* Quest)
{
    const bool bKnown = Quests.ContainsByPredicate([Quest](const FVGQuestState& S) { return S.Quest == Quest; });
    if (!Quest || Quest->Stages.IsEmpty() || bKnown)
    {
        return false;
    }
    FWork Work;
    Work.Kind = FWork::EKind::Start;
    Work.Quest = Quest;
    Enqueue(Work);
    return true;
}

void UVGQuestSubsystem::HandleObjectiveFinished(const FVGObjectiveState& Objective)
{
    // Estamos DENTRO do anúncio do subsistema de objetivos, que pode estar iterando a sua lista:
    // nada de ativar ou cancelar objetivos aqui. Só anotar.
    FWork Work;
    Work.Kind = FWork::EKind::ObjectiveFinished;
    Work.Objective = Objective.Definition.Get();
    Work.Result = Objective.Status;
    Enqueue(Work);
}

void UVGQuestSubsystem::Enqueue(const FWork& Work)
{
    Pending.Add(Work);
    if (!bDrainScheduled)
    {
        bDrainScheduled = true;
        GetWorld()->GetTimerManager().SetTimerForNextTick(this, &UVGQuestSubsystem::Drain);
    }
}

void UVGQuestSubsystem::Drain()
{
    bDrainScheduled = false;
    constexpr int32 MaxWorkPerDrain = 256; // etapas de passagem em laço seriam infinitas

    for (int32 i = 0; i < Pending.Num(); ++i) // a fila pode crescer durante o laço
    {
        if (!ensureMsgf(i < MaxWorkPerDrain, TEXT("Quests: trabalho demais num tick. Laço de etapas de passagem?")))
        {
            break;
        }
        const FWork Work = Pending[i]; // cópia: o array pode realocar
        switch (Work.Kind)
        {
        case FWork::EKind::Start:
            ProcessStart(Work.Quest.Get());
            break;
        case FWork::EKind::ObjectiveFinished:
            ProcessObjective(Work.Objective.Get(), Work.Result);
            break;
        case FWork::EKind::CheckStage:
            CheckStage(Work.QuestIndex);
            break;
        case FWork::EKind::JumpTo:
            if (Quests.IsValidIndex(Work.QuestIndex) && Quests[Work.QuestIndex].Status == EVGQuestStatus::Active)
            {
                CancelStageObjectives(Work.QuestIndex);
                EnterStage(Work.QuestIndex, Quests[Work.QuestIndex].Quest->FindStageIndex(Work.StageId));
            }
            break;
        }
    }
    Pending.Reset();
}

void UVGQuestSubsystem::ProcessStart(const UVGQuestData* Quest)
{
    const bool bKnown = Quests.ContainsByPredicate([Quest](const FVGQuestState& S) { return S.Quest == Quest; });
    if (!Quest || bKnown || (!Quest->StartCondition.IsEmpty() && !Quest->StartCondition.Matches(GetFacts())))
    {
        return; // a pré-condição é avaliada AGORA, não no pedido
    }
    FVGQuestState& State = Quests.AddDefaulted_GetRef();
    State.Quest = Quest;
    State.Status = EVGQuestStatus::Active;
    const int32 QuestIndex = Quests.Num() - 1;

    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Quest_Started, nullptr, nullptr, Quest->QuestTag);
    EnterStage(QuestIndex, 0);
}

void UVGQuestSubsystem::EnterStage(int32 QuestIndex, int32 StageIndex)
{
    if (StageIndex == INDEX_NONE)
    {
        FinishQuest(QuestIndex, EVGQuestStatus::Completed);
        return;
    }
    const UVGQuestData* Quest = Quests[QuestIndex].Quest;
    const FVGQuestStage& Stage = Quest->Stages[StageIndex];
    Quests[QuestIndex].StageIndex = StageIndex;
    Quests[QuestIndex].RequiredDone = 0;
    Quests[QuestIndex].StageSummary = Stage.Summary;

    if (UVGObjectiveSubsystem* Objectives = GetWorld()->GetSubsystem<UVGObjectiveSubsystem>())
    {
        for (const FVGQuestObjectiveEntry& Entry : Stage.Objectives)
        {
            Objectives->ActivateObjective(Entry.Objective);
        }
    }
    RunActions(Stage.OnEnter); // pode iniciar quests (o array cresce): use índices, não referências

    OnQuestChanged.Broadcast(Quests[QuestIndex]);
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Quest_StageEntered, nullptr, nullptr, Quest->QuestTag);

    // Etapa de passagem, ou "concluída se" já satisfeita: a reavaliação também passa pela fila.
    FWork Check;
    Check.Kind = FWork::EKind::CheckStage;
    Check.QuestIndex = QuestIndex;
    Pending.Add(Check); // estamos no Drain: o laço vai alcançá-la
}

void UVGQuestSubsystem::ProcessObjective(const UVGObjectiveData* Objective, EVGObjectiveStatus Result)
{
    for (int32 QuestIndex = 0; QuestIndex < Quests.Num(); ++QuestIndex)
    {
        if (Quests[QuestIndex].Status != EVGQuestStatus::Active)
        {
            continue;
        }
        const FVGQuestStage& Stage = Quests[QuestIndex].Quest->Stages[Quests[QuestIndex].StageIndex];
        const FVGQuestObjectiveEntry* Entry = Stage.Objectives.FindByPredicate(
            [Objective](const FVGQuestObjectiveEntry& E) { return E.Objective == Objective; });
        if (!Entry)
        {
            continue;
        }
        if (Result == EVGObjectiveStatus::Failed)
        {
            if (!Entry->bOptional)
            {
                FinishQuest(QuestIndex, EVGQuestStatus::Failed);
            }
            return;
        }
        RunActions(Entry->OnCompleted);
        if (!Entry->bOptional)
        {
            ++Quests[QuestIndex].RequiredDone;
        }
        CheckStage(QuestIndex);
        return;
    }
}

void UVGQuestSubsystem::CheckStage(int32 QuestIndex)
{
    if (!Quests.IsValidIndex(QuestIndex) || Quests[QuestIndex].Status != EVGQuestStatus::Active)
    {
        return;
    }
    const UVGQuestData* Quest = Quests[QuestIndex].Quest;
    const int32 StageIndex = Quests[QuestIndex].StageIndex;
    const FVGQuestStage& Stage = Quest->Stages[StageIndex];

    const bool bByFacts = !Stage.CompletedIf.IsEmpty() && Stage.CompletedIf.Matches(GetFacts());
    const int32 RequiredTotal = Algo::CountIf(Stage.Objectives, [](const FVGQuestObjectiveEntry& E) { return !E.bOptional; });
    if (!bByFacts && !VGQuestRules::IsStageComplete(Stage.Completion, RequiredTotal, Quests[QuestIndex].RequiredDone))
    {
        return;
    }

    // O que sobrou (opcionais; os outros de um "qualquer um") sai de cena.
    CancelStageObjectives(QuestIndex);
    RunActions(Stage.OnComplete);
    // Transições DEPOIS do OnComplete: os fatos concedidos ao concluir já valem para a escolha.
    EnterStage(QuestIndex, VGQuestRules::SelectNextStage(*Quest, StageIndex, GetFacts()));
}

void UVGQuestSubsystem::CancelStageObjectives(int32 QuestIndex)
{
    UVGObjectiveSubsystem* Objectives = GetWorld()->GetSubsystem<UVGObjectiveSubsystem>();
    const FVGQuestState& State = Quests[QuestIndex];
    if (!Objectives || !State.Quest->Stages.IsValidIndex(State.StageIndex))
    {
        return;
    }
    for (const FVGQuestObjectiveEntry& Entry : State.Quest->Stages[State.StageIndex].Objectives)
    {
        Objectives->CancelObjective(Entry.Objective); // já concluídos não estão mais lá: no-op
    }
}

void UVGQuestSubsystem::FinishQuest(int32 QuestIndex, EVGQuestStatus Result)
{
    CancelStageObjectives(QuestIndex);
    const UVGQuestData* Quest = Quests[QuestIndex].Quest;
    Quests[QuestIndex].Status = Result;
    Quests[QuestIndex].StageSummary = FText::GetEmpty();

    OnQuestChanged.Broadcast(Quests[QuestIndex]);
    UVGGameplayEventSubsystem::PublishFrom(this,
        Result == EVGQuestStatus::Completed ? TAG_Event_Quest_Completed : TAG_Event_Quest_Failed,
        nullptr, nullptr, Quest->QuestTag);
    RunActions(Result == EVGQuestStatus::Completed ? Quest->OnCompleted : Quest->OnFailed);
}

void UVGQuestSubsystem::RunActions(const TArray<TObjectPtr<UVGQuestAction>>& Actions)
{
    for (const UVGQuestAction* Action : Actions)
    {
        if (!Action)
        {
            continue;
        }
        UE_CLOG(CVarVGDebugQuests.GetValueOnGameThread(), LogVigilia, Log, TEXT("Quest: %s"), *Action->Describe());
        Action->Execute(*GetWorld());
    }
}

const FGameplayTagContainer& UVGQuestSubsystem::GetFacts() const
{
    // Os fatos ainda moram no subsistema de diálogo (Cap. 44). O Cap. 46 os muda de casa.
    static const FGameplayTagContainer NoFacts;
    const UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>();
    return Dialogue ? Dialogue->GetFacts() : NoFacts;
}

EVGQuestStatus UVGQuestSubsystem::GetQuestStatus(const UVGQuestData* Quest) const
{
    const FVGQuestState* State = Quests.FindByPredicate([Quest](const FVGQuestState& S) { return S.Quest == Quest; });
    return State ? State->Status : EVGQuestStatus::Inactive;
}

void UVGQuestSubsystem::DebugJumpToStage(FGameplayTag QuestTag, FName StageId)
{
    const int32 QuestIndex = Quests.IndexOfByPredicate(
        [QuestTag](const FVGQuestState& S) { return S.Quest && S.Quest->QuestTag == QuestTag; });
    if (QuestIndex == INDEX_NONE || Quests[QuestIndex].Quest->FindStageIndex(StageId) == INDEX_NONE)
    {
        UE_LOG(LogVigilia, Warning, TEXT("VGQuestJump: quest '%s' ou etapa '%s' não encontrada."),
               *QuestTag.ToString(), *StageId.ToString());
        return;
    }
    FWork Work;
    Work.Kind = FWork::EKind::JumpTo;
    Work.QuestIndex = QuestIndex;
    Work.StageId = StageId;
    Enqueue(Work);
}

// DescribeForDebug e o desenho na tela com vg.Debug.Quests: quest, etapa, obrigatórios
// concluídos/total. Implementação direta, no padrão do Cap. 44 — exercício da Parte 2.
```

🔁 O subsistema de diálogo do Capítulo 44 ganha um acesso de leitura aos fatos, usado pelas quests e pelos gatilhos:

```cpp
// UVGDialogueSubsystem (adição)
const FGameplayTagContainer& GetFacts() const { return Facts; }
```

### Explicação das decisões

- **Subsistema sem tick.** O tempo-limite dos objetivos já é tratado pelo subsistema do Capítulo 31; as quests só reagem. O único "tick" é o `SetTimerForNextTick`, agendado quando há trabalho na fila.
- **Toda mutação no `Drain`.** `StartQuest`, `HandleObjectiveFinished` e `DebugJumpToStage` só enfileiram. É a seção 45.5 em código: nenhuma etapa muda dentro de um anúncio alheio.
- **Índices, nunca referências, através de `RunActions`.** Uma ação pode iniciar outra quest, o que faz o array `Quests` crescer e realocar. Toda referência a um `FVGQuestState` obtida antes de `RunActions` é suspeita depois dele. Por isso o código relê `Quests[QuestIndex]`.
- **Pré-condição avaliada no processamento**, não no pedido. Entre um e outro passa um tick, e os fatos podem ter mudado.
- **Transições depois do `OnComplete`.** Assim, uma etapa pode conceder um fato ao concluir e ramificar por ele. Ao ler uma quest de cima para baixo, tudo o que a etapa faz acontece antes da decisão de para onde ir.
- **"Concluída se" reavaliada ao entrar na etapa e a cada objetivo concluído.** É o suficiente para eventos que aconteceram antes da hora. Reavaliar a cada mudança de fato exige que os fatos **anunciem** mudanças, e isso é o Capítulo 46.
- **Falha só por objetivo obrigatório.** A Vigília quase não tem falha de quest: a morte é tratada pelo respawn (Capítulo 22). O suporte existe (`OnFailed`, `Event.Quest.Failed`) porque custa pouco e o setor 3 pode ter uma fuga com tempo-limite.
- **Quests não se repetem** (simplificação). Uma quest encerrada fica na lista como memória da sessão. Quests repetíveis exigiriam "reiniciar" e limpar a memória de quem as acompanha, e não há caso para isso na Vigília.
- **Limite de trabalho por tick** com `ensure`: duas etapas de passagem apontando uma para a outra são um laço infinito. O limite transforma um travamento em um erro visível no log.
- **Os fatos ainda no subsistema de diálogo.** Agora são três leitores: o diálogo, as quests e os gatilhos. Pelo critério do "terceiro caso" (Capítulo 6), é a hora de extrair, e o próximo capítulo faz exatamente isso. Fazê-lo aqui misturaria dois assuntos num capítulo.

### 6. Gatilhos condicionados a fatos

🔁 O `AVGEventTrigger` (Capítulos 15 e 31) ganha duas propriedades e duas verificações:

```cpp
// AVGEventTrigger.h (adições)
/** O gatilho só "existe" quando os fatos permitem. Vazia = sempre. */
UPROPERTY(EditAnywhere, Category = "Vigilia|Trigger")
FGameplayTagQuery RequiredFacts;

/** Concedido ao disparar: a memória de "já aconteceu" vira fato narrativo. */
UPROPERTY(EditAnywhere, Category = "Vigilia|Trigger", meta = (Categories = "Narrative.Fact"))
FGameplayTag FactOnTrigger;
```

```cpp
// AVGEventTrigger::HandleBeginOverlap (adições)
// ... depois das verificações de bTriggerOnce e bPlayerOnly:
UVGDialogueSubsystem* Facts = GetWorld()->GetSubsystem<UVGDialogueSubsystem>(); // casa provisória (Cap. 46)
if (!RequiredFacts.IsEmpty() && (!Facts || !RequiredFacts.Matches(Facts->GetFacts())))
{
    return; // ainda não é hora, ou já passou
}

bHasTriggered = true;
if (Facts && FactOnTrigger.IsValid())
{
    Facts->AddFact(FactOnTrigger); // antes de anunciar: quem reage já vê o fato (Cap. 4)
}
OnTriggered.Broadcast(this, OtherActor);
// ... publicação de Event.Trigger.Entered (Cap. 31), como antes
```

O gatilho do susto passa a ser configurado assim: `bTriggerOnce = false`, `RequiredFacts = TEM S1.BreakersRestored E NÃO TEM S1.ScareDone`, `FactOnTrigger = S1.ScareDone`. Ele dispara uma vez, na hora certa, sem nenhuma variável no Level Blueprint.

### 7. Depuração

```cpp
// UVGCheatManager (adição)
UFUNCTION(Exec)
void VGQuestJump(const FString& QuestTag, const FString& StageId);

void UVGCheatManager::VGQuestJump(const FString& QuestTag, const FString& StageId)
{
    if (UVGQuestSubsystem* Quests = GetWorld()->GetSubsystem<UVGQuestSubsystem>())
    {
        Quests->DebugJumpToStage(FGameplayTag::RequestGameplayTag(FName(*QuestTag), false), FName(*StageId));
    }
}
```

`VGQuestJump Quest.S1.NightShift Painel` leva a quest direto à última etapa. Como as ações das etapas puladas não rodam, combine com `VGAddFact` (Capítulo 44) para montar o estado que você quer testar: por exemplo, `VGAddFact Narrative.Fact.Document.Memo.Read` antes do salto, para ver o final da variante do memorando.

### 8. Teste das regras

```cpp
// Source/Vigilia/Tests/VGQuestRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayTags.h"
#include "Narrative/VGQuestData.h"
#include "Narrative/VGQuestRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGQuestRulesTest, "Vigilia.Narrative.Quests.StagesAndTransitions",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGQuestRulesTest::RunTest(const FString& Parameters)
{
    const FGameplayTag Fact = TAG_Status_Hidden; // as regras não ligam para o nome do fato

    UVGQuestData* Quest = NewObject<UVGQuestData>();
    FVGQuestStage A; A.Id = TEXT("A");
    FVGQuestTransition ToC;
    ToC.Condition = FGameplayTagQuery::MakeQuery_MatchTag(Fact);
    ToC.NextStage = TEXT("C");
    A.Transitions.Add(ToC);
    FVGQuestStage B; B.Id = TEXT("B");
    FVGQuestStage C; C.Id = TEXT("C");
    Quest->Stages = { A, B, C };

    const FGameplayTagContainer NoFacts;
    const FGameplayTagContainer WithFact(Fact);

    TestEqual(TEXT("Com o fato, A ramifica para C"), VGQuestRules::SelectNextStage(*Quest, 0, WithFact), 2);
    TestEqual(TEXT("Sem o fato, A segue para B"), VGQuestRules::SelectNextStage(*Quest, 0, NoFacts), 1);
    TestEqual(TEXT("Depois da última, conclui"), VGQuestRules::SelectNextStage(*Quest, 2, NoFacts), INDEX_NONE);

    FVGQuestTransition ToEnd;
    ToEnd.NextStage = VGQuestRules::EndId();
    Quest->Stages[1].Transitions.Add(ToEnd);
    TestEqual(TEXT("End conclui de qualquer etapa"), VGQuestRules::SelectNextStage(*Quest, 1, NoFacts), INDEX_NONE);

    TestFalse(TEXT("Todos: 1 de 2 não basta"), VGQuestRules::IsStageComplete(EVGStageCompletion::AllRequired, 2, 1));
    TestTrue(TEXT("Todos: 2 de 2"), VGQuestRules::IsStageComplete(EVGStageCompletion::AllRequired, 2, 2));
    TestTrue(TEXT("Qualquer um: 1 de 2"), VGQuestRules::IsStageComplete(EVGStageCompletion::AnyRequired, 2, 1));
    TestTrue(TEXT("Sem obrigatórios: passagem"), VGQuestRules::IsStageComplete(EVGStageCompletion::AllRequired, 0, 0));
    return true;
}

#endif
```

---

## Projeto 6 — o Turno da Noite como quest

🔁 A segunda etapa da refatoração. Depois do rádio (Capítulo 44), sai do Level Blueprint a **sequência**.

### Os objetivos

| Asset | Canal | Contexto | Título na HUD |
|---|---|---|---|
| `DA_Obj_S1_Livro` | `Event.Item.Collected` | `Item.Document.Logbook` | Encontre o livro de ocorrências |
| `DA_Obj_S1_PortaControle` | `Event.Trigger.Entered` | `Location.S1.ControlDoor` | Chegue à sala de controle |
| `DA_Obj_S1_Disjuntores` | `Event.Sector.Powered` | `Sector.S1.ControlRoom` | Religue os disjuntores do subsolo |
| `DA_Obj_S1_EntrarControle` | `Event.Trigger.Entered` | `Location.S1.ControlRoom` | Entre na sala de controle |
| `DA_Obj_S1_Painel` | `Event.Dialogue.Finished` | `Dialogue.Radio.S1.Final` | Examine o painel principal |

O último objetivo tem um título que descreve o que a jogadora faz ("examine o painel") e um critério que descreve quando o momento acabou (a última fala de Sônia terminou). A diferença é deliberada: a cinemática e a fala acontecem entre uma coisa e a outra, e a quest só deve concluir quando a cena terminar.

### A quest: `DA_Quest_S1_NightShift` (`Quest.S1.NightShift`)

| Etapa | Diário | Objetivos | Concluída se | Ao entrar | Ao concluir |
|---|---|---|---|---|---|
| `Investigar` | "O turno C desapareceu em 1994. Procure registros da última noite; a sala de controle fica no fim do corredor." | `Livro` (ao concluir: fato `Document.Logbook.Read`, conversa `Livro`); `PortaControle` (ao concluir: conversa `PortaSemEnergia`) | — | conversa `Chegada` | — |
| `Disjuntores` | "Os disjuntores ficam no depósito do subsolo. A ordem certa deve estar no livro." | `Disjuntores` | `TEM S1.BreakersRestored` | — | conversa `Disjuntores` (Cap. 44) |
| `SalaDeControle` | "A sala de controle tem energia." | `EntrarControle` | — | — | — |
| `Painel` | "Os painéis estão acesos." | `Painel` | — | — | — |

Ao concluir a quest: fato `S1.Completed` e sinal `Signal.S1.ChapterEnd`.

**Conteúdo novo.** A conversa `DA_Dlg_S1_PortaSemEnergia` ganha um segundo nó, condicionado a `NÃO TEM Document.Logbook.Read`: *"E procura o livro de ocorrências. Se alguém anotou como religar isso, foi lá."* É a variante que fecha o buraco da dor 5 do lado da narrativa.

### O que sobra no Level Blueprint

- **Uma linha no `BeginPlay`:** `Start Quest (DA_Quest_S1_NightShift)`.
- **O puzzle dos disjuntores**, que ao ser resolvido agora **concede o fato** `S1.BreakersRestored` e energiza o setor da sala de controle (o `AVGSector` publica `Event.Sector.Powered` com `Sector.S1.ControlRoom`, Capítulo 24). O puzzle ainda é cola de nível: um ator de puzzle reutilizável é o desafio do Capítulo 50.
- **A sequência do susto**, agora inscrita no `OnTriggered` de um gatilho configurado com fatos (seção 6). As variáveis `bSustoArmado` e `bSustoAconteceu` desaparecem.
- **A cinemática final**, disparada pelo painel. A fala final de Sônia vem pela quest? Não: ela é pedida pelo Level Blueprint ao fim da sequência, como antes, porque o tempo dela pertence à cinemática (Capítulo 49).
- **O fade "FIM DO CAPÍTULO 1"**, que agora reage ao sinal `Signal.S1.ChapterEnd` em vez de esperar um `Delay` no fim da sequência.

As variáveis `bLeuLivro`, `bPegouChave` e `PassoPuzzle`, os `Branch` de ordem e os `ActivateObjective` espalhados saem do grafo.

### O inventário de dores, atualizado

| # | Dor | Situação depois do Cap. 45 |
|---|---|---|
| 5 | Ordem de beats não garantida | ✅ Resolvida: objetivos paralelos na etapa `Investigar`, variante de fala por fato, "concluída se" para o puzzle resolvido fora de ordem |
| 7 | Gatilhos que "lembram" errado | ✅ Resolvida: o gatilho do susto é condicionado a fatos e registra o próprio disparo como fato |
| 12 | O Level Blueprint cresce sem controle | 🟡 Em grande parte: sobram o puzzle, a sequência do susto e a cinemática (Caps. 49–50) |
| 4 | Ramificação vira `Branch` espalhado | 🟡 Transições por fato existem; o setor 1 quase não ramifica. Consequências tardias: Cap. 47 |
| 8 | Nada é reutilizável | 🟡 Quests, objetivos, conversas e ações servem a qualquer setor; o puzzle ainda não |
| 9 | Nada é testável | 🟡 Regras testadas; `VGQuestJump` + `VGAddFact` montam qualquer estado da quest |
| 1, 2 | Estado espalhado; impossível salvar | Fatos com casa provisória e quests sem persistência: Caps. 46 e 56 |
| 6 | Sequências sem cancelamento | Cap. 49 |

---

## Decisões arquiteturais

1. **Quest como dados**: etapas (ordem obrigatória), objetivos paralelos (ordem livre), condições, transições e ações. Nenhuma quest é código.
2. **Objetivos do Capítulo 31 reaproveitados** como unidade de progresso; a quest é o controlador que o Capítulo 31 deixou em aberto.
3. **Fatos como memória, eventos como momento**: mudanças importantes são registradas como fatos, e etapas podem concluir por fatos ("concluída se").
4. **Regras do mundo ficam fora das quests**: reações ambientes (o susto) são gatilhos condicionados a fatos.
5. **Ações como objetos instanciados no asset** (Command declarativo), imutáveis em runtime; **sinais** como escotilha para o nível.
6. **Toda mutação de quest numa fila processada no tick seguinte**, fora de qualquer notificação, com limite de trabalho por tick.
7. **Transições avaliadas depois das ações de conclusão.**
8. **Simplificações declaradas**: estado por mundo, sem persistência, quests não repetíveis, fatos ainda no subsistema de diálogo, todos com destino marcado (Caps. 46 e 56).

---

## Armadilhas

- **Etapa onde deveria haver objetivos paralelos.** Toda dependência de ordem que não existe no mundo é um buraco esperando uma jogadora que explora "errado".
- **Objetivo que espera um evento que já passou.** Se algo pode acontecer antes da etapa, registre um fato e use "concluída se".
- **Mutar quests dentro de uma notificação.** Ativar, cancelar ou concluir dentro do anúncio de outro sistema é reentrância, e o crash aparece longe da causa.
- **Guardar referência a um elemento de array através de código que pode adicionar elementos.** Ações que iniciam quests realocam a lista.
- **Recompensa que referencia o nível no asset.** Data Assets não sabem em que mapa estão: use um sinal.
- **Colocar regras do mundo dentro da quest.** O susto, o Diretor e as luzes não são passos de quest; acoplá-los ao roteiro torna cada mudança de roteiro perigosa.
- **Quest que só pode ser testada jogando do começo.** Sem salto de etapa e sem forçar fatos, cada variante custa uma partida inteira.
- **Título de objetivo que mente.** "Examine o painel" que conclui ao examinar, enquanto a cena ainda está tocando, faz a HUD avançar antes da história. O título descreve a ação; o critério descreve quando o momento terminou.
- **Etapas de passagem em laço.** Duas etapas sem objetivos que transitam uma para a outra nunca param. O limite por tick transforma isso num erro visível; a validação pode alertar no editor (exercício).

---

## Exercício

**Parte 1 — dados, regras e teste (1,5 h).** Implemente `UVGQuestAction` e as quatro ações, `UVGQuestData` com `IsDataValid`, `VGQuestRules` e o teste. Crie uma quest inválida de propósito (transição para etapa inexistente, objetivo repetido) e confira as mensagens.

**Parte 2 — o subsistema (2 h).** Implemente `UVGQuestSubsystem` com a fila de trabalho, `DescribeForDebug`, `vg.Debug.Quests` e o cheat `VGQuestJump`. Num nível de teste, monte uma quest de três etapas com uma etapa de passagem que ramifica por um fato. Verifique com `vg.Debug.Quests`:
- a ramificação muda com `VGAddFact`;
- um objetivo opcional é cancelado quando a etapa termina;
- uma ação "Iniciar quest" dentro de um `OnComplete` não quebra nada;
- duas etapas de passagem em laço disparam o `ensure`, e não travam o editor.

**Parte 3 — migração (2 h).** Monte os objetivos, a quest e a variante da conversa da porta conforme o Projeto 6. Configure o gatilho do susto com fatos. Reduza o Level Blueprint ao que a seção "O que sobra" descreve. Jogue o capítulo **fora de ordem** pelo menos três vezes:
- primeiro a porta, depois o livro;
- o puzzle resolvido por tentativa antes de ler o livro;
- direto da porta para o subsolo.

Registre no `DEVLOG.md` o que a jogadora ouve em cada caso.

**Parte 4 — diário (45 min).** Crie um `WBP_Diario` que escuta `OnQuestChanged` e mostra o título da quest e o resumo da etapa, acima da lista de objetivos da HUD do Capítulo 31. A HUD formal é o Capítulo 55; aqui basta o texto.

---

## Desafio — "Os seis do turno C"

Desenhe e implemente uma **quest secundária opcional** para o setor 1:

1. Seis crachás dos homens do turno C de 1994 estão espalhados pela Casa de Força, cada um com o nome e uma linha sobre a pessoa (escreva-as: um traço de personalidade cada, como o documento de narrativa pede).
2. A quest começa sozinha quando a jogadora lê o livro de ocorrências (`StartCondition: TEM Document.Logbook.Read`, iniciada por uma ação no `OnCompleted` do objetivo do livro).
3. Uma etapa com um objetivo de contagem (6 crachás, `Event.Item.Collected`, contexto `Item.Badge`). Cada crachá concede um fato próprio, para o setor 2 poder citar quem a jogadora "conheceu".
4. Ao concluir: o fato `S1.AllBadgesFound`, e a fala final de Sônia ganha uma variante curta para quem encontrou todos.
5. Se a quest principal concluir antes, a secundária **não** falha. Ela continua no setor 2? Decida, justifique no `DEVLOG.md` e observe o que isso exige da persistência (Capítulo 46).

---

## Uso de IA

1. **Para auditar uma quest:**
   > "Aqui está uma quest de jogo como dados: etapas com objetivos (obrigatórios ou opcionais), condições 'concluída se', transições condicionadas a fatos e ações. Encontre: ordens de exploração em que a jogadora fica sem objetivo ativo, eventos que podem acontecer antes da etapa que os espera, etapas sem saída, falas condicionadas que nunca podem tocar e fatos concedidos que ninguém lê. [quest + objetivos + conversas]"

2. **Para revisar a reentrância:**
   > "Revise este subsistema de quests da Unreal Engine 5. Ele recebe notificações de um subsistema de objetivos que itera a própria lista enquanto notifica. Procure: mutações durante notificações, referências a elementos de TArray mantidas através de chamadas que podem adicionar elementos, laços infinitos possíveis entre etapas, e ordem de efeitos (fatos concedidos antes ou depois das transições). [código]"

3. **Para desenhar a ordem livre:**
   > "Tenho um capítulo de jogo de terror com estas peças: [lista de locais, itens, portas e dependências reais]. Separe as dependências REAIS (o mundo impede) das dependências de roteiro (o autor prefere). Proponha etapas só para as reais e objetivos paralelos para o resto, e aponte que falas precisariam de variantes para cada ordem possível."

**Cuidado específico:** a IA tende a propor sistemas de quests de RPG grande (árvores de diálogo com reputação, journals com dezenas de estados, recompensas de XP), porque é o que mais aparece nos dados de treino. Peça explicitamente o mínimo para o seu jogo, e confira cada sugestão contra o critério do "terceiro caso".

---

## Checklist

- [ ] Sei descrever uma quest como processo de longa duração guiado por eventos, e onde a analogia com sagas cai.
- [ ] Sei separar ordem obrigatória (etapas) de ordem livre (objetivos paralelos).
- [ ] Sei por que eventos se perdem e fatos não, e uso "concluída se" para eventos fora de hora.
- [ ] Sei separar quests (o que a jogadora persegue) de regras do mundo (como o mundo reage a fatos).
- [ ] Implementei ações como objetos instanciados e sei usar sinais como escotilha para o nível.
- [ ] Sei explicar e implementar a fila de trabalho contra reentrância.
- [ ] Migrei a sequência do *Turno da Noite* para uma quest, e as dores 5 e 7 estão resolvidas.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Data Assets** e **Asset Manager** (primary assets), e os especificadores de classe e propriedade **`EditInlineNew`**, **`DefaultToInstanced`** e **`Instanced`**.
- **Documentação do Creation Kit** (a wiki oficial da Bethesda para o Creation Kit): as páginas sobre quests, etapas e objetivos são um bom estudo de um sistema de quests de produção.
- **GDC Vault** (gdcvault.com): palestras de narrative design e de *mission scripting* sobre a estrutura de missões em jogos de mundo aberto e em jogos narrativos.

---

➡️ **Próximo:** [Capítulo 46 — Narrative State](cap-46-narrative-state.md)

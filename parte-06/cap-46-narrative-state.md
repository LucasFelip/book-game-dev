# Capítulo 46 — Narrative State

## Objetivo

Ao final deste capítulo você deve conseguir:

- definir **estado narrativo** e separar **fato** (algo que aconteceu) de **estado** (algo que é agora);
- escolher a forma de cada informação narrativa: *flag*, contador, grupo exclusivo, registro de quest;
- criar um **dono único** do estado narrativo que sobreviva à troca de nível (`UGameInstanceSubsystem`);
- **derivar fatos de eventos** por regras de dados, em vez de conceder fatos à mão em cada lugar;
- fazer o estado **anunciar mudanças**, para que condições sejam reavaliadas quando um fato muda;
- produzir uma ***snapshot*** completa e versionada do estado narrativo, pronta para o save do Capítulo 56;
- migrar diálogo, quests e gatilhos para o novo dono, resolvendo a dor 1 do Interlúdio I e preparando a dor 2.

---

## Contexto

Os Capítulos 44 e 45 usaram **fatos narrativos** (`Narrative.Fact.*`) como a linguagem comum entre sistemas: o diálogo escolhe variantes por fatos, as quests ramificam e concluem por fatos, e o gatilho do susto existe ou não conforme os fatos. Mas os fatos ficaram, por decisão declarada, numa casa provisória: o subsistema de diálogo. Hoje eles têm **três leitores**, e pelo critério do "terceiro caso" (Capítulo 6) é a hora de dar a eles um dono próprio.

O Capítulo 45 deixou cinco pendências, e este capítulo resolve quatro:

1. **Os fatos moram no lugar errado**, e o subsistema de diálogo virou, sem querer, um registro global.
2. **Fatos derivados de eventos são concedidos à mão**. O puzzle concede `S1.BreakersRestored`, e o objetivo do livro concede `Document.Logbook.Read`. Esquecer uma dessas linhas é um bug silencioso.
3. **"Concluída se" só é reavaliada em momentos específicos**, porque nada avisa quando um fato muda.
4. **Nada persiste**: fatos, falas ditas, conversas tocadas e quests vivem num `UWorldSubsystem` e morrem na troca de nível.

A quinta pendência, se a quest dos crachás continua no setor 2, é uma decisão de design que este capítulo torna **possível**, e que fica para você.

E há duas dores do Interlúdio I que dependem diretamente do estado narrativo:

- **Dor 1:** estado narrativo espalhado e invisível. Hoje está concentrado, mas no dono errado e sem visibilidade.
- **Dor 2:** impossível salvar. Ninguém sabe dizer "o que aconteceu até agora" numa estrutura só.

---

## 46.1 O que é estado narrativo

Estado narrativo é **tudo o que o jogo precisa lembrar sobre a história da jogadora** para continuar contando-a de forma coerente:

- o que ela **descobriu** (leu o memorando, viu a turbina girando);
- o que ela **fez** (religou os disjuntores, encontrou quatro crachás);
- o que ela **disse** (admitiu a Sônia que religou a três);
- o que o jogo já **contou** (falas ditas, conversas tocadas);
- **onde ela está** em cada quest.

Não é estado narrativo:

- **a posição da jogadora, a vida, a munição**: estado de gameplay, salvo pelo sistema de save (Capítulo 56), mas não consultado pela história;
- **se uma porta está aberta ou se uma caixa foi empurrada**: estado de mundo, assunto da persistência (Capítulo 57);
- **o que a Presença está fazendo agora**: estado de simulação, efêmero.

A fronteira importa porque o estado narrativo tem propriedades especiais. É **pequeno** (dezenas a centenas de entradas, não milhares), é **consultado por todo o jogo** (falas, quests, gatilhos, documentos, cinemáticas, o final), **atravessa níveis** e **precisa sobreviver** ao save.

### Fato e estado

Uma distinção ajuda a manter esse estado simples:

- **Fato**: algo que **aconteceu**. *"Helena leu o memorando."* Fatos são **monotônicos**: uma vez verdadeiros, continuam verdadeiros. A história não volta atrás.
- **Estado**: algo que **é agora** e pode mudar. *"Sônia confia em Helena: pouco / razoável / muito."*

A regra prática da Vigília é **prefira fatos**. Um conjunto que só cresce é fácil de salvar, de testar, de depurar ("por que esta fala tocou?" → "porque estes fatos existiam") e de raciocinar: nada desfaz nada. Quando algo realmente varia, use uma forma explícita para isso (seção 46.2), e não uma *flag* que alguém lembra de desligar.

> 🌉 **Ponte:** um conjunto de fatos monotônicos lembra um ***event store*** do qual só se guarda a projeção: "o que aconteceu" e não "o que é". Condições sobre fatos são consultas sobre essa projeção.
>
> 🧱 **Onde a ponte cai:** um *event store* guarda a **sequência**, com tempo e ordem, e permite reconstruir qualquer projeção. O estado narrativo guarda só o **conjunto**: "leu o memorando", não "leu o memorando às 23h10, antes do livro". Se a ordem importar para a história, ela precisa virar um fato próprio (`Memo.ReadBeforeLogbook`). Guardar a linha do tempo inteira raramente compensa o custo.

---

## 46.2 Formas de estado narrativo

Nem tudo é um booleano. Quatro formas cobrem quase todos os casos de um jogo narrativo do tamanho da Vigília:

| Forma | Exemplo | Representação | Consultável em condições de dados? |
|---|---|---|---|
| ***Flag* (fato)** | Leu o memorando | Gameplay Tag num conjunto | Sim (`FGameplayTagQuery`) |
| **Contador** | Crachás encontrados: 4 | `TMap<FGameplayTag, int32>` | Indiretamente: um **fato de limiar** ("6 crachás") é concedido quando o contador chega lá |
| **Grupo exclusivo** | Confiança de Sônia: `Low`/`Mid`/`High` | Tags irmãs sob um pai, das quais só uma existe por vez | Sim |
| **Registro de quest** | Quest do setor 1: na etapa `Disjuntores` | `{tag, asset, status, etapa}` | Pelas quests e pelos fatos que elas concedem |

Ficam **de fora**, de propósito:

- **Strings livres** ("o nome que a jogadora escolheu para o gato"): não há onde usá-las com segurança numa condição, e elas viram dado de save comum.
- **Valores contínuos** (`float SoniaTrust = 0.63`): condições sobre *floats* espalham limiares mágicos pelo conteúdo. Se a confiança importa, ela tem **níveis** com nome, num grupo exclusivo, e a regra que muda o nível fica num lugar só.
- **Datas e ordem**: a não ser que a história dependa delas (seção 46.1).

### Por que tags, e não um *struct* com campos

A alternativa "tipada" seria um *struct* C++ com um campo por variável da história: `bool bReadMemo; bool bAdmittedTurbine3; int32 Badges;`. Ela tem verificação em tempo de compilação, mas cada variável nova exige código, compilação e uma versão nova do save. A história de um jogo muda **todos os dias** durante a produção, e quem a muda é quem escreve, não quem programa. Tags são criadas no editor, consultadas por dados e salvas como nomes. O preço é a disciplina de nomes (`docs/design/fatos.md`) e a validação de conteúdo.

---

## 46.3 Um dono que atravessa níveis

O estado narrativo precisa viver **mais** que um nível: a jogadora sai do Pátio, entra na Casa de Força, volta, vai ao setor 2, e o que aconteceu no setor 1 tem de continuar verdadeiro. Na Unreal, o objeto que vive a sessão inteira de jogo é o `UGameInstance`, e a forma idiomática de pendurar um sistema nele é um **`UGameInstanceSubsystem`** (Capítulo 6).

```text
  UGameInstance (sessão inteira)
   └── UVGNarrativeSubsystem       ← DONO: fatos, contadores, memória, registros de quest
                                      anuncia mudanças; produz e restaura snapshot
  UWorld (um nível)
   ├── UVGDialogueSubsystem         ← LÊ fatos, MARCA falas ditas
   ├── UVGQuestSubsystem            ← LÊ fatos, ESCREVE registros, reage a mudanças
   ├── UVGFactRulesSubsystem        ← traduz eventos do barramento em fatos (regras de dados)
   └── AVGEventTrigger (atores)     ← LÊ fatos, CONCEDE fato ao disparar
```

Quem mora no **mundo** (diálogo, quests, regras) é recriado a cada nível e **reconstrói** o que precisa a partir do dono. O dono não sabe que eles existem: ele só anuncia.

> 🌉 **Ponte:** é um *bean* de escopo de aplicação (*singleton*) num contexto Spring, com serviços de escopo de requisição que o consultam.
>
> 🧱 **Onde a ponte cai:** o "escopo de aplicação" aqui é a **sessão de jogo**. Ele começa ao abrir o jogo (ou ao apertar Play no editor, onde **cada** sessão de PIE ganha um `UGameInstance` novo) e não termina no "novo jogo": o menu principal e uma partida nova vivem na mesma instância. Por isso o dono precisa de um `ResetForNewGame()` explícito. Esquecê-lo é o bug clássico de "comecei um jogo novo e Sônia lembra do memorando".

---

## 46.4 Fatos derivados de eventos

Até aqui, cada fato tinha um **concessor manual**: a ação de quest do livro, o Level Blueprint do puzzle, o próprio gatilho. Funciona, mas espalha uma regra da história ("pegar o livro é ter lido o livro") por lugares diferentes, e a regra quebra em silêncio quando alguém cria um segundo caminho para pegar o livro.

A alternativa é um **conjunto de regras de dados** que traduz eventos do barramento em fatos:

```text
 QUANDO o evento...                          ENTÃO...
 Event.Item.Collected  ctx Item.Document.Logbook  →  fato  Document.Logbook.Read
 Event.Sector.Powered  ctx Sector.S1.ControlRoom  →  fato  S1.BreakersRestored
 Event.Item.Collected  ctx Item.Badge             →  contador S1.Badges +1;  em 6 → fato S1.AllBadgesFound
 Event.Quest.Completed ctx Quest.S1.NightShift    →  fato  S1.Completed
```

As regras vivem num Data Asset (`DA_FatosDoJogo`) apontado pelas configurações do projeto. Um sistema pequeno de mundo escuta o barramento e as aplica. O resultado é que **o puzzle não precisa mais conceder fato nenhum**: ele energiza o setor, o setor publica o evento, e a regra registra o fato. Quem programa o puzzle não precisa saber que a história se importa com ele.

Nem todo fato vem de uma regra. Escolhas de diálogo concedem fatos diretamente (Capítulo 44), e o gatilho do susto também (Capítulo 45), porque ali o fato **é** a consequência da coisa, e não um registro de um evento genérico. A regra de bolso: **se o fato é "isto aconteceu no mundo", use regra; se é "esta escolha/este momento narrativo aconteceu", conceda no próprio dado.**

---

## 46.5 Anunciar mudanças

Um dono de estado que não anuncia obriga todo mundo a **perguntar** de vez em quando, e foi o que limitou o "concluída se" do Capítulo 45, reavaliado só ao entrar na etapa e ao concluir objetivos. Com um anúncio `OnFactChanged(Fact, bAdded)`, qualquer sistema pode reagir **na hora**.

Duas regras, ambas vindas do Capítulo 4:

1. **Estado consistente, depois anúncio.** O fato entra no conjunto **antes** de o anúncio sair. Quem reage já vê o mundo novo.
2. **Ouvintes não mutam o estado dentro do anúncio.** O subsistema de quests já respeita isso: ele só **enfileira** uma reavaliação (Capítulo 45, seção 45.5). Um ouvinte que concede outro fato dentro do anúncio cria uma cascata recursiva. É permitido, mas o dono precisa de um limite de profundidade, como o barramento do Capítulo 24.

O anúncio é discreto (um fato entrou ou saiu), nunca contínuo, porque fatos não mudam a cada quadro (Capítulo 4: eventos para transições, consulta para valores contínuos).

---

## 46.6 A *snapshot*

Salvar o jogo, para o estado narrativo, deveria ser uma operação de **uma linha**: "me dê tudo o que você sabe, numa estrutura que eu consiga serializar". Isso só é possível se o estado inteiro estiver **num só lugar** e numa **estrutura de dados simples**: tags, mapas de tags para inteiros, conjuntos de nomes, registros de quest com referências *soft* aos assets.

O desenho da Vigília leva isso ao extremo: **o estado narrativo é um `USTRUCT`** (`FVGNarrativeState`), e o subsistema é só o dono desse *struct*, com regras de acesso e anúncios. Capturar é copiar o *struct*; restaurar é substituí-lo e avisar que tudo mudou. O Capítulo 56 serializa esse *struct* com o sistema de reflexão, e o desafio deste capítulo exporta-o como JSON.

Três cuidados:

- **Versão.** O *struct* tem um campo `Version`. Quando o formato mudar (um campo novo, uma tag renomeada), o loader sabe que está diante de uma snapshot antiga. O Capítulo 56 trata de migração de saves.
- **Referências *soft*** para assets (a quest de um registro): o save guarda o **caminho** do asset, não um ponteiro. O asset é carregado ao restaurar.
- **Nomes de tags são contrato.** Renomear `Narrative.Fact.Document.Memo.Read` quebra saves antigos. A Unreal tem redirecionamento de tags (*Gameplay Tag Redirects* nas configurações do projeto, ⚠️ confira na sua versão), e a regra do projeto é: **nunca renomeie um fato publicado; redirecione**.

---

## Estudos de caso

### The Walking Dead (Telltale) — o estado tornado visível

**[FATO PÚBLICO]** Em *The Walking Dead* (Telltale Games, 2012), certas escolhas do jogador são seguidas por uma notificação na tela, como *"Clementine will remember that."* ("Clementine vai se lembrar disso"). A frase ficou tão associada ao estúdio que virou referência cultural fora dos jogos.

**[INFERÊNCIA]** A notificação não muda nenhum sistema: ela **mostra** que uma informação entrou no estado narrativo. O efeito é de agência percebida (Capítulo 43): o jogador sente que a escolha foi registrada antes de ver qualquer consequência, e a expectativa da consequência vira tensão. É uma interface para o estado narrativo, não para o enredo.

**Lição para a Vigília:** o estado narrativo é invisível por natureza, e às vezes vale torná-lo visível, com cuidado, porque o terror vive de não saber. A Vigília não vai mostrar notificações, mas o mesmo princípio vale para o desenvolvimento: um painel de depuração com os fatos atuais (`vg.Debug.Narrative`) é a interface que **você** precisa para entender por que uma fala tocou.

### Fallen London — narrativa baseada em qualidades

**[FATO PÚBLICO]** A Failbetter Games, criadora de *Fallen London*, popularizou o termo ***quality-based narrative*** (narrativa baseada em qualidades): o estado do jogador é um conjunto de **qualidades** (valores com nome, quase sempre numéricos), e cada trecho de história (um *storylet*) declara as qualidades que exige e as que altera. O conceito foi discutido publicamente por desenvolvedores do estúdio e por designers narrativos como Emily Short, que escreveu sobre *storylets* em seu blog.

**[INFERÊNCIA]** O desenho troca o grafo de história por **estado + condições**: em vez de "depois do nó A vem o nó B", cada conteúdo diz "eu existo quando o estado é este". Conteúdo novo é acrescentado sem reescrever o grafo, porque ele se encaixa por condições.

**Lição para a Vigília:** é o mesmo princípio das falas condicionadas (Capítulo 44) e das etapas por fato (Capítulo 45), levado ao limite. A Vigília usa um meio-termo: estrutura explícita (quests com etapas) para o que precisa de ordem, e conteúdo por condição (variantes, documentos opcionais, comentários de Sônia) para todo o resto. As **qualidades numéricas** dela são os contadores, e os **limiares** viram fatos.

### Jogos de mundo aberto — o mundo que muda depois da missão

**[FATO PÚBLICO — observável jogando]** Em jogos de mundo aberto como os GTA, o mundo muda de forma duradoura depois de certas missões: áreas são liberadas, personagens deixam de aparecer em certos lugares, lojas e propriedades mudam de estado.

**[INFERÊNCIA]** Isso exige que o estado de progresso (missões concluídas, escolhas) seja **consultável pelo mundo**, e não só pelo sistema de missões: o spawner de personagens, a porta da loja e o rádio perguntam "isto já aconteceu?". É exatamente a separação entre o dono do estado e os seus muitos leitores.

**Lição para a Vigília:** cada setor vai ler fatos dos anteriores. O documento do setor 2 menciona "as luzes andando" só se `S1.ScareDone` existir, e a Presença do setor 3 se comporta diferente se a jogadora nunca usou o sinalizador. O estado narrativo é a memória que atravessa o jogo; o Interlúdio II volta a esse tema em escala de mundo aberto.

---

## Comparação com o desenvolvimento tradicional

| Estado narrativo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Fatos monotônicos | *Event store* (só a projeção) | Sem sequência nem tempo; a ordem, quando importa, vira um fato |
| Dono no `UGameInstance` | *Bean* singleton de aplicação | A "aplicação" é a sessão de jogo; "novo jogo" não reinicia o processo |
| Regras evento → fato | Projeções/*handlers* de eventos | Escritas como **dados** por designers, não como código |
| Anúncio de mudança | *Change data capture*, observadores | Síncrono, na mesma thread; o perigo é a recursão, não a ordem de entrega |
| *Snapshot* versionada | DTO de persistência com versão de schema | Os nomes das tags são o schema, e renomear é migração |
| Tags em vez de campos | Mapa chave-valor × entidade tipada | A flexibilidade serve a quem escreve a história; o preço é a disciplina de nomes |

---

## Unreal Engine: o que existe

- **`UGameInstanceSubsystem`**: um sistema por instância de jogo, criado e destruído com o `UGameInstance`. Acessível de qualquer objeto com mundo, via `GetGameInstance()->GetSubsystem<T>()`.
- **Gameplay Tags**, com `FGameplayTagContainer` (o conjunto), `FGameplayTagQuery` (condições) e `Filter`/`RemoveTags` (grupos exclusivos), mais **redirecionamento de tags** nas configurações do projeto.
- **`UDeveloperSettings`**: uma classe de configurações que aparece em *Project Settings* e é salva em `.ini`. É onde o projeto aponta o asset de regras (`DA_FatosDoJogo`) sem que nenhum nível precise configurá-lo. A classe mora no módulo `DeveloperSettings`, que precisa entrar no `Build.cs`.
- **Reflexão de `USTRUCT`** para serializar a *snapshot*: com o `USaveGame` (Capítulo 56), ou como JSON com `FJsonObjectConverter` (módulo `JsonUtilities`) no desafio.
- **`TSoftObjectPtr`** para referências a assets que podem não estar carregados.

---

## Abordagens

| Critério | A. Variáveis espalhadas (Interlúdio I) | B. Dicionário de strings (`FName` → `FString`) | **C. Fatos (tags) + contadores + grupos + registros** | D. *Struct* C++ com um campo por variável |
|---|---|---|---|---|
| **Complexidade** | Nenhuma no começo, alta depois | Baixa | Baixa | Baixa por campo, alta no total |
| **Segurança** | Nenhuma | Nenhuma: erros de digitação viram fatos novos | Tags validadas pelo editor; condições com seletor de tag | Total, em tempo de compilação |
| **Quem pode criar estado** | Quem abre o Blueprint | Qualquer um | Designers, no editor | Só programadores |
| **Save** | Impossível (dor 2) | Fácil | Fácil: uma *snapshot* | Fácil, mas cada campo novo muda o formato |
| **Consulta por dados** | Não | Frágil (parsing) | Nativa (`FGameplayTagQuery`) | Exige código ou reflexão |
| **Adequação à Vigília** | Foi a dor | Não | **Sim** | Não: a história muda todo dia |

**Decisão: C**, com um dono único no `UGameInstance`, regras de dados para fatos derivados e uma *snapshot* versionada.

---

## Implementação

### 1. O estado como dado

```cpp
// Source/Vigilia/Narrative/VGNarrativeTypes.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGQuestTypes.h"
#include "VGNarrativeTypes.generated.h"

class UVGQuestData;

/** Onde uma quest está, de forma salvável. */
USTRUCT(BlueprintType)
struct FVGQuestRecord
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Narrative")
    FGameplayTag QuestTag;

    /** Soft: o save guarda o caminho do asset, não um ponteiro. */
    UPROPERTY(BlueprintReadOnly, Category = "Narrative")
    TSoftObjectPtr<UVGQuestData> Quest;

    UPROPERTY(BlueprintReadOnly, Category = "Narrative")
    EVGQuestStatus Status = EVGQuestStatus::Inactive;

    UPROPERTY(BlueprintReadOnly, Category = "Narrative")
    FName StageId;
};

/**
 * TODO o estado narrativo, num só struct: é o estado em runtime E a snapshot do save.
 * Fatos são monotônicos por convenção; RemoveFact existe só para grupos exclusivos e depuração.
 */
USTRUCT(BlueprintType)
struct FVGNarrativeState
{
    GENERATED_BODY()

    // SaveGame: marca o que a serialização de save inclui (Cap. 56). Todo campo aqui é salvo.

    /** Sobe a cada mudança de formato (Cap. 56: migração de saves). */
    UPROPERTY(SaveGame)
    int32 Version = 1;

    UPROPERTY(SaveGame)
    FGameplayTagContainer Facts;

    UPROPERTY(SaveGame)
    TMap<FGameplayTag, int32> Counters;

    /** Chaves "Conversa.Nó" (Cap. 44). */
    UPROPERTY(SaveGame)
    TSet<FName> SaidLines;

    UPROPERTY(SaveGame)
    TSet<FName> PlayedConversations;

    UPROPERTY(SaveGame)
    TArray<FVGQuestRecord> Quests;

    /** true se o fato era novo. */
    bool AddFact(FGameplayTag Fact);

    /** Remove as irmãs de Value sob Group e acrescenta Value. Devolve os fatos removidos. */
    FGameplayTagContainer SetExclusive(FGameplayTag Group, FGameplayTag Value);

    /** Novo valor do contador. */
    int32 AddToCounter(FGameplayTag Counter, int32 Delta);

    /** Substitui o registro da mesma quest, ou acrescenta. */
    void RecordQuest(const FVGQuestRecord& Record);
};
```

```cpp
// Source/Vigilia/Narrative/VGNarrativeTypes.cpp
#include "Narrative/VGNarrativeTypes.h"

bool FVGNarrativeState::AddFact(FGameplayTag Fact)
{
    if (!Fact.IsValid() || Facts.HasTagExact(Fact))
    {
        return false;
    }
    Facts.AddTag(Fact);
    return true;
}

FGameplayTagContainer FVGNarrativeState::SetExclusive(FGameplayTag Group, FGameplayTag Value)
{
    // Filter devolve os fatos que são o grupo OU estão abaixo dele (comparação hierárquica).
    FGameplayTagContainer Siblings = Facts.Filter(FGameplayTagContainer(Group));
    Siblings.RemoveTag(Value);
    Facts.RemoveTags(Siblings);
    Facts.AddTag(Value);
    return Siblings;
}

int32 FVGNarrativeState::AddToCounter(FGameplayTag Counter, int32 Delta)
{
    int32& Value = Counters.FindOrAdd(Counter);
    Value += Delta;
    return Value;
}

void FVGNarrativeState::RecordQuest(const FVGQuestRecord& Record)
{
    if (FVGQuestRecord* Existing = Quests.FindByPredicate(
            [&Record](const FVGQuestRecord& R) { return R.QuestTag == Record.QuestTag; }))
    {
        *Existing = Record;
    }
    else
    {
        Quests.Add(Record);
    }
}
```

O *struct* não sabe de mundo, de anúncios ou de save. É dado com quatro operações, e por isso o teste do capítulo o exercita diretamente.

### 2. O dono

```cpp
// Source/Vigilia/Narrative/VGNarrativeSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Narrative/VGNarrativeTypes.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "VGNarrativeSubsystem.generated.h"

DECLARE_MULTICAST_DELEGATE_TwoParams(FVGFactChangedNative, FGameplayTag /*Fact*/, bool /*bAdded*/);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGFactChangedSignature, FGameplayTag, Fact, bool, bAdded);
DECLARE_MULTICAST_DELEGATE(FVGNarrativeRestoredNative);

/**
 * Dono ÚNICO do estado narrativo: fatos, contadores, memória do diálogo, registros de quest.
 * Vive a sessão inteira (troca de nível incluída). Anuncia mudanças; não conhece quem escuta.
 */
UCLASS()
class VIGILIA_API UVGNarrativeSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    /** Atalho a partir de qualquer objeto com mundo. */
    static UVGNarrativeSubsystem* Get(const UObject* WorldContextObject);

    // --- Fatos
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Narrative")
    void AddFact(FGameplayTag Fact);

    /** Grupo exclusivo: ex. Group = Narrative.State.Sonia.Trust, Value = ...Trust.High. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Narrative")
    void SetExclusiveFact(FGameplayTag Group, FGameplayTag Value);

    /** Só para depuração. Fatos são monotônicos por convenção. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Narrative")
    void RemoveFact(FGameplayTag Fact);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Narrative")
    bool HasFact(FGameplayTag Fact) const { return State.Facts.HasTag(Fact); }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Narrative")
    bool MatchesFacts(const FGameplayTagQuery& Query) const { return Query.IsEmpty() || Query.Matches(State.Facts); }

    const FGameplayTagContainer& GetFacts() const { return State.Facts; }

    // --- Contadores
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Narrative")
    int32 AddToCounter(FGameplayTag Counter, int32 Delta = 1);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Narrative")
    int32 GetCounter(FGameplayTag Counter) const { return State.Counters.FindRef(Counter); }

    // --- Memória do diálogo (Cap. 44)
    void MarkLineSaid(FName Key) { State.SaidLines.Add(Key); }
    const TSet<FName>& GetSaidLines() const { return State.SaidLines; }
    void MarkConversationPlayed(FName Key) { State.PlayedConversations.Add(Key); }
    bool HasPlayedConversation(FName Key) const { return State.PlayedConversations.Contains(Key); }

    // --- Quests (Cap. 45)
    void RecordQuest(const FVGQuestRecord& Record) { State.RecordQuest(Record); }
    const TArray<FVGQuestRecord>& GetQuestRecords() const { return State.Quests; }

    // --- Snapshot (Cap. 56)
    const FVGNarrativeState& CaptureSnapshot() const { return State; }
    void RestoreSnapshot(const FVGNarrativeState& Snapshot);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Narrative")
    void ResetForNewGame();

    FString DescribeForDebug() const;

    FVGFactChangedNative OnFactChangedNative;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Narrative")
    FVGFactChangedSignature OnFactChanged;

    /** O estado inteiro foi trocado (restore, novo jogo): leitores devem se reconstruir. */
    FVGNarrativeRestoredNative OnRestored;

private:
    void Announce(FGameplayTag Fact, bool bAdded);

    UPROPERTY()
    FVGNarrativeState State;

    int32 AnnounceDepth = 0;
};
```

```cpp
// Source/Vigilia/Narrative/VGNarrativeSubsystem.cpp (essencial)
#include "Narrative/VGNarrativeSubsystem.h"

#include "Core/VGLog.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"

static constexpr int32 MaxAnnounceDepth = 8; // fatos que concedem fatos que concedem fatos...

UVGNarrativeSubsystem* UVGNarrativeSubsystem::Get(const UObject* WorldContextObject)
{
    const UWorld* World = GEngine
        ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull)
        : nullptr;
    const UGameInstance* GameInstance = World ? World->GetGameInstance() : nullptr;
    return GameInstance ? GameInstance->GetSubsystem<UVGNarrativeSubsystem>() : nullptr;
}

void UVGNarrativeSubsystem::AddFact(FGameplayTag Fact)
{
    if (State.AddFact(Fact)) // estado primeiro...
    {
        Announce(Fact, true); // ...anúncio depois (Cap. 4)
    }
}

void UVGNarrativeSubsystem::SetExclusiveFact(FGameplayTag Group, FGameplayTag Value)
{
    if (!Value.MatchesTag(Group) || HasFact(Value))
    {
        return; // valor fora do grupo, ou nada muda
    }
    const FGameplayTagContainer Removed = State.SetExclusive(Group, Value);
    for (const FGameplayTag& Old : Removed)
    {
        Announce(Old, false);
    }
    Announce(Value, true);
}

void UVGNarrativeSubsystem::RemoveFact(FGameplayTag Fact)
{
    if (State.Facts.HasTagExact(Fact))
    {
        State.Facts.RemoveTag(Fact);
        Announce(Fact, false);
    }
}

int32 UVGNarrativeSubsystem::AddToCounter(FGameplayTag Counter, int32 Delta)
{
    return Counter.IsValid() ? State.AddToCounter(Counter, Delta) : 0;
}

void UVGNarrativeSubsystem::RestoreSnapshot(const FVGNarrativeState& Snapshot)
{
    // Simplificação: só a versão atual; a migração de versões antigas é o Cap. 56.
    if (!ensureMsgf(Snapshot.Version == State.Version, TEXT("Snapshot narrativa versão %d, esperada %d."),
                    Snapshot.Version, State.Version))
    {
        return;
    }
    State = Snapshot;
    OnRestored.Broadcast();
}

void UVGNarrativeSubsystem::ResetForNewGame()
{
    State = FVGNarrativeState();
    OnRestored.Broadcast();
}

void UVGNarrativeSubsystem::Announce(FGameplayTag Fact, bool bAdded)
{
    if (!ensureMsgf(AnnounceDepth < MaxAnnounceDepth, TEXT("Narrativa: cascata de fatos profunda demais em %s."),
                    *Fact.ToString()))
    {
        return;
    }
    ++AnnounceDepth;
    OnFactChangedNative.Broadcast(Fact, bAdded);
    OnFactChanged.Broadcast(Fact, bAdded);
    --AnnounceDepth;
}
```

### 3. Regras: eventos viram fatos

```cpp
// Source/Vigilia/Narrative/VGFactRuleSet.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Engine/DeveloperSettings.h"
#include "GameplayTagContainer.h"
#include "VGFactRuleSet.generated.h"

struct FVGGameplayEvent;

USTRUCT(BlueprintType)
struct FVGFactRule
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, Category = "Rule", meta = (Categories = "Event"))
    FGameplayTag EventChannel;

    /** Se definido, o contexto do evento precisa ser esta tag ou uma filha. */
    UPROPERTY(EditAnywhere, Category = "Rule")
    FGameplayTag RequiredContext;

    /** Opcional: incrementa este contador a cada evento. */
    UPROPERTY(EditAnywhere, Category = "Rule", meta = (Categories = "Narrative.Counter"))
    FGameplayTag Counter;

    /** Com contador: concede Fact quando ele chega a este valor. 0 = concede a cada evento (sem contador). */
    UPROPERTY(EditAnywhere, Category = "Rule", meta = (ClampMin = "0"))
    int32 FactAtCount = 0;

    UPROPERTY(EditAnywhere, Category = "Rule", meta = (Categories = "Narrative.Fact"))
    FGameplayTag Fact;
};

/** "Quando acontecer X, registre Y": a projeção dos eventos que importam para a história. */
UCLASS(BlueprintType)
class VIGILIA_API UVGFactRuleSet : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, Category = "Rules")
    TArray<FVGFactRule> Rules;
};

/** Project Settings → Vigília — Narrativa. */
UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Vigília — Narrativa"))
class VIGILIA_API UVGNarrativeSettings : public UDeveloperSettings
{
    GENERATED_BODY()

public:
    UPROPERTY(Config, EditAnywhere, Category = "Narrative")
    TSoftObjectPtr<UVGFactRuleSet> FactRules;
};

namespace VGNarrativeRules
{
    /** O evento casa com a regra? (canal e contexto, hierárquicos) */
    bool Matches(const FVGFactRule& Rule, const FVGGameplayEvent& Event);
}
```

```cpp
// Source/Vigilia/Narrative/VGFactRulesSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGFactRulesSubsystem.generated.h"

class UVGFactRuleSet;
struct FVGGameplayEvent;

/** A ponte mundo → narrativa: escuta o barramento do nível e aplica as regras de fatos. */
UCLASS()
class VIGILIA_API UVGFactRulesSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Deinitialize() override;

private:
    void HandleEvent(const FVGGameplayEvent& Event);

    UPROPERTY()
    TObjectPtr<const UVGFactRuleSet> Rules;

    FDelegateHandle EventHandle;
};
```

```cpp
// Source/Vigilia/Narrative/VGFactRulesSubsystem.cpp
#include "Narrative/VGFactRulesSubsystem.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Engine/World.h"
#include "Narrative/VGFactRuleSet.h"
#include "Narrative/VGNarrativeSubsystem.h"

bool VGNarrativeRules::Matches(const FVGFactRule& Rule, const FVGGameplayEvent& Event)
{
    return Event.Channel.MatchesTag(Rule.EventChannel)
        && (!Rule.RequiredContext.IsValid() || Event.Context.MatchesTag(Rule.RequiredContext));
}

void UVGFactRulesSubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
    // Asset pequeno: carga síncrona no início do nível é aceitável.
    Rules = GetDefault<UVGNarrativeSettings>()->FactRules.LoadSynchronous();
    if (UVGGameplayEventSubsystem* Bus = InWorld.GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &UVGFactRulesSubsystem::HandleEvent);
    }
}

void UVGFactRulesSubsystem::Deinitialize()
{
    if (UVGGameplayEventSubsystem* Bus = GetWorld() ? GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>() : nullptr)
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::Deinitialize();
}

void UVGFactRulesSubsystem::HandleEvent(const FVGGameplayEvent& Event)
{
    UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);
    if (!Rules || !Narrative)
    {
        return;
    }
    for (const FVGFactRule& Rule : Rules->Rules)
    {
        if (!VGNarrativeRules::Matches(Rule, Event))
        {
            continue;
        }
        if (!Rule.Counter.IsValid())
        {
            Narrative->AddFact(Rule.Fact);
            continue;
        }
        const int32 Count = Narrative->AddToCounter(Rule.Counter, 1);
        if (Rule.FactAtCount > 0 && Count >= Rule.FactAtCount)
        {
            Narrative->AddFact(Rule.Fact); // monotônico: a partir do limiar, repetir não muda nada
        }
    }
}
```

`Build.cs`: acrescente `"DeveloperSettings"`, o módulo de `UDeveloperSettings`.

### Explicação das decisões

- **O estado é um `USTRUCT`, e o subsistema é o seu dono.** A separação deixa o dado testável sem mundo, serializável com reflexão e capturável com uma cópia. O subsistema só acrescenta regras de acesso e anúncios.
- **`UGameInstanceSubsystem`**, porque o estado narrativo atravessa níveis. Quem mora no mundo (diálogo, quests, regras) consulta o dono e se reconstrói a partir dele.
- **`RemoveFact` existe, mas fica isolado.** Fatos são monotônicos por convenção. A remoção serve a grupos exclusivos (que removem irmãs de forma controlada) e à depuração. O comentário diz isso, e a revisão de código cobra.
- **Grupo exclusivo como operação atômica.** `SetExclusiveFact` remove as irmãs e acrescenta o valor antes de qualquer anúncio. Nenhum ouvinte vê um estado intermediário com dois níveis de confiança ao mesmo tempo, ou com nenhum.
- **Contadores não entram em condições de dados diretamente.** Condições continuam sendo `FGameplayTagQuery` sobre fatos, e o contador gera **fatos de limiar** pela regra. Assim o conteúdo nunca carrega um número mágico ("se crachás ≥ 6"). O número mora numa regra, num lugar só.
- **Profundidade de anúncio limitada**, como no barramento (Capítulo 24): um ouvinte que concede outro fato dentro do anúncio é permitido, mas uma cascata sem fim vira erro visível.
- **`OnRestored` separado de `OnFactChanged`.** Restaurar um save troca o estado inteiro; anunciar centenas de "fato acrescentado" seria lento e enganoso. Os leitores tratam `OnRestored` como "reconstrua tudo".
- **Regras via `UDeveloperSettings`.** A tradução de eventos em fatos é do **jogo**, não de um nível. Configurações de projeto são o lugar certo, e nenhum Level Blueprint precisa lembrar de configurá-las.
- **Versão na snapshot com `ensure`**, sem migração ainda. Um save de formato diferente é recusado de forma visível, e não restaurado pela metade. A migração é o Capítulo 56.

### 4. Os leitores migram

🔁 **Diálogo (Capítulo 44).** O `UVGDialogueSubsystem` perde `Facts`, `SaidLines`, `PlayedConversations`, `AddFact`, `HasFact` e `GetFacts`. Ele passa a consultar o dono:

```cpp
// UVGDialogueSubsystem (trechos alterados)
UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);

// RequestConversation / Begin / TakeBranch:
VGDialogueRules::FindPlayable(*Conversation, Index, Narrative->GetFacts(), Narrative->GetSaidLines());
// bOnce de conversa:
Narrative->HasPlayedConversation(Conversation->GetFName());

// FinishLine: memória e efeitos no dono
Narrative->MarkLineSaid(VGDialogueRules::MemoryKey(*Current.Conversation, Node));
for (const FGameplayTag& Fact : Node.GrantFacts) { Narrative->AddFact(Fact); }

// ChooseOption
for (const FGameplayTag& Fact : Choice.GrantFacts) { Narrative->AddFact(Fact); }

// EndConversation
Narrative->MarkConversationPlayed(Ended->GetFName());
```

Os fatos passam a ser concedidos um a um por `AddFact`, e não mais por `AppendTags`. É assim que cada um gera o seu anúncio.

🔁 **Quests (Capítulo 45).** Quatro mudanças no `UVGQuestSubsystem`:

1. `GetFacts()` passa a ler do dono.
2. **Registros**: `ProcessStart`, `EnterStage` e `FinishQuest` gravam o estado da quest no dono:

```cpp
void UVGQuestSubsystem::SaveRecord(int32 QuestIndex) // chamado ao iniciar, ao entrar em etapa e ao encerrar
{
    const FVGQuestState& S = Quests[QuestIndex];
    FVGQuestRecord Record;
    Record.QuestTag = S.Quest->QuestTag;
    Record.Quest = const_cast<UVGQuestData*>(S.Quest.Get()); // TSoftObjectPtr não aceita const
    Record.Status = S.Status;
    Record.StageId = S.Quest->Stages.IsValidIndex(S.StageIndex) ? S.Quest->Stages[S.StageIndex].Id : NAME_None;
    UVGNarrativeSubsystem::Get(this)->RecordQuest(Record);
}
```

3. **Retomada ao entrar num nível.** Em `OnWorldBeginPlay`, o subsistema enfileira um item novo, `EKind::Resume`, para cada registro `Active`. `ProcessResume` carrega o asset (`Record.Quest.LoadSynchronous()`), cria o estado e entra na etapa gravada. Quests com registro `Completed` ou `Failed` são recusadas por `StartQuest`: "já fiz esta quest" agora vale entre níveis.
4. **Reação a fatos.** O subsistema se inscreve em `OnFactChangedNative` e, a cada mudança, **enfileira** um `CheckStage` para cada quest ativa. O "concluída se" do Capítulo 45 passa a valer a qualquer momento, não só nos momentos em que a quest se mexe. Em `OnRestored`, as quests do mundo são descartadas e reconstruídas a partir dos registros. Duas proteções evitam que uma quest seja retomada duas vezes (pela entrada no nível **e** pelo restore): a inscrição em `OnRestored` acontece no `OnWorldBeginPlay`, depois de enfileirar a retomada, e `ProcessResume` ignora quests que já estão na lista.

⚠️ **Retomar uma etapa executa o `OnEnter` dela de novo.** Isso só é seguro se as ações forem **idempotentes**. Conversas são, porque a memória `bOnce` agora persiste e uma conversa já tocada é recusada. Fatos também, porque são monotônicos. **Sinais não são**: um sinal reemitido ao retomar a etapa dispara a reação do nível de novo. Regra do projeto: `OnEnter` só leva ações idempotentes; sinais vão em `OnComplete`, que só roda uma vez.

🔁 **Gatilhos e cheats.** O `AVGEventTrigger` passa a ler e conceder fatos via `UVGNarrativeSubsystem::Get(this)`. `VGAddFact` vai para o dono, e entram mais três cheats:

```cpp
// UVGCheatManager (adições)
UFUNCTION(Exec) void VGRemoveFact(const FString& TagName);   // depuração de grupos e variantes
UFUNCTION(Exec) void VGNewGame();                            // ResetForNewGame + recarregar o nível
UFUNCTION(Exec) void VGDumpNarrative();                      // DescribeForDebug no log
```

E uma CVar, `vg.Debug.Narrative`, que mostra na tela os fatos atuais (agrupados por prefixo), os contadores e as quests registradas. É o painel que a seção sobre Telltale recomendou para quem desenvolve.

### 5. Teste

```cpp
// Source/Vigilia/Tests/VGNarrativeStateTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Narrative/VGFactRuleSet.h"
#include "Narrative/VGNarrativeTypes.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGNarrativeStateTest, "Vigilia.Narrative.State.FactsGroupsRules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGNarrativeStateTest::RunTest(const FString& Parameters)
{
    FVGNarrativeState State;

    // Fatos monotônicos: o segundo AddFact não muda nada.
    TestTrue(TEXT("Fato novo"), State.AddFact(TAG_World_Sector_Powered));
    TestFalse(TEXT("Fato repetido"), State.AddFact(TAG_World_Sector_Powered));

    // Grupo exclusivo, com tags nativas hierárquicas: Status.Movement.{Sprinting,Crouched}.
    State.SetExclusive(TAG_Status_Movement_Sprinting.GetTag().RequestDirectParent(), TAG_Status_Movement_Sprinting);
    const FGameplayTagContainer Removed =
        State.SetExclusive(TAG_Status_Movement_Crouched.GetTag().RequestDirectParent(), TAG_Status_Movement_Crouched);
    TestTrue(TEXT("Irmã removida"), Removed.HasTagExact(TAG_Status_Movement_Sprinting));
    TestTrue(TEXT("Só o valor novo"), State.Facts.HasTagExact(TAG_Status_Movement_Crouched)
                                      && !State.Facts.HasTagExact(TAG_Status_Movement_Sprinting));

    // Contador e regra de limiar.
    TestEqual(TEXT("Contador"), State.AddToCounter(TAG_Faction_Target, 2), 2);

    FVGFactRule Rule;
    Rule.EventChannel = TAG_Event_Item_Collected;
    FVGGameplayEvent Collected;
    Collected.Channel = TAG_Event_Item_Collected;
    FVGGameplayEvent Other;
    Other.Channel = TAG_Event_Door_Opened;
    TestTrue(TEXT("Regra casa o canal"), VGNarrativeRules::Matches(Rule, Collected));
    TestFalse(TEXT("Regra ignora outro canal"), VGNarrativeRules::Matches(Rule, Other));

    // Registro de quest substitui, não duplica.
    FVGQuestRecord Record;
    Record.QuestTag = TAG_Faction_Target;
    Record.StageId = TEXT("A");
    State.RecordQuest(Record);
    Record.StageId = TEXT("B");
    State.RecordQuest(Record);
    TestEqual(TEXT("Um registro"), State.Quests.Num(), 1);
    TestEqual(TEXT("Etapa atualizada"), State.Quests[0].StageId, FName(TEXT("B")));
    return true;
}

#endif
```

O teste usa tags nativas existentes como substitutas: as regras não ligam para o nome da tag. Em particular, `Status.Movement.{Sprinting,Crouched}` serve de grupo exclusivo de exemplo porque são irmãs sob o mesmo pai.

---

## Projeto 6 — o estado narrativo do setor 1

🔁 A terceira etapa da refatoração do *Turno da Noite*.

### O catálogo de fatos

O documento `docs/design/fatos.md` passa a ser **contrato**: cada fato tem um nome, quem o concede e quem o lê.

| Fato / contador | Concedido por | Lido por |
|---|---|---|
| `Narrative.Fact.Document.Logbook.Read` | Regra: `Event.Item.Collected` + `Item.Document.Logbook` | Conversa `PortaSemEnergia` (variante), setor 2 |
| `Narrative.Fact.Document.Memo.Read` | Regra: `Event.Item.Collected` + `Item.Document.Memo` (o Cap. 48 troca por "lido de fato") | Conversas `Disjuntores` e `Final` |
| `Narrative.Fact.S1.BreakersRestored` | Regra: `Event.Sector.Powered` + `Sector.S1.ControlRoom` | Etapa `Disjuntores` ("concluída se"), gatilho do susto |
| `Narrative.Fact.S1.ScareDone` | Gatilho do susto (`FactOnTrigger`) | Gatilho do susto, setor 2 |
| `Narrative.Fact.Helena.AdmittedTurbine3` / `Helena.Doubted` | Escolha de diálogo (Cap. 44) | Conversa `Final`, Cap. 47 |
| `Narrative.Counter.S1.Badges` → `Narrative.Fact.S1.AllBadgesFound` (em 6) | Regra com contador: `Event.Item.Collected` + `Item.Badge` | Desafio do Cap. 45, fala final |
| `Narrative.Fact.S1.Completed` | Regra: `Event.Quest.Completed` + `Quest.S1.NightShift` | Pátio (o portão do setor 2), setor 2 |

### O que sai do conteúdo

- **A ação "Conceder fato" no objetivo do livro**, porque a regra cobre.
- **A concessão de `S1.BreakersRestored` no puzzle**: o puzzle só energiza o setor. O Level Blueprint do puzzle fica uma linha menor e, mais importante, deixa de conhecer a história.
- **O fato `S1.Completed` no `OnCompleted` da quest**, porque a regra cobre o evento de conclusão. O sinal `S1.ChapterEnd` continua no `OnCompleted`: ele é uma reação do nível, não um fato.

### O teste de troca de nível

A prova de que o estado mora no lugar certo:

1. Jogue o setor 1 até a etapa `Disjuntores` sem ler o memorando.
2. Volte ao Pátio pela porta da Casa de Força e entre de novo.
3. A quest retoma na etapa `Disjuntores`, a conversa `Chegada` **não** toca de novo e o livro continua "lido".
4. Ao religar os disjuntores, Sônia faz a pergunta da variante sem memorando.

Com `vg.Debug.Narrative` ligado, os fatos atravessam a troca de nível na tela.

### O inventário de dores, atualizado

| # | Dor | Situação depois do Cap. 46 |
|---|---|---|
| 1 | Estado narrativo espalhado e invisível | ✅ Resolvida: um dono, um catálogo, um painel de depuração |
| 2 | Impossível salvar | 🟡 Preparada: a *snapshot* existe; o save em disco é o Cap. 56 |
| 9 | Nada é testável | 🟡 Mais perto: `VGNewGame`, `VGAddFact`, `VGRemoveFact`, `VGQuestJump` e o painel montam e inspecionam qualquer estado |
| 8 | Nada é reutilizável | 🟡 As regras de fatos servem a todos os setores |

---

## Decisões arquiteturais

1. **Estado narrativo = fatos monotônicos + contadores + grupos exclusivos + registros de quest**, num único `USTRUCT` versionado, que é ao mesmo tempo o estado em runtime e a snapshot.
2. **Dono único no `UGameInstance`** (`UVGNarrativeSubsystem`); diálogo, quests, regras e gatilhos são leitores que se reconstroem a partir dele.
3. **Fatos de mundo vêm de regras de dados** (`UVGFactRuleSet`, apontado em *Project Settings*); fatos de momento narrativo são concedidos no próprio dado (escolhas, gatilhos).
4. **Contadores geram fatos de limiar**; condições de conteúdo nunca carregam números.
5. **Anúncio discreto por fato, com profundidade limitada**; restauração tem anúncio próprio (`OnRestored`).
6. **`OnEnter` de etapas só com ações idempotentes**, porque a retomada as executa de novo.
7. **Nomes de fatos são contrato**: catálogo em `docs/design/fatos.md`; renomear = redirecionar.

---

## Armadilhas

- **Esquecer o `ResetForNewGame`.** O `UGameInstance` sobrevive ao "novo jogo", e o estado também, se ninguém o zerar.
- **Usar fato para o que é estado.** Uma *flag* "Sônia está brava" que alguém precisa lembrar de desligar volta como bug. Estados variáveis vão para grupos exclusivos, e a regra que os muda fica num lugar.
- **Números mágicos no conteúdo.** "Se o contador ≥ 6" espalhado por falas e quests. Use fatos de limiar.
- **Renomear uma tag de fato** com saves publicados, ou com conteúdo que a referencia por nome. Redirecione.
- **Ouvintes que mutam o estado dentro do anúncio** sem limite. A cascata vira recursão profunda; enfileire, como o subsistema de quests.
- **Ações não idempotentes no `OnEnter`.** A retomada de etapa as repete.
- **Ponteiros para assets na snapshot.** O save precisa de caminhos (`TSoftObjectPtr`), não de endereços.
- **Guardar estado de simulação como narrativo** (onde a Presença está, a vida da jogadora). Isso infla o estado e confunde quem lê o catálogo. Cada estado tem o seu dono (Caps. 56–57).

---

## Exercício

**Parte 1 — o dono (1,5 h).** Implemente `FVGNarrativeState`, `UVGNarrativeSubsystem` e o teste. Acrescente `DescribeForDebug` e `vg.Debug.Narrative`, com os fatos agrupados pelo segundo nível da tag (`Document`, `S1`, `Helena`…).

**Parte 2 — regras (1 h).** Implemente `UVGFactRuleSet`, `UVGNarrativeSettings` e `UVGFactRulesSubsystem`. Crie o `DA_FatosDoJogo` com as regras do catálogo e aponte-o em *Project Settings*. Remova do conteúdo as concessões manuais listadas no Projeto 6 e jogue o setor 1: os mesmos fatos devem aparecer no painel.

**Parte 3 — migração (2 h).** Migre o diálogo, as quests (registros, retomada, reação a fatos), o gatilho e os cheats. Faça o teste de troca de nível do Projeto 6. Em seguida, faça a jogadora resolver o puzzle **antes** da etapa `Disjuntores` e confirme que, ao chegar lá, a etapa conclui sozinha.

**Parte 4 — idempotência (30 min).** Revise o `OnEnter` de todas as etapas da quest do setor 1. Mova para `OnComplete` qualquer ação que não seja idempotente, e registre a regra no `docs/design/quests.md`.

---

## Desafio — a snapshot como JSON

Antes do save "de verdade" (Capítulo 56), construa uma ferramenta de desenvolvimento:

1. Dois cheats, `VGNarrativeExport <arquivo>` e `VGNarrativeImport <arquivo>`, que gravam e leem a *snapshot* como JSON em `Saved/Narrative/`, usando `FJsonObjectConverter::UStructToJsonObjectString` e `JsonObjectStringToUStruct` (módulo `JsonUtilities`) e `FFileHelper`.
2. Monte uma pasta de **estados de teste**: `s1_antes_do_puzzle_sem_memo.json`, `s1_final_admitiu.json`. Cada um reproduz um caminho da história em segundos.
3. Responda no `DEVLOG.md`:
   - O que acontece ao importar um JSON com uma tag de fato que não existe mais?
   - E com uma quest cujo asset foi apagado?
   - O que isso ensina sobre o Capítulo 56?

---

## Uso de IA

1. **Para auditar o catálogo de fatos:**
   > "Aqui está o catálogo de fatos narrativos de um jogo (nome, quem concede, quem lê) e uma lista de condições usadas em falas e quests. Encontre: fatos concedidos que ninguém lê, fatos lidos que ninguém concede, fatos que deveriam ser um grupo exclusivo (estados que mudam), condições com números mágicos, e nomes inconsistentes com a convenção. [catálogo + condições]"

2. **Para revisar o dono do estado:**
   > "Revise este subsistema de estado narrativo da Unreal Engine 5 (UGameInstanceSubsystem com um USTRUCT de estado, anúncio de mudanças e snapshot). Procure: anúncio antes de o estado mudar, recursão sem limite em ouvintes, estado que sobrevive a 'novo jogo', referências que não serializam, e operações de grupo exclusivo que expõem estados intermediários. [código]"

3. **Para desenhar a idempotência:**
   > "Tenho quests com ações 'ao entrar na etapa' (conceder fato, pedir conversa, publicar sinal para o nível, iniciar outra quest). Ao carregar um save, as etapas ativas são reexecutadas. Classifique cada tipo de ação como idempotente ou não, e proponha a regra mais simples que torne a retomada segura."

**Cuidado específico:** pedir à IA "modele o estado narrativo do meu jogo" tende a produzir esquemas grandes, com entidades, relacionamentos e enums para tudo, no estilo de um banco de dados de aplicação. O estado narrativo de um jogo pequeno é um conjunto de nomes bem escolhidos. Use a IA para criticar o catálogo, não para inflá-lo.

---

## Checklist

- [ ] Sei separar estado narrativo de estado de gameplay, de mundo e de simulação.
- [ ] Sei a diferença entre fato (monotônico) e estado (variável), e por que prefiro fatos.
- [ ] Sei escolher entre *flag*, contador, grupo exclusivo e registro de quest.
- [ ] Implementei um dono único no `UGameInstance`, com anúncio de mudanças e reset para novo jogo.
- [ ] Derivo fatos de eventos por regras de dados, e sei quando conceder o fato no próprio dado.
- [ ] Tenho uma *snapshot* versionada, com referências *soft*.
- [ ] Migrei diálogo, quests e gatilhos; as quests retomam entre níveis e reagem a fatos.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Programming Subsystems** (Game Instance Subsystems), **Gameplay Tags** (incluindo redirecionamento) e **Developer Settings**.
- **Emily Short** (emshort.blog): textos sobre *storylets* e *quality-based narrative*, um vocabulário útil para pensar em conteúdo condicionado por estado.
- **GDC Vault** (gdcvault.com): palestras da trilha de narrativa sobre estado e consequências em jogos de escolhas (procure por desenvolvedores da Telltale e da Failbetter; confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 47 — Branching](cap-47-branching.md)

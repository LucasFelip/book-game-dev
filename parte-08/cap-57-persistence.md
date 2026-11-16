# Capítulo 57 — Persistence

## Objetivo

Ao final deste capítulo você deve conseguir:

- descrever o estado do mundo como **conteúdo mais diferença**, e classificar cada mudança: alterado, destruído, movido, criado ou derivado;
- dar a atores colocados no nível uma **identidade estável** (`FGuid`) que sobreviva a duplicações no editor, a patches e a trocas de nível, e saber por que atores *spawnados* são outro problema;
- serializar só as propriedades marcadas com `SaveGame`, com `FObjectAndNameAsStringProxyArchive`, `ArIsSaveGame` e `ArNoDelta`, e explicar o bug que o último evita;
- **restaurar sem reencenar**: devolver uma porta aberta sem som, sem ruído para a IA e sem anunciar eventos;
- escolher o **momento** de restaurar cada tipo de ator, sabendo que a ordem de `BeginPlay` entre atores não é garantida;
- manter o estado de atores que saem da memória por *streaming* (subníveis e *World Partition*);
- terminar a dor 2 do Interlúdio I: a Casa de Força lembra o que a jogadora fez.

---

## Contexto

O Capítulo 56 terminou com um teste que falha de propósito. Depois de carregar um checkpoint, a narrativa e a jogadora voltam certas, mas a porta do vestiário está fechada, a bateria do depósito voltou para a prateleira e o alarme que já tocou toca de novo. Morrer virou uma fábrica de baterias.

O motivo é a decisão central do capítulo anterior: **carregar é reabrir o nível**. Reabrir o nível recria o mundo a partir do conteúdo, e o conteúdo diz que a porta começa fechada e a bateria começa na prateleira. Falta aplicar a **diferença do mundo**.

Várias promessas chegam aqui:

- **Capítulo 8:** níveis de *streaming* "carregados e descarregados dinamicamente (Capítulo 57)".
- **Capítulo 15:** o gatilho que precisa "poder ser rearmado ao recarregar um checkpoint".
- **Capítulo 46:** "se uma porta está aberta ou se uma caixa foi empurrada: estado de mundo, assunto da persistência (Capítulo 57)".
- **Capítulo 48:** o `AVGReadable` esconde o documento levado em vez de destruí-lo, com o comentário "o Cap. 57 decide se ele volta".
- **Capítulo 76:** o Salão das Turbinas é candidato a *World Partition* ou a níveis em *streaming*, e a troca entre níveis vem "com carga e persistência (Caps. 56–57)".

---

## 57.1 O mundo é conteúdo mais diferença

O nível que você editou é a **verdade inicial**. Tudo o que a jogadora faz é uma diferença sobre ela. A persistência guarda só a diferença, e cada tipo de diferença pede uma estratégia:

| Tipo de mudança | Exemplo na Vigília | O que guardar | Como volta |
|---|---|---|---|
| **Alterado** | Porta aberta; disjuntor ligado; gatilho disparado | As propriedades que mudaram | Sobrescritas sobre o estado inicial |
| **Destruído** | Bateria pega no depósito | "Este ator não existe mais" | Removido ao carregar |
| **Movido** | Caixa empurrada, cadeira derrubada | O *transform* | Teleportado ao carregar |
| **Criado** | Algo que nasceu durante o jogo | Classe, *transform*, propriedades | Recriado (a Vigília não faz; veja 57.2) |
| **Derivado** | Luzes e zonas seguras do setor; documento levado e lido | **Nada** | Recalculado a partir de outra fonte |

A última linha é a mais importante, e é a mesma regra do Capítulo 56 aplicada ao mundo: **persista a fonte, derive o resto**.

- **O setor.** O `AVGSector` (Capítulo 24) acende as zonas seguras e os postes quando o disjuntor principal é ligado. Salvar o setor **e** o disjuntor cria duas verdades que podem discordar. Salve o disjuntor; o setor olha para ele ao começar.
- **O documento levado.** O Capítulo 48 esconde o `AVGReadable` quando a jogadora o abre, mesmo antes de a leitura contar. Ele volta ao carregar? A resposta já está no estado narrativo: se o fato de leitura existe, ele foi levado **e lido**, e fica fora do mundo; se não existe, ele volta para a mesa. Nenhum registro novo: o documento é **derivado dos fatos**.
- **Os vigias do setor 2.** Salvar cada corpo (posição, *ragdoll*, vida zero) é caro e frágil. A fonte certa é o **resultado do encontro**: uma regra de fatos do Capítulo 46 com contador (`Event.Actor.Died` com contexto `Faction.Guard` → contador `S2.GuardsDown`; em 4 → fato `S2.GuardsCleared`), e o spawner do encontro não cria ninguém se o fato existe. Encontro pela metade recomeça, o que é o comportamento esperado num jogo de checkpoints, com o checkpoint antes do encontro.

Derivar tem um custo: a regra de derivação precisa existir e estar certa. Mas cada estado derivado é um estado que **não pode discordar** de outro, e que não precisa de ID, de versão nem de teste de save.

> 🌉 **Ponte:** é o modelo dos sistemas de arquivos em camadas, como os de imagens de contêiner: uma imagem base imutável e uma camada gravável por cima, com marcas de "apagado" (*whiteouts*) para o que foi removido.
>
> 🧱 **Onde a ponte cai:** a imagem base de um contêiner não muda debaixo da camada gravável. A do jogo muda a cada patch: alguém move a porta, apaga a bateria, troca a classe de um gatilho. A camada de diferença precisa sobreviver a uma base diferente da que a gerou, e isso exige identidade estável (57.2) e tolerância a registros órfãos, que apontam para algo que não existe mais e são simplesmente ignorados.

---

## 57.2 Identidade estável

Para aplicar "a porta X está aberta", o jogo precisa encontrar **a porta X** num nível recém-aberto. As opções óbvias falham de maneiras diferentes:

- **Ponteiro.** Não significa nada no próximo processo, nem na próxima abertura do nível.
- **Nome do objeto** (`BP_Porta_C_3`). Para atores colocados no nível, o nome é salvo com o nível e costuma ser estável entre execuções. Mas muda se o ator for apagado e recriado, ou movido para outro subnível, e cópias recebem nomes novos que dependem da ordem em que foram criadas.
- **Rótulo do *Outliner*** ("Porta do vestiário"). Só existe no editor.
- **Caminho completo** (nível + nome). Igual ao nome, e ainda quebra quando o ator muda de subnível.

A solução robusta é um **identificador explícito**: um `FGuid` gravado no próprio ator, gerado **uma vez**, no editor, quando o ator é colocado no nível. O GUID viaja com o ator para qualquer subnível, sobrevive a renomeações e não depende de ordem. O preço é cuidar do ciclo de vida dele:

```text
  colocar no nível (editor)   → gera GUID novo                  ✓
  salvar o nível              → GUID vai para o disco            ✓
  abrir o nível (jogo/PIE)    → GUID lido do disco, igual        ✓
  duplicar no editor (Ctrl+D, Alt+arrastar, copiar/colar)
                              → a cópia herda o GUID ✗ → gerar um novo
  duplicar o mundo para PIE   → a cópia herda o GUID ✓ (é o mesmo ator)
  spawnar em runtime          → não há GUID do conteúdo ✗ → outro problema
```

A linha da duplicação é a armadilha clássica: duas portas com o mesmo GUID compartilham um registro, e abrir uma abre as duas no próximo load. A defesa tem duas camadas: regenerar o GUID nos ganchos de duplicação do editor (`PostEditImport` para copiar e colar, `PostDuplicate` quando não for para PIE; ⚠️ confira qual gancho cada forma de duplicação chama na sua versão) e, como rede de segurança, **detectar duplicatas em runtime** e falhar alto com `ensure`.

A engine tem identificadores próprios. Todo ator tem um `ActorGuid` no editor, usado pelo *World Partition* e pelo *One File Per Actor*, e versões recentes expõem um GUID de instância em runtime. ⚠️ Confira na sua versão o que está disponível fora do editor antes de depender deles. A Vigília usa um GUID próprio porque ele é **explícito**: está num campo que você vê, pertence a um componente que você controla e não muda de semântica entre versões da engine.

### Atores spawnados

Atores criados durante o jogo (um projétil, um efeito, um inimigo de onda) não têm GUID no conteúdo. Há duas estratégias:

1. **Não persistir; recriar pela lógica que os criou.** O spawner de vigias lê o fato do encontro (57.1). O pool de projéteis (Capítulo 32) não tem nada a lembrar.
2. **Persistir como registro de criação:** classe, *transform*, propriedades e um GUID gerado no *spawn*. Ao carregar, o sistema recria os registros e só então aplica as propriedades.

A Vigília fica com a primeira. Nada do que ela spawna precisa sobreviver a um load: os sinalizadores são munição (registro da jogadora), a Presença e os vigias são simulação ou derivados de fatos, e os efeitos são efêmeros. O componente de persistência deste capítulo **recusa** atores sem GUID e avisa no log. A segunda estratégia é o desafio do capítulo.

> 🌉 **Ponte:** é a escolha entre chave natural e chave substituta (*surrogate key*) num banco. O GUID é a chave substituta: não carrega significado e não muda quando o significado muda.
>
> 🧱 **Onde a ponte cai:** num banco, a restrição de unicidade é do próprio banco, e uma linha duplicada é recusada na inserção. No editor, as "linhas" são copiadas e coladas livremente por pessoas, e nenhuma restrição impede duas portas com o mesmo GUID. A unicidade é responsabilidade sua: ganchos de duplicação mais uma verificação em runtime.

---

## 57.3 Restaurar não é reencenar

Uma porta aberta pode ser devolvida de dois jeitos:

- **Reencenar:** chamar `Interact`, ou `TransitionTo(Opening)`, e deixar a porta abrir.
- **Restaurar:** pôr a porta no estado `Open`, com a dobradiça a 95 graus, **instantaneamente**.

Reencenar parece reaproveitar código, e é um erro. A transição de uma porta na Vigília faz quatro coisas além de girar: anuncia `OnDoorStateChanged` (áudio, narrativa e IA reagem), reporta ruído para a percepção (Capítulo 36, 0,6 de intensidade a 15 m), atualiza o modificador de navegação (Capítulo 35) e liga o tick. Num load, isso significa um rangido em cada porta aberta do nível no primeiro frame e uma Presença que ouve dez portas ao mesmo tempo e vai investigar. Pior: eventos publicados no barramento chegam às regras de fatos e aos objetivos, que podem concluir de novo algo que já concluíram.

A regra: **restaurar aplica o estado em silêncio**. Sem som, sem ruído, sem eventos, sem animação. Cada ator persistente tem um caminho de "encaixar no estado" (`SnapToState`), separado do caminho de transição. A atualização do modificador de navegação entra nos dois, porque não é um efeito: é parte do estado.

### O momento de restaurar

O Capítulo 56 restaurou a narrativa em `InitGame` e a jogadora no `BeginPlay` dela. Para os atores do mundo, o momento importa mais, porque eles **leem uns aos outros**:

- a porta, no `BeginPlay`, pergunta ao disjuntor se ele está ligado para decidir se começa trancada;
- o setor, no `BeginPlay`, pergunta ao disjuntor principal se deve acender.

A ordem de `BeginPlay` entre atores não é garantida (o guia do livro repete isso desde a Parte II). Se o disjuntor restaurar o próprio estado no `BeginPlay` dele, a porta pode perguntar **antes** e receber o estado do conteúdo. A solução é a mesma que o Capítulo 19 já usou para o estado inicial do disjuntor:

```text
  para cada nível (ou célula) que entra no mundo:
    1. todos os atores: PostInitializeComponents
         estado inicial do conteúdo  →  RestoreOwner() sobrescreve com a diferença
    2. só depois, todos os atores: BeginPlay
         leituras cruzadas (porta → disjuntor, setor → disjuntor) já veem o estado restaurado
```

Na Unreal 5, a inicialização dos atores de um nível acontece em fases, e as fases de inicialização de componentes de **todos** os atores do nível terminam antes de a fase de `BeginPlay` começar (⚠️ veja `ULevel::RouteActorInitialize` na sua versão). Restaurar no fim do `PostInitializeComponents` garante que nenhum `BeginPlay` lê um vizinho meio restaurado.

| Quem | Restaura em | Por quê |
|---|---|---|
| Narrativa | `AVGGameMode::InitGame` (Cap. 56) | Atores nascem lendo fatos |
| Atores do mundo | Fim do `PostInitializeComponents` | Antes de qualquer `BeginPlay` do mesmo nível |
| Estado derivado (setor, documento) | `BeginPlay` | A fonte já foi restaurada |
| Jogadora | `BeginPlay` dela, depois de `Super` (Cap. 56) | Os componentes dela iniciam no `BeginPlay` |

> 🌉 **Ponte:** reconstruir uma projeção a partir de um log de eventos sem reenviar os efeitos colaterais: *handlers* que mandariam e-mail ou cobrariam um cartão precisam saber que estão em *replay*.
>
> 🧱 **Onde a ponte cai:** lá, o problema é **duplicar** efeitos externos, e a defesa é idempotência ou deduplicação. Aqui, os "efeitos" são percepção (um rangido, um ruído que a IA ouve, uma luz que pisca), e eles não podem acontecer **nem uma vez**. Não há deduplicação para um som que a jogadora já ouviu. Por isso a restauração é um caminho de código separado, e não um *replay* com uma *flag*.

---

## 57.4 Streaming e estado

Até aqui, o mundo era um nível inteiro, carregado de uma vez. Em níveis maiores, a Unreal carrega e descarrega pedaços conforme a jogadora anda:

- **Level Streaming:** subníveis carregados e descarregados por volumes, por Blueprint ou por código.
- ***World Partition*:** o nível é dividido numa grade de células, carregadas conforme a distância de fontes de *streaming* (por padrão, a jogadora). Com ele vem o *One File Per Actor* (Capítulo 7), em que cada ator é um arquivo.

Nos dois, um ator que sai da memória é **destruído** (`EndPlay` com o motivo `RemovedFromWorld`), e quando a jogadora volta, nasce um ator **novo**, lido do conteúdo. Tudo o que ele lembrava se perdeu, a não ser que alguém tenha guardado. É a mesma situação do load de checkpoint, em escala menor e muito mais frequente: um corredor pode entrar e sair da memória várias vezes numa sessão.

O desenho deste capítulo já trata disso, porque os dois momentos são simétricos:

```text
  ator sai da memória    → EndPlay(RemovedFromWorld)  → captura → guarda o registro no subsistema
  ator volta à memória   → PostInitializeComponents   → RestoreOwner → aplica o registro
  troca de nível         → EndPlay(LevelTransition)   → idem: voltar ao Pátio o encontra como ficou
  destruído em jogo      → EndPlay(Destroyed)         → registro "não existe mais"
  fim do PIE / sair      → EndPlay(EndPlayInEditor/Quit) → nada a guardar
```

Os registros moram no `UVGSaveSubsystem`, que vive no `UGameInstance` e portanto sobrevive ao descarregamento de células e à troca de níveis. O checkpoint grava a soma dos registros guardados com os capturados dos atores vivos.

Três cuidados específicos de *streaming*:

1. **Referências entre áreas.** A porta do Capítulo 19 tem uma referência direta ao disjuntor (`PowerSource`). Se os dois estiverem em células diferentes, a porta pode carregar sem o disjuntor. O *World Partition* tem regras próprias para referências entre atores (⚠️ consulte a documentação de *actor references* na sua versão). A defesa de desenho é a de sempre: prefira **fatos e eventos** a referências diretas entre atores de áreas diferentes, e garanta que cada ator persistente carregue o **próprio** estado. A porta salva o próprio `State`, e não depende do disjuntor estar carregado para saber se está destrancada.
2. **Custo.** Capturar e restaurar acontecem no game thread, durante o *streaming*, que já é um momento caro (Capítulo 60). Com dezenas de atores persistentes por área, o custo é desprezível; com milhares, não é, e vale medir (Capítulo 59).
3. **Mudanças grandes de estado.** "Antes e depois da energia" pode trocar dezenas de luzes, materiais e objetos. Em vez de persistir cada um, mudanças assim podem ser camadas de conteúdo ligadas por um estado só: *Data Layers* no *World Partition* (⚠️ confira os estados de *runtime* na sua versão) ou o `UVGFactGateComponent` do Capítulo 47, que já liga e desliga atores por fatos. De novo, persista a fonte.

A Vigília, por ora, troca de nível inteiro (`L_Patio`, `L_CasaDeForca`, `L_Subestacao`, `L_Turbinas`, `L_Final`). O Salão das Turbinas pode virar *World Partition* ou *streaming* no Capítulo 77, decidido por profiling. O componente deste capítulo funciona igual nos dois casos, e o exercício simula um subnível para provar isso.

---

## Estudos de caso

### GTA: o que o mundo esquece, e a garagem

**[FATO PÚBLICO — observável jogando]** Nos GTA de mundo aberto, um carro deixado na rua costuma desaparecer quando a jogadora se afasta e o perde de vista. Carros guardados na garagem de uma casa da personagem continuam lá.

**[INFERÊNCIA]** O mundo aberto não pode lembrar de tudo; a população de veículos é simulação (Interlúdio II), recriada perto da jogadora e descartada longe dela. A garagem é um **contêiner explícito de persistência**: um lugar onde o jogo promete lembrar, e a jogadora aprende onde está a promessa. O jogo não persiste "o carro"; persiste "o carro **que você guardou**".

**Lição para a Vigília:** persistência é uma **promessa de design**, e cada promessa tem custo. A Vigília promete pouco e cumpre sempre: portas, disjuntores, gatilhos e itens pegos lembram; corpos, sinalizadores no chão e a Presença não.

O Interlúdio II, logo depois desta parte, leva essa ideia à escala de uma cidade, com a distinção entre **identidade** e **agregado**: só tem identidade (e portanto GUID, registro e save) o que a jogadora reconhece e pode verificar, como o carro da garagem; o resto é intercambiável, e o que se lembra dele é um **agregado** (um valor por zona, como o território de uma gangue), do qual os indivíduos são fabricados de novo. O `UVGPopulationSubsystem` que o interlúdio constrói não persiste nada, por desenho, e é o exemplo mais claro do livro de "o que **não** persistir". Os vigias do setor 2 (seção 57.1) já seguem a mesma regra em miniatura: o agregado é o fato `S2.GuardsCleared`, e não os corpos.

### Control: o que fica limpo e o que volta

**[FATO PÚBLICO — observável jogando]** Em *Control* (Remedy, 2019), os pontos de controle purificados pela protagonista continuam purificados e passam a servir de ponto de viagem rápida. Áreas já percorridas, por outro lado, voltam a ter inimigos com o tempo.

**[INFERÊNCIA]** O jogo separa **progresso** (o ponto purificado, que é um estado de mundo persistente e uma recompensa) de **simulação** (os inimigos, que são conteúdo recorrente e não precisam de memória individual). O ponto de controle persiste porque é a fonte de outras coisas: a viagem rápida, o mapa, a sensação de território conquistado.

**Lição para a Vigília:** o setor energizado é o ponto de controle da Vigília. O disjuntor persiste; tudo o que o setor energizado acende é derivado dele.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Conteúdo + diferença | Imagem base + camada gravável | A base muda a cada patch; registros órfãos são normais |
| `FGuid` por ator | Chave substituta | A unicidade não é garantida por ninguém além de você |
| Estado derivado | Coluna calculada, *view* | A derivação roda em atores, no `BeginPlay`, a cada load |
| Restaurar sem reencenar | *Replay* sem efeitos colaterais | Os efeitos são percepção e não podem acontecer nem uma vez |
| *Streaming* com registro | Cache com *write-back* na expulsão | A expulsão é decidida pela posição da jogadora e roda no game thread |

---

## Unreal Engine: o que existe e o que não existe

**Existe:**

- **O especificador `SaveGame`** em `UPROPERTY`, que marca a propriedade com `CPF_SaveGame`.
- **`FArchive::ArIsSaveGame`**: com ele ligado, a serialização por reflexão só considera propriedades `SaveGame`, em **todos os níveis** (campos de *structs* aninhados também precisam da marca).
- **`FArchive::ArNoDelta`**: desliga a serialização delta, gravando também os valores iguais ao padrão da classe. A seção de implementação mostra por que ele é obrigatório aqui.
- **`FObjectAndNameAsStringProxyArchive`** (`Serialization/ObjectAndNameAsStringProxyArchive.h`): um arquivo intermediário que grava referências a objetos e `FName`s como **texto**, e portanto funciona em outro processo. É o mesmo tipo que a engine usa por baixo de `SaveGameToSlot`.
- **`FMemoryWriter`/`FMemoryReader`**: arquivos sobre um `TArray<uint8>`.
- **`FGuid::NewGuid()`**, e os ganchos de editor `PostEditImport` e `PostDuplicate`.
- **`EEndPlayReason`**: `Destroyed`, `LevelTransition`, `EndPlayInEditor`, `RemovedFromWorld`, `Quit`.
- ***Level Streaming*, *World Partition*, *One File Per Actor*, *Data Layers*.**

**Não existe:**

- "salvar o estado deste nível": nenhuma função grava as diferenças de um mundo;
- um identificador de ator pensado para save, com unicidade garantida contra duplicação no editor;
- uma separação entre restaurar e reencenar: isso é desenho de cada classe.

---

## Abordagens

| Critério | A. Registro explícito por classe | **B. Componente genérico + propriedades `SaveGame`** | C. Serializar o nível inteiro |
|---|---|---|---|
| **Complexidade** | Um *struct* e duas funções por classe | Um componente e uma marca por propriedade | Baixa no começo; ordem e efeitos colaterais depois |
| **Performance** | Ótima | Boa: só atores com o componente, só propriedades marcadas | Ruim: todo ator, toda propriedade |
| **Extensibilidade** | Cada classe nova pede código | Marque a propriedade e adicione o componente | Automática, inclusive para o que não deveria |
| **Manutenção** | Formato explícito e verboso | O formato é "as propriedades `SaveGame` da classe", com tolerância de nomes | O formato é tudo, e qualquer mudança na classe muda o save |
| **Prototipação** | Lenta | Rápida | Rapidíssima |
| **Adequação à Vigília** | Para casos especiais | **Sim** | Não |

**Decisão: B**, com a regra de **derivar** sempre que houver uma fonte. A é a saída para um ator cujo estado não cabe em propriedades (o desafio).

---

## Implementação

### 1. O registro e a serialização filtrada

```cpp
// Save/VGSaveGame.h (adições)

/** A diferença de UM ator do mundo em relação ao conteúdo. */
USTRUCT()
struct FVGActorRecord
{
    GENERATED_BODY()

    UPROPERTY(SaveGame)
    bool bDestroyed = false;

    UPROPERTY(SaveGame)
    bool bHasTransform = false;

    UPROPERTY(SaveGame)
    FTransform Transform;

    /** As propriedades SaveGame do ator, serializadas com etiquetas (tolerantes a campos novos/removidos). */
    UPROPERTY(SaveGame)
    TArray<uint8> Properties;
};

// UVGSaveGame (adição): o mundo. Sem subir SaveVersion: um arquivo sem o campo
// carrega um mapa vazio, que significa "o mundo como o conteúdo" (o comportamento antigo).
UPROPERTY(SaveGame)
TMap<FGuid, FVGActorRecord> World;
```

O campo novo é um bom exemplo da camada 2 do Capítulo 56: um save de ontem, sem `World`, carrega com o mapa vazio, que é exatamente o que ele significava. Não há migração a escrever.

```cpp
// Source/Vigilia/Save/VGPersistence.h
#pragma once

#include "CoreMinimal.h"

namespace VGPersistence
{
    /** Grava as propriedades UPROPERTY(SaveGame) de Object em Bytes. */
    void WriteSaveGameProperties(UObject& Object, TArray<uint8>& OutBytes);

    /** Sobrescreve as propriedades UPROPERTY(SaveGame) de Object a partir de Bytes. As demais ficam intactas. */
    void ReadSaveGameProperties(UObject& Object, const TArray<uint8>& Bytes);
}
```

```cpp
// Source/Vigilia/Save/VGPersistence.cpp
#include "Save/VGPersistence.h"

#include "Serialization/MemoryReader.h"
#include "Serialization/MemoryWriter.h"
#include "Serialization/ObjectAndNameAsStringProxyArchive.h"

void VGPersistence::WriteSaveGameProperties(UObject& Object, TArray<uint8>& OutBytes)
{
    FMemoryWriter Writer(OutBytes, /*bIsPersistent*/ true);
    FObjectAndNameAsStringProxyArchive Archive(Writer, /*bInLoadIfFindFails*/ false);
    Archive.ArIsSaveGame = true; // só UPROPERTY(SaveGame), em todos os níveis
    Archive.ArNoDelta = true;    // grava também o que é igual ao padrão da classe (ver o teste)
    Object.Serialize(Archive);
}

void VGPersistence::ReadSaveGameProperties(UObject& Object, const TArray<uint8>& Bytes)
{
    FMemoryReader Reader(Bytes, /*bIsPersistent*/ true);
    FObjectAndNameAsStringProxyArchive Archive(Reader, /*bInLoadIfFindFails*/ true);
    Archive.ArIsSaveGame = true;
    Archive.ArNoDelta = true;
    Object.Serialize(Archive);
}
```

⚠️ `ArIsSaveGame` e `ArNoDelta` são campos de `FArchiveState`. Em algumas versões há *setters* equivalentes; confira o `Archive.h` da sua engine.

**Por que `ArNoDelta`.** Sem ele, a serialização grava só o que difere do padrão da **classe**. Considere uma porta colocada com `bStartsLocked = true`. O `PostInitializeComponents` a põe em `Locked`. A jogadora a destranca; agora `State == Closed`, que é o padrão da classe. Sem `ArNoDelta`, `State` não vai para o registro. No load, o `PostInitializeComponents` põe a porta em `Locked` de novo, o registro não diz nada sobre `State`, e **a porta destrancada volta trancada**. O valor certo era igual ao padrão da classe, mas diferente do estado inicial **daquela instância**. O teste do capítulo fixa esse caso.

### 2. O componente de persistência

```cpp
// Source/Vigilia/Save/VGPersistenceComponent.h
#pragma once

#include "Components/ActorComponent.h"
#include "CoreMinimal.h"
#include "Save/VGSaveGame.h"
#include "VGPersistenceComponent.generated.h"

/**
 * Dá ao dono uma identidade estável e persiste as propriedades UPROPERTY(SaveGame) dele.
 * Contrato com o dono: chamar RestoreOwner() no FIM do PostInitializeComponents, depois do estado inicial,
 * e aplicar o estado restaurado em silêncio (sem som, ruído ou eventos).
 * Só atores colocados no nível: spawnados não têm id e são ignorados (seção 57.2).
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGPersistenceComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGPersistenceComponent();

    /** true = havia registro e as propriedades SaveGame do dono foram sobrescritas. */
    bool RestoreOwner();

    FVGActorRecord CaptureOwner() const;

    const FGuid& GetPersistentId() const { return PersistentId; }

protected:
    virtual void OnRegister() override;
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void PostDuplicate(bool bDuplicateForPIE) override;
#if WITH_EDITOR
    virtual void PostEditImport() override;
#endif

    /** Gerado no editor, uma vez. Não edite à mão. */
    UPROPERTY(VisibleAnywhere, Category = "Vigilia|Persistence")
    FGuid PersistentId;

    /** Para objetos que a física ou a jogadora movem (caixas, cadeiras). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Persistence")
    bool bSaveTransform = false;

private:
    bool bDestroyOnBeginPlay = false;
};
```

```cpp
// Source/Vigilia/Save/VGPersistenceComponent.cpp
#include "Save/VGPersistenceComponent.h"

#include "Core/VGLog.h"
#include "Engine/World.h"
#include "GameFramework/Actor.h"
#include "Save/VGPersistence.h"
#include "Save/VGSaveSubsystem.h"

UVGPersistenceComponent::UVGPersistenceComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void UVGPersistenceComponent::OnRegister()
{
    Super::OnRegister();
#if WITH_EDITOR
    // Colocado no nível pela primeira vez (ou nível antigo sem ids): gera o GUID no editor, nunca no jogo.
    const UWorld* World = GetWorld();
    if (!PersistentId.IsValid() && !IsTemplate() && World && !World->IsGameWorld())
    {
        Modify(); // marca o nível como alterado: o GUID vai para o disco quando você salvar
        PersistentId = FGuid::NewGuid();
    }
#endif
}

void UVGPersistenceComponent::PostDuplicate(bool bDuplicateForPIE)
{
    Super::PostDuplicate(bDuplicateForPIE);
    if (!bDuplicateForPIE)
    {
        PersistentId = FGuid::NewGuid(); // Ctrl+D: a cópia é OUTRO ator
    }
}

#if WITH_EDITOR
void UVGPersistenceComponent::PostEditImport()
{
    Super::PostEditImport();
    PersistentId = FGuid::NewGuid(); // copiar e colar
}
#endif

bool UVGPersistenceComponent::RestoreOwner()
{
    const UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this);
    const FVGActorRecord* Record = (Save && PersistentId.IsValid()) ? Save->FindRecord(PersistentId) : nullptr;
    if (!Record)
    {
        return false; // nada mudou desde o conteúdo (ou estamos no editor, sem GameInstance)
    }

    AActor* Owner = GetOwner();
    if (Record->bDestroyed)
    {
        // Destruir no meio da inicialização do nível é arriscado: some já, destrói no BeginPlay.
        Owner->SetActorHiddenInGame(true);
        Owner->SetActorEnableCollision(false);
        bDestroyOnBeginPlay = true;
        return false;
    }
    if (bSaveTransform && Record->bHasTransform)
    {
        Owner->SetActorTransform(Record->Transform, /*bSweep*/ false, nullptr, ETeleportType::TeleportPhysics);
    }
    VGPersistence::ReadSaveGameProperties(*Owner, Record->Properties);
    return true;
}

FVGActorRecord UVGPersistenceComponent::CaptureOwner() const
{
    FVGActorRecord Record;
    AActor* Owner = GetOwner();
    if (bSaveTransform)
    {
        Record.bHasTransform = true;
        Record.Transform = Owner->GetActorTransform();
    }
    VGPersistence::WriteSaveGameProperties(*Owner, Record.Properties);
    return Record;
}

void UVGPersistenceComponent::BeginPlay()
{
    Super::BeginPlay();
    if (bDestroyOnBeginPlay)
    {
        GetOwner()->Destroy();
        return;
    }
    UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this);
    if (!Save)
    {
        return;
    }
    if (!PersistentId.IsValid())
    {
        UE_LOG(LogVigilia, Warning, TEXT("Persistência: %s não tem id (spawnado em runtime?). Ignorado."),
               *GetNameSafe(GetOwner()));
        return;
    }
    Save->RegisterPersistent(this);
}

void UVGPersistenceComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this);
    if (Save && PersistentId.IsValid())
    {
        Save->UnregisterPersistent(this);
        switch (EndPlayReason)
        {
        case EEndPlayReason::Destroyed:
        {
            FVGActorRecord Gone;
            Gone.bDestroyed = true;
            Save->StoreRecord(PersistentId, Gone);
            break;
        }
        case EEndPlayReason::RemovedFromWorld: // streaming: a célula ou o subnível saiu da memória
        case EEndPlayReason::LevelTransition:  // troca de nível: voltar deve encontrá-lo como ficou
            Save->StoreRecord(PersistentId, CaptureOwner());
            break;
        default:                               // fim do PIE, saída do jogo: nada a guardar
            break;
        }
    }
    Super::EndPlay(EndPlayReason);
}
```

### 3. O subsistema guarda o mundo

🔁 `UVGSaveSubsystem` (Capítulo 56) ganha o registro do mundo e a lista de componentes vivos:

```cpp
// UVGSaveSubsystem.h (adições)
public:
    void RegisterPersistent(UVGPersistenceComponent* Component);
    void UnregisterPersistent(UVGPersistenceComponent* Component);
    const FVGActorRecord* FindRecord(const FGuid& Id) const { return WorldRecords.Find(Id); }
    void StoreRecord(const FGuid& Id, const FVGActorRecord& Record) { WorldRecords.Add(Id, Record); }
    FString DescribeWorldForDebug() const;

private:
    void CaptureLiveWorld();

    /** A diferença do mundo, de todos os níveis (GUIDs são únicos no jogo: um mapa só basta). */
    TMap<FGuid, FVGActorRecord> WorldRecords;

    /** Atores persistentes carregados agora. */
    TMap<FGuid, TWeakObjectPtr<UVGPersistenceComponent>> LiveComponents;
```

```cpp
// UVGSaveSubsystem.cpp (adições)
#include "Save/VGPersistenceComponent.h"

void UVGSaveSubsystem::RegisterPersistent(UVGPersistenceComponent* Component)
{
    const FGuid& Id = Component->GetPersistentId();
    if (const TWeakObjectPtr<UVGPersistenceComponent>* Existing = LiveComponents.Find(Id); Existing && Existing->IsValid())
    {
        // Duplicado no editor sem GUID novo: dois atores, um registro. Falha alto (seção 57.2).
        ensureMsgf(false, TEXT("Persistência: id %s duplicado em %s e %s."), *Id.ToString(),
                   *GetNameSafe((*Existing)->GetOwner()), *GetNameSafe(Component->GetOwner()));
        return;
    }
    LiveComponents.Add(Id, Component);
}

void UVGSaveSubsystem::UnregisterPersistent(UVGPersistenceComponent* Component)
{
    const FGuid& Id = Component->GetPersistentId();
    if (const TWeakObjectPtr<UVGPersistenceComponent>* Existing = LiveComponents.Find(Id); Existing && Existing->Get() == Component)
    {
        LiveComponents.Remove(Id); // só se for ele mesmo (o duplicado nunca entrou)
    }
}

void UVGSaveSubsystem::CaptureLiveWorld()
{
    for (const TPair<FGuid, TWeakObjectPtr<UVGPersistenceComponent>>& Pair : LiveComponents)
    {
        if (const UVGPersistenceComponent* Component = Pair.Value.Get())
        {
            WorldRecords.Add(Pair.Key, Component->CaptureOwner());
        }
    }
}

FString UVGSaveSubsystem::DescribeWorldForDebug() const
{
    int32 Destroyed = 0;
    for (const TPair<FGuid, FVGActorRecord>& Pair : WorldRecords)
    {
        Destroyed += Pair.Value.bDestroyed ? 1 : 0;
    }
    return FString::Printf(TEXT("Mundo: %d registros (%d destruídos), %d atores persistentes vivos."),
                           WorldRecords.Num(), Destroyed, LiveComponents.Num());
}
```

E três linhas mudam no que o Capítulo 56 escreveu:

```cpp
// WriteCheckpoint: antes de AsyncSaveGameToSlot
CaptureLiveWorld();
Save->World = WorldRecords;

// ApplyPendingLoad: antes da narrativa (o mundo velho já foi desmontado e já guardou o que tinha)
WorldRecords = Save->World;
LiveComponents.Reset();

// StartNewGame
WorldRecords.Reset();
```

A ordem de `ApplyPendingLoad` resolve uma corrida sutil. Quando o checkpoint é recarregado, o nível velho é desmontado, e cada ator persistente guarda o próprio estado (`EndPlay(LevelTransition)`) no `WorldRecords`: o estado **pós-checkpoint**, que precisa ser descartado. Como `InitGame` do nível novo roda **depois** da desmontagem, a substituição inteira do mapa descarta essas gravações. Se a substituição acontecesse antes do `OpenLevel`, a desmontagem a sobrescreveria com o estado errado.

### 4. Os atores aprendem a persistir

🔁 **`AVGDoor`** (Capítulos 19 e 35). O estado inicial sai do `BeginPlay` e vai para o `PostInitializeComponents`, seguido da restauração, e a porta ganha um caminho silencioso:

```cpp
// AVGDoor.h (mudanças)
protected:
    virtual void PostInitializeComponents() override;

    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UVGPersistenceComponent> Persistence;

private:
    /** Aplica o estado sem transição: sem som, sem ruído para a IA, sem OnDoorStateChanged. */
    void SnapToState();

    UPROPERTY(SaveGame)
    EVGDoorState State = EVGDoorState::Closed;

    UPROPERTY(SaveGame)
    float OpenAlpha = 0.0f;
```

```cpp
// AVGDoor.cpp (mudanças)
AVGDoor::AVGDoor()
{
    // ... como antes ...
    Persistence = CreateDefaultSubobject<UVGPersistenceComponent>(TEXT("Persistence"));
}

void AVGDoor::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    // 1. Estado inicial do CONTEÚDO, por atribuição direta (sem anúncio, Cap. 13).
    State = bStartsLocked ? EVGDoorState::Locked : EVGDoorState::Closed;
    OpenAlpha = 0.0f;
    // 2. A diferença salva por cima.
    if (Persistence->RestoreOwner())
    {
        SnapToState();
    }
}

void AVGDoor::BeginPlay()
{
    Super::BeginPlay();
    if (PowerSource)
    {
        PowerSource->OnToggled.AddDynamic(this, &AVGDoor::HandlePowerToggled);
        // O disjuntor restaurou o próprio estado no PostInitializeComponents dele: a leitura é segura.
        if (!PowerSource->IsOn() && State == EVGDoorState::Closed)
        {
            TransitionTo(EVGDoorState::Locked);
        }
    }
}

void AVGDoor::SnapToState()
{
    // O save não tem "meio do movimento": quem estava abrindo, abriu.
    if (State == EVGDoorState::Opening) { State = EVGDoorState::Open; }
    if (State == EVGDoorState::Closing) { State = EVGDoorState::Closed; }
    OpenAlpha = (State == EVGDoorState::Open) ? 1.0f : 0.0f;
    ApplyAlpha();
    ApplyNavArea();            // extraído do TransitionTo (Cap. 35): navegação é estado, não efeito
    SetActorTickEnabled(false);
}
```

`ApplyNavArea` é a atualização do modificador de navegação que o Capítulo 35 pôs dentro de `TransitionTo`. Extraia-a para um método e chame-a dos dois lugares: a transição continua fazendo tudo (anúncio, ruído, navegação, tick), e o encaixe faz só o que é estado.

🔁 **`AVGBreakerSwitch`** (Capítulo 19). O estado inicial já estava no lugar certo:

```cpp
// AVGBreakerSwitch: bIsOn ganha SaveGame; o componente entra no construtor
UPROPERTY(SaveGame)
bool bIsOn = false;

void AVGBreakerSwitch::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    bIsOn = bStartsOn;           // conteúdo, sem broadcast (como antes)
    Persistence->RestoreOwner(); // diferença; o visual continua sendo aplicado no BeginPlay
}
```

🔁 **`AVGEventTrigger`** (Capítulos 15, 31 e 45). `bHasTriggered` vira `UPROPERTY(SaveGame)`, o componente entra no construtor e o `PostInitializeComponents` termina com `Persistence->RestoreOwner()`. Agora a promessa do Capítulo 15 se cumpre por inteiro: gatilhos disparados **antes** do checkpoint continuam disparados, e os disparados **depois** voltam armados, porque o registro gravado no checkpoint não os conhece e o ator novo nasce com o padrão. Ninguém chama `ResetTrigger` no load. Ele continua útil para rearmar um gatilho **sem** recarregar o nível, e é por isso que continua existindo. O gatilho do susto, condicionado a fatos (Capítulo 45), nem precisaria do componente: a memória dele é o fato `S1.ScareDone`.

🔁 **`AVGPickup`** (Capítulo 19). Só o componente no construtor. O `Destroy()` que já existia gera `EndPlay(Destroyed)`, e o componente grava "não existe mais".

🔁 **`AVGSector`** (Capítulos 23–24). Estado **derivado**, sem componente:

```cpp
void AVGSector::BeginPlay()
{
    Super::BeginPlay();
    // ... inscrição em OnToggled do disjuntor principal, como antes ...
    if (MainBreaker && MainBreaker->IsOn())
    {
        // O disjuntor já foi restaurado: acende zonas seguras e postes SEM publicar Event.Sector.Powered.
        SetPowered(/*bAnnounce*/ false);
    }
}
```

`SetPowered(bool bAnnounce)` é o método que o handler de `OnToggled` já chamava, agora com um parâmetro: com `true` (a jogadora ligou o disjuntor), publica `Event.Sector.Powered` e anuncia `OnSectorPowered`; com `false` (restauração), só aplica o estado. Use o nome que o seu `AVGSector` já tiver para esse método.

🔁 **`AVGReadable`** (Capítulo 48). Também derivado:

```cpp
void AVGReadable::BeginPlay()
{
    Super::BeginPlay();
    // Levado E lido: fica fora do mundo. Levado e NÃO lido: volta para onde estava (Cap. 48, 57.1).
    const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);
    if (bTakeOnRead && Document && Narrative && Narrative->HasFact(Document->ReadFact))
    {
        SetActorHiddenInGame(true);
        SetActorEnableCollision(false);
    }
}
```

A "simplificação" do Capítulo 48 (o documento levado e não lido sai do mundo) continua valendo **durante** a sessão, e se desfaz no próximo load ou na próxima vez que o nível abrir. É a resposta da pergunta que o Capítulo 48 deixou: ele volta se não foi lido.

**Cheat:** `VGDumpPersistence` escreve `DescribeWorldForDebug` no log.

### Explicação das decisões

- **Um componente, não uma interface.** A identidade (o GUID), o ciclo (registrar, guardar ao sair, destruir ao carregar) e a serialização são iguais para todos. O que muda por classe é **quais propriedades** e **como encaixar no estado**, e isso fica no ator: marcas `SaveGame` e um `SnapToState`.
- **O ator chama `RestoreOwner`, o componente não se restaura sozinho.** O momento certo é o **fim** do `PostInitializeComponents` do dono, depois do estado inicial. Um componente não tem como se inserir nesse ponto do dono, e um contrato explícito de uma linha é mais claro que um gancho esperto.
- **Um mapa só para o mundo inteiro.** GUIDs são únicos no jogo; separar registros por nível seria uma estrutura a mais sem nenhuma consulta que precise dela.
- **Registros órfãos são ignorados.** Um GUID cujo ator foi apagado num patch nunca é consultado. Ele custa alguns bytes, e limpá-lo exigiria saber quais atores existem em níveis não carregados.
- **Atores spawnados são recusados com aviso**, e não suportados pela metade.
- **Derivar antes de persistir.** O setor e o documento não têm componente; o setor olha para o disjuntor, o documento olha para os fatos. Nenhum dos dois pode discordar da fonte.

### 5. Teste

O teste precisa de uma classe com propriedades marcadas e não marcadas. Ela vive em `Tests/`, é minúscula e não tem `VIGILIA_API` (não sai do módulo):

```cpp
// Source/Vigilia/Tests/VGPersistenceTestTypes.h
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "VGPersistenceTestTypes.generated.h"

/** Só para o teste de persistência. */
UCLASS()
class UVGPersistenceTestObject : public UObject
{
    GENERATED_BODY()

public:
    UPROPERTY(SaveGame)
    int32 Saved = 0;

    UPROPERTY()
    int32 NotSaved = 0;

    UPROPERTY(SaveGame)
    FName Label;
};
```

```cpp
// Source/Vigilia/Tests/VGPersistenceTest.cpp
#include "Misc/AutomationTest.h"
#include "Kismet/GameplayStatics.h"
#include "Save/VGPersistence.h"
#include "Save/VGSaveGame.h"
#include "Tests/VGPersistenceTestTypes.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGPersistenceTest, "Vigilia.Save.Persistence.SaveGameFilterNoDelta",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGPersistenceTest::RunTest(const FString& Parameters)
{
    // O estado capturado: Saved é IGUAL ao padrão da classe (como a porta destrancada em Closed).
    UVGPersistenceTestObject* Source = NewObject<UVGPersistenceTestObject>();
    Source->Saved = 0;
    Source->NotSaved = 9;
    Source->Label = TEXT("Porta");
    TArray<uint8> Bytes;
    VGPersistence::WriteSaveGameProperties(*Source, Bytes);

    // O ator recém-aberto: estado inicial da INSTÂNCIA diferente do padrão (como bStartsLocked).
    UVGPersistenceTestObject* Target = NewObject<UVGPersistenceTestObject>();
    Target->Saved = 5;
    Target->NotSaved = 1;
    VGPersistence::ReadSaveGameProperties(*Target, Bytes);

    TestEqual(TEXT("Igual ao padrão também é restaurado (ArNoDelta)"), Target->Saved, 0);
    TestEqual(TEXT("Sem SaveGame não é tocado (ArIsSaveGame)"), Target->NotSaved, 1);
    TestEqual(TEXT("Nomes viajam como texto"), Target->Label, FName(TEXT("Porta")));

    // O registro dentro do envelope do Cap. 56: ida e volta pelo caminho do slot.
    UVGSaveGame* Save = NewObject<UVGSaveGame>();
    const FGuid Id = FGuid::NewGuid();
    FVGActorRecord Record;
    Record.Properties = Bytes;
    Save->World.Add(Id, Record);
    FVGActorRecord Gone;
    Gone.bDestroyed = true;
    Save->World.Add(FGuid::NewGuid(), Gone);

    TArray<uint8> File;
    UGameplayStatics::SaveGameToMemory(Save, File);
    const UVGSaveGame* Loaded = Cast<UVGSaveGame>(UGameplayStatics::LoadGameFromMemory(File));
    if (!TestNotNull(TEXT("Envelope"), Loaded))
    {
        return false;
    }
    TestEqual(TEXT("Dois registros"), Loaded->World.Num(), 2);
    TestTrue(TEXT("Bytes intactos"), Loaded->World.Contains(Id) && Loaded->World[Id].Properties == Bytes);
    return true;
}

#endif
```

Comente a linha `ArNoDelta` nas duas funções e rode o teste. Se a primeira verificação falhar, você viu o bug da porta trancada de novo acontecer num teste de dez linhas. (⚠️ Se não falhar na sua versão, a serialização desse caminho não está fazendo delta; a linha continua inofensiva e documenta a intenção.)

---

## Projeto Vigília — a Casa de Força lembra

### O mapa de persistência do setor 1

| Ator | Estratégia | O que persiste |
|---|---|---|
| Portas (`AVGDoor`) | Componente | `State`, `OpenAlpha` |
| Disjuntores (`AVGBreakerSwitch`) | Componente | `bIsOn` |
| Gatilhos (`AVGEventTrigger`) com `bTriggerOnce` | Componente | `bHasTriggered` |
| Gatilho do susto | Derivado | O fato `S1.ScareDone` (Cap. 45) |
| Pickups (`AVGPickup`: baterias, chave) | Componente | "Destruído" |
| Documentos (`AVGReadable`) | Derivado | Os fatos de leitura (Cap. 48) |
| Setor (`AVGSector`), zonas seguras, postes | Derivado | O disjuntor principal |
| Caixas e cadeiras com física | Componente, `bSaveTransform` | O *transform* |
| Presença, Diretor, ameaça | Simulação | Nada |

O mapa vai para o `docs/design/save.md`, abaixo da tabela do Capítulo 56.

### O teste do Capítulo 56, de novo

Repita o teste que falhou: abra a porta do vestiário, pegue a bateria do depósito, dispare o alarme, atravesse `CP_S1_Corredor` e morra.

- A porta está aberta, **sem rangido** no primeiro frame e sem a Presença vindo investigar.
- A bateria não está na prateleira.
- O alarme não toca de novo.
- Um gatilho que você disparou **depois** do checkpoint dispara de novo quando você passa por ele.

Agora a variação de troca de nível: abra a porta, volte ao Pátio, entre de novo. A porta continua aberta (`EndPlay(LevelTransition)` → registro → `PostInitializeComponents` do ator novo).

E a do documento: abra o memorando e feche na hora (não conta como leitura), atravesse o checkpoint, morra. O memorando está de volta na mesa. Leia de verdade, atravesse o próximo checkpoint, morra: ele não volta mais.

### O teste de streaming

A Casa de Força é um nível só, mas o caminho de *streaming* precisa ser provado antes de o Salão das Turbinas precisar dele. Mova o depósito do subsolo para um subnível (`L_CasaDeForca_Deposito`), carregado e descarregado por um *Level Streaming Volume* na escada. Pegue a bateria, ligue um disjuntor, suba a escada até o subnível descarregar (`stat levels` mostra o estado) e desça de novo. O disjuntor continua ligado e a bateria continua pega, sem checkpoint nenhum no meio: só `RemovedFromWorld` e `PostInitializeComponents`.

### O inventário de dores

| # | Dor | Situação depois do Cap. 57 |
|---|---|---|
| 2 | Impossível salvar | ✅ Resolvida: narrativa, jogadora e mundo salvos, versionados e testados |
| 7 | Gatilhos que "lembram" errado | ✅ Agora também entre loads: disparados antes do checkpoint continuam disparados |
| 9 | Nada é testável | 🟡 Qualquer estado salvo é um ponto de partida; as ferramentas de inspeção são o Cap. 61 |

---

## Decisões arquiteturais

1. **Mundo = conteúdo + diferença**, com cinco tipos de mudança; a Vigília persiste alterados, destruídos e movidos, deriva o resto e não persiste criados.
2. **Persista a fonte, derive o resto:** setor pelo disjuntor, documentos pelos fatos, encontros pelo resultado.
3. **Identidade = `FGuid` explícito no `UVGPersistenceComponent`**, gerado no editor, regenerado em duplicação, verificado em runtime com `ensure`.
4. **Serialização filtrada** (`ArIsSaveGame`) e **sem delta** (`ArNoDelta`), com nomes e referências como texto (`FObjectAndNameAsStringProxyArchive`).
5. **Restaurar ≠ reencenar:** cada ator persistente tem um `SnapToState` silencioso; navegação é estado, som e ruído são efeitos.
6. **Momento:** atores restauram no **fim** do `PostInitializeComponents`; derivados leem no `BeginPlay`.
7. **Push no `EndPlay`, pull na inicialização**, o que cobre load de checkpoint, troca de nível e *streaming* com o mesmo código.

---

## Armadilhas

- **Duplicar atores no editor sem regenerar o GUID.** Duas portas, um registro. O `ensure` no registro em runtime é a última linha de defesa; não o desligue.
- **Serializar com delta.** Valores iguais ao padrão da classe, mas diferentes do estado inicial da instância, não voltam (a porta trancada de novo).
- **Esquecer `SaveGame` em campos de *struct*.** Com `ArIsSaveGame`, o *struct* marcado é gravado vazio se os campos não estiverem marcados.
- **Reencenar no load.** Rangidos, ruído para a IA, eventos no barramento, objetivos concluídos duas vezes.
- **Restaurar no `BeginPlay`.** A ordem entre atores não é garantida, e a porta lê o disjuntor antes de ele se restaurar.
- **Estado inicial no `BeginPlay`** (como a porta fazia). Ele roda **depois** da restauração e a desfaz. Estado inicial próprio vai no `PostInitializeComponents`, antes do `RestoreOwner`.
- **Persistir o que é derivado.** O setor salvo e o disjuntor salvo discordam no primeiro bug.
- **Checkpoint dentro de um gatilho.** A jogadora nasce dentro do volume e o dispara no primeiro frame. Checkpoints ficam fora de gatilhos; o validador do Capítulo 61 pode conferir isso.
- **Referências diretas entre atores de áreas de *streaming* diferentes.** Um lado carrega sem o outro. Cada ator guarda o próprio estado; a comunicação é por fatos e eventos.

---

## Exercício

**Parte 1 — o núcleo (1,5 h).** Implemente `FVGActorRecord`, `VGPersistence`, `UVGPersistenceComponent`, as adições ao `UVGSaveSubsystem` e o teste. Rode o teste com e sem `ArNoDelta`.

**Parte 2 — os atores (2 h).** Converta porta, disjuntor, gatilho e pickup; torne setor e documento derivados. Abra a Casa de Força no editor, salve o nível (os GUIDs vão para o disco) e confira no painel *Details* que cada ator persistente tem um id. Duplique uma porta com Ctrl+D e confira que o id da cópia é outro.

**Parte 3 — os testes do projeto (1,5 h).** Faça os três testes da seção Projeto: o do Capítulo 56, o de troca de nível e o de *streaming* com o subnível do depósito.

**Parte 4 — a sabotagem (30 min).** Force um GUID duplicado (copie o valor de um ator para outro pelo editor de propriedades, se a sua versão permitir, ou por um script de editor) e veja o `ensure` acontecer. Registre no `DEVLOG.md` a mensagem e o que ela diria a quem não escreveu o sistema.

---

## Desafio — o que nasce durante o jogo

A Vigília não persiste atores spawnados. Construa o suporte assim mesmo, para entender o custo:

1. Um registro de criação: `FVGSpawnedRecord` com `TSoftClassPtr<AActor>`, *transform*, nível e as propriedades `SaveGame`.
2. O `UVGPersistenceComponent` passa a aceitar atores sem GUID do conteúdo: gera um GUID no *spawn* e marca o registro como "criado".
3. Ao abrir um nível, um passo novo **recria** os registros "criados" daquele nível, antes de restaurar as propriedades.
4. Teste com um cheat que spawna uma caixa com física (`VGSpawnCrate`): empurre-a, atravesse um checkpoint, morra.
5. Responda no `DEVLOG.md`:
   - Em que momento a recriação precisa acontecer para que a caixa recriada não caia "de novo" no chão na frente da jogadora?
   - O que acontece se a classe da caixa for removida num patch?
   - Que sistema da Vigília deveria **usar** isso, se algum? Se nenhum, o que você aprendeu ao construir?

---

## Uso de IA

1. **Para classificar o mundo:**
   > "Aqui está a lista de atores interativos de um nível de um jogo de terror (classe, o que a jogadora pode fazer com eles, quem depende deles). Classifique cada mudança possível como alterado, destruído, movido, criado ou derivado. Para cada 'derivado', diga de que fonte ele deveria ser recalculado. Para cada par de atores que se leem mutuamente, aponte se a ordem de inicialização pode causar um bug ao restaurar. [lista]"

2. **Para revisar o ciclo de vida do GUID:**
   > "Revise este componente da Unreal Engine 5 que gera um FGuid por ator colocado no nível (OnRegister no editor, PostEditImport, PostDuplicate). Liste as formas de duplicar ou recriar atores no editor (Ctrl+D, Alt+arrastar, copiar e colar, duplicar o nível, converter para Blueprint, mover para outro subnível) e diga, para cada uma, se a minha implementação gera um id novo, mantém o antigo ou deixa um duplicado. Marque o que você não tem certeza de que acontece na engine. [código]"

3. **Para separar restaurar de reencenar:**
   > "Esta é a função de transição de estado de uma porta num jogo (anuncia um delegate, reporta ruído para a IA, atualiza o modificador de navegação, liga o tick, toca som). Separe o que é ESTADO do que é EFEITO, e escreva a função que aplica só o estado, para ser usada ao carregar um save. [código]"

**Cuidado específico:** pedidos de "sistema de save de mundo para Unreal" costumam voltar com a abordagem C (serializar todos os atores do nível) ou com uma interface `ISaveable` cheia de métodos, sem nenhuma palavra sobre **momento de restauração**, **delta** ou **reencenação**, que são exatamente os três bugs deste capítulo. Use a IA para encontrar casos de borda no **seu** desenho; desconfie de qualquer resposta que não pergunte quando cada ator lê o outro.

---

## Checklist

- [ ] Sei classificar uma mudança no mundo em alterado, destruído, movido, criado ou derivado, e prefiro derivar quando há fonte.
- [ ] Meus atores persistentes têm um `FGuid` gerado no editor, e duplicar no editor gera um id novo.
- [ ] Sei por que `ArNoDelta` é necessário, e tenho um teste que quebra sem ele.
- [ ] Restaurar não toca som, não faz ruído para a IA e não publica eventos.
- [ ] Atores restauram no fim do `PostInitializeComponents`; estado inicial nunca fica no `BeginPlay`.
- [ ] Testei load de checkpoint, troca de nível e *streaming* de um subnível com o mesmo código.
- [ ] Sei dizer o que a Vigília **não** persiste, e por que a jogadora não percebe.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **World Partition** (incluindo *Data Layers* e *One File Per Actor*), **Level Streaming** e a página de especificadores de propriedade (`SaveGame`). Leia `Archive.h` (`FArchiveState`) e `ObjectAndNameAsStringProxyArchive.h` no código da engine.
- **Epic Developer Community** (dev.epicgames.com/community): há tutoriais da comunidade sobre salvar estado de mundo com atores e com *World Partition*; confira a versão da engine de cada um antes de copiar código.
- ***Game Engine Architecture***, de Jason Gregory: as seções sobre mundos, *streaming* e objetos de jogo explicam por que identidade e ciclo de vida de objetos são o centro de qualquer sistema de persistência.

---

➡️ **Próximo:** [Capítulo 58 — Performance](cap-58-performance.md)

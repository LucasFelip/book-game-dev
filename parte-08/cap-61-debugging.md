# Capítulo 61 — Debugging

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que depurar um jogo exige ferramentas além do *debugger* da IDE, e organizar as ferramentas em quatro camadas: na tela, gravadas, interativas e *post mortem*;
- usar *draw debug* e CVars com disciplina: barato quando desligado, ausente em Shipping;
- gravar e reler o comportamento de agentes no **Visual Logger**, com *snapshots* do estado da Vigília;
- criar categorias próprias no **Gameplay Debugger**: uma para o estado narrativo e o save, outra para a IA da Vigília;
- desenhar cheats como ferramentas de teste: pela API do jogo, explícitos, idempotentes e fora do Shipping;
- usar logs com categorias e verbosidade, e saber o que eles custam;
- ler um *crash*: pilha de chamadas, *minidump*, símbolos; e escolher entre `check`, `verify` e `ensure`;
- fechar a dor 9 do Interlúdio I: **nada é testável**.

---

## Contexto

O Capítulo 1 disse que a indústria depende de ferramentas de depuração visual, e prometeu aprofundá-las aqui. O Capítulo 11 criou a primeira CVar (`vg.Flicker.Enabled`) e pediu uma lista, no `DEVLOG.md`, das CVars `vg.Debug.*` que a Vigília ia precisar: "ela vira o painel de debug do Capítulo 61". O Capítulo 16 criou o `UVGCheatManager` e anunciou que o Capítulo 61 o expandiria "com teleporte, invulnerabilidade, ligar/desligar a IA". O Capítulo 33 apresentou o Gameplay Debugger e o Visual Logger para a IA, e o Capítulo 34 gravou o caminho de estados dos vigias com `UE_VLOG`.

Desde então, o projeto acumulou ferramentas, uma por sistema: `vg.Debug.Events`, `Movement`, `Noise`, `Utility`, `Dialogue`, `Quests`, `Narrative`; cheats como `VGAddFact`, `VGQuestJump`, `VGNewGame`, `VGSave`, `VGLoad`, `VGPerfHunt`. Cada uma resolve o problema do seu capítulo. Juntas, ainda não formam um **painel**: não há um lugar para ver, ao mesmo tempo, o que a Presença sabe, em que fase está o Diretor, quais fatos existem e o que o último save guardou.

A dor 9 do Interlúdio I era: "para verificar a fala final do caminho 'leu o memorando', é preciso jogar o capítulo inteiro". A Parte VI resolveu metade (estado consultável, cheats de fato e de quest, JSON de estados); a Parte VIII trouxe saves que viram pontos de partida. Este capítulo fecha a outra metade: **ver** o que está acontecendo, e entender o que deu errado quando algo quebra.

---

## 61.1 Por que o *debugger* não basta

Num serviço, um *breakpoint* na linha certa costuma resolver: você para a requisição, inspeciona o estado e entende. Num jogo, três coisas atrapalham:

1. **O bug é uma história no tempo.** "A Presença desistiu cedo demais" não está numa linha; está numa sequência de decisões ao longo de quatro segundos, e o que importa é **por que** cada decisão foi tomada naquele momento.
2. **O bug é espacial.** "O ponto de busca estava atrás da parede" só faz sentido desenhado no mundo.
3. **Parar o jogo muda o jogo.** Um *breakpoint* congela o tempo; a física, o áudio e o tempo real continuam a contar quando você volta, e a situação desaparece.

Por isso as ferramentas de depuração de jogos se organizam em quatro camadas:

| Camada | Pergunta | Ferramentas |
|---|---|---|
| **Na tela, agora** | O que está acontecendo neste instante? | *Draw debug*, CVars `vg.Debug.*`, `stat`, Gameplay Debugger |
| **Gravada** | O que aconteceu, e em que ordem? | Visual Logger, logs, *traces* do Insights |
| **Interativa** | E se eu forçar este estado? | Cheats, saves, JSON de estado narrativo |
| ***Post mortem*** | Por que travou? | Pilha de chamadas, *minidump*, símbolos, `ensure` |

O *debugger* da IDE continua essencial, mas como a última ferramenta, quando você já sabe **onde** olhar.

---

## 61.2 *Draw debug* e CVars

`DrawDebugLine`, `DrawDebugSphere`, `DrawDebugBox`, `DrawDebugCapsule`, `DrawDebugString` e afins (`DrawDebugHelpers.h`) desenham formas no mundo, por um frame, por uma duração ou de forma persistente (até `FlushPersistentDebugLines`). São a ferramenta mais rápida para responder "onde?".

O livro já seguiu um padrão para eles desde o Capítulo 11, e é hora de escrevê-lo como regra:

1. **Toda forma de depuração tem uma CVar `vg.Debug.<Sistema>`**, desligada por padrão.
2. **Com a CVar desligada, nada é pago**: nem o desenho, nem a formatação de texto. A leitura da CVar vem antes de qualquer trabalho.
3. **Em Shipping, o código não existe**: o bloco fica dentro de `#if ENABLE_DRAW_DEBUG`, que a engine define como falso em Shipping.
4. **CVars que mudam o comportamento do jogo** (não só o desenho), como `vg.Debug.FixedSpreadSeed`, levam `ECVF_Cheat`: em builds finais, elas ficam escondidas e não podem ser alteradas.

E uma distinção que o Capítulo 11 já fez e vale repetir aqui: **`vg.Flicker.Enabled` não é ferramenta de depuração.** É uma opção de acessibilidade. Em Shipping, sem console, ela só existe se estiver no menu de opções (Capítulo 55), e o Capítulo 62 confere isso.

O inventário de CVars da Vigília, como ficou:

| CVar | Sistema | Capítulo |
|---|---|---|
| `vg.Debug.Events` | Barramento de eventos | 24 |
| `vg.Debug.Movement` | Perfil de movimento | 25 |
| `vg.Debug.Noise` | Ruído para a IA | 36 |
| `vg.Debug.Utility` | Pontuação de utilidade | 40 |
| `vg.Debug.Dialogue` | Canal do rádio, fila | 44 |
| `vg.Debug.Quests` | Quests e etapas | 45 |
| `vg.Debug.Narrative` | Fatos, contadores, quests registradas | 46 |
| `vg.Debug.Interaction`, `vg.Debug.Flicker` | Interação, *flicker* | 11, 19 |
| `vg.Debug.FixedSpreadSeed` | Dispersão determinística (teste) | 27 |
| `vg.Camera.Motion`, `vg.Flicker.Enabled` | Conforto e acessibilidade (**não** são *debug*) | 11, 18 |

As CVars desenham **no mundo** e mostram **um sistema**. O que falta é uma visão que junte sistemas e acompanhe **um agente**. É o trabalho do Gameplay Debugger.

---

## 61.3 Visual Logger: o que aconteceu, e por quê

O **Visual Logger** grava, por objeto e ao longo do tempo, mensagens de log, formas geométricas e *snapshots* de estado. Depois, você navega pela linha do tempo: escolhe um agente, arrasta o cursor para o segundo 12,4 e vê o que ele sabia, onde achava que a jogadora estava e o que decidiu. O Capítulo 33 o descreveu; o Capítulo 34 já gravou os estados dos vigias com `UE_VLOG`.

As peças:

- **Macros** que escrevem no registro do objeto: `UE_VLOG` (texto), `UE_VLOG_LOCATION` (um ponto), `UE_VLOG_SEGMENT` (uma linha), `UE_VLOG_BOX`, e as versões condicionais (`UE_CVLOG`). Elas somem de builds sem log visual (Shipping).
- **Snapshots**: um objeto que implementa `IVisualLoggerDebugSnapshotInterface` tem `GrabDebugSnapshot` chamado a cada entrada, e preenche categorias de estado (`FVisualLogStatusCategory`). O `AAIController` já implementa a interface e grava o estado da BT e do *blackboard*.
- **A janela**, aberta pelo menu de ferramentas de depuração do editor (⚠️ o caminho do menu muda entre versões), com gravação, linha do tempo por objeto, filtros por categoria e desenho das formas no *viewport*. Gravações podem ser salvas e reabertas.

O valor do Visual Logger é responder **por quê** depois do fato. "A Presença desistiu cedo" vira: no segundo 12,4 a consciência caiu abaixo do limiar porque a jogadora entrou numa zona segura; a última posição conhecida ficou na porta; o EQS escolheu um ponto de busca do outro lado. Nada disso aparece num *breakpoint*.

> 🌉 **Ponte:** o Capítulo 33 já comparou o Visual Logger a *tracing* distribuído gravado, e a comparação continua boa: um *trace* por agente, com contexto em cada passo.
>
> 🧱 **Onde a ponte cai** (o que este capítulo acrescenta): um *trace* de serviço registra o que **aconteceu**; o *snapshot* do Visual Logger registra também o que o agente **acreditava** (consciência, última posição conhecida, alvo). Em IA de jogo, o bug quase sempre está na crença, e não no ato.

---

## 61.4 Gameplay Debugger: o painel ao vivo

O **Gameplay Debugger** é uma sobreposição na tela, ativada durante o jogo (por padrão, a tecla de apóstrofo, ou o cheat `EnableGDT`), organizada em **categorias** ligadas e desligadas pelo teclado numérico. As categorias da engine mostram o pawn selecionado, a BT, o EQS, a percepção e a navegação. A documentação descreve cinco categorias padrão e espaço para categorias do projeto.

Duas propriedades o tornam a ferramenta certa para o "painel" que o Capítulo 11 pediu:

- **É feito para estender.** Uma categoria é uma classe com dois métodos: `CollectData` (junta os dados) e `DrawData` (desenha na tela). Ela pode mostrar dados globais ou do ator selecionado, e desenhar formas no mundo.
- **Funciona em rede.** Os dados são coletados do lado com autoridade e **replicados** para quem desenha. Em single-player isso não importa; na Parte IX, a mesma categoria mostra o estado do servidor num cliente.

A Vigília cria duas categorias:

- **VigiliaNarrative**, global: fatos agrupados por prefixo, contadores, quests registradas, o último save e o mundo persistente. É o painel que o Capítulo 46 recomendou ("a interface que **você** precisa para entender por que uma fala tocou"), agora num lugar só.
- **VigiliaAI**, por agente: o estado de consciência e o valor, se o alvo está visível, a última posição conhecida (desenhada no mundo), a ameaça global, a fase e a tensão do Diretor.

O módulo `GameplayDebugger` só existe onde a engine o compila. ⚠️ Em versões recentes, a engine define `WITH_GAMEPLAY_DEBUGGER` a partir das regras do *target* (`bUseGameplayDebugger`); em versões antigas, a documentação mandava definir a macro à mão no `Build.cs`. Confira o `GameplayDebugger.Build.cs` da sua versão e use o padrão dela.

---

## 61.5 Cheats como ferramentas de teste

O `UCheatManager` da engine já traz cheats úteis: `God` (invulnerabilidade pelo sistema de dano da engine), `Ghost`, `Fly` e `Walk`, `Teleport` (para onde a câmera aponta), `Slomo`, `ToggleDebugCamera` (uma câmera livre, separada do pawn) e `DestroyTarget`. O `UVGCheatManager` acrescenta os da Vigília.

Um cheat bem desenhado segue quatro regras:

1. **Passa pela API do jogo.** `VGAddFact` chama `AddFact`, e por isso anuncia a mudança como qualquer outra fonte. Um cheat que escreve direto no estado testa um caminho que o jogo nunca usa, e esconde bugs.
2. **É explícito e idempotente.** `VGAIFreeze 1` congela; `VGAIFreeze 0` descongela. Um cheat que **alterna** depende de um estado guardado em algum lugar, e esse estado mente depois de um load (o cheat manager é recriado com o controller a cada nível, e uma variável estática sobrevive a ele).
3. **Deixa rastro.** Todo cheat escreve uma linha no log. Um bug reportado com "eu usei `VGGod` no meio" é outro bug.
4. **Não existe em Shipping.** A engine compila o cheat manager só onde `UE_WITH_CHEAT_MANAGER` é verdadeiro, e ela é falsa em Shipping. O Capítulo 62 confere.

O que os cheats permitem, somados aos saves e ao JSON do Capítulo 46, é a **receita de estado**: em vez de jogar dez minutos para chegar a um caso, você monta o caso em segundos.

```text
  "Sônia, caminho 'leu o memorando', depois do susto":
     VGNewGame
     VGNarrativeImport s1_antes_do_puzzle_sem_memo.json   (Cap. 46)
     VGAddFact Narrative.Fact.Document.Memo.Read
     VGGotoCheckpoint CP_S1_Subsolo
```

As receitas vão para `docs/qa/receitas.md`. São os casos de teste manuais do projeto.

> 🌉 **Ponte:** cheats são os *endpoints* administrativos e os *fixtures* de teste de um serviço: um jeito de pôr o sistema num estado conhecido sem passar pelo fluxo inteiro.
>
> 🧱 **Onde a ponte cai:** num serviço, o *endpoint* administrativo costuma ir para produção protegido por autenticação. Num jogo para um jogador, não há a quem pedir credencial: a única proteção é o código não existir no build final. E o cheat altera um estado que outros sistemas leem **no mesmo frame**, sem transação: um cheat que pula etapas pode deixar o jogo num estado que o fluxo normal nunca produziria. Por isso a regra 1.

---

## 61.6 Logs

A categoria `LogVigilia` (Capítulo 11) e a verbosidade (`Error`, `Warning`, `Display`, `Log`, `Verbose`, `VeryVerbose`) são a base. O que vale acrescentar:

- **Verbosidade em tempo de execução.** `Log LogVigilia Verbose` no console muda a verbosidade da categoria; `-LogCmds="LogVigilia Verbose"` na linha de comando faz o mesmo desde o início. Escreva em `Verbose` o que é útil numa investigação e ruído no resto do tempo.
- **Logs condicionais**: `UE_CLOG(Condição, ...)` evita o `if` em volta.
- ***Log* estruturado**: versões recentes têm `UE_LOGFMT` (`Logging/StructuredLog.h`), com campos nomeados em vez de `printf` (⚠️ disponível a partir de 5.2; confira).
- **Onde fica:** `Saved/Logs/<Projeto>.log`, com cópias das sessões anteriores. Num build empacotado, numa pasta do usuário (Capítulo 62).
- **Custo:** formatar uma string custa, mesmo que ninguém leia. Log por frame, por agente, no game thread, aparece no profiling (Capítulo 59). Em Shipping, os logs são compilados fora por padrão (Capítulo 62).

E uma regra que conecta logs a *crashes*: **o log é a primeira coisa que você pede num relatório de bug.** O `BuildVersion` gravado no save (Capítulo 56) e a primeira linha do log devem dizer qual build era.

---

## 61.7 *Crashes*: `check`, `verify`, `ensure` e o *minidump*

### As asserções

A Unreal tem três famílias de asserção, e a diferença entre elas está no que acontece em cada configuração de build:

| Macro | Em Debug e Development | Em Shipping (padrão) | Expressão avaliada em Shipping? | Derruba o processo? |
|---|---|---|---|---|
| `check(x)`, `checkf(x, ...)` | Ativa | Removida | **Não** | Sim |
| `verify(x)`, `verifyf(x, ...)` | Ativa | Só a expressão | **Sim** | Sim (fora de Shipping) |
| `ensure(x)`, `ensureMsgf(x, ...)` | Ativa: avisa e grava a pilha **uma vez** por local, por sessão | Só a expressão | **Sim** (o valor continua sendo devolvido) | Não |
| `ensureAlways(x)` | Como `ensure`, mas toda vez | Só a expressão | Sim | Não |
| `checkSlow(x)` | Só em Debug | Removida | Não | Sim |
| `checkNoEntry()`, `unimplemented()` | Ativas | Removidas | — | Sim |

(⚠️ Um projeto pode manter `check` em Shipping pelas regras do *target*; o padrão é removê-lo.)

Três regras práticas saem da tabela:

1. **Nunca ponha efeito colateral dentro de `check`.** `check(Inventory.Remove(Item))` remove o item em Development e **não remove** em Shipping. Para chamadas com efeito, `verify`.
2. **`ensure` para "não deveria acontecer, mas o jogo continua".** É o que o livro tem usado: `if (!ensureMsgf(...)) { return; }` no `RestoreSnapshot` (Capítulo 46), na cascata de fatos, no GUID duplicado (Capítulo 57). Em Development, o `ensure` grava a pilha no log e, com o depurador ligado, para nele; em Shipping, a condição continua valendo e o `return` acontece.
3. **`check` para invariantes cuja violação significa memória corrompida ou erro de programação sem saída**: um componente criado no construtor que é nulo, um índice que não pode estar fora do intervalo. O *crash* é a resposta certa, porque continuar produz um estado que ninguém consegue depurar.

E uma distinção que não é de asserção: um objeto que **pode** ter sido destruído por outro sistema (um ator, um alvo da IA) se testa com `IsValid`, e o código segue sem ele. `check(Target)` num alvo que a IA pode perder é transformar uma situação normal em *crash*.

### O *crash* em si

Quando o processo cai, a engine escreve em `Saved/Crashes/<pasta da ocorrência>/` um relatório com o log e um ***minidump*** (`.dmp`): a pilha de chamadas de cada thread e parte da memória no instante da falha. Em builds de desenvolvimento, o *Crash Reporter* mostra a pilha na hora.

Para ler um *minidump*:

1. Abra o `.dmp` no Visual Studio.
2. Aponte os **símbolos** (`.pdb`) **do mesmo build** e o código-fonte da mesma versão. Sem os símbolos certos, a pilha é uma lista de endereços.
3. Leia a pilha do *crash* de baixo para cima até o primeiro quadro do **seu** código. Quase sempre o problema está ali ou um quadro acima.

Por isso o Capítulo 62 manda **arquivar os símbolos de cada build** distribuído: um *crash* da máquina de outra pessoa só se lê com os `.pdb` daquele build exato.

Os tipos de *crash* mais comuns, e por onde começar:

| Sintoma | Causa típica | Por onde começar |
|---|---|---|
| Violação de acesso perto de um ponteiro | Objeto destruído ou coletado (`UPROPERTY` faltando, Cap. 11) | O ponteiro na pilha; quem deveria mantê-lo vivo |
| Asserção (`check`) | Invariante violada | A mensagem do `checkf`; o estado que a quebrou |
| Travamento sem *crash* (*hang*) | Laço infinito, espera eterna | *Break All* no depurador; o laço de 256 itens por tick do Cap. 45 existe para transformar isso em `ensure` |
| *Crash* só em Shipping | Variável não inicializada, código dentro de `check`, asset não cozido | O log do build; configuração Test (Cap. 62) |
| Perda do dispositivo de GPU | Driver, *shader*, memória de vídeo | Opções de depuração de *crash* de GPU da engine (por exemplo, `-gpucrashdebugging`; ⚠️ confira na sua versão) e as ferramentas do fabricante |

### Depurar com a IDE, quando chegar a hora

- **DebugGame** é a configuração em que o código **do seu módulo** é compilado sem otimização e a engine continua otimizada: variáveis locais visíveis, passo a passo confiável, desempenho aceitável.
- Para desligar a otimização de um trecho só, versões recentes têm `UE_DISABLE_OPTIMIZATION` e `UE_ENABLE_OPTIMIZATION` em volta do código (⚠️ os nomes mudaram ao longo das versões 5.x; antes eram outros). Nunca deixe isso num *commit*.
- *Breakpoints* condicionais e *data breakpoints* (parar quando um endereço muda) resolvem a pergunta "quem está mudando isto?", que nenhuma outra ferramenta responde tão bem.

---

## Estudos de caso

### Max Payne e o console de desenvolvedor

**[FATO PÚBLICO — amplamente documentado por jogadores]** O *Max Payne* original, no PC, aceitava um parâmetro de linha de comando que habilitava um console de desenvolvedor, com comandos como invulnerabilidade e todas as armas.

**[INFERÊNCIA]** É o caso de ferramentas de depuração que ficaram no build final, mas **escondidas** atrás de uma porta que o jogador comum não abre. Para um jogo para um jogador, sem competição, isso tem pouco risco e algum valor (a comunidade de *mods* e de curiosos). O estúdio fez uma escolha, e não um esquecimento.

**Lição para a Vigília:** o que fica no Shipping é **decisão**, tomada no Capítulo 62. A Vigília remove cheats e console do build final, porque o terror depende de o jogador não poder se tornar invulnerável com duas teclas; se um dia quiser um "modo história" com invulnerabilidade, ele vira uma **opção de jogo**, não um cheat.

### GTA e os códigos de trapaça como recurso

**[FATO PÚBLICO — observável jogando]** Os GTA têm códigos de trapaça digitados durante o jogo (sequências de botões no console, ou palavras no PC; no *GTA IV*, números discados no celular da personagem), que dão armas, vida, mudam o clima e o nível de procura.

**[INFERÊNCIA]** Aqui o cheat deixou de ser ferramenta de desenvolvimento e virou **recurso de design**: parte da diversão de um mundo aberto sem roteiro rígido. Ele passa pelas mesmas APIs do jogo (o nível de procura do *wanted system*, a vida, o inventário), e por isso funciona em qualquer momento sem quebrar o mundo.

**Lição para a Vigília:** mesmo um cheat de desenvolvimento deve passar pela API do jogo, como um código de GTA. Um cheat que escreve no estado por fora testa um jogo que não existe.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| CVars de *debug* | *Feature flags* de diagnóstico | Desligadas, precisam custar zero; em Shipping, não existem |
| Visual Logger | *Tracing* gravado | Grava também a **crença** do agente, e desenha no mundo |
| Gameplay Debugger | Painel de observabilidade | Sobreposto ao próprio produto, por agente, em tempo real |
| Cheats | *Endpoints* administrativos, *fixtures* | Não há autenticação: o código simplesmente não pode ir ao build final |
| `ensure` | Erro reportado sem derrubar o serviço | Avisa uma vez por local; em Shipping, só a condição sobra |
| `check` | `assert` / *fail fast* | Some em Shipping: nunca com efeito colateral |
| *Minidump* + `.pdb` | *Core dump* + símbolos | O símbolo precisa ser **daquele** build, arquivado antes de distribuir |

---

## Unreal Engine: o que existe

- ***Draw debug*** (`DrawDebugHelpers.h`) e `ENABLE_DRAW_DEBUG`.
- **CVars** (`TAutoConsoleVariable`) com *flags* como `ECVF_Cheat` e `ECVF_ReadOnly`.
- **Visual Logger**: `UE_VLOG*`, `IVisualLoggerDebugSnapshotInterface`, a janela de gravação e reprodução; `ENABLE_VISUAL_LOG`.
- **Gameplay Debugger**: `FGameplayDebuggerCategory`, `IGameplayDebugger::RegisterCategory`, replicação de dados (`SetDataPackReplication`), formas (`FGameplayDebuggerShape`), configurações em *Project Settings*.
- **Cheats**: `UCheatManager` (com `God`, `Ghost`, `Fly`, `Teleport`, `Slomo`, `ToggleDebugCamera`...), `UFUNCTION(Exec)`, `UE_WITH_CHEAT_MANAGER`, `EnableGDT`.
- **Logs**: `UE_LOG`, `UE_CLOG`, `UE_LOGFMT`, verbosidade em execução, `-LogCmds`.
- **Asserções**: `check`, `verify`, `ensure` e variantes.
- ***Crashes***: *Crash Reporter*, `Saved/Crashes`, *minidumps*; configurações DebugGame e Development; macros de desotimização local.

O que **não** existe: o painel da **sua** história e da **sua** IA. A engine mostra a BT; ela não sabe o que é um fato narrativo nem o que é o Diretor da Vigília.

---

## Abordagens

Onde mostrar o estado narrativo e o da IA, juntos e ao vivo:

| Critério | A. Mais CVars na tela (como até aqui) | **B. Categorias do Gameplay Debugger** | C. Painel próprio (UMG, ou uma biblioteca de UI imediata) |
|---|---|---|---|
| **Complexidade** | Mínima por sistema | Baixa: duas classes e o registro | Média a alta |
| **Visão conjunta** | Não: cada CVar desenha o seu | Sim: categorias lado a lado, por agente | Sim |
| **Seleção de agente** | Manual | Nativa | A construir |
| **Rede (Parte IX)** | Mostra só o local | Replica do servidor | A construir |
| **Shipping** | Some com `ENABLE_DRAW_DEBUG` | Some com o módulo | A cuidar à mão |
| **Adequação à Vigília** | Continua para desenhos no mundo | **Sim**, para o painel | Excesso |

**Decisão: B** para o painel, mantendo as CVars de A para o que é desenho espacial de um sistema (ruído, interação, movimento).

---

## Implementação

### 1. Uma regra pura para agrupar fatos

O painel do Capítulo 46 agrupa fatos "pelo segundo nível da tag". A regra vira uma função pura, usada pela CVar `vg.Debug.Narrative` e pela categoria nova, e testada:

```cpp
// Source/Vigilia/Debug/VGDebugRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGDebugRules
{
    /**
     * "Narrative.Fact.S1.ScareDone" → grupo "S1", item "ScareDone".
     * Descarta os dois primeiros segmentos (o espaço de nomes); o terceiro é o grupo; o resto, o item.
     * Nomes curtos demais vão para o grupo "-". Grupos e itens em ordem alfabética.
     */
    TArray<TPair<FString, TArray<FString>>> GroupByPrefix(const TArray<FString>& TagNames);
}
```

```cpp
// Source/Vigilia/Debug/VGDebugRules.cpp
#include "Debug/VGDebugRules.h"

TArray<TPair<FString, TArray<FString>>> VGDebugRules::GroupByPrefix(const TArray<FString>& TagNames)
{
    TMap<FString, TArray<FString>> Groups;
    for (const FString& Name : TagNames)
    {
        TArray<FString> Parts;
        Name.ParseIntoArray(Parts, TEXT("."));
        if (Parts.Num() < 4)
        {
            Groups.FindOrAdd(TEXT("-")).Add(Name);
            continue;
        }
        const FString Item = FString::Join(TArrayView<const FString>(Parts).RightChop(3), TEXT("."));
        Groups.FindOrAdd(Parts[2]).Add(Item);
    }

    TArray<TPair<FString, TArray<FString>>> Sorted;
    for (TPair<FString, TArray<FString>>& Pair : Groups)
    {
        Pair.Value.Sort();
        Sorted.Emplace(Pair.Key, MoveTemp(Pair.Value));
    }
    Sorted.Sort([](const TPair<FString, TArray<FString>>& A, const TPair<FString, TArray<FString>>& B)
    {
        return A.Key < B.Key;
    });
    return Sorted;
}
```

🔁 O desenho de `vg.Debug.Narrative` (Capítulo 46) passa a chamar `GroupByPrefix` com os nomes dos fatos (`Tag.ToString()` de cada um), em vez de agrupar por conta própria.

### 2. As categorias do Gameplay Debugger

```cpp
// Source/Vigilia/Debug/VGGameplayDebuggerCategories.h
#pragma once

#if WITH_GAMEPLAY_DEBUGGER

#include "CoreMinimal.h"
#include "GameplayDebuggerCategory.h"

/** Estado narrativo e save. Global: aparece sem ator selecionado. */
class FVGGameplayDebuggerCategory_Narrative : public FGameplayDebuggerCategory
{
public:
    FVGGameplayDebuggerCategory_Narrative();
    virtual void CollectData(APlayerController* OwnerPC, AActor* DebugActor) override;
    virtual void DrawData(APlayerController* OwnerPC, FGameplayDebuggerCanvasContext& CanvasContext) override;
    static TSharedRef<FGameplayDebuggerCategory> MakeInstance();

protected:
    /** Coletado com autoridade, replicado para quem desenha (Parte IX). */
    struct FRepData
    {
        TArray<FString> Lines;
        void Serialize(FArchive& Ar) { Ar << Lines; }
    };
    FRepData DataPack;
};

/** O agente selecionado (consciência, alvo) e o contexto (ameaça, Diretor). */
class FVGGameplayDebuggerCategory_AI : public FGameplayDebuggerCategory
{
public:
    FVGGameplayDebuggerCategory_AI();
    virtual void CollectData(APlayerController* OwnerPC, AActor* DebugActor) override;
    virtual void DrawData(APlayerController* OwnerPC, FGameplayDebuggerCanvasContext& CanvasContext) override;
    static TSharedRef<FGameplayDebuggerCategory> MakeInstance();

protected:
    struct FRepData
    {
        TArray<FString> Lines;
        void Serialize(FArchive& Ar) { Ar << Lines; }
    };
    FRepData DataPack;
};

#endif
```

```cpp
// Source/Vigilia/Debug/VGGameplayDebuggerCategories.cpp
#include "Debug/VGGameplayDebuggerCategories.h"

#if WITH_GAMEPLAY_DEBUGGER

#include "AI/VGAwarenessComponent.h"
#include "AI/VGDirectorSubsystem.h"
#include "AI/VGThreatSubsystem.h"
#include "AIController.h"
#include "Debug/VGDebugRules.h"
#include "GameFramework/Pawn.h"
#include "Narrative/VGNarrativeSubsystem.h"
#include "Save/VGSaveSubsystem.h"

// ------------------------------------------------------------- Narrativa

FVGGameplayDebuggerCategory_Narrative::FVGGameplayDebuggerCategory_Narrative()
{
    bShowOnlyWithDebugActor = false;
    SetDataPackReplication<FRepData>(&DataPack);
}

TSharedRef<FGameplayDebuggerCategory> FVGGameplayDebuggerCategory_Narrative::MakeInstance()
{
    return MakeShareable(new FVGGameplayDebuggerCategory_Narrative());
}

void FVGGameplayDebuggerCategory_Narrative::CollectData(APlayerController* OwnerPC, AActor* DebugActor)
{
    DataPack.Lines.Reset();
    const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(OwnerPC);
    if (!Narrative)
    {
        return;
    }
    const FVGNarrativeState& State = Narrative->CaptureSnapshot();

    TArray<FString> FactNames;
    for (const FGameplayTag& Fact : State.Facts)
    {
        FactNames.Add(Fact.ToString());
    }
    for (const TPair<FString, TArray<FString>>& Group : VGDebugRules::GroupByPrefix(FactNames))
    {
        DataPack.Lines.Add(FString::Printf(TEXT("{yellow}%s{white}  %s"), *Group.Key, *FString::Join(Group.Value, TEXT(", "))));
    }
    for (const TPair<FGameplayTag, int32>& Counter : State.Counters)
    {
        DataPack.Lines.Add(FString::Printf(TEXT("{grey}contador{white} %s = %d"), *Counter.Key.ToString(), Counter.Value));
    }
    for (const FVGQuestRecord& Quest : State.Quests)
    {
        DataPack.Lines.Add(FString::Printf(TEXT("{green}quest{white} %s  etapa %s"),
                                           *Quest.QuestTag.ToString(), *Quest.StageId.ToString()));
    }
    if (const UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(OwnerPC))
    {
        DataPack.Lines.Add(Save->DescribeForDebug());
        DataPack.Lines.Add(Save->DescribeWorldForDebug());
    }
}

void FVGGameplayDebuggerCategory_Narrative::DrawData(APlayerController* OwnerPC, FGameplayDebuggerCanvasContext& CanvasContext)
{
    for (const FString& Line : DataPack.Lines)
    {
        CanvasContext.Printf(TEXT("%s"), *Line);
    }
}

// ------------------------------------------------------------- IA

static const TCHAR* AwarenessName(EVGAwarenessState State)
{
    switch (State)
    {
    case EVGAwarenessState::Unaware:    return TEXT("Unaware");
    case EVGAwarenessState::Suspicious: return TEXT("Suspicious");
    case EVGAwarenessState::Aware:      return TEXT("Aware");
    }
    return TEXT("?");
}

FVGGameplayDebuggerCategory_AI::FVGGameplayDebuggerCategory_AI()
{
    SetDataPackReplication<FRepData>(&DataPack); // bShowOnlyWithDebugActor fica verdadeiro: precisa de um agente
}

TSharedRef<FGameplayDebuggerCategory> FVGGameplayDebuggerCategory_AI::MakeInstance()
{
    return MakeShareable(new FVGGameplayDebuggerCategory_AI());
}

void FVGGameplayDebuggerCategory_AI::CollectData(APlayerController* OwnerPC, AActor* DebugActor)
{
    DataPack.Lines.Reset();
    const APawn* Pawn = Cast<APawn>(DebugActor);
    const AController* Controller = Pawn ? Pawn->GetController() : nullptr;
    const UVGAwarenessComponent* Awareness = Controller ? Controller->FindComponentByClass<UVGAwarenessComponent>() : nullptr;
    if (Awareness)
    {
        DataPack.Lines.Add(FString::Printf(TEXT("{yellow}consciência{white} %s  %.2f  alvo visível: %s"),
            AwarenessName(Awareness->GetAwarenessState()), Awareness->GetAwareness(),
            Awareness->IsTargetVisible() ? TEXT("sim") : TEXT("não")));
        // Forma no mundo, replicada junto com os dados.
        AddShape(FGameplayDebuggerShape::MakePoint(Awareness->GetLastKnownLocation(), 30.0f, FColor::Orange,
                                                   TEXT("última posição conhecida")));
    }

    const UWorld* World = OwnerPC->GetWorld();
    if (const UVGThreatSubsystem* Threat = World->GetSubsystem<UVGThreatSubsystem>())
    {
        DataPack.Lines.Add(FString::Printf(TEXT("{yellow}ameaça{white} %s"),
                                           *UEnum::GetDisplayValueAsText(Threat->GetThreatLevel()).ToString()));
    }
    if (const UVGDirectorSubsystem* Director = World->GetSubsystem<UVGDirectorSubsystem>())
    {
        DataPack.Lines.Add(FString::Printf(TEXT("{yellow}diretor{white} %s  tensão %.2f"),
            *UEnum::GetDisplayValueAsText(Director->GetPhase()).ToString(), Director->GetTension()));
    }
}

void FVGGameplayDebuggerCategory_AI::DrawData(APlayerController* OwnerPC, FGameplayDebuggerCanvasContext& CanvasContext)
{
    for (const FString& Line : DataPack.Lines)
    {
        CanvasContext.Printf(TEXT("%s"), *Line);
    }
}

#endif
```

`UEnum::GetDisplayValueAsText` exige que `EVGThreatLevel` e `EVGDirectorPhase` sejam `UENUM()`. Se não forem, use um `switch` como o de `AwarenessName`.

### 3. O módulo registra as categorias

🔁 O módulo da Vigília usava a implementação padrão. Ele ganha uma classe própria, só para registrar as categorias:

```cpp
// Source/Vigilia/Vigilia.cpp
#include "Modules/ModuleManager.h"

#if WITH_GAMEPLAY_DEBUGGER
#include "Debug/VGGameplayDebuggerCategories.h"
#include "GameplayDebugger.h"
#endif

class FVigiliaModule : public FDefaultGameModuleImpl
{
public:
    virtual void StartupModule() override
    {
#if WITH_GAMEPLAY_DEBUGGER
        IGameplayDebugger& Debugger = IGameplayDebugger::Get();
        Debugger.RegisterCategory("VigiliaNarrative",
            IGameplayDebugger::FOnGetCategory::CreateStatic(&FVGGameplayDebuggerCategory_Narrative::MakeInstance),
            EGameplayDebuggerCategoryState::EnabledInGameAndSimulate, 6);
        Debugger.RegisterCategory("VigiliaAI",
            IGameplayDebugger::FOnGetCategory::CreateStatic(&FVGGameplayDebuggerCategory_AI::MakeInstance),
            EGameplayDebuggerCategoryState::EnabledInGameAndSimulate, 7);
        Debugger.NotifyCategoriesChanged();
#endif
    }

    virtual void ShutdownModule() override
    {
#if WITH_GAMEPLAY_DEBUGGER
        if (IGameplayDebugger::IsAvailable())
        {
            IGameplayDebugger& Debugger = IGameplayDebugger::Get();
            Debugger.UnregisterCategory("VigiliaNarrative");
            Debugger.UnregisterCategory("VigiliaAI");
            Debugger.NotifyCategoriesChanged();
        }
#endif
    }
};

IMPLEMENT_PRIMARY_GAME_MODULE(FVigiliaModule, Vigilia, "Vigilia");
```

```csharp
// Vigilia.Build.cs (adição)
// Só onde a engine compila o Gameplay Debugger (fora de Shipping, por padrão).
// ⚠️ Confira na sua versão se a macro WITH_GAMEPLAY_DEBUGGER vem das regras do target ou precisa ser definida aqui.
if (Target.bUseGameplayDebugger)
{
    PrivateDependencyModuleNames.Add("GameplayDebugger");
}
```

### 4. O Visual Logger com o estado da Vigília

🔁 `AVGAIController` acrescenta a consciência ao *snapshot* que o `AAIController` já grava:

```cpp
// AVGAIController.h (adição)
#if ENABLE_VISUAL_LOG
    virtual void GrabDebugSnapshot(FVisualLogEntry* Snapshot) const override;
#endif
```

```cpp
// AVGAIController.cpp (adição)
#if ENABLE_VISUAL_LOG
#include "VisualLogger/VisualLogger.h"

void AVGAIController::GrabDebugSnapshot(FVisualLogEntry* Snapshot) const
{
    Super::GrabDebugSnapshot(Snapshot); // BT e blackboard, da engine
    if (!Awareness)
    {
        return;
    }
    FVisualLogStatusCategory Category(TEXT("Vigilia: consciência"));
    Category.Add(TEXT("Valor"), FString::Printf(TEXT("%.2f"), Awareness->GetAwareness()));
    Category.Add(TEXT("Alvo visível"), Awareness->IsTargetVisible() ? TEXT("sim") : TEXT("não"));
    Category.Add(TEXT("Última posição"), Awareness->GetLastKnownLocation().ToCompactString());
    Snapshot->Status.Add(Category);
}
#endif
```

E duas linhas que tornam a linha do tempo legível:

```cpp
// UVGAwarenessComponent, ao mudar de estado (Cap. 36)
UE_VLOG_LOCATION(GetOwner(), LogVigilia, Log, LastKnownLocation, 30.0f, FColor::Orange,
                 TEXT("consciência → %d (%.2f)"), static_cast<int32>(State), Awareness);

// UVGDirectorSubsystem::EnterPhase (Cap. 42)
UE_VLOG(this, LogVigilia, Log, TEXT("Diretor → fase %d, tensão %.2f"), static_cast<int32>(NewPhase), Tension);
```

(Se a linha do Diretor não aparecer na janela do Visual Logger com o subsistema como dono, registre com o `AGameStateBase` do mundo como dono; ⚠️ o suporte a donos que não são atores varia.)

### 5. Os cheats prometidos

🔁 `UVGCheatManager` ganha os três atalhos que o Capítulo 16 anunciou:

```cpp
// UVGCheatManager (adições)
UFUNCTION(Exec) void VGGotoCheckpoint(FName CheckpointId); // teleporte para um AVGCheckpoint
UFUNCTION(Exec) void VGGod(bool bEnable);                  // invulnerabilidade pelo componente de vida da Vigília
UFUNCTION(Exec) void VGAIFreeze(bool bFreeze);             // pausa/retoma a lógica de toda a IA
```

```cpp
// UVGCheatManager.cpp (adições)
#include "AI/VGAIController.h"
#include "BrainComponent.h"
#include "Combat/VGHealthComponent.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerStart.h"

void UVGCheatManager::VGGotoCheckpoint(FName CheckpointId)
{
    APawn* Pawn = GetOuterAPlayerController()->GetPawn();
    for (TActorIterator<APlayerStart> It(GetWorld()); It && Pawn; ++It)
    {
        if (It->PlayerStartTag == CheckpointId)
        {
            Pawn->TeleportTo(It->GetActorLocation(), It->GetActorRotation());
            GetOuterAPlayerController()->SetControlRotation(It->GetActorRotation());
            UE_LOG(LogVigilia, Display, TEXT("Cheat: VGGotoCheckpoint %s"), *CheckpointId.ToString());
            return;
        }
    }
    UE_LOG(LogVigilia, Warning, TEXT("Cheat: checkpoint %s não existe neste nível."), *CheckpointId.ToString());
}

void UVGCheatManager::VGGod(bool bEnable)
{
    const APawn* Pawn = GetOuterAPlayerController()->GetPawn();
    if (UVGHealthComponent* Health = Pawn ? Pawn->FindComponentByClass<UVGHealthComponent>() : nullptr)
    {
        Health->SetInvulnerable(bEnable); // 🔁 setter novo em UVGHealthComponent (Cap. 22)
        UE_LOG(LogVigilia, Display, TEXT("Cheat: VGGod %d"), bEnable);
    }
}

void UVGCheatManager::VGAIFreeze(bool bFreeze)
{
    for (TActorIterator<AVGAIController> It(GetWorld()); It; ++It)
    {
        UBrainComponent* Brain = It->GetBrainComponent();
        if (bFreeze)
        {
            if (Brain) { Brain->PauseLogic(TEXT("VGAIFreeze")); }
            It->StopMovement();
        }
        else if (Brain)
        {
            Brain->ResumeLogic(TEXT("VGAIFreeze"));
        }
    }
    UE_LOG(LogVigilia, Display, TEXT("Cheat: VGAIFreeze %d"), bFreeze);
}
```

`UVGHealthComponent` ganha `void SetInvulnerable(bool bValue) { bInvulnerable = bValue; }`. Por que não o `God` da engine? Ele age sobre o sistema de dano da engine (`CanBeDamaged` do pawn); se todo dano da Vigília passa por `TakeDamage`, ele funciona, mas o `VGGod` mexe na regra do próprio componente, que é a que a Vigília controla, e é explícito (`1`/`0`) em vez de alternar.

### Explicação das decisões

- **Uma regra pura de agrupamento**, usada pela CVar e pela categoria. O painel e a CVar nunca discordam sobre como os fatos se organizam.
- **Duas categorias, uma global e uma por agente.** O estado narrativo não pertence a ator nenhum (`bShowOnlyWithDebugActor = false`); a consciência pertence a um agente.
- **Dados em linhas de texto replicadas.** É o mínimo que funciona em rede (Parte IX) sem um *struct* por campo. Se uma categoria precisar desenhar gráficos, o *struct* cresce.
- ***Snapshot* no controller, não no componente.** O `AAIController` já é o objeto que o Visual Logger acompanha; a consciência entra como mais uma categoria do mesmo *snapshot*.
- **Cheats explícitos e com rastro.** `VGGod 1`, `VGAIFreeze 0`: nenhum estado de cheat sobrevive a um load por acidente.
- **Tudo atrás das macros da engine** (`WITH_GAMEPLAY_DEBUGGER`, `ENABLE_VISUAL_LOG`, `ENABLE_DRAW_DEBUG`, `UE_WITH_CHEAT_MANAGER`). Nenhuma macro própria: as da engine já dizem exatamente o que existe em cada configuração.

### 6. Teste

```cpp
// Source/Vigilia/Tests/VGDebugRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Debug/VGDebugRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGDebugRulesTest, "Vigilia.Debug.Rules.GroupFactsByPrefix",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGDebugRulesTest::RunTest(const FString& Parameters)
{
    const TArray<FString> Names = {
        TEXT("Narrative.Fact.S1.ScareDone"),
        TEXT("Narrative.Fact.Document.Logbook.Read"),
        TEXT("Narrative.Fact.S1.BreakersRestored"),
        TEXT("Narrative.State.Sonia.Trust.High"),
        TEXT("Short.Tag"),
    };
    const TArray<TPair<FString, TArray<FString>>> Groups = VGDebugRules::GroupByPrefix(Names);

    TestEqual(TEXT("Quatro grupos"), Groups.Num(), 4);
    TestEqual(TEXT("Ordem: '-' primeiro"), Groups[0].Key, FString(TEXT("-")));
    TestEqual(TEXT("Document"), Groups[1].Key, FString(TEXT("Document")));
    TestEqual(TEXT("Item com pontos"), Groups[1].Value[0], FString(TEXT("Logbook.Read")));
    TestEqual(TEXT("S1"), Groups[2].Key, FString(TEXT("S1")));
    TestEqual(TEXT("S1 em ordem"), Groups[2].Value[0], FString(TEXT("BreakersRestored")));
    TestEqual(TEXT("Estado também agrupa"), Groups[3].Key, FString(TEXT("Sonia")));
    return true;
}

#endif
```

---

## Projeto Vigília — o painel de depuração

### O mapa de ferramentas

A lista que o Capítulo 11 começou no `DEVLOG.md` vira uma tabela em `docs/qa/ferramentas.md`:

| Pergunta | Ferramenta |
|---|---|
| Que fatos existem, em que etapa está cada quest, o que o save guardou? | Gameplay Debugger, **VigiliaNarrative** |
| O que a Presença acredita, e em que fase está o Diretor? | Gameplay Debugger, **VigiliaAI** (+ as categorias de BT e percepção da engine) |
| O que a Presença acreditou, segundo a segundo, na última caçada? | Visual Logger (*snapshot* "Vigilia: consciência", marcas do Diretor) |
| Onde estão o ruído, o foco da interação, o perfil de movimento? | `vg.Debug.Noise`, `vg.Debug.Interaction`, `vg.Debug.Movement` |
| Por que esta fala e não a outra? | `vg.Debug.Dialogue` + VigiliaNarrative |
| Quanto custa? | `stat Vigilia`, `VGPerfCapture`, Insights (Caps. 58–59) |
| Como chego rápido ao caso X? | Receitas em `docs/qa/receitas.md` (saves, JSON, cheats) |

### Uma investigação de ponta a ponta

**[HIPOTÉTICO]** Um relato de playtest: *"Depois de morrer no subsolo, a Presença ficou parada perto da escada e não reagiu mais."*

1. **Reproduzir pela receita.** `VGLoad` no `CP_S1_Subsolo`, morrer de propósito, recarregar. Acontece de novo.
2. **Painel ao vivo.** Apóstrofo na Presença: a categoria de BT da engine mostra a árvore **pausada**. A VigiliaAI mostra a consciência em `Unaware` e o Diretor em `Relax`, o que seria normal; a BT pausada, não.
3. **Gravado.** No Visual Logger, a linha da Presença tem uma entrada de pausa de lógica logo depois do load, com a razão `VGAIFreeze`.
4. **Causa.** A pessoa que testava tinha usado `VGAIFreeze` na sessão anterior, e uma versão antiga do cheat **alternava** a pausa com uma variável estática, que sobreviveu à troca de nível e inverteu o estado no load seguinte.
5. **Correção.** O cheat explícito (`VGAIFreeze 1`/`0`) desta seção. E uma linha nova em `docs/qa/receitas.md`: "antes de reportar um bug de IA, confira o log por `Cheat:`".

O exemplo é inventado, mas o padrão é real: metade dos bugs de playtest de um projeto com muitos cheats é **estado de ferramenta** vazando para o jogo. A regra 3 da seção 61.5 (deixar rastro) é o que torna esse tipo de bug achável em minutos.

### O inventário de dores

| # | Dor | Situação depois do Cap. 61 |
|---|---|---|
| 9 | Nada é testável | ✅ Resolvida: regras puras com testes em todas as partes, saves e JSON como pontos de partida, cheats explícitos, receitas de estado, painel ao vivo e gravação |

Com a dor 9, as doze dores do Interlúdio I estão resolvidas.

---

## Decisões arquiteturais

1. **Quatro camadas de depuração** (na tela, gravada, interativa, *post mortem*), cada uma com o seu conjunto de ferramentas.
2. **CVars `vg.Debug.*` desligadas, de custo zero e ausentes em Shipping**; CVars que mudam o jogo levam `ECVF_Cheat`; opções de acessibilidade não são CVars de *debug*.
3. **O painel da Vigília é o Gameplay Debugger**: VigiliaNarrative (global) e VigiliaAI (por agente), com dados replicados.
4. **O Visual Logger grava a crença dos agentes** (*snapshot* de consciência no controller) e as decisões do Diretor.
5. **Cheats pela API do jogo, explícitos, idempotentes, com rastro no log e fora do Shipping**; receitas de estado documentadas.
6. **Asserções pela configuração**: `check` para invariantes sem saída e sem efeito colateral; `verify` quando há efeito; `ensure` para o que não deveria acontecer mas tem saída; `IsValid` para o que pode legitimamente sumir.
7. **Símbolos de cada build arquivados** (Cap. 62): um *crash* só se lê com os `.pdb` daquele build.

---

## Armadilhas

- **Efeito colateral dentro de `check`.** O comportamento muda em Shipping.
- **`check` em algo que pode legitimamente sumir.** Um alvo destruído não é corrupção de memória.
- **Cheats que alternam.** O estado do cheat mente depois de um load.
- **Cheats que escrevem por fora da API.** Testam um caminho que o jogo nunca percorre.
- **Formatar texto de depuração com a CVar desligada.** O custo aparece no profiling e ninguém sabe de onde.
- ***Debug* fora das macros.** Um `DrawDebugSphere` sem `#if ENABLE_DRAW_DEBUG` não compila em algumas configurações, ou compila e custa.
- **`UE_LOG` por frame, por agente.** Ruído no log e milissegundos no game thread.
- **Perder os símbolos do build.** O *minidump* da máquina de alguém vira uma lista de endereços.
- **Esquecer `UE_DISABLE_OPTIMIZATION` num *commit*.** O código fica lento em todas as configurações, em silêncio.

---

## Exercício

**Parte 1 — o painel (2 h).** Implemente `VGDebugRules` e o teste, as duas categorias, a classe do módulo e a dependência no `Build.cs`. Em PIE, ative o Gameplay Debugger, ligue as duas categorias pelo teclado numérico e jogue o setor 1 até o susto, olhando os fatos chegarem.

**Parte 2 — Visual Logger (1 h).** Acrescente o *snapshot* e as duas marcas. Grave uma caçada completa da Presença e reconstrua, pela linha do tempo, quando ela desconfiou, quando teve certeza e por que desistiu.

**Parte 3 — cheats e receitas (1 h).** Implemente `VGGotoCheckpoint`, `VGGod` e `VGAIFreeze`. Escreva três receitas em `docs/qa/receitas.md`, uma delas para a fala final do caminho "leu o memorando". Cronometre: quanto tempo você leva do editor fechado até ouvir a fala?

**Parte 4 — um *crash* de propósito (45 min).** Num cheat temporário, acesse um ponteiro nulo. Rode em *Standalone* (Development), deixe cair, encontre o *minidump* em `Saved/Crashes`, abra no Visual Studio com os símbolos e ache a linha. Depois troque o acesso por um `check` e por um `ensure`, e registre no `DEVLOG.md` o que cada um mostrou. Apague o cheat.

---

## Desafio — a validação de nível

Muitos bugs da Vigília são **de conteúdo**, não de código: um checkpoint dentro de um gatilho (Capítulo 57), dois `PlayerStartTag` iguais, uma porta com `PowerSource` apontando para um disjuntor de outro nível, um ator persistente sem GUID, um documento sem `ReadFact`.

1. Escreva um cheat `VGValidateLevel` que percorre o nível aberto e escreve no log cada problema encontrado, com o nome do ator. Comece pelos cinco casos acima.
2. Transforme o mesmo código num **teste de automação** que abre `L_CasaDeForca` e falha se encontrar qualquer problema (⚠️ testes que abrem mapas usam a variante latente dos testes de automação; confira na sua versão).
3. Responda no `DEVLOG.md`: que parte desses problemas a validação de dados do editor (`IsDataValid`) já pegaria, e por que os outros só aparecem com o nível montado?

---

## Uso de IA

1. **Para desenhar uma categoria de depuração:**
   > "Tenho um subsistema de IA com estes dados por agente e globais: [lista]. Quero uma categoria do Gameplay Debugger da Unreal Engine 5 que caiba numa tela sem poluir. Proponha o que mostrar em texto, o que desenhar no mundo, e o que deixar para o Visual Logger por ser histórico e não instantâneo."

2. **Para ler um *crash*:**
   > "Esta é a pilha de chamadas de um *crash* num jogo em Unreal Engine 5, com os símbolos carregados, e as últimas 40 linhas do log: [pilha + log]. Qual é a hipótese mais provável, o que confirmaria cada hipótese, e que asserção eu deveria ter tido para pegar isso mais cedo?"

3. **Para revisar asserções:**
   > "Revise o uso de check, verify e ensure neste arquivo C++ da Unreal. Aponte: efeitos colaterais dentro de check, check em ponteiros que podem legitimamente ser nulos, ensure que deveria ser check (o estado depois é irrecuperável), e lugares sem nenhuma asserção onde uma suposição importante está implícita. [código]"

**Cuidado específico:** com uma pilha de chamadas na mão, a IA produz uma explicação plausível em segundos, e ela pode estar errada de um jeito convincente, sobretudo se os símbolos forem de outro build ou se o *crash* for consequência de uma corrupção que aconteceu muito antes. Trate a resposta como hipótese e confirme com o *debugger*, o Visual Logger ou uma receita que reproduza o bug.

---

## Checklist

- [ ] Sei em qual das quatro camadas procurar cada tipo de bug.
- [ ] Minhas CVars de *debug* custam zero quando desligadas e não existem em Shipping.
- [ ] Tenho as categorias VigiliaNarrative e VigiliaAI no Gameplay Debugger.
- [ ] Gravei uma caçada no Visual Logger e expliquei uma decisão da Presença pela linha do tempo.
- [ ] Meus cheats passam pela API, são explícitos, deixam rastro e somem em Shipping.
- [ ] Tenho receitas de estado para os casos que mais testo.
- [ ] Sei escolher entre `check`, `verify`, `ensure` e `IsValid`, e já li um *minidump* com os símbolos certos.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Visual Logger**, **Gameplay Debugger** (e as configurações do *Gameplay Debugger* em *Project Settings*), a referência da API de `UCheatManager`, **Logging**, **Asserts** e **Crash Reporting**.
- **Epic Developer Community** (dev.epicgames.com/community): há tutoriais sobre depuração avançada na Unreal, inclusive sobre o cheat manager em diferentes configurações de build; confira a versão de cada um.
- ***Game Engine Architecture***, de Jason Gregory: o capítulo sobre ferramentas de depuração e desenvolvimento cobre consoles, desenho de depuração, cheats e captura de estado dentro de engines.
- **GDC Vault** (gdcvault.com): palestras sobre ferramentas internas de depuração e de QA em estúdios (procure por "debug tools" e "QA"; confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 62 — Packaging](cap-62-packaging.md)

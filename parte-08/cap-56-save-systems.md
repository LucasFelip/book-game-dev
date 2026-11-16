# PARTE VIII — Engenharia

*Projeto: a Vigília ganha save, persistência de mundo, orçamento de frame, ferramentas de depuração e um build que outra pessoa consegue rodar.*

---

# Capítulo 56 — Save Systems

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que um save **é** (uma descrição suficiente para reconstruir a experiência) e o que ele **não é** (uma cópia da memória);
- escolher entre save livre, *save points* e checkpoints, e defender a escolha pelo **design** e pela **engenharia**;
- separar o que se salva (narrativa, jogadora, mundo), o que se deriva e o que se descarta;
- usar `USaveGame` com `UGameplayStatics::SaveGameToSlot`, `AsyncSaveGameToSlot`, `LoadGameFromSlot` e `AsyncLoadGameFromSlot`;
- tratar o save como um **contrato com o passado**: versionar o formato, migrar arquivos antigos e proteger os nomes que o arquivo guarda;
- montar um `UVGSaveSubsystem` que grava checkpoints em momentos seguros e recarrega o último checkpoint na morte;
- fazer o teste que importa: **salvar no meio do setor 1 e carregar**.

---

## Contexto

O Interlúdio I terminou com doze dores. A segunda delas era a mais seca: **impossível salvar**. Salvar o *Turno da Noite* exigiria serializar um Level Blueprint com booleanos espalhados, o que ninguém faz.

A Parte VI desmontou essa dor por dentro. O Capítulo 46 deu ao estado narrativo um dono único, `UVGNarrativeSubsystem`, e fez do estado um `USTRUCT` versionado, `FVGNarrativeState`, que **já é a snapshot**: fatos, contadores, falas ditas, conversas tocadas e registros de quest com `TSoftObjectPtr`. O Capítulo 45 garantiu que as quests retomam a partir dos registros, e a regra de idempotência do `OnEnter` tornou a retomada segura. Faltou o que o Capítulo 46 prometeu: pôr isso **no disco**.

Outras promessas se acumularam pelo caminho e vencem agora:

- **Capítulo 10:** sobrescrever `ChoosePlayerStart` "para nascer no último checkpoint".
- **Capítulo 22:** o `RequestRespawn` pede ao GameMode para reiniciar, com o comentário *"a REGRA de onde renascer é do GameMode (Cap. 56: checkpoint)"*.
- **Capítulo 15:** o `AVGEventTrigger` tem `ResetTrigger` e `HasTriggered` porque "precisa poder ser rearmado ao recarregar um checkpoint".
- **Capítulo 23:** a tabela "onde o estado mora" foi chamada de "a primeira versão da especificação de save".
- **Capítulo 76:** o Milestone 8 exige "checkpoints que nunca perdem progresso" e um teste automatizado.

Este capítulo resolve o save da **narrativa** e da **jogadora**. O estado do **mundo** (portas, disjuntores, pickups, gatilhos, documentos levados) é o Capítulo 57, e o fim do capítulo vai mostrar por que ele não cabe aqui.

---

## 56.1 O que um save é

A tentação de quem chega de sistemas é pensar em save como *dump*: pegar o estado da memória e escrever no disco. Não funciona, e não só por tamanho. Um jogo em execução tem milhões de bytes que não significam nada fora daquele processo: ponteiros, *handles* de áudio, estado de física em voo, buffers de GPU, timers agendados. Nenhum deles sobrevive a fechar o jogo, e quase nenhum deveria.

Um save é uma **descrição**. Ele guarda o mínimo necessário para que o jogo **reconstrua** uma experiência equivalente a partir do conteúdo, que já está no disco:

```text
  conteúdo do jogo (níveis, assets)      +      save (o que a jogadora mudou)
  ─────────────────────────────────             ─────────────────────────────
  L_CasaDeForca: portas fechadas,               fatos: leu o livro, religou...
  pickups no lugar, Presença no subsolo         quest: etapa "Disjuntores"
                                                jogadora: 61% de bateria, 0+2 sinalizadores
                    \                           checkpoint: CP_S1_Corredor
                     \                         /
                      ▼                       ▼
                 o jogo reconstrói: abre o nível, aplica a diferença, põe a jogadora no lugar
```

O save é a **diferença** entre o mundo que o conteúdo descreve e o mundo que a jogadora deixou. Três consequências guiam o resto do capítulo:

1. **Salve fontes, derive o resto.** Se a luz do setor acende porque o disjuntor está ligado, salve o disjuntor, não a luz.
2. **Salve identificadores, não ponteiros.** Uma quest é salva pelo caminho do asset (`TSoftObjectPtr`), e um checkpoint pelo nome.
3. **O que não se salva precisa ter um jeito honesto de recomeçar.** A Presença no meio de uma caçada não é salva; ela recomeça do jeito que o nível a define. Isso só é aceitável se o momento do save for escolhido para que ninguém perceba, e é o assunto da próxima seção.

### As quatro categorias, de novo

O Capítulo 46 separou o estado narrativo do resto. O save usa a mesma separação:

| Categoria | Exemplo | Dono | Salva? |
|---|---|---|---|
| **Narrativa** | Leu o memorando; quest na etapa `Disjuntores` | `UVGNarrativeSubsystem` | Sim: a snapshot inteira |
| **Jogadora** | Bateria, sinalizadores, chave da sala do engenheiro | Componentes do pawn | Sim: um registro pequeno |
| **Mundo** | Porta aberta, pickup pego, gatilho disparado | Os próprios atores | Sim, no Capítulo 57 |
| **Simulação** | Onde a Presença está, a fase do Diretor, um sinalizador em voo | IA, física, Diretor | **Não**: recomeça |

> 🌉 **Ponte:** é a diferença entre um *backup* físico de banco (as páginas do disco, como estão) e um *dump* lógico (os comandos que recriam os dados). O save de jogo é sempre lógico: ele descreve o que existe e deixa o motor recriar.
>
> 🧱 **Onde a ponte cai:** num banco, o *schema* é seu e muda por migração controlada. Num jogo, metade do "banco" é o **conteúdo**, e ele muda a cada patch: alguém move uma porta, apaga um pickup, renomeia uma quest. O save precisa sobreviver a mudanças num lado do sistema que ele não controla. É por isso que a seção 56.4 trata nomes como contrato.

---

## 56.2 Quando salvar: livre, *save points* ou checkpoints

Antes de qualquer código, há uma decisão de **design**. Os modelos clássicos:

- **Save livre:** a jogadora salva quando quiser, inclusive com *quicksave* (uma tecla). Dá controle e respeita o tempo dela.
- ***Save points*:** salvar só em lugares do mundo (uma cama, um escritório, uma máquina de escrever). O save vira um objeto diegético e um ritmo: a próxima sala segura é uma meta.
- **Checkpoints:** o jogo salva sozinho em pontos escolhidos pelo design. A jogadora não decide; ela confia.
- ***Save* ao sair (suspensão):** grava ao fechar e apaga ao carregar, só para interromper a sessão. Costuma acompanhar um dos outros.

Cada modelo muda a **experiência**. Com *quicksave*, a morte custa segundos, e o medo se dissolve em tentativa e erro (o famoso *save scumming*: salvar antes de cada risco). Com checkpoints, a morte custa o trecho desde o último ponto, e esse custo é o que sustenta a tensão. Jogos de terror quase sempre controlam esse custo.

### O que o modelo custa para a engenharia

O save livre tem um custo que o design não vê: **qualquer momento pode ser salvo**, e portanto o save precisa capturar qualquer momento. A Presença no meio de uma caçada (posição, consciência, alvo, nó da Behavior Tree, ponto de busca do EQS), um sinalizador em voo, uma cinemática pela metade, uma fala de Sônia no segundo 3 de 7, a música no clímax. Cada sistema precisaria saber se serializar e se restaurar **no meio do que estava fazendo**. É uma superfície enorme, e cada sistema novo a aumenta.

O checkpoint inverte o problema: **o jogo escolhe o momento**, e escolhe um momento em que quase nada está em movimento. Se a Presença não está caçando, ela pode recomeçar do ponto de patrulha do nível sem que a jogadora perceba. Se nenhuma cinemática está tocando, não há cena a retomar. O save fica pequeno porque o momento é calmo.

> 🌉 **Ponte:** em sistemas distribuídos, uma *snapshot* consistente (o algoritmo de Chandy-Lamport, por exemplo) precisa lidar com mensagens em trânsito entre processos. O checkpoint de jogo é uma snapshot consistente em que você **escolhe** o instante para que não haja nada em trânsito.
>
> 🧱 **Onde a ponte cai:** num sistema distribuído você não pode adiar a snapshot para quando a rede estiver quieta, nem fingir que uma mensagem não existiu. No jogo, pode as duas coisas. O Diretor sabe quando é calmo, e o que estava "em trânsito" (a caçada) pode simplesmente **recomeçar**, porque a jogadora não tem como distinguir uma Presença restaurada de uma Presença que voltou a patrulhar.

### A decisão para a Vigília

A Vigília é um jogo de terror de 10 a 20 minutos, jogado em uma ou duas sessões. As forças são claras:

- **Tensão:** a morte precisa custar alguma coisa. Um *quicksave* antes de cada corredor desmonta a Presença (Capítulo 42).
- **Sessão curta:** um jogo de 15 minutos não precisa de vários slots, nem de gerenciar "qual save eu carrego".
- **Escopo:** o Milestone 8 (Capítulo 76) pede "checkpoints que nunca perdem progresso", não um sistema de arquivos.

**Decisão:**

1. **Checkpoints automáticos, um slot.** Cada setor tem de três a quatro checkpoints em batidas da história, separados por dois a quatro minutos de jogo.
2. **A morte recarrega o último checkpoint.** O respawn do Capítulo 22 vira "carregar".
3. **Sem save manual e sem save ao sair.** Fechar o jogo perde, no máximo, o trecho desde o último checkpoint. Num jogo deste tamanho, é um preço aceitável, e evita capturar a simulação.
4. **O checkpoint registra o lugar; o momento espera a calma.** Se a jogadora atravessa um checkpoint durante uma caçada, o save fica **pendente** e é escrito assim que o momento for seguro. A regra é pura e testável:

| Condição | Por quê |
|---|---|
| A jogadora está viva | Salvar a morte é o pior bug possível de um sistema de checkpoint |
| Ameaça diferente de `Hunting` (`UVGThreatSubsystem`, Cap. 36) | A caçada é simulação que não salvamos |
| Diretor fora de `Peak` (`UVGDirectorSubsystem`, Cap. 42) | O pico é o momento de maior risco; o save vem na recuperação |
| Nenhuma cinemática tocando (`UVGCinematicSubsystem`, Cap. 49) | Uma cena não se retoma pela metade |

Uma consequência do item 2: **se a morte é um load, o caminho de load roda dezenas de vezes em cada playtest**, e um bug de save aparece na terceira morte da tarde, não "quando alguém carregar amanhã".

---

## 56.3 O que salvar: o inventário

O Capítulo 23 montou uma tabela de estado e chamou-a de primeira especificação de save. Ela evoluiu. A versão da Vigília depois da Parte VI fica assim, e mora em `docs/design/save.md` ao lado do catálogo de fatos:

| Estado | Dono | Salva? | Como volta | Capítulo |
|---|---|:-:|---|---|
| Fatos, contadores, falas ditas, conversas tocadas, quests | `UVGNarrativeSubsystem` | ✓ | `RestoreSnapshot` antes de qualquer ator | 46, 56 |
| Carga da bateria | `UVGBatteryComponent` | ✓ | `Recharge`/`Drain` na personagem nova | 56 |
| Arma e munição (pente + reserva) | `AVGWeapon` | ✓ | `GiveWeapon` + `RestoreAmmo` | 56 |
| Chaves e itens de progresso (`Item.*`) | `UVGStatusTagsComponent` | ✓ | `GrantStatus` | 56 |
| Onde a jogadora está | — | ✓ (o **nome** do checkpoint) | `ChoosePlayerStart` | 56 |
| 🔁 Vida | `UVGHealthComponent` | ✗ | Volta cheia | 56 |
| Porta, disjuntor, pickup, gatilho | Os atores | ✓ | Persistência de mundo | 57 |
| Presença, vigias, Diretor, ameaça | IA | ✗ | Recomeçam como o nível define | — |
| Modo de input, dilatação do tempo, alarme | Sistemas transitórios | ✗ | Valores iniciais | — |

Duas linhas pedem explicação.

**A posição é um nome, não um transform.** Salvar a posição exata da jogadora é tentador e frágil: ela pode estar no meio de um pulo, encostada numa porta que, no load, estará em outro estado, ou dentro do volume de um gatilho que vai disparar de novo. O checkpoint é um `APlayerStart` colocado pelo level design num lugar seguro, e o save guarda o `PlayerStartTag` dele. Se um patch mover o checkpoint meio metro, o save continua válido.

**🔁 A vida saiu da tabela.** O Capítulo 23 marcou a vida como salvável. Com as decisões firmadas desde então, ela não precisa ser: a regeneração (8 s de espera, 15 por segundo) leva a vida de volta a 100 em segundos, e o checkpoint só grava fora de caçada. A diferença entre "salvar a vida" e "carregar com a vida cheia" é, na prática, menos de dez segundos de regeneração. Tirar um campo do save é tirar um caso de borda: não existe "carreguei com 5 de vida ao lado da Presença".

> ⚠️ A decisão da vida **depende** da trava de momento: se o checkpoint um dia gravar durante uma caçada, a vida volta para a tabela. Por isso o `docs/design/save.md` registra o motivo de cada linha, não só o "sim/não".

---

## 56.4 Versionamento: o save é um contrato com o passado

Um save vive mais que o build que o escreveu. A jogadora salva na versão 1.0, a versão 1.1 sai com uma correção, e o save precisa abrir. Na produção é pior: o save de ontem precisa abrir no build de hoje, ou cada playtest recomeça do zero e ninguém testa o setor 3.

Pense no formato do save em cinco camadas, da mais automática para a mais manual.

### Camada 1: as versões da engine

`UGameplayStatics::SaveGameToSlot` escreve um **cabeçalho** antes dos dados (`FSaveGameHeader`, em `GameplayStatics.cpp`), com as versões da engine e dos formatos de pacote. Ao carregar, o loader aplica essas versões ao arquivo de leitura, e os tipos da engine que mudaram de formato entre versões sabem se ler. Você não faz nada aqui, mas precisa saber que existe: é por isso que um save de uma versão anterior da engine costuma abrir.

### Camada 2: propriedades com etiqueta

O `USaveGame` é serializado com o sistema de reflexão, por **serialização com etiquetas** (*tagged properties*): cada `UPROPERTY` é escrita com o nome e o tipo. Isso dá tolerância de graça:

- **Campo novo no código:** ausente no arquivo antigo, fica com o valor padrão.
- **Campo removido do código:** presente no arquivo, é ignorado.
- **Campo renomeado:** é lido como "removido" mais "novo", e o valor se perde, a não ser que você declare um redirecionamento de propriedade (*Core Redirects*, `PropertyRedirects` no `DefaultEngine.ini`, ⚠️ confira a sintaxe na sua versão). A convenção da engine para propriedades aposentadas é o sufixo `_DEPRECATED`.
- **Tipo alterado:** algumas conversões numéricas são feitas, outras não. ⚠️ Não conte com isso; trate como migração.

Há uma sutileza que causa bugs difíceis. A serialização de `UObject` grava, por padrão, só as propriedades **diferentes do padrão da classe** (serialização delta). Um campo cujo valor é igual ao padrão não vai para o arquivo; ao carregar, ele assume o padrão **do código atual**. Se você mudar o valor padrão de um campo, todo save antigo em que o campo tinha o padrão antigo carrega com o novo. A regra prática: **campos de save têm padrões neutros (zero, vazio, "não gravado") e nunca mudam de padrão.** É por isso que `SaveVersion` começa em `0` na classe e só ganha valor quando o save é escrito.

### Camada 3: nomes são contrato

O arquivo guarda **nomes**: de tags de fato, de assets de quest, de checkpoints, de classes de arma. Cada um é um contrato:

| Nome guardado | Se mudar | Proteção |
|---|---|---|
| Tag de fato (`Narrative.Fact.Document.Memo.Read`) | O fato some do save | **Nunca renomeie um fato publicado; redirecione** (*Gameplay Tag Redirects*, Cap. 46). ⚠️ Teste um save antigo depois de cada redirecionamento |
| Asset de quest (`TSoftObjectPtr`) | O registro aponta para nada | Mover assets no editor deixa *redirectors*; não os apague sem antes "consertá-los" (*Fix Up Redirectors*) e testar saves |
| Checkpoint (`PlayerStartTag`) | A jogadora nasce no `PlayerStart` padrão | Não renomeie checkpoints publicados; o loader avisa no log |
| Classe da arma (`TSoftClassPtr`) | A jogadora carrega sem a arma | Como os assets |

### Camada 4: a versão semântica e as migrações

Algumas mudanças não são tolerâncias de formato: são mudanças de **significado**. Para elas, o save tem um número de versão próprio, `SaveVersion`, e uma cadeia de migrações:

```text
  arquivo v1 ──► Migrar 1→2 ──► Migrar 2→3 ──► ... ──► versão atual ──► restaurar
                 (passo puro)    (passo puro)

  - um passo por versão, em ordem; nunca se pula um passo
  - um passo publicado nunca é editado; corrige-se com o passo seguinte
  - versão maior que a atual (save de um build mais novo): recusar, nunca adivinhar
  - qualquer falha: recusar o save inteiro, nunca restaurar pela metade
```

Este capítulo produz exatamente uma migração, e ela nasce de um bug real do teste da seção Projeto. A primeira versão do registro da jogadora guardava os sinalizadores como um **total** (`Flares`). Ao carregar, `GiveWeapon` cria a arma com o pente cheio, e o código acrescentava o total na reserva. Uma jogadora que salvou com o pente vazio e dois na reserva carregava com um no pente e dois na reserva: **cada morte dava um sinalizador grátis**, num jogo em que a decisão firmada é "máximo 4 cartuchos". A versão 2 grava pente e reserva separados, e a migração 1→2 converte o total de forma conservadora (o total se preserva; nada é criado).

### Camada 5: a versão da snapshot narrativa

`FVGNarrativeState` tem um `Version` próprio desde o Capítulo 46, porque a snapshot também viaja sozinha (o JSON do desafio daquele capítulo). Ela é migrada pelo mesmo `VGSaveRules::Migrate`, antes do `RestoreSnapshot`, que continua recusando com `ensure` qualquer versão diferente da atual. O dono do formato narrativo é o Capítulo 46; o dono do envelope é este.

> 🌉 **Ponte:** são as migrações de *schema* que você conhece (Flyway, Liquibase): sequenciais, numeradas, imutáveis depois de publicadas.
>
> 🧱 **Onde a ponte cai:** a migração de banco roda **uma vez**, num servidor seu, sobre todos os dados, e você confere o resultado. A migração de save roda **no computador da jogadora, a cada load, para sempre**, sobre um arquivo que você nunca vai ver. Não há como consultar "quantos saves ainda estão na v1". Por isso os passos precisam ser puros, testados com **arquivos reais guardados** de cada versão (`Tests/SaveFixtures/v1_s1_corredor.sav`), e conservadores: na dúvida, prefira dar menos à jogadora a corromper o arquivo.

---

## 56.5 Síncrono, assíncrono e o custo de um save

Salvar tem duas etapas com custos diferentes:

1. **Serializar** o objeto para bytes: CPU, no game thread, porque lê objetos do jogo.
2. **Escrever** os bytes no disco: E/S, de duração imprevisível (disco lento, antivírus, armazenamento em nuvem sincronizando a pasta).

`SaveGameToSlot` faz as duas no game thread e **bloqueia o frame** até o disco responder. `AsyncSaveGameToSlot` serializa no game thread e escreve numa thread de fundo, chamando o *delegate* de volta no game thread ao terminar (o comentário da declaração, em `GameplayStatics.h`, descreve essa divisão; ⚠️ confira na sua versão). O mesmo vale para `LoadGameFromSlot` e `AsyncLoadGameFromSlot`.

O save da Vigília tem poucos kilobytes, e a serialização cabe com folga em uma fração de milissegundo. A escrita, não se sabe. Um checkpoint que trava o frame por 40 ms ao atravessar um corredor é um *hitch* que a jogadora sente (Capítulo 58). **Decisão: gravação assíncrona sempre, um save por vez, e o pedido mais recente vence.**

Onde os arquivos moram:

- No editor e em builds de desenvolvimento, em `Saved/SaveGames/<Slot>.sav`, na pasta do projeto.
- Num build empacotado para Windows, numa pasta do usuário (tipicamente sob `%LOCALAPPDATA%\<Projeto>\Saved\SaveGames`; ⚠️ confira no seu build, o Capítulo 62 volta a isso).
- Em consoles, o sistema de save da plataforma (`ISaveGameSystem`), e o `UserIndex` passa a significar algo. No PC, use `0`.

E o arquivo é **entrada não confiável**. Jogadoras editam saves, discos corrompem, um build quebra no meio da escrita. O loader nunca deve travar o jogo por causa de um arquivo: ele valida, migra, recusa com uma mensagem clara e oferece "novo jogo". Valores numéricos lidos do save passam pelos mesmos limites que o jogo aplica (munição até o tamanho do pente, por exemplo).

---

## Estudos de caso

### Max Payne: do *quicksave* ao checkpoint

**[FATO PÚBLICO — observável jogando]** *Max Payne* (Remedy, 2001) e *Max Payne 2* permitiam salvar a qualquer momento no PC, com *quicksave*. *Max Payne 3* (Rockstar, 2012) trocou o modelo por checkpoints automáticos.

**[INFERÊNCIA]** Os primeiros jogos são uma sequência de tiroteios curtos e coreografados, em que o *quicksave* vira parte do ritmo: salvar antes da sala, tentar o *bullet time* perfeito, recarregar. O terceiro é construído em torno de cenas e transições cinematográficas longas; checkpoints dão ao estúdio controle sobre de onde a jogadora recomeça, o que combina com uma narrativa conduzida. Não sabemos quais razões internas pesaram.

**Lição para a Vigília:** o modelo de save acompanha a forma da narrativa. Um jogo de cenas conduzidas quer controlar o ponto de retorno.

### Outlast e Amnesia: a morte como custo

**[FATO PÚBLICO — observável jogando]** *Outlast* (Red Barrels, 2013) salva automaticamente em checkpoints e, na morte, devolve o jogador ao último deles. *Amnesia: The Dark Descent* (Frictional Games, 2010) não tem save manual: salva sozinho e oferece "salvar e sair" no menu.

**[INFERÊNCIA]** Nos dois, o custo da morte é calibrado pelo estúdio e não pelo jogador. O medo depende de a perseguição ter consequência; se o jogador pudesse salvar a cada esquina, a criatura viraria um obstáculo de tentativa e erro. O "salvar e sair" de Amnesia resolve o problema da sessão interrompida sem abrir a porta para o *save scumming*.

**Lição para a Vigília:** é a mesma decisão: checkpoints e morte como load. A Vigília não tem "salvar e sair" porque a sessão inteira dura menos que um episódio de série; se o escopo crescer, um save de suspensão (grava ao sair, apaga ao carregar) é o próximo passo, e ele herda a trava de momento seguro.

### GTA: casas, depois o telefone

**[FATO PÚBLICO — observável jogando]** Em *GTA: San Andreas*, o jogo só é salvo nas casas da personagem (*safehouses*), indo até um ponto específico. Em *GTA V*, há save automático depois das missões, save manual nas casas e um *quick save* pelo celular da personagem.

**[INFERÊNCIA]** Num mundo aberto sem um "trecho" claro para recomeçar, salvar em lugares cria rotina e geografia (voltar para casa), e o save depois de missões protege o progresso que mais custa.

**Lição para a Vigília:** o save é uma ferramenta de ritmo tanto quanto de engenharia. O Interlúdio II volta a GTA pelo outro lado: o que o mundo **não** precisa lembrar.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Save como descrição | *Dump* lógico de banco | Metade do "banco" é conteúdo que muda a cada patch |
| Checkpoint em momento calmo | Snapshot consistente | Aqui você escolhe o instante e pode reiniciar o que estava em trânsito |
| `SaveVersion` + migrações | Migrações de *schema* | Rodam no cliente, a cada load, sobre arquivos que você nunca vê |
| Nomes como contrato | Contrato de API pública | Quem "consome" o contrato é um arquivo de anos atrás |
| Gravação assíncrona | Escrita em *background*, *write-behind* | O que importa é o frame não travar, não a vazão |
| Arquivo de save | Entrada de usuário | Ela vem da própria jogadora, que às vezes edita de propósito |

---

## Unreal Engine: o que existe e o que não existe

**Existe:**

- **`USaveGame`** (`GameFramework/SaveGame.h`): uma classe vazia feita para ser herdada. As `UPROPERTY` dela são o conteúdo do arquivo.
- **`UGameplayStatics`** (`Kismet/GameplayStatics.h`): `CreateSaveGameObject`, `SaveGameToSlot`, `AsyncSaveGameToSlot`, `LoadGameFromSlot`, `AsyncLoadGameFromSlot`, `DoesSaveGameExist`, `DeleteGameInSlot`, e as versões em memória `SaveGameToMemory`/`LoadGameFromMemory`, ótimas para teste.
- **`ISaveGameSystem`**: a camada de plataforma por baixo dos slots.
- **O especificador `SaveGame`** em `UPROPERTY`. Ele marca a propriedade para arquivos de save que **filtram** por ele (`ArIsSaveGame`). O caminho de `SaveGameToSlot`, até onde o código da engine mostra, serializa o `USaveGame` sem esse filtro, e portanto grava todas as `UPROPERTY` (⚠️ confira `UGameplayStatics::SaveGameToMemory` na sua versão). Usamos `SaveGame` nos campos mesmo assim: documenta a intenção e mantém o formato correto se um dia o arquivo passar por um filtro. O especificador é essencial no Capítulo 57, onde atores são serializados com o filtro ligado.
- **Redirecionamentos**: de tags (*Gameplay Tag Redirects*), de propriedades e classes (*Core Redirects*) e de assets (*redirectors*).
- **`UGameUserSettings`**: as **opções** (resolução, qualidade, volume) moram aqui, num `.ini`, e não no save de progresso. O Milestone 8 cita "opções"; o lugar delas é este, e a UI é o Capítulo 55.

**Não existe:**

- um sistema de checkpoints, de slots ou de "continuar";
- uma política de versionamento e migração;
- o save do **mundo**: nenhuma função grava "o estado deste nível" (Capítulo 57);
- um identificador estável de ator pronto para save (Capítulo 57).

---

## Abordagens

| Critério | **A. `USaveGame` com registros explícitos** | B. Serializar tudo (todos os atores, filtro `SaveGame`) | C. Formato próprio (JSON) |
|---|---|---|---|
| **Complexidade** | Baixa: um envelope e alguns *structs* | Média; parece baixa até o primeiro bug de ordem de restauração | Média: conversão, tipos, versões à mão |
| **Performance** | Ótima: só o necessário | Pior: cada ator do nível é visitado | Boa, com arquivos maiores |
| **Extensibilidade** | Um campo por necessidade nova | Automática, inclusive para o que não deveria ser salvo | Manual |
| **Manutenção** | O arquivo diz o que o jogo considera progresso | O formato é um efeito colateral de quais `UPROPERTY` alguém marcou | Legível por humanos, fácil de corromper à mão |
| **Prototipação** | Rápida | Rapidíssima no começo | Lenta |
| **Adequação à Vigília** | **Sim**, para narrativa e jogadora | Só para atores do mundo, com escopo controlado (Cap. 57) | Como **ferramenta** de depuração (desafio do Cap. 46) |

**Decisão: A**, com a snapshot do Capítulo 46 dentro do envelope. O Capítulo 57 acrescenta uma forma restrita de B para atores que pedem persistência explicitamente.

---

## Implementação

### 1. O envelope

```cpp
// Source/Vigilia/Save/VGSaveGame.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGNarrativeTypes.h"
#include "VGSaveGame.generated.h"

class AVGWeapon;

/** O que a jogadora carrega. Estado de gameplay, não de história (Cap. 46, seção 46.1). */
USTRUCT(BlueprintType)
struct FVGPlayerRecord
{
    GENERATED_BODY()

    /** Negativo = nada gravado: a personagem fica com a carga com que nasce. */
    UPROPERTY(SaveGame)
    float BatteryCharge = -1.0f;

    /** Simplificação: uma arma (o sinalizador). Um inventário com slots gravaria um registro por slot. */
    UPROPERTY(SaveGame)
    TSoftClassPtr<AVGWeapon> Weapon;

    UPROPERTY(SaveGame)
    int32 AmmoInMagazine = 0;

    UPROPERTY(SaveGame)
    int32 ReserveAmmo = 0;

    /** Chaves e itens de progresso (Item.*), que a personagem guarda como status (Cap. 23). */
    UPROPERTY(SaveGame)
    FGameplayTagContainer Items;

    /** v1: total de sinalizadores. Lido só pela migração 1→2. Não use em código novo. */
    UPROPERTY(SaveGame)
    int32 Flares = 0;
};

/** O arquivo de checkpoint da Vigília. Padrões neutros: um campo ausente no arquivo assume o padrão. */
UCLASS()
class VIGILIA_API UVGSaveGame : public USaveGame
{
    GENERATED_BODY()

public:
    /** Versão do FORMATO (VGSaveRules::Migrate). 0 = arquivo sem versão. Nunca mude este padrão. */
    UPROPERTY(SaveGame)
    int32 SaveVersion = 0;

    UPROPERTY(SaveGame)
    FDateTime SavedAtUtc;

    /** ProjectVersion de quem gravou: diagnóstico de bugs reportados (Cap. 62). */
    UPROPERTY(SaveGame)
    FString BuildVersion;

    /** Nome curto do nível, sem o prefixo de PIE. */
    UPROPERTY(SaveGame)
    FName MapName;

    /** PlayerStartTag do AVGCheckpoint onde a jogadora renasce. */
    UPROPERTY(SaveGame)
    FName CheckpointId;

    UPROPERTY(SaveGame)
    FVGNarrativeState Narrative;

    UPROPERTY(SaveGame)
    FVGPlayerRecord Player;
};
```

🔁 Os campos de `FVGNarrativeState` (Capítulo 46) eram `UPROPERTY()` simples. Marque-os também com `SaveGame`:

```cpp
// FVGNarrativeState (Cap. 46): só o especificador muda
UPROPERTY(SaveGame) int32 Version = 1;
UPROPERTY(SaveGame) FGameplayTagContainer Facts;
UPROPERTY(SaveGame) TMap<FGameplayTag, int32> Counters;
UPROPERTY(SaveGame) TSet<FName> SaidLines;
UPROPERTY(SaveGame) TSet<FName> PlayedConversations;
UPROPERTY(SaveGame) TArray<FVGQuestRecord> Quests;   // e os quatro campos de FVGQuestRecord
```

Hoje não faz diferença, pelo motivo visto na seção "Unreal Engine". Mas o filtro, quando ligado, vale para **cada nível** da estrutura: um *struct* marcado `SaveGame` cujos campos não estão marcados é gravado **vazio**. Melhor não deixar essa armadilha armada.

### 2. As regras puras

```cpp
// Source/Vigilia/Save/VGSaveRules.h
#pragma once

#include "CoreMinimal.h"
#include "AI/VGDirectorSubsystem.h"
#include "AI/VGThreatSubsystem.h"

class UVGSaveGame;

namespace VGSaveRules
{
    /** Versão atual do formato. Suba a cada mudança que exija migração (seção 56.4). */
    constexpr int32 CurrentVersion = 2;

    inline constexpr const TCHAR* SlotName = TEXT("Vigilia_Checkpoint");
    constexpr int32 UserIndex = 0;

    /** Leva o save à versão atual, passo a passo. false = recusar o arquivo inteiro. */
    bool Migrate(UVGSaveGame& Save, FString& OutError);

    struct FCheckpointContext
    {
        EVGThreatLevel Threat = EVGThreatLevel::Calm;
        EVGDirectorPhase Phase = EVGDirectorPhase::Relax;
        bool bCinematicPlaying = false;
        bool bPlayerAlive = true;
    };

    /** O momento é seguro para gravar? (seção 56.2) */
    bool CanCheckpoint(const FCheckpointContext& Context);
}
```

```cpp
// Source/Vigilia/Save/VGSaveRules.cpp
#include "Save/VGSaveRules.h"

#include "Save/VGSaveGame.h"

bool VGSaveRules::Migrate(UVGSaveGame& Save, FString& OutError)
{
    if (Save.SaveVersion < 1 || Save.SaveVersion > CurrentVersion)
    {
        OutError = FString::Printf(TEXT("Versão de save %d não suportada (atual: %d)."),
                                   Save.SaveVersion, CurrentVersion);
        return false; // do futuro ou sem versão: nunca adivinhar
    }

    // Um passo por versão, em ordem. Um passo publicado nunca é editado: acrescente o próximo.
    if (Save.SaveVersion == 1)
    {
        // 1→2: munição em pente + reserva (a v1 dava um sinalizador grátis a cada load).
        FVGPlayerRecord& Player = Save.Player;
        Player.AmmoInMagazine = FMath::Min(Player.Flares, 1); // o sinalizador tem pente 1 (decisão firmada)
        Player.ReserveAmmo = Player.Flares - Player.AmmoInMagazine;
        Player.Flares = 0;
        Save.SaveVersion = 2;
    }

    // A snapshot narrativa tem versão própria (Cap. 46). Hoje só existe a 1.
    if (Save.Narrative.Version != FVGNarrativeState().Version)
    {
        OutError = FString::Printf(TEXT("Snapshot narrativa versão %d sem migração."), Save.Narrative.Version);
        return false;
    }
    return true;
}

bool VGSaveRules::CanCheckpoint(const FCheckpointContext& Context)
{
    return Context.bPlayerAlive
        && !Context.bCinematicPlaying
        && Context.Threat != EVGThreatLevel::Hunting
        && Context.Phase != EVGDirectorPhase::Peak;
}
```

### 3. O subsistema de save

```cpp
// Source/Vigilia/Save/VGSaveSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Save/VGSaveGame.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "VGSaveSubsystem.generated.h"

class USaveGame;

DECLARE_MULTICAST_DELEGATE_OneParam(FVGSaveFinishedNative, bool /*bSuccess*/);
DECLARE_MULTICAST_DELEGATE(FVGLoadFailedNative);

/**
 * Checkpoints da Vigília: grava em momentos seguros, recarrega na morte e no "continuar".
 * Um slot. Dono do fluxo de carga; NÃO é dono dos estados (narrativa, jogadora): só os transporta.
 */
UCLASS()
class VIGILIA_API UVGSaveSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    static UVGSaveSubsystem* Get(const UObject* WorldContextObject);

    // --- Fluxo de jogo
    /** Um AVGCheckpoint foi alcançado: grava agora ou assim que o momento for seguro. */
    void RequestCheckpoint(FName CheckpointId);

    /** Cheat e testes: grava já, ignorando a trava de momento. */
    void ForceCheckpoint();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Save")
    bool HasSave() const;

    /** Menu principal: lê o slot do disco, migra e abre o nível do checkpoint. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Save")
    void ContinueGame();

    /** Morte: recarrega o último checkpoint (da memória, se houver). */
    void ReloadLastCheckpoint();

    /** A UI já confirmou: apaga o slot, zera a narrativa e abre o primeiro nível. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Save")
    void StartNewGame(FName FirstMap);

    // --- Pontos de integração
    /** AVGGameMode::InitGame: o nível novo existe e nenhum ator foi inicializado. */
    void ApplyPendingLoad();

    /** AVGGameMode::ChoosePlayerStart: uma vez por load. */
    FName ConsumeSpawnCheckpoint();

    /** A personagem leva o que tem numa troca de nível; o load sobrescreve. */
    void StorePlayerRecord(const FVGPlayerRecord& Record);
    bool ConsumePlayerRecord(FVGPlayerRecord& OutRecord);

    static FVGPlayerRecord CapturePlayer(const APawn& Pawn);
    static void ApplyPlayer(APawn& Pawn, const FVGPlayerRecord& Record);

    FString DescribeForDebug() const;

    /** A UI mostra o ícone de "salvando" (Cap. 55). */
    FVGSaveFinishedNative OnCheckpointSaved;

    /** A UI oferece "novo jogo" (nunca restauramos pela metade). */
    FVGLoadFailedNative OnLoadFailed;

private:
    void TryWriteCheckpoint();
    void WriteCheckpoint();
    void HandleSaved(const FString& SlotName, const int32 UserIndex, bool bSuccess);
    void HandleLoaded(const FString& SlotName, const int32 UserIndex, USaveGame* Loaded);
    void BeginLoad(UVGSaveGame* Save);
    void ClearPendingRequest();
    bool IsCheckpointMomentSafe() const;

    /** Última gravação confirmada pelo disco. */
    UPROPERTY()
    TObjectPtr<UVGSaveGame> LastSave;

    /** Sendo escrita agora (uma por vez). */
    UPROPERTY()
    TObjectPtr<UVGSaveGame> InFlightSave;

    /** Esperando o nível abrir para ser aplicada. */
    UPROPERTY()
    TObjectPtr<UVGSaveGame> PendingLoad;

    FName RequestedCheckpoint;
    FName SpawnCheckpoint;
    FVGPlayerRecord PendingPlayer;
    bool bHasPendingPlayer = false;
    bool bSaveQueued = false;
    FTimerHandle RetryHandle;
};
```

```cpp
// Source/Vigilia/Save/VGSaveSubsystem.cpp
#include "Save/VGSaveSubsystem.h"

#include "AI/VGDirectorSubsystem.h"
#include "AI/VGThreatSubsystem.h"
#include "Combat/VGHealthComponent.h"
#include "Combat/VGWeapon.h"
#include "Combat/VGWeaponComponent.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGLog.h"
#include "Core/VGStatusTagsComponent.h"
#include "Engine/Engine.h"
#include "Engine/GameInstance.h"
#include "GeneralProjectSettings.h"
#include "Kismet/GameplayStatics.h"
#include "Narrative/VGCinematicSubsystem.h"
#include "Narrative/VGNarrativeSubsystem.h"
#include "Player/VGBatteryComponent.h"
#include "Save/VGSaveRules.h"
#include "TimerManager.h"

UVGSaveSubsystem* UVGSaveSubsystem::Get(const UObject* WorldContextObject)
{
    const UWorld* World = GEngine
        ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull)
        : nullptr;
    const UGameInstance* GameInstance = World ? World->GetGameInstance() : nullptr;
    return GameInstance ? GameInstance->GetSubsystem<UVGSaveSubsystem>() : nullptr;
}

bool UVGSaveSubsystem::HasSave() const
{
    return LastSave != nullptr || UGameplayStatics::DoesSaveGameExist(VGSaveRules::SlotName, VGSaveRules::UserIndex);
}

// ---------------------------------------------------------------- gravar

void UVGSaveSubsystem::RequestCheckpoint(FName CheckpointId)
{
    if (CheckpointId.IsNone() || (LastSave && LastSave->CheckpointId == CheckpointId))
    {
        return; // nascer dentro do volume, ou voltar a um checkpoint já gravado, não grava de novo
    }
    RequestedCheckpoint = CheckpointId;
    TryWriteCheckpoint();
}

void UVGSaveSubsystem::ForceCheckpoint()
{
    if (RequestedCheckpoint.IsNone() && LastSave)
    {
        RequestedCheckpoint = LastSave->CheckpointId;
    }
    WriteCheckpoint();
}

void UVGSaveSubsystem::TryWriteCheckpoint()
{
    FTimerManager& Timers = GetGameInstance()->GetTimerManager();
    if (!IsCheckpointMomentSafe())
    {
        // O checkpoint registra o LUGAR; o MOMENTO espera a calma (seção 56.2).
        if (!Timers.IsTimerActive(RetryHandle))
        {
            Timers.SetTimer(RetryHandle, this, &UVGSaveSubsystem::TryWriteCheckpoint, 0.5f, /*bLoop*/ true);
        }
        return;
    }
    Timers.ClearTimer(RetryHandle);
    WriteCheckpoint();
}

bool UVGSaveSubsystem::IsCheckpointMomentSafe() const
{
    const UWorld* World = GetWorld();
    if (!World)
    {
        return false;
    }
    const UVGThreatSubsystem* Threat = World->GetSubsystem<UVGThreatSubsystem>();
    const UVGDirectorSubsystem* Director = World->GetSubsystem<UVGDirectorSubsystem>();
    const UVGCinematicSubsystem* Cinematics = World->GetSubsystem<UVGCinematicSubsystem>();
    const APawn* Pawn = UGameplayStatics::GetPlayerPawn(World, 0);
    const UVGHealthComponent* Health = Pawn ? Pawn->FindComponentByClass<UVGHealthComponent>() : nullptr;

    VGSaveRules::FCheckpointContext Context;
    Context.Threat = Threat ? Threat->GetThreatLevel() : EVGThreatLevel::Calm;
    Context.Phase = Director ? Director->GetPhase() : EVGDirectorPhase::Relax;
    Context.bCinematicPlaying = Cinematics && Cinematics->IsPlaying();
    Context.bPlayerAlive = Health && Health->IsAlive();
    return VGSaveRules::CanCheckpoint(Context);
}

void UVGSaveSubsystem::WriteCheckpoint()
{
    if (InFlightSave)
    {
        bSaveQueued = true; // um por vez; ao terminar, grava de novo com o estado mais recente
        return;
    }
    UWorld* World = GetWorld();
    const APawn* Pawn = World ? UGameplayStatics::GetPlayerPawn(World, 0) : nullptr;
    const UVGNarrativeSubsystem* Narrative = GetGameInstance()->GetSubsystem<UVGNarrativeSubsystem>();
    if (!Pawn || !Narrative)
    {
        return;
    }

    UVGSaveGame* Save = Cast<UVGSaveGame>(UGameplayStatics::CreateSaveGameObject(UVGSaveGame::StaticClass()));
    Save->SaveVersion = VGSaveRules::CurrentVersion;
    Save->SavedAtUtc = FDateTime::UtcNow();
    Save->BuildVersion = GetDefault<UGeneralProjectSettings>()->ProjectVersion;
    Save->MapName = FName(UGameplayStatics::GetCurrentLevelName(World, /*bRemovePrefixString*/ true));
    Save->CheckpointId = RequestedCheckpoint;
    Save->Narrative = Narrative->CaptureSnapshot(); // cópia: o jogo segue mudando o original
    Save->Player = CapturePlayer(*Pawn);

    InFlightSave = Save;
    // Serializa agora (game thread); escreve no disco em segundo plano; responde no game thread.
    UGameplayStatics::AsyncSaveGameToSlot(Save, VGSaveRules::SlotName, VGSaveRules::UserIndex,
        FAsyncSaveGameToSlotDelegate::CreateUObject(this, &UVGSaveSubsystem::HandleSaved));
}

void UVGSaveSubsystem::HandleSaved(const FString& SlotName, const int32 UserIndex, bool bSuccess)
{
    if (bSuccess)
    {
        LastSave = InFlightSave;
        UE_LOG(LogVigilia, Log, TEXT("Save: checkpoint %s gravado."), *LastSave->CheckpointId.ToString());
    }
    else
    {
        UE_LOG(LogVigilia, Error, TEXT("Save: falha ao gravar o slot %s."), *SlotName);
    }
    InFlightSave = nullptr;
    OnCheckpointSaved.Broadcast(bSuccess);

    if (bSaveQueued)
    {
        bSaveQueued = false;
        WriteCheckpoint();
    }
}

// ---------------------------------------------------------------- carregar

void UVGSaveSubsystem::ContinueGame()
{
    UGameplayStatics::AsyncLoadGameFromSlot(VGSaveRules::SlotName, VGSaveRules::UserIndex,
        FAsyncLoadGameFromSlotDelegate::CreateUObject(this, &UVGSaveSubsystem::HandleLoaded));
}

void UVGSaveSubsystem::HandleLoaded(const FString& SlotName, const int32 UserIndex, USaveGame* Loaded)
{
    UVGSaveGame* Save = Cast<UVGSaveGame>(Loaded);
    FString Error = TEXT("Arquivo ausente ou de outra classe.");
    if (!Save || !VGSaveRules::Migrate(*Save, Error))
    {
        UE_LOG(LogVigilia, Error, TEXT("Save: %s recusado. %s"), *SlotName, *Error);
        OnLoadFailed.Broadcast();
        return;
    }
    BeginLoad(Save);
}

void UVGSaveSubsystem::ReloadLastCheckpoint()
{
    if (LastSave)
    {
        BeginLoad(LastSave); // a morte não precisa do disco: o último save confirmado está na memória
    }
    else
    {
        ContinueGame();
    }
}

void UVGSaveSubsystem::BeginLoad(UVGSaveGame* Save)
{
    ClearPendingRequest(); // um pedido pendente pertence ao mundo que está acabando
    PendingLoad = Save;
    UGameplayStatics::OpenLevel(this, Save->MapName);
}

void UVGSaveSubsystem::ApplyPendingLoad()
{
    if (!PendingLoad)
    {
        return; // troca de nível comum: nada a aplicar
    }
    UVGSaveGame* Save = PendingLoad;
    PendingLoad = nullptr;
    LastSave = Save;

    // A narrativa primeiro: quests, falas e portões de fato do nível novo nascem lendo o estado certo.
    GetGameInstance()->GetSubsystem<UVGNarrativeSubsystem>()->RestoreSnapshot(Save->Narrative);
    SpawnCheckpoint = Save->CheckpointId;
    StorePlayerRecord(Save->Player); // sobrescreve o que a personagem antiga guardou ao sair
}

FName UVGSaveSubsystem::ConsumeSpawnCheckpoint()
{
    const FName Checkpoint = SpawnCheckpoint;
    SpawnCheckpoint = NAME_None;
    return Checkpoint;
}

void UVGSaveSubsystem::StartNewGame(FName FirstMap)
{
    ClearPendingRequest();
    LastSave = nullptr;
    PendingLoad = nullptr;
    SpawnCheckpoint = NAME_None;
    bHasPendingPlayer = false;
    GetGameInstance()->GetSubsystem<UVGNarrativeSubsystem>()->ResetForNewGame();
    UGameplayStatics::DeleteGameInSlot(VGSaveRules::SlotName, VGSaveRules::UserIndex);
    UGameplayStatics::OpenLevel(this, FirstMap);
}

void UVGSaveSubsystem::ClearPendingRequest()
{
    RequestedCheckpoint = NAME_None;
    GetGameInstance()->GetTimerManager().ClearTimer(RetryHandle);
}

// ---------------------------------------------------------------- jogadora

void UVGSaveSubsystem::StorePlayerRecord(const FVGPlayerRecord& Record)
{
    PendingPlayer = Record;
    bHasPendingPlayer = true;
}

bool UVGSaveSubsystem::ConsumePlayerRecord(FVGPlayerRecord& OutRecord)
{
    if (!bHasPendingPlayer)
    {
        return false;
    }
    OutRecord = PendingPlayer;
    bHasPendingPlayer = false;
    return true;
}

FVGPlayerRecord UVGSaveSubsystem::CapturePlayer(const APawn& Pawn)
{
    FVGPlayerRecord Record;
    if (const UVGBatteryComponent* Battery = Pawn.FindComponentByClass<UVGBatteryComponent>())
    {
        Record.BatteryCharge = Battery->GetCharge();
    }
    if (const UVGWeaponComponent* Weapons = Pawn.FindComponentByClass<UVGWeaponComponent>())
    {
        if (const AVGWeapon* Weapon = Weapons->GetCurrentWeapon())
        {
            Record.Weapon = Weapon->GetClass();
            Record.AmmoInMagazine = Weapon->GetAmmoInMagazine();
            Record.ReserveAmmo = Weapon->GetReserveAmmo();
        }
    }
    if (const UVGStatusTagsComponent* Tags = Pawn.FindComponentByClass<UVGStatusTagsComponent>())
    {
        Record.Items = Tags->GetAllTags().Filter(FGameplayTagContainer(TAG_Item)); // só Item.*
    }
    return Record;
}

void UVGSaveSubsystem::ApplyPlayer(APawn& Pawn, const FVGPlayerRecord& Record)
{
    UVGBatteryComponent* Battery = Pawn.FindComponentByClass<UVGBatteryComponent>();
    if (Battery && Record.BatteryCharge >= 0.0f)
    {
        // Só a API pública: a bateria anuncia o próprio estado, e a HUD acompanha como sempre.
        const float Delta = Record.BatteryCharge - Battery->GetCharge();
        if (Delta >= 0.0f)
        {
            Battery->Recharge(Delta);
        }
        else
        {
            Battery->Drain(-Delta);
        }
    }

    UVGWeaponComponent* Weapons = Pawn.FindComponentByClass<UVGWeaponComponent>();
    if (Weapons && !Record.Weapon.IsNull())
    {
        // Simplificação: carga síncrona de uma classe pequena, durante a abertura do nível (Cap. 60).
        if (AVGWeapon* Weapon = Weapons->GiveWeapon(Record.Weapon.LoadSynchronous()))
        {
            Weapon->RestoreAmmo(Record.AmmoInMagazine, Record.ReserveAmmo);
        }
    }

    if (UVGStatusTagsComponent* Tags = Pawn.FindComponentByClass<UVGStatusTagsComponent>())
    {
        for (const FGameplayTag& Item : Record.Items)
        {
            Tags->GrantStatus(Item);
        }
    }
}

FString UVGSaveSubsystem::DescribeForDebug() const
{
    if (!LastSave)
    {
        return TEXT("Save: nenhum checkpoint em memória.");
    }
    return FString::Printf(TEXT("Save v%d | %s @ %s | build %s | %s | fatos %d, quests %d | bateria %.0f, munição %d+%d"),
        LastSave->SaveVersion, *LastSave->MapName.ToString(), *LastSave->CheckpointId.ToString(),
        *LastSave->BuildVersion, *LastSave->SavedAtUtc.ToString(),
        LastSave->Narrative.Facts.Num(), LastSave->Narrative.Quests.Num(),
        LastSave->Player.BatteryCharge, LastSave->Player.AmmoInMagazine, LastSave->Player.ReserveAmmo);
}
```

`Build.cs`: acrescente `"EngineSettings"`, o módulo de `UGeneralProjectSettings` (a versão do projeto, em *Project Settings → Description*). Nenhum módulo novo é necessário para o save em si: `USaveGame` e `UGameplayStatics` estão em `Engine`.

`VGGameplayTags` ganha a raiz `Item` como tag nativa, para o filtro:

```cpp
// VGGameplayTags.h / .cpp (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Item);
UE_DEFINE_GAMEPLAY_TAG(TAG_Item, "Item");
```

### 4. O checkpoint no nível

O checkpoint é um `APlayerStart` com um volume. O `PlayerStartTag`, que a engine já usa para escolher onde nascer, vira o identificador do checkpoint.

```cpp
// Source/Vigilia/Save/VGCheckpoint.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerStart.h"
#include "VGCheckpoint.generated.h"

class UBoxComponent;

/** Ponto de renascimento + volume que pede o save. PlayerStartTag = id do checkpoint (único no jogo). */
UCLASS()
class VIGILIA_API AVGCheckpoint : public APlayerStart
{
    GENERATED_BODY()

public:
    AVGCheckpoint(const FObjectInitializer& ObjectInitializer);

protected:
    virtual void PostInitializeComponents() override;

    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UBoxComponent> SaveVolume;

private:
    UFUNCTION()
    void HandleOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                       UPrimitiveComponent* OtherComp, int32 OtherBodyIndex,
                       bool bFromSweep, const FHitResult& SweepResult);
};
```

```cpp
// Source/Vigilia/Save/VGCheckpoint.cpp
#include "Save/VGCheckpoint.h"

#include "Components/BoxComponent.h"
#include "GameFramework/Pawn.h"
#include "Save/VGSaveSubsystem.h"

AVGCheckpoint::AVGCheckpoint(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer)
{
    SaveVolume = CreateDefaultSubobject<UBoxComponent>(TEXT("SaveVolume"));
    SaveVolume->SetupAttachment(RootComponent);
    SaveVolume->SetBoxExtent(FVector(200.0, 200.0, 150.0));
    SaveVolume->SetCollisionProfileName(TEXT("Trigger"));
}

void AVGCheckpoint::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    SaveVolume->OnComponentBeginOverlap.AddDynamic(this, &AVGCheckpoint::HandleOverlap); // não no construtor (Cap. 15)
}

void AVGCheckpoint::HandleOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
                                  UPrimitiveComponent* OtherComp, int32 OtherBodyIndex,
                                  bool bFromSweep, const FHitResult& SweepResult)
{
    const APawn* Pawn = Cast<APawn>(OtherActor);
    if (Pawn && Pawn->IsPlayerControlled())
    {
        if (UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this))
        {
            Save->RequestCheckpoint(PlayerStartTag);
        }
    }
}
```

### 5. As pontas: GameMode, personagem, arma, controller

🔁 **`AVGGameMode`** (Capítulo 10) ganha a regra de checkpoint que lhe foi prometida:

```cpp
// AVGGameMode (adições)
public:
    virtual void InitGame(const FString& MapName, const FString& Options, FString& ErrorMessage) override;
    virtual AActor* ChoosePlayerStart_Implementation(AController* Player) override;

    /** Morte → "continuar": a regra de onde renascer é do GameMode (Cap. 22). */
    void HandleRespawnRequest(AController* Controller);
```

```cpp
// AVGGameMode.cpp (adições)
#include "EngineUtils.h"
#include "GameFramework/PlayerStart.h"
#include "Save/VGSaveSubsystem.h"

void AVGGameMode::InitGame(const FString& MapName, const FString& Options, FString& ErrorMessage)
{
    Super::InitGame(MapName, Options, ErrorMessage);
    // O mundo novo e os subsistemas dele existem; nenhum ator do nível foi inicializado ainda.
    // ⚠️ Confira essa ordem em UWorld::InitializeActorsForPlay na sua versão da engine.
    if (UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this))
    {
        Save->ApplyPendingLoad();
    }
}

AActor* AVGGameMode::ChoosePlayerStart_Implementation(AController* Player)
{
    UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this);
    const FName Checkpoint = Save ? Save->ConsumeSpawnCheckpoint() : NAME_None;
    if (!Checkpoint.IsNone())
    {
        for (TActorIterator<APlayerStart> It(GetWorld()); It; ++It)
        {
            if (It->PlayerStartTag == Checkpoint)
            {
                return *It;
            }
        }
        UE_LOG(LogVigilia, Warning, TEXT("Checkpoint %s não existe neste nível; usando o início padrão."),
               *Checkpoint.ToString());
    }
    return Super::ChoosePlayerStart_Implementation(Player);
}

void AVGGameMode::HandleRespawnRequest(AController* Controller)
{
    UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this);
    if (Save && Save->HasSave())
    {
        Save->ReloadLastCheckpoint(); // a morte é um load: o caminho de load roda a cada morte
        return;
    }
    RestartPlayer(Controller); // sem checkpoint ainda: o comportamento do Cap. 22
}
```

`ConsumeSpawnCheckpoint` consome o nome: numa troca de nível comum (Pátio → Casa de Força), `ChoosePlayerStart` volta a escolher o início padrão do nível, e não o último checkpoint.

🔁 **`AVGPlayerController::RequestRespawn`** (Capítulo 22) delega ao GameMode:

```cpp
void AVGPlayerController::RequestRespawn()
{
    PopInputMode(EVGInputMode::Dead);
    if (AVGGameMode* GameMode = GetWorld()->GetAuthGameMode<AVGGameMode>())
    {
        GameMode->HandleRespawnRequest(this);
    }
}
```

🔁 **`AVGCharacter`** puxa o próprio registro quando está pronta para recebê-lo, e o entrega ao sair numa troca de nível:

```cpp
void AVGCharacter::BeginPlay()
{
    Super::BeginPlay(); // os componentes (bateria, armas, tags) já iniciaram
    // ... o que já existia ...
    if (UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this))
    {
        FVGPlayerRecord Record;
        if (Save->ConsumePlayerRecord(Record))
        {
            UVGSaveSubsystem::ApplyPlayer(*this, Record);
        }
    }
}

void AVGCharacter::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (EndPlayReason == EEndPlayReason::LevelTransition)
    {
        // Pátio → Casa de Força: a jogadora leva o que tem. Num load, ApplyPendingLoad sobrescreve isto.
        if (UVGSaveSubsystem* Save = UVGSaveSubsystem::Get(this))
        {
            Save->StorePlayerRecord(UVGSaveSubsystem::CapturePlayer(*this));
        }
    }
    Super::EndPlay(EndPlayReason);
}
```

🔁 **`AVGWeapon`** (Capítulo 20) ganha um caminho de restauração que não passa pelo disparo nem pela recarga:

```cpp
// AVGWeapon (adição pública)
/** Restauração de save: valores do arquivo são entrada não confiável, por isso o clamp. */
void RestoreAmmo(int32 InMagazine, int32 Reserve)
{
    AmmoInMagazine = FMath::Clamp(InMagazine, 0, Data->MagazineSize);
    ReserveAmmo = FMath::Clamp(Reserve, 0, Data->MaxReserveAmmo);
    BroadcastAmmo();
}
```

🔁 **Cheats.** O `VGNewGame` do Capítulo 46 passa a chamar `StartNewGame` com o nível atual, e entram quatro:

```cpp
// UVGCheatManager (adições)
UFUNCTION(Exec) void VGSave();        // ForceCheckpoint: grava já, ignorando a trava de momento
UFUNCTION(Exec) void VGLoad();        // ReloadLastCheckpoint: o mesmo caminho da morte
UFUNCTION(Exec) void VGDumpSave();    // DescribeForDebug no log
UFUNCTION(Exec) void VGDeleteSave();  // DeleteGameInSlot + esquece o save em memória
```

### Explicação das decisões

- **O subsistema transporta, não possui.** A narrativa continua dona da snapshot, e os componentes da personagem continuam donos da bateria e da munição. O save só sabe **capturar** e **aplicar**, pelas APIs públicas de cada dono. Nenhum sistema ganhou um "modo save" interno.
- **Três momentos de restauração, cada um no ponto certo.** A narrativa é restaurada em `InitGame`, antes de qualquer ator, porque quests, falas e portões de fato (Capítulo 47) **nascem** lendo fatos. O checkpoint é consumido em `ChoosePlayerStart`. A jogadora puxa o próprio registro no `BeginPlay`, depois dos componentes. A regra geral é: **quem é restaurado puxa o estado no momento em que está pronto para recebê-lo**. ⚠️ Um efeito colateral a conferir: `RestoreSnapshot` anuncia `OnRestored` já em `InitGame`. Se o `UVGQuestSubsystem` (Capítulo 46) se inscrever nesse anúncio no `Initialize`, ele reconstrói as quests ali **e** enfileira a retomada de novo no `OnWorldBeginPlay`. Inscreva-o no `OnWorldBeginPlay`, depois de enfileirar a retomada, e a retomada acontece uma vez só.
- **Carregar = reabrir o nível.** Abrir o nível de novo descarta toda a simulação (IA, timers, sons, cenas pela metade) e recria o mundo a partir do conteúdo. É mais lento que restaurar no lugar, e muito mais simples: não existe "esqueci de parar aquele timer". Gatilhos disparados **depois** do checkpoint voltam armados sem que ninguém chame `ResetTrigger`, porque o ator é novo. O Capítulo 57 garante que os disparados **antes** continuem disparados.
- **A morte usa a cópia em memória.** O disco não entra no caminho da morte; só o "continuar" do menu lê o arquivo.
- **Pedido pendente morre com o mundo.** Se a jogadora atravessa um checkpoint durante uma caçada e morre antes da calma, o pedido é descartado no load. Sem isso, o sistema gravaria o checkpoint B com a jogadora renascida no A.

### 6. Teste

```cpp
// Source/Vigilia/Tests/VGSaveTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayTags.h"
#include "Kismet/GameplayStatics.h"
#include "Save/VGSaveGame.h"
#include "Save/VGSaveRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGSaveTest, "Vigilia.Save.RoundTripMigrationGate",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGSaveTest::RunTest(const FString& Parameters)
{
    // 1. Ida e volta em memória: o mesmo caminho de SaveGameToSlot, sem disco.
    UVGSaveGame* Save = NewObject<UVGSaveGame>();
    Save->SaveVersion = VGSaveRules::CurrentVersion;
    Save->CheckpointId = TEXT("CP_Teste");
    Save->Narrative.AddFact(TAG_World_Sector_Powered);
    Save->Narrative.AddToCounter(TAG_Faction_Target, 3);
    Save->Player.AmmoInMagazine = 0;
    Save->Player.ReserveAmmo = 2;

    TArray<uint8> Bytes;
    TestTrue(TEXT("Serializa"), UGameplayStatics::SaveGameToMemory(Save, Bytes));
    const UVGSaveGame* Loaded = Cast<UVGSaveGame>(UGameplayStatics::LoadGameFromMemory(Bytes));
    if (!TestNotNull(TEXT("Desserializa"), Loaded))
    {
        return false;
    }
    TestEqual(TEXT("Checkpoint"), Loaded->CheckpointId, FName(TEXT("CP_Teste")));
    TestTrue(TEXT("Fato"), Loaded->Narrative.Facts.HasTagExact(TAG_World_Sector_Powered));
    TestEqual(TEXT("Contador"), Loaded->Narrative.Counters.FindRef(TAG_Faction_Target), 3);
    TestEqual(TEXT("Pente vazio continua vazio"), Loaded->Player.AmmoInMagazine, 0);

    // 2. Migração 1→2: o total vira pente + reserva, sem criar munição.
    UVGSaveGame* Old = NewObject<UVGSaveGame>();
    Old->SaveVersion = 1;
    Old->Player.Flares = 3;
    FString Error;
    TestTrue(TEXT("Migra v1"), VGSaveRules::Migrate(*Old, Error));
    TestEqual(TEXT("Versão atual"), Old->SaveVersion, VGSaveRules::CurrentVersion);
    TestEqual(TEXT("Pente"), Old->Player.AmmoInMagazine, 1);
    TestEqual(TEXT("Reserva"), Old->Player.ReserveAmmo, 2);

    // 3. Versões que não se carregam: sem versão e do futuro.
    UVGSaveGame* Bad = NewObject<UVGSaveGame>();
    TestFalse(TEXT("Recusa sem versão"), VGSaveRules::Migrate(*Bad, Error));
    Bad->SaveVersion = VGSaveRules::CurrentVersion + 1;
    TestFalse(TEXT("Recusa do futuro"), VGSaveRules::Migrate(*Bad, Error));

    // 4. A trava de momento.
    VGSaveRules::FCheckpointContext Calm;
    TestTrue(TEXT("Calma grava"), VGSaveRules::CanCheckpoint(Calm));
    VGSaveRules::FCheckpointContext Hunted = Calm;
    Hunted.Threat = EVGThreatLevel::Hunting;
    TestFalse(TEXT("Caçada espera"), VGSaveRules::CanCheckpoint(Hunted));
    VGSaveRules::FCheckpointContext Dead = Calm;
    Dead.bPlayerAlive = false;
    TestFalse(TEXT("Nunca salva a morte"), VGSaveRules::CanCheckpoint(Dead));
    return true;
}

#endif
```

O teste usa `SaveGameToMemory`/`LoadGameFromMemory`, que é o mesmo caminho de serialização do slot sem o disco. E fixa em teste as duas decisões que mais doem quando quebram: a migração não cria munição, e a morte nunca é salva.

---

## Projeto Vigília — checkpoints no setor 1

### Os checkpoints

Quatro `AVGCheckpoint` em `L_CasaDeForca`, nas batidas da quest `DA_Quest_S1_NightShift`:

| `PlayerStartTag` | Onde | Batida | Por que aqui |
|---|---|---|---|
| `CP_S1_Hall` | Hall, logo após a porta | Chegada | O início do setor; o load do "continuar" mais comum |
| `CP_S1_Corredor` | Corredor, antes da curva | Depois do livro e do memorando | Protege a investigação, que é a parte mais longa |
| `CP_S1_Subsolo` | Pé da escada do subsolo | Depois do susto | O susto não se repete na morte (o fato `S1.ScareDone` já existe) |
| `CP_S1_Controle` | Sala de controle | Energia restaurada | Antes da cena final |

Os nomes entram no `docs/design/save.md`, ao lado da regra: **checkpoints publicados não se renomeiam**.

### O teste: salvar no meio do setor 1 e carregar

Este é o teste que o Milestone 8 pede, feito à mão antes de ser automatizado. Jogue em *Standalone* (não só no PIE), com `vg.Debug.Narrative 1`:

1. **Novo jogo.** Pegue o livro de ocorrências, leia até a segunda página, pegue a chave. Atravesse `CP_S1_Corredor`. O log diz "checkpoint CP_S1_Corredor gravado".
2. **Mude o estado depois do checkpoint.** Dispare um sinalizador (pente 0, reserva 2). Gaste bateria. Leia o memorando.
3. **Morra** (o volume de dano do Capítulo 22, ou `VGKillPlayer`). Aperte "continuar".
4. **Confira**, na tela e com `VGDumpSave`:
   - Você nasce no `CP_S1_Corredor`, com a chave e com a bateria e a munição **do momento do checkpoint**, não as de depois.
   - O livro está no arquivo de documentos; o memorando **não** está (foi lido depois do checkpoint).
   - A quest está na etapa certa, e a conversa `Chegada` não toca de novo.
5. **Feche o jogo** e abra de novo. "Continuar" leva ao mesmo estado, agora lido do disco.
6. **Atravesse o corredor durante uma caçada** (com `VGAddFact` e o Diretor, ou jogando). O log não grava; quando a Presença desiste e o Diretor entra em `Recovery`, grava.

Foi no passo 4 que a versão 1 deste capítulo falhou: carregar com o pente vazio devolvia um sinalizador no pente. O teste manual achou o bug, a migração 1→2 o corrigiu, e o teste automatizado o mantém corrigido. Guarde um `.sav` da v1 em `Tests/SaveFixtures/` antes de mudar o formato: é o único jeito de testar a migração com um arquivo de verdade.

### O que o teste ainda mostra de errado

Repita o teste, mas **antes** do checkpoint abra a porta do vestiário e pegue a bateria do depósito. Depois do load:

- a porta está **fechada**;
- a bateria está **de volta na prateleira**, e pode ser pega de novo: morrer vira uma fábrica de baterias;
- o gatilho de um alarme que você disparou antes do checkpoint dispara **de novo**.

A narrativa e a jogadora voltaram; o **mundo** voltou ao conteúdo. É o assunto do próximo capítulo.

### O inventário de dores

| # | Dor | Situação depois do Cap. 56 |
|---|---|---|
| 2 | Impossível salvar | 🟡 Narrativa e jogadora salvas, versionadas e testadas; o mundo é o Cap. 57 |
| 9 | Nada é testável | 🟡 Qualquer estado salvo vira um ponto de partida (`VGSave`/`VGLoad`); as ferramentas de depuração são o Cap. 61 |

---

## Decisões arquiteturais

1. **Checkpoints automáticos, um slot, morte = load**, sem save manual nem save ao sair. O custo da morte é calibrado pelo design.
2. **Trava de momento seguro** (viva, sem caçada, sem pico, sem cena), pura e testada; o checkpoint registra o lugar, o momento espera a calma.
3. **Salve fontes e identificadores; derive o resto.** A posição é o nome do checkpoint; a vida não é salva porque a regeneração e a trava a tornam redundante.
4. **Carregar = reabrir o nível e aplicar a diferença**, em três momentos: narrativa em `InitGame`, checkpoint em `ChoosePlayerStart`, jogadora no `BeginPlay` dela.
5. **O save é um contrato com o passado:** `SaveVersion` com padrão neutro, migrações puras e imutáveis, recusa explícita do que não migra, nomes (tags, assets, checkpoints) que não se renomeiam.
6. **Gravação assíncrona, uma por vez**, e a morte usa a cópia em memória.
7. **O arquivo é entrada não confiável**: validação, `Clamp`, recusa sem restauração parcial.

---

## Armadilhas

- **Salvar no momento errado.** Um checkpoint durante a caçada, ou pior, durante a morte, cria um save do qual não se sai. A trava de momento é a primeira coisa a escrever, não a última.
- **Padrão de campo igual à versão atual**, ou padrões que mudam. A serialização delta faz o código novo reinterpretar arquivos antigos.
- **Renomear tags, assets ou checkpoints** com saves existentes, inclusive os da equipe durante a produção. Redirecione, e teste um save antigo.
- **Ponteiros no save.** `UObject*` não tem significado no próximo processo. Use `TSoftObjectPtr`, `TSoftClassPtr` e nomes.
- **Restaurar pela metade.** Um save que migra a narrativa e falha na jogadora deixa o jogo num estado que nunca existiu. Valide tudo, depois aplique tudo.
- **Pedido de checkpoint que sobrevive ao load.** O pedido pendente pertence ao mundo que acabou.
- **Restaurar a jogadora antes de os componentes iniciarem.** O `BeginPlay` do componente zera o que você acabou de restaurar. Puxe o estado depois do `Super::BeginPlay()`.
- **Testar só no PIE.** Cada sessão de PIE ganha um `UGameInstance` novo e caminhos de nível com prefixo (`UEDPIE_0_`). O fluxo de "fechar e continuar" só se testa em *Standalone* ou num build.

---

## Exercício

**Parte 1 — o envelope e as regras (1,5 h).** Implemente `FVGPlayerRecord`, `UVGSaveGame`, `VGSaveRules` e o teste. Rode o teste no *Session Frontend* (ou `Automation RunTests Vigilia.Save` no console) até ficar verde.

**Parte 2 — o subsistema (2 h).** Implemente `UVGSaveSubsystem`, o `AVGCheckpoint` e as mudanças no GameMode, no controller, na personagem e na arma. Coloque os quatro checkpoints do setor 1 e faça o teste "salvar no meio do setor 1 e carregar" em *Standalone*.

**Parte 3 — a migração de verdade (1 h).** Antes de aplicar a v2, grave um save com a v1 (o registro só com `Flares`) e guarde o arquivo em `Tests/SaveFixtures/`. Aplique a v2 e confirme que o arquivo antigo carrega com a munição certa. Escreva no `DEVLOG.md` o que aconteceria sem o arquivo guardado.

**Parte 4 — a especificação (30 min).** Escreva o `docs/design/save.md`: a tabela da seção 56.3 com o **motivo** de cada linha, a lista de checkpoints e as regras de nomes.

---

## Desafio — o arquivo que não pode estragar

Um save corrompido no meio da escrita (queda de energia, processo morto) faz a jogadora perder **tudo**, e não só o último checkpoint. Construa a defesa:

1. **Rotação de dois slots.** Grave alternadamente em `Vigilia_A` e `Vigilia_B`. No "continuar", carregue os dois, migre os dois e use o mais recente **válido** (`SavedAtUtc`).
2. **Corrompa de propósito.** Trunque um dos arquivos pela metade com um editor hexadecimal. O jogo deve carregar o outro, registrar um aviso e nunca travar.
3. Responda no `DEVLOG.md`:
   - O que `LoadGameFromSlot` devolve para um arquivo truncado na sua versão da engine?
   - A rotação protege contra **qual** falha, e não protege contra qual?
   - Por que a rotação é mais simples que escrever num arquivo temporário e renomear, e quando a segunda opção seria melhor?

---

## Uso de IA

1. **Para auditar o inventário de save:**
   > "Aqui está a tabela de estado de um jogo de terror curto com checkpoints (estado, dono, salvo ou não, como volta) e as regras de quando o checkpoint pode gravar. Para cada linha 'não salva', descreva um cenário em que a jogadora perceberia a diferença depois de um load. Para cada linha 'salva', diga se ela poderia ser derivada de outra. [tabela + regras]"

2. **Para revisar migrações:**
   > "Revise esta função de migração de save em C++ (Unreal Engine 5). Procure: passos que dependem de dados que um passo anterior apagou, passos que podem criar recursos para a jogadora, versões do futuro aceitas, e falhas que deixam o objeto meio migrado. [código]"

3. **Para pensar em casos de borda do fluxo de carga:**
   > "Num jogo da Unreal, carregar um checkpoint reabre o nível; a narrativa é restaurada em InitGame do GameMode, o ponto de nascimento em ChoosePlayerStart e o inventário no BeginPlay da personagem. Liste o que pode dar errado nessa ordem: o que lê estado antes de ele ser restaurado, o que é sobrescrito depois, e o que acontece se o jogador morrer durante uma gravação assíncrona."

**Cuidado específico:** a IA tende a propor o save "completo": serializar todos os atores do nível, com reflexão, num sistema genérico. Parece elegante e é exatamente a abordagem B da tabela, que salva o que não deveria (simulação) e faz o formato do arquivo depender de quem marcou qual propriedade. Peça à IA para criticar o **seu** inventário, não para desenhar um sistema que dispensa o inventário. E confira cada função da engine que ela citar: APIs de save mudam de assinatura entre versões.

---

## Checklist

- [ ] Sei explicar por que um save é uma descrição e não uma cópia da memória.
- [ ] Sei defender checkpoints para a Vigília pelo design e pela engenharia, e sei quando o save livre seria a escolha certa.
- [ ] Tenho um inventário de save com o motivo de cada linha.
- [ ] Uso `AsyncSaveGameToSlot`/`AsyncLoadGameFromSlot` e sei o que cada um faz em que thread.
- [ ] Meu save tem `SaveVersion` com padrão neutro, migrações puras e um arquivo antigo guardado para teste.
- [ ] A morte recarrega o último checkpoint, e o checkpoint nunca grava durante a caçada, o pico, uma cena ou a morte.
- [ ] Fiz o teste "salvar no meio do setor 1 e carregar" em *Standalone*, e sei por que o mundo ainda não volta certo.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Saving and Loading Your Game** (`USaveGame` e as funções de slot), **Core Redirects** e **Gameplay Tags** (redirecionamento de tags). Leia também `GameplayStatics.cpp`, nas funções de save, para ver o cabeçalho e o arquivo de leitura que a engine usa.
- ***Game Engine Architecture***, de Jason Gregory: os capítulos sobre os sistemas de fundação do gameplay discutem mundos, estado e jogos salvos do ponto de vista da engine.
- **GDC Vault** (gdcvault.com): há palestras sobre sistemas de save e checkpoint em jogos de ação e de mundo aberto (procure por "save system" e "checkpoint"; confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 57 — Persistence](cap-57-persistence.md)

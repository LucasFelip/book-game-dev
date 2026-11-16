# Capítulo 44 — Dialogue Systems

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir as **formas de fala** de um jogo (conversa ramificada, conversa de mão única, *barks*, narração) e o que cada uma exige do sistema;
- modelar uma fala como **dado** (falante, texto, áudio, duração, condição, efeitos, memória) e uma conversa como **grafo de nós**, sem `Branch` espalhado;
- tratar a voz como um **recurso escasso**: uma fala por vez, fila por prioridade, interrupção, retomada e expiração;
- escolher o **relógio** certo para o tempo de fala e para as legendas;
- implementar **escolhas que não pausam o jogo**, incluindo o silêncio como resposta;
- entender o que a Unreal oferece (texto localizável, *String Tables*, *Dialogue Waves*, legendas de *Sound Wave*) e o que fica por sua conta;
- migrar o rádio de Sônia do *Turno da Noite* para o novo sistema, resolvendo as dores 3 e 10 do Interlúdio I.

---

## Contexto

No Interlúdio I, cada fala de Sônia era um nó `Rádio("...")` no Level Blueprint: um `Play Sound 2D`, uma legenda, o texto escrito **dentro do grafo**. O inventário de dores registrou o preço:

- **Dor 3:** para corrigir uma fala é preciso abrir o Level Blueprint e achar o nó. Um roteirista não consegue revisar o roteiro, e localizar para inglês é inviável.
- **Dor 10:** o rádio não sabe o que já disse. Nada impede Sônia de repetir uma fala.
- **Dor 4 (em parte):** cada fala condicional (leu o memorando ou não) é um `Branch` em algum lugar do grafo, e todos precisam "concordar" sobre a mesma variável.

Há também dores que o Interlúdio não chegou a sentir, porque a história era curta e linear demais para elas aparecerem: duas falas pedidas ao mesmo tempo se sobrepõem; uma fala disparada enquanto a jogadora lê um documento disputa a atenção com o texto; uma fala que chega atrasada (porque outra estava tocando) fica sem sentido. Num jogo em que **o rádio é o fio condutor** (Capítulo 43, seção 43.8), esses problemas deixam de ser detalhes.

O sistema de diálogo resolve três coisas diferentes, e convém separá-las desde o começo:

1. **Conteúdo** — o que se diz, quem diz, com que áudio. Pertence ao roteirista.
2. **Fluxo** — em que ordem, sob que condições, com que escolhas. Pertence ao narrative designer.
3. **Entrega** — quando a fala de fato toca, como disputa o canal com outras, como aparece na tela. Pertence à engenharia.

O Interlúdio misturou as três num grafo. Este capítulo as separa.

---

## 44.1 Quatro formas de fala

| Forma | Exemplo | Quem controla o tempo | Escolhas? | O que o sistema precisa |
|---|---|---|---|---|
| **Conversa ramificada** | Diálogo com um NPC em RPG; roda de diálogo | A jogadora (avança, escolhe) | Sim | Grafo, condições, efeitos, UI de escolha; o jogo costuma parar |
| **Conversa de mão única** | Rádio, telefone, comunicador | O jogo | Raras | Fila, prioridade, interrupção, legendas; o jogo **não** para |
| ***Barks*** | "Recarregando!", "Perdi ela de vista!" | O jogo, por evento | Não | Seleção por regras e contexto, variação sem repetição, áudio posicional, limite de quantos falam |
| **Narração / leitura** | Diário lido em voz alta, gravações | A jogadora (inicia) ou o jogo | Não | Áudio longo, legenda sincronizada, pode coexistir com exploração |

A Vigília usa principalmente a **segunda** (Sônia no rádio) e a **terceira** (os vigias, que já disputam um token de *bark* desde o Capítulo 42). A primeira aparece num grau mínimo: algumas respostas de Helena pelo rádio, sem parar o jogo. A quarta virá com os documentos e as fitas de 1994 (Capítulo 48).

A distinção mais importante para a arquitetura é a coluna **"quem controla o tempo"**. Num RPG clássico, a conversa é um **modo**: o mundo para, a câmera enquadra os personagens, e a jogadora avança fala a fala. No rádio, a conversa é um **processo em segundo plano**: o mundo continua, a Presença continua caçando, e a fala precisa conviver com tudo isso. É por isso que o sistema da Vigília se parece menos com um "visualizador de conversas" e mais com um **escalonador de um canal de áudio**.

---

## 44.2 A fala como dado

Uma fala, decomposta, tem mais partes do que parece:

```text
 FALA (nó)
 ├── Id              chave estável: alvo de saltos e chave da memória de "já dito"
 ├── Falante         quem fala: nome exibido, cor da legenda, se é pelo rádio
 ├── Texto           FText — localizável, revisável por roteirista
 ├── Voz             áudio (ou nada, no protótipo)
 ├── Pausa antes     o "8 segundos depois" do Interlúdio mora aqui, não num Delay
 ├── Condição        sobre fatos narrativos: se falhar, a fala é pulada
 ├── Efeitos         fatos concedidos quando a fala termina de ser ouvida
 ├── Uma vez só?     memória: nunca repetir esta fala
 └── Depois          próximo nó, um salto, ou escolhas (com tempo-limite)
```

Três decisões já estão embutidas nessa lista.

**Texto é `FText`, não `FString`.** `FText` é o tipo de texto **exibível** da Unreal: participa do sistema de localização, pode apontar para uma entrada de *String Table* e é coletado pelas ferramentas de tradução. Uma `FString` com uma fala é um bug de localização esperando para acontecer.

> 🌉 **Ponte:** `FText` está para a Unreal como o `MessageSource`/`ResourceBundle` está para uma aplicação Spring: o código guarda uma **chave**, e o texto exibido depende do idioma ativo. A *String Table* é o seu `messages.properties`.
>
> 🧱 **Onde a ponte cai:** no jogo, o texto tem **voz**. Cada idioma tem o seu áudio, com **durações diferentes**, e a legenda precisa casar com a voz que está tocando. Traduzir uma fala é traduzir texto, áudio e tempo.

**A condição é um dado, não um `Branch`.** No Interlúdio, "se leu o memorando, Sônia pergunta; senão, elogia" eram dois `Branch` em lugares diferentes. Como dado, são **duas falas consecutivas com condições mutuamente exclusivas**: a primeira exige o fato "memorando lido"; a segunda exige a ausência dele. O fluxo pula a que não passa. Não existe `if/else` em lugar nenhum. Existe uma **regra** ("pule nós cuja condição falha") aplicada a **dados**. Este é o ponto central do capítulo, e o mesmo princípio volta nas quests (Capítulo 45) e na ramificação (Capítulo 47).

**A memória é por fala, com chave estável.** "Já dito" não é uma variável booleana por fala no Level Blueprint. É um conjunto de chaves (`conversa.nó`) mantido pelo sistema. Qualquer fala marcada como "uma vez só" consulta esse conjunto. A dor 10 desaparece como **propriedade do sistema**, não como cuidado de quem monta o nível.

### Fatos

Condições e efeitos precisam de algo sobre o que operar: os **fatos narrativos**. Na Vigília, um fato é uma Gameplay Tag sob `Narrative.Fact.*`: `Narrative.Fact.Document.Memo.Read`, `Narrative.Fact.Helena.AdmittedTurbine3`. Condições são `FGameplayTagQuery` (Capítulo 23): "tem este fato", "não tem nenhum destes", "tem todos destes".

O dono definitivo dos fatos é o **estado narrativo**, assunto do Capítulo 46: ele vai persistir, derivar fatos de eventos e responder consultas para o jogo inteiro. Neste capítulo, os fatos moram **provisoriamente** no subsistema de diálogo, marcados com `// Simplificação:`. É a mesma estratégia de sempre: resolver a dor da vez com o mínimo, deixando claro onde a solução vai morar depois.

---

## 44.3 Do roteiro ao grafo

Uma conversa é uma lista de nós lida em ordem, com três mecanismos de desvio:

1. **Condição** — o nó é pulado se a condição falhar.
2. **Salto** — `Next` aponta para outro nó pelo Id (ou para `End`).
3. **Escolhas** — ao terminar a fala, a jogadora escolhe; cada escolha concede fatos e aponta para um nó.

Com só o primeiro, você tem **variantes**. Com o segundo, tem **laços e convergências**. Com o terceiro, tem **conversa**. A ordem do array é o caminho padrão, de modo que uma conversa linear não precisa de nenhum salto. Isso mantém o caso comum (o rádio quase sempre é linear) barato de escrever.

### O exemplo: os disjuntores (beat 7)

No Interlúdio, o beat 7 tinha duas falas condicionais. Na migração, ele ganha a primeira escolha da Vigília: quando Sônia pergunta se Helena religou a turbina três, a jogadora pode responder, ou não dizer nada.

```text
 DA_Dlg_S1_Disjuntores  (Critical)

 [Pergunta]  Sônia: "Espera. O memorando dizia pra não religar a três sem o Moraes.
             Você religou a três?"
             condição: TEM Memo.Read
             escolhas (tempo-limite 6 s):
               1 "Religuei. Era a ordem do livro."   → concede Helena.AdmittedTurbine3
               2 "Eu não sei o que eu religuei."     → concede Helena.Doubted
               (silêncio)                            → nada
                    │
                    ▼   (todas seguem para o próximo nó; as condições filtram)
 [Admitiu]   Sônia: "...Tá. Tá bom. Só... fica perto do hall, tá?"
             condição: TEM Helena.AdmittedTurbine3
 [Duvidou]   Sônia: "Ninguém sabe, Helena. Esse é o problema dessa usina."
             condição: TEM Helena.Doubted
 [Calou]     Sônia: "Helena? ...Tá. Depois você me conta."
             condição: TEM Memo.Read E NÃO TEM (AdmittedTurbine3, Doubted)
 [Paineis]   Sônia: "Os painéis estão respondendo aqui na central. Bom trabalho."
             condição: NÃO TEM Memo.Read
```

Repare que **nenhuma escolha precisa de salto**. Cada escolha concede um fato, e as respostas são falas condicionadas a esses fatos. O fluxo segue em ordem, e as condições escolhem o caminho. É um padrão útil para conversas curtas: **escolher é afirmar um fato; reagir é falar sob condição**. Para conversas longas, com laços e convergências, os saltos por Id entram em cena.

Repare também em duas decisões de design:

- **A escolha de Helena não é dublada.** O texto da escolha aparece, a jogadora escolhe, e Sônia reage. O documento de narrativa (Capítulo 43) disse que Helena quase não fala: *a jogadora fala por ela*. Isso também corta pela metade o custo de produção das respostas.
- **O fato concedido é narrativo, não só de diálogo.** `Helena.AdmittedTurbine3` pode mudar a fala final de Sônia, ou um documento no setor 2 (consequência tardia, Capítulo 47). A conversa produz estado que o resto do jogo lê.

---

## 44.4 O canal de voz: um recurso escasso

Uma pessoa no rádio fala uma coisa de cada vez. Parece óbvio, mas o Interlúdio violava a regra sempre que dois gatilhos disparavam perto um do outro: duas falas tocavam juntas, com duas legendas sobrepostas. Num protótipo de nove beats isso quase não acontece. Num jogo inteiro, com quests, documentos, Diretor e sustos pedindo falas, acontece o tempo todo.

O sistema trata o rádio como **um canal com uma fila**:

```text
                       pedidos de conversa
        quest ──┐                                ┌── rádio (voz + legenda)
   documento ───┼──►  FILA (prioridade, ordem)  ─┼──► UMA conversa por vez
     Diretor ───┤      │                         │
       susto ───┘      │ expira se esperar demais│
                       │ Critical interrompe     │
                       ▼                         │
             interrompida? volta à fila e retoma do nó em que parou
```

As regras:

| Regra | Por quê |
|---|---|
| **Uma conversa por vez** | Duas vozes no mesmo rádio são ruído |
| **Prioridade: Ambient < Normal < Critical** | Um comentário de ambiente cede a vez a um beat, que cede a vez à revelação |
| **Só prioridade estritamente maior interrompe** | Duas falas Normal não se atropelam: a segunda espera |
| **Interrompida → volta à fila, retoma o nó cortado** | A fala cortada repete do começo; o resto da conversa não se perde |
| **Expiração (`MaxWait`)** | Uma fala que esperou demais perdeu o contexto: "a porta não abre sem energia" quando a jogadora já está no subsolo |
| **Durante a leitura, só Critical começa** | Ler um documento e ouvir o rádio ao mesmo tempo é perder um dos dois (uma fala já em curso termina) |
| **Fala interrompida não conta como dita** | Memória e efeitos só depois de ouvida inteira |

A última regra tem uma consequência sutil: **os efeitos de uma fala (fatos concedidos) acontecem no fim dela, não no começo**. Se Sônia é cortada no meio da frase que revela algo, a jogadora não ouviu a revelação, e o jogo não deve agir como se tivesse ouvido.

> 🌉 **Ponte:** é uma fila de mensagens com **prioridade** e **TTL**: consumidor único, preempção por prioridade, e mensagens vencidas descartadas. Quem já configurou uma fila com prioridade e expiração reconhece o desenho.
>
> 🧱 **Onde a ponte cai:** num sistema de mensageria, perder uma mensagem é falha, e por isso existem *dead letter queues*, retentativas, *at-least-once*. Aqui, **descartar é o comportamento correto**: uma fala atrasada é pior que fala nenhuma. Não há DLQ, não há retentativa. E "processar" leva o tempo da fala inteira, com a jogadora como única consumidora.

### A leitura e o rádio

A regra "durante a leitura, só Critical" usa o modo `Reading` da pilha de modos de input (Capítulo 16), a mesma informação que o Diretor (Capítulo 42) já usa para não iniciar um pico enquanto a jogadora lê. Com isso, a consulta "a jogadora está lendo?" passa a ter **dois** usos. Pelo critério do Capítulo 6, ainda não é hora de extraí-la: se aparecer um terceiro, ela sobe para o `AVGPlayerController`.

---

## 44.5 Quanto dura uma fala — e em que relógio

Uma fala dura o tempo do seu áudio. Sem áudio (o protótipo tem poucas gravações), dura o tempo de **leitura da legenda**. Uma referência comum para legendas confortáveis é algo em torno de **15 caracteres por segundo**, com um mínimo de um segundo e meio para falas curtas. É uma convenção de partida, não uma lei: ajuste no playtest.

A pergunta mais interessante, porém, é **em que relógio** medir esse tempo. O Capítulo 3 apresentou vários, e a regra 5 do Capítulo 6 exige que cada sistema **declare** o seu:

| Relógio | Pausa com o jogo? | Sofre dilatação (hitstop, câmera lenta)? | Serve para a fala? |
|---|---|---|---|
| `GetTimeSeconds` (tempo de jogo) | Sim | **Sim** | ✗ — no hitstop, a legenda "congela" e a voz continua |
| `GetRealTimeSeconds` | **Não** | Não | ✗ — no menu de pausa, a legenda some enquanto a voz está pausada |
| `GetAudioTimeSeconds` | Sim | Não | ✓ — o mesmo comportamento da própria voz |

O relógio de áudio para com a pausa e não é dilatado, exatamente como uma voz tocando. Se o sistema de diálogo medir a fala pelo tempo de jogo, cada hitstop do sinalizador (Capítulo 3) desalinha a legenda da voz por uma fração de segundo. Um bug minúsculo, difícil de ver e fácil de sentir.

⚠️ Confira na sua versão da engine (em `World.h`) o comentário de cada função de tempo. É ali que a engine declara, para cada relógio, se ele pausa e se dilata, e é a fonte mais confiável (o Capítulo 3 tem a tabela completa).

---

## 44.6 Legendas

Legendas não são um extra: muitas jogadoras jogam com elas ligadas, por necessidade (audição) ou por contexto (som baixo, outro idioma). E num jogo de terror, em que o som é parte do medo, a legenda de uma fala de rádio no meio do silêncio é **conteúdo**. Regras práticas para a Vigília:

- **Ligadas por padrão**, desligáveis nas opções (Capítulo 55).
- **Nome do falante** sempre visível, na cor do falante; um **marcador de rádio** quando a fala vem pelo rádio.
- **No máximo duas linhas**; falas mais longas viram dois nós.
- **Tempo mínimo de leitura**, mesmo quando o áudio é curto.
- **Contraste**: fundo semitransparente atrás do texto, porque a usina é escura e a lanterna ilumina paredes claras de forma imprevisível.

As diretrizes de acessibilidade de jogos (*Game Accessibility Guidelines*, ver "Para ir além") tratam legendas em detalhe; vale lê-las antes do Capítulo 55.

---

## 44.7 Escolhas que não pausam o jogo

A escolha de Helena no beat 7 aparece **enquanto a jogadora joga**. Ela está no subsolo escuro, acabou de religar os disjuntores, e o alarme da Casa de Força tocou (Interlúdio I). A pergunta de Sônia chega, duas opções aparecem na tela, e o tempo corre. Se ela não responder em seis segundos, o silêncio é a resposta.

Três consequências de engenharia:

1. **A escolha não é um modo.** O modo de input (Capítulo 16) diz o que a jogadora está fazendo de forma **exclusiva**: explorando, lendo, numa cinemática. Responder ao rádio não é exclusivo: ela continua andando, olhando, fugindo. Por isso as teclas de resposta entram como um **contexto de input sobreposto** (`IMC_RespostaRadio`), adicionado quando as escolhas aparecem e removido quando somem, sem mexer na pilha de modos.
2. **O tempo-limite é parte do design.** Escolha com tempo transforma a conversa em pressão, coerente com o tema (Capítulo 43, harmonia ludonarrativa). E o silêncio custa quase nada: é uma fala condicionada à **ausência** dos fatos das outras escolhas.
3. **As teclas disputam espaço.** Se as teclas 1 e 2 já trocam de arma (Capítulo 26), o contexto de resposta, com prioridade maior, **consome** essas teclas por alguns segundos, e a troca de arma fica bloqueada nesse intervalo. Na Vigília isso é aceitável, porque escolhas no rádio são raras e curtas. Num jogo com escolhas frequentes, as respostas merecem teclas próprias.

---

## Estudos de caso

### Firewatch — o rádio como relação

**[FATO PÚBLICO]** Em *Firewatch* (Campo Santo, 2016), o protagonista, Henry, trabalha como vigia de incêndio numa floresta, e sua única relação é com Delilah, outra vigia, que ele só ouve pelo rádio. O jogador escolhe as respostas de Henry **enquanto explora**: as opções aparecem por um tempo e somem, e não responder é uma possibilidade.

**[INFERÊNCIA]** O desenho transforma o diálogo em **mecânica de relação**: o que o jogador escolhe dizer (e o que escolhe calar) constrói o vínculo entre os dois personagens ao longo do jogo. O silêncio funciona em duas frentes. Para a narrativa, é uma resposta expressiva. Para a produção, é uma ramificação barata, porque a reação ao silêncio é uma fala só. E manter o jogador no controle durante a conversa preserva a sensação de estar sozinho no mundo, com uma voz no ouvido.

**Lição para a Vigília:** Sônia ocupa o mesmo lugar estrutural que Delilah, a única voz humana, mas com tom e intenção diferentes. A escolha do beat 7, com silêncio como opção, é a versão mínima desse desenho. O livro-razão de mistério (Capítulo 43) ganha uma dimensão nova: **o que Helena contou a Sônia**.

### GTA V — conversa interrompida e retomada

**[FATO PÚBLICO — observável jogando]** Em muitas missões de *Grand Theft Auto V*, os personagens conversam enquanto o jogador dirige até o destino. Se o jogador sai do carro, bate ou se afasta, a conversa é interrompida; ao voltar, ela recomeça, com frequência com uma fala de transição do tipo "como eu ia dizendo".

**[INFERÊNCIA]** O comportamento indica um sistema com **pontos de retomada**: a conversa não é um áudio longo, e sim uma sequência de falas com estado ("até onde já se falou"), interrompível por eventos de gameplay, com falas-ponte para disfarçar a costura. A jogadora sente uma conversa contínua; o sistema vê uma fila de nós com um cursor.

**Lição para a Vigília:** `bResumeAfterInterruption` e a retomada pelo nó cortado são a versão mínima disso. A fala-ponte ("Enfim... como eu dizia") fica para o exercício.

### Left 4 Dead — diálogo por regras sobre fatos

**[FATO PÚBLICO — palestra na GDC]** Na GDC de 2012, Elan Ruskin, da Valve, apresentou o sistema de diálogo contextual usado na série *Left 4 Dead* (no GDC Vault, a palestra se chama *AI-driven Dynamic Dialog through Fuzzy Pattern Matching. Empower Your Writers!*; os slides levam o título *Rule Databases for Contextual Dialog and Game Logic*). A ideia central: cada fala tem **critérios** sobre fatos do mundo (quem fala, o que aconteceu, onde, com quem por perto). Quando algo acontece, o jogo monta uma **consulta** com os fatos do momento, e a fala cujos critérios casam de forma **mais específica** é escolhida. Roteiristas acrescentam falas e critérios sem envolver programadores.

**[INFERÊNCIA]** É o caminho natural para os ***barks***: em vez de um grafo, um **banco de regras** consultado por evento. "Recarregando" genérico perde para "recarregando, e a Presença está perto", que perde para "recarregando, a Presença está perto e o parceiro foi pego". Variedade sem `if/else`, com especificidade como critério de desempate.

**Lição para a Vigília:** o grafo do rádio e o banco de regras dos barks são **dois sistemas**, com a mesma base: fatos como tags e condições como consultas. O desafio do capítulo constrói os barks dos vigias assim.

---

## Comparação com o desenvolvimento tradicional

| Diálogo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Conversa como grafo de nós | Workflow, BPMN, máquina de estados | O "processo" consulta fatos que mudam **enquanto** ele roda, e cada passo dura o tempo de uma fala |
| Condição como `FGameplayTagQuery` | Regras de negócio, feature flags | Quem escreve as condições é roteirista, não dev: o editor precisa tornar o erro difícil |
| Fila de falas com prioridade e expiração | Fila de mensagens com prioridade e TTL | Descartar é o comportamento desejado; não há DLQ |
| Retomada após interrupção | Offset/checkpoint de consumidor | Retomar exige uma costura que **soe** natural |
| `FText` e *String Tables* | `MessageSource`, `messages.properties` | O texto tem voz por idioma, com duração própria |
| Memória de "já dito" | Chave de idempotência | A repetição não corrompe dados: quebra a **ilusão** |

---

## Unreal Engine: o que existe e o que não existe

A Unreal **não traz** um sistema pronto de conversas ramificadas para gameplay: grafo, condições, escolhas e fila de rádio são responsabilidade do projeto (ou de um plugin). Ela traz as **peças**:

- **`FText`, *String Tables* e o painel de localização (*Localization Dashboard*).** Textos em `FText`, inclusive dentro de Data Assets, são coletados para tradução. Uma *String Table* é um asset de pares chave → texto, que pode ser **importado de CSV**. Uma propriedade `FText` no editor pode apontar para uma entrada de *String Table*. É o caminho para a dor 3: o roteirista edita uma planilha, e os nós de diálogo apontam para as chaves.
- **Legendas no *Sound Wave*.** Um *Sound Wave* pode carregar *cues* de legenda com tempo, e a engine sabe exibi-las. Funciona para casos simples, mas a Vigília controla a legenda pelo sistema de diálogo, porque ela precisa do nome do falante, do marcador de rádio e das escolhas.
- ***Dialogue Voice* e *Dialogue Wave*.** São assets da engine que associam uma fala a vozes e contextos (quem fala com quem) e a áudios por idioma. Resolvem o problema de "**qual** áudio tocar para esta fala", não o de "**qual** fala vem agora". Um projeto com dublagem em vários idiomas pode trocar o `USoundBase` do nó por um *Dialogue Wave* sem mudar o fluxo.
- **Gameplay Tags e Tag Queries** (Capítulo 23) para condições, **Data Assets** (Capítulo 13) para o conteúdo, **Sequencer** (Capítulo 49) para diálogos em cinemática, e ***Submixes* e MetaSounds** (Capítulo 52) para o filtro de rádio na voz de Sônia.

⚠️ Os detalhes de importação de CSV em *String Tables*, das legendas em *Sound Waves* e da configuração de *Dialogue Waves* variam entre versões: confira na documentação da sua versão antes de montar o pipeline do roteiro.

---

## Abordagens

| Critério | A. Roteiro linear (lista de falas) | **B. Grafo em Data Asset** | C. Linguagem externa (Ink, Yarn Spinner) ou ferramenta (articy:draft) | D. Editor de grafo próprio |
|---|---|---|---|---|
| **Complexidade** | Mínima | Baixa | Média: importador ou runtime, convenções | Alta: módulo de editor, Slate, serialização |
| **Performance** | Trivial | Trivial | Depende do runtime | Trivial |
| **Extensibilidade** | Sem condições nem escolhas | Condições, escolhas, saltos; novos campos fáceis | Muito alta: linguagens feitas para narrativa | Alta, no ritmo de quem mantém o editor |
| **Manutenção** | Fácil | Fácil até algumas centenas de falas | Duas ferramentas para manter em sincronia | Um projeto dentro do projeto |
| **Prototipação** | Rápida | Rápida | Rápida para roteiristas, lenta para integrar | Lenta no começo |
| **Adequação à Vigília** | Não basta: há variantes e escolhas | **Sim**: dezenas de falas, poucas escolhas, um autor | Excesso para o tamanho atual | Excesso |

**[FATO PÚBLICO]** *Ink* é a linguagem de narrativa interativa da inkle, usada em jogos como *80 Days* e *Heaven's Vault*. *Yarn Spinner*, criado pela Secret Lab, ficou conhecido pelo uso em *Night in the Woods*. A articy oferece uma ferramenta de design narrativo com integração para Unreal. Há integrações comunitárias de Ink para Unreal, e o Yarn Spinner tem uma integração oficial para Unreal, ainda em pré-lançamento. Verifique o estado de manutenção de qualquer uma antes de adotar.

**Decisão:** **B**. Um grafo mínimo em Data Asset resolve as dores do Interlúdio com poucas centenas de linhas de C++, usa ferramentas que o projeto já tem (Data Assets, tags, validação) e mantém o conteúdo localizável. **Quando migrar para C:** quando o roteiro passar de algumas centenas de falas, quando houver roteiristas que não abrem a Unreal, ou quando as conversas ganharem lógica que lista de nós no painel de detalhes torna ilegível. A migração é viável porque a **entrega** (fila, relógio, legendas, memória) não depende de onde o grafo é escrito: um importador de Ink alimentaria o mesmo subsistema.

---

## Implementação

### 1. Tags

Duas tags nativas novas, para o barramento (Capítulo 24):

```cpp
// VGGameplayTags.h (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Dialogue_Started);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Dialogue_Finished);

// VGGameplayTags.cpp (adições)
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Dialogue_Started,  "Event.Dialogue.Started");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Dialogue_Finished, "Event.Dialogue.Finished");
```

E dois ramos de tags **de conteúdo**, criados no editor e registrados em `docs/design/tags.md`: `Dialogue.*`, que identifica conversas (`Dialogue.Radio.S1.Breakers`), e `Narrative.Fact.*`, que nomeia os fatos (`Narrative.Fact.Document.Memo.Read`). O código não referencia nenhuma conversa nem fato específico.

### 2. Falante e conversa

```cpp
// Source/Vigilia/Narrative/VGSpeakerData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGSpeakerData.generated.h"

/** Quem fala: como aparece na legenda. Um asset por personagem (DA_Falante_Sonia). */
UCLASS(BlueprintType)
class VIGILIA_API UVGSpeakerData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Speaker")
    FText DisplayName;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Speaker")
    FLinearColor SubtitleColor = FLinearColor::White;

    /** Fala pelo rádio: legenda com marcador de rádio (o filtro de áudio vem no Cap. 52). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Speaker")
    bool bOverRadio = false;
};
```

```cpp
// Source/Vigilia/Narrative/VGDialogueData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "GameplayTagContainer.h"
#include "VGDialogueData.generated.h"

class USoundBase;
class UVGSpeakerData;

UENUM(BlueprintType)
enum class EVGDialoguePriority : uint8
{
    Ambient,   // comentário: espera, expira, cede a vez
    Normal,    // fala de beat
    Critical   // essencial à história: interrompe as outras e fala por cima da leitura
};

USTRUCT(BlueprintType)
struct FVGDialogueChoice
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Choice")
    FText Text;

    /** A escolha só aparece se a condição passar. Vazia = sempre. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Choice")
    FGameplayTagQuery Condition;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Choice", meta = (Categories = "Narrative.Fact"))
    FGameplayTagContainer GrantFacts;

    /** None = próximo nó do array; "End" = encerra; senão, o Id de um nó. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Choice")
    FName Next;
};

/** Uma fala. Os nós são lidos em ordem; condições pulam, Next salta, escolhas desviam. */
USTRUCT(BlueprintType)
struct FVGDialogueNode
{
    GENERATED_BODY()

    /** Único na conversa: alvo de saltos e chave da memória de "já dito". */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    FName Id;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    TObjectPtr<const UVGSpeakerData> Speaker;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node", meta = (MultiLine = "true"))
    FText Text;

    /** Simplificação: referência forte (o asset da conversa carrega os áudios). Com centenas de
     *  falas, trocar por TSoftObjectPtr com carga assíncrona ao enfileirar (Caps. 57 e 60). */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    TObjectPtr<USoundBase> Voice;

    /** Pausa antes da fala, em segundos (relógio de áudio). */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node", meta = (ClampMin = "0.0"))
    float DelayBefore = 0.0f;

    /** Se falhar, o nó é pulado. É assim que variantes substituem o Branch. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    FGameplayTagQuery Condition;

    /** Concedidos quando a fala termina de ser ouvida (interrupção não concede). */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node", meta = (Categories = "Narrative.Fact"))
    FGameplayTagContainer GrantFacts;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    bool bOnce = false;

    /** Depois da fala, sem escolhas visíveis. None = próximo do array; "End" = encerra. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    FName Next;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    TArray<FVGDialogueChoice> Choices;

    /** Com escolhas: 0 = espera para sempre; > 0 = após N s, o silêncio segue TimeoutNext. */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node", meta = (ClampMin = "0.0"))
    float ChoiceTimeout = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Node")
    FName TimeoutNext;
};

/** Uma conversa: o QUE se diz e em que fluxo. Imutável em runtime. */
UCLASS(BlueprintType)
class VIGILIA_API UVGDialogueData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    /** Identidade no barramento (Context de Event.Dialogue.*) e em objetivos (Cap. 45). */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Dialogue", meta = (Categories = "Dialogue"))
    FGameplayTag ConversationTag;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Dialogue")
    EVGDialoguePriority Priority = EVGDialoguePriority::Normal;

    /** Se não começar em N s (relógio de áudio), é descartada. 0 = nunca expira. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Dialogue", meta = (ClampMin = "0.0"))
    float MaxWait = 10.0f;

    /** Interrompida por outra mais importante: volta à fila e retoma do nó cortado. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Dialogue")
    bool bResumeAfterInterruption = true;

    /** A conversa inteira acontece no máximo uma vez. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Dialogue")
    bool bOnce = true;

    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Dialogue")
    TArray<FVGDialogueNode> Nodes;

    /** INDEX_NONE se não existir. */
    int32 FindNodeIndex(FName Id) const;

#if WITH_EDITOR
    virtual EDataValidationResult IsDataValid(class FDataValidationContext& Context) const override;
#endif
};
```

```cpp
// Source/Vigilia/Narrative/VGDialogueData.cpp
#include "Narrative/VGDialogueData.h"

#include "Narrative/VGDialogueRules.h"
#if WITH_EDITOR
#include "Misc/DataValidation.h"
#endif

int32 UVGDialogueData::FindNodeIndex(FName Id) const
{
    return Nodes.IndexOfByPredicate([Id](const FVGDialogueNode& Node) { return Node.Id == Id; });
}

#if WITH_EDITOR
EDataValidationResult UVGDialogueData::IsDataValid(FDataValidationContext& Context) const
{
    EDataValidationResult Result = Super::IsDataValid(Context);
    auto Error = [&](const FString& Message)
    {
        Context.AddError(FText::FromString(Message));
        Result = EDataValidationResult::Invalid;
    };
    auto CheckTarget = [&](FName Target, FName From)
    {
        if (!Target.IsNone() && Target != VGDialogueRules::EndId() && FindNodeIndex(Target) == INDEX_NONE)
        {
            Error(FString::Printf(TEXT("Nó '%s' aponta para '%s', que não existe."), *From.ToString(), *Target.ToString()));
        }
    };

    if (!ConversationTag.IsValid()) { Error(TEXT("ConversationTag vazia.")); }

    TSet<FName> Ids;
    for (const FVGDialogueNode& Node : Nodes)
    {
        if (Node.Id.IsNone() || Node.Id == VGDialogueRules::EndId() || Ids.Contains(Node.Id))
        {
            Error(FString::Printf(TEXT("Id '%s' vazio, reservado ou duplicado."), *Node.Id.ToString()));
        }
        Ids.Add(Node.Id);

        if (!Node.Speaker) { Error(FString::Printf(TEXT("Nó '%s' sem falante."), *Node.Id.ToString())); }
        CheckTarget(Node.Next, Node.Id);
        CheckTarget(Node.TimeoutNext, Node.Id);
        for (const FVGDialogueChoice& Choice : Node.Choices)
        {
            CheckTarget(Choice.Next, Node.Id);
        }
    }
    return Result;
}
#endif
```

### 3. Regras puras

O fluxo do grafo não precisa de mundo, áudio nem tempo, e por isso fica em funções puras, testáveis como as regras de objetivos do Capítulo 31.

```cpp
// Source/Vigilia/Narrative/VGDialogueRules.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGDialogueData.h"

/** Regras do fluxo de diálogo: sem mundo, sem áudio, testáveis. */
namespace VGDialogueRules
{
    /** Nome reservado de destino: "encerra a conversa". */
    FName EndId();

    /** Chave da memória de uma fala: "NomeDoAsset.IdDoNó". */
    FName MemoryKey(const UVGDialogueData& Data, const FVGDialogueNode& Node);

    /** Índice de destino. None = próximo do array; EndId = fim. INDEX_NONE = fim. */
    int32 ResolveNext(const UVGDialogueData& Data, int32 CurrentIndex, FName Next);

    /** Primeiro nó tocável a partir de StartIndex: condição passa e não é bOnce já dito. */
    int32 FindPlayable(const UVGDialogueData& Data, int32 StartIndex,
                       const FGameplayTagContainer& Facts, const TSet<FName>& Said);

    /** Índices (no array do nó) das escolhas visíveis com os fatos atuais. */
    TArray<int32> VisibleChoices(const FVGDialogueNode& Node, const FGameplayTagContainer& Facts);

    /** Só prioridade estritamente maior interrompe quem está falando. */
    bool ShouldPreempt(EVGDialoguePriority Speaking, EVGDialoguePriority Incoming);

    /** O áudio, se houver; nunca menos que o tempo de leitura da legenda. */
    float LineDuration(const FVGDialogueNode& Node);
}
```

```cpp
// Source/Vigilia/Narrative/VGDialogueRules.cpp
#include "Narrative/VGDialogueRules.h"

#include "Sound/SoundBase.h"

FName VGDialogueRules::EndId()
{
    static const FName End(TEXT("End"));
    return End;
}

FName VGDialogueRules::MemoryKey(const UVGDialogueData& Data, const FVGDialogueNode& Node)
{
    return FName(*FString::Printf(TEXT("%s.%s"), *Data.GetName(), *Node.Id.ToString()));
}

int32 VGDialogueRules::ResolveNext(const UVGDialogueData& Data, int32 CurrentIndex, FName Next)
{
    if (Next.IsNone())
    {
        return Data.Nodes.IsValidIndex(CurrentIndex + 1) ? CurrentIndex + 1 : INDEX_NONE;
    }
    return Next == EndId() ? INDEX_NONE : Data.FindNodeIndex(Next);
}

int32 VGDialogueRules::FindPlayable(const UVGDialogueData& Data, int32 StartIndex,
                                    const FGameplayTagContainer& Facts, const TSet<FName>& Said)
{
    if (StartIndex == INDEX_NONE)
    {
        return INDEX_NONE;
    }
    for (int32 i = StartIndex; i < Data.Nodes.Num(); ++i)
    {
        const FVGDialogueNode& Node = Data.Nodes[i];
        const bool bConditionOk = Node.Condition.IsEmpty() || Node.Condition.Matches(Facts);
        const bool bAlreadySaid = Node.bOnce && Said.Contains(MemoryKey(Data, Node));
        if (bConditionOk && !bAlreadySaid)
        {
            return i;
        }
    }
    return INDEX_NONE;
}

TArray<int32> VGDialogueRules::VisibleChoices(const FVGDialogueNode& Node, const FGameplayTagContainer& Facts)
{
    TArray<int32> Visible;
    for (int32 i = 0; i < Node.Choices.Num(); ++i)
    {
        const FGameplayTagQuery& Condition = Node.Choices[i].Condition;
        if (Condition.IsEmpty() || Condition.Matches(Facts))
        {
            Visible.Add(i);
        }
    }
    return Visible;
}

bool VGDialogueRules::ShouldPreempt(EVGDialoguePriority Speaking, EVGDialoguePriority Incoming)
{
    return Incoming > Speaking;
}

float VGDialogueRules::LineDuration(const FVGDialogueNode& Node)
{
    constexpr float CharsPerSecond = 15.0f; // referência de leitura confortável de legendas; ajuste no playtest
    constexpr float MinDuration = 1.5f;
    const float ReadTime = FMath::Max(MinDuration, Node.Text.ToString().Len() / CharsPerSecond);
    // Simplificação: supõe voz sem loop (GetDuration de um som em loop não é uma duração de fala).
    const float AudioTime = Node.Voice ? Node.Voice->GetDuration() : 0.0f;
    return FMath::Max(ReadTime, AudioTime);
}
```

### 4. O subsistema: o canal de voz

```cpp
// Source/Vigilia/Narrative/VGDialogueSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Narrative/VGDialogueData.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGDialogueSubsystem.generated.h"

class UAudioComponent;

/** O que a UI precisa de uma fala — e nada mais. */
USTRUCT(BlueprintType)
struct FVGDialogueLineView
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Dialogue")
    FText SpeakerName;

    UPROPERTY(BlueprintReadOnly, Category = "Dialogue")
    FLinearColor SpeakerColor = FLinearColor::White;

    UPROPERTY(BlueprintReadOnly, Category = "Dialogue")
    FText Text;

    UPROPERTY(BlueprintReadOnly, Category = "Dialogue")
    bool bOverRadio = false;

    UPROPERTY(BlueprintReadOnly, Category = "Dialogue")
    float Duration = 0.0f;
};

/** Uma conversa na fila ou em curso. */
USTRUCT()
struct FVGDialogueRequest
{
    GENERATED_BODY()

    UPROPERTY()
    TObjectPtr<const UVGDialogueData> Conversation;

    int32 StartIndex = 0;   // de onde começar (ou retomar)
    float QueuedAt = 0.0f;  // relógio de áudio
    uint64 Order = 0;       // desempate: quem pediu antes
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGDialogueLineSignature, const FVGDialogueLineView&, Line);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGDialogueChoicesSignature, const TArray<FText>&, Choices);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FVGDialogueSimpleSignature);

/**
 * O canal de voz da Vigília: uma conversa por vez, fila por prioridade, interrupção com
 * retomada, expiração, memória do que já foi dito. Mede o tempo no relógio de ÁUDIO.
 * Simplificação: os fatos narrativos moram aqui até o Capítulo 46 criar o dono definitivo.
 */
UCLASS()
class VIGILIA_API UVGDialogueSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void Tick(float DeltaTime) override;
    virtual TStatId GetStatId() const override;

    /** Pede uma conversa. false se ela já aconteceu (bOnce), já está pendente,
     *  ou não tem nada a dizer com os fatos atuais. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Dialogue")
    bool RequestConversation(const UVGDialogueData* Conversation);

    /** Índice entre as escolhas VISÍVEIS (a ordem em que a UI as mostrou). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Dialogue")
    void ChooseOption(int32 VisibleIndex);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Dialogue")
    bool IsSpeaking() const { return Current.Conversation != nullptr; }

    /** Simplificação (até o Cap. 46): o registro de fatos narrativos. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Narrative")
    void AddFact(FGameplayTag Fact);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Narrative")
    bool HasFact(FGameplayTag Fact) const { return Facts.HasTag(Fact); }

    FString DescribeForDebug() const;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Dialogue")
    FVGDialogueLineSignature OnLineStarted;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Dialogue")
    FVGDialogueSimpleSignature OnLineEnded;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Dialogue")
    FVGDialogueChoicesSignature OnChoicesPresented;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Dialogue")
    FVGDialogueSimpleSignature OnChoicesClosed;

private:
    enum class EStage : uint8 { Idle, Delay, Speaking, Choosing };

    void TryStartNext(float Now);
    void Begin(const FVGDialogueRequest& Request, float Now);
    void EnterNode(int32 Index, float Now);
    void StartLine(float Now);
    void FinishLine(float Now);
    void TakeBranch(FName Next, float Now);
    void Interrupt(float Now);
    void EndConversation();
    bool IsPlayerReading() const;
    const FVGDialogueNode* CurrentNode() const;

    UPROPERTY()
    TArray<FVGDialogueRequest> Queue;

    UPROPERTY()
    FVGDialogueRequest Current;

    int32 NodeIndex = INDEX_NONE;
    EStage Stage = EStage::Idle;
    float StageEndsAt = 0.0f;
    TArray<int32> VisibleChoices;
    TWeakObjectPtr<UAudioComponent> Voice;
    uint64 NextOrder = 0;

    FGameplayTagContainer Facts;     // Simplificação: até o Cap. 46
    TSet<FName> SaidLines;           // memória por fala (bOnce)
    TSet<FName> PlayedConversations; // memória por conversa (bOnce); persistência no Cap. 46
};
```

```cpp
// Source/Vigilia/Narrative/VGDialogueSubsystem.cpp (essencial)
#include "Narrative/VGDialogueSubsystem.h"

#include "Components/AudioComponent.h"
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"
#include "Narrative/VGDialogueRules.h"
#include "Narrative/VGSpeakerData.h"
#include "Player/VGPlayerController.h"

static TAutoConsoleVariable<bool> CVarVGDebugDialogue(
    TEXT("vg.Debug.Dialogue"),
    false,
    TEXT("Mostra na tela a conversa atual, o nó, a fila e os fatos narrativos."),
    ECVF_Default);

TStatId UVGDialogueSubsystem::GetStatId() const
{
    RETURN_QUICK_DECLARE_CYCLE_STAT(UVGDialogueSubsystem, STATGROUP_Tickables);
}

bool UVGDialogueSubsystem::RequestConversation(const UVGDialogueData* Conversation)
{
    if (!Conversation || (Conversation->bOnce && PlayedConversations.Contains(Conversation->GetFName())))
    {
        return false;
    }
    const bool bAlreadyPending = Current.Conversation == Conversation
        || Queue.ContainsByPredicate([Conversation](const FVGDialogueRequest& R) { return R.Conversation == Conversation; });
    if (bAlreadyPending || VGDialogueRules::FindPlayable(*Conversation, 0, Facts, SaidLines) == INDEX_NONE)
    {
        return false;
    }

    const float Now = GetWorld()->GetAudioTimeSeconds();
    FVGDialogueRequest Request;
    Request.Conversation = Conversation;
    Request.QueuedAt = Now;
    Request.Order = NextOrder++;
    Queue.Add(Request);

    if (Stage != EStage::Idle && VGDialogueRules::ShouldPreempt(Current.Conversation->Priority, Conversation->Priority))
    {
        Interrupt(Now); // a nova começa no próximo tick, pela fila
    }
    return true;
}

void UVGDialogueSubsystem::Tick(float DeltaTime)
{
    Super::Tick(DeltaTime);

    // Relógio de áudio: para com a pausa e NÃO é dilatado — o mesmo comportamento da voz (seção 44.5).
    const float Now = GetWorld()->GetAudioTimeSeconds();

    // Fala atrasada é pior que fala nenhuma.
    Queue.RemoveAll([Now](const FVGDialogueRequest& R)
    {
        return R.Conversation->MaxWait > 0.0f && Now - R.QueuedAt > R.Conversation->MaxWait;
    });

    if (Stage == EStage::Idle)
    {
        TryStartNext(Now);
    }
    else if (Now >= StageEndsAt)
    {
        switch (Stage)
        {
        case EStage::Delay:    StartLine(Now); break;
        case EStage::Speaking: FinishLine(Now); break;
        case EStage::Choosing: TakeBranch(CurrentNode()->TimeoutNext, Now); break; // o silêncio também é resposta
        default: break;
        }
    }

    if (CVarVGDebugDialogue.GetValueOnGameThread() && GEngine)
    {
        GEngine->AddOnScreenDebugMessage(static_cast<uint64>(GetUniqueID()), 0.0f, FColor::Cyan, DescribeForDebug());
    }
}

void UVGDialogueSubsystem::TryStartNext(float Now)
{
    if (Queue.IsEmpty())
    {
        return;
    }
    // Maior prioridade primeiro; empate: quem pediu antes.
    Queue.Sort([](const FVGDialogueRequest& A, const FVGDialogueRequest& B)
    {
        return A.Conversation->Priority != B.Conversation->Priority
            ? A.Conversation->Priority > B.Conversation->Priority
            : A.Order < B.Order;
    });
    // Lendo um documento, só o que é crítico fala por cima; o resto espera — e pode expirar.
    if (IsPlayerReading() && Queue[0].Conversation->Priority != EVGDialoguePriority::Critical)
    {
        return;
    }
    const FVGDialogueRequest Next = Queue[0];
    Queue.RemoveAt(0);
    Begin(Next, Now);
}

void UVGDialogueSubsystem::Begin(const FVGDialogueRequest& Request, float Now)
{
    Current = Request;
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Dialogue_Started, nullptr, nullptr,
                                           Current.Conversation->ConversationTag);
    EnterNode(VGDialogueRules::FindPlayable(*Current.Conversation, Current.StartIndex, Facts, SaidLines), Now);
}

void UVGDialogueSubsystem::EnterNode(int32 Index, float Now)
{
    if (Index == INDEX_NONE)
    {
        EndConversation();
        return;
    }
    NodeIndex = Index;
    Stage = EStage::Delay;
    StageEndsAt = Now + CurrentNode()->DelayBefore;
}

void UVGDialogueSubsystem::StartLine(float Now)
{
    const FVGDialogueNode& Node = *CurrentNode();
    if (Node.Voice)
    {
        Voice = UGameplayStatics::SpawnSound2D(this, Node.Voice); // 2D: o rádio está no ouvido de Helena
    }

    FVGDialogueLineView View;
    View.Text = Node.Text;
    View.Duration = VGDialogueRules::LineDuration(Node);
    if (Node.Speaker)
    {
        View.SpeakerName = Node.Speaker->DisplayName;
        View.SpeakerColor = Node.Speaker->SubtitleColor;
        View.bOverRadio = Node.Speaker->bOverRadio;
    }
    Stage = EStage::Speaking;
    StageEndsAt = Now + View.Duration;
    OnLineStarted.Broadcast(View);
}

void UVGDialogueSubsystem::FinishLine(float Now)
{
    const FVGDialogueNode& Node = *CurrentNode();
    // Só conta como dita, e só produz efeitos, depois de ouvida inteira.
    SaidLines.Add(VGDialogueRules::MemoryKey(*Current.Conversation, Node));
    Facts.AppendTags(Node.GrantFacts);
    OnLineEnded.Broadcast();

    VisibleChoices = VGDialogueRules::VisibleChoices(Node, Facts);
    if (VisibleChoices.IsEmpty())
    {
        TakeBranch(Node.Next, Now);
        return;
    }
    TArray<FText> Texts;
    for (const int32 ChoiceIndex : VisibleChoices)
    {
        Texts.Add(Node.Choices[ChoiceIndex].Text);
    }
    Stage = EStage::Choosing;
    StageEndsAt = Node.ChoiceTimeout > 0.0f ? Now + Node.ChoiceTimeout : TNumericLimits<float>::Max();
    OnChoicesPresented.Broadcast(Texts);
}

void UVGDialogueSubsystem::ChooseOption(int32 VisibleIndex)
{
    if (Stage != EStage::Choosing || !VisibleChoices.IsValidIndex(VisibleIndex))
    {
        return;
    }
    const FVGDialogueChoice& Choice = CurrentNode()->Choices[VisibleChoices[VisibleIndex]];
    Facts.AppendTags(Choice.GrantFacts);
    TakeBranch(Choice.Next, GetWorld()->GetAudioTimeSeconds());
}

void UVGDialogueSubsystem::TakeBranch(FName Next, float Now)
{
    if (Stage == EStage::Choosing)
    {
        OnChoicesClosed.Broadcast();
    }
    const int32 Target = VGDialogueRules::ResolveNext(*Current.Conversation, NodeIndex, Next);
    EnterNode(VGDialogueRules::FindPlayable(*Current.Conversation, Target, Facts, SaidLines), Now);
}

void UVGDialogueSubsystem::Interrupt(float Now)
{
    if (Voice.IsValid())
    {
        Voice->Stop();
    }
    if (Stage == EStage::Speaking) { OnLineEnded.Broadcast(); }
    if (Stage == EStage::Choosing) { OnChoicesClosed.Broadcast(); }

    if (Current.Conversation->bResumeAfterInterruption)
    {
        FVGDialogueRequest Resume = Current;
        Resume.StartIndex = NodeIndex; // a fala cortada repete do começo
        Resume.QueuedAt = Now;         // o prazo recomeça
        Queue.Add(Resume);             // Order original: volta à frente das de mesma prioridade
    }
    Current = FVGDialogueRequest();
    NodeIndex = INDEX_NONE;
    Stage = EStage::Idle;
}

void UVGDialogueSubsystem::EndConversation()
{
    const UVGDialogueData* Ended = Current.Conversation;
    PlayedConversations.Add(Ended->GetFName());
    Current = FVGDialogueRequest();
    NodeIndex = INDEX_NONE;
    Stage = EStage::Idle;
    // Anuncia depois de limpar: um ouvinte pode pedir a próxima conversa (reentrância, Cap. 4).
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Dialogue_Finished, nullptr, nullptr,
                                           Ended->ConversationTag);
}

bool UVGDialogueSubsystem::IsPlayerReading() const
{
    // Segundo uso desta consulta (o primeiro é o Diretor, Cap. 42). No terceiro, ela sobe para o controller.
    const AVGPlayerController* PC = Cast<AVGPlayerController>(GetWorld()->GetFirstPlayerController());
    return PC && PC->GetCurrentInputMode() == EVGInputMode::Reading;
}

const FVGDialogueNode* UVGDialogueSubsystem::CurrentNode() const
{
    return Current.Conversation && Current.Conversation->Nodes.IsValidIndex(NodeIndex)
        ? &Current.Conversation->Nodes[NodeIndex]
        : nullptr;
}

void UVGDialogueSubsystem::AddFact(FGameplayTag Fact)
{
    if (Fact.IsValid())
    {
        Facts.AddTag(Fact);
    }
}

// DescribeForDebug: conversa atual, nó e estágio; a fila (asset, prioridade, tempo de espera);
// os fatos (Facts.ToStringSimple()). Implementação direta — exercício da Parte 2.
```

### Explicação das decisões

- **`UTickableWorldSubsystem`**, como o subsistema de objetivos (Capítulo 31): um por mundo, tick barato quando ocioso. O tick é o "relógio" do canal; não há timers espalhados.
- **Um estágio explícito** (`Idle → Delay → Speaking → Choosing`) com um único prazo (`StageEndsAt`). É uma máquina de estados pequena, com transições centralizadas (Capítulo 4), e é ela que tira os `Delay` do Level Blueprint.
- **Relógio de áudio** (`GetAudioTimeSeconds`) para todos os prazos: fala, pausa, tempo-limite de escolha e expiração da fila. Um relógio só, declarado no comentário da classe (regra 5 do Capítulo 6).
- **Efeitos no fim da fala**, nunca no começo. Interrupção não concede fatos e não marca a fala como dita, então a retomada repete a fala inteira e os efeitos acontecem uma vez.
- **Interrupção pela fila.** `RequestConversation` só enfileira e, se for o caso, interrompe; quem decide o que toca é sempre `TryStartNext`. Há um único lugar onde conversas começam, e a regra de leitura vale para tudo.
- **`Event.Dialogue.Started` pode repetir** numa retomada; `Event.Dialogue.Finished` acontece uma vez. Quem precisa saber que uma conversa *aconteceu* (as quests do Capítulo 45, por exemplo) escuta `Finished`.
- **Escolhas sem nenhuma opção visível seguem `Next`**, como se não houvesse escolha. Uma escolha condicionada que não aparece não deve travar a conversa.
- **A UI recebe uma *view*** (`FVGDialogueLineView`), não o nó: a legenda não sabe de condições, fatos ou saltos (Capítulo 4, apresentação derivada).
- **Fatos no subsistema de diálogo** são a simplificação declarada do capítulo. Eles funcionam, são consultáveis de qualquer lugar (o que já alivia a dor 1) e não persistem. O Capítulo 46 os move para o dono certo e os salva.

### 5. Legendas e respostas

**A legenda** é o `WBP_Legenda` do Interlúdio, promovido: em vez de ser chamado pelo Level Blueprint, ele **escuta** o subsistema.

```text
WBP_Legenda (Event Construct)
  → Get World Subsystem (VGDialogueSubsystem)
  → Bind OnLineStarted → MostrarFala(Line)    -- nome na cor do falante, ícone de rádio se bOverRadio
  → Bind OnLineEnded   → Esconder
```

`WBP_RespostasRadio` faz o mesmo com `OnChoicesPresented` (mostra "1 — …", "2 — …" e uma barra de tempo) e `OnChoicesClosed`. Quem cria os dois widgets é o HUD (o Capítulo 55 formaliza a camada de UI).

**As respostas** entram pelo controller, como contexto sobreposto (seção 44.7):

```cpp
// AVGPlayerController.h (adições)
UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
TObjectPtr<UInputMappingContext> AnswerContext;   // IMC_RespostaRadio

UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
TObjectPtr<UInputAction> AnswerFirstAction;       // IA_Resposta1

UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
TObjectPtr<UInputAction> AnswerSecondAction;      // IA_Resposta2

UFUNCTION()
void HandleChoicesPresented(const TArray<FText>& Choices);

UFUNCTION()
void HandleChoicesClosed();

void HandleAnswerFirst()  { Answer(0); }
void HandleAnswerSecond() { Answer(1); }
void Answer(int32 VisibleIndex);
```

```cpp
// AVGPlayerController.cpp (adições)
// No BeginPlay, só no controller local:
if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
{
    Dialogue->OnChoicesPresented.AddDynamic(this, &AVGPlayerController::HandleChoicesPresented);
    Dialogue->OnChoicesClosed.AddDynamic(this, &AVGPlayerController::HandleChoicesClosed);
}

// No SetupInputComponent:
if (UEnhancedInputComponent* Input = Cast<UEnhancedInputComponent>(InputComponent))
{
    Input->BindAction(AnswerFirstAction, ETriggerEvent::Started, this, &AVGPlayerController::HandleAnswerFirst);
    Input->BindAction(AnswerSecondAction, ETriggerEvent::Started, this, &AVGPlayerController::HandleAnswerSecond);
}

void AVGPlayerController::HandleChoicesPresented(const TArray<FText>& Choices)
{
    // Contexto SOBREPOSTO, não um modo: a jogadora continua andando, olhando, fugindo.
    if (UEnhancedInputLocalPlayerSubsystem* Subsystem =
            ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
    {
        Subsystem->AddMappingContext(AnswerContext, 5); // acima da exploração (0), abaixo da leitura (10)
    }
}

void AVGPlayerController::HandleChoicesClosed()
{
    if (UEnhancedInputLocalPlayerSubsystem* Subsystem =
            ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
    {
        Subsystem->RemoveMappingContext(AnswerContext);
    }
}

void AVGPlayerController::Answer(int32 VisibleIndex)
{
    if (UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->ChooseOption(VisibleIndex);
    }
}
```

A prioridade 5 coloca as respostas **abaixo** da leitura: se a jogadora abrir um documento com as escolhas na tela, o `IMC_Leitura` (prioridade 10) fica por cima. Na prática isso é raro, porque a escolha só aparece numa conversa Critical, e o tempo-limite resolve o resto.

### 6. Depuração

- **`vg.Debug.Dialogue`** mostra a conversa atual, o nó, o estágio, a fila e os fatos.
- **Um cheat para pular para um estado** (dor 9, em parte):

```cpp
// UVGCheatManager (adição)
UFUNCTION(Exec)
void VGAddFact(const FString& TagName);

void UVGCheatManager::VGAddFact(const FString& TagName)
{
    const FGameplayTag Fact = FGameplayTag::RequestGameplayTag(FName(*TagName), /*ErrorIfNotFound*/ false);
    UVGDialogueSubsystem* Dialogue = GetWorld()->GetSubsystem<UVGDialogueSubsystem>();
    if (Fact.IsValid() && Dialogue)
    {
        Dialogue->AddFact(Fact);
    }
    else
    {
        UE_LOG(LogVigilia, Warning, TEXT("VGAddFact: tag '%s' não existe."), *TagName);
    }
}
```

Com `VGAddFact Narrative.Fact.Document.Memo.Read` no console, a variante "leu o memorando" do beat 7 pode ser testada sem procurar a chave, abrir a sala do engenheiro e ler o memorando.

### 7. Teste das regras

```cpp
// Source/Vigilia/Tests/VGDialogueRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Core/VGGameplayTags.h"
#include "Narrative/VGDialogueData.h"
#include "Narrative/VGDialogueRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGDialogueRulesTest, "Vigilia.Narrative.Dialogue.VariantsAndMemory",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGDialogueRulesTest::RunTest(const FString& Parameters)
{
    // As regras não ligam para o NOME do fato: uma tag nativa qualquer serve de "memorando lido".
    const FGameplayTag Memo = TAG_Status_Hidden;

    UVGDialogueData* Data = NewObject<UVGDialogueData>();
    FVGDialogueNode Ask;    Ask.Id = TEXT("Pergunta"); Ask.Condition = FGameplayTagQuery::MakeQuery_MatchTag(Memo);
    FVGDialogueNode Praise; Praise.Id = TEXT("Paineis");
    Praise.Condition = FGameplayTagQuery::MakeQuery_MatchNoTags(FGameplayTagContainer(Memo));
    FVGDialogueNode Close;  Close.Id = TEXT("Fim"); Close.bOnce = true;
    Data->Nodes = { Ask, Praise, Close };

    const FGameplayTagContainer NoFacts;
    const FGameplayTagContainer WithMemo(Memo);
    TSet<FName> Said;

    TestEqual(TEXT("Sem o fato, a pergunta é pulada"), VGDialogueRules::FindPlayable(*Data, 0, NoFacts, Said), 1);
    TestEqual(TEXT("Com o fato, a pergunta toca"), VGDialogueRules::FindPlayable(*Data, 0, WithMemo, Said), 0);

    const int32 AfterAsk = VGDialogueRules::ResolveNext(*Data, 0, NAME_None);
    TestEqual(TEXT("Depois da pergunta, o elogio é pulado"),
        VGDialogueRules::FindPlayable(*Data, AfterAsk, WithMemo, Said), 2);

    Said.Add(VGDialogueRules::MemoryKey(*Data, Data->Nodes[2]));
    TestEqual(TEXT("Fala bOnce já dita não volta"), VGDialogueRules::FindPlayable(*Data, 2, WithMemo, Said), INDEX_NONE);

    TestEqual(TEXT("End encerra"), VGDialogueRules::ResolveNext(*Data, 0, VGDialogueRules::EndId()), INDEX_NONE);
    TestEqual(TEXT("Salto por Id"), VGDialogueRules::ResolveNext(*Data, 0, TEXT("Fim")), 2);

    TestTrue(TEXT("Critical interrompe Normal"),
        VGDialogueRules::ShouldPreempt(EVGDialoguePriority::Normal, EVGDialoguePriority::Critical));
    TestFalse(TEXT("Normal não interrompe Normal"),
        VGDialogueRules::ShouldPreempt(EVGDialoguePriority::Normal, EVGDialoguePriority::Normal));
    return true;
}

#endif
```

O teste documenta a ideia do capítulo melhor do que qualquer parágrafo: **variante é condição, memória é conjunto de chaves, e nenhuma das duas precisa de `if/else` no conteúdo.**

---

## Projeto 6 — o rádio do Turno da Noite, migrado

🔁 A primeira etapa da refatoração do Interlúdio I. O conteúdo (as falas de Sônia) sobrevive; a cola muda de lugar.

### As conversas

| Asset | `ConversationTag` | Prioridade | Nós | Quem pede (por ora) |
|---|---|---|---|---|
| `DA_Dlg_S1_Chegada` | `Dialogue.Radio.S1.Arrival` | Normal | `Chegada1`; `Chegada2` (`DelayBefore` 8) | Level Blueprint, `BeginPlay` |
| `DA_Dlg_S1_Livro` | `Dialogue.Radio.S1.Logbook` | Normal | `Livro` (`DelayBefore` 2) | Pickup do livro |
| `DA_Dlg_S1_PortaSemEnergia` | `Dialogue.Radio.S1.PowerDoor` | Normal | `Porta` | Gatilho da porta |
| `DA_Dlg_S1_Disjuntores` | `Dialogue.Radio.S1.Breakers` | **Critical** | `Pergunta` (escolhas), `Admitiu`, `Duvidou`, `Calou`, `Paineis` (seção 44.3) | Puzzle resolvido |
| `DA_Dlg_S1_PosSusto` | `Dialogue.Radio.S1.AfterScare` | Normal | `Sinal` (`DelayBefore` 1) | Fim da cascata de luzes |
| `DA_Dlg_S1_Final` | `Dialogue.Radio.S1.Final` | Critical | `FinalMemo` (TEM `Memo.Read`), `FinalSemMemo` (NÃO TEM) | Cinemática final |

Mais dois falantes: `DA_Falante_Sonia` (`bOverRadio`, cor âmbar) e `DA_Falante_Helena` (usado só nas escolhas, que não são dubladas).

O texto mora numa *String Table*, `ST_Radio_Setor1`, com chaves como `S1.Chegada.1`. Os nós apontam para essas chaves. Para revisar o roteiro, exporte a tabela para CSV, edite e importe de volta: nenhum Blueprint é aberto.

### O que muda no Level Blueprint

Cada `Rádio("…")` vira `Request Conversation (DA_Dlg_…)`. As variáveis `bLeuLivro` e `bLeuMemorando` viram `Add Fact (Narrative.Fact.Document.Logbook.Read)` e `Add Fact (Narrative.Fact.Document.Memo.Read)` nos pickups. Os dois `Branch` sobre `bLeuMemorando` **desaparecem**: as variantes estão nas condições dos nós. O `Delay(8.0)` entre as duas falas da chegada também desaparece, porque virou `DelayBefore` no dado.

O Level Blueprint **ainda decide quando** cada conversa é pedida. Isso é a dor 5 (ordem de beats), que fica para o Capítulo 45. A fala final ainda depende do `Delay(6.0)` da cinemática (dor 6), que fica para o Capítulo 49.

### O inventário de dores, atualizado

| # | Dor | Situação depois do Cap. 44 |
|---|---|---|
| 3 | Texto de diálogo dentro do grafo | ✅ Resolvida: texto em Data Assets e *String Table*, localizável, revisável sem abrir o Blueprint |
| 10 | O rádio não sabe o que já disse | ✅ Resolvida: memória por fala e por conversa |
| 4 | Ramificação vira `Branch` espalhado | 🟡 Em parte: variantes são condições nos dados; consequências entre conversas e entre setores ficam para os Caps. 46–47 |
| 1 | Estado narrativo espalhado e invisível | 🟡 Em parte: os fatos saíram do Level Blueprint e são consultáveis de qualquer lugar, mas com dono provisório e sem persistência (Cap. 46) |
| 9 | Nada é testável | 🟡 Em parte: as regras têm teste e `VGAddFact` pula para um estado |
| 5, 6, 7, 2, 8, 12 | — | Pendentes (Caps. 45–49, 56–57) |

---

## Decisões arquiteturais

1. **Conteúdo, fluxo e entrega separados**: o texto em *String Tables*, o fluxo em Data Assets, a entrega no subsistema.
2. **Conversa como lista de nós com condições, saltos e escolhas**; o caminho padrão é a ordem do array.
3. **Variantes por condição, não por `Branch`**: a regra "pule o que não passa" aplicada a dados.
4. **O rádio é um canal único**, com fila por prioridade, interrupção com retomada e expiração.
5. **Relógio de áudio** para todo o tempo de fala.
6. **Efeitos e memória no fim da fala**, nunca no começo.
7. **Escolhas sem pausa**, como contexto de input sobreposto, com o silêncio como resposta.
8. **Fatos provisoriamente no subsistema de diálogo**, com a migração marcada para o Capítulo 46.
9. **Grafo em Data Asset agora; linguagem externa quando o roteiro crescer**, sem mudar a entrega.

---

## Armadilhas

- **Texto em `FString`**, ou montado por concatenação ("Você tem " + N + " cartuchos"). Para texto com variáveis, use `FText::Format`, que preserva a localização.
- **Conceder efeitos no começo da fala.** A jogadora não ouviu, mas o jogo age como se tivesse ouvido.
- **Medir a fala no tempo de jogo.** No hitstop e na câmera lenta, a legenda e a voz se desalinham.
- **Duas vozes no mesmo canal.** Sem fila, gatilhos próximos produzem falas sobrepostas.
- **Fila sem expiração.** A fala sobre a porta chega quando a jogadora já está do outro lado do mapa.
- **Escolha como modo.** Pausar o mundo para uma resposta de rádio desmonta a tensão e o tema.
- **Escolha com destino implícito.** Uma escolha sem `Next`, numa conversa cheia de saltos, cai no próximo nó do array, que pode ser a resposta errada. Use condições (seção 44.3) ou saltos explícitos.
- **Memória pelo texto.** Usar o texto da fala como chave de "já dito" quebra a memória na primeira revisão ou tradução. A chave é o `Id`.
- **Rádio falando por cima da leitura.** Documento e voz disputam a atenção, e a jogadora perde um dos dois.
- **Um diálogo que só funciona jogado do começo.** Sem um jeito de forçar fatos (cheat) e sem teste das regras, cada variante custa uma partida inteira.

---

## Exercício

**Parte 1 — dados e regras (1,5 h).** Implemente `UVGSpeakerData`, `UVGDialogueData` (com `IsDataValid`), `VGDialogueRules` e o teste. Rode o teste no *Session Frontend*. Crie uma conversa com um Id duplicado e outra com um salto para um nó inexistente, e confira as mensagens de validação.

**Parte 2 — o canal (2 h).** Implemente `UVGDialogueSubsystem`, incluindo `DescribeForDebug` e `vg.Debug.Dialogue`. Teste num nível vazio com três conversas de prioridades diferentes, pedidas por teclas de debug:
- duas Normal em sequência: a segunda espera;
- uma Critical no meio de uma Normal: interrompe, e a Normal retoma depois;
- uma Ambient com `MaxWait` de 3 s atrás de uma Normal longa: expira;
- `slomo 0.2` durante uma fala: a legenda continua sincronizada com a voz (se não houver voz, com o tempo real de leitura).

**Parte 3 — migração (1,5 h).** Migre o rádio do *Turno da Noite* conforme a tabela do Projeto 6, com a *String Table*. Remova do Level Blueprint todo texto de fala, os `Branch` sobre `bLeuMemorando` e o `Delay(8.0)`. Jogue o capítulo inteiro duas vezes: lendo e sem ler o memorando.

**Parte 4 — a escolha (1 h).** Implemente as respostas no controller e o `WBP_RespostasRadio` com a barra de tempo. Teste as três saídas do beat 7 (as duas respostas e o silêncio) usando `VGAddFact` para chegar à variante do memorando sem ler o documento. Registre no `DEVLOG.md`: o tempo-limite de 6 s é justo? O que as pessoas do playtest fizeram?

---

## Desafio — os barks dos vigias, por regras

Os vigias da Parte V disputam um token de *bark* (Capítulo 42), mas ainda não têm o que dizer. Construa um sistema de barks no espírito do estudo de caso de *Left 4 Dead*:

1. Um `UVGBarkSet` (Data Asset) com entradas `{ Evento (tag), Condição (FGameplayTagQuery), Falas (array), Cooldown }`.
2. Quando um vigia publica um evento (`Event.AI.TargetSpotted`, `Event.AI.Reloading`, `Event.AI.TargetLost`), o sistema monta os **fatos do momento** (as tags do vigia, a fase do Diretor, `Status.Suppressed`, aliados por perto) e escolhe a entrada **mais específica** que casa. Para medir especificidade, um critério simples é o número de tags exigidas pela condição.
3. Dentro da entrada, escolha uma fala **sem repetir as últimas N**.
4. O áudio é **3D**, na posição do vigia (`SpawnSoundAtLocation`). Por isso não passa pelo canal de rádio: barks não entram na fila de Sônia, mas respeitam o token de bark.

Responda no `DEVLOG.md`: por que barks e rádio são dois sistemas, e o que eles compartilham?

---

## Uso de IA

1. **Para revisar o grafo de uma conversa:**
   > "Aqui está uma conversa de jogo em forma de lista de nós (Id, falante, texto, condição sobre fatos, efeitos, próximo, escolhas). Encontre: nós inalcançáveis, combinações de fatos em que nenhuma fala toca, escolhas que levam ao mesmo resultado sem nenhuma diferença perceptível, e falas que contradizem fatos que a jogadora já pode ter. [conversa]"

2. **Para gerar variações de barks:**
   > "Escreva 12 variações curtas (até 6 palavras) de um vigia noturno de usina, em português brasileiro coloquial, para cada situação: avistou alguém, perdeu de vista, recarregando, ouviu um barulho. Tom: cansado e nervoso, não militar. Sem palavrões."
   *(Use como matéria-prima: escolha e reescreva com a voz da Vigília.)*

3. **Para revisar a fila e o relógio:**
   > "Revise este subsistema de diálogo da Unreal Engine 5 (código abaixo). Procure: condições de corrida entre interrupção e fim de fala, efeitos concedidos antes de a fala terminar, uso de relógio que sofre dilatação ou não pausa, broadcast antes de limpar o estado (reentrância) e vazamento de entradas na fila. [código]"

4. **Para preparar a localização:**
   > "Aqui está uma String Table de falas de rádio (chave, texto). Aponte textos que vão quebrar na tradução: concatenação, gênero e número presos ao português, gírias sem equivalente, falas longas demais para duas linhas de legenda em inglês."

**Cuidado específico:** a IA escreve diálogo plausível e genérico com muita facilidade, e falas genéricas são justamente o que mata o rádio de um jogo de terror. Use a IA para revisar e para gerar variações que você reescreve. A voz de Sônia é sua.

---

## Checklist

- [ ] Sei distinguir conversa ramificada, conversa de mão única, barks e narração, e o que cada uma exige.
- [ ] Modelo falas como dados, com Id estável, texto em `FText`, condição, efeitos e memória.
- [ ] Sei transformar um `Branch` de diálogo em falas com condições mutuamente exclusivas.
- [ ] Sei explicar a fila do rádio: prioridade, interrupção com retomada, expiração, leitura.
- [ ] Sei por que a fala é medida no relógio de áudio.
- [ ] Sei implementar escolhas sem pausar o jogo, com o silêncio como resposta.
- [ ] Sei o que a Unreal oferece (*String Tables*, *Dialogue Waves*, legendas de *Sound Wave*) e o que fica por conta do projeto.
- [ ] Migrei o rádio do *Turno da Noite*, e as dores 3 e 10 estão resolvidas.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Localization** (painel de localização, coleta de texto, *String Tables*), **Dialogue Voices and Waves** e **Subtitles**.
- **GDC Vault** (gdcvault.com): a palestra de Elan Ruskin sobre diálogo contextual baseado em regras (GDC 2012) e a trilha de narrativa (*Game Narrative Summit*), com postmortems de sistemas de diálogo.
- **Ink** (documentação da inkle, em inklestudios.com) e **Yarn Spinner** (yarnspinner.dev): mesmo sem adotar, ler como linguagens feitas para narrativa resolvem condições, variações e escolhas ajuda a desenhar o seu próprio sistema.
- **Game Accessibility Guidelines** (gameaccessibilityguidelines.com): a seção sobre legendas.

---

➡️ **Próximo:** [Capítulo 45 — Quest Systems](cap-45-quest-systems.md)

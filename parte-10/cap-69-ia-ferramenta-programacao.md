# PARTE X — IA Generativa

*Projeto: a Vigília com IA generativa — ferramentas de produção (Caps. 69–72) e um protótipo isolado de rádio híbrido (Caps. 73–74), fora do build de release*

---

# Capítulo 69 — IA como ferramenta de programação

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar, com um modelo mental de engenheiro, **por que** um assistente de IA erra do jeito que erra, e por que esse jeito é perigoso em Unreal;
- distinguir três modos de uso (**conversa**, **assistente na IDE** e **agente de programação**) e o que cada um vê, faz e arrisca;
- aplicar um *workflow* por tarefa: estudar um conceito, analisar código, explicar uma API, investigar um erro, prototipar, revisar arquitetura, criar testes, documentar, refatorar, analisar performance e aprender uma ferramenta desconhecida;
- reconhecer as quatro famílias de erro em código Unreal gerado por IA, incluindo a mais cara: **código que compila e está errado**;
- montar uma escada de verificação (compilar, testar, instrumentar, ler o código da engine) e decidir qual degrau cada afirmação exige;
- escrever o **arquivo de contexto** e o **protocolo de uso de IA** da Vigília, e um script que compila e roda os testes sem abrir o editor.

---

## Contexto

Desde o Capítulo 1, todo capítulo terminou com uma seção **Uso de IA**. A Introdução (seção 9.3) deu a regra geral: usar a IA para **acelerar o entendimento, não para pular o entendimento**. A spec do livro foi mais dura: IA generativa vem **depois** dos fundamentos e nunca como atalho para não aprender Game AI, arquitetura ou a engine. Esta parte cumpre a promessa de sistematizar o que aquelas seções praticaram de forma solta.

Ela se divide em duas metades, e convém separá-las desde já:

```text
 PARTE X — IA GENERATIVA
 ├── IA como FERRAMENTA  (fora do jogo: no seu fluxo de trabalho)
 │     69 programação · 70 game design · 71 narrativa · 72 Game AI
 │
 └── IA como COMPONENTE  (dentro do jogo: em runtime, diante da jogadora)
       73 LLMs no jogo · 74 NPC híbrido · 75 limitações e arquitetura híbrida
```

E convém separar também os dois sentidos de "IA" que convivem no livro:

| | **IA generativa** | **Game AI** |
|---|---|---|
| Exemplos | LLMs, geração de imagem, *embeddings*, RAG, agentes | FSM, Behavior Trees, Utility, EQS, *pathfinding*, planejadores |
| O que produz | Texto (código, prosa, JSON) plausível | Decisões de agentes, a cada frame |
| Determinismo | Baixo: a mesma pergunta pode ter respostas diferentes | Alto: o mesmo estado produz a mesma decisão |
| Onde roda neste livro | No seu computador de trabalho (69–72); num protótipo isolado do jogo (73–74) | Dentro do jogo, sempre (Parte V) |

Este capítulo trata da primeira metade, no seu ponto mais cotidiano: programar.

Há um motivo concreto para levar o assunto a sério, e ele está no próprio livro. **Este livro foi produzido com IA generativa a partir de uma especificação detalhada e depois revisado.** A revisão técnica de 2026-11-03 (o arquivo `revisao-2026-11-03.md`, na raiz do repositório) registrou que o código da Vigília existia só no texto e que **nada tinha sido compilado**. E encontrou erros que pareciam corretos: uma função que deveria ter pinos de execução virava nó puro, tokens de ataque que vazavam, um canal de colisão que apagava os *headshots*. O estudo de caso deste capítulo é esse relatório. A lição dele vale para todo código que você vai receber de uma IA, inclusive o deste livro: **a verificação é sua**.

> Se você chegou aqui logo depois da Parte I, como a Introdução sugere, leia as seções 69.1 a 69.5 e o protocolo do projeto. Os exemplos de Unreal fazem mais sentido depois da Parte II; volte a eles quando chegar lá.

---

## 69.1 Um modelo mental do assistente

Um modelo de linguagem (*LLM*, *large language model*) é, para um engenheiro, uma função que recebe um **contexto** (texto) e produz uma **continuação plausível**, um pedaço (*token*) de cada vez. Ele aprendeu o que é plausível lendo uma quantidade enorme de texto público: documentação, fóruns, repositórios, livros. Quatro consequências práticas saem daí.

1. **Plausível não é verdadeiro.** O modelo não tem um compilador dentro dele nem acesso ao seu `Engine/Source`. Quando ele escreve `UGameplayStatics::SpawnSound2D`, é porque essa sequência é plausível depois do que veio antes, e não porque ele conferiu a assinatura. Na maior parte das vezes, plausível e verdadeiro coincidem. O problema é que **o tom de voz é o mesmo nos dois casos**.

2. **Frequência pesa mais que atualidade.** Há muito mais código de UE4 na internet do que de qualquer versão específica de UE5, e muito mais C++ padrão do que C++ da Unreal. Num domínio de cauda longa como a Unreal, o modelo tende ao que é **comum**, não ao que é **correto para a sua versão**. É por isso que os capítulos anteriores alertaram para PhysX no lugar de Chaos (Capítulo 15), input legado no lugar de Enhanced Input (Capítulo 14) e classes de *camera shake* do UE4 (Capítulo 18).

3. **O contexto é tudo o que ele sabe sobre você.** O modelo não conhece o seu projeto, a sua versão da engine nem as decisões do seu README, a menos que você as coloque no contexto, colando o texto ou dando a um agente acesso ao repositório. Pergunta sem contexto recebe resposta genérica, e resposta genérica para um jogo de terror de 15 minutos é arquitetura de MMO.

4. **Ele não lembra entre sessões**, a não ser que a ferramenta guarde algo para ele. A memória de longo prazo do projeto tem de estar **em arquivos**: README, documentos de design, o `DEVLOG.md`, e o arquivo de contexto que este capítulo cria.

> 🌉 **Ponte:** pense num colega muito rápido, que leu todas as respostas de fórum já escritas sobre a Unreal e nunca rodou o seu build. Ele é ótimo para lembrar nomes, propor caminhos e revisar com uma lista na mão; é perigoso quando afirma como a sua versão se comporta.
>
> 🧱 **Onde a ponte cai:** um colega diz "não sei" e muda de tom quando está inseguro. O modelo raramente faz isso por conta própria, e a taxa de erro dele não aparece na resposta. Você precisa **pedir** a incerteza ("liste o que você não tem certeza") e, mesmo assim, verificar.

---

## 69.2 Três modos de uso: conversa, IDE e agente

A mesma IA se comporta de modos diferentes conforme o que ela **vê** e o que ela **pode fazer**.

| Modo | O que vê | O que faz | Risco típico | Melhor para |
|---|---|---|---|---|
| **Conversa** | O que você cola | Explica, compara, revisa, discute | Resposta genérica por falta de contexto; código copiado sem leitura | Estudar, investigar erros, revisar desenhos |
| **Assistente na IDE** | O arquivo aberto e arquivos próximos | Completa linhas, sugere trechos, responde sobre o código à vista | Aceitar com Tab uma linha plausível que você não leu | Código repetitivo, nomes, *boilerplate* conhecido |
| **Agente de programação** (no terminal ou na IDE) | O repositório inteiro, a saída de comandos | Lê arquivos, roda build e testes, edita vários arquivos em sequência | Diffs grandes demais para revisar; ações com efeito colateral; "pronto" sem prova | Tarefas mecânicas com critério de pronto verificável |

### O agente

Um **agente de programação** é um modelo num laço: ele recebe uma tarefa, planeja, lê arquivos, executa comandos (busca, build, testes), observa o resultado e continua até julgar que terminou. Existem agentes que rodam no terminal e agentes integrados à IDE. O desenho é o mesmo, e o que muda é a interface.

Para o seu trabalho, a pergunta que importa é **o que o agente consegue verificar sozinho** num projeto Unreal:

| Consegue verificar | Não consegue verificar |
|---|---|
| Se o C++ compila (UHT, compilador, linker), rodando o build pela linha de comando | Se um Blueprint está ligado certo: assets `.uasset`/`.umap` são binários |
| Se os testes de automação passam, rodando o editor sem interface | Se o *game feel* está bom, se a legenda está legível, se o susto assusta |
| Se um nome existe no código da engine, buscando no `Engine/Source` | Se um asset referencia o que deveria (sem abrir o editor) |
| Se o diff respeita as convenções escritas no arquivo de contexto | O que acontece no PIE com a jogadora andando pelo nível |

A coluna da direita é sua. A da esquerda só é do agente se você der a ele **um comando de verificação**: sem isso, ele não tem como saber se acertou, e "terminei" vira só uma frase. Por isso o projeto deste capítulo inclui um script que compila e roda os testes.

O laço de trabalho saudável com um agente se parece com o de qualquer revisão de código, só que mais curto:

```text
 você: tarefa + critério de pronto + restrições (arquivo de contexto)
   │
   ▼
 agente: plano curto ──► você aprova ou corrige o plano
   │
   ▼
 agente: mudança PEQUENA ──► build ──► testes ──► relatório (o que mudou, o que NÃO verificou)
   │
   ▼
 você: lê o diff inteiro, roda no PIE o que o agente não pode ver, commit
```

Três cuidados específicos de jogos:

- **Builds longos mudam a economia.** Um agente que "tenta e vê" funciona bem quando o ciclo leva segundos. Na Unreal, um build incremental leva bem mais que isso, e um build completo leva muito mais. Peça o **plano** antes e mudanças pequenas, para que cada ciclo valha o tempo.
- **Assets não são texto.** O agente não deve criar nem editar `.uasset`, e não deve "descrever" um Blueprint que não viu. Quando a tarefa envolve conteúdo, o agente escreve o C++ e uma **lista de passos no editor** para você executar.
- **Permissões.** Um agente com acesso ao terminal pode apagar, sobrescrever, publicar. Dê a ele o mínimo: sem `push`, sem acesso a credenciais, de preferência numa *branch* ou numa cópia de trabalho isolada.

---

## 69.3 Workflows por tarefa

A spec pediu "workflows melhores" do que "peça para a IA gerar o código". A tabela abaixo resume um padrão por tarefa. O padrão é sempre o mesmo, em três tempos: **contexto → pedido que produz algo verificável → verificação**.

| Tarefa | Pedido que funciona | Verificação | Armadilha |
|---|---|---|---|
| **Estudar um conceito** | "Explique X; depois me faça três perguntas para ver se entendi; proponha um experimento de 15 min que mostraria X acontecendo" | O experimento (uma sonda, um log, um nível de teste) | Ler a explicação e sentir que aprendeu |
| **Analisar código** | Código + intenção: "trace o fluxo de A até B, liste as suposições que este código faz sobre ordem e tempo de vida" | Depurador, *breakpoints*, logs | Pedir "o que este código faz" sem dizer o que ele **deveria** fazer |
| **Explicar uma API** | "Assinatura, header, em que versão existe, e um uso real dentro da própria engine" | Abrir o header; buscar usos no `Engine/Source` | Aceitar a assinatura sem abrir o header |
| **Investigar um erro** | Log **completo**, fase (UHT, compilação, link, runtime), o que mudou desde o último build bom; "hipóteses em ordem, cada uma com um teste que a descarta" | Rodar os testes das hipóteses, uma a uma | Colar só a última linha do log |
| **Prototipar** | "A menor versão que demonstra X, descartável, num mapa em `/Game/Developers/` ou num programa C++ isolado" | Jogar o protótipo | Promover o protótipo a código de produção sem reescrever |
| **Revisar arquitetura** | Desenho + **forças do jogo** (orçamento de frame, designers editando dados, reentrância, save) + "procure riscos, não me dê outro desenho" | Comparar com as decisões firmadas do projeto | Pedir "projete a arquitetura" e receber camadas corporativas (Capítulo 6) |
| **Criar testes** | Regras puras (`VG…Rules`) + "liste casos de borda numa tabela; eu preencho o esperado" | Teste de mutação: quebre o código e veja o teste falhar | Testes que só confirmam o comportamento atual, certo ou errado |
| **Documentar** | Código + "rascunho de `docs/design/x.md`: responsabilidade, contrato, quem chama, o que não faz" | Ler contra o código; o documento vira contrato | Documentação que descreve o código que a IA imaginou |
| **Refatorar** | Testes primeiro; "plano em passos pequenos, cada um compilável"; um passo por vez | Testes verdes a cada passo; diff lido | Refatoração grande num passo só |
| **Analisar performance** | **Dados** (captura do Unreal Insights, `stat unit`, `stat game`) + "o que estes números sugerem e que medição confirmaria" | Medir de novo depois da mudança | Pedir otimização a partir de uma impressão ("está lento") |
| **Aprender uma ferramenta** | "Um tour de 20 minutos pelo Visual Logger para responder à pergunta Y; o primeiro experimento" | Fazer o experimento na sua versão | Seguir caminhos de menu que mudaram (Capítulo 7) |

Quatro dessas linhas merecem um exemplo.

**Estudar.** A pior forma de estudar com IA é pedir uma explicação e lê-la. A explicação é fluente, e fluência dá a sensação de entendimento. A forma boa inverte o papel: você explica e a IA procura as lacunas ("vou explicar por que a ordem de `BeginPlay` entre atores não é garantida; aponte o que estou errando, sem me dar a resposta"). E toda explicação termina num **experimento**: o `AVGLifecycleProbe` do Capítulo 8 é o modelo. Quando a IA e o log discordam, o log vence.

**Investigar um erro.** Um erro de link na Unreal (`unresolved external symbol`) quase sempre é uma dependência faltando no `Build.cs`. Um erro do UHT é sintaxe de reflexão. Um *crash* em runtime com `nullptr` dentro de um callback é tempo de vida. A IA é muito boa em produzir **hipóteses ordenadas**, e esse é o pedido certo. O pedido errado é "corrija", porque a correção sem diagnóstico some com o sintoma e deixa a causa.

**Criar testes.** Peça casos, não asserções. A IA é excelente em listar bordas que você esqueceria: lista vazia, valor exatamente no limiar, dois eventos no mesmo frame, uma conversa interrompida no último nó. O **valor esperado** de cada caso é decisão de design e fica com você. Uma IA que escreve o esperado olhando o código produz um teste que confirma o comportamento atual, inclusive os bugs.

**Refatorar.** A sequência é a do Capítulo 45 ao mover o rádio para a quest, ou do Capítulo 46 ao extrair o dono dos fatos: teste que fixa o comportamento, plano em passos, um passo por commit, 🔁 registrado no `DEVLOG.md`. A IA acelera cada passo, e a disciplina do passo pequeno é o que a torna segura.

---

## 69.4 Como a IA erra em Unreal

Os erros de código Unreal gerado por IA caem em quatro famílias, da mais fácil à mais difícil de pegar.

**1. API inventada.** Uma função, um especificador de `UPROPERTY`, uma CVar ou um comando de console que não existe, com nome perfeitamente plausível. O compilador pega a maioria, e o console pega as CVars (o autocompletar mostra as que existem, Capítulo 3). É a família **barata**: o custo é um build.

**2. Versão misturada.** A API existe, mas em outra versão. Alguns exemplos reais do ciclo UE4→UE5: `FTicker` virou `FTSTicker`; consultas ao Asset Registry por nome de classe (`FName`) passaram a usar o caminho da classe (`FTopLevelAssetPath`); ponteiros crus em membros de `UObject` passaram a ser `TObjectPtr`; o input legado deu lugar ao Enhanced Input. O compilador pega parte disso. A outra parte compila com *warning* de depreciação, ou compila e se comporta diferente.

**3. Convenção de C++ padrão no lugar da engine.** `std::vector<UObject*>`, `std::shared_ptr` segurando um ator, ponteiro cru para `UObject` num membro sem `UPROPERTY`, que o *garbage collector* não enxerga e que, por isso, aponta para um objeto destruído depois de uma coleta (Capítulo 11). Compila, roda, e quebra de forma intermitente.

**4. Código que compila e está errado.** A família cara. O código respeita a sintaxe, as APIs existem, e o comportamento está errado porque viola um **contrato implícito** da engine: uma *flag* que precisa estar ligada, uma ordem de inicialização, uma thread, um relógio, uma regra de memória. Nem o compilador nem uma leitura rápida pegam esses erros. Eles aparecem no PIE, às vezes só com dois agentes, às vezes só depois de dois combates.

A tabela de armadilhas do guia de produção deste livro é, quase inteira, da família 4. O estudo de caso a seguir mostra por quê.

---

## Estudo de caso: os erros plausíveis deste livro

**Fonte:** `revisao-2026-11-03.md`, o relatório da revisão técnica dos Capítulos 1–43, feita por auditoria automatizada e leitura integral. Nenhum trecho tinha sido compilado. Os erros abaixo foram corrigidos nos capítulos, e cada um ensina um contrato da engine.

| Erro | Por que parecia certo | O que acontecia | Que verificação pegaria |
|---|---|---|---|
| `UFUNCTION(BlueprintCallable)` numa função `const` (Cap. 13) | `const` é boa prática em C++ para funções que não mudam o objeto | A engine trata função `const` chamável por Blueprint como **pura**: o nó perde os pinos de execução e é reavaliado a cada fio. A correção é `BlueprintPure = false` | Abrir o nó no editor; ler a regra no header de especificadores |
| Memória de nó de BT com valor inicial no `struct` (Cap. 40) | `int32 CurrentIndex = INDEX_NONE;` é como se inicializa um membro | A memória de nó chega **zerada, não construída**: o índice começava em 0. A correção é `InitializeMemory` com `InitializeNodeMemory<T>` | Teste com o service recém-ativado; ler `BTNode.h` |
| Service de token sem `bNotifyCeaseRelevant` (Caps. 37 e 42) | `OnCeaseRelevant` está sobrescrito; parece que será chamado | Sem a flag, nunca é chamado. Cada ataque prende um token e, depois de dois combates, ninguém mais ataca | Teste com **vários agentes** e vários combates; ler o construtor de `UBTService` |
| Vigia mira girando a control rotation (Cap. 30) | O jogador mira assim | O `AAIController` reescreve a control rotation a cada tick; o vigia não mira. A correção é `SetFocus` | PIE com o vigia; ler `AAIController::UpdateControlRotation` |
| Canal de colisão `Weapon` com resposta padrão Block (Cap. 27) | "O tiro deve bater em tudo" | A **cápsula** do personagem bloqueia antes da malha: somem *headshot*, nome do osso, reação direcional | Tiro de teste com `vg.Debug` ligado, olhando o osso atingido |
| `TSet<TWeakObjectPtr>.Remove(nullptr)` para limpar mortos (Cap. 32) | Um ponteiro fraco obsoleto "é nulo" | Ele **compara** diferente de `nullptr`; nada é removido e a onda nunca termina | Teste da regra com um ator destruído |
| Porta que lê o estado do disjuntor no `BeginPlay` (Cap. 19) | "No começo do jogo, leia o estado" | A ordem de `BeginPlay` **entre atores** não é garantida; às vezes a porta trancava para sempre | Repetir o PIE várias vezes; mover o estado inicial para `PostInitializeComponents` |

Repare no padrão. **Nenhum desses erros seria pego pelo compilador**, e quase todos passam numa leitura atenta de quem não conhece o contrato. Eles se concentram onde a engine tem **regras que não aparecem na assinatura**: *flags* de notificação, ciclo de vida, inicialização de memória, quem escreve o quê a cada tick.

Há uma segunda lição, sobre como esses erros foram encontrados. A revisão não perguntou "este código está certo?". Ela leu cada parte procurando **classes conhecidas de erro**: memória de nó, *flags*, relógios, reentrância. Uma IA revisora funciona do mesmo jeito: mal com "revise", bem com "procure especificamente X, Y e Z". É por isso que o guia de produção deste livro tem uma seção de armadilhas que todo autor lê antes de escrever, e é por isso que o arquivo de contexto da Vigília (seção de implementação) também tem uma.

**Lição para a Vigília:** a sua lista de armadilhas é um ativo. Cada bug que custou uma tarde vira uma linha no arquivo de contexto, e cada revisão (sua ou de uma IA) começa por ela.

---

## 69.5 Verificação: o ciclo que fecha

Verificar não é um ato só. É uma escada, e cada afirmação exige um degrau mínimo.

```text
 6  Playtest ............ "isto produz a sensação X"
 5  Documentação oficial  "a Epic recomenda Y"                 (pode estar atrasada)
 4  Código da engine .... "esta função faz Z, nesta thread"    (a fonte da verdade)
 3  PIE instrumentado ... "no jogo, acontece W"                (CVars vg.Debug.*, Visual Logger, sondas)
 2  Teste automatizado .. "a regra devolve V para estas entradas"
 1  Compila ............. "a API existe e os tipos batem"       (necessário, nunca suficiente)
```

| Afirmação | Evidência mínima |
|---|---|
| "Esta função existe e recebe estes parâmetros" | Header da sua versão (degrau 1 ou 4) |
| "Este callback roda na game thread" | Código da engine **e** um `check(IsInGameThread())` no callback (4 + 3) |
| "Este service libera o token quando o ramo é abortado" | Teste com vários agentes ou PIE com dois combates (3) |
| "Esta regra de diálogo pula a variante certa" | Teste de regras puras (2) |
| "Esta CVar existe" | Autocompletar do console (3) |
| "Este valor de recuo parece bom" | Playtest (6) |

### Ler o código da engine

O código-fonte da Unreal é público para quem tem conta na Epic: o repositório no GitHub exige associar a conta da Epic à do GitHub (confira o procedimento atual na documentação oficial, em "Downloading Unreal Engine Source Code"). Mesmo sem o repositório, a instalação pelo Launcher traz os headers e boa parte do código em `Engine/Source`, e a IDE navega até eles com "ir para a definição".

Três hábitos tornam essa leitura produtiva:

- **Leia o comentário do header antes do corpo.** Muitas regras estão ali: o Capítulo 44 mandou ler, em `World.h`, o comentário de cada relógio.
- **Procure como a própria engine usa a API.** Um uso interno é a melhor documentação que existe: mostra a ordem das chamadas, as *flags* que alguém precisou ligar e o tratamento de erro que alguém achou necessário.
- **Peça à IA para ler com você, não por você.** Cole o trecho do header e pergunte "que contrato este comentário impõe a quem chama?". Agora a resposta está ancorada em texto real.

### Rodar os testes sem abrir o editor

O framework de automação da Unreal (o mesmo do *Session Frontend*) pode rodar pela linha de comando, com o editor sem interface. É isso que transforma "o agente diz que terminou" em "os testes passaram". O script está na seção de implementação.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Revisão de código por IA | Linters, análise estática, revisão por pares | A IA não executa nada; o linter pelo menos é determinístico. Use os dois |
| Agente com comando de verificação | Bot de CI que roda a suíte em cada PR | O build da Unreal é longo, e boa parte do jogo (assets, *feel*) não tem teste automatizável |
| API alucinada | Resposta antiga de fórum com API depreciada | O modelo **recombina**: a API inventada pode não existir em versão nenhuma |
| Arquivo de contexto | `CONTRIBUTING.md`, ADRs, guia de estilo | É lido por uma máquina que segue o texto ao pé da letra: o que não está escrito não existe |
| Código que compila e está errado | Bug de concorrência que passa nos testes | Em jogos, o contrato violado costuma ser de **tempo** (tick, ordem, thread) e só aparece jogando |
| Escada de verificação | Pirâmide de testes | O topo (playtest) não automatiza, e é onde mora metade das perguntas que importam |

---

## Unreal Engine: o que ajuda e o que atrapalha

**O que ajuda:**

- **O código-fonte está disponível.** Poucas plataformas permitem conferir a verdade tão de perto. Use isso.
- **Headers comentados**, com as regras de muitos sistemas escritas ali.
- **Framework de automação** (`IMPLEMENT_SIMPLE_AUTOMATION_TEST`), rodável sem interface, e as regras puras do projeto (`VGDialogueRules`, `VGQuestRules`, `VGUtility`), que existem justamente para serem testáveis sem mundo.
- **Unreal Build Tool pela linha de comando**, logs detalhados e Live Coding para ciclos curtos.
- **Ferramentas de observação** já usadas no livro: CVars `vg.Debug.*`, Gameplay Debugger, Visual Logger, Unreal Insights.

**O que atrapalha:**

- **Assets binários.** Blueprints, Behavior Trees, EQS e níveis não são texto. Ao copiar nós de Blueprint, o editor coloca no *clipboard* uma serialização em texto. Dá para colá-la numa conversa, mas ela é verbosa e frágil, e o Capítulo 12 já avisou que IAs não "veem" Blueprints.
- **Macros e reflexão** (`UCLASS`, `GENERATED_BODY`, UHT), onde o conhecimento genérico de C++ engana.
- **Mudança constante entre versões**, e muito material de UE4 na internet.
- **Ciclos longos de build**, que encarecem o "tentar e ver".

---

## Abordagens

Como integrar a IA ao trabalho no projeto:

| Critério | A. Só conversa | B. Conversa + assistente na IDE | C. Agente com protocolo |
|---|---|---|---|
| **Complexidade** | Nenhuma | Baixa | Média: arquivo de contexto, permissões, script de verificação |
| **Performance** (velocidade de trabalho) | Baixa: copiar e colar | Alta em código local | Alta em tarefas mecânicas multi-arquivo |
| **Extensibilidade** | — | — | Cresce com o arquivo de contexto e os scripts |
| **Manutenção** (risco de erro silencioso) | Médio | Alto: aceitar sem ler | Controlado, **se** houver diff pequeno, build e testes |
| **Prototipação** | Boa para entender antes | Boa para digitar rápido | Boa para gerar andaimes (testes, *DescribeForDebug*, documentação) |
| **Adequação ao aprendizado** | Alta | Média: digita por você | Baixa para conceitos novos; alta para o que você já domina |

**Decisão:** **A** para tudo que você está aprendendo pela primeira vez (é o modo que obriga você a escrever o código). **B** para o que você já domina e só precisa digitar. **C** para tarefas mecânicas com critério de pronto verificável: escrever o teste de uma regra que já existe, gerar `DescribeForDebug`, migrar chamadas depois de uma refatoração, rascunhar documentação. Nunca **C** para um sistema que você ainda não saberia escrever. A regra de ouro da Introdução vale mais do que nunca aqui: *nunca aceite código de gameplay que você não saberia explicar linha a linha*.

---

## Implementação

O código deste capítulo é **ferramenta**, não jogo: dois documentos e um script.

### 1. O arquivo de contexto

Um arquivo que você cola no início de uma conversa, ou que o agente lê como instruções do projeto. Ele diz o que nenhuma IA tem como adivinhar.

```text
# docs/ia/CONTEXTO.md — Vigília (para pessoas e para IAs)

ENGINE
  Unreal Engine 5.__ (preencha a versão exata). Nada de APIs de UE4.
  Se não tiver certeza de uma API, escreva "VERIFICAR: <nome>" em vez de inventar.

PROJETO
  Módulo único Vigilia, prefixo VG, macro VIGILIA_API.
  Source/Vigilia/{Core, Player, Interaction, Combat, AI, Narrative, World, Save, UI, Debug, Tests}.
  Includes no formato "Pasta/Arquivo.h". Log: LogVigilia.
  Depuração: CVars vg.Debug.<Sistema>; cheats UFUNCTION(Exec) VGAlgo em UVGCheatManager.
  Testes: IMPLEMENT_SIMPLE_AUTOMATION_TEST, nome "Vigilia.<Área>.<Nome>", dentro de
          WITH_DEV_AUTOMATION_TESTS. Regras puras em namespace VG<Algo>Rules; um teste por sistema.
  Dados: UPrimaryDataAsset com IsDataValid (WITH_EDITOR). Texto exibível: FText, nunca FString.
  Tags nativas em VGGameplayTags; tags de conteúdo criadas no editor (docs/design/tags.md).
  Comunicação: UVGGameplayEventSubsystem::PublishFrom. Estado narrativo: UVGNarrativeSubsystem.
  Comentários "// Simplificação:" dizem até onde a solução vai e onde é revista.

DECISÕES FIRMADAS (não reabra; proponha e explique)
  Presença invencível. Sinalizador: no máximo 4 cartuchos. "Dois toques, o primeiro é aviso".
  Sem estamina. Rádio: canal único com fila (Cap. 44). Fatos monotônicos (Cap. 46).

ARMADILHAS CONHECIDAS (procure estas primeiro em toda revisão)
  - UFUNCTION const + BlueprintCallable vira nó puro: use BlueprintPure = false.
  - Memória de nó de BT chega zerada: InitializeMemory/CleanupMemory + InitializeNodeMemory<T>.
  - OnBecomeRelevant/OnCeaseRelevant exigem bNotifyBecomeRelevant/bNotifyCeaseRelevant = true.
  - AAIController reescreve a control rotation: para mirar, SetFocus.
  - Canal de colisão novo com Block bate na cápsula: cápsula Ignore, malha Block.
  - Ordem de BeginPlay entre atores não é garantida: estado inicial em PostInitializeComponents.
  - Valores do Blueprint não existem no construtor.
  - Não mute quem está notificando; copie, use índices, enfileire.
  - Declare o relógio: GetTimeSeconds (dilata, pausa), GetRealTimeSeconds (não dilata, não pausa),
    GetAudioTimeSeconds (pausa, não dilata).
  - TSet<TWeakObjectPtr>.Remove(nullptr) não remove obsoletos; TSubclassOf não vem de const UClass*.
  - Módulo novo entra no Build.cs no mesmo passo.
  (Acrescente aqui cada bug que custou mais de uma hora. Fonte: DEVLOG.md.)

O QUE A IA NÃO FAZ NESTE PROJETO
  - Não cria nem edita .uasset/.umap; para conteúdo, escreve os passos no editor.
  - Não descreve Blueprints, BTs ou EQS que não viu.
  - Não adiciona plugin, módulo ou dependência sem dizer por quê.
  - Não declara "pronto" sem rodar scripts/run-tests.ps1 e sem listar o que NÃO verificou.

COMO VERIFICAR
  scripts/run-tests.ps1 · CVars vg.Debug.* · Session Frontend · Engine/Source da versão acima.
```

### 2. O protocolo

O protocolo é curto de propósito, porque protocolo longo ninguém segue.

```text
# docs/ia/protocolo.md — antes de aceitar código vindo de IA

1. Sei explicar cada linha? Se não, volto ao modo conversa até saber.
2. Toda API que eu não conhecia foi conferida no header e anotada em
   docs/ia/apis-verificadas.md (nome · header · versão · data).
3. Compila (scripts/run-tests.ps1).
4. Tem teste, ou uma sonda/CVar que mostra o comportamento no PIE.
5. O passo é pequeno: consigo ler o diff inteiro de uma vez.
6. Procurei as ARMADILHAS CONHECIDAS do CONTEXTO.md no diff.
7. DEVLOG: "IA sugeriu ___; conferi ___; mudei ___; não verifiquei ___".
```

### 3. O script de verificação

```powershell
# scripts/run-tests.ps1 — compila o editor e roda os testes "Vigilia." sem abrir a interface.
# Uso: .\scripts\run-tests.ps1 -Engine "C:\Program Files\Epic Games\UE_5.x"
param([Parameter(Mandatory = $true)][string]$Engine)

$Project = Resolve-Path (Join-Path $PSScriptRoot "..\Vigilia.uproject")

& "$Engine\Engine\Build\BatchFiles\Build.bat" VigiliaEditor Win64 Development "-Project=$Project" -WaitMutex
if ($LASTEXITCODE -ne 0) { Write-Error "Build falhou."; exit 1 }

& "$Engine\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" "$Project" `
    -ExecCmds="Automation RunTests Vigilia" `
    -TestExit="Automation Test Queue Empty" `
    -ReportExportPath="$PSScriptRoot\..\Saved\TestReport" `
    -unattended -nullrhi -nosplash -log
exit $LASTEXITCODE
```

⚠️ Confira na documentação da sua versão (*Automation Test Framework*, *Unreal Build Tool*) os argumentos de linha de comando, e se o código de saída do editor reflete testes falhados. Se não refletir, faça o script ler o relatório exportado. Este é exatamente o tipo de detalhe que muda entre versões e que uma IA afirma com segurança.

### Explicação das decisões

- **O arquivo de contexto é texto em `docs/`, versionado.** Ele serve a você (é a memória do projeto), à IA da conversa (você cola) e ao agente (ele lê). Uma fonte só, para três leitores.
- **Armadilhas no contexto, em forma de lista.** Revisão por lista funciona; revisão por "está certo?" não funciona (estudo de caso).
- **"O que a IA não faz"** existe porque o padrão de um agente é fazer. Os limites precisam estar escritos.
- **O script é o critério de pronto.** Sem ele, o agente não tem como saber se acertou, e você não tem como saber se ele sabe.
- **`apis-verificadas.md`** parece burocracia, mas transforma uma verificação de cinco minutos num ativo: na próxima vez que uma IA sugerir aquela API, a resposta já está anotada, com a versão.

---

## Projeto Vigília — o kit de verificação

O que muda no repositório:

```text
docs/ia/
├── CONTEXTO.md              o arquivo de contexto (acima), com a versão exata da engine
├── protocolo.md             os 7 passos
├── apis-verificadas.md      tabela: API · header · versão · data · observação
└── prompts/                 a biblioteca de prompts, por TAREFA (não por capítulo)
    ├── estudar.md
    ├── investigar-erro.md
    ├── revisar-codigo.md    (com a lista de armadilhas embutida)
    ├── criar-testes.md
    └── refatorar.md
scripts/
└── run-tests.ps1
```

🔁 **As seções "Uso de IA" viram biblioteca.** Até aqui, os prompts moravam no fim de cada capítulo, organizados pelo assunto do capítulo. Isso foi bom para aprender e é ruim para usar: na hora de investigar um erro de link, você não lembra que o prompt bom estava no Capítulo 7. A biblioteca reorganiza os prompts pela **tarefa**, e cada arquivo começa com "cole o `CONTEXTO.md` antes". O que se aprendeu com o formato anterior: um prompt bom é específico do domínio, mas o **padrão** (contexto, pedido verificável, verificação) é o mesmo em todos.

**Auditoria retroativa.** Escolha três trechos de código da Vigília que você escreveu com ajuda de IA nas partes anteriores. Passe cada um pelo protocolo, como se fosse novo. Registre no `DEVLOG.md` o que encontrou. A expectativa honesta é encontrar pelo menos uma API não conferida e uma suposição de ordem ou de tempo de vida que nunca foi testada.

---

## Decisões arquiteturais

1. **IA como ferramenta de entendimento primeiro, de digitação depois.** Conversa para aprender; IDE para o que já domina; agente para o mecânico com critério de pronto.
2. **A memória do projeto mora em arquivos versionados** (`CONTEXTO.md`, README, `DEVLOG.md`), não na ferramenta.
3. **Toda afirmação tem um degrau mínimo de evidência** na escada de verificação; compilar é o primeiro degrau, nunca o último.
4. **O código da engine é a fonte da verdade**, acima da documentação e de qualquer resposta.
5. **Revisão por lista de armadilhas conhecidas**, alimentada pelo `DEVLOG.md`.
6. **Um comando de verificação** (`run-tests.ps1`) é pré-requisito para delegar a um agente.
7. **Prompts organizados por tarefa**, com o contexto do projeto como primeira linha.

---

## Armadilhas

- **Confundir fluência com correção.** A resposta mais bem escrita não é a mais correta; o tom é constante.
- **Pedir sem contexto.** Sem versão, sem convenções, sem forças do jogo, a resposta é a média da internet.
- **Colar só a última linha do erro.** A causa costuma estar no começo do log, e a fase (UHT, compilação, link) muda tudo.
- **Aceitar testes escritos olhando o código.** Eles confirmam o bug junto com o resto.
- **Delegar a um agente sem critério de pronto.** "Terminei" sem build e sem teste é só uma frase.
- **Diffs que você não consegue ler de uma vez.** O erro da família 4 se esconde no tamanho.
- **Pedir que a IA "descreva" um Blueprint, uma BT ou uma consulta EQS** que ela não viu. Ela descreve uma plausível.
- **Achar que a documentação oficial encerra a questão.** Às vezes ela está atrasada em relação ao código; o header da sua versão desempata.
- **Usar IA para o que você ainda não sabe fazer e chamar isso de estudo.** A spec chama isso de "usar IA para esconder falta de conhecimento".

---

## Exercício

**Parte 1 — o contexto (45 min).** Escreva o `docs/ia/CONTEXTO.md` da sua Vigília, com a versão exata da engine e as decisões firmadas do seu README. Acrescente às armadilhas pelo menos dois bugs do seu próprio `DEVLOG.md`.

**Parte 2 — dez APIs (1 h).** Liste dez APIs da engine que o seu código usa e que você aprendeu com ajuda de IA ou de exemplos (sugestões: `SpawnSound2D`, `GetAudioTimeSeconds`, `InitializeNodeMemory`, `AddMappingContext`, `SetFocus`). Para cada uma, abra o header, confira a assinatura, leia o comentário e registre em `apis-verificadas.md`. Anote qualquer diferença entre o que você "sabia" e o que está lá.

**Parte 3 — o bug plantado (1 h).** Numa *branch* descartável, reintroduza um dos erros do estudo de caso (por exemplo, apague `bNotifyCeaseRelevant = true` do service de tokens). Peça a uma IA para revisar o arquivo **sem dica**. Depois peça de novo, colando a lista de armadilhas do `CONTEXTO.md`. Registre no `DEVLOG.md`: ela achou na primeira vez? E na segunda? Que teste teria achado sozinho?

**Parte 4 — o script (45 min).** Adapte o `run-tests.ps1` à sua instalação e confirme três coisas: ele falha quando o build falha, ele roda todos os testes `Vigilia.*`, e você sabe onde está o relatório. Quebre um teste de propósito e veja se o script percebe.

---

## Desafio — o agente sob protocolo

Escolha uma tarefa mecânica e real da Vigília, por exemplo implementar o `DescribeForDebug` do `UVGDialogueSubsystem` (deixado como exercício no Capítulo 44), ou escrever um teste para uma regra que ainda não tem. Entregue-a a um agente de programação com:

1. o `CONTEXTO.md`;
2. o critério de pronto ("`run-tests.ps1` passa, e o teste novo falha se eu inverter a condição X");
3. a instrução de **planejar antes** e de listar no fim o que não verificou.

Meça e registre no `DEVLOG.md`: quantos ciclos de build ele precisou; quantas linhas o diff teve; o que você precisou corrigir à mão; quanto tempo você gastou **revisando** comparado ao tempo que gastaria escrevendo. A resposta honesta para a última pergunta define para que tipo de tarefa você vai usar agentes daqui em diante.

---

## Uso de IA

Nesta parte, a seção vira meta: prompts para avaliar o próprio uso de IA.

1. **Para auditar o seu uso de IA:**
   > "Aqui estão as entradas do meu DEVLOG das últimas quatro semanas que mencionam IA. Classifique cada uso: (a) acelerou um entendimento que eu já estava construindo, (b) substituiu um entendimento que eu deveria ter construído, (c) tarefa mecânica legítima. Para cada (b), diga qual conceito eu deveria estudar e que experimento mostraria se eu aprendi. Seja específico; não me elogie."

2. **Para estudar ensinando de volta:**
   > "Vou explicar como o canal de rádio da Vigília decide qual conversa toca (fila, prioridade, interrupção, expiração, leitura). Não me dê a explicação certa. Faça perguntas que exponham as lacunas da minha explicação, uma de cada vez, e só no fim diga o que eu errei. [minha explicação]"

3. **Para revisar com lista, não com fé:**
   > "Revise este código de Unreal Engine 5.[versão] procurando ESPECIFICAMENTE as armadilhas listadas no contexto abaixo. Para cada uma, diga 'presente', 'ausente' ou 'não consigo saber sem ver X'. Depois liste qualquer API que você não tem certeza de que existe nesta versão. [CONTEXTO.md] [código]"

4. **Para medir a sua dependência:**
   > "Me dê cinco perguntas de entrevista técnica sobre [tema de uma parte que já estudei], do tipo que só quem implementou responde. Eu respondo sem consulta; depois avalie as respostas e aponte qual parte do livro eu deveria reler."

**Cuidado específico:** a IA que avalia o seu uso de IA tende a ser gentil e genérica ("você está usando bem a ferramenta"). Exija evidência: cada classificação deve citar a entrada do `DEVLOG.md` em que se baseia, e cada lacuna apontada deve vir com um experimento que você consiga rodar.

---

## Checklist

- [ ] Sei explicar por que um LLM produz APIs plausíveis e erradas, e por que a Unreal é um domínio especialmente propenso a isso.
- [ ] Sei o que um agente de programação consegue e não consegue verificar num projeto Unreal.
- [ ] Tenho um workflow (contexto, pedido verificável, verificação) para cada tarefa da tabela 69.3.
- [ ] Reconheço as quatro famílias de erro e sei por que a quarta é a mais cara.
- [ ] Sei qual degrau da escada de verificação cada tipo de afirmação exige.
- [ ] Sei encontrar e ler o código da engine para conferir um contrato.
- [ ] O `CONTEXTO.md`, o `protocolo.md` e o `run-tests.ps1` da Vigília existem e funcionam.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Automation Test Framework** (e *Session Frontend*), **Unreal Build Tool** e **Downloading Unreal Engine Source Code** (acesso ao repositório pelo GitHub).
- **Michael Feathers, *Working Effectively with Legacy Code*.** O livro de referência sobre colocar código sob teste antes de mudá-lo. As técnicas valem para refatorar com ou sem IA.
- **Andrew Hunt e David Thomas, *The Pragmatic Programmer*.** Em particular as ideias de *tracer bullets* e de não programar por coincidência, que descrevem bem a diferença entre "funcionou" e "sei por que funcionou".
- **cppreference.com**, para separar o que é C++ padrão do que é convenção da Unreal.

---

➡️ **Próximo:** [Capítulo 70 — IA para Game Design](cap-70-ia-game-design.md)

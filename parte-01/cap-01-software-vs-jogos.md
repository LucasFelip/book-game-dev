# PARTE I — Pensando como Game Developer

---

# Capítulo 1 — O que diferencia software de jogos

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que significa dizer que um jogo é uma **simulação interativa em tempo real**, e por que cada uma dessas três palavras muda a engenharia;
- identificar os pontos em que seus reflexos de engenharia de backend ajudam — e os pontos em que eles levam a decisões ruins em jogos;
- entender por que, em jogos, **a experiência percebida é o requisito**, e por que "trapacear" para produzir essa experiência é uma técnica legítima;
- olhar para uma mecânica aparentemente trivial (uma porta) e enxergar os sistemas que ela atravessa;
- aplicar pela primeira vez a **Ficha de Decomposição** a um jogo real, com o estudo de caso da luz em Alan Wake.

Este é um capítulo conceitual. Quase não há código; há modelo mental. Ele é a base sobre a qual todo o resto do livro é construído.

---

## Contexto

Pense em um dia típico do seu trabalho. Uma requisição HTTP chega. Ela é desserializada, validada, passa por um *controller*, um serviço de domínio, um repositório. Uma transação é aberta, o estado no banco é alterado, uma resposta é serializada e devolvida. Talvez um evento seja publicado num tópico. Depois disso, **o sistema volta a esperar**.

Todo o vocabulário que você domina — latência de requisição, *throughput*, idempotência, transação, consistência, *retry*, *circuit breaker* — gira em torno dessa unidade fundamental: **a requisição**. Ela tem começo, meio e fim. O sistema existe para responder.

Agora pense no que acontece quando você abre Alan Wake e deixa o controle no chão. Nada chega. Ninguém pede nada. E, ainda assim, o programa continua trabalhando furiosamente: as árvores balançam com o vento, a névoa se move, o som ambiente evolui, a luz da lanterna oscila, a câmera faz micro-movimentos. Trinta ou sessenta vezes por segundo — o Alan Wake original, no Xbox 360, rodava a 30 —, o programa calcula um mundo inteiro e desenha uma imagem nova. Se ele atrasar alguns milissegundos, você percebe — não como "a resposta demorou", mas como "o jogo engasgou".

A unidade fundamental de um jogo não é a requisição. É o **frame** (quadro): um passo de simulação seguido de uma imagem. E um jogo não existe para responder; existe para **continuar**.

Essa diferença parece pequena quando dita em uma frase. Ela não é. Ela reorganiza a arquitetura, a forma de gerenciar estado, a concorrência, os testes, a definição de "correto" e até a relação entre o programador e as outras pessoas do time.

---

## 1.1 Um jogo é uma simulação interativa em tempo real

A definição mais útil para um engenheiro tem três palavras. Vamos desmontá-las uma de cada vez.

### Simulação

Um jogo mantém um **modelo de um mundo** — posições, velocidades, vidas, portas abertas ou fechadas, o que cada inimigo sabe sobre o jogador, em que ponto da história estamos — e **avança esse modelo no tempo**, passo a passo.

"Mundo", aqui, não precisa ser realista. Tetris é uma simulação: o mundo é uma grade, uma peça em queda e uma pontuação; a cada passo, a peça desce. PES é uma simulação: o mundo é um campo, 22 jogadores, uma bola, regras, um placar e um relógio. GTA V é uma simulação de uma cidade inteira — ou, como veremos no Interlúdio II, a simulação de *um pedaço da cidade em volta de você*, disfarçada de cidade inteira.

O ponto essencial: **o estado do jogo muda mesmo quando ninguém faz nada.** Isso já o diferencia de quase todo software corporativo, em que o estado só muda em resposta a um comando.

### Interativa

O jogador não é um cliente que envia requisições e recebe respostas. Ele é **parte do sistema**. Ele observa o mundo, decide, age; o mundo reage; ele observa de novo. É um **laço de realimentação fechado** (*feedback loop*):

```text
        ┌──────────────────────────────────────────────┐
        │                                              │
        ▼                                              │
   ┌─────────┐   percebe    ┌─────────┐   decide   ┌───┴─────┐
   │  MUNDO  │ ───────────► │ JOGADOR │ ─────────► │  INPUT  │
   │ (jogo)  │  imagem/som  │ (humano)│            │(controle)│
   └─────────┘              └─────────┘            └─────────┘
        ▲                                              │
        │          simulação avança um frame           │
        └──────────────────────────────────────────────┘
```

A consequência de engenharia é profunda: **a qualidade do sistema é avaliada por um ser humano dentro do laço, em tempo real**. Se o laço tiver atraso demais, ou for inconsistente, o humano sente. Ele não sabe dizer que o *input lag* está em 120 ms; ele diz "o controle está pesado" ou "parece que estou jogando debaixo d'água".

Você conhece esse fenômeno por outro ângulo: na sua área, existe a regra prática de que respostas abaixo de ~100 ms são percebidas como "instantâneas" em interfaces. Em jogos, o laço é contínuo: o jogador está o tempo todo mexendo o analógico e esperando que a câmera acompanhe. Não há "uma requisição" para medir — há um fluxo ininterrupto de pequenas expectativas, cada uma podendo ser frustrada.

### Tempo real

A palavra "tempo real" tem um significado preciso em computação. Sistemas de **tempo real rígido** (*hard real-time*), como o controle de um airbag, falham catastroficamente se perdem um prazo. Sistemas de **tempo real brando** (*soft real-time*) degradam em qualidade quando perdem prazos, mas continuam funcionando.

Jogos são *soft real-time*. Cada frame tem um prazo: se o jogo roda a 60 quadros por segundo, cada frame tem **16,67 ms** para ser simulado e desenhado. Se um frame levar 40 ms, nada explode — mas o jogador vê uma "travada" (*hitch*, *stutter*). Se isso acontecer com frequência, o jogo parece quebrado, mesmo que todos os resultados estejam "corretos".

```text
Taxa alvo     Orçamento por frame
 30 FPS   →   33,33 ms
 60 FPS   →   16,67 ms
120 FPS   →    8,33 ms
144 FPS   →    6,94 ms
240 FPS   →    4,17 ms
```

Guarde esses números. Eles vão aparecer de novo no Capítulo 3, no Capítulo 58 e em quase toda decisão de arquitetura do livro. Para efeito de comparação: 16,67 ms é menos tempo do que muitas das suas consultas a banco levam para voltar. Dentro dessa janela, um jogo precisa ler input, rodar a lógica de gameplay, simular física, avaliar animações de todos os personagens visíveis, atualizar áudio, decidir o que desenhar e enviar tudo para a GPU.

> 🌉 **Ponte:** pense no orçamento de frame como um SLO de latência — mas um SLO que se aplica a **cada** execução, não a um percentil. Você monitora p99 de latência porque sabe que a média esconde a dor do usuário. Em jogos, o equivalente é olhar o **pior frame** e a **consistência** dos frames (*frame pacing*), não o FPS médio. Um jogo a "60 FPS de média" com um frame de 80 ms a cada segundo é pior de jogar do que um jogo estável a 45.
>
> 🧱 **Onde a ponte cai:** em backend, quando a latência sobe, você escala horizontalmente. Em jogos, **não existe escalar**: o hardware é o do jogador, fixo, e o orçamento é o que é. Você não pode adicionar réplicas de um PlayStation 2 rodando PES 2011. Toda a performance tem que caber em uma máquina, em uma janela de tempo.

---

## 1.2 O requisito principal é uma experiência

Em software corporativo, a especificação descreve um comportamento correto: "ao receber um pedido válido, debitar o estoque e emitir a nota". Correção é verificável — a nota foi emitida ou não foi.

Em jogos, a especificação de verdade é uma **experiência**: "o jogador deve se sentir vulnerável", "o tiro deve ser satisfatório", "o drible deve parecer responsivo", "a cidade deve parecer viva". Essas frases não são decorativas. Elas são o requisito. E são, por natureza, avaliadas subjetivamente por humanos jogando.

O efeito mais desconcertante disso para um engenheiro é este:

> **Em jogos, o comportamento "fisicamente correto" frequentemente é o comportamento errado.**

Considere o pulo de um personagem. A física correta de um projétil sob gravidade constante produz uma parábola simétrica. Mas é uma prática amplamente difundida em game design — discutida em inúmeras talks e artigos sobre *game feel* — fazer o personagem **cair mais rápido do que sobe** (gravidade maior na descida), porque o pulo simétrico parece "flutuante". Outra prática comum é o **coyote time**: permitir que o jogador pule por alguns milissegundos *depois* de ter saído da beirada de uma plataforma, porque o cérebro humano percebe que apertou o botão "a tempo", mesmo que o personagem já estivesse no ar. Fisicamente absurdo. Experiencialmente correto.

Outra prática comum: o **jump buffering** — se o jogador aperta "pular" um pouco *antes* de tocar o chão, o jogo guarda esse input e executa o pulo assim que o personagem aterrissa. Sem isso, o input "se perde" e o jogador sente que o jogo ignorou o comando.

Você vai implementar as três coisas no Capítulo 25. Por enquanto, o ponto é o princípio: **o critério de correção é a percepção do jogador, não a fidelidade do modelo.**

### Bug vs. "não está divertido"

Isso cria duas categorias de problema que não existem da mesma forma no seu trabalho atual:

- **Bug** — o sistema não faz o que foi projetado para fazer (a porta não abre, o inimigo atravessa a parede, o save corrompe).
- **Problema de design** — o sistema faz exatamente o que foi projetado, e o resultado não é bom (o inimigo é injusto, a arma é sem graça, o puzzle é obscuro, o ritmo cansa).

O segundo tipo é muito mais comum, muito mais caro e não aparece em nenhum teste automatizado. Ele aparece quando alguém joga. É por isso que **playtest** — observar pessoas jogando — é uma prática central da produção de jogos, e é por isso que este livro vai pedir que você jogue o que construiu o tempo inteiro.

> 🌉 **Ponte:** isso se parece com a distinção entre *verificação* ("construímos o sistema corretamente?") e *validação* ("construímos o sistema correto?") da engenharia de software. A diferença é de proporção: em sistemas corporativos, a validação acontece em ciclos de semanas, com stakeholders. Em jogos, a validação acontece **a cada minuto de jogo**, e o stakeholder é o seu próprio sistema nervoso.

---

## 1.3 Mentir é uma técnica legítima

Se a experiência é o requisito, então qualquer técnica que produza a experiência com menor custo é válida — inclusive técnicas que, aos olhos de um engenheiro rigoroso, parecem trapaça. Desenvolvedores de jogos chamam isso, carinhosamente, de **smoke and mirrors** (fumaça e espelhos).

Alguns exemplos genéricos, todos comuns na indústria:

- **O céu não existe.** Montanhas distantes, nuvens e horizonte são muitas vezes uma imagem pintada numa esfera gigante (*skybox*) ou modelos simplificados que nunca podem ser alcançados.
- **O mundo existe só onde você está.** Em mundos abertos, NPCs e veículos são criados à sua volta e destruídos quando saem do seu campo de interesse. A cidade "viva" é, em grande parte, um palco montado em tempo real ao redor do jogador. (Este é o coração do Interlúdio II, sobre GTA.)
- **O inimigo não é tão bom quanto poderia ser.** Uma IA que sempre acerta o tiro é trivial de programar e terrível de enfrentar. É prática amplamente discutida em talks sobre Game AI fazer inimigos **errarem de propósito** os primeiros disparos, ou anunciarem sua presença antes de atacar, para dar ao jogador tempo de reagir. A dificuldade é *dosada*, não maximizada.
- **A tensão é roteirizada.** Uma porta que bate sozinha quando você passa, um som de passos no andar de cima, uma luz que falha: em jogos de terror, muitos desses momentos são disparados por *triggers* — volumes invisíveis no nível que executam um evento quando o jogador entra neles.
- **A câmera engana.** Um leve balanço, um aumento sutil do campo de visão ao correr, um tremor curto num impacto: nada disso é "física", e tudo isso comunica peso, velocidade e força.

Para quem vem de sistemas corporativos, onde "o sistema mostra uma coisa e faz outra" é a definição de um bug grave, isso exige uma reprogramação de valores. Em jogos, **o que importa é o mundo percebido, não o mundo simulado**. O mundo simulado só precisa ser bom o suficiente para sustentar a ilusão.

Isso tem uma consequência de arquitetura que vamos explorar no livro inteiro: **você sempre deve saber qual é a fronteira da ilusão**. Um inimigo que "ouve" você precisa de um sistema de percepção apenas sofisticado o bastante para que o jogador acredite que foi ouvido — e consiga entender *por que* foi ouvido. Se o jogador não consegue entender o sistema, ele o percebe como aleatório e injusto. Se consegue, ele começa a jogar com o sistema: andar devagar, evitar o vidro quebrado no chão, jogar uma garrafa para distrair. Esse é o momento em que um sistema técnico vira design.

> **Regra prática:** simule só o que o jogador pode perceber ou explorar. Todo o resto pode ser falsificado.

---

## 1.4 O estado do mundo inteiro vive na memória

No seu dia a dia, uma das melhores práticas de arquitetura é manter serviços **stateless**: o estado mora no banco, e qualquer instância pode atender qualquer requisição. A memória do processo é cache, descartável.

Em um jogo, a situação é invertida:

- **O estado vivo está na memória.** A posição de cada objeto, a vida de cada personagem, cada porta aberta, a memória de cada inimigo, o tempo restante de cada efeito. Isso é a fonte da verdade — não um cache.
- **O estado é altamente mutável.** Dezenas ou centenas de valores mudam a cada frame.
- **O estado é compartilhado.** A arma lê o estado do personagem, a IA lê o estado do jogador, a UI lê o estado da arma, o áudio lê o estado de tudo.
- **A persistência é um snapshot.** O "banco de dados" de um jogo é o arquivo de save, gravado ocasionalmente. Entre um save e outro, a memória manda.

Isso significa que boa parte da sua disciplina de arquitetura — fronteiras de agregados, transações, consistência — precisa ser reinterpretada. Em DDD, um agregado protege invariantes com transações. Em um jogo, o "agregado" pode ser um personagem cujo estado é alterado, no mesmo frame, pelo sistema de movimento, pelo sistema de dano, pelo sistema de animação e por um script de cinemática. Não há transação. Há **ordem de atualização**: quem roda primeiro no frame define o que os outros enxergam. (Esse é o assunto dos Capítulos 2 e 4.)

### E a concorrência?

Aqui está uma surpresa para quem trabalha com sistemas distribuídos: **o código de gameplay de um jogo típico roda numa única thread**. Na Unreal, ela se chama *game thread*. A engine é profundamente paralela por baixo — renderização, física, animação, áudio, streaming de assets rodam em outras threads —, mas a lógica de gameplay (o que você vai escrever na maior parte do tempo) é, por padrão, sequencial.

Isso não é atraso tecnológico; é uma decisão deliberada. Gameplay é um emaranhado de estado compartilhado com dependências de ordem sutis ("o inimigo morre, o que cancela o ataque dele, o que impede o dano, o que muda a animação"). Paralelizar isso com locks seria um pesadelo de bugs não determinísticos, e o ganho seria pequeno, porque o gargalo raramente é a lógica de gameplay em si. A estratégia geral da indústria é: **gameplay sequencial, sistemas pesados e independentes em paralelo**.

> 🌉 **Ponte:** se você já trabalhou com Node.js ou com o *event loop* do Netty, o modelo "uma thread para a lógica, I/O e trabalho pesado em outras" vai soar familiar.
>
> 🧱 **Onde a ponte cai:** o event loop de um servidor **dorme** quando não há eventos. A game thread **nunca dorme**: ela roda o frame seguinte imediatamente, ou espera apenas o tempo necessário para sincronizar com a tela. Ela não é dirigida por eventos externos; ela é dirigida pelo relógio. O Capítulo 2 desenvolve essa diferença.

---

## 1.5 O tempo é uma entrada do sistema

Em backend, o tempo costuma ser **metadado**: um *timestamp* de criação, um TTL, um agendamento. Ele raramente participa da lógica principal.

Em jogos, o tempo é **uma das entradas principais** de quase todo sistema. A atualização de praticamente qualquer coisa tem a forma:

```text
novo_estado = f(estado_atual, input, Δt)
```

onde **Δt** (*delta time*) é o tempo que passou desde o último frame. Um personagem que anda a 600 unidades por segundo se move `600 × Δt` unidades neste frame. Um efeito de veneno que tira 5 pontos de vida por segundo tira `5 × Δt` neste frame. Uma porta que leva 1,2 segundos para abrir avança `Δt / 1,2` do seu percurso.

Por que não simplesmente "mover 10 unidades por frame"? Porque frames não têm duração fixa. Em uma máquina rápida, o jogo roda a 144 FPS; numa lenta, a 40. Se o movimento for por frame, o personagem anda três vezes e meia mais rápido na máquina rápida. Esse erro já foi real: é parte do folclore da computação que alguns jogos antigos de PC ficavam rápidos demais em processadores mais novos, porque sua lógica estava amarrada à velocidade da máquina.

O Capítulo 3 é inteiro sobre isso: Δt variável vs. passo fixo, por que física prefere passo fixo, como interpolar a renderização, e por que o mesmo jogo pode se comportar de forma diferente a 30 e a 120 FPS se você não tomar cuidado.

---

## 1.6 Performance é um requisito funcional

No seu trabalho, performance é tipicamente um **requisito não funcional**: importante, mas negociável — você otimiza quando um SLO é violado, e enquanto isso a funcionalidade está "pronta".

Em jogos, performance é **funcional**. Um jogo de tiro a 20 FPS não está "pronto mas lento"; ele está **quebrado**, porque mirar fica impossível. Um jogo de terror com travadas não está "pronto mas lento"; ele perde a imersão que é a razão de ser do jogo.

Isso muda o *momento* em que performance entra nas decisões. Em jogos, você pensa em custo desde a escolha da arquitetura:

- "Esse sistema vai rodar a cada frame em 200 objetos ou em 3?"
- "Essa verificação precisa ser feita a cada frame ou a cada meio segundo?"
- "Esse dado vai ser criado e destruído o tempo todo (pressão no alocador e no garbage collector) ou reaproveitado?"

Não é otimização prematura — é **projetar dentro de um orçamento conhecido**. A otimização prematura, em jogos, é outra coisa: micro-otimizar código que roda uma vez por minuto. A linha entre as duas é exatamente o orçamento de frame, e ela será traçada com dados no Capítulo 58.

> 🌉 **Ponte:** você já pensa em custo de operações em sistemas distribuídos — uma chamada de rede dentro de um laço é um erro óbvio para você. Em jogos, a "chamada de rede dentro do laço" equivalente é qualquer trabalho caro feito **por frame, por objeto**. O laço implícito é o game loop, e ele roda para sempre.

---

## 1.7 Dados e conteúdo dominam o projeto

Em sistemas corporativos, o produto é majoritariamente código (e dados do cliente). Em jogos, o código é uma fração pequena do que é entregue. O resto é **conteúdo**: modelos 3D, texturas, animações, sons, músicas, níveis, diálogos, cinemáticas, configurações de armas e inimigos. Em produções de grande porte, o número de artistas, designers e animadores costuma superar com folga o de programadores.

Isso tem três consequências para você como programador:

1. **Seus usuários principais são outras pessoas do time.** O código de gameplay é usado por designers, que vão configurar armas, posicionar inimigos e montar eventos. Se configurar uma arma exige recompilar C++, você criou um gargalo. Por isso, sistemas de jogos são, por padrão, **data-driven**: o código define o *comportamento*; os dados (planilhas, *Data Assets*, Blueprints) definem *os números e as variações*.
2. **O editor faz parte do produto.** Na Unreal, as classes que você escreve aparecem no editor, com propriedades editáveis, categorias, valores padrão e validações. Um sistema que é poderoso mas impossível de configurar no editor é, na prática, um sistema ruim.
3. **Assets pesam e não se fundem.** Arquivos `.uasset` são binários. Duas pessoas editando o mesmo nível ao mesmo tempo é um conflito sem resolução automática. Isso explica por que o controle de versão em jogos usa *locks* de arquivo (Perforce, Git LFS com locking) — assunto do Capítulo 7.

> 🌉 **Ponte:** *data-driven design* lembra externalização de configuração e *feature flags*: separar o que muda com frequência (configuração) do que muda pouco (código).
>
> 🧱 **Onde a ponte cai:** em jogos, os "dados" não são apenas parâmetros. Um Blueprint é um dado que contém *lógica*. Um nível é um dado que contém *centenas de objetos com comportamento*. A fronteira entre código e conteúdo é deliberadamente porosa, e decidir onde ela fica é uma das decisões de arquitetura mais importantes que você vai tomar (Capítulo 13).

---

## 1.8 Iteração vence planejamento

Você está acostumado a projetar antes de construir: modelar o domínio, discutir contratos, revisar arquitetura. Isso funciona porque, em sistemas corporativos, **o problema é relativamente conhecido** antes da construção — o desafio é resolvê-lo bem.

Em jogos, uma parte grande do problema **só é descoberta jogando**. Você não sabe se uma mecânica é divertida até prototipá-la. Não sabe se um nível é confuso até ver alguém se perder nele. Não sabe se o inimigo é assustador até ser perseguido por ele. Por isso, desenvolvimento de jogos tem um vocabulário próprio para iteração:

- **Protótipo** — uma versão rápida, feia e muitas vezes descartável, construída para responder a uma pergunta de design ("é divertido iluminar inimigos para enfraquecê-los?").
- ***Grey-box*** ou ***blockout*** — um nível construído com formas geométricas simples, sem arte final, para testar espaço, fluxo e ritmo.
- ***Find the fun*** — a fase de exploração em que o objetivo é encontrar o que funciona, antes de investir em qualidade.
- ***Vertical slice*** — um pedaço pequeno do jogo construído com qualidade final, em todos os sistemas, para provar que o jogo inteiro é viável (Capítulo 78).

A consequência para o programador é que **parte do código que você escrever será jogada fora, e isso é bom**. Um protótipo bem-sucedido é aquele que responde à pergunta rapidamente, não aquele cujo código é elegante. O perigo oposto também existe: código de protótipo que nunca é reescrito e vira a fundação de um sistema de produção. Saber quando um protótipo deve ser reescrito é uma habilidade que este livro vai exercitar explicitamente — o Projeto 4 (Interlúdio I) é um protótipo deliberado que será reestruturado na Parte VI.

> 🌉 **Ponte:** a prototipação de jogos se parece com *spikes* em metodologias ágeis — código exploratório para reduzir incerteza.
>
> 🧱 **Onde a ponte cai:** um *spike* responde a uma incerteza técnica ("essa biblioteca aguenta a carga?"). Um protótipo de jogo responde, quase sempre, a uma incerteza **humana** ("as pessoas vão gostar disso?"). A única forma de responder é colocar uma pessoa para jogar.

---

## 1.9 Testes, qualidade e observabilidade

Jogos podem e devem ter testes automatizados. A Unreal possui um framework de automação com testes unitários, testes funcionais (executados dentro de um nível) e ferramentas de teste de performance. Lógica determinística — cálculo de dano, regras de inventário, transições de estado de quest, serialização de save — é testável da mesma forma que qualquer lógica de domínio, e você vai escrever testes assim nos Capítulos 45 e 56.

Mas a fração do comportamento coberta por testes automatizados é menor do que você está acostumado, por três motivos:

1. **Muito comportamento é emergente da interação de sistemas em tempo real** (física + animação + IA + input). Reproduzir essas condições num teste é caro e frágil.
2. **Muita qualidade é subjetiva** ("está gostoso?"), e não existe asserção para isso.
3. **O conteúdo muda o tempo todo.** Um teste que verifica que "o inimigo chega ao jogador em menos de 5 segundos" quebra cada vez que um level designer move uma parede.

O resultado é que a indústria depende fortemente de **QA humano** (testadores profissionais) e de **ferramentas de depuração visual**. Esta segunda parte é importante para você: em jogos, a observabilidade mais poderosa é desenhar informação **dentro do mundo**. O cone de visão do inimigo como um leque vermelho, o caminho da navegação como uma linha verde, o ponto de impacto do tiro como uma esfera amarela, a memória da IA como texto flutuando sobre a cabeça dela. A Unreal tem ferramentas excelentes para isso (Gameplay Debugger, Visual Logger, funções `DrawDebug*`), cobertas no Capítulo 61 e usadas desde a Parte III.

> 🌉 **Ponte:** desenhar debug no mundo é o equivalente de *tracing distribuído* — tornar visível o caminho de uma decisão através do sistema. O Visual Logger da Unreal, em particular, grava o estado de agentes ao longo do tempo e permite "voltar a fita", o que lembra muito inspecionar um trace no Jaeger ou no Application Insights.

---

## 1.10 Um time multidisciplinar

Por último, uma diferença humana. Em sistemas corporativos, a maior parte do time é de engenharia, com produto e design de UX ao redor. Em jogos, a engenharia é **uma disciplina entre várias**, e frequentemente não é a maior. Alguns papéis que você vai encontrar (e cujos chapéus vai vestir, sozinho, nos projetos deste livro):

| Papel | Responsabilidade |
|---|---|
| **Game designer** | Define regras, mecânicas, sistemas e a experiência desejada. |
| **Level designer** | Constrói os espaços jogáveis: layout, fluxo, encontros, ritmo. |
| **Narrative designer** | Estrutura a história dentro do gameplay: diálogos, quests, documentos. |
| **Technical designer** | Ponte entre design e engenharia; implementa lógica em ferramentas de alto nível (Blueprint). |
| **Gameplay programmer** | Implementa sistemas de gameplay: personagem, armas, IA, interação. **É a sua trilha principal.** |
| **Engine/tools programmer** | Trabalha na engine, renderização, ferramentas do editor, pipeline. |
| **Technical artist** | Ponte entre arte e engenharia: shaders, VFX, otimização de assets. |
| **Artistas, animadores, sound designers** | Criam o conteúdo audiovisual. |
| **Producer** | Planejamento, escopo, prazos. |
| **QA** | Testes, reprodução de bugs, verificação. |

A lição prática: **o código de gameplay é escrito para ser usado e ajustado por pessoas que não são programadoras**. Isso guia decisões como "esse valor deve ser uma constante no código ou uma propriedade editável?" (quase sempre a segunda), "esse comportamento deve ser fixo em C++ ou exposto como evento para Blueprint?" (frequentemente a segunda) e "esse erro deve ser um crash ou um aviso visível no editor?" (quase sempre a segunda).

---

## Comparação consolidada com o desenvolvimento tradicional

| Dimensão | Sistema corporativo típico | Jogo típico |
|---|---|---|
| Unidade de trabalho | Requisição / mensagem | Frame |
| Ritmo | Dirigido por eventos externos; ocioso quando não há demanda | Dirigido pelo relógio; nunca ocioso |
| Estado | No banco; serviços *stateless* | Na memória; mutável; compartilhado |
| Persistência | Contínua, transacional | Snapshot ocasional (save) |
| Concorrência da lógica | Muitas requisições em paralelo | Lógica de gameplay sequencial; engine paralela |
| Escala | Horizontal | Inexistente: hardware fixo do jogador |
| Métrica de performance | Throughput, latência por percentil | Tempo de frame; pior frame; consistência |
| Critério de correção | Comportamento especificado | Experiência percebida |
| Tempo | Metadado | Entrada de todo cálculo (Δt) |
| Quem configura | Engenharia, via deploy | Designers, via editor e dados |
| Qualidade verificada por | Testes automatizados + monitoramento | Playtest + QA humano + testes onde cabem |
| Observabilidade | Logs, métricas, traces | Debug visual no mundo, profilers de frame, logs |
| Código descartável | Exceção (spike) | Parte normal do processo (protótipos) |
| Arquitetura "boa" | Extensível, desacoplada, testável | Iterável, previsível em custo, ajustável por designers |

Leia a última linha com atenção. Ela não diz que extensibilidade, desacoplamento e testabilidade não importam em jogos — eles importam muito. Diz que, quando houver conflito, **a capacidade de iterar rápido sobre a experiência e de caber no orçamento de frame vencem a elegância**. O Capítulo 6 transforma essa frase em critérios concretos de decisão.

---

## Unreal Engine: onde essas diferenças aparecem

Você ainda não abriu a Unreal (isso acontece no Capítulo 7), mas vale antecipar onde cada ideia deste capítulo vai se materializar:

- **Simulação contínua** → o `UWorld` é o contêiner do mundo simulado; a cada frame, a engine executa o *tick* do mundo, que atualiza todos os objetos que precisam ser atualizados (Capítulo 2).
- **Tempo como entrada** → a função `Tick(float DeltaSeconds)` recebe o Δt de cada frame; sistemas como física rodam com regras próprias de passo (Capítulo 3).
- **Estado na memória** → os objetos do mundo são **Actors** (`AActor`), compostos por **Components** (`UActorComponent`), e vivem na memória enquanto o nível está carregado (Capítulos 8 e 9).
- **Gameplay em uma thread** → a *game thread* executa o tick de gameplay; *render thread*, *RHI thread* e threads de tarefas cuidam do resto (Capítulo 2).
- **Data-driven e editor como produto** → o sistema de reflexão (`UPROPERTY`, `UCLASS`) expõe suas classes C++ ao editor e ao Blueprint (Capítulos 11–13).
- **Debug visual** → `DrawDebugLine`, `DrawDebugSphere`, Gameplay Debugger, Visual Logger (usados desde a Parte III, aprofundados no Capítulo 61).
- **Orçamento de frame** → `stat unit`, `stat game`, Unreal Insights (Capítulos 58–59).

---

## Exemplo: a porta que toca dez sistemas

Vamos testar o novo modelo mental num exemplo propositalmente banal: **uma porta que o jogador abre ao apertar E**.

### A leitura de um engenheiro corporativo

O reflexo natural é algo assim:

```text
Jogador aperta E
   → DoorService.open(doorId)
      → valida se a porta não está trancada
      → door.state = OPEN
      → persiste
   → retorna sucesso
```

Um comando, uma validação, uma mudança de estado. Pronto.

### A leitura de um desenvolvedor de jogos

Agora observe tudo o que precisa acontecer para que essa porta **pareça** uma porta dentro da Usina de Serra Funda, num jogo de terror em primeira pessoa:

```text
                                    ┌───────────────┐
                                    │    A PORTA    │
                                    └───────┬───────┘
    ┌──────────────┬──────────────┬─────────┼─────────┬──────────────┬──────────────┐
    ▼              ▼              ▼         ▼         ▼              ▼              ▼
 INTERAÇÃO      ESTADO        MOVIMENTO  COLISÃO  NAVEGAÇÃO        ÁUDIO          LUZ
 prompt "E"     Fechada        rotação   bloqueia  caminho da IA   rangido        luz vaza
 alcance,       Abrindo        ao longo  e libera  muda quando     espacializado  pela fresta;
 ângulo de      Aberta         do tempo  o jogador abre/fecha      variação de    sombras
 visão          Trancada       (curva)   sem       (nav modifier)  pitch          mudam
                Fechando                 esmagá-lo
    │              │              │         │         │              │              │
    └──────────────┴──────────────┴─────────┼─────────┴──────────────┴──────────────┘
    ┌──────────────┬──────────────┬─────────┴─────────┬──────────────┐
    ▼              ▼              ▼                   ▼              ▼
 PERCEPÇÃO     NARRATIVA        SAVE             MULTIPLAYER     PERFORMANCE
 da IA         1ª abertura      estado da        quem tem        só atualiza
 o ruído pode  dispara uma      porta precisa    autoridade      enquanto se
 atrair a      fala no rádio    sobreviver a     para abrir?     move; dorme
 Presença                       um load          replicar        no resto
```

Nenhum desses itens é exagero. Cada um corresponde a um problema real:

1. **Interação** — como o jogo sabe que você está olhando para a porta e perto o bastante? Mostra um ícone? Qual tecla? E se houver duas coisas interativas à sua frente? *(Capítulo 19)*
2. **Estado** — a porta não tem dois estados (aberta/fechada); tem pelo menos cinco, porque ela leva tempo para abrir e pode ser interrompida no meio. *(Capítulos 4 e 34)*
3. **Movimento ao longo do tempo** — a abertura é uma animação de rotação guiada por uma curva (começa devagar, acelera, desacelera no fim), atualizada a cada frame com Δt. *(Capítulos 2 e 3)*
4. **Colisão** — uma porta se movendo é um objeto físico em movimento. Ela precisa empurrar o jogador ou parar se o jogador estiver no caminho? O que acontece se ela fechar com o jogador no meio? *(Capítulo 15)*
5. **Navegação** — a IA calcula caminhos sobre uma malha de navegação. Uma porta fechada é um obstáculo; aberta, não. A IA precisa saber. *(Capítulo 35)*
6. **Áudio** — o rangido é espacializado (vem da direção da porta), atenua com a distância, varia levemente a cada vez para não parecer repetitivo. *(Capítulo 52)*
7. **Luz** — num jogo em que a luz é mecânica, abrir uma porta pode deixar luz entrar num corredor escuro — ou deixar a escuridão sair. *(Capítulo 51)*
8. **Percepção da IA** — o rangido é um **evento de ruído** que a Presença pode ouvir e investigar. Agora a porta é uma decisão tática do jogador: abrir devagar? *(Capítulo 36)*
9. **Narrativa** — abrir esta porta pela primeira vez pode disparar uma fala da operadora no rádio. Só na primeira vez. *(Capítulos 45–46)*
10. **Save** — se o jogador salvar com a porta aberta e carregar depois, a porta precisa estar aberta. Se ela foi destrancada por uma chave, a chave precisa continuar consumida. *(Capítulos 56–57)*
11. **Multiplayer** — se dois jogadores tentarem abrir a mesma porta ao mesmo tempo, quem ganha? Quem decide? Como o outro cliente vê a porta abrir? *(Capítulos 64–66)*
12. **Performance** — se a usina tem 80 portas, nenhuma delas deve consumir processamento quando está parada. *(Capítulo 60)*

Você não vai implementar tudo isso de uma vez — e esse é o segundo aprendizado do exemplo. **A primeira versão da porta, no Projeto 3, vai cobrir apenas interação, estado, movimento e colisão.** Áudio entra na Parte VII. Navegação e percepção entram na Parte V. Narrativa entra na Parte VI. Save entra na Parte VIII. Multiplayer, na Parte IX. A cada etapa, a porta ganha uma nova responsabilidade — e você vai ter que decidir se ela continua sendo responsabilidade *da porta*, ou se pertence a um sistema separado que *observa* a porta.

Essa pergunta — "isto é responsabilidade do objeto, ou de um sistema que reage a ele?" — é uma das perguntas centrais da arquitetura de jogos, e você vai respondê-la de formas diferentes ao longo do livro.

### Um esboço da porta como estado + tempo

Para tornar concreto o item 2 e o item 3, veja um esboço em C++ no estilo da Unreal. **Ainda não é código para compilar** — a versão real nasce no Capítulo 19. O objetivo aqui é ver duas ideias deste capítulo no código: o estado tem mais nuances do que "aberto/fechado", e o tempo entra como parâmetro.

```cpp
// Esboço conceitual (Cap. 1). A implementação real está no Cap. 19.
enum class EVGDoorState : uint8
{
    Closed,
    Opening,
    Open,
    Closing,
    Locked
};

void AVGDoor::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    // O tempo é uma entrada: a porta avança proporcionalmente ao Δt,
    // não "um pouco por frame". A 30 ou a 144 FPS, ela leva OpenDuration segundos.
    if (State == EVGDoorState::Opening)
    {
        OpenAlpha = FMath::Min(OpenAlpha + DeltaSeconds / OpenDuration, 1.0f);
        ApplyRotation(OpenCurve->GetFloatValue(OpenAlpha)); // curva: devagar → rápido → devagar

        if (OpenAlpha >= 1.0f)
        {
            State = EVGDoorState::Open;
            SetActorTickEnabled(false); // parada, não custa nada por frame
            OnDoorOpened.Broadcast(this); // outros sistemas (áudio, narrativa, IA) reagem
        }
    }
    // ... Closing é simétrico
}
```

Repare em três detalhes que voltarão muitas vezes:

- `DeltaSeconds / OpenDuration` — o progresso depende do tempo real, não do número de frames.
- `SetActorTickEnabled(false)` — um objeto parado não deveria pagar custo por frame.
- `OnDoorOpened.Broadcast(this)` — a porta não chama o sistema de áudio, de narrativa ou de IA. Ela **anuncia** que abriu, e quem se interessa reage. É o primeiro sinal de uma decisão de arquitetura que o Capítulo 24 vai discutir em profundidade.

---

## Estudo de caso: Alan Wake — como a luz se torna mecânica

> **Pergunta:** como iluminação pode ser transformada de elemento visual em mecânica de gameplay?

Este é o primeiro uso da Ficha de Decomposição. Vamos aplicá-la com cuidado, separando o que é fato do que é inferência.

### O que é publicamente conhecido

**[FATO PÚBLICO]** Em *Alan Wake* (Remedy Entertainment, 2010), os inimigos principais — os *Taken*, pessoas possuídas por uma presença sombria — são protegidos por uma camada de escuridão. Enquanto essa proteção existe, armas de fogo não os ferem de forma efetiva. O jogador precisa primeiro **apontar a lanterna** para o inimigo para "queimar" essa escuridão; só então os tiros causam dano. A lanterna tem um modo de foco intensificado que consome bateria, e baterias são recursos coletados pelo cenário. Sinalizadores e granadas de luz funcionam como ferramentas de controle de grupo. Fontes de luz fixas no ambiente (como postes de iluminação) funcionam como **refúgios**: a área iluminada protege o jogador e, em vários pontos, funciona como ponto de recuperação e de *checkpoint*. Tudo isso é observável jogando, e é amplamente descrito em análises e materiais de divulgação do jogo.

Esse é o nível de afirmação que podemos fazer com segurança. A partir daqui, tudo é análise de design e inferência técnica.

### 1. Experiência — o que o jogo está tentando produzir?

Um *thriller* psicológico em que a escuridão é ameaça e a luz é esperança frágil. O jogador deve sentir que a escuridão é ativa e hostil, que a segurança é temporária e precisa ser conquistada, e que cada encontro exige uma sequência de ações — não apenas apontar e atirar.

### 2. Sistema — o que produz essa experiência?

Um único conceito — **luz** — atravessa vários sistemas ao mesmo tempo:

```text
                 LUZ
                  │
   ┌──────────────┼──────────────┬──────────────────┐
   ▼              ▼              ▼                  ▼
 ARMA           RECURSO        ESPAÇO            LINGUAGEM
 remove a       bateria e      zonas seguras,    visual e
 proteção do    sinalizadores  checkpoints,      narrativa:
 inimigo        são escassos   rotas de fuga     luz = sanidade,
                                                 escuro = ameaça
```

E a sequência de combate vira uma pequena cadeia causal:

```text
Light
 ↓
Player Strategy        (para onde aponto? gasto bateria agora ou depois?)
 ↓
Enemy Vulnerability    (o inimigo só fica vulnerável sob luz)
 ↓
Combat                 (luz + tiro: duas ações coordenadas, não uma)
 ↓
Narrative Atmosphere   (a regra de combate É a história: a escuridão é o vilão)
```

### 3. Design — qual decisão está por trás?

**Transformar um elemento estético em regra.** A luz já estaria no jogo de qualquer forma, como ferramenta de atmosfera. A decisão de design foi dar a ela uma **função mecânica** — e fazer essa função coincidir com o tema da história. O combate não é um sistema separado da narrativa; ele é a narrativa em forma jogável.

Uma segunda decisão importante: **dividir o ato de derrotar um inimigo em duas etapas** (expor com luz, depois ferir). Isso aumenta a carga cognitiva do jogador em cada encontro, desacelera o combate, cria tensão com grupos (enquanto você ilumina um, outro se aproxima) e torna a gestão de recursos relevante. Um shooter convencional pode ter dezenas de inimigos por minuto; um sistema de duas etapas naturalmente leva a encontros com menos inimigos e mais peso.

### 4. Tecnologia — como isso poderia ser implementado?

**[INFERÊNCIA]** A seguir, uma hipótese técnica plausível, sem nenhuma afirmação sobre o código real da Remedy:

- A lanterna pode ser modelada como um **cone** a partir da câmera. A cada frame (ou a intervalos curtos), o jogo verifica se cada inimigo próximo está dentro do cone — um **produto escalar** entre a direção da lanterna e a direção para o inimigo, comparado com o cosseno do ângulo do cone — e se há **linha de visão** (um *line trace* que não bate em parede antes).
- Cada inimigo pode ter um valor de "escudo de escuridão" que **diminui proporcionalmente ao tempo de exposição** (Δt!) e à intensidade da luz, e **se regenera** quando ele sai da luz.
- Quando o escudo chega a zero, o inimigo entra num estado "vulnerável", que habilita o dano das armas.
- Zonas seguras podem ser **volumes** associados às fontes de luz fixas; entrar no volume dispara eventos (recuperação, checkpoint, inimigos recuando).

Note como a implementação usa ideias deste capítulo: tempo como entrada, estado com mais de dois valores, eventos ao mudar de estado, e "smoke and mirrors" — o jogo não precisa simular a física da luz, apenas um cone e uma linha.

### 5. Versão mínima — como eu faria em escala pequena?

**[SIMPLIFICAÇÃO DIDÁTICA]** Uma versão mínima, que você poderá implementar ao final da Parte IV com o que terá aprendido:

```cpp
// Esboço didático — não reflete nenhuma implementação comercial.
// Componente anexado a um inimigo: um "escudo" que a luz desgasta.
void UVGDarknessShieldComponent::TickComponent(float DeltaSeconds, ...)
{
    const bool bLit = IsLitByPlayerFlashlight(); // cone (dot product) + line trace

    if (bLit)
    {
        Shield = FMath::Max(Shield - BurnRatePerSecond * DeltaSeconds, 0.0f);
    }
    else
    {
        Shield = FMath::Min(Shield + RegenRatePerSecond * DeltaSeconds, MaxShield);
    }

    const bool bNowVulnerable = (Shield <= 0.0f);
    if (bNowVulnerable != bVulnerable)
    {
        bVulnerable = bNowVulnerable;
        OnVulnerabilityChanged.Broadcast(bVulnerable); // VFX, áudio, IA reagem
    }
}
```

E o sistema de dano (Capítulo 22) simplesmente ignora — ou reduz drasticamente — dano enquanto `bVulnerable` for falso.

### 6. Lição — o que levo para os meus projetos?

**As melhores mecânicas servem a várias camadas ao mesmo tempo.** A luz em Alan Wake é simultaneamente arma, recurso, geografia e tema. Isso é eficiente em todos os sentidos: um único sistema técnico sustenta combate, exploração, ritmo e narrativa, e o jogador aprende uma regra que vale para tudo.

Para a Vigília, essa lição vira um pilar de design, mas **com outra forma**: em vez de luz como arma contra muitos inimigos, a luz será principalmente **território** — a rede elétrica da usina, que o jogador religa setor por setor, define onde a Presença pode ou não pode ir. A lanterna existe, mas sua bateria é curta, e sua função principal é *ver*, não *lutar*. Mesma lição, mecânica diferente. É isso que significa "inspiração conceitual".

---

## Decisões arquiteturais deste capítulo

Este capítulo não tomou decisões de código, mas estabeleceu **princípios de decisão** que serão aplicados em todo o livro:

1. **A experiência percebida é o critério final.** Quando dois designs técnicos forem possíveis, escolhemos o que produz a melhor experiência dentro do orçamento — não o mais fiel ou o mais elegante.
2. **Simular só o que o jogador percebe ou explora.** O resto pode ser falsificado.
3. **Todo trabalho por frame tem custo multiplicado.** Antes de colocar algo no `Tick`, pergunte quantos objetos vão executá-lo e com que frequência.
4. **Objetos anunciam, sistemas reagem.** Preferimos que um objeto emita um evento ("abri") a que ele conheça todos os sistemas interessados.
5. **Começar pequeno e deixar o sistema crescer com motivo.** A porta começa com quatro responsabilidades, não doze.
6. **Código e dados têm papéis diferentes.** Comportamento em código; números e variações em dados editáveis.

---

## Armadilhas

- **Tratar o jogo como um CRUD com gráficos.** Modelar tudo como comandos e respostas, ignorando que o mundo evolui sozinho no tempo. Sintoma: lógica que só "acontece" quando o jogador aperta um botão, e um mundo que parece morto.
- **Arquitetar antes de jogar.** Passar semanas desenhando camadas, interfaces e um "framework de gameplay" antes de ter algo jogável. Em jogos, a arquitetura certa só fica clara depois que você sabe o que é divertido.
- **Escrever uma engine.** A versão extrema da armadilha anterior: construir sistemas genéricos sobre a Unreal "para o futuro". O futuro raramente chega no formato previsto.
- **Confundir fidelidade com qualidade.** Simular física realista onde o jogador queria resposta imediata; IA que joga perfeitamente onde o jogador queria um adversário legível.
- **Ignorar o orçamento de frame até o final.** Descobrir na Parte XI que um sistema central custa 8 ms por frame é muito mais caro do que ter pensado nisso na Parte III.
- **Achar que "funciona" significa "pronto".** O sistema que funciona sem ter sido jogado e ajustado está, no máximo, na metade do caminho.
- **Escopo grande demais.** O erro mais comum de quem começa: querer fazer um mundo aberto, um FPS multiplayer ou um RPG com 40 horas. A Vigília tem 10–20 minutos por um motivo.

---

## Exercício — Fichas de Decomposição

Escolha **três jogos de três famílias diferentes** entre suas referências (por exemplo: um da Remedy, um de terror e um FPS ou um de futebol). Para cada um, escolha **uma única mecânica** e preencha a ficha:

```text
JOGO:
MECÂNICA:

1. EXPERIÊNCIA    O que o jogador deve sentir?
2. SISTEMA        Quais sistemas produzem isso? (liste 2–5)
3. DESIGN         Qual decisão de design está por trás?
4. TECNOLOGIA     [INFERÊNCIA] Como poderia ser implementado?
                  (estado, tempo, eventos, verificações espaciais)
5. VERSÃO MÍNIMA  Descreva em até 10 linhas uma versão que você
                  conseguiria construir sozinho.
6. LIÇÃO          O que essa mecânica ensina para a Vigília?

FATOS vs. INFERÊNCIAS: marque cada afirmação com [FATO PÚBLICO]
ou [INFERÊNCIA].
```

Sugestões de mecânicas, se precisar de ponto de partida:

- **Outlast** — a câmera com visão noturna que consome baterias.
- **Amnesia: The Dark Descent** — a relação entre escuridão, sanidade e inimigos.
- **Control** — documentos e registros espalhados pela Oldest House.
- **Call of Duty** — o *hit marker* (o pequeno sinal visual e sonoro quando um tiro acerta).
- **PES / FIFA** — o passe com assistência de direção.
- **GTA San Andreas** — o *wanted level* (nível de procurado).

**Tempo estimado:** 2–3 horas. Guarde as fichas no repositório (`docs/fichas/`). Você vai revisitá-las no Capítulo 5 e no Capítulo 76.

---

## Desafio — o passe em PES/FIFA

Decomponha o **passe** num jogo de futebol com o mesmo nível de detalhe usado na porta. Comece pelo input (o botão e a direção do analógico) e chegue até o resultado na tela. Algumas perguntas para guiar:

- O jogo usa a direção exata do analógico, ou "corrige" o passe para o companheiro mais provável? Por quê? *(Pense em 1.2 e 1.3.)*
- Quanto tempo passa entre apertar o botão e a bola sair do pé? O que acontece nesse intervalo? *(Animação, timing.)*
- O que os outros 21 jogadores fazem enquanto a bola viaja? *(IA de time, posicionamento.)*
- O que muda se o passe for feito durante uma corrida, de costas, ou pressionado por um marcador?
- **Bônus — antecipação da Parte IX:** jogando com seu primo no mesmo console, os dois veem exatamente a mesma bola. O que teria que mudar se cada um estivesse em uma cidade, com 80 ms de latência entre vocês?

Desenhe o resultado como um diagrama de sistemas (como o da porta) e uma cadeia causal (como a da luz em Alan Wake).

---

## Uso de IA

Prompts sugeridos para aprofundar este capítulo. Lembre-se da regra: use a IA para testar e ampliar o seu raciocínio, não para substituí-lo.

1. **Para ampliar uma Ficha de Decomposição (depois de você ter feito a sua):**
   > "Preenchi a ficha de decomposição abaixo sobre a mecânica X do jogo Y. Atue como um game designer sênior. Identifique: (a) sistemas que eu deixei de listar; (b) afirmações que apresentei como fato mas que são inferências; (c) uma versão mínima mais simples que a minha. Não invente detalhes de implementação do jogo real; quando especular, diga explicitamente que está especulando. [ficha]"

2. **Para estressar o modelo mental:**
   > "Sou engenheiro backend (Java, microsserviços, Kubernetes). Liste 10 decisões de arquitetura que seriam boas práticas no meu contexto e que seriam más decisões no código de gameplay de um jogo em tempo real. Para cada uma, explique o porquê em termos de orçamento de frame, iteração de design ou estado em memória."

3. **Para treinar a distinção fato/inferência:**
   > "Sobre o jogo [nome], separe em duas listas: (1) o que é publicamente conhecido sobre a mecânica [X], com a fonte provável (jogabilidade observável, entrevista, talk), e (2) o que seriam inferências técnicas sobre a implementação. Se não tiver certeza de que algo é público, coloque na segunda lista."

4. **Para antecipar sistemas:**
   > "Uma porta em um jogo de terror em primeira pessoa precisa interagir com quais sistemas? Organize por prioridade de implementação para um protótipo, um vertical slice e um jogo completo."

**Cuidado específico deste capítulo:** IAs tendem a "completar" lacunas sobre jogos comerciais com detalhes plausíveis e inventados ("o jogo usa um sistema X baseado em Y"). Sempre que a resposta afirmar algo específico sobre a implementação de um jogo real, pergunte: *qual é a fonte?* Se não houver fonte verificável, trate como inferência.

---

## Checklist

- [ ] Consigo explicar, com minhas palavras, por que um jogo é "simulação", "interativo" e "tempo real", e o que cada palavra implica para a engenharia.
- [ ] Sei de cor o orçamento de frame para 30, 60 e 120 FPS.
- [ ] Consigo dar dois exemplos em que o comportamento "correto" é pior para o jogador do que um comportamento "trapaceado".
- [ ] Entendo por que o estado de um jogo vive na memória, e por que a lógica de gameplay costuma ser sequencial.
- [ ] Entendo por que movimento e efeitos devem depender de Δt, e não do número de frames.
- [ ] Consigo listar pelo menos oito sistemas que uma porta pode tocar em um jogo de terror.
- [ ] Preenchi três Fichas de Decomposição, separando fatos de inferências.
- [ ] Consigo explicar por que a luz em Alan Wake é um bom exemplo de mecânica que serve a várias camadas.

---

## Para ir além

- **Robert Nystrom, *Game Programming Patterns*** — leia a introdução ("Architecture, Performance, and Games"), que discute exatamente a tensão entre arquitetura flexível e performance em jogos. Gratuito em gameprogrammingpatterns.com.
- **Jesse Schell, *The Art of Game Design: A Book of Lenses*** — os capítulos iniciais sobre experiência são a melhor introdução ao "requisito é a experiência".
- **Jason Gregory, *Game Engine Architecture*** — Capítulo 1 (Introdução), para uma visão geral de como uma engine é organizada e de quem faz o quê num time de jogos.

---

➡️ **Próximo:** [Capítulo 2 — Game Loop](cap-02-game-loop.md)

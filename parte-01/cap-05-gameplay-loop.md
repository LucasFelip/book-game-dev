# Capítulo 5 — Gameplay Loop

## Objetivo

Ao final deste capítulo você deve conseguir:

- definir **core loop** e **loops aninhados** (segundo, minuto, sessão, meta) e identificá-los em qualquer jogo;
- usar o modelo **MDA** (mecânicas, dinâmicas, estética) para separar "o que eu programo" de "o que o jogador sente";
- reconhecer **laços de realimentação positivos e negativos** e prever as dinâmicas que eles produzem;
- entender **feedback ao jogador** (*juice*) como sistema, não como enfeite;
- explicar como regras simples produzem **gameplay emergente**, usando PES/FIFA como referência;
- escrever o **documento de loops da Vigília**, que guiará todos os projetos seguintes.

Este é o capítulo em que o livro muda de lado da mesa: até aqui, o game loop foi uma estrutura de engenharia. Agora ele vira uma estrutura de **experiência**.

---

## Contexto

Os Capítulos 2 e 3 trataram do *game loop* técnico: o laço que roda 60 vezes por segundo. Existe outro laço, com o mesmo nome e uma natureza completamente diferente: o **gameplay loop**, a sequência de ações que o jogador repete ao longo do jogo e que, se for boa, ele quer repetir de novo.

Os dois laços se confundem no vocabulário, mas não na escala:

```text
GAME LOOP (técnico)                   GAMEPLAY LOOP (design)
───────────────────                   ──────────────────────
input → update → render               observar → decidir → agir → resultado
~16 ms por volta                      segundos a horas por volta
o programa repete                     o JOGADOR repete
correção = frame no prazo             correção = vontade de repetir
```

Para um engenheiro, o gameplay loop é desconfortável porque ele não é verificável por inspeção. Você pode ler o código de uma arma e saber que ela causa 25 de dano a 600 disparos por minuto. Não pode ler o código e saber se atirar com ela é **satisfatório**, nem se o ciclo "entrar na sala → atirar → recarregar → avançar" vai ser divertido na décima repetição. Isso se descobre jogando — mas pode, e deve, ser **projetado** antes, com a mesma disciplina com que você projeta um fluxo de sistema.

---

## 5.1 O que é um core loop

O **core loop** (laço central) é a menor sequência de ações que o jogador repete e que contém a essência do jogo. Se você remover o core loop, não sobra jogo; se o core loop for ruim, nenhuma quantidade de conteúdo o salva.

Algumas formulações, deliberadamente simplificadas:

```text
FPS multiplayer (COD)      spawn → mover → encontrar inimigo → atirar → matar/morrer → spawn
Horror de fuga (Outlast)   explorar → perceber ameaça → esconder/fugir → recuperar → avançar
Alan Wake                  explorar → emboscada → luz + tiro → refúgio de luz → avançar na história
Futebol (PES/FIFA)         ganhar a bola → construir a jogada → finalizar/perder a bola → defender
GTA (rua)                  dirigir/andar → oportunidade (missão, crime, evento) → agir → consequência
```

Três propriedades distinguem um bom core loop:

1. **Tem decisões.** Cada volta oferece escolhas significativas: rotas, recursos, riscos. "Apertar o mesmo botão em resposta ao mesmo estímulo" é um laço, mas não é um jogo.
2. **Tem resultado legível.** O jogador entende por que a volta deu certo ou errado — e, portanto, sabe o que mudar na próxima.
3. **Varia sem mudar.** As regras são as mesmas, mas as situações são diferentes a cada volta (outro mapa, outro inimigo, outra posição da bola). A variação vem de conteúdo, de sistemas ou de outros jogadores.

> 🌉 **Ponte:** o core loop é para o design o que o *happy path* do caso de uso principal é para um sistema: o fluxo que, se não funcionar perfeitamente, invalida todo o resto. E, como num sistema, a tentação é gastar esforço nas bordas (menus, progressão, cosméticos) antes de o caminho principal estar sólido.

---

## 5.2 Loops aninhados

Um jogo não tem um laço só. Ele tem **laços dentro de laços**, em escalas de tempo diferentes, cada um dando sentido ao de baixo:

```text
ESCALA          PERGUNTA DO JOGADOR                  EXEMPLO (FPS multiplayer)
──────          ───────────────────                  ─────────────────────────
Segundos        "Acertei?"                           mirar → atirar → hit marker
(micro-loop)

Dezenas de s    "Ganhei esse duelo?"                 encontrar → trocar tiros → abate/morte
(core loop)

Minutos         "Ganhamos a partida?"                capturar objetivos → placar → fim de partida
(macro-loop)

Sessão          "Evoluí hoje?"                       partidas → XP → nível → desbloqueio
(meta-loop)

Semanas         "Ainda quero voltar?"                temporadas, classes novas, desafios
(longo prazo)
```

O mesmo vale para um jogo narrativo, com outro conteúdo:

```text
ESCALA          VIGÍLIA (proposta)
──────          ──────────────────
Segundos        apontar a lanterna → ver → decidir para onde ir
Dezenas de s    entrar num ambiente → investigar → encontrar pista/recurso
Minutos         religar um setor elétrico → ameaça reage → sobreviver → zona segura
Sessão          setores religados → a história da usina se revela → final
```

Duas lições de engenharia saem desse diagrama.

**Cada escala tem sistemas diferentes.** O micro-loop é dominado por input, câmera, animação, áudio e feedback (Partes III, IV e VII). O core loop, por IA, combate e level design (Partes IV, V e VII). O macro-loop, por objetivos, quests, estado narrativo e spawn (Partes IV e VI). O meta-loop, por progressão e persistência (Parte VIII). Saber em que escala um problema mora diz em que sistema mexer.

**As escalas se constroem de baixo para cima.** Se o micro-loop for ruim — a mira é imprecisa, o tiro não tem peso —, nenhum sistema de progressão compensa. Por isso o livro constrói o personagem, a câmera e a arma (Partes III e IV) muito antes de quests e narrativa (Parte VI). E por isso o Projeto 2 é um FPS básico, mesmo que a Vigília quase não tenha combate: o micro-loop de olhar, mover e agir é o mesmo.

---

## 5.3 MDA: mecânicas, dinâmicas, estética

O modelo **MDA** — proposto por Robin Hunicke, Marc LeBlanc e Robert Zubek no artigo *MDA: A Formal Approach to Game Design and Game Research* (2004) — é a ferramenta conceitual mais útil para um engenheiro que entra em game design, porque separa exatamente o que você controla do que você quer produzir:

- **Mecânicas (M):** as regras e os componentes do jogo, no nível dos dados e algoritmos. *A bateria tem 100 de carga; a lanterna drena 2/s; a Presença não entra em áreas iluminadas.* **É o que você programa.**
- **Dinâmicas (D):** o comportamento que emerge quando as mecânicas rodam com um jogador dentro. *O jogador economiza a lanterna; corre entre zonas iluminadas; desliga a luz para não ser visto.* **Ninguém programa isso diretamente.**
- **Estética (A, de *aesthetics*):** as respostas emocionais desejadas no jogador. *Vulnerabilidade, tensão, alívio.* **É o requisito do Capítulo 1.**

```text
           DESIGNER / PROGRAMADOR                          JOGADOR
           enxerga da esquerda                       enxerga da direita
                    │                                          │
                    ▼                                          ▼
          ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
          │    MECÂNICAS    │ ──► │    DINÂMICAS    │ ──► │    ESTÉTICA     │
          │ regras, dados,  │     │ comportamento   │     │ o que o jogador │
          │ algoritmos      │     │ em execução     │     │ sente           │
          └─────────────────┘     └─────────────────┘     └─────────────────┘
```

A observação central do MDA é essa assimetria: **quem cria o jogo trabalha da esquerda para a direita; quem joga experimenta da direita para a esquerda.** O jogador nunca vê a regra "drena 2/s"; vê uma luz que vai morrer e sente medo. E o programador nunca escreve "medo"; escreve uma taxa de drenagem.

A implicação para o seu trabalho é profunda: **você não pode implementar uma estética diretamente. Só pode implementar mecânicas e observar se as dinâmicas resultantes produzem a estética desejada.** Por isso playtest não é opcional. E por isso, quando uma estética não aparece, a correção raramente é "adicionar mais coisas": é mudar uma mecânica e observar a nova dinâmica.

### Exemplo: a mesma mecânica, estéticas opostas

Considere a mecânica "a bateria da lanterna acaba". Com parâmetros diferentes, ela produz dinâmicas e estéticas diferentes:

| Parâmetro | Dinâmica observada | Estética resultante |
|---|---|---|
| Bateria dura 30 min; pilhas abundantes | Jogador ignora a bateria | Nenhuma (a mecânica é ruído) |
| Bateria dura 3 min; pilhas raras e escondidas | Jogador desliga a lanterna sempre que pode; explora no escuro; vasculha cada canto | **Tensão, escassez, vulnerabilidade** |
| Bateria dura 30 s; sem pilhas | Jogador desiste de usar a lanterna | Frustração |
| Bateria dura 3 min; recarrega em zonas iluminadas | Jogador planeja rotas entre zonas seguras | **Tensão com ritmo (tensão → alívio)** |

A última linha é, essencialmente, o desenho da Vigília. Nenhuma das quatro versões exige código diferente — só **dados** diferentes no `UVGBatteryComponent` do Capítulo 4. Esse é o motivo prático de separar código e configuração: a busca pela estética certa é feita **ajustando dados**, dezenas de vezes, e isso precisa ser barato.

> **[FATO PÚBLICO]** Em *Outlast* (Red Barrels, 2013), a câmera com visão noturna consome baterias, que são encontradas pelo cenário; sem bateria, a visão noturna para de funcionar, e muitos ambientes são escuros a ponto de serem praticamente impossíveis de enxergar sem ela.
>
> **[INFERÊNCIA]** A dinâmica que essa mecânica produz é a de **dependência de um recurso que permite ver o perigo** — o jogador precisa da câmera para navegar e, ao mesmo tempo, sabe que ela vai acabar. A estética é uma ansiedade constante de fundo, mesmo nos momentos sem inimigos. É um exemplo de mecânica que gera tensão **sem combate**, a pergunta do estudo de caso de Outlast que o livro aprofunda no Capítulo 36.

---

## 5.4 Laços de realimentação

Dinâmicas raramente são lineares. Muitas emergem de **laços de realimentação** (*feedback loops*) entre o estado do jogo e o desempenho do jogador. Há dois tipos.

### Realimentação positiva: quem está ganhando ganha mais

```text
jogador vai bem → ganha vantagem → fica mais fácil ir bem → ganha mais vantagem → ...
```

Exemplos: *killstreaks* em FPS multiplayer (abates em sequência liberam recompensas que facilitam mais abates); em estratégia, mais território produz mais recursos que conquistam mais território.

- **Dinâmica:** partidas que se decidem cedo e terminam rápido; vitórias esmagadoras; *snowball*.
- **Estética potencial:** sensação de poder e de recompensa para quem está ganhando; frustração para quem está perdendo.

### Realimentação negativa: quem está perdendo ganha ajuda

```text
jogador vai mal → recebe ajuda/compensação → volta a competir → ...
```

Exemplos: em jogos de corrida, o *rubber banding* (adversários controlados pela IA aceleram quando ficam para trás e desaceleram quando estão à frente); itens melhores para quem está em último; ajuste dinâmico de dificuldade.

- **Dinâmica:** partidas equilibradas até o fim; viradas.
- **Estética potencial:** tensão sustentada — e, se o jogador perceber, sensação de injustiça ("o jogo me roubou").

### No futebol

**[INFERÊNCIA]** Jogos de futebol são um caso interessante porque o próprio esporte tem mecanismos de realimentação embutidos nas regras: depois de um gol, a bola volta para o time que sofreu o gol (saída de bola) — uma realimentação negativa leve. Ao mesmo tempo, sistemas de jogo podem introduzir realimentações próprias, como o desgaste físico (cansaço que acumula) e o fator psicológico/momento em algumas simulações. Discussões entre jogadores sobre se certos jogos de futebol "ajudam" o time que está perdendo são frequentes e antigas — o que mostra o ponto central: **realimentação negativa percebida pelo jogador como intervenção arbitrária destrói a confiança no sistema**. Não há informação pública confiável que confirme ou negue esse tipo de mecanismo nesses jogos, e o livro não afirma nada sobre isso.

### Na Vigília

O nível de ameaça da Presença (Capítulo 4) é um sistema de realimentação, e sua direção é uma decisão de design consciente:

- se ruído aumenta a ameaça, e ameaça maior faz o jogador correr (que faz mais ruído), há **realimentação positiva** — tensão que escala até uma perseguição;
- se zonas seguras reduzem a ameaça e permitem recarregar a bateria, há **realimentação negativa** — o alívio que impede a tensão de virar frustração.

A curva de tensão da Vigília (seção 5.7) é, literalmente, o desenho da alternância entre esses dois laços.

---

## 5.5 Feedback: o sistema que traduz estado em sensação

Na seção 5.1, um bom core loop precisa de **resultado legível**. A legibilidade é produzida pelo **feedback**: tudo o que o jogo devolve ao jogador em resposta a uma ação. Em jogos, a palavra informal para feedback abundante e expressivo é **juice** — e é comum ouvir que um protótipo "precisa de mais juice".

Pense num único tiro de uma arma num FPS. A mecânica é: *um trace da câmera; se acertar, aplicar 25 de dano*. O jogador, porém, experimenta algo assim:

```text
                            UM TIRO (≈ 100 ms de experiência)
 ┌──────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
 │  0 ms        │  ~16 ms      │  ~30 ms      │  ~50 ms      │  ~100 ms+    │
 ├──────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
 │ som do       │ flash no     │ impacto:     │ hit marker   │ reação do    │
 │ disparo      │ cano         │ partículas,  │ + som de     │ alvo: anim., │
 │ recoil da    │ tremor de    │ decal, som   │ acerto       │ ragdoll,     │
 │ câmera       │ câmera       │ de material  │              │ grito        │
 │ anim. da arma│ cartucho     │              │              │              │
 └──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
   "eu atirei"    "foi forte"    "acertei ali"  "causei dano"  "teve efeito"
```

Cada camada responde a uma pergunta que o jogador faz em frações de segundo. Remova o hit marker e o jogador não sabe se acertou. Remova o recoil e a arma parece de brinquedo. Remova o som do impacto e a parede parece de papelão. A **mecânica não mudou** em nenhum desses casos — mas a estética mudou completamente.

**[FATO PÚBLICO]** O *hit marker* — a pequena marca na mira, acompanhada de um som característico, que confirma que um tiro acertou um inimigo — tornou-se um elemento de interface amplamente associado à série Call of Duty e adotado por muitos shooters desde então.

Três princípios de engenharia sobre feedback:

1. **Feedback é apresentação derivada (Capítulo 4).** O hit marker reage ao evento "dano aplicado". Ele nunca é a fonte da verdade sobre o acerto. Em multiplayer, essa distinção vira um problema real: o cliente pode mostrar o hit marker antes de o servidor confirmar o acerto, e às vezes o servidor discorda (Capítulo 68).
2. **Feedback é multicanal e sincronizado.** Áudio, visual, câmera, animação e (em consoles) vibração do controle precisam acontecer juntos. Um som 80 ms atrasado em relação ao flash do cano é percebido como "tiro mole".
3. **Feedback é proporcional.** Um tiro de pistola e uma explosão não podem ter o mesmo tremor de câmera. Isso exige **dados de configuração** por ação, e é por isso que o sistema de armas do Capítulo 26 terá feedback como parte dos dados da arma.

> 🌉 **Ponte:** feedback é, para o jogador, o que observabilidade é para você: a única janela para o estado interno do sistema. Um jogo sem feedback é um serviço sem logs, métricas e traces — ele pode estar funcionando perfeitamente, e ninguém consegue usá-lo com confiança.

### Game feel

**Game feel** é a sensação tátil e imediata de controlar algo no jogo — a soma do micro-loop: responsividade do input (Capítulos 2 e 3), movimento (Capítulo 25), câmera (Capítulo 18), animação (Capítulo 53), áudio (Capítulo 52) e feedback. O termo foi popularizado por Steve Swink, no livro *Game Feel: A Game Designer's Guide to Virtual Sensation* (2008).

Jogos de futebol são uma das melhores escolas de game feel, porque a ação principal — controlar um jogador e a bola — acontece o tempo inteiro, e qualquer imperfeição aparece imediatamente. Quando você jogava PES 2011 com seu primo, a diferença entre um drible que "saiu" e um que "não saiu" era uma combinação de:

- **resposta do controle** — o tempo entre mexer o analógico e o jogador reagir;
- **animação** — a transição entre correr, frear, girar, conduzir; e o compromisso que cada animação impõe (uma vez iniciada, por quanto tempo ela "prende" o jogador?);
- **física e regras da bola** — quanto a bola se afasta do pé a cada toque;
- **timing** — janelas de tempo em que um comando é aceito;
- **câmera** — o enquadramento que permite ou não enxergar o espaço;
- **áudio e feedback** — o som do toque, a reação da torcida.

**[INFERÊNCIA]** Existe uma tensão central em jogos esportivos com animações realistas: animações longas e detalhadas parecem mais naturais, mas **atrasam a resposta** ao input, porque o personagem precisa "terminar" um movimento antes de começar outro. Jogos que priorizam responsividade cortam ou misturam animações mais cedo; jogos que priorizam realismo visual deixam o jogador "preso" por mais tempo. Discussões de jogadores sobre um jogo de futebol estar "pesado" ou "arcade" são, em grande parte, discussões sobre onde esse compromisso foi posicionado. Voltaremos a essa tensão — responsividade vs. fidelidade de animação — no Capítulo 53.

---

## 5.6 Gameplay emergente

**Gameplay emergente** é a situação em que regras relativamente simples, interagindo entre si e com o jogador, produzem situações que ninguém roteirizou. É a dinâmica do MDA no seu estado mais rico.

O futebol — real e virtual — é o exemplo perfeito. As regras cabem numa página. As mecânicas de um jogo de futebol (correr, passar, chutar, desarmar, a física da bola, o posicionamento da IA) são finitas. E, ainda assim, duas partidas nunca são iguais:

```text
Input (dois jogadores humanos)
  ↓
Player (o atleta controlado)
  ↓
Game Rules (impedimento, faltas, posse)
  ↓
Physics / Animation / AI (bola, colisões, posicionamento de 20 atletas)
  ↓
Game State (placar, posições, cansaço, tempo)
  ↓
New Situation (um espaço que abriu, um contra-ataque)
  ↓
Player Response (o seu primo percebe e corre)
  ↓
... (a situação seguinte depende de tudo isso)
```

O ingrediente decisivo é que **cada saída vira entrada**. O estado resultante de um lance é o ponto de partida do próximo, e pequenas diferenças (a bola quicou um pouco para a esquerda) se amplificam. Em sistemas, você conhece isso como sensibilidade a condições iniciais.

**Quando há outro humano no laço**, a emergência se multiplica: a "IA" adversária é uma pessoa que aprende, blefa, se adapta e tem um jeito próprio de jogar. É por isso que partidas locais com primos e amigos produzem histórias que se contam por anos, mesmo num jogo com regras fixas — **o conteúdo é gerado pela interação**, não pelo designer.

### Emergência vs. roteiro

Jogos ficam num espectro:

```text
TOTALMENTE ROTEIRIZADO ◄─────────────────────────────────────────► TOTALMENTE SISTÊMICO
  corredor linear,                Alan Wake, Outlast,          GTA (rua),         futebol,
  cinemática, QTE                 Amnesia (eventos            Control (física     multiplayer
                                  roteirizados + IA)          e poderes)          competitivo
```

- **Roteiro** garante a experiência: o susto acontece na hora certa, a cena tem o enquadramento certo. Custa conteúdo (cada momento é feito à mão) e reduz a agência.
- **Sistemas** produzem variedade e agência a custo de conteúdo baixo, mas não garantem nada: o susto pode não acontecer, ou acontecer na hora errada.

Jogos narrativos de terror vivem no meio: **sistemas para produzir tensão contínua** (IA que caça, recursos escassos, percepção) e **roteiro para produzir os picos** (o primeiro encontro, a revelação, a perseguição). A arquitetura da Vigília reflete isso: sistemas nas Partes V e VII, roteiro na Parte VI, e o *AI Director* (Capítulo 42) como ponte entre os dois.

---

## 5.7 Pacing: o loop no tempo

Os loops descrevem **o que** o jogador repete. O **pacing** (ritmo) descreve **como a intensidade varia** ao longo das repetições. Em jogos de ação e terror, uma ferramenta simples e poderosa é a **curva de tensão**:

```text
tensão
  ▲
  │                                               ╭╮  perseguição
  │                         ╭╮                   ╭╯╰╮
  │             ╭╮         ╭╯╰╮   susto         ╭╯   ╰╮
  │   ╭╮       ╭╯╰╮       ╭╯   ╰╮              ╭╯     │
  │  ╭╯╰╮     ╭╯   ╰╮    ╭╯     ╰─╮          ╭─╯      │   revelação
  │ ╭╯   ╰╮  ╭╯      ╰───╯        ╰──╮    ╭──╯        ╰──────╮
  │─╯      ╰─╯ zona                  ╰────╯ zona              ╰── fim
  │          segura                         segura
  └───────────────────────────────────────────────────────────────────► tempo
     chegada   setor A            setor B            setor C
```

A regra básica do pacing é que **tensão constante deixa de ser tensão**. O cérebro se acostuma. O medo depende de contraste — e o alívio é tão projetado quanto o susto. Em jogos de terror, as zonas seguras, os momentos de exploração calma e as pausas narrativas não são "tempo morto": são o que dá aos picos o seu efeito.

> **[INFERÊNCIA]** Jogos como Amnesia: A Machine for Pigs e Outlast alternam longos trechos de exploração e narrativa ambiental, sem ameaça imediata, com encontros curtos e intensos. A expectativa de que algo vai acontecer — construída por som, luz e documentos — sustenta a tensão nos trechos calmos. É o conceito de *tensão criada pela expectativa do jogador*, que o livro desenvolve no Capítulo 48 (narrativa ambiental) e no Capítulo 52 (áudio).

Para a engenharia, o pacing tem uma consequência concreta: **o ritmo precisa ser controlável por dados e por conteúdo**, não enterrado em código. Quanto tempo a Presença leva para reagir, quantos recursos existem no setor B, onde ficam as zonas seguras, quando um evento roteirizado acontece — tudo isso será ajustado em playtest, muitas vezes.

---

## Comparação com o desenvolvimento tradicional

| Conceito de jogos | O que você conhece | Onde ajuda | Onde a analogia cai |
|---|---|---|---|
| Core loop | Fluxo principal / *happy path* | Priorizar o essencial | O critério é "quero repetir", não "consegui concluir" |
| Loops aninhados | Jornadas de usuário em escalas (tarefa, sessão, retenção) | Pensar em escalas de tempo | Em produtos corporativos, o ideal é o usuário terminar rápido; em jogos, é ele querer continuar |
| MDA | Requisitos funcionais vs. objetivos de negócio | Separar o que se implementa do que se quer | A relação M → A não é rastreável; só observável |
| Realimentação | Laços de controle, autoscaling, *backpressure* | Prever estabilidade e oscilação | Aqui, a instabilidade às vezes é **desejada** (escalada de tensão) |
| Feedback / juice | Observabilidade; UX de confirmação | Legibilidade do estado | Precisa ser sincronizado em dezenas de ms e ter valor estético |
| Emergência | Comportamento emergente de sistemas distribuídos | Entender interações não lineares | Em sistemas, emergência costuma ser um risco; em jogos, é um objetivo |

A última linha resume a inversão de valores: em sistemas distribuídos, comportamento emergente é aquilo que derruba produção às 3 da manhã. Em jogos, é aquilo que faz uma partida ser lembrada por anos.

---

## Unreal Engine: onde os loops aparecem

O gameplay loop não é uma classe da Unreal; é uma estrutura de design que se distribui por vários sistemas que você vai construir:

| Escala | Sistemas na Unreal | Capítulos |
|---|---|---|
| Micro (segundos) | Enhanced Input, Character Movement, Camera Manager, Animation Blueprint, Niagara, MetaSounds, Camera Shakes, Force Feedback | 14, 17, 18, 25, 29, 52–54 |
| Core (dezenas de s) | AI (Behavior Trees, Perception), sistema de dano, armas, level design | 22, 26–30, 33–42, 50 |
| Macro (minutos) | GameMode, GameState, objetivos, quests, estado narrativo, spawn | 10, 31, 32, 45–46 |
| Meta (sessão+) | SaveGame, progressão, GameInstance | 56–57 |

Uma observação de arquitetura: a **regra de cada loop** costuma ter um dono claro (Capítulo 4). As regras da partida pertencem ao **GameMode**; o estado da partida, ao **GameState**; a progressão da sessão, a algo que sobrevive à troca de nível (**GameInstance** ou um subsistema dele) e ao **save**. O Capítulo 10 formaliza essa divisão.

---

## Exemplo: o documento de loops da Vigília

Até aqui a Vigília tinha pilares (Introdução, seção 6). Agora ela ganha loops — a primeira peça de design formal do projeto. Este documento será revisado no Capítulo 76, mas já orienta tudo que vem antes.

```text
VIGÍLIA — DOCUMENTO DE LOOPS (v0.1)

ESTÉTICA-ALVO (o que o jogador deve sentir)
  1. Vulnerabilidade   — "não estou no controle desta usina"
  2. Curiosidade       — "preciso saber o que aconteceu"
  3. Alívio conquistado — "consegui religar a luz; aqui estou seguro, por enquanto"

MICRO-LOOP (segundos)
  olhar → iluminar → perceber → mover
  Mecânicas: câmera em 1ª pessoa, lanterna com bateria, passos com ruído,
             interação contextual.
  Feedback: feixe da lanterna, som dos próprios passos, respiração,
            flicker em bateria fraca.

CORE LOOP (dezenas de segundos)
  entrar num ambiente → investigar → encontrar (pista | recurso | caminho)
  → decidir arriscar ou recuar
  Mecânicas: documentos, objetos interativos, baterias, portas, ruído.

MACRO-LOOP (minutos) — um SETOR da usina
  chegar ao setor escuro → explorar sob ameaça → localizar o painel
  → religar a energia (puzzle simples) → a Presença reage (pico)
  → sobreviver / fugir → setor iluminado vira zona segura → revelação narrativa
  Mecânicas: rede elétrica, nível de ameaça, IA da Presença, eventos roteirizados,
             checkpoint ao religar.

SESSÃO (10–20 min)
  3 setores + prólogo + final
  Progressão: mais da usina iluminada, mais da história revelada,
              ameaça mais agressiva a cada setor.

REALIMENTAÇÃO
  Positiva: ruído → ameaça ↑ → pressa → mais ruído (escalada até perseguição)
  Negativa: zona iluminada → ameaça ↓, bateria recarrega (alívio)

PERGUNTAS ABERTAS (respondidas por playtest)
  - Quanto tempo a bateria deve durar para tensão sem frustração?
  - O jogador entende sozinho que luz = segurança?
  - O pico após religar um setor é previsível demais na 3ª vez?
```

Repare que o documento tem uma seção de **perguntas abertas**. Isso não é sinal de documento incompleto; é o reconhecimento do MDA de que estética só se valida jogando. Cada pergunta é uma hipótese de design com um critério de verificação — o equivalente, em design, a uma hipótese de experimento.

---

## Implementação: vendo uma dinâmica emergir

Este capítulo é de design, mas há uma forma de um engenheiro **sentir** a diferença entre mecânica e dinâmica sem nenhuma arte: simular. O programa abaixo simula 10.000 "partidas" entre dois jogadores de habilidade **igual**, com três regras de mecânica diferentes, e mede a dinâmica resultante: com que frequência a partida é decidida cedo e quantas viradas acontecem.

```cpp
// feedback_loops.cpp — g++ -std=c++20 -O2 feedback_loops.cpp -o feedback_loops
#include <cstdio>
#include <random>

enum class Rule { Neutral, Positive, Negative };

struct Stats
{
    int DecidedEarly = 0;   // partidas em que o vencedor já liderava por 3+ na metade
    int Comebacks = 0;      // partidas vencidas por quem perdia na metade
};

// Uma "partida": 20 disputas. Cada disputa vale 1 ponto.
// A regra altera a chance de vencer a disputa conforme o placar.
Stats Simulate(Rule R, int Matches, unsigned Seed)
{
    std::mt19937 Rng(Seed);
    std::uniform_real_distribution<double> Roll(0.0, 1.0);
    Stats S;

    for (int M = 0; M < Matches; ++M)
    {
        int A = 0, B = 0, HalfDiff = 0;
        for (int Round = 0; Round < 20; ++Round)
        {
            const int Diff = A - B;
            double ChanceA = 0.5;                                   // habilidades iguais
            if (R == Rule::Positive) { ChanceA += 0.04 * Diff; }    // quem lidera ganha força
            if (R == Rule::Negative) { ChanceA -= 0.04 * Diff; }    // quem perde ganha ajuda
            ChanceA = ChanceA < 0.05 ? 0.05 : (ChanceA > 0.95 ? 0.95 : ChanceA);

            (Roll(Rng) < ChanceA) ? ++A : ++B;
            if (Round == 9) { HalfDiff = A - B; }
        }

        const int Final = A - B;
        if ((HalfDiff >= 3 && Final > 0) || (HalfDiff <= -3 && Final < 0)) { ++S.DecidedEarly; }
        if ((HalfDiff < 0 && Final > 0) || (HalfDiff > 0 && Final < 0))   { ++S.Comebacks; }
    }
    return S;
}

int main()
{
    const int N = 10000;
    const char* Names[] = { "Neutra  ", "Positiva", "Negativa" };
    const Rule Rules[] = { Rule::Neutral, Rule::Positive, Rule::Negative };

    std::printf("Regra      Decididas cedo   Viradas\n");
    for (int i = 0; i < 3; ++i)
    {
        const Stats S = Simulate(Rules[i], N, 1234u);
        std::printf("%s   %6.1f%%          %6.1f%%\n",
                    Names[i], 100.0 * S.DecidedEarly / N, 100.0 * S.Comebacks / N);
    }
    return 0;
}
```

Rode e observe. A **mecânica** mudou num único número (`±0.04 × Diff`). A **dinâmica** — quantas partidas são decididas cedo, quantas viradas acontecem — muda de forma clara e mensurável. E a **estética** que você inferiria disso (partidas tensas até o fim, ou atropelos) é algo que nenhuma linha do código menciona.

Esse tipo de simulação tem nome na indústria: **simulação de balanceamento**. Designers e programadores usam planilhas e scripts para prever dinâmicas de economia, progressão e combate antes de colocar um humano para jogar. Ela não substitui o playtest — o seu primo não é uma variável aleatória com probabilidade 0,5 —, mas elimina hipóteses ruins de forma barata. A Parte X (Capítulo 70) mostra como usar IA para acelerar esse tipo de análise.

---

## Decisões arquiteturais

1. **A Vigília tem um documento de loops versionado** (`docs/design/loops.md`), revisado a cada projeto. Mudanças de design entram no `DEVLOG.md` com a hipótese e o resultado do playtest.
2. **Micro-loop primeiro.** Nenhum sistema de macro-loop (quests, narrativa) será construído antes de o movimento, a câmera e a interação estarem bons de usar.
3. **Todo parâmetro que afeta pacing é dado, não código.** Bateria, ameaça, tempos de reação da IA, recursos por setor.
4. **Feedback é tratado como sistema.** Cada ação relevante terá feedback multicanal configurável por dados (armas no Capítulo 26, interação no Capítulo 19).
5. **Realimentações são projetadas e nomeadas.** Para cada sistema com realimentação, o documento de loops diz qual é a direção e qual estética se espera.

---

## Armadilhas

- **Projetar a meta antes do core.** Árvores de progressão, sistemas de XP e cosméticos sobre um core loop que ainda não é bom.
- **Confundir mecânica com estética.** "Vou adicionar uma mecânica de medo." Não existe; existem mecânicas que, com sorte e ajuste, produzem medo.
- **Realimentação positiva sem freio.** Tensão que escala sem nenhuma válvula de alívio vira frustração — ou, num jogo competitivo, partidas decididas no primeiro minuto.
- **Realimentação negativa visível.** Ajuda ao jogador que perde, percebida como trapaça do sistema.
- **Feedback escasso ou dessincronizado.** Ações sem confirmação clara, ou com som e imagem fora de sincronia.
- **Tensão constante.** Em terror, ausência de vales destrói os picos.
- **Acreditar que roteiro resolve tudo.** Momentos roteirizados não escalam e não respondem ao jogador; sistemas sem roteiro não garantem os picos. Jogos narrativos precisam dos dois.

---

## Exercício

**Parte 1 — loops das suas referências (1,5 h).** Retome as três Fichas de Decomposição do Capítulo 1. Para cada jogo, escreva os loops em quatro escalas (micro, core, macro, sessão), no formato do documento da Vigília. Identifique pelo menos um laço de realimentação positiva e um de negativa em cada jogo, marcando o que é **[FATO PÚBLICO]** e o que é **[INFERÊNCIA]**.

**Parte 2 — MDA de uma mecânica (45 min).** Escolha uma mecânica da Vigília (bateria, ruído dos passos, zonas iluminadas, documentos). Monte uma tabela como a da seção 5.3: quatro configurações de parâmetros, a dinâmica que você espera de cada uma e a estética resultante. Qual você testaria primeiro? Por quê?

**Parte 3 — simulação (1 h).** Rode o `feedback_loops.cpp`. Depois:
1. Varie o coeficiente (0,02, 0,04, 0,08) e observe a sensibilidade da dinâmica.
2. Adicione uma quarta regra: realimentação positiva **e** negativa ao mesmo tempo, mas em momentos diferentes (positiva na primeira metade, negativa na segunda). Que estética isso sugere?
3. Escreva, em três frases, o que você aprendeu sobre a distância entre "mudar um número" e "mudar a experiência".

**Entregável:** `docs/design/loops.md` com o documento de loops da Vigília (pode partir do exemplo deste capítulo, mas reescreva com as suas palavras e as suas perguntas abertas).

---

## Desafio — o micro-loop de um passe

No desafio do Capítulo 1, você decompôs o passe em PES/FIFA em sistemas. Agora, decomponha-o em **tempo**, como o diagrama do tiro na seção 5.5: do instante em que o botão é pressionado até o companheiro dominar a bola, o que acontece a cada ~50 ms? Que feedback o jogador recebe em cada momento? Onde está a decisão de design "responsividade vs. fidelidade de animação"?

Em seguida, responda: se você tivesse que construir **só o micro-loop do passe** como protótipo, sem campo, sem regras, sem adversários — apenas dois bonecos e uma bola —, quais seriam os três parâmetros que você mais precisaria expor para ajuste? Por quê?

---

## Uso de IA

1. **Para analisar loops de um jogo:**
   > "Descreva os loops de jogo (micro, core, macro e sessão) de [jogo], usando apenas o que é observável jogando ou publicamente documentado. Para cada laço, aponte as mecânicas envolvidas, a dinâmica que elas produzem e a estética provável. Marque claramente o que é inferência."

2. **Para estressar o documento de loops:**
   > "Atue como um game designer sênior especializado em horror. Leia o documento de loops abaixo e identifique: (a) onde a tensão pode ficar constante demais; (b) onde uma realimentação positiva pode virar frustração; (c) três perguntas de playtest que eu ainda não fiz; (d) uma mecânica que poderia ser removida sem perda. [documento]"

3. **Para simulações de balanceamento:**
   > "Quero simular a dinâmica de uma mecânica de bateria em um jogo de terror: a bateria drena enquanto a lanterna está ligada, recarrega em zonas seguras, e o jogador encontra pilhas com uma certa probabilidade por sala. Ajude-me a escrever uma simulação simples (C++ ou Python) que estime, para diferentes parâmetros, a fração de tempo que um jogador 'cauteloso' e um 'impulsivo' passam sem luz. Explique as limitações da simulação."

**Cuidado específico:** IAs tendem a afirmar mecanismos ocultos em jogos comerciais (por exemplo, sistemas de "ajuda ao time que perde" em jogos de futebol) com base em discussões de fóruns. Trate esse tipo de afirmação como boato até que haja fonte primária.

---

## Checklist

- [ ] Sei a diferença entre game loop técnico e gameplay loop.
- [ ] Consigo descrever os loops de um jogo em quatro escalas de tempo.
- [ ] Sei explicar o MDA e por que estética não pode ser implementada diretamente.
- [ ] Sei identificar realimentação positiva e negativa e prever suas dinâmicas.
- [ ] Entendo feedback como apresentação derivada, multicanal, sincronizada e proporcional.
- [ ] Consigo explicar game feel usando o exemplo de um jogo de futebol.
- [ ] Sei situar um jogo no espectro roteiro ↔ sistema.
- [ ] Sei desenhar uma curva de tensão e explicar por que o alívio é projetado.
- [ ] Escrevi o documento de loops da Vigília com perguntas abertas.

---

## Para ir além

- **Robin Hunicke, Marc LeBlanc, Robert Zubek — *MDA: A Formal Approach to Game Design and Game Research*** (2004). Curto, fundamental, amplamente disponível.
- **Jesse Schell — *The Art of Game Design: A Book of Lenses*** — os capítulos sobre experiência, mecânicas e balanceamento, e as "lentes" como ferramenta de análise.
- **Steve Swink — *Game Feel: A Game Designer's Guide to Virtual Sensation*** (2008) — o livro de referência sobre game feel.
- **GDC Vault** (gdcvault.com) — busque talks sobre *game feel* e *juice*; há várias apresentações clássicas sobre como feedback transforma protótipos simples.

---

➡️ **Próximo:** [Capítulo 6 — Game Architecture](cap-06-game-architecture.md)

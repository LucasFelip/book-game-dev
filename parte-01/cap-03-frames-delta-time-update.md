# Capítulo 3 — Frames, Delta Time e Update

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que "multiplicar por Δt" é necessário, mas **não suficiente**, para que um jogo se comporte igual a 30 e a 144 FPS;
- reconhecer e corrigir os bugs clássicos de dependência de frame rate: integração numérica, amortecimento, suavização, input;
- implementar o padrão de **passo fixo com acumulador** e **interpolação de renderização**, e saber quando usá-lo;
- entender **substepping**, **determinismo** e por que eles importam para física, replays e multiplayer;
- distinguir **tempo de jogo** de **tempo real** na Unreal, e usar pausa, `slomo`, *global time dilation* e *custom time dilation*;
- decompor o *bullet time* de Max Payne e a manipulação temporal de Quantum Break como sistemas de tempo.

---

## Contexto

O Capítulo 2 terminou com um exercício incômodo: um frame "pesado" de 200 ms, de vez em quando, fazia a bola saltar de uma vez. O Δt resolveu o problema da velocidade média — a bola chegava ao lugar certo no tempo certo em qualquer máquina —, mas criou outro: **o tamanho do passo da simulação passou a variar**, e com ele a qualidade da simulação.

Este capítulo é sobre essa segunda camada. Ela é sutil porque os bugs que produz não são grosseiros. O personagem não anda o dobro da velocidade: ele **pula 15 cm mais alto a 30 FPS do que a 120**. A câmera não quebra: ela **fica mais "mole" num PC fraco**. A bala não some: ela **atravessa uma parede fina só quando o jogo engasga**. São bugs que passam em revisão de código, passam em testes, e aparecem como "o jogo é estranho na máquina do meu amigo".

Há também um lado positivo. Quando você entende o tempo como uma entrada explícita da simulação, ele vira **material de design**: câmera lenta, pausa, congelamento de impacto, *bullet time*, tempo parado. A Remedy construiu jogos inteiros em cima de manipular essa entrada: os dois primeiros Max Payne (o terceiro é da Rockstar) e Quantum Break.

---

## 3.1 O problema do Δt variável

Lembre a forma geral de uma atualização:

```text
novo_estado = f(estado_atual, input, Δt)
```

A promessa implícita do Δt é: **dez passos de 0,01 s devem produzir o mesmo resultado que um passo de 0,1 s**. Para movimento a velocidade constante (`x += v × Δt`), a promessa é verdadeira: somar dez vezes `v × 0,01` é exatamente `v × 0,1`.

Mas quase nada interessante em um jogo é movimento a velocidade constante. Gravidade muda a velocidade. Atrito muda a velocidade. Molas, suavização de câmera, aceleração de personagem, decaimento de recoil — tudo isso é **algo que muda enquanto muda**. E, para esses casos, a promessa é falsa. Há quatro famílias de problema.

### Problema 1 — Integração numérica depende do tamanho do passo

Um pulo é uma velocidade inicial para cima e uma gravidade puxando para baixo. A física contínua diz que a altura máxima é:

```text
h = v₀² / (2g)
```

Com unidades da Unreal (centímetros), `v₀ = 500 cm/s` e `g = 980 cm/s²`, isso dá **≈ 127,6 cm**.

Mas o jogo não simula física contínua. Ele simula **passos discretos**: a cada frame, atualiza velocidade e posição com Δt. Esse processo se chama **integração numérica**, e existem várias formas de fazê-lo. As duas mais comuns em código de gameplay são:

```cpp
// Euler explícito: usa a velocidade ANTIGA para mover
Z += V * Dt;
V -= G * Dt;

// Euler semi-implícito (ou "simplético"): atualiza a velocidade primeiro
V -= G * Dt;
Z += V * Dt;
```

Parece uma troca de ordem irrelevante. Não é. Veja a altura máxima que cada uma produz em diferentes frame rates (valores calculados pelo programa da seção de implementação):

| Frame rate | Δt | Euler explícito | Euler semi-implícito | Física contínua |
|---|---|---|---|---|
| 30 FPS | 33,3 ms | ≈ 136,0 cm | ≈ 119,3 cm | 127,6 cm |
| 60 FPS | 16,7 ms | ≈ 131,8 cm | ≈ 123,4 cm | 127,6 cm |
| 120 FPS | 8,3 ms | ≈ 129,6 cm | ≈ 125,5 cm | 127,6 cm |

Duas lições:

1. **Nenhuma das duas é exata, e o erro depende de Δt.** Com Euler semi-implícito, o mesmo pulo alcança ~6 cm a menos a 30 FPS do que a 120. Se um level designer colocou uma borda a 124 cm de altura testando numa máquina a 120 FPS, ela é **inalcançável** para um jogador a 30 FPS.
2. **A ordem das operações muda o sinal do erro.** Euler explícito superestima (o objeto "sobe com a velocidade velha"); semi-implícito subestima. Semi-implícito é preferido em jogos por ser mais estável em sistemas oscilantes (molas, órbitas) — ele não "ganha energia" do nada —, mas continua dependente do passo.

Existem integradores mais precisos (Verlet, Runge-Kutta), e a física da engine tem os seus. A lição de engenharia, porém, não é "use um integrador melhor": é **controle o tamanho do passo**. Esse é o tema das seções 3.3 e 3.5.

> **Na Unreal:** no `CharacterMovementComponent`, que você conhecerá no Capítulo 17, a altura do pulo é praticamente independente do frame rate — mas não por causa de passos menores. Na queda (`PhysFalling`), ele desloca o personagem pela **média** entre a velocidade do início e a do fim do passo (integração de ponto médio), o que, com gravidade constante, equivale à forma exata `Z += V·Δt − ½·g·Δt²`. Ele também subdivide frames longos (`MaxSimulationTimeStep`, `MaxSimulationIterations`), mas, com o limite padrão de 0,05 s, um frame de 33 ms nem chega a ser subdividido (verifique os valores e o código na sua versão da engine). Repare no alcance da correção: ela é exata só para aceleração constante; com forças que variam (molas, atrito, arrasto), volta a valer a lição de controlar o passo. No código que **você** escrever, a responsabilidade é sua.

### Problema 2 — Amortecimento e suavização "por frame"

Este é, provavelmente, o bug de dependência de frame rate mais comum em código de gameplay, e ele aparece em lugares inocentes:

```cpp
// "Atrito": perde 10% da velocidade por frame
Velocity *= 0.9f;

// "Suavização": aproxima 10% do alvo por frame
CameraLocation = FMath::Lerp(CameraLocation, TargetLocation, 0.1f);
```

Nenhuma das duas linhas usa Δt — então a "força" do atrito e a "moleza" da câmera dependem diretamente do frame rate. Veja quanto da distância original **resta** depois de 1 segundo com `Lerp(..., 0.1)` por frame:

```text
 20 FPS:  0,9^20  ≈ 12,2% restando   → câmera "mole"
 60 FPS:  0,9^60  ≈  0,18% restando  → câmera "firme"
144 FPS:  0,9^144 ≈  0,000025%       → câmera praticamente grudada
```

O jogo não é "um pouco diferente" em máquinas diferentes: ele tem **outra sensação**. E multiplicar ingenuamente o fator por Δt (`Lerp(A, B, 6.0f * Dt)`) melhora, mas não resolve, porque o efeito é **multiplicativo**, não aditivo — somar pequenos lerps não é o mesmo que um lerp grande.

A correção exata vem de reconhecer que "aproximar uma fração fixa por unidade de tempo" é um **decaimento exponencial**. A fração restante depois de um tempo `t` deve ser `e^(−k·t)`, independentemente de como `t` foi dividido em frames. Logo, o fator de mistura correto para um frame de duração Δt é:

```text
alpha = 1 − e^(−k · Δt)
```

onde `k` é a **taxa de convergência** (em 1/s). Interpretação útil: após `1/k` segundos, ~63% da distância foi percorrida; após `3/k`, ~95%.

E para converter um valor "por frame" que já foi ajustado num frame rate de referência `F` para uma taxa:

```text
k = −ln(1 − fator) × F
```

O `Lerp(..., 0.1)` ajustado a 60 FPS corresponde a `k = −ln(0,9) × 60 ≈ 6,32 /s`.

O mesmo vale para o atrito: `Velocity *= 0.9f` por frame vira `Velocity *= FMath::Exp(-k * Dt)`.

> **Na Unreal:** as funções `FMath::FInterpTo`, `FMath::VInterpTo` e `FMath::RInterpTo` recebem `DeltaTime` e uma velocidade de interpolação, e são o caminho usual para suavização. Internamente, elas usam um fator **linear** aproximado (`Δt × velocidade`, limitado a 1), que se comporta bem quando Δt é pequeno e diverge quando Δt é grande (com Δt × velocidade ≥ 1, o valor salta direto para o alvo). Para a maior parte dos usos é suficiente. Para a câmera do projeto, onde a sensação precisa ser idêntica em qualquer máquina, criaremos um utilitário exato (seção de implementação) — e você verá a diferença no experimento.

### Problema 3 — Passos grandes atravessam coisas (*tunneling*)

Um projétil a 30.000 cm/s (300 m/s) anda 1.000 cm em um frame de 33 ms. Se a colisão for verificada apenas na posição final de cada passo, uma parede de 20 cm entre a posição anterior e a nova simplesmente **não existe** para ele. Isso se chama *tunneling*.

Esse problema não é só de projéteis rápidos: qualquer objeto atravessa obstáculos finos se o passo for grande o suficiente — e o passo fica grande justamente quando o jogo engasga. As soluções são três, e você vai usar as três ao longo do livro:

- **Verificar o percurso, não o ponto.** Em vez de "há colisão na nova posição?", perguntar "há colisão no segmento entre a posição antiga e a nova?" — um *sweep* ou um *trace*. É o que o movimento de atores na Unreal faz quando você move com `bSweep = true`, e o que armas *hitscan* fazem por definição (Capítulo 27).
- **Detecção contínua de colisão (CCD)** na física, para corpos simulados rápidos (Capítulo 15).
- **Limitar o tamanho do passo** — com substepping (3.5) ou com um teto para o Δt (3.8).

### Problema 4 — Não determinismo

Se o resultado da simulação depende de Δt, e Δt depende do momento exato em que o sistema operacional agendou a thread, do que a GPU estava fazendo e da temperatura do processador, então **duas execuções com exatamente o mesmo input produzem resultados diferentes**. Isso inviabiliza replays por reexecução, multiplayer por *lockstep* e reproduções confiáveis de bugs. A seção 3.6 trata disso.

---

## 3.2 Input também tem unidade de tempo

Antes de chegar às soluções estruturais, um caso que pega quase todo iniciante e que importa muito para um FPS: **quais inputs devem ser multiplicados por Δt?**

A resposta depende da *natureza física* do input:

- **Mouse produz deslocamento.** O mouse informa "moveu 12 contagens desde o último frame". Isso já é uma quantidade acumulada no tempo. Se o frame foi longo, o deslocamento é maior naturalmente. **Não multiplique deslocamento do mouse por Δt** — fazê-lo torna a mira dependente do frame rate (e, num frame longo, a mira "trava").
- **Analógico produz taxa.** O analógico informa "está inclinado 70% para a direita" — uma posição que significa "gire a uma certa velocidade enquanto eu estiver assim". Isso é uma **taxa**, e deve ser **multiplicada por Δt** (e por uma velocidade de giro em graus/s) para virar rotação neste frame.
- **Botões produzem estados e transições.** "Está pressionado", "foi pressionado neste frame", "foi solto neste frame". Ações discretas (atirar, pular) não usam Δt; ações contínuas enquanto o botão está pressionado (correr, carregar um arremesso) usam.

```text
Mouse   → deslocamento → rotação = delta × sensibilidade
Stick   → taxa         → rotação = eixo × velocidade_graus_por_s × Δt
Botão   → evento       → ação discreta (sem Δt) ou contínua (com Δt)
```

Essa distinção explica um fenômeno que você talvez já tenha notado jogando: em alguns jogos, a mira com controle "fica mais lenta" quando o FPS cai e a mira com mouse não. Quando o tratamento está correto, nenhum dos dois deveria mudar.

> **Na Unreal:** o Enhanced Input (Capítulo 14) permite tratar os dois casos com o mesmo código de gameplay: o mapeamento do analógico pode receber um modificador de escala por Δt (*Scale By Delta Time*), enquanto o do mouse não. O código que recebe o valor de "olhar" (`AddControllerYawInput`/`AddControllerPitchInput`) apenas aplica o que chegou. A decisão de unidade fica na configuração do input — onde um designer pode ajustá-la — e não espalhada pelo código.

A conexão com o futebol é direta. Quando você jogava PES 2011 no PlayStation 2 com seu primo, cada um no seu controle, o analógico definia a *direção e a intensidade* da corrida — uma taxa — e o botão de passe era um *evento* cujo efeito dependia de quanto tempo ele ficava pressionado (a força do passe). Três tipos de input, três tratamentos de tempo, no mesmo lance.

---

## 3.3 Passo fixo com acumulador

Volte ao problema central: a simulação fica diferente quando o tamanho do passo varia. A solução mais robusta é simples de enunciar: **não deixe o passo variar**. A simulação avança sempre em passos de tamanho fixo — digamos, 1/60 s —, não importa quanto tempo o frame real levou.

Se o frame real levou 33 ms, a simulação roda **dois** passos. Se levou 8 ms, a simulação roda **zero** passos neste frame e acumula o tempo para o próximo. O tempo que "sobra" fica guardado num **acumulador**.

```text
frame real (ms):        34        8        8       50
acumulador antes:       34      8,7     16,7       50
passos de 16,67 ms:      2        0        1        3
sobra no acumulador:   0,7      8,7        0        0
```

Esta é a estrutura clássica descrita por Glenn Fiedler em *Fix Your Timestep!*:

```cpp
const double FixedDt = 1.0 / 60.0;
double Accumulator = 0.0;
auto Previous = Clock::now();

while (bRunning)
{
    const auto Now = Clock::now();
    double FrameTime = Seconds(Now - Previous);
    Previous = Now;

    FrameTime = std::min(FrameTime, 0.25);   // (1) teto: evita a espiral da morte
    Accumulator += FrameTime;

    ProcessInput();

    while (Accumulator >= FixedDt)           // (2) quantos passos fixos couberem
    {
        PreviousState = CurrentState;
        Simulate(CurrentState, FixedDt);     //     sempre o mesmo Δt
        Accumulator -= FixedDt;
    }

    const double Alpha = Accumulator / FixedDt;          // (3) fração do próximo passo
    Render(Interpolate(PreviousState, CurrentState, Alpha));
}
```

Três detalhes merecem atenção.

### (1) A espiral da morte

Suponha que simular um passo custe 20 ms e o passo fixo seja de 16,67 ms. A cada frame, você acumula mais tempo do que consegue simular. No frame seguinte, há mais passos a executar, que demoram mais, que acumulam ainda mais tempo... O jogo trava progressivamente até parar. Isso se chama **espiral da morte** (*spiral of death*).

O teto no tempo de frame (`min(FrameTime, 0.25)`) quebra a espiral: se o sistema não consegue acompanhar, o jogo **desacelera** em relação ao tempo real, em vez de travar. É uma escolha consciente: "prefiro câmera lenta a congelamento".

> 🌉 **Ponte:** você conhece esse fenômeno de filas. Se a taxa de chegada supera a taxa de processamento, o *backlog* cresce sem limite e a latência explode. A resposta clássica é *load shedding*: descartar trabalho para preservar o sistema. O teto de Δt é *load shedding* aplicado ao tempo: o jogo descarta o tempo que não consegue simular.
>
> 🌉 **Ponte (2):** a diferença entre "Δt variável" e "passo fixo com acumulador" é exatamente a diferença entre `scheduleWithFixedDelay` e `scheduleAtFixedRate` no `ScheduledExecutorService` do Java. *Fixed delay* não compensa atrasos — se uma execução demora, as próximas simplesmente começam mais tarde. *Fixed rate* tenta manter a cadência, executando em rajada as execuções atrasadas — o acumulador. E ambos sofrem do mesmo problema quando a tarefa demora mais que o período.

### (2) Zero, um ou vários passos por frame

Num computador rápido, a 144 FPS, a maioria dos frames não executa nenhum passo ou executa um. Num computador lento, a 30 FPS, cada frame executa dois. A **simulação é idêntica nos dois** — mesma sequência de estados, com o mesmo Δt —, o que resolve os Problemas 1 e 4 da seção 3.1.

Mas há um custo novo: se a renderização simplesmente desenhasse `CurrentState`, um jogo a 144 FPS mostraria o **mesmo estado** em dois ou três frames consecutivos, e depois um salto. O movimento pareceria travado (*stutter*), apesar do FPS alto.

### (3) Interpolação de renderização

A solução é **não desenhar o estado da simulação, mas uma interpolação entre os dois últimos estados**. Se o acumulador guarda 40% de um passo, desenha-se o objeto 40% do caminho entre o estado anterior e o atual. O resultado é movimento suave em qualquer frame rate, com simulação fixa por baixo.

O preço é **latência**: o que você vê está sempre até um passo fixo **atrás** do estado mais recente da simulação. Com passo de 1/60 s, até 16,67 ms. Para muitos jogos, imperceptível; para um FPS competitivo, é um custo que entra na conta da latência de input (Capítulo 2, seção 2.4).

A alternativa é **extrapolar**: desenhar o objeto um pouco *à frente* do estado atual, projetando sua velocidade. Não há latência, mas há erro: se o objeto mudou de direção, a extrapolação mostra uma posição onde ele nunca esteve, e depois corrige. Guarde esse par **interpolação (suave, atrasada) vs. extrapolação (imediata, errada às vezes)**: ele volta, quase idêntico, no Capítulo 68, quando os "estados" deixarem de vir da sua simulação e passarem a vir **da rede**.

### Quando usar passo fixo

| Situação | Passo fixo? | Por quê |
|---|---|---|
| Física rígida, molas, veículos | Sim (ou substepping) | Estabilidade numérica depende do passo |
| Simulação determinística (lockstep, rollback) | Sim, obrigatório | Mesmo input → mesmo resultado |
| Lógica de gameplay comum (abrir porta, regenerar escudo) | Normalmente não | Δt variável + cuidado com 3.1 basta |
| Animação, câmera, UI | Não | Precisam de suavidade por frame renderizado |
| Lógica de servidor multiplayer | Frequentemente sim (*tick rate*) | Taxa fixa de atualização e de envio (Parte IX) |

Na Unreal, o gameplay usa Δt variável por padrão, e você **não** vai reescrever o loop da engine para passo fixo. O padrão do acumulador aparece de outras formas: na física (3.5), em sistemas específicos que você mesmo escrever quando precisarem de estabilidade, e na rede.

---

## 3.4 Uma simulação dentro do Tick: o acumulador local

Não poder mudar o loop da engine não impede usar passo fixo **dentro de um sistema**. Se você tiver um componente que simula algo sensível ao passo — uma corda, um pêndulo de luz pendurado no teto da usina que balança quando a Presença passa, uma mola de câmera —, o acumulador pode viver dentro do `TickComponent`:

```cpp
void UVGSwingingLampComponent::TickComponent(float DeltaSeconds, ELevelTick TickType,
                                             FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaSeconds, TickType, ThisTickFunction);

    Accumulator += FMath::Min(DeltaSeconds, MaxFrameTime);
    while (Accumulator >= FixedStep)
    {
        PreviousAngle = CurrentAngle;
        StepPendulum(FixedStep);         // integração estável com passo fixo
        Accumulator -= FixedStep;
    }

    const float Alpha = Accumulator / FixedStep;
    ApplyAngle(FMath::Lerp(PreviousAngle, CurrentAngle, Alpha)); // suave na tela
}
```

É o mesmo padrão em miniatura. Ele custa pouco, isola o problema e não exige que o resto do jogo saiba de nada. Na maioria dos casos, porém, um objeto como esse seria simplesmente um corpo físico com uma restrição, e a física da engine faria o trabalho. O acumulador local é a ferramenta para quando você **precisa** controlar a simulação.

---

## 3.5 Substepping

Passo fixo puro tem uma rigidez: o número de passos por frame depende do tempo real, e a simulação pode ficar "dessincronizada" do frame renderizado (por isso a interpolação). **Substepping** é um meio-termo muito usado: o frame continua tendo Δt variável, mas, se ele for grande demais, é **subdividido** em vários subpassos menores, de tamanho igual, que somam exatamente Δt.

```text
Δt = 40 ms, subpasso máximo = 16,67 ms
   → 3 subpassos de 13,33 ms (somam 40 ms)

Δt = 10 ms
   → 1 passo de 10 ms (abaixo do limite, não subdivide)
```

O passo não é perfeitamente fixo — varia entre um mínimo e o limite —, então a simulação não é determinística. Mas o **erro máximo fica controlado**, e não há latência de interpolação, porque o estado simulado termina exatamente no tempo do frame. O `CharacterMovementComponent` subdivide frames dessa forma quando eles passam de `MaxSimulationTimeStep` (seção 3.1), e o substepping é uma das opções da física da Unreal.

### A física da Unreal

**[Pode variar entre versões do UE5 — verifique nas *Project Settings* da sua versão.]** A física (Chaos) da Unreal oferece, em linhas gerais, três modos:

- **Padrão:** a física avança uma vez por frame com o Δt do frame (sujeito a limites internos).
- **Substepping** (*Project Settings → Engine → Physics → Substepping*): frames longos são subdivididos, com configurações como tamanho máximo do subpasso e número máximo de subpassos.
- **Física assíncrona** (*Tick Physics Async*): a física roda em sua própria thread, com **passo fixo** configurável, desacoplada do frame de gameplay — essencialmente o acumulador da seção 3.3 implementado pela engine. Traz estabilidade e previsibilidade, ao custo de complexidade na comunicação entre gameplay e física (o gameplay passa a conversar com uma simulação que roda em outro ritmo).

Para o projeto Vigília, o padrão é suficiente: não há veículos nem física pesada. Para um jogo como GTA IV, em que a experiência inteira depende do comportamento físico de veículos e corpos (Interlúdio II), a escolha do modo de física seria uma decisão de arquitetura de primeira ordem.

---

## 3.6 Determinismo

Uma simulação é **determinística** quando, dados o mesmo estado inicial e a mesma sequência de inputs, ela produz sempre exatamente o mesmo resultado. Em sistemas corporativos, você valoriza isso em processamento de eventos (reprocessar um log de eventos deve reconstruir o mesmo estado — *event sourcing*). Em jogos, o determinismo habilita três coisas valiosas:

1. **Replays por reexecução.** Em vez de gravar a posição de tudo a cada frame, grava-se só o input dos jogadores, e o replay **reexecuta** a simulação. Arquivos minúsculos.
2. **Multiplayer por *lockstep* ou *rollback*.** Cada máquina roda a simulação inteira e só troca inputs. É a base histórica de jogos de estratégia com centenas de unidades (trocar o estado de mil soldados por rede é impossível; trocar os cliques do jogador é trivial) e das técnicas de *rollback* usadas em jogos de luta. Voltaremos a isso na Parte IX.
3. **Reprodução de bugs.** Gravou o input da sessão do testador? Reexecute e veja o bug acontecer de novo, no mesmo frame.

> 🌉 **Ponte:** replay por reexecução de inputs é *event sourcing* — o estado é derivado da sequência de eventos. E, como em *event sourcing*, a premissa é que a função de aplicação seja pura e determinística.
>
> 🧱 **Onde a ponte cai:** em *event sourcing*, você controla a função de aplicação. Em um jogo, a "função" é uma engine inteira — física, animação, IA, ponto flutuante —, e o determinismo quebra por motivos que você não controla diretamente.

### Fontes de não determinismo

| Fonte | Exemplo | Como mitigar |
|---|---|---|
| Δt variável | Mesma sessão, frames de durações diferentes | Passo fixo (3.3) |
| Aleatoriedade sem semente | `FMath::Rand()` no spread da arma | Gerador com semente explícita (`FRandomStream` na Unreal) |
| Ordem de iteração | Iterar um mapa/conjunto cuja ordem depende de endereços de memória | Ordenar antes de iterar, ou usar estruturas de ordem estável |
| Paralelismo | Resultado depende de qual thread terminou primeiro | Combinar resultados em ordem fixa |
| Ponto flutuante | Mesma conta, resultados diferentes em compiladores, flags de otimização ou CPUs diferentes | Muito difícil; jogos determinísticos entre máquinas às vezes usam aritmética de ponto fixo |
| Tempo real | Lógica que lê o relógio do sistema | Sempre usar o tempo da simulação |

O último ponto da tabela merece ênfase: **determinismo entre máquinas diferentes é muito mais difícil do que determinismo na mesma máquina.** Não assuma que a física da engine é determinística entre plataformas; para a maioria dos jogos, inclusive todo este livro, a estratégia de multiplayer será **autoridade do servidor + replicação de estado** (Parte IX), justamente porque não depende de determinismo perfeito.

> **[INFERÊNCIA]** Replays de jogos de futebol como PES e FIFA mostram o lance de vários ângulos, em câmera lenta, logo depois que ele acontece. Uma forma plausível — e mais robusta — de implementar isso é **gravar o estado** (posições, rotações e estados de animação dos jogadores e da bola) num *buffer* circular dos últimos segundos, e depois reproduzi-lo com outra câmera, em vez de reexecutar a simulação. Gravação de estado não exige determinismo; reexecução exige. Não há informação pública detalhada sobre como esses jogos implementam seus replays, e não é necessário que haja: o trade-off é o que importa. Na Unreal, existe um sistema de replay embutido que grava o fluxo de dados de **replicação de rede** — ou seja, estado, não input — e que estudaremos de passagem na Parte IX.

Na Unreal, para aleatoriedade reprodutível, use `FRandomStream`:

```cpp
FRandomStream SpreadStream(Seed);                       // semente explícita
const float SpreadYaw = SpreadStream.FRandRange(-Spread, Spread);
```

Mesmo sem precisar de determinismo, o hábito tem valor: um bug "que acontece às vezes no spread da arma" fica reproduzível se você puder fixar a semente.

---

## 3.7 Tempo de jogo, tempo real e manipulação do tempo

Até aqui, "tempo" significou uma coisa só. Um jogo tem vários relógios, e confundi-los é fonte de bugs sutis.

### Os relógios da Unreal

| Função (em `UWorld`) | O que mede | Afetado por pausa? | Afetado por time dilation? |
|---|---|:-:|:-:|
| `GetTimeSeconds()` | Tempo de jogo desde o início do mundo | Sim (para) | Sim |
| `GetUnpausedTimeSeconds()` | Tempo de jogo, ignorando pausas | Não | Sim |
| `GetRealTimeSeconds()` | Tempo real desde o início do mundo | Não | Não |
| `GetAudioTimeSeconds()` | Tempo usado pelo áudio | Sim | Não |
| `GetDeltaSeconds()` | Δt de jogo deste frame | — | Sim |

O `DeltaSeconds` que seu `Tick` recebe já é **tempo de jogo dilatado**: se o jogo está em câmera lenta a 25%, um frame de 16 ms real chega como 4 ms. **Timers** também usam tempo de jogo: um timer de 2 s, em câmera lenta a 25%, leva 8 s reais.

Isso é exatamente o que se quer para quase tudo — e exatamente o que **não** se quer para algumas coisas: a animação de um menu de pausa, a duração real de um efeito de "congelamento de impacto", o tempo de uma UI que deve responder mesmo com o jogo parado.

### Pausa

`UGameplayStatics::SetGamePaused(this, true)` pausa o mundo: atores e componentes deixam de tickar, timers param. Atores que precisam continuar (menus, câmera de pausa, um efeito de UI) podem ser marcados para tickar mesmo pausados (`SetTickableWhenPaused(true)` / `PrimaryActorTick.bTickEvenWhenPaused`). Widgets de UI (UMG) são atualizados pelo sistema de UI, que continua rodando com o jogo pausado.

### Time dilation

A Unreal tem dois níveis de dilatação do tempo:

- **Global** — `UGameplayStatics::SetGlobalTimeDilation(this, 0.25f)` deixa o mundo inteiro a 25% da velocidade. No console, o comando de desenvolvimento `slomo 0.25` faz o mesmo e é ótimo para depurar: **muitos bugs de animação, física e câmera só ficam visíveis em câmera lenta**.
- **Por ator** — `AActor::CustomTimeDilation` multiplica a dilatação global para aquele ator. A dilatação efetiva de um ator é `global × custom`.

A combinação dos dois é o mecanismo mais simples de *bullet time*: dilata-se o mundo e compensa-se o jogador.

```cpp
// Mundo a 30%, jogador a ~100% (0,3 × 3,33 ≈ 1,0)
UGameplayStatics::SetGlobalTimeDilation(this, 0.3f);
PlayerPawn->CustomTimeDilation = 1.0f / 0.3f;
```

Repare que **não há uma linha de código de gameplay mudando velocidade de nada**. Inimigos, projéteis, portas, timers, partículas: tudo que usa `DeltaSeconds` corretamente desacelera sozinho. Tudo que **não** usa — o `Lerp(..., 0.1f)` por frame, o `Velocity *= 0.9f` — continua na velocidade normal e denuncia o bug. A câmera lenta é, portanto, também um **teste**: rode `slomo 0.1` e veja o que não desacelera.

> **Atenção:** o controle de dilatação do tempo, os limites aceitos e a interação com física e áudio têm detalhes que variam entre versões. Teste no seu projeto, especialmente se combinar dilatação com física simulada.

---

## Estudo de caso: Max Payne e Quantum Break — o tempo como mecânica

> **Pergunta:** como uma variável técnica — a velocidade do tempo na simulação — se transforma na identidade de um jogo?

### O que é publicamente conhecido

**[FATO PÚBLICO]** *Max Payne* (Remedy Entertainment, 2001) tem como mecânica central o *Bullet Time*: o jogador ativa uma câmera lenta, consumindo um medidor que se recarrega ao derrotar inimigos. Durante o Bullet Time, o mundo desacelera, os projéteis ficam visíveis em voo, e o jogador consegue mirar com precisão enquanto tudo à sua volta está lento. O jogo também tem o *shootdodge*, um salto lateral em câmera lenta durante o qual se pode atirar. A mecânica foi amplamente associada à estética de cinema de ação da época, e é um dos elementos mais citados da série.

**[FATO PÚBLICO]** *Quantum Break* (Remedy, 2016) gira em torno de uma fratura no tempo. O protagonista ganha poderes temporais — parar o tempo numa área, deslocar-se em alta velocidade, criar escudos temporais — e o mundo passa por *stutters*, momentos em que o tempo congela, se repete ou salta, deixando objetos e pessoas suspensos no ar enquanto o jogador se move entre eles. O jogo combina capítulos jogáveis com episódios em live-action, cujo conteúdo muda conforme escolhas feitas no jogo.

### 1. Experiência

Max Payne: **sentir-se o protagonista de um filme de ação** — o momento em que o herói salta pela porta, em câmera lenta, e neutraliza a sala antes de tocar o chão. Poder e estilo, controlados pelo jogador.

Quantum Break: **o tempo como ambiente instável e como poder** — o mundo deixa de obedecer às regras, e o jogador é a exceção.

### 2. Sistema

```text
                       TEMPO DA SIMULAÇÃO
                              │
        ┌─────────────────────┼──────────────────────┐
        ▼                     ▼                      ▼
   Mundo desacelera      Jogador mantém         Recurso limitado
   (dilatação global)    precisão/controle      (medidor de Bullet Time)
        │                (compensação local       │
        │                 + mira por mouse)       │
        ▼                     ▼                      ▼
   Projéteis visíveis    Vantagem tática         Decisão: quando usar?
   = informação          temporária              = ritmo do combate
        └─────────────────────┼──────────────────────┘
                              ▼
                  Estética cinematográfica jogável
```

### 3. Design

A decisão central de Max Payne é transformar a câmera lenta — um recurso de **linguagem de cinema** — em **vantagem mecânica controlada pelo jogador**, e torná-la **escassa**. Sem o medidor, o jogador usaria Bullet Time o tempo todo e ele perderia o impacto (e o combate perderia o desafio). Com o medidor, ele vira uma decisão tática recorrente: "gasto agora, nesta sala, ou guardo?".

Uma segunda decisão, implícita: os **projéteis visíveis em voo** fazem o tempo lento não ser apenas um "modo fácil", mas uma forma de **ler** o combate. A câmera lenta transforma informação invisível (balas) em informação visível.

Quantum Break leva a ideia a outra escala: o tempo deixa de ser só uma ferramenta de combate e passa a ser **o tema da narrativa**, o **estado do ambiente** (stutters) e o **conjunto de poderes**. É o mesmo princípio de Alan Wake, no Capítulo 1: uma regra técnica que serve a combate, exploração e história ao mesmo tempo.

### 4. Tecnologia

**[INFERÊNCIA]** Sem afirmar nada sobre os motores proprietários da Remedy, o comportamento observável é compatível com o modelo da seção 3.7:

- uma **escala de tempo global** aplicada à simulação do mundo (inimigos, projéteis, partículas, animações);
- uma **escala diferente para o jogador**, ou um tratamento especial do input de mira — lembre-se da seção 3.2: se a mira usa deslocamento do mouse, ela **não é afetada** pela dilatação, e o jogador mira "em tempo normal" num mundo lento de graça;
- **áudio** com pitch e filtros alterados durante a câmera lenta, reforçando a percepção;
- em Quantum Break, os stutters sugerem **escalas de tempo locais por objeto ou por região** — um objeto "congelado" é um objeto cuja dilatação efetiva é zero, ou cujo estado é reproduzido a partir de uma gravação.

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]**

```cpp
// Bullet time mínimo: mundo lento, jogador compensado, recurso limitado.
void UVGBulletTimeComponent::SetActive(bool bActivate)
{
    if (bActivate && Meter <= 0.0f) { return; }
    bActive = bActivate;

    const float WorldScale = bActive ? WorldTimeScale : 1.0f;   // ex.: 0.3
    UGameplayStatics::SetGlobalTimeDilation(this, WorldScale);
    GetOwner()->CustomTimeDilation = bActive ? 1.0f / WorldScale : 1.0f;
    OnBulletTimeChanged.Broadcast(bActive);   // áudio, pós-processamento, HUD reagem
}

void UVGBulletTimeComponent::TickComponent(float DeltaSeconds, ...)
{
    // DeltaSeconds aqui já inclui a dilatação do DONO (global × custom ≈ 1),
    // então o medidor gasta em "tempo do jogador": ~tempo real.
    if (bActive)
    {
        Meter = FMath::Max(Meter - DrainPerSecond * DeltaSeconds, 0.0f);
        if (Meter <= 0.0f) { SetActive(false); }
    }
}
```

Note o comentário: decidir **em que tempo** o medidor é gasto (tempo do mundo? do jogador? real?) é uma decisão de design disfarçada de detalhe técnico. Se o medidor gastasse em tempo do mundo, a câmera lenta duraria 3,3× mais em segundos reais.

### 6. Lição

**Toda variável técnica fundamental é candidata a mecânica.** O tempo da simulação, a luz (Capítulo 1), a gravidade, o som, a visibilidade: quando uma dessas variáveis é exposta ao jogador como algo que ele controla, consome ou teme, ela pode definir a identidade de um jogo inteiro. E a condição para fazer isso com baixo custo é que o resto do jogo **respeite a variável** — o bullet time só é uma linha de código porque todo o resto usa `DeltaSeconds` corretamente.

Para a Vigília: não teremos bullet time, mas teremos **tempo como ferramenta de atmosfera e feedback** — uma breve desaceleração quando a Presença surge pela primeira vez, *hitstop* (congelamento de poucos milissegundos) no impacto do sinalizador, e a escolha consciente de **em que relógio** roda cada sistema: a bateria da lanterna gasta em tempo de jogo; legendas e UI de documentos respondem em tempo real.

---

## 3.8 Frame rate, VSync e consistência

Por último, o lado "de fora" do loop: como a taxa de frames é controlada, e por que **consistência** importa mais que número.

- **VSync** (sincronização vertical) faz o jogo esperar o monitor terminar de desenhar a imagem anterior antes de entregar a nova. Elimina *tearing* (a imagem "rasgada" quando dois frames aparecem na mesma tela), mas pode adicionar latência e, se o jogo não consegue manter a taxa do monitor, faz a taxa cair em degraus (60 → 30 num monitor de 60 Hz, em configurações tradicionais). Monitores de taxa variável (VRR) atenuam esse problema.
- **Limite de frame rate.** Na Unreal, o comando `t.MaxFPS 60` limita a taxa; útil para testar o jogo a 30, 60 e 120 FPS na mesma máquina — e você vai fazer isso no exercício.
- **Frame pacing.** Um jogo a 60 FPS cujos frames alternam entre 8 ms e 25 ms parece pior que um jogo estável a 40. O que o olho percebe é a **variação** entre frames. Por isso, em performance (Capítulo 58), o gráfico de tempo de frame importa mais que o número de FPS médio.
- **Teto de Δt.** A engine limita o Δt máximo de um frame — na Unreal, isso passa pelas *World Settings* (propriedades como `MaxUndilatedFrameTime`, consultadas ao corrigir o Δt de cada frame; verifique o nome e o valor padrão na sua versão). É o mesmo princípio do teto do acumulador: depois de uma travada de 2 segundos (carregando um asset, por exemplo), a simulação não deve avançar 2 segundos de uma vez.
- **Configurações de projeto.** A Unreal tem opções de *frame rate* nas configurações do projeto (taxa fixa, taxa suavizada, limites). Para gameplay, o padrão é adequado. A opção de **passo fixo da engine inteira** existe e é útil em situações específicas — captura de vídeo determinística, testes automatizados reproduzíveis —, mas não para o jogo jogável.

**[FATO PÚBLICO]** É amplamente reportado que a série Call of Duty prioriza historicamente 60 FPS nos consoles, desde a geração PS3/Xbox 360, inclusive aceitando resoluções menores para isso. Seja qual for a motivação interna, a lógica de design é coerente com tudo o que vimos: num shooter, **frame rate alto e estável é latência de input menor e mira mais legível**, e isso vale mais que nitidez.

---

## Comparação com o desenvolvimento tradicional

| Conceito de jogo | Análogo em backend | Onde a analogia vale | Onde cai |
|---|---|---|---|
| Passo fixo com acumulador | `scheduleAtFixedRate` | Mantém cadência e compensa atraso em rajada | Em jogos, a rajada precisa caber no frame; o teto é obrigatório |
| Espiral da morte + teto de Δt | Backlog crescente + *load shedding* | Descartar trabalho para preservar o sistema | O "trabalho descartado" é tempo de simulação: o jogo fica lento, não perde requisições |
| Replay por reexecução | *Event sourcing* | Estado = função pura da sequência de eventos | Pureza depende de física, float e engine, que você não controla |
| Interpolação de renderização | Exibir o último dado consistente em vez de um dado parcial | Mostrar estado estável em vez de estado instantâneo | O custo é latência de ~1 passo, percebida pelas mãos do jogador |
| Relógios de jogo vs. real | Tempo de evento vs. tempo de processamento (*event time* / *processing time* em streaming) | Dois relógios com semânticas diferentes | Em jogos, o relógio de "evento" pode parar, acelerar e desacelerar por design |

A última linha é especialmente útil se você já trabalhou com processamento de streams: a distinção entre *event time* e *processing time* é a mesma disciplina mental de "em que relógio isto roda?". A diferença é que, em jogos, o relógio de jogo é **manipulado de propósito**.

---

## Implementação

### Parte A — integração e passo fixo (C++ padrão)

**Programa 1: a altura do pulo depende do frame rate.**

```cpp
// jump_integration.cpp — g++ -std=c++20 -O2 jump_integration.cpp -o jump_integration
#include <cstdio>
#include <initializer_list>

// Simula um pulo vertical e devolve a altura máxima alcançada.
double SimulateApex(bool bSemiImplicit, double V0, double Gravity, double Dt)
{
    double Z = 0.0;
    double V = V0;
    double Apex = 0.0;

    while (true)
    {
        if (bSemiImplicit) { V -= Gravity * Dt; Z += V * Dt; } // velocidade primeiro
        else               { Z += V * Dt; V -= Gravity * Dt; } // posição primeiro

        if (Z > Apex) { Apex = Z; }
        if (V <= 0.0 && Z < Apex) { break; } // já passou do topo
    }
    return Apex;
}

int main()
{
    const double V0 = 500.0;      // cm/s
    const double Gravity = 980.0; // cm/s²
    std::printf("Analitico: %.2f cm\n\n", V0 * V0 / (2.0 * Gravity));
    std::printf(" FPS   Euler explicito   Euler semi-implicito\n");

    for (int Fps : {20, 30, 60, 120, 240})
    {
        const double Dt = 1.0 / Fps;
        std::printf("%4d   %10.2f cm      %10.2f cm\n", Fps,
                    SimulateApex(false, V0, Gravity, Dt),
                    SimulateApex(true,  V0, Gravity, Dt));
    }
    return 0;
}
```

Repare que este programa não tem loop de tempo real: ele **simula** frame rates diferentes passando Δt diferentes. Essa é uma técnica valiosa por si só — isolar a lógica de simulação do relógio torna-a testável. A função `SimulateApex` é pura: dá para escrever testes unitários para ela.

**Programa 2: passo fixo com acumulador, teto e interpolação.** Evolução direta do `game_loop.cpp` do Capítulo 2.

```cpp
// fixed_step.cpp — g++ -std=c++20 -O2 fixed_step.cpp -o fixed_step
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <random>
#include <thread>

using Clock = std::chrono::steady_clock;

struct State
{
    double X = 0.0;
    double V = 4.0; // unidades/s; a bola quica entre 0 e 10
};

void Simulate(State& S, double Dt)
{
    S.X += S.V * Dt;
    if (S.X > 10.0) { S.X = 20.0 - S.X; S.V = -S.V; }
    if (S.X < 0.0)  { S.X = -S.X;       S.V = -S.V; }
}

int main()
{
    const double FixedDt = 1.0 / 60.0;
    const double MaxFrameTime = 0.25;           // teto contra a espiral da morte

    State Previous, Current;
    double Accumulator = 0.0;
    double SimulatedTime = 0.0;

    std::mt19937 Rng(42);                       // semente fixa: execução reproduzível
    std::uniform_int_distribution<int> FrameCostMs(4, 40);

    const auto Start = Clock::now();
    auto Last = Start;

    for (int Frame = 1; Frame <= 150; ++Frame)
    {
        const auto Now = Clock::now();
        double FrameTime = std::chrono::duration<double>(Now - Last).count();
        Last = Now;

        FrameTime = std::min(FrameTime, MaxFrameTime);
        Accumulator += FrameTime;

        int Steps = 0;
        while (Accumulator >= FixedDt)
        {
            Previous = Current;
            Simulate(Current, FixedDt);
            SimulatedTime += FixedDt;
            Accumulator -= FixedDt;
            ++Steps;
        }

        const double Alpha = Accumulator / FixedDt;
        const double RenderX = Previous.X * (1.0 - Alpha) + Current.X * Alpha;

        if (Frame % 10 == 0)
        {
            const double RealTime = std::chrono::duration<double>(Now - Start).count();
            std::printf("frame=%3d real=%6.3fs sim=%6.3fs passos=%d alpha=%.2f renderX=%5.2f\n",
                        Frame, RealTime, SimulatedTime, Steps, Alpha, RenderX);
        }

        // Custo de frame variável + uma travada a cada 50 frames
        const int CostMs = (Frame % 50 == 0) ? 400 : FrameCostMs(Rng);
        std::this_thread::sleep_for(std::chrono::milliseconds(CostMs));
    }
    return 0;
}
```

Observe na saída: o número de passos por frame varia (0, 1, 2, às vezes 15 depois da travada), o tempo simulado acompanha o tempo real **exceto** depois das travadas de 400 ms (o teto de 250 ms "perde" ~150 ms cada vez), e `renderX` evolui suavemente.

### Parte B — suavização independente de frame rate na Unreal

Agora, o primeiro utilitário de verdade do projeto Vigília. Ele será usado pela câmera (Capítulo 18), pelo recoil (Capítulo 29) e pela UI. É deliberadamente pequeno: duas funções.

```cpp
// Source/Vigilia/Core/VGMathUtils.h
#pragma once

#include "CoreMinimal.h"

namespace VGMath
{
    /**
     * Fator de mistura para suavização exponencial, independente de frame rate.
     * Rate (1/s): após 1/Rate segundos, ~63% da distância foi percorrida; após 3/Rate, ~95%.
     * Para converter um fator "por frame" F ajustado a N FPS: Rate = -ln(1 - F) * N.
     */
    FORCEINLINE float ExpDecayAlpha(float Rate, float DeltaSeconds)
    {
        return 1.0f - FMath::Exp(-Rate * DeltaSeconds);
    }

    /** Aproxima Current de Target com decaimento exponencial (float, FVector, FLinearColor...). */
    template <typename T>
    FORCEINLINE T ExpDecayTo(const T& Current, const T& Target, float Rate, float DeltaSeconds)
    {
        return FMath::Lerp(Current, Target, ExpDecayAlpha(Rate, DeltaSeconds));
    }
}
```

Por que um `namespace` com funções livres e não uma classe? Porque não há estado nem polimorfismo: são funções matemáticas puras. Também não criamos uma `UBlueprintFunctionLibrary` ainda — ninguém precisa disso em Blueprint por enquanto. Quando precisar (Capítulo 13), expomos.

Para **ver** o problema, um ator de diagnóstico que persegue um alvo que alterna de posição, com três modos de suavização:

```cpp
// Source/Vigilia/Debug/VGSmoothingProbe.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "VGSmoothingProbe.generated.h"

class UStaticMeshComponent;

UENUM()
enum class EVGSmoothingMode : uint8
{
    NaivePerFrame,  // Lerp com fator fixo por frame — dependente de frame rate
    InterpTo,       // FMath::VInterpTo — aproximação linear com DeltaTime
    ExpDecay        // VGMath::ExpDecayTo — exato
};

/** Ator de diagnóstico: compara técnicas de suavização sob frame rates e time dilation diferentes. */
UCLASS()
class VIGILIA_API AVGSmoothingProbe : public AActor
{
    GENERATED_BODY()

public:
    AVGSmoothingProbe();

    virtual void Tick(float DeltaSeconds) override;

protected:
    virtual void BeginPlay() override;

    UPROPERTY(VisibleAnywhere, Category = "Smoothing Probe")
    TObjectPtr<UStaticMeshComponent> Mesh;

    UPROPERTY(EditAnywhere, Category = "Smoothing Probe")
    EVGSmoothingMode Mode = EVGSmoothingMode::ExpDecay;

    /** Fator por frame do modo NaivePerFrame. 0.1 a 60 FPS ≈ Rate 6.32. */
    UPROPERTY(EditAnywhere, Category = "Smoothing Probe", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float NaiveFactorPerFrame = 0.1f;

    /** Velocidade para InterpTo e taxa (1/s) para ExpDecay. */
    UPROPERTY(EditAnywhere, Category = "Smoothing Probe", meta = (ClampMin = "0.0"))
    float Rate = 6.32f;

    UPROPERTY(EditAnywhere, Category = "Smoothing Probe")
    FVector TargetOffset = FVector(0.0, 400.0, 0.0);

    UPROPERTY(EditAnywhere, Category = "Smoothing Probe", meta = (ClampMin = "0.1"))
    float SwapInterval = 2.0f;

private:
    void SwapTarget();

    FVector Origin = FVector::ZeroVector;
    FVector Target = FVector::ZeroVector;
    bool bTargetAtOffset = false;
    FTimerHandle SwapTimerHandle;
};
```

```cpp
// Source/Vigilia/Debug/VGSmoothingProbe.cpp
#include "Debug/VGSmoothingProbe.h"

#include "Components/StaticMeshComponent.h"
#include "Core/VGMathUtils.h"
#include "DrawDebugHelpers.h"
#include "TimerManager.h"

AVGSmoothingProbe::AVGSmoothingProbe()
{
    PrimaryActorTick.bCanEverTick = true;

    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    SetRootComponent(Mesh);
}

void AVGSmoothingProbe::BeginPlay()
{
    Super::BeginPlay();

    Origin = GetActorLocation();
    Target = Origin;

    // Timer usa tempo de jogo: sob 'slomo', o alvo também troca mais devagar.
    GetWorldTimerManager().SetTimer(
        SwapTimerHandle, this, &AVGSmoothingProbe::SwapTarget, SwapInterval, /*bLoop=*/true);
}

void AVGSmoothingProbe::SwapTarget()
{
    bTargetAtOffset = !bTargetAtOffset;
    Target = bTargetAtOffset ? Origin + TargetOffset : Origin;
}

void AVGSmoothingProbe::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    const FVector Current = GetActorLocation();
    FVector Next = Current;

    switch (Mode)
    {
    case EVGSmoothingMode::NaivePerFrame:
        Next = FMath::Lerp(Current, Target, NaiveFactorPerFrame); // ignora DeltaSeconds: o bug
        break;
    case EVGSmoothingMode::InterpTo:
        Next = FMath::VInterpTo(Current, Target, DeltaSeconds, Rate);
        break;
    case EVGSmoothingMode::ExpDecay:
        Next = VGMath::ExpDecayTo(Current, Target, Rate, DeltaSeconds);
        break;
    }

    SetActorLocation(Next);
    DrawDebugSphere(GetWorld(), Target, 25.0f, 12, FColor::Yellow);
}
```

**Explicação das escolhas:**

- O `UStaticMeshComponent` é criado no construtor com `CreateDefaultSubobject` — o jeito padrão de compor componentes em C++ (Capítulo 9). O mesh em si (um cubo, por exemplo `/Engine/BasicShapes/Cube`) é escolhido no editor: **conteúdo é decidido no editor, não no código**.
- O alvo troca de posição por **timer**, não por tick — é um evento discreto no tempo (Capítulo 2, seção 2.6).
- `DrawDebugSphere` mostra o alvo no mundo: observabilidade visual (Capítulo 1, seção 1.9). Funções de debug desenhado são removidas automaticamente de builds Shipping.
- Os três modos convivem em um `switch` porque é um ator de **diagnóstico**. Em código de produção, não haveria um modo "ingênuo" para escolher.

---

## Decisões arquiteturais

1. **Gameplay usa Δt variável da engine.** Não reescrevemos o loop da Unreal para passo fixo.
2. **Suavização e amortecimento usam decaimento exponencial.** Nenhum `Lerp` com fator constante por frame no projeto. `VGMath::ExpDecayTo` é o padrão; `FInterpTo` é aceitável onde a diferença não importa.
3. **Sistemas sensíveis ao passo usam acumulador local ou a física da engine.** Decidido caso a caso, com justificativa no `DEVLOG.md`.
4. **Aleatoriedade de gameplay usa `FRandomStream` com semente controlável.** Não por determinismo de rede — por reprodutibilidade de bugs.
5. **Todo sistema declara seu relógio.** Tempo de jogo (padrão), tempo sem pausa, ou tempo real. UI e efeitos de "congelamento" de impacto não usam tempo de jogo.
6. **Unidade de input decidida no mapeamento.** Mouse = deslocamento; analógico = taxa × Δt, via configuração do Enhanced Input (Capítulo 14).

---

## Armadilhas

- **`Lerp` e multiplicadores constantes por frame.** O bug mais comum deste capítulo. Procure no código por `Lerp(` e `*= 0.` dentro de ticks.
- **Multiplicar deslocamento de mouse por Δt.** A mira fica dependente do frame rate.
- **Esquecer o teto de Δt em simulações próprias.** Uma travada de carregamento vira um salto de 2 segundos — ou uma espiral da morte.
- **Confiar em determinismo que você não tem.** Física da engine, ordem de iteração de contêineres e ponto flutuante entre plataformas.
- **Timers sob time dilation.** Um efeito de "congelamento" de 0,1 s implementado com dilatação global de 0,05 e um timer de jogo de 0,1 s dura **2 segundos reais** — o timer também desacelerou. (Esse é o desafio deste capítulo.)
- **Ler o relógio do sistema em lógica de jogo.** Quebra pausa, câmera lenta e replays.
- **Testar sempre no mesmo frame rate.** Se a sua máquina roda a 144 FPS, você nunca vê os bugs de 30. Use `t.MaxFPS`.

---

## Exercício

**Parte 1 — numérica (1 h).**
Rode o `jump_integration.cpp` e reproduza a tabela da seção 3.1. Em seguida, acrescente uma terceira coluna em que, para cada frame rate, o pulo é simulado com **substepping**: cada frame é dividido em subpassos de no máximo 1/120 s. Quanto a variação entre 20 e 240 FPS diminui?

**Parte 2 — passo fixo (1 h).**
Rode o `fixed_step.cpp`. Depois:
1. Remova a interpolação (renderize `Current.X`) e compare `renderX` frame a frame. Descreva o efeito que isso teria na tela a 144 FPS.
2. Troque o teto de 250 ms por 1 s e observe o que acontece com os passos após as travadas.
3. Escreva um teste (qualquer framework, ou um `assert`) que verifique que `Simulate` executado 60 vezes com `FixedDt` produz exatamente o mesmo `State`, sempre.

**Parte 3 — Unreal (1,5 h).**
Coloque três `AVGSmoothingProbe` lado a lado (um em cada modo, todos com mesh de cubo e `Rate = 6.32`). Dê *Play* e, no console:
1. `t.MaxFPS 20`, depois `t.MaxFPS 60`, depois `t.MaxFPS 144`. Qual probe muda de comportamento? Qual não muda?
2. `slomo 0.2`. Qual probe **não** desacelera? Por quê?
3. Com `t.MaxFPS 5` (extremo), compare `InterpTo` e `ExpDecay`. O que acontece com `InterpTo` quando `DeltaSeconds × Rate ≥ 1`?

Registre as observações no `DEVLOG.md`.

---

## Desafio — *hitstop* que não trava

*Hitstop* é um congelamento curtíssimo (50–120 ms) do jogo no momento de um impacto forte. É uma técnica clássica de *game feel* em jogos de ação: o cérebro registra o "peso" do golpe.

Implemente um `UVGHitstopComponent` (ou função utilitária) com a assinatura `TriggerHitstop(float RealDurationSeconds, float TimeScale)`:

1. Ao ser chamado, aplica `SetGlobalTimeDilation(TimeScale)` (por exemplo, 0,05).
2. Após `RealDurationSeconds` **em tempo real**, restaura a dilatação para 1.
3. Se um novo hitstop for disparado durante outro, o efeito deve ser estendido, não empilhado.

A armadilha: um timer comum (`SetTimer` com 0,08 s) roda em tempo de jogo — com dilatação de 0,05, ele dura 1,6 s reais. Resolva de **duas** formas e compare:
- (a) compensando a duração do timer pela escala de tempo;
- (b) verificando em `Tick` o tempo real decorrido com `GetWorld()->GetRealTimeSeconds()` (lembre-se: com dilatação, o tick do próprio componente também desacelera — mas ele continua acontecendo a cada frame renderizado).

Qual das duas é mais robusta se, no futuro, outro sistema (o bullet time, por exemplo) também mexer na dilatação global? O que isso sugere sobre ter **um único dono** para a dilatação global do jogo? *(Guarde a resposta: ela antecipa a discussão sobre subsistemas no Capítulo 6.)*

---

## Uso de IA

1. **Para verificar sua matemática:**
   > "Tenho uma suavização `x = lerp(x, alvo, 0.15)` executada por frame, ajustada a 60 FPS. Derive passo a passo a forma independente de frame rate usando decaimento exponencial, calcule a taxa equivalente em 1/s e explique quanto da distância resta após 0,5 s a 30 e a 144 FPS nas duas versões."
   *(Faça a conta você primeiro.)*

2. **Para auditar código:**
   > "Revise este código de tick em C++ da Unreal procurando dependências de frame rate: multiplicadores por frame, lerps com fator constante, input de mouse multiplicado por DeltaTime, uso de tempo real em lógica de jogo e timers afetados por time dilation. Para cada problema, explique o sintoma que o jogador veria."

3. **Para aprofundar integração:**
   > "Compare Euler explícito, Euler semi-implícito, Verlet e RK4 para simulação em jogos: precisão, estabilidade com molas, custo e conservação de energia. Use um exemplo de mola amortecida simulada a 30 FPS. Aponte qual é mais comum em código de gameplay e por quê."

4. **Para relacionar com multiplayer (antecipação):**
   > "Explique por que jogos de estratégia com centenas de unidades historicamente usaram lockstep determinístico, enquanto shooters usam servidor autoritativo com replicação de estado. Relacione com passo fixo, ponto flutuante e largura de banda."

**Cuidado específico:** nomes de *console variables* e opções de configuração da Unreal mudam entre versões, e IAs frequentemente inventam cvars plausíveis. Antes de usar uma, confirme no console do editor (o autocompletar mostra as existentes) ou na documentação.

---

## Checklist

- [ ] Sei explicar por que `x += v * dt` é exato e `v *= 0.9f` por frame não é.
- [ ] Sei por que a altura de um pulo pode variar com o frame rate, e duas formas de mitigar.
- [ ] Sei converter um fator "por frame" para uma taxa exponencial e escrever `1 − e^(−kΔt)`.
- [ ] Sei quais inputs multiplicar por Δt (taxa) e quais não (deslocamento).
- [ ] Implementei passo fixo com acumulador, teto e interpolação, e sei explicar a espiral da morte.
- [ ] Sei a diferença entre passo fixo e substepping, e o trade-off de interpolar vs. extrapolar.
- [ ] Conheço as fontes de não determinismo e sei usar `FRandomStream`.
- [ ] Sei distinguir `GetTimeSeconds`, `GetUnpausedTimeSeconds` e `GetRealTimeSeconds`.
- [ ] Sei usar `slomo`, `SetGlobalTimeDilation` e `CustomTimeDilation`, e usá-los como ferramenta de teste.
- [ ] Consigo decompor o bullet time de Max Payne pela Ficha de Decomposição.

---

## Para ir além

- **Glenn Fiedler, "Fix Your Timestep!" e "Integration Basics"** (Gaffer On Games) — o artigo clássico sobre passo fixo e acumulador, e a introdução à integração numérica para jogos.
- **Robert Nystrom, *Game Programming Patterns*, capítulo "Game Loop"** — releia a parte sobre controle de tempo depois deste capítulo.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre configurações de física (substepping e física assíncrona) e sobre o `CharacterMovementComponent`.
- **Jason Gregory, *Game Engine Architecture*** — seções sobre tempo, relógios e o game loop.

---

➡️ **Próximo:** [Capítulo 4 — Estado e eventos](cap-04-estado-e-eventos.md)

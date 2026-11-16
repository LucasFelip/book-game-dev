# Capítulo 12 — Blueprint

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que Blueprint **é** tecnicamente — e por que ele não é "um substituto para programação", e sim uma linguagem com outro público e outros custos;
- distinguir os tipos de Blueprint (classe, Level Blueprint, interface, biblioteca de funções, Animation e Widget Blueprints);
- usar com segurança grafos de evento, funções, macros, *Construction Script*, variáveis, *Timelines* e *Event Dispatchers*;
- reconhecer as armadilhas específicas da linguagem: **nós puros reavaliados**, nós latentes, **casts que criam referências fortes**, Level Blueprint como depósito de lógica;
- avaliar o **custo de performance** de Blueprint e decidir com dados quando algo deve ir para C++;
- depurar e organizar grafos para que continuem legíveis em três meses;
- construir o **alarme da usina** — um sistema de atmosfera feito inteiramente em Blueprint.

---

## Contexto

Programadores experientes chegam à Unreal com uma de duas atitudes sobre Blueprint: desprezo ("programação de verdade é texto") ou alívio ("não vou precisar escrever C++"). As duas estão erradas, e pelo mesmo motivo: ambas tratam Blueprint como uma versão **pior ou mais fácil** de C++.

Blueprint é outra coisa. É uma linguagem de programação completa — com variáveis, funções, herança, polimorfismo, eventos e todos os bugs que isso permite —, projetada para um **público** diferente (designers, artistas técnicos, programadores prototipando) e otimizada para uma **tarefa** diferente: compor e ajustar comportamento sobre sistemas que já existem, dentro do editor, com iteração instantânea.

O Capítulo 13 responde à pergunta "o que vai em C++ e o que vai em Blueprint?". Para responder bem, primeiro é preciso conhecer Blueprint de verdade — inclusive escrevendo um sistema inteiro nele.

---

## 12.1 O que é Blueprint, tecnicamente

Um Blueprint de classe é um **asset** que, quando compilado no editor, gera uma **classe de verdade** (`UBlueprintGeneratedClass`) no sistema de objetos da Unreal. Ela é indistinguível, para a engine, de uma classe C++: pode ser instanciada, herdada, ter CDO (Capítulo 8), propriedades refletidas e funções.

O comportamento dessa classe — os grafos — é compilado para **bytecode** e executado por uma **máquina virtual** (historicamente chamada de *Kismet VM*). Cada nó do grafo vira uma ou mais instruções desse bytecode. Quando um nó chama uma função C++ (`SetActorLocation`, `Drain` do seu `UVGBatteryComponent`), a VM faz a ponte para o código nativo via o sistema de reflexão.

```text
  BP_PosteLuz.uasset ──compilar no editor──► UBlueprintGeneratedClass "BP_PosteLuz_C"
                                                  │ herda de
                                                  ▼
                                             AActor (C++)
                                                  │
  grafo "Event BeginPlay → Set Timer → ..."  ──► bytecode, executado pela VM
                                                  │ chama
                                                  ▼
                                   funções C++ expostas via UFUNCTION
```

Duas consequências:

- **Blueprint e C++ são o mesmo sistema de tipos.** Um Blueprint pode herdar de uma classe C++ (o padrão do projeto: `BP_VGJogadora` herda de `AVGCharacter`), e C++ pode chamar funções implementadas em Blueprint (Capítulo 13).
- **Blueprint tem custo de interpretação.** Cada nó executado passa pela VM. Para lógica disparada por eventos, isso é irrelevante. Para cálculos pesados executados todo frame em muitos atores, pode não ser (seção 12.6).

> 🌉 **Ponte:** a analogia mais honesta não é "low-code" — é **uma linguagem de script embutida numa plataforma**, como Lua em muitas engines, ou como Groovy/Kotlin script num sistema JVM: compila para uma VM, chama código nativo da plataforma, serve para compor e configurar.
>
> 🧱 **Onde a ponte cai:** linguagens de script textuais têm diff, merge, busca, refatoração automática e revisão de código maduros. Blueprint é **binário**: não há merge de dois Blueprints editados em paralelo, e o diff existe apenas dentro do editor. Isso tem consequências de processo (seção 12.8).

---

## 12.2 Tipos de Blueprint

| Tipo | O que é | Uso na Vigília |
|---|---|---|
| **Blueprint Class** | Classe derivada de qualquer classe (Actor, Component, Object) | Quase todo conteúdo: `BP_PosteLuz`, `BP_VGJogadora`, portas, interativos |
| **Level Blueprint** | Grafo único associado a **um nível** | Prototipação e eventos únicos do nível; **deliberadamente** no Projeto 4 |
| **Blueprint Interface** | Declaração de funções que classes implementam | Contratos entre conteúdo (Capítulo 19 usa interface C++) |
| **Blueprint Function Library** | Funções estáticas reutilizáveis | Utilitários de conteúdo |
| **Blueprint Macro Library** | Macros reutilizáveis | Raramente |
| **Animation Blueprint** | Lógica de animação de um esqueleto | Capítulo 53 |
| **Widget Blueprint** | Interface de usuário (UMG) | Capítulo 55 |
| **Editor Utility Blueprint/Widget** | Ferramentas que rodam no editor | Ferramentas de level design (Capítulo 50) |

---

## 12.3 Anatomia de um Blueprint de classe

Um Blueprint de classe tem vários grafos e painéis. Os essenciais:

### Componentes e variáveis

O painel **Components** é a árvore do Capítulo 9, editável visualmente. O painel **My Blueprint** lista variáveis, funções, macros, *event dispatchers* e grafos.

Variáveis têm flags que espelham os especificadores de `UPROPERTY` (Capítulo 11):

- **Instance Editable** (o "olho" ao lado da variável) — editável por instância no nível (≈ `EditAnywhere`);
- **Expose on Spawn** — aparece como parâmetro no nó *Spawn Actor from Class*, configurado **antes** do *BeginPlay* (o equivalente visual do spawn diferido do Capítulo 8);
- **Private** — invisível para outros Blueprints;
- **Category**, **Tooltip**, limites de valor.

### Event Graph

O **Event Graph** contém **eventos**: nós vermelhos que são pontos de entrada (`Event BeginPlay`, `Event Tick`, `Event ActorBeginOverlap`, eventos customizados) e as cadeias de nós que eles executam. Os nós se conectam por dois tipos de fio:

- **Fios de execução** (brancos) — definem a **ordem** em que nós com efeito colateral executam;
- **Fios de dados** (coloridos por tipo) — levam valores de saídas para entradas.

### Funções, eventos customizados e macros

| | Função | Evento customizado | Macro |
|---|---|---|---|
| Retorna valores | ✓ | ✗ | ✓ (múltiplas saídas) |
| Variáveis locais | ✓ | ✗ | ✓ (locais da macro) |
| Pode conter nós latentes (`Delay`) | **✗** | ✓ | ✓ (se usada num grafo de eventos) |
| Pode ser chamada de outro Blueprint | ✓ | ✓ | ✗ (só da classe/biblioteca) |
| Pode ser sobrescrita por filhos | ✓ | ✓ | ✗ |
| Pode ser ligada a um *dispatcher* / timer | ✗ (diretamente) | ✓ | ✗ |

A regra prática: **funções para lógica e cálculos; eventos para pontos de entrada e para tudo que envolve tempo; macros raramente.** O erro mais comum é colocar lógica pesada diretamente no Event Graph em cadeias longas, em vez de funções nomeadas — o primeiro passo para o espaguete (seção 12.7).

### Construction Script

O **Construction Script** é o `OnConstruction` do Capítulo 8 em forma de grafo: executa no editor a cada mudança de propriedade ou movimento do ator. É a ferramenta de **level design procedural**: uma cerca que se estende com base num comprimento, uma fileira de lâmpadas que se distribui ao longo de um corredor. Lógica de gameplay não pertence a ele.

---

## 12.4 Ferramentas de tempo e comunicação

### Nós latentes

Alguns nós "esperam": **`Delay`**, **`Retriggerable Delay`**, **`Move Component To`**, `AI Move To`. Eles são **nós latentes**: o grafo para naquele ponto e continua num frame futuro. Eles são a versão visual das cadeias de atrasos do Capítulo 4 (seção 4.7) — com as mesmas forças e as mesmas fraquezas:

- são ótimos para sequências curtas e simples;
- não têm estado consultável ("em que passo está?");
- não são canceláveis diretamente (um `Delay` em andamento continua, a menos que o ator seja destruído);
- disparos repetidos do evento podem se sobrepor de formas inesperadas (um `Delay` normal **ignora** novos disparos enquanto está esperando; um `Retriggerable Delay` **reinicia** a espera).

As cinco perguntas de cancelamento do Capítulo 4 valem para todo grafo com `Delay`.

### Timelines

Uma **Timeline** é um nó com curvas e eventos ao longo de um tempo, editados visualmente: uma curva de intensidade de luz de 0 a 1 em 2 segundos, um evento no segundo 1,5. Ela pode tocar para frente, para trás, parar, reiniciar e ter duração e taxa ajustáveis. É a ferramenta ideal para animações simples de propriedades (uma porta abrindo, uma luz pulsando, um objeto flutuando) — e o equivalente visual do acumulador `OpenAlpha` com curva do Capítulo 1.

Diferentemente de um `Delay`, uma Timeline **tem estado** (posição, se está tocando) e **é controlável** (parar, inverter). Para movimentos de objetos interativos autorados por designers, é frequentemente a escolha certa.

### Event Dispatchers

Um **Event Dispatcher** é um **multicast delegate** declarado em Blueprint — o `OnBatteryStateChanged` do Capítulo 4, na versão visual. O dono chama **Call**; outros objetos fazem **Bind** com um evento customizado. Tudo o que o Capítulo 4 disse sobre eventos síncronos (ordem, reentrância, desinscrição) vale integralmente.

---

## 12.5 As armadilhas específicas da linguagem

### Armadilha 1 — Nós puros são reavaliados a cada uso

Nós **puros** (verdes, sem pino de execução — como `Get Actor Location`, `Random Float`, operações matemáticas) **não guardam resultado**. Eles são reavaliados **toda vez que uma saída deles é lida**.

```text
          ┌──────────────────┐
          │ Random Float     │──┬────► Set Intensity (Luz A)
          │ in Range (0, 1)  │  │
          └──────────────────┘  └────► Set Intensity (Luz B)

  Expectativa: as duas luzes recebem o MESMO número.
  Realidade:   o nó roda DUAS vezes; cada luz recebe um número diferente.
```

Com `Random`, o bug é visível. Com nós puros caros (um `Get All Actors Of Class` exposto como função pura, um cálculo pesado), o bug é **invisível e custa performance**: o cálculo roda uma vez para cada fio que sai dele. A correção é guardar o valor numa variável local (em funções) ou numa variável do Blueprint, ou usar a versão impura do nó.

### Armadilha 2 — Cast cria referência forte

O nó **`Cast To BP_VGJogadora`** parece inofensivo. Mas, para que ele exista, o Blueprint que o contém precisa conhecer a classe `BP_VGJogadora` — o que cria uma **referência forte** (Capítulo 7) a ela. Carregar o Blueprint que faz o cast **carrega a jogadora e tudo o que ela referencia**: malha, animações, sons, materiais, a arma, os Blueprints que a arma referencia...

O resultado clássico, em projetos que crescem: um Blueprint pequeno de uma porta, ao ser carregado, arrasta centenas de megabytes de assets, porque faz cast para a jogadora, que referencia a arma, que referencia efeitos, que referenciam texturas. O **Size Map** (Capítulo 7) revela isso imediatamente.

As alternativas, em ordem de preferência:

1. **Cast para a classe C++ base** (`Cast To VGCharacter`): classes C++ não têm assets associados; o cast não carrega conteúdo.
2. **Interfaces** (Capítulo 19): o Blueprint pergunta "você implementa *Interactable*?" sem conhecer a classe concreta.
3. **Gameplay Tags** (Capítulo 23): identificar papéis por tag, não por classe.

Essa é uma das razões estruturais pelas quais a regra de camadas do projeto (classes base em C++) existe: **casts entre Blueprints de conteúdo são um risco de memória**, e as classes C++ base oferecem um alvo de cast seguro.

### Armadilha 3 — O Level Blueprint como depósito de lógica

O Level Blueprint é tentador: ele pode referenciar **diretamente** qualquer ator do nível (arraste o ator do Outliner para o grafo), sem configurar nada. Para um evento único de um nível — "quando a jogadora pisar aqui, toque esta cinemática" —, é uma ferramenta legítima e rápida.

Os problemas aparecem quando ele vira o lugar onde **sistemas** são implementados:

- a lógica **não é reutilizável** em outro nível;
- ela **não é acessível** a outros Blueprints (nada pode chamar o Level Blueprint);
- o estado guardado nele (variáveis do Level Blueprint) é **invisível** para o save e para qualquer outro sistema;
- num nível com muitos eventos, ele vira um grafo gigante impossível de navegar.

O Projeto 4 (Interlúdio I) será construído **propositalmente** com Level Blueprint e variáveis soltas — e a Parte VI vai medir o custo dessa escolha. Até lá, a regra: **Level Blueprint só para eventos únicos e específicos daquele nível.**

### Armadilha 4 — Tick em Blueprint

`Event Tick` em Blueprint é o lugar onde o custo de interpretação mais aparece, porque roda todo frame em toda instância. Os princípios do Capítulo 2 valem em dobro: desligar o tick quando não for necessário (*Start with Tick Enabled* desmarcado; `Set Actor Tick Enabled`), usar *Tick Interval*, preferir timers e eventos.

### Armadilha 5 — Referências nulas silenciosas

Um nó chamado sobre uma referência nula (*None*) não derruba o jogo: ele **não executa** e registra um erro no log ("Accessed None trying to read property..."). Isso é mais amigável que um crash, e mais perigoso: o comportamento simplesmente não acontece, e o erro pode passar despercebido no meio do log. Use **`Is Valid`** (o nó com dois pinos de saída) antes de usar referências que podem ser nulas, e leia o log do PIE com atenção — o editor mostra um resumo desses erros ao parar o jogo.

---

## 12.6 Performance: quando Blueprint custa

A pergunta "Blueprint é lento?" não tem resposta útil sem contexto. A pergunta útil é: **quanto custa este grafo, quantas vezes por frame, em quantas instâncias?**

O custo de Blueprint está essencialmente em **executar nós**. Cada nó tem um custo fixo de passagem pela VM, maior que uma operação equivalente em C++ compilado. Quando o nó chama uma função nativa que faz muito trabalho (um *trace*, um spawn), o custo da VM é desprezível em relação ao da função. Quando o grafo faz muitas operações pequenas (matemática de vetores, laços, comparações), o custo da VM domina.

```text
  CUSTO IRRELEVANTE                            CUSTO PODE IMPORTAR
  ─────────────────                            ───────────────────
  Event BeginPlay → configurar                 Event Tick em 300 instâncias
  Overlap → abrir porta                        ForEachLoop sobre 1.000 elementos todo frame
  Timer a cada 2 s → spawn                     matemática vetorial pesada por frame
  Input → disparar arma                        busca/ordenação em arrays grandes
  (eventos: poucos por segundo)                (trabalho contínuo × instâncias)
```

Duas observações de método:

- **Meça antes de mover para C++.** O comando `stat game` mostra o tempo de *tick* do mundo; o **Unreal Insights** (Capítulo 59) mostra quais Blueprints custam. Mover para C++ algo que custa 0,02 ms por frame é trocar iteração por nada.
- **A Unreal 5 não tem "nativização" de Blueprint.** O recurso que, no UE4, convertia Blueprints em C++ automaticamente no empacotamento foi removido. Se um Blueprint é caro, a solução é você mover a parte cara para uma função C++ (Capítulo 13).

O exercício deste capítulo inclui uma medição real, para que a sua intuição sobre o custo venha de dados e não de folclore.

---

## 12.7 Organização e depuração

### Depurar

O depurador de Blueprint é bom, e quase ninguém o usa no começo:

- **Breakpoints** (F9 num nó) — a execução para naquele nó durante o PIE.
- **Seletor de objeto de depuração** (na barra do editor de Blueprint) — escolhe **qual instância** está sendo observada; sem isso, você vê o fluxo "de alguma instância".
- **Watch** em pinos — mostra o valor que passou por aquele fio.
- **Execução visível** — durante o PIE, com o Blueprint aberto, os fios de execução **acendem** quando são percorridos. É uma das formas mais rápidas de ver "este evento está disparando?".
- **`Print String`** — o `System.out.println` do Blueprint; útil, temporário, nunca deixe no conteúdo final (ele é removido em Shipping, mas polui o desenvolvimento).

### Organizar

Grafos ficam ilegíveis rápido. Regras de higiene que valem para o projeto:

1. **Eventos curtos que chamam funções nomeadas.** O Event Graph deve ler como um índice: `BeginPlay → InitializeAlarm`; `StartAlarm → PlaySirenSequence`.
2. **Funções com nomes de intenção**, não de mecanismo (`ShouldTriggerAlarm`, não `CheckBoolAndTimer`).
3. **Comentários de bloco** (tecla `C` com nós selecionados) explicando o *porquê*.
4. **Reroute nodes** para fios longos; evitar fios cruzando o grafo inteiro.
5. **Variáveis com categoria e tooltip**, especialmente as editáveis por instância — o designer que coloca o ator no nível lê o tooltip.
6. **Collapse to Function** quando um trecho se repete ou passa de ~15 nós.
7. **Nenhuma lógica sem dono:** se um grafo começa a decidir coisas sobre o estado de outros sistemas, ele está violando a regra do dono único (Capítulo 4).

---

## 12.8 Blueprint e controle de versão

Como `.uasset` é binário, **dois Blueprints editados em paralelo não se fundem**. Em equipe, isso exige bloqueio de arquivo (LFS locking ou Perforce — Capítulo 7). Mesmo sozinho, há consequências:

- **Revisões de código são difíceis.** O editor tem uma ferramenta de **diff de Blueprint** (comparar com uma revisão anterior do controle de versão), que mostra nós adicionados, removidos e alterados. Use-a antes de commitar mudanças grandes.
- **Mensagens de commit importam mais.** Como o diff textual não existe, a mensagem é a principal documentação do que mudou.
- **Lógica complexa e estável vai para C++**, onde diff, revisão, busca e refatoração funcionam. Esse é um critério real, não estético, da divisão do Capítulo 13.

---

## 12.9 Quando Blueprint brilha

Blueprint é a ferramenta **certa** para:

- **comportamento específico de conteúdo** — "esta porta, neste nível, faz este som e esta luz pisca quando ela abre";
- **composição** de sistemas C++ — ligar o evento da bateria ao flicker da lanterna (desafio do Capítulo 9);
- **ajuste fino** de valores e curvas;
- **prototipação** — testar uma ideia de mecânica em uma hora antes de decidir se vale implementar em C++;
- **sequências e atmosfera** — eventos roteirizados simples, efeitos ambientes;
- **UI** (Widget Blueprints) e **animação** (Animation Blueprints), onde as ferramentas visuais são o fluxo principal;
- **trabalho de designers** — o público para o qual a linguagem foi feita.

E é a ferramenta **errada** para: sistemas centrais com muitas regras, lógica que roda todo frame em muitas instâncias, algoritmos (busca, ordenação, matemática pesada), código que precisa de revisão cuidadosa, e qualquer coisa que outros sistemas C++ precisem chamar com frequência.

---

## Comparação com o desenvolvimento tradicional

| Blueprint | Equivalente que você conhece | Onde a analogia cai |
|---|---|---|
| Linguagem visual compilada para VM | Linguagem de script embutida (Lua, Groovy) | Binário: sem merge, diff só no editor |
| Event Graph | Handlers de eventos | Nós latentes misturam tempo no fluxo |
| Nós puros | Expressões/funções puras | São **reavaliados a cada uso**; não há memoização |
| Cast entre Blueprints | Cast de tipo | Cria referência forte de asset → custo de memória |
| Event Dispatcher | Observer / multicast delegate | Síncrono, como os delegates C++ (Capítulo 4) |
| Level Blueprint | Script de configuração de um ambiente | Não reutilizável, não acessível, estado invisível |
| Timeline | Animação/tween declarativo | Tem estado e é controlável — o que `Delay` não tem |

---

## Implementação: o alarme da usina (100% Blueprint)

### O que é

Um sistema de atmosfera para o Pátio: a cada intervalo (por exemplo, 90 segundos), uma **sirene** soa na caixa d'água, uma luz vermelha pulsa, e **todos os postes falham** brevemente enquanto o alarme toca — como se a rede elétrica da usina sofresse com uma carga súbita. Ninguém explica por quê. É o primeiro "evento" do mundo da Vigília, e o primeiro sinal de que a usina está viva.

O sistema é feito **inteiramente em Blueprint**, de propósito: é comportamento de conteúdo, específico do Pátio, que um designer ajustaria. Ele reutiliza o `UVGFlickerComponent` (C++) do Capítulo 9.

### Convenção de notação de grafos

Como o livro é texto, grafos de Blueprint serão escritos nesta notação:

```text
[Evento]              nó de evento (ponto de entrada)
→                     fio de execução
Nó(Param=Valor)       nó com parâmetros relevantes
⇢ [Evento Custom]     nó que dispara/liga a um evento customizado
{var}                 variável do Blueprint
-- comentário
```

### `BP_AlarmeUsina`

**Componentes:**

```text
BP_AlarmeUsina
└── Root (Scene)
    ├── LuzAlarme (PointLight, cor vermelha, Mobility Movable, Intensity 0)
    └── Sirene (Audio, Auto Activate desmarcado, som de sirene — placeholder se não tiver)
```

**Variáveis:**

| Variável | Tipo | Flags | Padrão | Tooltip |
|---|---|---|---|---|
| `IntervaloAlarme` | float | Instance Editable | 90 | Segundos entre alarmes |
| `DuracaoAlarme` | float | Instance Editable | 6 | Duração de cada alarme |
| `IntensidadeMaxima` | float | Instance Editable | 8000 | Pico da luz vermelha |
| `PadraoFalhaPostes` | string | Instance Editable | `mmamaammaaaamma` | Padrão aplicado aos postes durante o alarme |
| `bAlarmeAtivo` | bool | Private | false | Estado: evita disparos sobrepostos |

**Event Dispatchers:** `OnAlarmeIniciado`, `OnAlarmeTerminado`.

**Timeline `TL_Pulso`:** duração = 1 s, *loop* ligado, uma faixa de float `Pulso` com curva 0 → 1 → 0 (suave).

**Grafo:**

```text
[Event BeginPlay]
  → Set Timer by Event(Time={IntervaloAlarme}, Looping=true)  ⇢ [IniciarAlarme]

[IniciarAlarme]                                    -- evento customizado
  → Branch(Condition={bAlarmeAtivo})
      True  → (nada: já está tocando)
      False → Set {bAlarmeAtivo} = true
            → Sirene.Play
            → TL_Pulso.Play from Start
            → Call OnAlarmeIniciado
            → Set Timer by Event(Time={DuracaoAlarme}, Looping=false)  ⇢ [TerminarAlarme]

[TL_Pulso.Update]
  → LuzAlarme.Set Intensity(NewIntensity = Pulso × {IntensidadeMaxima})

[TerminarAlarme]
  → TL_Pulso.Stop
  → LuzAlarme.Set Intensity(0)
  → Sirene.Stop
  → Set {bAlarmeAtivo} = false
  → Call OnAlarmeTerminado
```

Observe como as lições dos capítulos anteriores aparecem num grafo visual:

- **`bAlarmeAtivo` é uma guarda de estado** (Capítulo 4): o alarme não dispara duas vezes se o intervalo for menor que a duração.
- **Timers, não `Delay`:** o fim do alarme é agendado por timer para um evento nomeado, o que deixa claro onde o alarme termina — e permite, no futuro, cancelá-lo (`Clear Timer by Handle`).
- **A Timeline anima a luz** com estado e controle (parar no fim), em vez de um `Tick`.
- **O alarme anuncia** início e fim por dispatchers; ele não sabe quem reage.

### Quem reage: os postes

O `BP_PosteLuz` do Capítulo 9 ganha um comportamento novo, também em Blueprint:

**Variáveis novas:** `Alarme` (referência a `BP_AlarmeUsina`, Instance Editable), `PadraoNormal` (string, Instance Editable, padrão vazio).

```text
[Event BeginPlay]
  → Is Valid({Alarme})
      Is Valid → Bind Event to OnAlarmeIniciado(Target={Alarme})  ⇢ [AoIniciarAlarme]
               → Bind Event to OnAlarmeTerminado(Target={Alarme}) ⇢ [AoTerminarAlarme]
      Is Not Valid → (nada: poste independente)

[AoIniciarAlarme]
  → Flicker.SetPattern(NewPattern = {Alarme}.PadraoFalhaPostes)

[AoTerminarAlarme]
  → Flicker.SetPattern(NewPattern = {PadraoNormal})

[Event EndPlay]
  → Is Valid({Alarme})
      Is Valid → Unbind Event from OnAlarmeIniciado(Target={Alarme})
               → Unbind Event from OnAlarmeTerminado(Target={Alarme})
```

No nível, cada poste aponta para o alarme pelo campo `Alarme` (referência editável — a forma preferida de conectar atores, Capítulo 8). Postes que não apontam para ele não participam.

Repare em três decisões:

- **A referência é para `BP_AlarmeUsina`**, um Blueprint — o que, pela Armadilha 2, cria uma referência forte entre os dois assets. Aqui isso é aceitável: o alarme é pequeno e os dois vivem sempre juntos no Pátio. Num sistema que cresce, o alarme viraria uma classe C++ base (Capítulo 13) ou o poste escutaria um evento global (Capítulo 24).
- **`EndPlay` desfaz as inscrições** (Capítulo 4, Risco 3).
- **O poste guarda o seu `PadraoNormal`** para restaurar depois — o "componente que altera vizinhos restaura o estado" do Capítulo 9, aplicado ao conteúdo.

### Teste

Coloque o `BP_AlarmeUsina` no topo da caixa d'água, com `IntervaloAlarme = 15` para testar. Ligue três postes a ele e deixe um independente. Dê *Play*, caminhe (ou voe) até a altura dos olhos e espere. Depois:

- ponha `IntervaloAlarme = 3` e `DuracaoAlarme = 6`, e verifique que a guarda impede sobreposição;
- abra o `BP_AlarmeUsina` durante o PIE e veja os fios de execução acenderem;
- rode `vg.Flicker.Enabled 0` (Capítulo 11) e observe que os postes param de falhar, mas a sirene e a luz vermelha continuam — a opção de acessibilidade age onde deve.

---

## Decisões arquiteturais

1. **Blueprint é a linguagem de conteúdo do projeto**: composição, ajuste, atmosfera, eventos específicos de nível, UI e animação.
2. **Event Graph como índice**; lógica em funções nomeadas; eventos customizados para tudo que envolve tempo.
3. **Timelines para animar propriedades**; **timers para agendar**; `Delay` só em sequências curtas sem necessidade de cancelamento.
4. **Casts para classes C++ base**, nunca entre Blueprints de conteúdo que possam crescer; interfaces e tags quando possível.
5. **Level Blueprint apenas para eventos únicos do nível** — com a exceção deliberada do Projeto 4.
6. **Tick em Blueprint desligado por padrão.** Custo medido antes de qualquer migração para C++.
7. **Inscrições em dispatchers são desfeitas no `EndPlay`.**
8. **Toda variável editável por instância tem categoria e tooltip.**

---

## Armadilhas

- **Nós puros caros ou aleatórios com múltiplas saídas.**
- **Casts entre Blueprints de conteúdo**, arrastando cadeias de assets para a memória.
- **Sistemas no Level Blueprint.**
- **Tick em Blueprint por padrão em todo ator.**
- **"Accessed None" ignorado** no log.
- **Cadeias de `Delay` sem guarda** contra disparos repetidos e sem plano de cancelamento.
- **Grafos de 200 nós** sem funções nem comentários.
- **Mover para C++ sem medir.**
- **Editar o mesmo Blueprint em dois branches.**

---

## Exercício

**Parte 1 — o alarme (2 h).** Implemente o `BP_AlarmeUsina` e a reação dos postes. Faça os testes da seção de implementação e registre no `DEVLOG.md` o que funcionou e o que surpreendeu.

**Parte 2 — a armadilha dos nós puros (20 min).** Num Blueprint de teste, ligue um `Random Float in Range` a dois `Print String`. Observe os valores. Corrija guardando o valor numa variável. Depois, encontre um nó puro **caro** na paleta (por exemplo, `Get All Actors Of Class` usado dentro de uma função pura sua) e explique o risco.

**Parte 3 — a armadilha do cast (30 min).** Crie um Blueprint `BP_TesteCast` com um único nó `Cast To BP_VGJogadora`. Abra o **Size Map** e o **Reference Viewer** dele. Troque por `Cast To VGCharacter` (a classe C++) e compare. *(Num projeto ainda pequeno, a diferença é modesta; imagine a jogadora com malha, animações e arma.)*

**Parte 4 — medição de custo (1,5 h).** Crie `BP_TickTeste`, um ator cujo `Event Tick` executa um laço de 100 iterações somando vetores. Crie um `AVGSpawner` (Capítulo 8) que gere 200 instâncias dele. Meça com `stat game` (*World Tick Time*) e `stat unit`. Depois, implemente o mesmo laço numa função C++ `BlueprintCallable` (adiantando o Capítulo 13), chame-a do `Event Tick` e meça de novo. Registre: quanto custava, quanto passou a custar e quantas instâncias seriam necessárias para o custo ser relevante num orçamento de 16,67 ms.

---

## Desafio — o alarme que escala

O alarme hoje é regular e previsível — o que, num jogo de terror, rapidamente vira ruído de fundo (lembre-se do pacing do Capítulo 5: tensão constante deixa de ser tensão). Modifique-o para que:

1. o intervalo entre alarmes **varie** aleatoriamente dentro de uma faixa (com `Random Float in Range` usado **corretamente**);
2. **nenhum alarme** dispare enquanto a jogadora estiver dentro da guarita (dica: um volume de *overlap* — você vai formalizar isso no Capítulo 15; pode adiantar);
3. o alarme fique **mais frequente** a cada vez que toca, até um limite (uma realimentação positiva — Capítulo 5).

Depois, responda no `DEVLOG.md`: quais destas regras são **conteúdo** (específicas do Pátio) e quais começam a parecer **sistema** (algo que outros níveis da usina precisariam)? Qual delas você moveria para C++ primeiro, e por quê? *(Guarde a resposta para o Capítulo 13.)*

---

## Uso de IA

1. **Para traduzir grafos em texto e vice-versa:**
   > "Vou descrever um grafo de Blueprint da Unreal Engine 5 nesta notação: [Evento] → Nó(Param) ⇢ [Evento custom]. Revise-o procurando: nós puros reavaliados, casts que criam referências fortes, Delays sem guarda de reentrância, inscrições em dispatchers sem remoção e lógica que deveria estar em função. [grafo]"

2. **Para decidir entre Blueprint e C++:**
   > "Para cada comportamento a seguir, de um jogo de terror em primeira pessoa, diga se deveria ser implementado em Blueprint, em C++ ou nos dois (classe base C++ + Blueprint), justificando por público (designer vs. programador), frequência de execução, número de instâncias, necessidade de revisão de código e reutilização: [lista]."

3. **Para aprender a depurar:**
   > "Meu Blueprint de porta na Unreal Engine 5 às vezes não abre quando a jogadora interage. Liste uma estratégia de depuração passo a passo usando as ferramentas do editor (breakpoints, seletor de objeto de depuração, watch, fios de execução acesos, log de 'Accessed None'), em ordem do mais rápido ao mais profundo."

**Cuidado específico:** IAs não "veem" Blueprints; elas descrevem grafos de memória e frequentemente inventam nomes de nós ou misturam versões. Use a busca da paleta de nós do editor (que mostra os nós disponíveis no contexto) como fonte da verdade.

---

## Checklist

- [ ] Sei explicar Blueprint como classe gerada + bytecode numa VM que chama C++ via reflexão.
- [ ] Conheço os tipos de Blueprint e o uso de cada um.
- [ ] Sei a diferença entre função, evento customizado e macro, e por que funções não aceitam `Delay`.
- [ ] Sei usar Timelines, timers e Event Dispatchers, e quando cada um é melhor que `Delay`.
- [ ] Conheço as cinco armadilhas: nós puros, casts com referência forte, Level Blueprint, tick, referências nulas silenciosas.
- [ ] Medi o custo de um Blueprint com tick e tenho uma intuição baseada em dados.
- [ ] Sei depurar com breakpoints, seletor de instância e watch.
- [ ] Implementei o alarme da usina em Blueprint, com guarda de estado e desinscrição.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — seção **Blueprints Visual Scripting**, incluindo **Blueprint Best Practices**, **Blueprint Debugging**, **Timelines** e **Event Dispatchers**.
- **Busque talks da Epic sobre Blueprints e performance** (canal oficial Unreal Engine e Unreal Fest) — há apresentações sobre organização de Blueprints, referências de assets e quando migrar para C++.

---

➡️ **Próximo:** [Capítulo 13 — C++ + Blueprint](cap-13-cpp-e-blueprint.md)

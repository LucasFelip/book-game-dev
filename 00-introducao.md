# Desenvolvimento de Jogos com IA

### Um livro de estudos personalizado — de engenheiro de software a desenvolvedor de jogos narrativos em primeira pessoa

---

## Prefácio — para quem este livro foi escrito

Este livro foi escrito para uma única pessoa: um engenheiro de software que passa os dias projetando APIs, microsserviços, pipelines de CI/CD e sistemas distribuídos, que fez mestrado em Arquitetura de Software, e que quer conhecer em profundidade *o outro lado* da engenharia de software — o lado em que o programa não espera uma requisição chegar, porque está ocupado simulando um mundo sessenta vezes por segundo.

Ele não é um curso de programação. Você não vai encontrar aqui explicações sobre o que é uma variável, um laço ou uma interface. Também não é uma documentação da Unreal Engine — a Epic já mantém uma, e ela é boa. O que este livro tenta fazer é algo que a documentação não faz: **construir o modelo mental de um desenvolvedor de jogos** sobre a base do modelo mental que você já tem, mostrando onde suas intuições de engenharia ajudam, onde elas atrapalham e onde simplesmente não se aplicam.

A filosofia central é uma frase que vai reaparecer o livro inteiro:

> **Passar de "eu gosto dessa experiência" para "eu consigo identificar os sistemas de design e engenharia que produzem essa experiência — e construir uma versão simplificada deles".**

Alan Wake, Control, Outlast, Amnesia: A Machine for Pigs, Battlefield, Call of Duty, PES, FIFA e GTA não aparecem aqui como recomendações de jogos. Eles são **referências de design** — artefatos que você vai desmontar mentalmente, capítulo após capítulo, até que cada um deles deixe de ser uma caixa-preta mágica e passe a ser um conjunto de decisões de design implementadas por sistemas.

---

## 1. Seu perfil de aprendizagem

Antes de planejar o caminho, é preciso descrever com honestidade o ponto de partida.

**Quem você é profissionalmente.** Programador pleno em um time de pesquisa, inovação e engenharia. Trabalha com Java/Spring Boot, APIs REST, microsserviços, Docker, Kubernetes, Azure, bancos relacionais e NoSQL, mensageria, CI/CD, testes automatizados e observabilidade. Tem formação em Ciência da Computação e mestrado com foco em Arquitetura de Software.

**Como você aprende melhor (inferido do seu perfil e do que você pediu).**

- **Por sistemas, não por receitas.** Você quer entender *por que* algo é estruturado de determinada forma antes de aceitar *como*. Isso é uma vantagem enorme em game development, onde a maior parte das decisões são trade-offs, e uma desvantagem pequena: às vezes a resposta certa em jogos é "porque fica mais divertido assim", e isso não se deduz de princípios.
- **Por comparação arquitetural.** Você tem um repertório grande de padrões. O livro usa esse repertório como ponte — mas avisa quando a ponte desaba.
- **Por projetos que evoluem.** Você trabalha com sistemas que crescem, sofrem refatorações e acumulam decisões. O livro reproduz isso: um único projeto Unreal cresce ao longo de todos os capítulos, com refatorações reais e explicadas.
- **Por referências emocionais fortes.** Seus jogos favoritos não são aleatórios: eles formam famílias de problemas técnicos muito diferentes entre si (narrativa cinematográfica, horror atmosférico, FPS competitivo, simulação esportiva, mundo aberto sistêmico). Isso será usado como motor de motivação e como mapa de estudo.

**O nível-alvo do texto.** *Iniciante em desenvolvimento de jogos + profissional em engenharia de software.* Na prática isso significa:

- todo termo específico de jogos é definido na primeira vez que aparece;
- nenhum conceito geral de programação é explicado do zero;
- quando um conceito de programação aparece com uma "torção" específica de jogos (por exemplo, garbage collection, concorrência ou herança), o livro explica apenas a torção.

---

## 2. O que você já domina — e como isso transfere

A tabela abaixo é o primeiro exercício de honestidade do livro. A coluna da direita é tão importante quanto a do meio: várias das suas competências mais fortes vêm acompanhadas de hábitos que, em jogos, viram armadilhas.

| Competência que você tem | Como ela ajuda em jogos | Onde ela pode atrapalhar |
|---|---|---|
| **Arquitetura de software, DDD, Clean Architecture** | Você saberá separar responsabilidades, desenhar fronteiras de módulos e reconhecer acoplamento ruim — um dos problemas mais comuns em projetos de jogos. | A tendência de introduzir camadas, portas, adaptadores e abstrações antes da necessidade. Em jogos, a prioridade é iteração rápida e performance previsível; abstração prematura mata as duas. |
| **Modelagem orientada a objetos (herança, composição, interfaces)** | A Unreal é profundamente orientada a objetos e usa herança, interfaces e composição o tempo todo. | Hierarquias de herança profundas são uma das decisões ruins mais clássicas da história dos jogos ("a árvore de `GameObject` de 8 níveis"). Composição via componentes é o padrão dominante. |
| **Eventos, mensageria, sistemas distribuídos** | Você já entende desacoplamento por eventos, ordenação, idempotência, consistência eventual e falhas parciais. Isso é ouro em gameplay (eventos), e mais ainda em multiplayer. | Em um jogo, *polling* a cada frame é frequentemente melhor do que eventos. E "consistência eventual" em um FPS competitivo é um bug percebido em 100 ms. |
| **Gerenciamento de estado** | Jogos são, essencialmente, máquinas de estado gigantes. Você já pensa em estado, transições e invariantes. | Em backend, o estado mora no banco e o serviço é *stateless*. Em jogos, o estado vivo está **na memória**, é mutável, é compartilhado e muda dezenas de vezes por segundo. A base de dados é o save game. |
| **Concorrência** | A engine é altamente paralela internamente (render, física, animação, áudio). | O código de gameplay roda quase todo em uma única thread (*game thread*), de propósito. Paralelizar gameplay "porque sim" costuma ser um erro. |
| **Testes automatizados** | Lógica determinística (cálculo de dano, regras de quest, inventário) é testável e deve ser testada. A Unreal tem um framework de automação. | A maior parte da qualidade de um jogo não é testável por asserções: "este pulo está gostoso?" só se responde jogando. Playtest é o seu novo teste de integração. |
| **Observabilidade, debugging, profiling** | Você já pensa em métricas, traces e gargalos. Profiling de jogos é o mesmo instinto aplicado a um orçamento de 16,67 ms. | Em jogos, a ferramenta de observabilidade mais importante é **visual**: desenhar o cone de visão do inimigo na tela vale mais que mil logs. |
| **CI/CD, Docker, Kubernetes, Azure** | Builds automatizados, servidores dedicados e infraestrutura de matchmaking (Parte IX) vão parecer familiares. | Pouco disso importa nos primeiros meses. Não monte pipeline de build para um protótipo de duas semanas. |
| **Java** | Você já pensa em tipos, objetos, GC e JVM. C++ vai exigir trabalho, mas não do zero. | C++ não é "Java com ponteiros". Gerenciamento de memória, headers, compilação, macros e o dialeto próprio da Unreal (UObject, reflexão, GC próprio) exigem um modelo mental novo. |
| **Mestrado, leitura técnica, método** | Você consegue ler talks da GDC, papers de Game AI e postmortems com olhar crítico. | Risco de estudar teoria demais. Em jogos, o protótipo feio que roda vence o documento bonito que não roda. |

**Síntese:** você não precisa aprender a programar. Você precisa aprender **um domínio novo**, com restrições, prioridades e vocabulário próprios — e desaprender alguns reflexos.

---

## 3. As lacunas específicas em game development

As lacunas abaixo estão organizadas da mais fundamental para a mais especializada. Cada uma é atacada por capítulos específicos (seção 7).

### 3.1 O modelo mental de tempo real
A lacuna mais profunda e menos óbvia. Você está acostumado a programas que reagem a requisições. Jogos são **simulações contínuas** que avançam no tempo, frame após frame, com um prazo rígido por frame. Conceitos como *game loop*, *tick*, *delta time*, *fixed timestep* e *frame budget* (orçamento de frame) reorganizam toda a forma de pensar o código. **(Parte I, Caps. 1–6)**

### 3.2 Matemática espacial aplicada
Vetores, produto escalar (dot product), produto vetorial (cross product), transformações (posição, rotação, escala), espaços de coordenadas (local vs. mundo), rotações com *rotators* e *quaternions*, interpolação (lerp, slerp), curvas. Você provavelmente estudou álgebra linear na graduação; o que falta é a fluência aplicada — olhar para "o inimigo está me vendo?" e enxergar imediatamente um produto escalar e um *line trace*. **Este livro ensina matemática sob demanda**, no momento em que um sistema precisa dela (Caps. 17, 18, 27, 29, 36, 39), em vez de um capítulo isolado de matemática.

### 3.3 C++ moderno e o dialeto da Unreal
C++17/20 em geral (RAII, ponteiros inteligentes, move semantics, templates leves, headers e unidades de compilação) **e** o dialeto da Unreal, que é praticamente uma linguagem própria: `UObject`, sistema de reflexão (`UCLASS`, `UPROPERTY`, `UFUNCTION`), garbage collector próprio, contêineres próprios (`TArray`, `TMap`, `FString`, `FName`), macros, módulos, Unreal Header Tool e Unreal Build Tool. **(Caps. 11 e 13, reforçados em todos os capítulos de implementação)**

### 3.4 A engine e o editor
Uma engine não é um framework no sentido de Spring. É um **ambiente de autoria de conteúdo** com um runtime acoplado. Você vai trabalhar tanto no editor (níveis, assets, Blueprints) quanto no código. Entender o que é um *asset*, como funciona o *cooking*, o que é um *level*, como o editor executa o jogo (*Play In Editor*) é tão importante quanto saber C++. **(Parte II)**

### 3.5 Gameplay programming
O núcleo da sua formação técnica: personagem, câmera, input, interação, armas, dano, estado de gameplay, comunicação entre sistemas. É aqui que o "lado engenharia" encontra o "lado design". **(Partes III e IV)**

### 3.6 Vocabulário e raciocínio de game design
*Core loop*, mecânicas, dinâmicas, estética, feedback, *game feel*, dificuldade, progressão, *pacing*, *encounter design*, agência do jogador. Sem esse vocabulário, você implementa sistemas tecnicamente corretos que não são divertidos. **(Caps. 5, 21, 25, 43, 50, ao longo do livro)**

### 3.7 Game AI
Você conhece algoritmos de busca (A*) e talvez algo de agentes e planejamento do mestrado. Game AI é outra disciplina: o objetivo não é agir de forma ótima, e sim **parecer inteligente e ser divertido de enfrentar**. FSM, Behavior Trees, Utility AI, EQS, percepção, navegação, IA tática e de esquadrão. **(Parte V)**

### 3.8 Sistemas narrativos
Diálogos, quests, estado narrativo, ramificação, narrativa ambiental, cinematics. Do ponto de vista de engenharia, isso é modelagem de dados + máquinas de estado + autoria de conteúdo por não-programadores. **(Parte VI)**

### 3.9 Pipeline audiovisual
Iluminação, áudio, animação, efeitos visuais e UI. Você não vai virar artista, mas precisa saber como esses sistemas funcionam e como o código conversa com eles — especialmente porque seus jogos de referência (Alan Wake, Amnesia, Outlast) dependem mais de luz e som do que de qualquer outro sistema. **(Parte VII)**

### 3.10 Performance de frame
Você conhece performance de throughput e latência de requisição. Jogos têm outro tipo de restrição: **cada frame tem um orçamento fixo**, e o pior frame importa mais que a média. CPU-bound vs. GPU-bound, draw calls, LOD, streaming, custo de tick. **(Caps. 58–60)**

### 3.11 Networking de jogos
Sua experiência com sistemas distribuídos é uma base excelente — mas networking de jogos resolve um problema diferente: **criar a ilusão de um mundo compartilhado e instantâneo sobre uma rede lenta e não confiável**, com dezenas de atualizações por segundo e jogadores que tentam trapacear. Autoridade, replicação, predição, reconciliação, interpolação, lag compensation. **(Parte IX)**

### 3.12 Produção de jogos
Escopo, prototipação, *vertical slice*, *grey-box*, playtest, polimento, *feature creep*. A habilidade mais rara entre iniciantes não é técnica: é **terminar** um jogo pequeno. **(Interlúdio I, Parte XI)**

---

## 4. Mapa de competências

### 4.1 Visão estrutural

```text
                         DESENVOLVEDOR DE JOGOS NARRATIVOS EM PRIMEIRA PESSOA
                                              │
        ┌──────────────────┬──────────────────┼──────────────────┬──────────────────┐
        ▼                  ▼                  ▼                  ▼                  ▼
   FUNDAMENTOS          ENGINE            GAMEPLAY            SISTEMAS          PRODUÇÃO
   de tempo real      (Unreal 5)        programming          complexos         e design
        │                  │                  │                  │                  │
  Game loop          Editor/assets      Player/Camera       Game AI           Game design
  Delta time         Actors/Comps       Input               Narrativa         Level design
  Estado/eventos     Gameplay Fwk       Interação           Save/Persist.     Pacing
  Arquitetura        C++ (UObject)      Armas/Combate       Networking        Playtest
  Matemática 3D      Blueprint          Dano/Estado         Performance       Escopo
                     Física/Colisão     Comunicação         IA generativa     Vertical slice
                                                                 │
                                         ┌───────────────────────┴───────────┐
                                         ▼                                   ▼
                                  World building                      Projeto final
                                  Luz/Áudio/Anim/VFX/UI                  "Vigília"
```

### 4.2 Escala de proficiência

Usaremos uma escala simples, de 0 a 5:

- **0** — nunca vi.
- **1** — conheço o termo e a ideia geral.
- **2** — consigo seguir um tutorial e entender o que está acontecendo.
- **3** — consigo implementar sozinho uma versão funcional em um projeto pequeno.
- **4** — consigo projetar, justificar trade-offs e refatorar quando o sistema cresce.
- **5** — consigo ensinar, depurar casos difíceis e otimizar em produção.

### 4.3 Ponto de partida estimado e meta

| Área | Hoje (estimado) | Meta ao fim do livro | Onde se desenvolve |
|---|:-:|:-:|---|
| Modelo mental de tempo real (loop, tick, dt, frame) | 1 | 4 | Parte I |
| Matemática 3D aplicada | 2 | 4 | Caps. 17, 18, 27, 29, 36, 39 |
| C++ moderno | 1–2 | 3 | Caps. 11, 13 e implementação contínua |
| Dialeto Unreal (UObject, reflexão, GC, módulos) | 0 | 4 | Caps. 8–13 |
| Editor, assets e conteúdo | 0 | 3 | Parte II, Parte VII |
| Gameplay programming | 0 | 4 | Partes III e IV |
| Game design (loops, feel, pacing) | 1 | 3 | Caps. 5, 21, 25, 43, 50 |
| Level design | 0 | 3 | Cap. 50 + projetos |
| Game AI | 1 | 4 | Parte V |
| Sistemas narrativos | 0 | 4 | Parte VI |
| Luz, áudio, animação, VFX, UI | 0 | 2–3 | Parte VII |
| Save/persistência de mundo | 1 | 4 | Caps. 56–57 |
| Performance e profiling de frame | 1 | 3 | Caps. 58–60 |
| Networking de jogos | 2 (sist. distribuídos) | 3–4 | Parte IX + Interlúdio III |
| IA generativa aplicada a jogos | 3 | 4 | Parte X |
| Produção (escopo, slice, playtest, release) | 1 | 3 | Interlúdio I, Parte XI |

A meta **não** é nível 5 em tudo. A meta é ser um *generalista técnico de gameplay* (nível 3–4 nas áreas centrais) capaz de construir, sozinho, uma experiência narrativa curta de boa qualidade — e capaz de olhar para qualquer jogo e decompor seus sistemas.

---

## 5. A filosofia de decomposição: da experiência ao sistema

Toda vez que um jogo comercial aparecer neste livro, ele será analisado com o mesmo instrumento — a **Ficha de Decomposição**, com seis perguntas:

```text
1. EXPERIÊNCIA   Qual experiência o jogo está tentando produzir no jogador?
2. SISTEMA       Qual sistema (ou combinação de sistemas) produz essa experiência?
3. DESIGN        Qual decisão de design está por trás do sistema?
4. TECNOLOGIA    Como a tecnologia permite implementar essa decisão?
5. VERSÃO MÍNIMA Como eu implementaria uma versão extremamente simplificada?
6. LIÇÃO         O que eu levo disso para os meus próprios projetos?
```

E, para conectar experiência e engenharia de ponta a ponta, o livro segue sempre esta cadeia:

```text
Experiência do jogador
        ↓
Problema de design
        ↓
Sistema de gameplay
        ↓
Arquitetura
        ↓
Implementação
        ↓
Performance / limitações
        ↓
Resultado percebido
```

### 5.1 Regra de honestidade sobre jogos comerciais

Implementações internas de jogos comerciais são, em geral, proprietárias. Este livro **não inventa** como a Remedy, a Rockstar, a DICE, a Infinity Ward, a Red Barrels, a Frictional Games, a The Chinese Room, a Konami ou a EA implementaram seus sistemas. Sempre que um jogo for discutido, o texto marca explicitamente a natureza da afirmação:

- **[FATO PÚBLICO]** — algo observável jogando o jogo, ou declarado publicamente pelos desenvolvedores (entrevistas, talks, postmortems).
- **[INFERÊNCIA]** — uma hipótese técnica plausível sobre como algo *poderia* funcionar, deduzida do comportamento observável. Não é afirmação sobre o código real.
- **[SIMPLIFICAÇÃO DIDÁTICA]** — uma versão deliberadamente reduzida, criada para ensinar o princípio.
- **[HIPOTÉTICO]** — um exemplo inventado para ilustrar um conceito.

---

## 6. O fio condutor: o projeto *Vigília*

Este livro não tem sete tutoriais independentes. Ele tem **um único projeto Unreal**, chamado **Vigília**, que nasce nos exercícios da Parte I (os Capítulos 2–6 já criam as primeiras classes em `Source/Vigilia`), ganha forma de projeto no Capítulo 7 e cresce até virar o projeto final.

### 6.1 O conceito (resumo — o documento completo está no Cap. 76)

> *Uma perita do órgão estadual de energia é enviada, à noite, para inspecionar a Usina de Serra Funda, uma hidrelétrica desativada no interior do país. A equipe do último turno desapareceu há trinta anos. Esta noite, sem explicação, as turbinas voltaram a girar.*

Um FPS narrativo de terror e investigação, de 10 a 20 minutos, em primeira pessoa. Os pilares (que serão justificados no Cap. 76):

- **Luz como recurso, linguagem e defesa** (influência conceitual de Alan Wake): uma lanterna com bateria limitada e uma rede elétrica que o jogador religa setor por setor; áreas iluminadas são zonas seguras.
- **Burocracia como narrativa ambiental** (influência conceitual de Control): livros de ocorrência, memorandos, plantas da usina, fitas de rádio.
- **A máquina como horror** (influência conceitual de A Machine for Pigs): a usina como organismo industrial, som de maquinário como linguagem do medo.
- **Vulnerabilidade e perseguição** (influência conceitual de Outlast): combate escasso, uma presença que caça o jogador, uma sequência de fuga.
- **Momentos cinematográficos** (influência conceitual de Quantum Break e Max Payne): transições entre gameplay e cinemática, rádio com uma operadora.
- **Um combate curto e intenso** (influência conceitual dos FPS): um sinalizador com poucos cartuchos e uma sobrecarga da lanterna.

A inspiração é **conceitual**. Nenhum sistema, personagem, história ou estética será copiado.

### 6.2 Como os projetos se encadeiam

```text
  Projeto 1  Playground ─────────── "Pátio da Usina" (grey-box explorável)
      │                              → vira o exterior da Vigília
      ▼
  Projeto 2  FPS básico ─────────── "Galpão de Testes" (movimento, arma, dano, inimigo-alvo)
      │                              → código de arma/vida reaproveitado até o fim
      ▼
  Projeto 3  Interação ──────────── portas, disjuntores, baterias, documentos
      │                              → os interativos reais da usina
      ▼
  Interlúdio I / Projeto 4 ──────── "Turno da Noite" — experiência narrativa de 5–15 min
      │                              DELIBERADAMENTE INGÊNUA (Level Blueprint, flags soltas)
      ▼
  Projeto 5  Game AI ────────────── dois arquétipos: "Vigia" (tático, armado)
      │                              e "Presença" (horror, percepção, perseguição)
      ▼
  Projeto 6  Sistema narrativo ──── REFATORAÇÃO do Projeto 4 para um sistema data-driven
      │                              (quests, diálogos, estado narrativo)
      ▼
  Partes VII–VIII ───────────────── luz, áudio, animação, VFX, UI, save/load, performance
      │
      ▼
  Projeto Arena (Parte IX) ──────── multiplayer 1v1 no Galpão: descobrir o que quebra
      │                              quando o mundo deixa de ser de um jogador só
      ▼
  Projeto 7  Vertical Slice ─────── os primeiros ~5 minutos da Vigília em qualidade final
      │
      ▼
  Projeto Final  Vigília ────────── 10–20 minutos + experimento multiplayer cooperativo
```

O Projeto 4 é propositalmente construído do jeito "errado-mas-rápido": lógica no Level Blueprint, referências diretas entre atores, booleans espalhados. Ele vai funcionar. E vai começar a doer quando você tentar adicionar um segundo caminho narrativo, salvar o jogo ou reaproveitar a lógica em outro nível. Essa dor é o objetivo: a Parte VI apresenta o sistema narrativo como **resposta a problemas que você terá sentido**, e não como arquitetura imposta.

### 6.3 Convenções do código e do projeto

Estas convenções valem para o livro inteiro.

- **Nome do projeto e do módulo C++:** `Vigilia` (sem acento, por segurança em ferramentas).
- **Prefixo das classes do projeto:** `VG`. Somado aos prefixos obrigatórios da Unreal: `AVGCharacter` (Actor), `UVGHealthComponent` (UObject/Component), `FVGDamageInfo` (struct), `EVGDoorState` (enum), `IVGInteractable` (interface).
- **Organização do código-fonte:**

```text
Source/Vigilia/
├── Core/          GameMode, GameInstance, tipos comuns, log categories
├── Player/        Character, PlayerController, câmera, input
├── Interaction/   interface e componente de interação, interativos
├── Combat/        armas, dano, vida, projéteis
├── AI/            controllers, tasks, services, percepção
├── Narrative/     quests, diálogos, estado narrativo
├── World/         rede elétrica, luzes, eventos do mundo
├── Save/          SaveGame, persistência
├── UI/            classes base de widgets
├── GenAI/         protótipo isolado de IA generativa em runtime (Parte X; fora do build de release)
├── Debug/         ferramentas de debug, cheats
└── Tests/         testes de automação (regras puras e conteúdo)
```

- **Organização do conteúdo:** `/Game/Vigilia/{Maps, Blueprints, Data, Characters, Weapons, Audio, VFX, UI, Narrative}`. Experimentos ficam em `/Game/Developers/` (pasta padrão da Unreal para isso) e nunca são referenciados por conteúdo de produção.
- **Nomes de assets:** prefixos de tipo, seguindo a convenção difundida pela comunidade (por exemplo, o *UE5 Style Guide* de Allar no GitHub): `BP_` Blueprint, `DA_` Data Asset, `M_`/`MI_` Material/Instância, `SM_` Static Mesh, `SK_` Skeletal Mesh, `ABP_` Animation Blueprint, `BT_`/`BB_` Behavior Tree/Blackboard, `EQS_` consulta EQS, `WBP_` Widget, `IA_`/`IMC_` Input Action/Mapping Context, `NS_` Niagara System, `MS_` MetaSound.
- **Regra de camadas (detalhada no Cap. 13):** C++ define *sistemas, regras e tipos*; Blueprint define *conteúdo, composição e ajuste fino*; Data Assets definem *números e configuração*.
- **Comentários `// Simplificação:`** marcam decisões deliberadamente simples, com o limite da solução e o capítulo em que ela será revista.

---

## 7. Roadmap completo — 11 partes, 85 capítulos e 3 interlúdios

Os interlúdios não alteram a numeração dos 85 capítulos; são blocos de projeto ou estudo de sistemas posicionados entre partes.

### PARTE I — Pensando como Game Developer
*Conceitos agnósticos de engine, com programas em C++ padrão e análise de jogos. Os exercícios dos Caps. 2–6 já tocam a Unreal (sondas de tick, componentes, um subsistema, testes): se você nunca abriu a engine, faça as partes Unreal desses exercícios depois do Cap. 11, que explica o setup e a reflexão.*

1. **O que diferencia software de jogos** — simulação interativa em tempo real; experiência como requisito; "mentir" como técnica legítima; a porta que toca dez sistemas; estudo de caso: a luz em Alan Wake.
2. **Game Loop** — do programa que espera ao programa que não para; anatomia de um frame; pipelining entre threads; o loop da Unreal e os *tick groups*.
3. **Frames, Delta Time e Update** — timestep variável vs. fixo, *accumulator*, interpolação de renderização, *substepping*, determinismo, *time dilation*.
4. **Estado e eventos** — o estado do mundo; *polling* vs. eventos; ordem de atualização; máquinas de estado como forma de pensar; eventos que atravessam frames.
5. **Gameplay Loop** — *core loop*, loops aninhados (segundo, minuto, sessão), MDA (mecânicas, dinâmicas, estética), feedback; gameplay emergente com PES/FIFA.
6. **Game Architecture** — aplicação tradicional vs. jogo; hierarquia de objetos, componentes, *actor model* da Unreal, ECS (Mass); subsistemas; "arquitetura elegante" vs. "arquitetura adequada para um jogo".

### PARTE II — Unreal Engine 5 · *Projeto 1: Playground ("Pátio da Usina")*

7. **Conhecendo a Engine** — editor, projeto, assets, módulos, *Play In Editor*, cooking; criação do projeto `Vigilia`; controle de versão (Git LFS vs. Perforce).
8. **Actors** — o que é um Actor; ciclo de vida (construção, *spawn*, `BeginPlay`, `Tick`, `EndPlay`, destruição); transforms; o `UWorld`.
9. **Components** — Actor Components vs. Scene Components; hierarquia de anexação; composição como ferramenta principal; quando criar um componente.
10. **Gameplay Framework** — GameInstance, GameMode, GameState, PlayerController, PlayerState, Pawn, Character, HUD: quem é dono de quê, e por que essa divisão só faz sentido inteiro quando chega o multiplayer.
11. **C++ na Unreal** — C++ moderno essencial; `UObject`, reflexão, `UCLASS`/`UPROPERTY`/`UFUNCTION`, garbage collector, `TObjectPtr`/`TWeakObjectPtr`, contêineres, módulos, build, Live Coding.
12. **Blueprint** — grafos, eventos, funções, macros; Blueprint como linguagem de conteúdo; custo, limites e "espaguete".
13. **C++ + Blueprint** — `BlueprintCallable`, `BlueprintImplementableEvent`, `BlueprintNativeEvent`; classes base em C++ e assets em Blueprint; a regra de camadas do projeto.
14. **Input** — Enhanced Input: Input Actions, Mapping Contexts, modifiers, triggers; contextos de input (exploração, combate, UI, cinemática).
15. **Collision e Physics** — canais e *presets*, *overlap* vs. *block*, traces, Chaos, corpos simulados, materiais físicos.

### PARTE III — Gameplay Programming · *Projeto 2 (início) e Projeto 3: Interação*

16. **Player Controller** — o controller como "vontade" e o pawn como "corpo"; possessão; roteamento de input.
17. **Character** — `CharacterMovementComponent`, modos de movimento, cápsula, sprint/agachar/pulo; vetores aplicados ao movimento.
18. **Camera** — câmera em primeira pessoa; *rotators* vs. *quaternions*; FOV, *head bob*, *camera shakes*; câmera como emoção (Outlast).
19. **Interaction** — o sistema de interação do Projeto 3: herança vs. interface vs. componente vs. eventos, comparados com código.
20. **Weapons** — anatomia de uma arma: dados, estado, disparo, munição; Data Assets.
21. **Combat** — combate como sistema de design: ritmo, *telegraphing*, leitura, risco e recompensa.
22. **Health/Damage** — o sistema de dano da Unreal; componente de vida; tipos de dano; morte e reação.
23. **Gameplay State** — onde o estado mora: Actor, Component, GameState, Subsystem; Gameplay Tags.
24. **Events e comunicação** — delegates, interfaces, subsistemas como barramento, mensagens de gameplay; graus de acoplamento.

### PARTE IV — Construindo um FPS · *Projeto 2 completo ("Galpão de Testes")*

25. **FPS Controller** — *game feel* do movimento: aceleração, fricção, *coyote time*, *jump buffering*, sprint; referências de COD, Apex e Battlefront.
26. **Weapon System** — arquitetura de armas: arma como Actor + componentes, modos de disparo, troca, dados.
27. **Hitscan** — traces, *spread*, origem câmera vs. cano, penetração.
28. **Projectile** — `ProjectileMovementComponent`, balística, tempo de voo; quando hitscan, quando projétil.
29. **Recoil** — recoil vs. spread vs. sway; padrões, recuperação; *feel* de armas.
30. **Enemy** — inimigo simples: alvo de dano, reação a acerto, morte, ragdoll; preparando o terreno para a IA.
31. **Objectives** — objetivos de modo de jogo e de missão: estado, condições, UI.
32. **Spawn System** — pontos de spawn, ondas, spawn seguro, *pooling*; estudo de caso: sensação de escala com poucos NPCs (Battlefield/COD).

### INTERLÚDIO I — *Projeto 4: "Turno da Noite"* (versão ingênua)
Uma experiência narrativa de 5–15 minutos na Casa de Força da usina, construída com o mínimo de arquitetura: exploração, objetivos, documentos, diálogos de rádio, portas trancadas, um puzzle de disjuntores, uma cinemática e um final. Termina com um **inventário de dores** que alimenta a Parte VI.

### PARTE V — Game AI · *Projeto 5: o Vigia e a Presença*

33. **Introdução à Game AI** — AI de jogo vs. AI acadêmica; ser divertido, não ótimo; *sense–think–act*; a ilusão de inteligência.
34. **FSM** — estados, transições, FSM hierárquica; implementação em C++; onde quebra.
35. **Navigation** — NavMesh, A*, Recast/Detour, *nav modifiers*, *nav links*, *avoidance*.
36. **Perception** — AI Perception: visão, audição, dano; estímulos, memória, esquecimento; percepção "justa" (Outlast, Amnesia).
37. **Behavior Trees** — composites, decorators, services, tasks; reatividade; patrulhar → investigar → perseguir → perder → voltar.
38. **Blackboard** — memória do agente; o que pertence ao blackboard e o que não pertence.
39. **EQS** — consultas espaciais: cobertura, flanco, linha de visão; geradores, testes, pontuação.
40. **Utility AI** — pontuação de ações, curvas de resposta, considerações; comparação com BT.
41. **Tactical AI** — cobertura, supressão, posições táticas, planejamento (GOAP) e o "Soldier AI".
42. **Squad AI** — papéis, coordenação, *attack tokens*, AI Director; inteligência coletiva com poucos agentes.

### PARTE VI — Narrative Games · *Projeto 6: refatoração narrativa do Projeto 4*

43. **Narrative Design** — estrutura, *pacing*, agência; narrativa embutida vs. emergente; estrutura episódica (Alan Wake).
44. **Dialogue Systems** — grafo de diálogo, nós, escolhas, condições; dados, legendas, áudio.
45. **Quest Systems** — quests, objetivos, condições, recompensas; modelagem data-driven sem um mar de `if/else`.
46. **Narrative State** — fatos do mundo, flags vs. fatos tipados, Gameplay Tags; o subsistema narrativo como fonte da verdade.
47. **Branching** — ramificação, convergência, consequências tardias; o custo de conteúdo de cada escolha.
48. **Environmental Storytelling** — narrativa pelo ambiente e por documentos (Control, A Machine for Pigs).
49. **Cinematics** — Sequencer, cinemáticas in-engine, transições gameplay↔cinemática, eventos roteirizados (Quantum Break, GTA V).

### PARTE VII — World Building

50. **Level Design** — *blockout*, guiar o jogador, *gating*, *pacing* espacial, espaços de horror.
51. **Lighting** — Lumen, luz como composição, luz como mecânica (Alan Wake), escuridão jogável.
52. **Audio** — MetaSounds, atenuação, espacialização, mixagem dinâmica; som como informação e como medo (A Machine for Pigs).
53. **Animation** — skeletal meshes, Animation Blueprint, *state machines*, *blend spaces*, *montages*, IK, ragdoll e animação física (GTA IV).
54. **VFX** — Niagara; feedback de impacto, *muzzle flash*, atmosfera.
55. **UI/UX** — UMG; HUD diegético vs. não-diegético; UI de documentos e diálogo.

### PARTE VIII — Engenharia

56. **Save Systems** — `USaveGame`, serialização, o que salvar, versionamento de save, checkpoints.
57. **Persistence** — estado de mundo persistente, IDs estáveis, atores destruídos/movidos, streaming e estado.
58. **Performance** — orçamento de frame, CPU-bound vs. GPU-bound, memória, game thread vs. render thread.
59. **Profiling** — `stat` commands, Unreal Insights, profiling de GPU; metodologia.
60. **Optimization** — LOD, culling, HLOD, World Partition, otimização de tick, *significance*, pooling.
61. **Debugging** — Visual Logger, Gameplay Debugger, *draw debug*, console variables, cheats, crashes.
62. **Packaging** — configurações de build, cooking, pak/IoStore, Shipping.

### INTERLÚDIO II — *Decompondo um mundo aberto: GTA San Andreas, IV e V*
Estudo de sistemas: streaming, população de NPCs, *spawning/despawning*, simulação em segundo plano, *wanted system*, missões, veículos, física sistêmica (GTA IV). "O mundo continua existindo quando eu não estou olhando." Arquitetura elegante vs. arquitetura adequada.

### PARTE IX — Multiplayer · *Projeto Arena*

63. **Client/Server** — multiplayer local vs. online; topologias; *listen* vs. *dedicated server*; o modelo da Unreal.
64. **Authority** — autoridade, *net roles*, validação, trapaça; de quem é cada pedaço de estado.
65. **Replication** — propriedades replicadas, RepNotify, *relevancy*, *dormancy*, *bandwidth*, *interest management*.
66. **RPC** — Server/Client/NetMulticast, reliable vs. unreliable, validação.
67. **Prediction** — *client-side prediction*, reconciliação; o `CharacterMovementComponent` como estudo.
68. **Latency** — ping, jitter, perda, *tick rate*, *snapshots*, interpolação, extrapolação, *lag compensation* e *hit registration*.

### INTERLÚDIO III — *Multiplayer avançado*
Servidor dedicado, partida, lobby e matchmaking; multiplayer + Game AI; multiplayer + física e destruição (Battlefield 4); multiplayer + mundo aberto (GTA Online, conceitualmente); escala.

### PARTE X — IA Generativa

69. **IA como ferramenta de programação** — workflows de estudo, revisão, depuração e refatoração com IA. *(Pode ser lido como apoio logo após a Parte I.)*
70. **IA para Game Design** — ideação, variações de mecânicas, análise de loops, *balancing* assistido.
71. **IA para Narrative Design** — diálogos, quests, bíblia de mundo, consistência.
72. **IA para Game AI** — IA generativa como ferramenta para construir Game AI (não como substituta).
73. **LLMs dentro de jogos** — arquitetura, latência, custo, segurança de conteúdo.
74. **NPCs com IA generativa** — NPC híbrido: Game AI tradicional decide, LLM verbaliza.
75. **Limitações e arquitetura híbrida** — onde LLMs falham em jogos e como contê-los.

### PARTE XI — Projeto Final: *Vigília*

76. **Conceito** — documento de design, pilares, escopo, milestones.
77. **Arquitetura** — arquitetura do jogo inteiro, revisão das decisões dos projetos anteriores.
78. **Vertical Slice** — *Projeto 7*: os primeiros minutos em qualidade final.
79. **Implementação** — da fatia ao jogo completo.
80. **AI** — a Presença e o encontro de combate.
81. **Narrative** — a história completa no sistema narrativo.
82. **Polish** — *game feel*, áudio, luz, ritmo.
83. **Performance** — orçamento de frame do jogo real.
84. **Build** — build de release + branch experimental multiplayer cooperativo.
85. **Postmortem** — o que deu certo, o que deu errado, próximos passos.

---

## 8. Trilhas transversais

Suas referências formam famílias de problemas. A tabela mostra em que capítulos cada família é aprofundada — útil para revisar um tema específico ou para saber onde um jogo vai reaparecer.

| Trilha | Referências | Capítulos principais |
|---|---|---|
| **FPS / Combate** | Battlefield, Call of Duty, Battlefront II, Apex | 17, 18, 20–22, 25–32, 41–42, 54 |
| **Narrativa / Cinematográfico** | Alan Wake 1 e 2, Control, Quantum Break, Max Payne | 1, 5, 43–49, 51, 55, 76–81 |
| **Horror / Atmosfera** | Outlast, Amnesia (Dark Descent, Machine for Pigs, Rebirth) | 18, 36–37, 48, 50–52, Interlúdio I, 80–82 |
| **Sistemas / Game AI** | Todos, especialmente FPS e GTA | 4, 6, 23–24, 33–42, Interlúdio II |
| **Futebol / Multiplayer local** | PES 2011, FIFA 14, eFootball, EA Sports FC | 5, 14, 25, 53, 63 |
| **Mundo aberto / Simulação** | GTA San Andreas, IV, V | 6, 15, 53, 57, 60, Interlúdio II |
| **Multiplayer online** | COD (era clássica, MW2019), Battlefield 4 e 6, GTA Online | 10, 63–68, Interlúdio III, 84 |

### Por que cada família exige uma arquitetura diferente

```text
Alan Wake           → narrativa + atmosfera + combate        → luz como sistema central
Control             → exploração + física + poderes + mundo  → física e mundo reativos
Outlast             → tensão + perseguição + vulnerabilidade → percepção da IA e câmera
A Machine for Pigs  → atmosfera + narrativa + exploração     → áudio e ambiente
Battlefield         → combate + escala + multiplayer         → rede, relevância, veículos
PES / FIFA          → simulação + feel + multiplayer + AI    → animação, física, IA de time
GTA                 → mundo aberto + emergência + simulação  → streaming e população
```

Um dos objetivos do livro é que essa tabela, que agora parece uma lista de fatos, se torne **óbvia** para você: dada uma experiência desejada, você saberá quais sistemas vão dominar o orçamento de engenharia.

---

## 9. Como estudar com este livro

### 9.1 O ciclo de cada capítulo

```text
  Ler (teoria) ──► Experimentar (pequeno, descartável) ──► Exercício
       ▲                                                       │
       │                                                       ▼
  Checklist ◄── Diário de engenharia ◄── Integrar ao projeto Vigília
```

1. **Ler** o capítulo inteiro uma vez, sem implementar.
2. **Experimentar** com um teste pequeno e descartável (mapa em `/Game/Developers/`, ou programa C++ isolado na Parte I).
3. **Fazer o exercício.** O desafio é opcional — faça quando o capítulo for central para seus interesses.
4. **Integrar** ao projeto Vigília o que o capítulo pede.
5. **Escrever no diário de engenharia** (um `DEVLOG.md` no repositório): o que fez, o que deu errado, que decisão tomou e por quê. Isso vira matéria-prima do postmortem do Cap. 85 — e é o mesmo hábito de um ADR (*Architecture Decision Record*), que você já conhece.
6. **Passar pelo checklist.** Se algum item não está claro, volte antes de seguir.

### 9.2 Regras de ouro

- **Feio e jogável vence bonito e quebrado.** Cubos cinza são assets perfeitamente válidos até a Parte VII.
- **Jogue o que você fez, sempre.** Todo commit deve deixar o jogo executável. Jogue por dois minutos após cada mudança significativa.
- **Timebox.** Se um exercício passar de 2× o tempo estimado, simplifique, anote no diário e siga.
- **Não construa uma engine.** A tentação de arquiteto é escrever um framework sobre a Unreal antes de fazer o jogo. Resista; o livro vai apontar quando uma abstração se pagou.
- **Commit pequeno e frequente.** Assets da Unreal são binários; conflitos de merge em `.uasset` não se resolvem como texto.

### 9.3 Como usar IA durante o estudo

Cada capítulo traz uma seção **Uso de IA** com prompts sugeridos. O princípio geral — desenvolvido no Cap. 69 — é usar a IA para **acelerar o entendimento, não para pular o entendimento**:

- Peça explicações e contraexemplos antes de pedir código.
- Escreva sua primeira versão e peça revisão — não o contrário.
- Peça para a IA citar a API exata e **confira na documentação oficial**. IAs frequentemente inventam funções da Unreal ou misturam versões da engine.
- Use a IA como *rubber duck* com memória: descreva o bug, o comportamento esperado e o observado.
- Nunca aceite código de gameplay que você não saberia explicar linha a linha.

### 9.4 Ambiente recomendado

- **Unreal Engine 5** na versão estável mais recente disponível no Epic Games Launcher. O livro privilegia APIs estáveis no ciclo UE5 e sinaliza quando algo mudou entre versões.
- **IDE:** Visual Studio 2022 (com a carga de trabalho "Game development with C++") ou JetBrains Rider. Verifique as condições de licença vigentes no momento da instalação.
- **Controle de versão:** Git com Git LFS (para `.uasset`/`.umap`) é suficiente para um projeto individual. O padrão da indústria em times é Perforce; o Cap. 7 discute os dois.
- **Hardware:** a Unreal 5 com Lumen exige uma GPU razoável. Se a máquina sofrer, o Cap. 7 mostra como reduzir a escalabilidade do editor.

---

## 10. Cronograma sugerido (7–10 horas por semana)

### 10.1 A semana-modelo (~8,5 h)

| Bloco | Duração | Conteúdo |
|---|---|---|
| Sessão 1 (dia útil) | 1h30 | Leitura do capítulo + anotações |
| Sessão 2 (dia útil) | 1h30 | Experimento pequeno + exercício |
| Sessão 3 (dia útil, opcional) | 1h00 | Uso de IA para revisar, explorar dúvidas, ler um recurso externo |
| Bloco de fim de semana | 3h–4h | Projeto (integração ao Vigília) + diário + playtest |
| Revisão | 30 min | Checklist e planejamento da próxima semana |

Proporção aproximada: **30% teoria, 25% exercícios, 45% projeto.** A partir da Parte III, a proporção de projeto sobe.

### 10.2 Fases

| Fase | Conteúdo | Semanas | Acumulado |
|---|---|:-:|:-:|
| 1 | Parte I (Caps. 1–6) | 5 | 5 |
| 2 | Parte II (Caps. 7–15) + Projeto 1 | 8 | 13 |
| 3 | Parte III (Caps. 16–24) + Projeto 3 | 9 | 22 |
| 4 | Parte IV (Caps. 25–32) + Projeto 2 completo | 8 | 30 |
| 5 | Interlúdio I — Projeto 4 | 4 | 34 |
| 6 | Parte V (Caps. 33–42) + Projeto 5 | 11 | 45 |
| 7 | Parte VI (Caps. 43–49) + Projeto 6 | 8 | 53 |
| 8 | Parte VII (Caps. 50–55) | 7 | 60 |
| 9 | Parte VIII (Caps. 56–62) + Interlúdio II | 8 | 68 |
| 10 | Parte IX (Caps. 63–68) + Arena + Interlúdio III | 10 | 78 |
| 11 | Parte X (Caps. 69–75) | 5 | 83 |
| 12 | Parte XI (Caps. 76–85) + Projeto 7 + Projeto Final | 14 | 97 |

Isso dá **cerca de 22 meses** no ritmo de 8,5 h/semana — um ritmo sustentável ao lado de um emprego em período integral. Inclua **uma semana de folga a cada 6–8 semanas**; ela não é atraso, é parte do plano.

### 10.3 Trilha essencial (~12–14 meses)

Se quiser chegar mais rápido ao projeto final, uma trilha essencial cobre: Parte I inteira; Caps. 7–11, 13–15; 16–19, 22–24; 25–27, 29–30; Interlúdio I; 33–38; 43–46, 48–49; 50–52, 55; 56, 58–59, 61–62; 76–85. O restante pode ser estudado depois, conforme interesse (multiplayer, IA tática, mundo aberto).

---

## 11. Política de recursos externos

Recursos externos são recomendados ao final dos capítulos com a seguinte prioridade: documentação oficial da Unreal (dev.epicgames.com/documentation), documentação de C++ (cppreference.com), documentação de ferramentas, livros reconhecidos, cursos de alta qualidade, artigos técnicos, talks de desenvolvedores (GDC Vault), postmortems.

Alguns pilares bibliográficos atravessam o livro inteiro e valem desde já:

- **Robert Nystrom, *Game Programming Patterns*** — padrões de programação vistos pela ótica de jogos; disponível gratuitamente para leitura em gameprogrammingpatterns.com.
- **Jason Gregory, *Game Engine Architecture*** — a referência mais completa sobre como engines são construídas (o autor trabalhou na Naughty Dog).
- **Jesse Schell, *The Art of Game Design: A Book of Lenses*** — fundamentos de game design, organizado em "lentes" de análise.

Recursos mais específicos ou atuais (cursos, talks, artigos) serão pesquisados e verificados no momento de cada capítulo, em vez de listados de memória.

---

## 12. Como ler os marcadores do livro

| Marcador | Significado |
|---|---|
| **[FATO PÚBLICO]** | Observável no jogo ou declarado publicamente pelos desenvolvedores. |
| **[INFERÊNCIA]** | Hipótese técnica plausível; não é afirmação sobre o código real. |
| **[SIMPLIFICAÇÃO DIDÁTICA]** | Versão reduzida criada para ensinar o princípio. |
| **[HIPOTÉTICO]** | Exemplo inventado. |
| `// Simplificação:` | No código: solução deliberadamente simples, com seu limite e o capítulo onde será revista. |
| 🔁 **Refatoração** | Uma decisão anterior está sendo substituída — com o porquê. |
| 🌉 **Ponte** | Analogia com engenharia de software tradicional. |
| 🧱 **Onde a ponte cai** | O ponto em que a analogia deixa de funcionar. |

Com o ponto de partida mapeado e o caminho traçado, o livro começa.

➡️ **Próximo:** [Capítulo 1 — O que diferencia software de jogos](parte-01/cap-01-software-vs-jogos.md)

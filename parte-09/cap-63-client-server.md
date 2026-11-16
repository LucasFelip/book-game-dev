# PARTE IX — Multiplayer

*Projeto Arena: dois jogadores numa arena pequena — qual estado pertence ao cliente e qual pertence ao servidor*

---

# Capítulo 63 — Client/Server

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar, com o exemplo do PES jogado com os primos, por que o multiplayer **local** e o multiplayer **online** são problemas de natureza diferente, e não de tamanho diferente;
- comparar as topologias de rede usadas em jogos (*peer-to-peer* com *lockstep*, cliente/servidor autoritativo, *listen server*, servidor dedicado) e dizer para que tipo de jogo cada uma serve;
- descrever o modelo da Unreal: um servidor autoritativo, um mundo por processo, atores replicados, *net modes* e *net roles*;
- rodar dois jogadores no editor (PIE), com emulação de latência, e saber o que a configuração "um processo só" esconde;
- montar o esqueleto do **Projeto Arena** (`L_Arena`, `AVGArenaGameMode`, `AVGArenaGameState`, `AVGArenaPlayerState`) e produzir o **inventário de quebras**: o que o código single-player da Vigília faz de errado quando o mundo passa a ser compartilhado.

---

## Contexto

Todo o código escrito até aqui carrega uma suposição que nunca foi dita em voz alta: **existe uma máquina, e nela existe uma verdade**. Quando a arma do Capítulo 27 chama `ApplyPointDamage`, a vida do alvo muda, e todos os sistemas que perguntam por ela recebem o mesmo número. Quando o `UVGGameplayEventSubsystem` do Capítulo 24 publica `Event.Actor.Died`, todos os ouvintes do mundo escutam. Quando o `AVGCharacter` troca `MaxWalkSpeed` para correr, o corpo corre.

O Capítulo 10 já tinha avisado que o Gameplay Framework "só faz sentido inteiro quando chega o multiplayer", e deixou uma tabela de onde cada classe existe. O Capítulo 17 marcou a corrida com `// Simplificação:` porque, em rede, ela geraria correções. O Capítulo 25 fez o mesmo com o *coyote time* e a aterrissagem dura, e o Capítulo 27 escolheu uma semente por disparo pensando na predição. Essas promessas vencem agora.

A Parte IX não constrói um jogo multiplayer. Ela constrói um **laboratório**: o Projeto Arena, dois jogadores numa sala pequena, cada um com movimento, câmera, arma, tiro, vida, respawn e placar. O objetivo é responder, peça por peça, à pergunta da spec:

> **Qual estado pertence ao cliente e qual pertence ao servidor?**

A parte segue uma sequência de verbos, um por capítulo:

```text
63 Client/Server   separar      um mundo vira vários mundos (um por máquina)
64 Authority       decidir      quem pode mudar cada pedaço de estado
65 Replication     propagar     como o estado decidido chega aos outros
66 RPC             pedir        como o cliente pede ao servidor (e o servidor avisa o cliente)
67 Prediction      antecipar    como o cliente não espera a resposta para agir
68 Latency         compensar    como o servidor julga o que o cliente viu no passado
Interlúdio III     escalar      servidor dedicado, partida, lobby, matchmaking, IA, física, mundo aberto
```

É a trilha da spec 3.15 (*single player → conceitos locais → dois jogadores → cliente/servidor → replicação → RPC → autoridade → latência → predição → interpolação → servidor dedicado → partida → lobby → matchmaking*), com uma troca deliberada: **autoridade vem antes de replicação**. Antes de discutir *como* um número viaja pela rede, é preciso saber *quem* tem o direito de escrevê-lo. O Capítulo 64 explica a escolha.

---

## 63.1 Do sofá à rede: o PES com os primos

Pense numa tarde de PES 2011 no PlayStation 2. Dois controles, um console, uma televisão.

```text
 MULTIPLAYER LOCAL

 Controle A ─┐
             ├── Console (uma simulação, uma memória, um relógio) ── TV
 Controle B ─┘
```

O console lê os dois controles **no mesmo quadro**, aplica as mesmas regras ao mesmo estado e desenha o resultado numa tela que os dois veem ao mesmo tempo. Quando o seu primo chuta, a bola sai no quadro seguinte, para os dois. Não existe a pergunta "quem viu o chute primeiro?", porque só existe um jogo rodando. Não existe trapaça de memória, porque o primo não tem acesso à memória do console (só ao seu ombro, para empurrar). A única latência é a do controle e a da TV, e ela é a mesma para os dois.

Agora troque o sofá pela internet:

```text
 MULTIPLAYER ONLINE

 Client A ──► Rede ──► Servidor ──► Rede ──► Client B
  (cópia)     30–80 ms  (verdade)   30–80 ms   (cópia)
```

Uma mudança que parece pequena (*os jogadores não estão no mesmo computador*) cria uma família inteira de problemas novos. Cada um ganha um capítulo, e vale nomeá-los agora:

| Problema | O que é | No sofá | Onde se resolve |
|---|---|---|---|
| **Latência** | A informação leva dezenas de milissegundos para ir e voltar | Inexistente | 68 |
| **Autoridade** | Alguém precisa ter a palavra final sobre cada pedaço de estado | O console é o único | 64 |
| **Sincronização** | Cada máquina tem sua cópia do mundo, e as cópias se afastam | Uma cópia só | 65 |
| **Segurança** | O cliente roda na máquina do jogador, que pode adulterá-lo | O primo não abre o console | 64, 66 |
| **Replicação** | Escolher o que enviar, a quem e com que frequência, numa banda limitada | Nada a enviar | 65 |
| **Previsão** | Agir sem esperar o servidor, para o controle não parecer "mole" | Não precisa | 67 |
| **Reconciliação** | Corrigir o cliente quando a previsão erra, sem que isso pareça um tranco | Não erra | 67 |
| **Escalabilidade** | 2 jogadores não são 64; o custo cresce mais rápido que o número de jogadores | Limite físico: 4 controles | 65, Interlúdio III |

O multiplayer local também tem seus problemas: duas câmeras ou uma câmera compartilhada, HUD por jogador, input roteado para o controle certo, regras de partida, vitória e reinício. A Unreal resolve quase todos com o mesmo Gameplay Framework (Capítulo 10): cada jogador local tem um `ULocalPlayer` e um `PlayerController`, no mesmo processo, sob o mesmo GameMode. **O que o multiplayer local nunca tem é desacordo.** Online, o desacordo é o estado normal, e o trabalho de engenharia é escondê-lo.

> 🌉 **Ponte:** é a passagem de um **monólito** com um banco de dados para um **sistema distribuído**. Você conhece os sintomas: cada nó com sua visão, mensagens que atrasam e se perdem, um nó que precisa ser a fonte da verdade, clientes que não merecem confiança.
>
> 🧱 **Onde a ponte cai:** num sistema distribuído de negócio, "consistência eventual" significa segundos, e o usuário aceita um *spinner*. Num FPS, o orçamento de inconsistência é de dezenas de milissegundos, e não existe *spinner*: o jogo continua desenhando 60 quadros por segundo enquanto a resposta não chega. Também não existe "tentar de novo mais tarde". Um tiro que chega atrasado não é um tiro a ser reprocessado, é um tiro que precisa ser julgado **no passado** (Capítulo 68).

---

## 63.2 Topologias

Há poucas formas fundamentais de ligar jogadores, e cada uma nasceu de um tipo de jogo.

### Peer-to-peer com lockstep

Cada máquina roda a simulação inteira. A cada passo, os jogadores trocam **apenas os inputs**, e ninguém avança antes de receber os inputs de todos para aquele passo. Se a simulação for **determinística** (mesmos inputs, mesmo resultado, bit a bit), todas as cópias permanecem idênticas sem que nenhum estado viaje pela rede.

- **Por que existe:** jogos de estratégia em tempo real, com centenas ou milhares de unidades. Enviar a posição de cada unidade é impossível; enviar "o jogador mandou estas 12 unidades para lá" custa bytes.
- **O custo:** o jogo inteiro anda no ritmo do jogador mais lento, e o determinismo precisa ser absoluto. Uma diferença de arredondamento de ponto flutuante entre dois processadores basta para as simulações divergirem para sempre (*desync*).
- **Variante com rollback:** jogos de luta não podem esperar o input do outro, então **preveem** que ele vai repetir o último input, simulam, e, quando o input real chega diferente, **voltam** alguns quadros e ressimulam. **[FATO PÚBLICO]** É a técnica popularizada pela biblioteca GGPO e descrita em palestras da GDC por estúdios de jogos de luta. O Capítulo 67 usa a mesma ideia, no movimento do personagem.

### Cliente/servidor autoritativo

Uma máquina, o **servidor**, roda a simulação de verdade. Os clientes enviam **intenções** (input, pedidos) e recebem **estado**. Cada cliente desenha uma cópia do mundo que é, por definição, um pouco atrasada e um pouco errada.

- **Por que existe:** FPS e jogos de ação, em que cada jogador controla um corpo e a trapaça precisa ser contida. A verdade fica numa máquina que o jogador não controla.
- **O custo:** a latência entre a intenção e o resultado (escondida pela predição) e o custo de operar servidores.

### Listen server e servidor dedicado

O cliente/servidor tem duas formas de hospedagem:

| | Listen server | Servidor dedicado |
|---|---|---|
| **O que é** | Um dos jogadores é também o servidor | Um processo sem jogador local, sem renderização |
| **Quem paga** | O jogador anfitrião (CPU, banda de upload) | O estúdio ou quem aluga o servidor |
| **Justiça** | O anfitrião tem latência zero: *host advantage* | Todos têm latência à mesma máquina neutra |
| **Se o anfitrião sair** | A partida acaba, ou precisa de migração de anfitrião | Nada acontece |
| **Trapaça** | O anfitrião tem a verdade na própria máquina | A verdade está fora do alcance dos jogadores |
| **Custo de desenvolvimento** | Baixo; bom para cooperativo entre amigos | Build separado, infraestrutura (Interlúdio III) |

### Híbridos

Jogos reais misturam. Um jogo pode usar servidor autoritativo para o combate e confiar no cliente para cosméticos, ou usar *peer-to-peer* para voz e cliente/servidor para o jogo. Partes do mundo podem ter "donos" diferentes, como no mundo aberto do Interlúdio III. A tabela acima descreve formas puras para que você reconheça as misturas.

---

## 63.3 O modelo da Unreal

A Unreal tem uma resposta embutida para a topologia: **cliente/servidor autoritativo, com replicação de atores**. **[FATO PÚBLICO]** O documento clássico de Tim Sweeney sobre a arquitetura de rede da Unreal (de 1999, ainda citado pela documentação e pela comunidade) descreve o modelo como um "cliente/servidor generalizado": o servidor mantém o estado autoritativo do jogo, e cada cliente mantém uma aproximação local desse estado, atualizada pelo servidor e usada para prever e desenhar.

### Um mundo por processo

O modelo mental mais importante deste capítulo:

```text
  PROCESSO DO SERVIDOR            PROCESSO DO CLIENTE A           PROCESSO DO CLIENTE B
  UWorld (autoritativo)           UWorld (cópia)                  UWorld (cópia)
  ├── GameMode                    │                               │
  ├── GameState ──────────────────├── GameState (réplica)         ├── GameState (réplica)
  ├── PC_A, PC_B ─────────────────├── PC_A (só o seu)             ├── PC_B (só o seu)
  ├── PlayerState_A, _B ──────────├── PlayerState_A, _B           ├── PlayerState_A, _B
  ├── Pawn_A, Pawn_B ─────────────├── Pawn_A, Pawn_B              ├── Pawn_A, Pawn_B
  ├── Subsistemas (do servidor)   ├── Subsistemas (do cliente A)  ├── Subsistemas (do cliente B)
  └── Atores não replicados       └── Atores não replicados       └── Atores não replicados
```

Cada processo tem o **seu** `UWorld`, os **seus** atores, os **seus** subsistemas, os **seus** timers. Um ator replicado no servidor tem **uma cópia** em cada cliente para o qual é relevante. As cópias são objetos C++ diferentes, em memórias diferentes, ligados apenas pelo que a rede transporta. Um ator **não replicado** (o padrão para `AActor`) existe só na máquina que o criou, ou em todas, se foi colocado no nível, mas sem nenhuma ligação entre as cópias.

Consequências que vão aparecer no Projeto Arena:

- **Subsistemas não são compartilhados.** O `UVGGameplayEventSubsystem` do servidor e o do cliente são objetos independentes. Um evento publicado no servidor nunca chega a um ouvinte do cliente.
- **`BeginPlay` roda em cada máquina.** Um componente que cria uma arma no `BeginPlay` cria uma arma por máquina.
- **Timers são locais.** Um timer de recarga no cliente não tem relação com o do servidor.
- **O GameMode só existe no servidor.** `GetWorld()->GetAuthGameMode()` retorna nulo no cliente, como o Capítulo 22 avisou.

### Net mode

Cada mundo sabe o que é, pelo `ENetMode`:

| `GetNetMode()` | Significado |
|---|---|
| `NM_Standalone` | Single-player: servidor e cliente ao mesmo tempo, sem rede |
| `NM_DedicatedServer` | Servidor sem jogador local e sem renderização |
| `NM_ListenServer` | Servidor com um jogador local (o anfitrião) |
| `NM_Client` | Cliente conectado a um servidor |

Repare que **single-player é um servidor**. Tudo o que o livro escreveu até aqui rodava com autoridade total sobre o mundo, e é por isso que funcionava sem pensar em rede.

### Net role

Cada ator, em cada máquina, tem um **papel local** (`GetLocalRole()`) e um **papel remoto** (`GetRemoteRole()`):

| Papel | Significado | Exemplo na Arena |
|---|---|---|
| `ROLE_Authority` | Esta máquina tem a cópia autoritativa | Todo ator replicado, no servidor |
| `ROLE_AutonomousProxy` | Cópia num cliente, que esse cliente controla | O seu próprio pawn, no seu cliente |
| `ROLE_SimulatedProxy` | Cópia num cliente, que só reproduz o que o servidor manda | O pawn do outro jogador, no seu cliente |
| `ROLE_None` | Não replicado | Um ator de efeito local |

O mesmo pawn tem três papéis ao mesmo tempo, um em cada máquina. O pawn do jogador A é `Authority` no servidor, `AutonomousProxy` no cliente A e `SimulatedProxy` no cliente B. O Capítulo 64 transforma essa tabela num critério de código (`HasAuthority`, `IsLocallyControlled`).

### O que transporta o quê

Por baixo, um `UNetDriver` mantém uma `UNetConnection` por cliente, e cada ator replicado relevante para uma conexão ganha um **canal de ator** nela. Pelo canal passam duas coisas, e o livro vai tratá-las separadamente:

- **Propriedades replicadas** (Capítulo 65): o servidor compara o estado atual com o último enviado àquela conexão e envia as diferenças. É **estado**. Um valor intermediário pode ser pulado, e só o mais recente importa.
- **RPCs** (Capítulo 66): chamadas de função que executam em outra máquina. É **evento**. Uma chamada confiável chega, em ordem; uma não confiável pode se perder.

### O Gameplay Framework, revisitado

A tabela do Capítulo 10 agora é operacional:

| Classe | Servidor | Cliente dono | Outros clientes | Na Arena |
|---|---|---|---|---|
| `AGameMode` | ✓ | — | — | `AVGArenaGameMode`: regras, respawn, fim de partida |
| `AGameState` | ✓ | ✓ réplica | ✓ réplica | `AVGArenaGameState`: tempo, limite, vencedor |
| `APlayerController` | ✓ (todos) | ✓ (só o seu) | — | `AVGPlayerController`: input, modos, avisos ao dono |
| `APlayerState` | ✓ | ✓ réplica | ✓ réplica | `AVGArenaPlayerState`: abates, mortes |
| `APawn`/`ACharacter` | ✓ | ✓ autônomo | ✓ simulado | `AVGCharacter` (via `BP_ArenaJogador`) |
| HUD, câmera, widgets | — | ✓ | — | Locais: nunca replicados |

O `PlayerController` merece atenção: ele existe **no servidor e no cliente dono**, e em nenhum outro. É por isso que ele é o canal natural de comunicação privada entre o servidor e um jogador (Capítulo 66), e é por isso que o cliente B não pode perguntar nada ao controller do jogador A: na máquina dele, esse objeto não existe.

---

## 63.4 O que muda quando o mundo é compartilhado

A spec (3.24) desenha a mudança de forma direta:

```text
 SINGLE-PLAYER                          MULTIPLAYER

 Player                                 Player A ─────┐
   ↓                                                  ├── Server
 Enemy AI                               Player B ─────┘     │
   ↓                                                        ├── Combat
 Combat                                                     ├── Objective
   ↓                                                        └── Match State
 Objective
```

No single-player, o jogador está no topo de uma cadeia de chamadas: o input vira movimento, o movimento vira combate, o combate vira objetivo. No multiplayer, **os jogadores deixam de estar dentro da simulação**. Eles estão do lado de fora, mandando intenções para ela, e a simulação mora numa máquina que nenhum deles controla.

Uma primeira classificação do estado da Vigília, que o Capítulo 64 refina, separa três camadas:

| Camada | O que é | Exemplos do projeto | Onde mora |
|---|---|---|---|
| **Simulação autoritativa** | O que decide o resultado do jogo | Vida, morte, munição, posição oficial, placar | Servidor |
| **Intenção do jogador** | O que o jogador quer fazer | Input de movimento, gatilho, mira, "quero interagir" | Cliente dono, enviado ao servidor |
| **Apresentação** | Como cada máquina mostra o resultado | Câmera, FOV, head bob, HUD, som dos passos, partículas, coice visual | Cada máquina, localmente |

A apresentação é a boa notícia da Parte IX. Tudo o que as Partes III e IV fizeram com cuidado para ser **local e derivado** (o modificador de câmera do Capítulo 18 lendo tags, o `UVGFootstepComponent` lendo distância percorrida, o coice do Capítulo 29) continua funcionando sem mudança, porque não decide nada. Separar "o que decide" de "o que mostra" foi uma decisão de arquitetura single-player que agora paga dividendos.

---

## 63.5 Dois jogadores no editor

A Unreal permite testar multiplayer sem empacotar nada. Em **Play → Advanced Settings** (as opções de multiplayer das preferências de *Play* do editor):

- **Number of Players:** 2.
- **Net Mode:**
  - *Play Offline*: cada janela é um jogo single-player independente;
  - *Play As Listen Server*: a primeira janela é servidor e jogador; as demais, clientes;
  - *Play As Client*: o editor sobe um **servidor dedicado** em segundo plano, e todas as janelas são clientes.
- **Run Under One Process:** ligado por padrão. Todas as instâncias rodam no processo do editor.
- **Network Emulation:** ativa latência e perda de pacotes artificiais, com perfis prontos ou valores personalizados (latência mínima e máxima, perda em %). ⚠️ O nome exato e a localização dessas opções mudam entre versões. Procure por "Network Emulation" nas configurações de *Play*.

Duas armadilhas da configuração de um processo só:

1. **Estado global compartilhado.** Variáveis `static`, singletons e **CVars** existem uma vez por processo, não por instância de PIE. `vg.Debug.Net 1` digitado na janela do cliente liga o debug também no servidor. Um `static` que guarda "o jogador" (algo que o livro evitou) apontaria para o pawn de uma instância qualquer.
2. **Latência zero por padrão.** Sem emulação, a rede do PIE é um laço local. Tudo parece funcionar, e o primeiro teste com 100 ms revela metade dos bugs. A regra da Parte IX: **todo teste de rede roda pelo menos uma vez com 100 ms de latência e 2% de perda**.

Para saber em que mundo um log foi escrito, use o modo de rede no texto da mensagem (o helper `VGNetDebug` abaixo). O `Print String` dos Blueprints já prefixa "Server:" e "Client 1:".

---

## Estudos de caso

### PES 2011 e FIFA 14 — o multiplayer sem rede

**[FATO PÚBLICO, observável jogando]** No PES 2011 e no FIFA 14 de PlayStation 2, o modo versus local coloca os dois jogadores na mesma tela, com uma câmera de transmissão que enquadra a jogada. Cada um controla o jogador do seu time mais próximo da bola, indicado por um marcador colorido. Não há tela dividida.

**[INFERÊNCIA]** A câmera compartilhada é uma solução de **apresentação** para um problema de **multiplayer local**: os dois jogadores precisam ver a mesma jogada, então a câmera segue a bola, não um jogador. O HUD também é compartilhado (placar, tempo), e o que é individual vira marcador no mundo (o cursor sobre o atleta). Nada disso tem custo de rede, porque só existe uma simulação.

**[FATO PÚBLICO]** O eFootball, sucessor do PES, roda em Unreal Engine desde 2021 e tem partidas online entre jogadores.

**[INFERÊNCIA]** Num jogo de futebol online, a bola é o objeto mais disputado do mundo: os dois jogadores a influenciam ao mesmo tempo, e a física dela decide o jogo. É um caso mais difícil que o de um FPS, em que cada jogador controla o próprio corpo e a interação entre corpos é por tiro. Os detalhes de como o eFootball resolve isso não são públicos; o Interlúdio III discute o problema genérico de física compartilhada.

**Lição para a Arena:** a primeira coisa que muda do sofá para a rede não é a câmera nem o HUD, que continuam locais. É a existência de **mais de uma simulação**.

### Call of Duty — do anfitrião ao servidor dedicado

**[FATO PÚBLICO]** Nas versões de console da "era de ouro" de Call of Duty, era comum a partida ser hospedada pelo console de um dos jogadores, e a comunidade discutia abertamente a "vantagem do anfitrião" (*host advantage*) e as migrações de anfitrião quando ele saía. Em Call of Duty: Modern Warfare (2019), a Activision anunciou servidores dedicados e *crossplay* entre plataformas.

**[INFERÊNCIA]** A "vantagem do anfitrião" é a tabela de *listen server* em ação: o anfitrião tem latência zero até a verdade, e todos os outros não. A migração de anfitrião existe porque, num *listen server*, a verdade mora na máquina de um jogador que pode desligar o console a qualquer momento.

**Lição para a Arena:** o *listen server* é ótimo para desenvolver e para jogar com amigos, e é injusto para competir. O Arena começa como *listen server* (é o que o PIE oferece com menos atrito) e testa o servidor dedicado com *Play As Client*.

### Battlefield — servidores como parte do jogo

**[FATO PÚBLICO]** A série Battlefield usa servidores dedicados há muitas gerações, e o Battlefield 4 permitia que jogadores alugassem servidores e configurassem as próprias regras de partida.

**[INFERÊNCIA]** Com 64 jogadores, veículos e destruição, não há console de jogador capaz de ser o servidor com qualidade aceitável, nem banda de upload doméstica para enviar o estado a 63 outros. Em escala, o servidor dedicado deixa de ser uma escolha e vira requisito. O Capítulo 65 faz a conta.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Servidor autoritativo | Backend como fonte da verdade; o front-end nunca decide | O "front-end" do jogo simula o mundo por conta própria entre uma resposta e outra (Capítulo 67) |
| Um mundo por processo | Réplicas de serviço, cada uma com sua memória | Não há banco compartilhado: só o que viaja pela rede liga as cópias |
| Cópia do cliente | Cache de leitura | O cache é desenhado 60 vezes por segundo e precisa parecer correto mesmo desatualizado |
| *Listen server* | Um nó que é cliente e servidor | O nó-servidor tem um usuário humano com vantagem injusta |
| Lockstep determinístico | Replicação por log de comandos (*state machine replication*) | Exige determinismo de ponto flutuante entre máquinas diferentes |
| Emulação de rede no PIE | *Chaos engineering*, injeção de latência | É obrigatória desde o primeiro teste, não um exercício de resiliência |

---

## Unreal Engine: o que existe

O que a engine oferece, e o livro usa:

- **Replicação de atores e propriedades**, com condições, notificações e controle de frequência e relevância (Capítulo 65).
- **RPCs** de servidor, de cliente e *multicast*, confiáveis e não confiáveis (Capítulo 66).
- **O `UCharacterMovementComponent` com predição e reconciliação prontas** para o movimento do personagem (Capítulo 67).
- **O Gameplay Framework** com a divisão servidor/cliente já embutida, e o `AGameMode` com uma máquina de estados de partida (Capítulo 10).
- **PIE multiplayer** e **emulação de rede** no editor.
- **Online Subsystem** e sessões, para encontrar e entrar em partidas (Interlúdio III).
- **Ferramentas de análise**: `stat net`, e a análise de rede do **Unreal Insights** (*Networking Insights*).

O que **não** existe pronto, e o livro implementa numa versão simples:

- **Compensação de latência para tiros hitscan** (Capítulo 68).
- **Predição de disparo** (Capítulo 67). O CMC prevê o movimento; a arma é sua.
- **Matchmaking.** A engine sabe criar e procurar sessões; quem junta os jogadores certos é um serviço (Interlúdio III).

⚠️ A Unreal tem um sistema de replicação mais novo, o **Iris**, e um plugin de predição genérica (*Network Prediction*). O estado deles muda entre versões (experimental, beta, padrão). **Verifique o estado na sua versão** antes de adotá-los. Este livro usa o sistema de replicação clássico, que é o que a documentação e os exemplos cobrem há mais tempo.

---

## Abordagens

| Critério | A. Local (tela dividida) | B. Peer-to-peer lockstep | **C. Listen server** | D. Servidor dedicado |
|---|---|---|---|---|
| **Complexidade** | Baixa: um processo | Altíssima: determinismo total | Média: o modelo padrão da engine | Média + build e infraestrutura |
| **Performance** | Renderização dobrada | Banda mínima; CPU replicada em todos | Anfitrião paga simulação + render | Servidor só simula |
| **Extensibilidade** | Limite de controles | Ruim para física e muitos atores dinâmicos | Boa até dezenas de jogadores | A mais escalável |
| **Manutenção** | Simples | *Desyncs* são os piores bugs que existem | Padrão da engine | Padrão + operação |
| **Prototipação** | Imediata | Lenta | **Imediata no PIE** | PIE com *Play As Client* |
| **Adequação à Arena** | Não ensina rede (é o desafio) | Contra a engine | **Sim, para desenvolver** | Sim, para validar (Interlúdio III) |

**Decisão: C para desenvolver, D para validar.** O Arena roda no PIE como *listen server*, porque é o modo mais rápido de iterar e porque expõe um caso que o dedicado esconde: o anfitrião é ao mesmo tempo `Authority` e jogador local, e muito código erra exatamente aí. Antes de considerar um capítulo concluído, rode também *Play As Client*: o servidor dedicado expõe o erro contrário, o de código que só funciona porque existe um jogador no servidor.

---

## Implementação

O código deste capítulo é pequeno de propósito: as classes da partida, uma regra pura e uma ferramenta para **ver** a rede. A maior parte do trabalho é rodar o jogo e olhar o que quebra.

### 1. Uma pasta para o experimento

As classes da Arena ficam em `Source/Vigilia/Arena/`, uma pasta nova no mesmo módulo `Vigilia`. O motivo é a natureza do projeto: a Arena é um **laboratório**. Ela reaproveita o código da Vigília (personagem, armas, vida) e o refatora para a rede, mas as classes de partida (regras de abate, placar, respawn automático) não pertencem ao jogo single-player. Uma pasta própria as mantém removíveis. As refatorações das classes existentes ficam onde as classes já estão (`Player/`, `Combat/`, `Interaction/`), porque são o código da Vigília ficando pronto para a rede, que o experimento cooperativo do Capítulo 84 vai reaproveitar.

### 2. As regras puras da Arena

A primeira regra com lógica não trivial é a escolha do ponto de respawn: o mais longe possível do adversário, para que ninguém renasça na mira de alguém.

```cpp
// Source/Vigilia/Arena/VGArenaRules.h
#pragma once

#include "CoreMinimal.h"

/** Regras puras da Arena: sem mundo, sem atores, testáveis. */
namespace VGArenaRules
{
    /**
     * Índice do ponto de nascimento cuja ameaça mais próxima está mais longe.
     * Sem ameaças, o primeiro ponto. Sem pontos, INDEX_NONE.
     */
    inline int32 PickFarthestSpawn(TConstArrayView<FVector> Spawns, TConstArrayView<FVector> Threats)
    {
        int32 Best = INDEX_NONE;
        double BestNearest = -1.0;
        for (int32 Index = 0; Index < Spawns.Num(); ++Index)
        {
            double Nearest = TNumericLimits<double>::Max();
            for (const FVector& Threat : Threats)
            {
                Nearest = FMath::Min(Nearest, FVector::DistSquared(Spawns[Index], Threat));
            }
            if (Nearest > BestNearest) // estrito: empate fica com o primeiro (reprodutível)
            {
                BestNearest = Nearest;
                Best = Index;
            }
        }
        return Best;
    }
}
```

### 3. As três classes da partida

O Capítulo 10 previu: "para a Arena multiplayer da Parte IX, `AGameMode`, com sua máquina de estados de partida, é a escolha natural". O `AGameMode` exige um `AGameState`. O `PlayerState` é próprio porque o placar vai morar nele.

```cpp
// Source/Vigilia/Arena/VGArenaGameMode.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameMode.h"
#include "VGArenaGameMode.generated.h"

/**
 * Regras da Arena. Existe SÓ no servidor (Cap. 10): nenhum cliente consulta o GameMode.
 * Este capítulo: esperar os jogadores e escolher onde nascem. Cap. 64: abates, respawn e fim.
 */
UCLASS()
class VIGILIA_API AVGArenaGameMode : public AGameMode
{
    GENERATED_BODY()

public:
    AVGArenaGameMode();

protected:
    /** A partida só começa com a sala cheia. */
    virtual bool ReadyToStartMatch_Implementation() override;

    /** Nasce no ponto mais longe dos adversários vivos. */
    virtual AActor* ChoosePlayerStart_Implementation(AController* Player) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Arena", meta = (ClampMin = "1"))
    int32 PlayersToStart = 2;
};
```

```cpp
// Source/Vigilia/Arena/VGArenaGameMode.cpp
#include "Arena/VGArenaGameMode.h"

#include "Arena/VGArenaGameState.h"
#include "Arena/VGArenaPlayerState.h"
#include "Arena/VGArenaRules.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerStart.h"
#include "Player/VGCharacter.h"
#include "Player/VGPlayerController.h"

AVGArenaGameMode::AVGArenaGameMode()
{
    GameStateClass = AVGArenaGameState::StaticClass();
    PlayerStateClass = AVGArenaPlayerState::StaticClass();
    PlayerControllerClass = AVGPlayerController::StaticClass();
    DefaultPawnClass = AVGCharacter::StaticClass(); // o BP_VGArenaGameMode troca por BP_ArenaJogador
}

bool AVGArenaGameMode::ReadyToStartMatch_Implementation()
{
    if (bDelayedStart)
    {
        return false;
    }
    return GetMatchState() == MatchState::WaitingToStart && GetNumPlayers() >= PlayersToStart;
}

AActor* AVGArenaGameMode::ChoosePlayerStart_Implementation(AController* Player)
{
    TArray<AActor*> Starts;
    TArray<FVector> StartLocations;
    for (TActorIterator<APlayerStart> It(GetWorld()); It; ++It)
    {
        Starts.Add(*It);
        StartLocations.Add(It->GetActorLocation());
    }

    // O servidor conhece TODOS os controllers (Cap. 10); o cliente só conheceria o seu.
    TArray<FVector> Threats;
    for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
    {
        const APlayerController* Other = It->Get();
        if (Other && Other != Player && Other->GetPawn())
        {
            Threats.Add(Other->GetPawn()->GetActorLocation());
        }
    }

    const int32 Index = VGArenaRules::PickFarthestSpawn(StartLocations, Threats);
    return Starts.IsValidIndex(Index) ? Starts[Index] : Super::ChoosePlayerStart_Implementation(Player);
}
```

```cpp
// Source/Vigilia/Arena/VGArenaGameState.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameState.h"
#include "VGArenaGameState.generated.h"

/**
 * Estado da partida visível a todos (Cap. 10). Existe no servidor e em cada cliente.
 * Este capítulo: só a ferramenta de depuração de rede. Cap. 65: tempo, limite e vencedor.
 */
UCLASS()
class VIGILIA_API AVGArenaGameState : public AGameState
{
    GENERATED_BODY()

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    void DrawNetDebug();

    FTimerHandle NetDebugHandle;
};
```

```cpp
// Source/Vigilia/Arena/VGArenaPlayerState.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerState.h"
#include "VGArenaPlayerState.generated.h"

/** Dados públicos de um jogador da Arena. Vazio por enquanto: o placar chega no Cap. 64. */
UCLASS()
class VIGILIA_API AVGArenaPlayerState : public APlayerState
{
    GENERATED_BODY()
};
```

### 4. Ver a rede

Debugar rede sem enxergar papéis é adivinhar. A ferramenta mínima escreve, sobre cada pawn, em que mundo você está e que papel aquele pawn tem **nesta** máquina.

```cpp
// Source/Vigilia/Debug/VGNetDebug.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/EngineBaseTypes.h"

namespace VGNetDebug
{
    inline const TCHAR* RoleName(ENetRole Role)
    {
        switch (Role)
        {
        case ROLE_Authority:       return TEXT("Authority");
        case ROLE_AutonomousProxy: return TEXT("Autonomous");
        case ROLE_SimulatedProxy:  return TEXT("Simulated");
        default:                   return TEXT("None");
        }
    }

    inline const TCHAR* NetModeName(ENetMode Mode)
    {
        switch (Mode)
        {
        case NM_Standalone:      return TEXT("Standalone");
        case NM_DedicatedServer: return TEXT("DedicatedServer");
        case NM_ListenServer:    return TEXT("ListenServer");
        case NM_Client:          return TEXT("Client");
        default:                 return TEXT("?");
        }
    }
}
```

```cpp
// Source/Vigilia/Arena/VGArenaGameState.cpp
#include "Arena/VGArenaGameState.h"

#include "Debug/VGNetDebug.h"
#include "DrawDebugHelpers.h"
#include "EngineUtils.h"
#include "GameFramework/Pawn.h"
#include "HAL/IConsoleManager.h"
#include "TimerManager.h"

static TAutoConsoleVariable<bool> CVarVGDebugNet(
    TEXT("vg.Debug.Net"), false,
    TEXT("Escreve sobre cada pawn o modo de rede deste mundo e os papéis local/remoto do pawn."));

namespace
{
    constexpr float NetDebugInterval = 0.25f;
}

void AVGArenaGameState::BeginPlay()
{
    Super::BeginPlay();
    // Roda em TODAS as máquinas: cada uma desenha a sua própria visão.
    GetWorldTimerManager().SetTimer(NetDebugHandle, this, &AVGArenaGameState::DrawNetDebug,
                                    NetDebugInterval, /*bLoop=*/true);
}

void AVGArenaGameState::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearTimer(NetDebugHandle);
    Super::EndPlay(EndPlayReason);
}

void AVGArenaGameState::DrawNetDebug()
{
    if (!CVarVGDebugNet.GetValueOnGameThread())
    {
        return;
    }
    UWorld* World = GetWorld();
    const TCHAR* Mode = VGNetDebug::NetModeName(World->GetNetMode());

    for (TActorIterator<APawn> It(World); It; ++It)
    {
        const APawn* Pawn = *It;
        const FString Text = FString::Printf(TEXT("%s | local: %s | remoto: %s%s"),
            Mode,
            VGNetDebug::RoleName(Pawn->GetLocalRole()),
            VGNetDebug::RoleName(Pawn->GetRemoteRole()),
            Pawn->IsLocallyControlled() ? TEXT(" | MEU") : TEXT(""));
        DrawDebugString(World, Pawn->GetActorLocation() + FVector(0.0, 0.0, 120.0), Text,
                        nullptr, FColor::White, NetDebugInterval, /*bDrawShadow=*/true);
    }
}
```

### 5. O teste

```cpp
// Source/Vigilia/Tests/VGArenaRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Arena/VGArenaRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGArenaRulesTest, "Vigilia.Arena.Rules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGArenaRulesTest::RunTest(const FString& Parameters)
{
    const TArray<FVector> Spawns = { FVector(0.0, 0.0, 0.0), FVector(1000.0, 0.0, 0.0), FVector(2000.0, 0.0, 0.0) };

    TestEqual(TEXT("Sem ameaças: o primeiro ponto"),
              VGArenaRules::PickFarthestSpawn(Spawns, TArray<FVector>()), 0);
    TestEqual(TEXT("Ameaça na origem: o ponto mais distante"),
              VGArenaRules::PickFarthestSpawn(Spawns, TArray<FVector>{ FVector(0.0, 0.0, 0.0) }), 2);
    TestEqual(TEXT("Ameaças nas pontas: o do meio"),
              VGArenaRules::PickFarthestSpawn(Spawns, TArray<FVector>{ FVector(-100.0, 0.0, 0.0), FVector(2100.0, 0.0, 0.0) }), 1);
    TestEqual(TEXT("Sem pontos: nenhum"),
              VGArenaRules::PickFarthestSpawn(TArray<FVector>(), TArray<FVector>{ FVector::ZeroVector }), INDEX_NONE);
    return true;
}

#endif
```

### Explicação das decisões

- **`AGameMode`, não `AGameModeBase`.** A Arena tem uma partida com começo, meio e fim, e o `AGameMode` já tem a máquina de estados para isso (`WaitingToStart`, `InProgress`, `WaitingPostMatch`). Enquanto a partida espera, os jogadores entram como espectadores, e quando ela começa, o `AGameMode` cria os pawns de todos. Reescrever isso seria trabalhar contra a engine (critério 6 do Capítulo 6).
- **`ReadyToStartMatch` sobrescrito, não substituído.** A checagem de `bDelayedStart` é mantida para que um designer possa segurar a partida no Blueprint (um aquecimento, por exemplo).
- **Escolha do ponto de nascimento com a regra pura e a coleta de dados no GameMode.** Iterar `PlayerStart`s e controllers depende do mundo; comparar distâncias não. O teste cobre a parte que tem lógica.
- **A ferramenta de depuração no `GameState`.** É a única classe da Arena que existe em todas as máquinas e não pertence a um jogador. O timer de 4 Hz é suficiente para leitura humana e não pesa.
- **Papel local e remoto juntos.** "Authority" sozinho não diz se você está no anfitrião olhando o próprio corpo ou no anfitrião olhando o corpo do cliente. O par (local, remoto) mais o "MEU" diz.

---

## Projeto Arena — a primeira partida

### Montagem

1. **`L_Arena`**: um recorte do Galpão de Testes (Projeto 2), de uns 30 × 30 m, com três ou quatro coberturas baixas, uma passarela elevada e quatro `PlayerStart` nos cantos. É um *blockout* (Capítulo 50): só caixas, sem arte. Em *World Settings*, *GameMode Override* = `BP_VGArenaGameMode`.
2. **`BP_VGArenaGameMode`** (filho de `AVGArenaGameMode`): `Default Pawn Class` = `BP_ArenaJogador`.
3. **`BP_ArenaJogador`** (filho de `BP_VGJogadora`): uma malha de corpo inteiro visível para os **outros** (a cápsula da Vigília não tem corpo em terceira pessoa), com *Owner No See* ligado para que o próprio jogador não veja o corpo dentro da câmera. No `UVGWeaponComponent`, `StartingWeaponClass` = `BP_Fuzil` (Capítulo 20).
4. **PIE:** 2 jogadores, *Play As Listen Server*, *Run Under One Process* ligado. `vg.Debug.Net 1` no console.

### O que a ferramenta mostra

Na janela do servidor, sobre o próprio pawn: `ListenServer | local: Authority | remoto: Autonomous | MEU`. Sobre o pawn do cliente: `ListenServer | local: Authority | remoto: Autonomous`. Na janela do cliente, sobre o próprio pawn: `Client | local: Autonomous | remoto: Authority | MEU`. Sobre o pawn do anfitrião: `Client | local: Simulated | remoto: Authority`.

Leia essas quatro linhas até elas parecerem óbvias. A Parte IX inteira é sobre o que cada uma permite fazer.

### O inventário de quebras

Jogue cinco minutos, primeiro sem emulação, depois com 100 ms e 2% de perda. Anote tudo o que parece errado. É o equivalente, para a Parte IX, do inventário de dores do Interlúdio I: a lista que os próximos capítulos resolvem, uma quebra de cada vez.

| # | Quebra | O que você vê | Causa | Resolve em |
|---|---|---|---|---|
| Q1 | **Dano fantasma** | O cliente atira no anfitrião e vê a vida dele cair; na janela do anfitrião, nada aconteceu. Às vezes o cliente vê o anfitrião "morrer" e continuar andando | A arma do cliente roda o trace e chama `ApplyPointDamage` na **cópia local** do alvo | 64, 66 |
| Q2 | **Arma em dobro** | Cada janela vê armas diferentes; a arma do outro jogador flutua no lugar errado ou não aparece | O `BeginPlay` do `UVGWeaponComponent` cria a arma em **cada máquina**, e a arma não é replicada | 64, 65 |
| Q3 | **Corrida elástica** | Com latência, o cliente corre e é puxado para trás, aos trancos | `MaxWalkSpeed` muda só no cliente; o servidor simula o movimento com a velocidade de caminhada e corrige | 67 |
| Q4 | **Morte pela metade** | O anfitrião mata o cliente: no servidor, o corpo cai; no cliente, a câmera congela e o input de morte não entra | A vida não é replicada; o modo `Dead` do Capítulo 22 só é empilhado em controller local | 65, 66 |
| Q5 | **"Continuar" mudo** | O cliente morto aperta "continuar" e nada acontece | `RequestRespawn` chama `GetAuthGameMode()`, nulo no cliente | 64 |
| Q6 | **Sem placar** | Ninguém sabe quem está ganhando | Não há estado de partida | 64, 65 |
| Q7 | **HUD surda** | O marcador de abate do Capítulo 27 nunca aparece no cliente | O barramento de eventos é **por processo** | 66 |
| Q8 | **Pulo que volta** | Com latência, o pulo no limite da beirada (*coyote time*) às vezes é desfeito | A janela de *coyote* é medida no relógio do mundo, que difere entre as máquinas | 67 |
| Q9 | **Tiro atrasado** | Depois de Q1 consertado, com 100 ms, o tiro do cliente parece sair "depois" do clique | O cliente espera o servidor para ver o próprio tiro | 67 |
| Q10 | **"Mas eu acertei!"** | Com 100 ms, tiros que acertaram na tela do cliente erram no servidor | O servidor julga o tiro com as posições **dele**, não com as que o cliente via | 68 |

E, tão importante quanto, **o que não quebrou**:

- **Câmera, FOV dinâmico, head bob, passos e coice.** São apresentação local, derivada de estado que o cliente já tem (Capítulos 18, 23 e 29).
- **Agachar.** O `UCharacterMovementComponent` já transporta "quero agachar" nos movimentos que envia ao servidor. Compare com Q3: agachar é um recurso da engine que nasceu preditivo; correr foi um campo trocado à mão. O Capítulo 67 explica a diferença e aplica o mesmo mecanismo à corrida.
- **Pular** (fora da beirada). Também viaja no movimento.

Registre o inventário no `DEVLOG.md`. Ele é o critério de conclusão da Parte IX: o Capítulo 68 termina quando todas as linhas estiverem resolvidas.

---

## Decisões arquiteturais

1. **Cliente/servidor autoritativo**, o modelo da engine. Lockstep foi descartado por exigir determinismo que a Unreal não garante.
2. **Listen server para iterar, servidor dedicado para validar.** Os dois modos rodam antes de cada capítulo ser considerado concluído.
3. **`AGameMode` + `AGameState` + `APlayerState` próprios** para a Arena, numa pasta `Arena/` separável. As refatorações de rede de classes existentes ficam nas pastas delas.
4. **Três camadas de estado** (simulação, intenção, apresentação) como primeira triagem. A apresentação continua local.
5. **Toda verificação de rede com 100 ms e 2% de perda** pelo menos uma vez.
6. **Um inventário de quebras** como critério de conclusão da Parte IX.

---

## Armadilhas

- **Testar só com latência zero.** O PIE sem emulação esconde quase tudo. Q3, Q8, Q9 e Q10 não existem a 0 ms.
- **Testar só como anfitrião.** O anfitrião é `Authority` e jogador local ao mesmo tempo; código que mistura os dois conceitos funciona para ele e quebra para o cliente.
- **Testar só como listen server.** O dedicado não tem jogador local. Código que assume "o servidor tem um pawn local" quebra lá.
- **Achar que um subsistema é global.** Cada processo, e cada instância de PIE, tem os seus. O servidor e o cliente nunca compartilham um `UWorldSubsystem`.
- **Confiar em CVars e `static` no PIE de um processo.** São compartilhados entre as instâncias e mascaram bugs que um build real revelaria.
- **Chamar `GetAuthGameMode()` sem tratar nulo.** No cliente ele é sempre nulo, por design.
- **Assumir que o `BeginPlay` roda uma vez.** Roda uma vez **por máquina** em que o ator existe.
- **Começar pelo matchmaking.** Sessões, lobby e servidores dedicados são o fim da trilha (Interlúdio III), não o começo. Sem os fundamentos, viram uma camada sobre um jogo que não funciona em rede.

---

## Exercício

**Parte 1 — a arena e as classes (1,5 h).** Monte `L_Arena`, `BP_VGArenaGameMode` e `BP_ArenaJogador`. Implemente `AVGArenaGameMode`, `AVGArenaGameState`, `AVGArenaPlayerState`, `VGArenaRules` e o teste. Confirme que a partida não começa com um jogador só (o primeiro fica como espectador) e que começa quando o segundo entra.

**Parte 2 — papéis (45 min).** Ligue `vg.Debug.Net` e anote as quatro combinações de papel (anfitrião olhando cada pawn, cliente olhando cada pawn). Repita com *Play As Client* e 2 jogadores: que linhas mudam, e por quê? (Dica: não há "MEU" no servidor dedicado.)

**Parte 3 — o inventário (1,5 h).** Jogue com e sem emulação (100 ms, 2% de perda). Reproduza cada quebra de Q1 a Q10 e anote no `DEVLOG.md` o passo a passo para provocá-la. Para Q1, escreva em uma frase **em que máquina** o `ApplyPointDamage` rodou e **em que cópia** do alvo.

**Parte 4 — o que não quebrou (30 min).** Para cada sistema da lista "o que não quebrou", aponte no código **por que** ele sobreviveu: que dado ele lê, e por que esse dado já existe na máquina local.

---

## Desafio — "Os primos no sofá"

Implemente o modo **local** da Arena: dois jogadores no mesmo processo, tela dividida, sem rede.

1. Ative a tela dividida nas configurações de projeto (*Maps & Modes → Local Multiplayer*) e crie o segundo jogador com `UGameplayStatics::CreatePlayer`.
2. Rode a Arena em *Play Offline* com o segundo controle ligado.
3. Compare com o inventário: **quais quebras desaparecem** no modo local, e quais continuam? (Spoiler parcial: algumas que parecem "de rede" são, na verdade, de "mais de um jogador", como um `UGameplayStatics::GetPlayerCharacter(this, 0)` esquecido em algum sistema.)
4. Escreva no `DEVLOG.md` uma tabela com duas colunas, "problemas de ter dois jogadores" e "problemas de ter duas máquinas". É a versão prática da comparação da spec 3.23.

---

## Uso de IA

1. **Para mapear um sistema existente:**
   > "Aqui está um componente de jogo em Unreal Engine 5 escrito para single-player. Liste cada pedaço de estado que ele mantém e classifique em: simulação autoritativa (decide o resultado), intenção do jogador, ou apresentação local. Para cada um, diga o que aconteceria num listen server com dois jogadores se nada mudasse. Não proponha código ainda. [código]"

2. **Para entender um papel de rede:**
   > "Explique, para alguém que conhece sistemas distribuídos mas não a Unreal, a diferença entre ROLE_Authority, ROLE_AutonomousProxy e ROLE_SimulatedProxy, usando um pawn de FPS em três máquinas (servidor, cliente dono, outro cliente). Para cada máquina, diga o que o código pode decidir sobre esse pawn e o que só pode mostrar."

3. **Para desenhar o teste:**
   > "Monte um roteiro de testes manuais para um jogo de tiro 1v1 em Unreal (listen server e servidor dedicado, com e sem 100 ms de latência). Cada passo deve dizer o que fazer, em qual janela olhar e qual sintoma indica um bug de autoridade, de replicação ou de predição."

**Cuidado específico:** a IA tende a responder perguntas de rede da Unreal com código que **parece** correto e falha em um dos três casos (anfitrião, cliente, dedicado), porque a maior parte dos exemplos públicos testa só um. Para cada sugestão, pergunte explicitamente: "o que acontece no listen server para o jogador anfitrião, no cliente e no servidor dedicado?", e confira no PIE.

---

## Checklist

- [ ] Sei explicar, com o exemplo do sofá, por que o multiplayer local não tem o problema do desacordo e o online tem.
- [ ] Sei comparar lockstep, cliente/servidor, listen server e servidor dedicado, e dizer para que serve cada um.
- [ ] Sei que cada máquina tem o seu `UWorld`, os seus atores, subsistemas e timers.
- [ ] Sei ler os pares de papéis (local, remoto) de um pawn nas três máquinas.
- [ ] Sei onde cada classe do Gameplay Framework existe, e por que o `PlayerController` é especial.
- [ ] Rodei a Arena como listen server e como cliente de servidor dedicado, com e sem emulação de rede.
- [ ] Tenho o inventário de quebras Q1–Q10 reproduzido e registrado.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): a seção **Networking and Multiplayer**, em especial a visão geral de rede, os papéis de ator (*Actor Role and Remote Role*) e os testes de multiplayer no editor (*Play In Editor*, configurações multiplayer e emulação de rede).
- **"Unreal Networking Architecture"**, de Tim Sweeney: o documento original do modelo de rede da engine. É antigo e os nomes de classe mudaram, mas o modelo mental é o mesmo. Procure pelo título.
- **Gabriel Gambetta, "Fast-Paced Multiplayer"** (gabrielgambetta.com): a primeira parte, sobre arquitetura cliente/servidor, é a melhor introdução curta ao assunto.
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** os capítulos de topologias de rede e de modelos de replicação.
- **GGPO** (ggpo.net) e, no **GDC Vault** (gdcvault.com), *8 Frames in 16ms: Rollback Networking in Mortal Kombat and Injustice 2*, de Michael Stallone: o modelo de rollback, que reaparece no Capítulo 67.

---

➡️ **Próximo:** [Capítulo 64 — Authority](cap-64-authority.md)

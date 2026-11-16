# INTERLÚDIO III — Multiplayer avançado

*Do laboratório de dois jogadores ao jogo de verdade: servidores, partidas, lobbies, matchmaking, IA, física, mundos abertos, escala, e uma Vigília para dois.*

---

## Objetivo

Ao final deste interlúdio você deve conseguir:

- explicar o que muda quando o jogo passa a rodar em **servidores dedicados**, e o que a Unreal exige para isso;
- descrever o ciclo de vida de uma **partida** (estados, entrada no meio, reconexão, troca de mapa) e o papel de um **lobby**;
- separar o que a Unreal oferece para **encontrar partidas** (sessões, Online Subsystem) do que é **matchmaking** de verdade (um serviço), sem confundir os dois;
- aplicar o modelo de autoridade da Parte IX a **NPCs**, à **física e destruição** e a **mundos abertos compartilhados**, e explicar por que cada um é mais difícil que um personagem;
- raciocinar sobre **escala**: o que quebra primeiro ao ir de 2 para 16, 64 e 100 jogadores;
- desenhar a **Vigília cooperativa**: a Presença com autoridade no servidor, o estado narrativo no servidor, quem ouve o rádio, e o escopo do ramo experimental do Capítulo 84.

---

## Contexto

O Projeto Arena terminou com um inventário fechado e uma lista honesta de limites. O último deles diz: **dois jogadores**. A Arena roda no PIE, com o anfitrião escolhido à mão, numa sala de 30 metros, sem IA, sem física compartilhada e sem nenhum caminho para dois desconhecidos se encontrarem.

A trilha da spec (3.15) termina com quatro passos que a Arena não percorreu: **servidor dedicado → partida → lobby → matchmaking**. A spec também pede que o multiplayer seja combinado com o que veio antes: **Game AI** (3.20), **física** (3.21) e **mundo aberto** (3.22). E pede, para o projeto final (3.24), que uma parte pequena da Vigília ganhe uma **versão multiplayer experimental**, para entender como uma arquitetura pensada para um jogador muda quando o mundo é compartilhado.

Este interlúdio é majoritariamente conceitual. Cada um desses temas é um livro, e o objetivo aqui é o mapa: o que existe, o que a Unreal oferece, onde está a dificuldade e que decisão a Vigília tomaria. O código aparece onde ele esclarece uma decisão, e a última seção prepara o ramo cooperativo do Capítulo 84.

---

## III.1 Servidor dedicado

Um servidor dedicado é o jogo sem jogador: o mesmo código de simulação, sem renderização, sem áudio, sem interface, rodando numa máquina que nenhum jogador controla. O Capítulo 63 o comparou com o *listen server*, e o Arena o testou com *Play As Client*. Em produção, ele traz quatro mudanças.

**1. Um alvo de build próprio.** O servidor é compilado como um alvo separado:

```csharp
// Source/VigiliaServer.Target.cs
using UnrealBuildTool;

public class VigiliaServerTarget : TargetRules
{
    public VigiliaServerTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Server;
        DefaultBuildSettings = BuildSettingsVersion.Latest;
        ExtraModuleNames.Add("Vigilia");
    }
}
```

**[FATO PÚBLICO]** A documentação da Unreal indica que alvos de servidor dedicado exigem a engine compilada a partir do código-fonte (o repositório da Epic no GitHub); a versão instalada pelo *launcher* não compila esse alvo. ⚠️ Confira a página *Setting Up Dedicated Servers* da sua versão.

**2. Código que não deve existir no servidor.** A macro `UE_SERVER` vale 1 no build de servidor, e `IsRunningDedicatedServer()` responde em runtime. A Arena já segue a regra que importa: apresentação testa `GetNetMode() != NM_DedicatedServer` (o `PlayShotFx` do Capítulo 66), e nada de jogo depende de câmera, HUD ou áudio. O que vale procurar no projeto da Vigília antes de um servidor dedicado: widgets criados fora de controllers locais, sons tocados por sistemas de regra, e qualquer leitura de `GetFirstLocalPlayerController()` em código que roda no servidor.

**3. Coisas que o servidor "não vê".** Um servidor sem renderização não atualiza o que depende de visibilidade. O caso mais traiçoeiro é a animação (Capítulo 68, Armadilhas): ⚠️ a pose de uma malha esquelética pode não ser atualizada sem renderização, e traços contra os ossos ficam presos na pose antiga. O mesmo raciocínio vale para efeitos de partículas usados como lógica (não use) e para qualquer coisa feita no `Tick` de um widget.

**4. Operação.** Um servidor dedicado é um processo para cada partida (ou alguns por máquina), em regiões próximas dos jogadores, ligado e desligado conforme a demanda. O custo é medido em **jogador-hora**, e cada decisão das Partes VIII e IX (tick rate, banda, CPU de IA e de relevância) aparece nessa conta. **[INFERÊNCIA]** É por isso que estúdios discutem publicamente taxas de atualização (o Apex do Capítulo 68, o Battlefield 4 do Capítulo 65): a conta é multiplicada por milhares de servidores.

---

## III.2 Partida

O `AGameMode` que a Arena usa tem uma máquina de estados de partida (`MatchState`): `EnteringMap`, `WaitingToStart`, `InProgress`, `WaitingPostMatch`, `LeavingMap` e `Aborted`. A Arena usou três deles. Um jogo de verdade usa todos, e acrescenta quatro problemas.

**Aquecimento.** Entre `WaitingToStart` e `InProgress`, jogadores costumam poder andar e atirar sem pontuar. Na Unreal, é uma decisão do `ReadyToStartMatch` e de onde o placar é contado.

**Entrar no meio.** Um jogador que chega com a partida em andamento recebe o estado **atual** de cada ator relevante (Capítulo 65). Tudo o que foi modelado como estado (placar, vida, fase) chega certo; tudo o que foi modelado como evento (o *kill feed*) não chega, e não precisa. Esse é o teste definitivo da regra "replique estado": se um jogador que entra no meio vê um mundo inconsistente, algum estado foi mandado como evento.

**Sair e voltar.** Quando um jogador cai, o `PlayerState` dele pode ser guardado como **inativo** por um tempo. O `AGameMode` mantém uma lista de jogadores inativos e, se o mesmo jogador voltar, recupera os dados dele (o mecanismo usa `APlayerState::CopyProperties` para levar os campos de uma instância para outra). O `AVGArenaPlayerState` precisaria sobrescrever `CopyProperties` para levar abates e mortes. ⚠️ Confira os nomes (`AddInactivePlayer`, `FindInactivePlayer`) no `GameMode.h` da sua versão.

**Trocar de mapa.** `ServerTravel` leva o servidor e todos os clientes para outro mapa. Na viagem comum, todas as conexões são refeitas. Na **viagem contínua** (*seamless travel*, `bUseSeamlessTravel` no GameMode e um mapa de transição), as conexões se mantêm, e alguns atores, como os controllers e os `PlayerState`s, atravessam a troca. ⚠️ O suporte a viagem contínua dentro do PIE mudou entre versões; teste num build.

---

## III.3 Lobby

Um **lobby** é o lugar (um mapa, uma tela, ou um estado do servidor) onde jogadores se juntam antes da partida: escolhem equipe e equipamento, marcam que estão prontos, esperam completar a sala. Arquiteturalmente, é uma **partida que não é partida**: tem jogadores, `PlayerState`s e regras (quem é o anfitrião, quando todos estão prontos), mas não tem jogo.

Na Unreal, a forma mais comum é um mapa de lobby com um GameMode próprio:

- o estado "pronto" de cada jogador é uma propriedade replicada do `PlayerState` (estado, não evento: quem entrar depois precisa vê-lo), alterada por um RPC `Server` ("estou pronto");
- o GameMode do lobby verifica as condições e chama `ServerTravel` para o mapa da partida;
- com viagem contínua, as escolhas feitas no lobby atravessam a troca dentro dos `PlayerState`s.

Um conceito vizinho é o **grupo** (*party*): amigos que querem jogar juntos e entrar na mesma partida. O grupo existe **antes** e **fora** de qualquer servidor de jogo, e é por isso que ele mora num serviço (a plataforma, um backend), não no GameMode.

---

## III.4 Matchmaking

É fácil confundir duas coisas que a Unreal separa bem.

### Encontrar uma partida: sessões

O **Online Subsystem** da Unreal é uma camada de abstração sobre serviços online (Steam, Epic Online Services, plataformas de console, e uma implementação **Null** para LAN e testes). A interface de **sessões** permite anunciar, procurar e entrar em partidas:

| Operação | O que faz |
|---|---|
| `CreateSession` | Anuncia uma partida com configurações (vagas, LAN ou não, se aceita entrada no meio) |
| `FindSessions` | Procura partidas anunciadas, com filtros |
| `JoinSession` | Entra numa sessão encontrada; o endereço de conexão vem do subsistema |
| `StartSession` / `EndSession` | Marca o início e o fim da partida para o serviço |
| `DestroySession` | Remove a sessão |

Um esboço, para dar forma à ideia (o padrão de *callbacks* com *delegates* fica de fora):

```cpp
// Esboço: anunciar a Arena numa LAN com o Online Subsystem (módulos OnlineSubsystem e OnlineSubsystemUtils).
// ⚠️ Confira a API de sessões da sua versão; nas versões recentes há também os plugins "Online Services".
#include "OnlineSubsystem.h"
#include "OnlineSessionSettings.h"
#include "Interfaces/OnlineSessionInterface.h"

void AnnounceArenaOnLan()
{
    IOnlineSubsystem* Online = IOnlineSubsystem::Get(); // com DefaultPlatformService=Null no DefaultEngine.ini
    const IOnlineSessionPtr Sessions = Online ? Online->GetSessionInterface() : nullptr;
    if (!Sessions.IsValid())
    {
        return;
    }
    FOnlineSessionSettings Settings;
    Settings.NumPublicConnections = 2;
    Settings.bIsLANMatch = true;
    Settings.bShouldAdvertise = true;
    Settings.bAllowJoinInProgress = true;
    Sessions->CreateSession(/*HostingPlayerNum=*/0, NAME_GameSession, Settings);
}
```

Sessões resolvem "existe uma partida ali, e este é o caminho para entrar". Elas **não** decidem quem deve jogar com quem.

⚠️ A Epic introduziu, nas versões mais recentes, uma família de plugins chamada **Online Services**, com interfaces novas, ao lado do Online Subsystem clássico. O exemplo Lyra usa um plugin de conveniência (*CommonUser*) por cima disso. Verifique o estado e a recomendação para a sua versão antes de escolher.

### Juntar as pessoas certas: matchmaking

**Matchmaking** é o serviço que escolhe **quais** jogadores formam uma partida, e em **qual** servidor. Ele equilibra critérios que competem entre si:

| Critério | Por quê | Custo |
|---|---|---|
| **Latência** | Jogar no servidor da sua região (Capítulo 68: o rebobinamento tem limite) | Menos jogadores por região |
| **Habilidade** | Partidas equilibradas; cada jogador tem uma estimativa de habilidade | Esperas maiores; discussão sobre "partidas suadas" |
| **Grupo** | Amigos juntos; grupos contra grupos | Restringe combinações |
| **Tempo de espera** | Ninguém espera dez minutos | Relaxa os outros critérios com o tempo |
| **Preenchimento** (*backfill*) | Repor quem saiu de uma partida em andamento | Jogadores entrando em partidas perdidas |

Os modelos de estimativa de habilidade mais conhecidos são públicos: o **Elo** (do xadrez), o **Glicko** e o **TrueSkill** (publicado pela Microsoft Research, usado em jogos de Xbox). A Unreal não traz nenhum deles, nem um serviço de matchmaking: ele vem da plataforma, de um serviço de terceiros ou de um backend próprio, que, no fim, devolve ao cliente o endereço de um servidor dedicado para o qual viajar.

**[FATO PÚBLICO]** Em 2024, a Activision publicou um texto técnico sobre o matchmaking de Call of Duty, descrevendo a latência de conexão como o fator dominante e a habilidade como um dos vários fatores considerados (confira a série *Call of Duty Matchmaking* no site de pesquisa da Activision).

**[INFERÊNCIA]** Para um jogo do tamanho de Call of Duty, o matchmaking é um sistema distribuído à parte, com a sua própria engenharia. Para a Vigília, um jogo cooperativo de duas pessoas que se conhecem, o "matchmaking" é um convite de amigo e uma sessão. A spec pede que o tema seja entendido conceitualmente; entendê-lo inclui saber quando ele é desnecessário.

---

## III.5 Multiplayer + Game AI

A spec (3.20) desenha a combinação assim:

```text
 Multiplayer
      │
      ├── Players
      │
      ├── NPCs
      │
      ├── Server
      │
      └── Simulation
```

E pede respostas a sete perguntas. Na Unreal, com o que a Parte V construiu:

**Onde a IA roda?** No servidor. O `AAIController` existe só no servidor, como o GameMode: ele não é replicado. A Behavior Tree, o Blackboard, a percepção e o EQS rodam lá. Os clientes **não têm** IA; têm pawns de NPC.

**Quem tem autoridade sobre os NPCs?** O servidor, sem exceção. Um NPC não tem dono jogador, então nenhum cliente pode chamar RPCs `Server` nele (Capítulo 66): um jogador interage com um NPC sempre pelos próprios atores.

**Como o estado do NPC é replicado?** O pawn do NPC é replicado como o de um jogador, e é um *simulated proxy* em **todos** os clientes: ninguém prevê o movimento dele. O CMC move o NPC no servidor, e os clientes suavizam. O que a IA **pensa** (o Blackboard inteiro) não precisa ir para ninguém. O que a IA **mostra** precisa: um estado compacto de apresentação (um `enum` de alerta, que escolhe animação, som e expressão) replicado com `OnRep`, e eventos pontuais (um grito, um *bark*) por *multicast*.

**Como reduzir o tráfego?** Com as ferramentas do Capítulo 65, que funcionam melhor para NPCs que para jogadores: um NPC longe de todos os jogadores não é relevante para ninguém, e um NPC parado num posto pode dormir (dormência) até algo mudar.

**Relevância e dormência.** Atenção a uma diferença: dormência e relevância economizam **rede**, não **CPU**. Um NPC irrelevante para todos os clientes continua pensando no servidor. Para CPU, é preciso outra ferramenta.

**Atualização de IA.** Um nível de detalhe para a IA: NPCs longe de todos os jogadores atualizam a Behavior Tree e a percepção com menos frequência, ou deixam de simular e passam a ser "teleportados" pela regra (um guarda distante que só precisa estar em outro posto daqui a cinco minutos). A Unreal tem um plugin, o **Significance Manager**, para atribuir importância a objetos conforme a distância aos observadores e ajustar o custo de cada um.

**Escalabilidade.** No single-player, a IA tem um observador. No multiplayer, cada NPC precisa considerar vários: quem ele percebe (a percepção já trata vários estímulos), em quem ele mira, e para quem ele "atua". O custo de percepção cresce com NPCs × jogadores.

Uma nuance que o Capítulo 68 deixou para cá: o jogador também vê o NPC **no passado**. Se a IA se move rápido e os disparos contra ela devem ser justos, os NPCs também precisam do `UVGHitboxHistoryComponent`. Para inimigos lentos (o vigia que se arrasta, a Presença que espreita), o erro é pequeno.

---

## III.6 Multiplayer + física e destruição

A spec (3.21) resume o problema numa comparação: **sincronizar uma posição** é muito mais simples do que **sincronizar um mundo físico complexo entre vários clientes**. Os motivos são quatro.

1. **Sensibilidade.** Uma simulação física com muitos corpos em contato é caótica: uma diferença de um milímetro no início vira uma pilha de caixas que cai para o outro lado.
2. **Determinismo.** Mesmo com os mesmos inputs, duas máquinas podem divergir (ordem de resolução de contatos, ponto flutuante, passo de tempo variável). A física de uma engine comercial raramente garante resultados idênticos entre máquinas diferentes.
3. **Volume.** Um personagem é um corpo com poucos números. Uma parede destruída são centenas de fragmentos, cada um com posição, rotação e velocidade.
4. **Interação.** Corpos de jogadores diferentes empurram o mesmo objeto, e ninguém pode prever o efeito do empurrão do outro.

As respostas da indústria separam a física em **categorias**:

| Categoria | Exemplos | Tratamento comum |
|---|---|---|
| **Física de jogo** (decide o resultado) | Veículo, projétil lento, uma porta empurrável que bloqueia um tiro | Autoritativa no servidor; transformações replicadas e suavizadas; para o que o jogador controla, predição (mais difícil que a do personagem) |
| **Física cosmética** | Fragmentos, cápsulas de bala, *ragdolls* depois da morte, papéis voando | Simulada **localmente** em cada cliente, sem sincronização: cada um vê uma versão diferente, e ninguém percebe |
| **Estado de destruição** | "Esta parede caiu", "este pilar tem dano 2 de 3" | **Estado discreto** replicado; os fragmentos de cada cliente são cosméticos |

Na Unreal, atores com física simulada podem replicar o movimento (`bReplicates` e movimento replicado), e o servidor envia as transformações, que os clientes suavizam. ⚠️ A UE5 tem trabalho em andamento em física de rede com predição e ressimulação no Chaos; o estado muda entre versões, então verifique antes de planejar em cima dela.

**[FATO PÚBLICO]** O Battlefield 4 apresentou o *Levolution*: eventos de destruição em escala de mapa, como um arranha-céu que desaba no mapa Siege of Shanghai e muda o terreno da partida para todos os jogadores. A série Battlefield, desde a geração do Bad Company, é conhecida pela destruição de construções.

**[INFERÊNCIA]** Para que a destruição seja justa em rede, o que **decide** o jogo (onde há cobertura, por onde se passa) precisa ser estado discreto e autoritativo, igual para todos. A queda em si, com fragmentos e poeira, pode ser diferente em cada cliente, desde que termine no mesmo estado. Os detalhes de implementação da DICE não são deduzíveis daqui; palestras da DICE sobre o Frostbite estão no GDC Vault (confira os títulos lá).

O diagrama da spec 3.14 ganha, agora, a sua leitura completa: **mundo grande + muitos jogadores + veículos + física + destruição + rede** não é uma soma. Cada termo multiplica o custo dos outros, e a engenharia consiste em tirar a maior parte da física da categoria "de jogo" e empurrá-la para "cosmética".

---

## III.7 Multiplayer + mundo aberto

A spec (3.22) pede a diferença arquitetural entre:

```text
 SINGLE PLAYER WORLD                       SHARED ONLINE WORLD

 um jogador                                dezenas de jogadores, espalhados
 o mundo carregado em volta DELE           o mundo carregado em volta de CADA UM, no servidor
 IA, trânsito, pedestres: só perto dele    o que é compartilhado? o que é de cada um?
 o tempo para quando ele pausa             o tempo nunca para
 salvar = gravar o estado dele             o estado vive em serviços, fora da partida
```

**[FATO PÚBLICO, observável jogando]** No GTA Online, os jogadores entram em **sessões** com dezenas de outros jogadores no mesmo mapa de Los Santos; o progresso do personagem (dinheiro, propriedades, veículos, nível) persiste entre sessões, ligado à conta; as missões e atividades costumam acontecer em instâncias separadas da sessão livre; e trocas de sessão e "sessões cheias" fazem parte da experiência.

**[INFERÊNCIA]** Isso sugere uma separação em camadas que vale para qualquer mundo aberto compartilhado:

| Camada | O que guarda | Onde mora |
|---|---|---|
| **Persistente** | O que é do jogador para sempre: progresso, posses | Serviços do backend, fora do servidor de jogo |
| **Sessão** | O que é compartilhado agora: quem está aqui, veículos na rua, o mundo comum | O servidor (ou anfitrião) da sessão |
| **Instância** | Uma atividade com regras próprias: uma missão, uma corrida | Uma partida separada, com início e fim |
| **Local** | O que só decora: trânsito e pedestres de ambiente, clima visual | Cada cliente, quando possível |

Três problemas aparecem em qualquer mundo aberto compartilhado:

- **Streaming no servidor.** No single-player, o mundo é carregado em volta da jogadora (o Interlúdio II). No servidor, ele precisa estar carregado em volta de **cada** jogador, ao mesmo tempo, e a física e a IA rodam em todas essas regiões. ⚠️ Confira como a *World Partition* trata as fontes de *streaming* no servidor na sua versão.
- **Vida ambiente.** Os pedestres e o trânsito de um GTA single-player existem para uma pessoa. Num mundo compartilhado, cada NPC replicado custa banda para todos os que o veem. **[INFERÊNCIA]** É razoável que parte da vida ambiente seja local, e só o que importa para mais de um jogador (o carro em que alguém entrou, o pedestre atingido) passe a ser compartilhado.
- **Persistência.** Salvar não é mais "gravar um arquivo" (Capítulo 56). É uma transação com um serviço, sujeita a falhas, a duplicação de itens e a trapaça. O servidor de jogo pede; o serviço decide.

A spec diz explicitamente que não é necessário estudar a implementação de um MMO. O ponto é perceber que **"mundo aberto" e "multiplayer" não se somam: se multiplicam**, porque cada sistema do Interlúdio II (streaming, LOD de simulação, IA ambiente) precisa ser repensado para N observadores.

---

## III.8 Escala

A Arena foi medida com dois jogadores. Uma tabela de **o que costuma quebrar primeiro** em cada faixa, ao estilo da conta do Capítulo 65. **[SIMPLIFICAÇÃO DIDÁTICA]** As faixas são ordens de grandeza para raciocinar, não limites medidos.

| Jogadores | O que passa a doer | Ferramenta |
|---|---|---|
| **2–8** (cooperativo, duelo) | Quase nada; os bugs são de autoridade e predição | A Parte IX |
| **16–32** | Banda por cliente; *multicasts* de efeitos; o `PlayerState` atualizando devagar | Condições, frequências, quantização, efeitos por relevância |
| **64** (Battlefield 4) | Banda de upload do servidor (~n²); CPU de relevância (conexões × atores); física de veículos | Relevância agressiva, prioridade por distância, dormência, *push model* |
| **100+** (*battle royale*) | CPU de decidir o que enviar, antes da banda | Replication Graph ou Iris (⚠️ verifique o estado), grades espaciais |
| **Mundo persistente** | Um processo não comporta o mundo | Fora do escopo: instâncias, fragmentação (*sharding*), serviços |

Duas observações, que valem para qualquer projeto:

- **Escala é uma decisão de design antes de ser de engenharia.** Um modo de jogo com 64 jogadores **escolhe** mapas grandes (que espalham os jogadores e reduzem a relevância mútua) e veículos (que aceitam extrapolação melhor que pessoas).
- **Meça antes.** As ferramentas de 16–32 custam pouco e servem a qualquer projeto. As de 100+ têm custo de complexidade alto, e só se pagam com o problema medido.

---

## III.9 Uma Vigília para dois

A spec (3.24) pede que o projeto final tenha uma versão multiplayer experimental de uma pequena parte, para entender como a arquitetura muda. O desafio do Capítulo 64 pediu uma tabela de autoridade da Vigília cooperativa; esta seção propõe uma resposta e o escopo do ramo do Capítulo 84. **[HIPOTÉTICO]** Tudo aqui é desenho: a Vigília single-player é o produto, e a cooperativa é um experimento.

### Quem é o segundo jogador

A protagonista é Helena Duarte, e as decisões de design firmadas não mudam. Um experimento cooperativo precisa de um segundo personagem que não contradiga a história: **um segundo técnico do turno**, que entra na Casa de Força com Helena. Nada da narrativa do setor 1 depende de Helena estar sozinha, exceto o rádio, e é o rádio a decisão mais interessante abaixo.

### A tabela

| Sistema | Onde vive hoje | Dono no cooperativo | O que os clientes recebem | Observação |
|---|---|---|---|---|
| **Presença** (BT, percepção, ataque) | `AVGAIController` | Servidor (o controller de IA já só existe lá) | O pawn replicado + um estado de apresentação (`enum` replicado) | Escolha de alvo: quem ela percebe mais (a percepção do Cap. 36 já pesa luz e postura). "Dois toques" e "invencível" valem por jogador, sem mudança |
| **Reação à luz** | `UVGPresenceReactionComponent` lendo tags | Servidor | — | Precisa saber a lanterna **de cada** jogador: ver abaixo |
| **Lanterna e bateria** | `UVGBatteryComponent`, tag `Status.Light.Flashlight` | Servidor | Ligada/desligada replicada a todos; carga só ao dono | Ligar vira pedido (RPC `Server`); a luz em si é local de cada cliente, a partir do estado |
| **Zonas seguras e tags de status** | `AVGSafeZone`, `UVGStatusTagsComponent` | Servidor (sobreposições contam lá) | As tags que a apresentação lê (FOV, música) | O componente de tags vira replicado, com as tags num contêiner replicado |
| **Diretor de tensão** | `UVGDirectorSubsystem` (subsistema de mundo) | Servidor | Só o que a música e a HUD usam (fase de tensão) | Tensão do **grupo**: a do jogador mais tenso; "sem pico durante leitura" passa a valer se **qualquer um** estiver lendo |
| **Ameaça** | `UVGThreatSubsystem` | Servidor | A fase (Calm/Uneasy/Hunting) para a música | Por grupo, como o Diretor |
| **Estado narrativo** (fatos) | `UVGNarrativeSubsystem` (`UGameInstanceSubsystem`) | **O do servidor** | Um espelho dos fatos | Cada processo tem o seu subsistema: o do cliente vira só leitura (ver abaixo) |
| **Rádio e diálogo** | `UVGDialogueSubsystem` | Servidor (fila, prioridades, fatos) | "Qual fala está tocando, desde quando" | Ver "Quem ouve o rádio" |
| **Quests e objetivos** | `UVGQuestSubsystem`, `UVGObjectiveSubsystem` | Servidor | Etapa atual e objetivos ativos, para o diário e a HUD | Os objetivos ouvem o barramento, que no servidor recebe tudo (Cap. 64) |
| **Portas, disjuntores, setores** | `AVGDoor`, `AVGBreakerSwitch`, `AVGSector` | Servidor | Estado replicado (a FSM da porta: estado + início da transição) | Interação por `ServerInteract` (Cap. 66), já pronta |
| **Documentos e leitura** | Leitor (modo `Reading`) | Cliente (é apresentação) + fato "lido" no servidor | — | Ler é local; o **fato** de ter lido é pedido ao servidor |
| **Cinemáticas** | Sequencer (Cap. 49) | Servidor decide **quando**; cada cliente toca a sua | Um evento com o instante de início | Os dois precisam estar "em cena": decisão de design (esperar ou puxar o outro) |
| **Save** | Cap. 56 | Só o anfitrião salva | — | Sem salvar no meio de uma sessão cooperativa no experimento |

### A Presença com autoridade no servidor

A Presença é o caso mais simples da tabela, por um motivo da Parte V: ela já é um sistema de servidor. O `AAIController` não existe nos clientes, a Behavior Tree e a percepção rodam onde o controller está, e o pawn replica como qualquer personagem. O que muda é o mundo que ela percebe: **dois** jogadores, cada um com a sua lanterna, a sua postura e a sua zona segura. A percepção do Capítulo 36 já lida com vários estímulos; o que precisa de atenção é que tudo o que ela lê dos jogadores (luz, status) seja **estado do servidor**, e não estado local de cada cliente. A lanterna é o exemplo: no single-player, ligar a lanterna era uma ação local que concedia uma tag; no cooperativo, é um pedido ao servidor, e a tag é concedida lá.

### O estado narrativo no servidor

O `UVGNarrativeSubsystem` (Capítulo 46) é um `UGameInstanceSubsystem`: existe **um por processo**. Num jogo cooperativo, o do servidor é o dono dos fatos, e os dos clientes não podem originar fatos (a regra contra o cisma, Capítulo 64). Mas os clientes **leem** fatos: as variantes de fala, os documentos, o diário. A solução é um espelho, com a mesma forma de tudo o que a Parte IX fez: o servidor publica o estado, e os clientes o aplicam.

```cpp
// [HIPOTÉTICO, Cap. 84] Espelho dos fatos narrativos num GameState cooperativo.
UPROPERTY(ReplicatedUsing = OnRep_Facts)
FGameplayTagContainer Facts; // cópia dos fatos do UVGNarrativeSubsystem do SERVIDOR

// No servidor, no BeginPlay do GameState:
//   Narrative->OnFactChangedNative.AddWeakLambda(this, [this](FGameplayTag, bool)
//   {
//       Facts = Narrative->GetFacts(); // estado, não evento: quem entrar depois recebe o conjunto
//   });
//
// Nos clientes, OnRep_Facts entrega o conjunto ao subsistema local, que passa a responder
// HasFact/GetFacts com o espelho e recusa AddFact fora do servidor.
```

Repare na escolha: replicar o **conjunto** de fatos, e não "o fato X foi adicionado". É a lição do Capítulo 65 aplicada à narrativa: um jogador que entra no meio, ou volta de uma queda, recebe o estado inteiro, e as falas condicionadas a fatos funcionam para ele.

### Quem ouve o rádio

O rádio de Sônia (Capítulo 44) é o sistema em que a pergunta de design pesa mais que a técnica. Três opções:

| Opção | Como funciona | O que se ganha | O que se perde |
|---|---|---|---|
| **A. Os dois têm rádio** | Sônia fala com "o turno"; cada cliente toca a mesma fala, no mesmo instante do servidor | Simples; ninguém perde informação | A intimidade da Sônia falando com Helena |
| **B. Só Helena tem rádio** | A fala sai do rádio dela, como som posicional; o outro ouve se estiver perto | O rádio vira um objeto do mundo; separar-se custa informação | Quem se afasta perde a história |
| **C. Rádio por proximidade com legenda remota** | Como B, mas o outro recebe a legenda com "(rádio da Helena)" | Meio-termo | Mais regras |

Tecnicamente, as três têm a mesma base: o `UVGDialogueSubsystem` roda **no servidor** (fila, prioridades, condições por fato, memória de falas), e o que viaja é "a conversa X, nó Y, começou no instante T do servidor". Cada cliente toca a voz e a legenda localmente, sincronizado pelo relógio do servidor (o mesmo recurso do cronômetro da Arena). As **respostas** de rádio (o contexto `IMC_RespostaRadio`) são um pedido ao servidor, e o primeiro que chega vale; a legenda diz quem respondeu.

**Decisão para o experimento: A**, porque é o menor desvio do single-player e isola o que o experimento quer medir (autoridade e replicação), deixando B e C como pergunta de design registrada no `DEVLOG.md`.

### O ramo experimental do Capítulo 84

O Capítulo 84 pede um *build* de release e um **ramo experimental multiplayer cooperativo**. O escopo que este interlúdio recomenda:

1. **Só o setor 1** (a Casa de Força, o *Turno da Noite* refatorado), com dois jogadores, em *listen server*, por convite (sessão Null ou da plataforma, sem matchmaking).
2. **O que já está pronto pela Parte IX:** autoridade no dono da vida e das armas, o CMC da Vigília (corrida e *coyote*), a interação por `ServerInteract`, os avisos de morte e respawn por RPC. Nada disso precisa ser escrito de novo; a Arena o colocou nas classes da Vigília.
3. **O que o ramo implementa:** o espelho dos fatos; o diálogo no servidor com início sincronizado; a lanterna como pedido; tags de status replicadas; o estado das portas, disjuntores e setores replicado; o Diretor e a ameaça por grupo; a cinemática final disparada pelo servidor.
4. **O que fica de fora, de propósito:** entrar no meio da sessão, salvar durante o cooperativo, servidor dedicado, mais de dois jogadores, o prólogo, os setores 2 e 3 e o final.
5. **Critério de conclusão:** o setor 1 jogável do começo ao fim pelos dois, com 100 ms e 2% de perda, sem cismas (nenhum fato, porta ou objetivo diferente entre as máquinas ao final), e um inventário de quebras próprio, como o da Arena, registrado no `DEVLOG.md`.

A lição que o ramo deve produzir é a da spec: **como uma arquitetura pensada para um jogador precisa mudar quando o mundo é compartilhado**. A previsão deste interlúdio é que a maior parte das mudanças vai ser **de dono**, e não de código: sistemas que já eram donos únicos do próprio estado (Capítulos 22, 44, 45, 46) só precisam de uma guarda e de um espelho. Os sistemas que vão doer são os que misturavam decisão e apresentação.

---

## Estudos de caso

### Left 4 Dead — um Diretor para um grupo

**[FATO PÚBLICO]** O *AI Director* de Left 4 Dead (Valve, 2008), apresentado por Michael Booth na palestra *The AI Systems of Left 4 Dead* (2009), ajusta o ritmo da partida a partir de uma estimativa da intensidade vivida pelos jogadores, num jogo **cooperativo para quatro**. O Capítulo 42 o usou como referência para o Diretor da Vigília.

**[INFERÊNCIA]** Um Diretor cooperativo precisa responder a uma pergunta que o single-player não tem: **a tensão de quem?** Usar a do jogador mais tenso protege o mais frágil e pode entediar os outros; usar a média esconde quem está em apuros. A decisão da tabela de III.9 ("a do mais tenso") é a mais conservadora, e a Vigília cooperativa é o lugar para testá-la.

### GTA Online e Battlefield 4 — dois extremos de "mundo compartilhado"

Os dois apareceram ao longo do interlúdio (III.6 e III.7). Lado a lado, ilustram as duas direções de escala: o Battlefield 4 compartilha **intensamente** um mundo **limitado** (um mapa, uma partida, destruição que todos precisam ver igual); o GTA Online compartilha **frouxamente** um mundo **grande** (uma sessão, muita coisa local, atividades em instâncias). **[INFERÊNCIA]** A arquitetura de cada um segue dessa escolha de design, e não o contrário.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Servidor dedicado | Serviço *stateful* com uma instância por cliente/tenant | Cada instância simula física e IA em tempo real; o custo é por jogador-hora |
| Partida e estados | Ciclo de vida de um recurso (provisionar, ativo, drenar) | Jogadores entram e saem no meio; o estado é replicado, não consultado |
| Sessões | *Service discovery* | Anunciar e achar não é escolher |
| Matchmaking | Escalonador/alocador com múltiplos critérios | Os critérios competem e o tempo de espera relaxa todos |
| IA no servidor | *Workers* no backend, sem estado no cliente | O resultado precisa parecer contínuo nos clientes (suavização) |
| Física cosmética local | Renderização no cliente sem estado no servidor | Cada cliente vê uma versão diferente, de propósito |
| Camadas persistente/sessão/instância | Banco de dados × cache de sessão × job efêmero | A "sessão" é uma simulação em tempo real, não um cache |
| Espelho dos fatos narrativos | Réplica de leitura | O espelho é escrito só pelo servidor, e quem lê é a história |

---

## Armadilhas

- **Começar pelo matchmaking.** Sessões e serviços online sobre um jogo que não funciona em rede só mudam o lugar onde os bugs aparecem.
- **Código de apresentação em sistemas de regra.** No servidor dedicado, ele roda sem tela, e às vezes quebra.
- **Confiar na pose de animação no servidor dedicado** sem configurar a atualização dos ossos.
- **Eventos onde deveria haver estado** num jogo com entrada no meio: o jogador que chega vê um mundo incoerente.
- **Replicar o Blackboard.** O cliente precisa do que a IA mostra, não do que ela pensa.
- **Achar que dormência economiza CPU de IA.** Economiza rede. Para CPU, nível de detalhe de IA.
- **Sincronizar física cosmética.** Fragmentos e *ragdolls* de enfeite não precisam ser iguais em cada tela.
- **Tratar o mundo aberto compartilhado como o single-player com mais jogadores.** Streaming, vida ambiente e persistência precisam ser repensados para N observadores.
- **Um subsistema de jogo (`UGameInstanceSubsystem`, `UWorldSubsystem`) como dono de estado num cliente.** Cada processo tem o seu; só o do servidor é dono.
- **Deixar o design do cooperativo para depois.** "Quem ouve o rádio" não é uma questão técnica, e a resposta muda a técnica.

---

## Exercício

**Parte 1 — o servidor dedicado da Arena (2 h).** Se você tem a engine compilada do código-fonte, crie o `VigiliaServer.Target.cs`, gere o build de servidor e conecte dois clientes empacotados. Se não tem, rode a Arena com *Play As Client* e procure, no código da Vigília, todo uso de câmera, HUD, áudio ou `GetFirstLocalPlayerController` em código que pode rodar no servidor. Registre a lista.

**Parte 2 — sessões na LAN (1,5 h).** Com o Online Subsystem Null, anuncie a Arena numa LAN (`CreateSession`), procure-a de outra instância (`FindSessions`), entre (`JoinSession`) e viaje para o servidor. Documente o fluxo de *callbacks* que o esboço de III.4 omitiu.

**Parte 3 — IA na Arena (2 h).** Coloque um vigia do Capítulo 30 na Arena, hostil aos dois jogadores. Verifique que ele só pensa no servidor (um log no `BeginPlay` do `AVGAIController` mostra o modo de rede), que os clientes o veem mover-se e atirar, e crie um `enum` de apresentação replicado (patrulha, alerta, combate) que troca a cor de uma luz no capacete dele.

**Parte 4 — a tabela da Vigília (1 h).** Compare a sua tabela do desafio do Capítulo 64 com a de III.9. Para cada diferença, escreva qual das duas você levaria para o Capítulo 84, e por quê.

---

## Desafio — "O turno de dois"

Implemente, num ramo separado do projeto, o **primeiro passo** do experimento cooperativo, sem a narrativa: o setor 1 com dois jogadores, a Presença e as luzes.

1. Lanterna como pedido ao servidor, com o estado ligado/desligado replicado e a tag concedida no servidor.
2. `UVGStatusTagsComponent` replicado, para que zonas seguras e postura cheguem à Presença no servidor e à apresentação nos clientes.
3. Presença perseguindo o jogador que ela percebe mais, com a regra "dois toques" valendo para cada um.
4. Diretor e ameaça por grupo, com a tensão do mais tenso.

Jogue com 100 ms e registre um inventário de quebras próprio, como o da Arena. Compare o tamanho dele com o da Arena: as classes que a Parte IX já preparou deveriam quebrar menos que as que nunca foram revistas.

---

## Uso de IA

1. **Para desenhar a tabela de autoridade de um jogo:**
   > "Tenho um jogo single-player com estes sistemas [lista com onde cada um guarda o estado hoje]. Vou fazer uma versão cooperativa para duas pessoas com servidor autoritativo (Unreal Engine 5, listen server). Para cada sistema, proponha o dono do estado, o que os clientes precisam receber (estado ou evento) e que pergunta de DESIGN a mudança levanta. Não proponha código."

2. **Para entender o Online Subsystem:**
   > "Explique o fluxo de criar, procurar e entrar numa sessão com o Online Subsystem da Unreal Engine 5, incluindo os delegates de conclusão de cada operação e a viagem do cliente para o servidor. Aponte o que muda entre o subsistema Null e um serviço real, e diga quais partes dependem da versão da engine."

3. **Para analisar escala:**
   > "Para um jogo com [N jogadores, tipo de mapa, quantidade de NPCs, física], estime o que vai doer primeiro no servidor: banda, CPU de replicação, IA ou física. Mostre as suposições e proponha a ordem em que eu deveria medir e otimizar."

**Cuidado específico:** sobre serviços online (matchmaking, sessões de plataforma, backends), a IA tende a inventar APIs e nomes de produtos plausíveis, ou a misturar versões. Para qualquer chamada que não seja do Online Subsystem da engine, exija o link da documentação oficial e confira antes de escrever uma linha.

---

## Checklist

- [ ] Sei o que muda ao rodar em servidor dedicado (alvo de build, código sem apresentação, pose de animação, operação).
- [ ] Sei descrever os estados de partida, a entrada no meio, a reconexão e a troca de mapa.
- [ ] Sei o que é um lobby e por que o "pronto" é estado no `PlayerState`.
- [ ] Sei separar sessões (encontrar uma partida) de matchmaking (escolher quem joga com quem).
- [ ] Sei responder às sete perguntas de multiplayer + IA da spec, com as classes da Parte V.
- [ ] Sei separar física de jogo, física cosmética e estado de destruição.
- [ ] Sei explicar a diferença entre um mundo single-player e um mundo online compartilhado, em camadas.
- [ ] Tenho a tabela da Vigília cooperativa, a decisão sobre o rádio e o escopo do ramo do Capítulo 84.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Setting Up Dedicated Servers*, *Online Subsystem* (e a interface de sessões), *Online Services* (⚠️ verifique o estado na sua versão), *Travelling in Multiplayer* (viagem comum e contínua), *Replication Graph* e *Significance Manager*.
- **Documentação do Epic Online Services** (dev.epicgames.com/docs): as interfaces de sessões e de lobbies de um serviço real.
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** os capítulos sobre escalabilidade, serviços de jogo e servidores na nuvem.
- **Glenn Fiedler, *Gaffer On Games*** (gafferongames.com), e a palestra *Networking for Physics Programmers* (GDC, no GDC Vault): sincronização de física em rede.
- **Michael Booth, *The AI Systems of Left 4 Dead*** (AIIDE 2009; os slides foram publicados pela Valve), para o Diretor em grupo; e, no **GDC Vault** (gdcvault.com), as palestras da DICE sobre destruição e rede no Frostbite (confira os títulos no GDC Vault).
- **Gabriel Gambetta, "Fast-Paced Multiplayer"** (gabrielgambetta.com) e a documentação **Source Multiplayer Networking** da Valve: releia depois deste interlúdio; os fundamentos não mudam com a escala.

---

➡️ **Próximo:** [Parte X — Capítulo 69: IA como ferramenta de programação](../parte-10/cap-69-ia-ferramenta-programacao.md)

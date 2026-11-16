# Capítulo 64 — Authority

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que um FPS competitivo não pode confiar no cliente, e o que exatamente "confiar" significaria;
- separar as perguntas que o código faz sobre rede (`HasAuthority`, `IsLocallyControlled`, `GetNetMode`) e saber qual delas responde a cada decisão;
- montar a **tabela de autoridade** do Projeto Arena: de quem é cada pedaço de estado, quem pode escrevê-lo, quem o lê;
- distinguir **validação de forma** de **validação de regra**, e reconhecer o que a autoridade do servidor impede (trapaças de estado) e o que não impede (trapaças de input e de informação);
- classificar as divergências entre as cópias do mundo em atraso, previsão errada e cisma;
- proteger o estado da Vigília **no dono** (vida, armas, morte), e mover as regras da partida para o `AVGArenaGameMode`.

---

## Contexto

O inventário do Capítulo 63 começa por uma quebra que parece de rede e é, na verdade, de **autoridade**. Em Q1, o cliente atira no anfitrião, vê a vida dele cair, às vezes o vê morrer, e o anfitrião não sofreu nada. Nenhum pacote se perdeu. O problema é que uma máquina que **não tinha o direito** de mudar a vida do anfitrião mudou a cópia local dela, e ninguém a impediu.

A spec propõe a ordem *replicação → RPC → autoridade*. Este livro inverte as duas pontas de propósito. A replicação responde "como o estado chega aos outros", e o RPC responde "como o cliente pede ao servidor". As duas perguntas pressupõem uma resposta anterior: **quem escreve esse estado?** Replicar a vida sem decidir quem a escreve só espalha o Q1 para todas as máquinas. Por isso este capítulo vem primeiro, e o que ele entrega é deliberadamente incompleto: ao final, o servidor está correto e os clientes estão **cegos** (não recebem o estado) e **mudos** (não conseguem pedir nada). Os Capítulos 65 e 66 devolvem os olhos e a voz.

---

## 64.1 Por que um FPS não pode confiar no cliente

O cliente roda na máquina do jogador. O jogador controla a memória, o executável, a placa de rede e o tempo. Tudo o que o cliente afirma pode ser mentira, e a forma mais simples de entender o problema é imaginar um protocolo em que o cliente **afirma resultados**:

```text
 CLIENTE CONFIÁVEL (o protocolo ingênuo)
   Cliente A → Servidor: "acertei B na cabeça, 100 de dano"
   Cliente A → Servidor: "estou em (1200, 340, 90)"
   Cliente A → Servidor: "tenho 30 balas"
```

Cada linha é uma trapaça esperando para ser escrita. A alternativa é o cliente enviar **intenções**, e o servidor produzir os resultados:

```text
 Player
   │
   │ input
   ▼
 Client
   │
   │ request / action
   ▼
 Server
   │
   ├── validate
   ├── simulate
   ├── update state
   │
   ▼
 Replication
   │
   ├───────────┐
   ▼           ▼
 Client A    Client B
```

Esse é o diagrama da spec (3.17), e cada passo tem um significado preciso:

- **Input → request.** O cliente traduz o que o jogador fez num pedido: "andei para a frente por 16 ms", "puxei o gatilho com esta mira", "quero usar aquela estação de cura".
- **Validate.** O servidor confere se o pedido é possível: o jogador está vivo? A arma tem munição? A estação está ao alcance?
- **Simulate.** O servidor executa o pedido com as **regras dele**: move o corpo com a física dele, traça o tiro no mundo dele, aplica o dano no componente de vida dele.
- **Update state.** O resultado muda o estado autoritativo.
- **Replication.** O estado novo vai para os clientes, que ajustam as suas cópias.

> 🌉 **Ponte:** é o princípio de nunca confiar no front-end. O servidor de uma API não aceita "o total do pedido é R$ 3,00" do navegador: recebe os itens, recalcula o total e valida o estoque.
>
> 🧱 **Onde a ponte cai:** numa API, a requisição é rara e o cliente espera a resposta. Num FPS, o "pedido" de movimento chega 30 a 60 vezes por segundo por jogador, e o cliente **não pode esperar**: ele precisa simular o resultado sozinho, imediatamente, e aceitar a correção depois (Capítulo 67). Além disso, parte da requisição é o próprio input (a direção da mira), e não existe validação de forma que distinga a mira de um humano habilidoso da mira de um programa.

### O que a autoridade resolve, e o que não resolve

| Trapaça | O que o trapaceiro adultera | O servidor autoritativo resolve? |
|---|---|---|
| Velocidade, teleporte | A posição ou a velocidade que o cliente informa | **Sim.** O servidor simula o movimento e corrige (Capítulo 67) |
| Invencibilidade | A vida na memória do cliente | **Sim.** A vida do cliente é só uma cópia |
| Munição infinita, cadência maior | Contadores e timers locais | **Sim**, se o servidor conta e valida (Capítulo 66) |
| Dano aumentado | O valor de dano | **Sim.** O dano é calculado no servidor |
| Mira automática (*aimbot*) | O input: a rotação da câmera | **Não.** Uma mira perfeita é um input válido |
| Ver através de paredes (*wallhack*) | A **leitura** de dados que o cliente recebeu | **Não.** Só se atenua mandando menos dados (Capítulo 65) |
| Segurar pacotes (*lag switch*) | O tempo de envio | **Em parte.** Limites na compensação de latência (Capítulo 68) |

A regra que sai da tabela: **a autoridade do servidor resolve as trapaças de estado. Ela não resolve as trapaças de input nem as de informação.** Para essas, a indústria usa outras camadas (anti-cheat no cliente, detecção estatística no servidor, revisão de replays), que os estudos de caso abaixo citam.

---

## 64.2 As perguntas certas no código

O Capítulo 63 mostrou que cada ator tem um papel em cada máquina. O código não pergunta "qual é o meu papel?" diretamente. Ele faz uma de três perguntas, e confundi-las é a origem de metade dos bugs de rede:

| Pergunta | Função | Responde a | Use para |
|---|---|---|---|
| "Esta cópia é a autoritativa?" | `HasAuthority()` | Papel local == `ROLE_Authority` | **Decidir**: mudar estado de jogo |
| "Este pawn é controlado por um jogador desta máquina?" | `IsLocallyControlled()` (pawn), `IsLocalController()` (controller) | O controller é local | **Intenção e apresentação do dono**: input, câmera, HUD |
| "Esta máquina tem tela?" | `GetNetMode() != NM_DedicatedServer` | O modo de rede do mundo | **Apresentação para todos**: som, partículas |

As respostas, para os pawns da Arena:

| Máquina, pawn | `HasAuthority()` | `IsLocallyControlled()` | O que o código faz ali |
|---|---|---|---|
| Single-player, a jogadora | ✓ | ✓ | Tudo: decide e mostra |
| Listen server, pawn do **anfitrião** | ✓ | ✓ | Decide e mostra. **É o caso que engana** |
| Listen server, pawn do cliente | ✓ | ✗ | Decide; não lê input, não mexe em câmera nem HUD |
| Cliente, o próprio pawn | ✗ | ✓ | Lê input, pede, prevê, mostra |
| Cliente, pawn do outro | ✗ | ✗ | Só mostra |
| Servidor dedicado, qualquer pawn | ✓ | ✗ | Só decide |

Três idiomas resumem a tabela:

```cpp
if (HasAuthority())                            { /* decidir: estado de jogo */ }
if (IsLocallyControlled())                     { /* dono: input, câmera, HUD */ }
if (GetNetMode() != NM_DedicatedServer)        { /* quem tem tela: efeitos e som */ }
```

O anfitrião passa nos três. Código que testa só uma condição ("se é servidor, então não mostro efeitos") funciona no dedicado e deixa o anfitrião sem efeitos. Código que testa "se é locally controlled, então decido" funciona para o anfitrião e deixa o cliente decidindo.

### A armadilha: autoridade não é "ser o servidor"

`HasAuthority()` responde sobre **esta cópia deste ator**, não sobre a máquina. Um ator **não replicado** criado num cliente é autoritativo **naquele cliente**, porque não existe outra cópia dele.

É exatamente o que aconteceu em Q2. O `UVGWeaponComponent` cria a arma no `BeginPlay`, e o `BeginPlay` roda em todas as máquinas. No cliente, a arma criada localmente é `ROLE_Authority` no cliente. Um `if (HasAuthority())` dentro da arma **não teria impedido Q1**: a arma do cliente se considera, com razão, dona de si mesma, e dispara. O que não poderia acontecer é o efeito dela sobre um ator **replicado**, porque a cópia do anfitrião no cliente é `SimulatedProxy`.

Daí a regra que orienta o resto do capítulo: **a verificação de autoridade mora no dono do estado**, não em quem pede a mudança. A vida é do `UVGHealthComponent`; ele recusa mudanças na cópia não autoritativa. Quem chama não precisa saber de rede.

### O cliente pode escrever na própria cópia

A engine **não impede** o cliente de mudar uma propriedade replicada na cópia dele. Ela só não propaga a mudança. Pior: a replicação envia diferenças em relação ao **último valor enviado àquela conexão**. Se o servidor não mudar o valor, nada é reenviado, e a cópia do cliente fica errada indefinidamente. Uma escrita local num estado autoritativo não é corrigida "na próxima atualização". É corrigida quando o servidor mudar aquele valor de novo, o que pode não acontecer nunca.

---

## 64.3 De quem é cada pedaço de estado

Esta é a pergunta central do Projeto Arena. A tabela é o principal artefato do capítulo e será consultada em todos os seguintes.

| Estado | Quem escreve | Quem precisa ler | Como chega | Capítulo |
|---|---|---|---|---|
| Posição e velocidade do corpo | Servidor (autoritativo); o cliente dono prevê | Todos | Movimento do CMC | 67 |
| Rotação da mira (*control rotation*) | Cliente dono (é input) | Servidor (para traçar tiros); outros (inclinação do corpo) | No movimento enviado; *pitch* comprimido para os outros | 67 |
| "Quero correr", "quero mirar" | Cliente dono (intenção) | Servidor (velocidade máxima) | Flags do movimento | 67 |
| Vida e estado de vida | Servidor | Todos (HUD, corpo caindo) | Propriedade replicada | 65 |
| Arma criada e equipada | Servidor | Todos (o que aparece na mão) | Propriedade replicada | 65 |
| Munição | Servidor (verdade); o dono prevê | Só o dono | Só para o dono | 65, 67 |
| Gatilho e cadência local | Cliente dono (intenção) | Servidor valida | RPC | 66 |
| Dispersão (alfa da mira, *bloom*) | Cliente dono | Servidor valida a faixa | No pedido de tiro | 66, 67 |
| Acerto e dano | Servidor | Atirador (marcador), alvo (vida) | RPC ao atirador; vida replicada | 66, 68 |
| Coice da câmera | Cliente dono | Ninguém mais (já afeta a mira) | Local | — |
| Abates e mortes | Servidor (GameMode) | Todos | `PlayerState` replicado | 64, 65 |
| Fase e tempo da partida, vencedor | Servidor (GameMode) | Todos | `GameState` replicado | 65 |
| Regras (limite, espera de respawn) | Servidor (GameMode) | Ninguém lê diretamente | — | 64 |
| Modo de input (vivo, morto) | Cliente dono | Só ele | Local, avisado pelo servidor | 66 |
| Câmera, FOV, head bob, passos, HUD | Cada cliente | Só ele | Local | — |
| Efeitos de disparo e impacto | Cada máquina, a partir de um aviso | Todos com tela | *Multicast* | 66 |

Leia a tabela por colunas, e três padrões aparecem:

1. **Tudo o que decide o resultado é escrito pelo servidor.** Vida, munição, acerto, placar.
2. **Tudo o que é escrito pelo cliente é intenção ou apresentação.** Mira, gatilho, "quero correr", câmera. Intenções chegam ao servidor como pedidos e são validadas; apresentação nunca sai da máquina.
3. **Há estados com dois escritores**, um verdadeiro e um provisório: a posição e a munição. O cliente escreve uma versão prevista, o servidor escreve a verdadeira, e o cliente se corrige. Isso não é uma exceção à autoridade. É a **predição** (Capítulo 67), e ela só é segura porque o servidor tem a última palavra.

---

## 64.4 Validação: o servidor desconfia, com folga

"Validar" tem dois sentidos, e eles pedem respostas diferentes:

| Tipo | Pergunta | Exemplo | Se falhar |
|---|---|---|---|
| **De forma** | "Um cliente honesto mandaria isso?" | Um disparo com identificador repetido; uma direção de mira com comprimento zero | O cliente está adulterado. Desconectar é aceitável |
| **De regra** | "Isso é permitido agora, segundo o meu estado?" | Atirar sem munição; usar a estação de cura em recarga; atirar estando morto | **Recusar em silêncio.** Clientes honestos violam regras o tempo todo por causa da latência |

O segundo tipo é o que engana quem vem de backend. Um cliente honesto, com 100 ms de latência, termina a recarga **na tela dele** 50 ms antes de o servidor terminá-la, e atira. Do ponto de vista do servidor, ele atirou durante a recarga. Desconectá-lo por isso seria punir a física da internet. A Unreal reflete essa distinção no próprio mecanismo de RPC: a função `_Validate` de um RPC de servidor, quando retorna falso, **desconecta o cliente**. O Capítulo 66 usa `_Validate` só para validação de forma, e faz a validação de regra no corpo do RPC, recusando em silêncio e, quando necessário, com **folga** (uma tolerância de tempo ou distância calibrada).

---

## 64.5 Divergência: quando as cópias discordam

Num jogo em rede, as cópias **sempre** discordam um pouco. A questão é de que tipo é a discordância:

| Tipo | O que é | Exemplo | Tratamento |
|---|---|---|---|
| **Atraso** | A cópia mostra o passado | O pawn do outro jogador, no seu cliente, está onde estava há ~50 ms | Normal; disfarçado por interpolação (Capítulo 68) |
| **Previsão errada** | O cliente se antecipou, e o servidor decidiu diferente | Você correu, o servidor achou que você não podia; o corpo é puxado de volta | Corrigida pela reconciliação (Capítulo 67) |
| **Cisma** | As cópias passam a discordar para sempre | Q1: a vida do anfitrião na cópia do cliente nunca volta a bater com a do servidor | **Bug.** Nenhum mecanismo vai consertar |

Atraso e previsão errada são o preço do multiplayer, e as técnicas dos Capítulos 67 e 68 servem para escondê-los. O cisma é diferente: ele nasce quando uma máquina sem autoridade **origina** uma mudança que o servidor desconhece. A regra que previne cismas:

> **Um cliente pode estar atrasado, e pode estar errado sobre o futuro. Ele nunca pode ser a origem de uma mudança de estado autoritativo.**

---

## Estudos de caso

### Call of Duty — a killcam como ponto de vista do servidor

**[FATO PÚBLICO, observável jogando]** Desde os títulos da "era de ouro", Call of Duty mostra uma *killcam* depois da morte: um replay curto do abate visto pelo atirador. Jogadores notam com frequência que a killcam não bate com o que viram ("na minha tela eu já tinha virado a esquina").

**[INFERÊNCIA]** A killcam é reconstruída a partir dos dados que o servidor tem, e o servidor é a autoridade. Ela mostra a versão oficial, e a discordância com a tela da vítima é a divergência por **atraso** (64.5) tornada visível. Ela também funciona como ferramenta de confiança: mostra ao jogador que a morte "aconteceu" segundo alguém.

**[FATO PÚBLICO]** Em 2021, a Activision anunciou o **Ricochet**, um sistema anti-cheat para Call of Duty que inclui um *driver* em nível de kernel no PC, além de ferramentas no servidor.

**[INFERÊNCIA]** Um componente no cliente existe precisamente para a coluna "Não" da tabela de 64.1: *aimbots* e *wallhacks* não violam regras do servidor, então precisam ser detectados de outra forma.

### Battlefield 4 — detecção no servidor

**[FATO PÚBLICO]** O Battlefield 4 usou o PunkBuster e o FairFight. O FairFight é descrito por seus criadores como um sistema de detecção **no servidor**, baseado em análise estatística do comportamento dos jogadores.

**[INFERÊNCIA]** Uma abordagem estatística no servidor ataca as trapaças de input sem precisar ver a máquina do jogador: uma mira que acerta a cabeça com uma frequência ou uma rapidez impossível para humanos é suspeita, ainda que cada input isolado seja válido. A camada de autoridade (o servidor simula) e a de detecção (o servidor observa padrões) são complementares.

**Lição para a Arena:** a autoridade é a fundação, e o anti-cheat é outra disciplina, fora do escopo do livro. O que a Arena precisa garantir é que **nenhuma trapaça de estado seja possível**. As de input e de informação ficam registradas como limites conhecidos.

### Halo: Reach — distribuir a autoridade

**[FATO PÚBLICO]** Na GDC de 2011, David Aldridge, da Bungie, apresentou *I Shot You First: Networking the Gameplay of Halo: Reach* (disponível no GDC Vault), sobre como o jogo distribui e prioriza o estado de gameplay na rede.

**[INFERÊNCIA]** A palestra é útil para quebrar a ideia de que "autoridade" é uma decisão única por jogo. Num jogo real, a pergunta "quem decide?" é respondida **por tipo de estado**, exatamente como na tabela de 64.3. Assista com a tabela da Arena aberta e anote onde as decisões diferem e por quê.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Servidor autoritativo | Regras de negócio só no backend | O cliente também roda as regras, para prever; o servidor só tem a última palavra |
| `HasAuthority()` | "Sou o líder deste recurso?" (eleição de líder, *ownership* de partição) | A autoridade é por ator e definida pela topologia, não eleita |
| Validação de forma | Validação de schema, 400 Bad Request | Falhar desconecta o jogador; reserve para o que só um cliente adulterado faria |
| Validação de regra | Regras de negócio, 409/422 | Recusar em silêncio, com folga: a latência faz clientes honestos violarem regras |
| Cisma entre cópias | *Split brain*, réplicas divergentes | Não há reconciliação automática; a prevenção está na regra "cliente não origina estado" |
| Trapaça de input | Bot que usa a API com credenciais válidas | Não há CAPTCHA no meio de uma partida: só estatística e anti-cheat |

---

## Unreal Engine: o que existe

- **`AActor::HasAuthority()`**, `GetLocalRole()`, `GetRemoteRole()`: o papel de cada cópia. O papel é atribuído na criação, conforme o ator seja replicado (`bReplicates` no construtor, `SetReplicates(true)` em runtime) e quem o criou.
- **`APawn::IsLocallyControlled()`**, **`AController::IsLocalController()`**, `APlayerController::IsLocalPlayerController()`: a pergunta sobre o dono.
- **`GetNetMode()`**, `IsNetMode(NM_Client)`, `IsRunningDedicatedServer()`: a pergunta sobre a máquina.
- **O `AGameModeBase` existe só no servidor**, e por isso é o lugar natural para regras.
- **`SetOwner`/`GetOwner`**: a cadeia de posse de um ator até uma conexão. Ela decide quem pode chamar RPCs de servidor nele (Capítulo 66) e quem recebe propriedades com condição de dono (Capítulo 65).

O que a engine **não** faz:

- Não impede o código de mudar estado numa cópia não autoritativa (64.2). A proteção é do seu código, no dono do estado.
- Não diz o que é "regra" e o que é "apresentação". Essa separação é a tabela de 64.3, e ela é sua.

---

## Abordagens

Onde colocar a verificação de autoridade?

| Critério | A. Em cada chamador | **B. No dono do estado** | C. Componentes só no servidor | D. Classes separadas cliente/servidor |
|---|---|---|---|---|
| **Complexidade** | Espalhada: cada chamada lembra da rede | Uma guarda por dono | Média: criação condicional | Alta: duas hierarquias |
| **Performance** | Igual | Igual | Economiza memória nos clientes | Igual |
| **Extensibilidade** | Cada chamador novo é um bug novo | Chamadores novos são seguros por construção | Boa para sistemas sem apresentação | Ruim |
| **Manutenção** | Difícil de auditar | Fácil: "quem muda a vida?" tem uma resposta | Boa, com cuidado no que o cliente ainda precisa | Duplicação |
| **Prototipação** | Rápida até o primeiro esquecimento | Rápida | Média | Lenta |
| **Adequação à Vigília** | Contradiz o "dono único" do Capítulo 22 | **Sim**: é o "dono único" com uma regra a mais | Sim, para IA (o `AAIController` já existe só no servidor) | Não |

**Decisão: B**, com C quando a engine já o faz (controladores de IA, GameMode). O Capítulo 22 estabeleceu que o `UVGHealthComponent` é o **dono único** da vida e que ninguém mais a muda. Em rede, o dono único ganha uma pergunta extra antes de mudar qualquer coisa: "esta cópia é a autoritativa?". Os chamadores (a arma, o volume de dano, a Presença) continuam sem saber nada de rede.

---

## Implementação

### 1. A vida só muda na cópia autoritativa

🔁 **O que havia:** o `UVGHealthComponent` (Capítulo 22) aplicava qualquer dano recebido. **O problema:** no cliente, `ApplyPointDamage` sobre a cópia de outro jogador mudava a vida da cópia (Q1). **A solução:** uma guarda na entrada do pipeline e de cada mutação.

```cpp
// VGHealthComponent.h (adições)
private:
    /** Só a cópia autoritativa do dono muda a vida. Em single-player, sempre verdadeiro. */
    bool CanMutateHealth() const;
```

```cpp
// VGHealthComponent.cpp (trechos alterados)
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"

bool UVGHealthComponent::CanMutateHealth() const
{
    const AActor* Owner = GetOwner();
    return Owner && Owner->HasAuthority();
}

void UVGHealthComponent::ReceiveDamage(float Amount, const UDamageType* DamageType,
                                       AController* Instigator, AActor* Causer)
{
    // 0. Autoridade: cópias remotas não decidem. Recebem o resultado pela replicação (Cap. 65).
    if (!CanMutateHealth())
    {
        return;
    }

    // 1. Filtrar, 2. Modificar, 3. Aplicar: como no Cap. 22.
    // ...

    // 4. Anunciar (depois do estado consistente)
    OnDamaged.Broadcast(this, Report);
    OnHealthChanged.Broadcast(this);

    if (bDied)
    {
        // Antes do OnDied: quem pontua (o GameMode da Arena) precisa encontrar o corpo ainda
        // possuído. O OnDied faz o corpo avisar o controller, que o solta (Cap. 22).
        UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Actor_Died,
            Instigator ? Instigator->GetPawn() : nullptr, GetOwner());
        OnDied.Broadcast(this, Report);
    }
    else
    {
        ScheduleRegen();
    }
}

void UVGHealthComponent::Heal(float Amount)
{
    if (!CanMutateHealth() || LifeState == EVGLifeState::Dead || Amount <= 0.0f)
    {
        return;
    }
    Health = FMath::Min(Health + Amount, MaxHealth);
    OnHealthChanged.Broadcast(this);
}

void UVGHealthComponent::Revive()
{
    if (!CanMutateHealth())
    {
        return;
    }
    LifeState = EVGLifeState::Alive;
    Health = MaxHealth;
    OnHealthChanged.Broadcast(this);
}
```

A regeneração não precisa de guarda própria: ela só é agendada dentro de `ReceiveDamage`, que já passou pela guarda, e o tick que a executa só é ligado ali. No cliente, a regeneração simplesmente não acontece; a vida regenerada chega pela replicação.

### 2. Armas nascem no servidor

🔁 **O que havia:** o `UVGWeaponComponent` (Capítulos 20 e 26) criava a arma inicial no `BeginPlay`, e `GiveWeapon` podia ser chamado de qualquer lugar. **O problema:** uma arma por máquina, cada uma autoritativa onde nasceu (Q2), e a do cliente produzindo Q1. **A solução:** só o servidor cria armas. A arma vira um ator replicado, para que a criação no servidor produza uma cópia em cada cliente.

```cpp
// VGWeaponComponent.cpp (trechos alterados)
void UVGWeaponComponent::BeginPlay()
{
    Super::BeginPlay();
    // Uma arma por JOGO, não uma por máquina: o BeginPlay roda em todas elas.
    if (StartingWeaponClass && GetOwner()->HasAuthority())
    {
        GiveWeapon(StartingWeaponClass);
    }
}

AVGWeapon* UVGWeaponComponent::GiveWeapon(TSubclassOf<AVGWeapon> WeaponClass)
{
    if (!WeaponClass || !GetOwner()->HasAuthority())
    {
        return nullptr; // o cliente recebe a arma replicada; nunca a cria
    }
    // ... como no Cap. 26: SpawnActor com Params.Owner = GetOwner() e Params.Instigator = o pawn.
    //     O Owner já existia (Cap. 20); em rede ele ganha um segundo papel: a cadeia de posse
    //     até a conexão do jogador (Caps. 65 e 66).
}
```

```cpp
// VGWeapon.cpp (trechos alterados)
AVGWeapon::AVGWeapon()
{
    // ... como no Cap. 20 ...

    // A cópia autoritativa nasce no servidor; os clientes recebem cópias. O QUE replicar: Cap. 65.
    bReplicates = true;
}

void AVGWeapon::FireOnce()
{
    --AmmoInMagazine;               // 1. estado
    if (HasAuthority())
    {
        PerformShot();              // 2. efeito no mundo: só na cópia autoritativa
    }
    OnShotFeedback();               // 3. apresentação da própria arma
    OnFired.Broadcast(this);        // 4. outros sistemas (recoil, ruído para a IA, HUD)
    BroadcastAmmo();
}
```

A guarda em `FireOnce` é uma segunda linha de defesa, não a primeira. A primeira está na criação (só o servidor cria) e no dono do estado (só a cópia autoritativa da vida muda). A guarda na arma existe para que a cópia replicada no cliente, que um dia receberá input (Capítulo 66), não trace tiros por conta própria.

### 3. A morte em duas metades

🔁 **O que havia:** `AVGCharacter::HandleDied` (Capítulo 22) desligava o corpo, avisava o controller e marcava o tempo de vida do corpo. **O problema:** são duas coisas de natureza diferente. Desligar o movimento e a colisão é **corpo**, e precisa acontecer em todas as máquinas que souberem da morte. Avisar o controller e destruir o corpo depois são **decisões**, e só o servidor as toma.

```cpp
// VGCharacter.cpp (trecho alterado)
void AVGCharacter::HandleDied(UVGHealthComponent* HealthComponent, const FVGDamageReport& Report)
{
    // O CORPO reage como corpo, onde quer que a morte seja conhecida.
    // Hoje, só no servidor; a partir do Cap. 65, também nos clientes (pela replicação da vida).
    GetCharacterMovement()->DisableMovement();
    SetActorEnableCollision(false); // Simplificação: sem ragdoll (Cap. 30 fez o do inimigo)

    if (!HasAuthority())
    {
        return; // o resto é decisão
    }

    // A VONTADE reage como sessão do jogador (Cap. 22).
    if (AVGPlayerController* PC = Cast<AVGPlayerController>(GetController()))
    {
        PC->HandlePawnDied(this);
    }
    SetLifeSpan(5.0f); // destruir um ator replicado no servidor destrói as cópias nos clientes
}
```

### 4. O respawn é do servidor

🔁 **O que havia:** o jogador morto apertava "continuar", e `RequestRespawn` pedia ao GameMode (Capítulo 22). **O problema:** no cliente, `GetAuthGameMode()` é nulo (Q5). Na Arena, o respawn nem deveria depender do jogador: é uma regra da partida (3 segundos). **A solução:** o GameMode da Arena faz o respawn sozinho, e o controller sai do modo `Dead` quando ganha um corpo novo.

```cpp
// VGPlayerController.cpp (trecho alterado)
void AVGPlayerController::OnPossess(APawn* InPawn)
{
    Super::OnPossess(InPawn);
    SetViewTarget(InPawn);

    // Respawn decidido pelo servidor: quem tira o jogador do modo Dead é o corpo novo.
    // OnPossess roda no SERVIDOR: aqui só funciona para o anfitrião. O cliente: Cap. 66.
    if (IsLocalController() && GetCurrentInputMode() == EVGInputMode::Dead)
    {
        PopInputMode(EVGInputMode::Dead);
    }
}
```

`RequestRespawn` continua existindo para a Vigília single-player e ganha uma linha de aviso: se `GetAuthGameMode()` for nulo, registra no log que o pedido precisa de um RPC (o padrão do Capítulo 66). Repare na comparação com o `PopInputMode` fora de ordem do Capítulo 16: a verificação `GetCurrentInputMode() == Dead` existe porque `PopInputMode` de um modo que não está no topo dispara um `ensure`.

### 5. O placar mora no `PlayerState`

O placar precisa sobreviver à morte do pawn e ser visível a todos. O Capítulo 10 já tinha dado a resposta: `PlayerState`. Neste capítulo, ele só ganha os campos e a regra de quem escreve. A replicação é o próximo capítulo.

```cpp
// Source/Vigilia/Arena/VGArenaPlayerState.h
UCLASS()
class VIGILIA_API AVGArenaPlayerState : public APlayerState
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    int32 GetKills() const { return Kills; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    int32 GetDeaths() const { return Deaths; }

    /** Só o GameMode chama, e só no servidor. */
    void AddKill();
    void AddDeath();

private:
    int32 Kills = 0;
    int32 Deaths = 0;
};
```

```cpp
// Source/Vigilia/Arena/VGArenaPlayerState.cpp
#include "Arena/VGArenaPlayerState.h"

void AVGArenaPlayerState::AddKill()
{
    if (ensureMsgf(HasAuthority(), TEXT("Placar alterado fora do servidor.")))
    {
        ++Kills;
    }
}

void AVGArenaPlayerState::AddDeath()
{
    if (ensureMsgf(HasAuthority(), TEXT("Placar alterado fora do servidor.")))
    {
        ++Deaths;
    }
}
```

Aqui a guarda é um `ensure`, não um `return` silencioso, porque chamar `AddKill` num cliente não é uma situação de rede legítima (como o dano que chega à cópia de um proxy). É um erro de programação, e deve aparecer.

### 6. As regras da partida

O `AVGArenaGameMode` ganha as regras: ouvir as mortes, pontuar, agendar o respawn e encerrar a partida. Ele ouve o **barramento** do Capítulo 24, que no servidor recebe todas as mortes (agora publicadas só ali).

```cpp
// Source/Vigilia/Arena/VGArenaGameMode.h (versão do Cap. 64)
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameMode.h"
#include "VGArenaGameMode.generated.h"

struct FVGGameplayEvent;

UCLASS()
class VIGILIA_API AVGArenaGameMode : public AGameMode
{
    GENERATED_BODY()

public:
    AVGArenaGameMode();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    virtual bool ReadyToStartMatch_Implementation() override;
    virtual bool ReadyToEndMatch_Implementation() override;
    virtual void HandleMatchHasStarted() override;
    virtual void HandleMatchHasEnded() override;
    virtual AActor* ChoosePlayerStart_Implementation(AController* Player) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Arena", meta = (ClampMin = "1"))
    int32 PlayersToStart = 2;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Arena", meta = (ClampMin = "1"))
    int32 KillLimit = 10;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Arena", meta = (ClampMin = "10.0"))
    float MatchDuration = 300.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Arena", meta = (ClampMin = "0.0"))
    float RespawnDelay = 3.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Arena", meta = (ClampMin = "0.0"))
    float PostMatchDuration = 10.0f;

private:
    void HandleGameplayEvent(const FVGGameplayEvent& Event);
    void ScoreDeath(APawn* VictimPawn, APawn* KillerPawn);
    void RespawnNow(TWeakObjectPtr<AController> Victim);
    void GatherKills(TArray<int32>& OutKills, TArray<class AVGArenaPlayerState*>& OutStates) const;

    FDelegateHandle EventHandle;
    FTimerHandle RestartHandle;
    double MatchStartTime = 0.0; // relógio: tempo de jogo do servidor. Cap. 65 move para o GameState
};
```

```cpp
// Source/Vigilia/Arena/VGArenaGameMode.cpp (adições do Cap. 64)
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGLog.h"
#include "TimerManager.h"

void AVGArenaGameMode::BeginPlay()
{
    Super::BeginPlay();
    // O GameMode só existe no servidor; o barramento DESTE mundo recebe todas as mortes.
    if (UVGGameplayEventSubsystem* Events = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Events->OnEventNative.AddUObject(this, &AVGArenaGameMode::HandleGameplayEvent);
    }
}

void AVGArenaGameMode::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (UVGGameplayEventSubsystem* Events = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        Events->OnEventNative.Remove(EventHandle);
    }
    GetWorldTimerManager().ClearAllTimersForObject(this);
    Super::EndPlay(EndPlayReason);
}

void AVGArenaGameMode::HandleGameplayEvent(const FVGGameplayEvent& Event)
{
    if (Event.Channel.MatchesTagExact(TAG_Event_Actor_Died))
    {
        ScoreDeath(Cast<APawn>(Event.Target), Cast<APawn>(Event.Instigator));
    }
}

void AVGArenaGameMode::ScoreDeath(APawn* VictimPawn, APawn* KillerPawn)
{
    // O corpo ainda está possuído: a morte é publicada antes do OnDied (seção 1).
    AController* VictimController = VictimPawn ? VictimPawn->GetController() : nullptr;
    if (!VictimController)
    {
        return; // não é um jogador (um alvo do Galpão, por exemplo)
    }

    if (AVGArenaPlayerState* VictimState = VictimController->GetPlayerState<AVGArenaPlayerState>())
    {
        VictimState->AddDeath();
    }
    AVGArenaPlayerState* KillerState = KillerPawn ? KillerPawn->GetPlayerState<AVGArenaPlayerState>() : nullptr;
    if (KillerState && KillerPawn != VictimPawn) // suicídio (volume de dano) não pontua
    {
        KillerState->AddKill();
    }
    UE_LOG(LogVigilia, Log, TEXT("[Arena] %s morreu (por %s)."), *GetNameSafe(VictimPawn), *GetNameSafe(KillerPawn));

    if (IsMatchInProgress())
    {
        FTimerHandle Unused;
        GetWorldTimerManager().SetTimer(Unused,
            FTimerDelegate::CreateUObject(this, &AVGArenaGameMode::RespawnNow, TWeakObjectPtr<AController>(VictimController)),
            RespawnDelay, /*bLoop=*/false);
    }
}

void AVGArenaGameMode::RespawnNow(TWeakObjectPtr<AController> Victim)
{
    // O jogador pode ter saído durante a espera, e a partida pode ter acabado.
    if (Victim.IsValid() && !Victim->GetPawn() && IsMatchInProgress())
    {
        RestartPlayer(Victim.Get()); // ChoosePlayerStart decide onde (Cap. 63)
    }
}

void AVGArenaGameMode::HandleMatchHasStarted()
{
    Super::HandleMatchHasStarted(); // o AGameMode cria os pawns de quem está esperando
    MatchStartTime = GetWorld()->GetTimeSeconds();
}

void AVGArenaGameMode::GatherKills(TArray<int32>& OutKills, TArray<AVGArenaPlayerState*>& OutStates) const
{
    for (APlayerState* State : GameState->PlayerArray)
    {
        if (AVGArenaPlayerState* ArenaState = Cast<AVGArenaPlayerState>(State))
        {
            OutStates.Add(ArenaState);
            OutKills.Add(ArenaState->GetKills());
        }
    }
}

bool AVGArenaGameMode::ReadyToEndMatch_Implementation()
{
    TArray<int32> Kills;
    TArray<AVGArenaPlayerState*> States;
    GatherKills(Kills, States);
    const double Elapsed = GetWorld()->GetTimeSeconds() - MatchStartTime;
    return VGArenaRules::IsMatchOver(Kills, KillLimit, Elapsed, MatchDuration);
}

void AVGArenaGameMode::HandleMatchHasEnded()
{
    Super::HandleMatchHasEnded();

    TArray<int32> Kills;
    TArray<AVGArenaPlayerState*> States;
    GatherKills(Kills, States);
    const int32 Winner = VGArenaRules::PickWinner(Kills);
    UE_LOG(LogVigilia, Log, TEXT("[Arena] Fim de partida. Vencedor: %s"),
           States.IsValidIndex(Winner) ? *States[Winner]->GetPlayerName() : TEXT("empate"));

    // ⚠️ RestartGame faz um ServerTravel para o mesmo mapa; confira o comportamento no PIE da sua versão.
    GetWorldTimerManager().SetTimer(RestartHandle, this, &AVGArenaGameMode::RestartGame, PostMatchDuration, false);
}
```

### 7. As regras de fim, puras

```cpp
// VGArenaRules.h (adições)
namespace VGArenaRules
{
    /** A partida acabou? Alguém chegou ao limite de abates, ou o tempo esgotou. */
    inline bool IsMatchOver(TConstArrayView<int32> Kills, int32 KillLimit, double Elapsed, double Duration)
    {
        if (Elapsed >= Duration)
        {
            return true;
        }
        for (const int32 PlayerKills : Kills)
        {
            if (PlayerKills >= KillLimit)
            {
                return true;
            }
        }
        return false;
    }

    /** Quem tem mais abates. Empate no topo, ou ninguém: INDEX_NONE. */
    inline int32 PickWinner(TConstArrayView<int32> Kills)
    {
        int32 Best = INDEX_NONE;
        int32 BestKills = -1;
        bool bTie = false;
        for (int32 Index = 0; Index < Kills.Num(); ++Index)
        {
            if (Kills[Index] > BestKills)
            {
                BestKills = Kills[Index];
                Best = Index;
                bTie = false;
            }
            else if (Kills[Index] == BestKills)
            {
                bTie = true;
            }
        }
        return bTie ? INDEX_NONE : Best;
    }
}
```

```cpp
// VGArenaRulesTest.cpp (adições ao teste Vigilia.Arena.Rules)
    TestFalse(TEXT("Meio da partida"), VGArenaRules::IsMatchOver(TArray<int32>{ 3, 5 }, 10, 60.0, 300.0));
    TestTrue(TEXT("Limite atingido"), VGArenaRules::IsMatchOver(TArray<int32>{ 10, 5 }, 10, 60.0, 300.0));
    TestTrue(TEXT("Tempo esgotado"), VGArenaRules::IsMatchOver(TArray<int32>{ 3, 5 }, 10, 300.0, 300.0));
    TestEqual(TEXT("Vencedor: mais abates"), VGArenaRules::PickWinner(TArray<int32>{ 3, 5 }), 1);
    TestEqual(TEXT("Empate no topo: ninguém"), VGArenaRules::PickWinner(TArray<int32>{ 5, 5, 2 }), INDEX_NONE);
    TestEqual(TEXT("Sem jogadores: ninguém"), VGArenaRules::PickWinner(TArray<int32>()), INDEX_NONE);
```

### Explicação das decisões

- **Guarda no dono, `return` silencioso.** Um proxy no cliente receber `ApplyPointDamage` é uma situação legítima: um volume de dano colocado no nível gera eventos de sobreposição em todas as máquinas, porque a colisão roda em todas. O dono recusa sem alarde.
- **`ensure` no `PlayerState`.** O placar só tem um escritor (o GameMode), e ele só existe no servidor. Uma chamada no cliente é bug, não situação de rede.
- **A morte publicada antes do `OnDied`.** É uma mudança pequena de ordem com uma razão concreta: o `OnDied` dispara a cadeia corpo → controller → `UnPossess`. Depois dela, `GetController()` do corpo é nulo, e o GameMode não saberia de quem é a morte. O estado (vida zero, `Dead`) já está consistente antes de qualquer anúncio, como o Capítulo 4 pede.
- **O GameMode ouve o barramento**, em vez de o personagem chamar o GameMode. O `AVGCharacter` é da Vigília e não deve conhecer as regras da Arena; o barramento existe para relações muitos-para-muitos sem referência natural (Capítulo 24). No servidor, ele recebe toda morte, de qualquer fonte.
- **Respawn com `TWeakObjectPtr`.** Em 3 segundos, o jogador pode desconectar e o controller deixar de existir. O timer carrega uma referência fraca e confere antes de usar.
- **Duas proteções no respawn:** `!Victim->GetPawn()` evita criar um segundo corpo se algo já reiniciou o jogador, e `IsMatchInProgress()` evita renascer depois do fim.
- **`MatchStartTime` no GameMode**, por enquanto. O Capítulo 65 move o relógio da partida para o `GameState`, porque os clientes precisam ver o tempo restante, e o GameMode não existe neles.

---

## Projeto Arena — o servidor manda

Rode a Arena como listen server. O resultado é estranho e correto:

- **Q1 resolvida.** O cliente atira e nada acontece no mundo, nem na tela dele. A vida do anfitrião não muda em nenhuma cópia. Repare que o cliente nem consegue disparar: a arma dele agora é a cópia de uma arma criada no servidor, e o `UVGWeaponComponent` do cliente não sabe que ela existe (`Slots` está vazio no cliente). O Capítulo 65 resolve.
- **Q2 pela metade.** Existe uma arma por jogador, criada no servidor. Na janela do cliente, a arma de cada jogador aparece **parada onde o dono estava quando ela foi criada**: a cópia nasceu com a posição inicial e nunca foi anexada a nada, porque a anexação aconteceu no servidor e não foi replicada.
- **Q5 resolvida.** O anfitrião mata o cliente (com o volume de dano do Capítulo 22, ou com o fuzil) e, 3 segundos depois, o cliente renasce no ponto mais longe do anfitrião. Ninguém precisa apertar "continuar".
- **Q6 pela metade.** O placar existe no servidor, e o log mostra cada morte e o vencedor. Nenhum cliente vê nada.

O novo estado da Arena tem um nome: **cliente cego e mudo**. O servidor está correto, e os clientes não recebem o estado (cegos) nem conseguem pedir nada (mudos). Os Capítulos 65 e 66 resolvem um de cada vez.

| # | Quebra | Depois do Cap. 64 |
|---|---|---|
| Q1 | Dano fantasma | ✅ Resolvida: a vida só muda na cópia autoritativa. Mas o cliente não atira (Cap. 66) |
| Q2 | Arma em dobro | 🟡 Uma arma por jogador, no servidor; no cliente, parada no lugar errado (Cap. 65) |
| Q4 | Morte pela metade | 🟡 A morte é correta no servidor; o cliente não fica sabendo (Caps. 65 e 66) |
| Q5 | "Continuar" mudo | ✅ Resolvida na Arena: respawn automático pelo GameMode |
| Q6 | Sem placar | 🟡 Placar no servidor; invisível aos clientes (Cap. 65) |
| Q3, Q7–Q10 | — | Sem mudança |

---

## Decisões arquiteturais

1. **Autoridade antes de replicação:** decidir quem escreve antes de decidir como propagar.
2. **A guarda de autoridade mora no dono do estado** (Abordagem B). Os chamadores não sabem de rede.
3. **Tabela de autoridade da Arena (64.3)** como contrato: todo estado tem um escritor declarado.
4. **Clientes enviam intenções, nunca resultados.**
5. **Validação de forma pode desconectar; validação de regra recusa em silêncio, com folga.**
6. **Regras da partida no `AVGArenaGameMode`**, ouvindo o barramento no servidor; placar no `AVGArenaPlayerState`.
7. **Respawn automático** como regra da Arena; o fluxo "continuar" do Capítulo 22 fica para a Vigília.

---

## Armadilhas

- **Testar `HasAuthority()` dentro de um ator criado localmente.** Ele é autoritativo onde nasceu. A proteção certa está na criação e no dono do estado que ele tenta mudar.
- **Usar `IsLocallyControlled()` para decidir.** O anfitrião é local e autoritativo ao mesmo tempo; o cliente é local e não autoritativo. Decidir com essa pergunta dá ao cliente um poder que ele não tem.
- **Usar `HasAuthority()` para apresentação.** No dedicado, não há tela; no anfitrião, há. "Sou servidor, então não toco som" deixa o anfitrião surdo.
- **Escrever num estado replicado no cliente "para adiantar".** Sem um mecanismo de predição com reconciliação, isso é um cisma: o valor errado fica até o servidor mudar o seu.
- **Desconectar por regra violada.** Latência faz clientes honestos atirarem "durante a recarga" e interagirem "de longe". Recuse em silêncio, com folga.
- **Consultar o controller de um corpo morto.** Depois do `UnPossess`, ele é nulo. A ordem dos anúncios importa.
- **Achar que a autoridade resolve *aimbot* e *wallhack*.** Não resolve. Registre o limite e não prometa o contrário.
- **Guardar regras no `GameState` ou no `PlayerState` "porque os clientes precisam ver".** Os clientes precisam ver o **resultado** das regras; as regras ficam no GameMode, e o resultado vai para o estado público.

---

## Exercício

**Parte 1 — guardas no dono (1 h).** Implemente as guardas no `UVGHealthComponent` (dano, cura, reviver), a criação de armas só no servidor, `bReplicates` na arma e a morte em duas metades. Rode como listen server e confirme: o cliente atira e nada acontece, em nenhuma janela. Explique em uma frase **por que** o cliente nem consegue disparar.

**Parte 2 — regras da partida (1,5 h).** Implemente o placar no `AVGArenaPlayerState`, as regras no `AVGArenaGameMode` e as funções puras com o teste. Com `KillLimit = 3`, jogue como anfitrião contra o cliente parado e confira no log: três mortes, três respawns no ponto mais distante, fim de partida, vencedor, reinício.

**Parte 3 — a tabela (45 min).** Copie a tabela de 64.3 para o `DEVLOG.md` e acrescente três linhas que ela não tem: o estado da arma (`Holstered`/`Ready`/`Reloading`), o estado de agachado e a estação de cura que o Capítulo 65 vai criar. Para cada uma, decida quem escreve, quem lê e como chega.

**Parte 4 — servidor dedicado (30 min).** Rode com *Play As Client*. Coloque um volume de dano (Capítulo 22) na Arena e entre nele com um dos jogadores. Confirme que a morte, o placar e o respawn funcionam **sem nenhum jogador no servidor**. O volume dispara sobreposição também nos clientes: explique por que isso não causa dano em dobro.

---

## Desafio — "A Vigília a dois"

Faça, no `DEVLOG.md`, a tabela de autoridade de uma Vigília **cooperativa** hipotética, com duas pessoas no turno da noite. Para cada sistema, responda as mesmas perguntas da tabela de 64.3 (quem escreve, quem lê, como chega):

1. a Presença (percepção, Behavior Tree, ataque);
2. o Diretor de tensão (`UVGDirectorSubsystem`);
3. o rádio de Sônia (`UVGDialogueSubsystem`) e as respostas da jogadora;
4. os fatos narrativos (`UVGNarrativeSubsystem`, um `UGameInstanceSubsystem`);
5. a quest do setor 1 e os objetivos;
6. portas, disjuntores e setores energizados;
7. a lanterna e a bateria;
8. zonas seguras e tags de status.

Marque os casos em que a resposta não é óbvia, como "quem ouve o rádio quando os dois estão em salas diferentes?" e "quem responde a Sônia?". O Interlúdio III volta a essa tabela e propõe uma resposta para cada linha.

---

## Uso de IA

1. **Para auditar autoridade:**
   > "Revise este código de gameplay de Unreal Engine 5 para multiplayer cliente/servidor. Para cada mutação de estado, diga: em que máquinas ela pode executar (anfitrião de listen server, cliente, servidor dedicado), se a cópia é autoritativa ali, e se existe guarda de autoridade no DONO do estado (e não só no chamador). Aponte atores não replicados criados em BeginPlay. [código]"

2. **Para classificar trapaças:**
   > "Para um FPS 1v1 com servidor autoritativo, liste trapaças possíveis e classifique cada uma em: trapaça de estado, de input ou de informação. Para cada uma, diga se a autoridade do servidor resolve, atenua ou não resolve, e que camada adicional seria necessária. Não invente detalhes de sistemas anti-cheat comerciais."

3. **Para separar validação de forma e de regra:**
   > "Aqui estão as checagens que meu servidor faz num pedido de disparo [lista]. Separe as que um cliente honesto NUNCA violaria (forma) das que um cliente honesto pode violar por latência (regra). Para as de regra, proponha a folga mínima e como calibrá-la medindo em jogo."

**Cuidado específico:** pedidas para "deixar seguro", as IAs tendem a colocar `if (HasAuthority())` em todo lugar, inclusive em apresentação, e a sugerir desconectar o cliente a cada inconsistência. Os dois instintos são errados aqui: o primeiro deixa o anfitrião sem efeitos e o cliente sem predição, e o segundo pune a latência. Peça sempre a justificativa por máquina (anfitrião, cliente, dedicado) para cada guarda proposta.

---

## Checklist

- [ ] Sei explicar o diagrama de autoridade da spec passo a passo (input, pedido, validação, simulação, estado, replicação).
- [ ] Sei o que a autoridade do servidor resolve (trapaças de estado) e o que não resolve (input, informação).
- [ ] Sei escolher entre `HasAuthority`, `IsLocallyControlled` e `GetNetMode` para cada decisão, inclusive no anfitrião.
- [ ] Sei por que um ator criado localmente é autoritativo onde nasceu, e por que a guarda pertence ao dono do estado.
- [ ] Tenho a tabela de autoridade da Arena, com as minhas três linhas acrescentadas.
- [ ] Sei a diferença entre validação de forma (pode desconectar) e de regra (recusa em silêncio, com folga).
- [ ] Sei distinguir atraso, previsão errada e cisma.
- [ ] A Arena roda com regras no servidor: placar, respawn automático e fim de partida, inclusive no dedicado.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Actor Role and Remote Role*, a visão geral de rede (*Networking Overview*) e a página sobre *ownership* de atores e conexões.
- **Gabriel Gambetta, "Fast-Paced Multiplayer", parte I** (gabrielgambetta.com): o argumento "servidor autoritativo e clientes burros" e por que ele é o ponto de partida.
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** o capítulo sobre segurança (trapaças, validação e o que o servidor pode e não pode garantir).
- **GDC Vault** (gdcvault.com): *I Shot You First: Networking the Gameplay of Halo: Reach*, de David Aldridge (GDC 2011).

---

➡️ **Próximo:** [Capítulo 65 — Replication](cap-65-replication.md)

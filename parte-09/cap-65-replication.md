# Capítulo 65 — Replication

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o modelo de **replicação de estado** da Unreal: o servidor compara, envia diferenças por conexão, e o valor mais recente vence;
- usar `Replicated`, `ReplicatedUsing`, `GetLifetimeReplicatedProps`, `DOREPLIFETIME` e as condições `COND_*` sabendo o que cada uma custa e garante;
- prever o comportamento das notificações (`OnRep`): quando rodam, quando não rodam, em que ordem, e o que acontece com referências a atores que ainda não chegaram;
- controlar **quando** e **quanto** se replica: frequência, prioridade, quantização, *push model* e limites de banda;
- aplicar **relevância**, **dormência** e *interest management*, e estimar, com Battlefield 4 como referência, por que esses conceitos existem;
- devolver os "olhos" aos clientes da Arena: vida, morte, placar, tempo de partida, armas e uma estação de cura dormente.

---

## Contexto

O Capítulo 64 terminou com o **cliente cego e mudo**. O servidor decide tudo corretamente, e os clientes não ficam sabendo de nada: a vida do anfitrião é sempre 100 na tela do cliente, a arma do outro jogador fica parada onde ele nasceu, o placar existe só no log do servidor.

Este capítulo resolve a cegueira. É o mecanismo que a maioria das pessoas imagina quando pensa em "multiplayer na Unreal": marcar propriedades como replicadas e deixar a engine mandá-las. A parte fácil é a sintaxe. A parte que importa é o modelo por trás, porque ele tem consequências que não são óbvias para quem vem de mensageria: a replicação **não entrega eventos**, **pode pular valores**, **não garante ordem entre atores** e **não manda nada para quem não é relevante**. Cada uma dessas propriedades aparece na Arena.

A segunda metade do capítulo trata de **escala**. Dois jogadores numa sala de 30 metros não pressionam a banda de ninguém. A spec pede que se entenda por que um jogo como Battlefield 4 precisa de relevância, dormência e *interest management*, e a forma honesta de entender é fazendo a conta.

---

## 65.1 Estado, não mensagens

A replicação de propriedades funciona assim, para cada ator replicado e para cada conexão:

```text
 A cada atualização de rede do servidor (não a cada quadro):
   para cada conexão C:
     para cada ator A relevante para C, por ordem de prioridade, até acabar a banda:
       compare as propriedades de A com o ÚLTIMO estado enviado a C
       envie só o que mudou (e só as propriedades cuja condição vale para C)
       guarde o estado enviado como a nova referência para C
```

Três consequências decidem como você deve modelar o estado:

1. **O valor mais recente vence; os intermediários podem sumir.** Se a vida de um alvo vai de 100 para 40 e volta para 100 entre duas atualizações, nenhum cliente vê o 40. A replicação é **convergente**, não **completa**. Isso é ótimo para estado (a posição de um corpo, a vida) e péssimo para eventos (um disparo, um impacto, um abate).
2. **Não há confirmação por valor.** O servidor sabe que uma atualização chegou (a engine retransmite propriedades cujo pacote se perdeu), mas o seu código não recebe "o cliente viu o 40".
3. **Cada conexão tem a sua história.** O servidor guarda, por conexão, o último estado enviado. Um cliente que acabou de entrar recebe o estado **atual** de cada ator, não a sequência de mudanças.

Daí a regra que orienta toda a Parte IX:

> **Replique estado. Mande eventos por RPC, ou transforme-os em estado.**

"Transformar um evento em estado" é um padrão comum. Em vez de avisar "disparou", replica-se um **contador de disparos**: cada mudança do contador significa "houve disparos desde a última vez", e o cliente toca o efeito ao ver o número mudar. **[FATO PÚBLICO]** O antigo exemplo *ShooterGame* da Epic (UE4) usava um contador assim para os efeitos de tiro em clientes remotos (⚠️ confira no código do exemplo, se tiver acesso). O Capítulo 66 compara essa abordagem com o RPC *multicast*.

> 🌉 **Ponte:** é a diferença entre **replicação de estado** (um *snapshot* convergente, como a replicação de um banco por estado ou um CRDT) e **log de eventos** (Kafka, *event sourcing*). Quem precisa de cada evento consome o log; quem precisa do valor atual lê o estado.
>
> 🧱 **Onde a ponte cai:** a replicação da Unreal não tem log. Não existe "reprocessar a partir do offset 120". Se o seu sistema precisa de cada evento (um contador de abates, por exemplo), o evento precisa ser **acumulado no servidor** e o acumulado é que se replica: o servidor conta os abates e replica o total, nunca "houve um abate".

---

## 65.2 Propriedades replicadas na Unreal

### O mínimo

Três passos fazem uma propriedade replicar:

1. o ator replica (`bReplicates = true` no construtor, ou `SetReplicates(true)`), e, se for um componente, o componente também (`SetIsReplicatedByDefault(true)` no construtor);
2. a propriedade é marcada `UPROPERTY(Replicated)` ou `UPROPERTY(ReplicatedUsing = OnRep_Algo)`;
3. a classe registra a propriedade em `GetLifetimeReplicatedProps`, com `DOREPLIFETIME` (de `Net/UnrealNetwork.h`), chamando o `Super`.

Esquecer o passo 3 é o erro mais comum. Com o `Replicated` no `UPROPERTY` e sem o registro, a propriedade não replica, e as versões recentes da engine costumam avisar no log.

### Condições

Uma condição limita **para quem** e **quando** a propriedade é enviada:

| Condição | Envia para | Exemplo na Arena |
|---|---|---|
| `COND_None` (padrão) | Todos os clientes para os quais o ator é relevante | Vida |
| `COND_InitialOnly` | Só no primeiro envio do ator a cada conexão | Limite de abates da partida |
| `COND_OwnerOnly` | Só para a conexão dona do ator | Munição |
| `COND_SkipOwner` | Todos, menos o dono | Algo que o dono já prevê sozinho |
| `COND_SimulatedOnly` | Só para quem tem o ator como *simulated proxy* | Estado de animação que o dono calcula localmente |
| `COND_AutonomousOnly` | Só para quem tem o ator como *autonomous proxy* | Dados que só o controlador do pawn usa |

Com `DOREPLIFETIME_CONDITION(Classe, Propriedade, COND_OwnerOnly)`. A condição é avaliada por conexão, e é por isso que ela economiza banda: a munição do outro jogador nunca sai do servidor para você.

### Notificações (`OnRep`)

`ReplicatedUsing = OnRep_Health` faz a função ser chamada **no cliente** quando um valor novo chega. Seis regras, todas relevantes para a Arena:

1. **Em C++, o `OnRep` não roda no servidor.** O servidor muda o valor e precisa chamar à mão o que o `OnRep` faria (ou anunciar de outra forma). Esquecer isso deixa o **anfitrião** sem atualização de HUD. Em Blueprint, as *RepNotify* rodam também no servidor, uma diferença que confunde quem mistura os dois.
2. **O `OnRep` pode receber o valor anterior** como parâmetro (`void OnRep_Health(float OldHealth)`). Use-o para detectar **transições** ("estava vivo, agora está morto").
3. **Por padrão, só roda quando o valor recebido é diferente do valor local.** `DOREPLIFETIME_CONDITION_NOTIFY(..., REPNOTIFY_Always)` faz rodar a cada recebimento.
4. **A ordem entre `OnRep`s não é contrato.** Nem entre propriedades do mesmo ator, nem entre atores. Cada `OnRep` deve funcionar sozinho.
5. **Referências a atores podem chegar antes dos atores.** Se uma propriedade aponta para um ator que ainda não foi criado no cliente, o ponteiro chega nulo. Quando o ator chega, a engine resolve a referência e, ⚠️ nas versões que o livro conhece, chama o `OnRep` de novo. Confirme com um log na sua versão. O código deve tratar o nulo como "ainda não", e não como "nunca".
6. **No cliente, o `BeginPlay` de um ator replicado roda depois da replicação inicial.** As propriedades do primeiro envio já estão aplicadas quando o `BeginPlay` executa. Um `BeginPlay` que inicializa estado ("pente cheio") **sobrescreve** o valor que o servidor mandou.

### Estado inicial e entrada tardia

Como cada conexão recebe o estado **atual**, um jogador que entra no meio da partida, ou um ator que volta a ser relevante, recebe o que o servidor tem **agora**. Se a sua lógica de cliente reage a **transições** detectadas no `OnRep`, ela precisa funcionar também quando a primeira coisa que chega já é o estado final. Na Arena: um cliente que vê pela primeira vez um jogador que já está morto recebe `LifeState = Dead` com o valor anterior local `Alive` (o padrão), e o corpo cai. Correto, por acidente feliz do modelo de estado. Um RPC "morreu" enviado antes de o cliente chegar nunca teria sido entregue a ele.

---

## 65.3 Quando e quanto

### Frequência e prioridade

O servidor não replica um ator a cada quadro. Cada ator tem:

- **`NetUpdateFrequency`**: quantas vezes por segundo, no máximo, o servidor **considera** replicá-lo;
- **`MinNetUpdateFrequency`**: o piso, usado quando a engine reduz a frequência de atores que não mudam (frequência adaptativa, ⚠️ conforme a configuração da sua versão);
- **`NetPriority`**: o peso do ator na disputa pela banda de cada conexão. A engine ajusta a prioridade pelo tempo desde o último envio e pela relação com o que o jogador vê;
- **`ForceNetUpdate()`**: "considere este ator na próxima atualização, independentemente da frequência".

⚠️ Na UE 5.5, o acesso direto a `NetUpdateFrequency` e `MinNetUpdateFrequency` passou a ser feito por *setters* (`SetNetUpdateFrequency`, `SetMinNetUpdateFrequency`). Em versões anteriores, atribua os campos diretamente.

Há valores padrão que surpreendem. ⚠️ Nas versões que o livro conhece, o `APlayerState` nasce com uma frequência de atualização **baixa** (da ordem de uma vez por segundo) e **sempre relevante**. É razoável para nome e *ping*, e lento para um placar: o abate aparece até um segundo depois. A Arena usa `ForceNetUpdate()` ao pontuar. Confira o construtor do `APlayerState` na sua versão.

### Banda

Cada conexão tem um teto de bytes por segundo, configurável nos `.ini` (por exemplo, `ConfiguredInternetSpeed` e `ConfiguredLanSpeed` na seção do `Player`, e `MaxClientRate`/`MaxInternetClientRate` no *net driver*). Quando o que precisa ser enviado passa do teto, a engine envia os atores de maior prioridade e **adia** os outros. Um ator de prioridade baixa num servidor saturado fica "congelado" no cliente: ele não desaparece, só para de ser atualizado. Esse é o sintoma clássico de saturação, e ele se parece muito com um bug de lógica.

### Quantização

Cada byte economizado por ator é multiplicado por atores, por conexões e por atualizações. A Unreal oferece tipos quantizados para posições e vetores:

| Tipo | Precisão | Uso |
|---|---|---|
| `FVector_NetQuantize` | Inteiros (1 cm) | Pontos de impacto, posições de efeitos |
| `FVector_NetQuantize10` | 0,1 cm | Origens de disparo |
| `FVector_NetQuantize100` | 0,01 cm | Onde a precisão importa muito |
| `FVector_NetQuantizeNormal` | Componentes em [-1, 1], 16 bits | Direções, normais |

E rotações podem ser comprimidas para 16 bits por eixo (`FRotator::CompressAxisToShort`/`DecompressAxisFromShort`), que o Capítulo 66 usa no pedido de disparo. O movimento dos personagens já é quantizado pela engine.

### Push model

Comparar as propriedades de todos os atores com o último envio, a cada atualização, custa **CPU no servidor**, e esse custo cresce com atores × conexões. O *push model* inverte a lógica: a propriedade só é comparada quando o código a marca como **suja**.

```cpp
// GetLifetimeReplicatedProps
FDoRepLifetimeParams Params;
Params.bIsPushBased = true;
DOREPLIFETIME_WITH_PARAMS_FAST(AMinhaClasse, MinhaPropriedade, Params);

// onde o valor muda (no servidor)
MinhaPropriedade = NovoValor;
MARK_PROPERTY_DIRTY_FROM_NAME(AMinhaClasse, MinhaPropriedade, this);
```

Exige o módulo `NetCore` no `Build.cs`. ⚠️ O *push model* é controlado por uma configuração da engine (`net.IsPushModelEnabled`); com ele desligado, as propriedades marcadas continuam replicando pelo caminho comum. Confira o padrão da sua versão. O preço é a disciplina: uma mudança sem `MARK_PROPERTY_DIRTY` não é enviada, e esse bug é silencioso.

---

## 65.4 Relevância, dormência e interest management

### Relevância

Um ator só é replicado para uma conexão se for **relevante** para ela. Quando um ator deixa de ser relevante, o servidor **fecha o canal**, e o cliente **destrói a cópia**. Quando volta a ser relevante, o cliente cria uma cópia nova, com o estado atual, e o `BeginPlay` roda de novo nela. As regras padrão, em `AActor::IsNetRelevantFor`, consideram, entre outras coisas:

| Propriedade | Efeito |
|---|---|
| `bAlwaysRelevant` | Relevante para todos, sempre (GameState, PlayerState) |
| `bOnlyRelevantToOwner` | Só para o dono (um ator de inventário privado) |
| `bNetUseOwnerRelevancy` | Usa a relevância do dono (a arma segue o personagem) |
| `NetCullDistanceSquared` | Distância máxima ao ponto de vista do jogador; ⚠️ o padrão é da ordem de 150 m (225000000 cm²) |
| Dono e instigador | O pawn do jogador, seu controller e o que ele possui são relevantes para ele |

Para regras próprias, sobrescreva `IsNetRelevantFor`. A relevância tem um segundo efeito, além da banda: **o cliente não recebe o que não é relevante**. Um jogador do outro lado do mapa, fora da distância de corte, simplesmente não existe na memória do seu cliente. Um *wallhack* não tem como mostrar o que não chegou. Relevância é *interest management* e é, ao mesmo tempo, uma defesa parcial contra trapaças de informação (Capítulo 64).

### Dormência

Muitos atores replicados quase nunca mudam: uma porta fechada, uma caixa de munição, uma estação de cura. Mesmo sem mudanças, o servidor gasta CPU considerando-os a cada atualização. A **dormência** tira esses atores da consideração:

| `NetDormancy` | Significado |
|---|---|
| `DORM_Never` | Nunca dorme |
| `DORM_Awake` | Acordado; pode ser posto para dormir |
| `DORM_DormantAll` | Dormente para todas as conexões |
| `DORM_DormantPartial` | Dormente para algumas conexões (regra própria) |
| `DORM_Initial` | Para atores **colocados no nível**: dormente desde o início, sem nem abrir canal, porque o cliente já tem a cópia do mapa |

Para mudar um ator dormente, chame `FlushNetDormancy()`: ele é considerado na próxima atualização, envia a mudança e volta a dormir. Mudar uma propriedade de um ator dormente **sem** acordá-lo é um bug silencioso: o cliente nunca recebe a mudança.

### *Interest management*

Relevância e dormência são casos particulares de uma ideia geral: **cada cliente só precisa do que lhe interessa**. Em escala, decidir o interesse vira o problema principal, porque a abordagem ingênua (para cada conexão, para cada ator, teste a relevância) custa O(conexões × atores) por atualização.

- O **Replication Graph** é um plugin da Unreal que organiza os atores em estruturas (uma grade espacial, listas de "sempre relevantes", listas por conexão) para que o servidor não teste cada par. **[FATO PÚBLICO]** A documentação da Epic diz que ele foi desenvolvido para o Fortnite Battle Royale.
- O **Iris** é o sistema de replicação mais novo da Unreal, com uma arquitetura própria de filtragem e priorização. ⚠️ O estado dele (experimental, beta, padrão) muda entre versões. **Verifique o estado na sua versão** antes de planejar em cima dele.

---

## 65.5 Escala: a conta de Battlefield 4

A spec (3.14) pede para entender a relação entre:

```text
 Large World
      +
 Many Players
      +
 Vehicles
      +
 Physics
      +
 Destruction
      +
 Networking
```

Uma estimativa grosseira mostra por que o último item é o mais difícil. **[SIMPLIFICAÇÃO DIDÁTICA]** Os números abaixo são ilustrativos, não medidas de nenhum jogo.

**Só os jogadores, sem nenhuma otimização:**

- Estado de um jogador por atualização (posição e velocidade quantizadas, rotação comprimida, alguns bits de estado, cabeçalhos): ~24 bytes.
- 30 atualizações por segundo.
- Cada cliente recebe os outros 63: 63 × 24 B × 30 = **~45 KB/s** (~360 kbit/s).
- O servidor envia isso para 64 clientes: **~2,9 MB/s** (~23 Mbit/s) de upload.

E isso é só a posição dos jogadores. Faltam veículos (com física), projéteis, o estado de objetivos e tickets, e a destruição.

**Com relevância e prioridade:**

- Dos 63 outros jogadores, suponha que 10 estejam perto o bastante para importar a cada atualização, e que os outros 53 bastem a 5 atualizações por segundo.
- (10 × 30 + 53 × 5) × 24 B = **~13,5 KB/s** por cliente. Três vezes menos.

**E o custo que não aparece na banda:** decidir isso tudo. Com 64 conexões e alguns milhares de atores replicados, o teste ingênuo de relevância roda centenas de milhares de vezes por atualização. Dobrar o número de jogadores dobra as conexões **e** os atores que cada uma vê: o custo cresce perto do quadrado.

Daí as três lições de escala, válidas para qualquer jogo:

1. **O tráfego cresce mais rápido que o número de jogadores.** Ir de 2 para 64 não multiplica o custo por 32; multiplica por perto de mil, antes das otimizações.
2. **A otimização mais barata é não enviar.** Relevância e dormência tiram atores inteiros da conta; quantização e frequência só diminuem o tamanho do que sobrou.
3. **O custo de CPU de decidir o que enviar vira o gargalo** antes da banda. É o problema que o Replication Graph e o Iris atacam.

---

## Estudos de caso

### Battlefield 4 — 64 jogadores e a frequência de atualização

**[FATO PÚBLICO]** O Battlefield 4 (DICE, 2013) suporta partidas de 64 jogadores nas versões de PC e da geração PS4/Xbox One, com veículos terrestres, aéreos e navais, mapas grandes e eventos de destruição em escala de mapa (o *Levolution*).

**[FATO PÚBLICO]** Depois do lançamento, a DICE publicou uma série de atualizações de *netcode* para o Battlefield 4, que incluíram aumentar a frequência de atualização dos servidores. O tema foi amplamente discutido pela comunidade (confira as notas de atualização oficiais da época).

**[INFERÊNCIA]** Aumentar a frequência de atualização é a alavanca mais direta contra a sensação de "atraso" (o estado chega mais vezes), e também a mais cara: multiplica a banda e o custo de servidor da seção 65.5. Que a alavanca tenha sido ajustada depois do lançamento sugere o tamanho do *trade-off*: o valor inicial era um compromisso entre a experiência e o custo de operar milhares de servidores.

**Lição para a Arena:** frequência de atualização não é um número para "deixar no máximo". É um orçamento, e cada ator merece o seu.

### Fortnite — o Replication Graph

**[FATO PÚBLICO]** A documentação da Unreal apresenta o Replication Graph como o sistema que a Epic desenvolveu para o Fortnite Battle Royale, citando a escala do jogo: 100 jogadores por partida e dezenas de milhares de atores replicados.

**[INFERÊNCIA]** Num mapa em que a maior parte dos atores (construções, itens no chão, árvores) está longe da maioria dos jogadores, o problema não é a banda de cada conexão: é o servidor testar cada par (conexão, ator). Uma estrutura espacial reduz o teste a "o que está nas células perto de mim".

**Lição para a Arena:** para dois jogadores, a relevância padrão basta, e o Replication Graph seria só custo. A Arena usa dormência e relevância por dono, que custam uma linha cada, e deixa o Replication Graph como conhecimento para a escala.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Replicação de propriedades | Replicação de estado, CRDTs, cache invalidado | Convergente e com perda de intermediários; sem log para reprocessar |
| `OnRep` | *Change data capture*, *watchers* | Não roda no servidor em C++; ordem não é contrato |
| Condições (`COND_OwnerOnly`) | Autorização por campo, *field-level security* | Avaliada por conexão a cada envio, pelo dono do ator |
| Relevância | Assinatura por tópico, filtros de *pub/sub* | Recalculada continuamente por posição; sair da relevância **destrói** a cópia |
| Dormência | Cache com TTL infinito, *cold storage* | Esquecer o `FlushNetDormancy` deixa o cliente com o valor velho para sempre |
| Push model | Notificação explícita de mudança no lugar de *diff* | Esquecer a marcação é um bug silencioso |
| Quantização | Compressão com perda, tipos menores no protocolo | O cliente e o servidor podem ver valores diferentes; o Capítulo 66 trata disso no tiro |

---

## Unreal Engine: o que existe

- **Replicação de propriedades** com `Replicated`/`ReplicatedUsing`, `GetLifetimeReplicatedProps`, `DOREPLIFETIME`, `DOREPLIFETIME_CONDITION`, `DOREPLIFETIME_CONDITION_NOTIFY`, `DOREPLIFETIME_WITH_PARAMS_FAST`.
- **Componentes replicados** (`SetIsReplicatedByDefault`, `SetIsReplicated`), com as mesmas regras de propriedades.
- **Referências replicadas** a atores e componentes estáveis, resolvidas quando o alvo chega.
- **Controle de envio**: `NetUpdateFrequency`, `MinNetUpdateFrequency`, `NetPriority`, `ForceNetUpdate`, tipos `FVector_NetQuantize*`, *push model*.
- **Relevância e dormência**: `IsNetRelevantFor`, `bAlwaysRelevant`, `bOnlyRelevantToOwner`, `bNetUseOwnerRelevancy`, `NetCullDistanceSquared`, `NetDormancy`, `FlushNetDormancy`.
- **Escala**: Replication Graph (plugin) e Iris (⚠️ verifique o estado na sua versão).
- **Análise**: `stat net` no console e a análise de rede do Unreal Insights (*Networking Insights*). ⚠️ Os argumentos para capturar o rastro de rede mudam entre versões; siga a página de *Networking Insights* da documentação.

O que **não** existe: uma garantia de entrega de valores intermediários, uma ordem entre atores, ou uma forma automática de saber que "o cliente viu" um valor. Para isso, há RPCs (Capítulo 66).

---

## Abordagens

Como os clientes ficam sabendo de uma morte?

| Critério | A. Só a vida; o cliente deduz a morte de `Health <= 0` | **B. Vida e estado de vida, cada um com `OnRep`** | C. Vida replicada + RPC *multicast* "morreu" |
|---|---|---|---|
| **Complexidade** | Mínima | Baixa | Média: dois caminhos que podem discordar |
| **Performance** | 4 bytes | 5 bytes | Vida + uma mensagem confiável |
| **Extensibilidade** | Fraca: "morto" vira uma regra espalhada pelos clientes | Boa: a transição é explícita e única | Boa para efeitos, frágil para estado |
| **Manutenção** | Regra duplicada no servidor e nos clientes | O dono decide; os clientes reagem | Entrada tardia e relevância não recebem o evento |
| **Prototipação** | Imediata | Imediata | Média |
| **Adequação à Arena** | Contradiz "o dono decide" | **Sim** | Não: um cliente que vê o corpo depois nunca recebe o "morreu" |

**Decisão: B.** O `LifeState` já existia no Capítulo 22 como a transição única "de `Dead` nada volta a morrer". Replicá-lo faz a decisão continuar com o dono, e o `OnRep` com o valor anterior reconstrói o evento a partir do estado. A abordagem C parece natural para quem pensa em eventos e falha exatamente no caso da seção 65.2: o cliente que chega depois. Efeitos de morte que precisam ser vistos **no momento** (um som, uma câmera) podem somar um RPC à abordagem B, sem substituir o estado.

---

## Implementação

### 1. `Build.cs`

```csharp
// Source/Vigilia/Vigilia.Build.cs (adição do Cap. 65)
PublicDependencyModuleNames.Add("NetCore"); // push model (MARK_PROPERTY_DIRTY)
```

### 2. A vida replicada

🔁 **O que havia:** depois do Capítulo 64, a vida só mudava no servidor, e os clientes nunca sabiam. **A solução:** o componente replica, a vida e o estado de vida também, e as notificações reconstroem os anúncios do Capítulo 22 nas cópias.

```cpp
// VGHealthComponent.h (adições e alterações do Cap. 65)
public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

private:
    UFUNCTION()
    void OnRep_Health(float OldHealth);

    UFUNCTION()
    void OnRep_LifeState(EVGLifeState OldLifeState);

    UPROPERTY(VisibleInstanceOnly, ReplicatedUsing = OnRep_Health, Category = "Vigilia|Health")
    float Health = 100.0f;

    UPROPERTY(VisibleInstanceOnly, ReplicatedUsing = OnRep_LifeState, Category = "Vigilia|Health")
    EVGLifeState LifeState = EVGLifeState::Alive;
```

```cpp
// VGHealthComponent.cpp (adições do Cap. 65)
#include "Net/UnrealNetwork.h"

UVGHealthComponent::UVGHealthComponent()
{
    // ... como no Cap. 22 ...
    SetIsReplicatedByDefault(true);
}

void UVGHealthComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME(UVGHealthComponent, Health);
    DOREPLIFETIME(UVGHealthComponent, LifeState);
    // MaxHealth não replica: é dado de classe, igual em todas as máquinas.
}

void UVGHealthComponent::OnRep_Health(float OldHealth)
{
    // Na cópia, o relatório é PARCIAL: quanto caiu e quanto sobrou. Quem causou, o cliente não sabe.
    if (Health < OldHealth)
    {
        FVGDamageReport Report;
        Report.Amount = OldHealth - Health;
        Report.HealthAfter = Health;
        OnDamaged.Broadcast(this, Report);
    }
    OnHealthChanged.Broadcast(this);
}

void UVGHealthComponent::OnRep_LifeState(EVGLifeState OldLifeState)
{
    // A TRANSIÇÃO reconstrói o evento. Funciona também para quem vê o corpo pela primeira vez.
    if (OldLifeState == EVGLifeState::Alive && LifeState == EVGLifeState::Dead)
    {
        FVGDamageReport Report;
        Report.HealthAfter = 0.0f;
        OnDied.Broadcast(this, Report); // AVGCharacter::HandleDied: só a metade "corpo" roda aqui (Cap. 64)
    }
    OnHealthChanged.Broadcast(this);
}
```

A metade "corpo" do `HandleDied` (Capítulo 64) agora roda nos clientes, e o corpo do jogador morto para e deixa de colidir em todas as telas. A regeneração, que só roda no servidor, chega aos clientes como uma sequência de `OnRep_Health` crescentes, na frequência de atualização do pawn. Para uma barra de vida, isso basta.

### 3. O placar replicado, com *push model*

```cpp
// Source/Vigilia/Arena/VGArenaPlayerState.h (versão do Cap. 65)
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerState.h"
#include "VGArenaPlayerState.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGArenaScoreChangedSignature, AVGArenaPlayerState*, PlayerState);

UCLASS()
class VIGILIA_API AVGArenaPlayerState : public APlayerState
{
    GENERATED_BODY()

public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    int32 GetKills() const { return Kills; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    int32 GetDeaths() const { return Deaths; }

    /** Só o GameMode chama, e só no servidor. */
    void AddKill();
    void AddDeath();

    /** Em todas as máquinas: no servidor, à mão; nos clientes, pelo OnRep. */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Arena")
    FVGArenaScoreChangedSignature OnScoreChanged;

private:
    UFUNCTION()
    void OnRep_Score();

    void NotifyScoreChanged();

    UPROPERTY(ReplicatedUsing = OnRep_Score)
    int32 Kills = 0;

    UPROPERTY(ReplicatedUsing = OnRep_Score)
    int32 Deaths = 0;
};
```

```cpp
// Source/Vigilia/Arena/VGArenaPlayerState.cpp (versão do Cap. 65)
#include "Arena/VGArenaPlayerState.h"

#include "Net/Core/PushModel/PushModel.h"
#include "Net/UnrealNetwork.h"

void AVGArenaPlayerState::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);

    FDoRepLifetimeParams Params;
    Params.bIsPushBased = true; // só comparadas quando marcadas: o placar muda poucas vezes por minuto
    DOREPLIFETIME_WITH_PARAMS_FAST(AVGArenaPlayerState, Kills, Params);
    DOREPLIFETIME_WITH_PARAMS_FAST(AVGArenaPlayerState, Deaths, Params);
}

void AVGArenaPlayerState::AddKill()
{
    if (!ensureMsgf(HasAuthority(), TEXT("Placar alterado fora do servidor.")))
    {
        return;
    }
    ++Kills;
    MARK_PROPERTY_DIRTY_FROM_NAME(AVGArenaPlayerState, Kills, this);
    NotifyScoreChanged();
}

void AVGArenaPlayerState::AddDeath()
{
    if (!ensureMsgf(HasAuthority(), TEXT("Placar alterado fora do servidor.")))
    {
        return;
    }
    ++Deaths;
    MARK_PROPERTY_DIRTY_FROM_NAME(AVGArenaPlayerState, Deaths, this);
    NotifyScoreChanged();
}

void AVGArenaPlayerState::NotifyScoreChanged()
{
    ForceNetUpdate();               // o PlayerState atualiza devagar por padrão (seção 65.3)
    OnScoreChanged.Broadcast(this); // o servidor não recebe OnRep: o anfitrião depende desta linha
}

void AVGArenaPlayerState::OnRep_Score()
{
    OnScoreChanged.Broadcast(this);
}
```

### 4. O estado da partida no `GameState`

O relógio da partida sai do GameMode (Capítulo 64) e vai para o `GameState`, porque os clientes precisam vê-lo. O GameState não replica "segundos restantes" (um valor que muda continuamente). Ele replica **o instante em que a partida acaba**, no relógio do servidor, uma vez só, e cada cliente calcula o restante localmente com `GetServerWorldTimeSeconds()`, que o `AGameStateBase` mantém sincronizado de forma aproximada.

```cpp
// Source/Vigilia/Arena/VGArenaGameState.h (versão do Cap. 65)
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameState.h"
#include "VGArenaGameState.generated.h"

/** O resultado da partida como UM valor: muda de "não decidido" para "decidido" mesmo num empate. */
USTRUCT(BlueprintType)
struct FVGArenaResult
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly, Category = "Arena")
    bool bDecided = false;

    /** Nulo = empate. */
    UPROPERTY(BlueprintReadOnly, Category = "Arena")
    TObjectPtr<APlayerState> Winner;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FVGArenaResultSignature, const FVGArenaResult&, Result);

UCLASS()
class VIGILIA_API AVGArenaGameState : public AGameState
{
    GENERATED_BODY()

public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    int32 GetKillLimit() const { return KillLimit; }

    /** Segundos até o fim, no relógio do servidor (estimado nos clientes). 0 fora da partida. */
    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    float GetRemainingTime() const;

    UFUNCTION(BlueprintPure, Category = "Vigilia|Arena")
    const FVGArenaResult& GetResult() const { return Result; }

    // Escritos só pelo GameMode, no servidor.
    void SetKillLimit(int32 InKillLimit) { KillLimit = InKillLimit; }
    void StartMatchClock(float Duration);
    void SetResult(APlayerState* Winner);

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Arena")
    FVGArenaResultSignature OnResultDecided;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    UFUNCTION()
    void OnRep_Result();

    void DrawNetDebug();

    UPROPERTY(Replicated)
    int32 KillLimit = 0;

    UPROPERTY(Replicated)
    double MatchEndServerTime = 0.0;

    UPROPERTY(ReplicatedUsing = OnRep_Result)
    FVGArenaResult Result;

    FTimerHandle NetDebugHandle;
};
```

```cpp
// Source/Vigilia/Arena/VGArenaGameState.cpp (adições do Cap. 65)
#include "Net/UnrealNetwork.h"

void AVGArenaGameState::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME_CONDITION(AVGArenaGameState, KillLimit, COND_InitialOnly); // definido antes de qualquer conexão
    DOREPLIFETIME(AVGArenaGameState, MatchEndServerTime);
    DOREPLIFETIME(AVGArenaGameState, Result);
}

float AVGArenaGameState::GetRemainingTime() const
{
    if (MatchEndServerTime <= 0.0)
    {
        return 0.0f;
    }
    return static_cast<float>(FMath::Max(0.0, MatchEndServerTime - GetServerWorldTimeSeconds()));
}

void AVGArenaGameState::StartMatchClock(float Duration)
{
    // Relógio: tempo de jogo do SERVIDOR. Nos clientes, GetServerWorldTimeSeconds() o estima.
    MatchEndServerTime = GetWorld()->GetTimeSeconds() + Duration;
}

void AVGArenaGameState::SetResult(APlayerState* Winner)
{
    Result.bDecided = true;
    Result.Winner = Winner;
    OnRep_Result(); // o servidor não recebe OnRep
}

void AVGArenaGameState::OnRep_Result()
{
    if (Result.bDecided)
    {
        OnResultDecided.Broadcast(Result);
    }
}
```

🔁 O GameMode passa a escrever no GameState:

```cpp
// VGArenaGameMode (alterações do Cap. 65)
virtual void InitGameState() override; // declaração em protected

void AVGArenaGameMode::InitGameState()
{
    Super::InitGameState();
    if (AVGArenaGameState* Arena = GetGameState<AVGArenaGameState>())
    {
        Arena->SetKillLimit(KillLimit); // antes de qualquer cliente: COND_InitialOnly basta
    }
}

void AVGArenaGameMode::HandleMatchHasStarted()
{
    Super::HandleMatchHasStarted();
    GetGameState<AVGArenaGameState>()->StartMatchClock(MatchDuration); // MatchStartTime sai do GameMode
}

bool AVGArenaGameMode::ReadyToEndMatch_Implementation()
{
    TArray<int32> Kills;
    TArray<AVGArenaPlayerState*> States;
    GatherKills(Kills, States);
    const double Elapsed = MatchDuration - GetGameState<AVGArenaGameState>()->GetRemainingTime();
    return VGArenaRules::IsMatchOver(Kills, KillLimit, Elapsed, MatchDuration);
}

// Em HandleMatchHasEnded, depois de escolher o vencedor:
//   GetGameState<AVGArenaGameState>()->SetResult(States.IsValidIndex(Winner) ? States[Winner] : nullptr);
```

### 5. Armas replicadas no componente

🔁 **O que havia:** o `UVGWeaponComponent` (Capítulo 26) guardava `Slots` e `CurrentSlot` como estado local, e `EquipSlot` anexava e equipava diretamente. **O problema:** no cliente, `Slots` fica vazio (Q2), e a arma replicada não sabe onde se prender. **A solução:** o inventário e o índice equipado replicam; uma única função, idempotente, aplica em cada máquina o que o estado replicado diz.

```cpp
// VGWeaponComponent.h (adições e alterações do Cap. 65)
public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

private:
    UFUNCTION()
    void OnRep_Slots();

    UFUNCTION()
    void OnRep_CurrentSlot(int32 PreviousSlot);

    /** Aplica nesta máquina a arma que o estado replicado diz estar equipada. Idempotente. */
    void ApplyEquippedWeapon();

    UPROPERTY(ReplicatedUsing = OnRep_Slots)
    TArray<TObjectPtr<AVGWeapon>> Slots;

    UPROPERTY(ReplicatedUsing = OnRep_CurrentSlot)
    int32 CurrentSlot = INDEX_NONE;

    /** O que ESTA máquina já anexou e equipou (não replicado). */
    UPROPERTY(Transient)
    TObjectPtr<AVGWeapon> AppliedWeapon;
```

```cpp
// VGWeaponComponent.cpp (alterações do Cap. 65)
#include "Net/UnrealNetwork.h"

UVGWeaponComponent::UVGWeaponComponent()
{
    // ... como no Cap. 26 ...
    SetIsReplicatedByDefault(true);
}

void UVGWeaponComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME(UVGWeaponComponent, Slots);
    DOREPLIFETIME(UVGWeaponComponent, CurrentSlot);
}

void UVGWeaponComponent::EquipSlot(int32 SlotIndex)
{
    // Decisão: só no servidor (o pedido do cliente é o Cap. 66).
    if (!GetOwner()->HasAuthority() || !Slots.IsValidIndex(SlotIndex) || SlotIndex == CurrentSlot)
    {
        return;
    }
    CurrentSlot = SlotIndex;
    ApplyEquippedWeapon(); // o servidor não recebe OnRep
}

void UVGWeaponComponent::OnRep_Slots()
{
    ApplyEquippedWeapon(); // a arma pode chegar DEPOIS do índice: a referência se resolve aqui
}

void UVGWeaponComponent::OnRep_CurrentSlot(int32 PreviousSlot)
{
    ApplyEquippedWeapon();
}

void UVGWeaponComponent::ApplyEquippedWeapon()
{
    AVGWeapon* Wanted = GetCurrentWeapon();
    if (Wanted == AppliedWeapon)
    {
        return; // OnReps repetidos não reequipam
    }
    if (AppliedWeapon)
    {
        AppliedWeapon->Holster(); // cancela recarga/equipar locais (Cap. 20)
    }
    bWantsToAim = false; // trocar desfaz a mira (Cap. 26)
    AimAlpha = 0.0f;

    AppliedWeapon = Wanted;
    if (!Wanted)
    {
        return; // referência ainda não resolvida: o OnRep_Slots chama de novo quando a arma chegar
    }
    // Anexar é apresentação: cada máquina prende a SUA cópia ao SEU corpo.
    Wanted->AttachToComponent(GetAttachParent(), FAttachmentTransformRules::SnapToTargetNotIncludingScale);
    Wanted->Equip();
    ApplyWeaponOffset();
    OnWeaponEquipped.Broadcast(Wanted);
}
```

`GiveWeapon` (servidor) continua criando a arma e a coloca em `Slots`. Quando é a primeira, chama `EquipSlot`. A anexação que o Capítulo 20 fazia dentro de `GiveWeapon` sai de lá: quem anexa, agora, é `ApplyEquippedWeapon`, em cada máquina.

### 6. A arma: munição só para o dono

```cpp
// VGWeapon.h (adições e alterações do Cap. 65)
public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

private:
    UFUNCTION()
    void OnRep_Ammo();

    UPROPERTY(ReplicatedUsing = OnRep_Ammo)
    int32 AmmoInMagazine = 0;

    UPROPERTY(ReplicatedUsing = OnRep_Ammo)
    int32 ReserveAmmo = 0;
```

```cpp
// VGWeapon.cpp (alterações do Cap. 65)
#include "Net/UnrealNetwork.h"

AVGWeapon::AVGWeapon()
{
    // ... como no Cap. 20 ...
    bReplicates = true;              // Cap. 64
    bNetUseOwnerRelevancy = true;    // relevante quando o dono é: a arma segue o personagem
    SetReplicatingMovement(false);   // cada máquina anexa a sua cópia (ApplyEquippedWeapon)
}

void AVGWeapon::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME_CONDITION(AVGWeapon, AmmoInMagazine, COND_OwnerOnly); // ninguém mais precisa
    DOREPLIFETIME_CONDITION(AVGWeapon, ReserveAmmo, COND_OwnerOnly);
}

void AVGWeapon::BeginPlay()
{
    Super::BeginPlay();
    if (!ensureMsgf(Data, TEXT("%s sem UVGWeaponData."), *GetName()))
    {
        return;
    }
    // ... estatísticas efetivas, como no Cap. 26 (dados: iguais em todas as máquinas) ...

    // No cliente, o BeginPlay roda DEPOIS da replicação inicial: inicializar aqui apagaria
    // a munição que o servidor acabou de mandar.
    if (HasAuthority())
    {
        AmmoInMagazine = EffectiveStats.GetMagazineSize();
        ReserveAmmo = FMath::Clamp(InitialReserveAmmo, 0, Data->MaxReserveAmmo);
    }
    BroadcastAmmo();
}

void AVGWeapon::OnRep_Ammo()
{
    BroadcastAmmo(); // a HUD do dono escuta OnAmmoChanged (Cap. 20)
}
```

A munição replicada só para o dono é uma solução **provisória**, e o Capítulo 67 a substitui. Com latência, o dono atira, o servidor decrementa, e a HUD do dono só vê o número cair um RTT depois. Para o dono, a munição precisa ser prevista.

### 7. A estação de cura: dormência

A Arena ganha um ator novo, pequeno de propósito: uma estação de cura na parede, que cura 50 pontos e fica 20 segundos indisponível. Ela existe para ensinar dormência: passa a maior parte da partida sem mudar.

```cpp
// Source/Vigilia/Arena/VGArenaHealthStation.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Interaction/VGInteractable.h"
#include "VGArenaHealthStation.generated.h"

/** Estação de cura da Arena. Colocada no nível; dormente até ser usada. */
UCLASS()
class VIGILIA_API AVGArenaHealthStation : public AActor, public IVGInteractable
{
    GENERATED_BODY()

public:
    AVGArenaHealthStation();

    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

    virtual bool CanInteract_Implementation(AActor* Interactor) const override;
    virtual void Interact_Implementation(AActor* Interactor) override;
    virtual FText GetInteractionPrompt_Implementation(AActor* Interactor) const override;

protected:
    /** Apresentação: luz verde/vermelha, som. Roda em todas as máquinas. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Arena")
    void OnAvailabilityChanged(bool bNowAvailable);

    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<UStaticMeshComponent> Mesh;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Arena", meta = (ClampMin = "0.0"))
    float HealAmount = 50.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Arena", meta = (ClampMin = "1.0"))
    float Cooldown = 20.0f;

private:
    UFUNCTION()
    void OnRep_Available();

    void SetAvailable(bool bNewAvailable);

    UPROPERTY(ReplicatedUsing = OnRep_Available)
    bool bAvailable = true;

    FTimerHandle CooldownHandle;
};
```

```cpp
// Source/Vigilia/Arena/VGArenaHealthStation.cpp
#include "Arena/VGArenaHealthStation.h"

#include "Combat/VGHealthComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Net/UnrealNetwork.h"
#include "TimerManager.h"

#define LOCTEXT_NAMESPACE "VGArena"

AVGArenaHealthStation::AVGArenaHealthStation()
{
    Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
    SetRootComponent(Mesh);

    bReplicates = true;
    NetDormancy = DORM_Initial; // colocada no nível: o cliente já a tem do mapa, sem canal até mudar
}

void AVGArenaHealthStation::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME(AVGArenaHealthStation, bAvailable);
}

bool AVGArenaHealthStation::CanInteract_Implementation(AActor* Interactor) const
{
    // Roda no cliente (prompt) e no servidor (decisão), com os mesmos dados replicados.
    const UVGHealthComponent* Health = Interactor ? Interactor->FindComponentByClass<UVGHealthComponent>() : nullptr;
    return bAvailable && Health && Health->IsAlive() && Health->GetHealthRatio() < 1.0f;
}

void AVGArenaHealthStation::Interact_Implementation(AActor* Interactor)
{
    if (!HasAuthority() || !CanInteract_Implementation(Interactor))
    {
        return; // o dono do estado da estação decide (Cap. 64)
    }
    Interactor->FindComponentByClass<UVGHealthComponent>()->Heal(HealAmount);
    SetAvailable(false);
    GetWorldTimerManager().SetTimer(CooldownHandle,
        FTimerDelegate::CreateUObject(this, &AVGArenaHealthStation::SetAvailable, true), Cooldown, false);
}

FText AVGArenaHealthStation::GetInteractionPrompt_Implementation(AActor* Interactor) const
{
    return bAvailable ? LOCTEXT("HealUse", "Usar estação de cura") : LOCTEXT("HealWait", "Recarregando");
}

void AVGArenaHealthStation::SetAvailable(bool bNewAvailable)
{
    FlushNetDormancy();   // acorda: a mudança sai na próxima atualização, e o ator volta a dormir
    bAvailable = bNewAvailable;
    OnRep_Available();    // o servidor não recebe OnRep
}

void AVGArenaHealthStation::OnRep_Available()
{
    OnAvailabilityChanged(bAvailable);
}

#undef LOCTEXT_NAMESPACE
```

Neste capítulo, só o anfitrião consegue usar a estação: o `TryInteract` do cliente chama `Interact` na cópia dele, que recusa por não ter autoridade. O pedido do cliente é o RPC do Capítulo 66.

### Explicação das decisões

- **Replicar o instante final, não o tempo restante.** Um valor que muda continuamente gastaria banda a cada atualização e chegaria sempre atrasado. Um instante fixo chega uma vez, e o cliente faz a conta. O erro do relógio estimado do cliente é pequeno para um cronômetro de partida (não seria para um tiro; o Capítulo 68 trata disso).
- **O resultado como estrutura.** Num empate, o vencedor é nulo, o mesmo valor inicial. Uma propriedade `Winner` sozinha nunca mudaria, e nenhum `OnRep` rodaria. A estrutura muda de `bDecided = false` para `true` em qualquer caso.
- **`COND_InitialOnly` no limite de abates.** O valor é definido em `InitGameState`, antes de qualquer conexão, e nunca mais muda. Depois do primeiro envio, a engine não precisa compará-lo.
- **Push model só no `PlayerState`.** É a classe com mudanças raras e muitas leituras. No resto da Arena, o custo de comparação é irrelevante, e a disciplina do `MARK_PROPERTY_DIRTY` não se paga.
- **`ApplyEquippedWeapon` idempotente e chamada de dois `OnRep`s.** O índice e a lista podem chegar em qualquer ordem, e a referência à arma pode chegar nula. A função aplica o que o estado diz agora e não faz nada se já aplicou.
- **Anexação local, sem replicar movimento da arma.** A arma é presa à câmera do dono, um componente que já existe em cada cópia do pawn. Replicar a transformação de um ator anexado gastaria banda para dizer o que cada máquina sabe calcular.
- **`bNetUseOwnerRelevancy`** na arma: sem ele, a arma teria a própria regra de distância, e poderia sumir antes ou depois do personagem.
- **`DORM_Initial` na estação.** Como o ator é colocado no nível, o cliente já tem a cópia do mapa, com o mesmo estado inicial. Até alguém usar a estação, nenhum canal é aberto para ela.

---

## Projeto Arena — os clientes enxergam

Rode a Arena como listen server, com 100 ms e 2% de perda.

- **Q2 resolvida.** Cada jogador vê a arma do outro na mão do outro. Com `vg.Debug.Net`, confira que a arma é `Simulated` nos clientes.
- **Q4 pela metade.** O anfitrião mata o cliente: o corpo cai em todas as telas, a vida chega a zero na HUD do cliente. Mas o cliente continua no modo de input `Exploration`, com a câmera presa a um corpo que não responde, porque o controller dele não ficou sabendo que precisa entrar no modo `Dead`. Isso é um **evento** para um jogador específico, e é RPC (Capítulo 66).
- **Q6 resolvida.** O placar (`WBP_ArenaPlacar`: o nome e os abates de cada `PlayerState` do `GameState`, mais o tempo restante e o limite) aparece igual nas duas janelas. Repare no atraso de até um RTT entre o abate e o número.
- **A estação de cura** muda de cor nas duas janelas quando o anfitrião a usa.
- **O cliente continua mudo.** Ele vê tudo e não consegue fazer nada: não atira, não usa a estação.

| # | Quebra | Depois do Cap. 65 |
|---|---|---|
| Q1 | Dano fantasma | ✅ (Cap. 64). O cliente ainda não atira |
| Q2 | Arma em dobro | ✅ Resolvida: armas criadas no servidor, inventário replicado, anexação local |
| Q4 | Morte pela metade | 🟡 Corpo e vida corretos em todas as telas; falta o modo `Dead` no cliente (Cap. 66) |
| Q6 | Sem placar | ✅ Resolvida: `PlayerState` e `GameState` replicados |
| Q3, Q7–Q10 | — | Sem mudança |

---

## Decisões arquiteturais

1. **Replicar estado; eventos por RPC ou transformados em estado.**
2. **Transições reconstruídas no `OnRep`** com o valor anterior (morte), para que entrada tardia e relevância funcionem.
3. **O servidor anuncia à mão** o que o `OnRep` anuncia nos clientes (o anfitrião depende disso).
4. **Relógio da partida como instante final** no relógio do servidor; o restante é calculado em cada cliente.
5. **Resultado como estrutura** com `bDecided`, para que o empate também notifique.
6. **Condições por necessidade:** munição só para o dono; limite de abates só no envio inicial.
7. **Aplicação idempotente** do estado replicado em funções chamadas por mais de um `OnRep`.
8. **Push model onde as mudanças são raras** (`PlayerState`); dormência para atores do nível que quase não mudam.

---

## Armadilhas

- **Esquecer o `GetLifetimeReplicatedProps`.** O `UPROPERTY(Replicated)` sozinho não replica.
- **Esquecer o `SetIsReplicatedByDefault(true)` num componente.** O ator replica, o componente não, e as propriedades dele nunca saem do servidor.
- **Esperar `OnRep` no servidor.** Em C++, ele não roda lá. O anfitrião fica sem HUD.
- **Inicializar estado replicado no `BeginPlay` do cliente.** Ele roda depois da replicação inicial e apaga o que o servidor mandou.
- **Tratar o ponteiro nulo de um `OnRep` como "nunca".** Pode ser "ainda não": o ator referenciado não chegou.
- **Depender da ordem dos `OnRep`s.** Nem dentro do mesmo ator, nem entre atores.
- **Replicar um valor que pode não mudar e esperar notificação.** Empate com `Winner` nulo; "voltou para o mesmo valor". Use estrutura, contador ou `REPNOTIFY_Always`.
- **Replicar eventos como propriedades.** Valores intermediários somem. Um "último dano recebido" replicado perde metade dos danos de uma rajada.
- **Mudar ator dormente sem `FlushNetDormancy`.** O cliente nunca recebe.
- **Mudar propriedade *push-based* sem `MARK_PROPERTY_DIRTY`.** Idem.
- **Achar que um ator "congelado" no cliente é bug de lógica.** Pode ser saturação de banda ou prioridade baixa. Olhe `stat net` e o Networking Insights antes de depurar o código.
- **Guardar estado no cliente num ator que sai da relevância.** A cópia é destruída e recriada; o que era local se perde.

---

## Exercício

**Parte 1 — vida e morte (1 h).** Replique o `UVGHealthComponent` como na seção 2. Confirme que o corpo cai em todas as janelas. Depois, com o cliente olhando para outro lado, mate o anfitrião com o volume de dano, ande até o corpo e confirme que ele já está caído quando aparece (o caso do estado inicial).

**Parte 2 — placar e partida (1,5 h).** Implemente o `PlayerState` com *push model*, o `GameState` com o relógio e o resultado, e o `WBP_ArenaPlacar`. Teste o empate: com `MatchDuration = 30` e ninguém pontuando, o resultado precisa aparecer nas duas janelas. Comente a linha do `ForceNetUpdate` e meça, com um cronômetro na tela, quanto o placar do cliente passa a atrasar.

**Parte 3 — armas (1,5 h).** Replique o inventário como na seção 5 e a munição como na seção 6. Coloque um `UE_LOG` em `ApplyEquippedWeapon` com o nome da arma (ou "nula") e o modo de rede. Com 200 ms de latência, observe a ordem em que `OnRep_Slots` e `OnRep_CurrentSlot` rodam no cliente, e se a arma chega nula em algum deles.

**Parte 4 — dormência e banda (1 h).** Implemente a estação de cura. Com `stat net` e o Networking Insights, compare o tráfego da estação com `DORM_Initial` e com `DORM_Never`. Depois, remova o `FlushNetDormancy()` de `SetAvailable` e descreva o sintoma.

---

## Desafio — "Cem latas"

Coloque 100 barris replicados na Arena (um ator simples com uma propriedade `Health` replicada e uma malha), espalhados por uma área maior: estenda a Arena com um pátio de 200 × 200 m.

1. Meça o tráfego por cliente e o custo de rede no servidor (Networking Insights) com todos os barris acordados, sem nenhuma otimização.
2. Aplique, uma de cada vez, medindo depois de cada uma: `DORM_Initial`; `NetCullDistanceSquared` de 60 m; `NetUpdateFrequency` de 2 Hz.
3. Faça a conta da seção 65.5 para os seus números: quantos barris um servidor com o seu teto de banda aguentaria, com e sem as otimizações?
4. Escreva no `DEVLOG.md` qual otimização deu mais resultado e por quê, à luz da lição "a otimização mais barata é não enviar".

---

## Uso de IA

1. **Para revisar replicação:**
   > "Revise a replicação deste ator de Unreal Engine 5. Para cada propriedade replicada, diga: se está registrada em GetLifetimeReplicatedProps; se a condição é adequada; se o servidor anuncia à mão o que o OnRep anuncia no cliente; se algum OnRep depende de ordem ou de referência a ator que pode chegar nula; e se algum valor que deveria ser evento está sendo replicado como estado. [código]"

2. **Para estimar banda:**
   > "Estou estimando o tráfego de rede de um jogo com [N jogadores, M atores dinâmicos, taxas de atualização]. Monte a conta de bytes por segundo por cliente e de upload do servidor, primeiro sem otimizações e depois com relevância por distância e frequências diferentes por categoria de ator. Mostre as suposições de tamanho por atualização e diga quais dominam o total."

3. **Para escolher entre estado e evento:**
   > "Para cada uma destas informações de um FPS multiplayer [lista: disparo, impacto, abate, vida, munição, equipar arma, fim de partida], diga se deve ser estado replicado, RPC, ou estado derivado de contador, considerando entrada tardia de jogadores, atores que saem e voltam da relevância e perda de valores intermediários."

**Cuidado específico:** a IA costuma afirmar números padrão da engine (frequências, distâncias de corte, tetos de banda) com confiança, e eles mudam entre versões e projetos. Peça a fonte e confira no código da engine ou no `.ini` do projeto. O mesmo vale para o *push model* e o Iris: o estado deles muda, e a IA pode descrever uma versão que não é a sua.

---

## Checklist

- [ ] Sei explicar por que a replicação é convergente e perde valores intermediários, e o que isso proíbe.
- [ ] Sei fazer uma propriedade replicar em ator e em componente, com condição e notificação.
- [ ] Conheço as seis regras do `OnRep` (servidor, valor anterior, quando roda, ordem, referência nula, `BeginPlay` depois).
- [ ] Sei usar frequência, prioridade, `ForceNetUpdate`, quantização e *push model*, e o custo de cada um.
- [ ] Sei o que relevância e dormência fazem, inclusive a destruição da cópia ao sair da relevância.
- [ ] Sei fazer a conta de banda de um jogo de 64 jogadores e explicar por que o custo cresce perto do quadrado.
- [ ] A Arena mostra vida, morte, placar, tempo, armas e a estação de cura corretamente nos clientes.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Replicate Actor Properties* (inclui condições e RepNotify), *Actor Relevancy*, *Actor Network Dormancy*, *Replication Graph*, *Iris Replication System* e *Networking Insights*.
- **Gabriel Gambetta, "Fast-Paced Multiplayer"** (gabrielgambetta.com): a parte sobre interpolação de entidades ajuda a entender o que o cliente faz com o estado que chega.
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** os capítulos sobre replicação de objetos e sobre escalabilidade (relevância e prioridade).
- **GDC Vault** (gdcvault.com): palestras sobre a arquitetura de rede de jogos de grande escala; procure as da DICE sobre o Frostbite e as da Epic sobre a replicação do Fortnite (confira os títulos no GDC Vault).

---

➡️ **Próximo:** [Capítulo 66 — RPC](cap-66-rpc.md)

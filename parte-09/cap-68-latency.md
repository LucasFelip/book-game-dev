# Capítulo 68 — Latency

## Objetivo

Ao final deste capítulo você deve conseguir:

- usar com precisão o vocabulário da latência: *ping*, RTT, latência de ida, *jitter*, perda de pacotes, banda, *tick rate*, tick do servidor, tick do cliente, *snapshot*;
- decompor, em milissegundos, o caminho de um disparo, do clique do jogador até a tela do adversário, sem latência e com 50 a 100 ms;
- explicar interpolação e extrapolação, e o que a Unreal faz com os personagens dos outros jogadores;
- explicar *hit registration* em FPS (hitscan, projétil, validação no servidor, predição, estado histórico, rebobinamento) e os custos de cada escolha;
- analisar o caso de **dois jogadores que atiram quase ao mesmo tempo**: por que cada um "vê" que atirou primeiro e como o servidor decide;
- implementar uma **compensação de latência simplificada** no servidor da Arena, com histórico curto de hitboxes e rebobinamento, e dizer onde ela falha.

---

## Contexto

Resta uma quebra no inventário, e é a mais famosa do multiplayer competitivo. Em **Q10**, o cliente mira num adversário que corre de lado, atira, vê o rastro terminar no corpo dele, e o tiro não conta. O Capítulo 67 deixou a causa evidente: cliente e servidor calculam **exatamente** a mesma direção de tiro, e o tiro do servidor passa **atrás** do alvo. O servidor traça contra a posição **atual** do alvo; o cliente mirou na posição que **via**, e o que ele via era o passado.

Este capítulo fecha a Parte IX. Ele começa pelo vocabulário (a spec, na seção 3.18, pede cada termo) e pelo exemplo que a spec escolheu: o jogador aperta o botão de atirar. Depois trata de *hit registration* (3.19), com o caso dos dois jogadores que atiram quase ao mesmo tempo. Termina com a implementação que a Unreal não oferece pronta: o servidor **rebobina** os alvos para o instante que o atirador via.

---

## 68.1 O vocabulário da latência

| Termo | Definição | Na Arena |
|---|---|---|
| **RTT** (*round-trip time*) | Tempo de ida e volta de uma mensagem | O que a emulação do PIE simula com "100 ms" |
| **Ping** | Na prática dos jogos, o RTT medido pelo jogo | `APlayerState` guarda uma estimativa |
| **Latência de ida** | Metade do RTT, **se** a rota for simétrica (nem sempre é) | O atraso entre o clique e a chegada ao servidor |
| **Jitter** | A variação da latência de um pacote para o outro | Faz pedidos regulares chegarem em grupos (Capítulo 66) |
| **Perda de pacotes** | Fração de pacotes que não chega | Exige retransmissão (confiáveis) ou tolerância (não confiáveis) |
| **Banda** | Quantos bytes por segundo cabem na conexão | O teto que a relevância administra (Capítulo 65) |
| **Tick rate do servidor** | Quantas vezes por segundo o servidor simula e envia | Configurável no *net driver* (`NetServerMaxTickRate`) |
| **Tick do cliente** | A taxa de quadros do cliente | 60 FPS = 16,7 ms por quadro |
| **Snapshot** | Uma fotografia do estado do mundo enviada ao cliente | A Unreal não envia fotografias inteiras: envia diferenças por ator e por conexão (Capítulo 65) |

A latência de um pacote tem componentes que se somam: **propagação** (a distância física, limitada pela velocidade da luz na fibra), **serialização** (pôr os bits no fio), **filas** (roteadores, a fila de envio do próprio jogo) e **processamento**. Em jogos, há um componente a mais, que costuma ser esquecido: o **alinhamento ao tick**. Uma mensagem que chega ao servidor logo depois de um tick espera o próximo; uma atualização que fica pronta logo depois de um envio espera a próxima atualização de rede. Com o servidor a 30 Hz, cada espera custa de 0 a 33 ms.

A pergunta que este capítulo repete é: **em que relógio estou?** O servidor tem o dele, cada cliente tem o seu, e cada informação que um cliente desenha foi verdadeira num instante diferente do relógio do servidor.

---

## 68.2 O jogador aperta atirar

A spec descreve o caminho assim:

```text
 Input
  ↓
 Client
  ↓
 Network
  ↓
 Server
  ↓
 Game Simulation
  ↓
 Network
  ↓
 Other Clients
```

Com números. Suponha um cliente a 60 FPS, um servidor a 30 Hz, e uma rota com 100 ms de RTT (50 de ida). Os valores abaixo são **[SIMPLIFICAÇÃO DIDÁTICA]**: faixas plausíveis para estas suposições, não medidas.

| Etapa | No sofá (PES) | Online, 100 ms de RTT |
|---|---|---|
| O clique é lido no próximo quadro do cliente | 0–17 ms | 0–17 ms |
| O cliente prevê: som, clarão, coice, rastro (Capítulo 67) | mesmo quadro | mesmo quadro: **o atirador vê o disparo na hora** |
| O pedido espera o próximo envio de rede | — | 0–17 ms |
| A rede leva o pedido ao servidor | — | ~50 ms |
| O pedido espera o próximo tick do servidor | — | 0–33 ms |
| O servidor valida, traça e aplica o dano | ~0 | ~1 ms |
| O resultado espera a próxima atualização de rede | — | 0–33 ms |
| A rede leva o resultado aos clientes | — | ~50 ms (com a latência **de cada** cliente) |
| O cliente aplica, suaviza e desenha | — | 17 ms + suavização |
| **O atirador vê o marcador de acerto** | ~1 quadro | **~120–220 ms depois do clique** |
| **A vítima vê a própria vida cair** | ~1 quadro | **~120–220 ms depois do clique do atirador** (com a latência do atirador **mais** a dela) |

Três conclusões saem da tabela:

1. **O atirador sente a latência só onde não há predição.** Por isso o Capítulo 67 prevê tudo o que é dele.
2. **A latência total não é o ping.** Os ticks somam dezenas de milissegundos. Dobrar o *tick rate* do servidor reduz duas linhas da tabela; não reduz a rede.
3. **Cada jogador vive num passado diferente.** A vítima recebe a notícia da própria morte bem depois de, segundo o servidor, ela ter acontecido. Nesse intervalo, ela continuou se movendo e atirando na tela dela.

O efeito que importa para Q10 é o terceiro, visto pelo lado de quem mira: **o adversário que o atirador vê na tela está onde estava há algum tempo**, a soma da latência de ida do servidor até ele, das esperas de tick e da suavização. Mirando nessa imagem, o atirador acerta o passado.

---

## 68.3 Interpolação e extrapolação

O cliente recebe o estado dos outros jogadores em atualizações discretas (a 30 Hz, a cada 33 ms, quando chegam). Entre elas, precisa desenhar alguma coisa. Há duas famílias de resposta.

**Interpolação.** O cliente desenha os outros jogadores **um pouco no passado**, sempre entre duas atualizações que já recebeu. O movimento fica suave e correto (é o caminho que o jogador realmente fez), ao custo de um atraso fixo e conhecido. **[FATO PÚBLICO]** A documentação *Source Multiplayer Networking*, da Valve, descreve esse modelo: o cliente guarda as atualizações recebidas e desenha as entidades com um atraso de interpolação (por padrão, 100 ms naquele texto), o que tolera a perda de uma atualização sem o movimento travar.

**Extrapolação** (*dead reckoning*). O cliente desenha os outros jogadores **no presente estimado**, projetando a última posição recebida com a última velocidade. Não há atraso artificial, mas, quando o jogador muda de direção, a projeção erra e precisa ser corrigida. Funciona bem para o que tem inércia (veículos, aviões) e mal para pessoas que mudam de direção a cada passo.

**O que a Unreal faz com os personagens.** Os *simulated proxies* (Capítulo 67) recebem posição, rotação e velocidade replicadas. Entre as atualizações, o CMC **simula** o proxy localmente com a última velocidade (uma forma de extrapolação), e, quando a atualização seguinte chega e discorda, **suaviza** a correção ao longo de um tempo curto, conforme o `NetworkSmoothingMode` (desligado, linear ou exponencial) e os tempos de suavização configurados no componente. ⚠️ Os nomes e os valores padrão dessas propriedades mudam entre versões; confira no `CharacterMovementComponent.h`.

A consequência para o rebobinamento é importante, e a seção de implementação volta a ela: na Unreal, o proxy **não** é desenhado com um atraso fixo e conhecido, como no modelo da Valve. O que o atirador vê é a última atualização recebida, um pouco projetada e um pouco suavizada. O "quanto no passado" precisa ser **estimado e calibrado**, não lido de uma configuração.

---

## 68.4 *Hit registration*

*Hit registration* é o sistema que decide **se um tiro acertou**. Num FPS em rede, ele precisa conciliar três verdades: o que o atirador viu, o que a vítima viu e o que o servidor sabe.

### Hitscan e projétil

| | Hitscan | Projétil |
|---|---|---|
| **O que é** | O tiro é um traço instantâneo (Capítulo 27) | O tiro é um objeto que voa (Capítulo 28) |
| **Onde a latência dói** | No **alvo**: o atirador mira no passado | No **projétil**: o atirador o vê sair na hora, e os outros, depois |
| **Abordagens comuns** | Rebobinar os alvos no servidor (esta seção) | Projétil autoritativo no servidor + projétil "de enfeite" previsto no cliente, conciliados; ou criar o projétil no servidor "adiantado" pela latência do atirador |

A Arena só tem hitscan. O projétil em rede é o exercício opcional deste capítulo.

### As peças

- **Validação no servidor.** O servidor decide, sempre (Capítulo 64). O cliente nunca diz "acertei".
- **Predição no cliente.** O cliente mostra o disparo na hora (Capítulo 67), e o efeito no alvo espera a confirmação.
- **Estado histórico.** O servidor guarda, por um tempo curto, onde cada alvo esteve.
- **Rebobinamento** (*rewind*). Ao receber um disparo, o servidor estima **o instante que o atirador via**, coloca os alvos onde estavam naquele instante, traça o tiro, e devolve os alvos ao presente.
- **Interpolação.** O instante estimado raramente coincide com um registro do histórico; o servidor interpola entre os dois registros vizinhos.

### A fórmula

**[FATO PÚBLICO]** A documentação da Valve resume o cálculo do instante a rebobinar como "tempo atual do servidor − latência do pacote − interpolação de visão do cliente". A ideia é justamente a de 68.2: o servidor desconta do presente o tempo que o disparo levou para chegar e o atraso com que o atirador via os outros jogadores.

Na Arena:

```text
 instante rebobinado = agora (servidor) − RTT/2 do atirador − atraso estimado dos proxies
                       limitado a [agora − rebobinamento máximo, agora]
```

### Quem paga

A compensação de latência é uma decisão de **justiça**, não só de engenharia. Ela **favorece o atirador**: o que ele viu e mirou é o que conta. O custo vai para a vítima: ela já tinha se escondido atrás da parede **na tela dela**, e morre mesmo assim, porque, no instante que o atirador via, ela ainda estava exposta. **[INFERÊNCIA]** É a consequência direta do modelo descrito pela Valve, e a origem da queixa "morri atrás da parede" que aparece em comunidades de qualquer shooter online.

O limite de rebobinamento decide até onde essa justiça vai. Sem limite, um jogador com 400 ms de latência acertaria alvos que já estão escondidos há meio segundo. Com um limite de 250 ms, ele passa a ter de mirar à frente dos alvos, e o custo da latência alta volta para quem a tem.

> 🌉 **Ponte:** rebobinar é uma **consulta *as-of*** num banco temporal ("qual era a posição de B às 10:00:00,250?"), sobre um histórico com retenção curta. A decisão do servidor é como julgar transações com *timestamps* de clientes sem relógio confiável: você estima, limita e aceita que haverá injustiça nas bordas.
>
> 🧱 **Onde a ponte cai:** num banco temporal, o passado é imutável e a consulta é barata. Aqui, a "consulta" acontece dezenas de vezes por segundo, o resultado mata alguém **no presente**, e a pessoa morta tinha uma visão do passado diferente da do atirador. Não existe uma resposta correta para "quem estava certo"; existe uma regra, escolhida por design, que todos aceitam.

---

## 68.5 Dois jogadores atiram quase ao mesmo tempo

O caso que a spec pede, com números. O jogador A tem 30 ms de RTT; o jogador B, 120 ms. Os dois estão se vendo, e os dois clicam **no mesmo instante do relógio de parede**, T = 0. Servidor a 30 Hz (ticks em 0, 33, 67, 100 ms). **[SIMPLIFICAÇÃO DIDÁTICA]**

```text
 Tempo (ms)   Cliente A (30 ms)            Servidor                       Cliente B (120 ms)
      0       clica; vê o rastro em B      .                              clica; vê o rastro em A
     15       .                            chega o tiro de A              .
     33       .                            tick: processa A; rebobina B   .
                                           ~15 ms + atraso → acerto → B MORRE
     60       .                            chega o tiro de B              .
     67       .                            tick: B está morto → RECUSADO  .
     48       vê o marcador de acerto      .                              .
     93       .                            .                              descobre que morreu
```

Na tela de A: ele atirou, viu o marcador 48 ms depois, e B caiu. Na tela de B: **ele também atirou**, viu o rastro terminar em A, e 93 ms depois descobriu que estava morto, sem que A tenha sofrido nada. Os dois atiraram "ao mesmo tempo"; para cada um, o próprio disparo veio primeiro, porque cada um viu o seu na hora (predição) e o do outro com atraso.

O servidor resolveu com duas regras simples: **processa na ordem de chegada**, e **morto não atira**. Elas dão uma vantagem clara a quem tem latência menor: o pedido de A chegou antes. É a regra da Arena, a mais simples e defensável.

### O que mais o servidor poderia fazer

| Regra | O que acontece no caso acima | Custo |
|---|---|---|
| **Ordem de chegada, morto não atira** (Arena) | A vence | Favorece latência baixa nos empates |
| **Troca** (*trade*): aceitar o tiro de um morto se ele foi disparado **antes** da morte, segundo a estimativa do servidor | Os dois morrem | Estimar o instante do disparo de B (chegada − RTT/2 de B) tem o erro do *jitter*; a vítima de A vê A morrer "depois de já ter vencido" |
| **Sem compensação de latência** | Os dois traçam contra o presente: se B estava parado, A acerta; se se moviam, ambos podem errar | Todo mundo precisa mirar à frente pela própria latência |

**[INFERÊNCIA]** Shooters comerciais combinam essas regras de formas diferentes, e jogadores costumam perceber trocas ("morremos os dois") em uns jogos e não em outros. A escolha é de design, e precisa ser **consistente**: o pior resultado é uma regra que o jogador não consegue prever.

Há uma armadilha técnica na troca, além da de design: o pedido de B chega pela **arma** de B, e o servidor fez `UnPossess` no corpo de B quando ele morreu. A cadeia de posse da arma até a conexão de B acabou (Capítulo 66), e ⚠️ o RPC pode ser descartado. Uma regra de troca precisa adiar o `UnPossess` ou mandar o disparo por um ator que o jogador continua possuindo (o `PlayerController`). É o desafio deste capítulo.

---

## Estudos de caso

### Valve, Source — a compensação de latência documentada

**[FATO PÚBLICO]** A documentação *Source Multiplayer Networking* (wiki de desenvolvedores da Valve) descreve o modelo de rede da engine Source: o servidor simula em ticks, envia *snapshots* aos clientes, os clientes interpolam as entidades com um atraso, preveem as próprias ações, e o servidor aplica **compensação de latência** ao processar comandos de disparo, movendo os jogadores para onde estavam no instante que o atirador via e restaurando-os depois. O texto acompanha o artigo de Yahn Bernier, *Latency Compensating Methods in Client/Server In-game Protocol Design and Optimization*, um clássico do assunto.

**[INFERÊNCIA]** O que torna o modelo da Valve fácil de compensar é o **atraso de interpolação fixo e conhecido**: o servidor sabe exatamente quanto no passado o cliente desenha. A Unreal não tem esse atraso fixo para personagens (68.3), e por isso a Arena precisa estimá-lo e calibrá-lo.

**Lição para a Arena:** a implementação deste capítulo é a ideia da Valve adaptada a um modelo de proxy diferente. A diferença de modelo vira um parâmetro de calibração.

### Apex Legends — a taxa de atualização em público

**[FATO PÚBLICO]** Em 2021, a Respawn publicou um texto técnico sobre os servidores de Apex Legends, explicando que eles atualizam a 20 Hz e discutindo por que aumentar essa taxa não resolveria, sozinho, as queixas dos jogadores sobre "netcode" (confira o texto no blog oficial da EA/Respawn).

**[INFERÊNCIA]** O argumento casa com a tabela de 68.2: o *tick rate* reduz as esperas de alinhamento, mas não a latência de rede, nem a injustiça inerente à compensação, nem os picos de jitter e perda. Também casa com a conta de banda do Capítulo 65: num jogo com dezenas de jogadores, cada hertz a mais multiplica o custo de cada servidor.

### Call of Duty — "morri atrás da parede"

**[FATO PÚBLICO, observável jogando]** É comum, em Call of Duty, morrer depois de ter alcançado a cobertura e ver, na *killcam*, o próprio personagem ainda exposto no momento do disparo.

**[INFERÊNCIA]** É a compensação de latência favorecendo o atirador, vista pela vítima. A *killcam* (Capítulo 64) mostra o ponto de vista que o servidor usou para julgar o disparo, que é o do atirador, no passado dele.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| RTT, jitter, perda | Métricas de rede de qualquer sistema distribuído | Orçamento em dezenas de ms, e sentido pelo jogador a cada quadro |
| Tick do servidor | *Batching* com intervalo fixo | Cada espera de tick soma à latência percebida |
| Interpolação de proxies | *Buffering* de mídia (vídeo ao vivo atrasado alguns segundos) | O atraso é de dezenas de ms e afeta a mira |
| Extrapolação | Previsão de séries temporais | Erra em cada mudança de direção, e o erro é visível |
| Estado histórico + rebobinamento | Banco temporal, consulta *as-of* | A consulta decide uma morte no presente |
| Limite de rebobinamento | Janela de aceitação de *timestamps* | É uma decisão de justiça entre jogadores |
| Ordem de chegada no empate | Ordem de commit num log | Dá vantagem a quem tem latência menor |

---

## Unreal Engine: o que existe

- **Ping por jogador** no `APlayerState`. ⚠️ A API mudou ao longo das versões (o valor comprimido antigo, e um acessor em milissegundos nas versões recentes, `GetPingInMilliseconds()`); confira na sua.
- **Relógio do servidor estimado** nos clientes: `AGameStateBase::GetServerWorldTimeSeconds()` (usado pelo cronômetro da Arena no Capítulo 65).
- **Suavização dos proxies** no CMC (`NetworkSmoothingMode` e tempos de suavização).
- **Tick rate do servidor** configurável no *net driver* (`NetServerMaxTickRate`, nos `.ini`).
- **Emulação de rede** no PIE e por comandos de console. ⚠️ Os nomes dos comandos mudaram entre versões; as opções de *Play* do editor são o caminho mais estável.

O que **não** existe: **compensação de latência para hitscan**. A engine não guarda histórico de posições de personagens para julgar disparos. É a implementação deste capítulo.

---

## Abordagens

Como o servidor julga o disparo do cliente?

| Critério | A. Traçar no presente (Caps. 66–67) | B. O cliente diz quem acertou; o servidor confia | C. O cliente diz quem acertou; o servidor confere com tolerância geométrica | **D. Rebobinar no servidor, instante estimado pelo servidor** | E. Rebobinar, instante informado pelo cliente (relógio sincronizado) |
|---|---|---|---|---|---|
| **Complexidade** | Mínima | Mínima | Média | Média: histórico + teste geométrico | Alta: sincronização de relógio |
| **Performance** | 1 traço | 0 traços | 1–2 traços | 1 traço + teste contra N cápsulas | Igual a D |
| **Justiça** | O atirador mira à frente pela própria latência | Total para o atirador | Boa | Boa até o limite; erro do *jitter* | A melhor, por instante exato |
| **Segurança** | Total | Nenhuma | Média: a tolerância é a brecha | Boa: o servidor escolhe o instante | O cliente escolhe o instante (dentro da janela): trapaça de *backtrack* |
| **Prototipação** | Pronta | Imediata | Média | Média | Lenta |
| **Adequação à Arena** | É Q10 | Contradiz o Cap. 64 | Parcial | **Sim** | Excesso para o laboratório |

**Decisão: D.** O instante é estimado pelo servidor com o que ele mede (a latência do atirador) e um atraso de proxy calibrável, e limitado a uma janela máxima. A abordagem E é mais precisa e abre uma trapaça conhecida: um cliente que informa o instante pode escolher, dentro da janela, o momento em que o alvo estava mais exposto.

Há uma segunda escolha, de implementação: **como** colocar os alvos no passado.

| | Mover os colisores reais para trás, traçar, devolver | **Testar o raio contra uma cópia geométrica das hitboxes** |
|---|---|---|
| **Fidelidade** | Usa a *physics asset* real, osso a osso | Cápsula do corpo + esfera da cabeça |
| **Risco** | Mover componentes dispara sobreposições, atualiza física e navegação, e precisa ser desfeito com cuidado | Nenhum efeito colateral no mundo |
| **Custo** | Mover e restaurar cada alvo por disparo | Matemática de raio contra cápsula |
| **Adequação** | **[FATO PÚBLICO]** É o modelo descrito pela Valve | **A Arena**: simples, sem efeitos colaterais |

**Decisão: a cópia geométrica**, com os limites registrados: hitboxes grosseiras (sem braços e pernas separados), e o multiplicador de cabeça passa a vir da esfera da cabeça, e não do material físico do Capítulo 27.

---

## Implementação

### 1. As regras geométricas, puras

```cpp
// Source/Vigilia/Combat/VGLagCompRules.h
#pragma once

#include "CoreMinimal.h"

/** Um instante do histórico de um alvo: hitboxes simplificadas, em espaço do mundo. */
struct FVGHitboxFrame
{
    double Time = 0.0;                        // relógio: tempo de jogo do SERVIDOR
    FVector BodyCenter = FVector::ZeroVector;  // cápsula vertical (a cápsula de um ACharacter não inclina)
    double BodyHalfHeight = 0.0;
    double BodyRadius = 0.0;
    FVector HeadCenter = FVector::ZeroVector;
    double HeadRadius = 0.0;
};

enum class EVGHitboxPart : uint8
{
    None,
    Body,
    Head
};

namespace VGLagCompRules
{
    /** Distância ao longo do raio até entrar na esfera; < 0 se não acerta. Dir normalizada. */
    inline double RaySphere(const FVector& Origin, const FVector& Dir, double MaxDist,
                            const FVector& Center, double Radius)
    {
        const FVector ToOrigin = Origin - Center;
        const double B = FVector::DotProduct(ToOrigin, Dir);
        const double C = ToOrigin.SizeSquared() - Radius * Radius;
        if (C > 0.0 && B > 0.0)
        {
            return -1.0; // fora da esfera e se afastando
        }
        const double Discriminant = B * B - C;
        if (Discriminant < 0.0)
        {
            return -1.0; // passa ao lado
        }
        const double T = FMath::Max(0.0, -B - FMath::Sqrt(Discriminant)); // 0 = origem dentro
        return T <= MaxDist ? T : -1.0;
    }

    /**
     * Cápsula vertical: acerta se o raio passa a menos de Radius do eixo.
     * Simplificação: devolve a distância do ponto do raio MAIS PRÓXIMO do eixo, não a da entrada
     * na superfície (erro de até um raio ao longo do tiro). Importa só para desempatar com uma
     * parede colada ao alvo; o atalho evita resolver a interseção exata raio-cápsula.
     */
    inline double RayCapsule(const FVector& Origin, const FVector& Dir, double MaxDist,
                             const FVector& Center, double HalfHeight, double Radius)
    {
        const FVector AxisOffset(0.0, 0.0, FMath::Max(0.0, HalfHeight - Radius));
        FVector OnRay;
        FVector OnAxis;
        FMath::SegmentDistToSegmentSafe(Origin, Origin + Dir * MaxDist,
                                        Center - AxisOffset, Center + AxisOffset, OnRay, OnAxis);
        if (FVector::DistSquared(OnRay, OnAxis) > Radius * Radius)
        {
            return -1.0;
        }
        return FVector::DotProduct(OnRay - Origin, Dir);
    }

    /** Cabeça primeiro (é menor e fica no topo do corpo), depois o corpo. */
    inline EVGHitboxPart RayHitbox(const FVector& Origin, const FVector& Dir, double MaxDist,
                                   const FVGHitboxFrame& Frame, double& OutDistance)
    {
        OutDistance = RaySphere(Origin, Dir, MaxDist, Frame.HeadCenter, Frame.HeadRadius);
        if (OutDistance >= 0.0)
        {
            return EVGHitboxPart::Head;
        }
        OutDistance = RayCapsule(Origin, Dir, MaxDist, Frame.BodyCenter, Frame.BodyHalfHeight, Frame.BodyRadius);
        return OutDistance >= 0.0 ? EVGHitboxPart::Body : EVGHitboxPart::None;
    }

    /** O instante Time interpolado entre os registros vizinhos. Fora do histórico: o extremo mais próximo. */
    inline FVGHitboxFrame SampleHistory(TConstArrayView<FVGHitboxFrame> Frames, double Time)
    {
        check(Frames.Num() > 0);
        if (Time <= Frames[0].Time)
        {
            return Frames[0];
        }
        for (int32 Index = 1; Index < Frames.Num(); ++Index)
        {
            const FVGHitboxFrame& After = Frames[Index];
            if (Time <= After.Time)
            {
                const FVGHitboxFrame& Before = Frames[Index - 1];
                const double Span = After.Time - Before.Time;
                const double Alpha = Span > 0.0 ? (Time - Before.Time) / Span : 1.0;
                FVGHitboxFrame Out = After;
                Out.Time = Time;
                Out.BodyCenter = FMath::Lerp(Before.BodyCenter, After.BodyCenter, Alpha);
                Out.BodyHalfHeight = FMath::Lerp(Before.BodyHalfHeight, After.BodyHalfHeight, Alpha); // agachar
                Out.HeadCenter = FMath::Lerp(Before.HeadCenter, After.HeadCenter, Alpha);
                return Out;
            }
        }
        return Frames[Frames.Num() - 1];
    }
}
```

### 2. O histórico de cada alvo

```cpp
// Source/Vigilia/Combat/VGHitboxHistoryComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Combat/VGLagCompRules.h"
#include "Components/ActorComponent.h"
#include "VGHitboxHistoryComponent.generated.h"

/**
 * Grava, NO SERVIDOR, onde as hitboxes simplificadas do personagem estiveram nos últimos instantes.
 * Usado pela arma para julgar um disparo no instante que o atirador via (Cap. 68).
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGHitboxHistoryComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGHitboxHistoryComponent();

    virtual void TickComponent(float DeltaTime, ELevelTick TickType,
                               FActorComponentTickFunction* ThisTickFunction) override;

    /** As hitboxes no instante Time (relógio do servidor). Sem histórico: o presente. */
    FVGHitboxFrame GetFrameAt(double Time) const;

    /**
     * O personagem com histórico mais próximo ao longo do raio, rebobinado para Time,
     * antes de MaxDist (a parede). Nulo se nenhum.
     */
    static APawn* FindRewoundHit(UWorld* World, const FVector& Origin, const FVector& Dir, double MaxDist,
                                 double Time, const AActor* Ignore, EVGHitboxPart& OutPart, double& OutDistance);

protected:
    virtual void BeginPlay() override;

    /** Quanto do passado guardar. Deve cobrir o rebobinamento máximo com folga. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|LagComp", meta = (ClampMin = "0.05"))
    float HistorySeconds = 0.5f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|LagComp", meta = (ClampMin = "1.0"))
    float HeadRadius = 12.0f;

private:
    FVGHitboxFrame CaptureNow() const;

    // ponytail: RemoveAt(0) é O(n) num histórico de ~15–60 registros; um anel fixo, se o profiler pedir.
    TArray<FVGHitboxFrame> Frames;
};
```

```cpp
// Source/Vigilia/Combat/VGHitboxHistoryComponent.cpp
#include "Combat/VGHitboxHistoryComponent.h"

#include "Combat/VGHealthComponent.h"
#include "Components/CapsuleComponent.h"
#include "EngineUtils.h"
#include "GameFramework/Character.h"

UVGHitboxHistoryComponent::UVGHitboxHistoryComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false;
    PrimaryComponentTick.TickGroup = TG_PostUpdateWork; // depois do movimento deste quadro
}

void UVGHitboxHistoryComponent::BeginPlay()
{
    Super::BeginPlay();
    // Só o servidor de uma partida em rede julga disparos. Clientes e single-player não gravam nada.
    const AActor* Owner = GetOwner();
    SetComponentTickEnabled(Owner->HasAuthority() && Owner->GetNetMode() != NM_Standalone);
}

FVGHitboxFrame UVGHitboxHistoryComponent::CaptureNow() const
{
    const ACharacter* Character = CastChecked<ACharacter>(GetOwner());
    const UCapsuleComponent* Capsule = Character->GetCapsuleComponent();

    FVGHitboxFrame Frame;
    Frame.Time = GetWorld()->GetTimeSeconds();
    Frame.BodyCenter = Capsule->GetComponentLocation();
    Frame.BodyHalfHeight = Capsule->GetScaledCapsuleHalfHeight(); // encolhe ao agachar
    Frame.BodyRadius = Capsule->GetScaledCapsuleRadius();
    // Simplificação: a cabeça é uma esfera no topo da cápsula, sem ossos. Além de simples, evita
    // depender da pose da malha, que um servidor dedicado pode não atualizar (ver Armadilhas).
    Frame.HeadRadius = HeadRadius;
    Frame.HeadCenter = Frame.BodyCenter + FVector(0.0, 0.0, Frame.BodyHalfHeight - HeadRadius);
    return Frame;
}

void UVGHitboxHistoryComponent::TickComponent(float DeltaTime, ELevelTick TickType,
                                              FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

    Frames.Add(CaptureNow());
    // Mantém um registro anterior ao limite, para interpolar exatamente na borda da janela.
    const double Oldest = GetWorld()->GetTimeSeconds() - HistorySeconds;
    while (Frames.Num() > 2 && Frames[1].Time < Oldest)
    {
        Frames.RemoveAt(0);
    }
}

FVGHitboxFrame UVGHitboxHistoryComponent::GetFrameAt(double Time) const
{
    return Frames.IsEmpty() ? CaptureNow() : VGLagCompRules::SampleHistory(Frames, Time);
}

APawn* UVGHitboxHistoryComponent::FindRewoundHit(UWorld* World, const FVector& Origin, const FVector& Dir,
                                                 double MaxDist, double Time, const AActor* Ignore,
                                                 EVGHitboxPart& OutPart, double& OutDistance)
{
    APawn* Best = nullptr;
    OutPart = EVGHitboxPart::None;
    OutDistance = MaxDist;

    for (TActorIterator<APawn> It(World); It; ++It)
    {
        APawn* Pawn = *It;
        const UVGHitboxHistoryComponent* History = Pawn->FindComponentByClass<UVGHitboxHistoryComponent>();
        const UVGHealthComponent* Health = Pawn->FindComponentByClass<UVGHealthComponent>();
        if (Pawn == Ignore || !History || (Health && !Health->IsAlive()))
        {
            continue; // Simplificação: quem está morto AGORA não absorve tiros do passado
        }
        double Distance = 0.0;
        // MaxDist encolhe a cada acerto: o próximo candidato precisa estar mais perto.
        const EVGHitboxPart Part = VGLagCompRules::RayHitbox(Origin, Dir, OutDistance, History->GetFrameAt(Time), Distance);
        if (Part != EVGHitboxPart::None && Distance < OutDistance)
        {
            Best = Pawn;
            OutPart = Part;
            OutDistance = Distance;
        }
    }
    return Best;
}
```

O `BP_ArenaJogador` ganha o componente. Inimigos de IA (Capítulo 30) não precisam: o tiro do jogador contra a IA não é afetado pela latência do jeito que o tiro contra outro jogador é, porque o servidor e a IA estão na mesma máquina. Há uma nuance (o cliente vê a IA também com atraso), que fica para o Interlúdio III.

### 3. A arma julga no passado

🔁 **O que havia:** no Capítulo 67, o disparo autoritativo traçava contra o mundo **no presente**, com os corpos dos personagens bloqueando o canal de armas pela malha (Capítulo 27). **O problema:** Q10. **A solução:** o servidor separa o tiro em duas perguntas, uma para cada relógio. Paredes não se movem: o mundo é consultado no presente. Personagens se movem: são consultados no passado do atirador.

```cpp
// VGWeapon.h (adições do Cap. 68)
protected:
    /** Multiplicador de cabeça para as hitboxes rebobinadas (o histórico não guarda material físico). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon|Net", meta = (ClampMin = "1.0"))
    float RewoundHeadMultiplier = 2.0f;

private:
    /** O instante que o atirador via, no relógio do servidor. */
    double EstimateShooterViewTime() const;

    void FirePelletRewound(const FVector& Origin, const FVector& Direction, double ViewTime);
```

```cpp
// VGWeapon.cpp (Cap. 68)
#include "Combat/VGHitboxHistoryComponent.h"
#include "DrawDebugHelpers.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerState.h"
#include "HAL/IConsoleManager.h"

static TAutoConsoleVariable<bool> CVarVGLagCompEnable(
    TEXT("vg.LagComp.Enable"), true,
    TEXT("Compensação de latência no servidor para disparos hitscan contra personagens."));

static TAutoConsoleVariable<float> CVarVGLagCompProxyDelay(
    TEXT("vg.LagComp.ProxyDelay"), 0.05f,
    TEXT("Atraso estimado (s) entre o estado recebido de um proxy e o que o cliente desenha. Calibre."));

static TAutoConsoleVariable<float> CVarVGLagCompMaxRewind(
    TEXT("vg.LagComp.MaxRewind"), 0.25f,
    TEXT("Rebobinamento máximo (s). Acima disso, o atirador precisa mirar à frente."));

static TAutoConsoleVariable<bool> CVarVGDebugLagComp(
    TEXT("vg.Debug.LagComp"), false,
    TEXT("Desenha no servidor a cápsula rebobinada (verde) e a atual (vermelha) do alvo de cada disparo."));

double AVGWeapon::EstimateShooterViewTime() const
{
    const double Now = GetWorld()->GetTimeSeconds();
    if (!CVarVGLagCompEnable.GetValueOnGameThread() || IsLocallyOwned())
    {
        return Now; // o anfitrião (e a IA) veem o presente do servidor
    }
    const APawn* Shooter = GetInstigator();
    const APlayerState* State = Shooter ? Shooter->GetPlayerState() : nullptr;
    // ⚠️ GetPingInMilliseconds: confira a API de ping do APlayerState na sua versão.
    const double OneWay = State ? State->GetPingInMilliseconds() * 0.0005 : 0.0; // RTT/2, em segundos
    const double Rewind = OneWay + CVarVGLagCompProxyDelay.GetValueOnGameThread();
    return Now - FMath::Clamp(Rewind, 0.0, static_cast<double>(CVarVGLagCompMaxRewind.GetValueOnGameThread()));
}

void AVGWeapon::FirePelletRewound(const FVector& Origin, const FVector& Direction, double ViewTime)
{
    const FVGWeaponStats& Stats = EffectiveStats;
    const FVector End = Origin + Direction * Stats.Range;

    // 1. O MUNDO, no presente: paredes não se movem. Personagens com histórico ficam de fora.
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGWeaponShotRewound), /*bTraceComplex=*/true, GetInstigator());
    Params.AddIgnoredActor(this);
    Params.bReturnPhysicalMaterial = true;
    for (TActorIterator<APawn> It(GetWorld()); It; ++It)
    {
        if (It->FindComponentByClass<UVGHitboxHistoryComponent>())
        {
            Params.AddIgnoredActor(*It);
        }
    }
    FHitResult WorldHit;
    const bool bWorldHit = GetWorld()->LineTraceSingleByChannel(WorldHit, Origin, End, ECC_VGWeapon, Params);
    const double WallDistance = bWorldHit ? WorldHit.Distance : Stats.Range;

    // 2. Os PERSONAGENS, no passado que o atirador via, antes da parede.
    EVGHitboxPart Part = EVGHitboxPart::None;
    double TargetDistance = 0.0;
    APawn* Target = UVGHitboxHistoryComponent::FindRewoundHit(GetWorld(), Origin, Direction, WallDistance,
                                                              ViewTime, GetInstigator(), Part, TargetDistance);

    FVector Impact = bWorldHit ? WorldHit.ImpactPoint : End;
    FVector Normal = bWorldHit ? WorldHit.ImpactNormal : -Direction;
    const float PerPellet = Stats.Damage / Data->PelletCount;

    if (Target)
    {
        Impact = Origin + Direction * TargetDistance;
        Normal = -Direction;
        const float Falloff = Data->DamageFalloff ? Data->DamageFalloff->GetFloatValue(TargetDistance) : 1.0f;
        const bool bHead = (Part == EVGHitboxPart::Head);
        const float Damage = PerPellet * Falloff * (bHead ? RewoundHeadMultiplier : 1.0f);
        // Acerto sintético: ponto e normal, sem osso nem material físico (reações do Cap. 30 ficam genéricas).
        const FHitResult TargetHit(Target, nullptr, Impact, Normal);
        UGameplayStatics::ApplyPointDamage(Target, Damage, Direction, TargetHit,
                                           GetInstigatorController(), this, Data->DamageType);
        ClientConfirmHit(Target, bHead);

        if (CVarVGDebugLagComp.GetValueOnGameThread())
        {
            const FVGHitboxFrame Then = Target->FindComponentByClass<UVGHitboxHistoryComponent>()->GetFrameAt(ViewTime);
            const UCapsuleComponent* Capsule = CastChecked<ACharacter>(Target)->GetCapsuleComponent();
            DrawDebugCapsule(GetWorld(), Then.BodyCenter, Then.BodyHalfHeight, Then.BodyRadius,
                             FQuat::Identity, FColor::Green, false, 2.0f);
            DrawDebugCapsule(GetWorld(), Capsule->GetComponentLocation(), Capsule->GetScaledCapsuleHalfHeight(),
                             Capsule->GetScaledCapsuleRadius(), FQuat::Identity, FColor::Red, false, 2.0f);
        }
    }
    else if (bWorldHit && WorldHit.GetActor())
    {
        // Parede, alvo do Galpão, estação de cura: o caminho do Cap. 27, sem penetração.
        UGameplayStatics::ApplyPointDamage(WorldHit.GetActor(), PerPellet, Direction, WorldHit,
                                           GetInstigatorController(), this, Data->DamageType);
    }

    if (IsLocallyOwned())
    {
        PlayShotFx(Muzzle->GetComponentLocation(), Impact, Normal, bWorldHit || Target); // anfitrião
    }
    MulticastShotFx(Muzzle->GetComponentLocation(), Impact, Normal, bWorldHit || Target);
}

// AVGWeapon::TraceShot (alteração do Cap. 68): no caminho autoritativo, com compensação ligada,
// cada projétil usa FirePelletRewound(Request.Origin, Direção, ViewTime), com ViewTime calculado
// uma vez por disparo. Sem compensação (CVar), e na predição do cliente, o FirePellet do Cap. 67.
```

### 4. O teste

```cpp
// Source/Vigilia/Tests/VGLagCompRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Combat/VGLagCompRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGLagCompRulesTest, "Vigilia.Net.LagCompensation",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

namespace
{
    FVGHitboxFrame MakeFrame(double Time, const FVector& Center)
    {
        FVGHitboxFrame Frame;
        Frame.Time = Time;
        Frame.BodyCenter = Center;
        Frame.BodyHalfHeight = 88.0;
        Frame.BodyRadius = 34.0;
        Frame.HeadRadius = 12.0;
        Frame.HeadCenter = Center + FVector(0.0, 0.0, 76.0);
        return Frame;
    }
}

bool FVGLagCompRulesTest::RunTest(const FString& Parameters)
{
    const FVector Origin = FVector::ZeroVector;
    const FVector Forward(1.0, 0.0, 0.0);

    TestEqual(TEXT("Esfera à frente: entra a 90"),
              VGLagCompRules::RaySphere(Origin, Forward, 1000.0, FVector(100.0, 0.0, 0.0), 10.0), 90.0, 0.01);
    TestTrue(TEXT("Esfera ao lado: erra"),
             VGLagCompRules::RaySphere(Origin, Forward, 1000.0, FVector(100.0, 20.0, 0.0), 10.0) < 0.0);
    TestTrue(TEXT("Esfera atrás da parede (MaxDist): erra"),
             VGLagCompRules::RaySphere(Origin, Forward, 50.0, FVector(100.0, 0.0, 0.0), 10.0) < 0.0);
    TestTrue(TEXT("Cápsula à frente: acerta"),
             VGLagCompRules::RayCapsule(Origin, Forward, 1000.0, FVector(200.0, 0.0, 0.0), 88.0, 34.0) >= 0.0);
    TestTrue(TEXT("Raio acima da cápsula: erra"),
             VGLagCompRules::RayCapsule(FVector(0.0, 0.0, 200.0), Forward, 1000.0, FVector(200.0, 0.0, 0.0), 88.0, 34.0) < 0.0);

    double Distance = 0.0;
    TestTrue(TEXT("Na altura da cabeça: cabeça"),
             VGLagCompRules::RayHitbox(FVector(0.0, 0.0, 76.0), Forward, 1000.0,
                                       MakeFrame(0.0, FVector(300.0, 0.0, 0.0)), Distance) == EVGHitboxPart::Head);

    // O alvo corria de lado: estava em Y = 0 em t = 0,0 e em Y = 100 em t = 0,1.
    const TArray<FVGHitboxFrame> History = { MakeFrame(0.0, FVector(500.0, 0.0, 0.0)), MakeFrame(0.1, FVector(500.0, 100.0, 0.0)) };
    TestEqual(TEXT("Interpola no meio"), VGLagCompRules::SampleHistory(History, 0.05).BodyCenter.Y, 50.0, 0.01);
    TestEqual(TEXT("Antes do histórico: o mais antigo"), VGLagCompRules::SampleHistory(History, -1.0).BodyCenter.Y, 0.0, 0.01);
    TestEqual(TEXT("Depois do histórico: o mais novo"), VGLagCompRules::SampleHistory(History, 9.0).BodyCenter.Y, 100.0, 0.01);

    // Q10 em miniatura: mirando onde ele ESTAVA, o presente erra e o passado acerta.
    TestTrue(TEXT("No presente: erra"),
             VGLagCompRules::RayHitbox(Origin, Forward, 1000.0,
                                       VGLagCompRules::SampleHistory(History, 0.1), Distance) == EVGHitboxPart::None);
    TestTrue(TEXT("Rebobinado: acerta o corpo"),
             VGLagCompRules::RayHitbox(Origin, Forward, 1000.0,
                                       VGLagCompRules::SampleHistory(History, 0.0), Distance) == EVGHitboxPart::Body);
    return true;
}

#endif
```

### Explicação das decisões

- **Instante estimado pelo servidor.** O servidor mede a latência do atirador; o cliente não escolhe o instante, e a trapaça de *backtrack* (escolher o momento mais favorável dentro da janela) não existe. O preço é o erro do *jitter*: um pedido que chegou mais rápido ou mais devagar que a média é julgado num instante um pouco errado.
- **Atraso de proxy como CVar.** Na Unreal, os proxies não têm um atraso de interpolação fixo (68.3). O valor certo depende da suavização configurada e da taxa de atualização, e se descobre **medindo** (o exercício faz isso). É um parâmetro de calibração, não uma constante.
- **Rebobinamento máximo.** Protege a vítima contra latências extremas e limita o tamanho do histórico. 250 ms é um ponto de partida.
- **Mundo no presente, personagens no passado.** As duas perguntas usam relógios diferentes porque os dois tipos de coisa mudam de jeitos diferentes. Uma porta que se move (Capítulo 19) seria julgada no presente; a Arena não tem portas.
- **Cópia geométrica, não colisores reais.** Nenhum componente se move, nenhuma sobreposição dispara, nada precisa ser restaurado.
- **Cabeça como esfera no topo da cápsula.** Um multiplicador de cabeça é central num FPS, e uma esfera captura o essencial. O material físico da cabeça (Capítulo 27) continua valendo no single-player e na predição.
- **Sem penetração no caminho rebobinado.** A penetração do Capítulo 27 atravessa materiais por superfície; combiná-la com hitboxes no passado exigiria intercalar dois relógios ao longo do raio. A Arena não tem paredes finas.
- **O anfitrião não rebobina.** Ele vê o presente do servidor. A IA, que também atira do servidor, idem.

---

## Projeto Arena — concluído

Rode como listen server e como *Play As Client*, com 100 ms, 30 ms de variação e 2% de perda. Ligue `vg.Debug.LagComp 1` na janela do servidor.

- **Q10 resolvida.** O cliente atira num alvo que corre de lado e acerta onde mirou. Na janela do servidor, cada acerto desenha a cápsula verde (onde o alvo estava no instante estimado) e a vermelha (onde está agora); a distância entre as duas é a latência tornada visível.
- **O outro lado.** Peça a alguém para correr para trás de uma cobertura enquanto você atira com 150 ms. Às vezes, a pessoa morre já escondida na tela dela. É o custo da seção 68.4, e o limite de rebobinamento decide até onde ele vai.
- **O empate.** Com latências diferentes nos dois clientes (a emulação permite valores por instância em algumas versões; se a sua não permitir, use o anfitrião contra um cliente com 150 ms), atirem um no outro ao mesmo tempo. Quem tem a latência menor vence a maioria dos empates, como em 68.5.

### O inventário de quebras, fechado

| # | Quebra | Resolvida em | Como |
|---|---|---|---|
| Q1 | Dano fantasma | 64, 66 | Guarda de autoridade no dono da vida; disparo por pedido |
| Q2 | Arma em dobro | 64, 65 | Armas criadas no servidor; inventário replicado; anexação local |
| Q3 | Corrida elástica | 67 | Corrida e mira como flags do movimento |
| Q4 | Morte pela metade | 65, 66 | Estado de vida replicado; `ClientOnPawnDied` e `AcknowledgePossession` |
| Q5 | "Continuar" mudo | 64 | Respawn automático pelo GameMode |
| Q6 | Sem placar | 64, 65 | `PlayerState` e `GameState` replicados |
| Q7 | HUD surda | 66 | `ClientConfirmHit` e `MulticastKillFeed` |
| Q8 | Pulo que volta | 67 | *Coyote time* no relógio do movimento |
| Q9 | Tiro atrasado | 67 | Semente compartilhada, traço previsto, munição reconciliada |
| Q10 | "Mas eu acertei!" | 68 | Histórico de hitboxes e rebobinamento no servidor |

### O que a Arena entrega

Dois jogadores numa arena de 30 metros, em listen server ou servidor dedicado, cada um com movimento preditivo (andar, correr, agachar, pular com *coyote time* e *buffer*), câmera em primeira pessoa com os modificadores das Partes III e IV, uma arma hitscan com dispersão prevista e compensação de latência, vida com regeneração, morte e respawn automático no ponto mais distante, uma estação de cura dormente, placar, *kill feed*, cronômetro, limite de abates e fim de partida com vencedor ou empate.

E, mais importante que a lista: uma **tabela de autoridade** (Capítulo 64) em que cada pedaço de estado tem um dono declarado, e um código em que cada sistema da Vigília foi revisto com a pergunta "isto decide, pede ou mostra?".

### Os limites conhecidos

- **Trapaças de input e de informação** (Capítulo 64): *aimbot*, *wallhack*, a semente conhecida pelo cliente.
- **Hitboxes grosseiras** e reações de impacto genéricas no caminho rebobinado.
- **Sem penetração** contra personagens rebobinados.
- **Erro de *jitter*** na estimativa do instante.
- **Tiros póstumos** recusados: sem trocas (desafio).
- **Projéteis** sem compensação (exercício opcional).
- **Dois jogadores.** Nada aqui foi medido com 16, 32 ou 64. O Interlúdio III discute o que muda.

---

## Decisões arquiteturais

1. **Cada informação desenhada pelo cliente tem um relógio**, e o servidor julga disparos no relógio do atirador.
2. **Compensação de latência no servidor**, com instante estimado pelo servidor (RTT/2 + atraso de proxy calibrável), limitado por um rebobinamento máximo.
3. **Mundo no presente, personagens no passado.**
4. **Cópia geométrica das hitboxes** (cápsula + esfera da cabeça), sem mover colisores.
5. **Empates resolvidos por ordem de chegada; morto não atira.** Trocas ficam como variação de design.
6. **Calibração como parte do sistema:** o atraso de proxy e o rebobinamento máximo são CVars medidas, não constantes.

---

## Armadilhas

- **Confundir ping com latência total.** Os ticks e a suavização somam dezenas de milissegundos.
- **Achar que *tick rate* alto resolve *hit registration*.** Reduz as esperas; não reduz a rede nem a injustiça da compensação.
- **Rebobinar o mundo inteiro.** Paredes não se movem; rebobiná-las só custa.
- **Rebobinar sem limite.** A vítima paga por qualquer latência do atirador.
- **Copiar o atraso de interpolação da Valve para a Unreal.** Os proxies da Unreal não são desenhados com atraso fixo; calibre.
- **Mover colisores reais para trás sem desfazer tudo.** Sobreposições, física e navegação reagem ao movimento.
- **Traçar contra a malha esquelética num servidor dedicado sem conferir a pose.** ⚠️ Personagens costumam nascer com uma opção de atualização de animação baseada em visibilidade; sem renderização, a pose (e as formas da *physics asset* presas aos ossos) pode não acompanhar a animação. Para traçar contra ossos no servidor dedicado, verifique o `VisibilityBasedAnimTickOption` da malha (a opção que também atualiza os ossos). As hitboxes da Arena não dependem disso, de propósito.
- **Esquecer a cadeia de posse em regras de troca.** O RPC do morto pode não ter mais por onde chegar.
- **Testar a compensação com o anfitrião atirando.** Ele não rebobina. Teste com o cliente atirando.
- **Mostrar ao jogador um acerto que o servidor recusou.** O impacto em personagem espera a confirmação (Capítulo 67).

---

## Exercício

**Parte 1 — a anatomia do atraso (1 h).** Com 100 ms de RTT, meça com o *Networking Insights* e com logs (em milissegundos, no relógio de cada máquina) o tempo entre o clique no cliente, a chegada do pedido no servidor, o tick em que ele foi processado, e a chegada do `ClientConfirmHit`. Monte a sua versão da tabela de 68.2 e compare com a teórica.

**Parte 2 — histórico e rebobinamento (2 h).** Implemente `VGLagCompRules`, o teste, o `UVGHitboxHistoryComponent` e o `FirePelletRewound`. Com `vg.LagComp.Enable 0`, conte quantos de 30 tiros num alvo que corre de lado contam; com `1`, conte de novo.

**Parte 3 — calibrar o atraso de proxy (1,5 h).** No cliente, desenhe com um `DrawDebugCapsule` a cápsula do alvo **no instante do disparo** (o que o cliente via), e mande a posição para o log. No servidor, com `vg.Debug.LagComp 1`, registre a cápsula rebobinada. Ajuste `vg.LagComp.ProxyDelay` até a distância média entre as duas ser mínima, com 50, 100 e 150 ms. Registre no `DEVLOG.md` o valor e explique por que ele (não) depende do RTT.

**Parte 4 — o empate (45 min).** Com o anfitrião contra um cliente a 150 ms, faça vinte duelos "ao mesmo tempo" (um terceiro conta "três, dois, um"). Anote quem vence. Depois, troque: o cliente a 30 ms. Escreva um parágrafo sobre o que um jogador com latência alta sente nessa Arena.

**Parte 5 (opcional) — o sinalizador em rede (2 h).** Leve o `AVGFlareProjectile` (Capítulo 28) para a Arena: o servidor cria o projétil autoritativo, replicado; o cliente que atira cria um projétil de enfeite, não replicado, que some quando o autoritativo chega. Descreva o que o jogador vê com 150 ms, com e sem o projétil de enfeite.

---

## Desafio — "Troca justa"

Implemente a regra de **troca** de 68.5 como alternativa à regra da Arena, ligada por uma CVar:

1. O servidor registra, no `UVGHealthComponent`, o instante da morte de cada jogador (relógio do servidor).
2. Ao receber um disparo de um atirador morto, estima o instante do disparo (chegada − RTT/2 do atirador). Se ele for anterior à morte, por uma margem calibrável, o disparo é processado.
3. Resolva a armadilha da posse: o pedido vem pela arma, e a arma perde a cadeia até a conexão no `UnPossess`. Escolha entre adiar o `UnPossess` até o fim da janela de troca ou rotear o pedido pelo `AVGPlayerController`, e justifique.
4. Repita os vinte duelos da Parte 4 do exercício com a regra ligada. Registre quantas trocas acontecem e como cada jogador descreve a experiência.

Escreva no `DEVLOG.md` qual regra você escolheria para um jogo competitivo e qual para um cooperativo, e por quê.

---

## Uso de IA

1. **Para revisar a compensação:**
   > "Revise esta compensação de latência para disparos hitscan em Unreal Engine 5: histórico de hitboxes gravado no servidor, instante estimado por RTT/2 mais um atraso de proxy, limite de rebobinamento, teste do raio contra cápsulas e esferas. Aponte: erros de relógio (servidor × cliente), casos em que um alvo é acertado através de uma parede, casos em que um morto absorve tiros, e o efeito do jitter. [código]"

2. **Para decompor a latência:**
   > "Monte a linha do tempo, em milissegundos, de um disparo num FPS cliente/servidor com estes parâmetros: [RTT de cada cliente, tick do servidor, FPS dos clientes, atraso de suavização]. Mostre quando o atirador vê o próprio disparo, quando vê a confirmação e quando a vítima vê o dano, e quais etapas mudariam ao dobrar o tick do servidor."

3. **Para pensar o design do empate:**
   > "Num duelo de FPS com compensação de latência, dois jogadores com latências de [X] e [Y] ms atiram ao mesmo tempo. Compare as regras: ordem de chegada com 'morto não atira', troca com janela, e sem compensação. Para cada uma, descreva o que cada jogador vê na própria tela e quem a regra favorece. Não atribua essas regras a jogos comerciais específicos."

**Cuidado específico:** pedidas para "explicar o netcode do jogo X", as IAs costumam produzir detalhes de implementação de jogos comerciais (taxas exatas, janelas de rebobinamento, algoritmos internos) que não são públicos. Use as respostas como hipóteses, exija fonte para cada número e marque no seu texto o que é **[FATO PÚBLICO]** e o que é **[INFERÊNCIA]**, como o livro faz.

---

## Checklist

- [ ] Sei definir e distinguir RTT, latência de ida, jitter, perda, banda, *tick rate* do servidor e do cliente, e *snapshot*.
- [ ] Sei decompor o caminho de um disparo em milissegundos, com e sem latência.
- [ ] Sei explicar interpolação, extrapolação e o que a Unreal faz com os proxies de personagens.
- [ ] Sei explicar *hit registration* (hitscan, projétil, validação, predição, histórico, rebobinamento) e quem paga o custo da compensação.
- [ ] Sei analisar o caso dos dois jogadores que atiram quase ao mesmo tempo, com as regras alternativas.
- [ ] Implementei o histórico de hitboxes e o rebobinamento, com teste, e calibrei o atraso de proxy.
- [ ] O inventário de quebras Q1–Q10 está fechado na Arena, em listen server e em servidor dedicado.

---

## Para ir além

- **Valve, *Source Multiplayer Networking*** (developer.valvesoftware.com): o modelo de ticks, *snapshots*, interpolação, predição e compensação de latência.
- **Yahn Bernier, *Latency Compensating Methods in Client/Server In-game Protocol Design and Optimization*** (Valve, 2001): o artigo clássico.
- **Gabriel Gambetta, "Fast-Paced Multiplayer"** (gabrielgambetta.com): as partes III (*entity interpolation*) e IV (*lag compensation*), com a demonstração interativa.
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** o capítulo sobre latência e as técnicas de mitigação.
- **Glenn Fiedler, *Gaffer On Games*** (gafferongames.com): os artigos sobre *snapshot interpolation* e sobre o envio de estado.
- **GDC Vault** (gdcvault.com): *I Shot You First: Networking the Gameplay of Halo: Reach*, de David Aldridge (GDC 2011), sobre como priorizar e julgar disparos num jogo em rede.

---

## Estado do Livro (fim da Parte IX)

- **Capítulos concluídos nesta parte:** 63 (Client/Server), 64 (Authority), 65 (Replication), 66 (RPC), 67 (Prediction), 68 (Latency). O estado das partes escritas em paralelo (VI–VIII, X) está no `README.md` e nos `ESTADO.md` de cada pasta.
- **Projeto:** **Projeto Arena concluído** — 1v1 em listen server e servidor dedicado, com inventário de quebras Q1–Q10 fechado.
- **Conceitos consolidados na Parte IX:**
  - local × online; um mundo por processo; papéis e modos de rede;
  - autoridade no dono do estado; tabela de autoridade; validação de forma × regra;
  - replicação de estado (convergente), condições, `OnRep`, relevância, dormência, escala;
  - RPCs, posse, confiabilidade, estado × evento, folgas calibradas;
  - predição e reconciliação; o CMC como estudo; as quatro categorias de variáveis; disparo previsto com semente;
  - latência decomposta; interpolação × extrapolação; compensação de latência e quem paga por ela.
- **Ponto de continuação:** Interlúdio III — Multiplayer avançado (servidor dedicado, partida, lobby, matchmaking; multiplayer com IA, física e mundo aberto; escala; a Vigília cooperativa).

---

➡️ **Próximo:** [Interlúdio III — Multiplayer avançado](../interludio-3/multiplayer-avancado.md)

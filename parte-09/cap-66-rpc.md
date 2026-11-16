# Capítulo 66 — RPC

## Objetivo

Ao final deste capítulo você deve conseguir:

- usar as três direções de RPC da Unreal (`Server`, `Client`, `NetMulticast`) sabendo onde cada chamada executa, conforme quem chama e quem é dono do ator;
- explicar a **cadeia de posse** (*ownership*) que permite a um cliente chamar um RPC de servidor, e por que um RPC num ator sem dono é descartado;
- escolher entre **confiável** e **não confiável**, e entre **RPC** e **propriedade replicada**, para cada informação de um FPS;
- validar pedidos no servidor separando forma (`_Validate`) de regra (corpo do RPC), com **folga** para a latência: balde de fichas para a cadência, tolerância de origem, carência de recarga;
- devolver a "voz" aos clientes da Arena: disparar, recarregar, interagir, ser avisado da própria morte e ver o *kill feed*.

---

## Contexto

O Capítulo 65 devolveu os olhos aos clientes, e eles continuam mudos. O cliente vê o anfitrião, a arma, a vida, o placar e a estação de cura. Aperta o gatilho e nada acontece, porque o pedido não tem como chegar ao servidor. Aperta "usar" na estação e nada acontece, pelo mesmo motivo. Morre e fica preso olhando para o corpo, porque o servidor não tem como avisar **só a ele** que é hora de entrar no modo de morte.

As três quebras restantes que não dependem de latência (o cliente que não atira, Q4 e Q7) são a mesma coisa vista de ângulos diferentes: **eventos que precisam atravessar a rede**. A replicação de propriedades não serve para eles, como o Capítulo 65 explicou: ela entrega estado convergente, perde intermediários e não sabe de "agora". Para eventos, a Unreal tem **chamadas de procedimento remoto**.

O capítulo também é onde a desconfiança do Capítulo 64 vira código. Cada pedido do cliente é uma porta de entrada para trapaças, e cada validação mal calibrada é uma porta de saída para jogadores honestos com 100 ms de latência.

---

## 66.1 Três direções

Um RPC é uma função declarada numa máquina e executada em outra. A Unreal tem três tipos:

```text
  Server         cliente dono ──► servidor          "quero atirar", "quero usar"
  Client         servidor ──► cliente dono          "seu corpo morreu", "seu tiro acertou"
  NetMulticast   servidor ──► servidor + clientes   "houve um disparo aqui", "fulano abateu sicrano"
```

Onde cada chamada executa depende de **quem chama** e de **quem é dono do ator**. A documentação da Unreal resume assim (⚠️ confira a tabela na página de RPCs da sua versão):

**Chamado no servidor:**

| Dono do ator | `NetMulticast` | `Server` | `Client` |
|---|---|---|---|
| Um cliente | Servidor e todos os clientes | Servidor | **Cliente dono** |
| O servidor | Servidor e todos os clientes | Servidor | Servidor |
| Ninguém | Servidor e todos os clientes | Servidor | Servidor |

**Chamado num cliente:**

| Dono do ator | `NetMulticast` | `Server` | `Client` |
|---|---|---|---|
| O próprio cliente | Só localmente | **Servidor** | Só localmente |
| Outro cliente | Só localmente | Descartado | Só localmente |
| O servidor, ou ninguém | Só localmente | Descartado | Só localmente |

Duas linhas carregam o capítulo. Um **RPC `Server` só sai de um cliente se o ator for dele**. Um **RPC `Client` chamado no servidor vai para o dono, e, se o dono for local (o anfitrião) ou se não houver dono, executa no próprio servidor**. É por isso que o mesmo código funciona para o anfitrião, para o cliente e para um inimigo de IA sem conexão.

Em *standalone*, todo RPC executa localmente, e o código single-player da Vigília continua funcionando.

---

## 66.2 Posse: quem pode chamar o quê

A **cadeia de posse** de um ator é a sequência de `Owner`s até chegar a um `PlayerController`, que está ligado a uma conexão. O servidor só aceita um RPC `Server` vindo da conexão no fim dessa cadeia.

```text
  UNetConnection (cliente A)
        ▲
  PlayerController A          (dono da conexão)
        ▲ possui
  Pawn A                      (Owner = PC A, definido na possessão)
        ▲ Owner
  Arma A                      (Owner = Pawn A, definido no spawn: Cap. 20)
        ▲ componente
  UVGInteractionComponent     (componentes usam o dono do ator)
```

Na Arena, a cadeia já está montada por decisões antigas. O Capítulo 20 passava `Params.Owner = GetOwner()` ao criar a arma, para que ela soubesse quem a carregava. Em rede, o mesmo campo responde "de que conexão podem vir os RPCs desta arma". O `PlayerState` também pertence ao controller. O `GameState` não pertence a ninguém, e é por isso que nenhum cliente pode chamar um RPC `Server` nele: é preciso passar pelo controller.

Três consequências práticas:

- **Um RPC num ator sem dono é descartado**, com um aviso no log do tipo "sem conexão dona". Se um RPC "não faz nada", a primeira suspeita é a posse.
- **A posse muda.** Quando o servidor faz `UnPossess` no corpo morto, o `Owner` do corpo deixa de apontar para o controller, e a arma presa a ele deixa de ter uma cadeia até a conexão. ⚠️ RPCs em trânsito de um jogador que acabou de morrer podem chegar a um ator que a conexão não possui mais. O Capítulo 68 volta a esse ponto ao discutir "tiros póstumos".
- **Componentes precisam replicar para receber RPCs.** O `UVGInteractionComponent` não tem nenhuma propriedade replicada, e mesmo assim precisa de `SetIsReplicatedByDefault(true)` para que o RPC encontre o componente do outro lado.

---

## 66.3 Confiável ou não confiável

| | Confiável (`Reliable`) | Não confiável (`Unreliable`) |
|---|---|---|
| **Entrega** | Garantida; retransmitida se o pacote se perder | Pode se perder |
| **Ordem** | Na ordem de chamada, entre os confiáveis do mesmo ator | Sem garantia |
| **Custo** | Fila de retransmissão por conexão; se a fila encher, a **conexão cai** | Nenhum além do envio |
| **Use para** | Eventos raros que mudam o jogo ou a interface: pedir para atirar, morrer, recarregar, usar | Eventos frequentes e descartáveis: efeitos, confirmações que serão superadas pela próxima |

Duas regras de bolso:

1. **Um RPC confiável chamado a cada quadro é um bug esperando a perda de pacotes.** Com 2% de perda, a fila de retransmissão cresce, e um *buffer* de confiáveis estourado derruba a conexão. Movimento, mira contínua, posições de efeitos: nunca confiáveis.
2. **Não há ordem entre RPCs e propriedades, nem entre atores diferentes.** Um RPC `Client` com um ponteiro para um ator recém-criado pode chegar antes do ator, e o ponteiro chega nulo. Um *multicast* não alcança clientes para os quais o ator não é relevante, nem clientes que entram depois.

---

## 66.4 Estado ou evento?

O Capítulo 65 deu a regra ("replique estado; mande eventos por RPC ou transforme-os em estado"). Aplicada à Arena:

| Informação | É | Mecanismo | Por quê |
|---|---|---|---|
| "Quero atirar com esta mira" | Evento, cliente → servidor | `Server`, **confiável** | Cada disparo conta; ordem importa (o identificador do disparo) |
| "Quero recarregar" | Evento | `Server`, confiável | Raro, muda o estado da arma |
| "Quero usar a estação" | Evento | `Server`, confiável | Raro, muda o mundo |
| Rastro e impacto de um disparo | Evento cosmético | `NetMulticast`, não confiável | Frequente; perder um rastro não muda nada |
| "Seu tiro acertou" | Evento para um jogador | `Client`, não confiável | Frequente numa rajada; a vida do alvo é o estado verdadeiro |
| "Seu corpo morreu" | Evento para um jogador | `Client`, confiável | Raro; perder deixa o jogador preso na câmera |
| Linha do *kill feed* | Evento para todos | `NetMulticast`, confiável | Raro; a linha que falta é notada. O placar é o estado |
| Vida, placar, arma equipada | Estado | Propriedade | Entrada tardia e relevância precisam do valor atual |

Repare na última coluna: a escolha nunca é "o que é mais fácil de programar". É **o que acontece se a mensagem se perder** e **o que acontece com quem chega depois**.

### *Multicast* ou contador replicado?

Para os efeitos de disparo nos outros clientes, há duas abordagens comuns: o *multicast* não confiável e o contador replicado do Capítulo 65.

| | `NetMulticast` não confiável | Contador de disparos replicado |
|---|---|---|
| **Granularidade** | Um envio por disparo, com dados (origem, impacto) | O contador muda; o cliente toca "um disparo" ou "vários" |
| **Perda** | Disparos perdidos não aparecem | Disparos entre duas atualizações se fundem |
| **Banda numa rajada** | Proporcional à cadência | Limitada pela frequência de atualização da arma |
| **Precisão do impacto** | Ponto exato de cada disparo | Precisa de outra propriedade para o impacto |
| **Adequação à Arena** | **Sim**: dois jogadores, cadência baixa, impacto exato | Melhor com muitos jogadores e armas de cadência alta |

---

## 66.5 Validar sem punir a latência

O Capítulo 64 separou validação de **forma** (o que um cliente honesto nunca faria: pode desconectar) de validação de **regra** (o que um cliente honesto faz por causa da latência: recusa em silêncio, com folga). A Unreal implementa a primeira com `WithValidation`: o RPC ganha uma função `_Validate`, e, se ela retornar `false`, **o cliente é desconectado**. ⚠️ Na UE5, `WithValidation` é opcional para RPCs `Server`. Use-o quando houver forma para validar.

Para a Arena, três validações de regra merecem atenção, porque cada uma tem uma armadilha de latência.

### Cadência: o balde de fichas

O caminho óbvio é recusar um disparo que chegue antes do intervalo mínimo desde o anterior. Ele pune clientes honestos. Os pedidos saem do cliente em intervalos regulares, mas chegam ao servidor com **jitter**: dois pacotes podem chegar juntos depois de um atraso. Para o servidor, parecem dois disparos no mesmo instante.

A solução é medir a **cadência média**, não o intervalo instantâneo, com um **balde de fichas** (*token bucket*): o balde ganha fichas na cadência da arma, até uma folga máxima, e cada disparo gasta uma. Uma rajada curta de pedidos acumulados é aceita, porque o balde estava cheio. Uma cadência **sustentada** acima da arma esvazia o balde e é cortada.

### Origem: a tolerância de posição

O cliente informa de onde atirou (a câmera). O servidor compara com onde ele acha que a câmera está. Com latência, as duas posições diferem: o servidor está processando o movimento do cliente com algum atraso. Uma tolerância fixa (1 m, calibrável) aceita a diferença normal e recusa um teletransporte de mira (atirar de "dentro" da parede ou de outro ponto do mapa).

### Recarga: a carência

O cliente começa a recarregar em *t*. O pedido chega ao servidor em *t* + 50 ms, e a recarga do servidor termina 50 ms depois da do cliente. O cliente, já pronto na tela dele, atira, e o disparo chega ao servidor durante a recarga. A carência (`ReloadGraceTime`) diz: se faltar menos que isso para a recarga do servidor terminar, termine agora e aceite o disparo.

> 🌉 **Ponte:** o balde de fichas é o algoritmo de *rate limiting* de APIs. A tolerância de origem e a carência de recarga são **janelas de tolerância a relógios dessincronizados**, o mesmo raciocínio de aceitar um token JWT com alguns segundos de *clock skew*.
>
> 🧱 **Onde a ponte cai:** um *rate limiter* de API protege o servidor de abuso, e a folga é generosa contra o cliente. Aqui, a folga é calibrada **a favor** do cliente honesto e contra o trapaceiro ao mesmo tempo: folga demais permite um pouco mais de cadência a quem trapaceia; folga de menos faz o jogador honesto "perder tiros" sem entender por quê. O número certo sai de medir com latência e perda reais, não de um palpite.

---

## Estudos de caso

### Battlefield — marcar inimigos

**[FATO PÚBLICO, observável jogando]** No Bad Company 2, no Battlefield 3 e no Battlefield 4 (a mecânica vem de antes, do Battlefield 2 e do 2142), o jogador pode **marcar** (*spot*) um inimigo que está vendo, com um botão. O inimigo marcado aparece no minimapa e na HUD dos colegas de equipe por algum tempo.

**[INFERÊNCIA]** A mecânica tem a forma exata deste capítulo. O botão gera um **pedido** ("marquei aquele ali"). O servidor **valida** (o inimigo está à vista? a marcação é recente demais?). O resultado vira **estado** com duração (o inimigo está marcado para a equipe X até o instante T), e não um evento: um colega que olha o minimapa cinco segundos depois, ou que acabou de renascer, precisa ver a marcação. É pedido → validação → estado.

**Lição para a Arena:** quando um evento tem **duração** ou precisa ser visto por quem chega depois, ele vira estado no servidor, mesmo que tenha nascido de um RPC.

### Call of Duty — ativar uma sequência de abates

**[FATO PÚBLICO, observável jogando]** Em Call of Duty, sequências de abates ou de pontos (*killstreaks*, *scorestreaks*) dão recompensas que o jogador ativa, como o radar aéreo (UAV), que revela inimigos no minimapa da equipe por um tempo.

**[INFERÊNCIA]** A ativação é um pedido que o servidor só aceita se **ele** contou a sequência: a contagem é estado autoritativo (Capítulo 64), e um cliente que afirmasse "tenho uma sequência de 5" seria a trapaça de estado da tabela. O efeito (o radar) é estado com duração, replicado para a equipe. O aviso "UAV inimigo no ar" é um evento para todos, candidato natural a *multicast*.

**Lição para a Arena:** um único recurso de jogo costuma usar as três ferramentas: RPC `Server` para o pedido, propriedade para o efeito duradouro, `NetMulticast` para o aviso.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| RPC `Server` | Uma chamada de API (POST) | Sem valor de retorno: a "resposta" é estado replicado ou outro RPC |
| RPC `Client` | *Push notification* para um usuário | Só pelo canal do dono; no anfitrião, executa localmente |
| `NetMulticast` | *Broadcast*, *pub/sub* | Respeita relevância; quem entra depois não recebe |
| Confiável | Entrega garantida e ordenada (TCP) | Fila cheia derruba a conexão; nunca a cada quadro |
| Não confiável | UDP, métricas *fire-and-forget* | É o padrão para quase tudo que é frequente |
| Cadeia de posse | Autorização por dono do recurso | Muda em runtime (possessão, morte) |
| `_Validate` | Validação de esquema → 400 | Falhar **desconecta** |
| Balde de fichas | *Rate limiter* de API | A folga protege o cliente honesto do jitter, não o servidor do abuso |

---

## Unreal Engine: o que existe

- **Declaração:** `UFUNCTION(Server, Reliable)`, `UFUNCTION(Client, Unreliable)`, `UFUNCTION(NetMulticast, Unreliable)`, com `WithValidation` opcional nos de servidor. O UHT gera a chamada; você implementa `NomeDaFuncao_Implementation` e, se houver, `NomeDaFuncao_Validate`.
- **Parâmetros:** tipos simples, `FString`, `FName`, estruturas com `UPROPERTY`, tipos quantizados (`FVector_NetQuantize*`) e ponteiros para atores e componentes **replicados** (que se resolvem do outro lado). Sem valor de retorno.
- **Blueprint:** os eventos personalizados têm a opção de replicação *Run on Server*, *Run on owning Client* e *Multicast*, com a mesma semântica.
- **Requisitos:** o ator replica; o componente replica; o ator tem a cadeia de posse adequada para RPCs `Server`.

O que **não** existe pronto: limitação de cadência por RPC, tolerâncias calibradas, e a decisão de estado ou evento. Esse é o código deste capítulo.

---

## Abordagens

Como o disparo do cliente chega ao servidor?

| Critério | A. "Gatilho apertado/solto" e o servidor roda a cadência | **B. Um pedido por disparo, com origem, mira e identificador** | C. O cliente informa os acertos ("acertei X"), o servidor valida |
|---|---|---|---|
| **Complexidade** | Baixa: dois RPCs | Média: estrutura de pedido e validações | Alta: validar um acerto exige reconstruir a cena |
| **Performance** | Mínima de banda | Um RPC por disparo (~15 bytes) | Um RPC por acerto |
| **Fidelidade ao jogador** | Ruim: o número e o momento dos disparos dependem do relógio do servidor e do jitter | **Boa**: o cliente decide **quando**, o servidor decide **o que acontece** | Ótima na tela do atirador |
| **Segurança** | Boa | Boa: o servidor traça o tiro | Fraca sem compensação: o cliente escolhe o alvo |
| **Prototipação** | Imediata | Rápida | Lenta |
| **Adequação à Arena** | Não: semiautomáticas perdem cliques e a rajada não bate | **Sim** | Parcial: a validação dela é o Capítulo 68, por outro caminho |

**Decisão: B.** O cliente tem a melhor informação sobre **quando** o jogador atirou (o clique aconteceu na máquina dele) e a pior autoridade sobre **o que** o tiro faz. O pedido por disparo separa as duas coisas. O identificador sequencial serve à validação de forma neste capítulo, à semente compartilhada no Capítulo 67 e à reconciliação de munição também no 67. A abordagem C reaparece no Capítulo 68 de outra forma: o servidor não confia no acerto do cliente, mas **reconstrói** a cena que o cliente via.

---

## Implementação

### 1. O pedido de disparo

```cpp
// Source/Vigilia/Combat/VGShotTypes.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/NetSerialization.h"
#include "VGShotTypes.generated.h"

/** Pedido de disparo: a INTENÇÃO do cliente. O resultado é do servidor. */
USTRUCT()
struct FVGShotRequest
{
    GENERATED_BODY()

    /** Origem do traço (a câmera do atirador), com 0,1 cm de precisão na rede. */
    UPROPERTY()
    FVector_NetQuantize10 Origin;

    /** Mira comprimida a 16 bits por eixo (~0,0055°). */
    UPROPERTY()
    uint16 AimPitch = 0;

    UPROPERTY()
    uint16 AimYaw = 0;

    /** Sequencial por arma. Forma (Cap. 66), semente (Cap. 67), reconciliação (Cap. 67). */
    UPROPERTY()
    int32 ShotId = 0;

    void SetAim(const FRotator& Rotation)
    {
        AimPitch = FRotator::CompressAxisToShort(Rotation.Pitch);
        AimYaw = FRotator::CompressAxisToShort(Rotation.Yaw);
    }

    /** A mira como o SERVIDOR a verá: o cliente deve usar esta, e não a original (Cap. 67). */
    FRotator GetAim() const
    {
        return FRotator(FRotator::DecompressAxisFromShort(AimPitch),
                        FRotator::DecompressAxisFromShort(AimYaw), 0.0f);
    }
};
```

A mira é comprimida por nós, e não por um tipo da engine, por um motivo que só aparece no próximo capítulo: o cliente vai precisar calcular o disparo com **exatamente** a mesma mira que o servidor recebe. Uma mira comprimida dentro da serialização não estaria disponível para o cliente; uma mira comprimida pelo próprio código, sim.

### 2. As regras de validação, puras

```cpp
// Source/Vigilia/Combat/VGNetRules.h
#pragma once

#include "CoreMinimal.h"

/** Regras puras de validação (Cap. 66) e reconciliação (Cap. 67) de rede. */
namespace VGNetRules
{
    /** Balde de fichas: a cadência que o servidor aceita, com folga para rajadas de jitter. */
    struct FFireBudget
    {
        double Tokens = -1.0;  // < 0: nunca usado; o primeiro uso começa com o balde cheio
        double LastTime = 0.0; // relógio: tempo de jogo do servidor
    };

    /** Consome uma ficha, se houver. O balde ganha ShotsPerSecond fichas por segundo, até Burst. */
    inline bool TryConsumeShot(FFireBudget& Budget, double Now, double ShotsPerSecond, double Burst)
    {
        Budget.Tokens = (Budget.Tokens < 0.0)
            ? Burst
            : FMath::Min(Burst, Budget.Tokens + (Now - Budget.LastTime) * ShotsPerSecond);
        Budget.LastTime = Now;
        if (Budget.Tokens < 1.0)
        {
            return false;
        }
        Budget.Tokens -= 1.0;
        return true;
    }

    /** A origem informada está perto de onde o servidor acha que estão os olhos do atirador? */
    inline bool IsOriginPlausible(const FVector& Claimed, const FVector& ServerEye, double MaxError)
    {
        return FVector::DistSquared(Claimed, ServerEye) <= FMath::Square(MaxError);
    }
}
```

```cpp
// Source/Vigilia/Tests/VGNetRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Combat/VGNetRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGNetRulesTest, "Vigilia.Net.Rules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGNetRulesTest::RunTest(const FString& Parameters)
{
    // Arma de 10 disparos/s, folga de 3.
    VGNetRules::FFireBudget Budget;
    TestTrue(TEXT("1º disparo"), VGNetRules::TryConsumeShot(Budget, 0.0, 10.0, 3.0));
    TestTrue(TEXT("2º no mesmo instante (jitter)"), VGNetRules::TryConsumeShot(Budget, 0.0, 10.0, 3.0));
    TestTrue(TEXT("3º no mesmo instante"), VGNetRules::TryConsumeShot(Budget, 0.0, 10.0, 3.0));
    TestFalse(TEXT("4º no mesmo instante: além da folga"), VGNetRules::TryConsumeShot(Budget, 0.0, 10.0, 3.0));
    TestTrue(TEXT("0,1 s depois: uma ficha nova"), VGNetRules::TryConsumeShot(Budget, 0.1, 10.0, 3.0));
    TestFalse(TEXT("logo em seguida: sem ficha"), VGNetRules::TryConsumeShot(Budget, 0.1, 10.0, 3.0));

    // Cadência sustentada de 20/s por 5 s: o balde deixa passar ~10/s (+ a folga).
    int32 Accepted = 0;
    for (int32 Index = 0; Index < 100; ++Index)
    {
        Accepted += VGNetRules::TryConsumeShot(Budget, 1.0 + Index * 0.05, 10.0, 3.0) ? 1 : 0;
    }
    TestTrue(TEXT("20/s sustentados viram ~10/s"), Accepted >= 45 && Accepted <= 55);

    TestTrue(TEXT("Origem a 50 cm: plausível"),
             VGNetRules::IsOriginPlausible(FVector(50.0, 0.0, 0.0), FVector::ZeroVector, 100.0));
    TestFalse(TEXT("Origem a 5 m: implausível"),
              VGNetRules::IsOriginPlausible(FVector(500.0, 0.0, 0.0), FVector::ZeroVector, 100.0));
    return true;
}

#endif
```

### 3. A arma fala

🔁 **O que havia:** no Capítulo 64, `FireOnce` só traçava o tiro na cópia autoritativa, e a cópia do cliente não fazia nada. O `PerformShot` (Capítulos 20 e 27) tirava a origem e a mira do controller **na máquina que executava**. **O problema:** no servidor, para um cliente remoto, ninguém chama `FireOnce`, porque o input está no cliente. **A solução:** o cliente monta um pedido e o envia; o servidor valida e resolve. O `PerformShot` vira `ResolveShot(const FVGShotRequest&)`, que não lê mais o controller: tudo o que precisa está no pedido.

```cpp
// VGWeapon.h (adições do Cap. 66)
#include "Combat/VGNetRules.h"
#include "Combat/VGShotTypes.h"

public:
    /** O servidor recarrega a cópia dele; o cliente recarrega localmente para a animação. */
    UFUNCTION(Server, Reliable)
    void ServerReload();

protected:
    UFUNCTION(Server, Reliable, WithValidation)
    void ServerFireShot(const FVGShotRequest& Request);

    UFUNCTION(NetMulticast, Unreliable)
    void MulticastShotFx(FVector_NetQuantize From, FVector_NetQuantize To,
                         FVector_NetQuantizeNormal ImpactNormal, bool bImpact);

    UFUNCTION(Client, Unreliable)
    void ClientConfirmHit(AActor* HitActor, bool bCritical);

    /** Tolerâncias de validação: calibre medindo com latência e perda (exercício). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon|Net", meta = (ClampMin = "0.0"))
    float MaxOriginError = 100.0f; // cm

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon|Net", meta = (ClampMin = "1.0"))
    float FireBurstAllowance = 3.0f; // disparos

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon|Net", meta = (ClampMin = "0.0"))
    float ReloadGraceTime = 0.15f; // s

private:
    FVGShotRequest MakeShotRequest();
    void ResolveShot(const FVGShotRequest& Request);
    void PlayShotFx(const FVector& From, const FVector& To, const FVector& ImpactNormal, bool bImpact);
    bool IsLocallyOwned() const;

    int32 NextShotId = 0;                   // dono: próximo identificador
    int32 LastReceivedShotId = INDEX_NONE;  // servidor: último recebido (forma)
    VGNetRules::FFireBudget FireBudget;     // servidor: cadência (regra)
```

```cpp
// VGWeapon.cpp (Cap. 66)
#include "Player/VGCharacter.h"

bool AVGWeapon::IsLocallyOwned() const
{
    const APawn* Shooter = GetInstigator();
    return Shooter && Shooter->IsLocallyControlled();
}

FVGShotRequest AVGWeapon::MakeShotRequest()
{
    FVGShotRequest Request;
    if (const AController* Controller = GetInstigatorController())
    {
        FVector ViewLocation;
        FRotator ViewRotation;
        Controller->GetPlayerViewPoint(ViewLocation, ViewRotation); // origem: a câmera (Cap. 27)
        Request.Origin = ViewLocation;
        Request.SetAim(ViewRotation);
    }
    Request.ShotId = NextShotId++;
    return Request;
}

void AVGWeapon::FireOnce()
{
    // Roda só na máquina do jogador que atira (onde há input): anfitrião, cliente ou single-player.
    const FVGShotRequest Request = MakeShotRequest();
    if (HasAuthority())
    {
        --AmmoInMagazine;        // anfitrião e single-player: decide na hora
        ResolveShot(Request);
    }
    else
    {
        ServerFireShot(Request); // cliente: pede. Munição e acerto voltam do servidor (Cap. 67: prever)
    }
    OnShotFeedback();            // som e clarão do próprio disparo: imediatos para quem atira
    OnFired.Broadcast(this);     // coice e HUD: locais
    BroadcastAmmo();
}

bool AVGWeapon::ServerFireShot_Validate(const FVGShotRequest& Request)
{
    // FORMA: um RPC confiável chega em ordem e sem duplicata. Repetido ou fora de ordem = adulterado.
    return Request.ShotId > LastReceivedShotId;
}

void AVGWeapon::ServerFireShot_Implementation(const FVGShotRequest& Request)
{
    LastReceivedShotId = Request.ShotId;

    // REGRAS: recusa silenciosa. Clientes honestos as violam por latência.
    const AVGCharacter* Shooter = Cast<AVGCharacter>(GetInstigator());
    const UVGHealthComponent* ShooterHealth = Shooter ? Shooter->FindComponentByClass<UVGHealthComponent>() : nullptr;
    if (!Data || !ShooterHealth || !ShooterHealth->IsAlive())
    {
        return; // morto não atira (Cap. 68 discute o tiro "póstumo")
    }

    // Carência: a recarga do cliente terminou um pouco antes da do servidor.
    if (State == EVGWeaponState::Reloading
        && GetWorldTimerManager().GetTimerRemaining(ActionTimerHandle) <= ReloadGraceTime)
    {
        GetWorldTimerManager().ClearTimer(ActionTimerHandle);
        FinishReload();
    }
    if (State != EVGWeaponState::Ready || AmmoInMagazine <= 0)
    {
        return;
    }

    const double ShotsPerSecond = 1.0 / EffectiveStats.GetFireInterval();
    if (!VGNetRules::TryConsumeShot(FireBudget, GetWorld()->GetTimeSeconds(), ShotsPerSecond, FireBurstAllowance))
    {
        return;
    }

    const FVector ServerEye = Shooter->GetFirstPersonCamera()->GetComponentLocation();
    if (!VGNetRules::IsOriginPlausible(Request.Origin, ServerEye, MaxOriginError))
    {
        return;
    }

    --AmmoInMagazine; // COND_OwnerOnly: o dono vê o número cair um RTT depois (Cap. 67)
    ResolveShot(Request);
}

void AVGWeapon::ResolveShot(const FVGShotRequest& Request)
{
    // Semente do Cap. 27, agora pelo ShotId. Só o servidor resolve; ainda não precisa ser compartilhada.
    const FRandomStream Stream(static_cast<int32>(HashCombine(GetUniqueID(), static_cast<uint32>(Request.ShotId))));

    // Simplificação temporária: dispersão com o que o SERVIDOR sabe (movimento, queda). O alfa de mira
    // e o bloom são do cliente e não chegam aqui. O Cap. 67 os coloca no pedido, com validação de faixa.
    const float HalfAngle = FMath::DegreesToRadians(ComputeSpreadDegrees());
    const FVector AimDirection = Request.GetAim().Vector();

    for (int32 Pellet = 0; Pellet < Data->PelletCount; ++Pellet)
    {
        FirePellet(Request.Origin, Stream.VRandCone(AimDirection, HalfAngle), Stream);
    }
}
```

O `FirePellet` do Capítulo 27 muda em três linhas: o anúncio do acerto e a apresentação passam a atravessar a rede.

```cpp
// AVGWeapon::FirePellet (alterações do Cap. 66)
        if (AActor* HitActor = Hit.GetActor())
        {
            UGameplayStatics::ApplyPointDamage(HitActor, Damage, Direction, Hit,
                                               GetInstigatorController(), this, Data->DamageType);
            if (HitActor->FindComponentByClass<UVGHealthComponent>())
            {
                // Antes: OnHitConfirmed.Broadcast. Agora o atirador pode estar em outra máquina.
                // Client RPC: vai ao dono; no anfitrião, ou sem dono (IA), executa aqui mesmo.
                ClientConfirmHit(HitActor, MaterialMultiplier > 1.0f);
            }
        }
        // (o efeito de impacto por superfície sai daqui: guarde LastImpact e LastNormal)
    // ...
    // Fim do FirePellet. Antes: OnShotTracer(...). Agora, para todos (o servidor inclusive):
    MulticastShotFx(Muzzle->GetComponentLocation(), LastImpact, LastNormal, bAnyImpact);
```

```cpp
// VGWeapon.cpp (Cap. 66, continuação)
void AVGWeapon::ClientConfirmHit_Implementation(AActor* HitActor, bool bCritical)
{
    OnHitConfirmed.Broadcast(this, HitActor, bCritical); // a HUD do atirador (Cap. 27)
}

void AVGWeapon::MulticastShotFx_Implementation(FVector_NetQuantize From, FVector_NetQuantize To,
                                               FVector_NetQuantizeNormal ImpactNormal, bool bImpact)
{
    PlayShotFx(From, To, ImpactNormal, bImpact);
    if (!IsLocallyOwned())
    {
        OnShotFeedback(); // som e clarão para quem VÊ o disparo; o atirador já tocou o seu em FireOnce
    }
}

void AVGWeapon::PlayShotFx(const FVector& From, const FVector& To, const FVector& ImpactNormal, bool bImpact)
{
    if (GetNetMode() == NM_DedicatedServer)
    {
        return; // sem tela
    }
    OnShotTracer(From, To);
    if (bImpact && Data && Data->ImpactEffects)
    {
        // Simplificação: impacto reconstruído sem material físico (efeito padrão) e só o ÚLTIMO
        // impacto de cada projétil; a penetração do Cap. 27 mostra menos marcas nos outros clientes.
        FHitResult Hit;
        Hit.bBlockingHit = true;
        Hit.Location = Hit.ImpactPoint = To;
        Hit.Normal = Hit.ImpactNormal = ImpactNormal;
        Data->ImpactEffects->PlayAt(this, Hit);
    }
}
```

A recarga também atravessa:

```cpp
// VGWeapon.cpp (alterações do Cap. 66)
void AVGWeapon::StartReload()
{
    // ... verificações e transição para Reloading, como no Cap. 20 ...
    if (!HasAuthority())
    {
        ServerReload(); // o servidor recarrega a cópia autoritativa
    }
}

void AVGWeapon::ServerReload_Implementation()
{
    StartReload(); // as mesmas verificações, com o estado do servidor
}

void AVGWeapon::FinishReload()
{
    if (HasAuthority()) // a munição é do servidor; o cliente a recebe replicada (Cap. 67: prever)
    {
        const int32 Transfer = FMath::Min(EffectiveStats.GetMagazineSize() - AmmoInMagazine, ReserveAmmo);
        AmmoInMagazine += Transfer;
        ReserveAmmo -= Transfer;
    }
    TransitionTo(EVGWeaponState::Ready);
    BroadcastAmmo();
}
```

### 4. Interagir é pedir

🔁 **O que havia:** o `UVGInteractionComponent::TryInteract` (Capítulo 19) chamava `Interact` no alvo em foco. **O problema:** no cliente, o alvo é uma cópia; a estação de cura recusa por não ter autoridade (Capítulo 65). **A solução:** o foco continua local (é apresentação: o *prompt* na tela), e o uso vira pedido. O servidor confere alcance com folga e reavalia `CanInteract` com o estado dele.

```cpp
// VGInteractionComponent.h (adições do Cap. 66)
private:
    /** "Quero usar isto." O servidor confere alcance e CanInteract com o estado DELE. */
    UFUNCTION(Server, Reliable)
    void ServerInteract(AActor* Target);

    void InteractWith(AActor* Target);

    /** Folga de alcance no servidor: com latência, o cliente está um pouco à frente. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Interaction", meta = (ClampMin = "0.0"))
    float ServerRangeTolerance = 100.0f;
```

```cpp
// VGInteractionComponent.cpp (alterações do Cap. 66)
UVGInteractionComponent::UVGInteractionComponent()
{
    // ... como no Cap. 19 ...
    SetIsReplicatedByDefault(true); // sem propriedades replicadas, mas precisa receber RPCs
}

void UVGInteractionComponent::TryInteract()
{
    AActor* Focus = FocusedActor.Get();
    if (!Focus)
    {
        return;
    }
    if (GetOwner()->HasAuthority())
    {
        InteractWith(Focus);  // single-player e anfitrião
    }
    else
    {
        ServerInteract(Focus); // cliente: pede
    }
    Scan(); // atualiza o prompt já; o resultado real chega replicado
}

void UVGInteractionComponent::InteractWith(AActor* Target)
{
    UObject* Interactable = ResolveInteractable(Target);
    if (Interactable && IVGInteractable::Execute_CanInteract(Interactable, GetOwner()))
    {
        IVGInteractable::Execute_Interact(Interactable, GetOwner());
    }
}

void UVGInteractionComponent::ServerInteract_Implementation(AActor* Target)
{
    const APawn* Pawn = Cast<APawn>(GetOwner());
    if (!Target || !Pawn || !Target->GetRootComponent())
    {
        return;
    }
    // Distância até a CAIXA do alvo, não ao pivô: uma porta larga tem o pivô na dobradiça.
    const float MaxDistance = InteractionRange + ServerRangeTolerance;
    const float DistanceSq = Target->GetRootComponent()->Bounds.ComputeSquaredDistanceFromBoxToPoint(Pawn->GetPawnViewLocation());
    if (DistanceSq > FMath::Square(MaxDistance))
    {
        return; // regra: recusa silenciosa
    }
    InteractWith(Target); // CanInteract de novo, agora com o estado do servidor
}
```

O servidor **não** refaz o *sweep* de foco do cliente. Com latência, o jogador já pode ter virado a câmera, e um *sweep* no servidor recusaria interações honestas. A distância com folga e o `CanInteract` com o estado autoritativo bastam para impedir o que importa: usar algo do outro lado do mapa, ou algo que não está disponível.

### 5. Avisar o dono da própria morte

🔁 **O que havia:** `HandlePawnDied` (Capítulo 22, servidor desde o 64) empilhava o modo `Dead`, que só funciona em controller local. **O problema:** no servidor, o controller de um cliente remoto não é local, e o cliente fica preso (Q4). **A solução:** o servidor decide e avisa; o cliente aplica o que é dele (câmera e modo de input).

```cpp
// VGPlayerController.h (adições do Cap. 66)
public:
    virtual void AcknowledgePossession(APawn* P) override;

protected:
    /** O servidor avisa o dono: o seu corpo morreu. No anfitrião e em single-player, executa localmente. */
    UFUNCTION(Client, Reliable)
    void ClientOnPawnDied(APawn* DeadPawn);
```

```cpp
// VGPlayerController.cpp (alterações do Cap. 66)
void AVGPlayerController::HandlePawnDied(APawn* DeadPawn)
{
    UnPossess();               // decisão: no servidor
    ClientOnPawnDied(DeadPawn); // apresentação e input: no dono
}

void AVGPlayerController::ClientOnPawnDied_Implementation(APawn* DeadPawn)
{
    if (DeadPawn)
    {
        SetViewTarget(DeadPawn); // a câmera fica no corpo por um instante (Cap. 22)
    }
    PushInputMode(EVGInputMode::Dead);
}

void AVGPlayerController::AcknowledgePossession(APawn* P)
{
    Super::AcknowledgePossession(P);
    // O cliente reconhece o corpo novo (respawn): sai do modo Dead.
    if (GetCurrentInputMode() == EVGInputMode::Dead)
    {
        PopInputMode(EVGInputMode::Dead);
    }
}
```

O `OnPossess` do Capítulo 64 continua cobrindo o anfitrião; se a engine também chamar `AcknowledgePossession` para ele, a verificação do modo atual impede o segundo `Pop`. ⚠️ Confira com um log em qual dos dois o anfitrião passa na sua versão.

### 6. O *kill feed*

```cpp
// VGArenaGameState.h (adições do Cap. 66)
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGArenaKillSignature, APlayerState*, Killer, APlayerState*, Victim);

public:
    /** Linha do kill feed para todos. O placar (estado) continua nos PlayerStates. */
    UFUNCTION(NetMulticast, Reliable)
    void MulticastKillFeed(APlayerState* Killer, APlayerState* Victim);

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Arena")
    FVGArenaKillSignature OnKill;
```

```cpp
// VGArenaGameState.cpp (Cap. 66)
void AVGArenaGameState::MulticastKillFeed_Implementation(APlayerState* Killer, APlayerState* Victim)
{
    OnKill.Broadcast(Killer, Victim); // WBP_KillFeed; o marcador de abate da HUD compara Killer com o próprio PlayerState
}

// AVGArenaGameMode::ScoreDeath (adição), depois de pontuar:
//   GetGameState<AVGArenaGameState>()->MulticastKillFeed(KillerState, VictimState);
```

O marcador de abate do Capítulo 27 ouvia `Event.Actor.Died` no barramento, que agora só existe no servidor (Q7). A HUD passa a ouvir `OnKill` do `GameState` e mostra o marcador quando o `Killer` é o `PlayerState` do próprio jogador. O barramento continua sendo o lugar certo para os **sistemas do servidor**; a HUD de um cliente precisa de um evento que atravesse a rede.

### Explicação das decisões

- **`_Validate` só com forma.** O identificador repetido ou fora de ordem é impossível num RPC confiável honesto, porque a entrega é ordenada e sem duplicata. Todo o resto (morto, sem munição, recarregando, cadência, origem) é regra, e regra se recusa em silêncio.
- **Disparo confiável.** Cada disparo muda a munição e pode matar alguém; perdê-lo seria um "tiro que sumiu". A cadência da Arena (até ~12 por segundo, no fuzil) está longe de estourar a fila de confiáveis. Uma metralhadora com cadência muito alta num jogo com muitos jogadores mereceria outro desenho (disparos agrupados num pedido).
- **Rastro não confiável.** Um rastro perdido é invisível como perda.
- **`ClientConfirmHit` não confiável.** É frequente numa rajada, e a vida do alvo é o estado verdadeiro. Um marcador perdido incomoda; uma fila de confiáveis cheia derruba a conexão.
- **Morte confiável.** Perder esse aviso deixa o jogador preso.
- ***Kill feed* confiável e *multicast*.** É raro (no máximo algumas vezes por minuto), e uma linha faltando é notada. Quem entra depois não recebe linhas antigas, e não precisa: o placar, que é estado, está nos `PlayerState`s.
- **Interação com folga de alcance e sem refazer o foco.** O que o servidor protege é a regra (perto e disponível), não a mira exata.
- **Recarga com a munição no servidor.** O cliente recarrega para a animação e o estado da arma, mas não mexe na munição: mexer seria escrever num estado replicado no cliente, o cisma do Capítulo 64. O Capítulo 67 troca isso por predição com reconciliação.
- **Tolerâncias como propriedades editáveis.** Os valores (1 m, 3 disparos, 0,15 s) são pontos de partida. Calibrá-los é medir.

---

## Projeto Arena — os clientes falam

Rode como listen server, primeiro sem latência, depois com 100 ms e 2% de perda.

- **O cliente atira.** O anfitrião sofre dano, morre, o placar sobe, o *kill feed* aparece nas duas telas, e o marcador de abate aparece só para quem abateu (Q7).
- **O cliente morre direito.** Entra no modo `Dead`, a câmera fica no corpo e, 3 segundos depois, ele renasce e volta ao controle (Q4).
- **O cliente usa a estação de cura.** A luz muda nas duas telas.
- **Com 100 ms, dois incômodos novos ficam evidentes:**
  - **Q9, tiro atrasado.** O som e o clarão saem na hora (são do dono), mas o rastro e o impacto aparecem um RTT depois do clique, e a munição na HUD também cai atrasada. Numa rajada, o número da munição "anda atrás" dos tiros.
  - **Q10, "mas eu acertei!".** Mirando num alvo que corre de lado, os tiros que acertam na tela do cliente erram no servidor.

Faça um teste a mais: com 300 ms, recarregue e atire imediatamente várias vezes. Com `ReloadGraceTime = 0`, o primeiro tiro depois da recarga some; com 0,15 s, ele sai na maioria das vezes. A carência é a diferença entre um jogo que "come tiros" e um que não come.

| # | Quebra | Depois do Cap. 66 |
|---|---|---|
| Q1 | Dano fantasma | ✅ O cliente atira pelo servidor |
| Q4 | Morte pela metade | ✅ Resolvida: `ClientOnPawnDied` + `AcknowledgePossession` |
| Q7 | HUD surda | ✅ Resolvida: `ClientConfirmHit` e `MulticastKillFeed` |
| Q9 | Tiro atrasado | ❌ Visível a 100 ms: rastro, impacto e munição esperam o servidor (Cap. 67) |
| Q10 | "Mas eu acertei!" | ❌ Visível a 100 ms (Cap. 68) |
| Q3, Q8 | Corrida elástica, pulo que volta | Sem mudança (Cap. 67) |

---

## Decisões arquiteturais

1. **Disparo por pedido individual** (origem, mira comprimida, identificador): o cliente decide quando, o servidor decide o que acontece.
2. **Forma no `_Validate` (desconecta); regra no corpo (recusa em silêncio, com folga).**
3. **Folgas explícitas e calibráveis:** balde de fichas para cadência, tolerância de origem, carência de recarga, folga de alcance.
4. **Confiabilidade pelo custo da perda:** pedidos e avisos raros confiáveis; efeitos e confirmações frequentes não confiáveis.
5. **Eventos com duração ou que precisam ser vistos por quem chega depois viram estado no servidor.**
6. **Apresentação do próprio disparo imediata no dono;** a dos outros por *multicast*, ignorada pelo dono.
7. **O barramento é para sistemas do servidor;** eventos para a HUD de um cliente atravessam a rede por RPC.

---

## Armadilhas

- **RPC `Server` num ator sem dono** (ou de outro jogador): descartado, com um aviso no log que é fácil de perder.
- **Componente sem `SetIsReplicatedByDefault(true)`**: o RPC não encontra o componente.
- **RPC confiável a cada quadro**: com perda de pacotes, a fila de confiáveis enche e a conexão cai.
- **Regra no `_Validate`**: desconectar quem atirou "durante a recarga" é punir a latência.
- **Validação por intervalo instantâneo**: o jitter junta pedidos, e o servidor recusa disparos honestos. Meça a cadência média.
- **Esperar ordem entre RPC e propriedade**, ou entre atores: o ponteiro do RPC pode chegar antes do ator, e o RPC pode chegar antes da propriedade que ele pressupõe.
- **`NetMulticast` para estado**: quem entra depois, ou volta à relevância, nunca recebe.
- **Tocar o efeito do próprio disparo duas vezes**: uma no `FireOnce`, outra no *multicast*. Filtre pelo dono.
- **Esquecer que o `Client` RPC executa no servidor** quando o dono é o anfitrião ou não há dono. Código no `_Implementation` que assume "estou num cliente" quebra no anfitrião e com a IA.
- **Refazer no servidor a verificação perceptiva do cliente** (o foco da interação, a linha de visão exata): com latência, ela recusa ações honestas.

---

## Exercício

**Parte 1 — o pedido de disparo (2 h).** Implemente `FVGShotRequest`, `VGNetRules` com o teste, e os RPCs da arma (`ServerFireShot`, `ServerReload`, `MulticastShotFx`, `ClientConfirmHit`). Confira, nas três configurações (anfitrião atirando, cliente atirando, *Play As Client*), que o dano, o rastro e o marcador aparecem onde devem, e que o som do disparo não toca duas vezes para quem atira.

**Parte 2 — interação e morte (1 h).** Implemente o `ServerInteract`, o `ClientOnPawnDied` e o `AcknowledgePossession`. Teste a estação de cura pelo cliente, e a morte e o respawn do cliente, com 100 ms.

**Parte 3 — calibrar as folgas (1 h).** Com 100 ms, 30 ms de variação e 2% de perda, conte quantos disparos o servidor recusa numa rajada longa do fuzil. Ajuste `FireBurstAllowance` até a recusa de um cliente honesto ser zero numa rajada de 30 disparos. Repita com `MaxOriginError` correndo e pulando. Registre os valores no `DEVLOG.md`, com as condições de rede em que foram medidos.

**Parte 4 — *kill feed* e HUD (45 min).** Crie o `WBP_KillFeed` e troque o marcador de abate da HUD para ouvir `OnKill`. Confirme que um cliente que entra no meio da partida vê o placar certo e não vê linhas antigas do *kill feed*, e explique por que isso é o comportamento desejado.

---

## Desafio — "O cliente mentiroso"

Escreva, numa *build* de desenvolvimento, um "modo trapaça" ativado por CVar no **cliente**, com quatro trapaças:

1. reenviar o mesmo `ShotId` duas vezes;
2. informar a origem 5 m à frente da câmera;
3. disparar a 3× a cadência da arma (mandando `ServerFireShot` direto, sem passar pela arma);
4. girar a mira instantaneamente para a cabeça do adversário mais próximo antes de cada disparo.

Para cada uma, registre no `DEVLOG.md` o que o servidor faz: desconecta, recusa em silêncio ou **aceita**. A quarta será aceita, porque é uma trapaça de input (Capítulo 64). Escreva em um parágrafo que informação o servidor teria para **suspeitar** dela (velocidade angular da mira entre movimentos, por exemplo) e por que transformar essa suspeita em punição automática é perigoso.

---

## Uso de IA

1. **Para revisar RPCs:**
   > "Revise estes RPCs de Unreal Engine 5. Para cada um, diga: onde executa quando chamado pelo anfitrião, por um cliente e num servidor dedicado; se a cadeia de posse permite a chamada; se a confiabilidade combina com a frequência; se a validação está separada entre forma (_Validate) e regra (corpo); e se alguma regra pune clientes honestos com latência. [código]"

2. **Para decidir estado ou evento:**
   > "Num FPS multiplayer com servidor autoritativo, classifique cada uma destas informações como propriedade replicada, RPC Server, RPC Client ou NetMulticast, e confiável ou não: [lista]. Para cada escolha, diga o que acontece se a mensagem se perder e o que acontece com um jogador que entra depois."

3. **Para calibrar folgas:**
   > "Tenho um balde de fichas para validar a cadência de disparos no servidor, uma tolerância de origem e uma carência de recarga. Proponha um protocolo de medição com emulação de rede (latências e perdas a testar, quantas rajadas, o que registrar) para escolher valores que não recusem clientes honestos e limitem o ganho de um trapaceiro."

**Cuidado específico:** a IA tende a sugerir `Reliable` por padrão ("para garantir") e `_Validate` com regras de jogo ("para segurança"). As duas sugestões parecem prudentes e são perigosas aqui: a primeira derruba conexões com perda de pacotes, a segunda desconecta jogadores honestos com latência. Peça sempre a justificativa pela frequência da mensagem e pelo que acontece com um cliente honesto a 150 ms.

---

## Checklist

- [ ] Sei onde executa cada tipo de RPC, conforme quem chama e quem é dono do ator.
- [ ] Sei montar e verificar a cadeia de posse de um ator até a conexão, e sei que ela muda com a possessão.
- [ ] Sei escolher entre confiável e não confiável pelo custo da perda e pela frequência.
- [ ] Sei decidir entre RPC e propriedade pensando em perda, entrada tardia e relevância.
- [ ] Separo validação de forma (`_Validate`) de regra (corpo), e sei calibrar as folgas.
- [ ] Implementei o balde de fichas e o teste dele.
- [ ] Na Arena, o cliente atira, recarrega, usa a estação, morre e renasce corretamente, e vê o *kill feed*.
- [ ] Reproduzo Q9 e Q10 com 100 ms e sei explicar a causa de cada uma.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Remote Procedure Calls* (com a tabela de onde cada RPC executa), e a página sobre *ownership* de atores e conexões.
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** o capítulo sobre RPCs e o de segurança.
- **GDC Vault** (gdcvault.com): *Overwatch Gameplay Architecture and Netcode*, de Timothy Ford (GDC 2017), para ver como um jogo de ação competitivo organiza o que o cliente envia e o que o servidor decide.
- **Gabriel Gambetta, "Fast-Paced Multiplayer"** (gabrielgambetta.com): a parte II prepara o próximo capítulo (por que o cliente não pode esperar a resposta do servidor).

---

➡️ **Próximo:** [Capítulo 67 — Prediction](cap-67-prediction.md)

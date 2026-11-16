# Capítulo 67 — Prediction

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar por que um cliente de FPS não pode esperar a resposta do servidor para mostrar o resultado das próprias ações;
- descrever o algoritmo de **predição no cliente com reconciliação no servidor**: números de sequência, movimentos pendentes, estado autoritativo e reexecução;
- ler o `UCharacterMovementComponent` como um estudo de caso completo desse algoritmo, com os nomes reais das peças (movimentos salvos, flags comprimidas, correção, replay);
- classificar as variáveis de um sistema preditivo em **entrada**, **estado simulado**, **dados** e **efeito colateral**, e saber o que fazer com cada uma;
- estender o CMC com flags próprias para a corrida e a mira, e mover o *coyote time* para o relógio do movimento;
- prever o disparo com a **semente por disparo** do Capítulo 27, agora compartilhada, e reconciliar a munição com o mesmo padrão do movimento.

---

## Contexto

Três quebras do inventário têm a mesma causa. Em **Q3**, o cliente corre e é puxado para trás. Em **Q8**, o pulo na beirada às vezes é desfeito. Em **Q9**, o tiro "sai depois": o som é imediato, mas o rastro, o impacto e a munição esperam o servidor. Nos três casos, o cliente e o servidor discordam sobre **o que acabou de acontecer**, e o cliente perde a discussão de forma visível.

O livro deixou três promessas para este capítulo:

- o Capítulo 17 marcou a troca de `MaxWalkSpeed` da corrida com `// Simplificação:`, dizendo que, em rede, ela geraria correções, e que a solução era "incorporar o estado de corrida ao sistema de movimento preditivo do CMC";
- o Capítulo 25 disse que o *coyote time* e a aterrissagem dura precisariam ser integrados ao movimento preditivo;
- o Capítulo 27 semeou a dispersão por disparo dizendo que, "se o cliente e o servidor conhecem a mesma semente para cada disparo, ambos calculam a mesma direção sem enviar a direção pela rede".

Este capítulo cumpre as três. Uma delas vai se revelar menor do que parecia, e a leitura cuidadosa do fluxo do CMC é o que mostra isso.

---

## 67.1 Por que o cliente não pode esperar

Com 100 ms de ida e volta, um FPS que espera o servidor funciona assim:

```text
 t =   0 ms   o jogador aperta W
 t =  50 ms   o servidor recebe, move o corpo
 t = 100 ms   o cliente recebe a nova posição e a desenha
```

A 60 quadros por segundo, são **seis quadros** entre a intenção e o primeiro movimento visível. O jogador não descreve isso como "latência". Ele descreve como **controle mole**, "pesado", "com *input lag*", e nenhum ajuste de *game feel* (Capítulos 17 e 25) compensa. Com a câmera, é pior: uma mira que responde 100 ms depois do mouse é injogável.

A saída é o cliente **não esperar**: aplicar o input imediatamente na sua cópia, como se ele fosse o servidor, e lidar depois com o caso em que o servidor discorda. Isso é **predição**. Como o cliente roda o mesmo código que o servidor, com o mesmo input, ele acerta quase sempre. O trabalho de engenharia está no "quase".

---

## 67.2 Predição e reconciliação

O algoritmo, como Gabriel Gambetta o apresenta na segunda parte da série *Fast-Paced Multiplayer*, tem quatro peças.

**1. Cada input tem um número de sequência.** O cliente numera cada pedido ("input 41: andar para a frente por 16 ms").

**2. O cliente aplica e guarda.** Aplica o input na sua cópia (predição), envia ao servidor e guarda o input numa lista de **pendentes**.

**3. O servidor responde com estado e com o último input processado.** "Depois do input 41, você está em (1200, 340)."

**4. O cliente reconcilia.** Volta ao estado do servidor, descarta da lista os inputs até o 41 (já incorporados), e **reaplica** os pendentes (42, 43, 44...) sobre o estado do servidor. O resultado é a melhor estimativa do presente: o passado confirmado mais o que ainda está em trânsito.

```text
 Cliente                                  Servidor
 input 41 ─► aplica, guarda ─────────────►
 input 42 ─► aplica, guarda ───────┐       aplica 41 → estado S41
 input 43 ─► aplica, guarda ──┐    │   ◄── "após 41: S41"
                              │    │
 recebe S41: volta a S41,     │    └─────► aplica 42
   reaplica 42 e 43           └──────────► aplica 43
```

Se o servidor concordou com a previsão do 41, a reconciliação não muda nada visível. Se discordou (outro jogador bloqueou a passagem, o servidor achou que o pulo não era possível), o cliente salta para a posição corrigida **mais** o efeito dos inputs em trânsito. É a **correção**: o tranco que o jogador sente.

### O que precisa ser verdade

A predição só acerta se o cliente simular **igual** ao servidor. Isso não exige determinismo bit a bit, como no lockstep do Capítulo 63, porque o servidor tolera uma diferença pequena antes de corrigir. Exige que **tudo o que afeta a simulação** esteja disponível igualmente nas duas pontas. Cada variável cai numa de quatro categorias:

| Categoria | O que é | Exemplos na Vigília | Regra |
|---|---|---|---|
| **Entrada** | O que o jogador decide | Aceleração (WASD), pular, agachar, **correr**, **mirar** | Viaja no movimento enviado ao servidor |
| **Estado simulado** | O que a simulação acumula | Posição, velocidade, modo de movimento, **relógio do *coyote*** | É reconciliado. Se o servidor não o envia de volta, o cliente o **salva** com o movimento e o **restaura** no replay |
| **Dados** | Parâmetros | Velocidades do perfil (Capítulo 25), multiplicador de mira da arma | Iguais nas duas pontas; mudanças só com autoridade, e replicadas |
| **Efeito colateral** | O que a simulação **provoca** fora dela | Tag `Status.Movement.Sprinting`, som de passos, tremor de câmera, ruído para a IA | **Nunca** dentro do replay: senão acontece duas vezes |

Toda quebra de predição da Vigília é uma variável na categoria errada.

> 🌉 **Ponte:** é **UI otimista** com reconciliação, como um editor colaborativo que aplica a sua digitação na hora e, quando o servidor devolve a versão canônica, reaplica as operações locais ainda não confirmadas sobre ela (a ideia por trás de *operational transformation*). Também é *event sourcing*: o estado é o resultado de aplicar uma sequência de comandos, e reconstruí-lo é reaplicar.
>
> 🧱 **Onde a ponte cai:** num editor de texto, as operações dos usuários raramente interagem na mesma posição, e uma reconciliação de 200 ms passa despercebida. Num FPS, a reconciliação acontece dezenas de vezes por segundo, o estado (posição) é contínuo e qualquer diferença vira um tranco visível. E o replay precisa caber num quadro: o cliente reexecuta 5 ou 10 movimentos de física dentro dos 16 ms do quadro em que a correção chegou.

---

## 67.3 O `CharacterMovementComponent` como estudo

O CMC implementa o algoritmo de 67.2 para o movimento do personagem, e é a melhor peça de engenharia de rede da Unreal para estudar. Os nomes abaixo são os do código da engine; ⚠️ nas versões recentes, os RPCs de movimento são **empacotados** (`ServerMovePacked`, `ClientMoveResponsePacked`), mas a estrutura é a mesma, e os nomes antigos continuam úteis para ler o código.

```text
 CLIENTE (autonomous proxy), a cada quadro (ReplicateMoveToServer):
   1. o input vira Acceleration e flags (pular, agachar, 4 flags livres)
   2. cria um FSavedMove_Character e chama SetMoveFor: guarda o INPUT e o ESTADO INICIAL
   3. executa o movimento localmente (PerformMovement)                 ← predição
   4. guarda o movimento salvo na lista de pendentes
   5. envia ao servidor: timestamp, aceleração, flags comprimidas, posição final
      (movimentos consecutivos iguais podem ser COMBINADOS num só: CanCombineWith)

 SERVIDOR, ao receber (ServerMove → MoveAutonomous):
   6. aplica as flags (UpdateFromCompressedFlags) e executa o MESMO movimento
   7. compara a posição final com a do cliente (ServerCheckClientError)
      ├── dentro da tolerância → confirma (ClientAckGoodMove)
      └── fora → manda a correção: posição, velocidade, modo, base (ClientAdjustPosition)

 CLIENTE, ao receber:
   8a. confirmação → descarta os movimentos até aquele timestamp
   8b. correção → volta ao estado do servidor e REEXECUTA os pendentes (ClientUpdatePosition):
       para cada um, PrepMoveFor restaura o que foi salvo, e o movimento roda com
       ACharacter::bClientUpdating = true

 OUTROS CLIENTES (simulated proxy):
   recebem posição, rotação e velocidade replicadas; simulam entre atualizações
   e SUAVIZAM as correções (NetworkSmoothingMode)
```

Duas peças merecem destaque.

**As flags comprimidas.** O movimento salvo envia um byte de flags. Duas são da engine (pular e agachar), e quatro são livres (`FLAG_Custom_0` a `FLAG_Custom_3`) para entradas binárias do jogo. Para mais dados por movimento, as versões recentes oferecem estruturas próprias de dados de movimento (`FCharacterNetworkMoveData`). ⚠️ Confira a API da sua versão se precisar de mais que quatro bits.

**A tolerância.** O servidor só corrige quando o erro passa de um limite configurável (no `AGameNetworkManager`; ⚠️ confira o nome da propriedade na sua versão). Pequenas diferenças de ponto flutuante não geram correção. É isso que permite ao CMC não exigir determinismo exato.

### Por que agachar funciona e correr não (Q3)

Agachar é uma **entrada** que viaja no movimento: `bWantsToCrouch` é uma das flags da engine. O servidor recebe "quer agachar" junto com cada movimento e simula agachado. Os dois lados concordam.

Correr, no Capítulo 17, era uma troca de `MaxWalkSpeed` feita **fora** do movimento, por um handler de input. O cliente simula a 480 cm/s; o servidor, que nunca soube da corrida, simula o mesmo input a 280 cm/s. A cada movimento, a posição do cliente se afasta da do servidor; quando o erro passa da tolerância, o servidor corrige; o cliente volta, reexecuta os pendentes a 480, e se afasta de novo. É o efeito elástico de Q3: uma correção atrás da outra.

Na tabela de 67.2, a corrida estava na categoria **dados** (um parâmetro trocado à mão), quando é uma **entrada**.

---

## 67.4 O código da Vigília à luz da predição

Com as quatro categorias, cada sistema de movimento das Partes III e IV pode ser julgado:

| Sistema | Capítulo | Como estava | Categoria real | Veredicto |
|---|---|---|---|---|
| Correr | 17 | Troca de `MaxWalkSpeed` no handler de input | Entrada | ❌ Q3. Vira flag `FLAG_Custom_0`; a regra "só para a frente" passa a usar a aceleração, que existe nas duas pontas |
| Mirar (velocidade reduzida) | 26 | Multiplicador aplicado na velocidade máxima | Entrada | ❌ Mesmo problema da corrida, mais suave. Vira `FLAG_Custom_1` |
| *Coyote time* | 25 | Janela medida com `GetWorld()->GetTimeSeconds()` | Estado simulado | ❌ Q8. Cada máquina mede com o próprio relógio, e o servidor processa os movimentos em lotes, com outro tempo de mundo. Vira um relógio **de movimento**, salvo e restaurado |
| *Jump buffer* | 25 | Pedido guardado com o relógio do mundo, executado ao pousar | Entrada (decisão local) | ✅ A decisão é do cliente, e o resultado (`bPressedJump`) já viaja como flag. Só precisa de uma guarda contra o replay |
| Aterrissagem dura | 25 | Corta a velocidade horizontal no `Landed` | Estado simulado | ✅ **Já está dentro do fluxo**: o `Landed` é chamado pelo próprio CMC durante o passo de movimento, nas duas pontas. O temor do Capítulo 25 não se confirma |
| Câmera ao agachar, tremor ao pousar, passos | 17, 18 | Locais | Efeito colateral | ✅ Desde que não rodem no replay |

A aterrissagem dura merece uma explicação, porque contradiz uma frase do Capítulo 25. Ao rastrear o fluxo, o `Landed` acontece assim: `PerformMovement` → `PhysFalling` → `ProcessLanded` → `ACharacter::Landed`. Ele roda **dentro** do passo de movimento, no cliente (na predição e no replay) e no servidor (no `MoveAutonomous`). A intervenção na velocidade é, portanto, parte da simulação nas duas pontas, com os mesmos dados (o perfil é um Data Asset). Não é preciso fazer nada. ⚠️ Confirme com `p.NetShowCorrections 1` no seu projeto: se aparecerem correções em aterrissagens duras com latência, alguma diferença de dados entre as pontas está escapando. O tremor de câmera dentro do mesmo `Landed` é efeito colateral, e precisa da guarda do replay.

O *coyote time* é o caso oposto: parece estar dentro do fluxo (é consultado pelo `CanJumpInternal`, que o CMC chama nas duas pontas), e não está, porque o **relógio** que ele usa não é o do movimento. O servidor executa os movimentos do cliente com os *deltas* que o cliente mandou, mas o `GetTimeSeconds()` dele avança no ritmo do servidor, e os movimentos chegam em lotes. A janela que o cliente mediu como 0,12 s pode valer 0,18 s ou 0,05 s no servidor. O resultado é Q8: o cliente pula, o servidor acha que a janela fechou, e corrige.

---

## 67.5 Predizer o disparo

O movimento é a predição mais famosa, e não é a única. Q9 é a mesma pergunta para a arma: o que o cliente pode mostrar **antes** de o servidor responder?

| O quê | Antes (Cap. 66) | Agora | Como |
|---|---|---|---|
| Som e clarão do cano | Imediato | Imediato | Apresentação local |
| Coice da câmera | Imediato | Imediato | Local; chega ao servidor pela mira do movimento |
| Rastro e impacto em paredes | Um RTT depois | **Imediato** | Predição com a mesma semente |
| Impacto em personagens | Um RTT depois | **Na confirmação** | Decisão de design (abaixo) |
| Marcador de acerto | Na confirmação | Na confirmação | O acerto é do servidor |
| Munição | Um RTT depois | **Imediata** | Predição com reconciliação |
| Dano | Servidor | Servidor | Nunca previsto |

### A mesma direção nas duas pontas

Para o rastro previsto acabar no mesmo lugar que o tiro do servidor, as duas pontas precisam calcular **a mesma direção**. Ela depende de três coisas:

1. **A mira.** O Capítulo 66 comprimiu a mira a 16 bits por eixo **no código**. O cliente usa `Request.GetAim()`, a mira descomprimida, e não a rotação original da câmera. Os dois lados partem do mesmo número.
2. **O ângulo de dispersão.** Depende do alfa de mira e do *bloom*, que só o cliente conhece. O cliente o **envia** no pedido. O servidor não consegue recalculá-lo, mas consegue **validar a faixa**: nunca menor que a dispersão mínima da arma (mira total, parado) e nunca absurda.
3. **A semente.** O Capítulo 27 semeava com `HashCombine(GetUniqueID(), ShotCounter)`. O `GetUniqueID()` é um índice de objeto **local a cada processo**: a cópia da arma no cliente tem outro número. 🔁 A semente base passa a ser um `NetSeed` sorteado no servidor e replicado só para o dono, combinado com o `ShotId` do pedido. Mesma semente, mesmo `FRandomStream`, mesmo `VRandCone`, mesma direção.

Era exatamente a promessa do Capítulo 27: a direção não viaja pela rede; viajam a mira, o ângulo e o número do disparo, e cada lado a recalcula.

⚠️ **O custo de segurança.** Um cliente que conhece a semente pode calcular, antes de atirar, para onde a dispersão vai, e compensar a mira. É uma trapaça de input (Capítulo 64) que a predição torna possível. **[INFERÊNCIA]** Jogos competitivos ponderam esse risco contra a precisão da predição; alternativas incluem dispersões que não dependem de sorteio (padrões fixos) e sementes que o cliente só conhece depois do disparo. Para a Arena, o risco está registrado e aceito.

### Impacto em personagens: só na confirmação

O rastro previsto termina onde o traço do **cliente** bateu. Se bateu numa parede, o servidor quase sempre concorda, porque paredes não se movem. Se bateu num personagem, o servidor pode discordar (Q10, no próximo capítulo). Mostrar o efeito de impacto num corpo que o servidor diz que não foi atingido é pior do que atrasar o efeito 50 ms: o jogador **vê** o acerto que não contou. A Arena mostra, na hora, os impactos em paredes, e espera a confirmação para os impactos em personagens.

**[INFERÊNCIA]** É uma escolha que shooters comerciais parecem fazer de formas diferentes, e que os jogadores percebem: há jogos em que o efeito de sangue aparece na hora e o dano "não sai", e jogos em que o efeito só aparece com o dano. Não há informação pública detalhada sobre a escolha de cada um.

### Munição: o mesmo padrão do movimento

A munição no Capítulo 66 era replicada só para o dono, e caía um RTT depois do disparo. A predição segue a receita de 67.2, aplicada a um inteiro:

- o cliente decrementa ao disparar (predição) e lembra o último `ShotId` enviado;
- o servidor, ao processar um pedido (aceito **ou** recusado), responde com o último `ShotId` processado e a munição dele (`ClientAckAmmo`);
- o cliente reconcilia: **munição confirmada menos os disparos em trânsito**.

Se o servidor recusou um disparo (cadência, recarga), a confirmação traz a munição sem aquele decremento, e o cliente "devolve" a bala. Se aceitou todos, o número não muda. É o algoritmo do CMC com uma variável só, e é por isso que ele merece um teste.

---

## Estudos de caso

### Call of Duty e Battlefield — o disparo que sai na hora

**[FATO PÚBLICO, observável jogando]** Em Call of Duty e Battlefield, mesmo com latência alta, o clarão do cano, o coice e o som do disparo acontecem no instante do clique. Com latência alta, o que atrasa ou falha são o marcador de acerto e o dano, e não a resposta da arma.

**[INFERÊNCIA]** A apresentação do disparo é prevista no cliente, e a decisão do acerto é do servidor: a mesma divisão da tabela de 67.5. A sensação de responsividade de uma arma está quase toda na parte prevista. Um jogador perdoa um marcador atrasado; não perdoa uma arma que "demora para disparar".

**Lição para a Arena:** tudo o que é apresentação do próprio jogador deve ser imediato. O que é decisão espera o servidor, e o design (o marcador) é feito para tolerar a espera.

### Overwatch — predição além do movimento

**[FATO PÚBLICO]** Na GDC de 2017, Timothy Ford, da Blizzard, apresentou *Overwatch Gameplay Architecture and Netcode* (disponível no GDC Vault), sobre a arquitetura do jogo (um sistema de entidades e componentes) e o modelo de rede, incluindo como o cliente prevê as próprias ações e corrige previsões erradas.

**[INFERÊNCIA]** Num jogo com dezenas de habilidades por personagem, prever só o movimento não basta: habilidades também precisam responder no clique. Isso empurra a arquitetura para separar, em todo sistema, entrada, estado simulado e efeito colateral, a tabela de 67.2 aplicada ao jogo inteiro.

**Lição para a Arena:** o padrão que este capítulo aplica à munição serve a qualquer recurso que o jogador gasta e o servidor confirma. A Unreal tem uma versão genérica dessa ideia no **Gameplay Ability System**, com chaves de predição (`FPredictionKey`) que ligam efeitos previstos à confirmação do servidor; está fora do escopo do livro, e é o lugar para olhar quando o número de habilidades crescer.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Predição no cliente | UI otimista | Acontece a cada quadro, sobre estado contínuo |
| Reconciliação | Rebase de operações locais sobre a versão do servidor; OT/CRDT | Precisa caber num quadro; reexecuta física |
| Movimentos pendentes | Fila de comandos não confirmados (*outbox*) | Consumida por *timestamp*, combinada quando possível |
| Flags comprimidas | Campos compactos num protocolo binário | Quatro bits livres: o orçamento é real |
| Semente compartilhada | Geração determinística a partir de uma *seed* (testes reproduzíveis) | O cliente que conhece a semente pode trapacear |
| Efeito colateral fora do replay | Idempotência de *handlers* em reprocessamento | Aqui é o contrário: não reexecutar, em vez de reexecutar com segurança |
| Tolerância de correção | Limiar de divergência antes de ressincronizar | O limiar é sentido pelo jogador como "tranco" |

---

## Unreal Engine: o que existe

- **O CMC com predição e reconciliação** para o movimento: movimentos salvos (`FSavedMove_Character`), dados de predição do cliente (`FNetworkPredictionData_Client_Character`), flags comprimidas e livres, combinação de movimentos, correções suavizadas.
- **Extensão por subclasse**: `UCharacterMovementComponent` derivado, com `GetPredictionData_Client`, `UpdateFromCompressedFlags`, `GetMaxSpeed`, `OnMovementUpdated`; movimento salvo derivado com `Clear`, `GetCompressedFlags`, `CanCombineWith`, `SetMoveFor`, `PrepMoveFor`. O personagem troca o componente com `ObjectInitializer.SetDefaultSubobjectClass`.
- **Modos de movimento próprios** (`MOVE_Custom`, `PhysCustom`) para física diferente (deslizar, escalar).
- **Depuração**: `p.NetShowCorrections 1` desenha as correções; a emulação de rede do PIE.
- **Predição genérica**: o Gameplay Ability System (chaves de predição), o plugin *Network Prediction* e o plugin **Mover** (um componente de movimento mais novo). ⚠️ Os dois plugins estão em estado experimental ou beta conforme a versão: **verifique o estado na sua versão** antes de adotá-los.

O que **não** existe pronto: predição de disparo, reconciliação de munição e a classificação das suas variáveis. É o código deste capítulo.

---

## Abordagens

Como fazer a corrida funcionar em rede?

| Critério | A. RPC "corri/parei" + booleano replicado | **B. Flag própria no movimento salvo** | C. Modo de movimento próprio (`MOVE_Custom`) | D. Plugin Mover / Network Prediction |
|---|---|---|---|---|
| **Complexidade** | Baixa | Média: três classes pequenas | Alta: física própria | Alta: outra arquitetura |
| **Performance** | Um RPC por troca | Um bit por movimento | Um bit + a física | Depende do plugin |
| **Correção** | **Errada**: o RPC e os movimentos viajam por caminhos sem ordem entre si; nas bordas da corrida, o servidor simula alguns movimentos com a velocidade errada e corrige | Correta: a intenção viaja **dentro** do movimento que ela afeta | Correta | Correta |
| **Extensibilidade** | Ruim | Boa até 4 flags; depois, dados de movimento próprios | A certa para mecânicas com física diferente (deslizar) | Alta |
| **Prototipação** | Imediata | Rápida, depois de pronta | Lenta | Lenta |
| **Adequação à Arena** | Não | **Sim** | Não para correr; sim para deslizar (desafio) | ⚠️ verifique o estado na sua versão |

**Decisão: B.** A abordagem A é o erro mais comum em tutoriais, e o motivo é instrutivo: ela trata uma **entrada** como um **evento**. Os movimentos e o RPC chegam ao servidor por caminhos diferentes, sem ordem garantida entre eles (Capítulo 66), e o servidor aplica a corrida alguns movimentos antes ou depois do cliente. A flag dentro do movimento garante que cada movimento seja simulado com a intenção que o cliente tinha **naquele** movimento.

---

## Implementação

### 1. O componente de movimento da Vigília

```cpp
// Source/Vigilia/Player/VGCharacterMovementComponent.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "VGCharacterMovementComponent.generated.h"

/**
 * CMC da Vigília: corrida e mira como ENTRADAS do movimento (flags), e a janela de coyote
 * como ESTADO simulado no relógio do movimento. Mesma simulação no cliente e no servidor.
 */
UCLASS()
class VIGILIA_API UVGCharacterMovementComponent : public UCharacterMovementComponent
{
    GENERATED_BODY()

    friend class FSavedMove_VG;

public:
    // Entradas: o personagem as define a partir do input; viajam no movimento salvo.
    void SetWantsToSprint(bool bWants) { bWantsToSprint = bWants; }
    void SetWantsToAim(bool bWants) { bWantsToAim = bWants; }

    /** Dado: definido pela arma equipada (Cap. 26), igual nas duas pontas. */
    void SetAimSpeedMultiplier(float Multiplier) { AimSpeedMultiplier = Multiplier; }

    /** Regra da corrida (Cap. 17): quer correr, para a frente, sem agachar, sem mirar. */
    bool IsSprinting() const;

    // Coyote time (Cap. 25), agora no relógio do movimento.
    void OpenCoyoteWindow() { CoyoteClock = 0.0f; }
    void CloseCoyoteWindow() { CoyoteClock = -1.0f; }
    bool IsInCoyoteWindow(float MaxTime) const { return CoyoteClock >= 0.0f && CoyoteClock <= MaxTime; }

    virtual float GetMaxSpeed() const override;
    virtual FNetworkPredictionData_Client* GetPredictionData_Client() const override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Movement", meta = (ClampMin = "0.0"))
    float SprintSpeed = 480.0f;

    /** Corre só se a aceleração estiver neste cone à frente (cosseno: 0.7 ≈ 45°). */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Movement", meta = (ClampMin = "-1.0", ClampMax = "1.0"))
    float SprintForwardDotMin = 0.7f;

protected:
    virtual void UpdateFromCompressedFlags(uint8 Flags) override;
    virtual void OnMovementUpdated(float DeltaSeconds, const FVector& OldLocation, const FVector& OldVelocity) override;

private:
    bool bWantsToSprint = false;     // entrada: FLAG_Custom_0
    bool bWantsToAim = false;        // entrada: FLAG_Custom_1
    float AimSpeedMultiplier = 1.0f; // dado
    float CoyoteClock = -1.0f;       // estado: segundos de queda sem pulo, em TEMPO DE MOVIMENTO; < 0 = fechada
};

/** Movimento salvo: guarda as entradas e o estado inicial; restaura o estado no replay. */
class FSavedMove_VG : public FSavedMove_Character
{
public:
    typedef FSavedMove_Character Super;

    virtual void Clear() override;
    virtual uint8 GetCompressedFlags() const override;
    virtual bool CanCombineWith(const FSavedMovePtr& NewMove, ACharacter* InCharacter, float MaxDelta) const override;
    virtual void SetMoveFor(ACharacter* C, float InDeltaTime, FVector const& NewAccel,
                            FNetworkPredictionData_Client_Character& ClientData) override;
    virtual void PrepMoveFor(ACharacter* C) override;

    bool bSavedWantsToSprint = false;
    bool bSavedWantsToAim = false;
    float SavedCoyoteClock = -1.0f;
};

/** Faz o CMC criar movimentos salvos da Vigília. */
class FNetworkPredictionData_Client_VG : public FNetworkPredictionData_Client_Character
{
public:
    typedef FNetworkPredictionData_Client_Character Super;

    explicit FNetworkPredictionData_Client_VG(const UCharacterMovementComponent& ClientMovement)
        : Super(ClientMovement)
    {
    }

    virtual FSavedMovePtr AllocateNewMove() override { return FSavedMovePtr(new FSavedMove_VG()); }
};
```

```cpp
// Source/Vigilia/Player/VGCharacterMovementComponent.cpp
#include "Player/VGCharacterMovementComponent.h"

#include "GameFramework/Character.h"
#include "Player/VGCharacter.h"

// ---- Movimento salvo -----------------------------------------------------------------

void FSavedMove_VG::Clear()
{
    Super::Clear();
    bSavedWantsToSprint = false;
    bSavedWantsToAim = false;
    SavedCoyoteClock = -1.0f;
}

uint8 FSavedMove_VG::GetCompressedFlags() const
{
    uint8 Result = Super::GetCompressedFlags(); // pular, agachar (da engine)
    if (bSavedWantsToSprint)
    {
        Result |= FLAG_Custom_0;
    }
    if (bSavedWantsToAim)
    {
        Result |= FLAG_Custom_1;
    }
    return Result;
}

bool FSavedMove_VG::CanCombineWith(const FSavedMovePtr& NewMove, ACharacter* InCharacter, float MaxDelta) const
{
    // Movimentos com entradas diferentes não podem virar um só: a intenção mudou no meio.
    const FSavedMove_VG* Other = static_cast<const FSavedMove_VG*>(NewMove.Get());
    if (bSavedWantsToSprint != Other->bSavedWantsToSprint || bSavedWantsToAim != Other->bSavedWantsToAim)
    {
        return false;
    }
    return Super::CanCombineWith(NewMove, InCharacter, MaxDelta);
}

void FSavedMove_VG::SetMoveFor(ACharacter* C, float InDeltaTime, FVector const& NewAccel,
                               FNetworkPredictionData_Client_Character& ClientData)
{
    Super::SetMoveFor(C, InDeltaTime, NewAccel, ClientData);
    // Chamado ANTES de o movimento executar: guarda as entradas e o estado INICIAL.
    if (const UVGCharacterMovementComponent* Move = Cast<UVGCharacterMovementComponent>(C->GetCharacterMovement()))
    {
        bSavedWantsToSprint = Move->bWantsToSprint;
        bSavedWantsToAim = Move->bWantsToAim;
        SavedCoyoteClock = Move->CoyoteClock;
    }
}

void FSavedMove_VG::PrepMoveFor(ACharacter* C)
{
    Super::PrepMoveFor(C);
    // Antes de REEXECUTAR este movimento no replay: restaura o estado que o servidor não manda de volta.
    // (As entradas voltam pelas flags, em UpdateFromCompressedFlags.)
    if (UVGCharacterMovementComponent* Move = Cast<UVGCharacterMovementComponent>(C->GetCharacterMovement()))
    {
        Move->CoyoteClock = SavedCoyoteClock;
    }
}

// ---- Componente ----------------------------------------------------------------------

FNetworkPredictionData_Client* UVGCharacterMovementComponent::GetPredictionData_Client() const
{
    if (!ClientPredictionData)
    {
        UVGCharacterMovementComponent* MutableThis = const_cast<UVGCharacterMovementComponent*>(this);
        MutableThis->ClientPredictionData = new FNetworkPredictionData_Client_VG(*this);
    }
    return ClientPredictionData;
}

void UVGCharacterMovementComponent::UpdateFromCompressedFlags(uint8 Flags)
{
    Super::UpdateFromCompressedFlags(Flags);
    // No servidor: as entradas do cliente PARA ESTE MOVIMENTO. No cliente, no replay: as originais.
    bWantsToSprint = (Flags & FSavedMove_Character::FLAG_Custom_0) != 0;
    bWantsToAim = (Flags & FSavedMove_Character::FLAG_Custom_1) != 0;
}

bool UVGCharacterMovementComponent::IsSprinting() const
{
    if (!bWantsToSprint || bWantsToAim || IsCrouching() || !CharacterOwner)
    {
        return false;
    }
    // A regra "só para a frente" do Cap. 17 usava o input 2D, que só o cliente tem.
    // A ACELERAÇÃO viaja no movimento: as duas pontas aplicam a mesma regra ao mesmo dado.
    const FVector Direction = Acceleration.GetSafeNormal2D();
    return FVector::DotProduct(Direction, CharacterOwner->GetActorForwardVector()) >= SprintForwardDotMin;
}

float UVGCharacterMovementComponent::GetMaxSpeed() const
{
    float Speed = Super::GetMaxSpeed(); // caminhar, agachado, voar, nadar... (da engine)
    if (IsMovingOnGround() || IsFalling())
    {
        if (IsSprinting())
        {
            Speed = SprintSpeed;
        }
        else if (bWantsToAim)
        {
            Speed *= AimSpeedMultiplier;
        }
    }
    return Speed;
}

void UVGCharacterMovementComponent::OnMovementUpdated(float DeltaSeconds, const FVector& OldLocation,
                                                      const FVector& OldVelocity)
{
    Super::OnMovementUpdated(DeltaSeconds, OldLocation, OldVelocity);

    // Estado simulado: avança com o DELTA DO MOVIMENTO, que é o mesmo no cliente e no servidor.
    if (CoyoteClock >= 0.0f && IsFalling())
    {
        CoyoteClock += DeltaSeconds;
    }

    // Efeito colateral (tag de status, FOV): nunca durante o replay de uma correção.
    AVGCharacter* VGOwner = Cast<AVGCharacter>(CharacterOwner);
    if (VGOwner && !VGOwner->bClientUpdating)
    {
        VGOwner->SetSprintingState(IsSprinting());
    }
}
```

### 2. O personagem só declara intenções

🔁 **O que havia:** o `AVGCharacter` decidia a corrida no handler de input e trocava `MaxWalkSpeed` (Capítulo 17), media o *coyote time* com o relógio do mundo (Capítulo 25), e a mira reduzia a velocidade por fora do movimento (Capítulo 26). **O problema:** Q3 e Q8. **A solução:** o personagem passa a criar o CMC da Vigília, e só **declara** intenções; as regras rodam no movimento.

```cpp
// VGCharacter.h (alterações do Cap. 67)
class UVGCharacterMovementComponent;

public:
    explicit AVGCharacter(const FObjectInitializer& ObjectInitializer);

    UVGCharacterMovementComponent* GetVGMovement() const;

    /** Projeção pública do estado de corrida (tags, Cap. 23). Chamado pelo movimento, fora do replay. */
    void SetSprintingState(bool bNewSprinting);

// removidos: LeftGroundTime, bJumpedSinceGrounded (o estado foi para o movimento)
```

```cpp
// VGCharacter.cpp (alterações do Cap. 67)
#include "Player/VGCharacterMovementComponent.h"

AVGCharacter::AVGCharacter(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer.SetDefaultSubobjectClass<UVGCharacterMovementComponent>(
          ACharacter::CharacterMovementComponentName))
{
    // ... o corpo do construtor dos Caps. 17–25, sem mudanças ...
}

UVGCharacterMovementComponent* AVGCharacter::GetVGMovement() const
{
    return CastChecked<UVGCharacterMovementComponent>(GetCharacterMovement());
}

void AVGCharacter::UpdateSprint()
{
    // Antes: decidia e trocava MaxWalkSpeed. Agora só registra a INTENÇÃO; a regra roda no movimento.
    GetVGMovement()->SetWantsToSprint(bWantsToSprint);
}

void AVGCharacter::SetSprintingState(bool bNewSprinting)
{
    if (bNewSprinting == bIsSprinting)
    {
        return;
    }
    bIsSprinting = bNewSprinting;
    if (bIsSprinting) { StatusTags->GrantStatus(TAG_Status_Movement_Sprinting); }
    else              { StatusTags->RevokeStatus(TAG_Status_Movement_Sprinting); }
}

void AVGCharacter::ApplyMovementProfile(UVGMovementProfile* Profile)
{
    // ... como no Cap. 25 ...
    GetCharacterMovement()->MaxWalkSpeed = Profile->WalkSpeed; // dado: igual nas duas pontas
    GetVGMovement()->SprintSpeed = Profile->SprintSpeed;
}

bool AVGCharacter::CanJumpInternal_Implementation() const
{
    if (Super::CanJumpInternal_Implementation())
    {
        return true;
    }
    // Coyote time: a mesma regra do Cap. 25, com o relógio do MOVIMENTO.
    return MovementProfile && !bIsCrouched && GetCharacterMovement()->IsFalling()
        && GetVGMovement()->IsInCoyoteWindow(MovementProfile->CoyoteTime);
}

void AVGCharacter::OnMovementModeChanged(EMovementMode PrevMovementMode, uint8 PreviousCustomMode)
{
    Super::OnMovementModeChanged(PrevMovementMode, PreviousCustomMode);
    UVGCharacterMovementComponent* Move = GetVGMovement();

    // Saiu do chão: abre a janela. Se foi um pulo, o OnJumped a fecha logo em seguida
    // (o CMC muda o modo dentro do DoJump, e o OnJumped vem depois).
    const bool bWasGrounded = (PrevMovementMode == MOVE_Walking || PrevMovementMode == MOVE_NavWalking);
    if (bWasGrounded && Move->IsFalling())
    {
        Move->OpenCoyoteWindow();
    }

    const bool bJustLanded = (PrevMovementMode == MOVE_Falling) && Move->IsMovingOnGround();
    if (bJustLanded)
    {
        Move->CloseCoyoteWindow();
    }

    // Jump buffering (Cap. 25): decisão de INPUT do dono; o pulo resultante viaja como flag.
    // No replay de uma correção, o pulo já foi pedido na execução original: não repita.
    if (bJustLanded && IsLocallyControlled() && !bClientUpdating
        && GetWorld()->GetTimeSeconds() <= JumpBufferedUntil)
    {
        JumpBufferedUntil = -1.0f;
        Jump();
        if (!bJumpHeld)
        {
            GetWorldTimerManager().SetTimerForNextTick(this, &AVGCharacter::StopJumping);
        }
    }
}

void AVGCharacter::OnJumped_Implementation()
{
    Super::OnJumped_Implementation();
    GetVGMovement()->CloseCoyoteWindow(); // um pulo fecha a janela
}
```

O `OnJumped` é chamado pelo `ACharacter::CheckJumpInput` logo depois de o CMC aceitar o pulo, dentro do passo de movimento, nas duas pontas. ⚠️ Confira esse trecho no código da engine da sua versão: se o `OnJumped` estiver fora do passo, mova o fechamento da janela para uma sobrescrita de `DoJump` no CMC.

A mira entra pelo mesmo caminho. No `UVGWeaponComponent`:

```cpp
// VGWeaponComponent.cpp (alterações do Cap. 67)
void UVGWeaponComponent::StartAim()
{
    bWantsToAim = true;
    SetComponentTickEnabled(true);
    if (AVGCharacter* Character = Cast<AVGCharacter>(GetOwner()))
    {
        Character->GetVGMovement()->SetWantsToAim(true); // entrada do movimento
    }
}
// StopAim: o mesmo com false.

// Em ApplyEquippedWeapon (Cap. 65), depois de equipar — dado igual nas duas pontas:
//   Character->GetVGMovement()->SetAimSpeedMultiplier(Wanted->GetEffectiveStats().AimMoveSpeedMultiplier);
```

O `GetMoveSpeedMultiplier()` do Capítulo 26 deixa de ser aplicado à velocidade máxima. A velocidade com mira passa a ser decidida no `GetMaxSpeed` do movimento.

**Simplificação:** a mira no movimento é binária (quer mirar ou não), enquanto o alfa visual da mira sobe ao longo do `AimTime`. A velocidade cai de uma vez, e a arma chega ao rosto aos poucos. Para a Arena, é imperceptível. Uma transição gradual exigiria o alfa como estado simulado, salvo e restaurado como o relógio do *coyote*.

### 3. O disparo previsto

🔁 **O que havia:** no Capítulo 66, o cliente só enviava o pedido, e o servidor resolvia com a semente `HashCombine(GetUniqueID(), ShotId)` e a dispersão calculada por ele. **O problema:** Q9, e a dispersão do servidor ignorava a mira e o *bloom*. **A solução:** semente compartilhada, dispersão no pedido, traço previsto no cliente.

```cpp
// VGShotTypes.h (adição do Cap. 67)
    /** Ângulo de dispersão (graus) que o cliente usou: alfa de mira e bloom são dele. O servidor valida a faixa. */
    UPROPERTY()
    float SpreadDegrees = 0.0f;
```

```cpp
// VGWeapon.h (alterações do Cap. 67)
protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Weapon|Net", meta = (ClampMin = "0.0"))
    float MaxPlausibleSpread = 30.0f; // graus

    /** Confirmação ao dono: último disparo processado e a munição do servidor. Não confiável: a próxima supera. */
    UFUNCTION(Client, Unreliable)
    void ClientAckAmmo(int32 LastProcessedShotId, int32 ServerMagazine, int32 ServerReserve);

private:
    FRandomStream MakeShotStream(int32 ShotId) const;
    void TraceShot(const FVGShotRequest& Request, bool bAuthoritative);
    void SendAmmoAck();
    // FirePellet ganha o parâmetro bool bAuthoritative.

    /** Semente base: sorteada no servidor, replicada SÓ para o dono. */
    UPROPERTY(Replicated)
    int32 NetSeed = 0;

    int32 LastAckedShotId = INDEX_NONE; // dono: confirmação mais recente aplicada

// AmmoInMagazine e ReserveAmmo deixam de ser replicados (e OnRep_Ammo sai): o dono prevê, o servidor confirma.
```

```cpp
// VGWeapon.cpp (Cap. 67)
#include "Misc/ScopeExit.h"

void AVGWeapon::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
    Super::GetLifetimeReplicatedProps(OutLifetimeProps);
    DOREPLIFETIME_CONDITION(AVGWeapon, NetSeed, COND_OwnerOnly);
}

void AVGWeapon::BeginPlay()
{
    Super::BeginPlay();
    // ... dados e estatísticas, como antes ...
    if (HasAuthority())
    {
        NetSeed = FMath::RandRange(0, MAX_int32 - 1);
    }
    // 🔁 Cap. 65 inicializava a munição só no servidor, porque ela era replicada.
    // Agora ela é PREVISTA no dono: a previsão inicial vem dos mesmos dados nas duas pontas.
    AmmoInMagazine = EffectiveStats.GetMagazineSize();
    ReserveAmmo = FMath::Clamp(InitialReserveAmmo, 0, Data->MaxReserveAmmo);
    BroadcastAmmo();
}

FRandomStream AVGWeapon::MakeShotStream(int32 ShotId) const
{
    // 🔁 Cap. 27: GetUniqueID() muda de processo para processo. NetSeed é igual no servidor e no dono.
    return FRandomStream(static_cast<int32>(HashCombine(static_cast<uint32>(NetSeed), static_cast<uint32>(ShotId))));
}

FVGShotRequest AVGWeapon::MakeShotRequest()
{
    FVGShotRequest Request;
    // ... origem, mira comprimida e ShotId, como no Cap. 66 ...
    Request.SpreadDegrees = ComputeSpreadDegrees(); // inclui alfa de mira e bloom (só o dono os tem)
    return Request;
}

void AVGWeapon::TraceShot(const FVGShotRequest& Request, bool bAuthoritative)
{
    const FRandomStream Stream = MakeShotStream(Request.ShotId);
    const float HalfAngle = FMath::DegreesToRadians(Request.SpreadDegrees);
    const FVector AimDirection = Request.GetAim().Vector(); // a mira COMPRIMIDA: a mesma nas duas pontas
    for (int32 Pellet = 0; Pellet < Data->PelletCount; ++Pellet)
    {
        FirePellet(Request.Origin, Stream.VRandCone(AimDirection, HalfAngle), Stream, bAuthoritative);
    }
}

void AVGWeapon::FireOnce()
{
    const FVGShotRequest Request = MakeShotRequest();
    --AmmoInMagazine; // no anfitrião, a verdade; no cliente, a previsão
    if (HasAuthority())
    {
        TraceShot(Request, /*bAuthoritative=*/true);
    }
    else
    {
        TraceShot(Request, /*bAuthoritative=*/false); // rastro e impactos em paredes, na hora; sem dano
        ServerFireShot(Request);
    }
    OnShotFeedback();
    OnFired.Broadcast(this);
    BroadcastAmmo();
}

void AVGWeapon::ServerFireShot_Implementation(const FVGShotRequest& Request)
{
    LastReceivedShotId = Request.ShotId;
    ON_SCOPE_EXIT { SendAmmoAck(); }; // aceito OU recusado: o dono precisa saber onde a munição está

    // ... vivo, carência de recarga, Ready, munição, cadência e origem, como no Cap. 66 ...

    if (!VGNetRules::IsSpreadPlausible(Request.SpreadDegrees, EffectiveStats.AimSpread, MaxPlausibleSpread))
    {
        return; // menor que a mira total parado é impossível; maior que o teto é lixo
    }

    --AmmoInMagazine;
    TraceShot(Request, /*bAuthoritative=*/true);
}

void AVGWeapon::SendAmmoAck()
{
    if (!IsLocallyOwned()) // anfitrião e IA não precisam: a munição deles já é a verdade
    {
        ClientAckAmmo(LastReceivedShotId, AmmoInMagazine, ReserveAmmo);
    }
}

void AVGWeapon::ClientAckAmmo_Implementation(int32 LastProcessedShotId, int32 ServerMagazine, int32 ServerReserve)
{
    if (LastProcessedShotId < LastAckedShotId)
    {
        return; // não confiável: chegou depois de uma confirmação mais nova
    }
    LastAckedShotId = LastProcessedShotId;
    ReserveAmmo = ServerReserve;
    // ponytail: sem "época de recarga" no ack. Um ack atrasado por mais que uma recarga inteira desfaria
    // a recarga prevista até o ack seguinte. Se aparecer em teste, acrescente um contador de recargas.
    AmmoInMagazine = VGNetRules::ReconcileAmmo(ServerMagazine, LastProcessedShotId, NextShotId - 1);
    BroadcastAmmo();
}

void AVGWeapon::FinishReload()
{
    // 🔁 Cap. 66 só transferia no servidor. Agora o dono PREVÊ a transferência, e o ack corrige.
    const int32 Transfer = FMath::Min(EffectiveStats.GetMagazineSize() - AmmoInMagazine, ReserveAmmo);
    AmmoInMagazine += Transfer;
    ReserveAmmo -= Transfer;
    TransitionTo(EVGWeaponState::Ready);
    BroadcastAmmo();
    if (HasAuthority())
    {
        SendAmmoAck();
    }
}
```

O `FirePellet` ganha o parâmetro `bAuthoritative` e decide três coisas com ele:

```cpp
// AVGWeapon::FirePellet (alterações do Cap. 67)
        if (AActor* HitActor = Hit.GetActor())
        {
            const bool bHitCharacter = HitActor->FindComponentByClass<UVGHealthComponent>() != nullptr;
            if (bAuthoritative)
            {
                UGameplayStatics::ApplyPointDamage(HitActor, Damage, Direction, Hit,
                                                   GetInstigatorController(), this, Data->DamageType);
                if (bHitCharacter)
                {
                    ClientConfirmHit(HitActor, MaterialMultiplier > 1.0f);
                }
            }
            else if (bHitCharacter)
            {
                bShowImpact = false; // previsto num corpo: o efeito espera a confirmação (seção 67.5)
            }
        }
    // ...
    // Fim do FirePellet:
    if (IsLocallyOwned())
    {
        PlayShotFx(Muzzle->GetComponentLocation(), LastImpact, LastNormal, bAnyImpact && bShowImpact); // na hora
    }
    if (bAuthoritative)
    {
        MulticastShotFx(Muzzle->GetComponentLocation(), LastImpact, LastNormal, bAnyImpact); // para os outros
    }
```

```cpp
// VGWeapon.cpp (alteração do Cap. 67)
void AVGWeapon::MulticastShotFx_Implementation(FVector_NetQuantize From, FVector_NetQuantize To,
                                               FVector_NetQuantizeNormal ImpactNormal, bool bImpact)
{
    if (IsLocallyOwned())
    {
        return; // o dono já mostrou o disparo previsto (e o anfitrião, o real)
    }
    PlayShotFx(From, To, ImpactNormal, bImpact);
    OnShotFeedback();
}

// ClientConfirmHit_Implementation (alteração): além do OnHitConfirmed, toca o efeito de impacto
// no ponto do alvo, que a previsão segurou.
```

### 4. As regras de reconciliação, puras

```cpp
// VGNetRules.h (adições do Cap. 67)
namespace VGNetRules
{
    /** Munição prevista = a confirmada pelo servidor menos os disparos ainda em trânsito. */
    inline int32 ReconcileAmmo(int32 ServerAmmo, int32 LastProcessedShotId, int32 LastSentShotId)
    {
        const int32 InFlight = FMath::Max(0, LastSentShotId - LastProcessedShotId);
        return FMath::Max(0, ServerAmmo - InFlight);
    }

    /** A dispersão informada está entre o mínimo físico da arma e um teto de sanidade? */
    inline bool IsSpreadPlausible(float ClaimedDegrees, float MinDegrees, float MaxDegrees)
    {
        return ClaimedDegrees >= MinDegrees - KINDA_SMALL_NUMBER && ClaimedDegrees <= MaxDegrees;
    }
}
```

```cpp
// VGNetRulesTest.cpp (adições ao teste Vigilia.Net.Rules)
    TestEqual(TEXT("3 em trânsito"), VGNetRules::ReconcileAmmo(20, 10, 13), 17);
    TestEqual(TEXT("Nada em trânsito: a do servidor"), VGNetRules::ReconcileAmmo(20, 13, 13), 20);
    TestEqual(TEXT("Disparo recusado devolve a bala"), VGNetRules::ReconcileAmmo(20, 11, 11), 20);
    TestEqual(TEXT("Nunca negativa"), VGNetRules::ReconcileAmmo(1, 10, 15), 0);
    TestEqual(TEXT("Ack velho, nada enviado depois"), VGNetRules::ReconcileAmmo(5, 13, 12), 5);
    TestFalse(TEXT("Dispersão abaixo do mínimo"), VGNetRules::IsSpreadPlausible(0.1f, 0.4f, 30.0f));
    TestTrue(TEXT("Dispersão de quadril"), VGNetRules::IsSpreadPlausible(3.0f, 0.4f, 30.0f));
```

### Explicação das decisões

- **Entradas como flags, não como RPCs.** A intenção viaja **dentro** do movimento que ela afeta. É a única forma de garantir que o servidor simule cada movimento com a intenção daquele instante.
- **A regra da corrida com a aceleração.** O input 2D (`LastMoveInput`) só existe no cliente. A aceleração é o mesmo input já transformado em espaço do mundo, e o CMC a envia. Escolher o dado que **as duas pontas têm** é o que torna a regra replicável.
- **Relógio do movimento para o *coyote*.** O delta de cada movimento é o mesmo no cliente e no servidor; o relógio do mundo não é. Salvar no `SetMoveFor` e restaurar no `PrepMoveFor` cobre o replay, porque o servidor não manda esse valor de volta numa correção.
- **Efeitos colaterais fora do replay** com `bClientUpdating`. A tag de corrida, o tremor de pouso e o *jump buffer* rodariam de novo a cada correção.
- **Dispersão no pedido, validada por faixa.** O servidor não consegue recalcular o alfa de mira nem o *bloom*, e confiar no valor do cliente sem limite abriria a trapaça de "dispersão zero". A faixa fecha o pior caso: ninguém atira mais preciso do que a arma mirada e parada. **Limite conhecido:** um trapaceiro pode sempre declarar a dispersão mínima. O servidor sabe se o jogador está mirando (a flag do movimento) e poderia apertar o mínimo; fica como desafio.
- **Impacto em personagem só na confirmação.** Um efeito falso num corpo é pior que um efeito atrasado.
- **A munição confirmada a cada pedido, aceito ou não.** `ON_SCOPE_EXIT` garante que nenhum caminho de recusa esqueça a confirmação. A confirmação é não confiável porque a próxima a supera, e confirmações velhas são descartadas pelo `ShotId`.
- **`SendAmmoAck` só para dono remoto.** No anfitrião, a munição já é a verdade, e o `ShotId` do servidor (`LastReceivedShotId`) nem é usado: reconciliar subtrairia todos os disparos da partida.

---

## Projeto Arena — o controle volta a ser instantâneo

Rode como listen server com 100 ms, 30 ms de variação e 2% de perda, e ligue `p.NetShowCorrections 1` na janela do cliente.

- **Q3 resolvida.** O cliente corre sem trancos. Antes da mudança, a corrida desenhava uma correção atrás da outra; depois, quase nenhuma. Ligue e desligue a mira correndo: também sem correções.
- **Q8 resolvida.** Ande para fora de uma beirada e pule no limite da janela, vinte vezes. Antes, alguns pulos eram desfeitos; agora, o servidor concorda com o cliente.
- **Q9 resolvida.** O rastro e os impactos em paredes saem no clique. A munição na HUD cai a cada disparo, sem atraso, e numa rajada longa com perda ela não "anda para trás". Provoque uma recusa (atire logo depois de recarregar com `ReloadGraceTime = 0` e 300 ms): a bala é "devolvida" quando a confirmação chega.
- **O que não mudou: Q10.** Atirando num alvo que corre de lado, o rastro previsto termina no corpo do alvo, o impacto espera, e às vezes a confirmação nunca chega. O cliente e o servidor calculam a **mesma direção**, e o tiro do servidor passa **atrás** do alvo, porque o servidor traça contra a posição **atual** do alvo, e o cliente via a posição de ~100 ms antes. Isso não é um problema de predição. É de latência, e é o próximo capítulo.

| # | Quebra | Depois do Cap. 67 |
|---|---|---|
| Q3 | Corrida elástica | ✅ Resolvida: corrida e mira como flags do movimento |
| Q8 | Pulo que volta | ✅ Resolvida: *coyote* no relógio do movimento, salvo e restaurado |
| Q9 | Tiro atrasado | ✅ Resolvida: semente compartilhada, traço previsto, munição reconciliada |
| Q10 | "Mas eu acertei!" | ❌ O tiro é o mesmo; o alvo, não (Cap. 68) |

---

## Decisões arquiteturais

1. **Toda variável de um sistema preditivo é classificada**: entrada, estado simulado, dados ou efeito colateral.
2. **Entradas viajam dentro do movimento** (flags do CMC), nunca por RPC paralelo.
3. **Regras de movimento usam só dados que as duas pontas têm** (a aceleração, não o input 2D).
4. **Estado simulado que o servidor não devolve é salvo no movimento e restaurado no replay.**
5. **Efeitos colaterais nunca rodam no replay** (`bClientUpdating`).
6. **O disparo é previsto com semente compartilhada** (`NetSeed` + `ShotId`), mira comprimida e dispersão declarada e validada.
7. **A apresentação do próprio disparo é imediata; impacto em personagem e dano esperam o servidor.**
8. **Recursos gastos pelo jogador (munição) usam predição com reconciliação por número de sequência**, o mesmo padrão do movimento.

---

## Armadilhas

- **Mudar parâmetros do CMC fora do movimento** (`MaxWalkSpeed`, atrito, gravidade) a partir de input: correções em série.
- **Mandar uma entrada por RPC** em vez de flag: o servidor a aplica no movimento errado.
- **Usar o relógio do mundo dentro da simulação.** Use o delta do movimento.
- **Esquecer o `PrepMoveFor`** para estado que o servidor não devolve: o replay parte de um valor errado.
- **Efeitos colaterais dentro do replay**: sons, tags e câmera disparando duas ou três vezes a cada correção.
- **Esquecer o `CanCombineWith`**: movimentos com intenções diferentes combinados num só, e a intenção do segundo se perde.
- **Ultrapassar as quatro flags livres** com mais bits empacotados à mão em outros campos. Use os dados de movimento próprios da engine.
- **Semente local ao processo** (`GetUniqueID`, ponteiros, contadores locais): a dispersão prevista nunca bate com a do servidor.
- **Usar a mira original no cliente e a comprimida no servidor**: diferenças de milésimos de grau viram centímetros a 50 m.
- **Mostrar impacto previsto em personagem**: o jogador vê um acerto que não contou.
- **Reconciliar com confirmações não confiáveis sem descartar as velhas.**
- **Confiar que "funciona a 0 ms"**: sem emulação de rede, nenhuma correção acontece.

---

## Exercício

**Parte 1 — o CMC da Vigília (2 h).** Implemente `UVGCharacterMovementComponent`, o movimento salvo e os dados de predição. Troque o construtor do `AVGCharacter` e mova a corrida para a flag. Com 100 ms e `p.NetShowCorrections 1`, grave dez segundos correndo em zigue-zague antes e depois da mudança, e conte as correções.

**Parte 2 — *coyote* e mira (1,5 h).** Mova o *coyote time* para o relógio do movimento, com o `SetMoveFor`/`PrepMoveFor`. Faça vinte pulos no limite da beirada com 150 ms e anote quantos são desfeitos. Depois, **remova** a restauração no `PrepMoveFor`, repita, e explique a diferença. Mova a mira para a flag 1.

**Parte 3 — disparo previsto (2 h).** Implemente a semente compartilhada, a dispersão no pedido e o traço previsto. Ligue um `DrawDebugLine` com a direção calculada no cliente e outra no servidor (num listen server, as duas aparecem na janela do anfitrião quando o cliente atira; use cores diferentes). Elas devem coincidir. Troque a mira do pedido pela mira original no cliente e meça a diferença a 50 m.

**Parte 4 — munição (1 h).** Implemente `ClientAckAmmo`, `ReconcileAmmo` e o teste. Com 2% de perda e 200 ms, esvazie dez pentes em rajada. A munição na HUD nunca pode subir sem uma recusa do servidor, e precisa chegar a zero junto com o último disparo aceito.

---

## Desafio — "Deslizar"

O desafio do Capítulo 25 pediu um deslize e prometeu que, aqui, você descobriria que só uma das duas abordagens sobrevive ao multiplayer. Implemente as duas e compare:

1. **Troca de atrito e frenagem** enquanto um `bIsSliding` do personagem estiver ativo (a versão "mais simples" do Capítulo 25).
2. **Modo de movimento próprio** (`MOVE_Custom` com `PhysCustom` no `UVGCharacterMovementComponent`), entrado por uma terceira flag (`FLAG_Custom_2`), com a duração do deslize como estado simulado salvo e restaurado.

Com 100 ms e `p.NetShowCorrections 1`, deslize vinte vezes com cada uma. Registre no `DEVLOG.md` quantas correções cada uma gera, e classifique cada variável de cada abordagem nas quatro categorias de 67.2. A abordagem 1 é a corrida do Capítulo 17 de novo; descreva por quê.

---

## Uso de IA

1. **Para classificar variáveis:**
   > "Aqui está um sistema de movimento de personagem em Unreal Engine 5 que vai rodar com predição no cliente e reconciliação no servidor (CharacterMovementComponent). Classifique cada variável em: entrada (precisa viajar no movimento), estado simulado (precisa ser reconciliado ou salvo/restaurado no replay), dados (iguais nas duas pontas) ou efeito colateral (não pode rodar no replay). Aponte qualquer uso de relógio do mundo dentro da simulação. [código]"

2. **Para revisar a extensão do CMC:**
   > "Revise esta subclasse de UCharacterMovementComponent e o FSavedMove derivado. Verifique: Clear, GetCompressedFlags, CanCombineWith, SetMoveFor (guarda entradas e estado ANTES do movimento), PrepMoveFor (restaura estado no replay), UpdateFromCompressedFlags e GetPredictionData_Client. Diga onde uma correção do servidor faria o cliente divergir de novo. [código]"

3. **Para depurar correções:**
   > "Meu personagem é corrigido pelo servidor com frequência quando [situação], com 100 ms de latência. Estes são os sistemas que mexem no movimento [lista]. Monte um roteiro para isolar a causa usando p.NetShowCorrections, logs com bClientUpdating e testes com cada sistema desligado."

**Cuidado específico:** muitos exemplos públicos de extensão do CMC são de versões antigas da engine e usam assinaturas que mudaram (de `SetMoveFor`, `DoJump`, dos RPCs empacotados). A IA reproduz essas assinaturas com segurança. Compile cada sobrescrita contra o cabeçalho da **sua** versão (`CharacterMovementComponent.h`) e confira o `override`, em vez de confiar na resposta.

---

## Checklist

- [ ] Sei explicar por que esperar o servidor torna o controle "mole", em quadros.
- [ ] Sei descrever predição e reconciliação com números de sequência e reexecução.
- [ ] Sei percorrer o fluxo do CMC (movimento salvo, envio, verificação, confirmação ou correção, replay).
- [ ] Sei por que agachar funciona em rede e a corrida do Capítulo 17 não funcionava.
- [ ] Classifico variáveis em entrada, estado simulado, dados e efeito colateral, e sei o tratamento de cada uma.
- [ ] Estendi o CMC com flags para corrida e mira, e com o relógio do *coyote* salvo e restaurado.
- [ ] O disparo é previsto com semente compartilhada, e as direções do cliente e do servidor coincidem.
- [ ] A munição é prevista e reconciliada, com teste.

---

## Para ir além

- **Gabriel Gambetta, "Fast-Paced Multiplayer", parte II** (gabrielgambetta.com): *client-side prediction and server reconciliation*, com a demonstração interativa.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): a página sobre o movimento em rede do `CharacterMovementComponent` (*Understanding Networked Movement in the Character Movement Component*) e as páginas dos plugins *Mover* e *Network Prediction* (⚠️ verifique o estado na sua versão).
- **O código da engine:** `CharacterMovementComponent.h/.cpp`, a partir de `ReplicateMoveToServer`, `MoveAutonomous` e `ClientUpdatePosition`. É a melhor documentação do algoritmo.
- **GDC Vault** (gdcvault.com): *Overwatch Gameplay Architecture and Netcode*, de Timothy Ford (GDC 2017).
- **Joshua Glazer e Sanjay Madhav, *Multiplayer Game Programming*:** o capítulo sobre latência, jitter e predição no cliente.

---

➡️ **Próximo:** [Capítulo 68 — Latency](cap-68-latency.md)

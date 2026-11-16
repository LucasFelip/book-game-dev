# Capítulo 4 — Estado e eventos

## Objetivo

Ao final deste capítulo você deve conseguir:

- classificar o estado de um jogo em **categorias** com frequências, durações e donos diferentes — e saber qual é fonte da verdade e qual é derivado;
- aplicar a regra do **dono único** para cada pedaço de estado mutável, e resolver conflitos quando vários sistemas querem mudar a mesma coisa;
- modelar estado discreto com **máquinas de estado** em vez de combinações de booleanos;
- escolher entre **polling** e **eventos** para propagar mudanças, e entender os riscos de eventos síncronos (reentrância, ordem, ciclo de vida);
- reconhecer **condições de corrida sem threads**, causadas pela ordem de atualização dentro de um frame;
- modelar **processos que atravessam vários frames** (sequências roteirizadas) e cancelá-los com segurança;
- implementar o primeiro componente de gameplay real do projeto, com teste automatizado.

---

## Contexto

O desafio do Capítulo 3 terminou com uma pergunta. Você implementou um *hitstop* que mexe na dilatação global do tempo. O bullet time também mexe. Se os dois acontecerem ao mesmo tempo — o jogador está em câmera lenta e acerta um tiro forte —, o hitstop aplica 0,05, termina e restaura para **1,0**, cancelando o bullet time que ainda deveria estar ativo. Nenhuma das duas implementações está errada isoladamente. O defeito está no fato de que **dois sistemas são donos do mesmo estado**.

Esse é o tema deste capítulo. Um jogo, como vimos no Capítulo 1, é uma grande quantidade de estado mutável em memória, alterado dezenas de vezes por segundo por dezenas de sistemas. As perguntas que organizam a arquitetura de gameplay são, quase todas, perguntas sobre estado:

- **Que** estado existe, e de que tipo ele é?
- **Quem** pode mudá-lo?
- **Como** os outros ficam sabendo que ele mudou?
- **Quando**, dentro do frame, cada um enxerga a mudança?
- **Quanto tempo** dura uma mudança que não é instantânea?

Você já tem respostas maduras para essas perguntas em sistemas distribuídos: fonte da verdade, projeções, eventos de domínio, *single writer*, sagas. Muitas delas transferem bem. Mas o contexto muda tudo: aqui, não há rede, não há fila durável, não há transação, e o intervalo entre "mudou" e "todo mundo precisa saber" é de alguns milissegundos.

---

## 4.1 O que é "estado do mundo"

Quando se fala em "estado do jogo", é tentador imaginar uma coisa homogênea. Não é. Um jogo tem categorias de estado com propriedades muito diferentes, e tratá-las da mesma forma é a origem de boa parte dos problemas de arquitetura. Considere a usina da Vigília num instante qualquer:

| Categoria | Exemplos na Vigília | Muda com que frequência? | Vive quanto tempo? | Vai para o save? | Fonte da verdade? |
|---|---|---|---|---|---|
| **Simulação** | Posição e velocidade da jogadora, rotação de uma porta abrindo, corpo físico de uma caixa | Todo frame | Enquanto o objeto existir | Às vezes (só o necessário) | Sim, mas efêmera |
| **Gameplay** | Carga da bateria, vida, munição do sinalizador, porta trancada/destrancada, setor elétrico ligado | Em eventos discretos ou gradualmente | Minutos a sessão inteira | Sim | **Sim** |
| **Narrativa / progressão** | "Encontrou o livro de ocorrências", "falou com a operadora pela 2ª vez", "religou o setor B" | Raramente | O jogo inteiro | **Sempre** | **Sim** |
| **IA** | O que a Presença sabe sobre a jogadora, última posição vista, estado atual (patrulha, caça) | Frequentemente | Segundos a minutos | Raramente | Sim (local ao agente) |
| **Apresentação** | Animação tocando, partículas, sons ativos, texto da HUD, pós-processamento | Todo frame | Efêmero | Não | **Não — derivado** |
| **Configuração (dados)** | Capacidade da bateria, dano do sinalizador, velocidade da Presença | Nunca, em runtime | Assets do projeto | Não (já está no jogo) | Sim, mas imutável |

Três observações sobre a tabela.

**Primeira: apresentação é derivada.** A barra de bateria na HUD **não é** o estado da bateria; é uma *visualização* dele. O som de bateria fraca **não é** o estado; é uma *reação* a ele. Se você algum dia se pegar lendo o comprimento de uma barra de UI para decidir se a lanterna liga, a arquitetura está de cabeça para baixo. A regra é simples e inegociável: **estado de apresentação nunca é fonte da verdade.** Ele pode ser destruído e reconstruído a qualquer momento a partir do estado de gameplay — e isso é exatamente o que acontece ao carregar um save (Capítulo 56) e, em multiplayer, em cada cliente (Parte IX).

**Segunda: as categorias determinam decisões futuras.** A coluna "vai para o save?" é, praticamente, a especificação do sistema de save. A coluna "fonte da verdade?" é, praticamente, a especificação do que o servidor precisa replicar em multiplayer. Classificar o estado corretamente agora economiza refatorações enormes depois.

**Terceira: dados de configuração não são estado mutável.** A capacidade máxima da bateria vem de um asset e não muda durante o jogo. Separar "o que é configurado" (dados) de "o que muda" (estado) é a base do design *data-driven* do Capítulo 1. Um erro comum é misturar os dois — por exemplo, alterar o valor de um Data Asset em runtime para aplicar um *buff* (o que, na Unreal, altera o asset compartilhado por todos os objetos que o usam, e, no editor, pode até persistir a alteração no disco).

> 🌉 **Ponte:** a separação entre estado autoritativo e derivado é a mesma de CQRS: o modelo de escrita é a fonte da verdade, e os modelos de leitura (projeções) são derivados e podem ser reconstruídos. A HUD é uma projeção.
>
> 🧱 **Onde a ponte cai:** em CQRS, projeções são atualizadas de forma assíncrona e eventualmente consistentes, e isso é aceitável. Em jogos, a "projeção" (a barra de vida, a animação de dano) precisa refletir o estado **no mesmo frame**, ou no próximo. Um atraso de 200 ms entre levar um tiro e ver a vida cair é um bug percebido. Não há consistência eventual em gameplay single-player: há consistência *por frame*.

---

## 4.2 Quem é dono do estado

A regra mais útil deste capítulo é curta:

> **Todo pedaço de estado mutável tem exatamente um dono. Só o dono escreve. Os outros leem ou pedem.**

"Dono", aqui, é o objeto ou sistema que contém o estado e **é a única porta de entrada para alterá-lo**. A carga da bateria pertence ao componente de bateria. A vida pertence ao componente de vida. A dilatação global do tempo pertence a... ninguém, no código do Capítulo 3 — e é por isso que ela quebrou.

Quando outros sistemas querem mudar um estado que não é deles, eles **pedem** ao dono, através de uma operação com significado: `Drain(Amount)`, `ApplyDamage(Info)`, `RequestTimeDilation(...)`. Isso permite ao dono:

- **validar** o pedido (não drenar abaixo de zero, não aplicar dano a quem já morreu);
- **manter invariantes** (a carga está sempre entre 0 e o máximo);
- **resolver conflitos** entre pedidos concorrentes;
- **anunciar** a mudança de forma consistente (seção 4.4).

Isso é encapsulamento, e você conhece. O que é específico de jogos é **onde a tentação de violá-lo aparece**: no editor e no Blueprint, é trivial expor uma variável e deixar qualquer coisa escrever nela. Um designer, um script de cinemática e um sistema de IA podem, cada um, setar `Charge` diretamente — e a Unreal vai deixar, se você expuser a propriedade como editável em Blueprint. A disciplina do dono único é uma decisão sua, imposta pela forma como você expõe as propriedades (Capítulo 13).

### Resolvendo o problema da dilatação do tempo

Voltemos ao conflito entre hitstop e bullet time. Com a regra do dono único, a solução muda de natureza: em vez de cada sistema **escrever** a dilatação, cada sistema **faz um pedido**, e um dono decide o valor efetivo a partir de todos os pedidos ativos.

```text
           Bullet Time ── pedido: 0,30 (até cancelar) ──┐
                                                        │
             Hitstop  ── pedido: 0,05 (por 0,08 s) ─────┼──►  DONO DA DILATAÇÃO
                                                        │     valor efetivo = mínimo
          Cinemática  ── pedido: 1,00 (forçar normal) ──┘     dos pedidos ativos
                                                                     │
                                                                     ▼
                                                   SetGlobalTimeDilation(efetivo)
```

Cada pedido recebe um identificador (um *handle*); quem pediu, cancela o seu pedido, e só o seu. A regra de resolução (o mínimo, ou um sistema de prioridades) é decidida **num lugar só**. Quando o hitstop termina, ele remove o seu pedido — e o valor efetivo volta a 0,30, porque o bullet time ainda está pedindo.

Você vai implementar a lógica desse dono como exercício deste capítulo, em C++ puro e testável. No Capítulo 6, ela ganha uma casa definitiva na Unreal: um **subsistema de mundo** (`UWorldSubsystem`), o lugar natural para estado global com um único dono.

> 🌉 **Ponte:** o *Single Writer Principle*, popularizado por Martin Thompson no contexto de sistemas de alta performance (a arquitetura LMAX), afirma que qualquer item de dado deve ter um único escritor — o que elimina contenção e simplifica o raciocínio sobre consistência. A regra do dono único é a mesma ideia, com outra motivação: aqui não há contenção entre threads, há **confusão entre sistemas**.

---

## 4.3 Estado discreto: pensar em máquinas de estado

Boa parte do estado de gameplay é **discreta**: a lanterna está desligada, ligada, piscando, em sobrecarga ou sem bateria. A porta está fechada, abrindo, aberta, fechando ou trancada. A Presença está patrulhando, investigando, caçando ou perdeu a jogadora.

### O problema dos booleanos

O jeito "natural" de modelar isso, quando se começa, é acumular flags:

```cpp
bool bIsOn = false;
bool bIsFlickering = false;
bool bIsOvercharging = false;
bool bIsDepleted = false;
```

Quatro booleanos são **16 combinações**. Quantas delas são válidas? Cinco: desligada, ligada, piscando, sobrecarga, sem bateria. As outras onze — "desligada mas em sobrecarga", "sem bateria mas ligada e piscando" — são **estados impossíveis que o código consegue representar**. E, como o código consegue representá-los, mais cedo ou mais tarde algum caminho os produz: alguém liga a sobrecarga sem checar `bIsDepleted`, e agora a lanterna está queimando a escuridão sem bateria.

O sintoma clássico é um `Tick` cheio de condicionais defensivas:

```cpp
if (bIsOn && !bIsDepleted && !bIsOvercharging) { ... }
else if (bIsOn && bIsOvercharging && !bIsDepleted) { ... }
else if (bIsFlickering && bIsOn) { ... } // e se estiver em sobrecarga também?
```

### Estado explícito

A alternativa é tornar o estado **uma única variável com valores exclusivos**:

```cpp
enum class EVGFlashlightState : uint8
{
    Off,
    On,
    Flickering,   // bateria fraca: liga, mas falha
    Overcharge,   // foco intenso, gasta muito
    Depleted      // sem bateria
};

EVGFlashlightState State = EVGFlashlightState::Off;
```

Agora só existem os cinco estados válidos. E, mais importante, as **transições** entre eles tornam-se um objeto de projeto:

```text
                 ligar                     bateria fraca
     ┌─────┐ ───────────► ┌──────┐ ─────────────────────► ┌────────────┐
     │ Off │              │  On  │                        │ Flickering │
     └─────┘ ◄─────────── └──────┘                        └────────────┘
        ▲      desligar     │   ▲                                │
        │                   │   │ soltar foco                    │
        │      segurar foco │   │ ou tempo esgotado              │
        │                   ▼   │                                │
        │             ┌────────────┐                             │
        │             │ Overcharge │                             │
        │             └────────────┘                             │
        │                   │                                    │
        │                   │       bateria esgotou              │
        │                   │   (de On, Overcharge, Flickering)  │
        │                   ▼                                    ▼
        │             ┌──────────────────────────────────────────────┐
        └──────────── │                  Depleted                    │
         nova bateria └──────────────────────────────────────────────┘

  (Flickering → Off ao desligar foi omitido do desenho para legibilidade)
```

Uma máquina de estado finita (FSM, *finite state machine*) é definida por:

- **estados** — os valores possíveis;
- **transições** — quais mudanças de estado são permitidas, e o que as dispara (eventos: "ligar", "bateria fraca");
- **guardas** — condições que precisam ser verdadeiras para uma transição acontecer ("só pode entrar em Overcharge se carga > 10%");
- **ações de entrada e saída** — o que acontece ao entrar ou sair de um estado (ao entrar em `Flickering`, iniciar o padrão de falha da luz; ao sair, pará-lo);
- **comportamento do estado** — o que acontece *enquanto* se está nele (em `Overcharge`, drenar 5× mais rápido e queimar a escuridão).

Em código, a forma mais simples e honesta é uma função de transição central e um `switch` no comportamento:

```cpp
// Esboço: a lanterna real é implementada na Parte VII (Cap. 51).
bool UVGFlashlightComponent::TryTransition(EVGFlashlightState NewState)
{
    if (NewState == State || !IsTransitionAllowed(State, NewState))
    {
        return false;
    }

    const EVGFlashlightState OldState = State;
    ExitState(OldState);   // ex.: parar o padrão de flicker
    State = NewState;      // a mudança acontece num único lugar
    EnterState(NewState);  // ex.: começar o som de sobrecarga

    OnStateChanged.Broadcast(OldState, NewState);
    return true;
}

void UVGFlashlightComponent::TickComponent(float DeltaSeconds, ...)
{
    switch (State)
    {
    case EVGFlashlightState::On:         Battery->Drain(DrainPerSecond * DeltaSeconds); break;
    case EVGFlashlightState::Flickering: Battery->Drain(DrainPerSecond * DeltaSeconds); UpdateFlicker(DeltaSeconds); break;
    case EVGFlashlightState::Overcharge: Battery->Drain(OverchargeDrainPerSecond * DeltaSeconds); break;
    case EVGFlashlightState::Off:
    case EVGFlashlightState::Depleted:   break; // nada a fazer: o tick poderia estar desligado
    }
}
```

Observe a conexão com o Capítulo 2: nos estados `Off` e `Depleted`, a lanterna não tem trabalho contínuo. Uma implementação madura **desliga o tick** ao entrar nesses estados e religa ao sair — a ação de entrada é o lugar natural para isso.

> 🌉 **Ponte:** "tornar estados ilegais irrepresentáveis" é um princípio de modelagem de tipos (muito associado a linguagens com tipos algébricos, mas aplicável em Java com enums e `sealed`). O raciocínio é o mesmo que você usaria para modelar o ciclo de vida de um pedido (criado → pago → enviado → entregue) em DDD.
>
> 🧱 **Onde a ponte cai:** o ciclo de vida de um pedido tem poucas transições por dia. A FSM de um personagem pode transicionar várias vezes **por segundo**, com ações de entrada e saída que tocam animação, som e física. Em jogos, a FSM não é só modelagem de domínio — é um **controlador de comportamento em tempo real**, e o custo de cada transição importa.

FSMs são a ferramenta de modelagem mais usada em jogos: para personagens, armas, portas, UI, fluxo de partida, IA. Elas também têm limites claros — quando o número de estados cresce, as transições explodem —, e as soluções para isso (FSMs hierárquicas, Behavior Trees) são o tema dos Capítulos 34 e 37. Por ora, o hábito a criar é: **sempre que vir dois ou mais booleanos descrevendo "modos" de uma mesma coisa, pergunte se não é um enum de estado.**

### Estado discreto derivado de estado contínuo: histerese

Um caso particular aparece o tempo todo: um estado discreto que é **derivado** de um valor contínuo. "Bateria fraca" é derivado de "carga abaixo de 20%". "Ferido" é derivado de "vida abaixo de 30%". "Em alerta" é derivado de "nível de suspeita acima de 0,5".

O jeito ingênuo é recalcular com um limiar só:

```cpp
State = (Charge / MaxCharge < 0.2f) ? Low : Charged;
```

O problema surge quando o valor **oscila em torno do limiar** — a jogadora coloca uma bateria parcialmente carregada, a lanterna drena, um efeito recarrega um pouquinho... O estado alterna `Low → Charged → Low → Charged` várias vezes por segundo, e cada alternância dispara um evento: o som de "bateria fraca" toca em loop, o ícone da HUD pisca, a lanterna começa e para de falhar.

A solução, emprestada da engenharia de controle, é a **histerese**: usar **dois limiares**, um para entrar no estado e outro, mais alto, para sair dele.

```text
carga (%)
  30 ┤
  25 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  limiar de SAÍDA (volta para Charged)
     │            zona morta: mantém o estado atual
  20 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  limiar de ENTRADA (vira Low)
  15 ┤
```

Entre 20% e 25%, o estado **não muda** — permanece o que era. Isso elimina a oscilação. Você vai implementar exatamente isso no componente de bateria deste capítulo. A mesma técnica aparece em percepção de IA (para não alternar entre "vi" e "não vi" a cada frame quando a jogadora está na borda do cone de visão — Capítulo 36), em música dinâmica (para não trocar de faixa a cada segundo) e em LOD (Capítulo 60).

---

## 4.4 Propagar mudanças: polling ou eventos

Quando o estado muda, outros sistemas precisam reagir: a HUD precisa mostrar, o áudio precisa tocar, a IA precisa saber. Há duas formas fundamentais de fazer isso.

**Polling (consulta):** quem precisa do estado **lê** o estado do dono quando precisa — tipicamente a cada frame.

```cpp
// Na HUD, a cada frame:
BatteryBar->SetPercent(Battery->GetChargeRatio());
```

**Eventos (notificação):** o dono **anuncia** quando o estado muda, e quem se interessa se inscreveu previamente.

```cpp
// Na inicialização da HUD:
Battery->OnStateChanged.AddDynamic(this, &UVGHud::HandleBatteryStateChanged);

// No dono, quando a transição acontece:
OnStateChanged.Broadcast(OldState, NewState);
```

O Capítulo 2 já disse que, em jogos, polling não é *code smell*. Agora podemos ser mais precisos sobre quando usar cada um:

| Critério | Polling | Eventos |
|---|---|---|
| **Natureza do estado** | Contínuo, muda quase todo frame (carga, posição, spread da mira) | Discreto, muda raramente (estado, morte, coleta) |
| **Custo** | Proporcional a leitores × frames, mesmo sem mudança | Zero sem mudança; proporcional a ouvintes na mudança |
| **Consistência** | Sempre lê o valor atual; impossível "perder" uma mudança | Depende de estar inscrito na hora; mudanças antes da inscrição são perdidas |
| **Ciclo de vida** | Nenhum: não há inscrição para gerenciar | Inscrições precisam ser removidas; ouvintes destruídos são um risco |
| **Fluxo de controle** | Explícito: "eu leio" | Implícito: "alguém, em algum lugar, reage" |
| **Detectar transição** | Exige guardar o valor anterior e comparar | Natural: o evento **é** a transição |

A regra prática que vamos usar no projeto Vigília:

> **Valores contínuos: polling. Transições discretas: eventos.**

A barra de bateria lê `GetChargeRatio()` a cada frame. O ícone e o som de "bateria fraca" reagem ao evento `OnStateChanged`. Repare que é exatamente por isso que o componente de bateria deste capítulo **não** tem um evento `OnChargeChanged` disparado a cada frame — ele dispararia 60 vezes por segundo enquanto a lanterna está ligada, cada disparo percorreria todos os ouvintes, e nenhum deles precisa disso. Quem precisa do valor contínuo, consulta.

Existe também o **híbrido** — evento de "sujo" + leitura: o dono avisa "mudei" sem dizer como, e quem se interessa lê o estado atual quando for conveniente. É útil quando muitas mudanças pequenas acontecem num frame e os ouvintes só precisam do resultado final (por exemplo, uma UI de inventário que se reconstrói uma vez por frame, não uma vez por item adicionado).

> 🌉 **Ponte:** é a mesma escolha entre *polling* de uma API e *webhooks*/CDC (*change data capture*). Webhooks são eficientes quando mudanças são raras; polling é robusto e simples quando o consumidor precisa do valor atual de qualquer forma.

---

## 4.5 Eventos síncronos: o que muda dentro de um processo

Aqui está a diferença mais importante entre "eventos" no seu mundo e "eventos" em gameplay — e a fonte de bugs mais traiçoeiros deste capítulo.

Quando você publica uma mensagem num tópico Kafka ou numa fila do Azure Service Bus, você ganha, de graça, um conjunto de garantias e de isolamentos: o publicador continua imediatamente; o consumidor processa depois, em outro processo; falhas do consumidor não afetam o publicador; há ordem por partição; a mensagem é durável.

Um **delegate** da Unreal (ou um *observer* em qualquer linguagem) não tem nada disso. `Broadcast()` é **uma chamada de função**. Ele percorre a lista de inscritos e chama cada um, **imediatamente, na mesma thread, no meio da sua função**, antes de retornar. O seu código fica "pausado" na linha do `Broadcast` enquanto todos os ouvintes executam — e eles podem fazer qualquer coisa, inclusive mexer no objeto que está emitindo o evento.

> 🌉 **Ponte mais precisa:** a comparação certa não é com Kafka. É com o `ApplicationEventPublisher` do Spring, que por padrão é **síncrono**: `publishEvent()` chama os `@EventListener` na mesma thread, antes de retornar — e, se um listener lança exceção, ela sobe para o publicador. Delegates da Unreal se comportam como esses listeners síncronos.

Isso cria três riscos concretos.

### Risco 1 — Estado inconsistente durante o broadcast

```cpp
// ERRADO
void UVGHealthComponent::ApplyDamage(float Amount)
{
    OnDamaged.Broadcast(Amount);   // ouvintes executam AGORA...
    Health -= Amount;              // ...e enxergam a vida ANTIGA
}
```

Um ouvinte de `OnDamaged` que leia `GetHealth()` para atualizar a HUD verá o valor de antes do dano. A regra é: **complete a mudança de estado inteira, depois anuncie.**

```cpp
// CERTO
void UVGHealthComponent::ApplyDamage(float Amount)
{
    Health = FMath::Max(Health - Amount, 0.0f);  // 1. muda o estado
    OnDamaged.Broadcast(Amount);                 // 2. anuncia com o estado já consistente
}
```

> 🌉 **Ponte:** é o mesmo motivo pelo qual o Spring oferece `@TransactionalEventListener(phase = AFTER_COMMIT)`: os ouvintes só devem reagir depois que a mudança foi "confirmada". Em gameplay não há transação, então a disciplina é manual: **broadcast é a última coisa que a função faz**.

### Risco 2 — Reentrância

Um ouvinte pode chamar de volta o objeto emissor, *enquanto ele ainda está no meio do broadcast*:

```text
ApplyDamage(30)
  └─ Health = 0
  └─ OnDied.Broadcast()
        └─ ouvinte A: "ao morrer, explode" → aplica dano em área
              └─ ... a área inclui o próprio ator →  ApplyDamage(50)  ← REENTRÂNCIA
                    └─ Health = 0 (de novo)
                    └─ OnDied.Broadcast()  ← morreu DUAS vezes
```

Os sintomas são eventos duplicados, recursão infinita ou estado corrompido. As defesas:

- **Transições idempotentes com guarda:** "se já estou morto, ignoro dano". A máquina de estado da seção 4.3 resolve isso naturalmente — a transição `Alive → Dead` só acontece uma vez, porque de `Dead` não há transição para `Dead`.
- **Adiar efeitos colaterais:** em vez de agir dentro do callback, o ouvinte agenda a ação para mais tarde (próximo frame, ou fim do frame). Na Unreal, `GetWorld()->GetTimerManager().SetTimerForNextTick(...)` faz isso.
- **Fila de eventos:** o dono não chama os ouvintes diretamente; ele enfileira eventos, que são despachados num ponto seguro do frame. É o padrão *Event Queue*, descrito por Nystrom em *Game Programming Patterns*, e é usado em sistemas onde a reentrância seria frequente (por exemplo, áudio e mensagens de UI). O custo é que a reação deixa de ser imediata.

### Risco 3 — Ciclo de vida dos ouvintes

Um ouvinte se inscreve e depois é destruído — o widget da HUD é removido, um inimigo morre. Se a inscrição permanecer, o próximo broadcast chama uma função num objeto que não existe mais.

Na Unreal, **delegates dinâmicos** (`DECLARE_DYNAMIC_MULTICAST_DELEGATE`, os que aparecem em Blueprint) guardam referências fracas a `UObject`s e ignoram ouvintes já destruídos pelo garbage collector — o que elimina a forma mais grave do problema. Mas "o objeto foi marcado para destruição e ainda não foi coletado" e "o objeto ainda existe mas não deveria mais reagir" continuam sendo problemas seus. A disciplina: **quem se inscreve, se desinscreve** — tipicamente em `EndPlay` ou ao ser desativado. O Capítulo 24 compara os tipos de delegate da Unreal em detalhe.

### E a ordem dos ouvintes?

Não dependa dela. A ordem em que os ouvintes de um multicast delegate são chamados não deve ser tratada como parte do contrato. Se o ouvinte B precisa que o ouvinte A tenha rodado antes, eles não são dois ouvintes independentes — há uma dependência que precisa ser explícita (por exemplo, A emite um segundo evento ao terminar, ou o dono chama A diretamente e anuncia depois).

---

## 4.6 Condições de corrida sem threads

No Capítulo 1, vimos que o gameplay roda numa única thread. Isso elimina as condições de corrida clássicas. **Não** elimina uma família inteira de bugs que se comportam exatamente como elas — causados pela **ordem de atualização dentro do frame**.

### O bug do abate duplo

Dois projéteis do sinalizador atingem a Presença **no mesmo frame**. A sequência, dentro de um frame:

```text
Frame 1042
 ├─ Projétil A (tick): detecta acerto → lê Presença.Vida = 10 → 10 > 0, "vai matar"
 │                    → ApplyDamage(15) → Vida = 0 → OnDied → +1 abate, cinemática de morte
 └─ Projétil B (tick): detecta acerto → ...
```

Se a lógica de "matar" estiver no projétil e não no dono da vida — ou se o componente de vida não tiver a guarda de estado da seção anterior —, o projétil B também "mata": dois eventos de morte, a cinemática começa duas vezes, o placar conta dois abates. Nenhuma thread envolvida.

Uma variação mais sutil: o **sistema de IA** e o **sistema de dano** rodam no mesmo tick group, sem pré-requisito. Num frame, a IA lê a vida *antes* do dano e decide "estou bem, vou atacar"; noutro frame, com outra ordem, lê *depois* e decide "estou ferida, vou fugir". O comportamento depende de uma ordem que ninguém definiu — e pode mudar quando um ator é recriado, porque a ordem dentro de um grupo não é garantida (Capítulo 2).

As defesas são as mesmas que você usaria contra corridas reais, adaptadas:

- **O dono decide as transições**, nunca quem pede. O projétil pede `ApplyDamage`; só o componente de vida decide se houve morte.
- **Transições guardadas e idempotentes.** Morrer é uma transição que só acontece uma vez.
- **Ordem explícita quando importa** (tick groups e pré-requisitos — Capítulo 2).
- **Tolerância a um frame de atraso** quando a ordem não importa: na maioria dos casos, a IA ver a vida com 16 ms de atraso é irrelevante. Saber *quando* é irrelevante é parte da habilidade.

> 🌉 **Ponte:** o abate duplo é o problema do "evento entregue duas vezes" em mensageria *at-least-once*, e a solução é a mesma: **idempotência no consumidor** — aqui, no dono do estado.

---

## 4.7 Processos que atravessam frames

Até agora, as mudanças de estado foram instantâneas: o dano é aplicado, a bateria é drenada, o estado transiciona. Mas grande parte do que acontece num jogo — e quase tudo que importa num jogo narrativo de terror — são **processos que se estendem no tempo**:

> *A jogadora entra no corredor da subestação. As luzes do teto se apagam uma a uma, em cascata, em direção a ela, a cada 0,3 s. Silêncio por 2 segundos. Passos no andar de cima. A porta atrás dela bate. A lanterna falha por meio segundo.*

Isso é uma **sequência roteirizada** (*scripted sequence*): uma série de ações com tempo, disparada por um evento (o *trigger* na entrada do corredor). É o tipo de momento que Outlast e Amnesia usam constantemente para construir tensão, e que você vai criar dezenas de vezes na Vigília. Como implementá-lo?

### Opção A — Cadeia de atrasos

Em Blueprint, a forma mais imediata é encadear nós `Delay`. Em C++, encadear timers:

```text
OnTriggerEnter → apaga luz 1 → Delay 0,3 → apaga luz 2 → Delay 0,3 → ... → Delay 2,0
               → toca passos → Delay 1,5 → bate porta → falha lanterna
```

**Vantagem:** rápido de escrever, fácil de ler para sequências curtas. **Problemas:** o que acontece se a jogadora **morrer** no meio? Se **carregar um save** no meio? Se sair correndo do corredor e entrar de novo, disparando o trigger duas vezes? Se o nível for descarregado? Uma cadeia de atrasos não tem um "estado" consultável — está espalhada em timers pendentes. Cancelá-la, reiniciá-la ou salvá-la é difícil.

### Opção B — Máquina de estado com tempo

A sequência vira um objeto com estado explícito: em que passo estou, e há quanto tempo.

```cpp
enum class EVGBlackoutStep : uint8 { Idle, CascadingLights, Silence, Footsteps, DoorSlam, Done };
```

**Vantagem:** consultável ("em que passo está?"), cancelável (volta para `Idle`), salvável (salva o passo), protegido contra disparo duplo (só começa a partir de `Idle`). **Custo:** mais código, menos imediato para um designer ajustar.

### Opção C — Ferramentas de autoria temporal

A Unreal tem ferramentas feitas para isso: **Timelines** (curvas e eventos no tempo, dentro de um Blueprint) e **Sequencer** (o editor de cinemáticas, que também serve para eventos roteirizados no mundo). Elas tiram o tempo do código e o colocam num editor visual, onde um designer ajusta "a porta bate 0,2 s mais cedo" sem tocar em lógica. É o tema do Capítulo 49.

### Opção D — Corrotinas

Algumas engines (e bibliotecas de terceiros para a Unreal, usando corrotinas do C++20) permitem escrever a sequência como uma função que "pausa" e "continua" ao longo dos frames: `apagar luz; co_await Seconds(0.3); apagar próxima...`. Lê-se como código sequencial, mas o tempo passa entre as linhas. É elegante; o cancelamento e o ciclo de vida continuam sendo as perguntas difíceis.

### A pergunta que decide: cancelamento

Em todas as opções, a pergunta de engenharia mais importante não é "como faço os passos acontecerem?", e sim **"o que acontece quando o mundo muda no meio?"** Para cada processo longo, defina explicitamente:

1. **Pode ser disparado de novo enquanto roda?** (Normalmente não: guarda de estado.)
2. **O que o interrompe?** (Morte da jogadora, cinemática, carregamento.)
3. **O que acontece ao ser interrompido?** (Para onde está? Volta ao início? Pula para o fim?)
4. **Precisa sobreviver a um save/load?** (Se sim, seu estado precisa ser salvável.)
5. **O que acontece se o objeto dono for destruído?**

Sobre o último ponto, uma boa notícia: na Unreal, timers associados a um `UObject` e nós `Delay` de Blueprint (*latent actions*) não executam se o objeto dono foi destruído. Mas eles também não **limpam** o que a sequência já fez — se a sequência apagou três luzes e foi interrompida, as luzes continuam apagadas. Isso é o que "pensar no cancelamento" significa.

> 🌉 **Ponte:** um processo que atravessa frames é uma **saga** ou um *process manager*: uma sequência de passos com estado próprio, que reage a eventos e precisa saber o que fazer quando é interrompida. Ferramentas como workflow engines (Temporal, por exemplo) existem exatamente para tornar esse estado explícito e durável.
>
> 🧱 **Onde a ponte cai:** sagas lidam com falha parcial em sistemas distribuídos e usam **compensação** (desfazer passos já feitos). Sequências de jogo raramente compensam — ninguém "reacende" as luzes porque a jogadora morreu; o jogo recarrega um checkpoint e reconstrói o mundo a partir do estado salvo. Em jogos, a estratégia de recuperação dominante não é compensar, é **reconstruir a partir de estado autoritativo** — mais um motivo para manter esse estado limpo e centralizado.

Para a Vigília, a decisão é: **sequências curtas e puramente audiovisuais** podem ser Timelines ou Sequencer; **sequências que alteram estado de gameplay ou narrativo** (destrancar uma porta, mudar o estado da Presença, registrar um fato) passam por estado explícito e consultável. No Interlúdio I (Projeto 4), você vai, propositalmente, fazer tudo com cadeias de `Delay` — e vai sentir na pele cada uma das cinco perguntas acima.

---

## 4.8 Estado, save e multiplayer: antecipando consequências

Dois sistemas que só chegam na Parte VIII e na Parte IX dependem inteiramente das decisões deste capítulo.

**Save (Capítulos 56–57).** Salvar um jogo é serializar o **estado autoritativo** e nada mais. Se ele está concentrado em donos bem definidos (componente de bateria, componente de vida, subsistema narrativo), o save é uma coleta organizada. Se está espalhado — booleanos no Level Blueprint, estado implícito em timers pendentes, "a porta está aberta porque a animação tocou" —, o save é um pesadelo, porque não há onde ler o estado. A tabela da seção 4.1 é a primeira versão da especificação do save.

**Multiplayer (Parte IX).** Num jogo com servidor autoritativo, a pergunta "quem é o dono?" ganha uma camada: o dono **roda no servidor**. Os clientes recebem o estado autoritativo replicado e reconstroem a apresentação localmente. Estado de apresentação nunca é replicado — cada cliente o deriva. A disciplina "apresentação é derivada" é, literalmente, o que torna a replicação possível. E a regra "complete o estado, depois anuncie" vira, na Unreal, o padrão de **RepNotify**: o cliente recebe o valor novo e, então, é notificado (Capítulo 65).

Em outras palavras: **as decisões de estado que você toma no Capítulo 4 são as que tornam os Capítulos 56 e 65 fáceis ou impossíveis.**

---

## Estudo de caso: o *wanted level* de GTA — estado, eventos e percepção

> **Pergunta:** como um sistema pequeno de estado, alimentado por eventos, consegue produzir algumas das situações mais memoráveis e variadas de um mundo aberto?

### O que é publicamente conhecido

**[FATO PÚBLICO]** Em *GTA: San Andreas* (Rockstar, 2004), crimes testemunhados pela polícia aumentam o **nível de procurado** do jogador, exibido como estrelas (até seis). Cada nível determina a intensidade da resposta: de policiais a pé e viaturas, passando por helicópteros e equipes táticas, até forças federais e militares nos níveis mais altos. Há formas conhecidas de reduzir ou eliminar o nível: oficinas de pintura de veículos (*Pay 'n' Spray*) limpam o nível de procurado, e ícones de suborno espalhados pela cidade reduzem uma estrela.

**[FATO PÚBLICO]** *GTA IV* (2008) introduziu um **círculo de busca** no minimapa: para escapar, o jogador precisa sair da área de busca e permanecer fora da vista da polícia. *GTA V* (2013) mostra no radar **cones de visão** dos policiais; quando o jogador não está sendo visto, as estrelas piscam, e permanecer sem ser visto por tempo suficiente faz o nível de procurado desaparecer.

Tudo o que segue é análise e inferência.

### 1. Experiência

Consequência e escalada. O mundo **reage** ao que você faz, de forma crescente e legível, e cada fuga é uma pequena história improvisada: o beco onde você se escondeu, o helicóptero que quase te viu, a oficina alcançada no último segundo.

### 2. Sistema

O núcleo é um **estado discreto** (o nível) com **eventos de entrada** (crimes, percepção) e **efeitos de saída** (resposta policial):

```text
 EVENTOS                     ESTADO                       EFEITOS
 ─────────                   ──────                       ───────
 crime testemunhado ──┐                                ┌─► spawner de polícia
 ataque a policial ───┼──► NÍVEL DE PROCURADO (0..N) ──┼─► perfil de resposta por nível
 visto / não visto ───┤    + "está sendo visto?"       ├─► HUD (estrelas, piscar)
 tempo sem ser visto ─┤    + tempo desde última visão  ├─► música e rádio da polícia
 pintura / suborno ───┘                                └─► comportamento de NPCs civis
```

### 3. Design

Três decisões merecem destaque:

- **O estado é pequeno e discreto.** Um número inteiro de 0 a 6 é imediatamente legível pelo jogador, e cada degrau corresponde a uma mudança **perceptível** na resposta. Um "nível de suspeita contínuo de 0,0 a 1,0" seria mais "preciso" e muito menos jogável.
- **A entrada é filtrada por percepção.** O crime só conta se for **testemunhado**. Isso transforma o sistema de punição num sistema de **furtividade**: o jogador aprende a cometer crimes sem testemunhas, a fugir da linha de visão, a usar o ambiente. Em GTA V, os cones de visão no radar tornam essa percepção explícita — o sistema mostra suas regras ao jogador para que ele possa jogar com elas (lembre-se do Capítulo 1: um sistema de percepção só vira design quando o jogador o entende).
- **A saída do estado é uma atividade.** Escapar não é esperar: é uma pequena missão emergente (sair do círculo, esconder-se, achar uma oficina). O estado mais "custoso" para o jogador gera o gameplay mais rico.

### 4. Tecnologia

**[INFERÊNCIA]** Um desenho compatível com o comportamento observável, sem nenhuma afirmação sobre o código da Rockstar:

- um **dono único** do nível de procurado (um sistema global), que recebe **pedidos** de outros sistemas: "crime de gravidade X ocorreu na posição P";
- o dono consulta a **percepção** (algum policial ou testemunha tinha linha de visão?) antes de aceitar o pedido — como o dono da vida que valida o dano;
- transições de nível **guardadas** e com regras de entrada/saída — inclusive, plausivelmente, alguma forma de **histerese** temporal (não basta sair da vista por um frame para começar a perder estrelas);
- os **efeitos** (spawn de unidades, música, HUD) se inscrevem nas mudanças de nível como **eventos**, enquanto informações contínuas (posição de busca, quem está vendo) são **consultadas**;
- a resposta por nível vem de **dados de configuração** (quantas unidades, de que tipos, a que distância), não de código.

### 5. Versão mínima

**[SIMPLIFICAÇÃO DIDÁTICA]**

```cpp
// Um "nível de alerta" mínimo, no estilo de um wanted level.
void UVGAlertSystem::ReportIncident(float Severity, bool bWitnessed)
{
    if (!bWitnessed) { return; }                         // percepção filtra a entrada

    Heat = FMath::Min(Heat + Severity, MaxHeat);
    TimeSinceSeen = 0.0f;
    UpdateLevel();
}

void UVGAlertSystem::Tick(float DeltaSeconds)
{
    if (CurrentLevel == 0) { return; }

    TimeSinceSeen = bPlayerSeenThisFrame ? 0.0f : TimeSinceSeen + DeltaSeconds;
    if (TimeSinceSeen >= EscapeTime)                     // escapou: não foi visto por tempo suficiente
    {
        Heat = 0.0f;
        UpdateLevel();
    }
}

void UVGAlertSystem::UpdateLevel()
{
    const int32 NewLevel = FMath::FloorToInt(Heat / HeatPerLevel);
    if (NewLevel != CurrentLevel)
    {
        const int32 OldLevel = CurrentLevel;
        CurrentLevel = NewLevel;                         // 1. muda o estado
        OnLevelChanged.Broadcast(OldLevel, NewLevel);    // 2. anuncia (spawner, HUD, música)
    }
}
```

### 6. Lição

**Um estado pequeno, legível, alimentado por eventos filtrados por percepção e consumido por vários sistemas produz comportamento emergente desproporcional ao seu tamanho.** O código do nível de procurado, em si, é simples. A riqueza vem das **conexões**: crime → percepção → estado → spawn → nova situação → resposta do jogador. É exatamente o laço de gameplay emergente que você descreveu com PES/FIFA, aplicado a uma cidade.

Para a Vigília, a lição vira o **nível de ameaça da Presença**: um estado discreto global — *calma*, *inquietação*, *caça* — alimentado por eventos de ruído (portas rangendo, objetos caindo, a jogadora correndo) **filtrados pela percepção** da Presença, e consumido pela IA, pela música, pela iluminação e pelos eventos roteirizados. Ele nasce no Capítulo 36 e é a semente do *AI Director* do Capítulo 42.

---

## Comparação consolidada com o desenvolvimento tradicional

| Conceito em jogos | Conceito que você conhece | Transfere? | Diferença essencial |
|---|---|---|---|
| Estado autoritativo vs. apresentação | Modelo de escrita vs. projeções (CQRS) | Sim | Projeção atualizada no mesmo frame, não eventualmente |
| Dono único | Single Writer Principle, encapsulamento de agregado | Sim | O problema é confusão entre sistemas, não contenção |
| FSM de gameplay | Ciclo de vida de entidade em DDD | Parcialmente | Transições por segundo, com ações audiovisuais e custo |
| Delegate / Broadcast | `ApplicationEventPublisher` síncrono do Spring | Sim | Nenhuma relação com mensageria assíncrona |
| Broadcast depois de mudar o estado | `@TransactionalEventListener(AFTER_COMMIT)` | Sim | Sem transação: disciplina manual |
| Corrida por ordem de tick | Corrida entre threads; entrega duplicada | Sim | Sem threads; a solução é idempotência e ordem explícita |
| Sequência roteirizada | Saga / process manager | Parcialmente | Recuperação por reconstrução, não por compensação |
| Histerese | Histerese em autoscaling / circuit breaker | Sim | Aplicada a estados perceptíveis pelo jogador |

A última linha é um bom exemplo de ponte que funciona: você provavelmente já configurou um *autoscaler* com limiares diferentes para escalar e reduzir, ou um *circuit breaker* que só fecha depois de várias chamadas bem-sucedidas, exatamente para evitar oscilação. A bateria da lanterna precisa do mesmo cuidado.

---

## Unreal Engine: onde o estado e os eventos moram

Uma visão de mapa; cada item é aprofundado mais adiante.

- **Estado em propriedades de Actors e Components** (`UPROPERTY`). Componentes são a unidade natural de "dono": `UVGBatteryComponent` é dono da carga. *(Capítulos 8–9)*
- **Estado de partida e de jogador** no Gameplay Framework: `AGameStateBase`, `APlayerState`. Importantes principalmente em multiplayer. *(Capítulo 10)*
- **Estado global com dono único** em **Subsystems** (`UGameInstanceSubsystem`, `UWorldSubsystem`). O dono da dilatação do tempo e o subsistema narrativo vão morar aqui. *(Capítulos 6 e 23)*
- **Estados nomeados e hierárquicos** com **Gameplay Tags** (`Status.Light.Flashlight`, `Narrative.Fact.LogbookFound`) — uma alternativa poderosa a enums quando o conjunto de estados é aberto ou definido por designers. *(Capítulo 23)*
- **Eventos** por delegates (`DECLARE_DYNAMIC_MULTICAST_DELEGATE_*`, `DECLARE_MULTICAST_DELEGATE_*`), por funções virtuais da engine (`NotifyActorBeginOverlap`, `OnTakeAnyDamage`) e por interfaces. *(Capítulo 24)*
- **Processos no tempo** com timers, latent actions de Blueprint (`Delay`), Timelines e Sequencer. *(Capítulos 2, 12, 49)*

---

## Implementação: o componente de bateria

Agora, o primeiro componente de gameplay **de verdade** do projeto Vigília — que vai acompanhar o livro até o projeto final: a bateria da lanterna. Ele aplica quase tudo deste capítulo:

- é **dono único** da carga (ninguém escreve `Charge` diretamente);
- expõe **operações com significado** (`Drain`, `Recharge`) que mantêm o invariante 0 ≤ carga ≤ máximo;
- tem um **estado discreto derivado** (`Charged`, `Low`, `Depleted`) com **histerese**;
- **anuncia transições** discretas por evento, **depois** de mudar o estado;
- **não** anuncia mudanças contínuas de carga (quem precisa, consulta);
- **não tem tick** — quem drena é a lanterna, no tick dela;
- tem **teste automatizado**.

```cpp
// Source/Vigilia/Player/VGBatteryComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGBatteryComponent.generated.h"

UENUM(BlueprintType)
enum class EVGBatteryState : uint8
{
    Charged,
    Low,
    Depleted
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGBatteryStateChangedSignature,
    EVGBatteryState, OldState, EVGBatteryState, NewState);

/**
 * Bateria de um equipamento (ex.: lanterna). Dona única da carga.
 * Não tem tick: quem consome chama Drain() com o próprio DeltaSeconds.
 * Transições discretas são anunciadas por evento; a carga contínua deve ser consultada.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGBatteryComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UVGBatteryComponent();

    /** Consome carga. Valores negativos são ignorados. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Battery")
    void Drain(float Amount);

    /** Adiciona carga, até o máximo. Valores negativos são ignorados. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Battery")
    void Recharge(float Amount);

    UFUNCTION(BlueprintPure, Category = "Vigilia|Battery")
    float GetCharge() const { return Charge; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Battery")
    float GetChargeRatio() const { return MaxCharge > 0.0f ? Charge / MaxCharge : 0.0f; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Battery")
    EVGBatteryState GetBatteryState() const { return State; }

    /** Disparado apenas em transições de estado (nunca a cada mudança de carga). */
    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Battery")
    FVGBatteryStateChangedSignature OnBatteryStateChanged;

protected:
    virtual void BeginPlay() override;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Battery", meta = (ClampMin = "1.0"))
    float MaxCharge = 100.0f;

    /** Abaixo desta fração, a bateria entra em Low. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Battery", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float LowThresholdRatio = 0.2f;

    /** Margem acima do limiar necessária para sair de Low (evita oscilação). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Battery", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float HysteresisRatio = 0.05f;

private:
    void SetCharge(float NewCharge);
    EVGBatteryState ComputeState() const;

    UPROPERTY(VisibleInstanceOnly, Category = "Vigilia|Battery")
    float Charge = 100.0f;

    UPROPERTY(VisibleInstanceOnly, Category = "Vigilia|Battery")
    EVGBatteryState State = EVGBatteryState::Charged;
};
```

```cpp
// Source/Vigilia/Player/VGBatteryComponent.cpp
#include "Player/VGBatteryComponent.h"

UVGBatteryComponent::UVGBatteryComponent()
{
    PrimaryComponentTick.bCanEverTick = false; // a bateria não faz nada sozinha
}

void UVGBatteryComponent::BeginPlay()
{
    Super::BeginPlay();
    SetCharge(MaxCharge); // começa cheia, respeitando o MaxCharge configurado no editor
}

void UVGBatteryComponent::Drain(float Amount)
{
    if (Amount > 0.0f)
    {
        SetCharge(Charge - Amount);
    }
}

void UVGBatteryComponent::Recharge(float Amount)
{
    if (Amount > 0.0f)
    {
        SetCharge(Charge + Amount);
    }
}

void UVGBatteryComponent::SetCharge(float NewCharge)
{
    // Único ponto de escrita da carga: o invariante é garantido aqui.
    Charge = FMath::Clamp(NewCharge, 0.0f, MaxCharge);

    const EVGBatteryState NewState = ComputeState();
    if (NewState != State)
    {
        const EVGBatteryState OldState = State;
        State = NewState;                                  // 1. estado consistente
        OnBatteryStateChanged.Broadcast(OldState, State);  // 2. só então anuncia
    }
}

EVGBatteryState UVGBatteryComponent::ComputeState() const
{
    if (Charge <= 0.0f)
    {
        return EVGBatteryState::Depleted;
    }

    const float Ratio = GetChargeRatio();
    if (State == EVGBatteryState::Charged)
    {
        return Ratio < LowThresholdRatio ? EVGBatteryState::Low : EVGBatteryState::Charged;
    }

    // Em Low ou Depleted: só volta para Charged acima do limiar + histerese.
    return Ratio >= LowThresholdRatio + HysteresisRatio ? EVGBatteryState::Charged : EVGBatteryState::Low;
}
```

### Explicação das decisões

- **`SetCharge` é privada e é o único lugar que escreve `Charge`.** `Drain` e `Recharge` são as portas públicas, com semântica. Se no futuro surgir "bateria que descarrega mais rápido no frio", a regra entra em `Drain` — um lugar só.
- **`Charge` e `State` são `VisibleInstanceOnly`.** Aparecem no painel de detalhes durante o jogo (ótimo para depurar), mas não podem ser editados nem lidos/escritos por Blueprint como variáveis. Blueprint usa as funções. É a disciplina do dono único aplicada à exposição (Capítulo 13).
- **`MaxCharge`, `LowThresholdRatio` e `HysteresisRatio` são `EditAnywhere`.** São **configuração**: designers ajustam por instância ou em Blueprints derivados. Em fases posteriores, podem migrar para um Data Asset compartilhado (Capítulo 20).
- **O delegate é dinâmico e `BlueprintAssignable`.** Isso permite que a HUD e efeitos feitos em Blueprint reajam às transições. O custo de delegates dinâmicos é maior que o de nativos, e irrelevante para um evento que dispara poucas vezes por partida.
- **O evento carrega estado antigo e novo.** O ouvinte não precisa guardar o anterior para saber que tipo de transição ocorreu (entrou em `Low`? saiu de `Depleted`?).
- **`BeginPlay` chama `SetCharge(MaxCharge)`** para respeitar o valor configurado. Repare que, se o estado inicial fosse diferente, isso dispararia um evento em `BeginPlay` — um detalhe que pode surpreender ouvintes que se inscrevem depois. Aqui o estado inicial é `Charged`, então nenhum evento é emitido.
- **Não há `OnChargeChanged`.** Decisão deliberada da seção 4.4. A barra da HUD vai consultar `GetChargeRatio()` a cada frame.

### O teste

Lógica de estado sem dependência de mundo, física ou tempo real é testável como qualquer lógica de domínio. A Unreal tem um framework de automação próprio; este é o teste mais simples possível:

```cpp
// Source/Vigilia/Tests/VGBatteryComponentTest.cpp
#include "Misc/AutomationTest.h"
#include "Player/VGBatteryComponent.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGBatteryStateTransitionsTest,
    "Vigilia.Player.Battery.StateTransitions",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGBatteryStateTransitionsTest::RunTest(const FString& Parameters)
{
    // Sem BeginPlay: usa os valores padrão (Max 100, Low < 20%, histerese 5%).
    UVGBatteryComponent* Battery = NewObject<UVGBatteryComponent>();

    TestTrue(TEXT("Começa Charged"), Battery->GetBatteryState() == EVGBatteryState::Charged);

    Battery->Drain(85.0f); // 15%
    TestTrue(TEXT("Abaixo de 20% vira Low"), Battery->GetBatteryState() == EVGBatteryState::Low);

    Battery->Recharge(7.0f); // 22%: acima do limiar, dentro da histerese
    TestTrue(TEXT("Histerese mantém Low"), Battery->GetBatteryState() == EVGBatteryState::Low);

    Battery->Recharge(10.0f); // 32%
    TestTrue(TEXT("Acima de 25% volta a Charged"), Battery->GetBatteryState() == EVGBatteryState::Charged);

    Battery->Drain(1000.0f);
    TestTrue(TEXT("Zero vira Depleted"), Battery->GetBatteryState() == EVGBatteryState::Depleted);
    TestEqual(TEXT("Carga nunca fica negativa"), Battery->GetCharge(), 0.0f);

    Battery->Drain(-50.0f);
    TestEqual(TEXT("Drain negativo é ignorado"), Battery->GetCharge(), 0.0f);

    return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
```

Para rodar: no editor, abra a janela de automação de testes (o caminho do menu varia entre versões do UE5 — procure por *Session Frontend → Automation* ou *Test Automation*), filtre por `Vigilia` e execute. O teste roda em milissegundos, sem abrir nível nenhum.

Note o que **não** foi testado: se a lanterna fica bonita piscando, se o som de bateria fraca é assustador, se 20% é o limiar certo para a tensão. Isso é playtest. O teste cobre exatamente a parte que pode quebrar silenciosamente — o invariante e as transições —, e só ela.

---

## Decisões arquiteturais

1. **Todo estado mutável tem um dono único** com operações nomeadas. Propriedades de estado não são expostas para escrita em Blueprint.
2. **Apresentação é sempre derivada.** HUD, áudio, VFX e animação leem ou reagem ao estado; nunca são consultados como fonte da verdade.
3. **Estados discretos são enums (ou Gameplay Tags), não combinações de booleanos.** Transições passam por uma função central.
4. **Valores contínuos: polling. Transições discretas: eventos.** Nada de evento disparado a cada frame.
5. **Broadcast é a última coisa da função**, depois que o estado está consistente.
6. **O dono decide as transições**, de forma guardada e idempotente. Quem pede não decide o resultado.
7. **Estados derivados de limiares usam histerese** quando o valor pode oscilar.
8. **Processos longos que mudam estado de gameplay têm estado explícito e política de cancelamento.** Sequências puramente audiovisuais podem usar ferramentas de autoria (Timeline, Sequencer).
9. **Lógica de estado sem dependência de mundo recebe teste automatizado.**

Nova pasta na convenção do projeto: `Source/Vigilia/Tests/`, para testes de automação.

---

## Armadilhas

- **Booleanos de modo.** `bIsOn`, `bIsFlickering`, `bIsOvercharging`: substitua por um estado.
- **Estado de verdade dentro da apresentação.** "Se a animação de morte está tocando, ele está morto." A animação pode ser interrompida, pulada ou nem existir em um servidor dedicado.
- **Broadcast antes de mudar o estado.** Ouvintes enxergam o passado.
- **Evento por frame.** `OnChargeChanged` disparado 60 vezes por segundo para alimentar uma barra.
- **Decisão de transição fora do dono.** O projétil decide que o inimigo morreu.
- **Dependência da ordem de ouvintes** de um multicast delegate.
- **Inscrição sem desinscrição.** O widget removido que ainda reage.
- **Limiar sem histerese** em valores que oscilam.
- **Sequência sem cancelamento.** Cadeias de `Delay` que continuam rodando depois que a jogadora morreu, ou disparam duas vezes.
- **Mexer em Data Assets em runtime** para guardar estado que deveria ser da instância.

---

## Exercício

**Parte 1 — o dono da dilatação do tempo (1,5 h).**
Em C++ puro (fora da Unreal, como na Parte A dos capítulos anteriores), implemente uma classe `TimeDilationRequests` que:

- `int Add(float Scale)` — registra um pedido e devolve um handle;
- `void Remove(int Handle)` — remove apenas aquele pedido;
- `float Effective() const` — devolve o **mínimo** dos pedidos ativos, ou 1,0 se não houver nenhum.

Escreva testes (com `assert` ou qualquer framework) para o cenário do Capítulo 3: bullet time pede 0,3; hitstop pede 0,05; hitstop remove o seu; o efetivo volta a 0,3; bullet time remove o seu; o efetivo volta a 1,0. Depois, discuta por escrito no `DEVLOG.md`: o mínimo é sempre a regra certa? E uma cinemática que precisa **forçar** a velocidade normal, mesmo com bullet time ativo? *(No Capítulo 6, essa lógica vira um `UWorldSubsystem`.)*

**Parte 2 — bateria na Unreal (1,5 h).**
Implemente o `UVGBatteryComponent` e o teste. Rode o teste. Depois, crie um Blueprint de ator qualquer com o componente e um nó de *Tick* que chama `Drain(10 × DeltaSeconds)`; ligue o evento `OnBatteryStateChanged` a um `Print String` que mostre estado antigo e novo. Observe as transições no jogo. Por último, coloque `HysteresisRatio = 0` e, no mesmo Tick, alterne `Drain` e `Recharge` para fazer a carga oscilar em torno de 20%. Quantos eventos são disparados por segundo?

**Parte 3 — FSM da lanterna no papel (45 min).**
Desenhe a tabela completa de transições da lanterna da seção 4.3: para cada par (estado atual, evento), qual o próximo estado? Eventos: `TogglePressed`, `FocusPressed`, `FocusReleased`, `BatteryLow`, `BatteryDepleted`, `BatteryReplaced`, `OverchargeTimeout`. Marque as combinações que devem ser ignoradas. Quais eventos vêm do input e quais vêm do `UVGBatteryComponent`?

---

## Desafio — o abate duplo e a sequência do apagão

**Parte A.** Crie um ator-alvo com um componente de vida **ingênuo** (sem guarda de morte) e um evento `OnDied` que incrementa um contador global de abates. Crie um ator que, num único frame, aplica dano letal ao alvo **duas vezes** (simulando dois projéteis). Observe o contador. Corrija com uma máquina de estado (`Alive`, `Dead`) e mostre que o contador fica correto. Depois, faça o ouvinte de `OnDied` aplicar dano ao próprio alvo (reentrância) e verifique que a correção também resolve esse caso.

**Parte B.** Implemente a "sequência do apagão" (seção 4.7) com quatro luzes, de duas formas: (1) uma cadeia de timers/`Delay`; (2) uma pequena máquina de estado com tempo. Para as duas, responda às cinco perguntas de cancelamento — e teste na prática: o que acontece se você sair e entrar de novo no trigger durante a sequência? E se destruir o ator da sequência no meio (`DestroyActor` via um segundo trigger)?

---

## Uso de IA

1. **Para auditar estado:**
   > "Abaixo está a classe de um personagem de um jogo em Unreal C++. Liste todo o estado mutável, classifique cada item em simulação / gameplay / narrativo / IA / apresentação / configuração, aponte quem escreve cada um e identifique estados com mais de um escritor, booleanos que deveriam ser um enum de estado, e estado de apresentação sendo usado como fonte da verdade."

2. **Para encontrar problemas de eventos:**
   > "Revise este código procurando problemas com delegates: broadcast antes de atualizar o estado, possibilidade de reentrância, dependência da ordem dos ouvintes, inscrições sem remoção e eventos disparados a cada frame. Para cada problema, descreva um cenário concreto de jogo em que ele causaria um bug visível."

3. **Para treinar modelagem:**
   > "Quero modelar o estado de uma arma de fogo em primeira pessoa (pronta, disparando, recarregando, sem munição, trocando de arma, inspecionando). Antes de me mostrar uma solução, faça-me perguntas sobre as regras de design (posso cancelar a recarga atirando? posso trocar de arma no meio da recarga?) e só depois proponha a tabela de transições."
   *(Este prompt pede que a IA te faça pensar antes de entregar a resposta — um padrão útil para estudo.)*

4. **Para conectar com o que você já sabe:**
   > "Compare o padrão de delegates multicast da Unreal com ApplicationEvent síncrono do Spring, com observers do Java e com publicação em Kafka, em termos de: momento de execução, thread, tratamento de erro, ordem, ciclo de vida dos ouvintes e garantias de entrega."

**Cuidado específico:** ao pedir código de testes de automação da Unreal, confira os nomes das flags e macros na documentação da sua versão — elas sofreram ajustes ao longo do UE5, e IAs frequentemente misturam versões.

---

## Checklist

- [ ] Consigo classificar o estado de um jogo nas seis categorias e dizer o que vai para o save.
- [ ] Sei explicar por que estado de apresentação nunca é fonte da verdade.
- [ ] Aplico a regra do dono único e sei resolver múltiplos pedidos sobre o mesmo estado.
- [ ] Sei transformar booleanos de modo em uma máquina de estado com transições centralizadas.
- [ ] Sei o que é histerese e quando usá-la.
- [ ] Sei escolher polling ou eventos para um dado estado.
- [ ] Entendo que `Broadcast` é uma chamada síncrona e conheço os riscos de ordem, reentrância e ciclo de vida.
- [ ] Consigo explicar e corrigir o bug do abate duplo.
- [ ] Sei responder às cinco perguntas de cancelamento para uma sequência roteirizada.
- [ ] Implementei e testei o `UVGBatteryComponent`.
- [ ] Consigo decompor o wanted level de GTA como estado + eventos + percepção.

---

## Para ir além

- **Robert Nystrom, *Game Programming Patterns*** — capítulos **"State"**, **"Observer"** e **"Event Queue"** (gameprogrammingpatterns.com). Leitura quase obrigatória depois deste capítulo; o capítulo "State" usa um personagem de jogo de plataforma como exemplo e mostra a evolução de booleanos para FSM, FSM hierárquica e autômato com pilha.
- **Martin Thompson, "Single Writer Principle"** (blog *Mechanical Sympathy*) — o princípio do escritor único na origem, no contexto de alta performance.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — páginas sobre **Delegates** e sobre **Automation Testing**.
- **Jason Gregory, *Game Engine Architecture*** — capítulos sobre sistemas de gameplay em runtime, objetos de jogo e eventos/mensagens.

---

➡️ **Próximo:** [Capítulo 5 — Gameplay Loop](cap-05-gameplay-loop.md)

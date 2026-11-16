# Capítulo 54 — VFX

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que um efeito visual **comunica** (confirmação, estado, atmosfera) e por que efeito que não comunica é ruído caro;
- descrever a anatomia do **Niagara**: sistemas, emissores, estágios, módulos, *renderers* e parâmetros de usuário;
- escolher entre simulação em **CPU** e em **GPU**;
- construir os efeitos de combate da Vigília: **impactos** com *pooling* e orçamento, ***muzzle flash*** e o **sinalizador queimando** como um efeito que mostra estado;
- usar efeitos para a **luz** (o feixe na poeira, o pulso da sobrecarga) e para a **atmosfera** (névoa, poeira, gotejamento);
- usar **materiais de pós-processamento** (o contorno de interação prometido no Capítulo 19);
- estimar o **custo** de partículas (*overdraw*, contagem, luzes) e controlá-lo com escalabilidade.

---

## Contexto

O Niagara entrou na Vigília pela porta dos fundos: o Capítulo 27 adicionou o módulo ao `Build.cs` para o `UVGImpactEffects`, um Data Asset que toca som, partículas e decal por tipo de superfície. Desde então, cada impacto cria um sistema novo, sem limite e sem reaproveitamento. Outros capítulos deixaram ganchos:

- o Capítulo 27 criou `OnShotTracer` (o rastro do tiro saindo do cano), um evento de Blueprint sem efeito ainda;
- o Capítulo 28 deu ao sinalizador três estados (`Flying`, `Burning`, `Spent`) e um evento `OnFlareStateChanged` para a apresentação;
- o Capítulo 19 desenhou o foco de interação com *custom depth* e prometeu "um material de pós-processamento (Capítulo 54)" para o contorno;
- o Capítulo 32 prometeu "efeitos Niagara à distância" para a sensação de escala;
- o Capítulo 51 deixou o feixe da lanterna esperando poeira para aparecer, e a sobrecarga sem efeito visual.

E o Capítulo 51 deixou um problema de arquitetura que reaparece aqui: as luminárias reagem aos sinais do Diretor ouvindo o barramento e medindo a distância até a jogadora. Este capítulo vai precisar de **outra** coisa que reaja ao mesmo sinal (poeira caindo do teto), e duas cópias da mesma lógica é o momento de extraí-la.

---

## 54.1 O que um efeito comunica

Um efeito visual num jogo faz uma ou mais de três coisas:

| Função | Pergunta que responde | Exemplos na Vigília |
|---|---|---|
| **Confirmação** | "Minha ação teve efeito?" | Faísca no impacto; o tranco do vigia (Cap. 53); o clarão da sobrecarga |
| **Estado** | "Como está o mundo agora?" | O sinalizador queimando (= zona segura ativa) e se apagando; a Presença "queimando" quando a luz a atinge |
| **Atmosfera** | "Onde estou, e como devo me sentir?" | Poeira no feixe; névoa no subsolo; gotejamento; vapor |

E há uma quarta função, o **espetáculo** (explosões que impressionam), que a Vigília quase não usa. Num jogo de terror, espetáculo demais é alívio, e alívio na hora errada mata a tensão.

A regra que sai da tabela: **todo efeito tem uma função escrita**. Um efeito sem função é custo de GPU e ruído visual competindo com os efeitos que comunicam. Num jogo escuro isso é ainda mais grave, porque qualquer partícula clara chama o olho, e o olho da jogadora é o recurso mais disputado do jogo (Caps. 50 e 51).

> 🌉 **Ponte:** é a mesma disciplina de um painel de observabilidade: cada gráfico responde a uma pergunta; um gráfico bonito que ninguém usa para decidir nada é poluição que esconde os que importam.
>
> 🧱 **Onde a ponte cai:** num painel, a pessoa **procura** a informação. No jogo, o efeito **chama** a atenção sozinho, quer você queira ou não: brilho e movimento capturam o olhar involuntariamente. Um efeito irrelevante não é ignorado; ele distrai.

---

## 54.2 Niagara: a anatomia

O **Niagara** é o sistema de efeitos do UE5. Ele trata partículas como **dados**: arrays de atributos (posição, velocidade, cor, tamanho, idade) processados em estágios por módulos.

```text
 NIAGARA SYSTEM (o asset que você coloca ou dispara: NS_*)
 │
 ├─ parâmetros de usuário (User.*) ◄──── o jogo escreve aqui (SetVariableFloat, ...)
 │
 ├─ EMITTER "Faiscas"                       ├─ EMITTER "Fumaca"
 │   ├─ Emitter Spawn   (uma vez)            │   ...
 │   ├─ Emitter Update  (por frame: quantas nascer)
 │   ├─ Particle Spawn  (cada partícula nasce: posição, velocidade, vida)
 │   ├─ Particle Update (cada partícula, por frame: gravidade, arrasto, cor pela idade)
 │   ├─ Event Handlers  (ex.: colidiu → emitir outra coisa)
 │   └─ RENDERERS: Sprite, Mesh, Ribbon, Light...  (como as partículas viram pixels)
 │
 └─ (opcional) Simulation Stages, Data Interfaces (ler malha, colisão, textura...)
```

Os **módulos** são pequenos programas empilhados em cada estágio (há uma biblioteca grande: *Add Velocity*, *Gravity Force*, *Drag*, *Color from Curve*, *Collision*...). Os ***renderers*** decidem a forma visual: *sprites* (quadrados virados para a câmera), malhas, fitas (*ribbons*, para rastros) e até luzes. Os **parâmetros** vivem em *namespaces*: `User.` (escritos pelo jogo), `System.`, `Emitter.`, `Particles.` (por partícula).

A ponte entre gameplay e efeito é o `UNiagaraComponent` e os **parâmetros de usuário**:

```cpp
// O jogo nunca mexe em partículas; ele escreve parâmetros, e o efeito decide o que fazer com eles.
BurnFx->SetVariableFloat(TEXT("Restante"), 0.4f);
BeamDust->SetVariableVec3(TEXT("FeixeOrigem"), Origin);
```

⚠️ Os parâmetros de usuário aparecem no editor como `User.Restante`; na escrita por código e por Blueprint, o nome sem o prefixo funciona (a engine redireciona para o *namespace* de usuário). Confira na sua versão, e mantenha o nome **idêntico** ao do asset: um erro de digitação não gera erro, só um efeito que não reage.

### CPU ou GPU

Cada emissor simula na CPU ou na GPU:

| | CPU | GPU |
|---|---|---|
| **Quantidade** | Dezenas a poucos milhares | Milhares a centenas de milhares |
| **Interação com o jogo** | Eventos, leitura de atributos, *Light renderer* | Limitada; colisão por buffers de profundidade/campos de distância |
| **Custo** | Cresce rápido com a contagem, na CPU | Barato por partícula; custo fixo de *dispatch* |
| **Limites (*bounds*)** | Calculados | Precisam ser **fixos** (⚠️ ou o efeito some quando os limites calculados saem da tela) |
| **Na Vigília** | Faíscas de impacto, muzzle flash, o núcleo do sinalizador | Poeira no feixe, brasas do sinalizador, névoa de partículas |

> 🌉 **Ponte:** o Niagara é um *pipeline* de processamento **data-parallel**: cada estágio é um *map* sobre arrays de atributos (estrutura de arrays, *SoA*), e a GPU é a escolha natural quando o mesmo cálculo roda sobre muitos elementos sem dependência entre eles.
>
> 🧱 **Onde a ponte cai:** num *pipeline* de dados, o resultado precisa ser correto e, de preferência, determinístico. Uma simulação de partículas só precisa **parecer** certa. Ninguém audita a trajetória da décima milésima brasa, e por isso aproximações grosseiras (ruído no lugar de física, colisão contra profundidade em vez de geometria) são a regra, não o atalho.

---

## 54.3 Efeitos de combate

O Capítulo 29 descreveu a sensação de uma arma como a soma coordenada de camadas: som, coice, recuo de câmera, tremor, *muzzle flash* e impactos. Este capítulo faz as camadas visuais que faltam.

**O *muzzle flash*** dura de um a três frames. É um clarão curto no cano, um pouco de fumaça que se dissipa e, às vezes, uma luz breve que ilumina o entorno. Três decisões:

- **É curto de verdade.** Um clarão que dura 0,2 s parece uma explosão no cano.
- **A luz do clarão não projeta sombra.** Uma luz de 50 ms com sombra é custo puro (Cap. 51), e a sombra mal teria tempo de ser vista. ⚠️ Luzes geradas por partículas (o *Light renderer*) funcionam com simulação em CPU; confira na sua versão.
- **Num jogo escuro, ele é informação tática.** O clarão da arma de um vigia no escuro do pátio (setor 2) é como a jogadora sabe **de onde** atiram. O clarão do vigia é mais visível do que realista, de propósito.

**O rastro do tiro** (`OnShotTracer`, Cap. 27): uma fita curta (*ribbon*) do cano ao ponto de impacto, visível por poucos frames. Ele sai do **cano** (apresentação), mesmo que o acerto seja calculado da câmera (Cap. 27).

**O impacto** é o trio do `UVGImpactEffects` (som, partículas, decal por superfície), com dois problemas novos que o setor 2 vai expor: **quantidade** (um tiroteio com dois vigias gera dezenas de impactos por segundo) e **alcance** (um impacto a 60 m não precisa de faíscas que ninguém vê). A seção de implementação resolve os dois com *pooling* nativo e um orçamento por frame.

> **O *pooling* já existe.** O Capítulo 32 construiu o `UVGActorPoolSubsystem` para atores. Para sistemas Niagara, a engine tem o próprio *pool* de componentes: as funções de *spawn* recebem um método de *pooling* (`ENCPoolMethod`), e com `AutoRelease` o componente volta ao *pool* ao terminar. É o degrau "já existe na engine" da escada: não escreva outro.

---

## 54.4 O sinalizador: um efeito que é estado

O sinalizador é a ferramenta mais importante da jogadora contra a Presença (Cap. 28), e o efeito dele não é decoração: ele **é** a interface da zona segura temporária. Enquanto queima, a jogadora precisa saber, sem olhar para nenhum número:

1. **que está queimando** (a zona está ativa);
2. **onde a proteção termina** (o raio de ~6 m);
3. **quanto tempo resta**, sobretudo quando está acabando.

A luz responde ao item 2 (o círculo iluminado **é** a zona, pela linguagem de luz do Capítulo 51). O efeito responde aos itens 1 e 3:

```text
 NS_Sinalizador (parâmetro de usuário: Restante, de 1 a 0)

  Flying   ─► rastro de faíscas (ribbon) + fumaça fina
  Burning  ─► núcleo incandescente (CPU, sprites aditivos)
              + faíscas que saltam (CPU, poucas)
              + brasas que sobem (GPU, muitas, baratas)
              + coluna de fumaça (sprites translúcidos: o item mais caro)
              com Restante < 0,25: o núcleo "engasga" (falhas de intensidade),
              as faíscas rareiam → a jogadora LÊ que está acabando
  Spent    ─► só a fumaça, se dissipando
```

E uma regra de sincronia: **a luz e o efeito leem a mesma fonte**. Se o núcleo engasga, a luz engasga junto; se a luz se apaga, o efeito termina. Duas animações independentes de "acabando" (uma na luz, outra nas partículas) logo divergem, e a jogadora vê a luz forte com o efeito morrendo, ou o contrário. O sinalizador calcula o `Restante` uma vez e entrega aos dois.

---

## 54.5 Efeito e luz

**O feixe na poeira.** O feixe da lanterna é visível no ar por dois mecanismos que se somam:

- a **névoa volumétrica** (Cap. 51), que dá ao cone um volume contínuo e suave;
- **partículas de poeira** perto da câmera, que dão textura e movimento ao feixe.

A poeira tem um truque de custo. Partículas iluminadas de verdade pela lanterna exigem materiais translúcidos *lit*, caros. A alternativa barata: partículas **não iluminadas** (*unlit*), cuja opacidade depende de estarem **dentro do cone** do feixe. O sistema recebe, por parâmetros de usuário, a origem, a direção e o cosseno do ângulo do feixe, e um módulo calcula, por partícula, "estou dentro do cone e a que distância da origem?". Fora do cone, a poeira é invisível; dentro, ela brilha. O resultado parece luz, e custa um produto escalar por partícula.

**O pulso da sobrecarga** (Cap. 51) tem três camadas visuais em 0,3 s: o clarão (a própria luz, multiplicada), um cone curto de partículas brilhantes que "varrem" para a frente e a poeira do feixe disparando de uma vez. Depois, o preço: o feixe fraco por 1 s, que o efeito acompanha com a poeira quase sumindo.

**A Presença atingida pela luz.** Em Alan Wake, a escuridão dos inimigos se desfaz visivelmente sob a lanterna (estudo de caso). A Vigília usa a mesma ideia como **confirmação**: quando o dano de luz chega, o `UVGPresenceReactionComponent` (Cap. 37) dispara `NS_Presenca_Queimada` no ponto atingido, uma fumaça escura que se desfaz com faíscas frias. A jogadora sabe que acertou, e de onde a Presença recuou, sem nenhum marcador.

---

## 54.6 Atmosfera e pós-processamento

### Atmosfera

- **Névoa.** A *Exponential Height Fog* com névoa volumétrica cobre o espaço inteiro; ⚠️ versões recentes do UE5 têm *Local Fog Volumes* para concentrar névoa num ambiente (o subsolo) sem pagar por ela em todos. Névoa reduz a distância de visão, e isso é level design (Cap. 50): mais névoa, linhas de visão mais curtas, mais tensão.
- **Poeira suspensa** nos espaços abandonados (as partículas do feixe).
- **Gotejamento** no subsolo: gotas de malha pequena que caem, com um respingo e um som (o mesmo evento: o efeito e o som saem juntos, como passo e ruído no Capítulo 52).
- **Vapor e faíscas** de equipamentos, nos setores 2 e 3: a usina viva.
- **Poeira caindo do teto** como sinal de `BuildUp` do Diretor: perto da jogadora, uma nuvem fina de poeira cai das vigas, como se algo pesado tivesse passado em cima. É a versão visual do "ruído distante de passos" do Capítulo 42. A jogadora não vê nada, mas sabe que algo se moveu.

### Pós-processamento

Materiais de pós-processamento rodam sobre a imagem inteira, depois da renderização da cena, e podem ler buffers como a profundidade da cena e o ***custom depth*** (uma profundidade separada só dos objetos marcados).

O **contorno de interação**, prometido no Capítulo 19, é o caso clássico: o componente de interação liga o *custom depth* no objeto focado (`SetRenderCustomDepth(true)`, Cap. 19), e um material de pós-processamento compara o *custom depth* de cada pixel com o dos vizinhos para achar a borda do objeto e desenhá-la. ⚠️ Para usar o *stencil* (e ter contornos de cores diferentes por tipo de objeto), o projeto precisa do *Custom Depth-Stencil Pass* habilitado "com stencil" nas configurações de renderização.

A decisão de design da Vigília, coerente com o Capítulo 50: o contorno é **confirmação, não descoberta**. Ele aparece só no objeto focado (já ao alcance de 220 cm, Cap. 19), é fino e quente, e some quando ela desvia o olhar. Quem descobre o objeto é a luz e a *affordance*; o contorno só diz "sim, isto".

E uma fronteira com o próximo capítulo: a **vinheta de dano** ("dois toques", Cap. 21) é um efeito de pós-processamento, mas o **dono** dela é a camada de UI (Cap. 55), que já sabe do estado da vida. O efeito é a ferramenta; a decisão de quando mostrar é da UI.

---

## 54.7 O custo das partículas

O custo de efeitos tem quatro fontes, em ordem de quanto costumam doer:

1. ***Overdraw* de translúcidos.** Cada sprite translúcido grande na tela é desenhado por cima dos outros, e cada camada paga o *pixel shader* inteiro. Uma coluna de fumaça de 40 sprites grandes vista de dentro pode custar mais que o resto da cena. O modo de visualização ***Quad Overdraw*** (e o *Shader Complexity*) mostra o problema. Defesas: menos partículas maiores em vez de muitas pequenas sobrepostas; partículas que somem perto da câmera; materiais simples.
2. **Contagem e simulação.** Milhares de partículas em CPU custam caro no *game thread*; em GPU, quase nada por partícula. Escolha o lado certo (seção 54.2).
3. **Luzes de partículas.** Cada luz é uma luz (Cap. 51). Faíscas com luz própria multiplicam o custo de iluminação.
4. **Instâncias.** Cem sistemas pequenos ativos custam mais que um grande, por sobrecarga fixa por sistema.

A Unreal oferece o controle de escala no próprio Niagara: os ***Effect Types*** (`UNiagaraEffectType`) agrupam sistemas e definem, por nível de qualidade, distância de *culling*, número máximo de instâncias e regras de significância (⚠️ confira as opções na sua versão). O *pooling* reduz o custo de criar e destruir componentes. E o ***Niagara Debugger*** mostra o que está ativo e quanto custa.

O orçamento, como na luz (Cap. 51), é **por espaço e por momento**. O pior momento de efeitos da Vigília é o encontro dos vigias no setor 2: tiros, impactos, *muzzle flashes*, talvez um sinalizador, e a névoa do pátio. É ali que o Capítulo 58 vai medir.

---

## Estudos de caso

### Alan Wake — o efeito como estado da mecânica

**[FATO PÚBLICO, observável jogando]** Em *Alan Wake* (Remedy, 2010), os Taken aparecem envoltos numa escuridão visível. Sob o foco da lanterna, essa escuridão se desfaz progressivamente, e o fim da proteção é marcado por um efeito de luz claro, depois do qual as armas passam a feri-los.

**[INFERÊNCIA]** O efeito é a **barra de vida da proteção**, sem barra nenhuma: a jogadora vê a escuridão diminuir e sabe quanto falta. E o clarão final é a confirmação de mudança de estado ("agora pode atirar"). É provavelmente um parâmetro contínuo (o quanto da proteção resta) alimentando o efeito, como o `Restante` do sinalizador, mas como a Remedy o implementou não é público.

**Lição para a Vigília:** dois usos diretos. O sinalizador mostra o tempo que resta pelo próprio efeito (seção 54.4), e a Presença atingida pela luz "queima" visivelmente (seção 54.5). O efeito é a interface de uma mecânica.

### Control — espetáculo e legibilidade

**[FATO PÚBLICO, observável jogando]** *Control* (Remedy, 2019) é conhecido pelos ambientes destrutíveis: em combate, os poderes da protagonista arrancam pedaços de paredes, mesas e concreto, enchendo a sala de detritos, poeira e partículas.

**[INFERÊNCIA]** A destruição é espetáculo **e** confirmação: o poder "Lançar" atinge com um impacto que o ambiente inteiro registra. O custo de design é a legibilidade: num combate cheio de detritos, os inimigos e os projéteis precisam continuar visíveis, o que provavelmente exige cuidado com cor, contraste e duração das partículas de ambiente em relação às de ameaça.

**Lição para a Vigília:** a Vigília tem muito menos espetáculo, mas a mesma regra no tiroteio do setor 2: a poeira dos impactos não pode esconder o clarão das armas dos vigias, que é a informação tática principal. Partículas de ambiente baixas e escuras; clarões altos e curtos.

### Battlefield e Call of Duty — escala sem NPCs

**[FATO PÚBLICO, observável jogando]** Campanhas e mapas de *Battlefield* e *Call of Duty* frequentemente mostram, ao fundo, explosões, rastros de tiros, aviões e fumaça de combates que o jogador não alcança.

**[INFERÊNCIA]** Boa parte da "sensação de escala" vem de efeitos baratos à distância, sem nenhuma IA por trás: um sistema de partículas que dispara rastros no horizonte custa uma fração de um único soldado simulado. É a resposta à pergunta do Capítulo 32 (escala com poucos NPCs): **a escala é encenada**.

**Lição para a Vigília:** a Vigília não quer escala, quer **presença**. A mesma técnica serve: a turbina 3 vista pela janela (setor 1) com faíscas e vapor que nunca serão alcançados; luzes piscando ao longe na subestação; a usina "viva" encenada por efeitos baratos em lugares onde a jogadora nunca chega.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Efeito com função | Gráfico que responde a uma pergunta | O efeito captura a atenção sozinho; o irrelevante distrai |
| Niagara | *Pipeline* data-parallel (SoA) | Precisa parecer certo, não ser certo |
| Parâmetros de usuário | Interface de configuração em *runtime* | Nome errado falha em silêncio |
| *Pooling* de componentes | *Pool* de conexões/objetos | — (a analogia vale; e já existe na engine) |
| Orçamento por frame | *Rate limiting* | O que se corta é escolhido pela percepção (o longe, o fora da tela), não por justiça |
| Escala encenada | *Mock* convincente | Aqui o *mock* vai para produção, de propósito |

---

## Unreal Engine: o que existe

- **Niagara**: sistemas, emissores, módulos, *renderers* (Sprite, Mesh, Ribbon, Light, Component), *Data Interfaces*, *Simulation Stages*, parâmetros de usuário; o editor de Niagara e o ***Niagara Debugger***.
- **Em C++** (módulo `Niagara`, já no `Build.cs` desde o Cap. 27): `UNiagaraComponent` (`Activate`, `Deactivate`, `SetVariableFloat`, `SetVariableVec3`, `SetVariableLinearColor`, `SetVariableObject`), `UNiagaraFunctionLibrary::SpawnSystemAtLocation` e `SpawnSystemAttached` (com `ENCPoolMethod` e *pre-cull*), `UNiagaraEffectType` para escalabilidade.
- **Decals**: `UGameplayStatics::SpawnDecalAtLocation`, `UDecalComponent` (com *fade* por tempo e por tela).
- **Névoa**: *Exponential Height Fog*, *Volumetric Fog*, ⚠️ *Local Fog Volumes*.
- **Pós-processamento**: *Post Process Volume*, materiais de domínio *Post Process*, *Custom Depth/Stencil*.
- **Visualização**: *Quad Overdraw*, *Shader Complexity*, *Lighting Only*; comandos `stat` de partículas (⚠️ confira os disponíveis na sua versão).

O que a engine **não** oferece: a decisão de qual efeito comunica o quê, e o orçamento por espaço.

---

## Abordagens: impactos em quantidade

| Critério | A. Um sistema novo por impacto (atual) | **B. *Pool* nativo + distância + orçamento por frame** | C. *Pool* próprio de componentes (como o `UVGActorPoolSubsystem`) |
|---|---|---|---|
| **Complexidade** | Mínima | **Baixa** | Média |
| **Custo de criar/destruir** | Alto em tiroteios | **Baixo** (componentes reaproveitados) | Baixo |
| **Picos** (20 impactos no mesmo frame) | Sem limite | **Limitados pelo orçamento** | Limitados |
| **Código novo** | Nenhum | **Um parâmetro e uma regra** | Um subsistema inteiro |
| **Adequação à Vigília** | Quebra no setor 2 | **Sim** | Reescrever o que a engine já faz |

**Decisão: B.** O `ENCPoolMethod::AutoRelease` cuida do reaproveitamento; uma regra pura decide se um impacto merece efeito (distância e orçamento); o som continua sempre (o áudio tem a própria concorrência, Cap. 52).

---

## Implementação

### 1. A regra do orçamento

```cpp
// Source/Vigilia/Combat/VGImpactRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGImpactRules
{
    /**
     * O impacto merece partículas e decal? Longe demais, não; acima do orçamento do frame, não.
     * O som não passa por aqui (tem concorrência própria, Cap. 52).
     */
    bool ShouldSpawnVisuals(float DistanceToViewSquared, float MaxDistance, int32 SpawnedThisFrame, int32 FrameBudget);
}
```

```cpp
// Source/Vigilia/Combat/VGImpactRules.cpp
#include "Combat/VGImpactRules.h"

bool VGImpactRules::ShouldSpawnVisuals(float DistanceToViewSquared, float MaxDistance, int32 SpawnedThisFrame, int32 FrameBudget)
{
    return FrameBudget > 0
        && SpawnedThisFrame < FrameBudget
        && DistanceToViewSquared <= FMath::Square(MaxDistance);
}
```

### 2. 🔁 O `UVGImpactEffects` com *pool* e orçamento

**Antes** (Cap. 27), `PlayAt` criava um sistema Niagara e um decal a cada acerto, sem limite. **O problema:** no tiroteio do setor 2, dois vigias e a jogadora geram dezenas de impactos por segundo, muitos longe ou fora da tela, e os picos aparecem como engasgos. **Agora:**

```cpp
// VGImpactEffects.h (adição)
    /** Além desta distância (da câmera), só o som. */
    UPROPERTY(EditDefaultsOnly, Category = "Impact", meta = (ClampMin = "100.0"))
    float MaxVisualDistance = 4000.0f;
```

```cpp
// VGImpactEffects.cpp (🔁 PlayAt)
#include "Camera/PlayerCameraManager.h"
#include "Combat/VGImpactRules.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"
#include "NiagaraFunctionLibrary.h"
#include "PhysicalMaterials/PhysicalMaterial.h"

static TAutoConsoleVariable<int32> CVarVGImpactBudget(
    TEXT("vg.Fx.ImpactBudget"), 8, TEXT("Máximo de impactos com partículas/decal por frame (0 = só som)."), ECVF_Scalability);

void UVGImpactEffects::PlayAt(const UObject* WorldContext, const FHitResult& Hit) const
{
    const EPhysicalSurface Surface = UPhysicalMaterial::DetermineSurfaceType(Hit.PhysMaterial.Get());
    const FVGImpactEffect* Found = BySurface.Find(Surface);
    const FVGImpactEffect& Effect = Found ? *Found : Default;

    if (Effect.Sound)
    {
        UGameplayStatics::PlaySoundAtLocation(WorldContext, Effect.Sound, Hit.ImpactPoint);
    }

    // Simplificação: contador global por frame (GFrameCounter). Com vários mundos ao mesmo tempo
    // (PIE com clientes, Parte IX), o orçamento é dividido entre eles; mova-o para um subsistema se importar.
    static uint64 BudgetFrame = 0;
    static int32 SpawnedThisFrame = 0;
    if (BudgetFrame != GFrameCounter)
    {
        BudgetFrame = GFrameCounter;
        SpawnedThisFrame = 0;
    }

    FVector ViewLocation = Hit.ImpactPoint;
    if (const APlayerCameraManager* Camera = UGameplayStatics::GetPlayerCameraManager(WorldContext, 0))
    {
        ViewLocation = Camera->GetCameraLocation();
    }
    if (!VGImpactRules::ShouldSpawnVisuals(FVector::DistSquared(ViewLocation, Hit.ImpactPoint), MaxVisualDistance,
                                           SpawnedThisFrame, CVarVGImpactBudget.GetValueOnGameThread()))
    {
        return;
    }
    ++SpawnedThisFrame;

    if (Effect.Particles)
    {
        UNiagaraFunctionLibrary::SpawnSystemAtLocation(WorldContext, Effect.Particles, Hit.ImpactPoint,
            Hit.ImpactNormal.Rotation(), FVector(1.0f), /*bAutoDestroy=*/true, /*bAutoActivate=*/true,
            ENCPoolMethod::AutoRelease, /*bPreCullCheck=*/true); // pool nativo; o pre-cull usa o Effect Type
    }
    if (Effect.Decal)
    {
        UGameplayStatics::SpawnDecalAtLocation(WorldContext, Effect.Decal, FVector(Effect.DecalSize),
            Hit.ImpactPoint, (-Hit.ImpactNormal).Rotation(), Effect.DecalLifeSpan);
    }
}
```

O `ECVF_Scalability` marca a CVar como de escalabilidade: o Capítulo 55 pode expô-la como "qualidade de efeitos", e o 58 pode ajustá-la por plataforma.

### 3. 🔁 O *muzzle flash*

```cpp
// VGWeaponData.h (adição)
    /** Clarão no cano: curto (1–3 frames), luz sem sombra. Preso ao Muzzle, com pool. */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Weapon|FX")
    TObjectPtr<class UNiagaraSystem> MuzzleFlash;

// VGWeapon.cpp, no disparo (junto de OnFired, Cap. 20):
    if (Data->MuzzleFlash)
    {
        UNiagaraFunctionLibrary::SpawnSystemAttached(Data->MuzzleFlash, Muzzle, NAME_None,
            FVector::ZeroVector, FRotator::ZeroRotator, EAttachLocation::SnapToTarget,
            /*bAutoDestroy=*/true, /*bAutoActivate=*/true, ENCPoolMethod::AutoRelease);
    }
```

O rastro (`OnShotTracer`, Cap. 27) continua em Blueprint: um `NS_Rastro` com um *ribbon* de dois pontos, recebendo `From`/`To` por parâmetros de usuário.

### 4. 🔁 O sinalizador com estado

```cpp
// VGFlareProjectile.h (adições)
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<class UNiagaraComponent> BurnFx; // NS_Sinalizador, parâmetro "Restante"

private:
    float BaseLightIntensity = 0.0f; // lido da luz no BeginPlay (valor do Blueprint)
    float BurnStartTime = 0.0f;
```

```cpp
// VGFlareProjectile.cpp (essencial)
//   construtor:  BurnFx = CreateDefaultSubobject<UNiagaraComponent>(TEXT("BurnFx"));
//                BurnFx->SetupAttachment(RootComponent);
//                BurnFx->SetAutoActivate(false);
//   BeginPlay:   BaseLightIntensity = Light->Intensity;

void AVGFlareProjectile::StartBurning()
{
    // ... o que o Cap. 28 já fazia (estado, zona segura, timer de pulsos)
    BurnStartTime = GetWorld()->GetTimeSeconds();
    BurnFx->SetVariableFloat(TEXT("Restante"), 1.0f);
    BurnFx->Activate(/*bReset=*/true);
}

void AVGFlareProjectile::Pulse()
{
    // ... o pulso de luz do Cap. 28
    // Uma fonte para a luz E para o efeito: os dois "acabam" juntos (seção 54.4).
    const float Remaining = 1.0f - FMath::Clamp((GetWorld()->GetTimeSeconds() - BurnStartTime) / BurnDuration, 0.0f, 1.0f);
    BurnFx->SetVariableFloat(TEXT("Restante"), Remaining);
    Light->SetIntensity(BaseLightIntensity * FMath::Lerp(0.5f, 1.0f, FMath::Min(Remaining * 4.0f, 1.0f)));
}

void AVGFlareProjectile::Extinguish()
{
    // ... o que o Cap. 28 já fazia
    BurnFx->Deactivate(); // as partículas vivas terminam a vida (a fumaça se dissipa), sem corte
}
```

O `Pulse` já roda a cada `PulseInterval` (0,5 s) durante a queima; dois parâmetros por meio segundo bastam, porque o `NS_Sinalizador` interpola internamente. A luz cai à metade só no último quarto da queima: a jogadora vê a zona **encolhendo** quando falta pouco. O "engasgo" do núcleo fica no efeito (abaixo de `Restante` 0,25) e pode ser repetido na luz com um perfil de flicker, se o playtest pedir.

### 5. O sinal do Diretor como componente

🔁 **Antes** (Cap. 51), o `AVGLightFixture` ouvia o barramento, filtrava `Event.Director.BuildUp` e media a distância até a jogadora dentro do próprio `HandleEvent`. **O problema:** a poeira do teto precisa da mesma lógica, e a segunda cópia é o momento de extrair. **Agora**, um componente faz isso e anuncia; quem reage decide **como**:

```cpp
// Source/Vigilia/World/VGDirectorSignalComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "VGDirectorSignalComponent.generated.h"

struct FVGGameplayEvent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FVGDirectorSignalSignature);

/** Anuncia OnSignal quando o Diretor entra em BuildUp com a jogadora a até Radius do dono. */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGDirectorSignalComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UPROPERTY(EditAnywhere, Category = "Vigilia|Director", meta = (ClampMin = "100.0"))
    float Radius = 1500.0f;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Director")
    FVGDirectorSignalSignature OnSignal;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    void HandleEvent(const FVGGameplayEvent& Event);
    FDelegateHandle EventHandle;
};
```

```cpp
// Source/Vigilia/World/VGDirectorSignalComponent.cpp
#include "World/VGDirectorSignalComponent.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"

void UVGDirectorSignalComponent::BeginPlay()
{
    Super::BeginPlay();
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &UVGDirectorSignalComponent::HandleEvent);
    }
}

void UVGDirectorSignalComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::EndPlay(EndPlayReason);
}

void UVGDirectorSignalComponent::HandleEvent(const FVGGameplayEvent& Event)
{
    if (Event.Channel != TAG_Event_Director_BuildUp)
    {
        return;
    }
    const APlayerController* PC = GetWorld()->GetFirstPlayerController();
    const APawn* Player = PC ? PC->GetPawn() : nullptr;
    if (Player && FVector::DistSquared(Player->GetActorLocation(), GetOwner()->GetActorLocation()) <= FMath::Square(Radius))
    {
        OnSignal.Broadcast();
    }
}
```

No `AVGLightFixture` (Cap. 51), `SignalRadius`, a inscrição no barramento e o corpo de `HandleEvent` saem. A luminária ganha um `UVGDirectorSignalComponent` (`DirectorSignal`, criado no construtor) e um handler `UFUNCTION() void HandleDirectorSignal()` inscrito em `OnSignal`, com só a parte que é dela: "se `bDirectorSignals`, se não protejo zona, se estou acesa e tenho perfil, falho por `SignalSeconds`". A distância passa a ser o `Radius` do componente.

A poeira do teto é um Blueprint, `BP_PoeiraDoTeto`: um `UNiagaraComponent` com `NS_Poeira_Teto` (desativado) e um `UVGDirectorSignalComponent`; no `OnSignal`, ele ativa o efeito uma vez e toca um rangido baixo de madeira e metal. Nenhuma linha de C++ nova para cada coisa que reage ao Diretor daqui em diante.

### 6. O teste

```cpp
// Source/Vigilia/Tests/VGImpactRulesTest.cpp
#include "Combat/VGImpactRules.h"
#include "Misc/AutomationTest.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGImpactRulesTest, "Vigilia.Combat.ImpactBudget",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGImpactRulesTest::RunTest(const FString& Parameters)
{
    const float Near = FMath::Square(500.0f);
    const float Far = FMath::Square(6000.0f);
    TestTrue(TEXT("Perto e dentro do orçamento"),  VGImpactRules::ShouldSpawnVisuals(Near, 4000.0f, 0, 8));
    TestFalse(TEXT("Longe demais: só som"),        VGImpactRules::ShouldSpawnVisuals(Far, 4000.0f, 0, 8));
    TestFalse(TEXT("Orçamento do frame esgotado"), VGImpactRules::ShouldSpawnVisuals(Near, 4000.0f, 8, 8));
    TestFalse(TEXT("Orçamento zero = só som"),     VGImpactRules::ShouldSpawnVisuals(Near, 4000.0f, 0, 0));
    TestTrue(TEXT("Exatamente no limite conta"),   VGImpactRules::ShouldSpawnVisuals(FMath::Square(4000.0f), 4000.0f, 7, 8));
    return true;
}

#endif
```

### Explicação das decisões

- **O som do impacto não passa pelo orçamento visual.** Ouvir um tiro acertar a parede atrás de você é informação; vê-lo a 60 m, não. Cada canal tem o seu limite (a concorrência de áudio, Cap. 52).
- **`ENCPoolMethod::AutoRelease` em vez de um *pool* próprio**: a engine já tem, e o degrau da escada diz para usar.
- **Contador por frame estático, com `// Simplificação:`** declarando o limite (vários mundos ao mesmo tempo) e o caminho de evolução (um subsistema).
- **`Restante` calculado uma vez no sinalizador**, entregue à luz e ao efeito: duas apresentações, uma fonte.
- **`Deactivate`, não `DestroyComponent`**, ao apagar: as partículas vivas terminam a vida, e a fumaça se dissipa em vez de sumir.
- **O sinal do Diretor virou componente na segunda cópia**, não na primeira. No Capítulo 51, com uma luminária só, um componente teria sido abstração especulativa.
- **Parâmetros por evento ou a 2 Hz, interpolação no Niagara**: a mesma regra das MetaSounds (Cap. 52).

---

## Projeto Vigília — os efeitos do setor 1

### Lista de efeitos, com função

| Efeito | Onde | Função | Sim. | Notas |
|---|---|---|---|---|
| `NS_PoeiraFeixe` | Preso à câmera | Atmosfera + luz | GPU | Opacidade pelo cone do feixe (parâmetros `FeixeOrigem`, `FeixeDirecao`, `FeixeCos`); some quando a lanterna apaga |
| `NS_Sobrecarga` | Na lanterna | Confirmação | CPU | 0,3 s de cone brilhante; a poeira dispara junto |
| `NS_Presenca_Queimada` | No ponto atingido | Confirmação + estado | CPU | Disparado pelo `UVGPresenceReactionComponent` |
| `NS_Sinalizador` | No sinalizador | Estado | CPU + GPU | `Restante` de 1 a 0; engasgo abaixo de 0,25 |
| `NS_Gota` | Subsolo | Atmosfera | CPU | Com respingo e som no mesmo evento |
| `NS_Poeira_Teto` | Corredor, subsolo | Sinal do Diretor | GPU | Via `UVGDirectorSignalComponent` |
| `NS_Turbina_Faiscas` | Atrás da janela da sala de controle | Presença encenada | GPU | Inalcançável (Cap. 50: o landmark) |
| Impactos (`DA_Impacto_*`) | Onde acertar | Confirmação | CPU | *Pool* + orçamento |

E três materiais de pós-processamento ou de ambiente:

- `M_PP_Contorno`: o contorno de interação, fino, quente, só no objeto focado.
- *Local fog volume* no subsolo (ou névoa de altura mais densa nele, se a sua versão não tiver o recurso).
- Os decals da vinheta "as mãos na poeira" (Cap. 48), com `MI_Decal_MaoPoeira`, visíveis à luz da lanterna.

### O feixe na poeira

Um Blueprint pequeno no `BP_VGJogadora` atualiza `NS_PoeiraFeixe` quando o estado da lanterna muda (`OnStateChanged`, Cap. 51: desliga o efeito com a lanterna apagada) e, enquanto acesa, escreve origem, direção e cosseno do ângulo externo a cada frame (são três parâmetros baratos; aqui, a cada frame é justificado, porque o feixe se move com a câmera). A `vg.Camera.Motion` (Cap. 18) não afeta a poeira, mas a opção de "efeitos reduzidos" do Capítulo 55 pode desligá-la.

### O orçamento

No pior momento do setor 1 (a cascata do susto, com a lanterna acesa e a névoa do corredor), registre no `DEVLOG.md` o número de sistemas ativos, o de partículas (Niagara Debugger) e a visualização de *Quad Overdraw* do corredor. Repita no pátio dos vigias (setor 2, blockout do Cap. 50) com um tiroteio de teste e `vg.Fx.ImpactBudget` em 8 e em 2. O Capítulo 58 parte desses números.

---

## Decisões arquiteturais

1. **Todo efeito tem uma função escrita** (confirmação, estado, atmosfera); espetáculo quase nunca.
2. **Gameplay escreve parâmetros de usuário, nunca partículas**; interpolação dentro do Niagara.
3. **Impactos: *pool* nativo + distância + orçamento por frame** (`vg.Fx.ImpactBudget`); o som fica fora do orçamento visual.
4. **O sinalizador é a interface da zona segura**: `Restante` como fonte única da luz e do efeito.
5. **Poeira no feixe por cone em partículas *unlit***, não por partículas iluminadas.
6. **O contorno de interação é confirmação, não descoberta.**
7. **Sinais do Diretor por componente (`UVGDirectorSignalComponent`)**, extraído na segunda cópia.
8. **Orçamento de efeitos por espaço e por momento** (o pior: o tiroteio do setor 2).

---

## Armadilhas

- **Efeito sem função**, competindo com os que comunicam no escuro.
- **Fumaça translúcida grande na frente da câmera** (*overdraw*).
- **Um sistema novo por impacto**, sem *pool* nem limite.
- **Luzes de partículas com sombra**, ou muitas faíscas com luz própria.
- **Limites (*bounds*) dinâmicos em emissores de GPU**, e o efeito que some na borda da tela.
- **Nome de parâmetro digitado diferente** do asset: o efeito simplesmente não reage.
- **Luz e efeito "acabando" por relógios diferentes.**
- ***Muzzle flash* longo**, ou realista demais para ser lido no escuro.
- **Poeira de impacto escondendo o clarão do inimigo**, que é a informação tática.
- **`DestroyComponent` ao apagar**, cortando as partículas no meio da vida.
- **Mutar estado num Data Asset** (o `UVGImpactEffects`) como se fosse instância: ele é compartilhado.

---

## Exercício

**Parte 1 — anatomia (1 h).** Crie `NS_Gota` do zero (um emissor CPU, *spawn* por *burst*, gravidade, colisão, um evento de colisão gerando o respingo num segundo emissor). Anote no `DEVLOG.md` em que estágio cada módulo ficou e por quê.

**Parte 2 — impactos (1,5 h).** Implemente `VGImpactRules`, o teste e o 🔁 do `UVGImpactEffects`. Crie um *Effect Type* para os impactos com *culling* por distância. No Galpão de Testes, esvazie um pente na parede a 5 m e a 50 m com `vg.Fx.ImpactBudget` em 8 e em 1, e observe no Niagara Debugger quantos sistemas ficam ativos.

**Parte 3 — armas e sinalizador (2 h).** Faça o `NS_MuzzleFlash` (1–3 frames), o `NS_Rastro` no `OnShotTracer` e o `NS_Sinalizador` com o parâmetro `Restante`. Faça o 🔁 do `AVGFlareProjectile`. Jogue no escuro e responda sem olhar para nenhum número: quanto tempo o sinalizador ainda tem?

**Parte 4 — luz e atmosfera (2 h).** Faça `NS_PoeiraFeixe` com o teste de cone, o `NS_Sobrecarga` e o `NS_Presenca_Queimada`. Implemente `UVGDirectorSignalComponent`, faça o 🔁 da luminária e monte `BP_PoeiraDoTeto`. Force um `BuildUp` (uma trava do Diretor) perto da jogadora e confira que luz e poeira reagem juntas.

**Parte 5 — contorno (45 min).** Faça `M_PP_Contorno` com *custom depth*. Compare um contorno grosso e branco com um fino e quente, no escuro: qual "explica demais"?

---

## Desafio — a Presença que deixa rastro

A Presença quase nunca é vista. Desenhe um efeito que mostre **por onde ela passou**, sem mostrar ela.

1. Ideias de partida: poeira suspensa que demora a assentar no caminho dela; geada fina no vidro aramado da sala de controle; o vapor do subsolo que se desvia. Escolha **uma** e justifique pela função (estado: "ela esteve aqui").
2. Implemente com o que existe: um efeito disparado pelo corpo dela (um notify de passo, Cap. 53, ou um timer), com vida longa e custo baixo (GPU, poucas partículas, sem luz).
3. Decida a regra de honestidade (como o som no Capítulo 52): o rastro pode aparecer onde ela **não** passou, para enganar a jogadora? Registre a decisão e o motivo no `DEVLOG.md`.

---

## Uso de IA

1. **Para projetar um efeito:**
   > "Quero um efeito Niagara de sinalizador queimando no chão, para um jogo de terror escuro, com um parâmetro de usuário 'Restante' (1 a 0) que mostra o tempo que falta. Proponha os emissores (CPU ou GPU, e por quê), os módulos de cada estágio, os renderers e o que muda com 'Restante' abaixo de 0,25. Diga quais emissores são os mais caros e como reduzir o overdraw da fumaça."

2. **Para auditar o custo:**
   > "Esta é a lista de efeitos ativos no pior momento de um nível (abaixo: sistema, emissores, sim CPU/GPU, partículas máximas, material translúcido ou não, luzes). Ordene pelo custo provável de GPU e de CPU, explique o raciocínio e proponha três cortes que preservem a função de cada efeito. [lista]"

3. **Para revisar a função dos efeitos:**
   > "Para cada efeito desta tabela de um jogo de terror (abaixo), diga se a função declarada (confirmação, estado, atmosfera) é plausível, se ele compete pela atenção com algo mais importante na mesma cena e se poderia ser removido sem perder informação. [tabela]"

**Cuidado específico:** nomes de módulos e de opções do Niagara mudaram bastante entre versões, e a IA os cita com segurança. Pior: ela tende a sugerir efeitos **mais** ricos (mais emissores, mais partículas, mais luz) do que um jogo escuro aguenta, porque "mais" parece "melhor" em descrição. Peça sempre o custo junto, e julgue o resultado na tela, no escuro, com a lanterna.

---

## Checklist

- [ ] Sei dizer a função de cada efeito da Vigília, e não há efeito sem função.
- [ ] Sei a anatomia do Niagara e onde cada módulo vai.
- [ ] Sei escolher CPU ou GPU para um emissor e por quê.
- [ ] Os impactos usam *pool* nativo e orçamento, e o som não depende do orçamento visual.
- [ ] O sinalizador mostra quanto tempo resta, com a luz e o efeito lendo a mesma fonte.
- [ ] O feixe aparece na poeira sem partículas iluminadas.
- [ ] O contorno de interação existe e só confirma.
- [ ] Os sinais do Diretor passam por um componente, e luz e poeira reagem juntas.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Niagara** (visão geral, *emitters*, *modules*, *renderers*, *user parameters*, *Effect Types* e escalabilidade, *Niagara Debugger*), **Post Process Materials**, **Custom Depth and Stencil**, **Volumetric Fog** e **Decals**.
- **GDC Vault** (gdcvault.com): a trilha de efeitos visuais e arte técnica tem palestras sobre efeitos em jogos de ação e sobre otimização de partículas (confira títulos e autores lá).
- **Jason Gregory, *Game Engine Architecture*** — as seções sobre efeitos visuais e o pipeline de renderização, para situar partículas e pós-processamento.

---

➡️ **Próximo:** [Capítulo 55 — UI/UX](cap-55-ui-ux.md)

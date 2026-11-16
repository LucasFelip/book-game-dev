# Capítulo 35 — Navigation

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar como a Unreal gera uma **malha de navegação** (NavMesh) a partir da geometria e como ela é usada para encontrar caminhos;
- configurar **agentes** de navegação (raio, altura, degrau, inclinação) e o modo de **geração em runtime**;
- mover agentes com `MoveTo` e reagir ao resultado, entendendo o papel do **path following**;
- usar **áreas de navegação com custo** e **filtros por agente** para que agentes diferentes enxerguem o mesmo espaço de formas diferentes;
- transformar a regra de design "a Presença não entra na luz" num **mapa de navegação** dinâmico;
- tratar **portas**, saltos e quedas com modificadores e links, e conhecer as opções de **evitação** entre agentes.

---

## Contexto

O vigia da HFSM do Capítulo 34 já investiga: ao perder a jogadora, ele chama `MoveToLocation` e anda até a última posição conhecida. Para isso funcionar, você colocou um `NavMeshBoundsVolume` no Galpão sem saber exatamente o que ele fazia. Este capítulo explica.

Navegação é a etapa "como chego lá?" do ciclo de IA (Capítulo 33). Para você, que conhece grafos e algoritmos de caminho mínimo, a parte algorítmica é a menos interessante — a Unreal já faz isso bem. O interessante está em duas outras perguntas: **como o espaço contínuo de um nível vira um grafo**, e **como usar custos e filtros para que a navegação expresse regras de design**. Na Vigília, a segunda é central: a Presença não entra na luz, e uma porta fechada a detém. Essas duas frases do documento de design vão virar **dados de navegação**.

---

## 35.1 Do nível ao grafo: a NavMesh

Um nível é geometria contínua: chão, paredes, escadas, caixas. Buscar caminhos num espaço contínuo é caro; buscar num **grafo** é barato. A **malha de navegação** é a ponte: um conjunto de **polígonos convexos** que cobrem as superfícies por onde um agente pode andar. Dentro de um polígono convexo, qualquer ponto alcança qualquer outro em linha reta; entre polígonos vizinhos, há **arestas** compartilhadas. O grafo de caminho são os polígonos e suas adjacências.

A Unreal gera a NavMesh com a biblioteca **Recast**, num processo em etapas:

```text
 geometria com colisão
        │  1. VOXELIZAÇÃO — o espaço vira uma grade de células (voxels)
        ▼
 voxels "sólidos"
        │  2. FILTRAGEM pelo agente — remove o que é baixo demais (teto), íngreme demais,
        ▼     estreito demais (raio do agente), degraus altos demais
 superfícies andáveis
        │  3. REGIÕES e CONTORNOS — agrupa células em regiões e traça bordas
        ▼
 polígonos convexos  ──►  NavMesh (dados consultáveis pela biblioteca Detour)
```

O **agente** define a navegação. Os parâmetros principais (em *Project Settings → Navigation System → Agents*, e no ator `RecastNavMesh` do nível):

| Parâmetro | Efeito |
|---|---|
| **Agent Radius** | A malha é "encolhida" das paredes por esse raio: o centro do agente nunca chega mais perto que isso de uma parede. |
| **Agent Height** | Espaços com teto mais baixo que isso não são andáveis. |
| **Max Step Height** | Degraus até essa altura são atravessáveis. |
| **Max Slope** | Rampas mais íngremes que isso não são andáveis. |
| **Cell Size / Cell Height** | Resolução da voxelização: menor = mais preciso, mais caro de gerar e mais memória. |

Agentes com corpos diferentes precisam de malhas diferentes: a Presença é **alta e magra** (passa por frestas que um vigia não passa, mas não por dutos baixos); o vigia tem o tamanho de uma pessoa. A Unreal suporta **vários agentes suportados** (*Supported Agents*), cada um com a sua NavMesh, e escolhe para cada pawn a malha mais adequada ao tamanho da cápsula dele.

> 🌉 **Ponte:** é a mesma ideia de um mapa de ruas para roteamento: o espaço contínuo da cidade vira um grafo de vias, e o roteador opera no grafo. Os "parâmetros do agente" são como o tipo de veículo: uma moto e um caminhão têm grafos diferentes da mesma cidade.
>
> 🧱 **Onde a ponte cai:** a NavMesh de um jogo pode **mudar em runtime** (portas, objetos movidos, zonas que acendem), e cada agente consulta o grafo **dezenas de vezes por minuto**, dentro do orçamento de frame.

### Depurar a NavMesh

No editor, a tecla **P** no viewport mostra a NavMesh (em verde) sobre o nível. Durante o jogo, `show navigation` no console faz o mesmo, e o Gameplay Debugger tem uma categoria de navegação. **Olhe para a NavMesh sempre que a IA se comportar de forma estranha em um lugar específico**: na maior parte das vezes, o problema é a malha (um buraco, uma ponte que não conecta, uma porta que não deixa passar), não a decisão.

---

## 35.2 Geração em runtime

A NavMesh pode ser gerada de três formas (*Project Settings → Navigation Mesh → Runtime Generation*):

| Modo | O que muda em runtime | Custo | Uso |
|---|---|---|---|
| **Static** | Nada; a malha é gerada no editor | Zero em runtime | Níveis sem mudanças de navegação |
| **Dynamic Modifiers Only** | Só **áreas** marcadas por modificadores (custo/exclusão) podem mudar; a geometria base não é refeita | Baixo | **Portas, zonas de luz, áreas perigosas** — o caso da Vigília |
| **Dynamic** | A malha é regenerada em pedaços (*tiles*) quando a geometria muda | Médio a alto | Destruição, objetos grandes movidos pelo jogador |

A Vigília usa **Dynamic Modifiers Only**: a geometria da usina não muda, mas as **regras** sobre ela mudam — uma zona acende, uma porta fecha. É o modo mais barato que suporta isso.

---

## 35.3 Mover um agente

O `AAIController` move o pawn que controla:

```cpp
const EPathFollowingRequestResult::Type Result = AIController->MoveToLocation(
    Destination,
    /*AcceptanceRadius=*/50.0f,       // "cheguei" a até 50 cm do destino
    /*bStopOnOverlap=*/true,
    /*bUsePathfinding=*/true,
    /*bProjectDestinationToNavigation=*/true, // destino fora da malha? usa o ponto válido mais próximo
    /*bCanStrafe=*/false,
    /*FilterClass=*/nullptr,          // nullptr = filtro padrão do controller (seção 35.4)
    /*bAllowPartialPath=*/true);      // sem caminho completo? vai até onde der
```

Por trás, três coisas acontecem:

1. **Busca de caminho** — A* sobre o grafo de polígonos, considerando custos de área (seção 35.4).
2. **Suavização** — o caminho de polígonos vira uma sequência de pontos com um algoritmo de "puxar o barbante" (*string pulling*, ou *funnel*): o agente corta cantos em linha reta, em vez de passar pelo centro de cada polígono.
3. **Seguimento** — o `UPathFollowingComponent` do controller alimenta o movimento do pawn (`CharacterMovementComponent`) ponto a ponto, verificando progresso e bloqueios.

O resultado chega de forma assíncrona: o controller recebe `OnMoveCompleted(RequestID, Result)` com o motivo — chegou, abortado (outro movimento foi pedido), bloqueado, caminho inválido. O cérebro do agente (FSM, Behavior Tree) reage a isso. A HFSM do Capítulo 34 consultava `HasReachedMoveTarget()`; a partir deste capítulo, o componente do cérebro escuta o resultado real.

### Caminhos parciais

Se não há caminho completo até o destino (a jogadora subiu numa caixa inacessível), `bAllowPartialPath` faz o agente ir até o ponto **mais próximo** alcançável. Para um vigia investigando, é o comportamento certo — ele chega o mais perto possível e procura. Para a Presença caçando, também: ela fica **embaixo** da caixa, esperando. (Isso pode ser exatamente o momento mais assustador de uma perseguição.)

---

## 35.4 Áreas, custos e filtros: navegação como regra de design

Cada polígono da NavMesh pertence a uma **área de navegação** (`UNavArea`), com:

- **custo de travessia** (multiplicador sobre a distância): uma área com custo 5 "parece" cinco vezes mais longa para o A*;
- **custo fixo de entrada**: um pedágio para entrar na área;
- **flags** que filtros podem usar.

As áreas são definidas por **modificadores**: volumes (`NavModifierVolume`) colocados no nível, ou componentes (`UNavModifierComponent`) em atores, que marcam a região que cobrem com uma área.

E cada agente pode usar um **filtro de consulta** (`UNavigationQueryFilter`) que **reinterpreta** as áreas: excluir uma área inteira, mudar o custo dela, aceitar ou recusar flags. **O mesmo espaço, com as mesmas áreas, vira mapas diferentes para agentes diferentes.**

### A escuridão como mapa

Aqui está o ponto do capítulo. O pilar da Vigília — **"a Presença não entra na luz"** — vira navegação:

```text
 ÁREA                     Presença (filtro)            Vigia (filtro)       Jogadora
 ────                     ─────────────────            ──────────────       ────────
 Default (escuro)         custo 1                       custo 1              —
 Lit (luz ativa)          EXCLUÍDA                      custo 1              — (é a zona segura)
 DoorClosed (porta        EXCLUÍDA                      custo 3 (abre a porta)
   fechada)
```

- Toda **zona segura** (Capítulo 23) ganha um modificador de navegação que, **enquanto a zona está ativa**, marca a região como `Lit`. Quando um setor é energizado e as zonas acendem, a NavMesh da Presença **perde** aquelas regiões. Quando o sinalizador acende (Capítulo 28), a zona temporária dele faz o mesmo por oito segundos.
- Toda **porta fechada** marca o vão como `DoorClosed`. A Presença não atravessa portas fechadas: **fechar uma porta atrás de si** é uma ferramenta de fuga real. O vigia atravessa (com custo extra) e abre a porta ao chegar.

A consequência de design é poderosa e coerente: a jogadora **aprende uma regra** ("a luz e as portas me protegem") e a IA **obedece à mesma regra pelos mesmos motivos**, porque a regra está no mapa. Não há `if (estáNaLuz) fuja()` escondido no cérebro da Presença — ela simplesmente não encontra caminho até lá. E o pathfinding faz o resto: se a única rota até a jogadora passa por um corredor iluminado, a Presença **dá a volta** pela escuridão, ou espera.

> Isso é o "contrato uniforme" do Capítulo 6 aplicado ao espaço: zonas seguras, sinalizadores, setores energizados e portas usam o **mesmo** mecanismo, e qualquer fonte nova de luz que marque a área `Lit` é automaticamente respeitada pela Presença.

---

## 35.5 Portas, saltos e quedas

### Portas

Portas são o caso mais comum de navegação dinâmica. A Vigília usa o modificador de área (seção 35.4) em vez de deixar a porta "esculpir" a NavMesh com a sua colisão (o que exigiria geração dinâmica completa, mais cara). Para o vigia, a porta fechada é atravessável com custo; quando ele chega perto, a porta **abre** — implementado de forma simples: a porta tem um pequeno volume que, ao detectar um agente da facção `Guard` se aproximando com a porta destrancada, chama a abertura. (É uma simplificação honesta; uma versão mais rica faria o vigia **interagir** com a porta pela mesma interface da jogadora — o desafio do capítulo.)

### Links de navegação

Às vezes o agente precisa atravessar algo que não é chão contínuo: **pular** de uma passarela para outra, **cair** de uma plataforma, subir uma escada de mão. **Nav Links** (o ator `NavLinkProxy`) conectam dois pontos da NavMesh que não são adjacentes, com direção (ida, volta ou ambas). *Smart links* podem disparar um evento quando o agente chega a eles, para tocar uma animação de salto ou de escalada.

Para a Presença, links são uma ferramenta de **design de horror**: um link que só ela usa (uma descida pelo poço das turbinas) cria rotas que a jogadora não pode seguir — e faz a Presença aparecer onde não "deveria".

---

## 35.6 Evitação entre agentes

Dois agentes seguindo caminhos que se cruzam vão colidir. A Unreal oferece duas abordagens:

- **RVO** (*Reciprocal Velocity Obstacles*), no próprio `CharacterMovementComponent` (`bUseRVOAvoidance`): cada agente ajusta a velocidade para evitar os vizinhos. Simples de ligar, adequado para poucos agentes.
- **Detour Crowd**: um controller de multidão (`ADetourCrowdAIController`, ou o `UCrowdFollowingComponent`) que coordena a evitação de vários agentes ao longo dos caminhos. Mais robusto para grupos.

A Vigília tem, no máximo, um punhado de agentes simultâneos; RVO nos vigias é suficiente. A Presença não precisa de evitação — ela está sempre sozinha.

---

## Comparação com o desenvolvimento tradicional

| Navegação | O que você conhece | Onde a analogia cai |
|---|---|---|
| NavMesh | Grafo de rotas gerado a partir de um mapa | Gerado da geometria por voxelização, por tipo de agente |
| A* + string pulling | Caminho mínimo + suavização | Em polígonos, com custos de área e filtros por agente |
| Áreas e filtros | Pesos de arestas por tipo de veículo/política | Mudam em runtime e expressam **regras de design** |
| Modo Dynamic Modifiers Only | Atualizar pesos sem reconstruir o grafo | — transfere bem |
| Path following assíncrono | Requisição com callback de conclusão | O "progresso" é físico (colisões, bloqueios) |

---

## Implementação

### 1. Áreas de navegação

```cpp
// Source/Vigilia/AI/VGNavAreas.h
#pragma once

#include "CoreMinimal.h"
#include "NavAreas/NavArea.h"
#include "VGNavAreas.generated.h"

/** Região iluminada por luz ativa (zona segura, sinalizador, setor energizado). */
UCLASS()
class VIGILIA_API UVGNavArea_Lit : public UNavArea
{
    GENERATED_BODY()
public:
    UVGNavArea_Lit()
    {
        DefaultCost = 1.0f;
        DrawColor = FColor(255, 220, 120); // visível na depuração da NavMesh
    }
};

/** Vão de porta fechada. */
UCLASS()
class VIGILIA_API UVGNavArea_DoorClosed : public UNavArea
{
    GENERATED_BODY()
public:
    UVGNavArea_DoorClosed()
    {
        DefaultCost = 3.0f; // para quem atravessa (vigia), abrir uma porta "custa" mais
        DrawColor = FColor(160, 60, 60);
    }
};
```

### 2. Filtros por agente

```cpp
// Source/Vigilia/AI/VGNavFilters.h
#pragma once

#include "CoreMinimal.h"
#include "NavFilters/NavigationQueryFilter.h"
#include "VGNavFilters.generated.h"

/** A Presença: não entra na luz e não atravessa portas fechadas. */
UCLASS()
class VIGILIA_API UVGNavFilter_Presence : public UNavigationQueryFilter
{
    GENERATED_BODY()
public:
    UVGNavFilter_Presence();
};
```

```cpp
// Source/Vigilia/AI/VGNavFilters.cpp
#include "AI/VGNavFilters.h"

#include "AI/VGNavAreas.h"

UVGNavFilter_Presence::UVGNavFilter_Presence()
{
    FNavigationFilterArea Lit;
    Lit.AreaClass = UVGNavArea_Lit::StaticClass();
    Lit.bIsExcluded = true;
    Areas.Add(Lit);

    FNavigationFilterArea Door;
    Door.AreaClass = UVGNavArea_DoorClosed::StaticClass();
    Door.bIsExcluded = true;
    Areas.Add(Door);
}
```

No `BP_VGAIController_Presenca`, defina **Default Navigation Filter Class = `UVGNavFilter_Presence`**: todo `MoveTo` da Presença sem filtro explícito usa esse filtro. O vigia usa o filtro padrão (todas as áreas, com seus custos).

### 3. Zonas seguras marcam a luz

🔁 O `AVGSafeZone` (Capítulo 23) ganha um modificador de navegação:

```cpp
// VGSafeZone.h (adição)
    UPROPERTY(VisibleAnywhere, Category = "Components")
    TObjectPtr<class UNavModifierComponent> NavModifier;
```

```cpp
// VGSafeZone.cpp (trechos)
#include "AI/VGNavAreas.h"
#include "NavAreas/NavArea_Default.h"
#include "NavModifierComponent.h"

// no construtor:
//   NavModifier = CreateDefaultSubobject<UNavModifierComponent>(TEXT("NavModifier"));
//   (o modificador usa os limites de colisão do ator — o volume da zona)
//   Volume->SetCanEverAffectNavigation(true);

void AVGSafeZone::SetZoneActive(bool bActive)
{
    // ... lógica de tags do Cap. 23 ...
    NavModifier->SetAreaClass(bActive ? UVGNavArea_Lit::StaticClass() : UNavArea_Default::StaticClass());
}
```

Com *Runtime Generation = Dynamic Modifiers Only*, a mudança de área é aplicada à NavMesh em runtime. Verifique com `show navigation`: ao ativar a zona, a região muda de cor (a `DrawColor` da área).

> **Detalhe:** o `UNavModifierComponent` usa os limites de navegação dos componentes do ator. Certifique-se de que o volume da zona "pode afetar a navegação" (`SetCanEverAffectNavigation`) e de que a geração em runtime está no modo correto. Se a área não mudar, os dois primeiros suspeitos são esses.

### 4. Portas marcam o vão

🔁 O `AVGDoor` (Capítulo 19) ganha um `UNavModifierComponent` e um pequeno volume (`DoorwayVolume`, uma caixa cobrindo o vão, sem colisão de movimento) que define a região do modificador. Em `TransitionTo`:

```cpp
const bool bBlocksPresence = (NewState == EVGDoorState::Closed || NewState == EVGDoorState::Locked);
NavModifier->SetAreaClass(bBlocksPresence ? UVGNavArea_DoorClosed::StaticClass()
                                          : UNavArea_Default::StaticClass());
```

E a abertura automática para vigias: o `DoorwayVolume` tem overlap com pawns; ao detectar um pawn com a tag `Faction.Guard` e a porta em `Closed` (não `Locked`), a porta chama `TransitionTo(Opening)`.

### 5. O cérebro reage ao resultado do movimento

No `AVGAIController`, sobrescreva `OnMoveCompleted` e reencaminhe o resultado ao cérebro (o `UVGGuardBrainComponent`, por um delegate ou chamada direta — o controller e o cérebro do mesmo agente formam uma relação 1-para-1 estável, e a chamada direta é adequada, Capítulo 24):

```cpp
void AVGAIController::OnMoveCompleted(FAIRequestID RequestID, const FPathFollowingResult& Result)
{
    Super::OnMoveCompleted(RequestID, Result);
    OnAgentMoveCompleted.Broadcast(Result.IsSuccess()); // o cérebro escuta
}
```

E o estado `FInvestigate` (Capítulo 34) passa a trocar para `Search` quando o movimento termina — com sucesso **ou** não (chegou perto o bastante, ou não havia caminho).

---

## Projeto 5 — navegação no Galpão e na Casa de Força

1. **Agentes suportados:** dois agentes no projeto — `Humano` (raio 34, altura 176) e `Presenca` (raio 28, altura 210). Ajuste as cápsulas dos Blueprints para corresponder.
2. **Galpão:** NavMesh cobrindo o interior e o pátio dos fundos; portas com modificadores; vigias com RVO.
3. **Casa de Força (`L_CasaDeForca`, do Interlúdio I):** NavMesh nos dois níveis (térreo e subsolo), um **nav link** da escada metálica (se a navegação não conectar sozinha), e um **link só da Presença** descendo pelo poço das turbinas.
4. **A escuridão como mapa:** a zona segura do hall (sempre ativa) e as zonas dos setores (ativadas pelos disjuntores) marcam `Lit`. Mova a Presença de teste com um comando de cheat (`VGPresenceMoveTo` — o destino é o ponto para onde a câmera da jogadora aponta) e observe: ela nunca atravessa a luz nem portas fechadas.

---

## Decisões arquiteturais

1. **NavMesh com dois agentes** (humano e Presença), geração **Dynamic Modifiers Only**.
2. **Regras de design como áreas e filtros:** `Lit` e `DoorClosed`, excluídas pelo filtro da Presença.
3. **Zonas seguras, sinalizadores e portas marcam áreas** pelo mesmo mecanismo (`UNavModifierComponent`).
4. **Portas não esculpem a malha**; o vigia as atravessa com custo e elas se abrem para ele.
5. **`OnMoveCompleted` encaminhado ao cérebro**; caminhos parciais permitidos.
6. **Links para travessias especiais**, incluindo rotas exclusivas da Presença.
7. **RVO para vigias**; sem evitação para a Presença.

---

## Armadilhas

- **Depurar a decisão da IA quando o problema é a NavMesh** — olhe a malha primeiro.
- **Um agente só** para corpos muito diferentes.
- **Geração dinâmica completa** quando só áreas mudam.
- **Esquecer `CanEverAffectNavigation`** ou o modo de geração em runtime — o modificador "não funciona".
- **Regras de design escondidas no cérebro** (`if estáNaLuz`) em vez de no mapa.
- **Portas com colisão esculpindo a malha** em geração estática — a IA "atravessa" portas fechadas ou nunca passa por portas abertas.
- **`MoveTo` sem tratar falha** — o agente "trava" esperando um movimento que nunca termina.

---

## Exercício

**Parte 1 — NavMesh (1 h).** Gere a NavMesh do Galpão e da Casa de Força, com os dois agentes. Encontre e corrija três problemas visíveis (buracos, rampas não conectadas, vãos estreitos demais) usando a visualização.

**Parte 2 — áreas e filtros (1,5 h).** Implemente `UVGNavArea_Lit`, `UVGNavArea_DoorClosed`, `UVGNavFilter_Presence`, e os modificadores nas zonas seguras e nas portas. Configure o modo de geração em runtime. Verifique as cores das áreas mudando ao ativar zonas e ao abrir e fechar portas.

**Parte 3 — a Presença obedece (1 h).** Com o cheat de movimento, peça à Presença para ir até a jogadora dentro do hall iluminado. Ela deve parar na borda da luz (caminho parcial). Feche uma porta entre vocês: ela deve dar a volta ou parar.

**Parte 4 — o vigia abre portas (45 min).** Implemente a abertura automática para vigias e teste a investigação atravessando uma porta fechada.

---

## Desafio — o vigia que usa a interface

Substitua a abertura automática de portas por algo mais rico: quando o caminho do vigia passa por uma área `DoorClosed`, ele **para diante da porta** e a abre usando **a mesma interface da jogadora** (`IVGInteractable::Execute_Interact`, Capítulo 19), esperando a porta terminar de abrir antes de continuar.

Dicas: o `UPathFollowingComponent` permite inspecionar os pontos do caminho atual; um *smart link* na porta é outra abordagem. Pergunta para o `DEVLOG.md`: que vantagem de design há em a IA usar a mesma interface da jogadora? (Pense em portas trancadas, no prompt "Trancada" — e numa porta que a jogadora **trancou** para atrasar um vigia.)

---

## Uso de IA

1. **Para depurar navegação:**
   > "Na Unreal Engine 5, meu agente de IA não consegue chegar a um ponto que parece alcançável. Liste as causas possíveis ligadas à NavMesh (parâmetros do agente, agentes suportados, cell size, áreas e filtros, modificadores, geração em runtime, links, projeção do destino) e como verificar cada uma com as ferramentas de visualização."

2. **Para design com áreas:**
   > "Quero usar áreas de navegação e filtros na Unreal para expressar regras de design de um jogo de terror: a criatura não entra na luz, evita água, prefere corredores estreitos, não atravessa portas fechadas. Proponha as áreas, os custos e os filtros, e explique que comportamentos emergentes de pathfinding isso produziria."

3. **Para entender a geração:**
   > "Explique o pipeline do Recast (voxelização, filtragem por agente, regiões, contornos, polígonos) e o impacto de cell size, agent radius e max step height na qualidade da NavMesh, no tempo de geração e na memória."

---

## Checklist

- [ ] Sei explicar como a NavMesh é gerada a partir da geometria e por agente.
- [ ] Sei escolher o modo de geração em runtime.
- [ ] Sei mover agentes com `MoveTo`, tratar o resultado e usar caminhos parciais.
- [ ] Sei usar áreas, custos, modificadores e filtros por agente.
- [ ] A regra "a Presença não entra na luz nem atravessa portas fechadas" está na navegação.
- [ ] Sei usar nav links e conheço as opções de evitação.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation) — **Navigation System**, **Modifying the Navigation Mesh**, **Navigation Query Filters**, **Nav Link Proxy**, **Using Avoidance**.
- **Recast & Detour** (repositório público *recastnavigation*; biblioteca criada por Mikko Mononen) — a biblioteca de navegação usada pela Unreal, com documentação dos conceitos.
- **Ian Millington, *AI for Games*** — capítulos sobre pathfinding e representações do mundo para navegação.

---

➡️ **Próximo:** [Capítulo 36 — Perception](cap-36-perception.md)

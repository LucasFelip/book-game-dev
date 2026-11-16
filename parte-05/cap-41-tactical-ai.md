# Capítulo 41 — Tactical AI

## Objetivo

Ao final deste capítulo você deve conseguir:

- descrever o pipeline do **"Soldier AI"** — percepção → decisão → posição tática → navegação → ação — e onde cada conceito tático se encaixa;
- implementar **supressão** (atirar para prender o jogador em cobertura) e o efeito correspondente na jogadora (**near miss**);
- escolher posições de **flanco** e garantir **linha de tiro livre** (não atirar através de aliados);
- entender **mapas de influência** e como representar "perigo" no espaço;
- explicar **planejamento orientado a objetivos** (GOAP) e **redes de tarefas hierárquicas** (HTN), e implementar um planejador GOAP mínimo como laboratório;
- distinguir o que é **tática real** do que é **ilusão de tática** — e por que a segunda costuma valer mais.

---

## Contexto

Os vigias do Galpão já percebem com consciência gradual, decidem com uma Behavior Tree e intenções por utilidade, e escolhem cobertura com EQS. Eles **parecem** soldados — até o momento em que a jogadora se esconde atrás de uma caixa. Aí o vigia espera, atira quando ela aparece, e nada mais. Não tenta tirá-la de lá, não muda de ângulo, não aproveita que ela está presa.

**Tática** é o que transforma inimigos que reagem em inimigos que **pressionam**. É, também, o tema em que o pedido original citou os FPS de referência: como Battlefield, Call of Duty e outros shooters podem estruturar conceitualmente a IA de soldados. Este capítulo responde com conceitos e implementações pequenas — e com uma advertência: muito do que jogadores percebem como "IA tática" é **comunicação**, não cálculo.

---

## 41.1 O pipeline do soldado

```text
 PERCEPÇÃO          o que sei: onde a jogadora está/estava, se ela me vê, de onde vêm os tiros
 (Cap. 36)
     │
     ▼
 DECISÃO            o que quero: atacar, cobrir-me, suprimir, flanquear, recuar
 (Caps. 37, 40)
     │
     ▼
 POSIÇÃO TÁTICA     onde faço isso: o ponto de cobertura, o ângulo de flanco, o ponto de supressão
 (Cap. 39 + este)
     │
     ▼
 NAVEGAÇÃO          como chego: caminho, evitando a linha de tiro da jogadora
 (Cap. 35)
     │
     ▼
 AÇÃO               o que o corpo faz: mira, dispara, se agacha, grita "cobrindo!"
 (Caps. 20, 30)
```

**[SIMPLIFICAÇÃO DIDÁTICA]** Esta decomposição é uma forma útil de **pensar** a IA de soldados de qualquer shooter — Battlefield, Call of Duty ou outros —, não uma descrição de como esses jogos são implementados. Ela serve para localizar cada conceito tático deste capítulo: **supressão** é uma decisão com uma posição e uma ação; **flanco** é uma decisão cuja dificuldade está toda na posição; **linha de tiro livre** é uma condição para a ação; **perigo** é uma informação que afeta posição e navegação.

---

## 41.2 Supressão

**Supressão** é atirar **não para acertar**, mas para **impedir** o alvo de agir: enquanto as balas passam perto, quem está atrás da cobertura não se expõe. Em termos de design, ela cria uma dinâmica de dois tempos — um inimigo prende, outro avança — que é a base de quase toda "tática de esquadrão" percebida.

Duas metades:

1. **Do lado do inimigo — a intenção `Suppress`**: quando o alvo **não** está visível mas a última posição é recente e próxima (ela acabou de se esconder), o vigia atira **na borda da cobertura** ou na última posição conhecida, em rajadas, por alguns segundos. É uma nova intenção de utilidade (Capítulo 40), com considerações como "alvo não visível", "informação recente", "munição suficiente" e "há um aliado que poderia avançar" (Capítulo 42).
2. **Do lado da jogadora — ser suprimida**: balas que passam **perto** (sem acertar) aumentam um valor de **supressão**, que produz efeitos: vinheta escura, tremor de câmera leve, som abafado com zumbido, mira um pouco mais instável. O valor decai rapidamente sem novos *near misses*.

### Detectando quase-acertos

No hitscan (Capítulo 27), cada disparo é uma linha. Para saber se ela passou **perto** da cabeça da jogadora, calcula-se a **distância do ponto à reta** (o ponto mais próximo da linha de tiro até a câmera dela):

```text
                          ● cabeça da jogadora
                          ┊
                          ┊ d = distância à linha
   cano ●═════════════════╪═══════════════════════► linha do disparo
                    ponto mais próximo

   se d < raio de supressão (ex.: 150 cm) e o disparo NÃO a atingiu → near miss
```

Com álgebra vetorial simples (Capítulo 17): projeta-se o vetor (cabeça − origem) na direção do disparo, limita-se a projeção ao segmento, e mede-se a distância entre a cabeça e o ponto projetado. O componente de supressão da jogadora recebe a notificação e acumula.

---

## 41.3 Flanco e linha de tiro

### Flanco

Um **flanco** é uma posição que ataca o alvo **por um ângulo que a cobertura dele não protege**. Em termos de consulta espacial (Capítulo 39): pontos com **linha de visão** para a jogadora, a uma distância razoável, e com **ângulo grande** em relação à direção para onde ela está virada (ou à direção da cobertura dela):

```text
                       ▲ jogadora olhando para cá (cobertura à frente)
                       │
             ●         │         ●     ← pontos de flanco: ângulo ~70–110° da direção dela
                       ●  jogadora
                  ┌────┴────┐ cobertura
                  └─────────┘
                       ●  vigia (bloqueado pela cobertura)
```

A consulta `EQS_FlancoVigia` usa um teste de **Dot** entre a direção "jogadora → item" e a direção "jogadora → vigia atual" (ou a orientação da jogadora): itens perpendiculares pontuam mais. Mais um **Trace** exigindo linha de visão da jogadora até o item (de lá se acerta), e **Pathfinding** (dá para chegar).

O que um flanco convincente precisa, além do ponto: **chegar lá sem morrer**. Um caminho que atravessa a linha de tiro da jogadora é suicídio. A solução é tratar o **perigo** como dado espacial (seção 41.4): a consulta penaliza pontos sob a mira dela, e o trajeto passa por um ponto intermediário fora dessa mira.

### Linha de tiro livre

Um vigia não deve atirar através de um colega. Antes de disparar, um teste: o trace do cano até o alvo atinge um aliado? Se sim, a ação de disparo **não começa** e o vigia reposiciona (ou espera). Na Behavior Tree, um decorator `VG Has Clear Shot` no ramo de ataque — que, ao falhar, faz o selector cair para outra intenção.

---

## 41.4 Mapas de influência

Um **mapa de influência** é uma grade (ou um conjunto de pontos) sobre o nível em que cada célula guarda um valor que **se propaga e decai**: "perigo" onde a jogadora tem atirado, "controle" de cada facção, "frequência de passagem" da jogadora. Agentes consultam o mapa para escolher posições e caminhos.

```text
  perigo (onde a jogadora atirou nos últimos segundos)
  ░░░░░░░░░░░░░░░░░░░░
  ░░░░▒▒▒▒▒░░░░░░░░░░░       ░ baixo   ▒ médio   ▓ alto
  ░░▒▒▓▓▓▓▓▒▒░░░░░░░░░
  ░░▒▓▓█ J █▓▒▒▒▒▒░░░░       J = jogadora; o "cone" de perigo segue a mira dela
  ░░▒▒▓▓▓▓▓▒▒░░░░░░░░░
  ░░░░▒▒▒▒▒░░░░░░░░░░░
```

Na Vigília, um mapa de influência completo seria excessivo. A versão mínima usa uma ferramenta que já existe:

- **Perigo como teste de EQS:** um teste que penaliza itens dentro do cone de mira da jogadora (Dot + distância), usado nas consultas de cobertura e flanco. Para o **caminho** do flanco, o mesmo teste escolhe antes um **ponto intermediário** fora do cone: o vigia vai até ele e só então ao ponto de flanco — contorna a mira em duas pernas, sem mexer na navegação.

> ⚠️ **A tentação: perigo como área de navegação.** Parece elegante anexar à jogadora um modificador de navegação (Capítulo 35) marcando uma área `Danger` à frente dela. Não funciona bem: o modificador descreve caixas, não um cone, e um modificador que se **move com a jogadora** suja os tiles da NavMesh a cada frame — em *Dynamic Modifiers Only*, isso é regeneração contínua. Modificadores são para regras que mudam **raramente** (portas, zonas que acendem). Custo de caminho que muda a cada frame exigiria um filtro de consulta customizado de baixo nível — fora do escopo deste livro.

---

## 41.5 Planejamento: GOAP e HTN

Behavior Trees, FSMs e Utility **escolhem** entre comportamentos que o designer escreveu. **Planejadores** **montam** o comportamento: dado um **objetivo** ("o alvo está morto") e um conjunto de **ações** com **pré-condições** e **efeitos**, o agente **busca** uma sequência de ações que leva do estado atual ao objetivo.

### GOAP

**[FATO PÚBLICO]** O **GOAP** (*Goal-Oriented Action Planning*) foi apresentado à indústria de jogos por Jeff Orkin, da Monolith Productions, num artigo do *AI Game Programming Wisdom 2* (2003), e ficou famoso com a IA de *F.E.A.R.* (Monolith, 2005); a palestra *Three States and a Plan: The A.I. of F.E.A.R.* (GDC 2006) descreve uma arquitetura em que uma máquina de estados muito pequena executa **planos** produzidos por um planejador sobre ações com pré-condições e efeitos. Os soldados de F.E.A.R. ficaram conhecidos por usar cobertura, flanquear e se comunicar com falas, e Orkin contou no artigo da palestra que o jogo não tinha comportamentos complexos de esquadrão: o "flanco" podia emergir de soldados que só iam para uma cobertura válida, e as **falas** entre eles ("granada!", "não tenho para onde ir!") avisavam ao jogador que a coordenação era intencional.

O modelo:

```text
 ESTADO DO MUNDO (fatos booleanos):  ArmaNaMão=F, ArmaCarregada=F, NaCobertura=F, AlvoMorto=F
 OBJETIVO:                          AlvoMorto=V

 AÇÕES                pré-condições                         efeitos
 SacarArma            —                                     ArmaNaMão=V
 Recarregar           ArmaNaMão=V                           ArmaCarregada=V
 IrParaCobertura      —                                     NaCobertura=V
 Atirar               ArmaNaMão=V, ArmaCarregada=V          AlvoMorto=V
 AtirarDaCobertura    ArmaNaMão=V, ArmaCarregada=V,         AlvoMorto=V   (custo menor: mais seguro)
                      NaCobertura=V

 PLANO (busca A* no espaço de estados, minimizando custo):
   SacarArma → Recarregar → IrParaCobertura → AtirarDaCobertura
```

Vantagens: comportamento **emergente** e adaptável — se a arma já está carregada, o plano pula a recarga; se não há cobertura, o planejador encontra outro caminho. Custos: a busca tem custo de CPU; o comportamento é **menos previsível** para designers; e é difícil **autorar** momentos específicos ("neste encontro, o vigia deve gritar e correr para a porta").

### HTN

**Redes de tarefas hierárquicas** (*Hierarchical Task Networks*) planejam de outra forma: em vez de buscar ações livremente, **decompõem** tarefas de alto nível ("atacar o alvo") em subtarefas segundo **métodos** escritos pelo designer ("se há cobertura: ir para a cobertura, depois atirar; senão: atirar andando"). É mais controlável que o GOAP — o designer escreve as decomposições — e mais flexível que uma árvore fixa. **[FATO PÚBLICO — confira as fontes]** Há usos documentados de planejadores HTN: os bots multiplayer de *Killzone 2* (Guerrilla), apresentados em conferência de Game AI em 2009, e *Transformers: Fall of Cybertron* (High Moon), descrito por Troy Humphreys no *Game AI Pro* ("Exploring HTN Planners through Example").

### E na Vigília?

A Vigília **não** usa planejadores: seus agentes são poucos, os comportamentos são autorados, e previsibilidade para o design (principalmente para a Presença e o pacing) vale mais que emergência. Mas entender GOAP muda o modo de pensar ações — **pré-condições e efeitos** são uma forma excelente de documentar as tasks de uma Behavior Tree. A seção de implementação traz um planejador GOAP mínimo como **laboratório**.

---

## Estudo de caso: tática percebida em shooters

> **Pergunta:** quanto da "inteligência tática" que jogadores percebem em soldados de shooters é cálculo, e quanto é comunicação?

**[FATO PÚBLICO]** Além do caso de F.E.A.R. citado na seção 41.5, é comum em shooters — inclusive em campanhas como as da série Call of Duty e da série Battlefield — que inimigos e aliados **gritem** o que estão fazendo ou vendo: avisos de granada, de recarga, de posição do jogador. Esses *barks* (falas curtas contextuais) são um elemento sonoro característico do gênero.

**[INFERÊNCIA]** As falas têm um efeito multiplicador sobre a IA: elas **tornam visíveis** decisões que, sem elas, passariam despercebidas. Um vigia que se move para a esquerda é só um vigia que se moveu; um vigia que grita "vou pela esquerda!" e se move para a esquerda é um soldado **flanqueando** — e o jogador passa a olhar para a esquerda, o que transforma o movimento numa ameaça **legível**. Do mesmo modo, um "recarregando!" é ao mesmo tempo realismo e **informação de jogo**: uma janela de oportunidade anunciada. Na arquitetura deste livro, cada fala é a **apresentação** de uma transição de intenção (Capítulo 40) ou de uma ação (Capítulo 37).

**[SIMPLIFICAÇÃO DIDÁTICA]** Os vigias da Vigília recebem um pequeno sistema de *barks*: ao trocar de intenção (`Suppress`, `Flank`, `TakeCover`, `Reload`) ou ao perceber a jogadora, o corpo toca uma fala curta (placeholder: texto na legenda + som), com um intervalo mínimo por vigia e por tipo, para não repetir. O Capítulo 42 coordena para que dois vigias não gritem ao mesmo tempo.

**Lição:** **antes de calcular mais, comunique melhor.** Uma decisão tática que o jogador percebe vale mais que três que ele não percebe. E comunicar também é design de dificuldade: anunciar o flanco dá ao jogador a chance de reagir.

---

## Comparação com o desenvolvimento tradicional

| Tática | O que você conhece | Onde a analogia cai |
|---|---|---|
| Pipeline do soldado | Pipeline de processamento em estágios | Cada estágio é perceptível e precisa ser legível |
| Supressão | Backpressure / rate limiting aplicado a um cliente | O "cliente" é o jogador, e a pressão é emocional |
| Mapas de influência | Mapas de calor / campos de potencial | Atualizados em tempo real a partir do comportamento do jogador |
| GOAP | Planejamento automático, busca no espaço de estados (STRIPS) | Precisa caber no frame e produzir comportamento legível |
| HTN | Decomposição de workflows por métodos | Os "métodos" são design autoral |
| Barks | Logs/telemetria legíveis por humanos | O "leitor" é o adversário — e a fala muda o jogo |

> 🌉 **Ponte:** GOAP é uma aplicação do planejamento clássico tipo **STRIPS** (estados como conjuntos de fatos, ações com pré-condições e efeitos) com busca **A*** — conteúdo que você provavelmente viu na graduação. A novidade em jogos é a escala de tempo: o plano é refeito em milissegundos sempre que o mundo muda.

---

## Implementação

### 1. Supressão: o lado da jogadora

```cpp
// Source/Vigilia/Player/VGSuppressionComponent.h (essencial)
/**
 * Supressão da jogadora: quase-acertos aumentam o valor; decai rápido sem novos.
 * Efeitos (vinheta, som abafado, instabilidade da mira) leem GetSuppression() — contínuo → consulta.
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGSuppressionComponent : public UActorComponent
{
    GENERATED_BODY()
public:
    UVGSuppressionComponent();
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    /** Chamado por quem dispara quando uma linha de tiro passa perto e não acerta. */
    void ReportNearMiss(float Closeness); // 0 = no limite do raio, 1 = raspou

    UFUNCTION(BlueprintPure, Category = "Vigilia|Suppression")
    float GetSuppression() const { return Suppression; }

protected:
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Suppression") float GainPerNearMiss = 0.25f;
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Suppression") float DecayPerSecond = 0.6f;

private:
    float Suppression = 0.0f;
};
```

A implementação acumula (com teto 1), liga o tick ao receber um quase-acerto e o desliga quando o valor volta a zero. Uma tag de status `Status.Suppressed` (Capítulo 23) é concedida acima de 0,5 e revogada abaixo de 0,3 (histerese) — e a IA pode **consultá-la** pela consciência: "a jogadora está suprimida" é uma consideração da intenção `Flank` (Capítulo 42).

### 2. Detectando o quase-acerto no disparo

No `AVGWeapon::FirePellet` (Capítulo 27), depois de resolver o trace:

```cpp
// Quase-acerto: a linha de tiro passou perto da cabeça de algum jogador e não o atingiu.
if (const APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0); Player && Player != GetInstigator())
{
    FVector EyeLocation;
    FRotator EyeRotation;
    Player->GetActorEyesViewPoint(EyeLocation, EyeRotation);

    const FVector ClosestOnShot = FMath::ClosestPointOnSegment(EyeLocation, ViewLocation, LastImpact);
    const float Distance = FVector::Dist(ClosestOnShot, EyeLocation);
    const bool bHitPlayer = (LastHitActor == Player);

    if (!bHitPlayer && Distance < Data->SuppressionRadius)
    {
        if (UVGSuppressionComponent* Suppression = Player->FindComponentByClass<UVGSuppressionComponent>())
        {
            Suppression->ReportNearMiss(1.0f - Distance / Data->SuppressionRadius);
        }
    }
}
```

`FMath::ClosestPointOnSegment` faz a projeção da seção 41.2. A arma não sabe o que é "supressão" além de avisar o componente; o efeito na tela é do componente (e do Blueprint da jogadora). (Simplificação: só a jogadora local é considerada; em multiplayer, o teste se estende a todos os pawns de jogadores — Parte IX.)

### 3. A intenção de suprimir

Nova intenção no service de utilidade do vigia (Capítulo 40): **`Suppress`**, com considerações `TargetVisible` (inversa: não visível → alto), `LastKnownRecency` (nova entrada: quão recente é a informação — recente → alto), `AmmoRatio` (crescente) e `AlliesNearby` (Capítulo 42). O ramo correspondente na árvore:

```text
[CombatIntent == Suppress — abort Both]
  SEQUENCE
    ├─ Set Focal Point (LastKnownLocation + ruído aleatório de ~50 cm)   ← mira na borda da cobertura
    ├─ VG Bark (Suppressing)
    └─ VG Fire Burst (1,5 s, dispersão extra alta)
```

### 4. Linha de tiro livre e flanco

- **`UBTDecorator_VGHasClearShot`**: `CalculateRawConditionValue` faz um trace do cano (ou dos olhos) do vigia até o alvo e falha se o primeiro ator atingido tiver a tag `Faction.Guard`. Anexado ao ramo de ataque e ao de supressão.
- **`EQS_FlancoVigia`**: gerador *Pathing Grid* ao redor do **alvo** (8–14 m); testes: Trace do alvo até o item (filtro: **visível** — precisa ter linha de tiro), Dot entre (alvo → item) e (alvo → vigia) (pontuação: perto de 0 é melhor — perpendicular), Distance até o vigia (pontuação: não longe demais), e o teste de perigo (cone de mira da jogadora — penalidade).
- **Intenção `Flank`** no service: considerações `TargetSuppressed` (a jogadora está suprimida — por outro vigia), `HealthRatio`, `HasFlankPoint`. Ramo: `Run EQS (Flank) → VG Bark (Flanking) → Run EQS (ponto intermediário fora do cone de mira) → Move To → Move To (FlankLocation)`.
- **Entradas novas de utilidade:** `LastKnownRecency`, `AlliesNearby`, `TargetSuppressed` e `HasFlankPoint` entram no `EVGUtilityInput` **antes de `Count`** (o contexto cresce sozinho — Capítulo 40), são preenchidas no `BuildContext`, e o `static_assert` dele passa a `NumInputs == 11`.

### 5. Laboratório: um planejador GOAP mínimo

Fora da Unreal, em C++ padrão, para entender planejamento com as próprias mãos:

```cpp
// goap_lab.cpp — g++ -std=c++20 -O2 goap_lab.cpp -o goap_lab
#include <cstdint>
#include <cstdio>
#include <queue>
#include <string>
#include <unordered_map>
#include <vector>

using WorldState = uint32_t; // cada bit é um fato booleano

enum Fact : WorldState
{
    WeaponDrawn  = 1u << 0,
    WeaponLoaded = 1u << 1,
    InCover      = 1u << 2,
    TargetDead   = 1u << 3,
};

struct Action
{
    std::string Name;
    WorldState Preconditions; // fatos que precisam ser verdadeiros
    WorldState Effects;       // fatos que passam a ser verdadeiros
    float Cost;
};

struct Node
{
    WorldState State;
    float Cost;
    bool operator>(const Node& Other) const { return Cost > Other.Cost; }
};

// Busca de custo uniforme (A* com heurística zero) no espaço de estados.
std::vector<std::string> Plan(WorldState Start, WorldState Goal, const std::vector<Action>& Actions)
{
    std::priority_queue<Node, std::vector<Node>, std::greater<Node>> Open;
    std::unordered_map<WorldState, float> BestCost;
    std::unordered_map<WorldState, std::pair<WorldState, const Action*>> CameFrom;

    Open.push({ Start, 0.0f });
    BestCost[Start] = 0.0f;

    while (!Open.empty())
    {
        const Node Current = Open.top();
        Open.pop();
        if ((Current.State & Goal) == Goal)
        {
            std::vector<std::string> Steps;
            for (WorldState S = Current.State; S != Start; S = CameFrom[S].first)
            {
                Steps.insert(Steps.begin(), CameFrom[S].second->Name);
            }
            return Steps;
        }
        if (Current.Cost > BestCost[Current.State]) { continue; } // entrada obsoleta na fila

        for (const Action& A : Actions)
        {
            if ((Current.State & A.Preconditions) != A.Preconditions) { continue; }
            const WorldState Next = Current.State | A.Effects;
            const float NewCost = Current.Cost + A.Cost;
            const auto It = BestCost.find(Next);
            if (It == BestCost.end() || NewCost < It->second)
            {
                BestCost[Next] = NewCost;
                CameFrom[Next] = { Current.State, &A };
                Open.push({ Next, NewCost });
            }
        }
    }
    return {}; // sem plano
}

int main()
{
    const std::vector<Action> Actions = {
        { "SacarArma",         0,                                   WeaponDrawn,  1.0f },
        { "Recarregar",        WeaponDrawn,                         WeaponLoaded, 2.0f },
        { "IrParaCobertura",   0,                                   InCover,      3.0f },
        { "Atirar",            WeaponDrawn | WeaponLoaded,          TargetDead,   6.0f }, // exposto: caro
        { "AtirarDaCobertura", WeaponDrawn | WeaponLoaded | InCover, TargetDead,  1.0f },
    };

    auto Print = [&](const char* Label, WorldState Start)
    {
        std::printf("%s:", Label);
        for (const std::string& Step : Plan(Start, TargetDead, Actions)) { std::printf(" -> %s", Step.c_str()); }
        std::printf("\n");
    };

    Print("Desarmado, fora da cobertura", 0);
    Print("Armado e carregado          ", WeaponDrawn | WeaponLoaded);
    Print("Ja na cobertura, descarregado", WeaponDrawn | InCover);
    return 0;
}
```

Rode e observe: o mesmo conjunto de ações produz **planos diferentes** conforme o estado inicial — e o planejador escolhe a cobertura quando o custo total compensa. Mude o custo de `Atirar` de 6 para 3 e veja o plano mudar. Esse é o comportamento emergente que o GOAP oferece — e a imprevisibilidade que um designer precisa aceitar.

---

## Projeto 5 — táticas no Galpão

1. **Supressão nos dois lados:** os vigias suprimem quando a jogadora se esconde; a jogadora sente (vinheta, som, mira instável).
2. **Flanco:** com dois ou mais vigias, quando a jogadora está suprimida, um deles busca um flanco (o Capítulo 42 garante que só um faça isso).
3. **Linha de tiro livre:** vigias não atiram através de colegas.
4. **Perigo:** o teste de perigo (cone de mira da jogadora) faz os vigias escolherem pontos e trajetos que contornam a mira dela ao se reposicionar.
5. **Barks:** falas contextuais em transições de intenção, com intervalo mínimo.
6. Rode o **laboratório GOAP** e escreva no `DEVLOG.md` três situações em que um planejador produziria um comportamento melhor que a BT do vigia, e três em que a BT é melhor.

---

## Decisões arquiteturais

1. **Pipeline do soldado como mapa conceitual**; cada tática localizada numa etapa.
2. **Supressão nos dois lados**: intenção de suprimir no vigia; componente de supressão na jogadora, alimentado por quase-acertos detectados no disparo.
3. **Flanco por EQS** (ângulo + linha de tiro + perigo); **linha de tiro livre** por decorator.
4. **Perigo como teste de EQS** (pontos e ponto intermediário de trajeto), não como modificador de navegação móvel — mapas de influência só na versão mínima.
5. **Sem planejadores na Vigília** (previsibilidade de design); GOAP como laboratório.
6. **Barks como apresentação de intenções**, com intervalos mínimos.

---

## Armadilhas

- **Tática invisível** — flancos que ninguém percebe, supressão sem efeito na jogadora.
- **Inimigos que atiram através de aliados.**
- **Caminhos de flanco pela linha de tiro da jogadora.**
- **Todos os vigias fazendo a mesma tática ao mesmo tempo** (coordenação — Capítulo 42).
- **Barks repetitivos** ou sobrepostos.
- **Planejadores onde o design precisa de controle autoral.**
- **Supressão que pune demais** — a jogadora nunca consegue sair da cobertura.

---

## Exercício

**Parte 1 — supressão (2 h).** Implemente o componente de supressão, a detecção de quase-acertos e a intenção `Suppress`. Ajuste até que ficar atrás da caixa enquanto o vigia suprime seja tenso, mas sair seja possível nas pausas entre rajadas.

**Parte 2 — flanco e linha de tiro (2 h).** Implemente o decorator de linha de tiro livre, a consulta de flanco e a intenção `Flank`. Teste com três vigias.

**Parte 3 — barks (45 min).** Implemente falas contextuais com intervalo mínimo por vigia. Jogue com e sem as falas e descreva a diferença na percepção de inteligência.

**Parte 4 — GOAP (1 h).** Compile e rode o laboratório. Acrescente as ações `JogarGranada` (pré-condição: tem granada; efeito: alvo sai da cobertura) e `AtirarNoExposto`, e um fato `AlvoNaCobertura`. Que planos surgem?

---

## Desafio — um encontro tático de dois tempos

Projete e implemente, no fim do Galpão, um encontro com **três vigias** que execute, de forma sistêmica (sem roteiro), o padrão "**um prende, outro avança**":

1. Quando a jogadora entra em cobertura, um vigia suprime.
2. Enquanto ela está suprimida, outro flanqueia.
3. O terceiro mantém posição e cobre a rota de fuga dela.

Use apenas os sistemas do capítulo (intenções de utilidade, EQS, barks) e o que o Capítulo 42 vai formalizar (por enquanto, use a chave sincronizada `SquadAlertLocation` do Capítulo 38 e uma regra simples: "se alguém já está suprimindo, não suprima"). Pergunta para o `DEVLOG.md`: o comportamento emergiu como você queria? Em que momentos ele "quebrou"? O que faltou para que os três se coordenassem de verdade?

---

## Uso de IA

1. **Para desenhar táticas:**
   > "Para inimigos humanos num shooter em primeira pessoa com poucos agentes (2–4), proponha cinco táticas (supressão, flanco, cobrir a retirada, avançar em pares, forçar com granada), e para cada uma descreva: a decisão (quando), a posição tática (onde, como consulta espacial), a ação (o que o corpo faz), a comunicação ao jogador (barks, animação) e como evitar que seja injusta."

2. **Para entender GOAP:**
   > "Explique GOAP (Goal-Oriented Action Planning) como aplicado em jogos: estado do mundo como fatos, ações com pré-condições, efeitos e custos, busca A* no espaço de estados, replanejamento. Compare com HTN e com Behavior Trees em controle autoral, emergência, custo de CPU e depuração. Indique o que é documentado publicamente sobre o uso em F.E.A.R."

3. **Para a matemática do quase-acerto:**
   > "Mostre como calcular a menor distância entre um ponto (a cabeça do jogador) e um segmento de reta (a linha de um disparo hitscan, da origem ao ponto de impacto), e como usar isso para detectar quase-acertos em C++ na Unreal (FMath::ClosestPointOnSegment). Discuta casos de borda (disparo que para antes do jogador, disparo que passa atrás dele)."

---

## Checklist

- [ ] Sei localizar cada conceito tático no pipeline do soldado.
- [ ] Implementei supressão no inimigo e o efeito de supressão na jogadora por quase-acertos.
- [ ] Implementei flanco por EQS e linha de tiro livre por decorator.
- [ ] Sei o que são mapas de influência e implementei a versão mínima de perigo.
- [ ] Sei explicar GOAP e HTN e rodei o laboratório de planejamento.
- [ ] Implementei barks e entendo o papel deles na percepção de tática.

---

## Para ir além

- **Jeff Orkin, *Three States and a Plan: The A.I. of F.E.A.R.*** (GDC 2006) — artigo e palestra sobre GOAP em F.E.A.R. (disponíveis publicamente).
- **Ian Millington, *AI for Games*** — capítulos sobre IA tática e estratégica (pontos táticos, mapas de influência) e sobre planejamento.
- **Steve Rabin (org.), *Game AI Pro*** — capítulos sobre seleção de posições táticas, HTN em jogos e mapas de influência.

---

➡️ **Próximo:** [Capítulo 42 — Squad AI](cap-42-squad-ai.md)

# Capítulo 21 — Combat

## Objetivo

Ao final deste capítulo você deve conseguir:

- tratar combate como um **sistema de design** com loop, métricas e estéticas próprias, e não como "atirar até o inimigo cair";
- calcular e usar as métricas fundamentais: **TTK** (tempo para matar), **TTD** (tempo para morrer), **DPS** efetivo, disparos para abater e distância de engajamento;
- projetar **telegrafia** e **legibilidade** — o que torna um ataque justo — a partir do tempo de reação humano;
- pensar em **economia de recursos**, risco e recompensa, e em como ela muda entre um shooter e um jogo de terror;
- comparar três respostas de design para "o jogador pode lutar?" (Amnesia, Outlast, Alan Wake) e posicionar a Vigília;
- construir um **simulador de combate** para prever TTK antes do playtest, e escrever o documento de combate da Vigília.

---

## Contexto

O Capítulo 20 construiu o *mecanismo* de uma arma: cadência, munição, recarga, disparo. Nenhuma linha daquele código diz se o combate é **bom**. Uma pistola que causa 25 de dano a 400 RPM contra um inimigo de 100 de vida pode produzir um combate tenso, entediante ou frustrante — dependendo de quantos inimigos há, de quão rápido eles atacam, de quanto o jogador erra, de quanta munição existe e de quanto tempo ele tem para reagir.

Este capítulo é o equivalente, para o combate, do que o Capítulo 5 foi para o gameplay em geral: um capítulo de **design**, com engenharia a serviço dele. Você vai sair dele com números para pensar e uma ferramenta para calculá-los — e com uma decisão de design importante para a Vigília: **o que significa lutar num jogo sobre vulnerabilidade**.

---

## 21.1 O loop de combate

Em qualquer jogo com combate, um encontro se decompõe num loop:

```text
   PERCEBER ──► POSICIONAR ──► ENGAJAR ──► RESOLVER ──► RECUPERAR
   "há uma      "onde fico?     "atiro,     "abati /      "recarrego,
    ameaça"      cobertura,      esquivo,    fui ferido /  me curo,
                 distância,      uso          fugi"         reavalio"
                 rota de fuga"   recurso"
       ▲                                                     │
       └─────────────────── próximo encontro ◄───────────────┘
```

Cada etapa tem sistemas e decisões próprias:

| Etapa | Sistemas | Pergunta de design |
|---|---|---|
| Perceber | Áudio (Cap. 52), luz (51), IA anunciando presença (36), HUD | O jogador percebe a ameaça a tempo de reagir? |
| Posicionar | Level design (50), movimento (17, 25), cobertura | Há escolhas espaciais reais? |
| Engajar | Armas (20, 26–29), IA (33–42), feedback | O engajamento exige habilidade e decisões? |
| Resolver | Dano e vida (22), reação do inimigo (30) | O resultado é legível? O jogador entende por que ganhou/perdeu? |
| Recuperar | Recursos, recarga, regeneração, zonas seguras | Há um vale de tensão (Cap. 5, pacing) antes do próximo pico? |

O erro mais comum de quem começa é investir quase tudo em **engajar** (a arma, o tiro) e quase nada em **perceber**, **posicionar** e **recuperar**. Um combate em que o inimigo surge sem aviso, num espaço sem escolhas, e é seguido imediatamente de outro, é ruim mesmo com a melhor arma do mundo.

---

## 21.2 As métricas do combate

### Dano por segundo e disparos para abater

Para uma arma:

```text
DPS teórico      = dano por disparo × disparos por segundo
                 = Dano × RPM / 60

Disparos p/ abater (STK) = ⌈ vida do alvo / dano por disparo ⌉
```

Com a pistola do Galpão (25 de dano, 400 RPM) contra um alvo de 100 de vida: DPS teórico ≈ 167; STK = 4.

### Tempo para matar (TTK)

O **TTK** (*time to kill*) é o tempo entre o primeiro disparo e o abate. Com precisão perfeita:

```text
TTK ideal = (STK − 1) × intervalo entre disparos
```

O primeiro disparo é no instante zero; os outros vêm a cada intervalo. Pistola: (4 − 1) × 0,15 s = **0,45 s**.

Mas jogadores **erram**. Com uma taxa de acerto `p`, o número de disparos necessários passa a ser aleatório (em média, STK / p), e o TTK real cresce — e, se o pente acabar, inclui uma **recarga**. É por isso que o TTK "real" precisa de simulação (seção de implementação), e não só de uma fórmula.

### Tempo para morrer (TTD)

O espelho do TTK: quanto tempo o **jogador** sobrevive sob fogo de um inimigo (ou de vários). A relação entre os dois define a natureza do combate:

```text
TTK << TTD    → o jogador domina; combate de "poder" (muitos inimigos, power fantasy)
TTK ≈ TTD     → duelos; quem acerta primeiro e melhor vence (FPS competitivo)
TTK >> TTD    → o jogador é frágil; lutar é arriscado; fugir é melhor (terror)
```

> **[FATO PÚBLICO]** Em comunidades de FPS multiplayer, o TTK é uma das métricas mais discutidas: mudanças de TTK entre edições de uma série, ou em atualizações de balanceamento, costumam gerar debates intensos entre jogadores, porque alteram a natureza do jogo (TTK baixo favorece quem vê e reage primeiro; TTK alto favorece quem rastreia o alvo com precisão por mais tempo e dá mais tempo de reação a quem é atingido).

### Tempo de reação e telegrafia

O tempo de reação humano a um estímulo visual simples fica, como regra prática, na faixa de **um quarto de segundo** — e é maior quando o estímulo exige **decisão** (identificar a ameaça, escolher entre fugir e atirar) e quando o jogador está dividindo a atenção. Isso dá uma régua para **justiça**:

> **Se um ataque inimigo vai causar dano significativo, ele precisa ser anunciado com antecedência maior que o tempo de reação + o tempo da resposta esperada.**

Esse anúncio é a **telegrafia** (*telegraphing*): uma animação de preparo, um som característico, uma luz que muda, uma câmera que se ajusta. Um ataque sem telegrafia, ou com telegrafia mais curta que o tempo de reação, é percebido como **injusto** — o jogador não sente que perdeu por erro próprio.

```text
 tempo ──────────────────────────────────────────────────────────►
        │◄──── telegrafia (≥ reação + resposta) ────►│
        [sinal: som/anim.]                           [ataque]
        │◄─ reação ~0,25 s ─►│◄─ esquiva/fuga ─►│
                              o jogador consegue responder ✓
```

Em terror, a telegrafia também é **instrumento de tensão**: o som de algo se aproximando, antes de qualquer imagem, é ao mesmo tempo justo (o jogador pode agir) e aterrorizante (o jogador **sabe**).

---

## 21.3 Economia, risco e recompensa

Todo recurso de combate — munição, vida, cura, bateria, tempo — é uma **economia**: entra (pickups, regeneração), sai (uso, dano), e o saldo cria pressão.

| Jogo (referência) | Munição | Efeito na estética |
|---|---|---|
| FPS de ação (ex.: campanha de COD) | Abundante; reposta com frequência | Poder, ritmo, foco em habilidade de mira |
| Terror com combate (ex.: Alan Wake) | Limitada e encontrada; o recurso principal (luz) também é escasso | Tensão: cada encontro custa algo |
| Terror sem combate (ex.: Outlast, Amnesia) | Não há; o recurso escasso é outro (bateria, luz) | Vulnerabilidade: o jogador evita, não enfrenta |

A pergunta de design de cada encontro é: **o que o jogador arrisca, e o que ganha?** Um encontro em que lutar é sempre a melhor opção não tem decisão. Um encontro em que fugir custa nada não tem tensão. O meio-termo interessante é quando **as duas opções custam algo diferente**: lutar gasta cartuchos que podem faltar depois; fugir faz barulho e leva para áreas desconhecidas.

---

## Estudo de caso: três respostas para "o jogador pode lutar?"

> **Pergunta:** como jogos de terror decidem se — e como — o jogador pode lutar, e o que cada decisão produz?

### Os fatos

**[FATO PÚBLICO]**
- Em *Amnesia: The Dark Descent* (Frictional Games, 2010), o jogador **não tem armas** e não pode combater os monstros; a resposta à ameaça é evitar, esconder-se e fugir. A escuridão afeta a **sanidade** do personagem, e olhar para os monstros também tem consequências — o que torna o simples ato de observar a ameaça arriscado.
- Em *Outlast* (Red Barrels, 2013), o jogador também **não tem combate**: foge, esconde-se em armários e sob camas, e depende da visão noturna da câmera, limitada por baterias (Capítulo 18).
- Em *Alan Wake* (Remedy, 2010), o jogador **combate**, mas com uma regra de duas etapas — luz para remover a proteção de escuridão, arma para ferir — e com recursos escassos (baterias, munição, sinalizadores) (Capítulo 1).

### A análise

```text
                 SEM COMBATE                         COMBATE LIMITADO
         Amnesia            Outlast                     Alan Wake
         ───────            ───────                     ─────────
 Ameaça  invencível         invencível                  vencível, com custo
 Verbos  esconder, fugir,   correr, esconder,           iluminar, atirar,
         evitar olhar       filmar no escuro            esquivar, fugir para a luz
 Recurso luz, sanidade      bateria da câmera           luz, munição, sinalizadores
 Estética vulnerabilidade   pânico, perseguição         tensão + catarse
         psicológica
 Risco   tédio/frustração   repetição de padrões        combate virar rotina
         se a ameaça for    de fuga                     (perder o medo)
         previsível
```

**[INFERÊNCIA]** Os três jogos ilustram um trade-off central: **cada verbo de combate que o jogador ganha reduz a vulnerabilidade**. Dar uma arma ao jogador transfere poder para ele e, com o tempo, transforma o inimigo de "terror" em "problema a resolver". Jogos sem combate preservam o medo, mas precisam de outros sistemas — IA de perseguição convincente, level design de esconderijos, pacing cuidadoso — para não virar frustração ou rotina. Jogos com combate limitado preservam a tensão através da **escassez** e de **regras que tornam o combate trabalhoso**, mas correm o risco de o combate virar rotina se os recursos forem generosos demais.

### A decisão da Vigília

A Vigília fica entre Outlast e Alan Wake, com uma decisão específica:

> **A Presença não pode ser morta. O sinalizador não é uma arma para vencê-la: é uma ferramenta para afastá-la.**

Mecanicamente:

- Um disparo de sinalizador que atinge a Presença (ou explode perto dela) a **repele**: ela recua para fora da luz e fica **atordoada** por alguns segundos, perdendo o rastro da jogadora.
- O sinalizador tem **poucos cartuchos** (máximo de 4, raros pelo mapa) e uma **recarga lenta** (Capítulo 20).
- A luz do sinalizador também é **luz**: ela cria por alguns segundos uma zona segura temporária, coerente com a regra "a Presença não entra na luz" (pilar da Introdução).
- Os **Vigias** (Parte V) — inimigos humanos, armados — podem ser derrotados, mas aparecem em um único trecho, como contraste: um momento em que a jogadora pode reagir com violência, e descobre que isso também tem custo.

A estética-alvo: o combate com a Presença é **uma fuga com uma carta na manga**, não uma luta. Cada cartucho gasto é uma decisão de vida ou morte, e a jogadora nunca se sente segura por ter um.

---

## 21.4 Feedback de combate

O Capítulo 5 desmontou um tiro em camadas de feedback. No combate, três delas são críticas:

- **Confirmação de acerto.** O jogador precisa saber, em menos de 100 ms, se acertou: hit marker, som de impacto no corpo, reação do inimigo. Sem isso, o jogador não consegue corrigir a mira — o micro-loop quebra.
- **Confirmação de efeito.** Acertar e **causar efeito** são coisas diferentes: um inimigo com armadura, uma Presença que só reage à luz. Comunicar a diferença ("acertei, mas não fez efeito") é essencial para que o jogador entenda a regra — Alan Wake faz isso tornando visível a escuridão que envolve o inimigo e mostrando-a se dissipar sob a luz (**[FATO PÚBLICO]**, observável jogando).
- **Estado do jogador.** Quanto dano levei, de onde veio, quanto falta. Em jogos imersivos, isso costuma ser comunicado **sem números**: vinheta vermelha, respiração, som abafado, indicador direcional de dano (Capítulo 55).

Na Vigília, a Presença **não tem barra de vida**. O feedback do sinalizador é o **recuo** dela (animação, grito, a luz no corpo) e o silêncio que se segue. Isso é uma decisão de UI derivada da decisão de design: não se mostra a vida de algo que não pode morrer.

---

## 21.5 Dificuldade

Dificuldade é a combinação de três alavancas:

1. **Números** — vida, dano, munição, TTK, TTD.
2. **Comportamento** — agressividade, precisão e reação da IA (Parte V), telegrafia mais curta ou mais longa.
3. **Recursos e espaço** — quantos pickups, onde, quantas rotas de fuga e esconderijos.

Para a Vigília, a dificuldade será ajustada principalmente pelas alavancas 2 e 3, porque a alavanca 1 tem pouco espaço: a jogadora é frágil por design, e a Presença não tem vida. Uma regra de partida: **na dúvida, a primeira vez que algo acontece deve ser mais fácil** — o jogador está aprendendo a regra, e morrer antes de entendê-la é frustração, não medo.

**Dificuldade dinâmica** (o jogo ajusta a dificuldade conforme o desempenho) é uma realimentação negativa (Capítulo 5), com o mesmo risco: se percebida, destrói a confiança. Se a Vigília usar algo assim — por exemplo, o *AI Director* do Capítulo 42 dando mais tempo de respiro a uma jogadora que acabou de morrer duas vezes —, deve ser sutil e nunca invalidar uma decisão do jogador.

---

## Comparação com o desenvolvimento tradicional

| Combate | O que você conhece | Onde a analogia cai |
|---|---|---|
| TTK / TTD | SLOs e orçamentos de latência | O "usuário" quer que alguns tempos sejam **longos** (tensão) |
| Simulação de TTK | Teste de carga com distribuição de latência | O objetivo não é minimizar, é atingir uma faixa que produz uma estética |
| Telegrafia ≥ tempo de reação | Timeouts dimensionados para o pior caso | O "cliente" é um sistema nervoso, com variação e fadiga |
| Economia de recursos | Orçamentos, cotas, rate limits | A escassez é **desejada** como fonte de tensão |
| Dificuldade dinâmica | Autoscaling / controle adaptativo | Se o usuário percebe a adaptação, a experiência piora |

---

## Implementação: um simulador de combate

Antes de colocar um inimigo no Galpão, é possível **prever** o TTK com simulação — exatamente como a simulação de balanceamento do Capítulo 5. O programa abaixo simula duelos entre uma arma (com cadência, pente, recarga) e um alvo, com uma taxa de acerto do jogador, e reporta a distribuição do TTK.

```cpp
// combat_sim.cpp — g++ -std=c++20 -O2 combat_sim.cpp -o combat_sim
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <random>
#include <vector>

struct Weapon
{
    const char* Name;
    float Damage;
    float RoundsPerMinute;
    int MagazineSize;
    float ReloadTime;
};

// Simula um duelo contra um alvo estático e devolve o tempo até o abate (s).
// Simplificações: alvo não reage, taxa de acerto constante, sem dano por distância.
float SimulateTimeToKill(const Weapon& W, float TargetHealth, float HitChance, std::mt19937& Rng)
{
    std::bernoulli_distribution Hit(HitChance);
    const float Interval = 60.0f / W.RoundsPerMinute;

    float Time = 0.0f;
    float Health = TargetHealth;
    int InMagazine = W.MagazineSize;

    while (true)
    {
        if (InMagazine == 0)
        {
            Time += W.ReloadTime;       // recarga completa (reserva infinita na simulação)
            InMagazine = W.MagazineSize;
        }
        --InMagazine;
        if (Hit(Rng))
        {
            Health -= W.Damage;
            if (Health <= 0.0f)
            {
                return Time;            // o disparo que abate acontece no instante "Time"
            }
        }
        Time += Interval;
    }
}

int main()
{
    const std::vector<Weapon> Weapons = {
        { "Pistola", 25.0f, 400.0f, 8, 1.6f },
        { "Fuzil",   18.0f, 750.0f, 30, 2.2f },
    };
    const float TargetHealth = 100.0f;
    const float HitChances[] = { 1.0f, 0.7f, 0.4f };
    const int Trials = 20000;

    std::mt19937 Rng(2026);   // semente fixa: resultados reproduzíveis (Cap. 3)
    std::printf("Alvo: %.0f de vida\n\n", TargetHealth);
    std::printf("%-8s %7s %10s %10s %10s\n", "Arma", "Acerto", "TTK med.", "TTK p90", "TTK max");

    for (const Weapon& W : Weapons)
    {
        for (float P : HitChances)
        {
            std::vector<float> Samples;
            Samples.reserve(Trials);
            for (int i = 0; i < Trials; ++i)
            {
                Samples.push_back(SimulateTimeToKill(W, TargetHealth, P, Rng));
            }
            std::sort(Samples.begin(), Samples.end());
            const float Median = Samples[Trials / 2];
            const float P90 = Samples[static_cast<int>(Trials * 0.9)];
            std::printf("%-8s %6.0f%% %9.2fs %9.2fs %9.2fs\n",
                        W.Name, P * 100.0f, Median, P90, Samples.back());
        }
    }
    return 0;
}
```

Observe na saída:

- Com 100% de acerto, o TTK é **determinístico** e igual à fórmula da seção 21.2 (pistola: 0,45 s).
- Com 70% e 40%, a **distribuição** se abre — e o percentil 90 (os duelos "ruins") é o que o jogador lembra. Com 40% de acerto, a pistola começa a exigir **recarga** no meio do duelo, e o TTK salta.
- Olhar **percentis**, e não a média, é o mesmo hábito que você tem com latência: o p90 de um TTK é a experiência dos jogadores que estão tendo dificuldade.

> 🌉 **Ponte:** é literalmente um teste de carga com distribuição de latência — só que, aqui, você está dimensionando a **experiência**, e a meta pode ser uma faixa (nem rápido demais, nem lento demais), não um mínimo.

### O documento de combate da Vigília (v0.1)

Como o documento de loops do Capítulo 5, o combate ganha um documento versionado (`docs/design/combate.md`):

```text
VIGÍLIA — COMBATE (v0.1)

PRINCÍPIO
  A Presença não pode ser morta. Lutar é ganhar tempo, nunca vencer.

PRESENÇA × SINALIZADOR
  Efeito de um acerto direto: repulsão + atordoamento de 4 s + perde o rastro.
  Efeito de explosão próxima (até 4 m): repulsão, atordoamento de 2 s.
  Luz do sinalizador: zona segura temporária (raio ~6 m, 8 s).
  Cartuchos: máx. 4; 1 no início do setor B; 3 escondidos no mapa inteiro.
  Recarga: 2,5 s (janela de vulnerabilidade).

TELEGRAFIA DA PRESENÇA
  Ataque precedido por: som característico (≥ 1,2 s antes) + falha das luzes próximas.
  Nenhum ataque sem telegrafia. Primeiro encontro: telegrafia de 2 s.

JOGADORA
  Sem barra de vida visível. Dois "toques" da Presença = morte (o primeiro é aviso).
  Feedback de dano: vinheta, respiração, áudio abafado.

VIGIAS (trecho único, setor C)
  Derrotáveis. TTK com a pistola deles (se coletada): ~0,5–1,0 s com 70% de acerto.
  TTD da jogadora sob fogo de um vigia: ~2,5 s. (TTK << TTD só se ela usar cobertura.)

PERGUNTAS ABERTAS (playtest)
  - 4 cartuchos é escasso demais? (Teste: quantos a jogadora ainda tem no final?)
  - 1,2 s de telegrafia é suficiente com a câmera e o áudio finais?
  - O trecho dos vigias quebra o tom? (Hipótese: o contraste reforça a vulnerabilidade.)
```

---

## Decisões arquiteturais

1. **Combate é projetado com métricas** (TTK, TTD, STK, DPS efetivo, telegrafia) e verificado por simulação antes do playtest.
2. **Percentis, não médias**, para avaliar a experiência de combate.
3. **Telegrafia ≥ tempo de reação + resposta** para todo ataque significativo.
4. **A Presença é invencível; o sinalizador repele.** Combate é ferramenta de fuga.
5. **Sem barra de vida da Presença nem da jogadora**; feedback diegético.
6. **Dificuldade da Vigília via comportamento e recursos**, não via números de vida.
7. **Documento de combate versionado** com perguntas abertas.

---

## Armadilhas

- **Projetar só o "engajar"** e esquecer perceber, posicionar e recuperar.
- **Balancear pela média.**
- **Ataques sem telegrafia** — injustiça percebida.
- **Recursos generosos num jogo de terror** — o medo some.
- **Dar ao jogador um verbo de combate sem pensar no que ele faz com a vulnerabilidade.**
- **Barras de vida para tudo** — inclusive para o que não deveria ser "vencível".
- **Dificuldade dinâmica perceptível.**

---

## Exercício

**Parte 1 — simulação (1 h).** Compile e rode o `combat_sim.cpp`. Acrescente o sinalizador (dano alto, 60 RPM, pente 1, recarga 2,5 s) e um alvo de 300 de vida (um "vigia com colete"). Que arma tem o melhor p90 a 40% de acerto? Por quê?

**Parte 2 — TTD (45 min).** Inverta a simulação: um inimigo com uma arma e uma taxa de acerto atirando na jogadora (100 de vida). Ajuste o inimigo para que o TTD da jogadora seja ~2,5 s a 50% de acerto do inimigo. Que combinação de dano e cadência você escolheu?

**Parte 3 — documento (45 min).** Escreva o `docs/design/combate.md` da Vigília, partindo do exemplo e reescrevendo com as suas decisões. Inclua pelo menos três perguntas abertas.

**Parte 4 — análise (45 min).** Escolha um FPS que você conhece bem (COD, Battlefield, Apex) e estime, jogando ou por fontes públicas, o TTK de uma arma comum contra um jogador. Compare com o TTD. O combate desse jogo é de "poder", "duelo" ou "fragilidade"? Marque fatos e inferências.

---

## Desafio — telegrafia mensurável

Projete um **teste de justiça** para a telegrafia da Presença, que você poderá executar quando ela existir (Parte V):

1. Defina o que conta como "a jogadora reagiu" (começou a correr? virou a câmera para a ameaça? entrou na luz?).
2. Proponha uma forma de **medir**, durante o playtest, o tempo entre o início da telegrafia e a reação (um log com *timestamps* de eventos — você já tem `OnFootstep`, mudanças de modo de input e, em breve, eventos de percepção).
3. Defina o critério de aprovação: por exemplo, "em 90% dos encontros, a jogadora reage antes do ataque".

Escreva o plano no `DEVLOG.md`. É a primeira **telemetria de design** do projeto — o equivalente, para a experiência, das métricas de observabilidade que você usa no trabalho.

---

## Uso de IA

1. **Para balanceamento assistido:**
   > "Tenho estas armas (dano, RPM, pente, recarga) e estes inimigos (vida, armadura). Ajude-me a calcular STK, TTK ideal e TTK esperado para taxas de acerto de 40%, 70% e 100%, incluindo recargas. Depois, sugira mudanças mínimas para que todas as armas tenham TTK p90 entre 0,8 e 1,5 s contra o inimigo padrão. Mostre as contas."

2. **Para design de combate em terror:**
   > "Atue como game designer de terror. Avalie esta regra: 'o inimigo principal é invencível; um sinalizador com 4 cartuchos o repele e atordoa por 4 segundos'. Liste dinâmicas prováveis (positivas e negativas), riscos de o jogador 'perder o medo', e três variações da regra para testar em playtest."

3. **Para telegrafia:**
   > "Quais técnicas de telegrafia de ataques são usadas em jogos de ação e terror (animação, som, luz, câmera, UI)? Para cada uma, explique a vantagem em legibilidade e o efeito na tensão. Não atribua técnicas específicas a jogos específicos sem indicar se é observável ou inferência."

---

## Checklist

- [ ] Sei decompor um encontro no loop perceber → posicionar → engajar → resolver → recuperar.
- [ ] Sei calcular DPS, STK, TTK ideal e entendo por que o TTK real precisa de simulação.
- [ ] Sei usar a relação TTK/TTD para caracterizar um combate.
- [ ] Sei por que a telegrafia deve exceder o tempo de reação e como isso serve à tensão.
- [ ] Entendo combate como economia de recursos, risco e recompensa.
- [ ] Consigo comparar Amnesia, Outlast e Alan Wake quanto a "o jogador pode lutar?".
- [ ] Construí e rodei o simulador de combate e escrevi o documento de combate da Vigília.

---

## Para ir além

- **Jesse Schell, *The Art of Game Design*** — capítulos sobre balanceamento e sobre desafio e habilidade.
- **GDC Vault** (gdcvault.com) — busque talks sobre *encounter design*, *combat design* e telegrafia em jogos de ação; e postmortems de jogos de terror que discutem a decisão de ter ou não combate.

---

➡️ **Próximo:** [Capítulo 22 — Health/Damage](cap-22-health-damage.md)

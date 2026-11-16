# Capítulo 70 — IA para Game Design

## Objetivo

Ao final deste capítulo você deve conseguir:

- usar IA para **divergir** (gerar muitas variações de uma mecânica) sem terceirizar a **convergência** (escolher, com os pilares do jogo);
- ler variações de mecânica pelo **MDA** e transformar cada uma numa hipótese testável;
- pedir uma **análise de loops** que encontre realimentações, estratégias dominantes e tempo morto, e tratar o resultado como hipótese, não como veredito;
- montar um **balanceamento assistido**: modelo numérico, simulação em código, distribuição, faixa de design, varredura de parâmetros, com a IA ajudando a escrever e a ler, e nunca a fazer as contas de cabeça;
- reconhecer os vieses típicos da IA em design: a média do gênero, o "mais *features*", e fatos inventados sobre jogos comerciais;
- manter um **registro de ideias** que diz de onde cada ideia veio e por que foi aceita ou recusada.

---

## Contexto

Game design é, em grande parte, **formular hipóteses e testá-las**. O Capítulo 5 disse isso com o MDA: quem projeta escreve mecânicas; quem joga sente estética; entre as duas há dinâmicas que **só se observam jogando**. O documento de loops da Vigília terminou com perguntas abertas, e o documento de combate do Capítulo 21 também. Cada pergunta é uma hipótese com um critério de verificação.

A IA entra nesse ciclo em dois pontos, e é importante saber quais:

```text
  ideia ──► hipótese ──► protótipo ──► playtest ──► decisão
    ▲           ▲            │
    │           │            │
  DIVERGIR    ANALISAR     (a IA não joga; você e as pessoas do playtest jogam)
  (muitas     (loops,
  variações)  números)
```

Ela é muito boa em **volume** (vinte variações de uma mecânica em um minuto) e razoável em **análise estrutural** (encontrar um loop de realimentação num documento). Ela é ruim em **gosto** e não tem **corpo**: não sente o medo de uma bateria acabando, não percebe que um susto previsível deixou de assustar. E tem vieses previsíveis: propõe a média do gênero, acrescenta sistemas, e afirma coisas sobre jogos comerciais com a mesma segurança com que afirma APIs.

A pergunta deste capítulo é como usar a primeira metade sem herdar a segunda.

---

## 70.1 Divergir e convergir

Todo processo de ideação alterna duas fases: **divergir** (abrir o espaço de opções) e **convergir** (fechar com critérios). A IA inverte a economia da primeira fase: o que custava uma tarde de *brainstorm* custa um prompt. Isso é bom e é perigoso, porque o gargalo passa a ser a segunda fase, e a segunda fase é **sua**.

Três técnicas tornam a divergência útil.

**1. Restrições antes do pedido.** Sem restrições, a IA devolve a média do gênero. Com elas, devolve o que cabe no seu jogo. Para a Vigília, o prompt começa sempre pelos pilares (Introdução, seção 6.1) e pelas **anti-metas**, o que o jogo **não** é:

```text
PILARES: luz como recurso, linguagem e defesa; burocracia como narrativa; a máquina como horror;
         vulnerabilidade e perseguição; momentos cinematográficos; um combate curto.
ANTI-METAS: sem combate contra a Presença; sem estamina; sem árvore de habilidades;
            sem inventário de gestão; 10–20 minutos; uma pessoa produz tudo.
```

**2. Eixos explícitos.** "Dê 10 ideias" produz 10 variações do mesmo eixo. "Varie em quatro eixos: o **recurso** (o que se gasta), a **regra** (quando se gasta), o **feedback** (como a jogadora percebe) e o **acoplamento** (com que outro sistema isso conversa)" produz um espaço.

**3. A dinâmica e o falsificador junto com a ideia.** Peça, para cada variação, a **dinâmica** esperada, a **estética** que ela serviria e **o que no playtest provaria que ela não funciona**. Uma ideia sem falsificador não é hipótese; é gosto.

E uma técnica para a convergência: **você pontua primeiro, a IA critica depois**. Se a IA pontuar primeiro, você ancora na pontuação dela.

> 🌉 **Ponte:** é a sessão de *discovery* de produto, com a diferença de que o "time" gera opções instantaneamente. O seu papel se parece com o do *product owner* que corta escopo com critérios explícitos.
>
> 🧱 **Onde a ponte cai:** em produto, uma opção ruim aparece em métricas. Em game design, uma mecânica pode ser coerente no papel e **sem graça** na mão, e só o corpo de quem joga detecta isso. Nenhuma quantidade de análise substitui o playtest.

---

## 70.2 Variações de mecânica, lidas pelo MDA

O exemplo é a **lanterna**, o coração do pilar "luz como recurso". Hoje ela funciona assim (Partes III–V): a bateria drena enquanto está acesa, recarrega na luz das zonas seguras, há baterias como *pickup*, e a luz acesa torna a jogadora visível de longe para a Presença (Capítulo 36). Um prompt com pilares, anti-metas e os quatro eixos devolveu, entre outras, as variações abaixo.

**[HIPOTÉTICO]** A tabela ilustra o formato de uma resposta típica, já filtrada e resumida por quem escreveu o livro. Não é a transcrição de uma conversa real.

| # | Variação (mecânica) | Dinâmica esperada | Estética servida | Pilares | Custo | Falsificador (playtest) |
|---|---|---|---|---|---|---|
| 1 | **Feixe em dois modos**: largo (drena pouco) e concentrado (drena muito, ilumina longe, atordoa levemente) | Troca de modo por situação; o concentrado vira "arma fraca" | Controle tenso | ⚠️ aproxima a lanterna de combate | Médio | Se a jogadora vive no modo concentrado, ele é arma |
| 2 | **Dínamo de manivela**: recarrega girando, mas o som é **ruído** (Capítulo 36) | Escolha entre luz e silêncio; recarregar no escuro é apostar | Vulnerabilidade, decisão sob medo | ✓ acopla luz e ruído | Baixo: ruído já existe | Se ninguém usa, ou se é sempre seguro usar |
| 3 | Baterias com **carga variável** (algumas velhas, de 1994) | Incerteza ao trocar | Desconfiança | ✓ burocracia, 1994 | Baixo | Se a jogadora não percebe a diferença |
| 4 | **Inventário de baterias** com peso | Gestão | Planejamento | ✗ anti-meta | Alto | — |
| 5 | Lanterna que **falha** perto da Presença | Pânico; a luz trai | Horror da máquina | ✓ (o `UVGFlickerComponent` já existe) | Baixo | Se parece bug, não ameaça |
| 6 | **Bateria compartilhada** com a sobrecarga da lanterna (o ataque de luz dos pilares) | Cada sobrecarga custa minutos de escuridão | Sacrifício | ✓ combate curto | Médio | Se a sobrecarga nunca é usada |
| 7 | Barra de "sanidade" que cai no escuro | Pressa para sair do escuro | Medo do escuro | ✗ duplica a bateria; copia um jogo conhecido | Alto | — |

A convergência, com os pilares na mão:

- **4 e 7 saem** sem discussão: anti-meta e duplicação. Repare que a 7 é exatamente a "média do gênero": é o sistema mais famoso de terror em primeira pessoa (estudo de caso), e a IA o propõe porque ele aparece muito nos textos sobre o gênero.
- **1 sai** por um motivo mais sutil: aproxima a lanterna de uma arma, o que gera dissonância com "você é uma perita, não uma soldada" (Capítulo 43).
- **2 e 6 ficam** para protótipo, porque **acoplam sistemas que já existem** (ruído e sobrecarga), e não acrescentam um sistema novo. Esse é um critério que vale guardar: *a melhor variação costuma ser uma nova conexão, não uma nova peça*.
- **3 e 5 viram notas** para os Capítulos 48 (documentos e objetos de 1994) e 51 (luz como mecânica).

O resultado de uma hora de trabalho são duas hipóteses com falsificador, e nenhuma linha de código ainda.

---

## 70.3 Análise de loops

O segundo uso é analisar um documento de design, e não gerar ideias. Você cola o `docs/design/loops.md` (Capítulo 5), o `combate.md` (Capítulo 21) e uma descrição do Diretor (Capítulo 42), e pede:

1. as **realimentações** positivas e negativas, com o caminho causal de cada uma;
2. **estratégias dominantes** (algo que a jogadora pode fazer sempre e que esvazia uma decisão);
3. **tempo morto** (trechos em que nenhuma decisão interessante existe);
4. **feedback ausente** (regras que a jogadora não tem como perceber).

Uma análise desse tipo sobre a Vigília produz achados como estes:

- **Realimentação positiva:** ruído → ameaça ↑ → pressa → mais ruído. Já estava no documento de loops, e é desejada (escalada até a perseguição).
- **Realimentação negativa:** zona iluminada → ameaça ↓, bateria ↑. Também prevista.
- **Estratégia dominante candidata: "acampar na luz".** A Presença não entra na luz. Ficar parado numa zona segura é sempre seguro. A resposta de design é que os objetivos estão no escuro e que o Diretor força um *build-up* depois de `MaxRelaxTime`. Isso basta? É pergunta de playtest, não de análise.
- **Estratégia dominante candidata: "ler para congelar o Diretor".** Este achado é mais interessante, porque vem do **código**, não do documento. O Diretor do Capítulo 42 não passa de `Relax` para `BuildUp`, nem de `BuildUp` para `Peak`, enquanto a jogadora está lendo (a regra existe para não começar um pico com um documento aberto). Consequência: **abrir um documento congela o ritmo da ameaça.** Uma jogadora que perceba isso pode usar a leitura como pausa tática. (O Capítulo 82 confere o código e mostra que o achado é menor do que parece: o tempo na fase continua contando e o `MaxRelaxTime` já limita o `Relax`.)

O segundo achado mostra o valor e o limite da ferramenta. A IA encontrou uma interação entre duas regras que, separadas, eram razoáveis. Ela **não** sabe se isso importa: talvez nenhuma jogadora perceba; talvez perceber seja até divertido. As respostas possíveis são decisões de design:

| Resposta | Custo | Efeito |
|---|---|---|
| Aceitar: ninguém lê para sempre | Zero | O exploit existe, e é raro |
| Teto: depois de N segundos lendo, o Diretor volta a contar o tempo (sem iniciar o pico durante a leitura) | Uma linha no Diretor | A leitura protege, mas não congela |
| Consequência diegética: a leitura longa atrai a Presença até a porta (o pico começa ao fechar o documento) | Médio | Transforma o exploit em tensão |

Escolher entre elas é trabalho seu. A análise só tornou a escolha **visível**.

> **Verificação:** uma "estratégia dominante" apontada por IA é uma **hipótese sobre o código ou sobre o documento**. Confira a regra no código (aqui, `UVGDirectorSubsystem::UpdatePhase`) antes de mexer em qualquer coisa. Análises de loop sobre documentos desatualizados acham problemas que não existem mais, e deixam passar os que existem.

---

## 70.4 Balanceamento assistido

O Capítulo 21 construiu um simulador de TTK e mostrou o hábito certo: olhar **percentis**, não médias. O Capítulo 5 chamou isso pelo nome: **simulação de balanceamento**. Agora o simulador vira uma ferramenta de busca, com a IA no papel de assistente.

O *pipeline*:

```text
 MODELO          SIMULAÇÃO           DISTRIBUIÇÃO        FAIXA DE DESIGN       VARREDURA
 (números da  ─► (código: duelos, ─► (p50, p90 por    ─► (do documento de  ─► (todas as combinações
  arma, vida,     acertos, recarga)   combinação)          combate: "TTK p50     de parâmetros; quem
  acerto)                                                  entre 0,5 e 1,0 s")   cai dentro?)
                                                                                     │
                                         playtest ◄── 2 ou 3 candidatas ◄────────────┘
```

Onde a IA ajuda:

- **Escrever e alterar o programa** ("acrescente uma terceira dimensão: o tamanho do pente"; "exporte em CSV").
- **Ler a saída** ("nestas 42 linhas, quais combinações estão dentro da faixa e longe das bordas? quais parâmetros mais mexem no TTD?").
- **Propor a próxima pergunta** ("o que muda se os vigias acertarem 45% em vez de 35%?"), que **você** responde rodando de novo.

Onde a IA **não** ajuda: fazer as contas. Modelos de linguagem erram aritmética e estatística de cabeça com a mesma fluência com que acertam. "O p90 deve ficar em torno de 1,2 s" não é um resultado. O resultado é o que o programa imprime. A regra é simples: **todo número de balanceamento vem de código que você pode rodar de novo**.

> 🌉 **Ponte:** é planejamento de capacidade com teste de carga: modelo, simulação, distribuição de latência, SLO, varredura de configurações. Você já fez isso com *pools* de conexão e réplicas.
>
> 🧱 **Onde a ponte cai:** o SLO de um serviço é "o mais rápido possível dentro do custo". A faixa de design de um jogo é uma **janela**: TTK curto demais esvazia o combate, longo demais frustra. E a faixa em si é uma hipótese, que o playtest pode mover.

---

## Estudos de caso

### Amnesia: The Dark Descent — a sanidade e o que a IA "sabe" dela

**[FATO PÚBLICO — observável jogando]** Em *Amnesia: The Dark Descent* (Frictional Games, 2010), o protagonista tem uma medida de sanidade que cai quando ele fica no escuro, testemunha eventos perturbadores ou olha para as criaturas, e a sanidade baixa produz distorções de imagem e de som. Luz depende de recursos escassos: caixas de fósforos (*tinderboxes*) para acender velas e óleo para a lamparina.

**[INFERÊNCIA]** O desenho cria um conflito entre duas necessidades: ver (luz, que consome recurso) e se esconder (escuro, que custa sanidade). A estética de medo do escuro nasce de uma **mecânica que pune o escuro**, e não só de um cenário escuro.

O caso interessa a este capítulo por dois motivos. O primeiro é de design: a Vigília resolve o mesmo conflito com **uma** variável (a bateria) e uma regra de percepção (a luz denuncia). A variação 7 da seção 70.2 era, essencialmente, a sanidade de *Amnesia* proposta de volta. O segundo é sobre a ferramenta. Pergunte a uma IA "como funciona exatamente a sanidade de Amnesia" e você tende a receber limiares, taxas e efeitos ocultos ditos com segurança. Parte disso circula em wikis de fãs, parte é inferência, parte é invenção, e a resposta não diz qual é qual. O Capítulo 5 já advertiu sobre boatos de "sistemas ocultos" em jogos de futebol. Em design, isso importa porque você pode **calibrar a sua mecânica contra um número que não existe**.

**Lição para a Vigília:** ao analisar um jogo comercial com IA, peça explicitamente os rótulos do livro (**[FATO PÚBLICO]**, **[INFERÊNCIA]**, **[HIPOTÉTICO]**) e a fonte de cada fato. Números de jogos comerciais sem fonte primária são ruído.

### Spelunky — geração dentro de uma gramática autoral

**[FATO PÚBLICO — descrito pelo próprio autor; confira no livro]** Derek Yu descreve, no livro *Spelunky* (Boss Fight Books, 2016), como as fases do jogo são montadas: uma grade de salas; primeiro, um caminho garantido da entrada à saída; depois, cada sala escolhida a partir de **modelos desenhados à mão**, com trechos que variam aleatoriamente dentro de cada modelo. O resultado é variedade com garantias: toda fase é atravessável, e cada sala "parece desenhada" porque, em parte, foi.

**[INFERÊNCIA]** A relação entre gerador e designer é o ponto. O gerador **não inventa** o que é uma boa sala: ele combina peças que o designer fez, sob regras que o designer escreveu. A criatividade do sistema está na combinação; o gosto está nas peças e nas regras.

**Lição para a Vigília:** é a relação certa entre você e uma IA de ideação. Você escreve a gramática (pilares, anti-metas, eixos, critérios), e a IA gera combinações dentro dela. Quando a IA gera **fora** da gramática (a variação 4, a 7), o defeito não é dela: é de uma gramática que ainda não dizia o suficiente. Acrescente a restrição que faltou ao prompt-padrão do projeto.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Divergir/convergir com IA | *Discovery* de produto, *design thinking* | O critério final é sensação no corpo de quem joga, não métrica |
| Variação de mecânica + falsificador | Hipótese de experimento A/B | Um protótipo de mecânica precisa de **feel**, não só de lógica; amostras são poucas pessoas |
| Análise de loops | Revisão de requisitos procurando conflitos | O "conflito" pode ser desejado (tensão), e o exploit pode ser divertido |
| Simulação + varredura | Teste de carga + planejamento de capacidade | A meta é uma janela estética, não um mínimo |
| Registro de ideias | Backlog com motivo de recusa (ADR leve) | A ideia recusada hoje é a variação de amanhã; o motivo importa mais que a ideia |

---

## Unreal Engine: o que ajuda

A engine não tem, como sistema de jogo, uma "IA de design". Ela tem formas de transformar decisões de design em **dados ajustáveis**, e é isso que torna o ciclo hipótese → teste barato:

- **Data Assets** (Capítulo 13) e **`UCurveFloat`** (Capítulo 40): números e formas fora do código.
- **Data Tables importadas de CSV**: uma varredura que produz CSV pode alimentar uma tabela de parâmetros de teste. ⚠️ Confira o formato de importação na documentação da sua versão.
- **CVars e cheats** (`vg.*`, `VG…`) para ajustar ao vivo e pular para o momento que se quer testar.
- **`slomo`**, **Gameplay Debugger** e **Visual Logger** para observar uma dinâmica que acontece rápido demais.
- **Telemetria própria**, se você quiser medir playtests (tempo por setor, cartuchos restantes no fim), via o barramento de eventos do Capítulo 24 gravando num arquivo. O Capítulo 85 volta a isso no postmortem.

---

## Abordagens

Como balancear os números do combate da Vigília:

| Critério | A. Só playtest | B. Planilha | **C. Simulação em código + IA assistente** | D. Otimizador automático |
|---|---|---|---|---|
| **Complexidade** | Nenhuma | Baixa | Baixa: um programa de 80 linhas | Média/alta: função objetivo, busca |
| **Performance** (velocidade do ciclo) | Lenta: cada rodada custa pessoas | Rápida, mas só para fórmulas fechadas | Rápida, com aleatoriedade e recarga | Rápida |
| **Extensibilidade** | — | Ruim para processos aleatórios | Boa: nova dimensão = novo laço | Boa |
| **Manutenção** | — | Fórmulas escondidas em células | Código versionado, reproduzível (semente fixa) | Função objetivo vira o novo lugar dos erros |
| **Prototipação** | Precisa do jogo pronto | Antes do jogo | Antes do jogo | Antes do jogo |
| **Adequação à Vigília** | Necessária, mas cara como único método | Não captura recarga nem variância | **Sim** | Excesso: poucos parâmetros, e "ótimo" não é a meta |

**Decisão:** **C** para eliminar hipóteses ruins de forma barata, e **A** para decidir entre as poucas que sobram. **D** fica de fora de propósito: um otimizador encontra "o melhor" segundo uma função objetivo, e a função objetivo de um combate de terror é uma estética que você não sabe escrever. A IA entra em **C** como assistente: escreve e altera o programa, lê o CSV, propõe a próxima pergunta. Os números vêm sempre do programa.

---

## Implementação: a varredura

O simulador do Capítulo 21 respondia "qual o TTK desta arma?". A varredura responde à pergunta de design: **quais combinações de dano e cadência satisfazem as duas metas do documento de combate ao mesmo tempo?** As metas puxam em direções opostas. A mesma pistola é usada pela jogadora contra um vigia (TTK, que deve ser curto) e por um vigia contra a jogadora (TTD, que não pode ser curto demais).

```cpp
// tools/balance_sweep.cpp — g++ -std=c++20 -O2 balance_sweep.cpp -o balance_sweep
// Varre dano × cadência da pistola dos vigias e marca as combinações dentro da faixa de design.
// Saída: CSV (./balance_sweep > sweep.csv).
#include <algorithm>
#include <cstdio>
#include <random>
#include <vector>

struct Weapon
{
    float Damage;
    float RoundsPerMinute;
    int MagazineSize;
    float ReloadTime;
};

// A simulação do Capítulo 21, copiada de propósito: a ferramenta é descartável e não depende do jogo.
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
            Time += W.ReloadTime;
            InMagazine = W.MagazineSize;
        }
        --InMagazine;
        if (Hit(Rng))
        {
            Health -= W.Damage;
            if (Health <= 0.0f)
            {
                return Time;
            }
        }
        Time += Interval;
    }
}

struct Distribution
{
    float P50;
    float P90;
};

Distribution Measure(const Weapon& W, float Health, float HitChance, int Trials, std::mt19937& Rng)
{
    std::vector<float> Samples;
    Samples.reserve(Trials);
    for (int i = 0; i < Trials; ++i)
    {
        Samples.push_back(SimulateTimeToKill(W, Health, HitChance, Rng));
    }
    std::sort(Samples.begin(), Samples.end());
    return { Samples[Trials / 2], Samples[static_cast<int>(Trials * 0.9)] };
}

int main()
{
    // Metas do documento de combate (Cap. 21). Mude AQUI, não no meio do código.
    const float VigiaHealth = 100.0f;
    const float PlayerHealth = 100.0f;
    const float PlayerHit = 0.70f;   // a jogadora com a pistola coletada
    const float VigiaHit = 0.35f;    // suposição de design: vigias erram mais (confirme no playtest)
    const float TtkMin = 0.5f;       // TTK p50 da jogadora contra um vigia...
    const float TtkMax = 1.0f;       // ...entre 0,5 e 1,0 s
    const float TtdMin = 2.0f;       // TTD p50 da jogadora sob fogo de um vigia: pelo menos 2 s
    const int Trials = 5000;

    std::mt19937 Rng(2026); // semente fixa: duas execuções, o mesmo CSV
    std::printf("dano,rpm,ttk_p50,ttk_p90,ttd_p50,na_faixa\n");
    for (float Damage = 15.0f; Damage <= 40.0f; Damage += 5.0f)
    {
        for (float Rpm = 200.0f; Rpm <= 500.0f; Rpm += 50.0f)
        {
            const Weapon Pistol{ Damage, Rpm, 8, 1.6f };
            const Distribution Ttk = Measure(Pistol, VigiaHealth, PlayerHit, Trials, Rng);
            const Distribution Ttd = Measure(Pistol, PlayerHealth, VigiaHit, Trials, Rng);
            const bool bInBand = Ttk.P50 >= TtkMin && Ttk.P50 <= TtkMax && Ttd.P50 >= TtdMin;
            std::printf("%.0f,%.0f,%.2f,%.2f,%.2f,%s\n",
                        Damage, Rpm, Ttk.P50, Ttk.P90, Ttd.P50, bInBand ? "sim" : "nao");
        }
    }
    return 0;
}
```

Rode, abra o CSV numa planilha (ou cole-o numa conversa) e observe três coisas, que valem para qualquer resultado:

- **Dano e cadência movem TTK e TTD na mesma direção**, porque a arma é a mesma nos dois sentidos. As duas metas puxam em direções opostas, e a região "sim" é uma **faixa diagonal**, não um canto.
- **A faixa pode estar vazia.** Se nenhuma linha diz "sim", as metas do documento de combate **conflitam** para estas suposições. Isso não é falha da ferramenta, é uma descoberta de design, e as saídas são de design: mudar a suposição de acerto dos vigias, dar aos vigias um multiplicador de dano próprio, ou rever a meta.
- **As candidatas boas ficam longe das bordas.** Uma combinação que entra na faixa por dois centésimos sai dela com a primeira mudança de animação de recarga. Prefira o miolo.

### Explicação das decisões

- **Copiar a simulação em vez de reaproveitar o código do jogo.** A ferramenta é descartável e precisa rodar sem a engine. Se um dia ela crescer, o Capítulo 72 mostra o caminho inverso: regras puras do jogo testadas por cenários.
- **Metas no topo de `main`, com o nome do documento de onde vieram.** Quem muda uma meta muda num lugar só, e o CSV fica rastreável até a decisão.
- **Semente fixa.** Duas execuções produzem o mesmo arquivo; uma diferença no CSV significa uma mudança de parâmetro, não sorte.
- **p50 para a meta e p90 na saída.** A meta usa a mediana (a experiência típica), e o p90 fica visível para a pergunta do Capítulo 21: e os duelos ruins?
- **CSV no `stdout`.** É o formato que uma planilha, um gráfico, a IA e você leem igualmente bem.

---

## Projeto Vigília — o laboratório de design

O que muda no repositório:

```text
docs/design/
├── ideias.md          registro de ideias: origem (eu | IA | playtest), data, status
│                      (protótipo | nota | recusada), motivo, falsificador
├── loops.md           ganha a seção "RISCOS DETECTADOS" (acampar na luz; ler para congelar o Diretor)
└── combate.md         v0.2: faixa de design explícita (TTK p50, TTD p50, acerto suposto dos vigias)
                       + as 2–3 combinações candidatas da varredura e o CSV de origem
tools/
└── balance_sweep.cpp
```

O **registro de ideias** é a peça que mais se paga. Uma linha por ideia:

```text
| # | Ideia                         | Origem | Status     | Motivo                                  | Falsificador                     |
| 7 | Barra de sanidade no escuro   | IA     | recusada   | duplica a bateria; média do gênero      | —                                |
| 2 | Dínamo de manivela com ruído  | IA     | protótipo  | acopla luz e ruído; custo baixo         | ninguém usa, ou é sempre seguro  |
| 9 | Teto de leitura no Diretor    | IA→eu  | decidir    | exploit "ler para congelar"             | playtest: alguém percebe?        |
```

A coluna **Origem** não serve para dar crédito. Ela serve para você descobrir, no postmortem (Capítulo 85), **que tipo de ideia de cada origem sobreviveu ao playtest**. Se as ideias da IA que sobrevivem são sempre conexões entre sistemas, e as que morrem são sempre sistemas novos, você aprendeu como pedir.

**Decisão sobre "ler para congelar o Diretor":** registre no `DEVLOG.md` qual das três respostas da seção 70.3 você escolheu e por quê. Se escolher o teto, a mudança é pequena e mora no `UpdatePhase` do Diretor (uma constante nova em `VGDirectorTuning`, com a mesma marca `// Simplificação:` das outras; a partir do Cap. 80, um campo do `UVGDirectorProfile`).

---

## Decisões arquiteturais

1. **A IA diverge; a convergência é sua**, com pilares e anti-metas escritos no prompt-padrão do projeto.
2. **Toda ideia vira hipótese com falsificador**, ou não entra no registro como protótipo.
3. **Preferir variações que conectam sistemas existentes** a variações que acrescentam sistemas.
4. **Análises de loop são hipóteses sobre código e documentos**, verificadas no código antes de qualquer mudança.
5. **Números de balanceamento vêm de programas reproduzíveis** (semente fixa, metas no topo, CSV); a IA escreve e lê, não calcula.
6. **Faixa de design no documento de combate**, como janela, com a origem de cada número.

---

## Armadilhas

- **Pedir ideias sem restrições** e receber a média do gênero (sanidade, inventário, árvore de habilidades).
- **Deixar a IA pontuar primeiro.** Você ancora na nota dela e chama isso de decisão.
- **Aceitar números calculados de cabeça** pela IA, em especial percentis e probabilidades.
- **Calibrar contra "fatos" de jogos comerciais** sem fonte primária.
- **Tratar uma estratégia dominante apontada como bug**, sem perguntar se ela é divertida ou se alguém vai percebê-la.
- **Otimizar até a borda da faixa.** O ponto "ótimo" de uma varredura é frágil; o miolo é robusto.
- **Analisar um documento desatualizado.** O código mudou no Capítulo 42; o `loops.md` é do Capítulo 5.
- **Acumular protótipos.** Duas hipóteses testadas valem mais que dez esboçadas.

---

## Exercício

**Parte 1 — divergir com gramática (45 min).** Escreva o prompt-padrão de design da Vigília (pilares, anti-metas, os quatro eixos, o pedido de dinâmica, estética e falsificador). Use-o para gerar variações do **sinalizador** (não da lanterna). Filtre com os pilares **antes** de pedir qualquer avaliação à IA. Registre tudo em `ideias.md`.

**Parte 2 — análise de loops (1 h).** Cole o `loops.md`, o `combate.md` e uma descrição do Diretor (fases, condições de transição, a regra da leitura) e peça a análise da seção 70.3. Para cada estratégia dominante apontada, encontre a regra correspondente **no código** e marque: confirmada, falsa (documento desatualizado) ou incerta.

**Parte 3 — a varredura (1,5 h).** Compile e rode o `balance_sweep.cpp`. Depois peça a uma IA para acrescentar uma dimensão (o tamanho do pente: 6, 8, 10) e para escrever o CSV num arquivo. Leia o diff antes de rodar. Escolha duas combinações candidatas e justifique por que estão longe das bordas.

**Parte 4 — o teste da conta (30 min).** Antes de rodar a varredura, pergunte a uma IA: "qual o TTK p50 de uma pistola de 25 de dano, 400 RPM, pente 8, recarga 1,6 s, contra 100 de vida, com 70% de acerto?". Compare com a linha correspondente do CSV e registre a diferença no `DEVLOG.md`.

---

## Desafio — o orçamento de escuridão

O documento de loops perguntava: *quanto tempo a bateria deve durar para tensão sem frustração?* Construa uma segunda ferramenta de varredura:

1. Modele um setor como uma sequência de trechos escuros (comprimento em metros) entre zonas seguras, a velocidade da jogadora (andando e correndo, com a fração de cada uma), a drenagem da lanterna, a recarga nas zonas seguras e as baterias encontradas (com probabilidade por trecho).
2. Simule milhares de travessias e meça a distribuição do **tempo com a bateria zerada** por setor.
3. Defina uma faixa ("p50 entre 10 e 30 s de escuridão total por setor; p90 abaixo de 60 s") e varra a drenagem e o espaçamento entre zonas seguras.
4. Responda no `DEVLOG.md`: a faixa que você escolheu é design ou chute? Que observação de playtest poderia movê-la?

---

## Uso de IA

Prompts meta, para avaliar o seu uso de IA em design:

1. **Para medir quem decide:**
   > "Aqui está o meu `ideias.md` com a coluna Origem. Para as ideias aceitas, aponte quais foram aceitas por mérito explicado no registro e quais parecem aceitas sem justificativa ligada a um pilar. Para as recusadas, aponte recusas sem motivo. Não avalie se as ideias são boas; avalie se as decisões estão documentadas."

2. **Para checar o viés da média do gênero:**
   > "Aqui estão 20 ideias de mecânica geradas para um jogo de terror em primeira pessoa. Marque quais são variações de sistemas muito conhecidos do gênero (diga qual) e quais são combinações menos comuns entre os sistemas que já existem neste jogo: [lista de sistemas]. Não gere ideias novas."

3. **Para separar fato de lenda num estudo de jogo:**
   > "Descreva o sistema [X] de [jogo] usando três rótulos: FATO PÚBLICO (com a fonte primária: talk, postmortem, entrevista do estúdio, ou observável jogando), INFERÊNCIA e NÃO SEI. Nenhum número sem fonte. Se a única fonte for wiki de fãs, diga isso."

4. **Para revisar uma análise sua:**
   > "Escrevi esta análise de loops da Vigília. Não reescreva. Aponte: afirmações que dependem de um número que eu não medi, estratégias dominantes que eu não considerei, e trechos em que confundi a dinâmica que eu QUERO com a que o sistema PRODUZ. [análise] [documentos]"

**Cuidado específico:** a IA concorda com facilidade. Se você apresentar uma ideia como sua e pedir avaliação, ela tende a elogiar; se apresentar a mesma ideia como "de um colega", tende a criticar mais. Para uma avaliação útil, peça sempre os **três motivos mais fortes contra** e o **teste de playtest** que decidiria a questão.

---

## Checklist

- [ ] Sei escrever um prompt de ideação com pilares, anti-metas, eixos e falsificadores.
- [ ] Sei ler uma variação de mecânica pelo MDA e transformá-la em hipótese testável.
- [ ] Sei pedir uma análise de loops e verificar cada achado no código.
- [ ] Encontrei (ou descartei com motivo) a estratégia "ler para congelar o Diretor".
- [ ] Rodei a varredura, sei ler a faixa diagonal e sei o que fazer se ela estiver vazia.
- [ ] Nenhum número de balanceamento no meu documento de combate veio de conta feita por IA.
- [ ] Mantenho um registro de ideias com origem, status, motivo e falsificador.

---

## Para ir além

- **Robin Hunicke, Marc LeBlanc e Robert Zubek, *MDA: A Formal Approach to Game Design and Game Research*** (2004). Releia depois deste capítulo: o vocabulário é o mesmo que o prompt de ideação usa.
- **Jesse Schell, *The Art of Game Design: A Book of Lenses*.** As "lentes" funcionam muito bem como perguntas para uma análise assistida: escolha três lentes e peça à IA que aplique cada uma ao seu documento, com você julgando as respostas.
- **Ernest Adams e Joris Dormans, *Game Mechanics: Advanced Game Design*.** Modela economias internas e realimentações de jogos como diagramas, a base natural para as análises de loop e as simulações deste capítulo.
- **Derek Yu, *Spelunky*** (Boss Fight Books, 2016). O autor conta como desenhou o jogo e o gerador de fases.
- **GDC Vault** (gdcvault.com): palestras de *game balancing* e de design sistêmico. Procure por *balancing* e *systemic design* e confira títulos e autores lá.

---

➡️ **Próximo:** [Capítulo 71 — IA para Narrative Design](cap-71-ia-narrative-design.md)

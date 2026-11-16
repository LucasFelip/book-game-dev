# PARTE VII — World Building

*Projeto: a Vigília ganha corpo. O setor 1 passa de grey-box a experiência com luz, som, animação, efeitos e interface, e os setores 2 e 3 nascem em blockout.*

---

# Capítulo 50 — Level Design

## Objetivo

Ao final deste capítulo você deve conseguir:

- construir um **blockout** (*grey-box*) com **métricas** do seu jogo, e não com números genéricos;
- guiar a jogadora **sem setas**: luz, som, *landmarks*, *affordances* e enquadramento;
- desenhar **gating** (o que bloqueia o avanço e o que o libera) e **pacing espacial** (o ritmo que o espaço impõe);
- projetar **espaços de horror**: a curva do corredor, linhas de visão, compressão e alívio, rotas de fuga;
- escrever o **documento de nível** com uma **frase de intenção** por espaço;
- transformar o puzzle dos disjuntores num **ator de puzzle reutilizável**, a última cola do Level Blueprint de `L_CasaDeForca`;
- levar ao blockout o espaço dos setores 2 (Subestação) e 3 (Salão das Turbinas).

---

## Contexto

A Casa de Força nasceu no Interlúdio I como um desenho ASCII e cinco caixas cinza, com as métricas de partida do Capítulo 7. Funcionou. O playtest do Interlúdio, porém, fez uma pergunta que nenhum sistema da Parte VI respondeu: **onde as jogadoras se perderam?** A resposta, em quase todo playtest de jogo narrativo, mostra que o problema não está no código, e sim no espaço: a porta que ninguém viu, o armário que parecia cenário, o corredor que não dizia para onde ir.

Ao longo da Parte VI, o Level Blueprint de `L_CasaDeForca` encolheu até sobrar uma linha e o puzzle dos disjuntores (Capítulo 49). O puzzle é a última cola de nível, e o Capítulo 45 deixou o recado: transformá-lo num ator reutilizável é trabalho do level design, porque a Subestação vai precisar de outro puzzle do mesmo tipo.

E o Capítulo 76 conta com mais dois setores, a Subestação (2) e o Salão das Turbinas (3), que ainda não existem nem em cinza.

Luz (Cap. 51), som (52), animação (53), efeitos (54) e interface (55) servem a um espaço; se o espaço não funciona, nenhum deles o salva.

---

## 50.1 O nível como sistema

Um nível não é um cenário onde a jogadora age. Ele é um **sistema que sequencia a experiência**: decide o que ela vê primeiro, onde ela hesita, quanto tempo leva de um ponto a outro, de onde a ameaça pode vir e onde ela respira. O level designer trabalha com quatro camadas que se sobrepõem:

| Camada | Pergunta | Ferramentas | Na Vigília |
|---|---|---|---|
| **Topologia** | Que espaços existem e como se ligam? | Grafo de salas, portas, atalhos | Hall → corredor → salas → escada → subsolo |
| **Métrica** | Que tamanho tem cada coisa, e quanto tempo leva atravessá-la? | Grid, cápsula, alcance de visão e de luz | Corredor de 2,2 m, alcance da lanterna, visão da Presença |
| **Ritmo** | Onde a tensão sobe e onde cai? | Compressão/alívio, zonas seguras, revelações | A curva de tensão do Interlúdio I |
| **Informação** | O que o espaço comunica, e como a jogadora sabe para onde ir? | Luz, som, *landmarks*, *affordances* | A janela da sala de controle, o zumbido do subsolo |

Só a primeira camada é "construção"; as outras três são design de experiência aplicado à geometria.

> 🌉 **Ponte:** um nível se parece com o **fluxo de uma aplicação** desenhado por alguém de UX: telas (espaços), transições (portas), estados bloqueados (gates) e o caminho feliz (o *critical path*). Os protótipos de baixa fidelidade de UX, o *wireframe*, são o blockout.
>
> 🧱 **Onde a ponte cai:** em UX, atrito é defeito e o caminho ideal é o mais curto. No level design de terror, o atrito é **matéria-prima**: a curva que esconde o fim do corredor, a escada que obriga a descer devagar, o beco que assusta. O nível não otimiza a tarefa; otimiza a **emoção** ao longo dela.

---

## 50.2 Blockout e métricas

### O que é o blockout

***Blockout*** (ou *grey-box*) é a versão do nível feita com formas simples (caixas, rampas, cilindros) e materiais neutros, **jogável** desde o primeiro minuto. Ele existe para responder às perguntas caras **antes** de qualquer arte:

- a escala está certa em primeira pessoa?
- quanto tempo leva ir do hall ao subsolo, andando e correndo?
- a jogadora vê a porta da sala de controle ao entrar no corredor?
- a Presença consegue chegar aqui pela NavMesh, e a jogadora consegue fugir?

O blockout só é útil se for **rápido de mudar**. Por isso ele usa um *kit* de peças modulares num grid fixo, e não modelos únicos. Um kit mínimo para a Vigília:

| Peça | Dimensão | Uso |
|---|---|---|
| `SM_BK_Piso_100` | 100 × 100 × 10 cm | Pisos, em grid de 100 |
| `SM_BK_Parede_100` | 100 × 20 × 300 cm | Paredes de pé-direito padrão |
| `SM_BK_Porta_100x220` | vão de 100 × 220 | Portas comuns |
| `SM_BK_Escada_18x28` | degrau de 18 × 28 cm | Escadas (12 degraus por lance de ~2,2 m) |
| `SM_BK_Grade_100` | 100 × 100 × 5 cm | Passarelas metálicas (material físico `PM_Metal`, Cap. 17) |
| `SM_BK_Cobertura_100` | 100 × 40 × 100 cm | Cobertura baixa (agachada) para o trecho dos vigias |

E uma convenção de cor nos materiais, para o nível ser legível de relance: cinza para estrutura (`MI_BK_Neutro`), amarelo para o que pode ser usado (`MI_BK_Interativo`), vermelho para gates (`MI_BK_Bloqueio`), verde para zonas seguras (`MI_BK_Seguro`) e roxo para o território da Presença (`MI_BK_Ameaca`). O amarelo some na arte final, mas a pergunta que ele faz ("a jogadora sabe que isto é usável?") continua, e é respondida pelas *affordances* da seção 50.3.

### Métricas da Vigília

O Capítulo 7 deu métricas genéricas de escala humana. Um jogo precisa das **suas**: elas vêm dos sistemas que você já construiu, e é isso que faz o level design ser engenharia e não decoração.

```text
VIGÍLIA — MÉTRICAS DE NÍVEL (v1, docs/design/metricas.md)

CORPOS (Caps. 17 e 35)
  Jogadora (agente Humano) ........ cápsula raio 34, altura 176 cm
  Presença (agente Presenca) ...... cápsula raio 28, altura 210 cm
  Vão de porta para a Presença .... ≥ 220 cm de altura (ela se curva abaixo disso: Cap. 53)

INTERAÇÃO (Cap. 19)
  Alcance de interação ............ 220 cm a partir da câmera
  Altura de objetos usáveis ....... 80–160 cm (abaixo de 60 cm, a jogadora não olha)

LUZ E VISÃO (Caps. 36 e 51)
  Visão da Presença (teto) ........ 30 m, lanterna acesa; o escuro atenua
  Alcance útil da lanterna ........ ~12–15 m (o feixe ilumina; além disso, só sugere)
  Raio de uma zona segura ......... 4–6 m (o sinalizador cria ~6 m por 8 s)

ESPAÇOS
  Corredor de serviço ............. 120–140 cm (fila indiana; a Presença passa raspando)
  Corredor principal .............. 200–240 cm × pé-direito 300 cm
  Passarela ....................... 100–120 cm, guarda-corpo 110 cm
  Sala pequena (vestiário) ........ ~5 × 6 m; sala média (controle) ~8 × 12 m

RUÍDO (Cap. 36)
  Grade metálica ×1,6; concreto ×1,0; borracha/carpete ×0,5
  → material de piso é decisão de level design, não de arte

TEMPOS (medir no blockout, com o perfil Vigília do Cap. 25)
  Travessia de um espaço andando .. 8–20 s
  Distância segura de fuga ........ da posição de susto até luz/porta: ≤ 6 s correndo
```

Cada linha liga um número a um sistema. Se a visão da Presença mudar no Capítulo 80, o documento diz que corredores e pátios precisam ser revistos.

> 🌉 **Ponte:** métricas de nível são os ***design tokens*** de um *design system*: valores nomeados, derivados de restrições reais, que todos os espaços usam. Mudar um token é uma decisão global com impacto conhecido.
>
> 🧱 **Onde a ponte cai:** uma métrica de nível muda, ao mesmo tempo, a IA (NavMesh), a percepção (linhas de visão), o áudio (ruído do piso) e o ritmo (travessia): um token com efeitos colaterais em quatro sistemas.

### Medir, não achar

Duas medições substituem a maior parte das opiniões sobre um blockout: **cronometrar travessias** (um "respiro" atravessado em 4 s não é respiro; um corredor de tensão de 40 s vira tédio) e **ver a NavMesh dos dois agentes** (`show navigation`, Cap. 35): um espaço que a Presença não alcança é seguro **por acidente**, e acidentes não entram no ritmo.

---

## 50.3 Guiar sem setas

A Vigília não tem marcador de objetivo no mundo nem bússola. O diário (Cap. 45) diz **o que** fazer em texto; o espaço diz **para onde**. É uma decisão de pilar: a usina é o documento (Cap. 76), e uma seta flutuante transformaria a investigação em entrega de pacotes.

Guiar sem setas usa cinco ferramentas, e elas funcionam melhor combinadas.

**1. Luz.** O olho vai para onde há contraste. Uma porta iluminada num corredor escuro é um convite. Na Vigília, porém, a luz tem dois significados: **segurança** (zonas seguras) e **atenção** (algo importante). O Capítulo 51 trata dessa ambiguidade; aqui fica a regra de nível: **a luz que guia não pode mentir sobre segurança**. Uma luz de destaque fraca e quente sobre o livro de ocorrências é atenção; a luz de emergência estável do hall é segurança. As duas não podem ser confundidas.

**2. Som.** O som atravessa paredes e esquinas onde a luz não chega. O zumbido elétrico que cresce perto da escada, o gotejar que vem do subsolo, o rádio chiando na mesa de Moraes: cada um diz "há algo ali" sem dizer o quê. O Capítulo 52 os implementa; o documento de nível diz **onde** eles ficam.

**3. *Landmarks*.** Um ***landmark*** é um elemento único e visível de vários pontos, que orienta: "a janela grande fica do lado da sala de controle". Num espaço de corredores parecidos, sem landmarks, a jogadora se perde em dois minutos. Na Casa de Força, a janela da sala de controle para o salão das turbinas é o landmark principal: ela é vista do corredor por uma porta de vidro aramado, e a turbina 3 girando lá embaixo é o motivo do jogo inteiro.

**4. *Affordances*.** Uma ***affordance*** é a qualidade de um objeto que comunica o que se pode fazer com ele (o termo vem da psicologia da percepção, com James J. Gibson, e foi levado ao design por Don Norman). Na prática de nível:

| O que comunicar | Affordance na Vigília |
|---|---|
| "Esta porta abre" | Maçaneta, frestas de luz, porta entreaberta |
| "Esta porta está trancada" | Corrente, cadeado, luz vermelha no painel de acesso |
| "Esta porta precisa de energia" | Painel apagado ao lado, cabo cortado à vista, a mesma luz que acende quando o setor é energizado |
| "Isto é usável" | Objetos usáveis numa altura de 80–160 cm, destacados contra o fundo; o contorno de interação (Cap. 19) como confirmação, não como descoberta |
| "Não dá para passar por aqui" | Entulho alto, grade fechada; nunca uma parede invisível |

**5. Enquadramento e linhas guia.** Corrimãos, cabos no teto e fileiras de luminárias criam linhas que o olho segue; uma porta no fim de uma dessas linhas é mais visível que a mesma porta numa parede lisa.

E uma técnica de reforço, os ***breadcrumbs***: baterias e cartuchos ficam **no caminho**, ou a um passo dele; quem se desvia encontra documentos opcionais, que recompensam a curiosidade sem punir quem não a teve.

> 🌉 **Ponte:** é o que a arquitetura de informação chama de *information scent*: a pessoa segue pistas de que está no caminho certo, e abandona o caminho quando o "cheiro" enfraquece. Um nível bem guiado mantém o cheiro forte no caminho crítico.
>
> 🧱 **Onde a ponte cai:** no terror, você às vezes **quer** que o cheiro enfraqueça. Um trecho de desorientação controlada (o subsolo escuro, de corredores iguais) é assustador justamente porque a jogadora não sabe para onde vai. A regra é que a desorientação seja **curta e cercada**: ela termina num landmark (a escada, a luz do quadro de disjuntores), e nunca dura até a frustração.

### O teste do primeiro olhar

Para cada entrada de espaço, responda no documento de nível: **quando a jogadora entra aqui, o que ela vê primeiro?** (câmera na altura dos olhos, na porta, olhando para a frente). "Uma parede" significa que o espaço não guia; "a porta trancada com a luz vermelha" significa que guia.

---

## 50.4 Gating e pacing espacial

### Gates

Um ***gate*** é tudo o que impede o avanço até que uma condição seja satisfeita. Há gates duros e gates moles:

| Tipo | Exemplo | Como se abre | Na Vigília |
|---|---|---|---|
| **Chave** (duro) | Porta trancada | Um item ou fato | Sala do engenheiro: chave do armário (`RequiredTag`, Cap. 19) |
| **Energia** (duro) | Porta sem energia | Estado do mundo | Sala de controle: setor energizado (Caps. 23–24) |
| **Conhecimento** (duro, invisível) | Puzzle cuja solução está num documento | Ler e entender | A ordem dos disjuntores, no livro de ocorrências |
| **Ameaça** (mole) | Área patrulhada | Coragem, recursos, timing | Território da Presença; o pátio dos vigias |
| **Escuridão** (mole) | Trecho sem luz | Bateria, sinalizador | O subsolo |
| **Ruído** (mole) | Piso de grade | Ir devagar | As passarelas sobre o poço |

Gates duros organizam a **ordem**; gates moles organizam a **tensão**. Um nível só com gates duros vira uma lista de tarefas ("ache a chave, abra a porta"). Um nível só com gates moles não tem estrutura. A Casa de Força mistura os dois: a sala de controle exige energia (duro), e o caminho até a energia passa pelo escuro e pela grade metálica (moles).

### O grafo de dependências

Gates formam um **grafo de dependências**: para abrir B, é preciso ter A. Desenhá-lo antes de construir pega dois erros clássicos, o ***softlock*** (a jogadora fica presa sem como abrir o próximo gate, por exemplo porque usou a chave errada num lugar sem volta) e o atalho acidental (um gate contornável que pula metade do setor).

```text
 SETOR 1 — GRAFO DE GATES

   [Hall] ──► [Corredor] ──► [Vestiário] ──(livro: conhecimento)────────────┐
                 │               └──(chave)──► [Sala do engenheiro] (opcional)
                 │                                                          │
                 ├──► [Porta da sala de controle] ✖ (energia)               │
                 │                                                          ▼
                 └──► [Escada] ──► [Subsolo] ──(escuro, grade)──► [Puzzle] ◄┘
                                                                    │
                                          energia ◄─────────────────┘
                                             │
                   [Porta da sala de controle] ✔ ──► [Sala de controle] ──► final
```

A jogadora pode chegar ao puzzle **sem** ter lido o livro (Cap. 45, a variante de Sônia "procura o livro de ocorrências"), e o gate de conhecimento é mole de propósito: a tentativa e erro funciona, e a falha custa tempo no escuro. Um gate de conhecimento duro seria *softlock* para quem não achou o livro.

> 🌉 **Ponte:** é um **DAG** de dependências, como o de um sistema de build ou de *migrations*. A ordem em que a jogadora pode completar o setor é uma ordenação topológica desse grafo, e um ciclo é um *softlock*.
>
> 🧱 **Onde a ponte cai:** no build, você quer **uma** ordem determinística. No nível, a liberdade de ordem (várias ordenações válidas) é agência, e o design escolhe deliberadamente quanta liberdade dar. O Capítulo 45 chamou isso de "ordem obrigatória × livre".

### Laços, atalhos e válvulas

Três padrões de topologia aparecem em quase todo nível bem feito:

- **Laço** (*loop*): o caminho volta ao ponto de partida por outro trajeto. É essencial para perseguições (a jogadora dá a volta) e reduz o tédio de voltar pelo mesmo lugar.
- **Atalho** (*shortcut*): uma passagem que se abre **de dentro** depois de um trecho difícil (uma porta que só destranca de um lado), ligando o fim do trecho de volta ao ponto seguro. Recompensa o esforço e encurta o retorno.
- **Válvula** (*one-way valve*): uma passagem de mão única (um salto para baixo, uma porta que fecha atrás). **Compromete** a jogadora com o caminho à frente; é poderosa e perigosa, porque cria *softlocks* se houver gates atrás dela.

Na Casa de Força, o caminho de volta do subsolo **é** o de ida, e é por isso que o susto do beat 6 funciona: ali, a repetição não é tédio, é preparação.

### Pacing espacial

O ritmo de um nível vem da alternância entre **compressão** (espaços estreitos, baixos, escuros, com linhas de visão curtas: a jogadora vai devagar e escuta mais) e **alívio** (espaços amplos, altos, iluminados, com uma vista: ela respira e se orienta). A passagem de um para o outro é, em si, um evento: do hall iluminado para o corredor longo é compressão; do subsolo estreito para o quadro de disjuntores iluminado é alívio.

A curva de tensão do Interlúdio I pode ser **desenhada sobre o mapa**: cada espaço recebe a intensidade que deve produzir (hall baixa, corredor média, subsolo alta, puzzle média, corredor na volta máxima, sala de controle baixa), e a sequência de espaços do caminho crítico reproduz a curva. Esse **mapa de tensão** liga o documento de narrativa (Cap. 43) ao nível e orienta o Diretor (Cap. 42): nos espaços de alívio ele fica em `Relax`; nos de compressão, **pode** subir para `BuildUp`.

---

## 50.5 Espaços de horror

O terror em primeira pessoa depende do espaço mais do que qualquer outro gênero, porque a ameaça mais eficiente é a que a jogadora **imagina**. O espaço é a máquina de fazer imaginar. Seis princípios, todos com aplicação direta na Vigília.

### 1. A curva do corredor

O corredor principal da Casa de Força tem uma curva, e a curva é a peça mais importante do setor 1. Uma reta mostra o fim; uma curva o **promete**. Enquanto a jogadora anda, a parte invisível do corredor é preenchida pela imaginação, e a imaginação do medo é sempre pior que o que está lá.

A geometria da curva tem métricas próprias:

```text
 A CURVA DO CORREDOR (planta)

   hall                                         ┌── a silhueta (beat 6)
    │                                           │   aparece a ~16 m da jogadora:
    ▼                                           ▼   além do alcance útil da lanterna,
  ══════════════════════════╗                   ●   dentro da visão da Presença
                            ║     ╲
          ponto de virada ► ║  ◄── ╲── a jogadora só vê o fim do corredor
          (gatilho do susto)║       ╲   DEPOIS de passar pela curva
                            ╚═══════════════════════════════  (para a escada)

   - Curva de ~90°, com a parede interna cega (sem portas): nada distrai o olhar.
   - Antes da curva, linha de visão ≤ 8 m; depois, ~18 m de reta até o fim.
   - O fim fica na borda da luz: a lanterna mostra o chão até ~12 m e
     só sugere o que está além.
```

O gatilho do susto (Cap. 47, condicionado a fatos) fica **no ponto de virada**: no instante em que a reta se revela. A silhueta não está "lá desde sempre": ela aparece quando a jogadora pode vê-la. E a distância de ~16 m foi escolhida pela métrica da lanterna: perto o bastante para ser vista, longe o bastante para não ser **iluminada**. Uma silhueta iluminada é um boneco; uma silhueta na borda da luz é uma pergunta.

### 2. Linhas de visão e oclusão

Tudo que a jogadora vê é informação; tudo que ela não vê é ameaça potencial. Controlar linhas de visão é controlar o que ela sabe. Pilares, portas entreabertas, caixas empilhadas e curvas criam ***oclusão*** deliberada: lugares onde algo **poderia** estar. Mas oclusão demais vira poluição: se tudo esconde, nada esconde. Na Vigília, cada espaço tem **um** ponto de oclusão principal, escolhido no documento de nível.

### 3. Verticalidade

Olhar para baixo de uma passarela, ou para cima de um poço, produz uma vulnerabilidade que corredores planos não produzem. O Salão das Turbinas (setor 3) será quase todo vertical, e isso cria uma pergunta de IA: a Presença sobe escadas? A NavMesh responde (Cap. 35); o level design decide se a resposta é a que você quer.

### 4. Beco sem saída, rota de fuga

O medo de ser encurralado é um dos mais fortes, e um dos mais fáceis de transformar em frustração. A regra da Vigília: **nenhum espaço de ameaça sistêmica (Presença caçando) sem rota de fuga**. Becos existem, mas em espaços onde a Presença não caça (territórios de `Relax` do Diretor) ou com uma luz no fundo (uma zona segura). Um beco com luz é um refúgio; um beco escuro com a Presença atrás é morte sem escolha, e morte sem escolha é injusta (Cap. 21).

### 5. O familiar que estranha

Um espaço revisitado depois de uma mudança de estado assusta mais do que um espaço novo; o corredor do susto funciona porque é a terceira passagem. O `UVGFactGateComponent` (Cap. 47) e os setores energizados (Caps. 23–24) são as ferramentas, e o documento de nível registra o "antes e depois" de cada espaço.

### 6. Perseguição: o espaço que a fuga exige

A spec pede uma sequência de perseguição, e o Capítulo 76 a colocou no setor 3 ("a fuga pelas passarelas"). Uma perseguição é um problema de level design antes de ser um problema de IA. O espaço precisa de:

- **um laço**, para a jogadora poder dar a volta se errar;
- **uma porta que ela possa fechar** (as portas fechadas bloqueiam a Presença pela NavMesh, Cap. 35: é a regra que torna a fuga legível);
- **um destino iluminado** (uma zona segura), visível antes de ser alcançado, para dar direção à fuga;
- **leituras rápidas**: na correria, a jogadora não procura, ela reconhece. Portas de fuga com a mesma *affordance* (a mesma luz verde de emergência) em todo o trecho;
- **tempo medido**: do início da perseguição à luz, com a velocidade da jogadora correndo e a da Presença caçando, sem estamina (decisão firmada) e com o custo da corrida sendo o ruído.

> 🌉 **Ponte:** desenhar um espaço de horror se parece com desenhar o **modo de falha** de um sistema: você decide antecipadamente onde a pressão aparece e garante que existe uma rota de recuperação (a rota de fuga) para cada falha.
>
> 🧱 **Onde a ponte cai:** num sistema, a pressão é indesejada e a recuperação deve ser automática. No terror, a pressão é o produto, e a recuperação precisa **custar**: a jogadora deve sentir que escapou por pouco, não que o sistema a salvou.

---

## 50.6 O documento de nível

O Capítulo 48 prometeu: cada vinheta tem uma **frase de intenção** no documento de nível. O documento é onde todas as decisões deste capítulo ficam registradas, por espaço, numa página curta cada. Ele é para o level designer o que o documento de combate (Cap. 21) é para o combate: a referência que um playtest confirma ou derruba.

A frase de intenção é a parte mais importante, e a mais difícil de escrever. Ela diz **o que a jogadora deve sentir ou entender** naquele espaço, e não o que o espaço contém. "Aqui há armários e um banco" é inventário. "Aqui, a jogadora deve sentir que seis pessoas saíram deste lugar numa noite comum e não voltaram" é intenção. A intenção decide o que entra e o que sobra: um objeto que não serve à frase é corte.

```text
 VIGÍLIA — DOCUMENTO DE NÍVEL — L_CasaDeForca (setor 1)
 docs/design/niveis/S1-casa-de-forca.md

 S1-03  CORREDOR PRINCIPAL
 INTENÇÃO     "Na ida, um lugar de passagem que só incomoda; na volta,
               o lugar onde ela descobre que não está sozinha."
 BEATS        5 (a porta sem energia), 6 (o susto, na volta)
 MÉTRICAS     2,2 × 3,0 m; 34 m de comprimento; curva de 90° a 14 m do hall.
              Travessia: 11 s andando, 5 s correndo.
 PRIMEIRO     Do hall: a porta da sala de controle com a luz vermelha (gate).
 OLHAR        Da escada (volta): a curva, escura.
 GATES        Porta da sala de controle: energia (Sector.S1.ControlRoom).
 LUZ          4 luminárias com flicker; nenhuma zona segura. A luz do hall é visível
              da curva (destino de fuga). Cascata do susto: fundo → frente (Cap. 49).
 SOM          Zumbido elétrico que PARA 1 s antes do susto (Cap. 52).
 NARRATIVA    Vinheta "As luminárias": lâmpadas quebradas em sequência (Cap. 48).
 AMEAÇA       Só cenografia (silhueta a ~16 m). Diretor travado em Relax no setor 1.
 ANTES/DEPOIS Depois da energia: as 4 luminárias acendem estáveis; a cascata
              do susto acontece com elas acesas (o susto é a luz que "anda").
 RISCOS       A jogadora corre no corredor e passa da curva rápido demais
              para ver a silhueta → medir; considerar desacelerar com som.
```

O documento tem ainda, por setor, o **grafo de gates** (seção 50.4) e o **mapa de tensão**: uma página e meia para o setor 1 inteiro. Mais que isso, ninguém relê.

> 🌉 **Ponte:** a frase de intenção é um **critério de aceitação** escrito antes da implementação: "dado que a jogadora volta do subsolo, quando passa pela curva, então percebe que não está sozinha". O playtest é o teste de aceitação.
>
> 🧱 **Onde a ponte cai:** a intenção de um espaço só é verificável perguntando a uma pessoa, **depois**, o que ela sentiu, e as respostas variam. O playtest mede a distância entre a intenção e o que as pessoas viveram.

---

## Estudos de caso

### Alan Wake — a luz como mapa de ritmo

**[FATO PÚBLICO, observável jogando]** Em *Alan Wake* (Remedy, 2010), boa parte do jogo é atravessar florestas e cidades à noite, perseguido pelos Taken. Ao longo do caminho há postes e holofotes que funcionam como **refúgios** (*safe havens*): sob essas luzes, os inimigos se dissolvem ou não entram, e a vida de Alan se recupera. Muitos deles também funcionam como pontos de *checkpoint*.

**[INFERÊNCIA]** As luzes são, ao mesmo tempo, **gate mole**, **pacing** e **orientação**: o próximo refúgio, visto de longe, é o objetivo imediato, o landmark e a promessa de alívio. O nível se lê como "corridas de luz em luz", e a distância entre refúgios regula a tensão.

**Lição para a Vigília:** a distância entre zonas seguras, medida em segundos de corrida, é uma métrica de nível; e a regra "só é seguro onde há luz" (que o Capítulo 51 garante por construção) é o que torna a orientação confiável.

### Control — o prédio que se abre

**[FATO PÚBLICO, observável jogando]** Em *Control* (Remedy, 2019), a Oldest House é um prédio interconectado, explorado em parte de forma não linear. Áreas se abrem conforme a protagonista obtém novas habilidades (como a levitação) e níveis de autorização que destrancam portas. Os *Control Points*, depois de purificados, servem como pontos de viagem rápida e de retorno.

**[INFERÊNCIA]** Os gates são de dois tipos sobrepostos: **autorização** (a chave clássica, tematizada como burocracia, o que reforça o mundo) e **habilidade** (o padrão dos *metroidvanias*). Os *Control Points* são **atalhos** que barateiam a volta a espaços já vistos, e a revisita é o que permite ao familiar voltar estranho.

**Lição para a Vigília:** gates tematizados contam o mundo. "A sala de controle precisa de energia" é a usina explicando como funciona; e os setores energizados devem **mudar** os espaços já vistos.

### Outlast — o espaço da fuga

**[FATO PÚBLICO, observável jogando]** Em *Outlast* (Red Barrels, 2013), o protagonista não pode lutar; ele corre, se esconde em armários e debaixo de camas e observa pela câmera. Há trechos em que é preciso ativar mais de um mecanismo numa área patrulhada por um perseguidor.

**[INFERÊNCIA]** Esses trechos são **arenas de furtividade**: um espaço fechado com laços (para despistar), esconderijos (para quebrar a perseguição) e objetivos espalhados (para obrigar a cruzar o território do perseguidor várias vezes). A tensão vem da topologia.

**Lição para a Vigília:** a perseguição do setor 3 e o território da Presença no setor 2 são arenas desse tipo, com zonas seguras e portas no lugar dos esconderijos, e o blockout deve ser testado **com a IA ligada** desde o começo.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Blockout | *Wireframe*, protótipo de baixa fidelidade | O blockout é **jogável** e mede tempo e IA; o wireframe é estático |
| Métricas de nível | *Design tokens* | Uma métrica muda IA, percepção, áudio e ritmo ao mesmo tempo |
| Guiar sem setas | *Information scent*, *affordances* de UX | No terror, a desorientação curta e cercada é desejada |
| Grafo de gates | DAG de dependências, ordenação topológica | A liberdade de ordem é agência; um ciclo é um *softlock* |
| Documento de nível | Spec com critérios de aceitação | A aceitação é medida em pessoas, depois, e varia |
| Ator de puzzle reutilizável | Componente de UI reutilizável | Cada instância é configurada à mão, e o puzzle tem de **parecer** único |

---

## Unreal Engine: o que existe

- **Modeling Mode** (UE5): ferramentas de modelagem dentro do editor, incluindo o *CubeGrid*, que constrói geometria em blocos sobre um grid, útil para blockout rápido. ⚠️ Os nomes e a disposição das ferramentas mudaram entre versões do UE5; confira na sua.
- **BSP / Geometry Brushes**: a ferramenta clássica de blockout, ainda presente; converta para malhas estáticas quando o espaço se estabilizar.
- **Grid, *snapping* e medição**: o snap de posição (10/50/100) é a garantia física das métricas; em viewports ortográficos, arrastar com o botão do meio mede distâncias.
- **`ANote`**: um ator nativo, só de editor, que guarda um texto no nível. Serve para anotar intenções e riscos **no lugar**, ao lado do espaço. Ele já existe; não crie outro.
- **Level Instances e Packed Level Actors** (Cap. 48): agrupam peças em módulos reutilizáveis, para vinhetas e trechos repetidos de arquitetura.
- **Navegação**: `show navigation` e a cor das áreas (Cap. 35). Teste os dois agentes em todo blockout.
- **Níveis separados × World Partition**: a Vigília é uma sequência de espaços fechados, um nível por setor (`L_Patio`, `L_CasaDeForca`, `L_Subestacao`, `L_Turbinas`, `L_Final`). World Partition foi pensado para mundos grandes e contínuos (Interlúdio II e Cap. 60). ⚠️ O template de um projeto novo pode criar mapas com World Partition ligado; para níveis pequenos e fechados, avalie desligá-lo.

O que a engine **não** oferece: um conceito de "puzzle". Há atores, interfaces e eventos; o puzzle é seu.

---

## Abordagens: o puzzle dos disjuntores

| Critério | A. Level Blueprint (atual) | B. Blueprint de ator (`BP_PuzzleDisjuntores`) | **C. Ator C++ genérico + configuração na instância** | D. Puzzle como dado (grafo em Data Asset) |
|---|---|---|---|---|
| **Complexidade** | Baixa no começo, cresce com cada caso | Baixa | Média | Alta |
| **Reuso no setor 2** | Copiar e colar o grafo | Sim, se for genérico | **Sim** | Sim |
| **Teste automatizado** | Não | Difícil | **Regra pura testada** | Sim |
| **Reentrância** (disjuntores mudando durante o reset) | Fácil de errar | Fácil de errar | **Resolvida uma vez** | Resolvida uma vez |
| **Prototipação** de um puzzle diferente | Rápida | Rápida | Média (feedback em Blueprint) | Lenta |
| **Adequação à Vigília** (3 puzzles no jogo inteiro) | Foi a dor | Possível | **Sim** | Excesso: é o "ERP para uma porta" |

**Decisão: C.** Um `AVGSequencePuzzle` em C++, com a regra pura testada (`VGPuzzleRules`) e o feedback (som, flicker) em Blueprint. A sequência é configurada na instância, arrastando os disjuntores para uma lista **na ordem certa**. A opção D seria a escolha num jogo com dezenas de puzzles variados; com três, um grafo de puzzle em dados é a arquitetura de um problema que a Vigília não tem.

---

## Implementação

### 1. A regra pura

```cpp
// Source/Vigilia/World/VGPuzzleRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGPuzzleRules
{
    enum class EStep : uint8
    {
        Ignore,   // a mudança não conta (ex.: desligar uma alavanca que ainda não contava)
        Advance,  // a alavanca certa, na hora certa
        Complete, // a última alavanca certa
        Fail      // fora de ordem, ou desligou uma que já contava
    };

    /**
     * Puzzle de sequência: as alavancas devem ser ligadas na ordem 0, 1, ..., Count-1.
     * Progress = quantas já foram ligadas corretamente. ToggledIndex = qual alavanca mudou.
     */
    EStep Evaluate(int32 Progress, int32 Count, int32 ToggledIndex, bool bNowOn);
}
```

```cpp
// Source/Vigilia/World/VGPuzzleRules.cpp
#include "World/VGPuzzleRules.h"

VGPuzzleRules::EStep VGPuzzleRules::Evaluate(int32 Progress, int32 Count, int32 ToggledIndex, bool bNowOn)
{
    if (ToggledIndex < 0 || ToggledIndex >= Count || Progress >= Count)
    {
        return EStep::Ignore;
    }
    if (!bNowOn)
    {
        // Desligar uma alavanca que já fazia parte da sequência desfaz o progresso.
        return ToggledIndex < Progress ? EStep::Fail : EStep::Ignore;
    }
    if (ToggledIndex != Progress)
    {
        return EStep::Fail;
    }
    return Progress + 1 == Count ? EStep::Complete : EStep::Advance;
}
```

### 2. Tags e os retoques nos atores existentes

```cpp
// VGGameplayTags.h (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Puzzle_Solved);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Puzzle_Failed);

// VGGameplayTags.cpp (adições)
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Puzzle_Solved, "Event.Puzzle.Solved");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Puzzle_Failed, "Event.Puzzle.Failed");
```

Tags de conteúdo, registradas em `docs/design/tags.md`: `Puzzle.S1.Breakers` e, para o setor 2, `Puzzle.S2.Disconnectors`.

🔁 **Dois retoques pequenos em classes antigas.**

O `AVGBreakerSwitch` (Cap. 19) ganha uma trava. **Antes**, só o `bOneWay` impedia desligar. **O problema:** depois de resolvido o puzzle, a jogadora podia desligar um disjuntor, e o setor continuaria energizado com a alavanca para baixo, uma mentira visual. **Agora**, quem controla o disjuntor pode travá-lo:

```cpp
// VGBreakerSwitch.h (adições)
public:
    /** Travado: não aceita interação (o estado continua o mesmo). Usado por puzzles resolvidos. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Breaker")
    void SetLocked(bool bNewLocked) { bLocked = bNewLocked; }

private:
    bool bLocked = false;

// VGBreakerSwitch.cpp: CanInteract_Implementation passa a começar por
//     if (bLocked) { return false; }
```

O `AVGSector` (desafio dos Caps. 23–24) ganha uma operação pública. **Antes**, o setor só se energizava no `OnToggled` do disjuntor principal, e o puzzle não tinha como energizá-lo sem fingir ser um disjuntor. **Agora**, a lógica que estava no handler vira uma função; o handler do disjuntor passa a chamá-la, e o disjuntor principal fica opcional:

```cpp
// VGSector.h (adição)
    /** Energiza ou desenergiza o setor: concede/revoga World.Sector.Powered e publica Event.Sector.Powered. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Sector")
    void SetPowered(bool bNewPowered);
```

O *trade-off* é pequeno: o setor passa a ter dois caminhos de entrada (disjuntor e chamada direta), mas os dois convergem para a mesma função, que é a dona da regra. Se o seu `AVGSector` do desafio usa outro nome para essa lógica, mantenha o seu e exponha-o.

### 3. O ator de puzzle

```cpp
// Source/Vigilia/World/VGSequencePuzzle.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameplayTagContainer.h"
#include "VGSequencePuzzle.generated.h"

class AVGBreakerSwitch;
class AVGSector;

UENUM(BlueprintType)
enum class EVGPuzzleFeedback : uint8
{
    Advanced,
    Failed,
    Reset,
    Solved
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FVGPuzzleSolvedSignature);

/**
 * Puzzle de sequência: ligar as alavancas na ordem da lista. Errar desfaz tudo depois de um atraso.
 * Lógica em C++ (VGPuzzleRules, testada); feedback (som, flicker, falas) em Blueprint.
 * Relógio: tempo de jogo (o atraso do reset dilata com o hitstop e para com a pausa).
 */
UCLASS()
class VIGILIA_API AVGSequencePuzzle : public AActor
{
    GENERATED_BODY()

public:
    AVGSequencePuzzle();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Puzzle")
    bool IsSolved() const { return bSolved; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Puzzle")
    FGameplayTag GetPuzzleTag() const { return PuzzleTag; }

    /**
     * Resolve sem a jogadora: cheat (bAnnounce = true, a história avança)
     * ou restauração de estado (bAnnounce = false, Cap. 57).
     */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Puzzle")
    void ForceSolve(bool bAnnounce);

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Puzzle")
    FVGPuzzleSolvedSignature OnSolved;

#if WITH_EDITOR
    virtual EDataValidationResult IsDataValid(class FDataValidationContext& Context) const override;
#endif

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    /** Feedback de apresentação: som do desarme, flicker do subsolo, clique de avanço. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Puzzle")
    void OnPuzzleFeedback(EVGPuzzleFeedback Feedback, int32 NewProgress);

    /** As alavancas, NA ORDEM CORRETA. A ordem da lista é a solução. */
    UPROPERTY(EditInstanceOnly, Category = "Vigilia|Puzzle")
    TArray<TObjectPtr<AVGBreakerSwitch>> Sequence;

    UPROPERTY(EditInstanceOnly, Category = "Vigilia|Puzzle", meta = (Categories = "Puzzle"))
    FGameplayTag PuzzleTag;

    /** Opcional: o setor energizado ao resolver. */
    UPROPERTY(EditInstanceOnly, Category = "Vigilia|Puzzle")
    TObjectPtr<AVGSector> PoweredSector;

    /** Tempo entre o erro e o desarme: a jogadora precisa VER e OUVIR que errou. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Puzzle", meta = (ClampMin = "0.0"))
    float FailResetDelay = 0.8f;

private:
    UFUNCTION()
    void HandleToggled(AVGBreakerSwitch* Switch, bool bIsOn);

    void ResetSwitches();
    void Solve(bool bAnnounce);

    int32 Progress = 0;
    bool bSolved = false;
    bool bResetting = false; // ignora as mudanças que o próprio reset provoca
    FTimerHandle ResetTimer;
};
```

```cpp
// Source/Vigilia/World/VGSequencePuzzle.cpp
#include "World/VGSequencePuzzle.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGLog.h"
#include "Interaction/VGBreakerSwitch.h"
#include "TimerManager.h"
#include "World/VGPuzzleRules.h"
#include "World/VGSector.h"

#if WITH_EDITOR
#include "Misc/DataValidation.h"
#endif

AVGSequencePuzzle::AVGSequencePuzzle()
{
    PrimaryActorTick.bCanEverTick = false;
    SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("Root")));
}

void AVGSequencePuzzle::BeginPlay()
{
    Super::BeginPlay();
    for (AVGBreakerSwitch* Switch : Sequence)
    {
        if (ensureMsgf(Switch, TEXT("%s: alavanca vazia na sequência"), *GetName()))
        {
            Switch->OnToggled.AddDynamic(this, &AVGSequencePuzzle::HandleToggled);
        }
    }
}

void AVGSequencePuzzle::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearTimer(ResetTimer);
    for (AVGBreakerSwitch* Switch : Sequence)
    {
        if (Switch)
        {
            Switch->OnToggled.RemoveDynamic(this, &AVGSequencePuzzle::HandleToggled);
        }
    }
    Super::EndPlay(EndPlayReason);
}

void AVGSequencePuzzle::HandleToggled(AVGBreakerSwitch* Switch, bool bIsOn)
{
    if (bSolved || bResetting)
    {
        return;
    }
    const int32 Index = Sequence.IndexOfByKey(Switch);
    switch (VGPuzzleRules::Evaluate(Progress, Sequence.Num(), Index, bIsOn))
    {
    case VGPuzzleRules::EStep::Advance:
        ++Progress;
        OnPuzzleFeedback(EVGPuzzleFeedback::Advanced, Progress);
        break;

    case VGPuzzleRules::EStep::Complete:
        Progress = Sequence.Num();
        Solve(/*bAnnounce=*/true);
        break;

    case VGPuzzleRules::EStep::Fail:
        // Não mexa nas alavancas aqui: estamos DENTRO do OnToggled de uma delas (reentrância).
        bResetting = true;
        OnPuzzleFeedback(EVGPuzzleFeedback::Failed, Progress);
        UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Puzzle_Failed, nullptr, nullptr, PuzzleTag);
        GetWorldTimerManager().SetTimer(ResetTimer, this, &AVGSequencePuzzle::ResetSwitches, FMath::Max(FailResetDelay, 0.01f));
        break;

    case VGPuzzleRules::EStep::Ignore:
        break;
    }
}

void AVGSequencePuzzle::ResetSwitches()
{
    for (AVGBreakerSwitch* Switch : Sequence)
    {
        if (Switch)
        {
            Switch->SetOn(false); // dispara OnToggled; HandleToggled ignora (bResetting)
        }
    }
    Progress = 0;
    bResetting = false;
    OnPuzzleFeedback(EVGPuzzleFeedback::Reset, Progress);
}

void AVGSequencePuzzle::ForceSolve(bool bAnnounce)
{
    if (bSolved)
    {
        return;
    }
    GetWorldTimerManager().ClearTimer(ResetTimer);
    bResetting = true; // as alavancas vão mudar por nossa causa
    for (AVGBreakerSwitch* Switch : Sequence)
    {
        if (Switch)
        {
            Switch->SetOn(true);
        }
    }
    bResetting = false;
    Progress = Sequence.Num();
    Solve(bAnnounce);
}

void AVGSequencePuzzle::Solve(bool bAnnounce)
{
    bSolved = true; // estado consistente antes dos anúncios (Cap. 4)
    for (AVGBreakerSwitch* Switch : Sequence)
    {
        if (Switch)
        {
            Switch->SetLocked(true);
        }
    }
    if (!bAnnounce)
    {
        return; // restauração: o estado do setor e dos fatos é restaurado pelos donos deles
    }
    OnPuzzleFeedback(EVGPuzzleFeedback::Solved, Progress);
    OnSolved.Broadcast();
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Puzzle_Solved, nullptr, nullptr, PuzzleTag);
    if (PoweredSector)
    {
        PoweredSector->SetPowered(true); // Event.Sector.Powered → fato S1.BreakersRestored (regra do Cap. 46)
    }
}

#if WITH_EDITOR
EDataValidationResult AVGSequencePuzzle::IsDataValid(FDataValidationContext& Context) const
{
    EDataValidationResult Result = Super::IsDataValid(Context);
    if (Sequence.Num() < 2)
    {
        Context.AddError(FText::FromString(TEXT("Puzzle de sequência precisa de pelo menos 2 alavancas.")));
        Result = EDataValidationResult::Invalid;
    }
    if (Sequence.Contains(nullptr))
    {
        Context.AddError(FText::FromString(TEXT("Há uma alavanca vazia na sequência.")));
        Result = EDataValidationResult::Invalid;
    }
    if (!PuzzleTag.IsValid())
    {
        Context.AddError(FText::FromString(TEXT("PuzzleTag vazia: o evento não identifica o puzzle.")));
        Result = EDataValidationResult::Invalid;
    }
    return Result;
}
#endif
```

> ⚠️ **Validação de atores do nível.** `IsDataValid` em atores roda quando o **nível** é validado (clique direito no mapa → validar, ou na validação ao salvar, se estiver ligada). Confira como a sua versão da engine valida atores de nível. Se não rodar, o *Map Check* (`CheckForErrors`, também só de editor) é a alternativa clássica.

Um detalhe que a validação não pega: as alavancas do puzzle precisam de `bOneWay = false` (Cap. 19); senão, o reset não as desliga e a jogadora não consegue errar e tentar de novo. Uma linha a mais no `IsDataValid`, se você tornar `bOneWay` legível por quem está de fora (exercício).

### 4. O cheat

```cpp
// VGCheatManager.h (adição)
    /** Resolve o puzzle com a tag indicada, com anúncios (a história avança). Ex.: VGSolvePuzzle Puzzle.S1.Breakers */
    UFUNCTION(Exec)
    void VGSolvePuzzle(FName PuzzleTagName);

// VGCheatManager.cpp
#include "EngineUtils.h"
#include "World/VGSequencePuzzle.h"

void UVGCheatManager::VGSolvePuzzle(FName PuzzleTagName)
{
    const FGameplayTag Tag = FGameplayTag::RequestGameplayTag(PuzzleTagName, /*ErrorIfNotFound=*/false);
    for (TActorIterator<AVGSequencePuzzle> It(GetWorld()); It; ++It)
    {
        if (It->GetPuzzleTag() == Tag)
        {
            It->ForceSolve(/*bAnnounce=*/true);
        }
    }
}
```

### 5. O teste

```cpp
// Source/Vigilia/Tests/VGPuzzleRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "World/VGPuzzleRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGPuzzleRulesTest, "Vigilia.World.Puzzle.Sequence",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGPuzzleRulesTest::RunTest(const FString& Parameters)
{
    using namespace VGPuzzleRules;
    TestTrue(TEXT("Primeira certa avança"),        Evaluate(0, 3, 0, true)  == EStep::Advance);
    TestTrue(TEXT("Fora de ordem falha"),           Evaluate(0, 3, 2, true)  == EStep::Fail);
    TestTrue(TEXT("Última certa completa"),         Evaluate(2, 3, 2, true)  == EStep::Complete);
    TestTrue(TEXT("Desligar uma que contava falha"), Evaluate(2, 3, 0, false) == EStep::Fail);
    TestTrue(TEXT("Desligar uma que não contava é ignorado"), Evaluate(1, 3, 2, false) == EStep::Ignore);
    TestTrue(TEXT("Alavanca fora da lista é ignorada"), Evaluate(0, 3, INDEX_NONE, true) == EStep::Ignore);
    TestTrue(TEXT("Depois de completo, nada conta"), Evaluate(3, 3, 0, true) == EStep::Ignore);
    return true;
}

#endif
```

### Explicação das decisões

- **A ordem da lista é a solução.** O level designer arrasta os disjuntores para `Sequence` na ordem do livro de ocorrências. Não há índice, código nem enum de "qual alavanca é qual": o dado está onde a decisão é tomada, no nível.
- **Feedback em Blueprint, regra em C++.** O som do desarme, o flicker forte do subsolo e o clique de avanço mudam a cada playtest; a regra de sequência não muda. É a regra de camadas do Capítulo 13.
- **O reset não acontece dentro da notificação.** `HandleToggled` é chamado de dentro do `OnToggled` de uma alavanca. Desligar as alavancas ali mesmo dispararia novas notificações no meio da primeira (a armadilha de reentrância do guia). O timer adia o reset, e o atraso é, por acaso, também o que o design pede: a jogadora precisa **ver** a alavanca errada subir antes de tudo desarmar.
- **`bResetting` ignora as mudanças que o próprio puzzle provoca**, tanto no reset quanto no `ForceSolve`. Sem ele, o reset geraria uma falha nova a cada alavanca desligada.
- **Resolver trava as alavancas** (`SetLocked`): o estado visual e o do setor não podem divergir.
- **`ForceSolve(false)` não anuncia nada.** Na restauração de um save, setor e fatos são restaurados pelos seus donos (Caps. 46 e 57); anunciar de novo concederia fatos e concluiria objetivos uma segunda vez.
- **Sem interface `IVGPuzzleInput`.** As entradas da Vigília são todas alavancas (`AVGBreakerSwitch` e filhos em Blueprint, como as seccionadoras do setor 2). Quando aparecer uma válvula com outro comportamento, a interface nasce.

---

## Projeto Vigília — o setor 1 com intenção, e os setores 2 e 3 em blockout

### O fim da cola de nível

🔁 O puzzle do Level Blueprint é substituído por um `AVGSequencePuzzle` no subsolo:

| Propriedade | Valor |
|---|---|
| `Sequence` | `Disj_Alimentacao`, `Disj_Excitacao`, `Disj_Sincronismo` (nesta ordem) |
| `PuzzleTag` | `Puzzle.S1.Breakers` |
| `PoweredSector` | o `AVGSector` da sala de controle (`Sector.S1.ControlRoom`) |
| `FailResetDelay` | 0,8 s |
| `OnPuzzleFeedback` (Blueprint) | `Failed`: som de desarme e o perfil `DA_Flicker_Sobrecarga` nas luminárias do subsolo; `Advanced`: clique mecânico e um ronco crescente da usina; `Solved`: nada além do que o setor faz ao energizar |

O Level Blueprint de `L_CasaDeForca` fica com uma única linha (`Start Quest`), e a **dor 12** do Interlúdio ("o Level Blueprint cresce sem controle") fecha. Nenhum consumidor mudou: a quest espera `Event.Sector.Powered`, a regra do Capítulo 46 concede `S1.BreakersRestored`, o susto é armado por esse fato. Trocar o **produtor** de um evento não exigiu tocar em nenhum **consumidor**.

### O documento de nível do setor 1

Escreva as cinco páginas de espaço do setor 1 (hall, vestiário, sala do engenheiro, corredor e subsolo; a sala de controle entra como sexta, por ser o palco do final) no formato da seção 50.6, com as quatro vinhetas do Capítulo 48 e suas frases de intenção. As intenções de partida:

| Espaço | Intenção |
|---|---|
| **S1-01 Hall** | "O último lugar com luz: ela deve querer voltar aqui." |
| **S1-02 Vestiário** | "Seis pessoas saíram daqui numa noite comum e não voltaram." |
| **S1-03 Corredor** | (seção 50.6) |
| **S1-04 Sala do engenheiro** | "Ele tinha medo, e sabia por quê." |
| **S1-05 Subsolo** | "Descer é se afastar de tudo: do rádio, da luz, da saída." |
| **S1-06 Sala de controle** | "A recompensa é ver, e o que ela vê é pior que o escuro." |

E três ajustes de blockout que o documento deve justificar, com as métricas da seção 50.2:

1. **A curva do corredor** com as medidas da seção 50.5: linha de visão ≤ 8 m antes, ~18 m depois, silhueta a ~16 m.
2. **O piso do subsolo** em grade metálica (`PM_Metal`, ruído ×1,6) nas passarelas e em concreto no corredor estreito. O som dos próprios passos muda quando ela pisa a grade: é o espaço avisando que ali ela é ouvida.
3. **A porta de vidro aramado** entre o corredor e a sala de controle: a janela para o salão das turbinas vira o landmark do setor, visível (mas inacessível) desde o beat 5.

### Setor 2 — Subestação (blockout)

O Capítulo 76 definiu o setor 2: seis espaços; objetivo "restabelecer a linha até o salão das turbinas"; a escolha entre seguir Sônia ou o mapa de Moraes; o único trecho de combate do jogo (os vigias) e a Presença sistêmica. A proposta de blockout:

```text
 SETOR 2 — SUBESTAÇÃO (L_Subestacao), planta esquemática

            ┌───────────────────┐
            │ S2-01 GUARITA     │◄── entrada (da Casa de Força)
            │ zona segura,      │    o mapa de Moraes na parede
            │ rádio             │
            └────────┬──────────┘
          rota de Sônia │            rota de Moraes
        ┌───────────────┴──────────────────┐
        ▼                                  ▼
 ┌──────────────────────┐        ┌──────────────────────────┐
 │ S2-02 GALERIA DE     │        │ S2-03 CASA DE COMANDO    │
 │ CABOS (subterrânea)  │        │ (documentos de Moraes;   │
 │ escura, estreita,    │        │ resposta da pergunta 3)  │
 │ território da        │        └────────────┬─────────────┘
 │ Presença             │                     │
 └──────────┬───────────┘                     │
            │      ┌──────────────────────────┴───────────────┐
            └─────►│ S2-04 PÁTIO DOS TRANSFORMADORES          │
                   │ aberto, exposto; cobertura baixa e alta; │
                   │ O ENCONTRO DOS VIGIAS (trecho único)     │
                   └──────────────────┬───────────────────────┘
                                      ▼
                   ┌──────────────────────────────────────────┐
                   │ S2-05 PÁTIO DAS SECCIONADORAS            │
                   │ AVGSequencePuzzle (Puzzle.S2.Disconnectors)│
                   └──────────────────┬───────────────────────┘
                                      ▼
                   ┌──────────────────────────────────────────┐
                   │ S2-06 PÓRTICO DA LINHA → Salão (setor 3) │
                   └──────────────────────────────────────────┘
```

Decisões de nível do setor 2, para o documento:

- **As duas rotas convergem antes do pátio dos vigias.** A escolha muda **como** se chega (o escuro com a Presença, ou os documentos de Moraes), mas o encontro acontece para todas: a convergência do Capítulo 47 aplicada ao espaço.
- **O pátio dos transformadores é o oposto do setor 1**: aberto, linhas de visão longas, ameaça que atira. A compressão vira **exposição**. Cobertura baixa a ~100 cm e alta ≥ 250 cm (Cap. 41), e a EQS de cobertura dos vigias (Cap. 39) precisa achar pontos ali.
- **A Presença não entra no pátio dos vigias** enquanto houver vigias vivos (uma trava do Diretor, Cap. 42): duas ameaças ao mesmo tempo diluem as duas.
- **As seccionadoras reutilizam o puzzle** com quatro alavancas; a ordem está nos documentos das duas rotas, com palavras diferentes, e o gate de conhecimento continua mole.

### Setor 3 — Salão das Turbinas (blockout)

Quatro espaços, a revelação pelo espaço e a perseguição ("a fuga pelas passarelas", Cap. 76):

```text
 SETOR 3 — SALÃO DAS TURBINAS (L_Turbinas), corte vertical esquemático

  +12 m  ┌─────────── S3-01 GALERIA SUPERIOR ───────────┐  ← entrada; DAQUI se vê, do outro
         │  (vista do salão inteiro; ao fundo, a janela │    lado, a janela da sala de controle
         │   da sala de controle do setor 1)            │    do setor 1: o mesmo lugar, invertido
         └──────┬───────────────────────────────┬───────┘
                │ escada                        │ escada (atalho: abre de baixo)
   +6 m  ═══════╧══ S3-02 PASSARELAS (laço) ════╧═══════   ← a perseguição: um laço em dois níveis,
                │   portas de serviço que fecham │            duas portas que bloqueiam a Presença
                │                                │
    0 m  ┌──────┴── S3-03 POÇO DA TURBINA 3 ─────┴───────┐  ← a revelação: o que o turno C fez em 1994
         │  (o fundo; os seis crachás; a turbina girando) │
         └──────────────────────┬────────────────────────┘
                                ▼
         ┌───────────── S3-04 COMANDO MANUAL ────────────┐  ← zona segura (a única do setor);
         │  (o final: desligar ou deixar girar)          │    a escolha (L_Final)
         └───────────────────────────────────────────────┘
```

Decisões de nível do setor 3:

- **A primeira imagem é a recompensa e a ameaça.** Da galeria superior, a jogadora vê o salão, a turbina 3 girando e, ao fundo, a janela de onde olhou no fim do setor 1: ela entende onde está em relação a tudo o que já viu.
- **A perseguição acontece na volta do poço.** Ela desce em silêncio (Diretor em `BuildUp`), encontra a revelação, e a Presença caça (`Peak`, Cap. 42). O destino da fuga é o comando manual, que ela **viu** lá de cima.
- **O atalho de escada abre de baixo**: trancado na descida, a saída mais curta na fuga.
- **As portas de serviço do laço bloqueiam a Presença** quando fechadas (`UVGNavArea_DoorClosed`, Cap. 35): fechar uma porta atrás de si é a ação de fuga mais legível do jogo.

O blockout jogável dos dois setores é o entregável; arte, documentos e falas são da Parte XI.

---

## Decisões arquiteturais

1. **Métricas derivadas dos sistemas**, num documento versionado.
2. **Sem marcadores no mundo**: o diário diz o quê, o espaço diz onde.
3. **Gates duros para a ordem, gates moles para a tensão**; o gate de conhecimento continua mole.
4. **Nenhum espaço de caça sem rota de fuga.**
5. **Documento de nível** com frase de intenção por espaço, grafo de gates e mapa de tensão.
6. **`AVGSequencePuzzle`** genérico em C++, com feedback em Blueprint.
7. **Um nível por setor**, sem World Partition.

---

## Armadilhas

- **Blockout bonito demais.** Quando o grey-box ganha arte cedo, ninguém quer mudá-lo, e ele deixa de ser blockout.
- **Métricas genéricas.** Um corredor "de 2 m" sem saber o raio da cápsula, o alcance da lanterna e a visão da ameaça é um palpite.
- **Testar o nível sem a IA.** A arena que funciona sem a Presença ligada é uma arena que não foi testada.
- **Luz que mente**: um destaque de atenção que parece zona segura, ou o contrário.
- **Paredes invisíveis.** Se a jogadora não pode passar, o espaço precisa dizer isso com geometria.
- **Gate de conhecimento duro**: a solução só num documento opcional, sem tentativa e erro, é *softlock* para quem não leu.
- **Válvula de mão única com um gate atrás**: a chave ficou do outro lado, para sempre.
- **Becos sem saída em território de caça.**
- **Mexer nas alavancas dentro do `OnToggled`** de uma delas (reentrância).
- **Documento de nível como inventário** ("aqui há armários"), sem intenção.

---

## Exercício

**Parte 1 — kit e métricas (1,5 h).** Monte o kit de blockout da seção 50.2 (as seis peças e os cinco materiais) e escreva `docs/design/metricas.md`. Num nível de teste (`L_Lab`), construa uma "academia de métricas": três corredores (120, 160 e 220 cm), três vãos de porta (200, 220 e 240 cm de altura) e uma passarela de grade. Atravesse cada um com a jogadora e veja a NavMesh dos dois agentes. Anote o que você sentiu em cada largura.

**Parte 2 — o puzzle (2 h).** Implemente `VGPuzzleRules`, o teste, `AVGSequencePuzzle`, os retoques em `AVGBreakerSwitch` e `AVGSector` e o cheat. Substitua o puzzle do Level Blueprint de `L_CasaDeForca`. Teste:
- a ordem certa energiza o setor, e as alavancas travam;
- uma alavanca errada desarma tudo depois de 0,8 s, e mexer nas alavancas durante esse tempo não muda nada;
- `VGSolvePuzzle Puzzle.S1.Breakers` faz a quest avançar como se a jogadora tivesse resolvido.

**Parte 3 — o documento do setor 1 (1,5 h).** Escreva as seis páginas de espaço, o grafo de gates e o mapa de tensão. Ajuste o blockout da curva do corredor com as medidas da seção 50.5 e meça as travessias.

**Parte 4 — setores 2 e 3 (3 h).** Faça o blockout de `L_Subestacao` e `L_Turbinas` com as plantas deste capítulo, gere a NavMesh e coloque uma Presença e dois vigias de teste. Jogue cada setor do começo ao fim em cinza, e escreva uma página de documento por espaço, nem que a metade das linhas diga "a definir".

**Parte 5 — playtest de orientação (1 h).** Peça a alguém que jogue o setor 1 sem explicação e anote cada hesitação de mais de 5 s, com o lugar e o que a pessoa olhava. Compare com o "primeiro olhar" do documento.

---

## Desafio — a rota da fuga

Desenhe e meça a perseguição do setor 3 antes de qualquer arte.

1. Com o perfil de movimento Vigília (Cap. 25) e a velocidade de caça da Presença (`BT_Presenca`, Cap. 37), calcule quanto tempo a jogadora tem do poço até o comando manual pela rota mais curta e pela mais longa do laço.
2. Ajuste o blockout até que: (a) a rota correta, sem erros, chegue à luz com **1 a 2 s** de folga; (b) um erro de rota (a porta esquecida aberta, a escada errada) custe o toque de aviso, mas não a morte, da regra "dois toques" (Cap. 21); (c) a jogadora que lembrar do atalho chegue com folga confortável.
3. Grave três tentativas suas e uma de outra pessoa. Registre no `DEVLOG.md`: a fuga parecia "por pouco" ou "garantida"? O laço foi usado? A porta foi fechada? Quantas vezes a pessoa olhou para trás?

O desafio não pede código novo: a perseguição é um problema de espaço e de números.

---

## Uso de IA

1. **Para revisar um documento de nível:**
   > "Aqui está a página de documento de nível de um espaço de um jogo de terror em primeira pessoa, com a frase de intenção, as métricas, a luz, o som e os gates. Aponte: (1) elementos que não servem à frase de intenção; (2) contradições entre a intenção e as métricas (por exemplo, um espaço de 'respiro' atravessado em 4 s); (3) o que a jogadora provavelmente vê primeiro ao entrar, pela descrição; (4) riscos de playtest que não estão listados. [página]"

2. **Para auditar o grafo de gates:**
   > "Este é o grafo de gates de um setor de jogo (abaixo, em texto: nós, arestas e a condição de cada aresta). Encontre: ciclos, gates que podem ser contornados por outro caminho, itens que podem ser consumidos num lugar sem volta, e a ordem mínima de ações para completar o setor. Liste as ordenações válidas que você encontrar. [grafo]"

3. **Para variar um espaço de horror:**
   > "Proponha três variações de planta para um corredor de 34 m numa casa de força desativada, onde um susto acontece na volta da jogadora. Para cada uma: onde fica a oclusão principal, a linha de visão antes e depois do ponto de virada, a distância da aparição e o que muda na sensação. Não proponha mais de um susto."

**Cuidado específico:** a IA não vê nem sente o seu espaço. Ela raciocina sobre descrições, e descrições de espaço são sempre mais limpas que o espaço jogado. Use-a para auditar a **lógica** do nível (grafos, métricas, coerência entre documento e intenção); a **sensação** só se mede jogando, com pessoas.

---

## Checklist

- [ ] Sei montar um blockout com um kit modular, em grid, com materiais que codificam função.
- [ ] As métricas da Vigília estão num documento, e cada uma aponta o sistema de onde vem.
- [ ] Sei guiar sem setas e sei fazer o teste do primeiro olhar.
- [ ] Sei distinguir gates duros e moles e desenhar o grafo de gates sem ciclos nem *softlocks*.
- [ ] Sei desenhar compressão e alívio, e o mapa de tensão do setor bate com a curva narrativa.
- [ ] Sei por que a curva do corredor funciona e quais medidas a sustentam.
- [ ] O puzzle dos disjuntores é um `AVGSequencePuzzle`, testado, e o Level Blueprint de `L_CasaDeForca` tem uma linha.
- [ ] O setor 1 tem documento de nível com frases de intenção; os setores 2 e 3 existem em blockout jogável.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Modeling Mode**, **Geometry Brushes (BSP)**, **Level Instancing** e **Navigation System**.
- **GDC Vault** (gdcvault.com): há várias palestras sobre blockout, métricas de nível e level design de jogos de terror e de jogos lineares narrativos, incluindo apresentações de level designers de estúdios AAA (confira títulos e autores lá).
- **Jesse Schell, *The Art of Game Design*** — os capítulos sobre espaço e sobre como o jogador é guiado ("indirect control").
- **Don Norman, *The Design of Everyday Things*** — a origem do uso de *affordances* em design, útil para pensar portas, alavancas e sinais.

---

➡️ **Próximo:** [Capítulo 51 — Lighting](cap-51-lighting.md)

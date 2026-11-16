# PARTE VI — Narrative Games

*Projeto 6: o sistema narrativo — refatoração do "Turno da Noite"*

---

# Capítulo 43 — Narrative Design

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o que **narrative design** é — e como ele difere de "escrever a história de um jogo";
- distinguir **narrativa embutida** (autorada) de **narrativa emergente** (produzida pelos sistemas) e saber combiná-las;
- usar os conceitos de **agência**, **harmonia e dissonância ludonarrativa** e **informação do jogador vs. do personagem**;
- escolher uma **estrutura** (linear, ramificada, hub, episódica, colar de pérolas) e entender o seu custo de produção;
- desenhar um **livro-razão de mistério** (perguntas abertas e respondidas) e uma **mistura de canais** (cinemática, diálogo, documento, ambiente, gameplay);
- escrever o **documento de narrativa da Vigília**, que a Parte VI vai transformar em sistemas.

---

## Contexto

O Interlúdio I construiu uma história curta — o *Turno da Noite* — e a cola que a fazia acontecer foi a mais ingênua possível: variáveis booleanas no Level Blueprint, falas escritas dentro de nós, sequências de `Delay`. Funcionou, e o inventário de dores listou doze problemas. A Parte VI resolve esses problemas com sistemas — diálogos, quests, estado narrativo, ramificação, documentos, cinemáticas.

Antes dos sistemas, porém, vem a pergunta que eles servem: **o que é narrativa num jogo, e como se projeta uma?** Este capítulo é conceitual, como foram o 1 e o 5. Ele é o equivalente, para a história, do que o MDA foi para as mecânicas: o vocabulário que permite separar "o que eu implemento" de "o que a jogadora vive".

---

## 43.1 Narrative design não é escrever a história

Num estúdio, **escritor** e **narrative designer** são papéis próximos e diferentes:

- O **escritor** cria o texto: falas, documentos, personagens, a voz de cada um.
- O **narrative designer** decide **como a história chega à jogadora através do jogo**: em que momento, por qual canal, em resposta a quê, com que liberdade, e como ela se entrelaça com as mecânicas.

Para um engenheiro, a segunda metade é a mais interessante — e a mais próxima de sistemas. Narrative design trata de **informação** (o que a jogadora sabe, quando), **estado** (o que aconteceu, o que mudou no mundo), **condições** (o que só acontece se), **canais** (como cada informação é entregue) e **ritmo** (quando revelar, quando segurar). São exatamente as coisas que o *Turno da Noite* fez à mão.

> 🌉 **Ponte:** se o escritor produz o **conteúdo**, o narrative designer projeta o **sistema de entrega** — como um arquiteto de informação decide fluxos, permissões e momentos de exibição, sem escrever os textos.

---

## 43.2 Narrativa embutida e narrativa emergente

Dois tipos de história coexistem em quase todo jogo:

- **Narrativa embutida** (*embedded*) — a história **autorada**: o que aconteceu com o turno da noite, quem é Sônia, o que o engenheiro sabia. Está escrita antes de a jogadora jogar, e é **descoberta**.
- **Narrativa emergente** (*emergent*) — a história que **acontece** jogando, produzida pelos sistemas: "eu fechei a porta atrás de mim no último segundo, ouvi a Presença do outro lado e fiquei agachada no escuro até ela ir embora". Ninguém escreveu essa cena. Ela é a soma da navegação (Capítulo 35), da percepção (Capítulo 36), da Behavior Tree (Capítulo 37) e do Diretor (Capítulo 42).

```text
 TOTALMENTE AUTORADA ◄──────────────────────────────────────────────► TOTALMENTE EMERGENTE
   filme interativo,         Alan Wake, Max Payne,      Outlast, Amnesia,      GTA (rua),
   jogo de aventura          Quantum Break              a Vigília              futebol, simulações
   com escolhas
```

As posições no espectro são uma leitura do autor, não uma classificação estabelecida, e todo jogo mistura os dois polos. A Vigília está deliberadamente no meio: **a história da usina é embutida** (documentos, rádio, cinemáticas), e **a experiência de sobreviver a ela é emergente** (a Presença sistêmica). O trabalho de narrative design é fazer as duas **se reforçarem**: a história explica por que a escuridão é perigosa e o que a Presença é; a experiência faz a jogadora **sentir** o que os documentos descrevem.

---

## 43.3 Agência

**Agência** é a sensação de que as **ações** da jogadora têm **consequências** significativas. Ela não exige ramificação de história — a Vigília quase não tem — e ramificação não garante agência.

Três níveis, do mais barato ao mais caro:

1. **Agência no momento** — as escolhas de **como** jogar importam: correr ou se esconder, gastar o sinalizador agora ou depois, ler o documento ou seguir em frente. A Vigília vive aqui.
2. **Agência na interpretação** — a jogadora **monta** a história a partir do que encontrou; duas jogadoras saem com entendimentos diferentes, conforme o que leram e em que ordem. A Vigília também vive aqui (documentos opcionais, a variação do memorando).
3. **Agência no enredo** — escolhas mudam **o que acontece** na história (finais diferentes, personagens que vivem ou morrem). Caro: cada ramo é conteúdo que parte das jogadoras nunca vê (Capítulo 47).

> **Ilusão de escolha** — escolhas que parecem importar e convergem para o mesmo resultado — é uma técnica legítima e antiga (Capítulo 1, "mentir é legítimo"), **desde que** o jogador sinta reconhecimento: a escolha muda **algo perceptível** (uma fala, um detalhe, uma reação), mesmo que o enredo convirja. A variação da fala de Sônia sobre o memorando é exatamente isso.

---

## 43.4 Harmonia e dissonância ludonarrativa

**[FATO PÚBLICO]** O termo **dissonância ludonarrativa** foi cunhado por Clint Hocking, então na Ubisoft, num texto de 2007 sobre *BioShock*, para descrever o conflito entre o que a **mecânica** de um jogo comunica e o que a **história** diz. O termo se tornou parte do vocabulário de crítica e de design de jogos.

O conceito é simples: um jogo **diz** coisas pelas regras (o que é recompensado, o que é punido, o que é possível) e pela história. Quando as duas dizem coisas opostas — uma história sobre a fragilidade humana num jogo em que o protagonista mata centenas de inimigos sem esforço —, há **dissonância**. Quando dizem a mesma coisa, há **harmonia**, e cada uma amplifica a outra.

A Vigília foi desenhada para a harmonia desde a Introdução:

| A história diz | A mecânica diz |
|---|---|
| "A escuridão é perigosa; a luz protege" | A Presença não entra na luz (navegação); zonas seguras regeneram |
| "Você é uma perita, não uma soldada" | Sem combate contra a Presença; sinalizador só repele |
| "Ver é se expor" | A lanterna acesa torna a jogadora visível (percepção) |
| "A usina é um organismo que reage" | O alarme, as falhas de luz, o Diretor |
| "Alguém religou a turbina 3" | Religar os setores é o objetivo — e o que a desperta |

A última linha é a mais importante: **o objetivo da jogadora é a causa do perigo.** Restaurar a energia é ao mesmo tempo o que ela precisa fazer e o que alimenta a ameaça. É a mesma lição de Alan Wake no Capítulo 1 — uma regra que serve à mecânica e ao tema — aplicada à estrutura inteira.

---

## 43.5 O que a jogadora sabe vs. o que a personagem sabe

Um eixo de design específico de narrativa interativa: **a jogadora e a personagem nem sempre sabem as mesmas coisas.**

- **A jogadora sabe menos que a personagem**: a personagem tem um passado que a jogadora descobre. Útil para mistério; arriscado quando a personagem age com base em algo que a jogadora não sabe (decisões "do nada").
- **A jogadora sabe mais que a personagem**: a jogadora leu o memorando; Helena (a personagem) age como se não soubesse? Isso gera **ironia dramática** — e é uma fonte de tensão de terror: *a jogadora sabe que não deveria religar a turbina três, e precisa religá-la*.
- **Sabem o mesmo**: o padrão mais simples; a descoberta é compartilhada.

A Vigília usa o terceiro como base e o segundo como instrumento: o que a jogadora **lê** pode ser **comentado** por Sônia (a voz do rádio), mas Helena nunca diz "eu já sabia" — o conhecimento é da jogadora, e as consequências também.

---

## 43.6 Estruturas

| Estrutura | Forma | Custo de conteúdo | Exemplo de uso |
|---|---|---|---|
| **Linear** | Uma sequência de beats | Baixo: tudo é visto | Jogos de ação cinematográficos |
| **Colar de pérolas** (*string of pearls*) | Linear entre "pérolas"; liberdade dentro de cada uma | Médio | Áreas exploráveis ligadas por um caminho |
| **Ramificada** | Escolhas dividem a história | **Alto**: multiplica conteúdo | Jogos de escolhas |
| **Ramificar e convergir** (*branch and bottleneck*) | Ramifica e volta a pontos comuns | Médio | Escolhas com consequências locais |
| **Hub** | Um centro com caminhos opcionais | Médio | Exploração com retorno |
| **Episódica** | Capítulos com começo, meio e fim, com ganchos | Médio | Narrativas seriadas |
| **Aberta / sistêmica** | História emerge de atividades | Variável | Mundo aberto |

A Vigília é um **colar de pérolas episódico**: um prólogo (o Pátio), três setores (pérolas) e um final; dentro de cada setor, exploração livre; entre setores, um caminho; cada setor é um "episódio" com um gancho no fim. O *Turno da Noite* é o primeiro setor.

### Estudo de caso: Alan Wake — estrutura episódica e prenúncio

**[FATO PÚBLICO]** *Alan Wake* (Remedy, 2010) é dividido em **episódios**, como uma série de televisão, que terminam com ganchos e começam com recapitulações do tipo "anteriormente em *Alan Wake*". Ao longo do jogo, o protagonista encontra **páginas de um manuscrito** que ele não se lembra de ter escrito, e muitas dessas páginas **descrevem eventos que ainda vão acontecer** — às vezes eventos que o jogador vai viver alguns minutos depois.

**[INFERÊNCIA]** As duas técnicas são, ao mesmo tempo, **estrutura** e **sistema de tensão**:

- A estrutura episódica dá ao jogo um **ritmo macro** — picos no fim de cada episódio, recapitulações que reorientam quem voltou a jogar — e uma linguagem de **série** coerente com o tema (um escritor, uma história que se escreve sozinha).
- As páginas que prenunciam eventos invertem o mistério: a pergunta deixa de ser "o que vai acontecer?" e passa a ser "**quando** e **como** vai acontecer o que eu li?" — uma forma pura de **tensão pela expectativa** (Capítulo 5). Cada página lida aumenta o medo do que vem, sem nenhum inimigo na tela.

E o prenúncio é, também, um **sistema**: páginas são coletáveis opcionais, então jogadoras diferentes sabem coisas diferentes sobre o futuro — agência de interpretação. Nenhuma afirmação é feita sobre a implementação.

**Lição para a Vigília:** o **livro de ocorrências** do turno de 1994 cumpre um papel semelhante — ele descreve o que aconteceu com o turno ("as luzes do corredor apagaram de uma ponta à outra, como se alguém viesse andando com elas") **pouco antes** de acontecer com a jogadora (o susto do corredor, beat 6). Quem leu o livro **reconhece** o susto. Quem não leu, só leva o susto. É a mesma cena, com dois valores — e o sistema narrativo precisa saber qual jogadora é qual.

---

## 43.7 Mistério: o livro-razão de perguntas

Jogos de investigação e de terror são movidos por **perguntas**. Uma ferramenta simples de narrative design é manter um **livro-razão** de perguntas: quando cada uma é **aberta**, quando é **respondida** (ou parcialmente), e por qual canal.

```text
 VIGÍLIA — LIVRO-RAZÃO DE MISTÉRIO (trecho, setor 1 = Turno da Noite)

 #  Pergunta                                   Aberta em         Respondida em           Canal
 1  O que aconteceu com o turno de 1994?       Prólogo (rádio)   Final (parcial)         rádio, livro, final
 2  Por que a turbina 3 está girando?          Prólogo (rádio)   Setor 1, final (parcial) painéis, cinemática
 3  O que o Eng. Moraes sabia?                 Setor 1 (memo)    Setor 2                 documento
 4  O que "apaga as luzes andando"?            Setor 1 (livro)   Setor 1 (susto) — ver,  livro → evento
                                                                 não entender
 5  Quem está acionando a turbina agora?       Setor 1 (final)   Setor 3                 cinemática
```

Regras práticas:

- **Abra mais perguntas do que responde no começo; responda mais do que abre no fim.**
- **Toda resposta deve abrir uma pergunta menor** (manter o motor girando) — até o final.
- **Nunca responda tudo por um único canal** (só documentos, só cinemáticas): misture.
- **Respostas parciais** ("ver, não entender") são mais assustadoras que respostas completas — especialmente no terror.

---

## 43.8 Canais de entrega

Cada informação narrativa chega por um **canal**, e cada canal tem custos e propriedades:

| Canal | Controle do autor | Agência da jogadora | Custo de produção | Interrompe o jogo? |
|---|---|---|---|---|
| **Cinemática** | Total | Nenhuma | Alto | Sim |
| **Diálogo ativo** (rádio, conversa) | Alto | Baixa | Médio | Não necessariamente |
| **Falas contextuais** (barks) | Médio | Média | Baixo por fala | Não |
| **Documentos** | Alto (texto) | **Alta** (opcional) | Baixo | Sim (leitura) |
| **Ambiente** (narrativa ambiental) | Médio | **Alta** | Médio | Não |
| **Gameplay** (o que a mecânica comunica) | Baixo | **Total** | Variável | Não |
| **Áudio** (sons, música) | Médio | Média | Médio | Não |

A Vigília mistura todos, com uma intenção: **os fatos chegam por documentos e ambiente** (a jogadora os procura), **a emoção chega por áudio, luz e gameplay**, **o contexto chega pelo rádio** (Sônia como fio condutor), e **os picos chegam por cinemáticas curtas**. O Capítulo 48 aprofunda o ambiente e os documentos; o 49, as cinemáticas; o 44, o rádio.

---

## Comparação com o desenvolvimento tradicional

| Narrative design | O que você conhece | Onde a analogia cai |
|---|---|---|
| Escritor vs. narrative designer | Conteúdo vs. arquitetura de informação | O "usuário" é guiado emocionalmente, não funcionalmente |
| Embutida vs. emergente | Conteúdo estático vs. comportamento do sistema | O emergente precisa **parecer** história |
| Livro-razão de mistério | Backlog de perguntas abertas / dívida de informação | O objetivo é manter perguntas abertas de propósito |
| Canais de entrega | Canais de notificação (e-mail, push, in-app) | A escolha do canal é estética, não só funcional |
| Harmonia ludonarrativa | Coerência entre regras de negócio e comunicação | A dissonância é percebida como "mentira" do jogo |

---

## Implementação: o documento de narrativa da Vigília

Este capítulo não tem código. O entregável é o **documento de narrativa** (`docs/design/narrativa.md`), que guia toda a Parte VI. Estrutura sugerida — preencha com as suas palavras:

```text
VIGÍLIA — DOCUMENTO DE NARRATIVA (v0.1)

1. PREMISSA (3 frases)
   (Helena, a usina, o turno de 1994, a turbina girando esta noite.)

2. TEMA
   O que a história é "sobre", além do enredo. (Ex.: o que se perde quando se religa
   algo que deveria ter ficado desligado; responsabilidade; o trabalho noturno invisível.)

3. HARMONIA LUDONARRATIVA
   Tabela "a história diz / a mecânica diz" (seção 43.4).

4. ESTRUTURA
   Colar de pérolas episódico: Prólogo (Pátio) → Setor 1 (Casa de Força: Turno da Noite)
   → Setor 2 (Subestação) → Setor 3 (Salão das Turbinas) → Final.
   Para cada setor: objetivo, beats principais, gancho final.

5. PERSONAGENS
   Helena (voz? quase nenhuma — a jogadora fala por ela), Sônia (o rádio: cansada,
   profissional, assustada sem admitir), Eng. Moraes (só em documentos), os seis do
   turno de 1994 (nomes, um traço cada), a Presença (o que ela é — e o que o jogo
   nunca diz explicitamente).

6. LIVRO-RAZÃO DE MISTÉRIO
   Todas as perguntas, quando abrem, quando fecham, por qual canal.

7. MISTURA DE CANAIS
   Por setor: quais fatos por documentos, quais por rádio, quais por ambiente, quais
   cenas viram cinemática.

8. VARIAÇÕES (agência de interpretação)
   O que muda conforme o que a jogadora leu ou fez (ex.: o memorando; o livro de
   ocorrências antes do susto).

9. PERGUNTAS ABERTAS DE DESIGN (para playtest)
   Ex.: as jogadoras leem os documentos? A Sônia fala demais? O final do setor 1
   deixa vontade de continuar?
```

Revise o *Turno da Noite* (Interlúdio I) à luz do documento: os nove beats ainda servem? O livro-razão está equilibrado? Há dissonância em algum ponto (por exemplo, o sinalizador sendo usado como arma "normal")?

---

## Decisões arquiteturais (de design)

1. **A história da usina é embutida; a experiência de sobreviver é emergente** — e as duas são desenhadas para se reforçar.
2. **Agência no momento e na interpretação**; quase nenhuma ramificação de enredo.
3. **Harmonia ludonarrativa como critério de revisão** de toda mecânica e de todo texto.
4. **Colar de pérolas episódico**, com ganchos por setor.
5. **Livro-razão de mistério** mantido junto com o documento de narrativa.
6. **Mistura de canais**: fatos por documentos e ambiente; emoção por áudio, luz e gameplay; contexto pelo rádio; picos por cinemáticas curtas.

Consequências para a engenharia (o que a Parte VI precisa construir):

- **Estado narrativo** que lembre o que a jogadora leu, viu e fez (Capítulo 46);
- **Diálogos** condicionados a esse estado, sem repetir (Capítulo 44);
- **Quests e beats** com pré-condições e consequências (Capítulo 45);
- **Variações** baratas por estado (Capítulo 47);
- **Documentos** como dados, com registro de leitura (Capítulo 48);
- **Cinemáticas** integradas ao estado e ao Diretor (Capítulo 49).

---

## Armadilhas

- **Escrever a história antes de pensar a entrega** — e depois "encaixar" no jogo.
- **Dissonância ludonarrativa** — mecânicas que contradizem o tema.
- **Ramificação cara sem agência percebida.**
- **Responder todas as perguntas cedo** — ou nunca responder nenhuma.
- **Um único canal** (tudo em cinemática, ou tudo em documentos longos).
- **A personagem saber o que a jogadora não sabe** e agir com base nisso sem explicação.
- **Texto demais** — documentos longos que ninguém lê.

---

## Exercício

**Parte 1 — documento (2–3 h).** Escreva o `docs/design/narrativa.md` da Vigília com as nove seções.

**Parte 2 — livro-razão (45 min).** Monte o livro-razão completo (todos os setores). Verifique as regras da seção 43.7: o começo abre mais do que responde? O final responde mais do que abre? Cada resposta abre uma pergunta menor?

**Parte 3 — análise de referência (1 h).** Escolha um jogo narrativo que você conhece bem (Alan Wake 2, Control, Max Payne, Quantum Break, A Machine for Pigs). Identifique: estrutura, três perguntas do livro-razão dele, a mistura de canais, e um momento de harmonia (ou dissonância) ludonarrativa. Marque fatos e inferências.

**Parte 4 — o Turno da Noite revisto (45 min).** Reavalie os nove beats do Interlúdio I com o documento. Liste as mudanças de **conteúdo** que você faria (antes da refatoração de sistema).

---

## Desafio — o prenúncio

Inspirado nas páginas de manuscrito de Alan Wake, desenhe para a Vigília **três prenúncios**: documentos (ou fitas de rádio de 1994) que descrevem, com palavras do turno da noite, algo que a jogadora vai viver **minutos depois**. Para cada um:

1. O texto (curto: até 80 palavras).
2. O evento que ele prenuncia e onde acontece.
3. O que a jogadora sente se **leu** antes, e se **não leu**.
4. Como o sistema narrativo precisaria saber se ela leu (para, por exemplo, a Sônia comentar "foi igual ao livro" — ou para o Diretor **não** disparar o evento antes que ela tenha a chance de ler).

Guarde o desafio: os Capítulos 46 e 48 vão implementar exatamente esse tipo de dependência.

---

## Uso de IA

1. **Para revisar a harmonia ludonarrativa:**
   > "Atue como narrative designer. Aqui estão a premissa, o tema e as mecânicas principais de um jogo de terror em primeira pessoa (abaixo). Aponte pontos de harmonia e de dissonância ludonarrativa, e sugira ajustes de mecânica ou de narrativa para eliminar cada dissonância. [documento]"

2. **Para equilibrar o mistério:**
   > "Aqui está um livro-razão de perguntas de mistério de um jogo (quando abre, quando fecha, canal). Avalie o equilíbrio: há trechos sem perguntas novas? Perguntas respondidas cedo demais? Respostas que não abrem perguntas menores? Canais repetidos demais? Proponha ajustes. [tabela]"

3. **Para escrever com a sua voz:**
   > "Vou colar um documento que escrevi para um jogo (um registro de turno de 1994). Não reescreva. Aponte frases que soam genéricas ou 'de IA', informações que entregam demais, e onde o texto poderia sugerir mais e explicar menos, como em ficção de terror. [texto]"

**Cuidado específico:** IAs escrevem prosa plausível e genérica com facilidade. Use-as para **revisar** e para **gerar variações** que você reescreve — não para produzir o texto final. A voz da Vigília é sua.

---

## Checklist

- [ ] Sei a diferença entre escrever a história e projetar a narrativa.
- [ ] Sei distinguir narrativa embutida e emergente e combinar as duas.
- [ ] Sei os três níveis de agência e quando a ilusão de escolha funciona.
- [ ] Sei explicar harmonia e dissonância ludonarrativa e verifiquei a Vigília.
- [ ] Sei escolher uma estrutura pelo custo e pelo efeito.
- [ ] Montei o livro-razão de mistério e a mistura de canais.
- [ ] Escrevi o documento de narrativa da Vigília.

---

## Para ir além

- **Jesse Schell, *The Art of Game Design*** — capítulos sobre história, mundo e personagens.
- **Clint Hocking, "Ludonarrative Dissonance in Bioshock"** (2007) — o texto que deu nome ao conceito (no blog do autor, *Click Nothing*).
- **GDC Vault** (gdcvault.com) — a trilha de narrativa da GDC (incluindo o *Narrative Summit*) e postmortems de jogos narrativos; procure palestras de desenvolvedores da Remedy e da Frictional Games sobre narrativa.

---

➡️ **Próximo:** [Capítulo 44 — Dialogue Systems](cap-44-dialogue-systems.md)

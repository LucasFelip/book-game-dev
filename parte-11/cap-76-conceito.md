# PARTE XI — Projeto Final: *Vigília*

*Projeto 7 (Vertical Slice) e Projeto Final: os 10 a 20 minutos da Vigília, do conceito ao build*

---

# Capítulo 76 — Conceito

## Objetivo

Ao final deste capítulo você deve conseguir:

- escrever o **documento de design** de um jogo pequeno: uma página que cabe na cabeça e um documento vivo que guia a produção;
- justificar **pilares** de design pela experiência que eles produzem e pelos sistemas que exigem, com o custo de cada um;
- desenhar a **curva de experiência** do jogo inteiro e a estrutura de conteúdo que a sustenta;
- fazer um **inventário de conteúdo** com números (salas, documentos, falas, encontros, cenas) e cortar escopo antes de produzir;
- montar um **registro de riscos** e os **dez milestones** do projeto final, cada um com objetivo, funcionalidades, conceitos, entregáveis e critérios de conclusão;
- planejar a produção em semanas, para quem estuda de 7 a 10 horas por semana.

---

## Contexto

A Introdução prometeu (seção 6.1) que o documento completo da Vigília estaria neste capítulo. Ao longo de 75 capítulos, o projeto cresceu por partes:

- o Pátio virou o exterior;
- o Galpão testou armas e inimigos;
- o *Turno da Noite* foi feito errado de propósito e depois refatorado;
- a Presença e os vigias ganharam cérebro;
- a luz, o som, a animação e a interface ganharam acabamento;
- o save, a persistência e a performance foram resolvidos;
- o Projeto Arena descobriu o que muda quando o mundo é compartilhado;
- a IA generativa ganhou um lugar contido.

O que ainda não existe é **o jogo**: uma experiência de 10 a 20 minutos, com começo, meio e fim, em qualidade de lançamento. Para chegar lá, a Parte XI faz o que estúdios fazem no início de uma produção (e que este livro, por razões didáticas, deixou para o fim): **decidir o que o jogo é, o que ele não é, e o que cabe no tempo que existe.**

A diferença em relação a um começo de produção real é favorável: quase todos os sistemas já existem e foram testados. O risco da Vigília não é técnico, é de **escopo e de conteúdo**. É por isso que este capítulo não tem código.

---

## 76.1 O documento de design

Documentos de design de jogo (GDD) tinham, há uma geração, centenas de páginas que ninguém lia. A prática que sobreviveu é mais modesta: **uma página** que todo mundo conhece de cor, e um **documento vivo** que é consultado e corrigido durante a produção.

### A página única

```text
VIGÍLIA — UMA PÁGINA

PREMISSA  Helena Duarte, perita do Departamento Estadual de Energia, é enviada à noite à Usina de
          Serra Funda, desativada desde que o turno C desapareceu em 14/08/1994. Esta noite, as
          turbinas voltaram a girar. Sônia, da Central, é a única voz no rádio.

GÊNERO    FPS narrativo de terror e investigação, em primeira pessoa, 10–20 minutos.

FANTASIA  "Eu entrei sozinha num lugar que não devia estar funcionando, entendi o que aconteceu
          aqui — e tive que decidir se deixava continuar."

PILARES   1. A luz é recurso, linguagem e defesa.
          2. A usina é o documento: burocracia e máquina contam a história.
          3. Vulnerabilidade: fugir e se esconder antes de lutar.
          4. Momentos cinematográficos curtos, com uma voz no rádio.
          5. Um combate curto e intenso, no lugar certo.

ESTRUTURA Prólogo (Pátio) → Setor 1 (Casa de Força) → Setor 2 (Subestação)
          → Setor 3 (Salão das Turbinas) → Final (uma escolha, dois desfechos).

NÃO É     um jogo de tiro; um mundo aberto; um jogo de escolhas ramificadas;
          um jogo de quebra-cabeças difíceis; um jogo de sustos baratos.
```

A linha **NÃO É** é a mais útil da página. Cada pedido de funcionalidade durante a produção ("e se tivesse um inventário?", "e se os vigias pudessem ser negociados?") passa por ela antes de qualquer discussão.

### O documento vivo

O documento vivo (`docs/design/vigilia-gdd.md`) não é escrito do zero: ele **reúne** os documentos que o livro produziu e acrescenta o que falta.

| Seção | Fonte | Situação |
|---|---|---|
| Loops (core, micro, macro) | `docs/design/loops.md` (Cap. 5) | Revisar com o jogo inteiro |
| Combate | `docs/design/combate.md` (Cap. 21) | v0.1 → **v1.0** neste capítulo |
| Narrativa | `docs/design/narrativa.md` (Cap. 43) | Completar os setores 2 e 3 (Cap. 81) |
| Fatos, quests, ramificação | `fatos.md`, `quests.md`, `ramificacao.md` (Caps. 45–47) | Completar |
| Níveis | documentos de nível com frases de intenção (Cap. 50) | Setores 2 e 3 |
| Tags, Blackboards | `tags.md` (Cap. 23), `blackboards.md` (Cap. 38) | Contratos: só crescem |
| **Conteúdo, escopo, riscos, milestones** | — | **Este capítulo** |

---

## 76.2 Os pilares, justificados

Um pilar é uma promessa de experiência que **decide disputas**. Quando duas ideias brigam por tempo, ganha a que serve melhor a um pilar. Por isso cada pilar precisa de uma justificativa (a experiência), dos sistemas que o sustentam (o custo já pago) e do que ele exige da produção daqui em diante (o custo a pagar).

| Pilar | Experiência | Sistemas já construídos | O que ainda exige |
|---|---|---|---|
| **1. Luz: recurso, linguagem, defesa** | Ver custa: acender a lanterna é ser vista. A luz protege, e a escuridão é perigosa | Bateria e flicker (Caps. 4 e 9); zonas seguras (23); navegação e percepção pela luz (35–36); setores energizados (23–24); lanterna definitiva e sobrecarga (51) | Iluminação final dos três setores; leitura clara de "aqui é seguro" |
| **2. A usina é o documento** | A história se monta pelo que se lê e pelo que se vê | Documentos e leitor (48); vinhetas (48); fatos (46); o livro-razão (43) | Os documentos e as vinhetas dos setores 2 e 3; a janela do salão das turbinas |
| **3. Vulnerabilidade** | A ameaça não morre; fugir é a regra, esconder é a vitória | A Presença: BT, percepção, Diretor (Parte V); "dois toques" (21–22) | A perseguição do setor 3; o balanceamento do Diretor no jogo inteiro |
| **4. Momentos cinematográficos** | Cenas curtas que recompensam, e uma voz humana no ouvido | Rádio (44); cenas com estado (49) | Abertura, fim de cada setor, os dois finais |
| **5. Combate curto e intenso** | Um trecho em que a jogadora pode lutar, e por isso sente o resto do jogo como fuga | Armas, hitscan, recoil (Partes III–IV); vigias com IA tática (Parte V) | O encontro dos vigias no setor 2, com cobertura e munição contada |

Repare que o pilar 5 **existe para servir ao pilar 3**. O documento de combate do Capítulo 21 já tinha a hipótese: "o contraste reforça a vulnerabilidade". O único trecho em que a jogadora pode reagir com armas faz do resto do jogo uma fuga **consciente**. É uma decisão de ritmo, não de gênero.

---

## 76.3 A curva do jogo inteiro

O *Turno da Noite* tem uma curva de tensão própria (Interlúdio I). O jogo inteiro é uma sequência dessas curvas, com uma escalada que atravessa os setores:

```text
 tensão
   ▲                                                              perseguição ┐   escolha
   │                                                                     ╭──╮ │    ╭╮
   │                                         vigias (combate)      ╭─────╯  ╰─┴──╮╭╯╰╮  final
   │                          susto ╭╮         ╭─╮               ╭─╯              ╰╯  ╰──╮
   │                               ╭╯╰╮       ╭╯ ╰╮    descoberta╯                       ╰╮
   │       rádio    livro   ╭──────╯  ╰─╮  ╭──╯   ╰──╮ ╭───╯                             ╰── epílogo
   │  ╭────╮ ╭──────╮ ╭─────╯           ╰──╯         ╰─╯                                     (rádio)
   │──╯    ╰─╯      ╰─╯
   └──────────────────────────────────────────────────────────────────────────────────────► tempo
     PRÓLOGO (2 min)   SETOR 1 (4–5 min)   SETOR 2 (4–6 min)        SETOR 3 (3–5 min)    FINAL (1–2 min)
       Pátio            Casa de Força        Subestação               Salão das Turbinas
```

Três regras orientam a curva:

1. **Cada setor tem um pico e um vale.** O vale (zona segura, documento, rádio) é onde a jogadora processa o que viveu. Sem vales, a tensão vira cansaço.
2. **A escalada é de natureza, não só de intensidade.** O setor 1 assusta com **cenografia** (a silhueta), o setor 2 com **pessoas** (os vigias) e o setor 3 com **o sistema** (a Presença caçando de verdade, numa perseguição). Cada setor ensina uma ameaça nova.
3. **O pico final não é o mais alto.** A escolha final é um momento de **quietude tensa**: a Presença recua (uma trava do Diretor), Sônia fala, e a jogadora decide. O pico de adrenalina é a perseguição, logo antes.

---

## 76.4 Estrutura e inventário de conteúdo

### Os setores

O documento de combate v0.1 (Capítulo 21) usava letras (setores A, B e C), enquanto o Capítulo 43 numerou os setores da história. A nomenclatura final adota a numeração: **A = Prólogo (Pátio), B = Setor 1 (Casa de Força), C = Setor 2 (Subestação)**. O Salão das Turbinas (setor 3) não existia na v0.1.

| Parte | Espaço | Objetivo da jogadora | O que a jogadora aprende | Ameaça | Pico | Gancho final |
|---|---|---|---|---|---|---|
| **Prólogo** | Pátio da usina (Projeto 1) | Chegar à Casa de Força | Andar, olhar, lanterna; Sônia | Nenhuma: só atmosfera | A turbina ouvida de longe | A porta da Casa de Força |
| **Setor 1** | Casa de Força (*Turno da Noite*) | Religar a sala de controle | Documentos, interação, puzzle; a luz protege | Cenografia (o primeiro susto) | O corredor | A turbina 3 girando **agora** |
| **Setor 2** | Subestação | Restabelecer a linha até o salão das turbinas | Seguir Sônia ou o mapa de Moraes; cobertura e tiro | Os vigias (trecho único) e a Presença sistêmica | O encontro dos vigias | Quem são os vigias, e para quem trabalham |
| **Setor 3** | Salão das Turbinas | Chegar ao comando manual da turbina 3 | O que aconteceu em 1994 (revelação pelo espaço) | A Presença, em perseguição | A fuga pelas passarelas | A escolha |
| **Final** | Comando manual | Desligar a turbina 3 ou deixá-la girar | — | A Presença recua | A escolha | Epílogo no rádio |

### O inventário

Números, antes de produzir. Os do setor 1 já existem, e os outros são estimativas a confirmar no Capítulo 79.

| Conteúdo | Prólogo | Setor 1 | Setor 2 | Setor 3 | Final | Total |
|---|---|---|---|---|---|---|
| Espaços (salas/áreas) | 3 | 5 | 6 | 4 | 1 | 19 |
| Documentos | 1 | 4 | 5 | 3 | 0 | 13 |
| Vinhetas | 2 | 4 | 4 | 3 | 1 | 14 |
| Conversas de rádio | 3 | 6 | 6 | 4 | 4 (variantes do epílogo) | 23 |
| Escolhas (estado/estrutural) | 0 | 2 | 2 | 0 | 1 | 5 |
| Cenas (Sequencer) | 1 | 3 | 2 | 2 | 2 | 10 |
| Encontros com IA | 0 | 0 (cenografia) | 2 (vigias, Presença) | 2 (Presença, perseguição) | 0 | 4 |
| Puzzles | 0 | 1 | 1 | 1 | 0 | 3 |

O total é pequeno de propósito, e mesmo assim cada linha é trabalho de semanas para uma pessoa. A tabela também mostra onde o jogo é **denso** (setor 2) e onde respira (prólogo).

---

## 76.5 Escopo: o que fica, o que sai

A técnica de priorização **MoSCoW** (*must*, *should*, *could*, *won't*) é simples e funciona para um projeto individual, desde que o *won't* seja escrito com a mesma seriedade que o *must*.

| Prioridade | Itens |
|---|---|
| **Precisa ter** (*must*) | Os quatro espaços e o final; a lanterna com sobrecarga; o sinalizador; a Presença com percepção e Diretor; os vigias num encontro; o rádio com as variantes do catálogo; documentos e arquivo; save por checkpoint; os dois finais; legendas e opções de acessibilidade básicas |
| **Deveria ter** (*should*) | O caderno de Helena (desafio do Cap. 48); a quest dos seis crachás; a perseguição com rota alternativa; uma segunda passada de áudio |
| **Poderia ter** (*could*) | Fitas de 1994 narradas; um modo "sem combate" (os vigias evitáveis por furtividade); variações de vinhetas por fato além do catálogo |
| **Não vai ter** (*won't*) | Inventário com itens combináveis; mais de uma escolha estrutural; diálogo com escolhas fora do rádio; NPCs com IA generativa no build de lançamento (Parte X: só protótipo atrás de uma CVar); multiplayer no build de lançamento (Cap. 84: só um ramo experimental) |

A linha *won't* tem duas entradas que vêm de capítulos inteiros do livro: os NPCs generativos (Partes X) e o multiplayer (Parte IX). Os dois foram estudados a fundo, e os dois ficam **fora** do jogo de lançamento, por decisão e não por esquecimento. Aprender um sistema e decidir não usá-lo é uma das lições mais valiosas de produção: o conhecimento informa o que **não** fazer.

---

## 76.6 Riscos

Um registro de riscos é uma tabela que se revisa a cada milestone. Cada risco tem uma probabilidade, um impacto, um **sinal** (como saber que ele está acontecendo) e uma **resposta** decidida antes.

| Risco | Prob. | Impacto | Sinal | Resposta |
|---|---|---|---|---|
| O setor 2 (o mais denso) atrasa tudo | Alta | Alto | Milestone 6 com mais de 2 semanas de atraso | Cortar uma sala e um documento; os vigias num espaço só |
| A Presença frustra em vez de assustar | Média | Alto | No playtest, jogadoras morrem mais de 2 vezes por setor | Ajustar o Diretor (frequência), não as regras (Cap. 42); aumentar a telegrafia |
| O combate quebra o tom | Média | Médio | Jogadoras descrevem o setor 2 como "parte de tiro" | Reduzir a munição; mais ênfase na cobertura; o modo furtivo sobe para *should* |
| A escolha final não tem peso | Média | Alto | Jogadoras escolhem "qualquer uma" | Mais consequências tardias lidas no epílogo (Cap. 47); a escolha precisa de silêncio |
| Performance no Salão das Turbinas (espaço grande, Lumen, partículas) | Média | Médio | Um cenário `S3.*` reprovado no portão de performance (Cap. 83) | Orçamento por setor desde o Milestone 6; LOD e oclusão (Cap. 60) |
| Conteúdo de texto cresce sem controle | Alta | Médio | Mais de 15 documentos ou mais de 30 conversas | O inventário é teto, não meta |
| O projeto parece "nunca pronto" | Alta | Alto | O polimento passa de 3 semanas | Datas fixas e escopo variável: o que não ficar pronto vai para o *won't* |

---

## 76.7 Os milestones

A spec do projeto final pede dez milestones (Foundation, Player, Combat, AI, Narrative, Level, Audio/VFX, Save System, Polish, Release Build), cada um com objetivo, funcionalidades, conceitos aprendidos, entregáveis e critérios de conclusão. Para a Vigília, boa parte dos milestones é **integração e conteúdo**, não sistema novo, porque os sistemas existem. A tabela marca o capítulo da Parte XI que conduz cada um.

| # | Milestone | Objetivo | Funcionalidades | Conceitos | Entregáveis | Critérios de conclusão | Cap. |
|---|---|---|---|---|---|---|---|
| 1 | **Foundation** | O projeto do jogo, limpo e organizado | Estrutura de pastas e mapas; módulos; configurações; CI local de testes; tags e catálogos consolidados | Arquitetura (6, 77), convenções | `Vigilia` compilando sem *warnings*; todos os testes verdes; mapas vazios dos 5 espaços | Um build de desenvolvimento abre o Pátio e troca de nível até o final | 77 |
| 2 | **Player** | Helena em qualidade final | Movimento (perfil Vigília), câmera, lanterna com sobrecarga, interação, leitura | Caps. 16–19, 25, 51 | `BP_VGJogadora` final | Playtest de 5 min no Pátio: "o controle some da atenção" | 78 |
| 3 | **Combat** | O sinalizador e o encontro dos vigias | Sinalizador, pistola dos vigias, cobertura, dano e morte | Caps. 20–22, 26–30, 21 | Documento de combate v1.0; sala de teste do encontro | TTK e TTD dentro do documento; telegrafia ≥ 1,2 s em todos os ataques | 79 |
| 4 | **AI** | A Presença e os vigias no jogo real | BTs, percepção, Diretor ajustado por setor, perseguição | Parte V, Cap. 80 | Parâmetros por setor; a perseguição | Playtest: ninguém morre mais de 2 vezes por setor; ninguém atravessa um setor sem sentir a Presença | 80 |
| 5 | **Narrative** | A história inteira no sistema | Quests, conversas, documentos, fatos e cenas dos 3 setores e do final | Parte VI, Cap. 81 | Catálogos completos; auditoria verde | Todos os caminhos do mapa de ramificação jogáveis com cheats; a auditoria de conteúdo passa | 81 |
| 6 | **Level** | Os espaços em qualidade final | Blockout → arte dos setores 2 e 3; vinhetas; iluminação | Caps. 48, 50–51 | Os 4 espaços jogáveis de ponta a ponta | Uma pessoa nova termina o jogo sem ajuda em 10–20 minutos | 79 |
| 7 | **Audio/VFX** | O som e as partículas que fazem o medo | Ambiente, Presença, rádio filtrado, silêncios; efeitos do sinalizador, poeira, faíscas | Caps. 52, 54 | Mixagem por setor | No playtest de olhos fechados, as jogadoras sabem onde a Presença está | 82 |
| 8 | **Save System** | Checkpoints que nunca perdem progresso | Save por checkpoint, load, novo jogo, opções | Caps. 46, 56–57 | Saves versionados | Salvar e carregar em cada checkpoint reproduz o estado (teste automatizado + manual) | 79 |
| 9 | **Polish** | O jogo "parece" pronto | Game feel, ritmo, acessibilidade, bugs | Caps. 55, 82 | Lista de polimento zerada (dentro do prazo) | Nenhum bug "A" aberto; 3 playtests sem travamento | 82–83 |
| 10 | **Release Build** | Um executável que outra pessoa roda | Shipping, empacotamento, branch experimental cooperativo | Caps. 62, 84 | Build Shipping; *postmortem* | O build roda numa máquina limpa; o *postmortem* escrito | 84–85 |

O Projeto 7, o **vertical slice** (Capítulo 78), atravessa os milestones 2, 6, 7 e 9 para os **primeiros cinco minutos**: o prólogo e o começo do setor 1 em qualidade final, antes de produzir o resto. Ele existe para provar que a qualidade final é **alcançável** e para medir quanto ela custa por minuto de jogo, antes de se comprometer com quinze minutos.

---

## 76.8 O cronograma

Com 7 a 10 horas por semana (Introdução, seção 10), a Parte XI tem 14 semanas no cronograma original. Distribuídas pelos milestones:

| Semanas | Milestones | Foco |
|---|---|---|
| 1 | 1 | Fundação, catálogos, testes |
| 2–4 | 2 + vertical slice (2, 6, 7, 9 para os primeiros 5 min) | Qualidade final num trecho pequeno |
| 5–6 | 3, 4 | Combate e IA nos setores 2 e 3 |
| 7–9 | 5, 6 | Narrativa e níveis: o grosso do conteúdo |
| 10 | 7, 8 | Áudio, VFX, save |
| 11–13 | 9 | Polimento e playtests |
| 14 | 10 | Build e *postmortem* |

A regra que o registro de riscos já anunciou: **datas fixas, escopo variável.** Se a semana 9 terminar com o setor 3 incompleto, o que falta vai para o *won't* ou vira uma versão mais simples, e não para "mais uma semana". Para um projeto pessoal, sem prazo externo, essa regra é a única coisa que separa um jogo terminado de um projeto eterno.

---

## Estudos de caso

### Amnesia e Outlast — a unidade de lugar

**[FATO PÚBLICO]** *Amnesia: The Dark Descent* (Frictional Games, 2010) se passa quase inteiro no castelo de Brennenburg. *Outlast* (Red Barrels, 2013) se passa no asilo Mount Massive. Os dois vieram de estúdios independentes pequenos.

**[INFERÊNCIA]** A **unidade de lugar** (um edifício, explorado por dentro) serve a três coisas ao mesmo tempo. Na produção, permite reaproveitar arquitetura, materiais e regras de iluminação. No design, a jogadora aprende a "língua" do espaço e a expectativa cresce, porque ela sabe o que um corredor daquele lugar pode esconder. Na narrativa, o lugar **é** a história (Capítulo 48). É uma escolha de escopo que também é uma escolha estética.

**Lição para a Vigília:** a usina é um lugar só, com quatro espaços que compartilham materiais, linguagem de luz, sons e regras. O inventário de conteúdo (seção 76.4) é viável porque a unidade de lugar barateia cada espaço novo.

### Remedy — pilares como identidade

**[INFERÊNCIA]** Os jogos da Remedy citados neste livro (Max Payne, Alan Wake, Quantum Break, Control) compartilham traços reconhecíveis: um protagonista com voz interior ou narração forte, uma mecânica central ligada ao tema (o tempo, a luz, os poderes) e a integração entre narrativa e jogabilidade, com experimentação de forma (quadrinhos, *live action*). Esses traços funcionam como **pilares de estúdio**: decisões que se repetem de projeto em projeto e dão identidade.

**Lição para a Vigília:** pilares não são uma lista de funcionalidades, são uma identidade. "A luz é recurso, linguagem e defesa" decide coisas que nenhuma funcionalidade isolada decidiria: que a interface é escura, que o rádio chia quando a luz falha, que o final acontece numa sala de comando iluminada.

---

## Comparação com o desenvolvimento tradicional

| Produção de jogo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Página única e documento vivo | *One-pager* e PRD vivo | O "requisito" é uma experiência, verificável só por playtest |
| Pilares | Princípios de produto | Pilares decidem disputas **estéticas**, não só de prioridade |
| MoSCoW com *won't* explícito | Priorização de *backlog* | Cortar conteúdo costuma **melhorar** o produto (ritmo), algo raro com funcionalidades |
| Vertical slice | MVP | O MVP é mínimo em qualidade; o *vertical slice* é **completo** em qualidade e mínimo em extensão |
| Milestones com critérios | *Releases* com *definition of done* | Os critérios incluem sensações medidas em playtest |
| Datas fixas, escopo variável | *Timeboxing* | Funciona melhor em jogos, porque o conteúdo é mais cortável que funcionalidade de negócio |

---

## Unreal Engine: preparação do projeto final

- **Mapas:** `L_Patio`, `L_CasaDeForca`, `L_Subestacao`, `L_Turbinas`, `L_Final` e `L_MenuPrincipal`. A troca é por nível, com carga e persistência (Caps. 56–57). O Salão das Turbinas, o maior espaço, é candidato a *World Partition* ou a níveis em *streaming* (Caps. 57 e 60). Decida no Capítulo 77, com base no profiling.
- ***Primary assets*:** quests, documentos e conversas registrados no Asset Manager, o que facilita o arquivo, a auditoria e o empacotamento (Cap. 62).
- **Mapas e conteúdo de estudo** (Galpão, Arena, protótipos da Parte X) ficam fora do build de lançamento pelas regras de *cook* (Cap. 62), e não apagados: eles são o laboratório do projeto.

---

## Implementação: o documento

Este capítulo não tem código. O entregável é o **documento vivo** `docs/design/vigilia-gdd.md`, com as seções:

```text
VIGÍLIA — DOCUMENTO DE DESIGN (v1.0)
 1. Página única (seção 76.1)
 2. Pilares justificados (76.2)
 3. Curva do jogo (76.3)
 4. Setores (76.4) — um parágrafo de intenção por setor
 5. Inventário de conteúdo (76.4) — TETO, não meta
 6. Escopo MoSCoW (76.5)
 7. Registro de riscos (76.6) — revisado a cada milestone
 8. Milestones com critérios (76.7)
 9. Cronograma (76.8)
10. Índice dos documentos derivados: loops, combate v1.0, narrativa, fatos, quests,
    ramificação, níveis, tags, blackboards
```

E a atualização do **documento de combate para v1.0**:
- a nomenclatura de setores numerada (seção 76.4);
- a sobrecarga da lanterna (Cap. 51) ao lado do sinalizador;
- as perguntas abertas da v0.1 respondidas com os playtests das Partes VI e VII, ou mantidas como perguntas do Milestone 3.

---

## Projeto Final — o ponto de partida

- [ ] `docs/design/vigilia-gdd.md` v1.0, com as dez seções.
- [ ] Documento de combate v1.0.
- [ ] Os cinco mapas vazios criados, com a troca de nível funcionando de ponta a ponta (um gatilho no fim de cada espaço).
- [ ] Os documentos derivados listados, com o que falta marcado.
- [ ] Um quadro de tarefas (qualquer ferramenta) com os dez milestones e as datas da seção 76.8.

---

## Decisões arquiteturais (de produção)

1. **Página única + documento vivo**, este reunindo os documentos dos capítulos anteriores.
2. **Cinco pilares** com experiência, sistemas e custo explícitos; o combate serve à vulnerabilidade.
3. **Estrutura em cinco partes** (prólogo, três setores, final) com escalada de **natureza** da ameaça: cenografia → pessoas → sistema.
4. **Inventário de conteúdo como teto.**
5. **MoSCoW com *won't* explícito**, incluindo IA generativa e multiplayer fora do lançamento.
6. **Registro de riscos com sinais e respostas decididas antes.**
7. **Dez milestones** com critérios verificáveis, e um vertical slice antes do conteúdo.
8. **Datas fixas, escopo variável.**

---

## Armadilhas

- **O documento que ninguém lê.** Se a página única não cabe na cabeça, ela não decide nada.
- **Pilares como lista de funcionalidades** ("o jogo tem lanterna"). Pilar é experiência; funcionalidade é meio.
- **Inventário como meta.** Treze documentos é o máximo, não o objetivo.
- **O *won't* esquecido.** Sem a lista do que **não** entra, tudo entra.
- **Um vertical slice que vira o jogo inteiro.** Cinco minutos, em qualidade final, e mais nada.
- **Risco sem sinal.** "O setor 2 pode atrasar" não ajuda; "mais de duas semanas de atraso no M6" ajuda.
- **Cronograma sem regra de corte.** Toda semana extra parece pequena.
- **Esquecer que o jogo é para outra pessoa.** Critérios de conclusão que só você pode avaliar não são critérios.

---

## Exercício

**Parte 1 — a página (1 h).** Escreva a página única com as suas palavras. Leia em voz alta para alguém que não conhece o projeto e peça que essa pessoa descreva o jogo de volta. Ajuste até a descrição bater.

**Parte 2 — pilares e curva (1,5 h).** Escreva a tabela de pilares e desenhe a curva do jogo inteiro. Para cada pico da curva, aponte o sistema que o produz; para cada vale, o que a jogadora faz nele.

**Parte 3 — inventário, escopo e riscos (2 h).** Preencha o inventário dos setores 2 e 3, o MoSCoW e o registro de riscos. Some as horas estimadas e compare com as 14 semanas: o que precisa ir para o *won't*?

**Parte 4 — milestones e mapas (1,5 h).** Escreva os critérios de conclusão dos dez milestones na sua ferramenta de tarefas e crie os cinco mapas com a troca de nível de ponta a ponta.

---

## Desafio — o *pitch* de dois minutos

Grave um vídeo de dois minutos (captura do *Turno da Noite* com a sua narração) apresentando a Vigília como se fosse para uma banca ou um editor:
- a página única;
- os pilares, cada um mostrado em jogo;
- o que torna este jogo diferente de um "jogo de terror genérico";
- o que você vai entregar e quando.

Mostre para duas pessoas e anote o que elas lembram depois de um dia. O que elas lembram é o que o jogo é, para quem joga.

---

## Uso de IA

1. **Para atacar a página única:**
   > "Atue como produtor sênior de jogos independentes. Aqui está a página única do meu jogo (abaixo). Aponte: o que é vago, o que promete mais do que um desenvolvedor sozinho entrega em 14 semanas de 7 a 10 horas, o que contradiz o próprio 'NÃO É', e qual pilar está mais fraco. Não sugira funcionalidades novas. [página]"

2. **Para revisar o escopo:**
   > "Aqui está o inventário de conteúdo e o MoSCoW do meu jogo, com estimativas de horas por item. Encontre itens subestimados (com base no que costuma custar conteúdo narrativo, iluminação e áudio em jogos pequenos), dependências escondidas entre itens, e proponha os três cortes que menos prejudicam os pilares."

3. **Para pré-mortem:**
   > "Imagine que este projeto (documento abaixo) foi abandonado na semana 10. Escreva o pré-mortem: as cinco causas mais prováveis, os sinais que teriam aparecido antes, e o que eu deveria decidir hoje para evitá-las. [documento]"

**Cuidado específico:** a IA tende a expandir o escopo ("e se o jogo tivesse...") porque ideias são baratas para ela. Peça explicitamente **cortes**, e trate qualquer sugestão de funcionalidade como um item para o *won't* até prova em contrário.

---

## Checklist

- [ ] Tenho uma página única que outra pessoa consegue descrever de volta.
- [ ] Os pilares têm experiência, sistemas e custo, e sei que o combate serve à vulnerabilidade.
- [ ] Desenhei a curva do jogo inteiro e a escalada de natureza da ameaça.
- [ ] O inventário de conteúdo tem números, e eles são teto.
- [ ] O MoSCoW tem um *won't* explícito.
- [ ] O registro de riscos tem sinais e respostas.
- [ ] Os dez milestones têm critérios verificáveis, e o cronograma tem uma regra de corte.

---

## Para ir além

- **Jesse Schell, *The Art of Game Design*** — as lentes sobre experiência, tema e escopo.
- **GDC Vault** (gdcvault.com): postmortems de jogos independentes de terror e de exploração narrativa (procure por Thomas Grip, da Frictional Games, e confira os títulos lá; da Red Barrels, o relato de Philippe Morin sobre a produção de *Outlast* saiu no site da *Game Developer*) e palestras de produção sobre *vertical slices*.
- O seu próprio `DEVLOG.md`: releia-o do Capítulo 1 até aqui antes de escrever os riscos. Os riscos do projeto final já apareceram, em pequeno, ao longo do livro.

---

➡️ **Próximo:** [Capítulo 77 — Arquitetura](cap-77-arquitetura.md)

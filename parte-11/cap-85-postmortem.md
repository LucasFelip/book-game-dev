# Capítulo 85 — Postmortem

## Objetivo

Ao final deste capítulo você deve conseguir:

- escrever um ***postmortem*** honesto e útil: o que deu certo, o que deu errado, com números e com ações;
- fazer o postmortem da Vigília **e** do seu processo de aprendizado, que são coisas diferentes;
- reavaliar o **mapa de competências** da Introdução com evidências, e não com impressões;
- escolher os **próximos passos** de estudo e de projeto com base no que este livro deixou de fora;
- fechar o ciclo com a pergunta que abriu o livro: olhar para um jogo e entender como ele provavelmente funciona por dentro.

---

## Contexto

O Capítulo 84 terminou com um executável que roda numa máquina limpa e um ramo experimental cooperativo. O jogo existe. Falta o último hábito de engenharia, que a indústria de jogos pratica de forma pública há décadas: **olhar para trás com método**.

Um postmortem não é um relatório de status, nem uma celebração, nem uma lista de culpas. É o documento que transforma uma experiência em **conhecimento transferível**: para o próximo projeto, para outra pessoa, para você daqui a dois anos. O nome é mórbido, mas a prática é a mais otimista de todas: ela supõe que haverá um próximo projeto e que ele pode ser melhor.

Este capítulo tem dois postmortems:

1. **O do projeto.** A Vigília, como um jogo feito por uma pessoa.
2. **O do aprendizado.** Este livro, como o caminho de um engenheiro de software para o desenvolvimento de jogos.

---

## 85.1 O formato

**[FATO PÚBLICO]** Durante anos, a revista *Game Developer* (impressa de 1994 a 2013) e o site associado, Gamasutra (que adotou o nome *Game Developer* em 2021), publicaram postmortems de jogos escritos pelos próprios desenvolvedores, num formato que se tornou referência: **o que deu certo** (*What Went Right*) e **o que deu errado** (*What Went Wrong*), em geral cinco de cada, com um resumo do projeto.

O formato funciona porque força **simetria**. Escrever só o que deu errado vira autoflagelação; só o que deu certo vira propaganda. Cinco e cinco obrigam a encontrar as duas coisas e a escolher as mais importantes.

A Vigília usa uma versão estendida:

```text
POSTMORTEM — <projeto>

1. RESUMO        o que é o jogo, quem fez, quanto tempo, ferramentas (um parágrafo)
2. NÚMEROS       planejado × real: semanas, horas, minutos de jogo, conteúdo (inventário),
                 bugs por classe, desempenho (pior frame), resultados de playtest
3. DEU CERTO     5 itens: o que foi, POR QUE deu certo, como repetir
4. DEU ERRADO    5 itens: o que foi, POR QUE deu errado, o que fazer diferente
5. SURPRESAS     o que ninguém (você) previu, para melhor ou para pior
6. AÇÕES         3 a 5 mudanças concretas para o próximo projeto
```

Duas regras de escrita:

- **Sem culpa, com causa.** "Eu fui preguiçoso no áudio" não ensina nada. "O passe de áudio começou na semana 11 porque o de luz não tinha limite de tempo" ensina, e a ação ("todo passe tem limite", Cap. 78) sai sozinha.
- **Números do diário, não da memória.** A memória reescreve projetos. O `DEVLOG.md`, a telemetria (Cap. 78), o registro de riscos (Cap. 76) e o histórico de builds (Cap. 84) são as fontes.

---

## 85.2 O postmortem da Vigília

O que segue é o **modelo** do postmortem da Vigília, com o que o livro pode afirmar (as decisões e o processo) e espaços para o que só o seu projeto pode dizer (os números). Itens marcados **[SEU NÚMERO]** vêm do seu diário. Itens marcados **[HIPOTÉTICO]** são plausíveis, e você os confirma ou corrige.

### Resumo

*Vigília* é um FPS narrativo de terror e investigação, em primeira pessoa, com 10 a 20 minutos de duração, feito por uma pessoa em Unreal Engine 5, com C++ para sistemas e Blueprint e dados para conteúdo, ao longo de [SEU NÚMERO] semanas de 7 a 10 horas. Uma perita entra à noite numa usina desativada desde 1994, onde as turbinas voltaram a girar.

### Números

| Medida | Planejado (Cap. 76) | Real |
|---|---|---|
| Semanas da Parte XI | 14 | [SEU NÚMERO] |
| Minutos de jogo (mediana dos playtests) | 10–20 | [SEU NÚMERO] |
| Documentos / conversas / cenas | ≤ 13 / ≤ 23 / ≤ 10 | [SEU NÚMERO] |
| Custo por minuto (vertical slice) | — | [SEU NÚMERO] h/min |
| Bugs A abertos no release | 0 | [SEU NÚMERO] |
| Pior frame na máquina-alvo (build Test) | ≤ 16,67 ms | [SEU NÚMERO] |
| Sucesso na perseguição na 1ª tentativa | 70–85% | [SEU NÚMERO] |
| Código novo nos setores 2 e 3 | "muito pouco" | [SEU NÚMERO] linhas (Cap. 79) |

### O que deu certo

**1. A dor antes da arquitetura.** O Interlúdio I foi feito errado de propósito, e as doze dores que ele produziu viraram a especificação da Parte VI. Os sistemas narrativos foram aceitos como **resposta**, não como imposição, e cada um resolveu algo que já tinha doído. *Como repetir:* para todo sistema grande, faça antes a versão ingênua e anote as dores.

**2. Dados em vez de cola.** Diálogo, quests, fatos, documentos e cenas viraram dados interpretados por sistemas pequenos. O setor 2 foi montado quase sem código (Capítulo 79), e a ramificação, auditada por um teste (Capítulo 47). *Como repetir:* quando o mesmo tipo de lógica aparece pela terceira vez em Blueprints, ela vira um dado.

**3. Um dono para cada estado.** Do Capítulo 4 ao 77, a regra do dono único decidiu disputas e evitou classes inteiras de bugs. A tabela de donos (Capítulo 77) com "salvo?" e "relógio" explicou bugs antes que eles acontecessem. *Como repetir:* nenhum estado sem dono escrito.

**4. Testes de regras puras e de conteúdo.** Regras de objetivo, diálogo, quest, leitura, save, puzzle e utilidade ficaram em funções puras com um teste cada. Manifestos e auditoria testaram o **conteúdo**. *Como repetir:* separe a regra da cola antes de escrever o teste, e o teste sai barato.

**5. Medir antes de decidir.** O custo por minuto do vertical slice, a telemetria dos playtests, o orçamento de frame e o profiling transformaram "acho que dá" em números discutíveis, e o escopo foi cortado cedo. *Como repetir:* toda decisão de escopo ou de performance cita um número.

### O que deu errado [HIPOTÉTICO — confirme ou troque pelos seus]

**1. Abstrações por previsão.** A HFSM genérica do Capítulo 34 foi construída para dois usos previstos, e nenhum chegou (Capítulo 42). Outras peças do laboratório (a grade espacial, o pool de sinalizadores) foram recusadas a tempo, mas a primeira não foi. *O que fazer diferente:* o critério do "terceiro caso" (Capítulo 6) vale para usos **existentes**, não previstos.

**2. Conteúdo é mais caro que código.** O número do vertical slice surpreendeu: a arte e o áudio de um minuto de jogo custaram mais que vários sistemas inteiros. O inventário do Capítulo 76 foi cortado na semana [SEU NÚMERO]. *O que fazer diferente:* faça o vertical slice **antes** de fixar o inventário, e não depois.

**3. Decisões de pasta que erodiram.** O GameMode e o mix de áudio moraram em `Core` sem pertencer à base, e a arquitetura só foi verificada no Capítulo 77. *O que fazer diferente:* o verificador de camadas desde o primeiro dia.

**4. Números de engine assumidos sem leitura.** Comportamentos da engine (a memória de nó das BTs, as flags dos *services*, a ordem de `BeginPlay`, o foco do `AIController`) foram assumidos e depois corrigidos na revisão técnica (`revisao-2026-11-03.md`). *O que fazer diferente:* a escada de verificação do Capítulo 69 (compilar → testar → PIE → **ler o código da engine**) antes de escrever sobre a engine.

**5. Playtests tarde demais em alguns sistemas.** A leitura que congela o Diretor (Capítulo 42) só apareceu na análise de loops do Capítulo 70; um playtest com telemetria teria mostrado antes. *O que fazer diferente:* telemetria desde o protótipo.

### Surpresas

- **O barramento era a telemetria.** Um sistema feito para desacoplar (Capítulo 24) virou, sem nenhuma mudança, a fonte de dados dos playtests (Capítulo 78).
- **As mudanças foram de dono, não de algoritmo.** Do Interlúdio I ao multiplayer cooperativo, as refatorações grandes mudaram **quem é responsável por quê**, e quase nunca **como** algo é calculado (Capítulo 77).
- **A ambiguidade dá trabalho.** Manter a lista `[NUNCA]` (Capítulo 81) foi mais difícil do que escrever as respostas, porque cada sistema pode revelar sem querer (uma legenda, um nome de asset, uma conquista).

### Ações para o próximo projeto

1. Protótipo ingênuo e diário de dores antes de qualquer sistema grande.
2. Verificador de camadas, telemetria e testes de conteúdo desde a primeira semana.
3. Vertical slice antes do inventário de conteúdo.
4. Abstrações só para usos existentes.
5. A escada de verificação antes de afirmar qualquer coisa sobre a engine.

---

## 85.3 O postmortem do aprendizado

O projeto e o aprendizado não são a mesma coisa. Um jogo pode ficar bom com um aprendizado raso (copiando tutoriais), e um jogo pode ficar mediano com um aprendizado profundo (quando cada sistema foi entendido, e o tempo acabou antes do polimento). O livro foi desenhado para o segundo caso.

### O mapa de competências, revisitado

A Introdução (seção 4.3) estimou o ponto de partida e a meta em cada área, numa escala de 0 a 5. Refaça a tabela com **evidências**: para cada nota, cite o que você construiu que a justifica.

| Área | Início | Meta | Agora | Evidência (o que você construiu) |
|---|:-:|:-:|:-:|---|
| Modelo mental de tempo real | 1 | 4 | | O relógio de cada sistema na tabela de donos (Cap. 77) |
| Matemática 3D aplicada | 2 | 4 | | Hitscan, recuo, percepção, EQS |
| C++ moderno | 1–2 | 3 | | |
| Dialeto Unreal (UObject, reflexão, GC) | 0 | 4 | | |
| Editor, assets, conteúdo | 0 | 3 | | O vertical slice |
| Gameplay programming | 0 | 4 | | Partes III–IV |
| Game design | 1 | 3 | | Documentos de loops, combate, narrativa |
| Level design | 0 | 3 | | Os quatro espaços |
| Game AI | 1 | 4 | | A Presença e os vigias |
| Sistemas narrativos | 0 | 4 | | A Parte VI e o Cap. 81 |
| Luz, áudio, animação, VFX, UI | 0 | 2–3 | | O vertical slice |
| Save e persistência | 1 | 4 | | A matriz de checkpoints |
| Performance e profiling | 1 | 3 | | O orçamento e o profiling do jogo |
| Networking | 2 | 3–4 | | A Arena e o ramo cooperativo |
| IA generativa em jogos | 3 | 4 | | O protótipo e o ADR-0010 |
| Produção | 1 | 3 | | Este postmortem |

O critério de nota é o da escala da Introdução, levado a sério. **Nota 3** significa ter implementado sozinho uma versão funcional; **nota 4**, ter projetado, justificado *trade-offs* e refatorado quando o sistema cresceu. Uma nota 4 sem um 🔁 que você mesmo tenha feito é otimista demais.

### O que o livro deixou de fora

Um postmortem honesto de um livro de estudos também lista os buracos. Este deixou de fora, ou tratou só por cima:

- **Programação gráfica e de *shaders***: materiais foram usados, mas não escritos a fundo; o *pipeline* de renderização foi visto pelo lado do desempenho, não da implementação.
- **Física em profundidade**: colisão, traces e ragdoll, sim; *solvers*, veículos e destruição, só conceitualmente (Interlúdios II e III).
- **Animação técnica**: *Motion Matching*, *Control Rig* e *retargeting* ficaram fora de escopo (Cap. 53).
- ***Tools programming***: módulos de editor, ferramentas de nível e *commandlets* apareceram pouco.
- **Plataformas e certificação**: console, requisitos de certificação, *ports*.
- **Áudio técnico**: *middleware* de áudio e *DSP* além do MetaSounds básico.
- **Negócio**: publicação, *marketing*, contratos.

Cada item da lista é um próximo passo possível, e o mapa de competências diz quais importam para você.

---

## 85.4 Próximos passos

### Para o projeto

- **Publicar.** Um jogo pequeno publicado ensina coisas que nenhum livro ensina: o que as pessoas fazem quando você não está olhando, como elas descrevem o seu jogo, o que quebra em máquinas que você nunca viu. Uma página de jogo independente e gratuita é suficiente.
- **Terminar o ramo cooperativo**, ou decidir conscientemente não terminá-lo (outro ADR). O ponto de partida é o inventário de quebras C1–C16 e o `docs/coop/relatorio.md` do Capítulo 84.
- **Um setor a mais**: o desafio do Capítulo 79, levado ao fim, é o melhor teste da sua arquitetura.

### Para o estudo

| Se você gostou de… | Estude a seguir | Por onde começar |
|---|---|---|
| Parte V (Game AI) | Planejamento (GOAP, HTN) em produção, IA de grupos grandes | *Game AI Pro*; o Mass Entity da Unreal |
| Parte VI (narrativa) | Linguagens de narrativa (Ink, Yarn Spinner) e *storylets* | A documentação do Ink; os textos de Emily Short |
| Parte VIII (engenharia) | Renderização, memória e otimização de baixo nível | *Game Engine Architecture* (Gregory); o código-fonte da engine |
| Parte IX (multiplayer) | Servidores dedicados em escala, *rollback netcode* | *Multiplayer Game Programming* (Glazer e Madhav); os artigos de Gambetta |
| Parte X (IA generativa) | Avaliação de modelos, segurança de conteúdo em produção | A documentação dos provedores que você usar; a literatura de avaliação |
| Tudo | Fazer outro jogo pequeno, de outro gênero | Uma *game jam*: prazo fixo, escopo pequeno |

Uma recomendação que vale para todas as linhas: **faça outro jogo pequeno, de outro gênero e, de preferência, em outra engine.** O que se transfere entre engines é o conhecimento de verdade; o que não se transfere era detalhe de ferramenta. Este livro apostou que o primeiro é maior que o segundo, e a única forma de confirmar é tentar.

---

## 85.5 A pergunta do começo

A spec deste livro terminava com um objetivo:

> *"Entendo como esse sistema provavelmente funciona internamente e consigo construir uma versão simplificada dele."*

E não apenas:

> *"Sei apertar os botões da Unreal."*

Ao longo do livro, a Ficha de Decomposição da Introdução (seção 5) foi aplicada dezenas de vezes: a luz em Alan Wake, a física de GTA IV, o rádio de Firewatch, os dois cérebros de Alien: Isolation, os tickets do Battlefield. Ela sempre seguiu os mesmos passos:

1. a experiência;
2. o sistema que a produz;
3. a decisão de design por trás dele;
4. a tecnologia;
5. a versão simplificada;
6. a lição.

O exercício final deste livro é aplicá-la **sem o livro**:

1. Escolha um jogo das suas referências que o livro **não** decompôs em detalhe, por exemplo o *bullet time* de Max Payne 2, as habilidades de Control ou a IA de adversários de um jogo de futebol.
2. Jogue com intenção, por uma hora, e escreva a ficha: experiência, sistema, decisão, tecnologia, versão simplificada, lição. Marque cada afirmação como fato ou inferência.
3. Em uma semana de estudo (7 a 10 horas), construa a versão simplificada num projeto novo, reaproveitando o que quiser da Vigília.
4. Escreva um parágrafo para o seu eu do começo do livro: o que você viu naquele jogo que antes não via.

Se o passo 3 for possível em uma semana, o livro fez o que prometeu.

---

## Estudo de caso: o postmortem como cultura

**[FATO PÚBLICO]** Além dos postmortems escritos, a GDC mantém há anos sessões de postmortem em que desenvolvedores apresentam a história de um jogo, inclusive dos que fracassaram comercialmente ou tiveram produções difíceis. Muitas dessas palestras estão no GDC Vault.

**[INFERÊNCIA]** A prática pública de postmortem é uma das razões pelas quais o conhecimento de desenvolvimento de jogos circula, apesar de quase todo código de jogo comercial ser fechado. As decisões, os erros e os números de produção são compartilhados mesmo quando o código não é. Boa parte do que este livro afirmou com o rótulo **[FATO PÚBLICO]** veio dessa cultura.

**Lição para você:** escrever o postmortem da Vigília e, se quiser, publicá-lo, é participar dessa cultura. O texto que ensina outra pessoa a não cometer o seu erro é a forma mais barata de retribuir o que se aprendeu com os postmortems dos outros.

---

## Comparação com o desenvolvimento tradicional

| Postmortem de jogo | O que você conhece | Onde a analogia cai |
|---|---|---|
| Deu certo / deu errado | Retrospectiva ágil; *postmortem* de incidente | Cobre o projeto inteiro e inclui decisões **estéticas** |
| Sem culpa, com causa | *Blameless postmortem* | — (a prática é a mesma) |
| Números do diário | Métricas de entrega | Inclui medidas de experiência (playtest) |
| Publicar o postmortem | Relatórios públicos de incidente | É uma tradição cultural da indústria, não uma obrigação |

---

## Unreal Engine: depois do livro

A engine continua mudando, versão após versão: sistemas de replicação, ferramentas de animação, *World Partition*, *Motion Matching*, ferramentas de IA. Três hábitos protegem o que você aprendeu:

1. **Leia as notas de versão** e marque o que toca nos seus sistemas.
2. **Leia o código da engine** quando um comportamento surpreender. Ele é a fonte da verdade (Capítulo 69).
3. **Mantenha os testes rodando a cada atualização de versão.** As regras puras e os testes de conteúdo vão dizer o que a atualização quebrou antes que uma jogadora diga.

---

## Implementação: o documento

Este capítulo não tem código. O entregável é `docs/postmortem.md`, com o formato da seção 85.1, os números da tabela da seção 85.2 vindos do seu diário, e o mapa de competências da seção 85.3 com evidências.

---

## Projeto Final — o fechamento

- [ ] `docs/postmortem.md` escrito, com cinco e cinco, números e ações.
- [ ] O mapa de competências refeito, com evidências por linha.
- [ ] Os próximos passos escolhidos: um projeto, uma área de estudo, uma data.
- [ ] O `DEVLOG.md` arquivado junto com o build de release e os símbolos (Cap. 84).
- [ ] O exercício final da seção 85.5 marcado no calendário.

---

## Decisões arquiteturais (de carreira)

1. **Postmortem com simetria, números e ações**, sem culpa e com causa.
2. **Dois postmortems**: o do jogo e o do aprendizado.
3. **Competências avaliadas com evidência**; nota 4 exige um 🔁 próprio.
4. **O próximo projeto é pequeno, de outro gênero e, se possível, em outra engine.**

---

## Armadilhas

- **Postmortem de memória.** A memória reescreve projetos; use o diário.
- **Só o que deu errado.** Sem o que deu certo, você não sabe o que repetir.
- **Lição sem ação.** "Planejar melhor" não é uma ação; "todo passe tem limite de tempo" é.
- **Notas de competência por impressão.** Sem evidência, o mapa é uma autoavaliação de humor.
- **Começar um projeto grande demais em seguida.** O próximo projeto deveria ser **menor** que a Vigília, para que você o termine e compare.

---

## Exercício

**Parte 1 — o postmortem (2 h).** Escreva o `docs/postmortem.md` com os números do seu diário. Releia o registro de riscos do Capítulo 76: quais riscos aconteceram? Os sinais apareceram a tempo? As respostas decididas antes funcionaram?

**Parte 2 — o mapa (1 h).** Refaça o mapa de competências com evidências. Escolha as duas áreas com maior distância entre "agora" e o que você quer, e escreva o primeiro passo de cada uma.

**Parte 3 — a decomposição final (1 semana).** O exercício da seção 85.5.

---

## Desafio — o jogo de outro

Escolha um jogo que você **não** conhece bem (de preferência de um gênero que este livro não tratou: corrida, plataforma, estratégia). Jogue uma hora e escreva a Ficha de Decomposição de três sistemas dele, sem pesquisar nada. Depois, procure postmortems, palestras ou documentação sobre esses sistemas e compare. Quanto das suas inferências se confirmou? O que você errou, e por quê?

A distância entre as suas inferências e os fatos é a medida mais honesta do que este livro ensinou.

---

## Uso de IA

1. **Para escrever o postmortem com honestidade:**
   > "Aqui está o diário do meu projeto (DEVLOG, registro de riscos, números de playtest e de performance; abaixo). Sem elogios e sem críticas genéricas, proponha cinco 'deu certo' e cinco 'deu errado', cada um com a **causa** que o diário sustenta e a linha do diário que a mostra. Se o diário não sustentar algo, diga que não sustenta. [diário]"

2. **Para avaliar as competências:**
   > "Aqui está a minha tabela de competências com as evidências que eu citei (abaixo) e a escala de 0 a 5 com a definição de cada nível. Para cada linha, diga se a evidência justifica a nota que eu me dei, uma nota abaixo ou uma acima, e por quê. [tabela + escala]"

3. **Para planejar o próximo passo:**
   > "Terminei um jogo narrativo de terror de 15 minutos em Unreal Engine 5, sozinho, como estudo. As áreas que eu quero desenvolver são [áreas]. Proponha três projetos pequenos (até 6 semanas de 8 horas), cada um num gênero diferente, que exercitem essas áreas, com o risco principal de cada um."

**Cuidado específico:** a IA tende a ser generosa em avaliações e a transformar postmortems em narrativas de sucesso. O primeiro pedido exige que cada afirmação aponte uma linha do diário. Mantenha essa exigência: um postmortem sem fonte é ficção.

---

## Checklist

- [ ] Escrevi o postmortem da Vigília com simetria, números e ações.
- [ ] Escrevi o postmortem do meu aprendizado, com o mapa de competências e evidências.
- [ ] Sei o que este livro deixou de fora e o que vou estudar a seguir.
- [ ] Escolhi o próximo projeto: menor, de outro gênero.
- [ ] Consigo olhar para um jogo e decompor um sistema dele até uma versão simplificada que eu saberia construir.

---

## Para ir além

- **GDC Vault** (gdcvault.com): as sessões de postmortem clássicas e recentes.
- **O arquivo de postmortems da *Game Developer*** (o site da revista mantém o histórico dos textos publicados no formato "What Went Right / What Went Wrong").
- **Os livros citados ao longo do caminho**, agora com outros olhos: *Game Programming Patterns* (Nystrom), *Game Engine Architecture* (Gregory), *The Art of Game Design* (Schell), *Multiplayer Game Programming* (Glazer e Madhav).

---

## Estado do Livro — final

- **Capítulos concluídos:** Introdução; Caps. 1–85 (Partes I–XI); Interlúdios I, II e III.
- **Projetos:** 1 (Pátio), 2 (Galpão), 3 (Interação), 4 (Turno da Noite, ingênuo), 5 (IA), 6 (sistema narrativo), Arena (multiplayer), Quarteirão Vivo (laboratório de mundo aberto), 7 (vertical slice) e o Projeto Final, *Vigília*, com o ramo experimental cooperativo.
- **O que fica:** um jogo terminado, um diário, uma arquitetura que você sabe justificar, e o hábito de perguntar, diante de qualquer jogo, *que sistema produz esta experiência?*

---

*Fim.*

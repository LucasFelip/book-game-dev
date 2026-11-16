# INTERLÚDIO II — Decompondo um mundo aberto

*GTA: San Andreas, IV e V como estudo de sistemas, e um quarteirão vivo no laboratório da Vigília.*

---

## Objetivo

Ao final deste interlúdio você deve conseguir:

- decompor um mundo aberto em **sistemas pequenos e implementáveis** (streaming, população, simulação em segundo plano, horários, *wanted system*, missões, física sistêmica), separando **[FATO PÚBLICO]** de **[INFERÊNCIA]**;
- explicar "o mundo continua existindo quando eu não estou olhando" como **bolha**, **memória** e **fabricação**;
- reconhecer as peças da Unreal (World Partition, Level Streaming, Data Layers, HLOD, Mass, *significance*, pooling) e o que cada uma **não** resolve;
- argumentar, com exemplos, por que a arquitetura **adequada para um jogo** costuma ser mais simples, e mais certa, que a **tecnicamente elegante**;
- construir o **Quarteirão Vivo**: população com orçamento e pool, densidade por zona e horário, nível de alerta com calor e decaimento, e LOD de simulação.

---

## Contexto

O livro vem prometendo este interlúdio desde o começo. O Capítulo 1 chamou GTA V de "simulação de *um pedaço da cidade em volta de você*, disfarçada de cidade inteira". O Capítulo 8 deixou em aberto spawn fora de vista, despawn por relevância e pooling. O Capítulo 16 concluiu que o mundo que continua existindo é, em boa parte, **decidido no momento em que eu volto a olhar**. Aqui essas pontas se juntam.

O lugar é deliberado. A Parte VIII deu o vocabulário de engenharia: o que persiste (Caps. 56–57), quanto custa um quadro (Cap. 58) e como cortar custo com LOD, World Partition, *significance* e pooling (Cap. 60). A Parte IX vai quebrar a premissa central deste interlúdio, a de que há **uma** jogadora olhando.

E a advertência da spec: **não vamos reproduzir a escala de GTA**. A Vigília continua sendo uma usina à noite. O objetivo é aprender a decompor, e as técnicas de mundo aberto servem a qualquer jogo que precise parecer maior do que é.

---

## 1. O mapa do mundo aberto

O diagrama de partida é o da spec, com uma correção no rodapé:

```text
                          MUNDO ABERTO
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
      MUNDO               PERSONAGENS              GAMEPLAY
    streaming              população               missões
    relógio, clima         IA ambiente             wanted
    física                 animação, percepção     veículos
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               ▼
                      SIMULAÇÃO DO MUNDO
          não é um sistema que simula a cidade: é a política que
          decide ONDE cada sistema gasta o orçamento do quadro
```

O erro natural de quem vem de sistemas corporativos é ler "simulação do mundo" como um serviço central que mantém o estado de tudo. A aritmética proíbe: com 16,67 ms por quadro (Cap. 58), não há como dar IA, animação e física a milhares de pedestres e carros. O que existe é uma divisão da verdade em três camadas:

| Camada | O que é | Custo | Exemplo |
|---|---|---|---|
| **Bolha** | Atores de verdade, com IA, animação e física, só perto da jogadora | Alto, com orçamento | Os pedestres da sua calçada |
| **Memória** | O que a jogadora mudou e pode verificar: fatos, agregados, poucos objetos com identidade | Baixo, persistido | O território conquistado; o carro na garagem |
| **Fabricação** | O que ela não vê é decidido quando olhar, coerente com relógio e memória | Quase zero | Franklin "estava" dirigindo quando você trocou para ele |

"O mundo continua existindo quando eu não estou olhando" é uma promessa com três cláusulas. **Perto**, o mundo é simulado. **O que eu mudei**, o mundo lembra. **O resto**, o mundo inventa de forma plausível quando eu volto. As seções 2 a 8 aplicam a Ficha de Decomposição a cada sistema; a 9 junta tudo.

---

## 2. Streaming de mundo

**Experiência.** Atravessar um estado inteiro sem telas de carregamento. Em *San Andreas*, a sensação de que "jogos podem ser mundos inteiros" vem, antes de tudo, de **não haver costuras**.

**O que é público.** **[FATO PÚBLICO]** *GTA: San Andreas* (Rockstar, 2004) saiu primeiro para o PlayStation 2, um console com 32 MB de memória principal, e reúne três cidades (Los Santos, San Fierro e Las Venturas) e o interior entre elas. **[FATO PÚBLICO — observável jogando]** Dirigir entre as cidades não tem tela de carregamento; entrar em muitos interiores tem uma transição curta. No começo, as outras cidades estão bloqueadas, e quem atravessa a fronteira cedo recebe um nível de procurado alto. Em *GTA V* (2013), a troca de personagem passa por uma vista aérea (Cap. 16).

**Sistema.** **[INFERÊNCIA]** É compatível com um mundo em pedaços carregados conforme a posição (e, plausivelmente, a velocidade) da jogadora, com baixo detalhe para o que está longe e interiores como unidades separadas, carregadas sob uma transição.

**Design.** O **bloqueio de regiões** é progressão de história e, ao mesmo tempo, reduz o espaço que a jogadora alcança cedo. Os **interiores separados** aceitam uma costura curta onde ela é natural (uma porta). A **transição aérea** de GTA V transforma um salto caro em espetáculo que comunica geografia. Nada disso prova como a Rockstar faz streaming; mostra onde o design aceitou costuras e onde as escondeu.

**Tecnologia.** Na Unreal, o **World Partition** divide o nível numa grade e carrega células conforme **fontes de streaming** (por padrão, os *player controllers*) e o raio de carregamento da grade. O **HLOD** desenha uma versão simplificada das células distantes. **Level Streaming** e **Level Instances** cuidam de unidades separadas, como interiores. A configuração fica para o Capítulo 60.

**Versão mínima.** A Vigília já faz o modelo de *San Andreas*: o Pátio (`L_Patio`) é o exterior, e a Casa de Força (`L_CasaDeForca`), um interior separado por uma porta. O Exercício acrescenta um nível com World Partition para você **ver** células carregando.

**Lição.** Streaming é um orçamento de memória com uma decisão de design acoplada: **onde a costura é aceitável**. E tudo o que depende de atores precisa caber **dentro** do que está carregado (a regra dos anéis, na seção "Unreal Engine").

---

## 3. População ao redor da jogadora

**Experiência.** Uma cidade cheia, que muda de cara entre bairros e entre o dia e a noite.

**O que é público.** O Capítulo 8 registrou o essencial: **[FATO PÚBLICO — observável jogando]** em GTA V, pedestres e veículos aparecem ao redor da jogadora, os que saem de vista podem sumir, e densidade e tipo variam por bairro e horário. Acrescente uma impressão que jogadores comentam há vários jogos da série: dirigindo um modelo de carro, a jogadora passa a ver **mais carros do mesmo modelo** nas ruas. A impressão é observável; a causa não é pública.

**Sistema.**

```text
                 fora de vista por 2 s → volta ao pool
          ┌───────────────────────────────────────────────┐
          │   anel de spawn: fora de vista, ponto livre   │
          │      ┌─────────────────────────────────┐      │
          │      │  zona sem spawn: perto demais   │      │
          │      │         (seria visto)           │      │
          │      │             ● jogadora           │      │
          │      └─────────────────────────────────┘      │
          └───────────────────────────────────────────────┘
                          raio de despawn

 alvo de vivos = orçamento × densidade(zona, hora) × escala(eventos)
```

O **orçamento** (máximo de vivos) define o custo; a **densidade** por zona e hora, quanto dele se usa agora. A folga entre o anel de spawn e o raio de despawn impede um figurante de nascer e sumir no mesmo lugar.

**Design.** Densidade é **pacing**: a rua vazia às quatro da manhã produz outra emoção que a mesma rua ao meio-dia, e a jogadora lê o horário pela rua antes de olhar o relógio.

**Tecnologia.** **[INFERÊNCIA]** Os carros repetidos são compatíveis com uma população que **prefere modelos já carregados na memória**: o carro da jogadora está obrigatoriamente carregado, e escolhê-lo para o tráfego não custa streaming. Seria um sistema que se subordina a outro: a população escolhe **dentro** do orçamento de memória do streaming.

Na Unreal há dois caminhos. Com **atores**, você usa o que o livro já tem (Cap. 32 e Parte V), e o custo cresce com cada ator. Com **Mass**, o framework ECS da Unreal (Cap. 6), agentes são dados processados em lote. **[FATO PÚBLICO]** O *City Sample* da Epic usa Mass para multidões e tráfego com milhares de agentes. ⚠️ Os nomes dos plugins (MassGameplay, MassAI, MassCrowd, ZoneGraph) e o estado de cada um variam por versão.

**Versão mínima.** `UVGPopulationSubsystem`, no Projeto.

**Lição.** O Capítulo 32 mandou fazer pool só com evidência e só de atores simples. A população, com rotatividade constante, é o caso canônico em que ele compensa, e a consequência inverte a intuição: **o figurante é projetado para ser simples**, não o pool para aguentar um figurante complexo.

> 🌉 **Ponte:** é *autoscaling* com capacidade-alvo: um alvo calculado pela demanda, um teto de custo e um *scale-in* gradual.
>
> 🧱 **Onde a ponte cai:** a "demanda" é o que **uma pessoa percebe**, não carga medida. E o *scale-in* tem uma regra que nenhum orquestrador conhece: nenhuma instância é desligada **enquanto alguém olha para ela**.

---

## 4. Simulação em segundo plano e LOD de simulação

**Experiência.** O mundo não pausa quando você vira as costas: o personagem que você deixou está em outro lugar quando volta.

**O que é público.** **[FATO PÚBLICO — observável jogando]** Em GTA V, ao trocar de protagonista, o personagem é encontrado no meio de alguma atividade (Cap. 16).

**Sistema.** **[SIMPLIFICAÇÃO DIDÁTICA]** Um LOD de simulação em quatro níveis:

| Nível | Quando | O que roda | O que deixa de rodar |
|---|---|---|---|
| **Full** | Perto, ou à vista | Tudo: IA, percepção, animação, física, ser testemunha | — |
| **Reduced** | Médio, fora de vista | Movimento e IA em frequência baixa | Animação (não renderizada), física simulada, percepção fina |
| **Registro** | Longe | Nenhum ator; um registro com posição, destino, horário | Tudo o que é ator |
| **Inexistente** | Fora do interesse | Nada; fabricado sob demanda | — |

**Design.** A pergunta é "o LOD pode mudar o resultado?". Pode, desde que a jogadora **não consiga provar** a diferença. Um pedestre em `Reduced` não testemunha crimes, e a jogadora, que não o está vendo, não tem como saber que ele "deveria" ter visto. Já um pedestre à vista que some, ou que atravessa uma parede porque a colisão foi desligada, é uma prova, e quebra o pacto.

**Tecnologia.** **[INFERÊNCIA]** "Registro" e "inexistente" dispensam simulação contínua: uma rota de ônibus pode ser **avaliada por fórmula** (`posição = rota(hora atual)`) quando alguém precisa saber onde o ônibus está. Na Unreal, as alavancas para `Reduced` são o intervalo de tick de atores e componentes, as *Update Rate Optimizations* das malhas esqueléticas e não animar o que não é renderizado (`VisibilityBasedAnimTickOption`). O **Significance Manager** centraliza "quão importante é isto agora", e o Mass tem LOD de simulação e de representação próprios. O Capítulo 60 trata cada um; ⚠️ confira nomes e padrões na sua versão.

**Versão mínima.** O Projeto implementa `Full` e `Reduced`, e trata "longe e fora de vista" como devolução ao pool. `Registro` é o Desafio.

**Lição.** Simulação em segundo plano não é um *thread* que simula o mundo escondido. É uma **escada de fidelidade**, e cada degrau só serve onde a jogadora não vê a diferença.

> 🌉 **Ponte:** é avaliação preguiçosa: o valor só é computado quando alguém o lê.
>
> 🧱 **Onde a ponte cai:** a avaliação preguiçosa de um banco precisa dar o **mesmo** resultado que a ansiosa. A do jogo só precisa dar um resultado **plausível**, e ninguém vai auditar a diferença.

---

## 5. Scheduling e horários

**Experiência.** Um mundo com rotina: a cidade acorda, trabalha, sai à noite.

**O que é público.** **[FATO PÚBLICO — observável jogando]** *San Andreas* tem um relógio acelerado em que um minuto de jogo dura um segundo real, de modo que um dia inteiro passa em 24 minutos. Algumas atividades dependem do horário: as missões de arrombamento só podem ser iniciadas à noite. Os jogos seguintes mantêm relógio acelerado, clima e população que muda com a hora.

**Sistema.** Um **relógio** com dono único, **janelas de horário** usadas como condições (como fatos, no Cap. 46), **curvas de densidade** por hora e, para personagens com nome, **agendas** como dados: "das 22h às 6h, na Casa de Força".

**Design.** Comprimir o dia em minutos é decisão de design: a jogadora vê noite e dia na mesma sessão, e o horário vira recurso de jogo (esperar a noite para uma missão).

**Tecnologia.** **[INFERÊNCIA]** Agendas consultadas sob demanda, e não executadas, deixam pular o tempo de graça. Se cada NPC simulasse o próprio dia, dormir oito horas exigiria simular oito horas; se a agenda é uma tabela consultada quando alguém olha, avançar o relógio é mudar um número.

**Versão mínima.** `UVGWorldClockSubsystem` e duas regras puras: densidade interpolada por hora e "esta hora está na janela?", inclusive janelas que cruzam a meia-noite.

**Lição.** A agenda de um mundo aberto é mais **consulta** do que **execução**.

> 🌉 **Ponte:** parece `cron`.
>
> 🧱 **Onde a ponte cai:** o `cron` executa o job na hora marcada, haja ou não interessados. A agenda de um NPC não executa nada: só responde "onde ele estaria agora?" quando alguém pergunta, e quase nunca alguém pergunta.

---

## 6. *Wanted system*: calor, decaimento e escalada

O Capítulo 4 decompôs o nível de procurado como **estado + eventos + percepção**. Aqui entra o que ficou de fora: **decaimento**, **histerese** e **escalada da resposta** como dados.

**Experiência.** Consequência que escala de forma legível, e cada fuga como uma pequena história improvisada.

**O que é público.** Além do Capítulo 4 (seis estrelas em *San Andreas*, o círculo de busca de *GTA IV*, os cones de visão de GTA V): **[FATO PÚBLICO — observável jogando]** em GTA V o máximo é de cinco estrelas, que **piscam** enquanto a polícia procura sem ver a jogadora.

**Sistema.**

```text
 INCIDENTE (gravidade) ──► testemunhado? ──não──► nada aconteceu, para o mundo
                                │ sim
                                ▼
                CALOR (contínuo, interno) ── soma, com teto
                                │
           sem ser vista por N s: o calor decai
                                │
                                ▼
 NÍVEL (discreto, exibido) ◄── limiares com histerese
                                │ mudou?
                                ▼
     RESPOSTA (dados por nível): unidades, tipos, alarme, música, rua que esvazia
```

**Design.** Separar **calor** de **nível** resolve uma tensão do Capítulo 4. A jogadora precisa de um estado **legível** (três luzes, cinco estrelas); o sistema precisa de um valor **contínuo** para somar gravidades diferentes e decair suavemente. O calor é o motor; o nível, a interface. A **histerese** impede o nível de piscar na fronteira. O **decaimento só fora de vista** transforma a punição em atividade: escapar é sair da vista, não esperar.

**Tecnologia.** **[INFERÊNCIA]** A resposta policial é, ela mesma, **população com intenção**: unidades nascem fora de vista, num anel, com orçamento por nível. É a maquinaria da seção 3 com outro perfil.

**Versão mínima.** `VGAlertRules` e `UVGAlertSubsystem`, no Projeto, com incidentes pelo barramento do Capítulo 24.

**Lição.** Um estado pequeno e legível, com entrada filtrada por percepção e saída em dados, gera mais jogo que um sistema "completo".

> 🌉 **Ponte:** o calor com decaimento é um ***leaky bucket***: incidentes enchem o balde, o tempo esvazia.
>
> 🧱 **Onde a ponte cai:** o *rate limiter* é invisível e vaza sempre. Este balde é a interface do jogo, e **só vaza quando ninguém está vendo a jogadora**.

Não confunda com o **nível de ameaça** do Capítulo 36: a ameaça é o que **a Presença** sabe da jogadora; o alerta é o que **o mundo humano** sabe. Donos, entradas e consumidores diferentes.

---

## 7. Missões num mundo que não para

O Capítulo 45 tratou missões como programas (o `main.scm` de *San Andreas*) e quests como dados. O mundo aberto acrescenta um problema que o *Turno da Noite* não tinha: sistemas que continuam rodando durante a missão.

**Experiência.** Uma história roteirizada que acontece **no meio** de uma cidade que não para.

**O que é público.** **[FATO PÚBLICO — observável jogando]** Em *San Andreas*, missões começam em marcadores no mundo, com a letra de quem dá a missão no radar, e falham se um personagem ou veículo essencial se perde. Muitas têm "despiste a polícia" como objetivo. GTA V permite recomeçar de pontos intermediários.

**Sistema.** **[INFERÊNCIA]** Uma missão em mundo aberto precisa **pegar emprestado** o mundo:

- **reservar** entidades: o carro da fuga e o alvo da perseguição não podem ser devolvidos ao pool pela população;
- **sobrepor** sistemas: forçar ou suspender o nível de procurado, reduzir a densidade numa rua de perseguição;
- **devolver** tudo no fim, com sucesso ou falha: o que a missão criou volta ao mundo ambiente ou é limpo.

**Design.** "Despiste a polícia" é a missão **usando** um sistema do mundo como objetivo, em vez de reimplementá-lo.

**Tecnologia.** As **travas de roteiro com handle** do Diretor (`PushScriptLock`/`PopScriptLock`, Cap. 42) são o padrão do empréstimo: um pedido identificado, que quem pediu precisa devolver. Uma sobreposição de densidade pedida por uma quest seria uma trava idêntica na população.

**Versão mínima.** No Projeto, um objetivo do Capítulo 31 que conclui com `Event.Alert.Cleared` é o "despiste a segurança".

**Lição.** Em mundo aberto, a parte difícil de uma missão não é o roteiro: é **pedir emprestado e devolver** o mundo sem deixar nada preso.

---

## 8. Veículos e física sistêmica: a cadeia de GTA IV, revisitada

O Capítulo 15 decompôs a cadeia **física → veículo → colisão → reação do NPC → animação → feedback → emergência**. Aqui a pergunta é de arquitetura: **por onde a emergência passa?**

**Experiência.** Um mundo que reage fisicamente: cada batida e cada tropeço são diferentes.

**O que é público.** **[FATO PÚBLICO]** *GTA IV* usa o *euphoria*, da NaturalMotion, para animação física de personagens. **[FATO PÚBLICO — amplamente percebido]** Sua direção foi recebida como mais pesada que a de *San Andreas*; a de *V*, como mais responsiva que a de *IV*.

**Sistema.**

```text
 Física           colisão com impulso I na posição P
   │                      │ evento de hit (Cap. 15)
   ▼                      ▼
 Veículo ──────► ruído (Cap. 36) ─────► percepção de IA: vigias investigam
   │                      │
   ▼                      ▼
 Reação do NPC ◄── incidente no barramento (Cap. 24) ──► calor do alerta
   │                                                       │
   ▼                                                       ▼
 Animação física (Cap. 53)                   resposta: unidades, rua esvazia
   │                                                       │
   └────────────► feedback para a jogadora ◄───────────────┘
                              │
                              ▼
               uma situação que ninguém roteirizou
```

**Design.** Nenhum elo é complexo. A emergência vem das **conexões**, que só existem porque cada sistema publica o que fez num formato genérico (posição, magnitude, instigador) e outro consome sem conhecer o primeiro.

**Tecnologia.** **[INFERÊNCIA]** A cadeia tem **orçamento**: o Capítulo 15 levantou a hipótese de um limite de personagens em animação física simultânea, e física simulada é coisa do LOD Full (longe, um veículo pode seguir a faixa de forma cinemática). Na Unreal: o plugin **Chaos Vehicles** (`UChaosWheeledVehicleMovementComponent`) e o `UPhysicalAnimationComponent` (Cap. 53).

**Versão mínima.** A Vigília não terá carros, mas tem caixas e vigias: a Parte 5 do Exercício liga o elo "física → incidente".

**Lição.** Para ter emergência, não escreva um sistema esperto. Escreva **saídas genéricas** e deixe **entradas** que outros sistemas possam ligar.

---

## 9. Arquitetura tecnicamente elegante × arquitetura adequada para um jogo

O Capítulo 6 deu seis critérios de arquitetura adequada (iteração, custo previsível, autorabilidade, depurabilidade, deletabilidade, a favor da engine) e o "ERP para uma porta". Em mundo aberto a tentação corporativa é maior, porque o problema **parece** um sistema distribuído: milhares de entidades, estado, eventos, consistência. Seis exemplos mostram onde a solução de jogo é mais simples e mais certa.

**1. Identidade.** *Elegante:* todo pedestre tem ID estável, estado persistido e ciclo de vida auditável. *Adequada:* figurantes são **intercambiáveis**; só tem identidade o que a jogadora reconhece e pode verificar. **[FATO PÚBLICO — observável jogando]** Em *San Andreas*, o carro largado na rua some, e o da garagem fica. Em GTA V, o veículo **pessoal** de cada protagonista, se perdido, pode ser recuperado no pátio de apreensão da polícia; um carro qualquer roubado na rua, não. A identidade custa memória, save e casos de borda, e o jogo a paga só onde a jogadora cobraria.

**2. Persistência de agregados.** *Elegante:* registrar cada integrante de gangue e quem domina cada esquina. *Adequada:* persistir **um valor por zona**. **[FATO PÚBLICO — observável jogando]** *San Andreas* tem territórios de gangue que a jogadora conquista, marcados no mapa; nos territórios da gangue dela, os membros aparecem nas ruas. **[INFERÊNCIA]** Isso é compatível com persistir "quem domina o território" e deixar a população **ler** esse valor para escolher quem nasce. O indivíduo é fabricado; o agregado é memória, como o fato `S1.ScareDone` (Cap. 46) e os documentos que o mencionam.

**3. Simulação contínua × fabricação.** *Elegante:* simular a cidade inteira em baixa frequência, para tudo estar sempre consistente. *Adequada:* fabricar sob demanda, com restrições de plausibilidade (relógio, agenda, memória). A elegante custa CPU para sempre, encarece pular o tempo (seção 5) e produz uma consistência que ninguém vê.

**4. Varredura com orçamento × reação a eventos.** *Elegante:* cada NPC assina eventos de proximidade e reage na hora. *Adequada:* uma **varredura em fatias**, N agentes por passo, com custo fixo. Trinta *overlaps* no mesmo quadro estouram o orçamento; seis avaliações por passo, a 4 Hz, custam sempre o mesmo. Em backend, *push* costuma vencer *polling*; num jogo, *polling* com orçamento costuma vencer, porque o quadro é um prazo fixo, e 250 ms de latência são invisíveis a 40 metros.

**5. *Wanted* como motor de regras × um número.** *Elegante:* taxonomia de crimes, jurisdições, despacho com rotas, testemunhas com memória. *Adequada:* calor, decaimento, uma tabela de resposta e um filtro de percepção. A jogadora precisa **prever** o sistema para jogar com ele, e regras ricas demais viram ruído.

**6. Consistência forte × plausibilidade.** *Elegante:* o pedestre que saiu de vista é o mesmo que volta. *Adequada:* qualquer pedestre plausível serve, desde que **ninguém suma à vista**. O preço é conhecido: o carro que estava ali há dez segundos não está mais.

| Mundo aberto | O que você conhece | Onde a analogia cai |
|---|---|---|
| Bolha + fabricação | Cache com *miss* barato | No *miss*, o cache busca a verdade; o jogo **inventa** uma |
| Plausibilidade | Consistência eventual | Não converge nunca: só não pode ser **contradita diante da jogadora** |
| Varredura em fatias | Job em lote com limite por execução | Roda a cada quadro, com prazo de milissegundos |
| Agregado em vez de indivíduo | Projeção / *read model* | Os indivíduos nunca existiram como fonte da verdade |

**Onde a elegante vence.** A regra não é "simples sempre". A elegante é a certa quando **mais de um observador** pode verificar o mundo: com duas jogadoras, a bolha de uma é o mundo fabricado da outra, e o carro que some para uma some **diante** da outra. Por isso mundos compartilhados (GTA Online, Interlúdio III) precisam de identidade, autoridade e replicação onde o single-player fabricava. Ela também vence no que a jogadora **possui** (inventário, veículo pessoal, save) e no estado narrativo, que muitos sistemas leem (Cap. 46).

A regra que fica: **correção onde a jogadora pode verificar; plausibilidade onde não pode; e ninguém some à vista.**

---

## Unreal Engine: as peças e os anéis

| Peça da Unreal | O que resolve | O que **não** resolve |
|---|---|---|
| **World Partition** (grade, fontes de streaming, *One File Per Actor*) | Carregar o mundo por proximidade | Estado do que foi descarregado (Cap. 57) |
| **HLOD** | Ver longe sem carregar | Nada que precise de lógica |
| **Data Layers** (em runtime: descarregada, carregada, ativada) | Trocar conjuntos de atores (antes/depois de uma missão) | Decidir **quando** trocar: isso é estado narrativo |
| **Level Streaming**, **Level Instances** | Interiores, peças reutilizáveis | — |
| **Mass** (o *City Sample* como exemplo) | Milhares de agentes em lote, LOD de representação | Agentes ricos e únicos: continuam atores |
| **Significance Manager** | Um lugar para pontuar relevância | A política (o que fazer com a pontuação) |
| Pool (Cap. 32) | Custo de spawn e pressão no GC | Reset de atores complexos |
| **Chaos Vehicles**, **Physical Animation** | Simulação física | Quantos simulam ao mesmo tempo |

⚠️ A API de estado das Data Layers em runtime mudou dentro do UE5 (5.3 trocou o gerenciador), e vários plugins de Mass são experimentais ou beta. Confira na documentação da sua versão antes de escrever código contra eles.

A regra que amarra tudo é geométrica: cada anel precisa caber dentro do seguinte.

```text
 ● jogadora
 ├── LOD Full                  (IA, animação, testemunha)
 ├── anel de spawn             (fora de vista)
 ├── raio de despawn           (fora de vista por um tempo)
 ├── raio de carregamento      (World Partition: o chão existe)
 └── HLOD                      (o mundo é uma maquete)
```

Despawn além do carregamento: figurantes caminham para células descarregadas e caem no vazio. Spawn dentro do LOD Full: a jogadora vê gente aparecendo. Boa parte dos bugs de população é um anel fora de ordem.

---

## Projeto — O Quarteirão Vivo

Um **nível de laboratório**, fora do jogo e não canônico: `/Game/Developers/<você>/L_Lab_QuarteiraoVivo`. O Capítulo 76 decide se alguma peça sobrevive.

**A ficção de laboratório.** Serra Funda em 1994, com a usina funcionando: o **Pátio** (Cap. 7) e, do lado de fora do muro, uma rua da **vila operária**, com casas, uma praça e um bar. Operários atravessam o pátio nas trocas de turno; moradores ocupam a rua de manhã e à noite. Os vigias da Parte V respondem a um nível de alerta. A jogadora é a intrusa.

### O nível

- **Grey-box** de cerca de 240 × 160 m: o Pátio (80 × 60 m) com o portão aberto para a rua, seis a oito casas, a praça e o bar. Casas e muros quebram a linha de visão, e é isso que permite nascer "fora de vista" perto. NavMesh em tudo (Cap. 35).
- **15 a 25 `AVGSpawnPoint`** com a tag `Spawn.Population`, em calçadas e portas: lugares de onde faz sentido alguém sair.
- **Duas zonas**: um `AVGEventTrigger` no portão alterna o perfil entre `DA_Pop_Patio` e `DA_Pop_Vila`.
- **`BP_Figurante`**: um `ACharacter` sem vida, sem inventário e sem tags de status, com `Auto Possess AI = Placed in World or Spawned`, implementando `IVGPoolable` em Blueprint. No `OnPoolAcquired`, roda `BT_Figurante` (um ponto navegável a 8–20 m por EQS, `MoveTo`, espera de 2 a 6 s). Na malha, `Visibility Based Anim Tick Option = Only Tick Pose When Rendered` (⚠️ confira o nome na sua versão): fora de vista, a animação não custa.

### 1. Tags

```cpp
// VGGameplayTags.h (adições)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Alert_Incident);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Alert_LevelChanged);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Event_Alert_Cleared);
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Spawn_Population);

// VGGameplayTags.cpp (adições)
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Alert_Incident,     "Event.Alert.Incident");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Alert_LevelChanged, "Event.Alert.LevelChanged");
UE_DEFINE_GAMEPLAY_TAG(TAG_Event_Alert_Cleared,      "Event.Alert.Cleared");
UE_DEFINE_GAMEPLAY_TAG(TAG_Spawn_Population,         "Spawn.Population");
```

`Spawn.Population` é nativa, ao contrário das outras `Spawn.*` (conteúdo, Cap. 32), porque o C++ filtra por ela.

### 2. Visibilidade, extraída

🔁 **O que havia:** `AVGWaveSpawner::IsVisibleToPlayer` (Cap. 32), um teste de cone + linha de visão privado do spawner de ondas. **O problema:** a população precisa do mesmo teste no spawn e no LOD, e o spawner já o usa na escolha do ponto e no desafio do Capítulo 32. São quatro usos em duas classes: pelo critério do "terceiro caso" (Cap. 6), hora de extrair. **A solução:** uma função livre em `World/VGVisibility.h`, com o corpo do Capítulo 32:

`VIGILIA_API bool VGVisibility::IsVisibleToPlayer(const UWorld* World, const FVector& Target, float HalfAngleDeg, const AActor* Ignored = nullptr);`

As diferenças: recebe o mundo e um ponto (não um `AVGSpawnPoint`) e ignora `Ignored` no trace, além do pawn da jogadora. Sem isso, a cápsula do próprio figurante bloquearia o trace que testa se ele está à vista. O método do spawner vira uma linha que chama a função.

### 3. Regras puras: população e horário

```cpp
// Source/Vigilia/World/VGPopulationRules.h
#pragma once

#include "CoreMinimal.h"

/** LOD de simulação. Discard = pode voltar ao pool (fora de vista, longe). */
enum class EVGSimLod : uint8 { Full, Reduced, Discard };

namespace VGPopulationRules
{
    /** Densidade (0..1) na hora dada, interpolando 24 valores; 23h interpola com 0h. */
    inline float DensityAt(const TArray<float>& Hourly, float Hour)
    {
        if (Hourly.Num() != 24)
        {
            return 1.0f; // dado inválido (IsDataValid já reclamou): melhor rua cheia que rua morta
        }
        const float H = FMath::Fmod(FMath::Fmod(Hour, 24.0f) + 24.0f, 24.0f);
        const int32 A = FMath::FloorToInt(H) % 24;
        return FMath::Lerp(Hourly[A], Hourly[(A + 1) % 24], H - FMath::FloorToFloat(H));
    }

    inline int32 TargetCount(int32 MaxAlive, float Density, float Scale)
    {
        return FMath::Clamp(FMath::RoundToInt(MaxAlive * Density * Scale), 0, MaxAlive);
    }

    /** Janela de horário; From > To cruza a meia-noite (22h–6h). */
    inline bool IsHourInWindow(float Hour, float From, float To)
    {
        return From <= To ? (Hour >= From && Hour < To) : (Hour >= From || Hour < To);
    }

    /** Perto: Full. À vista: nunca descartado. Longe e fora de vista: Discard. */
    inline EVGSimLod SimLodFor(float Distance, bool bVisible, float FullRadius, float DespawnRadius)
    {
        if (Distance <= FullRadius)
        {
            return EVGSimLod::Full;
        }
        if (bVisible)
        {
            return Distance <= DespawnRadius ? EVGSimLod::Full : EVGSimLod::Reduced;
        }
        return Distance <= DespawnRadius ? EVGSimLod::Reduced : EVGSimLod::Discard;
    }
}
```

### 4. O relógio e o perfil de população

```cpp
// Source/Vigilia/World/VGWorldClockSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGWorldClockSubsystem.generated.h"

/** Hora do mundo. Relógio: o delta do mundo (dilata e pausa, como GetTimeSeconds). */
UCLASS()
class VIGILIA_API UVGWorldClockSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void Tick(float DeltaTime) override { Hour = FMath::Fmod(Hour + DeltaTime * HoursPerSecond, 24.0f); }
    virtual TStatId GetStatId() const override
    {
        RETURN_QUICK_DECLARE_CYCLE_STAT(UVGWorldClockSubsystem, STATGROUP_Tickables);
    }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Clock")
    float GetHour() const { return Hour; }

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Clock")
    void SetHour(float NewHour) { Hour = FMath::Fmod(FMath::Max(NewHour, 0.0f), 24.0f); }

    /** Horas de jogo por segundo real. 1/30: um dia em 12 minutos. */
    UPROPERTY(BlueprintReadWrite, Category = "Vigilia|Clock")
    float HoursPerSecond = 1.0f / 30.0f;

private:
    float Hour = 13.5f; // meia hora antes da troca de turno das 14h
};
```

```cpp
// Source/Vigilia/World/VGPopulationData.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "VGPopulationData.generated.h"

class APawn;

/** Perfil de população de uma zona: quem, quantos, quando e em que anéis. Trocar de zona = trocar de perfil. */
UCLASS(BlueprintType)
class VIGILIA_API UVGPopulationData : public UPrimaryDataAsset
{
    GENERATED_BODY()

public:
    /** Simplificação: referências duras. Com muitas variações, TSoftClassPtr + carga assíncrona (Caps. 57, 60). */
    UPROPERTY(EditDefaultsOnly, Category = "Population")
    TArray<TSubclassOf<APawn>> PawnClasses;

    /** 24 valores (0..1), um por hora; o índice 0 é meia-noite. */
    UPROPERTY(EditDefaultsOnly, Category = "Population")
    TArray<float> HourlyDensity;

    /** Orçamento: nunca mais vivos que isto, em qualquer hora. */
    UPROPERTY(EditDefaultsOnly, Category = "Population", meta = (ClampMin = "0"))
    int32 MaxAlive = 12;

    UPROPERTY(EditDefaultsOnly, Category = "Population|Rings", meta = (ClampMin = "0.0"))
    float FullLodRadius = 2500.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Population|Rings", meta = (ClampMin = "0.0"))
    float SpawnMinRadius = 3000.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Population|Rings", meta = (ClampMin = "0.0"))
    float SpawnMaxRadius = 7000.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Population|Rings", meta = (ClampMin = "0.0"))
    float DespawnRadius = 9000.0f;

#if WITH_EDITOR
    virtual EDataValidationResult IsDataValid(class FDataValidationContext& Context) const override;
#endif
};
```

```cpp
// Source/Vigilia/World/VGPopulationData.cpp
#include "World/VGPopulationData.h"

#if WITH_EDITOR
#include "Misc/DataValidation.h"

EDataValidationResult UVGPopulationData::IsDataValid(FDataValidationContext& Context) const
{
    EDataValidationResult Result = Super::IsDataValid(Context);
    auto Fail = [&](const TCHAR* Message)
    {
        Context.AddError(FText::FromString(Message));
        Result = EDataValidationResult::Invalid;
    };
    if (HourlyDensity.Num() != 24) { Fail(TEXT("HourlyDensity precisa de 24 valores, um por hora.")); }
    if (PawnClasses.IsEmpty()) { Fail(TEXT("Nenhuma classe de figurante.")); }
    // A regra dos anéis: cada um dentro do seguinte.
    if (!(FullLodRadius < SpawnMinRadius && SpawnMinRadius < SpawnMaxRadius && SpawnMaxRadius < DespawnRadius))
    {
        Fail(TEXT("Anéis fora de ordem: FullLod < SpawnMin < SpawnMax < Despawn."));
    }
    return Result;
}
#endif
```

### 5. O subsistema de população

```cpp
// Source/Vigilia/World/VGPopulationSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "World/VGPopulationRules.h"
#include "VGPopulationSubsystem.generated.h"

class AActor;
class APawn;
class AVGSpawnPoint;
class UVGPopulationData;

/** População ambiente com orçamento, anéis e LOD em fatias. Simplificação: uma observadora (Exercício, Parte 4). */
UCLASS()
class VIGILIA_API UVGPopulationSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Tick(float DeltaTime) override;
    virtual TStatId GetStatId() const override;

    /** Troca a zona. Ninguém some: o excesso sai pelo despawn normal, fora de vista. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Population")
    void SetProfile(UVGPopulationData* NewProfile) { Profile = NewProfile; }

    /** Multiplica a densidade (ex.: a rua esvazia quando o alerta sobe). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Population")
    void SetDensityScale(float Scale) { DensityScale = FMath::Clamp(Scale, 0.0f, 1.0f); }

    /** Agentes em LOD Full, dentro de Radius, com linha de visão para Location. */
    int32 CountWitnesses(const FVector& Location, float Radius, const AActor* Ignored) const;

private:
    struct FAgent
    {
        TWeakObjectPtr<APawn> Pawn;
        EVGSimLod Lod = EVGSimLod::Full;
        float LastEvalTime = 0.0f;
        float DiscardableTime = 0.0f; // há quanto tempo poderia sumir sem ninguém ver
    };

    void EvaluateSlice(const FVector& PlayerLocation, int32 Target);
    void TrySpawnOne(const FVector& PlayerLocation);
    void ReleaseAgent(int32 Index);
    void ApplyLod(APawn& Pawn, EVGSimLod Lod) const;
    void SetDormant(APawn& Pawn, bool bDormant) const;
    void DrawDebug(const FVector& PlayerLocation, int32 Target) const;

    UPROPERTY()
    TObjectPtr<UVGPopulationData> Profile;

    TArray<TWeakObjectPtr<AVGSpawnPoint>> Points;
    TArray<FAgent> Agents;
    int32 Cursor = 0;
    float StepAccumulator = 0.0f;
    float DensityScale = 1.0f;
};
```

```cpp
// Source/Vigilia/World/VGPopulationSubsystem.cpp
#include "World/VGPopulationSubsystem.h"

#include "AIController.h"
#include "BrainComponent.h"
#include "Core/VGActorPoolSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "DrawDebugHelpers.h"
#include "Engine/Engine.h"
#include "EngineUtils.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"
#include "World/VGPopulationData.h"
#include "World/VGSpawnPoint.h"
#include "World/VGVisibility.h"
#include "World/VGWorldClockSubsystem.h"

static TAutoConsoleVariable<bool> CVarVGDebugPopulation(
    TEXT("vg.Debug.Population"), false,
    TEXT("Desenha os anéis da população e os agentes por LOD de simulação."), ECVF_Default);

namespace VGPopulationTuning // Simplificação: constantes; viram dados do perfil se o design pedir
{
    constexpr float StepInterval        = 0.25f; // 4 Hz: população não precisa reagir a cada quadro
    constexpr int32 AgentsPerStep       = 6;     // orçamento de avaliação (e de traces) por passo
    constexpr float DiscardGrace        = 2.0f;  // fora de vista por 2 s antes de sumir
    constexpr float ReducedTickInterval = 0.25f;
    constexpr float ViewHalfAngle       = 50.0f;
}

TStatId UVGPopulationSubsystem::GetStatId() const
{
    RETURN_QUICK_DECLARE_CYCLE_STAT(UVGPopulationSubsystem, STATGROUP_Tickables);
}

void UVGPopulationSubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
    // Iterar o mundo só na inicialização (Cap. 8). Com World Partition, os pontos precisam
    // estar sempre carregados (Is Spatially Loaded desligado): ver o Exercício, Parte 3.
    for (TActorIterator<AVGSpawnPoint> It(&InWorld); It; ++It)
    {
        if (It->SpawnTags.HasTag(TAG_Spawn_Population))
        {
            Points.Add(*It);
        }
    }
}

void UVGPopulationSubsystem::Tick(float DeltaTime)
{
    const APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
    StepAccumulator += DeltaTime;
    if (!Profile || !Player || StepAccumulator < VGPopulationTuning::StepInterval)
    {
        return;
    }
    StepAccumulator = 0.0f;

    const UVGWorldClockSubsystem* Clock = GetWorld()->GetSubsystem<UVGWorldClockSubsystem>();
    const float Density = VGPopulationRules::DensityAt(Profile->HourlyDensity, Clock ? Clock->GetHour() : 12.0f);
    const int32 Target = VGPopulationRules::TargetCount(Profile->MaxAlive, Density, DensityScale);
    const FVector PlayerLocation = Player->GetActorLocation();

    EvaluateSlice(PlayerLocation, Target);
    if (Agents.Num() < Target)
    {
        TrySpawnOne(PlayerLocation); // um por passo: a rua enche aos poucos, sem pico de custo
    }
    if (CVarVGDebugPopulation.GetValueOnGameThread())
    {
        DrawDebug(PlayerLocation, Target); // implementação: Exercício, Parte 1
    }
}

void UVGPopulationSubsystem::EvaluateSlice(const FVector& PlayerLocation, int32 Target)
{
    const UWorld* World = GetWorld();
    const float Now = World->GetTimeSeconds();
    const int32 Budget = FMath::Min(VGPopulationTuning::AgentsPerStep, Agents.Num());
    for (int32 Step = 0; Step < Budget && !Agents.IsEmpty(); ++Step)
    {
        Cursor %= Agents.Num();
        FAgent& Agent = Agents[Cursor];
        APawn* Pawn = Agent.Pawn.Get();
        if (!IsValid(Pawn))
        {
            Agents.RemoveAtSwap(Cursor); // destruído por outro meio: só esquece
            continue;
        }
        const float Elapsed = Now - Agent.LastEvalTime;
        Agent.LastEvalTime = Now;

        const float Distance = FVector::Dist(PlayerLocation, Pawn->GetActorLocation());
        const bool bVisible = VGVisibility::IsVisibleToPlayer(World, Pawn->GetActorLocation(),
                                                              VGPopulationTuning::ViewHalfAngle, Pawn);
        const EVGSimLod Wanted = VGPopulationRules::SimLodFor(Distance, bVisible, Profile->FullLodRadius,
                                                              Profile->DespawnRadius);
        // Acima do alvo (a hora ou a zona mudou), qualquer agente fora de vista e fora do anel interno pode sair.
        const bool bDiscardable = Wanted == EVGSimLod::Discard
            || (!bVisible && Agents.Num() > Target && Distance > Profile->SpawnMinRadius);

        Agent.DiscardableTime = bDiscardable ? Agent.DiscardableTime + Elapsed : 0.0f;
        if (Agent.DiscardableTime >= VGPopulationTuning::DiscardGrace)
        {
            ReleaseAgent(Cursor); // RemoveAtSwap: o próximo agente cai neste índice
            continue;
        }
        const EVGSimLod Applied = Wanted == EVGSimLod::Discard ? EVGSimLod::Reduced : Wanted;
        if (Applied != Agent.Lod)
        {
            Agent.Lod = Applied;
            ApplyLod(*Pawn, Applied);
        }
        ++Cursor;
    }
}

void UVGPopulationSubsystem::TrySpawnOne(const FVector& PlayerLocation)
{
    UWorld* World = GetWorld();
    TArray<AVGSpawnPoint*> InRing;
    for (const TWeakObjectPtr<AVGSpawnPoint>& Weak : Points)
    {
        // Simplificação: varre todos os pontos. Com centenas, uma grade espacial corta a busca (Cap. 60).
        AVGSpawnPoint* Point = Weak.Get();
        const float Distance = Point ? FVector::Dist(PlayerLocation, Point->GetActorLocation()) : -1.0f;
        if (Distance >= Profile->SpawnMinRadius && Distance <= Profile->SpawnMaxRadius)
        {
            InRing.Add(Point);
        }
    }
    if (InRing.IsEmpty() || Profile->PawnClasses.IsEmpty())
    {
        return;
    }
    // Testes caros (overlap, trace) só no ponto sorteado. Falhou? O próximo passo sorteia outro.
    AVGSpawnPoint* Point = InRing[FMath::RandRange(0, InRing.Num() - 1)];
    const TSubclassOf<APawn> Class = Profile->PawnClasses[FMath::RandRange(0, Profile->PawnClasses.Num() - 1)];
    UVGActorPoolSubsystem* Pool = World->GetSubsystem<UVGActorPoolSubsystem>();
    if (!Class || !Pool || !Point->IsClear()
        || VGVisibility::IsVisibleToPlayer(World, Point->GetActorLocation(), VGPopulationTuning::ViewHalfAngle))
    {
        return;
    }
    FActorSpawnParameters Params;
    Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButDontSpawnIfColliding;
    if (APawn* Pawn = Cast<APawn>(Pool->Acquire(Class, Point->GetActorTransform(), Params)))
    {
        SetDormant(*Pawn, false);
        ApplyLod(*Pawn, EVGSimLod::Full);
        FAgent& Agent = Agents.AddDefaulted_GetRef();
        Agent.Pawn = Pawn;
        Agent.LastEvalTime = World->GetTimeSeconds();
    }
}

void UVGPopulationSubsystem::ReleaseAgent(int32 Index)
{
    if (APawn* Pawn = Agents[Index].Pawn.Get())
    {
        SetDormant(*Pawn, true);
        if (UVGActorPoolSubsystem* Pool = GetWorld()->GetSubsystem<UVGActorPoolSubsystem>())
        {
            Pool->Release(Pawn); // OnPoolReleased (Blueprint) zera o que é do conteúdo
        }
    }
    Agents.RemoveAtSwap(Index);
}

void UVGPopulationSubsystem::ApplyLod(APawn& Pawn, EVGSimLod Lod) const
{
    // Reduced: o mesmo comportamento, a 4 Hz. O movimento recebe o delta acumulado.
    const float Interval = Lod == EVGSimLod::Full ? 0.0f : VGPopulationTuning::ReducedTickInterval;
    AActor* Owners[] = { &Pawn, Pawn.GetController() }; // a BT e o path following são componentes do controller
    for (AActor* Owner : Owners)
    {
        if (!Owner)
        {
            continue;
        }
        Owner->SetActorTickInterval(Interval);
        for (UActorComponent* Component : Owner->GetComponents())
        {
            if (Component)
            {
                Component->SetComponentTickInterval(Interval);
            }
        }
    }
}

void UVGPopulationSubsystem::SetDormant(APawn& Pawn, bool bDormant) const
{
    // O pool desliga o tick do ATOR, não dos componentes: sem isto, o movimento e a malha de um
    // figurante escondido continuam custando. Simplificação: religa todo componente que pode ticar.
    for (UActorComponent* Component : Pawn.GetComponents())
    {
        if (Component)
        {
            Component->SetComponentTickEnabled(!bDormant);
        }
    }
    AAIController* AI = Cast<AAIController>(Pawn.GetController());
    if (bDormant && AI)
    {
        AI->StopMovement();
        if (UBrainComponent* Brain = AI->GetBrainComponent())
        {
            Brain->StopLogic(TEXT("Population")); // o OnPoolAcquired do figurante roda a BT de novo
        }
    }
}

int32 UVGPopulationSubsystem::CountWitnesses(const FVector& Location, float Radius, const AActor* Ignored) const
{
    int32 Count = 0;
    for (const FAgent& Agent : Agents)
    {
        const APawn* Pawn = Agent.Pawn.Get();
        // O LOD de simulação vira regra de jogo: só quem está em Full testemunha (seção 4).
        if (!Pawn || Agent.Lod != EVGSimLod::Full
            || FVector::DistSquared(Pawn->GetActorLocation(), Location) > FMath::Square(Radius))
        {
            continue;
        }
        FCollisionQueryParams Params(SCENE_QUERY_STAT(VGWitness), false, Pawn);
        Params.AddIgnoredActor(Ignored);
        FHitResult Hit;
        if (!GetWorld()->LineTraceSingleByChannel(Hit, Pawn->GetPawnViewLocation(), Location, ECC_Visibility, Params))
        {
            ++Count;
        }
    }
    return Count;
}
```

O `DrawDebug` fica para o Exercício: os quatro anéis com `DrawDebugCircle` (eixos `ForwardVector` e `RightVector`, para o círculo deitar no chão), uma esfera por agente (verde em Full, amarela em Reduced) e uma linha na tela com vivos, alvo, escala e perfil.

### 6. O nível de alerta

```cpp
// Source/Vigilia/World/VGAlertRules.h
#pragma once

#include "CoreMinimal.h"
#include "VGAlertRules.generated.h"

USTRUCT(BlueprintType)
struct FVGAlertTuning
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alert", meta = (ClampMin = "1.0"))
    float HeatPerLevel = 100.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alert", meta = (ClampMin = "1", ClampMax = "5"))
    int32 MaxLevel = 3;

    /** Para descer, o calor precisa cair esta margem abaixo do limiar: o nível não pisca na fronteira. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alert", meta = (ClampMin = "0.0"))
    float Hysteresis = 15.0f;

    /** Segundos sem ser vista antes de o calor começar a cair. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alert", meta = (ClampMin = "0.0"))
    float DecayDelay = 6.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alert", meta = (ClampMin = "0.0"))
    float DecayPerSecond = 20.0f;

    /** Distância máxima de uma testemunha ao incidente. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Alert", meta = (ClampMin = "0.0"))
    float WitnessRadius = 3000.0f;
};

namespace VGAlertRules
{
    /** Soma a gravidade. Teto meio nível acima do máximo: fugir do nível máximo custa tempo. */
    inline float AddIncident(float Heat, float Severity, const FVGAlertTuning& T)
    {
        return FMath::Clamp(Heat + Severity, 0.0f, T.HeatPerLevel * (T.MaxLevel + 0.5f));
    }

    /** O calor só cai depois de DecayDelay segundos sem a jogadora ser vista. */
    inline float Decay(float Heat, float TimeUnseen, float DeltaSeconds, const FVGAlertTuning& T)
    {
        return TimeUnseen < T.DecayDelay ? Heat : FMath::Max(0.0f, Heat - T.DecayPerSecond * DeltaSeconds);
    }

    /** Sobe ao cruzar o limiar; desce só abaixo do limiar menos a histerese; nunca passa do máximo. */
    inline int32 LevelFor(float Heat, int32 CurrentLevel, const FVGAlertTuning& T)
    {
        const int32 Up = FMath::Clamp(FMath::FloorToInt(Heat / T.HeatPerLevel), 0, T.MaxLevel);
        if (Up >= CurrentLevel)
        {
            return Up;
        }
        const int32 Down = FMath::Clamp(FMath::FloorToInt((Heat + T.Hysteresis) / T.HeatPerLevel), 0, T.MaxLevel);
        return FMath::Min(Down, CurrentLevel);
    }
}
```

```cpp
// Source/Vigilia/World/VGAlertSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/WorldSubsystem.h"
#include "World/VGAlertRules.h"
#include "VGAlertSubsystem.generated.h"

struct FVGGameplayEvent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGAlertLevelChangedSignature, int32, OldLevel, int32, NewLevel);

/** Nível de alerta no estilo de um wanted level. Dono único do calor e do nível; a resposta é de quem ouve. */
UCLASS()
class VIGILIA_API UVGAlertSubsystem : public UTickableWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Deinitialize() override;
    virtual void Tick(float DeltaTime) override;
    virtual TStatId GetStatId() const override;

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Alert")
    void SetTuning(const FVGAlertTuning& NewTuning) { Tuning = NewTuning; }

    /** Quem responde (os vigias) avisa que está vendo a jogadora: o calor para de cair. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Alert")
    void ReportPlayerSeen() { TimeUnseen = 0.0f; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Alert")
    int32 GetLevel() const { return Level; }

    UFUNCTION(BlueprintPure, Category = "Vigilia|Alert")
    float GetHeat() const { return Heat; }

    /** Cheat VGAlertHeat: soma (ou tira) calor sem testemunha. */
    void DebugAddHeat(float Amount);

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Alert")
    FVGAlertLevelChangedSignature OnAlertLevelChanged;

private:
    void HandleEvent(const FVGGameplayEvent& Event);
    void UpdateLevel();

    FVGAlertTuning Tuning;
    float Heat = 0.0f;
    float TimeUnseen = 1000.0f; // ninguém começa vendo a jogadora
    int32 Level = 0;
    FDelegateHandle EventHandle;
};
```

```cpp
// Source/Vigilia/World/VGAlertSubsystem.cpp
#include "World/VGAlertSubsystem.h"

#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Engine/Engine.h"
#include "HAL/IConsoleManager.h"
#include "World/VGPopulationSubsystem.h"

static TAutoConsoleVariable<bool> CVarVGDebugAlert(
    TEXT("vg.Debug.Alert"), false, TEXT("Mostra nível, calor e tempo sem ser vista."), ECVF_Default);

TStatId UVGAlertSubsystem::GetStatId() const
{
    RETURN_QUICK_DECLARE_CYCLE_STAT(UVGAlertSubsystem, STATGROUP_Tickables);
}

void UVGAlertSubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
    if (UVGGameplayEventSubsystem* Bus = InWorld.GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &UVGAlertSubsystem::HandleEvent);
    }
}

void UVGAlertSubsystem::Deinitialize()
{
    if (UVGGameplayEventSubsystem* Bus = GetWorld() ? GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>() : nullptr)
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::Deinitialize();
}

void UVGAlertSubsystem::HandleEvent(const FVGGameplayEvent& Event)
{
    if (!Event.Channel.MatchesTagExact(TAG_Event_Alert_Incident))
    {
        return;
    }
    // O incidente acontece onde está quem o causou (a jogadora); sem instigador, onde está o alvo.
    const AActor* Where = Event.Instigator ? Event.Instigator.Get() : Event.Target.Get();
    if (!Where)
    {
        return;
    }
    // A percepção filtra a entrada (Cap. 4): ou quem responde já está vendo a jogadora,
    // ou um figurante em LOD Full tem linha de visão para o incidente.
    const UVGPopulationSubsystem* Population = GetWorld()->GetSubsystem<UVGPopulationSubsystem>();
    const bool bWitnessed = TimeUnseen < 1.0f
        || (Population && Population->CountWitnesses(Where->GetActorLocation(), Tuning.WitnessRadius, Where) > 0);
    if (!bWitnessed)
    {
        return; // sem testemunha, para o mundo não aconteceu
    }
    Heat = VGAlertRules::AddIncident(Heat, Event.Magnitude, Tuning);
    TimeUnseen = 0.0f;
    UpdateLevel();
}

void UVGAlertSubsystem::Tick(float DeltaTime)
{
    TimeUnseen += DeltaTime;
    if (Heat > 0.0f)
    {
        Heat = VGAlertRules::Decay(Heat, TimeUnseen, DeltaTime, Tuning);
        UpdateLevel();
    }
    if (CVarVGDebugAlert.GetValueOnGameThread() && GEngine)
    {
        GEngine->AddOnScreenDebugMessage(static_cast<uint64>(GetUniqueID()), 0.0f, FColor::Orange,
            FString::Printf(TEXT("Alerta %d  calor %.0f  sem ser vista %.1f s"), Level, Heat, TimeUnseen));
    }
}

void UVGAlertSubsystem::DebugAddHeat(float Amount)
{
    Heat = VGAlertRules::AddIncident(Heat, Amount, Tuning);
    UpdateLevel();
}

void UVGAlertSubsystem::UpdateLevel()
{
    const int32 NewLevel = VGAlertRules::LevelFor(Heat, Level, Tuning);
    if (NewLevel == Level)
    {
        return;
    }
    const int32 OldLevel = Level;
    Level = NewLevel;                               // 1. muda o estado
    OnAlertLevelChanged.Broadcast(OldLevel, Level); // 2. anuncia: resposta, HUD, música, população
    UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Alert_LevelChanged, nullptr, nullptr,
                                           FGameplayTag(), static_cast<float>(Level));
    if (Level == 0)
    {
        UVGGameplayEventSubsystem::PublishFrom(this, TAG_Event_Alert_Cleared, nullptr, nullptr);
    }
}
```

**Quem publica incidentes** (Blueprint, `PublishFrom` no canal `Event.Alert.Incident`, gravidade em `Magnitude`): entrar na subestação cercada, por um `AVGEventTrigger` (25); um disparo que acerta algo, pelo `OnHitConfirmed` da arma (Cap. 27) no `BP_VGJogadora` (35); derrubar um vigia, com o `BP_RespostaAlerta` republicando `Event.Actor.Died` (120).

**Quem responde**: o `BP_RespostaAlerta`, em `OnAlertLevelChanged`. Nível 1: `SetDensityScale(0.7)`. Nível 2: `StartWaves` num `AVGWaveSpawner` (Cap. 32) com `DA_Onda_Seguranca` (dois vigias, pontos `Spawn.Security` na portaria e no galpão). Nível 3: `TriggerAlarm` no `AVGAlarm` (Cap. 13) e escala 0,2: a rua esvazia. Nível 0: escala 1 e `StopWaves`. Os vigias chamam `ReportPlayerSeen` enquanto estão `Aware` da jogadora (Cap. 36). Um objetivo do Capítulo 31 no canal `Event.Alert.Cleared` é o "despiste a segurança".

### 7. Depuração e testes

```cpp
// UVGCheatManager (adições)
UFUNCTION(Exec) void VGSetHour(float Hour);     // UVGWorldClockSubsystem::SetHour
UFUNCTION(Exec) void VGAlertHeat(float Amount); // UVGAlertSubsystem::DebugAddHeat
```

```cpp
// Source/Vigilia/Tests/VGOpenWorldRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "World/VGAlertRules.h"
#include "World/VGPopulationRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGAlertRulesTest, "Vigilia.World.Alert.HeatDecayHysteresis",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGAlertRulesTest::RunTest(const FString& Parameters)
{
    using namespace VGAlertRules;
    FVGAlertTuning T; // padrões: 100 por nível, máximo 3, histerese 15, carência 6 s, 20 por segundo

    TestEqual(TEXT("Teto: meio nível acima do máximo"), AddIncident(0.0f, 1000.0f, T), 350.0f);
    TestEqual(TEXT("Calor nunca negativo"), AddIncident(10.0f, -50.0f, T), 0.0f);
    TestEqual(TEXT("Sem decaimento na carência"), Decay(120.0f, 5.9f, 1.0f, T), 120.0f);
    TestEqual(TEXT("Decai depois da carência"), Decay(120.0f, 6.0f, 1.0f, T), 100.0f);
    TestEqual(TEXT("Decai até zero, não abaixo"), Decay(10.0f, 60.0f, 1.0f, T), 0.0f);

    TestEqual(TEXT("Sobe ao cruzar o limiar"), LevelFor(100.0f, 0, T), 1);
    TestEqual(TEXT("Incidente grave pula níveis"), LevelFor(250.0f, 0, T), 2);
    TestEqual(TEXT("Histerese: 90 ainda é nível 1"), LevelFor(90.0f, 1, T), 1);
    TestEqual(TEXT("Abaixo da margem, desce"), LevelFor(84.0f, 1, T), 0);
    TestEqual(TEXT("Nunca passa do máximo"), LevelFor(350.0f, 3, T), 3);

    // Uma fuga: incidente de 120, depois 10 s sem ser vista, a 4 Hz. Decai nos 17 passos com Unseen >= 6 s.
    float Heat = AddIncident(0.0f, 120.0f, T);
    int32 Level = LevelFor(Heat, 0, T);
    for (float Unseen = 0.25f; Unseen <= 10.0f; Unseen += 0.25f)
    {
        Heat = Decay(Heat, Unseen, 0.25f, T);
        Level = LevelFor(Heat, Level, T);
    }
    TestEqual(TEXT("Fuga: 120 - 17 x 5"), Heat, 35.0f);
    TestEqual(TEXT("Fuga: o alerta acabou"), Level, 0);
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGPopulationRulesTest, "Vigilia.World.Population.DensityScheduleLod",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGPopulationRulesTest::RunTest(const FString& Parameters)
{
    using namespace VGPopulationRules;
    TArray<float> Hourly;
    Hourly.Init(0.0f, 24);
    Hourly[4] = 1.0f;
    Hourly[23] = 1.0f;

    TestEqual(TEXT("Interpola entre horas"), DensityAt(Hourly, 3.5f), 0.5f);
    TestEqual(TEXT("23h interpola com 0h"), DensityAt(Hourly, 23.5f), 0.5f);
    TestEqual(TEXT("Nunca acima do orçamento"), TargetCount(12, 1.0f, 2.0f), 12);
    TestTrue(TEXT("Turno C (22h-6h) às 3h"), IsHourInWindow(3.0f, 22.0f, 6.0f));
    TestFalse(TEXT("Turno C ao meio-dia"), IsHourInWindow(12.0f, 22.0f, 6.0f));

    const auto Lod = [](float Distance, bool bVisible) { return SimLodFor(Distance, bVisible, 2500.0f, 9000.0f); };
    TestTrue(TEXT("Médio, fora de vista: Reduced"), Lod(5000.0f, false) == EVGSimLod::Reduced);
    TestTrue(TEXT("Longe, à vista: nunca some"), Lod(12000.0f, true) == EVGSimLod::Reduced);
    TestTrue(TEXT("Longe, fora de vista: Discard"), Lod(12000.0f, false) == EVGSimLod::Discard);
    return true;
}

#endif
```

### Explicação das decisões

- **Custo fixo por passo.** A 4 Hz, no máximo seis traces e um spawn, qualquer que seja a população. Com 12 vivos, cada agente é reavaliado a cada meio segundo, o que basta a 30 metros. É o exemplo 4 da seção 9 em código.
- **LOD genérico.** O figurante não sabe que existe LOD; qualquer pawn simples serve. ⚠️ Em `Reduced`, o movimento avança em passos de 0,25 s: confira se o `CharacterMovementComponent` se comporta bem com intervalos longos e, se o figurante "teleportar", use 0,1 s.
- **Dormência na população, não no pool.** Num projétil, desligar só o tick do ator bastava. Quem sabe que seus atores são pawns com IA é a população, e por isso a correção ficou nela.
- **Teto meio nível acima do máximo.** Sem ele, o nível 3 cairia para 2 menos de um segundo depois de o decaimento começar.
- **Testemunha.** Se quem responde já está vendo a jogadora (`TimeUnseen < 1 s`), todo incidente conta. Simplificação: civis e vigias "veem" do mesmo jeito; num jogo maior, a testemunha civil teria um atraso (precisa avisar alguém).
- **O alerta não conhece a resposta.** Trocar a resposta é editar Blueprint, não C++.

### Critérios de conclusão

- [ ] Com `vg.Debug.Population 1`, os anéis aparecem em volta da jogadora, e os agentes ficam verdes (Full) ou amarelos (Reduced).
- [ ] Ninguém nasce nem some à vista, mesmo girando a câmera rápido e andando de costas.
- [ ] `VGSetHour 3` esvazia a rua aos poucos; `VGSetHour 14` enche o pátio na troca de turno; o portão troca o perfil sem ninguém sumir.
- [ ] Um disparo **sem testemunha** não muda o calor; o mesmo disparo diante de um figurante em Full, sim.
- [ ] Os níveis 1, 2 e 3 têm respostas perceptivelmente diferentes, e ficar fora de vista leva o alerta a 0 e conclui o "despiste a segurança".
- [ ] Os dois testes `Vigilia.World.*` passam, e os custos de `stat game` e `stat unit` (Cap. 59) com 12 figurantes estão no `DEVLOG.md`.

---

## Decisões arquiteturais

1. **"O mundo continua existindo" = bolha + memória + fabricação**, nunca simulação contínua do mundo inteiro.
2. **Anéis aninhados** (Full ⊂ spawn ⊂ despawn ⊂ carregamento ⊂ HLOD), validados no perfil até o despawn.
3. **Zona = perfil de população ativo**, com densidade por hora; relógio com dono único.
4. **Pool para a população**, com figurantes simples por contrato e LOD em fatias de custo fixo.
5. **Alerta = calor contínuo + nível com histerese**, filtrado por testemunhas, com a resposta em Blueprint.
6. **Laboratório fora do jogo**: nada disto entra na Vigília sem decisão do Capítulo 76.

---

## Armadilhas

- **Anéis fora de ordem.** Spawn dentro do LOD Full mostra gente surgindo; despawn além do carregamento derruba figurantes no vazio.
- **Despawn por distância pura**, sem teste de visibilidade e sem carência: o bug de mundo aberto mais visível que existe.
- **Pool de pawns sem dormência.** Esconder um `ACharacter` não para o movimento, a malha nem a árvore de comportamento.
- **Figurante complexo.** Vida, inventário e tags de status num ator de população transformam cada reciclagem num bug de reset.
- **LOD que a jogadora pode provar.** Desligar a colisão de quem está à vista quebra o pacto.
- **Wanted sem filtro de percepção** vira punição arbitrária, e a jogadora não aprende nada sobre o sistema.
- **Nível sem histerese.** O nível pisca, a música troca a cada segundo e a resposta nasce e some.
- **Missão que não devolve o mundo.** Densidade reduzida, alerta suspenso ou entidades reservadas que ficam presas depois do fim.

---

## Exercício

**Parte 1 — população (2,5 h).** Monte o nível e os perfis: `DA_Pop_Patio` com picos às 6h, 14h e 22h (as trocas de turno) e `DA_Pop_Vila` com picos às 7h e 19h. Implemente as regras, o relógio, o perfil, o subsistema com o `DrawDebug`, e a extração de `VGVisibility`. Tente quebrar o sistema andando de costas, correndo e girando a câmera, e registre no `DEVLOG.md` cada vez que você **viu** alguém nascer ou sumir.

**Parte 2 — alerta (2 h).** Implemente `VGAlertRules`, o subsistema, os testes, os cheats, as fontes de incidente e a resposta. Jogue três fugas: sem testemunhas, com testemunha e fuga imediata, e com os vigias vendo você. Ajuste `DecayDelay` e `DecayPerSecond` até escapar do nível 2 levar de 20 a 40 segundos.

**Parte 3 — streaming (1,5 h).** Crie uma cópia do laboratório com World Partition (⚠️ confira na sua versão o nome do modelo de nível *Open World* vazio). Nos *World Settings*, reduza a célula e o raio de carregamento da grade de runtime até ver células carregando enquanto anda (⚠️ confira o comando de visualização da grade). Desligue *Is Spatially Loaded* nos pontos de spawn. Ponha o despawn fora do raio de carregamento e descreva o que acontece.

**Parte 4 — a segunda observadora (1,5 h).** A jogadora observa a vila pela câmera de segurança do Capítulo 16, num monitor da guarita. A população continua usando a câmera da jogadora: observe o que dá errado. Generalize `VGVisibility` para "visível para algum observador" (uma lista de pontos de vista ativos). No `DEVLOG.md`: o que muda quando a segunda observadora é **outra jogadora**, noutra máquina? É a pergunta da Parte IX.

**Parte 5 — física → incidente (45 min).** Caixas do Capítulo 15 que caem com impulso acima de um limiar publicam, além do ruído (Cap. 36), um incidente de gravidade 5. Anote uma situação emergente que você não planejou.

---

## Desafio — O turno C tem agenda

Teixeira, Almeida e Prado, do livro de ocorrências do Interlúdio I, ganham **agendas** no laboratório: portaria às 21h40, café no bar da vila às 21h50, Casa de Força às 22h, ronda no pátio às 2h, saída às 6h.

1. Modele a agenda como dados (*hora → lugar → atividade*), sem tick: uma função pura responde "onde Teixeira estaria às H?", usando `IsHourInWindow`.
2. Os três **não** são população: não entram no orçamento, nunca são descartados à vista e não são intercambiáveis. Mas também não estão sempre simulados: fora da bolha, existem só como **registro** (nome, agenda, última posição conhecida).
3. Quando a jogadora se aproxima de onde a agenda diz que Teixeira está, o ator é **fabricado** fora de vista, já no meio da atividade.
4. Com `VGSetHour`, pular de 21h para 2h deve encontrá-lo na ronda, e não "a caminho" desde as 21h.
5. No `DEVLOG.md`: e se a jogadora **seguir** Teixeira da portaria até a Casa de Força? Quando o registro e o ator podem divergir, e qual dos dois é a verdade?

---

## Uso de IA

1. **Para decompor outro mundo aberto:**
   > "Aplique esta ficha de seis passos (experiência, sistema, design, tecnologia, versão mínima, lição) a [Red Dead Redemption 2 / Cyberpunk 2077 / Watch Dogs] em quatro sistemas: streaming, população, simulação em segundo plano e um sistema de resposta a crimes. Para cada afirmação, marque [FATO PÚBLICO] apenas se for observável jogando ou declarada publicamente pelo estúdio, e [INFERÊNCIA] para o resto. Não invente detalhes de implementação."

2. **Para auditar os anéis:**
   > "Revise este subsistema de população da Unreal Engine 5. Procure: casos em que um agente nasce ou some à vista da jogadora, anéis fora de ordem, agentes que continuam custando depois de devolvidos ao pool, referências a elementos de TArray mantidas através de RemoveAtSwap, e o pior caso de traces por quadro. [código]"

3. **Para discutir elegante × adequada:**
   > "Sou arquiteto de software corporativo. Proponha a arquitetura que eu provavelmente desenharia para a população de uma cidade num jogo (identidade, persistência, eventos, consistência) e, ao lado, a que um programador de gameplay experiente desenharia. Para cada diferença, diga qual critério decide (custo por quadro, o que a jogadora pode verificar, iteração) e em que caso a minha versão estaria certa."

**Cuidado específico:** a IA conhece muito folclore de modding e de fóruns sobre os GTA e tende a apresentá-lo como fato sobre o código da Rockstar (limites de população, "como o jogo decide"). Exija a fonte e rebaixe para [INFERÊNCIA] tudo o que não for observável jogando ou declarado pelo estúdio.

---

## Checklist

- [ ] Explico "o mundo continua existindo quando eu não estou olhando" como bolha, memória e fabricação.
- [ ] Aplico a ficha de seis passos a cada sistema de um mundo aberto, separando fato de inferência.
- [ ] Desenho os anéis aninhados e sei o bug que cada inversão produz.
- [ ] Sei por que a população é o caso canônico de pooling e o que a dormência precisa desligar.
- [ ] Separo calor de nível e justifico histerese e decaimento fora de vista.
- [ ] Sei onde a arquitetura adequada vence a elegante, e onde (dois observadores, posse, narrativa) a elegante volta a vencer.
- [ ] O Quarteirão Vivo cumpre os critérios de conclusão.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **World Partition** (com **Data Layers**, **HLOD** e **Level Instancing**), **Level Streaming**, **Mass Entity**, **Significance Manager**, **Chaos Vehicles** e **Physical Animation**.
- **City Sample**, o projeto de exemplo gratuito da Epic, derivado de *The Matrix Awakens*: Mass, multidões, tráfego e World Partition funcionando juntos. Confira a versão da engine exigida.
- **Robert Nystrom, *Game Programming Patterns*** (também gratuito em gameprogrammingpatterns.com): os capítulos *Object Pool*, *Update Method* e *Spatial Partition*.
- **Jason Gregory, *Game Engine Architecture***: os capítulos sobre o modelo de objetos de jogo em runtime e sobre carregamento e streaming de mundo (confira a numeração na sua edição).
- **GDC Vault** (gdcvault.com): palestras sobre streaming de mundo aberto e simulação de multidões e tráfego; procure por *open world streaming*, *crowd* e *traffic* e confira os títulos lá. As palestras de Unreal Fest sobre Mass, publicadas pela Epic, complementam a documentação (confira os títulos).

---

## Estado do projeto ao final do Interlúdio II

Quarteirão Vivo concluído, fora da Vigília. Tudo aqui supôs **uma** observadora; a Parte IX começa onde a Parte 4 do Exercício parou.

---

➡️ **Próximo:** [Parte IX — Capítulo 63: Client/Server](../parte-09/cap-63-client-server.md)

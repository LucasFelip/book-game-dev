# Capítulo 82 — Polish

## Objetivo

Ao final deste capítulo você deve conseguir:

- distinguir **polimento** de **conteúdo novo** e conduzir o Milestone 9 com data fixa e escopo variável;
- ajustar o ***game feel*** de um jogo de terror pela **sutileza** (luz, som, câmera, resposta da lanterna) e reconhecer o "suco" que desfaz o medo;
- **medir o ritmo** com a telemetria dos playtests, usando um script de ferramenta (`Tools/telemetry_report.py`) que transforma os CSVs em duração por beat, mortes por setor, documentos lidos e tempo até o susto;
- conduzir os passes de **áudio, luz, UI e acessibilidade** com listas verificáveis, ligadas aos sistemas da Parte VII;
- organizar um ***bug bash*** com roteiros e triar o que ele encontra (A/B/C);
- decidir, por escrito, **o que não polir**;
- montar uma **lista de polimento com prazo** e zerá-la na data: cada item feito ou cortado com motivo;
- fechar a pendência da Parte X, **"ler para congelar o Diretor"**, com uma decisão de design justificada, o código mínimo e o registro no `DEVLOG.md`.

---

## Contexto

O Capítulo 76 definiu o Milestone 9 (*Polish*) em uma linha: **o jogo "parece" pronto**. Os critérios de conclusão são nenhum bug A aberto e três playtests seguidos sem travamento; o entregável, uma "lista de polimento zerada (dentro do prazo)"; o prazo, as semanas 11 a 13. O registro de riscos já previa o perigo: *o projeto parece "nunca pronto"*, com o sinal "o polimento passa de 3 semanas".

Ao Milestone 9 chegam quatro fluxos:

- os **bugs C** da triagem do Capítulo 79, que foram para a "lista de polimento (Cap. 82), sem garantia";
- o que ficou **abaixo da barra** quando acabou o limite de tempo de cada passe do vertical slice (Cap. 78);
- os **CSVs de telemetria** dos playtests, que o Capítulo 78 gravou e prometeu analisar aqui, "com um script fora do jogo";
- uma **pendência da Parte X**: a estratégia dominante "ler para congelar o Diretor", achada pela análise de loops do Capítulo 70.

O Capítulo 76 também deu a este capítulo o critério do Milestone 7 (*Audio/VFX*): no **teste de olhos fechados**, as jogadoras sabem onde a Presença está só pelo som. Ele entra no passe de áudio.

Uma definição orienta o capítulo inteiro: **polir é fazer o que já existe cumprir o que promete**, e não acrescentar coisas. Se uma ideia deixa o jogo maior do que a página única, e não mais parecido com ela, é escopo, e passa pelo MoSCoW (Cap. 76), não pela lista de polimento.

---

## 82.1 *Game feel* no terror: a resposta que não celebra

*Game feel* é a sensação de controle: como o jogo responde ao que a jogadora faz, no tempo e na intensidade. Em jogos de ação, a resposta é amplificada: tremor de tela, *hitstop* (alguns quadros congelados no impacto), partículas, câmera lenta. Esse acabamento se chama **suco** (*juice*), e a mensagem dele é sempre *você é forte*.

A Vigília diz o contrário: o pilar 3 é **vulnerabilidade**, e a página única exclui "um jogo de sustos baratos". Isso não significa responder menos, e sim responder com outro contrato, de três cláusulas.

1. **O controle é confiável; o mundo não é.** A jogadora nunca pode ter medo dos controles. A barra do Capítulo 78 exige resposta a qualquer interação em menos de 100 ms. O medo vem do que o mundo faz, nunca de uma lanterna que demorou a acender porque o *input* se perdeu.
2. **A resposta é proporcional e nunca celebra.** A sobrecarga da lanterna funciona e a jogadora precisa saber que funcionou, mas o jogo não a premia por isso.
3. **O silêncio também é resposta.** O susto do corredor tem um silêncio pedido por cena (`PushSilence`/`PopSilence`, Cap. 52). Depois do poço, Sônia pergunta "O que você viu?" e Helena não responde (Cap. 81): o silêncio é a resposta. No terror, a ausência é o feedback mais forte, e o mais fácil de estragar com um som a mais.

### Os quatro canais

| Canal | O que polir | Sistema (Parte VII) | Suco demais |
|---|---|---|---|
| **Lanterna** | Clique no mesmo quadro do *input*; LED de bateria legível; carga audível no *Hold* da sobrecarga; feixe a 30% depois do pulso (o custo visível); a Presença "queima" como confirmação | `UVGFlashlightComponent`, `NS_Presenca_Queimada` (Caps. 51, 54) | Tremor no pulso, *hitstop*, tela branca, som de "acerto" recompensador |
| **Câmera** | *Head bob* discreto, sob `CameraMotion`; tremor só para o que o corpo de Helena sente (a turbina perto, o dano) | `AVGPlayerCameraManager` (Cap. 18) | Tremor a cada passo da Presença, *FOV kick*, *motion blur* forte (que ainda causam enjoo) |
| **Som** | Passos por material; respiração; a usina que respira; a Presença sempre audível e honesta sobre a posição | `UVGAudioMixSubsystem`, `MS_Passo_*`, `MS_Usina_Respira`, `ATT_Presenca` (Cap. 52) | Um *stinger* a cada evento, ou música que confirma o perigo de forma confiável |
| **Luz** | A linguagem de luz em 100% das luminárias; a falha (flicker, cascata) é **sempre** a Presença | `AVGLightFixture`, `UVGDirectorSignalComponent` (Caps. 51, 54) | Flicker decorativo: uma luz que pisca sem a Presença é uma **mentira** |

Duas linhas pedem cuidado especial.

**Som.** O som do passo e o ruído que a Presença ouve saem do mesmo *handler* e da mesma `FinalLoudness` (a paridade som × ruído do Cap. 52). Polir o volume de um passo, portanto, **muda o jogo**: se o passo na passarela metálica fica mais baixo porque "estava alto demais", a jogadora deixa de ouvir o que a Presença ouve, e "correr faz barulho" fica menos legível. O ajuste certo é na mixagem da classe (`SC_Jogadora`), nunca na intensidade do ruído.

**Luz.** A linguagem de luz do Capítulo 51 promete que falha é sempre a Presença. Uma lâmpada que pisca "para dar clima" ensina que o sinal não significa nada, e o *Build-up* perde a força. Na triagem do Capítulo 79, "uma luz mentindo" é **bug B**, e não cosmético.

### Como reconhecer o suco demais

Três perguntas, nesta ordem:

1. **Isto deixa a jogadora mais forte ou mais frágil?** Se a deixa mais forte, só entra no único trecho em que o pilar 5 permite (os vigias), e com parcimônia. O *hit marker* existe só ali (Cap. 55).
2. **Isto informa algo de que ela precisa?** O Capítulo 54 exigiu uma função escrita para cada efeito (confirmação, estado ou atmosfera). Um efeito que só "embeleza" o momento não tem função.
3. **Na décima vez, isto ainda assusta ou já irrita?** O susto é um recurso que se gasta. O que funciona uma vez, como a cascata de luzes do corredor, vira ruído quando se repete. É por isso que a mesma cascata aparece só duas vezes no jogo (o corredor e o poço) e de propósito.

> 🌉 **Ponte:** são as microinterações de produto: o botão que responde ao toque, o indicador de carregamento, a animação que confirma o envio. Ninguém as nota quando estão certas, e todo mundo nota quando faltam.
>
> 🧱 **Onde a ponte cai:** em produto, todo feedback existe para **tranquilizar** a pessoa. No terror, parte do feedback existe para **inquietar**, e a resposta mais importante às vezes é a falta dela: o silêncio antes da silhueta, a pergunta de Sônia que fica sem resposta.

---

## 82.2 Ritmo medido: do CSV à curva

O Capítulo 76 desenhou a curva do jogo com durações-alvo: prólogo de cerca de 2 minutos, setor 1 de 4 a 5, setor 2 de 4 a 6, setor 3 de 3 a 5 e final de 1 a 2. O Capítulo 78 passou a gravar o que as jogadoras de fato fizeram. Falta cruzar os dois. A ferramenta é um script Python fora do jogo (seção "Implementação"), só com a biblioteca padrão, no mesmo espírito do `Tools/check_layers.py` do Capítulo 77.

O script responde a quatro perguntas:

| Pergunta | Como o script responde | Fonte no CSV |
|---|---|---|
| Quanto dura cada nível e cada beat? | Último evento de cada arquivo; intervalo entre `Event.Quest.StageEntered` consecutivos | `seconds`, `channel`, `context` |
| Onde as jogadoras morrem? | `Event.Player.Died` por nível, com o último `Event.Trigger.Entered` antes da morte como "local" | `context` do gatilho (`Location.*`, Cap. 31) |
| Os documentos são lidos? | Sessões que abriram × sessões que leram; tempo entre `Opened` e `Read` | `Event.Document.Opened`/`Read` (Cap. 48) |
| Quando chega o susto? | Segundos no nível até `Event.Cinematic.Started` com `Cinematic.S1.Scare` | Cena do corredor (Cap. 49) |

Antes de confiar nos números, conheça os **limites dos dados**. Todos vêm de ler o código dos capítulos anteriores:

- **Um CSV por nível carregado, não por sessão.** O `UVGTelemetrySubsystem` é um subsistema de **mundo** e cria um arquivo novo, com data e hora no nome, a cada `OnWorldBeginPlay`. Quem jogou do Pátio ao final deixa pelo menos cinco arquivos. O script trata **uma pasta como uma sessão**: o `Saved/Telemetry/` de uma pessoa, copiado para `playtests/<apelido>/`.
- **A etapa da quest não está no evento.** O `Event.Quest.StageEntered` publica a **tag da quest** (Cap. 45), e não o índice da etapa. O script numera as etapas pela ordem no arquivo (`Quest.S2.Substation#1`, `#2`…), e a numeração recomeça depois de um *load*: compare beats só entre sessões sem *load* naquele nível.
- **Só documentos lidos têm tempo de leitura.** O leitor (Cap. 48) publica `Opened` ao abrir e `Read` ao fechar, **se** a leitura contou. Um documento abandonado aparece como "aberto, não lido", sem duração.
- **A duração de um nível é um limite inferior**: vai até o último evento, porque não há evento de saída.
- **Em PIE, o nome do mapa vem com prefixo** (`UEDPIE_0_L_CasaDeForca`), que o script remove.

### Ler os números

Com três a dez pessoas, o script se limita a **mediana, mínimo e máximo**; média e porcentagem, com amostras desse tamanho, só produzem precisão falsa. Cada número fora do esperado é uma **pergunta** para as notas de observação (Cap. 78): a telemetria diz **quanto** e **quando**, e as notas dizem **por quê**.

A tabela-modelo abaixo é para você preencher com os **seus** playtests. Nenhum número dela é medido; os alvos vêm do Capítulo 76.

| Trecho | Alvo (Cap. 76) | Mediana medida | Faixa (mín–máx) | O que as notas dizem | Ação |
|---|---|---|---|---|---|
| Prólogo (`L_Patio`) | ~2 min | | | | |
| Setor 1 (`L_CasaDeForca`) | 4–5 min | | | | |
| Tempo até o susto (no setor 1) | perto do fim do setor | | | | |
| Setor 2 (`L_Subestacao`) | 4–6 min | | | | |
| Setor 3 (`L_Turbinas`) | 3–5 min | | | | |
| Final (`L_Final`) | 1–2 min | | | | |
| Mortes por setor | ≤ 2 por pessoa (Cap. 80) | | | | |
| Documentos abertos × lidos | todos abertos por alguém | | | | |

Algumas leituras se repetem de projeto em projeto. Cada uma é um ponto de partida, e não uma regra:

- **Beat com mais de 1,5 vez o alvo.** A jogadora se perdeu ou empacou. Se as notas dizem "não sabia aonde ir", corrija o **espaço** (luz de destaque, linha de visão), e não o texto do objetivo: "o diário diz o quê, o espaço diz onde" (Cap. 55).
- **Beat com menos de metade do alvo.** Conteúdo pulado. Se ninguém abriu os documentos do trecho, a tensão perdeu o vale que eles criavam.
- **Mais de duas mortes por pessoa num setor** (o critério do Cap. 80). Ajuste a **frequência** (o perfil do Diretor) ou a **telegrafia**, nunca as regras da Presença.
- **Documento aberto por todas e lido por poucas**: longo demais, ou leitor desconfortável (fonte, contraste). **Documento que ninguém abriu**: mal posicionado ou mal iluminado; a linguagem de luz tem o destaque para isso.
- **Faixa larga no tempo até o susto.** O gatilho condicionado (Cap. 45) espera o momento certo, e isso é bom. Mas se uma pessoa levou o dobro do tempo da outra, o vale antes do susto foi longo demais para ela, e o susto encontrou uma jogadora entediada, não tensa.

Uma última leitura alimenta a seção 82.7: o script imprime a **leitura mais longa observada**. É esse número que vai calibrar o teto de leitura do Diretor.

---

## 82.3 Os passes de acabamento

Os passes do Capítulo 78 eram **criativos**: transformavam *grey-box* em qualidade final. Os do Milestone 9 são **corretivos**: conferem a barra no jogo inteiro, e não só na fatia. As regras não mudam: limite de tempo fixado antes, e o que não couber vai para a lista de polimento (82.6).

A ordem é luz → áudio → UI → acessibilidade. O som acompanha o que se vê (Cap. 78), e a acessibilidade vem por último porque **audita** os outros passes: cada opção precisa ser respeitada pelo que eles mudaram.

O orçamento sai do cronograma: três semanas a 7–10 horas. Um exemplo **[HIPOTÉTICO]**, para mostrar a conta:

| Bloco | Horas |
|---|---|
| Passe de luz | 3 |
| Passe de áudio | 3 |
| Passe de UI | 2 |
| Passe de acessibilidade | 3 |
| *Bug bash* (2 rodadas) | 3 |
| 3 playtests + relatório | 4,5 |
| Reserva para bugs A e B | 4 |
| **Sobra para a lista de polimento** | **3** |
| **Total (3 semanas × 8,5 h)** | **25,5** |

Três horas para a lista inteira. É por isso que cada item precisa de custo e prazo (82.6), e que a seção 82.5 existe.

### Passe de luz

| Item | Como verificar | Sistema |
|---|---|---|
| Linguagem de luz em 100% das luminárias | Filtre as `AVGLightFixture` de cada nível no Outliner: toda âmbar tem `ProtectedZone`; nenhum destaque ilumina o chão; as frias acendem por fatos | Cap. 51 |
| Falha só com a Presença | Nenhuma `IdlePattern` de falha "decorativa"; flicker só pelo sinal do Diretor (`UVGDirectorSignalComponent`) ou por cena | Caps. 51, 54 |
| Caminho crítico sem preto absoluto | Percorra o caminho com o `BrightnessBias` no mínimo e no máximo da calibração | Cap. 55 |
| Documentos que ninguém abriu | Ganham uma luz de destaque (o relatório da seção 82.2 diz quais) | 82.2 |
| Sombras dentro do orçamento | Lanterna + 2 no setor 1; anote as dos outros setores para o Capítulo 83 | Caps. 51, 83 |
| LED da bateria legível | Sob luz âmbar, sob luz fria e no escuro | Cap. 55 |

### Passe de áudio

| Item | Como verificar | Sistema |
|---|---|---|
| **Teste de olhos fechados** (critério do M7) | No setor 3, peça à pessoa que feche os olhos e aponte para a Presença; repita nos 3 playtests | `ATT_Presenca`, oclusão só nela (Cap. 52) |
| Nenhum som ou voz temporária | Busque `_TEMP` no Content Browser; `Audio/Voz/Temp/` vazia ou registrada como pendência de release | Cap. 78 |
| Mixagem por modo | Em cada setor: ler (mundo −6 dB e passa-baixa, Presença intacta), pausar (as falas param), morrer, ver uma cena | `UVGAudioMixSubsystem` (Cap. 52) |
| O silêncio do susto | A cena pede `PushSilence` e devolve no `Finish` único, inclusive quando cancelada | Caps. 49, 52 |
| No máximo um *stinger* por setor | Liste-os por nível | Cap. 52 |
| Passos em todos os pisos | Todo `UVGPhysicalMaterial` com `FootstepSound`; ande em cada material | Cap. 52 |
| Rádio inteligível | Com a interferência máxima (Hunting + BuildUp) e as legendas desligadas, a fala ainda se entende | `MS_Radio_Voz` |

### Passe de UI

| Item | Como verificar | Sistema |
|---|---|---|
| Só o layout final | Nenhum widget provisório (a tabela "Do provisório ao definitivo" do Cap. 55) | `UVGHUDLayout` |
| A pilha de modos | Pausar lendo; abrir pelo arquivo; morrer com documento aberto; pausar numa cena | Caps. 16, 55 |
| Aviso de objetivo | 3 s a cada mudança de etapa, legível no claro e no escuro | Cap. 55 |
| Legendas | Sincronia, nome do falante, ícone de rádio; nada por cima do documento | `UVGSubtitleWidget` |
| Texto em *String Tables* | Nenhum texto fixo em widget; tudo em `ST_*`, pré-requisito da localização | Cap. 81 |
| Resoluções | 16:9, 16:10 e 21:9; o documento legível em 1280×720 | — |

### Passe de acessibilidade

Aqui a pergunta muda de "a opção existe?" para "**todos os lugares** que deveriam respeitá-la respeitam?". Uma opção que vale em 90% do jogo falha exatamente na pessoa que precisou dela.

| Opção (`UVGGameUserSettings`) | Quem precisa respeitá-la | Como verificar |
|---|---|---|
| `bSubtitlesEnabled` (ligada por padrão), `SubtitleScale`, `SubtitleBackgroundOpacity`, `bShowSpeakerNames` | Rádio, cenas, falas do final, epílogo | Jogue o final com legendas no maior tamanho |
| `CameraMotion` | *Head bob*, balanço da arma (Cap. 29), **todo** tremor de câmera | Procure no código e nos Blueprints quem inicia tremores; cada um lê a opção |
| `bFlickerEnabled` ("reduzir luzes piscando") | Luminárias, sinais do Diretor, a cascata do corredor, a do poço, a perseguição | Jogue o jogo inteiro com a opção ativa: a cascata vira escurecimento em sequência (Cap. 55) |
| `FieldOfView` | Câmera e braços em primeira pessoa | Os braços não "descolam" nos extremos |
| `MusicVolume`, `VoiceVolume`, `EffectsVolume` | As classes de som certas | Zere cada uma e confira o que some; com música no máximo, a voz ainda se entende |

Três itens que não são opções, mas são acessibilidade:

- **Cor.** A linguagem de luz não depende só de matiz: o âmbar seguro é **estável e ilumina o chão**, e o destaque **não** ilumina o chão. Confirme com a simulação de daltonismo (seção "Unreal Engine").
- ***Hold*.** A sobrecarga (0,35 s) e o "pular cena" exigem segurar um botão, o que é barreira para algumas pessoas. Ofereça alternância como *could*, ou registre a limitação.
- **Remapeamento de controles.** Não está no *must* do Capítulo 76. Se não entrar, declare a ausência nas notas de release (Cap. 84).

---

## 82.4 *Bug bash* e triagem

Um *bug bash* é uma sessão com limite de tempo para **quebrar** o jogo de propósito. No playtest, você observa alguém jogar como jogaria; no *bug bash*, quem joga é adversário do jogo. Rende mais com duas ou três pessoas, cada uma com um **roteiro** diferente por rodada: sem roteiro, todo mundo testa as mesmas três coisas.

| Roteiro | O que tentar | O que costuma quebrar |
|---|---|---|
| **A pilha** | Abrir, pausar, fechar e morrer em todas as ordens: documento, rádio, cena, menu, arquivo | Modos de *input* desalinhados (Caps. 16, 55) |
| **Os checkpoints** | A matriz de save do Capítulo 79, com `VGGotoCheckpoint`, `VGSave` e `VGLoad` | Vigias que reaparecem; fatos perdidos |
| **Morrer em todo lugar** | No meio do susto, na perseguição, com o sinalizador aceso, lendo | Estado roteirizado pela metade (Cap. 49) |
| **Fora do caminho** | Paredes, escadas, saltos, a porta da perseguição | Sair do mapa; ficar presa do lado errado da porta |
| **A jogadora estranha** | Ficar parada 10 minutos em cada setor; atravessar tudo correndo sem ler; ler tudo duas vezes | O ritmo do Diretor (a seção 82.7 é um caso deste roteiro); falas que expiram (Cap. 44) |
| **A máquina** | Alt-tab, trocar a resolução numa cena, desconectar o controle, tirar o fone | Perda de foco; *input* preso |

Cada bug encontrado vira um registro curto em `docs/qa/bugs.md`:

```text
BUG-031  [B]  L_Turbinas · passarela norte
  Passos:     CP_S3_Galeria → descer ao poço → morrer na perseguição → carregar
  Esperado:   a porta de manutenção aberta (a perseguição recomeça)
  Observado:  a porta continua fechada; a jogadora fica presa com a Presença
  Estado:     save "bug-031.sav"; cheats: VGGotoCheckpoint CP_S3_Galeria
  BugIt:      BugItGo <posição e rotação copiadas do log>
```

Bug sem passos de reprodução é palpite (Cap. 79). A linha `BugIt` vem de um comando de console da engine (seção "Unreal Engine").

### A triagem

A tabela é a do Capítulo 79, sem mudança:

| Classe | Definição | Prazo |
|---|---|---|
| **A** | Travamento, progresso impossível, perda de save, conteúdo ofensivo por acidente | Corrigir antes de qualquer outra coisa |
| **B** | Atrapalha a experiência: uma fala errada, uma luz mentindo, um objetivo confuso | Corrigir no milestone |
| **C** | Cosmético ou raro | Lista de polimento (Cap. 82), sem garantia |

O registro acima é **B**, mas por pouco. Se a porta fechada impedisse a perseguição em toda tentativa, seria progresso impossível, e portanto **A**. Duas regras práticas para casos assim:

- **Na dúvida entre duas classes, escolha a mais alta** e rebaixe só com um motivo escrito.
- **No terror, a classe depende do pilar.** Um susto que dispara duas vezes é B, porque o segundo vira piada. A Presença que soa de um lado e está do outro é B: mente sobre a posição, e o Capítulo 52 firmou que ela nunca mente. Uma lâmpada que pisca sem motivo é B. Nada disso trava o jogo, e tudo isso desmonta o medo.

---

## 82.5 O que não polir

Polimento não tem fim natural; num projeto individual, o fim precisa ser **decidido**. A régua: a prioridade de um item cresce com **quantas jogadoras o veem**, **por quanto tempo** e **quanto ele toca um pilar**, e diminui com o **custo**.

| Polir | Não polir |
|---|---|
| O caminho crítico, que todas percorrem | Cantos que ninguém visita (o mapa de calor, se você fez o Desafio do Cap. 78) |
| O começo de cada setor, que define a expectativa | Os primeiros cinco minutos **de novo**. A fatia já teve o polimento dela (Cap. 78), e voltar a ela é o jeito mais confortável de não encarar os setores 2 e 3 |
| A **legibilidade** da perseguição: luz, som, rota | O detalhe dos objetos da perseguição, que a jogadora vê correndo |
| Os momentos de pilar: o susto, o poço, a escolha | Sistemas fora do release: o protótipo `GenAI/` (`VG_WITH_GENAI` = 0), o ramo `exp/coop-s1`, a HFSM de estudo (Cap. 42) |
| As opções de acessibilidade do *must* | Ferramentas internas (`Tools/`, painéis de depuração): feias e funcionais está certo |
| Bugs A e B | Itens *could* que nem começaram: continuam *could* ou vão para o *won't* |

Duas tentações merecem nome próprio:

- **Polir o que o próximo capítulo vai mudar.** O Milestone 9 se divide entre os Capítulos 82 e 83, e uma sombra bem ajustada numa luz que o orçamento de frame vai desligar é trabalho jogado fora. Por isso o passe de luz conta as sombras e passa a lista ao Capítulo 83.
- **Polir o código.** Refatorar agora desestabiliza o que estava testado justo quando o jogo precisa ficar parado. No Milestone 9, só se refatora o que um bug A ou B exige, com o teste antes (Cap. 69).

A segunda passada de áudio (*should* no Cap. 76) entra na mesma régua: só com horas sobrando depois dos itens de pilar.

---

## 82.6 A lista de polimento com prazo

A lista mora em `docs/qa/polimento.md`, ao lado da matriz de save (Cap. 79) e dos bugs. Um exemplo **[HIPOTÉTICO]** do formato:

| ID | Item | Origem | Passe | Pilar | Custo (h) | Prazo | Estado |
|---|---|---|---|---|---|---|---|
| P-01 | Teto de leitura no Diretor | Pendência da Parte X | AI | 3 | 1 | Sem. 11 | ✓ feito |
| P-02 | Destaque sobre o recado de Moraes (ninguém abriu) | Telemetria (82.2) | Luz | 2 | 0,5 | Sem. 11 | ✓ feito |
| P-03 | Passo na grade do poço sem som | BUG-007 (C) | Áudio | 3 | 0,5 | Sem. 11 | ✓ feito |
| P-04 | Legenda do epílogo sobrepõe os créditos | BUG-012 (C) | UI | 4 | 1 | Sem. 12 | aberto |
| P-05 | Poeira do feixe some em 21:9 | Abaixo da barra (VFX) | UI | 1 | 2 | Sem. 12 | → *won't*: só em 21:9; custo alto |
| P-06 | Segunda passada de áudio no setor 2 | MoSCoW (*should*) | Áudio | 3 | 6 | Sem. 13 | → *won't*: não cabe no prazo |

As regras da lista:

1. **Nada entra sem origem**: um bug, a barra (Cap. 78), uma nota de playtest, um número da telemetria ou uma pendência registrada. "Seria legal se…" é ideia, e ideias passam pelo MoSCoW.
2. **O custo é estimado antes de começar**, e a soma dos itens abertos cabe nas horas reservadas (82.3).
3. **A ordem é pilar e visibilidade sobre custo.** Itens baratos de pilar primeiro; itens caros de canto, nunca.
4. **A data é fixa.** No fim da semana 13, todo item aberto vai para o *won't*, com o motivo numa linha. **"Zerada" quer dizer nenhum item aberto, e não tudo feito**: é a leitura literal de "datas fixas, escopo variável" (Cap. 76).
5. **Um bug A no meio do milestone** é corrigido primeiro, e a lista absorve o custo cortando por baixo.

---

## 82.7 A pendência da Parte X: ler para congelar o Diretor

### O achado

A análise de loops do Capítulo 70 encontrou no código uma estratégia dominante candidata: o Diretor do Capítulo 42 não passa de `Relax` para `BuildUp`, nem de `BuildUp` para `Peak`, enquanto a jogadora lê (a regra existe para nunca começar um pico com um documento cobrindo a tela). Abrir um documento congelaria o ritmo da ameaça, e a leitura viraria pausa tática. Foram registradas três respostas: aceitar, um teto de leitura ou o pico ao fechar o documento.

### O que o código realmente faz

O próprio Capítulo 70 avisou: *confira a regra no código antes de mexer em qualquer coisa*. Lido com atenção, o `UpdatePhase` do Capítulo 42, com a migração para perfis do Capítulo 80, mostra um exploit **menor** do que a descrição sugere:

- **O `TimeInPhase` nunca para.** O `Tick` soma o `DeltaTime` com ou sem leitura; a leitura só segura as **transições**.
- **O `Relax` já tem um teto.** A condição é `(… && !bReading) || TimeInPhase >= MaxRelaxTime`: lendo ou não, o `BuildUp` começa no `MaxRelaxTime` do perfil (150 s no setor 2, 75 s no setor 3; Cap. 80).
- **O `BuildUp` já tem "o pico ao fechar".** A leitura segura o `Peak` sem limite, mas, como o tempo continuou contando, fechar o documento depois do `BuildUpTime` inicia o pico no *tick* seguinte. A terceira opção do Capítulo 70 já existe pela metade, por acidente.
- **As travas de roteiro passam por cima.** O `Tick` resolve as travas das `AVGDirectorLockZone` (Cap. 80) **antes** do `UpdatePhase`: ler não congela a perseguição.
- **O arquivo fica no menu de pausa** (Cap. 55), e o modo `UI` pausa o jogo. ⚠️ Confira se a pausa continua valendo com `Reading` empilhado por cima (Cap. 16); se continuar, o exploit vive só nos documentos do mundo.

Sobram duas brechas reais. No `Relax`, a leitura adia o `BuildUp` até o `MaxRelaxTime`, mais do que qualquer documento pede. No `BuildUp`, a leitura deixa a jogadora segurar o pico e **escolher o momento** em que ele começa.

As duas não pesam igual. No `BuildUp`, a Presença já está perto (Investigar e Espreitar com pontos **perto**, Cap. 42), e a mixagem de leitura abaixa o mundo mas deixa a Presença intacta (Cap. 52): os passos dela chegam ao documento, e o pico espera do lado de fora. Segurar o `BuildUp` lendo é prender a respiração com alguém do outro lado da porta. Isso é tensão, e não abrigo. No `Relax`, nada está perto e nada se ouve: a leitura vira uma pausa com o mundo andando, que a jogadora controla e pode aprender a usar.

### Os critérios da decisão

1. **Justiça.** Nenhum pico começa com um documento aberto. É a decisão 6 do Capítulo 42, e ela não se negocia: o documento cobre a tela.
2. **O pilar 2.** Ler nunca pode ser punido. Uma jogadora que aprende que ler é perigoso para de ler, e a história da Vigília está nos documentos.
3. **O terror.** Um abrigo que a jogadora controla desfaz o pavor: a Presença vira um cronômetro com botão de pausa.
4. **Acessibilidade.** Quem lê devagar, ou numa segunda língua, não pode ser penalizado por isso.
5. **Custo.**

A comparação das três opções contra esses critérios, e a decisão, estão em "Abordagens". O código fica em "Implementação", e o registro no `DEVLOG.md`, em "Projeto Final".

---

## Estudos de caso

### Max Payne 3 — o suco que celebra

**[FATO PÚBLICO — observável jogando]** *Max Payne 3* (Rockstar, 2012) mantém a câmera lenta (*bullet time*) dos dois jogos da Remedy como mecânica central, com o salto em câmera lenta. Quando cai o último inimigo de um confronto, a câmera acompanha o tiro final, também em câmera lenta.

**[INFERÊNCIA]** Cada camada desse acabamento celebra a competência de quem joga: o tempo se dilata a favor dela, e a câmera se demora no acerto dela. É um contrato de poder, coerente com a fantasia de ação.

**Lição para a Vigília:** inverter cada item. Na sobrecarga da lanterna nada desacelera, a câmera não se demora no acerto, e o custo (o feixe a 30% por um segundo) aparece logo depois. O acabamento que em *Max Payne 3* diz "você venceu" diria na Vigília "você está segura", a frase que um jogo de terror nunca pode dizer.

### Amnesia: A Machine for Pigs — o que se escolhe não ter

**[FATO PÚBLICO — observável jogando]** Em comparação com *The Dark Descent*, *A Machine for Pigs* (The Chinese Room, publicado pela Frictional Games em 2013) não tem inventário nem medidor de sanidade, e a lanterna não consome combustível.

**[INFERÊNCIA]** Tirar sistemas concentra o acabamento no que sobra: o espaço, o som da máquina, o texto. É uma decisão de escopo visível, e tem preço: parte do público sentiu falta da tensão de recursos do primeiro jogo (leia análises da época e forme a sua opinião).

**Lição para a Vigília:** às vezes "o que não polir" é "o que não ter". Um sistema que não serve a um pilar e não cabe no prazo é melhor cortado do que entregue pela metade, como o inventário combinável que foi para o *won't* (Cap. 76). O Milestone 9 é o último momento barato para mais um corte desses.

---

## Comparação com o desenvolvimento tradicional

| Polimento | O que você conhece | Onde a analogia cai |
|---|---|---|
| Milestone de polimento | *Hardening sprint*, congelamento de funcionalidades | Metade dos itens se verifica com uma pessoa jogando |
| *Bug bash* com roteiros | Teste exploratório com *charters* | O roteiro "a jogadora estranha" ataca o ritmo, e não só o código |
| Triagem A/B/C | Severidade de incidentes | "A Presença mente sobre a posição" é grave sem travar nada |
| Relatório de telemetria | *Product analytics* | Com 3 a 10 pessoas, o relatório levanta perguntas, e não estatísticas |
| Lista com data fixa | *Timeboxing* e corte de escopo | "Zerada" quer dizer decidida, não concluída |
| Teto de leitura | *Timeout* | O teto protege uma experiência (o pavor), e não um recurso |

---

## Unreal Engine: o que ajuda no polimento

- **Tremores de câmera** (`UCameraShakeBase`). ⚠️ As classes de padrão de tremor mudaram entre versões do UE5; confira as da sua. No polimento, o que importa é **inventariar** quem inicia tremores: cada ponto precisa respeitar `CameraMotion`.
- **`BugIt` e `BugItGo`**: o primeiro registra a posição e a rotação da câmera (com uma captura de tela), e o segundo leva a câmera de volta a elas. ⚠️ Confira onde a sua versão grava a captura.
- **Modos de visualização** do viewport para o passe de luz (*Lighting Only*, *Detail Lighting*, *Light Complexity*, as visualizações de Lumen e de exposição). ⚠️ Os nomes variam entre versões.
- **Simulação de daltonismo**, por exemplo `UWidgetBlueprintLibrary::SetColorVisionDeficiencyType`. ⚠️ Confira se, na sua versão, ela cobre a cena 3D ou só a UI; no segundo caso, use uma ferramenta externa sobre capturas de tela.
- **Widget Reflector** para o passe de UI, e as **ferramentas de depuração de áudio** (⚠️ procure *Audio Debugging* na documentação da sua versão).
- **Os testes `Vigilia.*`** no build (Cap. 62): polimento que quebra um teste não é polimento.

A engine **não** tem noção de ritmo, de susto ou de "suco demais": isso fica com a telemetria, o playtest e as perguntas da seção 82.1.

---

## Abordagens

### Como conduzir o polimento

| Critério | A. "Até ficar bom" | B. Lista fechada, prazo móvel | **C. Passes com limite + lista com data fixa, priorizada por pilar e telemetria** |
|---|---|---|---|
| **Termina?** | Não | Sim, tarde | Sim, na data |
| **As horas vão para onde a jogadora sente?** | Vão para onde o autor gosta | Na ordem em que os itens foram escritos | Sim (régua da seção 82.5) |
| **Um bug A novo no meio do milestone** | Some na névoa | Empurra a data | Corta a lista por baixo |
| **Adequação à Vigília** | É o risco "nunca pronto" do Cap. 76 | Contradiz "datas fixas" | **Sim** |

**Decisão: C.**

### Ler para congelar o Diretor

| Critério | A. Aceitar | **B. Teto de leitura na saída do `Relax`** | C. A leitura longa atrai a Presença (pico ao fechar) |
|---|---|---|---|
| **Justiça** (nenhum pico com documento aberto) | Sim | Sim | Sim |
| **Pilar 2** (ler nunca é punido) | Sim | Sim, se o teto ficar acima da leitura mais longa medida | Não: ler devagar traz a Presença |
| **Terror** (sem abrigo controlável) | Não: o `Relax` lido vira pausa | Sim: depois do teto, o mundo volta a andar | Sim, até demais |
| **Acessibilidade** | Sim | Sim, com o teto calibrado pela leitora mais lenta | Não: pune quem lê devagar |
| **Custo** | Zero | Um campo no perfil, uma variável, três linhas | Médio: um estímulo de percepção novo e um ramo na BT da Presença |
| **O que a jogadora aprende** | "Ler pausa a ameaça" | "Ler protege, mas não para o mundo" | "Ler é perigoso" |

**Decisão: B, o teto de leitura, aplicado só à saída do `Relax`.** O teto fecha a única brecha que é abrigo e deixa o `BuildUp` como está, porque ali segurar o pico já é tensão: é o efeito da opção C, que o código produz por acidente, sem o custo dela e sem punir a leitura. A opção A é defensável (talvez ninguém perceba), mas o `Relax` lido dura até 150 s, mais do que qualquer documento pede, e o teto custa três linhas. A opção C ensinaria a pior lição para um jogo cuja história está nos documentos, e a coluna "lidos" do relatório mostraria o estrago.

🔁 **Uma adaptação ao código real.** O Capítulo 70 previa "uma constante nova em `VGDirectorTuning`". Esse *namespace* não existe mais: o Capítulo 80 o dissolveu no `UVGDirectorProfile`. A constante vira um **campo do perfil**, com valor padrão, coerente com a decisão 7 do Capítulo 42 (parâmetros de *pacing* como dados). Os perfis dos setores herdam o padrão e só o sobrescrevem se o playtest pedir.

---

## Implementação

### 1. O relatório de ritmo

```python
#!/usr/bin/env python3
"""Ritmo do jogo a partir da telemetria de playtest (Cap. 82; formato do CSV no Cap. 78).
Uso: python Tools/telemetry_report.py playtests/ana playtests/bia ...
Cada pasta é UMA sessão: o conteúdo de Saved/Telemetry/ de uma pessoa (um CSV por nível carregado)."""
import argparse
import csv
import statistics
from collections import defaultdict
from pathlib import Path

STAGE = "Event.Quest.StageEntered"  # contexto = tag da QUEST (Cap. 45); a etapa sai da ordem
DIED = "Event.Player.Died"
TRIGGER = "Event.Trigger.Entered"  # contexto = Location.* (Cap. 31)
OPENED, READ = "Event.Document.Opened", "Event.Document.Read"  # Read só ao fechar, se contou (Cap. 48)
SCARE = ("Event.Cinematic.Started", "Cinematic.S1.Scare")  # o susto do corredor (Cap. 49)


def load_session(folder):
    """Os níveis carregados numa sessão, em ordem; cada um é uma lista de linhas."""
    runs = []
    for path in sorted(Path(folder).glob("*.csv")):  # nome AAAAMMDD-HHMMSS: ordem alfabética = cronológica
        with open(path, newline="", encoding="utf-8-sig") as f:  # -sig: tolera o BOM de planilhas
            rows = list(csv.DictReader(f))
        for row in rows:
            row["seconds"] = float(row["seconds"])
            if row["map"].startswith("UEDPIE_"):  # PIE: UEDPIE_0_L_CasaDeForca
                row["map"] = row["map"].split("_", 2)[2]
        if rows:
            runs.append(rows)
    return runs


def summarize(sessions):
    level_time, beat_time = defaultdict(list), defaultdict(list)
    deaths = defaultdict(lambda: defaultdict(int))
    opened_by, read_by, read_time = defaultdict(int), defaultdict(int), defaultdict(list)
    scare = []
    for runs in sessions:
        opened, read, scare_at = set(), set(), None
        for rows in runs:
            level, end = rows[0]["map"], rows[-1]["seconds"]
            level_time[level].append(end)  # limite inferior: não há evento de saída
            stages, ordinal = [r for r in rows if r["channel"] == STAGE], defaultdict(int)
            for i, r in enumerate(stages):
                ordinal[r["context"]] += 1
                until = stages[i + 1]["seconds"] if i + 1 < len(stages) else end
                beat_time[f'{r["context"]}#{ordinal[r["context"]]}'].append(until - r["seconds"])
            place, open_at = "?", {}
            for r in rows:
                channel, context = r["channel"], r["context"]
                if channel == TRIGGER:
                    place = context
                elif channel == DIED:
                    deaths[level][place] += 1
                elif channel == OPENED:
                    open_at[context] = r["seconds"]
                    opened.add(context)
                elif channel == READ:
                    read.add(context)
                    if context in open_at:
                        read_time[context].append(r["seconds"] - open_at.pop(context))
                if (channel, context) == SCARE and scare_at is None:
                    scare_at = r["seconds"]  # segundos NO NÍVEL até a cena
        for doc in opened:
            opened_by[doc] += 1
        for doc in read:
            read_by[doc] += 1
        scare.append(scare_at)
    return {
        "sessions": len(sessions),
        "level_time": dict(level_time),
        "beat_time": dict(beat_time),
        "deaths": {level: dict(places) for level, places in deaths.items()},
        "documents": {doc: (opened_by[doc], read_by[doc], read_time.get(doc, [])) for doc in opened_by},
        "scare": scare,
    }


def report(s):
    def spread(values):
        return f"{statistics.median(values):7.1f}   {min(values):.1f}–{max(values):.1f}   n={len(values)}"

    print(f"Sessões: {s['sessions']}")
    print("\nDURAÇÃO POR NÍVEL, s (mediana, mín–máx; até o último evento)")
    for level, values in s["level_time"].items():
        print(f"  {level:<30}{spread(values)}")
    print("\nDURAÇÃO POR BEAT, s (etapa = ordem do StageEntered no arquivo)")
    for beat, values in s["beat_time"].items():
        print(f"  {beat:<30}{spread(values)}")
    print("\nMORTES POR NÍVEL (local = último gatilho antes da morte)")
    for level, places in s["deaths"].items():
        print(f"  {level:<30}{sum(places.values()):3}   " + ", ".join(f"{p} ×{n}" for p, n in places.items()))
    print("\nDOCUMENTOS (sessões que abriram / que leram; leitura em s)")
    for doc, (opened, read, times) in s["documents"].items():
        extra = f"   mediana {statistics.median(times):.0f}, máx {max(times):.0f}" if times else ""
        print(f"  {doc:<30}{opened}/{read}{extra}")
    longest = max((t for _, _, times in s["documents"].values() for t in times), default=None)
    if longest is not None:
        print(f"  Leitura mais longa observada: {longest:.0f} s (base do teto de leitura do Diretor)")
    print(f"\nSUSTO DO CORREDOR, s no nível até a cena (None = não viu): {s['scare']}")


def _self_test():
    import tempfile
    casa = (
        "seconds,map,channel,context,target\n"
        "0.50,UEDPIE_0_L_CasaDeForca,Event.Quest.StageEntered,Quest.S1.NightShift,\n"
        '10.00,UEDPIE_0_L_CasaDeForca,Event.Document.Opened,Document.S1.Memo,"BP_Livro, ""o"" do vestiário"\n'
        "40.00,UEDPIE_0_L_CasaDeForca,Event.Document.Read,Document.S1.Memo,\n"
        "50.00,UEDPIE_0_L_CasaDeForca,Event.Document.Opened,Document.S1.Locker,\n"
        "60.50,UEDPIE_0_L_CasaDeForca,Event.Quest.StageEntered,Quest.S1.NightShift,\n"
        "70.00,UEDPIE_0_L_CasaDeForca,Event.Trigger.Entered,Location.S1.CorridorCurve,\n"
        "71.00,UEDPIE_0_L_CasaDeForca,Event.Cinematic.Started,Cinematic.S1.Scare,\n"
    )
    turbinas = (
        "seconds,map,channel,context,target\n"
        "3.00,L_Turbinas,Event.Trigger.Entered,Location.S3.Catwalk,\n"
        "12.25,L_Turbinas,Event.Player.Died,,BP_VGJogadora_C_0\n"
    )
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "20261112-200000.csv").write_text(casa, encoding="utf-8")
        (Path(tmp) / "20261112-201500.csv").write_text(turbinas, encoding="utf-8")
        s = summarize([load_session(tmp)])
    assert s["level_time"] == {"L_CasaDeForca": [71.0], "L_Turbinas": [12.25]}, s["level_time"]
    assert s["beat_time"] == {"Quest.S1.NightShift#1": [60.0], "Quest.S1.NightShift#2": [10.5]}, s["beat_time"]
    assert s["deaths"] == {"L_Turbinas": {"Location.S3.Catwalk": 1}}, s["deaths"]
    assert s["documents"] == {"Document.S1.Memo": (1, 1, [30.0]), "Document.S1.Locker": (1, 0, [])}, s["documents"]
    assert s["scare"] == [71.0], s["scare"]


if __name__ == "__main__":
    _self_test()
    parser = argparse.ArgumentParser(description="Relatório de ritmo dos playtests da Vigília (Cap. 82).")
    parser.add_argument("sessions", nargs="*", default=["Saved/Telemetry"], help="uma pasta por sessão")
    report(summarize([load_session(folder) for folder in parser.parse_args().sessions]))
```

Os nomes `Document.S1.Locker` e `Location.S3.Catwalk` do auto-teste são ilustrativos (os seus estão em `docs/design/tags.md`). Se a tag da cena do susto não for `Cinematic.S1.Scare` (Cap. 49), ajuste `SCARE`.

### 2. 🔁 O teto de leitura no Diretor

**Antes** (Caps. 42 e 80): a leitura segurava as duas transições, sem limite, e o `Relax` só terminava lendo quando atingia o `MaxRelaxTime`. **O problema**: um abrigo que a jogadora controla, no trecho em que nada está perto. **Agora**: a leitura segura a saída do `Relax` só até um teto; o `BuildUp` não muda.

```cpp
// Source/Vigilia/AI/VGDirectorProfile.h — acréscimo à classe do Cap. 80
    /**
     * Teto de leitura (s): quanto tempo de leitura CONTÍNUA ainda segura a saída do Relax.
     * Depois dele, o Build-up pode começar com o documento aberto. O pico, não: ele nunca
     * começa durante a leitura (Cap. 42); no Build-up, quem o libera é fechar o documento.
     * Simplificação: um teto único para todos os documentos, calibrado pela leitura mais longa
     * do playtest (Tools/telemetry_report.py). Teto por documento só se o relatório mostrar
     * leituras muito desiguais entre eles.
     */
    UPROPERTY(EditDefaultsOnly, Category = "Pacing", meta = (ClampMin = "0.0"))
    float MaxReadingHold = 60.0f;
```

```cpp
// Source/Vigilia/AI/VGDirectorSubsystem.h — acréscimo à seção private
    /** Leitura contínua, no relógio do Diretor (o DeltaTime do Tick, o mesmo de TimeInPhase). */
    float ReadingTime = 0.0f;
```

```cpp
// Source/Vigilia/AI/VGDirectorSubsystem.cpp — UpdatePhase (trecho: perfil do Cap. 80 + teto do Cap. 82)
void UVGDirectorSubsystem::UpdatePhase(float DeltaTime)
{
    const bool bReading = IsPlayerReading(); // modo Reading na pilha do PlayerController (Cap. 16)
    ReadingTime = bReading ? ReadingTime + DeltaTime : 0.0f;
    const bool bReadingHoldsRelax = bReading && ReadingTime < Profile->MaxReadingHold;

    switch (Phase)
    {
    case EVGDirectorPhase::Relax:
        if ((TimeInPhase >= Profile->MinRelaxTime && Tension < 0.2f && !bReadingHoldsRelax)
            || TimeInPhase >= Profile->MaxRelaxTime)
        {
            EnterPhase(EVGDirectorPhase::BuildUp);
        }
        break;
    case EVGDirectorPhase::BuildUp:
        // Sem teto aqui, de propósito: nenhum pico começa com um documento aberto (Cap. 42).
        // O TimeInPhase não para durante a leitura: fechar o documento depois do BuildUpTime inicia o pico.
        if (TimeInPhase >= Profile->BuildUpTime && !bReading && Profile->bAllowPeak)
        {
            EnterPhase(EVGDirectorPhase::Peak);
        }
        break;
    // … case Peak e case Recovery: os do Cap. 42, lendo Profile-> (Cap. 80). Sem mudança; omitidos aqui.
    }
}
```

Os 60 s são um ponto de partida, **[DECISÃO DE PROJETO]**, e não uma medida. Sem playtests, use o dobro do `VGDocumentRules::EstimateReadSeconds` do documento mais longo (Cap. 48); com playtests, a leitura mais longa do relatório com margem (por exemplo, 1,5 vez).

### Explicação das decisões

**O relatório:**

- **Uma pasta por sessão**, porque o subsistema de telemetria é de mundo e grava um arquivo por nível. Juntar por pasta é mais honesto do que adivinhar sessões pelo horário.
- **`csv.DictReader` lê o escape do Capítulo 78** (RFC 4180). O auto-teste usa a mesma linha difícil do teste C++ daquele capítulo, e assim os dois lados do formato ficam presos ao mesmo exemplo. `utf-8-sig` tolera o BOM que algumas planilhas acrescentam.
- **Mediana e faixa, nunca média.** Com três a dez pessoas, uma única jogadora perdida move a média e não move a mediana; a faixa mostra que ela existiu.
- **Os limites dos dados estão no texto da saída** ("até o último evento", "etapa = ordem"): quem lê o relatório daqui a um mês não vai lembrar deste capítulo.
- **O auto-teste roda sempre**, como no `check_layers.py`, e só a biblioteca padrão é usada: o script roda em qualquer máquina com Python 3, inclusive na de quem fez o playtest.

**O teto:**

- **Só no `Relax`.** No `BuildUp`, mudar a regra obrigaria a escolher entre começar o pico com o documento aberto (injusto) e fechá-lo à força (pior).
- **O relógio é o do Diretor** (o `DeltaTime` do `Tick`: dilata e pausa), o mesmo do `TimeInPhase`. O leitor usa o relógio real para decidir se um documento foi lido (Cap. 48), e está certo para aquela pergunta; o teto compara leitura com o ritmo do Diretor, e por isso conta no relógio dele.
- **Fechar e reabrir não engana o teto.** O contador zera no primeiro *tick* sem leitura, e nesse mesmo *tick* a transição passa, se as outras condições valerem. Se não valerem (a tensão ainda alta), não era a leitura que segurava o `Relax`.
- **Sem regra de validação nem teste novos.** Um teto de 0 s é uma escolha legítima, e um teto acima do `MaxRelaxTime` apenas nunca age; nenhum dos dois é erro de dado. A mudança é uma condição de uma linha num método privado que precisa de mundo; a verificação é uma receita no PIE (Exercício, Parte 4), e o Diretor continua com o teste do perfil (Cap. 80).

---

## Projeto Final — Milestone 9: o jogo que parece pronto

O que muda no projeto Vigília:

- [ ] `Tools/telemetry_report.py` ao lado do `check_layers.py`; os CSVs em `playtests/<apelido>/` (fora do controle de versão, se preferir: são dados de pessoas, mesmo sem nada pessoal neles).
- [ ] `docs/qa/ritmo.md` (a tabela-modelo preenchida), `docs/qa/bug-bash.md` (os roteiros), `docs/qa/bugs.md` (os bugs triados) e `docs/qa/polimento.md` (a lista, zerada na data).
- [ ] Os quatro passes feitos, com o limite e as horas no `DEVLOG.md`.
- [ ] 🔁 `UVGDirectorProfile::MaxReadingHold`, `UVGDirectorSubsystem::ReadingTime` e o `UpdatePhase` com o teto; os testes `Vigilia.*` verdes.

O registro da decisão no `DEVLOG.md`:

```text
[data] — Pendência da Parte X fechada: "ler para congelar o Diretor" (Cap. 70)
Achado:     conferido no código: o TimeInPhase não para; o Relax já tinha teto (MaxRelaxTime);
            no BuildUp, fechar o documento já iniciava o pico. Brecha real: o Relax lido era uma
            pausa que a jogadora controla.
Decisão:    opção 2 (teto), só na saída do Relax: UVGDirectorProfile::MaxReadingHold (padrão 60 s).
            Mantida a decisão 6 do Cap. 42: nenhum pico começa com documento aberto.
Por quê:    o BuildUp lido já é tensão; a opção 3 pune a leitura (pilar 2) e quem lê devagar;
            a opção 1 deixa um abrigo de até 150 s que se aprende.
Número:     leitura mais longa nos playtests = ___ s (telemetry_report.py) → teto = ___ s.
Verificado: PIE, L_Subestacao, Gameplay Debugger: BuildUp com o documento aberto depois do teto;
            Peak só depois de fechar.
Rever se:   alguém disser no playtest que "o jogo pausa quando eu leio".
```

**Fechamento do Milestone 9**, com os critérios do Capítulo 76 sem reinterpretação: nenhum bug A aberto; três playtests **seguidos** sem travamento (se o terceiro travar, a contagem recomeça); a lista sem itens abertos na data. Se a data chegar com um bug A aberto, o milestone não fecha e o registro de riscos ganha uma linha: é o único caso em que a data se move, porque um bug A não é escopo.

---

## Decisões arquiteturais

1. **Polir é cumprir a promessa, não crescer**; o que cresce passa pelo MoSCoW.
2. ***Game feel* de terror**: controle confiável, resposta sem celebração; a linguagem de luz e a paridade som × ruído limitam o polimento.
3. **Ritmo medido por script fora do jogo**, biblioteca padrão e auto-teste; uma pasta por sessão; mediana e faixa.
4. **Passes corretivos com limite**, luz → áudio → UI → acessibilidade (a auditoria).
5. ***Bug bash* com roteiros** e triagem A/B/C do Capítulo 79, com a classe pesada pelo pilar.
6. **Lista com origem, custo e prazo**; "zerada" quer dizer decidida.
7. **Teto de leitura só na saída do `Relax`**, como campo do perfil; nenhum pico começa com documento aberto.

---

## Armadilhas

- **"Só mais uma vinheta"**: polimento que vira conteúdo novo.
- **Suco de ação num jogo de terror**, e o **flicker decorativo**, que ensina a jogadora a ignorar o sinal da Presença.
- **Baixar o volume do passo mexendo no ruído**, em vez de mexer na mixagem.
- **Ler o CSV como se fosse a sessão inteira**, ou comparar beats entre sessões com *load* no meio.
- **Opção de acessibilidade que vale "quase sempre"**: o tremor esquecido na cena, o flicker esquecido no poço.
- **Rebaixar a classe de um bug para caber no prazo**, ou "zerar" a lista estendendo a data.
- **Repolir a fatia** em vez de encarar os setores 2 e 3.
- **Fechar um exploit sem ler o código.** O Capítulo 70 descreveu um problema maior do que o que existia.
- **Teto de leitura abaixo da leitura mais lenta**: pune justamente quem o pilar 2 quer proteger.

---

## Exercício

**Parte 1 — o relatório (1 h).** Copie o `Saved/Telemetry/` de cada playtest para `playtests/<apelido>/` e rode `python Tools/telemetry_report.py playtests/*` (no PowerShell, liste as pastas). Preencha a tabela-modelo da seção 82.2 com uma hipótese, tirada das notas, para cada linha fora do alvo.

**Parte 2 — os passes (11 h).** Fixe o limite de cada passe e percorra as quatro listas. O que não couber vira linha na lista de polimento.

**Parte 3 — o *bug bash* (3 h).** Duas rodadas de 1,5 h com roteiros diferentes. Registre e trie cada bug; pelo menos um com `BugIt` e estado de teste.

**Parte 4 — o teto (1 h).** Implemente o 🔁 do Diretor e calibre o `MaxReadingHold` com a leitura mais longa do relatório. Verifique no PIE, no `L_Subestacao`, com o Gameplay Debugger aberto:

1. espere o `Relax` passar do `MinRelaxTime`, com a tensão baixa;
2. abra um documento e não feche: o `BuildUp` deve começar depois do teto, com o documento aberto, e os sinais devem ser audíveis;
3. continue lendo além do `BuildUpTime`: o `Peak` **não** pode começar;
4. feche o documento: o `Peak` começa no *tick* seguinte.

Escreva a entrada no `DEVLOG.md`.

**Parte 5 — a lista (1 h, mais a data).** Monte `docs/qa/polimento.md` com origem, custo e prazo. Na data, zere-a: cada item feito ou movido para o *won't*, com motivo.

---

## Desafio — o Diretor na telemetria

A tabela de telemetria do Capítulo 78 tinha uma linha nunca implementada ("O Diretor respira? | Tempo em cada fase"), e o *postmortem* do Capítulo 85 afirma que "um playtest com telemetria teria mostrado antes" a leitura que congela o Diretor. Torne a frase verificável:

1. Publique as mudanças de fase no barramento a partir do `EnterPhase`, com uma tag nativa nova e a fase no contexto (tags de conteúdo `Director.Phase.*`, registradas em `docs/design/tags.md`).
2. Estenda o relatório: tempo em cada fase por nível e, para cada leitura, a fase em que começou e terminou. Cada métrica nova ganha uma linha no CSV do auto-teste e um `assert`.
3. Rode-o sobre playtests feitos **antes** do teto. Alguém leu no `Relax` por mais tempo do que o teto permitiria hoje? A telemetria teria revelado a brecha antes do Capítulo 70?

---

## Uso de IA

1. **Para cortar a lista:**
   > "Atue como produtor de jogos independentes. Aqui está minha lista de polimento (tabela abaixo, com origem, pilar e custo em horas) e tenho N horas até a data fixa. Ordene por pilar e visibilidade sobre custo, diga o que cabe e o que vai para o *won't*, com um motivo de uma linha para cada corte. Não acrescente itens novos. [lista]"

2. **Para ler o relatório:**
   > "Aqui está a saída do meu script de telemetria (abaixo) e as notas de observação dos mesmos playtests. Para os três trechos mais distantes destes alvos [alvos], proponha hipóteses que as notas confirmam ou derrubam, citando a linha da nota. Se as notas não sustentarem nenhuma hipótese, diga isso. Não calcule nada de cabeça. [saída] [notas]"

3. **Para os roteiros do *bug bash*:**
   > "Gere oito roteiros de *bug bash* de 20 minutos para um jogo de terror em primeira pessoa com pilha de modos de *input*, checkpoints com fatos narrativos, cenas que a morte cancela, um Diretor de ritmo com zonas de trava e uma perseguição com porta que fecha. Para cada roteiro: o que tentar, o que costuma quebrar e como registrar a reprodução."

4. **Para auditar a acessibilidade:**
   > "Para cada uma destas opções [lista do `UVGGameUserSettings`], liste os tipos de lugar num jogo de terror em primeira pessoa que precisam respeitá-la e que costumam ser esquecidos (cenas, sinais de IA, pós-processamento, efeitos de partícula). Não proponha opções novas."

**Cuidado específico:** o conselho genérico de *game feel* que a IA oferece vem quase todo de jogos de ação ("acrescente tremor, partículas, *hitstop*, um som de recompensa"). Passe cada sugestão pelas três perguntas da seção 82.1. E, com três a dez playtests, ela calcula porcentagens e "tendências" com prazer: exija mediana, faixa e o código do cálculo (Cap. 78).

---

## Checklist

- [ ] Revisei lanterna, câmera, som e luz com as três perguntas do suco.
- [ ] O relatório de telemetria roda com o auto-teste, e conheço os limites dos dados.
- [ ] Fiz os quatro passes com limite de tempo, incluindo o teste de olhos fechados.
- [ ] Fiz o *bug bash* com roteiros e triei tudo com a tabela do Capítulo 79.
- [ ] Escrevi o que não vou polir, e a lista de polimento foi zerada na data.
- [ ] Fechei "ler para congelar o Diretor" com decisão, código, verificação e `DEVLOG.md`.
- [ ] Milestone 9: nenhum bug A aberto; três playtests seguidos sem travamento.

---

## Para ir além

- **Steve Swink, *Game Feel: A Game Designer's Guide to Virtual Sensation*** — o vocabulário de *game feel*, útil para perceber o que se ajusta quando se "ajusta a sensação".
- **As palestras *Juice it or lose it* (Martin Jonasson e Petri Purho) e *The Art of Screenshake* (Jan Willem Nijman)**, disponíveis em vídeo — o manual do suco, útil aqui pelo contraste. Confira as fontes antes de citar.
- **Game Accessibility Guidelines** (gameaccessibilityguidelines.com) e **Xbox Accessibility Guidelines** (documentação da Microsoft) — listas de verificação de acessibilidade, com exemplos.
- **Documentação do Python** (docs.python.org): os módulos `csv`, `statistics` e `argparse`.
- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): *Camera Shakes*, depuração de áudio e os modos de visualização do viewport.
- **GDC Vault** (gdcvault.com): palestras sobre playtest, telemetria em equipes pequenas e polimento (confira os títulos lá).

---

➡️ **Próximo:** [Capítulo 83 — Performance](cap-83-performance.md)

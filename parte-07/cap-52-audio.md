# Capítulo 52 — Audio

## Objetivo

Ao final deste capítulo você deve conseguir:

- descrever o caminho de um som na Unreal: fonte, instância, atenuação, espacialização, *Sound Class*, *Submix* e saída;
- usar **MetaSounds** para sons que reagem ao jogo por parâmetros;
- configurar **atenuação**, **espacialização**, **oclusão** e reverberação por espaço;
- montar uma **mixagem dinâmica** (*Sound Classes*, *Sound Mixes*, *Submixes*, com uma visão cautelosa de *Audio Modulation*) que reage aos modos de input, ao Diretor e às cenas;
- tratar o som como **informação** (passos, a Presença, o estado do mundo) e como **medo** (antecipação, silêncio);
- aplicar o **filtro de rádio** na voz de Sônia, prometido no Capítulo 44, com interferência ligada à ameaça;
- manter o **ruído da jogadora** e o **som da jogadora** saindo da mesma conta, para a percepção (Cap. 36) não mentir.

---

## Contexto

O áudio da Vigília, até aqui, é o mínimo do Interlúdio I: um zumbido elétrico, gotejamento no subsolo, vento no hall, a usina que "respira" a cada 30–60 s (um `AVGAlarm` sem sirene) e passos mais altos na grade. E uma linha no grafo que já era a melhor ideia de áudio do protótipo: **o zumbido para um segundo antes do susto**.

Vários capítulos deixaram promessas para este:

- o Capítulo 44 tocou a voz de Sônia com `SpawnSound2D` e avisou que "o filtro de áudio vem no Cap. 52";
- o Capítulo 17 fez os passos **anunciarem** e disse que o áudio se inscreveria; o 36 transformou passos em **ruído** para a IA;
- o Capítulo 16 criou `OnInputModeChanged` pensando, entre outros, no áudio ("abafar o som do mundo ao abrir um documento");
- o Capítulo 42 fez o Diretor publicar sinais de `BuildUp` que deveriam mudar "a camada de música";
- o Capítulo 48 deu aos documentos uma `Narration` opcional (fitas);
- o Capítulo 51 deixou o "carregar" da sobrecarga com um evento esperando um zumbido crescente.

A Introdução disse que os jogos de referência do leitor dependem mais de luz e som do que de qualquer outro sistema. A luz foi o capítulo anterior. Este é o outro pilar.

---

## 52.1 O caminho de um som

Um som num jogo passa por uma cadeia, e cada elo é um lugar onde o design decide alguma coisa:

```text
 FONTE                 INSTÂNCIA                ESPAÇO                     MIXAGEM                 SAÍDA
 ─────                 ─────────                ──────                     ───────                 ─────
 Sound Wave            UAudioComponent          Atenuação (distância)      Sound Class (volume     Submix master
 Sound Cue             ou "dispare e esqueça"   Espacialização (direção)   por categoria)          → dispositivo
 MetaSound Source      (PlaySoundAtLocation)    Oclusão (obstáculos)       Sound Mix (ajustes      
                       parâmetros do jogo ─►    Reverb (o espaço soa)      por estado)             
                                                Concorrência (limites)     Submix (efeitos, DSP)   
```

- A **fonte** é o asset: um `USoundWave` (um arquivo de áudio), um `USoundCue` (um grafo de nós sobre waves, o sistema clássico) ou uma **MetaSound Source** (seção 52.2).
- A **instância** é o som tocando agora: um `UAudioComponent` (quando você precisa controlá-lo depois: parar, mudar parâmetros, mover) ou um disparo sem controle (`PlaySoundAtLocation`, para um passo ou um impacto).
- O **espaço** decide como o som chega ao ouvinte: quanto ele cai com a distância, de que direção vem, se uma parede o abafa, como a sala reverbera.
- A **mixagem** agrupa sons em categorias e ajusta as categorias conforme o estado do jogo.
- A **concorrência** (*Sound Concurrency*) limita quantas instâncias de um tipo tocam ao mesmo tempo. Vinte passos simultâneos não são vinte vezes mais informação; são ruído e custo.

O motor de áudio da Unreal é o ***Audio Mixer***, que processa tudo num *thread* de áudio próprio, em blocos de amostras, separado do *game thread*. Isso tem uma consequência para o código: quando você muda um parâmetro de um som, a mudança chega ao áudio **no próximo bloco**, não no mesmo instante. Para passos e falas, é imperceptível; para música sincronizada a ritmo, é o motivo de existirem ferramentas próprias (⚠️ *Quartz*, o sistema de *timing* musical da Unreal, fora do escopo).

> 🌉 **Ponte:** a cadeia é um *pipeline* de processamento de *stream*, com estágios de transformação e um barramento de saída, parecido com um grafo de filtros de mídia ou um *pipeline* de logs com roteamento por categoria.
>
> 🧱 **Onde a ponte cai:** um *pipeline* de dados tolera atraso e se preocupa com *throughput*. O áudio tem um prazo rígido a cada bloco de poucos milissegundos: se o bloco atrasa, o som estala, e todo mundo ouve. É um sistema de **tempo real duro**, mais perto de um *driver* que de um serviço.

---

## 52.2 MetaSounds

**MetaSounds** é o sistema de áudio procedural do UE5: um grafo de nós (osciladores, *players* de wave, filtros, envelopes, aleatoriedade, matemática, gatilhos) que roda no *thread* de áudio com precisão de amostra. Uma *MetaSound Source* é um asset que **é** um som, com **entradas** que o jogo controla.

A diferença em relação a um `USoundWave` é a mesma entre um arquivo estático e um programa: o wave toca sempre igual; a MetaSound recebe parâmetros e decide o que tocar. Quatro usos na Vigília:

| MetaSound | Entradas | O que faz |
|---|---|---|
| `MS_Passo` | — | Escolhe uma variação aleatória do banco, com pequena variação de *pitch* e volume: nenhum passo soa igual ao anterior |
| `MS_Usina_Respira` | `Intensidade` (float) | O ronco grave da usina, com intervalo irregular gerado no próprio grafo; mais intenso quando a usina "acorda" (setores energizados) |
| `MS_Radio_Voz` | `Voz` (wave), `Interferencia` (float) | O filtro de rádio de Sônia (seção 52.8) |
| `MS_Trilha_Tensao` | `Tensao` (float 0–1) | Camadas de trilha que entram e saem com a tensão do Diretor (seção 52.4) |

O jogo fala com uma MetaSound por **parâmetros** no `UAudioComponent` que a toca: `SetFloatParameter`, `SetIntParameter`, `SetBoolParameter`, `SetObjectParameter` (para passar um wave), `SetTriggerParameter`. ⚠️ Esses métodos vêm da interface de parâmetros de áudio (`ISoundParameterControllerInterface`), do módulo `AudioExtensions`; confira se o seu `Build.cs` precisa dele para linkar.

E uma regra de ouro: **suavize dentro do grafo**, não no código. O jogo manda o valor-alvo de `Tensao` quatro vezes por segundo; a MetaSound interpola até ele (há nós de interpolação para isso). Mandar o valor a cada frame do jogo, interpolado em C++, só gasta comunicação entre *threads* e não soa melhor.

> ⚠️ **Sound Cues continuam valendo.** Para variação aleatória simples, um Sound Cue resolve, e muitos projetos misturam os dois. A Vigília usa MetaSounds onde há parâmetros vindos do jogo e Cues ou waves onde não há.

---

## 52.3 Atenuação, espacialização, oclusão e o som do espaço

Em primeira pessoa, o som é metade da orientação. A jogadora não tem olhos nas costas; tem ouvidos.

**Atenuação** é quanto o som cai com a distância. Um asset `USoundAttenuation` define a forma (esfera, cápsula, caixa, cone), o raio interno (onde o volume é máximo) e a distância de *falloff* com uma curva. Dois princípios de design:

- **A curva é uma decisão de jogo, não de física.** O passo da Presença deve ser audível a ~15 m, porque é a distância em que a jogadora ainda tem tempo de reagir. Um passo fisicamente realista seria inaudível a 8 m.
- **Atenuações compartilhadas** (`ATT_Passos`, `ATT_Presenca`, `ATT_Ambiente_Pontual`), nunca uma por som. Ajustar o alcance de todos os passos tem de ser mudar um asset.

**Espacialização** é de que direção o som vem. Sons 3D são posicionados em relação ao **ouvinte** (por padrão, a câmera do *view target*). O método mais simples distribui o som entre os canais (*panning*); métodos binaurais (HRTF) simulam a cabeça e as orelhas e funcionam bem com fones, inclusive para frente/trás e cima/baixo (⚠️ a disponibilidade depende de plugins e da plataforma). Para um jogo de terror jogado de fone, vale testar um espacializador binaural nos sons que importam (a Presença), e não em todos.

**Oclusão** é o abafamento por obstáculos. Ligada na atenuação, ela traça uma linha do ouvinte à fonte; se algo bloqueia, aplica um filtro passa-baixa e reduz o volume, com uma interpolação para não "piscar". É cara (um *trace* por som, periodicamente), e por isso vai **só** onde a informação importa: a Presença atrás de uma parede deve soar atrás de uma parede.

**Reverberação** é o som do espaço. Um ***Audio Volume*** (`AAudioVolume`) define a reverberação de uma região: o subsolo metálico com cauda longa e brilhante; o hall de concreto com cauda média; o vestiário pequeno e seco. O mesmo passo, em espaços diferentes, conta à jogadora onde ela está, sem nenhuma palavra. É level design com som (Cap. 50).

> 🌉 **Ponte:** atenuação e oclusão são um ***level of detail*** do áudio: quem está longe ou escondido recebe menos fidelidade e menos custo. É a mesma ideia de priorizar o tráfego de quem importa.
>
> 🧱 **Onde a ponte cai:** num sistema, degradar o distante é só economia. Aqui, o abafamento **é** a informação: uma Presença que soa abafada está atrás de algo, e a jogadora tira conclusões disso. Se a oclusão estiver errada, o jogo mente sobre o espaço.

---

## 52.4 Mixagem dinâmica

Um jogo tem dezenas de sons ao mesmo tempo, e a mixagem decide o que se ouve **agora**. Na Unreal, ela tem três camadas, de propósitos diferentes.

**1. *Sound Classes*: categorias com hierarquia.** Cada som pertence a uma classe, e as classes formam uma árvore. Ajustar uma classe ajusta todas as filhas. A árvore da Vigília:

```text
 SC_Master
  ├─ SC_Mundo           (ambiente, usina, portas, impactos)
  │   └─ SC_Ambiente    (os loops de fundo: zumbido, vento, gotejamento)
  ├─ SC_Jogadora        (passos, respiração, lanterna, armas)
  ├─ SC_Presenca        (respiração, passos, telegrafia — nunca abafada pela mixagem)
  ├─ SC_Voz             (falas)
  │   └─ SC_Voz_Radio   (Sônia)
  ├─ SC_Trilha          (MS_Trilha_Tensao)
  └─ SC_UI              (cliques, avisos; toca durante a pausa)
```

A árvore é também a do menu de opções (Cap. 55): "volume de música" é o volume de `SC_Trilha`; "volume de vozes", o de `SC_Voz`.

**2. *Sound Mixes*: ajustes por estado.** Um `USoundMix` é uma lista de ajustes de classes (volume, *pitch*, filtro passa-baixa) com tempos de entrada e saída. Ele é **empilhado** e **desempilhado** em tempo de execução (`UGameplayStatics::PushSoundMixModifier` / `PopSoundMixModifier`), e a engine compõe os ativos. Uma classe pode ter também ***passive mixes***: um mix que se aplica sozinho **enquanto** um som daquela classe toca. É o jeito de baixar o mundo quando Sônia fala (*ducking*) sem uma linha de código: `SC_Voz_Radio` com um mix passivo que abaixa `SC_Ambiente` em alguns decibéis. ⚠️ Confira o nome e a configuração dos *passive sound mix modifiers* na sua versão.

**3. *Submixes*: o roteamento de DSP.** Um ***Submix*** é um barramento de áudio por onde os sons passam e onde se aplicam efeitos (equalização, reverb, compressão). Sons ou classes escolhem para qual submix vão; os submixes formam uma árvore até o master. Mixes ajustam **volume**; submixes **processam** o sinal.

E há uma quarta camada, moderna: o plugin **Audio Modulation**, com *Control Buses* (valores nomeados, como "Intensidade do perigo") e *Bus Mixes* que os ajustam, ligados a volume, *pitch* e filtros de sons, classes e submixes. É mais flexível que os Sound Mixes e é o caminho que a Epic aponta para sistemas novos. ⚠️ Os nomes e as funções de Blueprint/C++ do plugin mudaram ao longo do UE5; confira na documentação da sua versão antes de adotá-lo.

### Os estados de mixagem da Vigília

| Estado | Quando | O que muda |
|---|---|---|
| **Leitura** | Modo `Reading` no topo da pilha (Cap. 16) | Mundo −6 dB com passa-baixa leve; Presença **intacta** |
| **Cinemática** | Modo `Cinematic` | Ambiente −4 dB; trilha a cargo da cena |
| **Menu** | Modo `UI` (pausa) | Mundo e trilha abafados; UI normal |
| **Morte** | Modo `Dead` | Tudo cai, exceto UI e um pulso cardíaco |
| **Silêncio** | Pedido por uma cena (o beat 6) | Ambiente **a zero** em 0,2 s; volta em 1,5 s |

Os quatro primeiros **derivam do modo de input**: o mix ativo é sempre o do modo que está no topo da pilha, recalculado quando a pilha muda. É o mesmo princípio do `ApplyTopMode` do Capítulo 16: um valor efetivo derivado do estado, em vez de mutações que podem dessincronizar. O silêncio é **pedido**: quem pede é dono do pedido e o devolve, com o padrão de *handle* que o Diretor já usa para as travas de roteiro (Cap. 42).

Repare na linha da leitura: a Presença **não** é abafada. Ler não pausa o jogo (Cap. 48), e a jogadora que lê precisa ouvir a ameaça chegando. O mix de leitura baixa o mundo para destacar a voz da fita e a ameaça, não para proteger a jogadora.

> 🌉 **Ponte:** os mixes empilhados são uma pilha de *feature flags* com escopo: cada estado liga ajustes enquanto está ativo, e a composição final é derivada do conjunto de flags ativas.
>
> 🧱 **Onde a ponte cai:** flags mudam instantaneamente. Aqui, toda transição tem **tempo**: um mix que entra em 0 s soa como bug; em 0,2 s, soa como susto; em 2 s, como mudança de humor. O tempo de entrada é uma decisão de direção, não um detalhe.

---

## 52.5 Som como informação

Num jogo sem HUD de ameaça, o som é o radar. Quatro informações que o som da Vigília carrega, e a regra que protege cada uma.

**1. Onde a Presença está.** Os passos e a respiração dela são 3D, com atenuação de ~15 m, oclusão ligada e uma assinatura única (nada no jogo soa parecido). **Regra:** o som da Presença nunca mente sobre a posição dela. O sinal de `BuildUp` do Capítulo 42 ("um ruído distante de passos metálicos **do lado** onde a Presença está") respeita isso: é distante, mas na direção certa.

**2. Que ela vai atacar.** O documento de combate (Cap. 21) exige telegrafia sonora ≥ 1,2 s antes de cada ataque, e 2 s no primeiro encontro. A task de telegrafia da árvore (Cap. 37) toca o som; o som precisa ser **inconfundível** e ter um ataque claro (início abrupto), para ser reconhecido mesmo com outros sons tocando.

**3. Onde a jogadora pisa.** O passo dela muda com a superfície (concreto, grade, água) e com a postura (agachada, andando, correndo). É *feedback* (o micro-loop do Capítulo 5: "o mundo respondeu") e é **aviso**: a grade metálica soa alto porque a IA a ouve alto.

**4. O estado do mundo.** A usina "respira" mais forte quando um setor é energizado; o zumbido das luminárias acompanha a luz; o rádio chia mais quando a Presença está atenta (seção 52.8).

### Paridade: o que ela ouve é o que a IA ouve

O ruído para a IA (Cap. 36) e o som do passo são duas saídas do mesmo acontecimento. Se forem calculados em lugares diferentes, divergem: a jogadora anda na grade, ouve um passo discreto, e a Presença a escuta de 20 m. Ou o contrário: o passo soa estrondoso e a IA não reage. As duas divergências quebram a confiança no sistema.

A regra da Vigília é de construção: **o mesmo handler, a mesma conta**. A função que reporta o ruído do passo (`UVGNoiseLibrary::ReportNoise`, com a intensidade × o multiplicador do material) é a mesma que toca o som, com o volume derivado da **mesma** intensidade final. A jogadora aprende, de ouvido, o quanto está sendo ouvida.

> 🌉 **Ponte:** é a regra de que a **telemetria e o comportamento** saem da mesma fonte: se o *dashboard* calcula a latência de um jeito e o *autoscaler* de outro, um dia eles discordam, e ninguém confia em nenhum.
>
> 🧱 **Onde a ponte cai:** a paridade aqui é **perceptiva**, não numérica. O volume não é linear com a intensidade de ruído, e a audição humana é logarítmica. A conta compartilhada garante a **ordem** (mais alto para a IA soa mais alto para a jogadora) e uma curva ajustada no ouvido, não uma igualdade.

---

## 52.6 Som como medo

O medo no som vem menos do que se ouve e mais do que se **espera** ouvir. Cinco princípios, todos aplicáveis em pequena escala:

1. **Antecipação vence revelação.** Um som não identificado (um arrastar ao longe, uma batida metálica) gera mais tensão que um rugido. O cérebro preenche a lacuna com o pior.
2. **Irregularidade.** A usina que "respira" a cada 30–60 s, em intervalo aleatório, é inquietante porque não dá para prever. O mesmo som em intervalo fixo vira metrônomo, e a jogadora para de ouvir.
3. **Frequências graves e sons do corpo.** Roncos graves, respiração, coração. O corpo reage a eles antes da consciência. A respiração de Helena acelerando quando a Presença caça é uma HUD de medo sem nenhum número.
4. **Trilha que não anuncia.** Música que sobe a cada perigo vira um alarme (a jogadora aprende que "música = monstro" e para de ter medo do silêncio). A trilha da Vigília é quase ambiente: camadas graves que crescem com a tensão do Diretor, sem melodia, e **nem sempre** junto com o perigo real.
5. **O susto sonoro (*stinger*) é caro.** Um som alto e súbito sempre funciona uma vez, e cada repetição vale menos. A Vigília tem orçamento de um *stinger* por setor, no máximo.

---

## 52.7 Silêncio como ferramenta

O beat 6 do Interlúdio é a lição inteira: **o zumbido para um segundo antes da cascata de luzes**. Por que isso funciona?

- O zumbido estava lá desde o hall. A jogadora parou de ouvi-lo, mas o cérebro continuava processando. Quando ele some, a **ausência** é percebida como um evento.
- O silêncio súbito concentra a atenção: tudo o que acontecer no segundo seguinte é ouvido com nitidez máxima, incluindo os próprios passos (que de repente parecem altos).
- Na ficção, é a usina "segurando a respiração". O mundo reage à Presença antes de ela aparecer.

Três regras para o silêncio funcionar:

1. **Ele precisa de um som constante antes.** Silêncio num lugar que já era silencioso não é notado.
2. **Silêncio não é zero digital.** Áudio cortado a zero absoluto soa como bug (ou como o jogo travou). O silêncio da Vigília derruba o **ambiente** e mantém o "tom de sala" baixíssimo e os sons da jogadora (passos, respiração).
3. **Ele é curto e raro.** Um segundo, uma vez por setor. Silêncio frequente vira estilo, e estilo não assusta.

Na implementação, o silêncio é um **estado de mixagem pedido pela cena** (seção 52.4): a trilha de evento da cena do susto (Cap. 49) pede o silêncio no frame certo e o devolve no fim. E como a cena do Capítulo 49 tem cancelamento e restauração, o silêncio tem de ser devolvido também quando a cena é pulada ou cancelada. O padrão de *handle* resolve: quem pediu é dono, e o `Finish` único da cena devolve o que ela pegou.

---

## 52.8 O rádio de Sônia

O rádio é o único canal humano da Vigília, e soa como rádio por três motivos: **realismo** (é um rádio portátil de 2024 conversando com uma central), **separação** (a voz de Sônia está no ouvido de Helena, não no espaço) e **informação** (o canal pode falhar, e a falha conta algo).

O filtro de rádio tem quatro estágios, todos dentro de `MS_Radio_Voz`:

```text
 MS_Radio_Voz (MetaSound Source, one-shot)

  entrada Voz (wave) ──► Wave Player ──► passa-alta ~300 Hz ──► passa-baixa ~3,4 kHz
                                                                      │
                                                                      ▼
                                            saturação leve (waveshaper/distorção suave)
                                                                      │
  entrada Interferencia (0–1) ──► interp ──┬──► ganho do ruído ──► ruído rosa/branco ──┐
                                           └──► "quedas" aleatórias de volume (0–40%) ─┤
                                                                                       ▼
                         clique de squelch (início) ──► MIX ◄── clique + cauda de chiado (fim)
                                                         │
                                                         ▼  saída (estéreo, 2D, SC_Voz_Radio)
```

- A **banda de ~300 Hz a ~3,4 kHz** é a faixa clássica da voz em telefonia; cortar graves e agudos é 80% do "som de rádio".
- A **saturação leve** imita o alto-falante pequeno e o circuito do rádio.
- Os **cliques de *squelch*** no início e no fim marcam o canal: a jogadora reconhece "Sônia vai falar" antes da primeira palavra.
- A **interferência** é o estágio que conta história: ruído e quedas de volume proporcionais a um parâmetro que o jogo controla.

A interferência é ligada à **ameaça**, não à distância: o `UVGThreatSubsystem` (Cap. 36) diz se a Presença está calma, inquieta ou caçando, e o Diretor (Cap. 42) diz se está em `BuildUp`. Quanto mais a Presença está atenta a Helena, mais o rádio chia. É diegético (na ficção, a Presença interfere em equipamentos elétricos, como as luzes) e é informação (Sônia falando com chiado forte é um aviso). E fecha uma fala do Interlúdio que até agora era só texto: *"O seu sinal sumiu por uns segundos."*

> ⚠️ **Um tropo conhecido.** O rádio que chia na presença de monstros é uma marca de *Silent Hill* (Konami, 1999) **[FATO PÚBLICO, observável jogando]**. A Vigília usa a ideia com uma diferença deliberada: o chiado não aparece sozinho; ele só altera a voz de Sônia quando ela fala. O rádio não vira um detector contínuo, o que tornaria a Presença previsível.

**Onde o filtro mora no código.** A voz de cada fala continua sendo o wave do nó do diálogo (Cap. 44); o que muda é **como** o falante soa. O `UVGSpeakerData` ganha uma "cadeia de voz" opcional (`VoiceChain`): para Sônia, `MS_Radio_Voz`. Ao começar uma fala, o subsistema de diálogo toca a cadeia e passa o wave como parâmetro. A duração da fala continua vindo do wave (a regra `VGDialogueRules::LineDuration` não muda), e falas de quem não tem cadeia tocam o wave direto, como antes.

---

## Estudos de caso

### Amnesia: A Machine for Pigs — a máquina que se ouve

**[FATO PÚBLICO]** *Amnesia: A Machine for Pigs* (The Chinese Room, publicado pela Frictional Games, 2013) tem trilha composta por Jessica Curry, da The Chinese Room. **[FATO PÚBLICO, observável jogando]** O protagonista carrega uma lanterna elétrica que não precisa de combustível e que **pisca quando há inimigos por perto**. A máquina sob Londres é ouvida muito antes de ser compreendida: roncos, pistões, vapor, a construção inteira soando como algo vivo.

**[INFERÊNCIA]** O som faz duas coisas que a narrativa ambiental (Cap. 48) precisa: **antecipa** a revelação (a máquina é ouvida antes de ser vista) e **personifica** o espaço (o prédio respira, geme, trabalha). A trilha se mistura ao som da máquina, e a fronteira entre música e ambiente fica deliberadamente borrada: a jogadora nunca tem certeza se ouve a trilha ou a máquina. E a lanterna é um exemplo de canal com um significado só: como não há combustível, piscar só pode significar perigo.

**Lição para a Vigília:** a usina que "respira" é a mesma ideia, e merece ser uma MetaSound viva (`MS_Usina_Respira`), irregular e mais intensa a cada setor energizado: a usina acordando. E o caso da lanterna confirma, pelo contraste, a decisão do Capítulo 51: na Vigília, a lanterna já significa "bateria", então o aviso de perigo vai para as luzes do mundo e para o rádio, e cada canal mantém um significado só.

### Outlast — o corpo como HUD

**[FATO PÚBLICO, observável jogando]** Em *Outlast* (Red Barrels, 2013), a respiração e os sons do protagonista se intensificam quando ele é perseguido ou se esconde, e a trilha reage quando ele é visto, com ataques musicais súbitos que marcam o início de uma perseguição.

**[INFERÊNCIA]** Sem barra de vida nem indicador de ameaça na tela, o **corpo** do protagonista é a interface: a respiração diz "você está em perigo" e "você está escondido". A trilha que dispara ao ser visto é uma confirmação de estado ("fui descoberto"), e por isso funciona como informação, não só como susto. O custo é o da seção 52.6: a jogadora aprende que a música marca o perigo.

**Lição para a Vigília:** a respiração de Helena é o indicador de ameaça (uma camada em `SC_Jogadora` que acompanha o `UVGThreatSubsystem`), e a vinheta de dano do Capítulo 55 complementa. A trilha da Vigília **não** confirma a descoberta de forma confiável, de propósito: a confirmação vem do som da Presença, que é honesto sobre a posição.

### Alan Wake — a voz do inimigo como telegrafia

**[FATO PÚBLICO, observável jogando]** Em *Alan Wake* (Remedy, 2010), os Taken falam frases fragmentadas, com vozes distorcidas, enquanto se aproximam. O jogo usa sinais de câmera e de som para avisar ataques iminentes, e uma esquiva no momento certo é mostrada em câmera lenta.

**[INFERÊNCIA]** As falas dos Taken são **telegrafia e atmosfera** ao mesmo tempo: anunciam a aproximação e a direção (sons 3D) e reforçam a estranheza (frases banais em vozes erradas). Os avisos de ataque compensam o ponto cego da câmera e transformam a esquiva numa resposta a um sinal, e não num palpite.

**Lição para a Vigília:** a telegrafia de 1,2 s do documento de combate deve ser sonora **e** espacial: a jogadora tem de saber **de onde** vem o ataque, não só que ele vem. Por isso a oclusão e a espacialização ficam ligadas na Presença e em pouca coisa mais.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Cadeia do som | *Pipeline* de *stream* com roteamento por categoria | Tempo real duro: um bloco atrasado é um estalo audível |
| MetaSound com parâmetros | Serviço configurado em *runtime* | Roda em outro *thread*; parâmetros chegam no próximo bloco |
| Atenuação e oclusão | LOD, priorização de tráfego | O abafamento **é** a informação |
| Mixes por estado | *Feature flags* com escopo, estado derivado | Toda transição tem tempo, e o tempo é direção |
| Paridade som × ruído | Telemetria e comportamento da mesma fonte | A paridade é perceptiva, não numérica |
| Filtro na cadeia do falante | *Decorator* sobre a saída | — (a analogia vale) |

---

## Unreal Engine: o que existe

- **Audio Mixer**: o motor de áudio do UE5, com *thread* próprio.
- **Fontes**: `USoundWave`, `USoundCue` e **MetaSound Source** (plugin MetaSounds, habilitado por padrão em projetos UE5 recentes; ⚠️ confira).
- **Instâncias**: `UAudioComponent` (com `Play`, `Stop`, `FadeIn`/`FadeOut`, `SetVolumeMultiplier` e os `Set*Parameter`) e funções de `UGameplayStatics`: `PlaySoundAtLocation`, `PlaySound2D`, `SpawnSoundAtLocation`, `SpawnSound2D`, `SpawnSoundAttached`, `CreateSound2D` (cria sem tocar, para configurar antes do `Play`).
- **Espaço**: `USoundAttenuation` (atenuação, espacialização, oclusão, foco), `USoundConcurrency`, `AAudioVolume` (reverb e efeitos por região), plugins de espacialização.
- **Mixagem**: `USoundClass`, `USoundMix` (com `PushSoundMixModifier`/`PopSoundMixModifier`/`SetSoundMixClassOverride`), `USoundSubmix` com *Submix Effect Presets*, e o plugin **Audio Modulation** (*Control Buses*, *Bus Mixes*).
- **Depuração**: comandos `stat` de áudio e as ferramentas de visualização de áudio do editor (⚠️ os comandos e o painel de *Audio Insights* variam entre versões; confira os disponíveis na sua com `stat` e a lista de CVars `au.`).

O que a engine **não** oferece: uma noção de "estado de mixagem do jogo" ligada aos seus modos de input, ao seu Diretor e às suas cenas, nem a paridade entre som e ruído de IA. A cola é sua.

---

## Abordagens: como mudar a mixagem por estado

| Critério | A. Volume na mão em cada componente | **B. Sound Mixes empilhados, derivados do estado** | C. Audio Modulation (*Control Buses*) |
|---|---|---|---|
| **Complexidade** | Baixa no começo, explode | **Baixa** | Média |
| **Quem ajusta** | Programador | **Designer de som, no asset do mix** | Designer de som |
| **Transições com tempo** | Código | **No asset (fade in/out)** | No asset |
| **Estados simultâneos** | Conflitos entre quem escreve | **A engine compõe** | A engine compõe |
| **Flexibilidade** (ligar a filtros, a submixes, a parâmetros de MetaSound) | Total, à mão | Volume, *pitch*, passa-baixa por classe | **A maior** |
| **Estabilidade da API entre versões** | Alta | **Alta** | Menor (⚠️) |
| **Adequação à Vigília** | Não | **Sim** | Quando os mixes não bastarem |

**Decisão: B.** Cinco estados, uma árvore de classes e mixes com *fades*. Quando a Vigília precisar de algo que os mixes não fazem (um único "nível de perigo" contínuo mexendo em dez parâmetros), o caminho é C, e a migração é localizada: a API do subsistema (estados e pedidos) não muda.

---

## Implementação

### 1. Módulos e regras puras

`Build.cs`: acrescente `"AudioExtensions"` (a interface de parâmetros usada por `SetFloatParameter`/`SetObjectParameter` no `UAudioComponent`; ⚠️ se a sua versão linka sem ele, a dependência é inofensiva). O `"DeveloperSettings"` já entrou no Capítulo 46.

```cpp
// Source/Vigilia/Core/VGAudioRules.h
#pragma once

#include "CoreMinimal.h"

enum class EVGDirectorPhase : uint8;
enum class EVGThreatLevel : uint8;

namespace VGAudioRules
{
    /** Alvo do parâmetro Tensao da trilha (0–1). A MetaSound suaviza. */
    float MusicTension(EVGDirectorPhase Phase, float DirectorTension);

    /** Interferência do rádio (0–1): a Presença atenta "suja" o canal. */
    float RadioInterference(EVGThreatLevel Threat, EVGDirectorPhase Phase);

    /** Volume do passo a partir da MESMA intensidade que vira ruído para a IA (paridade). */
    float FootstepVolume(float FinalLoudness);
}
```

```cpp
// Source/Vigilia/Core/VGAudioRules.cpp
#include "Core/VGAudioRules.h"

#include "AI/VGDirectorSubsystem.h"
#include "AI/VGThreatSubsystem.h"

float VGAudioRules::MusicTension(EVGDirectorPhase Phase, float DirectorTension)
{
    const float T = FMath::Clamp(DirectorTension, 0.0f, 1.0f);
    switch (Phase)
    {
    case EVGDirectorPhase::Relax:    return 0.15f * T;              // quase só o drone da usina
    case EVGDirectorPhase::BuildUp:  return 0.3f + 0.4f * T;        // a camada grave entra
    case EVGDirectorPhase::Peak:     return 0.8f + 0.2f * T;
    case EVGDirectorPhase::Recovery: return 0.2f;                    // desce devagar (a MetaSound interpola)
    }
    return 0.0f;
}

float VGAudioRules::RadioInterference(EVGThreatLevel Threat, EVGDirectorPhase Phase)
{
    float Base = 0.05f; // um rádio de verdade nunca é limpo
    switch (Threat)
    {
    case EVGThreatLevel::Calm:    break;
    case EVGThreatLevel::Uneasy:  Base = 0.35f; break;
    case EVGThreatLevel::Hunting: Base = 0.7f;  break;
    }
    return FMath::Min(1.0f, Base + (Phase == EVGDirectorPhase::BuildUp ? 0.15f : 0.0f));
}

float VGAudioRules::FootstepVolume(float FinalLoudness)
{
    // A audição é logarítmica: a curva preserva a ORDEM (mais ruído = mais alto), não a proporção.
    return FMath::Clamp(0.35f + 0.45f * FMath::Sqrt(FMath::Max(FinalLoudness, 0.0f)), 0.3f, 1.2f);
}
```

### 2. As configurações de áudio

```cpp
// Source/Vigilia/Core/VGAudioSettings.h
#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "VGAudioSettings.generated.h"

class USoundBase;
class USoundMix;

/** Project Settings → Vigilia Audio. Os assets de mixagem e a trilha, sem referência em nível nenhum. */
UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Vigilia Audio"))
class VIGILIA_API UVGAudioSettings : public UDeveloperSettings
{
    GENERATED_BODY()

public:
    UPROPERTY(Config, EditAnywhere, Category = "Mix")
    TSoftObjectPtr<USoundMix> ReadingMix;

    UPROPERTY(Config, EditAnywhere, Category = "Mix")
    TSoftObjectPtr<USoundMix> CinematicMix;

    UPROPERTY(Config, EditAnywhere, Category = "Mix")
    TSoftObjectPtr<USoundMix> MenuMix;

    UPROPERTY(Config, EditAnywhere, Category = "Mix")
    TSoftObjectPtr<USoundMix> DeadMix;

    UPROPERTY(Config, EditAnywhere, Category = "Mix")
    TSoftObjectPtr<USoundMix> SilenceMix;

    /** MS_Trilha_Tensao: entrada float "Tensao". */
    UPROPERTY(Config, EditAnywhere, Category = "Music")
    TSoftObjectPtr<USoundBase> TensionScore;
};
```

### 3. O subsistema de mixagem

```cpp
// Source/Vigilia/Core/VGAudioMixSubsystem.h
#pragma once

#include "CoreMinimal.h"
#include "Player/VGInputModes.h"
#include "Subsystems/WorldSubsystem.h"
#include "VGAudioMixSubsystem.generated.h"

class UAudioComponent;
class USoundMix;

/**
 * O estado de mixagem do jogo: o mix do modo de input no topo (derivado) + pedidos de silêncio (com dono).
 * Também alimenta a trilha (Tensao) e a interferência do rádio a 4 Hz, a partir do Diretor e da ameaça.
 * Relógio: o timer do mundo (para com a pausa; a MetaSound suaviza os valores).
 */
UCLASS()
class VIGILIA_API UVGAudioMixSubsystem : public UWorldSubsystem
{
    GENERATED_BODY()

public:
    virtual void OnWorldBeginPlay(UWorld& InWorld) override;
    virtual void Deinitialize() override;

    /** Silêncio pedido por uma cena. Devolva o handle no fim, cancelamento ou pulo. */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Audio")
    int32 PushSilence(FName Reason);

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Audio")
    void PopSilence(int32 Handle);

private:
    UFUNCTION()
    void HandleInputModeChanged(EVGInputMode OldMode, EVGInputMode NewMode);

    void Update();               // 4 Hz: liga-se ao controller, atualiza trilha e rádio
    void SetModeMix(EVGInputMode Mode);
    USoundMix* MixForMode(EVGInputMode Mode) const;

    UPROPERTY(Transient)
    TObjectPtr<USoundMix> ActiveModeMix;

    UPROPERTY(Transient)
    TObjectPtr<UAudioComponent> Score;

    TMap<int32, FName> SilenceRequests;
    int32 NextHandle = 1;
    bool bBoundToController = false;
    FTimerHandle UpdateTimer;
};
```

```cpp
// Source/Vigilia/Core/VGAudioMixSubsystem.cpp
#include "Core/VGAudioMixSubsystem.h"

#include "AI/VGDirectorSubsystem.h"
#include "AI/VGThreatSubsystem.h"
#include "Core/VGAudioRules.h"
#include "Core/VGAudioSettings.h"
#include "Components/AudioComponent.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "Narrative/VGDialogueSubsystem.h"
#include "Player/VGPlayerController.h"
#include "Sound/SoundMix.h"
#include "TimerManager.h"

void UVGAudioMixSubsystem::OnWorldBeginPlay(UWorld& InWorld)
{
    Super::OnWorldBeginPlay(InWorld);
    const UVGAudioSettings* Settings = GetDefault<UVGAudioSettings>();
    if (USoundBase* ScoreSound = Settings->TensionScore.LoadSynchronous())
    {
        Score = UGameplayStatics::CreateSound2D(this, ScoreSound, 1.0f, 1.0f, 0.0f, nullptr,
                                                /*bPersistAcrossLevelTransition=*/false, /*bAutoDestroy=*/false);
        if (Score)
        {
            Score->SetFloatParameter(TEXT("Tensao"), 0.0f);
            Score->Play();
        }
    }
    InWorld.GetTimerManager().SetTimer(UpdateTimer, this, &UVGAudioMixSubsystem::Update, 0.25f, /*bLoop=*/true);
}

void UVGAudioMixSubsystem::Deinitialize()
{
    if (ActiveModeMix)
    {
        UGameplayStatics::PopSoundMixModifier(this, ActiveModeMix);
    }
    if (!SilenceRequests.IsEmpty())
    {
        UGameplayStatics::PopSoundMixModifier(this, GetDefault<UVGAudioSettings>()->SilenceMix.Get());
    }
    Super::Deinitialize();
}

void UVGAudioMixSubsystem::Update()
{
    UWorld* World = GetWorld();
    if (!bBoundToController)
    {
        // Ligação preguiçosa: no OnWorldBeginPlay, o controller pode ainda não existir.
        if (AVGPlayerController* PC = Cast<AVGPlayerController>(World->GetFirstPlayerController()))
        {
            PC->OnInputModeChanged.AddDynamic(this, &UVGAudioMixSubsystem::HandleInputModeChanged);
            SetModeMix(PC->GetCurrentInputMode());
            bBoundToController = true;
        }
    }

    const UVGDirectorSubsystem* Director = World->GetSubsystem<UVGDirectorSubsystem>();
    const UVGThreatSubsystem* Threat = World->GetSubsystem<UVGThreatSubsystem>();
    if (!Director || !Threat)
    {
        return;
    }
    if (Score)
    {
        Score->SetFloatParameter(TEXT("Tensao"), VGAudioRules::MusicTension(Director->GetPhase(), Director->GetTension()));
    }
    if (UVGDialogueSubsystem* Dialogue = World->GetSubsystem<UVGDialogueSubsystem>())
    {
        Dialogue->SetVoiceFloatParameter(TEXT("Interferencia"),
            VGAudioRules::RadioInterference(Threat->GetThreatLevel(), Director->GetPhase()));
    }
}

void UVGAudioMixSubsystem::HandleInputModeChanged(EVGInputMode OldMode, EVGInputMode NewMode)
{
    SetModeMix(NewMode);
}

void UVGAudioMixSubsystem::SetModeMix(EVGInputMode Mode)
{
    USoundMix* NewMix = MixForMode(Mode);
    if (NewMix == ActiveModeMix)
    {
        return;
    }
    if (ActiveModeMix)
    {
        UGameplayStatics::PopSoundMixModifier(this, ActiveModeMix); // o fade-out é do asset
    }
    ActiveModeMix = NewMix;
    if (ActiveModeMix)
    {
        UGameplayStatics::PushSoundMixModifier(this, ActiveModeMix);
    }
}

USoundMix* UVGAudioMixSubsystem::MixForMode(EVGInputMode Mode) const
{
    const UVGAudioSettings* Settings = GetDefault<UVGAudioSettings>();
    switch (Mode)
    {
    case EVGInputMode::Reading:   return Settings->ReadingMix.LoadSynchronous();
    case EVGInputMode::Cinematic: return Settings->CinematicMix.LoadSynchronous();
    case EVGInputMode::UI:        return Settings->MenuMix.LoadSynchronous();
    case EVGInputMode::Dead:      return Settings->DeadMix.LoadSynchronous();
    default:                      return nullptr; // Exploration: a mixagem base
    }
}

int32 UVGAudioMixSubsystem::PushSilence(FName Reason)
{
    if (SilenceRequests.IsEmpty())
    {
        UGameplayStatics::PushSoundMixModifier(this, GetDefault<UVGAudioSettings>()->SilenceMix.LoadSynchronous());
    }
    const int32 Handle = NextHandle++;
    SilenceRequests.Add(Handle, Reason);
    return Handle;
}

void UVGAudioMixSubsystem::PopSilence(int32 Handle)
{
    if (SilenceRequests.Remove(Handle) > 0 && SilenceRequests.IsEmpty())
    {
        UGameplayStatics::PopSoundMixModifier(this, GetDefault<UVGAudioSettings>()->SilenceMix.LoadSynchronous());
    }
}
```

Os `#include` de `AI/VGDirectorSubsystem.h`, `AI/VGThreatSubsystem.h` e `Narrative/VGDialogueSubsystem.h` seguem as pastas dos Capítulos 36, 42 e 44; ajuste se os seus arquivos moram em outro lugar.

### 4. 🔁 A cadeia de voz no diálogo

**Antes** (Cap. 44), `StartLine` tocava o wave do nó com `SpawnSound2D`, e o "rádio" era só um ícone na legenda. **Agora**, o falante pode ter uma cadeia:

```cpp
// VGSpeakerData.h (adição)
    /**
     * Opcional: uma MetaSound que recebe a fala na entrada "Voz" (wave) e a processa (ex.: MS_Radio_Voz).
     * Vazio: a fala toca direto. A duração da fala continua vindo do wave do nó.
     */
    UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Speaker")
    TObjectPtr<USoundBase> VoiceChain;
```

```cpp
// VGDialogueSubsystem.h (adição, public)
    /** Ajusta um parâmetro da voz tocando agora, se houver (ex.: Interferencia do rádio). */
    void SetVoiceFloatParameter(FName Name, float Value);

// VGDialogueSubsystem.cpp
void UVGDialogueSubsystem::StartLine(float Now)
{
    const FVGDialogueNode& Node = *CurrentNode();
    if (Node.Voice)
    {
        USoundBase* Chain = Node.Speaker ? Node.Speaker->VoiceChain.Get() : nullptr;
        if (Chain)
        {
            // CreateSound2D não toca: configura primeiro, toca depois (o parâmetro chega antes do 1º bloco).
            UAudioComponent* Component = UGameplayStatics::CreateSound2D(this, Chain);
            if (Component)
            {
                Component->SetObjectParameter(TEXT("Voz"), Node.Voice);
                Component->Play();
            }
            Voice = Component;
        }
        else
        {
            Voice = UGameplayStatics::SpawnSound2D(this, Node.Voice); // 2D: o rádio está no ouvido de Helena
        }
    }
    // ... o resto de StartLine (legenda, duração, OnLineStarted) não muda
}

void UVGDialogueSubsystem::SetVoiceFloatParameter(FName Name, float Value)
{
    if (UAudioComponent* Component = Voice.Get())
    {
        Component->SetFloatParameter(Name, Value);
    }
}
```

`CreateSound2D` cria o componente com `bAutoDestroy` verdadeiro por padrão: ele se destrói ao terminar, e o `TWeakObjectPtr` `Voice` (Cap. 44) simplesmente fica inválido. ⚠️ Confira a assinatura de `SetObjectParameter` (o nome da entrada deve bater exatamente com a do grafo da MetaSound) e se o seu wave é `USoundWave`, que é o tipo que uma entrada *Wave Asset* aceita.

### 5. 🔁 Passos: o som e o ruído na mesma conta

O Capítulo 36 sugeriu passar o material físico no evento de passo, em vez do tipo de superfície. Se você fez a mudança, use-a; senão, faça agora (`FVGFootstepSignature` com `const UPhysicalMaterial*`). O `UVGPhysicalMaterial` ganha o som:

```cpp
// VGPhysicalMaterial.h (adição)
    /** O passo nesta superfície (ex.: MS_Passo_Grade). Volume vem da intensidade final (VGAudioRules). */
    UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Vigilia|Audio")
    TObjectPtr<USoundBase> FootstepSound;
```

E o handler do personagem que já reportava o ruído (Cap. 36) passa a tocar o som **com o mesmo número**:

```cpp
// VGCharacter.cpp (🔁 o handler de OnFootstep)
void AVGCharacter::HandleFootstep(FVector Location, const UPhysicalMaterial* Material, float Loudness)
{
    const UVGPhysicalMaterial* VGMaterial = Cast<UVGPhysicalMaterial>(Material);
    const float FinalLoudness = Loudness * (VGMaterial ? VGMaterial->NoiseMultiplier : 1.0f);

    // 1. O que a IA ouve (Cap. 36).
    UVGNoiseLibrary::ReportNoise(this, Location, FinalLoudness, this,
        FMath::Lerp(600.0f, 2500.0f, FMath::Clamp(FinalLoudness, 0.0f, 1.0f)), TEXT("Footstep"));

    // 2. O que ELA ouve: a mesma intensidade final, outra curva (paridade perceptiva).
    if (VGMaterial && VGMaterial->FootstepSound)
    {
        UGameplayStatics::PlaySoundAtLocation(this, VGMaterial->FootstepSound, Location,
                                              VGAudioRules::FootstepVolume(FinalLoudness));
    }
}
```

A atenuação e a concorrência ficam nos assets dos sons de passo (`ATT_Passos`, uma concorrência de 4 instâncias), e não no código.

### 6. O teste

```cpp
// Source/Vigilia/Tests/VGAudioRulesTest.cpp
#include "AI/VGDirectorSubsystem.h"
#include "AI/VGThreatSubsystem.h"
#include "Core/VGAudioRules.h"
#include "Misc/AutomationTest.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGAudioRulesTest, "Vigilia.Audio.Rules",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGAudioRulesTest::RunTest(const FString& Parameters)
{
    using P = EVGDirectorPhase;
    using T = EVGThreatLevel;

    TestTrue(TEXT("Trilha: pico acima do build-up"),
        VGAudioRules::MusicTension(P::Peak, 0.0f) > VGAudioRules::MusicTension(P::BuildUp, 1.0f) - 0.01f);
    TestTrue(TEXT("Trilha: relax quase sem trilha"), VGAudioRules::MusicTension(P::Relax, 1.0f) <= 0.15f);

    TestTrue(TEXT("Rádio nunca é limpo"), VGAudioRules::RadioInterference(T::Calm, P::Relax) > 0.0f);
    TestTrue(TEXT("Rádio: caçando chia mais que inquieta"),
        VGAudioRules::RadioInterference(T::Hunting, P::Relax) > VGAudioRules::RadioInterference(T::Uneasy, P::Relax));
    TestTrue(TEXT("Rádio: limitado a 1"), VGAudioRules::RadioInterference(T::Hunting, P::BuildUp) <= 1.0f);

    // Paridade: mais ruído para a IA nunca soa MAIS BAIXO para a jogadora.
    float Previous = 0.0f;
    for (float L = 0.0f; L <= 2.4f; L += 0.2f)
    {
        const float Volume = VGAudioRules::FootstepVolume(L);
        TestTrue(FString::Printf(TEXT("Volume monotônico em %.1f"), L), Volume >= Previous);
        Previous = Volume;
    }
    return true;
}

#endif
```

O laço é o teste que importa: ele fixa a **paridade** como propriedade. Se alguém trocar a curva por uma que, em algum trecho, deixa um passo mais ruidoso soar mais baixo, o teste falha.

### Explicação das decisões

- **O mix do modo de input é derivado**, não empilhado por cada sistema. O subsistema troca um mix pelo outro quando o topo da pilha muda; nenhum widget e nenhum leitor de documento mexem em áudio. É a mesma regra do Capítulo 16 para a UI.
- **O silêncio é pedido com handle**, como as travas do Diretor (Cap. 42): vários pedidos simultâneos não se atrapalham, e o mix sai quando o último é devolvido.
- **Ligação preguiçosa ao controller** no primeiro `Update`: no `OnWorldBeginPlay`, a ordem de criação do controller não é garantida (a mesma família de problemas da ordem de `BeginPlay` entre atores).
- **4 Hz de atualização e suavização na MetaSound.** A tensão do Diretor muda devagar; mandar o alvo quatro vezes por segundo basta, e a interpolação no grafo soa melhor que qualquer interpolação no *game thread*.
- **A interferência vem da ameaça, não da distância**, porque a ameaça já existe (`UVGThreatSubsystem`) e mede o que importa para a história (a Presença atenta a Helena), sem uma consulta espacial nova.
- **O subsistema de diálogo continua dono da voz**: o áudio só pede `SetVoiceFloatParameter`. Quem toca a voz é quem sabe quando ela começa e termina.
- **Cadeia de voz no falante, não no nó**: Sônia soa como rádio em todas as falas, sem que ninguém precise lembrar de configurar cada uma.
- **Paridade no mesmo handler**: ruído e volume saem da mesma `FinalLoudness`; o teste garante a ordem.
- **`LoadSynchronous` nos mixes**: são poucos assets, pequenos, carregados uma vez. ⚠️ `// Simplificação:` num jogo com muitos estados, carregue-os na inicialização do subsistema (Cap. 60 trata carregamento assíncrono).

---

## Projeto Vigília — o som do setor 1

### O mapa sonoro

O documento de nível (Cap. 50) ganha a linha de som de cada espaço com o que este capítulo construiu:

| Espaço | Ambiente | Reverb (`AAudioVolume`) | Sons-guia e eventos |
|---|---|---|---|
| Hall | Vento nas frestas; zumbido da emergência | Concreto, cauda média | O rádio (Sônia) começa aqui |
| Corredor | Zumbido das luminárias (presas a elas: apagam junto) | Concreto longo | **O silêncio do beat 6** |
| Vestiário | Gotejar distante; metal dos armários | Pequeno, seco | Armário aberto range (o da chave) |
| Sala do engenheiro | O rádio esquecido na mesa, chiando baixo | Pequeno, abafado (papel, madeira) | O chiado guia até a mesa (vinheta do Cap. 48) |
| Subsolo | Gotejamento; o ronco da usina mais perto | Metálico, cauda longa e brilhante | Os próprios passos na grade (alto: é aviso) |
| Sala de controle | Painéis acordando (relés, ventoinhas) | Médio, vidro | A turbina 3 ouvida pela janela, grave |

E a usina que "respira" troca o `AVGAlarm` filho por `MS_Usina_Respira` com intervalo irregular no próprio grafo; a entrada `Intensidade` sobe quando `S1.BreakersRestored` aparece (um Blueprint pequeno que lê o fato, como as luminárias do Cap. 51).

### Os assets de mixagem

- Árvore de classes da seção 52.4; `SC_Voz_Radio` com um *passive mix* que abaixa `SC_Ambiente` em 4 dB enquanto Sônia fala.
- `SMix_Leitura`, `SMix_Cinematica`, `SMix_Menu`, `SMix_Morte`, `SMix_Silencio`, apontados em *Project Settings → Vigilia Audio*. O de silêncio leva `SC_Ambiente` a zero em 0,2 s e volta em 1,5 s.
- `MS_Trilha_Tensao` com três camadas (drone, pulso grave, textura aguda), entrada `Tensao`.

### O rádio de Sônia

`DA_Falante_Sonia.VoiceChain = MS_Radio_Voz`. Teste em `L_Lab`: uma fala com a Presença calma e outra com ela caçando. A segunda deve soar suja, com quedas. A fala pós-susto ("O seu sinal sumiu por uns segundos") passa a ser **verdade audível**: no susto, o Diretor está em `BuildUp` e o rádio chia mais.

### O silêncio do susto

🔁 A cena do susto (`BP_Cena_Susto`, Cap. 49) pede `PushSilence(TEXT("S1.Susto"))` na trilha de evento, 1 s antes do primeiro `SetPattern` da cascata, e guarda o handle. O `Finish` único da cena devolve com `PopSilence`, em todos os caminhos (fim normal, pulo, cancelamento por morte). O Capítulo 49 já garante que `Finish` roda uma vez; o silêncio herda essa garantia.

### A lanterna e a Presença

- `OnOverchargeCharging(true)` toca um zumbido crescente (um `UAudioComponent` no `BP_VGJogadora`), parado em `false`; o pulso tem um estalo seco e um "*thump*" grave (o ruído para a IA já sai do componente, Cap. 51).
- A Presença: `MS_Presenca_Respira` em loop, `ATT_Presenca` (~15 m, oclusão ligada, espacialização binaural se disponível), passos por *anim notify* (Cap. 53) e a telegrafia da task do Capítulo 37.
- A respiração de Helena: uma camada em `SC_Jogadora` cuja intensidade acompanha o `UVGThreatSubsystem` (um Blueprint lendo `GetThreatLevel`).

---

## Decisões arquiteturais

1. **Classes por categoria, mixes por estado, submixes por processamento**; Audio Modulation só quando os mixes não bastarem.
2. **O mix do modo de input é derivado do topo da pilha**; o silêncio é um pedido com handle; nenhum widget mexe em áudio.
3. **A Presença nunca é abafada pela mixagem e nunca mente sobre a posição**; oclusão e espacialização caras só nela.
4. **Paridade som × ruído no mesmo handler**, com a ordem garantida por teste.
5. **Filtro de rádio como cadeia do falante** (`VoiceChain` + `MS_Radio_Voz`); a interferência vem da ameaça e do Diretor.
6. **Trilha quase ambiente**, guiada pela tensão do Diretor, sem confirmar o perigo de forma confiável; um *stinger* por setor, no máximo.
7. **Silêncio curto, raro, depois de um som constante, e nunca zero digital.**

---

## Armadilhas

- **Atenuação "realista"**: a Presença inaudível a 8 m, quando a jogadora precisava ouvi-la a 15.
- **Oclusão em todos os sons**: custo alto e ruído de informação.
- **Som que mente sobre a posição** da ameaça, mesmo por boa intenção ("é só para assustar").
- **Ruído e som calculados em lugares diferentes**: a IA ouve uma coisa e a jogadora, outra.
- **Cada sistema empilhando o seu mix** sem dono, e o mix que nunca sai.
- **Silêncio que não é devolvido** quando a cena é pulada ou cancelada.
- **Zero digital** no lugar de silêncio.
- **Trilha que sobe a cada perigo**, ensinando "música = monstro".
- **Parâmetros de MetaSound mandados a cada frame**, interpolados em C++.
- **Nome de entrada da MetaSound digitado diferente** no código (`"voz"` × `"Voz"`): nada acontece, e nada avisa.
- **Sons sem concorrência**: vinte passos simultâneos de cinco vigias.

---

## Exercício

**Parte 1 — classes, mixes e configurações (1,5 h).** Crie a árvore de *Sound Classes*, os cinco mixes e `UVGAudioSettings`. Ponha o *passive mix* em `SC_Voz_Radio`. Teste ouvindo: abra um documento (o mundo abafa, a Presença não), entre numa cinemática, pause.

**Parte 2 — regras, subsistema e teste (2 h).** Implemente `VGAudioRules`, o teste, `UVGAudioMixSubsystem` e `MS_Trilha_Tensao` (três camadas e a entrada `Tensao`). Force cada fase com uma trava do Diretor (`PushScriptLock`, Cap. 42, chamada de um cheat seu) e ouça a trilha mudar.

**Parte 3 — o rádio (1,5 h).** Construa `MS_Radio_Voz` com os quatro estágios, faça o 🔁 do `UVGSpeakerData` e do `StartLine`, e configure Sônia. Compare a mesma fala com a ameaça em `Calm` e em `Hunting`. Ajuste a interferência até a fala com chiado continuar **inteligível** (a legenda ajuda, mas não pode ser a única forma de entender).

**Parte 4 — passos e paridade (1 h).** Faça o 🔁 do evento de passo e do handler, crie `MS_Passo_Concreto` e `MS_Passo_Grade`. Com `vg.Debug.Noise 1`, ande e corra na grade e no concreto: o círculo de ruído e o volume que você ouve devem crescer juntos.

**Parte 5 — o susto (45 min).** Ligue o `PushSilence`/`PopSilence` à cena do susto. Teste os três caminhos: fim normal, pular, morrer no meio. Nos três, o ambiente volta.

---

## Desafio — as fitas de 1994

O `UVGDocumentData` tem uma `Narration` opcional desde o Capítulo 48. Faça do setor 1 o lugar da primeira **fita**: um gravador do turno C, com a voz de um operador gravada em 1994.

1. A fita é um documento com `Narration`. Ao abrir no leitor, a narração toca; ao fechar, para. A leitura conta como "leu" (Cap. 48) se a jogadora ouvir até o fim **ou** ler a transcrição até a última página: decida e teste.
2. A voz da fita precisa de uma cadeia própria (`MS_Fita_Voz`: banda estreita, chiado de fita, oscilação de velocidade). Ela não é um falante do diálogo; onde mora essa cadeia, sem duplicar o mecanismo do rádio?
3. A fita é ouvida **no espaço** (o gravador está na mesa, 3D) ou **no ouvido** (2D)? Se for no espaço, a Presença também a ouve? Uma fita tocando é um ruído para a IA? Decida no `DEVLOG.md` pensando na seção 52.5: o que ela ouve é o que a IA ouve.

---

## Uso de IA

1. **Para desenhar uma MetaSound:**
   > "Quero uma MetaSound Source na Unreal Engine 5 que simule uma voz de rádio portátil: entrada de wave com a fala, filtros para a banda de telefonia, saturação leve, cliques de squelch no início e no fim e uma entrada float 'Interferencia' (0–1) que adiciona ruído e quedas de volume. Descreva o grafo nó a nó, com os nomes de nós que existem na biblioteca padrão de MetaSounds, e marque os que você não tem certeza de que existem com esse nome."

2. **Para revisar a mixagem:**
   > "Esta é a árvore de Sound Classes e a tabela de estados de mixagem de um jogo de terror em primeira pessoa (abaixo). Aponte: estados que podem se sobrepor e como a composição deveria se comportar; classes que nunca deveriam ser abafadas e por quê; e tempos de entrada/saída que provavelmente soarão como bug. [árvore + tabela]"

3. **Para checar a paridade:**
   > "Num jogo, o ruído para a IA de um passo é Loudness × NoiseMultiplier do material, e o volume que a jogadora ouve é 0,35 + 0,45 × sqrt(ruído), limitado a [0,3; 1,2]. Para concreto (1,0), grade (1,6) e carpete (0,5), e para agachada (0,2), andando (0,5) e correndo (1,0), monte a tabela de ruído e de volume em dB relativos. Algum caso viola a ordem? Algum par tem ruído muito diferente e volume quase igual?"

**Cuidado específico:** a IA descreve grafos de MetaSound e nomes de nós com uma confiança que não tem, porque a biblioteca de nós cresceu e mudou de nome entre versões do UE5, e há pouco material público e atualizado. Trate cada nome de nó que ela sugerir como hipótese a conferir no editor, e cada número de mixagem como ponto de partida a ajustar **de ouvido**, com fone e com caixa de som.

---

## Checklist

- [ ] Sei o caminho de um som (fonte, instância, espaço, mixagem, saída) e onde cada decisão mora.
- [ ] Sei usar MetaSounds com parâmetros e suavizar dentro do grafo.
- [ ] Sei configurar atenuação, espacialização, oclusão e reverb, e onde a oclusão vale o custo.
- [ ] A mixagem da Vigília deriva do modo de input, e o silêncio é pedido com handle e sempre devolvido.
- [ ] O som da Presença é honesto sobre a posição, e a telegrafia é sonora e espacial.
- [ ] O som e o ruído dos passos saem da mesma conta, e o teste garante a ordem.
- [ ] Sônia soa como rádio, e o chiado conta quando a Presença está atenta.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **MetaSounds** (visão geral, referência de nós, parâmetros), **Sound Attenuation**, **Sound Classes and Sound Mixes**, **Submixes**, **Audio Modulation**, **Audio Volumes** e **Sound Concurrency**.
- **GDC Vault** (gdcvault.com): a trilha de áudio da GDC tem muitas palestras sobre som em jogos de terror, mixagem dinâmica e áudio procedural (confira títulos e autores lá).
- **Karen Collins, *Game Sound*** (MIT Press) — uma introdução histórica e teórica ao som em jogos.

---

➡️ **Próximo:** [Capítulo 53 — Animation](cap-53-animation.md)

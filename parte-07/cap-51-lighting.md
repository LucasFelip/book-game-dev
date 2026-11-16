# Capítulo 51 — Lighting

## Objetivo

Ao final deste capítulo você deve conseguir:

- explicar o mínimo de como a Unreal ilumina uma cena: tipos e mobilidade de luzes, **Lumen**, sombras e **exposição**;
- usar a luz como **composição**: dirigir o olhar, separar planos e criar uma **linguagem de luz** que a jogadora aprende;
- construir **escuridão jogável e legível**: escura o bastante para assustar, clara o bastante para jogar;
- tratar a luz como **mecânica** (Alan Wake): recurso, exposição, proteção e arma;
- implementar a **lanterna definitiva** (`UVGFlashlightComponent`), com bateria, flicker, tags de status, percepção, navegação e a **sobrecarga**;
- fazer as **luzes do mundo** reagirem a fatos e ao Diretor sem mentir sobre segurança;
- estimar o **custo** de luzes dinâmicas e sombras, a ponte para o Capítulo 58.

---

## Contexto

A luz é o pilar 1 da Vigília ("luz: recurso, linguagem, defesa", Cap. 76), e até aqui ela existiu em pedaços:

- o Capítulo 4 desenhou a máquina de estados da lanterna (`Off`, `On`, `Flickering`, `Overcharge`, `Depleted`) e deixou um esboço de `UVGFlashlightComponent` com o aviso "a lanterna real é implementada na Parte VII";
- o Capítulo 9 criou o `UVGFlickerComponent`, e o 13, os perfis de falha (`UVGFlickerProfile`);
- o Interlúdio I montou uma lanterna mínima em Blueprint: um `SpotLight` na câmera, `IA_Lanterna`, a bateria drenando e o flicker quando ela fica fraca;
- o Capítulo 19 deixou a bateria na jogadora "por ora", e o 36 fez a lanterna conceder `Status.Light.Flashlight`, que a percepção da Presença lê;
- o Capítulo 22 reservou o dano de luz para "a lanterna em sobrecarga (Capítulo 51)", e a Introdução prometeu "um sinalizador com poucos cartuchos e uma sobrecarga da lanterna".

A lanterna mínima funciona, mas é um Blueprint com estado em booleanos, e o flicker e a sobrecarga vão disputar a mesma intensidade de luz. As luzes do mundo, por sua vez, acendem por referência direta do setor, e nada garante que uma zona segura tenha, de fato, uma luz acesa. O Capítulo 50 deixou a regra que este capítulo precisa tornar verdadeira por construção: **a luz que guia não mente sobre segurança**.

---

## 51.1 O mínimo sobre luz na Unreal

Você não vai virar artista de iluminação, mas precisa do vocabulário para conversar com o editor e com o profiler.

**Tipos de luz.** *Directional* (o sol, a lua: raios paralelos, sem posição), *Point* (uma lâmpada, em todas as direções), *Spot* (um cone: a lanterna, um refletor), *Rect* (uma superfície: um painel, uma janela) e *Sky Light* (a luz do céu capturada do ambiente). Na Vigília, quase tudo é *Point*, *Spot* e *Rect*: é um lugar fechado, à noite.

**Mobilidade.** Toda luz tem uma mobilidade:
- ***Static***: calculada antes, em *lightmaps* (iluminação "assada"), sem custo em tempo real e sem mudar;
- ***Stationary***: posição fixa, cor e intensidade mutáveis, com parte pré-calculada;
- ***Movable***: tudo em tempo real.

Com **Lumen**, o sistema de iluminação global dinâmica do UE5, o fluxo padrão é usar luzes `Movable` e deixar o Lumen calcular a luz indireta (a que quica nas superfícies) em tempo real. ⚠️ O padrão dos projetos novos, e o que cada mobilidade faz com Lumen ligado, mudou entre versões; confira nas configurações de renderização do seu projeto.

**Luz direta e indireta.** A luz **direta** vai da fonte à superfície; a **indireta** quica antes de chegar. Num corredor escuro, a lanterna ilumina a parede (direta) e a parede devolve um pouco de luz ao redor (indireta, o Lumen). Essa luz rebatida é o que faz um ambiente parecer real, e o que faz a escuridão não ser um preto chapado.

**Sombras.** Luzes dinâmicas projetam sombras em tempo real; no UE5, o caminho padrão são os ***Virtual Shadow Maps*** (⚠️ confira se estão ligados no seu projeto). Sombras são o item mais caro da iluminação (seção 51.6), e a decisão de **quais** luzes projetam sombra é de design.

**Exposição.** A câmera da Unreal simula um olho ou uma câmera: a ***auto exposure*** (ou *eye adaptation*) clareia a imagem quando a cena é escura e escurece quando é clara. Num jogo de terror isso é um problema sério: deixada no automático, ela "acende" o escuro que você desenhou. A seção 51.3 trata disso.

---

## 51.2 Luz como composição

No cinema, a luz decide o que o espectador olha. No jogo, ela decide também para onde a jogadora **anda**. Três ideias de composição cobrem quase tudo.

1. **Contraste guia o olhar.** O olho vai para a área mais clara, ou de maior contraste, do quadro. Num corredor escuro, a única porta com luz embaixo é o destino.
2. **Planos separados.** Um objeto se destaca do fundo por uma luz de contorno (*rim light*) ou por uma diferença de valor (claro contra escuro, escuro contra claro). A silhueta da Presença no fim do corredor (Cap. 50) é escuro contra um fundo um pouco menos escuro: o fundo precisa de **alguma** luz para a silhueta existir.
3. **Temperatura de cor comunica.** Luz quente (amarelada) é humana e acolhedora; fria (azulada) é técnica, noturna, distante. Vermelho é alerta.

Daí sai a ferramenta mais importante para um jogo em que a luz é mecânica: uma **linguagem de luz**, um pequeno vocabulário que a jogadora aprende sem tutorial e que o jogo **nunca** contradiz.

| Significado | Como se parece na Vigília | Regra |
|---|---|---|
| **Segurança** | Luz de emergência âmbar, **estável**, que ilumina o chão ao redor | Sempre há uma zona segura sob ela; nunca falha |
| **Atenção** | Destaque fraco e pontual sobre um objeto (o livro, o painel), sem iluminar o chão | Nunca tem zona segura; nunca parece segurança |
| **Energia** | Luminárias de serviço brancas e frias, que acendem quando um setor é energizado | Estado do mundo: aparecem com fatos |
| **Perigo** | A falha: luz que pisca com o perfil "Presença próxima", ou que se apaga em cascata | Sempre significa a Presença (real ou roteirizada) |
| **Ela** (a jogadora) | O feixe branco-neutro da lanterna | É dela; a falha da lanterna fala de bateria, nunca de Presença |

A última linha evita uma ambiguidade sutil. Se a lanterna piscasse quando a Presença está perto (uma ideia tentadora), "a lanterna piscando" passaria a ter dois significados: bateria fraca **ou** perigo. A jogadora não saberia se troca a bateria ou se foge. Na Vigília, a lanterna pisca por bateria; o mundo pisca por perigo.

> 🌉 **Ponte:** a linguagem de luz é um ***design system*** de estados: cada cor e comportamento tem um significado único, como as cores de sucesso, aviso e erro de uma interface. Usar o vermelho de erro como decoração quebra o sistema inteiro.
>
> 🧱 **Onde a ponte cai:** na interface, o significado vem com texto e ícone; aqui, a jogadora **aprende** a linguagem jogando, e uma única contradição (uma luz de segurança que falha sem motivo) ensina a ela que a linguagem não é confiável. O custo de uma exceção é muito maior.

---

## 51.3 Escuridão jogável e legível

A escuridão é o recurso mais valioso de um jogo de terror, e o mais fácil de estragar. Escura demais, a jogadora não joga: tropeça, se perde, aumenta o brilho do monitor e destrói o clima. Clara demais, não assusta. O objetivo é uma escuridão **legível**: a jogadora não vê **o que** há no escuro, mas sabe **que** há espaço ali.

**1. Controle a exposição.** Num jogo escuro, a exposição automática precisa de limites. Num *Post Process Volume*, as opções de exposição permitem limitar a faixa (brilho mínimo e máximo de adaptação) ou usar exposição manual. A Vigília usa uma faixa **estreita**: o olho se adapta um pouco ao escuro (a jogadora sente o "acostumar"), mas nunca o bastante para o escuro deixar de ser escuro. ⚠️ Os nomes dos campos (*Min/Max EV100*, *Metering Mode*) e o modo padrão variam entre versões; ajuste olhando a cena, não os números.

**2. Nunca preto absoluto no caminho crítico.** Sempre há alguma fonte que desenha a forma do espaço: o luar por uma janela alta, o LED de um painel, a luz de emergência ao longe, o rebatido da lanterna. Preto puro não é escuridão; é ausência de imagem.

**3. Luzes-guia emissivas.** Placas de saída, LEDs de painéis, a luz piloto de um quadro. Materiais emissivos são baratos e funcionam como *breadcrumbs* de luz (Cap. 50). ⚠️ Com Lumen, superfícies emissivas **podem** iluminar o entorno, mas emissivos pequenos não são uma fonte de luz confiável; se a luz no chão importa, use uma luz de verdade.

**4. A lanterna como luz principal.** Num espaço escuro, a lanterna é a câmera do diretor de fotografia: a jogadora decide o que vê. O alcance útil (~12–15 m, Cap. 50) e o ângulo do cone são decisões de level design. Um cone estreito e longo cria um "túnel" de visão tenso; um cone largo e curto dá mais segurança e menos alcance. Um perfil **IES** (um arquivo que descreve a distribuição real de luz de uma luminária) dá ao feixe o anel e as imperfeições de uma lanterna de verdade, quase sem custo.

**5. Calibração de brilho.** Monitores e TVs variam muito. Uma tela de calibração ("ajuste até o símbolo da esquerda quase sumir") no primeiro início é uma opção de acessibilidade e de design ao mesmo tempo (Cap. 55).

**6. Teste em telas diferentes.** O escuro que funciona no seu monitor calibrado vira breu numa TV com contraste agressivo e cinza numa tela de notebook. Teste em pelo menos três.

> 🌉 **Ponte:** é a mesma disciplina de projetar para a pior rede ou o pior dispositivo: a experiência precisa se degradar com dignidade, não quebrar, quando o ambiente de execução não é o seu.
>
> 🧱 **Onde a ponte cai:** em software, o objetivo é a experiência **igual** em todo lugar. Aqui, você aceita diferenças de clima entre telas, desde que a **legibilidade** se mantenha: o mínimo garantido é "a jogadora consegue jogar", não "a jogadora sente o mesmo".

---

## 51.4 Luz como mecânica

A spec pergunta, no estudo de caso de Alan Wake: *como iluminação pode ser transformada de elemento visual em mecânica de gameplay?* A Vigília responde com quatro regras, todas já parcialmente construídas:

| Regra | O que significa | Sistemas |
|---|---|---|
| **Ver custa** | Lanterna acesa = muito visível; escuro = só vista de perto | Percepção (Cap. 36): `Status.Light.Flashlight` → fator de exposição |
| **A luz protege** | Onde há luz estável, a Presença não entra | Zonas seguras (Cap. 23), `UVGNavArea_Lit` e o filtro da Presença (Cap. 35) |
| **A luz é recurso** | A lanterna gasta bateria; baterias são escassas | `UVGBatteryComponent` (Cap. 4), pickups (Cap. 19) |
| **A luz é arma** | Luz intensa repele e atordoa a Presença | Sinalizador (Cap. 28); **sobrecarga** (este capítulo); dano de luz (Cap. 22) |

As quatro regras se tensionam umas às outras, e é dessa tensão que vem o jogo. Preciso ver (lanterna acesa), mas ver me expõe. Preciso de bateria para a próxima sobrecarga, mas economizar bateria é andar no escuro. A luz estável me protege, mas não posso ficar nela para sempre (o objetivo está no escuro).

### A sobrecarga

A sobrecarga é um **pulso curto e intenso** da lanterna. Ela fecha o conjunto de armas de luz da Vigília: o sinalizador é forte, raro e posicional (cria uma zona); a sobrecarga é fraca, recarregável e direcional (afasta o que está na frente).

```text
 SOBRECARGA (docs/design/combate.md, v0.2 — entra na v1.0 do Cap. 76)

 ENTRADA      Segurar IA_SobrecargaLanterna por 0,35 s com a lanterna acesa
              (o "carregar" é a telegrafia DA JOGADORA: um zumbido crescente)
 CUSTO        25 de carga (bateria de 100) — no máximo 4 pulsos com a bateria cheia
 PULSO        0,3 s; cone de 8 m e ~25° de meio-ângulo, com linha de visão
 EFEITO       Dano de luz de magnitude 40 → a Presença recua e fica atordoada
              ~2 s (a mesma tabela do pulso do sinalizador, Cap. 37)
              Humanos: nada (multiplicador de Light = 0 nos vigias, Cap. 22)
 RECARGA      6 s de cooldown
 PREÇO        Depois do pulso, a lanterna volta a 30% e leva 1 s para recuperar:
              o flash cega a jogadora também
              Ruído: o pulso é ouvido (como uma porta, ~15 m)
 ESTADO       Status.Light.Overcharge enquanto dura; Status.Light.Flashlight sempre
```

Cada número tem um motivo. **Magnitude 40** (contra 100 do acerto direto do sinalizador) mantém o sinalizador como a ferramenta forte: a sobrecarga compra 2 s, o sinalizador compra 4 e uma zona. **25 de carga** faz cada pulso custar um quarto da bateria: a jogadora que abusa da sobrecarga fica no escuro. O **preço depois do pulso** (a lanterna fraca por 1 s) transforma a arma num risco: se a Presença não estava onde ela pensava, o pulso a deixou cega e ouvida. E o **segurar** de 0,35 s é a telegrafia da própria jogadora, que impede o pulso acidental e dá ao gesto um peso físico.

> 🌉 **Ponte:** a sobrecarga é um *rate limiter* com orçamento compartilhado: um *token bucket* (a bateria) que também alimenta o serviço principal (a lanterna acesa), mais um *cooldown* fixo.
>
> 🧱 **Onde a ponte cai:** num sistema, o *rate limiter* protege o recurso e é invisível para quem o respeita. Aqui, o limite **é** o jogo: a jogadora precisa senti-lo, pesá-lo e às vezes perdê-lo. Um limite que nunca aperta não é design.

---

## 51.5 Luzes do mundo: fatos, Diretor e a regra da segurança

As luzes da usina mudam por três motivos: o **estado da história** (um setor foi energizado), o **Diretor** (os sinais de `BuildUp`, Cap. 42) e **cenas** (a cascata do susto, Cap. 49). Cada motivo tem um dono diferente, e o perigo é que dois donos mexam na mesma luz de jeitos incompatíveis.

**Fatos, não eventos.** Uma luminária que acende "quando o setor é energizado" pode escutar o evento `Event.Sector.Powered`, ou ler o fato `S1.BreakersRestored` que a regra do Capítulo 46 deriva dele. O fato é melhor, pela razão que o Capítulo 45 formulou: **eventos são o momento, fatos são a memória**. Uma luminária que lê o fato acende certo depois de carregar um save, sem código de restauração; uma que escuta o evento ficaria apagada.

**A regra da segurança, por construção.** Até aqui, o `AVGSector` ativava as zonas seguras do setor ao ser energizado, e o level designer era responsável por pôr uma luz em cima de cada zona. Nada impedia uma zona segura sem luz, ou uma luz de emergência apagada sobre uma zona ativa. 🔁 A partir deste capítulo, **a luminária é dona da zona que protege**: uma luminária com uma zona associada ativa a zona quando acende e a desativa quando apaga. O setor deixa de tocar nas zonas. "Só é seguro onde há luz" passa a ser verdade estrutural, e não uma disciplina de quem monta o nível.

**O Diretor pode assustar, mas não pode mentir.** Os sinais de `BuildUp` fazem luzes próximas à jogadora falharem. Mas uma luz de segurança que falha diz "a segurança não é confiável". Por isso, **o Diretor só mexe em luminárias que não protegem zona nenhuma**. A cascata do susto (uma cena) mexe nas luminárias do corredor, que também não protegem nada. A luz de emergência do hall nunca pisca.

```text
 QUEM MEXE EM QUÊ (luzes do mundo)

  fato (Narrative.Fact.*) ──► AVGLightFixture: ACESA / APAGADA ──► AVGSafeZone (se houver)
                                      │
  Diretor (Event.Director.BuildUp) ──► flicker temporário  ✖ se a luminária protege zona
  cena (Sequencer, Cap. 49) ─────────► flicker roteirizado ✖ idem (regra de autoria)

  "acesa/apagada" = visibilidade da luz (dono: a luminária)
  "flicker"       = intensidade (dono: o UVGFlickerComponent da luminária)
```

Repare na separação entre **visibilidade** e **intensidade**: são duas propriedades diferentes da luz, com dois donos diferentes, e por isso não brigam. É a regra do dono único (Cap. 4) aplicada a uma lâmpada.

---

## 51.6 O custo da luz

Luz dinâmica é cara, e quase todo o custo está em três lugares. Este é um resumo para o design; a medição é o assunto dos Capítulos 58 e 59.

1. **Sombras.** Cada luz dinâmica que projeta sombra precisa desenhar a cena do ponto de vista da luz (ou atualizar as páginas de sombra que mudaram, no caso dos *Virtual Shadow Maps*). Uma *point light* com sombra é a pior: ela olha em todas as direções. Regra da Vigília: **a lanterna sempre projeta sombra** (é a sombra mais importante do jogo: a da Presença na parede); das luzes do mundo, só as que compõem a cena (a emergência do hall, a do puzzle) projetam. As de preenchimento, não.
2. **Sobreposição.** Cada pixel paga por todas as luzes que o atingem. O raio de atenuação (*attenuation radius*) de cada luz deve ser o menor que funciona. O modo de visualização ***Light Complexity*** do viewport mostra onde há luzes demais sobrepostas.
3. **Iluminação global e névoa.** O Lumen tem custo fixo por frame, com níveis de qualidade nas configurações de escalabilidade, e opções de *software* e *hardware ray tracing* (⚠️ confira os requisitos da sua plataforma). A **névoa volumétrica**, que faz o feixe da lanterna aparecer no ar, também custa, e cada luz pode contribuir ou não para ela.

Uma observação prática sobre luz que muda rápido: o Lumen acumula a luz indireta ao longo de vários frames. A luz **direta** de uma lâmpada que pisca muda na hora, mas o **rebatido** pode reagir com atraso. Num flicker rápido, isso aparece como um "rastro" de luz indireta. ⚠️ Observe na sua cena; luzes que piscam muito podem ter a contribuição indireta reduzida (na própria luz há um multiplicador de intensidade indireta).

E a ponte para o Capítulo 58: **o orçamento de luz é por espaço, não por jogo**. O corredor com quatro luminárias de flicker, a lanterna com sombra e a névoa volumétrica precisa caber nos 16,67 ms (60 FPS) **com** a Presença, o áudio e a UI. Medir o corredor do susto no pior momento (a cascata acontecendo) é o primeiro teste de performance da Vigília.

---

## Estudos de caso

### Alan Wake — a luz como arma e como lugar

**[FATO PÚBLICO, observável jogando]** Em *Alan Wake* (Remedy, 2010), os Taken são protegidos por uma camada de escuridão. Alan precisa **focar** a lanterna neles (o que gasta bateria rapidamente) para queimar essa proteção; só depois as armas de fogo os ferem. Há baterias para coletar, sinalizadores, granadas de luz e uma pistola de sinalização. Postes e holofotes funcionam como refúgios. *Alan Wake 2* (2023) mantém a lanterna com foco e baterias como parte central do combate.

**[INFERÊNCIA]** A mecânica é uma cadeia de dois passos (luz, depois tiro), e a lanterna é ao mesmo tempo **mira** (o feixe aponta o alvo), **recurso** (bateria) e **arma**. Isso explica por que o combate é tenso mesmo com armas: a arma depende de um recurso que se esgota e que, ao mesmo tempo, ilumina o caminho. O "foco" provavelmente é um teste de cone com acúmulo de tempo sobre o alvo, mas como a Remedy o implementa não é público.

**Lição para a Vigília:** a Vigília pega a ideia e a inverte em escala: a luz é a única arma contra a Presença (que não morre), e a sobrecarga é o "foco" comprimido num pulso. O que se aproveita é o princípio: **a luz que você usa para ver é a mesma que você usa para se defender**, e isso faz cada uso ter dois custos.

### Amnesia: The Dark Descent — o paradoxo da escuridão

**[FATO PÚBLICO, observável jogando]** Em *Amnesia: The Dark Descent* (Frictional Games, 2010), ficar no escuro e olhar para os monstros reduz a sanidade do protagonista, com efeitos de distorção de imagem e som. Ao mesmo tempo, a escuridão o esconde dos monstros. Ele pode acender velas e tochas com *tinderboxes*, que são limitadas, e tem uma lanterna a óleo, também limitada.

**[INFERÊNCIA]** O sistema cria um paradoxo: a luz conforta e expõe; o escuro esconde e corrói. Não há escolha "certa", e é por isso que cada decisão de acender ou apagar pesa. As *tinderboxes* acrescentam permanência: uma vela acesa fica acesa, e a jogadora "constrói" pontos de luz no nível.

**Lição para a Vigília:** a Vigília tem metade do paradoxo (a luz expõe; o escuro esconde), sem sanidade. O que falta, a corrosão do escuro, é substituído pela Presença, que caça no escuro. Uma ideia que vale testar no desafio: pontos de luz que a jogadora **acende** (uma lâmpada de emergência religada) e que passam a ser zonas seguras, como as velas de Amnesia.

### Control — a luz que compõe e o custo de mostrar

**[FATO PÚBLICO]** *Control* (Remedy, 2019) foi um dos primeiros jogos a usar *ray tracing* em tempo real em PC para vários efeitos ao mesmo tempo (reflexos, sombras de contato, iluminação indireta difusa), em divulgação conjunta da Remedy com a NVIDIA. Jogando, é observável que a Oldest House usa luz forte e geométrica sobre a arquitetura brutalista, e que as áreas tomadas pelo Hiss ganham uma luz avermelhada.

**[INFERÊNCIA]** A luz faz duas coisas. Compõe a arquitetura (a escala do prédio, a geometria, o vazio) e marca o estado do mundo (vermelho onde o Hiss domina). E o *ray tracing* mostra o outro lado: cada efeito de luz tem um custo, e as opções gráficas do jogo permitiam ligar e desligar cada um. O jogo precisava ficar bonito e coerente com qualquer combinação.

**Lição para a Vigília:** a cor como **estado** (vermelho = Hiss) é a mesma ideia da linguagem de luz da seção 51.2. E o custo como **opção** prepara o Capítulo 58: a névoa volumétrica e as sombras das luminárias devem ser opções de escalabilidade, com a lanterna e a linguagem de luz intactas em todas.

---

## Comparação com o desenvolvimento tradicional

| Conceito | O que você conhece | Onde a analogia cai |
|---|---|---|
| Linguagem de luz | *Design system* de estados (sucesso, aviso, erro) | É aprendida jogando, sem texto; uma exceção destrói a confiança |
| Escuridão legível | Projetar para o pior dispositivo | Aceita-se clima diferente entre telas; garante-se a legibilidade |
| Sobrecarga | *Token bucket* + *cooldown* | O limite é o próprio jogo, e precisa ser sentido |
| Luminária dona da zona | Invariante garantida por construção, não por convenção | — (a analogia vale) |
| Luzes lendo fatos | Estado derivado de fonte persistida | — (a analogia vale; é o que torna o save trivial) |
| Orçamento de luz por espaço | Orçamento de latência por *endpoint* | O "*endpoint*" é um lugar, e o pior caso é um momento roteirizado |

---

## Unreal Engine: o que existe

- **Componentes de luz**: `UPointLightComponent`, `USpotLightComponent`, `URectLightComponent`, `UDirectionalLightComponent`, `USkyLightComponent`. Em C++: `SetIntensity`, `SetLightColor`, `SetVisibility`, `SetCastShadows`, `SetAttenuationRadius`; no spot, `SetInnerConeAngle`/`SetOuterConeAngle`. Cada luz tem também multiplicadores de contribuição indireta e volumétrica (⚠️ confira os nomes das propriedades na sua versão).
- **Perfis IES** e ***Light Functions*** (um material que modula a luz, como um *gobo*). IES é barato; *light functions* custam mais.
- **Lumen** (iluminação global e reflexos dinâmicos) e **Virtual Shadow Maps**, configurados no projeto e nos *Post Process Volumes*.
- **Post Process Volume**: exposição, *bloom*, granulação, vinheta, correção de cor.
- **Exponential Height Fog** com **Volumetric Fog**, e ⚠️ *Local Fog Volumes* em versões recentes do UE5.
- **Modos de visualização**: *Lighting Only*, *Light Complexity*, *Detail Lighting* e as visualizações do Lumen, para diagnosticar.
- **Escalabilidade** (`sg.*` e os níveis de qualidade): o caminho para transformar custos em opções (Caps. 55 e 58).

O que a engine **não** oferece: um conceito de "luz que protege", de lanterna com bateria ou de linguagem de luz. Isso é gameplay, e é seu.

---

## Abordagens: onde mora a lanterna

| Critério | A. Blueprint na jogadora (Interlúdio I) | **B. Componente C++ que é a própria luz (`USpotLightComponent`)** | C. Ator separado (`AVGFlashlight`) preso à mão |
|---|---|---|---|
| **Estado** | Booleanos espalhados | **FSM do Cap. 4, num lugar só** | FSM |
| **Dono da intensidade** | Disputado (flicker × sobrecarga) | **O próprio componente** | O ator |
| **Teste** | Não | **Transições como regra pura** | Sim |
| **Pode ser largada, trocada, dada a outro personagem** | Não | Não | **Sim** |
| **Complexidade** | Baixa | Média | Maior (posse, anexo, animação, persistência) |
| **Adequação à Vigília** | Foi a dívida | **Sim** | Excesso: Helena nunca larga a lanterna |

**Decisão: B.** `UVGFlashlightComponent` deriva de `USpotLightComponent`: a lanterna **é** um spot com estado. A bateria continua na jogadora (Cap. 19): a lanterna é o único consumidor e os pickups de bateria já a encontram lá. Se um dia a lanterna puder ser largada, a opção C passa a valer, e a bateria vai com ela.

---

## Implementação

### 1. Tags e módulos

```cpp
// VGGameplayTags.h (adição)
UE_DECLARE_GAMEPLAY_TAG_EXTERN(TAG_Status_Light_Overcharge);

// VGGameplayTags.cpp (adição)
UE_DEFINE_GAMEPLAY_TAG(TAG_Status_Light_Overcharge, "Status.Light.Overcharge");
```

Nenhum módulo novo: componentes de luz e dano estão no `Engine`.

### 2. 🔁 O flicker vira função pura

**Antes**, a amostragem do padrão de flicker (a letra `a`–`z` atual → escala de intensidade) morava dentro do `UVGFlickerComponent` (Cap. 9). **O problema:** a lanterna precisa da mesma amostragem, e copiar a função criaria duas fontes da verdade para "o que o `m` significa". **Agora**, a amostragem é uma regra pura, usada pelos dois:

```cpp
// Source/Vigilia/World/VGFlickerRules.h
#pragma once

#include "CoreMinimal.h"

namespace VGFlickerRules
{
    /** 'a' = 0 (apagada), 'm' = 1 (normal), 'z' ≈ 2,08. Padrão vazio = 1. */
    float SampleScale(const FString& Pattern, float StepsPerSecond, float ElapsedSeconds);
}
```

```cpp
// Source/Vigilia/World/VGFlickerRules.cpp
#include "World/VGFlickerRules.h"

float VGFlickerRules::SampleScale(const FString& Pattern, float StepsPerSecond, float ElapsedSeconds)
{
    if (Pattern.IsEmpty() || StepsPerSecond <= 0.0f)
    {
        return 1.0f;
    }
    const int32 Step = FMath::FloorToInt(ElapsedSeconds * StepsPerSecond) % Pattern.Len();
    const TCHAR Letter = FChar::ToLower(Pattern[FMath::Max(Step, 0)]);
    return FMath::Clamp(static_cast<float>(Letter - TEXT('a')), 0.0f, 25.0f) / static_cast<float>(TEXT('m') - TEXT('a'));
}
```

O `SampleScale()` privado do `UVGFlickerComponent` passa a chamar `VGFlickerRules::SampleScale(Pattern, StepsPerSecond, Elapsed)` e mantém a suavização e o `vg.Flicker.Enabled` como estavam. Se a sua versão do Capítulo 9 amostrava de outro jeito, preserve o seu mapeamento aqui: o ponto é ter **um** lugar.

### 3. As regras da lanterna

```cpp
// Source/Vigilia/Player/VGFlashlightRules.h
#pragma once

#include "CoreMinimal.h"
#include "VGFlashlightRules.generated.h"

/** Os cinco estados válidos da lanterna (Cap. 4). */
UENUM(BlueprintType)
enum class EVGFlashlightState : uint8
{
    Off,
    On,
    Flickering, // bateria fraca: acesa, mas falhando
    Overcharge, // o pulso
    Depleted    // ligada, sem carga
};

/** O que pode acontecer com a lanterna. */
enum class EVGFlashlightInput : uint8
{
    TogglePressed,
    OverchargeRequested,
    OverchargeFinished,
    BatteryLow,
    BatteryRecovered,  // saiu de Low por recarga
    BatteryDepleted,
    BatteryReplaced    // saiu de Depleted por recarga
};

struct FVGFlashlightContext
{
    bool bBatteryLow = false;
    bool bHasCharge = true;
    bool bCanAffordOvercharge = false;
    bool bOverchargeReady = false; // cooldown cumprido
};

namespace VGFlashlightRules
{
    /** A tabela de transições do exercício do Cap. 4. Devolve o estado atual quando a entrada não se aplica. */
    EVGFlashlightState Next(EVGFlashlightState Current, EVGFlashlightInput Input, const FVGFlashlightContext& Ctx);

    /** O feixe está visível (para Status.Light.Flashlight e para a percepção)? */
    inline bool IsBeamVisible(EVGFlashlightState State)
    {
        return State == EVGFlashlightState::On || State == EVGFlashlightState::Flickering
            || State == EVGFlashlightState::Overcharge;
    }
}
```

```cpp
// Source/Vigilia/Player/VGFlashlightRules.cpp
#include "Player/VGFlashlightRules.h"

using EState = EVGFlashlightState;
using EInput = EVGFlashlightInput;

EVGFlashlightState VGFlashlightRules::Next(EState Current, EInput Input, const FVGFlashlightContext& Ctx)
{
    const EState Lit = Ctx.bBatteryLow ? EState::Flickering : EState::On;

    if (Input == EInput::BatteryDepleted && IsBeamVisible(Current))
    {
        return EState::Depleted; // de On, Flickering ou Overcharge
    }

    switch (Current)
    {
    case EState::Off:
        return (Input == EInput::TogglePressed && Ctx.bHasCharge) ? Lit : Current;

    case EState::On:
    case EState::Flickering:
        switch (Input)
        {
        case EInput::TogglePressed:       return EState::Off;
        case EInput::BatteryLow:          return EState::Flickering;
        case EInput::BatteryRecovered:    return EState::On;
        case EInput::OverchargeRequested:
            return (Ctx.bCanAffordOvercharge && Ctx.bOverchargeReady) ? EState::Overcharge : Current;
        default:                          return Current;
        }

    case EState::Overcharge:
        // O pulso não é interrompido pelo interruptor: dura 0,3 s e termina sozinho.
        return Input == EInput::OverchargeFinished ? (Ctx.bHasCharge ? Lit : EState::Depleted) : Current;

    case EState::Depleted:
        // Cap. 4: desligar ou trocar a bateria leva a Off; ela acende de novo pelo interruptor.
        return (Input == EInput::TogglePressed || Input == EInput::BatteryReplaced) ? EState::Off : Current;
    }
    return Current;
}
```

### 4. O componente

```cpp
// Source/Vigilia/Player/VGFlashlightComponent.h
#pragma once

#include "CoreMinimal.h"
#include "Components/SpotLightComponent.h"
#include "Player/VGBatteryComponent.h" // EVGBatteryState no UFUNCTION
#include "Player/VGFlashlightRules.h"
#include "VGFlashlightComponent.generated.h"

class UVGFlickerProfile;
class UVGStatusTagsComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FVGFlashlightStateChangedSignature,
    EVGFlashlightState, OldState, EVGFlashlightState, NewState);

/**
 * A lanterna de Helena: um spot com a máquina de estados do Cap. 4.
 * Dona única da PRÓPRIA intensidade (não ponha um UVGFlickerComponent no mesmo ator).
 * Bateria: a do ator dono (Cap. 19). Relógio: tempo de jogo (pulso e cooldown pausam e dilatam).
 */
UCLASS(ClassGroup = (Vigilia), meta = (BlueprintSpawnableComponent))
class VIGILIA_API UVGFlashlightComponent : public USpotLightComponent
{
    GENERATED_BODY()

public:
    UVGFlashlightComponent();

    UFUNCTION(BlueprintCallable, Category = "Vigilia|Flashlight")
    void Toggle();

    /** Chamado quando IA_SobrecargaLanterna dispara (o "segurar" é do Enhanced Input). */
    UFUNCTION(BlueprintCallable, Category = "Vigilia|Flashlight")
    void RequestOvercharge();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Flashlight")
    EVGFlashlightState GetState() const { return State; }

    /** 0 = acabou de pulsar, 1 = pronta. Para a HUD diegética (Cap. 55). */
    UFUNCTION(BlueprintPure, Category = "Vigilia|Flashlight")
    float GetOverchargeReadiness() const;

    UPROPERTY(BlueprintAssignable, Category = "Vigilia|Flashlight")
    FVGFlashlightStateChangedSignature OnStateChanged;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight", meta = (ClampMin = "0.0"))
    float DrainPerSecond = 0.8f; // ~2 min de luz contínua com 100 de carga

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight")
    TObjectPtr<UVGFlickerProfile> LowBatteryFlicker;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "0.0"))
    float OverchargeCost = 25.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "0.05"))
    float OverchargeDuration = 0.3f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "0.0"))
    float OverchargeCooldown = 6.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "100.0"))
    float OverchargeRange = 800.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "1.0", ClampMax = "80.0"))
    float OverchargeHalfAngleDegrees = 25.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "0.0"))
    float OverchargeLightMagnitude = 40.0f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "1.0"))
    float OverchargeIntensityScale = 6.0f;

    /** O preço visual do pulso: a lanterna volta a esta fração e recupera em RecoverySeconds. */
    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "0.0", ClampMax = "1.0"))
    float PostPulseScale = 0.3f;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Flashlight|Overcharge", meta = (ClampMin = "0.0"))
    float RecoverySeconds = 1.0f;

private:
    void Apply(EVGFlashlightInput Input);
    void EnterState(EVGFlashlightState NewState);
    void FireOverchargePulse();
    void UpdateIntensity();
    FVGFlashlightContext MakeContext() const;
    double Now() const;

    UFUNCTION()
    void HandleBatteryStateChanged(EVGBatteryState OldState, EVGBatteryState NewState);

    UPROPERTY(Transient)
    TObjectPtr<UVGBatteryComponent> Battery;

    UPROPERTY(Transient)
    TObjectPtr<UVGStatusTagsComponent> StatusTags;

    EVGFlashlightState State = EVGFlashlightState::Off;
    float BaseIntensity = 0.0f;
    double StateEnteredAt = 0.0;
    double LastPulseAt = -1000.0;
};
```

```cpp
// Source/Vigilia/Player/VGFlashlightComponent.cpp
#include "Player/VGFlashlightComponent.h"

#include "AI/VGNoiseLibrary.h"
#include "Combat/VGDamageTypes.h"
#include "Core/VGGameplayTags.h"
#include "Core/VGLog.h"
#include "Core/VGStatusTagsComponent.h"
#include "DrawDebugHelpers.h"
#include "Engine/OverlapResult.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "HAL/IConsoleManager.h"
#include "Kismet/GameplayStatics.h"
#include "World/VGFlickerProfile.h"
#include "World/VGFlickerRules.h"

static TAutoConsoleVariable<bool> CVarVGDebugFlashlight(
    TEXT("vg.Debug.Flashlight"), false, TEXT("Desenha o cone da sobrecarga e loga as transições da lanterna."), ECVF_Default);

UVGFlashlightComponent::UVGFlashlightComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.bStartWithTickEnabled = false; // só tica acesa
    SetCastShadows(true); // a sombra mais importante do jogo
}

void UVGFlashlightComponent::BeginPlay()
{
    Super::BeginPlay();
    BaseIntensity = Intensity; // valor editado no Blueprint, que não existe no construtor
    Battery = GetOwner()->FindComponentByClass<UVGBatteryComponent>();
    StatusTags = GetOwner()->FindComponentByClass<UVGStatusTagsComponent>();
    if (ensureMsgf(Battery, TEXT("%s: lanterna sem bateria no dono"), *GetName()))
    {
        Battery->OnBatteryStateChanged.AddDynamic(this, &UVGFlashlightComponent::HandleBatteryStateChanged);
    }
    SetVisibility(false);
}

void UVGFlashlightComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    if (Battery)
    {
        Battery->OnBatteryStateChanged.RemoveDynamic(this, &UVGFlashlightComponent::HandleBatteryStateChanged);
    }
    Super::EndPlay(EndPlayReason);
}

double UVGFlashlightComponent::Now() const
{
    return GetWorld()->GetTimeSeconds();
}

FVGFlashlightContext UVGFlashlightComponent::MakeContext() const
{
    FVGFlashlightContext Ctx;
    if (Battery)
    {
        Ctx.bBatteryLow = Battery->GetBatteryState() == EVGBatteryState::Low;
        Ctx.bHasCharge = Battery->GetCharge() > 0.0f;
        Ctx.bCanAffordOvercharge = Battery->GetCharge() >= OverchargeCost;
    }
    Ctx.bOverchargeReady = Now() - LastPulseAt >= OverchargeCooldown;
    return Ctx;
}

void UVGFlashlightComponent::Toggle()           { Apply(EVGFlashlightInput::TogglePressed); }
void UVGFlashlightComponent::RequestOvercharge() { Apply(EVGFlashlightInput::OverchargeRequested); }

float UVGFlashlightComponent::GetOverchargeReadiness() const
{
    return OverchargeCooldown <= 0.0f ? 1.0f
        : FMath::Clamp(static_cast<float>((Now() - LastPulseAt) / OverchargeCooldown), 0.0f, 1.0f);
}

void UVGFlashlightComponent::HandleBatteryStateChanged(EVGBatteryState OldState, EVGBatteryState NewState)
{
    if (NewState == EVGBatteryState::Depleted)      { Apply(EVGFlashlightInput::BatteryDepleted); }
    else if (OldState == EVGBatteryState::Depleted) { Apply(EVGFlashlightInput::BatteryReplaced); }
    else if (NewState == EVGBatteryState::Low)      { Apply(EVGFlashlightInput::BatteryLow); }
    else                                            { Apply(EVGFlashlightInput::BatteryRecovered); }
}

void UVGFlashlightComponent::Apply(EVGFlashlightInput Input)
{
    const EVGFlashlightState NewState = VGFlashlightRules::Next(State, Input, MakeContext());
    if (NewState != State)
    {
        EnterState(NewState);
    }
}

void UVGFlashlightComponent::EnterState(EVGFlashlightState NewState)
{
    const EVGFlashlightState OldState = State;
    State = NewState; // estado consistente antes de qualquer efeito ou anúncio
    StateEnteredAt = Now();

    // Tags de status simétricas por construção: concede/revoga só na mudança.
    if (StatusTags)
    {
        const bool bWasLit = VGFlashlightRules::IsBeamVisible(OldState);
        const bool bIsLit = VGFlashlightRules::IsBeamVisible(NewState);
        if (bIsLit && !bWasLit) { StatusTags->GrantStatus(TAG_Status_Light_Flashlight); }
        if (!bIsLit && bWasLit) { StatusTags->RevokeStatus(TAG_Status_Light_Flashlight); }
        if (NewState == EVGFlashlightState::Overcharge) { StatusTags->GrantStatus(TAG_Status_Light_Overcharge); }
        if (OldState == EVGFlashlightState::Overcharge) { StatusTags->RevokeStatus(TAG_Status_Light_Overcharge); }
    }

    SetVisibility(VGFlashlightRules::IsBeamVisible(NewState));
    SetComponentTickEnabled(VGFlashlightRules::IsBeamVisible(NewState));
    UpdateIntensity();

    UE_CLOG(CVarVGDebugFlashlight.GetValueOnGameThread(), LogVigilia, Log, TEXT("Lanterna: %s -> %s"),
            *UEnum::GetValueAsString(OldState), *UEnum::GetValueAsString(NewState));
    OnStateChanged.Broadcast(OldState, NewState);

    if (NewState == EVGFlashlightState::Overcharge)
    {
        FireOverchargePulse(); // por último: ver o comentário no fim de FireOverchargePulse
    }
}

void UVGFlashlightComponent::FireOverchargePulse()
{
    LastPulseAt = Now();

    APawn* OwnerPawn = Cast<APawn>(GetOwner());
    const FVector Origin = GetComponentLocation();
    const FVector Forward = GetForwardVector();
    const float CosHalfAngle = FMath::Cos(FMath::DegreesToRadians(OverchargeHalfAngleDegrees));

    TArray<FOverlapResult> Overlaps;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(VGOvercharge), false, GetOwner());
    GetWorld()->OverlapMultiByObjectType(Overlaps, Origin, FQuat::Identity,
        FCollisionObjectQueryParams(ECC_Pawn), FCollisionShape::MakeSphere(OverchargeRange), Params);

    TSet<AActor*> Hit; // uma pawn pode ter vários componentes no overlap
    for (const FOverlapResult& Overlap : Overlaps)
    {
        AActor* Target = Overlap.GetActor();
        if (!Target || Hit.Contains(Target))
        {
            continue;
        }
        const FVector ToTarget = Target->GetActorLocation() - Origin;
        if (FVector::DotProduct(ToTarget.GetSafeNormal(), Forward) < CosHalfAngle)
        {
            continue; // fora do cone
        }
        FHitResult Block;
        if (GetWorld()->LineTraceSingleByChannel(Block, Origin, Target->GetActorLocation(), ECC_Visibility, Params)
            && Block.GetActor() != Target)
        {
            continue; // a luz não atravessa paredes
        }
        Hit.Add(Target);
        FHitResult HitInfo(Target, nullptr, Target->GetActorLocation(), -ToTarget.GetSafeNormal());
        UGameplayStatics::ApplyPointDamage(Target, OverchargeLightMagnitude, ToTarget.GetSafeNormal(), HitInfo,
            OwnerPawn ? OwnerPawn->GetController() : nullptr, GetOwner(), UVGDamageType_Light::StaticClass());
    }

    // O pulso é ouvido (Cap. 36): a arma de luz também denuncia.
    UVGNoiseLibrary::ReportNoise(this, Origin, 0.6f, GetOwner(), 1500.0f, TEXT("Overcharge"));

    if (CVarVGDebugFlashlight.GetValueOnGameThread())
    {
        const float HalfAngleRad = FMath::DegreesToRadians(OverchargeHalfAngleDegrees);
        DrawDebugCone(GetWorld(), Origin, Forward, OverchargeRange, HalfAngleRad, HalfAngleRad, 16,
                      Hit.Num() > 0 ? FColor::Yellow : FColor::Silver, false, 1.0f);
    }

    // POR ÚLTIMO: drenar pode esgotar a bateria, que anuncia Depleted e REENTRA em EnterState.
    // Nada depois desta linha (nem em EnterState) lê o estado da lanterna.
    Battery->Drain(OverchargeCost);
}

void UVGFlashlightComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    if (State == EVGFlashlightState::Overcharge && Now() - StateEnteredAt >= OverchargeDuration)
    {
        Apply(EVGFlashlightInput::OverchargeFinished);
    }
    if (Battery && (State == EVGFlashlightState::On || State == EVGFlashlightState::Flickering))
    {
        Battery->Drain(DrainPerSecond * DeltaTime); // contínuo: drenado por quem consome (Cap. 4)
    }
    UpdateIntensity();
}

void UVGFlashlightComponent::UpdateIntensity()
{
    float Scale = 1.0f;
    if (State == EVGFlashlightState::Overcharge)
    {
        Scale = OverchargeIntensityScale;
    }
    else if (State == EVGFlashlightState::Flickering && LowBatteryFlicker)
    {
        static const IConsoleVariable* FlickerEnabled = IConsoleManager::Get().FindConsoleVariable(TEXT("vg.Flicker.Enabled"));
        const bool bFlicker = !FlickerEnabled || FlickerEnabled->GetBool();
        // Acessibilidade: sem flicker, a bateria fraca vira uma luz mais fraca e estável.
        Scale = bFlicker
            ? VGFlickerRules::SampleScale(LowBatteryFlicker->Pattern, LowBatteryFlicker->StepsPerSecond,
                                          static_cast<float>(Now() - StateEnteredAt))
            : 0.6f;
    }

    // O preço do pulso: depois dele, o feixe volta fraco e recupera.
    const float SincePulse = static_cast<float>(Now() - LastPulseAt);
    if (State != EVGFlashlightState::Overcharge && RecoverySeconds > 0.0f && SincePulse < OverchargeDuration + RecoverySeconds)
    {
        const float Alpha = FMath::Clamp((SincePulse - OverchargeDuration) / RecoverySeconds, 0.0f, 1.0f);
        Scale *= FMath::Lerp(PostPulseScale, 1.0f, Alpha);
    }
    SetIntensity(BaseIntensity * Scale);
}
```

> ⚠️ **Pontos a conferir na sua versão:** o cabeçalho de `FOverlapResult` (em versões recentes, `Engine/OverlapResult.h`; em outras, ele chega por `Engine/World.h`); o nome do membro de intensidade (`Intensity`) e a função `SetIntensity` em `ULightComponent`; e o construtor de `FHitResult` usado para montar o `HitInfo` (se não existir com essa assinatura, preencha `HitActor`/`ImpactPoint` por `FHitResult::Init` e atribuição).

### 5. Ligando à jogadora

🔁 **Antes**, o `BP_VGJogadora` tinha um `SpotLight` na câmera, um `UVGFlickerComponent` e a lógica de ligar, drenar e conceder a tag no grafo. **Agora**, o `AVGCharacter` cria o componente preso à câmera, e o Blueprint só ajusta valores (intensidade, cone, perfil IES, `LowBatteryFlicker`):

```cpp
// VGCharacter.h (adições)
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<class UVGFlashlightComponent> Flashlight;

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<class UInputAction> FlashlightAction;       // IA_Lanterna

    UPROPERTY(EditDefaultsOnly, Category = "Vigilia|Input")
    TObjectPtr<class UInputAction> OverchargeAction;       // IA_SobrecargaLanterna (trigger Hold, 0,35 s)

    /** Feedback do "carregar" (zumbido crescente, Cap. 52): true ao começar a segurar, false ao soltar/cancelar. */
    UFUNCTION(BlueprintImplementableEvent, Category = "Vigilia|Flashlight")
    void OnOverchargeCharging(bool bCharging);

// VGCharacter.cpp
//   no construtor:
//     Flashlight = CreateDefaultSubobject<UVGFlashlightComponent>(TEXT("Flashlight"));
//     Flashlight->SetupAttachment(Camera);
//   em SetupPlayerInputComponent:
//     Input->BindAction(FlashlightAction, ETriggerEvent::Started, Flashlight.Get(), &UVGFlashlightComponent::Toggle);
//     Input->BindAction(OverchargeAction, ETriggerEvent::Started,   this, &AVGCharacter::HandleOverchargeStarted);
//     Input->BindAction(OverchargeAction, ETriggerEvent::Canceled,  this, &AVGCharacter::HandleOverchargeCanceled);
//     Input->BindAction(OverchargeAction, ETriggerEvent::Triggered, this, &AVGCharacter::HandleOverchargeTriggered);

void AVGCharacter::HandleOverchargeStarted()   { OnOverchargeCharging(true); }
void AVGCharacter::HandleOverchargeCanceled()  { OnOverchargeCharging(false); }
void AVGCharacter::HandleOverchargeTriggered()
{
    OnOverchargeCharging(false);
    Flashlight->RequestOvercharge(); // as regras decidem se pode
}
```

No `IMC_Exploracao`, `IA_SobrecargaLanterna` vai no botão direito do mouse (ou num gatilho do controle), com o trigger ***Hold*** e `HoldTimeThreshold = 0.35`, sem "disparar uma vez só" desmarcado: um pulso por segurar. Os três handlers são `void` sem parâmetros declarados no `.h` (privados). O *Hold* do Enhanced Input dispara `Started` ao começar a segurar, `Canceled` ao soltar antes do limiar e `Triggered` ao atingi-lo (⚠️ confira a semântica de `Ongoing`/`Triggered` do *Hold* na sua versão).

### 6. As luminárias

```cpp
// Source/Vigilia/World/VGLightFixture.h
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameplayTagContainer.h"
#include "VGLightFixture.generated.h"

class AVGSafeZone;
class ULightComponent;
class UVGFlickerComponent;
class UVGFlickerProfile;
struct FVGGameplayEvent;

/**
 * Uma luminária do mundo. ACESA/APAGADA vem de fatos (persistente por construção);
 * a zona segura associada segue a luz (só é seguro onde há luz).
 * O Diretor pode fazê-la falhar, mas nunca se ela protege uma zona.
 */
UCLASS()
class VIGILIA_API AVGLightFixture : public AActor
{
    GENERATED_BODY()

public:
    AVGLightFixture();

    UFUNCTION(BlueprintPure, Category = "Vigilia|Light")
    bool IsLit() const { return bLit; }

protected:
    virtual void PostInitializeComponents() override;
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
    TObjectPtr<UVGFlickerComponent> Flicker;

    /** Fatos para estar acesa (ex.: TEM Narrative.Fact.S1.BreakersRestored). Vazio = sempre acesa. */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Light")
    FGameplayTagQuery LitWhen;

    /** A zona que esta luz protege. Uma zona, UMA luminária dona. */
    UPROPERTY(EditInstanceOnly, Category = "Vigilia|Light")
    TObjectPtr<AVGSafeZone> ProtectedZone;

    /** Responde aos sinais de BuildUp do Diretor (ignorado se protege zona). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Light|Director")
    bool bDirectorSignals = true;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Light|Director", meta = (EditCondition = "bDirectorSignals"))
    TObjectPtr<UVGFlickerProfile> SignalProfile; // DA_Flicker_Presenca

    UPROPERTY(EditAnywhere, Category = "Vigilia|Light|Director", meta = (EditCondition = "bDirectorSignals", ClampMin = "100.0"))
    float SignalRadius = 1500.0f;

    UPROPERTY(EditAnywhere, Category = "Vigilia|Light|Director", meta = (EditCondition = "bDirectorSignals", ClampMin = "0.5"))
    float SignalSeconds = 3.0f;

    /** Padrão em repouso ("m" = estável). */
    UPROPERTY(EditAnywhere, Category = "Vigilia|Light")
    FString IdlePattern = TEXT("m");

private:
    void Refresh();
    void HandleEvent(const FVGGameplayEvent& Event);
    void EndSignal();

    UPROPERTY(Transient)
    TArray<TObjectPtr<ULightComponent>> Lights;

    bool bLit = false;
    FDelegateHandle FactHandle;
    FDelegateHandle RestoreHandle;
    FDelegateHandle EventHandle;
    FTimerHandle SignalTimer;
};
```

```cpp
// Source/Vigilia/World/VGLightFixture.cpp (essencial)
#include "World/VGLightFixture.h"

#include "Components/LightComponent.h"
#include "Core/VGGameplayEventSubsystem.h"
#include "Core/VGGameplayTags.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"
#include "GameFramework/PlayerController.h"
#include "Narrative/VGNarrativeSubsystem.h"
#include "TimerManager.h"
#include "World/VGFlickerComponent.h"
#include "World/VGFlickerProfile.h"
#include "World/VGSafeZone.h"

AVGLightFixture::AVGLightFixture()
{
    PrimaryActorTick.bCanEverTick = false;
    SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("Root")));
    Flicker = CreateDefaultSubobject<UVGFlickerComponent>(TEXT("Flicker"));
}

void AVGLightFixture::PostInitializeComponents()
{
    Super::PostInitializeComponents();
    const TInlineComponentArray<ULightComponent*> Found(this); // as luzes do Blueprint filho (point, spot, rect)
    for (ULightComponent* Light : Found)
    {
        Lights.Add(Light);
    }
}

void AVGLightFixture::BeginPlay()
{
    Super::BeginPlay();
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        FactHandle = Narrative->OnFactChangedNative.AddWeakLambda(this, [this](FGameplayTag, bool) { Refresh(); });
        RestoreHandle = Narrative->OnRestored.AddWeakLambda(this, [this]() { Refresh(); });
    }
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        EventHandle = Bus->OnEventNative.AddUObject(this, &AVGLightFixture::HandleEvent);
    }
    Flicker->SetPattern(IdlePattern);
    Refresh();
}

void AVGLightFixture::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearTimer(SignalTimer);
    if (UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this))
    {
        Narrative->OnFactChangedNative.Remove(FactHandle);
        Narrative->OnRestored.Remove(RestoreHandle);
    }
    if (UVGGameplayEventSubsystem* Bus = GetWorld()->GetSubsystem<UVGGameplayEventSubsystem>())
    {
        Bus->OnEventNative.Remove(EventHandle);
    }
    Super::EndPlay(EndPlayReason);
}

void AVGLightFixture::Refresh()
{
    const UVGNarrativeSubsystem* Narrative = UVGNarrativeSubsystem::Get(this);
    const bool bNewLit = LitWhen.IsEmpty() || (Narrative && Narrative->MatchesFacts(LitWhen));
    if (bNewLit == bLit && HasActorBegunPlay())
    {
        return;
    }
    bLit = bNewLit;
    for (ULightComponent* Light : Lights)
    {
        Light->SetVisibility(bLit); // visibilidade: dona é a luminária; intensidade: dono é o flicker
    }
    if (ProtectedZone)
    {
        ProtectedZone->SetZoneActive(bLit); // só é seguro onde há luz
    }
}

void AVGLightFixture::HandleEvent(const FVGGameplayEvent& Event)
{
    if (Event.Channel != TAG_Event_Director_BuildUp || !bDirectorSignals || ProtectedZone || !bLit || !SignalProfile)
    {
        return;
    }
    const APawn* Player = GetWorld()->GetFirstPlayerController() ? GetWorld()->GetFirstPlayerController()->GetPawn() : nullptr;
    if (!Player || FVector::DistSquared(Player->GetActorLocation(), GetActorLocation()) > FMath::Square(SignalRadius))
    {
        return;
    }
    Flicker->SetPattern(SignalProfile->Pattern);
    GetWorldTimerManager().SetTimer(SignalTimer, this, &AVGLightFixture::EndSignal, SignalSeconds);
}

void AVGLightFixture::EndSignal()
{
    Flicker->SetPattern(IdlePattern);
}
```

O `Refresh` usa `HasActorBegunPlay()` para aplicar o estado **sempre** na primeira chamada (dentro do `BeginPlay`, o ator ainda não terminou de começar), e só nas mudanças depois. O `Event.Director.BuildUp` é o canal que o Capítulo 42 publica; se a sua tag nativa tem outro nome no código, use-o.

### 7. O teste

```cpp
// Source/Vigilia/Tests/VGFlashlightRulesTest.cpp
#include "Misc/AutomationTest.h"
#include "Player/VGFlashlightRules.h"
#include "World/VGFlickerRules.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FVGFlashlightRulesTest, "Vigilia.Player.Flashlight.Transitions",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

bool FVGFlashlightRulesTest::RunTest(const FString& Parameters)
{
    using S = EVGFlashlightState;
    using I = EVGFlashlightInput;
    FVGFlashlightContext Full;  Full.bCanAffordOvercharge = true; Full.bOverchargeReady = true;
    FVGFlashlightContext Low = Full; Low.bBatteryLow = true;
    FVGFlashlightContext Empty; Empty.bHasCharge = false;
    FVGFlashlightContext Cooling = Full; Cooling.bOverchargeReady = false;
    FVGFlashlightContext Poor = Full; Poor.bCanAffordOvercharge = false;

    TestTrue(TEXT("Ligar com carga"),               VGFlashlightRules::Next(S::Off, I::TogglePressed, Full) == S::On);
    TestTrue(TEXT("Ligar com bateria fraca pisca"), VGFlashlightRules::Next(S::Off, I::TogglePressed, Low) == S::Flickering);
    TestTrue(TEXT("Sem carga não liga"),             VGFlashlightRules::Next(S::Off, I::TogglePressed, Empty) == S::Off);
    TestTrue(TEXT("Sobrecarga com tudo pronto"),     VGFlashlightRules::Next(S::On, I::OverchargeRequested, Full) == S::Overcharge);
    TestTrue(TEXT("Sobrecarga em cooldown: nada"),   VGFlashlightRules::Next(S::On, I::OverchargeRequested, Cooling) == S::On);
    TestTrue(TEXT("Sobrecarga sem carga suficiente"), VGFlashlightRules::Next(S::On, I::OverchargeRequested, Poor) == S::On);
    TestTrue(TEXT("Sobrecarga desligada: nada"),     VGFlashlightRules::Next(S::Off, I::OverchargeRequested, Full) == S::Off);
    TestTrue(TEXT("O pulso ignora o interruptor"),   VGFlashlightRules::Next(S::Overcharge, I::TogglePressed, Full) == S::Overcharge);
    TestTrue(TEXT("Fim do pulso com bateria fraca"), VGFlashlightRules::Next(S::Overcharge, I::OverchargeFinished, Low) == S::Flickering);
    TestTrue(TEXT("Esgotou durante o pulso"),        VGFlashlightRules::Next(S::Overcharge, I::BatteryDepleted, Empty) == S::Depleted);
    TestTrue(TEXT("Bateria nova leva a Off (Cap. 4)"), VGFlashlightRules::Next(S::Depleted, I::BatteryReplaced, Full) == S::Off);

    TestEqual(TEXT("'m' é 1"), VGFlickerRules::SampleScale(TEXT("m"), 10.0f, 0.0f), 1.0f);
    TestEqual(TEXT("'a' é 0"), VGFlickerRules::SampleScale(TEXT("ma"), 10.0f, 0.15f), 0.0f);
    return true;
}

#endif
```

### Explicação das decisões

- **A lanterna é dona da própria intensidade.** O flicker de bateria fraca, o pulso e a recuperação são calculados num lugar (`UpdateIntensity`) e multiplicados. Com um `UVGFlickerComponent` no mesmo ator, dois sistemas escreveriam `Intensity` a cada frame, e o último a escrever venceria. Por isso o flicker da lanterna usa a **regra** de flicker, não o **componente**.
- **Transições numa função pura e testada** (`VGFlashlightRules::Next`), com o contexto montado pelo componente. O componente só decide **quando** perguntar; a regra decide **o quê**. É o exercício do Capítulo 4, finalmente com código.
- **A bateria anuncia transições; a lanterna drena o contínuo** (Cap. 4). Um pulso que esgota a bateria não força o estado: ele drena, a bateria anuncia `Depleted`, e a transição chega pelo caminho de sempre. Esse caminho **reentra** em `EnterState`; por isso o dreno é a última linha do pulso, e o pulso é a última coisa de `EnterState`, depois do anúncio. Os ouvintes recebem `On → Overcharge` e só então `Overcharge → Depleted`, na ordem certa.
- **Tags concedidas e revogadas pela diferença entre o estado antigo e o novo.** Não há "conceder ao ligar" e "revogar ao desligar" espalhados: a simetria é garantida pela forma do código, porque a contagem de status do Capítulo 23 não perdoa um `Revoke` a menos.
- **O pulso usa o canal de dano** (`ApplyPointDamage` com `UVGDamageType_Light`), como o sinalizador. A Presença reage pelo `UVGPresenceReactionComponent` (Cap. 37), que estende o atordoamento sem reiniciá-lo (Cap. 38); os vigias ignoram (multiplicador 0, Cap. 22). A lanterna não sabe quem é a Presença.
- **Cone com linha de visão**: a luz não atravessa paredes, como o pulso do sinalizador (Cap. 28).
- **Relógio de jogo** para pulso, cooldown e recuperação: se o jogo pausa no meio do cooldown, o cooldown pausa junto.
- **Navegação: a lanterna não marca a NavMesh.** O feixe se move a cada frame; atualizar áreas de navegação com ele seria caro e instável. A navegação pela luz (Cap. 35) fica com o que é estável (zonas, sinalizadores, portas); a lanterna age pela **percepção** (a tag) e pelo **dano** (a sobrecarga).
- **A luminária lê fatos, não eventos**, e por isso acerta depois de um save sem código de restauração. Ela é dona da zona que protege, e a regra "só é seguro onde há luz" vira estrutural.

---

## Projeto Vigília — a luz do setor 1

### A lanterna

🔁 A lanterna mínima do Interlúdio I sai do `BP_VGJogadora`: o `SpotLight` da câmera, o `UVGFlickerComponent` e o grafo de ligar e drenar dão lugar ao `UVGFlashlightComponent`. **O que se aprendeu com a versão anterior:** ela provou que a mecânica funciona (o playtest do Interlúdio mostrou jogadoras apagando a lanterna para atravessar o corredor) e mostrou a dívida (booleanos, intensidade disputada, tags concedidas à mão). Valores de partida no Blueprint:

| Propriedade | Valor | Por quê |
|---|---|---|
| Intensidade / raio de atenuação | a ajustar / ~1.500 cm | Alcance útil de ~12–15 m (Cap. 50) |
| Cone interno / externo | ~12° / ~24° | Um "túnel" tenso, com borda suave |
| Perfil IES | um perfil de lanterna | Anel e imperfeição do feixe, quase sem custo |
| Sombras | ligadas | A sombra da Presença na parede |
| Contribuição volumétrica | moderada | O feixe aparece na poeira (Cap. 54) |
| `LowBatteryFlicker` | `DA_Flicker_LampadaVelha` | A falha da lanterna fala de bateria, não de Presença |

### As luminárias do setor 1

| Espaço | Luminária | `LitWhen` | `ProtectedZone` | Diretor |
|---|---|---|---|---|
| Hall | Emergência âmbar (point, sombra) | vazio (sempre) | A zona do hall | Não (protege) |
| Corredor | 4 luminárias de serviço (spot, sem sombra) | `S1.BreakersRestored` | — | Sim |
| Vestiário, sala do engenheiro | 1 luminária cada, de serviço | `S1.BreakersRestored` | — | Sim |
| Subsolo, quadro do puzzle | Emergência âmbar pequena (point, sombra) | vazio (sempre) | Zona pequena (~3 m) | Não |
| Sala de controle | Luzes de painel (rect) + emissivos | `S1.BreakersRestored` | A zona da sala | Não |
| Destaques de atenção | Livro, memorando, painel principal: spot fraco e estreito, sem iluminar o chão | vazio | — | Não |

🔁 O `AVGSector` deixa de ativar as zonas seguras (a lista de zonas do desafio do Capítulo 23 sai dele): a luz da sala de controle ativa a zona dela quando `S1.BreakersRestored` aparece. A ordem dos efeitos não muda para a jogadora: o setor energiza → a regra concede o fato → a luminária acende → a zona ativa → a área da NavMesh muda (Cap. 35).

E a cascata do susto (Cap. 49) continua funcionando sem mudança: a trilha de evento chama `SetPattern` no `UVGFlickerComponent` de cada luminária do corredor, que agora vive dentro do `AVGLightFixture`. Como o corredor não protege zona nenhuma, a cena pode fazer a luz "andar" sem quebrar a linguagem.

### Exposição e clima

Um *Post Process Volume* global no `L_CasaDeForca`: exposição com faixa estreita (o escuro continua escuro), granulação leve, vinheta leve, *bloom* baixo (a sobrecarga deve "estourar" sem lavar a tela). Névoa volumétrica fraca no corredor e no subsolo, para o feixe aparecer no ar.

### Orçamento de luz (primeira medida)

No pior momento do setor 1 (a cascata do susto, com a lanterna acesa), conte e registre no `DEVLOG.md`: luzes visíveis, luzes com sombra (meta: a lanterna + no máximo 2), o *Light Complexity* do corredor e o tempo de GPU (`stat GPU`). O Capítulo 58 parte desses números.

---

## Decisões arquiteturais

1. **Linguagem de luz** com cinco significados (segurança, atenção, energia, perigo, a jogadora), sem exceções; a lanterna pisca por bateria, o mundo pisca por perigo.
2. **Escuridão legível**: exposição com faixa estreita, nunca preto no caminho crítico, emissivos como guias, calibração de brilho.
3. **Sobrecarga**: segurar 0,35 s; 25 de carga; pulso de 0,3 s em cone de 8 m/25° com linha de visão; dano de luz 40; cooldown 6 s; o feixe volta a 30% por 1 s; ruído; `Status.Light.Overcharge`.
4. **`UVGFlashlightComponent` é um `USpotLightComponent`**, dono da própria intensidade, com transições em regra pura; bateria na jogadora.
5. **Luzes do mundo leem fatos**; a luminária é dona da zona que protege; o Diretor só mexe em luzes que não protegem.
6. **A lanterna não altera a NavMesh**; age por percepção (tag) e por dano (sobrecarga).
7. **Sombra: a lanterna sempre; luzes do mundo, só as que compõem**; orçamento medido por espaço, no pior momento.

---

## Armadilhas

- **Exposição automática sem limites**, que "acende" o escuro desenhado.
- **Preto absoluto no caminho crítico.**
- **Uma luz de segurança que falha**, ou um destaque de atenção que parece segurança.
- **Dois donos da intensidade** (um flicker e uma sobrecarga escrevendo a mesma luz).
- **Zona segura sem luz**, ou luz de emergência sem zona: a linguagem mente.
- **Luminária que escuta só o evento** e fica apagada depois de carregar um save.
- **Tag de status concedida sem revogação simétrica** (a percepção passa a ver a lanterna acesa para sempre).
- **Marcar a NavMesh com a lanterna em movimento.**
- **Sobrecarga sem preço**: sem custo, cooldown e risco, ela vira o botão "ganhar".
- **Sombra em toda luz**, e raios de atenuação enormes.
- **Flicker rápido com Lumen** sem olhar o rebatido.

---

## Exercício

**Parte 1 — regras e teste (1 h).** Implemente `VGFlickerRules` (🔁 no `UVGFlickerComponent`), `VGFlashlightRules` e o teste. Antes de rodar, preencha à mão a tabela de transições do exercício do Capítulo 4 e compare com o código.

**Parte 2 — a lanterna (2 h).** Implemente `UVGFlashlightComponent`, a ligação no `AVGCharacter` e `IA_SobrecargaLanterna` com *Hold*. Remova a lanterna Blueprint do `BP_VGJogadora`. Com `vg.Debug.Flashlight 1`, teste:
- o pulso só sai acesa, com carga ≥ 25 e cooldown cumprido;
- a bateria esgotando no meio do pulso leva a `Depleted`;
- `Status.Light.Flashlight` some ao apagar e `Status.Light.Overcharge` dura só o pulso (confira as tags do `UVGStatusTagsComponent` com um print ou o Gameplay Debugger);
- um vigia no cone não sofre nada; a Presença recua.

**Parte 3 — luminárias (1,5 h).** Implemente `AVGLightFixture`, crie os Blueprints `BP_Luminaria_Emergencia`, `BP_Luminaria_Servico` e `BP_Destaque`, e monte a luz do setor 1 conforme a tabela. Tire a lista de zonas do `AVGSector`. Teste com `VGAddFact Narrative.Fact.S1.BreakersRestored` e `VGRemoveFact`: as luzes e as zonas acompanham.

**Parte 4 — escuridão (1,5 h).** Configure a exposição, a névoa e o pós-processamento do `L_CasaDeForca`. Jogue o setor em três telas diferentes e anote onde a jogadora perde a leitura do espaço.

---

## Desafio — luzes que a jogadora acende

Inspirado nas velas de Amnesia: algumas lâmpadas de emergência da usina estão **desligadas**, e a jogadora pode religá-las (uma interação de 2 s, com ruído). Uma lâmpada religada vira zona segura **permanente**.

1. Implemente com o que já existe: um `AVGLightFixture` com `LitWhen` sobre um fato próprio (ex.: `Narrative.Fact.S2.Lamp03.On`), concedido por um interativo. Nenhuma classe nova deveria ser necessária. Se for, explique por quê.
2. Decida o custo: a interação consome uma bateria? Faz barulho? Pode ser interrompida pela Presença?
3. Pense na consequência de design: se a jogadora pode criar zonas seguras, o Diretor (Cap. 42) e o level design (Cap. 50) precisam saber. Onde ficam essas lâmpadas para que elas sejam uma **escolha** (qual religar?) e não uma trilha óbvia? Registre no `DEVLOG.md`.

---

## Uso de IA

1. **Para revisar a linguagem de luz:**
   > "Este é o vocabulário de luz de um jogo de terror (abaixo: cinco significados, aparência e regras). Procure ambiguidades: situações em que a jogadora poderia confundir dois significados, e casos de borda (a luz de segurança durante uma cena, a lanterna com bateria fraca perto do monstro). Para cada ambiguidade, diga o que a jogadora provavelmente faria de errado. [tabela]"

2. **Para auditar a máquina de estados:**
   > "Aqui está uma função de transição de estados de uma lanterna em C++ (abaixo), com cinco estados e sete entradas. Monte a tabela completa estado × entrada, marque as células em que o estado não muda e aponte combinações que parecem bugs de design (por exemplo, uma entrada ignorada que a jogadora esperaria que funcionasse). [código]"

3. **Para balancear a sobrecarga:**
   > "Uma lanterna tem bateria de 100, gasta 0,8/s acesa, e a sobrecarga custa 25 com cooldown de 6 s. Baterias recarregam 40 e aparecem a cada ~90 s de caminho. Simule três estilos de jogadora (econômica, normal, agressiva com a sobrecarga) por 10 minutos e diga quanto tempo cada uma passa no escuro e quantas sobrecargas usa. Mostre as contas."

**Cuidado específico:** a IA conhece a iluminação da Unreal "em média", misturando versões: nomes de propriedades de exposição, padrões do Lumen e o que cada mobilidade faz mudaram ao longo do UE5. Toda resposta sobre configuração de renderização deve ser conferida na documentação da sua versão e, principalmente, **na sua cena**.

---

## Checklist

- [ ] Sei os tipos e mobilidades de luz, o que o Lumen faz e por que a exposição importa num jogo escuro.
- [ ] A Vigília tem uma linguagem de luz escrita, e nenhuma luz a contradiz.
- [ ] Sei construir escuridão legível e testá-la em telas diferentes.
- [ ] A lanterna é o `UVGFlashlightComponent`, com transições testadas, tags simétricas e sobrecarga com preço.
- [ ] A sobrecarga afasta a Presença pelo canal de dano e não afeta os vigias.
- [ ] As luminárias leem fatos, e cada zona segura tem uma luz dona.
- [ ] Medi o orçamento de luz do corredor no pior momento.

---

## Para ir além

- **Documentação oficial da Unreal** (dev.epicgames.com/documentation): **Lumen Global Illumination and Reflections**, **Virtual Shadow Maps**, **Auto Exposure**, **Volumetric Fog**, **IES Light Profiles** e **Light Functions**.
- **GDC Vault** (gdcvault.com): palestras sobre iluminação em jogos de terror e sobre a iluminação dos jogos da Remedy (confira títulos e autores lá).
- **Jesse Schell, *The Art of Game Design*** — os capítulos sobre estética e sobre como o jogador é guiado.

---

➡️ **Próximo:** [Capítulo 52 — Audio](cap-52-audio.md)
